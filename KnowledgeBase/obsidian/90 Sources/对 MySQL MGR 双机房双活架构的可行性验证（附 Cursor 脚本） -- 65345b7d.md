---
doc_id: "65345b7d3cd1b42a7c2fc5184097e77b"
title: "对 MySQL MGR 双机房双活架构的可行性验证（附 Cursor 脚本）"
aliases:
  - "对 MySQL MGR 双机房双活架构的可行性验证（附 Cursor 脚本）"
url: "https://mp.weixin.qq.com/s/TU82SfCWYBJoFQ6c7JiHBQ"
source_domain: "mp.weixin.qq.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "MGR"
  - "双机房双活"
  - "高可用"
  - "容灾"
  - "数据库架构"
  - "DBA"
  - "自动化测试"
  - "故障转移"
  - "Cursor"
generated: true
---

# 对 MySQL MGR 双机房双活架构的可行性验证（附 Cursor 脚本）

> [!info] Provenance
> - doc_id: `65345b7d3cd1b42a7c2fc5184097e77b`
> - source_kind: `llm_filtered`
> - source: [original URL](https://mp.weixin.qq.com/s/TU82SfCWYBJoFQ6c7JiHBQ)
> - PDF: [open local PDF](../../collector/65345b7d3cd1b42a7c2fc5184097e77b.pdf)

## Summary

文章验证 MySQL MGR 在双机房双活场景下的可行性，涵盖设计目标、测试功能、自动化部署与故障模拟、复制链路校验、测试结论与脚本使用方式。核心结论包括单主模式不建议双向复制、双向复制需启用 skip_replica_start，以及 MySQL Shell 暂不支持双向复制。

## Knowledge Outline

- 背景 — MySQL, MGR, 双机房双活, 高可用, 容灾
- 设计目标 — 架构验证, 自动化测试, 故障模拟, 数据一致性
- 主要功能 — dbdeployer, 复制链路, 故障恢复, 数据一致性, 监控
- 测试结论 — MySQL Shell, ClusterSet, MySQL Router, skip_replica_start, GTID, 双向复制
- 使用方法示例 — 命令, 部署, 测试脚本
- 脚本说明 — Cursor, 脚本验证
- 核心配置 — MySQL, MGR, 端口, 复制通道, 配置
- 异步复制配置片段 — CHANGE REPLICATION SOURCE TO, START REPLICA, 异步复制, MySQL
- 测试表结构 — 测试数据, 数据一致性, DDL
- 数据同步验证 SQL — 数据同步, 校验, SQL
- 故障恢复流程片段 — 故障恢复, START GROUP_REPLICATION, START REPLICA, 自动化测试

## Repository Paths

- PDF: `collector/65345b7d3cd1b42a7c2fc5184097e77b.pdf`
- Extracted: `generated/extracted/65345b7d3cd1b42a7c2fc5184097e77b/full.md`
- Filtered: `generated/filtered/65345b7d3cd1b42a7c2fc5184097e77b/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
