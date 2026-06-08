#!/usr/bin/env bash
# phase-k8s/cell-cleanup-gate.sh — clean K8s state between cells.
# Reuses k3s server (.32). Per-DB helm uninstall + namespace delete +
# PVC delete + local-path PV reclaim + FS clean + final no-residue check.
#
# Usage:
#   cell-cleanup-gate.sh --db <tidb|crdb|ybdb> --namespace <ns>
#
# Required env:
#   K3S_HOST       — K3s server IP (e.g., 172.24.40.32)
#   K3S_AGENTS     — comma-separated agent IPs (for FS clean; default .33,.34)

set -euo pipefail

DB=""
NAMESPACE=""
while [[ $# -gt 0 ]]; do
  case $1 in
    --db) DB=$2; shift 2 ;;
    --namespace) NAMESPACE=$2; shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 1 ;;
  esac
done

: "${DB:?--db required}"
: "${NAMESPACE:?--namespace required}"
: "${K3S_HOST:?missing}"
: "${K3S_AGENTS:=172.24.40.33,172.24.40.34}"

KUBECTL="ssh root@${K3S_HOST} k3s kubectl"

echo "[cleanup-gate] DB=$DB namespace=$NAMESPACE"

# 1) Helm uninstall (release name varies per DB)
case "$DB" in
  tidb)
    # TiDB Operator + TidbCluster CR (operator helm in default ns)
    $KUBECTL -n "$NAMESPACE" delete tidbcluster --all --wait=true --timeout=120s 2>&1 || true
    ssh root@"$K3S_HOST" "helm uninstall tidb-operator -n tidb-admin 2>&1" || true
    ;;
  crdb)
    ssh root@"$K3S_HOST" "helm uninstall cockroachdb -n $NAMESPACE 2>&1" || true
    ;;
  ybdb)
    ssh root@"$K3S_HOST" "helm uninstall yugabyte -n $NAMESPACE 2>&1" || true
    ;;
esac

# 2) Delete PVCs in namespace (helm uninstall keeps statefulset PVCs)
echo "[cleanup-gate] deleting PVCs in $NAMESPACE..."
$KUBECTL -n "$NAMESPACE" delete pvc --all --wait=false --timeout=60s 2>&1 || true

# 3) Wait pods + PVCs gone
echo "[cleanup-gate] waiting pods gone..."
for _ in $(seq 30); do
  count=$($KUBECTL -n "$NAMESPACE" get pods --no-headers 2>/dev/null | wc -l)
  [[ "$count" -eq 0 ]] && break
  sleep 5
done

# 4) Delete namespace
echo "[cleanup-gate] deleting namespace $NAMESPACE..."
$KUBECTL delete namespace "$NAMESPACE" --wait=false --timeout=60s 2>&1 || true

# 5) Local-path PV reclaim: patch reclaimPolicy=Delete + delete Released PVs
echo "[cleanup-gate] reclaiming Released PVs..."
ssh root@"$K3S_HOST" "k3s kubectl get pv -o json | jq -r '.items[] | select(.status.phase==\"Released\" or .spec.claimRef.namespace==\"$NAMESPACE\") | .metadata.name'" 2>/dev/null | while read -r pv; do
  [[ -z "$pv" ]] && continue
  $KUBECTL patch pv "$pv" -p '{"spec":{"persistentVolumeReclaimPolicy":"Delete"}}' 2>&1 || true
  $KUBECTL delete pv "$pv" --wait=false 2>&1 || true
done

# 6) Local-path FS clean on all k3s nodes (k3s storage path = /opt/tidb/data per role config)
echo "[cleanup-gate] FS clean /opt/tidb/data/* on all k3s nodes..."
IFS=',' read -ra AGENT_IPS <<< "$K3S_AGENTS"
for ip in "$K3S_HOST" "${AGENT_IPS[@]}"; do
  ssh -o ConnectTimeout=5 root@"$ip" 'rm -rf /opt/tidb/data/pvc-* 2>&1' || echo "  [warn] FS clean failed on $ip"
done

# 7) Final no-residue check
echo "[cleanup-gate] verifying no residue..."
residue_pods=$($KUBECTL -n "$NAMESPACE" get pods --no-headers 2>/dev/null | wc -l || echo 0)
residue_pvcs=$($KUBECTL -n "$NAMESPACE" get pvc --no-headers 2>/dev/null | wc -l || echo 0)
if [[ "$residue_pods" -gt 0 ]] || [[ "$residue_pvcs" -gt 0 ]]; then
  echo "[cleanup-gate] WARN: $residue_pods pod(s) + $residue_pvcs pvc(s) remain in $NAMESPACE" >&2
  $KUBECTL -n "$NAMESPACE" get pods,pvc 2>&1 || true
  exit 1
fi

echo "[cleanup-gate] OK — namespace $NAMESPACE clean"
