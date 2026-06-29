# S-BASE / S-K8S 與延伸實驗流程、任務 Prompt

## 1. 盤點結論

本專案以 `result_scope` 隔離不同實驗家族：

| Scope | 用途 | baseline family | 主要 SSOT | Artifact |
|---|---|---|---|---|
| `S-BASE` | VM 單節點與三節點 baseline | `vm` | `results/PoC-DESIGN.md`、`tests/common/`、歷史入口 `Makefile.tc1` | `results/{db}-tc1/S-BASE/` |
| `S-K8S` | Kubernetes limit / unlimit 對照 | `k8s` | `phase-k8s/manifest.yaml`、`phase-k8s/expected/`、`phase-k8s/run-k8s-suite.sh` | `results/{db}-tc1/S-K8S/` |

`S-BASE` 與 `S-K8S` 都是 baseline eligible，但只能在各自 family 內形成 baseline。跨 family 比較只能報「K8s 相對同 DB VM 的保留率與 latency 差異」，不能混在同一排名中。

### 共用 workload

- Warehouses：128
- Warmup：20 分鐘，64 threads
- Thread sweep：16 / 32 / 64 / 128
- 每個 thread group：5 rounds × 5 分鐘
- round 間隔：60 秒
- 指標：tpmC、NEW_ORDER p50/p95/p99、all-transaction error rate、client/DB node OS metrics
- 統一主流程：`gate → prepare → gate-iso → dry-run → run → collect → summary`

### 統一七階段 pipeline contract

部署與破壞性 cleanup 是 pipeline 前置作業；取得明確授權後才可執行。每個實驗 cell 的正式資料鏈固定如下，不允許 phase 自行換順序：

| 順序 | 階段 | 必做內容 | 完成證據 |
|---:|---|---|---|
| 1 | `gate` | controller、SSH、chrony、磁碟、DB health、版本、拓樸與 scope guard | `.gate.done` + `gate/` |
| 2 | `prepare` | 建庫、128W 載入、ANALYZE、shard/RF/placement 設定及資料完整性檢查 | `.prepare.done` + `prepare/` |
| 3 | `gate-iso` | 以 workload 同 driver、同 endpoint、active transaction 驗證實際 isolation | `.gate-isolation.done` + `gate/isolation-*` |
| 4 | `dry-run` | 對 prepare 後狀態做唯讀快照：topology、配置、process/worker、routing、資料量、placement；產 config hash，**不跑 timed workload** | `.dry-run.done` + `dry-run/actual.yaml` |
| 5 | `run` | 驗 config hash 未變；cold reset、warmup、thread sweep、round watchdog 與 metrics | `.run.done` + `runs/` |
| 6 | `collect` | DB config/log、OS/pod/process metrics、版本與環境 fingerprint | `.collect.done` + `db-config/`、`env/` |
| 7 | `summary` | 從 raw stdout 產 summary、驗 rounds/markers/coverage、寫 machine-readable caveat；最後才寫 `.suite.done` | `summary.json` + `.summary.done` + `.suite.done` |

`dry-run` 不再代表「prepare 前先看看環境」。prepare 前的只讀檢查屬於 `gate`；正式 `dry-run` 必須鎖定 prepare 後即將進入 timed run 的真實狀態。`run` 必須核對 `.dry-run.done` 中的 config hash，若部署、設定或資料狀態改變就 fail-closed，重新從 gate 開始。

### 目前可驗證狀態

- `phase-k8s/manifest.yaml` 通過 `validate-phase-manifest.sh`。
- phase scope guard self-test 通過，shell scripts 通過 `bash -n`。
- S-K8S 六個 cell 都有 `.gate.done`、`.prepare.done`、`.gate-isolation.done`、`.run.done`、`.collect.done`、`.suite.done` 與 `summary.json`。
- 上述 S-K8S artifacts 早於本文件的七階段 contract，沒有 post-prepare `.dry-run.done` 與 pipeline `.summary.done`；可保留為歷史數據，但重跑時必須升級 schema，不能宣稱已符合新流程。
- YBDB limit 的 t128 只有 4/5 rounds；`.suite.done` 已記錄 deterministic hang caveat。
- 六個 S-K8S suite 都是 N=1，適合趨勢判讀，不足以升級成對外決策數據。

## 2. S-BASE 實驗步驟

### 2.1 實驗矩陣

1. VM 單節點：三家 DB × `rc / rr / strict`。TiDB 沒有原生 SERIALIZABLE，`strict` 以 RR 代表，不重複跑。
2. VM 三節點 direct：三家 DB × `1s1r / 1s3r / 3s1r / 3s3r`，只跑 RC。
3. VM 三節點 HAProxy：三家 DB × `haproxy-3s3r`，只跑 RC。

