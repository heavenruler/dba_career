图解 MySQL 第二篇 | KILL 的工作原理
Yunus Uyanik 爱可生开源社区 2025年9月29日 16:30 上海
作者： Yunus Uyanik ，Percona 工程师、DBA。
原文： https://www.percona.com/blog/mysql-with-diagrams-part-two-how-kill-works/ ，January 7, 2025
爱可生开源社区翻译， 本文约 500 字，预计阅读需要 2 分钟。
这是我的图解系列的第二篇。我们将探讨 MySQL 如何使用 KILL 命令处理线程终止，如提供
的图表所示，并提供示例演示以帮助您更好地理解。
爱可生开源社区 赞 分享 推荐 写留言
很多人自以为了解这个主题，但实际上并非如此，或者理解有误。KILL 操作并非由运行 KILL
命令的线程处理，而是由被另一个线程终止的线程本身处理。这有点令人困惑，所以用图表来
说明比较好。
该图说明了两个线程之间的交互：
线程 ID 10 表示正在主动执行查询的工作线程。
线程 ID 12 发出 KILL 10 命令以终止线程 ID 10。
线程 10 ： 该线程进入循环，分块处理查询。对于 ORDER BY 、 GROUP BY 或 ALTER TABLE
等操作 ，它会读取行块，处理这些行，并确认这些行。处理完每个行块后，它会检查
thd_killed() 标志，以确定是继续执行还是终止。

线程 12 ： 该线程发送 KILL 命令， 使用函数 thd_set_kill_status() 设置线程 10 的终止标志.
Kill 标志行为
如果终止标志未设置 ( thd_killed()=0 )，线程 10 将继续处理。如果终止标志已设置 ( thd
_killed()=1 )，则查询执行将中止，临时表将被丢弃，所有活动事务都将回滚。
MySQL 函数：is_killed()
函数 is_killed() 检查线程是否应该终止：
bool Sql_data_context::is_killed() const {
const auto kill = thd_killed(get_thd());
DBUG_LOG("debug", "is_killed:" << kill );
if (0 == kill ) return false ;
return ER_QUERY_INTERRUPTED != kill ;
}
如果 kill == 0 ，线程继续运行。如果为 kill != 0the thread is interrupted, ， 则停止进一步执
行。
结论
通过理解 KILL 命令以及 MySQL 如何管理线程生命周期，您可以判断或理解为什么它比预期
花费的时间更长。与往常一样，请仔细检查您的查询，并避免在生产环境中不加区分地终止线
程，因为这可能会中断关键操作。安全总比后悔好。
本文关键字： #MySQL #线程管理 #翻译
《技术译文系列》
数据库只追求性能是不够的！
没有好的数据，人工智能就毫无用处
MySQL 和 MariaDB 版本管理的历史背景及差异
AI 如何与我的数据库对话？MySQL 和 Gemini

✨ Github：https://github.com/actiontech/sqle
９ᤙ 文档：https://actiontech.github.io/sqle-docs/
９ᤙ 官网：https://opensource.actionsky.com/sqle/
９ᤙ 微信群：请添加小助手加入 ActionOpenSource
９ᤙ 商业支持：https://www.actionsky.com/sqle

翻译 · 目录
上一篇 下一篇
图解 MySQL 第一篇 | 复制架构 图解 MySQL 第三篇 | 写入进程的一生

