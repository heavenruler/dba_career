万字详解：K8s核⼼组件与指标监控体系
👉⽬录
1 引⾔
2 Kubernetes 监控 -- 为什么我们需要它？
3 Kubernetes 关键组件和指标
4 Kubernetes 指标是如何暴露的
5 结语
K8s  是容器编排领域的事实标准，作为⼀名后端开发，如果对  K8s  的技术原理不够了解，未
来⽆论是在⽇常⼯作还是求职⾯试中，可能都会⾯临⼀些挑战问题。
本⽂是腾讯云可观测平台⼯程师柯开所总结的  K8s  核⼼技术原理，帮助你轻松拿捏！⻓⽂⼲
货预警，建议先点赞转发收藏⼀键三连再来仔细阅读，对照问题场景印证效果更佳！
关注腾讯云开发者，⼀⼿技术⼲货提前解锁 👇
0101
引⾔
腾讯云官⽅社区公众号，汇聚技术开发者群体，分享技术⼲货，打造技术影响⼒交…
954 篇原创内容
腾讯云开发者
公众号
2025年03⽉19⽇ 08:46 北京腾讯云开发者
2025/6/4 凌晨 12:30 万字详解： K8s 核⼼组件与指标监控体系
https://mp.weixin.qq.com/s/jZCiQEKdMxZbuXmG7jdg-A 1/23

Kubernetes 可以说是容器编排领域的事实标准。不管你的业务是运⾏在公有云、私有云，还是
混合云上， Kubernetes 都能给你⼀种 “ 统⼀天下 ” 的感觉。它不仅能帮你把容器化应⽤管理得井
井有条，还能让你的系统在扩展性、弹性、⾼可⽤性上更上⼀层楼。 Kubernetes 就是云原⽣时
代的 “ 基础设施底座 ” 。
1.1 Kubernetes 为啥这么火？
Kubernetes 之所以能火，核⼼就在于它解决了容器化应⽤的 “ 管理难题 ” 。它不仅能帮你调度容
器，还能让你的应⽤在集群⾥跑得更 稳 、更快、更⾼效。比如：
弹性扩展：流量突然暴涨？ Kubernetes ⾃动扩容，帮你扛住压⼒。
⾼可⽤性：某个节点挂了？ Kubernetes 立⻢把应⽤调度到其他节点，服务不中断。
跨平台⽀持：不管你是⽤  AWS 、 Azure ，还是⾃⼰的私有云， Kubernetes 都能给你⼀致的
体验。
1.2 Kubernetes 的 “ 阿喀琉斯之踵 ”
不过， Kubernetes 也不是万能的。随着集群规模越来越⼤，业务越来越复 杂 ，性能问题就开始
冒头了。比如：
资源争⽤：CPU 、内存被抢光了，应⽤跑不动。
调度延 迟 ：Pod 半天调度不上去，急死个⼈。
⽹络瓶颈：流量⼤了，⽹络卡顿。
这些问题如果不解决，轻则影响⽤户体验，重则直接导致业务中断。所以，监控和优化
Kubernetes 性能，就成了每个⼯程师的 “ 必修课 ” 。
0202
Kubernetes 监控 -- 为什么我们需要它？
您可能会想： “Kubernetes 不是已经挺智能了吗？ ”
为啥还要监控它呢？别急，听我慢慢道来。
2.1 Kubernetes 非万能的，它也会 “ ⽣病”
2025/6/4 凌晨 12:30 万字详解： K8s 核⼼组件与指标监控体系
https://mp.weixin.qq.com/s/jZCiQEKdMxZbuXmG7jdg-A 2/23

