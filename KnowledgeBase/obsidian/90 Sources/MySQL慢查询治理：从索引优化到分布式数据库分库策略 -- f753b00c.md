---
doc_id: "f753b00c2c9516dd73315fb80c9c3371"
title: "MySQL慢查询治理：从索引优化到分布式数据库分库策略"
aliases:
  - "MySQL慢查询治理：从索引优化到分布式数据库分库策略"
url: "https://www.yunweipai.com/47345.html"
source_domain: "www.yunweipai.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "慢查询"
  - "索引优化"
  - "SQL优化"
  - "读写分离"
  - "主从复制"
  - "分库分表"
  - "ShardingSphere"
  - "Mycat"
  - "Prometheus"
  - "Grafana"
  - "性能调优"
  - "DBA"
generated: true
---

# MySQL慢查询治理：从索引优化到分布式数据库分库策略

> [!info] Provenance
> - doc_id: `f753b00c2c9516dd73315fb80c9c3371`
> - source_kind: `llm_filtered`
> - source: [original URL](https://www.yunweipai.com/47345.html)
> - PDF: [open local PDF](../../collector/f753b00c2c9516dd73315fb80c9c3371.pdf)

## Summary

本文整理 MySQL 慢查询治理路径，涵盖慢查询日志、Performance Schema、EXPLAIN、索引优化、JOIN 与分页优化、读写分离、主从延迟、分库分表、监控告警，以及电商订单系统优化案例。

## Knowledge Outline

- 慢查询事故场景 — MySQL, 慢查询, 事故案例, 性能调优
- 慢查询日志配置 — MySQL, 慢查询日志, mysqldumpslow
- Performance Schema监控 — MySQL, Performance Schema, 监控, SQL
- EXPLAIN执行计划 — MySQL, EXPLAIN, 执行计划, DBA
- 联合索引最左前缀 — MySQL, 联合索引, 最左前缀, SQL优化
- 覆盖索引优化 — MySQL, 覆盖索引, 回表, 性能调优
- JOIN优化 — MySQL, JOIN, 子查询, SQL优化
- 索引失效陷阱 — MySQL, 索引失效, SQL优化, 数据类型
- 分页与COUNT优化 — MySQL, 分页优化, COUNT优化, SQL优化
- 批量操作优化 — MySQL, 批量插入, 批量更新, SQL优化
- 主从复制配置 — MySQL, 主从复制, 读写分离, 配置
- 应用层读写分离 — MySQL, 读写分离, Python, 架构设计
- 主从延迟处理 — MySQL, 主从延迟, 并行复制, 半同步复制
- 垂直分库 — 分库分表, 垂直分库, 架构设计
- 水平分表 — 分库分表, 水平分表, 哈希分片, 路由策略
- ShardingSphere配置 — ShardingSphere, 分库分表, 配置, Snowflake
- Mycat配置 — Mycat, 分库分表, 配置
- 跨库事务与聚合 — 分布式事务, Seata, 跨库查询, 数据聚合
- MySQL监控指标 — MySQL, 监控, QPS, InnoDB
- Prometheus监控与告警 — Prometheus, Grafana, mysqld_exporter, 告警
- 订单系统案例诊断 — MySQL, 电商案例, 慢查询, EXPLAIN
- 订单系统优化实施 — MySQL, 索引优化, 查询重写, 案例
- 订单系统分表与效果 — 分库分表, 案例, 性能指标, 路由策略
- 优化检查清单 — MySQL, 优化清单, 索引优化, 查询优化, 架构优化
- 常见误区 — MySQL, 性能调优, 分库分表, 反模式

## Repository Paths

- PDF: `collector/f753b00c2c9516dd73315fb80c9c3371.pdf`
- Extracted: `generated/extracted/f753b00c2c9516dd73315fb80c9c3371/full.md`
- Filtered: `generated/filtered/f753b00c2c9516dd73315fb80c9c3371/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
