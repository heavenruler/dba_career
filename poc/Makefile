# ===================================================================
# Makefile — phase-crossregion (IDC↔GCP cross-region PoC, 9 phases)
#
# Orchestrates the 3-DB cross-region smoke (TiDB / YBDB / CRDB) across
# IDC (172.24.40.32-34) and GCP (asia-east1-a 10.160.152.11-13) via IAP
# tunnels (localhost:12211-12215).
#
# Required IaC dirs:  iac-idc/, iac-gcp/  (terraform)
#                     ansible/playbooks/{tidb,yugabyte,cockroach}-vm6.yml
# Sub-rules reuse:    Makefile.tc1 (bootstrap-tpcc-client, new-*-vms,
#                     drop-*-vms, gcp-tunnel-*, gcp-wait-startup,
#                     inventory-refresh*, clean-tpcc-artifacts).
#
# Today's SSOT:       phase-crossregion/SESSION-2026-06-19-3db-smoke.md
# Hard contract:      PHASE_NAME=phase-crossregion, RESULT_SCOPE=X-CROSS,
#                     BASELINE_FAMILY=crossregion, PLACEMENT=P-A,
#                     PROFILE=A-S, CLIENT_ZONE=idc, GATE_SKIP=1.
# ===================================================================

# === IaC dirs ===
IDC_IAC_DIR        := iac-idc
GCP_IAC_DIR        := iac-gcp
ANSIBLE_DIR        := ansible
ANSIBLE_INV_VIA31  := inventory/crossregion-via31.ini
ANSIBLE_REMOTE_DIR := /tmp/poc/ansible
POC_REMOTE_ROOT    := /tmp/poc
INVENTORY          := $(ANSIBLE_DIR)/inventory/hosts.ini
CROSSREGION_INV    := $(ANSIBLE_DIR)/inventory/crossregion.ini

# === IDC hosts ===
IDC_ADMIN          := 172.24.40.31
IDC_NODES          := 172.24.40.32 172.24.40.33 172.24.40.34
IDC_NODES_HEAD     := 172.24.40.32
IDC_KNOWN          := $(IDC_ADMIN) $(IDC_NODES)

# === GCP IAP tunnel ports ===
GCP_PORTS          := 12211 12212 12213 12214 12215
GCP_DB_PORTS       := 12211 12212 12213
GCP_DB_IPS         := 10.160.152.11 10.160.152.12 10.160.152.13

# === TPC-C client / artifacts (vm-1node SSOT §11.2) ===
TPCC_CLIENT        := root@172.24.40.31
TPCC_BASE          := /tmp/poc-tpcc
TPCC_ARTIFACTS     := $(TPCC_BASE)/artifacts
TPCC_SCRIPTS       := $(TPCC_BASE)/scripts
LOCAL_SCRIPTS      := tests/common
LOCAL_RESULTS      := results

# === DB hosts (vm-6node IDC writer = .32; single-port writer) ===
TIDB_HOST          := 172.24.40.32
TIDB_PORT          := 4000
CRDB_HOST          := 172.24.40.32
CRDB_PORT          := 26257
YBDB_HOST          := 172.24.40.32
YBDB_PORT          := 5433

# === go-tpc 5-min smoke knobs (NOT the full sweep) ===
GOTPC_VERSION      ?= v1.0.12
WAREHOUSES         ?= 4
THREADS_LIST       ?= 16
ROUNDS             ?= 1
WARMUP_SEC         ?= 30
RUN_SEC            ?= 300
ROUND_SLEEP_SEC    ?= 0
ISO                ?= rc

# ============ Per-phase timeouts (seconds; can be overridden) ============
TIMEOUT_PHASE1_APPLY    ?= 1200   # 20m
TIMEOUT_PHASE1_WAIT     ?= 900    # 15m (5 ports × 10min worst case 再加 buffer 15m)
TIMEOUT_PHASE2_BOOTSTRAP ?= 600   # 10m
TIMEOUT_PHASE3_DEPLOY   ?= 1800   # 30m TiDB
TIMEOUT_PHASE4_DEPLOY   ?= 1800   # 30m YBDB
TIMEOUT_PHASE5_DEPLOY   ?= 1800   # 30m CRDB
TIMEOUT_PHASE6_SMOKE    ?= 3600   # 60m TiDB (含 5 round)
TIMEOUT_PHASE7_SMOKE    ?= 3600   # 60m YBDB
TIMEOUT_PHASE8_SMOKE    ?= 3600   # 60m CRDB
TIMEOUT_PHASE85_FETCH   ?= 600    # 10m
TIMEOUT_PHASE9_DESTROY  ?= 900    # 15m
TIMEOUT_PHASE4_FIX6N    ?= 1800   # 30m (load-balancer drain)

# macOS: GNU timeout is 'gtimeout' (brew install coreutils); Linux has /usr/bin/timeout
TIMEOUT_BIN ?= $(shell command -v timeout 2>/dev/null || command -v gtimeout 2>/dev/null)
# =========================================================================

# === Cross-region contract (run-vm6-suite.sh hard-asserts these) ===
PHASE_NAME         := phase-crossregion
RESULT_SCOPE       := X-CROSS
LOCAL_RESULT_SCOPE := x-cross
LOCAL_RESULT_CATEGORY ?= smoke/early-runs
LOCAL_RESULT_ROOT := $(LOCAL_RESULTS)/$(LOCAL_RESULT_SCOPE)/$(LOCAL_RESULT_CATEGORY)
BASELINE_FAMILY    := crossregion
PLACEMENT          ?= P-A
PROFILE            ?= A-S
CLIENT_ZONE        := idc
GATE_SKIP          := 1

# === Per-invocation timestamp (overridable so chained sub-makes share one) ===
TPCC_TS            ?= $(shell date +%Y%m%dT%H%M%S%z)

# === Phase-crossregion script dir (on .31 after bootstrap+rsync) ===
CROSS_SCRIPTS_REMOTE := /tmp/poc-tpcc/scripts/crossregion

# === YBDB 6-node fix knobs ===
YB_PLACEMENT_INFO  := 104.idc.vlan241:2,104.gcp.asia-east1-a:1
YB_PREFERRED_ZONE  := 104.idc.vlan241
YB_RF              := 3
YB_MASTER_ADDR     := 172.24.40.32:7100,172.24.40.33:7100,172.24.40.34:7100

# === SSH common opts ===
SSH_OPTS           := -o LogLevel=ERROR -o StrictHostKeyChecking=accept-new

.DEFAULT_GOAL := help

.PHONY: help \
        phase1 phase1-destroy phase1-destroy-idc phase1-destroy-gcp phase1-apply phase1-wait phase1-wait-via-31 \
        phase2 phase2-dns-fix phase2-ssh-prime phase2-bootstrap phase2-gate \
        phase3 phase3-tidb-deploy \
        phase4 phase4-ybdb-deploy phase4-ybdb-fix6n \
        phase5 phase5-crdb-deploy \
        phase6 phase6-tidb-smoke phase6-tidb-result \
        phase7 phase7-ybdb-smoke phase7-ybdb-result \
        phase8 phase8-crdb-smoke phase8-crdb-result \
        phase9 phase9-destroy phase9-tunnels-stop \
        teardown-tidb teardown-ybdb teardown-crdb \
        phase-crossregion-all \
        new-idc-vms new-gcp-vms drop-idc-vms drop-gcp-vms \
        gcp-tunnel-start gcp-tunnel-stop gcp-tunnel-ensure gcp-wait-startup \
        inventory-refresh gcp-inventory-refresh inventory-refresh-all ansible-ping \
        bootstrap-tpcc-client clean-tpcc-artifacts \
        phase0-preflight phase0-preflight-fix

# ===================================================================
# help (default)
# ===================================================================
help:
	@echo "=== phase-crossregion 9-phase Makefile ==="
	@echo ""
	@echo "Meta:"
	@echo "  make phase-crossregion-all                  - run all 9 phases (TPCC_TS shared across phases)"
	@echo ""
	@echo "Phase chain (run in order):"
	@echo "  make phase1                                 - destroy + apply IDC + GCP VMs + wait startup"
	@echo "  make phase2                                 - DNS/chrony fix + SSH prime + bootstrap + chrony gate"
	@echo "  make phase3-tidb-deploy                     - Ansible deploy TiDB cluster (vm-6node)"
	@echo "  make phase6-tidb-smoke TPCC_TS=<ts>         - 5-min TiDB smoke via run-vm6-suite.sh"
	@echo "  make phase6-tidb-result TPCC_TS=<ts>        - parse + print TiDB tpmC / latency"
	@echo "  make teardown-tidb                          - tiup cluster destroy (best-effort)"
	@echo "  make phase4-ybdb-deploy                     - Ansible deploy YBDB cluster"
	@echo "  make phase4-ybdb-fix6n                      - post-deploy: GCP IPv4 advertise + placement_info + preferred_zone"
	@echo "  make phase4                                 - phase4-ybdb-deploy + phase4-ybdb-fix6n"
	@echo "  make phase7-ybdb-smoke TPCC_TS=<ts>         - 5-min YBDB smoke (gate/prepare/run/collect direct)"
	@echo "  make phase7-ybdb-result TPCC_TS=<ts>        - parse + print YBDB tpmC / latency"
	@echo "  make teardown-ybdb                          - kill yb procs + rm /var/yugabyte"
	@echo "  make phase5-crdb-deploy                     - Ansible deploy CRDB cluster"
	@echo "  make phase8-crdb-smoke TPCC_TS=<ts>         - 5-min CRDB smoke (gate/prepare/run/collect direct)"
	@echo "  make phase8-crdb-result TPCC_TS=<ts>        - parse + print CRDB tpmC / latency"
	@echo "  make teardown-crdb                          - stop cockroach + rm /var/lib/cockroach"
	@echo "  make phase9                                 - stop tunnels + terraform destroy (IDC + GCP)"
	@echo ""
	@echo "Utility:"
	@echo "  make gcp-tunnel-start | -stop | -ensure     - IAP tunnel control (poc-1..5: 12211..12215)"
	@echo "  make inventory-refresh-all                  - rebuild ansible/inventory/hosts.ini from terraform"
	@echo "  make bootstrap-tpcc-client                  - install go-tpc + rsync tests/common to .31"
	@echo "  make clean-tpcc-artifacts                   - wipe .31:$(TPCC_ARTIFACTS)/*"
	@echo ""
	@echo "Vars: TPCC_TS=<ISO8601> PLACEMENT=P-A PROFILE=A-S ISO=rc WAREHOUSES=4 THREADS_LIST=16 RUN_SEC=300"

# ===================================================================
# Phase 1 — VM lifecycle (rebuild IDC + GCP)
# ===================================================================
phase1: phase1-destroy phase1-apply phase1-wait
	@echo "==> phase1 complete (VMs rebuilt + GCP startup-done)"

phase1-destroy:
	$(MAKE) -j2 phase1-destroy-idc phase1-destroy-gcp
	@echo "==> phase1-destroy complete"

phase1-destroy-idc:
	-cd $(IDC_IAC_DIR) && terraform destroy -auto-approve

phase1-destroy-gcp:
	-cd $(GCP_IAC_DIR) && terraform destroy -auto-approve

