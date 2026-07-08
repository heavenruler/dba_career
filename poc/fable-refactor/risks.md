# 風險與未解清單 — poc/ 健檢（2026-07-06）

## 需使用者拍板的架構問題（健檢不代決）

### R1. iperf3 server 架構二選一（P1-4 的根）→ ✅ 已拍板（2026-07-07，見 decisions D9）
**裁定：拆 main.tf 常駐段 + iperf3 埠改 19999**。cloud-init 仍裝 binary、不起常駐 daemon；埠離開 TiKV range 移到專用 19999（干擾由時序 gate 解決，改埠純衛生）。原「5201 是否有其他消費者」的未解點因選擇拆除而不再阻塞。

### R2. Path C（P0-1）修 or 廢 → ✅ 已拍板（2026-07-07，見 decisions D9）
**裁定：刪除**（warmup-only×3 + roundrun-only×3 + orchestrator + run-round-only.sh + README 提及）。Wave 4 走 run-vm6-suite 正式路徑，Path C 無回歸價值。

### R3. cleanup-crdb 只清 3 GCP IP 是否正確
若 CRDB 拓撲確實不碰 .14/.15，現狀正確只是不對稱；若曾在 .14/.15 裝過 HAProxy/client 側組件則有殘留風險。**未驗證**（需 live 環境或部署紀錄確認）。

### R7（新，S5 執行中發現）：`check-gcp-via-31.sh` 亦有 2 處 `StrictHostKeyChecking=no`
原健檢 P1-3 finding 只點名 cleanup-{tidb,crdb,ybdb}，未涵蓋此檔（掃描盲點）。S5 範圍已鎖定不擴大處理；比照 P1-3 的理由，這裡也該改 `accept-new`，留待下一收斂批次（S8 或新批次）一併修。

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
| ansible playbook 語法（ansible-playbook --syntax-check） | 未跑（需 ansible 環境與 inventory，部分 inventory 在 .31） |
| P1-1（YBDB inline freeze 無 idle 確認）對量測數據的實際影響幅度 | 靜態確認兩路徑語義不同，但 LB 搬遷對 tpmC 的實際干擾量需 live 對照實驗 |
| E 交叉表的長尾數字（如 172.24.40.32 ×199 次的每一處） | 只抽查了關鍵交集，未逐條複核 |
| Path C 最後一次成功執行的時間 | 未考古 git log 全史 |

## 已知但明確不處理（見 decisions.md D8）
prepare/run-all 32 檔鏡像、log 函式不共用、tests/common 一切、Makefile.tc1/tunnel.sh 刪除。
（main.tf 5201 與 Path C 已於 D9 拍板改為「處理」——見 R1/R2。）
