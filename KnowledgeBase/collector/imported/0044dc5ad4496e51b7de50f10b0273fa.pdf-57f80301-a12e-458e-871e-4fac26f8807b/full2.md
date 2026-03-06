# 云原生应用连接可观测性

译者：米开朗基杨

注：由于译者水平有限，本文不免存在遗漏或错误之处。如有疑问，请查阅原文。以下为正文译文。

在正文开始之前，先介绍下 Dan Wendlandt：他是 Isovalent 的联合创始人兼 CEO，之前在 Nicira 负责推动并领导社区和产品战略。Nicira 是软件定义网络（SDN）的先驱之一，旗下有开源项目 Open vSwitch (OVS)。Dan Wendlandt 与 Linux 内核开发者、Cilium 项目创始人 Thomas Graf 共同创建了 Isovalent，他坚信 eBPF 会成为云原生时代的关键技术，能显著提升微服务应用之间的网络和安全能力。

将云原生时代的应用构建为 API 驱动的服务集合有诸多优点，但缺少监控和故障排查会带来挑战。在云原生与微服务世界中，用户的一次调用可能触发数十到数百个 API，底层连接的任何故障或延迟都会影响应用行为，但排查根因非常困难。Kubernetes 会将服务副本调度到不同的主机，使定位故障工作负载在某一时点的位置变得复杂；再加上容器的多租户特性，应用研发人员无法直接在宿主机上运行诸如 netstat、tcpdump 等网络调试工具。

因此，应用研发团队与 Kubernetes 平台运维团队常陷入两难。尽管应用连接可观测性比以往任何时候都重要，但实现它比以往更困难。

## 全面应用连接可观测性的挑战

深度观测 Kubernetes 应用之间连接的健康状况和性能是一个巨大的挑战，主要体现在两个方面。

### 挑战一：连接是分层的（“互相甩锅问题”）

常见情景：应用研发团队收到用户反馈应用故障或响应缓慢，认为是底层网络问题，便将责任推给平台运维团队；而平台团队在基础设施层未发现问题，又会把责任推回给应用团队，甚至推给 IaaS 或云厂商——这就是“互相甩锅问题”。

网络连接是分层的（OSI 模型），每一层抽象了其下层的细节。一旦发生故障，分层模型会隐藏低层故障，使得单层观测无法实现全面可观测性。应用本身只能观测到 L7，要实现全面可观测性，必须观测到所有网络层并将它们关联起来。

### 挑战二：应用身份（“信噪比问题”）

Kubernetes 的调度能力很强，即便是中等规模的多租户集群也能运行数千个服务，副本分散在数百个 Worker 节点上。在这样的环境中观测单个应用的连接性非常困难，底层连接信息非常嘈杂。

过去应用运行在物理机或虚拟机上，IP 地址或子网可以作为稳定的应用标识。但在云原生时代，容器生命周期短、IP 经常变化，IP 已不再能作为长期有效的服务标识。现代可观测性工作必须建立在长期有效的“服务身份”之上。在 Kubernetes 中，这些身份可以是与应用相关的元数据 label（例如 namespace=tenant-job, service=core-api）；在集群外，可以使用 DNS 名称（例如 api.twilio.com、mybucket.s3.amazonaws.com）作为服务身份。

服务身份以及其他高级身份（如进程、API 调用元数据）是定位特定故障或行为的重要上下文信息。

## 传统可观测性方案的不足

考虑到“互相甩锅问题”和“信噪比问题”，传统方案存在多方面不足：

- 传统网络监控设备是集中式的，易成为瓶颈，且通常不会将可观测性数据与来源/目标的服务身份关联起来。
- 云厂商的网络流量日志（如 VPC 流量日志）不易成为集中瓶颈，但局限于网络层，可观测性缺乏服务身份和 API 层信息，并且与底层基础设施紧密耦合，跨云不兼容。
- Linux 主机统计信息包含部分网络故障相关数据，但在 Kubernetes 中无法用主机级别数据区分同一主机上运行的多个容器实例，且缺乏目标服务身份和 API 层可观测性。
- 基于 Sidecar 的服务网格（如 Istio）可以在不修改应用代码的前提下提供丰富的 API 层可观测性，但代价高（资源、性能、运维复杂度），对网格外服务的可观测性有限，并且对网络层故障和瓶颈无能为力（因为 Sidecar 代理主要操作 L7）。

## 基于 eBPF & Cilium 的可观测性方案

eBPF 是 Linux 内核的一项革命性技术，Isovalent 在上游共同维护相关生态。目前主流 Linux 发行版均支持 eBPF，它提供了一种安全高效的方式，将额外的内核级功能以“eBPF 程序”的形式注入内核。eBPF 程序可以安全地在内核中观察和响应系统调用（如网络访问、文件访问、进程执行等）。

Cilium 不依赖 iptables 等传统内核网络功能，而是原生使用 eBPF 来实现高效的网络连接和安全性，并将可观测性作为一等公民。目前许多领先企业和电信公司使用 Cilium 作为 CNI，部分云厂商的 Kubernetes 产品也将 Cilium 作为默认 CNI。早在 2021 年，Isovalent 就将 Cilium 捐给了云原生计算基金会（CNCF）。

