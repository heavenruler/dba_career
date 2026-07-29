---
doc_id: "618c058a407fb5679ebedda83f6a9e02"
title: "高并发linux内核参数调优 - 知无不言~ - 博客园"
aliases:
  - "高并发linux内核参数调优 - 知无不言~ - 博客园"
url: "https://www.cnblogs.com/louwj/p/17162891.html"
source_domain: "www.cnblogs.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "Linux"
  - "TCP"
  - "sysctl"
  - "高并发"
  - "NGINX"
  - "LVS"
  - "conntrack"
  - "kernel"
  - "VM"
  - "fs"
generated: true
---

# 高并发linux内核参数调优 - 知无不言~ - 博客园

> [!info] Provenance
> - doc_id: `618c058a407fb5679ebedda83f6a9e02`
> - source_kind: `llm_filtered`
> - source: [original URL](https://www.cnblogs.com/louwj/p/17162891.html)
> - PDF: [open local PDF](../../collector/618c058a407fb5679ebedda83f6a9e02.pdf)

## Summary

本文整理了高并发场景下 Linux 内核与网络参数调优项，重点覆盖 TCP 连接、conntrack、监听队列、网卡缓冲、kernel/vm/fs 配置，以及 NGINX 代理和临时端口相关设置。

## Knowledge Outline

- TCP 连接参数 — Linux, TCP, sysctl, 高并发
- Conntrack 与缓冲区 — Linux, TCP, conntrack, sysctl
- 薄流、队列与网卡卸载 — Linux, LVS, 网卡, TCP
- Kernel / VM — Linux, kernel, VM, sysctl
- FS 限制 — Linux, fs, inotify, file descriptor
- Backlog 與 FD — Linux, NGINX, somaxconn, file descriptor, ephemeral ports

## Repository Paths

- PDF: `collector/618c058a407fb5679ebedda83f6a9e02.pdf`
- Extracted: `generated/extracted/618c058a407fb5679ebedda83f6a9e02/full.md`
- Filtered: `generated/filtered/618c058a407fb5679ebedda83f6a9e02/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
