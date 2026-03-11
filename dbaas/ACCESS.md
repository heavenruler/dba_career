# DBaaS Lab Access

## 對外入口

| 服務 | URL / Host | 說明 |
|---|---|---|
| Argo CD | `https://172.24.40.17:31559` | GitOps 管理入口 |
| Grafana | `http://172.24.40.17:30300` | Dashboard 與 Explore |
| VictoriaMetrics | `http://172.24.40.17:30428` | Metrics Query API |
| MySQL `mysql-single` | `172.24.40.17:30306` | 對外 MySQL 入口 |
| OTel Demo | `http://172.24.40.17:30080` | OpenTelemetry 顯化入口 |

## 叢集內入口

| 服務 | 位址 | 說明 |
|---|---|---|
| MySQL HAProxy | `minimal-cluster-haproxy.mysql-single:3306` | MySQL cluster 內入口 |
| mysqld-exporter | `mysqld-exporter.mysql-single:9104` | MySQL metrics exporter |
| VictoriaMetrics | `victoria-metrics-server.monitoring:8428` | Metrics backend |
| Tempo HTTP | `tempo.monitoring:3200` | Trace query API |
| Tempo OTLP gRPC | `tempo.monitoring:4317` | Trace ingest |
| Tempo OTLP HTTP | `tempo.monitoring:4318` | Trace ingest |
| Alloy OTLP gRPC | `alloy-otlp.monitoring:4317` | OTel receiver |
| Alloy OTLP HTTP | `alloy-otlp.monitoring:4318` | OTel receiver |

## 常用帳密

### Argo CD

- User: `admin`
- Password: 初始密碼可由下列指令取得

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo
```

### Grafana

- User: `admin`
- Password: `admin123456`

### MySQL root

查詢密碼：

```bash
kubectl get secret -n mysql-single minimal-cluster-secrets -o jsonpath='{.data.root}' | base64 -d; echo
```

## 常用連線指令

### MySQL cluster 外連線

```bash
mysql -h 172.24.40.17 -P 30306 -uroot -p
```

### MySQL cluster 內連線

```bash
kubectl exec -it -n mysql-single minimal-cluster-pxc-0 -- \
  mysql -uroot -p$(kubectl get secret -n mysql-single minimal-cluster-secrets -o jsonpath='{.data.root}' | base64 -d)
```

### VictoriaMetrics 查詢

```bash
curl -s "http://172.24.40.17:30428/api/v1/query?query=mysql_up" | python3 -m json.tool
```

## 盤點指令

### 所有 NodePort

```bash
kubectl get svc -A --field-selector spec.type=NodePort
```

### Argo CD Applications

```bash
kubectl get applications -n argocd
```

### 監控元件

```bash
kubectl get pods,svc,pvc -n monitoring
kubectl get pods,svc -n otel-demo
```

## Lab 注意事項

- 所有入口目前以 `NodePort` 為主，適合 lab，不適合正式環境直接沿用
- Storage 使用 `local-path`，資料與 node 綁定
- 部分帳密目前仍為 lab 固定值，正式化前需改為 Secret 管理方案
