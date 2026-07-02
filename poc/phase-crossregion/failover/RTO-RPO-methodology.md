# RTO / RPO Methodology — phase-crossregion PoC

> Status: **spec / planner-only**
> 本文件僅定義 RTO / RPO 在 distributed SQL + raft 情境下的量測方法論，
> 不含 runtime chain（不寫 deploy / kill / restore 串接）。實跑啟用需 PR + DBA review，
> 遵循 `chaos/README.md` 與 `failover/F1.md` 的 planner-only 限制。
>
> Ground truth:
> - F1 spec: `phase-crossregion/failover/F1.md`
> - chaos spec: `phase-crossregion/chaos/{C1,C4,C7}.md`
> - topology: `phase-crossregion/topology/{P-A,P-B}.md`
> - 決策來源: `1_MeetingMinutes/0602-decisions-track-E.md` §C5 / §9 / §10.4
> - 適用 phase: `manifest.yaml` (X-CROSS, RF=3, isolation=rc)

---

## 1. 定義段

### 1.1 RTO（distributed SQL + raft 情境）

> 與傳統 backup/restore RTO（從 dump 還原到資料庫可用）**不同**。

**本 PoC 採用之 RTO 定義**：

```
RTO = t(incident 後第一筆 successful write 收到 commit ack)
    − t(incident trigger 之 wall-clock)
```

關鍵點：
- 量的是 **raft leader election + lease handover + client routing 收斂** 三段的總和，
  不是磁碟 / 備份還原時間。
- 「successful」必須是 **commit ack**，不是 "connection up" 也不是 "leader elected"；
  raft term advance 不代表 client 能寫入。
- 起點是 **incident trigger 的 wall-clock**（kill 指令 ssh 返回 / iptables -A 返回），
  不是 raft 偵測到 leader 失聯的時間。
- 終點 client 必須是 **incident 後新 routing 路徑** 上的 client（F1: GCP-side；
  C4: 任一可達 client，視 leader 重選位置）。

### 1.2 RPO（distributed SQL + raft 情境）

> 與傳統 backup/restore RPO（最近一次完整備份的時間差）**不同**。

**本 PoC 採用之 RPO 定義**：

```
RPO = |S_pre − S_post|   （單位：transaction 筆數，非時間）

S_pre  = incident 前 W 秒已收到 commit ack 的 (w_id, d_id, o_id) 集合
S_post = incident 後從新 leader 可查詢到的 (w_id, d_id, o_id) 集合
```

關鍵點：
- 量的是 **synchronous raft commit 保證是否真的成立**，不是 async replica lag。
- F1 spec §RPO 已選定 W=5s 為 "kill 前 5 秒" 視窗；本方法論沿用 W=5s 作為其他場景的默認。
- 理論上 `RF=3 + raft majority commit + isolation=rc` 模型下 `|S_pre − S_post| = 0`；
  非 0 即為紀錄級別的 **invariant 違反**（值得單獨開 issue 追）。
- RPO 在「以時間表示」的場合，採用 `last_committed_ts(S_pre) − earliest_visible_ts(S_post)`
  作為輔助指標（見 §4 三 DB 各家具體 query）。

### 1.3 與 p99 / error rate / tpmC drop 的關係

| 指標 | 量的是 | 與 RTO/RPO 關係 |
|---|---|---|
| **RTO** | 不可用 → 可用的時間窗口 | 主指標，唯有 failover / leader die 場景適用 |
| **RPO** | 不可用視窗中遺失的 commit | 主指標，與 RTO 配對 |
| **tpmC drop %** | 整段不可用 + 降級期的吞吐損失 | RTO 內 tpmC 通常掉到 0；RTO 結束後仍可能持續降級（degraded） |
| **p99 latency spike** | 單筆 tx 延遲尾巴 | RTO 結束後 p99 仍可能維持高於 baseline 數十秒（warm cache / leader re-balance） |
| **error rate by sec** | go-tpc 統計的失敗筆數 / 秒 | RTO 視窗內為 100%（quorum-lost / no leader / context deadline）；輔助確認 RTO 邊界 |
| **healing curve 收斂時間** | tpmC 回到 baseline ±N% 所需時間 | 比 RTO 長；屬 **steady-state recovery time**，與 RTO 不同概念 |

