IAC_DIR     := iac
GCP_IAC_DIR := gcp-iac/envs/dev
ANSIBLE_DIR := ansible
INVENTORY   := $(ANSIBLE_DIR)/inventory/hosts.ini

## TPC-C defaults (override: make test-tpcc-vm WAREHOUSES=200 THREADS='32 64 128')
TIDB_USER    ?= root
TIDB_PASS    ?=
WAREHOUSES   ?= 128
DURATION     ?= 10m
THREADS      ?= 16 32 64 128
WARMUP       ?= 5m
TOPO         ?= tidb-tc1
SCENARIO     ?= S-BASE
RESULT_BASE  ?= results

## tc1 connection endpoints
TIDB_HOST_VM  := 172.24.40.34
TIDB_PORT_VM  := 4000
TIDB_HOST_K8S := 172.24.40.32
TIDB_PORT_K8S := 30004

## YugabyteDB connection endpoints (VM=HAProxy, K8s=NodePort)
YUGA_HOST_VM  := 172.24.40.32
YUGA_PORT_VM  := 15433
YUGA_HOST_K8S := 172.24.40.32
YUGA_PORT_K8S := 30005
YUGA_USER     ?= yugabyte
YUGA_PASS     ?=

## TPC-C remote client node — 172.24.40.31 (l-dbm-labroom-1, dedicated, not a DB node)
## Must NOT use 172.24.40.32/33/34 (DB nodes) to avoid resource contention
REMOTE_HOST ?= root@172.24.40.31

TPCC_ENV = TIDB_USER="$(TIDB_USER)" TIDB_PASS="$(TIDB_PASS)" \
           WAREHOUSES="$(WAREHOUSES)" DURATION="$(DURATION)" \
           THREADS_LIST="$(THREADS)" WARMUP="$(WARMUP)" \
           TOPO="$(TOPO)" SCENARIO="$(SCENARIO)" RESULT_BASE="$(RESULT_BASE)" \
           REMOTE_HOST="$(REMOTE_HOST)"

YUGA_TPCC_ENV = YUGA_USER="$(YUGA_USER)" YUGA_PASS="$(YUGA_PASS)" \
                WAREHOUSES="$(WAREHOUSES)" DURATION="$(DURATION)" \
                THREADS_LIST="$(THREADS)" WARMUP="$(WARMUP)" \
                TOPO="$(TOPO)" SCENARIO="$(SCENARIO)" RESULT_BASE="$(RESULT_BASE)" \
                REMOTE_HOST="$(REMOTE_HOST)"

.PHONY: help \
        yuga tidb \
        apply-all destroy-all \
        vm-create vm-destroy inventory-refresh ansible-ping ansible-setup vm-ping vm-setup \
        gcp-create gcp-destroy gcp-tunnel-start gcp-tunnel-stop gcp-tunnel-ensure \
        gcp-inventory-refresh inventory-refresh-all \
        tidb-deploy tidb-status yugabyte-deploy yugabyte-status \
        tidb-haproxy-tc1 tidb-haproxy-tc3 tidb-haproxy-tc4 \
        yuga-haproxy-tc1 yuga-haproxy-tc3 yuga-haproxy-tc4 \
        tidb-tc1 tidb-tc2 tidb-tc3 tidb-tc4 \
        yuga-tc1 yuga-tc2 yuga-tc3 yuga-tc4 \
        k8s-setup tidb-tc1-k8s tidb-tc1-k8s-limit tidb-k8s-status \
        yuga-tc1-k8s yuga-tc1-k8s-limit yuga-k8s-status \
        tpcc-cleanup-vm tpcc-cleanup-k8s \
        tpcc-prepare-vm tpcc-prepare-k8s \
        test-tpcc-vm test-tpcc-k8s test-tpcc-k8s-limit \
        tpcc-cleanup-yuga-vm tpcc-cleanup-yuga-k8s \
        tpcc-prepare-yuga-vm tpcc-prepare-yuga-k8s \
        test-tpcc-yuga-vm test-tpcc-yuga-k8s test-tpcc-yuga-k8s-limit \
        tpcc-report

