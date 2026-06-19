IDC_IAC_DIR := iac-idc
GCP_IAC_DIR := iac-gcp
ANSIBLE_DIR := ansible
INVENTORY   := $(ANSIBLE_DIR)/inventory/hosts.ini

IDC_ADMIN := 172.24.40.31
IDC_NODES := 172.24.40.32 172.24.40.33 172.24.40.34
IDC_KNOWN := $(IDC_ADMIN) $(IDC_NODES)

GCP_PORTS := 12211 12212 12213 12214 12215

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
            test-tpcc-vm1-$(db)-$(iso) \
            vm1-$(db)-$(iso) status-vm1-$(db)-$(iso))) \
        $(foreach iso,rc rr strict,gate-vm1-all-$(iso) test-tpcc-vm1-all-$(iso))

.DEFAULT_GOAL := help

help:
	@echo "=== VM Lifecycle ==="
	@echo "  make new-vms                 - 並行建立 IDC + GCP 全部 VM"
	@echo "  make new-idc-vms             - destroy → apply iac-idc (l-test-poc-1/2/3, 172.24.40.32-34) + 清 known_hosts (Mac + .31)"
	@echo "  make new-gcp-vms             - destroy → apply iac-gcp (g-test-poc-1/2/3/4/5, 10.160.152.11-15, zone a/b/c/a/a, AlmaLinux 8; per phase-crossregion decisions Q1: 3 db + 1 haproxy + 1 client) + 清 known_hosts"
	@echo "  make drop-vms                - 並行銷毀 IDC + GCP 全部 VM"
	@echo "  make drop-idc-vms            - terraform destroy iac-idc"
	@echo "  make drop-gcp-vms            - terraform destroy iac-gcp"
	@echo ""
	@echo "=== Inventory ==="
	@echo "  make inventory-refresh       - 從 iac-idc 重建 [poc_db] 段 (python3.12)"
	@echo "  make gcp-inventory-refresh   - 從 iac-gcp 追加 [gcp_poc] 段 (port 12211/12212/12213/12214/12215)"
	@echo "  make inventory-refresh-all   - inventory-refresh + gcp-inventory-refresh"
	@echo ""
	@echo "=== GCP IAP Tunnel ==="
	@echo "  make gcp-tunnel-start        - (先 stop 再) 啟動 IAP tunnel (poc-1:12211, poc-2:12212, poc-3:12213, poc-4:12214, poc-5:12215)"
	@echo "  make gcp-tunnel-stop         - 關閉 IAP tunnel"
	@echo "  make gcp-tunnel-ensure       - 若未啟動則啟動"
	@echo "  make gcp-wait-startup        - gcp-tunnel-start + 等 5 台 GCP VM 的 startup-script 完成 (touch /var/lib/startup-done)"
	@echo ""
	@echo "=== Ansible ==="
	@echo "  make ansible-ping            - inventory-refresh-all + tunnel-ensure + ansible all -m ping"
	@echo "  make ansible-setup           - gcp-wait-startup + site.yml + tpcc-client-ssh.yml"
	@echo ""
	@echo "=== TPC-C vm-1node Phase chain (依 PoC-DESIGN.md §8 / §11) ==="
	@echo "  MAC 下發 + .31 背景執行 (推薦; MAC session 中斷不影響 benchmark):"
	@echo "    make vm1-<db>-<iso>            - new-idc-vms + bootstrap + deploy + 遠端 detached suite"
	@echo "                                     gate/prepare/run/collect 全部 .31 跑,固定同一 TPCC_TS"
	@echo "    make status-vm1-<db>-<iso>     - 查 lock / artifact markers / log tail (read-only)"
	@echo "    範例: make vm1-tidb-rc -> 完成後 make fetch-vm1-tidb-rc TPCC_TS=<ts>"
	@echo "  一鍵 e2e (MAC foreground 監看; 不建議長時間使用):"
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
	@echo ""
	@echo "=== TPC-C vm-3node Phase chain (PoC-DESIGN §6.3.2; 12 cells × RC) ==="
	@echo "  make vm3-<db>-<sub>-rc                - destroy-all + deploy + dry-run anchor (預設停在 deploy 後)"
	@echo "    EXECUTE=1: + gate → prepare → run → collect (fetch 手動)"
	@echo "  make destroy-vm3-all                  - 清三家殘留（換 sub_topology / 換 DB 前都會自動跑）"
	@echo "  make vm3-all-dry                      - 12 cells 全跑到 dry-run anchor"
	@echo "  make deploy-vm3-<db>-<sub>            - 只跑 Ansible deploy"
	@echo "  make dryrun-vm3-<db>-<sub>-rc         - 只跑 dry-run-confirm (deploy 完才能跑)"
	@echo "  make status-vm3-<db>-<sub>-rc         - 看 dry-run 結果 + lock/marker"
	@echo "  make fetch-vm3-<db>-<sub>-rc TPCC_TS=<ts>"
	@echo "  變數: db=tidb|crdb|ybdb, sub=1s1r|1s3r|3s1r|3s3r"
	@echo ""
	@echo "=== Phase-K8s (K8s 對照組 / v4.7 detached suite / RC only / family=k8s; 詳 phase-k8s/README.md) ==="
	@echo "  make phase-k8s-plan          - 印出 phase scope / topology / 缺項 (read-only)"
	@echo "  make phase-k8s-deploy        - 三家 ansible-playbook *-k8s.yml (current 既有路徑)"
	@echo "  make phase-k8s-run           - 待補；v4.7 K8s wrapper 尚未實作 (exit 1)"
	@echo ""
	@echo "=== Phase-ThreadControl (process/thread/admission tuning 隔離 / family=tuning / baseline_eligible=false) ==="
	@echo "  make phase-threadcontrol-plan   - 印出 phase scope / 三家可調參數 / guardrail 規則 (read-only)"
	@echo "  make phase-threadcontrol-verify - 驗 manifest.yaml + 三層 hard gate 設定 (不跑 benchmark)"
	@echo ""
	@echo "=== Phase-CrossRegion (IDC↔GCP / family=crossregion / baseline_eligible=false; 詳 phase-crossregion/README.md) ==="
	@echo "  make phase-crossregion-plan   - 印出 placement × workload 矩陣 / chaos plan / WAN baseline 任務 (read-only)"
	@echo "  make phase-crossregion-deploy - 6-node ansible playbook (待 Pre-P0 完成；目前 exit 1)"
	@echo "  make phase-crossregion-run    - 跨區 runtime；本輪 spec-only (exit 1)"
	@echo "  make phase-crossregion-chaos-plan / -deploy / -run - chaos 4 場景 (lab mode; 本輪 plan only)"