⾸先， Kubernetes 确实很强⼤，但它并不是 “ ⾦刚不坏之⾝ ” 。它就像⼀个复 杂 的⽣态系统，⾥
⾯有很多组件在协同⼯作： API Server 、 etcd 、 Scheduler 、 Controller Manager 、 kubelet 、
kube-proxy…… 这些组件任何⼀个出了问题，都可能导致整个集群 “ 趴窝 ” ：
API Server 挂了：你连集群都访问不了，更别说管理应⽤了。
etcd 出问题了：集群的状态数据丢失，调度和资源管理全乱套。
kubelet 罢⼯了：节点上的  Pod 没⼈管，应⽤直接停摆。
所以，监控  Kubernetes 的⾸要⽬标就是确保这些核⼼组件的健康。你得时刻知道它们是不是在
正常⼯作，有没有出现异常。
2.2 资源管理：别让 ” 内卷 “ 毁了你的集群
Kubernetes 的核⼼功能之⼀就是资源调度和管理。但问题是，资源是有限的，⽽应⽤的需求是
⽆限的。如果你的集群⾥跑的应⽤太多，资源争⽤就会成为常态：
CPU 被抢光：应⽤跑得像蜗⽜，⽤户体验直接崩掉。
内存不⾜：OOM （ Out of Memory ） 杀 ⼿出动， Pod 被⽆情⼲掉。
磁盘  I/O 瓶颈：数据库操作卡成狗，业务逻辑全乱套。
通过监控，你可以实时了解集群的资源使⽤情况，及时发现瓶颈，避免 “ 内卷 ” 导致的性能下
降。
2.3 调度延 迟 ： Pod 为啥半天起不来？
Kubernetes 的调度器（ Scheduler ）负责把  Pod 分配到合适的节点上。但有时候，你会发现
Pod 半天调度不上去，甚⾄⼀直处于  Pending 状态。这可能是以下原因导致的：
节点资源不⾜：没有⾜够的  CPU 、内存或  GPU 。
调度策略问题：比如节点亲和性、污点（ Taint ）和容忍（ Toleration ）配置不当。
调度器性能瓶颈：调度器本⾝处理不过来，导致延 迟 。
通过监控调度器的性能，你可以快速定位问题，优化调度策略，确保  Pod 能快速启动。
2.4 ⽹络性能：别让⽹络成为 “ 瓶颈 ”
在  Kubernetes 集群⾥，⽹络是连接⼀切的 “ ⾎管 ” 。但如果⽹络性能不⾏，整个系统都会受影
响：
Service 延 迟 ⾼：⽤户请求半天没响应，体验极差。
2025/6/4 凌晨 12:30 万字详解： K8s 核⼼组件与指标监控体系
https://mp.weixin.qq.com/s/jZCiQEKdMxZbuXmG7jdg-A 3/23

Pod 之间通信慢：微服务架构下，服务调⽤卡顿，业务逻辑⽆法正常执⾏。
Ingress 性能瓶颈：外部流量进不来，业务直接瘫痪。
通过监控⽹络性能，你可以及时发现⽹络瓶颈，优化⽹络配置，确保流量畅通⽆阻。
2.5 故障排查：定位问题，减少  downtime
最后，监控的另⼀个重要作⽤就是故障排查。当集群出现问题时，监控数据就是你的 “ 侦探⼯
具 ” 。通过分析监控指标，你可以快速定位问题根源，减少故障恢复时间（ MTTR ）。比如：
Pod 频繁重启：可能是资源不⾜或应⽤本⾝有问题。
节点失联：可能是⽹络问题或  kubelet 崩溃。
API Server 响应慢：可能是  etcd 性能瓶颈或请求量过⼤。
没有监控，就像在 “ 摸⿊走路 ” ，问题来了都不知道从哪下⼿。
通过监控  Kubernetes, 我们可以确保核⼼组件健康，保障  API Server 、 etcd 、 Scheduler 等关键
组件不出问题。还可以优化资源使⽤情况，对资源使⽤情况有全局掌控，避免  CPU 、内存、磁
盘等资源成为瓶颈。另外当集群出现问题时，也能快速定位故障，减少  downtime ，提升系统
可⽤性。
所以，监控  Kubernetes 不是可选项，⽽是必选项。它就像是你集群的 “ 健康检查仪 ” ，帮你提前
发现问题，避免⼩问题演变成⼤灾难。
0303
Kubernetes 关键组件和指标
既然我们已经知道了为什么需要监控  Kubernetes ，接下来咱们就来聊聊到底监控什么？
Kubernetes 是⼀个复 杂 的系统，涉及很多组件和指标。如果不知道监控哪些东⻄，那监控⼯具
再强⼤也是⽩搭。
接下来我们将深入探讨  Kubernetes 监控的关键组件和指标。
下图是  kubernetes 集群的经典架构图，根据这个架构图我们可以知道  Kubernetes 有哪些关键
组件。
2025/6/4 凌晨 12:30 万字详解： K8s 核⼼组件与指标监控体系
https://mp.weixin.qq.com/s/jZCiQEKdMxZbuXmG7jdg-A 4/23

