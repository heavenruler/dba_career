#!/usr/bin/env bash
# Dry-run confirm gate for vm-3node (deploy 後、prepare 前的人工 review anchor).
#
# Per PoC-DESIGN §6.3.2.3: deploy 完 cluster topology / RF / iso preset / health
# 全部 dump 出來，由人工 review 後加 EXECUTE=1 才放行進 prepare。
#
# Usage (runs on the TPC-C client / .31):
#   dry-run-confirm.sh --db <tidb|crdb|ybdb> --sub-topology <1s1r|1s3r|3s1r|3s3r> \
#                      --iso <rc|rr|strict>  --db-host <ip> --ts <timestamp>
#
# Env (Makefile-provided):
#   TPCC_ARTIFACTS (default /tmp/poc-tpcc/artifacts)
#   TIDB/CRDB/YBDB_HOST/PORT/USER  (Makefile passes these)
#
# Exit codes:
#   0 — all checks passed; .dry-run.done written with all_pass=true
#   1 — any check failed; .dry-run.done written with all_pass=false
#
# This script does NOT honor EXECUTE=1; that is enforced by the Makefile gate
# (which decides whether to run prepare phase after this script exits 0).

set -euo pipefail
SELF=$(cd "$(dirname "$0")" && pwd)
source "$SELF/lib/common.sh"

DB="" SUB="" ISO="" DB_HOST="" TS=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --db)             DB=$2; shift 2 ;;
    --sub-topology)   SUB=$2; shift 2 ;;
    --iso)            ISO=$2; shift 2 ;;
    --db-host)        DB_HOST=$2; shift 2 ;;
    --ts)             TS=$2; shift 2 ;;
    *) die "unknown arg: $1" ;;
  esac
done
[[ -n "$DB" && -n "$SUB" && -n "$ISO" && -n "$DB_HOST" && -n "$TS" ]] || die "missing required args"

case "$SUB" in 1s1r|1s3r|3s1r|3s3r|haproxy-3s3r) ;; *) die "invalid sub-topology: $SUB" ;; esac
case "$DB"  in tidb|crdb|ybdb)      ;; *) die "invalid db: $DB" ;; esac

# Expected RF derived from sub-topology suffix:
case "$SUB" in
  1s1r|3s1r) EXPECTED_RF=1 ;;
  1s3r|3s3r|haproxy-3s3r) EXPECTED_RF=3 ;;
esac

TOPOLOGY="vm-3node-$SUB"
: "${TPCC_ARTIFACTS:=/tmp/poc-tpcc/artifacts}"
ROOT=$(artifact_dir "$DB" "$TOPOLOGY" "$ISO" "$TS")
mkdir -p "$ROOT/dry-run"
flock_phase "$ROOT" "dry-run"

DRY="$ROOT/dry-run"
ALL_PASS=true
FAILS=()

# HAProxy 等 proxy 拓樸：db-host 是 proxy，沒 yb-admin；yb-admin 必須走實 cluster member。
case "$SUB" in
  haproxy-*) CLUSTER_HOST="172.24.40.32" ;;
  *)         CLUSTER_HOST="$DB_HOST"     ;;
esac

info "dry-run-confirm root: $ROOT  (sub=$SUB rf=$EXPECTED_RF iso=$ISO db-host=$DB_HOST cluster-host=$CLUSTER_HOST)"

remote() {
  ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=5 "root@$CLUSTER_HOST" "$@"
}

# --- 1. cluster topology dump ------------------------------------------------
case "$DB" in
  tidb)
    require_cmd mysql
    remote 'PATH=$PATH:/root/.tiup/bin /root/.tiup/bin/tiup cluster display tpcc-tidb-vm3 2>&1' \
      > "$DRY/cluster-topology.txt" || true
    ;;
  crdb)
    require_cmd psql
    remote '/usr/local/bin/cockroach node status --insecure --host=127.0.0.1:26257 --format=tsv 2>&1' \
      > "$DRY/cluster-topology.txt" || true
    ;;
  ybdb)
    require_cmd ysqlsh
    remote '/opt/yugabyte/bin/yb-admin --master_addresses=172.24.40.32:7100,172.24.40.33:7100,172.24.40.34:7100 list_all_tablet_servers 2>&1' \
      > "$DRY/cluster-topology.txt" || true
    ;;
