#!/usr/bin/env bash
# netflow-snapshot.sh — snapshot established TCP connections per (host, port,
# remote_region) to證跨區流量分佈。
#
# Purpose: 補 0630.md §7 列的「跨專線實際承載流量」量化證據 — 哪些 port 在
# 跨區、各占多少 connections。SS 不量 bytes（用 nstat 或 ifconfig 才有），但
# connection count 已足夠回答「GCP TiDB 是否真的不連 IDC TiKV」這種 routing
# 真偽問題。
#
# Snapshot from .31 (controller)：ssh 到每台 host → 跑 ss -tn state established
# → 依 (remote_ip 所屬 region, local/remote port) 分組計數。
#
# Usage:
#   netflow-snapshot.sh --out-dir <path> --label <pre-run|mid-round|post-run>
#                       [--hosts "host1 host2 ..."]
#
# Hosts default:
#   IDC: 172.24.40.31 172.24.40.32 172.24.40.33 172.24.40.34
#   GCP: 10.160.152.11 10.160.152.12 10.160.152.13 10.160.152.14 10.160.152.15
#
# Ports of interest（per 0630.md §7）：
#   4000 TiDB / 2379 PD client / 2380 PD peer / 20160 TiKV /
#   26257 CRDB / 5433 YBDB YSQL / 7100 yb-master / 9100 yb-tserver
#
# Output:
#   <out-dir>/netflow-<label>.json — per-host per-port (idc|gcp|other) count
#
# Caveat:
#   - SS 只看 established connections at sample 瞬間；不是流量計量
#   - 跨區連線數 ≠ 跨區流量 bytes（idle connection 不產 bytes）
#   - fail-quiet per host：個別 host SSH 失敗不阻擋其他 host 統計

set -euo pipefail

OUT_DIR="" LABEL="snapshot"
HOSTS=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --out-dir) OUT_DIR=$2; shift 2 ;;
    --label) LABEL=$2; shift 2 ;;
    --hosts) HOSTS=$2; shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done
[[ -n "$OUT_DIR" ]] || { echo "missing --out-dir" >&2; exit 2; }
mkdir -p "$OUT_DIR"

: "${HOSTS:=172.24.40.31 172.24.40.32 172.24.40.33 172.24.40.34 10.160.152.11 10.160.152.12 10.160.152.13 10.160.152.14 10.160.152.15}"

PORTS="4000 2379 2380 20160 26257 5433 7100 9100"

# Classify IP into region (idc|gcp|other) by prefix.
ip_region() {
  case "$1" in
    172.24.*)   echo "idc" ;;
    10.160.152.*) echo "gcp" ;;
    *)          echo "other" ;;
  esac
}

OUT="$OUT_DIR/netflow-${LABEL}.json"
TMP=$(mktemp)
trap 'rm -f "$TMP"' EXIT

# JSON: { "label": ..., "timestamp": ..., "hosts": { "<ip>": { "<port>": { "idc": N, "gcp": N, "other": N } } } }
{
  echo "{"
  echo "  \"label\": \"$LABEL\","
  echo "  \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\","
  echo "  \"hosts\": {"

  host_count=0
  for h in $HOSTS; do
    [[ $host_count -gt 0 ]] && echo ","
    host_count=$((host_count + 1))
    echo -n "    \"$h\": {"

    # ss output: State Recv-Q Send-Q Local-Address:Port Peer-Address:Port
    # `-H` strips header; `-t` tcp; `-n` numeric; `state established` filter.
    # Parse: get local port (col 4 after :) and peer ip (col 5 before :).
    ss_out=$(ssh -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new \
                 root@"$h" "ss -H -tn state established 2>/dev/null" 2>/dev/null || echo "")
    if [[ -z "$ss_out" ]]; then
      echo " \"error\": \"ssh-failed-or-no-data\" }"
      continue
    fi

    port_first=1
    for port in $PORTS; do
      idc=0; gcp=0; other=0
      while IFS= read -r line; do
        # Match either local or peer side on this port.
        local_addr=$(echo "$line" | awk '{print $3}')
        peer_addr=$(echo "$line" | awk '{print $4}')
        local_port=$(echo "$local_addr" | awk -F: '{print $NF}')
        peer_port=$(echo "$peer_addr" | awk -F: '{print $NF}')

        if [[ "$local_port" == "$port" ]]; then
          peer_ip=$(echo "$peer_addr" | sed -E 's/:[0-9]+$//')
          case "$(ip_region "$peer_ip")" in
            idc) idc=$((idc + 1)) ;;
            gcp) gcp=$((gcp + 1)) ;;
            other) other=$((other + 1)) ;;
          esac
        elif [[ "$peer_port" == "$port" ]]; then
          peer_ip=$(echo "$peer_addr" | sed -E 's/:[0-9]+$//')
          case "$(ip_region "$peer_ip")" in
            idc) idc=$((idc + 1)) ;;
            gcp) gcp=$((gcp + 1)) ;;
            other) other=$((other + 1)) ;;
          esac
        fi
      done <<< "$ss_out"

      if [[ $((idc + gcp + other)) -gt 0 ]]; then
        [[ $port_first -eq 0 ]] && echo -n "," || port_first=0
        echo -n "
      \"$port\": {\"idc\": $idc, \"gcp\": $gcp, \"other\": $other}"
      fi
    done

    echo -n "
    }"
  done

  echo
  echo "  }"
  echo "}"
} > "$OUT"

echo "[netflow-snapshot] $LABEL → $OUT ($host_count hosts sampled)"
