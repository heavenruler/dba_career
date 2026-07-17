#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COLLECTOR_DIR="${COLLECTOR_DIR:-$ROOT_DIR/collector}"
STATE_FILE="${STATE_FILE:-$COLLECTOR_DIR/uploaded.tsv}"
INVENTORY_FILE="${INVENTORY_FILE:-$COLLECTOR_DIR/r2_inventory.tsv}"
KB_R2_BUCKET="${KB_R2_BUCKET:-}"
KB_R2_PREFIX="${KB_R2_PREFIX:-collector}"
KB_R2_PREFIX="${KB_R2_PREFIX%/}"
DRY_RUN="${DRY_RUN:-1}"
FORCE="${FORCE:-0}"

usage() {
  cat <<'EOF'
Upload collector PDFs to Cloudflare R2 with a local state file.

Required for real upload:
  KB_R2_BUCKET=<bucket>

Optional:
  KB_R2_PREFIX=collector
  COLLECTOR_DIR=collector
  STATE_FILE=collector/uploaded.tsv
  INVENTORY_FILE=collector/r2_inventory.tsv
  DRY_RUN=1|0       default 1
  FORCE=1           upload even if sha256 exists in state

Examples:
  scripts/upload_collector_r2.sh collector/abc.pdf
  KB_R2_BUCKET=my-kb DRY_RUN=0 scripts/upload_collector_r2.sh collector/*.pdf
EOF
}

sha256_file() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  else
    sha256sum "$1" | awk '{print $1}'
  fi
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ "$DRY_RUN" != "1" && -z "$KB_R2_BUCKET" ]]; then
  echo "ERROR: KB_R2_BUCKET is required when DRY_RUN=0" >&2
  exit 2
fi

if [[ "$DRY_RUN" != "1" && ! -s "$INVENTORY_FILE" ]]; then
  echo "ERROR: fresh R2 inventory required; run make fetch_collector_inventory" >&2
  exit 2
fi

if [[ "$DRY_RUN" != "1" ]]; then
  expected_header="# bucket=$KB_R2_BUCKET"$'\t'"prefix=$KB_R2_PREFIX/"
  actual_header="$(head -n 1 "$INVENTORY_FILE")"
  if [[ "$actual_header" != "$expected_header"$'\t'* ]]; then
    echo "ERROR: R2 inventory bucket/prefix does not match upload target" >&2
    exit 2
  fi
  if ! find "$INVENTORY_FILE" -mmin -15 -print -quit | grep -q .; then
    echo "ERROR: R2 inventory is older than 15 minutes; refresh it first" >&2
    exit 2
  fi
fi

if [[ "$DRY_RUN" != "1" ]] && ! command -v wrangler >/dev/null 2>&1; then
  echo "ERROR: wrangler not found" >&2
  exit 2
fi

if [[ "$#" -gt 0 ]]; then
  files=("$@")
else
  files=("$COLLECTOR_DIR"/*.pdf)
fi

uploaded=0
skipped=0
failed=0

for file in "${files[@]}"; do
  if [[ ! -f "$file" ]]; then
    continue
  fi

  base="$(basename "$file")"
  doc_id="${base%.pdf}"
  if [[ ! "$doc_id" =~ ^[0-9a-f]{32}$ ]]; then
    echo "SKIP non-doc-id filename: $file"
    skipped=$((skipped + 1))
    continue
  fi

  size="$(wc -c < "$file" | tr -d ' ')"
  sha256="$(sha256_file "$file")"
  key="$KB_R2_PREFIX/$base"

  remote_size="$(awk -F '\t' -v k="$key" '$1 == k { print $2; exit }' "$INVENTORY_FILE" 2>/dev/null || true)"
  state_match=0
  if [[ -f "$STATE_FILE" ]] && awk -F '\t' -v d="$doc_id" -v s="$sha256" -v z="$size" -v k="$key" \
      '$1 == d && $2 == s && $3 == z && $5 == k { found=1 } END { exit !found }' "$STATE_FILE"; then
    state_match=1
  fi

  if [[ -n "$remote_size" && "$FORCE" != "1" ]]; then
    if [[ "$remote_size" != "$size" ]]; then
      echo "FAIL remote conflict: $key local_size=$size remote_size=$remote_size" >&2
      failed=$((failed + 1))
      continue
    fi
    if [[ "$state_match" == "1" ]]; then
      echo "SKIP remote + state match: $base"
    else
      echo "SKIP remote exists, state missing/stale: $base"
    fi
    skipped=$((skipped + 1))
    continue
  fi

  if [[ "$DRY_RUN" == "1" ]]; then
    echo "DRY-RUN put ${KB_R2_BUCKET:-<bucket>}/$key size=$size sha256=$sha256"
    continue
  fi

  if wrangler r2 object put "$KB_R2_BUCKET/$key" --file "$file" --remote; then
    mkdir -p "$(dirname "$STATE_FILE")"
    printf '%s\t%s\t%s\t%s\t%s\n' "$doc_id" "$sha256" "$size" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$key" >> "$STATE_FILE"
    printf '%s\t%s\t%s\t%s\n' "$key" "$size" "uploaded-this-run" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$INVENTORY_FILE"
    uploaded=$((uploaded + 1))
    echo "OK uploaded: $base -> $key"
  else
    failed=$((failed + 1))
    echo "FAIL upload: $base" >&2
  fi
done

echo "summary uploaded=$uploaded skipped=$skipped failed=$failed dry_run=$DRY_RUN state=$STATE_FILE"
if [[ "$failed" -gt 0 ]]; then
  exit 1
fi
