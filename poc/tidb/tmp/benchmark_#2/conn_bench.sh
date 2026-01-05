#!/bin/bash
# 統一轉換成「整機百分比」

HOST="172.24.40.25"
PORT=6000
USER="root"
PASS="1qaz@WSX"
DB="test"

#THREADS_LIST="50 100 200 250 500 750 1000"
THREADS_LIST="1 10 100"
SAMPLER_INTERVAL=${SAMPLER_INTERVAL:-1}
DURATION=10
QNUM=10000
WARMUP_THREADS=100
WARMUP_TIME=10
TIMEOUT=1
SQL_TIMEOUT_MS=$((TIMEOUT*1000))
NORMALIZE=${NORMALIZE:-0}  # 1: 除以核心數得到整機百分比, 0: 直接使用 pidstat %CPU
DEBUG_CPU=${DEBUG_CPU:-0}  # 1: 輸出解析細節並保留 pidstat 日誌

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
printf '%s\n' "+---------+---------+---------+---------+---------+----------+----------+"
printf '%s\n' "| Threads |   RPS   |  AvgSec |  Loops  | ErrRate |  TiDB%   | TiProxy% |"
printf '%s\n' "+---------+---------+---------+---------+---------+----------+----------+"

for t in $THREADS_LIST; do
  total_q=0; total_s=0; loops=0; errors=0
  PIDS=()

  #### 啟動監控 (ps 取樣取代 pidstat，避免格式差異)
  for h in $TIDB_LIST; do
    sshpass -p 'root321' ssh -o StrictHostKeyChecking=no root@$h "
      tidb_pid=\$(pgrep -f tidb-server | head -n1); \
      tipr_pid=\$(pgrep -f tiproxy | head -n1); \
      echo \$tidb_pid > /tmp/tidb_pid_${t}; \
      echo \$tipr_pid > /tmp/tipr_pid_${t}; \
      : > /tmp/cpu_${t}.csv; \
      end_time=\$((\$(date +%s)+$DURATION)); \
      while [ \$(date +%s) -lt \$end_time ]; do \
        ts=\$(date +%s); \
        if [ -n \"\$tidb_pid\" ]; then tidb_cpu=\$(ps -p \$tidb_pid -o %cpu= 2>/dev/null | awk '{print $1+0}'); else tidb_cpu=0; fi; \
        if [ -n \"\$tipr_pid\" ]; then tipr_cpu=\$(ps -p \$tipr_pid -o %cpu= 2>/dev/null | awk '{print $1+0}'); else tipr_cpu=0; fi; \
        echo \"$t,\$ts,\$tidb_cpu,\$tipr_cpu\" >> /tmp/cpu_${t}.csv; \
        sleep $SAMPLER_INTERVAL; \
      done
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
    avg_s_fmt=$(printf '%0.3f' "$avg_s")
    rps=$(echo "scale=0; $total_q/$total_s" | bc) # 取整數 RPS
    err_rate=$(echo "scale=2; ($errors/$loops)*100" | bc)
  else
    avg_s_fmt="-"; rps=0; err_rate="-"
  fi

  #### CPU 使用率 (彙總：讀取 ps 取樣 CSV)
  tidb_sum=0; tipr_sum=0; host_cnt=0
  for h in $TIDB_LIST; do
    cores=$(sshpass -p 'root321' ssh -o StrictHostKeyChecking=no root@$h "nproc")
    # 聚合：欄位格式 t,epoch,tidb_cpu,tipr_cpu
    avgs=$(sshpass -p 'root321' ssh -o StrictHostKeyChecking=no root@$h "awk -F, '{tidb+=\$3; tipr+=\$4; n++} END{ if(n>0) printf(\"%.4f %.4f %d\", tidb/n, tipr/n, n); }' /tmp/cpu_${t}.csv 2>/dev/null || true")
    tidb_raw=$(echo "$avgs" | awk '{print $1}')
    tipr_raw=$(echo "$avgs" | awk '{print $2}')
    samples=$(echo "$avgs" | awk '{print $3}')
    [[ $tidb_raw =~ ^[0-9]+(\.[0-9]+)?$ ]] || tidb_raw=0
    [[ $tipr_raw =~ ^[0-9]+(\.[0-9]+)?$ ]] || tipr_raw=0
    if [ "$NORMALIZE" = "1" ] && [[ $cores =~ ^[0-9]+$ ]] && [ $cores -gt 0 ]; then
      tidb_pct=$(echo "scale=4; $tidb_raw/$cores" | bc 2>/dev/null | awk '{printf "%.2f", ($0==""?0:$0)}')
      tipr_pct=$(echo "scale=4; $tipr_raw/$cores" | bc 2>/dev/null | awk '{printf "%.2f", ($0==""?0:$0)}')
    else
      tidb_pct=$(printf '%.2f' "$tidb_raw")
      tipr_pct=$(printf '%.2f' "$tipr_raw")
    fi
    tidb_sum=$(echo "$tidb_sum + $tidb_pct" | bc)
    tipr_sum=$(echo "$tipr_sum + $tipr_pct" | bc)
    host_cnt=$((host_cnt+1))
    if [ "$DEBUG_CPU" = "1" ]; then
      echo "[DEBUG_CPU] host=$h t=$t samples=$samples tidb_raw=$tidb_raw tipr_raw=$tipr_raw pct_tidb=$tidb_pct pct_tipr=$tipr_pct" >&2
      sshpass -p 'root321' ssh -o StrictHostKeyChecking=no root@$h "head -n 10 /tmp/cpu_${t}.csv | sed 's/^/[cpu_csv] /'" >&2 || true
    fi
  done
  if [ $host_cnt -gt 0 ]; then
    tidb_avg=$(echo "scale=2; $tidb_sum/$host_cnt" | bc)
    tipr_avg=$(echo "scale=2; $tipr_sum/$host_cnt" | bc)
  else
    tidb_avg=0; tipr_avg=0
  fi

  #### 印出統一 Row (無 ScaleEff)
  if [ "$err_rate" != "-" ]; then
    printf "| %7d | %7d | %7s | %7d | %6s%% | %8.2f | %8.2f |\n" \
      $t $rps $avg_s_fmt $loops $err_rate $tidb_avg $tipr_avg
  else
    printf "| %7d | %7s | %7s | %7s | %6s | %8s | %8s |\n" \
      $t "-" "-" "0" "-" "-" "-"
  fi

  #### 寫入 CSV (沿用原欄位)
  row="$(date +'%F %T'),$t,$rps,$avg_s_fmt,$loops,$err_rate,$tidb_avg,$tipr_avg"
  echo "$row" >> $RESULT_CSV

  #### 清理暫存檔
#  if [ "$DEBUG_CPU" != "1" ]; then
#    for h in $TIDB_LIST; do
#      sshpass -p 'root321' ssh -o StrictHostKeyChecking=no root@$h \
#        "rm -f /tmp/mpstat_${t}.log /tmp/cpu_${t}.csv /tmp/tidb_pid_${t} /tmp/tipr_pid_${t}"
#    done
#  else
#    echo "[DEBUG_CPU] 保留遠端 pidstat/mpstat 日誌 (t=$t)" >&2
#  fi
done

printf '%s\n' "+---------+---------+---------+---------+---------+----------+----------+"
echo "===== 測試完成 ====="
