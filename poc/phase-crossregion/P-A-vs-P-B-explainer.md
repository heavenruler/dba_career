# Placement P-A vs P-B 對照說明

> **⚠ Superseded（2026-08-03）**：本文件是**動工前**的概念對齊文件，
> §3 的量化數字是 **PoC sweep 執行前的預估值，非實測**（該節本身已
> 標明）。P-A、P-B 目前已各完成至少一次 W=128 實測（P-B 三個
> workload 皆完成，P-A 缺 A-A），**實測數字與階段性比較**請見
> [`XCROSS-PA-VS-PB-FINAL-COMPARISON.md`](./XCROSS-PA-VS-PB-FINAL-COMPARISON.md)——
> 多數指標的實測方向與本文件 §3 的預測不符。本文件 §2 的 failover/
> quorum 敘述也已於 2026-08-03 更正（見下方），管理者請勿再把本文件
> 的預估 RTO/throughput 當作現況引用。
>
> 受眾：C-level / 跨部門主管 / application owner
> 用途：未動工 placement SQL / 部署前的概念對齊；本份**不是**工程細節文件
> 對應 spec：placement spec at `phase-crossregion/topology/P-A.md` / `P-B.md` / `tests/tidb/placement-p-{a,b}.sql`

---

## 1. 一句話差異

| | P-A：IDC 多數派（majority） | P-B：兩區平均散（spread） |
|---|---|---|
| 寫入主節點（leader）位置 | **集中於 IDC** | **任一區皆可（PD 自動分配）** |
| 寫入延遲 | **低**（同機房） | **較高**（部分寫須跨區同步） |
| IDC 機房整死可從 GCP 接手 | ✗ **RF=3 下 IDC 持 2 voters（majority）；IDC 整死時 GCP 僅剩 1/3 voter，未達 quorum(2)，無法自動選出新 leader 或 commit**，需人工介入（如強制副本恢復，有資料遺失風險），不是「重選 leader 約 30 秒」可解決 | ⚠ **未驗證，且 RF=3、僅兩個 failure domain 不保證整區故障後仍有 quorum**——leader 已分散只降低部分 shard 的 re-election 成本，若失去的是持有 2-voter majority 的 Region，該 shard 仍無 quorum、不可 commit（見 §2 quorum 澄清，2026-08-03 修正） |
| 適合場景 | 寫多讀少；重要交易主辦在 IDC，且能接受「IDC 整區故障 = 資料庫不可用直到人工介入」 | 地理 DR 訴求；可接受寫延遲偏高，但**目前拓樸尚不能保證整區故障下仍可用**，需另外設計（第三 failure domain／witness／更高 RF）才可能達成秒級接手 |

---

## 2. 圖示 — Raft 副本配置

### P-A：IDC 多數派（2 IDC voters + 1 GCP voter，RF=3）

> **修正（2026-08-03）**：先前圖示畫成 IDC 2 + GCP 2 共 4 replicas，
> 與 RF=3 矛盾，已修正為 2 IDC + 1 GCP。

```
                ┌─────────────────────┐         ┌─────────────────────┐
                │      IDC zone        │  跨區同步  │      GCP zone        │
                │                      │ ─────→  │                      │
                │  ★ leader            │         │  ☆ follower（voter） │
                │  ★ follower          │         │                      │
                │  (寫入收 quorum=2)   │         │                      │
                └─────────────────────┘         └─────────────────────┘

每筆寫入：leader 收到 → IDC 同機房 follower confirm → 達成 quorum(2) → commit
（正常健康時不必等 GCP ACK；GCP follower 仍是投票成員，持續同步追上）
```

- 寫入延遲 ≈ 同機房 raft 同步（毫秒級）
- GCP follower 是 Raft 意義上的**投票成員（voter）**，只是正常健康、
  兩個最快 ACK 都來自 IDC 時通常不在 commit latency 的 critical path
  上——**不是**非同步、非投票的 replica。
