# phase-k8s — Smoke Test Plan (6-cell, expected/actual/diff)

> Goal: 6 cell (TiDB/CRDB/YBDB × {limit, unlimit}) @ `k8s-3node-haproxy-3s3r` dry-run 全 pass → 再 suite execute；每 cell 與 `vm-3node-haproxy-3s3r` baseline 對照。
>
> **取代 v8 1-cell Tier 3 過度設計**（2026-06-07 user 指示）：簡化為 declarative `expected.yaml` SSOT + `dump-actual.sh` + `diff-check.sh`，不再堆 11 層 × 25 probe。
>
> **兩階段測試**：Stage 1 dry-run (參數 diff-check 通過) → Stage 2 suite execute。

> **2026-06-08 phase-1 MVP scope cut**（user 指示，跳過 v16 codex review）：
> - **phase-1 MVP**：只跑 **TiDB-unlimit 1 cell** @ `k8s-3node-haproxy-3s3r-unlimit` 的 dry-run，通過後**立即停止**。CRDB/YBDB + limit cell + suite execute → defer 至 phase-2。
> - 詳細執行步驟見 §14 「phase-1 MVP appendix」。
> - 本 plan §1-§13 仍保留完整 6-cell 規格作為 phase-2 SSOT。
> - 修 v15 codex blocking #4: `expected_region_count: 9` → `expected_tables: 9` + `expected_shards_per_table: 3`（per-table 不是 total）。
> - 修 v15 codex NB #2: `duration_sec_per_thread: 300` → `run_sec: 300`（對齊既有 `tests/common/run.sh` marker）。

## 0. Cell Matrix（6 cell）

| # | DB | Topology | resource.limits | NodePort | Client |
|---|---|---|---|---|---|
| 1 | TiDB | `k8s-3node-haproxy-3s3r-limit` | cpu/mem **set** | 30004 | mysql |
| 2 | TiDB | `k8s-3node-haproxy-3s3r-unlimit` | **unset** | 30004 | mysql |
| 3 | CRDB | `k8s-3node-haproxy-3s3r-limit` | cpu/mem **set** | 30002 | psql |
| 4 | CRDB | `k8s-3node-haproxy-3s3r-unlimit` | **unset** | 30002 | psql |
| 5 | YBDB | `k8s-3node-haproxy-3s3r-limit` | cpu/mem **set** | 30003 | psql |
| 6 | YBDB | `k8s-3node-haproxy-3s3r-unlimit` | **unset** | 30003 | psql |

**對照 baseline**：`vm-3node-haproxy-3s3r-{tidb,crdb,ybdb}`（已存在的 VM smoke baseline）。

## 1. 簡化 Dry-run 設計

| 元件 | 角色 |
|---|---|
| **`expected/<db>-<topo>.yaml`** | declarative SSOT — 6 份；每份描述該 cell 應有的全部參數 |
| **`expected/vm-3node-haproxy-3s3r-<db>.yaml`** | VM baseline SSOT — 3 份；對照用（同 DB 跨平台 diff）|
| **`dump-actual.sh`** | dry-run 跑：dump K8s / DB / wrapper env 同欄位成 `actual.yaml` |
| **`diff-check.sh`** | **canonicalize-compare**（codex v14 non-blocking #1）：先 `yq -P 'sort_keys(.)' ...` canonicalize → `jq -e` subset compare expected ⊆ actual；非 0 即 exit 1 + 列 mismatch field path。**不**用 raw `diff`（單位/欄位順序/預設值敏感）|
| **`compare-vm.sh`** | actual vs VM baseline → 用 §4 allow/deny **field path SSOT** 判定 → 產 `compare-vm.md` |

## 2. expected.yaml schema