→ RTO 為「業務可重新接受寫入」的硬指標；其他四項為「業務體感品質」的軟指標。
   不要混淆。本 PoC 報告需分開列。

---

## 2. 四場景指標矩陣

> P-A: 2-IDC + 1-GCP majority IDC；leader 在 IDC。
> P-B: RF=3 全 full voter 跨 IDC/GCP 散置（無 arbiter）；per-shard leader 散區。
> 詳 `topology/P-A.md` / `topology/P-B.md`。

| 場景 | RTO 適用 | RPO 適用 | 主指標（優先序） | 主要來源 | 通過閾值 |
|---|---|---|---|---|---|
| **F1**（planned IDC→GCP） | 是（P-A 主測；P-B 退化測） | 是 | 1) `rto_sec` 2) `rpo_lost_tx_count` 3) tpmC dip area 4) p99 | F1.md §artifact + driver wall-clock + leader-handover.log | TBD（由 dry-run 校準；F1.md §RTO 已記錄 lab-mode assumption ~5–30s） |
| **C1**（GCP WAN partition） | **不適用**（availability event，非 failover） | **部分**（僅 P-B 適用；見 §5） | 1) tpmC drop % 2) error rate by sec 3) healing curve 收斂時間 4) p99 spike | go-tpc stdout + chaos/C1/{tpmc-1s.txt, error-rate-by-sec.txt} | TBD（依 P-A vs P-B 而異；見 §5） |
| **C4**（IDC leader die） | 是（P-A / P-B 均適用） | 是 | 1) `rto_sec`（leader election only）2) `rpo_lost_tx_count` 3) tpmC dip + recovery curve | chaos/C4/tpmc-1s.txt + driver wall-clock + admin leader query | TBD（C4.md §預期 RTO 表已列各家 election timeout default：TiDB ~10s / CRDB ~9s / YBDB ~5–15s — 為 spec assumption） |
| **C7**（cluster write reject / placement gate fail-closed） | **不適用** | **不適用** | 1) write_failure_rate（應 100%） 2) read_availability（stale follower read 應維持） 3) placement actual ≠ expected 是否被 gate 攔下 4) split-brain 防護是否啟動（無新 leader） | C7.md §Validation 三家 SQL + dry-run-confirm placement gate | write_failure_rate = 100% AND no_new_leader_elected = true |

### 2.1 P-A vs P-B 差異速查

| 場景 | P-A 行為 | P-B 行為 |
|---|---|---|
| F1 | IDC leader kill → GCP follower 成 leader；2 IDC voter 剩 1 + 1 GCP voter = quorum 仍成立但 latency 升 | per-shard leader 散；只切該 shard，其他 shard leader 不動 |
| C1 | IDC majority 仍可寫；GCP-side client 走 idc-haproxy fail（路由斷）；**RPO 在 IDC 側為 0** | per-shard 兩區各 voter；partition 後**兩區皆 minority** ⇒ 全 cluster 寫拒；**等同 C7** |
| C4 | IDC 剩 1 IDC voter + 1 GCP voter = quorum；新 leader 通常仍在 IDC（lease_preferences）| per-shard 只該 shard-X-leader-IDC 失效；其他 shard leader (GCP) 不變 |
| C7 | IDC 3 voter 全死 → 每 shard 剩 1 GCP voter = minority ⇒ 全 cluster 寫拒 | IDC 全死後 per-shard 只剩 GCP-side voter（無 arbiter）；quorum 是否成立依各 shard GCP voter 數而定（三家分布不同：CRDB 2-IDC+1-GCP、YBDB 1-IDC+2-GCP、TiDB PD 自動散） |

