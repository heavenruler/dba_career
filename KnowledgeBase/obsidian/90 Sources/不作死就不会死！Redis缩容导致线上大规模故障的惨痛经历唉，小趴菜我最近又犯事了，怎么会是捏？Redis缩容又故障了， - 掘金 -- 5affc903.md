---
doc_id: "5affc9038bdd2ecfa79730a7fcdcad38"
title: "不作死就不会死！Redis缩容导致线上大规模故障的惨痛经历唉，小趴菜我最近又犯事了，怎么会是捏？Redis缩容又故障了， - 掘金"
aliases:
  - "不作死就不会死！Redis缩容导致线上大规模故障的惨痛经历唉，小趴菜我最近又犯事了，怎么会是捏？Redis缩容又故障了， - 掘金"
url: "https://juejin.cn/post/7409333772967526426"
source_domain: "juejin.cn"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "Redis"
  - "事故复盘"
  - "SRE"
  - "运维"
  - "Lettuce"
  - "集群拓扑"
  - "性能调优"
  - "故障排查"
generated: true
---

# 不作死就不会死！Redis缩容导致线上大规模故障的惨痛经历唉，小趴菜我最近又犯事了，怎么会是捏？Redis缩容又故障了， - 掘金

> [!info] Provenance
> - doc_id: `5affc9038bdd2ecfa79730a7fcdcad38`
> - source_kind: `llm_filtered`
> - source: [original URL](https://juejin.cn/post/7409333772967526426)
> - PDF: [open local PDF](../../collector/5affc9038bdd2ecfa79730a7fcdcad38.pdf)

## Summary

一篇 Redis 缩容事故复盘，核心信息是：手动重启与手动加节点破坏了集群迁移和下线流程，导致 slot 归属不一致、handshake 节点残留，以及 Lettuce 频繁刷新拓扑引发的 999 线升高。文章还总结了节点下线必须在 1 分钟内完成 cluster forget、线上不要做黑屏操作等经验。

## Knowledge Outline

- 故障经过 — Redis, 事故复盘, 故障时间线
- 第一次故障 — Redis, 超时, 99线, 999线, 故障复盘
- 第二次故障与 slot 异常 — Redis, MOVED, slot迁移, cluster nodes, cluster setslot, Lettuce
- slot 迁移流程与 handshake 节点 — Redis, slot迁移, handshake, cluster forget, 集群拓扑
- 999 线升高的原因 — Redis, 999线, Lettuce, cluster nodes, handshake, 性能问题
- 经验总结 — Redis, 经验总结, 生产事故, 运维规范

## Repository Paths

- PDF: `collector/5affc9038bdd2ecfa79730a7fcdcad38.pdf`
- Extracted: `generated/extracted/5affc9038bdd2ecfa79730a7fcdcad38/full.md`
- Filtered: `generated/filtered/5affc9038bdd2ecfa79730a7fcdcad38/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
