---
doc_id: "09e74f0a28f3954c6ffca5acac1d6de0"
title: "[MYSQL] 忘记root密码时, 不需要重启也能强制修改了! - 墨天轮"
aliases:
  - "[MYSQL] 忘记root密码时, 不需要重启也能强制修改了! - 墨天轮"
url: "https://www.modb.pro/db/1887314304005844992"
source_domain: "www.modb.pro"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "DBA"
  - "Linux"
  - "/proc"
  - "内存修改"
  - "密码恢复"
  - "mysql_native_password"
  - "Python"
generated: true
---

# [MYSQL] 忘记root密码时, 不需要重启也能强制修改了! - 墨天轮

> [!info] Provenance
> - doc_id: `09e74f0a28f3954c6ffca5acac1d6de0`
> - source_kind: `llm_filtered`
> - source: [original URL](https://www.modb.pro/db/1887314304005844992)
> - PDF: [open local PDF](../../collector/09e74f0a28f3954c6ffca5acac1d6de0.pdf)

## Summary

本文说明通过 /proc/PID/maps 与 /proc/PID/mem 访问 mysqld 进程内存，查找并修改 mysql_native_password 的二进制密码值，以实现不重启 MySQL 强制修改账号密码；同时给出脚本使用方式、限制和源码片段。

## Knowledge Outline

- 问题背景 — MySQL, 密码恢复, 内存修改
- 内存修改原理 — Linux, /proc, mysqld, 内存
- proc maps 与 mem — Linux, /proc, maps, mem, 内存映射
- 遍历内存查找数据 — Python, /proc/mem, 内存扫描
- MySQL 密码位置 — MySQL, mysql.user, flush privileges, 认证, 二进制密码
- 查看用户密码 — MySQL, 密码查看, Python
- 修改密码方法一 — MySQL, 密码修改, flush privileges
- 修改密码方法二 — MySQL, 密码修改, old-password
- 多个 mysqld 进程 — MySQL, mysqld, PID
- 限制与适用版本 — MySQL, mysql_native_password, 版本限制, 风险
- 核心源码：参数与密码编码 — Python, argparse, mysql_native_password, SHA1
- 核心源码：查找与写入内存 — Python, /proc/mem, 内存写入, 密码修改
- 核心源码：获取 mysqld PID — Python, /proc, mysqld, PID

## Repository Paths

- PDF: `collector/09e74f0a28f3954c6ffca5acac1d6de0.pdf`
- Extracted: `generated/extracted/09e74f0a28f3954c6ffca5acac1d6de0/full.md`
- Filtered: `generated/filtered/09e74f0a28f3954c6ffca5acac1d6de0/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
