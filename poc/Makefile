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

# === Cross-region contract (run-vm6-suite.sh hard-asserts these) ===
PHASE_NAME         := phase-crossregion
RESULT_SCOPE       := X-CROSS
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
        phase1 phase1-destroy phase1-destroy-idc phase1-destroy-gcp phase1-apply phase1-wait \
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
        bootstrap-tpcc-client clean-tpcc-artifacts

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

phase1-wait: gcp-tunnel-start
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
	@echo "==> phase2-bootstrap: install go-tpc + rsync scripts (tests/common + phase-crossregion/scripts)"
	TPCC_CLIENT=$(TPCC_CLIENT) TPCC_BASE=$(TPCC_BASE) GOTPC_VERSION=$(GOTPC_VERSION) \
	  bash $(LOCAL_SCRIPTS)/bootstrap-client.sh
	ssh $(TPCC_CLIENT) 'mkdir -p $(CROSS_SCRIPTS_REMOTE)'
	rsync -avz phase-crossregion/scripts/ '$(TPCC_CLIENT):$(CROSS_SCRIPTS_REMOTE)/'

phase2-gate: gcp-tunnel-ensure
	@echo "==> phase2-gate: chrony 10-host cross-region drift gate (from MAC)"
	bash phase-crossregion/scripts/gate-chrony-cross-region.sh \
	  --ts $(TPCC_TS) --root-suffix preflight-$(TPCC_TS) --result-scope $(RESULT_SCOPE)

# ===================================================================
# Phase 3 — TiDB deploy
# ===================================================================
phase3: phase3-tidb-deploy

phase3-tidb-deploy:
	@echo "==> phase3-tidb-deploy (placement=$(PLACEMENT))"
	cd $(ANSIBLE_DIR) && ansible-playbook -i inventory/crossregion.ini \
	  playbooks/tidb-vm6.yml -e tidb_placement=$(PLACEMENT)

# ===================================================================
# Phase 4 — YBDB deploy + 6-node fix
# ===================================================================
phase4: phase4-ybdb-deploy phase4-ybdb-fix6n

phase4-ybdb-deploy:
	@echo "==> phase4-ybdb-deploy (placement=$(PLACEMENT))"
	cd $(ANSIBLE_DIR) && ansible-playbook -i inventory/crossregion.ini \
	  playbooks/yugabyte-vm6.yml -e yb_placement=$(PLACEMENT)

# Per SESSION §2.6:
#   1. GCP yugabyted restart with --advertise_address=<IPv4> to avoid IPv6 fe80 hostname bug
#   2. sleep 60 (tserver_unresponsive_timeout_ms default)
#   3. yb-admin modify_placement_info + set_preferred_zones
phase4-ybdb-fix6n:
	@echo "==> phase4-ybdb-fix6n: restart GCP yugabyted with IPv4 advertise"
	for i in 1 2 3; do \
	  port=1221$$i; ip=10.160.152.1$$i; \
	  case $$i in 1) zone=asia-east1-a;; 2) zone=asia-east1-b;; 3) zone=asia-east1-c;; esac; \
	  ssh -p $$port root@localhost " \
	    pkill -9 -x yb-master 2>/dev/null; pkill -9 -x yb-tserver 2>/dev/null; \
	    pkill -9 -x yugabyted-ui 2>/dev/null; \
	    for pid in \$$(pgrep -x python3 2>/dev/null); do \
	      cmd=\$$(tr '\\0' ' ' < /proc/\$$pid/cmdline 2>/dev/null); \
	      case \"\$$cmd\" in *bin/yugabyted*) kill -9 \$$pid 2>/dev/null ;; esac; \
	    done; sleep 3; \
	    rm -rf /var/yugabyte && mkdir -p /var/yugabyte && chown yugabyte:yugabyte /var/yugabyte; \
	    sudo -u yugabyte /opt/yugabyte/bin/yugabyted start \
	      --base_dir=/var/yugabyte \
	      --advertise_address=$$ip \
	      --join=172.24.40.32 \
	      --master_flags='enable_automatic_tablet_splitting=false,placement_cloud=104,placement_region=gcp,placement_zone='$$zone \
	      --tserver_flags='memory_limit_hard_bytes=11811160064,db_block_cache_size_percentage=50,durable_wal_write=true,require_durable_wal_write=true,yb_enable_read_committed_isolation=true,ysql_enable_auth=false,ysql_enable_auto_analyze=false,ysql_num_shards_per_tserver=1,enable_automatic_tablet_splitting=false,wait_for_ysql_backends_catalog_version_client_master_rpc_timeout_ms=300000,wait_for_ysql_backends_catalog_version_client_master_rpc_margin_ms=600000,placement_cloud=104,placement_region=gcp,placement_zone='$$zone"; \
	done
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

