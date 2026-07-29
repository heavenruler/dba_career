---
doc_id: "dd80518a03cc67779a0c876376ccb05b"
title: "轻松上手：使用 Docker Compose 部署 TiDB 的简易指南 - 墨天轮"
aliases:
  - "轻松上手：使用 Docker Compose 部署 TiDB 的简易指南 - 墨天轮"
url: "https://www.modb.pro/db/1916401881191034880?utm_source=index_ori"
source_domain: "www.modb.pro"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "TiDB"
  - "Docker Compose"
  - "数据库部署"
  - "DBA"
  - "分区表"
  - "索引优化"
  - "执行计划"
  - "CentOS 7"
generated: true
---

# 轻松上手：使用 Docker Compose 部署 TiDB 的简易指南 - 墨天轮

> [!info] Provenance
> - doc_id: `dd80518a03cc67779a0c876376ccb05b`
> - source_kind: `llm_filtered`
> - source: [original URL](https://www.modb.pro/db/1916401881191034880?utm_source=index_ori)
> - PDF: [open local PDF](../../collector/dd80518a03cc67779a0c876376ccb05b.pdf)

## Summary

本文介绍在 CentOS 7 上使用 Docker Compose 部署 TiDB 7.5 集群，并演示 TiDB 基础数据库操作、分区表创建、索引优化与 EXPLAIN 执行计划分析。

## Knowledge Outline

- 引言与目标 — TiDB, 分布式数据库, Docker Compose
- 系统环境准备 — CentOS 7, TiDB, Docker
- 系统资源检查 — CentOS 7, 系统环境
- Docker 环境检查 — Docker, Docker Compose
- 拉取 TiDB 镜像 — TiDB, Docker, 镜像
- Docker Compose 配置 — Docker Compose, TiDB, PD, TiKV
- 启动 TiDB 集群 — Docker Compose, TiDB, 集群部署
- 连接 TiDB 实例 — TiDB, MySQL 客户端
- 查看数据库版本 — TiDB, 版本检查
- 创建数据库 — SQL, TiDB
- 创建员工表 — SQL, 表设计
- 插入员工数据 — SQL, 数据插入
- 查询员工数据 — SQL, 查询
- 创建分区表 — TiDB, 分区表, SQL
- 插入销售数据 — SQL, 分区表, 数据插入
- 查询 2020 年数据 — SQL, 范围查询, 分区表
- 查询 2021 年数据 — SQL, 范围查询, 分区表
- 普通表索引优化 — 索引优化, TiDB, SQL
- 普通表执行计划 — EXPLAIN, 执行计划, 索引优化
- 分区表索引优化 — 分区表, 索引优化, SQL
- 分区裁剪执行计划 — TiDB, 分区裁剪, EXPLAIN, 执行计划
- 分区与优化注意事项 — 分区表, 性能优化, TiDB
- 关键点总结 — TiDB, Docker Compose, 性能优化

## Repository Paths

- PDF: `collector/dd80518a03cc67779a0c876376ccb05b.pdf`
- Extracted: `generated/extracted/dd80518a03cc67779a0c876376ccb05b/full.md`
- Filtered: `generated/filtered/dd80518a03cc67779a0c876376ccb05b/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
