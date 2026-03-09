#!/usr/bin/env bash
set -Eeuo pipefail

LOG_FILE="/var/log/node-baseline.log"

PROXY_URL="http://sproxy.104-dev.com.tw:3128"
NO_PROXY_LIST="localhost,127.0.0.1,::1,172.24.40.17,172.24.40.18,172.24.40.19,172.24.40.20,10.96.0.0/12,10.244.0.0/16,10.0.0.0/8,192.168.0.0/16,.svc,.cluster.local"

HOSTS_BLOCK=$(cat <<'EOF'
172.24.40.17 l-k8s-labroom-1
172.24.40.18 l-k8s-labroom-2
172.24.40.19 l-k8s-labroom-3
172.24.40.20 l-k8s-labroom-4
EOF
)

PKGS=(
  vim
  curl
  wget
  jq
  bash-completion
  iproute-tc
  conntrack-tools
  socat
  ebtables
  ethtool
  chrony
)

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

ensure_hosts() {
  log "ensure /etc/hosts"
  while read -r line; do
    [[ -z "${line}" ]] && continue
    grep -qF "${line}" /etc/hosts || echo "${line}" >> /etc/hosts
  done <<< "${HOSTS_BLOCK}"
}

disable_swap() {
  log "disable swap"
  swapoff -a || true
  cp -a /etc/fstab "/etc/fstab.bak.$(date +%Y%m%d-%H%M%S)"
  sed -ri '/\sswap\s/s/^/#/' /etc/fstab
}

configure_profile_proxy() {
  log "configure /etc/profile.d/proxy.sh"
  cat > /etc/profile.d/proxy.sh <<EOF
export http_proxy=${PROXY_URL}
export https_proxy=${PROXY_URL}
export HTTP_PROXY=${PROXY_URL}
export HTTPS_PROXY=${PROXY_URL}
export no_proxy=${NO_PROXY_LIST}
export NO_PROXY=${NO_PROXY_LIST}
EOF
  chmod 0644 /etc/profile.d/proxy.sh
}

configure_dnf_proxy() {
  log "ensure dnf proxy"
  if grep -q '^proxy=' /etc/yum.conf; then
    sed -ri "s|^proxy=.*|proxy=${PROXY_URL}|" /etc/yum.conf
  else
    echo "proxy=${PROXY_URL}" >> /etc/yum.conf
  fi
}

install_packages() {
  log "install packages"
  dnf install -y "${PKGS[@]}"
}

load_kernel_modules() {
  log "configure kernel modules"
  cat > /etc/modules-load.d/k8s.conf <<'EOF'
overlay
br_netfilter
EOF

  modprobe overlay
  modprobe br_netfilter
}

configure_sysctl() {
  log "configure sysctl"
  cat > /etc/sysctl.d/99-k8s.conf <<'EOF'
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
vm.swappiness = 1
EOF
  sysctl --system
}

configure_containerd_proxy() {
  log "configure containerd proxy"
  mkdir -p /etc/systemd/system/containerd.service.d
  cat > /etc/systemd/system/containerd.service.d/http-proxy.conf <<EOF
[Service]
Environment="HTTP_PROXY=${PROXY_URL}"
Environment="HTTPS_PROXY=${PROXY_URL}"
Environment="NO_PROXY=${NO_PROXY_LIST}"
EOF
}

configure_kubelet_proxy() {
  log "configure kubelet proxy"
  mkdir -p /etc/systemd/system/kubelet.service.d
  cat > /etc/systemd/system/kubelet.service.d/http-proxy.conf <<EOF
[Service]
Environment="HTTP_PROXY=${PROXY_URL}"
Environment="HTTPS_PROXY=${PROXY_URL}"
Environment="NO_PROXY=${NO_PROXY_LIST}"
EOF
}

restart_services_if_exist() {
  log "reload systemd"
  systemctl daemon-reload

  if systemctl list-unit-files | grep -q '^containerd.service'; then
    systemctl restart containerd
  fi

  if systemctl list-unit-files | grep -q '^kubelet.service'; then
    systemctl restart kubelet || true
  fi

  systemctl enable chronyd --now || true
}

post_check() {
  log "post check"
  echo "===== uname -r =====" | tee -a "$LOG_FILE"
  uname -r | tee -a "$LOG_FILE"

  echo "===== free -h =====" | tee -a "$LOG_FILE"
  free -h | tee -a "$LOG_FILE"

  echo "===== swapon --show =====" | tee -a "$LOG_FILE"
  swapon --show | tee -a "$LOG_FILE" || true

  echo "===== lsmod =====" | tee -a "$LOG_FILE"
  lsmod | egrep 'overlay|br_netfilter' | tee -a "$LOG_FILE" || true

  echo "===== sysctl =====" | tee -a "$LOG_FILE"
  sysctl net.ipv4.ip_forward net.bridge.bridge-nf-call-iptables net.bridge.bridge-nf-call-ip6tables | tee -a "$LOG_FILE"

  echo "===== proxy =====" | tee -a "$LOG_FILE"
  grep -E '^proxy=' /etc/yum.conf | tee -a "$LOG_FILE" || true
  grep -E 'http_proxy|https_proxy|NO_PROXY|no_proxy' /etc/profile.d/proxy.sh | tee -a "$LOG_FILE"

  echo "===== hosts =====" | tee -a "$LOG_FILE"
  getent hosts l-k8s-labroom-1 l-k8s-labroom-2 l-k8s-labroom-3 l-k8s-labroom-4 | tee -a "$LOG_FILE"

  if systemctl list-unit-files | grep -q '^containerd.service'; then
    echo "===== containerd =====" | tee -a "$LOG_FILE"
    systemctl is-active containerd | tee -a "$LOG_FILE" || true
  fi

  if systemctl list-unit-files | grep -q '^kubelet.service'; then
    echo "===== kubelet =====" | tee -a "$LOG_FILE"
    systemctl is-active kubelet | tee -a "$LOG_FILE" || true
  fi
}

main() {
  require_root
  touch "$LOG_FILE"
  log "===== node baseline start ====="
  ensure_hosts
  disable_swap
  configure_profile_proxy
  configure_dnf_proxy
  install_packages
  load_kernel_modules
  configure_sysctl
  configure_containerd_proxy
  configure_kubelet_proxy
  restart_services_if_exist
  post_check
  log "===== node baseline done ====="
}

main "$@"