esac

NODE_COUNT=$(grep -cE '(Up|172\.24\.40\.(32|33|34))' "$DRY/cluster-topology.txt" 2>/dev/null || echo 0)
if [[ "${NODE_COUNT:-0}" -lt 3 ]]; then
  warn "cluster topology shows < 3 nodes (node_count=$NODE_COUNT)"
  ALL_PASS=false
  FAILS+=("topology-nodes<3")
fi

# --- 1b. (TiDB) TiKV storage layer hard gate (2026-05-29 race fix) ----------
# 原 NODE_COUNT 只計符合 IP 的行數，TiKV Down 也會被當成 1 個 node 算進去 → gate 過鬆。
# 改在這裡顯式驗 TiKV up count == 3，否則 fail-closed（playbook 雖已加 wait task，
# 但 dry-run gate 也要二次防護，未來 cluster 漂走也能抓住）。
# tiup cluster display 欄位順序：$1=ID $2=Role $3=Host $4=Ports $5=OS/Arch $6=Status $7=Data Dir $8=Deploy Dir
TIKV_UP_COUNT=n/a
if [[ "$DB" == "tidb" ]]; then
  TIKV_UP_COUNT=$(awk '$2=="tikv" && $6=="Up"' "$DRY/cluster-topology.txt" 2>/dev/null | wc -l | tr -d ' ')
  if [[ "${TIKV_UP_COUNT:-0}" -lt 3 ]]; then
    warn "TiKV stores not all Up (count=$TIKV_UP_COUNT, expected 3)"
    ALL_PASS=false
    FAILS+=("tikv-stores-not-all-up:$TIKV_UP_COUNT/3")
  fi
fi

# --- 1c. (TiDB) actual peer count per region == RF expected (Fix #11) -------
# 原 §2 只驗 PD config max-replicas（reports what was SET），沒驗 actual placement
# （what PD did）。2026-05-30 實測：max-replicas=3 但 replica-schedule-limit=0 →
# PD 不補 replica → 每 region peer_count=1，cluster 實效 RF=1 偽裝 RF=3。
# 此 gate 直接查每 region 的 peer count，min/max 都要 == EXPECTED_RF。
# region 取樣含 cluster 內所有（包含 mysql.* / information_schema 等 system table）；
# tpcc DB 尚未 prepare，因此這是 system regions 的 placement 驗證。
ACTUAL_RF_MIN=n/a
ACTUAL_RF_MAX=n/a
ACTUAL_RF_REGIONS=n/a
if [[ "$DB" == "tidb" ]]; then
  for i in $(seq 1 12); do
    read -r rfmin rfmax cnt < <(
      mysql -h "$DB_HOST" -P "${TIDB_PORT:-4000}" -u "${TIDB_USER:-root}" -B -N -e \
        "SELECT IFNULL(MIN(pc),0), IFNULL(MAX(pc),0), COUNT(*) FROM (
           SELECT COUNT(*) AS pc FROM information_schema.tikv_region_peers GROUP BY REGION_ID
         ) p" 2>/dev/null || echo "0 0 0"
    )
    if [[ "$rfmin" == "$EXPECTED_RF" && "$rfmax" == "$EXPECTED_RF" ]]; then break; fi
    sleep 5
  done
  ACTUAL_RF_MIN="${rfmin:-n/a}"
  ACTUAL_RF_MAX="${rfmax:-n/a}"
  ACTUAL_RF_REGIONS="${cnt:-n/a}"
  if [[ "$ACTUAL_RF_MIN" != "$EXPECTED_RF" || "$ACTUAL_RF_MAX" != "$EXPECTED_RF" ]]; then
    warn "RF actual peer count mismatch: expected=$EXPECTED_RF min=$ACTUAL_RF_MIN max=$ACTUAL_RF_MAX regions=$ACTUAL_RF_REGIONS (PD replica-schedule-limit may be 0)"
    ALL_PASS=false
    FAILS+=("rf-actual-mismatch:min=$ACTUAL_RF_MIN/max=$ACTUAL_RF_MAX/expected=$EXPECTED_RF")
  fi
  echo "actual-rf-min       = $ACTUAL_RF_MIN" >> "$DRY/replication-factor.txt"
  echo "actual-rf-max       = $ACTUAL_RF_MAX" >> "$DRY/replication-factor.txt"
  echo "actual-rf-regions   = $ACTUAL_RF_REGIONS" >> "$DRY/replication-factor.txt"
