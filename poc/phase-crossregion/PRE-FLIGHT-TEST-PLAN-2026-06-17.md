# phase-crossregion Pre-flight Test Plan — 2026-06-17 (v2)

> ⚠️ **Status: framework reserve / business ready 才啟動完整 sweep**
> 對齊 D1（跨區 DR 中長期必需 / 現行 No）；本 plan 為「**啟動時**的 SSOT」，不代表現在已 ready-to-run。
>
> Status: **draft v2**（codex 2026-06-17 review 後修補；15 處 fixes 已套入）
> 用途：phase-crossregion sweep 啟動前 / 各執行階段前 環境驗證 checklist
> 適用：9 cell-tracks × 360 rounds × 150h sweep + F1 + Chaos
> SSOT：`REPLAN-2026-06-15.md` / `decisions-2026-06-08.md` / `manifest.yaml`

---

## 0. 預修補項（啟動 sweep 前必補）

1. **wan-probe.sh SSH warning text 混入 rx_bytes bug** — 加 `-o LogLevel=ERROR` 或 grep filter；L5 測量層依賴
2. **D1 framework reserve 對齊**：本 plan 是規範，不是 ready statement；首段警語已加

---

## 1. 環境分層（5 層）

| 層 | 範圍 | 失效後果 |
|---|---|---|
| **L1 機器** | IDC 3 VM + GCP 5 VM；OS / 磁碟 / 套件 | 沒 host 跑、SSH 不通 |
| **L2 網路** | IDC↔GCP 連通；IAP tunnel；chrony drift | 跨區 raft 不收斂 / drift 爆 |
| **L3 部署** | DB cluster 6-node 起 / 版本對齊 / placement policy 建立 | cluster broken / placement 錯 |
| **L4 應用** | tpcc DB + tables 建立；placement actual 套到 tables；go-tpc binary；COMMON_DIR rsync；HAProxy backend health | run-time 撞 missing dep / placement 形同未套 |
| **L5 測量** | metrics dir 可寫 / disk free / artifact 結構 / summary lineage / fetch 完整性 | 跑完撈不到資料 / lineage broken |

---

## 2. 階段過渡 checklist（A–J；共 10 階段）

### Stage A — terraform apply 前（GCP VM 重建前）

| # | 檢查 | 指令 | 預期 | fail |
|---|---|---|---|---|
| A1 | terraform code valid | `cd iac-gcp && terraform validate` | `Success!` | BLOCKER |
| A2 | terraform plan diff 對齊預期 | `terraform plan -input=false -no-color \| grep "Plan:"` | `Plan: N to add, M to change, K to destroy` **數字由 operator review 是否合理**（5/0/0 全新；0/0/0 已存在 OK） | BLOCKER 若超預期 |
| A3 | tfvars 兩必填 var 已設 | `grep -c '^root_password\\|^ssh_public_key' iac-gcp/terraform.tfvars` | 2 | BLOCKER |
| A4 | gcloud auth active account | `gcloud auth list` | active = 預期帳號 | BLOCKER |
| A5 | gcloud project 對 | `gcloud config get-value project` | `lab-service-project-dba` | BLOCKER |
| A6 | API enabled | `gcloud services list --enabled \| grep -E 'compute\|iap'` | 兩個都列 | BLOCKER |
| A7 | CPU quota（5 × e2-standard-4 = 20 vCPU） | `gcloud compute project-info describe --format='value(quotas)' \| grep -i cpus` | quota ≥ 20 | BLOCKER（申請提額 24-48h）|
| A8 | terraform state 乾淨（無殘留 resource） | `cd iac-gcp && terraform state list` | empty 或符合預期 | BLOCKER 若殘留 → `terraform destroy` |
| A9 | SPOT / preemption risk acknowledgment | 確認 main.tf `provisioning_model=SPOT` + 預期 sweep 期間可被回收；review resume 策略 | operator sign-off | BLOCKER（生產 sweep 不建議 SPOT）|
| A10 | 預估 spend / IAP quota | `gcloud quotas list --filter='IAP'` + 簡算 GCP 5 VM × 月費 | 預算覆蓋 | HIGH |

### Stage B — GCP VM apply 後 / IAP tunnel 前

