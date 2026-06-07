# 2026-06-06 Smoke Test Orchestration — phase-threadcontrol → VM rebuild → phase-k8s

> Master orchestration for two smoke tests landed on 2026-06-06；連結 [phase-threadcontrol/test-plan-smoke.md](../phase-threadcontrol/test-plan-smoke.md) + [phase-k8s/test-plan-smoke.md](../phase-k8s/test-plan-smoke.md)。

## 1. 總序列

```
[A] VM rebuild #1 (~35 min)
    make drop-idc-vms + make new-idc-vms + ansible-ping + ansible-setup
        │
        ▼ fresh 3 VM (.32/.33/.34)
        │
[B] ansible-playbook deploy vm-3node-haproxy-3s3r (~30 min)
    ansible-playbook playbooks/tidb-vm3.yml + dry-run-confirm
        │
[C] phase-threadcontrol Stage 1 — dry-run (~30 min)
    DRY_RUN=1 + apply readpool tuning playbook + before/after config dump
    → verify dry-run/process-check.txt + db-config-check.txt + wrapper-env-trace.txt
    → 通過 Stage 1 才進 Stage 2；失敗 STOP + 修 framework bug
        │
[D] phase-threadcontrol Stage 2 — real benchmark (~3h)
    Topology: vm-3node-haproxy-3s3r
    Knob: TiDB readpool.unified.max-thread-count 4 → 8 + auto-adjust=false
    Profile id: tidb-readpool-a
    Output: results/tidb-tc1/T-THRD/tidb-vm-3node-haproxy-3s3r-rc-tidb-readpool-a-<TS>/
        │
        ▼ revert tuning + verify guardrails
        │
[E] VM rebuild #2 (~35 min)
    make drop-idc-vms + make new-idc-vms + ansible-ping + ansible-setup
        │
[F] K3s deploy (~30 min)
    ansible-playbook playbooks/k8s.yml
        │
        ▼ K3s ready
        │
[G+H] phase-k8s 6-cell 分 3 batch 執行（codex v14 NB #4）
    Batch 1: TiDB-limit + TiDB-unlimit （dry-run + suite + cleanup-gate × 2 = ~7.5h）
        ↓ ✋ user review batch 1 → 通過才進 Batch 2
    Batch 2: CRDB-limit + CRDB-unlimit （~7.5h）
        ↓ ✋ user review batch 2 → 通過才進 Batch 3
    Batch 3: YBDB-limit + YBDB-unlimit （~7.5h）
        ↓ ✋ user review batch 3 → 結束

    Per cell 流程：helm install (namespace=<db>-<res>) → DRY_RUN=1 wrapper →
                  dump-actual.sh → diff-check.sh (canonicalize compare) →
                  compare-vm.sh (allow/warn/deny field path SSOT) →
                  Stage G gate pass → suite execute → cell-cleanup-gate

    通過條件：6 cell × .diff-pass + compare-vm.md 無「絕對不允許」diff
    Output: results/{tidb,crdb,ybdb}-tc1/S-K8S/<db>-k8s-3node-haproxy-3s3r-{limit,unlimit}-rc-<TS>/
```

## 2. 預估總時

| Stage | 時間（首次）| 時間（再執行）|
|---|---|---|
| A. VM rebuild #1 | ~35 min | ~35 min |
| B. deploy vm-3node-haproxy-3s3r | ~30 min | ~30 min |
| C. phase-threadcontrol Stage 1 dry-run | ~30 min | ~30 min |
| D. phase-threadcontrol Stage 2 real benchmark | ~3h | ~3h |
| E. VM rebuild #2 | ~35 min | ~35 min |
| F. K3s deploy | ~30 min | ~30 min |
| G+H Batch 1 (TiDB) dry-run + suite × 2 + cleanup-gate × 2 | ~7.5h | ~7.5h |
| ✋ user review batch 1 | ~30 min | ~30 min |
| G+H Batch 2 (CRDB) | ~7.5h | ~7.5h |
| ✋ user review batch 2 | ~30 min | ~30 min |
| G+H Batch 3 (YBDB) | ~7.5h | ~7.5h |
| ✋ user review batch 3 | ~30 min | ~30 min |
| deliverable 補（首次, 含 6-cell expected/dump/diff/compare/cell-cleanup-gate scripts）| ~1.5 工作天 | 0 |
| **合計** | **~4-5 工作天** | **~25h** |

