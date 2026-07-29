---
doc_id: "13802f213af712dae47aa9d1df634b54"
title: "在MongoDB建模1对N关系的基本方法 - 墨天轮"
aliases:
  - "在MongoDB建模1对N关系的基本方法 - 墨天轮"
url: "https://www.modb.pro/db/1770628513246285824"
source_domain: "www.modb.pro"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MongoDB"
  - "資料建模"
  - "一對多關係"
  - "資料庫非規範化"
  - "架構設計"
  - "效能調優"
generated: true
---

# 在MongoDB建模1对N关系的基本方法 - 墨天轮

> [!info] Provenance
> - doc_id: `13802f213af712dae47aa9d1df634b54`
> - source_kind: `llm_filtered`
> - source: [original URL](https://www.modb.pro/db/1770628513246285824)
> - PDF: [open local PDF](../../collector/13802f213af712dae47aa9d1df634b54.pdf)

## Summary

本文介绍 MongoDB 中一对 N 关系建模的基本与中级模式，包括嵌入、子引用、父引用、双向引用，以及数据库非规范化的适用条件、读写比权衡和经验法则。

## Knowledge Outline

- 一對 N 建模問題 — MongoDB, 資料建模, 一對多關係
- 嵌入文件模式 — MongoDB, 嵌入文件, 資料建模
- 引用陣列模式 — MongoDB, ObjectID, 引用, 應用程式級聯接
- 引用陣列權衡 — MongoDB, 索引, 引用, 資料建模
- 父引用模式 — MongoDB, 父引用, 日誌, 高基數
- 基本模式選擇 — MongoDB, 決策框架, 資料建模
- 雙向引用 — MongoDB, 雙向引用, 資料建模
- 雙向引用限制 — MongoDB, 雙向引用, 一致性, 原子更新
- 多到一非規範化 — MongoDB, 非規範化, 讀取效能
- 非規範化查詢與成本 — MongoDB, 非規範化, 讀寫比, 一致性
- 一到多非規範化 — MongoDB, 非規範化, 讀寫比
- 一對海量非規範化 — MongoDB, 非規範化, 日誌, 查詢效能
- 使用 $push 維護摘要 — MongoDB, $push, $each, $slice, 日誌
- 投影與更新頻率 — MongoDB, 投影, 網路開銷, 讀寫比
- 中級模式回顧 — MongoDB, 雙向引用, 非規範化, 決策框架
- 非規範化選擇空間 — MongoDB, 資料建模, 決策框架
- 資料建模經驗法則 — MongoDB, 資料建模, 經驗法則, 讀寫比
- 建模主要標準 — MongoDB, 資料建模, 決策框架
- 資料結構選擇 — MongoDB, 資料建模, 非規範化
- 非規範化定義 — MongoDB, 非規範化, 讀取效能, $lookup
- 非規範化與 MongoDB — MongoDB, 非規範化, 交易, 一致性
- 何時非規範化 — MongoDB, 非規範化, $lookup, 讀寫比, 操作資料庫
- 何時標準化 — MongoDB, 標準化, 引用, 多對多

## Repository Paths

- PDF: `collector/13802f213af712dae47aa9d1df634b54.pdf`
- Extracted: `generated/extracted/13802f213af712dae47aa9d1df634b54/full.md`
- Filtered: `generated/filtered/13802f213af712dae47aa9d1df634b54/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
