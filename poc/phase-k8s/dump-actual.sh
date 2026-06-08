#!/usr/bin/env bash
# phase-k8s/dump-actual.sh — DB-aware dump for phase-k8s dry-run.
# Supports TiDB / CRDB / YBDB. Reads K8s state + DB config + wrapper env,
# emits canonical actual.yaml.
#
# Required env:
#   DB             — tidb | crdb | ybdb
#   K3S_HOST       — K3s server IP for ssh (kubectl/curl in-cluster)
#   K8S_NAMESPACE  — DB namespace
#   K8S_CLUSTER    — DB cluster/release name
#   DB_HOST        — DB SQL NodePort host
#   DB_PORT        — DB SQL NodePort port
#   OUT_DIR        — output dir for actual.yaml + raw dumps
#   TOPOLOGY       — topology id (e.g., k8s-3node-haproxy-3s3r-unlimit)
#   PHASE_NAME RESULT_SCOPE BASELINE_ELIGIBLE BASELINE_FAMILY tuning_profile_id
#
# Output:
#   $OUT_DIR/actual.yaml         — canonical yaml for diff-check.sh
#   $OUT_DIR/raw/kubectl-pods.json + kubectl-pvc.json
#   $OUT_DIR/raw/db-config.json  — DB-specific config dump
#   $OUT_DIR/raw/isolation-probe.txt

set -euo pipefail

: "${DB:?missing}"
: "${K3S_HOST:?missing}"
: "${K8S_NAMESPACE:?missing}"
: "${K8S_CLUSTER:?missing}"
: "${DB_HOST:?missing}"
: "${DB_PORT:?missing}"
: "${OUT_DIR:?missing}"
: "${TOPOLOGY:?missing}"
: "${PHASE_NAME:?missing}"
: "${RESULT_SCOPE:?missing}"
: "${BASELINE_ELIGIBLE:?missing}"
: "${BASELINE_FAMILY:?missing}"
: "${tuning_profile_id:=default}"

mkdir -p "$OUT_DIR/raw"
KUBECTL="ssh root@${K3S_HOST} k3s kubectl"

echo "[dump] K8s pods..."
$KUBECTL -n "$K8S_NAMESPACE" get pods -o json > "$OUT_DIR/raw/kubectl-pods.json"
$KUBECTL -n "$K8S_NAMESPACE" get pvc -o json > "$OUT_DIR/raw/kubectl-pvc.json"

# DB-aware label / container name / image prefix
case "$DB" in
  tidb)
    PD_LABEL='app.kubernetes.io/component=pd'
    SQL_LABEL='app.kubernetes.io/component=tidb'
    STORAGE_LABEL='app.kubernetes.io/component=tikv'
    SQL_CTNAME='tidb'
    STORAGE_CTNAME='tikv'
    IMG_PREFIX='pingcap/tidb'
    CLIENT_PROTO='mysql' ;;
  crdb)
    PD_LABEL=''
    # NB: use component=cockroachdb to exclude init Job (component=init)
    SQL_LABEL='app.kubernetes.io/component=cockroachdb'
    STORAGE_LABEL='app.kubernetes.io/component=cockroachdb'
    SQL_CTNAME='db'
    STORAGE_CTNAME='db'
    IMG_PREFIX='cockroachdb/cockroach'
    CLIENT_PROTO='postgres' ;;
  ybdb)
    PD_LABEL='app=yb-master'
    SQL_LABEL='app=yb-tserver'
    STORAGE_LABEL='app=yb-tserver'                       # YBDB merges sql + storage at tserver
    SQL_CTNAME='yb-tserver'
    STORAGE_CTNAME='yb-tserver'
    IMG_PREFIX='yugabytedb/yugabyte'
    CLIENT_PROTO='postgres' ;;
  *) echo "[dump] unknown DB=$DB" >&2; exit 1 ;;
esac

# Count pods per role
PD_COUNT=0
if [[ -n "$PD_LABEL" ]]; then
  PD_COUNT=$(jq --arg k "${PD_LABEL%=*}" --arg v "${PD_LABEL#*=}" '[.items[] | select(.metadata.labels[$k]==$v)] | length' "$OUT_DIR/raw/kubectl-pods.json")
