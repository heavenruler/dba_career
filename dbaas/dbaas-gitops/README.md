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
```

## 第一步

先套用 `projects/dbaas-project.yaml`，再套用 `bootstrap/root-application.yaml`。

## 驗證

- Argo CD 應出現 `dbaas-root` 與 `hello-app`
- 叢集應建立 `dbaas-system` namespace
