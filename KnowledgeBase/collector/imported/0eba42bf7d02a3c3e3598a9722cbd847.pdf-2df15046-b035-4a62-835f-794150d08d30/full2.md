# 从MySQL数据库的角度来看系统 page fault（缺页异常）

作者：听见风的声音  
日期：2025-09-25

## 目录
1. 什么是缺页异常  
2. 缺页异常的类型及其与数据库性能的关系  
  2.1 major page fault  
  2.2 InnoDB 缓冲池和 major page fault 的关系  
  2.3 minor page fault  
  2.4 Invalid Page Fault  
3. 结论

## 1 什么是缺页异常
当进程访问它的虚拟地址空间中的页面时，如果这个页面不能获得有效的数据，就会发生缺页异常（page fault）。

## 2 缺页异常的类型及其与数据库性能的关系
下面是一张缺页异常处理示意图（源自网络），以及相关讨论。

### 2.1 major page fault
Major Page Fault 指的是当进程访问一个虚拟内存页面时，该页面不在物理内存中，必须从外部存储设备（如硬盘）加载的情况。因为涉及到磁盘 I/O 操作，Major Page Fault 的代价非常高，常常会导致进程阻塞等待数据加载。

下面是一个缺页异常的例子（MySQL profile 输出）：

```
mysql> select SEQ, STATE, DURATION, BLOCK_OPS_IN, BLOCK_OPS_OUT, PAGE_FAULTS_MAJOR, PAGE_FAULTS_MINOR, SWAPS;
+-----+--------------------------------+----------+--------------+---------------+-------------------+-------------------+-------+
| SEQ | STATE                          | DURATION | BLOCK_OPS_IN | BLOCK_OPS_OUT | PAGE_FAULTS_MAJOR | PAGE_FAULTS_MINOR | SWAPS |
+-----+--------------------------------+----------+--------------+---------------+-------------------+-------------------+-------+
| 2   | starting                       | 0.005561 |            0 |             0 |                 0 |                 0 |     0 |
| 3   | Executing hook on transaction  | 0.000012 |            0 |             0 |                 0 |                 0 |     0 |
| 4   | starting                       | 0.000008 |            0 |             0 |                 0 |                 0 |     0 |
| 5   | checking permissions           | 0.000005 |            0 |             0 |                 0 |                 0 |     0 |
| 6   | Opening tables                 | 0.000032 |            0 |             0 |                 0 |                 0 |     0 |
| 7   | init                           | 0.000005 |            0 |             0 |                 0 |                 0 |     0 |
| 8   | System lock                    | 0.000008 |            0 |             0 |                 0 |                 0 |     0 |
| 9   | optimizing                     | 0.000005 |            0 |             0 |                 0 |                 0 |     0 |
| 10  | statistics                     | 0.000014 |            0 |             0 |                 0 |                 0 |     0 |
| 11  | preparing                      | 0.000012 |            0 |             0 |                 0 |                 0 |     0 |
| 12  | executing                      | 5.828843 |    1425248  |             0 |                 x |                 y |     0 |
| 13  | end                            | 0.005782 |        504  |             0 |                 0 |                 0 |     0 |
| 14  | query end                      | 0.007523 |        632  |             0 |                 0 |                 0 |     0 |
| 15  | waiting for handler commit     | 0.007799 |        888  |             0 |                 0 |                 0 |     0 |
| 16  | closing tables                 | 0.007178 |        576  |             0 |                 0 |                 0 |     0 |
| 17  | freeing items                  | 0.005499 |        240  |             0 |                 0 |                 0 |     0 |
| 18  | cleaning up                    | 0.005113 |        712  |             0 |                 0 |                 0 |     0 |
+-----+--------------------------------+----------+--------------+---------------+-------------------+-------------------+-------+
17 rows in set, 1 warning (0.00 sec)
```

上面的 profile 是语句的第一次执行，需要将数据载入 InnoDB 的缓冲池，语句的执行阶段 BLOCK_OPS_IN 数值很大，这个阶段也发生了 major page fault 和 minor page fault（minor 在后面解释）。这里先看 major page fault。

