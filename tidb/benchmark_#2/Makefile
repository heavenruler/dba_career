SHELL := /bin/bash

SRC_HOST = root@172.24.47.20
SRC_PATH = /root/poc/benchmark-tidb/benchmark_\#2/
DST_PATH = .

VENV := .venv
PYTHON := $(VENV)/bin/python3
PIP    := $(VENV)/bin/python3 -m pip
COMMIT_MSG ?= update

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
run: sync plot
	@echo "完成：資料同步 + 繪圖輸出"

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