---

## 3. RTO 具體量測程序

### 3.1 公式（F1 / C4 共用）

```
RTO = t_first_write_post − t_incident
```

- `t_incident`：driver 端 wall-clock，trigger 指令送出**或**收到 ssh ack 的時點（採後者，較精確）
- `t_first_write_post`：incident 後 client 端收到第一筆 NEW_ORDER commit ack 的 wall-clock

兩個時間戳必須由**同一台 driver host** 取得，避免 NTP 偏移（見 §7）。

### 3.2 go-tpc 1s tick 顆粒度問題

go-tpc stdout summary 行為 1s tick aggregation，**沒有 per-transaction wall-clock**。
直接從 stdout 看「first NEW_ORDER after incident」最佳精度 = 1 秒。

→ 對應 RTO < 1s 的場景（理論上 raft election timeout 已 ≥ 1s，但仍須留 budget）：

**佐證手段**（任一即可，建議兩個都做）：

1. **Driver-side wrapper script**：
   - 在 go-tpc 啟動前後 echo `date -u +%s.%3N`（毫秒精度）到 `t_incident.txt` / `t_first_ok.txt`
   - 注意：這只能標 **driver 整段** 的 wall-clock，不能標單筆 tx
2. **獨立 probe driver**（建議）：
   - 開一支簡單 SQL probe loop（INSERT 一筆 dummy row to a probe table, 100ms 間隔），
     輸出 `(ts_ms, ok|err, err_kind)`
   - probe 與 go-tpc 同 host、同 client routing → ts 由同一 OS clock 提供
   - RTO = `min(ts_ms for ok=true and ts_ms > t_incident) − t_incident`

### 3.3 三家 DB 各自的 leader-transfer 偵測

> 用途：在 RTO 量測**之外**，獨立佐證「leader 確實切換到 incident 後預期的位置」。
> 偵測完成的時間 ≠ RTO；偵測完成早於 / 晚於 first successful write 都有可能（client routing cache）。

| DB | Leader 偵測指令（spec；版本以實 cluster 為準） | poll interval |
|---|---|---|
| **TiDB** | `SELECT * FROM INFORMATION_SCHEMA.TIKV_REGION_PEERS WHERE is_leader=1;` <br> 或 `tiup ctl:<ver> pd -u http://<pd>:2379 region key <hex-key>` <br> 或 pd `member leader show` | 1s（per F1.md §monitoring 為 5s，較粗；本方法論建議 RTO 量測時加密到 1s） |
| **CRDB** | `SHOW RANGES FROM DATABASE tpcc WITH TABLES, DETAILS;`（含 `lease_holder`） <br> 或 `SELECT * FROM crdb_internal.ranges WHERE table_name='warehouse';` | 1s |
| **YBDB** | `yb-admin --master_addresses=<m> list_tablets <table>`（含 leader uuid → 對 host） <br> 或 `yb-admin --master_addresses=<m> get_load_move_completion`（負載搬遷面）| 1s |

→ 三家輸出格式不同；統一 normalise 為 `leader-handover.log` schema：
`<wall_clock_rfc3339> shard=<id> leader_host=<host> term/lease=<num>`（已記於 F1.md §artifact）。

### 3.4 「first successful write」的定義差異（三家）

| DB | 何謂 "commit ack" | 注意 |
|---|---|---|
| TiDB | SQL `COMMIT` 收到 OK；底層為 2PC（prewrite + commit）通過 | TSO 在 PD；PD 若同步處於切換中可能多一段 delay |
| CRDB | SQL `COMMIT` 收到 OK；底層 distributed txn 完成 lease check | range lease handover 期間 client 看到 retry → driver 須區分「retry succeeded」與「first attempt succeeded」 |
| YBDB | SQL `COMMIT` 收到 OK；YSQL layer 之下 tablet leader 完成 raft commit | tablet leader 與 master leader 兩層；master leader stepdown 不直接影響 tablet write，但會卡 DDL |

