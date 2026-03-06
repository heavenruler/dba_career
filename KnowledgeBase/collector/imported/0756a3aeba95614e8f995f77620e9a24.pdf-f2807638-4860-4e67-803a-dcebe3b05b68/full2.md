# TiDB 学习之路从部署开始

作者：jiayou  
日期：2024-05-10

## 一、TiDB 简述

TiDB 是 PingCAP 公司自主设计、研发的开源分布式关系型数据库，支持在线事务处理与在线分析处理（Hybrid Transactional and Analytical Processing, HTAP）。TiDB 的目标是为用户提供一站式 OLTP（Online Transactional Processing）、OLAP（Online Analytical Processing）、HTAP 解决方案。TiDB 适合对高可用、强一致要求较高、数据规模较大等各种应用场景。

TiDB 数据库五大核心特性：
- 一键水平扩缩容  
  得益于存储计算分离的架构设计，可按需对计算和存储分别进行在线扩容或缩容，对应用运维人员透明。
- 金融级高可用  
  数据采用多副本存储，副本之间通过 Multi-Raft 协议同步事务日志，多数派写入成功事务才能提交，确保强一致性。可按需配置副本地理位置与数量，满足不同容灾级别。
- 实时 HTAP  
  提供行存储引擎 TiKV 和列存储引擎 TiFlash。TiFlash 通过 Multi-Raft Learner 协议实时从 TiKV 复制数据，确保行存储与列存储之间的数据强一致，支持资源隔离。
- 云原生设计  
  通过 TiDB Operator 可在公有云、私有云与混合云中实现部署工具化与自动化。
- 兼容 MySQL 协议与生态  
  兼容 MySQL 协议与常用功能，应用通常无需或仅需少量改动即可从 MySQL 迁移到 TiDB，同时提供丰富的数据迁移工具。

TiDB 的四大核心应用场景：
- 金融行业场景：对数据一致性、高可靠、系统高可用、可扩展性和容灾要求高，TiDB 支持低 RTO（<=30s）和 RPO = 0 的设计。
- 海量数据与高并发 OLTP 场景：计算存储分离架构，可横向扩展，支持大规模并发与 PB 级数据容量。
- 实时 HTAP 场景：结合 TiKV 和 TiFlash，可以在同一系统中同时进行联机事务处理与实时分析。
- 数据汇聚与二次加工：将企业分散的数据汇聚至 TiDB，通过 ETL 或同步工具实现 T+0/T+1 报表生成。

TiDB 当前产品包括商业企业版、TiDB Cloud 以及开源社区版。TiDB 长期支持版本（LTS）大约每六个月发布一次，目前发布到 v7.5.1 LTS。

---

## 二、部署概要

本文通过在本地虚拟化环境模拟离线部署 TiDB v7.5.1。主要步骤包括拓扑规划、环境准备、使用 TiUP 部署与验证、以及扩缩容和卸载操作示例。

---

## 三、拓扑规划（示例）

实验环境拓扑示例：

- 实例与配置（示例）
  - TiDB: 1 节点，2 Core，4 GiB，IP 192.168.126.201，存储 50 GiB
  - PD: 3 节点，192.168.126.204 / .205 / .206，2 Core，4 GiB，存储 50 GiB
  - TiKV: 3 节点，192.168.126.207 / .208 / .209，2 Core，4 GiB，存储 50 GiB
  - Monitoring & Grafana: 1 节点，192.168.126.210，2 Core，4 GiB，存储 50 GiB
  - 中控机（NTP server & YUM）：1 节点，192.168.126.110，2 Core，4 GiB，存储 50 GiB
  - TiFlash: 1 节点，192.168.126.211，2 Core，4 GiB，存储 50 GiB

请根据实际资源及生产需求调整拓扑与规格。

---

## 四、环境准备

以下步骤在所有参与部署的节点上执行（根据节点角色有所不同）。

### 1. 修改主机名与 /etc/hosts

示例设置主机名：
```bash
# 设置新的主机名
hostnamectl set-hostname tiflashserver1

# 查看主机名
hostnamectl status

# 查看 /etc/hosts
cat /etc/hosts
```

### 2. 禁用 swap

官方建议永久关闭 swap，以避免影响性能。
```bash
# 查看 swap 当前状态
sudo free -h

# 临时禁用 swap
sudo swapoff -a

# 查看 /etc/fstab (swap 分区)
cat /etc/fstab

# 永久禁用 swap
sudo sed -ri 's/.*swap.*/#&/' /etc/fstab

# 验证
free -h && cat /etc/fstab
```

### 3. 关闭防火墙
```bash
# 停止防火墙
sudo systemctl stop firewalld

# 禁用防火墙开机启动
sudo systemctl disable firewalld

# 查看防火墙状态
sudo systemctl status firewalld
```

### 4. 配置时间同步（chrony）

在中控机（假设为 192.168.126.110）作为时间服务器：

在中控机上修改 /etc/chrony.conf：
- 注释掉原有 server iburst
- 添加：
  allow 0.0.0.0/0
  local stratum 10

