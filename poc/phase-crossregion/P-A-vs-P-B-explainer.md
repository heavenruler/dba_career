# Placement P-A vs P-B 對照說明

> 受眾：C-level / 跨部門主管 / application owner
> 用途：未動工 placement SQL / 部署前的概念對齊；本份**不是**工程細節文件
> 對應 spec：placement spec at `phase-crossregion/topology/P-A.md` / `P-B.md` / `tests/tidb/placement-p-{a,b}.sql`

---

## 1. 一句話差異

| | P-A：IDC 多數派（majority） | P-B：兩區平均散（spread） |
|---|---|---|
| 寫入主節點（leader）位置 | **集中於 IDC** | **任一區皆可（PD 自動分配）** |
| 寫入延遲 | **低**（同機房） | **較高**（部分寫須跨區同步） |
| IDC 機房整死可從 GCP 接手 | △ 需重選 leader 約 30 秒 | ✓ 已有 leader 在 GCP，秒級接手 |
| 適合場景 | 寫多讀少；重要交易主辦在 IDC | 地理 DR 優先；可接受寫延遲偏高 |

---

## 2. 圖示 — Raft 副本配置

### P-A：IDC 多數派 / GCP follower only

```
                ┌─────────────────────┐         ┌─────────────────────┐
                │      IDC zone        │  跨區同步  │      GCP zone        │
                │                      │ ─────→  │                      │
                │  ★ leader            │         │  ☆ follower          │
                │  ★ follower          │         │  ☆ follower          │
                │  (寫入收 quorum)     │         │                      │
                └─────────────────────┘         └─────────────────────┘

每筆寫入：leader 收到 → IDC 同機房 follower confirm → 立即 commit
（不必等 GCP 回應；GCP follower 持續異步追上）
```

- 寫入延遲 ≈ 同機房 raft 同步（毫秒級）
- GCP 跨區同步成 follower → 同步資料用，**不參與寫入決策**
- IDC 整死 → GCP 兩個 follower 須重選 leader（含資料追回，約 30 秒以上 RTO）

### P-B：IDC + GCP 平均散

```
                ┌─────────────────────┐ 跨區雙向同步 ┌─────────────────────┐
                │      IDC zone        │ ────────  │      GCP zone        │
                │                      │ ────────→ │                      │
                │  ★ leader (some)     │ ←─────── │  ★ leader (some)     │
                │  ☆ follower          │           │  ☆ follower          │
                │  ☆ follower          │           │  ☆ follower          │
                └─────────────────────┘           └─────────────────────┘

每筆寫入：leader 收到 → 須至少 2 個副本 confirm（含跨區）→ commit
（部分寫的 leader 在 GCP；IDC client 寫入要等跨區 raft 回應）
```

- 寫入延遲 ≈ IDC ↔ GCP 跨區 raft 同步（10–80 ms 視專線狀況）
- 不論哪區整死，另一區一定還有 leader → 秒級接手
- TPC-C 在 P-B 下 throughput 顯著低於 P-A，p99 latency 顯著高

---

## 3. 量化對比（PoC sweep 預期）

| 指標 | P-A 預期 | P-B 預期 | 落差幅度 |
|---|---|---|---|
| TiDB tpmC @ T=128 (vm-6node-haproxy) | ≈ VM 3-node baseline 的 60-75%（IDC 寫快，但跨區 follower 同步擠 WAN）| ≈ VM 3-node baseline 的 20-40%（半數寫須跨區 quorum）| P-B 比 P-A 低 ~40-50% |
| NEW_ORDER p99 (ms) | ≈ 600–1000 ms | ≈ 1500–3000 ms | P-B 比 P-A 高 2–3 倍 |
| 跨區 failover RTO (IDC 整死) | ~30–60 秒 | ~5–10 秒 | P-B 快 5–10 倍 |
| WAN runtime bytes (per round) | 中等（同步 follower）| 高（雙向 raft commit）| P-B 約 2-3 倍 |

> 上表為 PoC sweep 啟動前預估值；實測數字需 sweep 完成才能確認，目前**沒有實測 PoC 數據**。

---

## 4. 決策樹

```
應用層需求是什麼？
│
├─ 「寫入延遲必須低 / 大部分交易在 IDC」
│   → 走 P-A
│   → 接受「IDC 整死 RTO ~30 秒」、預期 throughput 較好、跨區同步資料延後
│
├─ 「IDC 機房整死必須秒級接手 / 地理 DR 是 hard requirement」
│   → 走 P-B
│   → 接受寫延遲倍增、throughput 降一半
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
| 3 | IDC 機房整死可接受多久接手？ | 30 秒 ~ 1 分鐘 | < 10 秒 hard requirement |
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
