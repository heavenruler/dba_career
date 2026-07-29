---
doc_id: "2331b3144809d3d7f9412ed9cd0d0341"
title: "暴揍ELK 痛打Loki - VictoriaLogs 搭建Syslog日志收集存储系统"
aliases:
  - "暴揍ELK 痛打Loki - VictoriaLogs 搭建Syslog日志收集存储系统"
url: "https://mp.weixin.qq.com/s/0ydkoQqkKq4Vu7yVqTwFpg"
source_domain: "mp.weixin.qq.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "VictoriaLogs"
  - "Syslog"
  - "日志收集"
  - "日志存储"
  - "Docker"
  - "docker compose"
  - "查询"
  - "监控"
  - "SRE"
generated: true
---

# 暴揍ELK 痛打Loki - VictoriaLogs 搭建Syslog日志收集存储系统

> [!info] Provenance
> - doc_id: `2331b3144809d3d7f9412ed9cd0d0341`
> - source_kind: `llm_filtered`
> - source: [original URL](https://mp.weixin.qq.com/s/0ydkoQqkKq4Vu7yVqTwFpg)
> - PDF: [open local PDF](../../collector/2331b3144809d3d7f9412ed9cd0d0341.pdf)

## Summary

本文围绕 VictoriaLogs 作为 syslog 日志收集与存储系统的部署、保留策略、Web 查询和监控展开，重点对比了它与 Elasticsearch / Grafana Loki 的资源占用与功能取舍，并给出 Docker 与 docker compose 的落地示例。

## Knowledge Outline

- 选择 VictoriaLogs — VictoriaLogs, Elasticsearch, Grafana Loki, 日志系统, 资源效率, 查询
- Docker 部署 — VictoriaLogs, Docker, Syslog, 部署, 端口, UDP
- Compose 部署 — VictoriaLogs, docker compose, Docker, 升级, 部署
- 保留时间 — VictoriaLogs, 保留策略, retentionPeriod, 日志保留, 配置
- Web 查询 — VictoriaLogs, Web UI, 查询, LogSQL, 搜索
- 监控指标 — VictoriaLogs, Prometheus, metrics, 监控, 可观测性

## Repository Paths

- PDF: `collector/2331b3144809d3d7f9412ed9cd0d0341.pdf`
- Extracted: `generated/extracted/2331b3144809d3d7f9412ed9cd0d0341/full.md`
- Filtered: `generated/filtered/2331b3144809d3d7f9412ed9cd0d0341/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
