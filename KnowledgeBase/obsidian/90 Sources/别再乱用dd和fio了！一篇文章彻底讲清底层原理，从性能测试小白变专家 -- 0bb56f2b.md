---
doc_id: "0bb56f2b4df816c6969b87d72ff5a89d"
title: "别再乱用dd和fio了！一篇文章彻底讲清底层原理，从性能测试小白变专家"
aliases:
  - "别再乱用dd和fio了！一篇文章彻底讲清底层原理，从性能测试小白变专家"
url: "https://mp.weixin.qq.com/s/ujpBrK-qs5AOowLAIp9o_g"
source_domain: "mp.weixin.qq.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "DBA"
  - "fio"
  - "dd"
  - "性能测试"
  - "Page Cache"
  - "IOPS"
  - "延迟调优"
  - "Linux"
generated: true
---

# 别再乱用dd和fio了！一篇文章彻底讲清底层原理，从性能测试小白变专家

> [!info] Provenance
> - doc_id: `0bb56f2b4df816c6969b87d72ff5a89d`
> - source_kind: `llm_filtered`
> - source: [original URL](https://mp.weixin.qq.com/s/ujpBrK-qs5AOowLAIp9o_g)
> - PDF: [open local PDF](../../collector/0bb56f2b4df816c6969b87d72ff5a89d.pdf)

## Summary

文章用 dd 与 fio 解释 I/O 压测的底层差异，重点讲 Page Cache、O_DIRECT、ioengine、iodepth、numjobs，以及如何用顺序/随机、读写混合负载去逼近数据库场景。

## Knowledge Outline

- dd 与 fio 的定位 — dd, fio, 性能测试, DBA, 存储
- dd 的底层原理 — dd, 系统调用, 吞吐, 性能测试, Linux
- dd、页缓存与 direct — dd, Page Cache, O_DIRECT, 存储, 性能测试
- dd 常用参数与场景 — dd, fio, 顺序读写, direct, fdatasync, 性能测试
- fio 的核心概念 — fio, job, ioengine, iodepth, numjobs, 随机I/O, 顺序I/O, O_DIRECT
- fio 实战与调优 — fio, 命令行, OLTP, 延迟分布, 调优, IOPS, 带宽

## Repository Paths

- PDF: `collector/0bb56f2b4df816c6969b87d72ff5a89d.pdf`
- Extracted: `generated/extracted/0bb56f2b4df816c6969b87d72ff5a89d/full.md`
- Filtered: `generated/filtered/0bb56f2b4df816c6969b87d72ff5a89d/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
