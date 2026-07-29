---
doc_id: "c7fe39393f4a540c8962e2a8d7ef3ebe"
title: "MySQL数据库审计采集技术调研之Packetbeat，eBPF-阿里云开发者社区"
aliases:
  - "MySQL数据库审计采集技术调研之Packetbeat，eBPF-阿里云开发者社区"
url: "https://developer.aliyun.com/article/852651"
source_domain: "developer.aliyun.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "数据库审计"
  - "网络抓包"
  - "Packetbeat"
  - "eBPF"
  - "bcc"
  - "Pixie"
  - "可观测性"
  - "数据安全"
  - "网络协议"
generated: true
---

# MySQL数据库审计采集技术调研之Packetbeat，eBPF-阿里云开发者社区

> [!info] Provenance
> - doc_id: `c7fe39393f4a540c8962e2a8d7ef3ebe`
> - source_kind: `llm_filtered`
> - source: [original URL](https://developer.aliyun.com/article/852651)
> - PDF: [open local PDF](../../collector/c7fe39393f4a540c8962e2a8d7ef3ebe.pdf)

## Summary

本文调研 MySQL 数据库审计中的抓包采集方案，涵盖 MySQL 通信协议、网络抓包部署方式、Packetbeat 采集原理、libpcap/af_packet、eBPF/bcc/Pixie 在数据库查询与协议采集中的应用。

## Knowledge Outline

- 数据库审计抓包方案 — 数据库审计, MySQL, 网络协议, 数据安全
- MySQL通信协议 — MySQL, 通信协议
- 客户端到服务端命令协议 — MySQL, 协议格式, 命令协议
- MySQL命令列表 — MySQL, COM_QUERY, 数据库审计
- 服务端到客户端数据包 — MySQL, 数据包, Result Set Packet
- 网络抓包特点 — 数据库审计, 云数据库, 抓包
- 抓包部署方式 — 端口镜像, 代理部署, 服务端部署, 客户端部署
- 数据库性能影响 — 性能影响, 数据库审计
- Packetbeat方案 — Packetbeat, Beats, Kafka, ElasticSearch, Logstash
- Packetbeat部署方式 — Packetbeat, 部署方式, Tap
- Packetbeat采集原理 — Packetbeat, gopacket, pcap, afpacket
- libpcap — libpcap, BPF, tcpdump, wireshark
- af_packet — af_packet, PACKET_MMAP, mmap, Packetbeat
- Packetbeat采集数据 — Packetbeat, MySQL, SQL, 审计
- Logtail采集Beats配置 — Logtail, SLS, Lumberjack, Packetbeat, Logstash
- Packetbeat小结 — Packetbeat, 数据库审计
- eBPF方案 — eBPF, BPF, tracing, XDP, 可观测性
- eBPF虚拟机 — eBPF, 虚拟机, Map
- eBPF程序执行流程 — eBPF, LLVM, verifier, kprobes, uprobes, tracepoints, perf_events
- bcc — bcc, eBPF, Python, Lua
- bcc hello world — bcc, kprobes, sys_clone, eBPF
- 数据库慢查询跟踪示例 — dbslower, MySQL, PostgreSQL, 慢查询, eBPF
- dbslower源码分析 — dbslower, uprobe, uretprobe, dispatch_command, perf_output
- Pixie — Pixie, Kubernetes, eBPF, 可观测性, PxL
- Database query profiling — Pixie, SQL, 查询延迟, 吞吐量
- Stirling原理分析 — Stirling, Pixie, socket_tracer, kprobes, uprobes, MySQL
- Pixie kprobe配置片段 — Pixie, kprobe, socket_trace_connector, MySQL
- eBPF网络包处理类型 — eBPF, BPF_PROG_TYPE_KPROBE, BPF_PROG_TYPE_SOCKET_FILTER, BPF_PROG_TYPE_XDP, Pixie
- 总结 — 数据库审计, Packetbeat, eBPF, PF_RING, DPDK

## Repository Paths

- PDF: `collector/c7fe39393f4a540c8962e2a8d7ef3ebe.pdf`
- Extracted: `generated/extracted/c7fe39393f4a540c8962e2a8d7ef3ebe/full.md`
- Filtered: `generated/filtered/c7fe39393f4a540c8962e2a8d7ef3ebe/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
