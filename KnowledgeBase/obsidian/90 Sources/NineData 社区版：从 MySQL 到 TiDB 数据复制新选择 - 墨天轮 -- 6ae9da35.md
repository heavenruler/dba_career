---
doc_id: "6ae9da3549283979aa62066b97ba2a96"
title: "NineData 社区版：从 MySQL 到 TiDB 数据复制新选择 - 墨天轮"
aliases:
  - "NineData 社区版：从 MySQL 到 TiDB 数据复制新选择 - 墨天轮"
url: "https://www.modb.pro/db/1900115262142164992?utm_source=index_ori"
source_domain: "www.modb.pro"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "NineData"
  - "MySQL"
  - "TiDB"
  - "数据复制"
  - "数据库迁移"
  - "敏感数据管理"
  - "Docker"
  - "Podman"
  - "Kubernetes"
  - "K3S"
  - "数据库对比"
generated: true
---

# NineData 社区版：从 MySQL 到 TiDB 数据复制新选择 - 墨天轮

> [!info] Provenance
> - doc_id: `6ae9da3549283979aa62066b97ba2a96`
> - source_kind: `llm_filtered`
> - source: [original URL](https://www.modb.pro/db/1900115262142164992?utm_source=index_ori)
> - PDF: [open local PDF](../../collector/6ae9da3549283979aa62066b97ba2a96.pdf)

## Summary

本文介绍 NineData 社区版的定位、部署方式、数据源管理、敏感数据管理，以及从 MySQL 到 TiDB 的数据复制示例，包含容器启动命令、K3S 组件状态、敏感数据测试 SQL、MySQL/TiDB 版本信息与复制流程。

## Knowledge Outline

- NineData 社区版定位 — NineData, 数据库 DevOps, 数据复制, 权限管理, SQL 审核
- 数据复制与对比能力 — CDC, 数据迁移, 数据同步, 容灾, 一致性校验, 数据库对比
- 安装前提 — Docker, Podman, 安装, 系统需求
- 镜像地址与拉取 — NineData, 镜像, Podman, 容器
- Docker 启动容器 — Docker, CentOS, 容器启动
- Rocky Linux 9 Podman 启动参数 — Rocky Linux, Podman, cgroup-v2, cgroups, Kubernetes, 容器故障
- 服务日志与 K3S 状态 — Kubernetes, K3S, kubectl, Podman, 服务状态, 日志
- 登录 NineData — NineData, 登录, 初始化, 管理员账号
- 数据源管理 — 数据源管理, MySQL, TiDB, IvorySQL, 达梦数据库
- 敏感数据管理能力 — 敏感数据, 数据分类分级, 脱敏算法, MySQL, 数据安全
- 敏感数据测试 SQL — SQL, 敏感数据扫描, 脱敏, 数据库 DevOps, MySQL
- MySQL 到 TiDB 场景背景 — MySQL, TiDB, HTAP, 分布式数据库, 数据库迁移, 扩展性
- 复制与对比功能 — 数据复制, 数据库对比, 结构复制, 全量复制, 增量复制, 一致性对比
- 演示环境版本 — MySQL, TiDB, 版本信息, 演示环境
- 创建复制任务 — NineData, 数据复制, 结构复制, 全量复制
- 复制对象与映射过滤 — 复制对象, 黑名单, 映射, 数据过滤
- 预检查与一致性对比 — 预检查, 一致性对比, 数据比对
- 任务启动与数据查验 — 同步任务, 数据复制状态, 数据查验, 一致性
- 总结 — NineData, 本地化部署, 数据管理, 数据流转

## Repository Paths

- PDF: `collector/6ae9da3549283979aa62066b97ba2a96.pdf`
- Extracted: `generated/extracted/6ae9da3549283979aa62066b97ba2a96/full.md`
- Filtered: `generated/filtered/6ae9da3549283979aa62066b97ba2a96/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
