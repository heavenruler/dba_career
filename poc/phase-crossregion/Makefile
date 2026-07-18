# ===================================================================
# Makefile — phase-crossregion (IDC↔GCP cross-region PoC, 9 phases)
#
# Authoritative location: poc/phase-crossregion/Makefile.
# Included by poc/Makefile so operator commands stay `make <target>`
# from the repo root (no `-C phase-crossregion` needed).
#
# Orchestrates the 3-DB cross-region smoke (TiDB / YBDB / CRDB) across
# IDC (172.24.40.32-34) and GCP (asia-east1-a 10.160.152.11-13) via IAP
# tunnels (localhost:12211-12215).
#
# Required IaC dirs:  iac-idc/, iac-gcp/  (terraform)
#                     ansible/playbooks/{tidb,yugabyte,cockroach}-vm6.yml
# Path convention:    All relative paths assume CWD = poc/ (repo root).
#                     Invoke `make <target>` from poc/, not from
#                     phase-crossregion/.
# Historical:         poc/Makefile.tc1 is the legacy vm-1node Makefile
#                     (pre-fork); kept for reference, NOT included.
#                     The bootstrap-tpcc-client / new-*-vms / drop-*-vms
#                     / gcp-tunnel-* / inventory-refresh* / clean-tpcc
#                     rules below are forked copies that diverged from
#                     Makefile.tc1 — DRY refactor pending.
#
# SSOT:               phase-crossregion/README.md (閱讀入口 + Phase 狀態);
#                     執行歷史 phase-crossregion/SESSION-HISTORY.md
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
GCP_ALL_IPS        := 10.160.152.11 10.160.152.12 10.160.152.13 10.160.152.14 10.160.152.15

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
# Q17（2026-07-07 拍板）：artifact 目錄 profile token，插在 placement 與 iso 之間。
# A-S = canonical 無 token（既有目錄名零變動）；A-A → -aa；A-A-RO → -aaro。
# 用遞迴展開（=）讓 target-specific PROFILE（aaro/aa smoke targets）也能生效。
PROFILE_TOKEN       = $(if $(filter A-A,$(PROFILE)),-aa,$(if $(filter A-A-RO,$(PROFILE)),-aaro,))
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
        phase6-tidb-aaro-smoke phase6-tidb-aa-smoke \
        phase7-ybdb-aaro-smoke phase7-ybdb-aa-smoke \
        phase8-crdb-aaro-smoke phase8-crdb-aa-smoke \
        phase9 phase9-destroy phase9-tunnels-stop phase8.5-static-check phase8.5-check-receipt \
        phase1-homogeneity phase1-proof \
        teardown-tidb teardown-ybdb teardown-crdb \
        phase-crossregion-all phase-crossregion-w128-suite phase-crossregion-w128-suite-pb \
        phase-crossregion-promotion-gate \
        phase-crossregion-tidb-validate phase6-tidb-smoke-dryrun \
        win-tidb-as-detach win-tidb-as-status \
        new-idc-vms new-gcp-vms drop-idc-vms drop-gcp-vms \
        gcp-tunnel-start gcp-tunnel-stop gcp-tunnel-ensure gcp-wait-startup \
        inventory-refresh gcp-inventory-refresh inventory-refresh-all ansible-ping \
        bootstrap-tpcc-client clean-tpcc-artifacts \
        phase0-preflight phase0-preflight-fix \
        phase8.5-fetch phase2-iperf3-idc phase0-preflight-fix-only-processes \
        phase-cleanup-tidb phase-cleanup-crdb phase-cleanup-ybdb

# ===================================================================
# help (default)
# ===================================================================
help:
	@echo "=== phase-crossregion 9-phase Makefile ==="
	@echo ""
	@echo "Meta:"
	@echo "  make phase-crossregion-all                  - run all 9 phases (TPCC_TS shared across phases)"
	@echo "  make phase-crossregion-w128-suite           - W=128 × N=5 cross-region P-A baseline (NEXT-STEPS Path 1.2)"
	@echo "  make phase-crossregion-w128-suite-pb        - W=128 × N=5 cross-region P-B variant (checklist #2)"
	@echo "  make phase-crossregion-promotion-gate       - Promotion checklist #9 final gate (checklist #1/#2/#7/#8)"
	@echo "  make phase-crossregion-tidb-validate        - TiDB P-A W=128 workflow validation (DRY_RUN=1, no benchmark)"
	@echo "  make win-tidb-as-detach PLACEMENT=P-A|P-B   - TiDB A-S W=128 window detached on .31 (Mac 可關機)"
	@echo "  make win-tidb-as-status PLACEMENT=... TPCC_TS=... - 查 detached window 進度 / markers"
	@echo ""
	@echo "Phase chain (run in order):"
	@echo "  make phase1                                 - destroy + apply IDC + GCP VMs + wait startup"
	@echo "  make phase2                                 - DNS/chrony fix + SSH prime + bootstrap + chrony gate"
	@echo "  make phase3-tidb-deploy                     - Ansible deploy TiDB cluster (vm-6node)"
	@echo "  make phase6-tidb-smoke TPCC_TS=<ts>         - 5-min TiDB smoke via run-vm6-suite.sh"
	@echo "  make phase6-tidb-result TPCC_TS=<ts>        - parse + print TiDB tpmC / latency"
	@echo "  make teardown-tidb                          - tiup cluster destroy (best-effort)"
	@echo "  make phase4-ybdb-deploy                     - Ansible deploy YBDB cluster"
	@echo "  make phase4-ybdb-fix6n                      - post-deploy: GCP IPv4 advertise + placement_info + preferred_zone(P-A only；P-B 不 pin leader)"
	@echo "  make phase4                                 - phase4-ybdb-deploy + phase4-ybdb-fix6n"
	@echo "  make phase7-ybdb-smoke TPCC_TS=<ts>         - 5-min YBDB smoke via run-vm6-suite.sh"
	@echo "  make phase7-ybdb-result TPCC_TS=<ts>        - parse + print YBDB tpmC / latency"
	@echo "  make teardown-ybdb                          - kill yb procs + rm /var/yugabyte"
	@echo "  make phase5-crdb-deploy                     - Ansible deploy CRDB cluster"
	@echo "  make phase8-crdb-smoke TPCC_TS=<ts>         - 5-min CRDB smoke via run-vm6-suite.sh"
	@echo "  make phase8-crdb-result TPCC_TS=<ts>        - parse + print CRDB tpmC / latency"
	@echo "  make phase6-tidb-aaro-smoke | phase6-tidb-aa-smoke TPCC_TS=<ts> - TiDB 雙 client A-A-RO / A-A smoke（Q17 目錄 token -aaro/-aa；收尾注入 gcp_side）"
	@echo "  make phase7-ybdb-aaro-smoke | phase7-ybdb-aa-smoke TPCC_TS=<ts> - YBDB 雙 client A-A-RO / A-A smoke（同上）"
	@echo "  make phase8-crdb-aaro-smoke | phase8-crdb-aa-smoke TPCC_TS=<ts> - CRDB 雙 client A-A-RO / A-A smoke（同上）"
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
phase1: phase1-destroy phase1-apply phase1-wait-via-31 phase1-homogeneity phase1-proof
	@echo "==> phase1 complete (VMs rebuilt + GCP startup-done + homogeneity + rebuild proof)"

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

# Homogeneity gate: verify all 6 nodes same OS kernel / nproc / disk
phase1-homogeneity:
	@echo "==> phase1-homogeneity: check OS kernel / nproc / disk across IDC+GCP nodes"
	@bash phase-crossregion/scripts/check-homogeneity.sh

