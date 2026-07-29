---
doc_id: "77e2359b6ffe175ae1fe9d40cb96f4b7"
title: "妙啊！ 不改一行代码，如何做到Redis毫秒级大key发现不改一行代码！如何做到Redis毫秒级大key发现？ eBPF - 掘金"
aliases:
  - "妙啊！ 不改一行代码，如何做到Redis毫秒级大key发现不改一行代码！如何做到Redis毫秒级大key发现？ eBPF - 掘金"
url: "https://juejin.cn/post/7416902555187216435"
source_domain: "juejin.cn"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "Redis"
  - "eBPF"
  - "uprobe"
  - "大key治理"
  - "可观测性"
  - "性能调优"
  - "SRE"
  - "Linux"
generated: true
---

# 妙啊！ 不改一行代码，如何做到Redis毫秒级大key发现不改一行代码！如何做到Redis毫秒级大key发现？ eBPF - 掘金

> [!info] Provenance
> - doc_id: `77e2359b6ffe175ae1fe9d40cb96f4b7`
> - source_kind: `llm_filtered`
> - source: [original URL](https://juejin.cn/post/7416902555187216435)
> - PDF: [open local PDF](../../collector/77e2359b6ffe175ae1fe9d40cb96f4b7.pdf)

## Summary

本文介绍使用 eBPF uprobe 无侵入实时发现 Redis 大 key 的方案，包含大 key 危害、传统方案缺陷、采集客户端 IP/命令参数/响应字节数的方法、初版实现、性能问题分析与第二版优化。

## Knowledge Outline

- Redis 大 Key 危害 — Redis, 大key治理
- 传统发现方案问题 — Redis, RDB, 可观测性
- eBPF 與 Uprobe — eBPF, Linux, uprobe
- eBPF 程序結構 — eBPF, uprobe, 架构设计
- 要采集的关键信息 — Redis, 慢日志, 可观测性
- 客户端 IP 获取位置 — Redis, eBPF, Linux, socket
- 命令参数获取 — Redis, 源码分析
- 响应字节数原理 — Redis, 源码分析, 性能调优
- Redis Get 响应调用链 — Redis, RESP, 源码分析
- 初版采集方案 — eBPF, uprobe, Redis
- call_entry 代码 — eBPF, C, uprobe
- 累加响应字节代码 — eBPF, C, Redis
- call_exit 代码 — eBPF, C, uretprobe
- 用户空间处理流程 — Go, eBPF, cilium-ebpf
- 效果验证 — Redis, eBPF, 测试验证, kyanos
- 初版性能问题 — Redis, 性能调优, redis-benchmark
- Uprobe 开销原因 — uprobe, eBPF, 性能调优
- 第二版优化思路 — Redis, eBPF, 性能优化
- 第二版 call_entry — eBPF, C, 性能优化
- 第二版 call_exit — eBPF, C, Redis
- 优化后性能比较 — 性能调优, redis-benchmark, bpftime
- 结语 — Redis, eBPF, uprobe

## Repository Paths

- PDF: `collector/77e2359b6ffe175ae1fe9d40cb96f4b7.pdf`
- Extracted: `generated/extracted/77e2359b6ffe175ae1fe9d40cb96f4b7/full.md`
- Filtered: `generated/filtered/77e2359b6ffe175ae1fe9d40cb96f4b7/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
