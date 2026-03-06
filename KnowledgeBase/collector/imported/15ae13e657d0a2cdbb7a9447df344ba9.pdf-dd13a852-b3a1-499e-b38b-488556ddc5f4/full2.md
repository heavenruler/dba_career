# 万字详解：K8s 核心组件与指标监控体系

目录
1. 引言
2. Kubernetes 监控 — 为什么我们需要它？
3. Kubernetes 关键组件和指标
4. Kubernetes 指标是如何暴露的
5. 结语

Kubernetes 是容器编排领域的事实标准。作为一名后端开发，如果对 Kubernetes 的技术原理不够了解，未来无论是在日常工作还是求职面试中，可能都会面临挑战。本篇由腾讯云可观测平台工程师柯开总结，讲解 Kubernetes 核心技术原理，帮助你掌握监控要点。

---

## 1 引言

Kubernetes 可以说是容器编排领域的事实标准。不管你的业务运行在公有云、私有云，还是混合云上，Kubernetes 都能给你一种“统一”的体验。它不仅管理容器化应用，还能提升系统的扩展性、弹性和高可用性，是云原生时代的基础设施底座。

### 1.1 为什么 Kubernetes 如此流行？
Kubernetes 之所以流行，核心在于它解决了容器化应用的管理难题，提供：
- 弹性扩展：流量激增时自动扩容。
- 高可用性：节点故障时自动重调度，服务不中断。
- 跨平台支持：在 AWS、Azure 或私有云上保持一致体验。

### 1.2 Kubernetes 的“阿喀琉斯之踵”
随着集群规模和业务复杂度增加，性能问题会显现：
- 资源争用：CPU、内存被抢光，应用跑不动。
- 调度延迟：Pod 长时间处于 Pending。
- 网络瓶颈：流量大时网络卡顿。

因此，监控和优化 Kubernetes 性能成为工程师的必修课。

---

## 2 Kubernetes 监控 — 为什么我们需要它？

你可能会想：“Kubernetes 不是很智能了吗？为什么还要额外监控？”原因如下。

### 2.1 Kubernetes 也会“生病”
Kubernetes 是一个复杂的生态系统，包含 API Server、etcd、Scheduler、Controller Manager、kubelet、kube-proxy 等。任何一个组件故障都可能影响集群可用性：
- API Server 挂了：无法访问或管理集群。
- etcd 出问题：集群状态数据异常，调度混乱。
- kubelet 出问题：节点上的 Pod 无人管理，应用停摆。

监控的首要目标是确保这些核心组件健康，及时发现异常。

### 2.2 资源管理：避免资源“内卷”
Kubernetes 的核心功能之一是资源调度和管理，但资源有限，应用需求无限。监控可以帮助发现资源瓶颈，避免 CPU、内存、磁盘 I/O 等成为性能瓶颈。

### 2.3 调度延迟：Pod 为什么起不来？
Scheduler 负责把 Pod 分配到节点。Pod 长时间 Pending 可能由以下原因导致：
- 节点资源不足（CPU、内存或 GPU）。
- 调度策略不当（节点亲和、污点与容忍等）。
- 调度器本身性能瓶颈。

监控调度器性能能帮助快速定位问题并优化策略。

### 2.4 网络性能：别让网络成为瓶颈
在集群中，网络连接一切。网络性能不好会导致：
- Service 响应延迟高。
- Pod 之间通信慢，微服务调用卡顿。
- Ingress 性能瓶颈，外部流量受阻。

监控网络性能能发现瓶颈并优化网络配置。

### 2.5 故障排查：定位问题，减少 downtime
监控数据是故障排查的侦探工具，能显著缩短 MTTR（平均修复时间）。例如：
- Pod 频繁重启：可能因资源不足或应用问题。
- 节点失联：可能因网络或 kubelet 崩溃。
- API Server 响应慢：可能与 etcd 性能或请求量有关。

没有监控就像在黑暗中行走，问题来了无从下手。

---

## 3 Kubernetes 关键组件和指标

既然知道了为什么要监控 Kubernetes，接下来要明确监控什么。Kubernetes 是一个复杂系统，涉及很多组件和指标，合理选择监控指标至关重要。

下面基于 Kubernetes 的经典架构，列出关键组件与指标。

### 3.1 核心组件：监控 Kubernetes 的“心脏”
- API Server（集群“大脑”）
  - 请求延迟：API 请求响应时间。
  - 请求速率（QPS）：每秒处理的请求数。
  - 错误率：API 请求失败比例。

