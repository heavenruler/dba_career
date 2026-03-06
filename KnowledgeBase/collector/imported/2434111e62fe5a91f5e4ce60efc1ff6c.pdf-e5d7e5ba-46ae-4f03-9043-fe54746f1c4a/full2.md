# redis 压力测试工具 — redis-benchmark

redis 做压测可以用自带的 redis-benchmark 工具，使用简单。

目录
- 只运行一些测试用例的子集 -t
- 选择测试键的范围大小 -r
- 使用 pipelining -P
- 陷阱和错误的认识
- 影响 Redis 性能的因素
- 其他需要注意的点
- 不同云主机和物理机器上的基准测试结果
- 更多使用 pipeline 的测试
- 高性能硬件下面的基准测试

示例说明：压测需要一段时间，因为它会依次压测多个命令（如 get、set、incr、lpush 等），如果只需压测某个命令，比如 get，可以加参数 -t。

示例：只测 GET
```
redis-benchmark -h 127.0.0.1 -p 6086 -c 50 -n 10000 -t get
```
示例输出：
```
====== GET ======
10000 requests completed in 0.16 seconds
50 parallel clients
3 bytes payload
keep alive: 1
99.53% <= 1 milliseconds
100.00% <= 1 milliseconds
62893.08 requests per second
```
上面表示执行了 10000 次 GET 操作，在 0.16 秒完成，每个请求数据量 3 字节，99.53% 的命令执行时间小于 1 毫秒，Redis 每秒可以处理 62893.08 次 GET 请求。

示例：只测 SET
```
redis-benchmark -h 127.0.0.1 -p 6086 -c 50 -n 10000 -t set
```
示例输出：
```
====== SET ======
10000 requests completed in 0.18 seconds
50 parallel clients
3 bytes payload
keep alive: 1
87.76% <= 1 milliseconds
99.47% <= 2 milliseconds
99.51% <= 7 milliseconds
99.74% <= 8 milliseconds
100.00% <= 8 milliseconds
56179.77 requests per second
```

如果只想看最终的 requests per second 信息，可以加上参数 -q（quiet 模式）：
```
redis-benchmark -h 127.0.0.1 -p 6379 -c 50 -n 10000 -q
```
示例输出（简洁模式）：
```
PING_INLINE: 63291.14 requests per second
PING_BULK: 62500.00 requests per second
SET: 49261.09 requests per second
GET: 47619.05 requests per second
INCR: 42194.09 requests per second
LPUSH: 61349.69 requests per second
RPUSH: 56818.18 requests per second
LPOP: 47619.05 requests per second
RPOP: 45045.04 requests per second
SADD: 46296.30 requests per second
SPOP: 59523.81 requests per second
LPUSH (needed to benchmark LRANGE): 56818.18 requests per second
LRANGE_100 (first 100 elements): 32362.46 requests per second
LRANGE_300 (first 300 elements): 13315.58 requests per second
LRANGE_500 (first 450 elements): 10438.41 requests per second
LRANGE_600 (first 600 elements): 8591.07 requests per second
MSET (10 keys): 55248.62 requests per second
```

常见测试命令示例
- `redis-benchmark -h 192.168.1.201 -p 6379 -c 100 -n 100000`  
  100 个并发连接，100000 个请求，检测 host 为 192.168.1.201 端口 6379 的 Redis 性能。
- `redis-benchmark -h 192.168.1.201 -p 6379 -q -d 100`  
  测试读写 100 字节数据包的性能（-d 指定数据大小）。
- `redis-benchmark -t set,lpush -n 100000 -q`  
  只测试 SET 和 LPUSH 操作的性能。
- `redis-benchmark -n 100000 -q script load "redis.call('set','foo','bar')"`  
  只测试 script load 的性能。

只运行一些测试用例的子集 -t
- 使用 `-t` 参数可以选择需要运行的测试用例，例如：
  ```
  redis-benchmark -t set,lpush -n 100000 -q
  ```
  只运行 SET 和 LPUSH 命令，并以安静模式输出。

