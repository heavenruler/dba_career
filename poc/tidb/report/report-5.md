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

ProxySQL Client Connections
![image](https://hackmd.io/_uploads/Sk6FoJVz-e.png)

ProxySQL Active Backend Connections
![image](https://hackmd.io/_uploads/By7PjJVG-l.png)

ProxySQL Network Traffic
![image](https://hackmd.io/_uploads/SJjNskVfZe.png)











### TiDB

- [SQL 語句分析](http://172.21.40.19:2379/dashboard/#/statement?from=1765165500&to=1765170900)

![](https://codimd.104.com.tw/image/s3/key/pss9tiruoz8h00inuygd1zid1.png)














## 有沒有需要自製壓力測試環境條件？