其中 `s` 是每表 shard 數，`r` 是 replication factor。VM 三節點在 prepare 後必須驗證實際 shard/RF，否則不能宣稱是 controlled experiment。

### 2.2 單一 cell 的正確時序

1. **Plan / preflight**：確認 DB、topology、isolation、唯一 timestamp、硬體與版本；先跑 syntax、inventory、SSH、磁碟、時間同步檢查。
2. **取得破壞性操作授權**：重建 VM、`destroy-vm3-all`、DROP/CREATE `tpcc` 都不可默認執行。
3. **Deploy**：只部署該 cell 需要的 DB 與 topology。
4. **Gate**：OS / chrony / disk / DB health / scope fail-closed。
5. **Prepare**：DROP/CREATE、載入 128W、ANALYZE、EXPLAIN、手動 shard split，再驗 shard/RF/placement 與資料完整性。
6. **Gate-iso**：使用 workload endpoint 與 connection params 開 active transaction，驗證 driver 看見的實際 isolation。
7. **Dry-run**：dump prepare 後的 node、RF、shard、isolation、routing、process/worker 與 health，產生 actual/config hash；審核通過才進 run。
8. **Run**：先驗 hash；cold reset；20 分鐘 warmup；依序跑 16/32/64/128，每組 5 rounds。
9. **Collect**：DB config、log tail、環境 snapshot、每節點 OS/process metrics。
10. **Summary / publish**：驗 marker、round、coverage，從 raw stdout 產 summary；搬到 `S-BASE` sibling 路徑並只引用 canonical artifact。

### 2.3 現況阻塞

目前不能把 `make -f Makefile.tc1 vm1-...` 或 `vm3-...` 當成可直接執行入口：

1. 頂層 `Makefile` 現在只 include `phase-crossregion/Makefile`。
2. `Makefile.tc1` 的高階 target 內使用裸 `$(MAKE)`；recursive make 會改讀頂層 `Makefile`，實測在 `deploy-vm1-tidb` / `destroy-vm3-all` 報 `No rule to make target`。
3. VM3 的 `EXECUTE=1` 會再次執行 `destroy → deploy → dry-run`，不是接續已審核的 dry-run state。
4. `vm1-*` 高階 target 會直接執行 `new-idc-vms`，包含 Terraform destroy/apply。

因此執行前應先修正 orchestration；不要以手動跳 gate 的方式繞過。

### 2.4 可直接交給 Codex 的 S-BASE prompt

```text
你在 /Users/wn.lin/vscode-git/dba_career/poc 工作。請依目前 repo 的真實狀態規劃並執行一個 S-BASE cell。

輸入：
- DB=<tidb|crdb|ybdb>
- TOPOLOGY=<vm-1node|vm-3node-1s1r|vm-3node-1s3r|vm-3node-3s1r|vm-3node-3s3r|vm-3node-haproxy-3s3r>
- ISO=<rc|rr|strict>；vm-3node 只能 rc；TiDB strict 不另跑
- REPEAT_N=<預設 1；決策級資料用 3>

先讀 results/PHASES.md、results/PoC-DESIGN.md、tests/common/run-vm1-suite.sh、tests/common/{gate,prepare,run,collect}.sh、tests/common/lib/guard.sh、Makefile.tc1。不得把歷史 tests/run-all 腳本當 v4.7 入口。

安全規則：
1. 第一階段只做 read-only audit 與 plan；不得執行 terraform destroy/apply、destroy-vm3-all、DROP DATABASE 或清 artifact。
2. 先重現並處理 Makefile.tc1 recursive make 問題。修正後用 make -n 證明所有 recursive target 都讀同一個 Makefile。
3. 把 dry-run 與 execute 分成兩個 target。execute 必須接收 APPROVED_DRY_RUN_TS 與 dry-run config hash，不得重新 destroy/deploy。
4. 列出所有將被刪除或重建的資源，等待我明確批准後才執行。

批准後流程只能是：deploy → gate → prepare → gate-iso → dry-run → run → collect → summary。dry-run 在 prepare 後執行，保存 actual/config hash；run 前必須重算 hash 並完全一致。run 內容為 cold reset → warmup 1200s@64 → threads 16/32/64/128，各 5×300s。

Acceptance criteria：
- artifact 路徑只能是 results/{db}-tc1/S-BASE/...
- 不得存在 TUNING_PROFILE、S-K8S、T-THRD、X-CROSS 污染
- `.gate.done/.prepare.done/.gate-isolation.done/.dry-run.done/.run.done/.collect.done/.summary.done/.suite.done` 全存在且順序正確
- dry-run 的 node/RF/shard/isolation/routing/process/config hash 全 pass；run 開始前 hash 相同
- summary thread keys 恰為 16/32/64/128；每組恰有 5 個有效 rounds
- summary 數字可從 go-tpc-stdout.txt 重算；列出 tpmC、NO p99、error rate、range/mean
- 任一 missing/timeout/hang/outlier 必標 caveat，不得自動排除
- REPEAT_N=3 時，每次使用獨立 fresh deploy/cold state，最後報 median、CV、95% CI，不只報最佳值

每完成一個 gate 回報證據路徑；不要只說 PASS。最後提供 canonical artifact、驗證命令輸出摘要與剩餘 caveat。
```

