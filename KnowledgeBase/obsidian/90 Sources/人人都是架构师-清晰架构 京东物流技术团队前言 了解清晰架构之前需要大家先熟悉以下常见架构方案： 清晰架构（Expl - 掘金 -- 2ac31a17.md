---
doc_id: "2ac31a1732680e72a16f3f3c2b711d09"
title: "人人都是架构师-清晰架构 | 京东物流技术团队前言 了解清晰架构之前需要大家先熟悉以下常见架构方案： 清晰架构（Expl - 掘金"
aliases:
  - "人人都是架构师-清晰架构 | 京东物流技术团队前言 了解清晰架构之前需要大家先熟悉以下常见架构方案： 清晰架构（Expl - 掘金"
url: "https://juejin.cn/post/7337533680239231030"
source_domain: "juejin.cn"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "软件架构"
  - "清晰架构"
  - "DDD"
  - "端口与适配器"
  - "洋葱架构"
  - "CQRS"
  - "组件解耦"
  - "共享内核"
  - "C4模型"
generated: true
---

# 人人都是架构师-清晰架构 | 京东物流技术团队前言 了解清晰架构之前需要大家先熟悉以下常见架构方案： 清晰架构（Expl - 掘金

> [!info] Provenance
> - doc_id: `2ac31a1732680e72a16f3f3c2b711d09`
> - source_kind: `llm_filtered`
> - source: [original URL](https://juejin.cn/post/7337533680239231030)
> - PDF: [open local PDF](../../collector/2ac31a1732680e72a16f3f3c2b711d09.pdf)

## Summary

本文介紹清晰架構的形成、端口與適配器、控制反轉、應用核心分層、組件解耦、共享內核、代碼組織方式，以及用 C4 模型描述架構的方法。

## Knowledge Outline

- 清晰架構背景 — 清晰架构, 软件架构
- 系統基本構建塊 — 端口与适配器, 应用核心, 基础设施
- 工具 — 应用核心, 基础设施, 工具
- 適配器與端口 — 适配器, 端口, DTO, API
- 主動適配器 — 主动适配器, Controller, Service, Repository, 命令总线, 查询总线
- 被動適配器 — 被动适配器, 持久化接口, MySQL, PostgreSQL, MongoDB
- 控制反轉 — 控制反转, 依赖方向, 端口, 适配器
- 應用層 — 应用层, DDD, 用例, 应用服务, ORM, 命令总线, 查询总线
- 領域層 — 领域层, 领域服务, 领域模型, 实体, 值对象, 领域事件, 事件溯源
- 組件分包 — 组件, 限界上下文, 按组件分包, 按层次分包
- 組件解耦 — 组件解耦, 依赖注入, 依赖倒置, 事件, 共享内核, 最终一致性, 发现服务
- 觸發其他組件邏輯 — 领域事件, 事件派发器, 共享内核, 微服务, HTTP, 发现服务
- 跨組件資料 — 组件数据, 查询对象, 数据存储, 单一事实来源, 领域事件
- 控制流 — 控制流, 命令总线, 查询总线, UML, 应用服务, 依赖方向
- 共享內核 — 共享内核, DDD, 限界上下文, 领域模型, 微服务, json, xml, yaml
- 代碼體現架構 — 代码组织, 依赖方向, 共享内核
- 代碼風格 — 代码风格, 命名规范, 设计意图, 组件
- 根目錄結構 — 代码结构, 用户界面, 应用核心, 基础设施, 依赖测试
- 用戶界面命名空間 — 用户界面, API, CLI, REST, SOAP, GraphQL, 命名空间
- 基礎設施命名空間 — 基础设施, ORM, 消息队列, SMS, 适配器, 命名空间
- 核心命名空間 — Core, Component, Shared Kernel, Port, Application, Domain, DTO
- 編程語言擴展 — 编程语言扩展, PHP, DateTime, UUID, 第三方库
- 架構文檔工具 — 架构文档, UML, ADR, C4模型, 依赖图
- C4 模型 — C4模型, 架构文档, 系统上下文图, 容器图, 组件图, 代码图
- 系統上下文圖 — C4模型, 系统上下文图
- 容器圖 — C4模型, 容器图, API, 数据库
- 組件圖 — C4模型, 组件图, 模块
- 代碼圖 — C4模型, 代码图, UML
- 總結與取捨 — 清晰架构, BFF, CQRS, 领域层, 应用层, 高内聚低耦合

## Repository Paths

- PDF: `collector/2ac31a1732680e72a16f3f3c2b711d09.pdf`
- Extracted: `generated/extracted/2ac31a1732680e72a16f3f3c2b711d09/full.md`
- Filtered: `generated/filtered/2ac31a1732680e72a16f3f3c2b711d09/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
