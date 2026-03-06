首页 / 运维实践｜MySQL命令之perror
2
运维实践｜MySQL命令之perror
原创 Aion 2024-02-26 299
1
六月暴雪飞梨花
今天在服务器上面出现了下面的错误，看了一眼，感觉很熟悉，我记得在我安装MySQL时也出现过这个问 关注
题。
37 77 15K+
Can't create/write to file '/tmp/MYIo9T2Q' (OS errno 13 - Permission denied); nested exce 文章 粉丝 浏览量
ption is java.sql.SQLException: Can't create/write to file '/tmp/MYIo9T2Q' (OS errno 13 - P
234 获得了 次点赞 ermission denied)
125 内容获得 次评论
解决问题固然重要，但是好奇心驱使我又看向了 系统错误编码 13（OS errno 13） ，很熟悉的一个编码。 62 获得了 次收藏
当时很快就想到了mysql的perror命令。所以，现在回顾下，也想来说说这个命令。
TA的专栏
MySQL
收录 15 篇内容
使用背景 Oracle
收录 8 篇内容
在mysql 的使用过程中，可能会出现各种各样的错误信息。这些error有些是由于操作系统引起的，比如
openGauss 文件或者目录不存在等等，使用perror的作用就是解释这些错误代码的详细含义。从官网我们其实也可以
收录 1 篇内容 查询到一些蛛丝马迹来帮助我们快速了解perror命令。官网介绍如下：
Perror显示MySQL或操作系统误差代码的错误消息
热门文章 官网地址： https://dev.mysql.com/doc/refman/8.0/en/perror.html
动手学习｜PostgreSQL的安装和配置
2024-05-27 2526浏览
学习实践｜内置函数之日期与时间函数
2024-04-29 894浏览
perror位置 「YashanDB个人版体验」安装部署开箱
体验（CentOS Stream 9版本） 如何找到perror小工具的位置，一般情况下，我们会使用 whereis perror或者which perror 来定位。针 2023-11-22 740浏览
对MySQL封装调用的工具，一般在 MySQL_HOME/bin 下就可以找到perror命令。例如我这里：
阿里云瑶池数据库SQL挑战赛（第一题）
2023-06-14 738浏览
$ whereis perror
新闻资讯｜2024年MySQL第一个长期支 perror: /usr/local/bin/perror
持版本8.4发布 $
2024-05-04 666浏览 $ cd /usr/local/bin/
$ ll perror
lrwxr-xr-x 1 501 wheel 33 12 17 2022 perror@ -> ../Cellar/mysql/8.0.31/bin/perror 最新文章
$
$ cd ../Cellar/mysql/8.0.31/bin/ MySQL运维实践｜稀里糊涂的解决了MyS
$ QL子账号过期、密钥问题
$ ll perror 2025-01-21 249浏览
-r-xr-xr-x 1 Aion admin 7327264 12 17 2022 perror*
Oracle运维实践｜当遇到数据类型NUMB
ER
2024-12-30 86浏览
Oracle运维实践｜一次导入数据引发的思
考
2024-12-30 73浏览
帮助命令 CentOS 7.6安装单节点openGauss 6.0.0
(LTS)数据库实践 如果刚开始使用命令，建议使用--help命令查询具体的使用方法，下面是我在MacOS 13.2上执行的帮助 2024-11-19 456浏览
命令。从下面的命令也可以看出来我当前安装的mysql版本为8.0.31 ，使用安装工具为 Homebrew 。
PostgreSQL学习实践｜随机函数和条件

