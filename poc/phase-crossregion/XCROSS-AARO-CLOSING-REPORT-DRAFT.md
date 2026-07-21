# X-CROSS A-A-RO 結案報告（雛形）— IDC↔GCP Cross-Region 3-DB W=128 A-A-RO 正式測試

> 狀態：**雛形（draft）**。所有數字取自實際執行的 W=128 採樣，無任何模擬/示範資料。
> 產出日：2026-07-21。範圍：A-A-RO（IDC 讀寫＋GCP read-only）profile，
> P-A placement，三家（TiDB／CockroachDB／YugabyteDB）。
>
> **⚠ 證據可及性注意**：本批原始 artifact（`results/x-cross/baseline/w128/20260720T101928+0800/`，
> 121M）依 2026-07-21 拍板暫不進 repo（`.gitignore` 排除，避免肥大）。本報告連結指向
> 該本地路徑，**在未持有此份本地 artifact 的環境（如重新 clone 的 repo）連結會失效**；
> 若後續決議留存，移除 `.gitignore` 該行即可正常 commit、連結即恢復可解析。
>
> 本文標籤同 [XCROSS-CLOSING-REPORT-DRAFT.md](XCROSS-CLOSING-REPORT-DRAFT.md)：`實測事實`／
> `觀察`／`機制推論`／`根因未確認`／`採用決策`／`後續驗證`。

## 1. 執行摘要

1. `採用決策`：正式採用三個 cell——**TiDB／CRDB／YBDB 的 A-A-RO W=128 全輪**（同批
   `TPCC_TS=20260720T101928+0800`，單一 detached driver `win-aaro-w128.sh` 依序
   TiDB→YBDB→CRDB；定義見 §3）。
2. `實測事實`：**三家 IDC 側與 GCP 側全程 0 錯誤**（IDC 逐檔位 `_ERR` 計數與 GCP
   `execute run failed` 計數雙口徑皆為 0；總交易數 TiDB 2,955,895／YBDB 2,124,346／
   CRDB 2,338,604）。
3. `實測事實`：t128 IDC 主水位 tpmC——TiDB **15,182.5**、YBDB **12,882.5**、CRDB
   **11,331.1**；GCP 側 read_tpmTotal——TiDB **31,571.3**、YBDB **56,787.9**、CRDB
   **41,056.3**（§5）。
4. `採用決策`：X-CROSS 於 phase registry 為 `baseline_eligible=false`——本報告數字供
   cross-region A-A-RO 能力與相對量級判讀，不作正式跨家排名（同 §2、§8 O5 慣例）。
5. `後續驗證`：本輪為 A-A-RO 首次真實 W=128 全輪（此前僅 W=4 t16 smoke，見
   [SMOKE-AARO-SUMMARY.md](SMOKE-AARO-SUMMARY.md)）；過程中發現並修復一個新根因
   （`merge-gcp-stdout.sh` stdin 陷阱，§7），修復後 YBDB/CRDB 兩家全程零人工介入
   （TiDB 因觸發此 bug 而人工補救一次，非重跑）。

## 2. 測試目的與範圍

驗證 TiDB / CockroachDB / YugabyteDB 三家分散式 SQL 在 6-node cross-region
（3 IDC + 3 GCP）拓樸、P-A placement 下，**A-A-RO profile**（IDC 端標準 TPCC
讀寫＋GCP 端同時對副本打 read-only workload）的正式 W=128 吞吐與延遲，作為
X-CROSS 階段 A-A-RO 分項的結案數據。

不在本報告範圍：P-B placement、A-A（雙端 RW）profile、failover 演練、跨家
正式排名。P-A×A-S 的結案數據見 [XCROSS-CLOSING-REPORT-DRAFT.md](XCROSS-CLOSING-REPORT-DRAFT.md)。

## 3. 採用 Suite

| 縮寫 | 狀態 | Suite 目錄（本地，見頂部證據可及性注意） |
|---|---|---|
| **TiDB A-A-RO** | ✅ 採用 | `results/x-cross/baseline/w128/20260720T101928+0800/tidb-vm-6node-P-A-aaro-rc-20260720T101928+0800/` |
| **YBDB A-A-RO** | ✅ 採用 | `results/x-cross/baseline/w128/20260720T101928+0800/ybdb-vm-6node-P-A-aaro-rc-20260720T101928+0800/` |
| **CRDB A-A-RO** | ✅ 採用 | `results/x-cross/baseline/w128/20260720T101928+0800/crdb-vm-6node-P-A-aaro-rc-20260720T101928+0800/` |
| TiDB／YBDB／CRDB plain anchor | 備查（prepare-bridge 來源，非正式數據） | 同批 `*-vm-6node-P-A-rc-20260720T101928+0800/`（`ANCHOR_ONLY=1`：僅 prepare+gate，無 workload，§7） |