# Re-uses new-idc-vms + new-gcp-vms body from Makefile.tc1 verbatim (sans drop dep)
phase1-apply:
	@echo "==> [start] phase1-apply at $$(date +%Y-%m-%dT%H:%M:%S%z) (timeout=$(TIMEOUT_PHASE1_APPLY)s)"
	cd $(IDC_IAC_DIR) && terraform apply -auto-approve
	for ip in $(IDC_KNOWN); do ssh-keygen -R $$ip || true; done
	ssh $(SSH_OPTS) root@$(IDC_ADMIN) \
	  'for ip in $(IDC_NODES); do ssh-keygen -R $$ip; done'
	@echo "==> warming dnf metadata cache on IDC nodes (parallel)"
	@pids=""; for ip in $(IDC_NODES); do \
	  ( ssh $(SSH_OPTS) root@$$ip 'dnf -q makecache' \
	      && echo "  -> $$ip cache ok" \
	      || { echo "  -> $$ip cache FAIL"; exit 1; } ) & \
	  pids="$$pids $$!"; \
	done; fail=0; for p in $$pids; do wait $$p || fail=1; done; test $$fail -eq 0
	@echo "==> expanding root partition on IDC nodes (sda3 → 100G; parallel)"
	@pids=""; for ip in $(IDC_NODES); do \
	  ( ssh $(SSH_OPTS) root@$$ip \
	      'dnf install -y -q cloud-utils-growpart && growpart /dev/sda 3 && xfs_growfs / && df -h /' \
	      && echo "  -> $$ip growpart ok" \
	      || { echo "  -> $$ip growpart FAIL"; exit 1; } ) & \
	  pids="$$pids $$!"; \
	done; fail=0; for p in $$pids; do wait $$p || fail=1; done; test $$fail -eq 0
	cd $(GCP_IAC_DIR) && terraform apply -auto-approve
	for port in $(GCP_PORTS); do ssh-keygen -R "[localhost]:$$port" || true; done
	ssh $(SSH_OPTS) root@$(IDC_ADMIN) \
	  'for ip in 10.160.152.11 10.160.152.12 10.160.152.13 10.160.152.14 10.160.152.15; do ssh-keygen -R $$ip 2>/dev/null || true; done'
	@echo "==> [end]   phase1-apply at $$(date +%Y-%m-%dT%H:%M:%S%z)"

phase1-wait: gcp-tunnel-start
	@echo "==> [start] phase1-wait at $$(date +%Y-%m-%dT%H:%M:%S%z) (timeout=$(TIMEOUT_PHASE1_WAIT)s)"
	@echo "==> sleep 15 for IAP tunnels to be reachable"
	@sleep 15
	@for p in $(GCP_PORTS); do \
	  echo "==> waiting startup-done on :$$p (max 10 min, retries connection refused)"; \
	  ok=0; \
	  for retry in $$(seq 1 60); do \
	    if ssh $(SSH_OPTS) -o ConnectTimeout=5 -o BatchMode=yes -p $$p root@localhost 'test -f /var/lib/startup-done' 2>/dev/null; then \
	      echo "  startup-done on :$$p"; ok=1; break; \
	    fi; \
	    sleep 10; \
	  done; \
	  [ $$ok -eq 1 ] || { echo "[phase1-wait] :$$p startup 10min timeout — abort"; exit 1; }; \
	done
	@echo "==> [end]   phase1-wait at $$(date +%Y-%m-%dT%H:%M:%S%z)"

# ALTERNATIVE: phase1-wait-via-31 — IAP tunnel 卡時改用 .31 直連 GCP 內部 IP
#   use: make phase1-apply phase1-wait-via-31 phase2-bootstrap ...
#   prerequisite: IDC↔GCP FW 已開、.31 known_hosts 已清舊 GCP fingerprint
phase1-wait-via-31:
	@echo "==> phase1-wait-via-31 (bypass IAP tunnel; ssh from .31 → GCP 內 IP)"
	@$(CURDIR)/phase-crossregion/scripts/check-gcp-via-31.sh
	@echo "==> all 5 GCP nodes READY (via .31)"

# ===================================================================
# Phase 2 — Pre-deploy init (DNS/chrony, SSH prime, bootstrap, chrony gate)
# ===================================================================
phase2: phase2-dns-fix phase2-ssh-prime gcp-tunnel-ensure phase2-bootstrap phase2-gate inventory-refresh-all
	@echo "==> phase2 complete"

phase2-dns-fix:
	@echo "==> phase2-dns-fix: fix DNS + chrony IP server on $(IDC_NODES)"
	for ip in $(IDC_NODES); do \
	  ssh $(SSH_OPTS) root@$$ip ' \
	    chattr -i /etc/resolv.conf 2>/dev/null || true; \
	    printf "nameserver 10.0.1.5\nnameserver 8.8.8.8\n" > /etc/resolv.conf; \
	    chattr +i /etc/resolv.conf; \
	    grep -q "^server 172.19.254.7" /etc/chrony.conf || echo "server 172.19.254.7 iburst" >> /etc/chrony.conf; \
	    systemctl restart chronyd; sleep 2; chronyc tracking | head -3'; \
	done

phase2-ssh-prime:
	@echo "==> phase2-ssh-prime: known_hosts clean + .31 self-ssh + GCP pubkey push"
	for ip in $(IDC_KNOWN); do ssh-keygen -R $$ip || true; done
	for port in $(GCP_PORTS); do ssh-keygen -R "[localhost]:$$port" || true; done
	ssh $(SSH_OPTS) root@$(IDC_ADMIN) 'true'
	for port in $(GCP_PORTS); do \
	  ssh $(SSH_OPTS) -p $$port root@localhost 'true'; \
	done
	ssh root@$(IDC_ADMIN) '\
	  [ -f /root/.ssh/id_rsa ] || ssh-keygen -t rsa -N "" -f /root/.ssh/id_rsa; \
	  grep -qFf /root/.ssh/id_rsa.pub /root/.ssh/authorized_keys 2>/dev/null \
	    || cat /root/.ssh/id_rsa.pub >> /root/.ssh/authorized_keys; \
	  chmod 600 /root/.ssh/authorized_keys; \
	  ssh -o StrictHostKeyChecking=accept-new root@172.24.40.31 true'
	@PUBKEY=$$(ssh root@$(IDC_ADMIN) 'cat /root/.ssh/id_rsa.pub'); \
	for port in $(GCP_PORTS); do \
	  ssh -p $$port root@localhost "mkdir -p /root/.ssh; grep -qF \"$$PUBKEY\" /root/.ssh/authorized_keys 2>/dev/null || echo \"$$PUBKEY\" >> /root/.ssh/authorized_keys; chmod 600 /root/.ssh/authorized_keys"; \
	done
	ssh root@$(IDC_ADMIN) 'for ip in $(IDC_NODES) $(GCP_DB_IPS); do ssh-keygen -R $$ip 2>/dev/null; done; true'

phase2-bootstrap:
	@echo "==> [start] phase2-bootstrap at $$(date +%Y-%m-%dT%H:%M:%S%z) (timeout=$(TIMEOUT_PHASE2_BOOTSTRAP)s)"
	@echo "==> phase2-bootstrap: install go-tpc + rsync scripts + rsync ansible to .31"
	TPCC_CLIENT=$(TPCC_CLIENT) TPCC_BASE=$(TPCC_BASE) GOTPC_VERSION=$(GOTPC_VERSION) \
	  bash $(LOCAL_SCRIPTS)/bootstrap-client.sh
	ssh $(TPCC_CLIENT) 'mkdir -p $(CROSS_SCRIPTS_REMOTE) $(ANSIBLE_REMOTE_DIR) $(POC_REMOTE_ROOT)/tests'
	rsync -avz phase-crossregion/scripts/ '$(TPCC_CLIENT):$(CROSS_SCRIPTS_REMOTE)/'
	@echo "==> rsync ansible/ + tests/ to $(TPCC_CLIENT):$(POC_REMOTE_ROOT)/ (mirror Mac layout for relative-path SQL files)"
	rsync -avz --delete ansible/ '$(TPCC_CLIENT):$(ANSIBLE_REMOTE_DIR)/'
	rsync -avz --delete tests/   '$(TPCC_CLIENT):$(POC_REMOTE_ROOT)/tests/'
	@echo "==> [end]   phase2-bootstrap at $$(date +%Y-%m-%dT%H:%M:%S%z)"

phase2-gate: gcp-tunnel-ensure
	@echo "==> phase2-gate: chrony 10-host cross-region drift gate (from MAC)"
	bash phase-crossregion/scripts/gate-chrony-cross-region.sh \
	  --ts $(TPCC_TS) --root-suffix preflight-$(TPCC_TS) --result-scope $(RESULT_SCOPE)

# ===================================================================
# Phase 3 — TiDB deploy
# ===================================================================
phase3: phase3-tidb-deploy

phase3-tidb-deploy:
	@echo "==> [start] phase3-tidb-deploy at $$(date +%Y-%m-%dT%H:%M:%S%z) (timeout=$(TIMEOUT_PHASE3_DEPLOY)s)"
	@echo "==> phase3-tidb-deploy (placement=$(PLACEMENT)) — controller=.31 direct ssh to GCP"
	ssh $(TPCC_CLIENT) "cd $(ANSIBLE_REMOTE_DIR) && ansible-playbook -i $(ANSIBLE_INV_VIA31) \
	  playbooks/tidb-vm6.yml -e tidb_placement=$(PLACEMENT)"
	@echo "==> [end]   phase3-tidb-deploy at $$(date +%Y-%m-%dT%H:%M:%S%z)"

# ===================================================================
# Phase 4 — YBDB deploy + 6-node fix
# ===================================================================
phase4: phase4-ybdb-deploy phase4-ybdb-fix6n

phase4-ybdb-deploy: phase-cleanup-tidb
	@echo "==> [start] phase4-ybdb-deploy at $$(date +%Y-%m-%dT%H:%M:%S%z) (timeout=$(TIMEOUT_PHASE4_DEPLOY)s)"
	@echo "==> phase4-ybdb-deploy (placement=$(PLACEMENT)) — controller=.31"
	ssh $(TPCC_CLIENT) "cd $(ANSIBLE_REMOTE_DIR) && ansible-playbook -i $(ANSIBLE_INV_VIA31) \
	  playbooks/yugabyte-vm6.yml -e yb_placement=$(PLACEMENT)"
	@echo "==> [end]   phase4-ybdb-deploy at $$(date +%Y-%m-%dT%H:%M:%S%z)"

