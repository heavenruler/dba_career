# 别再乱用 dd 和 fio 了！一篇文章彻底讲清底层原理，从性能测试小白变专家

作者：小皓（来源：小皓DBA学习之路）

## 前言

在做数据库、存储或者性能调优时，dd 和 fio 基本是两个绕不开的工具：

- dd：最原始的块拷贝工具，经常被拿来做顺序读写的粗测。
- fio：专业的 I/O 性能测试工具，能模拟各种复杂业务场景，比如数据库 OLTP 的 4K/8K 随机读写。

很多人只会照着命令敲，但并不清楚底层到底在干什么：这些命令测出来的 MB/s、IOPS、延迟到底意味着什么？哪些是真实磁盘性能，哪些其实是内存/缓存的幻觉？

---

## 一、dd

### 1. dd 底层在干什么？

从操作系统视角看，dd 本质就是一个不断调用 read()/write() 的小程序，伪代码如下：

```c
while (...) {
    read(ifd, buf, bs);   // 从输入 ifd 读 bs 字节
    write(ofd, buf, bs);  // 往输出 ofd 写 bs 字节
}
```

对应到命令行参数：

- if=：input file descriptor（输入），比如 /dev/zero、某个文件、某个块设备
- of=：output file descriptor（输出），比如普通文件、块设备 /dev/sdX
- bs=：每次 read/write 的块大小（block size，比如 4K / 1M）
- count=：总共循环几次（读多少块）

因此，在底层层面上：

- 每一次 I/O 操作，都对应一次 read + 一次 write 系统调用
- bs 越小：系统调用次数越多，用户态/内核态切换越频繁，CPU 开销大
- bs 越大：系统调用次数少，单次 I/O 数据多，吞吐量更容易起来

举个对比：写 10 GiB 数据时

- bs=4K：需要 10 GiB / 4 KiB ≈ 2,621,440 次系统调用
- bs=1M：需要 10 GiB / 1 MiB = 10,240 次系统调用

所以为了减少系统调用、充分发挥存储设备带宽，dd 测顺序吞吐时通常会使用 bs=1M 或更大，而不是 4K。

应用程序（如 fio、数据库）运行在用户态（user space）。真正操作磁盘、网络等硬件必须通过操作系统内核，即进入内核态（kernel space）。从用户态切换到内核态需要通过系统调用（system call），比如 read()、write()、pwrite() 等。每次系统调用都要经历上下文切换，因此系统调用次数对性能有明显影响。

### 2. dd 与页缓存（Page Cache）

很多人认为 dd 跑起来看到的 “xxx MB/s” 就是磁盘性能，实际上不然。

默认情况：走 Page Cache  
如果没有加 oflag=direct / iflag=direct，默认流程是：

- read()：内核先查页缓存（Page Cache），如果命中直接返回；如果没命中，从磁盘读数据到缓存，再返回给用户态。
- write()：写入的数据先落到页缓存，用户态的 write() 返回后，写盘动作由内核异步刷新（后台刷脏页）。

结果就是：dd 很快返回，看起来“写速度几 GB/s”；实际上只是把数据写入了内存，并不代表真正刷到了磁盘。

使用 O_DIRECT：绕过 Page Cache  
为尽量靠近设备真实性能，通常会加：

- oflag=direct：输出路径使用 O_DIRECT，绕过页缓存
- iflag=direct：输入路径使用 O_DIRECT
- conv=fdatasync / conv=fsync：写完后强制刷盘再统计时间

使用 O_DIRECT 时数据会尽量直接在用户缓冲区和块设备之间传输；但仍然可能经过存储阵列自己的硬件缓存（这属于硬件层，dd 控制不了）。

### 3. dd 的常用参数与实战命令

常用参数分类：

- I/O 路径：
  - if=：输入源（file / device）
  - of=：输出目标（file / device）
  - bs=：块大小（也可以使用 ibs、obs 分别指定）
  - count=：块数
  - iflag= / oflag=：
    - direct：使用 O_DIRECT，绕过 Page Cache
    - sync / dsync：同步 I/O 模式（带同步语义）
- 同步控制：
  - conv=fdatasync：写完后调用 fdatasync()，同步数据
  - conv=fsync：写完后调用 fsync()，同步数据和元数据
- 输出控制：
  - status=progress：显示实时进度（新版 coreutils 支持）
  - status=none：静默模式，不打印中间信息

场景示例：

顺序写吞吐（尽量绕过 Page Cache）：

```bash
dd if=/dev/zero of=/data/dd_test.bin bs=1M count=10240 oflag=direct status=progress
```