fi
SQL_COUNT=$(jq --arg k "${SQL_LABEL%=*}" --arg v "${SQL_LABEL#*=}" '[.items[] | select(.metadata.labels[$k]==$v)] | length' "$OUT_DIR/raw/kubectl-pods.json")
STORAGE_COUNT=$(jq --arg k "${STORAGE_LABEL%=*}" --arg v "${STORAGE_LABEL#*=}" '[.items[] | select(.metadata.labels[$k]==$v)] | length' "$OUT_DIR/raw/kubectl-pods.json")

# Resource limits — pick STORAGE container's limits as canonical (TiKV / cockroachdb / yb-tserver)
RESOURCE_LIMITS=$(jq --arg ct "$STORAGE_CTNAME" '[.items[].spec.containers[] | select(.name==$ct) | .resources.limits // empty] | first // null' "$OUT_DIR/raw/kubectl-pods.json")

# Storage class / PV size — pick storage layer
STORAGE_CLASS=$(jq -r '.items[0].spec.storageClassName // "unknown"' "$OUT_DIR/raw/kubectl-pvc.json")
STORAGE_PV_SIZE=$(jq -r --arg k "${STORAGE_LABEL%=*}" --arg v "${STORAGE_LABEL#*=}" '.items[] | select(.metadata.labels[$k]==$v) | .spec.resources.requests.storage' "$OUT_DIR/raw/kubectl-pvc.json" | head -1)
PD_PV_SIZE="null"
if [[ -n "$PD_LABEL" ]]; then
  PD_PV_SIZE=$(jq -r --arg k "${PD_LABEL%=*}" --arg v "${PD_LABEL#*=}" '.items[] | select(.metadata.labels[$k]==$v) | .spec.resources.requests.storage' "$OUT_DIR/raw/kubectl-pvc.json" | head -1)
  [[ -z "$PD_PV_SIZE" ]] && PD_PV_SIZE="null"
fi

# DB image (from SQL container)
SQL_IMG=$(jq -r --arg k "${SQL_LABEL%=*}" --arg v "${SQL_LABEL#*=}" --arg ct "$SQL_CTNAME" '.items[] | select(.metadata.labels[$k]==$v) | .spec.containers[] | select(.name==$ct) | .image' "$OUT_DIR/raw/kubectl-pods.json" | head -1)
DB_VERSION=$(echo "$SQL_IMG" | sed -E 's|.*:||')

# DB-specific config dump + isolation probe
case "$DB" in
  tidb)
    echo "[dump] TiKV /config..."
    ssh root@"$K3S_HOST" "k3s kubectl -n $K8S_NAMESPACE exec -c tikv \$(k3s kubectl -n $K8S_NAMESPACE get pod -l app.kubernetes.io/component=tikv -o name | head -1) -- curl -s http://127.0.0.1:20180/config" > "$OUT_DIR/raw/tikv-config.json" 2>/dev/null || echo "{}" > "$OUT_DIR/raw/tikv-config.json"
    TIKV_READPOOL_AUTO=$(jq -r '.readpool.unified."auto-adjust-pool-size" // false' "$OUT_DIR/raw/tikv-config.json")
    echo "[dump] PD /config..."
    ssh root@"$K3S_HOST" "k3s kubectl -n $K8S_NAMESPACE exec -c pd \$(k3s kubectl -n $K8S_NAMESPACE get pod -l app.kubernetes.io/component=pd -o name | head -1) -- curl -s http://127.0.0.1:2379/pd/api/v1/config" > "$OUT_DIR/raw/pd-config.json" 2>/dev/null || echo "{}" > "$OUT_DIR/raw/pd-config.json"
    PD_MAX_REPLICAS=$(jq -r '.replication["max-replicas"] // 3' "$OUT_DIR/raw/pd-config.json")
    echo "[dump] isolation probe..."
    mysql -h "$DB_HOST" -P "$DB_PORT" -u root -e "SET SESSION transaction_isolation='READ-COMMITTED'; SET SESSION tidb_txn_mode='pessimistic'; SELECT @@transaction_isolation, @@tidb_txn_mode;" > "$OUT_DIR/raw/isolation-probe.txt" 2>&1 || true
    ISO_LEVEL=$(grep -oE 'READ-COMMITTED|REPEATABLE-READ|SERIALIZABLE' "$OUT_DIR/raw/isolation-probe.txt" | head -1 || echo "UNKNOWN")
    TXN_MODE=$(grep -oE 'pessimistic|optimistic' "$OUT_DIR/raw/isolation-probe.txt" | head -1 || echo "UNKNOWN")
    DB_CONFIG_BLOCK="$(cat <<YAML
  tidb_version: ${DB_VERSION}
  tikv_readpool_unified_auto_adjust_pool_size: ${TIKV_READPOOL_AUTO}
  pd_max_replicas: ${PD_MAX_REPLICAS}
