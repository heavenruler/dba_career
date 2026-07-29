---
doc_id: "fad7c38e3934be3d1ec05e72c73c16b7"
title: "Redis 内存突增时，如何定量分析其内存使用情况 - 墨天轮"
aliases:
  - "Redis 内存突增时，如何定量分析其内存使用情况 - 墨天轮"
url: "https://www.modb.pro/db/1838027438363865088"
source_domain: "www.modb.pro"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "Redis"
  - "DBA"
  - "内存分析"
  - "性能调优"
  - "源码分析"
  - "故障排查"
  - "数据驱逐"
  - "可观测性"
generated: true
---

# Redis 内存突增时，如何定量分析其内存使用情况 - 墨天轮

> [!info] Provenance
> - doc_id: `fad7c38e3934be3d1ec05e72c73c16b7`
> - source_kind: `llm_filtered`
> - source: [original URL](https://www.modb.pro/db/1838027438363865088)
> - PDF: [open local PDF](../../collector/fad7c38e3934be3d1ec05e72c73c16b7.pdf)

## Summary

文章围绕 Redis used_memory 突增导致数据驱逐的案例，基于 Redis 源码解释 used_memory 的来源、更新机制、used_memory_overhead 的组成、Redis 7 内存统计变化、数据驱逐触发条件，并给出内存分析脚本输出示例。

## Knowledge Outline

- 背景案例 — Redis, 内存突增, 故障排查
- used_memory 来源 — Redis, INFO, used_memory, 源码分析
- used_memory 定义与更新 — Redis, 内存分配, 原子操作, jemalloc
- Redis 内存分配释放函数 — Redis, zmalloc, 内存管理
- used_memory 组成 — Redis, used_memory_dataset, used_memory_overhead
- used_memory_overhead 源码 — Redis, 源码分析, used_memory_overhead
- overhead 组成与重点项 — Redis, AOF, 复制积压缓冲区, 客户端缓冲区, MEMORY STATS
- Redis 7 内存统计变化 — Redis 7, Multi-Part AOF, 内存统计
- Redis 7 前复制缓冲区统计 — Redis, 复制缓冲区, OOM, 从节点
- Redis 7 全局复制缓冲区 — Redis 7, 全局复制缓冲区, replBufBlock
- Redis 7 复制缓冲区计算 — Redis 7, repl-backlog-size, Rax, 内存计算
- 数据驱逐触发条件 — Redis, 数据驱逐, maxmemory, mem_not_counted_for_evict
- mem_not_counted_for_evict 计算 — Redis, 源码分析, 驱逐判断, AOF, 复制缓存区
- 内存分析脚本用途 — Redis, 内存分析, 工具
- 内存分析脚本输出示例 — Redis, 内存分析脚本, 指标
- 脚本输出说明 — Redis, 指标解释, mem_counted_for_evict
- 客户端内存查看 — Redis, 客户端内存, 输入缓冲区, 输出缓冲区

## Repository Paths

- PDF: `collector/fad7c38e3934be3d1ec05e72c73c16b7.pdf`
- Extracted: `generated/extracted/fad7c38e3934be3d1ec05e72c73c16b7/full.md`
- Filtered: `generated/filtered/fad7c38e3934be3d1ec05e72c73c16b7/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
