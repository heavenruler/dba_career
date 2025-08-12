# HTML 轉 PDF 解決方案比較

## 解決方案概覽

| 方法 | 優點 | 缺點 | 安裝難度 | 渲染品質 | 速度 |
|------|------|------|----------|----------|------|
| **Chrome Headless** | 高品質渲染、支援 JavaScript | 需要 Chrome、資源消耗大 | ⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ |
| **wkhtmltopdf** | 輕量、快速、穩定 | 渲染品質一般、不支援現代 CSS | ⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| **WeasyPrint** | 高品質、支援現代 CSS | 安裝複雜、依賴多 | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ |
| **Playwright** | 現代瀏覽器引擎、支援 JavaScript | 資源消耗大、安裝複雜 | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ |
| **Pandoc** | 多功能、支援多格式 | 需要外部引擎、配置複雜 | ⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐ |
| **Selenium** | 完全控制、支援 JavaScript | 資源消耗大、速度慢 | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐ |
| **pdfkit** | Python 包裝器、易用 | 依賴 wkhtmltopdf | ⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐ |
| **requests-html** | 簡單易用 | 需要額外 PDF 引擎 | ⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐ |

## 詳細比較

### 1. Chrome Headless 模式
```bash
# 優點
- 高品質渲染，與真實瀏覽器一致
- 完整支援 JavaScript 和現代 CSS
- 無需額外安裝（如果已有 Chrome）

# 缺點
- 資源消耗較大
- 需要 Chrome 瀏覽器
- 在某些環境中可能不穩定
```

### 2. wkhtmltopdf
```bash
# 優點
- 輕量級，資源消耗小
- 速度快
- 穩定可靠
- 廣泛支援

# 缺點
- 渲染品質一般
- 不支援某些現代 CSS 特性
- 對 JavaScript 支援有限
```

### 3. WeasyPrint
```bash
# 優點
- 高品質渲染
- 支援現代 CSS 標準
- 可自定義樣式
- 支援字體嵌入

# 缺點
- 安裝複雜，依賴多
- 在某些系統上可能有問題
- 對 JavaScript 支援有限
```

### 4. Playwright
```bash
# 優點
- 現代瀏覽器引擎
- 完整支援 JavaScript
- 高品質渲染
- 跨平台支援

# 缺點
- 資源消耗大
- 安裝複雜
- 需要下載瀏覽器二進制檔案
```

### 5. Pandoc
```bash
# 優點
- 多功能文檔轉換工具
- 支援多種輸入輸出格式
- 可與多種 PDF 引擎配合

# 缺點
- 需要外部 PDF 引擎
- 配置複雜
- 對 HTML 渲染支援有限
```

### 6. Selenium
```bash
# 優點
- 完全控制瀏覽器
- 支援所有瀏覽器功能
- 可自動化複雜操作

# 缺點
- 資源消耗大
- 速度慢
- 需要瀏覽器驅動
- 配置複雜
```

### 7. pdfkit
```bash
# 優點
- Python 包裝器，易於使用
- 基於成熟的 wkhtmltopdf
- 配置簡單

# 缺點
- 依賴 wkhtmltopdf
- 功能受限於底層引擎
```

### 8. requests-html
```bash
# 優點
- 簡單易用
- 支援 JavaScript 渲染
- Python 原生支援

# 缺點
- 需要額外 PDF 引擎
- 功能有限
```

## 推薦使用場景

### 🏆 最佳選擇
- **一般用途**: Chrome Headless 或 wkhtmltopdf
- **高品質需求**: WeasyPrint 或 Playwright
- **簡單快速**: pdfkit
- **複雜網頁**: Selenium

### 📋 安裝指南

```bash
# 安裝所有依賴
make install_pdf_deps

# 測試所有方法
make test_pdf_methods

# 下載特定網頁
make download_specific
```

### 🔧 快速開始

```python
# 使用 Chrome Headless
python3 scripts/download_specific_pdf_chrome.py

# 使用 WeasyPrint
pip install weasyprint
python3 scripts/download_specific_pdf_simple.py

# 使用 Playwright
pip install playwright
playwright install chromium
python3 scripts/download_specific_pdf_playwright.py
```

## 注意事項

1. **安全性**: 不要使用不受信任的 HTML 內容
2. **性能**: 根據需求選擇合適的工具
3. **維護**: 定期更新依賴包
4. **測試**: 在目標環境中測試所有方法