# Per SESSION §2.6:
#   1. GCP yugabyted restart with --advertise_address=<IPv4> to avoid IPv6 fe80 hostname bug
#   2. sleep 60 (tserver_unresponsive_timeout_ms default)
#   3. yb-admin modify_placement_info + set_preferred_zones
phase4-ybdb-fix6n:
	@echo "==> [start] phase4-ybdb-fix6n at $$(date +%Y-%m-%dT%H:%M:%S%z) (timeout=$(TIMEOUT_PHASE4_FIX6N)s)"
	@echo "==> phase4-ybdb-fix6n: GCP restart loop skipped — playbook now advertises IPv4 directly via ansible_host"
	@echo "    (revisit if Plan B placement still fails; restart logic moved to scripts/fix6n-gcp-restart.sh if needed)"
	@echo "==> sleep 60 (waiting tserver register)"
	sleep 60
	@echo "==> remove DEAD tservers from master metadata (best practice: blacklist+remove+unblacklist)"
	@ssh root@$(IDC_NODES_HEAD) ' \
	  MASTERS=$(YB_MASTER_ADDR); \
	  DEAD_HOSTS=$$(/opt/yugabyte/bin/yb-admin --master_addresses=$$MASTERS list_all_tablet_servers 2>/dev/null | awk "/DEAD/{print \$$2}"); \
	  for host in $$DEAD_HOSTS; do \
	    echo "  blacklist $$host"; \
	    /opt/yugabyte/bin/yb-admin --master_addresses=$$MASTERS change_blacklist ADD $$host 2>&1 | tail -1; \
	  done; \
	  sleep 15; \
	  for uuid in $$(/opt/yugabyte/bin/yb-admin --master_addresses=$$MASTERS list_all_tablet_servers 2>/dev/null | awk "/DEAD/{print \$$1}"); do \
	    echo "  remove DEAD $$uuid"; \
	    /opt/yugabyte/bin/yb-admin --master_addresses=$$MASTERS remove_tablet_server $$uuid 2>&1 | tail -1; \
	  done; \
	  for host in $$DEAD_HOSTS; do \
	    /opt/yugabyte/bin/yb-admin --master_addresses=$$MASTERS change_blacklist REMOVE $$host 2>&1 | tail -1; \
	  done; true'
	@echo "==> Plan B: live_replicas=IDC-only RF=3, GCP=read_replica (clean leader pin, no cache stale)"
	@echo "    (revert Plan A — leader_blacklist causes postgres backend tablet cache stale)"
	@echo "==> set live_replicas placement = 104.idc.vlan241:3 RF=3"
	ssh root@$(IDC_NODES_HEAD) "/opt/yugabyte/bin/yb-admin --master_addresses=$(YB_MASTER_ADDR) modify_placement_info '104.idc.vlan241:3' 3"
	@echo "==> add GCP as read_replica (asia-east1-a only, RF=3 = 1 replica per GCP tserver)"
	ssh root@$(IDC_NODES_HEAD) "/opt/yugabyte/bin/yb-admin --master_addresses=$(YB_MASTER_ADDR) add_read_replica_placement_info '104.gcp.asia-east1-a:3' 3 ybdb_gcp_rr" 2>&1 | tail -3
	@echo "==> wait load_balancer Idle=1 sustained for 60s (best practice: not single-sample)"
	@idle_count=0; for i in $$(seq 1 90); do \
	  out=$$(ssh root@$(IDC_NODES_HEAD) "/opt/yugabyte/bin/yb-admin --master_addresses=$(YB_MASTER_ADDR) get_is_load_balancer_idle" 2>&1); \
	  case "$$out" in *"Idle = 1"*) idle_count=$$((idle_count+1));; \
	    *) idle_count=0;; \
	  esac; \
	  [ $$idle_count -ge 6 ] && { echo "  load_balancer sustained idle (6×10s consecutive)"; break; }; \
	  [ $$((i % 6)) -eq 0 ] && printf "  %3d/90 idle_count=%d  state=%s\n" $$i $$idle_count "$$out"; \
	  sleep 10; \
	done; \
	[ $$idle_count -ge 6 ] || echo "[fix6n] WARN: 15min 未 sustained idle, proceed anyway (Idle=0 可能 benign)"
	@echo "==> verify load_move_completion (must be 100%, hard gate)"
	@ssh root@$(IDC_NODES_HEAD) "/opt/yugabyte/bin/yb-admin --master_addresses=$(YB_MASTER_ADDR) get_load_move_completion" 2>&1 | tail -2
	@echo "==> health check: all 6 expected tservers ALIVE (3 IDC + 3 GCP read_replica)"
	@alive=$$(ssh root@$(IDC_NODES_HEAD) "/opt/yugabyte/bin/yb-admin --master_addresses=$(YB_MASTER_ADDR) list_all_tablet_servers" 2>/dev/null | grep -c ALIVE); \
	echo "  ALIVE tservers: $$alive (expect 6)"; \
	[ $$alive -ge 6 ] || { echo "[fix6n] health check FAIL — abort"; exit 1; }
	@echo "==> verify placement: 1 live (idc:3) + 1 read_replica (gcp:3)"
	ssh root@$(IDC_NODES_HEAD) "/opt/yugabyte/bin/yb-admin --master_addresses=$(YB_MASTER_ADDR) get_universe_config" | python3 -m json.tool | head -50
	@echo "==> [end]   phase4-ybdb-fix6n at $$(date +%Y-%m-%dT%H:%M:%S%z)"

# ===================================================================
# Phase 5 — CRDB deploy
# ===================================================================
phase5: phase5-crdb-deploy

phase5-crdb-deploy: phase-cleanup-ybdb
	@echo "==> [start] phase5-crdb-deploy at $$(date +%Y-%m-%dT%H:%M:%S%z) (timeout=$(TIMEOUT_PHASE5_DEPLOY)s)"
	@echo "==> phase5-crdb-deploy (placement=$(PLACEMENT)) — controller=.31"
	ssh $(TPCC_CLIENT) "cd $(ANSIBLE_REMOTE_DIR) && ansible-playbook -i $(ANSIBLE_INV_VIA31) \
	  playbooks/cockroach-vm6.yml -e crdb_placement=$(PLACEMENT)"
	@echo "==> [end]   phase5-crdb-deploy at $$(date +%Y-%m-%dT%H:%M:%S%z)"

# ===================================================================
# Phase 6 — TiDB smoke (run-vm6-suite.sh on .31)
# ===================================================================
phase6: phase6-tidb-smoke phase6-tidb-result

phase6-tidb-smoke:
	@echo "==> [start] phase6-tidb-smoke at $$(date +%Y-%m-%dT%H:%M:%S%z) (timeout=$(TIMEOUT_PHASE6_SMOKE)s)"
	@echo "==> phase6-tidb-smoke ts=$(TPCC_TS) placement=$(PLACEMENT)"
	@TS=$(TPCC_TS); \
	ssh $(TPCC_CLIENT) " \
	  export PHASE_NAME=$(PHASE_NAME) RESULT_SCOPE=$(RESULT_SCOPE) BASELINE_FAMILY=$(BASELINE_FAMILY) \
	         tuning_profile_id=default \
	         TPCC_TS=$$TS PLACEMENT=$(PLACEMENT) PROFILE=$(PROFILE) \
	         DB=tidb CLIENT_ZONE=$(CLIENT_ZONE) GATE_SKIP=$(GATE_SKIP) \
	         DB_HOST=$(TIDB_HOST) DB_PORT=$(TIDB_PORT) \
	         WAREHOUSES=$(WAREHOUSES) WARMUP_SEC=$(WARMUP_SEC) \
	         ROUNDS=$(ROUNDS) THREADS_LIST='$(THREADS_LIST)' RUN_SEC=$(RUN_SEC) ROUND_SLEEP_SEC=$(ROUND_SLEEP_SEC) \
	         TPCC_ARTIFACTS=$(TPCC_ARTIFACTS)/$(RESULT_SCOPE) \
	         WAN_PROBE_ENABLED=1 WAN_PROBE_IPERF=1; \
	  bash $(CROSS_SCRIPTS_REMOTE)/run-vm6-suite.sh \
	    --db tidb --topology vm-6node-$(PLACEMENT) --ts $$TS"
	@echo "==> phase6-tidb-post-prepare leader gate: wait tpcc region leaders → IDC (max 5 min)"
	@converged=0; for i in $$(seq 1 30); do \
	  pct=$$(ssh $(TPCC_CLIENT) "mysql -h $(TIDB_HOST) -P $(TIDB_PORT) -u root -BNe \"SELECT IFNULL(SUM(CASE WHEN s.LABEL LIKE '%idc%' THEN 1 ELSE 0 END) * 100.0 / NULLIF(COUNT(*),0), 0) FROM information_schema.tikv_region_peers p JOIN information_schema.tikv_store_status s ON p.STORE_ID=s.STORE_ID JOIN information_schema.tikv_region_status r ON p.REGION_ID=r.REGION_ID WHERE p.IS_LEADER=1 AND r.DB_NAME='tpcc';\"" 2>/dev/null | tail -1); \
	  case "$$pct" in *100|100.*) echo "  TiDB tpcc region leaders 100% on IDC"; converged=1; break;; esac; \
	  printf "  %2d/30 tpcc leaders on IDC: %s%%\n" $$i "$$pct"; \
	  sleep 10; \
	done; \
	[ "$$converged" = "1" ] || { echo "gate FAIL: TiDB tpcc leaders not 100% IDC after 5min"; exit 1; }
	@echo "==> phase6-tidb leader-snapshot (post-prepare placement verification)"
	@ROOT=$(TPCC_ARTIFACTS)/$(RESULT_SCOPE)/tidb-vm-6node-$(PLACEMENT)-$(ISO)-$(TPCC_TS); \
	ssh $(TPCC_CLIENT) "mkdir -p $$ROOT/leader-snapshot && \
	  mysql -h $(TIDB_HOST) -P $(TIDB_PORT) -u root -e \"SELECT \
	    p.STORE_ID, s.ADDRESS, s.STORE_STATE_NAME, s.LABEL, \
	    COUNT(*) as leader_count \
	    FROM information_schema.tikv_region_peers p \
	    JOIN information_schema.tikv_store_status s ON p.STORE_ID=s.STORE_ID \
	    WHERE p.IS_LEADER=1 \
	    GROUP BY p.STORE_ID, s.ADDRESS, s.STORE_STATE_NAME, s.LABEL \
	    ORDER BY leader_count DESC;\" > $$ROOT/leader-snapshot/tidb-region-leaders.txt 2>&1" || true
	@echo "==> [end]   phase6-tidb-smoke at $$(date +%Y-%m-%dT%H:%M:%S%z)"

phase6-tidb-result:
	@echo "==> phase6-tidb-result ts=$(TPCC_TS)"
	@ROOT=$(TPCC_ARTIFACTS)/$(RESULT_SCOPE)/tidb-vm-6node-$(PLACEMENT)-$(ISO)-$(TPCC_TS); \
	ssh $(TPCC_CLIENT) "echo '--- .run.done ---'; cat $$ROOT/.run.done 2>/dev/null || echo '(missing)'; \
	  echo '--- [Summary] from go-tpc-stdout.txt (per-round) ---'; \
	  for f in $$ROOT/runs/threads-*/round-*/go-tpc-stdout.txt; do \
	    [ -f \"\$$f\" ] || continue; \
	    echo \"### \$$f ###\"; \
	    grep -E '^\\[Summary\\]|^tpmC|^Finished' \"\$$f\" | tail -10; \
	  done; \
	  echo '--- TiDB region leader distribution (pre-smoke) ---'; \
	  cat $$ROOT/leader-snapshot/tidb-region-leaders.txt 2>/dev/null | head -15 || echo '(no leader-snapshot)'; \
	  echo '--- WAN probe samples (rx/tx delta + chrony) ---'; \
	  ls $$ROOT/runs/wan-probe-*.txt 2>/dev/null | head -5 || echo '(no wan-probe samples)'; true"

# ===================================================================
# Phase 7 — YBDB smoke (bypass suite; gate/prepare/run/collect direct)
# ===================================================================
phase7: phase7-ybdb-smoke phase7-ybdb-result