| # | 檢查 | 指令 | 預期 | fail |
|---|---|---|---|---|
| B1 | 5 VM Running | `gcloud compute instances list --filter='name~g-test-poc' --format='table(name,status,zone)'` | 5 列 RUNNING | BLOCKER |
| B2 | startup-script 完成（python3.12 / chronyd / tuned） | `gcloud compute ssh g-test-poc-1 --tunnel-through-iap -- 'python3 --version; systemctl is-active chronyd tuned'` | python3.12 + active × 2 | HIGH（等 1-2 min 或手動補）|
| B3 | OS hostname 與預期一致 | `gcloud compute ssh g-test-poc-1 --tunnel-through-iap -- 'hostname'` | `g-test-poc-1` | BLOCKER |

### Stage C — IAP tunnel 起後 / Ansible deploy 前

| # | 檢查 | 指令 | 預期 | fail |
|---|---|---|---|---|
| C1 | IAP tunnel 5 條 listening | `lsof -nP -iTCP:12211-12215 -sTCP:LISTEN \| wc -l` | ≥ 5 | BLOCKER |
| C2 | ssh -p 12211..15 root@localhost 通 | `for p in 12211 12212 12213 12214 12215; do ssh -i ~/.ssh/id_rsa -o ConnectTimeout=5 -p $p root@localhost hostname; done` | 5 個 hostname 對 | BLOCKER |
| C3 | IDC 3 node SSH 通 | `for h in 172.24.40.32 172.24.40.33 172.24.40.34; do ssh -o ConnectTimeout=5 root@$h hostname; done` | 3 host 通 | BLOCKER |
| C4 | **chrony 10-host drift gate < 100ms (fail-closed)** | `bash phase-crossregion/scripts/gate-chrony-cross-region.sh --ts <ts> --root-suffix prelaunch-<ts> --result-scope X-CROSS` | `verdict=PASS / drift_median < 100ms / 10/10 Leap=Normal` | **BLOCKER**（整 sweep 停） |
| C5 | IDC baseline reset 完成 | `bash phase-crossregion/scripts/idc-vm-baseline-reset.sh --db all --dry-run` 確認 → `--execute` | snapshot before/after + disk free ≥ 50GB | BLOCKER |
| C6 | ansible -m ping all 通 | `ansible -i ansible/inventory/crossregion.ini all -m ping` | 10 hosts SUCCESS | BLOCKER |
| C7 | placement SQL 檔案存在 controller | `ls tests/{tidb,cockroach,yuga}/placement-p-{a,b}.sql` | 6 個 SQL 檔（**TiDB-only dry-run 只需 tests/tidb/× 2；CRDB/YBDB 在 9 cell-tracks 完整 sweep 才需要全 6 個**）| BLOCKER if 對應 DB 範圍 |

### Stage D — ansible deploy 後 / suite run 前

| # | 檢查 | 指令 | 預期 | fail |
|---|---|---|---|---|
| D1 | DB cluster 6 nodes Running | per DB（見下） | 6 node 全 ready | BLOCKER |
|   | TiDB | `tiup cluster display tpcc-tidb-vm6 \| grep Up \| wc -l` | ≥ 6 | BLOCKER |
|   | CRDB | `cockroach node status --insecure --host=172.24.40.32:26257 \| grep -c 'true.*true'` | 6 nodes is_live=true | BLOCKER |
|   | YBDB | `yb-admin --master_addresses ... list_all_tablet_servers \| grep -c ALIVE` | 6 tservers ALIVE | BLOCKER |
| D2 | DB 版本對齊 manifest | per-DB version 對齊 manifest 預期 | 對齊 | HIGH |
| D3 | placement policy CREATE 已 deploy-time 套（per B0-3 階段 a）| TiDB `SHOW PLACEMENT LABELS` / CRDB `SHOW ZONE CONFIGURATIONS` / YBDB `SELECT * FROM pg_tablespace` | policy / zone / tablespace 已建（**tpcc tables 此時不存在；ALTER TABLE 留 Stage E**）| BLOCKER |
| D4 | **IDC HAProxy `.47.20` backend health** | `mysql -h 172.24.40.32 -P 4000 -uroot -e 'SELECT 1' --connect-timeout=5`（透過 haproxy 試連 backend）；haproxy stats socket 路徑/port 由 ops 確認後補（目前不寫死） | SQL 通 ⇒ backend up | BLOCKER |
| D5 | **GCP HAProxy `10.160.152.14` backend health** | 從 GCP client 跑同邏輯 | backend up + SQL 通 | BLOCKER |
| D6 | go-tpc binary 在 IDC client (.31) | `ssh root@172.24.40.31 'go-tpc tpcc --help \| head -3'` | 可呼叫 | BLOCKER |
| D7 | go-tpc binary 在 GCP client (g-test-poc-5) | `ssh -p 12215 root@localhost 'go-tpc tpcc --help \| head -3'` | 可呼叫 | BLOCKER（A-A/A-A-RO 必要）|
| D8 | **go-tpc --mix 語法支援** | `go-tpc tpcc run --help \| grep -i mix` | flag 存在；A-A-RO 用得到 | BLOCKER if A-A-RO |
| D9 | COMMON_DIR rsync done | `ssh root@172.24.40.31 'ls /tmp/poc-tpcc/scripts/run.sh prepare.sh gate.sh collect.sh'` | 4 script 在 | BLOCKER |
| D10 | manifest validation | `bash tests/common/validate-phase-manifest.sh phase-crossregion/manifest.yaml` | OK | BLOCKER |

