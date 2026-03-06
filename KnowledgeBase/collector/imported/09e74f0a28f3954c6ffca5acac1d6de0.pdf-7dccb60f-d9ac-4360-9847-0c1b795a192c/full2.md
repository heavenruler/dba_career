# [MYSQL] 忘记 root 密码时，不需要重启也能强制修改了!

作者：大大刺猬  
日期：2025-02-06

导读  
之前讲过 MySQL 忘记密码时的一些处理方法，前面几种都是需要重启才生效的（包括修改 ibd 文件）。而不需要重启的方法（修改内存，或者 gdb 跳过认证）并没有给出完整实现。有的同学恰好就需要一个不用重启也能强制修改密码的方法，所以本文重点讲讲“修改内存”实现强制修改密码的操作。

原理分析
- 原理很简单：既然验证的密码是在内存中的，那我们找到该密码并直接修改为我们需要的密码即可。
- 其实难点在于如何访问 mysqld 进程的内存。Linux 下进程的内存布局可通过 /proc/PID/maps 查看，实际内存数据可以通过 /proc/PID/mem 读取。我们只需要遍历 maps、找到可读写（rw-p）的内存区域，然后在对应的 mem 偏移中查找需要的数据并修改。

/proc/<pid>/maps 示例解析（以一行为例）：
00400000-00c6f000 r--p 00000000 fd:00 307653646 /soft/mysql_3386/mysqlbase/mysql/bin/mysqld

解释：
- 00400000-00c6f000：内存范围（16 进制）
- r--p：权限（r=read, w=write, x=execute, s=shared, p=private）
- 00000000：offset（相对于对应 fd 的偏移）
- fd:00：设备号
- 307653646：inode
- /soft/.../mysqld：对应的文件路径

只要遍历 maps，就可以知道 mysqld 进程的内存分配情况，然后读取 mem 中对应位置的数据查找需要的数据。

关于密码存储和 flush
- MySQL 的认证并不是直接每次登录都去查询 mysql.user 的文本页；密码验证用的是内存中保存的二进制（hash）值，所以直接修改 mysql.user 的 ibd/frm 文件后还需要 flush privileges 才会生效。flush 会把 mysql.user 的值刷新到内存对应结构中。
- 因此在内存中搜索并修改的是二进制的加密密码（mysql_native_password 的 double-SHA1），而不是 mysql.user 的文本表示。
- 在内存中同一二进制密码可能对应多个用户（如果多个用户设置了相同密码），所以修改内存中的某个密码位置会同时影响所有使用该密码的账号。要彻底持久化，仍建议在数据库内执行 ALTER USER ... IDENTIFIED BY ... 并 FLUSH PRIVILEGES。

在内存中查找关键词（演示用函数）
下面给出一个在内存中查找某个关键词的示例函数（演示原理）：

```python
# 在内存中查找某个关键词
def find_data_in_mem(pid, key):
    keysize = len(key)
    with open(f'/proc/{pid}/maps', 'r') as f:
        maps = f.readlines()
    result = []
    with open(f'/proc/{pid}/mem', 'rb') as f:
        for line in maps:
            addr = line.split()[0]
            _flags = line.split()[1]
            # 只处理可读写私有页面
            if _flags != 'rw-p':
                continue
            start_addr, stop_addr = addr.split('-')
            start_addr = int(start_addr, 16)
            stop_addr = int(stop_addr, 16)
            f.seek(start_addr, 0)
            data = f.read(stop_addr - start_addr)
            offset = 0
            while True:
                offset = data.find(key, offset)
                if offset != -1:
                    result.append([start_addr, stop_addr, offset])
                    offset += keysize
                else:
                    break
    return result
```

演示
- 理论很枯燥，下面是使用脚本的演示（脚本见下方源码部分）。注意：--user 指定 user@host 时，user 和 host 都不需要加引号。
- 查看用户的密码（在内存中查找并显示 mysql_native_password 插件下的二进制密码字符串）：
  - python3 online_modify_mysql_password.py --user u33@%
- 修改用户密码（方法 1）：
  - 该方法只是修改内存中 flush 处的密码，因此如果之后执行了 FLUSH PRIVILEGES，内存会被刷新回 mysql.user 的值，你需要在数据库中使用 ALTER USER 修改并执行 FLUSH，使修改持久化；另外修改会影响所有使用相同二进制密码的用户。
  - python3 online_modify_mysql_password.py --user u33@% --password newpassword_u33