# F4: capture VM resource IDs + boot_ids after rebuild
phase1-proof:
	@echo "==> phase1-proof: terraform resource IDs + boot_id per node → vm-rebuild-proof-$(TPCC_TS).json"
	@mkdir -p $(LOCAL_RESULT_ROOT)/$(TPCC_TS)
	@python3 $(CURDIR)/phase-crossregion/scripts/vm-rebuild-proof.py \
	  --ts $(TPCC_TS) --idc-dir $(IDC_IAC_DIR) --gcp-dir $(GCP_IAC_DIR) \
	  --out $(LOCAL_RESULT_ROOT)/$(TPCC_TS)/vm-rebuild-proof-$(TPCC_TS).json
	@echo "==> boot_id per IDC node:"
	@for ip in $(IDC_NODES); do \
	  bid=$$(ssh $(SSH_OPTS) root@$$ip 'cat /proc/sys/kernel/random/boot_id' 2>/dev/null || echo '?'); \
	  echo "  $$ip  boot_id=$$bid"; \
	done
	@echo "==> boot_id per GCP node (via .31):"
	@for ip in $(GCP_DB_IPS); do \
	  bid=$$(ssh $(SSH_OPTS) -o ProxyJump=root@$(IDC_ADMIN) root@$$ip \
	    'cat /proc/sys/kernel/random/boot_id' 2>/dev/null || echo '?'); \
	  echo "  $$ip  boot_id=$$bid"; \
	done
	@echo "==> phase1-proof complete → $(LOCAL_RESULT_ROOT)/$(TPCC_TS)/vm-rebuild-proof-$(TPCC_TS).json"

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
	@echo "==> clear stale host keys on Mac + .31 (VMs just rebuilt → host keys rotated)"
	@for ip in $(IDC_KNOWN) $(GCP_ALL_IPS); do ssh-keygen -R $$ip >/dev/null 2>&1 || true; done
	@ssh $(SSH_OPTS) root@$(IDC_ADMIN) 'for ip in $(IDC_NODES) $(GCP_ALL_IPS); do ssh-keygen -R $$ip >/dev/null 2>&1; done; true'
	@MAX_WAIT_SEC=1200 $(CURDIR)/phase-crossregion/scripts/check-gcp-via-31.sh
	@echo "==> all 5 GCP nodes READY (via .31)"

# ===================================================================
# Phase 2 — Pre-deploy init (DNS/chrony, SSH prime, bootstrap, chrony gate)
# ===================================================================
phase2: phase2-dns-fix phase2-ssh-prime phase2-bootstrap phase2-iperf3-idc phase2-probe-clients phase2-gate inventory-refresh-all
	@echo "==> phase2 complete"

# GCP probe host（g-test-poc-5=.15）需要 DB clients 才能跑 probe-iso-latency：
# tidb=mysql、ybdb=psql、共用 bc；crdb 的 cockroach binary 在 phase5-crdb-deploy
# 後從 DB 節點複製（deploy 前不存在）。
# 2026-07-14 根因：VM 每輪重建、從無安裝步驟 → 四個 suite 的 GCP probe 100% fail
# （command not found，非連線問題），fail-quiet 靜默通過直到 static-check 加斷言才抓到。
phase2-probe-clients:
	@echo "==> phase2-probe-clients: install psql/mysql/bc on GCP probe host (fail-closed)"
	ssh root@$(IDC_ADMIN) "ssh -o ConnectTimeout=5 -o BatchMode=yes -o StrictHostKeyChecking=accept-new root@10.160.152.15 ' \
	  source /etc/profile.d/proxy.sh 2>/dev/null || true; \
	  dnf install -y -q postgresql mysql bc >/dev/null 2>&1 || dnf install -y -q postgresql mysql bc; \
	  which psql mysql bc'" \
	  || { echo "[F-Gate] phase2-probe-clients FAIL — GCP probe 將全滅，中止"; exit 1; }

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

# via-31 only（硬規則：絕不走 IAP localhost:1221x）。
# .31 → GCP 免推 pubkey：terraform metadata extra_ssh_public_keys 已烘進 VM
# （phase1-wait-via-31 能從 .31 檢查 READY 即為證明）。
phase2-ssh-prime:
	@echo "==> phase2-ssh-prime: known_hosts clean + .31 self-ssh + .31→GCP prime (via-31; no IAP tunnel)"
	for ip in $(IDC_KNOWN); do ssh-keygen -R $$ip || true; done
	ssh $(SSH_OPTS) root@$(IDC_ADMIN) 'true'
	ssh root@$(IDC_ADMIN) '\
	  [ -f /root/.ssh/id_rsa ] || ssh-keygen -t rsa -N "" -f /root/.ssh/id_rsa; \
	  grep -qFf /root/.ssh/id_rsa.pub /root/.ssh/authorized_keys 2>/dev/null \
	    || cat /root/.ssh/id_rsa.pub >> /root/.ssh/authorized_keys; \
	  chmod 600 /root/.ssh/authorized_keys; \
	  ssh -o StrictHostKeyChecking=accept-new root@172.24.40.31 true'
	ssh root@$(IDC_ADMIN) 'for ip in $(IDC_NODES) $(GCP_ALL_IPS); do ssh-keygen -R $$ip 2>/dev/null; done; true'
	ssh root@$(IDC_ADMIN) 'ok=0; for ip in $(GCP_ALL_IPS); do \
	  ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 root@$$ip true && ok=$$((ok+1)); done; \
	  [ "$$ok" -eq 5 ] || { echo "ssh-prime FAIL: only $$ok/5 GCP reachable from .31"; exit 1; }; \
	  echo "  .31 → 5/5 GCP primed"'

phase2-bootstrap:
	@echo "==> [start] phase2-bootstrap at $$(date +%Y-%m-%dT%H:%M:%S%z) (timeout=$(TIMEOUT_PHASE2_BOOTSTRAP)s)"
	@echo "==> phase2-bootstrap: install go-tpc + rsync scripts + rsync ansible to .31"
	TPCC_CLIENT=$(TPCC_CLIENT) TPCC_BASE=$(TPCC_BASE) GOTPC_VERSION=$(GOTPC_VERSION) \
	  bash $(LOCAL_SCRIPTS)/bootstrap-client.sh
	ssh $(TPCC_CLIENT) 'mkdir -p $(CROSS_SCRIPTS_REMOTE) $(ANSIBLE_REMOTE_DIR) $(POC_REMOTE_ROOT)/tests'
	rsync -avz phase-crossregion/scripts/ '$(TPCC_CLIENT):$(CROSS_SCRIPTS_REMOTE)/'
	rsync -avz phase-crossregion/freeze/  '$(TPCC_CLIENT):$(CROSS_SCRIPTS_REMOTE)/freeze/'
	@echo "==> symlink /tmp/phase-crossregion/scripts (run.sh 以 \$$SELF/../../phase-crossregion/scripts 推導 wan-probe.sh)"
	ssh $(TPCC_CLIENT) 'mkdir -p /tmp/phase-crossregion && ln -sfn $(CROSS_SCRIPTS_REMOTE) /tmp/phase-crossregion/scripts'
	@echo "==> manifest.yaml → .31:/tmp/phase-crossregion/ (summary-from-stdout.py 以 parents[2] 推 repo root)"
	scp -q phase-crossregion/manifest.yaml '$(TPCC_CLIENT):/tmp/phase-crossregion/manifest.yaml'
	@echo "==> rsync ansible/ + tests/ to $(TPCC_CLIENT):$(POC_REMOTE_ROOT)/ (mirror Mac layout for relative-path SQL files)"
	rsync -avz --delete ansible/ '$(TPCC_CLIENT):$(ANSIBLE_REMOTE_DIR)/'
	rsync -avz --delete tests/   '$(TPCC_CLIENT):$(POC_REMOTE_ROOT)/tests/'
	@echo "==> [end]   phase2-bootstrap at $$(date +%Y-%m-%dT%H:%M:%S%z)"

# iperf3 binary on idc-dbhost-1（wan-probe WAN_PROBE_IPERF=1 前置；GCP 端由 cloud-init 預裝）
# server 由 wan-probe.sh 測試時臨時起（-s -1 單次即退），不建常駐 unit → --install-only
phase2-iperf3-idc:
	@echo "==> phase2-iperf3-idc: install iperf3 binary on idc-dbhost-1 (install-only)"
	bash phase-crossregion/scripts/idc-iperf3-bootstrap.sh --execute --install-only

phase2-gate:
	@echo "==> phase2-gate: chrony 10-host cross-region drift gate (via .31 ProxyJump; GCP_VIA_31=1)"
	@ok=0; for i in 1 2 3; do \
	  GCP_VIA_31=1 bash phase-crossregion/scripts/gate-chrony-cross-region.sh \
	    --ts $(TPCC_TS) --root-suffix preflight-$(TPCC_TS) --result-scope $(RESULT_SCOPE) && { ok=1; break; }; \
	  echo "==> chrony gate attempt $$i FAIL — retry in 60s (快速開機後 chrony 可能未收斂)"; \
	  [ $$i -lt 3 ] && sleep 60; \
	done; \
	[ "$$ok" = "1" ] || { echo "phase2-gate FAIL after 3 attempts"; exit 1; }

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

