# CockroachDB TPC-C Pipeline Log — cockroach-tc1 / S-BASE

> **本測試結論**：CockroachDB 單節點吞吐量介於 TiDB 與 YugabyteDB 之間 — 約為 TiDB 的 65%、YBDB 的 22 倍；READ COMMITTED 隔離後無 abort 重試風暴。

---

## vm-1node — 2026-05-08

### 環境
- 節點：.32 (172.24.40.32) 單節點，**insecure 模式**（無 TLS，方便快速比較；TLS overhead 對 OLTP 影響極小）
- 部署：`cockroach start-single-node --insecure --advertise-addr=172.24.40.32 --listen-addr=172.24.40.32:26257 --http-addr=172.24.40.32:8080 --store=/opt/cockroach/data --background`
- CockroachDB 版本：v26.1.4
- **Isolation**：READ COMMITTED（資料庫的「交易隔離等級」設定，決定多筆交易同時跑時彼此能看到對方未完成的資料到什麼程度。READ COMMITTED 是業界最常用的等級之一，本次與 YBDB 對齊，確保對比基準一致。CRDB 預設等級為 SERIALIZABLE 但較嚴格，會在衝突時整筆中止重試。）

  以下三條設定使 CRDB 整體切換到 READ COMMITTED 模式：
  - cluster setting：`SET CLUSTER SETTING sql.txn.read_committed_isolation.enabled = true;`（設定整個叢集層級的隔離預設值）
  - 預設 role：`ALTER ROLE ALL SET default_transaction_isolation = 'read committed';`（讓所有使用者新建交易時自動套用 READ COMMITTED）
  - go-tpc：`--isolation 2`（測試工具端的對應設定，與資料庫端一致；go-tpc isolation level 2 = ReadCommitted）
- 測試工具：go-tpc (`-d postgres --conn-params sslmode=disable --isolation 2`)（`sslmode=disable`：測試環境關閉 SSL 連線加密以簡化設定，正式部署應啟用加密；本次與 insecure 部署模式一致）
- 連線入口：直連 172.24.40.32:26257
- Warehouses：128 | Warmup：5m | Duration：10m | Threads：16/32/64/128
- 結果目錄：`vm-1node/20260508-2057/`

### Prepare
- 時間：12m46s（128W）— 三家中最快（TiDB 19m、YBDB 47m）
- check 階段全程通過

### Execute 結果

> ⚠️ **注意**：efficiency 欄位在無 think time（等待間隔）的壓力測試下會遠超 100%，這是正常現象（資料庫一刻不停地工作），不代表計算錯誤。
>
> （tpmC / tpmTotal：越高越好；NO avg / NO P99：越低越好）

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

> **倍數 = 前者 tpmC ÷ 後者 tpmC，越高代表前者效能越好**（TiDB/CRDB > 1 代表 TiDB 較快；CRDB/YBDB > 1 代表 CRDB 較快）。

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
- **無 NEW_ORDER_ERR（新訂單交易因衝突被資料庫中止的錯誤計數為 0）**：READ COMMITTED 模式下衝突會排隊等待而非 abort（取消整筆交易）；之前 SERIALIZABLE 在 16t 出現約 0.1% 的 abort 率，切到 RC 後消失。

### 根因：架構差異

> **管理層摘要**：CockroachDB 預設用「最嚴格的衝突偵測」，遇到衝突會直接中止整筆交易並要求應用程式重試（這個過程會吃掉吞吐）。本次將設定切到較寬鬆的 READ COMMITTED 模式後，衝突的交易改為「排隊等候」（與 TiDB 機制一致），因此延遲穩定、吞吐持續。這是 CRDB 居於 TiDB 與 YBDB 中間的原因。

CockroachDB 採用 **distributed serializable + lock-based locking under SERIALIZABLE，但 RC 模式下使用 row-level locking（以單一資料列為單位的鎖定，後到的交易等鎖而非整筆中止）不 abort**：
- SERIALIZABLE 模式：偵測到讀寫衝突直接 abort（`WriteTooOldError`：CRDB 在偵測到讀寫衝突時拋給應用程式的錯誤），需 client retry（要求應用程式端重新發送整筆交易）
- READ COMMITTED 模式：採 row-level locking，後到的交易等鎖（類似 TiDB 悲觀鎖），不 abort

TPC-C `district.D_NEXT_O_ID` 熱點 row 在 RC 下排隊處理，每筆順序執行，因此吞吐曲線平穩、無 retry 風暴。

### vs TiDB / YBDB 架構差異總結

| | TiDB | CockroachDB (RC) | YBDB |
|--|------|-----------------|------|
| 預設 isolation | RR | SERIALIZABLE（本測試切 RC）| RC（本測試）|
| 鎖定機制 | 悲觀（TiDB v6+ 預設） | RC 下 row-level | 樂觀 MVCC |
| 衝突處理 | 排隊等鎖 | 排隊等鎖 | rollback 重試 |
| 單節點 peak tpmC | 13,355 | 8,732 | 414.7 |
| 128t hang 風險 | 無 | 無 | 無（vm-1node 直連） |

> 縮寫：**RR** = Repeatable Read（可重複讀取）；**RC** = Read Committed（讀已提交）；**SERIALIZABLE** = 可序列化（最嚴格）。

### 注意事項

- **首次 SERIALIZABLE 測試**（同日稍早，5m 部分數據）：tpmC ~8,200，但每秒約 0.1% 的新訂單交易因 `WriteTooOldError`（讀寫衝突錯誤）被資料庫**中止整筆交易**（abort）。改 RC 後此情況消失，吞吐略升至 8,732。
- **insecure 模式**：本測試走無 TLS，TLS 對 OLTP 影響通常 < 5%；正式部署時應用 secure 模式。
