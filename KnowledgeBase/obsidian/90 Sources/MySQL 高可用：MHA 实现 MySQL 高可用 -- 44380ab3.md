---
doc_id: "44380ab34618101b2a7b528a7fba216f"
title: "MySQL 高可用：MHA 实现 MySQL 高可用"
aliases:
  - "MySQL 高可用：MHA 实现 MySQL 高可用"
url: "https://mp.weixin.qq.com/s/qITvEYNaedRiyPwMmC-lpw"
source_domain: "mp.weixin.qq.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "DBA"
  - "高可用"
  - "MHA"
  - "主从复制"
  - "故障转移"
  - "SRE"
  - "DevOps"
generated: true
---

# MySQL 高可用：MHA 实现 MySQL 高可用

> [!info] Provenance
> - doc_id: `44380ab34618101b2a7b528a7fba216f`
> - source_kind: `llm_filtered`
> - source: [original URL](https://mp.weixin.qq.com/s/qITvEYNaedRiyPwMmC-lpw)
> - PDF: [open local PDF](../../collector/44380ab34618101b2a7b528a7fba216f.pdf)

## Summary

本文介绍 MySQL 高可用方案对比、MHA 工作原理、架构组件、故障转移选主策略、数据恢复逻辑，并给出基于 MHA Manager、Node、VIP、MySQL 主从复制的部署配置与故障切换验证流程。

## Knowledge Outline

- MySQL 高可用方案对比 — MySQL, 高可用, MMM
- MHA 概念 — MHA, MySQL, 主从复制
- 金融级高可用方案 — Galera Cluster, Group Replication, Paxos, 高可用
- MHA 工作原理 — MHA, 故障转移, binlog, relay log, VIP
- 选举新的 Master — MHA, Master, 选主, candidate_master, check_repl_delay
- 数据恢复 — MHA, 数据恢复, GTID, relaylog, 半同步复制
- MHA 软件组件 — MHA, Manager, Node, 工具
- MHA 自定义扩展与配置文件 — MHA, 配置, 扩展脚本
- 实验主机清单 — MHA, 部署环境, MySQL 8.0
- Manager 与 Node 安装 — MHA, 安装, CentOS, Rocky Linux
- SSH 免密登录配置 — SSH, MHA, 免密登录
- MHA 应用配置 — MHA, app1.cnf, VIP, candidate_master
- Slave 提升策略 — MHA, 选主策略, slave, master
- 告警脚本配置 — MHA, 告警, mailx, postfix
- VIP 配置 — VIP, MHA, ifconfig
- MySQL 节点配置 — MySQL, my.cnf, 主从复制, read-only
- 主从复制配置 — MySQL, 主从复制, CHANGE MASTER, replication slave
- 主从同步测试 — MySQL, 主从同步, 验证
- MHA 环境检查与启动 — MHA, 环境检查, 启动, masterha_manager
- 心跳查询检查 — MHA, 心跳检测, general_log
- 故障切换测试 — MHA, 故障切换, VIP, master故障
- 切换后复制验证 — MHA, 故障切换验证, MySQL复制
- MHA 故障后处理说明 — MHA, 故障后处理, 限制, VIP

## Repository Paths

- PDF: `collector/44380ab34618101b2a7b528a7fba216f.pdf`
- Extracted: `generated/extracted/44380ab34618101b2a7b528a7fba216f/full.md`
- Filtered: `generated/filtered/44380ab34618101b2a7b528a7fba216f/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