→ 本方法論統一採 **"client 拿到 OK"** 為界；不細分底層 protocol stage。

---

## 4. RPO 具體驗證程序

### 4.1 理論依據（為何期望 RPO=0）

| 機制 | 保證 |
|---|---|
| `RF=3`（每 shard 3 voter） | 容忍 1 voter loss 仍有 quorum |
| raft majority commit | leader 在 ack client 前必須收到 majority replica 的 log append ack |
| isolation=rc（read committed，per manifest.yaml） | 不允許讀到未 commit 的資料；commit 後的資料保證持久 |
| `lease_preferences` / `voter_constraints` | leader 死後新 leader 必由有完整 log 的 voter 接手（raft safety property） |

→ 數學上 incident 前已 commit 的 tx 在新 leader 上必可見；
   **若量到 `|S_pre − S_post| > 0` 表 raft invariant 被破壞或 client 拿到的 ack 是錯的**。

### 4.2 實測驗證流程

> 不是 "raft 保證 0 所以信它"，是 **查出來確認 0**。

**Step A — 構建 S_pre**：

- incident 前 W=5s 區間內，driver-side 維護一個 in-memory FIFO buffer：
  `(commit_ts_driver, w_id, d_id, o_id)` 對每筆收到 commit ack 的 NEW_ORDER 紀錄
- incident trigger 後 freeze 該 buffer 為 `S_pre`

**Step B — 構建 S_post**：

- RTO 結束（first successful write post-incident）後等待 30s（讓 raft / lease 完全收斂）
- 對 `S_pre` 每筆 `(w_id, d_id, o_id)` 走新 client routing 查詢 `SELECT 1 FROM oorder WHERE o_w_id=? AND o_d_id=? AND o_id=?`
- 查到記為 `S_post`，查不到記為 lost

**Step C — 計算**：

```
rpo_lost_tx_count = |S_pre - S_post|
```

**Step D — 時間面輔助 query**（三家各自，用於若 lost_tx_count > 0 時 diff log timeline）：

| DB | 「最後 commit 的時間戳」query | 「復原後最早可讀」query |
|---|---|---|
| TiDB | `SELECT @@tidb_current_ts;`（TSO，HLC-like） <br> 或對表查 `tidb_mvcc_info()` 拿 commit_ts | 同上；用 `SET tidb_snapshot='<ts>'` 跳到該 ts 驗 readable |
| CRDB | `SELECT cluster_logical_timestamp();`（HLC） <br> 或 `SHOW EXPERIMENTAL_RANGES FROM TABLE` 看 `lease_start` | 同 HLC；可用 `AS OF SYSTEM TIME '<hlc>'` 查 readable |
| YBDB | `SELECT yb_hybrid_time_to_pretty(...)` （HLC） <br> 或 tablet leader 上 `yb-ts-cli dump_tablet <id>` 看 last applied OpId | 用 PITR snapshot 接近時點查 readable（spec 性質；視 build 是否支援） |

→ 三家皆有 HLC 概念；TS 不可跨 DB 直接比較，只能在同 DB 內 sanity check。

### 4.3 「同步 commit 保證 RPO=0」的反證條件

若實測 `rpo_lost_tx_count > 0`，可能原因（**排錯順序**）：

1. driver 把 retry-success 誤計為 ack（最常見） → check driver code
2. probe table 寫到了與 oorder 不同的 shard / placement → 確認 placement 設定
3. client 在 incident 前拿到的 ack 實際是 follower stale read（不應該，但配置錯誤可能）
4. raft majority commit 真的破口（應視為 P0 issue，立即停測）

---

## 5. C1 特殊處理 — partition / availability event

### 5.1 為何不套 RTO 框架