## Build
new-vms:
	$(MAKE) -j2 new-idc-vms new-gcp-vms
	@echo "==> All VMs created (IDC + GCP)"

new-idc-vms: drop-idc-vms
	cd $(IDC_IAC_DIR) && terraform apply -auto-approve
	for ip in $(IDC_KNOWN); do ssh-keygen -R $$ip || true; done
	ssh -o StrictHostKeyChecking=accept-new root@$(IDC_ADMIN) \
	  'for ip in $(IDC_NODES); do ssh-keygen -R $$ip; done'
	@echo "==> warming dnf metadata cache on IDC nodes (parallel)"
	@pids=""; for ip in $(IDC_NODES); do \
	  ( ssh -o StrictHostKeyChecking=accept-new root@$$ip 'dnf -q makecache' \
	      && echo "  -> $$ip cache ok" \
	      || { echo "  -> $$ip cache FAIL"; exit 1; } ) & \
	  pids="$$pids $$!"; \
	done; fail=0; for p in $$pids; do wait $$p || fail=1; done; test $$fail -eq 0
	@echo "==> expanding root partition on IDC nodes (sda3 → 100G; parallel)"
	@pids=""; for ip in $(IDC_NODES); do \
	  ( ssh -o StrictHostKeyChecking=accept-new root@$$ip \
	      'dnf install -y -q cloud-utils-growpart && growpart /dev/sda 3 && xfs_growfs / && df -h /' \
	      && echo "  -> $$ip growpart ok" \
	      || { echo "  -> $$ip growpart FAIL"; exit 1; } ) & \
	  pids="$$pids $$!"; \
	done; fail=0; for p in $$pids; do wait $$p || fail=1; done; test $$fail -eq 0

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
	  jq -r '"[gcp_poc]", (to_entries[] | .key + " ansible_host=localhost ansible_port=" + (if .key == "g-test-poc-1" then "12211" elif .key == "g-test-poc-2" then "12212" elif .key == "g-test-poc-3" then "12213" elif .key == "g-test-poc-4" then "12214" elif .key == "g-test-poc-5" then "12215" else "0" end) + " ansible_hostname=" + .key + " ansible_python_interpreter=/usr/bin/python3.12")' \
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

## 等 5 台 GCP VM 的 startup-script 完成 (避免與 ansible dnf 撞)
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

# ---- per-db result directory mapping ----
# Most DBs use <db>-tc1; YugabyteDB is shipped under yuga-tc1/ to keep the
# project-wide "yuga-*" directory convention (also used by ansible/vars/,
# tests/prepare/, tests/run-all/). Mapping isolates the dir name from the
# DB-code argument used in target names.
define DB_RESULT_DIR
$(if $(filter tidb,$(1)),tidb-tc1,\
$(if $(filter crdb,$(1)),crdb-tc1,\
$(if $(filter ybdb,$(1)),yuga-tc1,)))
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
  TPCC_BASE=$(TPCC_BASE) \
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
	$(eval RESULT_DIR := $(strip $(call DB_RESULT_DIR,$(DB))))
	$(eval FETCH_SRC := $(if $(filter command line,$(origin TPCC_TS)),$(TPCC_ARTIFACTS)/$(DB)-vm-1node-$(ISO)-$(TPCC_TS),$(TPCC_ARTIFACTS)/$(DB)-vm-1node-$(ISO)-*))
	@echo "==> fetch-vm1-$(DB)-$(ISO) src=$(FETCH_SRC) dest=$(RESULT_DIR)"
	mkdir -p $(LOCAL_RESULTS)/$(RESULT_DIR)/S-BASE/vm-1node-$(ISO)/
	rsync -avz --remove-source-files \
	  '$(TPCC_CLIENT):$(FETCH_SRC)' \
	  $(LOCAL_RESULTS)/$(RESULT_DIR)/S-BASE/vm-1node-$(ISO)/
	ssh $(TPCC_CLIENT) 'find $(TPCC_ARTIFACTS) -depth -type d -empty -delete' || true

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

# ====================================================================
# vm1-<db>-<iso> — MAC dispatches, .31 runs detached
#   1. new-idc-vms  (MAC)
#   2. bootstrap-tpcc-client (MAC → .31 rsync)
#   3. deploy-vm1-<db> (Ansible)
#   4. launch-vm1-suite.sh on .31 (nohup setsid; MAC ssh returns)
# Fetch is intentionally NOT included (MAC may not be reachable from .31).
# After collect completes (verify with status-vm1-<db>-<iso>), run:
#   make fetch-vm1-<db>-<iso> TPCC_TS=<ts>
# ====================================================================
$(foreach db,tidb crdb ybdb,$(foreach iso,rc rr strict,vm1-$(db)-$(iso))):
	$(eval DB := $(word 2,$(subst -, ,$@)))
	$(eval ISO := $(word 3,$(subst -, ,$@)))
	$(eval HOST := $(strip $(call DB_HOST,$(DB))))
	$(eval TS := $(TPCC_TS))
	@echo "==> $@: TPCC_TS=$(TS) host=$(HOST)"
	$(MAKE) new-idc-vms
	$(MAKE) bootstrap-tpcc-client
	$(MAKE) deploy-vm1-$(DB)
	@echo "==> launching remote suite on $(TPCC_CLIENT) (detached)"
	@ssh $(TPCC_CLIENT) "env $(TPCC_ENV) bash $(TPCC_SCRIPTS)/launch-vm1-suite.sh \
	  --db $(DB) --iso $(ISO) --topology vm-1node \
	  --db-host $(HOST) --ts $(TS)"
	@echo "==================================================================="
	@echo "  TPCC_TS:       $(TS)"
	@echo "  Status check:  make status-vm1-$(DB)-$(ISO)"
	@echo "  Tail log:      ssh $(TPCC_CLIENT) tail -f $(TPCC_BASE)/logs/$(DB)-vm-1node-$(ISO)-$(TS).log"
	@echo "  Fetch later:   make fetch-vm1-$(DB)-$(ISO) TPCC_TS=$(TS)"
	@echo "==================================================================="

