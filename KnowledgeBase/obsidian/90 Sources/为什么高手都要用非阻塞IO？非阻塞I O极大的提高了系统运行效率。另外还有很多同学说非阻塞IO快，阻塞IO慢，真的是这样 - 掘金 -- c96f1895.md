---
doc_id: "c96f1895052b469c48c42ddb0c22b9a0"
title: "为什么高手都要用非阻塞IO？非阻塞I/O极大的提高了系统运行效率。另外还有很多同学说非阻塞IO快，阻塞IO慢，真的是这样 - 掘金"
aliases:
  - "为什么高手都要用非阻塞IO？非阻塞I/O极大的提高了系统运行效率。另外还有很多同学说非阻塞IO快，阻塞IO慢，真的是这样 - 掘金"
url: "https://juejin.cn/post/7381752542982520886"
source_domain: "juejin.cn"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "非阻塞IO"
  - "I/O模型"
  - "性能优化"
  - "并发"
  - "Java NIO"
  - "Python asyncio"
  - "Node.js"
  - "Go"
  - "事件驱动"
  - "多路复用"
generated: true
---

# 为什么高手都要用非阻塞IO？非阻塞I/O极大的提高了系统运行效率。另外还有很多同学说非阻塞IO快，阻塞IO慢，真的是这样 - 掘金

> [!info] Provenance
> - doc_id: `c96f1895052b469c48c42ddb0c22b9a0`
> - source_kind: `llm_filtered`
> - source: [original URL](https://juejin.cn/post/7381752542982520886)
> - PDF: [open local PDF](../../collector/c96f1895052b469c48c42ddb0c22b9a0.pdf)

## Summary

聚焦非阻塞I/O的本质、阻塞I/O在高并发下的问题，以及 Java NIO、Python asyncio、Node.js、Go 的实现模型、设计共性与性能边界。

## Knowledge Outline

- I/O 基础与阻塞问题 — I/O模型, 阻塞IO, 并发, 性能优化, 线程, 上下文切换
- 非阻塞IO 的本质 — 非阻塞IO, I/O模型, 并发, 性能优化
- Java NIO — Java NIO, Channel, Buffer, Selector, 多路复用, 非阻塞IO
- Python asyncio — Python, asyncio, 事件循环, 协程, 异步I/O, 非阻塞IO
- Node.js 的事件驱动模型 — Node.js, 事件驱动, libuv, 非阻塞IO, 异步编程, I/O多路复用
- Go 语言的 goroutine — Go, goroutine, channel, select, 非阻塞IO, 并发
- 非阻塞I/O 的设计共性与性能边界 — 非阻塞IO, 多路复用, 协程, 事件驱动, 性能优化, 并发, I/O模型

## Repository Paths

- PDF: `collector/c96f1895052b469c48c42ddb0c22b9a0.pdf`
- Extracted: `generated/extracted/c96f1895052b469c48c42ddb0c22b9a0/full.md`
- Filtered: `generated/filtered/c96f1895052b469c48c42ddb0c22b9a0/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