help:
	@echo "=== Pipeline ==="
	@echo "  make tidb                   - TiDB demo (destroy→deploy→status)"
	@echo "  make yuga                   - YugabyteDB demo (destroy→deploy→status)"
	@echo "  make tidb-tc1               - TiDB TC1: Single IDC HA  (PD×3/TiDB×2/TiKV×3 RF=3)"
	@echo "  make tidb-tc2               - TiDB TC2: Cross-zone min (PD×3/TiDB×2/TiKV×2 RF=2)"
	@echo "  make tidb-tc3               - TiDB TC3: Cross-zone full(PD×3/TiDB×3/TiKV×5 RF=3)"
	@echo "  make tidb-tc4               - TiDB TC4: Cross-zone GCP primary (PD×3: 1IDC+2GCP, TiKV×5 RF=3)"
	@echo "  make yuga-tc1               - YugabyteDB TC1: Single zone RF3 (3 nodes)"
	@echo "  make yuga-tc2               - YugabyteDB TC2: Cross-zone RF3 (5 nodes)"
	@echo "  make yuga-tc3               - YugabyteDB TC3: Cross-zone RF5 (5 nodes, 100GB)"
	@echo "  make yuga-tc4               - YugabyteDB TC4: Cross-zone GCP primary (masters: 1IDC+2GCP, RF=3)"
	@echo ""
	@echo "┌─────────────────────────────────────────────────────────────────────────────────────────────────┐"
	@echo "│  TC Summary                                                                                     │"
	@echo "├──────────────┬──────────────────────┬────────────────────┬─────────────────────┬───────────────┤"
	@echo "│ Target       │ PD / Masters         │ TiDB / TServers    │ TiKV                │ RF / Disk     │"
	@echo "├──────────────┼──────────────────────┼────────────────────┼─────────────────────┼───────────────┤"
	@echo "│ tidb-tc1     │ poc-1/2/3            │ poc-1/2            │ poc-1/2/3           │ RF=3 / 30GB   │"
	@echo "│ tidb-tc2     │ poc-1/2 + gcp-1      │ poc-1 + gcp-1      │ poc-1 + gcp-1       │ RF=2 / 30GB   │"
	@echo "│ tidb-tc3     │ poc-1/2 + gcp-1      │ poc-1/2 + gcp-1    │ all 5               │ RF=3 / 30GB   │"
	@echo "│ tidb-tc4     │ poc-1 + gcp-1/2      │ poc-1 + gcp-1/2    │ all 5               │ RF=3 / 30GB   │"
	@echo "├──────────────┼──────────────────────┼────────────────────┼─────────────────────┼───────────────┤"
	@echo "│ yuga-tc1     │ poc-1/2/3            │ poc-1/2/3          │ -                   │ RF=3 / 30GB   │"
	@echo "│ yuga-tc2     │ poc-1/2 + gcp-1      │ all 5              │ -                   │ RF=3 / 30GB   │"
	@echo "│ yuga-tc3     │ poc-1/2 + gcp-1      │ all 5              │ -                   │ RF=5 / 100GB  │"
	@echo "│ yuga-tc4     │ poc-1 + gcp-1/2      │ all 5              │ -                   │ RF=3 / 30GB   │"
	@echo "└──────────────┴──────────────────────┴────────────────────┴─────────────────────┴───────────────┘"
	@echo "  RF (Replication Factor)：每筆資料保存的副本數，RF=3 表示 3 份副本分散於不同節點"
	@echo "  容錯能力 = RF-1，RF=3 可容忍 1 節點故障；RF=5 可容忍 2 節點故障"
	@echo ""
	@echo "  Zone-aware Routing："
	@echo "  ┌─────────────┬──────────────────────────────────────────────────────────────────┐"
	@echo "  │ Target      │ 說明                                                             │"
	@echo "  ├─────────────┼──────────────────────────────────────────────────────────────────┤"
	@echo "  │ tidb-tc1    │ 單一 IDC，無跨區設定                                             │"
	@echo "  │ tidb-tc2/3  │ location-labels=zone；TiDB/TiKV 標記 idc/gcp zone               │"
	@echo "  │             │ → poc 流量優先讀取 idc 副本，避免繞道 GCP                        │"
	@echo "  │ yuga-tc1    │ 單一 IDC，無跨區設定                                             │"
	@echo "  │ yuga-tc2/3  │ cloud_location 標記各節點 zone；placement policy 限制 master 分佈 │"
	@echo "  │             │ → follower reads 啟用 (staleness=10s)，讀取本地副本              │"
	@echo "  └─────────────┴──────────────────────────────────────────────────────────────────┘"
	@echo ""
	@echo "  HAProxy 規劃："
	@echo "  ┌─────────────┬──────────┬─────────────────────────────────────────────────────┐"
	@echo "  │ Target      │ HAProxy  │ 說明                                                │"
	@echo "  ├─────────────┼──────────┼─────────────────────────────────────────────────────┤"
	@echo "  │ tidb-tc1    │ poc-3    │ :4000 → roundrobin poc-1/2:4000                     │"
	@echo "  │ tidb-tc2    │ 不需要   │ 每 zone 單一 TiDB 節點，直連即可                    │"
	@echo "  │ tidb-tc3    │ poc-3    │ IDC :4000 → poc-1/2:4000                            │"
	@echo "  │             │ gcp-2    │ GCP :4000 → gcp-1:4000                              │"
	@echo "  │ tidb-tc4    │ poc-3    │ IDC :4000 → poc-1:4000                              │"
	@echo "  │             │ 直連     │ GCP 直連 gcp-1/gcp-2:4000                           │"
	@echo "  ├─────────────┼──────────┼─────────────────────────────────────────────────────┤"
	@echo "  │ yuga-tc1    │ poc-1    │ :15433 → roundrobin poc-1/2/3:5433                  │"
	@echo "  │ yuga-tc2    │ 不需要   │ 每 zone 單一 TServer，直連即可                      │"
	@echo "  │ yuga-tc3    │ poc-1    │ IDC :15433 → poc-1/2/3:5433                         │"
	@echo "  │             │ gcp-1    │ GCP :15433 → gcp-1/2:5433                           │"
	@echo "  │ yuga-tc4    │ poc-1    │ IDC :15433 → poc-1/2/3:5433                         │"
	@echo "  │             │ gcp-1    │ GCP :15433 → gcp-1/2:5433                           │"
	@echo "  └─────────────┴──────────┴─────────────────────────────────────────────────────┘"
	@echo ""
	@echo "=== Global ==="
	@echo "  make apply-all              - 建立全部 VM (vSphere + GCP)"
	@echo "  make destroy-all            - 刪除全部 VM (vSphere + GCP)"
	@echo ""
	@echo "=== vSphere ==="
	@echo "  make vm-create              - Terraform apply (建立 VM)"
	@echo "  make vm-destroy             - Terraform destroy (刪除 VM)"
	@echo "  make inventory-refresh      - 從 Terraform output 重建 vSphere hosts.ini"
	@echo ""
	@echo "=== GCP ==="
	@echo "  make gcp-create             - Terraform apply (建立 GCP VM)"
	@echo "  make gcp-destroy            - Terraform destroy (刪除 GCP VM)"
	@echo "  make gcp-tunnel-start       - 啟動 IAP SSH tunnels"
	@echo "  make gcp-tunnel-stop        - 關閉 IAP SSH tunnels"
	@echo "  make gcp-inventory-refresh  - 從 Terraform output 重建 GCP hosts.ini"
	@echo ""
	@echo "=== Ansible ==="
	@echo "  make ansible-ping           - 重建全部清單 + 確認 tunnel + ping 所有 VM"
	@echo "  make ansible-setup          - 執行 site.yml (base 設定)"
	@echo ""
	@echo "=== TiDB ==="
	@echo "  make tidb-deploy            - 部署 TiDB cluster (tidb.yml)"
	@echo "  make tidb-status            - 初始化密碼 + cluster status 檢查"
	@echo "  make tidb-haproxy-tc1       - 部署 HAProxy on poc-3 → poc-1/2:4000 (tc1)"
	@echo "  make tidb-haproxy-tc3       - 部署 HAProxy on poc-3(IDC) + gcp-2(GCP) (tc3)"
	@echo "  make tidb-haproxy-tc4       - 部署 HAProxy on poc-3(IDC) only；GCP 直連 (tc4)"
	@echo ""
	@echo "=== YugabyteDB ==="
	@echo "  make yugabyte-deploy        - 部署 YugabyteDB cluster (yugabyte.yml)"
	@echo "  make yugabyte-status        - 初始化密碼 + cluster status 檢查"
	@echo "  make yuga-haproxy-tc1       - 部署 HAProxy on poc-1:15433 → poc-1/2/3:5433 (tc1)"
	@echo "  make yuga-haproxy-tc3       - 部署 HAProxy on poc-1:15433(IDC) + gcp-1:15433(GCP) (tc3)"
	@echo "  make yuga-haproxy-tc4       - 部署 HAProxy on poc-1:15433(IDC) + gcp-1:15433(GCP) (tc4)"
	@echo ""
	@echo "=== TPC-C (VM vs K8s 比較；共用 tests/common/tpcc.sh) ==="
	@echo "  VM round  : tpcc-prepare-vm → test-tpcc-vm → tpcc-report VARIANT=vm"
	@echo "  K8s round : tpcc-cleanup-k8s → tpcc-prepare-k8s → test-tpcc-k8s → tpcc-report VARIANT=k8s-unlimit"
	@echo "  K8s-limit : tpcc-cleanup-k8s → tpcc-prepare-k8s → test-tpcc-k8s-limit → tpcc-report VARIANT=k8s-limit"
	@echo ""
	@echo "  make tpcc-cleanup-vm        - 清除 tpcc schema (VM TiDB)"
	@echo "  make tpcc-cleanup-k8s       - 清除 tpcc schema (K8s TiDB)"
	@echo "  make tpcc-prepare-vm        - 建立 tpcc schema + 載入資料 (VM)"
	@echo "  make tpcc-prepare-k8s       - 建立 tpcc schema + 載入資料 (K8s)"
	@echo "  make test-tpcc-vm           - 執行 TPC-C warmup+run (VARIANT=vm)"
	@echo "  make test-tpcc-k8s          - 執行 TPC-C warmup+run (VARIANT=k8s-unlimit)"
	@echo "  make test-tpcc-k8s-limit    - 執行 TPC-C warmup+run (VARIANT=k8s-limit)"
	@echo "  make tpcc-report            - 產生最新一次結果的 summary.md"
	@echo "  Override: WAREHOUSES=50 DURATION=5m THREADS='32 64' VARIANT=vm"
	@echo ""
	@echo "=== K8s (VM vs K8s TPC-C 比較) ==="
	@echo "  make k8s-setup              - destroy→VM→k3s v1.29 cluster (poc-1 server / poc-2/3 agents)"
	@echo "  make tidb-tc1-k8s           - k8s-setup→TiDB Operator v1.6.5→TidbCluster (K8s-unlimit)"
	@echo "  make tidb-tc1-k8s-limit     - 重部署 TiDB with resource limits (K8s-limit round)"
	@echo "  make tidb-k8s-status        - 顯示 nodes / TidbCluster / pods / resource limits / endpoint"
	@echo "  make yuga-tc1-k8s           - k8s-setup→YugabyteDB Helm 部署 (no limits)→status"
	@echo "  make yuga-tc1-k8s-limit     - k8s-setup→YugabyteDB Helm 部署 with resource limits→status"
	@echo "  make yuga-k8s-status        - 顯示 nodes / pods / services / YSQL endpoint"
	@echo ""
	@echo "=== YugabyteDB TPC-C (BenchmarkSQL; VM:HAProxy:15433 / K8s:NodePort:30005) ==="
	@echo "  VM  round  : tpcc-prepare-yuga-vm  → test-tpcc-yuga-vm       → tpcc-report VARIANT=yuga-vm"
	@echo "  K8s round  : tpcc-prepare-yuga-k8s → test-tpcc-yuga-k8s     → tpcc-report VARIANT=yuga-k8s"
	@echo "  K8s-limit  : tpcc-prepare-yuga-k8s → test-tpcc-yuga-k8s-limit → tpcc-report VARIANT=yuga-k8s-limit"
	@echo ""
	@echo "  make tpcc-cleanup-yuga-vm   - 清除 benchmarksql DB (VM)"
	@echo "  make tpcc-cleanup-yuga-k8s  - 清除 benchmarksql DB (K8s)"
	@echo "  make tpcc-prepare-yuga-vm   - 建表+載料 (VM)"
	@echo "  make tpcc-prepare-yuga-k8s  - 建表+載料 (K8s)"
	@echo "  make test-tpcc-yuga-vm          - warmup+run (VARIANT=yuga-vm)"
	@echo "  make test-tpcc-yuga-k8s         - warmup+run (VARIANT=yuga-k8s)"
	@echo "  make test-tpcc-yuga-k8s-limit   - warmup+run (VARIANT=yuga-k8s-limit)"
	@echo "  Override: WAREHOUSES=50 DURATION=5m THREADS='32 64' YUGA_USER=yugabyte"

