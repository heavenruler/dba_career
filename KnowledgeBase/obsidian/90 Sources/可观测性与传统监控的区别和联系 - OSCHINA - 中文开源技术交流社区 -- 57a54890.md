---
doc_id: "57a54890436038bbdcc3abcd130d9785"
title: "可观测性与传统监控的区别和联系 - OSCHINA - 中文开源技术交流社区"
aliases:
  - "可观测性与传统监控的区别和联系 - OSCHINA - 中文开源技术交流社区"
url: "https://my.oschina.net/morflameblog/blog/15316524"
source_domain: "my.oschina.net"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "可观测性"
  - "传统监控"
  - "Metrics"
  - "Logging"
  - "Tracing"
  - "OpenTelemetry"
  - "Prometheus"
  - "OnCall"
  - "SRE"
  - "DevOps"
  - "告警治理"
  - "事故响应"
  - "eBPF"
  - "Continuous Profiling"
generated: true
---

# 可观测性与传统监控的区别和联系 - OSCHINA - 中文开源技术交流社区

> [!info] Provenance
> - doc_id: `57a54890436038bbdcc3abcd130d9785`
> - source_kind: `llm_filtered`
> - source: [original URL](https://my.oschina.net/morflameblog/blog/15316524)
> - PDF: [open local PDF](../../collector/57a54890436038bbdcc3abcd130d9785.pdf)

## Summary

文章介绍可观测性的定义、传统监控的局限、监控工具演进、OpenTelemetry 与可观测平台，并重点讨论 OnCall 在告警治理、协同、度量改进中的作用，以及 Continuous Profiling、eBPF 等技术趋势。

## Knowledge Outline

- 可观测性定义 — 可观测性, Observability, 控制论
- 传统监控的局限 — 传统监控, 告警, Runbook, 故障复盘, 告警风暴
- 告警与用户体验 — 告警, 用户体验, 应急响应, 稳定性
- 外挂式监控问题 — 传统监控, Metrics, Tracing, 埋点, 运维
- Metrics 监控基础 — Metrics, 基础设施监控, 时序数据库, 告警工具
- 早期 Metrics 工具 — Cacti, Nagios, Ganglia, RRDtool, Collectd, StatsD, Graphite
- 互联网发展期监控 — Zabbix, Open-Falcon, 水平扩展, 监控系统
- 云原生监控工具 — Prometheus, Nightingale, CNCF, Kubernetes, Grafana
- 时序数据库代表 — 时序数据库, Prometheus, InfluxDB, TDengine, TimescaleDB, VictoriaMetrics, M3DB, Mimir
- 可观测性的特点 — 可观测性, Metrics, Logging, Tracing, Events, 埋点, 结构化数据
- 现代应用特点 — 云原生, 微服务, Application, 持续集成, 持续发布, 弹性伸缩
- OpenTelemetry — OpenTelemetry, OTel, traces, metrics, logs
- Flashcat 平台特点 — Flashcat, OpenTelemetry, Metrics, Logging, Tracing, Event, 混合云
- Flashcat 改善问题 — Flashcat, Prometheus, Zabbix, Grafana, ELK, Jaeger, OnCall
- OnCall 困扰 — OnCall, 告警治理, 协同, 应急响应, 知识沉淀
- OnCall 工具能力 — OnCall, 告警聚合, 告警生命周期, 排班, 故障管理, ChatOps
- OnCall 度量指标 — OnCall, 降噪比, 响应比, 告警总量, MTTA, MTTR, SLO
- OnCall 工具推荐 — PagerDuty, FlashDuty, OnCall
- 技术趋势 — Continuous Profiling, eBPF, Linux, 性能分析, 安全监控, 性能优化

## Repository Paths

- PDF: `collector/57a54890436038bbdcc3abcd130d9785.pdf`
- Extracted: `generated/extracted/57a54890436038bbdcc3abcd130d9785/full.md`
- Filtered: `generated/filtered/57a54890436038bbdcc3abcd130d9785/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
