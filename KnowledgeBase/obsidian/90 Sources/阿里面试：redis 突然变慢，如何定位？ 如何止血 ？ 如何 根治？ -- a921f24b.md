---
doc_id: "a921f24b9133afc247ffb8b7924bd74b"
title: "阿里面试：redis 突然变慢，如何定位？ 如何止血 ？ 如何 根治？"
aliases:
  - "阿里面试：redis 突然变慢，如何定位？ 如何止血 ？ 如何 根治？"
url: "https://mp.weixin.qq.com/s/AfqN9TJniilePMyec_-98w"
source_domain: "mp.weixin.qq.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "Redis"
  - "DBA"
  - "性能调优"
  - "SRE"
  - "DevOps"
  - "故障排查"
  - "事故止血"
  - "架构设计"
  - "面试"
generated: true
---

# 阿里面试：redis 突然变慢，如何定位？ 如何止血 ？ 如何 根治？

> [!info] Provenance
> - doc_id: `a921f24b9133afc247ffb8b7924bd74b`
> - source_kind: `llm_filtered`
> - source: [original URL](https://mp.weixin.qq.com/s/AfqN9TJniilePMyec_-98w)
> - PDF: [open local PDF](../../collector/a921f24b9133afc247ffb8b7924bd74b.pdf)

## Summary

本文整理 Redis 突然变慢的定位、止血、降级、性能优化与架构治理方案，涵盖慢日志、BigKey、Key 集中过期、fork、AOF、内存淘汰、THP、Swap、内存碎片、CPU 绑定和监控治理。

## Knowledge Outline

- Redis 变慢影响 — Redis, 性能调优, 故障排查
- 五步闭环 — Redis, 故障处理, 架构治理
- 链路追踪定位 — 链路追踪, Redis, 故障定位
- 基准性能测试 — Redis, 基准测试, 延迟
- 延迟采样判断 — Redis, 延迟, 基准测试
- 慢日志作用 — Redis, Slow Log, 性能诊断
- 慢日志配置 — Redis, Slow Log, 配置
- 慢日志实践 — Redis, Slow Log, 监控
- BigKey 识别 — Redis, BigKey, 性能瓶颈
- BigKey 影响 — Redis, BigKey, 风险
- BigKey 扫描 — Redis, BigKey, 扫描
- BigKey 优化 — Redis, BigKey, 优化
- 慢查询堆积 — Redis, 慢查询, 复杂度
- 复杂命令解决 — Redis, 高危命令, 性能调优
- Key 集中过期 — Redis, Key过期, 延迟
- 主动过期机制 — Redis, Key过期, 主线程
- 集中过期优化 — Redis, Key过期, 优化
- Lazy Free 过期 — Redis, lazy-free, Key过期
- 过期监控 — Redis, 监控, Key过期
- Fork 触发场景 — Redis, fork, 持久化
- Fork 耗时原因 — Redis, fork, 性能瓶颈
- Fork 指标 — Redis, fork, 监控
- Fork 优化 — Redis, fork, 优化
- AOF 机制 — Redis, AOF, 持久化
- AOF 刷盘策略 — Redis, AOF, 磁盘IO
- AOF 优化 — Redis, AOF, 配置
- 内存上限变慢 — Redis, maxmemory, 内存淘汰
- 内存淘汰机制 — Redis, LRU, 内存淘汰
- 内存上限优化 — Redis, 内存淘汰, 优化
- Lazy Free 淘汰 — Redis, lazy-free, 内存淘汰
- 内存大页风险 — Redis, THP, Linux, 性能调优
- COW 开销 — Redis, Copy On Write, THP
- 关闭 THP — Redis, THP, Linux
- Swap 风险 — Redis, Swap, Linux, 性能灾难
- Swap 检查 — Redis, Swap, 排查
- Swap 预防 — Redis, Swap, 容量规划
- 内存碎片 — Redis, 内存碎片, 性能调优
- 碎片率查看 — Redis, 内存碎片, 监控
- 自动碎片整理 — Redis, activedefrag, 配置
- CPU 绑定风险 — Redis, CPU绑定, 性能调优
- CPU 绑定配置 — Redis, CPU绑定, Redis 6.0
- 降级方案 — Redis, 降级, 熔断限流
- 性能爆破 — Redis, 高并发, 性能优化
- 架构根治 — Redis, 架构治理, Redis Cluster
- 高可用升级 — Redis, 高可用, 分层存储
- 监控规则 — Redis, Prometheus, 监控告警
- 治理制度 — Redis, 开发规约, 巡检, 混沌工程

## Repository Paths

- PDF: `collector/a921f24b9133afc247ffb8b7924bd74b.pdf`
- Extracted: `generated/extracted/a921f24b9133afc247ffb8b7924bd74b/full.md`
- Filtered: `generated/filtered/a921f24b9133afc247ffb8b7924bd74b/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