# Read-only status (no side effects)
$(foreach db,tidb crdb ybdb,$(foreach iso,rc rr strict,status-vm1-$(db)-$(iso))):
	$(eval DB := $(word 3,$(subst -, ,$@)))
	$(eval ISO := $(word 4,$(subst -, ,$@)))
	@ssh $(TPCC_CLIENT) "bash $(TPCC_SCRIPTS)/status-vm1.sh \
	  --db $(DB) --topology vm-1node --iso $(ISO)"

# ====================================================================
# vm-3node — 12 cells (4 sub-topology × 3 DB), all RC iso
# Per PoC-DESIGN §6.3.2 (vm-3node 元件分配與 dry-run gate)
#
# Naming:
#   vm3-<db>-<sub>-rc         e2e (deploy → dry-run → [EXECUTE=1] → prepare→...→collect)
#   deploy-vm3-<db>-<sub>     Ansible deploy only
#   dryrun-vm3-<db>-<sub>-rc dry-run-confirm.sh (deploy 後 / prepare 前 anchor)
#   prepare-vm3-<db>-<sub>-rc go-tpc prepare + shard SPLIT + hard gate
#   gate-vm3-<db>-<sub>-rc    OS / chrony / disk gate
#   run-vm3-<db>-<sub>-rc     cold-reset + warmup + 5 round × 4 threads
#   collect-vm3-<db>-<sub>-rc artifacts collect
#   fetch-vm3-<db>-<sub>-rc   rsync .31 → MAC
#   status-vm3-<db>-<sub>-rc  read-only status
#
# <db> ∈ {tidb, crdb, ybdb}  <sub> ∈ {1s1r, 1s3r, 3s1r, 3s3r}
# ====================================================================

VM3_SUBS := 1s1r 1s3r 3s1r 3s3r

.PHONY: destroy-vm3-all $(foreach db,tidb crdb ybdb,$(foreach sub,$(VM3_SUBS),\
          deploy-vm3-$(db)-$(sub) \
          dryrun-vm3-$(db)-$(sub)-rc \
          prepare-vm3-$(db)-$(sub)-rc \
          gate-vm3-$(db)-$(sub)-rc \
          run-vm3-$(db)-$(sub)-rc \
          collect-vm3-$(db)-$(sub)-rc \
          fetch-vm3-$(db)-$(sub)-rc \
          status-vm3-$(db)-$(sub)-rc \
          vm3-$(db)-$(sub)-rc))

# ---- destroy-vm3-all : best-effort 清三家殘留（換 sub_topology / 換 DB 前都要跑）---
# 設計理由（2026-05-22 dispatch 實測）：
#   * TiDB:  tiup cluster destroy <name> --yes（cluster 不存在會 fail，故 guard）
#   * CRDB:  systemctl stop --background daemonize → 必須等 process 真死才 rm /data/crdb，
#            否則 .33/.34 帶舊 cluster ID join 出現 "client cluster ID doesn't match" 死循環
#   * YBDB:  yugabyted 是 python3 wrapper，用 pgrep -x 抓子進程 yb-master/yb-tserver，
#            wrapper 經 /proc/<pid>/cmdline 過濾 — 避免 pgrep -f 自殺
destroy-vm3-all:
	@echo "==> destroy-vm3-all (best-effort; switch sub_topology 或換 DB 前必跑)"
	@echo "--- TiDB: tiup cluster destroy ---"
	-cd $(ANSIBLE_DIR) && ansible -i inventory/vm3.ini vm3_primary -m shell -a \
	  '[ -d /root/.tiup/storage/cluster/clusters/tpcc-tidb-vm3 ] && \
	   /root/.tiup/bin/tiup cluster destroy tpcc-tidb-vm3 --yes 2>&1 | tail -3 || \
	   echo "no tidb cluster"' -b -o 2>&1 | tail -5
	@echo "--- CRDB: stop service + wait inactive + rm data ---"
	cd $(ANSIBLE_DIR) && ansible -i inventory/vm3.ini vm3_db -m shell -a \
	  'systemctl stop cockroach.service 2>/dev/null; \
	   for i in $$(seq 1 15); do pgrep -x cockroach >/dev/null || break; sleep 1; done; \
	   pkill -9 -x cockroach 2>/dev/null; sleep 2; \
	   rm -f /etc/systemd/system/cockroach.service; systemctl daemon-reload; \
	   rm -rf /data/crdb 2>/dev/null; echo crdb_clean' -b -o 2>&1 | tail -5
	@echo "--- YugabyteDB: kill yb procs (exact-name) + rm /var/yugabyte ---"
	cd $(ANSIBLE_DIR) && ansible -i inventory/vm3.ini vm3_db -m shell -a \
	  'pkill -KILL -x yb-master 2>/dev/null; \
	   pkill -KILL -x yb-tserver 2>/dev/null; \
	   pkill -KILL -x yugabyted-ui 2>/dev/null; \
	   for pid in $$(pgrep -x python3 2>/dev/null); do \
	     cmd=$$(tr "\0" " " < /proc/$$pid/cmdline 2>/dev/null); \
	     case "$$cmd" in *bin/yugabyted*) kill -KILL $$pid 2>/dev/null ;; esac; \
	   done; sleep 3; rm -rf /var/yugabyte 2>/dev/null; echo ybdb_clean' -b -o 2>&1 | tail -5
	@echo "--- HAProxy (.20): stop + remove config (N=2/N=3 重跑前清殘留) ---"
	-cd $(ANSIBLE_DIR) && ansible -i inventory/vm3.ini haproxy -m shell -a \
	  'systemctl stop haproxy 2>/dev/null; \
	   systemctl disable haproxy 2>/dev/null; \
	   rm -f /etc/haproxy/haproxy.cfg 2>/dev/null; \
	   echo haproxy_clean' -b -o 2>&1 | tail -5
	@echo "==> destroy-vm3-all complete"

# ---- deploy-vm3-<db>-<sub> : Ansible deploy with sub_topology var --
deploy-vm3-tidb-1s1r deploy-vm3-tidb-1s3r deploy-vm3-tidb-3s1r deploy-vm3-tidb-3s3r:
	$(eval SUB := $(word 4,$(subst -, ,$@)))
	@echo "==> deploy-vm3-tidb-$(SUB) (sub_topology=$(SUB))"
	cd $(ANSIBLE_DIR) && ansible-playbook -i inventory/vm3.ini playbooks/tidb-vm3.yml \
	  -e tidb_sub_topology=$(SUB)

