---
doc_id: "96c9d9f34828ceb755d35e4beffb4249"
title: "MySQL里藏着一个会自己长大的文件，90%的DBA都忽略了"
aliases:
  - "MySQL里藏着一个会自己长大的文件，90%的DBA都忽略了"
url: "https://mp.weixin.qq.com/s/IreQ1pwRsYfRcYZ-v9ePpQ"
source_domain: "mp.weixin.qq.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "DBA"
  - "InnoDB"
  - "临时表"
  - "性能调优"
  - "故障排查"
  - "SQL优化"
generated: true
---

# MySQL里藏着一个会自己长大的文件，90%的DBA都忽略了

> [!info] Provenance
> - doc_id: `96c9d9f34828ceb755d35e4beffb4249`
> - source_kind: `llm_filtered`
> - source: [original URL](https://mp.weixin.qq.com/s/IreQ1pwRsYfRcYZ-v9ePpQ)
> - PDF: [open local PDF](../../collector/96c9d9f34828ceb755d35e4beffb4249.pdf)

## Summary

本文讲解 MySQL InnoDB 临时表空间 ibtmp1 的作用、膨胀原因、处理方法与预防配置，并列出常见触发临时表的 SQL 场景和相关参数。

## Knowledge Outline

- ibtmp1 的作用 — MySQL, InnoDB, 临时表, DBA, 性能调优
- 处理与限制 — MySQL, InnoDB, 故障排查, 配置, 性能调优
- 触发临时表的 SQL — MySQL, SQL优化, 执行计划, 临时表, 性能调优
- 复现与参数 — MySQL, 临时表, 参数, 故障复现, 性能调优
- 结尾总结 — MySQL, DBA, 故障复盘, 性能调优, SQL优化

## Repository Paths

- PDF: `collector/96c9d9f34828ceb755d35e4beffb4249.pdf`
- Extracted: `generated/extracted/96c9d9f34828ceb755d35e4beffb4249/full.md`
- Filtered: `generated/filtered/96c9d9f34828ceb755d35e4beffb4249/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
