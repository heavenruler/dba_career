SHELL := /bin/bash
.ONESHELL:
.PHONY: help commit md5_fix reconcile_manifest extract_pdf ocr_pdf filter_doc filter_test audit_sources build_chunks clean_generated sync todo filter_all_bg filter_status filter_stop filter_log

TODO_PID := todo.pid
TODO_OUT := todo.out

# 預設 filter_test 對象（可覆寫：make filter_test DOC_ID=<md5>）
FILTER_TEST_DOC_ID ?= 44862aef1f3e9f432840f303bb9da948

help:
	@printf '%s\n' \
		'KnowledgeBase workflow' \
		'' \
		'Source of truth:' \
		'  output_with_md5.txt     title/url/doc_id manifest; keep this file' \
		'  collector/*.pdf         source PDFs; keep these files' \
		'' \
		'Generated outputs:' \
		'  generated/extracted/    PDF text extracted by pdftotext' \
		'  generated/filtered/     Codex/OpenAI filtered knowledge JSON' \
		'  generated/kb/           chunk/document/audit JSONL outputs' \
		'  generated/              ignored by git; can be rebuilt' \
		'' \
		'Recommended single-document flow:' \
		'  make extract_pdf DOC_ID=<md5>' \
		'  make filter_doc DOC_ID=<md5>' \
		'  make build_chunks DOC_ID=<md5>' \
		'' \
		'Batch / maintenance:' \
		'  make sync                NEW: reconcile + extract + OCR + rebuild chunks + audit + regen todo.sh' \
		'  make todo                regenerate todo.sh (LLM filter queue) from current generated/extracted/' \
		'  make md5_fix             repair missing/incorrect MD5 values in output_with_md5.txt' \
		'  make reconcile_manifest  append orphan PDF entries to output_with_md5.txt (from pdfinfo)' \
		'  make extract_pdf         extract every collector PDF (strict mode: frontmatter+page markers+sha256)' \
		'  make ocr_pdf             OCR every needs_ocr doc (image-only PDFs); requires tesseract-lang' \
		'  make audit_sources       compare manifest, collector PDFs, and extracted text' \
		'  make build_chunks        build chunks for all extracted/filtered documents (page-tracked)' \
		'  make clean_generated     delete generated/ rebuildable outputs' \
		'' \
		'LLM filtering:' \
		'  make filter_doc DOC_ID=<md5>' \
		'      default provider: codex CLI' \
		'' \
		'  make filter_doc DOC_ID=<md5> PROVIDER=openai MODEL=gpt-5.4-mini' \
		'      uses OpenAI API and requires OPENAI_API_KEY' \
		'' \
		'  make filter_test' \
		'      force-rerun LLM filter on $(FILTER_TEST_DOC_ID) (test sample, 預設 5KB doc):' \
		'      → 刪除 generated/filtered/<DOC_ID>/ 舊結果 → 重跑 filter → rebuild chunks' \
		'      Override: make filter_test DOC_ID=<md5>' \
		'' \
		'  Batch (background) LLM filter — todo.sh 包裝:' \
		'    make filter_all_bg     # nohup + caffeinate + PID 記錄，啟動完即返回' \
		'    make filter_status     # 看是否在跑 + 完成數 + 最近 5 篇' \
		'    make filter_log        # tail -f filter_progress.log' \
		'    make filter_stop       # 停背景 todo.sh（process group + 5s fallback to SIGKILL）' \
		'' \
		'Notes:' \
		'  - build_chunks prefers generated/filtered/<doc_id>/knowledge.json.' \
		'  - If no filtered JSON exists, build_chunks falls back to generated/extracted/<doc_id>/full.md.' \
		'  - Do not commit generated/ outputs or large files.'

