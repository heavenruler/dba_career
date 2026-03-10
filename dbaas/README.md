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

---

# 4. 維運 R&R

## 角色分工

預設採用 **Platform-first** 模式：平台提供標準化能力，DBA 負責治理與高風險變更，App Team 以自助方式使用服務。

| Role | 主要責任 |
|---|---|
| Platform Team | 維護 IaC / GitOps / Operator / Service Catalog / Provision Workflow |
| DBA Team | DB 標準制定、SQL Review、權限治理、升級策略、資料遷移、重大變更審核 |
| SRE Team | 監控、告警、值班、事件處理、容量與可用性治理 |
| App Team | 提出申請、使用標準規格、Schema 變更申請、功能驗證、配合切換 |

## 責任邊界

| 項目 | Platform | DBA | SRE | App Team |
|---|---|---|---|---|
| DB Provision | R | C | I | A |
| Schema Migration | I | C / Approve | I | R |
| Engine Upgrade | C | R / A | I | I |
| Backup Policy | C | A | R | I |
| Restore 操作 | I | A | R | C |
| Failover 處理 | C | A | R | I |
| 監控與告警 | C | C | R / A | I |
| 容量規劃 | C | C | R / A | I |
| 例外申請審核 | C | A | C | R |

註：

- R = Responsible
- A = Accountable
- C = Consulted
- I = Informed

## On-call / Incident / Escalation

事件分級：

| Severity | 說明 | 處理方式 |
|---|---|---|
| Sev-1 | prod 全站或核心交易中斷 | SRE 立即接手，DBA / Platform 15 分鐘內加入 |
| Sev-2 | 單一服務降級、效能明顯異常 | SRE 主導，DBA 30 分鐘內支援 |
| Sev-3 | 非 prod 異常或可排程處理問題 | 依工單流程排入處理 |
| Sev-4 | 文件、報表、低風險設定調整 | 納入例行維護 |

升級路徑：

```text
App Team / Monitoring Trigger
→ SRE On-call
→ DBA On-call
→ Platform On-call
→ Incident Commander / Manager
```

處理原則：

- 以服務恢復優先，再進行根因分析
- 所有 Sev-1 / Sev-2 事件需產出 postmortem
- 若涉及資料一致性，需由 DBA 確認後才可恢復寫入

## Day-2 Operation

Day-2 維運項目：

- 使用者與權限調整
- Schema 變更治理
- 例行備份驗證與還原演練
- 監控閾值調整
- Capacity Review
- DB 版本與參數基線維護
- HA / DR 切換演練

標準作業頻率：

| 項目 | 頻率 |
|---|---|
| 備份成功率檢查 | daily |
| 慢查詢 / Top SQL Review | weekly |
| 容量檢查 | weekly |
| 權限盤點 | monthly |
| 還原演練 | quarterly |
| DR 演練 | semi-annually |
| 版本盤點與升級計畫 | quarterly |

## 容量管理

容量治理原則：

- 以 `Spec` 為申請單位，避免自由配置
- 以 `Quota` 控制 tenant / namespace 總量
- prod 需保留至少 20% CPU / Memory 緩衝
- storage 使用率達 70% 需預警，80% 需提出擴容計畫
- Replica / TiDB Scale-out 需先確認網路與儲存資源

容量檢視頻率：

- prod：weekly review
- non-prod：bi-weekly review

## 例外申請流程

下列情境需走例外審批：

- 非標準版本
- 非標準規格
- 高風險變更時段執行
- 跨區資料搬移
- 特殊權限申請

例外流程：

```text
提出申請
→ 補充業務理由與風險
→ DBA / SRE / Platform Review
→ 核准後排程執行
→ 執行結果留存 Audit Record
```

---

# 5. 效能與風險

## 效能損耗測試

DBaaS 上線前需驗證平台附加元件的效能影響，至少包含：

- ProxySQL 對連線延遲影響
- Backup Agent 對 IO 的影響
- Monitoring Exporter 對 CPU / Memory 的影響
- Sidecar / Agent 對 Pod 啟動時間的影響

建議驗證指標：

| 項目 | 目標 |
|---|---|
| 平均延遲增加 | < 5 ms |
| TPS 降幅 | < 10% |
| CPU 額外消耗 | < 10% |
| 備份期間 IO Latency 增幅 | < 20% |

## 已知問題

現階段已知限制：

- MySQL 強一致 HA 切換仍可能造成短暫寫入中斷
- Redis Sentinel 對網路抖動較敏感
- TiDB 對節點資源與網路品質要求較高
- 大型資料庫還原時間受資料量與 S3 頻寬影響
- 非標準 SQL 或外掛功能不保證可攜入平台

## 風險矩陣

| 風險 | 影響 | 可能性 | 緩解措施 |
|---|---|---|---|
| 規格低估導致效能不足 | 高 | 中 | 上線前壓測、保留擴容流程 |
| 備份可用但無法還原 | 高 | 低 | 定期 restore drill |
| Failover 成功但應用未自動重連 | 高 | 中 | App 端納入 reconnect 驗證 |
| Operator / GitOps 故障導致建置失敗 | 中 | 中 | 保留人工接管 Runbook |
| DNS / 網路異常造成 endpoint 不可用 | 高 | 中 | 降低 DNS TTL、建立多層監控 |

## CoreDNS 問題

若 DB Endpoint 透過 K8s Service 暴露，需特別關注：

- CoreDNS 查詢延遲
- DNS Cache 不一致
- Failover 後舊 IP 快取未過期

治理方式：

- 關鍵 DB Endpoint TTL 控制在低值
- App 端需支援 reconnect 與 DNS re-resolve
- 對 CoreDNS QPS / latency 設監控與告警