3.1 核⼼组件：监控  Kubernetes 的 “ ⼼脏 ”
Kubernetes 的核⼼组件是集群的 “ ⼼脏 ” ，它们的健康直接决定了整个系统的 稳 定性。让我们从
这些核⼼组件入⼿，逐步展开。
API Server ：集群的 “ ⼤脑 ”
API Server 是  Kubernetes 的 “ ⼤脑 ” ，负责处理所有  API 请求。如果它出了问题，整个集群的操
作都会受到影响。因此，监控  API Server 的健康状况是重中之重。
请求延 迟 ：API 请求的响应时间，延 迟 过⾼会影响集群操作。
请求速率：每秒处理的请求数，过⾼可能导致  API Server 过载。
错误率：API 请求失败的比例，⾼错误率可能意味着配置问题或资源不⾜。
etcd ：集群的 “ 数据库 ”
etcd 是  Kubernetes 的 “ 数据库 ” ，存储集群的所有状态数据。如果  etcd 性能下降，整个集群的
状态管理都会受到影响。
写延 迟 ：etcd 写入操作的延 迟 ，延 迟 过⾼会影响集群状态更新。
读延 迟 ：etcd 读取操作的延 迟 ，延 迟 过⾼会影响调度和资源管理。
存储⼤⼩：etcd 存储的数据量，过⼤可能导致性能下降。
Leader 选举：etcd 集群的  Leader 选举次数，频繁选举可能意味着⽹络问题。
Scheduler ： Pod 的 “ 调度员 ”
Scheduler 负责将  Pod 调度到合适的节点上。如果调度器性能不佳， Pod 可能 迟迟 ⽆法启动。
调度延 迟 ：从  Pod 创建到调度完成的时间，延 迟 过⾼会影响应⽤启动速度。
2025/6/4 凌晨 12:30 万字详解： K8s 核⼼组件与指标监控体系
https://mp.weixin.qq.com/s/jZCiQEKdMxZbuXmG7jdg-A 5/23

调度失败率：调度失败的  Pod 比例，⾼失败率可能意味着资源不⾜或配置问题。
Controller Manager ：集群的 “ 管家 ”
Controller Manager 负责运⾏各种控制器，确保集群状态符合预期。如果控制器出现问题，集
群状态可能会失控。
控制器延 迟 ：控制器处理事件的时间，延 迟 过⾼可能导致状态不⼀致。
控制器错误率：控制器处理失败的比例，⾼错误率可能意味着配置问题或资源冲突。
kubelet ：节点的 “ 守护者 ”
kubelet 负责管理节点上的  Pod 和容器。如果  kubelet 出现问题，节点上的应⽤可能会停摆。
Pod 启动延 迟 ：从  Pod 创建到容器启动的时间，延 迟 过⾼会影响应⽤可⽤性。
容器崩溃次数：容器崩溃的频率，⾼崩溃率可能意味着应⽤或资源问题。
kube-proxy ：⽹络的 “ 交通警察 ”
kube-proxy 负责  Service 的负载均衡和⽹络代理。如果  kube-proxy 性能不佳，⽹络请求可能会
卡顿。
⽹络延 迟 ：Service 请求的响应时间，延 迟 过⾼会影响⽤户体验。
连接错误率：⽹络连接失败的比例，⾼错误率可能意味着⽹络配置问题。
3.2 深入节点资源：监控集群的 “ 肌⾁ ”
节点是  Kubernetes 集群的 “ 肌⾁ ” ，它们的资源使⽤情况直接决定了集群的性能。让我们从节点
资源的⾓度，进⼀步展开监控。
CPU ：计算能⼒的 “ 燃料 ”
CPU 是节点计算能⼒的核⼼资源。如果  CPU 使⽤率过⾼，应⽤性能会⼤幅下降。你需要关
注：
使⽤率：节点的  CPU 使⽤率，过⾼可能导致应⽤性能下降。
限制和请求：Pod 的  CPU 请求和限制，确保资源分配合理。
内存：应⽤的 “ ⼯作空间 ”
内存是应⽤运⾏的 “ ⼯作空间 ” 。如果内存不⾜，应⽤可能会被  OOM （ Out of Memory ） 杀 ⼿
⼲掉。你需要关注：
使⽤率：节点的内存使⽤率，过⾼可能导致  OOM 问题。
限制和请求：Pod 的内存请求和限制，确保资源分配合理。
2025/6/4 凌晨 12:30 万字详解： K8s 核⼼组件与指标监控体系
https://mp.weixin.qq.com/s/jZCiQEKdMxZbuXmG7jdg-A 6/23