### Stage E — suite 啟動 / prepare 後 / warmup 前

| # | 檢查 | 指令 | 預期 | fail |
|---|---|---|---|---|
| E1 | DRY_RUN=1 path 跑通 | `DRY_RUN=1 CLIENT_ZONE=idc bash phase-crossregion/scripts/run-vm6-suite.sh --db tidb --topology vm-6node-P-A --ts <ts>` + env | 5-step PASS + `.dry-run.done` 寫入 | BLOCKER |
| E2 | CLIENT_ZONE 必填驗證 PASS | E1 內 | DB_HOST ∈ allowed zone | BLOCKER |
| E3 | A-A-RO GO_TPC_MIX_FLAG 設定 | run.sh log 印 `--mix ...` | A-A-RO cell 有 / 其他 cell 無 | BLOCKER（A-A-RO）|
| E4 | artifact dir 乾淨 | `ls $ROOT \| wc -l` ≤ 5 | 不被舊 data 污染 | HIGH（換 TS 重啟）|
| E5 | flock 不被搶 | `flock_phase` 不卡 | run 一次只能一份 | BLOCKER |
| E6 | **prepare 完成後 placement ACTUAL 套到 tables 成功** | TiDB `SHOW PLACEMENT FOR TABLE tpcc.warehouse` / CRDB `SHOW ZONE CONFIGURATION FROM TABLE tpcc.warehouse` / YBDB `\\d tpcc.warehouse` | 預期 policy / zone 已套（per run-vm6-suite.sh post-prepare ALTER TABLE）| BLOCKER |

### Stage F — warmup 完成 / 每 cell-track 第一 round 啟動前

> cold-reset 已於 cell 啟動時做了一次（per v4.7 既有設計，非每 round）；本階段不重做

| # | 檢查 | 指令 / 自動化 | 預期 | fail |
|---|---|---|---|---|
| F1 | chrony drift 仍 < 100ms | per-cell wan-probe.sh warmup-post（auto）| warn-only 但顯著超標 → 人工 review | HIGH（drift 飆高停 sweep）|
| F2 | wan-probe warmup-post 採樣 | auto from run.sh hook | `.wan-probe-warmup-post.txt` 寫入 | LOW（warn-only） |
| F3 | cluster 健康 | TiDB `tiup cluster display` / CRDB `node status` / YBDB `list_all_tablet_servers` | 6 node alive | HIGH |
| F4 | artifact disk free | `df -h $TPCC_ARTIFACTS \| awk 'NR==2 {print $4}'` | ≥ 30GB | HIGH（rotate 舊 artifact）|
| F5 | warmup 真實有跑 ≥ 1000s | `wc -l warmup.log` 應 > N | tpmC 已穩 | HIGH |

### Stage G — round 結束 / 下一 round 啟動前

| # | 檢查 | 指令 | 預期 | fail |
|---|---|---|---|---|
| G1 | wan-probe round-post 採樣 | auto | `.wan-probe-round-post.txt` 寫入 | LOW |
| G2 | round artifact 完整 5 個監測 | `ls $RD/{go-tpc-stdout,iostat-1s,mpstat,vmstat-1s,sar-net}*.txt` | 全有（或 fan-out 6 host suffix） | HIGH（缺檔 → round 標 invalid）|
| G3 | **error rate < 1%** | per-round `_ERR` parse | < 1% | **HIGH**（> 1% 結果不可信）|
| G4 | round 真實有跑 ~300s | `grep '^\[Summary\] NEW_ORDER' $RD/go-tpc-stdout.txt \| awk '{print $NF}'` | Takes(s) ≈ 300 | HIGH（異常長 → outlier）|
| G5 | OOM / disk monitor (sweep 中段) | sweep 中段每 N round 跑 `dmesg \| grep -i oom-killer` + `df -h $TPCC_ARTIFACTS` | 無 OOM 且 disk free ≥ 30GB | HIGH（sweep 拖長期會撞）|
| G6 | **SPOT VM preemption check** | `gcloud compute instances list --filter='name~g-test-poc' --format='value(status)'` | 全 RUNNING | BLOCKER（被回收 → sweep 中斷）|

