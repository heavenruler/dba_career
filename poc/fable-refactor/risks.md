# 風險與未解清單 — poc/ 健檢（2026-07-06）

## 需使用者拍板的架構問題（健檢不代決）

### R1. iperf3 server 架構二選一（P1-4 的根）→ ✅ 已拍板（2026-07-07，見 decisions D9）
**裁定：拆 main.tf 常駐段 + iperf3 埠改 19999**。cloud-init 仍裝 binary、不起常駐 daemon；埠離開 TiKV range 移到專用 19999（干擾由時序 gate 解決，改埠純衛生）。原「5201 是否有其他消費者」的未解點因選擇拆除而不再阻塞。

### R2. Path C（P0-1）修 or 廢 → ✅ 已拍板（2026-07-07，見 decisions D9）
**裁定：刪除**（warmup-only×3 + roundrun-only×3 + orchestrator + run-round-only.sh + README 提及）。Wave 4 走 run-vm6-suite 正式路徑，Path C 無回歸價值。

### R3. cleanup-crdb 只清 3 GCP IP 是否正確
若 CRDB 拓撲確實不碰 .14/.15，現狀正確只是不對稱；若曾在 .14/.15 裝過 HAProxy/client 側組件則有殘留風險。**未驗證**（需 live 環境或部署紀錄確認）。

### R7（S5 發現，✅ S8 已修）：`check-gcp-via-31.sh` 亦有 2 處 `StrictHostKeyChecking=no`
原健檢 P1-3 finding 只點名 cleanup-{tidb,crdb,ybdb}，未涵蓋此檔（掃描盲點）。已於 S8 改 `accept-new`（fix/s8-consolidation）。全專案 shell 腳本 `=no` 至此歸零；`ansible/inventory/crossregion-via31.ini` 的 `ansible_ssh_common_args` 用 `UserKnownHostsFile=/dev/null` 搭配 `=no`，無跨代 VM 信任累積風險，性質不同，判斷不動。

## 修復本身的風險

### R4. spike POC 未 live 驗證
POC-1/POC-2（見 plan S1）只有靜態驗證（bash -n、--dry-run）。iperf3 完整雙向 JSON 流程本來就等 all-phase 兩地 VM 全建後才做（07-03 拍板 standby）——屆時才是 POC-2 的 live 首驗。

### R5. .PHONY 批量補宣告的副作用
補 .PHONY 理論上零風險（這些 target 本就該是 phony），但 1447 行 Makefile 沒有測試防護網；建議修完跑 `make -n <target>` 全清單比對修改前後輸出（plan S3 驗收含此）。

### R6. StrictHostKeyChecking=no → accept-new 的行為變化
cleanup 腳本改 `accept-new` 後，若 VM rebuild 造成 known_hosts 舊 key 衝突，cleanup 會**開始報錯**（原 `=no` 靜默通過）。這是要的行為（fail-closed），但既有 runbook 若依賴「cleanup 從不因 key 卡住」需同步認知。phase1-wait-via-31 已有自動清 stale key 機制可擋大多數情況。

## 未驗證清單（誠實聲明）

| 項 | 狀態 |
|---|---|
| 90 個 YAML 完整語法 | 只做基本結構檢查（本機無 PyYAML/yamllint）。補法：`pip install pyyaml` 後重跑掃描 A 的第 3 步 |
| ~~ansible playbook 語法~~ | ✅ **已補驗**（S8 發現本機實有 `ansible-playbook`）：對 tidb-vm3/vm6、yugabyte-vm6、cockroach-vm6 跑 `--syntax-check` 全 PASS（inventory 缺失只產生 WARNING 不影響語法驗證結果）|
| P1-1（YBDB inline freeze 無 idle 確認）對量測數據的實際影響幅度 | 靜態確認兩路徑語義不同，但 LB 搬遷對 tpmC 的實際干擾量需 live 對照實驗 |
| E 交叉表的長尾數字（如 172.24.40.32 ×199 次的每一處） | 只抽查了關鍵交集，未逐條複核 |
| Path C 最後一次成功執行的時間 | 未考古 git log 全史 |

## 已知但明確不處理（見 decisions.md D8）
prepare/run-all 32 檔鏡像、log 函式不共用、tests/common 一切、Makefile.tc1/tunnel.sh 刪除。
（main.tf 5201 與 Path C 已於 D9 拍板改為「處理」——見 R1/R2。）

