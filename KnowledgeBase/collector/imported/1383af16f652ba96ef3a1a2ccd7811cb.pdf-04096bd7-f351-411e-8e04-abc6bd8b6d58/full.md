首页 AI Coding 沸点 课程 直播 活动 AI刷题 APP 插件 创作者中心 会员 登录 注册
威哥爱编程
【小白请绕道】Redis 的 I/O 多路复用技术，它是如何 华为HDE，公众号：威哥爱编程
榜上有名 优秀作者
工作的？ 320 206k 481
文章 阅读 粉丝
威哥爱编程 2024-09-24 103 阅读9分钟 专栏： V哥原创技术栈
关注 私信
目录 收起
Redis 的 I/O 多路复用技术是其高性能的关键之一。在单个线程中，Redis 可以同时处理多个网络连接，这
是通过使用 I/O 多路复用技术实现的。这种技术允许 Redis 在单个线程中监听多个套接字，并在套接字准备
I/O 多路复用的工作方式 好执行操作时（如读取或写入），执行相应的操作。
工作方式
I/O 多路复用技术
I/O 多路复用的工作方式 工作流程
Redis 的 Reactor 模式
I/O 多路复用技术，如 、 、 （Linux 上的事件通知机制）， （在 BSD 系统上） select poll epoll kqueue
Reactor 模式的实现原理 等，允许单个线程监视多个套接字。当套接字上的数据准备好读取或写入时，操作系统通知应用程序，然后
Reactor 模式的代码实现 应用程序可以执行相应的读取或写入操作。
性能优化
I/O 多路复用是一种处理多个输入输出通道（通常是网络连接）的技术，它允许单个线程处理多个输入输出 总结
请求。这种方式在网络服务器和其他需要同时处理多个客户端请求的应用程序中非常有用。I/O 多路复用的
关键优势是它能够在单个线程中管理多个连接，而不需要为每个连接创建一个新的线程，从而减少了资源消
耗和上下文切换的开销。 相关推荐
工作方式 Linux I/O多路复用
1.1k阅读 · 3点赞
监听多个通道 ：服务器应用程序使用 I/O 多路复用技术来监听多个通道（例如，客户端的网络连接）。 Redis 和 I/O 多路复用
这些通道可以是套接字（socket）。 3.4k阅读 · 91点赞
I/O复用
监控状态变化 ：I/O 多路复用技术监控这些通道的状态变化，例如是否有数据可读、是否可以写入数据 56阅读 · 0点赞
等。
Redis 和 I/O 多路复用
141阅读 · 1点赞 事件通知 ：当某个通道的状态发生变化，并且该事件符合应用程序设定的监控条件时，操作系统会通知
应用程序。 Redis的I/O多路复用模型
230阅读 · 0点赞
事件处理 ：应用程序接收到通知后，会调用相应的事件处理函数来处理事件。例如，如果一个通道可
读，应用程序可能会读取数据；如果一个通道可写，应用程序可能会写入数据。
精选内容
非阻塞操作 ：在 I/O 多路复用模型中，通道通常被设置为非阻塞模式。这意味着当尝试读取或写入数据
时，如果数据不可用，操作会立即返回，而不是等待。 RocketMQ高级特性实战：Java开发者的进阶指南
33255_40857_28059 · 63阅读 · 0点赞
I/O 多路复用技术 ZGC 执行日志：解锁低延迟运行的核心密码
码出极致 · 23阅读 · 0点赞
select ： 分布式事务在分片场景下，TCC和Seata到底怎么选？一线实战全解析！
我爱娃哈哈 · 41阅读 · 1点赞
是最早的 I/O 多路复用技术之一。 select
大规模Go网络应用的部署与监控
它允许应用程序监视一组文件描述符，以确定它们是否处于可读、可写或异常状态。 Go高并发架构_王工 · 67阅读 · 0点赞
有一个缺点，即它使用一个固定大小的位集合来跟踪文件描述符，这限制了它可以监视 select
HarmonyOS 设备自动发现与连接全攻略：从原理到可运行 Demo 的文件描述符的数量。
zhanshuo · 19阅读 · 0点赞
poll ：
找对属于你的技术圈子 与 类似，但它没有最大文件描述符数量的限制。 poll select
回复「进群」加入官方微信群 不使用位集合，而是使用动态分配的数组来跟踪文件描述符。 poll

