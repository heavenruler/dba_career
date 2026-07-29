---
doc_id: "50c4dffbe1dc2f4c90bcb36f2fa1ff79"
title: "使用podman搭建MySQL 8.0主从避坑指北镜像准备和选择 由于mysql自带许多工具，比如mysqlbinlog - 掘金"
aliases:
  - "使用podman搭建MySQL 8.0主从避坑指北镜像准备和选择 由于mysql自带许多工具，比如mysqlbinlog - 掘金"
url: "https://juejin.cn/post/7397028381974331401"
source_domain: "juejin.cn"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "主从复制"
  - "Podman"
  - "容器"
  - "配置"
  - "SQL"
  - "运维"
  - "经验分享"
generated: true
---

# 使用podman搭建MySQL 8.0主从避坑指北镜像准备和选择 由于mysql自带许多工具，比如mysqlbinlog - 掘金

> [!info] Provenance
> - doc_id: `50c4dffbe1dc2f4c90bcb36f2fa1ff79`
> - source_kind: `llm_filtered`
> - source: [original URL](https://juejin.cn/post/7397028381974331401)
> - PDF: [open local PDF](../../collector/50c4dffbe1dc2f4c90bcb36f2fa1ff79.pdf)

## Summary

这篇文章主要记录了用 podman 搭建 MySQL 8.0 主从复制时的关键避坑点：镜像版本选择、为什么用 podman、主从配置文件、容器启动方式、复制账号与复制参数设置，以及旧库补做从库时要先手动同步数据。

## Knowledge Outline

- 镜像选择与Podman原因 — MySQL, Podman, Docker, 容器, 镜像选择, 运维
- 配置与启动 — MySQL, 主从复制, Podman, 配置文件, Docker Compose, 容器
- 进容器设置与复制账号 — MySQL, 主从复制, SQL, 复制账号, 复制参数, 容器
- 旧库补从机的经验 — MySQL, 主从复制, 经验, 数据同步, 运维

## Repository Paths

- PDF: `collector/50c4dffbe1dc2f4c90bcb36f2fa1ff79.pdf`
- Extracted: `generated/extracted/50c4dffbe1dc2f4c90bcb36f2fa1ff79/full.md`
- Filtered: `generated/filtered/50c4dffbe1dc2f4c90bcb36f2fa1ff79/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
