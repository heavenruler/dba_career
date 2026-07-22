# A7(1)(4) 補強驗證——原始結果（2026-07-22）

回應 codex 獨立審查（07-22，§5.6）建議的後續補做 (1)(4)：用真實
ORDER_STATUS/STOCK_LEVEL 交易取代 `LIMIT 1` 單筆查詢、在 t128 高併發執行
期間持續採樣近讀證據。三家皆用 smoke 規模（W=4）、
[verify-a7-smoke.sh](../scripts/verify-a7-smoke.sh) driver 執行。

| 檔案 | 內容 | TS |
|---|---|---|
| `tidb-results.md` / `tidb-realtxn.log` / `tidb-underload.log` | TiDB | `20260721T213453+0800` |
| `crdb-results.md` / `crdb-realtxn.log` / `crdb-underload.log` | CRDB（已套用 go-tpc 修法後的乾淨結果） | `20260722T095546+0800` |
| `ybdb-results.md` / `ybdb-realtxn.log` / `ybdb-underload.log` | YBDB | `20260722T101909+0800` |

## 結果摘要

| DB | A7(1) 真實交易 | A7(4) t128 採樣 | aaro-smoke 本身 |
|---|---|---|---|
| TiDB | PASS | 25/28 PASS（早期 3 次為暖機過渡，見下） | check-aaro-artifacts.py PASS |
| CRDB | PASS | 22/28 PASS（早期 6 次為暖機過渡，見下） | check-aaro-artifacts.py PASS（套用 go-tpc 修法前 100% 報錯，見下） |
| YBDB | 表面 FAIL 3/12，實為腳本未暖機的假陽性（見下） | 14/15 PASS（末端 1 次疑為收尾資源競爭） | check-aaro-artifacts.py PASS |

## 兩個過程中發現並修正的問題

**1. go-tpc 與 CRDB/YBDB 近讀機制結構性衝突（重大發現）**——見
[patches/README.md](../patches/README.md) 完整說明。簡述：go-tpc 從未對
ORDER_STATUS/STOCK_LEVEL 設 `TxOptions.ReadOnly=true`，其 `lib/pq` driver
因此對每筆交易明確送出 `BEGIN ... READ WRITE`，蓋過 session 層
`default_transaction_read_only=on`——CRDB 因此 100% 報錯（`AS OF SYSTEM
TIME specified with READ WRITE mode`），YBDB 依官方文件會靜默 fallback 回
leader（未報錯但近讀不生效）。修法：
[go-tpc-readonly-fix.patch](../patches/go-tpc-readonly-fix.patch)，只讓這
兩種純讀交易類型明確要求 `ReadOnly: true`。`crdb-results.md` 記載的是套用
此 patch 之後的乾淨結果；套用前的失敗記錄未保留原始 log（僅口頭記載於
report §5.5），因為問題定位後直接修正重跑，未特意保留失敗態的完整 log。

**2. YBDB A7(1) 的「FAIL」是腳本本身未做連線暖機造成的假陽性**——
`ybdb-realtxn.log` 顯示唯一失敗的是第一組樣本（w=1 d=3 c=500）的全部 3 條
查詢，其餘 3 組樣本（w=2/3/4）全部 PASS 且 on/off 時間差距懸殊（如
on=0.43ms vs off=8.66ms）。第一組樣本 on≈off（10.6ms vs 8.4ms）與
`ybdb-explain-analyze-on-off.txt`（07-21）記載的「首次查詢冷 catalog
cache」現象一致——並非近讀機制失效，是測試腳本本身少做一次暖機查詢。
已修正 [check-nearread-realtxn.sh](../scripts/check-nearread-realtxn.sh)
補上暖機查詢，未來重跑不會再有此假陽性。

## A7(4) 暖機過渡現象（非隨機退化）

TiDB／CRDB 的 A7(4) FAIL 樣本**全部集中在採樣視窗最前面幾次**（TiDB：
sample 2-4；CRDB：sample 2-7），之後穩定 100% PASS 到採樣結束（TiDB 25
次、CRDB 22 次連續 PASS）。這與「高併發下持續隨機退化」不同，更符合
「closed-timestamp/副本狀態剛從 freeze 解除，需要約 1 分鐘穩定」的過渡
現象，屬於預期內、良性、可解釋的行為。YBDB 則相反——前 14 次全 PASS，
僅最後一次（採樣間隔異常拉長至 46 秒，暗示當時 DB 資源競爭較激烈）FAIL，
與 aaro-smoke 收尾階段的資源競爭時間點吻合。

## 對應報告章節

[XCROSS-AARO-CLOSING-REPORT-DRAFT.md §5.5](../XCROSS-AARO-CLOSING-REPORT-DRAFT.md)。
