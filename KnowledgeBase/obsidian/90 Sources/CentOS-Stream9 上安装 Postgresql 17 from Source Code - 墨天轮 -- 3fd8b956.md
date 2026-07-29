---
doc_id: "3fd8b956d4a659320637c2cfc220963b"
title: "CentOS-Stream9 上安装 Postgresql 17 from Source Code - 墨天轮"
aliases:
  - "CentOS-Stream9 上安装 Postgresql 17 from Source Code - 墨天轮"
url: "https://www.modb.pro/db/1843469275967881216"
source_domain: "www.modb.pro"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "PostgreSQL"
  - "CentOS Stream 9"
  - "源码编译"
  - "DBA"
  - "数据库安装"
  - "systemd"
  - "pg_hba.conf"
  - "pg_ident.conf"
generated: true
---

# CentOS-Stream9 上安装 Postgresql 17 from Source Code - 墨天轮

> [!info] Provenance
> - doc_id: `3fd8b956d4a659320637c2cfc220963b`
> - source_kind: `llm_filtered`
> - source: [original URL](https://www.modb.pro/db/1843469275967881216)
> - PDF: [open local PDF](../../collector/3fd8b956d4a659320637c2cfc220963b.pdf)

## Summary

本文记录在 CentOS Stream 9 上从源码编译安装 PostgreSQL 17 的流程，包含源码下载、依赖安装、Bison/Flex 简介、编译参数、用户和目录创建、环境变量、initdb 初始化、systemd 服务配置，以及本地和远程连接相关的 pg_hba.conf、pg_ident.conf、postgresql.conf 配置。

## Knowledge Outline

- 下载源码 — PostgreSQL, 源码下载
- 安装依赖 — 依赖安装, CentOS, PostgreSQL
- Bison 简介 — Bison, 语法分析器, 编译器, PostgreSQL
- Flex 简介 — Flex, 词法分析器, 编译器, PostgreSQL
- 编译 PostgreSQL 源码 — PostgreSQL, 源码编译, systemd, contrib
- 创建用户与目录 — PostgreSQL, Linux 用户, 目录权限
- 配置环境变量 — PostgreSQL, 环境变量, Linux
- 初始化数据库 — PostgreSQL, initdb, pg_hba.conf
- 启动实例与创建数据库 — PostgreSQL, pg_ctl, createdb, psql
- 配置 systemd 服务 — PostgreSQL, systemd, 服务配置
- 本地连接数据库 — PostgreSQL, psql, 本地连接
- pg_hba.conf 远程访问 — PostgreSQL, pg_hba.conf, 远程访问, 认证
- pg_ident.conf 映射 — PostgreSQL, pg_ident.conf, ident, 用户映射
- ident 配置示例 — PostgreSQL, pg_hba.conf, ident, pg_ctl
- postgresql.conf 监听配置 — PostgreSQL, postgresql.conf, listen_addresses, 远程连接

## Repository Paths

- PDF: `collector/3fd8b956d4a659320637c2cfc220963b.pdf`
- Extracted: `generated/extracted/3fd8b956d4a659320637c2cfc220963b/full.md`
- Filtered: `generated/filtered/3fd8b956d4a659320637c2cfc220963b/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
