# YBDB master quorum — 解決方案 + 測試交辦包

> 2026-07-09（Fable 規劃）。前情：`ybdb-master-quorum-handoff.md`（同目錄，先讀）。
> 本文件 = 根因定案 + 修法（**程式碼已寫好、已 commit**）+ 測試步驟 + 交辦 kickoff prompt。
> 執行 session 的工作是**驗證**，不是重新設計。

## 0. TL;DR

- 根因定案：**yugabyted 的 master 選擇是 region-blind 的**（`--cloud_location` 從未設定，
  全節點在 yugabyted 眼裡都是假 zone `cloud1.datacenter1.rack1`），master 擴編發生在
  `configure data_placement --rf=3`，選到 GCP 節點純看註冊順序，2/2 復現非偶發。
- 修法：不賭 yugabyted 自動選擇（它的設計目標「跨 zone 分散」與我們要的「單 zone 集中」
  方向相反），改用**部署後強制手術 gate**：新腳本
  `phase-crossregion/scripts/ybdb-master-quorum-gate.sh` 已接入 `phase4-ybdb-fix6n`，
  fail-closed 強制 raft = 3 台 IDC-only + 全節點 `current_masters` conf 快取校正 +
  6/6 YSQL 健檢（含 postgres 死鎖類問題的證據收集與重啟修復）。
- `tests/common/*` **零改動**（先前兩個 fix `44d95c42`/`9f3306fe` 已在，不需再動禁改檔）。
- 測試 = 本文件 §4 的 Stage 0→A→B→C，全部通過即 YBDB Stage 1 smoke 完成。

## 1. 根因定案（本次規劃 session 讀 playbook/inventory 的新事證）

交接文件遺留兩個懸念，已查明：

**懸念 1「join 序列哪裡沒序列化？」→ 答案：join 有序列化，race 根本不在那裡。**
`ansible/playbooks/yugabyte-vm6.yml` 的 worker join play（line 447-449）**早已 `serial: 1`**，
順序 .33 → .34 → g1 → g2 → g3。race 的真正機制鏈：

1. `.32` bootstrap（`yugabyted start` 無 `--join`）→ yugabyted 預設
   `fault_tolerance=none`，yb-master 以 `--replication_factor=1`、
   `--master_addresses=172.24.40.32:7100`（只有自己）啟動。**ps 實證**（07-09 兩輪皆同）。
2. worker 逐台 join 時，yugabyted 在每台都啟動一個 **shell yb-master process**
   （cmdline 無 `--master_addresses`，未入 raft）——.33/.34 上「本機在跑 yb-master
   但不在共識內」就是這個。
3. 全部 join 完後，Verify play 跑 `yugabyted configure data_placement --rf=3`——
   **master 1→3 的擴編發生在這裡**。它挑哪些節點入 raft 時**沒有 region 概念**：
   playbook 從未給 `yugabyted start` 傳 `--cloud_location`，yugabyted conf 裡全節點
   都是預設假 zone `cloud1.datacenter1.rack1`；而 yugabyted 幫 yb-master 組 cmdline 時
   把自己的假 zone flag 排在使用者 `--master_flags` 的正確 placement flag **之後**
   （gflags 重複時後者 wins，ps 實證），所以連 master 自報的 zone 都是假的。
   結果：挑誰入 raft 純看內部順序，GCP 節點會中選（07-09 兩輪分別是 .12 和 .11），
   且跨區 ADD 部分失敗（playbook line 544 自註「yugabyted v2 fails to add GCP masters
   via this CLI (known limitation)」的另一面）——第二輪實測 raft 一度只有 2 台
   （`.32` + `.12`），.33/.34 的 shell master 從未被加進去。
4. 查 raft membership 的正確姿勢：**只能信 `yb-admin list_all_masters`（它會找 LEADER 問）**；
   FOLLOWER 節點的 HTTP `/api/v1/masters` 回報的是過期 peer 快取（07-09 實證顯示 4 台，
   實際 raft 只有 2 台）。

