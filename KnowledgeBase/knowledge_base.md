# 知識庫分類目錄

## 基礎知識

### 資料庫概念

- [Database Scalability and the Giant Flea: A Lesson in Complexity - The New Stack](collector/94fb63fc6db6864ca91e18cbbe282906.pdf)
- [xtrabackup原理及实施](collector/ada26a457f24c63b95c3b4cd08ffc1d8.pdf)
- [The Optimizer Cost Model from MariaDB 11.0](collector/9b85d8a7fc8e89c6fd28c45d4d15b9e1.pdf)

### 分散式資料庫概論

- [NineData 社区版：从 MySQL 到 TiDB 数据复制新选择 - 墨天轮](collector/6ae9da3549283979aa62066b97ba2a96.pdf)
- [轻松上手：使用 Docker Compose 部署 TiDB 的简易指南 - 墨天轮](collector/dd80518a03cc67779a0c876376ccb05b.pdf)

## 系統架構

### 雲端架構與部署

- [CloudJump II：云数据库在共享存储场景下的优化与实现（发表于SIGMOD 2025）](collector/4504ec57cff1695d52509f095590eb57.pdf)

## 資料庫管理

### 安裝部署與配置

- [Ubuntu上的MySQL 8.4.5安装：一行命令背后的系统级操作实录 | 不只是apt install那么简单](collector/38e33dbdc635c5230643e3801cf0cef9.pdf)

### 維運管理與日常作業

- [Using Blue/Green Deployment For (near) Zero-Downtime Primary Key Updates in RDS MySQL](collector/7e04df7e492af937f3db7351c4bd43b8.pdf)
- [Orchestrator (for Managing MySQL) High Availability Using Raft](collector/41244ed80cb02c95a173325114b0285b.pdf)
- [云和恩墨杨廷琨：日常运维中的技术决策](collector/09de87d3a15a7e8dcfbd0ef455ddefa7.pdf)

### 監控與日誌

- [Password Management in MySQL 8: Switching Between Authentication Plugins](collector/52e38072515ecdc8bacde815def89053.pdf)
- [[MYSQL] 从库 io_thread 接受binlog速度太慢?](collector/ab0fceca2e10d9257ab64bf479662204.pdf)

## 部署與維運 (DevOps/運維)

## 性能優化

### 查詢優化

- [PolarDB MySQL跨可用区强一致解决方案](collector/f47e6048987f7b4eeb3199c1fc30c45c.pdf)
- [基于 MySQL 8.0 细粒度授权：单独授予 KILL 权限的优雅解决方案 - 墨天轮](collector/cf51ea429c1967586f9582bb182a15d9.pdf)
- [MySQL突然崩溃？教你用gdb解剖core文件，快速锁定“元凶”! - 墨天轮](collector/3eb79c4afbd0fc2c42133f9d0b606de1.pdf)
- [MySQL生产实战优化（利用Index skip scan优化性能提升257倍） - 墨天轮](collector/8011ad97f55be5ff49fb57fe47b36b7a.pdf)
- [MySQL8.0统计信息总结 - 墨天轮](collector/001569921a9bb9ed2b9b5384beec7bbe.pdf)
- [MySQL 有没有类似 Oracle 的索引监控功能？ - 墨天轮](collector/864da5709363c16af76f365306c1a0f1.pdf)
- [[MYSQL] 漏扫发现驱动存在漏洞, 怎么快速查找客户端的驱动版本呢? - 墨天轮](collector/6424dd3cd2dcf41a682a292d0693b88c.pdf)
- [MySQL 8.4 新特性深度解析：功能增强、废弃项与移除项全指南 - 墨天轮](collector/c057781ef0c7e0873c7f9a43cadca7b5.pdf)
- [MySQL 8.0 OCP 1Z0-908 考试解析指南(三)终结篇 - 墨天轮](collector/3c5d927871fd91e17ed6408eec088c71.pdf)
- [一键生成MySQL巡检报告](collector/29ecf63fcd34313a9a5e06c2b97a01c4.pdf)
- [MySQL 8.0 性能优化实战：性能提升的全方位调优方案](collector/68739bb3073ab7d8c92fd54feacfcfe9.pdf)
- [MySQL锁定位实践指南](collector/1b075f6bffd67f550f942f6b81dabf9d.pdf)
- [mysql自适应哈希索引（AHI）,40%性能提升，为何有人却选择关闭？](collector/801ad604fe510fdd79c023b9c99aa7df.pdf)
- [[MYSQL] row_format=compressed的存储结构浅析](collector/af409e79577162f416b6463ce5d15a87.pdf)
- [怎样保持MySQL Performance Schema的性能开销在可控范围内？--深度解析PFS对数据库性能的影响](collector/3e4d8db847142e8a85459e10b6868641.pdf)
- [MySQL 8.0.40：字符集革命、窗口函数效能与DDL原子性实践](collector/bbe9baf20037a60a6bda0752abc273be.pdf)
- [深度解析MySQL的半连接转换](collector/8b3b99d613c2bf75e4779522b9170476.pdf)
- [使用 MySQL Clone 插件为MGR集群添加节点](collector/4504759312deaf01f04cd5a2d02c4b99.pdf)
- [MySQL数据库SQL优化案例(走错索引)](collector/87f38de02a1b77e66adc488b320edb1c.pdf)
- [InnoDB 二级索引 B+ 树的 Key 是什么？](collector/99e79ab39ea9004943b9c92dfcdcceb9.pdf)

### 索引設計

- [聊聊跨数据库迁移的数据比对那些事儿 - 墨天轮](collector/f30c184d6c036d4d3d20f77b75f37302.pdf)
- [AWR报告暗藏的致命误区，90%的DBA还在踩坑！ - 墨天轮](collector/8e613f1d9f82451d3aa96ae12dc43051.pdf)
- [Debezium实战！一款不错的开源CDC工具 - 墨天轮](collector/5ed3876f474f24c2a33147acd3267d85.pdf)

## 安全與合規

## 災難復原與備份

## 開發者支援

### 資料模型與 Schema 設計

- [如何迅速并识别处理MDL锁阻塞问题TaurusDB推出MDL锁视图功能，帮助用户迅速识别并处理MDL锁阻塞问题，从而有效 - 掘金](collector/aa48496117f65bb611d2fbea446b3c6c.pdf)
- [面试复盘：MySQL InnoDB 事务隔离级别与 MVCC 分析/为什么可重复读的死锁概率高？_ 最近一次面试中，面 - 掘金](collector/02f7ce5680cb3c01e50450fddbe10d04.pdf)
- [理解 MySQL 的分组机制：GROUP BY、SELECT、HAVING 及索引优化理解 MySQL 的分组机制：GR - 掘金](collector/23a35557d03da0e51c3396bd694b4bf5.pdf)
- [Docker部署MySQL、Redis、Kafka、ES、KibanaDocker Docker的基础概念和安装就不多讲 - 掘金](collector/13c919cde6178d6e6bbf2bcaa88f6cd4.pdf)
- [SQL执行顺序与ON vs WHERE：MySQL底层解析与面试记忆法SQL执行顺序与ON vs WHERE：MySQL - 掘金](collector/b221d40092566cfb3b93d88b064efe4f.pdf)

## 工具與整合

## 培訓與文件

### 操作手冊與教學文件