deploy-vm3-crdb-1s1r deploy-vm3-crdb-1s3r deploy-vm3-crdb-3s1r deploy-vm3-crdb-3s3r:
	$(eval SUB := $(word 4,$(subst -, ,$@)))
	@echo "==> deploy-vm3-crdb-$(SUB) (sub_topology=$(SUB))"
	cd $(ANSIBLE_DIR) && ansible-playbook -i inventory/vm3.ini playbooks/cockroach-vm3.yml \
	  -e crdb_sub_topology=$(SUB)

deploy-vm3-ybdb-1s1r deploy-vm3-ybdb-1s3r deploy-vm3-ybdb-3s1r deploy-vm3-ybdb-3s3r:
	$(eval SUB := $(word 4,$(subst -, ,$@)))
	@echo "==> deploy-vm3-ybdb-$(SUB) (sub_topology=$(SUB))"
	cd $(ANSIBLE_DIR) && ansible-playbook -i inventory/vm3.ini playbooks/yugabyte-vm3.yml \
	  -e yb_sub_topology=$(SUB)

# ---- dryrun-vm3-<db>-<sub>-rc : deploy 後 / prepare 前 anchor ---
$(foreach db,tidb crdb ybdb,$(foreach sub,$(VM3_SUBS),dryrun-vm3-$(db)-$(sub)-rc)):
	$(eval DB := $(word 3,$(subst -, ,$@)))
	$(eval SUB := $(word 4,$(subst -, ,$@)))
	$(eval ISO := $(word 5,$(subst -, ,$@)))
	$(eval HOST := $(strip $(call DB_HOST,$(DB))))
	@echo "==> dryrun-vm3-$(DB)-$(SUB)-$(ISO) host=$(HOST) ts=$(TPCC_TS)"
	ssh $(TPCC_CLIENT) "$(TPCC_ENV) bash $(TPCC_SCRIPTS)/dry-run-confirm.sh \
	  --db $(DB) --sub-topology $(SUB) --iso $(ISO) --db-host $(HOST) --ts $(TPCC_TS)"

# ---- gate-vm3-<db>-<sub>-rc : OS / chrony / disk preflight (reuse gate.sh, topo=vm-3node-<sub>) ----
$(foreach db,tidb crdb ybdb,$(foreach sub,$(VM3_SUBS),gate-vm3-$(db)-$(sub)-rc)):
	$(eval DB := $(word 3,$(subst -, ,$@)))
	$(eval SUB := $(word 4,$(subst -, ,$@)))
	$(eval ISO := $(word 5,$(subst -, ,$@)))
	$(eval HOST := $(strip $(call DB_HOST,$(DB))))
	@echo "==> gate-vm3-$(DB)-$(SUB)-$(ISO) host=$(HOST) ts=$(TPCC_TS)"
	ssh $(TPCC_CLIENT) "$(TPCC_ENV) bash $(TPCC_SCRIPTS)/gate.sh \
	  --db $(DB) --iso $(ISO) --db-host $(HOST) --ts $(TPCC_TS)"

# ---- prepare-vm3-<db>-<sub>-rc : DROP+CREATE + prepare + shard SPLIT + hard gate ----
$(foreach db,tidb crdb ybdb,$(foreach sub,$(VM3_SUBS),prepare-vm3-$(db)-$(sub)-rc)):
	$(eval DB := $(word 3,$(subst -, ,$@)))
	$(eval SUB := $(word 4,$(subst -, ,$@)))
	$(eval ISO := $(word 5,$(subst -, ,$@)))
	$(eval HOST := $(strip $(call DB_HOST,$(DB))))
	@echo "==> prepare-vm3-$(DB)-$(SUB)-$(ISO) host=$(HOST) ts=$(TPCC_TS)"
	ssh $(TPCC_CLIENT) "$(TPCC_ENV) bash $(TPCC_SCRIPTS)/prepare.sh \
	  --db $(DB) --iso $(ISO) --topology vm-3node-$(SUB) --db-host $(HOST) --ts $(TPCC_TS)"

# ---- run-vm3-<db>-<sub>-rc : cold-reset + warmup + 5 round × 4 threads ----
$(foreach db,tidb crdb ybdb,$(foreach sub,$(VM3_SUBS),run-vm3-$(db)-$(sub)-rc)):
	$(eval DB := $(word 3,$(subst -, ,$@)))
	$(eval SUB := $(word 4,$(subst -, ,$@)))
	$(eval ISO := $(word 5,$(subst -, ,$@)))
	$(eval HOST := $(strip $(call DB_HOST,$(DB))))
	@echo "==> run-vm3-$(DB)-$(SUB)-$(ISO) host=$(HOST) ts=$(TPCC_TS)"
	ssh $(TPCC_CLIENT) "$(TPCC_ENV) bash $(TPCC_SCRIPTS)/run.sh \
	  --db $(DB) --iso $(ISO) --topology vm-3node-$(SUB) --db-host $(HOST) --ts $(TPCC_TS)"

# ---- collect-vm3-<db>-<sub>-rc ----
$(foreach db,tidb crdb ybdb,$(foreach sub,$(VM3_SUBS),collect-vm3-$(db)-$(sub)-rc)):
	$(eval DB := $(word 3,$(subst -, ,$@)))
	$(eval SUB := $(word 4,$(subst -, ,$@)))
	$(eval ISO := $(word 5,$(subst -, ,$@)))
	$(eval HOST := $(strip $(call DB_HOST,$(DB))))
	@echo "==> collect-vm3-$(DB)-$(SUB)-$(ISO) host=$(HOST) ts=$(TPCC_TS)"
	ssh $(TPCC_CLIENT) "$(TPCC_ENV) bash $(TPCC_SCRIPTS)/collect.sh \
	  --db $(DB) --iso $(ISO) --topology vm-3node-$(SUB) --db-host $(HOST) --ts $(TPCC_TS)"

