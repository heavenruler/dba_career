# DBaaS Program

---

## 1. 目標與範圍

### 建置目標

DBaaS 平台主要解決三個核心問題：

1. **部署速度**
   - DB Provision：3 days → 30 minutes
2. **成本治理**
   - DB 規格標準化
   - 避免過度配置
3. **多機房策略**
   - Active / Passive 架構
   - 標準化 HA / DR 模式

### 服務邊界

DBaaS 提供資料庫基礎平台能力，並整合資料治理工具。 {待調整, 太高大上了}

平台能力包含：

| 能力 | 說明 |
|---|---|
| Schema Migration | RD 透過平台工具執行（EX: Bytebase），DBA 協作 |
| SQL Review / Governance | SQL 審核與治理 |
| DB 帳號管理 | RD 使用 CRUD 帳號，DBA 保留 ALL 權限 |
| Data Migration | DBA 執行（CDC / AWS Glue） |
| Backup 管理 | 統一備份策略與保留政策 |
| Replication / DR | 跨機房資料同步 |
| DB 升級治理 | DBA 負責 Engine / Major Version 升級 |

### DB Account Model

| Role | 權限 |
|---|---|
| RD | CRUD |
| DBA | ALL PRIVILEGES |

### DB Migration Strategy

主要資料遷移方式：

- CDC
- AWS Glue
- pt-online-schema-change（pt-osc）

### 納管對象

分階段 DBaaS 納管資料庫：

- MySQL
- ProxySQL
- Redis
- Redis Sentinel
- TiDB

### 不納管對象

現階段不納管：

- PostgreSQL
- MongoDB

### 適用環境

DBaaS 適用以下環境：

- dev
- staging
- prod
- dr

### 成功定義

DBaaS 成功指標：

- DB Provision 時間 < 30 min
- DB 架構標準化
- HA 架構統一
- DB 資源成本可治理

---

# 2. Service Catalog

## Stateful / Stateless

DBaaS 僅納管 **Stateful Service**。

ProxySQL 作為 **DB HA 架構組件**。

---

## DB 類型分類

| DB | Type |
|---|---|
| MySQL | OLTP |
| Redis | Cache |
| Redis Sentinel | HA Control |
| TiDB | Distributed SQL |
| ProxySQL | Proxy |

---

## DB Service Catalog

| Service ID | Architecture |
|---|---|
| mysql-single | MySQL Standalone |
| mysql-ha1 | MySQL Replication + ProxySQL |
| mysql-ha2 | MySQL Galera Cluster + ProxySQL |
| redis-single | Redis Standalone |
| redis-ha | Redis + Sentinel |
| tidb-cluster | TiDB |

---

## HA 選型

| DB | HA Model |
|---|---|
| MySQL | Replication / Galera |
| Redis | Sentinel |
| TiDB | Native HA |
| ProxySQL | Cluster |

---

## Scale Strategy

| DB | Scale Model |
|---|---|
| MySQL | Read Replica |
| Redis | Sentinel + Replica |
| TiDB | Scale-out |

---

## DB Version Policy

| DB | Version |
|---|---|
| MySQL | 8.4 LTS |
| Redis | 7.1 |
| TiDB | 8.5 LTS |

DB 版本 **不可由產品端自行選擇**。

---

## Spec 標準化

DBaaS 提供標準規格：

| Spec | CPU | Memory |
|---|---|---|
| small | 2 | 4G |
| medium | 4 | 8G |
| large | 8 | 16G |

---

## Storage Policy

DB Storage 統一使用：standard-ssd

---

## Backup Policy

| Environment | Backup |
|---|---|
| dev | daily |
| staging | daily |
| prod | daily |
| dr | none |

Retention Policy：per day
Backup Storage：S3 Object Storage

---

## Resource Quota Policy

Quota 依 Spec 等級對應。

Example：

- cpu: 64
- memory: 256Gi
- storage: 10Ti

Quota 作用：

- 控制 tenant / namespace 總資源使用量
- 防止資源過度消耗

Spec 與 Quota 關係：

| 類型 | 說明 |
|---|---|
| Spec | 單一 DB 服務規格 |
| Quota | Tenant 總資源限制 |

---

# 3. DBaaS Workflow

## DB Lifecycle

```
Request
→ Provision
→ Operate (Day-2 Operation)
→ Change
→ Scale
→ Backup / Restore
→ Upgrade
→ Failover
→ Decommission
```

---

## 端到端 DBaaS 流程

```
產品團隊提出申請
→ Git Action 觸發 workflow
→ 平台檢查是否符合標準規格
→ IaC / GitOps / Operator 建置
→ DB 建置完成
→ 自動掛載監控 / 備份 / 告警
→ 回傳 Endpoint / 帳號 / 文件
→ 進入 Day-2 Operation
```

---

## Provision

透過 **Git Action** 建立 DB。

流程：

```
提交 DB config
→ Git Action
→ IaC Deploy
→ Operator 建置 DB
→ Proxy / Endpoint 建立
```

---

## Change

可變更內容 {for now}：

- Schema Migration

---

## Scale

支援：

- CPU / Memory Scale # Spec Upgrade
- Storage Scale
- Read Replica

---

## Backup / Restore

支援：

- Daily Backup (phy & login backup)

---

## Upgrade

DB 升級方式：

- DBA 手動操作
- 藍綠部署
- RollBack Plan

---

## Failover

HA 切換：

- MySQL Replication Failover
- Redis Sentinel Failover
- TiDB Native Failover

---

## Decommission

DB 下線流程：

```
停止應用
→ 備份
→ DB 下線
→ 保留資料
→ 清理資源
```

---

## Single → HA Migration

### MySQL

```
mysql-single
→ 建立 HA cluster
→ 資料同步
→ ProxySQL 切流
→ 驗證
→ 舊 single 下線
```

### Redis

```
redis-single
→ 建立 Redis + Sentinel
→ 資料同步
→ Endpoint 切換
→ 驗證
→ 舊 single 下線
```

========================================================================

## 維運 R&R
### DBA / SRE / Platform / App Team 分工
### On-call / Incident / Escalation
### Day-2 Operation
### 容量管理
### 例外申請流程

## 效能與風險
### 效能損耗測試
### 已知問題
### 風險矩陣
### CoreDNS 問題
### 網路 / Storage / 資源爭用問題

## 可觀測性與治理
### 監控
### Logging / Metrics / Tracing
### OTel 佈點策略
### Alert / Event / Audit
### 報表與成本看板

## 生態工具整合
### Archery
### Bytebase
### SQLe
### DB Doctor
### NineData

## KPI / SLO / 成本模型
### KPI 量化規劃
### SLO / SLA 定義
### 成本計價模型
### 預算評估方式
