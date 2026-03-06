Docker 部署 MySQL 、 Redis 、 Kafka 、 ES 、
Kibana
⽆奈何杨2025-03-31333阅读 5 分钟 关注
Docker
Docker 的基础概念和安装就不多讲了，参考官⽹学习就⾏。
www.docker.com/
docs.docker.com/engine/inst…
镜像仓库
hub.docker.com/explore
hub.docker.com/search?badg…
hub.docker 已经提供了⾮常多的镜像，⼀般情况来讲使⽤官⽅镜像就好了。
如：hub.docker.com/_/mysql
探 索 稀 ⼟ 掘 ⾦
登录⾸⻚
2025/6/4 凌晨 12:06 Docker 部署 MySQL 、 Redis 、 Kafka 、 ES 、 KibanaDocker Docker 的基础概念和安装就不多讲  - 掘⾦
https://juejin.cn/post/7487219933127245833 1/11

官⽅写的也相当明⽩，如何使⽤镜像，运⾏容器可以配置那些参数，⽇志等
还包括进⼊容器执⾏命名、查看⽂件等等
Docker Compose
Docker Compose 相较于单独使⽤  docker run  命令有很多优势，特别是在管理多容器应⽤
时。
1. 简化复杂环境的配置
多容器管理：当您的应⽤程序由多个服务组成（如前端、后端、数据库等），使⽤  docker
run  需要为每个服务单独启动容器，并⼿动配置它们之间的⽹络和依赖关系。⽽  Docker
Compose  可以通过⼀个简单的  docker-compose.yml  ⽂件定义所有服务及其配置。
统⼀配置⽂件：所有服务的配置都集中在⼀个  YAML  ⽂件中，易于阅读和维护。
2. ⾃动化服务依赖
⾃动处理依赖：在  docker-compose.yml  中可以指定服务之间的依赖关系。例如，您可以
设置  MySQL 服务必须在应⽤服务之前启动。Docker Compose  会确保这些依赖关系得到满
⾜。
重启策略：可以定义重启策略来保证服务的⾼可⽤性，⽐如某个服务失败后⾃动重启。
3. ⽹络配置简化
2025/6/4 凌晨 12:06 Docker 部署 MySQL 、 Redis 、 Kafka 、 ES 、 KibanaDocker Docker 的基础概念和安装就不多讲  - 掘⾦
https://juejin.cn/post/7487219933127245833 2/11

内置⽹络管理：Docker Compose  ⾃动创建⼀个默认⽹络供所有服务使⽤，使得容器间通信
变得⾮常简单。您不需要⼿动创建和管理⽹络。
⾃定义⽹络：虽然可以⼿动创建⽹络并在  docker run  中指定，但  Docker Compose  提供
了更简洁的⽅式来⾃定义⽹络。
4. 环境变量管理
.env ⽂件⽀持：Docker Compose  ⽀持从  .env  ⽂件加载环境变量，这使得管理和切换
不同环境下的配置更加容易。
环境变量⽂件：还可以通过  env_file  指令引⽤外部环境变量⽂件，进⼀步增强灵活性。
5. 卷和绑定挂载的便捷配置
持久化存储：在  Docker Compose  ⽂件中，可以通过简单的声明来配置卷或绑定挂载，从
⽽轻松实现数据持久化。
⼀致的开发与⽣产环境：可以在不同环境中复⽤相同的配置，只需调整少量参数即可适应不
同的部署场景。
6. 命令⾏简化
单命令操作多个容器：使⽤  docker-compose up  即可⼀次性启动所有定义的服务，⽽⽆需
分别执⾏  docker run  命令。
便捷的⽣命周期管理：除了启动服务外，还可以使⽤  docker-compose down  来停⽌并移除
所有相关容器、⽹络和卷。
7. 版本控制友好
YAML 格式便于版本控制：将  docker-compose.yml  ⽂件纳⼊版本控制系统（如  Git ）
中，便于团队协作和历史记录追踪。
回滚⽅便：如果需要恢复到之前的配置版本，只需切换到相应的分⽀或标签即可。
8. 扩展性和伸缩性
轻松扩展服务实例数：通过  docker-compose scale  或者在  docker-compose.yml  中定义
deploy  部分，可以轻松地增加或减少服务实例的数量。
负载均衡：对于Web 应⽤等场景，Docker Compose  能够结合  Docker Swarm  实现负载均
衡。
2025/6/4 凌晨 12:06 Docker 部署 MySQL 、 Redis 、 Kafka 、 ES 、 KibanaDocker Docker 的基础概念和安装就不多讲  - 掘⾦
https://juejin.cn/post/7487219933127245833 3/11