**懸念 2「current_masters 快取生命週期」→ 答案：部署時寫定、手術不更新、restart 必讀。**
`/var/yugabyte/conf/yugabyted.conf` 的 `current_masters` 欄位在 join 當下寫入，之後
`yb-admin change_master_config` 改了真實 raft **不會**回寫此欄位；任何
`yugabyted stop/start`（`coldreset-ybdb.sh` 正是）都會拿舊值組 `--tserver_master_addrs`，
把 tserver 導向已不存在的 master → YSQL proxy 卡死初始化、5433 永不 bind（07-09 實證，
`sed` 手動校正後立即恢復）。

**為何不治本改 playbook 讓 yugabyted 自己選對？** 就算補上 `--cloud_location`，
yugabyted 的 master placement 邏輯是**跨 zone 分散**（fault-tolerance 導向）；我們要的是
**3 台全集中在 IDC 單一 zone vlan241**（P-A leader-pin 設計）——與工具設計方向相反，
其內部行為版本間也可能變動，賭不得。確定性的做法是部署後用 yb-admin 強制手術
（07-09 已 live 驗證 2/2 有效），做成 fail-closed gate。

## 2. 已落地的修法（本次 commit，執行 session 不需重寫）

| # | 檔案 | 內容 |
|---|---|---|
| F1 | `phase-crossregion/scripts/ybdb-master-quorum-gate.sh`（新） | 六步驟 gate：①dump pre-repair 現況 + 缺席 IDC master 的 `yugabyted.log` 證據 ②`ADD_SERVER` 補齊 IDC（前置檢查 shell yb-master 存在）③`REMOVE_SERVER` 逐出非 IDC（參數序 `<ip> <port> <uuid>`，uuid 最後）④終局 assert 恰 3 台/全 IDC/恰 1 LEADER ⑤全 6 節點 `current_masters` conf 校正 ⑥全 6 節點 YSQL `SELECT 1` 健檢，fail 節點先留 `postgresql-*.log` + backend 清單證據再 `yugabyted stop/start` 修復複檢。冪等；全程 fail-closed；證據落 `.31:/tmp/ybdb-quorum-gate/` |
| F2 | `phase-crossregion/Makefile` `phase4-ybdb-fix6n` | `sleep 60` 之後插入 `ssh .31 "bash $(CROSS_SCRIPTS_REMOTE)/ybdb-master-quorum-gate.sh"`（gate 跑在 .31，.31→全 6 節點 ssh 已 prime；腳本由 phase2-bootstrap 自動 rsync 到位） |

**既有修復（已在 master，會自動生效）**：`44d95c42`（prepare.sh grep -c 二修 +
coldreset `--join`）、`9f3306fe`（coldreset catalog-wait flags）。

**cold-reset 路徑為何不用再改**：gate step ⑤ 把全節點 conf 校正成
`172.24.40.32:7100,172.24.40.33:7100,172.24.40.34:7100` 後，`coldreset-ybdb.sh` 的
`yugabyted stop/start` 讀到的就是正確位址；正確部署下 master set 之後不再變動。
→ `tests/common/` 零改動，不需再走禁改例外授權。

## 3. postgres 死鎖（交接問題 3 尾段）的處理定位

成因仍未定（交接文件假說 a/b/c），但 gate step ⑥ 把它從「15 分鐘 prepare timeout
才間接發現」變成「部署完成當下就直接健檢 + 自動留證據 + 重啟修復」：

- **若假說 b（`current_masters` 陳舊）為真**：step ⑤ 校正 + step ⑥ 重啟即根治。
- **若假說 a（ADD_SERVER 手術對運行中 postgres 的副作用）為真**：gate 每次手術後
  必經 step ⑥，中招節點會被重啟修復；證據（`postgresql-*.log`，07-09 沒讀到的關鍵檔）
  自動落盤供後續根因分析。