- C1 是 **network partition**，不是 leader 死亡 → 沒有 failover 發生（在 P-A）
- partition 期間：
  - P-A：IDC majority 仍可寫；只是 GCP client 路由斷
  - P-B：兩區皆 minority；**全 cluster 寫拒**，但這是 split-brain 防護，**不是 failover**
- partition restore 後系統會自動回穩；那段 catch-up 時間屬 healing，不是 RTO

### 5.2 建議指標組合（依 P-A / P-B 分開報）

| 指標 | P-A 期望行為 | P-B 期望行為 |
|---|---|---|
| **tpmC drop %**（IDC-side client） | 接近 0%（IDC majority 不擋寫；可能僅 sync_replicate_to_gcp queue backpressure 些微影響） | 接近 100%（split-brain 防護 → 寫全拒） |
| **tpmC drop %**（GCP-side client） | 100%（路由全斷，GCP client 走 idc-haproxy 不通） | 100% |
| **error rate by sec** | GCP-side 100%；IDC-side ~0% | 兩側 100% |
| **error kind 分布** | GCP-side: `connection refused` / `i/o timeout`；IDC-side: 少量 `replicate to follower failed` warning | 兩側皆 `quorum lost` / `no leader` / `context deadline exceeded` |
| **p99 spike**（IDC-side） | 些微升高（leader 不再等 GCP voter ACK；理論上 raft commit latency **降低**，但 region rebalance 可能造成短暫尖峰）| N/A（寫全拒） |
| **healing curve 收斂時間** | partition restore → tpmC 回到 baseline ±5% 所需時間（含 GCP voter catch-up）| 同左；P-B 預期 catch-up 較久（積壓的兩側都需重新同步） |
| **RPO**（partition restore 後查 S_pre vs S_post） | IDC-side commit 應 100% 保留（P-A IDC majority 未斷）| 兩側皆無新 commit；RPO 退化為 trivial = 0 |

### 5.3 量測來源

- `chaos/C1/tpmc-1s.txt`：1s 粒度 tpmC 曲線；標記 `t_inject` / `t_restore`
- `chaos/C1/error-rate-by-sec.txt`：含 error kind 分類
- `chaos/C1/leader-redist-trace.txt`：partition 期間是否觸發 spurious leader election（P-A 不應該；P-B 應觀察到 election 嘗試但 quorum 失敗）

### 5.4 通過閾值（spec 性質）

- P-A：IDC-side tpmC drop **<10%**（TBD，由 dry-run 校準）；GCP-side 完全斷可接受
- P-B：write_failure_rate = 100%（split-brain 防護啟動 = pass）；無 spurious commit
- healing curve：partition restore 後 **≤ 60s** 回到 baseline ±5%（TBD）

---

## 6. C7 特殊處理 — placement gate fail-closed

### 6.1 C7 性質

- C7 是 **gate 驗證**，不是 failover：
  - 注入：IDC 3 node 全停（或對應 region majority loss 條件）
  - 預期：cluster 進入 write-reject 狀態；**沒有任何新 leader 在 GCP 被選出**
  - 同步：dry-run-confirm 的 `placement actual ≠ expected → fail-closed` gate
    應在部署階段就攔下不合法 placement（見 `topology/P-A.md` §驗證 gate 與
    `0602-decisions-track-E.md` §10.2 / 任務 5）
- C7 是 **要證明 split-brain 防護啟動 + placement gate 不被 bypass**，
  不是要量「多久切回來」

### 6.2 不適用的指標

| 指標 | 為何不適用 |
|---|---|
| RTO | 沒有 failover；系統正確行為是 **永遠不可寫**（除非 IDC 復原）|
| RPO | 沒有新 commit；S_post 對 S_pre 的查詢仍可由 GCP follower 提供 stale read，但這不是 RPO 語意 |
| tpmC | 寫全拒；tpmC = 0；無曲線意義（只能標 "stuck at 0"）|
| p99 | 所有寫 timeout / reject；latency = client-side timeout 設定值，不反映 DB 行為 |

