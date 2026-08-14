#!/usr/bin/env bash
# chaos-c7-disk-slow-execute.sh — REAL execution (new file, planner
# chaos-c7-disk-slow-plan.sh stays planner-only per project rule).
#
# Spec: phase-crossregion/chaos/C7.md's REPLAN §6 redefinition (disk-slow;
# see chaos-c7-disk-slow-plan.sh header for the C7 renumbering history —
# the ORIGINAL C7.md "IDC full-death" scenario is handled separately by
# run-vm6-f2-idc-death-execute.sh, per 2026-08-07 scope decision).
#
# Mechanism (2026-08-07 revision): competing high-priority O_DIRECT fio I/O
# on the SAME block device as the DB data dir, inducing genuine queueing
# latency for the DB's own I/O — verified via io-latency-p99.txt await
# delta, not assumed. This replaces an earlier cgroup v1 blkio.throttle
# design: empirically confirmed on this kernel (4.18.0-553, AlmaLinux 8.10)
# that blkio.throttle.{read,write}_bps_device does NOT cap TiKV's buffered
# writeback even with the PID correctly placed in the cgroup (verified via
# /proc/<pid>/cgroup + live iostat sampling showing throughput far above
# the configured cap) — the standard cgroup-v1-writeback-needs-a-matching-
# memcg gap, not a script bug. Retrofitting a memcg was rejected: the host
# had only ~2.1GB RAM available against tikv-server's 8.6GB RSS, and an
# under-sized memory limit risks OOM-killing the very process under test.
# tc qdisc network shaping (spec's Option B) was also rejected: this host's
# storage is local (sda3), not network-attached, so network shaping would
# not touch actual disk I/O and would misrepresent what was tested.
#
# Honesty requirement: plan.txt must record the mechanism actually used
# (fio contention) and must NOT claim an absolute bytes/sec cap on the DB
# process — only a verified, measured latency/throughput delta.
#
# Usage:
#   bash chaos-c7-disk-slow-execute.sh --db tidb|crdb|ybdb --target-host <ip> \
#     --duration <sec> --artifact-dir <dir> [--fio-jobs 4] [--fio-iodepth 64] \
#     [--fio-size 2G] [--dry-run]

set -uo pipefail

DB=""
TARGET_HOST=""
DURATION=""
ARTIFACT_DIR=""
FIO_JOBS=4
FIO_IODEPTH=64
FIO_SIZE=2G
DRY_RUN=0

usage() {
  cat <<'EOF'
Usage: chaos-c7-disk-slow-execute.sh --db tidb|crdb|ybdb --target-host <ip> \
  --duration <sec> --artifact-dir <dir> [--fio-jobs N] [--fio-iodepth N] \
  [--fio-size SIZE] [--dry-run]
EOF
  exit 2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --db)            DB=$2; shift 2 ;;
    --target-host)   TARGET_HOST=$2; shift 2 ;;
    --duration)      DURATION=$2; shift 2 ;;
    --artifact-dir)  ARTIFACT_DIR=$2; shift 2 ;;
    --fio-jobs)      FIO_JOBS=$2; shift 2 ;;
    --fio-iodepth)   FIO_IODEPTH=$2; shift 2 ;;
    --fio-size)      FIO_SIZE=$2; shift 2 ;;
    --dry-run)       DRY_RUN=1; shift ;;
    -h|--help)       usage ;;
    *) echo "unknown arg: $1" >&2; usage ;;
  esac
done
[[ -z "$DB" || -z "$TARGET_HOST" || -z "$DURATION" || -z "$ARTIFACT_DIR" ]] && usage
[[ "$DB" =~ ^(tidb|crdb|ybdb|galera)$ ]] || { echo "--db must be tidb|crdb|ybdb|galera" >&2; exit 2; }
[[ "$DURATION" =~ ^[0-9]+$ ]] || { echo "--duration must be integer seconds" >&2; exit 2; }

case "$DB" in
  tidb)   DATA_DIR="/tidb-data/tikv-20160" ;;
  crdb)   DATA_DIR="/var/lib/cockroach" ;;
  ybdb)   DATA_DIR="/var/yugabyte/data" ;;  # 2026-08-08: confirmed real path via `yugabyted status`
  galera) DATA_DIR="/var/lib/mysql" ;;      # G5，2026-08-13：見 ansible/playbooks/galera-vm6.yml，MySQL/PXC 預設 datadir
esac