- 修改用户密码（方法 2）：
  - 如果 mysql.user 不在内存中，或者 flush 处的密码和 mysql.user 不一致（例如你在磁盘上直接 update），那么可以手动提供 mysql.user 里面的旧二进制密码（即 flush 中的密码），脚本会直接根据你提供的旧密码位置进行替换。
  - python3 online_modify_mysql_password.py --user u33@% --password newpassword_u33 --old-password <old_password_hex>
- 存在多个 mysqld 进程时：
  - 如果服务器上存在多个 mysqld 进程，需要使用 --pid 指定要操作的实例进程号。
  - python3 online_modify_mysql_password.py --user u33@% --password newpassword_u33 --pid 18721

总结
- 虽然本文提供了不需要重启数据库就能强制修改密码的方法，但还是建议重启数据库（还能释放内存并保证一致性）。本文测试过 MySQL 5.7.38、8.0.28、8.0.41，均可成功。当前脚本仅支持 mysql_native_password 插件的密码。
- 如果使用本脚本修改密码后，未在数据库内做 ALTER 并 FLUSH，那么再次使用脚本时需要加上 --old-password 指定上一次修改前内存中保存的密码二进制值（hex）。

参考
- https://www.kernel.org/doc/html/latest/filesystems/proc.html

源码
下面是演示脚本（在线修改 mysqld 进程的密码工具，仅支持 mysql_native_password）。注意：脚本需要 root 权限才能读取 /proc/<pid>/mem 并写入。

