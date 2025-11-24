# TiDB Intro for DBA #5-3

## Chaos engineering for leased-line quality across multiple data centers

### Scenario

面向測試內容與容忍值如下，採用同一套 `monitor_rto_sql.sh` / `write_rto_sql.sh` Heartbeat 設計：

- **RTT 延遲（50 / 100 / 200 ms）**
  - 在 TiDB、PD、TiKV 之間逐層注入額外延遲，觀察 `seq_val` 是否停滯、Tiproxy 連線是否先異常告警。

- **頻寬瓶頸（30Mbps / 10Mbps / 5Mbps）**
  - 針對 TiDB 上行、TiKV 下行等方向限速，同步觀察 TiKV `region` pending、PD scheduler 採納策略；期望在低頻寬下仍維持運作。

- **丟包（0% / 0.1% / 1%）**
  - 透過 `chaosd` 對不同專線注入封包遺失，檢驗 TiKV Raft 重傳與 TiDB coprocessor 重試；若 Heartbeat 出現 gap，需立刻標記為 RPO 事件並擴增追蹤資料。

每個條件下都可搭配 `tiup cluster display`、Grafana 面板確認 PD/RoF/TiKV 延遲與負載變化，測試記錄可附於報告供進一步分析。

----

### 測試環境資訊 交付
```
[root@l-k8s-labroom-1 ~]# date ; tiup cluster display tidb-demo
Mon Nov 24 09:43:29 CST 2025
Cluster type:       tidb
Cluster name:       tidb-demo
Cluster version:    v8.5.3
Deploy user:        root
SSH type:           builtin
Dashboard URL:      http://10.160.152.21:2379/dashboard
Dashboard URLs:     http://10.160.152.21:2379/dashboard
Grafana URL:        http://172.24.40.20:3000
ID                   Role        Host           Ports                 OS/Arch       Status  Data Dir                         Deploy Dir
--                   ----        ----           -----                 -------       ------  --------                         ----------
172.24.40.20:3000    grafana     172.24.40.20   3000                  linux/x86_64  Up      -                                /data/tidb-deploy/grafana-3000
10.160.152.21:2379   pd          10.160.152.21  2379/2380             linux/x86_64  Up|UI   /data/tidb-data/pd-2379          /data/tidb-deploy/pd-2379
10.160.152.22:2379   pd          10.160.152.22  2379/2380             linux/x86_64  Up      /data/tidb-data/pd-2379          /data/tidb-deploy/pd-2379
10.160.152.23:2379   pd          10.160.152.23  2379/2380             linux/x86_64  Up|L    /data/tidb-data/pd-2379          /data/tidb-deploy/pd-2379
172.24.40.17:2379    pd          172.24.40.17   2379/2380             linux/x86_64  Up      /data/tidb-data/pd-2379          /data/tidb-deploy/pd-2379
172.24.40.18:2379    pd          172.24.40.18   2379/2380             linux/x86_64  Up      /data/tidb-data/pd-2379          /data/tidb-deploy/pd-2379
172.24.40.19:2379    pd          172.24.40.19   2379/2380             linux/x86_64  Up      /data/tidb-data/pd-2379          /data/tidb-deploy/pd-2379
172.24.40.20:9090    prometheus  172.24.40.20   9090/9115/9100/12020  linux/x86_64  Up      /data/tidb-data/prometheus-9090  /data/tidb-deploy/prometheus-9090
10.160.152.21:4000   tidb        10.160.152.21  4000/10080            linux/x86_64  Up      -                                /data/tidb-deploy/tidb-4000
10.160.152.22:4000   tidb        10.160.152.22  4000/10080            linux/x86_64  Up      -                                /data/tidb-deploy/tidb-4000
10.160.152.23:4000   tidb        10.160.152.23  4000/10080            linux/x86_64  Up      -                                /data/tidb-deploy/tidb-4000
172.24.40.17:4000    tidb        172.24.40.17   4000/10080            linux/x86_64  Up      -                                /data/tidb-deploy/tidb-4000
172.24.40.18:4000    tidb        172.24.40.18   4000/10080            linux/x86_64  Up      -                                /data/tidb-deploy/tidb-4000
172.24.40.19:4000    tidb        172.24.40.19   4000/10080            linux/x86_64  Up      -                                /data/tidb-deploy/tidb-4000
10.160.152.24:20160  tikv        10.160.152.24  20160/20180           linux/x86_64  Up      /data/tidb-data/tikv-20160       /data/tidb-deploy/tikv-20160
172.24.40.20:20160   tikv        172.24.40.20   20160/20180           linux/x86_64  Up      /data/tidb-data/tikv-20160       /data/tidb-deploy/tikv-20160
10.160.152.21:6000   tiproxy     10.160.152.21  6000/6001             linux/x86_64  Up      -                                /data/tidb-deploy/tiproxy-6000
10.160.152.22:6000   tiproxy     10.160.152.22  6000/6001             linux/x86_64  Up      -                                /data/tidb-deploy/tiproxy-6000
10.160.152.23:6000   tiproxy     10.160.152.23  6000/6001             linux/x86_64  Up      -                                /data/tidb-deploy/tiproxy-6000
172.24.40.17:6000    tiproxy     172.24.40.17   6000/6001             linux/x86_64  Up      -                                /data/tidb-deploy/tiproxy-6000
172.24.40.18:6000    tiproxy     172.24.40.18   6000/6001             linux/x86_64  Up      -                                /data/tidb-deploy/tiproxy-6000
172.24.40.19:6000    tiproxy     172.24.40.19   6000/6001             linux/x86_64  Up      -                                /data/tidb-deploy/tiproxy-6000
Total nodes: 22
```

