---
doc_id: "4c72c06d793ff8b0156e5dde9d646324"
title: "使用 TiUP 部署 TiDB 集群 | TiDB 文档中心"
aliases:
  - "使用 TiUP 部署 TiDB 集群 | TiDB 文档中心"
url: "https://docs.pingcap.com/zh/tidb/stable/production-deployment-using-tiup"
source_domain: "docs.pingcap.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "TiDB"
  - "TiUP"
  - "数据库部署"
  - "集群运维"
  - "离线部署"
  - "拓扑配置"
  - "安全启动"
generated: true
---

# 使用 TiUP 部署 TiDB 集群 | TiDB 文档中心

> [!info] Provenance
> - doc_id: `4c72c06d793ff8b0156e5dde9d646324`
> - source_kind: `llm_filtered`
> - source: [original URL](https://docs.pingcap.com/zh/tidb/stable/production-deployment-using-tiup)
> - PDF: [open local PDF](../../collector/4c72c06d793ff8b0156e5dde9d646324.pdf)

## Summary

本文说明如何在生产环境中使用 TiUP 部署 TiDB 集群，覆盖在线与离线安装 TiUP、初始化拓扑文件、执行部署、查看与验证集群状态，以及安全启动与普通启动方式。

## Knowledge Outline

- 概述 — TiDB, TiUP, 集群运维
- 步骤 1：前置检查 — TiDB, 前置检查, 安全
- 步骤 2：在线部署 TiUP — TiUP, 在线部署, 命令
- 步骤 2：离线部署 TiUP — TiUP, 离线部署, 镜像管理, 命令
- 步骤 3：初始化拓扑文件 — TiUP, topology.yaml, 拓扑配置
- 常用部署场景 — TiDB, TiFlash, TiCDC, TiSpark, 拓扑, 配置模板
- 步骤 4：执行部署 — TiDB, 部署命令, 风险检查, 权限
- 步骤 5：查看集群列表 — TiUP, 集群管理, 列表
- 步骤 6：检查集群状态 — TiDB, 状态检查, display
- 步骤 7：启动集群 — TiDB, 启动, 安全启动, root密码
- 步骤 8：验证运行状态 — TiDB, 验证, 运行状态

## Repository Paths

- PDF: `collector/4c72c06d793ff8b0156e5dde9d646324.pdf`
- Extracted: `generated/extracted/4c72c06d793ff8b0156e5dde9d646324/full.md`
- Filtered: `generated/filtered/4c72c06d793ff8b0156e5dde9d646324/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