语句执行阶段发生的 major page fault 也可以从操作系统层面看到，使用 pidstat 可以监控进程的 page fault 指标：

```
Linux 6.11.0-29-generic (myserver) 09/24/2025 _x86_64_ (4 CPU)
02:16:11 PM UID   PID minflt/s majflt/s VSZ     RSS    %MEM Command
02:16:19 PM 110  1136    0.00     0.00   2407056 438236 47.81 mysqld
02:16:20 PM 110  1136   55.00    23.00   2472592 438492 47.84 mysqld
02:16:21 PM 110  1136    0.00     0.00   2472592 438492 47.84 mysqld
02:16:22 PM 110  1136    0.00     0.00   2472592 438492 47.84 mysqld
02:16:23 PM 110  1136    0.00     0.00   2472592 438492 47.84 mysqld
02:16:24 PM 110  1136  249.00     0.00   2472592 439388 47.94 mysqld
02:16:25 PM 110  1136    0.00     0.00   2472592 439388 47.94 mysqld
```

发生 major page fault 往往是服务器物理内存不足的征兆：原来应该在内存中的数据被交换到了磁盘（交换区）。也有可能是 MySQL 的内存参数配置过大（如 InnoDB 缓冲池大小、读缓冲、排序缓冲、tmp_table_size 等），导致系统使用了交换区。

例如查看交换区使用：

```
root@myserver:~# swapon
NAME       TYPE SIZE USED PRIO
/swap.img  file 4G   270.6M -2
```

用 free 也可以查看内存和交换区：

```
root@myserver:~# free -h
              total   used   free   shared  buff/cache  available
Mem:          895Mi   724Mi   90Mi    84Ki     209Mi     170Mi
Swap:         4.0Gi   270Mi   3.7Gi
```

### 2.2 InnoDB 缓冲池和 major page fault 的关系
InnoDB 缓冲池是 MySQL 内部的内存区域，用于缓存数据和索引页。操作系统的 Major Page Fault 发生在虚拟内存管理层面：当进程（这里是 mysqld）访问的内存地址对应的物理页面不在内存中时，由操作系统触发。

当 InnoDB 缓冲池不足时，MySQL 无法在缓冲池中找到所需的数据页，因此需要从磁盘上的表空间文件中读取数据页。这个磁盘读取操作是 MySQL 主动发起的 I/O（通过文件系统调用如 read 完成），并不等同于操作系统层面的 Major Page Fault。

需要区分两种情况：
a) MySQL 从磁盘读取数据到缓冲池：这是 MySQL 发起的 I/O，会在 SQL profile 中体现为 BLOCK_OPS_IN（磁盘读取）等操作。  
b) 操作系统的 Major Page Fault：这是虚拟内存不足导致的，指进程访问的虚拟内存页面被换出到交换区或文件，需要操作系统从磁盘加载。

因此，InnoDB 缓冲池不足可能间接导致更多磁盘 I/O（BLOCK_OPS_IN），但不一定直接导致操作系统的 Major Page Fault。反过来，如果是物理内存不足（系统开始使用 swap），就会看到操作系统层面的 Major Page Fault。

通常：
- 如果 SQL profile 中出现大量 BLOCK_OPS_IN，说明数据库缓冲池不足，需要增大缓冲池或优化数据访问。  
- 如果系统产生大量 majflt（major page fault），说明物理内存不足或 mysqld 的内存使用超过系统可用内存，导致交换发生。

### 2.3 minor page fault
Minor Page Fault（也称 soft page fault）指访问的内存页面在物理内存中，但尚未为当前进程建立虚拟地址到物理页的映射，此时 MMU 需要建立映射即可。minor page fault 的代价很小，速度很快，通常不会显著影响数据库性能。

发生 minor page fault 的两种情况：
1. 要访问的数据不在物理内存中，需要读入（这类属于 major 情况）；  
2. 要访问的数据已经在物理内存和缓冲区中，但尚未与当前进程或线程的虚拟地址空间建立映射（属于 minor 情况）。

可以通过在另一个会话中再次运行相同 SQL 并查看 profile 来验证第二种情况：