phase4-ybdb-deploy: phase-cleanup-crdb
	@echo "==> [start] phase4-ybdb-deploy at $$(date +%Y-%m-%dT%H:%M:%S%z) (timeout=$(TIMEOUT_PHASE4_DEPLOY)s)"
	@echo "==> phase4-ybdb-deploy (placement=$(PLACEMENT)) — controller=.31"
	ssh $(TPCC_CLIENT) "cd $(ANSIBLE_REMOTE_DIR) && ansible-playbook -i $(ANSIBLE_INV_VIA31) \
	  playbooks/yugabyte-vm6.yml -e yb_placement=$(PLACEMENT)"
	@echo "==> [end]   phase4-ybdb-deploy at $$(date +%Y-%m-%dT%H:%M:%S%z)"

# Per SESSION §2.6:
#   1. GCP yugabyted restart with --advertise_address=<IPv4> to avoid IPv6 fe80 hostname bug
#   2. sleep 60 (tserver_unresponsive_timeout_ms default)
#   3. yb-admin modify_placement_info + set_preferred_zones（P-A）
# PLACEMENT 分流（2026-07-17）：P-A 行為完全不變；P-B 副本布局同 P-A（idc:2+gcp:1）
# 但不 set_preferred_zones（不 pin leader，讓 LB 自然分散）。quorum gate 兩者照跑。
phase4-ybdb-fix6n:
	@echo "==> [start] phase4-ybdb-fix6n at $$(date +%Y-%m-%dT%H:%M:%S%z) (timeout=$(TIMEOUT_PHASE4_FIX6N)s)"
	@echo "==> phase4-ybdb-fix6n: GCP restart loop skipped — playbook now advertises IPv4 directly via ansible_host"
	@echo "    (revisit if Plan B placement still fails; restart logic moved to scripts/fix6n-gcp-restart.sh if needed)"
	@echo "==> sleep 60 (waiting tserver register)"
	sleep 60
	@echo "==> master-quorum gate: enforce 3-IDC-only raft + current_masters conf 校正 + 6/6 YSQL 健檢 (fail-closed)"
	ssh $(TPCC_CLIENT) "bash $(CROSS_SCRIPTS_REMOTE)/ybdb-master-quorum-gate.sh"
	@echo "==> runtime gflag enforce+verify: transaction_rpc_timeout_ms=15000（yugabyted --tserver_flags 對部分 runtime flag 不生效，0717/0718 varz 實證；fail-closed）"
	ssh $(TPCC_CLIENT) "bash $(CROSS_SCRIPTS_REMOTE)/ybdb-runtime-gflags.sh"
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
ifeq ($(PLACEMENT),P-B)
	@echo "==> P-B live placement: 2 IDC + 1 GCP voter (RF=3)，leader 不 pin — 由 LB 自然分散"
	@echo "    (副本布局與 P-A 完全相同——P-B 差異只在 leader 分散。"
	@echo "     S3 取捨：yb-admin set_preferred_zones 雖可多 zone 並列，但跨版本對"
	@echo "     『同優先級多 zone』的 leader 均衡行為保證不足；保守做法 = 完全不設"
	@echo "     preferred_zones（deploy 為 fresh cluster、無殘留 pin），LB 依 raft 自然"
	@echo "     分佈 leader，與 prepare.sh P-B gate 30-70% spread 口徑一致。)"
	-ssh root@$(IDC_NODES_HEAD) "/opt/yugabyte/bin/yb-admin --master_addresses=$(YB_MASTER_ADDR) delete_read_replica_placement_info" 2>/dev/null
	ssh root@$(IDC_NODES_HEAD) "/opt/yugabyte/bin/yb-admin --master_addresses=$(YB_MASTER_ADDR) modify_placement_info '104.idc.vlan241:2,104.gcp.asia-east1:1' 3"
	@echo "==> skip set_preferred_zones（P-B：不 pin leader，讓 LB 自然分散）"
else
	@echo "==> P-A live placement: 2 IDC + 1 GCP voter (RF=3)，leader 由 preferred_zones 固定 IDC"
	@echo "    (2026-07-13 修正：前版 Plan B 的 read_replica 要求 placement_uuid=ybdb_gcp_rr 的 tserver，"
	@echo "     但 playbook 從未設此 flag → RR tablet 永不實體化，GCP SST=0B、資料零同步。"
	@echo "     改 live 2+1 對齊 TiDB/CRDB 語意：quorum 2/3 由 IDC pair 滿足、commit 不等 WAN，"
	@echo "     GCP follower 持續收 raft log = IDC CRUD 同步 GCP 可驗。"
	@echo "     GCP 三台 tserver 統一 placement_zone=asia-east1（playbook 07-13 改），"
	@echo "     LB 把各 tablet 的 GCP 副本均衡到 .11/.12/.13 三台。)"
	-ssh root@$(IDC_NODES_HEAD) "/opt/yugabyte/bin/yb-admin --master_addresses=$(YB_MASTER_ADDR) delete_read_replica_placement_info" 2>/dev/null
	ssh root@$(IDC_NODES_HEAD) "/opt/yugabyte/bin/yb-admin --master_addresses=$(YB_MASTER_ADDR) modify_placement_info '104.idc.vlan241:2,104.gcp.asia-east1:1' 3"
	@echo "==> set_preferred_zones = IDC（tablet leader 全數固定 IDC）"
	ssh root@$(IDC_NODES_HEAD) "/opt/yugabyte/bin/yb-admin --master_addresses=$(YB_MASTER_ADDR) set_preferred_zones 104.idc.vlan241"
endif
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
	@echo "==> health check: all 6 expected tservers ALIVE (3 IDC + 3 GCP，GCP 統一 zone 分擔 tablet 副本)"
	@alive=$$(ssh root@$(IDC_NODES_HEAD) "/opt/yugabyte/bin/yb-admin --master_addresses=$(YB_MASTER_ADDR) list_all_tablet_servers" 2>/dev/null | grep -c ALIVE); \
	echo "  ALIVE tservers: $$alive (expect 6)"; \
	[ $$alive -ge 6 ] || { echo "[fix6n] health check FAIL — abort"; exit 1; }
ifeq ($(PLACEMENT),P-B)
	@echo "==> verify placement: live = idc:2 + gcp(asia-east1):1, preferred zone = (none, P-B)"
else
	@echo "==> verify placement: live = idc:2 + gcp(asia-east1):1, preferred zone = idc"
endif
	ssh root@$(IDC_NODES_HEAD) "/opt/yugabyte/bin/yb-admin --master_addresses=$(YB_MASTER_ADDR) get_universe_config" | python3 -m json.tool | head -50
	@echo "==> [end]   phase4-ybdb-fix6n at $$(date +%Y-%m-%dT%H:%M:%S%z)"

# ===================================================================
# Phase 5 — CRDB deploy
# ===================================================================
phase5: phase5-crdb-deploy