重启 chrony：
```bash
systemctl restart chronyd.service
```

在其它节点的 /etc/chrony.conf 中添加：
```text
server 192.168.126.110 iburst
```
重启并检查同步状态：
```bash
systemctl restart chronyd.service
chronyc sources -v
chronyc sourcestats -v
chronyc -a makestep      # 立刻手工同步
chronyc tracking
```

### 5. 禁用 SELinux

查看当前状态：
```bash
getenforce
```
临时禁用：
```bash
sudo setenforce 0
```
永久修改 /etc/selinux/config：
```bash
sudo sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config
sudo sed -i 's/^SELINUX=permissive$/SELINUX=disabled/' /etc/selinux/config
```
验证：
```bash
sestatus && getenforce && cat /etc/selinux/config
# 重启（如有需要）
# reboot
```

### 6. 操作系统相关参数调整

- SSH 调优（避免 SSH 登录慢）：
```bash
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
sudo sed -i 's/^#*UseDNS yes$/UseDNS no/' /etc/ssh/sshd_config
sudo sed -i 's/GSSAPIAuthentication yes/#GSSAPIAuthentication yes\nGSSAPIAuthentication no/' /etc/ssh/sshd_config
sudo systemctl restart sshd
```

- 修改 sysctl 参数（在所有节点）：
在 /etc/sysctl.conf 中添加：
```text
fs.file-max = 1000000
net.core.somaxconn = 32768
net.ipv4.tcp_tw_recycle = 0
net.ipv4.tcp_syncookies = 0
vm.overcommit_memory = 1
vm.swappiness = 0
```
使其生效：
```bash
sysctl -p
```

- 修改 limits.conf（在所有节点）：
在 /etc/security/limits.conf 中添加：
```text
tidb soft nofile 1000000
tidb hard nofile 1000000
tidb soft stack 32768
tidb hard stack 32768
```

### 7. 关闭透明大页（THP）

查看当前状态：
```bash
cat /sys/kernel/mm/transparent_hugepage/enabled
# 可能输出：[always] madvise never
```
临时禁用：
```bash
echo never > /sys/kernel/mm/transparent_hugepage/enabled
echo never > /sys/kernel/mm/transparent_hugepage/defrag
```
在 /etc/rc.d/rc.local 中添加：
```bash
if test -f /sys/kernel/mm/transparent_hugepage/enabled; then
  echo never > /sys/kernel/mm/transparent_hugepage/enabled
fi
if test -f /sys/kernel/mm/transparent_hugepage/defrag; then
  echo never > /sys/kernel/mm/transparent_hugepage/defrag
fi
```
赋予执行权限并重启：
```bash
chmod +x /etc/rc.d/rc.local
# reboot
```

### 8. 配置 irqbalance 服务

irqbalance 可以将设备中断分配到不同 CPU 上，避免单个 CPU 成为性能瓶颈。
```bash
# 安装（如未安装）
yum -y install irqbalance

# 启动并设置开机自启
systemctl start irqbalance
systemctl enable irqbalance
```

### 9. 安装 numactl

如果报错 "numactl: command not found"：
```bash
yum -y install numactl.x86_64
```

### 10. 创建 tidb 用户

不建议使用 root 用户部署。创建 tidb 用户并设置密码：
```bash
useradd tidb && passwd tidb
```

### 11. 配置 sudo 免密（tidb 用户）

在 /etc/sudoers 文件末尾添加：
```text
tidb ALL=(ALL) NOPASSWD:ALL
```
可以通过以下命令追加：
```bash
cat >> /etc/sudoers << "EOF"
tidb ALL=(ALL) NOPASSWD:ALL
EOF
```
测试切换为 root：
```bash
sudo -su root
```

### 12. 配置 SSH 免密登录（tidb 用户）

切换为 tidb 用户并生成密钥：
```bash
su - tidb
ssh-keygen -t rsa    # 按回车接受默认
ssh-copy-id -i ~/.ssh/id_rsa.pub tidb@192.168.126.204
```

（如果使用 root 用户部署，则对应生成 root 的 ssh-key 并复制到目标节点）

### 13. 创建工作目录并上传安装包

切换到 tidb 用户，新建目录并上传安装包：
```bash
mkdir ~/tidb-deploy
mkdir ~/tidb-data
```
示例上传的安装包（本次选择 v7.5.1 社区版）：
- tidb-community-server-v7.5.1-linux-amd64.tar.gz
- tidb-community-toolkit-v7.5.1-linux-amd64.tar.gz

---

## 五、使用 TiUP 部署 TiDB 集群

下面以 tidb 用户为例，后续安装 TiUP 及集群管理操作均通过该用户进行。

### 1. 在线部署 TiUP（安装与更新）

安装 TiUP（在线）：
```bash
curl --proto '=https' --tlsv1.2 -sSf https://tiup-mirrors.pingcap.com/install.sh | sh
```
设置环境变量：
```bash
source ~/.bash_profile
```
验证安装：
```bash
which tiup
tiup cluster     # 安装 cluster 组件或查看可用命令
```
更新 TiUP：
```bash
tiup update --self && tiup update cluster
```
查看 TiUP cluster 二进制信息：
```bash
tiup --binary cluster
```

