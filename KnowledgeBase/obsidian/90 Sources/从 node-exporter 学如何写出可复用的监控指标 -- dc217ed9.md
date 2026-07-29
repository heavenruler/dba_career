---
doc_id: "dc217ed91d85fc1b107058abbdc0600e"
title: "从 node-exporter 学如何写出可复用的监控指标"
aliases:
  - "从 node-exporter 学如何写出可复用的监控指标"
url: "https://juejin.cn/post/7589481566424596534"
source_domain: "juejin.cn"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "Prometheus"
  - "node-exporter"
  - "监控指标"
  - "可观测性"
  - "SRE"
  - "Exporter"
  - "Counter"
  - "Gauge"
  - "PromQL"
  - "架构设计"
generated: true
---

# 从 node-exporter 学如何写出可复用的监控指标

> [!info] Provenance
> - doc_id: `dc217ed91d85fc1b107058abbdc0600e`
> - source_kind: `llm_filtered`
> - source: [original URL](https://juejin.cn/post/7589481566424596534)
> - PDF: [open local PDF](../../collector/dc217ed91d85fc1b107058abbdc0600e.pdf)

## Summary

本文围绕 node-exporter 的监控指标设计，提炼 Prometheus Exporter 的核心原则：暴露事实而非观点、按指标本质选择 Counter/Gauge/Histogram、用 PromQL 组合视图、保持 Collector/Registry/HTTP 暴露的极简架构，并强调低基数标签与轻量被动采集。

## Knowledge Outline

- 设计哲学 — 监控指标, Prometheus, 设计原则
- USE 方法 — SRE, USE 方法, 可观测性
- CPU 指标 — CPU, Counter, node-exporter
- CPU PromQL — PromQL, CPU, rate
- Counter 适用性 — Counter, Prometheus, 指标类型
- 内存 Gauge — 内存, Gauge, node-exporter
- 内存场景 — PromQL, 内存, 告警, 容量规划
- 磁盘设计 — 磁盘, Gauge, Counter, IO
- 磁盘 PromQL — PromQL, 磁盘, 容量预测, IOPS
- 网络 Counter — 网络, Counter, node-exporter
- 网络 PromQL — PromQL, 网络, 错误率
- 指标类型映射 — 指标类型, Counter, Gauge, PromQL
- Collector 职责 — Collector, Exporter, 架构设计
- Registry 与暴露 — Registry, Prometheus, Exporter
- 三段式设计 — 架构设计, Exporter, Prometheus
- 通用规律 — Histogram, Summary, 指标类型
- 命名单位标签 — 命名规范, Prometheus, 指标设计
- 低基数标签 — 标签, 高基数, Prometheus
- Exporter 骨架 — Exporter, Go, Prometheus
- 性能哲学 — 性能优化, Exporter, Prometheus
- 被动采集 — 性能优化, scrape_interval, Exporter
- 三条黄金法则 — 设计原则, Counter, Gauge, 低基数标签
- 设计清单 — Exporter, 设计清单, 监控指标

## Repository Paths

- PDF: `collector/dc217ed91d85fc1b107058abbdc0600e.pdf`
- Extracted: `generated/extracted/dc217ed91d85fc1b107058abbdc0600e/full.md`
- Filtered: `generated/filtered/dc217ed91d85fc1b107058abbdc0600e/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
