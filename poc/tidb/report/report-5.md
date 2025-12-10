# TiDB Intro for DBA #5-5 

[Ver: Hackmd](https://hackmd.io/@skhUTGhBTuKf0SIjiqI3-g/r1Z05J4fWx)

[Ver: Github](https://github.com/heavenruler/dba_career/blob/master/poc/tidb/report/report-5.md)

## Staging AC-API 整合測試紀錄

### 前提:

- Staging AC-API 僅將部分 Mirror 流量導入 TiDB，實際導向的 API Endpoint 篩選清單如下
  - /v1/account/get-multiple
  - /v1/account/vip
  - /v1/account/${idc-update-bd-pid}/birthday
  - /v1/b/ha/set-account

## 流量架構示意圖

![image](https://hackmd.io/_uploads/S1fiHHSf-e.png)

## 相關可觀測 (效能對照) 數據

### Read

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
