---
doc_id: "90a8dd6f2dddc0d00efe98fd30c36f8f"
title: "事务持续执行之谜：怎样找出对行记录上锁的 SQL？"
aliases:
  - "事务持续执行之谜：怎样找出对行记录上锁的 SQL？"
url: "https://mp.weixin.qq.com/s/y2zmEfwL-vAxQ15IvB5VNw"
source_domain: "mp.weixin.qq.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "InnoDB"
  - "锁等待"
  - "事务"
  - "性能排查"
  - "故障排查"
  - "SRE"
generated: true
---

# 事务持续执行之谜：怎样找出对行记录上锁的 SQL？

> [!info] Provenance
> - doc_id: `90a8dd6f2dddc0d00efe98fd30c36f8f`
> - source_kind: `llm_filtered`
> - source: [original URL](https://mp.weixin.qq.com/s/y2zmEfwL-vAxQ15IvB5VNw)
> - PDF: [open local PDF](../../collector/90a8dd6f2dddc0d00efe98fd30c36f8f.pdf)

## Summary

本文说明了当事务长期处于锁等待、但 show processlist 又看不到真正阻塞 SQL 时，如何通过 information_schema、sys 和 performance_schema 追踪未提交事务、等待锁关系，以及持有锁的线程 SQL，并给出快速排查与处理方式。

## Knowledge Outline

- 故障背景 — MySQL, 事务, 故障排查, 锁等待
- 故障复现 — MySQL, 事务, 锁等待, SQL, 故障复现
- 排查思路 — MySQL, InnoDB, 性能排查, 锁等待, performance_schema
- 解决方案 — MySQL, 锁等待, KILL, 故障处理
- 总结 — MySQL, InnoDB, 锁等待, 参数, 性能调优

## Repository Paths

- PDF: `collector/90a8dd6f2dddc0d00efe98fd30c36f8f.pdf`
- Extracted: `generated/extracted/90a8dd6f2dddc0d00efe98fd30c36f8f/full.md`
- Filtered: `generated/filtered/90a8dd6f2dddc0d00efe98fd30c36f8f/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