## 3. S-K8S 實驗步驟

### 3.1 實驗矩陣

三家 DB × `{unlimit, limit}`，共 6 cells：

- topology：`k8s-3node-haproxy-3s3r-{unlimit|limit}`
- isolation：RC only
- family：`k8s`
- NodePort：TiDB 30004、CockroachDB 30007、YBDB 30005
- 三個 K8s nodes 做 host-level metrics fan-out

`unlimit` 只表示沒有顯式 pod limit，不代表沒有 parent cgroup 或 kube-reserved 限制。

### 3.2 單一 cell 的正確時序

1. 驗 `manifest.yaml`、expected YAML、vars YAML、scope guard 與必要工具；清除前一 cell residue。
2. 部署該 DB + resource profile，等待 pod、PVC、HAProxy 與 NodePort ready。
3. **Gate**：K8s/node/DB readiness、chrony、磁碟、scope 與 endpoint。
4. **Prepare**：128W 載入、ANALYZE、split/RF gate。
5. **Gate-iso**：由 `.31` 透過正式 NodePort/HAProxy endpoint 驗 active RC。
6. **Dry-run**：prepare 後執行 `dump-actual → expected subset diff → compare VM allow/warn/deny → config hash`；任何 deny 都停止。
7. **Run**：hash 不變才 cold reset、warmup 與 sweep。
8. **Collect**：cleanup 前保存 kubectl events、pod describe/log、image digest、cgroup/pod 與三 node OS metrics。
9. **Summary**：驗 round completeness、markers、metrics coverage；artifact 搬到 `S-K8S`。
10. 完成該 DB 的 limit/unlimit pair review，再做 cleanup gate 並切換下一家。

### 3.3 可直接交給 Codex 的 S-K8S prompt

```text
你在 /Users/wn.lin/vscode-git/dba_career/poc 工作。請依 phase-k8s SSOT 執行 S-K8S 對照實驗。

輸入：
- DB=<tidb|crdb|ybdb>
- RESOURCE=<unlimit|limit>
- REPEAT_N=<預設 1；決策級資料用 3>

先讀 results/PHASES.md、phase-k8s/manifest.yaml、phase-k8s/expected/<db>-k8s-3node-haproxy-3s3r-<resource>.yaml、對應 vars/playbook、run-k8s-suite.sh、dump-actual.sh、diff-check.sh、compare-vm.sh、cell-cleanup-gate.sh 與 tests/common/{gate,prepare,run,collect}.sh。phase-k8s/README.md 與 test-plan-smoke.md 有過時段落，程式與 canonical artifacts 優先，但必回報文件漂移。

第一階段只做 audit：
- validate manifest、bash -n、guard self-test
- 驗 SSH/kubectl/ansible/yq/jq/go-tpc、node 時間同步、磁碟與 namespace residue
- 從 expected YAML 讀 namespace、NodePort、workload，不手打另一套值
- 列出 deploy/cleanup 會改動的資源，等待我批准

批准後逐 cell 嚴格執行：deploy → gate → prepare → gate-iso → dry-run → run → collect → summary。現有 pre-prepare `DRY_RUN=1` 行為要重構為 gate/preflight；正式 `.dry-run.done` 必須在 prepare 與 gate-iso 後產生。dry-run 要驗 `.diff-pass`、compare-vm deny_count=0、metadata 與 config hash；回報後等待 run approval。run 在同一 state 上執行 W=128、warmup=1200s@64、threads=16/32/64/128、各 5×300s。collect 後、cleanup 前保存 pod logs/describe/events、image digest、cgroup/pod CPU memory、三 node OS metrics；summary 完成後 fetch，再跑 cleanup gate。

Acceptance criteria：
- scope metadata 必為 phase-k8s/S-K8S/k8s/baseline_eligible=true/default
- expected workload/isolation/split/network deny fields零差異
- 三節點 metrics coverage 完整
- 八個 pipeline/suite markers 完整且 timestamp 順序符合七階段 contract
- thread keys 16/32/64/128，每組恰有 5 個有效 rounds；缺 round 不得標完整 PASS
- timeout/hang 要有 machine-readable incomplete 狀態，不得只靠 prose caveat
- summary 報 tpmC、NO p99、error rate、range/mean；limit/unlimit 與同 DB VM 只報 retention，不混入 VM ranking
- REPEAT_N=3 時報 median、CV、95% CI，並保存每次獨立 artifact

已知歷史 caveat：YBDB limit t128 曾 deterministic hang，TiDB unlimit t16 曾有單 round stall。不要預先排除；使用事前定義的 timeout/outlier policy，保留 raw data。

每個 gate 都附證據檔案與命令摘要。單一 DB 的 limit/unlimit pair review 完成後才進下一家。
```