# ---- fetch-vm3-<db>-<sub>-rc : rsync .31 → MAC ----
$(foreach db,tidb crdb ybdb,$(foreach sub,$(VM3_SUBS),fetch-vm3-$(db)-$(sub)-rc)):
	$(eval DB := $(word 3,$(subst -, ,$@)))
	$(eval SUB := $(word 4,$(subst -, ,$@)))
	$(eval ISO := $(word 5,$(subst -, ,$@)))
	$(eval RESULT_DIR := $(strip $(call DB_RESULT_DIR,$(DB))))
	$(eval FETCH_SRC := $(if $(filter command line,$(origin TPCC_TS)),$(TPCC_ARTIFACTS)/$(DB)-vm-3node-$(SUB)-$(ISO)-$(TPCC_TS),$(TPCC_ARTIFACTS)/$(DB)-vm-3node-$(SUB)-$(ISO)-*))
	@echo "==> fetch-vm3-$(DB)-$(SUB)-$(ISO) src=$(FETCH_SRC) dest=$(RESULT_DIR)/S-BASE/vm-3node-$(SUB)-$(ISO)/"
	mkdir -p $(LOCAL_RESULTS)/$(RESULT_DIR)/S-BASE/vm-3node-$(SUB)-$(ISO)/
	rsync -avz --remove-source-files \
	  '$(TPCC_CLIENT):$(FETCH_SRC)' \
	  $(LOCAL_RESULTS)/$(RESULT_DIR)/S-BASE/vm-3node-$(SUB)-$(ISO)/
	ssh $(TPCC_CLIENT) 'find $(TPCC_ARTIFACTS) -depth -type d -empty -delete' || true

# ---- fetch-vm3-<db>-haproxy-3s3r-rc (HAProxy variant；sub_topology 字串含中槓需 hardcode) ----
.PHONY: fetch-vm3-ybdb-haproxy-3s3r-rc fetch-vm3-tidb-haproxy-3s3r-rc fetch-vm3-crdb-haproxy-3s3r-rc
fetch-vm3-ybdb-haproxy-3s3r-rc fetch-vm3-tidb-haproxy-3s3r-rc fetch-vm3-crdb-haproxy-3s3r-rc:
	$(eval DB := $(word 3,$(subst -, ,$@)))
	$(eval RESULT_DIR := $(strip $(call DB_RESULT_DIR,$(DB))))
	$(eval FETCH_SRC := $(if $(filter command line,$(origin TPCC_TS)),$(TPCC_ARTIFACTS)/$(DB)-vm-3node-haproxy-3s3r-rc-$(TPCC_TS),$(TPCC_ARTIFACTS)/$(DB)-vm-3node-haproxy-3s3r-rc-*))
	@echo "==> fetch-vm3-$(DB)-haproxy-3s3r-rc src=$(FETCH_SRC) dest=$(RESULT_DIR)/S-BASE/vm-3node-haproxy-3s3r-rc/"
	mkdir -p $(LOCAL_RESULTS)/$(RESULT_DIR)/S-BASE/vm-3node-haproxy-3s3r-rc/
	rsync -avz --remove-source-files \
	  '$(TPCC_CLIENT):$(FETCH_SRC)' \
	  $(LOCAL_RESULTS)/$(RESULT_DIR)/S-BASE/vm-3node-haproxy-3s3r-rc/
	ssh $(TPCC_CLIENT) 'find $(TPCC_ARTIFACTS) -depth -type d -empty -delete' || true

# ---- status-vm3-<db>-<sub>-rc ----
$(foreach db,tidb crdb ybdb,$(foreach sub,$(VM3_SUBS),status-vm3-$(db)-$(sub)-rc)):
	$(eval DB := $(word 3,$(subst -, ,$@)))
	$(eval SUB := $(word 4,$(subst -, ,$@)))
	$(eval ISO := $(word 5,$(subst -, ,$@)))
	@ssh $(TPCC_CLIENT) "bash $(TPCC_SCRIPTS)/status-vm1.sh \
	  --db $(DB) --topology vm-3node-$(SUB) --iso $(ISO)" || true
	@echo "==> dry-run artifacts: $(TPCC_ARTIFACTS)/$(DB)-vm-3node-$(SUB)-$(ISO)-*/dry-run/"
	@ssh $(TPCC_CLIENT) "ls -la $(TPCC_ARTIFACTS)/$(DB)-vm-3node-$(SUB)-$(ISO)-*/dry-run/ 2>/dev/null | tail -20" || true

# ---- status-vm3-<db>-haproxy-3s3r-rc (HAProxy variant；只支援 status，dispatch 手動) ----
# haproxy-3s3r 含中槓會破壞 $(word N,$(subst -, ,$@)) 解析；故獨立 stanza 不走 foreach。
.PHONY: status-vm3-ybdb-haproxy-3s3r-rc status-vm3-tidb-haproxy-3s3r-rc status-vm3-crdb-haproxy-3s3r-rc
status-vm3-ybdb-haproxy-3s3r-rc status-vm3-tidb-haproxy-3s3r-rc status-vm3-crdb-haproxy-3s3r-rc:
	$(eval DB := $(word 3,$(subst -, ,$@)))
	@ssh $(TPCC_CLIENT) "bash $(TPCC_SCRIPTS)/status-vm1.sh \
	  --db $(DB) --topology vm-3node-haproxy-3s3r --iso rc" || true
	@echo "==> dry-run artifacts: $(TPCC_ARTIFACTS)/$(DB)-vm-3node-haproxy-3s3r-rc-*/dry-run/"
	@ssh $(TPCC_CLIENT) "ls -la $(TPCC_ARTIFACTS)/$(DB)-vm-3node-haproxy-3s3r-rc-*/dry-run/ 2>/dev/null | tail -20" || true

