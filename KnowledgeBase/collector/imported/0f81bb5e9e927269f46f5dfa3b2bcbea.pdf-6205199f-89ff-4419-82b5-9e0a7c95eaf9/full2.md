# 性能运维 — 借助 pstack + strace 排查 SQL 性能问题

作者：沐雨听风  
来源：金仓数据库（原创） 2024-03-05

## 一、pstack 和 strace

pstack 用来跟踪进程栈，在排查进程问题时非常有用。比如发现某个服务一直处于 working 状态（类似假死或死循环），可以连续在一段时间内（例如每秒一次，连续10次）多次执行 pstack。如果发现代码栈总是停在同一个位置，那个位置就需要重点关注，可能就是问题所在。

示例：
```
[kingbase@localhost ~]$ pstack 2050
#0 0x00007f95424d1c53 in __select_nocancel () from /lib64/libc.so.6
#1 0x00000000008cc180 in KesMasterMain ()
#2 0x00000000004a726c in main ()
```
从下往上解读：先执行 main，然后调用 KesMasterMain，然后是 __select_nocancel。如果应用程序长时间等待，可以通过 pstack 判断卡在了哪一步。

但 pstack 只能看到程序执行的函数以及对应的内存地址，并不能显示每步的执行耗时或系统调用信息。这时可以借助 strace。

strace 常用来跟踪进程执行时的系统调用和所接收的信号。在 Linux 中，进程访问硬件资源（例如读取磁盘、接收网络数据）必须从用户态切换到内核态，通过系统调用实现。strace 可以跟踪进程产生的系统调用，包括参数、返回值和执行消耗的时间。

示例命令：
```
strace -o output.txt -T -tt -e trace=all -p 2050
```
参数含义：
- -o 将结果输出到文件
- -e trace=all 跟踪进程的所有系统调用
- -p 指定进程号
- -tt 在每行输出前显示时间（精确到毫秒）
- -T 显示每次系统调用所花费的时间

示例查看：
```
[kingbase@localhost ~]$ tail -f output.txt
19:33:39.107104 select(6, [3 4 5], NULL, NULL, {40, 451375}) = 0 (Timeout)
19:34:19.590769 rt_sigprocmask(SIG_SETMASK, ~[ILL TRAP ABRT BUS FPE SEGV ...])
19:34:19.590982 open("kingbase.pid", O_RDWR) = 10 <0.000043>
19:34:19.591128 read(10, "2050\n/o", 7) = 7 <0.000028>
19:34:19.591225 close(10) = 0 <0.000032>
19:34:19.591318 rt_sigprocmask(SIG_SETMASK, [], NULL, 8) = 0 <0.000050>
19:34:19.591690 select(6, [3 4 5], NULL, NULL, {60, 0}) <detached ...>
```
上述示例中，read、close 等系统调用后的 `<0.000032>` 是执行时间。

## 二、排查耗时的步骤

1. 确认进程号  
   可以通过系统视图确认 SQL 对应的 pid：  
   SELECT * FROM sys_stat_activity

2. 打印进程信息  
   使用 pstack 打印进程栈：  
   pstack <进程号>

3. 查看 strace 信息  
   运行 strace 并输出到文件：  
   strace -o output.txt -T -tt -e trace=all -p <进程号>

4. 查看 output.txt 并分析执行时间

注意：strace 输出会涉及很多内核层的函数名称，必要时可借助搜索引擎确认对应操作的含义。

## 三、慢 SQL 问题排查步骤（示例）

1. 测试 SQL（获取执行计划）
```
EXPLAIN ANALYZE SELECT * FROM "app_family" af2 WHERE NOT EXISTS (SELECT ...)
```
示例（部分）：
```
Hash Anti Join  (cost=78.38..395702.04 rows=4999850 width=33) (actual time=601.025..14615.331)
  Hash Cond: ((af2.family_id)::text = (af.family_id)::text)
  -> Seq Scan on app_family af2  (cost=0.00..332500.00 rows=5000000 width=33)
  -> Hash (cost=76.50..76.50 rows=150 width=4) (actual time=2.136..2.136)
       Buckets: 16384 (originally 1024)  Batches: 1 (originally 1)  Memory
       -> Seq Scan on app_family2 af  (cost=0.00..76.50 rows=150 width=4)
Planning Time: 0.466 ms
Execution Time: 14814.652 ms
```
从执行计划可以看到存在大量 Seq Scan，且实际执行时间较长（约 14.8s）。

2. 查询对应 pid
```
SELECT pid, query FROM sys_stat_activity;
```
示例中发现执行该 SQL 的进程号为 32255（query 字段显示正在执行的 EXPLAIN ANALYZE 语句）。

