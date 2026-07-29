---
doc_id: "9b155c5f6dba05ac24db758bf32a027a"
title: "美团2面：亿级流量，如何保证Redis与MySQL的一致性？操作失败 如何设计 补偿？"
aliases:
  - "美团2面：亿级流量，如何保证Redis与MySQL的一致性？操作失败 如何设计 补偿？"
url: "https://mp.weixin.qq.com/s/_VyHzICG_qZENjjnHGC0UA"
source_domain: "mp.weixin.qq.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "Redis"
  - "MySQL"
  - "缓存一致性"
  - "Cache-Aside"
  - "高并发"
  - "架构设计"
  - "补偿机制"
  - "消息队列"
  - "RocketMQ"
  - "Canal"
  - "Flink"
  - "APISIX"
  - "CAP"
generated: true
---

# 美团2面：亿级流量，如何保证Redis与MySQL的一致性？操作失败 如何设计 补偿？

> [!info] Provenance
> - doc_id: `9b155c5f6dba05ac24db758bf32a027a`
> - source_kind: `llm_filtered`
> - source: [original URL](https://mp.weixin.qq.com/s/_VyHzICG_qZENjjnHGC0UA)
> - PDF: [open local PDF](../../collector/9b155c5f6dba05ac24db758bf32a027a.pdf)

## Summary

本文围绕 Redis 与 MySQL 在高并发场景下的数据一致性，整理了 Read-Through、Write-Through、Write Behind、Cache-Aside 等缓存策略，并重点讨论 Cache-Aside 下先更数据库再删缓存、延迟双删、逻辑过期、异步删除、消息队列补偿、binlog 订阅、三级补偿与灰度上线方案。

## Knowledge Outline

- 缓存一致性基础策略 — Redis, MySQL, Read-Through, 缓存一致性
- Write-Through — Write-Through, 缓存一致性, 数据库
- Write Behind — Write Behind, 异步写入, 缓存一致性
- Cache-Aside — Cache-Aside, 旁路缓存, 分布式系统
- Cache-Aside 读写流程 — Cache-Aside, 读流程, 写流程
- 删除缓存而非更新缓存 — Cache-Aside, 删除缓存, 脏数据
- 先更数据库再删缓存 — Cache-Aside, 并发读写, 最终一致性
- 策略三风险 — 缓存删除失败, 最终一致性, 延迟双删
- 延迟双删步骤 — 延迟双删, 缓存一致性
- 延迟双删代码 — Java, Redis, 延迟双删
- 逻辑删除 — 逻辑删除, 逻辑过期, 缓存击穿
- 异步重建流程 — 异步重建, SETNX, 缓存击穿
- 逻辑删除适用与注意事项 — 逻辑删除, 高并发读, 最终一致性
- 异步删除 — 异步删除, 队列, 缓存一致性
- 内存队列删缓存 — 内存队列, 异步删除, Redis
- 消息队列删缓存 — RocketMQ, 消息队列, 高可靠
- Binlog 加消息队列 — binlog, Canal, RocketMQ, 缓存删除
- 异步删除方案延迟对比 — 方案选型, 异步删除, 最终一致性
- 三级补偿机制 — 补偿机制, 延迟队列, 消息队列, 定时任务
- 阻塞队列异步删除代码 — Java, BlockingQueue, 异步删除
- 延迟队列重试 — 延迟队列, 重试, 网络抖动
- RocketMQ 持久化重试 — RocketMQ, 持久化重试, 指数退避
- RocketMQ 重试间隔 — RocketMQ, 重试间隔
- 定时任务兜底比对 — xxl-job, Redis SCAN, RocketMQ, Flink
- SCAN 优化 — Redis SCAN, 性能优化, 生产环境
- 黄金组合方案 — 三级防御, 最终一致性, 缓存补偿
- 灰度放量 — 灰度发布, 流量染色, 上线可靠性
- 回滚与异常处理 — APISIX, 灰度发布, 回滚
- CAP 视角 — CAP, 分布式系统, 弱一致性, 最终一致性

## Repository Paths

- PDF: `collector/9b155c5f6dba05ac24db758bf32a027a.pdf`
- Extracted: `generated/extracted/9b155c5f6dba05ac24db758bf32a027a/full.md`
- Filtered: `generated/filtered/9b155c5f6dba05ac24db758bf32a027a/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
