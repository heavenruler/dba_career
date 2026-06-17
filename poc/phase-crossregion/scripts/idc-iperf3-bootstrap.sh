#!/usr/bin/env bash
# phase-crossregion/scripts/idc-iperf3-bootstrap.sh
#
# 在 IDC dbhost(s) 安裝 iperf3 並起 iperf3-server.service。
# 為 wan-probe.sh opt-in mode (WAN_PROBE_IPERF=1) 預備：
#   - GCP 端由 iac-gcp/main.tf startup-script 預裝（per phase-crossregion §6 #4）
#   - IDC 端由此 script 補裝（無 IaC，純 SSH 推送）
#
# 範圍：
#   - target = 172.24.40.32 (idc-dbhost-1；wan-probe 的 iperf3 endpoint)
#   - 預設 --target 即 .32；如要多台改 --target host1 --target host2 ...
#
# 安全考量（必讀）：
#   - iperf3 -s 監聽 0.0.0.0:5201；任何能連到該 host 5201 都可佔頻寬
#   - IDC 環境通常 firewall 是 iptables / vendor FW；本 script **不開** firewall rule
#   - 建議 ops 在 IDC 邊界 FW 限制 5201 只接受 GCP IAP / VPC peering 來源
#   - sweep 結束後 stop/disable: systemctl disable --now iperf3-server
#
# 用法：
#   bash idc-iperf3-bootstrap.sh --dry-run                    # 預設 target=.32
#   bash idc-iperf3-bootstrap.sh --dry-run --target 172.24.40.32
#   bash idc-iperf3-bootstrap.sh --execute --target 172.24.40.32
#   bash idc-iperf3-bootstrap.sh --execute --target 172.24.40.32 --target 172.24.40.33
#
# Env overrides：
#   SSH_USER          (default root)
#   IPERF_PORT        (default 5201)
#
# Exit:
#   0 = PASS
#   1 = FAIL（SSH 失敗 / install 失敗 / service start 失敗 / 不合法 arg）

set -euo pipefail

TARGETS=()
MODE=""
while [[ $# -gt 0 ]]; do
  case $1 in
    --dry-run)  MODE=dry-run; shift ;;
    --execute)  MODE=execute; shift ;;
    --target)   TARGETS+=("$2"); shift 2 ;;
    -h|--help)
      sed -n '2,30p' "$0"
      exit 0
      ;;
    *) echo "unknown arg: $1" >&2; exit 1 ;;
  esac
done

[[ "$MODE" == "dry-run" || "$MODE" == "execute" ]] || {
  echo "--dry-run or --execute required (default execute 不允許)" >&2
  exit 1
}

# 預設 target = idc-dbhost-1 (.32)，與 wan-probe.sh IDC_DBHOST1_ADDR 對齊
if [[ ${#TARGETS[@]} -eq 0 ]]; then
  TARGETS=("172.24.40.32")
fi

: "${SSH_USER:=root}"
: "${IPERF_PORT:=5201}"

# 遠端要跑的命令（multi-line；單一 here-doc 透過 ssh stdin 餵）
build_remote_script() {
  cat <<'REMOTE_EOF'
set -euo pipefail

# 1. install iperf3
if command -v iperf3 >/dev/null 2>&1; then
  echo "[remote] iperf3 already installed: $(iperf3 --version | head -1)"
else
  echo "[remote] installing iperf3 via dnf"
  dnf install -y iperf3
fi

# 2. 寫 systemd unit
cat > /etc/systemd/system/iperf3-server.service <<'UNIT_EOF'
[Unit]
Description=iperf3 server (WAN probe)
After=network-online.target

[Service]
ExecStart=/usr/bin/iperf3 -s -p __IPERF_PORT__
Restart=always

[Install]
WantedBy=multi-user.target
UNIT_EOF

# 3. enable + start
systemctl daemon-reload
systemctl enable --now iperf3-server

# 4. verify
sleep 1
systemctl is-active iperf3-server
ss -ltnp 2>/dev/null | grep ":__IPERF_PORT__" || echo "[remote][warn] port __IPERF_PORT__ not listening yet"
REMOTE_EOF
}

REMOTE_SCRIPT=$(build_remote_script | sed "s/__IPERF_PORT__/${IPERF_PORT}/g")

echo "[idc-iperf3-bootstrap] mode=$MODE targets=(${TARGETS[*]}) port=$IPERF_PORT user=$SSH_USER"

for host in "${TARGETS[@]}"; do
  echo "----- target=$host -----"
  if [[ "$MODE" == "dry-run" ]]; then
    echo "[dry-run] ssh ${SSH_USER}@${host} bash -s <<'EOF'"
    echo "$REMOTE_SCRIPT" | sed 's/^/[dry-run]   /'
    echo "[dry-run] EOF"
  else
    echo "[execute] ssh ${SSH_USER}@${host} bash -s"
    ssh -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new \
        "${SSH_USER}@${host}" bash -s <<< "$REMOTE_SCRIPT" || {
      echo "[idc-iperf3-bootstrap] FAIL on $host" >&2
      exit 1
    }
  fi
done

echo "[idc-iperf3-bootstrap] PASS mode=$MODE targets=(${TARGETS[*]})"
exit 0