## 4. 改善建議

### P0：先修才能可靠重跑

1. **七階段落地到程式**：把 `gate-isolation.sh` 從 `run.sh` 拆成獨立 stage；將 K8s/X-CROSS 目前的 pre-prepare DRY_RUN 改名 preflight，新增 post-prepare dry-run；summary 成為 wrapper 正式 stage。
2. **恢復正式入口**：把 S-BASE 從 `Makefile.tc1` 搬成 `phase-base/Makefile`，由頂層 Makefile include；禁止 recursive make 隱式選檔。
3. **dry-run/execute 真正分離**：execute 只接受已批准的 artifact ID + config hash，不可再次 destroy/deploy。
4. **controller provenance gate**：marker 固定記錄 controller hostname/IP；S-BASE/S-K8S/T-THRD 用 `.31`，X-CROSS 強制 `.31` 且拒絕 MAC localhost/IAP path。
5. **修文件漂移**：`phase-k8s/README.md`、`test-plan-smoke.md`、`results/README.md` 仍宣稱 wrapper/K8s 結果待完成；應由 artifact registry 生成狀態，避免手寫漂移。
6. **建立統一 suite verifier**：檢查 scope metadata、八個 markers、stage timestamp 順序、thread matrix、每組實際 round 數、raw stdout 可解析性、metrics coverage 與 caveat；不再只以 `.suite.done` 判成功。
7. **summary completeness fail-closed**：增加 `expected_rounds`、`observed_rounds`、`complete`、`incomplete_reason`；YBDB 4/5 不能與完整 5/5 共用無警示 schema。
8. **每 round watchdog**：明確 hard timeout、TERM/KILL 時序、driver exit code與 partial artifact；避免人工等 25 分鐘後才 SIGTERM。

### P1：提升科學可信度

1. 將 `requires_n` 從 1 提升到 3；每個 N 是完整獨立 suite，不是同一 suite 內的五個 rounds。
2. 事前定義 outlier policy；主要結果保留全部有效 runs，另做 sensitivity analysis，禁止看完數字才排除。
3. 報 median、CV、95% CI 與完整 per-run 數據，不只報最佳 thread 或單次 mean。
4. limit/unlimit 與 DB 執行順序採平衡或隨機化，降低時間、cache、硬體熱狀態偏差。
5. K8s 增加 pod/cgroup telemetry；目前 node-level mpstat/iostat 不能證明是哪個 pod 飽和。
6. cleanup 前永久保存 Kubernetes events、pod logs、describe 與 scheduler state；避免異常發生後無法溯因。

### P2：降低維運成本

1. 為 S-BASE 補 `manifest.yaml`，讓 VM/K8s 共用同一 experiment schema 生成 wrapper、expected 與 artifact metadata。
2. 在 CI 跑 manifest、guard、shell syntax、Make dry-run、README status/link 與 canonical artifact registry gate。
3. `summary-from-stdout.py` 改成正式 pipeline stage，不再依靠事後 retrofit。
4. 每個 artifact 固定保存 git commit、manifest SHA、playbook/vars SHA、DB image digest、kernel/K8s/DB 版本與硬體 fingerprint。
5. 將 canonical artifact 清單做成機器可讀 registry，再由 registry 生成 `results/README.md` 與各 pipeline status。

## 5. 本次盤點發現的其他問題

