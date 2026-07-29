---
doc_id: "b2a72b1f792bbd5c3e6baf7bf5a17911"
title: "美团MySQL数据库巡检系统的设计与应用"
aliases:
  - "美团MySQL数据库巡检系统的设计与应用"
url: "https://tech.meituan.com/2020/06/04/mysql-detection-system.html"
source_domain: "tech.meituan.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "数据库运维"
  - "巡检系统"
  - "SRE"
  - "DevOps"
  - "平台工程"
  - "可观测性"
  - "隐患治理"
  - "自动化运维"
generated: true
---

# 美团MySQL数据库巡检系统的设计与应用

> [!info] Provenance
> - doc_id: `b2a72b1f792bbd5c3e6baf7bf5a17911`
> - source_kind: `llm_filtered`
> - source: [original URL](https://tech.meituan.com/2020/06/04/mysql-detection-system.html)
> - PDF: [open local PDF](../../collector/b2a72b1f792bbd5c3e6baf7bf5a17911.pdf)

## Summary

本文介绍美团MySQL数据库巡检系统的设计目标、架构分层、巡检项分类、治理运营机制和落地成果，重点强调自动化巡检、隐患入库、运营催办与外部平台对接在保障MySQL稳定运行中的作用。

## Knowledge Outline

- 背景 — MySQL, 数据库运维, 巡检系统, 隐患治理, 自动化运维
- 设计原则 — 设计原则, 数据库运维, 隐患治理, 可运营, 自动化运维
- 执行层 — 巡检系统, Crane, 分布式调度, Python, Git, 高可用, 中间件
- 存储层 — 数据建模, 巡检数据库, 幂等, 半结构化数据, Git仓库, DBA, 自动化
- 应用层 — 数据库运维平台, 隐患治理, 运营报表, 催办, 先知平台, SRE, 周报
- 巡检项目 — 巡检项目, DBA, RD, Schema/SQL, 高可用, 备份, 中间件, 报警
- 成果 — 成果, 隐患治理, 运营指标, SRE, RD, 先知平台, 数据指标
- 未来规划 — 未来规划, 自动化, CI, 审计, 运营, 自动修复

## Repository Paths

- PDF: `collector/b2a72b1f792bbd5c3e6baf7bf5a17911.pdf`
- Extracted: `generated/extracted/b2a72b1f792bbd5c3e6baf7bf5a17911/full.md`
- Filtered: `generated/filtered/b2a72b1f792bbd5c3e6baf7bf5a17911/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