phase5-crdb-deploy: phase-cleanup-tidb
	@echo "==> [start] phase5-crdb-deploy at $$(date +%Y-%m-%dT%H:%M:%S%z) (timeout=$(TIMEOUT_PHASE5_DEPLOY)s)"
	@echo "==> phase5-crdb-deploy (placement=$(PLACEMENT)) — controller=.31"
	ssh $(TPCC_CLIENT) "cd $(ANSIBLE_REMOTE_DIR) && ansible-playbook -i $(ANSIBLE_INV_VIA31) \
	  playbooks/cockroach-vm6.yml -e crdb_placement=$(PLACEMENT)"
	@echo "==> copy cockroach binary → GCP probe host .15（probe-iso-latency crdb 分支需要；fail-closed）"
	ssh $(TPCC_CLIENT) "ssh root@$(CRDB_HOST) 'cat /usr/local/bin/cockroach' | \
	  ssh -o StrictHostKeyChecking=accept-new root@10.160.152.15 'cat > /usr/local/bin/cockroach && chmod +x /usr/local/bin/cockroach && /usr/local/bin/cockroach version | head -2'" \
	  || { echo "[F-Gate] cockroach binary → .15 FAIL — GCP probe 將全滅，中止"; exit 1; }
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
	         WAN_PROBE_ENABLED=1 WAN_PROBE_IPERF=1 \
	         GCP_PROBE_DB_HOST=10.160.152.11; \
	  bash $(CROSS_SCRIPTS_REMOTE)/run-vm6-suite.sh \
	    --db tidb --topology vm-6node-$(PLACEMENT)$(PROFILE_TOKEN) --ts $$TS"
	@echo "==> phase6-tidb-post-prepare leader gate: wait tpcc region leaders → IDC (max 5 min)"
	@converged=0; for i in $$(seq 1 30); do \
	  pct=$$(ssh $(TPCC_CLIENT) "mysql -h $(TIDB_HOST) -P $(TIDB_PORT) -u root -BNe \"SELECT IFNULL(SUM(CASE WHEN s.LABEL LIKE '%idc%' THEN 1 ELSE 0 END) * 100.0 / NULLIF(COUNT(*),0), 0) FROM information_schema.tikv_region_peers p JOIN information_schema.tikv_store_status s ON p.STORE_ID=s.STORE_ID JOIN information_schema.tikv_region_status r ON p.REGION_ID=r.REGION_ID WHERE p.IS_LEADER=1 AND r.DB_NAME='tpcc';\"" 2>/dev/null | tail -1); \
	  case "$$pct" in *100|100.*) echo "  TiDB tpcc region leaders 100% on IDC"; converged=1; break;; esac; \
	  printf "  %2d/30 tpcc leaders on IDC: %s%%\n" $$i "$$pct"; \
	  sleep 10; \
	done; \
	[ "$$converged" = "1" ] || { echo "gate FAIL: TiDB tpcc leaders not 100% IDC after 5min"; exit 1; }
	@echo "==> phase6-tidb leader-snapshot (post-run tpcc-scoped placement verification)"
	@ROOT=$(TPCC_ARTIFACTS)/$(RESULT_SCOPE)/tidb-vm-6node-$(PLACEMENT)$(PROFILE_TOKEN)-$(ISO)-$(TPCC_TS); \
	ssh $(TPCC_CLIENT) "mkdir -p $$ROOT/leader-snapshot && \
	  mysql -h $(TIDB_HOST) -P $(TIDB_PORT) -u root -e \"SELECT \
	    p.STORE_ID, s.ADDRESS, s.STORE_STATE_NAME, s.LABEL, \
	    COUNT(*) as leader_count \
	    FROM information_schema.tikv_region_peers p \
	    JOIN information_schema.tikv_store_status s ON p.STORE_ID=s.STORE_ID \
	    JOIN information_schema.tikv_region_status r ON p.REGION_ID=r.REGION_ID \
	    WHERE p.IS_LEADER=1 AND r.DB_NAME='tpcc' \
	    GROUP BY p.STORE_ID, s.ADDRESS, s.STORE_STATE_NAME, s.LABEL \
	    ORDER BY leader_count DESC;\" > $$ROOT/leader-snapshot/tidb-region-leaders.txt 2>&1" || true
	@echo "==> [end]   phase6-tidb-smoke at $$(date +%Y-%m-%dT%H:%M:%S%z)"

phase6-tidb-result:
	@echo "==> phase6-tidb-result ts=$(TPCC_TS)"
	@ROOT=$(TPCC_ARTIFACTS)/$(RESULT_SCOPE)/tidb-vm-6node-$(PLACEMENT)$(PROFILE_TOKEN)-$(ISO)-$(TPCC_TS); \
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
# Phase 7 — YBDB smoke (run-vm6-suite.sh on .31)
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
	         GCP_PROBE_DB_HOST=10.160.152.11 \
	         YBDB_USER=yugabyte YBDB_DB=tpcc; \
	  bash $(CROSS_SCRIPTS_REMOTE)/run-vm6-suite.sh \
	    --db ybdb --topology vm-6node-$(PLACEMENT)$(PROFILE_TOKEN) --ts $$TS"
	@echo "==> phase7-ybdb leader-snapshot (tablet leader counts per tserver)"
	@ROOT=$(TPCC_ARTIFACTS)/$(RESULT_SCOPE)/ybdb-vm-6node-$(PLACEMENT)$(PROFILE_TOKEN)-$(ISO)-$(TPCC_TS); \
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
	@ROOT=$(TPCC_ARTIFACTS)/$(RESULT_SCOPE)/ybdb-vm-6node-$(PLACEMENT)$(PROFILE_TOKEN)-$(ISO)-$(TPCC_TS); \
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
# Phase 8 — CRDB smoke (run-vm6-suite.sh on .31)
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
	         GCP_PROBE_DB_HOST=10.160.152.11 \
	         CRDB_USER=root CRDB_DB=tpcc; \
	  bash $(CROSS_SCRIPTS_REMOTE)/run-vm6-suite.sh \
	    --db crdb --topology vm-6node-$(PLACEMENT)$(PROFILE_TOKEN) --ts $$TS"
	@echo "==> phase8-crdb leader-snapshot (lease holder locality per range)"
	@ROOT=$(TPCC_ARTIFACTS)/$(RESULT_SCOPE)/crdb-vm-6node-$(PLACEMENT)$(PROFILE_TOKEN)-$(ISO)-$(TPCC_TS); \
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
	@ROOT=$(TPCC_ARTIFACTS)/$(RESULT_SCOPE)/crdb-vm-6node-$(PLACEMENT)$(PROFILE_TOKEN)-$(ISO)-$(TPCC_TS); \
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
# A-A-RO / A-A dual-client smoke — run-vm6-aa.sh on .31（Q16 Win-2/3 前置）
#
# 與 phase7-ybdb-smoke 同款 env 合約；差異：
#   - PROFILE=A-A-RO|A-A 由 target-specific 變數指定 → 目錄帶 Q17 token（-aaro/-aa）
#   - 雙 client：IDC=.31（standard mix）+ GCP=g-test-poc-5（.31 直連 .15，不走 IAP；
#     A-A-RO 走 read-only mix、A-A 同 standard mix）
#   - 收尾：summary-from-stdout.py（IDC 主表，欄位零變動）→
#     summary-gcp-side.py 注入頂層 gcp_side（G2/G3，2026-07-15 拍板）
# 參數: $(1)=db  $(2)=IDC writer host  $(3)=DB port  $(4)=per-DB extra env
# ===================================================================
define _aa_smoke_recipe
	@echo "==> [start] $@ at $$(date +%Y-%m-%dT%H:%M:%S%z)"
	@echo "==> $@ ts=$(TPCC_TS) placement=$(PLACEMENT) profile=$(PROFILE) token=$(PROFILE_TOKEN)"
	@TS=$(TPCC_TS); \
	ssh $(TPCC_CLIENT) " \
	  export PHASE_NAME=$(PHASE_NAME) RESULT_SCOPE=$(RESULT_SCOPE) BASELINE_FAMILY=$(BASELINE_FAMILY) \
	         tuning_profile_id=default \
	         TPCC_TS=$$TS PLACEMENT=$(PLACEMENT) PROFILE=$(PROFILE) \
	         DB=$(1) CLIENT_ZONE=$(CLIENT_ZONE) GATE_SKIP=$(GATE_SKIP) \
	         IDC_CLIENT=root@$(IDC_ADMIN) \
	         GCP_CLIENT_SSH=root@10.160.152.15 GCP_CLIENT_PORT=22 GCP_CLIENT_IP=10.160.152.15 \
	         IDC_DB_HOST=$(2) IDC_DB_PORT=$(3) \
	         GCP_DB_HOST=10.160.152.11 GCP_DB_PORT=$(3) \
	         CLUSTER_HOSTS='idc-dbhost-1@172.24.40.32 idc-dbhost-2@172.24.40.33 idc-dbhost-3@172.24.40.34 gcp-dbhost-1@10.160.152.11 gcp-dbhost-2@10.160.152.12 gcp-dbhost-3@10.160.152.13' \
	         WAREHOUSES=$(WAREHOUSES) WARMUP_SEC=$(WARMUP_SEC) \
	         ROUNDS=$(ROUNDS) THREADS_LIST='$(THREADS_LIST)' RUN_SEC=$(RUN_SEC) ROUND_SLEEP_SEC=$(ROUND_SLEEP_SEC) \
	         TPCC_ARTIFACTS=$(TPCC_ARTIFACTS)/$(RESULT_SCOPE) \
	         WAN_PROBE_ENABLED=1 WAN_PROBE_IPERF=1 \
	         GCP_PROBE_DB_HOST=10.160.152.11 \
	         $(4); \
	  bash $(CROSS_SCRIPTS_REMOTE)/run-vm6-aa.sh \
	    --db $(1) --topology vm-6node-$(PLACEMENT)$(PROFILE_TOKEN) --ts $$TS"
	@echo "==> $@ summary: IDC 主表 + gcp_side 注入（G2/G3；summary-gcp-side.py）"
	@ROOT=$(TPCC_ARTIFACTS)/$(RESULT_SCOPE)/$(1)-vm-6node-$(PLACEMENT)$(PROFILE_TOKEN)-$(ISO)-$(TPCC_TS); \
	ssh $(TPCC_CLIENT) " \
	  python3 $(TPCC_SCRIPTS)/summary-from-stdout.py --warehouses $(WAREHOUSES) \
	    --phase $(PHASE_NAME) --result-scope $(RESULT_SCOPE) --baseline-family $(BASELINE_FAMILY) \
	    $$ROOT && \
	  python3 $(CROSS_SCRIPTS_REMOTE)/summary-gcp-side.py --profile $(PROFILE) $$ROOT"
	@echo "==> [end]   $@ at $$(date +%Y-%m-%dT%H:%M:%S%z)"
