#!/bin/bash
# SQL Layer RTO monitor：持續讀取 rto_seq，統計故障次數與中斷時間

HOST=172.24.40.25
PORT=6000
USER=root
PASS="1qaz@WSX"
DB=rto

SLEEP_INTERVAL=0.3

sample_count=0
fail_count=0
total_fail_ms=0
current_fail_start=""
current_fail_epoch=""
last_seq=-1
declare -a FAIL_WINDOWS=()

print_summary() {
  local exit_time now_epoch now_ts duration_ms

  now_epoch=$(date +%s%3N)
  now_ts=$(date +'%F %T.%3N')

  if [[ -n "$current_fail_start" ]]; then
    duration_ms=$((now_epoch - current_fail_epoch))
    total_fail_ms=$((total_fail_ms + duration_ms))
    fail_count=$((fail_count + 1))
    FAIL_WINDOWS+=("FAIL#${fail_count} ${current_fail_start} -> ${now_ts} (${duration_ms}ms,未恢復即被中斷)")
    current_fail_start=""
    current_fail_epoch=""
  fi

  echo
  echo "========== SQL RTO Monitor Summary =========="
  echo "Samples        : ${sample_count}"
  echo "Fail segments  : ${fail_count}"
  echo "Total fail (ms): ${total_fail_ms}"
  if [[ ${fail_count} -gt 0 ]]; then
    echo "--------------- Failure Windows -------------"
    printf '%s\n' "${FAIL_WINDOWS[@]}"
  else
    echo "無故障發生"
  fi
  echo "=============================================="
  exit 0
}

trap print_summary INT TERM

while true; do
  start_ms=$(date +%s%3N)

  row=$(mysql -h"${HOST}" -P"${PORT}" -u"${USER}" -p"${PASS}" -D"${DB}" -N -e "
    SELECT seq_val,
           DATE_FORMAT(last_ts, '%Y-%m-%d %H:%i:%s.%f')
      FROM rto_seq
     WHERE id = 1;
  " 2>/dev/null)
  rc=$?

  end_ms=$(date +%s%3N)
  rtt_ms=$((end_ms - start_ms))
  now_ts=$(date +'%F %T.%3N')
  sample_count=$((sample_count + 1))

  if [[ $rc -ne 0 || -z "$row" ]]; then
    if [[ -z "$current_fail_start" ]]; then
      current_fail_start="$now_ts"
      current_fail_epoch=$start_ms
      echo "${now_ts}  FAIL_BEGIN  RTT(ms)=${rtt_ms} rc=${rc}"
    else
      echo "${now_ts}  FAILING     RTT(ms)=${rtt_ms} rc=${rc}"
    fi
    sleep "${SLEEP_INTERVAL}"
    continue
  fi

  seq=$(echo "$row" | awk '{print $1}')
  ts=$(echo "$row"  | awk '{print $2}')

  if [[ -n "$current_fail_start" ]]; then
    duration_ms=$((start_ms - current_fail_epoch))
    total_fail_ms=$((total_fail_ms + duration_ms))
    fail_count=$((fail_count + 1))
    FAIL_WINDOWS+=("FAIL#${fail_count} ${current_fail_start} -> ${now_ts} (${duration_ms}ms)")
    echo "${now_ts}  RECOVERED  outage=${duration_ms}ms"
    current_fail_start=""
    current_fail_epoch=""
  fi

  if [[ $last_seq -lt 0 ]]; then
    delta=0
  else
    delta=$((seq - last_seq))
  fi
  last_seq=$seq

  echo "${now_ts}  seq_val=${seq} delta=${delta} RTT(ms)=${rtt_ms} last_ts=${ts}"

  sleep "${SLEEP_INTERVAL}"
done
