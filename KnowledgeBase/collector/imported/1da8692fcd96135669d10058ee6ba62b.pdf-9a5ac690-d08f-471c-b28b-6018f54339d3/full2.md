# MySQL 全文索引

乔木 — 政采云技术 — 2024-01-17

## 1 背景简介
实际开发过程中，常有全文检索需求。通常会搭建 ES（Elasticsearch）来实现，但当数据量较少且不属于高并发高吞吐场景时，引入 ES 会使系统设计复杂并带来资源浪费。MySQL 从 5.7 开始内置了 ngram 全文检索解析器（用于中文分词），对 MyISAM 和 InnoDB 有效。因此可以直接在 MySQL 中使用 full-text 索引，满足简单的全文检索需求。

## 2 MySQL 全文索引简介
MySQL 的全文索引主要用于全文字段检索，支持 CHAR、VARCHAR、TEXT 等字段并仅支持 InnoDB 与 MyISAM 引擎。MySQL 内置 ngram 解析器来支持中文、日文、韩文等语言文本。全文索引支持三种模式：
- 布尔模式（IN BOOLEAN MODE）
- 自然语言模式（NATURAL LANGUAGE MODE）
- 查询拓展（QUERY EXPANSION）

## 3 ngram 解析器简介
ngram 是一种基于滑动窗口的分词方法：通过一个大小为 n 的滑动窗口，将文本分成多个由 n 个连续字符组成的 term。默认 ngram_token_size 为 2，可通过 ngram_token_size 设置分词大小。

示例：对“全文索引”分词结果
- ngram_token_size = 1：‘全’, ‘文’, ‘索’, ‘引’
- ngram_token_size = 2：‘全文’, ‘文索’, ‘索引’
- ngram_token_size = 3：‘全文索’, ‘文索引’
- ngram_token_size = 4：‘全文索引’

### 3.1 如何查看 ngram_token_size 配置
查看相关变量：
```sql
SHOW VARIABLES LIKE '%token%';
```

相关变量说明：
- innodb_ft_min_token_size：默认 3，表示最小字符数作为关键词（对 InnoDB 全文索引有效，增大可减少索引大小）。
- innodb_ft_max_token_size：默认 84，表示最大字符数作为关键词（对 InnoDB 全文索引有效，限制可减少索引大小）。
- ngram_token_size：默认 2，表示 ngram 解析器的分词大小（对使用 ngram 解析器时，innodb_ft_min_token_size 和 innodb_ft_max_token_size 无效）。

### 3.2 修改 ngram_token_size
修改方式：
- 启动参数方式：mysqld --ngram_token_size=1
- 配置文件方式（my.cnf / my.ini）：
  ```
  [mysqld]
  ngram_token_size=1
  ```
该参数不可动态修改，修改后需重启 MySQL 服务，并重新建立全文索引。

## 4 创建全文索引
1. 在建表时创建全文索引：
```sql
CREATE TABLE `announcement` (
  `id` INT(11) NOT NULL AUTO_INCREMENT COMMENT '主键',
  `content` TEXT CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NULL COMMENT '内容',
  `title` VARCHAR(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NULL DEFAULT NULL COMMENT '标题',
  PRIMARY KEY (`id`) USING BTREE,
  FULLTEXT INDEX `idx_full_text` (`content`) WITH PARSER `ngram`
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
```

2. 通过 ALTER TABLE 添加：
```sql
ALTER TABLE announcement ADD FULLTEXT INDEX idx_full_text(content) WITH PARSER ngram;
```

3. 直接通过 CREATE INDEX：
```sql
CREATE FULLTEXT INDEX idx_full_text ON announcement(content) WITH PARSER `ngram`;
```

## 5 全文索引测试
构建测试数据：
```sql
INSERT INTO announcement (id, content, title) VALUES
(1, '杭州市最近有大雪，出门多穿衣服', '杭州天气'),
(2, '杭州市最近温度很低，不适合举办杭州马拉松', '杭州马拉松'),
(3, '杭州市最近有大雪，西湖断桥会很美', '杭州西湖雪景'),
(4, '浙江大学的雪景也很美，周末可以去杭州逛逛', '浙江大学雪景'),
(5, '城北万象城开业，打折力度很大', '城北万象城开业火爆');
```