## Pipeline
tidb:
	$(MAKE) destroy-all
	$(MAKE) apply-all
	$(MAKE) ansible-ping
	$(MAKE) ansible-setup
	$(MAKE) tidb-deploy
	$(MAKE) tidb-status

yuga:
	$(MAKE) destroy-all
	$(MAKE) apply-all
	$(MAKE) ansible-ping
	$(MAKE) ansible-setup
	$(MAKE) yugabyte-deploy
	$(MAKE) yugabyte-status

## Global
apply-all:
	$(MAKE) -j2 vm-create gcp-create
	@echo "==> All VMs created"

destroy-all:
	$(MAKE) -j2 vm-destroy gcp-destroy
	@echo "==> All VMs destroyed"

## vSphere Terraform
vm-create:
	cd $(IAC_DIR) && terraform init -upgrade && terraform apply -auto-approve

vm-destroy:
	cd $(IAC_DIR) && terraform destroy -auto-approve

## vSphere Inventory
inventory-refresh:
	cd $(IAC_DIR) && terraform output -json vm_ips | \
	  jq -r '"[poc_db]", (to_entries[] | .value + " ansible_hostname=" + .key)' \
	  > ../$(INVENTORY)
	@echo "==> $(INVENTORY) updated"
	@cat $(INVENTORY)

