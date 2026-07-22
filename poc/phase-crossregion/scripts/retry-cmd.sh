#!/usr/bin/env bash
# phase-crossregion/scripts/retry-cmd.sh
#
# 重試包裝：Mac↔.31 的 ssh/rsync/scp 偶爾在 SSH kex 階段被連線重置
# （2026-07-22 觀測兩次，皆發生在 phase2-bootstrap 同一位置——連續數個
# ssh/rsync 呼叫後的下一個新連線）。.31 端 sshd journal 顯示
# "Connection reset by <mac-ip> ... [preauth]"，即 client（Mac）端主動斷線，
# 非 .31 sshd 限流（MaxStartups 遠高於本流程的連線數）——根因是 Mac 端網路層
# （VPN utun 介面）對短時間內密集新連線的處理，非本專案可控；手動立即重試
# 兩次都馬上成功，故用重試吸收這類瞬斷，而非放寬 fail-closed。
#
# Usage: retry-cmd.sh <max_attempts> <sleep_sec> -- <command...>
# Exit: 0 一旦任一次成功；非 0（原始指令最後一次的 exit code）= 連續 N 次皆失敗
set -uo pipefail

MAX=$1; SLEEP=$2; shift 2
[[ "${1:-}" == "--" ]] && shift
[[ $# -gt 0 ]] || { echo "[retry-cmd] missing command after --" >&2; exit 2; }

i=0
while true; do
  i=$((i+1))
  if "$@"; then
    exit 0
  fi
  rc=$?
  if [[ $i -ge $MAX ]]; then
    echo "[retry-cmd] FAIL after $i/$MAX attempts (exit=$rc): $*" >&2
    exit "$rc"
  fi
  echo "[retry-cmd] attempt $i/$MAX failed (exit=$rc), retry in ${SLEEP}s: $*" >&2
  sleep "$SLEEP"
done
