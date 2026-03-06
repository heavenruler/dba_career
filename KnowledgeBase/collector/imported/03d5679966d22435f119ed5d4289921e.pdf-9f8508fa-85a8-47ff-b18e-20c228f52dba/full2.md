# 图解 MySQL 第二篇 | KILL 的工作原理

作者：Yunus Uyanik，Percona 工程师、DBA。  
原文：https://www.percona.com/blog/mysql-with-diagrams-part-two-how-kill-works/（January 7, 2025）  
翻译：爱可生开源社区。本文约 500 字，预计阅读需要 2 分钟。

这是我的图解系列的第二篇。我们将探讨 MySQL 如何使用 KILL 命令处理线程终止，并通过图表和示例演示来帮助理解。

很多人自以为了解这个主题，但实际上并非如此，或者理解有误。KILL 操作并非由运行 KILL 命令的线程处理，而是由被另一个线程终止的线程本身处理。这有点令人困惑，所以用图表来说明比较好。

该图说明了两个线程之间的交互：

- 线程 ID 10：表示正在主动执行查询的工作线程。该线程进入循环，分块处理查询。对于 ORDER BY、GROUP BY 或 ALTER TABLE 等操作，它会读取行块，处理这些行，并提交这些行。处理完每个行块后，它会检查 thd_killed() 标志，以确定是继续执行还是终止。
- 线程 ID 12：该线程发出 KILL 10 命令以终止线程 ID 10。线程 12 使用函数 thd_set_kill_status() 设置线程 10 的终止标志。

Kill 标志行为  
如果终止标志未设置（thd_killed() = 0），线程 10 将继续处理。如果终止标志已设置（thd_killed() = 1），则查询执行将中止，临时表将被丢弃，所有活动事务都将回滚。

MySQL 函数：is_killed()  
函数 is_killed() 检查线程是否应该终止：

```cpp
bool Sql_data_context::is_killed() const {
    const auto kill = thd_killed(get_thd());
    DBUG_LOG("debug", "is_killed:" << kill );
    if (0 == kill) return false;
    return ER_QUERY_INTERRUPTED != kill;
}
```

如果 kill == 0，线程继续运行。如果 kill != 0，则线程被中断，停止进一步执行。

结论  
通过理解 KILL 命令以及 MySQL 如何管理线程生命周期，您可以判断或理解为什么终止线程比预期花费更长时间。与往常一样，请仔细检查您的查询，并避免在生产环境中不加区分地终止线程，因为这可能会中断关键操作。安全总比后悔好。

本文关键字：#MySQL #线程管理 #翻译

《技术译文系列》  
（系列文章：图解 MySQL 第一篇 | 复制架构；图解 MySQL 第三篇 | 写入进程的一生）