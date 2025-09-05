#!/bin/bash
# 統一轉換成「整機百分比」

HOST="172.24.40.25"
PORT=6000
USER="root"
PASS="1qaz@WSX"
DB="test"

#THREADS_LIST="50 100 200 250 500 750 1000"
THREADS_LIST="1 10 100"
DURATION=10
QNUM=10000
WARMUP_THREADS=100
WARMUP_TIME=10
TIMEOUT=1
SQL_TIMEOUT_MS=$((TIMEOUT*1000))
NORMALIZE=${NORMALIZE:-0}  # 1: 除以核心數得到整機百分比, 0: 直接使用 pidstat %CPU

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
    avg_s_fmt=$(printf '%0.3f' "$avg_s")
    rps=$(echo "scale=0; $total_q/$total_s" | bc) # 取整數 RPS
    err_rate=$(echo "scale=2; ($errors/$loops)*100" | bc)
  else
    avg_s_fmt="-"; rps=0; err_rate="-"
  fi

  #### CPU 使用率 (彙總：若多節點則取平均)
  tidb_sum=0; tipr_sum=0; host_cnt=0
  for h in $TIDB_LIST; do
      cores=$(sshpass -p 'root321' ssh -o StrictHostKeyChecking=no root@$h "nproc")
      awk_prog='BEGIN{col=0;found=0} 
        /^#/ {for(i=1;i<=NF;i++) if($i=="%CPU") col=i; next} 
        /^Average:/ && col {print $col; found=1; next} 
        /^[0-9]{2}:[0-9]{2}:[0-9]{2}/ && col && $2 ~ /^[0-9]+$/ {sum+=$col; n++} 
        END{ if(!found && n>0) printf("%.2f", sum/n) }'
      tidb=$(sshpass -p 'root321' ssh -o StrictHostKeyChecking=no root@$h "awk '$awk_prog' /tmp/pidstat_tidb_${t}.log 2>/dev/null || true")
      tipr=$(sshpass -p 'root321' ssh -o StrictHostKeyChecking=no root@$h "awk '$awk_prog' /tmp/pidstat_tipr_${t}.log 2>/dev/null || true")
      # 驗證為數字
      [[ $tidb =~ ^[0-9]+(\.[0-9]+)?$ ]] || tidb=0
      [[ $tipr =~ ^[0-9]+(\.[0-9]+)?$ ]] || tipr=0
      if [ "$NORMALIZE" = "1" ] && [ "$cores" -gt 0 ]; then
        tidb_pct=$(echo "scale=2; $tidb/$cores" | bc)
        tipr_pct=$(echo "scale=2; $tipr/$cores" | bc)
      else
        tidb_pct=$tidb
        tipr_pct=$tipr
      fi
      tidb_sum=$(echo "$tidb_sum + $tidb_pct" | bc)
      tipr_sum=$(echo "$tipr_sum + $tipr_pct" | bc)
      host_cnt=$((host_cnt+1))
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
  for h in $TIDB_LIST; do
    sshpass -p 'root321' ssh -o StrictHostKeyChecking=no root@$h \
      "rm -f /tmp/mpstat_${t}.log /tmp/pidstat_tidb_${t}.log /tmp/pidstat_tipr_${t}.log"
  done
done

printf '%s\n' "+---------+---------+---------+---------+---------+----------+----------+"
echo "===== 測試完成 ====="
