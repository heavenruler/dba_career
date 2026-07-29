---
doc_id: "ae414e4585126b7eff4d087d8839968d"
title: "Linux 8 快速安装 PostgreSQL 17.2 - 墨天轮"
aliases:
  - "Linux 8 快速安装 PostgreSQL 17.2 - 墨天轮"
url: "https://www.modb.pro/db/1869408088034394112"
source_domain: "www.modb.pro"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "PostgreSQL"
  - "PostgreSQL 17"
  - "Linux"
  - "DBA"
  - "数据库安装部署"
  - "源码编译"
  - "systemd"
  - "数据库参数配置"
generated: true
---

# Linux 8 快速安装 PostgreSQL 17.2 - 墨天轮

> [!info] Provenance
> - doc_id: `ae414e4585126b7eff4d087d8839968d`
> - source_kind: `llm_filtered`
> - source: [original URL](https://www.modb.pro/db/1869408088034394112)
> - PDF: [open local PDF](../../collector/ae414e4585126b7eff4d087d8839968d.pdf)

## Summary

本文记录在 Linux 8.7 / Oracle Linux 8.7 上源码编译安装 PostgreSQL 17.2 的流程，包含系统参数、依赖安装、源码下载、configure 编译安装、环境变量、初始化实例、postgresql.conf 参数、启动测试、systemd 开机自启动，以及常见依赖缺失错误处理。

## Knowledge Outline

- 前言 — PostgreSQL, 版本发布
- 操作系统信息 — Linux, Oracle Linux, 系统信息
- 内核参数设置 — Linux, sysctl, PostgreSQL
- 资源限制与系统服务 — Linux, limits.conf, SELinux, firewalld
- 依赖安装与用户创建 — Linux, RPM, 依赖安装, postgres用户
- 下载软件包并解压 — PostgreSQL, 源码包, 安装目录
- 编译安装要求 — PostgreSQL, 源码编译, 依赖
- configure 参数选项 — PostgreSQL, configure, 编译参数
- configure 配置 — PostgreSQL, configure, GCC, Python
- 编译安装命令 — PostgreSQL, gmake, 客户端安装
- 编译错误处理 — PostgreSQL, ICU, configure错误
- bison 与 flex 错误 — PostgreSQL, bison, flex, configure错误
- 环境变量 — PostgreSQL, 环境变量, bashrc
- 初始化 PG 实例 — PostgreSQL, initdb, 数据库初始化
- postgresql.conf 参数 — PostgreSQL, postgresql.conf, 数据库参数, WAL, 日志, autovacuum
- 启动实例与状态检查 — PostgreSQL, pg_ctl, 进程检查
- 登录测试 — PostgreSQL, psql, SQL测试
- 开机自启动 — PostgreSQL, 开机自启动, chkconfig
- systemd 服务配置 — PostgreSQL, systemd, 开机自启动

## Repository Paths

- PDF: `collector/ae414e4585126b7eff4d087d8839968d.pdf`
- Extracted: `generated/extracted/ae414e4585126b7eff4d087d8839968d/full.md`
- Filtered: `generated/filtered/ae414e4585126b7eff4d087d8839968d/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
