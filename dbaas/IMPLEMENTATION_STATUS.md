# DBaaS Implementation Status

## 目前狀態

- Kubernetes lab cluster 已完成基線建置
- `local-path` 已作為預設 `StorageClass`
- `Argo CD` 已可從 GitHub 同步 GitOps 設定
- `Percona Operator` 已可在 cluster 內運作
- `mysql-single` 已成功建立並完成 SQL 驗證
- `TiDB Operator` 已可於 cluster 內運作
- `tidb-cluster` 已成功建立並完成 SQL 驗證
- `tidb-monitor` 已納入最小 POC 佈署骨架
- `OT-CONTAINER-KIT Redis Operator` 已成功建立 `redis-single`

## 已完成項目

| 項目 | 狀態 | 說明 |
|---|---|---|
| StorageClass | done | 使用 `local-path` 對應各 node `/data` |
| GitOps | done | 使用 `Argo CD + GitHub` |
| MySQL Operator | done | 使用 `Percona XtraDB Cluster Operator` |
| mysql-single | done | 單節點 PXC + HAProxy |
| SQL 驗證 | done | 已完成建庫、建表、寫入與查詢 |
| TiDB Operator | done | 使用 `PingCAP tidb-operator` |
| tidb-cluster | done | 最小 TiDB Cluster POC 已成功建立 |
| TiDB SQL 驗證 | done | `select version(); show databases;` 已成功 |
| tidb-monitor | done | 已加入最小 TiDB Monitor GitOps 定義 |
| Redis Operator | done | 使用 `OT-CONTAINER-KIT redis-operator` |
| redis-single | done | Standalone Redis + exporter + NodePort |
| MySQL Metrics Exporter | done | `mysqld-exporter` 已提供 metrics 給 VictoriaMetrics |
| VictoriaMetrics Query | done | `mysql_up=1` 查詢已成功 |
| Redis Metrics Exporter | done | `redis-exporter` 已提供 metrics 給 VictoriaMetrics |
| metrics-server | done | `kubectl top nodes/pods` 已可用 |

## 目前部署元件

| 類型 | 名稱 | Namespace |
|---|---|---|
| Argo CD App | `dbaas-root` | `argocd` |
| Argo CD App | `percona-operator` | `argocd` |
| Argo CD App | `mysql-single` | `argocd` |
| Argo CD App | `tidb-operator` | `argocd` |
| Argo CD App | `tidb-cluster` | `argocd` |
| Argo CD App | `tidb-monitor` | `argocd` |
| Argo CD App | `redis-operator` | `argocd` |
| Argo CD App | `redis-single` | `argocd` |
| DB Cluster | `minimal-cluster` | `mysql-single` |
| DB Cluster | `basic` | `tidb-cluster` |
| Redis | `redis-single` | `redis-single` |
| Exporter | `mysqld-exporter` | `mysql-single` |
| Exporter | `redis-exporter` | `redis-single` |

## TiDB 存取方式

叢集內服務：

- Host: `basic-tidb.tidb-cluster`
- Port: `4000`

Lab 對外服務：

- Host: `172.24.40.17`
- Port: `30400`

測試指令：

```bash
make tidb-info-short
```

TiDB Monitor 預設入口：

- Grafana: `http://172.24.40.17:32159`

目前已驗證：

- `curl -s http://172.24.40.17:32159/api/health` 可正常回傳
- TiDB Monitor Grafana 版本為 `7.5.11`

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

從 cluster 內測試：

```bash
kubectl run -n mysql-single mysql-client --rm -it --image=mysql:8.0 --restart=Never -- \
  mysql -h minimal-cluster-haproxy -uroot -p$(kubectl get secret -n mysql-single minimal-cluster-secrets -o jsonpath='{.data.root}' | base64 -d)
```

從 cluster 外測試：

```bash
mysql -h 172.24.40.17 -P 30306 -uroot -p
```

## Lab 限制

- Storage 使用 `local-path`，僅適合 lab / POC
- `percona-operator` 目前以較寬鬆 RBAC 運作，不適合直接進正式環境
- `mysql-single` 密碼目前存放於 GitOps secret manifest，後續需改為安全憑證管理機制
- `redis-operator` 目前使用 `ServerSideApply=true` 避免大型 CRD annotation 問題
- `tidb-operator` 目前停用 `tidb-scheduler`，僅保留與 `Kubernetes 1.29` 相容的最小 operator 組態
- `metrics-server` 已安裝，但尚未納入 GitOps 管理

## 下一步建議

1. 補 `redis-sentinel / redis-ha` 驗證流程
2. 收斂 TiDB scheduler 與正式版相容性策略
3. 收斂正式環境 RBAC、Secret 管理與對外入口策略

## 監控規劃

Lab 環境規劃導入：

- `VictoriaMetrics Single` 作為 metrics backend
- `Grafana` 作為 dashboard 入口
- `mysqld-exporter` 作為 `mysql-single` metrics exporter
- `redis-exporter` 作為 `redis-single` metrics exporter
- 預設 namespace：`monitoring`
- Lab 對外入口預計：
  - Grafana: `172.24.40.17:30300`
  - VictoriaMetrics: `172.24.40.17:30428`

目前已驗證：

- `mysql_up=1` 可由 VictoriaMetrics 查詢
- 目前保留 `service-endpoints` 單一路徑抓取 `mysqld-exporter`
- `redis_up=1` 應可由 VictoriaMetrics 查詢
- `kubectl top nodes` 已可觀察節點 CPU / memory 使用量

## Lab 架構摘要

- MySQL：`Percona Operator + mysql-single + mysqld-exporter`
- Redis：`OT-CONTAINER-KIT redis-operator + redis-single + redis-exporter`
- TiDB：`PingCAP tidb-operator + tidb-cluster`
- GitOps：`Argo CD + GitHub`
- Storage：`local-path` (`/data`)
- Metrics：`VictoriaMetrics`
- Cluster Metrics：`metrics-server`
- Dashboard：`Grafana`
