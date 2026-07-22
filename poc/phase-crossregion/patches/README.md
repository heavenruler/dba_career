# go-tpc-readonly-fix.patch

**背景**：A7(4) 實測發現 go-tpc（`github.com/pingcap/go-tpc`）的
`tpcc/workload.go` 對所有交易一律呼叫 `beginTx`，其
`sql.TxOptions{Isolation: ...}` 從未設 `ReadOnly: true`（永遠是 Go 的 zero
value `false`）。CRDB/YBDB 的 GCP 側連線走 `-d postgres`（`lib/pq` driver），
`lib/pq` 的 `BeginTx` 看到 `ReadOnly=false` 會**明確**送出
`BEGIN ... READ WRITE`，這個交易層級的明確設定會蓋過 session 層的
`default_transaction_read_only=on`（SQL 標準行為：顯式設定優先於預設值）。

**後果**：
- CRDB：`default_transaction_use_follower_reads=on` 依賴隱式注入
  `AS OF SYSTEM TIME`，該子句只能用在 READ ONLY 交易——實測 100% 報錯
  `AS OF SYSTEM TIME specified with READ WRITE mode`。
- YBDB：官方文件明講「READ WRITE 交易一律走 leader」——不會報錯，但
  `yb_read_from_followers` 靜默失效，回退到 leader-read。

**修法**：只針對 TPC-C 定義上本就是純讀、永不寫入的 `ORDER_STATUS` /
`STOCK_LEVEL` 兩種交易類型，新增 `beginTxReadOnly`（`ReadOnly: true`），
讓 `lib/pq` 改送 `BEGIN ... READ ONLY`。其餘交易類型（`NEW_ORDER`／
`PAYMENT`／`DELIVERY`，皆涉及寫入）完全不受影響，繼續用原本的 `beginTx`。

**套用方式**：
```bash
git clone --depth 1 https://github.com/pingcap/go-tpc.git
cd go-tpc
git apply /path/to/go-tpc-readonly-fix.patch
GOOS=linux GOARCH=amd64 GOEXPERIMENT=jsonv2 CGO_ENABLED=0 GO111MODULE=on \
  go build -o ./bin/go-tpc ./cmd/go-tpc/
```

**部署範圍**：僅需替換 **GCP client**（A-A-RO 架構下唯一發起純讀 mix 的
一側）的 `go-tpc` binary；IDC 側維持原版（IDC 側跑完整 mix，含寫入交易）。
2026-07-22 驗證時部署路徑：`root@10.160.152.15:/usr/local/bin/go-tpc`
（原始版本備份為同目錄 `go-tpc.orig`）。

**base commit**：`a9ca4818625deef91ff80f6c395a575ccae22b7c`
（`github.com/pingcap/go-tpc` master，2026-01-13）。

**驗證結果**：套用後 CRDB GCP 側查詢錯誤率從 100% 降到 ~0.1%（僅 RUN_SEC
收尾時的預期 timeout），`check-aaro-artifacts.py` 轉為 PASS。詳見
[XCROSS-AARO-CLOSING-REPORT-DRAFT.md §5.5](../XCROSS-AARO-CLOSING-REPORT-DRAFT.md)。

**注意**：此 patch 只解決「go-tpc 讓近讀機制在正確設定下仍無法生效」的
結構性衝突，不改變 TiDB（zone-based 路由，本就不受此問題影響，未套用此
patch 也不需要）。若上游 go-tpc 之後改變 `beginTx` 簽名或交易分派邏輯，
需要重新核對這兩個呼叫點是否仍然正確。