含义：从 /dev/zero 连续读取 10 GiB 数据，以 1M 为块大小写到 /data/dd_test.bin，使用 oflag=direct 尽量绕过 Page Cache。得到的 MB/s 大致可作为顺序写吞吐的参考。

顺序读吞吐（只读文件）：

```bash
dd if=/data/dd_test.bin of=/dev/null bs=1M iflag=direct status=progress
```

使用 /dev/null 丢弃数据，iflag=direct 尽量避免 Page Cache 干扰，得到大致的顺序读带宽。

强制刷盘的写测试（更接近真实写盘时间）：

```bash
dd if=/dev/zero of=/data/dd_test_sync.bin bs=1M count=10240 oflag=direct conv=fdatasync status=progress
```

conv=fdatasync 会在测试结束前调用一次 fdatasync()，确保数据落到存储介质，测试时间会更长但更接近真实写入耗时。

对块设备做只读测试（谨慎）：

```bash
dd if=/dev/mapper/mpatha of=/dev/null bs=1M iflag=direct status=progress
```

只读通常不破坏数据，但如果设备正在被其他业务写入，测试数据会受影响；对正在使用的设备进行写入测试是绝对禁止的。

小结：dd 的定位

- 适合：简单粗略测顺序读写吞吐、验证链路是否通。
- 不适合：随机 IOPS 测试、接近数据库业务的复杂场景、需要详细延迟分布分析的场合。真正要做专业 I/O 压测，应使用 fio。

---

## 二、fio

### 1. fio 的特点与优势

fio 是一个高度可配置的 I/O 压测工具，核心优势：

- 支持多 job、多线程、多进程
- 支持同步 I/O / 异步 I/O（libaio / io_uring 等）
- 支持顺序 / 随机 / 混合读写
- 输出 IOPS、吞吐、延迟均值与分位点（p99 / p99.9）

### 2. fio 的核心结构

- job：一个压测任务单元。每个 job 描述要压的文件/设备（filename）、读写模式（rw）、块大小（bs）、I/O 范围（size/offset）、ioengine、队列深度（iodepth）、并发线程/进程数（numjobs）等。设置 numjobs=N 会为该 job 开 N 个线程/进程并行执行。
- ioengine：I/O 是如何发给内核的。常见：
  - ioengine=sync：同步 I/O，使用 read/write
  - ioengine=libaio：Linux 异步 I/O（AIO），使用 io_submit/io_getevents
  - ioengine=io_uring：Linux 新的高性能异步 I/O 框架
  - ioengine=mmap：使用内存映射
  在 Linux 下做块设备性能压测时，常用 ioengine=libaio。
- iodepth：队列深度（并发 I/O 数量）。以 ioengine=libaio 为例，iodepth 表示该 job 同时在内核排队、尚未完成的 I/O 请求数量上限。例如 iodepth=32 时，fio 会向内核提交多个 I/O 请求，维持队列中大致为 32 个未完成请求。总 I/O 深度 ≈ iodepth × numjobs（粗略）。
  - iodepth 太小：存储“吃不饱”，IOPS 上不去。
  - iodepth 太大：队列堆积，延迟暴涨。
- numjobs：并发 job 数量。numjobs 控制当前 job 要开多少个线程/进程来跑，同样配置下可以更好把资源吃满。

示例：bs=8k，iodepth=64，numjobs=8，大致意味着理论并发 I/O 数 ≈ 64 × 8 = 512（实际因完成/提交动态变化会有波动）。

### 3. 顺序 I/O 与随机 I/O

fio 决定下一次 I/O 地址的方式：

- 顺序模式（rw=read/write/readwrite）：针对每个 job，会维护当前 offset，每次 I/O 在当前 offset 上读/写 bs 大小，然后 offset += bs，即线性向前读写。
- 随机模式（rw=randread/randwrite/randrw）：根据 size/filesize 确定 I/O 地址空间，每次 I/O 从该范围里按随机分布选取一个 offset，因此底层看到的是真正的随机寻址。

这解释了为什么通过组合 rw、rwmixread、bs 等参数可以模拟不同场景：小块随机读（OLTP 热点表）、大块顺序读写（备份、全表扫描）、混合随机读写（典型数据库负载）等。

### 4. 设置 fio 是否走 Page Cache

与 dd 类似：

- direct=1 → fio 在打开设备/文件时使用 O_DIRECT，绕过 Page Cache。

对存储压测通常建议加 direct=1，否则测到的可能是“内存 + 缓存”的能力，而不是真正的 I/O 能力。

---

## 三、fio 的详细实战用法

