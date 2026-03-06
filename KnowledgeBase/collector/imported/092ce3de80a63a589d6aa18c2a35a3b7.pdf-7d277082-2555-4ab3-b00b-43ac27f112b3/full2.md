Migrating Facebook to MySQL 8.0
===============================

MySQL, an open-source database developed by Oracle, powers some of Facebook’s most important workloads. We actively develop new features in MySQL to support our evolving requirements. These features change many different areas of MySQL, including client connectors, storage engine, optimizer, and replication. Each new major version of MySQL requires significant time and effort to migrate our workloads.

Our last major version upgrade, to MySQL 5.6, took more than a year to roll out. When 5.7 was released, we were still in the midst of developing our LSM-tree storage engine, MyRocks. Since upgrading to 5.7 while simultaneously building a new storage engine would have significantly slowed progress on MyRocks, we opted to stay with 5.6 until MyRocks was complete. MySQL 8.0 was announced as we were finishing the rollout of MyRocks to our user database (UDB) service tier.

MySQL 8.0 included compelling features like writeset-based parallel replication and a transactional data dictionary that provided atomic DDL support. For us, moving to 8.0 would also bring in the 5.7 features we had missed, including Document Store. Version 5.6 was approaching end of life, and we wanted to stay active within the MySQL community, especially with our work on the MyRocks storage engine. Enhancements in 8.0, like instant DDL, could speed up MyRocks schema changes, but we needed to be on the 8.0 codebase to use it. Given the benefits, we decided to migrate to 8.0.

When we initially scoped the project, it was clear that moving to 8.0 would be even more difficult than migrating to 5.6 or MyRocks. At the time, our customized 5.6 branch had over 1,700 code patches to port to 8.0. As we were porting those changes, new Facebook MySQL features and fixes were added to the 5.6 codebase that moved the goalpost further away. We have many MySQL servers running in production, serving a large number of disparate applications, and extensive software infrastructure for managing MySQL instances (operations like gathering statistics and managing server backups). Upgrading from 5.6 to 8.0 skipped over 5.7 entirely. APIs that were active in 5.6 would have been deprecated in 5.7 and possibly removed in 8.0, requiring us to update any application using the now-removed APIs. A number of Facebook features were not forward-compatible with similar ones in 8.0 and required a deprecation and migration path forward. MyRocks enhancements were also needed to run in 8.0, including native partitioning and crash recovery.

Code patches
------------

We first set up the 8.0 branch for building and testing in our development environments, then began the long journey to port the patches from our 5.6 branch. There were more than 1,700 patches when we started, but we were able to organize them into a few major categories. Most of our custom code had good comments and descriptions so we could easily determine whether it was still needed or could be dropped. Features enabled by special keywords or unique variable names were easy to search for in our application codebases to determine relevance. A few patches were very obscure and required detective work — digging through old design documents, posts, and code review comments — to understand their history.

We sorted each patch into one of four buckets:
- Drop: Features that were no longer used, or had equivalent functionality in 8.0, and did not need to be ported.
- Build/Client: Non-server features that supported our build environment or modified MySQL tools like mysqlbinlog, or added functionality like the async client API.
- Non-MyRocks Server: Features in the mysqld server that were not related to our MyRocks storage engine.
- MyRocks Server: Features that supported the MyRocks storage engine.

We tracked the status and relevant historical information of each patch using spreadsheets and recorded our reasoning when dropping a patch. Multiple patches that updated the same feature were grouped together for porting. Patches ported and committed to the 8.0 branch were annotated with the 5.6 commit information. Discrepancies on porting status inevitably arose due to the large number of patches; these notes helped us resolve them.

Each of the client and server categories became a software release milestone. With all client-related changes ported, we updated our client tooling and connector code to 8.0. Once all of the non-MyRocks server features were ported, we were able to deploy 8.0 mysqld for InnoDB servers. Finishing up the MyRocks server features enabled us to update MyRocks installations.

Some of the most complex features required significant changes for 8.0, and a few areas had major compatibility problems. For example, upstream 8.0 binlog event formats were incompatible with some of our custom 5.6 modifications. Error codes used by Facebook 5.6 features conflicted with those assigned to new features by upstream 8.0. We ultimately needed to patch our 5.6 server to be forward-compatible with 8.0. It took a couple of years to complete porting all of these features. By the time we finished, we had evaluated more than 2,300 patches and ported 1,500 of those to 8.0.

The migration path
------------------

We group multiple mysqld instances into a single MySQL replica set. Each instance in a replica set contains the same data but is geographically distributed to different data centers to provide availability and failover support. Each replica set has one primary instance; the remaining instances are all secondaries. The primary handles all write traffic and replicates data asynchronously to all secondaries.

We started with replica sets consisting of 5.6 primary/5.6 secondaries and the end goal was replica sets with 8.0 primary/8.0 secondaries. For each replica set, we followed this plan:
1. Create and add 8.0 secondaries via a logical copy using mysqldump. These secondaries do not serve any application read traffic.
2. Enable read traffic on the 8.0 secondaries.
3. Allow the 8.0 instance to be promoted to primary.
4. Disable the 5.6 instances for read traffic.
5. Remove all the 5.6 instances.

Each replica set could transition through the steps independently and remain in a step as long as needed. We separated replica sets into much smaller groups and shepherded each through the transitions. If we found problems, we could roll back to the previous step. To automate the transition of a large number of replica sets, we built new software infrastructure that allowed grouping replica sets and moving them through each stage by changing a line in a configuration file. Any replica set that encountered problems could then be individually rolled back.

Row-based replication
---------------------

