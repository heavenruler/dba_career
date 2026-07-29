---
doc_id: "085302eadb992a732a584739377a1221"
title: "你真的理解mysql的事务隔离吗？"
aliases:
  - "你真的理解mysql的事务隔离吗？"
url: "https://mp.weixin.qq.com/s?__biz=MzI1NTQwNDU4MA==&mid=2247483774&idx=1&sn=6e9636ff66bd644db2ac46fad3df4228&chksm=ea373e35dd40b7235881e349f4c0425df99513995e9d2f83ab02432b5f4151549743fc1bd845&scene=132#wechat_redirect"
source_domain: "mp.weixin.qq.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "事务隔离"
  - "MVCC"
  - "数据库"
  - "ACID"
  - "面试"
generated: true
---

# 你真的理解mysql的事务隔离吗？

> [!info] Provenance
> - doc_id: `085302eadb992a732a584739377a1221`
> - source_kind: `llm_filtered`
> - source: [original URL](https://mp.weixin.qq.com/s?__biz=MzI1NTQwNDU4MA==&mid=2247483774&idx=1&sn=6e9636ff66bd644db2ac46fad3df4228&chksm=ea373e35dd40b7235881e349f4c0425df99513995e9d2f83ab02432b5f4151549743fc1bd845&scene=132#wechat_redirect)
> - PDF: [open local PDF](../../collector/085302eadb992a732a584739377a1221.pdf)

## Summary

本文主要解释 MySQL 事务的 ACID、四种隔离级别、脏读/不可重复读/幻读、读提交与可重复读的差异，以及 MVCC、快照读/当前读和 undo log 的实现思路。

## Knowledge Outline

- ACID 与隔离级别 — MySQL, 事务, ACID, 事务隔离, 隔离级别, 脏读, 不可重复读, 幻读
- 读提交与可重复读 — MySQL, 读提交, 可重复读, 一致性视图, 快照
- 事务快照 — MySQL, 事务隔离, 快照, 一致性快照, 当前读, 锁等待
- MVCC 实现 — MySQL, MVCC, transaction id, row trx_id, undo log, 版本链

## Repository Paths

- PDF: `collector/085302eadb992a732a584739377a1221.pdf`
- Extracted: `generated/extracted/085302eadb992a732a584739377a1221/full.md`
- Filtered: `generated/filtered/085302eadb992a732a584739377a1221/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
