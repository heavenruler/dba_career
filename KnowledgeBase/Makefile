SHELL := /bin/bash
.ONESHELL:
.PHONY: commit md5_fix

commit:
	mv ~/Downloads/FireShot/* collector ; git add . ; git commit -m "update" ; git push

# 修補 output_with_md5.txt 中遺漏或不正確的 MD5（例如佔位字 nnn）
md5_fix:
	@python3 scripts/md5_fix.py
	@echo "已修補 output_with_md5.txt 的 MD5 欄位"

# 重新分類知識庫內容
reclassify:
	@python3 scripts/reclassify.py
	@echo "已重新分類知識庫內容"

# 合併 knowledge_base_md5.json 到 knowledge_base.md
merge_kb:
	@python3 scripts/merge_kb.py
	@echo "已合併 knowledge_base_md5.json 到 knowledge_base.md"

# 檢查缺失的 PDF 檔案
check_pdfs:
	@python3 scripts/check_missing_pdfs.py
	@echo "已檢查缺失的 PDF 檔案"

# 安裝 wkhtmltopdf
install_wkhtmltopdf:
	@chmod +x scripts/install_wkhtmltopdf.sh
	@./scripts/install_wkhtmltopdf.sh
	@echo "已安裝 wkhtmltopdf"

# 下載指定的網頁為 PDF
download_specific:
	@python3 scripts/download_specific_pdf_official.py
	@echo "已下載指定的網頁為 PDF"

# 安裝所有 PDF 轉換依賴
install_pdf_deps:
	@chmod +x scripts/install_pdf_dependencies.sh
	@./scripts/install_pdf_dependencies.sh
	@echo "已安裝所有 PDF 轉換依賴"

# 測試所有 HTML 轉 PDF 方法
test_pdf_methods:
	@python3 scripts/html_to_pdf_solutions.py
	@echo "已測試所有 HTML 轉 PDF 方法"

# 簡易 PDF 轉換
convert_pdf:
	@if [ -z "$(URL)" ]; then \
		echo "使用方法: make convert_pdf URL=https://example.com"; \
		exit 1; \
	fi
	@source venv/bin/activate && python3 scripts/simple_pdf_converter.py "$(URL)"
	@echo "已轉換 URL 為 PDF"

# 批次 PDF 轉換
batch_convert:
	@if [ -z "$(FILE)" ]; then \
		echo "使用方法: make batch_convert FILE=urls.txt"; \
		exit 1; \
	fi
	@source venv/bin/activate && python3 scripts/batch_pdf_converter.py "$(FILE)"
	@echo "已完成批次轉換"

# 超快速 PDF 轉換
ultra_fast:
	@if [ -z "$(URL)" ]; then \
		echo "使用方法: make ultra_fast URL=https://example.com"; \
		exit 1; \
	fi
	@python3 scripts/ultra_fast_pdf.py "$(URL)"
	@echo "已完成超快速轉換"

# 簡單快速轉換
quick:
	@if [ -z "$(URL)" ]; then \
		echo "使用方法: make quick URL=https://example.com"; \
		exit 1; \
	fi
	@python3 scripts/quick_pdf.py "$(URL)"
	@echo "已完成快速轉換"
