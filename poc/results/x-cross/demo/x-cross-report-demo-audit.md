# X-CROSS Demo Audit — 2026-06-29 reverse review

> Audit per `results/x-cross/demo/x-cross-report-demo-review-prompt.md` §6.1。
> Output buckets: Remove / Add / Correct / Block。靜態審查 only；不執行 benchmark / chaos / failover。
> Status: NOT-FOR-DECISION; demo report 重寫後續仍維持 framework-only。

---

## §1 Remove（從主報告刪除）

| # | Item | 原因 | 證據 |
|---:|---|---|---|
| 1 | §5 fake tpmC / p99 / error rate / CV / commit latency / WAN RTT 表（P-A × A-S × W=128 三家對比）| review-prompt §3.1：fake 數字即使有警語仍會造成決策錨定 | demo §5.1–§5.5 全段，含 ASCII bar 與 trend curve |
| 2 | §5.4 P-A vs P-B fake drop% 表 | 同上；P-B 從未跑過 | manifest `requires_n:1`；`results/x-cross/` 無 P-B artifact |
| 3 | §6 fake bottleneck / 勝負敘事（TiKV lock-wait、CRDB latch、YBDB RPC pool）| review-prompt §3.2：correlation ≠ root cause；無 saturation evidence | §6.1–§6.5 全段 |
| 4 | §11 / §12 fake F1 / C1 / C4 RTO + 95% CI 表 | review-prompt §3.5：chaos / F1 為 BLOCKED；plan 存在 ≠ runtime PASS；CI 必由 independent samples 產 | §11.2–§11.6、§12.2 |
| 5 | §13 16 維 rigor 章 fake M 數據（histogram, TOST verdict, replication lag, cost 等）| review-prompt §3.4：方法論用連結，不重抄；fake M 與 §5 同性質 | demo §13.1–§13.16 |
| 6 | §13.1 outlier policy「±3σ from median，最多剔除一個 suite」 | review-prompt §3.9：不採此規則；預設不自動排除 | demo §13.1 M 表 outlier 欄 |
| 7 | §13.2 p99.9 / p99.99 fake 數字 | review-prompt §3.8：未證明每 cell sample count 足以穩定估計 | demo §13.2 M 表 |
| 8 | §14 「19/19 PASS」與 §3 19 / 19 plan-conformance 計數 | review-prompt §3.6：plan 對齊 ≠ runtime PASS | demo §3 / §14 |
| 9 | §15 anti-pattern 16 條（搬到 appendix 或 SSOT link）| review-prompt §3.4：方法論不重抄主報告 | demo §15 |
| 10 | §0 表格「永遠 `baseline_eligible=false`（X-CROSS 永遠如此）」過度延伸 | review-prompt §3.7：`baseline_eligible=false` 真實語意是「不可混入 S-BASE 主表」；X-CROSS 同 phase 內受控比較仍成立 | demo §0、§1 段尾 |

## §2 Add（補上的決策資訊）

| # | Item | 來源 / 為何屬決策必要 | 取得方式 |
|---:|---|---|---|
| 1 | Executive decision statement（採跨區 / DB / placement 三層 go-no-go）| review-prompt §4.1：PoC 必須先說要決定什麼 | 新增 §1 decision statement |
| 2 | Acceptance criteria（業務 owner 提供最低 tpmC / p99 / RTO / RPO / WAN cost）| review-prompt §4.3：沒有門檻只能做探索 | 標 BLOCKED — owner TBD |
| 3 | Primary endpoint per decision track（steady-state vs resilience 分軌）| review-prompt §4.4 / §3.5 | 新增 §2 decision questions and gates |
| 4 | Scenario business owner（A-S / A-A-RO / A-A 各對應實際需求）| review-prompt §4.2 | 標 BLOCKED — owner TBD |
| 5 | IDC-only 6-node paired control（量化 WAN cost 必須的對照組）| review-prompt §4.6 | 標 BLOCKED — 尚未跑 |
| 6 | 容量映射（W=128 與 production peak 的對應）| review-prompt §4.7 | 標 BLOCKED — 無 production demand data |
| 7 | Experiment unit 區分（rounds vs independent suites vs same-cluster repeats vs rebuild repeats）| review-prompt §4.8 + 衝突 #3 | 新增 §6 measurement contract |
| 8 | Client / 系統飽和證據要求（CPU / disk / network / queue saturation）| review-prompt §4.11 | 新增 §6 gate 列表 |
| 9 | 可營運性 gate（deploy / upgrade / backup / restore / observability）| review-prompt §4.12 | 新增 §8 risks/cost/operability |
| 10 | Cost split（steady-state vs failover）| review-prompt §4.13 | 新增 §8 |
| 11 | 安全 / 治理（data residency / 加密 / IAM）| review-prompt §4.14 | 新增 §8 |
| 12 | Blocker owner / due date / 解除證據 | review-prompt §4.15 | 新增 §9 blockers and next actions |
| 13 | Evidence provenance（artifact path + manifest sha + confidence）| review-prompt §4.16 | 新增 §7 results table 欄位 |