fi

# CRDB parity (Fix #11 對應): zone config 報的是 SET，allocator 收斂後實際 placement 才是真相
# 查每 range 的 replica array length，min/max 都要 == EXPECTED_RF。
# crdb_internal.ranges_no_leases.replicas 是 array of store IDs；ARRAY_LENGTH 即 RF。
# 大 cluster 取所有 ranges 可能上萬 row，這裡限縮 system ranges only（sub_topology
# deploy 完還沒 prepare 過 tpcc，與 TiDB 同步邏輯：驗 system placement）。
if [[ "$DB" == "crdb" ]]; then
  for i in $(seq 1 12); do
    out=$(/usr/local/bin/cockroach sql --insecure --host="$DB_HOST":"${CRDB_PORT:-26257}" --format=tsv -e \
      "SELECT IFNULL(MIN(ARRAY_LENGTH(replicas, 1)), 0) AS rfmin,
              IFNULL(MAX(ARRAY_LENGTH(replicas, 1)), 0) AS rfmax,
              COUNT(*) AS cnt
       FROM crdb_internal.ranges_no_leases" 2>/dev/null | tail -1 || echo "0	0	0")
    rfmin=$(echo "$out" | awk -F'\t' '{print $1}')
    rfmax=$(echo "$out" | awk -F'\t' '{print $2}')
    cnt=$(echo "$out"   | awk -F'\t' '{print $3}')
    if [[ "$rfmin" == "$EXPECTED_RF" && "$rfmax" == "$EXPECTED_RF" ]]; then break; fi
    sleep 5
  done
  ACTUAL_RF_MIN="${rfmin:-n/a}"
  ACTUAL_RF_MAX="${rfmax:-n/a}"
  ACTUAL_RF_REGIONS="${cnt:-n/a}"
  if [[ "$ACTUAL_RF_MIN" != "$EXPECTED_RF" || "$ACTUAL_RF_MAX" != "$EXPECTED_RF" ]]; then
    warn "RF actual replica count mismatch: expected=$EXPECTED_RF min=$ACTUAL_RF_MIN max=$ACTUAL_RF_MAX ranges=$ACTUAL_RF_REGIONS (CRDB allocator 未收斂或 zone config 未生效)"
    ALL_PASS=false
    FAILS+=("rf-actual-mismatch:min=$ACTUAL_RF_MIN/max=$ACTUAL_RF_MAX/expected=$EXPECTED_RF")
  fi
  echo "actual-rf-min       = $ACTUAL_RF_MIN" >> "$DRY/replication-factor.txt"
  echo "actual-rf-max       = $ACTUAL_RF_MAX" >> "$DRY/replication-factor.txt"
  echo "actual-rf-ranges    = $ACTUAL_RF_REGIONS" >> "$DRY/replication-factor.txt"
fi

# --- 2. replication-factor dump ---------------------------------------------
case "$DB" in
  tidb)
    PORT="${TIDB_PORT:-4000}"; USER="${TIDB_USER:-root}"
    mysql -h "$DB_HOST" -P "$PORT" -u "$USER" -B -N -e \
      "SELECT VALUE FROM information_schema.CLUSTER_CONFIG WHERE TYPE='pd' AND \`KEY\`='replication.max-replicas' LIMIT 1" \
      > "$DRY/replication-factor.txt" 2>&1 || true
    ACTUAL_RF=$(tr -d ' \n\r' < "$DRY/replication-factor.txt" 2>/dev/null || echo "?")
    ;;
  crdb)
    PORT="${CRDB_PORT:-26257}"; USER="${CRDB_USER:-root}"
    remote "/usr/local/bin/cockroach sql --insecure --host=127.0.0.1:26257 --format=tsv -e \"SHOW ZONE CONFIGURATION FROM RANGE default\"" \
      > "$DRY/replication-factor.txt" 2>&1 || true
    ACTUAL_RF=$(grep -oE 'num_replicas = [0-9]+' "$DRY/replication-factor.txt" 2>/dev/null | awk '{print $NF}' | head -1)
    ACTUAL_RF=${ACTUAL_RF:-?}
    ;;
  ybdb)
    remote '/opt/yugabyte/bin/yb-admin --master_addresses=172.24.40.32:7100,172.24.40.33:7100,172.24.40.34:7100 get_universe_config 2>&1' \
      > "$DRY/replication-factor.txt" || true
    # YB universe config JSON 是 camelCase ("numReplicas":N)，不是 snake_case；
    # grep 失敗時 set -euo pipefail 會炸 — 用 || echo 兜底避免提前 exit。
    ACTUAL_RF=$(grep -oE '"numReplicas"\s*:\s*[0-9]+|"replication_factor"\s*:\s*[0-9]+' "$DRY/replication-factor.txt" 2>/dev/null | grep -oE '[0-9]+' | head -1 || echo "?")
    ACTUAL_RF=${ACTUAL_RF:-?}
    ;;
