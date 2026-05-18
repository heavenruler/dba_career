IDC_IAC_DIR := iac-idc
GCP_IAC_DIR := iac-gcp
ANSIBLE_DIR := ansible
INVENTORY   := $(ANSIBLE_DIR)/inventory/hosts.ini

IDC_ADMIN := 172.24.40.31
IDC_NODES := 172.24.40.32 172.24.40.33 172.24.40.34
IDC_KNOWN := $(IDC_ADMIN) $(IDC_NODES)

GCP_PORTS := 12211 12212 12213 12214

# === TPC-C client / DB endpoint (vm-1node SSOT §11.2) ===
TPCC_CLIENT       := root@172.24.40.31
TPCC_BASE         := /tmp/poc-tpcc
TPCC_ARTIFACTS    := $(TPCC_BASE)/artifacts
TPCC_SCRIPTS      := $(TPCC_BASE)/scripts
LOCAL_SCRIPTS     := tests/common
LOCAL_RESULTS     := results

# vm-1node 都跑在 172.24.40.32
TIDB_HOST         := 172.24.40.32
TIDB_PORT         := 4000
TIDB_USER         := root
TIDB_DB           := tpcc

CRDB_HOST         := 172.24.40.32
CRDB_PORT         := 26257
CRDB_USER         := root
CRDB_DB           := tpcc

YBDB_HOST         := 172.24.40.32
YBDB_PORT         := 5433
YBDB_USER         := yugabyte
YBDB_DB           := tpcc

# go-tpc parameters
GOTPC_VERSION     := v1.0.12
WAREHOUSES        := 128
THREADS_LIST      := 16 32 64 128
ROUNDS            := 5
WARMUP_SEC        := 1200
RUN_SEC           := 300
ROUND_SLEEP_SEC   := 60

# Generate a single timestamp per make-invocation (so all phases of one run share it)
TPCC_TS           := $(shell date '+%Y%m%dT%H%M%S%z')

.PHONY: help \
        new-vms new-idc-vms new-gcp-vms \
        drop-vms drop-idc-vms drop-gcp-vms \
        inventory-refresh gcp-inventory-refresh inventory-refresh-all \
        gcp-tunnel-start gcp-tunnel-stop gcp-tunnel-ensure gcp-wait-startup \
        ansible-ping ansible-setup \
        bootstrap-tpcc-client clean-tpcc-artifacts \
        $(foreach db,tidb crdb ybdb,\
          $(foreach iso,rc rr strict,\
            deploy-vm1-$(db) gate-vm1-$(db)-$(iso) \
            prepare-vm1-$(db)-$(iso) run-vm1-$(db)-$(iso) \
            collect-vm1-$(db)-$(iso) fetch-vm1-$(db)-$(iso) \
            test-tpcc-vm1-$(db)-$(iso))) \
        $(foreach iso,rc rr strict,gate-vm1-all-$(iso) test-tpcc-vm1-all-$(iso))

.DEFAULT_GOAL := help