```python
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# writen by ddcw @ https://github.com/ddcw
# 在线修改 mysqld 密码的工具，仅支持 mysql_native_password 插件

import os
import sys
import struct
import hashlib
import binascii
import argparse

def _argparse():
    parser = argparse.ArgumentParser(description='在线修改 mysqld 进程的脚本')
    parser.add_argument('--password', '-p', dest="PASSWORD", help='mysql new password')
    parser.add_argument('--old-password', dest="OLD_PASSWORD", help='last modify password (hex without 0x)')
    parser.add_argument('--pid', dest="PID", help='mysql pid', type=int)
    parser.add_argument('--user', dest="USER", help='mysql account (user@host, e.g. root@localhost)')
    parser.add_argument('--help-brief', action='store_true', help='show examples')
    args = parser.parse_args()
    if args.help_brief:
        print('Example:')
        print(f'  python3 {sys.argv[0]} --user root@localhost')
        print(f'  python3 {sys.argv[0]} --user root@localhost --password 123456')
        print(f'  python3 {sys.argv[0]} --user root@localhost --password 123456 --pid 18721')
        sys.exit(0)
    if args.USER is None:
        print('必须使用 --user 指定用户 (user@host)')
        sys.exit(10)
    return args

def encode_password(new_password):
    # mysql_native_password: SHA1(SHA1(password))
    return hashlib.sha1(hashlib.sha1(new_password.encode()).digest()).digest()

def find_data_in_mem(pid, key):
    keysize = len(key)
    with open(f'/proc/{pid}/maps', 'r') as f:
        maps = f.readlines()
    result = []
    with open(f'/proc/{pid}/mem', 'rb') as f:
        for line in maps:
            parts = line.split()
            if len(parts) < 2:
                continue
            addr = parts[0]
            _flags = parts[1]
            if _flags != 'rw-p':
                continue
            start_addr, stop_addr = addr.split('-')
            start_addr = int(start_addr, 16)
            stop_addr = int(stop_addr, 16)
            try:
                f.seek(start_addr)
                data = f.read(stop_addr - start_addr)
            except (OSError, ValueError):
                continue
            offset = 0
            while True:
                offset = data.find(key, offset)
                if offset != -1:
                    result.append([start_addr, stop_addr, offset])
                    offset += keysize
                else:
                    break
    return result

def set_new_password(old_password_bytes, new_password_bytes, pid):
    maps = find_data_in_mem(pid, old_password_bytes)
    if len(maps) == 0:
        print('可能之前已经修改过了, 可以使用 --old-password 指定上一次的密码 (hex)')
        sys.exit(1)
    with open(f'/proc/{pid}/mem', 'r+b') as f:
        for start, stop, offset in maps:
            # 这里演示时从旧密码位置向前偏移检查一些标识（示例读取 20 字节）
            try:
                f.seek(start + offset - 20)
                data = f.read(20)
            except (OSError, ValueError):
                continue
            # 简单验证：示例中希望后 4 字节为 0（视具体版本可能不同）
            if data[-4:] != b'\x00\x00\x00\x00':
                continue
            f.seek(start + offset)
            f.write(new_password_bytes)
            print(f'set new password success! ({binascii.hexlify(new_password_bytes).decode()})')

def get_pid_list():
    pid_list = []
    for entry in os.listdir('/proc'):
        if not entry.isdigit():
            continue
        try:
            with open(f'/proc/{entry}/comm', 'r') as f:
                if f.read().strip() == 'mysqld':
                    pid_list.append(entry)
        except Exception:
            pass
    return pid_list

if __name__ == "__main__":
    parser = _argparse()
    try:
        user, host = parser.USER.split('@')
    except ValueError:
        print('USER 必须是 user@host 格式')
        sys.exit(11)

    # flags: binary representation in memory for user@host (length-prefixed)
    flags = struct.pack('<B', len(host)) + host.encode() + struct.pack('<B', len(user)) + user.encode()

    PIDS = get_pid_list()
    pid = None
    if parser.PID is not None:
        if str(parser.PID) in PIDS:
            pid = parser.PID
        else:
            print(f'pid: {parser.PID} not exists {PIDS}')
            sys.exit(0)
    else:
        if len(PIDS) == 1:
            pid = int(PIDS[0])
        elif len(PIDS) == 0:
            print('当前不存在 mysqld 进程')
            sys.exit(2)
        else:
            print('当前存在多个 mysqld 进程, 请指定一个 --pid')
            sys.exit(3)

    MODIFY_PASSWORD = False
    NEW_PASSWORD = b''
    if parser.PASSWORD is not None:
        NEW_PASSWORD = encode_password(parser.PASSWORD)
        MODIFY_PASSWORD = True

    if parser.OLD_PASSWORD is not None:
        # 提供的是旧密码的 hex（无 0x）
        set_new_password(bytes.fromhex(parser.OLD_PASSWORD), NEW_PASSWORD, pid)
        sys.exit(0)

    # 查看当前内存中的 password（查找 flags 并解析结构）
    maps = find_data_in_mem(pid, flags)
    if len(maps) == 0:
        print('没找到对应的内存记录...')
        sys.exit(1)

    with open(f'/proc/{pid}/mem', 'rb') as f:
        for start, stop, offset in maps:
            try:
                f.seek(start)
                data = f.read(stop - start)
            except (OSError, ValueError):
                continue
            local_offset = offset + len(flags)
            # 先检查权限字段（示例期望 29 个权限字节为 0x01）
            MATCHED = True
            for i in range(29):
                if local_offset + 1 > len(data):
                    MATCHED = False
                    break
                if data[local_offset:local_offset+1] != b'\x01':
                    MATCHED = False
                    break
                local_offset += 2
            if not MATCHED:
                continue
            # 跳过 ssl、max_conn 等可变长度字段（8 个字段示例）
            for i in range(8):
                if local_offset + 1 > len(data):
                    MATCHED = False
                    break
                vsize = struct.unpack('<B', data[local_offset:local_offset+1])[0]
                local_offset += 1 + vsize
            if not MATCHED:
                continue
            # 插件名
            if local_offset + 1 > len(data):
                continue
            vsize = struct.unpack('<B', data[local_offset:local_offset+1])[0]
            plugins = data[local_offset+1:local_offset+1+vsize].decode(errors='ignore')
            local_offset += 1 + vsize
            if plugins != 'mysql_native_password':
                continue
            # 密码字段
            if local_offset + 1 > len(data):
                continue
            vsize = struct.unpack('<B', data[local_offset:local_offset+1])[0]
            if local_offset + 1 + vsize > len(data):
                continue
            old_password = data[local_offset+1:local_offset+1+vsize].decode(errors='ignore')
            print(f'{parser.USER} password: {old_password} at memory range {hex(start)} - {hex(stop)} offset {local_offset}')
            if MODIFY_PASSWORD:
                # old_password 形如 "*HEX..."，去掉首字符后为 hex
                if old_password and old_password[0] == '*':
                    set_new_password(bytes.fromhex(old_password[1:]), NEW_PASSWORD, pid)
                else:
                    print('发现的旧密码格式不符合预期，无法直接修改。')
            break
```

说明与风险提示
- 直接修改进程内存有风险：可能导致 mysqld 崩溃或数据不一致。请在充分理解风险并在允许的环境下（如测试环境或取得授权的生产环境中）谨慎使用。
- 最好在内存修改后尽快在数据库内执行 ALTER USER 并 FLUSH PRIVILEGES，使修改持久化到磁盘，并考虑重启 mysqld 以确保环境一致性。

参考源码
- https://github.com/ddcw/ddcw/tree/master/python/online_modify_mysql_password