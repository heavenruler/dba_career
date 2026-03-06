登录 注册 首页 AI Coding 沸点 课程 直播 活动 AI刷题 APP 插件 创作者中心 会员
kevinyan
用Docker-Compose / K8s 快速安装MySQL 和 Redis 公众号「网管叨bi叨」
榜上有名 优秀作者 签约作者
kevinyan 2025-02-09 205 阅读7分钟 专栏： Go项目搭建和整洁开发实战 278 930k 1.6k
文章 阅读 粉丝
关注 私信
项目开发中最常用的就是MySQL和Redis了，咱们的实战项目的需求开发过程中也依赖这两个基础环境。所
以在继续介绍项目的ORM、Redis的集成和配置之前我们先花一点时间说一下怎么在自己电脑的开发环境中 目录 收起
安装MySQL和Redis。
电脑环境准备
这里我们介绍两种容器化安装他们的方式：
使用Docker-Compose 安装MySQL 和 Redis
使用Docker-Compose 安装MySQL 和 Redis 使用 K8s 安装MySQL 和 Redis
使用 K8s 安装MySQL 和 Redis
如果你自己电脑上已经安装过这两个软件，那么完全没必要再安装这里介绍的方式重新安装一遍，保持你电 相关推荐
脑上原来的环境即可，没必要推到重来。
Docker安装Mysql和Redis以及构建部署应用镜像
如果你对K8s还不太清楚或者电脑性能一般，推荐用Docker-Compose 来安装这些软件。 6.4k阅读 · 23点赞
使用docker-compose构建管理MySQL和redis
电脑环境准备 1.3k阅读 · 10点赞
docker-compose编排部署多服务Web应用(python/fastapi,
3.8k阅读 · 4点赞 不管用哪种方法，电脑上都需要提前安装一个Docker。这里推荐你安装一个 Docker Desktop， 下载地址：
www.docker.com/products/do… [Docker实践系列-02]利用DockerCompose编排完整的PHP开发环境
5.2k阅读 · 22点赞
主要原因是它安全起来简单，而且还有可视化界面让我们能对容器进行管理。
用docker-compose编排微服务
829阅读 · 2点赞
精选内容
当你配置了feign.sentinel.enable=true时发生什么
ruokkk · 34阅读 · 0点赞
FastSoyAdmin导出excel报错‘latin-1‘ codec can‘t encode characters
Abadbeginning · 29阅读 · 0点赞
12、Python项目实战
anthem37 · 31阅读 · 0点赞
7、Python高级特性 - 提升代码质量与效率 另外如果你不想在电脑上安装K3s、Kind 这些轻量级的K8s集群的话，Docker Desktop 自带一个单节点的
anthem37 · 27阅读 · 0点赞 Kubernetes 集群。
6、Python文件操作与异常处理
在安装好 Docker Desktop 打开软件后，像下图这样选择配置 Tab 页，然后点进 Kubernetes 菜单。 anthem37 · 26阅读 · 1点赞

找对属于你的技术圈子
回复「进群」加入官方微信群
点击菜单后，会有一个选项叫做“Enable Kubernetes”，它下面有行小字提示“Start a Kubernetes single-
node cluster when starting Docker Desktop”， 告诉我们选中后会在Docker Desktop 启动时启动一个单节
点的Kubernetes 集群。
我们选中并 “Apply & Start” 即可，安装的过程会有些慢，有可能因为网络问题中断。
Docker Desktop 自带 Kubernetes 功能的优点是：最简单，开箱即用， 缺点则是：只支持单节点 K8S，且
K8S 部分功能不支持，不易定制。但是对于我们来说够用了。
使用Docker-Compose 安装MySQL 和 Redis
首先安装了Docker Desktop 后，因为它里面自带了Docker CLI，所以安装后，你在电脑终端里直接输入
docker 或者 docker-compose 命令是能识别到的。
Docker-Compose 与你直接使用docker run 启动命令的主要区别是：当我们使用docker run 命令运行启动
一个容器时，通常需要在命令参数中指定的镜像名、容器名、端口映射、数据卷挂载等选项，比如下面这个
运行nginx 容器的docker run 命令。
bash 体验AI代码助手 代码解读 复制代码
docker run -d -p 8080:80 -v /host/data:/data --name webserver nginx
而用Docker-Compose时这些配置选项都可以放在一个YAML文件里声明里

yaml 体验AI代码助手 代码解读 复制代码
services:
nginx:
image: nginx:latest
ports:
- "8080:80"
volumes:
- /host/data:/data
restart: always
启动时，只需要把工作目录切换到 YAML 所在的目录然后执行 docker-compose up -d 就行了，docker-
compose会读取文件里的配置然后按里面的定义去启动容器。
除此之外，它还能在一个文件里定义多个服务，有点容器编排的意思，但是没K8s那么强大，不过用来搭开
发环境挺方便的。
了解Docker-Compose 大概是什么东西后，我们来看一下怎么用它来在自己电脑上安装MySQL和Redis的环
境。
这里我直接给出这两个服务的compose文件。
bash 体验AI代码助手 代码解读 复制代码
version: '2'
services:
# Database
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
environment:
- REDIS_ARGS= "--requirepass 123456"
- REDIS_DISABLE_COMMANDS=FLUSHDB,FLUSHALL
ports:
- '31379:6379'
volumes:
- 'redis_data:/bitnami/redis/data'
volumes:
dbdata:
driver: local
redis_data:
driver: local
这里我们设置了：
MySQL
版本为5.7，数据库名为go_mall, MySQL的时区是Shanghai时区保证插入数据时current timestamp
不会显示成0时区，英国那个格林尼治时间，此外还设置了root用户和一个普通用户的密码。
端口映射为电脑的30306端口映射到 容器里的3306 端口。
Redis：
端口映射为电脑的31379 端口映射到容器里的6379端口。
Redis访问需要密码，密码大家可以自行更改。
这些设置都跟咱们项目中配置文件 application.dev.yaml中 的相关配置保持了一致。接下来我们要做的就是
把这个compose文件保存到自己电脑上，可以访问下面这个链接拿到compose还有接下来要说的K8s服务的
配置文件。
配置文件下载 github.com/go-study-la…
把compose配置保存到你自己的电脑上后需要执行下面的命令

bash 体验AI代码助手 代码解读 复制代码
cd $compose_dir // 切换到compose文件所在目录
docker-compose up -d
启动完成后我们可以在电脑上使用MySQL和Redis的客户端来连接它们。比在Redis客户端里新建连接信息
里输入Host：127.0.0.1，Port：31379，密码刚才在配置文件里看到过。
这样就能用Redis客户端打开本地开发环境的Redis服务，进而自己操作了。
开发环境的MySQL和Redis就安装好后，只要不主动删除容器，即使重启电脑写入的数据也不会丢失的，所
以如果你的电脑上还没有安装开发需要的环境，并且嫌一个个去安装太烦的话，我推荐你使用Docker-
Compose这种方式，除了操作简单外对电脑的性能要求也比较低。
使用 K8s 安装MySQL 和 Redis
K8s里边的东西比较多，各种资源都抽象成了对象，所以如果你对K8s还不够了解的话建议你先看一下我之
前写的入门科普的文章，先对它有个了解。
K8s也面向对象？学会这三要素，用K8s就跟编程一样
在K8s集群里边启动服务，需要先有服务的定义文件，我根据项目application.dev.yaml 中对MySQL和Redis
的配置做了MySQL和Redis服务的声明文件，也放在了刚才的资源文件链接中： github.com/go-study-la…
，具体的操作步骤也有写，大家可以安装里面的步骤进行操作，该文件订阅专栏后才能访问。
本文节选自我的专栏《Go项目搭建和整洁开发实战》， 本专栏力主实战技能，配备完整的实战项目，访问
xiaobot.net/p/golang 即可订阅 ， 订阅后，可加入专栏配套的实战项目，获得完整实战教程，同时也有专
属的读者群，欢迎加入一起学习 。

本专栏分为五大部分，大部分内容已经更新完成
第一部分介绍让框架变得好用的诸多实战技巧，比如通过自定义日志门面让项目日志更简单易用、支持
自动记录请求的追踪信息和程序位置信息、通过自定义Error在实现Go error接口的同时支持给给错误添
加错误链，方便追溯错误源头。
第二部分：讲解项目分层架构的设计和划分业务模块的方法和标准，让你以后无论遇到什么项目都能按
这套标准自己划分出模块和逻辑分层。后面几个部分均是该部分所讲内容的实践。
第三部分：设计实现一个套支持多平台登录，Token泄露检测、同平台多设备登录互踢功能的用户认证
体系，这套用户认证体系既可以在你未来开发产品时直接应用
第四部分：商城app C端接口功能的实现，强化分层架构实现的讲解，这里还会讲解用责任链、策略和
模版等设计模式去解决订单结算促销、支付方式支付场景等多种多样的实际问题。
第五部分：单元测试、项目Docker镜像、K8s部署和服务保障相关的一些基础内容和注意事项
标签： 后端 Docker Kubernetes
本文收录于以下专栏
Go项目搭建和整洁开发实战 专栏目录
订阅 从零搭建出一个健壮性、可维护性、可观测性良好的GO项目框架
· 35 订阅 12 篇文章
Go Gin 项目实战-API路由的分模块管理 GORM 在项目中的初始化、重要连接参数和多数据源配置 上一篇 下一篇
评论 0
登录 / 注册 即可发布评论！
0 / 1000 发送
暂无评论数据

为你推荐
CentOs7 Redis6.0.6安装
知了堂 4年前 422 1 评论 Redis
如何实现项目代码的自动拉取、打包并部署？
MuShanYu 1年前 1.7k 17 4 Java
【Redis】Linux安装redis及五大数据类型
抢老婆酸奶的小肥仔 2年前 384 1 评论 后端 Java
90%程序员都不知道，Redis为什么会默认16个数据库
Java小叮当 4年前 2.2k 7 8 Java Redis
在centos中安装MYSQL、Redis、MongDB、Conda等环境
pycode 11月前 291 点赞 评论 CentOS 服务器
Docker 部署 MySQL 实战
源滚滚编程 8月前 228 1 评论 后端
【批处理】- 批处理自动安装Mysql与Redis
怒放吧德德 2年前 1.2k 1 评论 命令行
Docker 安装 Redis 并外置数据文件
鳄鱼儿 1年前 1.3k 点赞 2 后端
Redis在Linux服务器上编译安装与配置
守望时空33 4年前 1.1k 3 1 Redis
docker compose redis 6.x安装启动 单机 sentinel哨兵 cluster集群 超详细介绍
howa 1年前 587 1 评论 后端 Redis Docker
Redis7系列：Redis对决Redis Stack
SimonKing 5月前 618 5 评论 Redis 后端
记录一次前后端发版工作
刘_小_二 1年前 328 2 评论 后端
Redis快速入门
freejackman 7月前 137 1 评论 后端 Redis
docker-compose实战-容器任务编排
北鸟南游 2年前 1.4k 2 评论 前端 Docker
深入了解Redis：配置文件、动态修改和安全设置
全栈技术蜜糖罐 1年前 902 2 评论 Redis 后端 Java