```
mysql> show profile PAGE FAULTS for query 1;
+--------------------------------+----------+-------------------+-------------------+
| Status                         | Duration | Page_faults_major | Page_faults_minor |
+--------------------------------+----------+-------------------+-------------------+
| starting                       | 0.000090 |                 0 |                 0 |
| Executing hook on transaction  | 0.000007 |                 0 |                 0 |
| starting                       | 0.000012 |                 0 |                 0 |
| checking permissions           | 0.000008 |                 0 |                 0 |
| Opening tables                 | 0.000043 |                 0 |                 0 |
| init                           | 0.000009 |                 0 |                 0 |
| System lock                    | 0.000012 |                 0 |                 0 |
| optimizing                     | 0.000008 |                 0 |                 0 |
| statistics                     | 0.000023 |                 0 |                 0 |
| preparing                      | 0.000020 |                 0 |                 0 |
| executing                      | 0.151010 |                 0 |                 0 |
| end                            | 0.000014 |                 0 |                 0 |
| query end                      | 0.000005 |                 0 |                 0 |
| waiting for handler commit     | 0.000008 |                 0 |                 0 |
| closing tables                 | 0.000008 |                 0 |                 0 |
| freeing items                  | 0.000040 |                 0 |                 0 |
| cleaning up                    | 0.000005 |                 0 |                 0 |
+--------------------------------+----------+-------------------+-------------------+
17 rows in set, 1 warning (0.00 sec)
```

再次运行语句，profile 通常不会再出现 page fault（因为映射已建立）：

```
mysql> show profile PAGE FAULTS for query 2;
+--------------------------------+----------+-------------------+-------------------+
| Status                         | Duration | Page_faults_major | Page_faults_minor |
+--------------------------------+----------+-------------------+-------------------+
| starting                       | 0.000068 |                 0 |                 0 |
| Executing hook on transaction  | 0.000004 |                 0 |                 0 |
| starting                       | 0.000007 |                 0 |                 0 |
| checking permissions           | 0.000005 |                 0 |                 0 |
| Opening tables                 | 0.000026 |                 0 |                 0 |
| init                           | 0.000005 |                 0 |                 0 |
| System lock                    | 0.000007 |                 0 |                 0 |
| optimizing                     | 0.000004 |                 0 |                 0 |
| statistics                     | 0.000013 |                 0 |                 0 |
| preparing                      | 0.000011 |                 0 |                 0 |
| executing                      | 0.171669 |                 0 |                 0 |
| end                            | 0.000014 |                 0 |                 0 |
| query end                      | 0.000005 |                 0 |                 0 |
| waiting for handler commit     | 0.000008 |                 0 |                 0 |
| closing tables                 | 0.000008 |                 0 |                 0 |
| freeing items                  | 0.000040 |                 0 |                 0 |
| cleaning up                    | 0.000009 |                 0 |                 0 |
+--------------------------------+----------+-------------------+-------------------+
17 rows in set, 1 warning (0.00 sec)
```

总结：minor page fault 主要是内存映射建立的开销，速度快，通常不会成为数据库性能瓶颈。

### 2.4 Invalid Page Fault
Invalid Page Fault（无效缺页错误）是指进程访问了无效或越界的内存地址，例如对空指针解引用。这类错误通常会触发段错误（segmentation fault），导致进程被操作系统终止。发生这类错误通常是程序 BUG 或数据错误造成的。

## 3 结论
- 如果语句执行过程中发生大量 major page fault（系统层面的 majflt），应考虑物理内存不足或 mysqld 内存配置过大，导致系统开始使用交换区。需要检查系统内存使用并调整 MySQL 内存参数或扩充物理内存。  
- 如果 SQL profile 中出现大量 BLOCK_OPS_IN，说明 InnoDB 缓冲池不足，应增大缓冲池或优化查询与索引，减少磁盘读取。  
- minor page fault（soft page fault）通常是正常的内存映射开销，代价小，通常不会显著影响性能。  
- Invalid Page Fault 往往表示程序错误，应修复代码或数据。

---