YAML
)"
    ISO_BLOCK="$(cat <<YAML
isolation:
  level: ${ISO_LEVEL}
  txn_mode: ${TXN_MODE}
YAML
)"
    ;;
  crdb)
    echo "[dump] CRDB cluster settings + version..."
    # CRDB cluster settings (NB: setting name is kv.range_split.by_load.enabled, with dot before enabled)
    psql "postgres://root@${DB_HOST}:${DB_PORT}/defaultdb?sslmode=disable" -t -A -c "SHOW CLUSTER SETTING sql.txn.read_committed_isolation.enabled;" > "$OUT_DIR/raw/crdb-rc-enabled.txt" 2>&1 || echo "f" > "$OUT_DIR/raw/crdb-rc-enabled.txt"
    psql "postgres://root@${DB_HOST}:${DB_PORT}/defaultdb?sslmode=disable" -t -A -c "SHOW CLUSTER SETTING kv.range_split.by_load.enabled;" > "$OUT_DIR/raw/crdb-by-load.txt" 2>&1 || echo "t" > "$OUT_DIR/raw/crdb-by-load.txt"
    CRDB_RC_ENABLED=$(grep -oE '^[tf]$' "$OUT_DIR/raw/crdb-rc-enabled.txt" | head -1)
    CRDB_SPLIT_BY_LOAD=$(grep -oE '^[tf]$' "$OUT_DIR/raw/crdb-by-load.txt" | head -1)
    [[ "$CRDB_RC_ENABLED" == "t" ]] && CRDB_DEFAULT_ISO="read committed" || CRDB_DEFAULT_ISO="serializable"
    [[ "$CRDB_SPLIT_BY_LOAD" == "t" ]] && CRDB_SPLIT_BY_LOAD=true || CRDB_SPLIT_BY_LOAD=false
    CRDB_VERSION_RAW=$(echo "$SQL_IMG" | sed -E 's|.*:||')
    echo "[dump] isolation probe..."
    # default_transaction_isolation is derived from cluster setting; SHOW on root returns serializable
    # (CockroachDB forbids ALTER ROLE root SET default_transaction_isolation).
    # Use BEGIN/SHOW to probe the actual effective isolation for non-root sessions.
    psql "postgres://root@${DB_HOST}:${DB_PORT}/defaultdb?sslmode=disable" -t -A -c "SHOW default_transaction_isolation;" > "$OUT_DIR/raw/isolation-probe.txt" 2>&1 || true
    ISO_LEVEL="${CRDB_DEFAULT_ISO}"    # use cluster setting as canonical
    DB_CONFIG_BLOCK="$(cat <<YAML
  crdb_version: ${CRDB_VERSION_RAW}
  default_transaction_isolation: "${CRDB_DEFAULT_ISO}"
  kv_range_split_by_load_enabled: ${CRDB_SPLIT_BY_LOAD}
YAML
)"
    ISO_BLOCK="$(cat <<YAML
isolation:
  level: "${ISO_LEVEL}"
