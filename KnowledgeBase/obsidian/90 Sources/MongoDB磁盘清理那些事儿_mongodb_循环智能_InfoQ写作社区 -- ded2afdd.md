---
doc_id: "ded2afddbbecda4a36a0bd8da64ba6b1"
title: "MongoDB磁盘清理那些事儿_mongodb_循环智能_InfoQ写作社区"
aliases:
  - "MongoDB磁盘清理那些事儿_mongodb_循环智能_InfoQ写作社区"
url: "https://xie.infoq.cn/article/d8cb871a7733646996f60641a"
source_domain: "xie.infoq.cn"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MongoDB"
  - "WiredTiger"
  - "磁盘清理"
  - "副本集"
  - "GridFS"
  - "DBA"
  - "故障处理"
  - "数据恢复"
generated: true
---

# MongoDB磁盘清理那些事儿_mongodb_循环智能_InfoQ写作社区

> [!info] Provenance
> - doc_id: `ded2afddbbecda4a36a0bd8da64ba6b1`
> - source_kind: `llm_filtered`
> - source: [original URL](https://xie.infoq.cn/article/d8cb871a7733646996f60641a)
> - PDF: [open local PDF](../../collector/ded2afddbbecda4a36a0bd8da64ba6b1.pdf)

## Summary

這篇文章聚焦 MongoDB 刪除資料後磁碟空間不釋放的實務處理，整理了 compact、secondary 節點同步、copyDatabase、mongodump/mongorestore、repairDatabase 五種回收空間方案，並強調備份、索引、停機窗口與風險控制。

## Knowledge Outline

- 业务背景与问题 — MongoDB, 磁盘清理, GridFS, WiredTiger, 副本集, 备份, 索引
- 方法一：compact 整理 — MongoDB, compact, 磁盘整理, 副本集, 运维
- 方法二：secondary 节点同步 — MongoDB, secondary, 副本集同步, 磁盘清理, 索引
- 方法三：copyDatabase — MongoDB, copyDatabase, 数据迁移, 索引, 磁盘回收
- 方法四：mongodump / mongorestore — MongoDB, mongodump, mongorestore, 备份恢复, 磁盘清理
- 方法五：repairDatabase — MongoDB, repairDatabase, 数据修复, 索引重建, 风险控制
- 总结 — MongoDB, 磁盘清理, 备份, 高危操作, 方案选型

## Repository Paths

- PDF: `collector/ded2afddbbecda4a36a0bd8da64ba6b1.pdf`
- Extracted: `generated/extracted/ded2afddbbecda4a36a0bd8da64ba6b1/full.md`
- Filtered: `generated/filtered/ded2afddbbecda4a36a0bd8da64ba6b1/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
