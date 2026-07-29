---
doc_id: "0e1e0313ecb9fbd59e27a609cef0705f"
title: "MySQL的默认隔离级别为什么是RR，而不是RCMySQL 的默认隔离级别为什么是 RR，而不是 RC？MySQL5.0 - 掘金"
aliases:
  - "MySQL的默认隔离级别为什么是RR，而不是RCMySQL 的默认隔离级别为什么是 RR，而不是 RC？MySQL5.0 - 掘金"
url: "https://juejin.cn/post/7422848805049040896"
source_domain: "juejin.cn"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "数据库"
  - "事务隔离级别"
  - "binlog"
  - "主从复制"
  - "InnoDB"
  - "DBA"
  - "面试"
generated: true
---

# MySQL的默认隔离级别为什么是RR，而不是RCMySQL 的默认隔离级别为什么是 RR，而不是 RC？MySQL5.0 - 掘金

> [!info] Provenance
> - doc_id: `0e1e0313ecb9fbd59e27a609cef0705f`
> - source_kind: `llm_filtered`
> - source: [original URL](https://juejin.cn/post/7422848805049040896)
> - PDF: [open local PDF](../../collector/0e1e0313ecb9fbd59e27a609cef0705f.pdf)

## Summary

本文讨论 MySQL 默认隔离级别为何是 RR 而不是 RC，重点围绕事务隔离级别、binlog 三种格式 STATEMENT / ROW / MIXED、不同 MySQL 版本的 binlog 默认值，以及早期主从复制 bug 与默认隔离级别选择的关系。

## Knowledge Outline

- 隔离级别回顾 — MySQL, 事务隔离级别, InnoDB, 面试
- binlog 基础 — MySQL, binlog, SQL
- binlog 格式版本演进 — MySQL, binlog, 版本差异
- STATEMENT 格式 — MySQL, binlog, STATEMENT, mysqlbinlog
- STATEMENT 记录 SQL — MySQL, binlog, STATEMENT, SQL
- ROW 格式示例 — MySQL, binlog, ROW, mysqlbinlog
- ROW 解密查看 — MySQL, binlog, ROW, mysqlbinlog
- ROW INSERT 记录 — MySQL, binlog, ROW, INSERT
- ROW UPDATE 记录 — MySQL, binlog, ROW, UPDATE
- ROW DELETE 记录 — MySQL, binlog, ROW, DELETE
- MIXED 格式 — MySQL, binlog, MIXED, STATEMENT, ROW
- 格式选择建议 — MySQL, binlog, ROW, 数据准确性
- RC 与 STATEMENT 限制 — MySQL, RC, STATEMENT, InnoDB, binlog
- binlog 提交顺序 — MySQL, binlog, 事务, commit, 主从复制
- 默认 RR 的历史原因 — MySQL, RR, RC, binlog, 主从复制, Bug23051
- RR 作为默认隔离级别 — MySQL, RR, RC, STATEMENT, 主从复制
- 总结 — MySQL, binlog, RR, RC, 主从复制, 总结

## Repository Paths

- PDF: `collector/0e1e0313ecb9fbd59e27a609cef0705f.pdf`
- Extracted: `generated/extracted/0e1e0313ecb9fbd59e27a609cef0705f/full.md`
- Filtered: `generated/filtered/0e1e0313ecb9fbd59e27a609cef0705f/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
