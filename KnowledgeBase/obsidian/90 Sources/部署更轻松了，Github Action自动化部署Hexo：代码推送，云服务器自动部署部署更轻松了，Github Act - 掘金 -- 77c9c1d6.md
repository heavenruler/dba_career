---
doc_id: "77c9c1d6afbff80e7276eb15cce12e49"
title: "部署更轻松了，Github Action自动化部署Hexo：代码推送，云服务器自动部署部署更轻松了，Github Act - 掘金"
aliases:
  - "部署更轻松了，Github Action自动化部署Hexo：代码推送，云服务器自动部署部署更轻松了，Github Act - 掘金"
url: "https://juejin.cn/post/7347958786050752563"
source_domain: "juejin.cn"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "GitHub Actions"
  - "Hexo"
  - "CI/CD"
  - "SSH部署"
  - "DevOps"
  - "Troubleshooting"
generated: true
---

# 部署更轻松了，Github Action自动化部署Hexo：代码推送，云服务器自动部署部署更轻松了，Github Act - 掘金

> [!info] Provenance
> - doc_id: `77c9c1d6afbff80e7276eb15cce12e49`
> - source_kind: `llm_filtered`
> - source: [original URL](https://juejin.cn/post/7347958786050752563)
> - PDF: [open local PDF](../../collector/77c9c1d6afbff80e7276eb15cce12e49.pdf)

## Summary

这篇文章讲的是用 GitHub Actions 在 push 到 main 分支时自动执行 Hexo 构建，并通过 ssh-deploy 把生成后的 public/ 目录同步到云服务器。文中还说明了相关 secrets 的配置方式，以及 rsync/SSH 连接失败时的排查方向。

## Knowledge Outline

- 关于 Github Action — GitHub Actions, CI/CD, Hexo, DevOps
- 开始设置 — GitHub Actions, Workflow, YAML, Hexo, CI/CD
- SSH 凭证配置 — SSH, Secrets, GitHub Actions, 安全, 部署
- 错误排查 — GitHub Actions, Rsync, SSH, Troubleshooting, 安全

## Repository Paths

- PDF: `collector/77c9c1d6afbff80e7276eb15cce12e49.pdf`
- Extracted: `generated/extracted/77c9c1d6afbff80e7276eb15cce12e49/full.md`
- Filtered: `generated/filtered/77c9c1d6afbff80e7276eb15cce12e49/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
