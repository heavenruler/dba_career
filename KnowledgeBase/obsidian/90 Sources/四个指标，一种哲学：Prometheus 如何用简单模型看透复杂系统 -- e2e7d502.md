---
doc_id: "e2e7d502ae22489a42d7ab9073000d3f"
title: "四个指标，一种哲学：Prometheus 如何用简单模型看透复杂系统"
aliases:
  - "四个指标，一种哲学：Prometheus 如何用简单模型看透复杂系统"
url: "https://juejin.cn/post/7589146208225296420"
source_domain: "juejin.cn"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "Prometheus"
  - "可观测性"
  - "SRE"
  - "监控"
  - "PromQL"
  - "Histogram"
  - "指标设计"
  - "性能分析"
generated: true
---

# 四个指标，一种哲学：Prometheus 如何用简单模型看透复杂系统

> [!info] Provenance
> - doc_id: `e2e7d502ae22489a42d7ab9073000d3f`
> - source_kind: `llm_filtered`
> - source: [original URL](https://juejin.cn/post/7589146208225296420)
> - PDF: [open local PDF](../../collector/e2e7d502ae22489a42d7ab9073000d3f.pdf)

## Summary

本文围绕 Prometheus 的设计哲学、四种指标类型、Histogram 分布统计、PromQL 常见函数与生产实践展开，重点说明 Counter、Gauge、Histogram、Summary 的适用场景、权衡与常见误区。

## Knowledge Outline

- Prometheus 设计哲学 — Prometheus, 设计哲学
- 时间序列本质 — TSDB, 时间序列
- 抓取时间戳设计 — Exporter, TSDB, 监控架构
- 类型是软约束 — 指标类型, 存储引擎
- Counter 重置哲学 — Counter, 监控, 计费
- rate 处理重置 — PromQL, rate, Counter
- 四种指标本质 — Counter, Gauge, Histogram, Summary
- Counter 使用 — Counter, 指标设计
- Counter 常见错误 — Counter, PromQL, 告警
- Gauge 选择规则 — Gauge, Counter, 指标设计
- Gauge 预测 — Gauge, PromQL, 容量规划
- 平均值问题 — Histogram, 性能分析, 长尾延迟
- Histogram 结构 — Histogram, 指标结构
- Histogram 分位数 — Histogram, PromQL, 分位数
- Summary 限制 — Summary, Histogram, 分布统计
- Summary 不能聚合 — Summary, 聚合, 分位数
- 高基数风险 — Histogram, 高基数, 性能优化
- Bucket 设置原则 — Histogram, Bucket, 指标设计
- rate 与 irate — PromQL, rate, irate, 告警
- histogram_quantile 误区 — PromQL, histogram_quantile, Histogram

## Repository Paths

- PDF: `collector/e2e7d502ae22489a42d7ab9073000d3f.pdf`
- Extracted: `generated/extracted/e2e7d502ae22489a42d7ab9073000d3f/full.md`
- Filtered: `generated/filtered/e2e7d502ae22489a42d7ab9073000d3f/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
