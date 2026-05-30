# PoC results 審計與進度監督 — Codex Prompt

> **用法**：
> ```bash
> cd /Users/wn.lin/vscode-git/dba_career/poc
> codex exec - < results/audit-watch-prompt.md
> ```
>
> 本 prompt 合併文件審計與長期進度監督。預設不修改檔案、不 commit、不 push；只輸出審計 / 監督報告與具體建議。
> 重要任務: 避免任何邏輯 / 數據 / 流程 或其他相關技術可見的瑕疵及錯誤發生。 EX: 設定 3 shard / 3 replica ; 結果設定找不到 ; 測試結果無法對照參考，導致數據不可性。

---

你在 `/Users/wn.lin/vscode-git/dba_career/poc` 內擔任 PoC results 旁觀者架構師、文件校驗者與執行進度監督者。

## 最高指導原則

優先遵循以下文件：

- `results/AI-COLLABORATION.md`
- `results/README-template.md`
- `results/pipeline-log-template.md`
- `results/audit-prompt.md`
- `results/audit-watch-prompt.md`

鎖定文件：

- `results/README.md`
- `results/PoC-DESIGN.md`
- `results/tidb-tc1/S-BASE/pipeline-log.md`
- `results/yuga-tc1/S-BASE/pipeline-log.md`（v4.7 active）
- `results/yuga-tc1-old/S-BASE/pipeline-log.md` + `pipeline-log_old.md`（pre-v4.7 archive，只確認 active log 是否有 pointer）
- `results/crdb-tc1/S-BASE/pipeline-log.md`
- `results/cockroach-tc1/S-BASE/pipeline-log.md`（舊版資料，只確認 deprecated / migrated 標示是否清楚）
- `results/dispatch-records/`（vm-3node 4 cells 跨 cell 分析、HAProxy vs direct 分析、首次 dispatch 中斷處置等紀錄）

## 核心任務

1. 根據 `results/AI-COLLABORATION.md` 的審計精神，檢查 results 文件是否符合目前 PoC 文件規範。
2. 同時承擔長期監督職責：監督、協作、複查、檢驗、校驗、建議、進度確認及規格對齊。
3. 進度監督涵蓋全測試矩陣（vm-1node 三 isolation + vm-3node 4 sub-topology + vm-3node-haproxy-3s3r + Kubernetes 兩變體）；每次執行都要確認目前狀態、缺口與是否需要更新文件。
4. 自動確認相關更新是否已 commit；若有未 commit 變更，需明確列出。
5. 本次以 audit / watch / report 為主，不要修改檔案。

## 審計原則