endef

phase6-tidb-aaro-smoke: PROFILE = A-A-RO
phase6-tidb-aaro-smoke:
	$(call _aa_smoke_recipe,tidb,$(TIDB_HOST),$(TIDB_PORT),TIDB_USER=root TIDB_DB=tpcc)

phase6-tidb-aa-smoke: PROFILE = A-A
phase6-tidb-aa-smoke:
	$(call _aa_smoke_recipe,tidb,$(TIDB_HOST),$(TIDB_PORT),TIDB_USER=root TIDB_DB=tpcc)

phase7-ybdb-aaro-smoke: PROFILE = A-A-RO
phase7-ybdb-aaro-smoke:
	$(call _aa_smoke_recipe,ybdb,$(YBDB_HOST),$(YBDB_PORT),YBDB_USER=yugabyte YBDB_DB=tpcc)

phase7-ybdb-aa-smoke: PROFILE = A-A
phase7-ybdb-aa-smoke:
	$(call _aa_smoke_recipe,ybdb,$(YBDB_HOST),$(YBDB_PORT),YBDB_USER=yugabyte YBDB_DB=tpcc)

phase8-crdb-aaro-smoke: PROFILE = A-A-RO
phase8-crdb-aaro-smoke:
	$(call _aa_smoke_recipe,crdb,$(CRDB_HOST),$(CRDB_PORT),CRDB_USER=root CRDB_DB=tpcc)

phase8-crdb-aa-smoke: PROFILE = A-A
phase8-crdb-aa-smoke:
	$(call _aa_smoke_recipe,crdb,$(CRDB_HOST),$(CRDB_PORT),CRDB_USER=root CRDB_DB=tpcc)

# ===================================================================
# Phase 8.5 — Correctness gate (static-check before fetch; per audit §6 #8)
# ===================================================================
# Verifies on .31: each DB suite has summary.json + .suite.done + placement-gate artifact;
# no fake/synthetic keywords in summary.json; fails closed → blocks phase9 destroy.
phase8.5-static-check:
	@echo "==> phase8.5-static-check: artifact schema check on .31 before fetch"
	@ssh $(TPCC_CLIENT) "python3 $(CROSS_SCRIPTS_REMOTE)/check-static-artifacts.py '$(TPCC_ARTIFACTS)/$(RESULT_SCOPE)' --ts '$(TPCC_TS)'" \
		|| { echo "[F-Gate] phase8.5-static-check FAIL — fix artifacts before destroy"; exit 1; }
	@echo "==> phase8.5-static-check PASS"

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
	@echo "==> F3: writing fetch-receipt (summary.json count + sha256)"
	@python3 -c " \
import os, glob, hashlib, json, datetime; \
base='$(LOCAL_RESULT_ROOT)/$(TPCC_TS)'; \
summaries=glob.glob(os.path.join(base,'**','summary.json'),recursive=True); \
checksums={}; \
[checksums.update({os.path.relpath(f,base): hashlib.sha256(open(f,'rb').read()).hexdigest()}) for f in summaries]; \
suite_dones=glob.glob(os.path.join(base,'**','.suite.done'),recursive=True); \
receipt={'ts':'$(TPCC_TS)','fetched_at':datetime.datetime.now().strftime('%Y-%m-%dT%H:%M:%S%z'), \
  'summary_json_count':len(summaries),'suite_done_count':len(suite_dones), \
  'local_root':base,'checksums':checksums}; \
out=os.path.join(base,'fetch-receipt.json'); \
json.dump(receipt,open(out,'w'),indent=2); \
print(f'  summary_json={len(summaries)}  suite_done={len(suite_dones)}  receipt={out}')" || { echo "[F3] receipt write FAIL"; exit 1; }
	@echo "==> [end]   phase8.5-fetch at $$(date +%Y-%m-%dT%H:%M:%S%z)"

# F3: gate — verify receipt exists and has at least 1 summary before destroy
phase8.5-check-receipt:
	@echo "==> phase8.5-check-receipt: verify fetch-receipt.json exists + summary_json_count > 0"
	@test -f $(LOCAL_RESULT_ROOT)/$(TPCC_TS)/fetch-receipt.json \
	  || { echo "[F3] FAIL: fetch-receipt.json not found — run phase8.5-fetch first"; exit 1; }
	@python3 -c " \
import json, sys; \
r=json.load(open('$(LOCAL_RESULT_ROOT)/$(TPCC_TS)/fetch-receipt.json')); \
n=r.get('summary_json_count',0); \
print(f'  summary_json_count={n}  suite_done_count={r.get(\"suite_done_count\",0)}'); \
sys.exit(0 if n>0 else 1)" || { echo "[F3] FAIL: no summary.json fetched"; exit 1; }
	@echo "==> phase8.5-check-receipt PASS"

# ===================================================================
# Phase 9 — Teardown (FETCH first, then tunnels + terraform destroy)
# ===================================================================
# ===================================================================
# Per-DB cleanup phases — 完整解耦，跑下一個 DB test 前清掉上一個
# 用法（per decisions Q9 / Q11，順序 TiDB → CRDB → YBDB）：
#   phase6-tidb-smoke → phase-cleanup-tidb → phase5-crdb-deploy
#   phase8-crdb-smoke → phase-cleanup-crdb → phase4-ybdb-deploy
#   phase7-ybdb-smoke → phase-cleanup-ybdb → phase9
# ===================================================================
phase-cleanup-tidb:
	bash phase-crossregion/scripts/cleanup-tidb.sh

phase-cleanup-crdb:
	bash phase-crossregion/scripts/cleanup-crdb.sh

phase-cleanup-ybdb:
	bash phase-crossregion/scripts/cleanup-ybdb.sh

phase9: phase8.5-static-check phase8.5-fetch phase8.5-check-receipt phase9-tunnels-stop phase9-destroy
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
# teardown 一律在 .31 上執行（crossregion-via31.ini 設計即為 .31 controller；
# Mac 直連 10.160.152.x 不通 → GCP 端清掃會漏，污染下一 cell）
teardown-tidb:
	@echo "==> teardown-tidb (best-effort; ansible on .31)"
	-ssh $(TPCC_CLIENT) "cd $(ANSIBLE_REMOTE_DIR) && ansible -i $(ANSIBLE_INV_VIA31) crossregion_cluster -m shell -a \
	  '[ -d /root/.tiup/storage/cluster/clusters/tpcc-tidb-vm6 ] && \
	   /root/.tiup/bin/tiup cluster destroy tpcc-tidb-vm6 --yes 2>&1 | tail -3 || echo no_tidb' -b -o"

