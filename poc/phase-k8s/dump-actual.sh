#!/usr/bin/env bash
# phase-k8s/dump-actual.sh — TiDB-only dump for phase-1 MVP dry-run.
# Reads K8s state + DB config + wrapper env, emits canonical actual.yaml.
# Called by run-k8s-suite.sh inside DRY_RUN=1 branch.
#
# Required env:
#   K3S_HOST       — K3s server IP for kubectl/curl (e.g., 172.24.40.32)
#   K8S_NAMESPACE  — TidbCluster namespace (e.g., tidb-cluster)
#   K8S_CLUSTER    — TidbCluster name (e.g., tidb-poc)
#   TIDB_HOST      — TiDB SQL NodePort host
#   TIDB_PORT      — TiDB SQL NodePort port (default 30004)
#   OUT_DIR        — output dir for actual.yaml + raw dumps
#   PHASE_NAME RESULT_SCOPE BASELINE_ELIGIBLE BASELINE_FAMILY tuning_profile_id
#
# Output:
#   $OUT_DIR/actual.yaml         — canonical yaml for diff-check.sh
#   $OUT_DIR/raw/kubectl-pods.json
#   $OUT_DIR/raw/tikv-config.json
#   $OUT_DIR/raw/pd-config.json
#   $OUT_DIR/raw/tidb-vars.txt
#   $OUT_DIR/raw/isolation-probe.txt

set -euo pipefail

: "${K3S_HOST:?missing}"
: "${K8S_NAMESPACE:?missing}"
: "${K8S_CLUSTER:?missing}"
: "${TIDB_HOST:?missing}"
: "${TIDB_PORT:=30004}"
: "${OUT_DIR:?missing}"
: "${PHASE_NAME:?missing}"
: "${RESULT_SCOPE:?missing}"
: "${BASELINE_ELIGIBLE:?missing}"
: "${BASELINE_FAMILY:?missing}"
: "${tuning_profile_id:=default}"

mkdir -p "$OUT_DIR/raw"
KUBECTL="ssh root@${K3S_HOST} k3s kubectl"

echo "[dump] K8s pods..."
$KUBECTL -n "$K8S_NAMESPACE" get pods -o json > "$OUT_DIR/raw/kubectl-pods.json"

PD_COUNT=$(jq '[.items[] | select(.metadata.labels["app.kubernetes.io/component"]=="pd")] | length' "$OUT_DIR/raw/kubectl-pods.json")
TIDB_COUNT=$(jq '[.items[] | select(.metadata.labels["app.kubernetes.io/component"]=="tidb")] | length' "$OUT_DIR/raw/kubectl-pods.json")
TIKV_COUNT=$(jq '[.items[] | select(.metadata.labels["app.kubernetes.io/component"]=="tikv")] | length' "$OUT_DIR/raw/kubectl-pods.json")

# unlimit cell: limits unset (null). limit cell: limits set.
RESOURCE_LIMITS=$(jq '[.items[].spec.containers[].resources.limits // empty] | first // null' "$OUT_DIR/raw/kubectl-pods.json")

# storage class / pv size
$KUBECTL -n "$K8S_NAMESPACE" get pvc -o json > "$OUT_DIR/raw/kubectl-pvc.json"
PD_PV_SIZE=$(jq -r '.items[] | select(.metadata.labels["app.kubernetes.io/component"]=="pd") | .spec.resources.requests.storage' "$OUT_DIR/raw/kubectl-pvc.json" | head -1)
TIKV_PV_SIZE=$(jq -r '.items[] | select(.metadata.labels["app.kubernetes.io/component"]=="tikv") | .spec.resources.requests.storage' "$OUT_DIR/raw/kubectl-pvc.json" | head -1)
STORAGE_CLASS=$(jq -r '.items[0].spec.storageClassName' "$OUT_DIR/raw/kubectl-pvc.json")

# image — TiDB pod 有 2 container (slowlog alpine + tidb pingcap); 過濾 name=tidb
TIDB_IMG=$(jq -r '.items[] | select(.metadata.labels["app.kubernetes.io/component"]=="tidb") | .spec.containers[] | select(.name=="tidb") | .image' "$OUT_DIR/raw/kubectl-pods.json" | head -1)
TIDB_VERSION=$(echo "$TIDB_IMG" | sed -E 's|.*:||')

echo "[dump] TiKV /config..."
ssh root@"$K3S_HOST" "k3s kubectl -n $K8S_NAMESPACE exec -c tikv \$(k3s kubectl -n $K8S_NAMESPACE get pod -l app.kubernetes.io/component=tikv -o name | head -1) -- curl -s http://127.0.0.1:20180/config" > "$OUT_DIR/raw/tikv-config.json" 2>/dev/null || echo "{}" > "$OUT_DIR/raw/tikv-config.json"

