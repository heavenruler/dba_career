# 运维实践｜MySQL命令之 perror

作者: Aion

今天在服务器上出现了下面的错误，看了一眼很熟悉，记得在安装 MySQL 时也遇到过类似问题：

Can't create/write to file '/tmp/MYIo9T2Q' (OS errno 13 - Permission denied); nested exception is java.sql.SQLException: Can't create/write to file '/tmp/MYIo9T2Q' (OS errno 13 - Permission denied)

解决问题之外，我又关注到系统错误编码 13（OS errno 13）。于是回顾并介绍一下 mysql 的 perror 命令。

perror 的作用是解释这些错误代码的详细含义。官方说明：Perror 显示 MySQL 或操作系统误差代码的错误消息。官方文档：https://dev.mysql.com/doc/refman/8.0/en/perror.html

## 使用背景

在 MySQL 的使用过程中，可能会出现各种各样的错误信息。有些 error 是由操作系统引起的（例如“文件或者目录不存在”或“权限被拒绝”等），perror 可以帮助解释这些系统错误码或 MySQL 错误码的含义，快速定位问题。

## perror 所在位置

可以使用 whereis 或 which 来定位 perror 小工具的位置，例如：

```bash
$ whereis perror
perror: /usr/local/bin/perror
$ cd /usr/local/bin/
$ ll perror
lrwxr-xr-x 1 501 wheel 33 12 17 2022 perror@ -> ../Cellar/mysql/8.0.31/bin/perror
$ cd ../Cellar/mysql/8.0.31/bin/
$ ll perror
-r-xr-xr-x 1 Aion admin 7327264 12 17 2022 perror*
```

一般在 MySQL 安装目录的 bin 下可以找到 perror。

## 帮助命令

建议使用 `--help` 查看具体用法，例如在 macOS 上的输出可能如下：

```bash
$ perror --help
perror Ver 8.0.31 for macos13.0 on x86_64 (Homebrew)
Copyright (c) 2000, 2022, Oracle and/or its affiliates.

Print a description for a system error code or a MySQL error code.
If you want to get the error for a negative error code, you should use
-- before the first error code to tell perror that there was no more options.
Usage: perror [OPTIONS] [ERRORCODE [ERRORCODE...]]
-?, --help         Displays this help and exits.
-I, --info         Synonym for --help.
-s, --silent       Only print the error message.
-v, --verbose      Print error code and message (default).
-V, --version      Displays version information and exits.
```

## 使用格式

```
perror [options] errorcode...
perror [选项] [错误码]
```

perror 对参数比较灵活。例如对于 ER_WRONG_VALUE_FOR_VAR 错误，perror 可以识别如下任意一种输入：`1231`、`001231`、`MY-1231`、`MY-001231` 或 `ER_WRONG_VALUE_FOR_VAR`。也就是说可以用多种格式来展示同一个错误的详细信息。

## 回到问题

上面错误提示中包含系统错误码 13（Permission denied），可以用 perror 查询：

```bash
$ perror 13
OS error code 13: Permission denied
MySQL error code MY-000013: Can't get stat of '%s' (OS errno %d - %s)
```

可以看到 perror 返回了两行信息：
- 第一行：操作系统错误码：Permission denied
- 第二行：MySQL 错误码 MY-000013：Can't get stat of '%s' (OS errno %d - %s)

这说明当错误号在 MySQL 与操作系统错误号范围重叠时，perror 会显示两条消息（分别对应 OS error code 与 MySQL error code）。注意：perror 是在单机环境下使用；如果是在 NDB 集群环境，请使用 ndb_perror。

## 解决问题（针对 Can't create/write to file '/tmp/...' OS errno 13）

本例中是由于 MySQL 无法在 tmp 目录中创建或写入文件导致的。常见的解决思路是检查 tmpdir 参数所指向的目录及其权限，并修改为 MySQL 可写的目录。步骤如下：

1. 创建临时目录并赋权：

```bash
mkdir /data/mysql_tmp
chown mysql:mysql /data/mysql_tmp -R
chmod 750 /data/mysql_tmp
```

2. 修改 MySQL 配置文件（如 my.cnf），增加 tmpdir 配置，例如：

```
# 临时文件目录
tmpdir=/data/mysql_tmp
```

3. 重启 MySQL（根据系统使用相应命令，这里为 systemd）：

```bash
# 重启 mysqld
systemctl restart mysqld

# 查看 mysqld 状态
systemctl status mysqld
```

4. 验证 tmpdir 是否生效：

登录 MySQL 执行：

```sql
mysql> show variables like '%tmpdir%';
+---------------+-------------------+
| Variable_name | Value             |
+---------------+-------------------+
| tmpdir        | /data/mysql_tmp   |
+---------------+-------------------+
```

完成以上步骤后，MySQL 应能在指定的 tmpdir 下创建临时文件，从而避免 OS errno 13 的错误。

## 穷举错误码信息（批量获取）

如果想一次性获取大量错误码的解释，可以循环遍历（示例遍历 1 到 10000）并保存到文件：

```bash
$ for i in $(seq 1 10000); do perror $i; done > 10000.txt 2> /dev/null
```

等待完成后在 10000.txt 中查看结果。

## 总结

perror 是一个很有用的命令行工具，用来解释操作系统错误码和 MySQL 错误码。当出现权限、文件或目录相关错误时，先用 perror 定位是系统错误还是 MySQL 错误，然后针对性地检查目录权限、tmpdir 配置等。熟练使用 perror 和其他 MySQL 运维工具（如 mysqlimport、mysqlhotcopy、mysqlshow 等）能大大提高排查效率。

参考：
- MySQL: 显示错误消息信息 — https://dev.mysql.com/doc/refman/8.0/en/perror.html