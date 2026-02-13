PYTHON ?= python3
BASE_URL ?= https://pmm.104.com.tw/prometheus
TIMEOUT ?= 20
SLEEP_EVERY ?= 200
SLEEP_SECONDS ?= 0.1
WORKERS ?= 6

.PHONY: build clean

build: metrics.list labels.json

metrics.list:
	BASE_URL=$(BASE_URL) TIMEOUT=$(TIMEOUT) \
		$(PYTHON) scripts/metrics_list.py

labels.json: metrics.list
	BASE_URL=$(BASE_URL) TIMEOUT=$(TIMEOUT) \
		SLEEP_EVERY=$(SLEEP_EVERY) SLEEP_SECONDS=$(SLEEP_SECONDS) \
		WORKERS=$(WORKERS) \
		$(PYTHON) scripts/labels_json.py

clean:
	rm -f metrics.list labels.json
