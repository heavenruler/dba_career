#!/usr/bin/env bash
# phase-crossregion/scripts/wall-clock-wrapper.sh
#
# Driver-side wall-clock stamp tool (per RTO-RPO-methodology.md §7.3).
# Records t_incident and t_first_ok as RFC3339+ms timestamps for RTO calculation.
#
# Both timestamps MUST be taken on the same driver host to avoid NTP skew.
#
# Usage:
#   # Stamp incident trigger (call immediately after kill/stop ssh returns):
#   bash wall-clock-wrapper.sh --stamp-incident --artifact-dir <dir>
#
#   # Stamp first successful write (call once probe.txt shows first 'ok' post-incident):
#   bash wall-clock-wrapper.sh --stamp-first-ok --artifact-dir <dir> [--probe-file <path>]
#
#   # Compute RTO from stamps + probe file:
#   bash wall-clock-wrapper.sh --compute-rto --artifact-dir <dir>
#
# Outputs (in artifact-dir):
#   t_incident.txt     — {"ts_ms":<epoch_ms>, "ts_rfc3339":"...", "source":"manual"}
#   t_first_ok.txt     — {"ts_ms":<epoch_ms>, "ts_rfc3339":"...", "source":"probe|manual"}
#   rto-wall-clock.json — {"t_incident_ms":N, "t_first_ok_ms":N, "rto_sec": F}

set -euo pipefail

MODE=""
ARTIFACT_DIR=""
PROBE_FILE=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --stamp-incident) MODE=stamp-incident; shift ;;
    --stamp-first-ok) MODE=stamp-first-ok; shift ;;
    --compute-rto)    MODE=compute-rto;    shift ;;
    --artifact-dir)   ARTIFACT_DIR=$2;     shift 2 ;;
    --probe-file)     PROBE_FILE=$2;       shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 1 ;;
  esac
done

: "${MODE:?--stamp-incident | --stamp-first-ok | --compute-rto required}"
: "${ARTIFACT_DIR:?--artifact-dir required}"

mkdir -p "$ARTIFACT_DIR"
PROBE_FILE="${PROBE_FILE:-$ARTIFACT_DIR/probe.txt}"

ts_ms()     { date '+%s%3N'; }
ts_rfc3339(){ date '+%Y-%m-%dT%H:%M:%S.%3N%z'; }

