#!/usr/bin/env bash
# freeze-crdb.sh — disable CRDB load-based lease rebalancing and range splitting
# Usage: CRDB_HOST=10.x.x.x DUMP_DIR=/tmp/freeze-state ./freeze-crdb.sh
set -euo pipefail

: "${CRDB_HOST:?CRDB_HOST is required}"
: "${DUMP_DIR:?DUMP_DIR is required}"

mkdir -p "$DUMP_DIR"

SQL() { cockroach sql --insecure --host="$CRDB_HOST" "$@"; }

# ── backup existing dump files (avoid overwriting pre-freeze originals) ────────
for f in crdb-lease-rebal-before.tsv crdb-split-load-before.tsv; do
  if [[ -f "$DUMP_DIR/$f" ]]; then
    mv "$DUMP_DIR/$f" "$DUMP_DIR/${f}.bak-$(date +%s)"
    echo "[freeze-crdb] existing $f renamed to ${f}.bak"
  fi
done

# ── track what we've SET so rollback can undo only those ──────────────────────
ORIG_LEASE_REBAL=""
ORIG_SPLIT_LOAD=""
SET_LEASE_REBAL=0
SET_SPLIT_LOAD=0

rollback() {
  echo "[freeze-crdb] ERROR — rolling back changes..." >&2
  if [[ "$SET_LEASE_REBAL" = "1" ]]; then
    SQL -e "SET CLUSTER SETTING kv.allocator.load_based_lease_rebalancing.enabled = ${ORIG_LEASE_REBAL};" || true
    echo "[freeze-crdb] rolled back kv.allocator.load_based_lease_rebalancing.enabled → ${ORIG_LEASE_REBAL}" >&2
  fi
  if [[ "$SET_SPLIT_LOAD" = "1" ]]; then
    SQL -e "SET CLUSTER SETTING kv.range_split.by_load_enabled = ${ORIG_SPLIT_LOAD};" || true
    echo "[freeze-crdb] rolled back kv.range_split.by_load_enabled → ${ORIG_SPLIT_LOAD}" >&2
  fi
}
trap rollback ERR INT TERM

# ── dump current values (--format=tsv + tail -1 → pure value, no header/separator) ──
echo "[freeze-crdb] dumping current cluster settings..."

ORIG_LEASE_REBAL=$(SQL --format=tsv \
  -e "SHOW CLUSTER SETTING kv.allocator.load_based_lease_rebalancing.enabled;" \
  | tail -1)
case "$ORIG_LEASE_REBAL" in
  true|false) ;;
  *) echo "[freeze-crdb] FAIL: unexpected value '${ORIG_LEASE_REBAL}' for lease_rebal" >&2; exit 1 ;;
esac
printf '%s' "$ORIG_LEASE_REBAL" > "$DUMP_DIR/crdb-lease-rebal-before.tsv"

ORIG_SPLIT_LOAD=$(SQL --format=tsv \
  -e "SHOW CLUSTER SETTING kv.range_split.by_load_enabled;" \
  | tail -1)
case "$ORIG_SPLIT_LOAD" in
  true|false) ;;
  *) echo "[freeze-crdb] FAIL: unexpected value '${ORIG_SPLIT_LOAD}' for split_load" >&2; exit 1 ;;
esac
printf '%s' "$ORIG_SPLIT_LOAD" > "$DUMP_DIR/crdb-split-load-before.tsv"

# ── freeze ────────────────────────────────────────────────────────────────────
echo "[freeze-crdb] disabling load_based_lease_rebalancing..."
SQL -e "SET CLUSTER SETTING kv.allocator.load_based_lease_rebalancing.enabled = false;"
SET_LEASE_REBAL=1

echo "[freeze-crdb] disabling range_split.by_load_enabled..."
SQL -e "SET CLUSTER SETTING kv.range_split.by_load_enabled = false;"
SET_SPLIT_LOAD=1

# ── all good: disarm trap ────────────────────────────────────────────────────
trap - ERR INT TERM

echo "[freeze-crdb] waiting 10s for settings to propagate..."
sleep 10

echo "[freeze-crdb] CRDB frozen at $(date)"
