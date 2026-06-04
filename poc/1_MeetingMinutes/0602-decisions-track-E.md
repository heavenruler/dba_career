# Track E（Cross-region IDC↔GCP）— §12 B+C 決策定案（2026-06-04）

> 對應 [`0602.md`](./0602.md) §12 待確認事項 B 區 + C 區；本檔為 stakeholder 對齊定案 + Pre-P0 落地清單。
>
> 決策來源：2026-06-04 dba-career 對話逐項裁示。

---

## 1. 決策結論一表

### 1.1 B 區 — Track E 必答 7 項

| # | 議題 | 決策 | 影響 |
|---|---|---|---|
| **B1** | 跨區叢集型態 | **single 6-node** | raft 跨 WAN 為 PoC 主旨；放棄 two 3-node + CDC 路徑（logical replication 是不同場景）|
| **B2** | RF=3 placement | **P-A + P-B 兩拓樸都測** | P-A（2-IDC + 1-GCP，majority IDC）→ Test 1；P-B（1+1+1 散開）→ Test 2 |
| **B3** | DB 範圍 | **先 TiDB** | 走現有最熟 ansible/iac；TiDB placement rule 須手寫；數據有趣再擴 CRDB/YBDB |
| **B4** | WAN baseline | **Pre-P0 hard gate** | iperf3 throughput + ping p50/p99 + MTU + 飽和 packet loss；多時段（business hour vs off-peak）；RTT > 50ms 須與 user 重議 PoC 假設 |
| **B5** | N 數 | **全部 N=1** | exploratory caveat；不入跨家 median table；trend confirm 為主 |
| **B6** | TPCC W / warmup | **W=128 / 20min** | 與單區 baseline 完全可比；caveat：r1/r2 跨區 cache warm 不足風險，必要時棄掉 |
| **B7** | baseline 對照 | **current haproxy-3s3r 3-node only** | 不另跑 IDC-only-6-node；caveat：delta 含 (WAN + scale-out 6/3 = 2x) 混合，無法純分離 WAN 變數 |

### 1.2 C 區 — 跨區開放 8 項

| # | 議題 | 決策 | 影響 |
|---|---|---|---|
| **C1** | GCP 10.162.0.x routing | **已開通** | Pre-P0 blocker 解除，可立即啟動 |
| **C2** | Pre-P0 部署路線 | **一次性 6-node ansible 重寫** | 2-3 工作天投資；押注 Track E 多輪迭代攤平成本 |
| **C3** | DB 順序 | **先 TiDB**（確認 B3）| — |
| **C4** | baseline source | **current haproxy-3s3r 3-node**（確認 B7）| — |
| **C5** | chaos C3/C7 風險級 | **lab 模式** | first pass 讓 failure 持續 5 round，看 degraded TPS；recovery validation 留正式化階段 |
| **C6** | Test 2 W 分配 | **Option B：IDC W=1-64 / GCP W=65-128** | 隔離 key conflict 與 WAN 互擾的清訊號 |
| **C7** | chaos 場景範圍 | **首輪 4 場景** | C1 GCP partition / C3 GCP read-only / C4 IDC leader die / C7 cluster write reject；7 全跑留正式化 |
| **C8** | 與 §5 P5 關係 | **獨立、不互斥** | Track E 測跨區、P5 測在區 scale-out；預算二選一 → 先 Track E |

---

## 2. Pre-P0 hard action items

| Order | 任務 | 估時 | 交付物 |
|:---:|---|---|---|
| 1 | **WAN baseline 量測**（B4 hard gate）| 半天（多時段抽樣）| `results/track-e/wan-baseline/<timestamp>/` 內 iperf3.json + ping-p50p99.txt + MTU 探測 + 飽和 packet loss + 時段對照摘要 |
| 2 | **TiDB 6-node ansible 重寫**（C2）| 2–3 工作天 | `iac/ansible/tidb-vm6.yml` + `tidb-vm6.yml.template`（P-A / P-B 兩 placement 變體）+ inventory 含 IDC/GCP 兩區 6 node |
| 3 | **TiDB placement rule 撰寫**（B3 衍生）| 1 天 | `tests/tidb/placement-{p-a,p-b}.sql`；含 placement label hint + `PLACEMENT POLICY` + 驗證 SQL（`SHOW PLACEMENT FOR TABLE`）|
| 4 | **results 子目錄結構預備**（落地後）| 半天 | `results/tidb-tc1/S-BASE/vm-6node-{p-a-test1,p-b-test2}-rc/` 框架 + per-cell `summary.json` parser 確認可吃 6-node `mpstat`/`iostat` × 6 hosts |
| 5 | **dry-run-confirm 補 placement actual gate**（§10.2 Critical）| 半天 | `dry-run-confirm.sh` 新增 placement 落地驗證：若 GCP 變 leader → fail-closed |