# ---- vm3-<db>-<sub>-rc : full chain with EXECUTE=1 safety gate -----
# Default: destroy-all + deploy + dry-run-confirm; stop at anchor.
# With EXECUTE=1: Mac 同步跑 deploy 部分，gate→prepare→run→collect 透過
# launch-vm1-suite.sh on .31 detached（mirror vm1-<db>-<iso> 設計，Mac 啟動後
# 立刻返回；後續可關屏 / 斷網）。Fetch 仍人工。
$(foreach db,tidb crdb ybdb,$(foreach sub,$(VM3_SUBS),vm3-$(db)-$(sub)-rc)):
	$(eval DB := $(word 2,$(subst -, ,$@)))
	$(eval SUB := $(word 3,$(subst -, ,$@)))
	$(eval ISO := $(word 4,$(subst -, ,$@)))
	$(eval HOST := $(strip $(call DB_HOST,$(DB))))
	$(eval TS := $(TPCC_TS))
	@echo "==================================================================="
	@echo "  vm3-$(DB)-$(SUB)-$(ISO)  ts=$(TS)  execute=$(EXECUTE)"
	@echo "==================================================================="
	$(MAKE) destroy-vm3-all
	$(MAKE) bootstrap-tpcc-client
	$(MAKE) deploy-vm3-$(DB)-$(SUB)
	$(MAKE) dryrun-vm3-$(DB)-$(SUB)-$(ISO) TPCC_TS=$(TS)
	@if [ "$(EXECUTE)" = "1" ]; then \
	  echo "==> EXECUTE=1 — launching detached suite on $(TPCC_CLIENT)"; \
	  ssh $(TPCC_CLIENT) "env $(TPCC_ENV) bash $(TPCC_SCRIPTS)/launch-vm1-suite.sh \
	    --db $(DB) --iso $(ISO) --topology vm-3node-$(SUB) \
	    --db-host $(HOST) --ts $(TS)"; \
	  echo "==================================================================="; \
	  echo "  Suite launched detached on $(TPCC_CLIENT) — Mac safe to disconnect."; \
	  echo "  TPCC_TS:       $(TS)"; \
	  echo "  Status check:  make status-vm3-$(DB)-$(SUB)-$(ISO)"; \
	  echo "  Tail log:      ssh $(TPCC_CLIENT) tail -f $(TPCC_BASE)/logs/$(DB)-vm-3node-$(SUB)-$(ISO)-$(TS).log"; \
	  echo "  Fetch later:   make fetch-vm3-$(DB)-$(SUB)-$(ISO) TPCC_TS=$(TS)"; \
	  echo "==================================================================="; \
	else \
	  echo "==================================================================="; \
	  echo "  STOPPED AT DRY-RUN ANCHOR"; \
	  echo "  TPCC_TS:        $(TS)"; \
	  echo "  Review:         ssh $(TPCC_CLIENT) cat $(TPCC_ARTIFACTS)/$(DB)-vm-3node-$(SUB)-$(ISO)-$(TS)/dry-run/*.txt"; \
	  echo "  Status:         make status-vm3-$(DB)-$(SUB)-$(ISO)"; \
	  echo "  To execute:     make vm3-$(DB)-$(SUB)-$(ISO) EXECUTE=1 TPCC_TS=$(TS)"; \
	  echo "==================================================================="; \
	fi

# Batch: deploy + dry-run for all 4 sub-topologies of one DB
.PHONY: vm3-tidb-all-rc-dry vm3-crdb-all-rc-dry vm3-ybdb-all-rc-dry vm3-all-dry
vm3-tidb-all-rc-dry: vm3-tidb-1s1r-rc vm3-tidb-1s3r-rc vm3-tidb-3s1r-rc vm3-tidb-3s3r-rc
vm3-crdb-all-rc-dry: vm3-crdb-1s1r-rc vm3-crdb-1s3r-rc vm3-crdb-3s1r-rc vm3-crdb-3s3r-rc
vm3-ybdb-all-rc-dry: vm3-ybdb-1s1r-rc vm3-ybdb-1s3r-rc vm3-ybdb-3s1r-rc vm3-ybdb-3s3r-rc
vm3-all-dry: vm3-tidb-all-rc-dry vm3-crdb-all-rc-dry vm3-ybdb-all-rc-dry
	@echo "==> all 12 vm-3node cells reached dry-run anchor"

# ====================================================================
# vm-3node-haproxy-3s3r (Phase F) — hardcoded targets, since 'haproxy-3s3r'
# 含中槓會破壞 $(word N,$(subst -, ,$@)) 解析；不走 foreach。
# Client connects to HAProxy on 172.24.47.20；scripts 內部以 CLUSTER_HOST
# case 處理 (coldreset-{tidb,crdb,ybdb}.sh / run.sh / collect.sh / db-config-dump.sh / prepare.sh)。
# DB-specific HAProxy frontend port (與 backend 相同):
#   TiDB:        4000   (.32/.33/.34:4000 — 需 3 tidb_servers, tidb-vm3.yml 條件渲染)
#   CockroachDB: 26257  (.32/.33/.34:26257)
#   YugabyteDB:  5433   (.32/.33/.34:5433)
# 部署：各 vm-3node playbook 末段 conditional include haproxy_deploy role
# (when *_sub_topology == 'haproxy-3s3r')，無需另跑 haproxy.yml。
# ====================================================================

HAPROXY_HOST := 172.24.47.20

# Per-DB HAProxy frontend port (與 deploy 時 ansible playbook 內 haproxy_backends 對齊)
define HAPROXY_PORT
$(if $(filter tidb,$(1)),4000,\
$(if $(filter crdb,$(1)),26257,\
$(if $(filter ybdb,$(1)),5433,)))
endef

.PHONY: deploy-vm3-tidb-haproxy-3s3r deploy-vm3-crdb-haproxy-3s3r deploy-vm3-ybdb-haproxy-3s3r
deploy-vm3-tidb-haproxy-3s3r:
	@echo "==> deploy-vm3-tidb-haproxy-3s3r (sub_topology=haproxy-3s3r; 3 tidb_servers + HAProxy on .20)"
	cd $(ANSIBLE_DIR) && ansible-playbook -i inventory/vm3.ini playbooks/tidb-vm3.yml \
	  -e tidb_sub_topology=haproxy-3s3r

deploy-vm3-crdb-haproxy-3s3r:
	@echo "==> deploy-vm3-crdb-haproxy-3s3r (sub_topology=haproxy-3s3r; cockroach × 3 + HAProxy on .20)"
	cd $(ANSIBLE_DIR) && ansible-playbook -i inventory/vm3.ini playbooks/cockroach-vm3.yml \
	  -e crdb_sub_topology=haproxy-3s3r

deploy-vm3-ybdb-haproxy-3s3r:
	@echo "==> deploy-vm3-ybdb-haproxy-3s3r (sub_topology=haproxy-3s3r; yugabyted × 3 + HAProxy on .20)"
	cd $(ANSIBLE_DIR) && ansible-playbook -i inventory/vm3.ini playbooks/yugabyte-vm3.yml \
	  -e yb_sub_topology=haproxy-3s3r

.PHONY: dryrun-vm3-tidb-haproxy-3s3r-rc dryrun-vm3-crdb-haproxy-3s3r-rc dryrun-vm3-ybdb-haproxy-3s3r-rc
dryrun-vm3-tidb-haproxy-3s3r-rc dryrun-vm3-crdb-haproxy-3s3r-rc dryrun-vm3-ybdb-haproxy-3s3r-rc:
	$(eval DB := $(word 3,$(subst -, ,$@)))
	$(eval PORT := $(strip $(call HAPROXY_PORT,$(DB))))
	@echo "==> dryrun-vm3-$(DB)-haproxy-3s3r-rc db-host=$(HAPROXY_HOST):$(PORT) ts=$(TPCC_TS)"
	ssh $(TPCC_CLIENT) "$(TPCC_ENV) bash $(TPCC_SCRIPTS)/dry-run-confirm.sh \
	  --db $(DB) --sub-topology haproxy-3s3r --iso rc --db-host $(HAPROXY_HOST) --ts $(TPCC_TS)"

