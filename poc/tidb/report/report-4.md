# TiDB Intro for DBA #5-4

## Failover Scenario

以下場景及測試數據以 Chapter: Testing Record的實測資料為準

目前測試條件尚不嚴謹，待完整腳本與案例設計完成後再更新完整合理 RTO / RPO 數據。

- **SQL 層（TiDB + Tiproxy）**
  - 單一 TiDB 停機（[影片](https://youtu.be/DYmA5Ne3nrE)）：故障 0，初步顯示 Tiproxy / TiDB 重新路由或重連於壓測流量下無感；但因僅為簡化流量情境，仍需模擬貼近線上負載後再更新正式數據。
  - 同時停所有 TiDB（[影片](https://youtu.be/92OqEJydPP8)）：出現 1 段 28,008 ms 中斷視窗；此為 SQL 層最壞 RTO，恢復後 `rto_seq` 持續運行。
- **PD 層（Leader / Follower 切換）**
  - 關閉 follower、leader 或整組 PD（含舊連線、新連線；[影片1](https://youtu.be/irOAXQ6ETKk), [影片2](https://youtu.be/Yi_WWKZMXwo), [影片3](https://youtu.be/h9d9Vumfjhs), [影片4](https://youtu.be/-9gCAvybCG0)）皆無故障段，RTO = 0，證實 PD failover 對 SQL 服務透明。
- **TiKV 層（Region / Store 故障）**
  - 寫入與讀取同時監控（[影片](https://youtu.be/bG8OAF1RtC8)）皆觀測到 41,124 ms 的中斷視窗。
- **RPO（Recovery Point Objective）/ RTO（Recovery Time Objective）**
  - 目前以 `rto_seq` Heartbeat 表推算，紀錄皆為 0；但測試條件尚不嚴謹，待完整腳本與案例設計完成後再更新完整合理數據。

## 環境資訊交付
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

## Testing Record

- **RTO（Recovery Time Objective）**
  - SQL 層：TiDB 重新路由 + 連線重建需要多少時間
    - shutdown one tidb [Click Here](https://youtu.be/DYmA5Ne3nrE)
    ```
    ========== SQL RTO Monitor Summary ==========
    Samples        : 128
    Fail segments  : 0
    Total fail (ms): 0
    無故障發生
    ==============================================
    ```

    - shutdown all tidb [Click Here](https://youtu.be/92OqEJydPP8)
    ```
    ========== SQL RTO Monitor Summary ==========
    Samples        : 26
    Fail segments  : 1
    Total fail (ms): 28008
    --------------- Failure Windows -------------
    FAIL#1 2025-11-20 15:40:44.700 -> 2025-11-20 15:41:03.099 (28008ms)
    ==============================================
    ```
  - PD 層：Leader 切換
    - shutdown PD Follower [Click Here](https://youtu.be/irOAXQ6ETKk)
    ```
    ========== SQL RTO Monitor Summary ==========
    Samples        : 29
    Fail segments  : 0
    Total fail (ms): 0
    無故障發生
    ==============================================
    ```
    - shutdown PD Leader [Click Here](https://youtu.be/Yi_WWKZMXwo)
    ```
    ========== SQL RTO Monitor Summary ==========
    Samples        : 77
    Fail segments  : 0
    Total fail (ms): 0
    無故障發生
    ==============================================
    ```
    - shutdown All PDs (still connect) [Click Here](https://youtu.be/h9d9Vumfjhs)
    ```
    ========== SQL RTO Monitor Summary ==========
    Samples        : 77
    Fail segments  : 0
    Total fail (ms): 0
    無故障發生
    ==============================================
    ```
    - shutdown All PDs (new connect) [Click Here](https://youtu.be/-9gCAvybCG0)
    Old Connection
    ```
    ========== SQL RTO Monitor Summary ==========
    Samples        : 95
    Fail segments  : 0
    Total fail (ms): 0
    無故障發生
    ==============================================
    ```
    New Connection
    ```
    ========== SQL RTO Monitor Summary ==========
    Samples        : 29
    Fail segments  : 0
    Total fail (ms): 0
    無故障發生
    ==============================================
    ```
  - TiKV 層：Region 故障恢復 [Click Here](https://youtu.be/bG8OAF1RtC8)
    Write
    ```
    ========== SQL RTO Monitor Summary ==========
    Samples        : 52
    Fail segments  : 1
    Total fail (ms): 41124
    --------------- Failure Windows -------------
    FAIL#1 2025-11-21 10:29:18.846 -> 2025-11-21 10:29:22.251 (41124ms)
    ==============================================
    ```
    Read
    ```
    ========== SQL RTO Monitor Summary ==========
    Samples        : 52
    Fail segments  : 1
    Total fail (ms): 41124
    --------------- Failure Windows -------------
    FAIL#1 2025-11-21 10:29:18.846 -> 2025-11-21 10:29:22.251 (41124ms)
    ==============================================
    ```