case "$MODE" in

  stamp-incident)
    T_MS=$(ts_ms)
    T_RFC=$(ts_rfc3339)
    printf '{"ts_ms":%s,"ts_rfc3339":"%s","source":"manual"}\n' "$T_MS" "$T_RFC" \
      > "$ARTIFACT_DIR/t_incident.txt"
    echo "[wall-clock] t_incident stamped: $T_RFC  ($T_MS ms)"
    ;;

  stamp-first-ok)
    # If probe file exists, find first 'ok' line AFTER t_incident (more
    # precise than manual call). 2026-08-07 fix: the probe loop starts
    # ~2s BEFORE the incident and runs continuously, so probe.txt already
    # contains pre-incident 'ok' lines by the time this is called — taking
    # the file's first 'ok' unconditionally (the original logic) always
    # picked a pre-incident timestamp, making every RTO compute to ~0 (or
    # negative, since t_first_ok would predate t_incident). Must cut off
    # at t_incident's own ts_ms.
    # 2026-08-07 second fix: a real F1 run showed "flapping" during
    # failover — one isolated 'ok' at t_incident+172ms sandwiched between
    # two later 'err' lines (944474, 947840), with sustained recovery only
    # starting ~7s later. Picking the first post-incident 'ok' (previous
    # fix) reported that isolated blip as "recovered", understating RTO by
    # ~7s. Correct anchor: the first 'ok' AFTER the LAST 'err' in the whole
    # post-incident window (i.e. the point recovery actually held), not the
    # first 'ok' after t_incident.
    T_INC_CUTOFF=0
    if [[ -f "$ARTIFACT_DIR/t_incident.txt" ]]; then
      T_INC_CUTOFF=$(grep -oP '"ts_ms":\K[0-9]+' "$ARTIFACT_DIR/t_incident.txt" || echo 0)
    fi
    # 2026-08-10 fix (audit finding F-001): the previous version fell back
    # to LAST_ERR_MS=cutoff whenever zero post-incident 'err' lines existed,
    # which made FIRST_OK_MS resolve to "whatever probe tick happened to
    # fire next after t_incident" — i.e. probe scheduling latency, NOT an
    # observed outage-to-recovery duration. Verified against raw artifacts:
    # every CockroachDB/YugabyteDB F1/C4 probe.txt in this campaign has
    # err_count=0 post-incident (887/972/502/508/505/489/508/504 ok for
    # crdb; 122/127/108/117/109/124/109/117 ok for ybdb — zero errors in
    # all 16), so every RTO number reported for those scenarios was in
    # fact measuring probe cadence, not failover. Must not silently keep
    # producing a positive RTO in this case — record outage_observed
    # explicitly and let --compute-rto decide what to output.
    ERR_COUNT_POST=0
    OK_COUNT_POST=0
    if [[ -f "$PROBE_FILE" ]]; then
      ERR_COUNT_POST=$(awk -v cutoff="$T_INC_CUTOFF" '/^[0-9]+ err /{if ($1 > cutoff) n++} END{print n+0}' "$PROBE_FILE")
      OK_COUNT_POST=$(awk -v cutoff="$T_INC_CUTOFF" '/^[0-9]+ ok /{if ($1 > cutoff) n++} END{print n+0}' "$PROBE_FILE")
    fi
    if [[ -f "$PROBE_FILE" && "$ERR_COUNT_POST" -gt 0 ]]; then
      LAST_ERR_MS=$(awk -v cutoff="$T_INC_CUTOFF" '/^[0-9]+ err /{if ($1 > cutoff) last=$1} END{if (last) print last; else print cutoff}' "$PROBE_FILE")
      FIRST_OK_MS=$(awk -v cutoff="$LAST_ERR_MS" '/^[0-9]+ ok /{if ($1 > cutoff) {print $1; exit}}' "$PROBE_FILE" || true)
    fi
    OUTAGE_OBSERVED=false
    if [[ -n "${FIRST_OK_MS:-}" ]]; then
      # Convert epoch_ms to RFC3339 (portable: seconds + ms suffix)
      SEC=$((FIRST_OK_MS / 1000))
      MS_PART=$((FIRST_OK_MS % 1000))
      T_RFC=$(date -r "$SEC" '+%Y-%m-%dT%H:%M:%S' 2>/dev/null || date -d "@$SEC" '+%Y-%m-%dT%H:%M:%S' 2>/dev/null || echo "?")
      T_RFC="${T_RFC}.$(printf '%03d' "$MS_PART")$(date '+%z')"
      SRC=probe
      OUTAGE_OBSERVED=true
    elif [[ -f "$PROBE_FILE" ]]; then
      # Probe ran and never errored post-incident: no outage was observed
      # within probe resolution. Do NOT fabricate a recovery timestamp from
      # the next scheduled tick — record the fact plainly instead.
      FIRST_OK_MS="$T_INC_CUTOFF"
      T_RFC="n/a"
      SRC=no_outage_observed
      echo "[wall-clock] NOTE: 0 post-incident errors in $PROBE_FILE (ok=$OK_COUNT_POST) — outage_observed=false, RTO not applicable" >&2
    else
      FIRST_OK_MS=$(ts_ms)
      T_RFC=$(ts_rfc3339)
      SRC=manual
      echo "[wall-clock] WARN: no probe file found — using current time as t_first_ok" >&2
    fi
    printf '{"ts_ms":%s,"ts_rfc3339":"%s","source":"%s","outage_observed":%s,"probe_ok_count":%s,"probe_err_count":%s}\n' \
      "$FIRST_OK_MS" "$T_RFC" "$SRC" "$OUTAGE_OBSERVED" "$OK_COUNT_POST" "$ERR_COUNT_POST" \
      > "$ARTIFACT_DIR/t_first_ok.txt"
    echo "[wall-clock] t_first_ok stamped: $T_RFC  ($FIRST_OK_MS ms)  source=$SRC  outage_observed=$OUTAGE_OBSERVED  ok=$OK_COUNT_POST  err=$ERR_COUNT_POST"
    ;;

  compute-rto)
    INCIDENT_FILE="$ARTIFACT_DIR/t_incident.txt"
    FIRST_OK_FILE="$ARTIFACT_DIR/t_first_ok.txt"
    [[ -f "$INCIDENT_FILE" ]] || { echo "ERROR: $INCIDENT_FILE not found" >&2; exit 1; }
    [[ -f "$FIRST_OK_FILE" ]] || { echo "ERROR: $FIRST_OK_FILE not found" >&2; exit 1; }

    T_INC=$(grep -oP '"ts_ms":\K[0-9]+' "$INCIDENT_FILE")
    T_OK=$(grep -oP '"ts_ms":\K[0-9]+' "$FIRST_OK_FILE")
    OUTAGE_OBSERVED=$(grep -oP '"outage_observed":\K(true|false)' "$FIRST_OK_FILE" || echo "true")
    PROBE_OK=$(grep -oP '"probe_ok_count":\K[0-9]+' "$FIRST_OK_FILE" || echo "null")
    PROBE_ERR=$(grep -oP '"probe_err_count":\K[0-9]+' "$FIRST_OK_FILE" || echo "null")

    if [[ "$T_OK" -le "$T_INC" && "$OUTAGE_OBSERVED" != "false" ]]; then
      echo "[wall-clock] WARN: t_first_ok ($T_OK) <= t_incident ($T_INC) — probe may predate incident" >&2
    fi

    OUT="$ARTIFACT_DIR/rto-wall-clock.json"
    if [[ "$OUTAGE_OBSERVED" == "false" ]]; then
      # 2026-08-10 fix (audit finding F-001): zero post-incident probe
      # errors means no client-visible outage was observed within probe
      # resolution — rto_sec MUST be null, not a positive number derived
      # from probe scheduling latency. See probe_ok_count/probe_err_count
      # for the underlying evidence.
      printf '{"t_incident_ms":%s,"t_first_ok_ms":%s,"rto_ms":null,"rto_sec":null,"outage_observed":false,"probe_ok_count":%s,"probe_err_count":%s,"note":"no post-incident probe error observed; RTO not applicable (see F-001 audit finding)"}\n' \
        "$T_INC" "$T_OK" "$PROBE_OK" "$PROBE_ERR" > "$OUT"
      echo "[wall-clock] outage_observed=false — RTO not applicable (0 post-incident probe errors, ok=$PROBE_OK)  → $OUT"
    else
      RTO_MS=$((T_OK - T_INC))
      RTO_SEC=$(awk "BEGIN{printf \"%.3f\", $RTO_MS/1000}")
      printf '{"t_incident_ms":%s,"t_first_ok_ms":%s,"rto_ms":%s,"rto_sec":%s,"outage_observed":true,"probe_ok_count":%s,"probe_err_count":%s}\n' \
        "$T_INC" "$T_OK" "$RTO_MS" "$RTO_SEC" "$PROBE_OK" "$PROBE_ERR" > "$OUT"
      echo "[wall-clock] RTO = ${RTO_SEC}s  (${RTO_MS}ms)  outage_observed=true  → $OUT"
    fi
    ;;
esac