.PHONY: gate-vm3-tidb-haproxy-3s3r-rc gate-vm3-crdb-haproxy-3s3r-rc gate-vm3-ybdb-haproxy-3s3r-rc
gate-vm3-tidb-haproxy-3s3r-rc gate-vm3-crdb-haproxy-3s3r-rc gate-vm3-ybdb-haproxy-3s3r-rc:
	$(eval DB := $(word 3,$(subst -, ,$@)))
	@echo "==> gate-vm3-$(DB)-haproxy-3s3r-rc ts=$(TPCC_TS)"
	ssh $(TPCC_CLIENT) "$(TPCC_ENV) bash $(TPCC_SCRIPTS)/gate.sh \
	  --db $(DB) --iso rc --db-host $(HAPROXY_HOST) --ts $(TPCC_TS)"

.PHONY: prepare-vm3-tidb-haproxy-3s3r-rc prepare-vm3-crdb-haproxy-3s3r-rc prepare-vm3-ybdb-haproxy-3s3r-rc
prepare-vm3-tidb-haproxy-3s3r-rc prepare-vm3-crdb-haproxy-3s3r-rc prepare-vm3-ybdb-haproxy-3s3r-rc:
	$(eval DB := $(word 3,$(subst -, ,$@)))
	@echo "==> prepare-vm3-$(DB)-haproxy-3s3r-rc db-host=$(HAPROXY_HOST) ts=$(TPCC_TS)"
	ssh $(TPCC_CLIENT) "$(TPCC_ENV) bash $(TPCC_SCRIPTS)/prepare.sh \
	  --db $(DB) --iso rc --topology vm-3node-haproxy-3s3r --db-host $(HAPROXY_HOST) --ts $(TPCC_TS)"

.PHONY: run-vm3-tidb-haproxy-3s3r-rc run-vm3-crdb-haproxy-3s3r-rc run-vm3-ybdb-haproxy-3s3r-rc
run-vm3-tidb-haproxy-3s3r-rc run-vm3-crdb-haproxy-3s3r-rc run-vm3-ybdb-haproxy-3s3r-rc:
	$(eval DB := $(word 3,$(subst -, ,$@)))
	@echo "==> run-vm3-$(DB)-haproxy-3s3r-rc db-host=$(HAPROXY_HOST) ts=$(TPCC_TS)"
	ssh $(TPCC_CLIENT) "$(TPCC_ENV) bash $(TPCC_SCRIPTS)/run.sh \
	  --db $(DB) --iso rc --topology vm-3node-haproxy-3s3r --db-host $(HAPROXY_HOST) --ts $(TPCC_TS)"

.PHONY: collect-vm3-tidb-haproxy-3s3r-rc collect-vm3-crdb-haproxy-3s3r-rc collect-vm3-ybdb-haproxy-3s3r-rc
collect-vm3-tidb-haproxy-3s3r-rc collect-vm3-crdb-haproxy-3s3r-rc collect-vm3-ybdb-haproxy-3s3r-rc:
	$(eval DB := $(word 3,$(subst -, ,$@)))
	@echo "==> collect-vm3-$(DB)-haproxy-3s3r-rc db-host=$(HAPROXY_HOST) ts=$(TPCC_TS)"
	ssh $(TPCC_CLIENT) "$(TPCC_ENV) bash $(TPCC_SCRIPTS)/collect.sh \
	  --db $(DB) --iso rc --topology vm-3node-haproxy-3s3r --db-host $(HAPROXY_HOST) --ts $(TPCC_TS)"

# Full chain (mirror vm3-<db>-<sub>-rc), gate→prepare→run→collect 走 detached suite。
.PHONY: vm3-tidb-haproxy-3s3r-rc vm3-crdb-haproxy-3s3r-rc vm3-ybdb-haproxy-3s3r-rc
vm3-tidb-haproxy-3s3r-rc vm3-crdb-haproxy-3s3r-rc vm3-ybdb-haproxy-3s3r-rc:
	$(eval DB := $(word 2,$(subst -, ,$@)))
	$(eval TS := $(TPCC_TS))
	@echo "==================================================================="
	@echo "  vm3-$(DB)-haproxy-3s3r-rc  ts=$(TS)  execute=$(EXECUTE)"
	@echo "==================================================================="
	$(MAKE) destroy-vm3-all
	$(MAKE) bootstrap-tpcc-client
	$(MAKE) deploy-vm3-$(DB)-haproxy-3s3r
	$(MAKE) dryrun-vm3-$(DB)-haproxy-3s3r-rc TPCC_TS=$(TS)
	@if [ "$(EXECUTE)" = "1" ]; then \
	  echo "==> EXECUTE=1 — launching detached suite on $(TPCC_CLIENT)"; \
	  ssh $(TPCC_CLIENT) "env $(TPCC_ENV) bash $(TPCC_SCRIPTS)/launch-vm1-suite.sh \
	    --db $(DB) --iso rc --topology vm-3node-haproxy-3s3r \
	    --db-host $(HAPROXY_HOST) --ts $(TS)"; \
	  echo "==================================================================="; \
	  echo "  Suite launched detached on $(TPCC_CLIENT) — Mac safe to disconnect."; \
	  echo "  TPCC_TS:       $(TS)"; \
	  echo "  Status check:  make status-vm3-$(DB)-haproxy-3s3r-rc"; \
	  echo "  Tail log:      ssh $(TPCC_CLIENT) tail -f $(TPCC_BASE)/logs/$(DB)-vm-3node-haproxy-3s3r-rc-$(TS).log"; \
	  echo "  Fetch later:   make fetch-vm3-$(DB)-haproxy-3s3r-rc TPCC_TS=$(TS)"; \
	  echo "==================================================================="; \
	else \
	  echo "==================================================================="; \
	  echo "  STOPPED AT DRY-RUN ANCHOR"; \
	  echo "  TPCC_TS:        $(TS)"; \
	  echo "  Review:         ssh $(TPCC_CLIENT) cat $(TPCC_ARTIFACTS)/$(DB)-vm-3node-haproxy-3s3r-rc-$(TS)/dry-run/*.txt"; \
	  echo "  Status:         make status-vm3-$(DB)-haproxy-3s3r-rc"; \
	  echo "  To execute:     make vm3-$(DB)-haproxy-3s3r-rc EXECUTE=1 TPCC_TS=$(TS)"; \
	  echo "==================================================================="; \
	fi

