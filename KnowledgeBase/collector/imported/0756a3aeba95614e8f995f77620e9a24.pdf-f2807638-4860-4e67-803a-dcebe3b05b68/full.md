首页 / TiDB 学习之路从部署开始
5
TiDB 学习之路从部署开始
原创 jiayou 2024-05-10 1286
jiayou
关注
TiDB 学习之路从部署开始
53 23 25K+
文章 粉丝 浏览量 一、TiDB简述
167 获得了 次点赞
TiDB 是 PingCAP 公司自主设计、研发的开源分布式关系型数据库，是一款同时支持在线事务处理与在线
14 内容获得 次评论 分析 处理 (Hybrid Transactional and Analytical Processing, HTAP) 的融合型分布式数据库产品，具备
37 获得了 次收藏 水平扩容或者缩容、金融级高可用、实时 HTAP、云原生的分布式数据库、兼容 MySQL 协议和 MySQL
生态等重要特性。
TA的专栏
目标是为用户提供一站式 OLTP (Online Transactional Processing)、OLAP (Online Analytical Proces
sing)、HTAP 解决方案。 yashandb
收录 2 篇内容
TiDB 适合高可用、强一致要求较高、数据规模较大等各种应用场景。
gbase
TiDB数据库五大核心特性： 收录 2 篇内容
DB2数据库
• 一键水平扩缩容 收录 19 篇内容
得益于 TiDB 存储计算分离的架构的设计，可按需对计算、存储分别进行在线扩容或者缩容，扩容或者缩容过程中
对应用运维人员透明。
• 金融级高可用
热门文章 数据采用多副本存储，数据副本通过 Multi-Raft 协议同步事务日志，多数派写入成功事务才能提交，确保数据强
一致性且少数副本发生故障时不影响数据的可用性。可按需配置副本地理位置、副本数量等策略，满足不同容灾级
别的要求。 深信服一体机设备管理地址
• 实时 HTAP 2023-08-26 3255浏览
提供行存储引擎TiKV、列存储引擎TiFlash 两款存储引擎，TiFlash 通过 Multi-Raft Learner 协议实时从 TiKV
人大金仓 KingBaseES V9 学习之路：集 复制
群部署实战探索 数据，确保行存储引擎 TiKV 和列存储引擎 TiFlash 之间的数据强一致。TiKV、TiFlash 可按需部署在不同的机
2024-06-01 2849浏览 器，解决 HTAP 资源隔离的问题。
• 云原生的分布式数据库 崖山数据库（YashanDB）部署实战体验
专为云而设计的分布式数据库，通过 TiDB Operator 可在公有云、私有云、混合云中实现部署工具化、自动化。 2024-04-26 2120浏览
• 兼容 MySQL 协议和 MySQL 生态
TiDB 备份与恢复：BR 工具的深入应用与 兼容 MySQL 协议、MySQL 常用的功能、MySQL 生态，应用无需或者修改少量代码即可从 MySQL 迁移到TiD
实战解析 B。提供丰富的数据迁移工具帮助应用便捷完成数据迁移。
2024-06-02 1310浏览
vios 安装系统
TiDB数据库的四大核心应用场景 2023-08-26 1180浏览
最新文章 • 金融行业场景
金融行业对数据一致性及高可靠、系统高可用、可扩展性、容灾要求较高。传统的解决方案的资源利用率低，维护
KingbaseES性能优化工具四剑客之KWR 成本高。TiDB 采用多副本 + Multi-Raft 协议的方式将数据调度到不同的机房、机架、机器，确保系统的 RTO <=
使用指南 30s 及 RPO = 0。
2025-01-14 85浏览 • 海量数据及高并发的 OLTP 场景
传统的单机数据库无法满足因数据爆炸性的增长对数据库的容量要求。TiDB 是一种性价比高的解决方案，采用计 KES V9 RWC集群极速部署实战
算、存储分离的架构，可对计算、存储分别进行扩缩容，计算最大支持 512 节点，每个节点最大支持 1000 并发， 2025-01-08 125浏览
集群容量最大支持 PB 级别。
初探MySQL至KingbaseES的迁移之旅 • 实时 HTAP 场景
2024-12-09 279浏览 TiDB 适用于需要实时处理的大规模数据和高并发场景。TiDB 在 4.0 版本中引入列存储引擎 TiFlash，结合行存储
引擎 TiKV 构建真正的 HTAP 数据库，在增加少量存储成本的情况下，可以在同一个系统中做联机交易处理、实时
一次业务系统问题引起的表空间满问题处 数据分析，极大地节省企业的成本。 理总结
• 数据汇聚、二次加工处理的场景 2024-12-05 218浏览
TiDB 适用于将企业分散在各个系统的数据汇聚在同一个系统，并进行二次加工处理生成 T+0 或 T+1 的报表。与H
MySQL8.0密码认证方式修改 adoop 相比，TiDB 要简单得多，业务通过 ETL 工具或者 TiDB 的同步工具将数据同步到 TiDB，在TiDB 中可通
2024-11-27 126浏览 过 SQL 直接生成报表。