## vSphere Ansible
ansible-ping: inventory-refresh-all gcp-tunnel-ensure
	cd $(ANSIBLE_DIR) && ansible all -m ping

ansible-setup:
	cd $(ANSIBLE_DIR) && ansible-playbook playbooks/site.yml

## vSphere-only (no GCP) — for TC1 / K8s targets
vm-ping: inventory-refresh
	cd $(ANSIBLE_DIR) && ansible poc_db -m ping

vm-setup:
	cd $(ANSIBLE_DIR) && ansible-playbook playbooks/site.yml \
	  -i inventory/hosts.ini

## GCP Terraform
gcp-create:
	cd $(GCP_IAC_DIR) && terraform init -upgrade && terraform apply -auto-approve

gcp-destroy:
	cd $(GCP_IAC_DIR) && terraform destroy -auto-approve

## GCP IAP Tunnel
gcp-tunnel-start:
	@$(GCP_IAC_DIR)/tunnel.sh start

gcp-tunnel-stop:
	@$(GCP_IAC_DIR)/tunnel.sh stop

gcp-tunnel-ensure:
	@if ! lsof -i :12211 | grep -q LISTEN 2>/dev/null; then \
	  echo "==> IAP tunnel not running, starting..."; \
	  $(GCP_IAC_DIR)/tunnel.sh start; \
	else \
	  echo "==> IAP tunnel already running"; \
	fi

