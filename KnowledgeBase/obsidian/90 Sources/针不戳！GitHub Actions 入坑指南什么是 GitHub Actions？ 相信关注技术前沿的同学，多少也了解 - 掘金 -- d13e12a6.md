---
doc_id: "d13e12a68a7744bac4a4c20663d079a4"
title: "针不戳！GitHub Actions 入坑指南什么是 GitHub Actions？ 相信关注技术前沿的同学，多少也了解 - 掘金"
aliases:
  - "针不戳！GitHub Actions 入坑指南什么是 GitHub Actions？ 相信关注技术前沿的同学，多少也了解 - 掘金"
url: "https://juejin.cn/post/6960126908180725773"
source_domain: "juejin.cn"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "GitHub Actions"
  - "CI/CD"
  - "DevOps"
  - "自动化部署"
  - "Workflow"
  - "持续集成"
generated: true
---

# 针不戳！GitHub Actions 入坑指南什么是 GitHub Actions？ 相信关注技术前沿的同学，多少也了解 - 掘金

> [!info] Provenance
> - doc_id: `d13e12a68a7744bac4a4c20663d079a4`
> - source_kind: `llm_filtered`
> - source: [original URL](https://juejin.cn/post/6960126908180725773)
> - PDF: [open local PDF](../../collector/d13e12a68a7744bac4a4c20663d079a4.pdf)

## Summary

本文介绍 GitHub Actions 的基本概念、CI/CD 关系、工作流配置位置、触发事件、Jobs 与 steps 语法，并用发送邮件的 workflow 示例展示 secrets、上下文变量和第三方 action 的使用。

## Knowledge Outline

- 前言 — GitHub Actions
- GitHub Actions 定义 — GitHub Actions, CI/CD, 持续集成
- 软件开发流程 — CI/CD, 自动化测试, 自动化部署
- Action 市场 — GitHub Actions, Action Market
- 基本概念 — GitHub Actions, Workflow, Jobs, Steps, Runners
- 快速入门 — GitHub Actions, SMTP, Workflow
- 发送邮件 Workflow 示例 — GitHub Actions, YAML, SMTP, secrets
- Workflow 示例说明 — GitHub Actions, YAML, Workflow
- Secrets 与上下文 — GitHub Actions, secrets, 上下文变量
- 触发与执行状态 — GitHub Actions, push, 执行状态
- Workflow 文件位置 — GitHub Actions, Workflow, YAML
- name 语法 — GitHub Actions, Workflow
- on 语法 — GitHub Actions, Workflow, 事件触发
- on 示例 — GitHub Actions, YAML, push, pull_request
- 定时调度示例 — GitHub Actions, cron, 定时任务
- Jobs 语法 — GitHub Actions, Jobs, Workflow
- job name 语法 — GitHub Actions, Jobs
- job needs 语法 — GitHub Actions, Jobs, 依赖关系
- job needs 示例 — GitHub Actions, YAML, Jobs, 依赖关系
- runs-on 语法 — GitHub Actions, Runner, runs-on
- steps 语法 — GitHub Actions, Steps, Docker
- steps 字段 — GitHub Actions, Steps, YAML, Docker, shell
- Workflow 文档参考 — GitHub Actions, 官方文档
- Runner 资源规格 — GitHub Actions, Runner, 虚拟机, 资源规格
- 使用限制 — GitHub Actions, Runner, 安全, 使用限制
- 小结 — GitHub Actions
- 参考资料 — GitHub Actions, 参考资料

## Repository Paths

- PDF: `collector/d13e12a68a7744bac4a4c20663d079a4.pdf`
- Extracted: `generated/extracted/d13e12a68a7744bac4a4c20663d079a4/full.md`
- Filtered: `generated/filtered/d13e12a68a7744bac4a4c20663d079a4/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