目录
二、部署概要
一、TiDB简述
TiDB 目前产品包括商业的企业版、tidb cloud以及开源社区版。 TiDB数据库五大核心特性：
TiDB数据库的四大核心应用场景 TiDB长期支持版本 (Long-Term Support Releases, LTS) 约每六个月发布一次，会引入新功能、改进、
二、部署概要 缺陷修复和安全漏洞修复。目前发布到v7.5.1 LTS。
三、拓扑规划
本文通过搭建本地虚拟化环境模拟离线部署TiDB v7.5.1数据库。 四、环境准备
1、修改主机名和IP 三、拓扑规划
2、禁用swap交换分区
实验环境 3、关闭防火墙
4、配置时间同步
5、禁用 SELinux 实例 个数 虚拟机配置 IP 配置
6、操作系统相关参数调整
7、配置 Irqbalance 服务 2 Core 4 GiB 默认端口 TiDB 1 192.168.126.201 50 GiB 用于存储 全局目录配置 8、numactl工具安装
9、创建tidb用户
10、配置免密码登录 192.168.126.204 2 Core 4 GiB 默认端口 PD 3 192.168.126.205 11、创建tidb用户ssh key 50 GiB 用于存储 全局目录配置 192.168.126.206
12、指定公钥文件
192.168.126.207 2 Core 4 GiB 默认端口 TiKV 3 192.168.126.208 50 GiB 用于存储 全局目录配置 192.168.126.209
2 Core 4 GiB 默认端口 Monitoring & Grafana 1 192.168.126.210 50 GiB 用于存储 全局目录配置
2 Core 4 GiB 中控机 1 192.168.126.110 Ntpserver&&YUM 50 GiB 用于存储
2 Core 4 GiB 默认端口 Tiflash 1 192.168.126.211 50 GiB 用于存储 全局目录配置
四、环境准备
1、修改主机名和IP
举例：
#设置新的主机名
hostnamectl set-hostname tiflashserver1
#查看主机名
hostnamectl status
cat /etc/hosts
2、禁用swap交换分区
官方建议：TiDB 运行需要有足够的内存。如果内存不足，不建议使用 swap 作为内存不足的缓冲，因为
这会降低性能。建议永久关闭系统 swap。
# 查看swap当前的状态
sudo free -h
# 临时禁用swap
sudo swapoff -a
# 查看/etc/fstab (swap分区)
cat /etc/fstab

# 永久禁用swap
sudo sed -ri 's/.*swap.*/#&/' /etc/fstab
# 查看swap当前的状态
free -h && cat /etc/fstab
3、关闭防火墙
# 关闭防火墙
sudo systemctl stop firewalld
# 禁用防火墙
sudo systemctl disable firewalld
# 查看防火墙状态
sudo systemctl status firewalld
4、配置时间同步
(1)检查NTP服务是否开启
# systemctl status chronyd.service
(2)查看chrony服务是否同步
# chrony tracking
(3)修改chrony服务，此处设置主控机（这里假设为192.168.126.110）作为时间同步服务器，先修改主控
机（服务端）设置
# vi /etc/chrony.conf
添加allow 0.0.0.0/0 添加local stratum 10
注释掉上方的server iburst
(4)重启服务
# systemctl restart chronyd.service
(5) 其他所有节点，需同步主控机，各节点操作如下
# vi /etc/chrony.conf
注释server iburst，新增
server 192.168.126.110 iburst
重启
# systemctl restart chronyd.service
检查是否同步
# chronyc sources -v
查看时间同步源状态
#chronyc sourcestats -v
立刻手工同步
#chronyc -a makestep
校验时间服务器
#chronyc tracking
5、禁用 SELinux

