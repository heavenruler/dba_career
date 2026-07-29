---
doc_id: "1ccd2bc3061d196cb93e40b4a3d8a197"
title: "真·Redis缓存优化—97%的优化率你见过嘛？ | 京东云技术团队本文通过一封618前的R2M(公司内部缓存组件，可以 - 掘金"
aliases:
  - "真·Redis缓存优化—97%的优化率你见过嘛？ | 京东云技术团队本文通过一封618前的R2M(公司内部缓存组件，可以 - 掘金"
url: "https://juejin.cn/post/7283150465525137468"
source_domain: "juejin.cn"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "Redis"
  - "缓存优化"
  - "事故排查"
  - "性能调优"
  - "架构设计"
  - "云计算"
  - "中间件选型"
  - "SRE"
generated: true
---

# 真·Redis缓存优化—97%的优化率你见过嘛？ | 京东云技术团队本文通过一封618前的R2M(公司内部缓存组件，可以 - 掘金

> [!info] Provenance
> - doc_id: `1ccd2bc3061d196cb93e40b4a3d8a197`
> - source_kind: `llm_filtered`
> - source: [original URL](https://juejin.cn/post/7283150465525137468)
> - PDF: [open local PDF](../../collector/1ccd2bc3061d196cb93e40b4a3d8a197.pdf)

## Summary

本文用一次 618 前的缓存告警，拆解了 R2M/Redis 内存占用过高的直接原因、根本原因与优化方案：一方面调整过期键的渐进式物理删除频率，另一方面把不必要的中间样本从缓存中移除、把结果分片迁移到 OSS 并在流程结束后清理，从而将缓存占用显著降下来。

## Knowledge Outline

- 告警背景 — Redis, 告警分析, 事故排查, 缓存容量
- 代码定位 — Redis, 代码分析, 缓存键设计, Java
- 告警原因 — Redis, 事故排查, 缓存占用, 根因分析
- 过期删除 — Redis, 过期键删除, 缓存淘汰, 渐进式删除
- 参数调整 — Redis, 参数调优, 运维, 缓存告警
- 根本优化 — Redis, 架构优化, OSS, 流程重构
- 优化结果与体会 — Redis, 优化率, 中间件选型, 学习方法, 总结

## Repository Paths

- PDF: `collector/1ccd2bc3061d196cb93e40b4a3d8a197.pdf`
- Extracted: `generated/extracted/1ccd2bc3061d196cb93e40b4a3d8a197/full.md`
- Filtered: `generated/filtered/1ccd2bc3061d196cb93e40b4a3d8a197/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
