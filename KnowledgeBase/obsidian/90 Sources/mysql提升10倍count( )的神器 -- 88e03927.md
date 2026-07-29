---
doc_id: "88e03927022b034a07fc05697d27b429"
title: "mysql提升10倍count(*)的神器"
aliases:
  - "mysql提升10倍count(*)的神器"
url: "https://mp.weixin.qq.com/s/XOYK9eGMxFlmPucUi7imcg"
source_domain: "mp.weixin.qq.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "InnoDB"
  - "效能調優"
  - "資料校驗"
  - "DBA"
  - "Python"
generated: true
---

# mysql提升10倍count(*)的神器

> [!info] Provenance
> - doc_id: `88e03927022b034a07fc05697d27b429`
> - source_kind: `llm_filtered`
> - source: [original URL](https://mp.weixin.qq.com/s/XOYK9eGMxFlmPucUi7imcg)
> - PDF: [open local PDF](../../collector/88e03927022b034a07fc05697d27b429.pdf)

## Summary

這篇文章介紹了一種直接讀取 InnoDB .ibd 檔案來統計行數的方法，用 PAGE_N_RECS 累加葉子節點記錄數，避免掃描整張表；適合做主從切換後的快速校驗、靜態資料的行數估算，但不適合頻繁更新或 IO 壓力大的表。

## Knowledge Outline

- 問題背景 — MySQL, 数据校验, DBA
- 统计原理 — InnoDB, B+Tree, MySQL, 效能調優
- 实现与验证 — Python, MySQL, 效能比較, 工具
- 命令与结果 — MySQL, Python, 性能测试, DBA
- 适用场景与限制 — MySQL, InnoDB, 限制, 运维

## Repository Paths

- PDF: `collector/88e03927022b034a07fc05697d27b429.pdf`
- Extracted: `generated/extracted/88e03927022b034a07fc05697d27b429/full.md`
- Filtered: `generated/filtered/88e03927022b034a07fc05697d27b429/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
