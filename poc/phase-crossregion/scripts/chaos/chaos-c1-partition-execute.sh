#!/usr/bin/env bash
# chaos-c1-partition-execute.sh — REAL execution (new file, planner
# chaos-c1-partition-plan.sh stays planner-only per project rule).
#
# Spec: phase-crossregion/chaos/C1.md — GCP partition (WAN drop,
# bi-directional, full CIDR, no port filter).
#
# Difference from the plan script: applies the iptables DROP on ALL 3 IDC
# DB hosts AND ALL 3 GCP DB hosts (a true region-wide partition), not just
# a single --target-host — C1.md's injection commands are written as
# "IDC 側阻擋 GCP traffic" / "GCP 側阻擋 IDC traffic（對稱）" with no
# single-host qualifier, so a faithful reproduction needs all 6 DB hosts.
#
# Usage:
#   bash chaos-c1-partition-execute.sh --duration <sec> --artifact-dir <dir> \
#     [--idc-hosts "ip1 ip2 ip3"] [--gcp-hosts "ip1 ip2 ip3"] [--dry-run]
#
# Restore is automatic after --duration, and additionally trap-guarded so
# a script interrupt still removes the DROP rules (never leaves a real
# partition hanging on operator error).
#
# 2026-08-07 safety fix (post-incident): a real run of this script caused
# an UNCONTROLLED partition lasting ~4 minutes instead of the intended
# duration. Root cause: the orchestrator host (--orchestrator-ip, default
# 172.24.40.31) is itself inside $IDC_CIDR, so once a GCP host's inbound
# DROP-from-$IDC_CIDR rule took effect, the orchestrator's own ssh_c call
# applying/removing that very rule could never receive its response —
# ssh has no total-execution timeout (only ConnectTimeout, which only
# bounds the initial handshake), so it hung indefinitely. Manual recovery
# required routing through a third host outside both CIDRs. Fixed with two
# independent layers, per explicit operator decision:
#   1. Whitelist: an ACCEPT rule for $ORCHESTRATOR_IP is inserted (position
#      1, before the broader DROP) on every GCP host, so the orchestrator's
#      own control-plane traffic is never blocked by the CIDR-wide rule.
#      This does not weaken the test: the DB cluster's own SQL/PD/TiKV/raft
#      traffic between IDC and GCP is still fully blocked; only the
#      out-of-band management path is excluded, matching standard chaos-
#      engineering practice of keeping a control channel outside the blast
#      radius.
#   2. Self-expiring safety net: BEFORE applying any DROP rule on a host,
#      a self-contained background timer is launched ON THAT HOST (not
#      depending on the orchestrator at all) that removes the rule after
#      $SELF_HEAL_GRACE_SEC seconds past --duration, regardless of whether
#      the orchestrator's own restore() ever runs. restore() still attempts
#      immediate removal for a clean, fast recovery — the timer is the
#      backstop if that attempt itself hangs or the orchestrator dies.

set -uo pipefail  # NOT -e: restore must run even if a mid-script ssh fails

DURATION=""
ARTIFACT_DIR=""
DB=""
IDC_HOSTS="172.24.40.32 172.24.40.33 172.24.40.34"
GCP_HOSTS="10.160.152.11 10.160.152.12 10.160.152.13"
IDC_CIDR="172.24.0.0/16"
GCP_CIDR="10.160.152.0/24"
ORCHESTRATOR_IP="172.24.40.31"
SELF_HEAL_GRACE_SEC=15
DRY_RUN=0

usage() {
  cat <<'EOF'
Usage: chaos-c1-partition-execute.sh --db tidb|crdb|ybdb --duration <sec> --artifact-dir <dir>
  [--idc-hosts "ip1 ip2 ip3"] [--gcp-hosts "ip1 ip2 ip3"]
  [--orchestrator-ip ip] [--self-heal-grace-sec N] [--dry-run]
EOF
  exit 2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --db)                   DB=$2; shift 2 ;;
    --duration)             DURATION=$2; shift 2 ;;
    --artifact-dir)         ARTIFACT_DIR=$2; shift 2 ;;
    --idc-hosts)            IDC_HOSTS=$2; shift 2 ;;
    --gcp-hosts)            GCP_HOSTS=$2; shift 2 ;;
    --orchestrator-ip)      ORCHESTRATOR_IP=$2; shift 2 ;;
    --self-heal-grace-sec)  SELF_HEAL_GRACE_SEC=$2; shift 2 ;;
    --dry-run)              DRY_RUN=1; shift ;;
    -h|--help)              usage ;;
    *) echo "unknown arg: $1" >&2; usage ;;
  esac