## R8（2026-07-08 發現，✅ 已修 d73cac65）：CRDB steady-state freeze/unfreeze 從未接線
盤點 CRDB/YBDB smoke dry-run 前置條件時發現：`run-vm6-suite.sh` 的 crdb case 分支只做 placement apply + lease-holder 收斂 gate，**完全沒有呼叫** `freeze-crdb.sh`/`unfreeze-crdb.sh`（兩檔本身完好、fail-closed，只是從未被任何 runtime 路徑呼叫）。比健檢已修的 P1-1（YBDB inline freeze 缺 idle 確認）更嚴重——YBDB 至少有呼叫，CRDB 是完全沒有。已比照 YBDB 模式接線（案例分支呼叫 freeze-crdb.sh fail-closed；post-run 對稱呼叫 unfreeze-crdb.sh best-effort）。**未 live 驗證**，需 Stage 1 CRDB smoke 確認。

## R9（2026-07-08 發現，未修，範圍外）：`_suite_failed()` 失敗兜底解凍只認 TiDB
`run-vm6-suite.sh` 的 `_suite_failed()` trap（wrapper 中途崩潰時的保險絲）只檢查 `pd-config-before.json`（TiDB 專屬），CRDB/YBDB 若在 freeze 之後、unfreeze 之前崩潰，會停留在凍結狀態直到下次 cleanup 才清掉。此為既存缺口（R8 修復前就存在，非新引入），CRDB freeze 接線後這個風險視窗才變得「真的可能發生」（之前 CRDB 從不 freeze，自然也不會卡在凍結態）。留待後續一併補強（比照 TiDB 模式擴充 trap 判斷邏輯）。

## R10（2026-07-08，對照 `results/x-cross/demo/x-cross-report-demo.md` TL;DR 需求）：報表格式 vs 現行採樣落差
逐條核對 demo report §6.4 correctness gate 與 §D 就近讀寫 checklist 對現行程式碼：
- **報表偏樂觀**（"[MEASURED]（schema 已落地）"但實際缺欄位）：`summary.json` 缺 `expected_rounds`/`observed_rounds`/`complete`/`incomplete_reason`/`controller_host` 5 個欄位——`tests/common/summary-from-stdout.py` 目前只有 `manifest_sha256`。這些欄位若要在 Wave 6 report 產出前補齊，屬 `tests/common/` 禁改清單，需另案處理（不在本次 fable-refactor 範圍）。
- **報表偏悲觀（已過時）**："Client / system saturation evidence — MISSING" 這條標記於 06-30，但 `tests/common/run.sh`（07-02 起陸續補齊）**現在已經**每 round 對 client(.31) + 每個 DB host（含 GCP fan-out）採樣 mpstat/iostat/vmstat/sar-net/free——CPU/disk/network/memory 面已覆蓋。**仍真的缺**：DB 內部 queue/lock/retry 指標（TiDB TIDB_TRX、CRDB contention view、YBDB pg_locks 等價物皆未採樣，全域搜尋 0 命中）。
- **D1-D7 checklist**：核對 `tests/common/prepare.sh` §6.5/§6.6，三家 placement gate（D3）+ 就近讀 SET（D4/D5）確實已落地（與 changelog 07-06-30 條目一致）；`probe-iso-latency.sh`（D6）+ `netflow-snapshot.sh`（D7）也已接進 `run.sh` per-round hook。**這部分報表與程式碼一致，不是落差**。
- **Data integrity TPC-C 檢查**：`prepare.sh` 有 pre-run 的 `go-tpc tpcc check --check-all`（TiDB/CRDB）+ row-count check（YBDB），但這是**驗資料載入後的結構完整性**，不是報表要的**post-run**（驗計時工作負載跑完後沒壞資料）；報表 `[PLANNED]` 標記對 post-run 這條仍準確，但有現成的 building block（go-tpc check-all）可重用於未來補 post-run gate。
- 結論：現行採樣**足以支撐 W=128 A-S 正式 cell 的 TL;DR §A tpmC 表**（tpmC/p99/error rate + 系統面 + WAN + placement 皆已覆蓋）；**尚不足以支撐** summary.json 的「markers 依序」「controller audit」欄位式驗證與 DB 內部 queue/lock 觀察——這兩塊屬 Wave 6 report 產出前的 framework patch，非本次 smoke 就緒範圍。