esac

if [[ "$ACTUAL_RF" != "$EXPECTED_RF" ]]; then
  warn "RF mismatch (expected=$EXPECTED_RF actual=$ACTUAL_RF)"
  ALL_PASS=false
  FAILS+=("rf-mismatch:expected=$EXPECTED_RF/actual=$ACTUAL_RF")
fi

# --- 2b. (HAProxy variants) backend health gate (F-B) -----------------------
# 取自 haproxy.cfg.j2 加的 :8404/stats;csv endpoint。CSV 第 1 欄 pxname、第 2 欄
# svname、第 18 欄 status。filter pxname=db_nodes 且 svname=node1/node2/node3，
# count status==UP 必須 == 3，否則 fail-closed（HAProxy round-robin 沒法輪到 down
# 的 backend，跑 suite 等於浪費）。
HAPROXY_BACKENDS_UP=n/a
if [[ "$SUB" =~ ^haproxy- ]]; then
  HAPROXY_HOST=${HAPROXY_HOST:-172.24.47.20}
  HAPROXY_STATS_URL="http://${HAPROXY_HOST}:8404/stats;csv"
  HAPROXY_STAT_FILE="$DRY/haproxy-backends.csv"
  for i in $(seq 1 6); do
    if curl -fs --max-time 5 "$HAPROXY_STATS_URL" > "$HAPROXY_STAT_FILE" 2>/dev/null; then
      break
    fi
    sleep 5
  done
  if [[ ! -s "$HAPROXY_STAT_FILE" ]]; then
    warn "HAProxy stats endpoint unreachable at $HAPROXY_STATS_URL (deploy may have failed to render F-B stats frontend)"
    ALL_PASS=false
    FAILS+=("haproxy-stats-unreachable")
  else
    HAPROXY_BACKENDS_UP=$(awk -F',' 'NR>1 && $1=="db_nodes" && $2 ~ /^node[0-9]+$/ && $18=="UP" {n++} END {print n+0}' "$HAPROXY_STAT_FILE")
    HAPROXY_BACKENDS_TOTAL=$(awk -F',' 'NR>1 && $1=="db_nodes" && $2 ~ /^node[0-9]+$/ {n++} END {print n+0}' "$HAPROXY_STAT_FILE")
    if [[ "$HAPROXY_BACKENDS_UP" != "3" ]]; then
      warn "HAProxy backends not all UP: up=$HAPROXY_BACKENDS_UP/total=$HAPROXY_BACKENDS_TOTAL (expected up=3)"
      ALL_PASS=false
      FAILS+=("haproxy-backends-not-all-up:$HAPROXY_BACKENDS_UP/3")
    fi
  fi