done
[[ -z "$DURATION" || -z "$ARTIFACT_DIR" || -z "$DB" ]] && usage
[[ "$DURATION" =~ ^[0-9]+$ ]] || { echo "--duration must be integer seconds" >&2; exit 2; }
# 2026-08-10 fix (audit finding F-008): this script previously had NO --db
# flag and unconditionally probed a hardcoded TiDB MySQL endpoint
# (172.24.40.32:4000). When run against YugabyteDB/CockroachDB environments
# (which don't run a MySQL service on that port at all), every single probe
# failed regardless of whether the WAN partition itself affected the
# database — confirmed against raw artifacts: YBDB/CRDB P-A
# error-rate-by-sec.txt are 30/30 "err" (100%, before/during/after identical),
# while TiDB's are 30/30 "ok" — that split reflects "does this environment
# run tidb-4000" not "does this DB tolerate a WAN partition". --db is now
# required and selects the correct protocol/port/probe query per DB.
[[ "$DB" =~ ^(tidb|crdb|ybdb|galera)$ ]] || { echo "--db must be tidb|crdb|ybdb|galera" >&2; exit 2; }
# galera（G4，2026-08-13）：全 6 台皆完整副本、無 shard/leader 概念，partition
# 後兩側都會失去 majority（6 節點 majority=4，3v3 兩側都是 minority）——跟
# RTO-RPO-methodology.md §2.1 P-B row 描述的「兩區皆 minority ⇒ 全 cluster
# 寫拒」是同一種結果，等同 C1 對 Galera 只有一種 placement 可測（不像
# tidb/crdb/ybdb 有 P-A/P-B 差異）。密碼一律走 GALERA_BENCH_PASSWORD 環境變數。
if [[ "$DB" == "galera" ]]; then
  : "${GALERA_BENCH_PASSWORD:?missing GALERA_BENCH_PASSWORD}"
fi

log() { echo "[c1-execute] $(date -u '+%Y-%m-%dT%H:%M:%S.%3NZ') $*"; }

mkdir -p "$ARTIFACT_DIR"
log "duration=${DURATION}s idc_hosts=[$IDC_HOSTS] gcp_hosts=[$GCP_HOSTS] orchestrator_ip=$ORCHESTRATOR_IP self_heal_grace=${SELF_HEAL_GRACE_SEC}s dry_run=$DRY_RUN"

# timeout wraps every ssh_c call: belt-and-suspenders on top of the
# whitelist/self-heal fixes above — no single ssh_c call may hang past 10s.
ssh_c() { timeout 10 ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=5 root@"$1" "$2"; }

# ---- pre-injection snapshot ----
: > "$ARTIFACT_DIR/iptables-rules-before.txt"
for h in $IDC_HOSTS $GCP_HOSTS; do
  echo "=== $h ===" >> "$ARTIFACT_DIR/iptables-rules-before.txt"
  if [[ "$DRY_RUN" -eq 0 ]]; then
    ssh_c "$h" "iptables -L INPUT -n; iptables -L OUTPUT -n" >> "$ARTIFACT_DIR/iptables-rules-before.txt" 2>&1
  else
    echo "[dry-run] would snapshot iptables on $h" >> "$ARTIFACT_DIR/iptables-rules-before.txt"
  fi
done

