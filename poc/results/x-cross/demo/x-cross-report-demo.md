# X-CROSS Exploratory Report — OFFICIAL EXPLORATORY / NOT-AN-ADOPTION-DECISION

> **Status**: framework-only preview。**正文 §1 起不含 fake 數字**；TL;DR 章節含 synthetic illustrative（per user 授權 2026-06-30）量級錨架構合理範圍，非 measurement。未量到的值寫 `TBD (not measured)`。
> Generated: 2026-06-29 · Updated: 2026-06-30（+TL;DR） · Author: planner-only · 對應 SSOT: `phase-crossregion/manifest.yaml`
> Promotion 條件見 `x-cross-report-demo-audit.md` §6（9 項）。

Evidence-state tags 用法：
- **MEASURED**: artifact 真實存在且通過 schema 檢查（`results/x-cross/...`）
- **DERIVED**: 由 MEASURED 經明確規則推導
- **INFERRED**: 邏輯/架構推論，非實測；可能錯
- **PLANNED**: spec 已寫但未跑
- **BLOCKED**: 缺前置（owner / driver / FW / spec reconcile），不可推進
- **SYNTHETIC**: 僅 TL;DR 使用；量級錨架構合理範圍但非 measurement

---

## TL;DR — 三情境快速理解（[SYNTHETIC]）

> ⚠️ 本章節含 **synthetic illustrative** 數字（per user 授權）；量級錨架構推導範圍但**不是 measurement**。正式 cell run-once 後 TL;DR 將以 MEASURED 重寫；正文 §5-§9 至今不含 synthetic。

### A. 跨專線 X-CROSS 6-node vs IDC-only S-BASE 3-node 性能解讀

**重要說明（per codex F6）**：S-BASE 三節點 (vm-3node) 與 X-CROSS 六節點 (vm-6node) **不是成對對照組 (paired control)** — 節點數、法定人數 (quorum)、硬體、placement 都不同。下表僅作**情境參考 (contextual reference)**，**禁用「保留率 / 跨區耗損 / Δ」任何算式**作對外結論。

per `phase-crossregion/manifest.yaml` placements 與 workload-profiles — **完整 3 × 3 × 2 矩陣**（架構上三家 DB 都能跑全部 profile × placement）：

| DB | Profile | P-A 跨區 tpmC [合成示意] | P-A 對 3-node 比值 | P-B 跨區 tpmC [合成示意] | P-B 對 3-node 比值 | S-BASE 3-node tpmC [合成示意] | P-A 主要成本來源 | P-B 額外成本 |
|---|---|---:|---:|---:|---:|---:|---|---|
| TiDB | A-S (主動-待命) | 18,000 | 0.82 | 9,000 | 0.41 | 22,000 | IDC 主 + 1 GCP 半同步確認 | leader 跨區分布；每筆提交需跨區 raft 來回 |
| TiDB | A-A-RO (雙活-唯讀) | 14,000 | 0.64 | 7,500 | 0.34 | 22,000 | + GCP 讀取網路往返 (RTT) 進入查詢路徑 | + leader 跨區後讀取進一步惡化 |
| TiDB | A-A (雙活) | 10,000 | 0.45 | 5,500 | 0.25 | 22,000 | + 兩端寫入；Percolator 二階段提交跨區 | + leader 跨區；成本最重 |
| CRDB | A-S (主動-待命) | 16,500 | 0.85 | 8,000 | 0.41 | 19,500 | range leaseholder 在 IDC + 複寫確認 | leaseholder 跨區分布 |
| CRDB | A-A-RO (雙活-唯讀) | 12,500 | 0.64 | 6,800 | 0.35 | 19,500 | + GCP 副本讀取網路往返 | + leaseholder 跨區分布 |
| CRDB | A-A (雙活) | 9,500 | 0.49 | 5,200 | 0.27 | 19,500 | 跨區分散式交易 | + leaseholder 跨區分布 |
| YBDB | A-S (主動-待命) | 15,000 | 0.83 | 7,500 | 0.42 | 18,000 | DocDB tablet leader 在 IDC + 同步複寫 | tablet leader 跨區分布 + YSQL 閘道路由 |
| YBDB | A-A-RO (雙活-唯讀) | 11,500 | 0.64 | 6,300 | 0.35 | 18,000 | + YSQL 閘道跨區讀取 | + tablet leader 跨區分布 |
| YBDB | A-A (雙活) | 8,800 | 0.49 | 4,800 | 0.27 | 18,000 | + 跨區 DocDB raft | + tablet leader 跨區分布 |

**正確解讀**：