Cilium 会基于工作负载的身份生成内核级 eBPF 程序，这些 eBPF 程序将可观测性数据输出到 Grafana 实验室的可观测性组件（Loki、Grafana、Tempo、Mimir 等，文中统称 LGTM 全家桶）。借助 eBPF，Cilium 能确保可观测性数据不仅与 IP 相关，还与连接两端应用的高级别服务身份相关。此外，eBPF 程序运行在 Linux 内核中，无需修改应用、无需 Sidecar 或重量级网格即可透明地插入到现有工作负载中，便于横向扩展。

Cilium 能收集丰富的“可感知服务身份”相关的指标和事件流，结合 Grafana 的可视化与查询能力，可极大改善应用与平台团队之间的协作与故障定位。

下面通过三个示例说明 Cilium 与 Grafana 如何解决“互相甩锅”以及“信噪比”问题。

### 示例 1：无需更改应用（也无需 Sidecar）观测 HTTP 黄金信号

HTTP 黄金信号（HTTP Golden Signals）是衡量 HTTP（即 API 层）连接健康状况的三个关键指标：

- HTTP 请求速率
- HTTP 请求延迟
- HTTP 请求响应码

Cilium 可以在不修改应用的前提下收集这些监控数据，并按长期有效的服务身份汇总指标。这样，当出现故障时，应用或平台团队可以根据这些黄金信号判断根因层级：如果问题出在 API 层，应由应用团队处理；如果是网络层，则由基础设施团队处理。

同时，由于所有监控指标都以有意义的服务身份标记，双方可以使用 Grafana 的过滤功能排除无关服务的监控信息，聚焦相关服务，不必关心容器实例运行在哪台机器上。

举例：Grafana 面板展示命名空间 tenant-jobs 中服务 core-api 的入站连接响应码。面板显示 core-api 正在被 resumes 服务访问，起初正常，但在 11:55 左右 500 响应码增加，表明两个服务之间在 API 层出现问题，需要对应的应用研发团队排查。

### 示例 2：监测瞬息万变的网络层问题

故障可能出现在 OSI 模型的任意层。如果非 API 层组件出现连接故障，应用团队可能难以发现或界定应找谁来解决。

Isovalent 在商业产品中扩展了 Cilium，能够直接利用内核级可观测性提取“TCP 黄金信号”指标：

- 发送/接收的 TCP 字节数
- TCP 重传（表示网络层数据包丢失/拥塞）
- TCP 往返时间（RTT，表示网络层延迟）

举例：Grafana 面板显示命名空间 tenant-jobs 中某服务与外部服务 api.twilio.com 的通信期间出现短暂的 TCP 重传，时间窗口与用户反馈的故障窗口一致，可判定故障与 api.twilio.com 有关，应用团队可查看 Twilio 状态页确认是否存在外部服务中断，从而排除本应用问题。

### 示例 3：使分布式追踪来识别异常 API 请求

Cilium 与 Grafana 不仅抓取网络层与 API 层监控数据，还可与分布式追踪结合（基于 HTTP Header 传播的追踪标识符），实现多跳网络追踪。

大量追踪数据容易让人不知所措，不知道哪些追踪能帮助解决问题。Grafana 引入了“exemplars”概念：当与指标结合时，exemplar 能帮助你确定哪些追踪数据值得深入查看。

回到示例 1 中的 core-api：如果某次升级后请求延迟飙升，Grafana 面板中的多个小绿框即为 core-api 与 resumes 服务之间的各个 HTTP 请求的 exemplars。单击某个高延迟 exemplar，可以通过菜单项在 Tempo 中查看和可视化对应的追踪，进一步定位到底层故障或重试引起的高延迟。

## 未来规划

Grafana Labs 与 Isovalent 预计在未来几周和几个月内发布更多博客，包含更多用例以及与 Grafana Cloud 的进一步整合消息。除探索更多可观测性用例之外，还将探讨 LGTM 全家桶如何与 Cilium Tetragon（Isovalent 的开源运行时安全项目）结合，为威胁检测和合规性检测提供深度的运行时与网络安全可观测能力。

示例中提及的配置示例均已开源，感兴趣的读者可以自行实践。

GitHub 仓库（示例配置）：  
https://github.com/isovalent/cilium-grafana-observability-demo

## 引用链接

1. Grafana Labs 与 Isovalent 建立战略合作伙伴关系（新闻稿）：  
   https://grafana.com/about/press/2022/10/24/grafana-labs-partners-with-isovalent-to-bring-best-in-class-grafana-observability-to-ciliums-service-connectivity-on-kubernetes/

2. Isovalent 的 B 轮融资新闻：  
   https://www.prnewswire.com/news-releases/isovalent-raises-40m-series-b-as-cilium-and-ebpf-transform-cloud-native-service-connectivity-and-security-301619134.html

3. Loki（日志）：https://grafana.com/oss/loki/  
4. Grafana（可视化）：https://grafana.com/oss/grafana  
5. Tempo（分布式追踪）：https://grafana.com/oss/tempo/  
6. Mimir（监控存储）：https://grafana.com/oss/mimir/  

7. Cilium 加入 CNCF（2021）：  
   https://www.cncf.io/blog/2021/10/13/cilium-joins-cncf-as-an-incubating-project/

8. Grafana 文档：exemplars 介绍：  
   https://grafana.com/docs/grafana/latest/fundamentals/exemplars/