---
doc_id: "54711fcb27d9bfcc2ddd6a778b3b5ac9"
title: "MySQL8.0.40 MGR集群安装部署及管理 - 墨天轮"
aliases:
  - "MySQL8.0.40 MGR集群安装部署及管理 - 墨天轮"
url: "https://www.modb.pro/db/1871362852146135040"
source_domain: "www.modb.pro"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "MGR"
  - "InnoDB Cluster"
  - "mysqlshell"
  - "DBA"
  - "数据库高可用"
  - "集群部署"
  - "故障处理"
generated: true
---

# MySQL8.0.40 MGR集群安装部署及管理 - 墨天轮

> [!info] Provenance
> - doc_id: `54711fcb27d9bfcc2ddd6a778b3b5ac9`
> - source_kind: `llm_filtered`
> - source: [original URL](https://www.modb.pro/db/1871362852146135040)
> - PDF: [open local PDF](../../collector/54711fcb27d9bfcc2ddd6a778b3b5ac9.pdf)

## Summary

本文保留 MySQL 8.0.40 MGR 集群介绍、三节点部署、my.cnf 配置、MGR 插件与复制账号配置、mysqlshell 管理、节点增删、主节点切换及常见报错处理等高价值技术内容。

## Knowledge Outline

- MGR 集群介绍 — MySQL, MGR, Paxos, 高可用
- 环境说明 — 环境配置, MySQL
- glibc 检查 — 安装前检查, glibc
- 安装包上传 — MySQL, mysqlshell, 安装
- Hosts 配置 — Linux, hosts, 集群部署
- 资源限制 — Linux, 资源限制, MySQL
- 关闭 SELINUX — Linux, SELinux
- 解压安装包 — MySQL, 安装
- 用户与目录 — Linux, MySQL, 权限
- my.cnf 示例 — MySQL, my.cnf, MGR, 性能参数
- 节点配置差异 — MySQL, MGR, 节点配置
- 初始化与启动 MySQL — MySQL, 初始化, 启动
- 环境变量与 root 密码 — MySQL, 环境变量, 账号管理
- 管理账号 — MySQL, 账号管理, 权限
- MGR 插件与复制账号 — MGR, 复制账号, MySQL
- 单主模式说明 — MGR, 单主模式, 高可用
- 启动 MGR — MGR, 启动, 集群状态
- 加入其他节点 — MGR, 节点加入, 故障处理
- mysqlshell 安装 — mysqlshell, 安装
- 创建 Cluster — mysqlshell, InnoDB Cluster
- 查看集群状态 — mysqlshell, 集群状态, MGR
- 修复 parallel-appliers 提示 — mysqlshell, 故障处理, parallel-appliers
- 添加新节点 — MGR, mysqlshell, 节点扩容
- 删除老节点 — MGR, mysqlshell, 节点删除
- 切换主节点 — MGR, 主节点切换, mysqlshell
- caching_sha2_password 报错 — MySQL, 认证插件, 故障处理
- 重新加入节点报错 — InnoDB Cluster, mysqlshell, 节点加入, 故障处理
- 总结 — MySQL, MGR, mysqlshell

## Repository Paths

- PDF: `collector/54711fcb27d9bfcc2ddd6a778b3b5ac9.pdf`
- Extracted: `generated/extracted/54711fcb27d9bfcc2ddd6a778b3b5ac9/full.md`
- Filtered: `generated/filtered/54711fcb27d9bfcc2ddd6a778b3b5ac9/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