### 6.3 適用指標（gate 驗證）

| 指標 | 期望值 | 來源 |
|---|---|---|
| `write_failure_rate` | 100% | go-tpc stdout error count |
| `new_leader_elected_in_gcp` | **false**（任何 shard） | 三家 admin query（C7.md §Validation）|
| `read_availability_stale` | true（GCP follower 仍可 stale read） | client SELECT 試讀 |
| `placement_gate_triggered_pre_deploy` | true（若刻意把 placement 設錯）| dry-run-confirm 輸出 |
| `cluster_state_self_report` | IDC node = `down` / `DEAD` | C7.md §Validation 三家 SQL |

### 6.4 通過判定

```
PASS = (write_failure_rate == 100%)
     AND (no shard has new leader in GCP)
     AND (stale read still works from GCP follower)
     AND (placement_gate fail-closed when actual ≠ expected)
```

---

## 7. 風險與盲點

### 7.1 go-tpc stdout 1s tick 顆粒度

- stdout summary 為 1s aggregation；理論 RTO 下限 = 1s
- **緩解**：用 driver-side probe loop 或 wrapper wall-clock（§3.2）；
  並在報告中明示 `RTO 精度上限為 ±1s`

### 7.2 NTP / clock 偏移

- 三家 DB 各 node + 兩台 driver host（IDC + GCP）clock 不一致 → wall-clock 比對失準
- **緩解**：
  - Pre-flight 跑 `scripts/gate-chrony-cross-region.sh`（已存在）確認 chrony 同步
  - RTO 量測限定 **單一 driver host 內** 取兩個時間戳（t_incident、t_first_ok），
    不跨 host 比 wall-clock
  - DB-side log timestamps（leader-handover.log）僅作 **佐證 / 排序**，不直接代入 RTO 公式

### 7.3 driver 側 wall-clock pre/post timestamp

- **建議實裝**：
  - F1: `kill.log` 內已有 `t_kill RFC3339 ms`（F1.md §artifact）
  - C4: 同樣模式，記 `t_stop_ack` 為 ssh return 時點
  - probe loop 並行於 go-tpc，產 `probe.txt`：`<ts_ms> <ok|err> <err_kind>`
  - RTO 計算時優先採 probe.txt，go-tpc stdout 作交叉驗證

### 7.4 "first successful write" 定義差異

- 已於 §3.4 列三家差異；統一以「client 拿到 COMMIT OK」為界
- 注意：CRDB 的 client retry 機制可能讓「第一次 attempt 成功」與「第 N 次 retry 成功」
  視覺上相同 → driver 須開 verbose log 區分

### 7.5 client routing cache

- TiDB region cache / CRDB range cache / YBDB tablet cache 在 leader 切換後不會立即 invalidate
- client 在 RTO 窗口尾段可能仍打舊 leader → 看似 "leader 已切但 client 仍 fail"
- **緩解**：probe driver 須使用「不快取 leader 位置」的 routing（每次重連 / 指 haproxy）
  或接受 RTO 含 client cache 收斂時間（業務體感視角合理）

### 7.6 RPO=0 的 driver 端誤計風險

- 已於 §4.3 列出；driver 將 retry-success 計入 S_pre 是最常見偽 RPO loss 源
- **緩解**：driver code review；S_pre 只接受 **第一次 attempt OK** 的 (w_id, d_id, o_id)

### 7.7 P-B 場景 RTO 多 shard 並發

- P-B 每 shard leader 散在不同區；一次 incident 可能同時切多 shard
- RTO 不可只看單 shard；建議報告 `max(rto_per_shard)` 與 `median(rto_per_shard)` 兩個值
- 對應的 probe table 須跨多個 shard（建議放 warehouse 表，自然 split）

---

## 8. 與既有 spec 的呼應

### 8.1 F1.md

