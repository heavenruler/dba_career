#!/usr/bin/env bash
set -Eeuo pipefail

LOG_FILE="/var/log/post-check.log"

KUBECONFIG_PATH="/etc/kubernetes/admin.conf"
NODEPORT_URL="http://172.24.40.20:31374"
CLUSTER_SERVICE_NAME="nginx"

log() {
  echo "[$(date '+%F %T')] $*" | tee -a "$LOG_FILE"
}

die() {
  log "ERROR: $*"
  exit 1
}

require_root() {
  [[ "${EUID}" -eq 0 ]] || die "請用 root 執行"
}

check_kubeconfig() {
  [[ -f "${KUBECONFIG_PATH}" ]] || die "找不到 ${KUBECONFIG_PATH}"
  export KUBECONFIG="${KUBECONFIG_PATH}"
}

show_cluster_status() {
  log "===== nodes ====="
  kubectl get nodes -o wide | tee -a "$LOG_FILE"

  log "===== pods all namespaces ====="
  kubectl get pods -A -o wide | tee -a "$LOG_FILE"

  log "===== cluster info ====="
  kubectl cluster-info | tee -a "$LOG_FILE"
}

show_workload_status() {
  log "===== deploy svc pods ====="
  kubectl get deploy,svc,pods -o wide | tee -a "$LOG_FILE" || true

  log "===== endpoints nginx ====="
  kubectl get endpoints "${CLUSTER_SERVICE_NAME}" -o yaml | tee -a "$LOG_FILE" || true
}

test_nodeport() {
  log "===== curl nodeport ====="
  curl -fsS "${NODEPORT_URL}" | head -20 | tee -a "$LOG_FILE"
}

test_clusterip_dns() {
  log "===== curl service from pod ====="
  kubectl run curl-test \
    --image=curlimages/curl:8.7.1 \
    -it --rm --restart=Never -- \
    curl -fsS "http://${CLUSTER_SERVICE_NAME}" | head -20 | tee -a "$LOG_FILE"
}

main() {
  require_root
  touch "$LOG_FILE"
  log "===== post check start ====="
  check_kubeconfig
  show_cluster_status
  show_workload_status
  test_nodeport
  test_clusterip_dns
  log "===== post check done ====="
}

main "$@"
