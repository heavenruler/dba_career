# 暴揍ELK 痛打Loki - VictoriaLogs 搭建Syslog日志收集存储系统

作者：网工格物  
日期：2025-02-11

## 为什么要用 VictoriaLogs？
- 与 Elasticsearch / Grafana Loki 相比，VictoriaLogs 在 CPU/内存/存储资源占用上有几十倍的差距，能极大地节省硬件资源。
- 单体软件可以实现 ELK 的 Web 查询、日志压缩存储、syslog 日志接收。

官方文档：https://docs.victoriametrics.com/victorialogs/quickstart/

## 具体优势对比

VictoriaLogs 的优势：
1. 资源效率：VictoriaLogs 通常设计为资源高效型，在内存和存储的使用上更为节省。  
2. 高压缩率：存储引擎使用高效的数据压缩技术，减小存储空间需求。  
3. 简单部署和管理：易于部署和管理，适合小型团队或不需要复杂功能的用户。  
4. 面向特定日志场景优化：在其优化场景下性能优秀。

Elasticsearch 的优势：
1. 成熟度和社区支持：ES 是成熟项目，拥有广泛社区支持与丰富文档。  
2. 扩展性：支持大规模集群，能够从小型扩展到大规模应用。  
3. 强大的查询功能：提供丰富的查询语言与功能，适合复杂数据分析。  
4. 广泛生态系统：有大量插件与可视化工具（如 Kibana）。

使用建议：
- 如果需要高效资源使用和简单日志处理，VictoriaLogs 是不错的选择。  
- 如果需要复杂查询能力、大规模数据处理和强大社区支持，Elasticsearch 可能更合适。  
最终选择应基于具体需求、现有基础设施与团队技术能力。

备注：VictoriaLogs 占用内存和硬盘较小、性能高，但功能不如 ES 完善（例如没有完整的集群功能），查询界面较为简陋。

## 部署背景
接收服务器或网络设备发送的 syslog 协议日志，用于存储和日常查询。  
Docker 要求较新版本，支持 Compose v2。

Docker 安装参考（示例）：https://yeasy.gitbook.io/docker_practice/install/centos

## Docker 单容器部署

示例运行命令：
```bash
docker run -d --restart always \
  -p 9428:9428 \
  -p 514:514/udp \
  -v ./victoria-logs-data:/victoria-logs-data \
  --name victoria-logs-syslog \
  docker.io/victoriametrics/victoria-logs:latest \
  -syslog.listenAddr.udp=:514
```

说明：
- 9428 为 HTTP 端口，用于访问 Web UI（默认无安全认证）。  
- 514/udp 为 syslog 接收端口，参数 -syslog.listenAddr.udp=:514 用于开启 UDP 接收 syslog。  
- -v ./victoria-logs-data:/victoria-logs-data 将在当前目录创建数据存储文件夹。

## Docker Compose 部署

在同一目录下创建 `docker-compose.yml`（示例）：

```yaml
version: "3.8"
services:
  victoria-logs-syslog:
    image: docker.io/victoriametrics/victoria-logs:latest
    container_name: victoria-logs-syslog
    restart: always
    ports:
      - "9428:9428"
      - "514:514/udp"
    volumes:
      - ./victoria-logs-data:/victoria-logs-data
    command:
      - '-syslog.listenAddr.udp=:514'
```

部署示例命令：
```bash
mkdir VictoriaLogs
cd VictoriaLogs
mkdir victoria-logs-data
# 创建 docker-compose.yml 并写入上面的内容
docker compose up -d
```

升级/更新示例命令：
```bash
cd VictoriaLogs
docker compose down
docker compose pull
docker compose up -d
```

## VictoriaLogs 日志保留时间
默认情况下，VictoriaLogs 会保留最近一段时间内的日志条目（例如 [now-7d, now]），默认保留 7 天。可以使用命令行标志 `--retentionPeriod` 配置保留时间，该标志接受从 `1d`（一天）到 `100y`（100 年）的值。

例如，以下 Compose 配置将保留 30 天：
```yaml
version: "3.8"
services:
  victoria-logs-syslog:
    image: docker.io/victoriametrics/victoria-logs:latest
    container_name: victoria-logs-syslog
    restart: always
    ports:
      - "9428:9428"
      - "514:514/udp"
    volumes:
      - ./victoria-logs-data:/victoria-logs-data
    command:
      - '-syslog.listenAddr.udp=:514'
      - '--retentionPeriod=30d'
```

启动参数可在 http://localhost:9428/flags 查看（替换为实际访问地址和端口）。

## Web UI 搜索
在浏览器访问 http://localhost:9428（替换为实际地址），选择 "select/vmui - Web UI for VictoriaLogs" 进入。  
查询语法：直接输入关键词可全局搜索，右上角选择时间范围。示例：查询两个关键词可写为 `abc AND bcd`。

日志查询文档（参考）：https://docs.victoriametrics.com/victorialogs/logsql/

## 监控 VictoriaLogs
VictoriaLogs 以 Prometheus 格式公开内部指标，建议通过 VictoriaMetrics 或 Prometheus 采集这些指标。访问路径示例：  
http://localhost:9428/metrics

## 运维与交流
- 运维技术交流群或问题请发邮件：me@songxwn.com  
- 官方博客与更多内容： https://songxwn.com/

（个人观点，仅供参考）