- **artifact-first**：所有數字必須能追溯到 `results/` 下的結果目錄、marker、go-tpc stdout、summary、DB-host OS 監控或 pipeline log。
- **no invented numbers**：不得創造或推估數據；找不到來源就標 `missing source`。
- **README as index**：`README.md` 只作結果索引；`pipeline-log.md` 承載流程、分析、踩坑、技術細節與 caveat；跨 cell 觀察落地於 `dispatch-records/<日期>-<scope>-analysis.md`。
- **clean tables**：表格保持乾淨；長解釋放到文末註解或 dedicated caveat。
- **linked notes**：差異說明使用 `[註1](#note-1)` 到 `[註4](#note-4)`，並可引用補充 `[N1]`–`[N10]`；文末集中解釋。
- **required fields**：已驗證結果需包含來源目錄 link、tpmC、p99、error rate；vm-3node / HAProxy 結果額外需標 `N`（獨立重跑次數）。
- **method separation**：v4.7 5-round mean 與 pre-v4.7 single-run wrapper 不可混用。
- **fact vs inference**：機制歸因要區分直接量測、合理推論、未知；缺 DB metrics / trace 時必須標示推測。
- **language rule**：正文使用 `TiDB` / `CockroachDB` / `YugabyteDB`，不使用 `CRDB` / `YBDB`；不使用「產物」一詞。
- **YugabyteDB triple gate**：isolation 須三層通過（default flag + enable flag + active/effective）；範例 SQL 改用 `SELECT yb_get_effective_transaction_isolation_level()`，舊 `SHOW yb_effective_transaction_isolation_level` 已 deprecated。
- **sample size aware**：`N` = 獨立重跑次數（不是 round）。`N=1` 僅作為方向性觀察、不作為對外定論；對外結論需 `N=3`。引用 README [N9](./README.md#note-N9)。
- **batch-readiness preflight**：把 batch 由 Mac 搬到 `.31`（或任何新 controller）前，必須先在新 controller 上跑 `ansible-playbook --syntax-check` + `ansible-galaxy collection list` 比對 Mac 一致（曾踩過 `ansible.posix` collection 缺失導致 batch 跑 30s 即 fail，浪費 1 cell TPCC_TS）。新 controller 同時要驗 `ssh root@<DB-host>` 通、`/usr/bin/python3.x` 版本可跑 ansible setup module、磁碟空間 ≥ 預計 artifact 量。
- **data extraction traceability**：主要數據表應記錄工作目錄、使用檔案、取數指令、計算口徑；若缺失需列為 finding。

## 執行進度檢查

請檢查全測試矩陣的目前狀態：

- vm-1node：gate / prepare / gate-isolation / run / collect / suite marker 是否完整（三 DB × 三 isolation = 9 組）。
- vm-3node：4 sub-topology（1s1r / 1s3r / 3s1r / 3s3r）× 3 DB = 12 cells；dry-run anchor `.dry-run.done` 是否 `all_pass=true`；EXECUTE=1 後是否有完整 suite marker。
- vm-3node-haproxy-3s3r：HAProxy 變體 3 cells 是否完成；DB-host metrics 是否齊全；HAProxy timeout 與 keepalive 設定是否生效。
- 是否有新的結果目錄、summary、go-tpc stdout、DB-host OS 監控。
- isolation gate 是否符合目標隔離級（YugabyteDB 須通過 triple gate）。
- README.md 與各 pipeline-log.md、`dispatch-records/` 是否同步。
- 相關更新是否已 commit。
- 沒有新異動時回報 `standby`，但仍需列出 git status 與最近 HEAD。
- 發現異常時列出具體路徑、問題、風險與建議下一步。

## 建議先執行的檢查指令

```bash
git status --short
git log --oneline -5
rg -n "CRDB|YBDB|產物|TODO|待補|推測|註[1-4]" results/README.md results/*-tc1/S-BASE/pipeline-log.md
rg -n "SHOW yb_effective_transaction_isolation_level" results/ tests/ ansible/   # deprecated，期望僅出現於 yuga-tc1-old/ 或歷史 dispatch-records
find results -path "*vm-1node*" \( -name ".gate.done" -o -name ".prepare.done" -o -name ".gate-isolation.done" -o -name ".run.done" -o -name ".collect.done" -o -name ".suite.done" \)
find results -path "*vm-3node*" \( -name ".dry-run.done" -o -name ".suite.done" \)
find results -path "*vm-3node*haproxy*" -name "summary.json"
find results -path "*vm-1node*" \( -name "summary.json" -o -name "go-tpc-stdout.txt" \)
rg -n "取數來源|取數指令索引|error rate|來源目錄|N=1|N=3" results/README.md results/*-tc1/S-BASE/pipeline-log.md results/dispatch-records/
```

### Batch-readiness preflight（搬 batch 到新 controller 前必跑）

```bash
# 1. ansible syntax-check：playbook 在新 controller 解析得了？
ssh root@<新-controller> 'cd <poc-batch-dir>/ansible && ansible-playbook --syntax-check playbooks/<db>-vm3.yml -e <db>_sub_topology=1s1r'

# 2. collection 對齊：對照 Mac 已用 collection（避免 ansible.posix 等缺漏，曾踩過）
ssh root@<新-controller> 'ansible-galaxy collection list 2>&1 | grep -E "ansible.(posix|builtin)"'
ansible-galaxy collection list 2>&1 | grep -E "ansible.(posix|builtin)"   # Mac 對照

# 3. ssh 連線：新 controller 對 vm3_db (.32/.33/.34) + haproxy (.20) 是否可 ssh root
ssh root@<新-controller> 'for h in 172.24.40.32 172.24.40.33 172.24.40.34 172.24.47.20; do ssh -o ConnectTimeout=3 -o BatchMode=yes "root@$h" "hostname" 2>&1 | head -1; done'

# 4. Python 版本（ansible setup module 需 3.7+；.20 monitor host 是 3.6 已知問題）
ssh root@<新-controller> '/usr/bin/python3 --version; /usr/bin/python3.12 --version 2>/dev/null'

# 5. 磁碟：artifact 估算（vm-3node 4 cells × ~50 MB = ~200 MB；haproxy 同量）
ssh root@<新-controller> 'df -h /tmp /root 2>/dev/null | tail -3'
```

## 審計維度

| 代號 | 維度 | 檢查重點 |
|---|---|---|
| D1 | 錯誤登錄數據 | tpmC / latency / error rate / CPU / IO 表格數字是否內部一致；round-by-round 與 5-round mean 是否能對齊；HAProxy vs direct 差異計算口徑是否註明 |
| D2 | 語意正確性 | isolation / retry / WAL / Raft / MVCC 等機制描述是否有 artifact 或官方文件支持 |
| D3 | 文件可讀性 | 標題層級、表格欄位、註解連結、用詞是否符合 template |
| D4 | 完整性 | 是否每個 `(db, iso)` 或 `(db, sub-topology)` 有環境、結果、DB-host 飽和分析、對比、結論、取數來源 |
| D5 | 跨檔一致性 | README、pipeline log、`dispatch-records/` 對同一數字、狀態、來源目錄是否一致 |
| D6 | 進度與 commit 狀態 | 新 artifact 是否已反映到文件；文件更新是否已 commit |
| D7 | YB triple gate / deprecated SQL | YugabyteDB 範例與 gate 流程是否仍引用 deprecated `SHOW yb_effective_transaction_isolation_level`；應改 `SELECT yb_get_effective_transaction_isolation_level()`，並確認三層 gate 皆有 artifact |
| D8 | 樣本數 `N` | vm-3node / HAProxy 結果是否標 `N`；`N=1` 是否有 caveat；對外結論是否避免 `N=1` 單獨支持 |
| D9 | Batch-readiness 移植驗證 | 把 batch（dispatch loop）搬到新 controller 前，是否跑過 `ansible-playbook --syntax-check`、`ansible-galaxy collection list` 對齊、ssh / Python 版本 / 磁碟 preflight；缺一就視為 batch 未準備好（曾踩 ansible.posix 缺失 → 1 cell TPCC_TS 作廢）|
| D10 | Cluster leader 平衡（RF>1 必驗）| vm-3node RF>1 拓樸 deploy 後須驗 region/tablet leader 分佈：每 store 應持有 ≈ `total_regions / N_stores` 個 leader（±20% 容差）。若全集中於單 store → 拓樸實效退化為「single-store-leader + 多 follower」，failed to deliver "3 stores 同時寫" 設計初衷。<br>**TiDB**：`tidb-vm3.yml` 寫死 `pd.schedule.leader-schedule-limit=0`（從 vm-1node 沿用未解）→ PD 不會 rebalance；2026-05-30 Cell 4 (3s3r) 實測 27/27 leaders 全在單 store。修法：vm-3node 此值改回預設 4；vm-1node 可保留 0。<br>**YugabyteDB**：playbook 沒 disable `--load_balancer_enabled`，走預設 true → master 自動均衡，**不踩同坑**（doc-level 證據；如要 first-hand 驗證見下方指令）。<br>**CockroachDB**：類似 ybdb，cluster setting `kv.allocator.load_based_lease_rebalancing.enabled` 預設 true → 自動均衡。<br>**驗證指令**：<br>- TiDB: `mysql ... -e "SELECT p.STORE_ID, COUNT(*) FROM information_schema.tikv_region_peers p JOIN information_schema.tikv_region_status r ON p.REGION_ID=r.REGION_ID WHERE p.IS_LEADER=1 AND r.DB_NAME='tpcc' GROUP BY p.STORE_ID"`<br>- YugabyteDB: `yb-admin --master_addresses=... get_load_balancer_state` + `list_tablets ysql.yugabyte <tbl>` 看 leader_uuid 分佈<br>- CockroachDB: `SHOW RANGES FROM TABLE <tbl>` 看 lease_holder 分佈 |

## 輸出格式

```markdown
# PoC results 審計與進度監督報告 — <yyyy-mm-dd>

## 1. 目前狀態
- git HEAD：<short SHA>
- git status：<clean / dirty + files>
- 本次是否 standby：<yes/no>

## 2. 全測試矩陣進度
### 2.1 vm-1node（三 isolation）
| Database | READ COMMITTED | REPEATABLE READ | 最嚴格隔離級 | 缺口 |
|---|---|---|---|---|
| TiDB | ... | ... | ... | ... |
| CockroachDB | ... | ... | ... | ... |
| YugabyteDB | ... | ... | ... | ... |

### 2.2 vm-3node（4 sub-topology × RC）
| Database | 1s1r | 1s3r | 3s1r | 3s3r | haproxy-3s3r | 缺口 |
|---|---|---|---|---|---|---|
| TiDB | ... | ... | ... | ... | ... | ... |
| CockroachDB | ... | ... | ... | ... | ... | ... |
| YugabyteDB | ... | ... | ... | ... | ... | ... |

## 3. Critical Findings
### F-001 [D?] <短描述>
- 位置：
- 證據：
- 風險：
- 建議：

## 4. Major Findings
...

## 5. Minor Findings
...

## 6. 文件一致性檢查
| 項目 | README | TiDB | CockroachDB | YugabyteDB | 結果 |
|---|---|---|---|---|---|
| 來源目錄 link | ... | ... | ... | ... | ✓/✗ |
| error rate | ... | ... | ... | ... | ✓/✗ |
| 註解連結 | ... | ... | ... | ... | ✓/✗ |
| 取數來源 | ... | ... | ... | ... | ✓/✗ |

## 7. 需要人工確認的問題
- ...

## 8. 下一步建議
- ...
```

## 限制

- 不要憑空補數字。
- 不要把尚未完成的測試寫成已完成。
- 不要修改任何檔案，除非使用者明確要求 `fix` / `apply` / `commit`。
- 不要 commit、不要 push。
- 若建議修改，請指出具體檔案與段落。

開始審計與監督。