## §3 Correct（修正的事實 / SSOT 衝突）

### 衝突表（10 項）

| # | 衝突 | 修正前 | 修正後 | repo 修改 |
|---:|---|---|---|---|
| 1 | DEV-1x1 誤標 | demo §5 把 `determinism/run1,run2` 描述為 DEV-1x1 W=4 framework selfcheck；§7 caveat 4 也寫 `flow_selfcheck=true` | 實為 true 6-node W=4 same-cluster determinism；per `pipeline-log.md` §1 + §2.1：`results/x-cross/determinism/run{1,2}/` 為「same-cluster N-round 收斂 CV ≤ 5%」 evidence | demo 重寫 §4 inventory 段；無 SSOT 改動 |
| 2 | W=128 target stale doc | `NEXT-STEPS.md` §2.1 step 1.2 寫「Makefile 沒有 W=128 X-CROSS suite target」 | `Makefile` line 135 已有 `phase-crossregion-w128-suite`；但 chain 進 `phase-crossregion-all` 含 `phase1-wait`（Mac IAP），實際限制為 `.31` controller 路徑 | **已修** `NEXT-STEPS.md` §2.1 step 1.2 — 同步現況 |
| 3 | N=5 語意錯置 | demo §3 / §13.1 把 `requires_n:1` + `ROUNDS=5` 描述為 independent N=5 suite | `manifest.yaml requires_n:1` exploratory；`ROUNDS=5` 是同 suite 5 round（per `summary-from-stdout.py` aggregate_thread_group）；independent N=5 需外層 repeat orchestration | demo 重寫 §6 measurement contract；SSOT 無需改 |
| 4 | 統計口徑衝突 | `pipeline-log.md` §1 / §5 要求 R2-R5 median / CV；`PHASES.md` §5 + `summary-from-stdout.py` canonical = R1-R5 mean | Primary = R1-R5 mean（per code + PHASES）；R2-R5 median 改列 secondary / sensitivity | **已修** `pipeline-log.md` §1 TL;DR 與 §5 下一步 |
| 5 | A-A-RO `NEW_ORDER` 寫成 read | `workload-profiles/A-A-RO.md` Client 配置表 GCP 端「只跑 NEW_ORDER/STOCK_LEVEL read paths」 | NEW_ORDER 是 write txn；A-A-RO GCP mix per `decisions-2026-06-08.md` Q6 + `run-vm6-aa.sh` line 96-98 = `0:0:50:0:50`（ORDER_STATUS + STOCK_LEVEL only）| **已修** `workload-profiles/A-A-RO.md` Client 配置表 |
| 6 | Chaos C1 / C4 spec ↔ planner script 名稱錯置 | `chaos/C1.md` spec = WAN partition iptables；`chaos/C4.md` spec = IDC leader die systemctl stop。但 planner `chaos-c1-node-down-plan.sh` model = single-node systemctl stop（對應 C4 spec 的故障模型），`chaos-c4-network-partition-plan.sh` model = iptables raft-port drop（對應 C1 spec 的故障模型） | Demo 不可宣稱「planner 已符合 spec」；spec 與 planner 故障模型互換為 known mismatch（per `chaos/README.md` 註解 + planner script header）；scenario 結果 schema 不可在 demo 列為 PASS | demo 重寫 §9 blockers；SSOT 不動（planner header 已自註） |
| 7 | 非 repo memory 引用 | demo §1 / §2.2 / §2.3 / §15 引用 `feedback_iap_tunnel_avoid`、`feedback_xcross_serial_per_db` | 改引 repo decision record：`crossregion-via31.ini` header（.31 controller，IDC↔GCP FW 已開）+ `decisions-2026-06-08.md` Q9（serial per-DB + cell sequence）；memory ref 從 demo 全移除 | demo 重寫；SSOT 無改動 |
| 8 | 每 cell VM rebuild 規則 | demo §2.3 寫「每 cell 完整 VM destroy + apply rebuild 否則殘留汙染」當科學必然 | Rebuild 降低殘留汙染但同時增加 between-suite environment variance；目前 repo evidence 僅 `decisions-2026-06-08.md` Q9 排程設計，未證明變異主導；demo 改寫為 trade-off 而非必然 | demo 重寫 §6 measurement contract |
| 9 | 拓撲語意（P-B `arbiter`）| `topology/P-B.md` 結構表稱第三 voter 為 `arbiter` | TiDB / CRDB / YBDB 三家無原生 arbiter 概念：TiDB PD 自動 balance（`tests/tidb/placement-p-b.sql` line 20-24 未指定 PRIMARY_REGION）；CRDB 用 `lease_preferences` 多 region；YBDB 用 tablespace（`tests/yuga/placement-p-b.sql` line 20 註解「YBDB tablespace 無 arbiter 概念」）；用「voter / leaseholder / leader」per DB 語意 | demo 重寫 §3 / appendix topology 段；P-B.md SSOT 未動（需專案決定是否改 ASCII；列為次要 blocker） |
| 10 | endpoint 圖統一 `:4000` | demo §2.2 / §4 圖：三家 HAProxy 都 `:4000` 並用 `jdbc/pg` 統稱 | 由 `Makefile` line 60-65 + `gate-placement-p-b.sh` line 50-52：TiDB MySQL protocol `:4000`、CRDB PostgreSQL protocol `:26257`、YBDB YSQL PostgreSQL protocol `:5433` | demo 重寫 §10 appendix topology — 三家分別標 port + protocol |