- [美团2面：亿级流量，如何保证Redis与MySQL的一致性？操作失败 如何设计 补偿？](collector/9b155c5f6dba05ac24db758bf32a027a.pdf)
- ["慢SQL"治理的几点思考](collector/928473265cdc10481ccbce541bba4a5b.pdf)
- [MySQL表数据已经删了，为什么空间还是没释放？](collector/dd9ab01aa305698c82f77c8cc05f2e0d.pdf)
- [掌握 SQL 子查询：让你成为查询优化高手](collector/23cf552d4947da4441ccb1acd5aa7079.pdf)
- [好问题，数据治理到底解决了什么啊](collector/f963b5bf58c9daad2b17f798d93d4f3d.pdf)
- [MySQL 如何实现安全连接？](collector/e51cd350fe0d6bce55191d86520d2261.pdf)
- [MySQL中varchar(50)和varchar(500)区别是什么?](collector/69543d21b92b2836d64184f7a064390e.pdf)
- [35岁重学网络安全——SQL注入篇（二十四）](collector/86a8ea7c70317357da7b0a3bf35dea79.pdf)
- [免费开源 PDF 神器，啥功能都有，PDF 需求全覆盖～～～](collector/d56385bf638090498b47d885e2ed6b43.pdf)
- [MySQL8第108期-性能优化之数据库结构1](collector/8742fddec1aac99f2ec7f7ae4655c089.pdf)
- [TiDB × AI ：DeepSeek 时代你需要什么样的数据基座](collector/2f7d940a3a2e1635b70fe4d038d9e330.pdf)
- [阿里面试：10WQPS高并发，怎么限流？这份答案，让我当场拿了offer](collector/6b159e0502dedddad0a2c78d220d598b.pdf)
- [MySQL内存问题分析利器--Jemalloc](collector/cf063b6e344bb94de337aa8099ec0765.pdf)
- [MySQL 升级后查询性能跳水，排序竟成“罪魁祸首”？](collector/3e6aea7a585dd2262279f6bf9853912a.pdf)
- [数据库流程管理功能：防范灾难性故障的最后防线](collector/cd78ff0348afb430117e1b1594b25d0a.pdf)
- [[MYSQL] 记录一下undo太大(Disk is full)导致数据库宕机案例](collector/3033a92d5b8ec0a31605d0312ae9898d.pdf)
- [行业案例：12306亿级流量架构分析（史上最全）](collector/e323f982151cdee3c063172ec89893b2.pdf)
- [京东二面：分库分表后翻页100万条，怎么设计？答对这题直接给P7！](collector/f89a1f60714663f9493a4a35837dfaa1.pdf)
- [从单一到多活，麦当劳中国的数据库架构迁移实战](collector/22cfb4facea082f8b8debd6605e8e257.pdf)
- [第 53 期：EXPLAIN 中最直观的 rows](collector/783f485ee2a4566af9ddf900f7f8bb56.pdf)
- [面试官：如果某个业务量突然提升100倍QPS你会怎么做？](collector/f27b82079b8733bedc70f25fa53da604.pdf)
- [一起免费考 MySQL OCP 认证啦！](collector/be34ff8663b0ba98397851ad3de8c7e8.pdf)
- [什么是索引下推？什么是索引覆盖？什么是回表？](collector/4f288e377446e893136755b1f417aa89.pdf)
- [SQL优化实战：从慢如蜗牛到快如闪电的必杀技](collector/0504718023db4a726279fd687d4bcab0.pdf)
- [阿里二面：10亿级分库分表，如何丝滑扩容、如何双写灰度？阿里P8方案+ 架构图，看完直接上offer！](collector/0f1fbb21bfa72846d928642ab8afa178.pdf)
- [MySQL免费培训与认证](collector/0f947a3b8fb7da48c5dfc8dfe5493ef8.pdf)
- [高并发下幂等性的七大解决方案（图文总结）](collector/55a2e878185edd06369a1b04387280e6.pdf)
- [腾讯二面：1.2 亿级大表, 如何 加索引？](collector/562b8a33a3d8c8e2348279008e454053.pdf)
- [性能比拼: MySQL vs PostgreSQL](collector/d0d1305ad59b2d3b0e3f6fbf26f823f7.pdf)
- [实现一个 MySQL 配置对比脚本需要考虑哪些细节？](collector/b42daf3594e7c685521ef338b772085e.pdf)
- [SQL优化——我是如何将SQL执行性能提升10倍的](collector/1e8b6b87255ee140f42e8a9cc94f6190.pdf)
- [分布式数据库是伪需求](collector/3e081f32fa73e052fe70bb3c86d634f4.pdf)
- [别再卷技术细节了，不值钱。。。](collector/613ad8fa92bb5155bdd8b6a8eafcd10a.pdf)
- [CPU又100%了](collector/44862aef1f3e9f432840f303bb9da948.pdf)
- [MySQL惊天陷阱：left join时选on还是where？](collector/4ece2a5d71108290a43bd9aa6fe88d14.pdf)
- [高并发下连接池：性能飞升的魔法秘籍](collector/7fa5526bae686214bbcb40c29a167309.pdf)
- [架构师必看！现代应用架构发展趋势与数据库选型建议丨TiDB vs MySQL 专题（一）](collector/1c72a63958d35f8bbaac1d46415655a8.pdf)
- [TiDB 观测性解读（一）丨索引观测：快速识别无用索引与低效索引](collector/2de026eacc1b893ed1226f2bd873037c.pdf)
- [MySQL数据库常用的41个脚本，速来下载！](collector/63e7f4a398c3412bd0e46e04761ec0f0.pdf)
- [MySQL 8.0 INSTANT DDL 算法原理简析](collector/897240cbe8f970062e4b51aa9a925826.pdf)
- [Redis缓存三剑客：穿透、雪崩、击穿—手把手教你解决](collector/a9d7a197acc8356eb770b8865430d8bc.pdf)
- [面试官最爱问：你线上 QPS 是多少？你怎么知道的？](collector/c88bc9dc70d233d3bbe555aa91b89b8e.pdf)
- [如何准确获取 MySQL 主从延迟时间？](collector/efdce531a066312521594d378fbec0b1.pdf)
- [重新定义可视化：我的 Grafana 设计之旅](collector/c4c2ab9a7b97fbbda9bc4e0cb41d79af.pdf)
- [MySQL死锁全解析：从原理到实战的破局指南](collector/1917eb14d34aacecd7169b6ca66c3fc1.pdf)
- [万字详解：K8s核心组件与指标监控体系](collector/15ae13e657d0a2cdbb7a9447df344ba9.pdf)
- [MySQL 8.0 OCP 1Z0-908 考试题解析指南](collector/e4e533ce546996f92a85b8a5e760ae1b.pdf)
- [活动中台系统慢 SQL 治理实践](collector/341f2313c1791492b1c0284347ce6220.pdf)
- [MySQL 30 周年庆！MySQL 企业版已开放下载！](collector/3608af8780e5810dea74d054e452b709.pdf)
- [庖丁解InnoDB之B+Tree](collector/2e34f0e79a7ff1abef3d20cbbd74f695.pdf)
- [京东面试：mysql深度分页 严重影响性能？根本原因是什么？如何优化？](collector/938ec8b854beade0cca15aaaba177790.pdf)
- [停从库,为啥主库报错[ERROR]mysqld:Got an error reading communication packe](collector/85a3ee4b98438113378489e6e8029f92.pdf)
- [不同数据库的存算分离有何不同](collector/22b190fe2638409e2dde4bc5f7dd2ad9.pdf)
- [深入理解 SQL 联结表：从基础到优化，一篇文章带你掌握](collector/b3e61dbf1eaa62124a0f3fb0d7fca83f.pdf)
- [面试必看！腾讯面试问：MySQL缓存有几级？你能答上来吗？](collector/85442faf3da258ee16a3ef38899f808b.pdf)
- [重生之 MySQL B+Tree 提前问世二十年，MySQL之父叫我师父](collector/1739e4ae182da8c5d4e409b063d6876a.pdf)
- [MySQL日志系统：持久性和一致性是如何实现的？](collector/4e63b616ab207e733ae09e3b879e2637.pdf)
- [腾讯面试：1亿用户的好友关系如何秒级查询共同好友？这套方案让性能提升100倍！](collector/f0fa06631288db2fe941f72b59f6f429.pdf)
- [mysql字段数量限制为啥是1017 ?](collector/7e84f0d02bc9c52eb91888f94b8c1414.pdf)
- [MySQL 8.0参数默认值变更，恐致性能下降3倍多](collector/f23997bda0e84488df8ab87e753bb69c.pdf)
- [架构设计过程中的10点体会](collector/42dfb24cc37ad18726de64a2bb5cc686.pdf)
- [「合集」MySQL 8.x 系列文章汇总](collector/e5f93f1a236836228efea418a70ea536.pdf)
- [全面监控太优雅 , 太6了, 运维强推](collector/255ef4a415237f487394694346498aee.pdf)
- [MySQL 高可用：MHA 实现 MySQL 高可用](collector/44380ab34618101b2a7b528a7fba216f.pdf)
- [一文搞懂 MySQL InnoDB架构 Buffer Pool、Change Buffer、自适应哈希索引、Log Buffer](collector/50301f09e4569d3c389c6146db83bd10.pdf)
- [我的2023-2024年mysql相关文章整理汇总](collector/0b42390bb6652a945e1b87c86efc459a.pdf)
- [如何给MySQL的字符串字段加好索引？](collector/67b9239c1e117f57662e78ccd279613b.pdf)
- [字节二面：为何还执着传统数据复制，零拷贝它不香吗？](collector/7323232c21b1301c822fd40679b9c46b.pdf)
- [[MYSQL] mysql空间问题案例分享](collector/ce02df5a739df7820a4d3c2094ac4340.pdf)
- [当 DeepSeek 遇见数据库，大模型如何重构 DBA 的工作模式？](collector/9d0cce180d29510aeaa72fabc39369bd.pdf)
- [MySQL 用 limit 为什么会影响性能？有什么优化方案？](collector/e17662648434859bd6be76ed3b95a212.pdf)
- [字节一面：20亿手机号存储选int还是string？varchar还是char？为什么？](collector/63f9298623511a70589f45ada9401398.pdf)
- [MySQL参数innodb_buffer_pool_size优化方法](collector/daa4411582408500b5be400ff24ce477.pdf)
- [爬虫搞崩网站后，程序员自制“Zip炸弹”反击，6刀服务器成功扛住4.6万请求](collector/72a36f88fa5f3dd55625c60c045a0f3c.pdf)
- [为什么GROUP BY比DISTINCT快3倍？90%的程序员都踩过这个坑！](collector/2ce23a075947fcba62bdaaeaa37af067.pdf)
- [利用 MySQL 8.0 clone 插件远程克隆快速重建主从复制环境](collector/c05b559cdae28f2f430f663a7fcfd3e8.pdf)
- [网易终面：100G内存下，MySQL查询200G大表会OOM么？](collector/64b489bde252cbb70863ab7a779b75cf.pdf)
- [[MYSQL] 服务器出现大量的TIME_WAIT, 每天凌晨就清零了](collector/7b1aa4898308cb8d02cd86501b2bc5ef.pdf)
- [TiDB 可观测性解读系列：索引与算子执行性能优化实践](collector/2ab019b57c025f2f4972986577ee1f5c.pdf)
- [新特性：用户管理升级，角色权限一目了然](collector/9ea1332c634ea50d1442fa530ea9c633.pdf)
- [验证 MySQL MGR 双机房双活架构可行性](collector/be275f1ba6718211207a8bea411b237f.pdf)
- [重生之MySQL 索引失效六大陷阱](collector/5f7bdc0ef060d0efff808773e7782c67.pdf)
- [去哪面试：1Wtps高并发，MySQL 热点行 问题， 怎么解决？](collector/21374143cf71842dc5d7d1a8e1b36d40.pdf)
- [阿里一面：MySQL 一张表最多支持多少个索引？16个？64个？还是无限制？](collector/2b7f33be7031ea105eaa09a6193da552.pdf)
- [主从报错GTID_MODE = ON cannot be set to ANONYMOUS](collector/8806df80070e0504041848adeb3d0e1b.pdf)
- [阿里面试：每天新增100w订单，如何的分库分表？这份答案让我当场拿了offer](collector/1bb42ceacac9fdb371ef81785f2c8b29.pdf)
- [MySQL出息了! 大败PG用的这个case](collector/ec00423c5e1578b5ff5fc4032f41879a.pdf)
- [mysql提升10倍count(*)的神器](collector/88e03927022b034a07fc05697d27b429.pdf)
- [携程面试：100 亿分库分表 如何设计？ 核弹级 16字真经， 让面试官彻底 “沦陷”，当场发offer！](collector/6a5506a915d6ff1834b919009678a30f.pdf)
- [深度解析MySQL索引失效的8大场景及终极解决方案](collector/2703fc1679655e88248b2b12af886e95.pdf)
- [事务持续执行之谜：怎样找出对行记录上锁的 SQL？](collector/90a8dd6f2dddc0d00efe98fd30c36f8f.pdf)
- [大规模数据同步后源端与目标端数据总条数对不上的系统性解决方案](collector/c600b512bfaa0d325fedfe7742fb0b23.pdf)
- [MySQL内存使用率高问题排查](collector/02507d3964afd744e6dbb7e9148eaacf.pdf)
- [一、架构设计基础](collector/1e45d837b5e0443da7128142263f5a27.pdf)
- [认知密度：为什么聪明的人越来越沉默了](collector/70cf21c5606f0e8a9494c4b5d16ebbec.pdf)
- [面试官：说说四层和七层代理的本质区别？——从 OSI 模型到千万级集群的拆解指南](collector/652496fd9d65b8fb0e3df460c3d85f3d.pdf)
- [MySQL生产实战优化（利用Index skip scan优化性能提升257倍）](collector/e384c3abb1f2ec298174c21666b0cc67.pdf)
- [火焰图：MySQL 性能分析的可视化利器](collector/e98faa4611508ebf162d1ae5f9b8622d.pdf)
- [凌晨四点，线上CPU告警，绩效没了……](collector/9a132f2b394a5efe8b50c0abaf80ecb7.pdf)
- [MySQL 性能优化核心指南：表结构设计与查询速度深度解析](collector/6178cb92683f4e4ed6d5e16ac3b57411.pdf)
- [万字总结：腾讯会议后台告警治理实践——如何才能避免“事后诸葛亮”](collector/bc19303cf196e66d02df8b299abd8a1a.pdf)
- [如何构建故障容忍的分布式系统](collector/5a1f568435e61abfbf5dd495d88fda9b.pdf)
- [一分钟阅读:架构师的核心能力](collector/cbde1a52bbe1f2e64dfbfb3166c29f2e.pdf)
- [分布式系统不可靠时钟问题](collector/1a1779077a8ec0f1dc5b805ef4d6f082.pdf)
- [字节面试：流量突然提升100倍QPS，怎么办？说出这 9字真经（压、分、缓、异、限、降、扩 、监、演），大厂 面试官跪了！！](collector/a3d782e1a99228f82f8d9bbebeeeeb8b.pdf)
- [如何度量高可用架构设计指标](collector/9098d0816007e761ad4aafc541b1a6cd.pdf)
- [对 MySQL MGR 双机房双活架构的可行性验证（附 Cursor 脚本）](collector/65345b7d3cd1b42a7c2fc5184097e77b.pdf)
- [淘宝质量保障之主动预警能力建设](collector/1cacda269b0dafc0d0c693ab78fcb2c7.pdf)
- [ETL的“终结者”？DBA如何看待HTAP的概念、价值与实现路径](collector/238bc7725675313cf3055d2b4cad8c5b.pdf)
- [MySQL 8.0升级价值分析：新特性与5.7性能实测](collector/356d597ec2167bdfd3ed77777f909971.pdf)
- [[MYSQL] 当一个PAGE里的数据全部被delete之后, 它还会存在于Btree+中吗?](collector/9449fab062d488b9ec305b64000d070a.pdf)
- [DBSyncer：一款开源的数据同步工具](collector/8abecd7579f40e36704900e1dc658a7c.pdf)
- [[MYSQL] 出现大量的Waiting for table flush导致业务表查询不了](collector/da3cbf9103dd0fde44989bcf85ce8d8e.pdf)
- [刚升级到MySQL8.0就凉凉，是时候准备再次重启升级了](collector/868c71eb7e985d733eda69dde101d31b.pdf)
- [上线3周：告警减少70%！AI巡检分级报告实战（一）](collector/4a7d3d0523b8155c5eef588a3dc9907e.pdf)
- [如何分析 mysqld crash 的原因](collector/9188f9c7f4423974c11dd8222435fe12.pdf)
- [[MYSQL] 参数/变量浅析(1) -- 超时(timeout)相关](collector/63119f5c69d42ed1a267a59ce5c3a63a.pdf)
- [SQL 优化对比：驱动表 vs Hash 关联](collector/c42de607b00a6d208b94059f4d218b1a.pdf)
- [什么？事务提交后，数据丢了？](collector/974aa1398cfb33a892f4faec4fdba4ff.pdf)
- [阿里面试：MySQL 一个表最多 加几个索引？ 6个？64个？还是多少？](collector/499ade35926310be425eda5ff150f94e.pdf)
- [美团面试： ‘异地多活’ 都不用 ， 你们 项目 怎么实现 高可用呢？](collector/d7fe63bdf2283b3983577c28e356c225.pdf)
- [微众银行：大规模 TiDB 运维体系建设 & 金融级稳定性保障漫谈](collector/b1b7469378233f9581c863170286f8ef.pdf)
- [告别 MySQL 分库分表， 重庆富民银行通过 TiDB 实现批量场景降本提效](collector/69639d8704c7656d30176be0d63596f7.pdf)
- [如何理解高可用数据复制原理](collector/765b189c8a79c9f58e7574de2b359fb8.pdf)
- [我们运维的 CMDB 模型是不是都做错了？](collector/44f04696c333a9712822825f2f257b78.pdf)
- [阿里面试：redis 突然变慢，如何定位？ 如何止血 ？ 如何 根治？](collector/a921f24b9133afc247ffb8b7924bd74b.pdf)
- [MySQL Buffer Pool的“防暴”机制，让你的数据库内存永不“社恐”](collector/db88b92775464cd4e325dfcf2d2a4c66.pdf)
- [运维做好述职-“让价值被看见”](collector/e1a168c44200c635a475549f4c5a5cc3.pdf)
- [优秀架构师必备：技术领导力的六项核心修炼](collector/027e57475b162bf6d68064e5223762fc.pdf)
- [MySQL InnoDB MONITOR 性能监控](collector/177c701a8fcabb8769c4e6695fa54383.pdf)
- [为什么DBA怒吼：MySQL小数必须用decimal？float/double是隐藏的财务刺客！](collector/677109bf61d41cae7f523d3703c4a8ee.pdf)
- [为什么DBA要求MySQL表索引不能超过5个](collector/8d31234716fdeda76cb7fffa732202f6.pdf)

