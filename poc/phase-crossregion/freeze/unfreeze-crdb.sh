#!/usr/bin/env bash
# unfreeze-crdb.sh — restore CRDB cluster settings from pre-freeze dump
# Usage: CRDB_HOST=10.x.x.x DUMP_DIR=/tmp/freeze-state ./unfreeze-crdb.sh
set -euo pipefail

: "${CRDB_HOST:?CRDB_HOST is required}"
: "${DUMP_DIR:?DUMP_DIR is required}"

SQL() { cockroach sql --insecure --host="$CRDB_HOST" "$@"; }

_restore_setting() {
  local dump_file="$1"
  local setting_name="$2"

  if [[ ! -f "$dump_file" ]]; then
    echo "[unfreeze-crdb] ERROR: dump file not found: ${dump_file}" >&2
    exit 1
  fi

  # dump files contain a single bare value (true/false) written by freeze-crdb.sh
  local val
  val=$(cat "$dump_file")

  case "$val" in
    true|false) ;;
    *) echo "[unfreeze-crdb] FAIL: invalid value '${val}' in ${dump_file}" >&2; exit 1 ;;
  esac

  echo "[unfreeze-crdb] restoring ${setting_name} = ${val}"
  SQL -e "SET CLUSTER SETTING ${setting_name} = ${val};"
}

_restore_setting \
  "${DUMP_DIR}/crdb-lease-rebal-before.tsv" \
  "kv.allocator.load_based_lease_rebalancing.enabled"

_restore_setting \
  "${DUMP_DIR}/crdb-split-load-before.tsv" \
  "kv.range_split.by_load_enabled"

echo "[unfreeze-crdb] CRDB unfrozen at $(date)"
