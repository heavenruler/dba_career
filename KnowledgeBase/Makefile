SHELL := /bin/bash
.ONESHELL:
.PHONY: help commit md5_fix extract_pdf filter_doc audit_sources build_chunks clean_generated

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
		'  make md5_fix            repair missing/incorrect MD5 values in output_with_md5.txt' \
		'  make extract_pdf        extract all manifest PDFs found under collector/' \
		'  make audit_sources      compare manifest, collector PDFs, and extracted text' \
		'  make build_chunks       build chunks for all extracted/filtered documents' \
		'  make clean_generated    delete generated/ rebuildable outputs' \
		'' \
		'LLM filtering:' \
		'  make filter_doc DOC_ID=<md5>' \
		'      default provider: codex CLI' \
		'' \
		'  make filter_doc DOC_ID=<md5> PROVIDER=openai MODEL=gpt-5.4-mini' \
		'      uses OpenAI API and requires OPENAI_API_KEY' \
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
