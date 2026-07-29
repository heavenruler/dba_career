---
doc_id: "87ba322240f941f18209b19f0c2c47c4"
title: "跨机房ADG因带宽限制引起的GAP问题"
aliases:
  - "跨机房ADG因带宽限制引起的GAP问题"
url: "https://mp.weixin.qq.com/s/9veGFs2VShoPFGBI2aM8_Q"
source_domain: "mp.weixin.qq.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "Oracle"
  - "ADG"
  - "Data Guard"
  - "RAC"
  - "FAL"
  - "GAP"
  - "性能调优"
  - "数据库运维"
  - "带宽限制"
generated: true
---

# 跨机房ADG因带宽限制引起的GAP问题

> [!info] Provenance
> - doc_id: `87ba322240f941f18209b19f0c2c47c4`
> - source_kind: `llm_filtered`
> - source: [original URL](https://mp.weixin.qq.com/s/9veGFs2VShoPFGBI2aM8_Q)
> - PDF: [open local PDF](../../collector/87ba322240f941f18209b19f0c2c47c4.pdf)

## Summary

本文记录了一个跨机房 Oracle ADG 在带宽受限下反复出现 GAP、FAL 恢复缓慢的案例。作者通过观察主备库 ARC 进程占用情况，推断 FAL 请求被 ARC 进程资源卡住，并通过把 log_archive_max_processes 从 4 调到 8，显著改善了 GAP 的自动恢复速度；同时也强调根因仍是跨机房带宽不足。

## Knowledge Outline

- 背景与现象 — Oracle, ADG, Data Guard, RAC, GAP, 带宽限制, 故障排查
- 进程观察 — Oracle, ADG, FAL, GAP, V$MANAGED_STANDBY, V$ARCHIVE_PROCESSES, 排障
- 调参与验证 — Oracle, ADG, FAL, GAP, 性能调优, 带宽限制, 验证
- 参数作用 — Oracle, 参数, Data Guard, FAL, GAP, RAC, 运行时调整
- 版本演进 — Oracle, 参数演进, Data Guard, RAC, 版本对比, 性能调优

## Repository Paths

- PDF: `collector/87ba322240f941f18209b19f0c2c47c4.pdf`
- Extracted: `generated/extracted/87ba322240f941f18209b19f0c2c47c4/full.md`
- Filtered: `generated/filtered/87ba322240f941f18209b19f0c2c47c4/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
