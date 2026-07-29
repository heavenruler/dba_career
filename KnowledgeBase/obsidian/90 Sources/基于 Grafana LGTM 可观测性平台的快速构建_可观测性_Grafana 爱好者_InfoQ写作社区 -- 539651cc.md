---
doc_id: "539651cce16d117833dbb8af11c8046c"
title: "基于 Grafana LGTM 可观测性平台的快速构建_可观测性_Grafana 爱好者_InfoQ写作社区"
aliases:
  - "基于 Grafana LGTM 可观测性平台的快速构建_可观测性_Grafana 爱好者_InfoQ写作社区"
url: "https://xie.infoq.cn/article/a86a5daed44bc363abb392203"
source_domain: "xie.infoq.cn"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "Grafana"
  - "可观测性"
  - "Observability"
  - "Prometheus"
  - "OpenTelemetry"
  - "OTel Collector"
  - "Mimir"
  - "Loki"
  - "Tempo"
  - "Go"
  - "SRE"
  - "日志"
  - "Trace"
  - "指标"
  - "云原生"
generated: true
---

# 基于 Grafana LGTM 可观测性平台的快速构建_可观测性_Grafana 爱好者_InfoQ写作社区

> [!info] Provenance
> - doc_id: `539651cce16d117833dbb8af11c8046c`
> - source_kind: `llm_filtered`
> - source: [original URL](https://xie.infoq.cn/article/a86a5daed44bc363abb392203)
> - PDF: [open local PDF](../../collector/539651cce16d117833dbb8af11c8046c.pdf)

## Summary

这篇文章用一个 Go Web demo 说明如何用 Grafana LGTM 构建可观测性平台，核心内容覆盖指标、Trace、日志的埋点与导出，OTel Collector 的收集与转发配置，以及 Grafana/Mimir/Loki/Tempo 的统一查询链路。真正有价值的是 Prometheus exemplar 关联 TraceID、OTLP trace 导出、filelog 日志采集和整体部署流程。

## Knowledge Outline

- 可观测性与目标 — 可观测性, Grafana, Go, Prometheus, Trace, 日志, MySQL, Redis
- 样例部署与验证 — Grafana, Mimir, Loki, Tempo, 部署, docker-compose, wrk, 可观测性
- 指标导出 — Prometheus, Go, 指标, Exemplar, TraceID, Gin
- Trace 埋点与导出 — OpenTelemetry, OTLP, Trace, Go, MySQL, otel
- 结构化日志 — 日志, Zap, Go, TraceID, 结构化日志
- OTel Collector 收集指标与 Trace — OTel Collector, Prometheus, Mimir, Tempo, OTLP, metrics, traces, 配置
- OTel Collector Contrib 日志采集 — OTel Collector, Loki, 日志, filelog, 配置
- 总结 — 总结, 可观测性, Grafana, Prometheus, TraceID, 日志, 指标, Trace

## Repository Paths

- PDF: `collector/539651cce16d117833dbb8af11c8046c.pdf`
- Extracted: `generated/extracted/539651cce16d117833dbb8af11c8046c/full.md`
- Filtered: `generated/filtered/539651cce16d117833dbb8af11c8046c/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