fi

# --- 3. cluster-health probe -------------------------------------------------
case "$DB" in
  tidb)
    mysql -h "$DB_HOST" -P "${TIDB_PORT:-4000}" -u "${TIDB_USER:-root}" \
      -e "SELECT 1 AS health" > "$DRY/cluster-health.txt" 2>&1 || ALL_PASS=false
    ;;
  crdb)
    /usr/local/bin/cockroach sql --insecure --host="$DB_HOST":"${CRDB_PORT:-26257}" -e "SELECT 1 AS health" \
      > "$DRY/cluster-health.txt" 2>&1 || ALL_PASS=false
    ;;
  ybdb)
    ysqlsh -h "$DB_HOST" -p "${YBDB_PORT:-5433}" -U "${YBDB_USER:-yugabyte}" -d yugabyte \
      -c "SELECT 1 AS health" > "$DRY/cluster-health.txt" 2>&1 || ALL_PASS=false
    ;;
esac
grep -qE '^(1|health|---|[[:space:]]*1[[:space:]]*$)' "$DRY/cluster-health.txt" 2>/dev/null \
  || { ALL_PASS=false; FAILS+=("cluster-health-no-row"); }

# --- 4. iso preset probe (against default DB, since tpcc not created yet) ----
# Use the same conn-params + transaction-isolation expectation as gate-isolation.sh,
# but connect to default DB (mysql / defaultdb / yugabyte) since prepare hasn't run.
ISO_CONN_PARAMS=$(get_conn_params "$DB" "$ISO")
EXPECTED_ISO=$(expected_iso "$DB" "$ISO")
case "$DB" in
  tidb)
    if [[ "$ISO" == "rc" ]]; then tidb_iso="READ-COMMITTED"; else tidb_iso="REPEATABLE-READ"; fi
    mysql -h "$DB_HOST" -P "${TIDB_PORT:-4000}" -u "${TIDB_USER:-root}" \
      -e "SET SESSION transaction_isolation='${tidb_iso}'; SET SESSION tidb_txn_mode='pessimistic'; BEGIN; SELECT @@transaction_isolation AS transaction_isolation, @@tidb_txn_mode AS tidb_txn_mode; COMMIT;" \
      > "$DRY/iso-preset.txt" 2>&1 || true
    ACTUAL_ISO=$(awk 'NR==2 {print $1}' "$DRY/iso-preset.txt")
    ;;
  crdb)
    psql "postgres://${CRDB_USER:-root}@${DB_HOST}:${CRDB_PORT:-26257}/defaultdb?${ISO_CONN_PARAMS}" \
      -v ON_ERROR_STOP=1 -At -c "SHOW transaction_isolation" \
      > "$DRY/iso-preset.txt" 2>&1 || true
    ACTUAL_ISO=$(grep -E '^(read committed|repeatable read|serializable)$' "$DRY/iso-preset.txt" | tail -1)
    ;;
  ybdb)
    # YB triple gate active layer: SHOW transaction_isolation + yb_get_effective_transaction_isolation_level()
    # 舊 SHOW yb_effective_transaction_isolation_level 已 deprecated。
    psql "postgres://${YBDB_USER:-yugabyte}@${DB_HOST}:${YBDB_PORT:-5433}/yugabyte?${ISO_CONN_PARAMS}" \
      -v ON_ERROR_STOP=1 -At \
      -c "SHOW transaction_isolation" \
      -c "SELECT yb_get_effective_transaction_isolation_level()" \
      > "$DRY/iso-preset.txt" 2>&1 || true
    ACTUAL_ISO=$(sed -n '1p' "$DRY/iso-preset.txt")
    YB_EFFECTIVE=$(sed -n '2p' "$DRY/iso-preset.txt")
    if [[ "${YB_EFFECTIVE:-}" != "$EXPECTED_ISO" ]]; then
      warn "YBDB effective iso mismatch (expected=$EXPECTED_ISO effective=${YB_EFFECTIVE:-N/A}) — tserver gflag may be off"
      ALL_PASS=false
      FAILS+=("yb-effective-iso-mismatch")
    fi
    ;;
