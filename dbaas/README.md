# DBaaS Program Proposal

---

## 1. 計畫目標與範圍

### 計畫目標

本計畫擬建立企業級 DBaaS 平台，優先解決下列三項核心議題：

1. **交付效率**
   - 將 DB Provision Lead Time 由 3 days 降至 30 minutes 內
2. **資源與成本治理**
   - 建立規格標準化與 Quota 控制機制
   - 降低 over-provision 與閒置資源
3. **高可用與災難復原標準化**
   - 建立 Active / Passive 與標準 HA / DR 模式
   - 降低各團隊自行維運造成的架構差異

### 服務邊界

DBaaS 提供標準化資料庫申請、建置、備份、監控、擴縮、升級與下線流程，不負責應用程式邏輯、ORM 設計與商業資料模型設計。

平台交付能力如下：

| 能力 | 說明 |
|---|---|
| DB Provision | 透過標準規格與自動化流程建立 DB Instance / Cluster |
| Schema Migration | App Team 透過平台工具執行，DBA 依風險等級協作或審核 |
| SQL Review / Governance | SQL 審核、變更治理與稽核追蹤 |
| DB 帳號管理 | 提供標準角色與帳號生命週期管理 |
| DB 升級治理 | 由 DBA 主責 Engine / Major Version 升級 |
| Observability | 自動掛載監控、告警、審計與基礎報表 |
| Data Migration | 提供 CDC / 批次搬移 / 切換治理流程 |
| Backup 管理 | 統一備份策略、保留政策與還原演練 |
| Replication / DR | 提供標準化資料同步與 DR 架構 |

不在本期範圍：

- 自由選版與高度客製化 DB Engine 參數服務
- 非標準 Engine 的全面納管
- 應用程式端 SQL 效能調校代工
- 所有舊系統一次性遷移至 DBaaS

### DB Account Model

| Role | 權限 |
|---|---|
| App Team | 應用所需 CRUD 與限定物件權限 |
| DBA | 管理、維運、備份、還原、治理相關高權限 |

原則：

- 正式環境不建議長期使用高權限帳號作為應用連線帳號
- 權限採角色化模型管理，避免以 `ALL PRIVILEGES` 作為常態設定

### DB Migration Strategy

主要資料遷移策略如下：

- 線上資料同步：CDC
- 批次資料搬移：AWS Glue
- 線上表結構調整：`pt-online-schema-change`

所有遷移作業需具備：

- Migration Plan
- Cutover Plan
- Rollback Plan
- Data Validation 機制

### 納管對象

本期分階段納管下列資料庫與組件：

- MySQL
- ProxySQL
- Redis
- Redis Sentinel

### 不納管對象

現階段不納入本期範圍：

- PostgreSQL
- MongoDB
- TiDB

### 適用環境

DBaaS 適用以下環境，並依環境提供不同治理強度：

- dev
- staging
- prod
- dr

### 成功定義

本計畫成功定義如下：

- DB Provision 時間 < 30 min
- DB Service Catalog 標準化並可重複交付
- HA / DR 架構具一致治理模型
- DB 資源使用、備份與成本可被量測與治理

---

# 2. 服務目錄與標準規格

## 平台納管原則

DBaaS 僅納管 **Stateful Service**。

Redis Sentinel 與 ProxySQL 作為 **DB HA 架構組件** 使用，不列為獨立 DB 服務型號，也不單獨對外提供為一般應用服務。

---

## DB 類型分類

| DB | Type |
|---|---|
| MySQL | OLTP |
| Redis | Cache |

---

## DB Service Catalog

| Service ID | Architecture | 適用場景 | 限制 |
|---|---|---|---|
| mysql-single | MySQL Standalone | dev、低風險非核心服務 | 不提供 HA 保證，不適用核心 prod |
| mysql-ha1 | MySQL Replication + ProxySQL | 一般 OLTP、標準 prod | 需接受 failover 切換時間 |
| mysql-ha2 | MySQL Galera Cluster + ProxySQL | 高可用寫入需求場景 | 架構複雜度與運維成本較高 |
| redis-single | Redis Standalone | cache、dev、非關鍵場景 | 無 HA，不適用核心 cache |
| redis-ha | Redis + Sentinel | 標準快取高可用場景 | 對網路與 Sentinel 健康度敏感 |

原則：

- 產品團隊優先從標準服務型號中選擇
- 非標準架構需走例外申請流程
- 不同 Service ID 對應不同 SLO 與治理強度

---

## HA 選型

| DB | HA Model |
|---|---|
| MySQL | Replication / Galera |
| Redis | Sentinel |

---

## Scale Strategy

| DB | Scale Model |
|---|---|
| MySQL | Read Replica |
| Redis | Sentinel + Replica |