- **修正（2026-08-03）**：先前寫「IDC 整死 → GCP 兩個 follower 須重選
  leader（約 30 秒以上 RTO）」不成立——RF=3 下 IDC 是持 2 voters 的
  majority Region，IDC 整死時 GCP 僅剩 1 個 voter，**未達 quorum(2)，
  無法自動選出新 leader、也不可 commit**，不是「重選 leader 30 秒」
  可解決的問題，需人工介入（如強制副本恢復，有資料遺失風險）。

### P-B：IDC + GCP 混合分佈（leader 30-70% 混合，仍是 2 IDC voters +
1 GCP voter，RF=3）

```
                ┌─────────────────────┐ 跨區雙向同步 ┌─────────────────────┐
                │      IDC zone        │ ────────  │      GCP zone        │
                │                      │ ────────→ │                      │
                │  ★/☆ leader/follower │ ←─────── │  ★/☆ leader/follower │
                │  （2 voters，視 shard│           │  （1 voter，視 shard │
                │   而定，部分 shard   │           │   而定，部分 shard   │
                │   leader 在此）      │           │   leader 在此）      │
                └─────────────────────┘           └─────────────────────┘

每筆寫入：leader 收到 → 須湊滿 quorum(2) → commit
（IDC-majority 且 leader 在 IDC 的 shard，兩個 IDC voters 即可 commit，
不必等 GCP；只有 GCP leader 或跨區 ACK 成為 quorum 必需時才必經 WAN）
```

- 寫入延遲 ≈ IDC ↔ GCP 跨區 raft 同步（10–80 ms 視專線狀況），**但僅
  限於需要跨區 ACK 才能湊滿 quorum 的那部分寫入**，不是「每筆寫都需
  跨區 quorum」。
- **修正（2026-08-03）**：先前寫「不論哪區整死，另一區一定還有
  leader → 秒級接手」**不成立**——每個 shard 仍是 2+1 voter 分布，
  若失去的是持有 2-voter majority 的那個 Region，該 shard 只剩 1
  voter，即使倖存 Region 原本就有 leader，仍**沒有 quorum、不可
  commit**。不同 shard 的 2-voter majority 方向可能交錯（P-B leader
  30-70% 混合正是刻意如此設計），故任一 Region 整體失效，都可能讓
  部分 shards 失去 quorum，資料庫整體仍可能不可用。leader/lease 已
  分散只能降低**部分** shard 的 leader locality／re-election 成本，
  **不能取代 quorum 的數學限制**。若要達成「整區故障仍可用」，需要
  第三 failure domain／witness 或更高 RF 與明確 quorum placement，
  是重新設計題，不是現行 P-B 已滿足的性質。
- TPC-C 在 P-B 下 throughput 是否顯著低於 P-A、p99 latency 是否顯著
  高，**已有實測數據可查**，且方向因 DB／profile 而異，不是全面一致
  地「顯著低／顯著高」，詳見
  [`XCROSS-PA-VS-PB-FINAL-COMPARISON.md`](./XCROSS-PA-VS-PB-FINAL-COMPARISON.md)。

---

## 3. 量化對比（PoC sweep 預期）

| 指標 | P-A 預期 | P-B 預期 | 落差幅度 |
|---|---|---|---|
| TiDB tpmC @ T=128 (vm-6node-haproxy) | ≈ VM 3-node baseline 的 60-75%（IDC 寫快，但跨區 follower 同步擠 WAN）| ≈ VM 3-node baseline 的 20-40%（半數寫須跨區 quorum）| P-B 比 P-A 低 ~40-50% |
| NEW_ORDER p99 (ms) | ≈ 600–1000 ms | ≈ 1500–3000 ms | P-B 比 P-A 高 2–3 倍 |
| 跨區 failover RTO (IDC 整死) | ~30–60 秒 | ~5–10 秒 | P-B 快 5–10 倍 |
| WAN runtime bytes (per round) | 中等（同步 follower）| 高（雙向 raft commit）| P-B 約 2-3 倍 |

