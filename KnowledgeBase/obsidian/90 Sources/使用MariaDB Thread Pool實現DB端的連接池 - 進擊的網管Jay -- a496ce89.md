---
doc_id: "a496ce8991961e0a30a98cdcb608319d"
title: "使用MariaDB Thread Pool實現DB端的連接池 - 進擊的網管Jay"
aliases:
  - "使用MariaDB Thread Pool實現DB端的連接池 - 進擊的網管Jay"
url: "https://www.sre-devops.info/mariadb-thread-pool/"
source_domain: "www.sre-devops.info"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MariaDB"
  - "DBA"
  - "SRE"
  - "效能調優"
  - "連接池"
  - "Thread Pool"
generated: true
---

# 使用MariaDB Thread Pool實現DB端的連接池 - 進擊的網管Jay

> [!info] Provenance
> - doc_id: `a496ce8991961e0a30a98cdcb608319d`
> - source_kind: `llm_filtered`
> - source: [original URL](https://www.sre-devops.info/mariadb-thread-pool/)
> - PDF: [open local PDF](../../collector/a496ce8991961e0a30a98cdcb608319d.pdf)

## Summary

介紹 MariaDB 5.5 之後的 Thread Pool，對比 one-thread-per-connection 與 connection pool，說明其在高併發與短連接情境下如何減少 thread 建立與 context-switch。

## Knowledge Outline

- 背景與選型 — MariaDB, DBA, 架構設計, 連接池
- 單連線單執行緒 — MariaDB, 效能調優, 高併發
- Thread Pool — MariaDB, Thread Pool, 效能調優, SRE
- 模式對照 — MariaDB, 比較表, 效能調優
- Connection Pool 對照 — Connection Pool, Thread Pool, MariaDB

## Repository Paths

- PDF: `collector/a496ce8991961e0a30a98cdcb608319d.pdf`
- Extracted: `generated/extracted/a496ce8991961e0a30a98cdcb608319d/full.md`
- Filtered: `generated/filtered/a496ce8991961e0a30a98cdcb608319d/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