- **若重啟修不好**：gate fail-closed 停下，現場證據齊全，不會像 07-09 那樣燒到
  prepare 階段才炸。

## 4. 測試步驟（交辦執行 session 照跑）

### Stage 0 — 靜態（Mac，2 分鐘）
```bash
cd /Users/wn.lin/vscode-git/dba_career/poc
bash -n phase-crossregion/scripts/ybdb-master-quorum-gate.sh        # 預期：無輸出
make -n phase4-ybdb-fix6n | grep -A1 "master-quorum gate"           # 預期：看到 ssh .31 bash .../ybdb-master-quorum-gate.sh
```

### Stage A — 部署 + gate 首驗（~50 分鐘）
```bash
TS=$(ssh root@172.24.40.31 "date +%Y%m%dT%H%M%S%z")
caffeinate -i make -C /Users/wn.lin/vscode-git/dba_career/poc phase1        # ~15m；GCP NOTREADY 卡住見 §5 陷阱 1
caffeinate -i make -C /Users/wn.lin/vscode-git/dba_career/poc phase2        # ~5m；含 gate 腳本 rsync 到 .31
caffeinate -i make -C /Users/wn.lin/vscode-git/dba_career/poc phase4 PLACEMENT=P-A   # ~30m；fix6n 內會自動跑 gate
```
**驗收（缺一不可）**：
1. fix6n log 出現 `quorum gate PASS（raft=3 IDC-only；conf 已校正；6/6 YSQL OK）`。
2. 人工複核（不信 gate 自己）：
   ```bash
   ssh root@172.24.40.32 "/opt/yugabyte/bin/yb-admin --master_addresses=172.24.40.32:7100,172.24.40.33:7100,172.24.40.34:7100 list_all_masters"
   # 預期：恰 3 列，host 全為 172.24.40.3[234]，恰 1 個 LEADER
   ```
3. 收證據（root-cause 素材，commit 進 repo）：
   ```bash
   scp -r root@172.24.40.31:/tmp/ybdb-quorum-gate results/x-cross/smoke/early-runs/$TS-quorum-gate-evidence
   ```
   `masters-before.txt` 應重現「GCP 節點在 raft / IDC 缺席」（第 3 次復現，坐實 race）；
   `yugabyted-172.24.40.3x.log` 是「為何 .33/.34 的 master add 靜默失敗」的第一手素材。
4. 若 gate FAIL：照 log 指示看 `.31:/tmp/ybdb-quorum-gate/`，**同因兩敗即停**整理現場回報。

### Stage B — cold-reset 演練（隔離驗證，~10 分鐘；07-09 三炸有兩炸在這條路徑）
```bash
# 模擬 run.sh 會做的 cold-reset（.31 上以 tests/common 部署副本執行）
ssh root@172.24.40.31 "bash /tmp/poc-tpcc/scripts/coldreset-ybdb.sh --db-host 172.24.40.32"
```
**驗收**：
1. 輸出含 `Node joined a running cluster`、`Replication Factor: 3`、`YSQL Status: Ready`（或等效）。
2. `.32` 的 tserver flags 正確：
   ```bash
   ssh root@172.24.40.32 "ps aux | grep yb-tserver | grep -v grep | grep -o 'tserver_master_addrs=[^ ]*'"
   # 預期：tserver_master_addrs=172.24.40.32:7100,172.24.40.33:7100,172.24.40.34:7100（不得出現 10.160.152.x）
   ```