## 案例研究與實務

## 參考資源

## TiDB 實踐

### 核心組件

- [TiDB 的高可用實踐: 一文了解代理組件 TiProxy 的原理與應用](collector/28eb86116fab2803d090537fee290113.pdf)
- [TiDB 介紹及設計原理](collector/384e3ca8b05dbed3b6ca32222678ca7f.pdf)
- [TiDB 底層存儲結構 LSM 樹原理介紹](collector/1de9b7d1440ed70776bf9f305e14a986.pdf)
- [TiDB 的列式存儲引擎是如何實現的？](collector/156269ef29fe4a830a34022ba79f9974.pdf)

### 架構設計

- [TiDB 整體架構](collector/99ab36a846be3cd2bd2237ea2ff882da.pdf)
- [7000+字的 TiDB 保姆級簡介](collector/c878673f99e69883937d54a6b5b740df.pdf)
- [TiDB 中的自增主鍵有哪些使用限制，應該如何避免？](collector/f24cbbd6a04f8ca036d5113ed745aab5.pdf)
- [分庫分表已成為過去式，使用分佈式資料庫才是未來](collector/5341b6858256a0774fc3ae4e1b17768d.pdf)
- [How a new database architecture supports scale and reliability in TiDB](collector/8e431cf3f342da1daa965db08504102f.pdf)

- [一文详解架构设计的本质](collector/5cf669dc724cc9b8f13dc47ad1c764dd.pdf)
- [架构提效的矛盾和矛盾的主要方面](collector/82ca5379bc881cf9c7fb9bcc7785428c.pdf)
- [什麼才是架構師的真內核？](collector/29923a2ff3e48bb8fa82bdd2c75cd4ca.pdf)
- [單體架構和微服務架構到底哪個好？](collector/7de0d091d91c88f84dcf3593a6f7462d.pdf)
- [架構師必備 10 大接口性能優化秘技，條條經典！](collector/b0b7db4bb8f74dbe80c088d52dd5fa55.pdf)
- [像架構師一樣去思考](collector/53834403bd0eb43fa85470bd5d81809d.pdf)
- [彩虹橋架構演進之路-負載均衡篇｜得物技術](collector/cb41093a0ba5cf6f375f46b3e1e3ff96.pdf)
- [單元化架構在字節跳動的落地實踐](collector/a7a153849277d6daeda5f742f7b4499c.pdf)
- [微服務與分布式系統設計看這篇就夠了！](collector/47eb1dc6abbb4d9c6c213ae7755adae2.pdf)
- [15 個系統設計權衡關鍵點: 構建高性能系統的黃金法則](collector/8b00523b7afd9201d9eba6bc4ceb6f1b.pdf)
- [不可思議！平均執行耗時僅 1.5ms 的接口在超時時間 100ms 下成功率竟然還不到 5 個 9!!](collector/d878c8bd4435c697819401293e6cb373.pdf)
- [什麼才是真正的架構設計？](collector/ff238e5e10abf4370f715e5e481a053f.pdf)
- [整潔架構演進之路——京東廣告投放平台實戰](collector/0382a897347df4798d7e22baeca3dca9.pdf)
- [如何畫好架構圖：7 種常用類型與示例](collector/0aafc5cc111c00e82970042bc8bcf339.pdf)
- [架構師基本功：如何畫好一張 UML 用例圖？](collector/4a533f9955a7b50cb4596468c058eb7f.pdf)
- [架構師必備底層邏輯：設計與建模](collector/25e668d98d19f77bb58ca2a397715405.pdf)
- [過度設計的架構師們，應該拿去祭天](collector/cafa830ebf998bb3583c865eb01444cd.pdf)
- [你的 API 服務設計能力將再次進化！](collector/1a4fa6e37f7eb683ca1f8496b00cb1f0.pdf)
- [架構設計的悖論，復用是美好的還是邪惡的](collector/3398a6ca1b1c193f45e75fbf1aef8266.pdf)
- [架構師必備底層邏輯：分層架構設計](collector/f6283fbfef4f7fcabb4815abf6dd5846.pdf)
- [Software Architecture is Hard](collector/359626bc5641e31d9fe81b2ac8e446bd.pdf)
- [如何畫好一張架構圖？](collector/2e4744acfe6ffc0fec8a6937fb8689ee.pdf)
- [大型研發架構團隊的 AOM 實踐](collector/276062bf162565814aa4e70e14b7db0d.pdf)
- [DDD 落地指南-架構師眼中的餐廳](collector/5f6455b1073443e92c1507c8d17a3872.pdf)
- [系統技術規劃的幾點概要思路](collector/20b82eeff9bce51ccb1902caead3b6ce.pdf)
- [再聊對架構決策記錄的一些思考](collector/acd99de92c32e4d3c54c7d710714ccd8.pdf)
- [人人都是架構師-清晰架構 | 京東物流技術團隊](collector/2ac31a1732680e72a16f3f3c2b711d09.pdf)
- [架構演變史：從建築學到架構設計](collector/8704c7ff9b9fa201451e5d17e8e1c243.pdf)
- [介紹了那麼多，技術中架構到底什麼？](collector/cfd2624b5bcccd703547d420ed4ca6c1.pdf)
- [系統設計中 跨時區問題 解決方案](collector/eac970515cc6b06b1b335d2273c954fd.pdf)
- [如何將技術債務納入路線圖](collector/47b4511182e6e82b208a708e923a4ed1.pdf)
- [你的架構決策記錄是否失去了它的目的？](collector/ef62f06e66fcf9730ad9361a0cacd20b.pdf)
- [亞馬遜 CTO 20 年架構經驗之道：儉約架構師的七大黃金法則！](collector/e7a93957c877ec7aa35b668de07db479.pdf)
- [軟件架構，一切盡在權衡](collector/29407d2fed04e0cb2684a676ffea3fa5.pdf)
### 高可用性設計

- [Cross-DC Deployment Solutions](collector/71ad51e40af1dcc472d06992997d0516.pdf)
- [TiDB 與 MySQL 在備份容災體系的衡量對比](collector/11943de59bf565b7d958f82d5ef421cf.pdf)
- [國產資料庫『同城兩中心』容災方案對比，TiDB 表現優秀](collector/2912766936bb510774c1551dd89fa3b9.pdf)
- [TiDB 三中心『腦裂』場景探討](collector/0c7834f8ba6b520d05f5d04933e9c78b.pdf)
- [為什麼說 TiDB 在線擴容對業務幾乎沒有影響](collector/65a4c9cc26789c98e196bd0be9c0a1e3.pdf)
- [TiDB DR-Auto-Sync 同城双中心的原理与实践](collector/5d5b8506afba43b65c7fd1af35337f77.pdf)
- [DR Auto-Sync：TiDB 同城两中心自适应同步复制技术解析](collector/48561f1691da582df595307bd02a614b.pdf)