- `results/verify-readme-gates.sh` 目前因 `AI-COLLABORATION.md`、`audit-watch-prompt.md` 兩個連結不存在而失敗。
- `results/README.md` 仍把三家 Kubernetes 標為待重跑，但六個 canonical S-K8S suite 已存在。
- `phase-k8s/README.md` 與 `Makefile.tc1` 仍寫 `phase-k8s-run` 未實作，和 `run-k8s-suite.sh` full-chain 及現有 artifacts 矛盾。
- `test-plan-smoke.md` 同時保留早期 MVP/deferred 描述與後來已完成的 phase-2 實作，閱讀時容易誤判現況。
- 現有 S-K8S `summary.json` 的 phase metadata 不在 summary 頂層，需回查 `.suite.done`；應收斂成單一 schema。

## 6. 新增任務總覽

| 任務 | Scope / family | 基準 | 主要目的 |
|---|---|---|---|
| MySQL 8.4 Galera | 建議新增 `S-PXC` / `mysql-pxc` | S-BASE 同硬體與 workload | 建立 MySQL-compatible synchronous cluster 對照，量 single-writer / multi-writer 成本 |
| 三家 process/thread 研究 | 既有 `T-THRD` / `tuning` | 各 DB canonical S-BASE | 分離 SQL gateway process 數與 DB-native worker/concurrency 對效能的影響 |
| X-CROSS 完整流程 | 既有 `X-CROSS` / `crossregion` | 先 1 IDC + 1 GCP flow self-check，再升 3+3 | 在 `.31` 完成跨區 deploy、七階段 pipeline 與正式 W=128 設計 |

三個任務都必須遵循統一七階段 contract。新的 scope、manifest、wrapper 與 verifier 應由同一 schema 產生；不能複製舊 shell 後各自演化。

## 7. 任務一：MySQL 8.4 LTS Galera Cluster

### 7.1 技術選型與矩陣

