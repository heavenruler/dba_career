---
doc_id: "9d9c56c47b7487e447b293a014d5f263"
title: "35 张图带你了解 Oracle AI Database 26ai 技术架构(下)"
aliases:
  - "35 张图带你了解 Oracle AI Database 26ai 技术架构(下)"
url: "https://mp.weixin.qq.com/s/agpGc3NvVGcPg1rmQ24MyA"
source_domain: "mp.weixin.qq.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "Oracle"
  - "数据库架构"
  - "后台进程"
  - "AWR"
  - "ASH"
  - "闪回数据库"
  - "归档日志"
  - "作业队列"
  - "共享服务器"
  - "RAC"
  - "ASM"
  - "DBA"
generated: true
---

# 35 张图带你了解 Oracle AI Database 26ai 技术架构(下)

> [!info] Provenance
> - doc_id: `9d9c56c47b7487e447b293a014d5f263`
> - source_kind: `llm_filtered`
> - source: [original URL](https://mp.weixin.qq.com/s/agpGc3NvVGcPg1rmQ24MyA)
> - PDF: [open local PDF](../../collector/9d9c56c47b7487e447b293a014d5f263.pdf)

## Summary

本文主要整理 Oracle Database 26ai 的后台进程职责与协作关系，涵盖 PMON、PMAN、LREG、SMON、DBWn、CKPT、MMON/MMNL、RECO、LGWR、ARCn、CJQ0、RVWR、FBDA、SMCO/Wnnn、Dnnn/Snnn 等进程，以及它们与 AWR、ASH、闪回、归档、作业队列和共享服务器的关系。

## Knowledge Outline

- PMON — Oracle, 数据库架构, 后台进程, PMON, ASM
- PMAN — Oracle, 数据库架构, 后台进程, PMAN, 共享服务器, 作业队列, ASM
- LREG — Oracle, 数据库架构, 后台进程, LREG, ASM, RAC
- SMON — Oracle, 数据库架构, 后台进程, SMON, Undo, Flashback, RAC
- DBWn — Oracle, 数据库架构, 后台进程, DBWn, 写入, 性能调优, 参数
- CKPT — Oracle, 数据库架构, 后台进程, CKPT, 检查点, 参数, ASM
- MMON / MMNL — Oracle, 数据库架构, 后台进程, AWR, ASH, MMON, MMNL, 性能监控, 自动调优
- RECO — Oracle, 数据库架构, 后台进程, RECO, 分布式事务, 故障恢复
- LGWR — Oracle, 数据库架构, 后台进程, LGWR, Redo, ASM, RAC
- ARCn — Oracle, 数据库架构, 后台进程, ARCn, 归档日志, 参数
- CJQ0 / Jnnn — Oracle, 数据库架构, 后台进程, CJQ0, Jnnn, Scheduler, 作业队列, 参数
- RVWR — Oracle, 数据库架构, 后台进程, RVWR, 闪回数据库, SGA
- FBDA — Oracle, 数据库架构, 后台进程, FBDA, 闪回数据库, 审计, 保留期限
- SMCO / Wnnn — Oracle, 数据库架构, 后台进程, SMCO, Wnnn, 空间管理, 内存管理
- Dnnn / Snnn — Oracle, 数据库架构, 后台进程, Dnnn, Snnn, 共享服务器, SGA

## Repository Paths

- PDF: `collector/9d9c56c47b7487e447b293a014d5f263.pdf`
- Extracted: `generated/extracted/9d9c56c47b7487e447b293a014d5f263/full.md`
- Filtered: `generated/filtered/9d9c56c47b7487e447b293a014d5f263/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
