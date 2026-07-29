---
doc_id: "02fe4209332110a9ec9a5d79241dbaae"
title: "MySQL Drop Table 优化"
aliases:
  - "MySQL Drop Table 优化"
url: "https://mp.weixin.qq.com/s/7_cBEqAqFVl7xtuRhDDwvw"
source_domain: "mp.weixin.qq.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "InnoDB"
  - "buffer pool"
  - "AHI"
  - "DDL"
  - "性能调优"
  - "事故覆盘"
  - "SRE"
generated: true
---

# MySQL Drop Table 优化

> [!info] Provenance
> - doc_id: `02fe4209332110a9ec9a5d79241dbaae`
> - source_kind: `llm_filtered`
> - source: [original URL](https://mp.weixin.qq.com/s/7_cBEqAqFVl7xtuRhDDwvw)
> - PDF: [open local PDF](../../collector/02fe4209332110a9ec9a5d79241dbaae.pdf)

## Summary

这篇文章主要分析 MySQL 5.7 上 DROP TABLE / TRUNCATE TABLE 造成长时间阻塞、主备切换的原因，重点涉及 buffer pool 监控解读、AHI 清理、dict_sys::mutex、LRU scan / flush list scan，以及 AliSQL 和 MySQL 8.0 的对应优化。

## Knowledge Outline

- buffer pool 监控指标 — MySQL, InnoDB, buffer pool, 性能调优
- free page 与数据页 — MySQL, InnoDB, buffer pool, 性能调优, SRE
- 额外占用与大幅回落 — MySQL, InnoDB, tablespace, buffer pool, 版本差异, 性能调优
- DROP TABLE 事故 — MySQL, DROP TABLE, 事故覆盤, HA, SRE, InnoDB
- before_dml hook 与 dict_sys — MySQL, InnoDB, Data Dictionary, 锁, DDL, 性能调优
- AHI 与文件删除优化 — MySQL, AHI, InnoDB, AliSQL, 性能优化, DDL
- 页面清理与 TRUNCATE — MySQL, TRUNCATE TABLE, DDL, InnoDB, 性能调优, SRE
- MySQL 8.0 与总结 — MySQL, 8.0, Atomic DDL, AliSQL, 参考, 性能调优

## Repository Paths

- PDF: `collector/02fe4209332110a9ec9a5d79241dbaae.pdf`
- Extracted: `generated/extracted/02fe4209332110a9ec9a5d79241dbaae/full.md`
- Filtered: `generated/filtered/02fe4209332110a9ec9a5d79241dbaae/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
