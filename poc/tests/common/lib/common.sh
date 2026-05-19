#!/usr/bin/env bash
# Shared helpers for vm-1node PoC scripts (run on .31 client).
# Source from each phase script:  source "$(dirname "$0")/lib/common.sh"

set -euo pipefail

# ---- logging -----------------------------------------------------
log()   { printf '[%s] %s\n' "$(date '+%H:%M:%S')" "$*" >&2; }
info()  { log "INFO  $*"; }
warn()  { log "WARN  $*"; }
err()   { log "ERROR $*"; }
die()   { err "$*"; exit 1; }

require_var() {
  local name=$1
  [[ -n "${!name:-}" ]] || die "required env var $name not set"
}

require_cmd() {
  for c in "$@"; do
    command -v "$c" >/dev/null 2>&1 || die "command not found: $c"
  done
}

# ---- timestamp / artifact dir ------------------------------------
poc_ts() { date '+%Y%m%dT%H%M%S%z'; }

# artifact_dir <db> <topology> <iso> <ts>
artifact_dir() {
  local db=$1 topo=$2 iso=$3 ts=$4
  printf '%s/%s-%s-%s-%s' "${TPCC_ARTIFACTS:-/tmp/poc-tpcc/artifacts}" "$db" "$topo" "$iso" "$ts"
}

# ensure artifact subtree
mk_artifact_tree() {
  local root=$1
  mkdir -p "$root"/{env,db-config,gate,prepare,runs}
}

# ---- phase lock + done -------------------------------------------
# flock_phase <artifact_root> <phase>  — exits non-zero if locked elsewhere
flock_phase() {
  local root=$1 phase=$2
  local lock="$root/.lock-$phase"
  # 9 is fd for lock
  exec 9>"$lock"
  flock -n 9 || die "phase $phase locked: another run in progress ($lock)"
}

# write_phase_done <artifact_root> <phase> <json_body>
write_phase_done() {
  local root=$1 phase=$2 body=$3
  printf '%s\n' "$body" >"$root/.$phase.done"
}

# ---- iso -> conn-params mapping (echoes go-tpc --conn-params value) ----
# get_conn_params <db> <iso>
get_conn_params() {
  local db=$1 iso=$2
  case "$db:$iso" in
    tidb:rc)
      echo "transaction_isolation=%27READ-COMMITTED%27&tidb_txn_mode=%27pessimistic%27" ;;
    tidb:rr|tidb:strict)
      echo "transaction_isolation=%27REPEATABLE-READ%27&tidb_txn_mode=%27pessimistic%27" ;;
    crdb:rc|ybdb:rc)
      echo "sslmode=disable&options=-c%20default_transaction_isolation%3Dread%5C%20committed" ;;
    crdb:rr|ybdb:rr)
      echo "sslmode=disable&options=-c%20default_transaction_isolation%3Drepeatable%5C%20read" ;;
    crdb:strict|ybdb:strict)
      echo "sslmode=disable&options=-c%20default_transaction_isolation%3Dserializable" ;;
    *)
      die "unknown <db>:<iso> = $db:$iso" ;;
  esac
}

# expected_iso <db> <iso>  -> human readable expected value (for gate verify)
expected_iso() {
  local db=$1 iso=$2
  case "$db:$iso" in
    tidb:rc)       echo "READ-COMMITTED" ;;
    tidb:rr|tidb:strict) echo "REPEATABLE-READ" ;;
    crdb:rc|ybdb:rc)     echo "read committed" ;;
    crdb:rr|ybdb:rr)     echo "repeatable read" ;;
    crdb:strict|ybdb:strict) echo "serializable" ;;
    *) die "unknown <db>:<iso> = $db:$iso" ;;
  esac
}

# get_driver <db>
get_driver() {
  case "$1" in
    tidb) echo "mysql" ;;
    crdb|ybdb) echo "postgres" ;;
    *) die "unknown db: $1" ;;
  esac
}
