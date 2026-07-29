---
doc_id: "85a3ee4b98438113378489e6e8029f92"
title: "停从库,为啥主库报错[ERROR]mysqld:Got an error reading communication packe"
aliases:
  - "停从库,为啥主库报错[ERROR]mysqld:Got an error reading communication packe"
url: "https://mp.weixin.qq.com/s/MkiM1iuxur104jQMwYmojw"
source_domain: "mp.weixin.qq.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "半同步复制"
  - "主从复制"
  - "故障分析"
  - "日志"
  - "SRE"
generated: true
---

# 停从库,为啥主库报错[ERROR]mysqld:Got an error reading communication packe

> [!info] Provenance
> - doc_id: `85a3ee4b98438113378489e6e8029f92`
> - source_kind: `llm_filtered`
> - source: [original URL](https://mp.weixin.qq.com/s/MkiM1iuxur104jQMwYmojw)
> - PDF: [open local PDF](../../collector/85a3ee4b98438113378489e6e8029f92.pdf)

## Summary

本文分析了停止从库复制进程时，主库日志出现 `Got an error reading communication packets` 的原因。结论是该错误主要来自半同步复制插件输出，通常不影响业务；没有启用半同步时不会出现。

## Knowledge Outline

- 现象 — MySQL, 报错, 主从复制, 日志
- 分析 — MySQL, 错误分析, 日志, 连接断开
- 源码定位 — MySQL, 源码分析, ER_NET_READ_ERROR, 半同步复制
- 验证与处理 — MySQL, 半同步复制, 验证, 处理方法
- 堆栈说明 — MySQL, 堆栈, 错误日志, ack_receiver

## Repository Paths

- PDF: `collector/85a3ee4b98438113378489e6e8029f92.pdf`
- Extracted: `generated/extracted/85a3ee4b98438113378489e6e8029f92/full.md`
- Filtered: `generated/filtered/85a3ee4b98438113378489e6e8029f92/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
