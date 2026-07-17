#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COLLECTOR_DIR="${COLLECTOR_DIR:-$ROOT_DIR/collector}"
STATE_FILE="${STATE_FILE:-$COLLECTOR_DIR/uploaded.tsv}"
KB_R2_BUCKET="${KB_R2_BUCKET:-}"
KB_R2_PREFIX="${KB_R2_PREFIX:-collector}"
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

  if [[ "$FORCE" != "1" && -f "$STATE_FILE" ]] && awk -F '\t' -v s="$sha256" '$2 == s { found=1 } END { exit !found }' "$STATE_FILE"; then
    echo "SKIP already uploaded: $base"
    skipped=$((skipped + 1))
    continue
  fi

  if [[ "$DRY_RUN" == "1" ]]; then
    echo "DRY-RUN put ${KB_R2_BUCKET:-<bucket>}/$key size=$size sha256=$sha256"
    continue
  fi

  if wrangler r2 object put "$KB_R2_BUCKET/$key" --file "$file"; then
    mkdir -p "$(dirname "$STATE_FILE")"
    printf '%s\t%s\t%s\t%s\t%s\n' "$doc_id" "$sha256" "$size" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$key" >> "$STATE_FILE"
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
