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
[F] K3s + TiDB Operator deploy (~30 min)
    ansible-playbook playbooks/k8s.yml
    ansible-playbook playbooks/tidb-k8s.yml --extra-vars '@vars/tidb-k8s-3node-unlimit.yml'
        │
        ▼ K8s ready, NodePort :30004 通
        │
[G] phase-k8s Stage 1 — dry-run (~30 min)
    DRY_RUN=1 + verify K8s pod ready + NodePort + manifest patch + wrapper env trace
    → 通過 Stage 1 才進 Stage 2；失敗 STOP + 修 K8s wrapper
        │
[H] phase-k8s Stage 2 — real benchmark (~3h)
    Topology: k8s-3node-haproxy-3s3r-unlimit
    DB: TiDB unlimit
    Output: results/tidb-tc1/S-K8S/tidb-k8s-3node-haproxy-3s3r-unlimit-rc-<TS>/
```

## 2. 預估總時

| Stage | 時間（首次）| 時間（再執行）|
|---|---|---|
| A. VM rebuild #1 | ~35 min | ~35 min |
| B. deploy vm-3node-haproxy-3s3r | ~30 min | ~30 min |
| C. phase-threadcontrol Stage 1 dry-run | ~30 min | ~30 min |
| D. phase-threadcontrol Stage 2 real benchmark | ~3h | ~3h |
| E. VM rebuild #2 | ~35 min | ~35 min |
| F. K3s + TiDB Operator deploy | ~30 min | ~30 min |
| G. phase-k8s Stage 1 dry-run | ~30 min | ~30 min |
| H. phase-k8s Stage 2 real benchmark | ~3h | ~3h |
| 15 deliverable 補（首次）| ~半天-1 天 | 0 |
| **合計** | **~2-2.5 工作天** | **~9h 10min** |

## 3. 拍板來源（2026-06-06 Q1-Q6）

| Q | 決策 | 影響到本 plan |
|---|---|---|
| Q1 | phase-threadcontrol = 1 cell smoke | [A] 1 cell only |
| Q2 | topology = vm-3node-haproxy-3s3r | [A] topology 鎖定 |
| Q3 | wrapper = thin + 包 run.sh | [D] phase-k8s/run-k8s-suite.sh design |
| Q4 | phase-k8s = 1 cell smoke @ K8s haproxy-3s3r 等價 | [D] topology = k8s-3node-haproxy-3s3r-unlimit |
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
| 2026-06-06 | （本 commit）| 初版 orchestration plan（Q1-Q6 已拍板）|