```yaml
# expected/tidb-k8s-3node-haproxy-3s3r-limit.yaml (example)
db: tidb                 # tidb | crdb | ybdb
topology: k8s-3node-haproxy-3s3r-limit
phase_env:
  PHASE_NAME: phase-k8s
  RESULT_SCOPE: S-K8S
  BASELINE_ELIGIBLE: true
  BASELINE_FAMILY: k8s
  tuning_profile_id: default       # codex v14 blocking #3 fix：S-K8S 自動寫 default（不用 TUNING_PROFILE: ""）
k8s:
  namespace: tidb-limit            # codex v14 blocking #4：每 cell 獨立 namespace
  pod_replicas:
    storage: 3                     # TiDB tikv / CRDB roach / YBDB yb-tserver
    compute: 3                     # TiDB tidb-server / CRDB N.A. (合一) / YBDB yb-tserver (合一)
    haproxy: 1
  db_image: pingcap/tidb:v7.5.0    # codex v14 NB #2：補 image/version
  resource_requests:               # codex v14 NB #2：補 requests
    cpu: "2"
    memory: "4Gi"
  resource_limits:                 # null on unlimit cell
    cpu: "4"
    memory: "8Gi"
  storage_class: local-path
  pv_size: 50Gi
  anti_affinity: required          # codex v14 NB #2：pod anti-affinity (3 storage pod 分散 3 node)
  pvc_bound_nodes: [.32, .33, .34] # actual PV node binding
db_config:
  # TiDB family
  tikv_readpool_unified_max_thread_count: 4
  tikv_readpool_unified_auto_adjust_pool_size: true
  tikv_block_cache_capacity_derived_from_limit: true    # limit cell 4G; unlimit auto
  pd_max_replicas: 3
  # CRDB family (override per DB):
  # default_transaction_isolation: read committed
  # cache: 25%
  # max_sql_memory: 25%
  # YBDB family (override per DB):
  # replication_factor: 3
  # enable_automatic_tablet_splitting: false   # v15 blocking #1 fix：對齊 PoC-DESIGN SSOT (false 不是 true)
  # ysql_num_shards_per_tserver: 1             # guardrail; 正式 shard 由 schema pre-create `SPLIT INTO N TABLETS` 控制
  # ysql_max_connections: 300
workload:                          # codex v14 blocking #1 fix：對齊 v4.7 spec; v15 NB #2: rename run_sec
  warehouses: 128
  threads_list: [16, 32, 64, 128]
  rounds: 5
  warmup_threads: 64
  warmup_sec: 1200
  run_sec: 300                     # 5 min per round (對齊 tests/common/run.sh marker `run_sec`)
isolation:
  level: READ-COMMITTED
  txn_mode: pessimistic            # TiDB only; CRDB/YBDB 留空
network:
  haproxy_backends: 3
  nodeport: 30004                  # TiDB 30004 / CRDB 30002 / YBDB 30003
  client_proto: mysql              # mysql for TiDB; postgres for CRDB/YBDB
split:
  strategy: tidb_explicit_9table   # tidb_explicit_9table | crdb_auto_range | ybdb_pre_create_split_into
  source_ref: tests/common/prepare.sh:134-144   # TiDB only
  expected_tables: 9               # v15 blocking #4 fix：per-table 不是 total
  expected_shards_per_table: 3     # TiDB region / CRDB range / YBDB tablet 每張表 ≥3
                                   # YBDB: pre-create `SPLIT INTO 3 TABLETS`（PoC-DESIGN §7.5.3）
                                   # YBDB gflag `enable_automatic_tablet_splitting: false` 為 guardrail
```

## 3. dry-run 流程 per cell（簡化版）

```
[1] wrapper 入口讀 expected/<db>-<topology>.yaml
[2] guard.sh dispatch: assert_phase_k8s_target "$ROOT"
[3] dump-actual.sh:
    - kubectl get pods/svc/nodes/pvc → replicas/resource_limits/storage_class
    - DB-aware config dump:
      * TiDB: curl TiKV :20180/config + curl PD :2379/api/v1/config
      * CRDB: cockroach sql -e 'SHOW CLUSTER SETTING ALL'
      * YBDB: yb-admin get_gflags all + psql -d yugabyte -c 'SHOW ALL'
    - wrapper env dump → workload + phase_env
    - isolation probe (DB-aware SQL，對齊 gate-isolation.sh 口徑)
    - haproxy.cfg dump (backend pool)
    → write $ROOT/dry-run/actual.yaml
[4] diff-check.sh expected.yaml actual.yaml
    - diff 為 0 → write $ROOT/dry-run/.diff-pass
    - diff 非 0 → write diff.txt + exit 1
[5] compare-vm.sh actual.yaml expected/vm-3node-haproxy-3s3r-<db>.yaml
    → write $ROOT/dry-run/compare-vm.md
[6] write $ROOT/.dry-run.done (含 cell metadata)
[7] STOP（不執行 prepare / warmup / run / collect）
```