示例对⽐
假设我们要部署⼀个包含  MySQL 和  Redis 的应⽤：
使⽤  docker run
使⽤  Docker Compose
只需运⾏  docker-compose up -d  即可同时启动这两个服务，并且它们之间能够⾃动发现对⽅
（如果在同⼀⽹络下）。
Docker Compose  提供了⼀种更为⾼效、灵活的⽅式来管理和部署复杂的多容器应⽤，特别适
合开发、测试以及⼩规模⽣产环境中的快速部署需求。
示例 Compose
github.com/wnhyang/coo…
也是此项⽬的部署⽅式
.env
体验 AI 代码助⼿
# 启动  MySQL 容器
docker run --name some-mysql -e MYSQL_ROOT_PASSWORD=my-secret-pw -d mysql:tag
# 启动  Redis 容器
docker run --name some-redis -d redis:alpine
1
2
3
4
5
体验 AI 代码助⼿
version: '3'
services:
db:
image: mysql:tag
environment:
MYSQL_ROOT_PASSWORD: my-secret-pw
redis:
image: redis:alpine
1
2
3
4
5
6
7
8
2025/6/4 凌晨 12:06 Docker 部署 MySQL 、 Redis 、 Kafka 、 ES 、 KibanaDocker Docker 的基础概念和安装就不多讲  - 掘⾦
https://juejin.cn/post/7487219933127245833 4/11

docker-compose.yml
体验 AI 代码助⼿
mysql_root_password=mysql_password
mysql_database=mysql_database
mysql_user=mysql_user
mysql_password=mysql_password
redis_password=redis_password
elasticsearch_password=elasticsearch_password
kibana_password=kibana_password
kibana_url=http://localhost:5601
coolguard_image=coolguard_image
1
2
3
4
5
6
7
8
9
体验 AI 代码助⼿
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
28
29
30
31
32
2025/6/4 凌晨 12:06 Docker 部署 MySQL 、 Redis 、 Kafka 、 ES 、 KibanaDocker Docker 的基础概念和安装就不多讲  - 掘⾦
https://juejin.cn/post/7487219933127245833 5/11

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
KAFKA_PROCESS_ROLES: broker,controller
KAFKA_LISTENERS: PLAINTEXT://0.0.0.0:9092,CONTROLLER://0.0.0.0:9093
KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://kafka:9092
KAFKA_CONTROLLER_LISTENER_NAMES: CONTROLLER
KAFKA_LISTENER_SECURITY_PROTOCOL_MAP: CONTROLLER:PLAINTEXT,PLAINTEXT:PLAINTEXT
KAFKA_CONTROLLER_QUORUM_VOTERS: 1@kafka:9093
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
33
34
35
36
37
38
39
40
41
42
43
44
45
46
47
48
49
50
51
52
53
54
55
56
57
58
59
60
61
62
63
64
65
66
67
68
69
70
71
72
73
74
75
76
77
78
79
80
81
82
2025/6/4 凌晨 12:06 Docker 部署 MySQL 、 Redis 、 Kafka 、 ES 、 KibanaDocker Docker 的基础概念和安装就不多讲  - 掘⾦
https://juejin.cn/post/7487219933127245833 6/11

运⾏
在docker-compose.yml 同⽬录执⾏
container_name: kibana
volumes:
- kibanadata:/usr/share/kibana/data
ports:
- "5601:5601"
environment:
ELASTICSEARCH_HOSTS: http://elasticsearch:9200
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
83
84
85
86
87
88
89
90
91
92
93
94
95
96
97
98
99
100
101
102
103
104
105
106
107
108
109
110
111
112
113
114
115
116
117
118
119
120
121
122
123
124
125
2025/6/4 凌晨 12:06 Docker 部署 MySQL 、 Redis 、 Kafka 、 ES 、 KibanaDocker Docker 的基础概念和安装就不多讲  - 掘⾦
https://juejin.cn/post/7487219933127245833 7/11

