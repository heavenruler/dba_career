---
doc_id: "b0f0afe2c0476d3392780695022cc50a"
title: "数据同步要灵活隔离？TiCDC 独立部署 vs 混合部署该怎么选？"
aliases:
  - "数据同步要灵活隔离？TiCDC 独立部署 vs 混合部署该怎么选？"
url: "https://mp.weixin.qq.com/s/CgCjxAWuXfL87lg18DgLRg"
source_domain: "mp.weixin.qq.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "TiCDC"
  - "TiDB"
  - "数据同步"
  - "混合部署"
  - "独立部署"
  - "TiGateway"
  - "运维"
  - "架构设计"
generated: true
---

# 数据同步要灵活隔离？TiCDC 独立部署 vs 混合部署该怎么选？

> [!info] Provenance
> - doc_id: `b0f0afe2c0476d3392780695022cc50a`
> - source_kind: `llm_filtered`
> - source: [original URL](https://mp.weixin.qq.com/s/CgCjxAWuXfL87lg18DgLRg)
> - PDF: [open local PDF](../../collector/b0f0afe2c0476d3392780695022cc50a.pdf)

## Summary

文章对比 TiCDC 混合部署与独立部署，说明独立部署的资源隔离、权限边界与跨网段访问能力，并给出 TiGateway、环境准备、部署步骤和常用运维命令，同时补充 TiCDC 的核心同步能力。

## Knowledge Outline

- 导读 — TiCDC, TiDB, 数据同步, 部署模式
- 混合部署 — TiCDC, 混合部署, 运维, 架构设计
- 独立部署 — TiCDC, 独立部署, 资源隔离, 权限管理
- 选型建议 — TiCDC, 选型, 运维, 架构设计
- 部署配置 — TiGateway, 配置, 跨网段访问, 高可用
- 核心能力 — TiCDC, 容灾, Kafka, MySQL, S3, Open API
- 环境准备 — TiCDC, 环境准备, 容量规划, 运维
- 快速部署 — TiCDC, 部署步骤, TiUP, changefeed
- TiGateway — TiGateway, 安全, 高可用, 访问控制
- 结语 — TiCDC, 总结, 部署选型

## Repository Paths

- PDF: `collector/b0f0afe2c0476d3392780695022cc50a.pdf`
- Extracted: `generated/extracted/b0f0afe2c0476d3392780695022cc50a/full.md`
- Filtered: `generated/filtered/b0f0afe2c0476d3392780695022cc50a/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