### 5.1 布尔模式（IN BOOLEAN MODE）
布尔模式支持常用操作符：
- +（必须出现）
- -（必须不出现）
- 无操作符（出现则相关性更高）
- <、>（减少或增加相关性）
- ~（负相关性）
- *（通配符）
- ""（短语）

示例与说明：

1) 操作符 +（必须出现）
```sql
SELECT * FROM announcement WHERE MATCH(content) AGAINST('+杭州' IN BOOLEAN MODE);
```
'+杭州' 表示必须出现“杭州”，出现次数越多相关性越高。

2) 操作符 -（必须不出现）
```sql
SELECT * FROM announcement WHERE MATCH(content) AGAINST('+杭州 -大学' IN BOOLEAN MODE);
```
表示结果必须包含“杭州”且不能包含“大学”。

3) 无操作符（出现则相关性更高）
```sql
SELECT * FROM announcement WHERE MATCH(content) AGAINST('杭州 大雪' IN BOOLEAN MODE);
```
出现“杭州”或“大雪”的行相关性会更高。

4) <>（增加或减少相关性）
```sql
SELECT * FROM announcement WHERE MATCH(content) AGAINST('+杭州 >大学' IN BOOLEAN MODE);
```
表示必须包含“杭州”，当出现“大学”时相关性会增加；使用 `<大学` 则会降低相关性。

5) ~（负相关性）
```sql
SELECT * FROM announcement WHERE MATCH(content) AGAINST('+杭州 ~大学' IN BOOLEAN MODE);
```
类似于 '+杭州 -大学'，当出现“大学”时相关性降低。

6) *（通配符）
```sql
SELECT * FROM announcement WHERE MATCH(content) AGAINST('杭州*' IN BOOLEAN MODE);
```
'*' 可用于前缀匹配，类似于 LIKE 的通配符（但行为不同，具体取决于分词与索引）。

7) ""（短语）
```sql
SELECT * FROM announcement WHERE MATCH(content) AGAINST('"杭州"' IN BOOLEAN MODE);
```
双引号表示短语搜索。注意分词大小会影响短语匹配的行为（例如 ngram_token_size=1 时）。

### 5.2 自然语言模式
自然语言模式是默认模式，把检索关键词当作自然语言处理。自然语言模式等价于布尔模式中的无操作符模式，下面三种查询等价：
```sql
-- 自然语言模式
SELECT * FROM announcement WHERE MATCH(content) AGAINST('杭州 大学' IN NATURAL LANGUAGE MODE);

-- 布尔模式（无操作符）
SELECT * FROM announcement WHERE MATCH(content) AGAINST('杭州 大学' IN BOOLEAN MODE);

-- 默认模式
SELECT * FROM announcement WHERE MATCH(content) AGAINST('杭州 大学');
```

### 5.3 查询拓展（WITH QUERY EXPANSION）
查询拓展先对搜索字符串执行自然语言搜索，取最相关行中的词汇扩展搜索字符串，然后再执行一次搜索，返回第二次搜索的结果。示例：
```sql
-- 首次根据 '万象城' 查找最相关行，并扩展得到相关词
SELECT * FROM announcement WHERE MATCH(content) AGAINST('万象城' WITH QUERY EXPANSION);

-- 使用扩展得到的词汇（例如 '城北', '万象', '开业', '打折' 等）再次查询
SELECT * FROM announcement WHERE MATCH(content) AGAINST('城北 万象 开业 打折' IN NATURAL LANGUAGE MODE);
```

## 6 总结
MySQL 全文索引通过建立倒排索引，可以显著提升检索效率，解决判断字段是否包含关键词的问题。但全文索引占用存储空间较大，如果内存无法一次性装下全部索引，性能会下降。使用全文索引需要合理配置分词大小等参数，否则查询结果可能不理想。

## 参考文献
- MySQL 官方文档：《Boolean Full-Text Searches》 https://dev.mysql.com/doc/refman/5.7/en/fulltext-boolean.html