esac

if [[ "${ACTUAL_ISO:-}" != "$EXPECTED_ISO" ]]; then
  warn "iso preset mismatch (expected=$EXPECTED_ISO actual=${ACTUAL_ISO:-N/A})"
  ALL_PASS=false
  FAILS+=("iso-mismatch:expected=$EXPECTED_ISO/actual=${ACTUAL_ISO:-N/A}")
fi

# --- 4b. (YBDB only) cluster health: master raft + tserver heartbeat --------
# yugabyted 對 RF=1 cell 只起 1 master raft（.32 LEADER），對 RF=3 cell 起 3 masters。
# tserver 的靜態 --tserver_master_addrs 只需含至少 1 個現役 master 即可 bootstrap
# heartbeat；後續 master quorum 由 heartbeat response 動態學到。
# Gate：(1) master raft 數 == EXPECTED_RF，全 ALIVE；(2) 3 tservers 全 ALIVE
# heartbeating；(3) 每個 tserver cmdline 至少含 1 個 raft 中 master。
YBDB_CLUSTER_HEALTHY=n/a
if [[ "$DB" == "ybdb" ]]; then
  CLUSTER_REPORT="$DRY/master-addrs-consistency.txt"
  : > "$CLUSTER_REPORT"
  YB_ADMIN="/opt/yugabyte/bin/yb-admin --master_addresses=172.24.40.32:7100,172.24.40.33:7100,172.24.40.34:7100"
  HEALTHY=true

  # (1) master raft membership — header line 跳過，count ALIVE 行
  masters_raw=$(ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 \
                root@172.24.40.32 "$YB_ADMIN list_all_masters" 2>/dev/null | tail -n +2)
  masters_alive=$(echo "$masters_raw" | grep -c "ALIVE")
  masters_endpoints=$(echo "$masters_raw" | awk '/ALIVE/ {print $2}' | tr '\n' ',' | sed 's/,$//')
  echo "master_raft_alive=$masters_alive expected_rf=$EXPECTED_RF endpoints=$masters_endpoints" >> "$CLUSTER_REPORT"
  if [[ "$masters_alive" != "$EXPECTED_RF" ]]; then
    HEALTHY=false
    FAILS+=("ybdb-master-raft-mismatch:alive=$masters_alive/expected=$EXPECTED_RF")
  fi

  # (2) tservers heartbeat health — 3 全 ALIVE
  tservers_alive=$(ssh -o ConnectTimeout=10 root@172.24.40.32 \
                   "$YB_ADMIN list_all_tablet_servers" 2>/dev/null | tail -n +2 | grep -c "ALIVE")
  echo "tservers_alive=$tservers_alive expected=3" >> "$CLUSTER_REPORT"
  if [[ "$tservers_alive" != "3" ]]; then
    HEALTHY=false
    FAILS+=("ybdb-tservers-not-all-alive:$tservers_alive/3")
  fi

  # (3) 每 tserver cmdline 至少含 1 個 raft master endpoint
  for h in 172.24.40.32 172.24.40.33 172.24.40.34; do
    list=$(ssh -o ConnectTimeout=5 "root@$h" \
              'tr "\0" " " < /proc/$(pgrep -x yb-tserver)/cmdline 2>/dev/null | grep -oE "tserver_master_addrs=[^ ]*"' \
           2>/dev/null | sed -E 's/.*=//')
    found=false
    IFS=',' read -ra ep_arr <<< "$masters_endpoints"
    for ep in "${ep_arr[@]}"; do
      [[ -n "$ep" && "$list" == *"$ep"* ]] && { found=true; break; }
    done
    if $found; then
      echo "host=$h tserver_master_addrs=$list has_raft_master=true" >> "$CLUSTER_REPORT"
    else
      HEALTHY=false
      FAILS+=("ybdb-tserver-static-no-raft-master:$h")
      echo "host=$h tserver_master_addrs=$list has_raft_master=FALSE" >> "$CLUSTER_REPORT"
    fi
  done

  if $HEALTHY; then
    YBDB_CLUSTER_HEALTHY=true
  else
    YBDB_CLUSTER_HEALTHY=false
    ALL_PASS=false
    warn "YBDB cluster health gate FAILED — see $CLUSTER_REPORT"
    cat "$CLUSTER_REPORT" >&2
  fi