commit:
	mv ~/Downloads/FireShot/* collector ; git add . ; git commit -m "update" ; git push

# 修補 output_with_md5.txt 中遺漏或不正確的 MD5（例如佔位字 nnn）
md5_fix:
	@python3 scripts/md5_fix.py
	@echo "已修補 output_with_md5.txt 的 MD5 欄位"

# 從 PDF metadata 反推 orphan PDFs 的 title/url 並補進 output_with_md5.txt
reconcile_manifest:
	@python3 scripts/reconcile_manifest.py
	@echo "已 reconcile output_with_md5.txt"

# 對 needs_ocr=true 的 PDF（avg_chars_per_page 過低 / 純圖像）跑 tesseract OCR
ocr_pdf:
	@if [ -z "$(DOC_ID)" ]; then \
		python3 scripts/ocr_pdf.py --all; \
	else \
		python3 scripts/ocr_pdf.py --doc-id $(DOC_ID); \
	fi
	@echo "已 OCR 圖像 PDF（更新 full.md 與 metadata.json）"

# 從 collector/*.pdf 解析正文到 generated/extracted
extract_pdf:
	@if [ -z "$(DOC_ID)" ]; then \
		python3 scripts/extract_pdf.py --all; \
	else \
		python3 scripts/extract_pdf.py --doc-id $(DOC_ID); \
	fi
	@echo "已建立 generated/extracted"

# 用 LLM 將 generated/extracted 的全文過濾成有效知識
filter_doc:
	@if [ -z "$(DOC_ID)" ]; then \
		echo "使用方法: make filter_doc DOC_ID=<md5>"; \
		exit 1; \
	fi
	@python3 scripts/filter_doc.py --doc-id $(DOC_ID) $(if $(PROVIDER),--provider $(PROVIDER),) $(if $(MODEL),--model $(MODEL),)
	@echo "已建立 generated/filtered/$(DOC_ID)/knowledge.json"

# 強制重跑單一 doc 的 LLM filter：先刪舊 filtered 結果再產新，再 rebuild 該 doc 的 chunks
# 預設 DOC_ID=$(FILTER_TEST_DOC_ID)；可覆寫：make filter_test DOC_ID=<md5> [PROVIDER=openai MODEL=gpt-5.4-mini]
filter_test: DOC_ID ?= $(FILTER_TEST_DOC_ID)
filter_test:
	@echo "[filter_test] target DOC_ID=$(DOC_ID)"
	@rm -rf generated/filtered/$(DOC_ID)
	@python3 scripts/filter_doc.py --doc-id $(DOC_ID) $(if $(PROVIDER),--provider $(PROVIDER),) $(if $(MODEL),--model $(MODEL),)
	@python3 scripts/build_chunks.py --doc-id $(DOC_ID)
	@echo "[filter_test] 完成 generated/filtered/$(DOC_ID)/knowledge.json 並已 rebuild 該 doc 的 chunks"

# 從 generated/filtered 或 generated/extracted 建立知識庫拆塊資料
build_chunks:
	@python3 scripts/build_chunks.py $(if $(DOC_ID),--doc-id $(DOC_ID),)
	@echo "已建立 generated/kb/chunks.jsonl"

# 檢查 output_with_md5、collector PDF、generated/extracted 正文的主鍵對齊狀態
audit_sources:
	@python3 scripts/audit_sources.py
	@echo "已建立 generated/kb/source_audit.jsonl"

# 清除可重建的知識庫產物
clean_generated:
	@rm -rf generated
	@echo "已清除可重建產物"

# 新增 PDF 後一鍵同步：reconcile manifest → extract → OCR → rebuild chunks → audit → regen todo.sh
# 所有子步驟 idempotent；重跑無害。LLM filter 不含在 sync，要跑請另外 make filter_doc / filter_test。
sync: reconcile_manifest extract_pdf ocr_pdf
	@rm -rf generated/kb
	@$(MAKE) build_chunks
	@$(MAKE) audit_sources
	@$(MAKE) todo
	@echo "[sync] 完成 — 新增的 PDF 已抽取、OCR、切塊、審核、todo.sh 重生完畢"

# 從 generated/extracted 重生 todo.sh（依現況排序 + 跳過已 filter 的）
# 可單獨呼叫；make sync 也會自動跑
todo:
	@python3 scripts/regen_todo.py

# 背景啟動 ./todo.sh：nohup + caffeinate（防 mac 睡）+ PID 記錄
# 啟動完即返回；用 make filter_status / filter_log / filter_stop 管理
filter_all_bg:
	@if [ -f $(TODO_PID) ] && kill -0 $$(cat $(TODO_PID)) 2>/dev/null; then \
		echo "⚠️  已有 todo.sh 在跑 (PID $$(cat $(TODO_PID)))；先 make filter_stop"; \
		exit 1; \
	fi
	@if [ ! -x ./todo.sh ]; then echo "todo.sh 不存在或不可執行；先 make todo"; exit 1; fi
	@nohup caffeinate -i ./todo.sh > $(TODO_OUT) 2>&1 & echo $$! > $(TODO_PID)
	@sleep 1
	@echo "[filter_all_bg] started PID $$(cat $(TODO_PID)) at $$(date '+%Y-%m-%d %H:%M:%S')"
	@echo "  日誌    : tail -f filter_progress.log    (或 make filter_log)"
	@echo "  進度    : wc -l .todo.state              (或 make filter_status)"
	@echo "  中斷    : make filter_stop"
	@echo "  失敗    : cat filter_failed.log"

# 顯示 todo.sh 背景狀態 + 進度 + 最新完成項
filter_status:
	@if [ -f $(TODO_PID) ] && kill -0 $$(cat $(TODO_PID)) 2>/dev/null; then \
		echo "🟢 RUNNING  PID $$(cat $(TODO_PID))"; \
	else \
		echo "⚫ STOPPED"; \
	fi
	@printf '完成: '; [ -f .todo.state ] && wc -l < .todo.state || echo 0
	@printf '失敗: '; [ -f filter_failed.log ] && wc -l < filter_failed.log || echo 0
	@printf '已 filter (knowledge.json): '; ls generated/filtered 2>/dev/null | wc -l
	@echo '最近 5 篇完成:'
	@[ -f .todo.state ] && tail -5 .todo.state || echo '  (尚無)'

# 中斷背景 todo.sh + 所有子程序（make filter_doc / codex exec）
# nohup&启动的 todo.sh 不一定是 process group leader，所以 PID kill + pattern pkill 雙保險
filter_stop:
	@PID=""; \
	[ -f $(TODO_PID) ] && PID=$$(cat $(TODO_PID)); \
	if [ -n "$$PID" ] && kill -0 $$PID 2>/dev/null; then \
		echo "[filter_stop] SIGTERM → PID $$PID + descendants by name pattern"; \
		kill -TERM $$PID 2>/dev/null; \
	else \
		echo "[filter_stop] no live todo.sh PID; clearing descendants only"; \
	fi; \
	pkill -TERM -f "scripts/filter_doc.py" 2>/dev/null || true; \
	pkill -TERM -f "codex exec --cd.*KnowledgeBase" 2>/dev/null || true; \
	for i in 1 2 3 4 5; do \
		ALIVE=0; \
		[ -n "$$PID" ] && kill -0 $$PID 2>/dev/null && ALIVE=1; \
		pgrep -f "scripts/filter_doc.py" >/dev/null && ALIVE=1; \
		pgrep -f "codex exec --cd.*KnowledgeBase" >/dev/null && ALIVE=1; \
		[ "$$ALIVE" = "0" ] && { echo "  ✅ stopped gracefully"; rm -f $(TODO_PID); exit 0; }; \
		sleep 1; \
	done; \
	echo "  ⚠️  still alive after 5s, SIGKILL"; \
	[ -n "$$PID" ] && kill -9 $$PID 2>/dev/null; \
	pkill -9 -f "scripts/filter_doc.py" 2>/dev/null || true; \
	pkill -9 -f "codex exec --cd.*KnowledgeBase" 2>/dev/null || true; \
	rm -f $(TODO_PID); \
	echo "  killed"

# tail -f filter_progress.log（Ctrl-C 退出不影響背景 todo.sh）
filter_log:
	@tail -f filter_progress.log
