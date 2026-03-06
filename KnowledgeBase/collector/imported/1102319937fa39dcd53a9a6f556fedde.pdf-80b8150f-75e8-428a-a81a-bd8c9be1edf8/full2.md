# 分布式数据库的进度管理：TiDB 备份恢复工具 PiTR 的原理与实践

本文深入解析 TiDB 备份恢复工具 PiTR（Point in Time Restore）的原理与实践。先介绍 PiTR 对数据恢复的重要性，然后阐述 TiKV 侧的备份流程，包括关键组件与备份操作。接着探讨从单个 Region 到全局的进度管理，引入 Checkpoint、Service Safepoint 和 Global Checkpoint 等概念。最后讲述 TiDB 侧负责进度管理的组件 CheckpointAdvancer 的工作及异常处理机制。

希望本文能够帮助开发者和数据库管理员更好地理解 PiTR 的工作机制，有效利用这一功能加固数据库基础设施。

---

## 概览

TiDB 的数据以表和行的形式写入，每一行数据作为一个键值对存储在 TiKV 中。TiKV 被逻辑地划分为多个 Region。由于写入是分布式的，各个 Region 的数据分布在不同宿主机上，并不存在一个统一的写入时点。因此需要分别管理每个 Region 的写入进度，并提供一个整体进度（Global Checkpoint）。下面从 TiKV 层的备份流程开始，逐步讲到全局进度管理与 TiDB 侧的推进器设计。

---

## TiKV 侧备份流程

PiTR 是一个分布式过程：每个 TiKV Server 记录备份数据并将数据发送到远端存储。备份流程的大致步骤如下。

在 TiKV server 初始化时，会初始化 BackupStreamObserver 和 Endpoint 两个组件。它们共用同一个 scheduler（backup_stream_scheduler），通过向 scheduler 发送 Task 的方式进行通信。

- BackupStreamObserver 实时监听 Raft 状态机的写入。关键接口是 on_flush_applied_cmd_batch()，该接口在 Raft 状态机 apply 时被调用，将 Raft 命令打包为 BatchEvent，然后作为任务发送给 scheduler。在 PiTR 中，这种任务被称为 Task::BatchEvent。

下面是 BatchEvent 对应的命令批结构示例（Rust）：

```rust
pub struct CmdBatch {
    pub level: ObserveLevel,
    pub cdc_id: ObserveId,
    pub rts_id: ObserveId,
    pub pitr_id: ObserveId,
    pub region_id: u64,
    pub cmds: Vec<Cmd>,
}
```

BatchEvent 实质上是一系列 Raft 命令的拷贝。PiTR 在备份时记录这些命令，并在恢复时重放以实现日志备份功能。

- Endpoint 负责与外部存储通信。在启动后，Endpoint 会进入循环，检查 scheduler 是否包含新的任务并执行相应函数。对于 Task::BatchEvent（来自 Observer 的写入数据），Endpoint 会执行 backup_batch() 函数开始备份这些键值对。

备份过程概览：

1. Endpoint 对 CmdBatch 做简单检查，然后将其发往 router.on_events() 并开始异步等待结果。
2. Router 将写入操作按 range 拆分以提高并发度。每个 range 的写入先存入内存中的临时文件（用于暂存 raft store 更新的信息）。
3. 当内存中临时文件大小超过上限或超过指定刷盘间隔时，才会将临时文件的数据写入远端存储，视为完成一次（部分）备份。

BackupStreamConfig 的默认设置（示例）：

```rust
impl Default for BackupStreamConfig {
    fn default() -> Self {
        // ...
        Self {
            min_ts_interval: ReadableDuration::secs(10),
            max_flush_interval: ReadableDuration::minutes(3),
            // ...
        }
    }
}
```

当满足刷盘条件后，会进入 endpoint.do_flush()，在这里完成将备份文件刷盘的逻辑。此时备份数据已被写入远端存储，备份操作得以告一段落。这也是汇报备份进度（checkpoint）的最佳时刻。备份完成后的回调 flush_ob.after() 会负责后续进度更新：

下面是回调的示例实现（Rust）：

```rust
async fn after(&mut self, task: &str, _rts: u64) -> Result<()> {
    let flush_task = Task::RegionCheckpointsOp(RegionCheckpointOperation::FlushWith(
        std::mem::take(&mut self.checkpoints),
    )); // Update checkpoint
    try_send!(self.sched, flush_task);
    let global_checkpoint = self.get_checkpoint(task).await?;
    info!("getting global checkpoint from cache for updating."; "checkpoint" => ?global_checkpoint);
    self.baseline.after(task, global_checkpoint.ts.into_inner()).await?; // update safepoint
    Ok(())
}
```

该回调做了两件事：更新 store checkpoint（向 scheduler 报告当前 Region 的 checkpoint）和更新 service safepoint（提示 GC 在安全时间戳之前可以清理数据）。下面讨论这两者的意义。

---

## 从检查点（Checkpoint）到全局检查点（Global Checkpoint）

在 PiTR 流程中，每个 TiKV 将数据打包成文件并发送到远端存储。为了管理备份进度，需要跟踪每个 TiKV（或每个 Region）上的备份进度。对单个 Region，可以通过记录已刷盘数据的时间戳来实现进度管理：刷盘时记录时间戳，这个时间戳就是该 Region 完成备份的最小时间点，也称为 Checkpoint。

需要注意的是，备份数据与 TiKV 的 MVCC（多版本并发控制）机制相关。MVCC 会保留历史版本以支持历史查询和事务隔离，历史数据会不断累积，因此需要通过 GC（垃圾回收）来清理旧版本以释放存储空间。为了确保在备份（Flush）完成之前这些历史版本不会被 GC 清除，引入了 Service Safepoint 的概念：它是通知 GC 可以安全清除的数据时间戳。