phase7-ybdb-smoke:
	@echo "==> [start] phase7-ybdb-smoke at $$(date +%Y-%m-%dT%H:%M:%S%z) (timeout=$(TIMEOUT_PHASE7_SMOKE)s)"
	@echo "==> phase7-ybdb-smoke ts=$(TPCC_TS) placement=$(PLACEMENT)"
	@TS=$(TPCC_TS); \
	ssh $(TPCC_CLIENT) " \
	  export PHASE_NAME=$(PHASE_NAME) RESULT_SCOPE=$(RESULT_SCOPE) BASELINE_FAMILY=$(BASELINE_FAMILY) \
	         tuning_profile_id=default \
	         TPCC_TS=$$TS PLACEMENT=$(PLACEMENT) PROFILE=$(PROFILE) \
	         DB=ybdb CLIENT_ZONE=$(CLIENT_ZONE) GATE_SKIP=$(GATE_SKIP) \
	         DB_HOST=$(YBDB_HOST) DB_PORT=$(YBDB_PORT) \
	         CLUSTER_HOSTS='idc-dbhost-1@172.24.40.32 idc-dbhost-2@172.24.40.33 idc-dbhost-3@172.24.40.34 gcp-dbhost-1@10.160.152.11 gcp-dbhost-2@10.160.152.12 gcp-dbhost-3@10.160.152.13' \
	         WAREHOUSES=$(WAREHOUSES) WARMUP_SEC=$(WARMUP_SEC) \
	         ROUNDS=$(ROUNDS) THREADS_LIST='$(THREADS_LIST)' RUN_SEC=$(RUN_SEC) ROUND_SLEEP_SEC=$(ROUND_SLEEP_SEC) \
	         TPCC_ARTIFACTS=$(TPCC_ARTIFACTS)/$(RESULT_SCOPE) \
	         WAN_PROBE_ENABLED=1 WAN_PROBE_IPERF=1 \
	         YBDB_USER=yugabyte YBDB_DB=tpcc; \
	  set -e; \
	  bash $(TPCC_SCRIPTS)/gate.sh    --db ybdb --iso $(ISO) --topology vm-6node-$(PLACEMENT) --db-host $(YBDB_HOST) --ts $$TS; \
	  bash $(TPCC_SCRIPTS)/prepare.sh --db ybdb --iso $(ISO) --topology vm-6node-$(PLACEMENT) --db-host $(YBDB_HOST) --ts $$TS; \
	  echo '==> post-prepare: gate on load_move_completion=100% (reliable under read_replica; get_is_load_balancer_idle benign-Idle=0 skipped)'; \
	  converged=0; for i in \$$(seq 1 30); do \
	    out=\$$(ssh root@$(YBDB_HOST) '/opt/yugabyte/bin/yb-admin --master_addresses=$(YB_MASTER_ADDR) get_load_move_completion' 2>&1); \
	    case \"\$$out\" in *'Percent complete = 100'*|*'100.'*) echo '  load_move_completion 100% (post-prepare)'; converged=1; break;; esac; \
	    sleep 10; \
	  done; \
	  [ \"\$$converged\" = \"1\" ] || echo '[phase7] WARN: load_move_completion not 100% after 5min; proceeding (0 tablets remaining = benign)'; \
	  echo '==> pre-run: freeze YBDB load balancer to prevent tablet leader churn during timed run'; \
	  ssh root@$(YBDB_HOST) '/opt/yugabyte/bin/yb-admin --master_addresses=$(YB_MASTER_ADDR) set_load_balancer_enabled 0'; \
	  echo '  load balancer disabled'; \
	  bash $(TPCC_SCRIPTS)/run.sh     --db ybdb --iso $(ISO) --topology vm-6node-$(PLACEMENT) --db-host $(YBDB_HOST) --ts $$TS; \
	  echo '==> post-run: unfreeze YBDB load balancer'; \
	  ssh root@$(YBDB_HOST) '/opt/yugabyte/bin/yb-admin --master_addresses=$(YB_MASTER_ADDR) set_load_balancer_enabled 1' || true; \
	  bash $(TPCC_SCRIPTS)/collect.sh --db ybdb --iso $(ISO) --topology vm-6node-$(PLACEMENT) --db-host $(YBDB_HOST) --ts $$TS"
	@echo "==> phase7-ybdb leader-snapshot (tablet leader counts per tserver)"
	@ROOT=$(TPCC_ARTIFACTS)/$(RESULT_SCOPE)/ybdb-vm-6node-$(PLACEMENT)-$(ISO)-$(TPCC_TS); \
	ssh $(TPCC_CLIENT) "mkdir -p $$ROOT/leader-snapshot && \
	  ssh root@$(YBDB_HOST) '/opt/yugabyte/bin/yb-admin --master_addresses=$(YB_MASTER_ADDR) list_all_tablet_servers' > $$ROOT/leader-snapshot/ybdb-tservers.txt 2>&1 && \
	  for tbl in warehouse district customer history new_order orders order_line item stock; do \
	    echo \"### \$$tbl ###\" >> $$ROOT/leader-snapshot/ybdb-leader-counts.txt; \
	    ssh root@$(YBDB_HOST) \"/opt/yugabyte/bin/yb-admin --master_addresses=$(YB_MASTER_ADDR) list_leader_counts ysql.tpcc \$$tbl\" >> $$ROOT/leader-snapshot/ybdb-leader-counts.txt 2>&1; \
	  done; \
	  ssh root@$(YBDB_HOST) '/opt/yugabyte/bin/yb-admin --master_addresses=$(YB_MASTER_ADDR) get_universe_config' > $$ROOT/leader-snapshot/ybdb-universe-config.txt 2>&1" || true
	@echo "==> [end]   phase7-ybdb-smoke at $$(date +%Y-%m-%dT%H:%M:%S%z)"

phase7-ybdb-result:
	@echo "==> phase7-ybdb-result ts=$(TPCC_TS)"
	@ROOT=$(TPCC_ARTIFACTS)/$(RESULT_SCOPE)/ybdb-vm-6node-$(PLACEMENT)-$(ISO)-$(TPCC_TS); \
	ssh $(TPCC_CLIENT) "echo '--- .run.done ---'; cat $$ROOT/.run.done 2>/dev/null || echo '(missing)'; \
	  echo '--- [Summary] from go-tpc-stdout.txt (per-round) ---'; \
	  for f in $$ROOT/runs/threads-*/round-*/go-tpc-stdout.txt; do \
	    [ -f \"\$$f\" ] || continue; \
	    echo \"### \$$f ###\"; \
	    grep -E '^\\[Summary\\]|^tpmC|^Finished' \"\$$f\" | tail -10; \
	  done; \
	  echo '--- YBDB tablet leader counts per tserver (key tables) ---'; \
	  cat $$ROOT/leader-snapshot/ybdb-leader-counts.txt 2>/dev/null | head -50 || echo '(no leader-snapshot)'; \
	  echo '--- WAN probe samples ---'; \
	  ls $$ROOT/runs/wan-probe-*.txt 2>/dev/null | head -5 || echo '(no wan-probe samples)'; true"

# ===================================================================
# Phase 8 — CRDB smoke (bypass suite; gate/prepare/run/collect direct)
# ===================================================================
phase8: phase8-crdb-smoke phase8-crdb-result

phase8-crdb-smoke:
	@echo "==> [start] phase8-crdb-smoke at $$(date +%Y-%m-%dT%H:%M:%S%z) (timeout=$(TIMEOUT_PHASE8_SMOKE)s)"
	@echo "==> phase8-crdb-smoke ts=$(TPCC_TS) placement=$(PLACEMENT)"
	@TS=$(TPCC_TS); \
	ssh $(TPCC_CLIENT) " \
	  export PHASE_NAME=$(PHASE_NAME) RESULT_SCOPE=$(RESULT_SCOPE) BASELINE_FAMILY=$(BASELINE_FAMILY) \
	         tuning_profile_id=default \
	         TPCC_TS=$$TS PLACEMENT=$(PLACEMENT) PROFILE=$(PROFILE) \
	         DB=crdb CLIENT_ZONE=$(CLIENT_ZONE) GATE_SKIP=$(GATE_SKIP) \
	         DB_HOST=$(CRDB_HOST) DB_PORT=$(CRDB_PORT) \
	         CLUSTER_HOSTS='idc-dbhost-1@172.24.40.32 idc-dbhost-2@172.24.40.33 idc-dbhost-3@172.24.40.34 gcp-dbhost-1@10.160.152.11 gcp-dbhost-2@10.160.152.12 gcp-dbhost-3@10.160.152.13' \
	         WAREHOUSES=$(WAREHOUSES) WARMUP_SEC=$(WARMUP_SEC) \
	         ROUNDS=$(ROUNDS) THREADS_LIST='$(THREADS_LIST)' RUN_SEC=$(RUN_SEC) ROUND_SLEEP_SEC=$(ROUND_SLEEP_SEC) \
	         TPCC_ARTIFACTS=$(TPCC_ARTIFACTS)/$(RESULT_SCOPE) \
	         WAN_PROBE_ENABLED=1 WAN_PROBE_IPERF=1 \
	         CRDB_USER=root CRDB_DB=tpcc; \
	  set -e; \
	  bash $(TPCC_SCRIPTS)/gate.sh    --db crdb --iso $(ISO) --topology vm-6node-$(PLACEMENT) --db-host $(CRDB_HOST) --ts $$TS; \
	  bash $(TPCC_SCRIPTS)/prepare.sh --db crdb --iso $(ISO) --topology vm-6node-$(PLACEMENT) --db-host $(CRDB_HOST) --ts $$TS; \
	  echo '==> post-prepare: apply per-table lease_preferences=IDC (hard leader pin)'; \
	  ssh root@$(CRDB_HOST) \"awk '/^-- tpcc database 套用/{p=1}p' /root/crdb-vm6-placement-$$(echo $(PLACEMENT) | tr A-Z a-z).sql 2>/dev/null | /usr/local/bin/cockroach sql --insecure --host=$(CRDB_HOST):$(CRDB_PORT) -d tpcc\" || echo '  (warn: per-table CONFIGURE ZONE failed)'; \
	  echo '==> wait CRDB lease holders → IDC region (max 5 min, deterministic gate)'; \
	  converged=0; for i in \$$(seq 1 30); do \
	    pct=\$$(/usr/local/bin/cockroach sql --insecure --host=$(CRDB_HOST):$(CRDB_PORT) -d tpcc --format=csv -e \
	      \"SELECT IFNULL(ROUND(SUM(CASE WHEN lease_holder_locality LIKE '%region=idc%' THEN 1 ELSE 0 END) * 100.0 / NULLIF(COUNT(*),0), 1), 0) AS idc_pct FROM [SHOW RANGES FROM DATABASE tpcc WITH TABLES, DETAILS] WHERE table_name IN ('new_order','orders','warehouse','customer','district','history','order_line','item','stock');\" \
	      2>/dev/null | tail -1); \
	    case \"\$$pct\" in 100|100.*) echo '  CRDB lease holders 100% on IDC'; converged=1; break;; esac; \
	    printf '  %2d/30 leases on IDC: %s%%\n' \$$i \"\$$pct\"; \
	    sleep 10; \
	  done; \
	  [ \"\$$converged\" = \"1\" ] || { echo 'gate FAIL: CRDB lease holders not 100% IDC after 5min'; exit 1; }; \
	  bash $(TPCC_SCRIPTS)/run.sh     --db crdb --iso $(ISO) --topology vm-6node-$(PLACEMENT) --db-host $(CRDB_HOST) --ts $$TS; \
	  bash $(TPCC_SCRIPTS)/collect.sh --db crdb --iso $(ISO) --topology vm-6node-$(PLACEMENT) --db-host $(CRDB_HOST) --ts $$TS"
	@echo "==> phase8-crdb leader-snapshot (lease holder locality per range)"
	@ROOT=$(TPCC_ARTIFACTS)/$(RESULT_SCOPE)/crdb-vm-6node-$(PLACEMENT)-$(ISO)-$(TPCC_TS); \
	ssh $(TPCC_CLIENT) "mkdir -p $$ROOT/leader-snapshot && \
	  ssh root@$(CRDB_HOST) '/usr/local/bin/cockroach node status --insecure --host=$(CRDB_HOST):$(CRDB_PORT)' > $$ROOT/leader-snapshot/crdb-nodes.txt 2>&1 && \
	  ssh root@$(CRDB_HOST) \"/usr/local/bin/cockroach sql --insecure --host=$(CRDB_HOST):$(CRDB_PORT) -d tpcc -e \
	    \\\"SELECT lease_holder, lease_holder_locality, COUNT(*) AS range_count FROM [SHOW RANGES FROM DATABASE tpcc WITH TABLES, DETAILS] WHERE table_name IN ('new_order','orders','warehouse','customer','district','history','order_line','item','stock') GROUP BY lease_holder, lease_holder_locality ORDER BY range_count DESC;\\\"\" \
	  > $$ROOT/leader-snapshot/crdb-lease-holders.txt 2>&1" || true
	@echo "==> [end]   phase8-crdb-smoke at $$(date +%Y-%m-%dT%H:%M:%S%z)"
	  # TODO: validate with live cluster (crdb v26.2); fallback if gossip_nodes unavailable:
	  # SELECT lease_holder, lease_holder_locality, COUNT(*) AS range_count FROM crdb_internal.ranges
	  #   WHERE table_name IN ('new_order','orders','warehouse','customer','district','history','order_line','item','stock')
	  #   GROUP BY lease_holder, lease_holder_locality ORDER BY range_count DESC;