## 3. 拍板來源（2026-06-06 Q1-Q6）

| Q | 決策 | 影響到本 plan |
|---|---|---|
| Q1 | phase-threadcontrol = 1 cell smoke | [A] 1 cell only |
| Q2 | topology = vm-3node-haproxy-3s3r | [A] topology 鎖定 |
| Q3 | wrapper = thin + 包 run.sh | [D] phase-k8s/run-k8s-suite.sh design |
| Q4 | phase-k8s = 1 cell smoke @ K8s haproxy-3s3r 等價 | [D] topology = k8s-3node-haproxy-3s3r-unlimit |
| Q4b (2026-06-07 user 改寫) | phase-k8s 改 6 cell = TiDB/CRDB/YBDB × {limit, unlimit} @ k8s-3node-haproxy-3s3r；dry-run 採 expected/actual/diff 簡化版（不再堆 Tier 3 11 層 probe）| [G] 6 cell dry-run sequence + helm swap；[H] 6 cell suite execute；deliverable list 新增 expected.yaml × 6 + VM baseline yaml × 3 + dump-actual.sh + diff-check.sh + compare-vm.sh |
| Q5 | VM rebuild 排在 phase-threadcontrol 後 | [B] 序列 [A] → [B] |
| Q6 | plan doc 走 codex review (B 規則)| 本文件 + 兩 sub-plan 須先 codex approve |

## 4. 必要 deliverable 清單

| # | 檔 | 對應 phase | 必要時機 |
|---|---|---|---|
| 1 | `phase-threadcontrol/playbooks/apply-tidb-readpool.yml` | A | Stage A 開始前 |
| 2 | `phase-threadcontrol/playbooks/revert-tidb-readpool.yml` | A | Stage A 結束時 |
| 3 | **`phase-threadcontrol/run-threadcontrol-suite.sh`** | A | Stage A 開始前（codex v6 blocking #1）|
| 4 | **`tests/common/lib/common.sh::write_phase_done` patch** | A + D 共用 | Stage A 開始前（codex v6 blocking #2）|
| 5 | `phase-k8s/manifest.yaml` allowed_topology patch | D | Stage D 開始前（命名 `haproxy-3s3r` 一致，codex v6 blocking #4）|
| 6 | `phase-k8s/run-k8s-suite.sh` (thin wrapper)| D | Stage D 開始前（含 phase guard, codex v6 blocking #1 + 5）|
| 7 | `phase-k8s/gate-k8s.sh` | D | Stage D 開始前 |
| 8 | `phase-k8s/prepare-k8s.sh` (prepare → SPLIT → mark) | D | Stage D 開始前（codex v6 blocking #3）|
| 9 | `phase-k8s/collect-k8s.sh` | D | Stage D 開始前 |
| 10 | Makefile `phase-k8s-run` body | D | Stage D 開始前 |

deliverable 1-4 為 A pre-req；5-10 為 D pre-req。其中 #4 (write_phase_done patch) A 與 D 共用，需先寫。

**codex v8 補充 deliverable #11**（A+D 共用，先做）：`tests/common/run-vm1-suite.sh` + `tests/common/prepare.sh` 對 phase scope path (`/S-K8S/` `/T-THRD/` `/X-CROSS/`) fail-fast，要求只能走對應 phase wrapper，不能從 baseline launcher 進來。

**codex v8 補充 deliverable #12**（D 專用）：prepare-k8s.sh 的 9-table split SQL **必須 mirror VM TiDB 明確 split points** (`tests/common/prepare.sh:134-144`)，不可用 generic BETWEEN/REGIONS（會 ERROR 8212）。

**user 補充 deliverable #13**（A+D 共用，2026-06-06 新指示 + codex v11 修正後規格）：`tests/common/run.sh` 新 `DRY_RUN=1` env flag — **bypass `.prepare.done` lookup**（不存在亦 OK）→ 直接 mkdir `$ROOT/dry-run/` + guard.sh dispatch + dry-run probes；**不呼叫**既有 gate-isolation.sh（需 tpcc DB + go-tpc）；改用無 DB 依賴 isolation probe (`mysql/psql/cockroach -e 'SHOW transaction_isolation'`)。產 7+ probe artifacts（process-check / db-config-check / wrapper-env-trace / isolation-probe / ansible-patch-result / infra-probe / `.dry-run.done`）。

