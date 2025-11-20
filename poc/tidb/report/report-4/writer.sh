#!/bin/bash
# 持續對 rto_test + rto_seq 做 UPDATE，並顯示每次 SQL RTT（ms）

HOST=172.24.40.25
PORT=6000
USER=root
PASS="1qaz@WSX"
DB=rto

SLEEP_INTERVAL=1

SEQ_STEP=1000000000   # 大步長，避免撞 UNIQUE

while true; do
  start_ms=$(date +%s%3N)

  output=$(
    mysql -h"${HOST}" -P"${PORT}" -u"${USER}" -p"${PASS}" -D"${DB}" -N -e "
      START TRANSACTION;

        UPDATE rto_test
           SET seq_data = seq_data + ${SEQ_STEP},
               col1     = col1 + FLOOR(RAND()*10),
               col2     = col2 + FLOOR(RAND()*10),
               col3     = col3 + FLOOR(RAND()*10),
               payload  = CONCAT(SUBSTRING(payload, 2), SUBSTRING(payload, 1, 1))
         WHERE id = FLOOR(RAND()*1000000) + 1;

        UPDATE rto_seq
           SET seq_val = seq_val + 1,
               last_ts = NOW(6)
         WHERE id = 1;

      COMMIT;
    " 2>/dev/null
  )
  rc=$?

  end_ms=$(date +%s%3N)
  rtt_ms=$((end_ms - start_ms))
  now_ts=$(date +'%F %T.%3N')

  if [ $rc -ne 0 ]; then
    echo "${now_ts}  UPDATE_FAIL  RTT(ms)=${rtt_ms} rc=${rc}"
    echo "  MYSQL_ERROR: ${output}"
  else
    echo "${now_ts}  UPDATE_OK    RTT(ms)=${rtt_ms}"
  fi

  if [ "$(printf '%.1f\n' "$SLEEP_INTERVAL")" != "0.0" ]; then
    sleep "${SLEEP_INTERVAL}"
  fi
done

