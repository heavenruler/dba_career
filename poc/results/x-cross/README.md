# X-CROSS 目錄索引

> `results/x-cross/` 是 `phase-crossregion` 的集中式本機彙整目錄。  
> 正式判讀請以 [`pipeline-log.md`](./pipeline-log.md) 為主；本檔只做快速導覽。

## 目錄分層

| 目錄 | 內容 | 判讀方式 |
|---|---|---|
| [`baseline/w128/`](./baseline/w128/) | P-A×A-S 正式 W=128 採用批次（#2/#3 系列） | 以 `summary.json`／raw `go-tpc-stdout*.txt` 為準，見下表 |
| [`preflight/time-sync/`](./preflight/time-sync/) | chrony / time server / 前置同步檢查 | 只作跨區前置佐證，不作 benchmark 結果 |
| [`dry-run/`](./dry-run/) | framework probe、wrapper / gate / endpoint dry-run | 驗證流程可跑通，不含正式 go-tpc run |
| [`smoke/early-runs/`](./smoke/early-runs/) | **目錄名稱沿用早期 smoke 慣例，但現已同時存放已採用的正式 W=128 P-A×A-A-RO／P-B 三 workload suite**（各子目錄含 `summary.json`），與早期 smoke/partial run 混放於同層 | 早期 smoke 子目錄僅供追溯建置與修正過程，不納正式結論；**已採用批次**（見下方清單）以其 `summary.json`／raw `go-tpc-stdout*.txt` 為 X-CROSS 採用數字來源（`baseline_eligible=false`，非 S-BASE/S-K8S 正式 baseline） |
| [`determinism/`](./determinism/) | same-cluster determinism / CV 觀察 | W=4 重現性資料 |

**已採用批次（W=128，`N=1`，`baseline_eligible=false`，皆屬 X-CROSS 探索性 scope）：**

| Placement | Workload | 採用批次 TS | 結案報告 |
|---|---|---|---|
| P-A | A-S | `baseline/w128/20260717T143238+0800/`（#3 批，同批三家；前代 `20260712T164221+0800`／`20260714T*` 轉備查） | [XCROSS-CLOSING-REPORT-DRAFT.md](../../phase-crossregion/XCROSS-CLOSING-REPORT-DRAFT.md) |
| P-A | A-A-RO（修正後） | `smoke/early-runs/20260723T133843+0800/` | [XCROSS-AARO-CLOSING-REPORT-DRAFT.md](../../phase-crossregion/XCROSS-AARO-CLOSING-REPORT-DRAFT.md) |
| P-B | A-S | `smoke/early-runs/20260727T223650+0800/` | [XCROSS-PB-AS-CLOSING-REPORT-DRAFT.md](../../phase-crossregion/XCROSS-PB-AS-CLOSING-REPORT-DRAFT.md) |
| P-B | A-A-RO | `smoke/early-runs/20260730T094406+0800/` | [XCROSS-PB-AARO-CLOSING-REPORT-DRAFT.md](../../phase-crossregion/XCROSS-PB-AARO-CLOSING-REPORT-DRAFT.md) |
| P-B | A-A | `smoke/early-runs/20260731T204801+0800/` | [XCROSS-PB-AA-CLOSING-REPORT-DRAFT.md](../../phase-crossregion/XCROSS-PB-AA-CLOSING-REPORT-DRAFT.md) |

P-B 三 workload 彙整見 [XCROSS-PB-ALL-WORKLOADS-SUMMARY.md](../../phase-crossregion/XCROSS-PB-ALL-WORKLOADS-SUMMARY.md)。**不可**重新命名上述任何目錄；未列入此表的 `smoke/early-runs/` 子目錄一律視為早期 smoke／partial run／中斷重試殘留，不作 X-CROSS 採用數字來源。

## 建議閱讀順序

1. 先看 [`pipeline-log.md`](./pipeline-log.md) 的目錄歸屬與 TL;DR。
2. 若要看已採用的正式 W=128 P-A/P-B 結果，直接查上表對應批次的 `summary.json` 與結案報告。
3. 若要了解 W=4 重現性觀察，看 [`determinism/`](./determinism/)。
4. 若要追溯前置檢查，回 [`preflight/time-sync/`](./preflight/time-sync/)。
5. 若要看流程是否跑通，查 [`dry-run/`](./dry-run/)。
6. 若要回顧早期 smoke 與路徑修正歷程，再看 [`smoke/early-runs/`](./smoke/early-runs/) 中未列入上表的子目錄。

## 使用原則

- `results/x-cross/` 內除上表列出的已採用批次外，其餘檔案只作 framework / determinism / 早期 smoke 證據。
- 已採用批次各自含 `summary.json`；tpmC / p95 / p99 / 錯誤率一律以該檔與對應 raw `go-tpc-stdout*.txt` 為準，不得手動摘錄後脫離來源引用。
- 這些是 X-CROSS 探索性結果（`baseline_eligible=false`、各 profile `N=1`），不可作為 S-BASE 正式跨家排名；若要做正式跨家排序，仍須回到 `phase-crossregion` 依 PoC-DESIGN 規範另行設計對照實驗。
- 不可重新命名、刪除或覆寫任何既有批次目錄。