三家均通過 `check-aaro-artifacts.py`（fail-closed）：`gcp_side` 頂層區塊存在、
`tpmC_mean=null`（G2，RO mix 無 NEW_ORDER）、`read_tpmTotal_mean` 四檔位齊全、
雙側每輪 raw stdout 含 `[Summary]`/`tpmC` 結算行。placement gate 三家皆 idc
majority PASS。

## 4. 測試環境與共同口徑

### 4.1 環境

| 項目 | 值 |
|---|---|
| 拓樸 | 6 DB node = 3 IDC（172.24.40.32-34）+ 3 GCP（10.160.152.11-13）；IDC client = .31；GCP client = .15（g-test-poc-5） |
| Placement | P-A（leader/lease pin IDC） |
| VM 潔淨度 | 全新 `phase1+phase2` 重建，三家依序共用同一批 VM（軟體逐家部署/拆除，非重建 VM，見 §7） |

### 4.2 量測口徑

| 參數 | 值 |
|---|---|
| Workload | go-tpc TPC-C；IDC 端 standard mix；GCP 端 read-only mix（ORDER_STATUS/STOCK_LEVEL 各 50%） |
| WAREHOUSES | 128 |
| Threads 檔位 | 16 / 32 / 64 / 128 |
| Rounds | 每檔 5 輪 × 300s；Warmup 1200s |
| GCP 主指標 | `read_tpmTotal`（G2：非 tpmC，唯讀 mix 下 tpmC 無定義） |
| 雙端合併規則 | G1-G6（[decisions-2026-06-08.md](decisions-2026-06-08.md) 2026-07-15 附錄）：兩地永不合併，GCP 自成 `gcp_side` 頂層區塊 |
| 執行入口 | [`make win-aaro-detach`](Makefile)（driver：[win-aaro-w128.sh](scripts/win-aaro-w128.sh)），TiDB→YBDB→CRDB |

## 5. 主結果

口徑：tpmC/read_tpmTotal 為 R1-R5 mean；range% = (max−min)/mean（非統計 CV，
見 [XCROSS-CLOSING-REPORT-DRAFT.md §5](XCROSS-CLOSING-REPORT-DRAFT.md) 口徑說明）。

### 5.1 IDC 側吞吐（標準 TPCC mix）

| threads | TiDB tpmC (range%) | YBDB tpmC (range%) | CRDB tpmC (range%) |
|---:|---:|---:|---:|
| 16 | 9,439.1 (16.1%) | 6,002.6 (18.6%) | 9,347.7 (13.8%) |
| 32 | 12,833.2 (23.5%) | 7,276.9 (17.8%) | 9,906.0 (18.9%) |
| 64 | 15,702.7 (7.3%) | 12,247.1 (2.6%) | 11,501.7 (8.8%) |
| **128（主水位）** | **15,182.5 (23.6%)** | **12,882.5 (3.1%)** | **11,331.1 (4.0%)** |

`觀察`：TiDB t64→t128 微降（15,702.7→15,182.5）且 t128 range% 偏高（23.6%）；
YBDB/CRDB 皆單調遞增、t128 range% 收斂良好（3.1%/4.0%）。三家全檔位、全輪
**0 錯誤**（IDC `_ERR` 計數與 GCP `execute run failed` 計數雙口徑核實，§1.2）。

### 5.2 GCP 側吞吐（read-only mix）

| threads | TiDB read_tpmTotal | YBDB read_tpmTotal | CRDB read_tpmTotal |
|---:|---:|---:|---:|
| 16 | 8,151.6 | 19,883.7 | 8,831.6 |
| 32 | 14,518.1 | 36,802.0 | 19,320.5 |
| 64 | 26,475.5 | 50,640.1 | 42,095.6 |
| **128** | **31,571.3** | **56,787.9** | **41,056.3** |

`觀察`：三家 GCP 側 read_tpmTotal 皆隨 threads 單調遞增、未見平頂（128 檔位
仍在成長），與 IDC 側同檔位相比：YBDB GCP 吞吐（56,787.9）遠高於其 IDC 側
（12,882.5，約 4.4×）；TiDB／CRDB 的 GCP／IDC 比值分別約 2.1×／3.6×。
`機制推論`：唯讀 mix（僅 ORDER_STATUS/STOCK_LEVEL，無寫入/鎖競爭）本質上
比標準 TPCC mix 輕量，GCP 側單筆延遲更短、同硬體可撐更高吞吐；未以逐筆延遲
分解證實。**GCP 與 IDC 兩側數值不可直接比較大小（G2）**——不同 workload、
不同副本角色，此處僅供觀察兩側量級差異，非效能對比。

### 5.3 結果判讀

| 資料庫 | IDC t128 | GCP t128 read_tpmTotal | 錯誤 | 可引用結論 |
|---|---|---:|---|---|
| TiDB | 15,182.5 tpmC | 31,571.3 | 0 / 2,955,895 | 首次 A-A-RO W=128 全輪，機制驗證成功 |
| YBDB | 12,882.5 tpmC | 56,787.9 | 0 / 2,124,346 | 同上；range% 收斂最佳（3.1%） |
| CRDB | 11,331.1 tpmC | 41,056.3 | 0 / 2,338,604 | 同上；range% 收斂良好（4.0%） |