TIKV_READPOOL_AUTO=$(jq -r '.readpool.unified."auto-adjust-pool-size" // false' "$OUT_DIR/raw/tikv-config.json")

echo "[dump] PD /config..."
ssh root@"$K3S_HOST" "k3s kubectl -n $K8S_NAMESPACE exec -c pd \$(k3s kubectl -n $K8S_NAMESPACE get pod -l app.kubernetes.io/component=pd -o name | head -1) -- curl -s http://127.0.0.1:2379/pd/api/v1/config" > "$OUT_DIR/raw/pd-config.json" 2>/dev/null || echo "{}" > "$OUT_DIR/raw/pd-config.json"

PD_MAX_REPLICAS=$(jq -r '.replication["max-replicas"] // 3' "$OUT_DIR/raw/pd-config.json")

echo "[dump] TiDB SHOW VARIABLES..."
mysql -h "$TIDB_HOST" -P "$TIDB_PORT" -u root -e "SHOW VARIABLES LIKE 'transaction_isolation'; SHOW VARIABLES LIKE 'tidb_txn_mode';" > "$OUT_DIR/raw/tidb-vars.txt" 2>&1 || true

echo "[dump] isolation probe..."
mysql -h "$TIDB_HOST" -P "$TIDB_PORT" -u root -e "SET SESSION transaction_isolation='READ-COMMITTED'; SET SESSION tidb_txn_mode='pessimistic'; SELECT @@transaction_isolation, @@tidb_txn_mode;" > "$OUT_DIR/raw/isolation-probe.txt" 2>&1 || true

ISO_LEVEL=$(grep -oE 'READ-COMMITTED|REPEATABLE-READ|SERIALIZABLE' "$OUT_DIR/raw/isolation-probe.txt" | head -1 || echo "UNKNOWN")
TXN_MODE=$(grep -oE 'pessimistic|optimistic' "$OUT_DIR/raw/isolation-probe.txt" | head -1 || echo "UNKNOWN")

echo "[dump] workload env..."
# Wrapper env passed via env vars (TPCC_* / DB_*).
WAREHOUSES="${WAREHOUSES:-128}"
THREADS_LIST="${THREADS_LIST:-16,32,64,128}"
ROUNDS="${ROUNDS:-5}"
WARMUP_THREADS="${WARMUP_THREADS:-64}"
WARMUP_SEC="${WARMUP_SEC:-1200}"
RUN_SEC="${RUN_SEC:-300}"

cat > "$OUT_DIR/actual.yaml" <<EOF
db: tidb
topology: ${TOPOLOGY:-k8s-3node-haproxy-3s3r-unlimit}
phase_env:
  PHASE_NAME: ${PHASE_NAME}
  RESULT_SCOPE: ${RESULT_SCOPE}
  BASELINE_ELIGIBLE: ${BASELINE_ELIGIBLE}
  BASELINE_FAMILY: ${BASELINE_FAMILY}
  tuning_profile_id: ${tuning_profile_id}
k8s:
  namespace: ${K8S_NAMESPACE}
  cluster_name: ${K8S_CLUSTER}
  pod_replicas:
    pd: ${PD_COUNT}
    tidb: ${TIDB_COUNT}
    tikv: ${TIKV_COUNT}
  resource_limits: ${RESOURCE_LIMITS}
  storage_class: ${STORAGE_CLASS}
  pv_size:
    pd: ${PD_PV_SIZE}
    tikv: ${TIKV_PV_SIZE}
  db_image_prefix: $(echo "$TIDB_IMG" | sed -E 's|:.*||')
db_config:
  tidb_version: ${TIDB_VERSION}
  tikv_readpool_unified_auto_adjust_pool_size: ${TIKV_READPOOL_AUTO}
  pd_max_replicas: ${PD_MAX_REPLICAS}
workload:
  warehouses: ${WAREHOUSES}
  threads_list: [$(echo "$THREADS_LIST" | sed 's/,/, /g')]
  rounds: ${ROUNDS}
  warmup_threads: ${WARMUP_THREADS}
  warmup_sec: ${WARMUP_SEC}
  run_sec: ${RUN_SEC}
isolation:
  level: ${ISO_LEVEL}
  txn_mode: ${TXN_MODE}
network:
  nodeport: ${TIDB_PORT}
  client_proto: mysql
  haproxy_backends: 0
split:
  strategy: tidb_explicit_9table
  source_ref: tests/common/prepare.sh:134-144
  expected_tables: 9
  expected_shards_per_table: 3
EOF

echo "[dump] OK → $OUT_DIR/actual.yaml"
