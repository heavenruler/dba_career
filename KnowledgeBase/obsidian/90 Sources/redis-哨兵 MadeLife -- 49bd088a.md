---
doc_id: "49bd088a990a7dda68e668d5c27c4c34"
title: "redis-哨兵 | MadeLife"
aliases:
  - "redis-哨兵 | MadeLife"
url: "https://suntw2015.github.io/2019/11/18/redis-sentinel/"
source_domain: "suntw2015.github.io"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "Redis"
  - "Sentinel"
  - "高可用"
  - "故障修復"
  - "Raft"
  - "源码分析"
  - "数据库"
  - "SRE"
generated: true
---

# redis-哨兵 | MadeLife

> [!info] Provenance
> - doc_id: `49bd088a990a7dda68e668d5c27c4c34`
> - source_kind: `llm_filtered`
> - source: [original URL](https://suntw2015.github.io/2019/11/18/redis-sentinel/)
> - PDF: [open local PDF](../../collector/49bd088a990a7dda68e668d5c27c4c34.pdf)

## Summary

本文介紹 Redis Sentinel 的高可用模式、拓撲發現、監控、告警、故障修復與 Leader 選舉流程，並摘錄 Sentinel 配置、核心資料結構與部分源碼流程。

## Knowledge Outline

- 哨兵模式用途 — Redis, Sentinel, 高可用
- 启动方式 — Redis, Sentinel, 配置
- 拓扑发现 — Redis, Sentinel, 拓扑发现
- 监控机制 — Redis, Sentinel, 监控
- 主观与客观下线 — Redis, Sentinel, 故障检测
- 告警频道 — Redis, Sentinel, 告警
- 故障修复流程 — Redis, Sentinel, 故障修复, Raft
- Leader 选举 — Redis, Sentinel, Leader选举, Raft
- 配置示例 — Redis, Sentinel, 配置
- 配置参数说明 — Redis, Sentinel, 配置
- 源码入口 — Redis, Sentinel, 源码分析
- 核心常量与状态 — Redis, Sentinel, 源码分析
- 定时参数 — Redis, Sentinel, 源码分析
- 故障修复状态定义 — Redis, Sentinel, 故障修复, 源码分析
- 连接结构 — Redis, Sentinel, 源码分析, 连接管理
- 节点实例结构 — Redis, Sentinel, 源码分析, 数据结构
- 哨兵状态结构 — Redis, Sentinel, 源码分析, 数据结构
- 哨兵模式命令集 — Redis, Sentinel, 命令, 源码分析
- Sentinel 初始化 — Redis, Sentinel, 初始化, 源码分析
- 运行前检查 — Redis, Sentinel, 配置, 源码分析
- Sentinel 事件处理 — Redis, Sentinel, 事件, 源码分析
- 脚本任务调度 — Redis, Sentinel, 脚本, 源码分析
- 脚本运行 — Redis, Sentinel, 脚本, 源码分析
- 连接管理 — Redis, Sentinel, 连接管理
- 连接创建 — Redis, Sentinel, 连接管理, 源码分析
- 连接共享 — Redis, Sentinel, 连接管理
- 节点实例说明 — Redis, Sentinel, 数据结构, 源码分析
- 当前 Master 地址 — Redis, Sentinel, 故障修复, 源码分析
- 命令重命名映射 — Redis, Sentinel, 安全, 源码分析
- 配置处理逻辑 — Redis, Sentinel, 配置, 源码分析

## Repository Paths

- PDF: `collector/49bd088a990a7dda68e668d5c27c4c34.pdf`
- Extracted: `generated/extracted/49bd088a990a7dda68e668d5c27c4c34/full.md`
- Filtered: `generated/filtered/49bd088a990a7dda68e668d5c27c4c34/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
