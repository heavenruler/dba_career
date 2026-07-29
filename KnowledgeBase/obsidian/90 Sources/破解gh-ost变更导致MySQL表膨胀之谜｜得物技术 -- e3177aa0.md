---
doc_id: "e3177aa0c78f29ff04351a044e709e05"
title: "破解gh-ost变更导致MySQL表膨胀之谜｜得物技术"
aliases:
  - "破解gh-ost变更导致MySQL表膨胀之谜｜得物技术"
url: "https://mp.weixin.qq.com/s/gkRqwk_kvY1BVzML6cPfpQ"
source_domain: "mp.weixin.qq.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "InnoDB"
  - "gh-ost"
  - "DDL"
  - "B+tree"
  - "页分裂"
  - "统计信息"
  - "慢SQL"
  - "数据库性能"
  - "DBA"
  - "事故分析"
generated: true
---

# 破解gh-ost变更导致MySQL表膨胀之谜｜得物技术

> [!info] Provenance
> - doc_id: `e3177aa0c78f29ff04351a044e709e05`
> - source_kind: `llm_filtered`
> - source: [original URL](https://mp.weixin.qq.com/s/gkRqwk_kvY1BVzML6cPfpQ)
> - PDF: [open local PDF](../../collector/e3177aa0c78f29ff04351a044e709e05.pdf)

## Summary

本文分析一次 gh-ost/无锁 DDL 变更后 MySQL 表空间膨胀、统计信息严重偏差与慢 SQL 的关联。核心内容包括 InnoDB B+tree、页、溢出页、页面分裂机制，当前 DDL 变更流程，全量复制与 binlog 回放交叉导致大主键记录先写入，再叠加单行记录较大触发页分裂异常，最终导致单页只存一条记录、统计信息偏差，并影响 ORDER BY limit 场景下的索引选择。

## Knowledge Outline

- 问题背景 — MySQL, DDL, 慢SQL, 事故分析
- B+tree 结构 — InnoDB, B+tree, 索引
- 页与溢出页 — InnoDB, page, 溢出页, 行格式
- 页面分裂机制 — InnoDB, 页分裂, 页合并, 性能
- 表空间管理 — InnoDB, tablespace, extent, page, IO
- 当前 DDL 变更机制 — DDL, gh-ost, binlog, OneDBA, 无锁变更
- 表膨胀根因 — MySQL, 页分裂, 表膨胀, gh-ost
- 复现建表与初始插入 — MySQL, 复现, InnoDB, page, heap
- 插入 rec-1 与 rec-2 — MySQL, 页分裂, 复现
- 插入 rec-3 与 rec-4 — MySQL, 页分裂, 复现, btr_page_get_split_rec_to_right
- 右分裂函数代码 — MySQL源码, InnoDB, 页分裂, btr_page_get_split_rec_to_right
- 插入 rec-5 与 rec-6 — MySQL, 页分裂, 单页单记录, 复现
- 排查过程 — MySQL, 排查过程, 页分裂, heap, ibd
- heap 与 ibd 解析 — InnoDB, heap, ibd, 页结构
- 统计信息偏差原因 — MySQL, InnoDB, 统计信息, 优化器, index dive
- 统计信息源码片段 — MySQL源码, InnoDB, 统计信息, dict_stats_analyze_index_for_n_prefix
- 统计信息优化思路 — MySQL, 统计信息, 优化器, 主键基数
- 统计信息与慢 SQL — MySQL, 慢SQL, ORDER BY, prefer_ordering_index, 索引选择
- 临时解决方案 — MySQL, DDL, alter table, 表空间整理, 临时方案
- 长期解决方案 — gh-ost, DDL, binlog, 长期方案, PR-1378
- 总结 — MySQL, InnoDB, DDL, 页分裂, 慢SQL

## Repository Paths

- PDF: `collector/e3177aa0c78f29ff04351a044e709e05.pdf`
- Extracted: `generated/extracted/e3177aa0c78f29ff04351a044e709e05/full.md`
- Filtered: `generated/filtered/e3177aa0c78f29ff04351a044e709e05/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