### Stage H — 一 cell-track 完成 / 跨 cell-track 切換前

| # | 檢查 | 指令 | 預期 | fail |
|---|---|---|---|---|
| H1 | IDC-local round 數 = 20（4 thread × 5 round） | `find $ROOT/runs/threads-*/round-*/go-tpc-stdout.txt \| wc -l` | 20 | HIGH |
| H2 | .run.done 寫入 | `ls $ROOT/.run.done` | 在 | HIGH（run.sh 異常退 → 查 log）|
| H3 | db-config dump 5 個檔案 | `ls $ROOT/db-config/` | cluster-settings / effective-config / isolation / etc | HIGH |
| H4 | .collect.done 寫入 | `ls $ROOT/.collect.done` | 在 | HIGH |
| H5 | .suite.done 寫入 | `ls $ROOT/.suite.done` | 在 | HIGH（wrapper write_phase_done 補）|
| H6 | **summary.json 生成 + TPCC_TS lineage** | `cat $ROOT/.suite.done \| jq .ts; ls $ROOT/summary.json` | summary 含 ts / cell / tpmC / p99；lineage 對齊 manifest schema | HIGH |
| H7 | **GCP client artifact fetch / consolidate**（A-A / A-A-RO 才有）| `rsync -av -e 'ssh -i ~/.ssh/id_rsa -p 12215' root@localhost:/tmp/poc-tpcc/artifacts/$RUN_DIR/ $ROOT/gcp-side/` | GCP 端 artifact 都拿回，H7 後 IDC + GCP 兩側合 40 stdout | HIGH |
| H8 | **跨 cell-track baseline reset** | 下個 cell-track 前跑 `phase-crossregion/scripts/idc-vm-baseline-reset.sh --db <next-cell-db> --execute` | snapshot 對比；disk recovered | BLOCKER 若 DB 切換 |

### Stage I — chaos / F1 啟動前（Tier 2；目前 planner-only）

> 目前**只**有 planner-only；下表是未來 `--execute` PR review 時必跑。
> **嚴禁** verbal 確認 — 必走 PR / issue sign-off template（見 §3.3）

| # | 檢查 | 預期 | fail |
|---|---|---|---|
| I1 | planner script 跑過 + plan output 已 owner sign-off | plan.txt 已 review | BLOCKER |
| I2 | 維護視窗時段（非營業時段）| timestamp 在 maintenance window | BLOCKER |
| I3 | PR 含 dba-approved + sre-approved labels | PR labels 確認 | BLOCKER |
| I4 | rollback procedure documented 且測過 | 對應 `chaos-cN-recover.sh` 或 spec 有 recover step + dry-run 跑過 | BLOCKER |
| I5 | cluster healthy 60s consecutive | cluster_info × 6 polls 全 OK | BLOCKER |
| I6 | observability ready（promtail / kubectl events / cluster log shipping） | log endpoint reachable | BLOCKER |

### Stage J — sweep 全部完成 / commit / archive 前

| # | 檢查 | 指令 | 預期 | fail |
|---|---|---|---|---|
| J1 | 9 cell-track × 對應 round 數齊全 | `find results/x-cross/ -name '.suite.done' \| wc -l` | 9（3 DB × 3 profile） | HIGH |
| J2 | summary 對 manifest schema | per-cell `jq` 驗 fields | 全合規 | HIGH |
| J3 | GCP VM destroy 完 | `cd iac-gcp && terraform state list \| wc -l` | 0 | BLOCKER（節費）|
| J4 | IAP tunnel 清乾淨 | `lsof -nP -iTCP:12211-12215` | empty | LOW |

---

## 3. fail 嚴重度矩陣與處置

| 嚴重度 | 範例 check | 處置 |
|---|---|---|
| **BLOCKER** | A1-A9 / B1 B3 / C1-C7 / D1-D10 / E1-E2 E5 E6 / G6 SPOT / H8 / I 全部 / J3 | sweep 停；修；重試 |
| **HIGH** | A10 / B2 / D2 / E3 E4 / F1 F3-F5 / G2-G5 / H1-H7 / J1 J2 | per-cell skip 或修；可不中斷整 sweep |
| **MEDIUM** | （目前無；如有暫不穩 phenomena 再分） | 等 / rotate / warn |
| **LOW** | F2 / G1 / J4 wan-probe / IAP cleanup | log 留痕，繼續 |