**deliverable #14**（A+D 共用 wrapper special-case，codex v11 blocking）：`phase-{threadcontrol,k8s}/run-*-suite.sh` 入口判 `DRY_RUN=1` → 只跑 env/scope validation + dry-run probes；**不**進 prepare-k8s.sh / launch-vm1-suite.sh。

**deliverable #15**（K8s 專用 K8s-aware probes）：phase-k8s 場景 dry-run 額外產 `dry-run/{k8s-pod-ready, nodeport-check, tikv-status-port-check, split-sql-lint, manifest-patch-check}.txt`。

**2026-06-07 user 改寫 → 取代 #15 + 擴展 D 專用 list**（6-cell expected/actual/diff 簡化版）：

| # | 檔 | 內容 |
|---|---|---|
| 16 | `phase-k8s/manifest.yaml` patch | `allowed_topology` 加 6 entry (TiDB/CRDB/YBDB × {limit, unlimit} @ k8s-3node-haproxy-3s3r)；取代 deliverable #5 |
| 17 | `phase-k8s/expected/{tidb,crdb,ybdb}-k8s-3node-haproxy-3s3r-{limit,unlimit}.yaml` × 6 | 6 cell expected SSOT |
| 18 | `phase-k8s/expected/vm-3node-haproxy-3s3r-{tidb,crdb,ybdb}.yaml` × 3 | VM baseline 對照 SSOT |
| 19 | `phase-k8s/dump-actual.sh` | DB-aware dump (kubectl + DB config + wrapper env + isolation + haproxy.cfg) → actual.yaml |
| 20 | `phase-k8s/diff-check.sh` | `diff expected.yaml actual.yaml` → 非 0 exit 1 |
| 21 | `phase-k8s/compare-vm.sh` | actual vs VM baseline → compare-vm.md (allow/deny list 判定) |
| 22 | `phase-k8s/prepare-k8s.sh` 擴展（取代 deliverable #8）| DB-aware：TiDB 9-table explicit split / CRDB no-op / YBDB tablet pre-split |
| 23 | `phase-k8s/gate-k8s.sh` DB-aware 擴展（取代 deliverable #7）| TiDB :20180 / CRDB :8080 / YBDB :7000 status port 各別預檢 |
| 24 | `phase-k8s/run-k8s-suite.sh` DB-aware（取代 deliverable #6）| `--db {tidb,crdb,ybdb}` flag；DRY_RUN=1 → dump+diff+compare → STOP；DRY_RUN=0 → 固定 chain |
| 25 | `Makefile` `phase-k8s-dry-run-<cell>` + `phase-k8s-run-<cell>` × 6（取代 deliverable #10）| Make entrypoint × 12（或 loop）|

deliverable #15 K8s-aware probes 仍部分保留（含於 #19 dump-actual.sh 內，但格式從 free-text 改為 yaml 結構）。

**2026-06-07 codex v14 review fixes（additional deliverable）**：

| # | 檔 | 內容 |
|---|---|---|
| 26 | `phase-k8s/manifest.yaml` patch 擴展（取代 #16）| 新增 `allowed_db: [tidb, crdb, ybdb]` 欄位；`allowed_topology` 加 2 entry；6 cell = `allowed_db × allowed_topology` 笛卡兒積；對應 PHASES.md §3 schema 補 `allowed_db: REQUIRED list[string]` |
| 27 | expected.yaml × 6 schema 擴展（取代 #17）| 補：`tuning_profile_id: default` (取代 `TUNING_PROFILE: ""`)；`k8s.namespace=<db>-{limit,unlimit}` (每 cell 獨立 ns)；`k8s.db_image`/`resource_requests`/`anti_affinity`/`pvc_bound_nodes`；`split.expected_region_count`；workload 對齊 v4.7 (`warmup_sec:1200`/`warmup_threads:64`/`threads_list:[16,32,64,128]`/`rounds:5`/`duration_sec_per_thread:300`)；YBDB `enable_automatic_tablet_splitting` typo fix |
| 28 | `phase-k8s/cell-cleanup-gate.sh`（新增；介於 #21 #22）| helm uninstall + namespace delete + PVC + PV (local-path retain) + CRD instances + ansible FS clean (`/var/lib/rancher/k3s/storage/pvc-*`) + final no-residue check；每 cell 結束必呼叫 |
| 29 | `phase-k8s/diff-check.sh` 改 canonicalize-compare（取代 #20）| `yq -P 'sort_keys(.)' actual.yaml expected.yaml` 先 canonicalize → `jq -e` subset compare expected ⊆ actual；**不**用 raw `diff` |
| 30 | `phase-k8s/compare-vm.sh` field path SSOT（取代 #21）| allow/warn/deny 寫死 field path：`network.nodeport`/`k8s.*`/`db_config.tikv_block_cache_*` = allow；`db_config.tikv_readpool_*` = warn；`workload.*`/`isolation.*`/`split.strategy`/`network.haproxy_backends` = deny |
| 31 | Batch 執行 sequence（取代 #25）| Makefile 改 `phase-k8s-batch-{tidb,crdb,ybdb}` × 3（每 batch 跑 dry-run + suite × 2 + cleanup × 2）；user review gate 在 batch 間 |

