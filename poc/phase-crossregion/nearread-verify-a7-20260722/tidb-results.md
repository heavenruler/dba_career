# A7(1)(4) 補強驗證結果（smoke 規模 W=4，TS=20260721T213453+0800）

回應 codex 獨立審查（07-22）§5.6 建議 (1)(4)。本輪吞吐數字僅供機制
驗證，非報告 §1-§6 採用數字（W=4 anchor，非完整 W=128）。

## tidb

### A7(1) 真實 ORDER_STATUS/STOCK_LEVEL 交易（idle 連線）
PASS（詳見 verify-a7-20260721T213453+0800-tidb-realtxn.log）
### A7(4) t128 執行期間採樣（每 12s 一次，共 330s）
PASS=25 FAIL=3（詳見 verify-a7-20260721T213453+0800-tidb-underload.log / .detail）
**至少一次取樣 FAIL——負載下近讀曾退化，需人工複核 .detail log**
本輪 aaro-smoke 本身：check-aaro-artifacts.py PASS（0 錯誤）
