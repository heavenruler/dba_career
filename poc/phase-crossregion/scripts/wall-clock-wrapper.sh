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
    # If probe file exists, find first 'ok' line from it (more precise than manual call).
    if [[ -f "$PROBE_FILE" ]]; then
      FIRST_OK_MS=$(awk '/^[0-9]+ ok /{print $1; exit}' "$PROBE_FILE" || true)
    fi
    if [[ -n "${FIRST_OK_MS:-}" ]]; then
      # Convert epoch_ms to RFC3339 (portable: seconds + ms suffix)
      SEC=$((FIRST_OK_MS / 1000))
      MS_PART=$((FIRST_OK_MS % 1000))
      T_RFC=$(date -r "$SEC" '+%Y-%m-%dT%H:%M:%S' 2>/dev/null || date -d "@$SEC" '+%Y-%m-%dT%H:%M:%S' 2>/dev/null || echo "?")
      T_RFC="${T_RFC}.$(printf '%03d' "$MS_PART")$(date '+%z')"
      SRC=probe
    else
      FIRST_OK_MS=$(ts_ms)
      T_RFC=$(ts_rfc3339)
      SRC=manual
      echo "[wall-clock] WARN: no 'ok' in probe file — using current time as t_first_ok" >&2
    fi
    printf '{"ts_ms":%s,"ts_rfc3339":"%s","source":"%s"}\n' "$FIRST_OK_MS" "$T_RFC" "$SRC" \
      > "$ARTIFACT_DIR/t_first_ok.txt"
    echo "[wall-clock] t_first_ok stamped: $T_RFC  ($FIRST_OK_MS ms)  source=$SRC"
    ;;

  compute-rto)
    INCIDENT_FILE="$ARTIFACT_DIR/t_incident.txt"
    FIRST_OK_FILE="$ARTIFACT_DIR/t_first_ok.txt"
    [[ -f "$INCIDENT_FILE" ]] || { echo "ERROR: $INCIDENT_FILE not found" >&2; exit 1; }
    [[ -f "$FIRST_OK_FILE" ]] || { echo "ERROR: $FIRST_OK_FILE not found" >&2; exit 1; }

    T_INC=$(grep -oP '"ts_ms":\K[0-9]+' "$INCIDENT_FILE")
    T_OK=$(grep -oP '"ts_ms":\K[0-9]+' "$FIRST_OK_FILE")

    if [[ "$T_OK" -le "$T_INC" ]]; then
      echo "[wall-clock] WARN: t_first_ok ($T_OK) <= t_incident ($T_INC) — probe may predate incident" >&2
    fi

    RTO_MS=$((T_OK - T_INC))
    RTO_SEC=$(awk "BEGIN{printf \"%.3f\", $RTO_MS/1000}")

    OUT="$ARTIFACT_DIR/rto-wall-clock.json"
    printf '{"t_incident_ms":%s,"t_first_ok_ms":%s,"rto_ms":%s,"rto_sec":%s}\n' \
      "$T_INC" "$T_OK" "$RTO_MS" "$RTO_SEC" > "$OUT"

    echo "[wall-clock] RTO = ${RTO_SEC}s  (${RTO_MS}ms)  → $OUT"
    ;;
esac
