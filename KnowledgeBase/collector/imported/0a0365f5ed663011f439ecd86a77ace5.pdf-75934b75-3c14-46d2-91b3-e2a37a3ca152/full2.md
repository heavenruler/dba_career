# 用 Docker-Compose / K8s 快速安装 MySQL 和 Redis

作者：kevinyan · 2025-02-09

项目开发中最常用的就是 MySQL 和 Redis。在介绍项目的 ORM、Redis 集成和配置之前，先说明如何在本地开发环境中快速搭建这两个服务。

## 电脑环境准备

这里介绍两种容器化安装方式：

- 使用 Docker-Compose 安装 MySQL 和 Redis
- 使用 K8s 安装 MySQL 和 Redis

不管用哪种方法，电脑上都需要提前安装 Docker。推荐安装 Docker Desktop（带可视化界面和可选单节点 Kubernetes）。如果电脑性能一般或对 K8s 不熟悉，建议优先使用 Docker-Compose。

如果你电脑上已经安装过 MySQL/Redis，就不必重复安装，保留原有环境即可。

## 使用 Docker-Compose 安装 MySQL 和 Redis

Docker-Compose 可以把容器运行配置集中写在一个 YAML 文件里，方便启动和管理多个服务。相比直接使用 `docker run`，Compose 更方便管理多服务开发环境。

示例：使用 `docker run` 启动 nginx 的命令示例
```bash
docker run -d -p 8080:80 -v /host/data:/data --name webserver nginx
```

而用 Docker-Compose，可以把配置写到 YAML 文件中，例如：
```yaml
services:
  nginx:
    image: nginx:latest
    ports:
      - "8080:80"
    volumes:
      - /host/data:/data
    restart: always
```
启动时切换到 YAML 文件所在目录，执行 `docker-compose up -d` 即可。

下面给出用于在本地启动 MySQL 和 Redis 的 Compose 文件示例（version: '2'）：

```yaml
version: '2'
services:
  # MySQL
  database:
    platform: linux/x86_64
    image: mysql:5.7
    volumes:
      - dbdata:/var/lib/mysql
    environment:
      - "MYSQL_DATABASE=go_mall"
      - "MYSQL_USER=user"
      - "MYSQL_PASSWORD=secret"
      - "MYSQL_ROOT_PASSWORD=superpass"
      - "TZ=Asia/Shanghai"
    ports:
      - "30306:3306"

  # Redis
  redis:
    platform: linux/x86_64
    image: redis
    command: ["redis-server", "--requirepass", "123456"]
    environment:
      - REDIS_DISABLE_COMMANDS=FLUSHDB,FLUSHALL
    ports:
      - "31379:6379"
    volumes:
      - redis_data:/data

volumes:
  dbdata:
    driver: local
  redis_data:
    driver: local
```

说明：
- MySQL
  - 使用 mysql:5.7，数据库名为 `go_mall`，设置了 root 和普通用户密码，时区为 Asia/Shanghai（保证插入时间戳正确）。
  - 主机端口 30306 映射到容器的 3306。
- Redis
  - 主机端口 31379 映射到容器的 6379。
  - 通过参数指定了访问密码（示例为 `123456`），并禁用了危险的命令 FLUSHDB/FLUSHALL。
  - 数据卷持久化到本地卷 `redis_data`。

将上述 Compose 文件保存到本地目录后，执行：
```bash
cd $compose_dir  # 切换到 compose 文件所在目录
docker-compose up -d
```

启动完成后，可以使用本地的 MySQL 和 Redis 客户端连接：
- Redis 客户端连接示例：Host：127.0.0.1，Port：31379，Password：在配置文件中设置的密码。
- MySQL 客户端连接示例：Host：127.0.0.1，Port：30306，使用在环境中配置的用户名/密码连接。

只要不删除容器或卷，重启电脑后写入的数据不会丢失。对于只需本地开发环境且不想单独安装软件的场景，Docker-Compose 是个简单且轻量的选择。

## 使用 K8s 安装 MySQL 和 Redis

Kubernetes 的资源较多、概念较多，配置和管理也更复杂，但在集群环境或需要更强部署能力时更合适。如果你对 K8s 不熟悉，建议先学习基础概念和常用资源类型（Deployment、Service、PersistentVolume、Secret 等）。

在 K8s 中启动服务，需要准备资源定义文件（YAML），通常包括 Deployment/StatefulSet、Service、ConfigMap/Secret、PersistentVolumeClaim 等。你可以根据项目的配置（例如 application.dev.yaml 中的 MySQL/Redis 配置）编写对应的 K8s 声明文件，并按步骤在集群中应用这些配置来启动服务。

（此处略去具体 K8s 配置示例，实际可根据项目需求编写 StatefulSet + PVC + Service 等资源来部署 MySQL 和 Redis。）

## 小结

- 如果只是本地开发或电脑性能有限，推荐使用 Docker-Compose，简单、开箱即用，对资源要求低。
- 如果需要在集群环境部署或需要更多可扩展性与高可用性，可以使用 Kubernetes，但需准备更多的资源定义并了解 K8s 的基本概念与操作。

---

本内容节选自专栏《Go项目搭建和整洁开发实战》。本专栏注重实战技巧与示例，涵盖项目架构、认证体系、商城功能实现、单元测试与部署等内容。专栏主要内容概览：

1. 实战技巧：自定义日志门面、请求追踪信息、可扩展的错误处理机制等。
2. 项目分层：分层架构设计与模块划分标准。
3. 用户认证：多平台登录、Token 泄露检测、同平台多设备互踢等认证体系实现。
4. 商城模块实战：订单结算、促销、支付等复杂业务场景的分层实现与设计模式应用。
5. 项目运维：单元测试、Docker 镜像构建、K8s 部署与服务保障注意事项。

标签：后端、Docker、Kubernetes