## 4. VM baseline 對照原則（field path SSOT）

`compare-vm.md` 將 diff field 分三類，**field path 寫死於 `compare-vm.sh`**（codex v14 NB #3）：

### ✅ Allow（平台差異，記錄不 fail）
```
network.nodeport                          # K8s NodePort vs VM HAProxy :4000
network.client_proto                      # tcp connector path 不同
k8s.*                                     # K8s 層全部 (vs VM 沒有 k8s.*)
db_config.tikv_block_cache_capacity_*     # limit cell derived from pod limit
phase_env.tuning_profile_id               # 兩平台都 default
```

### ⚠️ Warn（DB 內部 derived，記錄走 codex review）
```
db_config.tikv_readpool_unified_max_thread_count   # K8s 4 vs VM 8 (cgroup vs OS)
db_config.tikv_grpc_concurrency                    # 同上
db_config.pd_max_replicas                          # 兩平台都 3 但 actual 可能 drift
split.expected_region_count                        # 9 vs 9 應該 0 diff，drift = warn
```

### ❌ Deny（絕對不允許，exit 1）
```
phase_env.PHASE_NAME                # 必 phase-k8s vs phase-baseline (VM)，platform-derived，不算 deny
phase_env.RESULT_SCOPE              # 必 S-K8S vs S-BASE，同上，不算 deny
phase_env.BASELINE_FAMILY           # k8s vs vm，platform-derived，不算 deny
phase_env.BASELINE_ELIGIBLE         # 必兩平台都 true，drift = deny
workload.*                          # 全部 deny（warehouses/threads_list/rounds/warmup_*/duration_*）
isolation.*                         # 全部 deny（level/txn_mode）
split.strategy                      # tidb_explicit_9table vs tidb_explicit_9table，drift = deny
network.haproxy_backends            # 必 3
```

**注意**：`phase_env.PHASE_NAME` / `RESULT_SCOPE` / `BASELINE_FAMILY` 三項在跨平台對照下**理應不同**（k8s vs vm），所以 compare-vm.sh 對這三 field 用 platform-derived expected mapping，不做 raw equality；其他 fields 走 allow/warn/deny 三分法。

## 5. 6 cell 序列（分批執行，含 cell cleanup gate）

**分批策略**（codex v14 NB #4）：避免跑滿 18h 才發現 wrapper bug，按 DB family 分 3 批，每批 dry-run + suite 後 user review pass 才進下批。

```
[F] VM rebuild (×1 allowed) + K3s deploy
  │
  ├─[Batch 1: TiDB]──────────────────────────────────────────
  │   ├── deploy: ansible-playbook tidb-k8s.yml (namespace=tidb-limit)
  │   ├── [G1] dry-run cell #1 (TiDB-limit)         → .diff-pass + compare-vm.md
  │   ├── cell-cleanup-gate (定義見下)
  │   ├── redeploy (namespace=tidb-unlimit)
  │   ├── [G2] dry-run cell #2 (TiDB-unlimit)       → .diff-pass + compare-vm.md
  │   ├── cell-cleanup-gate
  │   ├── [H1+H2] suite execute (2 × ~3h)           → ~6h
  │   └── ✋ user review batch 1 results
  │
  ├─[Batch 2: CRDB]──────────────────────────────────────────
  │   ├── cell-cleanup-gate (full DB family swap)
  │   ├── deploy: helm install crdb (namespace=crdb-limit)
  │   ├── [G3] dry-run cell #3 (CRDB-limit)
  │   ├── cell-cleanup-gate + redeploy unlimit
  │   ├── [G4] dry-run cell #4 (CRDB-unlimit)
  │   ├── [H3+H4] suite execute (2 × ~3h)           → ~6h
  │   └── ✋ user review batch 2 results
  │
  └─[Batch 3: YBDB]──────────────────────────────────────────
      ├── cell-cleanup-gate
      ├── deploy: helm install yugabyte (namespace=ybdb-limit)
      ├── [G5] dry-run cell #5 (YBDB-limit)
      ├── cell-cleanup-gate + redeploy unlimit
      ├── [G6] dry-run cell #6 (YBDB-unlimit)
      ├── [H5+H6] suite execute (2 × ~3h)           → ~6h
      └── ✋ user review batch 3 results
```