3. master raft 未被 cold-reset 弄壞：同 Stage A 驗收 2。
4. 6/6 YSQL：
   ```bash
   for ip in 172.24.40.32 172.24.40.33 172.24.40.34 10.160.152.11 10.160.152.12 10.160.152.13; do
     ssh root@$ip "cd /tmp && timeout 15 runuser -u yugabyte -- ysqlsh -h \$HOSTNAME -p 5433 -U yugabyte -d yugabyte -Atc 'SELECT 1'" \
       && echo "$ip OK" || echo "$ip FAIL"
   done   # 注意：-h 用各節點自己的 IP（把 \$HOSTNAME 換成 $ip 逐台帶入）
   ```
   任一 FAIL → 讀該節點 `/var/yugabyte/data/yb-data/tserver/logs/postgresql-*.log` 尾段
   （07-09 未讀到的關鍵檔），留檔後停下回報——這就是交接問題 3 的直接重現，成因素材最珍貴。

### Stage C — 全鏈 smoke（~40 分鐘）
```bash
TS=$(ssh root@172.24.40.31 "date +%Y%m%dT%H%M%S%z")
ssh root@172.24.40.31 "nohup env \
  PHASE_NAME=phase-crossregion RESULT_SCOPE=X-CROSS BASELINE_FAMILY=crossregion tuning_profile_id=default \
  TPCC_TS=$TS PLACEMENT=P-A PROFILE=A-S DB=ybdb CLIENT_ZONE=idc GATE_SKIP=1 \
  DB_HOST=172.24.40.32 DB_PORT=5433 \
  WAREHOUSES=1 ROUNDS=1 THREADS_LIST=16 \
  TPCC_ARTIFACTS=/tmp/poc-tpcc/artifacts/X-CROSS \
  WAN_PROBE_ENABLED=1 WAN_PROBE_IPERF=1 \
  bash /tmp/poc-tpcc/scripts/crossregion/run-vm6-suite.sh --db ybdb --topology vm-6node-P-A --ts $TS \
  > /tmp/poc-tpcc/logs/ybdb-smoke-$TS.log 2>&1 < /dev/null &"
# 輪詢 .suite.done / .suite.failed（ROOT=/tmp/poc-tpcc/artifacts/X-CROSS/ybdb-vm-6node-P-A-rc-$TS）
```
**驗收（照 prompt_next_phase.md Stage 1 口徑）**：`.suite.done` status；placement gate
PASS（`prepare/placement-gate-P-A.{txt,json}`，07-09 的 grep -c 修正首次 live 過此關）；
freeze/unfreeze 痕跡（`freeze-state/` dump + log 行，M5 首驗）；wan-probe 無非預期
failed.txt；`summary.json` tpmC 有值。

### 收尾
```bash
make -C /Users/wn.lin/vscode-git/dba_career/poc phase8.5-static-check TPCC_TS=$TS
make -C /Users/wn.lin/vscode-git/dba_career/poc phase8.5-fetch TPCC_TS=$TS LOCAL_RESULT_CATEGORY=smoke/early-runs
# fetch 後去重：early-runs 只留本輪 $TS 目錄（歷史目錄勿動勿改名）
make -C /Users/wn.lin/vscode-git/dba_career/poc phase9-tunnels-stop phase9-destroy
# commit：data(x-cross): YBDB smoke（git commit -F <file>，不可 -m）
# SESSION-HISTORY.md 記結果（含 gate 首驗結論 + 證據目錄路徑）
```

### Abort 紀律
同因兩敗即停；殘局必做：`.31` 上手動 `unfreeze-ybdb.sh`（若凍結中斷）→ 收 log →
`phase9-tunnels-stop phase9-destroy` → 現場摘要回報。禁止：改 `tests/common/*`（需
user 逐次明確授權）、push、動 tfvars/tfstate、重命名 artifact 目錄、走 IAP tunnel。

## 5. 已知陷阱（07-09 實踩，執行 session 必讀）

1. **phase1 GCP NOTREADY 卡住**：gproxy 對 AlmaLinux mirrorlist 偶發 503，startup-script
   dnf 3 retry 用盡後**已退出不會自癒**。處置：`ssh .31 → ssh <gcp-ip>`，
   `curl -s -H "Metadata-Flavor: Google" http://169.254.169.254/computeMetadata/v1/instance/attributes/startup-script -o /tmp/s.sh && bash /tmp/s.sh`
   （用 `169.254.169.254`；hostname `metadata.google.internal` 可能被 proxy 劫走回 HTML）。