磁盘：数据的 “ 仓库 ”
磁盘是存储数据的 “ 仓库 ” 。如果磁盘使⽤率过⾼或  I/O 延 迟 过⼤，应⽤性能会受到影响。你需
要关注：
使⽤率：节点的磁盘使⽤率，过⾼可能导致  I/O 性能下降。
I/O 延 迟 ：磁盘读写操作的延 迟 ，延 迟 过⾼会影响应⽤性能。
⽹络：流量的 “ ⾼速公路 ”
⽹络是连接节点和应⽤的 “ ⾼速公路 ” 。如果⽹络带宽不⾜或丢包率过⾼，流量会卡顿。你需要
关注：
带宽使⽤率：节点的⽹络带宽使⽤率，过⾼可能导致⽹络拥塞。
丢包率：⽹络数据包的丢失比例，⾼丢包率可能意味着⽹络问题。
3.3 聚集  Pod 和容器：监控应⽤的细胞
Pod 和容器是  Kubernetes 中运⾏应⽤的 “ 细胞 ” ，它们的健康状况直接决定了应⽤的表现。让我
们从  Pod 和容器的⾓度，进⼀步深入监控。
Pod ：应⽤的最⼩单位
Pod 是  Kubernetes 中应⽤的最⼩单位。如果  Pod 状态异常，应⽤可能会停摆。你需要关注：
状态：Pod 的当前状态（ Running 、 Pending 、 Failed 等），异常状态需要及时处理。
重启次数：Pod 的重启次数，频繁重启可能意味着应⽤或资源问题。
资源使⽤：Pod 的  CPU 、内存、磁盘等资源使⽤情况，确保资源分配合理。
容器：应⽤的运⾏环境
容器是  Pod 中运⾏应⽤的 “ 环境 ” 。如果容器崩溃或启动时间过⻓，应⽤可能会⽆法正常运⾏。
你需要关注：
启动时间：容器的启动时间，过⻓可能意味着镜像拉取或配置问题。
崩溃次数：容器的崩溃次数，频繁崩溃可能意味着应⽤或资源问题。
⽇志：容器的⽇志，帮助排查应⽤错误。
3.4  延伸⾄⽹络和服务：监控集群的 “ ⾎管 ”
⽹络和服务是  Kubernetes 集群的 “ ⾎管 ” ，它们的性能直接决定了应⽤的可⽤性。让我们从⽹络
和服务的⾓度，进⼀步扩展监控。
2025/6/4 凌晨 12:30 万字详解： K8s 核⼼组件与指标监控体系
https://mp.weixin.qq.com/s/jZCiQEKdMxZbuXmG7jdg-A 7/23

Service ：内部流量的 “ 调度中⼼ ”
Service 是  Kubernetes 中内部流量的 “ 调度中⼼ ” 。如果  Service 性能不佳，应⽤之间的通信会受
到影响。你需要关注：
请求延 迟 ：Service 请求的响应时间，延 迟 过⾼会影响⽤户体验。
错误率：Service 请求失败的比例，⾼错误率可能意味着后端  Pod 问题。
Ingress ：外部流量的 “ 入⼝ ”
Ingress 是  Kubernetes 中外部流量的 “ 入⼝ ” 。如果  Ingress 性能不佳，外部⽤户可能⽆法访问应
⽤。你需要关注：
请求延 迟 ：Ingress 请求的响应时间，延 迟 过⾼会影响外部访问。
错误率：Ingress 请求失败的比例，⾼错误率可能意味着配置问题。
⽹络策略：流量的 “ 防火墙 ”
⽹络策略是  Kubernetes 中流量的 “ 防火墙 ” 。如果⽹络策略配置不当，流量可能会被错误地拦
截。你需要关注：
连接状态：⽹络策略的执⾏情况，确保流量符合预期。
丢包率：⽹络数据包的丢失比例，⾼丢包率可能意味着⽹络问题。
3.5  总结：层层递进的监控逻辑
Kubernetes 是⼀个复 杂 的系统，涉及很多组件和指标。监控  Kubernetes ，不能只盯着  Pod 和容
器，⽽要分层处理。
通过从核⼼组件到节点资源，再到  Pod 和容器，最后延伸到⽹络和服务，我们逐步构建了⼀个
完整的  Kubernetes 监控体系。
这种层层递进的逻辑关系，不仅可以帮助我们全⾯了解  Kubernetes 的监控重点，还能让你在遇
到问题时，快速定位到具体的组件或资源。
0404
Kubernetes 指标是如何暴露的
我们已经深入了解了  Kubernetes 监控的关键组件和核⼼指标，接下来咱们来聊聊  Kubernetes
指标是如何暴露的。以及如何通过这些指标构建⼀个完整的监控体系。
2025/6/4 凌晨 12:30 万字详解： K8s 核⼼组件与指标监控体系
https://mp.weixin.qq.com/s/jZCiQEKdMxZbuXmG7jdg-A 8/23

