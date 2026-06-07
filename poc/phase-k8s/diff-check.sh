#!/usr/bin/env bash
# phase-k8s/diff-check.sh — canonicalize-compare expected ⊆ actual.
# Replaces raw `diff` per codex v14 NB #1.
#
# Algorithm:
#   1. yq sort_keys both files (canonical YAML)
#   2. yq -o=json both files
#   3. jq subset check: every key in expected must equal the same key in actual
#   4. Extra keys in actual are OK; missing/wrong keys in expected → exit 1
#
# Usage:
#   diff-check.sh <expected.yaml> <actual.yaml> <out_dir>
# Writes:
#   $OUT_DIR/.diff-pass         (if pass)
#   $OUT_DIR/diff.txt           (mismatch field paths)
# Exit:
#   0 = pass; 1 = mismatch

set -euo pipefail

EXPECTED=$1
ACTUAL=$2
OUT_DIR=$3

if [[ ! -f "$EXPECTED" ]]; then echo "missing expected.yaml: $EXPECTED" >&2; exit 1; fi
if [[ ! -f "$ACTUAL" ]];   then echo "missing actual.yaml: $ACTUAL"     >&2; exit 1; fi

mkdir -p "$OUT_DIR"

# 1) canonicalize via yq sort + json
EXP_JSON=$(yq -o=json 'sort_keys(..)' "$EXPECTED")
ACT_JSON=$(yq -o=json 'sort_keys(..)' "$ACTUAL")

# 2) subset compare via jq — every leaf in expected must match in actual.
#    NB: use type-aware indexing (NOT `a[k] // null`) — `// null` treats
#        `false` and `0` as falsy and overwrites them with null.
DIFF=$(jq -n --argjson exp "$EXP_JSON" --argjson act "$ACT_JSON" '
  def walk(prefix; e; a):
    if (e | type) == "object" then
      e | to_entries | map(
        . as $kv
        | walk("\(prefix).\($kv.key)"; $kv.value;
            (a | if type == "object" then .[$kv.key] else null end))
      ) | add // []
    elif (e | type) == "array" then
      if (a | type) != "array" or (e | length) != (a | length) then
        ["\(prefix): expected=\(e), actual=\(a)"]
      else
        [range(0; e | length)] as $idxs
        | $idxs | map(. as $i | walk("\(prefix)[\($i)]"; e[$i]; a[$i])) | add // []
      end
    else
      if e == a then [] else ["\(prefix): expected=\(e), actual=\(a)"] end
    end;
  walk(""; $exp; $act) | .[]
')

if [[ -z "$DIFF" ]]; then
  echo "PASS: expected ⊆ actual" > "$OUT_DIR/.diff-pass"
  echo "[diff-check] PASS"
  exit 0
else
  echo "$DIFF" > "$OUT_DIR/diff.txt"
  echo "[diff-check] FAIL — mismatch field paths:" >&2
  echo "$DIFF" >&2
  exit 1
fi
