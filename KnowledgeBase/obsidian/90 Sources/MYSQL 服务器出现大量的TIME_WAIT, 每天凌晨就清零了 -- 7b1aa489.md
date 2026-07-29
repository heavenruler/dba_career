---
doc_id: "7b1aa4898308cb8d02cd86501b2bc5ef"
title: "[MYSQL] 服务器出现大量的TIME_WAIT, 每天凌晨就清零了"
aliases:
  - "[MYSQL] 服务器出现大量的TIME_WAIT, 每天凌晨就清零了"
url: "https://mp.weixin.qq.com/s/UDEQxNGUmGcGrO1lwbZLgw"
source_domain: "mp.weixin.qq.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "TCP"
  - "TIME_WAIT"
  - "短连接"
  - "故障分析"
  - "事故覆盘"
  - "数据库运维"
generated: true
---

# [MYSQL] 服务器出现大量的TIME_WAIT, 每天凌晨就清零了

> [!info] Provenance
> - doc_id: `7b1aa4898308cb8d02cd86501b2bc5ef`
> - source_kind: `llm_filtered`
> - source: [original URL](https://mp.weixin.qq.com/s/UDEQxNGUmGcGrO1lwbZLgw)
> - PDF: [open local PDF](../../collector/7b1aa4898308cb8d02cd86501b2bc5ef.pdf)

## Summary

本文分析数据库服务器与应用服务器出现大量 TIME_WAIT 连接的原因，指出核心特征是应用大量使用短连接，并且每天凌晨应用重启导致 TIME_WAIT 清零。文章还给出用 `show global status like 'Connections';`、`show processlist;`、检查 MySQL error log、以及用 Python 脚本复现短连接的验证方法。

## Knowledge Outline

- 背景 — MySQL, TIME_WAIT, 短连接
- 状态分析 — MySQL, TIME_WAIT, TCP, 故障分析
- 日志与复现 — MySQL, TIME_WAIT, 复现, 排障
- 总结与脚本 — MySQL, TCP, 短连接, 脚本, 复现

## Repository Paths

- PDF: `collector/7b1aa4898308cb8d02cd86501b2bc5ef.pdf`
- Extracted: `generated/extracted/7b1aa4898308cb8d02cd86501b2bc5ef/full.md`
- Filtered: `generated/filtered/7b1aa4898308cb8d02cd86501b2bc5ef/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
