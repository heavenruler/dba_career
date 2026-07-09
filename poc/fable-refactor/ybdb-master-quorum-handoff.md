# YBDB smoke 卡關交接包 — master quorum race + catalog-wait 連環

> 2026-07-09。本輪 YBDB Stage 1 smoke 兩次重跑皆在抓出新 bug 後中止，第三個問題
> （postgres backend 死鎖）尚未查完成因即被 user 收手，改走本文件彙整交接。
> TiDB/CRDB 已完成 Stage 1（見 SESSION-HISTORY），YBDB 是三家最後一個未過關的。

## 目前狀態

- VM 已全拆（`phase9-tunnels-stop phase9-destroy`，iac-idc/iac-gcp state 皆 0）。
- 已 commit 3 個修復（見下表），下次重跑會自動套用；**但這些修復不足以讓 smoke 過關**——
  卡在第三個問題（postgres 死鎖）時中止，成因未查完。
- Stage 1 進度：TiDB ✅、CRDB ✅、**YBDB ❌ 未完成**。

## 問題 1（已修）：`prepare.sh` grep -c 在 set -e 下的死鎖

**現象**：CRDB/YBDB 的 placement gate 段跑到 `gcp_cnt=$(grep -cE ... )` 那行，log 印完
"X-CROSS placement gate" 後無任何錯誤訊息瞬間死亡，`.suite.failed exit_code:1`。

**成因**：`grep -c` 零匹配時仍正確印出 "0"，但 exit code 是 1。`var=$(failing_cmd)` 這種
assignment 形式的指令，在 `set -euo pipefail` 下**不比照** if/&&/|| 語境豁免 set -e，
會在 `${var:-0}` fallback 執行前就把整支腳本殺死。可用
`bash -c 'set -e; x=$(grep -c zzz /etc/hostname); echo after'`（exit 2，"after" 永不印）
重現。這其實是**第二次修**——第一次修法（`bea9ae1d`，改成 `var=$(...); var=${var:-0}`
兩段式）本身就踩了這個陷阱，只是恰好第一次 CRDB smoke 因為 leader 分布 50/50、
两邊都非零而沒觸發。這次 YBDB 100% leader 落 IDC（`gcp_cnt` 真的 0）才踩爆。

**修法**（`44d95c42`）：`$(...)` 內加 `|| true` 吸收 exit code：
```bash
idc_cnt=$(grep -cE '...' "$GATE_OUT" 2>/dev/null || true); idc_cnt=${idc_cnt:-0}
```
已驗證零匹配/正匹配/檔案不存在三種情境皆對。CRDB（356-357）+ YBDB（413-414）兩分支同修。

## 問題 2（已修，deploy 層存量 bug）：yugabyted 自動 master 選舉的 join-order race

**現象**：`phase4-ybdb-fix6n` 跑完顯示 6/6 tservers ALIVE、placement 正確（idc:3 live +
gcp:3 read_replica），一切看起來正常。但用 `curl http://<idc-host>:7000/api/v1/masters`
（或更權威的 `yb-admin list_all_masters`）直接查 master raft membership 才發現：
**master quorum 實際是 4 台，包含 1 台 GCP tserver 被誤選為 master**（非設計預期的
3 台 IDC-only）。**兩次全新 `phase1` rebuild + `phase4` 重部署，都重現了這個 bug**
（分別是 `10.160.152.12` 和 `10.160.152.11` 搶到 master 名額），確認是 ansible
`yugabyte-vm6.yml` 的**可重現 race**，不是偶發。

第二次修復時甚至發現比預期更差：diagnostic 過程中 `yb-admin list_all_masters`
（查詢實際 LEADER）顯示真正的 raft quorum**只有 2 台**（`.32` + 1 台 GCP），
`.33`/`.34` 雖然本機在跑 yb-master process，但從未真正 join 進 raft 共識——
HTTP `/api/v1/masters` 端點在 FOLLOWER 節點上回報的是**過時的 peer 快取**，
不是真正的 consensus membership，只有直接問 LEADER 才拿到真值。

**成因（架構層）**：TiDB 的 tiup topology YAML 和 CRDB 的 `cockroach start` 都用
**明確 flag/topology 指定**哪些節點是控制平面，沒有歧義。YBDB 的 `yugabyted` CLI
不同——它靠**join 順序**自動選前 3 個成功 join 的節點當 master，沒有明確角色綁定。
這是簡化上手體驗的設計，但在 ansible 平行/序列化不夠嚴謹的 orchestration 下就是
race 溫床。

