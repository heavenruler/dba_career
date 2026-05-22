#!/usr/bin/env bash
# todo.sh — LLM filter execution queue (auto-generated)
# Generated: 2026-05-22 16:11
#
# Inventory (snapshot at generation):
#   Total extracted docs : 897
#   Already filtered     : 76  (auto-skipped)
#   Pending              : 821
#   Total char (trunc to 60000): 8,173,501
#   Est. tokens          : ~10.6M
#   Est. 5h windows      : 9  (~45h wall-clock)
#
# Ordering: char_count desc (longest docs first — most noise to remove = highest filter value)
#
# Usage:
#   ./todo.sh                # run sequentially, idempotent (skip already-filtered)
#   ./todo.sh --dry-run      # show what would run, do not execute
#   Ctrl-C                   # stop; re-run later to resume from where you left off
#
# Behavior:
#   - Per-doc failure → logged to filter_failed.log, continues on next doc
#   - All progress → filter_progress.log
#   - Each completed doc appended to .todo.state ("<doc_id> <ISO timestamp>")
#   - Skip logic = (.todo.state has doc_id) OR (generated/filtered/<doc>/knowledge.json exists)
#   - Codex 5h window 額度滿時，filter_doc 會失敗 → 全部 log 起來；隔一個 window 再跑
#
# Regenerate after adding new PDFs:
#   make todo            # 單獨重生 todo.sh
#   make sync            # extract + OCR + chunks + audit + regen todo

set -o pipefail   # 讓 `make ... | tee` 抓得到 make 的 exit code
# 不用 set -u：bash 3.x/4.x 對空 associative array 的處理不一致，會誤觸發 unbound
cd "$(dirname "$0")"

DRY_RUN=0
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=1

LOG=filter_progress.log
FAILED_LOG=filter_failed.log
STATE_FILE=.todo.state
mkdir -p generated/filtered
touch "$STATE_FILE"

# Ctrl-C / kill 時清掉子程序（make filter_doc / python / codex），不留孤兒
cleanup() {
  echo
  echo "[todo.sh] interrupted, stopping current filter..."
  pkill -P $$ 2>/dev/null || true
  pkill -f "scripts/filter_doc.py" 2>/dev/null || true
  pkill -f "codex exec --cd.*KnowledgeBase" 2>/dev/null || true
  echo "[todo.sh] stopped. Progress saved in .todo.state. Re-run to resume."
  exit 130
}
trap cleanup INT TERM

# Build "done" set from state file (key=doc_id, value=1)
declare -A DONE_SET
while IFS=' ' read -r doc rest; do
  [[ -n "$doc" ]] && DONE_SET["$doc"]=1
done < "$STATE_FILE"

date '+%Y-%m-%d %H:%M:%S [todo.sh] start' | tee -a "$LOG"
echo "[todo.sh] state file has ${#DONE_SET[@]} previously-marked docs" | tee -a "$LOG"

