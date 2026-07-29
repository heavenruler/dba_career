---
doc_id: "3417bbea01f3da303fe6587e9ec538f1"
title: "默认配置下，为什么 MySQL 8.0 比 MySQL 5.7 慢？"
aliases:
  - "默认配置下，为什么 MySQL 8.0 比 MySQL 5.7 慢？"
url: "https://mp.weixin.qq.com/s/9gAWS_UUpyFlDXP2xsZG-g"
source_domain: "mp.weixin.qq.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "性能调优"
  - "数据库"
  - "InnoDB"
  - "故障排查"
generated: true
---

# 默认配置下，为什么 MySQL 8.0 比 MySQL 5.7 慢？

> [!info] Provenance
> - doc_id: `3417bbea01f3da303fe6587e9ec538f1`
> - source_kind: `llm_filtered`
> - source: [original URL](https://mp.weixin.qq.com/s/9gAWS_UUpyFlDXP2xsZG-g)
> - PDF: [open local PDF](../../collector/3417bbea01f3da303fe6587e9ec538f1.pdf)

## Summary

本文通过在 MySQL 5.7 与 8.0 上执行相同的存储过程插入测试，比较默认配置下的性能差异。作者先排查了 InnoDB 相关参数与磁盘性能，发现这些因素不足以解释差距，随后定位到 transaction_write_set_extraction 与 MySQL 8.0 默认开启 binlog 是主要影响项；关闭 binlog 后，两者插入性能差距明显缩小。

## Knowledge Outline

- 现象与默认配置 — MySQL, 性能对比, 默认配置, InnoDB, 参数
- 排查与磁盘验证 — MySQL, fio, 磁盘性能, 性能排查, 数据库
- 根因与结论 — MySQL, transaction_write_set_extraction, binlog, 性能优化, 插入性能

## Repository Paths

- PDF: `collector/3417bbea01f3da303fe6587e9ec538f1.pdf`
- Extracted: `generated/extracted/3417bbea01f3da303fe6587e9ec538f1/full.md`
- Filtered: `generated/filtered/3417bbea01f3da303fe6587e9ec538f1/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