# 查看 SELinux 当前执行模式
# Enforcing：表示 SELinux 当前处于强制执行模式。
# Permissive：表示 SELinux 当前处于宽容执行模式。
# Disabled：表示 SELinux 当前处于禁用状态。
getenforce
# 临时禁用 SELinux
sudo setenforce 0
# 查看/etc/selinux/config
cat /etc/selinux/config
# 永久禁用 SELinux
sudo sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config
sudo sed -i 's/^SELINUX=permissive$/SELINUX=disabled/' /etc/selinux/config
# 查看 SELinux 当前的状态
sestatus && getenforce && cat /etc/selinux/config
#重启
#reboot
6、操作系统相关参数调整
修改sshd相关参数（ssh慢）
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
echo UseDNS no>> /etc/ssh/sshd_config
cat /etc/ssh/sshd_config | grep UseDNS
sudo sed -i 's/^#*UseDNS yes$/UseDNS no/' /etc/ssh/sshd_config
sudo sed -i 's/GSSAPIAuthentication yes/#GSSAPIAuthentication yes\nGSSAPIAuthentication no/' /etc/
ssh/sshd_config
cat /etc/ssh/sshd_config | grep GSSAPIAuthentication
sudo systemctl restart sshd
systemctl restart sshd.service
修改sysctl.conf参数
所有节点服务器配置如下文件：
# vim /etc/sysctl.conf
添加以下内容：
fs.file-max = 1000000
net.core.somaxconn = 32768
net.ipv4.tcp_tw_recycle = 0
net.ipv4.tcp_syncookies = 0
vm.overcommit_memory = 1
vm.swappiness = 0
生效
sysctl -p
cat << EOF >>/etc/sysctl.conf
fs.file-max = 1000000
net.core.somaxconn = 32768
net.ipv4.tcp_tw_recycle = 0
net.ipv4.tcp_syncookies = 0
vm.overcommit_memory = 1
vm.swappiness = 0
EOF
修改limits.conf参数
所有节点服务器配置如下文件：
# vim /etc/security/limits.conf
添加如下内容：
tidb soft nofile 1000000

tidb hard nofile 1000000
tidb soft stack 32768
tidb hard stack 32768
cat << EOF >>/etc/security/limits.conf
tidb soft nofile 1000000
tidb hard nofile 1000000
tidb soft stack 32768
tidb hard stack 32768
EOF
关闭透明大页
# cat /sys/kernel/mm/transparent_hugepage/enabled
[always] madvise never
# echo never > /sys/kernel/mm/transparent_hugepage/enabled
# echo never > /sys/kernel/mm/transparent_hugepage/defrag
THP disabled
THP is enabled, please disable it for best performance
vim /etc/rc.d/rc.local
if test -f /sys/kernel/mm/transparent_hugepage/enabled; then
echo never > /sys/kernel/mm/transparent_hugepage/enabled
fi
if test -f /sys/kernel/mm/transparent_hugepage/defrag; then
echo never > /sys/kernel/mm/transparent_hugepage/defrag
fi
增加文件执行权限，命令如下：
chmod +x /etc/rc.d/rc.local
最后重启主机，让所有配置生效。
7、配置 Irqbalance 服务
# Irqbalance 服务可以将各个设备对应的中断号分别绑定到不同的 CPU 上，以防止所有中断请求都落在
同一个 CPU 上而引发性能瓶颈。
# 启动
systemctl start irqbalance
# 设置开机自启动
systemctl enable irqbalance
service irqbalance not found,
service irqbalance not found, should be installed and started
解决方法：
yum -y install irqbalance
systemctl start irqbalance
systemctl enable irqbalance
8、numactl工具安装
numactl not usable
numactl not usable, bash: numactl: command not found
解决方法：
yum -y install numactl.x86_64
9、创建tidb用户
不用root用户，创建tidb用户进行部署，配置ssh互信和sudo免密
#创建用户

# adduser tidb
#设置密码
# passwd tidb
useradd tidb && passwd tidb
10、配置免密码登录
编辑/etc/sudoers文件,文末加入：
tidb ALL=(ALL) NOPASSWD:ALL
如果想要控制某个用户(或某个组用户)只能执行root权限中的一部分命令,
或者允许某些用户使用sudo时不需要输入密码，一般修改/etc/sudoers文件
cat >> /etc/sudoers << "EOF"
tidb ALL=(ALL) NOPASSWD:ALL
EOF
测试tidb用户登录
$ sudo -su root
11、创建tidb用户ssh key
切换用户
# su - tidb
执行命令，一直按回车键就行
$ ssh-keygen -t rsa
12、指定公钥文件
$ ssh-copy-id -i ~/.ssh/id_rsa.pub tidb@192.168.126.204
13、创建root用户ssh key（使用TiDB用户部署跳过）
[root@tidb ~]# ssh-keygen -t rsa
14、指定公钥文件（使用TiDB用户部署跳过）
[root@tidb ~]# ssh-copy-id -i ~/.ssh/id_rsa.pub root@192.168.126.204
15、创建工作目录上传安装包
1.切换到tidb用户，新建以下两个目录
$ mkdir tidb-deploy
$ mkdir tidb-data
2.上传 Tidb server安装包（本次选择v7.5.1社区版）

