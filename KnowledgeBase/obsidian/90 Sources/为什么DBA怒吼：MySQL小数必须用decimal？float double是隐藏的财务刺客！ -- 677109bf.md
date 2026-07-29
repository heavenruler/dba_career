---
doc_id: "677109bf61d41cae7f523d3703c4a8ee"
title: "为什么DBA怒吼：MySQL小数必须用decimal？float/double是隐藏的财务刺客！"
aliases:
  - "为什么DBA怒吼：MySQL小数必须用decimal？float/double是隐藏的财务刺客！"
url: "https://mp.weixin.qq.com/s/F6elSTBOZBOitl4etZAVwg"
source_domain: "mp.weixin.qq.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "decimal"
  - "float/double"
  - "精度"
  - "财务系统"
  - "IEEE 754"
  - "DBA"
  - "金融"
generated: true
---

# 为什么DBA怒吼：MySQL小数必须用decimal？float/double是隐藏的财务刺客！

> [!info] Provenance
> - doc_id: `677109bf61d41cae7f523d3703c4a8ee`
> - source_kind: `llm_filtered`
> - source: [original URL](https://mp.weixin.qq.com/s/F6elSTBOZBOitl4etZAVwg)
> - PDF: [open local PDF](../../collector/677109bf61d41cae7f523d3703c4a8ee.pdf)

## Summary

文章用 MySQL 小数计算与记账场景说明 float/double 的精度风险，展示常量表达式的“看似正确”与实际存储误差、IEEE 754 的二进制表示限制、decimal 的 BCD 存储与精确聚合，以及财务场景下的选型原则。

## Knowledge Outline

- 常量表达式陷阱 — MySQL, float, double, 精度, SQL
- IEEE 754 精度问题 — IEEE 754, float, double, 精度, 二进制浮点
- 记账示例 — MySQL, 财务, 记账, double, decimal, SQL
- decimal 存储原理 — decimal, BCD, MySQL, 存储原理, 精度
- 精确计算示例 — decimal, 精确计算, 加密货币, 聚合, MySQL
- 类型对比与选型法则 — decimal, float, double, 选型, 金融, DBA

## Repository Paths

- PDF: `collector/677109bf61d41cae7f523d3703c4a8ee.pdf`
- Extracted: `generated/extracted/677109bf61d41cae7f523d3703c4a8ee/full.md`
- Filtered: `generated/filtered/677109bf61d41cae7f523d3703c4a8ee/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