phase8-crdb-result:
	@echo "==> phase8-crdb-result ts=$(TPCC_TS)"
	@ROOT=$(TPCC_ARTIFACTS)/$(RESULT_SCOPE)/crdb-vm-6node-$(PLACEMENT)-$(ISO)-$(TPCC_TS); \
	ssh $(TPCC_CLIENT) "echo '--- .run.done ---'; cat $$ROOT/.run.done 2>/dev/null || echo '(missing)'; \
	  echo '--- [Summary] from go-tpc-stdout.txt (per-round) ---'; \
	  for f in $$ROOT/runs/threads-*/round-*/go-tpc-stdout.txt; do \
	    [ -f \"\$$f\" ] || continue; \
	    echo \"### \$$f ###\"; \
	    grep -E '^\\[Summary\\]|^tpmC|^Finished' \"\$$f\" | tail -10; \
	  done; \
	  echo '--- CRDB lease holder distribution (key TPCC tables) ---'; \
	  cat $$ROOT/leader-snapshot/crdb-lease-holders.txt 2>/dev/null | head -20 || echo '(no leader-snapshot)'; \
	  echo '--- WAN probe samples ---'; \
	  ls $$ROOT/runs/wan-probe-*.txt 2>/dev/null | head -5 || echo '(no wan-probe samples)'; true"

# ===================================================================
# Phase 8.5 — Fetch artifacts to MAC BEFORE destroy (critical for analysis)
# ===================================================================
phase8.5-fetch:
	@echo "==> [start] phase8.5-fetch at $$(date +%Y-%m-%dT%H:%M:%S%z) (timeout=$(TIMEOUT_PHASE85_FETCH)s)"
	@echo "==> phase8.5-fetch: ssh+tar .31 artifacts → MAC results/x-cross/$(LOCAL_RESULT_CATEGORY)/$(TPCC_TS)/"
	@echo "    (uses ssh+tar pipe; macOS openrsync v15+ silently fails on GNU rsync source)"
	@mkdir -p $(LOCAL_RESULT_ROOT)/$(TPCC_TS)
	ssh $(TPCC_CLIENT) "cd $(TPCC_ARTIFACTS)/$(RESULT_SCOPE) && tar czf - ." \
	  | tar xzf - -C $(LOCAL_RESULT_ROOT)/$(TPCC_TS)/
	@echo "==> fetched to: $(LOCAL_RESULT_ROOT)/$(TPCC_TS)/"
	@du -sh $(LOCAL_RESULT_ROOT)/$(TPCC_TS)/ 2>&1
	@ls $(LOCAL_RESULT_ROOT)/$(TPCC_TS)/ | head -10
	@echo "==> [end]   phase8.5-fetch at $$(date +%Y-%m-%dT%H:%M:%S%z)"

# ===================================================================
# Phase 9 — Teardown (FETCH first, then tunnels + terraform destroy)
# ===================================================================
# ===================================================================
# Per-DB cleanup phases — 完整解耦，跑下一個 DB test 前清掉上一個
# 用法：phase6-tidb-smoke → phase-cleanup-tidb → phase4-ybdb-deploy
#       phase7-ybdb-smoke → phase-cleanup-ybdb → phase5-crdb-deploy
# ===================================================================
phase-cleanup-tidb:
	bash phase-crossregion/scripts/cleanup-tidb.sh

phase-cleanup-ybdb:
	bash phase-crossregion/scripts/cleanup-ybdb.sh

phase9: phase8.5-fetch phase9-tunnels-stop phase9-destroy
	@echo "==> phase9 complete"

phase9-tunnels-stop:
	-@$(GCP_IAC_DIR)/tunnel.sh stop

phase9-destroy:
	@echo "==> [start] phase9-destroy at $$(date +%Y-%m-%dT%H:%M:%S%z) (timeout=$(TIMEOUT_PHASE9_DESTROY)s)"
	-cd $(GCP_IAC_DIR) && terraform destroy -auto-approve
	-cd $(IDC_IAC_DIR) && terraform destroy -auto-approve
	@echo "==> [end]   phase9-destroy at $$(date +%Y-%m-%dT%H:%M:%S%z)"

# ===================================================================
# Per-DB teardown (between phases, before next DB deploys on same VMs)
# ===================================================================
teardown-tidb:
	@echo "==> teardown-tidb (best-effort)"
	-cd $(ANSIBLE_DIR) && ansible -i inventory/crossregion.ini crossregion_cluster -m shell -a \
	  '[ -d /root/.tiup/storage/cluster/clusters/tpcc-tidb-vm6 ] && \
	   /root/.tiup/bin/tiup cluster destroy tpcc-tidb-vm6 --yes 2>&1 | tail -3 || echo no_tidb' -b -o

teardown-ybdb:
	@echo "==> teardown-ybdb (best-effort)"
	-cd $(ANSIBLE_DIR) && ansible -i inventory/crossregion.ini crossregion_cluster -m shell -a \
	  'pkill -KILL -x yb-master 2>/dev/null; pkill -KILL -x yb-tserver 2>/dev/null; \
	   pkill -KILL -x yugabyted-ui 2>/dev/null; \
	   for pid in $$(pgrep -x python3 2>/dev/null); do \
	     cmd=$$(tr "\0" " " < /proc/$$pid/cmdline 2>/dev/null); \
	     case "$$cmd" in *bin/yugabyted*) kill -KILL $$pid 2>/dev/null ;; esac; \
	   done; sleep 3; rm -rf /var/yugabyte 2>/dev/null; echo ybdb_clean' -b -o

teardown-crdb:
	@echo "==> teardown-crdb (best-effort)"
	-cd $(ANSIBLE_DIR) && ansible -i inventory/crossregion.ini crossregion_cluster -m shell -a \
	  'systemctl stop cockroach.service 2>/dev/null; \
	   for i in $$(seq 1 15); do pgrep -x cockroach >/dev/null || break; sleep 1; done; \
	   pkill -9 -x cockroach 2>/dev/null; sleep 2; \
	   rm -f /etc/systemd/system/cockroach.service; systemctl daemon-reload; \
	   rm -rf /var/lib/cockroach 2>/dev/null; echo crdb_clean' -b -o

# ===================================================================
# Convenience meta — full chain, one shared TPCC_TS across all phases
# ===================================================================
phase-crossregion-all:
	@echo "==================================================================="
	@echo "  phase-crossregion-all  TPCC_TS=$(TPCC_TS)"
	@echo "==================================================================="
	$(MAKE) phase1                TPCC_TS=$(TPCC_TS)
	$(MAKE) phase2                TPCC_TS=$(TPCC_TS)
	$(MAKE) phase3-tidb-deploy    TPCC_TS=$(TPCC_TS)
	$(MAKE) phase6-tidb-smoke     TPCC_TS=$(TPCC_TS)
	$(MAKE) phase6-tidb-result    TPCC_TS=$(TPCC_TS)
	$(MAKE) teardown-tidb         TPCC_TS=$(TPCC_TS)
	$(MAKE) phase4-ybdb-deploy    TPCC_TS=$(TPCC_TS)
	$(MAKE) phase4-ybdb-fix6n     TPCC_TS=$(TPCC_TS)
	$(MAKE) phase7-ybdb-smoke     TPCC_TS=$(TPCC_TS)
	$(MAKE) phase7-ybdb-result    TPCC_TS=$(TPCC_TS)
	$(MAKE) teardown-ybdb         TPCC_TS=$(TPCC_TS)
	$(MAKE) phase5-crdb-deploy    TPCC_TS=$(TPCC_TS)
	$(MAKE) phase8-crdb-smoke     TPCC_TS=$(TPCC_TS)
	$(MAKE) phase8-crdb-result    TPCC_TS=$(TPCC_TS)
	$(MAKE) teardown-crdb         TPCC_TS=$(TPCC_TS)
	$(MAKE) phase9                TPCC_TS=$(TPCC_TS)
	@echo "==> phase-crossregion-all complete  TPCC_TS=$(TPCC_TS)"

# ===================================================================
# Sub-rules reused verbatim from Makefile.tc1
# ===================================================================

## VM lifecycle helpers (kept for ad-hoc use; phase1 calls inline)
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

drop-idc-vms:
	cd $(IDC_IAC_DIR) && terraform destroy -auto-approve

drop-gcp-vms:
	cd $(GCP_IAC_DIR) && terraform destroy -auto-approve

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

gcp-wait-startup: gcp-tunnel-start
	@for p in $(GCP_PORTS); do \
	  echo "==> waiting startup-done on :$$p"; \
	  ssh -o StrictHostKeyChecking=accept-new -p $$p root@localhost \
	    'until [ -f /var/lib/startup-done ]; do sleep 5; done; echo done'; \
	done

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

ansible-ping: inventory-refresh-all gcp-tunnel-ensure
	cd $(ANSIBLE_DIR) && ansible all -m ping

## TPC-C client bootstrap
# ===================================================================
# Path C — freeze/unfreeze cluster scheduling (穩定 leader 分布)
# ===================================================================

# --- TiDB freeze/unfreeze ---
TIDB_PD            ?= $(TIDB_HOST)

phase-freeze-tidb:
	@echo "==> phase-freeze-tidb: dump PD config then freeze scheduling"
	@mkdir -p $(LOCAL_RESULT_ROOT)/$(TPCC_TS)
	@ssh $(TPCC_CLIENT) "curl -s http://$(TIDB_PD):2379/pd/api/v1/config" \
	  > $(LOCAL_RESULT_ROOT)/$(TPCC_TS)/pd-config-before.json
	@echo "  dumped pd-config-before.json"
	ssh $(TPCC_CLIENT) " \
	  tiup ctl:v8.5.2 pd -u http://$(TIDB_PD):2379 config set leader-schedule-limit 0; \
	  tiup ctl:v8.5.2 pd -u http://$(TIDB_PD):2379 config set region-schedule-limit 0; \
	  tiup ctl:v8.5.2 pd -u http://$(TIDB_PD):2379 config set replica-schedule-limit 0; \
	  tiup ctl:v8.5.2 pd -u http://$(TIDB_PD):2379 config set merge-schedule-limit 0; \
	  tiup ctl:v8.5.2 pd -u http://$(TIDB_PD):2379 config set hot-region-schedule-limit 0"
	@echo "==> phase-freeze-tidb: all 5 schedule limits set to 0"

phase-unfreeze-tidb:
	@echo "==> phase-unfreeze-tidb: restore PD config from pd-config-before.json"
	@test -f $(LOCAL_RESULT_ROOT)/$(TPCC_TS)/pd-config-before.json \
	  || { echo "[unfreeze-tidb] ERROR: pd-config-before.json not found at $(LOCAL_RESULT_ROOT)/$(TPCC_TS)/"; exit 1; }
	@python3 -c " \
import json, subprocess, sys; \
cfg = json.load(open('$(LOCAL_RESULT_ROOT)/$(TPCC_TS)/pd-config-before.json')); \
sched = cfg.get('schedule', {}); \
keys = ['leader-schedule-limit','region-schedule-limit','replica-schedule-limit', \
        'merge-schedule-limit','hot-region-schedule-limit']; \
cmds = []; \
[cmds.append(['ssh','$(TPCC_CLIENT)', \
  f'tiup ctl:v8.5.2 pd -u http://$(TIDB_PD):2379 config set {k} {sched.get(k, 4)}']) \
  for k in keys]; \
[subprocess.run(c, check=True) for c in cmds]; \
print('==> pd config restored')"
	@echo "==> phase-unfreeze-tidb: done"

# --- CRDB freeze/unfreeze ---
CRDB_FREEZE_DUMP   ?= $(LOCAL_RESULT_ROOT)/$(TPCC_TS)/crdb-cluster-settings-before.sql