1. **「3→6 節點預期 +50-80% 效能」被跨區提交成本抵消** — 6 節點 IDC 內同 W=128 應達 ~33,000-40,000 tpmC（×1.5-1.8 of 3 節點），但 X-CROSS 加上 raft 提交 / lease 確認 / 網路往返後**淨結果回到 0.4-0.85 × 3 節點區間**。**這不是「6 節點不如 3 節點」**，而是「跨區成本 > 額外資源帶來的增益」
2. **A-S (主動-待命) 模式不跨區讀寫**（IDC 主寫 + GCP 待命冷待）→ 成本集中在「提交複寫」，使用者查詢路徑仍在 IDC 本地；表中 A-S 行比值較高（0.82-0.85）
3. **A-A-RO (雙活-唯讀) 開啟 GCP 讀流量** → 成本 = 複寫 + 讀取 RTT；比值降至 ~0.64。**前提**：必須 `SET GLOBAL tidb_replica_read='closest-replicas'`（per `1_MeetingMinutes/0630.md` §5.3 + [TiDB Follower Read 官方文件](https://docs.pingcap.com/zh/tidb/stable/follower-read/)）；default `leader` 模式下 GCP 讀仍跨區到 IDC TiKV Leader → 表中數字不成立
4. **A-A (雙活) 兩端皆寫** → 成本 = 複寫 + 跨區分散式交易 + 主鍵衝突重試；比值降至 ~0.45-0.49。**前提**：需 **geo-partition + per-region leader** 配置（per 0630.md §5.4：同份資料強一致寫入「GCP 內」不成立；GCP 寫 GCP 必須是不同 partition 的 leader 在 GCP）；無此配置時兩端寫實際都跑 IDC Leader → A-A 與 A-S 數字趨同，table 失準
5. **P-A (主分布 IDC) leader 集中 IDC**：提交 = IDC 內 raft 多數派 + GCP 半同步確認（單次跨區）；效能接近本地 + 1 次 RTT 額外開銷
6. **P-B (主跨區分布) leader 跨區分布**：每筆提交 = 跨區 raft 來回（必須）→ 比值降至 ~0.41-0.42（最重）
7. **Control plane 成本永遠跨區**（per 0630.md §6）：即使 data plane 走 closest-replicas，PD Region metadata fallback 與 TSO request 在 PD Leader 固定 IDC 時仍跨區；GCP TiDB cache miss / Region split / TSO 取號每次 ~50ms 跨區。建議 `pd_enable_follower_handle_region=ON`（TiDB 8.5+ GA）+ 評估 `tidb_enable_tso_follower_proxy`（per 0630.md §6.3）
8. **「就近讀寫」嚴格定義**（per 0630.md §10 verbatim）：「IDC / GCP Client 先進入當地 TiDB；讀取優先使用當地 TiKV replica；寫入送往資料唯一的 Region Leader；跨專線承載 Raft、PD/TSO control traffic 與必要 fallback。」 **不是**「IDC Request 絕不離開 IDC，GCP Request 絕不離開 GCP」— 單一強一致 cluster 做不到，需獨立 cluster + async replication，或 geo-partition + 對應區域 Leader，或接受 Stale Read

### B. 故障切換情境 (Failover Scenarios) — 讀 / 寫 (UPDATE) 統計

| 情境 | 觸發條件 | 讀取影響 | 寫入 (UPDATE) 影響 | 切換期間錯誤率 | RTO 復原時間 [合成示意] | RPO 資料遺失 | 解讀 |
|---|---|---|---|---|---:|---:|---|
| **F1 計畫性切換 (planned)** | 透過管理 CLI 主動讓 leader 下台 (per `failover/F1.md`) | ~1-3 秒短暫舊資料讀取（視一致性模式） | 5-30 秒寫入暫停；切到新 leader | ~5-15% 於切換期間 | TiDB 10-30 秒 / CRDB 5-15 秒 / YBDB 10-20 秒 | **理論 0**（raft 多數派 + 讀已提交） | 計畫性 = SLA 上限最樂觀；運維只能保證 ≥ F1 復原時間 |
| **F-非計畫性 IDC 站點失效 (unplanned)** | IDC 連線斷 / 斷電 | 法定人數 (quorum) 視 placement；P-A 寫入癱瘓（需人工切到 GCP）；P-B GCP 自動選舉新 leader | P-A: 寫入暫停直到人工切；P-B: ~10-60 秒 GCP 選舉 | ~30-50% 錯誤尖峰 | P-A: TBD（人工介入）；P-B: 10-60 秒 | TBD（可能丟失進行中的交易） | 災難場景；P-B 理論復原時間較短但常態成本重 |
| **F-副本同步延遲尖峰** | GCP 副本節點暫時失同步 | 影響小；讀取走 IDC | 寫入仍可提交；同步佇列堆積 | <1% | 0（不觸發切換） | 視佇列深度；穩態 0 | 健康度觀察 |

**閱讀要點**：
- **RPO=0 是「raft 多數派 + 讀已提交 (RC)」的理論值**，**非實測** — 需探針工具 (probe driver) 量化（per codex F8）
- 錯誤率量到的是客戶端 (go-tpc) 看見的中止 / 重試，不等於叢集內部提交失敗
- F-非計畫性比 F1 計畫性嚴酷；P-A 在 IDC 站點失效時**寫入癱瘓直到人工介入**，P-B 才有自動選舉

### C. 混沌工程情境 (Chaos Engineering Scenarios) — 讀 / 寫 (UPDATE) 統計

per `phase-crossregion/chaos/{C1,C4,C7}.md` spec（**注意 codex F2：C1/C4 spec ↔ script 命名互換，本表以 spec 為主**）：

| 情境 | Spec | 讀取影響 | 寫入影響 | tpmC 下降幅度 [合成示意] | 錯誤率尖峰 | RTO 復原時間 | RPO 資料遺失 | 解讀 |
|---|---|---|---|---:|---:|---:|---:|---|
| **C1** GCP 廣域網路斷線 (WAN partition；60 秒雙向封包丟棄) | `chaos/C1.md` | IDC 本地讀取不受影響 | P-A: 繼續（IDC 多數派完整）；P-B: ~50% 提交失敗（leader 在跨區） | P-A: -5 至 -15%；P-B: -50 至 -80% | P-A: <1%；P-B: ~30-50% | N/A（未觸發切換） | 0（網路恢復後自動同步） | P-A 對 WAN 斷線抗性最佳；P-B 暴露雙主腦 (split-brain) 風險 |
| **C4** IDC leader 失效 (5 分鐘服務停止) | `chaos/C4.md` | 短暫卡頓 → GCP 副本選為新 leader → 讀取切過去 | 短暫卡頓；提交切到 GCP（跨區重啟） | -30 至 -60% 於切換期間 | 10-30% 於切換期間 | 10-30 秒 | **理論 0** | 非計畫性的 F1；運維最關注；應與 F1 對比看偵測機制 |
| **C7** placement 驗證閘 fail-closed (失敗即關閉) | `chaos/C7.md`（純配置驗證，不發 workload） | 不影響（僅 metadata 讀取） | 不影響（不發寫入） | 0%（無 workload） | 0%（無客戶端流量） | N/A（不觸發切換） | N/A（無提交） | 驗證 P-B 套用後 leader 真跨區分布；若退化為單 AZ 集中 → fail；保護機制：阻止 P-B 退化成 P-A 行為而未察覺 |

**C7 驗證閘輸出細節（合成示意）** — 不同於 C1/C4 的 workload 量測，C7 產出 leader 分布計數 + 二元判定：

| 指標 | PASS (健康 P-B) [合成示意] | FAIL (退化情境) [合成示意] | 解讀 |
|---|---:|---:|---|
| 抽樣 leader 總數 | 144 | 144 | 取決於 cluster 物件數量（table / range / tablet）|
| IDC 區 leader 數 | 72 (50%) | 144 (100%) | P-B 預期 ~50/50 跨區分布 |
| GCP 區 leader 數 | 72 (50%) | 0 (0%) | FAIL 代表 leader 全縮回 IDC（退化為 P-A 行為）|
| 單 AZ 集中的 leader 數 | 0 | 144 | > 0 即 fail-closed（閘卡關）|
| 驗證閘執行時間 | ~5-15 秒 | ~5-15 秒 | 純 metadata 查詢，不掃資料 |
| 判定 | exit 0 PASS | exit 1 FAIL | 二元（per `scripts/gate-placement-p-b.sh` §159-173）|

**閱讀要點**：
- C1 是斷線（不觸發切換），**RTO 不適用**；關鍵看寫入成功率與網路恢復後同步速度
- C4 是非計畫性切換；應與 F1 計畫性對比 RTO 比值（理論非計畫性 < 2× 計畫性；超出代表偵測機制有問題）
- C7 是配置驗證閘（非故障注入），不影響 workload；產出 leader 分布計數 + PASS/FAIL 二元判定
- **三家 DB 混沌行為差異（INFERRED）**：TiDB（Percolator + PD TSO）/ CRDB（分散式交易）/ YBDB（DocDB tablet）對斷線與 leader 失效反應不同；C4 RTO 應有顯著 DB 差異

---

### D. 就近讀寫驗證 checklist（per `1_MeetingMinutes/0630.md` §9 + TiDB 官方文件）

§A 表所有 ratio 成立的**必要前提**；正式 cell run 前 / 後皆需驗。**少一項則 TL;DR §A 數字 invalid**。

| # | 驗證面 | 證據 | SSOT |
|---|---|---|---|
| D1 | Placement Policy 已套且 `Scheduling_State=SCHEDULED` | TiDB: `SHOW PLACEMENT FOR DATABASE tpcc;` + `SELECT * FROM information_schema.placement_policies;` | 0630.md §9.1 |
| D2 | TiKV / TiDB / PD 三層 `zone` label 一致 | `SELECT s.ADDRESS, s.LABEL FROM information_schema.TIKV_STORE_STATUS s;` + ansible playbook server.labels 對齊 | 0630.md §5.2 + `ansible/playbooks/tidb-vm6.yml:203-208`（已落地）|
| D3 | Leader / replica 實際位置符 Placement Policy | **三家 DONE**：`tests/common/prepare.sh` §6.6 `placement leader-distribution gate` (vm-6node-* fail-closed)；P-A 預期 IDC ≥ 70%；P-B 預期 30%-70% spread；FAIL → 中斷 prepare 不進 timed run；artifact `placement-gate-<P-A\|P-B>.json`。TiDB 用 TIKV_REGION_PEERS + JSON_CONTAINS；CRDB 用 SHOW RANGES + lease_holder_locality grep；YBDB 用 ssh + `yb-admin list_tablets` + IP prefix grep（172.24.40.{32,33,34}=IDC / 10.160.152.{11,12,13}=GCP）| 0630.md §9.2 + decisions Q11/Q12 |
| D4 | 三家就近讀「機制」已 SET（per Q13）| **DONE**：`tests/common/prepare.sh` §6.5 vm-6node-* 自動 SET — TiDB `tidb_replica_read='closest-replicas'`；CRDB `kv.closed_timestamp.follower_reads_enabled=true`；YBDB `ALTER DATABASE ... SET yb_read_from_followers=true`。artifact 三家各自寫入 `near-read-vars.txt`。**注意 caveat**：CRDB 機制啟用但實際路由需查詢層 `AS OF SYSTEM TIME follower_read_timestamp()`；YBDB ALTER DATABASE 對既有連線無效需重連 | 0630.md §8 + Q13 + [TiDB Follower Read](https://docs.pingcap.com/zh/tidb/stable/follower-read/) |
| D5 | TiDB control plane 就近 `pd_enable_follower_handle_region=ON` 已 SET | **DONE**：同 D4 一併 SET；CRDB / YBDB 無對等機制（metadata 分散結構不同；HLC 無集中 TSO） | 0630.md §6.2（TiDB 8.5+ GA）|
| D6 | 就近讀真生效（routing 證據） | **IDC + GCP pipeline hook DONE**：`tests/common/run.sh` §3.5 idempotent scp probe-iso-latency.sh 到 g-test-poc-5；per-round（vm-6node-* gated）自動 spawn local `probe-iso-latency.sh --label idc-t<N>-r<R>` + ssh g-test-poc-5 拉 `--label gcp-t<N>-r<R>`；GCP probe 目標 = GCP HAProxy (10.160.152.14)；scp 回 artifact 到 `runs/threads-<N>/round-<R>/probe-iso-latency-{idc,gcp}-*.{csv,json}`。比 p99：GCP SELECT 1 ~50ms 即 follower read 沒生效 | 0630.md §9.3 + decisions Q13 |
| D7 | 跨區流量分類量化 | **DONE (connection-count)**：`tests/common/netflow-snapshot.sh` (ss-based) per-host per-port (idc/gcp/other) established connection 計數；`tests/common/run.sh` per-round (vm-6node-* gated) 自動 spawn pre-run + post-run snapshot；artifact `runs/threads-<N>/round-<R>/netflow-{pre-run,post-run}.json`。Ports 涵蓋 4000/2379/2380/20160/26257/5433/7100/9100。**Caveat**：connection count ≠ bytes throughput；idle connection 不產 bytes。完整流量計量需 iptables counter + bytes diff，列 framework patch | 0630.md §7（10 種跨區流量）|

> ⚠️ **D4-D7 目前尚未實作於 prepare / dump-actual / collect 階段**（per 「開工前修正」§B-C，排 framework patch 階段）。本 TL;DR §A 數字在 D4-D7 落地前皆為 architectural inference，非 measurement。

→ TiDB 跨區部署最佳實踐：[TiDB 異地多活部署](https://docs.pingcap.com/zh/tidb/stable/geo-distributed-deployment-topology/)

CRDB / YBDB 等價就近讀寫設定 **PLANNED**（per `decisions-2026-06-08.md` Q13 拍板 2026-06-30；完整 6 維對照表見 Q13）：
- **CRDB**: `--locality=region/zone` + `lease_preferences=[[+region=idc]]` + `kv.closed_timestamp.follower_reads_enabled=true` → 查詢 `AS OF SYSTEM TIME follower_read_timestamp()`
- **YBDB**: tserver flag `--placement_*` + tablespace placement_blocks + `SET yb_read_from_followers=true; SET yb_follower_read_staleness_ms=30000;`
- **同源 caveat**：三家「IDC Request 絕不離開 IDC」單一強一致 cluster 都做不到（per Q13 §同源 caveat）

---

### Bottom line（必讀 3 條）

1. **「3 節點→6 節點資源增益直接被抵消」是過簡的口號**；正確分解：跨區提交確認額外開銷 + 讀取網路往返 + (A-A 雙活才有的) 跨區分散式交易成本。**workload profile 與 placement 決定成本暴露面**，非單純規模換延遲
2. **故障切換 / 混沌情境的 RTO / RPO 目前皆理論值**（per codex F8）；正式量化需 **Go 語言實作的探針工具 (probe driver)** + 單調時鐘 + 提交 ACK 機制 — bash + 各 DB CLI 100ms tick 精度不足
3. **P-A vs P-B 取捨**：P-A 守 IDC（WAN 斷線抗性 + 常態效能優），但 IDC 站點失效時失效；P-B 跨區分布（抗故障上限高，常態成本重）。**SLA 取向決定選誰**：可容忍人工介入 / 短時 IDC 失效 → P-A；不可人工介入 / IDC 失效必須自動 → P-B

---

## 1. Executive decision

**這份 PoC 最終要回答的決策（3 層）**：

| Decision | 選項 | 目前能不能下？ |
|---|---|---|
| D1 跨區 PoC 是否進入正式採用？ | 採 / 不採 | **NO**（核心 W=128 baseline 未跑 + acceptance criteria 未訂）|
| D2 採哪個 placement？ | P-A (majority IDC) / P-B (spread) / 不採跨區 | **NO**（P-B 從未跑過；無對照組）|
| D3 採哪個 DB + 對應 workload profile？ | TiDB / CRDB / YBDB × A-S / A-A-RO / A-A | **NO**（profile 業務 owner 未指派；三家 W=128 受控比較未跑）|

**目前能說的（高 confidence）**：跨區 framework 已可在三家 DB × 6 真實節點跑通（per `results/x-cross/determinism/run{1,2}/` W=4 same-cluster 重現性 CV ≤ 5%；`pipeline-log.md` §2.1 [MEASURED]）。

**最大三個 blocker**（per `x-cross-report-demo-audit.md` §4）：
1. W=128 正式 baseline 三家齊全 [BLOCKED]
2. Acceptance criteria（業務 threshold）未訂 [BLOCKED]
3. P-B placement + IDC-only 6-node paired control 不存在 [BLOCKED]

---

## 2. Decision questions and gates

| Decision | Owner | Acceptance threshold | Evidence required | Current status |
|---|---|---|---|---|
| D1 跨區是否採用 | 業務 + 架構 | tpmC ≥ TBD；NEW_ORDER p99 ≤ TBD；error rate ≤ TBD；WAN cost ≤ TBD | W=128 × 3 DB × P-A artifact + IDC-only paired control | **BLOCKED** — threshold + control missing |
| D2 placement P-A vs P-B | 架構 + DBA | P-B tpmC drop vs P-A ≤ TBD%；P-B p99 ≤ TBD ms；split-brain 防護 PASS | W=128 × 3 DB × P-B artifact + `gate-placement-p-b.sh` exit 0 | **BLOCKED** — P-B 未跑 |
| D3a A-S 採用 | 業務 owner = TBD | 平時 tpmC ≥ TBD；failover RTO ≤ TBD；RPO = 0 | A-S artifact + F1 probe driver | **BLOCKED** — F1 probe driver 未實裝 |
| D3b A-A-RO 採用 | 業務 owner = TBD | GCP read 一致性 mode + read tpm ≥ TBD；replication lag p99 ≤ TBD | A-A-RO artifact + follower-read mode 設定驗證 | **BLOCKED** — owner missing |
| D3c A-A 採用 | 業務 owner = TBD | retry/abort rate ≤ TBD；兩側合計 tpmC ≥ TBD | A-A artifact + `run-vm6-aa.sh` dual-client driver + cross-region key conflict 量測 | **BLOCKED** — owner missing; A-A 是否真的進 production 未拍板 |
| D-Resilience F1 / C1 / C4 / C7 | 架構 + DBA | RTO / RPO / write_failure_rate per `RTO-RPO-methodology` | probe driver + wall-clock wrapper + DBA review label | **BLOCKED** — `chaos/README.md` 開閘流程 4 項 + chaos C1/C4 spec ↔ script reconcile |

> Steady-state（D1–D3）與 Resilience（D-Resilience）為**獨立 decision track**；前者未過不阻擋後者方法論，但兩者目前都 BLOCKED。

---

## 3. Scope and candidate scenarios

### 3.1 候選 placement × profile（per `manifest.yaml` placements/profiles）

| Placement | Profile | 業務 use case | Owner | 是否進正式矩陣 |
|---|---|---|---|---|
| P-A (majority IDC) | A-S | IDC primary writer + GCP DR standby | **TBD** | 候選（待 owner）|
| P-A | A-A-RO | IDC primary writer + GCP read offload | **TBD** | 候選（待 owner）|
| P-A | A-A | 兩端皆寫 max contention（探索性，per `decisions-2026-06-08.md` Q6）| **TBD** | 不建議（無 production case；per review-prompt §3.5 預設刪除）|
| P-B (spread) | A-S | 退化形態（leader 散區，per `topology/P-B.md`）| **TBD** | 候選（量化 cost）|
| P-B | A-A-RO | spread leader + GCP read | **TBD** | 候選（待 owner）|
| P-B | A-A | spread leader + 兩端寫 worst case | **TBD** | 探索性 only |

### 3.2 候選 DB（per `manifest.yaml`，3 家 serial）

TiDB / CRDB / YBDB 三家全在矩陣內。三家絕對 serial（per `decisions-2026-06-08.md` Q9：先 P-A 再 P-B；DB 順序 TiDB → CRDB → YBDB；reasoning：client / WAN / GCP API quota 互擾風險，由 decision record 而非 memory 取證）。

---

## 4. Current evidence inventory

| Evidence | Status | Source | Confidence |
|---|---|---|---|
| 跨區 framework 已跑通（3 DB × 6 node × W=4 × same-cluster, 5 round）| **MEASURED** | `results/x-cross/determinism/run1-20260622T131459+0800/{tidb,crdb}-vm-6node-P-A-rc-run1-*/summary.json` + `run2-.../ybdb-...-run2-*/summary.json` | high |
| Same-cluster determinism CV ≤ 5%（W=4）| **MEASURED** | `pipeline-log.md` §2.1: TiDB 1.5% / CRDB 4.5% / YBDB 1.8% (R3-R5) | high |
| TiDB / CRDB / YBDB 真 6-node smoke 跑通 | **MEASURED** | `pipeline-log.md` §2.2 (2026-06-19) | high |
| W=128 P-A baseline | **BLOCKED** | `manifest.yaml` warehouses:128 為 spec；無 W=128 artifact 在 `results/x-cross/` | — |
| P-B placement artifact | **BLOCKED** | `results/x-cross/` 全部 `topology=vm-6node-P-A`；P-B SQL 已存在但未 apply | — |
| F1 / C1 / C4 / C7 runtime | **BLOCKED** | `chaos/README.md` 標 planner-only；4 項開閘條件未達；`chaos-c1/c4-*-plan.sh` 無 `--execute` 旗標 | — |
| IDC-only 6-node paired control | **BLOCKED** | 不存在；S-BASE 為 vm-3node，硬體 / topology 不同 | — |
| Independent N=5 suite | **BLOCKED** | `manifest.yaml requires_n:1`；`ROUNDS=5` 為同 suite 5 round（per `summary-from-stdout.py`），非 5 independent suite | — |
| probe driver 100ms tick | **BLOCKED** | `RTO-RPO-methodology.md` §3.2 + §9 step 2；未實裝 | — |

> **DEV-1x1 不適用 X-CROSS**：`results/x-cross/determinism/` 為 true 6-node W=4 same-cluster determinism（per `pipeline-log.md` §1 [MEASURED]），不是 DEV-1x1 framework selfcheck（DEV-1x1 為 S-BASE / S-K8S phase 概念）。

---

## 5. Minimal experiment matrix

> 規則：每 cell 必須回答「哪個結果會改變哪個決策」。Cell 若 owner 未指派或結果不影響任何 D，刪除而非保留為「完整性」(per review-prompt §4.5)。

| # | Cell | Hypothesis | Primary endpoint | Control | 改變的決策 | Status |
|---:|---|---|---|---|---|---|
| C-01 | P-A × A-S × W=128 × 3 DB | 跨區 majority IDC retain ≥ TBD% vs IDC-only | tpmC mean (R1-R5) | IDC-only 6-node W=128 A-S | D1, D3a | **PLANNED** |
| C-02 | P-A × A-A-RO × W=128 × 3 DB | GCP follower read 不顯著影響 IDC write tpmC | IDC-side tpmC + GCP read tpm | IDC-only W=128 (read-only mix) | D3b | **PLANNED**（owner 確認後）|
| C-03 | P-B × A-S × W=128 × 3 DB | P-B drop vs P-A ≤ TBD% | tpmC drop% vs C-01 | C-01 | D2 | **PLANNED** |
| C-04 | P-B × A-A-RO × W=128 × 3 DB | spread leader 對 read offload 收益 / 成本 | GCP read tpm + IDC commit p99 | C-02 + C-03 | D2, D3b | **PLANNED**（owner 確認後）|
| C-05 | A-A 全 cell | 兩端寫 max contention | retry/abort rate + 兩側合計 tpmC | — | D3c | **不進矩陣**（owner 未指派；per review-prompt §3.5 預設刪除）|
| C-06 | F1 P-A planned failover | RTO ≤ TBD；RPO = 0 | rto_sec + rpo_lost_tx_count | — | D-Resilience | **BLOCKED**（probe driver + DBA approve）|
| C-07 | C1 / C4 chaos | partition / leader die 行為符 spec | tpmC drop curve + healing curve；C4 加 rto_sec | — | D-Resilience | **BLOCKED**（spec ↔ script reconcile + DBA approve）|
| C-08 | C7 placement gate fail-closed | write_failure_rate = 100% + no spurious leader in GCP | binary gate verdict | — | D-Resilience | **BLOCKED**（C7 planner script 確認 + spec match）|

---

## 6. Measurement contract

### 6.1 Canonical schema（per `PHASES.md` §5 + `tests/common/summary-from-stdout.py` v1）

```json
{
  "schema_version": 1,
  "phase": "phase-crossregion",
  "result_scope": "X-CROSS",
  "baseline_family": "crossregion",
  "manifest_sha256": "<sha256 of phase-crossregion/manifest.yaml>",
  "warehouses": 128,
  "rounds_per_thread_group": 5,
  "skip_rounds": 0,
  "thread_results": {
    "<N>": {
      "tpmC_mean": "<R1-R5 mean>",
      "tpmC_per_round": ["r1..r5"],
      "tpmC_range_mean_pct": "<(max-min)/mean*100>",
      "NEW_ORDER": {"p50_mean_ms": "...", "p95_mean_ms": "...", "p99_mean_ms": "...", "total_count": "...", "error_count": "...", "error_rate_pct": "..."},
      "all_txn":   {"total_count": "...", "error_count": "...", "error_rate_pct": "..."}
    }
  }
}
```

### 6.2 Primary estimator

- **Primary**: `tpmC_mean = R1-R5 mean`（per `PHASES.md` §5 + code 落地；與 S-BASE / S-K8S 一致）
- **Secondary / sensitivity**: R2-R5 median + CV（觀察 R1 cold reset 影響）；不取代 primary
- **Outlier policy**: 預設不自動排除；保留所有 raw round；異常需事前規則 + 含 / 不含 sensitivity analysis（per review-prompt §3.9）

### 6.3 Experiment unit（區分四層，per review-prompt §4.8）

| 單位 | 定義 | 數量 |
|---|---|---|
| within-suite round | 同 suite 內的 5 個 timed window（每個 5 min） | `ROUNDS=5` per cell |
| independent suite | 同 cell、不同 ts、各自獨立 artifact root | 目前 = 1（exploratory；`manifest.yaml requires_n:1`）|
| same-cluster repeat | 同 deploy 內多次跑 suite（不 redeploy） | determinism evidence 為此（W=4）|
| rebuild repeat | 不同 VM rebuild 之間 | **強制**於三家 DB cell 之間（per `decisions-2026-06-08.md` Q11）；不接受 service-level cleanup 替代 |

→ `ROUNDS=5` ≠ independent N=5。Demo / 後續報告若聲稱 independent N=5，**必須**外層 repeat orchestration + 各自獨立 artifact。

→ **三家 DB cell 強制 VM rebuild**（per Q11 拍板 2026-06-29）：
- 規則：TiDB → PASS → CRDB → PASS → YBDB；每家 cell 之間跑 `make phase1-destroy phase1-apply phase1-wait-via-31`
- 不接受替代：service-level cleanup（systemctl stop + DROP DATABASE + rm -rf）**不可**取代完整 VM rebuild
- Trade-off：降低 cross-DB residue bias ↔ 增加 between-suite environment variance（**非科學必然**，是 controlled bias trade）
- 不適用：同家 DB 內 round / thread sweep 不需 rebuild
- Audit hook（待實作）：`summary.json` 新增 `prev_suite_done` + `vm_rebuild_ts`；wrapper `gate` 驗 `.31` 對 cluster SSH host key 殘留為 fail-closed 條件

### 6.4 Correctness gate（preceeds 效能採信）

| Gate | Spec / verifier | Status |
|---|---|---|
| Markers 依序 | 8 markers per cell（per existing pipeline contract） | spec [PLANNED]; runtime [BLOCKED] |
| `summary.json` schema 完整 | `expected_rounds / observed_rounds / complete / incomplete_reason / thread_results / manifest_sha256` | spec [MEASURED]（schema 已落地）；W=128 runtime [BLOCKED] |
| Controller = .31 audit | marker JSON / summary `controller_host = 172.24.40.31`；無 MAC hostname | spec [PLANNED]，由 `ansible/inventory/crossregion-via31.ini` 強制 |
| Data integrity TPC-C C1-C5 | post-run consistency check | spec [PLANNED] |
| Workload mix vs spec | NewOrder/Payment/... 比例（A-S standard；A-A-RO GCP mix `0:0:50:0:50` per `run-vm6-aa.sh` line 96-98）| spec [MEASURED]；runtime [BLOCKED] |
| Placement actual = expected | P-A：leaders 全 IDC；P-B：`gate-placement-p-b.sh` exit 0（idc_count ≥ 1 AND gcp_count ≥ 1）| script [MEASURED]；runtime [BLOCKED] |
| WAN baseline RTT | `wan-probe.sh` business + off-peak | script [MEASURED]；runtime [BLOCKED] |
| chrony cross-region drift < 100ms | `gate-chrony-cross-region.sh` | script [MEASURED]；runtime [BLOCKED] |
| Client / system saturation evidence | CPU / disk lat / IOPS / network / DB queue / lock / retry / client CPU+conn saturation | **MISSING** — review-prompt §4.11 要求；目前無 collect spec |

### 6.5 Artifact path

- `results/x-cross/determinism/` — 本 demo 唯一 MEASURED 來源（W=4）
- `results/x-cross/{db}-vm-6node-{P-A|P-B}-rc-{ts}/` — W=128 正式 artifact root（per `manifest.yaml artifact_prefix: results/x-cross/`，遵 PHASES.md §0 命名）

---

## 7. Results

> 只列真實 artifact。未跑欄位寫 `TBD (not measured)`。

### 7.1 W=4 same-cluster determinism (per `pipeline-log.md` §2.1 [MEASURED])

| DB | Suite | tpmC mean | R1-R5 raw | CV (R1-R5) | Note |
|---|---|---:|---|---:|---|
| TiDB | `determinism/run1-.../tidb-vm-6node-P-A-rc-run1-...` | 9,557.9 | 9525.5 / 9553.2 / 9786.9 / 9393.2 / 9530.8 | 1.5% | summary.json schema_v1 [MEASURED] |
| CRDB | `determinism/run1-.../crdb-vm-6node-P-A-rc-run1-...` | 7,912.1 | 8409.5 / 8055.3 / 7902.5 / 7720.9 / 7472.3 | 4.5% | [MEASURED] |
| YBDB | `determinism/run2-.../ybdb-vm-6node-P-A-rc-run2-...` | 6,296.6 (R3-R5) | 102.0 / 226.9 / 6424.2 / 6259.3 / 6206.2 | 1.8% (R3-R5) | R1/R2 暖機異常；`--skip-rounds 2` [MEASURED] |

**判讀限制**（per `pipeline-log.md` §4）：
- W=4 ≠ W=128 contention；本表**不可**作跨家 W=128 排序
- 三家比較需同 W、同 warmup、同 round；目前 W / warmup 對齊但 N=1 suite
- IDC-only paired control 不存在，**不可**宣稱 retain% vs IDC-only

### 7.2 W=128 P-A baseline

| DB | tpmC mean | NEW_ORDER p99 | error rate | Note |
|---|---|---|---|---|
| TiDB | TBD (not measured) | TBD | TBD | BLOCKED — `phase-crossregion-w128-suite` 未跑 |
| CRDB | TBD (not measured) | TBD | TBD | 同上 |
| YBDB | TBD (not measured) | TBD | TBD | 同上 |

### 7.3 W=128 P-B baseline

| DB | tpmC mean | drop vs P-A | Note |
|---|---|---|---|
| TiDB | TBD (not measured) | TBD | BLOCKED — P-B 未跑 |
| CRDB | TBD (not measured) | TBD | 同上 |
| YBDB | TBD (not measured) | TBD | 同上 |

### 7.4 Resilience（F1 / C1 / C4 / C7）

| Scenario | DB | RTO | RPO | Note |
|---|---|---|---|---|
| F1 P-A | TiDB / CRDB / YBDB | TBD (not measured) | TBD | BLOCKED — probe driver 未實裝 |
| C1 (partition) | 同上 | n/a (not RTO/RPO event per `RTO-RPO-methodology` §5) | 同上 | BLOCKED — spec ↔ planner script reconcile |
| C4 (leader die) | 同上 | TBD | TBD | 同上 |
| C7 (gate fail-closed) | 同上 | n/a | n/a | BLOCKED — runtime 未跑 |

> RPO=0 為 raft majority commit + RF=3 + RC 的**理論預期**（per `RTO-RPO-methodology.md` §1.2 / §4.1）[INFERRED]，不是觀測結果。

---

## 8. Risks, cost, operability

| 維度 | 主要問題 | Status | Reference |
|---|---|---|---|
| **可營運性** | deploy / upgrade / backup / restore / 觀測 / 支援 / license | **MISSING** — must-pass gate 待業務拍板 | review-prompt §4.12 |
| **成本** | steady-state（GCP VM + inter-region egress + storage）vs failover cost（含 RTO 期 unavailable cost）| **MISSING** — 待 acceptance criteria 訂後估 | review-prompt §4.13 |
| **安全 / 治理** | data residency（IDC ↔ asia-east1）/ 加密 / IAM / 稽核 / 合規 | **MISSING** — 待業務 owner 確認 | review-prompt §4.14 |
| **WAN** | RTT business-hour vs off-peak；MTU; loss | spec 已寫 [PLANNED]（`scripts/wan-probe.sh`）；W=128 runtime [BLOCKED] | `phase-crossregion/wan/baseline-measurement.md` |
| **Placement drift** | scheduler / balancer freeze 三家 | spec 已寫 [PLANNED]（`phase-crossregion/freeze/`）；W=128 runtime [BLOCKED] | `NEXT-STEPS.md` §2.1 hard gate |
| **Chrony** | IDC ↔ GCP drift < 100ms（per `decisions-2026-06-08.md` Q10）| script 落地 [MEASURED]；preflight artifact 存在 | `scripts/gate-chrony-cross-region.sh` |

---

## 9. Blockers and next actions

| # | Blocker | Owner | Due date | 解除證據 | 阻擋的決策 |
|---:|---|---|---|---|---|
| B1 | W=128 baseline 三家齊 | TBD | TBD | `results/x-cross/{db}-vm-6node-P-A-rc-{ts}/summary.json` × 3，warehouses=128，R1-R5 完整 | D1, D3a |
| B2 | P-B placement W=128 跑 + gate PASS | TBD | TBD | `gate-placement-p-b.sh` exit 0 + P-B summary.json × 3 | D2 |
| B3 | IDC-only 6-node paired control | TBD | TBD | 同硬體、同 W、同 profile 的對照 summary.json | D1, D2 |
| B4 | Acceptance criteria（業務 threshold） | 業務 / 架構 | TBD | `decisions-*.md` 拍板段 | All D |
| B5 | A-S / A-A-RO / A-A profile 業務 owner 指派 | 業務 | TBD | decisions record 含 owner | D3 全段 |
| B6 | chaos C1 / C4 spec ↔ planner script 故障模型 reconcile | DBA + reviewer | TBD | spec or script 修一邊；header 自註消除 | D-Resilience |
| B7 | probe driver 100ms tick + wall-clock wrapper | DBA + reviewer | TBD | PR + DBA approve label；`RTO-RPO-methodology` §9 step 2/3 滿足 | D-Resilience |
| B8 | 三家 admin CLI 路徑 confirm（leader stepdown / drain / list_tablets per cluster 版本） | DBA | TBD | per `F1.md` §47-52 confirm 紀錄 | D-Resilience |
| B9 | capacity mapping（W=128 ↔ production peak）| 業務 | TBD | production demand sample + W 對應 | D1 |
| B10 | P-B `arbiter` 語意對齊三家實作 | 架構 | TBD | `topology/P-B.md` 改用各 DB 真實 voter / leaseholder / tablespace 語意 | D2 |

---

## 10. Appendix

### 10.1 Topology

```
IDC vlan241                            asia-east1
┌──────────────────────────┐           ┌──────────────────────────┐
│ .31 idc-client / controller          │ g-test-poc-5 gcp-client (A-A only)
│ .47.20 idc-haproxy                   │ g-test-poc-4 gcp-haproxy
│ .32 / .33 / .34 idc-dbhost-1/2/3     │ .11 / .12 / .13 gcp-dbhost-1/2/3
└──────────────────────────┘           └──────────────────────────┘
        ▲                                       ▲
        │ MySQL :4000 / PostgreSQL :26257 :5433 │
        └────── WAN raft replication ───────────┘
```

**Endpoint port / protocol**（per `phase-crossregion/Makefile` line 60-65 + `gate-placement-p-b.sh` line 50-52）：

| DB | Client protocol | HAProxy port | Driver port |
|---|---|---:|---:|
| TiDB | MySQL | `:4000` | `:4000` |
| CockroachDB | PostgreSQL | (HAProxy not always used; direct) | `:26257` |
| YugabyteDB | YSQL (PostgreSQL) | (HAProxy not always used; direct) | `:5433` |

> Demo 不畫三家 HAProxy 統一 `:4000`；不用「jdbc/pg」統稱。

### 10.2 SSOT references

| SSOT | 用途 |
|---|---|
| `phase-crossregion/manifest.yaml` | result_scope / baseline_family / threads_list / warehouses / isolation / placements / profiles / artifact_prefix |
| `phase-crossregion/Makefile` | `phase-crossregion-w128-suite` target（exists; chain 需 fix 改走 `phase1-wait-via-31`）|
| `phase-crossregion/NEXT-STEPS.md` | 已落地 / 待 operator 觸發 / 已知阻擋 |
| `phase-crossregion/decisions-2026-06-08.md` | Q1–Q10 拍板；Q6 A-A-RO mix；Q9 serial per-DB + cell sequence；Q10 chrony |
| `phase-crossregion/topology/{P-A,P-B}.md` | placement 結構 + 落地指令 + 驗證 gate |
| `phase-crossregion/workload-profiles/{A-S,A-A-RO,A-A}.md` | client 配置 + 預期觀察 + 搭配 placement |
| `phase-crossregion/chaos/{README,C1,C4,C7}.md` | scenario spec |
| `phase-crossregion/scripts/chaos/chaos-c{1,4}-*-plan.sh` | planner-only; 故障模型對換見 audit doc §3 衝突 #6 |
| `phase-crossregion/scripts/gate-placement-p-b.sh` | P-B leader spread gate（read-only admin query）|
| `phase-crossregion/scripts/run-vm6-aa.sh` | A-A / A-A-RO dual-client orchestration；A-A-RO GCP mix = `0:0:50:0:50` |
| `phase-crossregion/failover/{F1,RTO-RPO-methodology}.md` | F1 planner spec + RTO/RPO 量測方法論 |
| `phase-crossregion/wan/baseline-measurement.md` | WAN baseline gate spec |
| `phase-crossregion/freeze/` | 三家 scheduler / balancer freeze |
| `results/PHASES.md` | scope / baseline_family / canonical schema（§5 R1-R5 mean）|
| `results/PoC-DESIGN.md` | §8.3 5-round mean canonical（已對齊 code）|
| `results/x-cross/pipeline-log.md` | X-CROSS pipeline / determinism evidence |
| `tests/common/summary-from-stdout.py` | summary.json v1 producer；CLI `--warehouses N` / `--skip-rounds K` |
| `ansible/inventory/crossregion-via31.ini` | .31 controller；IDC↔GCP FW 已開（2026-06-18）；三家 protocol/port |
| `1_MeetingMinutes/0630.md` | TiDB 資源隔離 + 跨區就近讀寫官方機制與限制；§5 Placement Policy ≠ Request routing / §6 PD/TSO control plane / §8 建議 SQL / §9 驗證程序 / §10 最終結論 |
| [TiDB Geo-Distributed Deployment](https://docs.pingcap.com/zh/tidb/stable/geo-distributed-deployment-topology/) | 跨區部署官方最佳實踐 |
| [TiDB Follower Read](https://docs.pingcap.com/zh/tidb/stable/follower-read/) | `tidb_replica_read='closest-replicas'` 設定與限制 |

### 10.3 變更歷史

| 日期 | 內容 |
|---|---|
| 2026-06-29 | Reverse review 重寫：移除 fake 數字；decision-first 結構；evidence-state tag；SSOT 衝突 #2 / #4 / #5 已修，#1 / #3 / #6–#10 列 audit doc unresolved blocker（per `x-cross-report-demo-audit.md`）|
| 2026-06-30 | 加 TL;DR（A 跨專線 6-node vs 3-node / B Failover R/W / C Chaos R/W），含 synthetic illustrative 數字（per user 授權；標 [SYNTHETIC] tag）。正文 §1 起仍不含 fake。Header disclaimer 同步調整列出 SYNTHETIC tag 用法 |
| 2026-06-30 | TL;DR A 表 asymmetric 修正：原 TiDB P-A × 3 + P-B × 1 / CRDB 缺 A-A-RO / YBDB 只有 A-S — 為 demo 疏失（架構上三家都能跑全部 6 cell）。改成完整 3 × 3 × 2 = 9 row 矩陣，每行同時列 P-A 與 P-B tpmC 與 ratio |
| 2026-06-30 | TL;DR A/B/C 三段減少技術英文：保留 P-A/P-B/A-S/A-A-RO/A-A 等 project tag，其餘加中文括號註釋（F1 planned → F1 計畫性切換 / cutover → 切換期間 / quorum → 法定人數 / split-brain → 雙主腦 等）；C7 補 leader 分布計數細節表，將原 N/A 改為合成示意（IDC 72/72 vs 144/0 退化情境）|
| 2026-06-30 | 對齊 `1_MeetingMinutes/0630.md` 就近讀寫議題：TL;DR §A 解讀 3/4 加前提（A-A-RO 需 `closest-replicas`；A-A 需 geo-partition），加 §7 control plane cost 永遠跨區 + §8 「就近讀寫嚴格定義」per 0630.md §10；新增 §D「就近讀寫驗證 checklist」7 項（D1-D7）+ CRDB/YBDB 等價設定推導；§10.2 SSOT 補 0630.md + TiDB 官方 geo-deployment / follower-read；audit §4 加 unresolved blocker #11（routing evidence + control plane cost 量測未實作）|
| 2026-06-30 | TL;DR §D CRDB/YBDB 等價設定從 INFERRED 升為 PLANNED，引 `decisions-2026-06-08.md` Q13（6 維對照表：region/zone label / topology / 就近讀 / control plane 就近 / TSO / Placement Policy）+ 同源 caveat（三家「IDC Request 絕不離開 IDC」單一強一致 cluster 皆做不到）|
| 2026-06-30 | TiDB prepare §6.5 加 `tidb_replica_read='closest-replicas'` + `pd_enable_follower_handle_region=ON` 自動 SET（vm-6node-* topology only）+ dump `near-read-vars.txt`；TL;DR §D 表 D4/D5 標 PARTIAL；audit blocker #11 標 TiDB 部分落地、CRDB/YBDB 仍缺 |
| 2026-06-30 | prepare §6.5 補 CRDB / YBDB 等價 SET：CRDB `SET CLUSTER SETTING kv.closed_timestamp.follower_reads_enabled=true`；YBDB `ALTER DATABASE ... SET yb_read_from_followers=true; SET yb_follower_read_staleness_ms=30000`；各 dump `near-read-vars.txt`；TL;DR §D D4/D5 升為 DONE（caveat 加註：CRDB 需查詢層 AS OF SYSTEM TIME / YBDB ALTER DATABASE 需重連才生效）；audit blocker #11 三家 prepare 機制 SET 落地，仍缺 dump-actual leader 分布 / collect NetFlow / summary.json routing evidence |
| 2026-06-30 | prepare §6.6 新增 **placement leader-distribution gate** (TiDB；fail-closed) — 從 TOPO 解 P-A/P-B，JSON_CONTAINS 查 TIKV_STORE_STATUS LABEL；P-A 期 IDC ≥ 70%、P-B 期 30%-70% spread；不符即 `exit 1` 中斷 prepare 不進 timed run；artifact `placement-gate-<placement>.json`（verdict / reason / counts）。CRDB/YBDB Q13 PLANNED 同章節 TODO。TL;DR §D D3 升為 TiDB DONE；audit blocker #11 紀錄已落地項目擴充 |
| 2026-06-30 | prepare §6.6 補 **CRDB placement gate**：用 `SHOW RANGES FROM TABLE warehouse/district/customer WITH DETAILS` + grep `region=idc/gcp` lease_holder_locality；同 P-A 70% / P-B 30-70% 判定；FAIL `exit 1` 中斷 prepare。YBDB DEFERRED（需 SSH + yb-admin，留 framework patch 階段委派到 `gate-placement-*.sh`）。TL;DR §D D3 升為 TiDB + CRDB DONE / YBDB DEFERRED |
| 2026-06-30 | `tests/common/summary-from-stdout.py` 加 **`region_routing_evidence`** 頂層欄：自動讀 `<suite>/prepare/near-read-vars.txt` 與 `placement-gate-*.json` 寫入 summary.json；包含 `near_read_setup.vars_snapshot` + `placement_gate.{verdict,placement,idc_leader_count,gcp_leader_count,total_leader_samples,reason}`。Future audit 從 cell summary.json 一檔即可驗 closest-replicas + placement gate 是否生效；不再需逐檔翻 prepare/。 |
| 2026-06-30 | 新增 `tests/common/probe-iso-latency.sh` standalone tool：三家 DB（TiDB/CRDB/YBDB）跑 SELECT 1 + UPDATE 取 p50/p95/p99 latency；CLI flags `--db / --db-host / --port / --user / --dbname / --duration-sec / --out-dir / --label`；輸出 csv (raw per-iteration) + json (aggregate)。設計用途：同次 timed run 期間從 IDC (.31) 與 GCP (g-test-poc-5) 各 call 一次（label=idc/gcp），比 p99 → 證 closest-replicas 是否生效（GCP SELECT 1 ~50ms 即 follower read 沒生效）。Pipeline hook 待 framework patch；CRDB caveat 明列（需 AS OF SYSTEM TIME 才走 follower）。TL;DR §D D6 升為 TOOL READY |
| 2026-06-30 | `tests/tidb/placement-p-a.sql` 加 `SCHEDULE='MAJORITY_IN_PRIMARY'` 對齊 0630.md §5.1 + TiDB 官方文件：強化 P-A 語意，從「leader 偏 IDC」升為「leader + 多數 replica 都偏 IDC」；對齊 §6.6 placement gate IDC ≥ 70% 門檻。Fallback 註解：若 TiDB 版本不支援此 syntax，移除該行；leader 仍偏 IDC 但 follower 可能 spread 略多 → gate 門檻可能略低於預期需手動觀察 |
| 2026-06-30 | `tests/common/run.sh` per-round 加 **probe-iso-latency.sh IDC-side sidecar**（vm-6node-* gated, fail-quiet）：自動 spawn local probe `--label idc-t<N>-r<R> --duration-sec 60`；MON_PIDS 同 wait；artifact 寫進 `runs/threads-<N>/round-<R>/probe-iso-latency-idc-*.{csv,json}`。GCP-side hook TODO（需 deploy probe + DB client 到 g-test-poc-5；ssh 拉 label=gcp 同次取證）。TL;DR §D D6 升為 IDC pipeline hook DONE |
| 2026-06-30 | `tests/common/run.sh` §3.5 加 idempotent `scp probe-iso-latency.sh root@10.160.152.15:/tmp/poc/tests/common/`；per-round 加 **GCP-side probe**（ssh g-test-poc-5 → 本地跑 probe → scp 回 artifact）；目標 = GCP HAProxy (10.160.152.14)；env override `GCP_PROBE_HOST` / `GCP_PROBE_DB_HOST`；fail-quiet 不阻擋主 run。三家 DB client 已在 g-test-poc-5（go-tpc client host）。IDC vs GCP 兩 label 同次取證齊備，可比 p99 證 closest-replicas 真生效。TL;DR §D D6 升為 IDC + GCP pipeline hook DONE |
| 2026-06-30 | `tests/common/prepare.sh` §6.6 **補 YBDB placement gate** 完成三家齊全：ssh root@$DB_HOST → `yb-admin --master_addresses=$YB_MASTER_ADDR list_tablets ysql.<db> <table>` → grep leader IP prefix (172.24.40.{32,33,34}=IDC / 10.160.152.{11,12,13}=GCP)；同 P-A 70% / P-B 30-70% 判定 fail-closed。YB_MASTER_ADDR env fallback 預設 IDC 三節點:7100。TL;DR §D D3 升為三家 DONE；audit blocker #11 YBDB gate 落地 |
| 2026-06-30 | 新增 `tests/common/netflow-snapshot.sh` 跨區流量 connection-count 工具 + `tests/common/run.sh` per-round pre-run / post-run hook（vm-6node-* gated, fail-quiet）：ssh 各 host 跑 `ss -tn state established`，按 (port, remote_region: idc/gcp/other) 計數；涵蓋 ports 4000/2379/2380/20160/26257/5433/7100/9100；artifact `runs/threads-<N>/round-<R>/netflow-{pre-run,post-run}.json`。Caveat: connection count ≠ bytes（idle 連線不算流量）；完整 bytes 量測需 iptables counter，列 framework patch。TL;DR §D D7 升為 DONE（connection-count level）|

| 2026-06-30 | **codex F2 + F6 落地**：(F2) `phase-crossregion/Makefile` `phase-crossregion-all` chain DB 順序 TiDB→YBDB→CRDB 修正為 TiDB→CRDB→YBDB（per Q9/Q11）；cleanup deps wiring 同步（新增 `phase-cleanup-crdb` target）。(F6) S-BASE vm-3node「contextual reference 禁用 retain%/WAN penalty/Δ」**三點落地**：demo §A 既有 + audit §4 #3 強化 + audit §6 #3 revised 強化 + decisions Q11 新增「跨 phase 對照禁制」段（per codex F6）|

---

**END — OFFICIAL EXPLORATORY / NOT-AN-ADOPTION-DECISION; no fake numbers; promotion checklist in `x-cross-report-demo-audit.md` §6.**