选择测试键的范围大小 -r
- 默认情况下，基准测试使用单一 key。使用 `-r` 可以指定随机 key 范围来模拟更接近真实的缓存不命中情况。
- 示例：在一个空的 Redis 上连续 SET 100 万次，随机 key 范围为 100000：
  ```
  redis-cli flushall
  redis-benchmark -t set -r 100000 -n 1000000
  ```
- `-r` 会在 key、counter 键上加一个后缀（默认 12 位后缀），例如 `-r 10000` 代表只对后四位做随机处理（`-r` 并不是随机数的个数）。
- 示例：
  ```
  redis-benchmark -c 100 -n 20000 -r 10000
  ```
  操作后可通过 `DBSIZE` 或 `SCAN` 查看实际插入的 key 数量。

使用 pipelining -P
- 默认情况下，每个客户端在一个请求完成后才发送下一个请求。Redis 支持 pipelining，可一次性发送多条命令，从而提高 TPS。
- 使用 `-P` 指定 pipeline 的命令数，例如：
  ```
  redis-benchmark -n 1000000 -t set,get -P 16 -q
  ```
  示例输出：
  ```
  SET : 403063.28 requests per second
  GET : 508388.41 requests per second
  ```
- 选项说明：
  - `-P <num>`：每个请求 pipeline 的命令数（默认为 1）。
  - `-k <boolean>`：客户端是否使用 keepalive，1 为使用，0 为不使用，默认 1。

陷阱和错误的认识
- 基准测试的黄金准则是保持一致的标准：用相同的工作量和参数对不同版本或不同工具做对比。
- Redis 是服务器，所有命令包含网络或 IPC 消耗，因此直接与嵌入式或无返回确认的存储系统（如某些配置的 MongoDB）比较意义有限。
- 简单的循环单连接测试更多是在测试网络/IPC 延迟，要真正测试 Redis 吞吐需使用多个连接或 pipelining、并发客户端。
- Redis 是内存数据库，若要与持久化数据库比较，应考虑 RDB/AOF 和 fsync 策略的影响。
- Redis 是单线程的：与多线程数据库直接对比时需谨慎；若想利用多核，可运行多个 Redis 实例。
- redis-benchmark 并不总给出在真实生产中可达到的最大吞吐，使用 pipelining 和更快的客户端（如 hiredis）通常能得到更高吞吐。
- 客户端而非服务器常常成为瓶颈；在高性能测试中可能需优化或多实例化客户端以获得真实的最大吞吐。

影响 Redis 性能的因素
- 网络带宽与延迟通常是主要瓶颈。测试前建议用 ping 检查延迟，并根据数据包大小和目标吞吐估算所需带宽（例如 4 KB 的字符串、100000 q/s 大约需要 3.2 Gbits/s）。
- CPU：由于 Redis 单线程模型，倾向于单核高主频 CPU。不同 CPU 架构（Intel/AMD）和代次会有显著差异。
- 对大对象（>10 KB）时，内存速度和带宽变得重要。
- 虚拟化会带来额外开销，建议在物理机上测试以获得更真实的延迟指标。
- 在同机测试时，Unix domain socket 往往比 TCP loopback 快（Linux 上可快 ~50%），但在大量使用 pipelining 时差异会减小。
- 在多核服务器上，NUMA 配置与处理器绑定会影响性能。可用 taskset 或 numactl 固定进程到指定 CPU 以获得更稳定的结果。
- 客户端连接数会影响吞吐：在高配置机器上，更多连接并不总是线性增加吞吐，测试中可出现 30000 连接的吞吐只有 100 连接的一半的情况。
- NIC 调优（绑定 Rx/Tx 队列到 CPU、开启 RPS、使用 Jumbo frames）可以在网络成为瓶颈时提升性能。
- 内存分配器（libc malloc、jemalloc、tcmalloc）在不同场景下表现不同。INFO 可查看实际使用的分配器。

其他需要注意的点
- 目标是获得可重现结果：尽量在隔离硬件上测试，避免其他进程影响。
- 固定 CPU 频率策略以减少 CPU 动态调整带来的波动。
- 配置足够内存，避免使用 swap。注意 32 位和 64 位 Redis 在内存限制上的差异。
- 如果测试包含 RDB 或 AOF，请避免同时有其他 I/O 操作；不要把持久化文件放在依赖网络的存储上。
- 将 Redis 日志级别设置为 warning 或 notice，避免日志写入远程文件系统。
- 避免使用会严重影响性能的诊断工具（如 MONITOR）；使用 INFO 查看状态通常是安全的。

