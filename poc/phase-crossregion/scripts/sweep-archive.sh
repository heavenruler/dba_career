#!/usr/bin/env bash
# phase-crossregion/scripts/sweep-archive.sh
#
# Stage J archive + cleanup (per PRE-FLIGHT-TEST-PLAN-2026-06-17 §6 #5 / Stage J).
#
# 觸發時機：9 cell-tracks × 360 rounds × 150h sweep 全部完成 / commit / archive 前。
#
# 流程（依序，fail-closed）：
#   1. 驗證 sweep 結果完整性：
#      find results/x-cross/ -name '.suite.done' | wc -l == 9（3 DB × 3 profile）
#      列出 9 cell-tracks；不齊則 fail-closed。
#   2. GCP client artifact fetch（A-A / A-A-RO 才有）：
#      rsync /tmp/poc-tpcc/artifacts/X-CROSS/<cell>/ from g-test-poc-5 (port 12215)
#      → results/x-cross/<cell>/gcp-side/
#   3. 生成 sweep summary：
#      results/sweep-summary-<ts>.md：9 cell-tracks tpmC / p99 / error rate / status
#   4. archive tarball：
#      tar -czf results/x-cross-sweep-<ts>.tar.gz results/x-cross/...
#      印 size + sha256 checksum
#   5. GCP VM destroy（除非 --skip-destroy）：
#      cd iac-gcp && terraform destroy -auto-approve
#      驗 terraform state list 為空；印 ~$590/月節費
#   6. IAP tunnel cleanup：bash iac-gcp/tunnel.sh stop
#   7. write .archive.done JSON：ts / 9 cell-tracks / tar path / tar size / duration / destroyed
#
# 用法：
#   bash sweep-archive.sh --ts <sweep-ts> --dry-run
#   bash sweep-archive.sh --ts <sweep-ts> --execute
#   bash sweep-archive.sh --ts <sweep-ts> --execute --skip-destroy
#
# Env overrides：
#   REPO_ROOT           (default 由 script 自動推導 = repo root)
#   GCP_CLIENT_PORT     (default 12215；g-test-poc-5 IAP tunnel)
#   GCP_CLIENT_USER     (default root)
#   GCP_CLIENT_SSH_KEY  (default $HOME/.ssh/id_rsa)
#   GCP_ARTIFACT_BASE   (default /tmp/poc-tpcc/artifacts/X-CROSS)
#
# Exit:
#   0 = PASS（dry-run 印完 / execute 9 cells 完整 + archive + destroy + cleanup OK）
#   1 = FAIL（任一步 fail-closed）

set -euo pipefail

SELF=$(cd "$(dirname "$0")" && pwd)
: "${REPO_ROOT:=$(cd "$SELF/../.." && pwd)}"

# ---- arg parse ------------------------------------------------------
SWEEP_TS=""
MODE=""
SKIP_DESTROY=0
while [[ $# -gt 0 ]]; do
  case $1 in
    --ts) SWEEP_TS=$2; shift 2 ;;
    --dry-run) MODE=dry-run; shift ;;
    --execute) MODE=execute; shift ;;
    --skip-destroy) SKIP_DESTROY=1; shift ;;
    -h|--help)
      sed -n '2,42p' "$0"
      exit 0
      ;;
    *) echo "unknown arg: $1" >&2; exit 1 ;;
  esac
done

: "${SWEEP_TS:?--ts <sweep-ts> required (e.g., 20260617T120000+0800)}"
[[ "$MODE" == "dry-run" || "$MODE" == "execute" ]] || \
  { echo "--dry-run or --execute required" >&2; exit 1; }

: "${GCP_CLIENT_PORT:=12215}"
: "${GCP_CLIENT_USER:=root}"
: "${GCP_CLIENT_SSH_KEY:=$HOME/.ssh/id_rsa}"
: "${GCP_ARTIFACT_BASE:=/tmp/poc-tpcc/artifacts/X-CROSS}"

