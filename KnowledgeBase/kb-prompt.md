# KB Consumer Prompt（給其他 agent / codex 驗證用）

把整份貼進對方 session 即可。

---

## 1. 知識庫位置與結構

KB 在 `/Users/wn.lin/vscode-git/dba_career/KnowledgeBase/generated/`：

| 路徑 | 內容 | 數量 |
|---|---|---|
| `generated/kb/chunks.jsonl` | 主索引（每行一個 chunk） | 13228 |
| `generated/kb/documents.jsonl` | 文件概覽 | 897 |
| `generated/filtered/<doc_id>/knowledge.json` | LLM extractive 過濾後的結構化版 | 115+（持續增加） |
| `generated/extracted/<doc_id>/full.md` | pdftotext + OCR 原文 | 897 |
| `generated/extracted/<doc_id>/metadata.json` | 每篇 metadata | 897 |

主鍵：`doc_id`（PDF 的 md5）。Manifest：`/Users/wn.lin/vscode-git/dba_career/KnowledgeBase/output_with_md5.txt`。

`chunks.jsonl` 欄位：
```
doc_id, chunk_id, chunk_index, content, content_hash,
page_start, page_end, title, url, source_domain,
source_kind (llm_filtered | extracted_text),
source_content, source_pdf,
tags, primary_category, chunk_types,
classification_confidence, char_count, status, quality
```

`knowledge.json` 結構：
```
{doc_id, title, url, summary, tags, source_md,
 sections: [{heading, content, section_type, tags}, ...],
 discarded_noise, filter_provider, filter_model, filter_usage}
```

---

## 2. 取用優先順序（品質高→低）

1. `generated/filtered/<doc_id>/knowledge.json` — 已過雜訊；逐字 extractive
2. `chunks.jsonl` 中 `source_kind=llm_filtered` — 上一項的切塊
3. `chunks.jsonl` 中 `source_kind=extracted_text` — 未 filter，含頁眉 / 廣告 / 推薦閱讀
4. `generated/extracted/<doc_id>/full.md` — 最原始

---

## 3. Scope（**不限**資料庫）

- DBA / 資料庫核心：MySQL, PostgreSQL, Oracle, TiDB, CRDB, YBDB
- 系統架構 / SRE / 可觀測性
- 分析設計 / 演算法 / 系統設計
- 心理學 / 認知科學
- 職場 / 面試 / 履歷 / 溝通
- 研究方法

---

## 4. 驗證任務（請依序回答；每題標明引用來源）

請用上述 KB 回答以下問題。**每個答案必須附引用**：格式 `doc_id=<md5>  chunk_id=<id>  source_kind=<llm_filtered|extracted_text>`。

**Q1（資料庫 / 故障排查）**
MySQL CPU 飆到 100% 時，如何從 OS 一路定位到具體執行緒並對應到 SQL？請給完整步驟與會用到的指令 / 表。

**Q2（資料庫 / 架構）**
PolarDB MySQL 跨可用區強一致方案的核心機制是什麼？需要哪些前置設定？

**Q3（架構 / SRE）**
HikariCP 連線池在什麼情境下會出現 connection leak？要怎麼診斷？

**Q4（職涯 / 心理學）**
面試表達結構（如 STAR / 金字塔原理 / 邏輯樹）KB 內有哪些可用素材？挑 1–2 段直接引用。

**Q5（覆蓋率自評）**
逐題回報：
- 找到的 chunk 是 `llm_filtered` 還是 `extracted_text`？
- 內容是否完整可用，或被噪音稀釋（廣告 / 頁眉 / 殘缺）？
- 若答不出來，是 KB 真的沒有，還是檢索方法不對？

---

## 5. 約定

- 只讀 KB；**不要**修改 `generated/` 任何檔案
- 路徑使用絕對路徑，避免 cwd 假設
- chunks.jsonl 行多，建議用 `grep` 或 `jq` 過濾後再讀
- 找不到時直接說沒有，不要編造
