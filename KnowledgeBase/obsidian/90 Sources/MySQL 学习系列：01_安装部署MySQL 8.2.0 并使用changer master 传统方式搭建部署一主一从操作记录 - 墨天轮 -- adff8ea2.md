---
doc_id: "adff8ea24b970c9925d7421a9c0d0708"
title: "MySQL 学习系列：01_安装部署MySQL 8.2.0 并使用changer master 传统方式搭建部署一主一从操作记录 - 墨天轮"
aliases:
  - "MySQL 学习系列：01_安装部署MySQL 8.2.0 并使用changer master 传统方式搭建部署一主一从操作记录 - 墨天轮"
url: "https://www.modb.pro/db/1759486743346761728"
source_domain: "www.modb.pro"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "DBA"
  - "主从复制"
  - "数据库部署"
  - "复制故障排查"
  - "运维"
generated: true
---

# MySQL 学习系列：01_安装部署MySQL 8.2.0 并使用changer master 传统方式搭建部署一主一从操作记录 - 墨天轮

> [!info] Provenance
> - doc_id: `adff8ea24b970c9925d7421a9c0d0708`
> - source_kind: `llm_filtered`
> - source: [original URL](https://www.modb.pro/db/1759486743346761728)
> - PDF: [open local PDF](../../collector/adff8ea24b970c9925d7421a9c0d0708.pdf)

## Summary

本文记录 MySQL 8.2.0 二进制包安装部署、传统 position 方式搭建一主一从复制，以及主从配置、验证命令和常见报错处理。

## Knowledge Outline

- 主从复制简介 — MySQL, 主从复制, 高可用, 读写分离
- 复制原理 — MySQL, 主从复制, binary log, 复制线程, 故障恢复
- 环境规划 — MySQL, CentOS, 环境规划
- 安装包部署 — MySQL, 安装部署, Linux
- 卸载mariadb — MySQL, MariaDB, 安装部署
- master配置文件 — MySQL, my.cnf, master, binary log
- slave配置文件 — MySQL, my.cnf, slave, relay log
- 配置参数说明 — MySQL, 配置参数, server-id, log-bin
- 初始化数据库 — MySQL, 初始化, root密码
- 启动与环境变量 — MySQL, 启动, 环境变量
- 重置root口令 — MySQL, root, 权限
- 创建复制账号 — MySQL, 复制账号, replication slave, master status
- 从库设置主库参数 — MySQL, CHANGE MASTER, slave status, 主从复制
- 复制状态字段 — MySQL, 复制线程, 监控
- 复制应用状态查询 — MySQL, performance_schema, 复制监控
- Authentication报错原因与处理 — MySQL, caching_sha2_password, Authentication, get_master_public_key
- ANONYMOUS事务错误 — MySQL, 复制错误, ANONYMOUS, 主从不一致
- 传统方式总结 — MySQL, GTID, position, 主从复制

## Repository Paths

- PDF: `collector/adff8ea24b970c9925d7421a9c0d0708.pdf`
- Extracted: `generated/extracted/adff8ea24b970c9925d7421a9c0d0708/full.md`
- Filtered: `generated/filtered/adff8ea24b970c9925d7421a9c0d0708/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
