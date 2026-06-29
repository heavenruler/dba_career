# X-CROSS Demo Report — DEMO / NOT-FOR-DECISION

> **Status**: framework-only preview。本檔不含任何 fake 數字。未量到的值寫 `TBD (not measured)`。
> Generated: 2026-06-29 · Author: planner-only · 對應 SSOT: `phase-crossregion/manifest.yaml`
> Promotion 條件見 `x-cross-report-demo-audit.md` §6（9 項）。

Evidence-state tags 用法：
- **MEASURED**: artifact 真實存在且通過 schema 檢查（`results/x-cross/...`）
- **DERIVED**: 由 MEASURED 經明確規則推導
- **INFERRED**: 邏輯/架構推論，非實測；可能錯
- **PLANNED**: spec 已寫但未跑
- **BLOCKED**: 缺前置（owner / driver / FW / spec reconcile），不可推進

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

### 10.3 變更歷史

| 日期 | 內容 |
|---|---|
| 2026-06-29 | Reverse review 重寫：移除 fake 數字；decision-first 結構；evidence-state tag；SSOT 衝突 #2 / #4 / #5 已修，#1 / #3 / #6–#10 列 audit doc unresolved blocker（per `x-cross-report-demo-audit.md`）|

---

**END — DEMO / NOT-FOR-DECISION; no fake numbers; promotion checklist in `x-cross-report-demo-audit.md` §6.**