- F1.md §RTO 已記載 `rto_sec = t_first_write_gcp - t_kill`，與本方法論 §3.1 公式**一致**
- F1.md §RPO 已採 `kill 前 5s` 視窗 = 本方法論 W=5s 默認
- F1.md §artifact 已含 `rto-rpo.json` schema，本方法論不擴充 schema，沿用
- **本方法論擴充**：
  - §3.2 probe driver 為 F1.md 未涵蓋；建議補入 F1.md §監測流程 step 4
  - §4.3 RPO=0 反證流程為 F1.md 未涵蓋；建議補入 F1.md §RPO 段
  - §7.7 P-B 多 shard 並發為 F1.md 未涵蓋（F1.md 偏 P-A 視角）

### 8.2 C1.md

- C1.md §度量已列 tpmC drop / error rate / leader redistribution，與本方法論 §5.2 **一致**
- **本方法論擴充**：
  - §5.2 P-A vs P-B 期望行為矩陣為 C1.md 未明確列；建議補入 C1.md §預期行為
  - §5.1 "C1 不套 RTO 框架" 為本方法論定論；C1.md 未直接寫但隱含
  - healing curve 收斂時間 C1.md 未列；建議補入度量表

### 8.3 C4.md

- C4.md §度量已含「Leader election RTO = last write before stop → first write after election」，
  與本方法論 §3.1 公式**一致**
- C4.md §預期 RTO 表已列各家 election timeout default → 與本方法論 §2 表中 TBD 條目互補
- **本方法論擴充**：
  - §3.2 probe loop 為 C4.md 未涵蓋
  - §7.7 P-B 多 shard 並發為 C4.md 未涵蓋

### 8.4 C7.md

- C7.md §度量已列 write_failure_rate / read_availability / GCP client retry storm，
  與本方法論 §6.3 **一致**
- C7.md §Validation 三家 SQL 對應本方法論 §6.3 來源欄
- **本方法論擴充**：
  - §6.1 把 C7 framing 為「placement gate fail-closed」+「split-brain 防護」雙重 gate；
    C7.md 偏向只談 split-brain，未呼應 `0602-decisions-track-E.md` §10.2 的 placement gate
  - §6.2 明確列出**不適用的指標**（RTO / RPO / tpmC / p99）；C7.md 未明示

### 8.5 0602-decisions-track-E.md

- §C5（lab 模式 chaos 不測 recovery 正確性）：
  本方法論 §5 / §6 與此一致（C1 / C7 不量 RTO，只量 degraded 行為）
- §9 升級判準：「chaos 出現非預期的 failover RTO 偏差 → 升級 production-like」
  本方法論為該升級提供具體 RTO 量測方法（§3）
- §10.2 / 任務 5（placement actual gate）：本方法論 §6 將其納入 C7 通過判定
- **未發現** 0602-decisions-track-E.md 內有對 RTO / RPO 數值的既決議；
  本文件所有閾值欄位皆標 TBD / "由 dry-run 校準"，**未 fabricate 數字**

---

## 9. 升級到實跑的條件

對齊 F1.md §升級條件 / chaos/README.md §後續開閘流程：

1. 本方法論文件經 DBA 一輪 review
2. probe driver script（§3.2）落地為新 PR；含三家對應的最小 SQL probe
3. driver 端 wall-clock wrapper（§7.3）落地
4. 跨 region NTP / chrony gate 通過（已存在 `scripts/gate-chrony-cross-region.sh`）
5. 對應 cluster 版本的 admin CLI 路徑由 DBA confirm（per F1.md §47-52）
6. F1 / C4 dry-run 跑一輪純 plan，輸出 `rto-rpo.json` schema sanity check（無 cluster 介入）
7. 取得 DBA approve label 才能 merge runtime PR

---

## 10. 變更歷史

| 日期 | commit | 變更 |
|---|---|---|
| 2026-06-26 | (本) | 初版方法論 spec（spec / planner-only，未含 runtime chain）|
