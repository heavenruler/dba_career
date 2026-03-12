.PHONY: help apps namespaces pvc pv rebuild-delete rebuild-bootstrap rebuild-wait rebuild-verify mysql-check monitoring-check rebuild-all

KUBECTL ?= kubectl
ARGOCD_NS ?= argocd
DBAAS_ROOT ?= /root/dba_career/dbaas
PROJECT_FILE ?= $(DBAAS_ROOT)/dbaas-gitops/projects/dbaas-project.yaml
ROOT_APP_FILE ?= $(DBAAS_ROOT)/dbaas-gitops/bootstrap/root-application.yaml
WORKLOAD_NAMESPACES ?= dbaas-system mysql-single percona-operator monitoring

help:
	@printf '%s\n' \
	  'make rebuild-all        # 清空 Argo CD 資源並重建' \
	  'make rebuild-delete     # 刪除 Argo CD applications' \
	  'make namespaces         # 刪除工作 namespaces' \
	  'make rebuild-bootstrap  # 重新套用 AppProject 與 root app' \
	  'make rebuild-wait       # 觀察 applications / pods' \
	  'make rebuild-verify     # 驗證 mysql / monitoring 狀態' \
	  'make mysql-check        # 檢查 mysql-single 狀態' \
	  'make monitoring-check   # 檢查 monitoring 狀態'

apps:
	$(KUBECTL) get applications -n $(ARGOCD_NS)

namespaces:
	$(KUBECTL) delete ns $(WORKLOAD_NAMESPACES) --ignore-not-found
	$(KUBECTL) get ns

pvc:
	$(KUBECTL) get pvc -A

pv:
	$(KUBECTL) get pv

rebuild-delete:
	$(KUBECTL) delete application -n $(ARGOCD_NS) dbaas-root --ignore-not-found || true
	@sleep 5
	$(KUBECTL) delete application -n $(ARGOCD_NS) grafana hello-app mysql-single percona-operator victoria-metrics --ignore-not-found || true
	$(KUBECTL) get applications -n $(ARGOCD_NS)

rebuild-bootstrap:
	$(KUBECTL) apply -f $(PROJECT_FILE)
	$(KUBECTL) apply -f $(ROOT_APP_FILE)
	$(KUBECTL) get applications -n $(ARGOCD_NS)

rebuild-wait:
	$(KUBECTL) get applications -n $(ARGOCD_NS)
	$(KUBECTL) get ns
	$(KUBECTL) get pods -A -o wide

mysql-check:
	$(KUBECTL) get pxc -n mysql-single
	$(KUBECTL) get pods,svc,pvc -n mysql-single

monitoring-check:
	$(KUBECTL) get pods,svc,pvc -n monitoring

rebuild-verify: mysql-check monitoring-check

rebuild-all: rebuild-delete namespaces rebuild-bootstrap rebuild-wait rebuild-verify
