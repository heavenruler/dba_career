---
doc_id: "89d071d4305029494eb3bd42da658e75"
title: "当数据库的主要用户不再是人类：我们在 AI Agent 场景下的架构实践与思考"
aliases:
  - "当数据库的主要用户不再是人类：我们在 AI Agent 场景下的架构实践与思考"
url: "https://mp.weixin.qq.com/s/ZlMhflW6crubrwmXfuh5MA"
source_domain: "mp.weixin.qq.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "数据库"
  - "AI Agent"
  - "架构设计"
  - "多租户"
  - "存算分离"
  - "长上下文"
  - "在线DDL"
  - "记忆基础设施"
  - "性能调优"
  - "云数据库"
generated: true
---

# 当数据库的主要用户不再是人类：我们在 AI Agent 场景下的架构实践与思考

> [!info] Provenance
> - doc_id: `89d071d4305029494eb3bd42da658e75`
> - source_kind: `llm_filtered`
> - source: [original URL](https://mp.weixin.qq.com/s/ZlMhflW6crubrwmXfuh5MA)
> - PDF: [open local PDF](../../collector/89d071d4305029494eb3bd42da658e75.pdf)

## Summary

本文讨论 AI Agent 成为数据库主要用户后，数据库架构如何变化。核心内容包括海量短命实例、多租户与存算分离、长上下文直接入库、在线 DDL、真实工作负载压测，以及面向 Agent 的持久记忆基础设施 mem9。

## Knowledge Outline

- 趋势与负载特征 — AI Agent, 数据库, 工作负载, 多租户, 长上下文, 成本模型
- 案例一：百万 Agent 租户 — AI Agent, 多租户, 存算分离, 弹性, 资源隔离, 压测, 查询优化
- 案例二：长上下文入库 — AI 硬件, 长上下文, 对象存储, 一致性, 在线DDL, 数据库设计
- 案例三与记忆层 — 大模型, 数据库架构, 复杂度, 记忆系统, mem9, 检索, 向量搜索, 系统设计

## Repository Paths

- PDF: `collector/89d071d4305029494eb3bd42da658e75.pdf`
- Extracted: `generated/extracted/89d071d4305029494eb3bd42da658e75/full.md`
- Filtered: `generated/filtered/89d071d4305029494eb3bd42da658e75/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
