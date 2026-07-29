---
doc_id: "8b115a54671c59a18b925c410d4f2566"
title: "mysql 信号量与进程状态"
aliases:
  - "mysql 信号量与进程状态"
url: "https://www.modb.pro/db/2018623074968084480"
source_domain: "www.modb.pro"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "Linux"
  - "signal"
  - "进程状态"
  - "cgroup"
  - "DBA"
  - "SRE"
generated: true
---

# mysql 信号量与进程状态

> [!info] Provenance
> - doc_id: `8b115a54671c59a18b925c410d4f2566`
> - source_kind: `llm_filtered`
> - source: [original URL](https://www.modb.pro/db/2018623074968084480)
> - PDF: [open local PDF](../../collector/8b115a54671c59a18b925c410d4f2566.pdf)

## Summary

本文整理了 MySQL 对 UNIX 信号的响应、SIGUSR2 触发重启的机制，以及 Linux 进程状态 D/R/S/T/t/zombie 的含义，并结合 cgroup 与信号做了实验验证。

## Knowledge Outline

- MySQL 信号响应 — MySQL, signal, 运维, 进程管理
- SIGUSR2 重启机制 — MySQL, shell, restart, mysqld_safe
- 进程状态与 cgroup — Linux, 进程状态, cgroup, SRE
- D/T 状态实验与总结 — Linux, MySQL, cgroup, 进程状态, 事故复盘, SRE, DBA

## Repository Paths

- PDF: `collector/8b115a54671c59a18b925c410d4f2566.pdf`
- Extracted: `generated/extracted/8b115a54671c59a18b925c410d4f2566/full.md`
- Filtered: `generated/filtered/8b115a54671c59a18b925c410d4f2566/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
