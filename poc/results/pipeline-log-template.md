# <Database> TPC-C Pipeline Log — <db>-tc1 / S-BASE

> 本檔記錄 `<Database>` 在 PoC v4.7 框架下的 S-BASE baseline。舊流程、單次 wrapper 或 deprecated 資料需移至 `pipeline-log_old.md`，避免與 v4.7 baseline 混用。

## 使用規則

- 資料庫名稱使用完整名稱：`TiDB`、`CockroachDB`、`YugabyteDB`。
- 隔離級使用完整名稱：`READ COMMITTED`、`REPEATABLE READ`、`SERIALIZABLE`、`最嚴格隔離級`。
- 不使用 `產物`；改用 `執行紀錄`、`結果目錄`、`流程紀錄`、`gate 記錄`。
- 數據口徑必須明示：v4.7 標準為 20 分鐘 warmup、4 個併發水位、每水位 5 round、每 round 5 分鐘、client + DB-host 雙邊 OS 監控。
- 所有 tpmC、p50、p95、p99 若為 5-round mean，需明寫；若不是 v4.7 口徑，必須標記 caveat。
- 機制歸因若不是直接量測，必須標示「推測」或「待補 metrics / trace 佐證」。
- 差異分析表格只放數字與 `註記` 欄，不要在表格內塞長句；註解內容集中放在文末「差異分析註解」。
- 註解連結統一寫成 `[註1](#note-1)`、`[註2](#note-2)`、`[註3](#note-3)`、`[註4](#note-4)`。
- 表格外段落需要補充說明時，也在句尾使用同一組註解連結。
- `註1` 到 `註4` 為全文件共用，不針對單一表格重新編號。
- 文末固定使用 `<a id="note-1"></a>` anchor，避免 Markdown renderer 對中文 heading anchor 產生差異。

## TL;DR — <scope>（<date>）

> 本段只放目前最重要結論，避免塞完整分析。完整數據放各 isolation 段。

### tpmC 排行

| 排名 | 隔離級 | tpmC | 併發 | DB-host 瓶頸 | error count | error rate |
|---|---|---:|---:|---|---:|---:|
| 🥇 | `<隔離級>` | `<tpmC>` | `<threads>` | `<CPU-bound / IO-bound / retry-bound / 待確認>` | `<count>` | `<errors / total 或 %>` |
| 🥈 | `<隔離級>` | `<tpmC>` | `<threads>` | `<瓶頸>` | `<count>` | `<errors / total 或 %>` |
| 🥉 | `<隔離級>` | `<tpmC>` | `<threads>` | `<瓶頸>` | `<count>` | `<errors / total 或 %>` |

### 三大發現

1. `<發現 1：例如最高吞吐、sweet spot、瓶頸成因。>`
2. `<發現 2：例如隔離級差異或 retry/error 行為。>`
3. `<發現 3：例如跨家比較 caveat 或下一步。>`

### 業務啟示

- `<用非內部術語說明這組結果對 PoC 決策的意義。>`
- `<說明哪些數據可用、哪些仍不可用。>`

### 完整資料目錄