tidb-community-server-v7.5.1-linux-amd64.tar.gz
tidb-community-toolkit-v7.5.1-linux-amd64.tar.gz
五、使用TiUP部署TiDB集群
1、在线部署
以 tidb 用户为例，后续安装 TiUP 及集群管理操作均通过该用户完成：
执行如下命令安装 TiUP 工具：
curl --proto '=https' --tlsv1.2 -sSf https://tiup-mirrors.pingcap.com/install.sh | sh
按如下步骤设置 TiUP 环境变量：
重新声明全局环境变量：
source .bash_profile
确认 TiUP 工具是否安装：
which tiup
安装 TiUP cluster 组件：
tiup cluster
如果已经安装，则更新 TiUP cluster 组件至最新版本：
tiup update --self && tiup update cluster
预期输出 “Update successfully!” 字样。
验证当前 TiUP cluster 版本信息。执行如下命令查看 TiUP cluster 组件版本：
tiup --binary cluster
2、离线部署
1、准备 TiUP 离线组件包
方式一：在 官方下载页面 选择对应版本的 TiDB server 离线镜像包（包含 TiUP 离线组件包）。需要同时
下载 TiDB-community-server 软件包和 TiDB-community-toolkit 软件包。
2、部署离线环境 TiUP 组件
将离线包发送到目标集群的中控机后，执行以下命令安装 TiUP 组件：
tar xzvf tidb-community-server-v7.5.1-linux-amd64.tar.gz && \
sh tidb-community-server-v7.5.1-linux-amd64/local_install.sh && \
source /home/tidb/.bash_profile
local_install.sh 脚本会自动执行 tiup mirror set tidb-community-server-v7.5.1-linux-amd64 命令将
当前镜像地址设置为 tidb-community-server-v7.5.1-linux-amd64。

3、合并离线包
如果是通过 官方下载页面 下载的离线软件包，需要将 TiDB-community-server 软件包和 TiDB-commun
ity-toolkit 软件包合并到离线镜像中。如果是通过 tiup mirror clone 命令手动打包的离线组件包，不需
要执行此步骤。
执行以下命令合并离线组件到 server 目录下。
tar xf tidb-community-toolkit-v7.5.1-linux-amd64.tar.gz
ls -ld tidb-community-server-v7.5.1-linux-amd64 tidb-community-toolkit-v7.5.1-linux-amd64
cd tidb-community-server-v7.5.1-linux-amd64/
cp -rp keys ~/.tiup/
tiup mirror merge ../tidb-community-toolkit-v7.5.1-linux-amd64
若需将镜像切换到其他目录，可以通过手动执行 tiup mirror set <mirror-dir> 进行切换。如果需要切换
到在线环境，可执行 tiup mirror set https://tiup-mirrors.pingcap.com 。
查看镜像地址：
tiup mirror show
4、编辑集群初始化配置文件
请根据不同的集群拓扑，编辑 TiUP 所需的集群初始化配置文件。首先生成集群初始化配置模版，命令如
下：
tiup cluster template > topology.yaml
编辑 TiUP 所需的集群初始化配置文件，命令如下：
vi topology.yaml
提示需要升级 tiup 以及 cluster
根据提示升级
#TiDB Cluster配置如下：

5、检查和修复集群风险
先使用 check 命令来检查集群存在的潜在风险，命令如下：
tiup cluster check ./topology.yaml --user tidb
[tidb@adminnode ~]$ tiup cluster check ./topology.yaml --user tidb
检查结果为Fail的内容，表面存在的风险。进一步运行check --apply 命令，自动修复集群存在的潜在风
险，如果自动无法修复，还需要手工来修复风险。命令如下：
tiup cluster check ./topology.yaml --apply --user tidb
[tidb@adminnode ~]$ tiup cluster check ./topology.yaml --apply --user tidb
6、部署TiDB集群
执行 deploy 命令部署 TiDB 集群，集群名称使用 tidb_cluster ，命令如下：
tiup cluster deploy tidb_cluster v7.5.1 ./topology.yaml --user tidb
[tidb@adminnode ~]$ tiup cluster deploy tidb_cluster v7.5.1 ./topology.yaml --user tidb

输入y
安装成功提示：
Cluster `tidb_cluster` deployed successfully, you can start it with command: `tiup cluster start tidb_c
luster --init`
7、验证集群运行状态
TiDB集群部署完成后，默认是关闭状态，通过查看集群状态可以进行确认，命令如下：
tiup cluster display tidb_cluster