### cell-cleanup-gate（codex v14 blocking #4）

每 cell 結束後必須執行（防 PVC/CRD/namespace 殘留污染下一 cell）：

```bash
cell_cleanup_gate() {
  local NS=$1
  helm uninstall -n "$NS" <release>             # uninstall helm release
  kubectl delete namespace "$NS" --wait=false   # cascade delete pod/svc/pvc
  kubectl delete pvc -A -l app.kubernetes.io/managed-by=Helm  # 殘留 PVC
  # 等 pod / pvc / pv 全 gone (PV 為 local-path → retain 需手動清)
  kubectl wait --for=delete pod -A -l app.kubernetes.io/instance="$NS" --timeout=180s
  kubectl wait --for=delete pvc -A --field-selector=metadata.namespace="$NS" --timeout=180s
  kubectl get pv | grep "$NS" | awk '{print $1}' | xargs -r kubectl patch pv -p '{"spec":{"persistentVolumeReclaimPolicy":"Delete"}}'
  kubectl get pv | grep "Released" | awk '{print $1}' | xargs -r kubectl delete pv

  # local-path provisioner FS cleanup (k3s 預設 /var/lib/rancher/k3s/storage)
  ansible all -m shell -a 'rm -rf /var/lib/rancher/k3s/storage/pvc-*'

  # CRD cleanup（TiDB Operator 留 CRD instances，需手動）
  case <db> in
    tidb) kubectl delete tidbclusters.pingcap.com -A --all ;;
    crdb) kubectl delete cockroachdbs.crdb.cockroachlabs.com -A --all 2>/dev/null || true ;;
    ybdb) kubectl delete ybclusters.yugabytedb.com -A --all 2>/dev/null || true ;;
  esac

  # final check：無殘留 pod/pvc/pv in "$NS"
  test -z "$(kubectl get pod,pvc -n "$NS" 2>/dev/null)" || die "cell-cleanup-gate FAILED: $NS still has resources"
}
```

**namespace 命名**：`<db>-{limit, unlimit}`（6 個 namespace 對應 6 cell；不複用）。

## 6. 環境前置

| 項 | 狀態 |
|---|---|
| VM rebuild (.32/.33/.34) | 允許 ×1 (user 2026-06-07 授權) |
| K3s server / agent | `ansible-playbook playbooks/k8s.yml` |
| TiDB Operator + TidbCluster | `ansible-playbook playbooks/tidb-k8s.yml --extra-vars '@vars/tidb-k8s-3node-haproxy-3s3r-{limit,unlimit}.yml'` |
| CockroachDB | `helm install crdb cockroachdb/cockroachdb -f vars/crdb-k8s-3node-haproxy-3s3r-{limit,unlimit}.yml` |
| YugabyteDB | `helm install yugabyte yugabytedb/yugabyte -f vars/ybdb-k8s-3node-haproxy-3s3r-{limit,unlimit}.yml` |
| go-tpc client (.31) | 既有 |

### manifest 6-cell 表達（codex v14 blocking #2 fix）

`phase-k8s/manifest.yaml` 需新增 `allowed_db` 欄位，並擴 `allowed_topology`：

```yaml
allowed_db:
  - tidb
  - crdb
  - ybdb
allowed_topology:
  - k8s-3node-limit                              # 舊 entry, 保留
  - k8s-3node-unlimit                            # 舊 entry, 保留
  - k8s-3node-haproxy-3s3r-limit                 # 新
  - k8s-3node-haproxy-3s3r-unlimit               # 新
```

**6 cell = allowed_db × allowed_topology 笛卡兒積 ∩ 本 plan §0 matrix**（不開放任意組合；wrapper 入口讀 `expected/<db>-<topology>.yaml` 為唯一 cell SSOT）。

對應 PHASES.md §3 manifest schema 須補：
- `allowed_db: REQUIRED list[string]` enum: `{tidb, crdb, ybdb}` （與 baseline_family 相依）
- 既有 `allowed_topology` 規則不變

## 7. Pending deliverable