teardown-ybdb:
	@echo "==> teardown-ybdb (best-effort; ansible on .31)"
	-ssh $(TPCC_CLIENT) "cd $(ANSIBLE_REMOTE_DIR) && ansible -i $(ANSIBLE_INV_VIA31) crossregion_cluster -m shell -a \
	  'pkill -KILL -x yb-master 2>/dev/null; pkill -KILL -x yb-tserver 2>/dev/null; \
	   pkill -KILL -x yugabyted-ui 2>/dev/null; \
	   for pid in \$$(pgrep -x python3 2>/dev/null); do \
	     cmd=\$$(tr \"\0\" \" \" < /proc/\$$pid/cmdline 2>/dev/null); \
	     case \"\$$cmd\" in *bin/yugabyted*) kill -KILL \$$pid 2>/dev/null ;; esac; \
	   done; sleep 3; rm -rf /var/yugabyte 2>/dev/null; echo ybdb_clean' -b -o"

teardown-crdb:
	@echo "==> teardown-crdb (best-effort; ansible on .31)"
	-ssh $(TPCC_CLIENT) "cd $(ANSIBLE_REMOTE_DIR) && ansible -i $(ANSIBLE_INV_VIA31) crossregion_cluster -m shell -a \
	  'systemctl stop cockroach.service 2>/dev/null; \
	   for i in \$$(seq 1 15); do pgrep -x cockroach >/dev/null || break; sleep 1; done; \
	   pkill -9 -x cockroach 2>/dev/null; sleep 2; \
	   rm -f /etc/systemd/system/cockroach.service; systemctl daemon-reload; \
	   rm -rf /var/lib/cockroach 2>/dev/null; echo crdb_clean' -b -o"

# ===================================================================
# Convenience meta — full chain, one shared TPCC_TS across all phases
# ===================================================================
phase-crossregion-all:
	@echo "==================================================================="
	@echo "  phase-crossregion-all  TPCC_TS=$(TPCC_TS)"
	@echo "==================================================================="
	$(MAKE) phase1                TPCC_TS=$(TPCC_TS)
	$(MAKE) phase2                TPCC_TS=$(TPCC_TS)
	# DB cell sequence: TiDB → CRDB → YBDB (per decisions Q9 / Q11)
	# 注意：phase3/4/5 編號為歷史命名（4=ybdb, 5=crdb），執行順序以 Q9 為準
	$(MAKE) phase3-tidb-deploy    TPCC_TS=$(TPCC_TS)
	$(MAKE) phase6-tidb-smoke     TPCC_TS=$(TPCC_TS)
	$(MAKE) phase6-tidb-result    TPCC_TS=$(TPCC_TS)
	$(MAKE) phase8.5-static-check TPCC_TS=$(TPCC_TS)   # Q12 per-cell gate #8
	$(MAKE) teardown-tidb         TPCC_TS=$(TPCC_TS)
	$(MAKE) phase5-crdb-deploy    TPCC_TS=$(TPCC_TS)
	$(MAKE) phase8-crdb-smoke     TPCC_TS=$(TPCC_TS)
	$(MAKE) phase8-crdb-result    TPCC_TS=$(TPCC_TS)
	$(MAKE) phase8.5-static-check TPCC_TS=$(TPCC_TS)   # Q12 per-cell gate #8
	$(MAKE) teardown-crdb         TPCC_TS=$(TPCC_TS)
	$(MAKE) phase4-ybdb-deploy    TPCC_TS=$(TPCC_TS)
	$(MAKE) phase4-ybdb-fix6n     TPCC_TS=$(TPCC_TS)
	$(MAKE) phase7-ybdb-smoke     TPCC_TS=$(TPCC_TS)
	$(MAKE) phase7-ybdb-result    TPCC_TS=$(TPCC_TS)
	$(MAKE) phase8.5-static-check TPCC_TS=$(TPCC_TS)   # Q12 per-cell gate #8 (all 3 cells)
	$(MAKE) teardown-ybdb         TPCC_TS=$(TPCC_TS)
	$(MAKE) phase9                TPCC_TS=$(TPCC_TS)
	@echo "==> phase-crossregion-all complete  TPCC_TS=$(TPCC_TS)"

# -------------------------------------------------------------------
# W=128 × N=5 × 3-DB cross-region P-A baseline (NEXT-STEPS Path 1.2)
#
# Re-uses phase-crossregion-all pipeline with W=128 / ROUNDS=5 / 20-min
# warmup / 5-min run knobs. Operator gates (chrony / WAN RTT / freeze)
# remain phase2-gate's responsibility.
#
# Artifacts under results/x-cross/baseline/w128/ via LOCAL_RESULT_CATEGORY.
# Override knobs at invocation time, e.g.:
#   make phase-crossregion-w128-suite WAREHOUSES=256 ROUNDS=3
# -------------------------------------------------------------------
phase-crossregion-w128-suite:
	@echo "==================================================================="
	@echo "  phase-crossregion-w128-suite  W=128 × N=5 × 3-DB cross-region baseline"
	@echo "  TPCC_TS=$(TPCC_TS)"
	@echo "==================================================================="
	$(MAKE) phase-crossregion-all \
	  WAREHOUSES=128 \
	  ROUNDS=5 \
	  WARMUP_SEC=1200 \
	  RUN_SEC=300 \
	  THREADS_LIST='16 32 64 128' \
	  LOCAL_RESULT_CATEGORY=baseline/w128 \
	  TPCC_TS=$(TPCC_TS)

# Promotion checklist #2: P-B placement variant — same knobs, PLACEMENT=P-B
phase-crossregion-w128-suite-pb:
	@echo "==================================================================="
	@echo "  phase-crossregion-w128-suite-pb  W=128 × N=5 × 3-DB cross-region P-B"
	@echo "  TPCC_TS=$(TPCC_TS)"
	@echo "==================================================================="
	$(MAKE) phase-crossregion-all \
	  WAREHOUSES=128 \
	  ROUNDS=5 \
	  WARMUP_SEC=1200 \
	  RUN_SEC=300 \
	  THREADS_LIST='16 32 64 128' \
	  PLACEMENT=P-B \
	  LOCAL_RESULT_CATEGORY=baseline/w128-pb \
	  TPCC_TS=$(TPCC_TS)

# Promotion checklist #9 final gate: verify #1/#2/#7/#8 all PASS before header flip
phase-crossregion-promotion-gate:
	@echo "==> phase-crossregion-promotion-gate: Promotion checklist #9 final gate"
	@bash phase-crossregion/scripts/promotion-gate.sh \
	  --artifact-dir $(TPCC_ARTIFACTS)/$(RESULT_SCOPE) \
	  --ts $(TPCC_TS)

# ===================================================================
# TiDB P-A W=128 workflow validation (DRY_RUN=1 — no go-tpc benchmark)
# Validates: VM rebuild → bootstrap → TiDB deploy → SSH/endpoint/binary/
#            placement-SQL pre-flight → teardown.
# Usage:
#   make phase-crossregion-tidb-validate [TPCC_TS=<ts>]
# ===================================================================
phase-crossregion-tidb-validate:
	@echo "==================================================================="
	@echo "  phase-crossregion-tidb-validate  TiDB P-A W=128 workflow check"
	@echo "  TPCC_TS=$(TPCC_TS)  (DRY_RUN=1 — no go-tpc benchmark)"
	@echo "==================================================================="
	$(MAKE) phase1             TPCC_TS=$(TPCC_TS)
	$(MAKE) phase2             TPCC_TS=$(TPCC_TS)
	$(MAKE) phase3-tidb-deploy TPCC_TS=$(TPCC_TS)
	$(MAKE) phase6-tidb-smoke-dryrun \
	  WAREHOUSES=128 ROUNDS=5 WARMUP_SEC=1200 RUN_SEC=300 \
	  PLACEMENT=P-A PROFILE=A-S \
	  TPCC_TS=$(TPCC_TS)
	$(MAKE) teardown-tidb      TPCC_TS=$(TPCC_TS)
	@echo "==> phase-crossregion-tidb-validate PASS  TPCC_TS=$(TPCC_TS)"