### Unified diff（已 apply；未 commit；per parent 統一管 git）

**衝突 #2** — `phase-crossregion/NEXT-STEPS.md`：

```diff
-| **1.2** | 三家 W=128 × N=5 × same-cluster suite | **目前 Makefile 沒有 W=128 X-CROSS suite target**；需 operator 新增（或沿用 `phase6/7/8-*-smoke` 但 override W 參數）。建議新 target：`phase-crossregion-w128-suite`，掛 freeze → warmup 20min → 5 round × 5min → collect |
+| **1.2** | 三家 W=128 × N=5 × same-cluster suite | `phase-crossregion-w128-suite` target 已存在於 `phase-crossregion/Makefile`（commit `5dadbbc1`）。**但內部 chain `phase-crossregion-all` 仍含 `phase1-wait`（IAP tunnel 路徑），不符 .31-only 限制；正式啟用前須切換為 `phase1-wait-via-31` + .31-native wrapper**。`ROUNDS=5` 是同 suite 的 5 個 round（不是 5 個 independent suite）；如需 independent N=5，須外層 repeat orchestration 並各自獨立 artifact。|
```

**衝突 #4** — `results/x-cross/pipeline-log.md`：

```diff
-- 正式 X-CROSS baseline 仍需 W=128、20 分鐘 warmup、R2-R5 median / CV、完整 DB-host metrics 與 `summary.json`。
+- 正式 X-CROSS baseline 仍需 W=128、20 分鐘 warmup、**canonical primary = `tpmC_mean = R1-R5 mean` per PHASES.md §5 + `summary-from-stdout.py`**（與 S-BASE / S-K8S 一致）；R2-R5 median / CV 只作為 secondary / sensitivity analysis，不取代 primary。完整 DB-host metrics 與 `summary.json` 必齊。

-3. 正式 W=128 測試需固定：same cluster、不 redeploy、placement gate、scheduler / balancer freeze、20 分鐘 warmup、R2-R5 median / CV。
+3. 正式 W=128 測試需固定：same cluster、不 redeploy、placement gate、scheduler / balancer freeze、20 分鐘 warmup；primary estimator = R1-R5 mean（per PHASES §5 / `summary-from-stdout.py`），secondary = R2-R5 median + CV（sensitivity only，不入主表）。
```