- etcd（集群“数据库”）
  - 写延迟、读延迟：影响集群状态更新与读取。
  - 存储大小：数据量过大可能导致性能下降。
  - Leader 选举次数：频繁选举可能指示网络或节点问题。

- Scheduler（Pod 的“调度员”）
  - 调度延迟：从 Pod 创建到调度完成的时间。
  - 调度失败率：调度失败的 Pod 比例。

- Controller Manager（集群“管家”）
  - 控制器延迟：处理事件所需时间。
  - 控制器错误率：处理失败的比例。

- kubelet（节点“守护者”）
  - Pod 启动延迟：从 Pod 创建到容器启动的时间。
  - 容器崩溃次数：崩溃频率。

- kube-proxy（网络“交通警察”）
  - 网络延迟：Service 请求响应时间。
  - 连接错误率：网络连接失败比例。

### 3.2 节点资源：监控集群的“肌肉”
节点资源直接影响集群性能，需关注：
- CPU
  - 使用率、Pod 的请求和限制。
- 内存
  - 使用率、OOM 频率、Pod 的请求和限制。
- 磁盘
  - 使用率、I/O 延迟。
- 网络
  - 带宽使用、丢包率。

### 3.3 Pod 与容器：监控应用的“细胞”
- Pod
  - 状态（Running、Pending、Failed 等）。
  - 重启次数。
  - 资源使用（CPU、内存、磁盘）。

- 容器
  - 启动时间（影响可用性）。
  - 崩溃次数。
  - 日志（用于排查应用错误）。

### 3.4 网络与服务：监控集群的“血管”
- Service（内部流量）
  - 请求延迟、错误率。
- Ingress（外部入口）
  - 请求延迟、错误率。
- 网络策略
  - 连接状态、丢包率。

### 3.5 总结：分层递进的监控逻辑
监控 Kubernetes 不能只盯着 Pod 和容器，而要分层处理：从核心组件到节点资源、再到 Pod/容器，最后延伸到网络与服务。层层递进的逻辑能帮助快速定位故障根源。

---

## 4 Kubernetes 指标是如何暴露的

监控数据来源大致可分为三类：
1. 用户业务 Pod 暴露的指标：由应用通过 Prometheus 客户端库（如 client_golang）在 /metrics 端点暴露，通常包括请求延迟、吞吐量、错误率以及业务相关指标（订单量、活跃用户等）。
2. Kubernetes 核心组件暴露的指标：如 Metrics Server、kubelet、API Server 等以 Prometheus 格式通过 /metrics 暴露集群和节点的资源使用信息和内部指标。
3. Exporter 暴露的指标：如 kube-state-metrics、node-exporter，将 Kubernetes 内部状态或宿主机指标转换为 Prometheus 可识别格式并通过 HTTP 暴露。

下面分别展开。

### 4.1 用户业务 Pod 暴露的指标
应用通常在代码中通过 Prometheus 客户端库定义并暴露自定义指标，常见类型：
- Counter：累加（如请求总数）。
- Gauge：可增可减（如当前并发数）。
- Histogram：用于统计分布（如请求延迟）。
- Summary：用于统计分位数（如 99 分位延迟）。

示例：使用 Go 的 Prometheus 客户端暴露指标

```go
package main

import (
    "net/http"
    "github.com/prometheus/client_golang/prometheus"
    "github.com/prometheus/client_golang/prometheus/promhttp"
)

// Counter 指标
var requestsTotal = prometheus.NewCounter(
    prometheus.CounterOpts{
        Name: "myapp_requests_total",
        Help: "Total number of requests.",
    },
)

// Gauge 指标
var activeUsers = prometheus.NewGauge(
    prometheus.GaugeOpts{
        Name: "myapp_active_users",
        Help: "Number of active users.",
    },
)

func init() {
    prometheus.MustRegister(requestsTotal)
    prometheus.MustRegister(activeUsers)
}

func handleRequest(w http.ResponseWriter, r *http.Request) {
    requestsTotal.Inc()
    w.Write([]byte("Hello, World!"))
}

func userLogin() {
    activeUsers.Inc()
}

func userLogout() {
    activeUsers.Dec()
}

func main() {
    http.HandleFunc("/", handleRequest)
    http.Handle("/metrics", promhttp.Handler())
    http.ListenAndServe(":8080", nil)
}
```

