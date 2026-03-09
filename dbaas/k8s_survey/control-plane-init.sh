#!/usr/bin/env bash
set -Eeuo pipefail

LOG_FILE="/var/log/control-plane-init.log"

K8S_VERSION="v1.29.15"
API_SERVER_IP="172.24.40.17"
POD_CIDR="10.244.0.0/16"
FLANNEL_URL="https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml"

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
  command -v kubectl >/dev/null 2>&1 || die "找不到 kubectl"
  command -v kubelet >/dev/null 2>&1 || die "找不到 kubelet"
  systemctl is-active containerd >/dev/null 2>&1 || die "containerd 未啟動"
}

pre_pull_images() {
  log "pre-pull images"
  kubeadm config images pull --kubernetes-version "${K8S_VERSION}"
}

run_init() {
  if [[ -f /etc/kubernetes/admin.conf ]]; then
    log "control-plane 已初始化，略過 kubeadm init"
    return
  fi

  log "run kubeadm init"
  kubeadm init \
    --kubernetes-version "${K8S_VERSION}" \
    --apiserver-advertise-address="${API_SERVER_IP}" \
    --pod-network-cidr="${POD_CIDR}" | tee -a "$LOG_FILE"
}

configure_kubectl() {
  log "configure kubectl for root"
  export KUBECONFIG=/etc/kubernetes/admin.conf
  mkdir -p /root/.kube
  cp -f /etc/kubernetes/admin.conf /root/.kube/config
  chmod 600 /root/.kube/config

  grep -q 'KUBECONFIG=/etc/kubernetes/admin.conf' /root/.bashrc || \
    echo 'export KUBECONFIG=/etc/kubernetes/admin.conf' >> /root/.bashrc
}

install_flannel() {
  export KUBECONFIG=/etc/kubernetes/admin.conf

  if kubectl get ns kube-flannel >/dev/null 2>&1; then
    log "kube-flannel namespace 已存在，略過 apply"
  else
    log "install flannel"
    kubectl apply -f "${FLANNEL_URL}"
  fi
}

show_join_command() {
  export KUBECONFIG=/etc/kubernetes/admin.conf
  log "join command"
  kubeadm token create --print-join-command | tee -a "$LOG_FILE"
}

post_check() {
  export KUBECONFIG=/etc/kubernetes/admin.conf
  log "post check"
  kubectl get nodes -o wide | tee -a "$LOG_FILE"
  kubectl get pods -A -o wide | tee -a "$LOG_FILE"
}

main() {
  require_root
  touch "$LOG_FILE"
  log "===== control-plane init start ====="
  check_prereq
  pre_pull_images
  run_init
  configure_kubectl
  install_flannel
  show_join_command
  post_check
  log "===== control-plane init done ====="
}

main "$@"
