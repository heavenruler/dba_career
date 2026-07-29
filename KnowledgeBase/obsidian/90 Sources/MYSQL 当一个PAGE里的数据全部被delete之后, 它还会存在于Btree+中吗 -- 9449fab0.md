---
doc_id: "9449fab062d488b9ec305b64000d070a"
title: "[MYSQL] 当一个PAGE里的数据全部被delete之后, 它还会存在于Btree+中吗?"
aliases:
  - "[MYSQL] 当一个PAGE里的数据全部被delete之后, 它还会存在于Btree+中吗?"
url: "https://mp.weixin.qq.com/s/W2tRd5JBPgjnADsciQ1k_Q"
source_domain: "mp.weixin.qq.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "InnoDB"
  - "B+Tree"
  - "delete_flag"
  - "ibd2sql"
  - "数据库"
  - "数据恢复"
generated: true
---

# [MYSQL] 当一个PAGE里的数据全部被delete之后, 它还会存在于Btree+中吗?

> [!info] Provenance
> - doc_id: `9449fab062d488b9ec305b64000d070a`
> - source_kind: `llm_filtered`
> - source: [original URL](https://mp.weixin.qq.com/s/W2tRd5JBPgjnADsciQ1k_Q)
> - PDF: [open local PDF](../../collector/9449fab062d488b9ec305b64000d070a.pdf)

## Summary

这篇文章验证了 InnoDB 中一个页的数据如果全部被 delete 之后，并不一定还会继续留在 B+Tree 结构里；在删除过程中，部分被 delete 标记的数据可能会转移到相邻 page，最终 parent 和 brother 节点都会移除该页信息。文末还提到 ibd2sql 遍历所有 page 并结合 --force 可以帮助恢复被删除标记的数据。

## Knowledge Outline

- 结论 — MySQL, InnoDB, B+Tree, delete_flag
- 测试数据与页分布 — MySQL, ibd2sql, SQL, Python, B+Tree
- 删除前的猜想 — MySQL, B+Tree, delete_flag, 数据结构
- 验证过程 — MySQL, B+Tree, page, Python, ibd2sql
- 结果与总结 — MySQL, ibd2sql, 数据恢复, delete_flag, B+Tree

## Repository Paths

- PDF: `collector/9449fab062d488b9ec305b64000d070a.pdf`
- Extracted: `generated/extracted/9449fab062d488b9ec305b64000d070a/full.md`
- Filtered: `generated/filtered/9449fab062d488b9ec305b64000d070a/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
