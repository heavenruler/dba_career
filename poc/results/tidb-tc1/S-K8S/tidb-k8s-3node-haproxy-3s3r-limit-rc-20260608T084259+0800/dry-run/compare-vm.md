# compare-vm.md — phase-k8s actual vs VM baseline

Sources:
- actual: /tmp/poc-tpcc/artifacts/S-K8S/tidb-k8s-3node-haproxy-3s3r-limit-rc-20260608T084259+0800/dry-run/actual.yaml
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
- .k8s.pod_replicas.sql: k8s=2 vm=<absent>
- .k8s.pod_replicas.storage: k8s=3 vm=<absent>
- .k8s.pv_size.pd: k8s=10Gi vm=<absent>
- .k8s.pv_size.storage: k8s=100Gi vm=<absent>
- .k8s.resource_limits.cpu: k8s=2 vm=<absent>
- .k8s.resource_limits.memory: k8s=8Gi vm=<absent>
- .k8s.storage_class: k8s=local-path vm=<absent>
- .network.haproxy_backends: k8s=0 vm=3
- .network.nodeport: k8s=30004 vm=<absent>
- .split.strategy: k8s=tidb_split_placeholder vm=tidb_explicit_9table
- .network.haproxy_port: k8s=<absent> vm=4000
- .split.expected_shards_per_table: k8s=<absent> vm=3
- .split.expected_tables: k8s=<absent> vm=9
- .split.source_ref: k8s=<absent> vm=tests/common/prepare.sh:134-144
- .vm.nodes: k8s=<absent> vm=3
- .vm.per_node.pd: k8s=<absent> vm=1
- .vm.per_node.sql: k8s=<absent> vm=1
- .vm.per_node.storage: k8s=<absent> vm=1

## 🔀 PLATFORM-DERIVED (mapping)
- .phase_env.BASELINE_FAMILY: k8s=k8s vm=vm
- .phase_env.PHASE_NAME: k8s=phase-k8s vm=phase-baseline
- .phase_env.RESULT_SCOPE: k8s=S-K8S vm=S-BASE
- .topology: k8s=k8s-3node-haproxy-3s3r-limit vm=vm-3node-haproxy-3s3r
