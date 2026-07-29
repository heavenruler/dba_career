---
doc_id: "c5f0e561e700c1ccba0c1fa2ba7ab330"
title: "这些年背过的面试题——MySQL篇"
aliases:
  - "这些年背过的面试题——MySQL篇"
url: "https://mp.weixin.qq.com/s/L26rI11OV8hrfJVy5Yu78g"
source_domain: "mp.weixin.qq.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "DBA"
  - "数据库"
  - "NoSQL"
  - "事务"
  - "MVCC"
  - "索引优化"
  - "SQL调优"
  - "主从复制"
  - "分库分表"
  - "线上故障"
  - "面试"
generated: true
---

# 这些年背过的面试题——MySQL篇

> [!info] Provenance
> - doc_id: `c5f0e561e700c1ccba0c1fa2ba7ab330`
> - source_kind: `llm_filtered`
> - source: [original URL](https://mp.weixin.qq.com/s/L26rI11OV8hrfJVy5Yu78g)
> - PDF: [open local PDF](../../collector/c5f0e561e700c1ccba0c1fa2ba7ab330.pdf)

## Summary

本文整理 MySQL 与相关数据库/存储系统面试知识，涵盖 NoSQL、OSS/FastDFS、事务隔离、锁、MVCC、索引、SQL 执行与优化、主从复制、分库分表、线上故障与 SQL/ORM 调优案例。

## Knowledge Outline

- NoSQL 数据库类型 — NoSQL, 数据库
- Aerospike 场景 — NoSQL, Aerospike, 推荐系统
- ETL 与推荐链路 — ETL, 数据仓库, 推荐系统
- Neo4j 图数据库 — Neo4j, 图数据库, 知识图谱
- Neo4j 优势 — Neo4j, 图数据库
- MongoDB 与 BSON — MongoDB, BSON, NoSQL
- MongoDB 优缺点 — MongoDB, NoSQL
- MySQL 8.0 特性 — MySQL, MySQL 8.0, 索引优化
- OSS CDN 加速 — OSS, CDN, 云存储
- FastDFS 特性 — FastDFS, 分布式文件系统, 高可用
- FastDFS 组成 — FastDFS, 架构
- 事务 ACID — MySQL, 事务, ACID, InnoDB
- 事务隔离级别 — MySQL, 事务隔离
- 默认隔离级别 RR — MySQL, 可重复读, MVCC, 幻读
- 锁分类 — MySQL, InnoDB, 锁
- 表锁与行锁 — MySQL, 锁, InnoDB
- 意向锁 — MySQL, 意向锁, InnoDB
- MVCC — MySQL, MVCC, InnoDB
- 版本链 — MySQL, MVCC, Undo Log, InnoDB
- InnoDB 与 MyISAM — MySQL, InnoDB, MyISAM
- 哈希索引 — MySQL, 索引, 哈希索引
- B+ 树索引 — MySQL, B+树, 索引
- 聚簇与非聚簇索引 — MySQL, 聚簇索引, 索引
- 最左前缀 — MySQL, 联合索引, 索引优化
- SQL 执行过程 — MySQL, SQL, 查询优化
- 回表与覆盖索引 — MySQL, 回表, 覆盖索引
- 索引优化 — MySQL, 索引优化, Explain
- SQL 语句优化 — MySQL, SQL调优, 分页
- 表结构优化 — MySQL, 表结构优化, 数据库范式
- JOIN 查询 — SQL, JOIN
- 主从复制 — MySQL, 主从复制, Binlog
- 复制一致性 — MySQL, 数据一致性, 主从复制
- 集群架构 — MySQL, 高可用, 故障转移
- 故障转移 — MySQL, 故障转移, 高可用
- 分库分表方案 — MySQL, 分库分表, Sharding-JDBC, Mycat
- 水平与垂直拆分 — MySQL, 分库分表, 架构设计
- 分库核心问题 — MySQL, 分库分表, ElasticSearch, 分布式事务
- 双写迁移 — MySQL, 数据迁移, 双写
- 扩容评估 — MySQL, 容量规划, 分库分表
- 动态扩容步骤 — MySQL, 扩容, DBA
- 主键生成 — 分布式ID, Snowflake, MySQL
- 主从延迟故障 — MySQL, 主从延迟, 事故覆盘
- 主从延迟解决 — MySQL, 主从延迟, 读写分离
- 深分页故障 — MySQL, 分库分表, 深分页, Sharding-JDBC
- 深分页方案 — MySQL, 深分页, SQL调优
- 动态 SQL 查询异常 — SQL调优, MyBatis, 内存溢出
- Controller 大结果集 — 性能优化, Controller, DTO, 内存
- ORM 批量操作 — MyBatis, ORM, 批量操作, 内存优化

## Repository Paths

- PDF: `collector/c5f0e561e700c1ccba0c1fa2ba7ab330.pdf`
- Extracted: `generated/extracted/c5f0e561e700c1ccba0c1fa2ba7ab330/full.md`
- Filtered: `generated/filtered/c5f0e561e700c1ccba0c1fa2ba7ab330/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
