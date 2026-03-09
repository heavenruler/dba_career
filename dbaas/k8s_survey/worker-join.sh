#!/usr/bin/env bash
set -Eeuo pipefail

LOG_FILE="/var/log/worker-join.log"

JOIN_CMD='kubeadm join 172.24.40.17:6443 --token {FIXME} --discovery-token-ca-cert-hash sha256:{FIXME}'

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

check_prereq() {
  command -v kubeadm >/dev/null 2>&1 || die "找不到 kubeadm"
  systemctl is-active containerd >/dev/null 2>&1 || die "containerd 未啟動"
}

already_joined() {
  [[ -f /etc/kubernetes/kubelet.conf ]]
}

run_join() {
  if already_joined; then
    log "本機似乎已 join，略過 kubeadm join"
    return
  fi

  log "run kubeadm join"
  eval "${JOIN_CMD}" | tee -a "$LOG_FILE"
}

post_check() {
  log "post check"
  systemctl is-active kubelet | tee -a "$LOG_FILE" || true
  journalctl -u kubelet -n 30 --no-pager | tee -a "$LOG_FILE" || true
}

main() {
  require_root
  touch "$LOG_FILE"
  log "===== worker join start ====="
  check_prereq
  run_join
  post_check
  log "===== worker join done ====="
}

main "$@"