**手動修法（已驗證有效，尚未落回 playbook）**：
```bash
# 1. 用權威來源（查 LEADER，不要查 FOLLOWER 的 HTTP API）確認真正的 raft membership
yb-admin --master_addresses=<candidate list> list_all_masters

# 2. 依序 ADD_SERVER 補齊缺的 IDC master
yb-admin --master_addresses=<現存 masters> change_master_config ADD_SERVER <idc_ip> 7100

# 3. REMOVE_SERVER 移除誤入的 GCP master（注意參數順序：ip port [uuid]，不是 uuid 在前）
yb-admin --master_addresses=<現存+待移除> change_master_config REMOVE_SERVER <gcp_ip> 7100 <uuid>
```
兩次 live 驗證：ADD_SERVER 讓 `.33`/`.34` 從「本機跑但未 join」變成真正 raft FOLLOWER；
REMOVE_SERVER 讓 GCP 節點的 role 從 FOLLOWER 變 NON_PARTICIPANT 後從清單消失。
最終 `list_all_masters` 穩定顯示 `{.32, .33, .34}` 3 台 IDC-only，無 tablet 資料
遺失（RF=3 期間其他 replica 仍在，純觸發 re-replicate）。

**未落地**：這個手動 yb-admin 三步驟**沒有回寫進任何腳本**——下次 `phase4-ybdb-deploy`
+ `phase4-ybdb-fix6n` 大概率**還會重現同一個 race**（2/2 復現率）。`phase4-ybdb-fix6n`
（Makefile 行 386-433）目前只檢查/清理 DEAD **tserver**，完全沒有檢查 master raft
membership 是否符合「剛好 3 台、全 IDC」的預期。

**尚未查清、需要 Fable 規劃的部分**：
1. **`yugabyte-vm6.yml` 的 join 序列到底哪裡沒序列化？** 沒有直接看 playbook 原始碼
   確認 IDC .33/.34 與 GCP 1-3 的 join 是否用 `serial: 1` 或等效機制隔開——只確認了
   「結果錯」，沒確認「playbook 哪一行造成錯」。
2. **`current_masters` 快取欄位的完整生命週期**：`/var/yugabyte/conf/yugabyted.conf`
   有一個 `current_masters` JSON 欄位，yugabyted CLI 用它（而非即時查詢）來決定
   `yugabyted start` 時要塞給 tserver 的 `--tserver_master_addrs`。這個欄位**不會
   因為你用 yb-admin CLI 改了真實 raft membership 就自動更新**——本輪手動用 `sed`
   patch 過 `.32` 的這個欄位才解決「cold-reset 後 tserver 連不到正確 master」的問題
   （見問題 3 的前半段）。**這代表：即使上面的 yb-admin 三步驟修好 master quorum，
   任何後續 `yugabyted stop && yugabyted start`（cold-reset 正是這樣）都可能重新用
   舊快取值把 tserver 導向錯誤位址。** 需要決定：(a) 修 playbook 讓部署時就不產生
   錯誤的 join race（治本），或 (b) 在每次 `yugabyted start` 前都先校正
   `current_masters` 欄位（治標但每個呼叫點都要補）。

## 問題 3（已修一半）：cold-reset 缺 catalog-wait tserver flags

**現象**：修完問題 2 後重跑，卡在 `run.sh` 的 `[3/4] run` 階段的 cold-reset 步驟
（`coldreset-ybdb.sh` 重啟 `.32`）——重啟後 `yugabyted` CLI 自報 "YSQL Status: Not
Ready" 超過 5 分鐘輪詢上限，`ysqlsh` 連線直接 "Connection refused"。

**成因**：確認是問題 2 講的 `current_masters` 快取問題——tserver 啟動時被塞進
`--tserver_master_addrs=10.160.152.11:7100,10.160.152.12:7100,172.24.40.32:7100`
（剛被 yb-admin 移除的兩台 GCP master 的舊位址),YSQL proxy 因為連不到正確的
master leader 而卡死初始化，port 5433 從未 bind。

**修法（手動，已驗證）**：`sed -i` 直接改 `.32` 上 `/var/yugabyte/conf/yugabyted.conf`
的 `current_masters` 欄位成 `172.24.40.32:7100,172.24.40.33:7100,172.24.40.34:7100`，
重新 `yugabyted stop/start`。改完後 YSQL 確實 Ready，`ysqlsh SELECT 1` 秒回。

**接著又炸出第二層**：改完 `current_masters` 重跑 prepare，go-tpc 在
`creating index idx_customer` 階段 panic：
`pq: timed out waiting for postgres backends to catch up`——這是 SESSION-HISTORY
06-19 記錄過的歷史 bug（YSQL DDL 觸發 catalog version 更新需等所有 ALIVE tservers
的 postgres backend ack，跨區 ack 慢，default timeout 太短）。查證發現
`coldreset-ybdb.sh` 的 `YB_TSERVER_FLAGS` 從未帶
`wait_for_ysql_backends_catalog_version_client_master_rpc_{timeout,margin}_ms`
這兩個 flag（ansible 部署時已幫 `.33`/`.34` 加了，但 cold-reset 重啟 `.32` 時遺漏，
每次 cold-reset 都會讓 `.32` 掉回沒有這個緩衝的狀態）。

**修法**（`9f3306fe`）：`YB_TSERVER_FLAGS` 補上
`wait_for_ysql_backends_catalog_version_client_master_rpc_timeout_ms=300000,`
`wait_for_ysql_backends_catalog_version_client_master_rpc_margin_ms=600000`
（與 `.33`/`.34` 完全一致）。已對 `.32` 重啟驗證 flag 確實生效（`ps aux` 可見）。