mkdir -p "$ARTIFACT_DIR"
log() { echo "[c7-execute] $(date -u '+%Y-%m-%dT%H:%M:%S.%3NZ') $*"; }
ssh_c() { ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=5 root@"$TARGET_HOST" "$1"; }

log "db=$DB target=$TARGET_HOST duration=${DURATION}s data_dir=$DATA_DIR fio_jobs=$FIO_JOBS fio_iodepth=$FIO_IODEPTH fio_size=$FIO_SIZE dry_run=$DRY_RUN"

# ---- resolve which mount/filesystem to contend on (same device as DATA_DIR) ----
MOUNT_TARGET=""
SCRATCH_DIR=""
if [[ "$DRY_RUN" -eq 0 ]]; then
  MOUNT_TARGET=$(ssh_c "df --output=target '$DATA_DIR' 2>/dev/null | tail -1")
  if [[ -z "$MOUNT_TARGET" ]]; then
    log "FATAL: could not resolve mount point for $DATA_DIR — aborting, will not guess"
    echo '{"error":"could_not_resolve_mount_point","data_dir":"'"$DATA_DIR"'"}' > "$ARTIFACT_DIR/plan.txt"
    exit 1
  fi
  # Scratch dir lives on the same mount (same block device / same I/O queue
  # as $DATA_DIR) but is NEVER inside $DATA_DIR itself — never touches real
  # DB files.
  SCRATCH_DIR="${MOUNT_TARGET%/}/chaos-c7-fio-scratch"
  log "resolved mount for $DATA_DIR: $MOUNT_TARGET — fio scratch dir: $SCRATCH_DIR"
else
  log "[dry-run] would resolve mount point for $DATA_DIR and place fio scratch dir on same device"
fi

# ---- pre-injection snapshot ----
if [[ "$DRY_RUN" -eq 0 ]]; then
  ssh_c "df -h '$DATA_DIR'" > "$ARTIFACT_DIR/pre-inject-state.txt" 2>&1
else
  echo "[dry-run] pre-injection snapshot" > "$ARTIFACT_DIR/pre-inject-state.txt"
fi

RESTORED=0
restore() {
  [[ "$RESTORED" -eq 1 ]] && return
  RESTORED=1
  log "restoring — stopping fio contention job and removing scratch files"
  if [[ "$DRY_RUN" -eq 0 ]]; then
    ssh_c "pkill -f 'fio --name=chaos-c7-contention' 2>/dev/null" || true
    ssh_c "rm -rf '$SCRATCH_DIR'" || true
    ssh_c "cat /proc/loadavg; df -h '$DATA_DIR'" >> "$ARTIFACT_DIR/pre-inject-state.txt" 2>&1
  fi
  log "restore complete"
}
trap restore EXIT INT TERM

T_INCIDENT=$(date -u '+%Y-%m-%dT%H:%M:%S.%3NZ')
FIO_OK=0

