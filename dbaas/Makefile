.PHONY: help apps namespaces pvc pv rebuild-delete rebuild-bootstrap rebuild-wait rebuild-verify mysql-check tidb-check tidb-info tidb-info-short redis-check redis-ping redis-info redis-info-short monitoring-check rebuild-all

KUBECTL ?= kubectl
ARGOCD_NS ?= argocd
DBAAS_ROOT ?= /root/dba_career/dbaas
PROJECT_FILE ?= $(DBAAS_ROOT)/dbaas-gitops/projects/dbaas-project.yaml
ROOT_APP_FILE ?= $(DBAAS_ROOT)/dbaas-gitops/bootstrap/root-application.yaml
WORKLOAD_NAMESPACES ?= dbaas-system mysql-single percona-operator tidb-operator tidb-cluster redis-single redis-operator monitoring

help:
	@printf '%s\n' \
	  'make rebuild-all        # 清空 Argo CD 資源並重建' \
	  'make rebuild-delete     # 刪除 Argo CD applications' \
	  'make namespaces         # 刪除工作 namespaces' \
	  'make rebuild-bootstrap  # 重新套用 AppProject 與 root app' \
	  'make rebuild-wait       # 觀察 applications / pods' \
	  'make rebuild-verify     # 驗證 mysql / redis / monitoring 狀態' \
	  'make mysql-check        # 檢查 mysql-single 狀態' \
	  'make tidb-check         # 檢查 tidb-operator 狀態' \
	  'make tidb-info          # 顯示 tidb-cluster 基本資訊' \
	  'make tidb-info-short    # 顯示 tidb_version()' \
	  'make redis-check        # 檢查 redis-single 狀態' \
	  'make redis-ping         # 測試 redis-single ping' \
	  'make redis-info         # 顯示 redis-single info' \
	  'make redis-info-short   # 顯示 redis 關鍵資訊' \
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
	$(KUBECTL) delete application -n $(ARGOCD_NS) grafana hello-app mysql-single percona-operator tidb-operator tidb-cluster redis-operator redis-single victoria-metrics --ignore-not-found || true
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

tidb-check:
	$(KUBECTL) get pods -n tidb-operator
	$(KUBECTL) get crd | grep pingcap.com || true

tidb-info:
	$(KUBECTL) get tc -n tidb-cluster
	$(KUBECTL) get pods,svc,pvc -n tidb-cluster

tidb-info-short:
	$(KUBECTL) run -n tidb-cluster mysql-client --rm -i --restart=Never --image=mysql:8.0 -- mysql -h basic-tidb -P 4000 -u root -e "select tidb_version();"

redis-check:
	$(KUBECTL) get redis -n redis-single
	$(KUBECTL) get pods,svc,pvc -n redis-single

redis-ping:
	$(KUBECTL) run -n redis-single redis-client --rm -i --restart=Never --image=redis:7.0 -- redis-cli -h redis-single -p 6379 ping

redis-info:
	$(KUBECTL) run -n redis-single redis-client --rm -i --restart=Never --image=redis:7.0 -- redis-cli -h redis-single -p 6379 info

redis-info-short:
	$(KUBECTL) run -n redis-single redis-client --rm -i --restart=Never --image=redis:7.0 -- sh -c 'redis-cli -h redis-single -p 6379 info server | egrep "redis_version|process_id|tcp_port|uptime_in_seconds"'

monitoring-check:
	$(KUBECTL) get pods,svc,pvc -n monitoring

rebuild-verify: mysql-check tidb-check redis-check monitoring-check

rebuild-all: rebuild-delete namespaces rebuild-bootstrap rebuild-wait rebuild-verify