EXPECTED_DBS=(tidb cockroach yuga)
EXPECTED_PROFILES=(A-S A-A-RO A-A)            # 用於對齊預期 9 cells（cell→profile 由 .suite.done.profile 對齊）
GCP_FETCH_PROFILES=(A-A A-A-RO)               # 2 個 profile × 3 DB = 6 個 cell 需要 fetch（A-A-RO IDC writer + GCP reader / A-A 雙側 RW）

START_EPOCH=$(date +%s)

echo "[sweep-archive] mode=$MODE ts=$SWEEP_TS skip_destroy=$SKIP_DESTROY"
echo "[sweep-archive] repo_root=$REPO_ROOT"

# ---- helper ---------------------------------------------------------
run_or_dry() {
  # run_or_dry <step-name> <cmd...>
  local step=$1; shift
  if [[ "$MODE" == "dry-run" ]]; then
    echo "[dry-run] $step: $*"
  else
    echo "[execute] $step: $*"
    "$@" || { echo "[sweep-archive] FAIL at $step" >&2; exit 1; }
  fi
}

# ---- 1. 驗證 sweep 結果完整性 ----------------------------------------
echo "[sweep-archive] step 1/7 verify sweep completeness"

# find expects results/x-cross/<cell>/.suite.done 結構
SUITE_DONE_LIST=$(cd "$REPO_ROOT" && \
  find results -maxdepth 4 -type f -path 'results/x-cross/*/.suite.done' 2>/dev/null | sort || true)

DONE_COUNT=$(printf '%s\n' "$SUITE_DONE_LIST" | grep -c . || true)

echo "[verify] .suite.done found: $DONE_COUNT (expected 9)"
if [[ -n "$SUITE_DONE_LIST" ]]; then
  printf '  %s\n' $SUITE_DONE_LIST
fi

if [[ "$DONE_COUNT" -ne 9 ]]; then
  if [[ "$MODE" == "execute" ]]; then
    echo "[sweep-archive] FAIL (integrity-gate): expected 9 cell-tracks, got $DONE_COUNT" >&2
    exit 1
  else
    echo "[dry-run] integrity-gate would FAIL (--execute would exit 1)"
  fi
fi

# 列 9 cell-tracks 摘要：db / profile / placement / topology / ts
echo "[verify] cell-track summary:"
CELL_TRACKS=()
if [[ -n "$SUITE_DONE_LIST" ]]; then
  while IFS= read -r done_path; do
    [[ -z "$done_path" ]] && continue
    cell_dir=$(dirname "$done_path")
    # parse db / topology / iso / ts / profile from .suite.done JSON
    if command -v jq >/dev/null 2>&1; then
      db=$(jq -r '.db // "?"' "$REPO_ROOT/$done_path" 2>/dev/null)
      profile=$(jq -r '.profile // "?"' "$REPO_ROOT/$done_path" 2>/dev/null)
      placement=$(jq -r '.placement // "?"' "$REPO_ROOT/$done_path" 2>/dev/null)
      topology=$(jq -r '.topology // "?"' "$REPO_ROOT/$done_path" 2>/dev/null)
      ts=$(jq -r '.ts // "?"' "$REPO_ROOT/$done_path" 2>/dev/null)
    else
      db="?"; profile="?"; placement="?"; topology="?"; ts="?"
    fi
    echo "  - $cell_dir | db=$db profile=$profile placement=$placement topology=$topology ts=$ts"
    CELL_TRACKS+=("$cell_dir|$db|$profile|$placement|$topology|$ts")
  done <<< "$SUITE_DONE_LIST"
fi

# ---- 2. GCP client artifact fetch（A-A / A-A-RO） ---------------------
echo "[sweep-archive] step 2/7 GCP client artifact fetch (A-A / A-A-RO)"

