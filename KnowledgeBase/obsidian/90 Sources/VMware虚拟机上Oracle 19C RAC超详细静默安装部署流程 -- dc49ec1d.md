---
doc_id: "dc49ec1d99211bce054ea259f9b4334e"
title: "VMware虚拟机上Oracle 19C RAC超详细静默安装部署流程"
aliases:
  - "VMware虚拟机上Oracle 19C RAC超详细静默安装部署流程"
url: "https://mp.weixin.qq.com/s/11vXQTHGFvBorMvOnJM8uA"
source_domain: "mp.weixin.qq.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "Oracle RAC"
  - "Oracle 19c"
  - "DBA"
  - "Grid Infrastructure"
  - "ASM"
  - "静默安装"
  - "VMware"
  - "Linux"
  - "ISCSI"
  - "multipath"
  - "UDEV"
generated: true
---

# VMware虚拟机上Oracle 19C RAC超详细静默安装部署流程

> [!info] Provenance
> - doc_id: `dc49ec1d99211bce054ea259f9b4334e`
> - source_kind: `llm_filtered`
> - source: [original URL](https://mp.weixin.qq.com/s/11vXQTHGFvBorMvOnJM8uA)
> - PDF: [open local PDF](../../collector/dc49ec1d99211bce054ea259f9b4334e.pdf)

## Summary

Oracle Linux 7.9 上以 VMware 双节点部署 Oracle 19c RAC 的静默安装流程，涵盖系统、存储、网络规划，安装前 OS 配置，ISCSI 共享存储、多路径、UDEV、hosts、防火墙、SELinux、chrony、内核参数、用户目录、环境变量、Grid Infrastructure、ASM、DB 软件与 DBCA 建库。

## Knowledge Outline

- 系统规划 — Oracle RAC, 规划, 网络
- 存储规划 — ASM, OCR, Voting File, 存储
- 网络规划 — Oracle RAC, Public IP, Private IP, VIP, SCAN
- 节点网络配置 — Linux, nmcli, 网络配置
- YUM 源配置 — Oracle Linux, YUM, 安装准备
- 依赖包安装 — Oracle 19c, 依赖包, Linux
- ISCSI 客户端配置 — ISCSI, 共享存储, Oracle RAC
- Multipath 配置 — multipath, 共享存储, Linux
- Multipath 文件 — multipath, ASM, Linux
- UDEV 绑盘 — UDEV, ASM, Linux
- Hosts 配置 — hosts, Oracle RAC, 网络
- 防火墙与 SELinux — Linux, firewalld, SELinux
- Chrony 时间同步 — chrony, 时间同步, Oracle RAC
- 关闭透明大页和 NUMA — Oracle, Linux, THP, NUMA
- Avahi 配置 — Linux, avahi-daemon, Oracle RAC
- 系统参数 — sysctl, Oracle 19c, Linux 参数
- 资源限制 — limits.conf, Oracle, Linux
- 用户组与目录 — Oracle 用户, Linux 用户组, RAC
- 软件目录 — Oracle Home, 目录权限, Linux
- Grid 环境变量 — Grid Infrastructure, 环境变量, ASM
- Oracle 环境变量 — Oracle, 环境变量, RAC
- 安装介质与补丁 — OPatch, RU, Oracle 19c, Grid
- CVUQDisk 安装 — cvuqdisk, Oracle RAC, Grid
- 用户互信 — SSH, Oracle RAC, 互信
- Grid 安装前校验 — runcluvfy, Grid Infrastructure, 安装校验
- Grid 响应文件 — Grid Infrastructure, 响应文件, ASM, OCR
- Grid 静默安装 — Grid Infrastructure, 静默安装, root.sh
- ASM 磁盘组创建 — ASM, asmca, 磁盘组
- DB 软件校验 — Oracle DB, runcluvfy, 安装校验
- DB 安装响应文件 — Oracle DB, 响应文件, 静默安装
- DB 软件安装 — Oracle DB, runInstaller, 静默安装
- DBCA 响应文件 — DBCA, RAC 建库, CDB, PDB
- 建库与检查 — DBCA, srvctl, Oracle RAC, SQL
- 流程总结 — Oracle RAC, 安装流程, DBA

## Repository Paths

- PDF: `collector/dc49ec1d99211bce054ea259f9b4334e.pdf`
- Extracted: `generated/extracted/dc49ec1d99211bce054ea259f9b4334e/full.md`
- Filtered: `generated/filtered/dc49ec1d99211bce054ea259f9b4334e/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
