#!/bin/bash
# 統一轉換成「整機百分比」

HOST="172.24.40.25"
PORT=6000
USER="root"
PASS="1qaz@WSX"
DB="test"

#THREADS_LIST="50 100 200 250 500 750 1000"
THREADS_LIST="1 2 10 50 100"
DURATION=30
QNUM=20000
WARMUP_THREADS=100
WARMUP_TIME=10
TIMEOUT=1
SQL_TIMEOUT_MS=$((TIMEOUT*1000))

export MYSQL_PWD=$PASS

# Node IP (包含 tidb-server 與 tiproxy)
TIDB_LIST="172.24.40.17"
RESULT_CSV="bench_result.csv"

header="Timestamp,Threads,RPS,AvgSec,Loops,ErrRate,TidbCPU%,TiProxyCPU%"
echo "$header" > $RESULT_CSV

########################################
# Warm up
########################################
echo "===== WARM UP 開始 ($WARMUP_THREADS threads, $WARMUP_TIME 秒) ====="
end=$((SECONDS+WARMUP_TIME))
while [ $SECONDS -lt $end ]; do
  mysqlslap \
    --host=$HOST --port=$PORT --user=$USER \
    --concurrency=$WARMUP_THREADS --number-of-queries=$QNUM \
    --create-schema=$DB \
    --query="SELECT SLEEP(0.001);" \
    --pre-query="SET SESSION MAX_EXECUTION_TIME=${SQL_TIMEOUT_MS};" >/dev/null 2>&1
done
echo "===== WARM UP 完成，sleep 10 秒 ====="
sleep 10

########################################
# 正式測試
########################################
echo "===== TiDB mysqlslap 壓測開始 ====="
printf "+---------+---------+---------+---------+---------+\n"
printf "| Threads |   RPS   |  AvgSec |  Loops  | ErrRate |\n"
printf "+---------+---------+---------+---------+---------+\n"

for t in $THREADS_LIST; do
  total_q=0; total_s=0; loops=0; errors=0
  PIDS=()

  #### 啟動監控
  for h in $TIDB_LIST; do
    sshpass -p 'root321' ssh -o StrictHostKeyChecking=no root@$h "
      mpstat 1 $DURATION > /tmp/mpstat_${t}.log &
      pidstat -p \$(pgrep -f tidb-server | head -n1) 1 $DURATION > /tmp/pidstat_tidb_${t}.log &
      pidstat -p \$(pgrep -f tiproxy | head -n1) 1 $DURATION > /tmp/pidstat_tipr_${t}.log &
      wait
    " &
    PIDS+=($!)
  done

  #### 執行 mysqlslap 測試
  end=$((SECONDS+DURATION))
  while [ $SECONDS -lt $end ]; do
    result=$(mysqlslap \
      --host=$HOST --port=$PORT --user=$USER \
      --concurrency=$t --number-of-queries=$QNUM \
      --create-schema=$DB \
      --query="SELECT 1;" \
      --pre-query="SET SESSION MAX_EXECUTION_TIME=${SQL_TIMEOUT_MS};" 2>&1)

    sec=$(echo "$result" | awk '/Average number of seconds to run all queries/ {print $(NF-1)}')
    if [[ "$sec" =~ ^[0-9]+(\.[0-9]+)?$ ]] && (( $(echo "$sec>0" | bc -l) )); then
      total_q=$((total_q+QNUM))
      total_s=$(echo "$total_s + $sec" | bc)
      loops=$((loops+1))
    fi
    if echo "$result" | grep -q "ERROR"; then
      errors=$((errors+1))
    fi
  done

  #### 等監控結束
  for pid in "${PIDS[@]}"; do
    wait $pid
  done

  #### 計算 RPS/Avg/ErrRate
  if [ $loops -gt 0 ]; then
    avg_s=$(echo "scale=3; $total_s/$loops" | bc)
    rps=$(echo "$total_q/$total_s" | bc)
    err_rate=$(echo "scale=2; ($errors/$loops)*100" | bc)
    printf "| %7d | %7d | %7s | %7d | %6s%% |\n" $t $rps $avg_s $loops $err_rate
  else
    avg_s="N/A"; rps="N/A"; err_rate="N/A"
    printf "| %7d | %7s | %7s | %7s | %6s |\n" $t "N/A" "N/A" "0" "N/A"
  fi

  #### CPU 使用率 Table
  row="$(date +'%F %T'),$t,$rps,$avg_s,$loops,$err_rate"

  echo "---- CPU Usage @ Threads=$t ----"
  echo "+---------+--------------------------+----------+"
  echo "| Comp    | NodeIP                   | CPU%     |"
  echo "+---------+--------------------------+----------+"

  for h in $TIDB_LIST; do
    cores=$(sshpass -p 'root321' ssh -o StrictHostKeyChecking=no root@$h "nproc")

    tidb=$(sshpass -p 'root321' ssh -o StrictHostKeyChecking=no root@$h \
      "awk '/Average/ {print \$8}' /tmp/pidstat_tidb_${t}.log")
    tidb_pct=$(echo "scale=2; $tidb/$cores" | bc)

    tipr=$(sshpass -p 'root321' ssh -o StrictHostKeyChecking=no root@$h \
      "awk '/Average/ {print \$8}' /tmp/pidstat_tipr_${t}.log")
    tipr_pct=$(echo "scale=2; $tipr/$cores" | bc)

    printf "| %-7s | %-24s | %7.2f%% |\n" "TiDB"    $h $tidb_pct
    printf "| %-7s | %-24s | %7.2f%% |\n" "TiProxy" $h $tipr_pct
    row="$row,$tidb_pct,$tipr_pct"
  done

  echo "+---------+--------------------------+----------+"

  #### 寫入 CSV
  echo "$row" >> $RESULT_CSV

  #### 清理暫存檔
  for h in $TIDB_LIST; do
    sshpass -p 'root321' ssh -o StrictHostKeyChecking=no root@$h \
      "rm -f /tmp/mpstat_${t}.log /tmp/pidstat_tidb_${t}.log /tmp/pidstat_tipr_${t}.log"
  done
done

printf "+---------+---------+---------+---------+---------+\n"
echo "===== 測試完成 ====="