**任務 1（WAN baseline）為 P0 前置硬閘**：未拿到合理 RTT/throughput 數據 → P0 不啟。

---

## 3. 主要 caveats（要在 Track E 最終報告明示）

| Caveat | 來源決策 | 在報告中如何處理 |
|---|---|---|
| N=1 → exploratory only | B5 | TL;DR 標明 `N=1 exploratory`；不入跨家 median table；不引用為對外 baseline |
| baseline 含 (WAN + scale-out) 混合 delta | B7 | 三家對比矩陣補腳注：「3-node IDC haproxy-3s3r → 6-node 跨區 delta 不可純歸因 WAN」 |
| r1/r2 跨區 cache warm 不足風險 | B6 | 若 r1/r2 與 r3-r5 偏離 > range/mean 標準，標明 drop 並重新計算 mean |
| lab 模式 chaos 不測 recovery 正確性 | C5 | chaos cell 章節明示「只測 degraded TPS，不驗 failover RTO / 資料完整性」 |
| placement actual 失敗風險（GCP 變 leader） | §10.2 / B2 | dry-run-confirm 含 placement gate；若 fail-closed → Pre-P0 排除後再啟 |

---

## 4. Pre-P0 → P0 → P4 排序

```
Pre-P0  (~3-5 工作天)
  ├── 任務 1：WAN baseline 量測          [hard gate]
  ├── 任務 2：TiDB 6-node ansible 重寫
  ├── 任務 3：TiDB placement rule
  ├── 任務 5：dry-run placement gate
  └── 任務 4：results 子目錄
                ↓
P0  (~3h × 5 cell × 1 batch)
  └── IDC-only-6-node TiDB 5-cell（純 in-region 6-node baseline）
        ※ 注：B7 已決定 baseline 用 current 3-node，本步驟可選；
          建議仍跑作為 dry-run 場域熱身、驗證 ansible 正常
                ↓
P1  (~3h × 5 cell)
  └── P-A 拓樸 / Test 1（IDC-only TPCC，GCP 純 follower voter）
        thread sweep 16/32/64/128, W=128, 5 round
                ↓
P2  (~3h × 5 cell)
  └── P-B 拓樸 / Test 2（IDC + GCP 並行 TPCC，W=1-64 / W=65-128 分配）
                ↓
P3  (~半天 × 4 場景)
  └── 4 chaos（C1 GCP partition / C3 GCP read-only / C4 IDC leader die / C7 write reject）
        lab 模式，failure 持續整個 5 round
                ↓
P4  (~1 工作天)
  └── Track E 報告產出：pipeline-log + SUMMARY + 跨家對齊矩陣對應位置 + Track E section
```

**升級判準**（do we extend Track E?）：
- 若 Test 2 P-B WAN 延遲對 tpmC 損耗顯著 (> 30%) → 升級到 CRDB/YBDB 重測
- 若 chaos 出現非預期的 failover RTO 偏差（>>單區 baseline）→ 升級 production-like recovery validation
- 若 W=1-64 / W=65-128 隔離下仍有 key conflict 信號 → 升級到 W=128/128 兩側極端 contention

---

## 5. 跨參考

- 整合會議備忘：[`0602.md`](./0602.md)
  - §10 Track E 詳細設計
  - §12 待確認事項 B+C 區（本檔對應）
- standing 議程：[`0602-agenda.md`](./0602-agenda.md)
- pipeline-log 模板（Track E 落地時遵循）：[`../results/pipeline-log-template.md`](../results/pipeline-log-template.md)
- TPCC log 取數口徑：`tests/common/summary-from-stdout.py`

---

## 6. 變更歷史

| 日期 | 變更 | commit |
|---|---|---|
| 2026-06-04 | 初版定案，逐項記錄 §12 B+C 15 項決策 | (待 commit) |