help:
	@echo "=== VM Lifecycle ==="
	@echo "  make new-vms                 - 並行建立 IDC + GCP 全部 VM"
	@echo "  make new-idc-vms             - destroy → apply iac-idc (l-test-poc-1/2/3, 172.24.40.32-34) + 清 known_hosts (Mac + .31)"
	@echo "  make new-gcp-vms             - destroy → apply iac-gcp (g-test-poc-1/2/3/4, 10.160.152.11-14, zone a/b/c/a, AlmaLinux 8) + 清 known_hosts"
	@echo "  make drop-vms                - 並行銷毀 IDC + GCP 全部 VM"
	@echo "  make drop-idc-vms            - terraform destroy iac-idc"
	@echo "  make drop-gcp-vms            - terraform destroy iac-gcp"
	@echo ""
	@echo "=== Inventory ==="
	@echo "  make inventory-refresh       - 從 iac-idc 重建 [poc_db] 段 (python3.12)"
	@echo "  make gcp-inventory-refresh   - 從 iac-gcp 追加 [gcp_poc] 段 (port 12211/12212/12213/12214)"
	@echo "  make inventory-refresh-all   - inventory-refresh + gcp-inventory-refresh"
	@echo ""
	@echo "=== GCP IAP Tunnel ==="
	@echo "  make gcp-tunnel-start        - (先 stop 再) 啟動 IAP tunnel (poc-1:12211, poc-2:12212, poc-3:12213, poc-4:12214)"
	@echo "  make gcp-tunnel-stop         - 關閉 IAP tunnel"
	@echo "  make gcp-tunnel-ensure       - 若未啟動則啟動"
	@echo "  make gcp-wait-startup        - gcp-tunnel-start + 等 4 台 GCP VM 的 startup-script 完成 (touch /var/lib/startup-done)"
	@echo ""
	@echo "=== Ansible ==="
	@echo "  make ansible-ping            - inventory-refresh-all + tunnel-ensure + ansible all -m ping"
	@echo "  make ansible-setup           - gcp-wait-startup + site.yml + tpcc-client-ssh.yml"
	@echo ""
	@echo "=== TPC-C vm-1node Phase chain (依 PoC-DESIGN.md §8 / §11) ==="
	@echo "  一鍵 e2e:"
	@echo "    make test-tpcc-vm1-<db>-<iso>  - deploy → gate → prepare → run → collect → fetch"
	@echo "    make test-tpcc-vm1-all-<iso>   - 三家 (tidb/crdb/ybdb) 依序跑同 iso"
	@echo "  細分 phase (可單獨重跑;  TPCC_TS=<ts> 變數帶入同組 timestamp):"
	@echo "    make bootstrap-tpcc-client   - rsync tests/common/ to .31:/tmp/poc-tpcc/scripts/"
	@echo "    make deploy-vm1-<db>         - Ansible 部署 DB cluster (tidb/crdb/ybdb)"
	@echo "    make gate-vm1-<db>-<iso>     - OS / chrony / disk gate on DB host"
	@echo "    make prepare-vm1-<db>-<iso>  - DROP+CREATE + go-tpc prepare 128W + ANALYZE + EXPLAIN"
	@echo "    make run-vm1-<db>-<iso>      - cold-reset + warmup 20m + 5 round × 5 min × 4 threads"
	@echo "    make collect-vm1-<db>-<iso>  - DB log tail + db-config dump + env snapshot"
	@echo "    make fetch-vm1-<db>-<iso>    - rsync .31 → MAC results/ + 清 .31"
	@echo "    make clean-tpcc-artifacts    - 清 .31:/tmp/poc-tpcc/artifacts/*"
	@echo "  變數: db=tidb|crdb|ybdb, iso=rc|rr|strict, TPCC_TS=<ISO-8601>"

## Build
new-vms:
	$(MAKE) -j2 new-idc-vms new-gcp-vms
	@echo "==> All VMs created (IDC + GCP)"

new-idc-vms: drop-idc-vms
	cd $(IDC_IAC_DIR) && terraform apply -auto-approve
	for ip in $(IDC_KNOWN); do ssh-keygen -R $$ip || true; done
	ssh -o StrictHostKeyChecking=accept-new root@$(IDC_ADMIN) \
	  'for ip in $(IDC_NODES); do ssh-keygen -R $$ip; done'
	@echo "==> expanding root partition on IDC nodes (sda3 → 100G)"
	@for ip in $(IDC_NODES); do \
	  echo "  -> $$ip"; \
	  ssh -o StrictHostKeyChecking=accept-new root@$$ip \
	    'dnf install -y -q cloud-utils-growpart && growpart /dev/sda 3 && xfs_growfs / && df -h /'; \
	done

new-gcp-vms: drop-gcp-vms
	cd $(GCP_IAC_DIR) && terraform apply -auto-approve
	for port in $(GCP_PORTS); do ssh-keygen -R "[localhost]:$$port" || true; done

