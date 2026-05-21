SHELL := /bin/bash
.ONESHELL:
.PHONY: help commit md5_fix reconcile_manifest extract_pdf ocr_pdf filter_doc filter_test audit_sources build_chunks clean_generated

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