GCP_FETCHED=0
for entry in "${CELL_TRACKS[@]:-}"; do
  [[ -z "$entry" ]] && continue
  IFS='|' read -r cell_dir db profile placement topology ts <<< "$entry"
  needs_fetch=0
  for fp in "${GCP_FETCH_PROFILES[@]}"; do
    [[ "$profile" == "$fp" ]] && needs_fetch=1
  done
  [[ "$needs_fetch" -eq 0 ]] && continue

  # remote cell dir on g-test-poc-5: $GCP_ARTIFACT_BASE/<cell-name>
  cell_name=$(basename "$cell_dir")
  remote_src="${GCP_CLIENT_USER}@localhost:${GCP_ARTIFACT_BASE}/${cell_name}/"
  local_dst="$REPO_ROOT/$cell_dir/gcp-side/"
  rsync_cmd=(rsync -av --partial \
    -e "ssh -i ${GCP_CLIENT_SSH_KEY} -p ${GCP_CLIENT_PORT} -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10" \
    "$remote_src" "$local_dst")

  if [[ "$MODE" == "dry-run" ]]; then
    echo "[dry-run] gcp-fetch ($profile $db): mkdir -p $local_dst"
    echo "[dry-run] gcp-fetch ($profile $db): ${rsync_cmd[*]}"
  else
    echo "[execute] gcp-fetch ($profile $db) → $local_dst"
    mkdir -p "$local_dst"
    "${rsync_cmd[@]}" || { echo "[sweep-archive] FAIL gcp-fetch $cell_name" >&2; exit 1; }
  fi
  GCP_FETCHED=$((GCP_FETCHED + 1))
done
echo "[sweep-archive] gcp-fetch processed cells: $GCP_FETCHED"

# ---- 3. 生成 sweep summary ------------------------------------------
SUMMARY_PATH="$REPO_ROOT/results/sweep-summary-${SWEEP_TS}.md"
echo "[sweep-archive] step 3/7 generate sweep summary → $SUMMARY_PATH"

# helper: per-cell extract tpmC / p99 / error rate（best-effort）
extract_metric() {
  # extract_metric <cell-abs-dir> <metric: tpmC|p99|err>
  local cell=$1 metric=$2
  case "$metric" in
    tpmC)
      # 取 go-tpc-stdout.txt 最後一 NEW_ORDER summary 行
      grep -h "^\[Summary\] NEW_ORDER" "$cell"/runs/threads-*/round-*/go-tpc-stdout.txt 2>/dev/null \
        | awk '{print $4}' | tail -1
      ;;
    p99)
      grep -h "^\[Summary\] NEW_ORDER" "$cell"/runs/threads-*/round-*/go-tpc-stdout.txt 2>/dev/null \
        | awk '{print $(NF-1)}' | tail -1
      ;;
    err)
      # _ERR 行 count vs total summary 行
      local err_n total_n
      err_n=$(grep -h "_ERR" "$cell"/runs/threads-*/round-*/go-tpc-stdout.txt 2>/dev/null | wc -l | tr -d ' ')
      total_n=$(grep -h "^\[Summary\]" "$cell"/runs/threads-*/round-*/go-tpc-stdout.txt 2>/dev/null | wc -l | tr -d ' ')
      [[ "$total_n" -gt 0 ]] && echo "${err_n}/${total_n}" || echo "n/a"
      ;;
  esac
}

write_summary() {
  {
    echo "# X-CROSS Sweep Summary — ts=${SWEEP_TS}"
    echo
    echo "Generated: $(date '+%Y-%m-%dT%H:%M:%S%z')"
    echo "Mode: $MODE"
    echo "Cell-track count: $DONE_COUNT (expected 9)"
    echo
    echo "| # | cell-dir | db | profile | placement | topology | ts | tpmC | p99 | err | status |"
    echo "|---|---|---|---|---|---|---|---|---|---|---|"
    local idx=0
    for entry in "${CELL_TRACKS[@]:-}"; do
      [[ -z "$entry" ]] && continue
      idx=$((idx + 1))
      IFS='|' read -r cell_dir db profile placement topology ts <<< "$entry"
      local cell_abs="$REPO_ROOT/$cell_dir"
      local tpmc p99 err status
      tpmc=$(extract_metric "$cell_abs" tpmC)
      p99=$(extract_metric "$cell_abs" p99)
      err=$(extract_metric "$cell_abs" err)
      [[ -z "$tpmc" ]] && tpmc="n/a"
      [[ -z "$p99"  ]] && p99="n/a"
      [[ -z "$err"  ]] && err="n/a"
      status="OK"
      [[ "$tpmc" == "n/a" ]] && status="UNRELIABLE"
      echo "| $idx | $cell_dir | $db | $profile | $placement | $topology | $ts | $tpmc | $p99 | $err | $status |"
    done
    echo
    echo "## Notes"
    echo "- tpmC / p99 / err are best-effort extracted from go-tpc-stdout.txt last summary line per round."
    echo "- 'n/a' indicates extraction failure；建議 analytics 階段再對齊。"
  } > "$SUMMARY_PATH"
}