「MySQL 8.4 LTS Galera」在本 PoC 明確實作為 **Percona XtraDB Cluster 8.4（PXC 8.4）**。PXC 8.4 以 Percona Server for MySQL 8.4 為基礎並整合 Galera；不是在 Oracle MySQL Community Server 上臨時掛未驗證 plugin。版本必須 pin 到 manifest 中的精確 8.4.x package/build，不可使用 floating `latest`。官方依據：[Percona XtraDB Cluster 8.4 documentation](https://docs.percona.com/percona-xtradb-cluster/)。

建議最小矩陣：

1. `pxc84-vm-1node-wsrep-off-rc`：同一 PXC 8.4 binary 的單節點 wsrep-off control，用來隔離 Galera replication 成本。
2. `pxc84-vm-3node-haproxy-single-writer-rc`：三節點 PXC，HAProxy 寫入只送一台。
3. `pxc84-vm-3node-haproxy-multi-writer-rc`：三節點 PXC，HAProxy 將寫入分散到三台，觀察 certification conflict / BF abort。

三台 PXC 分別放 IDC `.32/.33/.34`，controller 與 go-tpc 固定 `.31`；HAProxy 沿用獨立入口主機。PXC 每台都是完整資料副本，不得把 topology 命名成 S-BASE 的 `3 shards × RF3`。

### 7.2 可直接交給 Codex 的 PXC prompt

```text
你在 /Users/wn.lin/vscode-git/dba_career/poc 工作。新增一個以 S-BASE v4.7 workload 為基礎的 Percona XtraDB Cluster 8.4 實驗 track。

目標：
1. 建立 S-PXC scope、manifest、Ansible deploy/cleanup、HAProxy routing profiles、七階段 suite wrapper、summary/verifier 與結果目錄。
2. 跑三個 cell：pxc84-vm-1node-wsrep-off-rc、pxc84-vm-3node-haproxy-single-writer-rc、pxc84-vm-3node-haproxy-multi-writer-rc。
3. 保持 S-BASE 硬體與 workload：W=128、warmup 1200s@64、threads 16/32/64/128、各 5×300s；決策級 REPEAT_N=3。

技術約束：
- 使用官方 Percona XtraDB Cluster 8.4 package；先查官方 release，將 exact package/build、wsrep provider 與 XtraBackup 版本 pin 入 manifest。不要寫 Oracle MySQL 8.4 + 任意 Galera plugin。
- 單節點 control 使用同版 PXC/Percona Server binary 並明確關閉 wsrep；若另測 Oracle MySQL Community 8.4，必須獨立命名為 Group Replication/InnoDB Cluster track，不能稱為 Galera control。
- 三節點各放 .32/.33/.34；controller/client 只能是 .31。所有 DB/OS metrics fan-out 三台。
- 連線 isolation 固定 READ COMMITTED，透過 go-tpc 同 endpoint 的 active transaction 驗證。
- PXC traffic ports、SELinux/firewall、SSL、SST/IST、gcache、pxc_strict_mode 與 wsrep 設定必須由 playbook 管理並 dump。
- single-writer 與 multi-writer 是兩個獨立 routing profile；HAProxy actual backends 與 write routing 必須出現在 dry-run actual.yaml。
- 不得把 wsrep replicated apply 重複計成邏輯交易。go-tpc tpmC 是 workload 結果；cluster logical write cross-check 使用同時間點 sum(wsrep_local_commits rate)，物理 RW work 分節點報告。

先做 read-only audit 與設計，列出新增/修改檔案與破壞性動作；等我批准後才 deploy 或 DROP DATABASE。

每個 cell 固定執行：
gate → prepare → gate-iso → dry-run → run → collect → summary

各階段要求：
- gate：三台 mysql_up；wsrep_cluster_size=3、cluster_status=Primary、connected/ready=ON、local_state_comment=Synced；chrony/disk/ports/版本一致。
- prepare：只從指定 writer 載入 128W；等待三台 Synced、recv/send queue 收斂；三台 table count/schema/checksum 一致。
- gate-iso：從正式 HAProxy endpoint BEGIN 後驗 transaction_isolation=READ-COMMITTED。
- dry-run：保存 wsrep/PXC/MySQL config、HAProxy routing、process/thread、SST state、資料量、三台 health 與 config hash；不跑 timed workload。
- run：hash 不變才 cold reset + warmup + sweep；每 round 有 hard timeout，保存 client 與三台 node metrics。
- collect：保存 wsrep_local_commits、trx_rw/ro commits、cert failures、BF aborts、flow-control paused、recv/send queue、threads、CPU/IO/memory、error log。
- summary：驗八個 markers、round completeness 與 metrics coverage；報 tpmC、NO p99、error rate、CV、single-vs-multi writer delta。N=3 報 median 與 95% CI。

Acceptance：
- S-PXC 與 S-BASE/S-K8S/T-THRD/X-CROSS 路徑隔離，baseline family=mysql-pxc。
- 每個 timed round 三台均保持 Primary/Synced；若 membership 改變，該 round invalid 且 machine-readable 標記。
- single-writer 的 local commit 應集中指定節點；multi-writer 應有 routing 分散證據。
- certification/BF abort/flow control 不得只寫 prose，必須進 summary.json。
- 不把三台各自 percentile 相加；cluster series 必須先按 timestamp 對齊加總再算 percentile。
- 完成後只比較同硬體同 workload，明確區分 standalone MySQL 成本、PXC replication 成本與 multi-writer certification 成本。
```

## 8. 任務二：三家 process / thread / worker 效能研究

### 8.1 研究設計

此任務基於 S-BASE canonical topology，但結果必須寫入 `T-THRD`，`baseline_eligible=false`。go-tpc `threads` 是 client concurrency，不是 DB worker 數，兩者要做成正交矩陣。

跨家真正可比較的共同變因是 **可接受 client traffic 的 SQL gateway 數量**：1 / 2 / 3。底層三個 storage/raft members、shard、RF、資料與 HAProxy 都保持不變，只改 HAProxy active backends：

- TiDB：可路由 TiDB Server 數 1/2/3。
- CockroachDB：可路由 SQL gateway node 數 1/2/3；每個 `cockroach` process 仍同時承擔 KV/Raft。
- YugabyteDB：可路由 YSQL endpoint / YB-TServer 數 1/2/3；YSQL 與 DocDB 仍是耦合架構。

DB-native concurrency 是第二條研究軸，不能假設參數語意等價：

- TiDB：一次只測 `readpool.unified.max-thread-count`、`server.grpc-concurrency` 或 `tidb_executor_concurrency` 其中一個，levels 為 low/default/high。
- YugabyteDB：一次只測 `rpc_workers_limit` 或 `num_reactor_threads`，levels 為 low/default/high。
- CockroachDB：沒有等價的公開 worker pool；主研究只做 gateway 1/2/3。admission control on/off 可做獨立機制實驗，但不得命名成 worker-count 對照。

每個 native level 先從 actual default 與 CPU core 數導出，不在文件硬編會隨版本失效的數字。每個 cell 只改一個因子，其他 config hash 必須相同。

### 8.2 可直接交給 Codex 的 T-THRD prompt

```text
你在 /Users/wn.lin/vscode-git/dba_career/poc 工作。完成 TiDB、CockroachDB、YugabyteDB 的 process/thread/worker 控制變因研究框架與測試，基準取各家 S-BASE canonical vm-3node-haproxy-3s3r-rc。

先盤點 phase-threadcontrol。現況只有 manifest/README/vars/spec，run-threadcontrol-suite.sh 與 apply/revert playbooks 尚不存在；不可假裝可執行。先實作並測試 framework，再申請執行 benchmark。

研究拆成兩軸：
A. SQL_GATEWAY_COUNT=1,2,3：三家都做；三個 storage/raft members、RF、shard、資料集不變，只改 HAProxy active SQL endpoints。
B. DB_NATIVE_CONCURRENCY：
   - TiDB：readpool、grpc、executor 分成三個獨立 experiment family，每次只動一個 knob。
   - YBDB：rpc_workers、reactor 分成兩個獨立 family，每次只動一個 knob。
   - CRDB：worker-count=N/A；可另做 admission-default vs admission-off，但標為 admission mechanism，不納入 worker 數跨家排名。

每個 family 的 levels=low/default/high；先 dump actual default，再依 CPU cores 產生 levels 並寫 expected YAML。不得同時改 cache、memory、shard、RF、scheduler、admission 或 process count。go-tpc CLIENT_THREADS 固定 sweep 16/32/64/128，與 DB worker 軸分欄記錄。

所有輸出必須是 T-THRD/tuning/baseline_eligible=false，tuning_profile_id 格式為 <db>-<axis>-<level>。canonical S-BASE artifact 唯讀，不得覆寫。

先完成：
1. manifest schema 擴充 axis/level/control_artifact/config_hash。
2. run-threadcontrol-suite.sh，嚴格七階段：gate → prepare → gate-iso → dry-run → run → collect → summary。
3. 三家 apply/revert playbooks；apply 前後 config dump；revert 後與 control hash 相同。
4. HAProxy backend-count renderer + verifier，證明只有 active SQL gateways 改變。
5. unified summary/verifier，包含 process/thread actual、queue/admission metrics、markers、round completeness。
6. framework smoke 通過後回報，等待我批准正式 N=3 matrix。

實驗執行規則：
- 每個 cell 使用同一 S-BASE topology specification 重新建立 clean state；prepare 完再 gate-iso。
- dry-run 保存 process tree、thread count、effective config、HAProxy backends、RF/shard/leader distribution、資料量與 config hash。
- run 前重算 hash；不一致立即停止。
- 每個 level 做 N=3 independent suites；level 順序採平衡/隨機化，default 要在每個 family 前後各驗一次以偵測時間漂移。
- 每 round hard timeout；保存 CPU、run queue、context switches、IO、DB queue、RPC/admission、p99 與 error。
- summary 對每個 CLIENT_THREADS 報 tpmC、NO p99、error、CPU、CV；再報相對 default delta、median、95% CI。

Acceptance：
- 八個 markers 依序完整，summary 可從 raw stdout 重算。
- config diff 證明每 cell 只有指定因子改變；任何額外 drift 使 cell invalid。
- gateway 1/2/3 必須有 HAProxy routing 與每節點 connection/transaction distribution 證據。
- TiDB/YBDB native knob 只做同 DB 因果分析；不可用「8 workers」直接跨家排名。
- CRDB 沒有等價 worker knob要明列 N/A，不以非等價參數補數字。
- 報告要回答：何時增加 gateway/worker 提升 throughput、何時只增加 queue/p99、瓶頸是否從 SQL/RPC 轉移到 CPU/IO/Raft。
```

## 9. 任務三：X-CROSS 完整流程設計與 1+1 自檢

### 9.1 現況與分階段策略

目前 X-CROSS 已證明 3+3 W=4 流程可跑，但正式 W=128 尚未完成；`run-vm6-suite.sh` 只允許 TiDB，CockroachDB/YugabyteDB 由 Makefile 直接拼 common scripts，且預設 `localhost:12211-12213` 是 MAC 上的 IAP tunnel 假設。這不符合「從 `.31` 執行、MAC 不進 timed path」。

分兩階段：

1. **DEV-1x1 flow self-check**：每次一個 DB，1 IDC DB VM + 1 GCP DB VM，controller/client 固定 `.31`；W=4、threads=16、短 warmup、1 round。只驗七階段與跨區網路/placement/artifact，不做 HA、quorum、跨家效能結論。
2. **正式 3+3**：通過 promotion gates 後才跑 P-A/P-B 與 A-S/A-A-RO/A-A，W=128、20 分鐘 warmup、完整 sweep、N=5。

兩節點不能證明三節點 quorum、N-1 或正式 replication cost。DEV 模式應使用 DB-specific minimal RF/control-plane 設定並在 metadata 強制 `flow_selfcheck=true`、`baseline_eligible=false`。

### 9.2 可直接交給 Codex 的 X-CROSS prompt

```text
你在 /Users/wn.lin/vscode-git/dba_career/poc 工作。重構並完成 X-CROSS 的統一流程，先以 IDC VM×1 + GCP VM×1 做 flow self-check，再設計升級到正式 3+3。

核心限制：
- 所有 deploy、gate、prepare、gate-iso、dry-run、run、collect、summary 命令都從 IDC controller/client 172.24.40.31 執行。
- MAC 不得成為 controller、SSH jump、IAP localhost tunnel、metrics relay 或 timed workload path。MAC 只可編修程式，suite 完成後讀取複製出的 artifact。
- .31 必須直接到達 IDC/GCP 節點 private IP，或使用固定且記錄在 manifest 的非 MAC bastion。若 .31→GCP 沒路由，fail-closed 並先修網路；不得 fallback 到 localhost:122xx。
- 各 DB 依序執行，禁止同時跑造成 client/網路資源互相污染。

先讀 phase-crossregion manifest/README/NEXT-STEPS、run-vm6-suite.sh、Makefile、topology P-A/P-B、WAN/chrony/placement gates 與 results/x-cross/pipeline-log.md。明確列出現有缺口：wrapper 只支援 TiDB、CRDB/YBDB bypass wrapper、MAC IAP address、summary retrofit、W=128 target 缺失。

先完成 framework：
1. 建立 .31-native controller entrypoint；確認 .31 具備 repo checkout、Terraform/Ansible、cloud credentials、SSH key與必要 CLI；同步 scripts 到固定 release dir並記 git SHA，不從 MAC 逐步 ssh orchestration。
2. run-cross-suite.sh 支援 tidb/crdb/ybdb，統一七階段：gate → prepare → gate-iso → dry-run → run → collect → summary。
3. 將 chrony、WAN RTT/loss/MTU、雙向 DB/raft ports、SSH、磁碟、版本、scope 放 gate。
4. prepare 支援 DB-specific schema/load/RF/placement；gate-iso 使用 .31 的正式 endpoint。
5. dry-run 在 prepare 後驗 actual RF/shard/tablet、leader/leaseholder、placement、scheduler freeze、endpoint、資料量、process 與 config hash。
6. summary 成為正式 stage，不再事後 retrofit；加入 round completeness、WAN metrics coverage、placement stability 與 machine-readable caveat。
7. artifact 先完整留在 .31；.suite.done 後才可非同步複製到 results/x-cross/，複製動作不算 benchmark path。

DEV-1x1 matrix：
- DB=tidb,crdb,ybdb，各自單獨跑。
- 一台 IDC DB VM + 一台 GCP DB VM；.31 為唯一 workload client。
- PROFILE=A-S-dev、PLACEMENT=P-A-dev、W=4、CLIENT_THREADS=16、短 warmup、1×120s round。
- 使用各 DB 可運作的 minimal control-plane/RF；metadata 明列 reduced_quorum=true、flow_selfcheck=true。
- 目的只驗跨區雙向連線、資料載入、isolation、placement probe、timed run、collect、summary 與 artifact lineage。

DEV acceptance：
- 全程 command audit 顯示執行 host=.31，無 localhost:122xx、MAC path 或 MAC clock。
- 八個 markers 依序完整，config hash 在 dry-run→run 不變。
- IDC↔GCP 雙向應用/replication port、chrony、WAN probe 有 artifact。
- 三家各有可重算 summary.json；任何 DB-specific reduced topology caveat 明列。
- 不發布 retention、HA、quorum、RTO/RPO 或跨家排名。

DEV 全通過後提出正式 3+3 plan，等待我批准：
- 3 IDC + 3 GCP DB nodes，.31 controller；必要時由 .31 遠端啟動 GCP-side load generator，但 orchestration/clock lineage仍由 .31 控制。
- P-A/P-B × A-S/A-A-RO/A-A × 3 DB；先 P-A A-S，再逐 gate promotion，不一次全跑。
- W=128、warmup 1200s@64、threads 16/32/64/128、各 5×300s、N=5 independent suites。
- prepare 後 leader/leaseholder placement 100% 符合 policy；run 前 freeze scheduler/balancer並驗穩定。
- 報 tpmC、NO p99/error、WAN RTT/loss、commit latency、placement drift、CV/CI；X-CROSS 維持 baseline_eligible=false。
- chaos/RTO/RPO 不混入 steady-state suite，需獨立批准與 probe driver。

最後交付：框架變更、DEV 三家 evidence、完整 3+3 matrix/工時/風險、promotion checklist，以及所有尚未滿足而阻止正式 W=128 的 blocker。不得用 DEV-1x1 PASS 宣稱 X-CROSS 效能測試完成。
```
