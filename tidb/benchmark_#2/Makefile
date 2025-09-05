SHELL := /bin/bash

## Makefile to schedule a remote command (hostname) exactly DELAY seconds after local now.
## Usage:
##   make exec                # wait default 5s then run remote CMD (default hostname)
##   make exec DELAY=10       # wait 10s
##   make exec HOST=root@172.24.47.20 DELAY=3 CMD='uname -a'
## Variables:
##   HOST   - SSH target (user@host). Default root@172.24.47.20
##   DELAY  - Seconds from now to execute. Default 5
##   SKEW_TOL - Max allowed absolute time skew (seconds) between local and remote. Default 2
##   CMD      - Remote command to execute once target time reached. Default hostname
##
## Notes:
## - Local time determines the target epoch. Remote loops until it reaches that epoch.
## - If skew exceeds tolerance, the command aborts (to avoid large drift).
## - Override SKEW_TOL=0 to force strict alignment (abort on any skew).
## - You can export SSH_OPTIONS to add extra options (e.g. -i keyfile).

HOST ?= root@172.24.47.20
DELAY ?= 5
SKEW_TOL ?= 2
SSH_OPTIONS ?= -o StrictHostKeyChecking=no -o ConnectTimeout=5
CMD ?= hostname
REMOTE_FILE ?= /tmp/test
LOCAL_FILE ?= test
CSV_HEADER ?= Timestamp,Threads,RPS,AvgSec,Loops,ErrRate,TidbCPU%,TiProxyCPU%
CSV_LINE ?= 2025-09-04 15:37:13,100,21349,.936,32,0,64.61,10.94

# Python virtual environment (for plotting)
VENV ?= .venv
PYTHON := $(VENV)/bin/python3
PIP    := $(PYTHON) -m pip
PLOT_SCRIPT ?= plot_from_csv.py

.PHONY: exec show-time

show-time:
	@echo "Local epoch: $$(date +%s)  Human: $$(date '+%Y-%m-%d %H:%M:%S %Z')"
	@echo "Remote epoch: $$(ssh $(SSH_OPTIONS) $(HOST) 'date +%s')"

exec:
	@echo "[info] Scheduling remote file creation after $(DELAY)s (host: $(HOST))"
	@now_local=$$(date +%s); \
	 target_epoch=$$(( now_local + $(DELAY) )); \
	 echo "[debug] Local now: $$now_local target_epoch: $$target_epoch"; \
	 remote_now=$$(ssh $(SSH_OPTIONS) $(HOST) 'date +%s' 2>/dev/null || echo 0); \
	 if [ "$$remote_now" = "0" ]; then echo "[error] Unable to fetch remote time" >&2; exit 2; fi; \
	 skew=$$(( remote_now - now_local )); \
	 skew_abs=$$skew; if [ $$skew_abs -lt 0 ]; then skew_abs=$$(( -skew_abs )); fi; \
	 echo "[info] Time skew (remote - local): $$skew s (abs=$$skew_abs s)"; \
	 if [ $$skew_abs -gt $(SKEW_TOL) ]; then \
	   echo "[error] Skew $$skew_abs s exceeds tolerance $(SKEW_TOL)s. Abort."; \
	   echo "        Consider synchronizing time (e.g., ntp/chrony) or increasing SKEW_TOL."; \
	   exit 3; \
	 fi; \
	 echo "[info] Waiting on remote until epoch $$target_epoch (delay $(DELAY)s)"; \
	 # Send CSV content via pipe; remote waits first, then writes file.
	 ( printf '%s\n%s\n' "$(CSV_HEADER)" "$(CSV_LINE)" ) | \
	   ssh $(SSH_OPTIONS) $(HOST) "target_epoch=$$target_epoch; while [ $$(date +%s) -lt $$target_epoch ]; do sleep 0.2; done; cat > $(REMOTE_FILE)"; \
	 rce=$$?; if [ $$rce -ne 0 ]; then echo "[error] Remote file creation failed rc=$$rce"; exit $$rce; fi; \
	 echo "[info] Remote file $(REMOTE_FILE) created"; \
	 # Optionally run extra CMD (e.g., hostname) after creation
	 ssh $(SSH_OPTIONS) $(HOST) "eval $(CMD)" 2>&1 | sed 's/^/[remote cmd] /'; \
	 # Rsync the file back
	 echo "[info] Fetching remote file via rsync -> $(LOCAL_FILE)"; \
	 rsync -e "ssh $(SSH_OPTIONS)" -avz $(HOST):$(REMOTE_FILE) $(LOCAL_FILE) >/dev/null 2>&1 || { echo "[error] rsync failed"; exit 4; }; \
	 echo "[info] File saved locally as $(LOCAL_FILE)"; \
	 # Delete remote file
	 ssh $(SSH_OPTIONS) $(HOST) "rm -f $(REMOTE_FILE)" || { echo "[warn] Could not delete remote file $(REMOTE_FILE)"; }; \
	 echo "[info] Remote file removed"; \
	 # ---- Plotting phase (using local '$(LOCAL_FILE)' as source CSV) ---- \
	 if [ ! -f "$(LOCAL_FILE)" ]; then echo "[error] Local CSV $(LOCAL_FILE) missing"; exit 5; fi; \
	 if [ ! -f "$(PYTHON)" ]; then \
	   echo "[info] Creating venv $(VENV)"; \
	   python3 -m venv $(VENV) || { echo "[error] venv create failed"; exit 6; }; \
	   $(PIP) install --upgrade pip >/dev/null 2>&1; \
	   $(PIP) install pandas matplotlib >/dev/null 2>&1 || { echo "[error] pip install failed"; exit 7; }; \
	 else \
	   echo "[info] Using existing venv $(VENV)"; \
	 fi; \
	 PLOT_OUT="plot_$$(( $$(date +%s) )).png"; \
	 echo "[info] Generating bar chart => $$PLOT_OUT"; \
	 if [ ! -f "$(PLOT_SCRIPT)" ]; then echo "[error] Missing $(PLOT_SCRIPT)"; exit 9; fi; \
	 LOCAL_FILE=$(LOCAL_FILE) PLOT_OUT=$$PLOT_OUT $(PYTHON) $(PLOT_SCRIPT) || { echo "[error] Plot failed"; exit 8; }; \
	 echo "[info] Plot image: $$PLOT_OUT"; \
	 exit 0
