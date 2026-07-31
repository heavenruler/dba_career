---
doc_id: "99574e36ba022a0a02cf9b9545f7d55a"
title: "开源全方位运维监控工具：HertzBeatHertzBeat：实时监控系统性能，精准预警保障业务稳定- 精选真开源，释放 - 掘金"
knowledge_type: source
status: reviewed
primary_expert: "SRE Platform"
expert_domains:
  - "SRE Platform"
  - "DBA"
classification_source: generated
source_kind: "llm_filtered"
source_domain: "juejin.cn"
url: "https://juejin.cn/post/7358691823545663523"
generated: true
---

# 开源全方位运维监控工具：HertzBeatHertzBeat：实时监控系统性能，精准预警保障业务稳定- 精选真开源，释放 - 掘金

> [!info] Provenance
> - doc_id: `99574e36ba022a0a02cf9b9545f7d55a`
> - source_kind: `llm_filtered`
> - original: [來源連結](https://juejin.cn/post/7358691823545663523)
> - Review Record: [[99574e36ba022a0a02cf9b9545f7d55a]]
> - PDF: [[Attachments/Sources/99574e36ba022a0a02cf9b9545f7d55a.pdf|Open PDF]]

## 專家建議

- primary_expert: **SRE Platform**
- expert_domains: SRE Platform, DBA
- reason: SRE monitoring tool and observability

## Generated Summary

> [!warning] Generated interpretation
> 下列摘要不是來源原文；技術主張請回到 Evidence 與 PDF 核對。

本文介绍 HertzBeat 作为开源实时监控解决方案的核心能力，包括自定义监控模板、无需 Agent 的拉取式采集、内置多类监控类型、告警通知与集群扩展能力。整体重点落在运维监控、可观测性与高可扩展架构。

## Knowledge Outline

- 概览与特性
- 监控模板
- 内置监控类型
- 无需 Agent
- 高性能集群

## Extractive Evidence

### `99574e36ba022a0a02cf9b9545f7d55a:0001`

`doc_id: 99574e36ba022a0a02cf9b9545f7d55a` · `source_kind: llm_filtered`

```text
# 摘要

本文介绍 HertzBeat 作为开源实时监控解决方案的核心能力，包括自定义监控模板、无需 Agent 的拉取式采集、内置多类监控类型、告警通知与集群扩展能力。整体重点落在运维监控、可观测性与高可扩展架构。

# 概览与特性

HertzBeat是一款深受广大开发者喜爱的开源实时监控解决方案。它以其简洁直观的设计理念和免安装
Agent的特性，实现了对各类服务器、数据库及应用服务的高效、便捷监控。该系统具备出色的自定义监控
功能，用户可以根据自身需求灵活设定各项监控指标，全面覆盖系统的运行状态、性能表现以及资源使用情
况，实现从基础硬件到上层应用的全方位透视。
在实际运维工作中，HertzBeat能够实时捕获并分析系统数据，及时发出预警通知，有效预防潜在故障风
险，有力保障业务的连续性和稳定性。无论对于个人开发者还是企业级用户，HertzBeat都是一款实用且高
效的运维利器，助您轻松掌握系统的脉搏，提升运维管理效率与质量。
HertzBeat的强大自定义，多类型支持，高性能，易扩展，低耦合，希望能帮助开发者和团队快速搭建自有
监控系统。HertzBeat的主要优势如下:

# 监控模板

HertzBeat 自身并没有去创造一种采集数据协议让监控对端来适配它。而是充分使用了现有的生态，SNMP
协议采集网络交换机路由器信息，JMX规范采集JAVA应用信息，JDBC规范采集数据集信息，SSH直连执行
脚本获取回显信息，HTTP+(JsonPath   |   prometheus等)解析API接口信息，IPMI协议采集服务器信息等等。
HertzBeat 使用这些已有的标准协议或规范，将他们的抽象规范可配置化，最后使其都可以通过编写YML格
式监控模板的形式，来制定模板使用这些协议去采集任何想要的指标数据。

# 内置监控类型
```

### `99574e36ba022a0a02cf9b9545f7d55a:0002`

`doc_id: 99574e36ba022a0a02cf9b9545f7d55a` · `source_kind: llm_filtered`

```text
而是充分使用了现有的生态，SNMP
协议采集网络交换机路由器信息，JMX规范采集JAVA应用信息，JDBC规范采集数据集信息，SSH直连执行
脚本获取回显信息，HTTP+(JsonPath   |   prometheus等)解析API接口信息，IPMI协议采集服务器信息等等。
HertzBeat 使用这些已有的标准协议或规范，将他们的抽象规范可配置化，最后使其都可以通过编写YML格
式监控模板的形式，来制定模板使用这些协议去采集任何想要的指标数据。

# 内置监控类型

Website, Port Telnet, Http Api, Ping Connect, Jvm, SiteMap, Ssl Certificate, SpringBoot2, FTP Server
  ,   SpringBoot3, Udp Port, Dns, Pop3, Ntp, Api Code, Smtp, Nginx
  Mysql, PostgreSQL, MariaDB, Redis, ElasticSearch, SqlServer, Oracle, MongoDB, DM, OpenGauss, C
  lickHouse, IoTDB, Redis Cluster, Redis SentinelDoris BE, Doris FE, Memcached, NebulaGraph
  Linux, Ubuntu, CentOS, Windows, EulerOS, Fedora CoreOS, OpenSUSE, Rocky Linux, Red Hat, Free
  BSD, AlmaLinux, Debian Linux
  Tomcat, Nacos, Zookeeper, RabbitMQ, Flink, Kafka, ShenYu, DynamicTp, Jetty, ActiveMQ, Spring Gat
  eway, EMQX MQTT, AirFlow, Hive, Spark, Hadoop
  Kubernetes, Docker
  CiscoSwitch, HpeSwitch, HuaweiSwitch, TpLinkSwitch, H3cSwitch
  通知支持 Discord Slack Telegram 邮件 钉钉 微信 飞书 短信 Webhook Server酱
```

### `99574e36ba022a0a02cf9b9545f7d55a:0003`

`doc_id: 99574e36ba022a0a02cf9b9545f7d55a` · `source_kind: llm_filtered`

```text
ShenYu, DynamicTp, Jetty, ActiveMQ, Spring Gat
  eway, EMQX MQTT, AirFlow, Hive, Spark, Hadoop
  Kubernetes, Docker
  CiscoSwitch, HpeSwitch, HuaweiSwitch, TpLinkSwitch, H3cSwitch
  通知支持 Discord Slack Telegram 邮件 钉钉 微信 飞书 短信 Webhook Server酱

# 无需 Agent

对于使用过各种系统的用户来说，可能最麻烦头大的不过就是各种                                  agent 的安装部署调试升级了。每台主机
得装个 agent，为了监控不同应用中间件可能还得装几个对应的                              agent，监控数量上来了轻轻松松上千个，
写个批量脚本可能会减轻点负担。agent                    的版本是否与主应用兼容,            agent 与主应用的通讯调试, agent 的同
步升级等等等等，这些全是头大的点。

HertzBeat 的原理就是使用不同的协议去直连对端系统，采用                           PULL 的形式去拉取采集数据，无需用户在对
端主机上部署安装          Agent   |   Exporter 等。比如监控   linux操作系统, 在 HertzBeat 端输入IP端口账户密码或密
钥即可。比如监控          mysql数据库, 在 HertzBeat 端输入IP端口账户密码即可。密码等敏感信息全链路加密

# 高性能集群
```

## Repository Paths

- PDF: `collector/99574e36ba022a0a02cf9b9545f7d55a.pdf`
- Extracted: `generated/extracted/99574e36ba022a0a02cf9b9545f7d55a/full.md`
- Filtered: `generated/filtered/99574e36ba022a0a02cf9b9545f7d55a/knowledge.json`

<!-- Generated source page: do not edit. Use the Review Record or promote a new note. -->
