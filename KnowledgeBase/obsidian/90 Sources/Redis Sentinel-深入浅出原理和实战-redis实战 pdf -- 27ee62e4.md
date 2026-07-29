---
doc_id: "27ee62e48490adce210c13eb3c0a9c63"
title: "Redis Sentinel-深入浅出原理和实战-redis实战 pdf"
aliases:
  - "Redis Sentinel-深入浅出原理和实战-redis实战 pdf"
url: "https://www.51cto.com/article/634230.html"
source_domain: "www.51cto.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "Redis"
  - "Sentinel"
  - "高可用"
  - "主从复制"
  - "故障转移"
  - "Docker"
  - "docker-compose"
  - "数据库"
  - "SRE"
  - "DevOps"
generated: true
---

# Redis Sentinel-深入浅出原理和实战-redis实战 pdf

> [!info] Provenance
> - doc_id: `27ee62e48490adce210c13eb3c0a9c63`
> - source_kind: `llm_filtered`
> - source: [original URL](https://www.51cto.com/article/634230.html)
> - PDF: [open local PDF](../../collector/27ee62e48490adce210c13eb3c0a9c63.pdf)

## Summary

本文介绍 Redis Sentinel 的高可用定位、Sentinel 自身高可用要求、quorum 与 majority、主观宕机与客观宕机，以及基于 Docker Compose 搭建 Redis 主从与 Sentinel 集群并模拟故障转移的实战流程。

## Knowledge Outline

- Sentinel 引入背景 — Redis, Sentinel, 主从复制, 高可用
- Sentinel 功能概览 — Redis, Sentinel, 故障转移, 高可用
- Sentinel 自身高可用 — Sentinel, 高可用, 分布式
- 至少三个 Sentinel 节点 — Sentinel, 高可用, 故障转移
- quorum 与 majority — Sentinel, quorum, majority, 故障转移
- 主观宕机与客观宕机 — Sentinel, sdown, odown, 故障检测
- 客观宕机后的故障转移 — Sentinel, odown, 故障转移, Redis
- 实战前置要求 — Docker, docker-compose, Redis, Sentinel
- 目录结构 — Docker, docker-compose, Redis, Sentinel
- Redis 主从 compose — Redis, docker-compose, 主从复制
- slaveof 说明 — Redis, slaveof, 主从复制
- 启动 Redis 并获取 master IP — Docker, Redis, 容器网络
- Sentinel compose — Sentinel, docker-compose, Redis
- redis-sentinel 命令说明 — Redis, Sentinel, redis-sentinel
- Sentinel 配置文件 — Sentinel, Redis, quorum, 配置
- Sentinel monitor 配置说明 — Sentinel, quorum, docker-compose
- 模拟 master 挂掉 — Sentinel, 故障转移, Docker
- 故障转移日志 — Sentinel, sdown, switch-master, 日志
- 故障转移结果 — Redis, Sentinel, 故障转移, Replication
- 原 master 重新启动 — Redis, Sentinel, 故障恢复, Docker
- 原 master 恢复后的复制状态 — Redis, Sentinel, Replication, 故障恢复
- 新 master 的复制状态 — Redis, Sentinel, Replication, 故障恢复

## Repository Paths

- PDF: `collector/27ee62e48490adce210c13eb3c0a9c63.pdf`
- Extracted: `generated/extracted/27ee62e48490adce210c13eb3c0a9c63/full.md`
- Filtered: `generated/filtered/27ee62e48490adce210c13eb3c0a9c63/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
