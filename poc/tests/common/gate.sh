#!/usr/bin/env bash
# Run preflight gates and write artifacts.
#
# Scope:
#   - OS gate         → on DB node ($DB_HOST):  THP / sysctl / ulimit / governor / chrony
#   - chrony offset   → compare CLIENT (.31) and DB_HOST clocks
#   - disk gate       → CLIENT artifacts FS + DB_HOST data FS
#
# Active isolation gate (§7.4) lives in a separate script (gate-isolation.sh),
# called after prepare phase.
#
# Usage (runs on the TPC-C client / .31):
#   gate.sh --db <tidb|crdb|ybdb> --iso <rc|rr|strict> \
#           --db-host <ip>       --ts <timestamp> \
#           [--topology <vm-1node|vm-3node-...>]    # default vm-1node (legacy)
#
# Env (Makefile-provided):
#   TPCC_ARTIFACTS (default /tmp/poc-tpcc/artifacts)

set -euo pipefail
SELF=$(cd "$(dirname "$0")" && pwd)
source "$SELF/lib/common.sh"

DB="" ISO="" DB_HOST="" TS="" TOPO="vm-1node"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --db)       DB=$2; shift 2 ;;
    --iso)      ISO=$2; shift 2 ;;
    --db-host)  DB_HOST=$2; shift 2 ;;
    --ts)       TS=$2; shift 2 ;;
    --topology) TOPO=$2; shift 2 ;;
    *) die "unknown arg: $1" ;;
  esac
done
[[ -n "$DB" && -n "$ISO" && -n "$DB_HOST" && -n "$TS" ]] || die "missing required args"

: "${TPCC_ARTIFACTS:=/tmp/poc-tpcc/artifacts}"
ROOT=$(artifact_dir "$DB" "$TOPO" "$ISO" "$TS")
mk_artifact_tree "$ROOT"
flock_phase "$ROOT" "gate"

GATE_DIR="$ROOT/gate"
ENV_DIR="$ROOT/env"

info "gate root: $ROOT  (client=$(hostname), db-host=$DB_HOST)"

# helper: run remote command, capture output
remote() {
  ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=5 "root@$DB_HOST" "$@"
}

# ---- env snapshot (client + db-host) -------------------------------
{
  echo "=== client (.31) ==="
  uname -a
  [[ -f /etc/os-release ]] && cat /etc/os-release
  echo
  echo "=== db-host ($DB_HOST) ==="
  remote 'uname -a; [ -f /etc/os-release ] && cat /etc/os-release' || true
} > "$ENV_DIR/kernel.txt" 2>&1

# ---- OS gate on DB_HOST -------------------------------------------
{
  echo "=== DB-HOST OS gate ($DB_HOST) ==="
  remote 'set +e
    echo "[THP]"
    cat /sys/kernel/mm/transparent_hugepage/enabled
    echo "[sysctl]"
    sysctl -n vm.swappiness vm.dirty_ratio vm.dirty_background_ratio
    echo "[ulimit -n]"
    ulimit -n
    echo "[governor]"
    cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo "(no cpufreq, virtual guest OK)"
    echo "[chrony tracking]"
    chronyc tracking 2>/dev/null | head -10
  '
} > "$GATE_DIR/os-gate.txt" 2>&1

# Hard checks against DB_HOST values (best-effort parsing)
db_thp=$(remote 'cat /sys/kernel/mm/transparent_hugepage/enabled' 2>/dev/null || echo "")
db_swap=$(remote 'sysctl -n vm.swappiness' 2>/dev/null || echo 999)
db_nofile=$(remote 'ulimit -n' 2>/dev/null || echo 0)

gate_pass=true
echo "$db_thp" | grep -q '\[never\]' || { warn "DB-host THP != [never] ($db_thp)"; gate_pass=false; }
[[ ${db_swap:-999} -le 5 ]]    || { warn "DB-host vm.swappiness ($db_swap) > 5"; gate_pass=false; }
[[ ${db_nofile:-0} -ge 65536 ]] || { warn "DB-host ulimit -n ($db_nofile) < 65536"; gate_pass=false; }
echo "" >> "$GATE_DIR/os-gate.txt"
echo "os-gate-pass=$gate_pass" >> "$GATE_DIR/os-gate.txt"

# ---- chrony offset gate (compare client ↔ db-host) -----------------
{
  echo "=== client (.31) chrony tracking ==="
  chronyc tracking 2>/dev/null | head -10 || echo "(chronyc not available)"
  echo
  echo "=== db-host ($DB_HOST) chrony tracking ==="
  remote 'chronyc tracking 2>/dev/null | head -10' || echo "(ssh/chronyc failed)"
} > "$GATE_DIR/chrony-gate.txt" 2>&1

# ---- disk gate -----------------------------------------------------
{
  echo "=== CLIENT artifacts FS ($(dirname "$TPCC_ARTIFACTS")) ==="
  df -h "$(dirname "$TPCC_ARTIFACTS")"
  echo
  echo "=== DB-HOST data FS (/) ==="
  remote 'df -h /' || echo "(ssh failed)"
} > "$GATE_DIR/disk-gate.txt" 2>&1

client_avail_gb=$(df -B1G --output=avail "$(dirname "$TPCC_ARTIFACTS")" | tail -1 | tr -d ' ')
db_avail_gb=$(remote 'df -B1G --output=avail / | tail -1 | tr -d " "' 2>/dev/null || echo 0)
echo "" >> "$GATE_DIR/disk-gate.txt"
echo "client-avail-gb=$client_avail_gb" >> "$GATE_DIR/disk-gate.txt"
echo "db-host-avail-gb=$db_avail_gb"    >> "$GATE_DIR/disk-gate.txt"

[[ ${client_avail_gb:-0} -ge 30 ]] || warn "client (.31) artifacts FS available ${client_avail_gb}GB < 30GB"
[[ ${db_avail_gb:-0} -ge 30 ]]     || warn "db-host ($DB_HOST) / available ${db_avail_gb}GB < 30GB"

write_phase_done "$ROOT" "gate" "$(cat <<JSON
{
  "phase": "gate",
  "db": "$DB",
  "iso": "$ISO",
  "ts": "$TS",
  "db_host": "$DB_HOST",
  "os_gate_pass": $gate_pass,
  "client_avail_gb": $client_avail_gb,
  "db_host_avail_gb": $db_avail_gb
}
JSON
)"

info "gate done  (os_gate_pass=$gate_pass  client=${client_avail_gb}GB  db-host=${db_avail_gb}GB)"
