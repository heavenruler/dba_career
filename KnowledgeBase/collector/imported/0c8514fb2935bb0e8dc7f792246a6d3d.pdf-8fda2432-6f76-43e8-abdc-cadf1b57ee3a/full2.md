# Redis Explained

A deep technical dive into all things Redis: topologies, data persistence, and process forking.

Mahdi Yusuf — Aug 11, 2022

Image: Redis Explained Infographic

## What is Redis?

Redis ("REmote DIctionary Server") is an open-source key-value database server. The most accurate description of Redis is that it's a data structure server. This specific nature of Redis has led to much of its popularity and adoption among developers.

Rather than iterating over, sorting, and ordering rows, what if the data was in the data structures you wanted from the ground up? Early on, Redis was used much like Memcached, but as Redis improved, it became viable for many other use cases, including publish-subscribe mechanisms, streaming, and queues.

### Redis data types for storage

Primarily, Redis is an in-memory database used as a cache in front of another "real" database like MySQL or PostgreSQL to help improve application performance. It leverages the speed of memory and alleviates load from the central application database for:

- Data that changes infrequently and is requested often
- Data that is less mission-critical and is frequently evolving

Examples include session caches, leaderboard or roll-up analytics for dashboards, and other read-heavy data.

However, for many use cases, Redis offers enough guarantees that it can be used as a full-fledged primary database. Coupled with Redis plug-ins and its various high availability (HA) setups, Redis as a database has become incredibly useful for certain scenarios and workloads. Another important aspect is that Redis blurred the lines between a cache and a datastore: reading and manipulating data in memory is much faster than anything possible with traditional datastores on SSDs or HDDs.

Important latency and bandwidth numbers every software engineer should be aware of (Credit: Jeff Dean).

Originally, Redis was most commonly compared to Memcached, which lacked any nonvolatile persistence at the time.

## Memcached vs Redis

Memcached was created by Brad Fitzpatrick in 2003, predating Redis by six years. It originally started as a Perl project and was later rewritten in C. It was the de facto caching tool of its day. The main differentiating point between it and Redis is its lack of data types and its limited eviction policy of just LRU (least recently used).

Another difference is that Redis is single-threaded while Memcached is multithreaded. Memcached might be performant in a strictly caching environment but requires some setup in a distributed cluster, while Redis has support for clustering out of the box.

Here is a current breakdown of capabilities between these two caches:

Feature | Memcached | Redis
--- | ---: | ---:
Sub-millisecond latency | Yes | Yes
Developer ease of use | Yes | Yes
Data partitioning | Yes | Yes
Support for a broad set of programming languages | Yes | Yes
Advanced data structures | - | Yes
Multithreaded architecture | Yes | -
Snapshots (RDB) | - | Yes
Replication | - | Yes
Transactions | - | Yes
Pub/Sub | - | Yes
Lua scripting | - | Yes
Geospatial support | - | Yes

Although now configurable in how it persists data to disk, when it was first introduced, Redis used snapshots where asynchronous copies of the data in memory were persisted to disk for long-term storage. This mechanism has the downside of potentially losing data between snapshots.

Redis has matured since its inception in 2009. Below we cover most of its architecture and topologies so you can add Redis to your data storage system arsenal.

## Redis Architectures

Before discussing Redis internals, let's look at the various Redis deployments and their trade-offs. We will focus mainly on these configurations:

- Single Redis instance
- Redis HA (primary + replica)
- Redis Sentinel
- Redis Cluster

Depending on your use case and scale, you can decide which setup to use.

### Single Redis Instance

Image: Simple Redis deployment.

A single Redis instance is the most straightforward deployment. It allows users to set up and run small instances that can help them grow and speed up their services. However, this deployment isn't without shortcomings: if this instance fails or is unavailable, all client calls to Redis will fail and therefore degrade the system's overall performance.

Given enough memory and server resources, a single instance can be powerful. A scenario primarily used for caching could result in a significant performance boost with minimal setup. You could deploy Redis on the same machine as the application if resources permit.