访问 http://localhost:8080/metrics 可以看到暴露的指标，例如：
```
# HELP myapp_requests_total Total number of requests.
# TYPE myapp_requests_total counter
myapp_requests_total 10

# HELP myapp_active_users Number of active users.
# TYPE myapp_active_users gauge
myapp_active_users 5
```

### 4.2 Kubernetes 核心组件指标
Kubernetes 的核心组件（API Server、kubelet 等）通常会在 /metrics 端点以 Prometheus 格式暴露指标。例如 API Server 会暴露各控制器的工作队列长度、请求 QPS、延迟数据等。

Kubelet 的 /metrics 默认通过 HTTPS 暴露（端口 10250），并启用了认证与授权（RBAC）。访问时通常需要使用 ServiceAccount 的 token 作为 Bearer Token，并确保该 ServiceAccount 有相应权限。由于证书可能不包含节点 IP 的 SAN，在直接 curl 时可能遇到证书校验错误，可以在调试时使用 -k 跳过证书校验（生产环境请使用安全方式）。

示例 curl（调试用）：
```bash
curl -k -H "Authorization: Bearer {token}" https://{node-ip}:10250/metrics
```

使用 Prometheus 采集 kubelet
- 直接使用 Node 服务发现（role: node）自动发现集群中所有 Node，将 kubelet 作为抓取目标。
- 常见的 Prometheus scrape 配置如下（示例，需根据实际环境完善 token 文件路径等）：

```yaml
scrape_configs:
- job_name: kubelet-metrics
  honor_timestamps: true
  metrics_path: /metrics
  scheme: https
  kubernetes_sd_configs:
  - role: node
  bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
  tls_config:
    insecure_skip_verify: true
```

使用 API Server 代理方式抓取 kubelet
- 也可以通过 API Server 的代理 API 访问 kubelet，这样抓取地址统一为 kubernetes.default.svc:443，通过 relabeling 将目标地址替换为 API Server，并把 metrics path 指向 /api/v1/nodes/${node}/proxy/metrics。

示例配置（简化）：
```yaml
scrape_configs:
- job_name: kubelet
  honor_timestamps: true
  metrics_path: /metrics
  scheme: https
  kubernetes_sd_configs:
  - role: node
  bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
  tls_config:
    insecure_skip_verify: true
  relabel_configs:
  - separator: ;
    regex: (.*)
    target_label: __address__
    replacement: kubernetes.default.svc:443
    action: replace
  - source_labels: [__meta_kubernetes_node_name]
    regex: (.+)
    target_label: __metrics_path__
    replacement: /api/v1/nodes/${1}/proxy/metrics
    action: replace
```

通过上述 relabeling，Prometheus 实际访问的是 API Server 的代理地址来获取 kubelet 指标。

### 4.3 使用 Exporter 暴露集群指标
某些 Kubernetes 内部信息或宿主机度量并不直接以 Prometheus 格式暴露，这时需要 Exporter 将这些数据转换为 Prometheus 指标。常用的 Exporter 包括：

- kube-state-metrics：从 Kubernetes API Server 获取资源状态（Pod、Deployment、Service 等），并将其转换为 Prometheus 指标，提供集群的“状态视图”。
  - 可以获取 Pod 状态、Deployment 副本数与可用副本数、Node 的状态与资源分配等。

- node-exporter：收集节点的硬件与操作系统指标，提供 CPU 使用、内存使用、磁盘 I/O、磁盘空间、网络带宽与丢包率等信息。

通过这些 Exporter，可以补完基础组件与应用层的监控数据，构建完整的监控体系。

---

## 5 结语

Kubernetes 组件核心监控、Exporter 与业务监控三者相辅相成：

- 当业务指标（如请求延迟）异常时，可以结合 Kubernetes 资源使用情况（CPU、内存）判断是否为资源不足导致的问题。
- 当 Kubernetes 集群发生故障时，可以通过业务指标判断对业务的影响程度。
- 通过 kube-state-metrics 等 Exporter 可以全面了解集群各资源的数量与状态。

本文深入探讨了 Kubernetes 监控的重要性、关键组件与核心指标，并分析了指标的暴露与采集机制。理解指标来源与暴露机制是确保集群稳定性、性能优化与故障排查的第一步。

后续可以继续探索如何使用 Prometheus 采集这些指标、如何用 Grafana 进行可视化，并结合告警（Alertmanager）实现完整的可观测体系。监控不仅是发现问题，更是预防问题。通过全面监控与深入分析，才能真正释放 Kubernetes 的潜力，为业务提供稳定、高效的运行环境。

---

原创作者｜柯开