DOCS=(
  # === window 1/9 (1-100, avg 21461 chars/doc) ===
  08bdb13c0f6e56c65e34f257e2361501  #  25710c  developer.aliyun.com      MySQL性能监控全掌握，快来get关键指标及采集方法！-阿里云开发者社区
  83bd3cfd4b71fc8fb1ebfbc9cc02eb91  #  25661c  zhuanlan.zhihu.com        (2 封私信) Redis LRU 算法和LFU算法 - 知乎
  c7fe39393f4a540c8962e2a8d7ef3ebe  #  25661c  developer.aliyun.com      MySQL数据库审计采集技术调研之Packetbeat，eBPF-阿里云开发者社区
  c5a76aae24d9e59bbb652f3cac0f0373  #  25623c  www.modb.pro              Oracle Database 23ai 体验 - 墨天轮
  195a316902e2c6ebcb72754be0fec3b2  #  25493c  mp.weixin.qq.com          图灵奖数据库大师Stonebraker师徒对数据库近20年发展与展望的2万字论文
  6a5506a915d6ff1834b919009678a30f  #  25486c  mp.weixin.qq.com          携程面试：100 亿分库分表 如何设计？ 核弹级 16字真经， 让面试官彻底 “沦陷”，当场发off
  afecd65684d2f2a9566d8d83211a72e9  #  25408c  github.com                dragonflydb/dragonfly: A modern replacement for Re
  2669ad45cecf54d617286f26b3add8cf  #  25297c  cloud.tencent.com         MySQL为什么'错误'选择代价更大的索引-腾讯云开发者社区-腾讯云
  54711fcb27d9bfcc2ddd6a778b3b5ac9  #  25243c  www.modb.pro              MySQL8.0.40 MGR集群安装部署及管理 - 墨天轮
  32e1c4ac785a9c814df4739817f6ef6e  #  25148c  www.modb.pro              oracle awr 报告详解 - 墨天轮
  63e7f4a398c3412bd0e46e04761ec0f0  #  25039c  mp.weixin.qq.com          MySQL数据库常用的41个脚本，速来下载！
  ab87bac92f55d2e012d82cbf529154f5  #  24991c  github.blog               Upgrading GitHub.com to MySQL 8.0 - The GitHub Blo
  7323232c21b1301c822fd40679b9c46b  #  24951c  mp.weixin.qq.com          字节二面：为何还执着传统数据复制，零拷贝它不香吗？
  7e04df7e492af937f3db7351c4bd43b8  #  24874c  www.percona.com           Using Blue/Green Deployment For (near) Zero-Downti
  add7e8f0135831a046531de5ef1ef67b  #  24865c  mp.weixin.qq.com          五年沉淀，微信全平台终端数据库WCDB迎来重大升级！
  2521eca551359e30b8f64337d32bfc87  #  24735c  cloud.tencent.com         重现一条简单SQL的优化过程-腾讯云开发者社区-腾讯云
  58533fe1f1c6095cb0e2f3955e58159b  #  24724c  juejin.cn                 从源码分析，MySQL优化器如何估算SQL语句的访问行数本文将从源码角度分析SQL优化器代价估算的基
  fad7c38e3934be3d1ec05e72c73c16b7  #  24494c  www.modb.pro              Redis 内存突增时，如何定量分析其内存使用情况 - 墨天轮
  c6d772c8efb21f71e0ac6c7c4556c7c8  #  24375c  www.modb.pro              2025 年宣布一件大事，Oracle 一键安装脚本开源了！ - 墨天轮
  092ce3de80a63a589d6aa18c2a35a3b7  #  24237c  engineering.fb.com        Migrating Facebook to MySQL 8.0 - Engineering at M
  e4e533ce546996f92a85b8a5e760ae1b  #  24121c  mp.weixin.qq.com          MySQL 8.0 OCP 1Z0-908 考试题解析指南
  8e431cf3f342da1daa965db08504102f  #  24012c  www.infoworld.com         How a new database architecture supports scale and
  65345b7d3cd1b42a7c2fc5184097e77b  #  23991c  mp.weixin.qq.com          对 MySQL MGR 双机房双活架构的可行性验证（附 Cursor 脚本）
  7378df9b8ce83824af3650aa7ffbd7e0  #  23925c  juejin.cn                 分布式系统幂等性详解：从理论到落地的完整指南
  bc19303cf196e66d02df8b299abd8a1a  #  23878c  mp.weixin.qq.com          万字总结：腾讯会议后台告警治理实践——如何才能避免“事后诸葛亮”
  92db090625bfc7b86caa1cf54d6814d2  #  23771c  medium.com                Terraform — Best Practices. Best practices for usi
  7bff90a70d31863b2836c1fa9e5c903e  #  23703c  www.modb.pro              MySQL性能分析的“秘密武器”，深度剖析SQL问题 - 墨天轮
  363b358097044d3da294ef6278ba6340  #  23556c  mp.weixin.qq.com          不懂 无锁队列，别说你懂高并发底层原理
  4161c619d44a078a2cbebea93dd7a452  #  23522c  www.modb.pro              MySQL 优化利器 SHOW PROFILE 的实现原理 - 墨天轮
  8b3b99d613c2bf75e4779522b9170476  #  23466c  www.modb.pro              深度解析MySQL的半连接转换
  373cccfc80aaa90e9d52e29d6c2befba  #  23438c  mp.weixin.qq.com          99线怎么算？99线、90线 你们 盯哪根？
  3eb79c4afbd0fc2c42133f9d0b606de1  #  23414c  www.modb.pro              MySQL突然崩溃？教你用gdb解剖core文件，快速锁定“元凶”! - 墨天轮
  dd80518a03cc67779a0c876376ccb05b  #  23265c  www.modb.pro              轻松上手：使用 Docker Compose 部署 TiDB 的简易指南 - 墨天轮
  e70189e2613b25fdc54c24dd0bacdaf2  #  23220c  zhuanlan.zhihu.com        十年后数据库还是不敢拥抱NUMA？ - 知乎
  868c71eb7e985d733eda69dde101d31b  #  23184c  mp.weixin.qq.com          刚升级到MySQL8.0就凉凉，是时候准备再次重启升级了
  09e74f0a28f3954c6ffca5acac1d6de0  #  23052c  www.modb.pro              [MYSQL] 忘记root密码时, 不需要重启也能强制修改了! - 墨天轮
  f08a253aedb8ac4520ff1c7255c419dd  #  22871c  mp.weixin.qq.com          阿里面崩：听说Redis Pipeline能提升3-12倍性能 ？怎么实现的?我懵逼了。 6抡暴击,
  fabc880add2352bb94926c7d4ce0eb7d  #  22662c  juejin.cn                 MySQL运维MySQL运维 创建健壮的MySQL健康检查Python类 在本文中，我们将介绍如何创
  9b34444b962ceaf7a53426a01d11698e  #  22630c  juejin.cn                 从MySQL迁移到PostgreSQL经验总结最近一两周在做从MySQL迁移到PostgreSQL的
  b0b7db4bb8f74dbe80c088d52dd5fa55  #  22501c  mp.weixin.qq.com          架构师必备10大接口性能优化秘技，条条经典！
  0044dc5ad4496e51b7de50f10b0273fa  #  21996c  blog.csdn.net             云原生可观测领域的半壁江山，这次被 Grafana 和 Cilium 给拿下了-CSDN博客
  c600b512bfaa0d325fedfe7742fb0b23  #  21839c  mp.weixin.qq.com          大规模数据同步后源端与目标端数据总条数对不上的系统性解决方案
  38e33dbdc635c5230643e3801cf0cef9  #  21665c  www.modb.pro              Ubuntu上的MySQL 8.4.5安装：一行命令背后的系统级操作实录 | 不只是apt inst
  35a02820f97270a198956b1d664bb548  #  21548c  www.modb.pro              60分钟部署 Oracle 26ai RAC
  6962faaf603def99caf469a99c3fef6e  #  21515c  www.modb.pro              mysql mgr参数调优与最佳实践
  9793d273762077412ec1100458f4fee7  #  21443c  cloud.tencent.com         [MySQL FAQ]系列 — MySQL复制中slave延迟监控-腾讯云开发者社区-腾讯云
  e6737cbc96da2ff050b837cf2d0e665f  #  21433c  mp.weixin.qq.com          MySQL 是怎么做并发控制的？
  5365303245a29ae0ea2c52c43d15b854  #  21366c  mp.weixin.qq.com          京东面试：15wQPS 下 20%连接失败、5%长尾延迟，如何解决？
  a2a836ba5c143aacb484b095326efb8c  #  21254c  mysql.taobao.org          聊聊数据库跨地域
  a85522ecb488168b0df0394577ff026b  #  20995c  blog.51cto.com            一次“诡异”的 Ansible 密码问题排查，最后的“真相”竟是这样_LinkSLA智能运维管家的技
  ddb97d6b1a194b933b5d700d03dc362b  #  20925c  mp.weixin.qq.com          MySQL2PG v3.4.0 正式发布：支持 MySQL 5.7+ 完整评估和迁移报告的数据库迁移
  d767729aa8c1ba344a005fd2c957e3a0  #  20892c  blog.pichuang.com.tw      選擇 IaC 工具是多選題，而不是單選題 - 魂系架構 Phil's Workspace
  0756a3aeba95614e8f995f77620e9a24  #  20741c  www.modb.pro              TiDB 学习之路从部署开始 - 墨天轮
  5cf669dc724cc9b8f13dc47ad1c764dd  #  20739c  mp.weixin.qq.com          一文详解架构设计的本质
  8704c7ff9b9fa201451e5d17e8e1c243  #  20686c  juejin.cn                 架构师之道：架构演变史：从建筑学到架构设计“Arkitekton”直译为“主建筑师”，揭示了“架构”
  aa5eda94ae1f55aaf2e53ca0bef8e683  #  20662c  www.modb.pro              MySQL高阶调优，一文让你从入门到精通！ - 墨天轮
  65c5f6a8dcc99c54543b28bda6809b6e  #  20512c  www.modb.pro              从Oracle走向更广阔的世界：我的MySQL/PostgreSQL并发设计学习笔记
  897240cbe8f970062e4b51aa9a925826  #  20497c  mp.weixin.qq.com          MySQL 8.0 INSTANT DDL 算法原理简析
  de0b10ad6a3933d4997a21c64f7947d7  #  20290c  juejin.cn                 Raft一致性算法Raft算法是分布式存储比较常用的一致性算法之一，本文主要还是按照论文顺序来拆分讲
  8f248675052975f863e75b5d853d4076  #  20287c  www.cnblogs.com           高性能场景为什么推荐使用PostgreSQL，而非MySQL?
  798bbffe8d7f44758e997a633940616f  #  20251c  cn.pingcap.com            TiDB 7.4 发版：正式兼容 MySQL 8.0 | PingCAP 平凯星辰
  801ad604fe510fdd79c023b9c99aa7df  #  20133c  www.modb.pro              mysql自适应哈希索引（AHI）,40%性能提升，为何有人却选择关闭？
  a51447dc0d71de23310cfd2502e4c740  #  20067c  mp.weixin.qq.com          用错nacos 损失1.7亿美金，教训惨痛。 一个 骇人听闻的 P0级故障 复盘（2）
  3e4d8db847142e8a85459e10b6868641  #  19914c  www.modb.pro              怎样保持MySQL Performance Schema的性能开销在可控范围内？--深度解析PFS对
  316046afa4a8a6b4d16334018c69e804  #  19822c  github.com                myhhub/stock: stock股票.获取股票数据,计算股票指标,筹码分布,识别股票形态,综合
  8b12c380d76b70ee02aeec4ff21f3d63  #  19643c  juejin.cn                 知乎 PB 级别 TiDB 数据库在线迁移实践导读 本文由知乎数据库负责人代晓磊老师老师撰写，全面介
  749b755e560d76f0bc0411393ba9573c  #  19641c  mp.weixin.qq.com          B站前端错误监控实践
  a83040219e29aee212c16a1479831a52  #  19589c  mp.weixin.qq.com          从一个事故中理解Redis（几乎）所有知识点
  c878673f99e69883937d54a6b5b740df  #  19586c  juejin.cn                 【建议收藏】7000+字的TIDB保姆级简介，你见过吗## TIDB简介 ![Database of
  3cf2f16b5ce48c00b76497ffe86cb55f  #  19558c  mysql.taobao.org          浅析Xtrabackup备份工具
  e41eacaaad9129ff0d437bf1ff5abdbe  #  19513c  juejin.cn                 Github Action 是什么？能干什么？怎么做到的？如何开发一个action通过这篇文章简单讲
  57a54890436038bbdcc3abcd130d9785  #  19477c  my.oschina.net            可观测性与传统监控的区别和联系 - OSCHINA - 中文开源技术交流社区
  6ae9da3549283979aa62066b97ba2a96  #  19324c  www.modb.pro              NineData 社区版：从 MySQL 到 TiDB 数据复制新选择 - 墨天轮
  a1ad0e0cf7ca5cfc9f42bb71aa30ef02  #  19308c  mp.weixin.qq.com          你的数据库在摸鱼吗？SHOW ENGINE INNODB STATUS 教你抓个正着
  b9baf5df840c23c5921f322b1d662874  #  19255c  mp.weixin.qq.com          缓存有大key?你得知道的一些手段
  27ee62e48490adce210c13eb3c0a9c63  #  19226c  www.51cto.com             Redis Sentinel-深入浅出原理和实战-redis实战 pdf
  d1599c75c0446a7645889953a54ed234  #  19007c  www.modb.pro              [MYSQL] mysql数据加密原理和解析 - 墨天轮
  ff147dc2b8a767234da1c5501f270cf2  #  18977c  mp.weixin.qq.com          SQL查询优化：为什么“先聚合再JOIN”更高效？
  fd6dead109635f62ce365e007efaeda7  #  18923c  www.modb.pro              CentOS 7.9部署MySQL 8.4.3 LTS保姆级手册 - 墨天轮
  f7a8df8b89aff3049775b4d17e41f7a7  #  18895c  www.modb.pro              sql调优实战：分页语句中你真的了解count stokey吗？sort order by的存在就一
  2ac31a1732680e72a16f3f3c2b711d09  #  18894c  juejin.cn                 人人都是架构师-清晰架构 | 京东物流技术团队前言 了解清晰架构之前需要大家先熟悉以下常见架构方案：
  1764f90c573a90e5562b3b781ab886db  #  18860c  mp.weixin.qq.com          关于“稳定性建设”的一些思考
  9b85d8a7fc8e89c6fd28c45d4d15b9e1  #  18490c  mariadb.com               The Optimizer Cost Model from MariaDB 11.0 | Maria
  5a12b61dad7853075f20eae390ee29c2  #  18450c  cn.pingcap.com            如何在 TiDB 上高效运行序列号生成服务 | PingCAP 平凯星辰
  cf51ea429c1967586f9582bb182a15d9  #  18443c  www.modb.pro              基于 MySQL 8.0 细粒度授权：单独授予 KILL 权限的优雅解决方案 - 墨天轮
  156269ef29fe4a830a34022ba79f9974  #  18430c  cn.pingcap.com            TiDB 的列式存储引擎是如何实现的？ | PingCAP 平凯星辰
  a2eba635f7a208fceb4b1753c6184b17  #  18338c  www.modb.pro              PG vs MySQL mvcc机制实现的异同 - 墨天轮
  3fd8b956d4a659320637c2cfc220963b  #  18305c  www.modb.pro              CentOS-Stream9 上安装 Postgresql 17 from Source Code 
  a9a60ad1c59a3164d8db894b6d3f6c6f  #  18248c  mp.weixin.qq.com          InnoDB 让 MySQL 流行，DuckDB 使其伟大
  c51099813fdf00efdcac4c2423542dcc  #  18158c  www.modb.pro              MySQL 参数核心优化指导
  2e87ddfff75380625588a9e56566fd56  #  18101c  juejin.cn                 如何高效实现缓存预热？一文了解九大方法 什么是缓存预热 缓存预热是一种在系统启动或运行过程中，提前加
  813c74ea2eee6595f183870c6c05af83  #  18085c  cloud.tencent.com         xtrabackup 8.0如何恢复单表-腾讯云开发者社区-腾讯云
  3ce26dec621f56b972282463c68c3417  #  18072c  www.51cto.com             为什么说MySQL单表行数不要超过2000w?-mysql 查询表行数
  b6969167c3b02f8ec30f7728da29dfd3  #  18048c  www.modb.pro              MySQL DBA请注意 不要被Sleep会话蒙蔽了双眼
  13802f213af712dae47aa9d1df634b54  #  18040c  www.modb.pro              在MongoDB建模1对N关系的基本方法 - 墨天轮
  4210c288c9a0ab0b576a21322ded5cf7  #  17945c  juejin.cn                 复杂SQL治理实践 | 京东物流技术团队一、前言 软件在持续的开发和维护过程中，会不断添加新功能和修
  c057781ef0c7e0873c7f9a43cadca7b5  #  17928c  www.modb.pro              MySQL 8.4 新特性深度解析：功能增强、废弃项与移除项全指南 - 墨天轮
  d7fe63bdf2283b3983577c28e356c225  #  17915c  mp.weixin.qq.com          美团面试： ‘异地多活’ 都不用 ， 你们 项目 怎么实现 高可用呢？
  5e700227287ae6f14ad8d3a305c804ab  #  17885c  blog.csdn.net             MySql优化（三）详细解读InnoDB存储引擎_my.cnf innodb-read-io-thr
  90b30a59a13f8100785328229e12c2f4  #  17879c  github.com                microsoft/garnet: Garnet is a remote cache-store f
  # === window 2/9 (101-200, avg 15771 chars/doc) ===
  f7f8b48dba959823223bde33edbe760d  #  17841c  juejin.cn                 53 倍性能提升！TiDB 全局索引如何优化分区表查询？本文将详细介绍 TiDB 全局索引的工作原理
  0677cdea45b5e1bbdaf50d1c4afded76  #  17818c  mp.weixin.qq.com          35 张图带你了解 Oracle AI Database 26ai 技术架构(上)
  b7fb2cf132e9b86c3637ef3e3767376b  #  17804c  www.modb.pro              技术分享 | 数据库产品选型测试 集中式与分布式 - 墨天轮
  cf063b6e344bb94de337aa8099ec0765  #  17767c  mp.weixin.qq.com          MySQL内存问题分析利器--Jemalloc
  938ec8b854beade0cca15aaaba177790  #  17748c  mp.weixin.qq.com          京东面试：mysql深度分页 严重影响性能？根本原因是什么？如何优化？
  94fb63fc6db6864ca91e18cbbe282906  #  17709c  thenewstack.io            Database Scalability and the Giant Flea: A Lesson 
  8366ac8078d401444ca48174d32e1197  #  17670c  juejin.cn                 网易互娱的数据库选型和 TiDB 应用实践计费组是为网易互娱产品提供统一登录和支付高效解决方案的公共
  ac58ca0b42a9832dd7b708c2c7f5a566  #  17559c  www.modb.pro              TiDB x DeepSeek 打造更好用的国产知识库问答系统解决方案 - 墨天轮
  0f81bb5e9e927269f46f5dfa3b2bcbea  #  17479c  www.modb.pro              性能运维 -- 借助pstack + strace排查SQL性能问题 - 墨天轮
  cfd2624b5bcccd703547d420ed4ca6c1  #  17470c  juejin.cn                 架构师之道：介绍了那么多，技术中架构到底什么？通过前面的介绍，我们对架构的历史脉络有了一些基本的认识
  5f3d079a8a599f1c3f17644b42d1059d  #  17316c  www.modb.pro              运维实践｜浅谈explain的使用 - 墨天轮
  dc37e86fabf6151f7244030e5ad0f71f  #  17300c  www.modb.pro              MySQL8.0参数配置不生效问题排查诊断 - 墨天轮
  9d47bfaf531d843cf867b96aee9bb846  #  17242c  juejin.cn                 货拉拉离线大数据迁移-验数篇
  c5f0e561e700c1ccba0c1fa2ba7ab330  #  17225c  mp.weixin.qq.com          这些年背过的面试题——MySQL篇
  562b8a33a3d8c8e2348279008e454053  #  17175c  mp.weixin.qq.com          腾讯二面：1.2 亿级大表, 如何 加索引？
  d9fbca86cb98208a0740cd496378dab5  #  17163c  www.yunweipai.com         Kubernetes集群成本优化:我是如何用3个月省下公司60%云账单的
  d8fe534bcb7c4945ecc285d3f14d044e  #  17141c  www.modb.pro              MySQL运维实践｜稀里糊涂的解决了MySQL子账号过期、密钥问题 - 墨天轮
  93780619a420a021f8a62310bf13318e  #  17108c  www.modb.pro              打破认知幻像：你写的SQL是否如你心意？ - 墨天轮
  bfd730f8429ec1986a03f22dc2fa7a46  #  17083c  tech.meituan.com          MySQL自治平台建设的内核原理及实践（下）
  9164b6b01c752abcc65ef034a1368be8  #  17076c  mp.weixin.qq.com          P0级故障：头部电商双11大促 全链路故障损失超1.2亿，竟然是 Eureka 雪崩。骇人听闻的P0
  62f94a5713ff62a9daed28d8d820eb8a  #  16957c  www.modb.pro              MySQL 密码防暴力破解插件：Connection Control
  0e1e0313ecb9fbd59e27a609cef0705f  #  16897c  juejin.cn                 MySQL的默认隔离级别为什么是RR，而不是RCMySQL 的默认隔离级别为什么是 RR，而不是 R
  02005b363a530bfca0b776f7a0ccd481  #  16891c  mp.weixin.qq.com          B 站轻量级容灾演练体系构建与业务实践
  2f0189726bba86fd958eb14e09388674  #  16876c  www.51cto.com             Redis 7.0 源码调试环境搭建与源码导读技巧-redis源码分析
  af6b995ef368286d525216dce480e634  #  16853c  juejin.cn                 你需要什么样的资源隔离？丨TiDB 资源隔离最佳实践本文以实际案例为切入点，详细解读了 Placem
  53834403bd0eb43fa85470bd5d81809d  #  16845c  www.infoq.cn              像架构师一样去思考_架构_InfoQ精选文章
  5b7666c86b5b31b53878096412a71aa2  #  16766c  juejin.cn                 我说MySQL每张表最好不超过2000万数据，面试官让我回去等通知？面试官：麻烦你好好看看这篇文章
  3608af8780e5810dea74d054e452b709  #  16644c  mp.weixin.qq.com          MySQL 30 周年庆！MySQL 企业版已开放下载！
  2c5c534818a5d59287014c32c39219cd  #  16528c  juejin.cn                 一次线上脑裂故障让我彻底搞懂了Redis集群原理这又是一个线上大规模故障引发的案例，而且居然是罕见的
  001569921a9bb9ed2b9b5384beec7bbe  #  16469c  www.modb.pro              MySQL8.0统计信息总结 - 墨天轮
  8192be1d3dc64e250a40e06f8fcbb6cd  #  16448c  mp.weixin.qq.com          作业帮多云架构下的数据库集群解决方案，实现资源隔离、快速响应
  e3177aa0c78f29ff04351a044e709e05  #  16398c  mp.weixin.qq.com          破解gh-ost变更导致MySQL表膨胀之谜｜得物技术
  26c7b841d9c64290bf8f23d5052f45be  #  16385c  tech.meituan.com          MySQL自治平台建设的内核原理及实践（上）
  d13e12a68a7744bac4a4c20663d079a4  #  16350c  juejin.cn                 针不戳！GitHub Actions 入坑指南什么是 GitHub Actions？ 相信关注技术前
  5db25a77c7a120bb8ea0b1b1bf9ad498  #  16340c  mp.weixin.qq.com          PostgreSQL 18 核心新特性解析
  4d4e43e93df75d3901a0b69ae02e0960  #  16287c  www.modb.pro              别再手动编译了：Docker Compose 容器化部署 RabbitMQ
  1d98657cac48cb47af146f250f965e3b  #  16236c  juejin.cn                 别再纠结线程池池大小、线程数量了，哪有什么固定公式 | 京东云技术团队可能很多人都看到过一个线程数设
  13de9bafc7f57700887118dc971f3b70  #  16217c  www.modb.pro              SQL语句Cost花费判断 - 墨天轮
  c92d31dbd1b551149cf863cce4ccd1d5  #  16179c  cloud.tencent.com         同城容灾+异地多活是全球化容灾处理的最好模式吗？
  8e61ea932eead7717bffe5e2796f001a  #  16094c  cloud.tencent.com         如何阅读MySQL死锁日志-腾讯云开发者社区-腾讯云
  13c919cde6178d6e6bbf2bcaa88f6cd4  #  16069c  juejin.cn                 Docker部署MySQL、Redis、Kafka、ES、KibanaDocker Docker的基
  3e173690a95f3a280107fad07829a712  #  16069c  ithelp.ithome.com.tw      可觀測性宇宙的第一天 - Grafana LGTM 全家桶的起點 - iT 邦幫忙::一起幫忙解決難
  7506a36633e3bc12944c670f6319ebd6  #  16046c  mysql.taobao.org          数据库内核月报
  ef62f06e66fcf9730ad9361a0cacd20b  #  16034c  www.infoq.cn              你的架构决策记录是否失去了它的目的？_业务架构_InfoQ精选文章
  78aebc04d946bc99a8428426dfdc8163  #  15944c  tech.meituan.com          业务数据治理体系化思考与实践 - 美团技术团队
  371e949e7e669478182b96cd8012ef2f  #  15925c  medium.com                How We Optimize RocksDB in TiKV — Write Batch Opti
  359626bc5641e31d9fe81b2ac8e446bd  #  15888c  medium.com                Software Architecture is Hard | by Oz Anani | Medi
  51c199aad1722448a7614d1775936198  #  15832c  juejin.cn                 Mysql JOIN 的高阶使用 在数据库操作中，JOIN 操作和 UNION 操作是数据关联与合并
  323dcd05c49a0ccdd23533064c92937d  #  15824c  blog.csdn.net             MongoDB 写安全(Write Concern)_writeconcern-CSDN博客
  1a4fa6e37f7eb683ca1f8496b00cb1f0  #  15823c  juejin.cn                 看完这篇，你的API服务设计能力将再次进化!本篇文章旨在探讨在遵循通用设计规范之外，服务设计过程中需
  1e5a96baa1b47abd695db96226e4d814  #  15647c  tech.meituan.com          基于代价的慢查询优化建议 - 美团技术团队
  d74fed5a0ea1396efe26284e1e7e0dc9  #  15623c  www.51cto.com             Redis 缓存击穿（失效）、缓存穿透、缓存雪崩怎么解决？-redis缓存穿透
  2f7d940a3a2e1635b70fe4d038d9e330  #  15623c  mp.weixin.qq.com          TiDB × AI ：DeepSeek 时代你需要什么样的数据基座
  50301f09e4569d3c389c6146db83bd10  #  15614c  mp.weixin.qq.com          一文搞懂 MySQL InnoDB架构 Buffer Pool、Change Buffer、自适应哈
  384e3ca8b05dbed3b6ca32222678ca7f  #  15493c  juejin.cn                 TiDB介绍及设计原理TiDB是一个支持海量数据存储的分布式数据库，TiDB需要解决分布式数据存储O
  f753b00c2c9516dd73315fb80c9c3371  #  15421c  www.yunweipai.com         MySQL慢查询治理：从索引优化到分布式数据库分库策略
  7d340f3f760b1d950f29747526397cbd  #  15414c  juejin.cn                 基于Prometheus、Thanos与Grafana的监控体系详解说明： Grafana通过Tha
  8b0dc82c8bc537b2bfadc1194f6dda77  #  15372c  www.infoq.cn              中小银行如何构建智能风控体系？明确业务需求比盲目求新更重要_银行_李忠良_InfoQ精选文章
  b5c82627ea7a00b7d09324820dd309ac  #  15295c  www.infoq.cn              爆发式增长业务的高可用架构优化之路_阿里巴巴_Xue Liang_InfoQ精选文章
  4504759312deaf01f04cd5a2d02c4b99  #  15277c  www.modb.pro              使用 MySQL Clone 插件为MGR集群添加节点
  66b76895904726f19c1fb184b1c8fc81  #  15233c  juejin.cn                 MySQL 的JSON类型违反第一范式吗？MySQL 在 5.7 版本中正式引入了原生的 JSON 
  4c72c06d793ff8b0156e5dde9d646324  #  15220c  docs.pingcap.com          使用 TiUP 部署 TiDB 集群 | TiDB 文档中心
  47eb1dc6abbb4d9c6c213ae7755adae2  #  15146c  mp.weixin.qq.com          微服务与分布式系统设计看这篇就够了！
  1102319937fa39dcd53a9a6f556fedde  #  15136c  juejin.cn                 分布式数据库的进度管理：TiDB 备份恢复工具 PiTR 的原理与实践导读 对于一款企业级数据库产品
  248ebbbf322172edf4bb297f0847fe80  #  15101c  mp.weixin.qq.com          【PG性能优化】索引驱动小范围替代大结果集物化
  29d246652c4541bbaad603d81d776f7a  #  15039c  mp.weixin.qq.com          CMDB数据建模哲学：从IBM、ServiceNow到Device42
  02fe4209332110a9ec9a5d79241dbaae  #  15030c  mp.weixin.qq.com          MySQL Drop Table 优化
  1e45d837b5e0443da7128142263f5a27  #  15026c  mp.weixin.qq.com          一、架构设计基础
  c6d910c00e0be92213b9cc93886ca326  #  14947c  mp.weixin.qq.com          高频面题： 你们线上 QPS 多少？你 怎么知道的？
  7a60dc31f53e71ff0b92421183087387  #  14935c  mp.weixin.qq.com          MySQL运行时的可观测性
  825f016a8bf6ec8012fbbcff9da759e6  #  14923c  www.modb.pro              PostgreSQL 17 主从部署、配置优化及备份脚本最佳实践 - 墨天轮
  6d3c6ad70423dbbbbf99c913a48efcf4  #  14891c  www.mydbops.com           Online DDL in TiDB
  fa11d8c9e87a9646e588e48bc28e7d1e  #  14888c  mp.weixin.qq.com          美团面试：MySQL为什么 不用 Docker部署？
  9ab508ea9d37ca7e68022a4d97c17d86  #  14887c  juejin.cn                 高性能无锁并发框架Disruptor，太强了！前言 Disruptor是一个开源框架，研发的初衷是为
  e5a322b63e6589f1fba641056b49008d  #  14817c  juejin.cn                 高性能！易用友好的开源实时监控系统！HertzBeat —— 一个易用友好的开源实时监控告警系统，无
  3aef6722b6a737086a27c76a4aab979f  #  14809c  juejin.cn                 MySQL中的SQL调优设计SQL调优有哪些基本原则？ 导致SQL查询效率比较低的原因,主要包括数据
  24d897b7785f2b5d7e54d6af153d3ac1  #  14748c  tech.meituan.com          提升资源利用率与保障服务质量，鱼与熊掌不可兼得？ - 美团技术团队
  8806df80070e0504041848adeb3d0e1b  #  14699c  mp.weixin.qq.com          主从报错GTID_MODE = ON cannot be set to ANONYMOUS
  435f356f18b2ed534f8aaf0c16c36944  #  14641c  www.infoq.cn              团队授权：分散化的架构决策
  02222d3b5e103580e0ba3e888fcb3677  #  14615c  www.modb.pro              PG vs MySQL 统计信息收集的异同 - 墨天轮
  e7a93957c877ec7aa35b668de07db479  #  14588c  www.infoq.cn              亚马逊 CTO 20 年架构经验之道：俭约架构师的七大黄金法则！_框架_Tina_InfoQ精选文章
  f778b8c05ca1e0e84bc5530fd59fe4eb  #  14575c  mp.weixin.qq.com          阿里面试：全年零P4级故障，你是怎么做到的？
  9e341feb75cec583e02f026c736f4ab6  #  14522c  www.modb.pro              Redis 调优：必须关注的几个参数
  1059aadb9ba78b94ac181ac7b2f82d3d  #  14509c  juejin.cn                 EXPLAIN TYPE 列的 JOIN 常见场景详解（上）专栏连载至此，相信读者们已经对一条 SQ
  8b115a54671c59a18b925c410d4f2566  #  14501c  www.modb.pro              mysql 信号量与进程状态
  cf1ebb026508e8330d132f7a7ae8799b  #  14421c  mp.weixin.qq.com          高性能MySQL到PostgreSQL异构数据库转换工具MySQL2PG
  f28a6b0b0c287d980d0e6455bef1aa33  #  14411c  www.infoq.cn              关于业务架构基础知识的二三事儿： 业务能力_业务架构_钰湚—付晓岩_InfoQ精选文章
  5f6455b1073443e92c1507c8d17a3872  #  14261c  juejin.cn                 DDD落地指南-架构师眼中的餐厅在去年、我整理了一篇名为《如何做架构设计？》的文章，主要探讨了架构设
  7760f6bf93ac47495e17db3da739d9d4  #  14229c  juejin.cn                 九. Redis 持久化-RDB(详细讲解说明，一个配置一个说明分析，步步讲解到位)九. Redis
  58c1dbeba8e91e42b491ec2aa92ca656  #  14229c  www.infoq.cn              数据规模超 1PB ，揭秘网易游戏规模化 TiDB SaaS 服务建设实践_数据库_田维繁_Info
  756ed68c2e8bb8dbc4f5a0f01cec6362  #  14207c  cloud.tencent.com         DBA计划外工作的一点思考-腾讯云开发者社区-腾讯云
  45526cc680de3ac7e39e27e4f1ea82d6  #  14156c  mp.weixin.qq.com          解锁Linux“故障宝藏”：Core Dump分析秘籍
  a586506fbf5e39188e8662c2a5ef36ae  #  14140c  ithelp.ithome.com.tw      Day30 Redis架構實戰-Redis Request Routing/效能監控與調教 - iT
  1383af16f652ba96ef3a1a2ccd7811cb  #  14131c  juejin.cn                 【小白请绕道】Redis 的 I/O 多路复用技术，它是如何工作的？Redis 的 I/O 多路复用
  a63b722e337c94c448469cbaeda2780a  #  14123c  juejin.cn                 再谈Raft一致性算法本文基于对分布式存储以及Raft算法的理解，再浅浅的分析分布式存储以及Raft
  ebd5be6a2515570bc962b5b5532c9494  #  14055c  juejin.cn                 Redis内存回收1.Redis内存回收 Redis之所以性能强，最主要的原因就是基于内存存储。然而
  e9306a342d9b36289c228d0dadb76b0c  #  14031c  mp.weixin.qq.com          深度探索Jemalloc：内存分配与优化实践
  b69f492e3b8214868eff4d6c09f68d8b  #  13926c  www.mydbops.com           Yulu's Data Breakthrough: 72% Storage Savings & Sc
  df1ae51824a2a79e5ce2a4ae746cc4c1  #  13919c  juejin.cn                 【建议收藏】数据库源码学习调试利器之 CGDBCGDB 是 GDB 的一个前端工具，通过提供更丰富的
  9406e0d6900611d537168e29f129a40e  #  13908c  mp.weixin.qq.com          一文搞懂腾讯云数据库都有啥？
  # === window 3/9 (201-300, avg 12538 chars/doc) ===
  217028f183386f55576c92270b1185be  #  13908c  juejin.cn                 从MySQL索引下推看性能优化：减少回表，提升查询效率接着上篇索引优化全攻略：提升排序、GROUP 
  c6fa92e5ff944c2e247abef4b82d02a3  #  13904c  juejin.cn                 新闻 | MySQL 9.2.0 有哪些功能新增、弃用和删除？2025 年 1 月 21 日，MyS
  ccb59c456a3bd191d7826ccb513aa08c  #  13870c  juejin.cn                 DBCP一个配置，浪费了MySQL 50%的性能！1. 引言 研究背景 数据库性能的重要性 数据库性
  75274d56ff4ecbbf91b4faee75cac8cd  #  13852c  juejin.cn                 OLTP上云，哪种架构最划算？·VLDB'25
  5affc9038bdd2ecfa79730a7fcdcad38  #  13793c  juejin.cn                 不作死就不会死！Redis缩容导致线上大规模故障的惨痛经历唉，小趴菜我最近又犯事了，怎么会是捏？Re
  1feba66c0577ef67ed23beb17c43025f  #  13785c  www.modb.pro              权限管控，还可以再简单点 - 墨天轮
  0eba42bf7d02a3c3e3598a9722cbd847  #  13775c  www.modb.pro              从MySQL数据库的角度来看系统page fault（缺页异常）
  dee24dd325d72215232df59dc3ccb641  #  13760c  www.modb.pro              使用docker-compose一键拉起一个ORACLE-ADG一主一备环境
  0e9882cbb3c7917b26251aba1dd71df1  #  13756c  cloud.tencent.com         6 mysql底层解析——缓存，Innodb_buffer_pool，包括连接、解析、缓存、引擎、存
  747278457a0b9e4b440922031694b5c9  #  13737c  www.modb.pro              近期客户需求巡检自己编写整理的SQL - 墨天轮
  87414491af876ac2bed247c28af3dc32  #  13736c  mp.weixin.qq.com          一条 SQL 是怎么导致 MySQL TempTable 引擎崩溃的？
  864da5709363c16af76f365306c1a0f1  #  13727c  www.modb.pro              MySQL 有没有类似 Oracle 的索引监控功能？ - 墨天轮
  e7eca656effbcb1f7a834641d6b4e66e  #  13703c  www.modb.pro              Oracle 官方文档整理以及阅读指南 - 墨天轮
  65781e5618da9a8be5f0cc47bb556272  #  13699c  www.modb.pro              MySQL 备库延迟排查：从大事务定位到根因深度分析
  b7c012df75c4a8c65ceb74ab23a90ab6  #  13696c  www.modb.pro              MySQL OCP 认证考试你知道吗？ - 墨天轮
  c96f1895052b469c48c42ddb0c22b9a0  #  13693c  juejin.cn                 为什么高手都要用非阻塞IO？非阻塞I/O极大的提高了系统运行效率。另外还有很多同学说非阻塞IO快，阻
  c42de607b00a6d208b94059f4d218b1a  #  13686c  mp.weixin.qq.com          SQL 优化对比：驱动表 vs Hash 关联
  afb454044deb7c2fb8e95d70070900fa  #  13665c  www.modb.pro              一键启动 Oracle Database 23c Free - 墨天轮
  a69f1499718af619f505a7bc9a176ea0  #  13649c  blog.csdn.net             MySQL进阶之路（二十一）—— 5分钟搞懂MySQL中的优化器与成本模型_mysql中的true 
  0b815a98abff315fe50e653f5df3a6bb  #  13642c  zhuanlan.zhihu.com        (2 封私信) MySQL性能诊断实践之系统观测工具 - 知乎
  1b075f6bffd67f550f942f6b81dabf9d  #  13610c  www.modb.pro              MySQL锁定位实践指南
  d51a210888d75c34c12f3f2b5d887459  #  13524c  www.modb.pro              mysql一键安装脚本分享 - 墨天轮
  af409e79577162f416b6463ce5d15a87  #  13506c  www.modb.pro              [MYSQL] row_format=compressed的存储结构浅析
  96ef003bebcb8c621f0a7f3123e736ce  #  13492c  mp.weixin.qq.com          老杨教你做监控体系设计(纯干货版)
  af9e005ca4117ac5d06795668036cf6f  #  13464c  juejin.cn                 P10老板一句‘搞不定就P0’，15分钟我用Arthas捞回1000万资损
  47b4511182e6e82b208a708e923a4ed1  #  13459c  www.infoq.cn              如何将技术债务纳入路线图_软件工程_InfoQ精选文章
  3d9701ad76464d991013ba14e4768b63  #  13444c  newsletter.squishy.computer Nature's many attempts to evolve a Nostr
  974aa1398cfb33a892f4faec4fdba4ff  #  13417c  mp.weixin.qq.com          什么？事务提交后，数据丢了？
  099c8de99670cbaf5c08e08feef5e1b4  #  13376c  mp.weixin.qq.com          希音面试：第三方挂了，我们总 背锅。设计一 靠谱的 高可用方案，让 外部依赖 稳如泰山
  cde9a293df0148928f7f6abdb8d99c8e  #  13339c  juejin.cn                 Mysql DATETIME 毫秒坑今天写代码突发一个诡异的 bug，代码逻辑大概如下。 先生成退款
  2de026eacc1b893ed1226f2bd873037c  #  13332c  mp.weixin.qq.com          TiDB 观测性解读（一）丨索引观测：快速识别无用索引与低效索引
  aa48496117f65bb611d2fbea446b3c6c  #  13247c  juejin.cn                 如何迅速并识别处理MDL锁阻塞问题TaurusDB推出MDL锁视图功能，帮助用户迅速识别并处理MDL
  29ecf63fcd34313a9a5e06c2b97a01c4  #  13225c  www.modb.pro              一键生成MySQL巡检报告
  5358496da341dbfe4de3c87a9ce4ac4f  #  13215c  mp.weixin.qq.com          大厂内训资料：  Skill设计7大核心原则，AI时代，人人必备（史上最全）
  783f485ee2a4566af9ddf900f7f8bb56  #  13179c  mp.weixin.qq.com          第 53 期：EXPLAIN 中最直观的 rows
  356d597ec2167bdfd3ed77777f909971  #  13081c  mp.weixin.qq.com          MySQL 8.0升级价值分析：新特性与5.7性能实测
  220a46a80d79e7909277fef80cca9a77  #  13039c  www.modb.pro              用蜜蜂(eBPF)来追踪海豚(MySQL)，性能追的上吗 - 墨天轮
  3417bbea01f3da303fe6587e9ec538f1  #  12990c  mp.weixin.qq.com          默认配置下，为什么 MySQL 8.0 比 MySQL 5.7 慢？
  b3172b34c930168aaa8f7c70759de72d  #  12928c  sysdig.com                Top key metrics for monitoring MySQL | Sysdig
  922b703f278bb1f6fe3372861644106e  #  12914c  mp.weixin.qq.com          从零开始学习MySQL调试跟踪（1）
  1910e6904f0fb569a19be4a24b171c18  #  12913c  blog.csdn.net             mysql中的Innodb_buffer_pool_mysql 的 innodb buffer po
  9a3940bcde09289b13996507d0bb3452  #  12823c  www.modb.pro              【专家有话说第四期】多年DBA实战生涯有哪些经验教训、常见误区？ - 墨天轮
  7240ba3a595045166bc14dc906dc5070  #  12791c  medium.com                A philosophy of building high-quality TiDB
  f24cbbd6a04f8ca036d5113ed745aab5  #  12779c  juejin.cn                 TiDB 中的自增主键有哪些使用限制，应该如何避免？大家好，我是V 哥，在TiDB中使用自增主键时，
  265e03c33a8abcd3cfe08219bf970788  #  12775c  juejin.cn                 Google工程师如何在实践中避免和处理故障鲁迅曾说：决定一个程序员的表现如何，除了他写的代码、完成
  5341b6858256a0774fc3ae4e1b17768d  #  12753c  juejin.cn                 分库分表已成为过去式，使用分布式数据库才是未来当我们使用 Mysql数据库到达一定量级以后，性能就会
  77c9c1d6afbff80e7276eb15cce12e49  #  12714c  juejin.cn                 部署更轻松了，Github Action自动化部署Hexo：代码推送，云服务器自动部署部署更轻松了，
  13c9a75a3b73f640e3b274638cd14d59  #  12650c  medium.com                Say Hello to Grafana OnCall. A Practical Guide to 
  e48e705554489935651e667b574d3058  #  12596c  juejin.cn                 稳定性方法论：可灰度 & 可监控 & 可回滚业务系统核心目标是挣钱，系统稳定性建设核心是防止丢钱（丢
  23a35557d03da0e51c3396bd694b4bf5  #  12552c  juejin.cn                 理解 MySQL 的分组机制：GROUP BY、SELECT、HAVING 及索引优化理解 MySQ
  0cc7ff4443fbb0cb3c90ca79bc6b9dcd  #  12435c  juejin.cn                 InnoDB 索引与 Online DDL 的结合：业务不中断的优化秘诀InnoDB加索引是否会锁表
  b1736a85bcca8ec024c8adc6afac4036  #  12412c  mp.weixin.qq.com          TiDB 多列索引优化：从分钟级到毫秒级，实现超万倍延迟降低
  ea385de9c0b44e5dd00d7baa05e5d0b7  #  12292c  www.modb.pro              离线部署TiDB 8.1.0 集群 - 墨天轮
  341f2313c1791492b1c0284347ce6220  #  12283c  mp.weixin.qq.com          活动中台系统慢 SQL 治理实践
  fb3635d67aa05bfa9595045817adc308  #  12250c  mp.weixin.qq.com          从零开始学习MySQL调试跟踪（2）
  3e081f32fa73e052fe70bb3c86d634f4  #  12204c  mp.weixin.qq.com          分布式数据库是伪需求
  ca14bed799d35fc4adb9a0f62af1bd8a  #  12196c  juejin.cn                 MVCC如何应对MySQL并发问题数据库使用事务来保持数据最终一致性，但是在并发下执行事务，会引起脏
  e971799877653511eabc9df4aeea104c  #  12138c  juejin.cn                 得物自建 Redis 无人值守资源均衡调度设计与实现目前，得物 Redis 管理平台管理着几千台 R
  ec20509e594012ab4e3a3bc4200fc1ab  #  12069c  cn.pingcap.com            TiDB 在个推丨掌握这两个调优技巧，让 TiDB 性能提速千倍！ | PingCAP 平凯星辰
  69543d21b92b2836d64184f7a064390e  #  12068c  mp.weixin.qq.com          MySQL中varchar(50)和varchar(500)区别是什么?
  c8d92283c776a448e787474ab2df7c00  #  11998c  mp.weixin.qq.com          一次大小写敏感参数 lower_case_table_names从0 改1的线上事故复盘
  0257e8d84d92ab9df034e8d8da89302a  #  11980c  mp.weixin.qq.com          Gartner 2025 全球数据库排名：PingCAP 凭什么领跑分布式赛道
  1de9b7d1440ed70776bf9f305e14a986  #  11971c  juejin.cn                 TiDB 底层存储结构 LSM 树原理介绍随着数据量的增大，传统关系型数据库越来越不能满足对于海量数
  a341f53008e995783c31665b88ea62d8  #  11956c  juejin.cn                 数据库性能优化之道：Buffer Pool 深度剖析（三）1. Buffer Pool 与数据库操作
  fc7fb93fd3428a7643605f8199852f6b  #  11926c  juejin.cn                 来来来，快速撸 Redis 一遍！年底了，你发年终奖了么？是不是很不爽？不管是被动毕业还是主动毕业，
  681f331f41efc7e130c57fe0adb36cfd  #  11886c  cloud.tencent.com         意想不到的MySQL复制延迟原因-腾讯云开发者社区-腾讯云
  1ccd2bc3061d196cb93e40b4a3d8a197  #  11838c  juejin.cn                 真·Redis缓存优化—97%的优化率你见过嘛？ | 京东云技术团队本文通过一封618前的R2M(公
  71ad51e40af1dcc472d06992997d0516  #  11832c  docs-archive.pingcap.com  Cross-DC Deployment Solutions | TiDB Archived Docs
  836dd0d3a1fafd647498cb0d2cbe5083  #  11825c  cloud.tencent.com         MYSQL proxysql 在深入 信息获取和信息输出-腾讯云开发者社区-腾讯云
  0a0365f5ed663011f439ecd86a77ace5  #  11824c  juejin.cn                 用Docker-Compose / K8s 快速安装MySQL 和 Redis项目开发中最常用的就是
  09de87d3a15a7e8dcfbd0ef455ddefa7  #  11799c  www.modb.pro              云和恩墨杨廷琨：日常运维中的技术决策
  6424dd3cd2dcf41a682a292d0693b88c  #  11774c  www.modb.pro              [MYSQL] 漏扫发现驱动存在漏洞, 怎么快速查找客户端的驱动版本呢? - 墨天轮
  63a37d9b9ca98f9b3b99170e36b50550  #  11767c  juejin.cn                 Redis 系列（一）：认识 Redis最近在整理 Redis 的相关知识体系，书和博客都看了很多，
  767d332bd9ae367e226a0c88bdf9cdda  #  11766c  mp.weixin.qq.com          MySQL 8.0 JSON 功能增强：更高效的存储、索引和查询
  568d16fb706f7aded0dcd246ae07f462  #  11762c  mp.weixin.qq.com          数据库监控指标
  75be5e203e2525680ca0da0f0f670615  #  11744c  www.modb.pro              一个不可思议的SQL优化过程及扩展几个需掌握的几个知识点 - 墨天轮
  ab0fceca2e10d9257ab64bf479662204  #  11709c  www.modb.pro              [MYSQL] 从库 io_thread 接受binlog速度太慢?
  b121609000b4d8151c7644a80e0b1da1  #  11688c  juejin.cn                 这句简单的sql，如何加索引？颠覆了我多年的认知掘金多能人，原理性内容可留言。 不啰嗦，直接入正题。
  4504ec57cff1695d52509f095590eb57  #  11682c  mysql.taobao.org          CloudJump II：云数据库在共享存储场景下的优化与实现（发表于SIGMOD 2025）
  2aea9f3c4968a9344f8d1384cb709267  #  11681c  juejin.cn                 九. Redis 持久化-AOF(详细讲解说明，一个配置一个说明分析，步步讲解到位 2)九. Red
  310a7f3d66d1b7fd7cb120662fec10f0  #  11603c  www.modb.pro              「合集」三年50篇，TiDB干货全收录 - 墨天轮
  5da18daca984cbdc2c24f7078f1716b5  #  11597c  mp.weixin.qq.com          预测技术在美团弹性伸缩场景的探索与应用
  cafa830ebf998bb3583c865eb01444cd  #  11573c  juejin.cn                 过度设计的架构师们，应该拿去祭天我发现一个非常有趣的现象。 十多年前，那时“美女”这个称谓还是非常稀
  e3635325a2d98d51abd3e0bd1e897305  #  11568c  mp.weixin.qq.com          多线程读写锁产生死锁的故障解决方案
  da9ec6ae216546915b14e556228aacf6  #  11476c  github.com                kejilion/sh: KEJILION.SH 一款全功能的Linux管理脚本！An all-in
  86e6ff1f64f293b7dbda6ccc1fad65e3  #  11474c  www.modb.pro              黄东旭：“向量数据库”还是“向量搜索插件 + SQL 数据库”？丨我对 2024 年数据库发展趋势的
  90a8dd6f2dddc0d00efe98fd30c36f8f  #  11425c  mp.weixin.qq.com          事务持续执行之谜：怎样找出对行记录上锁的 SQL？
  371ee94759aab8f941c8e302145321f0  #  11425c  mp.weixin.qq.com          OceanBase在传统监控数据存储的应用 | 优秀征文分享
  396492f261f31bd2daba732f62a2633b  #  11412c  juejin.cn                 唐刘：当 SaaS 爱上 TiDB（一）- 行业挑战与 TiDB 的应对之道系列文章将从技术原理和真
  86b22da9cb093413535d4c60d6d7ccf3  #  11313c  www.modb.pro              一个简单的查询语句竟然把CPU耗尽了
  3343f80ad4ea02a9b1fc52250a3b2bff  #  11303c  mp.weixin.qq.com          MySQL 一个会话占用几十 GB，你敢信？
  bf72f910f228526b8a13ab54f5299b4c  #  11299c  juejin.cn                 TiDB 资源管控的对撞测试以及最佳实践架构本文将从业务角度切入，通过对不同类型业务(OLTP 和 
  e7fb3d296d98f0cb512b4cbd2d2e7640  #  11245c  mp.weixin.qq.com          容器化后性能反而下降了？老杨带你深挖背后的技术真相
  5f21306297f8c498e3fd82aa65287180  #  11240c  tidb.net                  二、从数据库架构选型看 TiDB 常见应用场景 | TiDB Books
  f26a1d7db8751248a9458210f4ee342e  #  11235c  juejin.cn                 【稳定性】从项目风险管理角度探讨系统稳定性背景： 在软件开发过程中，系统稳定性是一个重要的考量因素。
  62a2d2a8185b0acac6aaad114b509948  #  11194c  mp.weixin.qq.com          Ansible千节点作战手册：灰度、熔断与一致性守护
  29124bfed232ff376eac386866d868a4  #  11163c  juejin.cn                 揭秘10亿+高并发应用如何实现高效稳定的开发和运维揭秘10亿+高并发应用如何实现高效稳定的开发和运维
  fda87a7de4f9cc233b1d5413ae62fa22  #  11153c  www.modb.pro              MySQL 8.0 优化器迷思：索引误选是如何发生的？
  c05b559cdae28f2f430f663a7fcfd3e8  #  11134c  mp.weixin.qq.com          利用 MySQL 8.0 clone 插件远程克隆快速重建主从复制环境
  27e9099df9be2e5a232b1bb47113906b  #  11131c  juejin.cn                 SHOPLINE x TiDB丨集群成本降低 50%！跨境电商 SHOPLINE 交易、商品管理等核
  # === window 4/9 (301-400, avg 10035 chars/doc) ===
  7de0d091d91c88f84dcf3593a6f7462d  #  11125c  mp.weixin.qq.com          单体架构和微服务架构到底哪个好？
  50c4dffbe1dc2f4c90bcb36f2fa1ff79  #  11113c  juejin.cn                 使用podman搭建MySQL 8.0主从避坑指北镜像准备和选择 由于mysql自带许多工具，比如m
  e1462e7727b76b3201c2f59f40b77572  #  11108c  juejin.cn                 拒绝全表扫描！3个提升MySQL深度分页技巧！分析MySQL深度分页性能问题，并介绍了3种优化方案：
  d19ed17ffb58920fe620e4bc1d1ab7b1  #  11108c  mp.weixin.qq.com          阿里面试：延迟双删有什么问题？大厂是如何优雅避开 延迟双删 的？
  4c5c7ea86f85576b90bde65b02e956c3  #  11089c  www.modb.pro              MySQL 运维高危操作 - 墨天轮
  216773d3642c67bdfcdcc050f50b9bdd  #  11072c  mp.weixin.qq.com          一篇为MySQL用户，分析版本核心差异的文章--8.028-8.4的差异
  539651cce16d117833dbb8af11c8046c  #  11062c  xie.infoq.cn              基于 Grafana LGTM 可观测性平台的快速构建_可观测性_Grafana 爱好者_InfoQ
  994273e100bbe317b24d730c3600aa47  #  10975c  juejin.cn                 瓜子二手车 x TiDB 丨平均耗时降低 30%，TiDB HTAP 在瓜子二手车财务中台结账核心系
  22cfb4facea082f8b8debd6605e8e257  #  10963c  mp.weixin.qq.com          从单一到多活，麦当劳中国的数据库架构迁移实战
  99574e36ba022a0a02cf9b9545f7d55a  #  10843c  juejin.cn                 开源全方位运维监控工具：HertzBeatHertzBeat：实时监控系统性能，精准预警保障业务稳定
  b79dbda815b5964f80e03209fc7b8e33  #  10842c  www.modb.pro              Innodb的覆盖索引实践 - 墨天轮
  ee379b8960c3cec660fb5579a208ac1d  #  10828c  mp.weixin.qq.com          队列不只是MQ！——亿级流量系统架构设计系列
  3f02310b7e8d40d8a61662a93f4fc153  #  10761c  www.cnblogs.com           MySQL 在线开启GTID的每个阶段是要做什么 - ZhenXing_Yu - 博客园
  6c436d6832ca311822f9cc006336ff54  #  10729c  zhuanlan.zhihu.com        TiDB HTAP 深度解读 - 知乎
  d878c8bd4435c697819401293e6cb373  #  10677c  juejin.cn                 不可思议！平均执行耗时仅1.5ms的接口在超时时间100ms下成功率竟然还不到5个9！！本文深入分析
  20ebd916b868d194b735cd2e2e7de577  #  10634c  juejin.cn                 Redis 性能刺客，大key在使用 Redis 的过程中，如果未能及时发现并处理 Big keys
  eac970515cc6b06b1b335d2273c954fd  #  10595c  juejin.cn                 系统设计中 跨时区问题 解决方案hello，大家好，我是张张，「架构精进之路」公号作者。 一、背景 
  0b42390bb6652a945e1b87c86efc459a  #  10592c  mp.weixin.qq.com          我的2023-2024年mysql相关文章整理汇总
  a4321b7b5f8ee0884724922720b61595  #  10536c  www.yunweipai.com         轻松驾驭！Prometheus 如何监控指标，快速定位故障 - 运维派
  290705b8cfe5c418572d1f2f7d66a8f8  #  10534c  mp.weixin.qq.com          【稳定性】稳定性建设之变更管理
  49d6d7ab28010ed561100dc3178b7872  #  10512c  www.modb.pro              在 Kubernetes 上跑数据库，真的没有意义么？ - 墨天轮
  9a3c31cdbd7bcaaeb71c74d2758815c7  #  10510c  tech.meituan.com          超大规模数据库集群保稳系列之一：高可用系统
  e7159a79bff33500e66dcd8c83b194c2  #  10460c  mp.weixin.qq.com          奇思妙想的SQL｜兼顾性能的数据倾斜处理新姿势
  242677c4365e3acf8f7e18583efea8c5  #  10446c  mysql.taobao.org          MySQL 遇见 DuckDB V2
  747015c71672d076a19bf363ff9e7bc5  #  10388c  ost.51cto.com             三歪连MySQL大表怎么DDL变更都不懂-鸿蒙开发者社区-51CTO.COM
  c987ef17da2cd800c929f41f933f30f9  #  10376c  juejin.cn                 Galera Cluster一致性问题本文主要说明MariaDB Galera Cluster + 
  8c8a6713a6a88c0a81a4844755c9e9ca  #  10368c  www.modb.pro              从秒级洞察到一键修复：现代数据库监控工具的MTTD与MTTR制胜之道
  68cf2d356d223e40052e1a97cbd82a56  #  10348c  mp.weixin.qq.com          分布式跨节点的数据排序 - Lamport Clock
  920fc401e964bd564fd1ba19586c13d8  #  10342c  www.modb.pro              MySQL优化生产实践-MySQL 优化器负优化产生超慢查询(三)，优化后性能提升 47倍
  07a717881b13a95b7c412894c5c890a6  #  10326c  www.modb.pro              运维实践｜MySQL命令之perror - 墨天轮
  d17e415e3ea9f029b01340b4871dd160  #  10325c  www.modb.pro              出海案例合辑丨TiDB Cloud 在金融、社交、智能风控领域的最佳实践 - 墨天轮
  c6754911a1521c9a5bfad6464d73b521  #  10319c  mp.weixin.qq.com          2026 年了，万物皆可 Postgres
  8835b8fd9b634e87a5282504f03da56f  #  10315c  mp.weixin.qq.com          35 张图带你了解 Oracle AI Database 26ai 技术架构(中)
  86d4255c1e9b4491db7e123bc5356267  #  10228c  juejin.cn                 Redis 分布式锁：实现与应用在分布式系统中，为了保证数据的一致性和并发控制，常常需要使用分布式锁
  2703fc1679655e88248b2b12af886e95  #  10222c  mp.weixin.qq.com          深度解析MySQL索引失效的8大场景及终极解决方案
  578cf5fdbe13139280cfb700f3ff31ee  #  10220c  github.com                cookieY/Yearning:  A most popular sql audit platf
  0d98d837392fad916ca0ec993690421e  #  10187c  juejin.cn                 学习 MySQL 必须了解的几个 Undo 概念Undo 模块的第一篇，聊聊 Undo 相关的几个概
  9d0cce180d29510aeaa72fabc39369bd  #  10175c  mp.weixin.qq.com          当 DeepSeek 遇见数据库，大模型如何重构 DBA 的工作模式？
  5eb59bb4729666790af59f5cb379544e  #  10170c  mp.weixin.qq.com          MySQL 9.5 性能优化终极指南：从 10s 到 10ms 的 5 个核心心法
  11943de59bf565b7d958f82d5ef421cf  #  10164c  tidb.net                  专栏 - TiDB与MySQL在备份容灾体系的衡量对比 | TiDB 社区
  7c13d67e4a2e9c6c8bd59d50484a24bf  #  10140c  mp.weixin.qq.com          改动四行代码，DB基础框架内存占用下降40%
  0a126f19f7fb8815e609b1bd7ddf1a8e  #  10130c  www.modb.pro              MySQL 5.7 半同步复制优缺点、配置及实操记录
  2001810f78059400d786baaaa6efa019  #  10092c  github.com                sqlmapproject/sqlmap: Automatic SQL injection and 
  618c058a407fb5679ebedda83f6a9e02  #  10065c  www.cnblogs.com           高并发linux内核参数调优 - 知无不言~ - 博客园
  499ade35926310be425eda5ff150f94e  #  10044c  mp.weixin.qq.com          阿里面试：MySQL 一个表最多 加几个索引？ 6个？64个？还是多少？
  b3e61dbf1eaa62124a0f3fb0d7fca83f  #  10027c  mp.weixin.qq.com          深入理解 SQL 联结表：从基础到优化，一篇文章带你掌握
  014f6d8449fb1d87feb08583d79ba2b0  #  10014c  developer.aliyun.com      探索Redis与MySQL的双写问题-阿里云开发者社区
  bafa55700417ec6e1448c610ccf633dd  #  10011c  github.com                actiontech/sqle: 一个支持多种不同类型数据库，覆盖事前控制、事后监督、标准发布场景，
  dacc7b2ec50c463fd88b3c0f76cfad04  #  10009c  juejin.cn                 MySQL 分配 Undo 段分配完回滚段，接下来该分享 Undo 段了。 > 作者：操盛春，爱可生
  8bb7ff28765ebc83a117b67f87d8b9de  #  10006c  www.modb.pro              为什么在配置顶格本地盘服务上运行数据库，数据量不大的情况下，CPU资源却显得并不“宽裕”？
  6c01c7f8685f78a5297bd600c889a0eb  #   9967c  juejin.cn                 云监控的盲点：用户视角监控云应用性能时，主干网、最后一公里和无线网络不仅仅是画面的一部分，它们就是画
  798696a57435063e63ece1615aaf44b1  #   9967c  www.modb.pro              7.5 LTS 解读 ｜ Runaway Queries 管理、高性能数据批处理方案、DDL 启停特
  2cc68248d145f410fb0e967bb6a0f880  #   9964c  juejin.cn                 通过 gitHub Action 自动发布博客文章因为之前的博客升级了，并且 gh-pages de
  32c69f4736b968a9f6f790d56bcccbe2  #   9928c  mp.weixin.qq.com          亿级流量系统架构设计系列——5.系统降级特技
  82e29afe90a9448e6d252c6f190ddc60  #   9927c  mp.weixin.qq.com          数据库巡检进入智能时代：异常检测算法的落地实践
  1c72a63958d35f8bbaac1d46415655a8  #   9907c  mp.weixin.qq.com          架构师必看！现代应用架构发展趋势与数据库选型建议丨TiDB vs MySQL 专题（一）
  bc6f838fdd36f9c671f80a91cab79951  #   9903c  juejin.cn                 Undo 表空间分配回滚段事务写第一条 Undo 日志之前，需要先分配回滚段。 > 作者：操盛春，爱
  99e79ab39ea9004943b9c92dfcdcceb9  #   9903c  mysql.taobao.org          InnoDB 二级索引 B+ 树的 Key 是什么？
  2e4744acfe6ffc0fec8a6937fb8689ee  #   9878c  mp.weixin.qq.com          如何画好一张架构图？
  e329d14d82af19f8c8732410e682d876  #   9877c  juejin.cn                 分布式系统架构8：分布式缓存1. AP还是CP Redis 集群就是典型的 AP 式，它具有高性能、
  63b2d82ac235da5f28aea4fca14603a6  #   9859c  www.modb.pro              数据库管理-第394期 从数据角度如何用好分布式数据库（20251209）
  a298dd2bf5726df03a02ce438b399390  #   9835c  www.modb.pro              MySQL-extra常见的额外信息 - 墨天轮
  416422e1def568c6639587c52b43ef02  #   9816c  mp.weixin.qq.com          什么是技术架构、数据架构、业务架构、应用架构和代码架构？
  37c8cb3419cbe919508422032878e4d7  #   9793c  mp.weixin.qq.com          架构师和技术管理者必须打破的7个'常识'
  304d33ad22f32d52cc212a8465a01613  #   9781c  juejin.cn                 什么是系统可用性？如何提升可用性？日常开发中，我们经常听到系统的可用性是几个 9这样的描述，因此，这
  c88bc9dc70d233d3bbe555aa91b89b8e  #   9774c  mp.weixin.qq.com          面试官最爱问：你线上 QPS 是多少？你怎么知道的？
  48561f1691da582df595307bd02a614b  #   9760c  mp.weixin.qq.com          DR Auto-Sync：TiDB 同城两中心自适应同步复制技术解析
  a4bece0fd22b660823f13109f8c9c56d  #   9758c  github.com                xykt/IPQuality: IP质量检测脚本 - IP Quality Check Script
  c5ccce85f8dd2d29e4493536ecda5797  #   9737c  juejin.cn                 MySQL如何加速读写速度？来看看Buffer Pool什么是 Buffer Pool 什么是 Bu
  b15cea0e52bc2b147a982bd0d42b77f5  #   9729c  juejin.cn                 为何要小表驱动大表？为什么要小表驱动大表？ MySQL在执行Join操作时，优先使用较小的表作为驱动
  0382a897347df4798d7e22baeca3dca9  #   9697c  mp.weixin.qq.com          整洁架构演进之路——京东广告投放平台实战
  dbd9d8ee40e269e7e0a9740532c52ec8  #   9659c  mp.weixin.qq.com          TiDB 黄东旭：消耗了上百亿 Token后， 对于 Agent 时代软件构建、软件形态及未来发展的
  b221d40092566cfb3b93d88b064efe4f  #   9653c  juejin.cn                 SQL执行顺序与ON vs WHERE：MySQL底层解析与面试记忆法SQL执行顺序与ON vs W
  55a2e878185edd06369a1b04387280e6  #   9602c  mp.weixin.qq.com          高并发下幂等性的七大解决方案（图文总结）
  5ed3876f474f24c2a33147acd3267d85  #   9580c  www.modb.pro              Debezium实战！一款不错的开源CDC工具 - 墨天轮
  92d095e0a7ede211a14fbe4ef30812e3  #   9552c  juejin.cn                 【稳定性】稳定性建设之依赖设计背景 随着分布式微服务的发展，一个普通的应用可能会依赖于许多其他服务，
  4ce0b3f917daa79230d277dfbc115c16  #   9543c  mp.weixin.qq.com          建议收藏|MySQL DBA 防坑指南
  cfc6998dae59a74b0e73437915906997  #   9532c  juejin.cn                 数据库管理工具NineData，一年进化成为数万+开发者的首选数据库工具？
  f89a1f60714663f9493a4a35837dfaa1  #   9512c  mp.weixin.qq.com          京东二面：分库分表后翻页100万条，怎么设计？答对这题直接给P7！
  1739e4ae182da8c5d4e409b063d6876a  #   9507c  mp.weixin.qq.com          重生之 MySQL B+Tree 提前问世二十年，MySQL之父叫我师父
  9481b6b1dc40262da708cc295fcfcf53  #   9452c  juejin.cn                 美团二面:如何解决Redis热点key问题大家好，我是田螺。 有位星球粉丝去美团面试，被问到：Red
  07a24e9e6324a0563f5cb3deff2b1f58  #   9450c  blog.csdn.net             grant之后为什么要flush privileges_flush grant;-CSDN博客
  52e8d4cc76553717ebfe093141e92588  #   9439c  mp.weixin.qq.com          数据库内核揭秘：存储引擎的设计与实现
  dcda36a9b4a96a259d5f64f830720cd6  #   9430c  juejin.cn                 一次线上生产库的全流程切换完整方案本篇介绍了一次数据库迁移的完整方案。 本次需要改造的系统为一个较为
  b67c38779ee21b7c938d30596f93ce60  #   9378c  mp.weixin.qq.com          MySQL 8.0结束生命周期，8.4.9 LTS、9.7.0发版上线：一个时代的交接与新生
  ded2afddbbecda4a36a0bd8da64ba6b1  #   9367c  xie.infoq.cn              MongoDB磁盘清理那些事儿_mongodb_循环智能_InfoQ写作社区
  b1b7469378233f9581c863170286f8ef  #   9361c  mp.weixin.qq.com          微众银行：大规模 TiDB 运维体系建设 & 金融级稳定性保障漫谈
  7d56bd12f7ce4e49c7679dc0a74db7e0  #   9346c  mp.weixin.qq.com          千万级高性能长连接Go服务架构实践
  85442faf3da258ee16a3ef38899f808b  #   9346c  mp.weixin.qq.com          面试必看！腾讯面试问：MySQL缓存有几级？你能答上来吗？
  c5ea9a4541563d9f85de80b1f27011a1  #   9336c  www.modb.pro              揭开 PostgreSQL 读取效率问题的真相
  fe2c8392501d406156efc25b53110da9  #   9332c  openai.com                擴展 PostgreSQL 以支援 8 億名 ChatGPT 使用者
  42dfb24cc37ad18726de64a2bb5cc686  #   9320c  mp.weixin.qq.com          架构设计过程中的10点体会
  5048ef6006bc902710136f9d234bc350  #   9314c  tidb.net                  专栏 - 月活超 1.1 亿，用户超 4 亿，你也在用的「知乎」是如何在超大规模 TiDB 集群上玩
  32c55cca02b90fedfe90f13be0b0cc48  #   9291c  mp.weixin.qq.com          面试官：第三方服务经常挂，你的系统怎么保证高可用？
  f0bc01c71363634b79aaa1216000b41d  #   9262c  opensource.actionsky.com  技术分享 | 如何使用 bcc 工具观测 MySQL 延迟
  e51cd350fe0d6bce55191d86520d2261  #   9251c  mp.weixin.qq.com          MySQL 如何实现安全连接？
  59f0e31cba4c06395b7f87db795e44d2  #   9251c  juejin.cn                 监控系统中的95分位，90分位，是什么？解释下什么是分位数 分位数(Quantile)，TP=Top
  792df6acaebabccdf938d861398e4a61  #   9249c  juejin.cn                 数据质量和数据治理的关系 | 京东云技术团队很多不太了解的人会认为：数据治理就是干数据清洗的。 近两
  02f7ce5680cb3c01e50450fddbe10d04  #   9183c  juejin.cn                 面试复盘：MySQL InnoDB 事务隔离级别与 MVCC 分析/为什么可重复读的死锁概率高？_ 
  23cf552d4947da4441ccb1acd5aa7079  #   9172c  mp.weixin.qq.com          掌握 SQL 子查询：让你成为查询优化高手
  # === window 5/9 (401-500, avg 8102 chars/doc) ===
  44b0a9b336e6d445876bd777a34fb8b2  #   9138c  juejin.cn                 这些BUG，防不胜防常见时间case与防护分析 话不多说，上干货！笔者经过长年累月的积累，针对常见的
  2ab019b57c025f2f4972986577ee1f5c  #   9118c  mp.weixin.qq.com          TiDB 可观测性解读系列：索引与算子执行性能优化实践
  5bf9d1d0905f632298cf0a98cefd6aa9  #   9115c  cloud.tencent.com         囧...执行analyze table意外导致waiting for table flush-腾讯云
  e9e93bba19be3d44d59ca672e4ca49b2  #   9115c  www.modb.pro              数据库设计(MySQL)避坑指南 - 墨天轮
  f400595a754aef9c556f00d1fc68154a  #   9096c  juejin.cn                 如何设计一个秒杀系统大家好，我是田螺。 最近有位星球好友问我，如何从整体角度，去设计一个秒杀系统。秒
  71b2e5d43a3491634adaa66b8824b45f  #   9091c  testerhome.com            从工程师到技术 leader 的思维升级 · 测试之家
  f71e5577f6761159acd6f588bff82b1a  #   9061c  www.modb.pro              GBASE南大通用专家访谈：走进深水区，核心系统需要什么样的（OLTP）数据库？ - 墨天轮
  89f9984a8f95983ed998b21c78e1358e  #   8992c  juejin.cn                 直观且高效！一个 Redis 可视化工具！Redis Insight —— 一个基于 Electro
  9d9c56c47b7487e447b293a014d5f263  #   8976c  mp.weixin.qq.com          35 张图带你了解 Oracle AI Database 26ai 技术架构(下)
  bdb938515d4db0a98027b2e465844afd  #   8890c  mp.weixin.qq.com          阿里面试：10Wqps 的“限流阈值”，是怎么 计算 出来的 ？
  0fce448cb6f2ea23bafbdbb9d1ac1e61  #   8846c  mp.weixin.qq.com          数据库分片评估，零代码实践
  db88b92775464cd4e325dfcf2d2a4c66  #   8812c  mp.weixin.qq.com          MySQL Buffer Pool的“防暴”机制，让你的数据库内存永不“社恐”
  0b89d4063faab9584c2a02a17afec5d7  #   8811c  justinhollly.medium.com   使用 Blue-Green Deploy 把 Mysql 5.7 升級到 8.0 | by Just
  2fc668d4428f430525d21aafa0df261d  #   8790c  mp.weixin.qq.com          PGSQL vs MySQL：一场已经结束的战争
  b0e035468657e143017813f07af2263f  #   8772c  juejin.cn                 数据库性能优化之道：Buffer Pool 深度剖析（一）1. 什么是 Buffer Pool？ 通
  641c6bf58c66c8289d1f3afb9c8322c5  #   8758c  cloud.tencent.com         注意啦！mysql 唯一键冲突与解决冲突时的死锁风险-腾讯云开发者社区-腾讯云
  ebd1229c005d4aa71c1428465b0cf000  #   8733c  mp.weixin.qq.com          一文看懂微服务世界性技术难题——分布式事务
  5010cee755fc68fd6103067d0f8de45e  #   8680c  mp.weixin.qq.com          MySQL 中 IN 到底走不走索引？90% 的人都理解错了
  cc1432d35ac3db1b87767c9fd0ca489b  #   8655c  mp.weixin.qq.com          数据库同步神器！一款开源的异构数据库同步系统，支持所有主流数据库数据同步，效率提升10倍
  4a533f9955a7b50cb4596468c058eb7f  #   8616c  mp.weixin.qq.com          架构师基本功：如何画好一张UML用例图？
  e323f982151cdee3c063172ec89893b2  #   8594c  mp.weixin.qq.com          行业案例：12306亿级流量架构分析（史上最全）
  30b2eb3f014c6499f0fada785c70fc9b  #   8593c  mp.weixin.qq.com          基于主动元数据构建智能数据治理体系|京东零售技术实践
  2363f83ac347c8e3e1c148804be7270a  #   8544c  tech.meituan.com          超大规模数据库集群保稳系列之二：数据库攻防演练建设实践
  9398151483b56361b103e7ad85c07221  #   8535c  mp.weixin.qq.com          基于主动元数据构建智能数据治理体系|京东零售技术实践
  a7a153849277d6daeda5f742f7b4499c  #   8526c  mp.weixin.qq.com          单元化架构在字节跳动的落地实践
  110b5dd41feddec4456121f82de5d947  #   8513c  mp.weixin.qq.com          别再盲目跟风，七家企业真实场景的向量数据库选型，揭秘核心原则
  500d284589890b157a375d0716f15a67  #   8475c  juejin.cn                 分布式系统架构7：本地缓存1.引入缓存的影响 我们在开发时，用到缓存的情况，无非就是为了减少客户端对
  b3197c5db61ec605db44b1e9bfd73d4c  #   8471c  www.modb.pro              MySQL 高可用MHA整体解读
  a42b9134bc6cbfa4a0eb624df9cb84bd  #   8464c  www.modb.pro              PostgreSQL 白名单与访问控制，你了解多少？
  efdce531a066312521594d378fbec0b1  #   8445c  mp.weixin.qq.com          如何准确获取 MySQL 主从延迟时间？
  6178cb92683f4e4ed6d5e16ac3b57411  #   8438c  mp.weixin.qq.com          MySQL 性能优化核心指南：表结构设计与查询速度深度解析
  6966be31852851e890b6396710a52af8  #   8416c  mp.weixin.qq.com          告警平台：给告警一个胶带
  0bb56f2b4df816c6969b87d72ff5a89d  #   8404c  mp.weixin.qq.com          别再乱用dd和fio了！一篇文章彻底讲清底层原理，从性能测试小白变专家
  8b00523b7afd9201d9eba6bc4ceb6f1b  #   8394c  juejin.cn                 15个系统设计权衡关键点：构建高性能系统的黄金法则在系统设计中，性能是一个关键的考量因素，尤其是在面
  8cf0dfac20145d8aad1f1fcc8ef182f6  #   8386c  mp.weixin.qq.com          应用缓存不止是Redis！——亿级流量系统架构设计系列
  30f14ae923d74b101276b457397c9e56  #   8372c  juejin.cn                 数据库性能优化之道：Buffer Pool 深度剖析（二）1. Buffer Pool 的组成 Bu
  29923a2ff3e48bb8fa82bdd2c75cd4ca  #   8360c  mp.weixin.qq.com          什么才是架构师的真内核？
  f5afb7bc9f6e72f0554d4b087cb97916  #   8339c  blog.csdn.net             MySQL 8.4 版本(LTS) 发布，一睹为快_mysql 8.4.4lts-CSDN博客
  101850f77b5ef2dedab91a52e2ed7742  #   8332c  juejin.cn                 腾讯音乐：说说Redis脑裂问题？Redis 脑裂问题是指，在 Redis 哨兵模式或集群模式中，由
  4ea56b9aac3735b178b207e76680ba16  #   8327c  mp.weixin.qq.com          MySQL 8.4新特性之直方图自动更新
  ae312ce915141a3b796a129cd7d7170b  #   8311c  juejin.cn                 MySQL 如何插入记录的 Undo 日志？Undo 模块的第二篇，聊聊插入记录产生的 Undo 日
  72a36f88fa5f3dd55625c60c045a0f3c  #   8309c  mp.weixin.qq.com          爬虫搞崩网站后，程序员自制“Zip炸弹”反击，6刀服务器成功扛住4.6万请求
  64b489bde252cbb70863ab7a779b75cf  #   8263c  mp.weixin.qq.com          网易终面：100G内存下，MySQL查询200G大表会OOM么？
  0c13009f75e503fc241380577e1e1714  #   8242c  juejin.cn                 一文让你对mysql索引底层实现明明白白作者：京东零售 韩航云 开篇： 图片是本人随笔画的，有点粗糙
  28eb86116fab2803d090537fee290113  #   8236c  unknown                   TiDB 的高可用实践：一文了解代理组件 TiProxy 的原理与应用
  306a2fdd62275d347be82a00faf87f3e  #   8188c  www.modb.pro              假期结束了，DBA们又要忙起来了 - 墨天轮
  15c525f09b5d02cf6690c65d97756f1f  #   8160c  tech.meituan.com          数据库异常智能分析与诊断 - 美团技术团队
  5450d4d89dd0b48d368c766133e165a4  #   8154c  www.modb.pro              实战过程记录：濒临宕机的业务系统仅优化1个SQL即恢复！！ - 墨天轮
  b42daf3594e7c685521ef338b772085e  #   8153c  mp.weixin.qq.com          实现一个 MySQL 配置对比脚本需要考虑哪些细节？
  b4b1abba675ec98a51ed46678dd748af  #   8132c  www.modb.pro              谈谈分布式数据库的分片键选择准则和数据重分布的思考 - 墨天轮
  cb36d6d5588ad442a66262586b2e28ca  #   8119c  www.modb.pro              DBA运维压力大的根源是什么？分享3个提升效率的核心方法
  f0fa06631288db2fe941f72b59f6f429  #   8114c  mp.weixin.qq.com          腾讯面试：1亿用户的好友关系如何秒级查询共同好友？这套方案让性能提升100倍！
  3f933187d5510b2a9790706d699eaeba  #   8095c  mp.weixin.qq.com          PostgreSQL 18 最新版本发布了，看看都有啥？
  ec9347a5eee122f836c568ffffb8a27e  #   8055c  mp.weixin.qq.com          如何从0-1的建设云上稳定性？
  474db9c225132febf28cf0237f6756b5  #   8048c  mp.weixin.qq.com          该开始关注 MySQL 8.4 了
  d3a854f925bc3e4c738bb5bd5481f95b  #   7998c  testerhome.com            自动化的 10 项准备工作 · 测试之家
  39f02aea862b12f6283f50d2a9ac4e1c  #   7992c  juejin.cn                 MySQL 8.0.35 企业版比社区版性能高出 25%？# 前言 说实话，比较一下这两个 MySQ
  f282805a621b32c9815451ada68aa6b7  #   7987c  www.modb.pro              DBA的前景怎样？ - 墨天轮
  2be116ef3fe501312dc262e4bf18ed04  #   7956c  mp.weixin.qq.com          招行面试：高并发写，为什么不推荐关系数据？
  a9a45617eedb98682e148905278d00f1  #   7953c  www.slideshare.net        ArgoCD 的雷 碰過的人就知道 @TSMC IT Community Meetup #4 | P
  d0d1305ad59b2d3b0e3f6fbf26f823f7  #   7952c  mp.weixin.qq.com          性能比拼: MySQL vs PostgreSQL
  d60c3b194bd62f5a755432fc11e2a5ee  #   7951c  mp.weixin.qq.com          从0到1建设美团数据库容量评估系统
  b7ac18169e19ad481417d57f8691ddd1  #   7937c  www.modb.pro              图数据库采购 | 做好三大问题的前置思考 - 墨天轮
  da3cbf9103dd0fde44989bcf85ce8d8e  #   7924c  mp.weixin.qq.com          [MYSQL] 出现大量的Waiting for table flush导致业务表查询不了
  232ca7ed99f159b92e0f2cf1d06394ed  #   7924c  mp.weixin.qq.com          MySQL的performance_schema：你的数据库隐形监控官！
  913838650560b9b03c229fddfad4cdd3  #   7839c  www.easemob.com           天啊，这个MySQL故障定位方法太好用了！ - 环信
  51ddf38d06733b767208de80242be46e  #   7780c  www.modb.pro              看透Oracle DBA赚钱的另外一层逻辑 - 墨天轮
  2ce23a075947fcba62bdaaeaa37af067  #   7778c  mp.weixin.qq.com          为什么GROUP BY比DISTINCT快3倍？90%的程序员都踩过这个坑！
  0ba61f00c841e9c8807906298c8adb3d  #   7743c  blog.xiayf.cn             BitPacking
  5c22c86cab79a213aa0f3e774fb65a44  #   7696c  tech.meituan.com          超大规模数据库集群保稳系列之三：美团数据库容灾体系建设实践
  00bc274f98a08ecc1f0aa21660a64755  #   7669c  mp.weixin.qq.com          MySQL 9.7 LTS，何至于此
  014f9d3e04c22471170b4a7dde06501d  #   7625c  www.modb.pro              2026年，数据库技术都几十岁了，安装难题为何还没被根治？
  86a8ea7c70317357da7b0a3bf35dea79  #   7618c  mp.weixin.qq.com          35岁重学网络安全——SQL注入篇（二十四）
  02581dc354de9f20ea6917d6e6764de8  #   7615c  zhuanlan.zhihu.com        技术 011 - 《My Philosophy on Alerting》- 监控报警的哲学 - 知乎
  8afe88f0d8aa0f874c0ff4603080c299  #   7605c  mp.weixin.qq.com          可以不用，但是不能不会的MySQL进阶技能
  efde1c0d259b1f325219ed58c751fad6  #   7593c  mp.weixin.qq.com          小红书自研Binlog Server守护MySQL数据0丢失
  ada26a457f24c63b95c3b4cd08ffc1d8  #   7584c  zhuanlan.zhihu.com        xtrabackup原理及实施
  63119f5c69d42ed1a267a59ce5c3a63a  #   7545c  mp.weixin.qq.com          [MYSQL] 参数/变量浅析(1) -- 超时(timeout)相关
  2912766936bb510774c1551dd89fa3b9  #   7540c  tidb.net                  专栏 - 国产数据库“同城两中心”容灾方案对比，TiDB表现优秀 | TiDB 社区
  7a3cda39d47cb670a24215b0004634dc  #   7529c  mp.weixin.qq.com          Apache Doris毫秒级分布式数据库引擎
  20b82eeff9bce51ccb1902caead3b6ce  #   7509c  juejin.cn                 系统技术规划的几点概要思路每年年底或年初都会有各种总结规划，业务部门有业务的规划，研发部门有研发的技
  b49bd03601324599bb5aec4fbdd0835b  #   7497c  github.com                blueswen/observability-workshop-101: Build a lab s
  029ba53675722edcf473b3cbf8963ab8  #   7488c  www.modb.pro              转行DBA，给你分享数据库运维的N条建议（随时更新） - 墨天轮
  6b201bfea29e61bcdf3f42feadad8183  #   7447c  mp.weixin.qq.com          在Netflix构建全球缓存系统：深入了解全局复制
  0a5cc77baa6fdac01c4cad8e5669fa86  #   7417c  mp.weixin.qq.com          搞懂Redo Log与Binlog，就搞懂了MySQL数据安全的半壁江山
  e17662648434859bd6be76ed3b95a212  #   7404c  mp.weixin.qq.com          MySQL 用 limit 为什么会影响性能？有什么优化方案？
  de2791b620b63753c4bc05e868e8cbb9  #   7401c  mp.weixin.qq.com          B站大数据平台故障自愈实践
  9e92b067b97402a563e5c4b170238c0c  #   7384c  www.kancloud.cn           processlist中哪些状态要引起关注 · MySQL FAQ系列整理 · 看云
  e98faa4611508ebf162d1ae5f9b8622d  #   7366c  mp.weixin.qq.com          火焰图：MySQL 性能分析的可视化利器
  02507d3964afd744e6dbb7e9148eaacf  #   7346c  mp.weixin.qq.com          MySQL内存使用率高问题排查
  ee4f383c38b25b93083dd7fa22dcc594  #   7329c  mp.weixin.qq.com          MySQL内存稳定神器--jemalloc内存分配器
  2b72721c0360d3db80da67d933324c06  #   7327c  blog.bytebytego.com       Why Do We Need a Message Queue? - ByteByteGo Newsl
  9b1c88d0271839dc6226b9a5d2db3820  #   7295c  mp.weixin.qq.com          数据库智能运维skill—DBClaw安装与配置文档
  18cf5c0f70442806d22fd260498ea0e7  #   7278c  mp.weixin.qq.com          什么是 CDMP
  80289b23686d00a83a80ca6767f3eb4f  #   7221c  topic.alibabacloud.com    MongoDB 提升效能的18原則（開發設計階段）
  db466c72aba42f19b73eb86c22209606  #   7204c  www.modb.pro              MySQL8.0后的double write有什么变化 - 墨天轮
  7666e36cec2c5fd31b82eae21f936855  #   7166c  www.modb.pro              案例合集｜探索 TiDB Serverless 在新能源、跨境电商领域的应用 - 墨天轮
  63b60d9696e9cc24fcdaeb89c42fb825  #   7104c  mp.weixin.qq.com          PostgreSQL运维篇--日常运维集合①h
  3e6aea7a585dd2262279f6bf9853912a  #   7100c  mp.weixin.qq.com          MySQL 升级后查询性能跳水，排序竟成“罪魁祸首”？
  f30c184d6c036d4d3d20f77b75f37302  #   7100c  www.modb.pro              聊聊跨数据库迁移的数据比对那些事儿 - 墨天轮
  # === window 6/9 (501-600, avg 6033 chars/doc) ===
  276062bf162565814aa4e70e14b7db0d  #   7097c  time.geekbang.org         23｜大型研发架构团队的AOM实践-技术领导力实战笔记 2022-极客时间
  63f9298623511a70589f45ada9401398  #   7085c  mp.weixin.qq.com          字节一面：20亿手机号存储选int还是string？varchar还是char？为什么？
  9a76ee763859f779a95930cd98f997d1  #   7059c  mp.weixin.qq.com          爱奇艺大数据多 AZ 统一调度架构
  0af9a91eb4e5ff6d75d3b951a1a9b6e2  #   7058c  tidb.net                  专栏 - TIDB数据库在某省妇幼业务系统应用 | TiDB 社区
  22b190fe2638409e2dde4bc5f7dd2ad9  #   7019c  mp.weixin.qq.com          不同数据库的存算分离有何不同
  7e890105f953a5640b5d254878d8d5a9  #   6995c  mp.weixin.qq.com          MySQL好玩新特性：离线模式
  3398a6ca1b1c193f45e75fbf1aef8266  #   6915c  mp.weixin.qq.com          架构设计的悖论，复用是美好的还是邪恶的
  418a747501aa79be9d4ccc7e444cd1b8  #   6904c  mp.weixin.qq.com          从ibdata1到ibd：MySQL是如何管理数据“不动产”的？
  8039ad89e862bf9c76508e05dfac0b67  #   6879c  mp.weixin.qq.com          四大运营商都在用的国产分布式数据库
  88c8a4cc3a0652039894b5a92745d5d7  #   6795c  www.modb.pro              数据库慢SQL治理，让业务跑得更快 - 墨天轮
  05700a89acbe2a648d376dd8852b3607  #   6756c  mp.weixin.qq.com          Redis凭什么用单线程“干翻”了全世界？
  89d071d4305029494eb3bd42da658e75  #   6716c  mp.weixin.qq.com          当数据库的主要用户不再是人类：我们在 AI Agent 场景下的架构实践与思考
  7ce28791c2392bae5ca0e574fca75ca5  #   6706c  mp.weixin.qq.com          别再用五六个系统了，一个 PostgreSQL 全搞定
  0019408e20acf5f3555bc2459da94fba  #   6700c  www.modb.pro              DBA不仅仅是管理数据库--也要管理中间件 - 墨天轮
  fa037f1e0c76d28d3f33974805fa0ef8  #   6661c  mp.weixin.qq.com          小红书混合云架构下自用数据中心设计实践与探索
  1e49bc31193fce5f3844c70461bbb30a  #   6649c  mp.weixin.qq.com          MySQL 内存使用情况排查
  acd99de92c32e4d3c54c7d710714ccd8  #   6644c  juejin.cn                 再聊对架构决策记录的一些思考1 引言 第一次在社区发文聊ADR（架构决策记录）是在2022年8月份，
  919208eda3c2cbdf3d382535ea6588fe  #   6602c  mp.weixin.qq.com          B站直播S14保障全解析：高效保障技术实践
  1da8692fcd96135669d10058ee6ba62b  #   6593c  mp.weixin.qq.com          MySQL 全文索引
  bbd19a0c71e5da944ef7cac41569bc91  #   6582c  mp.weixin.qq.com          MySQL MRR优化：让磁盘不再“跳广场舞”！
  a9d7a197acc8356eb770b8865430d8bc  #   6498c  mp.weixin.qq.com          Redis缓存三剑客：穿透、雪崩、击穿—手把手教你解决
  d4e783dc4c78c15bde1f58f19bcd1e21  #   6455c  mp.weixin.qq.com          基于时间维度水平拆分的多 TiDB 集群统一数据路由/联邦查询技术的实践
  367d191d3c04c078f0fbe3096c65c976  #   6450c  mp.weixin.qq.com          MYSQL统计信息详解
  850a285ae70c97bb41ee585668fcbe40  #   6446c  mp.weixin.qq.com          放弃低效翻日志，终端排障终于进化了
  a6a1c3c0e928e9f97c6e3fc32e91ce5d  #   6438c  www.modb.pro              MYSQL 8 VS MYSQL 5.7 在复杂查询中 到底好了多少 - 墨天轮
  62a96627bcdda9e587dd92af4b4d623e  #   6437c  www.modb.pro              朗DBA福利来了！《YashanDB数据库概念手册》正式发布 - 墨天轮
  b41be37b46db4627fc9ee7b6e64673fb  #   6417c  mp.weixin.qq.com          不敢谈结果的技术负责人，迟早会被边缘化
  dd9ab01aa305698c82f77c8cc05f2e0d  #   6416c  mp.weixin.qq.com          MySQL表数据已经删了，为什么空间还是没释放？
  be202d2455ffbec2f8bb2d6c79f84f54  #   6373c  mp.weixin.qq.com          FlowScope：一款注重隐私的SQL数据血缘分析工具
  6b7cb5fbeb631271e97ede60ad1251a6  #   6342c  www.modb.pro              PgSQL vs InnoDB脏页刷脏对比
  72d0d29cf6257887b0bebe47a79221d1  #   6337c  mp.weixin.qq.com          如何看待顺序与因果一致性问题
  6871c262dcc21d3c3b7ce4ec16a536e6  #   6318c  mp.weixin.qq.com          一文聊聊我理解的技术PM
  7046890fce99a6992d160b718a16e300  #   6284c  mp.weixin.qq.com          在代码提交前，怎么把高风险 SQL 拦下来?
  bc1e1aaf502c59c8416a933e838f545e  #   6278c  mp.weixin.qq.com          数据指标体系搭建实践
  7c13c82a8913f6c6ef6bc8b0e1b3894d  #   6264c  totoroliu.medium.com      redis - 快取雪崩、擊穿、穿透 - Po-Ching Liu - Medium
  07a3538f5432289854dc9757b45aede7  #   6243c  cloud.tencent.com         如何精确监控DB响应延时-腾讯云开发者社区-腾讯云
  7cfa2cbed43e77115142e6d573d2f440  #   6217c  www.mongodb.com           数据建模 - 数据库手册 - MongoDB Docs
  1e8b6b87255ee140f42e8a9cc94f6190  #   6209c  mp.weixin.qq.com          SQL优化——我是如何将SQL执行性能提升10倍的
  2449de0973edcb07258a35e0781f30a6  #   6201c  mp.weixin.qq.com          技术负责人的述职报告应该怎么写？
  107b1af0b7b25d9fbe7c070feba47834  #   6197c  juejin.cn                 如何熟悉一个陌生系统在日常开发过程中，我们经常需要去承接一个陌生的系统，而且承接的系统都很复杂，那我
  74a5f008d96464e1db2c025ed58bf048  #   6185c  mp.weixin.qq.com          为什么 InnoDB 中的反向索引扫描更慢？
  b4c969cc750dfea59f6824a3c3a6884a  #   6183c  testerhome.com            千万级数据深分页查询 SQL 性能优化实践 · 测试之家
  ceb0b611cf2ea95c8d2a8cbcea078de2  #   6168c  mp.weixin.qq.com          GTID生命周期大揭秘：MySQL复制中的“身份证”如何运转？
  cb41093a0ba5cf6f375f46b3e1e3ff96  #   6162c  mp.weixin.qq.com          彩虹桥架构演进之路-负载均衡篇｜得物技术
  f963b5bf58c9daad2b17f798d93d4f3d  #   6161c  mp.weixin.qq.com          好问题，数据治理到底解决了什么啊
  e39884e8aca3522cda02bf919f91f604  #   6136c  mp.weixin.qq.com          全新升级！TiCDC 新架构试用通道已开启，解锁 TiDB 数据同步新体验
  6326e10c25c00731fb010b2ae6feab55  #   6095c  github.com                grafanafans/club: The path to learn observability 
  65e8c6a2dd8b1a4db8fc533d6848dd7b  #   6044c  www.modb.pro              Redis运维之内核参数调优 - 墨天轮
  77e5013bf00a42d07f4909ad8b5e7251  #   6013c  mp.weixin.qq.com          数据库自动化指标采集与智能评分系统实践与构想
  2fe21428b063a29374872e8f8c584d26  #   6004c  mp.weixin.qq.com          数据库半月谈（2026.3.21~2026.4.3）
  77d153d0f7a90db44f7655a7644ccfa5  #   5988c  mp.weixin.qq.com          初识 ASH —— 打开数据库的「月光宝盒」
  e1a687e18d0243cbe8e8ed2e126360a4  #   5988c  mp.weixin.qq.com          为什么分布式系统中的“顺序”比你想象的更重要？
  daa4411582408500b5be400ff24ce477  #   5973c  mp.weixin.qq.com          MySQL参数innodb_buffer_pool_size优化方法
  cb50472fbcf5ad315a90dc00d2119e33  #   5958c  mp.weixin.qq.com          从 Oracle 迁移到 TiDB，架构哲学的碰撞｜TiDB vs Oracle 第二篇
  f2cff3040d8b002c70ec2f3b8b0ecd8f  #   5933c  mp.weixin.qq.com          字节内部演进实录：Redis 迁移 Valkey，以一体化破解 AI 集群规模魔咒
  0dee63158798f5b970a4b7475220948d  #   5898c  juejin.cn                 MySQL 性能优化：从普通程序员的角度出发《普通开发者的MySQL优化指南》详解了常见优化方向，包
  085302eadb992a732a584739377a1221  #   5867c  mp.weixin.qq.com          你真的理解mysql的事务隔离吗？
  bb9d2cba9a3a2219b2597f9d440d9c0e  #   5844c  mp.weixin.qq.com          架构师掏干货：金融级核心系统从 Oracle 到 TiDB 的流程拆解与实践案例分享｜TiDB vs
  677109bf61d41cae7f523d3703c4a8ee  #   5832c  mp.weixin.qq.com          为什么DBA怒吼：MySQL小数必须用decimal？float/double是隐藏的财务刺客！
  e97c83626b9b5a9253ec49984f1f84ad  #   5825c  mp.weixin.qq.com          读数据不用等？MySQL的Inno引擎是如何做到“秒读”而不阻塞的？
  856f040a989f98c424a263b0de744481  #   5815c  mp.weixin.qq.com          持续改善的趋势和S曲线模型
  1281d483d3e4579a1f95fe17afaebeba  #   5804c  mp.weixin.qq.com          盛天网络 TiDB 落地复盘：从 MySQL 瓶颈到高效运营的架构升级之路
  c85e42bbafa0911a3a59b64603c92314  #   5804c  mp.weixin.qq.com          2026年如何打造一个不依赖人工的自动化运维体系？
  b030787670fe57cfc763df9379c316b4  #   5790c  mp.weixin.qq.com          MySQL 问题排查
  9188f9c7f4423974c11dd8222435fe12  #   5745c  mp.weixin.qq.com          如何分析 mysqld crash 的原因
  317f32cc2d1a887c396b32809ebb9252  #   5650c  www.modb.pro              DBA不仅仅是管理数据库--也要管理好需求 - 墨天轮
  5ed07e0d53e0bc8751e51c4f404aeebe  #   5649c  mp.weixin.qq.com          狂飙 50 倍丨TiDB DDL 框架优化深度解析
  4518a11992998316304cb48a35f79dd6  #   5649c  tidb.net                  专栏 - AmzTrends x TiDB Serverless：通过云原生改造实现全局成本降低 8
  a2deaba167d624726b75f88ce7683a87  #   5619c  tidb.net                  专栏 - 一文概述TiDB中的索引类型 | TiDB 社区
  81bdab7c9176334dde17b66f985af117  #   5602c  mp.weixin.qq.com          异地多活架构进阶：如何解决写后立即读场景问题？
  7b1aa4898308cb8d02cd86501b2bc5ef  #   5587c  mp.weixin.qq.com          [MYSQL] 服务器出现大量的TIME_WAIT, 每天凌晨就清零了
  fe7dbdfb7b57bb71d5d65b19716af0a4  #   5582c  mp.weixin.qq.com          互联网 | 千万日活背后，TiDB 赋能美柚核心系统高并发场景降本增效
  c7c239f59df48e5aa1513329f33b9345  #   5580c  mp.weixin.qq.com          MySQL后台线程大揭秘：你知道数据库里有16个“隐形员工”在007工作吗？
  e56da4cbd8272603dbfc1a2fdf866cc1  #   5578c  mp.weixin.qq.com          美团一面：ES 集群日增 1TB 数据怎么抗？90% 的人只报数字，结果面试就挂！
  83d996e5abc2f5d910e35c6f73dfa4f8  #   5576c  github.com                jerry048/Tune
  0f6de1c74d05b48b3022aded0ed1dfef  #   5569c  mp.weixin.qq.com          TiDB 资源管控的原理与实践
  5d395169523ccf6cbee6c8b59648b40d  #   5540c  mp.weixin.qq.com          分布式架构的“灵魂拷问”：数据一致性到底怎么做？
  d30f1d26fac1b8e04980a7f140c504c4  #   5533c  github.com                guide/数据库规范/Mysql数据结构设计及开发规范.md at master · wanfan
  662013dda71c61bbe2c09ad1428dad4e  #   5516c  mp.weixin.qq.com          MySQL内存为什么不断增高，怎么让它释放
  ff238e5e10abf4370f715e5e481a053f  #   5503c  mp.weixin.qq.com          什么才是真正的架构设计？
  d3f4272583bda5caffab5245ec27b236  #   5486c  mp.weixin.qq.com          个人网站的终结
  ef77d1b85520b85b8bf17c38272c37b8  #   5485c  mp.weixin.qq.com          MySQL学习第七天——MVCC底层原理及MySQL一周学习总结
  c9cdf8ce5968990b8f343b5fb685942b  #   5476c  mp.weixin.qq.com          分布式共识算法哪个最通用？Raft协议占有一席之地！（分布式共识算法-中）
  67f5b0495d2930c7dccaf6f4fde943a3  #   5448c  mp.weixin.qq.com          服务器突然断电，我为何丝毫不慌？揭秘MySQL DBA的“后悔药”机制！两次写（Double Wri
  3033a92d5b8ec0a31605d0312ae9898d  #   5418c  mp.weixin.qq.com          [MYSQL] 记录一下undo太大(Disk is full)导致数据库宕机案例
  652496fd9d65b8fb0e3df460c3d85f3d  #   5409c  mp.weixin.qq.com          面试官：说说四层和七层代理的本质区别？——从 OSI 模型到千万级集群的拆解指南
  d56385bf638090498b47d885e2ed6b43  #   5394c  mp.weixin.qq.com          免费开源 PDF 神器，啥功能都有，PDF 需求全覆盖～～～
  4e63b616ab207e733ae09e3b879e2637  #   5383c  mp.weixin.qq.com          MySQL日志系统：持久性和一致性是如何实现的？
  b0f0afe2c0476d3392780695022cc50a  #   5383c  mp.weixin.qq.com          数据同步要灵活隔离？TiCDC 独立部署 vs 混合部署该怎么选？
  d034327db4b36bf04fd4a89d5c0471cb  #   5361c  mp.weixin.qq.com          基于内核视角的MySQL巡检脚本设计与实践解析
  765b189c8a79c9f58e7574de2b359fb8  #   5343c  mp.weixin.qq.com          如何理解高可用数据复制原理
  85a3ee4b98438113378489e6e8029f92  #   5342c  mp.weixin.qq.com          停从库,为啥主库报错[ERROR]mysqld:Got an error reading commu
  48e5bb727a8d69b48b14d4e7cf1171d1  #   5336c  mp.weixin.qq.com          淘宝信息流融合混排服务升级
  9a132f2b394a5efe8b50c0abaf80ecb7  #   5321c  mp.weixin.qq.com          凌晨四点，线上CPU告警，绩效没了……
  b697a6325edb82e5bff5f2f0f34c4c3a  #   5309c  mp.weixin.qq.com          MySQL防'打脸'机制-内部XA事务：说出去的话，如何保证一定能做到？
  b26fd66bcb8b3d2f7cef69ec86ef235f  #   5281c  mp.weixin.qq.com          Claude Code都在用！扔掉向量数据库，这个开源项目让RAG准确率飙到98.7%
  1159c05117645b15e71f1e88c68fd704  #   5268c  www.yunweipai.com         渗透测试报告一键生成工具 - 运维派
  9c16734f4f56ad61ffa56829b66f32d1  #   5266c  mp.weixin.qq.com          MySQL的这个参数能让性能提升300%！你居然还不知道？
  49c909864f6e03166faa260b1a289797  #   5246c  mp.weixin.qq.com          PostgreSQL这个特性，害惨了搞数据恢复的兄弟们
  ce02df5a739df7820a4d3c2094ac4340  #   5245c  mp.weixin.qq.com          [MYSQL] mysql空间问题案例分享
  # === window 7/9 (601-700, avg 4569 chars/doc) ===
  97dffaf7176f45379b87d01e34d47765  #   5244c  mp.weixin.qq.com          MemFree 辣么大，为啥报 out of memory？
  1800fe557ac5208c408f5d630bc6ae23  #   5229c  mp.weixin.qq.com          MySQL 性能优化：真正重要的变量
  4f288e377446e893136755b1f417aa89  #   5217c  mp.weixin.qq.com          什么是索引下推？什么是索引覆盖？什么是回表？
  605c8df3f7810b55f87fb6656e8e5e94  #   5216c  mp.weixin.qq.com          拼多多一面：说说缓存淘汰机制 LRU 和 LFU 的区别，秒杀场景下应该如何选择？
  35474ce24b41d8442b3ea28170c7f494  #   5211c  mp.weixin.qq.com          Redis 集群为什么只能用 0 号数据库？
  3165ecb82736644587556f12b95b1f7a  #   5198c  mp.weixin.qq.com          PostgreSQL 19 即将预发, 最值得期待的特性一览
  e8881308e198ef0269283514e5caa4b3  #   5174c  mp.weixin.qq.com          阿里订单系统演进史：从单体到多活架构全公开！
  d2ba048e0f911a5cdd01fd9fa96b859c  #   5172c  mp.weixin.qq.com          效率+100%: MySQL运维脚本大揭秘
  67b9239c1e117f57662e78ccd279613b  #   5161c  mp.weixin.qq.com          如何给MySQL的字符串字段加好索引？
  ed6e2de3e9c4d04a69561dd494d4fa1e  #   5154c  mp.weixin.qq.com          经典的“IOE”架构，又要爆了？
  03157529f9534b578a94fb57dc20c6a7  #   5151c  testerhome.com            【稳定性】浅谈团队如何做好系统稳定性 · 测试之家
  f196e3b48eaa71038dc1d55cec4e9dce  #   5136c  mp.weixin.qq.com          七年，从 TB 到 PB：TiDB 助力马上消费金融核心系统演进
  15fc67fda4eb410aaca2c5e353ebfe55  #   5110c  mp.weixin.qq.com          面试官：MySQL 空值字段应该保存 NULL 还是默认值？
  4af2fd950bcfd970bd8551041d500f03  #   5107c  mp.weixin.qq.com          监控工具卷成这样了？Grafana 13一口气放了50个大招，我挑了最实用的8个告诉你
  75f22d95afec6fbdec8ad6a7b593cde7  #   5102c  mp.weixin.qq.com          MySQL 8.0不再担心被垃圾SQL搞爆内存
  cd78ff0348afb430117e1b1594b25d0a  #   5076c  mp.weixin.qq.com          数据库流程管理功能：防范灾难性故障的最后防线
  89f733a8723e36f2f85fe570fbe1ce02  #   5066c  mp.weixin.qq.com          提升用户体验的UUID设计策略
  f6283fbfef4f7fcabb4815abf6dd5846  #   5058c  mp.weixin.qq.com          架构师必备底层逻辑：分层架构设计
  c21523ba09f0a9369ac170ed350c6716  #   5045c  www.modb.pro              DBdoctor产品体验报告 - 墨天轮
  2296c5e7ce59cc0f3284c0606862789b  #   5041c  neoremind.com             Neo的技术博客 广告系统的平台架构与交互流程 |
  04b541b98be61d1cc8ac33859a4d8a26  #   5012c  mp.weixin.qq.com          二级缓存架构极致提升系统性能
  611bb676a511fec6025dd44a32121663  #   5004c  mp.weixin.qq.com          从 MySQL 到 TiDB：调研、测试、迁移、上线全流程实施方案
  eb0768ebcf35cf0e987dc2e6e6ca9fac  #   4984c  mp.weixin.qq.com          MySQL时区踩坑记：为什么time_zone=SYSTEM会让你的数据库慢如蜗牛？
  1a1779077a8ec0f1dc5b805ef4d6f082  #   4971c  mp.weixin.qq.com          分布式系统不可靠时钟问题
  98be07551b410eef63f5208c98f6f61c  #   4968c  mp.weixin.qq.com          指标监控
  0c05cc4d2aab376a987e7ad6984ca19d  #   4950c  mp.weixin.qq.com          seekdb 1.2.0 发布：主备容灾上线，整库秒级克隆实现了
  be34ff8663b0ba98397851ad3de8c7e8  #   4940c  mp.weixin.qq.com          一起免费考 MySQL OCP 认证啦！
  5f7bdc0ef060d0efff808773e7782c67  #   4938c  mp.weixin.qq.com          重生之MySQL 索引失效六大陷阱
  ef89b334588239e3c1f76d0e4c1ca8ff  #   4922c  mp.weixin.qq.com          Oracle 翻车之作：MySQL Cluster 的失败根源与设计原罪
  b59a231fcf0f9467931c6343853c22b8  #   4895c  mp.weixin.qq.com          MySQL8.4运维实录：3个案例带你吃透MySQL并行查询，大表扫描不再头大
  55dd89e2ce321cd9badca57499b4de1a  #   4892c  mp.weixin.qq.com          你要做的是技术负责人，还是技术领袖？
  f33be720942211fe71ed6836820570e1  #   4891c  mp.weixin.qq.com          从 Oracle 迁移到 TiDB，不止是技术替换，更是数据库范式升级｜TiDB vs Oracle
  b2a72b1f792bbd5c3e6baf7bf5a17911  #   4869c  tech.meituan.com          美团MySQL数据库巡检系统的设计与应用
  ef1d7c7aad615b5d23ecb62a7d6419c4  #   4865c  mp.weixin.qq.com          高级SQL优化系列之外连接优化
  e6f9cffbc2723d3fc1b8f8cd5e9fc12b  #   4851c  mp.weixin.qq.com          MySQL 的 10 种高级 SQL，性能飞升 10 倍！DBA 不会主动告诉你
  e2e4a77b2fc8eec2a6cfb07739b41c84  #   4823c  mp.weixin.qq.com          替换MySQL|统一数据库跨云架构，批量处理能力提升80%
  0aafc5cc111c00e82970042bc8bcf339  #   4821c  mp.weixin.qq.com          如何画好架构图：7种常用类型与示例
  dc4da16d552aec6627bc814718ea772a  #   4803c  mp.weixin.qq.com          你以为DROP TABLE只是简单删表？MySQL底层到底在偷偷干什么？
  75e91fdee79fc69993f32ae16a7df548  #   4798c  mp.weixin.qq.com          汽车之家携手 TiDB：业务增长 20+ 倍，一套 HTAP 数据库的规模化实践
  3692e564c188bfff113d0b44cdf7e1cf  #   4786c  mp.weixin.qq.com          04 | 能有效揭示数据库性能瓶颈的数据集
  dd56bb459d0f428afe156adecbfd2455  #   4759c  tidb.net                  专栏 - 一文了解TiDB的数据对比工具sync-diff-inspector | TiDB 社区
  72ef824ce9b8942f1539498272bee9f4  #   4759c  mp.weixin.qq.com          数据库优化
  a7a6a3bab63361e278b50e0f8a513da5  #   4741c  mp.weixin.qq.com          数据库之路——TiDB + AiOps，迈入智能运维新时代
  82ca5379bc881cf9c7fb9bcc7785428c  #   4699c  mp.weixin.qq.com          架构提效的矛盾和矛盾的主要方面
  cb938de003553777024e704a83f4b688  #   4678c  mp.weixin.qq.com          可观测性三重奏：Logs+Metrics+Traces的协同作战
  e384c3abb1f2ec298174c21666b0cc67  #   4649c  mp.weixin.qq.com          MySQL生产实战优化（利用Index skip scan优化性能提升257倍）
  364f4dfffda278498ec5ad5699969eeb  #   4640c  www.kancloud.cn           profiling中要关注哪些信息 · MySQL FAQ系列整理 · 看云
  14864ba5b579b1db6ae864769d76b093  #   4632c  mp.weixin.qq.com          Day 28｜大厂怎么用 PostgreSQL？
  2331b3144809d3d7f9412ed9cd0d0341  #   4628c  mp.weixin.qq.com          暴揍ELK 痛打Loki - VictoriaLogs 搭建Syslog日志收集存储系统
  baf2bcd9d70b187a627c07e5e7a2a108  #   4591c  www.modb.pro              DBA转型的十二宫（3）唯技术论
  87ba322240f941f18209b19f0c2c47c4  #   4586c  mp.weixin.qq.com          跨机房ADG因带宽限制引起的GAP问题
  d73fc36354cc01a508c070aa678423e5  #   4545c  mp.weixin.qq.com          远程开发和 CI 一回事
  0c7834f8ba6b520d05f5d04933e9c78b  #   4529c  tidb.net                  专栏 - TiDB 三中心'脑裂'场景探讨 | TiDB 社区
  cc38ab37dcf288409015dfacbd09ad91  #   4528c  mp.weixin.qq.com          中国农业发展银行智能支付平台分布式数据库建设实践
  e0477f3220539ed579cca22dad329888  #   4499c  mp.weixin.qq.com          这才是“AI原生数据库”
  3c5969ada6e425d2b91e3c2d25bd33c3  #   4461c  www.modb.pro              从一个故障案例谈数据库运维中的数字化分析之路 - 墨天轮
  a73b1b80834904a0d6e0700e4c32caab  #   4456c  mp.weixin.qq.com          TiDB 赋能半导体产线运营：以毫秒级数据同步、零超时故障转移，实现稳定性与运行效率双突破
  e1a168c44200c635a475549f4c5a5cc3  #   4406c  mp.weixin.qq.com          运维做好述职-“让价值被看见”
  9929353f479a3a7a23234d1e51b7376a  #   4393c  mp.weixin.qq.com          攻克多版本运维难题：爱奇艺百套 TiDB 集群升级至 v7.1.5 实战宝典来袭！
  6071e9a6c8582c6e7686babe133f4129  #   4380c  mp.weixin.qq.com          Redis基础知识典藏版：架构设计、功能特性、应用场景、操作命令……
  96c9d9f34828ceb755d35e4beffb4249  #   4378c  mp.weixin.qq.com          MySQL里藏着一个会自己长大的文件，90%的DBA都忽略了
  2c0e221a4d2a3d0e11df8e9bcdd8514e  #   4357c  mp.weixin.qq.com          前任开发在代码里下毒，支付下单居然没加幂等
  25e668d98d19f77bb58ca2a397715405  #   4321c  mp.weixin.qq.com          架构师必备底层逻辑：设计与建模
  4aef6f739e31d7fce382d6b841946eff  #   4321c  mp.weixin.qq.com          InnoDB为什么不用跳表，Redis为什么不用B+树？
  807f235ec633096f7fa295142a1aa586  #   4311c  mp.weixin.qq.com          多租户隔离最佳实践：每个租户一库
  724fa5327338b9b1ca3c28d24cde30d6  #   4301c  mp.weixin.qq.com          被闭源坑怕了！国产数据库为什么死活不敢再抄 MySQL 的底？
  146bdb7126f5ea288ca0706e05780fe4  #   4299c  mp.weixin.qq.com          SQL秒变RESTful API：一款让DBA和后端都点赞的神器
  dcf3bfb86e729a8eb661acd62c6dbfd8  #   4294c  mp.weixin.qq.com          不止数据库替换，更是架构的跃迁
  d031211a2d6e799ebde9a48c5f5e255b  #   4276c  mp.weixin.qq.com          MySQL 数据库认证考试介绍（2024 版）
  ef788f772e3b94f5adcf1c9654232a05  #   4250c  mp.weixin.qq.com          一致性协议到底选 Paxos、Raft 还是 ZooKeeper？权威解读来了
  f284001f410a32a012f8b5bf217e5792  #   4247c  mp.weixin.qq.com          兆翔科技：利用TiDB 助力福建四大机场核心系统高效运营
  24a666bdd34b1551caf3ff2bdc6133e2  #   4246c  mp.weixin.qq.com          Rakuten 乐天积分系统从 Cassandra 到 TiDB 的选型与实战
  386108d46b4f685b9b9ace50f1922627  #   4227c  mp.weixin.qq.com          深度参与TiDB社区建设看到的新场景和价值
  5b4bc25279258c48724bcc837524acd5  #   4218c  mp.weixin.qq.com          运维加薪技术——微服务拆分规范
  660aeb24aa4b3f8caac70aa7af0129c0  #   4214c  docs.ninedata.cloud       什么是 NineData - NineData Docs
  9098d0816007e761ad4aafc541b1a6cd  #   4186c  mp.weixin.qq.com          如何度量高可用架构设计指标
  b99633e6d09d838bd40f4241534d131e  #   4174c  mp.weixin.qq.com          故障分析 | 为什么 MySQL 8.0.13 要引入新参数 sql_require_primary
  9f30c18db7a9308c4d4fc06a8b4e45c1  #   4168c  cloud.tencent.com         MySQL ProxySql 由于漏洞扫描导致的 PROXYSQL CPU 超高-腾讯云开发者社区-
  987fea908c8a8365e5cacfb7ff206ecd  #   4166c  mp.weixin.qq.com          双活、异地多活架构怎么设计才不翻车？
  70cf21c5606f0e8a9494c4b5d16ebbec  #   4128c  mp.weixin.qq.com          认知密度：为什么聪明的人越来越沉默了
  854ced78c28960d8bc5e6454498d6797  #   4119c  mp.weixin.qq.com          TiDB架构师：数据底座已成为企业级 AI 落地的核心变量
  22b20b82733fcb8951ce4e321501bd03  #   4073c  mp.weixin.qq.com          DuckDB新版本发布，求求你给友商留条活路吧
  9f3f6317d944f32807f64c9f8a6140a6  #   4038c  mp.weixin.qq.com          MySQL 8.0.34 高可用集群OOM故障分析与解决方案
  65a4c9cc26789c98e196bd0be9c0a1e3  #   4022c  tidb.net                  专栏 - 为什么说TiDB在线扩容对业务几乎没有影响 | TiDB 社区
  54bf88b72446638d64f703c20b0e4b3c  #   4011c  www.modb.pro              数据库常见性能故障应急场景 - 墨天轮
  8d31234716fdeda76cb7fffa732202f6  #   4004c  mp.weixin.qq.com          为什么DBA要求MySQL表索引不能超过5个
  44d83d0f5a4348f978a8cea38026c881  #   4001c  mp.weixin.qq.com          云数据库RDS MySQL Serverless已来
  9ea1332c634ea50d1442fa530ea9c633  #   3998c  mp.weixin.qq.com          新特性：用户管理升级，角色权限一目了然
  1917eb14d34aacecd7169b6ca66c3fc1  #   3992c  mp.weixin.qq.com          MySQL死锁全解析：从原理到实战的破局指南
  44f04696c333a9712822825f2f257b78  #   3972c  mp.weixin.qq.com          我们运维的 CMDB 模型是不是都做错了？
  a67aa39c0aca1441e7759fb1124a53e6  #   3963c  mp.weixin.qq.com          听劝！彻底搞懂 MySQL 8 InnoDB 缓冲池配置
  0548e80783f89f58f8de9622f4d13675  #   3963c  mp.weixin.qq.com          微服务拆错一步，项目直接崩！资深架构师这样避坑
  7c66d17390ff9a6df1b863861bd07b29  #   3960c  segmentfault.com          后端 - 索引下推，这个点你肯定不知道！ - 艾小仙 - SegmentFault 思否
  742eb8ef288e0836e4a5c06bec6ba6ab  #   3938c  alwq.xyz                  简洁优雅知识库 FastGPT 快速部署
  9449fab062d488b9ec305b64000d070a  #   3923c  mp.weixin.qq.com          [MYSQL] 当一个PAGE里的数据全部被delete之后, 它还会存在于Btree+中吗?
  99ab36a846be3cd2bd2237ea2ff882da  #   3917c  docs.pingcap.com          TiDB 整体架构 | TiDB 文档中心
  a13c5dc1c94f07a09c2ccd6119ab715b  #   3909c  mp.weixin.qq.com          为什么越来越多架构师开始重新思考“存储过程”？
  0504718023db4a726279fd687d4bcab0  #   3909c  mp.weixin.qq.com          SQL优化实战：从慢如蜗牛到快如闪电的必杀技
  97425cfd61349709f701d3e36551b7cf  #   3900c  www.modb.pro              mysql 内存使用率高问题排查 - 墨天轮
  55eb11785caa1e1fa9d78eede1117a41  #   3867c  mp.weixin.qq.com          SCALE | SQLFlash 在 SQL 优化维度上的表现评估
  # === window 8/9 (701-800, avg 2891 chars/doc) ===
  69639d8704c7656d30176be0d63596f7  #   3852c  mp.weixin.qq.com          告别 MySQL 分库分表， 重庆富民银行通过 TiDB 实现批量场景降本提效
  82fd48ba9e85d03f78cb5a709b291ebe  #   3843c  mp.weixin.qq.com          常见分布式事务理论梳理，2pc,3pc,AT,Saga,Seata
  1d02b0538b388d871bc9b697c65cbafb  #   3828c  mp.weixin.qq.com          写了 5 年 SQL，才发现可以用 (a, b) > (x, y) 这种神仙写法！
  a6c10f51f8156600506205716e39208e  #   3821c  mp.weixin.qq.com          多租户架构设计
  928473265cdc10481ccbce541bba4a5b  #   3813c  mp.weixin.qq.com          '慢SQL'治理的几点思考
  750493433708d91ff8f306711bd3cca0  #   3732c  mp.weixin.qq.com          PostgreSQL 19 最值得关注的新特性
  53cdbc61c404deac009700776ed6cb31  #   3728c  mp.weixin.qq.com          面试官：MySQL 内存飙升，可能是什么原因？
  8514157bd68ad683d49d03d79ddc7ce5  #   3715c  mp.weixin.qq.com          SQL Origin：一个指纹打通 SQL 全生命周期治理
  d386afd23ee5ad3fa31a559ace99110c  #   3697c  tidb.net                  专栏 - 干掉DBA！产品经理运维 TiDB，用非技术手段攻克技术挑战 | TiDB 社区
  3b3cf87f8d65e7fa52518d6a94307d20  #   3666c  mp.weixin.qq.com          “降本增笑”，B站又血崩了！底层逻辑是：一个顶级架构师，胜过1000个平庸的架构师
  255ef4a415237f487394694346498aee  #   3578c  mp.weixin.qq.com          全面监控太优雅 , 太6了, 运维强推
  3bc37e5adcfbdfb28c86d3d961b53a10  #   3572c  mp.weixin.qq.com          小心！那个中划线可能让你的MySQL数据库“折了腰”
  770a5ded7afe237c255adb98bb24947c  #   3563c  mp.weixin.qq.com          系统容灾体系及架构设计
  25c9b2109c8fc4388b2b7714d0cee824  #   3558c  mp.weixin.qq.com          还在用 VARCHAR(36) 存 UUID？试试 BINARY(16)，性能提升 50%！
  741dfcb409d3cd9199a0bb815cc32d15  #   3554c  mp.weixin.qq.com          MySQL防丢数据秘籍：双剑合璧的redo log与binlog
  14abac1ce6e1ea52c5e109f2b0e10a9a  #   3550c  mp.weixin.qq.com          MySQL查询优化的三种处理阶段：Index Key、Index Filter 和 Table Fi
  02cb05d407f170aac442804e36e6537e  #   3548c  mp.weixin.qq.com          5分钟搭建AI知识库！这个开源神器太香了
  177c701a8fcabb8769c4e6695fa54383  #   3517c  mp.weixin.qq.com          MySQL InnoDB MONITOR 性能监控
  fa843817c6394b172bad7d0f77bb51fd  #   3505c  mp.weixin.qq.com          不仅是“去 O”，更是构建企业数字化的新底座｜TiDB vs Oracle 第四篇
  5a3e9a95c25c9898938317a9e04aa65a  #   3488c  testerhome.com            对号入座，快看看你的应用系统用了哪些高并发技术？ · 测试之家
  a83ab541d88ff0e8ac0314cd43a161a1  #   3473c  testerhome.com            如何做标准化？| 京东云技术团队 · 测试之家
  26d1287a6f77a08fffc38a6a01a1c9df  #   3453c  tidb.net                  专栏 - TiDB VS MySQL 场景选择 | TiDB 社区
  4ece2a5d71108290a43bd9aa6fe88d14  #   3443c  mp.weixin.qq.com          MySQL惊天陷阱：left join时选on还是where？
  68e3486ba833991fcd34b4368e6479b0  #   3389c  mp.weixin.qq.com          分布式事务一致性方案有哪些？先从XA事务（2PC与3PC）讲起！（分布式事务一致性解决方案-上）
  7267591ce00b943de3b24ec5f5f740d1  #   3320c  mp.weixin.qq.com          浙江交通集团：如何用一套 TiDB 技术栈支撑 7 大核心系统且实现“零事故”
  2b7f33be7031ea105eaa09a6193da552  #   3286c  mp.weixin.qq.com          阿里一面：MySQL 一张表最多支持多少个索引？16个？64个？还是无限制？
  b4c8e7b20e6063fdfaa5c262d694565b  #   3277c  mp.weixin.qq.com          以后云数据库将全免费!
  36b7e4bac8908b8e68432c259b73e076  #   3265c  mp.weixin.qq.com          解密百万并发秒杀架构：如何在1秒内抗住流量洪峰
  ec00423c5e1578b5ff5fc4032f41879a  #   3265c  mp.weixin.qq.com          MySQL出息了! 大败PG用的这个case
  c1131b0454f0681cee2e3419ff02c5fe  #   3227c  mp.weixin.qq.com          MySQL数据库idb文件过大处理方法
  27df39c6c465e4137152d658cc473bdf  #   3224c  mp.weixin.qq.com          NL2SQL：因果推理 vs 流程挖掘，谁更“懂”业务？
  3af90e819f357a240e851eb7f9e58f5c  #   3219c  mp.weixin.qq.com          技术译文 | MySQL 8.4.3 和 9.1.0：显著提升性能！
  5d5b8506afba43b65c7fd1af35337f77  #   3191c  mp.weixin.qq.com          TiDB DR-Auto-Sync 同城双中心的原理与实践
  7510120543c62ef992b7ecacd517fb03  #   3181c  mp.weixin.qq.com          3分钟时间理解MySQL索引下推：概念、条件、原理以及代码验证
  dd54183c3ee2b4ab14b53296108bb227  #   3177c  mp.weixin.qq.com          面试题：在 Redis 中，什么是 “缓存穿透” “缓存击穿” “缓存雪崩”？分别有哪些解决方案？
  88e03927022b034a07fc05697d27b429  #   3168c  mp.weixin.qq.com          mysql提升10倍count(*)的神器
  1cacda269b0dafc0d0c693ab78fcb2c7  #   3147c  mp.weixin.qq.com          淘宝质量保障之主动预警能力建设
  d6456d4db39ebc05b54f99b5d89beb5b  #   3146c  mp.weixin.qq.com          平凯数据库云服务正式发布，极致弹性带来 50% 降本
  1779f76e21a977df4b808288e4b2132a  #   3143c  mp.weixin.qq.com          MySQL 核心模块揭秘 | 51 期 | 开年暖场，回顾和展望
  e7468c61306e14e57dd688156495c3e3  #   3124c  mp.weixin.qq.com          一文了解 TiDB 存储架构基本原理
  5a1f568435e61abfbf5dd495d88fda9b  #   3074c  mp.weixin.qq.com          如何构建故障容忍的分布式系统
  c91b1db2c7105f51d3969f4b99c16d01  #   3067c  mp.weixin.qq.com          核心系统数据库迁移中，那些被“1:1 兼容”掩盖的隐性成本
  238bc7725675313cf3055d2b4cad8c5b  #   3052c  mp.weixin.qq.com          ETL的“终结者”？DBA如何看待HTAP的概念、价值与实现路径
  2cb60eb63c026e43f8ccb22b013c82db  #   3046c  mp.weixin.qq.com          MySQL的自优化秘籍：AHI如何智能加速你的查询？
  b9f6018d8fd607af84c230d806fefd40  #   3023c  mp.weixin.qq.com          MySQL参数调优实战：20个关键参数的最佳配置
  b21fae0e09bbe6f464d740707f77117a  #   3018c  mp.weixin.qq.com          MySQL 并发线程的理解
  f27b82079b8733bedc70f25fa53da604  #   3012c  mp.weixin.qq.com          面试官：如果某个业务量突然提升100倍QPS你会怎么做？
  b0f328c98f3099e1010db8564c79a3e1  #   2970c  mp.weixin.qq.com          MySQL 8.0版本mysqld消耗大量主机内存不释放还可能导致数据库重启【排查与解决】
  027e57475b162bf6d68064e5223762fc  #   2921c  mp.weixin.qq.com          优秀架构师必备：技术领导力的六项核心修炼
  372f7d390eae89de0de5f617d18d4fdd  #   2904c  mp.weixin.qq.com          MySQL数据库巡检报告，一条命令搞定，省心又省力！
  f74081dd01bea8ccc790f779a7a8a47c  #   2902c  mp.weixin.qq.com          慢SQL优化别白忙！一份“报告”让老板秒懂你多强！
  a0293ae142b48d3d7526cc669c9b0475  #   2897c  mp.weixin.qq.com          问系统能支撑多少并发时该怎么回答
  8495e50507b55ca0516bab7e6232ab8b  #   2875c  mp.weixin.qq.com          MySQL 回表检测太难？这个SKill 帮你搞定
  fbcf77bf952164ea6e86aacf5457ec21  #   2812c  mp.weixin.qq.com          MySQL部分最新特性快速预览
  a496ce8991961e0a30a98cdcb608319d  #   2790c  www.sre-devops.info       使用MariaDB Thread Pool實現DB端的連接池 - 進擊的網管Jay
  345dc565dcbbcc185080995f9926e796  #   2758c  mp.weixin.qq.com          TiDB 团队 11 周年的思考和判断
  a5942d69737dabb237ff6442c5b6b6c4  #   2754c  mp.weixin.qq.com          14TB 之后我们才承认：MongoDB 不是“灵活”，是昂贵
  d394fdc6ce7ee33faaf1410ed7239637  #   2739c  mp.weixin.qq.com          MyBatis动态SQL中的'引号陷阱'：一个让排序失效的隐蔽Bug
  bb1cb5fccc38cebad1d22ba9963fd05e  #   2728c  mp.weixin.qq.com          系统容灾体系及架构设计（续）
  887c7e2b69aa6bead1af5e79229cd57c  #   2668c  mp.weixin.qq.com          程序员，当你意识到这一点，说明你成熟了...
  e6411bf956d1fcd106513aaaaa682ec0  #   2642c  mp.weixin.qq.com          数据库允许空值(null)，现在我有点后悔了，悲剧的开始（1分钟系列）
  3c5d927871fd91e17ed6408eec088c71  #   2636c  www.modb.pro              MySQL 8.0 OCP 1Z0-908 考试解析指南(三)终结篇 - 墨天轮
  357b0755039b4c7a0f4d48da5408d9b8  #   2621c  mp.weixin.qq.com          面试官：如果你是架构师，PostgreSQL 和 MySQL 你选择哪个？
  c9ca56db7d4e7a2a07b40175b0370203  #   2607c  mp.weixin.qq.com          从微服务到单体：究竟是什么让架构走“回头路”？
  613ad8fa92bb5155bdd8b6a8eafcd10a  #   2591c  mp.weixin.qq.com          别再卷技术细节了，不值钱。。。
  82d9c578076157c35ced42d85a3e94d1  #   2590c  mp.weixin.qq.com          20.1k star! 太强了，一个浏览器直接能跑20+种操作系统！
  a5401f96c8b6aabf360c82cc55070bbf  #   2584c  mp.weixin.qq.com          MariaDB 12.0 震撼上线，助你打造稳定可靠的数据库底座
  51ee295b6fd03c36d8fc819a10cdeda1  #   2573c  mp.weixin.qq.com          从 MySQL 迁移到 TiDB 成本详解
  d8d64e1cf5a12828ca30a9f84dce3ff6  #   2563c  mp.weixin.qq.com          数据库指标集的设计思路
  c89b59697d52f0578a0ee32178ec85cd  #   2550c  mp.weixin.qq.com          在连表查询场景下，MySQL隐式转换存在的坑
  1ae03029be522fca5ed9024238fc1dec  #   2543c  mp.weixin.qq.com          【ORACLE优化案例】索引小技巧，存储null值
  80755396e73533176ba1510ae02d1664  #   2522c  mp.weixin.qq.com          DBA性能调优内功心法（十五）：知己知彼篇——从多列到系统统计，构建性能优化的全局视野
  5037fe8c2b130ac3ec51ab1522d6e874  #   2518c  www.sre-devops.info       Galera Cluster真的沒有同步延遲嗎?- 進擊的網管Jay
  addde3560fe66ae3d4eacc59c2ec85d4  #   2472c  mp.weixin.qq.com          MySQL磁盘一夜爆满？900G临时文件背后的“JOIN+ORDER BY”陷阱
  81bbce42402ad3067c110d8408b6b2f2  #   2471c  mp.weixin.qq.com          MySQL一条命令生成数据库巡检报告进阶-生成更好看更美观的报告
  dec8812e492c45a90c01d2bf14be0e5f  #   2460c  mp.weixin.qq.com          生产环境 CPU 飙升 100%！别再去翻日志了，这 3 行命令教你 1 分钟定位代码行号
  8011ad97f55be5ff49fb57fe47b36b7a  #   2459c  www.modb.pro              MySQL生产实战优化（利用Index skip scan优化性能提升257倍） - 墨天轮
  7e84f0d02bc9c52eb91888f94b8c1414  #   2438c  mp.weixin.qq.com          mysql字段数量限制为啥是1017 ?
  8e613f1d9f82451d3aa96ae12dc43051  #   2433c  www.modb.pro              AWR报告暗藏的致命误区，90%的DBA还在踩坑！ - 墨天轮
  ba66f907d6293014bd76b120e9e5b65c  #   2392c  mp.weixin.qq.com          TiDB集群可用区级别改造的探索与实践
  ae6616771df941ce874202bb047524f3  #   2386c  mp.weixin.qq.com          TiDB 8.5 LTS 发版——支持无限扩展，开启 AI 就绪新时代
  49507050e386025f0751e8128842eef2  #   2357c  mp.weixin.qq.com          数据治理现在那么火，能治理好吗？
  569e1013099d129639d9057381dac1fa  #   2341c  mp.weixin.qq.com          讲真，没见过技术这么差的架构师！
  de99e3e48160c230fca72f06a3bdd20b  #   2320c  mp.weixin.qq.com          案例分享 | DBdoctor助力某大型期货厂商，破解核心系统被动运维之痛
  860d10697bbb76c235fcd77274dab0fb  #   2183c  mp.weixin.qq.com          学会这招轻松解决数据库分布式锁痛点
  f47e6048987f7b4eeb3199c1fc30c45c  #   2150c  mysql.taobao.org          PolarDB MySQL跨可用区强一致解决方案
  cbde1a52bbe1f2e64dfbfb3166c29f2e  #   2149c  mp.weixin.qq.com          一分钟阅读:架构师的核心能力
  635aa2ecfde696d83771924db73a3d8c  #   2138c  mp.weixin.qq.com          SQLFlash 档案：将 SQL 性能优化从专家经验重构为开发者标配能力
  1c947f799503ee9786c18815202eb1cf  #   2127c  mp.weixin.qq.com          面试官最爱问的MySQL日志问题：3大日志工作原理图解
  d5c67c9dabfacf13dbf7d7b7a460938a  #   2079c  mp.weixin.qq.com          数据库高可用架构的尽头是RAC吗？
  0f8ea805b7c8a987c468e839a885342f  #   2069c  mp.weixin.qq.com          架构师和技术总监之间，差的不只是技术
  b1127af19f62ee155c05f10917dc6e76  #   2056c  mp.weixin.qq.com          如何介绍你负责的测试项目并展示自己的亮点
  03d5679966d22435f119ed5d4289921e  #   2052c  mp.weixin.qq.com          图解 MySQL 第二篇 | KILL 的工作原理
  bc6fd79aec0f956697f37e8e6e1756b0  #   2028c  mp.weixin.qq.com          一款开源的零代码开发api服务，这些核心亮点绝了
  4f0b91ec24b33fd77f9ee4c0bd56977f  #   2009c  mp.weixin.qq.com          深夜网络故障秒解决！这个开源监控工具让运维告别通宵
  2825a56e66830c46b330f4457bf324e5  #   1977c  mp.weixin.qq.com          一个晚上, PG 19 又干出1个五星级特性
  8742fddec1aac99f2ec7f7ae4655c089  #   1971c  mp.weixin.qq.com          MySQL8第108期-性能优化之数据库结构1
  6b53c975ffe7e5c0754c8fa7e7917a15  #   1961c  mp.weixin.qq.com          Redis 8.2 来了！性能暴涨 49%，单机破百万 QPS
  063654e866338a631e508899ea458555  #   1959c  mp.weixin.qq.com          别再让IT背锅了！数据质量的第一责任人是业务
  e5f93f1a236836228efea418a70ea536  #   1952c  mp.weixin.qq.com          「合集」MySQL 8.x 系列文章汇总
  # === window 9/9 (801-821, avg 1570 chars/doc) ===
  138b23cffd575b9b0021fa7e1a840eaf  #   1943c  mp.weixin.qq.com          透明分布式是蜜糖还是毒药?
  f23997bda0e84488df8ab87e753bb69c  #   1910c  mp.weixin.qq.com          MySQL 8.0参数默认值变更，恐致性能下降3倍多
  c95827d768117332fbe12c185270d3c1  #   1905c  mp.weixin.qq.com          34.5K star！又来一款全能开源笔记神器，超好用！
  71c1040f6b60b7051883d1d25cb1daa7  #   1902c  mp.weixin.qq.com          Kubernetes SRE 技能树（运维进阶版 2026）
  1071aa59c60a8ef26436ef8fafd33b40  #   1869c  mp.weixin.qq.com          知识积累能力是DBA最为重要的能力
  a5f531ebc7c13d24d4641fd12a1093d0  #   1785c  mp.weixin.qq.com          MySQL 8.4 默认关闭了 AHI
  c412d8a69cf951e567b5711fd8c974ce  #   1772c  mp.weixin.qq.com          Redis集群模式在扩容情况下，如何处理客户端的读写请求
  08efda3a78c7dff8e52444546f14ed46  #   1669c  mp.weixin.qq.com          运维服务绩效考核指标V1.0【拿来即用】
  476cf87c95cd3a760ead59fa0372046a  #   1628c  mp.weixin.qq.com          为什么说“懂业务”的DBA最值钱？
  9299ac1d48fe9dc26d55181249bcd123  #   1603c  mp.weixin.qq.com          PostgreSQL 19 重磅更新：200GB 大表维护，业务“零中断”！
  46cac2677f26e25f6ee8e2142ef86e57  #   1597c  mp.weixin.qq.com          为什么很多DBA的工作无法量化？
  8abecd7579f40e36704900e1dc658a7c  #   1597c  mp.weixin.qq.com          DBSyncer：一款开源的数据同步工具
  0f947a3b8fb7da48c5dfc8dfe5493ef8  #   1515c  mp.weixin.qq.com          MySQL免费培训与认证
  8413ed49d763ba958296992331692b3e  #   1512c  mp.weixin.qq.com          DBA是个创业成功率比较高的职业
  bebdb728929d79ee0a1afbb081a789c9  #   1489c  mp.weixin.qq.com          数据权限里放了几万条数据，用in拼接了几万个数据，sql太长了怎么优化？
  c665bb4859a613568ac28dc69bf7dd07  #   1470c  mp.weixin.qq.com          分布式数据库的存储引擎要复杂得多
  e383e460d520f17946fd341bb15cade8  #   1467c  mp.weixin.qq.com          真正高级的汇报，第一页就已经赢了
  168ac420da7a72de3db35e99f45fefad  #   1456c  mp.weixin.qq.com          数据倾斜是分布式数据库应用中的两难问题
  5e89258e07f874095b31a17664e42d60  #   1401c  mp.weixin.qq.com          PG 19 继续恶心OID升级到64位有啥用？
  b9f2342d0180e9458f81202b07e62d22  #    745c  mp.weixin.qq.com          innodb_adaptive_flushing，它的作用是用于控制 InnoDB 是否自适应地调整
  b18366ca3c3a10724c836aee806fef34  #    738c  mp.weixin.qq.com          Mysql的IN最多能放多少个值？
)