---

## DB Version Policy

| DB | Version |
|---|---|
| MySQL | 8.4 LTS |
| Redis | 7.1 |

原則：

- DB 版本由平台統一維護，不開放產品端自由選版
- LTS 版本優先，降低升級碎片化風險
- Major Upgrade 需納入年度升級計畫與驗證流程

---

## Spec 標準化

DBaaS 提供標準規格如下：

| Spec | CPU | Memory | 適用場景 |
|---|---|---|---|
| small | 2 | 4Gi | dev、staging、低流量服務 |
| medium | 4 | 8Gi | 一般業務服務 |
| large | 8 | 16Gi | 核心業務或較高併發場景 |

原則：

- 先以標準規格交付，再依監控數據進行升級
- prod 原則上不得低於經評估後的最小安全規格

---

## Storage Policy

DB Storage 原則統一使用 `standard-ssd`，避免因儲存型號過多造成治理成本上升。

補充：

- 關鍵服務可依例外流程申請更高等級 storage class
- Storage 擴容僅允許向上調整，不支援縮容

---

## Backup Policy

| Environment | Backup |
|---|---|
| dev | daily |
| staging | daily |
| prod | daily |
| dr | 依資料同步架構決定 |

補充原則：

- 備份資料統一存放於 S3 Object Storage
- Retention Policy 需依環境與資料等級細分，不建議僅以 `per day` 表示
- 若 DR 環境以 replication 為主，仍需定義是否保留獨立備份

---

## Resource Quota Policy

Quota 依租戶或 namespace 管理，用於控制整體資源消耗。

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

# 3. 申請與生命週期流程

## DB Lifecycle

```text
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

## 端到端流程

```text
產品團隊提出申請
→ CI Workflow 觸發
→ 平台檢查是否符合標準規格與配額
→ 必要時進入例外審批
→ IaC / GitOps / Operator 建置
→ DB 建置完成
→ 自動掛載監控 / 備份 / 告警
→ 回傳 Endpoint / 帳號 / 文件
→ 進入 Day-2 Operation
```

---

## Provision

DB Provision 透過 `CI Workflow` 與 `GitOps` 流程執行。

流程：

```text
提交 DB config
→ CI Workflow
→ Policy / Quota Check
→ IaC Deploy
→ Operator 建置 DB
→ Proxy / Endpoint 建立
→ Monitoring / Backup / Alert 掛載
→ 交付使用資訊
```

交付輸出至少包含：

- DB endpoint
- 帳號資訊或帳號申請方式
- 使用規格與容量資訊
- 備份與監控文件入口

---

## Change

本期支援的變更項目：

- Schema Migration

補充原則：

- 高風險變更需審批與排程
- 所有變更需保留可追溯紀錄

---

## Scale

支援以下擴縮方式：

- CPU / Memory Scale（Spec Upgrade）
- Storage Scale
- Read Replica

原則：

- CPU / Memory 以升級標準規格為主
- Storage 僅支援向上調整
- 讀流量壓力優先評估 Read Replica 或快取分流策略

---

## Backup / Restore

支援項目：

- Daily Backup（physical backup / logical backup）
- 指定時間點前後的 restore 流程

原則：

- 備份可用性需透過還原演練驗證
- Restore 操作需由 DBA / SRE 依權限流程執行

---

## Upgrade

DB 升級策略：

- 由 DBA 主責規劃與執行
- 以藍綠部署或分批升級為優先
- 升級前需備妥 rollback plan
- 正式環境升級需先完成 staging 驗證

---

## Failover

HA 切換模式：

- MySQL Replication Failover
- Redis Sentinel Failover

---

## Decommission

DB 下線流程：

```text
停止應用
→ 備份
→ 確認保留期限與責任人
→ DB 下線
→ 保留資料
→ 清理資源
```

原則：

- 下線前需確認是否仍有應用連線
- 下線後需保留 audit record 與資料保留期限

---

## Single → HA Migration

### MySQL

```text
mysql-single
→ 建立 HA cluster
→ 資料同步
→ ProxySQL 切流
→ 驗證
→ 舊 single 下線
```

### Redis

```text
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
| P0 | prod 全站或核心交易中斷 | SRE 立即接手，DBA / Platform 15 分鐘內加入 |
| P1 | 單一服務降級、效能明顯異常 | SRE 主導，DBA 30 分鐘內支援 |
| P2 | 非 prod 異常或可排程處理問題 | 依工單流程排入處理 |
| P3 | 文件、報表、低風險設定調整 | 納入例行維護 |

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
- 所有 P0 / P1 事件需產出 postmortem
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
- Replica 擴充前需先確認網路與儲存資源

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

---

# 9. Lab 實作現況

## 目前完成項目