fi

# --- 5. write expected-vs-actual summary + .dry-run.done --------------------
{
  echo "=== dry-run gate $TOPOLOGY / $DB / $ISO ==="
  echo "expected-node-count = 3        actual = $NODE_COUNT"
  echo "expected-rf (config) = $EXPECTED_RF        actual = $ACTUAL_RF"
  echo "actual-rf-peer-min  = $ACTUAL_RF_MIN  (TiDB/CRDB; per-region/range replica count)"
  echo "actual-rf-peer-max  = $ACTUAL_RF_MAX  (TiDB/CRDB)"
  echo "actual-rf-regions   = $ACTUAL_RF_REGIONS  (TiDB/CRDB; total regions/ranges sampled)"
  echo "haproxy-backends-up = $HAPROXY_BACKENDS_UP  (haproxy-* sub only; F-B)"
  echo "expected-iso        = $EXPECTED_ISO   actual = ${ACTUAL_ISO:-N/A}"
  echo "yb-effective-iso    = ${YB_EFFECTIVE:-n/a}"
  echo "ybdb-cluster-healthy = ${YBDB_CLUSTER_HEALTHY:-n/a}"
  echo "all_pass            = $ALL_PASS"
  if [[ ${#FAILS[@]} -gt 0 ]]; then
    echo "fails               = ${FAILS[*]}"
  fi
} > "$DRY/expected-vs-actual.txt"

write_phase_done "$ROOT" "dry-run" "$(cat <<JSON
{
  "phase": "dry-run",
  "db": "$DB",
  "topology": "$TOPOLOGY",
  "sub_topology": "$SUB",
  "iso": "$ISO",
  "ts": "$TS",
  "db_host": "$DB_HOST",
  "node_count": ${NODE_COUNT:-0},
  "rf_expected": "$EXPECTED_RF",
  "rf_actual": "${ACTUAL_RF:-?}",
  "rf_actual_peer_min": "${ACTUAL_RF_MIN:-n/a}",
  "rf_actual_peer_max": "${ACTUAL_RF_MAX:-n/a}",
  "rf_actual_regions": "${ACTUAL_RF_REGIONS:-n/a}",
  "haproxy_backends_up": "${HAPROXY_BACKENDS_UP:-n/a}",
  "iso_expected": "$EXPECTED_ISO",
  "iso_actual": "${ACTUAL_ISO:-N/A}",
  "yb_effective_iso": "${YB_EFFECTIVE:-n/a}",
  "all_pass": $ALL_PASS,
  "fails": "${FAILS[*]:-}"
}
JSON
)"

if $ALL_PASS; then
  info "dry-run-confirm PASSED  (sub=$SUB rf=$ACTUAL_RF iso=$ACTUAL_ISO)"
  info "review: cat $DRY/*.txt"
  info "to execute: re-run the make target with EXECUTE=1 TPCC_TS=$TS"
  exit 0
else
  err "dry-run-confirm FAILED  fails=${FAILS[*]}"
  err "review: cat $DRY/*.txt"
  err "fix deploy first; do NOT set EXECUTE=1 until all_pass=true"
  exit 1
fi