Global Checkpoint 是用于管理整个集群备份进度的指标。在实践中，Global Checkpoint 被定义为所有 TiKV Checkpoint 的最小值（即 min of per-store/region checkpoints），这保证在 Global Checkpoint 之前的所有数据已经在集群范围内完成备份。汇总所有 TiKV 进度并计算 Global Checkpoint 的工作由 TiDB 负责。

---

## TiDB 侧进度管理

在 TiDB 侧，负责汇总与推进全局进度的组件是 CheckpointAdvancer。它本质上是一个随主程序运行的守护进程，周期性执行以下工作：

- 订阅并接收来自 TiKV 的 FlushTSO（刷盘时间戳）更新；
- 处理可能的错误并计算 Global Checkpoint；
- 将总体进度汇报给 PD（Placement Driver）。

实现细节：

- CheckpointAdvancer 包含一个 FlushSubscriber 字段，用于维持一个 gRPC 流，持续监听不同 range 的 checkpoint 并将其记录下来。FlushSubscriber 将接收到的 checkpoint 通过 channel 发送给 advancer。
- Advancer 将接收到的 checkpoint 放入内部的 checkpoints 数据结构中，并在周期性 tick() 调用中尝试推进 Global Checkpoint。

关键的 tick 流程（Go）：

```go
func (c *CheckpointAdvancer) tick(ctx context.Context) error {
    // ...
    var errs error
    cx, cancel := context.WithTimeout(ctx, c.Config().TickTimeout())
    defer cancel()
    err := c.optionalTick(cx)
    if err != nil {
        // ...
    }
    err = c.importantTick(ctx)
    if err != nil {
        // ...
    }
    return errs
}
```

tick 分为两部分：optionalTick() 和 importantTick()。

- optionalTick() 主要负责与 FlushSubscriber 沟通，获取来自 TiKV 的进度更新。由于单个 TiKV 的 checkpoint 并不一定会持续推进，因此称为 optional。只要捕获到 FlushTSO 的更新，advancer 会在此记录并尝试推进全局检查点。
- importantTick() 负责管理全局进度：一旦确认进度更新，就会产生新的 Global Checkpoint 并更新 Service Safepoint。importantTick 的动作会影响全局 GC，因此风险更高。

异常处理与保护机制：

如果某个 TiKV 的 checkpoint 长时间未推进，会阻塞 Global Checkpoint 的推进，从而可能阻塞 GC，导致不能清除已经完成备份的冗余数据。最糟糕的情况是某个 TiKV 出现不可自动恢复的错误，永远阻碍 GC 的推进，进而影响整个集群。

为此，importantTick 会检测 checkpoint 距离上次更新的时间差。如果某个 checkpoint 长时间未推进，该备份任务会被标记为异常状态，advancer 会自动暂停这个任务并等待管理员介入。示例代码（Go）：

```go
isLagged, err := c.isCheckpointLagged(ctx)
if err != nil {
    return errors.Annotate(err, "failed to check timestamp")
}
if isLagged {
    err := c.env.PauseTask(ctx, c.task.Name)
    if err != nil {
        return errors.Annotate(err, "failed to pause task")
    }
    return errors.Annotate(errors.Errorf("check point lagged too large"), "check point lagged")
}
```

暂停后，advancer 并不会完全停止；它会在推进过程中跳过被标记为异常的任务的 checkpoint 更新。如果 PD 恢复了该任务，会向 advancer 发送信号，advancer 可以重新回到正常的 tick 流程中。

需要指出的是，这种异常处理机制是防卫性的：它能识别异常并临时隔离任务，但无法自动定位或修复根本原因，仍需管理员手动介入进行排查与恢复。未来可以考虑实现更多的自动化运维能力，例如在 checkpoint 恢复推进后自动重启任务等。

---

## 小结

- PiTR 在 TiKV 层通过监听 Raft apply 事件，将写入命令打包并异步刷写到远端存储，从而实现增量日志备份。
- 每个 Region 的刷盘时间戳作为 Checkpoint，TiDB 将所有 Checkpoint 的最小值作为 Global Checkpoint，并通过 Service Safepoint 协同 GC。
- TiDB 的 CheckpointAdvancer 负责订阅 TiKV 的 checkpoint 更新、计算 Global Checkpoint 并上报 PD；同时具备异常检测与任务暂停机制以保护全局 GC 安全。
- 当前机制能够保证备份与 GC 的协调，但异常处理仍依赖人工介入，未来可进一步提升自动化修复能力。

---

## 参考资料（要点索引）

1. BackupStreamObserver（TiKV）
2. Endpoint（TiKV）
3. backup_stream_scheduler（TiKV）
4. on_flush_applied_cmd_batch（TiKV）
5. Task::BatchEvent（TiKV）
6. backup_batch（TiKV）
7. router.on_events（TiKV）
8. endpoint.do_flush（TiKV）
9. flush_ob.after（TiKV）
10. Global Checkpoint 最小值计算（TiDB）
11. CheckpointAdvancer（TiDB）
12. FlushSubscriber（TiDB）
13. FlushSubscriber 持续监听实现（TiDB）
14. checkpoints 数据结构（TiDB）
15. tick()（TiDB）
16. optionalTick()（TiDB）
17. importantTick()（TiDB）
18. Service Safepoint（TiDB/PD）
19. checkpoint lag 检查逻辑（TiDB）
20. 将任务标记为异常状态的逻辑（TiDB）
21. 异常任务跳过策略（TiDB）
22. PD 与 Advancer 的信号通信（TiDB）

（以上参考项对应 TiKV/TiDB 源码中的具体实现与函数，可在相应项目源码仓库中查阅详细实现。）

---