### 安裝部署及管理

- [定制化 MySQL 8.2.0 編譯選項](collector/400140b9fdd43e06dc075915fd2384d1.pdf)
- [離線部署 TiDB 8.1.0 集群](collector/ea385de9c0b44e5dd00d7baa05e5d0b7.pdf)
- [TiDB 在單機上模擬部署生產環境集群](collector/abd1e7518133ab15bc87e957a32b00b7.pdf)
- [TiDB 學習之路從部署開始](collector/0756a3aeba95614e8f995f77620e9a24.pdf)
- [使用 TiUP 部署 TiDB 集群](collector/4c72c06d793ff8b0156e5dde9d646324.pdf)
- [攻克多版本运维难题：爱奇艺百套 TiDB 集群升级至 v7.1.5 实战宝典来袭！](collector/9929353f479a3a7a23234d1e51b7376a.pdf)

- [MySQL 在線開啟 GTID 的每個階段是要做什麼](collector/3f02310b7e8d40d8a61662a93f4fc153.pdf)
- [MySQL 8.0 參數配置不生效問題排查診斷](collector/dc37e86fabf6151f7244030e5ad0f71f.pdf)
- [Upgrading GitHub.com to MySQL 8.0](collector/ab87bac92f55d2e012d82cbf529154f5.pdf)
- [Migrating Facebook to MySQL 8.0](collector/092ce3de80a63a589d6aa18c2a35a3b7.pdf)
- [使用 Blue-Green Deploy 把 MySQL 5.7 升級到 8.0](collector/0b89d4063faab9584c2a02a17afec5d7.pdf)
- [MySQL 8.0.40 MGR 集群安裝部署及管理](collector/54711fcb27d9bfcc2ddd6a778b3b5ac9.pdf)
- [Linux 8 快速安装 PostgreSQL 17.2](collector/ae414e4585126b7eff4d087d8839968d.pdf)
- [CentOS 7.9部署MySQL 8.4.3 LTS保姆级手册](collector/fd6dead109635f62ce365e007efaeda7.pdf)
- [mysql一键安装脚本分享](collector/d51a210888d75c34c12f3f2b5d887459.pdf)
- [CentOS-Stream9 上安裝 PostgreSQL 17 from Source Code](collector/3fd8b956d4a659320637c2cfc220963b.pdf)
- [從 MySQL 遷移到 PostgreSQL 經驗總結](collector/9b34444b962ceaf7a53426a01d11698e.pdf)
- [一鍵啟動 Oracle Database 23c Free](collector/afb454044deb7c2fb8e95d70070900fa.pdf)
- [Oracle Database 23ai 體验](collector/c5a76aae24d9e59bbb652f3cac0f0373.pdf)
- [使用 podman 搭建 MySQL 8.0 主從避坑指北](collector/50c4dffbe1dc2f4c90bcb36f2fa1ff79.pdf)
- [美团面试：MySQL为什么 不用 Docker部署？](collector/fa11d8c9e87a9646e588e48bc28e7d1e.pdf)
- [用Docker-Compose / K8s 快速安装MySQL 和 Redis](collector/0a0365f5ed663011f439ecd86a77ace5.pdf)
### 維運管理

- [TiDB 相關 SQL 腳本大全](collector/d2b3ef56ccfd2ae6244fd35de8c7c8bd.pdf)

### 工具與技術

- [TiDB 的數據對比工具 sync-diff-inspector](collector/dd56bb459d0f428afe156adecbfd2455.pdf)
- [全新升级！TiCDC 新架构试用通道已开启，解锁 TiDB 数据同步新体验](collector/e39884e8aca3522cda02bf919f91f604.pdf)

### 資源隔離

- [你需要什么样的资源隔离？丨TiDB 资源隔离最佳实践](collector/af6b995ef368286d525216dce480e634.pdf)

### 性能優化

- [狂飙 50 倍丨TiDB DDL 框架优化深度解析](collector/5ed07e0d53e0bc8751e51c4f404aeebe.pdf)
- [TiDB 優化器丨執行計劃和 SQL 算子解讀最佳實踐](collector/6c32ebeee3402f4f05f5d5ab547357db.pdf)
- [TiDB 资源管控的对撞测试以及最佳实践架构](collector/bf72f910f228526b8a13ab54f5299b4c.pdf)
- [如何在 TiDB 上高效運行序列號生成服務](collector/5a12b61dad7853075f20eae390ee29c2.pdf)
- [TiDB 在個推丨掌握這兩個調優技巧，讓 TiDB 性能提速千倍！](collector/ec20509e594012ab4e3a3bc4200fc1ab.pdf)
- [一文概述 TiDB 中的索引類型](collector/a2deaba167d624726b75f88ce7683a87.pdf)
- [53 倍性能提升！TiDB 全局索引如何优化分区表查询？](collector/f7f8b48dba959823223bde33edbe760d.pdf)

- [後端架構師必備：提升系統性能的 6 大核心優化策略](collector/9425cd7265c2bc64e72af5ac5b1c551c.pdf)
- [提升資源利用率與保障服務質量，魚與熊掌不可兼得？](collector/24d897b7785f2b5d7e54d6af153d3ac1.pdf)
- [高並發 Linux 內核參數調優](collector/618c058a407fb5679ebedda83f6a9e02.pdf)
### 案例研究

- [数据规模超 1PB ，揭秘网易游戏规模化 TiDB SaaS 服务建设实践](collector/58c1dbeba8e91e42b491ec2aa92ca656.pdf)
- [Rakuten 乐天积分系统从 Cassandra 到 TiDB 的选型与实战](collector/24a666bdd34b1551caf3ff2bdc6133e2.pdf)
- [基于时间维度水平拆分的多 TiDB 集群统一数据路由/联邦查询技术的实践](collector/d4e783dc4c78c15bde1f58f19bcd1e21.pdf)
- [分布式資料庫的進度管理: TiDB 備份恢復工具 PiTR 的原理與實踐](collector/1102319937fa39dcd53a9a6f556fedde.pdf)
- [「合集」三年 50 篇，TiDB 幹貨全收錄](collector/310a7f3d66d1b7fd7cb120662fec10f0.pdf)
- [知乎 PB 級別 TiDB 數據庫在線遷移實踐](collector/8b12c380d76b70ee02aeec4ff21f3d63.pdf)
- [瓜子二手車 x TiDB 丨平均耗時降低 30%，TiDB HTAP 在瓜子二手車財務中台結帳核心系統的深度實踐](collector/994273e100bbe317b24d730c3600aa47.pdf)
- [SHOPLINE x TiDB丨集群成本降低 50%！跨境電商 SHOPLINE 交易、商品管理等核心業務的資料庫升級之路](collector/27e9099df9be2e5a232b1bb47113906b.pdf)
- [唐劉：當 SaaS 愛上 TiDB（一）- 行業挑戰與 TiDB 的應對之道](collector/396492f261f31bd2daba732f62a2633b.pdf)
- [TiDB VS MySQL 場景選擇](collector/26d1287a6f77a08fffc38a6a01a1c9df.pdf)
- [幹掉 DBA！產品經理運維 TiDB，用非技術手段攻克技術挑戰](collector/d386afd23ee5ad3fa31a559ace99110c.pdf)
- [AmzTrends x TiDB Serverless：通過雲原生改造實現全局成本降低 80%](collector/4518a11992998316304cb48a35f79dd6.pdf)
- [一名開發者眼中的 TiDB 與 MySQL 的選擇](collector/952a764dbd7eedde0553cb5770b52c05.pdf)
- [TiDB HTAP 深度解讀](collector/6c436d6832ca311822f9cc006336ff54.pdf)
- [TiDB Cloud 在金融、社交、智能風控領域的最佳實踐](collector/d17e415e3ea9f029b01340b4871dd160.pdf)
- [探索 TiDB Serverless 在新能源、跨境電商領域的應用](collector/7666e36cec2c5fd31b82eae21f936855.pdf)
- [月活超 1.1 億，用户超 4 億，你也在用的「知乎」是如何在超大規模 TiDB 集群上玩轉多雲多活的？](collector/5048ef6006bc902710136f9d234bc350.pdf)
- [TiDB 資料庫在某省婦幼業務系統應用](collector/0af9a91eb4e5ff6d75d3b951a1a9b6e2.pdf)
- [從資料庫架構選型看 TiDB 常見應用場景](collector/5f21306297f8c498e3fd82aa65287180.pdf)
- [網易互娛的資料庫選型和 TiDB 應用實踐](collector/8366ac8078d401444ca48174d32e1197.pdf)
- [TiDB x DeepSeek 打造更好用的国产知识库问答系统解决方案](collector/ac58ca0b42a9832dd7b708c2c7f5a566.pdf)
- [Cutting over: Our journey from AWS Aurora MySQL to TiDB](collector/41446ccd753567640b5543201715fb85.pdf)

### 新版本發布

- [TiDB 8.5 LTS 发版——支持无限扩展，开启 AI 就绪新时代](collector/ae6616771df941ce874202bb047524f3.pdf)
- [TiDB 7.4 發版：正式兼容 MySQL 8.0](collector/798bbffe8d7f44758e997a633940616f.pdf)
- [7.5 LTS 解讀 ｜ Runaway Queries 管理、高性能數據批處理方案、DDL 啟停特性](collector/798696a57435063e63ece1615aaf44b1.pdf)

## 開發流程與管理

### 團隊開發流程規範

- [團隊開發流程規範](collector/0ba61f00c841e9c8807906298c8adb3d.pdf)

### 項目管理

- [一文聊聊我理解的技術 PM](collector/6871c262dcc21d3c3b7ce4ec16a536e6.pdf)

### 自動化與 DevOps

- [自動化的 10 項準備工作](collector/d3a854f925bc3e4c738bb5bd5481f95b.pdf)
- [ArgoCD 的雷 碰過的人就知道](collector/a9a45617eedb98682e148905278d00f1.pdf)

### 基礎設施自動化 (IaC)

- [選擇 IaC 工具是多選題，而不是單選題](collector/d767729aa8c1ba344a005fd2c957e3a0.pdf)
- [Terraform — Best Practices](collector/92db090625bfc7b86caa1cf54d6814d2.pdf)

### 配置管理

- [一次“詭異”的 Ansible 密碼問題排查，最後的“真相”竟是這樣](collector/a85522ecb488168b0df0394577ff026b.pdf)

### 標準化與流程設計

- [如何做標準化？| 京東雲技術團隊](collector/a83ab541d88ff0e8ac0314cd43a161a1.pdf)

### 技術領導力

- [從工程師到技術 leader 的思維升級](collector/71b2e5d43a3491634adaa66b8824b45f.pdf)
- [程序员，当你意识到这一点，说明你成熟了](collector/887c7e2b69aa6bead1af5e79229cd57c.pdf)

### 容器化與微服務