我们可以根据  Kubernetes 监控数据的来源，将其分为三⼤类：
⽤户业务  Pod 暴露的指标：这些指标主要与应⽤性能和业务逻辑相关。例如，应⽤性能指
标包括请求延 迟 、吞吐量、错误率等；⽽业务逻辑相关的指标则可能涵盖订单处理量、⽤
户活跃度、交易成功率等。这些指标通常由应⽤程序通过  Prometheus 客户端库（如
client_golang）直接暴露。
Kubernetes 核⼼组件暴露的指标：这些指标由  Kubernetes 的核⼼组件（如  Metrics Server
和  kubelet）提供，主要⽤于监控集群和节点的资源使⽤情况，例如  CPU 、内存、磁盘  I/O
等。这些组件内置了  Prometheus 格式的指标暴露机制。
Exporter 暴露的指标：Exporter （如  kube-state-metrics 和  node-exporter）在  Kubernetes 监
控中扮演着 “ 桥梁 ” 的⾓⾊。它们将  Kubernetes 内部组件的状态和性能数据转换为
Prometheus 可识别的格式，并通过  HTTP 接⼝暴露出来，供监控系统采集。
我们从  ⽤户业务  Pod 暴露的指标 开始，详细介绍  Prometheus 指标暴露的基本机制。例如，
应⽤程序可以通过在代码中集成  Prometheus 客户端库，定义和暴露⾃定义指标，并通过
/metrics 端点提供数据。
然后，我们将介绍  Kubernetes 核⼼组件 的指标暴露机制。这些组件（如  kubelet 和  Metrics
Server ）同样使⽤  Prometheus 格式来暴露指标，通常通过  HTTP 接⼝提供集群和节点的资源使
⽤情况数据。
最后，我们将深入探讨  Exporter 的作⽤。 Exporter 是  Kubernetes 监控体系中的重要组成部
分，它们将  Kubernetes 内部组件的复 杂 状态数据转换为  Prometheus 可识别的格式。
例如，kube-state-metrics 会暴露  Kubernetes 资源对象（如  Pod 、 Deployment 、 Service 等）的
状态信息，⽽  node-exporter 则专注于节点级别的硬件和操作系统指标。
通过这三种指标的层层递进，我们不仅可以学习  如何构建⼀个完整的  Kubernetes 监控体系，
还能深入理解  Kubernetes 内部组件的运⾏状态和性能表现，从⽽为集群的 稳 定性、可观测性
和优化提供有⼒⽀持。
4.1  ⽤户业务  Pod 暴露的指标
我们不仅需要采集  Kubernetes 各个组件的指标来了解集群健康状况，也需要采集业务  pod 暴
露的指标。这些指标通常是由应⽤程序⾃⾝⽣成，并通过  HTTP 端点（如  /metrics）或⽇志形
式暴露出来。它直接反映了应⽤程序的运⾏状态和性能表现。通过监控这些指标，可以及时发
现业务层⾯的问题，
2025/6/4 凌晨 12:30 万字详解： K8s 核⼼组件与指标监控体系
https://mp.weixin.qq.com/s/jZCiQEKdMxZbuXmG7jdg-A 9/23

例如：应⽤性能相关的，如：请求延 迟 、吞吐量、错误率等，以及业务逻辑相关的，如：订单
处理量、⽤户活跃度、交易成功率等。
业务⾃定义指标使⽤  Prometheus SDK 暴露业务指标是⼀种常⻅的做法，特别是在开发⾃定义
应⽤程序时。 Prometheus 提供了多种语⾔的客户端库（如  Go 、 Java 、 Python 等），通过这些
库，你可以轻松地在应⽤程序中定义和暴露⾃定义指标。
⾸先需要在代码中定义你需要的业务指标。 Prometheus ⽀持多种类型的指标，包括：
Counter ：累加器，只增不减（如请求总数）。
Gauge ：可增可减的数值（如当前并发数）。
Histogram ：直⽅图，⽤于统计分布（如请求延 迟 ）。
Summary ：摘要，⽤于统计分位数（如请求延 迟 的  99 分位）。
1
2
3
4
5
6
7
8
9
10
11
12
13
14
15
16
17
18
19
20
21
22
23
24
25
26
27
package main
import (
"net/http"
"github.com/prometheus/client_golang/prometheus"
"github.com/prometheus/client_golang/prometheus/promhttp"
)
// 定义⼀个  Counter 指标
var (
requestsTotal = prometheus.NewCounter(
prometheus.CounterOpts{
Name: "myapp_requests_total", // 指标名称
Help: "Total number of requests.", // 指标描述
},
)
)
// 定义⼀个  Gauge 指标
var (
activeUsers = prometheus.NewGauge(
prometheus.GaugeOpts{
Name: "myapp_active_users", // 指标名称
Help: "Number of active users.", // 指标描述
},
)
)
2025/6/4 凌晨 12:30 万字详解： K8s 核⼼组件与指标监控体系
https://mp.weixin.qq.com/s/jZCiQEKdMxZbuXmG7jdg-A 10/23

在业务逻辑中更新指标的值。例如，在每次处理请求时增加  requestsTotal，并在⽤户登录时更
新  activeUsers：
使⽤  promhttp 包暴露指标。 Prometheus 会通过  HTTP 端点抓取这些指标：
28
29
30
31
32
33
// 初始化指标
func init() {
prometheus.MustRegister(requestsTotal)
prometheus.MustRegister(activeUsers)
}
1
2
3
4
5
6
7
8
9
10
11
12
13
14
15
16
17
func handleRequest(w http.ResponseWriter, r *http.Request) {
// 增加请求总数
requestsTotal.Inc()
// 模拟业务逻辑
w.Write([]byte("Hello, World!"))
}
func userLogin() {
// 增加活跃⽤户数
activeUsers.Inc()
}
func userLogout() {
// 减少活跃⽤户数
activeUsers.Dec()
}
1
2
3
4
5
6
7
8
9
10
func main() {
// 注册  HTTP 处理函数
http.HandleFunc("/", handleRequest)
// 暴露指标端点
http.Handle("/metrics", promhttp.Handler())
// 启动  HTTP 服务器
http.ListenAndServe(":8080", nil)
}
2025/6/4 凌晨 12:30 万字详解： K8s 核⼼组件与指标监控体系
https://mp.weixin.qq.com/s/jZCiQEKdMxZbuXmG7jdg-A 11/23