## Drop
drop-vms:
	$(MAKE) -j2 drop-idc-vms drop-gcp-vms
	@echo "==> All VMs destroyed (IDC + GCP)"

drop-idc-vms:
	cd $(IDC_IAC_DIR) && terraform destroy -auto-approve

drop-gcp-vms:
	cd $(GCP_IAC_DIR) && terraform destroy -auto-approve

## Inventory
inventory-refresh:
	cd $(IDC_IAC_DIR) && terraform output -json vm_ips | \
	  jq -r '"[poc_db]", (to_entries[] | .value + " ansible_hostname=" + .key + " ansible_python_interpreter=/usr/bin/python3.12")' \
	  > ../$(INVENTORY)
	@echo "==> $(INVENTORY) updated"
	@cat $(INVENTORY)

gcp-inventory-refresh:
	cd $(GCP_IAC_DIR) && terraform output -json host_ip_mapping | \
	  jq -r '"[gcp_poc]", (to_entries[] | .key + " ansible_host=localhost ansible_port=" + (if .key == "g-test-poc-1" then "12211" elif .key == "g-test-poc-2" then "12212" elif .key == "g-test-poc-3" then "12213" else "12214" end) + " ansible_hostname=" + .key + " ansible_python_interpreter=/usr/bin/python3.12")' \
	  >> ../$(INVENTORY)
	@echo "==> GCP section appended to $(INVENTORY)"

inventory-refresh-all: inventory-refresh gcp-inventory-refresh
	@echo "==> Final inventory:"
	@cat $(INVENTORY)

## GCP IAP Tunnel
gcp-tunnel-start:
	@$(GCP_IAC_DIR)/tunnel.sh stop 2>/dev/null || true
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

## 等 4 台 GCP VM 的 startup-script 完成 (避免與 ansible dnf 撞)
gcp-wait-startup: gcp-tunnel-start
	@for p in $(GCP_PORTS); do \
	  echo "==> waiting startup-done on :$$p"; \
	  ssh -o StrictHostKeyChecking=accept-new -p $$p root@localhost \
	    'until [ -f /var/lib/startup-done ]; do sleep 5; done; echo done'; \
	done

## Ansible
ansible-ping: inventory-refresh-all gcp-tunnel-ensure
	cd $(ANSIBLE_DIR) && ansible all -m ping

ansible-setup: gcp-wait-startup
	cd $(ANSIBLE_DIR) && ansible-playbook playbooks/site.yml
	cd $(ANSIBLE_DIR) && ansible-playbook playbooks/tpcc-client-ssh.yml \
	  -i inventory/hosts.ini \
	  -i inventory/tpcc-client.ini

# ====================================================================
# vm-1node PoC Phase targets (Step 1 skeleton)
# Per results/PoC-DESIGN.md v4.3 — §8.1 phase chain, §11 naming
# ====================================================================

# ---- one-time client setup ----
bootstrap-tpcc-client:
	TPCC_CLIENT=$(TPCC_CLIENT) TPCC_BASE=$(TPCC_BASE) GOTPC_VERSION=$(GOTPC_VERSION) \
	  bash $(LOCAL_SCRIPTS)/bootstrap-client.sh

clean-tpcc-artifacts:
	@echo "==> wiping $(TPCC_CLIENT):$(TPCC_ARTIFACTS)/*"
	ssh $(TPCC_CLIENT) "rm -rf $(TPCC_ARTIFACTS)/*" && \
	  echo "==> done"

# ---- per-db host lookup helper ----
# define how each DB host is resolved (Makefile macro)
define DB_HOST
$(if $(filter tidb,$(1)),$(TIDB_HOST),\
$(if $(filter crdb,$(1)),$(CRDB_HOST),\
$(if $(filter ybdb,$(1)),$(YBDB_HOST),)))
endef

