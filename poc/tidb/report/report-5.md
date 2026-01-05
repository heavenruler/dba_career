# TiDB Intro for DBA #5-5 

[Ver: Hackmd](https://hackmd.io/@skhUTGhBTuKf0SIjiqI3-g/r1Z05J4fWx)

[Ver: Github](https://github.com/heavenruler/dba_career/blob/master/poc/tidb/report/report-5.md)

## Staging AC-API 整合測試紀錄

## 流量架構示意圖

![image](https://hackmd.io/_uploads/SJF-xiwGWg.png)

---

## 可觀測 (效能對照) 數據

### Staging AC 基礎量 壓力測試 觀測總結

在相同壓測來源，兩者於 CPU、Network、IO、QPS、Latency 呈現明顯差異，可歸納如下：

| 效能指標 | ProxySQL + MariaDB (P+M) 集中式數據 | TiDB Cluster (TiDB) 分佈式數據 | P+M 相較 TiDB 的差異比例 (約略值) | 關鍵差異點 |
| :--- | :--- | :--- | :--- | :--- |
| **CPU 負載 (儲存層)** | MariaDB MAX **11.5%** | TiKV MAX **5.8%** | P+M 核心節點 CPU 負載約高 **1.98 倍** | MariaDB 單點瓶頸在集中架構呈現較明顯。 |
| **I/O 寫入 (儲存層)** | MariaDB Disk Write **1.9 MB/s** | TiKV sdb throughput current **316.00 KB/s** | P+M I/O 寫入集中度約高 **6.0 倍** | TiDB 將 I/O 寫入分散到 TiKV 節點。 |
| **網路流量 (Outbound)** | ProxySQL Outbound AVG **11.64 MB/s** | TiDB/Proxy/PD Outbound current **587 KB/s** | 參考數據 | Outbound 去 NULL 與正確回應的差異。 |
| **P+M 查詢量 (Client Questions)** | ProxySQL 接收 AVG **5.85K** ; MariaDB 處理 AVG **2K** | TiDB Select QPS 113 | P+M 核心處理量約高 17.7 倍 | MariaDB 實際查詢量: (2K) 約為 TiDB Select QPS (113) 的 17.7 倍。但負載僅多 TiDB 1.98 倍差異。 |

----

## Staging 壓測時間點

- [AC 基礎量 壓力測試 @ 2025-12-05 (五) 11:30 ~ 2025-12-05 (五) 18:00](https://teams.microsoft.com/l/message/19:c44e126d5a4e4f42a1fdc5f0c71c942c@thread.skype/1764905115320?tenantId=e5b7696b-abd7-48ed-9482-723ead81e6fd&groupId=442a8629-6c1b-435f-9c92-268280d1f25f&parentMessageId=1764905115320&teamName=announcement&channelName=%E9%9D%9E%E7%B7%9A%E4%B8%8A%E4%BD%9C%E6%A5%AD%E5%85%AC%E5%91%8A&createdTime=1764905115320)

- [AC 基礎量 壓力測試 @ 2025-12-05 (五) 18:00 ~ 2025-12-05 (五) 20:30](https://teams.microsoft.com/l/message/19:c44e126d5a4e4f42a1fdc5f0c71c942c@thread.skype/1764927638765?tenantId=e5b7696b-abd7-48ed-9482-723ead81e6fd&groupId=442a8629-6c1b-435f-9c92-268280d1f25f&parentMessageId=1764927638765&teamName=announcement&channelName=%E9%9D%9E%E7%B7%9A%E4%B8%8A%E4%BD%9C%E6%A5%AD%E5%85%AC%E5%91%8A&createdTime=1764927638765)

- [AC 基礎量 壓力測試 @ 2025-12-08 (一) 12:00 ~ 2025-12-08 (一) 13:00](https://teams.microsoft.com/l/message/19:c44e126d5a4e4f42a1fdc5f0c71c942c@thread.skype/1765166484458?tenantId=e5b7696b-abd7-48ed-9482-723ead81e6fd&groupId=442a8629-6c1b-435f-9c92-268280d1f25f&parentMessageId=1765166484458&teamName=announcement&channelName=%E9%9D%9E%E7%B7%9A%E4%B8%8A%E4%BD%9C%E6%A5%AD%E5%85%AC%E5%91%8A&createdTime=1765166484458)

- [AC 基礎量 壓力測試 @ 2025-12-08 (一) 18:00 ~ 2025-12-08 (一) 19:00](https://teams.microsoft.com/l/message/19:c44e126d5a4e4f42a1fdc5f0c71c942c@thread.skype/1765171405602?tenantId=e5b7696b-abd7-48ed-9482-723ead81e6fd&groupId=442a8629-6c1b-435f-9c92-268280d1f25f&parentMessageId=1765171405602&teamName=announcement&channelName=%E9%9D%9E%E7%B7%9A%E4%B8%8A%E4%BD%9C%E6%A5%AD%E5%85%AC%E5%91%8A&createdTime=1765171405602)

- [AC 基礎量 壓力測試 @ 2025-12-09 (二) 12:00 ~ 2025-12-09 (二) 13:00](https://teams.microsoft.com/l/message/19:c44e126d5a4e4f42a1fdc5f0c71c942c@thread.skype/1765249368164?tenantId=e5b7696b-abd7-48ed-9482-723ead81e6fd&groupId=442a8629-6c1b-435f-9c92-268280d1f25f&parentMessageId=1765249368164&teamName=announcement&channelName=%E9%9D%9E%E7%B7%9A%E4%B8%8A%E4%BD%9C%E6%A5%AD%E5%85%AC%E5%91%8A&createdTime=1765249368164)

- [AC 基礎量 壓力測試 @ 2025-12-09 (二) 18:00 ~ 2025-12-09 (二) 19:00](https://teams.microsoft.com/l/message/19:c44e126d5a4e4f42a1fdc5f0c71c942c@thread.skype/1765266380849?tenantId=e5b7696b-abd7-48ed-9482-723ead81e6fd&groupId=442a8629-6c1b-435f-9c92-268280d1f25f&parentMessageId=1765266380849&teamName=announcement&channelName=%E9%9D%9E%E7%B7%9A%E4%B8%8A%E4%BD%9C%E6%A5%AD%E5%85%AC%E5%91%8A&createdTime=1765266380849)

- [AC 基礎量 壓力測試 @ 2025-12-10 (三) 12:00 ~ 2025-12-10 (三) 13:00](https://teams.microsoft.com/l/message/19:c44e126d5a4e4f42a1fdc5f0c71c942c@thread.skype/1765331401195?tenantId=e5b7696b-abd7-48ed-9482-723ead81e6fd&groupId=442a8629-6c1b-435f-9c92-268280d1f25f&parentMessageId=1765331401195&teamName=announcement&channelName=%E9%9D%9E%E7%B7%9A%E4%B8%8A%E4%BD%9C%E6%A5%AD%E5%85%AC%E5%91%8A&createdTime=1765331401195)

- {Sample from here.} [AC 基礎量 壓力測試 @ 2025-12-10 (三) 18:00 ~ 2025-12-10 (三) 19:00 ](https://teams.microsoft.com/l/message/19:c44e126d5a4e4f42a1fdc5f0c71c942c@thread.skype/1765343548564?tenantId=e5b7696b-abd7-48ed-9482-723ead81e6fd&groupId=442a8629-6c1b-435f-9c92-268280d1f25f&parentMessageId=1765343548564&teamName=announcement&channelName=%E9%9D%9E%E7%B7%9A%E4%B8%8A%E4%BD%9C%E6%A5%AD%E5%85%AC%E5%91%8A&createdTime=1765343548564)

## ProxySQL with MariaDB

CPU Usage

[s-proxysql-acapi-1](https://pmm.104-staging.com.tw/graph/d/qyzrQGHmk/system-overview?refresh=1m&orgId=1&panelId=2&fullscreen&edit&var-interval=$__auto_interval_interval&var-host=s-proxysql2-acapi-1&from=1765338900000&to=1765343100000) AVG 4.2%
![image](https://hackmd.io/_uploads/BJxV0KLGbx.png)

[s-m075-1](https://pmm.104-staging.com.tw/graph/d/qyzrQGHmk/system-overview?refresh=1m&orgId=1&panelId=2&fullscreen&edit&from=1765338900000&to=1765343100000&var-interval=$__auto_interval_interval&var-host=s-m075-1) AVG 8.1%
![image](https://hackmd.io/_uploads/BJa4RYIMbx.png)

Network Traffic

[s-proxysql-acapi-1](https://pmm.104-staging.com.tw/graph/d/qyzrQGHmk/system-overview?refresh=1m&orgId=1&panelId=21&fullscreen&edit&from=1765338900000&to=1765343100000&var-interval=$__auto_interval_interval&var-host=s-proxysql2-acapi-1) Inbound AVG: 8.1MB/s ; Outbound AVG: 9.5MB/s
![image](https://hackmd.io/_uploads/r1b3AtIGWg.png)

[s-m075-1](https://pmm.104-staging.com.tw/graph/d/qyzrQGHmk/system-overview?refresh=1m&orgId=1&panelId=21&fullscreen&edit&var-interval=$__auto_interval_interval&var-host=s-m075-1&from=1765338900000&to=1765343100000) Outbound AVG: 6.7MB/s
![image](https://hackmd.io/_uploads/SJjYRYUGbl.png)

I/O Activity

[s-proxysql-acapi-1](https://pmm.104-staging.com.tw/graph/d/qyzrQGHmk/system-overview?refresh=1m&orgId=1&panelId=31&fullscreen&edit&from=1765338900000&to=1765343100000&var-interval=$__auto_interval_interval&var-host=s-proxysql2-acapi-1) Disk Write: 3.8KB/s
![image](https://hackmd.io/_uploads/ry7fyqUGbg.png)

[s-m075-1](https://pmm.104-staging.com.tw/graph/d/qyzrQGHmk/system-overview?refresh=1m&orgId=1&panelId=31&fullscreen&edit&from=1765338900000&to=1765343100000&var-interval=$__auto_interval_interval&var-host=s-m075-1) Disk Write: 1.9MB/s
![image](https://hackmd.io/_uploads/SJMbk9LM-x.png)


[ProxySQL Client Questions](https://pmm.104-staging.com.tw/graph/d/fwWR9oiiz/proxysql-overview?refresh=1m&panelId=56&fullscreen&edit&orgId=1&var-interval=$__auto_interval_interval&var-proxysql=s-proxysql2-acapi-1&var-hostgroup=10&var-hostgroup=11&from=1765338900000&to=1765343100000) AVG: 5.85K ; Max: 7k
![image](https://hackmd.io/_uploads/r1BdJcIzWl.png)

[MariaDB Questions](https://pmm.104-staging.com.tw/graph/d/MQWgroiiz/mysql-overview?refresh=1m&panelId=53&fullscreen&edit&orgId=1&var-interval=$__auto_interval_interval&var-host=s-m075-1&from=1765338900000&to=1765343100000) AVG: 2K ; Max: 2.4k
![image](https://hackmd.io/_uploads/r1sAyc8G-l.png)

[Top Command Counters](https://pmm.104-staging.com.tw/graph/d/MQWgroiiz/mysql-overview?refresh=1m&panelId=14&fullscreen&edit&orgId=1&var-interval=$__auto_interval_interval&var-host=s-m075-1&from=1765338900000&to=1765343100000) stmt_exec: 2k ; select: 2k
![image](https://hackmd.io/_uploads/BJUmec8MZe.png)

[InnoDB Row Operations](https://pmm.104-staging.com.tw/graph/d/giGgrTimz/mysql-innodb-metrics?refresh=1m&panelId=23&fullscreen&edit&orgId=1&var-interval=$__auto_interval_interval&var-host=s-m075-1&from=1765338900000&to=1765343100000) Row read operations AVG: 32.7K
![image](https://hackmd.io/_uploads/r1rYx9LfZg.png)

[InnoDB Read/Write Status](https://pmm.104-staging.com.tw/graph/d/giGgrTimz/mysql-innodb-metrics?refresh=1m&orgId=1&var-interval=$__auto_interval_interval&var-host=s-m075-1&from=1765338900000&to=1765343100000)

```
Data Writes
max: 98.83
avg: 74.10

Data Fsyncs
max: 54.05
avg: 40.49

Log Writes
max: 16.50
avg: 12.50
```
![image](https://hackmd.io/_uploads/rkeX-q8M-x.png)

----

## TiDB Cluster

- CPU Usage

[TiProxy/TiDB/PD](http://172.21.40.20:3000/d/000000001/tidb-cluster-node_exporter?editPanel=2&orgId=1&from=1765338900000&to=1765343100000&var-interval=1m&var-host=172.21.40.17:9100&var-buddyinfozone=All) Max: 3.5 ; 8% (with PD Leader)
![image](https://hackmd.io/_uploads/rJIcm5Uzbg.png)
![image](https://hackmd.io/_uploads/HJYTQ9UMbe.png)
![image](https://hackmd.io/_uploads/BJH0Xc8z-l.png)

[TiKV](http://172.21.40.20:3000/d/000000001/tidb-cluster-node_exporter?editPanel=2&orgId=1&from=1765338900000&to=1765343100000&var-interval=1m&var-host=172.21.40.20:9100&var-buddyinfozone=All)Max: 5.8%
![image](https://hackmd.io/_uploads/BymJVqIfZl.png)


- Network Traffic

[TiProxy/TiDB/PD](http://172.21.40.20:3000/d/000000001/tidb-cluster-node_exporter?editPanel=21&orgId=1&from=1765338900000&to=1765343100000&var-interval=1m&var-host=172.21.40.17:9100&var-buddyinfozone=All)
![image](https://hackmd.io/_uploads/Sk_7N98GZg.png)
![image](https://hackmd.io/_uploads/Hy44NcLfbx.png)
![image](https://hackmd.io/_uploads/BkeS4cIfbg.png)
```
172.21.40.17
Inbound current 87.83 / max 372.82 KB（≈0.70 Mbps）
Outbound current 97.40 / max 587.09 KB（≈0.78 Mbps）

172.21.40.18
Inbound current 46.64 / max 233.93 KB（≈0.37 Mbps）
Outbound current 48.87 / max 377.96 KB（≈0.39 Mbps）

172.21.40.19
Inbound current 46.58 / max 213.92 KB（≈0.37 Mbps）
Outbound current 49.23 / max 390.48 KB（≈0.39 Mbps）
```

[TiKV](http://172.21.40.20:3000/d/000000001/tidb-cluster-node_exporter?editPanel=21&orgId=1&from=1765338900000&to=1765343100000&var-interval=1m&var-host=172.21.40.20:9100&var-buddyinfozone=All)
![image](https://hackmd.io/_uploads/H1dMV98Mbl.png)
```
172.21.40.20
Inbound current 119.35 / max 449.06 KB（≈0.93 Mbps）
Outbound current 23.12 / max 242.10 KB（≈0.18 Mbps）
```

- [I/O Activity](http://172.21.40.20:3000/d/000000001/tidb-cluster-node_exporter?orgId=1&from=1765338900000&to=1765343100000&var-interval=1m&var-host=172.21.40.20:9100&var-buddyinfozone=All)

TiProxy/TiDB/PD
![image](https://hackmd.io/_uploads/SkZ64c8Gbg.png)
![image](https://hackmd.io/_uploads/r17CNc8G-x.png)
![image](https://hackmd.io/_uploads/Hk51S5Lzbe.png)
```
172.21.40.17
sdb throughput current 15.03 KB / max 29.33 KB
172.21.40.18
sdb throughput current 13.7 KB / max 28.2 KB
172.21.40.19
sdb throughput current 38.8.00 KB / max 102.7 KB
```

TiKV
![image](https://hackmd.io/_uploads/rkFiE5UG-g.png)
```
172.21.40.20
sdb throughput current 316.00 KB / max 53.83 MB
```

[Connection Count](http://172.21.40.19:2379/dashboard/#/monitoring): 28
![image](https://hackmd.io/_uploads/H1z6D5UGbe.png)

[Database Time by SQL Types](http://172.21.40.19:2379/dashboard/#/monitoring)
![image](https://hackmd.io/_uploads/Bk04w5LM-e.png)

[QPS](http://172.21.40.19:2379/dashboard/#/monitoring): 113 for select.
![image](https://hackmd.io/_uploads/SyTDD9UzZe.png)

[TPS](http://172.21.40.19:2379/dashboard/#/monitoring): 89 for commit.
![image](https://hackmd.io/_uploads/B1xVOqLzWx.png)

[Top Command Counters](http://172.21.40.19:2379/dashboard/#/monitoring): 113 for select.
![image](https://hackmd.io/_uploads/SycKu5LM-g.png)
![image](https://hackmd.io/_uploads/Bk3q_cLzWl.png)


TiProxy CPU Usage: 0.8 ~ 2.5%
![image](https://hackmd.io/_uploads/Hk6bK98fbl.png)

TiDB CPU Usage: 2.7 ~ 3.4%
![image](https://hackmd.io/_uploads/r1GAOcLGWl.png)

TiKV CPU Usage: 2.8 ~ 7.8%
![image](https://hackmd.io/_uploads/BkYyt58zWe.png)

TiKV IO MBps: 3.8 MB Max
![image](https://hackmd.io/_uploads/SJVQF9LGZx.png)

----

### 自製 (Read) 壓力測試條件 

```
wnlin@s-dba-bastion-1:~/lab/104tsd-misc/stress/multi-readwrite-test/scripts$ date ; ACAPI_ID_MIN=15004119 ACAPI_ID_MAX=15004119 ./test.sh --qps 500 --threads 25 --requests 0 --duration 300 ; date
Tue Dec  9 16:20:08 CST 2025
Target: https://acapi.104dc-staging.com/internal/account/{15004119-15004119}
QPS: 500 (interval 0.050000s) with threads: 25
Requests: 0 (0 means infinite)
Duration cap: 300s (0 means no cap)
Running... (Ctrl+C to stop)
./test.sh: line 106: 319714 Terminated              worker "$interval"
----- summary -----
Target: https://acapi.104dc-staging.com/internal/account/{15004119-15004119}
Requests sent: 9494 (limit: 0, 0 means infinite; duration limit: 300s)
Success: 9494 | Fail: 0 | Success rate: 100.00% | Error rate: 0.00%
Latency ms avg: 54.88 | min: 29 | max: 7184 | p95: 54 | p99: 147
Runtime sec: 300
Tue Dec  9 16:25:08 CST 2025
```

#### ProxySQL & MariaDB

- ProxySQL

[Client Questions](https://pmm.104-staging.com.tw/graph/d/fwWR9oiiz/proxysql-overview?refresh=5s&panelId=56&fullscreen&edit&orgId=1&var-interval=$__auto_interval_interval&var-proxysql=s-proxysql2-acapi-1&var-hostgroup=10&var-hostgroup=11&from=1765268100000&to=1765269000000)
![image](https://hackmd.io/_uploads/rJ97CUrGWg.png)

[Network Traffic](https://pmm.104-staging.com.tw/graph/d/qyzrQGHmk/system-overview?refresh=5s&panelId=21&fullscreen&edit&orgId=1&var-interval=$__auto_interval_interval&var-host=s-proxysql2-acapi-1&from=1765268100000&to=1765269000000)
![image](https://hackmd.io/_uploads/BJFiRIrGbe.png)

[CPU Usage](https://pmm.104-staging.com.tw/graph/d/qyzrQGHmk/system-overview?refresh=5s&panelId=2&fullscreen&edit&orgId=1&var-interval=$__auto_interval_interval&var-host=s-proxysql2-acapi-1&from=1765268100000&to=1765269000000)
![image](https://hackmd.io/_uploads/rJk_RUBfWx.png)

[Memory Utilization](https://pmm.104-staging.com.tw/graph/d/qyzrQGHmk/system-overview?refresh=5s&panelId=29&fullscreen&edit&orgId=1&var-interval=$__auto_interval_interval&var-host=s-proxysql2-acapi-1&from=1765268100000&to=1765269000000)
![image](https://hackmd.io/_uploads/BkGF7wUGWl.png)

- MariaDB

[Top Command Counters](https://pmm.104-staging.com.tw/graph/d/MQWgroiiz/mysql-overview?refresh=1m&panelId=14&fullscreen&edit&orgId=1&var-interval=$__auto_interval_interval&var-host=s-m075-1&from=1765268100000&to=1765269000000)
![image](https://hackmd.io/_uploads/S1CcyP8zZe.png)

[CPU Usage / Load](https://pmm.104-staging.com.tw/graph/d/MQWgroiiz/mysql-overview?refresh=1m&panelId=2&fullscreen&edit&orgId=1&var-interval=$__auto_interval_interval&var-host=s-m075-1&from=1765268100000&to=1765269000000)
![image](https://hackmd.io/_uploads/H1LRkw8zWx.png)

[Memory Utilization](https://pmm.104-staging.com.tw/graph/d/qyzrQGHmk/system-overview?refresh=5s&panelId=29&fullscreen&edit&orgId=1&from=1765268100000&to=1765269000000&var-interval=$__auto_interval_interval&var-host=s-m075-1)
![image](https://hackmd.io/_uploads/B1V2XwLfWg.png)

[I/O Activity](https://pmm.104-staging.com.tw/graph/d/MQWgroiiz/mysql-overview?refresh=1m&panelId=31&fullscreen&edit&orgId=1&var-interval=$__auto_interval_interval&var-host=s-m075-1&from=1765268100000&to=1765269000000)
![image](https://hackmd.io/_uploads/rJi-ePIfZl.png)

[InnoDB Row Operations](https://pmm.104-staging.com.tw/graph/d/giGgrTimz/mysql-innodb-metrics?refresh=1m&panelId=23&fullscreen&edit&orgId=1&from=1765268100000&to=1765269000000&var-interval=$__auto_interval_interval&var-host=s-m075-1)
![image](https://hackmd.io/_uploads/rkqKlw8Gbl.png)


[InnoDB Buffer Pool Requests](https://pmm.104-staging.com.tw/graph/d/giGgrTimz/mysql-innodb-metrics?refresh=1m&panelId=41&fullscreen&edit&orgId=1&from=1765268100000&to=1765269000000&var-interval=$__auto_interval_interval&var-host=s-m075-1)
![image](https://hackmd.io/_uploads/S1KAgvUG-x.png)

----

#### TiDB 對照

##### Client Questions & Top Command Counters

- [TiProxy Query Summary](http://172.21.40.20:3000/d/Wqz947zvk/tidb-demo-tiproxy-summary?orgId=1&from=1765268100000&to=1765269000000)
![image](https://hackmd.io/_uploads/SJWaaOIMbl.png)

- [TiDB Query Summary](http://172.21.40.20:3000/d/3Amr4nzDk/tidb-demo-tidb-summary?orgId=1&from=1765268100000&to=1765269000000)
![image](https://hackmd.io/_uploads/HkorhdIMWe.png)

##### [CPU Usage](http://172.21.40.20:3000/d/000000001/tidb-cluster-node_exporter?editPanel=2&orgId=1&from=1765268100000&to=1765269000000&var-interval=1m&var-host=172.21.40.17:9100&var-buddyinfozone=All)

- TiProxy/TiDB/PD
![image](https://hackmd.io/_uploads/rkCyxYLzbl.png)
![image](https://hackmd.io/_uploads/B1TgetIMbg.png)
![image](https://hackmd.io/_uploads/SJoZxY8zWg.png)

- TiKV
![image](https://hackmd.io/_uploads/rJYMlFIMZl.png)

##### [Memory Utilization](http://172.21.40.20:3000/d/000000001/tidb-cluster-node_exporter?editPanel=6&orgId=1&from=1765268100000&to=1765269000000&var-interval=1m&var-host=172.21.40.20:9100&var-buddyinfozone=All)

- TiProxy/TiDB/PD
![image](https://hackmd.io/_uploads/rJSPgYIG-l.png)
![image](https://hackmd.io/_uploads/HyPugYUMZg.png)
![image](https://hackmd.io/_uploads/BkLtgY8Gbl.png)

- TiKV
![image](https://hackmd.io/_uploads/S1qqxF8G-l.png)

##### [I/O Activity](http://172.21.40.20:3000/d/000000001/tidb-cluster-node_exporter?orgId=1&from=1765268100000&to=1765269000000&var-interval=1m&var-host=172.21.40.20:9100&var-buddyinfozone=All)

- TiProxy/TiDB/PD
![image](https://hackmd.io/_uploads/BJk8ftUzWx.png)
![image](https://hackmd.io/_uploads/B1QPMKLM-e.png)
![image](https://hackmd.io/_uploads/r1NuMYUz-x.png)

- TiKV
![image](https://hackmd.io/_uploads/r1S4GK8zWl.png)

##### [Network Traffic](http://172.21.40.20:3000/d/000000001/tidb-cluster-node_exporter?editPanel=21&orgId=1&from=1765268100000&to=1765269000000&var-interval=1m&var-host=172.21.40.20:9100&var-buddyinfozone=All)

- TiProxy/TiDB/PD
![image](https://hackmd.io/_uploads/BkRsbtLGZg.png)
![image](https://hackmd.io/_uploads/ry62WFIfWg.png)
![image](https://hackmd.io/_uploads/BkYpZt8MZg.png)

- TiKV
![image](https://hackmd.io/_uploads/S12qWFUfZx.png)
