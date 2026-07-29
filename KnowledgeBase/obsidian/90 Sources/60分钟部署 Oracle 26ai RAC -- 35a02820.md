---
doc_id: "35a02820f97270a198956b1d664bb548"
title: "60分钟部署 Oracle 26ai RAC"
aliases:
  - "60分钟部署 Oracle 26ai RAC"
url: "https://www.modb.pro/db/2024323757843226624"
source_domain: "www.modb.pro"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "Oracle"
  - "Oracle RAC"
  - "Oracle 26ai"
  - "Podman"
  - "DBA"
  - "数据库部署"
  - "ASM"
  - "CMAN"
  - "Linux"
  - "容器化"
generated: true
---

# 60分钟部署 Oracle 26ai RAC

> [!info] Provenance
> - doc_id: `35a02820f97270a198956b1d664bb548`
> - source_kind: `llm_filtered`
> - source: [original URL](https://www.modb.pro/db/2024323757843226624)
> - PDF: [open local PDF](../../collector/35a02820f97270a198956b1d664bb548.pdf)

## Summary

本文记录在 Oracle Linux 9.7 宿主机上使用 Podman 部署 Oracle 26ai RAC 的完整流程，包含资源准备、宿主机参数、Podman 网络与密钥、ASM 共享块设备、DNS/RAC/cman 容器创建、集群检查、数据库参数修改与远程连接验证。

## Knowledge Outline

- Oracle RAC Podman 支持 — Oracle RAC, Podman, 生产支持
- 宿主机资源准备 — Oracle Linux, 资源规划, RAC
- 文件系统容量检查 — Linux, 磁盘容量, RAC
- RAC 网络规划 — RAC, 网络规划, SCAN, VIP, CMAN
- 关闭透明大页 — Linux, THP, Oracle RAC
- 设置时钟源 — Linux, 时钟源, 虚拟机
- 关闭防火墙与 SELinux — Linux, firewalld, SELinux
- 宿主机内核参数 — Linux, sysctl, Oracle RAC
- 安装 Podman — Podman, Oracle Linux, 容器
- 下载 RAC 镜像 — Podman, Oracle RAC, 镜像
- 创建 Podman 网桥 — Podman, 网络, RAC
- 创建 Podman Secret — Podman, Secret, 安全
- 共享块设备固定盘符 — ASM, udev, ESXi, 块设备
- 重载 udev 与初始化磁盘 — ASM, udev, 块设备
- 时区文件 — Linux, 时区
- 创建 DNS 服务 — DNS, Podman, Oracle RAC
- 修复官方镜像 srvctl — Oracle RAC, srvctl, 镜像问题
- 创建第一个 RAC 节点 — Oracle RAC, Podman, 节点部署
- 创建第二个 RAC 节点 — Oracle RAC, Podman, 节点部署
- 启动 RAC 容器 — Oracle RAC, Podman, 安装注意事项
- 数据库创建成功日志 — Oracle RAC, 安装验证, 日志
- 检查 RAC 集群 — Oracle RAC, crsctl, 集群检查
- 集群资源状态 — Oracle RAC, crsctl, 资源状态
- 数据库状态与 ASM 空间 — Oracle, ASM, SQLPlus, 数据库检查
- 修改 remote_listener — Oracle RAC, remote_listener, SQLPlus
- 部署 CMAN — CMAN, Oracle Connection Manager, Podman
- CMAN 成功日志 — CMAN, 日志, 验证
- 修改 cman.ora — CMAN, cman.ora, Oracle 网络
- 远程连接验证 — Oracle RAC, SQLPlus, 远程连接, 验证

## Repository Paths

- PDF: `collector/35a02820f97270a198956b1d664bb548.pdf`
- Extracted: `generated/extracted/35a02820f97270a198956b1d664bb548/full.md`
- Filtered: `generated/filtered/35a02820f97270a198956b1d664bb548/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
