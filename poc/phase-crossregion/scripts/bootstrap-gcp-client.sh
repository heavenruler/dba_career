#!/usr/bin/env bash
# phase-crossregion/scripts/bootstrap-gcp-client.sh
#
# A-A-RO/A-A 前置：g-test-poc-5 (.15) 缺 go-tpc binary + tests/common 腳本
# （之前只裝了 psql/mysql/bc，見 phase2-probe-clients）。run-vm6-aa.sh 的 GCP
# 側呼叫 /tmp/poc-tpcc/scripts/run.sh（tests/common 全套，含 lib/*.sh +
# coldreset-*.sh + gate-isolation.sh），缺檔會 fail-closed。
#
# 做法：不從 Mac 直連 .15（硬規則 4：GCP 內網只能從 .31/.15 到達）；一律經
# .31 nested ssh/rsync：
#   1. go-tpc binary：從 .31（已由 phase2-bootstrap 驗證安裝）cat | ssh 落地 .15
#      （比照 phase5-crdb-deploy 對 cockroach binary 的既有作法）
#   2. tests/common 全套：從 .31:/tmp/poc-tpcc/scripts/ rsync → .15 同路徑
#   3. mkdir -p /tmp/poc-tpcc/{scripts,artifacts,bin} on .15
#
# Usage: bootstrap-gcp-client.sh (no args; env TPCC_CLIENT / GCP_CLIENT_IP overridable)
# Fail-closed: go-tpc / run.sh 缺一即 exit 1（GCP 側 aaro-smoke 會全滅，先擋在這）

set -euo pipefail

: "${TPCC_CLIENT:=root@172.24.40.31}"
: "${GCP_CLIENT_IP:=10.160.152.15}"

SSH_NC=(-o StrictHostKeyChecking=accept-new -o ConnectTimeout=10)

echo "==> bootstrap-gcp-client: target=$GCP_CLIENT_IP (via $TPCC_CLIENT)"

ssh "${SSH_NC[@]}" "$TPCC_CLIENT" "ssh ${SSH_NC[*]} root@$GCP_CLIENT_IP 'mkdir -p /tmp/poc-tpcc/scripts /tmp/poc-tpcc/artifacts /tmp/poc-tpcc/bin'"

echo "==> go-tpc: check on .15, install from .31 binary if missing"
have_gotpc=$(ssh "${SSH_NC[@]}" "$TPCC_CLIENT" "ssh ${SSH_NC[*]} root@$GCP_CLIENT_IP 'command -v go-tpc' 2>/dev/null" || true)
if [[ -z "$have_gotpc" ]]; then
  echo "    go-tpc missing on .15 — copying binary from .31"
  ssh "${SSH_NC[@]}" "$TPCC_CLIENT" \
    "cat \$(command -v go-tpc) | ssh ${SSH_NC[*]} root@$GCP_CLIENT_IP 'cat > /usr/local/bin/go-tpc && chmod +x /usr/local/bin/go-tpc'"
else
  echo "    go-tpc already present: $have_gotpc"
fi
ssh "${SSH_NC[@]}" "$TPCC_CLIENT" "ssh ${SSH_NC[*]} root@$GCP_CLIENT_IP 'go-tpc version 2>&1 | head -3'" \
  || { echo "[bootstrap-gcp-client] FAIL: go-tpc not runnable on .15" >&2; exit 1; }

echo "==> tests/common (run.sh + lib/*.sh + coldreset-*.sh + gate-isolation.sh + probe-iso-latency.sh): rsync .31 -> .15"
ssh "${SSH_NC[@]}" "$TPCC_CLIENT" \
  "rsync -az --delete -e 'ssh ${SSH_NC[*]}' /tmp/poc-tpcc/scripts/ root@$GCP_CLIENT_IP:/tmp/poc-tpcc/scripts/"
ssh "${SSH_NC[@]}" "$TPCC_CLIENT" \
  "ssh ${SSH_NC[*]} root@$GCP_CLIENT_IP 'chmod +x /tmp/poc-tpcc/scripts/*.sh /tmp/poc-tpcc/scripts/lib/*.sh /tmp/poc-tpcc/scripts/crossregion/*.sh 2>/dev/null || true'"

echo "==> phase-crossregion/scripts symlink (wan-probe.sh path derivation; WAN_PROBE disabled on GCP side but keep layout symmetric)"
ssh "${SSH_NC[@]}" "$TPCC_CLIENT" \
  "ssh ${SSH_NC[*]} root@$GCP_CLIENT_IP 'mkdir -p /tmp/phase-crossregion && ln -sfn /tmp/poc-tpcc/scripts/crossregion /tmp/phase-crossregion/scripts'"

echo "==> verify run.sh present + executable on .15"
ssh "${SSH_NC[@]}" "$TPCC_CLIENT" "ssh ${SSH_NC[*]} root@$GCP_CLIENT_IP 'test -x /tmp/poc-tpcc/scripts/run.sh'" \
  || { echo "[bootstrap-gcp-client] FAIL: /tmp/poc-tpcc/scripts/run.sh missing/not executable on .15" >&2; exit 1; }

echo "==> bootstrap-gcp-client PASS — go-tpc + tests/common ready on $GCP_CLIENT_IP"
