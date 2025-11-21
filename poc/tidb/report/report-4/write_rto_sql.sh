#!/bin/bash
# 寫入 rto_seq，模擬 TiKV 故障切換期間的持續寫流量

HOST=172.24.40.25
PORT=6000
USER=root
PASS="1qaz@WSX"
DB=rto

SLEEP_INTERVAL=0.2       # 每筆寫入間隔
MAX_LOOPS=0              # 0 = 無限循環，可改為固定次數

success=0
fail=0
loops=0
current_fail_start=""
current_fail_epoch=""
declare -a FAIL_LOG=()

print_summary() {
  local now_ts total duration_ms

  now_ts=$(date +'%F %T.%3N')
  echo
  echo "========== SQL Writer Summary =========="
  echo "End at       : ${now_ts}"
  echo "Total loops  : ${loops}"
  echo "Success      : ${success}"
  echo "Fail         : ${fail}"
  if [[ ${#FAIL_LOG[@]} -gt 0 ]]; then
    echo "--------------- Fail Windows -------------"
    printf '%s\n' "${FAIL_LOG[@]}"
  else
    echo "無寫入故障"
  fi
  echo "========================================="
  exit 0
}

trap print_summary INT TERM

while true; do
  if [[ ${MAX_LOOPS} -gt 0 && ${loops} -ge ${MAX_LOOPS} ]]; then
    break
  fi
  loops=$((loops + 1))

  start_ms=$(date +%s%3N)
  now_ts=$(date +'%F %T.%3N')

  output=$(
    mysql -h"${HOST}" -P"${PORT}" -u"${USER}" -p"${PASS}" -D"${DB}" -N -e "
      START TRANSACTION;
        UPDATE rto_seq
           SET seq_val = seq_val + 1,
               last_ts = NOW(6)
         WHERE id = 1;
      COMMIT;
    " 2>&1
  )
  rc=$?

  end_ms=$(date +%s%3N)
  rtt_ms=$((end_ms - start_ms))

  if [[ $rc -ne 0 ]]; then
    fail=$((fail + 1))
    if [[ -z "$current_fail_start" ]]; then
      current_fail_start="$now_ts"
      current_fail_epoch=$start_ms
      echo "${now_ts}  WRITE_FAIL  RTT(ms)=${rtt_ms} rc=${rc}"
    else
      echo "${now_ts}  WRITE_FAIL  RTT(ms)=${rtt_ms} rc=${rc}"
    fi
    echo "  MYSQL_ERROR: ${output}"
  else
    success=$((success + 1))
    if [[ -n "$current_fail_start" ]]; then
      duration_ms=$((start_ms - current_fail_epoch))
      FAIL_LOG+=("${current_fail_start} -> ${now_ts} (${duration_ms}ms)")
      current_fail_start=""
      current_fail_epoch=""
      echo "${now_ts}  WRITE_RECOVER outage=${duration_ms}ms"
    fi
    echo "${now_ts}  WRITE_OK    RTT(ms)=${rtt_ms}"
  fi

  if [[ "$(printf '%.1f\n' "$SLEEP_INTERVAL")" != "0.0" ]]; then
    sleep "${SLEEP_INTERVAL}"
  fi
done

print_summary