Commands sent to Redis are first processed in memory. If persistence is configured, Redis forks a process at intervals to facilitate persistence via RDB snapshots (point-in-time compact representations) or AOF (append-only files). These two persistence flows allow Redis to have long-term storage, support replication strategies, and enable more complicated topologies. If persistence is disabled, data is lost on restart or failover. If persistence is enabled, on restart Redis loads data from the RDB snapshot or AOF back into memory before serving new client requests.

### Redis HA

Image: Redis with secondary failover.

A common setup is a primary instance with one or more replica instances kept in sync via replication. As data is written to the primary, Redis sends copies of those commands to a replica output buffer on secondary instances, facilitating replication. Replicas can help scale reads and provide failover if the primary fails.

#### High Availability

High availability (HA) aims to ensure an agreed level of operational performance, usually uptime, for an extended period. In HA systems it is essential to avoid single points of failure so systems can recover gracefully and quickly, preserving data during transitions and automatically detecting failure and recovery.

When entering a distributed setup, things that were previously straightforward become more complex. Below are a few core concepts.

#### Redis Replication

Every primary Redis instance has a replication ID and an offset. These two pieces of data are critical to determine where a replica can continue replication or whether it needs a full sync. The offset increments for every action on the primary.

- If a replica is only a few offsets behind, the primary sends the remaining commands to be replayed by the replica until it is in sync.
- If the two instances cannot agree on the replication ID or the offset is unknown, the replica requests a full synchronization. The primary creates an RDB snapshot and sends it to the replica. During the transfer, the primary buffers intermediate updates (commands) so they can be sent once the replica is ready. Once the snapshot is loaded and the buffered updates replayed, replication resumes normally.

If an instance has the same replication ID and offset as another instance, they have precisely the same data. A replication ID is required because when a Redis instance is promoted to primary or restarts as primary, it is given a new replication ID. This helps infer previous relationships and allows partial synchronization with other replicas that share a common ancestor.

If replication IDs differ and there is no known common ancestor, a full sync (expensive) is required. If a previous replication ID is known, a partial sync might be possible.

## Redis Sentinel

Image: Redis Sentinel deployment (extra monitoring/dashed lines from other sentinel nodes are left out for clarity).

Sentinel is a distributed system designed to provide high availability for Redis. A cluster of sentinel processes coordinates state to avoid a single point of failure in the HA control plane. Sentinel is responsible for:

- Monitoring — ensuring primary and replica instances are working as expected.
- Notification — alerting system admins about occurrences in Redis instances.
- Failover management — initiating an automatic failover if the primary is unavailable and a quorum of sentinel nodes agrees.
- Configuration management — serving as a service discovery mechanism so clients can learn the current primary.

Sentinels constantly monitor availability and inform clients so they can react to failover events. Failure detection involves multiple sentinel processes agreeing that the primary is unavailable; this agreement is called quorum.

#### Quorum

A quorum is the minimum number of votes required to perform operations like failover. This number is configurable but should reflect the number of nodes in the distributed system. Many systems use three or five nodes with quorums of two and three respectively. An odd number of nodes is preferred to break ties.

Recommendations and caveats when using Sentinel:

- Run at least three sentinel nodes with a quorum of at least two.
- Consider running sentinel processes alongside application servers (if possible) to reduce network reachability differences between sentinels and clients.
- You can run Sentinel alongside Redis instances or on independent nodes, but independent nodes complicate network and availability considerations.
- Be aware that persistence is asynchronous; durability guarantees are limited. There can be lost writes during failover if clients are unaware of a new primary.
- To mitigate data loss, force the primary to replicate writes to at least one replica before accepting them. Note that Redis replication is asynchronous; you must independently track acknowledgements. If acknowledgements are not confirmed by at least one replica, the primary can be configured to stop accepting writes.

Potential failure scenarios to consider:

- Sentinel nodes falling out of quorum.
- Network splits that put the old primary in a minority partition — writes in the minority are lost when the system recovers.
- Misaligned network topologies between sentinel nodes and clients, causing clients to continue writing to an unaware primary.

