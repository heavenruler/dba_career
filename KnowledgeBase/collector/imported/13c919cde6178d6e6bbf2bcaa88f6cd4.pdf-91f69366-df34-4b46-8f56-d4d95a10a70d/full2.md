# Docker 部署 MySQL、Redis、Kafka、Elasticsearch、Kibana

作者：⽆奈何杨 · 2025-03-31 · 333 阅读 · 5 分钟

Docker 的基础概念和安装不在此详述，参考官方文档学习即可。镜像仓库（如 Docker Hub）已经提供了大量镜像，一般使用官方镜像即可，例如 mysql 官方镜像。

## 镜像仓库
Docker Hub 提供了非常多的镜像，通常使用官方镜像就足够了（例如 mysql 官方镜像）。

## Docker Compose
Docker Compose 相较于单独使用 docker run 命令有很多优势，特别是在管理多容器应用时：

1. 简化复杂环境的配置  
   - 多容器管理：应用由多个服务组成时，使用 docker run 需要为每个服务单独启动容器并手动配置网络和依赖。Docker Compose 可以通过一个 docker-compose.yml 文件定义所有服务及其配置。  
   - 统一配置文件：所有服务的配置集中在一个 YAML 文件中，易于阅读和维护。

2. 自动化服务依赖  
   - 可以在 docker-compose.yml 中指定服务之间的依赖关系，Compose 会确保这些依赖得到满足。  
   - 可以定义重启策略以保证服务高可用，例如服务失败后自动重启。

3. 网络配置简化  
   - 内置网络管理：Docker Compose 自动创建一个默认网络供所有服务使用，使容器间通信变得非常简单。  
   - 自定义网络：也可以在 Compose 文件中自定义网络配置。

4. 环境变量管理  
   - 支持从 .env 文件加载环境变量，便于管理和切换不同环境配置。  
   - 还可以通过 env_file 引用外部环境变量文件，增强灵活性。

5. 卷和绑定挂载的便捷配置  
   - 在 Compose 文件中可以声明卷或绑定挂载，实现数据持久化。  
   - 可在不同环境中复用相同配置，仅需调整少量参数。

6. 命令行简化  
   - 使用 docker compose up 即可一次性启动所有定义的服务，无需分别执行 docker run。  
   - 使用 docker compose down 停止并移除所有相关容器、网络和卷。

7. 版本控制友好  
   - YAML 格式便于纳入版本控制（如 Git），便于团队协作和历史追踪。  
   - 回滚配置只需切换到相应分支或标签即可。

8. 扩展性和伸缩性  
   - 可通过 docker compose scale 或在 docker-compose.yml 中定义 deploy 部分来扩展服务实例数。  
   - 在需要时可结合 Docker Swarm 实现负载均衡。

## 示例对比
假设要部署一个包含 MySQL 和 Redis 的应用：

- 使用 docker run：需要分别执行多个 docker run 命令并手动配置网络。
- 使用 Docker Compose：只需一个 docker-compose.yml，然后运行 docker compose up -d 即可同时启动多个服务并让它们在同一网络下自动发现对方。

Docker Compose 更适合开发、测试以及小规模生产环境中的快速部署需求。

## 简单示例

使用 docker run：
```bash
# 启动 MySQL 容器
docker run --name some-mysql -e MYSQL_ROOT_PASSWORD=my-secret-pw -d mysql:tag

# 启动 Redis 容器
docker run --name some-redis -d redis:alpine
```

简单的 docker-compose 示例：
```yaml
version: '3'
services:
  db:
    image: mysql:tag
    environment:
      MYSQL_ROOT_PASSWORD: my-secret-pw
  redis:
    image: redis:alpine
```

## .env 示例
```env
mysql_root_password=mysql_password
mysql_database=mysql_database
mysql_user=mysql_user
mysql_password=mysql_password
redis_password=redis_password
elasticsearch_password=elasticsearch_password
kibana_password=kibana_password
kibana_url=http://localhost:5601
coolguard_image=coolguard_image
```