epoll （Linux 特定）：
是 Linux 提供的一种高效的 I/O 多路复用技术。 epoll
它不需要在每次调用时重复传递文件描述符集合，而是在初始化时创建一个 文件，然后使 epoll
用它来添加或删除要监视的文件描述符。
能够更高效地处理大量文件描述符，因为它使用内核数据结构来跟踪状态变化。 epoll
kqueue （BSD 系统）：
是在 BSD 系统（如 macOS 和 FreeBSD）上的一种高效的 I/O 多路复用技术。 kqueue
它允许应用程序注册要监视的事件，并且可以处理多种类型的事件，包括文件描述符事件和定时
器事件。
工作流程
初始化 ：应用程序初始化一个 I/O 多路复用实例（例如，创建一个 实例或设置一个 调 epoll select
用）。
注册文件描述符 ：应用程序将需要监视的文件描述符注册到 I/O 多路复用实例中。
等待事件 ：应用程序调用 I/O 多路复用函数（如 、 、 或 ），并等 select poll epoll_wait kevent
待事件的发生。
处理事件 ：当事件发生时，操作系统通知应用程序，应用程序根据事件类型调用相应的事件处理函数。
循环 ：应用程序在一个循环中重复执行上述步骤，以持续监听和处理事件。
I/O 多路复用技术是构建高性能网络服务器的关键，它使得服务器能够有效地处理大量并发连接，同时保持
资源使用的高效性。
Redis 的 Reactor 模式
Redis 的 Reactor 模式是其高性能网络事件处理器的核心。这种模式基于事件驱动，使用非阻塞 I/O 多路复
用技术来同时监控多个套接字，并在套接字准备好执行操作时（如读取或写入），执行相应的事件处理函
数。
Reactor 模式的实现原理
事件分派器（Reactor） ：这是模式的核心，负责监听和分发事件。在 Redis 中，Reactor 通过 I/O 多路
复用技术（如 、 、 ）来监控多个套接字，并将发生的事件分派给相应的事件 epoll select kqueue
处理器。
事件处理器 ：这些是处理具体事件的函数，如读取客户端请求、发送响应等。在 Redis 中，事件处理器
包括连接应答处理器、命令请求处理器和命令回复处理器。
事件创建器 ：用于添加新事件或删除不再需要的事件。
Reactor 模式的代码实现
在 Redis 中，Reactor 模式的实现代码主要在 文件中。我们通过一个简化的示例，来解释使用 ae.c
实现 Reactor 模式的基本工作流程，先来看一下整体，我们再分段解释： epoll

c 体验AI代码助手 代码解读 复制代码
int epfd = epoll_create1( 0 );
if (epfd == -1 ) {
perror( "epoll_create1" );
exit (EXIT_FAILURE);
}
struct epoll_event event , events [ MAX_EVENTS ];
// 设置事件
event.events = EPOLLIN | EPOLLET;
event.data.fd = STDIN_FILENO;
if (epoll_ctl(epfd, EPOLL_CTL_ADD, STDIN_FILENO, &event) == -1 ) {
perror( "epoll_ctl" );
exit (EXIT_FAILURE);
}
// 事件循环
while ( 1 ) {
int nfds = epoll_wait(epfd, events, MAX_EVENTS, -1 );
if (nfds == -1 ) {
perror( "epoll_wait" );
exit (EXIT_FAILURE);
}
for ( int n = 0 ; n < nfds; ++n) {
if (events[n].events & EPOLLIN) {
handle_read(events[n].data.fd);
}
}
}
close(epfd);
return 0 ;
在这个示例中， 创建一个新的 实例， 用于添加需要监听的事件， epoll_create1 epoll epoll_ctl
等待事件发生，并在事件发生时调用 函数来处理读取操作。 epoll_wait handle_read
下面来具体分段解释：
创建 epoll 实例 ：
c 体验AI代码助手 代码解读 复制代码
int epfd = epoll_create1( 0 );
if (epfd == -1 ) {
perror( "epoll_create1" );
exit (EXIT_FAILURE);
}
创建一个新的 实例，并返回一个文件描述符 ，用于后续的事件管 epoll_create1(0) epoll epfd
理。
如果创建失败，打印错误信息并退出程序。
定义事件结构 ：
c 体验AI代码助手 代码解读 复制代码
struct epoll_event event , events [ MAX_EVENTS ];
是 事件的基本数据结构，用于描述要监视的事件及其相关数据。 struct epoll_event epoll
数组用于存储 返回的事件。 events epoll_wait
设置要监视的事件 ：
c 体验AI代码助手 代码解读 复制代码
event.events = EPOLLIN | EPOLLET;
event.data.fd = STDIN_FILENO;
if (epoll_ctl(epfd, EPOLL_CTL_ADD, STDIN_FILENO, &event) == -1 ) {
perror( "epoll_ctl" );
exit (EXIT_FAILURE);
}
设置为 ： event.events EPOLLIN | EPOLLET
表示要监视可读事件。 EPOLLIN
表示使用边缘触发（Edge Triggered）模式，只有在状态变化时才会通知。 EPOLLET
设置为 ，表示监视标准输入。 event.data.fd STDIN_FILENO
函数将标准输入的事件添加到 实例中。 epoll_ctl epoll
事件循环 ：

