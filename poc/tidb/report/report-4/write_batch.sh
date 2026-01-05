#!/bin/bash
# 持續對 rto_test + rto_seq 做 UPDATE，並顯示每次 SQL RTT（ms）

HOST=172.24.40.25
PORT=6000
USER=root
PASS="1qaz@WSX"
DB=rto

SLEEP_INTERVAL=1          # 每次迴圈間隔（秒）
MAX_OPS=60                # 最多執行 60 次迴圈，約 1 分鐘就結束

SEQ_STEP=1000000000       # 大步長，避免撞 UNIQUE

ops=0

while true; do
  # 若已達最大次數就結束
  if [ "${MAX_OPS}" -gt 0 ] && [ "${ops}" -ge "${MAX_OPS}" ]; then
    echo "$(date +'%F %T.%3N')  DONE  ops=${ops}"
    break
  fi

  start_ms=$(date +%s%3N)

  output=$(
    mysql -h"${HOST}" -P"${PORT}" -u"${USER}" -p"${PASS}" -D"${DB}" -N -e "
      START TRANSACTION;

        -- 減少寫入壓力：只更新 seq_data 一個欄位
        -- UPDATE rto_test
        --    SET seq_data = seq_data + ${SEQ_STEP}
        --  WHERE id = FLOOR(RAND()*1000000) + 1;

        -- 仍保留 rto_seq 供 RTO 監控用
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
  now_ts=$(date +'%F %T.%3N')

  if [ $rc -ne 0 ]; then
    echo "${now_ts}  UPDATE_FAIL  RTT(ms)=${rtt_ms} rc=${rc}"
    echo "  MYSQL_ERROR: ${output}"
  else
    echo "${now_ts}  UPDATE_OK    RTT(ms)=${rtt_ms}"
  fi

  ops=$((ops + 1))

  if [ "$(printf '%.1f\n' "$SLEEP_INTERVAL")" != "0.0" ]; then
    sleep "${SLEEP_INTERVAL}"
  fi
done

