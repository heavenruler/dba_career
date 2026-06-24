# <Database> TPC-C Pipeline Log — <db>-tc1 / S-BASE

> 本檔記錄 `<Database>` 在 PoC v4.7 框架下的 S-BASE baseline。舊流程、單次 wrapper 或 deprecated 資料需移至 `archive/pipeline-log_old.md`，避免與 v4.7 baseline 混用。

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
- `N` 表示獨立重跑次數（不是 round）；`N=1` 為方向性觀察，需 `N=3` 才可作為對外結論基準（同 README N9）。
- **Phase scope 規則**（2026-06-06 phase isolation framework 後）：本模板主體適用 `S-BASE` (vm baseline)，並於下方補充 `S-K8S` pipeline-log 結構。`baseline_eligible: false` 的 scope (`T-THRD` / `X-CROSS`) **嚴禁**作為跨家對比的 source（[`PHASES.md`](./PHASES.md) §2）。`S-K8S` 屬 `baseline_family: k8s`，與 `S-BASE` 屬不同 family，不可混入 VM 主排名；跨 family 對比須明標 retention / delta 口徑。
- Execute 總覽表為每份 pipeline-log 的主要入口：`vm-1node`、`vm-3node`、`S-K8S` 都必須有總覽表，且第一欄項目需 link 到本檔對應段落 anchor。
- `N` 固定表示獨立 suite 重跑次數；若要描述有效 round 數，欄名必須寫 `有效 rounds`，不可用 `N` 代替。

## 章節骨架與例外（2026-06-04 audit 後新增）

### Mandatory 章節（每家 pipeline-log 必有，依出現順序）

| § | 章節 | 說明 |
|---|---|---|
| 0 | `# <DB Display Name> TPC-C Pipeline Log — <db>-tc1 / S-BASE` + 一行 framing | H1 + 指向 archive |
| 1 | `## 使用規則` 或同等聲明（採本模板規則者可略）| 風格與 N=1/N=3 約定 |
| 2 | `## TL;DR — vm-1node <count> isolation 矩陣完成（<yyyy-mm-dd[/dd]>）` | 整檔最頂 5 段集中總結（核心結論 / tpmC 排行 / 三大發現 / 業務啟示 / 完整資料目錄 / vm-3node 段尾摘要 / 下一步）|
| 3 | `## 取數來源（Data trace）`（或拆入各段內的「取數來源」子節）| tpmC / latency / DB-host 指標的 source-of-truth |
| 4 | `## vm-1node-rc — <date>` | 完整段（環境 / Suite 時序 / Gate / Prepare / Execute / Round-by-round / DB-host / vs 對比 / Saturation / 觀察 / 結論）|
| 5 | `## vm-1node-rr — <date>` | 完整段，同 §4 結構 |
| 6 | `## vm-1node-strict — <date>` *or* `## vm-1node-strict — 略過（<DB> 不支援 SERIALIZABLE）` | 完整段或略過段擇一 |
| 7 | `## vm-3node 系列（4 sub-topology × RC，PoC-DESIGN §6.3.2）` | 共同元件分配 + 5 sub-topology（1s1r / 1s3r / 3s1r / 3s3r / haproxy-3s3r）|
| 8 | `## K8s — 已移轉至 ...` *or* `## Kubernetes — 未排期；待 v4.7 detached suite 重跑後回填` | 收尾段；即使無 K8s 資料也須單行說明 |

### DB-specific optional 章節（夾在 §3 與 §4 之間，或於對應 iso 段內）

| 章節 | 適用 DB | 理由 |
|---|---|---|
| `## YugabyteDB Isolation 注意事項（重跑前置 — 必讀）` | YBDB | tserver gflag + session iso + `yb_get_effective_transaction_isolation_level()` triple gate 為 YBDB 獨有 setup chore |
| `## v4.7 重跑 setup 修法紀錄（<date>）` | YBDB | YBDB-specific 8 個 deploy chore fixes |
| `### RR=SI 機制差異 ★（同名不同實作）` | CRDB | CRDB preview RR 與 TiDB pessimistic RR 文件對比 |
| `### CockroachDB pessimistic 工具集（補充）` | CRDB | CRDB 無 `tidb_txn_mode` 全域開關，補語句層工具集 |
| `### 為何 RR 反而比 RC 快？` | TiDB | pessimistic + snapshot ts 省切換機制解析 |
| `### Error 時序分布 ★ — starting-gun storm` | CRDB | RR / strict 衝突時序分析 |
| `### Error 分析 — N-1 pattern` | YBDB | rr / strict 線性 N-1 error pattern |

### Forbidden 章節（已知反例，不可寫入實際 pipeline-log）