## Redis Cluster

Image: Redis Cluster Architecture

Redis Cluster allows horizontal scaling of Redis across multiple machines (sharding). This is useful when a single server cannot hold all data in memory.

### Vertical and Horizontal Scaling

As your systems grow, you have three options:

- Do less (rarely feasible).
- Scale up (vertical scaling).
- Scale out (horizontal scaling).

Vertical scaling uses bigger machines; horizontal scaling spreads the workload across multiple smaller machines. When using Redis Cluster, data is spread across shards (each Redis instance is a shard).

### Sharding and Hashslots

Redis Cluster uses algorithmic sharding. To find the shard for a given key, Redis hashes the key and maps it to one of 16,384 hashslots (16K). This layer of indirection simplifies resharding: when adding or removing nodes, Redis moves hashslots between instances rather than rehashing every key.

Example:

- M1 initially contains hashslots 0–8191.
- M2 contains 8192–16383.

The key "foo" is hashed to a slot that maps to M2. If a new instance M3 is added, hashslots are redistributed:

- M1: 0–5460
- M2: 5461–10922
- M3: 10923–16383

Keys do not need to be rehashed individually; only hashslots move, which reduces downtime and simplifies resharding.

### Gossiping and Failover

Redis Cluster uses gossiping among nodes to determine the cluster's health. Nodes constantly communicate to know which shards are available. If enough nodes agree that a primary (e.g., M1) is unresponsive, they can promote a replica (e.g., S1) to primary. The number of nodes needed to trigger this is configurable. Avoid misconfiguration that could cause split-brain; an odd number of primaries and at least two replicas per primary are generally recommended for robustness.

## Redis Persistence Models

If Redis will store data you want to keep, you must understand its persistence options. For some use cases (like caches or non-critical analytics) losing Redis data is acceptable. For others, you want guarantees around persistence and recovery.

Redis prioritizes speed; consistency and durability are secondary trade-offs.

### No persistence

If desired, you can disable persistence altogether. This is the fastest mode but provides no durability guarantees.

### RDB (Redis Database) snapshots

RDB persistence performs point-in-time snapshots of your dataset at specified intervals. The main downsides:

- Data between snapshots is lost.
- Snapshotting relies on forking; with large datasets, the fork may cause a momentary delay in serving requests.
- RDB files are faster to load into memory than AOF files.

### AOF (Append Only File)

AOF logs every write operation the server receives. On restart, AOF is replayed to reconstruct the dataset. AOF is more durable than RDB because it logs commands incrementally. Writes are buffered to the log and flushed to disk with fsync according to configuration. Downsides include larger disk usage and slower recovery compared to RDB.

fsync() transfers modified in-core file data to disk so changes are durable in the event of a crash or reboot.

### RDB + AOF

You can enable both RDB and AOF. If both are enabled, Redis uses AOF to reconstruct data on restart because AOF is the most complete representation. Using both is a reasonable trade-off if you accept some performance cost for extra durability.

## Forking and Copy-on-Write

Image: How Redis uses forking for point-in-time snapshots

One of Redis's clever techniques for persistence is using OS-level forking and copy-on-write (COW) to create snapshots without duplicating all memory immediately.

- Forking creates a child process that is a copy of the parent process.
- Using copy-on-write, parent and child share the same physical memory pages at fork time. If either process modifies a page, the OS copies that page so the other process retains the original version.
- Redis starts the snapshot process in the child process. If no changes occur during snapshotting, no additional memory is used. If changes occur, the kernel copies modified pages as needed.
- The child process writes the snapshot to disk, obtaining a consistent point-in-time snapshot of the dataset without duplicating the entire memory footprint up front.

This approach enables efficient point-in-time snapshots of gigabytes of in-memory data.

## Closing

I hope you learned something useful about how Redis operates in systems. If you want to explore further, read up on Sentinel best practices, cluster resharding procedures, and persistence tuning for production workloads.

Author: Mahdi Yusuf