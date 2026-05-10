SHELL := /bin/bash
.ONESHELL:
.PHONY: commit md5_fix audit_sources build_chunks clean_generated

commit:
	mv ~/Downloads/FireShot/* collector ; git add . ; git commit -m "update" ; git push

# 修補 output_with_md5.txt 中遺漏或不正確的 MD5（例如佔位字 nnn）
md5_fix:
	@python3 scripts/md5_fix.py
	@echo "已修補 output_with_md5.txt 的 MD5 欄位"

# 從 collector/imported/*/full.md 建立知識庫拆塊資料
build_chunks:
	@python3 scripts/build_chunks.py $(if $(DOC_ID),--doc-id $(DOC_ID),)
	@echo "已建立 generated/kb/chunks.jsonl"

# 檢查 output_with_md5、collector PDF、imported 正文的主鍵對齊狀態
audit_sources:
	@python3 scripts/audit_sources.py
	@echo "已建立 generated/kb/source_audit.jsonl"

# 清除可重建的知識庫產物
clean_generated:
	@rm -rf generated
	@echo "已清除可重建產物"