### 3.1 chrony drift 不可為 LOW
- C4 fail-closed = BLOCKER
- F1 sweep 中飆高 = HIGH（不是 LOW，因影響 cross-region transaction 時間戳）

### 3.2 error rate > 1% 必 HIGH
- 不只「anomaly round」，是「該 round 結果不可信」
- 整 cell-track 若 ≥ 50% rounds error rate > 1% → 全 cell-track 標 unreliable

### 3.3 Chaos / F1 --execute PR sign-off template

```markdown
## Chaos / F1 Execute PR Template

**Target**: <DB> <node|cluster|placement>
**Scenario**: <C1 / C4 / C7 / F1>
**Duration**: <N seconds>
**Inject command preview**: (planner.txt link)
**Rollback command**: <link>
**Maintenance window**: <UTC time range>

### Reviewers
- [ ] DBA approver: <name>
- [ ] SRE approver: <name>
- [ ] Cell owner: <name>

### Pre-flight checklist (must check all)
- [ ] Cluster healthy 60s consecutive (I5)
- [ ] Observability ready (I6)
- [ ] Rollback dry-run passed (I4)
- [ ] In maintenance window (I2)
- [ ] No conflicting sweep running

### Sign-off
- [ ] User: I confirm this is non-production / acceptable risk
- [ ] DBA: I'll be on call during execution
```

---

## 4. 自動化 vs 人工分工

| 階段 | 模式 |
|---|---|
| A1-A10 | **半自動**（terraform / gcloud CLI），最終 apply 由人工 review plan 後執行 |
| B1-B3 | 半自動（cloud-init polling）|
| C1-C7 | 半自動（chrony gate fail-closed auto；其他 manual SSH check）|
| D1-D10 | 半自動（ansible deploy 結尾 + ansible -m ping 後 manual review）|
| E1-E6 | **全自動** in `DRY_RUN=1` path + post-prepare placement gate |
| F1-F5 | **全自動** in `run.sh` hook |
| G1-G6 | **全自動** in `run.sh` round loop |
| H1-H8 | **半自動**（collect.sh + write_phase_done + manual GCP fetch / baseline reset）|
| I1-I6 | **嚴格人工 + PR sign-off**（never auto-execute）|
| J1-J4 | **半自動**（archive script + manual destroy + cleanup）|

---

## 5. 與既有 framework 對應

| Stage | 對應 script / 機制 | commit |
|---|---|---|
| A | iac-gcp/ + Agent 2 audit (2026-06-15) | (existing) |
| B | iac-gcp/main.tf metadata.startup-script | 0c17ae9 |
| C4 | `phase-crossregion/scripts/gate-chrony-cross-region.sh` | 801c1b4 |
| C5 / H8 | `phase-crossregion/scripts/idc-vm-baseline-reset.sh` | 42b7a55 |
| D | `ansible/playbooks/{tidb,cockroach,yugabyte}-vm6.yml` | 0c17ae9 + 42b7a55 |
| E1 / E6 | `phase-crossregion/scripts/run-vm6-suite.sh` DRY_RUN path + post-prepare placement ALTER | 339d453 (§0 B0-1 / B0-3) |
| F2 / G1 | `phase-crossregion/scripts/wan-probe.sh` + `tests/common/run.sh` hook | 42b7a55 |
| G3 | per round go-tpc-stdout `_ERR` parse；analytics 已含 error rate 表 | 41b88b3 |
| H | `tests/common/{collect.sh,lib/common.sh::write_phase_done}` | existing |
| I | `phase-crossregion/scripts/chaos/*-plan.sh` / `run-vm6-failover-plan.sh` | 42b7a55 |
| J | (待補：archive + cleanup script) | TBD |

---

## 6. 預修補（啟動 sweep 前必補）

1. `wan-probe.sh` 加 `ssh -o LogLevel=ERROR` 過濾 SSH warning text；驗 rx_bytes / tx_bytes 數字純粹
2. 補 `tests/common/validate-phase-manifest.sh` 對應 `phase-crossregion/manifest.yaml` path
3. SPOT VM 換為 standard provisioning（sweep 期間，per A9）or 接受被 preempt 並寫 resume 邏輯
4. iperf3 server 安裝（per WAN_PROBE_IPERF=1 啟用前）
5. Stage J archive + cleanup script 補
