---
doc_id: "63f9298623511a70589f45ada9401398"
title: "字节一面：20亿手机号存储选int还是string？varchar还是char？为什么？"
aliases:
  - "字节一面：20亿手机号存储选int还是string？varchar还是char？为什么？"
url: "https://mp.weixin.qq.com/s/svWY28jSDkwCzB4Xkq1ClQ"
source_domain: "mp.weixin.qq.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "DBA"
  - "数据建模"
  - "MySQL"
  - "面试"
  - "数据完整性"
  - "索引设计"
  - "字段设计"
  - "安全"
generated: true
---

# 字节一面：20亿手机号存储选int还是string？varchar还是char？为什么？

> [!info] Provenance
> - doc_id: `63f9298623511a70589f45ada9401398`
> - source_kind: `llm_filtered`
> - source: [original URL](https://mp.weixin.qq.com/s/svWY28jSDkwCzB4Xkq1ClQ)
> - PDF: [open local PDF](../../collector/63f9298623511a70589f45ada9401398.pdf)

## Summary

这篇文章围绕手机号存储的面试题，核心价值在于说明为什么不适合用 int 存手机号，以及为什么实际设计中更倾向用 VARCHAR 并预留扩展长度；同时补充了索引、清洗、校验、隐私等日常建模注意事项。

## Knowledge Outline

- 为什么不用 Int — DBA, MySQL, 面试, 数据完整性, 字段设计
- 为什么用 String / VARCHAR — DBA, MySQL, 面试, 字段设计, 业务扩展性, 数据容错性
- 日常开发避坑 — DBA, MySQL, 索引设计, 数据清洗, 校验, 安全, 正则

## Repository Paths

- PDF: `collector/63f9298623511a70589f45ada9401398.pdf`
- Extracted: `generated/extracted/63f9298623511a70589f45ada9401398/full.md`
- Filtered: `generated/filtered/63f9298623511a70589f45ada9401398/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
