# phase-crossregion / chaos — scenario index

> Status: **planner-only / 不實跑**
> 三支 planner script 只印出「會跑的指令」+「期望 artifact」+「期望行為」；不執行任何 systemctl / iptables / cgroup / tc。
> 啟用實跑需 PR + DBA review。

## 場景對應

| ID | Spec | Planner script | 故障模型 | 注入機制 |
|---|---|---|---|---|
| C1 | [`C1.md`](./C1.md) | [`../scripts/chaos/chaos-c1-node-down-plan.sh`](../scripts/chaos/chaos-c1-node-down-plan.sh) | 單 node 故障（leader 或 voter）| `systemctl stop` DB service |
| C4 | [`C4.md`](./C4.md) | [`../scripts/chaos/chaos-c4-network-partition-plan.sh`](../scripts/chaos/chaos-c4-network-partition-plan.sh) | IDC ↔ GCP raft 切斷 | `iptables -A INPUT/OUTPUT ... DROP` on raft port |
| C7 | [`C7.md`](./C7.md) | [`../scripts/chaos/chaos-c7-disk-slow-plan.sh`](../scripts/chaos/chaos-c7-disk-slow-plan.sh) | 磁碟慢（單 node WAL fsync 延遲） | cgroup `blkio.throttle.{read,write}_bps_device` 或 fallback `tc qdisc tbf` |

> 註：planner script 命名與內部模型遵照 `REPLAN-2026-06-15.md` §6（C1=node-down / C4=network-partition / C7=disk-slow）。原 spec C1.md / C4.md / C7.md 內描述的「IDC全死、leader die、WAN partition」等細部模型在 planner 內以註解標示 mapping。

## 已淘汰

- **C3**（GCP read-only / region quorum loss）：2026-06 Q4 review 結論「Q4 已淘汰」，spec `C3.md` 已刪除。

## CLI 規範

```
chaos-c{1,4,7}-*-plan.sh --db tidb|crdb|ybdb --target-host <ip> --duration <sec>
```

- 三個 flag 都是必填
- `--db` 限 `tidb` / `crdb` / `ybdb`
- `--duration` 整數秒
- **沒有 `--execute` 旗標**（不允許後續加；啟用實跑要走 PR + DBA review）

## 輸出

每次跑會把 plan 印到 stdout 並寫入 `chaos-plan-c<id>-<ts>.txt`（current working dir）。

artifact schema（**僅為預期格式**，實跑後才會產出）：

```
chaos/C<id>/<ts>/
├── tpmc-1s.txt
├── error-rate-by-sec.txt
├── leader-redist-trace.txt   # C1 / C4
├── iptables-rules-*.txt      # C4
├── blkio-throttle-state.txt  # C7
├── tc-qdisc-state.txt        # C7 (fallback)
├── io-latency-p99.txt        # C7
├── go-tpc-stdout.txt
└── plan.txt
```

## 後續開閘流程（草案）

啟用實跑需：

1. PR：把 planner script 加 inject 行為（**新檔 / 新 script**，不要在現有 planner 加 `--execute`）
2. PR 內必須含 DBA reviewer approve
3. 目標 host 限縮（IDC `.32/.33/.34` 或 GCP `g-test-poc-*`）+ 維護視窗（避開營業時段）
4. 灰度：先在 isolation env 跑一次 dry-run + observability sanity check
5. 全程留痕：iptables / cgroup / systemctl pre/post snapshot 必出
