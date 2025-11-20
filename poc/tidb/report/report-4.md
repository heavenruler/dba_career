# TiDB Intro for DBA #5-4

## 如何測試 RTO / RPO 數據

### Scenario
- **RTO（Recovery Time Objective）**
  - SQL 層：TiDB 重新路由 + 連線重建需 < 30 秒
  - PD 層：Leader 切換 < 30 秒
  - TiKV 層：Raft leader 轉移 + Region 補足需 < 90 秒
  - Re-Sharding：調度過程不得中斷 SQL 服務（RTO = 0）
- **RPO（Recovery Point Objective）**
  - 交易寫入以 Raft 多副本為前提 → 期望 0 秒
  - TiKV Re-Sharding 調度期間允許 < 5 秒追平時間

- **SQL Layer 不可用**：模擬 2/6 TiDB server 故障，觀察 Tiproxy 監控、連線重試、Session 粘滯行為
- **TiKV Layer 不可用**：下架單一或多個 store，觀察 Region leader 補位、txn retry、TiKV GC
- **TiKV Layer Re-Sharding**：Scale-out 再 scale-in，強迫 Region re-balance，觀察 PD 調度併發量

## 環境交代
```
[root@l-k8s-labroom-1 ~]# make display
date ; tiup cluster display tidb-demo
Wed Nov 19 11:07:35 CST 2025
Cluster type:       tidb
Cluster name:       tidb-demo
Cluster version:    v8.5.3
Deploy user:        root
SSH type:           builtin
Dashboard URL:      http://10.160.152.21:2379/dashboard
Dashboard URLs:     http://10.160.152.21:2379/dashboard
Grafana URL:        http://172.24.40.20:3000
ID                   Role        Host           Ports                 OS/Arch       Status   Data Dir                         Deploy Dir
--                   ----        ----           -----                 -------       ------   --------                         ----------
172.24.40.20:3000    grafana     172.24.40.20   3000                  linux/x86_64  Up       -                                /data/tidb-deploy/grafana-3000
10.160.152.21:2379   pd          10.160.152.21  2379/2380             linux/x86_64  Up|L|UI  /data/tidb-data/pd-2379          /data/tidb-deploy/pd-2379
10.160.152.22:2379   pd          10.160.152.22  2379/2380             linux/x86_64  Up       /data/tidb-data/pd-2379          /data/tidb-deploy/pd-2379
10.160.152.23:2379   pd          10.160.152.23  2379/2380             linux/x86_64  Up       /data/tidb-data/pd-2379          /data/tidb-deploy/pd-2379
172.24.40.17:2379    pd          172.24.40.17   2379/2380             linux/x86_64  Up       /data/tidb-data/pd-2379          /data/tidb-deploy/pd-2379
172.24.40.18:2379    pd          172.24.40.18   2379/2380             linux/x86_64  Up       /data/tidb-data/pd-2379          /data/tidb-deploy/pd-2379
172.24.40.19:2379    pd          172.24.40.19   2379/2380             linux/x86_64  Up       /data/tidb-data/pd-2379          /data/tidb-deploy/pd-2379
172.24.40.20:9090    prometheus  172.24.40.20   9090/9115/9100/12020  linux/x86_64  Up       /data/tidb-data/prometheus-9090  /data/tidb-deploy/prometheus-9090
10.160.152.21:4000   tidb        10.160.152.21  4000/10080            linux/x86_64  Up       -                                /data/tidb-deploy/tidb-4000
10.160.152.22:4000   tidb        10.160.152.22  4000/10080            linux/x86_64  Up       -                                /data/tidb-deploy/tidb-4000
10.160.152.23:4000   tidb        10.160.152.23  4000/10080            linux/x86_64  Up       -                                /data/tidb-deploy/tidb-4000
172.24.40.17:4000    tidb        172.24.40.17   4000/10080            linux/x86_64  Up       -                                /data/tidb-deploy/tidb-4000
172.24.40.18:4000    tidb        172.24.40.18   4000/10080            linux/x86_64  Up       -                                /data/tidb-deploy/tidb-4000
172.24.40.19:4000    tidb        172.24.40.19   4000/10080            linux/x86_64  Up       -                                /data/tidb-deploy/tidb-4000
10.160.152.24:20160  tikv        10.160.152.24  20160/20180           linux/x86_64  Up       /data/tidb-data/tikv-20160       /data/tidb-deploy/tikv-20160
172.24.40.20:20160   tikv        172.24.40.20   20160/20180           linux/x86_64  Up       /data/tidb-data/tikv-20160       /data/tidb-deploy/tikv-20160
10.160.152.21:6000   tiproxy     10.160.152.21  6000/6001             linux/x86_64  Up       -                                /data/tidb-deploy/tiproxy-6000
10.160.152.22:6000   tiproxy     10.160.152.22  6000/6001             linux/x86_64  Up       -                                /data/tidb-deploy/tiproxy-6000
10.160.152.23:6000   tiproxy     10.160.152.23  6000/6001             linux/x86_64  Up       -                                /data/tidb-deploy/tiproxy-6000
172.24.40.17:6000    tiproxy     172.24.40.17   6000/6001             linux/x86_64  Up       -                                /data/tidb-deploy/tiproxy-6000
172.24.40.18:6000    tiproxy     172.24.40.18   6000/6001             linux/x86_64  Up       -                                /data/tidb-deploy/tiproxy-6000
172.24.40.19:6000    tiproxy     172.24.40.19   6000/6001             linux/x86_64  Up       -                                /data/tidb-deploy/tiproxy-6000
Total nodes: 22
```







- **RTO（Recovery Time Objective）**
  - SQL 層：TiDB 重新路由 + 連線重建需 < 30 秒
    - shutdown one tidb
    [![IMAGE ALT TEXT HERE](http://img.youtube.com/vi/YOUTUBE_VIDEO_ID_HERE/0.jpg)](https://youtu.be/DYmA5Ne3nrE)

    - shutdown all tidb
  - PD 層：Leader 切換 < 30 秒
    - shutdown PD Follower
    - shutdown PD Leader
    - shutdown All PDs
  - TiKV 層：Raft leader 轉移 + Region 補足需 < 90 秒
  - Re-Sharding：調度過程不得中斷 SQL 服務（RTO = 0）