---
doc_id: "0756a3aeba95614e8f995f77620e9a24"
title: "TiDB 学习之路从部署开始 - 墨天轮"
aliases:
  - "TiDB 学习之路从部署开始 - 墨天轮"
url: "https://www.modb.pro/db/1788935978215870464"
source_domain: "www.modb.pro"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "TiDB"
  - "数据库"
  - "分布式数据库"
  - "HTAP"
  - "TiUP"
  - "离线部署"
  - "集群部署"
  - "运维"
  - "Linux"
  - "性能配置"
generated: true
---

# TiDB 学习之路从部署开始 - 墨天轮

> [!info] Provenance
> - doc_id: `0756a3aeba95614e8f995f77620e9a24`
> - source_kind: `llm_filtered`
> - source: [original URL](https://www.modb.pro/db/1788935978215870464)
> - PDF: [open local PDF](../../collector/0756a3aeba95614e8f995f77620e9a24.pdf)

## Summary

本文介绍 TiDB 的核心特性、应用场景，并记录了在本地虚拟化环境中以 TiUP 离线部署 TiDB v7.5.1 集群的拓扑规划、操作系统环境准备、部署、启动验证、连接测试与卸载流程。

## Knowledge Outline

- TiDB 简述 — TiDB, HTAP, OLTP, OLAP, 分布式数据库
- 核心特性 — TiDB, Multi-Raft, TiKV, TiFlash, MySQL兼容, 云原生
- 应用场景 — 应用场景, 金融行业, OLTP, HTAP, 数据汇聚
- 部署概要 — TiDB, LTS, 离线部署
- 拓扑规划 — 拓扑规划, TiDB, PD, TiKV, TiFlash, Grafana
- 主机名与 IP — Linux, 主机名, 网络配置
- 禁用 swap — Linux, swap, 性能配置
- 防火墙配置 — Linux, firewalld, 运维
- 时间同步 — chrony, NTP, 时间同步, 集群部署
- 禁用 SELinux — SELinux, Linux, 安全配置
- 操作系统参数 — sysctl, sshd, Linux, 性能配置
- limits 参数 — limits.conf, Linux, 文件句柄, 性能配置
- 透明大页 — THP, Linux, 性能配置
- Irqbalance — Irqbalance, CPU, 性能配置, Linux
- numactl — numactl, NUMA, Linux
- tidb 用户 — 用户管理, sudo, TiDB部署
- SSH 互信 — SSH, 免密登录, TiDB部署
- 安装包准备 — 安装包, TiDB, 离线部署
- 在线部署 TiUP — TiUP, 在线部署, TiDB
- 离线部署 TiUP — TiUP, 离线部署, TiDB
- 合并离线包 — TiUP, 离线镜像, TiDB
- 初始化配置 — topology.yaml, TiUP, 集群配置
- 检查与修复风险 — TiUP, 集群检查, 风险修复
- 部署集群 — TiUP, TiDB集群, 部署
- 集群状态 — TiUP, 集群状态, TiDB
- 安全启动 — TiUP, 安全启动, root密码
- 普通启动 — TiUP, 普通启动, TiDB
- 状态检查 — TiUP, Dashboard, Grafana, 监控
- 客户端连接 — MySQL协议, 客户端连接, TiDB
- 卸载集群 — TiUP, 卸载, 清理数据, 端口检查

## Repository Paths

- PDF: `collector/0756a3aeba95614e8f995f77620e9a24.pdf`
- Extracted: `generated/extracted/0756a3aeba95614e8f995f77620e9a24/full.md`
- Filtered: `generated/filtered/0756a3aeba95614e8f995f77620e9a24/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
