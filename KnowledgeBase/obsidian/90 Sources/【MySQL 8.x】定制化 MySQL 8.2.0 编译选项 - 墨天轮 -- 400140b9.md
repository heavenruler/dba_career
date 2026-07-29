---
doc_id: "400140b9fdd43e06dc075915fd2384d1"
title: "【MySQL 8.x】定制化 MySQL 8.2.0 编译选项 - 墨天轮"
aliases:
  - "【MySQL 8.x】定制化 MySQL 8.2.0 编译选项 - 墨天轮"
url: "https://www.modb.pro/db/1722794246820945920?utm_source=index_ai"
source_domain: "www.modb.pro"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "数据库"
  - "DBA"
  - "编译选项"
  - "存储引擎"
  - "MySQL 8.2"
  - "MySQL X"
  - "MySQL Router"
generated: true
---

# 【MySQL 8.x】定制化 MySQL 8.2.0 编译选项 - 墨天轮

> [!info] Provenance
> - doc_id: `400140b9fdd43e06dc075915fd2384d1`
> - source_kind: `llm_filtered`
> - source: [original URL](https://www.modb.pro/db/1722794246820945920?utm_source=index_ai)
> - PDF: [open local PDF](../../collector/400140b9fdd43e06dc075915fd2384d1.pdf)

## Summary

本文介绍 MySQL 8.2.0 编译时可定制的存储引擎、MySQL X 插件、MySQL Router、跳过测试用例与定制版本后缀等选项，并展示编译配置、缓存确认、安装后引擎与插件检查结果。

## Knowledge Outline

- 前情提要 — MySQL, 编译, Debug
- 默认存储引擎 — MySQL, 存储引擎
- ARCHIVE 引擎 — MySQL, ARCHIVE, 存储引擎, 编译选项
- BLACKHOLE 引擎 — MySQL, BLACKHOLE, binlog, 复制, 编译选项
- FEDERATED 引擎 — MySQL, FEDERATED, DB Link, 编译选项
- NDBCLUSTER 引擎 — MySQL, NDBCLUSTER, shared-nothing, InnoDB Cluster, 编译选项
- CSV 引擎 — MySQL, CSV, 存储引擎
- HEAP MEMORY 引擎 — MySQL, MEMORY, HEAP, 复制, 存储引擎
- 绑定预装引擎 — MySQL, InnoDB, MyISAM, PERFSCHEMA
- MYSQL X 插件 — MySQL, X plugin, mysqlsh, 插件
- 卸载 MYSQL X 插件 — MySQL, X plugin, WITH_MYSQLX
- MySQL Router — MySQL Router, InnoDB Cluster, ProxySQL, HAProxy, 编译选项
- 跳过测试用例 — MySQL, 编译, 测试用例, CMakeCache
- 预编译选项 — MySQL, CMake, 编译选项
- 缓存确认 — MySQL, CMakeCache, 存储引擎
- 编译结果 — MySQL, 编译耗时
- 安装目录 — MySQL, 安装目录
- 运行数据库 — MySQL, mysqld, 启动日志
- 查看引擎 — MySQL, show engines, 存储引擎
- 查看插件 — MySQL, show plugins, 插件
- 定制版本号 — MySQL, 版本号, MYSQL_SERVER_SUFFIX
- 版本后缀效果 — MySQL, version, MYSQL_SERVER_SUFFIX
- 总结 — MySQL, 编译选项, 存储引擎, MySQL X, Router

## Repository Paths

- PDF: `collector/400140b9fdd43e06dc075915fd2384d1.pdf`
- Extracted: `generated/extracted/400140b9fdd43e06dc075915fd2384d1/full.md`
- Filtered: `generated/filtered/400140b9fdd43e06dc075915fd2384d1/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