----

## **RTT 延遲（50 / 100 / 200 ms）**

- TiProxy
  - Latency ~= Default @ mysqlslap_logs_20251124_095128
    | concurrency | avg(s) | min(s) | max(s) | avg_qps | avg_ms/req |
    |--------------|--------|--------|--------|----------|-------------|
    | 10 | 1.03 | 1.02 | 1.03 | 97434.23 | 0.01 |
    | 50 | 1.03 | 1.03 | 1.04 | 96618.36 | 0.01 |
    | 100 | 1.05 | 1.05 | 1.06 | 95026.92 | 0.01 |
    | 250 | 1.07 | 1.07 | 1.07 | 93254.59 | 0.01 |
    | 500 | 1.11 | 1.10 | 1.13 | 89901.11 | 0.01 |
    | 1000 | 2.40 | 2.37 | 2.44 | 41631.97 | 0.02 |
  - Latency ~= 50 ms @ mysqlslap_logs_20251124_100636
    | concurrency | avg(s) | min(s) | max(s) | avg_qps | avg_ms/req |
    |--------------|--------|--------|--------|----------|-------------|
    | 10 | 4.50 | 4.43 | 4.63 | 22241.99 | 0.04 |
    | 50 | 4.57 | 4.44 | 4.63 | 21888.22 | 0.05 |
    | 100 | 4.57 | 4.44 | 4.64 | 21881.84 | 0.05 |
    | 250 | 4.65 | 4.64 | 4.66 | 21511.54 | 0.05 |
    | 500 | 6.03 | 5.79 | 6.22 | 16585.58 | 0.06 |
    | 1000 | 9.10 | 8.76 | 9.67 | 10988.21 | 0.09 |
  - Latency ~= 100 ms @ mysqlslap_logs_20251124_101151
    | concurrency | avg(s) | min(s) | max(s) | avg_qps | avg_ms/req |
    |--------------|--------|--------|--------|----------|-------------|
    | 10 | 8.50 | 8.23 | 9.03 | 11769.32 | 0.08 |
    | 50 | 8.10 | 7.84 | 8.23 | 12343.65 | 0.08 |
    | 100 | 8.24 | 8.23 | 8.24 | 12140.83 | 0.08 |
    | 250 | 8.24 | 8.24 | 8.25 | 12128.56 | 0.08 |
    | 500 | 8.91 | 8.64 | 9.14 | 11219.57 | 0.09 |
    | 1000 | 16.12 | 15.69 | 16.63 | 6201.94 | 0.16 |
  - Latency ~= 200 ms @ mysqlslap_logs_20251124_101616
    | concurrency | avg(s) | min(s) | max(s) | avg_qps | avg_ms/req |
    |--------------|--------|--------|--------|----------|-------------|
    | 10 | 14.37 | 13.84 | 14.63 | 6961.04 | 0.14 |
    | 50 | 14.64 | 14.63 | 14.64 | 6830.76 | 0.15 |
    | 100 | 14.64 | 14.64 | 14.65 | 6830.13 | 0.15 |
    | 250 | 14.91 | 14.65 | 15.44 | 6705.26 | 0.15 |
    | 500 | 17.72 | 17.12 | 18.16 | 5642.28 | 0.18 |
    | 1000 | 38.34 | 32.68 | 47.28 | 2608.58 | 0.38 |