标签： 后端 话题： 每天⼀个知识点
评论  0
本⽂收录于以下专栏 1 / 2
上⼀篇 免费使⽤满⾎版 DeepSeek-R1… 下⼀篇 开源项⽬更新到个⼈仓库并保…
软件 & ⼯具
分享软件⼯具
6 订阅·9 篇⽂章
订阅
专栏⽬录
0/ 1000 发送
抢⾸评，友善交流
登录  / 注册 即可发布评论！
或指定
-f  参数 指定⽂件的路径
-p  参数 指定项⽬名，默认不指定时使⽤当前⽬录名作为项⽬的名称
体验 AI 代码助⼿
# 单独运⾏
docker compose up -d <service_name>
# ⼀起运⾏
docker compose up -d
1
2
3
4
体验 AI 代码助⼿
docker-compose -f /home/user/projects/myapp/docker-compose.yml -p myapp up -d mysql redi
1
2025/6/4 凌晨 12:06 Docker 部署 MySQL 、 Redis 、 Kafka 、 ES 、 KibanaDocker Docker 的基础概念和安装就不多讲  - 掘⾦
https://juejin.cn/post/7487219933127245833 8/11

暂⽆评论数据
⽬录 收起
Docker
镜像仓库
Docker Compose
1. 简化复杂环境的配置
2. ⾃动化服务依赖
3. ⽹络配置简化
4. 环境变量管理
5. 卷和绑定挂载的便捷配置
6. 命令⾏简化
7. 版本控制友好
8. 扩展性和伸缩性
示例对⽐
使⽤  docker run
使⽤  Docker Compose
示例 Compose
.env
docker-compose.yml
运⾏
相关推荐
为了不再被事务坑，我读透了 Spring 的事务传播性。
885 阅读 · 16 点赞
10 个案例告诉你 mysql 不使⽤⼦查询的原因
517 阅读 · 6 点赞
深⼊理解请求限流算法的实现细节
54 阅读 · 0 点赞
博客：⼋股⽂⽹站验证码解锁与 JWT 登录机制解析 / 前端 Vuex 实现
47 阅读 · 0 点赞
AB 实验：数据驱动决策的科学⽅法
2025/6/4 凌晨 12:06 Docker 部署 MySQL 、 Redis 、 Kafka 、 ES 、 KibanaDocker Docker 的基础概念和安装就不多讲  - 掘⾦
https://juejin.cn/post/7487219933127245833 9/11

59 阅读 · 0 点赞
为你推荐
使⽤ Windows 电脑快速⼊⻔ Docker
Docker 前端 容器蒸汽蘑菇1 年前 1.4k 5 评论
Docker ⼊⻔系列 ⸺DockerFile 的使⽤
前端 Docker叶知秋⽔6 ⽉前 2946 评论
docker 容器由浅⼊深解析
Dockerlcomedy 喜剧 3 年前 3652 评论
Docker 快速⼊⻔
Docker王延领 3 年前 8533 评论
docker ⼊⻔学习⼀
Docker5 ⼤⼤⼤⼤雄3 年前 4001 评论
Docker 系列  - 02 - ⼊⻔  & Nginx 服务  & Docker 概念【合集】
Docker Nginxjsliang 3 年前 1.7k 92
Docker 基础使⽤教程
Docker 后端热⼼市⺠余⽣3 年前 39221
Docker ⼊⻔之 docker 基本命令
后端 运维 Docker讷⾔⼂ 4 ⽉前 1661 评论
docker 技术的安装与应⽤
Docker 后端chensi21133 年前 512 点赞 评论
linux 服务器使⽤ docker 部署 Vue+Egg.js 项⽬
Docker 容器curtain 3 ⽉前 711 评论
Docker ⼊⻔讲解
Docker暗余 4 年前 1.3k 151
深⼊浅出 Docker 应⽤ -Docker Compose 实战
DockerLunaticskytql1 年前 318 点赞 评论
「 Docker 系列」 - Docker 的安装与常⻅命令的使⽤
2025/6/4 凌晨 12:06 Docker 部署 MySQL 、 Redis 、 Kafka 、 ES 、 KibanaDocker Docker 的基础概念和安装就不多讲  - 掘⾦
https://juejin.cn/post/7487219933127245833 10/11

Docker 后端你算哪块⼩蛋糕3 年前 2971 评论
如何使⽤ docker + nginx 来部署前端项⽬
前端 Linux NginxsensFeng 6 ⽉前 1.5k 262
Docker 实战应⽤
DockerJason 学⻓ 4 年前 9375 评论
2025/6/4 凌晨 12:06 Docker 部署 MySQL 、 Redis 、 Kafka 、 ES 、 KibanaDocker Docker 的基础概念和安装就不多讲  - 掘⾦
https://juejin.cn/post/7487219933127245833 11/11

