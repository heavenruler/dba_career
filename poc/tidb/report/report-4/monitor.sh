#!/bin/bash
# 監控 rto_seq.seq_val / last_ts，並顯示每次 SELECT RTT（ms）
# RTO：故障期間 seq_val 不變或讀取失敗的時間長度

HOST=172.24.40.25
PORT=6000
USER=root
PASS="1qaz@WSX"
DB=rto

SLEEP_INTERVAL=0.3   # 調小會更密集監控

last_seq=-1

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

  if [ $rc -ne 0 ] || [ -z "$row" ]; then
    echo "${now_ts}  READ_FAIL  RTT(ms)=${rtt_ms} rc=${rc}"
    sleep "${SLEEP_INTERVAL}"
    continue
  fi

  seq=$(echo "$row" | awk '{print $1}')
  ts=$(echo "$row"  | awk '{print $2}')

  if [ "$last_seq" -lt 0 ]; then
    delta=0
  else
    delta=$((seq - last_seq))
  fi
  last_seq=$seq

  echo "${now_ts}  seq_val=${seq}  delta=${delta}  RTT(ms)=${rtt_ms}"

  sleep "${SLEEP_INTERVAL}"
done