目前 Lab 環境已完成第一階段 MVP 驗證，重點如下：

- Kubernetes lab cluster 已完成基線建置
- `local-path` 已作為預設 `StorageClass`
- `Argo CD` 已可自 GitHub 同步 GitOps 設定
- `Percona XtraDB Cluster Operator` 已可於 cluster 內運作
- `mysql-single` 已成功建立並完成 SQL 驗證
- `TiDB Operator` 已納入 GitOps 佈署骨架
- `OT-CONTAINER-KIT Redis Operator` 已成功建立 `redis-single`

## 已完成元件

| 項目 | 狀態 | 說明 |
|---|---|---|
| StorageClass | done | 使用 `local-path` 對應各 node `/data` |
| GitOps | done | 使用 `Argo CD + GitHub` |
| MySQL Operator | done | 使用 `Percona XtraDB Cluster Operator` |
| mysql-single | done | 單節點 PXC + HAProxy |
| SQL 驗證 | done | 已完成建庫、建表、寫入與查詢 |
| TiDB Operator | done | 已加入 `PingCAP tidb-operator` GitOps 定義 |
| Redis Operator | done | 使用 `OT-CONTAINER-KIT redis-operator` |
| redis-single | done | Standalone Redis + exporter + NodePort |
| MySQL Metrics Exporter | done | `mysqld-exporter` 已提供 metrics 給 VictoriaMetrics |
| VictoriaMetrics Query | done | `mysql_up=1` 查詢已成功 |

## 目前部署元件

| 類型 | 名稱 | Namespace |
|---|---|---|
| Argo CD App | `dbaas-root` | `argocd` |
| Argo CD App | `percona-operator` | `argocd` |
| Argo CD App | `mysql-single` | `argocd` |
| Argo CD App | `tidb-operator` | `argocd` |
| Argo CD App | `redis-operator` | `argocd` |
| Argo CD App | `redis-single` | `argocd` |
| DB Cluster | `minimal-cluster` | `mysql-single` |
| Redis | `redis-single` | `redis-single` |
| Exporter | `mysqld-exporter` | `mysql-single` |

## MySQL 存取方式

叢集內服務：

- Host: `minimal-cluster-haproxy.mysql-single`
- Port: `3306`

Lab 對外服務：

- Host: `172.24.40.17`
- Port: `30306`
- Service: `minimal-cluster-haproxy-nodeport`

查 root 密碼：

```bash
kubectl get secret -n mysql-single minimal-cluster-secrets -o jsonpath='{.data.root}' | base64 -d; echo
```

叢集內連線測試：

```bash
kubectl run -n mysql-single mysql-client --rm -it --image=mysql:8.0 --restart=Never -- \
  mysql -h minimal-cluster-haproxy -uroot -p$(kubectl get secret -n mysql-single minimal-cluster-secrets -o jsonpath='{.data.root}' | base64 -d)
```

叢集外連線測試：

```bash
mysql -h 172.24.40.17 -P 30306 -uroot -p
```

## 監控驗證

已完成以下監控驗證：

- `mysqld-exporter` 已部署於 `mysql-single`
- `VictoriaMetrics` 已成功抓取 `mysql_up=1`
- 為避免重複時間序列，目前保留 `service-endpoints` 單一路徑抓取 exporter
- `redis-single` 已透過 `redis-exporter` 暴露 `9121` metrics

Redis metrics 查詢範例：

```bash
curl -s "http://172.24.40.17:30428/api/v1/query?query=redis_up" | python3 -m json.tool
```

查詢範例：

```bash
curl -s "http://172.24.40.17:30428/api/v1/query?query=mysql_up" | python3 -m json.tool
```

## Redis 存取方式

叢集內服務：

- Host: `redis-single.redis-single`
- Port: `6379`

Lab 對外服務：

- Host: `172.24.40.17`
- Port: `30379`
- Service: `redis-single-external-service`

叢集內測試：

```bash
kubectl run -n redis-single redis-client --rm -it --image=redis:7.0 --restart=Never -- redis-cli -h redis-single -p 6379 ping
```

叢集外測試：

```bash
redis-cli -h 172.24.40.17 -p 30379 ping
```

Redis exporter metrics：

- Service: `redis-single:9121`
- 指標查詢：`redis_up`

## Lab 限制

- Storage 使用 `local-path`，僅適合 lab / POC
- `percona-operator` 目前以較寬鬆 RBAC 運作，不適合直接進正式環境
- `mysql-single` 密碼目前存放於 GitOps secret manifest，後續需改為安全憑證管理機制

## 下一步

1. 補 `redis-sentinel / redis-ha` 驗證流程
2. 補 `backup / restore` 驗證流程
3. 收斂正式環境 RBAC、Secret 管理與對外入口策略