## 6. 各資料庫觀察

- `觀察`：TiDB t128 range% 23.6% 為三家最高，且 t64→t128 tpmC 微降——與
  [XCROSS-CLOSING-REPORT-DRAFT.md §6.1](XCROSS-CLOSING-REPORT-DRAFT.md) 記載的
  P-A×A-S 下 TiDB 低併發延遲敏感、高併發近線性的形狀不同（此處是 A-A-RO 雙端
  並發下的新場景，GCP 側同時打流量可能改變 IDC 側資源競爭型態）。`根因未確認`
  ——本輪未收集逐輪 mpstat 對照，留待下一輪補強。
- `觀察`：YBDB／CRDB 在 A-A-RO 下的 IDC 側 t128 tpmC（12,882.5／11,331.1）與
  P-A×A-S #3 批（12,769.5／10,163.4，見 [XCROSS-CLOSING-REPORT-DRAFT.md §5.1](XCROSS-CLOSING-REPORT-DRAFT.md)）
  量級相近——`機制推論`：GCP 側的 read-only 流量對 IDC 側寫入路徑影響有限（副本
  同步是既有 raft/paxos 背景成本，read-only 查詢多數走 GCP 本地副本、未回打
  IDC）；跨批比較，未做同批對照實驗，僅供參考。

## 7. 執行紀錄與問題

- `實測事實`：`ANCHOR_ONLY=1` 機制（跳過 freeze/run/collect，僅 prepare+gate）
  首次在真實 W=128 場景驗證有效——TiDB anchor prepare 耗時 ~57 分鐘（資料載入
  本身固定成本，無法省），省下的是後續若整段重跑一次 baseline 才能拿到
  anchor 證據的時間（原設計動機見 [scripts/win-aaro-w128.sh](scripts/win-aaro-w128.sh) 註解）。
- `實測事實`（根因＋修復）：TiDB cell 首次驗證 FAIL——`merge-gcp-stdout.sh` 的
  `while read` 迴圈內 `ssh ... cat ...` 未將 stdin 導向 `/dev/null`，偷走了
  迴圈自身 here-string 輸入，導致 20 筆待合併檔案只處理 1 筆
  （`threads-128/round-1`）。與 SESSION-HISTORY 記載過的 `ybdb-master-quorum-gate.sh`
  同一種陷阱重演。`check-aaro-artifacts.py` 正確 fail-closed 攔下（未讓半套
  artifact 靜默通過）。修復：`< /dev/null`（commit `78796957`）。修復後手動
  補救 TiDB 既有 20/20 raw stdout（IDC/GCP 兩側皆已正確落地，僅合併步驟有誤），
  重生 `summary.json`、重驗 PASS，未重跑 workload；YBDB/CRDB 兩家沿用修好的
  版本，全程零人工介入。
- `實測事實`：三家依序共用同一批 VM（`teardown-{db}` 僅移除 DB 軟體，不動
  terraform/VM），符合 `win-aaro-w128.sh` 設計；VM 僅在批次開始前 `phase1+phase2`
  建一次、批次結束後 `phase9-destroy` 拆一次。

## 8. 效度邊界與未竟事項

| ID | 缺口 | 對結果影響 | 下一步 |
|---|---|---|---|
| A1 | TiDB t128 range% 偏高（23.6%）、t64→t128 微降之機制未確認 | 不影響「0 錯誤、機制可行」的核心判定 | 下一輪加 per-round mpstat/iostat 對照 |
| A2 | 本批僅 N=1（單輪），無同參數重跑驗證重現性 | 數字為單次觀察，不作跨輪穩定性宣稱 | 視排程需要決定是否重跑 |
| A3 | GCP／IDC 兩側量級比較僅為觀察，無 workload-normalized 對照設計 | 不影響本報告範圍內結論 | 若需要「等效負載換算」需獨立設計 |
| A4 | 原始 artifact（121M）依拍板未進 repo（`.gitignore`），report 連結在無本地副本環境會失效 | 不影響本機使用；影響外部可重現性 | 待留存決策；決議保留時移除 `.gitignore` 該行即可 |
| A5 | X-CROSS `baseline_eligible=false` | 數字不得進正式跨家排名 | 恆定約束（同 P-A×A-S 報告 O5） |

## 9. 追溯紀錄

- 執行歷史：[SESSION-HISTORY.md](SESSION-HISTORY.md) 2026-07-18（A-A-RO smoke
  四根因修復）、2026-07-20/21（本輪全跑＋merge-gcp-stdout.sh 修復）
- Smoke 前置：[SMOKE-AARO-SUMMARY.md](SMOKE-AARO-SUMMARY.md)（W=4 t16，07-18）
- Commits：`e2cae9a2`（4 根因修復＋smoke）、`f92d2491`（ANCHOR_ONLY／win-aaro-w128
  driver）、`78796957`（merge-gcp-stdout.sh stdin 修復）