### 2. 离线部署 TiUP

准备离线组件包（将 server 与 toolkit 两个包下载到中控机）并解压安装：
```bash
tar xzvf tidb-community-server-v7.5.1-linux-amd64.tar.gz
sh tidb-community-server-v7.5.1-linux-amd64/local_install.sh
source /home/tidb/.bash_profile
```
local_install.sh 会自动执行 tiup mirror set tidb-community-server-v7.5.1-linux-amd64，将当前镜像地址设置为本地镜像。

如果需要合并 toolkit 包到 server 镜像：
```bash
tar xf tidb-community-toolkit-v7.5.1-linux-amd64.tar.gz
ls -ld tidb-community-server-v7.5.1-linux-amd64 tidb-community-toolkit-v7.5.1-linux-amd64
cd tidb-community-server-v7.5.1-linux-amd64/
cp -rp keys ~/.tiup/
tiup mirror merge ../tidb-community-toolkit-v7.5.1-linux-amd64
```
如需切换镜像目录：
```bash
tiup mirror set <mirror-dir>
# 或切换回在线镜像
tiup mirror set https://tiup-mirrors.pingcap.com
```
查看当前镜像：
```bash
tiup mirror show
```

### 3. 编辑集群初始化配置（topology.yaml）

生成集群初始化配置模板：
```bash
tiup cluster template > topology.yaml
```
编辑 topology.yaml，根据实际拓扑与角色调整配置：
```bash
vi topology.yaml
```

### 4. 检查和修复集群风险

先使用 check 命令检查潜在风险：
```bash
tiup cluster check ./topology.yaml --user tidb
```
对于检查结果为 Fail 的项目，尝试自动修复：
```bash
tiup cluster check ./topology.yaml --apply --user tidb
```
如果自动无法修复，需要根据提示手工修复。

### 5. 部署 TiDB 集群

执行 deploy 命令（以集群名 tidb_cluster 为例）：
```bash
tiup cluster deploy tidb_cluster v7.5.1 ./topology.yaml --user tidb
```
按提示输入 y 确认。部署成功示例提示：
```
Cluster `tidb_cluster` deployed successfully, you can start it with command: `tiup cluster start tidb_cluster --init`
```

### 6. 启动集群

安全启动（推荐，从 TiUP cluster v1.9.0 起支持）：
- 安全启动会自动生成 TiDB root 用户密码并在命令行返回，需保存该密码。
- 注意：密码只会显示一次。

安全启动命令：
```bash
tiup cluster start tidb_cluster --init
```
示例成功输出会包含新 root 密码（仅显示一次）。

普通启动（允许无密码 root 登录）：
```bash
tiup cluster start tidb_cluster
```

### 7. 验证集群运行状态

查看集群状态：
```bash
tiup cluster display tidb_cluster
```
如果各节点的 Status 为 Up，则集群正常。

也可以通过 TiDB Dashboard 与 Grafana 检查：
- TiDB Dashboard（访问 etcd 节点上的端口，一般通过 PD 的 endpoints）
- Grafana（默认 admin/admin，首次登录需修改密码）

检查端口占用：
```bash
ss -ntl
```

### 8. 客户端连接测试

使用任何支持 MySQL 协议的客户端连接 TiDB，使用 TiDB 提供的连接信息（IP、端口、用户、密码）。

---

## 六、使用 TiUP 卸载 TiDB 集群

1. 查看已部署的集群：
```bash
tiup cluster list
```
2. 停止集群：
```bash
tiup cluster stop tidb_cluster
```
3. 清理数据（注意：此操作会清除数据）：
```bash
tiup cluster clean tidb_cluster --all
```
4. 卸载集群：
```bash
tiup cluster destroy tidb_cluster
# 成功示例：Destroyed cluster `tidb_cluster` successfully
```

---

## 七、使用 TiUP 扩容

（示例流程）
1. 修改 topology.yaml，新增需要扩容的实例配置。
2. 执行：
```bash
tiup cluster scale-out tidb_cluster ./topology.yaml --user tidb
```
3. 按提示完成扩容与验证。

## 八、使用 TiUP 缩容

（示例流程）
1. 执行缩容命令，指定需要下线的实例：
```bash
tiup cluster scale-in tidb_cluster --node <component>:<host>:<port> --user tidb
```
2. 清理数据并验证集群状态。

## 九、使用 TiUP 升级 TiDB 集群

（示例流程）
1. 准备目标版本的镜像并更新镜像：
```bash
tiup update cluster
```
2. 执行升级前检查：
```bash
tiup cluster check ./topology.yaml --user tidb
```
3. 执行升级：
```bash
tiup cluster upgrade tidb_cluster v7.x.y --user tidb
```
4. 验证升级结果并回归测试。

---

未完待续...

（本文为部署示例与操作指南，部署到生产环境前请结合官方文档与自身运维规范调整配置与操作。）