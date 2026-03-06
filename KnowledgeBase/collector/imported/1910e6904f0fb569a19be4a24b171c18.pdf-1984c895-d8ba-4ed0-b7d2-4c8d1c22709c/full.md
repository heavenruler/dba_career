博客 下载 学习 社区 GitCode InsCodeAI 会议 搜索 AI 搜索 登录 会员中心 消息 历史 创作中心 创作
mysql中的Innodb_buffer_pool
jchen104 阅读量2.9k 收藏 6 点赞数 2 已于 2023-05-26 00:33:02 修改 CC 4.0 BY-SA版权
分类专栏： 文章标签： mysql mysql 数据库 sql
2048 AI社区 文章已被社区收录 加入社区
mysql 专栏收录该内容 22 篇文章 订阅专栏
本文深入探讨MySQL的InnoDB Buffer Pool，包括其内部结构、插入缓冲和变更缓
冲的作用，以及数据合并的规则和Redo Log的重要性。通过对缓冲池的淘汰算法、状态查看的
分析，帮助理解如何优化数据库性能并确保数据一致性。
摘要生成于 C知道 ，由 DeepSeek-R1 满血版支持， 前往体验 >
参考文章：
《mysql底层解析——缓存，Innodb_buffer_pool，包括连接、解析、缓存、引擎、存储等》
写在开头：本文为学习后的总结，可能有不到位的地方，错误的地方，欢迎各位指正。
前言
在之前的文章 《mysql内存相关知识介绍》 中，我们对 mysql 的内存有了初步的了解，在最后
我们提及了mysql内存的重要组成部分Innodb_buffer_pool，这篇文章我们就来更深入了解下它。
buffer)与变更缓冲(change
目录
前言
一、Innodb_buffer_pool的内部结构
二、插入缓冲(insert buffer)与变更缓冲(change buffer)
三、数据合并(Merge buffer)
1、写回规则 觉得还不错? 一键收藏
2、redo log
四、补充 jchen104 2 6 0 分享 关注 专栏目录
1、淘汰算法
2、状态查看
一、Innodb_buffer_pool的内部结构
我们可以看到，Innodb_buffer_pool的组成部分包括索引、插入缓存、锁、缓存数据等。
和操作系统类似，mysql读取数据时也采用了分页读取的方式，当发生缺页中断的时候，去磁盘
上读取这个数据块，找到后把这一整个数据页都读入内存中（根据局部性原理，当某个数据被使用
时，那么他相邻的数据也有较大可能被使用到）。这样的数据读取方式有效的减少的磁盘的随机读，实
现了读取性能的优化。
使用如下语句查看Innodb_buffer_pool的大小
AI写代码 sql
show variables like 'innodb_buffer_pool_size'
另外，我们还可以查看 Innodb_buffer_pool使用内存页的情况

AI写代码 sql
show global status like '%innodb_buffer_pool_pages%'
Innodb_buffer_pool_pages_data：缓存池中包含数据的页的数目，包括脏页。单位是page。
Innodb_buffer_pool_pages_dirty：缓存池中脏页的数目。单位是page。
Innodb_buffer_pool_pages_flushed：缓存池中刷新页请求的数目。单位是page。
Innodb_buffer_pool_pages_free：剩余的页数目。单位是page。
Innodb_buffer_pool_pages_misc：缓存池中当前已经被用作管理用途或hash index而不能用作
为普通数据页的数目。单位是page。
Innodb_buffer_pool_pages_total：缓冲池的页总数目。单位是page。
在数据库专用服务器中，Innodb_buffer_pool推荐的大小设置为系统内存的70%-80%（不能太
小但也不能太大，小了的话内存不够用影响性能，大了的话可能导致swap分区被占用，同样影响性
能）。
索引、锁等信息大家都不陌生，这里就不展开来讲了，有兴趣的朋友可以看下我前面的
介绍 《mysql之事务、锁、隔离级别与MVCC》 《mysql库中索引的基础概念》
我们着重来讲下插入缓冲(insert buffer) 和 变更缓冲(change buffer)以及mysql中的相关配套措施。
二、插入缓冲(insert buffer)与变更缓冲(change buffer)
我们都知道mysql的索引结构是基于b+树建立的，对于一颗b+树而言，每次新增1个叶子节点都
会涉及非常多的步骤，包括但不限于扩容、校验、寻址等。所以当数据库进行频繁的插入时，若此多
的I/O操作对于性能的影响是比较大的。
对于主键索引，因为每次插入都是顺序增长的，所以问题不大。但是对于二级索引（非主键索
引、非聚簇索引）就不是这样了，每次数据的插入都需要对这些二级索引的b+树进行维护，这个步骤
需要根据自己的索引列进行排序，这就需要随机读取了。二级索引越多，那么插入就会越慢，因为要
寻找的树更多了。
于是，mysql设计了插入缓冲(insert buffer)。简单来说就是不是每次都插入到索引页中，而是
先判断该索引页是否在缓冲池中，若在，就直接插入，若不在，则先插入一个insert buffer里，再以
一定的规则进行真正的插入到二级索引的操作，这时就可以聚合多个操作，一起去插入。通过减少磁
盘的随机读写，提高性能 。
change buffer其实是对insert buffer的扩充，不仅insert会有缓存池，update、delete也存在缓存
池。也就是说对于所有的DML操作，都会先进缓冲区，再根据一定的规则，写回磁盘。
我们还可以查看并修改buffer的设置，我们可以修改为all(全部启用)、insert(仅插入启用)、
none(不启用)等.
AI写代码 sql
show variables like 'Innodb_change_buffering'
Innodb_change_buffer_max_size表示buffer最多占Innodb_buffer_pool百分之多少的空间。
AI写代码 sql
show variables like 'Innodb_change_buffer_max_size'

三、数据合并(Merge buffer)
在上文中我们了解了mysql利用缓冲池减少了对磁盘的I/O操作，但是无论怎样，这些数据都是要
写回磁盘才算DML操作的真正结束。这一节我们来介绍下写回规则与容灾措施。
1、写回规则
（1）insert buffer已无可用空间
（2）当二级缓存被读取进入内存中时
前面我们提到了，只有当索引页不在内存中时，才会把数据临时放入到change buffer中，既然
这里我们把二级索引给读取了进来，自然就可以把这个修改冲buffer中给取出并合并入二级索引中。
不过需要注意的时，此时这个数据仍然在内存中，不过是从变更缓冲(change buffer)中给写回到索引
页(index page)中，而不是磁盘，至于磁盘的写回则要更晚，这一点我们后面会介绍 。
（3）后台线程定时写回
mysql为了防止内存中的数据不要过大，专门设置了1个主线程master thread定期取出变更缓
冲(change buffer)中的数据写回磁盘。
2、redo log
现在，我们知道了mysql利用缓冲池的机制实现了尽量少的磁盘读写，进而优化了数据库的性
能。但是这带来了一个新的问题，内存中的数据与磁盘上的数据不一致，操作系统中的专业术语叫做
脏页，如此多的脏页，万一mysql挂了、服务器宕机了，内存上没有写回磁盘的数据不久丢失了吗，
这违反了数据一致性规则。
为了解决这一问题，mysql使用redo log来记录所有的事物，当事务开始时，逐步开始写redo
log，记录下每一步的操作，而后修改数据（这里的修改数据对应上文中的change buffer），最后，
当脏页根据前文中提及的规则写回磁盘后，对应的redo log便可以被重新（覆盖） 。
这样，即使服务器宕机，缓冲池中的数据丢失，我们也不用担心出现数据不一致的问题，mysql
会去读取redo log中的日志恢复。
四、补充
1、淘汰算法
在操作系统中我们使用LRU（Least Recently Used最近最少使用）算法来进行页面替换，将内存
中最近最少使用的页面换出内存，最频繁使用的页在LRU列表的前端，最少使用的页在LRU列表的尾
端。淘汰的话，就首先释放尾端的页。在 Innodb_buffer_pool 中也类似，之所以说类似，是因为
Innodb_buffer_pool中并不会把替换进来的页放在LRU队首，而是放在一个 midpoint的位置，这个参数
可以通过Innodb_old_blocks_pct来控制，默认距尾端37%的位置。
AI写代码 sql
show variables like 'Innodb_old_blocks_pct'
在midpoint之后的列表都是old列表，之前的是new列表，可以简单理解为new列表的页都是最活
跃的数据。
之所以不直接放在头部，是因为其实我们并不能确定这一页的数据是否会被多次用到，也许只是
偶发性的被使用到，因此并不能确定这个页面就是最活跃的，所以放在一个较为靠近末尾的位置，避
免了队首真正活跃的页面被后移。
另外还有个参数可以控制这个参数用来表示 页读取到mid位置后，需要等待多久（单位为毫秒）
才会被加入到LRU列表的。
AI写代码 sql
show variables like 'Innodb_old_blocks_time'
2、状态查看
在之前的文章 《mysql死锁分析工具show engine innodb status》 中有介绍过死锁分析工具，这
里再介绍下这个工具的另一个用处，即查看缓冲池的使用情况，命中状况等。
在开头，展示了以下信息

几个比较有用的参数这里例举了下，其余的参数有兴趣的可以自行搜索。
Pages made young：从 old 区移动到 new 区有多少个页
Pages made not young：因为 innodb_old_blocks_time 的设置而导致页没有从 old 部分启
动到 new 部分的操作。
Buffer pool hit rate：表示缓冲池的命中率，通常这个值不应该小于95%，如果小于95%，则应
该看看是不是由于全表扫描而导致 LRU 列表有污染。
MySQL 参数 之 innodb _ buffer _ pool _size 心有猛虎 细嗅蔷薇 1万+
Innodb _ buffer _ pool _size 《深入浅出 MySQL 》一文中这样描述 Innodb _ buffer _ pool _size： 该参数定义了 InnoDB 存
【 MySQL 】 InnoDB 存储引擎内存结构之 buffer pool 详解 8-10
可以通过系统变量 innodb _ buffer _ pool _size 进行设置,设置时以字节为单位:默认值为134217728 字节,即 128MB;最
mysql innodb 之 buffer pool _ innodb buffer pool 8-8
innodb _ buffer _ pool _size = innodb _ buffer _ pool _chunk_size * innodb _ buffer _ pool _instances*N(N>=1) 每次调整 inno
MySQL 优化： innodb _ buffer _ pool _instances与 innodb _ buffer _ pool _size参数 SunZLong的博客 1万+
首先了解三个参数三个参数： innodb _ buffer _ pool _size（缓冲池大小） innodb _ buffer _ pool _chunk_size（定义 Inno
MySQL 的 InnoDB 存储引擎 中的 Buffer Pool 机制 z3551906947的博客 1397
Buffer Pool 是 MySQL 数据库 中的 InnoDB 存储引擎使用的一个内存区域，用来缓存 数据库 中的 页（pages），以提高 数
MySQL 中的 Buffer pool ,以及各种 buffer _ buffer pool mysql 8-7
buffer pool 作为 innodb 内存结构的四大组件之一,不属于 mysql 的server层,是 innodb 存储引擎的缓冲池。 1.1 什么是 bu
... InnoDB 引擎底层解析( InnoDB 的表空间、 InnoDB 的 Buffer Pool ... 7-30
1.3.2. Buffer Pool InnoDB 为了缓存磁盘 中的 页,在 MySQL 服务器启动的时候就向操作系统申请了一片连续的内存,他
mysql 原理-- InnoDB 的 Buffer Pool x13262608581的博客 2062
Buffer Pool ，用户态高速缓存
InnoDB 的 Buffer Pool 详解 csdn_tom_168的博客 最新发布 787
摘要： InnoDB 的 Buffer Pool 是 MySQL 的核心内存组件，作为磁盘和内存之间的高速缓存层，主要作用是缓存数据页
MySql innodb buffer pool QuillChen的博客 804
show variables where variable_name in (' innodb _ buffer _ pool _size',' innodb _file_per_table',' innodb _log_ buffer _siz
【 MySQL 】 InnoDB 中的 Buffer Pool qq_45795794的博客 967
Buffer Pool 用作缓存，主要用于数据写入、数据读取、数据刷新，目的是为了减少磁盘I/O，增加读写速率，提高数
Mysql 参数 innodb _ buffer _ pool _size 热门推荐 2万+
以下考虑主要为 Innodb 引擎, key_ buffer _size 不考虑。对于实例级别或线程级别参数设置,暂不考虑。【 innodb _ buff
浅析在线调整 innodb _ buffer _ pool _size 12-14
浅析在线调整 innodb _ buffer _ pool _size 作者：zhou mysql 版本：5.7 先介绍一下 buffer pool : 在 innodb 存储引擎中数
innodb _ buffer _ pool _reads、 innodb _ buffer _ pool _read_requests分析与 inn w1346561235的博客 3884
澄清一下 innodb buffer pool 缓存命中率（cachehit ratio）指标的计算，这个计算涉及到两个状态变量 innodb _ buffer
mysql innodb _sort_ buffer _size_ mysql 优化---第7篇：参数 innodb _ buffer weixin_28848833的博客 1211
摘要：1 innodb _ buffer _ pool _instances可以开启多个内存缓冲池，把需要缓冲的数据hash到不同的缓冲池中，这样
MYSQL ---- InnoDB 的 Buffer Pool AFtaicai的博客 838
Buffer Pool :顾名思义，缓冲池。
MySQL InnoDB Buffer Pool qq_34125999的博客 917
1 缓存的重要性 我们知道，对于使用 InnoDB 作为存储引擎的表来说，不管是用于存储用户数据的索引（包括聚簇
MySQL InnoDB 内存结构之 Buffer Pool 最后的武艺集大成者 442
缓冲池是主内存 中的 一个区域， InnoDB 在访问时缓存表和索引数据。 缓冲池允许直接从内存中访问经常使用的数
MySQL InnoDB 缓冲池 buffer pool xzh_blog 610
什么是 buffer pool MySQL 服务器启动的时候会向操作系统申请了一片连续的内存作为缓冲池（ buffer pool ），默认12
Mysql InnoDB 的 Buffer Pool qq_27502511的博客 901
上述的这个间隔时间是由系统变量。每当需要从磁盘中加载⼀个⻚到 Buffer Pool 中时，就从free链表中取⼀个空闲的
Mysql — Innodb Buffer Pool l_dongyang的博客 522
一、 Innodb Buffer Pool 简介 我们知道 Mysql 是基于磁盘的永久性存储的一个 数据库 ，但是磁盘的读写速度远远赶不
【 MySQL 】 InnoDB 内存结构- Buffer Pool qq_34408516的博客 1940
前言 无论是后端开发、DBA、还是测试，几乎每天都会和 MySQL 打交道。尤其是后端开发人员，大部分只是停留在

MySQL 中 Innodb 存储引擎的 Buffer Pool 详解 sanylove的博客 1483
Buffer Pool 即缓冲池（简称BP），BP以Page页为单位，缓存最热的数据页(data page)与索引页(index page)，Page
mysql 数据库 参数 innodb _ buffer _ pool _size和max_connections weixin_34360651的博客 166
接到报故，查看 mysql 数据库 以下参数 1、 innodb _ buffer _ pool _size 2、max_connections 该参数定义了数据缓冲区
关于我们 招贤纳士 商务合作 寻求报道 400-660-0108 kefu@csdn.net 在线客服 工作时间 8:30-22:00
公安备案号11010502030143 京ICP备19004658号 京网文〔2020〕1039-165号 经营性网站备案信息 北京互联网违法和不良信息举报中心
家长监护 网络110报警服务 中国互联网举报中心 Chrome商店下载 账号管理规范 版权与免责声明 版权申诉 出版物许可证 营业执照
©1999-2025北京创新乐知网络技术有限公司