启动TiDB集群
（一）安全启动
安全启动是 TiUP cluster 从 v1.9.0 起引入的一种新的启动方式，采用该方式启动数据库可以提高数据库
安全性。推荐使用安全启动。
安全启动后，TiUP 会自动生成 TiDB root 用户的密码，并在命令行界面返回密码。
注意：
1、使用安全启动方式后，不能通过无密码的 root 用户登录数据库，你需要记录命令行返回的密码进行后
续操作。
2、该自动生成的密码只会返回一次，如果没有记录或者忘记该密码，请参照 忘记 root 密码 修改密码。
安全启动命令如下：
tiup cluster start tidb_cluster –init
启动成功提示：
Started cluster `tidb_cluster` successfully
The root password of TiDB database has been changed.
The new password is: '2t*63b^0PUr9@7uZv+'.
Copy and record it to somewhere safe, it is only displayed once, and will not be stored.
The generated password can NOT be get and shown again.
（二）普通启动
使用普通启动方式后，可通过无密码的 root 用户登录数据库。
启动TiDB集群，命令如下：
tiup cluster start tidb_cluster

通过 TiUP 检查集群状态
tiup cluster display tidb-test
预期结果输出：各节点 Status 状态信息为 Up 说明集群状态正常。
通过 TiDB Dashboard 和 Grafana 检查集群状态
查看 TiDB Dashboard 检查 TiDB 集群状态（登录口令为TiDB数据库root用户和密码，默认是空）
Dashboard URL:
http://ip:2379/dashboard
查看 Grafana 监控 Overview 页面检查 TiDB 集群状态（默认用户名密码：admin/admin）初次登录需
要修改密码
Grafana URL:
http://ip:3000
8、客户端连接测试
选择支持MySQL协议的客户端连接测试如下图配置：

六、使用TiUP卸载TiDB集群
1、查看tidb集群名称
tiup cluster list
2、停止tidb集群
tiup cluster stop tidb_cluster

3、清理数据
tiup cluster clean tidb_cluster --all
4、卸载TiDB集群
tiup cluster destroy tidb_cluster
Destroyed cluster `tidb_cluster` successfully
#查看端口占用情况
ss -ntl
七、使用TiUP扩容
八、使用TiUP缩容
九、使用TiUP升级TiDB集群
未完待续。。。
tidb,ptcp,tiup 墨力计划
最后修改时间：2024-05-27 19:29:05

「喜欢这篇文章，您的关注和赞赏是给作者最好的鼓励」
关注作者 赞赏
【版权声明】本文为墨天轮用户原创内容，转载时必须标注文章的来源（墨天轮），文章链接，文章作者等基本信息，否则作者和墨天轮有权追究
责任。如果您发现墨天轮中有涉嫌抄袭或者侵权的内容，欢迎发送邮件至：contact@modb.pro进行举报，并提供相关证据，一经查实，墨天轮将
立刻删除相关内容。
文章被以下合辑收录
TIDB（共5篇） 收藏合辑
tidb数据库
评论
相关阅读
【大盘点】2024年国产数据库行业有哪些大事发生？
墨天轮编辑部 523次阅读 2025-01-20 12:30:33
黄东旭：2025 数据库技术展望
PingCAP 191次阅读 2025-01-13 09:20:18
【TiDB 社区荣誉】2024 年最后一批 MOA & MVA 揭晓！共有 20 位技术布道师当选！
PingCAP 96次阅读 2025-01-06 09:54:26
PingCAP 连续两年入选 Gartner 云数据库管理系统魔力象限“荣誉提及”
通讯员 92次阅读 2024-12-31 10:37:40
2024 TiDB 社区年度总结报告新鲜出炉！又携手共进了一年，2025年，一起迎接变化，挑战变化！
PingCAP 88次阅读 2025-01-13 09:20:19
TiDB 8.5 LTS 发版——支持无限扩展，开启 AI 就绪新时代
PingCAP 56次阅读 2024-12-28 10:03:21
2025 数据库技术展望
通讯员 32次阅读 2025-01-07 19:11:47
用户的角度看 2024TiDB这一年的变化
帅萌的杂谈铺 25次阅读 2025-01-02 09:34:28
唐刘：TiDB 的 2024 - Cloud、SaaS 与 AI
PingCAP 24次阅读 2025-01-09 09:59:56
2024 TiDB 社区年度总结报告新鲜出炉！又携手共进了一年，2025年，一起迎接变化，挑战变化！
青年数据库学习互助会 23次阅读 2025-01-13 09:34:28