c 体验AI代码助手 代码解读 复制代码
while ( 1 ) {
int nfds = epoll_wait(epfd, events, MAX_EVENTS, -1 );
if (nfds == -1 ) {
perror( "epoll_wait" );
exit (EXIT_FAILURE);
}
for ( int n = 0 ; n < nfds; ++n) {
if (events[n].events & EPOLLIN) {
handle_read(events[n].data.fd);
}
}
}
阻塞地等待事件的发生，返回发生事件的数量 。 epoll_wait nfds
如果 为负，表示出错，打印错误信息并退出。 nfds
遍历 数组，处理每个发生的事件： events
检查事件类型是否为可读事件（ ）。 EPOLLIN
调用 函数处理可读事件，通常用于读取数据。 handle_read
关闭 epoll 实例 ：
c 体验AI代码助手 代码解读 复制代码
close(epfd);
return 0 ;
关闭 文件描述符，释放资源。 epoll
实现逻辑和原理是这样的：
I/O 多路复用 ：通过 ，程序可以在单个线程中同时监听多个文件描述符（如网络套接字），从而 epoll
高效地处理并发连接。
事件驱动 ：当某个文件描述符的状态发生变化（如有数据可读）， 会通知应用程序，应用程序随 epoll
后可以处理这些事件。
边缘触发模式 ：使用 使得应用程序在状态变化时才会被通知，减少了不必要的事件通知，提 EPOLLET
高了性能。
单线程处理 ：通过单线程模型，避免了多线程带来的上下文切换和同步开销，使得处理逻辑更加简单。
性能优化
在高并发场景下，可以通过以下方式优化 Lettuce 的性能（需要对Lettuce有认识哈）：
连接池配置 ：合理配置连接池的大小，以适应并发需求。
使用 Pipeline ：通过 Pipeline 批处理命令，减少网络往返次数。
集群支持 ：在 Redis 集群环境中，确保客户端配置正确，以优化性能。
监控和调优 ：使用监控工具跟踪性能指标，并根据需要调整配置。
通过这些机制，Redis 的 Reactor 模式能够在高并发场景下保持高性能，同时提供线程安全的操作和良好的
用户体验。
总结
使用 I/O 多路复用技术，Redis 可以高效地处理大量并发连接，而不需要为每个连接创建新的线程，这减少
了线程切换的开销，并提高了性能。此外，Redis 6.0 引入了多线程来处理客户端的请求和回复，进一步提
高了性能。
Redis 的 I/O 多路复用技术是其高性能的关键因素之一。通过在单个线程中处理多个网络事件，Redis 能够
以极高的效率服务于大量的客户端连接。这种技术的应用，使得 Redis 成为一个非常快速且可扩展的内存数
据库解决方案。
标签： Redis C语言 话题： 金石计划征文活动
本文收录于以下专栏
V哥原创技术栈 专栏目录
订阅 本专栏收集 V 哥后端开发高阶内容，包括设计模式、源码剖析、算法与数据结构、高并发、分布式、鸿蒙NEXT、经验分享、招聘内推、人脉链接。
· 70 订阅 314 篇文章
Redis 的 Java 客户端有哪些？官方推荐哪个？ 蚂蚁Raft一致性算法库SOFAJRaft深入分析 上一篇 下一篇

评论 0
登录 / 注册 即可发布评论！
0 / 1000 发送
暂无评论数据
为你推荐
Redis 和 I/O 多路复用
CryptoPunk 6年前 350 2 评论 Redis
Redis的I/O多路复用模型
用户9381691255360 2年前 230 点赞 评论 Redis
神奇快递员——Redis的非阻塞I/O与多路复用技术解析
AI滚雪球 2年前 165 点赞 评论 后端 Redis 数据库
Redis为何那么快？/多路I/O复用模型，非阻塞IO
二十六画生的博客 4年前 1.2k 6 1 Redis
彻底理解 IO 多路复用实现机制
一角钱技术 4年前 55k 153 11 Netty
I/O多路复用的三种实现
StackOverFlow 2年前 797 6 评论 Linux Java
Redis 为什么这么快，你知道 I/O 多路复用吗？
程序员祝融 2年前 2.5k 11 7 Redis 掘金·日新计划 后端
为什么 Redis 的查询很快, Redis 如何保证查询的高效
LiZ 3年前 178 1 评论 Redis
网络模型中的I/O多路复用
pascal_lin 3年前 126 点赞 评论 设计模式
Linux的I/O 模式之多路复用
Linn 5年前 717 10 评论 Linux 操作系统
网络编程(三)：I/O多路复用
XuDT 5年前 1.2k 5 评论 Java
动图了解I/O多路复用
菜刚RyuGou 5年前 4.7k 19 3 Linux
【732、Redis 是单线程的吗，为什么使用单线程还那么快？】
lfsun666 2年前 74 1 评论 后端
聊聊redis、epoll和多路IO复用之间的总总关系
bangiao 2年前 476 点赞 评论 Redis Java
Redis的I/O模型
尼古拉斯小六子 2年前 175 点赞 评论 Redis