**衝突 #5** — `phase-crossregion/workload-profiles/A-A-RO.md`：

```diff
-| IDC | go-tpc @ idc-dbhost-1 | W=1-128（全）| 16/32/64/128 | idc-haproxy | full TPCC（read + write）|
-| GCP | go-tpc @ gcp-dbhost-1 | W=1-128（全；read-only mode）| 16/32/64/128 | gcp-haproxy（routed to followers）| 只跑 NEW_ORDER/STOCK_LEVEL read paths |
-
-→ 兩側 W 重疊但 GCP 走 follower read / stale read。
+| IDC | go-tpc @ idc-client (.31) | W=1-128（全）| 16/32/64/128 | idc-haproxy | full TPCC standard mix（read + write）|
+| GCP | go-tpc @ gcp-client (g-test-poc-5) | W=1-128（全；read-only mode）| 16/32/64/128 | gcp-haproxy（routed to followers）| read-only mix `--mix DELIVERY:NEW_ORDER:ORDER_STATUS:PAYMENT:STOCK_LEVEL=0:0:50:0:50`（per `decisions-2026-06-08.md` Q6；GCP 端只跑 ORDER_STATUS + STOCK_LEVEL，**NEW_ORDER 是 write txn，不在 RO mix**）|
+
+→ 兩側 W 重疊但 GCP 走 follower read / stale read（NEW_ORDER 留在 IDC writer 側）。
```

## §4 Block（unresolved，需 owner/date/evidence）

| # | Blocker | 為何 block | 解除條件 | owner |
|---:|---|---|---|---|
| 1 | W=128 正式 baseline 未跑 | `manifest.yaml` warehouses:128 是 spec；`results/x-cross/determinism/` 僅 W=4；demo 任何 W=128 結論都是 INFERRED | 跑 `phase-crossregion-w128-suite`（fix chain 改走 `phase1-wait-via-31`）；產出 3 家 same-cluster 5-round artifact + summary.json | TBD |
| 2 | P-B placement 未跑過 | `results/x-cross/` 全部 artifact `topology=vm-6node-P-A`；P-B SQL 已存在但未 apply 跑 benchmark | apply `tests/{tidb,cockroach,yuga}/placement-p-b.sql` → `gate-placement-p-b.sh` PASS → 跑 W=128 × N=5 | TBD |
| 3 | IDC-only 6-node paired control 不存在 | 量化 WAN cost 必需的對照組；目前 baseline 為 S-BASE vm-3node，硬體 / topology 不同 | 在同 IDC vlan241 部署 6-node 同硬體，跑 W=128 × N=5（A-S 即可） | TBD |
| 4 | chaos / F1 probe driver 未實裝 | `RTO-RPO-methodology.md` §3.2 / §9 step 2；go-tpc stdout 1s tick 顆粒度不足以量 RTO < 1s | 三家最小 SQL probe loop + wall-clock wrapper PR + DBA review label | TBD |
| 5 | chaos C1 / C4 spec ↔ planner 故障模型互換 | `chaos/{C1,C4}.md` spec 與 planner script 故障模型對換；script header 已自註，但 demo / 後續實跑前須 reconcile | (a) 修 spec 對齊 script，或 (b) 修 script 對齊 spec；DBA + reviewer 決定 | TBD |
| 6 | acceptance criteria（業務 threshold）缺 | 沒有最低 tpmC / p99 / RTO / RPO threshold → demo 無法下 go/no-go，只能做探索 | 業務 / 架構 owner 提供 per-profile threshold；寫入 `decisions-*.md` | TBD（業務 / 架構）|
| 7 | A-S / A-A-RO / A-A 各自業務 owner 未指派 | review-prompt §4.2：無 owner 的 profile 不應自動進正式矩陣 | 每 profile 對應實際業務需求 + owner 名字寫入 decision record | TBD |
| 8 | capacity mapping（W=128 ↔ production peak）未對齊 | 無 production demand data → W=128 / thread sweep 對應業務意義不明 | 取 production peak TPS / hotspot 樣本；對應 PoC W 與 thread | TBD |
| 9 | 三家 admin CLI 路徑 DBA 未 confirm | `F1.md` §47-52；leader stepdown / drain / list_tablets 版本 specific | 對應 cluster 版本（TiDB v8.5 / CRDB v26.2 / YBDB 2025.2）confirm | DBA |
| 10 | P-B arbiter 抽象未對齊三家實作 | `topology/P-B.md` ASCII 用 `arbiter` 但三家無原生 arbiter 概念 | 改 P-B.md 用各 DB 實際 voter / leaseholder / tablespace 語意 | TBD |

