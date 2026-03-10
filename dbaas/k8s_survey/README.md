OS: AlmaLinux 8.10
Kubernetes: v1.29.15
Runtime: containerd
CNI: flannel
Proxy: http://sproxy.104-dev.com.tw:3128

Nodes:

l-k8s-labroom-1 = 172.24.40.17
l-k8s-labroom-2 = 172.24.40.18
l-k8s-labroom-3 = 172.24.40.19
l-k8s-labroom-4 = 172.24.40.20

# 四台都先做
/root/k8s-lab/node-baseline.sh

# 只在 labroom-1
/root/k8s-lab/control-plane-init.sh

# 在 labroom-2/3/4
/root/k8s-lab/worker-join.sh

# 回 labroom-1 驗證
/root/k8s-lab/post-check.sh
