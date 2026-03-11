# DBaaS Implementation Status

## 目前狀態

- Kubernetes lab cluster 已完成基線建置
- `local-path` 已作為預設 `StorageClass`
- `Argo CD` 已可從 GitHub 同步 GitOps 設定
- `Percona Operator` 已可在 cluster 內運作
- `mysql-single` 已成功建立並完成 SQL 驗證

## 已完成項目

| 項目 | 狀態 | 說明 |
|---|---|---|
| StorageClass | done | 使用 `local-path` 對應各 node `/data` |
| GitOps | done | 使用 `Argo CD + GitHub` |
| MySQL Operator | done | 使用 `Percona XtraDB Cluster Operator` |
| mysql-single | done | 單節點 PXC + HAProxy |
| SQL 驗證 | done | 已完成建庫、建表、寫入與查詢 |

## 目前部署元件

| 類型 | 名稱 | Namespace |
|---|---|---|
| Argo CD App | `dbaas-root` | `argocd` |
| Argo CD App | `percona-operator` | `argocd` |
| Argo CD App | `mysql-single` | `argocd` |
| DB Cluster | `minimal-cluster` | `mysql-single` |

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

## 下一步建議

1. 導入 `redis-single` GitOps POC
2. 補 `backup / restore` 驗證流程
3. 收斂正式環境 RBAC、Secret 管理與對外入口策略