| 隔離級 | TPCC_TS | 主要結果 | 結果目錄 | 詳細段落 |
|---|---|---:|---|---|
| READ COMMITTED | `<yyyyMMddTHHmmss+0800>` | `<tpmC>` | [`<result-dir>`](./vm-1node-rc/<result-dir>/) | [§ vm-1node-rc](#vm-1node-rc) |
| REPEATABLE READ | `<yyyyMMddTHHmmss+0800>` | `<tpmC>` | [`<result-dir>`](./vm-1node-rr/<result-dir>/) | [§ vm-1node-rr](#vm-1node-rr) |
| 最嚴格隔離級 | `<yyyyMMddTHHmmss+0800 或 alias>` | `<tpmC 或 —>` | [`<result-dir>`](./vm-1node-strict/<result-dir>/) | [§ vm-1node-strict](#vm-1node-strict) |

## vm-1node-rc

> **本段目的**：取得 `<Database>` 單節點 READ COMMITTED baseline，作為其他隔離級與其他資料庫對標的起點。

### 環境

- 版本：`<database version>`
- 部署：`<playbook / helm / manual>`
- 硬體：`<vCPU / memory / disk / OS>`
- 連線入口：`<host:port>`
- 測試工具：go-tpc on `.31`（`<driver>` driver，`<conn-params>`）
- Warehouses：`128`
- Warmup：`20 min @ 64 threads`
- Run：每組 `5 round × 5 min`
- Threads：`16 / 32 / 64 / 128`
- OS 監控：client (`.31`) 與 DB-host (`.32`) 同時採樣 `mpstat` / `iostat` / `vmstat` / `sar`
- TPCC_TS：`<yyyyMMddTHHmmss+0800>`
- 結果目錄：`<case>/<result-dir>/`

### Suite 階段時序

| Phase | 起 | 訖 | 耗時 |
|---|---|---|---|
| gate | `<time>` | `<time>` | `<duration>` |
| prepare | `<time>` | `<time>` | `<duration>` |
| gate-isolation | `<time>` | `<time>` | `<duration>` |
| run | `<time>` | `<time>` | `<duration>` |
| collect | `<time>` | `<time>` | `<duration>` |
| **total** | `<time>` | `<time>` | `<duration>` |

> `<若有 manual resume / bug fix / retry / interruption，於此說明資料品質是否受影響。>`

### Gate 結果

- isolation gate：`<expected>` / `<actual>`，來源：`gate/isolation-db.txt`、`gate/isolation-driver-verify.txt`
- OS gate：`<THP / swappiness / ulimit>`
- Time sync：`<chrony / drift>`
- Disk gate：`<filesystem / mount / free space>`

### Prepare

- DROP / CREATE：`<duration / status>`
- go-tpc prepare：`<duration / status>`
- check-all / row-count：`<duration / status>`
- ANALYZE / statistics：`<duration / status>`
- EXPLAIN dump：`<files>`

### Execute 結果（5 round tpmC 平均；latency 為 5 round mean）

### 取數來源

- 工作目錄：`<result-dir>`
- 使用檔案：`runs/threads-*/round-*/go-tpc-stdout.txt`
- 取得方式：`<手動 / parser / rg + awk / jq / 待補固定 parser>`
- 指令：
  ```bash
  <command>
  ```
- 計算口徑：`<5-round mean / median / single run / round-N>`
- 產出欄位：`tpmC mean / tpmTotal mean / efficiency mean / NO p50 / NO p95 / NO p99 / error count / error rate`

> tpmC / tpmTotal / efficiency 為 5 round mean；NO p50 / p95 / p99 亦為 5 round latency mean。
>
> `range/mean` = `(5 round 最大 tpmC - 最小 tpmC) / 5 round 平均 tpmC`，用來看同一併發水位的 round-to-round 波動。
>
> go-tpc 若沒有 think time / keying time，efficiency 遠超 100% 屬正常。

| threads | tpmC mean | range/mean | tpmTotal mean | efficiency mean | NO p50 (ms) | NO p95 (ms) | NO p99 (ms) | error count | error rate |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 16 | `<value>` | `<value>` | `<value>` | `<value>` | `<value>` | `<value>` | `<value>` | `<count>` | `<errors / total 或 %>` |
| 32 | `<value>` | `<value>` | `<value>` | `<value>` | `<value>` | `<value>` | `<value>` | `<count>` | `<errors / total 或 %>` |
| 64 | `<value>` | `<value>` | `<value>` | `<value>` | `<value>` | `<value>` | `<value>` | `<count>` | `<errors / total 或 %>` |
| 128 | `<value>` | `<value>` | `<value>` | `<value>` | `<value>` | `<value>` | `<value>` | `<count>` | `<errors / total 或 %>` |

### Round-by-round tpmC

### 取數來源

- 工作目錄：`<result-dir>`
- 使用檔案：`runs/threads-*/round-*/go-tpc-stdout.txt`
- 取得方式：`<手動 / parser / rg + awk / jq / 待補固定 parser>`
- 指令：
  ```bash
  <command>
  ```
- 計算口徑：`per-round tpmC`
- 產出欄位：`r1 / r2 / r3 / r4 / r5`

| Threads | r1 | r2 | r3 | r4 | r5 |
|---:|---:|---:|---:|---:|---:|
| 16 | `<value>` | `<value>` | `<value>` | `<value>` | `<value>` |
| 32 | `<value>` | `<value>` | `<value>` | `<value>` | `<value>` |
| 64 | `<value>` | `<value>` | `<value>` | `<value>` | `<value>` |
| 128 | `<value>` | `<value>` | `<value>` | `<value>` | `<value>` |

### DB-host 飽和分析

### 取數來源

- 工作目錄：`<result-dir>`
- 使用檔案：`runs/threads-*/round-*/mpstat-db.txt`、`runs/threads-*/round-*/iostat-1s-db.txt`
- 取得方式：`<手動 / parser / awk / 待補固定 parser>`
- 指令：
  ```bash
  <command>
  ```
- 計算口徑：`<round-N mean / 5-round mean / selected mid-run sample>`
- 產出欄位：`%usr / %sys / %iowait / %idle / %idle min / r/s / w/s / %util`

> **核心問題**：單節點在固定硬體下，吞吐天花板的成因是什麼？  
> **回答**：`<CPU-bound / IO wait-bound / retry-bound / network-bound / 待確認>`。

#### mpstat-db.txt

| threads | %usr mean | %sys mean | %iowait mean | %idle mean | %idle min |
|---:|---:|---:|---:|---:|---:|
| 16 | `<value>` | `<value>` | `<value>` | `<value>` | `<value>` |
| 32 | `<value>` | `<value>` | `<value>` | `<value>` | `<value>` |
| 64 | `<value>` | `<value>` | `<value>` | `<value>` | `<value>` |
| 128 | `<value>` | `<value>` | `<value>` | `<value>` | `<value>` |

#### iostat-1s-db.txt

| threads | r/s | w/s | rkB/s+wkB/s | %util |
|---:|---:|---:|---:|---:|
| 16 | `<value>` | `<value>` | `<value>` | `<value>` |
| 32 | `<value>` | `<value>` | `<value>` | `<value>` |
| 64 | `<value>` | `<value>` | `<value>` | `<value>` |
| 128 | `<value>` | `<value>` | `<value>` | `<value>` |

#### 飽和歸因

| 假設 | 驗證 | 證據 |
|---|---|---|
| 飽和是 CPU | `<✓ / ❌ / 待確認>` | `<證據>` |
| 飽和是 IO wait | `<✓ / ❌ / 待確認>` | `<證據>` |
| 飽和是 transaction retry / abort | `<✓ / ❌ / 待確認>` | `<證據>` |
| 飽和是 network / proxy / shard routing | `<✓ / ❌ / 待確認>` | `<證據>` |

### 對標分析

### 取數來源

- 工作目錄：`<result-dir A>`、`<result-dir B>`
- 使用檔案：`<pipeline-log.md / summary.json / go-tpc-stdout.txt>`
- 取得方式：`<手動彙整 / parser / 待補固定 parser>`
- 指令：
  ```bash
  <command>
  ```
- 計算口徑：`<同口徑 5-round mean / mixed caveat>`
- 產出欄位：`Δ tpmC / Δ p99 / 註記`

| threads | `<對照 A>` | `<本組>` | Δ tpmC | `<對照 A p99>` | `<本組 p99>` | Δ p99 | 註記 |
|---:|---:|---:|---:|---:|---:|---:|---|
| 16 | `<value>` | `<value>` | `<value>` | `<value>` | `<value>` | `<value>` | `[註1](#note-1)` |
| 32 | `<value>` | `<value>` | `<value>` | `<value>` | `<value>` | `<value>` | `[註1](#note-1)` |
| 64 | `<value>` | `<value>` | `<value>` | `<value>` | `<value>` | `<value>` | `[註2](#note-2)` |
| 128 | `<value>` | `<value>` | `<value>` | `<value>` | `<value>` | `<value>` | `[註2](#note-2)` |

> 若同一張表需要多個說明，`註記` 欄可寫 `[註1](#note-1), [註3](#note-3)`。註解內容仍放文末，不放在表格內。

### 觀察

- `<sweet spot 與 peak 差異。>`
- `<latency / retry / abort / error 觀察。>`
- `<OS 監控對瓶頸的支持或限制。>`

### 結論

`<一段總結：這組 isolation / case 是否可作 baseline、主要瓶頸、下一步。>`

## vm-1node-rr

> 本段對齊 `vm-1node-rc` 結構填入。若 REPEATABLE READ 在該資料庫為 preview、snapshot isolation 或與其他資料庫語意不同，需在本段明確說明。

### 與 READ COMMITTED 的差異

- `<isolation 實作差異。>`
- `<retry / lock / snapshot / timestamp 行為差異。>`
- `<資料庫特定 caveat。>`

### Execute 結果

> 複製 `vm-1node-rc` 的 Execute / Round-by-round / DB-host 飽和分析 / 對標分析結構。

## vm-1node-strict

> 本段記錄最嚴格隔離級。若該資料庫不支援原生 SERIALIZABLE，需明確寫「略過」或「以何者代表」，並說明不可與其他資料庫 strict 直比。

### 執行或略過依據

- `<例如 TiDB strict 等價於 REPEATABLE READ；CockroachDB 預設 SERIALIZABLE；YugabyteDB SERIALIZABLE 需額外檢查。>`

### Execute 結果

> 若有實跑，複製 `vm-1node-rc` 的 Execute / Round-by-round / DB-host 飽和分析 / 對標分析結構。

## Kubernetes / scale-out 段

> 三節點虛擬機、HAProxy、Kubernetes 無資源限制、Kubernetes 有資源限制等 scale-out case 請獨立成段。未重跑前不可保留舊數字在主段。

### <case-name>

- 狀態：`<待重跑 / 完成 / 完成，分析待修>`
- 結果目錄：`<path>`
- 主要結論：`<一到三點>`
- caveat：`<是否與 vm-1node 同口徑>`

## 歷史檔案

- `<pipeline-log_old.md / deprecated path / pre-v4.7 result>`：`<是否納入 baseline，通常不納入。>`

## 差異分析註解

| 註記 | 說明 |
|---|---|
| <a id="note-1"></a>註1 | `<差異計算口徑，例如 Δ tpmC = (本組 - 對照組) / 對照組；p99 差異同理。>` |
| <a id="note-2"></a>註2 | `<比較限制，例如不同 isolation、不同 retry 行為、不同 run 方法時不可直接視為引擎優劣。>` |
| <a id="note-3"></a>註3 | `<資料品質限制，例如單次 10min wrapper、5-round mean、manual resume、欄位待修。>` |
| <a id="note-4"></a>註4 | `<機制歸因限制，例如 OS 指標支持瓶頸，但缺少 DB metrics / trace 直接佐證。>` |

## 取數指令索引

| 目的 | 工作目錄 | 使用檔案 | 指令 | 產出 |
|---|---|---|---|---|
| go-tpc summary | `<result-dir>` | `runs/threads-*/round-*/go-tpc-stdout.txt` | `<command>` | `tpmC / latency / error count / error rate` |
| round-by-round tpmC | `<result-dir>` | `runs/threads-*/round-*/go-tpc-stdout.txt` | `<command>` | `r1-r5 tpmC` |
| marker chain | `<result-dir>` | `.*.done` | `ls -al .*.done` | `phase complete` |
| isolation gate | `<result-dir>` | `gate/isolation*.txt` | `cat gate/isolation-db.txt gate/isolation-driver-verify.txt` | `isolation actual` |
| DB-host CPU | `<result-dir>` | `runs/threads-*/round-*/mpstat-db.txt` | `<command>` | `%usr / %iowait / %idle` |
| DB-host IO | `<result-dir>` | `runs/threads-*/round-*/iostat-1s-db.txt` | `<command>` | `r/s / w/s / %util` |
| DB config | `<result-dir>` | `db-config/*` | `<command>` | `cluster setting / effective config` |

## v4.7 檢核項

| 項目 | 目標 |
|---|---|
| Run 結構 | 5 round × 5 min × 4 thread groups (16/32/64/128) + 20min warmup @ 64 threads |
| Round artifact 格式 | `runs/threads-X/round-Y/go-tpc-stdout.txt` |
| DB-host 監控 | mpstat / iostat / vmstat / sar 1s 取樣，client (`*.txt`) + DB-host (`*-db.txt`) 雙邊 |
| Gate 雙閘 | `isolation-db.txt` + `isolation-driver-verify.txt`，兩者一致才放行 |
| Suite marker | `.gate.done` / `.prepare.done` / `.gate-isolation.done` / `.run.done` / `.collect.done` / `.suite.done` |
| TPCC_TS | `yyyyMMddTHHmmss+0800` 共用整 suite |
| 平均口徑 | tpmC / p50 / p95 / p99 全為 5-round mean，range/mean 看穩定性 |
| 三 isolation 矩陣 | READ COMMITTED + REPEATABLE READ + 最嚴格隔離級 |
