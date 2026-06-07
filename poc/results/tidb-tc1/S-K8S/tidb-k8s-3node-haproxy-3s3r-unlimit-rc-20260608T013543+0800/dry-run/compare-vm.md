# compare-vm.md — phase-k8s actual vs VM baseline

Sources:
- actual: /tmp/poc-tpcc/artifacts/S-K8S/tidb-k8s-3node-haproxy-3s3r-unlimit-rc-20260608T013543+0800/dry-run/actual.yaml
- vm baseline: /tmp/poc-tpcc/phase-k8s/expected/vm-3node-haproxy-3s3r-tidb.yaml

## ❌ DENY (exit 1 if any)
- (none)

## ⚠️ WARN (codex review)
- (none)

## ✅ ALLOW (platform diff)
- .k8s.cluster_name: k8s=tidb-poc vm=<absent>
- .k8s.db_image_prefix: k8s=pingcap/tidb vm=<absent>
- .k8s.namespace: k8s=tidb-cluster vm=<absent>
- .k8s.pod_replicas.pd: k8s=3 vm=<absent>
- .k8s.pod_replicas.tidb: k8s=2 vm=<absent>
- .k8s.pod_replicas.tikv: k8s=3 vm=<absent>
- .k8s.pv_size.pd: k8s=10Gi vm=<absent>
- .k8s.pv_size.tikv: k8s=100Gi vm=<absent>
- .k8s.storage_class: k8s=local-path vm=<absent>
- .network.haproxy_backends: k8s=0 vm=3
- .network.nodeport: k8s=30004 vm=<absent>
- .network.haproxy_port: k8s=<absent> vm=4000
- .vm.nodes: k8s=<absent> vm=3
- .vm.per_node.pd: k8s=<absent> vm=1
- .vm.per_node.tidb: k8s=<absent> vm=1
- .vm.per_node.tikv: k8s=<absent> vm=1

## 🔀 PLATFORM-DERIVED (mapping)
- .phase_env.BASELINE_FAMILY: k8s=k8s vm=vm
- .phase_env.PHASE_NAME: k8s=phase-k8s vm=phase-baseline
- .phase_env.RESULT_SCOPE: k8s=S-K8S vm=S-BASE
- .topology: k8s=k8s-3node-haproxy-3s3r-unlimit vm=vm-3node-haproxy-3s3r
