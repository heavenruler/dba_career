---
doc_id: "97dffaf7176f45379b87d01e34d47765"
title: "MemFree 辣么大，为啥报 out of memory？"
aliases:
  - "MemFree 辣么大，为啥报 out of memory？"
url: "https://mp.weixin.qq.com/s/Rr1Gk6Gto6WVOA9s6_ab6w"
source_domain: "mp.weixin.qq.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "OceanBase"
  - "Linux"
  - "内存管理"
  - "Docker"
  - "故障排查"
  - "SRE"
generated: true
---

# MemFree 辣么大，为啥报 out of memory？

> [!info] Provenance
> - doc_id: `97dffaf7176f45379b87d01e34d47765`
> - source_kind: `llm_filtered`
> - source: [original URL](https://mp.weixin.qq.com/s/Rr1Gk6Gto6WVOA9s6_ab6w)
> - PDF: [open local PDF](../../collector/97dffaf7176f45379b87d01e34d47765.pdf)

## Summary

本文排查了容器执行 `docker exec` 时出现 `out of memory` 的原因：主机 `MemFree` 看起来充足，但 `MemAvailable` 为 0，最终定位到 `vm.min_free_kbytes` 设置过高，导致可用内存被水位线吃掉，给出临时和永久调整方案。

## Knowledge Outline

- 报错现象 — OceanBase, Docker, 故障排查
- 资源与日志检查 — Docker, 日志, 故障排查
- meminfo 分析 — Linux, 内存管理, 系统分析
- 水位线与修复 — Linux, 内存管理, OceanBase, 故障排查

## Repository Paths

- PDF: `collector/97dffaf7176f45379b87d01e34d47765.pdf`
- Extracted: `generated/extracted/97dffaf7176f45379b87d01e34d47765/full.md`
- Filtered: `generated/filtered/97dffaf7176f45379b87d01e34d47765/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
