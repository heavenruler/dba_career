一 篇 乃 MySQL 用 戶 ， 分 析 版 本 核 心 差 异 的 文 章 ﹣﹣8﹒028﹣8﹒4 的 莘 异
原 刨 iuaustin3 AustinDatabases 2025 年 10 月 9 日 06﹕01 菲 律 客
井 欣 迎 是 介 紹 一 下 群 ， 如 果 媒 灰 趣 PolarDB ，MongoDB ，MySQL ，PostgreSQL ，Redis， OceanBase， Sql
Server 等 有 向 顓 ， 有 需 求 都 可 以 加 群 群 內 有 各 大 敷 据 庠 行 山 大 咖 ， 可 以 解 決 你 的 同 題 。 加 群 這 珠 紹
liuaustin3 ，( 共 3300 人 左 右 ] ﹢ 2 ﹢ 3 ﹢ 4 ﹢5 ﹢ 6 ﹢ 7 ﹢ 8 ﹢9﹚ (1 2 3 4 5 6 7 群 均 已 爆 滿 ， 升 8 群 近 400
9 群 200﹢， 升 10 群 PolarDB 支 孤 刈 群 100﹢﹚
內 容 到 底 玆 些 版 本 都 更 新 了 什 念 ， 有 什 念 推 劭 我 仗 需 要 芙 注 的 新 知 汎 烈 。 我 們 人 莖 助 大 家 楝 理 一 下 。
8﹒028 之 后 災 于 rename column 和 drop column 的 instant 的 优 化 。
ALGORITHM=INSTANT 的 操 作 宛 全 不 涉 及 敷 据 (Data﹚ 和 索 引 (Index﹚ 的 重 柬 或 拷 以 。 它 作 在 以 下 時
仁 居 面 迸 行 修 改 ， 敷 据 字 典 (Data Dictionary﹚ 的 修 改 ﹔﹒ 在 江 統 表 ( 如 mysql﹒innodb﹍table﹍stats 等 ﹚ 中
更 新 表 的 定 文 (Metadata}﹚。 玆 人 掌 作 本 身 是 极 快 的 。 內 存 中 的 表 定 又 修 改 ﹕ 作 更 新 InnoDB 綾 存 的 表 結
构 定 又 。 因 加 沒 有 敷 据 拷 以 ， 所 以 操 作 可 以 在 毫 秒 級 完 成 ， 并 且 不 中 斷 或 极 少 中 斷 災 表 的 漢 罟 操 作 ( 几 乎
汲 有 鏍 兗 孝 ﹚。
在 8﹒028 之 前 修 改 列 名 ， 或 者 刪 除 列 夾 引 來 重 建 表 的 可 能 ， 而 在 8﹒029 后 我 們 粧 可 以 通 返 rename column
(B﹒028﹚﹒drop column (8﹒029﹚ 人 支 持 algorithm=instant 來 迸 行 暗 回 的 操 作 。
而 另 一 仁 美 罰 就 是 在 我 什 add column 的 旱 候 。 如 果 指 定 滑 加 的 列 在 before or after 的 情 況 下 ， 需 要 重 建
表 ， 而 現 在 在 8﹒029 后 ， 就 汲 有 玆 人 同 題 ， 即 使 在 rename column 也 是 秒 改 。
際 了 阡 DBA 管 理 有 改 好 的 部 分 ， 在 敷 据 庠 結 柬 部 分 也 有 一 些 改 妝 。
1 Redo log 劭 恣 的 容 量 的 引 入 ， 玆 仁 是 8﹒030 之 后 引 入 的 如 化 ， 之 前 redo log buffer 默 汀 是 16MB ， 如 果
要 如 化 需 要 重 屈 主 机 ，( 注 愛 我 仝 混 的 是 REDO LOC BUFFER ， 不 是 innodb buffer size﹚ ， 玆 里 MYSQL
可 以 恆 旱 在 有 大 事 劣 的 情 況 下 咪 旱 如 化 ， 兀 需 重 屆 迸 行 redo log buffer 的 如 化 。
那 么 際 之 被 拋 弇 的 客 量 innodb﹍log﹍files﹍in﹍group 和 innodb﹍log﹍file﹍size。
2 BINLOG 的 日 志 格 式 ， 佳 8﹒034 版 本 彼 底 牯 binlog format 的 格 式 的 沉 置 蒼 止 ， 只 能 且 只 能 有 一 仁 格 式
TOW ，
之 前 老 MYSQLDBA 熟 悄 的 statement， mixed 等 都 取 消 了 。
3 一 些 汀 返 方 法 的 取 消 ， 如 FIDO ， 放 人 仁 迎 方 法 是 先 迸 的 但 加 什 么 取 消 了 ， 放 是 因 加 MYSQL 的 云 島 略
中 汀 沈 更 多 的 圣 近 服 努 度 造 在 敏 据 庠 外 迸 行 集 成 ， 而 不 是 在 敷 据 庠 內 。
版 本 ︴量『′之祠E_婁聾嗤 重 品 頻 域 羔 警 更 新 內 容 / 重 扂 特 性 (Key Highlights﹚
移 除 TLS v1﹒0A1﹒1 支 持 ﹔ALTER TABLE … RENAMIE COL
50 2022﹣01﹣1 安 全 性 、 性 能 ，UMN 支 持 ALGORITHM=INSTANT ﹔ Performance Schem
| 8 些 控 、DDL a 引 入 CPU﹍TIME 指 柩 ﹔ 新 增 逄 接 內 存 苫 控 与 限 制 ﹔DAT
B/TIME 支 持 至 3001 年 。
( 撤 回 版 本 ， 因 一 重 InnoDB 同 題 ﹚ ﹔ ALTER TABLE … DR
m 2022﹣04﹣2 DDL、 安 鈍 OP COLUMN 支 持 ALCORITHM=INSTANT ﹔ 敏 威 紫 統 空
0 6 性 、 SQL 通 法 ， 量 安 全 持 久 化 ﹔CREATE FUNCTION/PROCEDURE/TRICC
ER 支 持 IF NOT EXISTS ﹔ 分 离 的 XA 事 炒 。
InnoDB 支 持 Redo Log 窖 量 劭 恣 配 置 0nnodb」edo」og﹂
( 2022﹣07﹣2 ﹍ 字 符 集 、Inno ﹍ Capacity﹚ ﹔ 引 入 ClIPK 模 式 (Cenerated Invisible Primary
0 6 DB、CIPK Keys﹚ ﹔ 新 增 utf8mb4 多 透 說 排 序 規 刪 ﹔ REVOKE 支 持 IF
EXISTS。
支 持 SQL 柩 准 INTERSECT 和 EXCEPT 操 作 符 ﹔ ANALYZE
2022﹣10﹣1 ﹍ SQL 适 法 、 优
8﹒0﹒31 1 化 器 、 組 件 TABLE 支 持 JSON 更 新 直 方 圉 ﹔ Performance Schema 內
存 指 柩 增 強 ﹔ 廖 弈 keyring﹍oci 插 件 。
更 改 max﹍join﹍size 行 切 ( 限 制 基 破 表 最 大 行 冰 向 敷 ﹚ ﹔E
2023﹣01﹣1 ﹍ 优 化 器 、CIP
8﹒0﹒32 | kK、 廖 奐 XPLAIN 支盎笭﹜『』x[】Iain一form…】t黑j隻i人崋﹐彳訌出格式 ﹔ 度 奔 ﹩ 升 次
圖 的 非 帶 引 吋 柩 汎 符 。
2023﹣04﹣1 ﹍ 組 件 、 安 全 、 ﹍ 度 弇 用 戶 自 定 又 排 序 規 刪 ﹔ 企 心 版 敷 据 脖 敏 由 插 件 糕 加 組
0 8 度 奔 件 ﹔INSTALL COMPONENT 這 句 支 持 SET 子 句 。
OpenSSL 升 3 3﹒0﹒9 ﹔ | 工 具 } binl
…Z〕_07_ˍ 君 全 、 廖 指 、 pen 升ˊ蘆阜至 廉 弈 my〒q pump 工 具 ﹔ 度 弈 bin
8﹒0﹒34 蠡〕 sQL og﹍format 妝 量 ﹔ 廉 弈 mysq﹍native﹍password 插 件 ﹔ CU
RRENT﹍USERiD 可 作 加 VARCHAR/TEXT 默 汀 值 。
FIDO 圣 迎 方 法 ﹔ INFORMATION﹍SCHEMA﹒PR
2023﹣10﹣2 度 弈 、 安 金 、 仁 吳 扣 括 作 共 ﹒ 國 0
8﹒0﹒35 …〕 ( OCESSLIST ﹔ 廉 夾 搞 柯 中 %/﹍ 通 配 彼 ﹔ Group Replication
版 本 要 求 放 寅 。
2024﹣01﹣1
8﹒0﹒36 2 宏 全 、 性 能 OpenSSL 升 級 至 3﹒0﹒12 ﹔ 更 新 GnuPC 构 建 密 習 。
n 2024﹣04﹣3 ﹍ 复 制 、 克 隆 、 ﹍ Clone 插 件 支 持 組 列 內 思 版 本 克 隆 ﹔Cpen5SL 升 級 至 3﹒0﹒
0 0 性 能 13 ﹔ 修 复 TempTable 引 擎 性 能 同 題 。
2024﹣07﹣0 態 夏 InnoDB 大 量 表 重 屈 失 敗 的 回 丹 同 顏 ( 宋 陀 在 8﹒0﹒39
8﹒0﹒38 ( 撤 回 版 本 ﹚ 偉 0 閻 6
1 修 复 ﹚。
2024﹣07﹣2 ‵
8﹒0﹒39 j 修 复 修 复 8﹒0﹒38 引 入 的 InnoDB 重 屈 失 敝 同 題 。
2Eji 重 近 示 Performance Schema 的 data﹍locks / data﹍lock﹍wa
8﹒0﹒40 s 0 性 能 、 安 全 i ， 降 低 褒 章 爭 ﹔ Open5SL 升 級 至 3﹒0﹒15 ﹔ mysql 容 戶 端
新 增 ﹣﹣system﹣command 造 頤 。
2025﹣01﹣2 倫 氣 、 吳 土 修 复 空 同 索 引 扼 坏 (Incompatible Change， 需 重 建 索
】 引 ﹚ ﹔ OpenSSL 升 級 至 3﹒0﹒16。
ˍ ﹍ CROUP BY ROLLUP (﹒﹒﹚ 替 代 透 法 》Performance Schema
ˍ ﹍ 2024﹣10﹣1 ﹍ 性 腐 、SQL 通 ˍ ， ， 二 ﹒ 閻
8﹒4﹒3 (LTS﹚ 。 法 、 复 制 嵇 表 重 近 汀 ﹔ 二 迸 制 日 志 事 劣 依 購 跟 踞 优 化 (ankerl﹕﹕unor
﹚ dered﹍dense﹕﹕map} ﹔ Open5SL 升 級 至 3﹒0﹒15。
2025﹣01﹣2 修 复 空 向 索 引 扼 坏 ( 同 8﹒0﹒41﹚ ﹔ PERFORMIANCE﹍SCHE
8﹒4﹒4 (LTS﹚ 修 复 (
1 MA﹒PROCESSLIST 用 戶 分 配 改 迸 。
0 ( 2025﹣04﹣1 安 全 、 修 春 、 ﹍ OpenSSL 升 級 至 3﹒0﹒16 ﹔ 新 增 ﹣﹣check﹣table﹣functions 造
0 同 SQL 須 ﹔ 修 复 innodb﹍spin﹍wait﹍delay 性 能 回 功 。
a 2025﹣07﹣2 哀 汀 s 囤 mysql 竇/=ˍ立謊胃€J壬i亨 一 commands 造 頜 ﹔ Gou鬥 Replication
2 GCS 改 迸 ， 停 止 逄 接 已 离 升 的 成 呂 以 減 少 延 迕 。
W 史
同 云 上 DBA 是 造 葛 亮 ， 云 下 的 DBA 是 美 云 坊 ， 此 适 怎 活 ﹖ 4 念 如 化 直 市 要 害
男 外 圖 考 家 涉 PG 18 Al 能 力 不 行 ， 到 底 行 不 行 ﹖
日 MongoDB 井 始 接 客 戶 皮 用 系 統 Al 改 造 的 活 了 ﹣﹣OMG 玆 世 界 太 瘋 狂
日 一 篇 PostgreSQL 日 志 吃 題 逕 的 非 常 送 細 附 帚 分 析 解 決 方 絨 的 文 章 ( 翻 連 ﹚
向 DBA 丐 Al 斗 智 斗 勇 的 一 天 ， 進 是 妝 3 蒼 。 進 是 星 巴 克
科 技 改 寒 生 活 ， 阿 里 云 DAS Al 改 室 了 什 么
同 企 載 DBA 廋 造 沒 听 逕 返 Supabase， 因 之 他 不 牛 純 ! !
向 Oracle 推 出 原 生 支 持 Oracle 敏 捰 庠 的 MCP 服 劣 器 ， 助 力 企 山 构 建 智 能 代 理 皮 用
日 PolarDB MySQL SQL 优 化 指 南 (SQL 优 化 系 列 5﹚
向 升 岑 歎 魚 翡 Redis 的 大 keys 的 向 題 ， 我 一 仁 DBA 怎 公 解 決 ﹖
旦 IF﹣Club 你 提 意 儿 拿 社 物 AustinDatabases 破 10000
旦 午 岑 歎 魚 我 Redis 的 大 keys 的 同 題 ， 我 一 仁 DBA 怕 公 解 決 ﹖
巴 云 基 座 披 本 是 大 厂 有 ， 那 小 厂 和 私 有 云 的 出 路 在 哪 里 ﹖
OceanBase 相 美 文 章
棻 敷 据 庠 下 的 一 手 好 棋 ! 共 享 存 傭 落 子 了 !
日 OceanBase 光 速 快 遞 OB Cloud ”MySQL ” 給 我 ，Thanks a lot
固
和 架 构 為 洸 通 那 种 ^ 一 坨 ” 的 紅 統 ， 推 荐 只 能 是 OceanBase，Why ﹖
口 OceanBase Hybrid search 雒 力 測 浙 ， 平 揆 MySQL 的 好 送 捍
目 染 敷 据 庠 下 的 一 手 好 棠 ! 共 享 存 值 落 子 了 !
日 罠 了 3750 一 字 的 戒 ， 在 2000 字 的 OB 白 皮 上 了 一 淄 ﹣~iD 《OceanBase 社 囿 版 在 泛 互 坊 景 的 皮 用 索 例
口 OceanBase 牟 机 版 可 以 大 批 量 快 途 部 署 吾 ﹖ YES
早 OceanBase 6 大 址 分 法 ﹣﹣OBCA 祖 頻 圳 分 怠 結 第 六 章
口 OceanBase 6 大 孤 刈 法 ﹣﹣OBCA 祖 頻 字 刈 怠 結 第 五 章 ﹣﹣ 索 引 与 表 透 水
|
固
固 固 固 固 ﹍ 囤 回 囤 固
E | 不
固 固
固
固 囤
OceanBase 6 大 查 分 法 ﹣﹣OBCA 祖 頻 柚 刈 怠 結 第 五 章 ~ 升 岑 与 庠 表 近 汀
同 OceanBase 6 大 孤 刈 法 ﹣﹣OBCA 祖 頭 查 切 怠 結 第 凶 章 ﹣﹣ 敷 据 庠 安 裟
同 OceanBase 6 大 孤 史 法 ﹣﹣OBCA 視 頻 孤 史 怒 結 第 三 章 ﹣ 敏 据 庠 引 擊
同 OceanBase 架 构 孤 切 ﹣﹣OB 上 手 視 頻 孤 切 怓 結 第 二 章 (OBCA﹚
同 OceanBase 6 大 孝 切 法 ﹣﹣OB 上 手 視 頻 學 史 怓 結 第 一 章
同 汲 有 凄 是 塭 掉 的 一 代 ﹣﹣ 迄 第 四 屆 OceanBase 敏 捰 庠 大 寫
同 OceanBase 造 祖 福 活 功 ， 則 物 和 幸 逞 帶 給 您
同 跟 我 學 OceanBase4﹒0 ﹣ 固 淡 白 皮 向 (OB 分 布 式 优 化 哪 里 了 提 高 了 童 度 ﹚
同 跟 我 學 OceanBase4﹒0 ﹣ 岡 深 白 皮 市 (4﹒0 优 化 的 核 心 貴 是 什 么 ﹚
跟 我 字 OceanBase4﹒0 ﹣ 圃 漆 白 皮 旨 (0﹒5﹣4﹒0 的 架 构 与 之 前 架 柬 特 扂 ﹚
同 跟 我 學 OceanBase4﹒0 ﹣ 固 淡 白 皮 向 ( 日 的 概 念 害 死 人 呀 ， 更 新 知 迂 和 理 念 ﹚
同 瞻 焦 SaaS 美 企 弘 敷 据 庠 遵 型 ( 技 木 、 成 本 、 合 規 、 地 緣 政 治 ﹚
同 OceanBase 拋 刈 池 睪 ﹣﹣ 建 立 MySQL 租 戶 ， 像 用 MySQL 一 根 使 用 OB
同 ^ 合 体 吧 兄 弟 仝 ! / 一 一 仁 浪 浪 山 小 妖 怪 看 OceanBase 囤 宁 芯 月 优 化 《OceanBase ^ 重 如 小 埃 / 之 歌 》
MongoDB 相 羔 文 章
向 MongoDB ” 升 級 頤 目 ” 大 型 送 繕 剎 (4﹚﹣﹣ 与 升 岐 和 架 构 洸 通 与 拍 尾
MongoDB ^ 升 級 須 目 ” 大 型 迷 繞 券 (3﹚﹒﹣ 自 劭 校 紂 代 磅 丐 注 意 事 須
同 MongoDB ^ 升 級 頤 目 ” 大 垚 逄 繞 制 (2﹚﹣﹣ 到 底 進 是 ”der
MongoDB ^ 升 級 須 目 / 大 型 逄 緩 制 (1﹚﹣﹣ 可 ^ 生 / 可 不 升
同 MongoDB 大 信 大 雅 ， 上 人 同 分 月 真 三 俗 ﹣﹣ 4 分 什 么 分
MongoDB 大 俗 大 雅 ， 高 端 知 迦 泰 ^ 廈 俗 / ﹣3 奇 葩 敷 据 更 新 方 法
同 MongoDB 孤 史 建 模 丐 迥 汀 思 路 ﹣﹣ 統 汀 敷 据 更 新 案 例
MongoDB 大 俗 大 雅 ， 高 端 的 知 沖 活 ^ 斌 俗 ^ ﹣﹣ 2 嵌 奧 和 引 用
MongoDB 天 俋 大 雅 ， 高 端 的 知 社 迪 低 倍 ”﹣﹣ 1 什 念 叫 多 模
MongoDB 合 作 考 迫 指 節 活 劭 貼 附 屙 ，MongoDB 基 砷 知 迅 通 速
MongoDB 年 底 活 功 ， 免 翥 考 逆 名 續 7 仁 公 次 身 荻 得
MongoDB 使 用 岑 上 妙 招 ， 直 接 DOWN 机 ﹣﹣ 一 清 理 表 碎 月 旱 致 的 灰 禍 ( 送 卡 活 加 結 束 ﹚
ongoDB 2023 年 度 紐 約 MongoDB 年 度 大 吟 迺 題 ﹣﹣ MongoDB 敏 据 模 式 丐 建 模
ongoDB 沙 机 然 畚 那 篇 文 章 是 ” 轉 ~
MongoDB﹍ 鈕 丟 敷 据 呔 ﹖ 在 灰 祁 刀 MongoDB 汎 束 然 呈
MONGODB ﹣﹣﹣﹣ Austindatabases 庈 年 文 章 合 集
MongoDB 麻 煩 考 鳥 思 ， 不 憶 可 以 同 ， 別 率 公 用 行 吶 ! ﹣﹣TTL
PolarDB 已 經 午 放 的 深 程
同 PolarDB 非 官 方 深 程 第 八 苦 ﹣﹣ 敷 据 庠 彈 性 彈 出 一 月 未 來 ﹣﹣ 結 進
向 PolarDB 非 官 方 進 程 第 七 苦 ﹣﹣ 敷 据 舐 份 妤 原 睿 尖 宛 成 是 怎 公 做 到 的 ﹣﹣ 答 題 領 芋 品
同 PolarDB 非 官 方 深 程 第 六 苦 ﹣﹣ 斂 据 庠 名 枸 延 脊 玆 么 玩 ﹣﹣ 第 題 頓 莢 品
向 PolarDB 非 官 方 進 程 第 五 苦 ﹣﹣PolarDB 代 理 很 重 要 咩 ﹖ ﹣﹣ 筈 題 領 猁 品
PolarDB 非 官 方 深 程 第 四 芯 ﹣﹣PG 宋 旱 物 化 視 囧 与 行 列 敷 据 整 合 悍 理 ﹣﹣ 筈 題 領 莠 品
PolarDB 非 官 方 深 程 第 三 芯 ﹣﹣MySQL﹢IMCI= 性 能 怪 魯 ﹣﹣ 答 題 領 美 品
同 PolarDB 非 官 方 深 程 第 二 苦 ﹣﹣ 云 原 生 架 构 丐 特 有 功 能 ﹣﹣﹣ 筈 題 領 美 品
向 PolarDB 非 官 方 深 程 第 一 苦 ﹣﹣ 用 戶 角 度 怎 公 看 PolarDB ﹣﹣ 筈 題 領 美 品
同 免 習 PolarDB 云 原 生 進 程 ， 听 遞 ” 抑 / 社 品 ， 重 塑 云 上 知 泊 。 提 高 冱 軍 能 力
PolarDB 相 羔 文 章
口 ﹣MySQL SQL 优 化 案 例 ， 反 泰 MySQL 不 死 沒 有 天 理
史 非 / 尸 商 厂 告 / 的 PolarDE 進 程 ﹔ 用 戶 共 刨 的 新 式 字 切 茄 本 ﹣﹣7 位 同 孝 狹 莠 PolarDB 孤 刈 之 星
同 / 望 复 紮 的 SQL 不 再 需 要 特 別 的 优 化 ”， 那 修 研 究 PolarDB for PC 列 式 索 引 加 遨 复 作 SQL 建 行
日 數 据 底 縮 60%% 迂 ”PostgreSQL” SQL 逞 行 更 怏 ， 故 不 科 孤 呀 ﹖
口 玆 仁 PostgreSQL 巡 我 有 宦 本 找 老 板 要 瘋 腿 鵲 膊 !
用 MySQL 分 匡 表 腧 子 有 水 ! 仁 宋 例 ， 軍 劣 ， 午 友 雋 度 分 析 PolarDB 使 用 不 為 像 MySQL 那 公 Low
P﹥MySQL SQL 优 化 杯 例 ， 反 斌 MySQL 不 死 汲 有 天 理
MySQL 和 PostgreSQL 可 以 一 起 怏 童 岑 展 ， 提 供 更 多 的 功 能 ﹖
玆 仁 MySQL 逸 ^ 云 上 自 建 的 MySQD/ 都 是 ” 小 垃 圾 ^
口 PolarDB MySQL 加 索 引 卡 主 的 整 体 解 決 方 案
同 ^PostgreSQL/” 高 性 能 主 仁 強 一 致 溱 電 分 离 ， 猞 行 ， 你 汲 蹄 !
回 固 囤
固
同 PostgreSQL 的 搜 局 者 同 怡 了 ， 祖 返 來 了 !
同 在 被 厂 商 困 剿 的 DBA 求 生 之 路 ﹣﹣ 我 是 老 油 紮
同 POLARDB 潑 加 字 段 ^ 卡 / 住 ﹣ 玆 袍 Polar 不 苗
同 PolarDB 版 本 差 异 分 析 ﹣ 外 人 不 知 道 的 秘 密 ( 進 是 綿 羊 ， 進 是 怪 曾 ﹚
同 在 被 厂 商 困 剿 的 DBA 求 生 之 路 ﹣ 一 我 是 老 油 紮
同 PolarDB 筈 題 拿 ﹣﹣ t 刀 怒 的 帆 、 同 敝 一 衣 、T 恤 ， 來 自 杭 州 的 Package ( 活 劾 結 束 了 ﹚
同 PolarDB for MySQL 三 大 核 心 之 一 POLARFS 今 天 扒 午 它 ﹣﹣﹣ 嘛 是 火
PostgreSQL 相 羔 文 章
PostgreSQL 新 版 本 就 一 定 好 ﹣﹣ 由 培 汝 現 象 比 我 做 的 奕 虢
固
口 透 我 PC Freezing Boom 近 的 一 般 的 那 仁 同 字 ， 芊 帖 給 你 ， 看 看 玆 欽 可 滿 愛
口 邦 邦 硬 的 PostgreSQL 技 本 千 崗 來 了 ， 怎 么 劭 恣 扒 展 PG 內 存 !
口 3 种 方 式 PG 大 版 本 升 級 接 甦 ， 莠 島 ， 不 甩 峪 以 客 戶 加 中 心 做 仁 品
口 ”PostgreSQL” 不 重 相 机 器 就 能 逮 整 shared buffer pool 的 原 理
口 透 我 PG Freezing Boom 逄 的 一 般 的 那 仁 同 學 考 帖 給 你 看 玆 次 可 滬 愛
一 人 IP 地 址 沙 同 覃 仃 PG 宋 例 ， 上 演 一 女 嫁 二 夫 ~ 的 炳 磅
口 PostgreSQL Hybrid 能 力 岔 非 小 趴 萊 敷 据 庠 可 比 ﹖
同 PostgreSQL 新 版 本 就 一 定 好 ﹣﹣ 由 培 列 現 象 水 我 做 的 宏 虢
旨 PostgreSQL ” 乩 彈 ” 尻 索 引 性 能 到 午 岑 优 化
口 PostgreSQL 天 服 劣 Neon and Aurora 新 技 木 下 的 新 細 洗 模 式 ( 翰 遊 ﹚
同 PostgreSQL 的 暇 角 古 旯 ” 的 參 敷 拇 一 拇
囤
PostgreSQL 遂 糊 复 制 槽 功 能
PostBreSQL 拍 盲 貼 常 用 的 些 控 分 析 腳 本
固
同 ”PostgreSQUˊ 高 性 能 主 仁 張 一 致 逵 雪 分 高 ， 我 行 ， 你 沒 為 !
同 PostgreSQL 滑 加 索 引 旱 致 崇 潰 ， 參 敷 醃 整 需 遽 慎 ﹣﹣ 文 查 未 必 客 全 覆 莖 城 景
同 PostgreSQL 的 搜 局 者 同 忠 了 ， 祖 玅 人 了 !
口 PostgreSQL SQL 优 化 用 兵 法 ， 优 化 后 提 高 140 倍 通 度
同 PostgreSQL 娜 維 的 雅 与 ” 雕 ” ﹣﹣ 上 海 PG 大 鈍 主 題 迅 景
同 PostgreSQL 什 念 都 能 存 ， 什 么 都 能 塞 ﹣﹣﹣ 你 能 成 熟 一 恆 吧 ﹖
同 PostgreSQL 延 移 用 戶 很 筒 弛 ﹣﹣﹣ 戒 看 你 的 好 義
同 PostgreSQL 用 戶 胡 作 非 刈 只 能 叔 著 ﹣﹣﹣ 警 告 他
同 金 世 界 都 在 ” 搞 ” PostgreSQL ， 尻 Oracle 得 到 一 仁 ” 懊 主 意 ” 升 始
同 PostgreSQL 加 索 引 系 統 OOM 怨 我 了 ﹣﹣﹣ 不 怨 你 怨 週
同 PostgreSQL ” 戒 怎 么 就 逄 人 敏 据 庠 都 不 吟 礎 ﹖”﹣﹣﹣ 你 妤 真 不 名 !
痛 毒 攻 宙 PostgreSQL 暴 力 破 解 系 統 ， 防 茄 加 固 系 統 方 索 ( 內 附 分 析 日 志 腳 本 ﹚
同 PostgreSQL 返 程 管 理 越 來 越 筍 弓 ，6 代 自 劫 化 腳 本 午 胃 菜
同 PostgreSQL 稀 定 性 平 台 PG 中 文 社 匡 大 吟 ﹣﹣ 杭 州 來 去 匆 匆
同 PostgreSQL 如 何 娜 玅 工 具 來 分 析 PG 內 存 泄 露
同 PostgreSQL 分 組 查 尚 可 以 不 迸 行 全 表 拍 描 吧 ﹖ 適 度 提 高 上 千 倍 ﹖
POSTGRESQL ﹣﹣Austindatabaes 庈 年 文 章 整 理
PostgreSQL 查 泱 透 句 升 岑 雰 不 好 是 必 然 ， 不 是 PG 的 島
同 PostgreSQL 安 符 集 口 芯 旱 致 數 据 查 洶 排 序 的 同 題 ， 与 MySQL 程 定 ”PG 不 程 定 ”
同 PostgreSQL Patroni 3﹒0 新 功 能 規 划 2023 年 紐 約 PG 大 吳 ( 音 迷 ﹚
同 PostgreSQL ﹍ 玩 PG 我 仗 是 圣 真 的 ，vacuum 穗 定 性 平 台 我 仗 有 了
同 PostgreSQL DBA 硬 扛 垃 圾 ” 井 岑 ”， ” 架 构 炤 ”， 港 用 PG 你 体 滾 出 ! ( 附 造 定 期 清 理 洽 接 腳
同 DBA 失 眺 旱 致 PostgreSQL 日 志 瘋 潁
同 玆 仁 PostgreSQL 比 戚 有 峇 本 找 老 板 要 端 腿 鵡 膇 !
口 一 人 IP 地 址 沙 同 兩 人 PC 宋 例 ， 上 演 ^ 一 女 嫁 二 夫 ” 的 焦 磔
PostgreSQL ^ 乩 彈 ” 今 索 引 性 能 到 午 岑 优 化
MySQL 相 羔 文 章
口 那 介 MySQL 大 事 劣 比 住 穗 定 ， 主 尼 延 返 低 ， 功 什 公 ﹖ Look my eyes! 因 加 宋 利 兵 宋 老 為
史 MySQL 終 件 下 推 丐 排 序 优 化 宏 例 ﹣﹣MySQL8﹒035
口 青 春 的 12 忱 ，MySQL 30 年 愚 溫 有 你 ， 再 儿 ! ( 洪 ﹚
口 MySQL 8 SQL 优 化 覃 券 ~ 常 見 回 題
同 MySQL SQL 优 化 快 速 定 位 索 例 丐 优 化 思 雕 旱 囡
”DBA 是 仄 der” 吵 出 MySQL 主 糅 同 題 多 种 解 決 方 案
同 MySQL 怎 么 巡 自 己 更 高 級 ﹣﹣﹣ 仁 內 存 表 混 到 了 升 岑 方 式
同 MySQL timeout 參 敷 可 以 水 事 劣 不 宛 全 回 滾
同 MySQL 社 你 延 用 5﹒7 出 事 了 吧 ， 用 著 用 著 5﹒7 崩 了
日 MySQL 的 SQL 引 擎 很 華 吵 ﹖ 由 一 仁 同 孝 提 出 同 題 引 出 的 奕 號
用 MySql 不 是 MySQL， 不 用 MySQL 都 是 MySQL 橫 批 哼 唏 哈 哈 啊 啕
同 MYSQL ﹣﹣Austindatabases 庈 年 文 章 合 集
同 超 張 外 指 迄 MySQL 再 次 災 盛 ， 囤 內 神 秘 組 紉 捧 教 MySQL 行 劾
MySQL 柬 件 下 推 与 排 序 优 化 宏 例 ﹣﹣MAySQL8﹒035
固
a
帕 明 工 近 進 系 列
同 汾 有 進 是 垠 掉 的 一 代 ﹣﹣iD 第 四 屆 OceanBase 敏 据 庠 大 賽
同 ETL 行 軍 也 慟 卵 ， 云 化 ETL，ETL 政 件 不 玅 了
SQL SERVEB 紫 列
口 泡 海 要 ，《SQL SERVEB 建 維 之 道 》， 清 口 笑 ， 竟 惹 寂 寥
同 SQL SERVEB 維 保 Al 化 ， 六 一 段 小 故 事 午 始
向 SQL SERVEB 如 何 宋 現 UNDO REDO 和 PostgreSQL 有 近 紙 芙 系 吵
同 SQL SEBVEB 危 隘 中 ， 椋 題 不 巡 岑 ， 迸 入 看 洋 情 ( 活 ﹚
同 未 知 黑 客 通 玅 SQL SERVER 窗 取 佞 弗 SAP 核 心 欽 据 ， 影 咬 企 不 沛 菖
數 据 庠 优 化 紹 列
同 MongoDpB 查 洩 优 化 指 南 四 句 真 詞 ﹍ ( 查 洩 优 化 系 列 4﹚
MySQL SQL 优 化 指 南 SQL 四 句 真 言 ( 优 化 系 列 3﹚
口 SQL SERVEB SQL 优 化 指 南 四 句 真 詞 ﹍(SQL 优 化 系 列 2﹚
口 PostgreSQL SQL 侄 化 指 南 四 句 真 言 (SQL 优 化 系 列 1﹚
泊 淵
史 仇 Universal 珈 球 影 城 到 囧 仁 敷 据 庠 公 品 菖 箬 ﹣﹣ 蛇 唄 灼 口 嘴
同 Al 很 聯 明 ， 但 就 怕 腩 子 失 忙 ， 汐 忱 向 A 很 重 要
仇 某 數 据 庠 信 任 《 危 杋 ﹖ ， 箬 淡 危 杋 公 夾
史 數 据 庠 信 刨 适 題 能 碓 哎 ﹖ 今 天 立 肱 透 浙
企 志 出 海 數 据 庠 妣 汀 同 題 一 角 ， 丐 政 策 劼 萵 下 的 全 球 數 捰 庠 公 品
同 汀 向 題 一 角 ， 与 政 策 努 蕩 下 的 全 球 敷 据 庠 仁 品
同 《 數 据 庠 江 湖 那 修 [ 刁 派 ﹕ 心 法 五 式 全 解 》
口 徵 敏 劭 手 了 ， 聒 合 OpenAl ﹢ Azure 云 扭 夷 Al 服 劣 市 塔
口 企 軍 出 海 ^DB/ 要 合 規 ， 要 不 拵 那 資 毬 都 不 惕 賣 的
同 短 述 國 仁 敷 据 庠 菖 筱 市 城 ^ 回 題 ^
口 DBA 被 瞧 不 起 你 有 什 念 建 沒 ﹖ Drive Fast !
日 HyBrid Search 宏 現 价 值 落 地 ， 尻 真 宣 企 心 的 需 求 角 度 分 析 ! 不 只 淡 技 木 !
日 尻 ” 小 偷 / 午 始 ， 不 金 仁 / 強 盜 / 結 束 ﹣ IvorySQL 2025 PostgreSQL 生 恣 大 心
同 被 弱 后 的 文 字 ﹣﹣ 技 木 人 不 脫 离 思 維 困 局 ， 笠 局 是 人 ” 死 ” ﹖ ! …
日 代 群 2025 上 半 年 性 結 ，OB、PolarDB， DBdoctor、 愛 可 生 、pigsty、osyun 、 工 作 岑 位 等
日 卷 呀 卷 ，Hybrid 混 合 查 逆 孛 分 ﹣﹣ 哪 仁 庠 是 小 趴 菜
早 今 MySQL 不 行 了 ， 到 乙 方 DBA 給 狗 ， 狗 都 不 千 ﹖ 我 千 呀 !
sF
DBA 十 不 好 容 易 蹦 牢 房 ﹣﹣ 率 事 你 知 道 咩 ﹖
口 5SQL SERVER 2025 岐 布 了 ， China 幸 二 有 信 仆 !
同 云 數 据 庠 厂 商 除 了 卷 扳 本 ， 下 一 仁 防 段 汶 可 以 卷 什 么 ﹖
口 刪 隊 敷 据 ” 八 屏 屏 / 之 鴞 」 英 豪 ﹣﹣ 我 去 ﹣BigData !
同 亦 了 3750 上 孖 的 我 ， 在 2000 字 的 OB 白 皮 帆 上 了 一 進 ﹣﹣《OceanBase 社 匡 版 在 泛 互 基 景 的
底 用 案 例 研 究 》
E SQLSHIFT 是 愛 可 生 灰 OB 的 雪 中 送 炭 !
一
青 春 的 列 忒 ，MySQL 30 年 威 遜 有 你 ， 再 儿 ! ( 連 ﹚
同 老 空 人 做 的 敷 掘 庠 宁 品 ， 好 像 也 不 ^ 老 空 ” !
同 瘋 狂 老 DBA 和 年 粒 / 罪 紅 ” 程 序 呂 ﹣ 火 星 撞 地 球 ﹣﹣ 凌 也 不 是 您 岱
同 哈 呣 站 ，OB 厂 州 升 岑 者 大 鈍 之 ^ 五 ” 眼 聚 盧
iuaustin3
作 者 提 沙 ﹕ 人 人 官 恆 ， 作 供 參 考

