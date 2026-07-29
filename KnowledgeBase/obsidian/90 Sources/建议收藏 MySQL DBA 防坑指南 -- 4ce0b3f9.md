---
doc_id: "4ce0b3f917daa79230d277dfbc115c16"
title: "建议收藏|MySQL DBA 防坑指南"
aliases:
  - "建议收藏|MySQL DBA 防坑指南"
url: "https://mp.weixin.qq.com/s/iy9mAwahHWo4V3tyYGm6jw"
source_domain: "mp.weixin.qq.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "DBA"
  - "运维"
  - "性能调优"
  - "故障排查"
  - "DDL"
  - "监控"
  - "SRE"
generated: true
---

# 建议收藏|MySQL DBA 防坑指南

> [!info] Provenance
> - doc_id: `4ce0b3f917daa79230d277dfbc115c16`
> - source_kind: `llm_filtered`
> - source: [original URL](https://mp.weixin.qq.com/s/iy9mAwahHWo4V3tyYGm6jw)
> - PDF: [open local PDF](../../collector/4ce0b3f917daa79230d277dfbc115c16.pdf)

## Summary

整理了 MySQL 运维中常见的坑和对应处理思路，涵盖连接数、文件句柄、隐式转换、索引选择、自增键、大表删除、AHI、MHA、pt-archiver、pt-osc/gh-ost、拆库、监控、磁盘空间、死锁、性能排查与 crash 处理。

## Knowledge Outline

- MySQL连接数问题 — MySQL, 连接数, 监控, 故障排查
- MySQL文件句柄设置 — MySQL, 文件句柄, Linux, 系统参数, 运维
- 注意SQL隐式转换的坑 — MySQL, SQL, 隐式转换, 索引, 开发规范
- SQL为什么一会可以走到索引，一会走不到索引 — MySQL, 优化器, 索引, 慢查询, 查询性能
- 自增键重启后回溯问题 — MySQL, InnoDB, 自增键, 重启, AUTO_INCREMENT
- 自增键用完怎么办 — MySQL, 自增键, 表设计, 容量规划, 监控
- 大表删除hang的问题 — MySQL, 大表删除, InnoDB, Linux, 文件系统, 运维
- Adaptive Hash Index引发的问题 — MySQL, InnoDB, AHI, 性能, 锁
- MHA切换VIP的问题 — MySQL, MHA, 高可用, VIP, DNS, 切换
- pt-archiver迁移为什么少了一条数据 — MySQL, pt-archiver, 归档, AUTO_INCREMENT, Percona
- pt-osc和ghost变更丢数据的问题 — MySQL, pt-osc, gh-ost, 在线变更, 唯一索引, 数据丢失, DDL
- 数据库拆分引发的删库事件 — MySQL, 数据库拆分, 事故复盘, 流程, 双重确认
- HA没有切换/监控没有正常报警 — MySQL, HA, 监控, SRE, 单点故障
- df看空间越来越少，du却没有发现大文件 — Linux, 磁盘空间, lsof, deleted file, 运维
- 死锁要紧么，需要注意什么 — MySQL, 死锁, InnoDB, 故障排查
- text等大对象类型有什么风险 — MySQL, TEXT, BLOB, InnoDB, 存储, 性能
- CPU %user 为什么特别的高 — MySQL, CPU, 慢SQL, 索引, 性能调优
- 查询被hang住了，什么原因 — MySQL, hang, 性能问题, 锁等待, InnoDB, 故障排查
- mysql crash了，怎么办 — MySQL, crash, error log, 故障排查, 数据恢复

## Repository Paths

- PDF: `collector/4ce0b3f917daa79230d277dfbc115c16.pdf`
- Extracted: `generated/extracted/4ce0b3f917daa79230d277dfbc115c16/full.md`
- Filtered: `generated/filtered/4ce0b3f917daa79230d277dfbc115c16/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