if [[ "$MODE" == "dry-run" ]]; then
  echo "[dry-run] step 3: would write summary → $SUMMARY_PATH"
else
  mkdir -p "$REPO_ROOT/results"
  write_summary
  echo "[execute] step 3: summary written → $SUMMARY_PATH ($(wc -l < "$SUMMARY_PATH") lines)"
fi

# ---- 4. archive tarball ---------------------------------------------
TAR_PATH="$REPO_ROOT/results/x-cross-sweep-${SWEEP_TS}.tar.gz"
echo "[sweep-archive] step 4/7 archive tarball → $TAR_PATH"

# 收集 X-CROSS 本機彙整目錄
TAR_INPUTS=()
if [[ -d "$REPO_ROOT/results/x-cross" ]]; then
  TAR_INPUTS+=("results/x-cross")
fi

# 也納入 summary.md（execute 後才存在）
if [[ "$MODE" == "execute" && -f "$SUMMARY_PATH" ]]; then
  TAR_INPUTS+=("results/sweep-summary-${SWEEP_TS}.md")
fi

if [[ "${#TAR_INPUTS[@]}" -eq 0 ]]; then
  if [[ "$MODE" == "execute" ]]; then
    echo "[sweep-archive] FAIL: no results/x-cross dir found to archive" >&2
    exit 1
  else
    echo "[dry-run] step 4: no results/x-cross dir found；execute would FAIL"
  fi
fi

tar_cmd=(tar -czf "$TAR_PATH" -C "$REPO_ROOT" "${TAR_INPUTS[@]}")
if [[ "$MODE" == "dry-run" ]]; then
  echo "[dry-run] step 4: ${tar_cmd[*]}"
  echo "[dry-run] step 4: size/checksum check (skipped in dry-run)"
  TAR_SIZE_BYTES=0
  TAR_SHA256="(dry-run)"
else
  echo "[execute] step 4: ${tar_cmd[*]}"
  "${tar_cmd[@]}" || { echo "[sweep-archive] FAIL tar" >&2; exit 1; }
  TAR_SIZE_BYTES=$(stat -f %z "$TAR_PATH" 2>/dev/null || stat -c %s "$TAR_PATH" 2>/dev/null || echo 0)
  if command -v shasum >/dev/null 2>&1; then
    TAR_SHA256=$(shasum -a 256 "$TAR_PATH" | awk '{print $1}')
  elif command -v sha256sum >/dev/null 2>&1; then
    TAR_SHA256=$(sha256sum "$TAR_PATH" | awk '{print $1}')
  else
    TAR_SHA256="(sha256 tool missing)"
  fi
  echo "[execute] step 4: tar size=${TAR_SIZE_BYTES} bytes sha256=${TAR_SHA256}"
fi

# ---- 5. GCP VM destroy（除非 --skip-destroy）-------------------------
echo "[sweep-archive] step 5/7 terraform destroy (skip_destroy=$SKIP_DESTROY)"
DESTROYED=false
if [[ "$SKIP_DESTROY" -eq 1 ]]; then
  echo "[sweep-archive] --skip-destroy 指定，跳過 destroy；GCP 5 VM 仍在運行（持續燒錢）"
