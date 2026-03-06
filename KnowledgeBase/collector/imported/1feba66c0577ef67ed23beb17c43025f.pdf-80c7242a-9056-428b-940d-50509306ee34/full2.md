# 权限管控，还可以再简单点

原创 xiongcc 2024-05-25

## 前言

PostgreSQL 中的权限设计略微复杂，属于层次结构，对于新手不太友好，老鸟也会经常云里雾里。举个栗子，假如你需要查询某一行数据的话，大概需要经过这么多层关卡：

- 先通过数据库防火墙
- 能够登录对应数据库 (LOGIN)
- 表所在数据库的连接权限 (CONNECT)
- 表所在模式的使用权限 (USAGE)
- 表本身的查看权限 (SELECT)
- 列级权限 (SELECT)
- 行级策略 (RLS)

实名劝退不少新手小白，还有角色 (ROLE)、用户 (USER) 和组 (GROUP) 这些十分类似的概念，更不用说还可以角色套娃了。关于权限我也写了不少文章（此处省略链接）。今天向各位分享几个实用插件，简单易懂，快速上手，帮助各位轻松拿捏这个晕乎的权限体系。

## 权限查询

### crunchy_check_access

第一个推荐的插件是 crunchy_check_access。插件说明：Functions and views to facilitate PostgreSQL object access inspection。

在 MySQL 中，如果要获取一个用户的所有权限，很方便，一条语句就可以搞定，但是在 PostgreSQL 中，你需要拼接大量的表才能获取出可能并不完整的权限列表。crunchy_check_access 可以解决这样的难题。

示例：

```sql
postgres=# create extension check_access ;
CREATE EXTENSION

postgres=# \dx+ check_access
Objects in extension "check_access"
Object description
------------------------------------------
function all_access()
function all_access(boolean)
function all_grants()
function all_grants(boolean)
function check_access(text,boolean)
function check_access(text,boolean,text)
function check_grants(text,boolean)
function check_grants(text,boolean,text)
function my_privs()
function my_privs_sys()
view my_privs
view my_privs_sys
(12 rows)
```

比如你想看 postgres 用户对于表的相关权限：

```sql
postgres=# SELECT * FROM all_access() WHERE base_role = 'postgres' and objtype
role_path | base_role | as_role | objtype | objid | schemaname | objname
-----------+-----------+----------+---------+--------+------------+-------------+----------
postgres | postgres | postgres | table | 167849 | public | enrollments
postgres | postgres | postgres | table | 167849 | public | enrollments
postgres | postgres | postgres | table | 167849 | public | enrollments
postgres | postgres | postgres | table | 167849 | public | enrollments
postgres | postgres | postgres | table | 167849 | public | enrollments
(5 rows)
```

对于数据库的相关权限：

```sql
postgres=# SELECT * FROM all_access() WHERE base_role = 'postgres' and objtype
role_path | base_role | as_role | objtype | objid | schemaname | objname |
-----------+-----------+----------+----------+-------+------------+----------+--------------------------
postgres | postgres | postgres | database | 33405 | | postgres |
postgres | postgres | postgres | database | 33405 | | postgres |
postgres | postgres | postgres | database | 33405 | | postgres |
postgres | postgres | postgres | database | 33405 | | postgres |
postgres | postgres | postgres | database | 33405 | | postgres |
(5 rows)
```

更多用法各位读者自行尝试，确实十分方便。

### pg_permissions

第二个插件是 pg_permissions。插件说明：This extension allows you to review object permissions on a PostgreSQL database。

pg_permissions 支持权限对比。DBA 在管理权限时，只需要在 permission_target 表中录入相应的权限。后期开发人员或 DBA 在开发阶段可能会随意分配权限，比如权限超了，只需要查询结果还可以写入等，那么 DBA 只需要运行对比函数就能发现权限是否符合设计要求，防患于未然。

示例：

```sql
postgres=# \dx+ pg_permissions
Objects in extension "pg_permissions"
Object description
-------------------------------------
function permission_diffs()
function permissions_trigger_func()
sequence permission_target_id_seq
table permission_target
type obj_type
type perm_type
view all_permissions
view column_permissions
view database_permissions
view function_permissions
view schema_permissions
view sequence_permissions
view table_permissions
view view_permissions
(14 rows)
```

权限对比示例：

```sql
SELECT * FROM public.permission_diffs();
missing | role_name | object_type | schema_name | object_name | column_name |
---------+-----------+-------------+-------------+-------------+-------------+------------
f | laurenz | VIEW | appschema | appview | |
t | appuser | TABLE | appschema | apptable | |
(2 rows)
```

