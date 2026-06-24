# X-CROSS 目錄索引

> `results/x-cross/` 是 `phase-crossregion` 的集中式本機彙整目錄。  
> 正式判讀請以 [`pipeline-log.md`](./pipeline-log.md) 為主；本檔只做快速導覽。

## 目錄分層

| 目錄 | 內容 | 判讀方式 |
|---|---|---|
| [`preflight/time-sync/`](./preflight/time-sync/) | chrony / time server / 前置同步檢查 | 只作跨區前置佐證，不作 benchmark 結果 |
| [`dry-run/`](./dry-run/) | framework probe、wrapper / gate / endpoint dry-run | 驗證流程可跑通，不含正式 go-tpc run |
| [`smoke/early-runs/`](./smoke/early-runs/) | 早期 smoke / partial run | 可追溯建置與修正過程，不納正式結論 |
| [`determinism/`](./determinism/) | same-cluster determinism / CV 觀察 | 目前唯一可引用的 W=4 重現性資料 |

## 建議閱讀順序

1. 先看 [`pipeline-log.md`](./pipeline-log.md) 的目錄歸屬與 TL;DR。
2. 再看 [`determinism/`](./determinism/) 了解目前可引用的重現性觀察。
3. 若要追溯前置檢查，回 [`preflight/time-sync/`](./preflight/time-sync/)。
4. 若要看流程是否跑通，查 [`dry-run/`](./dry-run/)。
5. 若要回顧早期 smoke 與路徑修正，再看 [`smoke/early-runs/`](./smoke/early-runs/)。

## 使用原則

- `results/x-cross/` 內的檔案只作 framework / determinism 證據。
- 目前尚未建立 `summary.json` 正式產線；tpmC 仍以 `go-tpc-stdout.txt` 為準。
- 若要做正式 W=128 跨家排序，必須回到 `phase-crossregion` 重跑，不可直接沿用這裡的 W=4 觀察。

