面试官：MySQL 空值字段应该保存 NULL 还是默认值？
朱晋君 君哥聊技术 2025年11月19日 08:24 北京 原创
君哥聊技术
后端架构师，定期分享技术干货，包括后端开发、分布式、中间件、云原生等。同时也会分享职场心得、程序人生。关注我，一起进阶。
237篇原创内容
公众号
大家好，我是君哥。
使用 MySQL 数据库时，对于一个可以为空的字段，如果没有值，应该保存 NULL 还是给一个
默认值呢？多数时候我们不太注意，有时候不赋值，直接保存 NULL， 有时候赋值一个业务指
定的默认值。今天来聊一聊这个话题。
1.行数据存储
MySQL 保存一行数据时，不仅仅会保存数据本身，还会保存数据相关的额外信息。 InnoDB 存
储引擎支持四种行格式 ，MySQL 5.7 版本之后，默认使用 Dynamic 行格式。看一下官网给出
的 4 种格式说明：
紧凑的存 增强的可变 大索引键 表空间类型 行格式 压缩支持 文件格式 储特性 长度列存储 前缀支持 支持
system, file- Antelope o REDUND No No No No per-table, g r Barracud ANT eneral a
system, file- Antelope o COMPAC Yes No No No per-table, g r Barracud T eneral a
君哥聊技术 赞 分享 推荐 写留言
system, file- DYNAMI Yes Yes Yes No per-table, g Barracuda C eneral
COMPRE file-per-tabl Yes Yes Yes Yes Barracuda SSED e, general
DYNAMIC 和 COMPRESSED 这两种格式都是 COMPACT 的改进版，基本结构跟 COMPACT 类
似，我们看一下 COMPACT 这种格式。如下图：
我们创建一张表：
CREATE TABLE `t_user` (
`id` bigint ( 20 ) NOT NULL AUTO_INCREMENT,
`name` varchar ( 16 ) DEFAULT NULL ,
`email` varchar ( 32 ) DEFAULT NULL ,
`address` varchar ( 255 ) DEFAULT NULL ,
PRIMARY KEY ( `id` )
) ENGINE = InnoDB DEFAULT CHARSET =latin1;
插入 2 行数据，

数据行保存格式如下图：
变长字段宽度列表保存 变长字段非空值长度。 从上图可以看到， 变长字段宽度列表 存放的列宽
度顺序和数据表中的列顺序相反，也就是说变长字段宽度列表逆序存放列宽度。
如果表中所有列都是 NOT NULL 并且具有固定长度，则没有变长字段宽度列表这个部
分 。
同样， NULL 值列表 也是逆序保存，当该值是 NULL 时， 用二进制 1 表记，否则就保存二进制
0。
如果表中所有列都是 NOT NULL，就没有 NULL 值列表这个部分。
记录头信息 用 5 个字节保存，主要记录数据的一些信息，比如：
delete-flag： 记录是否删除，我们知道，在 MySQL 中删除一条数据，并不会马上从磁盘上
删除，而是打上删除标记，在空余时间再进行异步清理。
record_type： 记录类型，比如普通记录、非叶子节点记录。
next_record： 指向下一条记录的地址指针。
n_owned： 记录该组数据的条数。
隐藏列 ：
DB_TRX_ID： 修改（插入、更新或删除）这一条数据的事务 id；
DB_ROLL_PTR： 回滚指针，指向修改前的历史版本，用于回滚操作；
DB_ROW_ID： 当表中不定义主键时用作主键来自动生成聚簇索引。
2.NULL 处理

根据上面的分析和实际使用，如果我们把一个字段直接定义成 NOT NULL， 有下面好处：
节省存储空间 ：NULL 值虽然不会占用数据存储空间，但是需要额外 1~2 个字节保
存 NULL 值列表。
减少应用程序 NullPointerException 的可能性；
减少统计问题：比如 count (字段)不会统计 NULL 值。
对索引有好处，索引是不会保存 NULL 值的，定义成 NULL 会使索引效率下降。
比较操作：字段定义成 NULL， 只能使用 is null 和 is not null 进行判断，不能使用比较操作
比如 =、!=、>、<（都会返回 null） 。
范围操作：字段定义成 NULL，使用 in、not in 语句时会返回空结果。
当然，设置为 NULL， 并不是没有好处，比如：
语义清晰‌ ：NULL 表示“无值”或“未知”，这在逻辑上更清晰准确；
灵活性‌ ：NULL 值更容易筛选，比如在 WHERE 子句中使用 is null 进行筛选；
兼容性‌：类似 JOIN 操作，NULL 跟任何值比较都会返回 NULL， 这有助于保持数据的一致
性和完整性。
在实际项目开发中，我们经常会在值是 NULL 的情况下给一个默认值，比如”-“ 、”“、”
N/A“ 等，这一定程度上避免了空指针，但是往往带来一些额外的问题，比如上下游系统因为默
认值的不一致导致业务处理受影响。
在表设计时，我们其实没有必要过多地考虑定义成 NULL 或默认值在存储空间上的影响，更多
的应该考虑系统整体设计规范、保证各子系统在设计上的一致性，这样才能让处理逻辑更加健
壮。
君哥聊技术
后端架构师，定期分享技术干货，包括后端开发、分布式、中间件、云原生等。同时也会分享职场心得、程序人生。关注我，一起进阶。
237篇原创内容
公众号
精品专栏 70 篇，推荐阅读。
又老性能又差，为什么好多公司依然选择 RabbitMQ？
45 个知识点，带你入门消息队列！
引入了 Disruptor 后，系统性能大幅提升！
从 MySQL 迁移到 GoldenDB，上来就踩了一个坑。
面试官：MySQL BETWEEN AND 语句包括边界吗？
面试官：MySQL Redo Log 和 Binlog 有什么区别？分别用在什么场景？
面试官：使用 MySQL 时你遇到过哪些索引失效的场景
面试官：MySQL表中有2千万条数据，B+树层高是多少？
面试官：MySQL JOIN 表太多，你有哪些优化思路？
感谢阅读，如果对你有帮助，请点赞和在看。欢迎加我微信：zhujinjun86。
号内回复 seata ，下载《阿里分布式中间件Seata从入门到精通》
号内回复 beijing ，下载我总结的北京上百家知名科技公司
号内回复 aqs ，下载《40张图精通Java AQS》

分布式数据库 · 目录
上一篇 下一篇
面试官：如果你是架构师，GoldenDB 和 面试官：MySQL 分区表和分表有什么区别？
openGauss 选择哪个？ 分别适合什么场景？