- [在 Kubernetes 上跑資料庫，真的沒有意義麼？](collector/49d6d7ab28010ed561100dc3178b7872.pdf)
- [雲資料庫 RDS MySQL Serverless 已來](collector/44d83d0f5a4348f978a8cea38026c881.pdf)
- [运维加薪技术——微服务拆分规范](collector/5b4bc25279258c48724bcc837524acd5.pdf)

### 雲架構設計

- [雲計算與企業 IT 成本治理](collector/4752cf81d989834ca56dd7677283b7c6.pdf)

### 平臺設計

- [B站大数据平台故障自愈实践](collector/de2791b620b63753c4bc05e868e8cbb9.pdf)
- [B站標籤系統建設實踐](collector/9398151483b56361b103e7ad85c07221.pdf)
- [基於主動元數據構建智能數據治理體系 | 京東零售技術實踐](collector/30b2eb3f014c6499f0fada785c70fc9b.pdf)
- [遠程開發和 CI 一回事](collector/d73fc36354cc01a508c070aa678423e5.pdf)
- [愛奇藝大數據多 AZ 統一調度架構](collector/9a76ee763859f779a95930cd98f997d1.pdf)
- [廣告系統的平臺架構與交互流程](collector/2296c5e7ce59cc0f3284c0606862789b.pdf)
- [淘寶信息流融合混排服務升級](collector/48e5bb727a8d69b48b14d4e7cf1171d1.pdf)

### 緩存設計

- [如何高效实现缓存预热？一文了解九大方法](collector/2e87ddfff75380625588a9e56566fd56.pdf)
- [缓存预热怎么选？九大场景对号入座！](collector/71831de8268009bbe981d3081b1acc19.pdf)
- [在 Netflix 構建全球緩存系統: 深入了解全局複製](collector/6b201bfea29e61bcdf3f42feadad8183.pdf)
- [分布式系統架構 7: 本地緩存](collector/500d284589890b157a375d0716f15a67.pdf)
- [分佈式系統架構 8：分佈式緩存](collector/e329d14d82af19f8c8732410e682d876.pdf)
- [二級緩存架構極致提升系統性能](collector/04b541b98be61d1cc8ac33859a4d8a26.pdf)

### 監控系統設計

- [高性能！易用友好的开源实时监控系统！](collector/e5a322b63e6589f1fba641056b49008d.pdf)
- [雲監控的盲點: 用戶視角](collector/6c01c7f8685f78a5297bd600c889a0eb.pdf)
- [監控系統中的 95 分位，90 分位，是什麼？](collector/59f0e31cba4c06395b7f87db795e44d2.pdf)
- [告警平台：給告警一個膠帶](collector/6966be31852851e890b6396710a52af8.pdf)
- [可觀測性宇宙的第一天 - Grafana LGTM 全家桶的起點](collector/3e173690a95f3a280107fad07829a712.pdf)
- [Build a lab scale end-to-end Observability Platform](collector/b49bd03601324599bb5aec4fbdd0835b.pdf)
- [技術 011 - 《My Philosophy on Alerting》- 監控報警的哲學](collector/02581dc354de9f20ea6917d6e6764de8.pdf)
- [Prometheus 如何監控指標，快速定位故障](collector/a4321b7b5f8ee0884724922720b61595.pdf)
- [基於 Grafana LGTM 可觀測性平台的快速構建](collector/539651cce16d117833dbb8af11c8046c.pdf)
- [雲原生可觀測領域的半壁江山，這次被 Grafana 和 Cilium 給拿下了](collector/0044dc5ad4496e51b7de50f10b0273fa.pdf)
- [B站前端錯誤監控實踐](collector/749b755e560d76f0bc0411393ba9573c.pdf)
- [基於 Prometheus、Thanos 與 Grafana 的監控體系詳解](collector/7d340f3f760b1d950f29747526397cbd.pdf)
- [可觀測性與傳統監控的區別和聯繫](collector/57a54890436038bbdcc3abcd130d9785.pdf)
- [A Modern Guide to MySQL Performance Monitoring](collector/116d0744d4b5407d9e5c6eb9fc324405.pdf)
- [Top key metrics for monitoring MySQL](collector/b3172b34c930168aaa8f7c70759de72d.pdf)
- [MySQL 性能監控全掌握，快來 get 關鍵指標及采集方法！](collector/08bdb13c0f6e56c65e34f257e2361501.pdf)
- [数据库指标集的设计思路](collector/d8d64e1cf5a12828ca30a9f84dce3ff6.pdf)
- [OceanBase在传统监控数据存储的应用](collector/371ee94759aab8f941c8e302145321f0.pdf)
- [一次线上生产库的全流程切换完整方案](collector/dcda36a9b4a96a259d5f64f830720cd6.pdf)
- [高频面题： 你们线上 QPS 多少？你 怎么知道的？](collector/c6d910c00e0be92213b9cc93886ca326.pdf)
- [运维服务绩效考核指标V1.0](collector/08efda3a78c7dff8e52444546f14ed46.pdf)
- [深夜网络故障秒解决！这个开源监控工具 (smartping) 让运维告别通宵](collector/4f0b91ec24b33fd77f9ee4c0bd56977f.pdf)
- [暴揍ELK 痛打Loki - VictoriaLogs 搭建Syslog日志收集存储系统](collector/2331b3144809d3d7f9412ed9cd0d0341.pdf)

- [MySQL 運行時的可觀測性](collector/7a60dc31f53e71ff0b92421183087387.pdf)
### 分佈式系統

- [再談 Raft 一致性算法](collector/a63b722e337c94c448469cbaeda2780a.pdf)
- [Raft 一致性算法](collector/de0b10ad6a3933d4997a21c64f7947d7.pdf)
- [一文看懂微服務世界性技術難題——分佈式事務](collector/ebd1229c005d4aa71c1428465b0cf000.pdf)
- [招行面试： 分布式调度 设计，要考虑 哪些问题？](collector/9de93ff7cc8284361c55959ed7b7b58a.pdf)
- [Multi-Region Distributed SQL Transaction Latency](collector/8feff8720c498d0cc1d51b5c453d23c9.pdf)

### 高效能設計

- [為什麼高手都要用非阻塞 IO？](collector/c96f1895052b469c48c42ddb0c22b9a0.pdf)
- [如何設計一個秒殺系統](collector/f400595a754aef9c556f00d1fc68154a.pdf)
- [看看你的應用系統用了哪些高並發技術？](collector/5a3e9a95c25c9898938317a9e04aa65a.pdf)
- [千萬級高性能長連接 Go 服務架構實踐](collector/7d56bd12f7ce4e49c7679dc0a74db7e0.pdf)
- [高性能無鎖並發框架 Disruptor](collector/9ab508ea9d37ca7e68022a4d97c17d86.pdf)
- [揭秘 10 億+ 高並發應用如何實現高效穩定的開發和運維](collector/29124bfed232ff376eac386866d868a4.pdf)

- [十年後資料庫還是無法擁抱 NUMA？](collector/e70189e2613b25fdc54c24dd0bacdaf2.pdf)
### 業務架構設計

- [關於業務架構基礎知識的二三事兒：業務能力](collector/f28a6b0b0c287d980d0e6455bef1aa33.pdf)
- [中小銀行如何構建智能風控體系？明確業務需求比盲目求新更重要](collector/8b0dc82c8bc537b2bfadc1194f6dda77.pdf)

### 數據治理

- [業務數據治理體系化思考與實踐](collector/78aebc04d946bc99a8428426dfdc8163.pdf)
- [數據指標體系搭建實踐](collector/bc1e1aaf502c59c8416a933e838f545e.pdf)
- [數據質量和數據治理的關係 | 京東雲技術團隊](collector/792df6acaebabccdf938d861398e4a61.pdf)

### 系統設計

- [如何熟悉一個陌生系統](collector/107b1af0b7b25d9fbe7c070feba47834.pdf)

### 設計模式

- [提升用戶體驗的 UUID 設計策略](collector/89f733a8723e36f2f85fe570fbe1ce02.pdf)
- [time zone 這些 BUG，防不勝防](collector/44b0a9b336e6d445876bd777a34fb8b2.pdf)

### 消息隊列設計

- [Why Do We Need a Message Queue?](collector/2b72721c0360d3db80da67d933324c06.pdf)

### 故障處理與預防

- [Google 工程師如何在實踐中避免和處理故障](collector/265e03c33a8abcd3cfe08219bf970788.pdf)

### 可靠性設計

- [前任開發在代碼裡下毒，支付下單居然沒加幂等](collector/2c0e221a4d2a3d0e11df8e9bcdd8514e.pdf)

### 可用性設計

- [什么是系统可用性？如何提升可用性？](collector/304d33ad22f32d52cc212a8465a01613.pdf)
- [B站直播 S14 保障全解析: 高效保障技術實踐](collector/919208eda3c2cbdf3d382535ea6588fe.pdf)
- [異地多活架構進階: 如何解決寫後立即讀場景問題？](collector/81bdab7c9176334dde17b66f985af117.pdf)
- [B 站輕量級容災演練體系構建與業務實踐](collector/02005b363a530bfca0b776f7a0ccd481.pdf)
- [【穩定性】穩定性建設之變更管理](collector/290705b8cfe5c418572d1f2f7d66a8f8.pdf)
- [關於『穩定性建設』的一些思考](collector/1764f90c573a90e5562b3b781ab886db.pdf)
- [淺談團隊如何做好系統穩定性](collector/03157529f9534b578a94fb57dc20c6a7.pdf)
- [如何從 0-1 的建設雲上穩定性？](collector/ec9347a5eee122f836c568ffffb8a27e.pdf)
- [超大規模資料庫集群保穩系列之一：高可用系統](collector/9a3c31cdbd7bcaaeb71c74d2758815c7.pdf)
- [超大規模資料庫集群保穩系列之二：資料庫攻防演練建設實踐](collector/2363f83ac347c8e3e1c148804be7270a.pdf)
- [超大規模資料庫集群保穩系列之三：美團資料庫容災體系建設實踐](collector/5c22c86cab79a213aa0f3e774fb65a44.pdf)
- [從項目風險管理角度探討系統穩定性](collector/f26a1d7db8751248a9458210f4ee342e.pdf)
- [穩定性方法論：可灰度 & 可監控 & 可回滾](collector/e48e705554489935651e667b574d3058.pdf)
- [穩定性建設之依賴設計](collector/92d095e0a7ede211a14fbe4ef30812e3.pdf)
- [爆發式增長業務的高可用架構優化之路](collector/b5c82627ea7a00b7d09324820dd309ac.pdf)

## 資料庫原理

### 資料庫比較

- [PG vs MySQL 统计信息收集的异同](collector/02222d3b5e103580e0ba3e888fcb3677.pdf)
- [MYSQL 8 VS MYSQL 5.7 在复杂查询中 到底好了多少](collector/a6a1c3c0e928e9f97c6e3fc32e91ce5d.pdf)
- [默认配置下，为什么 MySQL 8.0 比 MySQL 5.7 慢？](collector/3417bbea01f3da303fe6587e9ec538f1.pdf)

### 發展與趨勢

