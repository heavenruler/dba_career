---
doc_id: "4504759312deaf01f04cd5a2d02c4b99"
title: "使用 MySQL Clone 插件为MGR集群添加节点"
aliases:
  - "使用 MySQL Clone 插件为MGR集群添加节点"
url: "https://www.modb.pro/db/1948016960059486208"
source_domain: "www.modb.pro"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "MGR"
  - "Group Replication"
  - "Clone插件"
  - "数据库运维"
  - "高可用"
  - "监控"
generated: true
---

# 使用 MySQL Clone 插件为MGR集群添加节点

> [!info] Provenance
> - doc_id: `4504759312deaf01f04cd5a2d02c4b99`
> - source_kind: `llm_filtered`
> - source: [original URL](https://www.modb.pro/db/1948016960059486208)
> - PDF: [open local PDF](../../collector/4504759312deaf01f04cd5a2d02c4b99.pdf)

## Summary

本文说明如何在 MySQL Group Replication 集群中使用 Clone 插件快速新增节点，覆盖前置条件、克隆账号授权、新节点 my.cnf 配置、初始化数据目录、执行克隆、加入集群与状态监控。

## Knowledge Outline

- 前提与授权 — MySQL, MGR, Clone插件, 权限配置, 前置检查
- 新节点配置 — MySQL, MGR, 配置文件, InnoDB, 复制参数
- 初始化与启动 — MySQL, 初始化, 启动, root密码, 数据目录
- 执行克隆 — MySQL, Clone插件, 克隆, 数据迁移, 监控
- 加入 MGR — MySQL, MGR, Group Replication, 白名单, 复制状态, 性能监控

## Repository Paths

- PDF: `collector/4504759312deaf01f04cd5a2d02c4b99.pdf`
- Extracted: `generated/extracted/4504759312deaf01f04cd5a2d02c4b99/full.md`
- Filtered: `generated/filtered/4504759312deaf01f04cd5a2d02c4b99/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