phase-freeze-crdb:
	@echo "==> phase-freeze-crdb: dump cluster settings then freeze rebalancing"
	@mkdir -p $(LOCAL_RESULT_ROOT)/$(TPCC_TS)
	ssh $(TPCC_CLIENT) "ssh root@$(CRDB_HOST) ' \
	  /usr/local/bin/cockroach sql --insecure --host=$(CRDB_HOST):$(CRDB_PORT) \
	    --format=tsv -e \
	    \"SELECT variable, value FROM system.settings \
	       WHERE variable IN ('"'"'kv.allocator.load_based_lease_rebalancing.enabled'"'"', \
	                          '"'"'kv.range_split.by_load_enabled'"'"');\"'" \
	  > $(CRDB_FREEZE_DUMP) 2>&1
	@echo "  dumped crdb-cluster-settings-before.sql"
	ssh $(TPCC_CLIENT) "ssh root@$(CRDB_HOST) ' \
	  /usr/local/bin/cockroach sql --insecure --host=$(CRDB_HOST):$(CRDB_PORT) -e \
	    \"SET CLUSTER SETTING kv.allocator.load_based_lease_rebalancing.enabled = false; \
	      SET CLUSTER SETTING kv.range_split.by_load_enabled = false;\"'"
	@echo "==> phase-freeze-crdb: lease rebalancing + range split by load disabled"

phase-unfreeze-crdb:
	@echo "==> phase-unfreeze-crdb: restore CRDB cluster settings"
	@test -f $(CRDB_FREEZE_DUMP) \
	  || { echo "[unfreeze-crdb] ERROR: $(CRDB_FREEZE_DUMP) not found"; exit 1; }
	@python3 -c " \
lines = open('$(CRDB_FREEZE_DUMP)').readlines(); \
import subprocess; \
setting_map = {}; \
for l in lines: \
    parts = l.strip().split('\t'); \
    if len(parts) == 2: setting_map[parts[0]] = parts[1]; \
for var, val in setting_map.items(): \
    sql = f'SET CLUSTER SETTING {var} = {val};'; \
    subprocess.run(['ssh','$(TPCC_CLIENT)', \
      f'ssh root@$(CRDB_HOST) \"/usr/local/bin/cockroach sql --insecure --host=$(CRDB_HOST):$(CRDB_PORT) -e \\\"{sql}\\\"\"'], \
      check=True); \
    print(f'  restored: {var} = {val}'); \
print('==> crdb settings restored')"
	@echo "==> phase-unfreeze-crdb: done"

# --- YBDB freeze/unfreeze ---
YBDB_UNIV_DUMP     ?= $(LOCAL_RESULT_ROOT)/$(TPCC_TS)/ybdb-universe-config-before.json

phase-freeze-ybdb:
	@echo "==> phase-freeze-ybdb: dump universe config then disable load balancer"
	@mkdir -p $(LOCAL_RESULT_ROOT)/$(TPCC_TS)
	ssh $(TPCC_CLIENT) "ssh root@$(IDC_NODES_HEAD) ' \
	  /opt/yugabyte/bin/yb-admin --master_addresses=$(YB_MASTER_ADDR) get_universe_config'" \
	  > $(YBDB_UNIV_DUMP) 2>&1
	@echo "  dumped ybdb-universe-config-before.json"
	ssh $(TPCC_CLIENT) "ssh root@$(IDC_NODES_HEAD) ' \
	  /opt/yugabyte/bin/yb-admin --master_addresses=$(YB_MASTER_ADDR) set_load_balancer_enabled 0'"
	@echo "==> phase-freeze-ybdb: load balancer disabled"

phase-unfreeze-ybdb:
	@echo "==> phase-unfreeze-ybdb: re-enable YBDB load balancer"
	ssh $(TPCC_CLIENT) "ssh root@$(IDC_NODES_HEAD) ' \
	  /opt/yugabyte/bin/yb-admin --master_addresses=$(YB_MASTER_ADDR) set_load_balancer_enabled 1'"
	@echo "==> phase-unfreeze-ybdb: load balancer re-enabled"

# ===================================================================
# Path C — smoke-only targets (cluster already deployed + prepared)
# ===================================================================
# Shared var: SMOKE_ROUND (預設 1，loop 時由 caller 傳入)
SMOKE_ROUND        ?= 1

# 結果目錄結構: results/x-cross/$(LOCAL_RESULT_CATEGORY)/<TPCC_TS>/round-<N>/<db>/
SMOKE_RESULT_BASE  = $(LOCAL_RESULT_ROOT)/$(TPCC_TS)/round-$(SMOKE_ROUND)

phase-smoke-only-tidb:
	@echo "DEPRECATED: 用 phase-roundrun-only-tidb 取代 (此 target 仍保留，但含 cold-reset+warmup 的 run.sh，非純 run)"
	@echo "==> phase-smoke-only-tidb round=$(SMOKE_ROUND) W=$(WAREHOUSES) T=$(THREADS_LIST) S=$(RUN_SEC) ts=$(TPCC_TS)"
	@mkdir -p $(SMOKE_RESULT_BASE)/tidb
	@TS=$(TPCC_TS); \
	ssh $(TPCC_CLIENT) " \
	  export PHASE_NAME=$(PHASE_NAME) RESULT_SCOPE=$(RESULT_SCOPE) BASELINE_FAMILY=$(BASELINE_FAMILY) \
	         tuning_profile_id=default \
	         TPCC_TS=$$TS PLACEMENT=$(PLACEMENT) PROFILE=$(PROFILE) \
	         DB=tidb CLIENT_ZONE=$(CLIENT_ZONE) GATE_SKIP=$(GATE_SKIP) \
	         DB_HOST=$(TIDB_HOST) DB_PORT=$(TIDB_PORT) \
	         WAREHOUSES=$(WAREHOUSES) WARMUP_SEC=$(WARMUP_SEC) \
	         ROUNDS=1 THREADS_LIST='$(THREADS_LIST)' RUN_SEC=$(RUN_SEC) ROUND_SLEEP_SEC=0 \
	         TPCC_ARTIFACTS=$(TPCC_ARTIFACTS)/$(RESULT_SCOPE) \
	         WAN_PROBE_ENABLED=0 WAN_PROBE_IPERF=0 \
	         SMOKE_ROUND=$(SMOKE_ROUND); \
	  bash $(TPCC_SCRIPTS)/run.sh --db tidb --iso $(ISO) --topology vm-6node-$(PLACEMENT) --db-host $(TIDB_HOST) --ts $$TS; \
	  bash $(TPCC_SCRIPTS)/collect.sh --db tidb --iso $(ISO) --topology vm-6node-$(PLACEMENT) --db-host $(TIDB_HOST) --ts $$TS"
	@ROOT=$(TPCC_ARTIFACTS)/$(RESULT_SCOPE)/tidb-vm-6node-$(PLACEMENT)-$(ISO)-$(TPCC_TS); \
	ssh $(TPCC_CLIENT) "tar czf - -C $$ROOT/runs ." \
	  | tar xzf - -C $(SMOKE_RESULT_BASE)/tidb/ 2>/dev/null || true
	@echo "==> phase-smoke-only-tidb round=$(SMOKE_ROUND) done → $(SMOKE_RESULT_BASE)/tidb/"

phase-smoke-only-crdb:
	@echo "DEPRECATED: 用 phase-roundrun-only-crdb 取代 (此 target 仍保留，但含 cold-reset+warmup 的 run.sh，非純 run)"
	@echo "==> phase-smoke-only-crdb round=$(SMOKE_ROUND) W=$(WAREHOUSES) T=$(THREADS_LIST) S=$(RUN_SEC) ts=$(TPCC_TS)"
	@mkdir -p $(SMOKE_RESULT_BASE)/crdb
	@TS=$(TPCC_TS); \
	ssh $(TPCC_CLIENT) " \
	  export PHASE_NAME=$(PHASE_NAME) RESULT_SCOPE=$(RESULT_SCOPE) BASELINE_FAMILY=$(BASELINE_FAMILY) \
	         tuning_profile_id=default \
	         TPCC_TS=$$TS PLACEMENT=$(PLACEMENT) PROFILE=$(PROFILE) \
	         DB=crdb CLIENT_ZONE=$(CLIENT_ZONE) GATE_SKIP=$(GATE_SKIP) \
	         DB_HOST=$(CRDB_HOST) DB_PORT=$(CRDB_PORT) \
	         CLUSTER_HOSTS='idc-dbhost-1@172.24.40.32 idc-dbhost-2@172.24.40.33 idc-dbhost-3@172.24.40.34 gcp-dbhost-1@10.160.152.11 gcp-dbhost-2@10.160.152.12 gcp-dbhost-3@10.160.152.13' \
	         WAREHOUSES=$(WAREHOUSES) WARMUP_SEC=$(WARMUP_SEC) \
	         ROUNDS=1 THREADS_LIST='$(THREADS_LIST)' RUN_SEC=$(RUN_SEC) ROUND_SLEEP_SEC=0 \
	         TPCC_ARTIFACTS=$(TPCC_ARTIFACTS)/$(RESULT_SCOPE) \
	         WAN_PROBE_ENABLED=0 WAN_PROBE_IPERF=0 \
	         CRDB_USER=root CRDB_DB=tpcc SMOKE_ROUND=$(SMOKE_ROUND); \
	  bash $(TPCC_SCRIPTS)/run.sh --db crdb --iso $(ISO) --topology vm-6node-$(PLACEMENT) --db-host $(CRDB_HOST) --ts $$TS; \
	  bash $(TPCC_SCRIPTS)/collect.sh --db crdb --iso $(ISO) --topology vm-6node-$(PLACEMENT) --db-host $(CRDB_HOST) --ts $$TS"
	@ROOT=$(TPCC_ARTIFACTS)/$(RESULT_SCOPE)/crdb-vm-6node-$(PLACEMENT)-$(ISO)-$(TPCC_TS); \
	ssh $(TPCC_CLIENT) "tar czf - -C $$ROOT/runs ." \
	  | tar xzf - -C $(SMOKE_RESULT_BASE)/crdb/ 2>/dev/null || true
	@echo "==> phase-smoke-only-crdb round=$(SMOKE_ROUND) done → $(SMOKE_RESULT_BASE)/crdb/"

phase-smoke-only-ybdb:
	@echo "DEPRECATED: 用 phase-roundrun-only-ybdb 取代 (此 target 仍保留，但含 cold-reset+warmup 的 run.sh，非純 run)"
	@echo "==> phase-smoke-only-ybdb round=$(SMOKE_ROUND) W=$(WAREHOUSES) T=$(THREADS_LIST) S=$(RUN_SEC) ts=$(TPCC_TS)"
	@mkdir -p $(SMOKE_RESULT_BASE)/ybdb
	@TS=$(TPCC_TS); \
	ssh $(TPCC_CLIENT) " \
	  export PHASE_NAME=$(PHASE_NAME) RESULT_SCOPE=$(RESULT_SCOPE) BASELINE_FAMILY=$(BASELINE_FAMILY) \
	         tuning_profile_id=default \
	         TPCC_TS=$$TS PLACEMENT=$(PLACEMENT) PROFILE=$(PROFILE) \
	         DB=ybdb CLIENT_ZONE=$(CLIENT_ZONE) GATE_SKIP=$(GATE_SKIP) \
	         DB_HOST=$(YBDB_HOST) DB_PORT=$(YBDB_PORT) \
	         CLUSTER_HOSTS='idc-dbhost-1@172.24.40.32 idc-dbhost-2@172.24.40.33 idc-dbhost-3@172.24.40.34 gcp-dbhost-1@10.160.152.11 gcp-dbhost-2@10.160.152.12 gcp-dbhost-3@10.160.152.13' \
	         WAREHOUSES=$(WAREHOUSES) WARMUP_SEC=$(WARMUP_SEC) \
	         ROUNDS=1 THREADS_LIST='$(THREADS_LIST)' RUN_SEC=$(RUN_SEC) ROUND_SLEEP_SEC=0 \
	         TPCC_ARTIFACTS=$(TPCC_ARTIFACTS)/$(RESULT_SCOPE) \
	         WAN_PROBE_ENABLED=0 WAN_PROBE_IPERF=0 \
	         YBDB_USER=yugabyte YBDB_DB=tpcc SMOKE_ROUND=$(SMOKE_ROUND); \
	  bash $(TPCC_SCRIPTS)/run.sh --db ybdb --iso $(ISO) --topology vm-6node-$(PLACEMENT) --db-host $(YBDB_HOST) --ts $$TS; \
	  bash $(TPCC_SCRIPTS)/collect.sh --db ybdb --iso $(ISO) --topology vm-6node-$(PLACEMENT) --db-host $(YBDB_HOST) --ts $$TS"
	@ROOT=$(TPCC_ARTIFACTS)/$(RESULT_SCOPE)/ybdb-vm-6node-$(PLACEMENT)-$(ISO)-$(TPCC_TS); \
	ssh $(TPCC_CLIENT) "tar czf - -C $$ROOT/runs ." \
	  | tar xzf - -C $(SMOKE_RESULT_BASE)/ybdb/ 2>/dev/null || true
	@echo "==> phase-smoke-only-ybdb round=$(SMOKE_ROUND) done → $(SMOKE_RESULT_BASE)/ybdb/"