# ---- inject: competing high-priority O_DIRECT fio contention on the same
#      block device, time-bounded to $DURATION, then collect iostat samples
#      concurrently so the induced latency is directly observable. ----
if [[ "$DRY_RUN" -eq 0 ]]; then
  # 2026-08-08 fix: a real run on a freshly-rebuilt host (fio never
  # installed there — each VM rebuild starts clean, nothing carries over)
  # silently "succeeded" per FIO_OK's old logic: the launch command itself
  # (mkdir + setsid nohup ionice fio ... &) returns 0 even though the
  # backgrounded fio then failed with "No such file or directory" —
  # launching a background job is not the same as the job succeeding.
  # Check the binary exists BEFORE injecting rather than discovering it
  # from an empty/truncated fio-summary.txt after the fact.
  if ! ssh_c "command -v fio" > /dev/null 2>&1; then
    log "FATAL: fio not installed on $TARGET_HOST — aborting, will not fake an injection"
    echo '{"error":"fio_not_installed","target_host":"'"$TARGET_HOST"'"}' > "$ARTIFACT_DIR/plan.txt"
    exit 1
  fi
  log "starting fio contention on $TARGET_HOST for ${DURATION}s (background)"
  # The whole "mkdir && setsid ... fio" compound must be wrapped in its own
  # subshell with stdio redirected on the SUBSHELL itself, not just the
  # trailing fio command — empirically confirmed on this host: a bare
  # "A && setsid nohup CMD > log 2>&1 < /dev/null &" still blocks this ssh
  # call for the full fio runtime (redirects only bind to the last simple
  # command, leaving the "A && ..." AND-list's own stdio attached to the
  # ssh channel until every command in it finishes); wrapping in "( ... )"
  # with redirects on the parens returns immediately as intended.
  ssh_c "( mkdir -p '$SCRATCH_DIR' && \
         setsid nohup ionice -c1 -n0 fio --name=chaos-c7-contention --directory='$SCRATCH_DIR' \
           --size=$FIO_SIZE --rw=randwrite --bs=4k --ioengine=libaio --direct=1 \
           --iodepth=$FIO_IODEPTH --numjobs=$FIO_JOBS --time_based --runtime=${DURATION}s \
           --group_reporting ) > /root/chaos-c7-fio.log 2>&1 < /dev/null &" \
    >> "$ARTIFACT_DIR/inject.log" 2>&1 && FIO_OK=1 || log "WARN: fio launch reported non-zero exit (see inject.log)"

  log "sampling iostat for ${DURATION}s while fio contention runs concurrently"
  ssh_c "iostat -x 1 $DURATION 2>/dev/null || echo 'iostat not available'" > "$ARTIFACT_DIR/io-latency-p99.txt" 2>&1

  # fio's own summary (throughput/latency it observed) — corroborating
  # evidence, separate from the DB-side iostat view. fio's --runtime
  # matches $DURATION and iostat's sampling loop above already took
  # $DURATION seconds, so fio should be done — but give it a moment to
  # finish flushing its own report before reading (racing this produced a
  # truncated summary on an earlier real run).
  sleep 3
  ssh_c "cat /root/chaos-c7-fio.log 2>/dev/null; rm -f /root/chaos-c7-fio.log" > "$ARTIFACT_DIR/fio-summary.txt" 2>&1
  # FIO_OK from the launch command's exit code only proves the ssh call
  # that BACKGROUNDED fio returned 0 — not that fio itself ran. The real
  # completion marker is "Run status" in fio's own summary output.
  if ! grep -q "Run status" "$ARTIFACT_DIR/fio-summary.txt" 2>/dev/null; then
    log "WARN: fio-summary.txt has no 'Run status' — fio did not complete successfully despite launch succeeding (see fio-summary.txt for the actual error)"
    FIO_OK=0
  fi
else
  sleep 1
  echo "[dry-run] would run: fio --name=chaos-c7-contention --directory=<scratch> --size=$FIO_SIZE --rw=randwrite --bs=4k --direct=1 --iodepth=$FIO_IODEPTH --numjobs=$FIO_JOBS --runtime=${DURATION}s (background) + iostat -x 1 ${DURATION} concurrently" > "$ARTIFACT_DIR/io-latency-p99.txt"
fi

log "duration elapsed — restore via EXIT trap"
restore

cat > "$ARTIFACT_DIR/plan.txt" <<JSON
{
  "scenario": "C7-disk-slow",
  "mechanism": "fio-direct-io-contention",
  "mechanism_note": "Competing high-priority O_DIRECT fio writes on the same block device as the DB data dir induce genuine I/O queueing latency; this is NOT an absolute bytes/sec cap on the DB process. cgroup v1 blkio.throttle was evaluated and rejected — confirmed ineffective against TiKV's buffered writeback on this kernel even with the PID correctly cgroup-assigned. tc network shaping was rejected — storage here is local, not network-attached, so it would not touch actual disk I/O.",
  "db": "$DB",
  "target_host": "$TARGET_HOST",
  "t_incident": "$T_INCIDENT",
  "duration_sec": $DURATION,
  "fio_jobs": $FIO_JOBS,
  "fio_iodepth": $FIO_IODEPTH,
  "fio_size": "$FIO_SIZE",
  "fio_launch_ok": $([ "$FIO_OK" -eq 1 ] && echo true || echo false),
  "scratch_dir": "$SCRATCH_DIR",
  "dry_run": $([ "$DRY_RUN" -eq 1 ] && echo true || echo false),
  "note": "Induced latency delta must be read from io-latency-p99.txt (await/svctm columns, pre- vs during-injection) and fio-summary.txt; tpmC-1s impact must be derived separately from the concurrent go-tpc workload log for this window."
}
JSON

if [[ "$DRY_RUN" -eq 0 && "$FIO_OK" -ne 1 ]]; then
  log "FATAL: fio did not complete successfully — see plan.txt/fio-summary.txt (fio_launch_ok=false)"
  exit 1
fi
log "done — artifacts in $ARTIFACT_DIR"