# DRY_RUN=1: SSH/endpoint/go-tpc-binary/placement-SQL check; no gate/prepare/run/collect
phase6-tidb-smoke-dryrun:
	@echo "==> [start] phase6-tidb-smoke-dryrun at $$(date +%Y-%m-%dT%H:%M:%S%z)"
	@echo "==> phase6-tidb-smoke-dryrun ts=$(TPCC_TS) placement=$(PLACEMENT) W=$(WAREHOUSES) N=$(ROUNDS)"
	@TS=$(TPCC_TS); \
	ssh $(TPCC_CLIENT) " \
	  export PHASE_NAME=$(PHASE_NAME) RESULT_SCOPE=$(RESULT_SCOPE) BASELINE_FAMILY=$(BASELINE_FAMILY) \
	         tuning_profile_id=default \
	         TPCC_TS=$$TS PLACEMENT=$(PLACEMENT) PROFILE=$(PROFILE) \
	         DB=tidb CLIENT_ZONE=$(CLIENT_ZONE) GATE_SKIP=1 \
	         DB_HOST=$(TIDB_HOST) DB_PORT=$(TIDB_PORT) \
	         WAREHOUSES=$(WAREHOUSES) WARMUP_SEC=$(WARMUP_SEC) \
	         ROUNDS=$(ROUNDS) THREADS_LIST='$(THREADS_LIST)' RUN_SEC=$(RUN_SEC) ROUND_SLEEP_SEC=0 \
	         TPCC_ARTIFACTS=$(TPCC_ARTIFACTS)/$(RESULT_SCOPE) \
	         WAN_PROBE_ENABLED=0 WAN_PROBE_IPERF=0 \
	         DRY_RUN=1; \
	  bash $(CROSS_SCRIPTS_REMOTE)/run-vm6-suite.sh \
	    --db tidb --topology vm-6node-$(PLACEMENT)$(PROFILE_TOKEN) --ts $$TS"
	@echo "==> phase6-tidb-smoke-dryrun: reading .dry-run.done artifact"
	@ssh $(TPCC_CLIENT) "cat $(TPCC_ARTIFACTS)/$(RESULT_SCOPE)/tidb-vm-6node-$(PLACEMENT)$(PROFILE_TOKEN)-$(ISO)-$(TPCC_TS)/.dry-run.done 2>/dev/null || echo '(dry-run.done not found)'"
	@echo "==> [end] phase6-tidb-smoke-dryrun at $$(date +%Y-%m-%dT%H:%M:%S%z)"

# ===================================================================
# Operator window — TiDB × A-S × W=128 detached on .31（Mac 可關機）
#
# 前提：phase1 / phase2 / phase2-gate / phase3-tidb-deploy 已完成（Mac touch）。
# detach 後長跑段（load+warmup+sweep ~4.5-6.5h）完全在 .31 上，nohup 存活。
#
# Usage:
#   make win-tidb-as-detach PLACEMENT=P-A TPCC_TS=<ts>   # 觸發後 Mac 可關機
#   make win-tidb-as-status PLACEMENT=P-A TPCC_TS=<ts>   # 回來查進度
# ===================================================================
WIN_LOG = /tmp/poc-tpcc/logs/win-tidb-as-$(PLACEMENT)-$(TPCC_TS).log

win-tidb-as-detach:
	@echo "==> rsync scripts + freeze/ to .31 (driver 依賴)"
	rsync -avz phase-crossregion/scripts/ '$(TPCC_CLIENT):$(CROSS_SCRIPTS_REMOTE)/'
	rsync -avz phase-crossregion/freeze/  '$(TPCC_CLIENT):$(CROSS_SCRIPTS_REMOTE)/freeze/'
	@echo "==> launch detached driver on .31  PLACEMENT=$(PLACEMENT) TPCC_TS=$(TPCC_TS)"
	ssh $(TPCC_CLIENT) "mkdir -p /tmp/poc-tpcc/logs; \
	  nohup env PLACEMENT=$(PLACEMENT) TPCC_TS=$(TPCC_TS) \
	    bash $(CROSS_SCRIPTS_REMOTE)/win-tidb-as-w128.sh \
	    > $(WIN_LOG) 2>&1 < /dev/null & \
	  echo \"started pid \$$!\""
	@echo ""
	@echo "==> detached。Mac 現在可關機。回來後查進度："
	@echo "    make win-tidb-as-status PLACEMENT=$(PLACEMENT) TPCC_TS=$(TPCC_TS)"

win-tidb-as-status:
	@echo "==> window markers (TPCC_TS=$(TPCC_TS) PLACEMENT=$(PLACEMENT))"
	@ssh $(TPCC_CLIENT) "ROOT=$(TPCC_ARTIFACTS)/$(RESULT_SCOPE)/tidb-vm-6node-$(PLACEMENT)$(PROFILE_TOKEN)-$(ISO)-$(TPCC_TS); \
	  for m in .window.done .window.failed .suite.done .suite.failed; do \
	    [ -f \"\$$ROOT/\$$m\" ] && { echo \"--- \$$m ---\"; cat \"\$$ROOT/\$$m\"; }; \
	  done; \
	  [ -f \"\$$ROOT/.window.done\" ] || [ -f \"\$$ROOT/.window.failed\" ] || echo '(window still running)'"
	@echo "==> driver log tail"
	@ssh $(TPCC_CLIENT) "tail -20 $(WIN_LOG) 2>/dev/null || echo '(no log yet)'"

# ===================================================================
# Operator window — YBDB→CRDB × W=128 detached on .31（Mac 可關機）
#
# 2026-07-14：指揮鏈搬 .31。Mac 端只需先跑 phase1 phase2（VM 重建 + gate +
# probe clients），detach 後 driver 在 .31 以 make 跑 YBDB cell（deploy→fix6n
# →smoke→result→static-check→teardown）→（static-check fail-closed 全綠才）
# CRDB cell。完成後回 Mac 跑 make phase9 TPCC_TS=<ts> 收尾（fetch+destroy）。
#
# Usage:
#   make phase1 phase2 <w128 knobs> TPCC_TS=<ts>
#   make win-ybdb-crdb-detach TPCC_TS=<ts>       # 觸發後 Mac 可關機
#   make win-ybdb-crdb-status TPCC_TS=<ts>       # 回來查進度
#   make phase9 <w128 knobs> TPCC_TS=<ts>        # driver .done 後收尾
# ===================================================================
WIN_YC_LOG = /tmp/poc-tpcc/logs/win-ybdb-crdb-$(TPCC_TS).log

win-ybdb-crdb-detach:
	@echo "==> rsync scripts + freeze/ + Makefile to .31 (driver 依賴)"
	rsync -avz phase-crossregion/scripts/ '$(TPCC_CLIENT):$(CROSS_SCRIPTS_REMOTE)/'
	rsync -avz phase-crossregion/freeze/  '$(TPCC_CLIENT):$(CROSS_SCRIPTS_REMOTE)/freeze/'
	ssh $(TPCC_CLIENT) 'mkdir -p /tmp/poc/phase-crossregion/scripts'
	rsync -avz phase-crossregion/Makefile '$(TPCC_CLIENT):/tmp/poc/phase-crossregion/Makefile'
	rsync -avz phase-crossregion/scripts/ '$(TPCC_CLIENT):/tmp/poc/phase-crossregion/scripts/'
	@echo "==> preflight: .31 不得有殘留 run-vm6-suite/go-tpc/win-driver 進程"
	@ssh $(TPCC_CLIENT) "procs=\$$(pgrep -af 'run-vm6-suite\.sh|go-tpc|win-ybdb-crdb-w128' | grep -v pgrep || true); \
	  [ -z \"\$$procs\" ] || { echo \"FATAL 殘留進程:\"; echo \"\$$procs\"; exit 1; }"
	@echo "==> launch detached driver on .31  TPCC_TS=$(TPCC_TS)"
	ssh $(TPCC_CLIENT) "mkdir -p /tmp/poc-tpcc/logs; \
	  nohup env PLACEMENT=$(PLACEMENT) TPCC_TS=$(TPCC_TS) \
	    bash $(CROSS_SCRIPTS_REMOTE)/win-ybdb-crdb-w128.sh \
	    > $(WIN_YC_LOG) 2>&1 < /dev/null & \
	  echo \"started pid \$$!\""
	@echo ""
	@echo "==> detached。Mac 現在可關機。回來後查進度："
	@echo "    make win-ybdb-crdb-status TPCC_TS=$(TPCC_TS)"