## 5. 風險與 fallback

| 風險 | impact | mitigation |
|---|---|---|
| A 期間 TiKV readpool patch 後 cluster 不穩 | A fail；可能影響 baseline 狀態 | Stage A.6 revert playbook；若 revert fail → `make new-idc-vms` 早期觸發 Stage B |
| B VM rebuild 失敗（terraform / network） | 後續 C/D 阻塞 | `terraform plan` 預先檢查；GCP routing 確認（C1 已 ✓ 但 IDC vSphere 可能受影響）|
| C K3s deploy 失敗 | D 不能 start | `ansible-playbook --check` 預跑；retry 3 次 |
| D phase-k8s wrapper bug | smoke fail，須 fix 後重跑 | Q3 拍板 thin wrapper = run.sh + override env，code 量最少 |
| D K8s SPLIT TABLE 失敗 | shard 不到 3 | 改用 `tidb_split_region_concurrency` + pd-ctl region scatter；fall back to 1 shard |

## 6. 成功條件（master）

整體 smoke 通過 = 兩個 sub-plan 各自的「成功條件」全綠 + 以下 cross-cutting：

- [ ] 兩 phase 的 result artifact 嚴格隔離（A 在 `T-THRD/`、D 在 `S-K8S/`，互不嵌套）
- [ ] `results/verify-readme-gates.sh` 6/6 PASS（A 跑前、A 跑後、D 跑後三次驗證）
- [ ] task list #110 後續 task 對應更新（任務追蹤）
- [ ] commit 紀錄：每 stage 完成 commit 一次（A run commit + D run commit + deliverable patches）

## 7. codex review 流程（Q6 拍板）

本 plan + 兩 sub-plan 為 phase 設計總綱 → 走 codex (B 規則 a 類)。

```
1. 寫 3 plan doc (本檔 + threadcontrol + k8s smoke) → 本 commit ✓
2. 送 codex same session 019e38f2 review
3. codex verdict:
   - approve → 補 deliverable + 執行
   - changes-required → iterate
4. deliverable commit 各自 codex review (B 規則 b 類 commit 前 git diff)
5. 執行 A → B → C → D
6. 各 stage 完成後 docs sync + master plan「結果」段填數字
```

## 8. 變更歷史

| 日期 | commit | 變更 |
|---|---|---|
| 2026-06-06 | （已 push）| 初版 orchestration plan（Q1-Q6 已拍板）|
| 2026-06-07 | （本 commit）| **大改**：phase-k8s 1-cell → 6-cell (TiDB/CRDB/YBDB × {limit, unlimit})；dry-run 改 expected/actual/diff 簡化版；Stage G/H 序列 + 估時更新；新增 deliverable #16-25（expected.yaml × 6 + VM baseline × 3 + dump/diff/compare scripts + DB-aware gate/prepare/run-suite/Makefile）|
| 2026-06-07 | （本 commit fixup-1, codex v14 review）| 修 5 blocking + 4 non-blocking：workload schema 對齊 v4.7 / manifest `allowed_db` + 6-cell 笛卡兒積 / `tuning_profile_id: default` / cell-cleanup-gate.sh (PVC/PV/CRD/FS clean) / YBDB typo fix；NB: canonicalize-compare / expected schema 擴展 / compare-vm field path SSOT / 3 batch 執行 (TiDB→CRDB→YBDB) 含 user review gate。新增 deliverable #26-31。 |