# ---- gate phase (Step 1: OS / chrony / disk; isolation gate after prepare) ----
# pattern target: gate-vm1-<db>-<iso>
$(foreach db,tidb crdb ybdb,$(foreach iso,rc rr strict,gate-vm1-$(db)-$(iso))):
	$(eval DB := $(word 3,$(subst -, ,$@)))
	$(eval ISO := $(word 4,$(subst -, ,$@)))
	$(eval HOST := $(strip $(call DB_HOST,$(DB))))
	@echo "==> gate-vm1-$(DB)-$(ISO) host=$(HOST) ts=$(TPCC_TS)"
	ssh $(TPCC_CLIENT) "TPCC_ARTIFACTS=$(TPCC_ARTIFACTS) bash $(TPCC_SCRIPTS)/gate.sh \
	  --db $(DB) --iso $(ISO) --db-host $(HOST) --ts $(TPCC_TS)"

gate-vm1-all-rc:     gate-vm1-tidb-rc gate-vm1-crdb-rc gate-vm1-ybdb-rc
gate-vm1-all-rr:     gate-vm1-tidb-rr gate-vm1-crdb-rr gate-vm1-ybdb-rr
gate-vm1-all-strict: gate-vm1-tidb-strict gate-vm1-crdb-strict gate-vm1-ybdb-strict

# ---- phase 1: deploy (Ansible) - per DB ----
deploy-vm1-tidb:
	cd $(ANSIBLE_DIR) && ansible-playbook -i inventory/vm1.ini playbooks/tidb-vm1.yml
deploy-vm1-crdb:
	cd $(ANSIBLE_DIR) && ansible-playbook -i inventory/vm1.ini playbooks/cockroach-vm1.yml
deploy-vm1-ybdb:
	cd $(ANSIBLE_DIR) && ansible-playbook -i inventory/vm1.ini playbooks/yugabyte-vm1.yml

# ---- env injection for prepare/run/collect (pass to ssh) ----
TPCC_ENV = \
  TPCC_ARTIFACTS=$(TPCC_ARTIFACTS) \
  WAREHOUSES=$(WAREHOUSES) \
  THREADS_LIST='$(THREADS_LIST)' \
  ROUNDS=$(ROUNDS) WARMUP_SEC=$(WARMUP_SEC) RUN_SEC=$(RUN_SEC) ROUND_SLEEP_SEC=$(ROUND_SLEEP_SEC) \
  TIDB_PORT=$(TIDB_PORT) TIDB_USER=$(TIDB_USER) TIDB_DB=$(TIDB_DB) \
  CRDB_PORT=$(CRDB_PORT) CRDB_USER=$(CRDB_USER) CRDB_DB=$(CRDB_DB) \
  YBDB_PORT=$(YBDB_PORT) YBDB_USER=$(YBDB_USER) YBDB_DB=$(YBDB_DB)

# ---- phase 4: prepare (DROP+CREATE + go-tpc prepare + check + ANALYZE + EXPLAIN) ----
$(foreach db,tidb crdb ybdb,$(foreach iso,rc rr strict,prepare-vm1-$(db)-$(iso))):
	$(eval DB := $(word 3,$(subst -, ,$@)))
	$(eval ISO := $(word 4,$(subst -, ,$@)))
	$(eval HOST := $(strip $(call DB_HOST,$(DB))))
	@echo "==> prepare-vm1-$(DB)-$(ISO) host=$(HOST) ts=$(TPCC_TS)"
	ssh $(TPCC_CLIENT) "$(TPCC_ENV) bash $(TPCC_SCRIPTS)/prepare.sh \
	  --db $(DB) --iso $(ISO) --topology vm-1node --db-host $(HOST) --ts $(TPCC_TS)"

