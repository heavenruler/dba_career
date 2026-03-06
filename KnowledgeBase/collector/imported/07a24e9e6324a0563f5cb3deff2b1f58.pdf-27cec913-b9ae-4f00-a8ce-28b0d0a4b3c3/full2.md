# grant 之后真的需要执行 flush privileges 吗？

本文深入解析 MySQL 权限管理系统，包括用户创建、权限赋予与回收等操作的底层逻辑，以及 `flush privileges` 命令的作用和使用场景。按照权限范围从大到小说明：全局权限、库级权限、表权限与列权限，并讨论这些权限对已有连接的影响。

作者：MariaOzawa

---

## 示例：创建用户

```sql
create user 'ua'@'%' identified by 'pa';
```

该语句在磁盘上的 `mysql.user` 表里插入一行表示 `ua@%` 的记录（密码为 `pa`）。注意在 MySQL 中，用户由用户名 (user) + 地址 (host) 共同标识，`ua@ip1` 和 `ua@ip2` 是两个不同的用户。

在内存中，会向数组 `acl_users` 插入一个 `acl_user` 对象，这个对象的 `access` 字段表示权限位，初始为 0。

下文以用户 `ua` 为例说明不同范围权限的处理和生效时机。

---

## 全局权限

全局权限作用于整个 MySQL 实例，保存在 `mysql.user` 表中。赋予 `ua` 最高权限的示例：

```sql
grant all privileges on *.* to 'ua'@'%' with grant option;
```

这个 `GRANT` 命令做了两件事：

- 磁盘上：修改 `mysql.user` 表中 `ua@%` 对应行，设置表示权限的字段为 `'Y'`。
- 内存里：在 `acl_users` 数组中找到对应对象，将其 `access` 值（权限位）设置为“全 1”。

命令完成后，新建立的连接会读取 `acl_users` 中的权限并拷贝到线程对象中，之后该连接内使用的全局权限判断直接基于线程对象内部保存的权限位。

结论：
- `GRANT` 对全局权限同时更新磁盘和内存，命令完成后对新连接即时生效。
- 对于已经存在的连接，其线程对象中的全局权限不会被 `GRANT/REVOKE` 修改所影响（即不会即时改变）。

---

## 库级（db）权限

库级权限保存在 `mysql.db` 表中，内存中对应数组为 `acl_dbs`。示例命令：

```sql
grant all privileges on db1.* to 'ua'@'%' with grant option;
```

此 `GRANT` 同样做两件事：

- 磁盘上：在 `mysql.db` 表中插入一行，权限位字段设置为 `'Y'`。
- 内存里：在 `acl_dbs` 数组中增加一个对象，权限位为“全 1”。

判断用户对某个数据库的权限时，会遍历 `acl_dbs` 数组，根据 `user`、`host` 和 `db` 找到匹配对象并读取其权限位。因此，`GRANT`/`REVOKE` 对 db 权限的修改会立刻影响到正在运行的连接在访问库时的权限判断。

有一点需要说明：如果当前会话已经执行过 `USE db1` 并取得该库权限，该会话会把库权限保存在会话变量中，切换出该库之前会继续使用这份权限副本。因此存在一种情形：对某会话而言，即使 `REVOKE` 已经执行，但该会话在切库之前仍然拥有之前的权限（因为权限被缓存于会话）。

---

## 表权限和列权限

表权限定义存放在 `mysql.tables_priv`，列权限定义存放在 `mysql.columns_priv`。内存中这两类权限组合在 `column_priv_hash` 的哈希结构里。赋权示例：

```sql
create table db1.t1(id int, a int);

grant all privileges on db1.t1 to 'ua'@'%' with grant option;
GRANT SELECT(id), INSERT(id,a) ON mydb.mytbl TO 'ua'@'%' with grant option;
```

与 db 权限类似，这两类权限的 `GRANT` 会同时修改磁盘表和内存哈希结构，因此对已有连接也会马上生效。

---

## 为什么看起来不需要执行 flush privileges

从上面的分析可以看出，使用 `GRANT`/`REVOKE` 语句时，MySQL 会同时更新磁盘表和内存结构，二者是同步的。因此在正常、规范地通过 `GRANT` 或 `REVOKE` 管理权限时，通常不需要执行 `FLUSH PRIVILEGES`。

`FLUSH PRIVILEGES` 的行为是：清空内存中的权限结构（例如 `acl_users`），然后从 `mysql.user` 和其他系统表重新读取数据，重建内存权限数据。也就是说它会用磁盘表的数据覆盖内存数据。

因此只有当内存和磁盘上的权限数据不一致时，才需要 `FLUSH PRIVILEGES` 来让二者恢复一致。

---

## flush privileges 的使用场景

不一致的情况通常是由于不规范的操作导致的，例如直接用 DML（INSERT/UPDATE/DELETE）语句去修改系统权限表，而不是通过 `GRANT/REVOKE`。举例说明：

- 直接在 `mysql.user` 表用 `DELETE` 删除了用户的记录，磁盘上用户已被删除，但内存 `acl_users` 中仍有该用户的对象。因此在删除后短时间内仍可用该用户登录。
- 在这种状态下，尝试用 `GRANT` 给该用户赋权限会失败，因为磁盘表中找不到该用户记录。
- 试图重新创建该用户也可能失败，因为内存判断中会认为该用户仍然存在。

在上述情形下，执行 `FLUSH PRIVILEGES` 可以重建内存数据，反映磁盘上的真实状态，例如使得被直接删除的用户在登录时被阻止。

总结：仅在你或某个工具直接修改了权限系统表而未同步更新内存（即内存与磁盘不一致）时，才需要 `FLUSH PRIVILEGES`。因此尽量不要直接用 DML 操作系统权限表，而应使用 `GRANT` / `REVOKE` 等语句来规范管理权限。

---

## 小结

- `GRANT` / `REVOKE` 会同时修改系统权限表（磁盘）和对应的内存数据结构，权限判断时使用的是内存数据。
- 对于规范的权限变更，不需要随后执行 `FLUSH PRIVILEGES`。
- `FLUSH PRIVILEGES` 用于在磁盘与内存权限数据不一致时，强制用磁盘数据重建内存权限结构。这种不一致通常由直接用 DML 操作系统权限表导致，因此应尽量避免这种不规范操作。