# Batch: 1 DB × 5 sub-topology dry-run (4 direct + 1 haproxy)
.PHONY: vm3-tidb-haproxy-3s3r-rc-dry vm3-crdb-haproxy-3s3r-rc-dry vm3-ybdb-haproxy-3s3r-rc-dry
vm3-tidb-all5-rc-dry: vm3-tidb-all-rc-dry vm3-tidb-haproxy-3s3r-rc
vm3-crdb-all5-rc-dry: vm3-crdb-all-rc-dry vm3-crdb-haproxy-3s3r-rc
vm3-ybdb-all5-rc-dry: vm3-ybdb-all-rc-dry vm3-ybdb-haproxy-3s3r-rc

## ============================================================================
## Phase isolation targets (T104-T106) — see results/PHASES.md + phase-*/README.md
## ============================================================================

.PHONY: phase-k8s-plan phase-k8s-deploy phase-k8s-run \
        phase-threadcontrol-plan phase-threadcontrol-verify \
        phase-crossregion-plan phase-crossregion-deploy phase-crossregion-run \
        phase-crossregion-deploy-tidb \
        phase-crossregion-run-tidb-a-s-p-a phase-crossregion-run-tidb-a-s-p-b \
        phase-crossregion-run-tidb-a-a-ro-p-a phase-crossregion-run-tidb-a-a-ro-p-b \
        phase-crossregion-run-tidb-a-a-p-a phase-crossregion-run-tidb-a-a-p-b \
        phase-crossregion-chaos-plan phase-crossregion-chaos-deploy phase-crossregion-chaos-run

# --- Phase-K8s ---
phase-k8s-plan:
	@echo "===================================================================="
	@echo " phase-k8s — Kubernetes 對照組 (v4.7 detached suite, RC only)"
	@echo "===================================================================="
	@cat phase-k8s/manifest.yaml | sed 's/^/  /'
	@echo "  ---"
	@echo "  Status: deploy ready / v4.7 run-wrapper PENDING (see phase-k8s/README.md §Pending)"
	@echo "  Existing scripts (pre-v4.7, do NOT use as output source):"
	@for f in tests/run-all/*-k8s-3node-*.sh tests/prepare/*-k8s-3node-*.sh; do echo "    $$f"; done

phase-k8s-deploy:
	@echo "==> phase-k8s deploy: 三家 K8s ansible playbook"
	cd $(ANSIBLE_DIR) && ansible-playbook -i $(INVENTORY) playbooks/tidb-k8s.yml
	cd $(ANSIBLE_DIR) && ansible-playbook -i $(INVENTORY) playbooks/cockroach-k8s.yml
	cd $(ANSIBLE_DIR) && ansible-playbook -i $(INVENTORY) playbooks/yugabyte-k8s.yml
	@echo "==> phase-k8s deploy complete; status via:"
	@echo "    cd $(ANSIBLE_DIR) && ansible-playbook -i $(INVENTORY) playbooks/{tidb,cockroach,yugabyte}-k8s-status.yml"

phase-k8s-run:
	@echo "==> phase-k8s-run: v4.7 K8s detached suite wrapper NOT YET IMPLEMENTED."
	@echo "    See phase-k8s/README.md §Pending v4.7 K8s wrapper for required deliverables."
	@echo "    Until wrapper lands, run results MUST NOT be promoted to S-K8S."
	@exit 1

# --- Phase-ThreadControl ---
phase-threadcontrol-plan:
	@echo "===================================================================="
	@echo " phase-threadcontrol — process/thread/admission tuning isolation"
	@echo "===================================================================="
	@cat phase-threadcontrol/manifest.yaml | sed 's/^/  /'
	@echo "  ---"
	@echo "  Status: manifest + guardrail spec landed; benchmark execution out of scope this round."
	@echo "  Tuning sources (read-only refs):"
	@echo "    - 1_MeetingMinutes/0605.md §3-§5 (TiDB / YBDB / CRDB process knob inventory)"
	@echo "    - 1_MeetingMinutes/0602-agenda.md §6 (4 議題)"

phase-threadcontrol-verify:
	@echo "==> phase-threadcontrol-verify: validating manifest + guardrails"
	@tests/common/validate-phase-manifest.sh phase-threadcontrol/manifest.yaml
	@echo "==> manifest OK; guardrail rules (path/marker/Make fail-fast) — see phase-threadcontrol/guardrails.md"

# --- Phase-CrossRegion (本輪 spec-only) ---
phase-crossregion-plan:
	@echo "===================================================================="
	@echo " phase-crossregion — IDC ↔ GCP cross-region (single 6-node, RC, exploratory)"
	@echo "===================================================================="
	@cat phase-crossregion/manifest.yaml | sed 's/^/  /'
	@echo "  ---"
	@echo "  Topology (placement × workload 正交):"
	@echo "    placement: P-A (2-IDC + 1-GCP, majority IDC) / P-B (1+1+1 散)"
	@echo "    workload : A-A / A-A-RO / A-S / backup / migration"
	@echo "  Chaos plan (lab mode, plan-only this round):"
	@echo "    C1 GCP partition / C3 GCP read-only / C4 IDC leader die / C7 cluster write reject"
	@echo "  Decision source: 1_MeetingMinutes/0602-decisions-track-E.md"
	@echo "  Status: spec landed; deploy / runtime / chaos NOT executed this round."

phase-crossregion-deploy:
	@echo "==> phase-crossregion-deploy: 6-node cross-region ansible NOT YET IMPLEMENTED (Pre-P0 task 2)."
	@echo "    See phase-crossregion/README.md + 1_MeetingMinutes/0602-decisions-track-E.md §2."
	@exit 1

phase-crossregion-run:
	@echo "==> phase-crossregion-run: runtime phase P0+ NOT YET IMPLEMENTED (spec-only this round)."
	@exit 1

phase-crossregion-chaos-plan:
	@echo "==> phase-crossregion chaos plan (4 scenarios, lab mode):"
	@for f in phase-crossregion/chaos/*.md; do echo "  - $$f"; done

phase-crossregion-chaos-deploy:
	@echo "==> phase-crossregion-chaos-deploy: NOT YET IMPLEMENTED."
	@exit 1

phase-crossregion-chaos-run:
	@echo "==> phase-crossregion-chaos-run: NOT YET IMPLEMENTED (chaos infra pending Pre-P0/P0)."
	@exit 1