| 章節 | 反例 | 移除原因 |
|---|---|---|
| `## v4.7 重跑檢核項` 表格 | YBDB（已修） | 與本模板末尾 `## v4.7 檢核項` 重複；且 rr / strict 完成後表內仍寫「待測」造成 stale。注意：本模板末尾的 `## v4.7 檢核項` 屬於 **template-acceptance 用 checklist**，**不應複製到實際 pipeline-log** |
| `### TL;DR — vm-3node <N> cells（<date>）` 子表（出現於 §7 開頭）| YBDB（已修）| vm-3node 摘要表應只出現於 §2 TL;DR 主節（2.6 段尾摘要）；§7 開頭只放一行 framing，不重複 table |
| 連續多條 `---` 分隔線 | YBDB（已修） | 每節之間 `---` 必為單條；連續多條為遺留排版錯誤 |

### 風格規則（補強既有 §「使用規則」）

- TL;DR 標題日期格式：`（YYYY-MM-DD/DD）` 無空格、單一斜線 — 反例 `（2026-05-20 / 21）`
- 「下一步」wording 三家須同步：`K8s 對照組待重跑` 不寫 `Kubernetes 對照組待排程`
- vm-1node / vm-3node / S-K8S 的 `Execute 結果總覽` 必須使用段落 link：例如 [`rc`](#vm-1node-rc)、[`1s1r`](#vm-3node-1s1r-rc)、[`unlimit`](#k8s-unlimit-rc無顯式-kubernetes-resource-limits)
- vm-3node 5-cell 摘要在 §2.6 只出現一次；§7 開頭可放 `Execute 結果總覽（vm-3node 5 cells）`，不得再放 stale `TL;DR — vm-3node N cells`
- 失敗 trial（如 F-E FAIL）不入 sub-topology Execute 主表、不入 SUMMARY 5-cell 表；以 `⚠️ ... 不入 canonical` 註腳說明

## TL;DR — <scope>（<date>）

> 本段只放目前最重要結論，避免塞完整分析。完整數據放各 isolation / 各 vm-3node 子拓撲段。

### tpmC 排行

統一 8 欄 ranking-style；`併發` 允許 per-row 變動（讓「peak 點不同 t」訊息留在 TL;DR），thread sweep 細節歸 §「Execute 結果」/「Round-by-round」/「Saturation」，TL;DR 不重複展開。

| 排名 | 案例 / 隔離級 | tpmC | 併發 | DB-host 瓶頸 | err count / round | error rate | N |
|---|---|---:|:---:|---|---:|---:|:---:|
| 🥇 | `<隔離級 / 子拓撲>` | `<tpmC>` | `t??` | `<CPU-bound / IO-bound / retry-bound / coordination-bound / 待確認>` | `<count>` | `<all_txn.error_rate_pct>` | `<1 或 3>` |
| 🥈 | `<隔離級 / 子拓撲>` | `<tpmC>` | `t??` | `<瓶頸>` | `<count>` | `<rate>` | `<1 或 3>` |
| 🥉 | `<隔離級 / 子拓撲>` | `<tpmC>` | `t??` | `<瓶頸>` | `<count>` | `<rate>` | `<1 或 3>` |

> 數據口徑：`err count / round` = `all_txn.error_count / 5`（5-round mean）；`error rate` 取 `summary.json.thread_results.<N>.all_txn.error_rate_pct`。peak 點不同 t 的事實透過 `併發` 欄 per-row 表達；若有跨 iso thread 不一致需更深入觀察，補一行說明指向 §「Execute 結果」。

### 三大發現

1. `<發現 1：例如最高吞吐、sweet spot、瓶頸成因。>`
2. `<發現 2：例如隔離級差異或 retry/error 行為。>`
3. `<發現 3：例如跨家比較 caveat 或下一步。>`

### 業務啟示

- `<用非內部術語說明這組結果對 PoC 決策的意義。>`
- `<說明哪些數據可用、哪些仍不可用。>`

### 完整資料目錄

| 案例 / 隔離級 | TPCC_TS | 主要結果 | 結果目錄 | 詳細段落 |
|---|---|---:|---|---|
| vm-1node / READ COMMITTED | `<yyyyMMddTHHmmss+0800>` | `<tpmC>` | [`<result-dir>`](./vm-1node-rc/<result-dir>/) | [§ vm-1node-rc](#vm-1node-rc) |
| vm-1node / REPEATABLE READ | `<yyyyMMddTHHmmss+0800>` | `<tpmC>` | [`<result-dir>`](./vm-1node-rr/<result-dir>/) | [§ vm-1node-rr](#vm-1node-rr) |
| vm-1node / 最嚴格隔離級 | `<yyyyMMddTHHmmss+0800 或 alias>` | `<tpmC 或 —>` | [`<result-dir>`](./vm-1node-strict/<result-dir>/) | [§ vm-1node-strict](#vm-1node-strict) |
| vm-3node-1s1r / RC | `<yyyyMMddTHHmmss+0800>` | `<tpmC 或 —>` | [`<result-dir>`](./vm-3node-1s1r-rc/<result-dir>/) | [§ vm-3node 系列](#vm-3node-系列4-sub-topology--rcpoc-design-632) |
| vm-3node-1s3r / RC | `<yyyyMMddTHHmmss+0800>` | `<tpmC 或 —>` | [`<result-dir>`](./vm-3node-1s3r-rc/<result-dir>/) | [§ vm-3node 系列](#vm-3node-系列4-sub-topology--rcpoc-design-632) |
| vm-3node-3s1r / RC | `<yyyyMMddTHHmmss+0800>` | `<tpmC 或 —>` | [`<result-dir>`](./vm-3node-3s1r-rc/<result-dir>/) | [§ vm-3node 系列](#vm-3node-系列4-sub-topology--rcpoc-design-632) |
| vm-3node-3s3r / RC | `<yyyyMMddTHHmmss+0800>` | `<tpmC 或 —>` | [`<result-dir>`](./vm-3node-3s3r-rc/<result-dir>/) | [§ vm-3node 系列](#vm-3node-系列4-sub-topology--rcpoc-design-632) |
| vm-3node-haproxy-3s3r / RC | `<yyyyMMddTHHmmss+0800>` | `<tpmC 或 —>` | [`<result-dir>`](./vm-3node-haproxy-3s3r-rc/<result-dir>/) | [§ vm-3node-haproxy-3s3r-rc](#vm-3node-haproxy-3s3r-rc3-shards--rf3--haproxy) |

### Execute 結果總覽（vm-1node 三 isolation）

> 代表點採各 isolation 的 peak / 主要觀察併發；完整 per-round thread sweep 見各 iso 的 `Execute 結果` 表。p99 為 NEW_ORDER 5-round latency mean；err 為 all transaction error rate。`iso` 欄必須 link 到本檔對應段落。

| iso | TPCC_TS | 代表併發 | tpmC mean | range/mean | NO p99 mean (ms) | err | N | 判讀 |
|---|---|---:|---:|---:|---:|---:|---:|---|
| [`rc`](#vm-1node-rc) | [`<yyyyMMddTHHmmss>`](./vm-1node-rc/<result-dir>/) | `<t>` | `<tpmC>` | `<pct>` | `<p99>` | `<rate>` | `<1 或 3>` | `<CPU-bound / IO-bound / 零 error / caveat>` |
| [`rr`](#vm-1node-rr) | [`<yyyyMMddTHHmmss>`](./vm-1node-rr/<result-dir>/) | `<t>` | `<tpmC>` | `<pct>` | `<p99>` | `<rate>` | `<1 或 3>` | `<retry-bound / lock-wait / caveat>` |
| [`strict`](#vm-1node-strict) | [`<yyyyMMddTHHmmss>`](./vm-1node-strict/<result-dir>/) | `<t>` | `<tpmC 或 —>` | `<pct 或 —>` | `<p99 或 —>` | `<rate 或 —>` | `<1 或 3>` | `<原生 strict / alias / skipped>` |

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
- YugabyteDB triple gate（僅 YugabyteDB；其他資料庫忽略本欄）：
  1. default gate：`--ysql_default_transaction_isolation='read committed'`
  2. enable gate：`--yb_enable_read_committed_isolation=true`
  3. active / effective gate：`SHOW TRANSACTION ISOLATION LEVEL` 與 `SELECT yb_get_effective_transaction_isolation_level()`
  > 舊 `SHOW yb_effective_transaction_isolation_level` 已 [deprecated](https://yugabytedb.tips/view-yb-run-time-parameters-values-and-descriptions/)，改用 `yb_get_effective_transaction_isolation_level()` 函式。
- OS gate：`<THP / swappiness / ulimit>`
- Time sync：`<chrony / drift>`
- Disk gate：`<filesystem / mount / free space>`

### Prepare

- DROP / CREATE：`<duration / status>`
- go-tpc prepare：`<duration / status>`
- check-all / row-count：`<duration / status>`
- ANALYZE / statistics：`<duration / status>`
- EXPLAIN dump：`<files>`

### Execute 結果

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

> per-round tpmC + 5-round mean（W=128、指定 isolation、指定 N）。p99 為 NEW_ORDER 5-round latency mean；err 為 all transaction `error_rate_pct`。補充指標見 `summary.json`。
>
> `range/mean` = `(5 round 最大 tpmC - 最小 tpmC) / 5 round 平均 tpmC`，用來看同一併發水位的 round-to-round 波動。
>
> go-tpc 若沒有 think time / keying time，efficiency 遠超 100% 屬正常。

| threads | r1 | r2 | r3 | r4 | r5 | mean | range/mean | NO p99 mean (ms) | err |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 16 | `<r1>` | `<r2>` | `<r3>` | `<r4>` | `<r5>` | `<mean>` | `<pct>` | `<p99>` | `<rate>` |
| 32 | `<r1>` | `<r2>` | `<r3>` | `<r4>` | `<r5>` | `<mean>` | `<pct>` | `<p99>` | `<rate>` |
| 64 | `<r1>` | `<r2>` | `<r3>` | `<r4>` | `<r5>` | `<mean>` | `<pct>` | `<p99>` | `<rate>` |
| 128 | `<r1>` | `<r2>` | `<r3>` | `<r4>` | `<r5 或 —>` | `<mean>` | `<pct>` | `<p99>` | `<rate>` |

### 代表點

**t=<N> / <tpmC> tpmC / NO p99 = <ms> ms**。`<對照說明 / sweet spot / caveat>`。

### Round-by-round tpmC（可選）

> 若 `Execute 結果` 已採 `r1-r5 / mean / range/mean / NO p99 / err` 統一表格，本節可略；若保留，需與 `Execute 結果` 完全一致，避免兩份 per-round 數字漂移。

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
> **回答**：`<CPU-bound / IO wait-bound / retry-bound / network-bound / coordination-bound / 待確認>`。

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

## vm-3node 系列（4 sub-topology × RC，PoC-DESIGN §6.3.2）

> 本段聚合 4 個 direct vm-3node 子拓撲（1s1r / 1s3r / 3s1r / 3s3r）與 1 個 HAProxy 變體（haproxy-3s3r）在 RC 下的執行紀錄與對標分析。子拓撲命名規則：`<shards>s<replicas>r`（例：`3s3r` = 3 shards × RF=3）。`N=1` / `N=3` 嚴謹性定義見 README [N9](./README.md#note-N9)；shard / replica 變數說明見 [N10](./README.md#note-N10)。

### Dry-run anchor 矩陣

| sub-topo | TPCC_TS | Shard planned | RF expected/actual | ISO expected/actual | dry-run.done |
|---|---|---:|---:|---|:---:|
| `1s1r` | `<yyyyMMddTHHmmss+0800>` | 1 | `1 / <actual>` | `READ COMMITTED / <actual>` | `<✅/❌>` |
| `1s3r` | `<yyyyMMddTHHmmss+0800>` | 1 | `3 / <actual>` | `READ COMMITTED / <actual>` | `<✅/❌>` |
| `3s1r` | `<yyyyMMddTHHmmss+0800>` | 3 | `1 / <actual>` | `READ COMMITTED / <actual>` | `<✅/❌>` |
| `3s3r` | `<yyyyMMddTHHmmss+0800>` | 3 | `3 / <actual>` | `READ COMMITTED / <actual>` | `<✅/❌>` |

### Execute 結果總覽（vm-3node 5 cells）

> 代表點採各 sub-topology 的主要觀察併發；完整 per-round thread sweep 見各 cell 的 `Execute 結果` 表。p99 為 NEW_ORDER 5-round latency mean；err 為 all transaction error rate。前 4 cells 為 direct 連線，第 5 cell 為 HAProxy 連線分散變體。`sub-topology` 欄必須 link 到本檔對應段落。

| sub-topology | shard / RF | TPCC_TS | 代表併發 | tpmC mean | range/mean | NO p99 mean (ms) | err | N | 判讀 |
|---|---:|---|---:|---:|---:|---:|---:|---:|---|
| [`1s1r`](#vm-3node-1s1r-rc) | 1 / 1 | [`<yyyyMMddTHHmmss>`](./vm-3node-1s1r-rc/<result-dir>/) | `<t>` | `<tpmC>` | `<pct>` | `<p99>` | `<rate>` | `<1 或 3>` | `<baseline / caveat>` |
| [`1s3r`](#vm-3node-1s3r-rc) | 1 / 3 | [`<yyyyMMddTHHmmss>`](./vm-3node-1s3r-rc/<result-dir>/) | `<t>` | `<tpmC>` | `<pct>` | `<p99>` | `<rate>` | `<1 或 3>` | `<RF cost / caveat>` |
| [`3s1r`](#vm-3node-3s1r-rc) | 3 / 1 | [`<yyyyMMddTHHmmss>`](./vm-3node-3s1r-rc/<result-dir>/) | `<t>` | `<tpmC>` | `<pct>` | `<p99>` | `<rate>` | `<1 或 3>` | `<sharding cost / caveat>` |
| [`3s3r`](#vm-3node-3s3r-rc) | 3 / 3 | [`<yyyyMMddTHHmmss>`](./vm-3node-3s3r-rc/<result-dir>/) | `<t>` | `<tpmC>` | `<pct>` | `<p99>` | `<rate>` | `<1 或 3>` | `<combined cost / caveat>` |
| [`haproxy-3s3r`](#vm-3node-haproxy-3s3r-rc3-shards--rf3--haproxy) | 3 / 3 | [`<yyyyMMddTHHmmss>`](./vm-3node-haproxy-3s3r-rc/<result-dir>/) | `<t>` | `<tpmC>` | `<pct>` | `<p99>` | `<rate>` | `<1 或 3>` | `<HAProxy delta / caveat>` |

### 跨 cell 分析

- `<例如「3s3r 極不穩，stddev 1,400–2,600」這類跨子拓撲機制觀察。>`
- 完整跨 cell 分析請見 [`dispatch-records/<日期>-vm-3node-<all4|haproxy>-rc-<db>-analysis.md`](./dispatch-records/)。

## vm-3node-haproxy-3s3r-rc（3 shards × RF=3 + HAProxy）

> 本段記錄 `vm-3node-3s3r-rc` 拓撲在 HAProxy 連線分散下的執行紀錄；比對 direct 連線（`vm-3node-3s3r-rc`）的差異是本段重點。`N=1` 結果視為方向性觀察，需 `N=3` 才能作為跨家 HAProxy delta 排序依據（[N9](./README.md#note-N9)）。

### 部署差異

- HAProxy 主機：`<host:port>`，TCP roundrobin
- backend：`.32:<port> / .33:<port> / .34:<port>`
- 關鍵設定：`timeout client/server 1h`、`option clitcpka` / `option srvtcpka`（防 prepare 階段連線斷線）
- 客戶端連線：`.31 → <HAProxy host>:<port>`，不再直連 DB

### Execute 結果

> 複製 `vm-1node-rc` 的 `Execute 結果` 統一表格（`r1-r5 / mean / range/mean / NO p99 / err`）填入；HAProxy 也不得退回簡化 `mean / range` 表。

### 對 direct 連線的差異

| threads | direct tpmC | haproxy tpmC | Δ tpmC | direct p99 | haproxy p99 | Δ p99 | 註記 |
|---:|---:|---:|---:|---:|---:|---:|---|
| 16 | `<value>` | `<value>` | `<value>` | `<value>` | `<value>` | `<value>` | `[註1](#note-1)` |
| 32 | `<value>` | `<value>` | `<value>` | `<value>` | `<value>` | `<value>` | `[註1](#note-1)` |
| 64 | `<value>` | `<value>` | `<value>` | `<value>` | `<value>` | `<value>` | `[註2](#note-2)` |
| 128 | `<value>` | `<value>` | `<value>` | `<value>` | `<value>` | `<value>` | `[註2](#note-2)` |

### Caveats

- `<例如 DB-host metrics 缺失 / 首次 dispatch 中斷 / N=1 / direct baseline 本身不穩等。>`
- 完整 HAProxy vs direct 對比分析請見 [`dispatch-records/<日期>-vm-3node-haproxy-vs-direct-3s3r-<db>-analysis.md`](./dispatch-records/)。

## S-K8S pipeline-log 結構（獨立檔，不寫入 S-BASE）

> `S-K8S` 必須放在 `results/<db>-tc1/S-K8S/pipeline-log.md`；不可回填到 `S-BASE/pipeline-log.md` 的 Kubernetes 段。`S-K8S` 屬 `baseline_family: k8s`，只能和 VM baseline 做 retention / delta，不可混入 VM 排名。

### S-K8S H1 與 framing

```md
# <Database> TPC-C Pipeline Log — <db>-tc1 / S-K8S

> 本檔僅紀錄 **S-K8S**（Kubernetes 部署平面）<Database> 對照數據；VM baseline 在 [`../S-BASE/pipeline-log.md`](../S-BASE/pipeline-log.md)。取數口徑一律為各 suite 的 `summary.json`。
```

### S-K8S TL;DR 排行

> TL;DR 排行可放 VM 對照列，但欄位需寫 `有效 rounds`，不要寫 `N`；`N` 僅表示獨立 suite 重跑次數。

| 排名 | variant | tpmC | NO p99 (ms) | err | range/mean | 有效 rounds |
|---|---|---:|---:|---:|---:|:---:|
| 🥇 | VM HAProxy 3s3r (S-BASE 對照) | `<tpmC>` | `<p99>` | `<rate>` | `<pct>` | 5 |
| 🥈 | K8s [`unlimit`](#k8s-unlimit-rc無顯式-kubernetes-resource-limits) RC | `<tpmC>` | `<p99>` | `<rate>` | `<pct>` | `<5 或 caveat>` |
| 🥉 | K8s [`limit`](#k8s-limit-rckubernetes-resource-limits) RC | `<tpmC>` | `<p99>` | `<rate>` | `<pct>` | `<5 或 4/5 caveat>` |

### S-K8S adopted cases

| variant | TPCC_TS | suite path | markers | summary.json |
|---|---|---|---|---|
| K8s [`unlimit`](#k8s-unlimit-rc無顯式-kubernetes-resource-limits) RC | `<yyyyMMddTHHmmss+0800>` | [`<result-dir>/`](./<result-dir>/) | `.suite.done` + `.collect.done` | `<✅ / missing / retrofit date>` |
| K8s [`limit`](#k8s-limit-rckubernetes-resource-limits) RC | `<yyyyMMddTHHmmss+0800>` | [`<result-dir>/`](./<result-dir>/) | `.suite.done` + `.collect.done` | `<✅ / missing / retrofit date>` |

排除 dry-run / partial setup case 時，另外列排除表，不可刪到無跡可追。

### S-K8S Execute 結果總覽

| variant | resource profile | TPCC_TS | 代表併發 | tpmC mean | range/mean | NO p99 mean (ms) | err | N | 判讀 |
|---|---|---|---:|---:|---:|---:|---:|---:|---|
| [`unlimit`](#k8s-unlimit-rc無顯式-kubernetes-resource-limits) | 無顯式 Kubernetes resource limits | [`<yyyyMMddTHHmmss>`](./<result-dir>/) | `<t>` | `<tpmC>` | `<pct>` | `<p99>` | `<rate>` | `<1 或 3>` | `<retention / caveat>` |
| [`limit`](#k8s-limit-rckubernetes-resource-limits) | Kubernetes resource limits | [`<yyyyMMddTHHmmss>`](./<result-dir>/) | `<t>` | `<tpmC>` | `<pct>` | `<p99>` | `<rate>` | `<1 或 3>` | `<retention / caveat>` |

### S-K8S Thread sweep

每個 variant 使用固定 heading，確保 anchor 穩定：

```md
### k8s-unlimit-rc（無顯式 Kubernetes resource limits）
### k8s-limit-rc（Kubernetes resource limits）
```

表格欄位固定對齊 S-BASE：

| threads | r1 | r2 | r3 | r4 | r5 | mean | range/mean | NO p99 mean (ms) | err |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 16 | `<r1>` | `<r2>` | `<r3>` | `<r4>` | `<r5>` | `<mean>` | `<pct>` | `<p99>` | `<rate>` |
| 32 | `<r1>` | `<r2>` | `<r3>` | `<r4>` | `<r5>` | `<mean>` | `<pct>` | `<p99>` | `<rate>` |
| 64 | `<r1>` | `<r2>` | `<r3>` | `<r4>` | `<r5>` | `<mean>` | `<pct>` | `<p99>` | `<rate>` |
| 128 | `<r1>` | `<r2>` | `<r3>` | `<r4>` | `<r5 或 —>` | `<mean>` | `<pct>` | `<p99>` | `<rate>` |

若某 thread 只有 4/5 有效 round，該列 `r5` 寫 `—`，並在表格下方以 caveat 說明，不得默默當 5-round baseline。

### S-K8S VM baseline 對標

| 對照 | tpmC retention | NO p99 Δ | error-rate Δ |
|---|---:|---:|---:|
| unlimit / VM | `<pct>` | `<pct>` | `<pp>` |
| limit / VM | `<pct>` | `<pct>` | `<pp>` |
| limit / unlimit | `<pct>` | `<pct>` | `<pp>` |

公式固定：`retention = K8s / VM`；`Δ = K8s / VM - 1`。

### S-K8S Caveats

- S-K8S 與 S-BASE 屬不同 baseline family；retention 僅量化部署平面開銷。
- `N=1` 只能作方向性觀察；若只有 partial rounds，需同時標 `有效 rounds` caveat。
- resource limits / requests、pod placement、NodePort / HAProxy、storage class、DB-host metrics 可用性都需列入 caveat。

## 歷史檔案

- `archive/pipeline-log_old.md` / `archive/` 下的 pre-v4.7 result：`<是否納入 baseline，通常不納入。>`

## 差異分析註解

| 註記 | 說明 |
|---|---|
| <a id="note-1"></a>註1 | `<差異計算口徑，例如 Δ tpmC = (本組 - 對照組) / 對照組；p99 差異同理。>` |
| <a id="note-2"></a>註2 | `<比較限制，例如不同 isolation、不同 retry 行為、不同 run 方法時不可直接視為引擎優劣。>` |
| <a id="note-3"></a>註3 | `<資料品質限制，例如單次 10min wrapper、5-round mean、manual resume、欄位待修、DB-host metrics 缺失。>` |
| <a id="note-4"></a>註4 | `<機制歸因限制，例如 OS 指標支持瓶頸，但缺少 DB metrics / trace 直接佐證。>` |

## 取數指令索引

| 目的 | 工作目錄 | 使用檔案 | 指令 | 產出 |
|---|---|---|---|---|
| go-tpc summary | `<result-dir>` | `runs/threads-*/round-*/go-tpc-stdout.txt` | `<command>` | `tpmC / latency / error count / error rate` |
| round-by-round tpmC | `<result-dir>` | `runs/threads-*/round-*/go-tpc-stdout.txt` | `<command>` | `r1-r5 tpmC` |
| marker chain | `<result-dir>` | `.*.done` | `ls -al .*.done` | `phase complete` |
| isolation gate | `<result-dir>` | `gate/isolation*.txt` | `cat gate/isolation-db.txt gate/isolation-driver-verify.txt` | `isolation actual` |
| YB triple gate（僅 YugabyteDB）| `<result-dir>` | `dry-run/iso-preset.txt`、`dry-run/expected-vs-actual.txt`、`gate/isolation-db.txt` | `cat dry-run/iso-preset.txt; cat gate/isolation-db.txt` | `default / enable / effective 三層 isolation` |
| DB-host CPU | `<result-dir>` | `runs/threads-*/round-*/mpstat-db.txt` | `<command>` | `%usr / %iowait / %idle` |
| DB-host IO | `<result-dir>` | `runs/threads-*/round-*/iostat-1s-db.txt` | `<command>` | `r/s / w/s / %util` |
| DB config | `<result-dir>` | `db-config/*` | `<command>` | `cluster setting / effective config` |
| dry-run anchor（vm-3node）| `<result-dir>` | `dry-run/*.txt`、`.dry-run.done` | `jq . .dry-run.done; cat dry-run/expected-vs-actual.txt` | `topology / rf / iso actual` |

## v4.7 檢核項

| 項目 | 目標 |
|---|---|
| Run 結構 | 5 round × 5 min × 4 thread groups (16/32/64/128) + 20min warmup @ 64 threads |
| Round artifact 格式 | `runs/threads-X/round-Y/go-tpc-stdout.txt` |
| DB-host 監控 | mpstat / iostat / vmstat / sar 1s 取樣，client (`*.txt`) + DB-host (`*-db.txt`) 雙邊 |
| Gate 雙閘 | `isolation-db.txt` + `isolation-driver-verify.txt`，兩者一致才放行 |
| YugabyteDB triple gate | default + enable + active/effective 三層皆通過才放行；active 改用 `SELECT yb_get_effective_transaction_isolation_level()` |
| Suite marker | `.gate.done` / `.prepare.done` / `.gate-isolation.done` / `.run.done` / `.collect.done` / `.suite.done` + `.db-config.done` |
| vm-3node dry-run anchor | `.dry-run.done` JSON `all_pass=true` + 4 dump txt（cluster-topology / replication-factor / cluster-health / iso-preset / expected-vs-actual）|
| TPCC_TS | `yyyyMMddTHHmmss+0800` 共用整 suite |
| 平均口徑 | tpmC / p50 / p95 / p99 全為 5-round mean，range/mean 看穩定性 |
| 三 isolation 矩陣 | READ COMMITTED + REPEATABLE READ + 最嚴格隔離級（僅 vm-1node；vm-3node 全部以 RC 為主）|
| 重跑次數 N | 對外結論需 `N=3`；`N=1` 僅作為方向性觀察 |

> ⚠️ **本檢核項屬 template-acceptance 用 checklist，不應複製到實際 pipeline-log**；參見上方「Forbidden 章節」說明。

## 三家對齊矩陣（歷史 audit snapshot — 2026-06-04 audit-1 起點）

> 本表為 2026-06-04 audit-1 啟動時的對齊起點，並非當前 active baseline。當前 baseline 見「§ 三家對齊矩陣 current state（2026-06-04 audit-2 後）」（本檔下方）。本表保留作歷史證據（哪些項曾偏離、修了什麼）。

| 對齊項 | TiDB | CRDB | YBDB | 待修正 |
|---|:---:|:---:|:---:|---|
| 章節骨架 §0-§8 | ✓（strict 略過段，合理）| ✗ 缺 §8 K8s 段 | ✓ 多 2 節 stale | YBDB 移除 stale 兩節；CRDB 補 §8 |
| TL;DR 日期格式 | `(2026-05-18/19)` ✓ | `(2026-05-19)` ✓ | `(2026-05-20 / 21)` ✗ | YBDB 改 `(2026-05-20/21)` |
| 「下一步」wording | `K8s 對照組待重跑` ✓ | n/a（無 §8）| `Kubernetes 對照組待排程` ✗ | YBDB 改 `K8s 對照組待重跑` |
| 取數來源 markers | 6 markers | 6 markers | 7 markers（含 `.db-config.done`）| ✓ 合理差異 |
| vm-3node 5 sub-topology Execute | 1s1r placeholder ✗ | 5/5 ✓ | 5/5 ✓ | TiDB 1s1r 補 Execute 數據（待 EXECUTE=1）|
| `## v4.7 重跑檢核項` stale 章節 | ✗ | ✗ | ✓ stale | YBDB 移除（line 706-722）|
| vm-3node 系列開頭 `### TL;DR — vm-3node N cells` 子表 | ✗（合理）| ✗（合理）| ✓ stale 4-cell | YBDB 移除（line 729-738）|
| 連續多條 `---` 分隔線 | ✗ | ✗ | ✓ 2 處（rr 段尾 line 531-535 / strict 段尾 line 700-704）| YBDB 收斂為單條 |
| §6 vm-1node-strict 完整段 vs 略過段 | 略過 | 完整 | 完整 | ✓ 合理 |
| §7 vm-3node-haproxy disk/CPU shift 對比表 | ✓ | ✓ stability shift | ✗（DB-host metrics missing caveat）| ✓ 合理（YBDB metrics 缺失已 caveat）|

### 已知合理差異（不修）

- TiDB `vm-1node-strict — 略過` 段（TiDB 不支援原生 SERIALIZABLE）
- CRDB / TiDB / YBDB 各自 vs 另兩家 cross-DB 對比段 wording 不同
- YBDB optional 兩節（Isolation 注意事項 / v4.7 重跑 setup 修法）— DB-specific deploy chore 獨有
- YBDB haproxy 段缺 CPU/disk shift 對比表 — DB-host metrics 採樣失敗已 caveat
- 取數來源 markers 6 vs 7 — YBDB 修法 #8 後 `.db-config.done` 獨立成 phase

### 待修項目逐項追蹤

| 修正項 | 對應檔 | 預期動作 | 狀態 |
|---|---|---|---|
| YBDB `(2026-05-20/21)` 日期格式 | `yuga-tc1/S-BASE/pipeline-log.md` line 7 | Edit 移除空格 | 待 |
| YBDB「Kubernetes 對照組待排程」→「K8s 對照組待重跑」 | line 46 | Edit | 待 |
| YBDB 移除 `## v4.7 重跑檢核項` 章節 | line 706-722 | Delete 17 行 | 待 |
| YBDB 移除 `### TL;DR — vm-3node 4 cells` 子表 | line 729-738 | Delete 10 行 | 待 |
| YBDB 連續 `---` 收斂為單條 | line 531-535、line 700-704 | Edit | 待 |
| CRDB 補 `## Kubernetes — 未排期` 收尾段 | `crdb-tc1/S-BASE/pipeline-log.md` 末尾 | 新增 1 節 | 待 |
| TiDB vm-3node-1s1r Execute 數據 placeholder | `tidb-tc1/S-BASE/pipeline-log.md` line 439 | 待 EXECUTE=1 跑完回填 | 排程 |

## 三家對齊矩陣 current state（2026-06-04 audit-2 後）

| 對齊項 | TiDB | CRDB | YBDB | 備註 |
|---|:---:|:---:|:---:|---|
| Mandatory §0-§8 完整 | ✓ | ✓ | ✓ | YBDB stale 2 節已移除（F3/F4）；CRDB 補 K8s 收尾（F6）|
| 每 iso 段 11 子節 | ✓ | ✓（rr/strict 補 Gate/Prepare/Saturation/觀察，audit-2 F-001）| ✓ | — |
| vm-3node 5 sub-topology Execute | ✓（1s1r 已回填，F7）| ✓ 5/5 | ✓ HAProxy 段補 3 子節（audit-2 F-002）| — |
| TL;DR 日期格式 `(YYYY-MM-DD/DD)` | ✓ | ✓ | ✓（F1 已去空格）| — |
| 「下一步」wording 同步 | ✓ | n/a | ✓（F2 改為 `K8s 對照組待重跑`）| — |
| Forbidden 章節 hit count | 0 | 0 | 0 | F3/F4/F5 完成 |
| 連續多條 `---` | ✗ | ✗ | ✗（F5 收斂）| — |
| K8s 收尾段 | ✓ archive/pipeline-log-old.md | ✓ Kubernetes — 未排期 | ✓ yuga-tc1-old/archive | — |
| SUMMARY 5-cell 一致性 | ✓ 5/5 | ✓ 5/5 | ✓ 5/5 | audit-2 D8 全 Yes |
| TL;DR ranking 表欄位 | 8 欄統一（併發=t128 三列）| 8 欄統一（併發=t128 三列）| 8 欄統一（併發=t32 三列）| 三家統一 8-col；併發欄允許 per-row 變動（本批三家各 DB 內三列同 t）；audit-2 F-004 收尾 |

### 驗證指令

> ⚠️ scope：只驗 active pipeline-log 三份；`results/*/S-BASE/` glob 會掃入 `cockroach-tc1-old` / `yuga-tc1-old` archive，須以 `-g '!*-old/**'` 排除或明列三份檔。

```bash
ACTIVE='results/tidb-tc1/S-BASE/pipeline-log.md results/crdb-tc1/S-BASE/pipeline-log.md results/yuga-tc1/S-BASE/pipeline-log.md'

# pipeline-log 三家骨架對比（mandatory section header 數）
for f in $ACTIVE; do
  echo "${f}: $(grep -c '^## ' $f)"
done
# 預期：TiDB 7 / CRDB 7（補 K8s 後）/ YBDB 8（含 2 DB-specific optional）

# 連續多條 --- 反例檢查（active scope only）
awk '/^---$/{c++; if(c>=2) print FILENAME ":" NR; next} {c=0}' $ACTIVE
# 預期：0 行

# 過時章節檢查（active scope only）
rg -n '## v4\.7 重跑檢核項' $ACTIVE
# 預期：0 行（archive `yuga-tc1-old/S-BASE/archive/pipeline-log.md:129` 為合理歷史命中，不掃）

# vm-3node TL;DR 子表反例檢查（active scope only）
rg -n '^### TL;DR — vm-3node' $ACTIVE
# 預期：0 行
```
