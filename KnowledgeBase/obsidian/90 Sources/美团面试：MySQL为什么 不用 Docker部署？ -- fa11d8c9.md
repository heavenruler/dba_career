---
doc_id: "fa11d8c9e87a9646e588e48bc28e7d1e"
title: "美团面试：MySQL为什么 不用 Docker部署？"
aliases:
  - "美团面试：MySQL为什么 不用 Docker部署？"
url: "https://mp.weixin.qq.com/s/PD-BjDw0G-e2WhBG1dn29A"
source_domain: "mp.weixin.qq.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "Docker"
  - "数据库"
  - "架构设计"
  - "性能调优"
  - "SRE"
  - "面试"
  - "Share Nothing"
generated: true
---

# 美团面试：MySQL为什么 不用 Docker部署？

> [!info] Provenance
> - doc_id: `fa11d8c9e87a9646e588e48bc28e7d1e`
> - source_kind: `llm_filtered`
> - source: [original URL](https://mp.weixin.qq.com/s/PD-BjDw0G-e2WhBG1dn29A)
> - PDF: [open local PDF](../../collector/fa11d8c9e87a9646e588e48bc28e7d1e.pdf)

## Summary

本文主要讨论 MySQL 为什么通常不推荐用 Docker 部署，核心理由集中在有状态服务的持久化与扩容复杂度、Docker 资源隔离不彻底、磁盘 IO 性能损耗，以及大型 MySQL 在稳定性和维护上的额外成本。同时也补充了 Docker 的优势、Share Nothing 架构背景，以及小型 MySQL 在特定场景下仍可使用 Docker。

## Knowledge Outline

- 有状态容器与 MySQL — Docker, MySQL, 数据库, 有状态, 无状态, 扩容
- 持久化与本地双实例 — Docker, MySQL, 持久化, 部署, 配置, 容器
- 扩容困境 — MySQL, Docker, 扩容, binlog, 数据持久化
- 资源隔离与 IO — Docker, MySQL, 资源隔离, IO, 性能, SRE
- Docker 优势 — Docker, 自动伸缩, 容灾, 开发生产一致性, 快速部署, 隔离性
- 大型 MySQL 与 Share Nothing — MySQL, Share Nothing, 分布式数据库, 架构设计, 高可用, 扩展性
- 小型 MySQL 仍可用 Docker — MySQL, Docker, 小型数据库, 部署

## Repository Paths

- PDF: `collector/fa11d8c9e87a9646e588e48bc28e7d1e.pdf`
- Extracted: `generated/extracted/fa11d8c9e87a9646e588e48bc28e7d1e/full.md`
- Filtered: `generated/filtered/fa11d8c9e87a9646e588e48bc28e7d1e/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