# ===================================================================
# Path C — 純 run-round-only targets (BLOCKER 2/3: 不含 cold-reset/warmup)
# 使用 run-round-only.sh：純 go-tpc tpcc run，無 prepare/restart/warmup
# ===================================================================

# WARMUP_ROUND_SEC: warmup 輪（R0）用短時 120s 跑一次後丟棄
WARMUP_ROUND_SEC   ?= 120

phase-warmup-only-tidb:
	@echo "==> phase-warmup-only-tidb (R0 warmup, 120s, discard) ts=$(TPCC_TS)"
	@mkdir -p $(LOCAL_RESULT_ROOT)/$(TPCC_TS)/round-0/tidb
	ssh $(TPCC_CLIENT) " \
	  rsync -q $(CROSS_SCRIPTS_REMOTE)/run-round-only.sh /tmp/run-round-only.sh 2>/dev/null || true; \
	  DB=tidb TIDB_HOST=$(TIDB_HOST) TIDB_PORT=$(TIDB_PORT) \
	  SMOKE_ROUND=0 WAREHOUSES=$(WAREHOUSES) RUN_SEC=$(WARMUP_ROUND_SEC) \
	  THREADS_LIST='$(THREADS_LIST)' \
	  RESULT_DIR=/tmp/poc-tpcc-warmup-$$$$ \
	  bash $(CROSS_SCRIPTS_REMOTE)/run-round-only.sh" || true
	@echo "==> phase-warmup-only-tidb R0 done (result discarded)"

phase-warmup-only-crdb:
	@echo "==> phase-warmup-only-crdb (R0 warmup, 120s, discard) ts=$(TPCC_TS)"
	ssh $(TPCC_CLIENT) " \
	  DB=crdb CRDB_HOST=$(CRDB_HOST) CRDB_PORT=$(CRDB_PORT) \
	  SMOKE_ROUND=0 WAREHOUSES=$(WAREHOUSES) RUN_SEC=$(WARMUP_ROUND_SEC) \
	  THREADS_LIST='$(THREADS_LIST)' \
	  RESULT_DIR=/tmp/poc-tpcc-warmup-$$$$ \
	  bash $(CROSS_SCRIPTS_REMOTE)/run-round-only.sh" || true
	@echo "==> phase-warmup-only-crdb R0 done (result discarded)"

phase-warmup-only-ybdb:
	@echo "==> phase-warmup-only-ybdb (R0 warmup, 120s, discard) ts=$(TPCC_TS)"
	ssh $(TPCC_CLIENT) " \
	  DB=ybdb YBDB_HOST=$(YBDB_HOST) YBDB_PORT=$(YBDB_PORT) \
	  SMOKE_ROUND=0 WAREHOUSES=$(WAREHOUSES) RUN_SEC=$(WARMUP_ROUND_SEC) \
	  THREADS_LIST='$(THREADS_LIST)' \
	  RESULT_DIR=/tmp/poc-tpcc-warmup-$$$$ \
	  bash $(CROSS_SCRIPTS_REMOTE)/run-round-only.sh" || true
	@echo "==> phase-warmup-only-ybdb R0 done (result discarded)"

# 結果目錄：遠端 client 的 RESULT_DIR
REMOTE_RESULT_DIR  = /tmp/poc-tpcc-results/$(RESULT_SCOPE)/$(TPCC_TS)

phase-roundrun-only-tidb:
	@echo "==> phase-roundrun-only-tidb round=$(SMOKE_ROUND) W=$(WAREHOUSES) T='$(THREADS_LIST)' S=$(RUN_SEC) ts=$(TPCC_TS)"
	ssh $(TPCC_CLIENT) " \
	  mkdir -p $(REMOTE_RESULT_DIR)/round-$(SMOKE_ROUND)/tidb; \
	  DB=tidb TIDB_HOST=$(TIDB_HOST) TIDB_PORT=$(TIDB_PORT) \
	  SMOKE_ROUND=$(SMOKE_ROUND) WAREHOUSES=$(WAREHOUSES) RUN_SEC=$(RUN_SEC) \
	  THREADS_LIST='$(THREADS_LIST)' \
	  RESULT_DIR=$(REMOTE_RESULT_DIR) \
	  bash $(CROSS_SCRIPTS_REMOTE)/run-round-only.sh"
	@mkdir -p $(SMOKE_RESULT_BASE)/tidb
	ssh $(TPCC_CLIENT) "tar czf - -C $(REMOTE_RESULT_DIR)/round-$(SMOKE_ROUND)/tidb ." \
	  | tar xzf - -C $(SMOKE_RESULT_BASE)/tidb/ 2>/dev/null || true
	@echo "==> phase-roundrun-only-tidb round=$(SMOKE_ROUND) done → $(SMOKE_RESULT_BASE)/tidb/"

phase-roundrun-only-crdb:
	@echo "==> phase-roundrun-only-crdb round=$(SMOKE_ROUND) W=$(WAREHOUSES) T='$(THREADS_LIST)' S=$(RUN_SEC) ts=$(TPCC_TS)"
	ssh $(TPCC_CLIENT) " \
	  mkdir -p $(REMOTE_RESULT_DIR)/round-$(SMOKE_ROUND)/crdb; \
	  DB=crdb CRDB_HOST=$(CRDB_HOST) CRDB_PORT=$(CRDB_PORT) \
	  SMOKE_ROUND=$(SMOKE_ROUND) WAREHOUSES=$(WAREHOUSES) RUN_SEC=$(RUN_SEC) \
	  THREADS_LIST='$(THREADS_LIST)' \
	  RESULT_DIR=$(REMOTE_RESULT_DIR) \
	  bash $(CROSS_SCRIPTS_REMOTE)/run-round-only.sh"
	@mkdir -p $(SMOKE_RESULT_BASE)/crdb
	ssh $(TPCC_CLIENT) "tar czf - -C $(REMOTE_RESULT_DIR)/round-$(SMOKE_ROUND)/crdb ." \
	  | tar xzf - -C $(SMOKE_RESULT_BASE)/crdb/ 2>/dev/null || true
	@echo "==> phase-roundrun-only-crdb round=$(SMOKE_ROUND) done → $(SMOKE_RESULT_BASE)/crdb/"

phase-roundrun-only-ybdb:
	@echo "==> phase-roundrun-only-ybdb round=$(SMOKE_ROUND) W=$(WAREHOUSES) T='$(THREADS_LIST)' S=$(RUN_SEC) ts=$(TPCC_TS)"
	ssh $(TPCC_CLIENT) " \
	  mkdir -p $(REMOTE_RESULT_DIR)/round-$(SMOKE_ROUND)/ybdb; \
	  DB=ybdb YBDB_HOST=$(YBDB_HOST) YBDB_PORT=$(YBDB_PORT) \
	  SMOKE_ROUND=$(SMOKE_ROUND) WAREHOUSES=$(WAREHOUSES) RUN_SEC=$(RUN_SEC) \
	  THREADS_LIST='$(THREADS_LIST)' \
	  RESULT_DIR=$(REMOTE_RESULT_DIR) \
	  bash $(CROSS_SCRIPTS_REMOTE)/run-round-only.sh"
	@mkdir -p $(SMOKE_RESULT_BASE)/ybdb
	ssh $(TPCC_CLIENT) "tar czf - -C $(REMOTE_RESULT_DIR)/round-$(SMOKE_ROUND)/ybdb ." \
	  | tar xzf - -C $(SMOKE_RESULT_BASE)/ybdb/ 2>/dev/null || true
	@echo "==> phase-roundrun-only-ybdb round=$(SMOKE_ROUND) done → $(SMOKE_RESULT_BASE)/ybdb/"

# ===================================================================
# BLOCKER 4 — TiDB leader gate: post-prepare / pre-freeze
# JOIN tikv_region_status 過濾 DB_NAME='tpcc'
# ===================================================================
phase-leader-gate-tidb-postprepare:
	@echo "==> phase-leader-gate-tidb-postprepare: wait tpcc region leaders → IDC (max 5 min)"
	@converged=0; for i in $$(seq 1 30); do \
	  pct=$$(ssh $(TPCC_CLIENT) "mysql -h $(TIDB_HOST) -P $(TIDB_PORT) -u root -BNe \
	    \"SELECT IFNULL(SUM(CASE WHEN s.LABEL LIKE '%idc%' THEN 1 ELSE 0 END) * 100.0 / NULLIF(COUNT(*),0), 0) \
	      FROM information_schema.tikv_region_peers p \
	      JOIN information_schema.tikv_store_status s ON p.STORE_ID=s.STORE_ID \
	      JOIN information_schema.tikv_region_status r ON p.REGION_ID=r.REGION_ID \
	      WHERE p.IS_LEADER=1 AND r.DB_NAME='tpcc';\"" 2>/dev/null | tail -1); \
	  case "$$pct" in 100|100.*) echo "  TiDB tpcc region leaders 100% on IDC"; converged=1; break;; esac; \
	  printf "  %2d/30 tpcc leaders on IDC: %s%%\n" $$i "$$pct"; \
	  sleep 10; \
	done; \
	[ "$$converged" = "1" ] || { echo "[leader-gate-tidb] gate FAIL — tpcc leaders not 100% IDC after 5min"; exit 1; }