> 上表為 PoC sweep 啟動前預估值。**2026-08-03 更新**：sweep 已完成
> P-A（A-S、A-A-RO）與 P-B（A-S、A-A-RO、A-A）多數 cell，實測數字見
> [`XCROSS-PA-VS-PB-FINAL-COMPARISON.md`](./XCROSS-PA-VS-PB-FINAL-COMPARISON.md)——
> 多數指標的實測方向與上表預測不符（例如 A-S/A-A-RO 多數檔位 TiDB/
> CRDB 的 P-B tpmC 並未低於 P-A），且「跨區 failover RTO」一項的
> 預測前提在 RF=3、兩 failure domain 下**數學上不成立**（見 §2 修正），
> 不可再引用本表作為現況依據。

---

## 4. 決策樹

```
應用層需求是什麼？
│
├─ 「寫入延遲必須低 / 大部分交易在 IDC」
│   → 走 P-A
│   → 接受「IDC 整區故障 = 資料庫不可用直到人工介入」（RF=3 下 GCP
│     僅 1 voter，未達 quorum，不是「重選 leader ~30 秒」可解決）
│
├─ 「IDC 機房整死必須秒級接手 / 地理 DR 是 hard requirement」
│   → **現行 P-A/P-B 皆不滿足此需求**（RF=3、兩 failure domain 下
│     quorum 數學不保證整區故障後可用，見 §2 修正）；需先評估第三
│     failure domain／witness／更高 RF 的重新設計，再談是否可能秒級
│     接手
│   → 若暫時只能接受 P-B，接受寫延遲較高、throughput 因 DB 而異（見
│     實測比較報告），但**地理 DR 承諾本身尚未驗證**
│
└─ 「兩端都重要 / active-active 寫」
    → P-B 加 A-A (Active-Active) workload
    → 接受 max contention 下的 retry / abort 為觀察值
```

---

## 5. application owner 需要回答的問題

| # | 問題 | P-A 適合答 | P-B 適合答 |
|---|---|---|---|
| 1 | 主要交易在哪？ | 集中於 IDC | 跨區雙向 |
| 2 | 寫入 p99 可接受上限？ | < 1 秒 | 2–3 秒可接受 |
| 3 | IDC 機房整死可接受多久接手？ | 需接受「無法自動接手，需人工介入」（GCP 僅 1 voter，未達 quorum） | 若答案是 `< 10 秒 hard requirement`，**現行 P-B 尚無法保證**——需另評估第三 failure domain／witness／更高 RF 的設計 |
| 4 | 寫吞吐量 vs 地理可用性權衡 | 吞吐優先 | 可用性優先 |
| 5 | 跨區 WAN 頻寬成本可接受？ | 中等（follower 同步）| 高（雙向 raft commit） |

> 上述 5 題取得共識前，**不建議直接拍板 P-A 或 P-B**。

---

## 6. 與 PoC 設計的對應

- PoC 規劃 sweep 兩個 placement 都跑（per `decisions-2026-06-08.md` Q8：P-A 先 P-B 後）
- 對應實測數據出來後（cross-region sweep ~150 小時），可回頭判斷「在 104 應用負載下 P-A / P-B 各自的實際代價」
- 短期（D1 跨區 DR 中長期必需、現行 No）：placement 設計與 SQL 已就緒，**等業務需求成熟才啟動 sweep**

---

## 7. 引用

- 規格：placement spec at `phase-crossregion/topology/P-A.md` / `P-B.md`
- SQL：`tests/tidb/placement-p-a.sql` / `placement-p-b.sql`
- 決策來源：`phase-crossregion/decisions-2026-06-08.md` Q8
- 跨區 framework 保留依據：`1_MeetingMinutes/2026-06-09-distributed-db-adoption-non-technical.md` D1
