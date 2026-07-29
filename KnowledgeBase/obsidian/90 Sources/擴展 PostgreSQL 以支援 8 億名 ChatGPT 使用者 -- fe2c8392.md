---
doc_id: "fe2c8392501d406156efc25b53110da9"
title: "擴展 PostgreSQL 以支援 8 億名 ChatGPT 使用者"
aliases:
  - "擴展 PostgreSQL 以支援 8 億名 ChatGPT 使用者"
url: "https://openai.com/zh-Hant/index/scaling-postgresql/"
source_domain: "openai.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "PostgreSQL"
  - "資料庫"
  - "SRE"
  - "效能調優"
  - "雲端"
  - "高可用性"
  - "快取"
  - "連線池"
  - "事故覆盤"
generated: true
---

# 擴展 PostgreSQL 以支援 8 億名 ChatGPT 使用者

> [!info] Provenance
> - doc_id: `fe2c8392501d406156efc25b53110da9`
> - source_kind: `llm_filtered`
> - source: [original URL](https://openai.com/zh-Hant/index/scaling-postgresql/)
> - PDF: [open local PDF](../../collector/fe2c8392501d406156efc25b53110da9.pdf)

## Summary

文章說明 OpenAI 如何在 Azure PostgreSQL 上，以單一主要執行個體搭配近 50 個讀取副本，透過查詢最佳化、快取鎖定、PgBouncer、工作負載隔離、速限與嚴格的結構描述管理，把讀取密集型工作負載擴展到每秒數百萬次查詢，同時降低 SEV、延遲與主節點壓力。

## Knowledge Outline

- 概覽 — PostgreSQL, 雲端, 擴展性, SRE
- 初始架構問題 — PostgreSQL, SEV, 事故覆盤, SRE, 效能
- MVCC 限制 — PostgreSQL, MVCC, 資料庫內部, 效能調優
- 分流寫入 — PostgreSQL, 資料分割, 寫入分流, 架構設計
- 主節點負載控制 — PostgreSQL, 主節點, 寫入壓力, 速限, 應用程式最佳化
- 查詢最佳化 — PostgreSQL, SQL, ORM, OLTP, 效能調優
- 讀取可用性 — 高可用性, 容錯移轉, 讀取副本, PostgreSQL
- 工作負載隔離 — 工作負載隔離, 多租戶, 資源治理, SRE
- 連線池 — PgBouncer, 連線池, PostgreSQL, 延遲
- 快取 — 快取, cache stampede, PostgreSQL, 效能調優
- 讀取副本擴充 — 讀取副本, WAL, 級聯複寫, Azure PostgreSQL
- 速限 — 速限, 重試風暴, ORM, SRE
- 結構描述管理 — Schema management, PostgreSQL, 發布管理, 寫入控制
- 結果與後續 — PostgreSQL, 可用性, 延遲, 讀取副本, 未來擴展

## Repository Paths

- PDF: `collector/fe2c8392501d406156efc25b53110da9.pdf`
- Extracted: `generated/extracted/fe2c8392501d406156efc25b53110da9/full.md`
- Filtered: `generated/filtered/fe2c8392501d406156efc25b53110da9/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
