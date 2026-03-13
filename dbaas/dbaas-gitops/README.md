# dbaas-gitops

最小 GitOps 骨架，先驗證 Argo CD、AppProject、Application 與 namespace 建立流程。

## 目錄

```text
dbaas-gitops/
  bootstrap/
    root-application.yaml
  projects/
    dbaas-project.yaml
  clusters/
    lab/
      namespaces/
        dbaas-system.yaml
      apps/
        kustomization.yaml
        hello-app.yaml
        percona-operator.yaml
        mysql-single.yaml
        tidb-operator.yaml
        tidb-cluster.yaml
        tidb-monitor.yaml
        redis-operator.yaml
        redis-single.yaml
        victoria-metrics.yaml
        grafana.yaml
      operators/
        percona/
          kustomization.yaml
          namespace.yaml
      services/
        mysql-single/
          kustomization.yaml
          namespace.yaml
          secrets.yaml
          cluster.yaml
          nodeport-service.yaml
        tidb-cluster/
          kustomization.yaml
          namespace.yaml
          tidb-cluster.yaml
        tidb-monitor/
          kustomization.yaml
          tidb-monitor.yaml
```

## 第一步

先套用 `projects/dbaas-project.yaml`，再套用 `bootstrap/root-application.yaml`。

## 驗證

- Argo CD 應出現 `dbaas-root` 與 `hello-app`
- 叢集應建立 `dbaas-system` namespace

## 下一步

- `percona-operator.yaml` 會讓 Argo CD 佈署 Percona Operator
- Operator 安裝 namespace 預設為 `percona-operator`
- `mysql-single.yaml` 會建立最小 MySQL POC
- `tidb-operator.yaml` 會佈署 PingCAP TiDB Operator
- `tidb-cluster.yaml` 會建立最小 TiDB Cluster POC
- `tidb-monitor.yaml` 會建立最小 TiDB Monitor POC
- `redis-operator.yaml` 會佈署 OT-CONTAINER-KIT Redis Operator
- `redis-single.yaml` 會建立最小 Redis Standalone POC
- `nodeport-service.yaml` 會暴露 Lab MySQL 對外入口 `30306`
- `victoria-metrics.yaml` 與 `grafana.yaml` 會建立 Lab 監控入口