## GCP Inventory
gcp-inventory-refresh:
	cd $(GCP_IAC_DIR) && terraform output -json host_ip_mapping | \
	  jq -r '"[gcp_poc]", (to_entries[] | .key + " ansible_host=localhost ansible_port=" + (if .key == "g-test-poc-1" then "12211" else "12212" end) + " ansible_hostname=" + .key)' \
	  >> ../../../$(INVENTORY)
	@echo "==> GCP section appended to $(INVENTORY)"

## Combined Inventory (vSphere overwrite → GCP append)
inventory-refresh-all: inventory-refresh gcp-inventory-refresh
	@echo "==> Final inventory:"
	@cat $(INVENTORY)

## HAProxy
tidb-haproxy-tc1:
	cd $(ANSIBLE_DIR) && ansible-playbook playbooks/haproxy.yml \
	  -i inventory/hosts.ini \
	  -i inventory/tidb-tc1.ini

tidb-haproxy-tc3: gcp-tunnel-ensure
	cd $(ANSIBLE_DIR) && ansible-playbook playbooks/haproxy.yml \
	  -i inventory/hosts.ini \
	  -i inventory/tidb-tc3.ini

tidb-haproxy-tc4:
	cd $(ANSIBLE_DIR) && ansible-playbook playbooks/haproxy.yml \
	  -i inventory/hosts.ini \
	  -i inventory/tidb-tc4.ini

yuga-haproxy-tc1:
	cd $(ANSIBLE_DIR) && ansible-playbook playbooks/haproxy.yml \
	  -i inventory/hosts.ini \
	  -i inventory/yugabyte-tc1.ini

yuga-haproxy-tc3: gcp-tunnel-ensure
	cd $(ANSIBLE_DIR) && ansible-playbook playbooks/haproxy.yml \
	  -i inventory/hosts.ini \
	  -i inventory/yugabyte-tc3.ini

yuga-haproxy-tc4: gcp-tunnel-ensure
	cd $(ANSIBLE_DIR) && ansible-playbook playbooks/haproxy.yml \
	  -i inventory/hosts.ini \
	  -i inventory/yugabyte-tc4.ini

## TiDB
tidb-deploy: gcp-tunnel-ensure
	cd $(ANSIBLE_DIR) && ansible-playbook playbooks/tidb.yml \
	  -i inventory/hosts.ini \
	  -i inventory/tidb.ini

