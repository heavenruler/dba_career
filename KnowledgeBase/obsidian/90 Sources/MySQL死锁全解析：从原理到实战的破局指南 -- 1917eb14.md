---
doc_id: "1917eb14d34aacecd7169b6ca66c3fc1"
title: "MySQL死锁全解析：从原理到实战的破局指南"
aliases:
  - "MySQL死锁全解析：从原理到实战的破局指南"
url: "https://mp.weixin.qq.com/s/JoXK3e9kxrSNbcENcLp_eg"
source_domain: "mp.weixin.qq.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "InnoDB"
  - "死锁"
  - "事务"
  - "索引"
  - "事故覆盘"
  - "数据库"
generated: true
---

# MySQL死锁全解析：从原理到实战的破局指南

> [!info] Provenance
> - doc_id: `1917eb14d34aacecd7169b6ca66c3fc1`
> - source_kind: `llm_filtered`
> - source: [original URL](https://mp.weixin.qq.com/s/JoXK3e9kxrSNbcENcLp_eg)
> - PDF: [open local PDF](../../collector/1917eb14d34aacecd7169b6ca66c3fc1.pdf)

## Summary

這篇文章用電商告警案例引出 MySQL/InnoDB 死鎖的成因、檢測與回滾策略，並整理常見觸發場景、預防手段與 `SHOW ENGINE INNODB STATUS` 的診斷方法。

## Knowledge Outline

- 故障案例 — MySQL, 死锁, 事故覆盘, SRE, 数据库
- 死锁本质 — MySQL, InnoDB, 死锁原理, 等待图, 事务
- InnoDB破局 — MySQL, InnoDB, 错误码, 配置, 死锁检测
- 高频场景 — MySQL, 死锁, 间隙锁, Gap Lock, 隔离级别, 事务
- 预防体系 — MySQL, 预防, 索引, 重试, 监控, 隔离级别
- 死锁诊断 — MySQL, 死锁日志, SHOW ENGINE INNODB STATUS, 排障, 索引

## Repository Paths

- PDF: `collector/1917eb14d34aacecd7169b6ca66c3fc1.pdf`
- Extracted: `generated/extracted/1917eb14d34aacecd7169b6ca66c3fc1/full.md`
- Filtered: `generated/filtered/1917eb14d34aacecd7169b6ca66c3fc1/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
