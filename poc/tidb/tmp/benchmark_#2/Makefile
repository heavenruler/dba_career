SHELL := /bin/bash

SRC_HOST = root@172.24.47.20
SRC_PATH = /root/poc/benchmark-tidb/benchmark_\#2/
DST_PATH = .

VENV := .venv
PYTHON := $(VENV)/bin/python3
PIP    := $(VENV)/bin/python3 -m pip
COMMIT_MSG ?= update

# Remote async control files
REMOTE_DONE_FILE := bench_done.flag
REMOTE_LOG := bench_run.log
REMOTE_EXIT_CODE := bench_exit_code

venv_ok := $(shell test -f $(PYTHON) && echo yes || echo no)

## 預設
sync: rsync

## rsync 同步
rsync:
	rsync -avz --progress $(SRC_HOST):$(SRC_PATH) $(DST_PATH)

## scp 拷貝
scp:
	scp -r $(SRC_HOST):$(SRC_PATH)* $(DST_PATH)

## 建立 venv
setup:
ifeq ($(venv_ok),no)
	@echo ">>> 建立虛擬環境 $(VENV) ..."
	python3 -m venv $(VENV)
	$(PIP) install --upgrade pip
	$(PIP) install pandas matplotlib
else
	@echo ">>> 已存在虛擬環境，略過安裝"
endif

## 檢查回傳結果
check_csv:
	@if [ ! -f "bench_result.csv" ]; then \
		echo "bench_result.csv 不存在，請先 make sync"; \
		exit 1; \
	fi

## 執行繪圖
plot: setup check_csv
	@echo ">>> 繪圖中 ..."
	$(PYTHON) plot_rps_bar.py

## 一鍵流程
## 上傳最新 conn_bench.sh 到來源機並執行，完成後再同步與繪圖
.PHONY: upload_script remote_exec remote_exec_async remote_status watch_remote run_async finish help

upload_script:
	@echo ">>> 上傳 conn_bench.sh 到 $(SRC_HOST):$(SRC_PATH)"
	scp conn_bench.sh $(SRC_HOST):"$(SRC_PATH)conn_bench.sh"
	ssh $(SRC_HOST) "chmod +x \"$(SRC_PATH)conn_bench.sh\""

remote_exec: upload_script
	@echo ">>> 觸發遠端執行 conn_bench.sh (可能需數分鐘，請稍候)"
	ssh $(SRC_HOST) "cd \"$(SRC_PATH)\" && ./conn_bench.sh"
	@echo ">>> 遠端腳本執行完成"

## 非阻塞遠端執行 (SSH 中斷仍持續)
remote_exec_async: upload_script
	@echo ">>> 以背景方式啟動遠端 conn_bench.sh (可安全斷線)"
	ssh $(SRC_HOST) "cd \"$(SRC_PATH)\" \
	&& rm -f $(REMOTE_DONE_FILE) $(REMOTE_EXIT_CODE) \
	&& nohup bash -c './conn_bench.sh; ec=$$?; echo $$ec > $(REMOTE_EXIT_CODE); date +%F_%T > $(REMOTE_DONE_FILE)' > $(REMOTE_LOG) 2>&1 &"
	@echo ">>> 已啟動，使用 make remote_status / make watch_remote 查看狀態"

remote_status:
	@echo ">>> 查詢遠端狀態..."
	@ssh $(SRC_HOST) "cd \"$(SRC_PATH)\"; if [ -f $(REMOTE_DONE_FILE) ]; then echo 'Status: DONE'; [ -f $(REMOTE_EXIT_CODE) ] && echo -n 'ExitCode: ' && cat $(REMOTE_EXIT_CODE); else echo 'Status: RUNNING'; fi; echo 'Log(head):'; [ -f $(REMOTE_LOG) ] && head -n 5 $(REMOTE_LOG) || echo '(no log yet)'"

watch_remote:
	@echo ">>> 等待遠端完成 (每 15 秒輪詢) ..."
	@while true; do \
	  if ssh $(SRC_HOST) "test -f \"$(SRC_PATH)$(REMOTE_DONE_FILE)\""; then \
	    echo '>>> 遠端已完成'; \
	    break; \
	  else \
	    echo '... still running'; \
	  fi; \
	  sleep 15; \
	done

## 啟動遠端後立即返回
run_async: remote_exec_async
	@echo "已背景啟動，可稍後執行: make finish"

## 等待遠端完成後自動同步+繪圖
finish: watch_remote
	@$(MAKE) sync
	@$(MAKE) plot
	@echo "完成：同步 + 繪圖"

run: remote_exec
	@echo ">>> 遠端結果產出，開始同步..."
	$(MAKE) sync
	@echo ">>> 同步完成，開始繪圖..."
	$(MAKE) plot
	@echo "完成：遠端執行 + 資料同步 + 繪圖輸出"

help:
	@echo "用法 (Workflow)";
	@echo "  make run_async     # 上傳並背景啟動遠端 conn_bench.sh, 可關 Terminal / 網路中斷";
	@echo "  make remote_status # 查看是否完成 + 顯示 log 開頭";
	@echo "  make watch_remote  # 輪詢等待完成 (15s 間隔)";
	@echo "  make finish        # 等完成後自動 sync + plot (相當於 watch_remote -> sync -> plot)";
	@echo "  make run           # 阻塞式：遠端執行完立即同步 + 繪圖";
	@echo "其他";
	@echo "  make sync          # rsync 全部結果";
	@echo "  make plot          # 讀 bench_result.csv 產圖";
	@echo "  make commit        # git add/commit/push (自訂 COMMIT_MSG=msg)";
	@echo "  make clean         # 刪除虛擬環境";
	@echo "  make help          # 顯示本說明";

## 清理環境
clean:
	rm -rf $(VENV)

.PHONY: commit
commit:
	@echo "[git] add ."
	@git add .
	@echo "[git] commit -m '$(COMMIT_MSG)'"
	@git commit -m "$(COMMIT_MSG)" || echo "[git] Nothing to commit"
	@echo "[git] push"
	@git push
	@echo "[git] Done push (message: $(COMMIT_MSG))"

