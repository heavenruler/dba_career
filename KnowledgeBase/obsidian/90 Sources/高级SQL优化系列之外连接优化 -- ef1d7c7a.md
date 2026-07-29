---
doc_id: "ef1d7c7aad615b5d23ecb62a7d6419c4"
title: "高级SQL优化系列之外连接优化"
aliases:
  - "高级SQL优化系列之外连接优化"
url: "https://mp.weixin.qq.com/s?__biz=MzkyODM0NzE1Ng==&mid=2247483813&idx=1&sn=18ecaef134a1c847a2c115d739efa86e&chksm=c21b64def56cedc8eb5d4bdb438085e3771851fa964dca7ba58c113f6f43b2bfa2c1e454a4af&scene=132#wechat_redirect"
source_domain: "mp.weixin.qq.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "SQL优化"
  - "外连接"
  - "内连接重写"
  - "NFC"
  - "MySQL"
  - "PostgreSQL"
  - "索引推荐"
  - "查询优化"
generated: true
---

# 高级SQL优化系列之外连接优化

> [!info] Provenance
> - doc_id: `ef1d7c7aad615b5d23ecb62a7d6419c4`
> - source_kind: `llm_filtered`
> - source: [original URL](https://mp.weixin.qq.com/s?__biz=MzkyODM0NzE1Ng==&mid=2247483813&idx=1&sn=18ecaef134a1c847a2c115d739efa86e&chksm=c21b64def56cedc8eb5d4bdb438085e3771851fa964dca7ba58c113f6f43b2bfa2c1e454a4af&scene=132#wechat_redirect)
> - PDF: [open local PDF](../../collector/ef1d7c7aad615b5d23ecb62a7d6419c4.pdf)

## Summary

这篇文章聚焦外连接优化，说明外连接为何会限制优化器的连接顺序选择，介绍空拒绝条件（NFC）如何触发外连接到内连接的简化重写，并展示 MySQL、PostgreSQL 以及 PawSQL 在该类改写上的执行计划与索引推荐效果。

## Knowledge Outline

- 外连接与执行计划 — SQL优化, 外连接, 执行计划, 优化器, MySQL
- 外连接简化与NFC — SQL优化, 外连接, NFC, 谓词下推, 重写优化
- NFC 判定示例 — SQL优化, NFC, 条件判定, 外连接
- 数据库示例 — MySQL, PostgreSQL, SQL优化, 外连接, 执行计划
- PawSQL 重写与索引推荐 — PawSQL, 索引推荐, SQL优化, PostgreSQL, MySQL, 外连接重写

## Repository Paths

- PDF: `collector/ef1d7c7aad615b5d23ecb62a7d6419c4.pdf`
- Extracted: `generated/extracted/ef1d7c7aad615b5d23ecb62a7d6419c4/full.md`
- Filtered: `generated/filtered/ef1d7c7aad615b5d23ecb62a7d6419c4/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
