---
doc_id: "1d02b0538b388d871bc9b697c65cbafb"
title: "写了 5 年 SQL，才发现可以用 (a, b) > (x, y) 这种神仙写法！"
aliases:
  - "写了 5 年 SQL，才发现可以用 (a, b) > (x, y) 这种神仙写法！"
url: "https://mp.weixin.qq.com/s/aVlUDXmp7XV0U46EH-cQvw"
source_domain: "mp.weixin.qq.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "SQL"
  - "資料庫"
  - "效能調優"
  - "分頁"
  - "索引"
  - "複合主鍵"
generated: true
---

# 写了 5 年 SQL，才发现可以用 (a, b) > (x, y) 这种神仙写法！

> [!info] Provenance
> - doc_id: `1d02b0538b388d871bc9b697c65cbafb`
> - source_kind: `llm_filtered`
> - source: [original URL](https://mp.weixin.qq.com/s/aVlUDXmp7XV0U46EH-cQvw)
> - PDF: [open local PDF](../../collector/1d02b0538b388d871bc9b697c65cbafb.pdf)

## Summary

這篇文章介紹 SQL 的行比較（row comparison）語法，說明元組的字典序比較規則，並延伸到高性能游標分页、複合主鍵批量查詢、版本號比較，以及在 MySQL 中的索引、方向一致性與 NULL 注意事項。

## Knowledge Outline

- 元组字典序比较 — SQL, 資料庫, 字典序, 行比較
- 游标分页 — SQL, Keyset Pagination, 效能調優, 分頁
- 游标分页写法 — SQL, Keyset Pagination, 游標分頁
- 复合主键批量查询 — SQL, 複合主鍵, IN, 資料庫優化
- 版本号比较 — SQL, 版本號, 字串比較, 資料庫
- 索引注意事项 — SQL, 索引, MySQL, NULL, 效能調優
- 总结 — SQL, 总結, 行比較, 效能調優

## Repository Paths

- PDF: `collector/1d02b0538b388d871bc9b697c65cbafb.pdf`
- Extracted: `generated/extracted/1d02b0538b388d871bc9b697c65cbafb/full.md`
- Filtered: `generated/filtered/1d02b0538b388d871bc9b697c65cbafb/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