tidb-status:
	cd $(ANSIBLE_DIR) && ansible-playbook playbooks/tidb-status.yml \
	  -i inventory/hosts.ini \
	  -i inventory/tidb.ini

## YugabyteDB
yugabyte-deploy: gcp-tunnel-ensure
	cd $(ANSIBLE_DIR) && ansible-playbook playbooks/yugabyte.yml \
	  -i inventory/hosts.ini \
	  -i inventory/yugabyte.ini

yugabyte-status: gcp-tunnel-ensure
	cd $(ANSIBLE_DIR) && ansible-playbook playbooks/yugabyte-status.yml \
	  -i inventory/hosts.ini \
	  -i inventory/yugabyte.ini

## TiDB Test Cases
tidb-tc1:
	$(MAKE) vm-destroy
	$(MAKE) vm-create
	$(MAKE) vm-ping
	$(MAKE) vm-setup
	cd $(ANSIBLE_DIR) && ansible-playbook playbooks/tidb.yml \
	  -i inventory/hosts.ini \
	  -i inventory/tidb-tc1.ini \
	  -e tidb_rf=3
	$(MAKE) tidb-haproxy-tc1
	cd $(ANSIBLE_DIR) && ansible-playbook playbooks/tidb-status.yml \
	  -i inventory/hosts.ini \
	  -i inventory/tidb-tc1.ini

tidb-tc2: gcp-tunnel-ensure
	$(MAKE) destroy-all
	$(MAKE) apply-all
	$(MAKE) ansible-ping
	$(MAKE) ansible-setup
	cd $(ANSIBLE_DIR) && ansible-playbook playbooks/tidb.yml \
	  -i inventory/hosts.ini \
	  -i inventory/tidb-tc2.ini \
	  -e tidb_rf=2 \
	  -e tidb_use_zones=true
	cd $(ANSIBLE_DIR) && ansible-playbook playbooks/tidb-status.yml \
	  -i inventory/hosts.ini \
	  -i inventory/tidb-tc2.ini

tidb-tc3: gcp-tunnel-ensure
	$(MAKE) destroy-all
	$(MAKE) apply-all
	$(MAKE) ansible-ping
	$(MAKE) ansible-setup
	cd $(ANSIBLE_DIR) && ansible-playbook playbooks/tidb.yml \
	  -i inventory/hosts.ini \
	  -i inventory/tidb-tc3.ini \
	  -e tidb_rf=3 \
	  -e tidb_use_zones=true
	$(MAKE) tidb-haproxy-tc3
	cd $(ANSIBLE_DIR) && ansible-playbook playbooks/tidb-status.yml \
	  -i inventory/hosts.ini \
	  -i inventory/tidb-tc3.ini

tidb-tc4: gcp-tunnel-ensure
	$(MAKE) destroy-all
	$(MAKE) apply-all
	$(MAKE) ansible-ping
	$(MAKE) ansible-setup
	cd $(ANSIBLE_DIR) && ansible-playbook playbooks/tidb.yml \
	  -i inventory/hosts.ini \
	  -i inventory/tidb-tc4.ini \
	  -e tidb_rf=3 \
	  -e tidb_use_zones=true
	$(MAKE) tidb-haproxy-tc4
	cd $(ANSIBLE_DIR) && ansible-playbook playbooks/tidb-status.yml \
	  -i inventory/hosts.ini \
	  -i inventory/tidb-tc4.ini

## YugabyteDB Test Cases
yuga-tc1:
	$(MAKE) vm-destroy
	$(MAKE) vm-create
	$(MAKE) vm-ping
	$(MAKE) vm-setup
	cd $(ANSIBLE_DIR) && ansible-playbook playbooks/yugabyte.yml \
	  -i inventory/hosts.ini \
	  -i inventory/yugabyte-tc1.ini \
	  -e yb_rf=3 \
	  -e yb_placement="poc.poc-region.idc:3" \
	  -e yb_master_addresses="172.24.40.32:7100,172.24.40.33:7100,172.24.40.34:7100"
	$(MAKE) yuga-haproxy-tc1
	cd $(ANSIBLE_DIR) && ansible-playbook playbooks/yugabyte-status.yml \
	  -i inventory/hosts.ini \
	  -i inventory/yugabyte-tc1.ini