RESTORED=0
restore() {
  [[ "$RESTORED" -eq 1 ]] && return
  RESTORED=1
  log "restoring — removing DROP rules on all hosts (self-heal timers are the backstop if this hangs/fails)"
  for h in $IDC_HOSTS; do
    if [[ "$DRY_RUN" -eq 0 ]]; then
      ssh_c "$h" "iptables -D INPUT -s $GCP_CIDR -j DROP 2>/dev/null; iptables -D OUTPUT -d $GCP_CIDR -j DROP 2>/dev/null" || true
    fi
  done
  for h in $GCP_HOSTS; do
    if [[ "$DRY_RUN" -eq 0 ]]; then
      ssh_c "$h" "iptables -D INPUT -s $IDC_CIDR -j DROP 2>/dev/null; iptables -D OUTPUT -d $IDC_CIDR -j DROP 2>/dev/null; iptables -D INPUT -s $ORCHESTRATOR_IP -j ACCEPT 2>/dev/null; iptables -D OUTPUT -d $ORCHESTRATOR_IP -j ACCEPT 2>/dev/null" || true
    fi
  done
  : > "$ARTIFACT_DIR/iptables-rules-after.txt"
  for h in $IDC_HOSTS $GCP_HOSTS; do
    echo "=== $h ===" >> "$ARTIFACT_DIR/iptables-rules-after.txt"
    [[ "$DRY_RUN" -eq 0 ]] && ssh_c "$h" "iptables -L INPUT -n; iptables -L OUTPUT -n" >> "$ARTIFACT_DIR/iptables-rules-after.txt" 2>&1
  done
  log "restore complete (verify iptables-rules-after.txt — self-heal timers on each host will also fire ${SELF_HEAL_GRACE_SEC}s after duration regardless)"
}
trap restore EXIT INT TERM

T_INCIDENT=$(date -u '+%Y-%m-%dT%H:%M:%S.%3NZ')
echo "t_incident=$T_INCIDENT" > "$ARTIFACT_DIR/inject.log"
HEAL_AFTER=$((DURATION + SELF_HEAL_GRACE_SEC))

# ---- inject: DROP both directions, both regions ----
# Self-heal timer is launched BEFORE the DROP rule on every host — its own
# launch response must return over a link that isn't blocked yet. It is a
# single simple backgrounded command (setsid nohup ... &), not a compound
# "A && B &" list, which is what caused ssh to hang on the earlier real
# run (a backgrounded AND-list's own stdio stays attached to the ssh
# channel until every command in it finishes; a single simple command's
# redirects fully detach immediately).
if [[ "$DRY_RUN" -eq 0 ]]; then
  log "injecting DROP on IDC hosts ($IDC_HOSTS) → $GCP_CIDR (+ self-heal timer, ${HEAL_AFTER}s)"
  for h in $IDC_HOSTS; do
    ssh_c "$h" "setsid nohup bash -c 'sleep $HEAL_AFTER; iptables -D INPUT -s $GCP_CIDR -j DROP 2>/dev/null; iptables -D OUTPUT -d $GCP_CIDR -j DROP 2>/dev/null' > /root/chaos-c1-self-heal.log 2>&1 < /dev/null & iptables -A INPUT -s $GCP_CIDR -j DROP; iptables -A OUTPUT -d $GCP_CIDR -j DROP" \
      >> "$ARTIFACT_DIR/inject.log" 2>&1 || echo "WARN: inject failed on $h" >> "$ARTIFACT_DIR/inject.log"
  done
  log "injecting DROP on GCP hosts ($GCP_HOSTS) → $IDC_CIDR (+ orchestrator whitelist + self-heal timer, ${HEAL_AFTER}s)"
  for h in $GCP_HOSTS; do
    ssh_c "$h" "setsid nohup bash -c 'sleep $HEAL_AFTER; iptables -D INPUT -s $IDC_CIDR -j DROP 2>/dev/null; iptables -D OUTPUT -d $IDC_CIDR -j DROP 2>/dev/null; iptables -D INPUT -s $ORCHESTRATOR_IP -j ACCEPT 2>/dev/null; iptables -D OUTPUT -d $ORCHESTRATOR_IP -j ACCEPT 2>/dev/null' > /root/chaos-c1-self-heal.log 2>&1 < /dev/null & iptables -I INPUT 1 -s $ORCHESTRATOR_IP -j ACCEPT; iptables -I OUTPUT 1 -d $ORCHESTRATOR_IP -j ACCEPT; iptables -A INPUT -s $IDC_CIDR -j DROP; iptables -A OUTPUT -d $IDC_CIDR -j DROP" \
      >> "$ARTIFACT_DIR/inject.log" 2>&1 || echo "WARN: inject failed on $h" >> "$ARTIFACT_DIR/inject.log"
  done
