# CockroachDB TPC-C Pipeline Log — cockroach-tc1 / S-BASE

> **本測試結論**：CockroachDB 單節點吞吐量介於 TiDB 與 YugabyteDB 之間 — 約為 TiDB 的 65%、YBDB 的 22 倍；READ COMMITTED 隔離後無 abort 重試風暴。

---

## vm-1node — 2026-05-08

### 環境
- 節點：.32 (172.24.40.32) 單節點，**insecure 模式**（無 TLS，方便快速比較；TLS overhead 對 OLTP 影響極小）
- 部署：`cockroach start-single-node --insecure --advertise-addr=172.24.40.32 --listen-addr=172.24.40.32:26257 --http-addr=172.24.40.32:8080 --store=/opt/cockroach/data --background`
- CockroachDB 版本：v26.1.4
- **Isolation**：READ COMMITTED（為對標 YBDB / TiDB 行為）
  - cluster setting：`SET CLUSTER SETTING sql.txn.read_committed_isolation.enabled = true;`
  - 預設 role：`ALTER ROLE ALL SET default_transaction_isolation = 'read committed';`
  - go-tpc：`--isolation 2`（go-tpc isolation level 2 = ReadCommitted）
- 測試工具：go-tpc (`-d postgres --conn-params sslmode=disable --isolation 2`)
- 連線入口：直連 172.24.40.32:26257
- Warehouses：128 | Warmup：5m | Duration：10m | Threads：16/32/64/128
- 結果目錄：`vm-1node/20260508-2057/`

### Prepare
- 時間：12m46s（128W）— 三家中最快（TiDB 19m、YBDB 47m）
- check 階段全程通過

### Execute 結果

| threads | tpmC | tpmTotal | efficiency | NO avg(ms) | NO P99(ms) |
|---------|------|----------|------------|------------|------------|
| 16 | 8,559.5 | 19,034.1 | 520.0% | 62.3 | 125.8 |
| 32 | 8,732.5 | 19,423.5 | 530.5% | 126.0 | 260.0 |
| 64 | 8,555.3 | 19,082.9 | 519.7% | 265.0 | 604.0 |
| 128 | 8,133.4 | 18,086.4 | 494.1% | 564.6 | 1,275.1 |

### Execute 結果白話解讀

| 併發 | 白話解讀 |
|------|---------|
| 16t | 表現良好（延遲 62ms） |
| 32t | 維持高吞吐（延遲 126ms，最佳吞吐點） |
| 64t | 開始吃力（延遲 265ms） |
| 128t | 仍可運作（延遲 565ms，無逾時、無 hang） |

### 三家對比（vm-1node 相同硬體）

| threads | TiDB tpmC | CRDB tpmC | YBDB tpmC | TiDB/CRDB | CRDB/YBDB |
|---------|-----------|-----------|-----------|-----------|-----------|
| 16 | 11,895 | 8,559 | 414.7 | 1.39× | 20.6× |
| 32 | 12,766 | 8,732 | 394.8 | 1.46× | 22.1× |
| 64 | 13,355 | 8,555 | 378.6 | 1.56× | 22.6× |
| 128 | 13,078 | 8,133 | 370.4 | 1.61× | 21.9× |
| **Peak** | **13,355** | **8,732** | **414.7** | — | — |
| Peak @ | 64t | 32t | 16t | — | — |

| threads | TiDB NO avg | CRDB NO avg | YBDB NO avg |
|---------|-------------|-------------|-------------|
| 16 | 39 ms | 62 ms | 2,225 ms |
| 32 | 72 ms | 126 ms | 4,686 ms |
| 64 | 135 ms | 265 ms | 9,548 ms |
| 128 | 268 ms | 565 ms | 15,655 ms |

### 觀察

- **吞吐穩定 ~8,500 tpmC**：16~128t 之間 tpmC 浮動 < 7%（8,732 → 8,133），曲線平緩，無 YBDB 那樣的崩潰式下滑。
- **峰值在 32t**（與 TiDB 64t、YBDB 16t 相比，CRDB 對中度併發最友好）。
- **NO avg 線性翻倍**：62 → 126 → 265 → 565 ms，與 TiDB / YBDB 相同模式，但絕對值落在中間。
- **128t 順利完成**：無 hang，total 45m01s；NO P99 1,275ms 遠低於 go-tpc 16s 上限。
- **無 NEW_ORDER_ERR**（READ COMMITTED 不再 abort）：之前用 SERIALIZABLE 在 16t 出現 ~0.1% abort 率，切到 RC 後消失。

### 根因：架構差異

CockroachDB 採用 **distributed serializable + lock-based locking under SERIALIZABLE，但 RC 模式下使用 row-level locking 不 abort**：
- SERIALIZABLE 模式：偵測到讀寫衝突直接 abort（`WriteTooOldError`），需 client retry
- READ COMMITTED 模式：採 row-level locking，後到的交易等鎖（類似 TiDB 悲觀鎖），不 abort

TPC-C `district.D_NEXT_O_ID` 熱點 row 在 RC 下排隊處理，每筆順序執行，因此吞吐曲線平穩、無 retry 風暴。

### vs TiDB / YBDB 架構差異總結

| | TiDB | CockroachDB (RC) | YBDB |
|--|------|-----------------|------|
| 預設 isolation | RR | SERIALIZABLE（本測試切 RC）| RC（本測試）|
| 鎖定機制 | 悲觀（v6+ 預設） | RC 下 row-level | 樂觀 MVCC |
| 衝突處理 | 排隊等鎖 | 排隊等鎖 | rollback 重試 |
| 單節點 peak tpmC | 13,355 | 8,732 | 414.7 |
| 128t hang 風險 | 無 | 無 | 無（vm-1node 直連） |

### 注意事項

- **首次 SERIALIZABLE 測試**（同日稍早，5m 部分數據）：tpmC ~8,200，但每秒 0.1% NEW_ORDER 因 `WriteTooOldError` abort。改 RC 後 abort 消失，吞吐略升至 8,732。
- **insecure 模式**：本測試走無 TLS，TLS 對 OLTP 影響通常 < 5%；正式部署時應用 secure 模式。
