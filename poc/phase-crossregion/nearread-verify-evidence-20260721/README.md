# GCP 就近讀生效檢驗——原始證據（2026-07-21）

補 codex 獨立審查（2026-07-22）指出的可追溯性缺口：本目錄保存 §5.5 三家
驗證的原始輸出，供第三方獨立重算，而非僅信任報告敘述。

| 檔案 | 內容 |
|---|---|
| `tidb-zone-labels.txt` | TiKV store 標籤、tidb-server 標籤、延遲對照原始值 |
| `netflow-pre.json` / `netflow-post.json` | TiDB 500 筆讀取 burst 前後 netflow byte 快照 |
| `crdb-explain-analyze-8x.txt` | CRDB 8 次 `EXPLAIN ANALYZE` 原始輸出 |
| `netflow-crdb-pre*.json` / `netflow-crdb-post*.json` | CRDB 4 輪 burst 測試（500/500/500/5000 筆）netflow 快照 |
| `ybdb-explain-analyze-on-off.txt` | YBDB follower-read on/off 對照 `EXPLAIN (ANALYZE, DIST)` 原始輸出 |

對應報告章節：[XCROSS-AARO-CLOSING-REPORT-DRAFT.md §5.5](../XCROSS-AARO-CLOSING-REPORT-DRAFT.md)。
netflow JSON 由 [tests/common/netflow-snapshot.sh](../../tests/common/netflow-snapshot.sh) 產生
（`iptables_to_gcp_bytes`/`iptables_to_idc_bytes` 為累積計數器，兩次快照相減即為區間 delta）。
