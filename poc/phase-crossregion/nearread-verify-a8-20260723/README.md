# codex §5.6 (2)(3) 補強驗證——原始輸出（2026-07-22/23）

回應使用者拍板順序（先補驗證再決定 aaro#2）：TiDB 嚴格 A/B、staleness/
freshness（codex §5.6 (2)(3)），外加 YBDB go-tpc 反事實（驗證拿掉
go-tpc-readonly-fix.patch 後 YBDB 是否也像 CRDB 一樣近讀失效）。

執行過程分三段 driver 呼叫（原因見下），非單次連續 log：

| 檔案 | 內容 | 對應 driver 呼叫 |
|---|---|---|
| `tidb-zone-ab-and-staleness.log` | TiDB staleness + 4 組 zone A/B（unified/mismatched × closest/leader）原始輸出 | 第 1 次（`DBS=tidb ybdb crdb`） |
| `ybdb-staleness.log` | YBDB staleness 原始輸出 | 第 3 次（`DBS=ybdb crdb`，前兩次卡在 gcp-replica-gate 已知 flaky） |
| `ybdb-gotpc-nopatch-run.log` | YBDB 未套 go-tpc patch 的真實 aaro-smoke 完整輸出（IDC+GCP 兩側） | 第 3 次 |
| `ybdb-gotpc-patched-run.log` | 套用 patch 後同組參數重跑的完整輸出 | 手動補跑（見下） |
| `ybdb-netflow-{pre,post}-patched.json` | 套 patch 後那輪的 netflow byte 快照 | 手動補跑 |
| `crdb-staleness.log` | CRDB staleness 原始輸出 | 第 4 次（`DBS=crdb`） |
| `crdb-driver-log.log` | CRDB 段完整 driver log（deploy/prepare/staleness/teardown） | 第 4 次 |

## 為什麼分成多次 driver 呼叫（過程插曲，誠實記錄）

1. **第 1 次**（`DBS=tidb ybdb crdb`）跑完 TiDB 全段後，YBDB 在
   `gcp-replica-gate` 卡住（`gcp_tservers_with_sst=2`，需要 3）——與
   [XCROSS-AARO-CLOSING-REPORT-DRAFT.md §8 A9](../XCROSS-AARO-CLOSING-REPORT-DRAFT.md)
   記載的已知機率性 flaky 同一模式，非新問題。TiDB 結果在此之前已完整
   落地，不受影響。
2. **第 2 次**（`teardown-ybdb` + 重跑 `DBS=ybdb crdb`）YBDB 又卡在同一個
   gate——連續第 2 次未通過（歷史紀錄是 3 次裡 2 次卡、1 次過）。
3. **第 3 次**（再次 `teardown-ybdb` + 重跑）gate 通過，YBDB staleness
   跑完，但 driver 腳本本身在 `count_err()`（YBDB go-tpc 反事實的錯誤
   計數輔助函式）踩到一個真 bug：`pipefail` 下 grep 找不到任何 `_ERR`
   摘要行（0 錯誤時 go-tpc 根本不印該行，非印 `Count: 0`）會讓整個
   pipeline 回傳非 0，觸發 `set -e` 中止整個 driver——這時「未套 patch」
   那輪真實負載其實已經跑完（IDC/GCP 兩側 rc=0，`dual-side AA run
   PASS`），只是腳本統計步驟自己中止了。已修正
   [verify-a8-batch-smoke.sh](../scripts/verify-a8-batch-smoke.sh) 的
   `count_err()`（`grep` 拿掉 `^` 錨點以吃到 `[gcp] ` 前綴、函式尾端加
   `return 0` 避免 pipefail 誤判成腳本失敗）。
4. 未套 patch 那輪的 netflow pre/post 暫存檔仍留在 `.31` 上
   （`mktemp -d` 建立、driver 中止前未執行到 `rm -rf`），手動撈回算出
   ratio，未浪費那一輪真實跑過的資料。
5. 手動接著跑「已套 patch」對照組（apply patch → 跑同組 aaro-smoke
   參數 → netflow post），拿到完整 before/after 對照，才 `teardown-ybdb`
   並用修好的 driver（`DBS=crdb`）跑最後一段 CRDB。

## 結果摘要（完整分析見報告 §5.8）

- **TiDB**：staleness 近讀 78ms vs leader 94ms（近乎即時，符合預期）；
  zone A/B 4 組 ratio 全落在 110-130%，看不出方向性——netflow 在 W=4
  規模下被背景流量淹沒，此測法對 TiDB 不夠力（方法論限制，非近讀失效）。
- **YBDB**：staleness 近讀延遲 28,283ms，與設定值
  `yb_follower_read_staleness_ms=30000` 量級吻合（決定性）。go-tpc
  反事實：未套 patch 平均延遲 60.7/37.9ms（ORDER_STATUS/STOCK_LEVEL）、
  套用後降至 27.1/25.3ms，吞吐量從 ~18.6k 提升到 ~34k/~34.3k 筆（近乎
  翻倍），套用後出現 ~0.04% 極低錯誤率（同量級於 CRDB 已知的 ~0.1%）。
  netflow ratio 本身（105.9%→91.2%）幾乎沒變化——與 CRDB 已知的
  netflow-noise 限制同一類，佐證「拿掉 patch 確實會像 CRDB 一樣近讀
  失效」的延遲/吞吐量證據才是決定性的，netflow 不是。
- **CRDB**：staleness 近讀延遲 4,152ms，與 CRDB `follower_read_timestamp()`
  預設 ~4.8s 的量級吻合（決定性）。

對應報告章節：[XCROSS-AARO-CLOSING-REPORT-DRAFT.md §5.8](../XCROSS-AARO-CLOSING-REPORT-DRAFT.md)。
