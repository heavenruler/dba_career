---
doc_id: "7d340f3f760b1d950f29747526397cbd"
title: "基于Prometheus、Thanos与Grafana的监控体系详解说明： Grafana通过Thanos Query从 - 掘金"
aliases:
  - "基于Prometheus、Thanos与Grafana的监控体系详解说明： Grafana通过Thanos Query从 - 掘金"
url: "https://juejin.cn/post/7416562712023334966"
source_domain: "juejin.cn"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "Prometheus"
  - "Thanos"
  - "Grafana"
  - "Kubernetes"
  - "可观测性"
  - "监控"
  - "SRE"
  - "DevOps"
  - "高可用"
  - "TSDB"
  - "WAL"
  - "服务发现"
generated: true
---

# 基于Prometheus、Thanos与Grafana的监控体系详解说明： Grafana通过Thanos Query从 - 掘金

> [!info] Provenance
> - doc_id: `7d340f3f760b1d950f29747526397cbd`
> - source_kind: `llm_filtered`
> - source: [original URL](https://juejin.cn/post/7416562712023334966)
> - PDF: [open local PDF](../../collector/7d340f3f760b1d950f29747526397cbd.pdf)

## Summary

本文介绍基于 Prometheus、Thanos 与 Grafana 的监控体系，包括 Prometheus 抓取、存储、服务发现、高可用、分片、WAL，Thanos Sidecar、Querier、对象存储、降采样，以及 Grafana 可视化与告警和生产环境部署要点。

## Knowledge Outline

- 监控体系概述 — Prometheus, Thanos, Grafana, 监控架构
- 架构示意 — Prometheus, Thanos, Grafana, 架构图
- 监控方案组成 — Prometheus, Thanos, Grafana, 可观测性
- Prometheus 数据抓取 — Prometheus, TSDB, PromQL, 服务发现
- Prometheus 架构组成 — Prometheus, Alertmanager, Pushgateway
- Prometheus 高可用 — Prometheus, Thanos, 高可用, 去重
- Prometheus 分片 — Prometheus, 分片, prometheus.yml
- Hashmod 分片 — Prometheus, Hashmod, 服务发现
- 规则配置位置 — Prometheus, Thanos, 告警规则, Recording Rules
- 存储策略 — Prometheus, Thanos, 存储, 对象存储
- 查询效率策略 — Prometheus, Thanos, 查询优化, 降采样
- Kubernetes 服务发现 — Prometheus, Kubernetes, 服务发现
- Endpoints 发现 — Prometheus, Kubernetes, Endpoints
- 服务发现底层原理 — Prometheus, Kubernetes, Informer, 服务发现
- Prometheus 部署结构 — Prometheus, 部署, WAL, TSDB
- WAL 原理 — Prometheus, WAL, TSDB, 数据一致性
- Thanos 架构组成 — Thanos, Sidecar, Store API, Querier
- Thanos 优化策略 — Thanos, 降采样, 对象存储
- Grafana 作用 — Grafana, Prometheus, Thanos, 告警
- Grafana 关键功能 — Grafana, 仪表盘, 告警
- 生产环境 Prometheus 部署 — Prometheus, 生产环境, 持久化存储
- 生产环境 Thanos 部署 — Thanos, Sidecar, Querier, Store Gateway
- 生产环境 Grafana 配置 — Grafana, 数据源, 告警规则
- Prometheus 底层实现 — Prometheus, WAL, TSDB, 数据恢复
- Thanos 底层实现 — Thanos, gRPC, 对象存储, Sidecar
- 结论 — Prometheus, Thanos, Grafana, 可观测性

## Repository Paths

- PDF: `collector/7d340f3f760b1d950f29747526397cbd.pdf`
- Extracted: `generated/extracted/7d340f3f760b1d950f29747526397cbd/full.md`
- Filtered: `generated/filtered/7d340f3f760b1d950f29747526397cbd/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
