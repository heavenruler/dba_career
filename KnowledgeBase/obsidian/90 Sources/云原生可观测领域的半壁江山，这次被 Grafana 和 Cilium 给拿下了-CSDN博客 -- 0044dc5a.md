---
doc_id: "0044dc5ad4496e51b7de50f10b0273fa"
title: "云原生可观测领域的半壁江山，这次被 Grafana 和 Cilium 给拿下了-CSDN博客"
aliases:
  - "云原生可观测领域的半壁江山，这次被 Grafana 和 Cilium 给拿下了-CSDN博客"
url: "https://blog.csdn.net/alex_yangchuansheng/article/details/128681290"
source_domain: "blog.csdn.net"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "云原生"
  - "Kubernetes"
  - "可观测性"
  - "Grafana"
  - "Cilium"
  - "eBPF"
  - "SRE"
  - "DevOps"
  - "网络"
  - "分布式追踪"
  - "故障排查"
generated: true
---

# 云原生可观测领域的半壁江山，这次被 Grafana 和 Cilium 给拿下了-CSDN博客

> [!info] Provenance
> - doc_id: `0044dc5ad4496e51b7de50f10b0273fa`
> - source_kind: `llm_filtered`
> - source: [original URL](https://blog.csdn.net/alex_yangchuansheng/article/details/128681290)
> - PDF: [open local PDF](../../collector/0044dc5ad4496e51b7de50f10b0273fa.pdf)

## Summary

本文讨论云原生应用连接可观测性的挑战，包括网络分层导致的责任归因困难、动态工作负载身份导致的信噪比问题，并说明传统方案的不足。文章介绍基于 eBPF 与 Cilium 的可观测性方案，以及结合 Grafana LGTM 全家桶观测 HTTP 黄金信号、TCP 黄金信号和分布式追踪 exemplars 的示例。

## Knowledge Outline

- 背景与目标 — Grafana, Cilium, Kubernetes, 可观测性, eBPF
- 应用连接可观测性 — 云原生, Kubernetes, 微服务, 故障排查
- 分层连接挑战 — OSI, 网络, 可观测性, 故障归因
- 应用身份挑战 — Kubernetes, 服务身份, label, DNS, 可观测性
- 传统方案不足 — 网络监控, VPC Flow Logs, Linux, Service Mesh, Istio
- eBPF 与 Cilium — eBPF, Cilium, Linux Kernel, CNI, LGTM
- HTTP 黄金信号 — HTTP Golden Signals, Grafana, Cilium, API, 故障排查
- TCP 黄金信号 — TCP, RTT, 重传, 网络层, Grafana, 故障排查
- 分布式追踪与 Exemplars — 分布式追踪, HTTP Header, Grafana, Tempo, exemplars
- 未来规划 — Grafana Cloud, Cilium Tetragon, 运行时安全, 威胁检测, 合规

## Repository Paths

- PDF: `collector/0044dc5ad4496e51b7de50f10b0273fa.pdf`
- Extracted: `generated/extracted/0044dc5ad4496e51b7de50f10b0273fa/full.md`
- Filtered: `generated/filtered/0044dc5ad4496e51b7de50f10b0273fa/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
