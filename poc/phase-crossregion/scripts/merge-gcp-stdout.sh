#!/usr/bin/env bash
# phase-crossregion/scripts/merge-gcp-stdout.sh
#
# G3（雙端數據彙整規則，2026-07-15 拍板）落檔器 — 在 .31（IDC client）上執行：
#   把 GCP client 端 suite 目錄內每輪 go-tpc stdout（runs/threads-N/round-M/go-tpc-stdout.txt）
#   精確落位到 IDC 端同 suite 目錄的 runs/threads-N/round-M/go-tpc-stdout-gcp.txt
#   （與 IDC 端 go-tpc-stdout.txt 並排；IDC 檔案一律不動 — G1 永不合併）。
#
# 呼叫者: run-vm6-aa.sh（post-run 步驟，經 ssh .31）
# 前提:   .31 → GCP client 內網直連 SSH 已 prime（phase2-ssh-prime；不走 IAP）
#
# Usage:
#   merge-gcp-stdout.sh --root <IDC suite dir 絕對路徑> --gcp-host <GCP client 內網 IP>
#
# Fail-closed:
#   - IDC suite 目錄不存在 → exit 1
#   - GCP 端列不到任何 go-tpc-stdout.txt → exit 1
#   - 任一來源檔拉回為空 → exit 1（不留半套 artifact）

set -euo pipefail

ROOT=""
GCP_HOST=""
while [[ $# -gt 0 ]]; do
  case $1 in
    --root) ROOT=$2; shift 2 ;;
    --gcp-host) GCP_HOST=$2; shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 1 ;;
  esac
done

: "${ROOT:?--root required (IDC suite dir)}"
: "${GCP_HOST:?--gcp-host required (GCP client internal IP)}"

[[ "$GCP_HOST" =~ ^10\.160\.152\.1[1-5]$ ]] || \
  { echo "[merge-gcp] GCP_HOST=$GCP_HOST 不在 GCP zone (預期 10.160.152.11-15) — fail-closed" >&2; exit 1; }
[[ -d "$ROOT" ]] || { echo "[merge-gcp] IDC suite 目錄不存在: $ROOT — fail-closed" >&2; exit 1; }

SSH_OPTS=(-o ConnectTimeout=10 -o BatchMode=yes -o StrictHostKeyChecking=accept-new)

# GCP 端相對路徑清單（相對 suite root；佈局兩端同構：runs/threads-N/round-M/...）
FILES=$(ssh "${SSH_OPTS[@]}" "root@$GCP_HOST" \
  "cd '$ROOT' 2>/dev/null && find runs -type f -name go-tpc-stdout.txt | sort") || {
  echo "[merge-gcp] 無法列出 GCP 端 $ROOT/runs（目錄缺失或 SSH 失敗）— fail-closed" >&2
  exit 1
}
[[ -n "$FILES" ]] || { echo "[merge-gcp] GCP 端 $ROOT 無任何 go-tpc-stdout.txt — fail-closed" >&2; exit 1; }

N=0
while IFS= read -r rel; do
  [[ -n "$rel" ]] || continue
  dest="$ROOT/${rel%go-tpc-stdout.txt}go-tpc-stdout-gcp.txt"
  mkdir -p "$(dirname "$dest")"
  ssh "${SSH_OPTS[@]}" "root@$GCP_HOST" "cat '$ROOT/$rel'" > "$dest.tmp"
  [[ -s "$dest.tmp" ]] || {
    echo "[merge-gcp] GCP 端 $rel 拉回為空 — fail-closed" >&2
    rm -f "$dest.tmp"
    exit 1
  }
  mv "$dest.tmp" "$dest"          # 同 FS tmp→mv，冪等（重跑覆寫）
  N=$((N+1))
  echo "[merge-gcp] $rel → ${dest#"$ROOT"/}"
done <<< "$FILES"

echo "[merge-gcp] PASS — $N 檔落位 go-tpc-stdout-gcp.txt（G3 佈局）"