| # | 檔 | 內容 |
|---|---|---|
| 1 | `phase-k8s/manifest.yaml` patch | 新增 `allowed_db: [tidb, crdb, ybdb]` + 擴 `allowed_topology` 2 entry (`k8s-3node-haproxy-3s3r-{limit, unlimit}`)；6 cell = 笛卡兒積（codex v14 blocking #2）|
| 2 | `phase-k8s/expected/{tidb,crdb,ybdb}-k8s-3node-haproxy-3s3r-{limit,unlimit}.yaml` × 6 | 6 cell expected SSOT（v4.7 workload spec + tuning_profile_id:default + namespace per cell + image/version + resource_requests + anti_affinity + pvc_bound_nodes + DB-aware db_config）|
| 3 | `phase-k8s/expected/vm-3node-haproxy-3s3r-{tidb,crdb,ybdb}.yaml` × 3 | VM baseline 對照 SSOT |
| 4 | `phase-k8s/dump-actual.sh` | DB-aware dump → actual.yaml (kubectl get pods/svc/pvc/pv + DB config + wrapper env + isolation + haproxy.cfg + actual region/range/tablet count) |
| 5 | `phase-k8s/diff-check.sh` | **canonicalize-compare**（codex v14 NB #1）：yq sort-keys + jq subset compare，**不**用 raw diff |
| 6 | `phase-k8s/compare-vm.sh` | actual vs VM baseline → compare-vm.md (allow/warn/deny **field path SSOT** per §4) |
| 7 | `phase-k8s/cell-cleanup-gate.sh` | helm uninstall + namespace + PVC + PV + CRD + local-path FS clean + final no-residue check（codex v14 blocking #4）|
| 8 | `phase-k8s/run-k8s-suite.sh` | thin wrapper：DRY_RUN=1 → guard + dump + diff + compare-vm → STOP；DRY_RUN=0 → gate-k8s → prepare-k8s → run.sh → collect-k8s |
| 9 | `phase-k8s/gate-k8s.sh` | K8s ready gate (kubectl wait pod ready + NodePort + DB-aware status port) |
| 10 | `phase-k8s/prepare-k8s.sh` | DB-aware prepare：TiDB 9-table explicit split (mirror `tests/common/prepare.sh:134-144`) / CRDB no-op + verify SHOW RANGES / YBDB tablet pre-split via `--num_tablets` gflag + verify yb-admin list_tablets |
| 11 | `phase-k8s/collect-k8s.sh` | `kubectl logs/describe` + DB-aware status |
| 12 | `Makefile` `phase-k8s-dry-run-<cell>` + `phase-k8s-run-<cell>` × 6 (或 loop) | Make entrypoint |

**共用 deliverable（B1 已列，不重複）**：
- `tests/common/run.sh` DRY_RUN flag
- `tests/common/lib/common.sh::write_phase_done` patch
- `tests/common/run-vm1-suite.sh` + `tests/common/prepare.sh` scope guard

## 8. 執行步驟（分批，含 cell-cleanup-gate）

