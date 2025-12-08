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

## Staging 壓測時間點

- [AC 基礎量 壓力測試 @ 2025-12-05 (五) 11:30 ~ 2025-12-05 (五) 18:00](https://teams.microsoft.com/l/message/19:c44e126d5a4e4f42a1fdc5f0c71c942c@thread.skype/1764905115320?tenantId=e5b7696b-abd7-48ed-9482-723ead81e6fd&groupId=442a8629-6c1b-435f-9c92-268280d1f25f&parentMessageId=1764905115320&teamName=announcement&channelName=%E9%9D%9E%E7%B7%9A%E4%B8%8A%E4%BD%9C%E6%A5%AD%E5%85%AC%E5%91%8A&createdTime=1764905115320)

- [AC 基礎量 壓力測試 @ 2025-12-05 (五) 18:00 ~ 2025-12-05 (五) 20:30](https://teams.microsoft.com/l/message/19:c44e126d5a4e4f42a1fdc5f0c71c942c@thread.skype/1764927638765?tenantId=e5b7696b-abd7-48ed-9482-723ead81e6fd&groupId=442a8629-6c1b-435f-9c92-268280d1f25f&parentMessageId=1764927638765&teamName=announcement&channelName=%E9%9D%9E%E7%B7%9A%E4%B8%8A%E4%BD%9C%E6%A5%AD%E5%85%AC%E5%91%8A&createdTime=1764927638765)

- {Sample from here} [AC 基礎量 壓力測試 @ 2025-12-08 (一) 12:00 ~ 2025-12-08 (一) 13:00](https://teams.microsoft.com/l/message/19:c44e126d5a4e4f42a1fdc5f0c71c942c@thread.skype/1765166484458?tenantId=e5b7696b-abd7-48ed-9482-723ead81e6fd&groupId=442a8629-6c1b-435f-9c92-268280d1f25f&parentMessageId=1765166484458&teamName=announcement&channelName=%E9%9D%9E%E7%B7%9A%E4%B8%8A%E4%BD%9C%E6%A5%AD%E5%85%AC%E5%91%8A&createdTime=1765166484458)

- [AC 基礎量 壓力測試 @ 2025-12-08 (一) 18:00 ~ 2025-12-08 (一) 19:00](https://teams.microsoft.com/l/message/19:c44e126d5a4e4f42a1fdc5f0c71c942c@thread.skype/1765171405602?tenantId=e5b7696b-abd7-48ed-9482-723ead81e6fd&groupId=442a8629-6c1b-435f-9c92-268280d1f25f&parentMessageId=1765171405602&teamName=announcement&channelName=%E9%9D%9E%E7%B7%9A%E4%B8%8A%E4%BD%9C%E6%A5%AD%E5%85%AC%E5%91%8A&createdTime=1765171405602)

## 相關可觀測 (效能對照) 數據

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










## 有沒有需要自製壓力測試環境條件？