# ===================================================================
# Phase 5 — CRDB deploy
# ===================================================================
phase5: phase5-crdb-deploy

phase5-crdb-deploy:
	@echo "==> phase5-crdb-deploy (placement=$(PLACEMENT))"
	cd $(ANSIBLE_DIR) && ansible-playbook -i inventory/crossregion.ini \
	  playbooks/cockroach-vm6.yml -e crdb_placement=$(PLACEMENT)

# ===================================================================
# Phase 6 — TiDB smoke (run-vm6-suite.sh on .31)
# ===================================================================
phase6: phase6-tidb-smoke phase6-tidb-result

phase6-tidb-smoke:
	@echo "==> phase6-tidb-pre-smoke: wait region leaders → IDC (max 5 min, deterministic gate)"
	@for i in $$(seq 1 30); do \
	  pct=$$(ssh $(TPCC_CLIENT) "mysql -h $(TIDB_HOST) -P $(TIDB_PORT) -u root -BNe \"SELECT IFNULL(SUM(CASE WHEN s.LABEL LIKE '%idc%' THEN 1 ELSE 0 END) * 100.0 / NULLIF(COUNT(*),0), 0) FROM information_schema.tikv_region_peers p JOIN information_schema.tikv_store_status s ON p.STORE_ID=s.STORE_ID WHERE p.IS_LEADER=1;\"" 2>/dev/null | tail -1); \
	  case "$$pct" in *100|100.*) echo "  TiDB region leaders 100% on IDC"; break;; esac; \
	  printf "  %2d/30 leaders on IDC: %s%%\n" $$i "$$pct"; \
	  sleep 10; \
	done
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
	@echo "==> phase6-tidb leader-snapshot (pre/post smoke comparison)"
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
	  echo '==> post-prepare: verify load_balancer idle (Plan B deterministic gate)'; \
	  for i in \$$(seq 1 30); do \
	    out=\$$(ssh root@$(YBDB_HOST) '/opt/yugabyte/bin/yb-admin --master_addresses=$(YB_MASTER_ADDR) get_is_load_balancer_idle' 2>&1); \
	    case \"\$$out\" in *'Idle = 1'*) echo '  load_balancer idle (post-prepare)'; break;; esac; \
	    sleep 10; \
	  done; \
	  bash $(TPCC_SCRIPTS)/run.sh     --db ybdb --iso $(ISO) --topology vm-6node-$(PLACEMENT) --db-host $(YBDB_HOST) --ts $$TS; \
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
	  for i in \$$(seq 1 30); do \
	    pct=\$$(/usr/local/bin/cockroach sql --insecure --host=$(CRDB_HOST):$(CRDB_PORT) -d tpcc --format=csv -e \"SELECT IFNULL(SUM(CASE WHEN lease_holder_locality LIKE '%region=idc%' THEN 1 ELSE 0 END) * 100.0 / NULLIF(COUNT(*),0), 0) FROM crdb_internal.ranges WHERE table_name IN ('new_order','orders','warehouse','customer','district','history','order_line','item','stock');\" 2>/dev/null | tail -1); \
	    case \"\$$pct\" in 100|100.*) echo '  CRDB lease holders 100% on IDC'; break;; esac; \
	    printf '  %2d/30 leases on IDC: %s%%\n' \$$i \"\$$pct\"; \
	    sleep 10; \
	  done; \
	  bash $(TPCC_SCRIPTS)/run.sh     --db crdb --iso $(ISO) --topology vm-6node-$(PLACEMENT) --db-host $(CRDB_HOST) --ts $$TS; \
	  bash $(TPCC_SCRIPTS)/collect.sh --db crdb --iso $(ISO) --topology vm-6node-$(PLACEMENT) --db-host $(CRDB_HOST) --ts $$TS"
	@echo "==> phase8-crdb leader-snapshot (lease holder locality per range)"
	@ROOT=$(TPCC_ARTIFACTS)/$(RESULT_SCOPE)/crdb-vm-6node-$(PLACEMENT)-$(ISO)-$(TPCC_TS); \
	ssh $(TPCC_CLIENT) "mkdir -p $$ROOT/leader-snapshot && \
	  ssh root@$(CRDB_HOST) '/usr/local/bin/cockroach node status --insecure --host=$(CRDB_HOST):$(CRDB_PORT)' > $$ROOT/leader-snapshot/crdb-nodes.txt 2>&1 && \
	  ssh root@$(CRDB_HOST) \"/usr/local/bin/cockroach sql --insecure --host=$(CRDB_HOST):$(CRDB_PORT) -d tpcc -e \\\"SELECT lease_holder, lease_holder_locality, COUNT(*) as range_count FROM crdb_internal.ranges WHERE table_name IN ('new_order','orders','warehouse','customer','district','history','order_line','item','stock') GROUP BY lease_holder, lease_holder_locality ORDER BY range_count DESC;\\\"\" > $$ROOT/leader-snapshot/crdb-lease-holders.txt 2>&1" || true

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
	@echo "==> phase8.5-fetch: ssh+tar .31 artifacts → MAC results/X-CROSS/$(TPCC_TS)/"
	@echo "    (uses ssh+tar pipe; macOS openrsync v15+ silently fails on GNU rsync source)"
	@mkdir -p $(LOCAL_RESULTS)/$(RESULT_SCOPE)/$(TPCC_TS)
	ssh $(TPCC_CLIENT) "cd $(TPCC_ARTIFACTS)/$(RESULT_SCOPE) && tar czf - ." \
	  | tar xzf - -C $(LOCAL_RESULTS)/$(RESULT_SCOPE)/$(TPCC_TS)/
	@echo "==> fetched to: $(LOCAL_RESULTS)/$(RESULT_SCOPE)/$(TPCC_TS)/"
	@du -sh $(LOCAL_RESULTS)/$(RESULT_SCOPE)/$(TPCC_TS)/ 2>&1
	@ls $(LOCAL_RESULTS)/$(RESULT_SCOPE)/$(TPCC_TS)/ | head -10

# ===================================================================
# Phase 9 — Teardown (FETCH first, then tunnels + terraform destroy)
# ===================================================================
phase9: phase8.5-fetch phase9-tunnels-stop phase9-destroy
	@echo "==> phase9 complete"

phase9-tunnels-stop:
	-@$(GCP_IAC_DIR)/tunnel.sh stop

phase9-destroy:
	-cd $(GCP_IAC_DIR) && terraform destroy -auto-approve
	-cd $(IDC_IAC_DIR) && terraform destroy -auto-approve

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
bootstrap-tpcc-client:
	TPCC_CLIENT=$(TPCC_CLIENT) TPCC_BASE=$(TPCC_BASE) GOTPC_VERSION=$(GOTPC_VERSION) \
	  bash $(LOCAL_SCRIPTS)/bootstrap-client.sh

clean-tpcc-artifacts:
	@echo "==> wiping $(TPCC_CLIENT):$(TPCC_ARTIFACTS)/*"
	ssh $(TPCC_CLIENT) "rm -rf $(TPCC_ARTIFACTS)/*" && \
	  echo "==> done"