访问  http://localhost:8080/metrics ，你会看到暴露的指标，例如：
4.2 Kubernetes 核⼼组件指标
Kubernetes 核⼼组件指标主要包括：来⾃于  Kubernetes 的  API Server 、 kubelet 等组件的
/metrics API 。
除了常规的  CPU 、内存的信息外，这部分信息还主要包括了各个组件的核⼼监控指标。比如，
对于  API Server 来说，它就会在  /metrics API ⾥，暴露出各个  Controller 的⼯作队列（ Work
Queue ）的⻓度、请求的  QPS 和延 迟 数据等等。这些信息，是检查  Kubernetes 本⾝⼯作情况
的主要依据。
以  Kubelet 为例， Kubelet 的  /metrics 端点是通过  HTTPS 暴露的，默认端⼝  10250 ，  并且需要
认证和授权。
我们可以直接访问  node 上暴露的  10250 端⼝获取  kubelet 指标：
由于  kubelet 指标默认通过  https 暴露，在  tls 握⼿过程中，验证服务端证书的时候， ca 证书中
不包含  node ip 信息，会出现证书校验失败的错误：x509: cannot validate certiﬁcate for <node-
ip> because it doesn't contain any IP SANs 。
为了解决该问题，我们在  curl 请求中加上-k 参数，即⾃动跳过证书校验。
1
2
3
4
5
6
7
# HELP myapp_requests_total Total number of requests.
# TYPE myapp_requests_total counter
myapp_requests_total 10
# HELP myapp_active_users Number of active users.
# TYPE myapp_active_users gauge
myapp_active_users 5
1 curl -k -H "Authorization: Bearer {token}" https://{node-ip}:10250/metri
2025/6/4 凌晨 12:30 万字详解： K8s 核⼼组件与指标监控体系
https://mp.weixin.qq.com/s/jZCiQEKdMxZbuXmG7jdg-A 12/23

另外  Kubelet 的  API 默认启⽤了  RBAC （基于⾓⾊的访问控制），需要使⽤  ServiceAccount 的
Token 作为  Bearer Token 访问  Kubelet ，并且确保该  ServiceAccount 具有访问  Kubelet 的权
限。
使⽤  Prometheus 采集  kubelet
由于  Kubelet 组件运⾏在  Kubernetes 集群的各个节点中，  如果使⽤  Prometheus 采集  kubelet
指标的话，我们可以基于  Node 服务发现模式，⾃动发现  Kubernetes 中所有  Node 节点的信息
并作为监控的⽬标  Target 。
在  Prometheus 的采集配置中添加如下任务：
在  Prometheus 中我们可以看到能够通过  https://<kubelet-ip>:<port>/metrics   直接获取指标数
据，并展⽰出结果。
1
2
3
4
5
6
7
8
9
10
11
12
scrape_configs:
- job_name: kubelet-metrics
honor_timestamps: true
metrics_path: /metrics
scheme: https
kubernetes_sd_configs:
# node 模式，发现到所有的 node 节点并作为当前 Job 监控的 Target 实例
- role: node
bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/to
tls_config:
#  跳过证书校验
insecure_skip_verify: true
2025/6/4 凌晨 12:30 万字详解： K8s 核⼼组件与指标监控体系
https://mp.weixin.qq.com/s/jZCiQEKdMxZbuXmG7jdg-A 13/23

另外，我们也可以不直接通过  kubelet 的  metrics 服务采集监控数据，⽽通过  Kubernetes 的
api-server 提供的代理  API 访问各个节点中  kubelet 的  metrics 服务，如下所⽰：
1
2
3
4
5
6
7
8
9
10
11
12
13
14
15
16
17
18
19
20
21
22
23
scrape_configs:
- job_name: kubelet
honor_timestamps: true
metrics_path: /metrics
scheme: https
kubernetes_sd_configs:
- role: node
bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/toke
tls_config:
insecure_skip_verify: true
relabel_configs:
- separator: ;
regex: (.*)
target_label: __address__
replacement: kubernetes.default.svc:443
action: replace
- source_labels:
- __meta_kubernetes_node_name
separator: ;
regex: (.+)
target_label: __metrics_path__
replacement: /api/v1/nodes/${1}/proxy/metrics
action: replace
2025/6/4 凌晨 12:30 万字详解： K8s 核⼼组件与指标监控体系
https://mp.weixin.qq.com/s/jZCiQEKdMxZbuXmG7jdg-A 14/23