**修完 flag 之後，同一個 panic 又發生一次（15 分鐘才逾時，比之前久，但仍炸）**：
往下查發現 **`.33` 的本機 postgres backend 完全死鎖**——`timeout 10 ysqlsh -h
172.24.40.33 ... SELECT 1` 連本機（同機）連線都卡死到逾時被 kill，
`ps aux` 上有一堆卡在 `postgres: postgres template1 [local] startup` 狀態、
持續累積、從未清掉的 backend process（23 個，仍在增長）。但 `list_all_tablet_servers`
顯示 `.33` 的 tserver 心跳完全正常（ALIVE，heartbeat delay < 1s）——**tserver 層
健康，但同機的 postgres/YSQL 層死鎖**，兩者狀態不一致。

**這是本輪查到最後、成因未確認就被中止的問題**。已知線索：
- `.33` 從未被本輪任何操作重啟過（從 09:16 部署完成後持續運行，包含在
  「問題 2」的 `change_master_config ADD_SERVER` 期間也沒重啟，只是被拉進
  master raft group 當 FOLLOWER）。
- master leader 當時在 `.34`（不是 `.33`），所以死鎖不是「身為 leader 處理
  catalog version bump 卡住」這麼直觀。
- 懷疑方向（未驗證）：(a) 本輪對 master raft membership 做的 ADD_SERVER 操作
  本身，是否對已經在跑的 `.33` local postgres 造成某種 catalog cache 失效但
  沒有正確恢復；(b) 是否與「問題 2」提到的 `current_masters` 快取不一致問題
  在 `.33` 上也有一份（只是還沒去檢查/修正)，導致 `.33` 的 postgres 也在等一個
  連不到的 master 位址；(c) 純粹是本輪反覆 ADD/REMOVE master + 兩次
  yugabyted stop/start on `.32` 疊加出的一次性不穩定狀態，重新部署可能不會遇到。
- 下次排查起手式：`ssh root@172.24.40.33 timeout 10 ysqlsh -h 172.24.40.33 -p 5433
  -U yugabyte -d yugabyte -c 'SELECT 1'` 直接重現；若重現，查
  `/var/yugabyte/data/yb-data/tserver/logs/postgresql-*.log`（本輪未查看這個檔，
  只看了 yb-tserver 自己的 WARNING/ERROR log）；也該檢查 `.33` 的
  `yugabyted.conf` 的 `current_masters` 欄位是否也需要跟 `.32` 一樣手動校正。

## 建議路線（給 Fable 規劃參考，非拍板）

1. **治本優先**：查 `ansible/playbooks/yugabyte-vm6.yml` 的 join play，確認
   IDC 3 台與 GCP 3 台是否有 `serial` 或等效阻斷，補上讓 IDC 3 台**保證**先完整
   join、GCP 3 台**保證**在那之後才 join。如果能讓 master 選舉 100% 落在 IDC，
   問題 2/3 的一整條連鎖可能都不會發生。
2. 若治本成本高，**次選**：`phase4-ybdb-fix6n` 加一道 fail-closed gate，deploy
   完成後強制查 `yb-admin list_all_masters`（查 LEADER，不要信 FOLLOWER 的 HTTP
   API），驗證剛好 3 台且全 IDC，不符合就自動跑上面驗證過的 ADD_SERVER/
   REMOVE_SERVER 三步驟修正，而非留給人工事後發現。
3. **`current_masters` 快取的通用修法**：不管治本與否，`coldreset-ybdb.sh`（以及
   任何未來會呼叫 `yugabyted stop/start` 的地方）都該在 start 前，用即時查詢
   （`yb-admin list_all_masters` 問任一存活 master 的 LEADER）算出當前真正的
   master 位址清單，動態產生 `--tserver_master_addrs` 等值傳入，而不是依賴
   `yugabyted.conf` 裡可能過期的 `current_masters` 快取欄位。
4. 問題 3 的 postgres 死鎖成因未確認前，**不建議直接重跑 smoke 賭它不會再發生**——
   先照上面的排查起手式定位成因，否則可能又是一次「修完 A 炸 B，修完 B 炸 C」
   的連環。

## 已 commit 的修復（下次重跑自動生效）

| commit | 內容 |
|---|---|
| `44d95c42` | `prepare.sh` grep -c set -e 死鎖二修（`\|\| true`）+ `coldreset-ybdb.sh` 補 `--join` |
| `9f3306fe` | `coldreset-ybdb.sh` 補 catalog-wait 兩個 tserver flags（與 .33/.34 對齊） |

## 本輪 artifact

- `results/x-cross/smoke/early-runs/20260709T041412+0800/`（第一輪 phase1 rebuild proof）
- `results/x-cross/smoke/early-runs/20260709T090535+0800/`（第二輪 phase1 rebuild proof）
- 三次 YBDB smoke 嘗試皆無 `.suite.done`（`.suite.failed` × 3，TS 分別為
  `20260709T095702+0800`、`20260709T101440+0800`、`20260709T102707+0800`），
  VM 已拆，.31 上的 log/artifact 隨 teardown 可能已不可達（未確認是否保留）。
