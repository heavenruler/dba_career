#!/usr/bin/env bash
# Bootstrap the TPC-C client on .31:
#   - Verify go-tpc v1.0.12 installed (else exit; we don't auto-install yet)
#   - Create /tmp/poc-tpcc/{scripts,artifacts,bin}
#   - Sync tests/common/* (scripts + lib) to .31:/tmp/poc-tpcc/scripts
#
# Usage: ./bootstrap-client.sh
# Required env (caller injects via Makefile):
#   TPCC_CLIENT    (e.g. root@172.24.40.31)
#   TPCC_BASE      (e.g. /tmp/poc-tpcc)
#   GOTPC_VERSION  (e.g. v1.0.12)

set -euo pipefail
SELF_DIR=$(cd "$(dirname "$0")" && pwd)

: "${TPCC_CLIENT:?TPCC_CLIENT not set}"
: "${TPCC_BASE:=/tmp/poc-tpcc}"
: "${GOTPC_VERSION:=v1.0.12}"

echo "==> bootstrap TPC-C client: $TPCC_CLIENT  (base=$TPCC_BASE)"

# 1. Verify go-tpc version on remote
remote_ver=$(ssh -o StrictHostKeyChecking=accept-new "$TPCC_CLIENT" \
  'go-tpc version 2>&1 | grep "Release version" | awk "{print \$NF}"' || true)
if [[ -z "$remote_ver" ]]; then
  echo "ERROR: go-tpc not installed on $TPCC_CLIENT" >&2
  echo "Install manually:" >&2
  echo "  ssh $TPCC_CLIENT 'curl --proto =https --tlsv1.2 -sSf https://raw.githubusercontent.com/pingcap/go-tpc/master/install.sh | sh'" >&2
  exit 1
fi
echo "    remote go-tpc release: $remote_ver"
if [[ "v${remote_ver}" != "$GOTPC_VERSION" ]]; then
  echo "WARN: remote go-tpc version (v${remote_ver}) != expected ($GOTPC_VERSION); continuing but check compatibility." >&2
fi

# 2. Make remote directories
ssh "$TPCC_CLIENT" "mkdir -p $TPCC_BASE/scripts $TPCC_BASE/artifacts $TPCC_BASE/bin"

# 3. Rsync scripts (this dir except .git/swap files)
echo "==> rsync scripts -> $TPCC_CLIENT:$TPCC_BASE/scripts/"
rsync -az --delete \
  --exclude='*.swp' \
  --exclude='.DS_Store' \
  "$SELF_DIR/" "$TPCC_CLIENT:$TPCC_BASE/scripts/"

# 4. Make scripts executable on remote
ssh "$TPCC_CLIENT" "chmod +x $TPCC_BASE/scripts/*.sh $TPCC_BASE/scripts/lib/*.sh 2>/dev/null || true"

# 5. Record bin metadata
ssh "$TPCC_CLIENT" "
  set -e
  echo 'go-tpc release: $remote_ver' > $TPCC_BASE/bin/go-tpc.meta
  command -v go-tpc | xargs -I{} sh -c 'echo path=\"{}\"; sha256sum \"{}\" 2>/dev/null || true' >> $TPCC_BASE/bin/go-tpc.meta
  cat $TPCC_BASE/bin/go-tpc.meta
"

echo "==> bootstrap complete"