2. **查 master raft 只能用 `yb-admin list_all_masters`**；FOLLOWER 的 HTTP API 是過期快取。
3. **REMOVE_SERVER 參數序**：`change_master_config REMOVE_SERVER <ip> <port> <uuid>`
   （uuid 在最後；放前面會報 `is not a valid number for type l`）。
4. 長跑一律 nohup detach 在 .31（前景 ssh 遇本機 VPN 斷線 → SIGPIPE 141 假死，07-08 實踩）。
5. `git commit -F <file>`（RTK hook 會把 `-m` 訊息換成 "update"）。
6. gate 腳本改動後要重新 rsync 到 .31（`make phase2-bootstrap` 或手動 rsync 到
   `/tmp/poc-tpcc/scripts/crossregion/`），別改了本機忘了同步。

## 6. 交辦 kickoff prompt（直接貼給執行 session）

```
任務：完成 YBDB Stage 1 cross-region smoke（TiDB/CRDB 已完成，YBDB 是最後一家）。
Repo：/Users/wn.lin/vscode-git/dba_career/poc（make 一律 make -C 此路徑）
角色：執行 operator。修法已寫好並 commit，你的工作是照測試計畫驗證，不是重新設計。

開工必讀（順序）：
1. poc/fable-refactor/ybdb-master-quorum-handoff-solution.md（本任務的測試計畫，§4 照跑、§5 陷阱必讀）
2. poc/fable-refactor/ybdb-master-quorum-handoff.md（前情：三個問題的完整脈絡）
3. poc/phase-crossregion/SESSION-HISTORY.md 的 2026-07-08/07-09 各節（既往踩坑）

硬規則（違反即失敗）：
- 禁改 tests/common/*.sh（本任務設計上不需要改；若你認為必須改，停下向 user 要逐次明確授權）
- 不 push；commit 一律 git commit -F <file>；不動 terraform.tfvars/tfstate；不重命名 artifact 目錄
- 環境操作一律 ssh root@172.24.40.31 jump，絕不走 IAP localhost:1221x
- 長跑（>10min）nohup detach 在 .31，Mac 端只做短觸發（配 caffeinate -i）
- 機敏（密碼/token/私鑰）不得出現在任何輸出
- 同因兩敗即停：收 log、解凍、拆 VM、整理現場摘要等 user

執行：照 solution doc §4 Stage 0 → A → B → C 依序跑，每 Stage 驗收全過才進下一
Stage。Stage A 的 gate 證據（masters-before.txt、yugabyted-*.log）scp 回 repo 並
commit——這是 race 第三次復現的 root-cause 素材，比 smoke 數字更重要。Stage B 若
任一節點 YSQL FAIL，讀該節點 postgresql-*.log 留檔回報（這是交接問題 3 的成因素材）。
全部通過後：static-check → fetch（去重）→ phase9 拆 VM → data commit + SESSION-HISTORY
記錄（含 gate 首驗結論）。
```

## 7. 殘留 open items（不擋本輪，記錄備查）

- **假 zone `cloud1.datacenter1.rack1`**：yugabyted conf 層的 cloud_location 仍是預設值
  （master 自報 zone 錯）。tablet placement 由 fix6n 的 `yb-admin modify_placement_info`
  覆寫、tserver flag 順序恰好使用者值 wins，故不影響數據；但這是 06-19「假 zone block」
  bug 的殘根，若未來升級 yugabyted 版本或依賴其 zone-aware 行為，需補 `--cloud_location`。
- **playbook 治本**（讓 yugabyted 原生選對 master）：已評估不做（§1 末段），gate 為長期解。
- **`.33` postgres 死鎖根因**：待 Stage A/B 的證據檔定案（gate 已內建證據收集）。
