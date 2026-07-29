---
doc_id: "f24cbbd6a04f8ca036d5113ed745aab5"
title: "TiDB 中的自增主键有哪些使用限制，应该如何避免？大家好，我是V 哥，在TiDB中使用自增主键时，确实存在一些限制和潜 - 掘金"
aliases:
  - "TiDB 中的自增主键有哪些使用限制，应该如何避免？大家好，我是V 哥，在TiDB中使用自增主键时，确实存在一些限制和潜 - 掘金"
url: "https://juejin.cn/post/7416272705513111561"
source_domain: "juejin.cn"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "TiDB"
  - "数据库"
  - "分布式主键"
  - "AUTO_RANDOM"
  - "SHARD_ROW_ID_BITS"
  - "性能优化"
generated: true
---

# TiDB 中的自增主键有哪些使用限制，应该如何避免？大家好，我是V 哥，在TiDB中使用自增主键时，确实存在一些限制和潜 - 掘金

> [!info] Provenance
> - doc_id: `f24cbbd6a04f8ca036d5113ed745aab5`
> - source_kind: `llm_filtered`
> - source: [original URL](https://juejin.cn/post/7416272705513111561)
> - PDF: [open local PDF](../../collector/f24cbbd6a04f8ca036d5113ed745aab5.pdf)

## Summary

文章讨论 TiDB 自增主键的限制，以及用 AUTO_RANDOM、SHARD_ROW_ID_BITS 缓解写入热点的做法，并给出建表示例和调整思路。

## Knowledge Outline

- 自增主键限制 — TiDB, 自增主键, 限制, 数据库
- AUTO_RANDOM — TiDB, AUTO_RANDOM, 写入热点, 主键, 性能优化
- SHARD_ROW_ID_BITS — TiDB, SHARD_ROW_ID_BITS, 热点Region, 分布式, 性能优化
- 调整 SHARD_ROW_ID_BITS — TiDB, SHARD_ROW_ID_BITS, 配置调整, Region, 监控
- 结论 — TiDB, 主键, 分布式ID, 总结

## Repository Paths

- PDF: `collector/f24cbbd6a04f8ca036d5113ed745aab5.pdf`
- Extracted: `generated/extracted/f24cbbd6a04f8ca036d5113ed745aab5/full.md`
- Filtered: `generated/filtered/f24cbbd6a04f8ca036d5113ed745aab5/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
