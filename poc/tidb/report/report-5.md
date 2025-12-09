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

- MariaDB




#### TiDB Cluster



### Write














=================================================================================================================================================
=================================================================================================================================================
=================================================================================================================================================
=================================================================================================================================================

## Staging 壓測時間點

- [AC 基礎量 壓力測試 @ 2025-12-05 (五) 11:30 ~ 2025-12-05 (五) 18:00](https://teams.microsoft.com/l/message/19:c44e126d5a4e4f42a1fdc5f0c71c942c@thread.skype/1764905115320?tenantId=e5b7696b-abd7-48ed-9482-723ead81e6fd&groupId=442a8629-6c1b-435f-9c92-268280d1f25f&parentMessageId=1764905115320&teamName=announcement&channelName=%E9%9D%9E%E7%B7%9A%E4%B8%8A%E4%BD%9C%E6%A5%AD%E5%85%AC%E5%91%8A&createdTime=1764905115320)

- [AC 基礎量 壓力測試 @ 2025-12-05 (五) 18:00 ~ 2025-12-05 (五) 20:30](https://teams.microsoft.com/l/message/19:c44e126d5a4e4f42a1fdc5f0c71c942c@thread.skype/1764927638765?tenantId=e5b7696b-abd7-48ed-9482-723ead81e6fd&groupId=442a8629-6c1b-435f-9c92-268280d1f25f&parentMessageId=1764927638765&teamName=announcement&channelName=%E9%9D%9E%E7%B7%9A%E4%B8%8A%E4%BD%9C%E6%A5%AD%E5%85%AC%E5%91%8A&createdTime=1764927638765)

- {Sample from here} [AC 基礎量 壓力測試 @ 2025-12-08 (一) 12:00 ~ 2025-12-08 (一) 13:00](https://teams.microsoft.com/l/message/19:c44e126d5a4e4f42a1fdc5f0c71c942c@thread.skype/1765166484458?tenantId=e5b7696b-abd7-48ed-9482-723ead81e6fd&groupId=442a8629-6c1b-435f-9c92-268280d1f25f&parentMessageId=1765166484458&teamName=announcement&channelName=%E9%9D%9E%E7%B7%9A%E4%B8%8A%E4%BD%9C%E6%A5%AD%E5%85%AC%E5%91%8A&createdTime=1765166484458)

- [AC 基礎量 壓力測試 @ 2025-12-08 (一) 18:00 ~ 2025-12-08 (一) 19:00](https://teams.microsoft.com/l/message/19:c44e126d5a4e4f42a1fdc5f0c71c942c@thread.skype/1765171405602?tenantId=e5b7696b-abd7-48ed-9482-723ead81e6fd&groupId=442a8629-6c1b-435f-9c92-268280d1f25f&parentMessageId=1765171405602&teamName=announcement&channelName=%E9%9D%9E%E7%B7%9A%E4%B8%8A%E4%BD%9C%E6%A5%AD%E5%85%AC%E5%91%8A&createdTime=1765171405602)

### ProxySQL with MariaDB

#### ProxySQL

![image](https://hackmd.io/_uploads/rJKAMlEM-x.png)

Client Connections
![image](https://hackmd.io/_uploads/Sk6FoJVz-e.png)

Active Backend Connections
![image](https://hackmd.io/_uploads/By7PjJVG-l.png)

Network Traffic
![image](https://hackmd.io/_uploads/SJjNskVfZe.png)

Latency
![image](https://hackmd.io/_uploads/Sk-Mhy4MZe.png)

CPU Usage
![image](https://hackmd.io/_uploads/S1DIAkEfbe.png)


#### MariaDB

![image](https://hackmd.io/_uploads/rJ-gQl4f-x.png)

Select Types
![image](https://hackmd.io/_uploads/BycYhkEfZl.png)

Network Traffic
![image](https://hackmd.io/_uploads/B1Qh31EfWx.png)

Top Command Counters
![image](https://hackmd.io/_uploads/H1hZaJEzbe.png)

Transaction Handlers
![image](https://hackmd.io/_uploads/BJWJA1Nfbl.png)

CPU Usage / Load
![image](https://hackmd.io/_uploads/SJ3kleEGZl.png)

I/O Activity
![image](https://hackmd.io/_uploads/BkDzleEfbe.png)

InnoDB Row Operations
![image](https://hackmd.io/_uploads/SJGPxlNMZl.png)

InnoDB Row Lock Time
![image](https://hackmd.io/_uploads/HkLagxVMWl.png)

InnoDB Buffer Pool I/O & Requests
![image](https://hackmd.io/_uploads/B1BGWe4MWl.png)

----

### TiDB

![image](https://hackmd.io/_uploads/r1QcMg4zWx.png)

![image](https://hackmd.io/_uploads/SJx987gVz-l.png)

![image](https://hackmd.io/_uploads/r10vQlEMWg.png)

- [SQL 語句分析](http://172.21.40.19:2379/dashboard/#/statement?from=1765165500&to=1765170900)

![image](https://hackmd.io/_uploads/BkCIzlEMZg.png)

- No Slow Queries.
![image](https://hackmd.io/_uploads/BJRZrgVGbg.png)

- [監控指標](http://172.21.40.19:2379/dashboard/#/monitoring?from=1765165500&to=1765170900)

Connections
![image](https://hackmd.io/_uploads/ryGOveEGWe.png)

TPS
![image](https://hackmd.io/_uploads/rk6T_gNG-e.png)

QPS
![image](https://hackmd.io/_uploads/S1f6weEMWe.png)

TiProxy CPU Usage
![image](https://hackmd.io/_uploads/HkUvtgVMZe.png)

TiDB CPU Usage
![image](https://hackmd.io/_uploads/SyjHYeVzZx.png)

TiKV CPU Usage
![image](https://hackmd.io/_uploads/SkDMYlVM-x.png)

TiKV IO MBps
![image](https://hackmd.io/_uploads/H19Ftl4fZl.png)