TOTAL=${#DOCS[@]}
IDX=0       # 當前位置（含 skipped），決定 [X/TOTAL] 顯示
DONE=0      # 本次實跑的篇數
SKIPPED=0   # 跳過的篇數（state 已標記或 knowledge.json 已存在）
FAILED_CNT=0

for DOC in "${DOCS[@]}"; do
  IDX=$((IDX + 1))
  # Skip if marked done in state file OR if filter output already exists
  if [[ -n "${DONE_SET[$DOC]:-}" ]] || [[ -f "generated/filtered/$DOC/knowledge.json" ]]; then
    SKIPPED=$((SKIPPED + 1))
    # Backfill state file if knowledge.json exists but state file missed it
    if [[ -z "${DONE_SET[$DOC]:-}" ]]; then
      echo "$DOC $(date -u '+%Y-%m-%dT%H:%M:%SZ') backfilled" >> "$STATE_FILE"
      DONE_SET["$DOC"]=1
    fi
    continue
  fi

  if [ "$DRY_RUN" = "1" ]; then
    echo "[dry-run] [$IDX/$TOTAL] make filter_doc DOC_ID=$DOC"
    continue
  fi

  DONE=$((DONE + 1))
  TS=$(date '+%H:%M:%S')
  echo "[$TS] [$IDX/$TOTAL] filter $DOC  (session#$DONE skipped=$SKIPPED)" | tee -a "$LOG"
  # tee → stdout (前台即時看 token / 5h window) + filter_progress.log
  if make filter_doc DOC_ID="$DOC" 2>&1 | tee -a "$LOG"; then
    # Mark done in state file (append-only, with UTC timestamp)
    echo "$DOC $(date -u '+%Y-%m-%dT%H:%M:%SZ') ok" >> "$STATE_FILE"
    DONE_SET["$DOC"]=1
  else
    FAILED_CNT=$((FAILED_CNT + 1))
    echo "$DOC" >> "$FAILED_LOG"
    echo "  ⚠️  FAIL $DOC (continuing). Reason in $LOG; if quota hit, re-run after 5h window resets."
  fi

  # 5h window 額度保護：剩餘 < 10% 即停（保留緩衝避免硬封）
  # 來源：filter_doc.py 每篇印 `5h window used=X% remaining=Y%`，抓最新一筆
  REMAIN=$(grep -oE '5h window used=[0-9.]+% remaining=[0-9.]+' "$LOG" 2>/dev/null | tail -1 | sed -E 's/.*remaining=//')
  if [[ -n "$REMAIN" ]] && awk -v r="$REMAIN" 'BEGIN{exit !(r+0 < 10)}'; then
    echo "[todo.sh] 5h window remaining=${REMAIN}% < 10% → 停止以保護額度" | tee -a "$LOG"
    echo "  resume: make filter_all  (5h window 重置後再跑)" | tee -a "$LOG"
    exit 0
  fi
done

date '+%Y-%m-%d %H:%M:%S [todo.sh] done' | tee -a "$LOG"
echo "summary: done=$DONE skipped=$SKIPPED failed=$FAILED_CNT total=$TOTAL"
[ "$FAILED_CNT" -gt 0 ] && echo "failed doc_ids in: $FAILED_LOG"