## §5 Static check 結果

審查目標（依 review-prompt §6.5）：

| 項目 | 結果 | 細節 |
|---|---|---|
| 1. `fake\|synthetic\|speculative` grep | demo 重寫前 ~50 hit；重寫後僅保留 DEMO header 與 audit `Remove` 表 reference | 主報告 §1–§10 各結論不含「realistic fake range」推導 |
| 2. `feedback_` grep | demo 重寫後 0 hit；改引 `decisions-2026-06-08.md` Q9 + `crossregion-via31.ini` header | audit doc 引用 review-prompt §2.7 描述用，不作權威 |
| 3. `DEV-1x1` / `N=5` / `R1-R5` / `R2-R5` 語意一致性 | DEV-1x1 自 demo 移除（不適用 X-CROSS）；N=5 demo 內標明 `ROUNDS=5` ≠ independent N=5；R1-R5 為 primary canonical；R2-R5 為 secondary sensitivity | pipeline-log §1 / §5 與 PHASES §5 一致 |
| 4. C1 / C4 script vs spec | demo 重寫後不宣稱 planner conforms；§9 blocker #5 明列 spec ↔ planner 故障模型互換 | C7 planner 未在 phase-crossregion/scripts/chaos/ 落地（per `chaos/README.md` 表，C7 planner 為 `chaos-c7-disk-slow-plan.sh`，但目錄列表確認存在）|
| 5. Repo-relative link 存在性 | demo §10 appendix 列出的 SSOT link 全部 cross-check：`phase-crossregion/manifest.yaml` / `Makefile` / `NEXT-STEPS.md` / `decisions-2026-06-08.md` / `topology/{P-A,P-B}.md` / `workload-profiles/{A-S,A-A-RO,A-A}.md` / `chaos/{README,C1,C4,C7}.md` / `failover/{F1,RTO-RPO-methodology}.md` / `scripts/{gate-placement-p-b.sh, chaos/chaos-c1-node-down-plan.sh, chaos/chaos-c4-network-partition-plan.sh}` / `tests/common/summary-from-stdout.py` / `results/PHASES.md` / `results/PoC-DESIGN.md` / `results/x-cross/pipeline-log.md` 全部存在 | — |

## §6 Promotion checklist（從 demo → 正式 PoC 報告需滿足）

依 `decisions-2026-06-08.md` Q12 拍板（2026-06-29）：**#1-#7 為 active task**；**#8 為 per-cell gate**（每 cell `.suite.done` 後立即跑）；**#9 為 final report gate**（最後 cell + 全 PASS 後 flip）。

### Active tasks（#1-#7）