这表示 appuser 缺少对 appschema.apptable 的 DELETE 权限（missing 为 TRUE），而 laurenz 对 appschema.appview 多了 SELECT 权限（missing 为 FALSE）。

另外，pg_permissions 也可以像 crunchy_check_access 那样查询某个用户的权限列表，对应的视图包括 table_permissions、column_permissions 等。例如：

```sql
postgres=# select * from table_permissions limit 2;
object_type | role_name | schema_name | object_name | column_name
-------------+-------------------+-------------+------------------+-------------+------------+---------
TABLE | pg_database_owner | public | pgbench_branches |
TABLE | pg_database_owner | public | pgbench_history |
(2 rows)

postgres=# select * from column_permissions limit 2;
object_type | role_name | schema_name | object_name | column_name |
-------------+-------------------+-------------+---------------+-------------+------------+---------
COLUMN | pg_database_owner | public | ptab01_202303 | id |
COLUMN | pg_read_all_data | public | ptab01_202303 | id |
(2 rows)
```

灰常好用！

## 实用 SQL

如果各位觉得装插件麻烦的话，也可以使用一些懒人专用的 SQL 来查看权限信息。下面是一个较长的示例查询，用来汇总服务器权限、数据库归属、模式权限、表所有权以及对象权限（原文保留完整 SQL 代码块）：

```sql
WITH server_permissions AS (
SELECT
r.rolname,
'Server_Permissions' AS "Level",
r.rolsuper,
r.rolinherit,
r.rolcreaterole,
r.rolcreatedb,
r.rolcanlogin,
ARRAY(
SELECT b.rolname
FROM pg_catalog.pg_auth_members m
JOIN pg_catalog.pg_roles b ON m.roleid = b.oid

WHERE m.member = r.oid
) AS memberof,
r.rolbypassrls
FROM pg_catalog.pg_roles r
WHERE r.rolname !~ '^pg_'
),
db_ownership AS (
SELECT
r.rolname,
'DB_Ownership' AS "Level",
d.datname
FROM pg_catalog.pg_database d, pg_catalog.pg_roles r
WHERE d.datdba = r.oid
),
schema_permissions AS (
SELECT
'Schema Permissions' AS "Level",
r.rolname AS role_name,
nspname AS schema_name,
pg_catalog.has_schema_privilege(r.rolname, nspname, 'CREATE') AS create_grant,
pg_catalog.has_schema_privilege(r.rolname, nspname, 'USAGE') AS usage_grant
FROM pg_namespace pn, pg_catalog.pg_roles r
WHERE array_to_string(nspacl, ',') LIKE '%' || r.rolname || '%'
AND nspowner > 1
),
table_ownership AS (
SELECT
'Table Ownership' AS "Level",
tableowner,
schemaname,
tablename
FROM pg_tables
GROUP BY tableowner, schemaname, tablename
),
object_permissions AS (

SELECT
'Object Permissions' AS "Level",
COALESCE(NULLIF(s[1], ''), 'public') AS rolname,
n.nspname,
relname,
CASE
WHEN relkind = 'm' THEN 'Materialized View'
WHEN relkind = 'p' THEN 'Partitioned Table'
WHEN relkind = 'S' THEN 'Sequence'
WHEN relkind = 'I' THEN 'Partitioned Index'
WHEN relkind = 'v' THEN 'View'
WHEN relkind = 'i' THEN 'Index'
WHEN relkind = 'c' THEN 'Composite Type'
WHEN relkind = 't' THEN 'TOAST table'
WHEN relkind = 'r' THEN 'Table'
WHEN relkind = 'f' THEN 'Foreign Table'
END AS "Object Type",
s[2] AS privileges
FROM
pg_class c
JOIN pg_namespace n ON n.oid = relnamespace
JOIN pg_roles r ON r.oid = relowner,
UNNEST(COALESCE(relacl::text[], FORMAT('{%s=arwdDxt/%s}', rolname,
REGEXP_SPLIT_TO_ARRAY(acl, '=|/') s
WHERE relkind <> 'i' AND relkind <> 't'
)
SELECT
"Level",
rolname AS "Role",
'N/A' AS "Object Name",
'N/A' AS "Schema Name",
'N/A' AS "DB Name",
'N/A' AS "Object Type",
'N/A' AS "Privileges",
rolsuper::text AS "Is SuperUser",
rolinherit::text,
rolcreaterole::text,
rolcreatedb::text,
rolcanlogin::text,

memberof::text,
rolbypassrls::text
FROM server_permissions
UNION
SELECT
dow."Level",
dow.rolname,
'N/A',
'N/A',
datname,
'N/A',
'N/A',
'N/A',
'N/A',
'N/A',
'N/A',
'N/A',
'N/A',
'N/A'
FROM db_ownership AS dow
UNION
SELECT
"Level",
role_name,
'N/A',
schema_name,
'N/A',
'N/A',
CASE
WHEN create_grant IS TRUE AND usage_grant IS TRUE THEN 'Usage+Create'
WHEN create_grant IS TRUE AND usage_grant IS FALSE THEN 'Create'
WHEN create_grant IS FALSE AND usage_grant IS TRUE THEN 'Usage'
ELSE 'None'
END,
'N/A',
'N/A',

'N/A',
'N/A',
'N/A',
'N/A',
'N/A'
FROM schema_permissions
UNION
SELECT
"Level",
tableowner,
tablename,
schemaname,
'N/A',
'N/A',
'N/A',
'N/A',
'N/A',
'N/A',
'N/A',
'N/A',
'N/A',
'N/A'
FROM table_ownership
UNION
SELECT
"Level",
rolname,
relname,
nspname,
'N/A',
"Object Type",
privileges,
'N/A',
'N/A',
'N/A',
'N/A',

'N/A',
'N/A',
'N/A'
FROM object_permissions
ORDER BY "Role";
```