## 網路 / Storage / 資源爭用問題

平台需預防下列基礎風險：

- 網路抖動導致 replication lag 升高
- 儲存延遲造成交易尖峰時 TPS 下滑
- 同節點部署過多 Stateful Pod 造成 noisy neighbor
- 備份與業務尖峰重疊造成 IO 爭用

建議控制：

- Stateful workload 使用 anti-affinity
- 關鍵 DB 使用專用 storage class
- 備份排程避開業務尖峰
- 對 replication lag、disk latency、node pressure 設門檻

---

# 6. 可觀測性與治理

## 監控

平台需提供統一監控基線：

| 類型 | 指標 |
|---|---|
| Availability | Instance up/down、endpoint health |
| Performance | QPS、TPS、latency、slow query |
| Capacity | CPU、memory、disk usage、connection |
| Replication | replication lag、binlog apply status |
| Backup | backup success rate、duration、last success time |
| HA | failover count、role change event |

## Logging / Metrics / Tracing

治理原則：

- Metrics 為主要告警依據
- Logs 用於事件追查與稽核
- Tracing 聚焦在 App → DB 的請求路徑，不直接要求 DB Engine 原生支援

日誌類型：

- DB Error Log
- Slow Query Log
- Audit Log
- Operator / Platform Workflow Log

## OTel 佈點策略

OTel 佈點以應用側為主：

- App 端 trace 需標記 DB type、endpoint、database name
- 關鍵交易需量測 App latency 與 DB latency
- 不在 DB Pod 內大量植入 tracing agent，避免干擾效能
- OTel 資料保留時間依環境區分，prod 保留較長週期

## Alert / Event / Audit

最低告警集合：

- DB instance unavailable
- replication lag threshold exceeded
- disk usage > 80%
- backup failed
- failover triggered
- connection saturation

Audit 需留存：

- Provision / Decommission 紀錄
- 權限變更
- Schema 變更審批與執行紀錄
- 例外申請與核准紀錄
- Restore / Failover / Upgrade 執行紀錄

## 報表與成本看板

平台需提供至少以下報表：

- 各 tenant DB 數量與規格分布
- CPU / Memory / Storage 使用率
- 備份成功率
- 事件數量與 MTTR
- 各環境成本與月增率

---

# 7. 生態工具整合

工具整合原則：

- 優先整合標準 API / CLI，可自動化與可審計
- 同類型工具只保留一套主方案，避免治理分裂
- 工具導入需有替代方案，避免被單一產品綁定

## SQL Review / Change Management

| 項目 | 暫定方案 | 用途 |
|---|---|---|
| Bytebase | Primary | Schema Migration、變更審批、DB 變更紀錄 |
| Archery / SQLe | Optional | SQL 審核、SQL Risk Check、查詢治理 |

原則：

- 正式環境 Schema 變更需有工單與審批紀錄
- 變更工具需能對接 Git / CI Workflow

## 健康檢查與診斷

| 項目 | 暫定方案 | 用途 |
|---|---|---|
| DB Doctor | Optional | DB 健檢與參數建議 |
| 自建檢查腳本 | Required | 基線檢查、版本盤點、例行巡檢 |

## Data Migration / Sync

| 項目 | 暫定方案 | 用途 |
|---|---|---|
| NineData | Optional | 資料搬移、同步、校驗 |
| CDC / AWS Glue | Primary | 異質或大量資料遷移 |

原則：

- 所有資料遷移需先定義 cutover plan 與 rollback plan
- 遷移完成需執行資料校驗

---

# 8. KPI / SLO / 成本模型

## KPI 量化規劃

第一階段 KPI：

| KPI | 目標 |
|---|---|
| Provision Lead Time | < 30 min |
| 平台納管率 | > 70% 目標 DB |
| 備份成功率 | > 99% |
| Restore 演練成功率 | 100% |
| 標準規格使用率 | > 90% |
| P1 / P2 事件 MTTR | 持續下降 |

## SLO / SLA 定義

建議先定義 SLO，SLA 待平台穩定後再對外承諾。

| 環境 | 可用性 SLO | RPO | RTO |
|---|---|---|---|
| dev | best effort | 24h | 1 business day |
| staging | 99.5% | 24h | 8h |
| prod | 99.9% | 15 min ~ 1h | 1h ~ 4h |
| dr | 依 DR 架構定義 | 與 prod 對齊或略放寬 | 依演練結果定義 |

說明：

- 實際 RPO / RTO 需依 DB 類型與 HA / DR 架構細分
- `mysql-single` 不應承諾與 `mysql-ha1` 相同 SLO

## 成本計價模型

建議採用 **Showback first, Chargeback later**：

- Phase 1：先提供成本透明化報表
- Phase 2：再導入部門或租戶分攤

成本項目：

- Compute
- Memory
- Storage
- Backup Storage
- Network Traffic
- 授權 / 工具成本
- 維運人力估算

計價維度：

| 維度 | 說明 |
|---|---|
| Spec | 基本資源費 |
| Storage | 依實際使用量計價 |
| Backup | 依備份容量與保留天數 |
| HA / DR | 額外副本與跨區成本 |
| Premium Support | 例外需求與高優先支持 |

## 預算評估方式

年度預算估算方式：

```text
預估 DB 數量
× 各 Spec 單價
× 環境數量
+ Backup / DR 成本
+ 工具授權成本
+ 平台維運人力成本
```

評估原則：

- 以 prod / non-prod 分開估算
- 新增 HA / DR 時需同步更新 TCO
- 每季檢查閒置資源與 over-provision 狀況
