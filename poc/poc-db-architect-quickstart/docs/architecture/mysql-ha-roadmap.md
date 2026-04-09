# MySQL HA Roadmap

目前已確認後續要納入以下 MySQL HA scenario：

- `mysql-replication`
- `mysql-group-replication`
- `mysql-innodb-cluster`
- `mysql-proxysql`

## 版本建議

- `5.7`: 僅建議用於 legacy / upgrade / compatibility PoC
- `8.0`: 主流相容性版本
- `8.4`: LTS，建議當主要 PoC 基準
- `9.6`: innovation 線，可做新功能驗證

## 落地順序建議

1. `mysql-replication`
2. `mysql-proxysql`
3. `mysql-group-replication`
4. `mysql-innodb-cluster`

## 設計備註

- `mysql-replication` 是後續所有 HA 驗證的基礎場景
- `mysql-proxysql` 可建立讀寫分離、故障切換、路由規則驗證能力
- `mysql-group-replication` 可用來驗證單主或多主群組複寫行為
- `mysql-innodb-cluster` 需一併考慮 `mysqlsh` 與 `mysql-router`
- `MYSQL_VERSION` 不一定能直接套用到所有周邊元件，部分 scenario 需要額外版本變數