```bash
# === Stage F: VM rebuild + K3s deploy ===
make new-idc-vms && make ansible-ping && make ansible-setup
cd ansible && ansible-playbook -i ../ansible/inventory/hosts.ini playbooks/k8s.yml

# === Per-batch loop: TiDB → CRDB → YBDB ===
run_cell() {
  local DB=$1 RES=$2
  local TOPO="k8s-3node-haproxy-3s3r-${RES}"
  local NS="${DB}-${RES}"
  local TS=$(date '+%Y%m%dT%H%M%S%z')

  # 1) deploy DB cluster to dedicated namespace
  case $DB in
    tidb) ansible-playbook playbooks/tidb-k8s.yml \
            --extra-vars "@vars/tidb-k8s-3node-haproxy-3s3r-${RES}.yml" \
            --extra-vars "namespace=${NS}" ;;
    crdb) helm install crdb cockroachdb/cockroachdb \
            -n "$NS" --create-namespace \
            -f vars/crdb-k8s-3node-haproxy-3s3r-${RES}.yml ;;
    ybdb) helm install yugabyte yugabytedb/yugabyte \
            -n "$NS" --create-namespace \
            -f vars/ybdb-k8s-3node-haproxy-3s3r-${RES}.yml ;;
  esac

  # 2) dry-run via DRY_RUN=1
  ssh root@172.24.40.31 "env DRY_RUN=1 TPCC_TS=${TS} K8S_NAMESPACE=${NS} \
    PHASE_NAME=phase-k8s RESULT_SCOPE=S-K8S BASELINE_ELIGIBLE=true BASELINE_FAMILY=k8s \
    bash /tmp/poc-tpcc/scripts/run-k8s-suite.sh --db ${DB} --topology ${TOPO} --ts ${TS}"

  # 3) fetch + acceptance check
  DRY_OUT="results/${DB}-tc1/S-K8S/${DB}-${TOPO}-rc-${TS}-dry-run"
  rsync -av "root@172.24.40.31:/tmp/poc-tpcc/artifacts/S-K8S/${DB}-${TOPO}-rc-${TS}/" "$DRY_OUT/"

  test -f "$DRY_OUT/dry-run/.diff-pass"     || die "diff-check FAILED for ${DB}-${RES}"
  test -s "$DRY_OUT/dry-run/compare-vm.md"  || die "compare-vm.md missing for ${DB}-${RES}"
  jq -e '.phase=="phase-k8s" and .result_scope=="S-K8S" and .baseline_family=="k8s" and .tuning_profile_id=="default"' \
    "$DRY_OUT/.dry-run.done" || die ".dry-run.done metadata mismatch"

  # 4) Stage G acceptance gate（dry-run pass 才繼續）
  echo "[GATE] dry-run pass for ${DB}-${RES}; proceeding to suite execute"

  # 5) Stage H suite execute (DRY_RUN unset)
  TS2=$(date '+%Y%m%dT%H%M%S%z')
  ssh root@172.24.40.31 "env TPCC_TS=${TS2} K8S_NAMESPACE=${NS} \
    PHASE_NAME=phase-k8s RESULT_SCOPE=S-K8S BASELINE_ELIGIBLE=true BASELINE_FAMILY=k8s \
    bash /tmp/poc-tpcc/scripts/run-k8s-suite.sh --db ${DB} --topology ${TOPO} --ts ${TS2}"

  # 6) cell-cleanup-gate（codex v14 blocking #4）
  bash phase-k8s/cell-cleanup-gate.sh --namespace "$NS" --db "$DB"
}

# === Batch 1: TiDB ===
run_cell tidb limit
run_cell tidb unlimit
# ✋ user review batch 1 → 確認 framework OK 才進 Batch 2

# === Batch 2: CRDB ===
run_cell crdb limit
run_cell crdb unlimit
# ✋ user review batch 2

# === Batch 3: YBDB ===
run_cell ybdb limit
run_cell ybdb unlimit
# ✋ user review batch 3 → final master plan「結果」段
```

## 9. 成功條件

- [ ] 6 cell × `.diff-pass` 全存在
- [ ] 6 cell × `compare-vm.md` 差異只在「允許平台差異」/「可接受 DB 內部差異」軸
- [ ] **無**「絕對不允許」級 diff（workload/isolation/scope/split.strategy）
- [ ] Stage H 後 6 cell artifact 落於 `results/<db>-tc1/S-K8S/<cell>-rc-<TS>/`
- [ ] 6 cell `.suite.done` 含 `phase=phase-k8s, result_scope=S-K8S, baseline_family=k8s`
- [ ] `bash results/verify-readme-gates.sh` 6/6 PASS
- [ ] tpmC 6 值落地於本 doc「結果」段（K8s family，不可作為 baseline 對標）

## 10. Rollback