# ===================================================================
# Path C — orchestration: 5 連跑 smoke (hypothesis validation)
# ===================================================================
# 前提：cluster 已跑過 phase1~7（deploy + prepare 完成）
# 跑 5 輪：R1=warmup, R2-R5 取 median
phase-c-validate-hypothesis:
	@echo "=================================================================="
	@echo "  phase-c-validate-hypothesis  TPCC_TS=$(TPCC_TS)"
	@echo "  prereq: phase1-7 已完成 (deploy + prepare done)"
	@echo "  W=$(WAREHOUSES)  T='$(THREADS_LIST)'  RUN_SEC=$(RUN_SEC)"
	@echo "=================================================================="
	@set -e; \
	FROZEN_TIDB=0; FROZEN_CRDB=0; FROZEN_YBDB=0; \
	trap ' \
	  echo "==> EXIT trap: unfreeze in reverse order (ybdb→crdb→tidb)"; \
	  if [ "$$FROZEN_YBDB" = "1" ]; then \
	    $(MAKE) phase-unfreeze-ybdb TPCC_TS=$(TPCC_TS) || echo "[trap] warn: unfreeze-ybdb failed"; \
	  fi; \
	  if [ "$$FROZEN_CRDB" = "1" ]; then \
	    $(MAKE) phase-unfreeze-crdb TPCC_TS=$(TPCC_TS) || echo "[trap] warn: unfreeze-crdb failed"; \
	  fi; \
	  if [ "$$FROZEN_TIDB" = "1" ]; then \
	    $(MAKE) phase-unfreeze-tidb TPCC_TS=$(TPCC_TS) || echo "[trap] warn: unfreeze-tidb failed"; \
	  fi' EXIT; \
	echo "==> BLOCKER4: TiDB leader gate (post-prepare, pre-freeze)"; \
	$(MAKE) phase-leader-gate-tidb-postprepare TPCC_TS=$(TPCC_TS); \
	echo "==> freeze all DBs"; \
	$(MAKE) phase-freeze-tidb TPCC_TS=$(TPCC_TS) && FROZEN_TIDB=1; \
	$(MAKE) phase-freeze-crdb TPCC_TS=$(TPCC_TS) && FROZEN_CRDB=1; \
	$(MAKE) phase-freeze-ybdb TPCC_TS=$(TPCC_TS) && FROZEN_YBDB=1; \
	echo "==> R0 warmup (discarded) for each DB"; \
	$(MAKE) phase-warmup-only-tidb TPCC_TS=$(TPCC_TS) WAREHOUSES=$(WAREHOUSES) THREADS_LIST='$(THREADS_LIST)'; \
	$(MAKE) phase-warmup-only-crdb TPCC_TS=$(TPCC_TS) WAREHOUSES=$(WAREHOUSES) THREADS_LIST='$(THREADS_LIST)'; \
	$(MAKE) phase-warmup-only-ybdb TPCC_TS=$(TPCC_TS) WAREHOUSES=$(WAREHOUSES) THREADS_LIST='$(THREADS_LIST)'; \
	echo "==> R1-R5 measurement rounds"; \
	for r in 1 2 3 4 5; do \
	  echo ""; \
	  echo "=== Path C Round $$r / 5 ==="; \
	  $(MAKE) phase-roundrun-only-tidb SMOKE_ROUND=$$r TPCC_TS=$(TPCC_TS) \
	    WAREHOUSES=$(WAREHOUSES) RUN_SEC=$(RUN_SEC) THREADS_LIST='$(THREADS_LIST)' || exit 1; \
	  $(MAKE) phase-roundrun-only-crdb SMOKE_ROUND=$$r TPCC_TS=$(TPCC_TS) \
	    WAREHOUSES=$(WAREHOUSES) RUN_SEC=$(RUN_SEC) THREADS_LIST='$(THREADS_LIST)' || exit 1; \
	  $(MAKE) phase-roundrun-only-ybdb SMOKE_ROUND=$$r TPCC_TS=$(TPCC_TS) \
	    WAREHOUSES=$(WAREHOUSES) RUN_SEC=$(RUN_SEC) THREADS_LIST='$(THREADS_LIST)' || exit 1; \
	done; \
	$(MAKE) phase-c-cv-report TPCC_TS=$(TPCC_TS)
	@echo "==> phase-c-validate-hypothesis complete  TPCC_TS=$(TPCC_TS)"

# ===================================================================
# Path C — CV report: 讀 5 round 結果，算 mean/stddev/CV per DB
# ===================================================================
phase-c-cv-report:
	@echo "==> phase-c-cv-report  TPCC_TS=$(TPCC_TS)"
	@python3 -c " \
import os, glob, statistics, re, sys; \
base = '$(LOCAL_RESULT_ROOT)/$(TPCC_TS)'; \
dbs  = ['tidb', 'crdb', 'ybdb']; \
print(''); \
print('  Path C CV Report — TPCC_TS=$(TPCC_TS)'); \
print('  W=$(WAREHOUSES)  T=$(THREADS_LIST)  RUN_SEC=$(RUN_SEC)  Rounds=5 (R0=warmup/discard, R1-R5 measured, R2-R5 analysis)'); \
print('  {:<8} {:>8} {:>8} {:>8} {:>8}  {:>10}  {:>8}  note'.format('DB','R2','R3','R4','R5','median(R2-R5)','CV%')); \
print('  ' + '-'*80); \
any_incomplete = False; \
for db in dbs: \
    tpmc_per_round = {}; \
    for r in range(1, 6): \
        pat = os.path.join(base, f'round-{r}', db, 'go-tpc-stdout.txt'); \
        files = glob.glob(pat); \
        if not files: \
            pat2 = os.path.join(base, f'round-{r}', db, '**/go-tpc-stdout.txt'); \
            files = glob.glob(pat2, recursive=True); \
        vals = []; \
        for f in files: \
            for line in open(f, errors='ignore'): \
                m = re.search(r'tpmC[=:\s]+([0-9]+\.?[0-9]*)', line, re.I); \
                if m: vals.append(float(m.group(1))); \
        tpmc_per_round[r] = max(vals) if vals else None; \
    r2 = tpmc_per_round.get(2); \
    r3 = tpmc_per_round.get(3); \
    r4 = tpmc_per_round.get(4); \
    r5 = tpmc_per_round.get(5); \
    analysis = [v for v in [r2, r3, r4, r5] if v is not None]; \
    missing = 4 - len(analysis); \
    if missing > 0: \
        any_incomplete = True; \
        note = f'INCOMPLETE (missing {missing}/4 rounds)'; \
        r2s = f\"{r2:.0f}\" if r2 else 'N/A'; \
        r3s = f\"{r3:.0f}\" if r3 else 'N/A'; \
        r4s = f\"{r4:.0f}\" if r4 else 'N/A'; \
        r5s = f\"{r5:.0f}\" if r5 else 'N/A'; \
        print(f'  {db:<8} {r2s:>8} {r3s:>8} {r4s:>8} {r5s:>8}  {\"N/A\":>10}  {\"N/A\":>8}  {note}'); \
    else: \
        med = statistics.median([r2, r3, r4, r5]); \
        mean = statistics.mean([r2, r3, r4, r5]); \
        std  = statistics.stdev([r2, r3, r4, r5]); \
        cv   = std / mean * 100 if mean else 0; \
        note = 'STABLE' if cv < 5 else ('MARGINAL' if cv < 10 else 'NOISY'); \
        print(f'  {db:<8} {r2:>8.0f} {r3:>8.0f} {r4:>8.0f} {r5:>8.0f}  {med:>10.0f}  {cv:>7.1f}%  {note}'); \
print(''); \
print('  Note: R0 discarded (warmup). R1=first run. R2-R5 analysis window (4 rounds ALL required for STABLE).'); \
print('        CV<5%=STABLE; 5-10%=MARGINAL; >10%=NOISY; missing any R2-R5 = INCOMPLETE'); \
if any_incomplete: \
    print('  WARN: one or more DB has INCOMPLETE data — check round dirs under', base); \
    sys.exit(1); \
"
	@echo "==> phase-c-cv-report done"

# === Path C .PHONY additions ===
.PHONY: \
  phase-freeze-tidb phase-unfreeze-tidb \
  phase-freeze-crdb phase-unfreeze-crdb \
  phase-freeze-ybdb phase-unfreeze-ybdb \
  phase-smoke-only-tidb phase-smoke-only-crdb phase-smoke-only-ybdb \
  phase-roundrun-only-tidb phase-roundrun-only-crdb phase-roundrun-only-ybdb \
  phase-warmup-only-tidb phase-warmup-only-crdb phase-warmup-only-ybdb \
  phase-leader-gate-tidb-postprepare \
  phase-c-validate-hypothesis phase-c-cv-report \
  phase-cleanup-on-fail \
  phase1-apply-safe phase1-wait-safe phase2-bootstrap-safe \
  phase3-tidb-deploy-safe phase4-ybdb-deploy-safe phase4-ybdb-fix6n-safe \
  phase5-crdb-deploy-safe phase6-tidb-smoke-safe phase7-ybdb-smoke-safe \
  phase8-crdb-smoke-safe phase8.5-fetch-safe phase9-destroy-safe

bootstrap-tpcc-client:
	TPCC_CLIENT=$(TPCC_CLIENT) TPCC_BASE=$(TPCC_BASE) GOTPC_VERSION=$(GOTPC_VERSION) \
	  bash $(LOCAL_SCRIPTS)/bootstrap-client.sh

clean-tpcc-artifacts:
	@echo "==> wiping $(TPCC_CLIENT):$(TPCC_ARTIFACTS)/*"
	ssh $(TPCC_CLIENT) "rm -rf $(TPCC_ARTIFACTS)/*" && \
	  echo "==> done"

# ===================================================================
# Phase 0 — Mac pre-flight (run before any long phase-crossregion flow)
# ===================================================================
PREFLIGHT_SCRIPT := $(CURDIR)/phase-crossregion/scripts/preflight-mac.sh

phase0-preflight:
	@$(PREFLIGHT_SCRIPT)

phase0-preflight-fix:
	@$(PREFLIGHT_SCRIPT) --fix

phase0-preflight-fix-only-processes:
	@pkill -9 -f "start-iap-tunnel" 2>/dev/null || true
	@pkill -9 -f "ansible-playbook"  2>/dev/null || true
	@pkill -9 -f "go-tpc"            2>/dev/null || true
	@rm -f /tmp/iap-tunnel-poc*.pid  2>/dev/null || true

# ===================================================================
# Timeout helpers — cleanup + safe wrappers
# ===================================================================

phase-cleanup-on-fail:
	@echo "==> phase-cleanup-on-fail (kill leftover background)"
	@pkill -9 -f "start-iap-tunnel" 2>/dev/null || true
	@pkill -9 -f "ansible-playbook" 2>/dev/null || true
	@pkill -9 -f "go-tpc"           2>/dev/null || true
	@rm -f /tmp/iap-tunnel-poc*.pid 2>/dev/null || true

# Helper macro — used by every -safe target below.
# $(1) = target name, $(2) = TIMEOUT var value
# If TIMEOUT_BIN is empty, warn and run without timeout.
define _safe_wrap
	@if [ -z "$(TIMEOUT_BIN)" ]; then \
	  echo "[WARN] No timeout binary found (install: brew install coreutils). Running $(1) without timeout."; \
	  $(MAKE) $(1) || { rc=$$?; echo "[FAIL] $(1) exit=$$rc"; \
	    $(MAKE) phase-cleanup-on-fail 2>/dev/null || true; exit $$rc; }; \
	else \
	  $(TIMEOUT_BIN) $(strip $(2)) $(MAKE) $(1) || \
	  { rc=$$?; echo "[TIMEOUT/FAIL] $(1) exit=$$rc after $(strip $(2))s"; \
	    $(MAKE) phase-cleanup-on-fail 2>/dev/null || true; exit $$rc; }; \
	fi
endef

phase1-apply-safe:
	$(call _safe_wrap,phase1-apply,$(TIMEOUT_PHASE1_APPLY))

phase1-wait-safe:
	$(call _safe_wrap,phase1-wait,$(TIMEOUT_PHASE1_WAIT))

phase2-bootstrap-safe:
	$(call _safe_wrap,phase2-bootstrap,$(TIMEOUT_PHASE2_BOOTSTRAP))

phase3-tidb-deploy-safe:
	$(call _safe_wrap,phase3-tidb-deploy,$(TIMEOUT_PHASE3_DEPLOY))

phase4-ybdb-deploy-safe:
	$(call _safe_wrap,phase4-ybdb-deploy,$(TIMEOUT_PHASE4_DEPLOY))

phase4-ybdb-fix6n-safe:
	$(call _safe_wrap,phase4-ybdb-fix6n,$(TIMEOUT_PHASE4_FIX6N))

phase5-crdb-deploy-safe:
	$(call _safe_wrap,phase5-crdb-deploy,$(TIMEOUT_PHASE5_DEPLOY))

phase6-tidb-smoke-safe:
	$(call _safe_wrap,phase6-tidb-smoke,$(TIMEOUT_PHASE6_SMOKE))

phase7-ybdb-smoke-safe:
	$(call _safe_wrap,phase7-ybdb-smoke,$(TIMEOUT_PHASE7_SMOKE))

phase8-crdb-smoke-safe:
	$(call _safe_wrap,phase8-crdb-smoke,$(TIMEOUT_PHASE8_SMOKE))

phase8.5-fetch-safe:
	$(call _safe_wrap,phase8.5-fetch,$(TIMEOUT_PHASE85_FETCH))

phase9-destroy-safe:
	$(call _safe_wrap,phase9-destroy,$(TIMEOUT_PHASE9_DESTROY))