As part of the 8.0 migration, we standardized on row-based replication (RBR). Some 8.0 features required RBR, and it simplified our MyRocks porting efforts. While most of our MySQL replica sets were already using RBR, those still running statement-based replication (SBR) could not be easily converted because they usually had tables without any high-cardinality keys. Adding primary keys to every table had a long tail of work and was often deprioritized.

We made RBR a requirement for 8.0. After evaluating and adding primary keys to every table, we switched over the last SBR replica set. Using RBR also gave us an alternative solution for resolving an application issue we encountered when moving some replica sets to 8.0 primaries (discussed below).

Automation validation
---------------------

Most of the 8.0 migration process involved testing and verifying the mysqld server with our automation infrastructure and application queries. As our MySQL fleet grew, so did the automation infrastructure we use to manage servers. To ensure all automation was compatible with the 8.0 version, we built a test environment that leveraged test replica sets with virtual machines to verify behaviors. We wrote integration tests to canary each piece of automation on both the 5.6 and 8.0 versions and verified correctness. We found several bugs and behavior differences as we went.

As each piece of MySQL infrastructure was validated against our 8.0 server, we found and fixed (or worked around) a number of issues:
- Software that parsed text output from error logs, mysqldump output, or server SHOW commands easily broke. Slight changes in server output often revealed bugs in a tool’s parsing logic.
- The 8.0 default collation settings resulted in utf8mb4 collation mismatches between our 5.6 and 8.0 instances. 8.0 tables may use the new utf8mb4_0900 collations even for CREATE statements generated by 5.6’s SHOW CREATE TABLE because the 5.6 schemas do not explicitly specify utf8mb4_general_ci. These table differences often caused problems with replication and schema verification tools.
- The error codes for certain replication failures changed and we had to update our automation to handle them correctly.
- The 8.0 data dictionary obsoleted .frm files, but some of our automation used them to detect table schema modifications.
- We had to update our automation to support the dynamic privileges introduced in 8.0.

Application validation
----------------------

We wanted the transition for applications to be as transparent as possible, but some application queries hit performance regressions or failed on 8.0.

For the MyRocks migration, we built a MySQL shadow testing framework that captured production traffic and replayed it to test instances. For each application workload, we constructed test instances on 8.0 and replayed shadow traffic queries to them. We captured and logged the errors returning from the 8.0 server and found several problems. Unfortunately, not all of these problems were found during testing; for example, a transaction deadlock was discovered by applications during the migration. We were able to roll back these applications to 5.6 temporarily while we researched solutions.

Specific issues we encountered:
- New reserved keywords were introduced in 8.0 (for example, groups and rank) and conflicted with popular table column names and aliases used in application queries. Queries that did not escape these names via backquotes produced parsing errors. Applications using libraries that automatically escaped column names did not hit these issues, but not all applications used such libraries. Fixing the problem was straightforward but required locating the application owners and codebases generating the queries.
- A few REGEXP incompatibilities were found between 5.6 and 8.0.
- Some applications hit repeatable-read transaction deadlocks involving insert queries on InnoDB. 5.6 had a bug related to ON DUPLICATE KEY that was corrected in 8.0, but the fix increased the likelihood of transaction deadlocks. After analyzing our queries, we resolved these by lowering the isolation level. This option was available to us because we had switched to row-based replication.
- Our custom 5.6 Document Store and JSON functions were not compatible with 8.0’s. Applications using Document Store needed to convert the document type to text for the migration. For JSON functions, we added 5.6-compatible versions to the 8.0 server so applications could migrate to the 8.0 API at a later time.

Our query and performance testing of the 8.0 server uncovered a few problems that needed to be addressed quickly:
- We found new mutex contention hotspots around the ACL cache. When a large number of connections opened simultaneously, they could all block on checking ACLs.
- Similar contention was found with binlog index access when many binlog files were present and high binlog write rates rotated files frequently.
- Several queries involving temp tables were broken: they would return unexpected errors or take so long to run that they timed out.
- Memory usage compared with 5.6 increased, especially for our MyRocks instances, because InnoDB must be loaded in 8.0. The default performance_schema settings enabled all instruments and consumed significant memory. We limited memory usage by enabling only a small number of instruments and making code changes to disable tables that could not be manually turned off. However, not all the increased memory was attributable to performance_schema. We examined and modified various InnoDB internal data structures to reduce the memory footprint further. This effort brought 8.0’s memory usage down to acceptable levels.

What’s next
-----------

The 8.0 migration has taken a few years so far. We have converted many of our InnoDB replica sets to run entirely on 8.0. Most of the remaining ones are at various stages along the migration path. Now that most of our custom features have been ported to 8.0, updating to Oracle’s minor releases has been comparatively easier, and we plan to keep pace with the latest versions.

Skipping a major version like 5.7 introduced problems that our migration needed to solve:
- We could not upgrade servers in place and needed to use logical dump and restore to build a new server. For very large mysqld instances, this can take many days on a live production server and the fragile process can be interrupted before completion. For these large instances, we had to modify our backup and restore systems to handle the rebuild.
- It is harder to detect API changes because 5.7 could have provided deprecation warnings to our application clients. Instead, we needed to run additional shadow tests to find failures before migrating production workloads. Using mysql client software that automatically escapes schema object names helps reduce compatibility issues.
- Supporting two major versions within a replica set is hard. Once a replica set promotes its primary to be an 8.0 instance, it is best to disable and remove the 5.6 ones as soon as possible. Application users tend to discover new features supported only by 8.0, such as collations, and using these can break replication streams between 8.0 and 5.6 instances.

Despite the hurdles, we have already seen benefits from running 8.0. Some applications opted for early conversion to use features like Document Store and improved datetime support. We have been considering how to support storage-engine features like Instant DDL on MyRocks. Overall, the new version greatly expands what we can do with MySQL at Facebook.