通过  relabeling, 将默认的采集地址 __address__ 从 <node-ip> ，替换成  api-server 地址：
kubernetes.default.svc:443。
同时将实际采集的  path 从  /metrics 替换成  api-server 的代理地址
/api/v1/nodes/${1}/proxy/metrics。
2025/6/4 凌晨 12:30 万字详解： K8s 核⼼组件与指标监控体系
https://mp.weixin.qq.com/s/jZCiQEKdMxZbuXmG7jdg-A 15/23

此时，实际采集访问的是  api-server 的代理地址，通过代理地址获取  kubelet 数据。
4.3  使⽤  Exporter 暴露集群指标
Kubernetes 内部的某些核⼼组件并不会以  Prometheus metrics 的形式暴露出来，比如  Etcd 的
各项性能指标、集群中  Pod 的数量等关键信息。这个时候就需要  Exporter 来帮忙了。
Exporter 在  Kubernetes 监控中扮演着 “ 桥梁 ” 的⾓⾊，它的作⽤是将这些组件的内部状态 / 指标转
换成  Prometheus 可以识别的格式，然后通过  HTTP 接⼝暴露出来，从⽽帮助你全⾯监控集群
的健康状况。
Prometheus 社区提供了丰富的  Exporter 实现，涵盖了从基础设施，中间件以及⽹络等各个⽅
⾯的监控功能。
2025/6/4 凌晨 12:30 万字详解： K8s 核⼼组件与指标监控体系
https://mp.weixin.qq.com/s/jZCiQEKdMxZbuXmG7jdg-A 16/23

在  Kubernetes ⽣态中，有⼏种常⽤的  Exporter ，它们各⾃负责暴露不同组件的指标。
kube-state-metrics ：
kube-state-metrics 是⼀个专⻔为  Kubernetes 设计的  Exporter ，它从  Kubernetes API Server 中获
取集群的状态信息 , 并将其暴露为  Prometheus 格式的指标。
kube-state-metrics 提供了  Kubernetes 集群的 “ 状态视图 ” ，帮助你了解集群中各种资源的状态和
健康状况。通过  kube-state-metrics, 我们可以获取：
Pod 的状态（ Running 、 Pending 、 Failed 等）。
Deployment 的副本数和可⽤副本数。
Node 的状态和资源分配情况。
Node Exporter ：
node-exporter 是  Prometheus 官⽅提供的  Exporter ，⽤于收集节点的硬件和操作系统指标。
node-exporter 提供了节点的详细资源使⽤情况，帮助你发现节点级别的性能瓶颈。通过  Node
Exporter 我们可以获取
CPU 使⽤率。
内存使⽤率。
磁盘  I/O 和空间使⽤情况。
⽹络带宽和丢包率。
0505
结语
Kubernetes 组件核⼼监控、 Exporter 和业务监控三者是相辅相成的，比如：
2025/6/4 凌晨 12:30 万字详解： K8s 核⼼组件与指标监控体系
https://mp.weixin.qq.com/s/jZCiQEKdMxZbuXmG7jdg-A 17/23

当业务指标（如请求延 迟 ）异常时，可以结合  Kubernetes 资源使⽤情况（如  CPU 、内存）
进⾏分析，判断是否是资源不⾜导致的问题。
当  Kubernetes 集群出现故障时，可以通过业务指标判断是否对业务造成了影响。
通过  kube-state-metrics 等  Exporter 可以对集群各资源的数量、状态有⼀个全⾯的了解。
通过这三者相结合，我们可以构建⼀个全⾯的监控体系，确保从基础设施到应⽤程序的每⼀个
环节都处于可观测状态。
我们深入探讨了  Kubernetes 监控的重要性、关键组件及其核⼼指标，并详细分析了
Kubernetes 指标是如何暴露和采集的。从⽤户业务  Pod 的⾃定义指标，到  Kubernetes 核⼼组
件的资源使⽤数据，再到  Exporter 对集群内部状态的转换与暴露，我们逐步构建了⼀个完整的
Kubernetes 监控框架。
Kubernetes 的强⼤之处在于其灵活性和可扩展性，但这也带来了监控的复 杂 性。理解这些指标
的来源和暴露机制，是确保集群 稳 定性、性能优化和故障排查的关键第⼀步。
在后续⽂章中，我们将进⼀步探讨如何使⽤  Prometheus 采集这些指标，并通过  Grafana 实现
可视化监控，同时分享腾讯云上的最佳实践，帮助您在实际⽣产环境中构建⾼效、可靠的
Kubernetes 监控体系。
监控  Kubernetes 不仅是为了发现问题，更是为了预防问题。只有通过全⾯的监控和深入的分
析，我们才能真正释放  Kubernetes 的潜⼒，为业务提供 稳 定、⾼效的运⾏环境。
最后介绍⼀下腾讯云可观测平台  Prometheus 。使⽤腾讯云  Prometheus ，⼀键监控您的集群，
极⼤地解放您的双⼿和头脑。
在腾讯云  Prometheus 上：
⼀键监控您的  Kubernetes 集群，⾃动帮您完成各种  Exporter 的安装。
⾃动部署采集配置和采集  agent, 完成  Exporter 和  Kubernetes 核⼼组件（ kubelet,api-
server,cadvisor 等）的指标采集。
并集成  Grafana, 直接在  Grafana 上为你提供展⽰⾯板。
结合腾讯云可观测平台的告警功能和  Prometheus Alertmanager 能⼒，为您提供免搭建的⾼效
运维能⼒，减少开发及运维成本。
2025/6/4 凌晨 12:30 万字详解： K8s 核⼼组件与指标监控体系
https://mp.weixin.qq.com/s/jZCiQEKdMxZbuXmG7jdg-A 18/23