## docker-compose.yml（完整示例）
```yaml
version: '3'
services:
  mysql:
    image: mysql:8.0.36
    container_name: mysql
    volumes:
      - mysqldata:/var/lib/mysql
    ports:
      - "3306:3306"
    environment:
      MYSQL_ROOT_HOST: 'localhost'
      TZ: Asia/Shanghai
      MYSQL_ROOT_PASSWORD: ${mysql_root_password}
      MYSQL_DATABASE: ${mysql_database}
      MYSQL_USER: ${mysql_user}
      MYSQL_PASSWORD: ${mysql_password}
    networks:
      - custom_network

  redis:
    image: redis:7.2.7-alpine
    container_name: redis
    command: redis-server --requirepass ${redis_password}
    volumes:
      - redisdata:/data
    ports:
      - "6379:6379"
    environment:
      TZ: Asia/Shanghai
    networks:
      - custom_network

  kafka:
    image: apache/kafka:3.7.0
    container_name: kafka
    volumes:
      - kafkadata:/var/lib/kafka/data
    ports:
      - "9092:9092"
      - "9093:9093"
    environment:
      KAFKA_NODE_ID: 1
      KAFKA_LOG_DIRS: /var/lib/kafka/data
      KAFKA_METADATA_LOG_REPLICATION_FACTOR: 1
      KAFKA_DEFAULT_REPLICATION_FACTOR: 1
      KAFKA_PROCESS_ROLES: "broker,controller"
      KAFKA_LISTENERS: "PLAINTEXT://0.0.0.0:9092,CONTROLLER://0.0.0.0:9093"
      KAFKA_ADVERTISED_LISTENERS: "PLAINTEXT://kafka:9092"
      KAFKA_CONTROLLER_LISTENER_NAMES: CONTROLLER
      KAFKA_LISTENER_SECURITY_PROTOCOL_MAP: "CONTROLLER:PLAINTEXT,PLAINTEXT:PLAINTEXT"
      KAFKA_CONTROLLER_QUORUM_VOTERS: "1@kafka:9093"
      KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR: 1
      KAFKA_TRANSACTION_STATE_LOG_REPLICATION_FACTOR: 1
      KAFKA_TRANSACTION_STATE_LOG_MIN_ISR: 1
      KAFKA_GROUP_INITIAL_REBALANCE_DELAY_MS: 0
      KAFKA_NUM_PARTITIONS: 3
      TZ: Asia/Shanghai
    networks:
      - custom_network

  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:8.17.3
    container_name: elasticsearch
    volumes:
      - esdata:/usr/share/elasticsearch/data
    ports:
      - "9200:9200"
      - "9300:9300"
    environment:
      ES_JAVA_OPTS: "-Xms1g -Xmx1g"
      discovery.type: single-node
      ELASTIC_PASSWORD: ${elasticsearch_password}
      xpack.security.enabled: "true"
      xpack.security.http.ssl.enabled: "false"
      xpack.security.transport.ssl.enabled: "false"
      TZ: Asia/Shanghai
    networks:
      - custom_network

  kibana:
    depends_on:
      - elasticsearch
    image: docker.elastic.co/kibana/kibana:8.17.3
    container_name: kibana
    volumes:
      - kibanadata:/usr/share/kibana/data
    ports:
      - "5601:5601"
    environment:
      ELASTICSEARCH_HOSTS: "http://elasticsearch:9200"
      ELASTICSEARCH_USERNAME: kibana
      ELASTICSEARCH_PASSWORD: ${kibana_password}
      SERVER_PUBLICBASEURL: ${kibana_url}
      XPACK_SECURITY_ENABLED: "true"
      XPACK_SECURITY_HTTP_SSL_ENABLED: "false"
      TZ: Asia/Shanghai
    networks:
      - custom_network

  coolguard:
    image: ${coolguard_image}
    container_name: coolguard
    volumes:
      - /docker/coolguard/logs:/coolguard/logs
    ports:
      - "8081:8081"
    environment:
      - "SPRING_PROFILES_ACTIVE=demo"
    networks:
      - custom_network

volumes:
  mysqldata:
    driver: local
  redisdata:
    driver: local
  kafkadata:
    driver: local
  esdata:
    driver: local
  kibanadata:
    driver: local

networks:
  custom_network:
    driver: bridge
```

## 运行
在包含 docker-compose.yml 的目录下执行：

- 启动所有服务：
```bash
docker compose up -d
```

- 单独启动某个服务：
```bash
docker compose up -d <service_name>
```

- 使用指定文件和项目名启动（兼容旧版 docker-compose 命令）：
```bash
docker-compose -f /home/user/projects/myapp/docker-compose.yml -p myapp up -d mysql redis
```

以上为一个常见的本地多服务开发/测试环境示例，根据实际需求调整镜像版本、环境变量和持久化路径即可。