---
doc_id: "8b12c380d76b70ee02aeec4ff21f3d63"
title: "知乎 PB 级别 TiDB 数据库在线迁移实践导读 本文由知乎数据库负责人代晓磊老师老师撰写，全面介绍了知乎几十套 Ti - 掘金"
aliases:
  - "知乎 PB 级别 TiDB 数据库在线迁移实践导读 本文由知乎数据库负责人代晓磊老师老师撰写，全面介绍了知乎几十套 Ti - 掘金"
url: "https://juejin.cn/post/7418412937607708708"
source_domain: "juejin.cn"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "TiDB"
  - "数据库迁移"
  - "DBA"
  - "Kubernetes"
  - "TiCDC"
  - "Placement Rules"
  - "BR"
  - "多云多活"
  - "在线迁移"
  - "架构设计"
generated: true
---

# 知乎 PB 级别 TiDB 数据库在线迁移实践导读 本文由知乎数据库负责人代晓磊老师老师撰写，全面介绍了知乎几十套 Ti - 掘金

> [!info] Provenance
> - doc_id: `8b12c380d76b70ee02aeec4ff21f3d63`
> - source_kind: `llm_filtered`
> - source: [original URL](https://juejin.cn/post/7418412937607708708)
> - PDF: [open local PDF](../../collector/8b12c380d76b70ee02aeec4ff21f3d63.pdf)

## Summary

本文介绍知乎 PB 级别 TiDB 数据库在线迁移实践，涵盖在线机房迁移准备条件、Placement Rules 副本投放迁移、TiCDC 主备集群迁移、其他业务场景迁移方式，以及迁移后的平台化建设经验。

## Knowledge Outline

- 导读 — TiDB, 数据库迁移, 在线迁移
- 在线机房准备条件 — 机房迁移, 网络, Kubernetes, 资源规划
- TiDB 迁移切换方案 — TiDB, Kubernetes, 迁移架构, TiCDC, Placement Rules
- Placement Rules 迁移架构 — TiDB, Placement Rules, PD, Raft, 调度
- Placement Rules 默认配置 — TiDB, pd-ctl, Placement Rules
- 同城双中心副本配置 — TiDB, Placement Rules, 副本放置, 同城双中心
- 新机房副本迁移调整 — TiDB, Placement Rules, region leader, 副本迁移
- Placement Rules 优缺点 — TiDB, Placement Rules, 优缺点, 性能
- 同构集群迁移步骤一 — TiDB, PD, TiKV, Kubernetes, clusterDomain
- 调优 Region 创建速度 — TiDB, PD, TiKV, region, Store Limit, 监控
- 加速调度配置 — TiDB, PD, 调度, 性能调优
- Leader 均衡与切换 — TiDB, region leader, PD, TiKV, 多云多活
- PD Leader 切换风险 — TiDB, PD, 故障, 风险控制
- 业务切换与资源回收 — TiDB, 业务切换, DNS, 资源回收, Kubernetes
- clusterDomain 注意事项 — TiDB, Kubernetes, clusterDomain
- TiCDC 主备集群方案 — TiDB, TiCDC, BR, 主备集群, 数据一致性
- TiCDC 方案优缺点 — TiDB, TiCDC, BR, SQL 兼容性, 回滚, MVCC
- TiCDC 迁移步骤一 — TiDB, TiCDC, gc_life_time, SQL
- BR 备份与恢复 — TiDB, BR, S3, 备份恢复
- 创建 CDC 同步任务 — TiDB, TiCDC, TSO, changefeed, Kubernetes
- TiCDC 验证与切换 — TiDB, TiCDC, 灰度, 数据一致性, 回滚
- 其他迁移场景 — TiDB, 业务双写, BR, dumping, lightning
- 总结 — TiDB, PB 级数据, DTS, 平台化, 机房迁移

## Repository Paths

- PDF: `collector/8b12c380d76b70ee02aeec4ff21f3d63.pdf`
- Extracted: `generated/extracted/8b12c380d76b70ee02aeec4ff21f3d63/full.md`
- Filtered: `generated/filtered/8b12c380d76b70ee02aeec4ff21f3d63/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
