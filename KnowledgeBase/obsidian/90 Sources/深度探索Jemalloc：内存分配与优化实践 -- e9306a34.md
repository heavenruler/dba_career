---
doc_id: "e9306a342d9b36289c228d0dadb76b0c"
title: "深度探索Jemalloc：内存分配与优化实践"
aliases:
  - "深度探索Jemalloc：内存分配与优化实践"
url: "https://mp.weixin.qq.com/s/PuQaqbCpFbtZQBloCEHCdA"
source_domain: "mp.weixin.qq.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "Jemalloc"
  - "内存分配"
  - "内存碎片"
  - "多线程"
  - "性能调优"
  - "MySQL"
  - "Redis"
  - "SRE"
generated: true
---

# 深度探索Jemalloc：内存分配与优化实践

> [!info] Provenance
> - doc_id: `e9306a342d9b36289c228d0dadb76b0c`
> - source_kind: `llm_filtered`
> - source: [original URL](https://mp.weixin.qq.com/s/PuQaqbCpFbtZQBloCEHCdA)
> - PDF: [open local PDF](../../collector/e9306a342d9b36289c228d0dadb76b0c.pdf)

## Summary

本文介绍 Jemalloc 的设计目标、内存分配机制、与 ptmalloc/tcmalloc 的差异，以及在 Web、MySQL 和大数据场景中的加载方式、参数调优和效果验证。

## Knowledge Outline

- Jemalloc 概览 — Jemalloc, 内存分配, 内存碎片, 多线程, Redis, Rust, Netty
- 内存分配原理 — Jemalloc, 堆, 栈, 内存碎片, extent, slab, buddy, tcache, arena, mmap
- 与 ptmalloc / tcmalloc 的对比 — Jemalloc, ptmalloc, tcmalloc, 多线程, 内存碎片, 性能对比
- 优化实践案例 — Jemalloc, 性能优化, Web应用, MySQL, Spark, Linux, 多线程
- 常见问题 — Jemalloc, 内存泄漏, 内存碎片, 兼容性, jeprof, MALLOC_CONF
- 配置建议 — Jemalloc, narenas, lg_chunk, lg_tcache_max, muzzy_decay_ms, dirty_decay_ms, 性能调优

## Repository Paths

- PDF: `collector/e9306a342d9b36289c228d0dadb76b0c.pdf`
- Extracted: `generated/extracted/e9306a342d9b36289c228d0dadb76b0c/full.md`
- Filtered: `generated/filtered/e9306a342d9b36289c228d0dadb76b0c/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