（注：上述 SQL 来自原文示例，实际使用时可能需要根据环境调整或修复拼接部分。）

## 权限限制

为了解决原生 PostgreSQL 某些无法限制的操作（例如无法阻止 ALTER SYSTEM、COPY PROGRAM 等），可以使用一些扩展来提供更多控制与审计。

### set_user

set_user 是一个扩展，允许在会话中切换用户，并在需要时进行权限提升，同时提供增强的日志记录和控制。主要功能包括：

- 在切换角色时记录日志，并在提升为超级用户时使用特定标记。
- 可配置在切换为特权角色时将 log_statement 设置为 "all"，以记录所有执行的 SQL。
- 可配置阻止 ALTER SYSTEM、COPY PROGRAM、以及对 log_statement 的修改等敏感命令。
- 可配置在超级用户提升时给日志追加一个审计标签（默认 'AUDIT'）。
- 可配置在出错时使 backend 进程退出（exit_on_error）。
- 支持在提升后调用的后置钩子（post-execution hook）。

这个插件提供了对敏感操作的限制与更细粒度的审计，用法相对简单。

### pg_restrict

pg_restrict 功能类似，并额外支持禁止删除数据库等操作。原生 PostgreSQL 很难阻止删除数据库（除非设为模板数据库），pg_restrict 提供了以下可配置项：

- pg_restrict.alter_system (boolean)：限制 ALTER SYSTEM 仅能由主控角色执行，默认 false。
- pg_restrict.copy_program (boolean)：限制 COPY ... PROGRAM 仅能由主控角色执行，默认 false。
- pg_restrict.master_roles (string)：允许执行受限命令的角色列表，多个角色用逗号分隔，默认 postgres。
- pg_restrict.nonremovable_databases (string)：将列出的数据库限制为只有主控角色才能 DROP（即使当前角色是数据库所有者或超级用户），默认包含 postgres、template1、template0。
- pg_restrict.nonremovable_roles (string)：将列出的角色限制为只有主控角色才能 DROP（即使当前角色有 CREATEROLE 权限或是超级用户），默认是 postgres。

这些设置可以防止一些危险操作被随意执行。

### pg_sulog

pg_sulog 主要针对超级用户的操作审计与限制，目的在于使超级用户的操作也可受控。该扩展的模式包括：

- 'BLOCK'：阻止指定超级用户角色的所有操作。
- 'MAINTENANCE'：仅允许维护类命令，其他操作被阻止（如 VACUUM、REINDEX、ANALYZE、CLUSTER）。
- 'LOGGING'：记录超级用户的所有操作到日志。

注意：pg_sulog 已有一段时间没有维护，使用前需评估其兼容性和安全性。

## 小结

权限管理还是需要多动手，多折腾几下，实际上就是理解并运用好层次关系、审计和限制策略。使用上述插件可以在不改变业务逻辑的前提下，增强权限可见性、做权限对比，以及对敏感操作进行限制和审计，从而让权限管控变得更容易上手、更安全。