# ---- phase 5: run (cold-reset + isolation gate + warmup + 5 round × 4 threads) ----
$(foreach db,tidb crdb ybdb,$(foreach iso,rc rr strict,run-vm1-$(db)-$(iso))):
	$(eval DB := $(word 3,$(subst -, ,$@)))
	$(eval ISO := $(word 4,$(subst -, ,$@)))
	$(eval HOST := $(strip $(call DB_HOST,$(DB))))
	@echo "==> run-vm1-$(DB)-$(ISO) host=$(HOST) ts=$(TPCC_TS)"
	ssh $(TPCC_CLIENT) "$(TPCC_ENV) bash $(TPCC_SCRIPTS)/run.sh \
	  --db $(DB) --iso $(ISO) --topology vm-1node --db-host $(HOST) --ts $(TPCC_TS)"

# ---- phase 6: collect (DB log + db-config dump + env snapshot) ----
$(foreach db,tidb crdb ybdb,$(foreach iso,rc rr strict,collect-vm1-$(db)-$(iso))):
	$(eval DB := $(word 3,$(subst -, ,$@)))
	$(eval ISO := $(word 4,$(subst -, ,$@)))
	$(eval HOST := $(strip $(call DB_HOST,$(DB))))
	@echo "==> collect-vm1-$(DB)-$(ISO) host=$(HOST) ts=$(TPCC_TS)"
	ssh $(TPCC_CLIENT) "$(TPCC_ENV) bash $(TPCC_SCRIPTS)/collect.sh \
	  --db $(DB) --iso $(ISO) --topology vm-1node --db-host $(HOST) --ts $(TPCC_TS)"

# ---- phase 7: fetch (rsync .31 → MAC, clean .31) ----
$(foreach db,tidb crdb ybdb,$(foreach iso,rc rr strict,fetch-vm1-$(db)-$(iso))):
	$(eval DB := $(word 3,$(subst -, ,$@)))
	$(eval ISO := $(word 4,$(subst -, ,$@)))
	@echo "==> fetch-vm1-$(DB)-$(ISO)"
	mkdir -p $(LOCAL_RESULTS)/$(DB)-tc1/S-BASE/vm-1node-$(ISO)/
	rsync -avz --remove-source-files \
	  '$(TPCC_CLIENT):$(TPCC_ARTIFACTS)/$(DB)-vm-1node-$(ISO)-*' \
	  $(LOCAL_RESULTS)/$(DB)-tc1/S-BASE/vm-1node-$(ISO)/
	ssh $(TPCC_CLIENT) 'find $(TPCC_ARTIFACTS) -maxdepth 1 -type d -empty -delete' || true

# ---- one-button e2e per <db>-<iso> ----
$(foreach db,tidb crdb ybdb,$(foreach iso,rc rr strict,test-tpcc-vm1-$(db)-$(iso))):
	$(eval DB := $(word 4,$(subst -, ,$@)))
	$(eval ISO := $(word 5,$(subst -, ,$@)))
	$(MAKE) deploy-vm1-$(DB)
	$(MAKE) gate-vm1-$(DB)-$(ISO)        TPCC_TS=$(TPCC_TS)
	$(MAKE) prepare-vm1-$(DB)-$(ISO)     TPCC_TS=$(TPCC_TS)
	$(MAKE) run-vm1-$(DB)-$(ISO)         TPCC_TS=$(TPCC_TS)
	$(MAKE) collect-vm1-$(DB)-$(ISO)     TPCC_TS=$(TPCC_TS)
	$(MAKE) fetch-vm1-$(DB)-$(ISO)       TPCC_TS=$(TPCC_TS)
	@echo "==> test-tpcc-vm1-$(DB)-$(ISO) complete; ts=$(TPCC_TS)"

# ---- batch: 3 DB × 1 iso ----
test-tpcc-vm1-all-rc:     test-tpcc-vm1-tidb-rc     test-tpcc-vm1-crdb-rc     test-tpcc-vm1-ybdb-rc
test-tpcc-vm1-all-rr:     test-tpcc-vm1-tidb-rr     test-tpcc-vm1-crdb-rr     test-tpcc-vm1-ybdb-rr
test-tpcc-vm1-all-strict: test-tpcc-vm1-tidb-strict test-tpcc-vm1-crdb-strict test-tpcc-vm1-ybdb-strict