else
  IAC_DIR="$REPO_ROOT/iac-gcp"
  if [[ "$MODE" == "dry-run" ]]; then
    echo "[dry-run] step 5: cd $IAC_DIR && terraform destroy -auto-approve"
    echo "[dry-run] step 5: terraform state list | wc -l (expect 0)"
  else
    if [[ ! -d "$IAC_DIR" ]]; then
      echo "[sweep-archive] FAIL: iac-gcp dir not found at $IAC_DIR" >&2
      exit 1
    fi
    echo "[execute] step 5: (cd $IAC_DIR && terraform destroy -auto-approve)"
    ( cd "$IAC_DIR" && terraform destroy -auto-approve ) \
      || { echo "[sweep-archive] FAIL terraform destroy" >&2; exit 1; }
    STATE_N=$( cd "$IAC_DIR" && terraform state list 2>/dev/null | wc -l | tr -d ' ' )
    echo "[verify] terraform state list count = $STATE_N (expected 0)"
    if [[ "$STATE_N" -ne 0 ]]; then
      echo "[sweep-archive] FAIL: terraform state still has $STATE_N resources" >&2
      exit 1
    fi
    DESTROYED=true
    echo "[sweep-archive] destroyed；預估節費 ~\$590/月 (5 × e2-standard-4)"
  fi
fi

# ---- 6. IAP tunnel cleanup ------------------------------------------
echo "[sweep-archive] step 6/7 IAP tunnel cleanup"
TUNNEL_SH="$REPO_ROOT/iac-gcp/tunnel.sh"
if [[ "$MODE" == "dry-run" ]]; then
  echo "[dry-run] step 6: bash $TUNNEL_SH stop"
else
  if [[ -f "$TUNNEL_SH" ]]; then
    bash "$TUNNEL_SH" stop || echo "[warn] tunnel.sh stop returned non-zero (tunnels may not have been running)"
  else
    echo "[warn] $TUNNEL_SH not found；skip"
  fi
fi

# ---- 7. write .archive.done -----------------------------------------
END_EPOCH=$(date +%s)
DURATION_SEC=$((END_EPOCH - START_EPOCH))
ARCHIVE_DONE="$REPO_ROOT/results/.archive.done-${SWEEP_TS}.json"
echo "[sweep-archive] step 7/7 write .archive.done → $ARCHIVE_DONE"

# build cell-tracks JSON array
build_cells_json() {
  local first=1
  printf '['
  for entry in "${CELL_TRACKS[@]:-}"; do
    [[ -z "$entry" ]] && continue
    IFS='|' read -r cell_dir db profile placement topology ts <<< "$entry"
    if [[ "$first" -eq 1 ]]; then first=0; else printf ','; fi
    printf '{"cell_dir":"%s","db":"%s","profile":"%s","placement":"%s","topology":"%s","ts":"%s"}' \
      "$cell_dir" "$db" "$profile" "$placement" "$topology" "$ts"
  done
  printf ']'
}

CELLS_JSON=$(build_cells_json)

if [[ "$MODE" == "dry-run" ]]; then
  echo "[dry-run] step 7: would write JSON with ts/cell-tracks/tar/duration/destroyed=$DESTROYED"
else
  cat > "$ARCHIVE_DONE" <<JSON
{
  "phase": "archive",
  "ts": "$SWEEP_TS",
  "completed_at": "$(date '+%Y-%m-%dT%H:%M:%S%z')",
  "duration_sec": $DURATION_SEC,
  "cell_track_count": $DONE_COUNT,
  "cell_tracks": $CELLS_JSON,
  "tar_path": "$TAR_PATH",
  "tar_size_bytes": $TAR_SIZE_BYTES,
  "tar_sha256": "$TAR_SHA256",
  "summary_path": "$SUMMARY_PATH",
  "gcp_fetched_cells": $GCP_FETCHED,
  "destroyed": $DESTROYED,
  "skip_destroy": $( [[ "$SKIP_DESTROY" -eq 1 ]] && echo true || echo false )
}
JSON
  echo "[execute] step 7: .archive.done written"
fi

echo "[sweep-archive] PASS mode=$MODE ts=$SWEEP_TS duration=${DURATION_SEC}s"
exit 0