yuga-tc2: gcp-tunnel-ensure
	$(MAKE) destroy-all
	$(MAKE) apply-all
	$(MAKE) ansible-ping
	$(MAKE) ansible-setup
	cd $(ANSIBLE_DIR) && ansible-playbook playbooks/yugabyte.yml \
	  -i inventory/hosts.ini \
	  -i inventory/yugabyte-tc2.ini \
	  -e yb_rf=3 \
	  -e yb_placement="poc.poc-region.idc:2,poc.poc-region.gcp:1" \
	  -e yb_master_addresses="172.24.40.32:7100,172.24.40.33:7100,10.160.152.11:7100"
	cd $(ANSIBLE_DIR) && ansible-playbook playbooks/yugabyte-status.yml \
	  -i inventory/hosts.ini \
	  -i inventory/yugabyte-tc2.ini \
	  -e yb_enable_follower_reads=true

yuga-tc3: gcp-tunnel-ensure
	$(MAKE) destroy-all
	cd $(IAC_DIR) && terraform apply -auto-approve -var "vm_disk_size=100"
	cd $(GCP_IAC_DIR) && terraform apply -auto-approve -var "disk_size=100"
	$(MAKE) ansible-ping
	$(MAKE) ansible-setup
	cd $(ANSIBLE_DIR) && ansible-playbook playbooks/yugabyte.yml \
	  -i inventory/hosts.ini \
	  -i inventory/yugabyte-tc3.ini \
	  -e yb_rf=5 \
	  -e yb_placement="poc.poc-region.idc:3,poc.poc-region.gcp:2" \
	  -e yb_master_addresses="172.24.40.32:7100,172.24.40.33:7100,10.160.152.11:7100"
	$(MAKE) yuga-haproxy-tc3
	cd $(ANSIBLE_DIR) && ansible-playbook playbooks/yugabyte-status.yml \
	  -i inventory/hosts.ini \
	  -i inventory/yugabyte-tc3.ini \
	  -e yb_enable_follower_reads=true

yuga-tc4: gcp-tunnel-ensure
	$(MAKE) destroy-all
	$(MAKE) apply-all
	$(MAKE) ansible-ping
	$(MAKE) ansible-setup
	cd $(ANSIBLE_DIR) && ansible-playbook playbooks/yugabyte.yml \
	  -i inventory/hosts.ini \
	  -i inventory/yugabyte-tc4.ini \
	  -e yb_rf=3 \
	  -e yb_placement="poc.poc-region.idc:1,poc.poc-region.gcp:2" \
	  -e yb_master_addresses="172.24.40.32:7100,10.160.152.11:7100,10.160.152.12:7100"
	$(MAKE) yuga-haproxy-tc4
	cd $(ANSIBLE_DIR) && ansible-playbook playbooks/yugabyte-status.yml \
	  -i inventory/hosts.ini \
	  -i inventory/yugabyte-tc4.ini \
	  -e yb_enable_follower_reads=true

## K8s
k8s-setup:
	$(MAKE) vm-destroy
	$(MAKE) vm-create
	$(MAKE) vm-ping
	$(MAKE) vm-setup
	cd $(ANSIBLE_DIR) && ansible-playbook playbooks/k8s.yml \
	  -i inventory/hosts.ini \
	  -i inventory/tidb-tc1-k8s.ini

tidb-tc1-k8s:
	$(MAKE) k8s-setup
	cd $(ANSIBLE_DIR) && ansible-playbook playbooks/tidb-k8s.yml \
	  -i inventory/tidb-tc1-k8s.ini
	$(MAKE) tidb-k8s-status

tidb-tc1-k8s-limit:
	$(MAKE) k8s-setup
	cd $(ANSIBLE_DIR) && ansible-playbook playbooks/tidb-k8s.yml \
	  -i inventory/tidb-tc1-k8s.ini \
	  -e k8s_resource_limits=true
	$(MAKE) tidb-k8s-status

tidb-k8s-status:
	cd $(ANSIBLE_DIR) && ansible-playbook playbooks/tidb-k8s-status.yml \
	  -i inventory/tidb-tc1-k8s.ini

yuga-tc1-k8s:
	$(MAKE) k8s-setup
	cd $(ANSIBLE_DIR) && ansible-playbook playbooks/yugabyte-k8s.yml \
	  -i inventory/yuga-tc1-k8s.ini
	$(MAKE) yuga-k8s-status

yuga-tc1-k8s-limit:
	$(MAKE) k8s-setup
	cd $(ANSIBLE_DIR) && ansible-playbook playbooks/yugabyte-k8s.yml \
	  -i inventory/yuga-tc1-k8s.ini \
	  -e yb_resource_limits=true
	$(MAKE) yuga-k8s-status

