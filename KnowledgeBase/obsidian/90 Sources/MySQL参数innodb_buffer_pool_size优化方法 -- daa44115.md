---
doc_id: "daa4411582408500b5be400ff24ce477"
title: "MySQL参数innodb_buffer_pool_size优化方法"
aliases:
  - "MySQL参数innodb_buffer_pool_size优化方法"
url: "https://mp.weixin.qq.com/s/Sxg1FHHITufWUW3J-HES5g"
source_domain: "mp.weixin.qq.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "InnoDB"
  - "buffer pool"
  - "性能调优"
  - "数据库"
  - "运维"
generated: true
---

# MySQL参数innodb_buffer_pool_size优化方法

> [!info] Provenance
> - doc_id: `daa4411582408500b5be400ff24ce477`
> - source_kind: `llm_filtered`
> - source: [original URL](https://mp.weixin.qq.com/s/Sxg1FHHITufWUW3J-HES5g)
> - PDF: [open local PDF](../../collector/daa4411582408500b5be400ff24ce477.pdf)

## Summary

本文说明了 innodb_buffer_pool_size 的作用、内存评估思路、基于状态变量的调优参考、在线修改方式，以及持久化到配置文件的方法。

## Knowledge Outline

- 作用与影响 — MySQL, InnoDB, 性能调优, 数据库
- 内存评估 — MySQL, InnoDB, 内存规划, 性能调优
- 调优参考 — MySQL, InnoDB, 状态变量, 性能调优, 参考公式
- 在线调整 — MySQL, InnoDB, 在线变更, 风险提示
- 配置文件 — MySQL, 配置文件, 持久化配置, 性能调优

## Repository Paths

- PDF: `collector/daa4411582408500b5be400ff24ce477.pdf`
- Extracted: `generated/extracted/daa4411582408500b5be400ff24ce477/full.md`
- Filtered: `generated/filtered/daa4411582408500b5be400ff24ce477/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