- TiDB
  - Latency ~= Default @ mysqlslap_logs_20251124_103210
    | concurrency | avg(s) | min(s) | max(s) | avg_qps | avg_ms/req |
    |--------------|--------|--------|--------|----------|-------------|
    | 10 | 1.03 | 1.02 | 1.03 | 97434.23 | 0.01 |
    | 50 | 1.04 | 1.03 | 1.04 | 96401.03 | 0.01 |
    | 100 | 1.05 | 1.05 | 1.05 | 95268.34 | 0.01 |
    | 250 | 1.09 | 1.08 | 1.10 | 91631.03 | 0.01 |
    | 500 | 1.23 | 1.13 | 1.40 | 81543.90 | 0.01 |
    | 1000 | 2.57 | 2.47 | 2.67 | 38870.17 | 0.03 |
  - Latency ~= 50 ms @ mysqlslap_logs_20251124_103412
    | concurrency | avg(s) | min(s) | max(s) | avg_qps | avg_ms/req |
    |--------------|--------|--------|--------|----------|-------------|
    | 10 | 3.03 | 3.03 | 3.03 | 33003.30 | 0.03 |
    | 50 | 3.04 | 3.03 | 3.04 | 32948.93 | 0.03 |
    | 100 | 3.04 | 3.04 | 3.05 | 32869.51 | 0.03 |
    | 250 | 3.06 | 3.06 | 3.07 | 32672.62 | 0.03 |
    | 500 | 3.59 | 3.58 | 3.62 | 27824.15 | 0.04 |
    | 1000 | 6.38 | 5.89 | 7.16 | 15673.98 | 0.06 |
  - Latency ~= 100 ms @ mysqlslap_logs_20251124_103606
    | concurrency | avg(s) | min(s) | max(s) | avg_qps | avg_ms/req |
    |--------------|--------|--------|--------|----------|-------------|
    | 10 | 5.03 | 5.03 | 5.03 | 19868.87 | 0.05 |
    | 50 | 5.04 | 5.03 | 5.05 | 19838.65 | 0.05 |
    | 100 | 5.05 | 5.04 | 5.07 | 19787.61 | 0.05 |
    | 250 | 5.06 | 5.06 | 5.06 | 19764.15 | 0.05 |
    | 500 | 5.44 | 5.39 | 5.53 | 18382.35 | 0.05 |
    | 1000 | 10.30 | 9.95 | 10.84 | 9707.17 | 0.10 |
  - Latency ~= 200 ms







- PD
  - Leader
    - Latency ~= Default
    - Latency ~= 50 ms
    - Latency ~= 100 ms
    - Latency ~= 200 ms
  - Follower
    - Latency ~= Default
    - Latency ~= 50 ms
    - Latency ~= 100 ms
    - Latency ~= 200 ms
- TiKV
  - Latency ~= Default
  - Latency ~= 50 ms
  - Latency ~= 100 ms
  - Latency ~= 200 ms

----

## **頻寬瓶頸（30Mbps / 10Mbps / 5Mbps）**
- TiDB
  - Bandwidth ~= 10Mbps
  - Bandwidth ~= 5Mbps
- PD
  - Leader
    - Bandwidth ~= 10Mbps
    - Bandwidth ~= 5Mbps
  - Follower
    - Bandwidth ~= 10Mbps
    - Bandwidth ~= 5Mbps
- TiKV
  - Bandwidth ~= 10Mbps
  - Bandwidth ~= 5Mbps

----

## **丟包（0% / 0.1% / 1%）**
- TiDB
  - Packet Loss ~= 0.1%
  - Packet Loss ~= 1%
- PD
  - Leader
    - Packet Loss ~= 0.1%
    - Packet Loss ~= 1%
  - Follower
    - Packet Loss ~= 0.1%
    - Packet Loss ~= 1%
- TiKV
  - Packet Loss ~= 0.1%
  - Packet Loss ~= 1%