# 修復執行計畫 — poc/ 健檢（2026-07-06）

> 粒度：每步可由 Opus/Sonnet 獨立照做，含精確位置、修法、驗收命令。
> 全程規則：**絕不 commit 到 master**（一律 spike/fix branch）；不動 `tests/common/*`、`terraform.tfvars`、`*.tfstate`；commit 用 `git commit -F <msgfile>`（RTK 會改寫 `-m`）；每步修完跑該步驗收 + `git status --short` 確認只動了預期檔案。
> 依據：finding 編號對應 `healthcheck-report.md`；決策依據見 `decisions.md`；動手前讀 `risks.md`。

## S1. 【已做，spike branch】POC 示範：iperf3 註解與埠對齊（P3-1 部分 + P2-3）

分支 `spike/healthcheck-poc`（見報告尾註）。內容：
- `phase-crossregion/scripts/wan-probe.sh:26,245`：註解改為「20170 = R8 range 內既定閒置埠；5201 實測亦可達（2026-07-03，SESSION-HISTORY 勘誤），非改埠原因」
- `phase-crossregion/scripts/idc-iperf3-bootstrap.sh`：`IPERF_PORT` 預設 5201→20170，header 註解同步

驗收：
```bash
bash -n poc/phase-crossregion/scripts/wan-probe.sh poc/phase-crossregion/scripts/idc-iperf3-bootstrap.sh
bash poc/phase-crossregion/scripts/idc-iperf3-bootstrap.sh --dry-run | grep 'port=20170'
grep -c '未開通' poc/phase-crossregion/scripts/wan-probe.sh   # 預期 0
```

## S2+S2b. 【已完成，fix/s2-s2b-pathc-daemon @ edd6d5b4】Path C 刪除 + main.tf 拆常駐 + 埠統一 19999

S2（R2 拍板=刪）：刪 `phase-warmup-only-{tidb,crdb,ybdb}`、`phase-roundrun-only-*`、orchestrator `phase-c-validate-hypothesis`、`phase-c-cv-report`、`run-round-only.sh`；`.PHONY` 同步移除。保留 `phase-freeze-*`/`phase-smoke-only-*`/`phase-leader-gate-tidb-postprepare`（非本鏈成員，`phase-smoke-only-*` 走 `run.sh` 直連未受影響，只更新其 DEPRECATED 提示不再指向已刪目標）。

S2b（R1 拍板=拆常駐）：`iac-gcp/main.tf` 刪 `iperf3-server.service` 常駐段，保留 binary 安裝。

**併同補做 M1**（spike `5cd6d6d8` 從未真正合入 master，執行前才發現）：`wan-probe.sh`/`idc-iperf3-bootstrap.sh` 的「5201 未開通」錯誤前提改勘誤敘述；`IPERF_PORT` 統一 **19999**（非 spike 原寫的 20170，因 D9 埠已改拍板）。

驗收（已過）：Path C 殘留 grep = 0；`bash -n` 全過；`terraform validate`+`fmt -check` PASS；`idc-iperf3-bootstrap.sh --dry-run` 確認 unit 埠=19999、`--install-only` 仍只裝 binary；`make -n` 對 `phase-freeze-tidb`/`phase-smoke-only-tidb`/`phase-leader-gate-tidb-postprepare`/`phase-crossregion-w128-suite` 皆展開正常（未誤刪依賴）。**未 live 驗證**：19999 埠+binary-only 需下次 phase1 rebuild 才生效。
```

## S3. 【P1-5 + B 全部】.PHONY 補宣告（Sonnet/Haiku 可做）

`phase-crossregion/Makefile` 為以下 6 個 target 補 .PHONY（加入既有 .PHONY 行或新開一行）：
`phase8.5-fetch`、`phase-cleanup-tidb`、`phase-cleanup-crdb`、`phase-cleanup-ybdb`、`phase2-iperf3-idc`、`phase0-preflight-fix-only-processes`

驗收：
```bash
for t in phase8.5-fetch phase-cleanup-tidb phase-cleanup-crdb phase-cleanup-ybdb phase2-iperf3-idc phase0-preflight-fix-only-processes; do
  grep -l "\.PHONY.*$t" poc/phase-crossregion/Makefile >/dev/null && echo "OK $t" || echo "MISS $t"