- [圖靈獎資料庫大師 Stonebraker 師徒對資料庫近 20 年發展與展望的 2 萬字論文](collector/195a316902e2c6ebcb72754be0fec3b2.pdf)
- [10 種資料庫技術的發展歷程與現狀](collector/3de90bfbaff6cd7491e37c7fb5714cd6.pdf)
- [五年沉澱，微信全平台終端資料庫 WCDB 歡迎重大升級](collector/add7e8f0135831a046531de5ef1ef67b.pdf)
- [2.8萬字總結：OceanBase 資料庫在金融核心系統升級路徑與場景實踐](collector/46dd0fd233797b1d5a31ea05b7a7c84b.pdf)
- [黃東旭：“向量資料庫”還是“向量搜索插件 + SQL 資料庫”？丨我對 2024 年資料庫發展趨勢的思考](collector/86e6ff1f64f293b7dbda6ccc1fad65e3.pdf)

### Buffer Pool 深度剖析

- [数据库性能优化之道: Buffer Pool 深度剖析（一）](collector/b0e035468657e143017813f07af2263f.pdf)
- [数据库性能优化之道: Buffer Pool 深度剖析（二）](collector/30f14ae923d74b101276b457397c9e56.pdf)
- [数据库性能优化之道: Buffer Pool 深度剖析（三）](collector/a341f53008e995783c31665b88ea62d8.pdf)

### 鎖機制

- [多线程读写锁产生死锁的故障解决方案](collector/e3635325a2d98d51abd3e0bd1e897305.pdf)
- [MySQL 是怎麼做並發控制的？](collector/e6737cbc96da2ff050b837cf2d0e665f.pdf)
- [MVCC 如何應對 MySQL 並發問題](collector/ca14bed799d35fc4adb9a0f62af1bd8a.pdf)
- [学会这招轻松解决数据库分布式锁痛点](collector/860d10697bbb76c235fcd77274dab0fb.pdf)

### Undo 日誌

- [MySQL 如何插入记录的 Undo 日志？](collector/ae312ce915141a3b796a129cd7d7170b.pdf)
- [Undo 表空间分配回滚段](collector/bc6f838fdd36f9c671f80a91cab79951.pdf)
- [MySQL 分配 Undo 段](collector/dacc7b2ec50c463fd88b3c0f76cfad04.pdf)

### double write機制

- [MySQL 8.0后的double write有什么变化](collector/db466c72aba42f19b73eb86c22209606.pdf)

### 事務管理與隔離級別

- [学习 MySQL 必须了解的几个 Undo 概念](collector/0d98d837392fad916ca0ec993690421e.pdf)
- [MySQL 的默認隔離級別為什麼是 RR, 而不是 RC](collector/0e1e0313ecb9fbd59e27a609cef0705f.pdf)
- [MySQL 數據加密原理和解析](collector/d1599c75c0446a7645889953a54ed234.pdf)
- [MySQL DATETIME 毫秒坑](collector/cde9a293df0148928f7f6abdb8d99c8e.pdf)
- [PG vs MySQL MVCC 機制實現的異同](collector/a2eba635f7a208fceb4b1753c6184b17.pdf)
- [你真的理解 MySQL 的事務隔離嗎？](collector/085302eadb992a732a584739377a1221.pdf)

### 分佈式資料庫

- [談談分佈式資料庫的分片鍵選擇準則和數據重分布的思考](collector/b4b1abba675ec98a51ed46678dd748af.pdf)
- [招行面试：高并发写，为什么不推荐关系数据？](collector/2be116ef3fe501312dc262e4bf18ed04.pdf)

### 資料庫學習資源

- [Oracle 官方文檔整理以及閱讀指南](collector/e7eca656effbcb1f7a834641d6b4e66e.pdf)
- [YashanDB 資料庫概念手冊正式發布](collector/62a96627bcdda9e587dd92af4b4d623e.pdf)

## 資料庫優化

### 查詢性能優化

- [為何要小表驅動大表？](collector/b15cea0e52bc2b147a982bd0d42b77f5.pdf)
- [EXPLAIN TYPE 列的 JOIN 常见场景详解（上）](collector/1059aadb9ba78b94ac181ac7b2f82d3d.pdf)
- [從MySQL索引下推看性能優化: 減少回表，提升查詢效率](collector/217028f183386f55576c92270b1185be.pdf)
- [MySQL底層概述—7.優化原則及慢查詢](collector/34608efa79dafe8421af5c2c7c9d3038.pdf)
- [SQL 調優實戰: 分頁語句中你真的了解 COUNT 索引嗎？SORT ORDER BY 的存在就一定很糟？](collector/f7a8df8b89aff3049775b4d17e41f7a7.pdf)
- [一文讓你對 MySQL 索引底層實現明明白白](collector/0c13009f75e503fc241380577e1e1714.pdf)
- [数据库优化](collector/72ef824ce9b8942f1539498272bee9f4.pdf)
- [拒绝全表扫描！3个提升MySQL深度分页技巧！](collector/e1462e7727b76b3201c2f59f40b77572.pdf)

### SQL 優化技巧

- [重現一條簡單 SQL 的優化過程](collector/2521eca551359e30b8f64337d32bfc87.pdf)
- [一个不可思议的SQL优化过程及扩展几个需掌握的几个知识点](collector/75be5e203e2525680ca0da0f0f670615.pdf)
- [從源碼分析，MySQL 優化器如何估算 SQL 語句的訪問行數](collector/58533fe1f1c6095cb0e2f3955e58159b.pdf)
- [MySQL JOIN 的高階使用](collector/51c199aad1722448a7614d1775936198.pdf)
- [MySQL 全文索引](collector/1da8692fcd96135669d10058ee6ba62b.pdf)
- [MySQL8索引篇：性能提升了100%！！](collector/814120882b6dc79670eb6ef15d5d275d.pdf)
- [《MySQL开发规范》过时了，视图的查询性能提升了一万倍](collector/dbfd739fa6148e81c1b1e24263eafbf3.pdf)
- [技术分享 | MySQL 表空间碎片整理方法](collector/3aba28a31c245563bc6d4253665d9938.pdf)

### 性能分析工具

- [MySQL 优化利器 SHOW PROFILE 的实现原理](collector/4161c619d44a078a2cbebea93dd7a452.pdf)
- [MySQL性能分析的“秘密武器”，深度剖析SQL问题](collector/7bff90a70d31863b2836c1fa9e5c903e.pdf)

### InnoDB 優化

- [InnoDB 索引与 Online DDL 的结合: 业务不中断的优化秘诀](collector/0cc7ff4443fbb0cb3c90ca79bc6b9dcd.pdf)
- [InnoDB 的覆蓋索引實踐](collector/b79dbda815b5964f80e03209fc7b8e33.pdf)

### PostgreSQL 優化

- [PostgreSQL SQL优化用兵法，优化后提高 140倍速度](collector/2d2497bf4c0c4b1f1e89aef13fecb77d.pdf)

## 資料庫工具

### 可視化工具

- [直观且高效！一个 Redis 可视化工具！](collector/89f9984a8f95983ed998b21c78e1358e.pdf)
- [資料庫源碼學習調試利器之 CGDB](collector/df1ae51824a2a79e5ce2a4ae746cc4c1.pdf)

### 安裝部署工具

- [2025 年宣布一件大事，Oracle 一键安装脚本开源了！](collector/c6d772c8efb21f71e0ac6c7c4556c7c8.pdf)
- [PostgreSQL 17 主从部署、配置优化及备份脚本最佳实践](collector/825f016a8bf6ec8012fbbcff9da759e6.pdf)

### 高可用與分佈式數據庫

- [Galera Cluster 不存在同步延遲？不，Galera Cluster 到處都是同步延遲](collector/5037fe8c2b130ac3ec51ab1522d6e874.pdf)
- [Galera Cluster 一致性問題](collector/c987ef17da2cd800c929f41f933f30f9.pdf)
- [数据库高可用架构的尽头是RAC吗？](collector/d5c67c9dabfacf13dbf7d7b7a460938a.pdf)
- [6种MySQL高可用方案对比分析](collector/eedc3f072f2fb6b4fa133eafc44bdace.pdf)

### 中間件

- [MySQL ProxySQL 在深入信息獲取和信息輸出](collector/836dd0d3a1fafd647498cb0d2cbe5083.pdf)

### MySQL 存儲引擎

- [詳細解讀 InnoDB 存儲引擎](collector/5e700227287ae6f14ad8d3a305c804ab.pdf)
- [關於 MySQL checkpoint](collector/098499a5822a1ebae8f2016ac0d796e4.pdf)
- [MySQL Binlog 源碼入門](collector/7506a36633e3bc12944c670f6319ebd6.pdf)
- [MySQL 底層解析——緩存，InnoDB_buffer_pool，包括連接、解析、緩存、引擎、存儲](collector/0e9882cbb3c7917b26251aba1dd71df1.pdf)

### MySQL 設計與實踐

- [詳解 MySQL 字符集和 Collation](collector/70d6796cf7d059fc575ac8263506713b.pdf)
- [MySQL 數據結構設計及開發規範](collector/d30f1d26fac1b8e04980a7f140c504c4.pdf)
- [故障分析 | 为什么 MySQL 8.0.13 要引入新参数 sql_require_primary_key？](collector/b99633e6d09d838bd40f4241534d131e.pdf)
- [MySQL 核心模块揭秘 | 51 期 | 开年暖场，回顾和展望](collector/1779f76e21a977df4b808288e4b2132a.pdf)
- [MySQL 的JSON类型违反第一范式吗？](collector/66b76895904726f19c1fb184b1c8fc81.pdf)

### MySQL 安全與審計

- [MySQL 數據庫審計采集技術調研之 Packetbeat，eBPF](collector/c7fe39393f4a540c8962e2a8d7ef3ebe.pdf)

### MySQL 資料庫管理

- [實戰過程記錄：瀕臨宕機的業務系統僅優化 1 個 SQL 即恢復！](collector/5450d4d89dd0b48d368c766133e165a4.pdf)
- [安裝部署 MySQL 8.2.0 並使用 changer master 傳統方式搭建部署一主一從操作記錄](collector/adff8ea24b970c9925d7421a9c0d0708.pdf)
- [xtrabackup 8.0 如何恢復單表](collector/813c74ea2eee6595f183870c6c05af83.pdf)
- [MySQL 複製中 slave 延遲監控](collector/9793d273762077412ec1100458f4fee7.pdf)
- [GRANT 之後為什麼要 FLUSH PRIVILEGES](collector/07a24e9e6324a0563f5cb3deff2b1f58.pdf)
- [三歪連 MySQL 大表怎麼 DDL 變更都不懂](collector/747015c71672d076a19bf363ff9e7bc5.pdf)
- [意想不到的 MySQL 複製延遲原因](collector/681f331f41efc7e130c57fe0adb36cfd.pdf)
- [全網最詳細之 pt-osc 處理 MySQL 外鍵表流程分析](collector/542079bda9492131b774e9eed82ebd01.pdf)
- [效率+100%: MySQL运维脚本大揭秘](collector/d2ba048e0f911a5cdd01fd9fa96b859c.pdf)
- [[MYSQL] 忘记root密码时, 不需要重启也能强制修改了!](collector/09e74f0a28f3954c6ffca5acac1d6de0.pdf)
- [MYSQL统计信息详解](collector/367d191d3c04c078f0fbe3096c65c976.pdf)
- [MySQL数据库idb文件过大处理方法](collector/c1131b0454f0681cee2e3419ff02c5fe.pdf)