else
  log "[dry-run] would inject DROP on all 6 hosts (+ orchestrator whitelist on GCP hosts + self-heal timers, ${HEAL_AFTER}s)"
fi

# 2026-08-10 fix (audit finding F-008): per-DB probe command against the
# same fixed IDC host (172.24.40.32) used throughout this topology — only
# the protocol/port/query differs. Still a single IDC-side vantage point
# (see note below and the audit report on the still-open "no GCP-side
# probe" gap — a full bidirectional dual-probe redesign is deferred, not
# attempted blind in this pass).
case "$DB" in
  tidb)   PROBE_CMD="timeout 2 mysql -h 172.24.40.32 -P 4000 -u root -e 'SELECT 1'" ;;
  crdb)   PROBE_CMD="timeout 2 cockroach sql --insecure --host=172.24.40.32:26257 -e 'SELECT 1'" ;;
  ybdb)   PROBE_CMD="timeout 2 psql \"host=172.24.40.32 port=5433 user=yugabyte dbname=yugabyte connect_timeout=2\" -c 'SELECT 1'" ;;
  galera) PROBE_CMD="MYSQL_PWD=\"\$GALERA_BENCH_PASSWORD\" timeout 2 mysql -h 172.24.40.32 -P 3306 -u tpcc_bench -e 'SELECT 1'" ;;
esac

log "partition active for ${DURATION}s — collecting error-rate-by-sec via probe (best effort, db=$DB)"
# Best-effort 1s-resolution probe against the (now-unreachable-from-other-side)
# IDC endpoint, from THIS host (.31, IDC-side), to see local-side degradation.
: > "$ARTIFACT_DIR/error-rate-by-sec.txt"
if [[ "$DRY_RUN" -eq 0 ]]; then
  END=$(( $(date +%s) + DURATION ))
  while [[ $(date +%s) -lt $END ]]; do
    TS=$(date -u '+%Y-%m-%dT%H:%M:%S')
    OK="err"
    eval "$PROBE_CMD" >/dev/null 2>&1 && OK="ok"
    echo "$TS $OK" >> "$ARTIFACT_DIR/error-rate-by-sec.txt"
    sleep 1
  done
else
  sleep 1
  echo "[dry-run] would sample IDC-side reachability (db=$DB) every 1s for ${DURATION}s" >> "$ARTIFACT_DIR/error-rate-by-sec.txt"
fi

log "duration elapsed — restore will run via EXIT trap"
# trap handles restore; explicit call here too in case script continues past this point
restore

cat > "$ARTIFACT_DIR/plan.txt" <<JSON
{
  "scenario": "C1-partition",
  "db": "$DB",
  "t_incident": "$T_INCIDENT",
  "duration_sec": $DURATION,
  "idc_hosts": "$IDC_HOSTS",
  "gcp_hosts": "$GCP_HOSTS",
  "orchestrator_ip_whitelisted_on_gcp_hosts": "$ORCHESTRATOR_IP",
  "self_heal_grace_sec": $SELF_HEAL_GRACE_SEC,
  "self_heal_fires_at_sec": $HEAL_AFTER,
  "dry_run": $([ "$DRY_RUN" -eq 1 ] && echo true || echo false),
  "note": "tpmC-1s and leader-redist-trace must be derived separately from the concurrent go-tpc workload log for this window; this script only owns the network partition inject/restore + a coarse IDC-side reachability probe. Orchestrator control-plane traffic is whitelisted on GCP hosts (see 2026-08-07 safety fix in header) — the DB cluster's own SQL/PD/TiKV/raft traffic between IDC and GCP remains fully blocked for the full duration; only management-plane SSH is excluded from the blast radius."
}
JSON
log "done — artifacts in $ARTIFACT_DIR"