不同云主机和物理机器上的基准测试结果
（这些测试模拟了 50 个客户端和 2,000,000 请求，使用 Redis 2.6.14，loopback 网络，key 范围 1,000,000，同时测试了有 pipelining 和没有 pipelining 的情况，P=16 表示使用 16 条命令 pipelining。）

示例：Intel Xeon E5520（with pipelining）
```
redis-benchmark -r 1000000 -n 2000000 -t get,set,lpush,lpop -P 16 -q
SET : 552028.75 requests per second
GET : 707463.75 requests per second
LPUSH: 767459.75 requests per second
LPOP: 770119.38 requests per second
```

同机（without pipelining）
```
redis-benchmark -r 1000000 -n 2000000 -t get,set,lpush,lpop -q
SET : 122556.53 requests per second
GET : 123601.76 requests per second
LPUSH: 136752.14 requests per second
LPOP: 132424.03 requests per second
```

Linode 2048（with pipelining）
```
redis-benchmark -r 1000000 -n 2000000 -t get,set,lpush,lpop -q -P 16
SET : 195503.42 requests per second
GET : 250187.64 requests per second
LPUSH: 230547.55 requests per second
LPOP: 250815.16 requests per second
```

Linode 2048（without pipelining）
```
redis-benchmark -r 1000000 -n 2000000 -t get,set,lpush,lpop -q
SET : 35001.75 requests per second
GET : 37481.26 requests per second
LPUSH: 36968.58 requests per second
LPOP: 35186.49 requests per second
```

更多使用 pipeline 的测试
```
redis-benchmark -n 100000
```
示例输出片段：
```
====== SET ======
100007 requests completed in 0.88 seconds
50 parallel clients
3 bytes payload
keep alive: 1
58.50% <= 0 milliseconds
99.17% <= 1 milliseconds
```
注意包大小从 256 到 1024 或 4096 bytes 不会显著改变结果量级（但到 1024 bytes 后，GET 操作会变慢）。50 到 256 个客户端测试结果通常相近，客户端太少会导致总吞吐达不到最大值。

不同机器的示例（简洁输出）：
```
# Intel T5500 1.66 GHz (Linux 2.6)
redis-benchmark -q -n 100000
SET : 53684.38 requests per second
GET : 45497.73 requests per second
INCR: 39370.47 requests per second
LPUSH: 34803.41 requests per second
LPOP: 37367.20 requests per second
```
```
# Xeon L5420 2.5 GHz (64-bit)
redis-benchmark -q -n 100000
PING: 111731.84 requests per second
SET : 108114.59 requests per second
GET : 98717.67 requests per second
INCR: 95241.91 requests per second
LPUSH: 104712.05 requests per second
LPOP: 93722.59 requests per second
```

高性能硬件下面的基准测试
Redis 2.4.2，默认连接数，数据包大小 256 bytes，Linux SLES10 SP3，CPU Intel X5670 @ 2.93 GHz，固定 CPU 并使用不同内核。

使用 Unix domain socket：
```
numactl -C 6 redis-benchmark -q -n 100000 -s /tmp/redis.sock -d 256
PING (inline): 200803.22 requests per second
PING: 200803.22 requests per second
MSET (10 keys): 78064.01 requests per second
SET : 198412.69 requests per second
GET : 198019.80 requests per second
INCR: 200400.80 requests per second
LPUSH: 200000.00 requests per second
LPOP: 198019.80 requests per second
SADD: 203665.98 requests per second
```

使用 TCP loopback：
```
numactl -C 6 redis-benchmark -q -n 100000 -d 256
PING (inline): 145137.88 requests per second
PING: 144717.80 requests per second
MSET (10 keys): 65487.89 requests per second
SET : 142653.36 requests per second
GET : 142450.14 requests per second
INCR: 143061.52 requests per second
LPUSH: 144092.22 requests per second
LPOP: 142247.52 requests per second
SADD: 144717.80 requests per second
```

参考
- Redis 官方关于 benchmarks 的说明与示例（可在 Redis 官方文档中查阅）。