### Redis 設計與實踐

- [從一個事故中理解 Redis（幾乎）所有知識點](collector/a83040219e29aee212c16a1479831a52.pdf)
- [Redis 高級特性與應用——發布訂閱、Stream、慢查詢、Pipeline、事務、Lua 腳本](collector/e7827ac48447228327d033fd51d65087.pdf)
- [如何做到 Redis 毫秒級大 key 發現](collector/77e2359b6ffe175ae1fe9d40cb96f4b7.pdf)
- [Redis 內存突增時，如何定量分析其內存使用情況](collector/fad7c38e3934be3d1ec05e72c73c16b7.pdf)
- [Redis 的 I/O 多路復用技術，它是如何工作的？](collector/1383af16f652ba96ef3a1a2ccd7811cb.pdf)
- [得物自建 Redis 無人值守資源均衡調度設計與實現](collector/e971799877653511eabc9df4aeea104c.pdf)
- [一次線上腦裂故障讓我徹底搞懂了 Redis 集群原理](collector/2c5c534818a5d59287014c32c39219cd.pdf)
- [Redis 性能刺客，大 key](collector/20ebd916b868d194b735cd2e2e7de577.pdf)
- [Redis 基礎知識典藏版：架構設計、功能特性、應用場景、操作命令](collector/6071e9a6c8582c6e7686babe133f4129.pdf)
- [美團二面: 如何解決 Redis 熱點 key 問題](collector/9481b6b1dc40262da708cc295fcfcf53.pdf)
- [Redis 分布式鎖：實現與應用](collector/86d4255c1e9b4491db7e123bc5356267.pdf)
- [Redis 縮容導致線上大規模故障的慘痛經歷](collector/5affc9038bdd2ecfa79730a7fcdcad38.pdf)
- [Redis 內存回收](collector/ebd5be6a2515570bc962b5b5532c9494.pdf)
- [騰訊音樂：說說 Redis 腦裂問題？](collector/101850f77b5ef2dedab91a52e2ed7742.pdf)
- [Redis 架構實戰 - Redis Request Routing/效能監控與調教](collector/a586506fbf5e39188e8662c2a5ef36ae.pdf)
- [Redis Sentinel - 深入淺出原理和實戰](collector/27ee62e48490adce210c13eb3c0a9c63.pdf)
- [Redis 哨兵](collector/49bd088a990a7dda68e668d5c27c4c34.pdf)
- [真·Redis 緩存優化—97%的優化率你見過嘛？ | 京東雲技術團隊](collector/1ccd2bc3061d196cb93e40b4a3d8a197.pdf)
- [Redis 運維之內核參數調優](collector/65e8c6a2dd8b1a4db8fc533d6848dd7b.pdf)
- [Redis 壓力測試工具 redis-benchmark](collector/2434111e62fe5a91f5e4ce60efc1ff6c.pdf)
- [緩存有大 key？你得知道的一些手段](collector/b9baf5df840c23c5921f322b1d662874.pdf)
- [Redis 系列（一）：認識 Redis](collector/63a37d9b9ca98f9b3b99170e36b50550.pdf)
- [Redis Explained](collector/0c8514fb2935bb0e8dc7f792246a6d3d.pdf)
- [Redis 7.0 源碼調試環境搭建與源碼導讀技巧](collector/2f0189726bba86fd958eb14e09388674.pdf)
- [來來來，快速撸 Redis 一遍！](collector/fc7fb93fd3428a7643605f8199852f6b.pdf)
- [Redis - 快取雪崩、擊穿、穿透](collector/7c13c82a8913f6c6ef6bc8b0e1b3894d.pdf)
- [Redis 快取擊穿（失效）、快取穿透、快取雪崩怎麼解決？](collector/d74fed5a0ea1396efe26284e1e7e0dc9.pdf)
- [Redis Multi-Threaded Network Model](collector/c1c5a19002363ec9e4f3d22659442fce.pdf)
- [詳解 Redis 分布式鎖的 5 種方案](collector/91fb322e736a26fcf759fec5ed8d65f3.pdf)
- [Redis 面試題集錦](collector/47caffb02a1d2f628c02e1ee74619b99.pdf)
- [Redis LRU 算法和 LFU 算法](collector/83bd3cfd4b71fc8fb1ebfbc9cc02eb91.pdf)
- [Redis 持久化-RDB(详细讲解说明，一个配置一个说明分析，步步讲解到位)](collector/7760f6bf93ac47495e17db3da739d9d4.pdf)
- [Redis 持久化-AOF(详细讲解说明，一个配置一个说明分析，步步讲解到位 2)](collector/2aea9f3c4968a9344f8d1384cb709267.pdf)

### NoSQL 資料庫設計

- [在 MongoDB 建模 1 對 N 關係的基本方法](collector/13802f213af712dae47aa9d1df634b54.pdf)
- [MongoDB 寫安全 (Write Concern)](collector/323dcd05c49a0ccdd23533064c92937d.pdf)
- [MongoDB Schema Design: Data Modeling Best Practices](collector/7cfa2cbed43e77115142e6d573d2f440.pdf)
- [MongoDB 提升效能的 18 原則（開發設計階段）](collector/80289b23686d00a83a80ca6767f3eb4f.pdf)

### NoSQL 資料庫工具

- [MongoDB 集合結構分析工具 Variety](collector/5cb911c327da3ce8b96baa5a7090d0b2.pdf)

### NoSQL 資料庫維護

- [MongoDB 磁碟清理那些事兒](collector/ded2afddbbecda4a36a0bd8da64ba6b1.pdf)

### 調試與排查

- [從零開始學習 MySQL 調試跟踪（1）](collector/922b703f278bb1f6fe3372861644106e.pdf)
- [從零開始學習 MySQL 調試跟踪（2）](collector/fb3635d67aa05bfa9595045817adc308.pdf)

### 自動化工具

- [MySQL数据库巡检报告，一条命令搞定，省心又省力！](collector/372f7d390eae89de0de5f617d18d4fdd.pdf)
- [MySQL一条命令生成数据库巡检报告进阶-生成更好看更美观的报告](collector/81bbce42402ad3067c110d8408b6b2f2.pdf)
- [近期客戶需求巡檢自己編寫整理的 SQL](collector/747278457a0b9e4b440922031694b5c9.pdf)

### OLTP 系統設計

- [GBASE 南大通用專家訪談：走進深水區，核心系統需要什麼樣的（OLTP）資料庫？](collector/f71e5577f6761159acd6f588bff82b1a.pdf)

### 圖資料庫設計

- [圖資料庫採購 | 做好三大問題的前置思考](collector/b7ac18169e19ad481417d57f8691ddd1.pdf)

### MySQL 新版本

- [该开始关注 MySQL 8.4 了](collector/474db9c225132febf28cf0237f6756b5.pdf)
- [技術譯文 | MySQL 8.4.3 和 9.1.0: 顯著提升性能！](collector/3af90e819f357a240e851eb7f9e58f5c.pdf)
- [MySQL 好玩新特性：離線模式](collector/7e890105f953a5640b5d254878d8d5a9.pdf)
- [新闻 | MySQL 9.2.0 有哪些功能新增、弃用和删除？](collector/c6fa92e5ff944c2e247abef4b82d02a3.pdf)
- [MySQL 8.4 版本(LTS) 发布，一睹为快](collector/f5afb7bc9f6e72f0554d4b087cb97916.pdf)

### Oracle DBA 指南

- [看透Oracle DBA赚钱的另外一层逻辑](collector/51ddf38d06733b767208de80242be46e.pdf)
- [oracle awr 报告详解](collector/32e1c4ac785a9c814df4739817f6ef6e.pdf)

### MySQL DBA 指南

- [MySQL 數據庫面試題總結](collector/d35c4e4aac3ce13fbc2a096f93a6ca98.pdf)
- [這些年背過的面試題——MySQL 篇](collector/c5f0e561e700c1ccba0c1fa2ba7ab330.pdf)
- [MySQL DBA 防坑指南](collector/4ce0b3f917daa79230d277dfbc115c16.pdf)
- [多年 DBA 實戰生涯有哪些經驗教訓](collector/9a3940bcde09289b13996507d0bb3452.pdf)
- [運維實踐｜MySQL 命令之 perror](collector/07a717881b13a95b7c412894c5c890a6.pdf)
- [資料庫運維的 N 條建議](collector/029ba53675722edcf473b3cbf8963ab8.pdf)
- [MySQL 運維高危操作](collector/4c5c7ea86f85576b90bde65b02e956c3.pdf)
- [MySQL 運維](collector/fabc880add2352bb94926c7d4ce0eb7d.pdf)
- [MySQL 運維實踐｜稀里糊塗的解決了 MySQL 子帳號過期、密鑰問題](collector/d8fe534bcb7c4945ecc285d3f14d044e.pdf)
- [MySQL 資料庫認證考試介紹（2024 版）](collector/d031211a2d6e799ebde9a48c5f5e255b.pdf)
- [資料庫內核工程師必讀論文清單](collector/a2487e6a2ea1cdfdfc4320249e7d1208.pdf)
- [Oracle DBA 必備的 101 道面試題](collector/5b5b3c8a84ca9d82265291dd5df410cb.pdf)
- [MySQL 自治平台建設的內核原理及實踐（上）](collector/26c7b841d9c64290bf8f23d5052f45be.pdf)
- [MySQL 自治平台建設的內核原理及實踐（下）](collector/bfd730f8429ec1986a03f22dc2fa7a46.pdf)
- [DBA 計劃外工作的一點思考](collector/756ed68c2e8bb8dbc4f5a0f01cec6362.pdf)
- [資料庫產品選型測試 集中式與分佈式](collector/b7fb2cf132e9b86c3637ef3e3767376b.pdf)
- [DBA 不僅僅是管理資料庫--也要管理好需求](collector/317f32cc2d1a887c396b32809ebb9252.pdf)
- [DBA 不僅僅是管理資料庫--也要管理中間件](collector/0019408e20acf5f3555bc2459da94fba.pdf)
- [DBA 的前景怎樣？](collector/f282805a621b32c9815451ada68aa6b7.pdf)
- [MySQL OCP 認證考試你知道嗎？](collector/b7c012df75c4a8c65ceb74ab23a90ab6.pdf)
- [資料庫設計 (MySQL) 避坑指南](collector/e9e93bba19be3d44d59ca672e4ca49b2.pdf)
- [知识积累能力是DBA最为重要的能力](collector/1071aa59c60a8ef26436ef8fafd33b40.pdf)
- [DBA是个创业成功率比较高的职业](collector/8413ed49d763ba958296992331692b3e.pdf)
- [假期结束了，DBA们又要忙起来了](collector/306a2fdd62275d347be82a00faf87f3e.pdf)

