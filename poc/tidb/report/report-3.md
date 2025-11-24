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
  - Latency ~= 50 ms
  - Latency ~= 100 ms
  - Latency ~= 200 ms
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