### 1. 命令行基本模板

```bash
fio --name=<测试名> \
    --filename=<文件或设备> \
    --rw=<模式> \
    --bs=<块大小> \
    --iodepth=<队列深度> \
    --numjobs=<job数量> \
    --ioengine=libaio \
    --direct=1 \
    --runtime=<秒> \
    --time_based \
    --group_reporting
```

常用参数解释：

- --filename=：/dev/mapper/mpathX（压 LUN / 多路径设备）或 /data/file（压文件系统上的文件）
- --rw=：read/write（顺序）或 randread/randwrite（随机），randrw（随机混合，配合 --rwmixread）
- --bs=：如 4k、8k、1M
- --iodepth=：队列深度（常见 32 / 64 / 128）
- --numjobs=：并发 job 数量
- --runtime= + --time_based：按时间运行测试
- --group_reporting：将多个 job 的结果汇总显示

### 2. 典型场景示例

顺序 1M 写吞吐测试：

```bash
fio --name=seq_write_1M \
    --filename=/data/fio_seq_test.bin \
    --rw=write \
    --bs=1M \
    --iodepth=32 \
    --numjobs=4 \
    --ioengine=libaio \
    --direct=1 \
    --runtime=300 \
    --time_based \
    --group_reporting
```

示例输出可能包含：write: IOPS=12.3k, BW=12.0GiB/s ... 适合看顺序写是否能跑满链路、CPU 是否吃紧、存储是否瓶颈。

随机 4K、70% 读 / 30% 写，模拟 OLTP：

```bash
fio --name=rand4k_70r30w \
    --filename=/dev/mapper/mpathX \
    --rw=randrw \
    --rwmixread=70 \
    --bs=4k \
    --iodepth=64 \
    --numjobs=8 \
    --ioengine=libaio \
    --direct=1 \
    --runtime=300 \
    --time_based \
    --group_reporting
```

重点看 IOPS（是否接近阵列随机 IOPS 能力）和 clat（平均 / p99 等分位延迟是否可接受）。

随机 8K 读（贴近数据库 8K 块）：

```bash
fio --name=rand8k_read \
    --filename=/dev/mapper/mpathX \
    --rw=randread \
    --bs=8k \
    --iodepth=64 \
    --numjobs=8 \
    --ioengine=libaio \
    --direct=1 \
    --runtime=300 \
    --time_based \
    --group_reporting
```

### 3. 使用 job 文件

示例 job 文件 oracle_like_8k_rand.fio：

```
[global]
ioengine=libaio
direct=1
time_based=1
runtime=300
group_reporting=1
filename=/dev/mapper/mpathX

[randread_8k]
rw=randread
bs=8k
iodepth=64
numjobs=8

[seqread_1M]
rw=read
bs=1M
iodepth=32
numjobs=4
```

运行：

```bash
fio oracle_like_8k_rand.fio
```

可在同一个 job 文件里追加多个 job 来同时或顺序执行不同测试。

### 4. fio 输出与调优思路

fio 输出包含很多信息，关键关注点：

- 整体指标：IOPS、带宽（BW）。如 read: IOPS=950k, BW=3700MiB/s。看是否接近理论和链路能力（例如 32Gb FC ≈ 3.2 GB/s）。
- 延迟统计：clat（completion latency）平均值、标准差、以及延迟分位（50th、90th、99th、99.9th）。分位延迟更接近真实业务体验。
  - 如果 IOPS 高但 p99 非常高（例如 >10 ms），说明队列太深或存储吃力。

常见调参思路：

- IOPS 不高且 CPU 也不高、HBA 没跑满：尝试增大 iodepth、numjobs。
- IOPS 上来了但延迟不可接受（p99 爆炸）：说明队列太深，逐步减小 iodepth。
- 调整 bs：小 bs（4K / 8K）关注 IOPS；大 bs（128K / 1M）关注带宽。

---

## 四、总结

- dd：
  - 本质是用户态循环调用 read/write 的块拷贝程序；
  - 默认走 Page Cache，必须配合 oflag=direct/iflag=direct + conv=fdatasync 才更接近真实；
  - 适合粗略测顺序读写吞吐、快速验证链路是否通。
- fio：
  - 通过 job / ioengine / iodepth / numjobs 等机制，能模拟复杂 I/O 模式；
  - 支持随机/顺序、读/写/混合、不同块大小、多线程；
  - 输出 IOPS、带宽、延迟分布，更贴近真实业务；
  - 适合评估存储阵列、主机、网络链路在实际业务场景下的表现（例如数据库 OLTP、备份等）。