### SQL 優化與調優

- [千萬級數據深分頁查詢 SQL 性能優化實踐](collector/b4c969cc750dfea59f6824a3c3a6884a.pdf)
- [MySQL 為什麼「錯誤」選擇代價更大的索引](collector/2669ad45cecf54d617286f26b3add8cf.pdf)
- [MySQL 查詢為什麼選擇使用這個索引？——基於 MySQL 8.0.22 索引成本計算](collector/07ef646c6cb296008218c2bde1fa7c48.pdf)
- [MySQL-extra 常見的額外信息](collector/a298dd2bf5726df03a02ce438b399390.pdf)
- [運維實踐｜淺談 explain 的使用](collector/5f3d079a8a599f1c3f17644b42d1059d.pdf)
- [索引下推，這個點你肯定不知道！](collector/7c66d17390ff9a6df1b863861bd07b29.pdf)
- [複雜 SQL 治理實踐 | 京東物流技術團隊](collector/4210c288c9a0ab0b576a21322ded5cf7.pdf)
- [奇思妙想的 SQL｜兼顧性能的數據傾斜處理新姿勢](collector/e7159a79bff33500e66dcd8c83b194c2.pdf)
- [PostgreSQL 打破認知幻像：你寫的 SQL 是否如你心意？](collector/93780619a420a021f8a62310bf13318e.pdf)
- [基於代價的慢查詢優化建議](collector/1e5a96baa1b47abd695db96226e4d814.pdf)
- [SQL 語句 Cost 花費判斷](collector/13de9bafc7f57700887118dc971f3b70.pdf)
- [這句簡單的 SQL，如何加索引？顛覆了我多年的認知](collector/b121609000b4d8151c7644a80e0b1da1.pdf)
- [高級 SQL 優化系列之外連接優化](collector/ef1d7c7aad615b5d23ecb62a7d6419c4.pdf)
- [数据库慢SQL治理，让业务跑得更快](collector/88c8a4cc3a0652039894b5a92745d5d7.pdf)

### MySQL 性能優化

- [MySQL 唯一鍵衝突與解決衝突時的死鎖風險](collector/641c6bf58c66c8289d1f3afb9c8322c5.pdf)
- [如何精確監控 DB 響應延時](collector/07a3538f5432289854dc9757b45aede7.pdf)
- [執行 analyze table 意外導致 waiting for table flush](collector/5bf9d1d0905f632298cf0a98cefd6aa9.pdf)
- [profiling 中要關注哪些信息](collector/364f4dfffda278498ec5ad5699969eeb.pdf)
- [processlist 中哪些狀態要引起關注](collector/9e92b067b97402a563e5c4b170238c0c.pdf)
- [如何閱讀 MySQL 死鎖日誌](collector/8e61ea932eead7717bffe5e2796f001a.pdf)
- [如何使用 bcc 工具觀測 MySQL 延遲](collector/f0bc01c71363634b79aaa1216000b41d.pdf)
- [MySQL 性能診斷實踐之系統觀測工具](collector/0b815a98abff315fe50e653f5df3a6bb.pdf)
- [性能運維 -- 借助 pstack + strace 排查 SQL 性能問題](collector/0f81bb5e9e927269f46f5dfa3b2bcbea.pdf)
- [我說 MySQL 每張表最好不超過 2000 萬數據](collector/5b7666c86b5b31b53878096412a71aa2.pdf)
- [為什麼說 MySQL 單表行數不要超過 2000w？](collector/3ce26dec621f56b972282463c68c3417.pdf)
- [MySQL 性能優化：從普通程序員的角度出發](collector/0dee63158798f5b970a4b7475220948d.pdf)
- [用蜜蜂 (eBPF) 來追蹤海豚 (MySQL)，性能追得上嗎](collector/220a46a80d79e7909277fef80cca9a77.pdf)
- [MySQL 8.0.35 企業版比社區版性能高出 25%？](collector/39f02aea862b12f6283f50d2a9ac4e1c.pdf)
- [MySQL 中的 SQL 調優設計](collector/3aef6722b6a737086a27c76a4aab979f.pdf)
- [DBCP 一個配置，浪費了 MySQL 50% 的性能！](collector/ccb59c456a3bd191d7826ccb513aa08c.pdf)
- [淺析 MySQL 代價估計器](collector/c7fe501ea5c0351c788748b4669f0b48.pdf)
- [MySQL 高階調優，一文讓你從入門到精通！](collector/aa5eda94ae1f55aaf2e53ca0bef8e683.pdf)
- [搞懂 MySQL 中的優化器與成本模型](collector/a69f1499718af619f505a7bc9a176ea0.pdf)
- [MySQL 中的 InnoDB Buffer Pool](collector/1910e6904f0fb569a19be4a24b171c18.pdf)
- [MySQL 如何加速讀寫速度？來看看 Buffer Pool](collector/c5ccce85f8dd2d29e4493536ecda5797.pdf)

### MariaDB 設計與實踐

- [使用 MariaDB Thread Pool 實現 DB 端的連接池](collector/a496ce8991961e0a30a98cdcb608319d.pdf)

### MariaDB 性能優化

- The Optimizer Cost Model from MariaDB 11.0
- [連結](https://mariadb.com/kb/en/the-optimizer-cost-model-from-mariadb-11-0/)

### 資料庫安全與權限管理

- [PostgreSQL 權限管控，還可以再簡單點](collector/1feba66c0577ef67ed23beb17c43025f.pdf)

### 數據一致性

- [探索 Redis 與 MySQL 的雙寫問題](collector/014f6d8449fb1d87feb08583d79ba2b0.pdf)

### 性能故障應急

- [数据库常见性能故障应急场景](collector/54bf88b72446638d64f703c20b0e4b3c.pdf)
- [從一個故障案例談資料庫運維中的數字化分析之路](collector/3c5969ada6e425d2b91e3c2d25bd33c3.pdf)
- [MySQL 內存為什麼不斷增高，怎麼讓它釋放](collector/662013dda71c61bbe2c09ad1428dad4e.pdf)
- [MySQL 8.0 不再擔心被垃圾 SQL 搞爆內存](collector/75f22d95afec6fbdec8ad6a7b593cde7.pdf)
- [MySQL ProxySQL 由於漏洞掃描導致的 PROXYSQL CPU 超高](collector/9f30c18db7a9308c4d4fc06a8b4e45c1.pdf)
- [資料庫異常智能分析與診斷](collector/15c525f09b5d02cf6690c65d97756f1f.pdf)
- [天啊，這個 MySQL 故障定位方法太好用了！](collector/913838650560b9b03c229fddfad4cdd3.pdf)
- [mysql 内存使用率高问题排查](collector/97425cfd61349709f701d3e36551b7cf.pdf)
- [MySQL 8.0版本mysqld消耗大量主机内存不释放还可能导致数据库重启【排查与解决】](collector/b0f328c98f3099e1010db8564c79a3e1.pdf)

## 作業系統研究

### 內存管理

- [深度探索Jemalloc：内存分配与优化实践](collector/e9306a342d9b36289c228d0dadb76b0c.pdf)

### 線程與資源管理

- [別再糾結線程池池大小、線程數量了，哪有什麼固定公式 | 京東雲技術團隊](collector/1d98657cac48cb47af146f250f965e3b.pdf)

### 進程管理

- [Linux 進程管理和啟動流程](collector/26bd06e3f8f79d60d645c40bafe81cb0.pdf)
- [解锁Linux“故障宝藏”：Core Dump分析秘籍](collector/45526cc680de3ac7e39e27e4f1ea82d6.pdf)

## Application/Toolkit

### Github

- [stock 股票. 获取股票数据, 计算股票指标, 筹码分布, 识别股票形态, 综合选股, 选股策略, 股票验证回测, 股票自动交易, 支持PC及移动设备](collector/316046afa4a8a6b4d16334018c69e804.pdf)
- [20.1k star! 太强了，一个浏览器直接能跑20+种操作系统！](collector/82d9c578076157c35ced42d85a3e94d1.pdf)
- [34.5K star！又来一款全能开源笔记神器，超好用！](collector/c95827d768117332fbe12c185270d3c1.pdf)

### 監控工具

- [開源全方位運維監控工具：HertzBeat](collector/99574e36ba022a0a02cf9b9545f7d55a.pdf)
- [The path to learn observability following Grafana LGTM stack](collector/6326e10c25c00731fb010b2ae6feab55.pdf)
- [Say Hello to Grafana OnCall](collector/13c9a75a3b73f640e3b274638cd14d59.pdf)

### 緩存工具

- [Garnet 是一個來自 Microsoft Research 的遠程緩存存儲，提供強大的性能、可擴展性、存儲、恢復、集群分片、密鑰遷移和複制功能](collector/90b30a59a13f8100785328229e12c2f4.pdf)
- [Dragonfly 是一種針對現代應用程序負荷需求而構建的內存資料庫](collector/afecd65684d2f2a9566d8d83211a72e9.pdf)

### 安全工具

- [滲透測試報告一鍵生成工具](collector/1159c05117645b15e71f1e88c68fd704.pdf)
- [sqlmap - Automatic SQL injection and database takeover tool](collector/2001810f78059400d786baaaa6efa019.pdf)
- [IPQuality - A script for IP quality detection](collector/a4bece0fd22b660823f13109f8c9c56d.pdf)

### 系統調整管理工具

- [Tune - 系統調整](collector/83d996e5abc2f5d910e35c6f73dfa4f8.pdf)
- [sh - Linux 管理腳本](collector/da9ec6ae216546915b14e556228aacf6.pdf)

### 數據管理

- [DBdoctor 產品體驗報告](collector/c21523ba09f0a9369ac170ed350c6716.pdf)

### 平台管理

- [NineData 是集成了資料庫 DevOps、數據複製、數據備份、數據對比多個模塊的雲服務](collector/578cf5fdbe13139280cfb700f3ff31ee.pdf)
- [sqle - 一个支持多种不同类型数据库，覆盖事前控制、事后监督、标准发布场景，帮助您建立质量规范的 SQL 全生命周期质量管理平台](collector/bafa55700417ec6e1448c610ccf633dd.pdf)
- [Yearning - A most popular SQL audit platform for MySQL](collector/660aeb24aa4b3f8caac70aa7af0129c0.pdf)

### 開發資源

- [GitHub Actions 入坑指南](collector/d13e12a68a7744bac4a4c20663d079a4.pdf)
- [GitHub Action 是什麼？能幹什麼？怎麼做到的？如何開發一個 action](collector/e41eacaaad9129ff0d437bf1ff5abdbe.pdf)
- [通過 GitHub Action 自動發布博客文章](collector/2cc68248d145f410fb0e967bb6a0f880.pdf)
- [部署更輕鬆了，GitHub Action 自動化部署 Hexo：代碼推送，雲伺服器自動部署](collector/77c9c1d6afbff80e7276eb15cce12e49.pdf)