yuga-k8s-status:
	cd $(ANSIBLE_DIR) && ansible-playbook playbooks/yugabyte-k8s-status.yml \
	  -i inventory/yuga-tc1-k8s.ini

## TPC-C
tpcc-cleanup-vm:
	TIDB_HOST=$(TIDB_HOST_VM) TIDB_PORT=$(TIDB_PORT_VM) \
	  $(TPCC_ENV) bash tests/common/tpcc.sh cleanup

tpcc-cleanup-k8s:
	TIDB_HOST=$(TIDB_HOST_K8S) TIDB_PORT=$(TIDB_PORT_K8S) \
	  $(TPCC_ENV) bash tests/common/tpcc.sh cleanup

tpcc-prepare-vm:
	TIDB_HOST=$(TIDB_HOST_VM) TIDB_PORT=$(TIDB_PORT_VM) \
	  $(TPCC_ENV) bash tests/common/tpcc.sh prepare

tpcc-prepare-k8s:
	TIDB_HOST=$(TIDB_HOST_K8S) TIDB_PORT=$(TIDB_PORT_K8S) \
	  $(TPCC_ENV) bash tests/common/tpcc.sh prepare

test-tpcc-vm:
	TIDB_HOST=$(TIDB_HOST_VM) TIDB_PORT=$(TIDB_PORT_VM) VARIANT=vm \
	  $(TPCC_ENV) bash tests/common/tpcc.sh run

test-tpcc-k8s:
	TIDB_HOST=$(TIDB_HOST_K8S) TIDB_PORT=$(TIDB_PORT_K8S) VARIANT=k8s-unlimit \
	  $(TPCC_ENV) bash tests/common/tpcc.sh run

test-tpcc-k8s-limit:
	TIDB_HOST=$(TIDB_HOST_K8S) TIDB_PORT=$(TIDB_PORT_K8S) VARIANT=k8s-limit \
	  $(TPCC_ENV) bash tests/common/tpcc.sh run

## YugabyteDB TPC-C (BenchmarkSQL)
tpcc-cleanup-yuga-vm:
	YUGA_HOST=$(YUGA_HOST_VM) YUGA_PORT=$(YUGA_PORT_VM) VARIANT=yuga-vm \
	  $(YUGA_TPCC_ENV) bash tests/common/yuga-tpcc.sh cleanup

tpcc-cleanup-yuga-k8s:
	YUGA_HOST=$(YUGA_HOST_K8S) YUGA_PORT=$(YUGA_PORT_K8S) VARIANT=yuga-k8s \
	  $(YUGA_TPCC_ENV) bash tests/common/yuga-tpcc.sh cleanup

tpcc-prepare-yuga-vm:
	YUGA_HOST=$(YUGA_HOST_VM) YUGA_PORT=$(YUGA_PORT_VM) VARIANT=yuga-vm \
	  $(YUGA_TPCC_ENV) bash tests/common/yuga-tpcc.sh prepare

tpcc-prepare-yuga-k8s:
	YUGA_HOST=$(YUGA_HOST_K8S) YUGA_PORT=$(YUGA_PORT_K8S) VARIANT=yuga-k8s \
	  $(YUGA_TPCC_ENV) bash tests/common/yuga-tpcc.sh prepare

test-tpcc-yuga-vm:
	YUGA_HOST=$(YUGA_HOST_VM) YUGA_PORT=$(YUGA_PORT_VM) VARIANT=yuga-vm \
	  $(YUGA_TPCC_ENV) bash tests/common/yuga-tpcc.sh run

test-tpcc-yuga-k8s:
	YUGA_HOST=$(YUGA_HOST_K8S) YUGA_PORT=$(YUGA_PORT_K8S) VARIANT=yuga-k8s \
	  $(YUGA_TPCC_ENV) bash tests/common/yuga-tpcc.sh run

test-tpcc-yuga-k8s-limit:
	YUGA_HOST=$(YUGA_HOST_K8S) YUGA_PORT=$(YUGA_PORT_K8S) VARIANT=yuga-k8s-limit \
	  $(YUGA_TPCC_ENV) bash tests/common/yuga-tpcc.sh run

tpcc-report:
	@latest=$$(ls -td $(RESULT_BASE)/$(TOPO)/$(SCENARIO)/$(VARIANT)/*/ 2>/dev/null | head -1); \
	  if [[ -z "$$latest" ]]; then echo "No results found in $(RESULT_BASE)/$(TOPO)/$(SCENARIO)/$(VARIANT)/"; exit 1; fi; \
	  bash tests/common/report.sh "$$latest"
