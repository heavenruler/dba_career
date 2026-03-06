Envoy 中文指南系列：Envoy 介绍
博客 下载 学习 社区 C知道 GitCode InsCode 会议 搜索 登录 会员中心 消息 历史 创作中心 创作 25181
跨平台构建 Docker 镜像新姿势，x86、arm
云原生可观测领域的半壁江山，这次被 Grafana 和 Cilium 给
一把梭 22599
Podman 使用指南 21249
拿下了
最新评论 米开朗基杨 阅读量872 收藏 2 点赞数 于 2023-01-13 11:38:07 发布 版权
文章标签： 云原生 grafana kubernetes 云计算 大数据 在 Kubernetes 上运行 GitHub Actions Self-hosted
ZhenYiCJ: [fix] entrypoint.sh line 6: it shou
[1] d is `payload=$(curl -sX POST -H "Authori 两个多月前， Grafana 实验室宣布与 Cilium 母公司 Isovalent 建立战略合作伙伴关系 ，希望通过 Grafana
开源的可观测性全家桶组件，帮助各个基础架构团队深度探测 Kubernetes 集群工作负载的安全、性能和相 Sealos 私有化部署完全指南
[2] coolcalf: 第一步： sealos gen ...... 可是， 互之间的连接状况。在这之前，Grafana 实验室还参与了 Isovalent 的 B 轮融资 ，并启动了相关的联合工程
我的系统中还没有 sealos 呢 计划。
哈哈，我好像知道 Cursor 为什么叫 Cursor 了，真相竟然是。。。
这两家公司都相信，在这个 API 驱动的应用时代，应用之间连接的可观测性（connectivity observability）起着 北风吹来个毛: 只用动动嘴就能安装编程环
至关重要的作用。为此，Isovalent 的 CEO Dan Wendlandt 专门写了一篇文章来探讨 使用传统方案来观测 境是吧 什么勾八文章 误导人
云原生应用之间连接的健康状况与性能是多么困难，以及如何使用 eBPF 来从根本上解决这个问题。 使用 FastGPT 实现最佳 AI 翻译工作流：全世界最信达雅的翻译
xnhsq12345: 老师好，刚刚下载了工作流，
导入到FastGPT里运行报错了，然后发现里 ❝
划重点：connectivity observability 是个新词，如果翻译成“应用之间连接的可观测性”就太长了，后面我 使用 Cursor 和 Devbox 快速开发并上线 Gin 项目
们统一就叫它 应用连接可观测性 吧。 前端程序猿i: 博主如果有1.0.1版本点击上线
后会提示重名怎么办
本文会讨论 Cilium 项目（由 eBPF 驱动）是如何打造一个标准来让 Kubernetes 集群中工作负载之间的连接变
最新文章 得更加安全，并且可观测。本文还会深入探讨如何将 Cilium 丰富的 应用连接可观测性 数据与 Grafana 实验室
[3] [4] [5] [6] 开源的 LGTM（Loki 用于日志，Grafana 用于可视化，Tempo 用于分布式追踪，Mimir 用于监控指 普通人用 DeepSeek 搞钱的 4 个野路子，3
标） 可观测性组件全家桶 进行结合，帮助应用研发人员与基础架构团队更轻松且更深入地观测应用之间连接的 个月赚 20w+
目录 健康状况与性能。 FastGPT 一招帮你解决 DeepSeek R1 的卡
顿问题 云原生应用连接可观测性
× 某教育网站疑似删库。。。没备份。。。数据全 全面应用连接可观测性的挑战 登录后您可以享受以下权益： 没了。。。Sealos 带你一分钟满血复活
挑战一：连接是分层的（“互相甩锅问题”） 免费复制代码 和博主大V互动
2025年 13篇 2024年 157篇 挑战二：应用身份（“信噪比问题”） 下载海量资源 发动态/写文章/加入社区
2023年 135篇 2022年 252篇
传统可观测性方案的不足
觉得还不错? 一键收藏 2021年 257篇 2020年 151篇 立即登录 基于 eBPF & Cilium 的可观测性方案 2019年 67篇
米开朗基杨 0 2 0 分享 关注 示例 1：无需更改应用（也无需 Sidecar）观测
示例 2：监测瞬息万变的网络层问题
示例 3：使分布式追踪来识别异常 API 请求
未来规划
引用链接
㝥拓 爆款云服务器 2核2G 38元/年！超高性价
通过结合 Grafana 实验室开源的可观测性组件和 Isovalent 基于 Cilium 的可观测性数据，实现网络和 API 层级 比 限时选购！ 㝥拓
服务的映射关系和指标监控。 广告
由于译者水平有限，本文不免存在遗漏或错误之处。如有疑问，请查阅原文。
以下是正文内容的译文。 分类专栏
云原生 1篇 付费
在正文开始之前，先给大家介绍下 Dan Wendlandt 这个人，他是 Isovalent 的联合创始人兼 CEO，之前在 黑科技 2篇
Nicira 公司负责推动并领导社区和产品战略。Nicira 这个公司现在可能没多少人听说过，毕竟现在是 云原生
的时代。10 年前应该有很人听过这个公司，它是软件定义网络（SDN）的领军者之一，旗下有大名鼎鼎的开 Service Mesh 2篇
源项目 Open vSwitch (OVS)，其 CTO Martin Casado 还是 OpenFlow 协议的第一份草案的撰稿人。2012 年
envoy 2篇 Nicira 被 VMware 收购后，OVS 就被拿来开刀了，VMware 基于 OVS 打造了一个网络虚拟化平台叫

Vmware NSX。 linux 9篇
Dan Wendlandt 与另外一位大佬 Thomas Graf（ Linux 内核开发者，Cilium 项目创始人） 共同创建了 Kubernetes 22篇
Isovalent 这个公司，他坚信 eBPF 会成为后云原生时代的救星，可以给云原生时代的微服务应用之间的网络
和安全带来质的飞跃。 Cloud Native 19篇
以下真的是正文内容的译文。。 Docker 8篇
Prometheus 1篇
云原生应用连接可观测性 监控 2篇
将云原生时代的应用构建为 API 驱动的服务集合有千般万般的好处，但惟独不包含监控和故障排查。因为在云 DevOps 1篇
原生和 微服务 的世界中，用户随便点一下鼠标都可能会调用几十个甚至几百个 API，底层连接中的任何故障
或者延迟都会对应用的行为产生负面影响，但是我们却很难排查到根本原因并根治它。
而且 Kubernetes 会动态地将每个服务的不同副本作为容器调度到由不同 Linux 机器组成的大型集群中，这会
使问题变得更加复杂。Kubernetes 这种架构很难确定遇到连接故障的工作负载在某一特定时间点的运行位
置，就算能确定位置，由于容器的多租户特性，应用研发人员也不能直接使用网络调试工具（例如 netstat、
tcpdump）来排查故障。
如此一来，应用研发团队与 Kubernetes 平台运维团队将会陷入两难的境地。虽然云原生时代的应用连接可观
测性比以往任何时候都重要，但实现起来却比以往任何时候都困难。
全面应用连接可观测性的挑战
深度观测 Kubernetes 应用之间连接的健康状况和性能是一个巨大的挑战，主要体现在两个方面：
挑战一：连接是分层的（“互相甩锅问题”）
最常见的情景是这样的：应用研发团队收到了某个用户报告某个应用出现了故障或者响应缓慢，他们感觉是底
层网络的问题， 于是甩锅给平台运维团队 。但是平台运维团队在基础架构相关的组件中并没有发现哪里出了问
题，于是 又甩锅给应用研发团队 ，甚至还可能甩锅给 IaaS 层或者云厂商。这就是传说中的“ 互相甩锅问题 ”。
全面应用连接可观测性需要穿透多个网络层
网络连接是分层的，每一层都有不同的职责，这个分层的模型叫做 “OSI 网络模型”。虽然你可能会经常听到一
些精通网络的大牛夸夸其谈数据链路层、网络层、传输层和应用层，但是这些内容在本文所探讨的挑战中都不
重要，我们只需要知道 每一层的根本目的是抽象出它下面各层的细节 。没发生故障时万事大吉，一发生故障就
傻眼了，因为这种网络分层模型会有意地将低层的故障隐藏在高层之中。
最终的结果是，无法通过观测单一网络层来实现全面应用连接可观测性，靠应用本身也无法实现（因为它只能
观测到 L7）。要想实现全面应用连接可观测性，必须能观测到所有网络层，并将所有网络层关联起来。
挑战二：应用身份（“信噪比问题”）
Kubernetes 的调度能力非常强大，即便是中等规模的多租户 Kubernetes 集群也可以轻松运行数以千计的服
务，每个服务都包含多个副本，这些副本都分散在数百个 Worker 节点上。想在这样的环境中观测单个应用的
连接性，简直是个噩梦，因为底层连接太“嘈杂”了。
以前大家的应用都跑在物理机或 虚拟机 上，网络环境一般都是 VLAN 和各种子网，那时候的 IP 地址或子网
可以直接用来识别特定的应用，因为应用的 IP 地址是长期有效的，不会频繁变化，因此我们可以根据特定 IP
的网络日志或计数器来分析应用的行为。云原生时代就不同了，工作负载都运行在容器中，而容器的生命周期
很短，不断被销毁重建，因此不能将 IP 地址作为应用的有效标识。即使在 Kubernetes 集群之外，IP 地址也
会不断变化，例如当应用研发人员使用来自云提供商（如 AWS）或其他第三方（如 Twilio）外部 API 时，每
次连接的目标 IP 地址都是不同的。因此我们不能再使用基于 IP 的网络日志来分析应用的行为。
对于现代应用而言，使用 IP 地址作为连接的来源或者目标的标识不再具有任何意义，因为所有的可观测性工
作都必须建立在长期有效的“服务身份”背景下。对于 Kubernetes 中运行的工作负载而言，可以使用与每个应
用相关的元数据 label（例如，namespace=tenant-job, service=core-api）来作为服务的身份。对于
Kubernetes 外部的服务而言，可以使用 DNS 名称（例如，api.twilio.com 或 mybucket.s3.aws.amazon.com）
来作为服务身份。

服务身份与其他形式的高级身份，如进程和 API 调用元数据，都是有价值的额外上下文信息，以锁定特定的故
障或行为。
传统可观测性方案的不足
考虑到上述的“ 互相甩锅问题 ”与“ 信噪比问题 ”，我们来看看传统可观测性方案的不足之处：
传统的网络监控设备 在多个方面都有限制，而且它们都是集中式设备，很容易成为瓶颈。除此之外，它们
的可观测性通常都不会对连接的来源和目标赋予特定的服务身份。
云厂商的网络流量日志 （例如，VPC 流量日志）倒不会成为集中的瓶颈，但仅限于网络层的可观测性，
因此缺乏服务身份和 API 层的可观测性。而且它们还与底层的基础设施紧密相关，不同的云厂商之间并不
兼容。
Linux 主机的统计信息 包含了部分与网络故障相关的数据，但是在 Kubernetes 集群中，操作系统并不能
通过“服务身份”来区分主机上运行的多个容器实例。此外，操作系统也不知道连接目标的服务身份，还缺
乏 API 层的可观测性。
基于 Sidecar 的服务网格 （例如 Istio）号称可以在不修改应用代码的前提下提供丰富的 API 层可观测
性，但是代价很大，牺牲了更多的资源、性能和操作复杂度。除此之外，服务网格对于网格外部服务的可
观测性也是能力有限，而且由于 Sidecar 代理只能操作 API 层，所以对于网络层的故障和瓶颈也无能为
力。
基于 eBPF & Cilium 的可观测性方案
eBPF 是一个全新的 Linux 内核革命性技术，由 Isovalent 在上游共同维护。目前 eBPF 支持所有主流的 Linux
发行版，它提供了一种安全高效的方式来将额外的内核级功能注入到 “eBPF 程序”。无论你想在内核中执行哪
些系统调用（例如网络访问、文件访问、程序执行等），eBPF 程序都可以安全且无干扰地执行。
Cilium 没有利用 iptables 等传统的内核级网络功能，而是采用了原生的 eBPF，从而实现了高效强大的网络连
接，网络安全性也大大提高，除此之外 Cilium 还将可观测性作为内置的 一等公民 。目前全球领先的企业和电
信公司都有在用 Cilium 作为网络插件，甚至连谷歌云、AWS 和微软 Azure 的 Kubernetes 产品都将 Cilium 作
[7] 为默认的 CNI 插件。早在 2021 年，Isovalent 就将 Cilium 捐给了云原生计算基金会（CNCF） 。
Cilium 联合 Grafana 的高级架构。Cilium 根据工作负载的身份生成内核级 eBPF 程序，这些 eBPF 程序将可
观测性数据输出到 Grafana 实验室的 LGTM 全家桶。
在 eBPF 的加持下，Cilium 可以确保所有的可观测性数据不仅与 IP 地址相关，而且与网络连接两端应用的更
高级别服务身份相关。再加上 eBPF 程序运行在 Linux 内核中，无需对应用本身作任何修改，也无需使用更复
杂的重量级服务网格，就可以实现上述的可观测性，它会将可观测性功能透明地插入到现有的工作负载下，非
常便于横向扩展。
Cilium 可以收集到非常丰富的“可感知服务身份”的与连接相关的指标和事件流，再联合 Grafana LGTM 全家
桶，简直是天作之合。
下面我们通过三个具体的示例来说明 这两个家伙组成的 CP 如何解决 Kubernetes 平台运维团队与应用研发团
队的“互相甩锅难题”。
示例 1：无需更改应用（也无需 Sidecar）观测 HTTP 黄金信号
一般大家都会使用 HTTP 黄金信号 （HTTP Golden Signals）指标来作为 HTTP（即 API 层）连接健康状况的
三个关键指标，这三个指标分别是：
HTTP 请求速率；
HTTP 请求延迟；
HTTP 请求响应码。
Cilium 可以在不修改应用的前提下收集这些监控数据，而且是根据长期有效的服务身份来汇总相应的指标。
回到之前的“ 互相甩锅问题 ”，如果应用研发团队发现应用连接出现了故障，他们可以根据 HTTP 黄金信号 明确
判断出故障的根源到底在哪里。如果是 API 层，那么这个问题需要应用研发团队自己处理；如果是网络层，那
么就需要基础设施团队进行处理。
再回到之前的“ 信噪比问题 ”，由于所有的监控指标都使用有意义的服务身份来标记，不管是平台运维团队还是
应用研发团队，都可以很轻松地使用 Grafana 的过滤功能来排除与当前故障无关的其他应用的监控信息，只关
注标记了相应团队名称的服务即可，甚至可以锁定特定的服务，无需了解该服务的容器实例运行在哪里。
举个例子，下面的 Grafana 监控面板展示了 命名空间 tenant-jobs 中的特定应用服务 core-api 所有入站连
接的响应码。从监控面板可以很直观地看出 core-api 服务正在被另一个服务 resumes 访问，起初都很正常，
但在 11:55 左右，500 响应码的数量开始增加，很明显这两个服务之间的连接在 API 层出现了问题，必须由负
责 core-api 服务和 resumes 服务的应用研发团队来解决。

示例 2：监测瞬息万变的网络层问题
故障总是无处不在，它可能发生在 OSI 网络模型的任意一层，如果“非 API 层”的组件出现了连接故障，由于应
用研发团队能力有限，所以很难发现潜在的网络问题，也不太可能清晰地说出这个问题应该找谁解决。
举个例子，假设用户反馈某个应用在几个小时前的一个非常短暂的时间窗口中出现了性能降低和应用层超时的
现象，用户查看应用日志也看不出哪里有问题，而且应用的 CPU 负载也没有任何异常，这会不会是网络层的
问题呢？
Isovalent 在其商业产品中对 Cilium 进行了扩展，可以直接利用内核级别的可观测性来提取 “ TCP 黄金信号”
的指标数据：
发送/接收的 TCP 字节数；
TCP 重传表示网络层数据包丢失/拥塞；
TCP 往返传输时间（RTT）表示网络层的延迟。
针对上述问题，我们来看看 Grafana 的监控面板，可以看到命名空间 tenant-jobs 中的某个特定服务
api.twilio.com notifications 出现了短暂的 TCP 重传（即网络层数据包丢失），但仅仅是与外部服务 通信
时才出现的 TCP 重传，而且时间窗口与用户反馈的故障时间窗口相吻合，基本可以断定这个故障与
api.twilio.com 有关。应用研发团队可以查看 Twilio 服务状态页面来确认故障发生的时间窗口中是否存在
已知的服务中断，最终可以断定这个故障与应用研发团队的应用无关。
示例 3：使分布式追踪来识别异常 API 请求
Cilium & Grafana 除了可以抓取网络层与 API 层的监控数据，还可以与分布式追踪（通过 HTTP Header 传播
标准追踪标识符的应用）相结合，实现多跳网络追踪。
大量的 HTTP 追踪数据本身就很容易让人不知所措，你根本就不知道这里面哪些数据可以帮助你解决问题。为
[8] 了简化问题，Grafana 引入了一个非常强大的概念叫 “exemplars ”，当它与指标结合使用时，可以帮助你确
定哪些追踪数据可以给你提供更详细的观测数据来帮助你解决问题。
回到示例 1 中的 core-api 服务，如果这个服务升级版本之后，请求延迟开始飙升，我们该怎么办？
如果你足够细心，可以发现监控面板上有很多小绿框，它们是 resumes 服务和 core-api 服务之间各个 HTTP
请求的 Grafana “exemplars”。单击具有高延迟值的某个 exemplar 会出现一个窗口，该窗口提供了一个菜单选
项来使用 Tempo 进行查询和可视化跟踪。

点击这个按钮，用户就可以看到 Tempo 中的全部跟踪细节，从下面的图中可以看出，可能是底层故障和重试
引发了较高的延迟。
未来规划
预计在未来几周和几个月内，Grafana 实验室和 Isovalent 会联合产出更多的博客，包含更多的用例以及与
Grafana Cloud 进一步整合的消息。除了探索更多的可观测性用例之外，还会探讨 LGTM 全家桶如何与 Cilium
Tetragon（Isovalent 开源的运行时安全项目）相结合，为威胁检测和合规性检测提供深度的运行时和网络安全
观测能力。
上述的所有示例配置都在这个 GitHub 中： https://github.com/isovalent/cilium-grafana-observability-
demo
感兴趣的同学可以自己实践一下。
引用链接
[1]
Grafana 实验室宣布与 Cilium 母公司 Isovalent 建立战略合作伙伴关系:
https://grafana.com/about/press/2022/10/24/grafana-labs-partners-with-isovalent-to-bring-best-in-class-
grafana-observability-to-ciliums-service-connectivity-on-kubernetes/
[2]
Isovalent 的 B 轮融资: https://www.prnewswire.com/news-releases/isovalent-raises-40m-series-b-as-cilium-
and-ebpf-transform-cloud-native-service-connectivity-and-security-301619134.html
[3]
Loki: https://grafana.com/oss/loki/
[4]
Grafana: https://grafana.com/oss/grafana
[5]
Tempo: https://grafana.com/oss/tempo/
[6]
Mimir: https://grafana.com/oss/mimir/
[7]
早在 2021 年，Isovalent 就将 Cilium 捐给了云原生计算基金会（CNCF）:
https://www.cncf.io/blog/2021/10/13/cilium-joins-cncf-as-an-incubating-project/
[8]
exemplars: https://grafana.com/docs/grafana/latest/fundamentals/exemplars/
你可能还喜欢
点击下方图片即可阅读
如何配置 Cilium 和 BGP 协同工作？
2023-01-05
ChatGPT 帮我跑了一个完整的 DevOps 流水线，离了个大谱...
2022-12-21

K8s 最强 CNI Cilium 网络故障排查指南
2022-12-16
云原生是一种信仰  ﰉ
关注公众号
后台回复◉k8s◉获取史上最方便快捷的 Kubernetes 高可用部署工具，只需一条命令，连 ssh 都不需要！
点击 "阅读原文" 获取 更好的阅读体验！
发现朋友圈变“安静”了吗？

K8s 应用的网络可 观测 性： Cil ium VS DeepFlow 每天都要开心呀(#^.^#) 1720
快速提高 云原生 应用开发者建设K8S网络可 观测 性能力
云原生 之使用docker部署uptime-kuma服务器 监控 面板 _uptime kuma-CSDN博... 2-13
2.访问uptime-kuma首页 六、添加http 监控 项 1.添加http 监控 项 2.查看 监控 项状态 七、添加docker 监控 项 1.配置docker宿主信
【 云原生 监控 系列第一篇】一文详解Prometheus普罗米修斯 监控 系统... 2-4
The job name is added as a labeljob=<job\_name>toanytimeseries scraped from this config. job_name: “prometheus” #每个
云原生 | 在 Kubernetes 中使用 Cil ium 替代 Calico 网络插件实 WeiyiGeek 唯一极客IT知识分享 最新发布 2268
Cil ium 是一款开源软件，它基于一种名为eBPF的新的Linux内核技术提供动力，用于透明地保护使用 Docker 和 Kubernetes
Grafana 系列文章（十五）：Exemplars east4ming的博客 991
Exemplars 简介 Exemplar 是用一个特定的 trace，代表在给定时间间隔内的度量。Metrics 擅长给你一个系统的综合视图，而
traces 给你一个单一请求的细粒度视图；Exemplar 是连接这两者的一种方式。 假设你的公司网站正经历着流量的激增。虽然
【 云原生 | Docker 高级篇】09、Docker 容器 监控 之 CAdvisor+InfluxDB+... 2-1 超过百分之八十的用户能够在两秒内访问网站，但有些用户的响应时间超过了正常水平，导致用户体验不佳。 为了确定造成
1.配置数据源 ​2.配置 面板 panel 一、Docker原生 监控 命令 暴露的问题:docker stats 统计结果只能是当前宿主机的全部容器,数 延迟的因素，你必须将快速响应的 trace 与缓慢响应的 trace 进行比较。鉴于典型生产环境中的大量数据，这将是非常费力和
k8s 云原生 应用如何接入 监控 .md 1-17
- role: node 这样的话就可以 监控 k8s 的内存、CPU之类的数据。 具体提供了哪些指标可以参考这里:https://github.com/googl
云原生 爱好者周刊：使用 Cil ium 和 Grafana 实现无侵入可 观测 性 KubeSphere 666
开源项目推荐 Cil ium Grafana Observability Demo 这个项目由 Cil ium 母公司 Isovalent 开源，提供了一个 Demo，使用 Cil iu
探索 Cil ium 与 Grafana 的 观测 之力：无痛实现应用洞察 gitblog_00042的博客 326
探索 Cil ium 与 Grafana 的 观测 之力：无痛实现应用洞察 去发现同类优质开源项目:https://gitcode.com/ 在今天这个高度依赖容器
4- 云原生 监控 体系- Grafana -基本使用 1-21
本文介绍了 云原生 监控 工具 Grafana 的基本使用,包括其界面、数据源设置,特别是如何导入和配置Prometheus数据源。详细讲
云原生 开发 - 监控 (简约版) 1-31
云原生 开发 - 监控 (简约版) 要在程序中暴露指标,并符合Prometheus和 Kubernetes 的规范,可以按照以下步骤进行: 1. 选择合适
Cil ium 开源 Tetragon – 基于 eBPF 的安全可 观测 性 & 运行时增强 k8s 生态 636
❝原文链接????：https://isovalent.com/blog/post/2022-05-16-tetragon译文原文链接????：https://icloudnative.io/posts/tetrag
prometheus+ Grafana 监控 全家桶 oMaFei的博客 1042
在调研 监控 工具，之前一直用的zabbix很平稳(从没出过问题)， 监控 内容大概有系统级别的cpu、内存、硬盘之类的， 也有服
【 云原生 监控 】Prometheus之Alertmanager报警_prometheus报警-CSDN... 2-12
【 云原生 监控 】Prometheus之Alertmanager报警 之Alertmanager报警 文章目录 Prometheus之Alertmanager报警 概述 资源
18. 云原生 可 观测 性之kubesphere 监控 报警系统使用实战_kubeshpere 开启监... 2-11
Kubernetes 核心组件 监控 APIServer 监控 Scheduler 监控 应用资源 监控 应用资源 监控 管理员视角 集群层级 项目与应用资源统
基于eBPF的 云原生 可 观测 性开源项目Kindling之eBPF基础设施库技术选型 eBPF_Kindling的博客 568
eBPF技术正以令人难以置信的速度发展，作为一项新兴技术，它具备改变容器网络、安全、可 观测 性生态的潜力。eBPF作为
kubernetes 使用 cil ium 网络插件 替换kube-proxy 02-10
然而，随着 云原生 应用的发展，对网络性能、安全性和可 观测 性的需求日益增强，这催生了 Cil ium 网络插件的出现。 Cil ium 是
基于 云原生 的一体化 监控 系统Day1_ 云原生 综合 监控 系统 1-24
基于 云原生 的一体化 监控 系统Day1 7.1 监控 体系部署管理 7.2k8s集群层面 监控 准备:部署k8s集群 master:192.168.192.128 no
【 云原生 】Nacos 监控 手册_nacos 监控 2-13
随着Nacos 0.9版本发布,Nacos-Sync 0.3版本支持了metrics 监控 ,能通过metrics数据观察Nacos-Sync服务的运行状态,提升了N
云原生 周报 | 信通院发布《 云计算 白皮书（2022年）》； Cil ium 1.12 正式发布 百度云原生计算的博客 348
今年的白皮书聚焦“新经济，上云用云新周期”。上云用云新周期是用 云原生 改造应用架构，以算力服务为资源调度手段，实现
Cisco 将收购 Cil ium 母公司 Isovalent，预计 2024 年第 3 季度完成 dwh0403的专栏 1046
2023 年 12 月 21 日，Isovalent 公司 CTO & 联合创始人 Thomas Graf 和 Cisco 安全业务集团高级副总裁兼总经理 Tom Gillis
分别在各自公司网站公布了思科打算收购 Isovalent 公司的计划，双方都没有公布收购的价格。当一家大公司收购一家建立在
Cil ium 如何处理 L7 流量 hanfengzxh的博客 485 像这样的流行开源项目上的初创公司时，事情可能并不是那么简单，这可能会在社区和依赖该软件的大公司面发生方向性的选
整篇看下来， Cil ium 在处理 L7 流量上的实现还是比较复杂的，牵扯多个组件协同。eBPF 在 L3/L4 流量处理上有着优异的性 择。CIsco 意在通过收购，意在增强其在多云网络和安全的能力。
SaaS多租户篇 tobebetter9527的博客 777
多租户
引领未来的安全 观测 与运行时保护：Tetragon gitblog_00069的博客 324
引领未来的安全 观测 与运行时保护：Tetragon tetragon Cil ium 是一个开源的网络代理和网络安全解决方案，用于保护 Kubernet
TCP重传问题分析及解决方法 qq_37934722的博客 4241
但是，在使用TCP通讯时，常会遇到数据包丢失或传输错误导致的TCP重传问题，这会给通讯稳定性带来很大影响。在编写T
CP通讯代码时，需要注意以上几点，并通过抓包等方式对数据进行分析，以确保TCP通讯的稳定性和可靠性。当发送的数据
【GO】LGTM_ Grafana _gozero_配置trace(4)_代码实操及追踪 非晓为骁的博客 534 包在网络传输中出现问题，如丢失、超时等，接收方未收到数据包会触发ACK未确认或未收到的情况。TCP的确认机制通过对
在 go-zero 框架中使用 trace，发送数据到 tempo，并做源码追踪 收到的数据包进行ACK确认，确认后即可删除已确认的数据包。在网络延迟过大的情况下，可以优化网络环境，例如使用增加
带宽或加入负载均衡器等措施，以缩短网络传输时间。
云原生 可 观测 套件：构建无处不在的可 观测 基础设施 阿里巴巴云原生的博客 678
近日，全球权威 IT 研究与顾问咨询公司 Gartner 发布《2023 年十大战略技术趋势》报告，「应用可 观测 性」再次成为其中热
资源数据可视化工具 Grafana qqxhb 资源共享 965
1 Grafana 1.1 什么是 Grafana Grafana 是一个可视化 面板 （Dashboard），有着非常漂亮的图表和布局展示，功能齐全的度量
Kubernetes 入门与组件详解： 云原生 应用部署指南
本篇指南详细阐述了 Kubernetes （K8s）的使用方法，结合 云原生 （Cloud Native）的理念，旨在帮助读者理解和部署 Kubern
关于我们 招贤纳士 商务合作 寻求报道 400-660-0108 kefu@csdn.net 在线客服 工作时间 8:30-22:00
公安备案号11010502030143 京ICP备19004658号 京网文〔2020〕1039-165号 经营性网站备案信息 北京互联网违法和不良信息举报中心
家长监护 网络110报警服务 中国互联网举报中心 Chrome商店下载 账号管理规范 版权与免责声明 版权申诉 出版物许可证 营业执照
©1999-2025北京创新乐知网络技术有限公司

Pade 8
云 原 生 可 泰 測 氟 域 的 半 壁 江 山 ， 玆 伐 被 Grafana 和 Cilium 絡 拿 下 了 ﹣CSDN 博 客
https﹕//blog﹒csdn﹒net/alex﹍yangchuansheng/article/details/128681290
Captured by Fireshot Pro﹕ 14 2 月 2025， 14﹕52﹕42
https﹕//detfireshot﹒corm