| 失敗類型 | rollback |
|---|---|
| K3s deploy 失敗 | `make new-idc-vms` 重啟（消耗第二次 rebuild 額度）|
| DB cluster CrashLoop | `kubectl describe pod` + `kubectl logs`；視情況改 vars/*.yml 後 redeploy |
| dry-run diff-check FAIL | 視 `diff.txt` 修 expected.yaml（如 baseline drift）或修 helm vars（如 deploy 錯）|
| compare-vm 出現「絕對不允許」diff | STOP；走 codex review 決定是 framework bug 還是 baseline 過時 |
| Stage H 中段失敗 | 該 cell 重跑；其餘 cell artifact 保留 |

## 11. 估時

| Stage | 時間 |
|---|---|
| Pending deliverable 1-12 補（首次）| ~1.5 工作天 |
| Stage F VM rebuild + K3s deploy | ~30 min |
| **Batch 1 (TiDB)**: 2 cell dry-run + cleanup-gate × 2 + suite × 2 | ~30 min dry-run + ~20 min cleanup + ~6h suite + ~30 min user review = **~7.5h** |
| **Batch 2 (CRDB)**: 2 cell dry-run + cleanup-gate × 2 + suite × 2 | ~7.5h |
| **Batch 3 (YBDB)**: 2 cell dry-run + cleanup-gate × 2 + suite × 2 | ~7.5h |
| **合計（dry-run 階段，含 deliverable）** | **~2 工作天** |
| **合計（含 3 batch suite execute, 可分天）**| **~4-5 工作天** |

**分批好處（codex v14 NB #4）**：Batch 1 跑完 user review → 早期抓 wrapper bug → 不浪費 12h on broken framework。

## 12. 與 phase-threadcontrol 序列關係

orchestration 主序列（`1_MeetingMinutes/0606-test-plan-orchestration.md`）：

```
[A-D] phase-threadcontrol smoke (vm-3node-haproxy-3s3r × TiDB tuning) ~3h+
  ↓
[E] VM rebuild #2
  ↓
[F-H] phase-k8s 6-cell smoke (本 plan) ~3-4 工作天
```

## 14. phase-1 MVP appendix（2026-06-08 user 指示）

> Scope: 只跑 TiDB-unlimit 1 cell @ `k8s-3node-haproxy-3s3r-unlimit` dry-run，通過後立即停止。

### 14.1 MVP deliverable（11 件）

| # | 檔 | 內容 |
|---|---|---|
| 1 | `phase-k8s/playbooks/k8s.yml` | **raw shell** K3s server + agent install（不用 ansible/roles/，phase-isolated）|
| 2 | `phase-k8s/playbooks/tidb-k8s.yml` | **raw shell** TiDB Operator helm install + TidbCluster CR apply |
| 3 | `phase-k8s/vars/tidb-k8s-3node-haproxy-3s3r-unlimit.yml` | vars: TiDB version + replicas + storage + nodeport + haproxy frontend (resource.limits unset) |
| 4 | `phase-k8s/manifest.yaml` patch | 加 `allowed_db: [tidb]` + `allowed_topology` 加 `k8s-3node-haproxy-3s3r-unlimit` |
| 5 | `phase-k8s/expected/tidb-k8s-3node-haproxy-3s3r-unlimit.yaml` | 1 cell expected SSOT |
| 6 | `phase-k8s/expected/vm-3node-haproxy-3s3r-tidb.yaml` | VM baseline 對照 |
| 7 | `phase-k8s/dump-actual.sh` | TiDB-only dump (kubectl + TiKV /config + PD /config + wrapper env + isolation + haproxy.cfg) |
| 8 | `phase-k8s/diff-check.sh` | yq canonicalize + jq subset compare |
| 9 | `phase-k8s/compare-vm.sh` | actual vs VM baseline → compare-vm.md (allow/warn/deny field path SSOT) |
| 10 | `phase-k8s/run-k8s-suite.sh` | **DRY_RUN-only**：env validate → guard → dump-actual → diff-check → compare-vm → write .dry-run.done → STOP |
| 11 | `tests/common/lib/common.sh::write_phase_done` patch | env auto-inject (light)：可被 #10 引用寫 .dry-run.done |

**Deferred** to phase-2：CRDB/YBDB cell + limit cell + suite execute + cell-cleanup-gate + scope guards in run-vm1-suite.sh/prepare.sh + DRY_RUN flag in run.sh + gate-k8s.sh + prepare-k8s.sh + collect-k8s.sh

### 14.2 MVP 執行序列

```
[M1] commit plan (本文檔變更)
[M2] build deliverable 1-11 → commit
[M3] make new-idc-vms （✋ user 授權 1 次 VM rebuild）
[M4] ansible-playbook phase-k8s/playbooks/k8s.yml
[M5] ansible-playbook phase-k8s/playbooks/tidb-k8s.yml -e @phase-k8s/vars/tidb-k8s-3node-haproxy-3s3r-unlimit.yml
[M6] ssh root@.31 'env DRY_RUN=1 ... bash phase-k8s/run-k8s-suite.sh ...'
[M7] rsync artifact → 驗 .diff-pass + compare-vm.md → STOP
[M8] report back to user
```

### 14.3 MVP 成功條件

- [ ] `phase-k8s/playbooks/{k8s,tidb-k8s}.yml` 成功 deploy K3s + TiDB Operator + TidbCluster
- [ ] `kubectl get pods -n tidb-cluster` 顯示 3 PD + 2 TiDB + 3 TiKV 全 Ready
- [ ] NodePort `:30004` mysql connect OK
- [ ] dry-run 產生 `dry-run/actual.yaml` + `dry-run/.diff-pass` + `dry-run/compare-vm.md`
- [ ] `.dry-run.done` JSON 含 `phase=phase-k8s, result_scope=S-K8S, baseline_family=k8s, tuning_profile_id=default`
- [ ] compare-vm.md 無「絕對不允許」level diff（workload/isolation/scope/split.strategy）
- [ ] user 看到結果後確認是否進 phase-2

### 14.4 MVP 估時

| 階段 | 時間 |
|---|---|
| M2 build 11 deliverable | ~3-4h |
| M3 VM rebuild | ~35 min |
| M4-M5 K3s + TiDB deploy | ~30 min |
| M6 dry-run | ~10 min |
| M7 verify + report | ~10 min |
| **合計** | **~5-6h** (~半個工作天) |

## 13. 變更歷史

| 日期 | commit | 變更 |
|---|---|---|
| 2026-06-06 | （已 push）| 初版 1-cell smoke (Q1-Q6 拍板) |
| 2026-06-06 | （已 push）| codex v6-v9 修正 |
| 2026-06-06 | （已 push）| two-stage (dry-run + benchmark) |
| 2026-06-06 | （已 push）| codex v11-v12 修正 |
| 2026-06-07 | （已 push 643e17c）| codex v13 cosmetic (YBDB isolation probe + acceptance wording) |
| 2026-06-07 | （本 commit）| **大改**：1-cell Tier 3 → 6-cell expected/actual/diff 簡化版（user 2026-06-07 指示）。新增 TiDB/CRDB/YBDB × {limit, unlimit} matrix + `expected.yaml` SSOT + `dump-actual.sh` + `diff-check.sh` + `compare-vm.sh` + VM baseline 對照。允許 VM rebuild ×1 for K8s env。 |
| 2026-06-07 | （本 commit fixup-1, v14 review）| codex v14 changes-required 修 5 blocking + 4 non-blocking：(1) workload schema 對齊 v4.7 (warmup_sec:1200, warmup_threads:64, threads_list:[16,32,64,128], rounds:5)；(2) manifest 加 `allowed_db` + 擴 `allowed_topology` 表達 6 cell 笛卡兒積；(3) `TUNING_PROFILE: ""` → `tuning_profile_id: default`；(4) DB family swap 補 cell-cleanup-gate.sh (helm + namespace + PVC + PV + CRD + local-path FS clean)；(5) YBDB typo `enable_automatic_tablets_splits` → `enable_automatic_tablet_splitting`；NB (1) diff-check 改 canonicalize-compare (yq sort + jq subset)；(2) expected schema 補 image/version/requests/anti_affinity/pvc_bound_nodes/expected_region_count；(3) compare-vm allow/warn/deny field path SSOT 明確列；(4) 18h suite 分 3 batch 跑 (TiDB → CRDB → YBDB, 每批 user review)。 |
| 2026-06-08 | （本 commit phase-1 MVP）| **MVP scope cut + 跳過 v16 codex**（user 指示）：6-cell 規格 defer 至 phase-2；phase-1 只跑 TiDB-unlimit 1 cell dry-run；§14 新增 MVP appendix（11 deliverable + 執行序列 + 成功條件）；修 v15 blocking #1 (YBDB `enable_automatic_tablet_splitting: false` 對齊 PoC-DESIGN)、#4 (`expected_region_count` → `expected_tables`+`expected_shards_per_table`)、NB #2 (`duration_sec_per_thread` → `run_sec`)。其他 v15 issue (cleanup-gate scope/batch 圖示一致性/platform-derived 分類) defer 至 phase-2 plan iteration。 |