3. pstack 分析 32255 进程  
多次执行 pstack，如果每次栈都停在相同函数，说明该函数可能是性能瓶颈。示例 pstack 输出：
```
[kingbase@localhost ~]$ pstack 32255
#0 0x0000000000985fbb in hash_search_with_hash_value ()
#1 0x000000000092209a in BufferTableLookup ()
#2 0x00000000009248fc in ReadBufferCommon ()
#3 0x0000000000925383 in ReadBufExtended ()
#4 0x0000000000516382 in HeapGetPage ()
#5 0x0000000000516a0b in HeapGettupPageMode ()
#6 0x0000000000517b3e in HeapGetNextSlot ()
#7 0x00000000006e7761 in SequenceNext ()
#8 0x00000000006e837e in ExecRowScan ()
#9 0x00000000006aaff3 in ExecutorProcNodeInstr ()
#10 0x00000000006d363a in ExecHJoin ()
#11 0x00000000006aaff3 in ExecutorProcNodeInstr ()
#12 0x00000000006a7f38 in StandardExecRun ()
#13 0x00007f95380ea6e5 in KDBExplainExecutorRun () from /opt/Kingbase/.../auto_explain.so
#14 0x00007f9535bd3d75 in kbss_ExecutorRun () from /opt/Kingbase/.../sys_stat_statements.so
#15 0x000000000068ddde in ExplainOnePlan ()
#16 0x000000000068e09f in ExplainOneQueryPlan ()
#17 0x000000000068e6bd in ExplainQuery ()
#18 0x000000000094e4b7 in standard_ProcessUtility ()
#19 0x00007f9537b67813 in SynonymProcUtility () from /opt/Kingbase/.../synonym.so
#20 0x00007f95378ece31 in PlsqlUtilityCommand () from /opt/Kingbase/.../plsql.so
#21 0x00007f95376c33fa in ForceViewProcUtil () from /opt/Kingbase/.../force_view.so
#22 0x00007f95374b636c in flashback_ProcessUtility () from /opt/Kingbase/.../kdb_flashback.so
#23 0x00007f9535bd706b in kbss_ProcessUtility () from /opt/Kingbase/.../sys_stat_statements.so
#24 0x000000000094b14c in PortalRunUtility ()
#25 0x000000000094c202 in FillPortalStore ()
#26 0x000000000094ccdd in PortalRun ()
#27 0x00000000009473d9 in ExecSimpleQuery ()
#28 0x0000000000949c7a in BackendMain ()
#29 0x00000000004a6683 in ForegroundStartup ()
#30 0x00000000008cc21c in KesMasterMain ()
#31 0x00000000004a726c in main ()
```
pstack 显示了 SQL 执行过程中调用的函数，但无法直接给出耗时的步骤。

4. strace 分析  
通过 strace 可以看到进程在何时进行了哪些系统调用以及每个调用耗时。示例分析发现：从 21:36:07 到 21:36:22（约 15s）进程 32255 一直在执行 pread64 操作，涉及文件描述符 48、49、50。pread64 是从指定偏移开始读文件，说明该 SQL 的耗时主要在大量文件读取上。

收集指令：
```
strace -o output.txt -T -tt -e trace=all -p 32255
```
示例输出（节选）：
```
21:36:01.883491 epoll_wait(3, [{EPOLLIN, {u32=23034888, u64=23034888}}], ...)
21:36:07.195191 recvfrom(10, "Q\0\0\0\222EXPLAIN ANALYZE SELECT * ...", 8192, ...)
21:36:07.195553 lseek(50, 0, SEEK_END) = 166756352 <0.000013>
21:36:07.195627 lseek(52, 0, SEEK_END) = 500768768 <0.000010>
21:36:07.195662 lseek(54, 0, SEEK_END) = 113106944 <0.000010>
21:36:07.195693 lseek(45, 0, SEEK_END) = 614400 <0.000010>
21:36:07.195724 lseek(46, 0, SEEK_END) = 393216 <0.000010>
21:36:07.195755 lseek(47, 0, SEEK_END) = 385024 <0.000010>
21:36:07.196088 kill(27091, SIGUSR1) = 0 <0.000024>
21:36:07.196148 pread64(48, "...", ...) = 4096 <0.006xxx>
21:36:07.202769 pread64(48, "...", ...) = 4096 <0.000xxx>
...
21:36:20.227660 pread64(49, "...", ...) = 4096 <0.000xxx>
...
21:36:21.999330 pread64(50, "...", ...) = 4096 <0.000xxx>
...
21:36:22.010357 write(2, "...", ...) = ...
21:36:22.010854 sendto(10, "T\0\0\0#\0\1QUERY PLAN\0...", ...) = ...
```
通过 lsof 查看进程 32255 处理的文件以及对应 fd，可以确认本次 IO 操作涉及的文件：
```
lsof | grep 32255
kingbase 32255 kingbase 48u REG 253,0 1073741824 7672114 /opt/Kingbase/ES/V9/data/base/14385/96798
kingbase 32255 kingbase 49u REG 253,0 1073741824 18717 /opt/Kingbase/ES/V9/data/base/14385/96798.1
kingbase 32255 kingbase 50u REG 253,0 166756352 7642968 /opt/Kingbase/ES/V9/data/base/14385/96798.2
```
结合执行计划可以确认：该 SQL 在执行过程中由于 Seq Scan 导致了大量文件读操作，从而使 SQL 执行耗时过久。

## 四、总结

pstack + strace 结合使用，可以分析出一个 SQL 执行过程中主要耗时的 Linux 系统操作，从而定位性能瓶颈（例如大量文件读取、频繁系统调用等）。但在大多数场景下，执行计划本身就能帮助定位大部分 SQL 性能问题，因此只有在执行计划信息不足以判断瓶颈时，才建议使用 pstack + strace 进行更底层的诊断。

中电科金仓