表达式
$ perror --help 2024-11-03 232浏览
perror Ver 8.0.31 for macos13.0 on x86_64 (Homebrew)
Copyright (c) 2000, 2022, Oracle and/or its affiliates.
Oracle is a registered trademark of Oracle Corporation and/or its
affiliates. Other names may be trademarks of their respective
owners.
Print a description for a system error code or a MySQL error code.
If you want to get the error for a negative error code, you should use
-- before the first error code to tell perror that there was no more options.
Usage: perror [OPTIONS] [ERRORCODE [ERRORCODE...]]
-?, --help Displays this help and exits.
-I, --info Synonym for --help.
-s, --silent Only print the error message.
-v, --verbose Print error code and message (default).
(Defaults to on; use --skip-verbose to disable.)
-V, --version Displays version information and exits.
Variables (--variable-name=value)
and boolean options {FALSE|TRUE} Value (after reading options)
--------------------------------- ----------------------------------------
verbose TRUE
$
使用实践
使用格式
perror [options] errorcode...
perror [选项] [错误码]
对于使用格式，perror试图灵活理解其参数，例如，对于ER_WRONG_VALUE_FOR_VAR错误，perror理
解这些参数中的任何一个：1231、001231、MY-1231或MY-001231，或ER_WRONG_VALUE_FOR_VA
R。说到这里，其实这里好像是一个模糊的准确定位，你可以输入上述任何一种来展示错误的详细信息，
以帮助理解当前机器或程序出现的问题。
回到问题
从上面我的错误码可以看出来，这里提示的是错误码 13，后续跟着无权限。我们也可以使用命令来查询下
这个错误码。
$ perror 13
OS error code 13: Permission denied
MySQL error code MY-000013: Can't get stat of '%s' (OS errno %d - %s)
这里有一个很有意思的事情，我在执行命令perror 13时，返回了两行信息。
第一行 ：系统错误码：无权限
第二行 ：MySQL 错误码 MY-000013：无法获取参数格式，系统错误。
从这里也可以看出来，结合前面的问题，可以确定的是，这里是系统错误，而非MySQL的错误码，这里需
要留意一个问题： 如果错误号在MySQL和操作系统错误重叠的范围内，perror会显示两条错误消息 。
注意 ⚠️ ： 使用perror是在单机上使用，如果是在集群中，请使用命令ndb_perror。
解决问题
针对开篇的问题 ，其实也比较简单。查阅下MySQL Can't create/write to file '/tmp/MYIo9T2Q'
中的所有文件目录，找到tmpdir的参数值，修改其权限即可。当然，你也可以指定到具体的参数来查看目
录。修改完成后，记得重新启动下mysql。想要完全解决这个问题建议在mysql的配置文件中增加tmpdir
参数即可（也是需要重启生效）。
mysql> show variables like '%dir%';
复现问题？

在执行完命令之后，为了可靠的解决现在按照如下方式处理。
（1）创建临时目录并赋权
mkdir /data/mysql_tmp
cd /data/
chown mysql:mysql mysql_tmp -R
（2）修改配置文件
在配置文件中增加临时目录的配置，永绝后患。使用vim打开文件后，输入下面的信息
# 临时文件目录
tmpdir=/data/mysql_tmp
（3）重启mysql
至于你使用什么命令重启都可以，我这里是用的是systemctl。
# 重启mysql
systemctl restart msyqld
# 查看msyql状态
systemctl status msyqld
（4）验证目录是否被修改
登录到mysql，然后执行参数验证。
mysql> show variables like '%tmpdir%';
+-----------------------------------------+------------------------------------------------------+
| Variable_name | Value
+-----------------------------------------+------------------------------------------------------+
| tmpdir | /data/mysql_tmp
+-----------------------------------------+------------------------------------------------------+
19 rows in set (0.00 sec)
穷举错误码信息
为了以后更直观的学习，当然你也可以查询资料来获取所有的错误码以及详细信息，这里给出来一个学习
方法，那就是循环遍历获取这些信息。我们约定大约有10000个错误码（当然这些都是尝试出来的）以及
信息，执行命令如下：
$ for i in $(seq 1 10000); do perror $i; done > 10000.txt 2> /dev/null
稍等片刻，你可以泡上一杯咖啡，回来后就可以看这些命令隐藏在10000.txt文本中了。
总结
学以致用，出现问题，解决问题，引申问题，举一反三。在前面几章中讲到了常用的几个工具，mysqlim
port、mysqlhotcopy、mysqlshow等等。最后熟练使用这些工具，将会带来很大便利。
[引用]
1、显示MySQL错误消息信息： https://dev.mysql.com/doc/refman/8.0/en/perror.html
墨力计划 墨力原创作者计划 墨力原创计划
「喜欢这篇文章，您的关注和赞赏是给作者最好的鼓励」

关注作者 赞赏
【版权声明】本文为墨天轮用户原创内容，转载时必须标注文章的来源（墨天轮），文章链接，文章作者等基本信息，否则作者和墨天轮有权追究
责任。如果您发现墨天轮中有涉嫌抄袭或者侵权的内容，欢迎发送邮件至：contact@modb.pro进行举报，并提供相关证据，一经查实，墨天轮将
立刻删除相关内容。
文章被以下合辑收录
MySQL（共15篇） 收藏合辑
分享知识
评论
reddey R
这确实是个好工具
1年前 点赞 评论
相关阅读
数据库之路-第 2 篇【金仓数据库产品体验官】金仓SQL Server 兼容版 T-SQL 测试篇
悟空聊架构 94次阅读 2025-07-24 17:13:15
数据库之路-第5期-超强的运维管理平台，TEM on 腾讯云安装 + TiDB 集群实践
悟空聊架构 88次阅读 2025-07-28 23:47:19
数据库之路-第4期-安装 KingbaseES 遇到的问题
悟空聊架构 84次阅读 2025-07-28 14:16:40