| # | Promotion condition | 驗證 | 拍板狀態（2026-06-29 session）|
|---:|---|---|---|
| 1 | W=128 × same-cluster artifact 三家齊（at least P-A × A-S）；**ROUNDS=5 ≠ independent N=5**（per §4 B5）| `results/x-cross/` 下三家 `summary.json` warehouses=128 + R1-R5 完整 | active：先 patch chain → `phase1-wait-via-31`，再三家序列跑 |
| 2 | P-B placement gate PASS + W=128 baseline 跑完（at least A-S） | `gate-placement-p-b.sh` exit 0 + 三家 P-B summary.json | active：串在 #1 之後 |
| 3 | IDC-only 6-node paired control 跑完 | 對照組 summary.json 存在；填入 `Δ vs IDC-only` 欄 | **revised**：接受 S-BASE vm-3node 作對照（scale / 設備數不同，明標 caveat） |
| 4 | Acceptance criteria 由業務 / 架構 owner 拍板 | `decisions-*.md` 增段，含 per-profile threshold | **revised**：**不訂 threshold**，PoC 改 exploratory 不下 go/no-go |
| 5 | A-S / A-A-RO / A-A 各 profile 業務 owner 指派 | decisions record 含 owner | **revised**：三 profile 都當探查跑，不指 owner（與 #4 一致） |
| 6 | C1 / C4 spec ↔ planner 故障模型 reconcile + 三家 admin CLI 路徑 DBA confirm | spec or script 修一邊；DBA approve label | active：**以 spec 為主** rename + 重寫 script 內部 |
| 7 | probe driver + wall-clock wrapper PR merge | `RTO-RPO-methodology` §9 step 2 / 3 滿足 | active：**Claude 寫最小 UPDATE 寫入版**（非僅 SELECT 1），bash + per-DB client，100ms tick |

### Per-cell gate（#8，per Q12）

| # | Gate condition | 觸發時機 | 失敗處理 |
|---:|---|---|---|
| 8 | static check 5 項全 PASS（無 fake / 無 `feedback_` ref / 語意一致 / link 全活 / spec-script reconcile）| **每 cell `.suite.done` 後立即跑** | FAIL → cell artifact 標 `incomplete_reason: static-check-fail`；**下家 cell 不可啟動** |

### Final gate（#9）

| # | Gate condition | 觸發時機 |
|---:|---|---|
| 9 | DEMO header 改為 OFFICIAL；版本 + manifest_sha256 + git commit 入 §10 appendix | 最後一個 cell `.suite.done` + #1-#7 全 PASS + #8 重跑 PASS 後，**單一 commit** flip header |

---

## §7 VM destroy / recreate 嚴謹要求（per `decisions-2026-06-08.md` Q11）

| 規則 | 內容 |
|---|---|
| **強制動作** | 三家 DB cell 之間必跑 `make phase1-destroy phase1-apply phase1-wait-via-31`（terraform 雙側完整 destroy + apply）|
| **不接受替代** | service-level cleanup（systemctl stop + DROP DATABASE + rm -rf）**不可**取代完整 VM rebuild |
| **順序** | TiDB → PASS → CRDB → PASS → YBDB（per Q9 同 placement 內 DB 順序）|
| **不適用範圍** | 同家 DB 內 round / thread sweep 不需 VM rebuild；DEV-1x1 framework selfcheck 可降為 service-level cleanup（標 caveat）|

### Trade-off（per Q11 明列 — 非科學必然）

| 利（rebuild） | 弊（rebuild） |
|---|---|
| 降低 cross-DB residue bias（systemd / SELinux / cgroup / TCP TIME-WAIT / disk hotness / dnf cache 等）| **增加** between-suite environment variance（GCP API 排班 / vSphere datastore 熱點 / cloud-init drift / dnf mirror latency）|

**屬性**：controlled bias trade — 接受此 trade 因 X-CROSS phase `baseline_eligible: false` + `requires_n: 1`，cell 間隔離性優先於 cell 內統計穩定性。

### Audit hook（待實作）

`summary.json` schema 新增（per Q11）：
- `prev_suite_done`: 上家 cell `.suite.done` timestamp
- `vm_rebuild_ts`: 本 cell run 前 VM image creation timestamp
- wrapper `gate` 第一步驗 `.31` 對 cluster 端 SSH host key — 殘留即視為前家未清乾淨 → fail-closed

---

**END — audit only; demo report 重寫見 `x-cross-report-demo.md`**
