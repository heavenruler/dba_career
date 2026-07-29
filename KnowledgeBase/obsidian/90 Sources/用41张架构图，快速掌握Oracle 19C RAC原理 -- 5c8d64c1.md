---
doc_id: "5c8d64c19d54db6cc2c80bc36051d9c1"
title: "用41张架构图，快速掌握Oracle 19C RAC原理"
aliases:
  - "用41张架构图，快速掌握Oracle 19C RAC原理"
url: "https://mp.weixin.qq.com/s/_fHC508aVoNCA2MvduEuuQ"
source_domain: "mp.weixin.qq.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "Oracle"
  - "RAC"
  - "Oracle 19c"
  - "DBA"
  - "数据库架构"
  - "Clusterware"
  - "ASM"
  - "ACFS"
  - "高可用"
  - "共享存储"
  - "FPP"
generated: true
---

# 用41张架构图，快速掌握Oracle 19C RAC原理

> [!info] Provenance
> - doc_id: `5c8d64c19d54db6cc2c80bc36051d9c1`
> - source_kind: `llm_filtered`
> - source: [original URL](https://mp.weixin.qq.com/s/_fHC508aVoNCA2MvduEuuQ)
> - PDF: [open local PDF](../../collector/5c8d64c19d54db6cc2c80bc36051d9c1.pdf)

## Summary

本文整理 Oracle 19c RAC 技术架构，涵盖 RAC 数据库与实例、共享存储、SPFILE、TDE、Undo/Redo、监听器、Clusterware、OCR/Voting Disk、ASM、ACFS、服务器池、FPP 等核心原理。

## Knowledge Outline

- RAC 配置模型 — Oracle RAC, 数据库配置, Flex ASM
- RAC 概览 — Oracle RAC, Grid Infrastructure, Clusterware, 网络
- RAC 实例与缓存融合 — RAC Instance, Cache Fusion, SGA, 互连
- RAC One Node — RAC One Node, 高可用, 故障转移
- RAC 管理工具 — SRVCTL, CVU, SQLPlus, Oracle Enterprise Manager
- RAC 数据库文件 — 数据文件, Undo, Redo, 临时表空间, ASM
- SPFILE 与参数 — SPFILE, PFILE, 初始化参数, CLUSTER_DATABASE
- TDE 钱包 — TDE, Wallet, WALLET_ROOT, 安全
- Undo 表空间 — Undo Tablespace, AUM, 事务恢复
- Redo 线程 — Redo, Redo Thread, 恢复, ASM
- PDB 与服务 — PDB, CDB, 多租户, 动态数据库服务
- SCAN 监听器 — SCAN, Listener, DNS, VIP, 负载均衡
- 集群节点 — Cluster Node, ADR, OLR, 共享存储, FPP
- 集群与存储选项 — Standalone Cluster, Extended Cluster, Cluster Domain, 共享存储, ASM, NFS, OCFS2
- 扩展集群 — Extended Cluster, 站点, 故障组, 冗余
- GIMR OCR Voting — GIMR, OCR, Voting File, Clusterware, ASM
- OCR 原理 — OCR, CRSD, 共享缓存, Clusterware
- Voting Disk 与脑裂 — Voting Disk, CSS, Split Brain, 心跳, 节点驱逐
- Clusterware 工具与网络 — CRSCTL, SRVCTL, 公共网络, 私有网络, 链路聚合
- Clusterware 进程 — CRS, CRSD, OHASD, 高可用, 资源管理
- ONS 与 FAN — ONS, FAN, HA Event, 连接池, TAF
- GNS 与 SCAN — GNS, GPnP, mDNS, SCAN, 监听器
- 服务器池 — Server Pool, 资源隔离, Policy-managed, Administrator-managed
- ASM 配置 — ASM, Flex ASM, IOServer, 共享存储
- ASM 实例 — ASM Instance, SGA, 后台进程, 内存管理
- ASM 磁盘组 — ASM Disk, Disk Group, 冗余, 故障组, ACFS
- ASM 文件组 — File Group, Quota Group, PDB, ASM, FLEX
- ACFS — ACFS, ASM, POSIX, ADVM, 文件系统
- FPP 工作流 — Fleet Patching, FPP, RHP, rhpctl, ACFS, 补丁

## Repository Paths

- PDF: `collector/5c8d64c19d54db6cc2c80bc36051d9c1.pdf`
- Extracted: `generated/extracted/5c8d64c19d54db6cc2c80bc36051d9c1/full.md`
- Filtered: `generated/filtered/5c8d64c19d54db6cc2c80bc36051d9c1/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
