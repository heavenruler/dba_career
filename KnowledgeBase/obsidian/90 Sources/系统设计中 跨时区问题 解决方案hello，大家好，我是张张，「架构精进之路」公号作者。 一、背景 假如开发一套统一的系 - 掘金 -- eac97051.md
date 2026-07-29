---
doc_id: "eac970515cc6b06b1b335d2273c954fd"
title: "系统设计中 跨时区问题 解决方案hello，大家好，我是张张，「架构精进之路」公号作者。 一、背景 假如开发一套统一的系 - 掘金"
aliases:
  - "系统设计中 跨时区问题 解决方案hello，大家好，我是张张，「架构精进之路」公号作者。 一、背景 假如开发一套统一的系 - 掘金"
url: "https://juejin.cn/post/7362722064069869605"
source_domain: "juejin.cn"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "系统设计"
  - "时区"
  - "UTC"
  - "Linux"
  - "MySQL"
  - "前端时间"
  - "夏令时"
  - "数据库"
generated: true
---

# 系统设计中 跨时区问题 解决方案hello，大家好，我是张张，「架构精进之路」公号作者。 一、背景 假如开发一套统一的系 - 掘金

> [!info] Provenance
> - doc_id: `eac970515cc6b06b1b335d2273c954fd`
> - source_kind: `llm_filtered`
> - source: [original URL](https://juejin.cn/post/7362722064069869605)
> - PDF: [open local PDF](../../collector/eac970515cc6b06b1b335d2273c954fd.pdf)

## Summary

本文围绕跨时区系统设计，整理了时区、UTC/GMT、UNIX 时间戳等基础概念，说明 Linux 与 MySQL 的时区设置方式，并给出服务端统一使用 UTC、前端按需要格式化展示的处理原则，同时补充了夏令时与冬令时的背景。

## Knowledge Outline

- 时区与时间标准 — 时区, UTC, GMT, UNIX时间戳, 基础概念
- Linux 中设置时区 — Linux, 时区, 系统设置, 运维
- MySQL 中设置时区 — MySQL, 时区, 数据库配置, 运维
- 系统跨时区设计 — 系统设计, 跨时区, UTC, 前端, 后端, 数据库, 时间处理
- 夏令时与冬令时 — 夏令时, 冬令时, 时间制度, 时区

## Repository Paths

- PDF: `collector/eac970515cc6b06b1b335d2273c954fd.pdf`
- Extracted: `generated/extracted/eac970515cc6b06b1b335d2273c954fd/full.md`
- Filtered: `generated/filtered/eac970515cc6b06b1b335d2273c954fd/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
