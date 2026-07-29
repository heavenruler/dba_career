---
doc_id: "0c7834f8ba6b520d05f5d04933e9c78b"
title: "专栏 - TiDB 三中心\"脑裂\"场景探讨 | TiDB 社区"
aliases:
  - "专栏 - TiDB 三中心\"脑裂\"场景探讨 | TiDB 社区"
url: "https://tidb.net/blog/07b42ec0"
source_domain: "tidb.net"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "TiDB"
  - "三中心架构"
  - "脑裂"
  - "高可用"
  - "Raft"
  - "容灾"
  - "故障分析"
  - "参数调优"
generated: true
---

# 专栏 - TiDB 三中心"脑裂"场景探讨 | TiDB 社区

> [!info] Provenance
> - doc_id: `0c7834f8ba6b520d05f5d04933e9c78b`
> - source_kind: `llm_filtered`
> - source: [original URL](https://tidb.net/blog/07b42ec0)
> - PDF: [open local PDF](../../collector/0c7834f8ba6b520d05f5d04933e9c78b.pdf)

## Summary

本文分析 TiDB 三中心部署在不同网络断连下的可用性表现，逐步推演 A、B、C 机房之间的半断开与完全断开场景，并给出 raft-min-election-timeout-ticks / raft-max-election-timeout-ticks 的参数建议。

## Knowledge Outline

- 部署架构 — TiDB, 三中心架构, 高可用, 容灾
- 场景一 — TiDB, 脑裂, 网络分区, 可用性, Region Leader
- 场景二 — TiDB, 脑裂, 网络分区, 可用性, Region Leader
- 场景三与参数建议 — TiDB, 脑裂, SRE, 故障分析, Raft, 参数调优

## Repository Paths

- PDF: `collector/0c7834f8ba6b520d05f5d04933e9c78b.pdf`
- Extracted: `generated/extracted/0c7834f8ba6b520d05f5d04933e9c78b/full.md`
- Filtered: `generated/filtered/0c7834f8ba6b520d05f5d04933e9c78b/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