相比开源  Prometheus ，腾讯云  Prometheus 具备如下优势：
2025/6/4 凌晨 12:30 万字详解： K8s 核⼼组件与指标监控体系
https://mp.weixin.qq.com/s/jZCiQEKdMxZbuXmG7jdg-A 19/23

我们诚邀您体验   腾讯云  Prometheus （ 15 天免费试⽤），借助其强⼤的监控能⼒和企业级⽀
持，助⼒您的  Kubernetes 环境实现更⾼效的可观测性和 稳 定性。
如有任何疑问，欢迎加入官⽅技术交流群
关于腾讯云可观测平台
腾讯云可观测平台（ Tencent Cloud Observability Platform ， TCOP ）基于指标、链路、⽇志、
事件的全类型监控数据，结合强⼤的可视化和告警能⼒，为您提供⼀体化监控解决⽅案。满⾜
您全链路、端到端的统⼀监控诉求，提⾼运维排障效率，为业务的健康和 稳 定保驾护航。功能
模块有：
Prometheus 监控：开箱即⽤的  Prometheus 托管服务；
应⽤性能监控  APM ：⽀持⽆侵入式探针，零配置获得开箱即⽤的应⽤观测能⼒；
云拨测  CAT ：利⽤分布于全球的监测⽹络，提供模拟终端⽤户体验的拨测服务；
前端 / 终端性能监控  RUM ：Web 、⼩程序、 iOS 、 Android 端等⼤前端质量、性能监控；
Grafana 可视化服务：提供免运维、免搭建的  Grafana 托管服务；
云压测  PTS ：模拟海量⽤户的真实业务场景，全⽅位验证系统可⽤性和 稳 定性；
...... 等等
点击播放视频快速了解 👇
联系我们
2025/6/4 凌晨 12:30 万字详解： K8s 核⼼组件与指标监控体系
https://mp.weixin.qq.com/s/jZCiQEKdMxZbuXmG7jdg-A 20/23

👇点击阅读原⽂了解腾讯云可观测平台
-End-
原创作者｜柯开
感谢你读到这⾥，不如关注⼀下？👇
📢📢 欢迎加入腾讯云开发者社群，享前沿资讯、⼤咖⼲货，找兴趣搭⼦，交同城好友，
更有鹅⼚招聘机会、限量周边好礼等你来 ~
（⻓按图片立即扫码）
可观测平台（ TCOP ）基于指标、链路、⽇志、事件的全类型监控数据，结合强⼤的可视…
140 篇原创内容
腾讯云可观测
公众号
腾讯云官⽅社区公众号，汇聚技术开发者群体，分享技术⼲货，打造技术影响⼒交流社区。
954 篇原创内容
腾讯云开发者
公众号
03:4203:42
2025/6/4 凌晨 12:30 万字详解： K8s 核⼼组件与指标监控体系
https://mp.weixin.qq.com/s/jZCiQEKdMxZbuXmG7jdg-A 21/23

阅读原⽂修改于2025年03⽉19⽇
📢📢对  DeepSeek 的技术原理、部署教程、应⽤实践感兴趣的⼩伙伴，也可以扫下⽅⼆
维码加入腾讯云官⽅  DeepSeek 交流群，不定时输出鹅⼚⼤佬的实战教学！
腾讯技术⼈原创集 · ⽬录
上⼀篇
⼀⽂看懂⽀付系统架构之第三⽅⽀付
下⼀篇
技术⼈核⼼竞争⼒：被忽视的项⽬管理能⼒
2025/6/4 凌晨 12:30 万字详解： K8s 核⼼组件与指标监控体系
https://mp.weixin.qq.com/s/jZCiQEKdMxZbuXmG7jdg-A 22/23

2025/6/4 凌晨 12:30 万字详解： K8s 核⼼组件与指标监控体系
https://mp.weixin.qq.com/s/jZCiQEKdMxZbuXmG7jdg-A 23/23