YAML
)"
    ;;
  ybdb)
    echo "[dump] YBDB master gflags..."
    ssh root@"$K3S_HOST" "k3s kubectl -n $K8S_NAMESPACE exec \$(k3s kubectl -n $K8S_NAMESPACE get pod -l app=yb-master -o name | head -1) -c yb-master -- yb-admin --master_addresses=yb-masters.${K8S_NAMESPACE}.svc.cluster.local:7100 get_universe_config 2>&1" > "$OUT_DIR/raw/yb-universe-config.txt" 2>&1 || true
    YB_RF=$(grep -oE 'replicationFactor[^0-9]*[0-9]+|num_replicas[^0-9]*[0-9]+' "$OUT_DIR/raw/yb-universe-config.txt" | grep -oE '[0-9]+' | head -1 || echo "3")
    # auto tablet split: read from tserver gflag
    ssh root@"$K3S_HOST" "k3s kubectl -n $K8S_NAMESPACE exec \$(k3s kubectl -n $K8S_NAMESPACE get pod -l app=yb-tserver -o name | head -1) -c yb-tserver -- curl -s http://127.0.0.1:9000/varz?raw=1 2>&1 | grep -E '^--(enable_automatic_tablet_splitting|ysql_num_shards_per_tserver|yb_enable_read_committed_isolation)='" > "$OUT_DIR/raw/yb-tserver-varz.txt" 2>&1 || true
    YB_AUTO_SPLIT=$(grep -oE '^--enable_automatic_tablet_splitting=\w+' "$OUT_DIR/raw/yb-tserver-varz.txt" | sed -E 's/.*=//' | head -1)
    [[ -z "$YB_AUTO_SPLIT" ]] && YB_AUTO_SPLIT="unknown"
    YB_READ_COMMITTED=$(grep -oE '^--yb_enable_read_committed_isolation=\w+' "$OUT_DIR/raw/yb-tserver-varz.txt" | sed -E 's/.*=//' | head -1)
    [[ -z "$YB_READ_COMMITTED" ]] && YB_READ_COMMITTED="unknown"
    YB_VERSION_RAW=$(echo "$SQL_IMG" | sed -E 's|.*:||')
    echo "[dump] isolation probe..."
    psql "postgres://yugabyte@${DB_HOST}:${DB_PORT}/yugabyte" -c "SHOW transaction_isolation; SHOW default_transaction_isolation;" > "$OUT_DIR/raw/isolation-probe.txt" 2>&1 || true
    ISO_LEVEL=$(grep -oE 'read committed|repeatable read|serializable' "$OUT_DIR/raw/isolation-probe.txt" | head -1 || echo "UNKNOWN")
    DB_CONFIG_BLOCK="$(cat <<YAML
  ybdb_version: ${YB_VERSION_RAW}
  replication_factor: ${YB_RF}
  enable_automatic_tablet_splitting: ${YB_AUTO_SPLIT}
  yb_enable_read_committed_isolation: ${YB_READ_COMMITTED}
YAML
)"
    ISO_BLOCK="$(cat <<YAML
isolation:
  level: "${ISO_LEVEL}"
YAML
)"
    ;;
esac

echo "[dump] workload env..."
WAREHOUSES="${WAREHOUSES:-128}"
THREADS_LIST="${THREADS_LIST:-16,32,64,128}"
ROUNDS="${ROUNDS:-5}"
WARMUP_THREADS="${WARMUP_THREADS:-64}"
WARMUP_SEC="${WARMUP_SEC:-1200}"
RUN_SEC="${RUN_SEC:-300}"

cat > "$OUT_DIR/actual.yaml" <<EOF
db: ${DB}
topology: ${TOPOLOGY}
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
    sql: ${SQL_COUNT}
    storage: ${STORAGE_COUNT}
  resource_limits: ${RESOURCE_LIMITS}
  storage_class: ${STORAGE_CLASS}
  pv_size:
    pd: ${PD_PV_SIZE}
    storage: ${STORAGE_PV_SIZE}
  db_image_prefix: ${IMG_PREFIX}
db_config:
${DB_CONFIG_BLOCK}
workload:
  warehouses: ${WAREHOUSES}
  threads_list: [$(echo "$THREADS_LIST" | sed 's/,/, /g')]
  rounds: ${ROUNDS}
  warmup_threads: ${WARMUP_THREADS}
  warmup_sec: ${WARMUP_SEC}
  run_sec: ${RUN_SEC}
${ISO_BLOCK}
network:
  nodeport: ${DB_PORT}
  client_proto: ${CLIENT_PROTO}
  haproxy_backends: 0
split:
  strategy: ${DB}_split_placeholder
EOF

echo "[dump] OK → $OUT_DIR/actual.yaml"
