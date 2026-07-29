---
doc_id: "2434111e62fe5a91f5e4ce60efc1ff6c"
title: "【redis】redis压力测试工具-----redis-benchmark-CSDN博客"
aliases:
  - "【redis】redis压力测试工具-----redis-benchmark-CSDN博客"
url: "https://blog.csdn.net/bandaoyu/article/details/103143475"
source_domain: "blog.csdn.net"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "Redis"
  - "redis-benchmark"
  - "性能测试"
  - "压力测试"
  - "数据库"
  - "SRE"
  - "DevOps"
  - "性能调优"
  - "基准测试"
generated: true
---

# 【redis】redis压力测试工具-----redis-benchmark-CSDN博客

> [!info] Provenance
> - doc_id: `2434111e62fe5a91f5e4ce60efc1ff6c`
> - source_kind: `llm_filtered`
> - source: [original URL](https://blog.csdn.net/bandaoyu/article/details/103143475)
> - PDF: [open local PDF](../../collector/2434111e62fe5a91f5e4ce60efc1ff6c.pdf)

## Summary

本文介绍 Redis 自带压测工具 redis-benchmark 的常用参数、典型压测命令、pipelining 测试、基准测试误区、影响 Redis 性能的因素，以及不同硬件/云主机环境下的测试结果。

## Knowledge Outline

- redis-benchmark 基本用法 — Redis, redis-benchmark, 压力测试
- GET 压测示例 — Redis, GET, 性能测试
- SET 压测示例 — Redis, SET, 性能测试
- 安静模式输出 — Redis, redis-benchmark, q 参数
- 测试命令事例 — Redis, 命令参数, 性能测试
- 只运行测试子集 — Redis, t 参数, 基准测试
- 选择测试键范围 — Redis, r 参数, 缓存命中率
- 随机键参数说明 — Redis, r 参数, keyspace
- Pipelining 参数 — Redis, pipelining, P 参数, keepalive
- 基准测试误区 — Redis, 基准测试, 性能测试误区
- redis-benchmark 吞吐量说明 — Redis, pipelining, 吞吐量
- 影响 Redis 性能的因素 — Redis, 性能调优, 网络, CPU, 内存
- 虚拟化与连接方式 — Redis, 虚拟化, unix socket, TCP, pipelining
- NUMA 与连接数 — Redis, NUMA, taskset, numactl, 连接数
- NIC 与内存分配 — Redis, NIC, RPS, Jumbo frames, 内存分配
- 可重现测试实践 — Redis, 基准测试, 可重现性, RDB, AOF
- 云主机与物理机测试设置 — Redis, 云主机, 物理机, 基准测试
- Xeon E5520 测试结果 — Redis, Xeon, pipelining, 基准测试结果
- Linode 测试结果 — Redis, Linode, pipelining, 基准测试结果
- 更多 pipeline 测试 — Redis, pipeline, 包大小, 客户端数
- 不同 CPU 测试结果 — Redis, CPU, Linux, 基准测试结果
- 高性能硬件测试环境 — Redis, 高性能硬件, Linux, CPU
- Unix Socket 与 TCP Loopback — Redis, unix domain socket, TCP loopback, numactl

## Repository Paths

- PDF: `collector/2434111e62fe5a91f5e4ce60efc1ff6c.pdf`
- Extracted: `generated/extracted/2434111e62fe5a91f5e4ce60efc1ff6c/full.md`
- Filtered: `generated/filtered/2434111e62fe5a91f5e4ce60efc1ff6c/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