win-ybdb-crdb-status:
	@echo "==> window markers (TPCC_TS=$(TPCC_TS))"
	@ssh $(TPCC_CLIENT) "for m in /tmp/poc-tpcc/logs/win-ybdb-crdb-$(TPCC_TS).done /tmp/poc-tpcc/logs/win-ybdb-crdb-$(TPCC_TS).failed; do \
	  [ -f \"\$$m\" ] && { echo \"--- \$$m ---\"; cat \"\$$m\"; }; done; \
	  [ -f /tmp/poc-tpcc/logs/win-ybdb-crdb-$(TPCC_TS).done ] || [ -f /tmp/poc-tpcc/logs/win-ybdb-crdb-$(TPCC_TS).failed ] || echo '(window still running)'"
	@echo "==> driver log tail"
	@ssh $(TPCC_CLIENT) "tail -25 $(WIN_YC_LOG) 2>/dev/null || echo '(no log yet)'"

# -------------------------------------------------------------------
# #3 同批三家重跑：TiDB→YBDB→CRDB × W=128 detached on .31
# 用法同上（win-3db-detach / win-3db-status），driver = win-3db-w128.sh
# -------------------------------------------------------------------
WIN_3DB_LOG = /tmp/poc-tpcc/logs/win-3db-$(TPCC_TS).log

win-3db-detach:
	@echo "==> rsync scripts + freeze/ + Makefile to .31 (driver 依賴)"
	rsync -avz phase-crossregion/scripts/ '$(TPCC_CLIENT):$(CROSS_SCRIPTS_REMOTE)/'
	rsync -avz phase-crossregion/freeze/  '$(TPCC_CLIENT):$(CROSS_SCRIPTS_REMOTE)/freeze/'
	ssh $(TPCC_CLIENT) 'mkdir -p /tmp/poc/phase-crossregion/scripts'
	rsync -avz phase-crossregion/Makefile '$(TPCC_CLIENT):/tmp/poc/phase-crossregion/Makefile'
	rsync -avz phase-crossregion/scripts/ '$(TPCC_CLIENT):/tmp/poc/phase-crossregion/scripts/'
	@echo "==> preflight: .31 不得有殘留 run-vm6-suite/go-tpc/win-driver 進程"
	@ssh $(TPCC_CLIENT) "procs=\$$(pgrep -af 'run-vm6-suite\.sh|go-tpc|win-ybdb-crdb-w128|win-3db-w128' | grep -v pgrep || true); \
	  [ -z \"\$$procs\" ] || { echo \"FATAL 殘留進程:\"; echo \"\$$procs\"; exit 1; }"
	@echo "==> launch detached driver on .31  TPCC_TS=$(TPCC_TS) DBS='$(DBS)'"
	ssh $(TPCC_CLIENT) "mkdir -p /tmp/poc-tpcc/logs; \
	  nohup env PLACEMENT=$(PLACEMENT) TPCC_TS=$(TPCC_TS) DBS='$(DBS)' \
	    bash $(CROSS_SCRIPTS_REMOTE)/win-3db-w128.sh \
	    > $(WIN_3DB_LOG) 2>&1 < /dev/null & \
	  echo \"started pid \$$!\""
	@echo ""
	@echo "==> detached。Mac 現在可關機。回來後查進度："
	@echo "    make win-3db-status TPCC_TS=$(TPCC_TS)"

win-3db-status:
	@echo "==> window markers (TPCC_TS=$(TPCC_TS))"
	@ssh $(TPCC_CLIENT) "for m in /tmp/poc-tpcc/logs/win-3db-$(TPCC_TS).done /tmp/poc-tpcc/logs/win-3db-$(TPCC_TS).failed; do \
	  [ -f \"\$$m\" ] && { echo \"--- \$$m ---\"; cat \"\$$m\"; }; done; \
	  [ -f /tmp/poc-tpcc/logs/win-3db-$(TPCC_TS).done ] || [ -f /tmp/poc-tpcc/logs/win-3db-$(TPCC_TS).failed ] || echo '(window still running)'"
	@echo "==> driver log tail"
	@ssh $(TPCC_CLIENT) "tail -25 $(WIN_3DB_LOG) 2>/dev/null || echo '(no log yet)'"

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
	@echo "DEPRECATED: legacy target（Path C run-round-only 鏈已刪除，此 target 含 cold-reset+warmup 的 run.sh，非純 run；正式路徑走 run-vm6-suite.sh）"
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
	  bash $(TPCC_SCRIPTS)/run.sh --db tidb --iso $(ISO) --topology vm-6node-$(PLACEMENT)$(PROFILE_TOKEN) --db-host $(TIDB_HOST) --ts $$TS; \
	  bash $(TPCC_SCRIPTS)/collect.sh --db tidb --iso $(ISO) --topology vm-6node-$(PLACEMENT)$(PROFILE_TOKEN) --db-host $(TIDB_HOST) --ts $$TS"
	@ROOT=$(TPCC_ARTIFACTS)/$(RESULT_SCOPE)/tidb-vm-6node-$(PLACEMENT)$(PROFILE_TOKEN)-$(ISO)-$(TPCC_TS); \
	ssh $(TPCC_CLIENT) "tar czf - -C $$ROOT/runs ." \
	  | tar xzf - -C $(SMOKE_RESULT_BASE)/tidb/ 2>/dev/null || true
	@echo "==> phase-smoke-only-tidb round=$(SMOKE_ROUND) done → $(SMOKE_RESULT_BASE)/tidb/"

phase-smoke-only-crdb:
	@echo "DEPRECATED: legacy target（Path C run-round-only 鏈已刪除，此 target 含 cold-reset+warmup 的 run.sh，非純 run；正式路徑走 run-vm6-suite.sh）"
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
	  bash $(TPCC_SCRIPTS)/run.sh --db crdb --iso $(ISO) --topology vm-6node-$(PLACEMENT)$(PROFILE_TOKEN) --db-host $(CRDB_HOST) --ts $$TS; \
	  bash $(TPCC_SCRIPTS)/collect.sh --db crdb --iso $(ISO) --topology vm-6node-$(PLACEMENT)$(PROFILE_TOKEN) --db-host $(CRDB_HOST) --ts $$TS"
	@ROOT=$(TPCC_ARTIFACTS)/$(RESULT_SCOPE)/crdb-vm-6node-$(PLACEMENT)$(PROFILE_TOKEN)-$(ISO)-$(TPCC_TS); \
	ssh $(TPCC_CLIENT) "tar czf - -C $$ROOT/runs ." \
	  | tar xzf - -C $(SMOKE_RESULT_BASE)/crdb/ 2>/dev/null || true
	@echo "==> phase-smoke-only-crdb round=$(SMOKE_ROUND) done → $(SMOKE_RESULT_BASE)/crdb/"

phase-smoke-only-ybdb:
	@echo "DEPRECATED: legacy target（Path C run-round-only 鏈已刪除，此 target 含 cold-reset+warmup 的 run.sh，非純 run；正式路徑走 run-vm6-suite.sh）"
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
	  bash $(TPCC_SCRIPTS)/run.sh --db ybdb --iso $(ISO) --topology vm-6node-$(PLACEMENT)$(PROFILE_TOKEN) --db-host $(YBDB_HOST) --ts $$TS; \
	  bash $(TPCC_SCRIPTS)/collect.sh --db ybdb --iso $(ISO) --topology vm-6node-$(PLACEMENT)$(PROFILE_TOKEN) --db-host $(YBDB_HOST) --ts $$TS"
	@ROOT=$(TPCC_ARTIFACTS)/$(RESULT_SCOPE)/ybdb-vm-6node-$(PLACEMENT)$(PROFILE_TOKEN)-$(ISO)-$(TPCC_TS); \
	ssh $(TPCC_CLIENT) "tar czf - -C $$ROOT/runs ." \
	  | tar xzf - -C $(SMOKE_RESULT_BASE)/ybdb/ 2>/dev/null || true
	@echo "==> phase-smoke-only-ybdb round=$(SMOKE_ROUND) done → $(SMOKE_RESULT_BASE)/ybdb/"

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

# === Path C .PHONY additions ===
.PHONY: \
  phase-freeze-tidb phase-unfreeze-tidb \
  phase-freeze-crdb phase-unfreeze-crdb \
  phase-freeze-ybdb phase-unfreeze-ybdb \
  phase-smoke-only-tidb phase-smoke-only-crdb phase-smoke-only-ybdb \
  phase-leader-gate-tidb-postprepare \
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
