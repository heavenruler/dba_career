# TiDB Intro for DBA #5-3

## Chaos engineering for leased-line quality across multiple data centers

### Scenario

面向測試內容與容忍值如下，採用同一套 `monitor_rto_sql.sh` / `write_rto_sql.sh` Heartbeat 設計：

- **RTT 延遲（50 / 100 / 200 ms）**
  - 在 TiDB、PD、TiKV 之間逐層注入額外延遲，觀察 `seq_val` 是否停滯、Tiproxy 連線是否先報 fail；目標 RTO 為 Tiproxy 能在 2-5 秒內切換至健康節點並保持 Heartbeat。

- **頻寬瓶頸（30Mbps / 10Mbps / 5Mbps）**
  - 針對 TiDB 上行、TiKV 下行等方向限速，同步觀察 TiKV `region` pending、PD scheduler 採納策略；期望在低頻寬下仍保持 P99<200ms，無額外 RPO。

- **丟包（0% / 0.1% / 1%）**
  - 透過 `chaosd` 對不同專線注入封包遺失，檢驗 TiKV Raft 重傳與 TiDB coprocessor 重試；若 Heartbeat 出現 gap，需立刻標記為 RPO 事件並擴增追蹤資料。

每個條件下都可搭配 `tiup cluster display`、Grafana 面板確認 PD/RoF/TiKV 延遲與負載變化，測試記錄可附於報告供進一步分析。

----

- **RTT 延遲（50 / 100 / 200 ms）**
  - TiDB
    - Latency ~= 50 ms
    - Latency ~= 100 ms
    - Latency ~= 200 ms
  - PD
    - Leader
      - Latency ~= 50 ms
      - Latency ~= 100 ms
      - Latency ~= 200 ms
    - Follower
      - Latency ~= 50 ms
      - Latency ~= 100 ms
      - Latency ~= 200 ms
  - TiKV
    - Latency ~= 50 ms
    - Latency ~= 100 ms
    - Latency ~= 200 ms