done
# 行為不變檢查：修改前後各跑一次，diff 必須為空
make -C poc -n phase8.5-fetch TPCC_TS=dummy > /tmp/before.txt 2>&1  # （修改前先存）
```

## S4. 【已完成，fix/sweep-archive-via31 @ 8195c64d】sweep-archive.sh 去 IAP（P0-2）

`scripts/sweep-archive.sh` 跑在 Mac（非 .31，本身還做本機 terraform destroy），故非 wan-probe.sh 的單跳 `ssh_gcp`（那是跑在 .31 上），而是比照 **Mac 側既有 ProxyJump 樣板**（`check-homogeneity.sh` / `gate-chrony-cross-region.sh`）：`ssh -o ProxyJump=root@172.24.40.31 root@10.160.152.15`。新增 `JUMP_HOST`/`GCP_CLIENT_HOST` env，移除 `GCP_CLIENT_PORT`(12215)/`GCP_CLIENT_SSH_KEY`。

驗收（已過）：`bash -n` PASS；`grep 1221x` = 0；合成 `.suite.done` 資料跑 `--dry-run` 全 7 步 PASS，rsync 命令實際印出正確走 ProxyJump→10.160.152.15。
（live 驗收待下輪真實 sweep 收檔時實跑一次——這是 150h sweep 收尾腳本，目前尚無對應 live 窗口。）

## S5. 【已完成，fix/s5-ybdb-safety @ 24a59df5】YBDB/cleanup 安全對齊（P0-3+P1-1+P1-2+P1-3）

5a. `cleanup-ybdb.sh` 重寫為 `cleanup-crdb.sh` 兩段式結構（CLEANUP_CMD+VERIFY_CMD），補 VERIFY（確認無 yb-master/yb-tserver 進程）；順帶消掉舊版 GCP 側巢狀引號的脆弱 inline 命令。
5b. `freeze/freeze-ybdb.sh` + `unfreeze-ybdb.sh` 的 `SSH=` 補 `-o StrictHostKeyChecking=accept-new`（已完成）。
5c. cleanup-{tidb,crdb}.sh 的 `StrictHostKeyChecking=no`（實際 16 處，非原估 11）全改 `accept-new`；ybdb 新版直接寫 accept-new（行為變化見 risks R6）。
5d. `run-vm6-suite.sh` ybdb 分支改呼叫 `freeze/freeze-ybdb.sh`/`unfreeze-ybdb.sh`（拿到 idle 確認）：freeze 保持無 `|| true`（fail-closed，同 TiDB FREEZE_SCRIPT）、unfreeze 保持 `|| true`（best-effort）。**未 live 驗證**（需下輪 YBDB smoke 視窗）。

驗收（已過）：`grep VERIFY_CMD` 有輸出；`grep StrictHostKeyChecking=no` 於 cleanup 三檔 = 0；freeze/unfreeze-ybdb.sh 皆 accept-new；`set_load_balancer_enabled` 只剩 freeze/unfreeze script 內；`bash -n` 全過；CLEANUP_CMD/VERIFY_CMD 字串抽出後額外做語法+本機功能驗證（VERIFY_CMD 乾淨機器印 OK exit=0）。

**意外發現（範圍外，未修）**：`check-gcp-via-31.sh` 亦有 2 處 `StrictHostKeyChecking=no`，不在原 P1-3 finding 點名清單（只列 cleanup-{tidb,crdb,ybdb}）。留待未來收斂批次處理，不在此次擴大範圍。

## S6. 【P3-1 + P3-2】文件矛盾勘誤（Haiku 可做，純文字）

6a. `SESSION-HISTORY.md:64` 該段句尾加註「（07-03 勘誤：5201 實測可達，見文末 2026-07-03 節）」——不刪原文（歷史紀錄），只加指標。
6b. `results/x-cross/pipeline-log.md` §4:91「目前沒有 summary.json」改為「determinism（06-26 retrofit）與 baseline/w128（07-03）已有 summary.json；更早期資料點仍無」。§7 變更紀錄加一行。

驗收：
```bash
grep -n '勘誤' poc/phase-crossregion/SESSION-HISTORY.md | head -3
grep -n '目前沒有 summary.json' poc/results/x-cross/pipeline-log.md   # 0 hit
```

## S7. 【P3-3】tracked .pyc 移出版控（Haiku 可做）

```bash
git rm -r --cached poc/tpmc-report/__pycache__/
echo '__pycache__/' >> poc/tpmc-report/.gitignore   # 或 repo 根 .gitignore，先查有無既有規則
```
驗收：`git ls-files '*.pyc'` 為空；`git status --short` 顯示預期的 D + .gitignore 修改。

## S8. 【已完成，fix/s8-consolidation】收斂與清理

- **P2-1**：新增 `freeze/lib-pd-drain.sh` 共用函式 `pd_drain_wait`，`freeze-tidb.sh`/`run-vm6-suite.sh` 都改呼叫它。**未統一成 300s**——查 SESSION-HISTORY 07-02 節發現 150s(freeze-tidb 內) vs 300s(wrapper pre-freeze) 是 bug #14 修復時的**刻意設計**（明載「freeze 內 150s 語意不動」），故只抽共用 code、保留兩邊各自的超時值。這是對本文件先前「建議取 300s」的修正——原建議未查證這段歷史。
- **P2-2**：`tidb-vm6.yml` 的 RF-wait 段（task name + shell 內 3 處 `"3"`）改 `{{ tidb_replicas }}`，比照 `tidb-vm3.yml` 既有樣板。
- **P2-4**：`tidb-vm3.yml` 與 `tidb-vm6.yml` 的 TiKV-wait 段各 2 處 `tiup cluster display tpcc-tidb-vm{3,6}` 硬編碼改 `{{ tidb_cluster_name }}`（**vm3 也有此問題，非僅 vm6**——原 finding 只點名 vm6 不精確）。
- **P2-5**：不強推統一，維持 S5b 範圍；額外把 R7（`check-gcp-via-31.sh` 2 處 `=no`）一併修為 `accept-new`（risks.md 明載留待 S8）——**全專案 shell 腳本的 `StrictHostKeyChecking=no` 至此歸零**（`ansible/inventory/crossregion-via31.ini` 的 `ansible_ssh_common_args` 另一機制，`UserKnownHostsFile=/dev/null` 使其無狀態累積風險，判斷不同於腳本內 `=no`，未動）。
- **P3-4**：README.md 補一句說明 `.sh`（早期版）與 Go 版（F8 新版，monotonic + jitter 統計）`probe-rto-driver` 的取捨，接線目標是 Go 版。
- **P3-5**：`wan/baseline-measurement.md` 已有 supersede 頂部橫幅 + Pending 段落點名兩個不存在腳本（已足夠清楚，未再加註）；IAP tunnel 那行加 DEPRECATED 註記。
- **P3-6**：**原「孤兒 target 5 個」finding 為誤判，已本體覆核推翻**——`new-idc-vms`/`new-gcp-vms`/`gcp-wait-startup`/`ansible-ping`/`phase0-preflight-fix-only-processes` 皆在 `phase-crossregion/Makefile` 有真實定義與 body（從 `Makefile.tc1` 複製非 include），是合法的 operator 直接呼叫 leaf target，非死碼，**未加任何標記**。playbooks 頂部（tidb/yugabyte/cockroach-vm6.yml）過時 IAP 註解已加 DEPRECATED 說明；**`host-resolution.sh:22` 在 `tests/common/` 禁改清單內，即使只是註解也未觸碰**。
- **P3-7**：`172.24.40.25`/`.17` 殘留擴大確認為 14 個檔案（原估更少），但全部落在 `tidb/report/`、`tidb/tmp/`——與 phase-crossregion 完全無關的個人歷史 scratch 材料，**判斷不動**（不順手重構無關程式）。

驗收（已過）：`bash -n` 全過（含新 lib）；`pd_drain_wait` 用 mock curl/jq 做功能測試（drained + timeout 兩路徑皆驗證正確）；`ansible-playbook --syntax-check`（環境實際可用，非原估的「未驗證」）對 4 個 playbook 全 PASS；`grep StrictHostKeyChecking=no` 於全部 shell 腳本 = 0。

## S9. 【⏸ PENDING（2026-07-08 使用者裁定）】PROFILE token 命名實作（與 Win-2 gap#1 A-A 接線綁做）

**狀態：刻意延後，非遺漏。** 方案已 100% 定案（Q17），做法/驗收皆已寫好，隨時可執行——但實作對象（Makefile ROOT 拼接、`run-vm6-suite.sh`/`win-tidb-as-w128.sh` 的 crdb/ybdb 對應、`promotion-gate.sh`）只在 Win-2（A-A/A-A-RO）開跑前才有意義驗證，Win-1（A-S，目前唯一在跑的 profile）完全不受影響、不需要這個改動。提前做不會被 Win-1 的 A-S smoke/正式跑驗證到，等於是「寫了但沒人驗」的死碼窗口期——延後到 Win-2 prep 才做，做完立刻有 A-A dry-run 可驗，風險更低。

方案定案見 decisions Q17：A-S token-less（不變）、A-A→`-aa-`、A-A-RO→`-aaro-`，插在 placement 與 `rc` 之間；token 藏 topology 段 → **tests/common 三檔（common.sh/run.sh/summary-from-stdout.py）零改動**。

做法（皆可改檔）：
1. 引入 `PROFILE` make-var（`PROFILE ?= A-S`）+ 派生 `PROFILE_TOKEN`（A-S→空、A-A→`-aa`、A-A-RO→`-aaro`）。
2. Makefile ~13 處 `{db}-vm-6node-$(PLACEMENT)-$(ISO)-$(TPCC_TS)` → 插入 `$(PROFILE_TOKEN)`（placement 與 ISO 之間）。清單見 decisions Q17 觸點 + 觸點 agent 報告（phase6/7/8 smoke+result、win-*-status、smoke-only×3 已 DEPRECATED 可略）。
3. `run-vm6-suite.sh:115`、`win-tidb-as-w128.sh:49`(+crdb/ybdb 對應)：同樣依 PROFILE 派生 token 插入 ROOT。
4. `promotion-gate.sh`：現行 #1/#2 glob（`P-A-rc-*`/`P-B-rc-*`）針對 A-S/P-B baseline **不動**；A-A/A-A-RO 若要納入 promotion 另加對應 glob。

驗收：
```bash
# A-S 零迴歸：改前後 make -n 輸出 diff 為空
make -C poc -n win-tidb-as-status PLACEMENT=P-A TPCC_TS=dummy > /tmp/as-before.txt   # 改前存
# A-A 生效：
make -C poc -n <aa-target> PLACEMENT=P-A PROFILE=A-A TPCC_TS=dummy | grep -- '-aa-rc-'
bash -n phase-crossregion/scripts/{run-vm6-suite,win-tidb-as-w128}.sh
# tests/common 未被碰：
git status --short | grep tests/common   # 必須為空
```
**綁做**：與 Win-2 gap#1（`run-vm6-aa.sh` 接 Makefile）同一 PR；先驗 FW 涵蓋 .31→GCP client SSH（A-A 雙 client 前置）。

## 執行順序建議

S1（已完成 2591f33e）→ S3+S6+S7（已完成 ee3e014f）→ S4（已完成 8195c64d）→ S5（已完成 24a59df5，5d 待 YBDB smoke live 驗）→ S2+S2b（已完成 edd6d5b4，含補做 M1，19999 埠待 phase1 rebuild live 驗）→ S8（已完成 ae1a55f8）→ 額外修復 CRDB freeze 接線（d73cac65，2026-07-08 盤點 smoke 前置時發現）→ **S9（⏸ PENDING，Win-2 prep 才做）**。

**S1-S8 + CRDB freeze 修復＝Fable 健檢全部靜態修復完成**。CRDB/YBDB smoke dry-run（Stage 1）現在可以開始，S9 不擋路。
每個 PR 合併前在 spike/fix branch 上跑該步驗收命令並貼輸出。
