# phase-k8s — Smoke Test Plan (1 cell, k8s haproxy-3s3r 等價, two-stage)

> Goal: 驗證 phase-k8s wrapper + S-K8S artifact path + fan-out metrics (k8s-node-N) + manifest 全鏈在 K8s 環境下 work；不追求三家完整對照。
>
> **兩階段測試**（2026-06-06 user 新指示）：先 Stage 1 dry-run 驗 K8s deploy + NodePort + manifest + SPLIT 順序；通過才進 Stage 2 real benchmark。

## 0. 兩階段測試（two-stage）

| Stage | 範圍 | 估時 | 失敗 → |
|---|---|---|---|
| **Stage 1 — dry-run** | K8s deploy + NodePort `kubectl get pods` + `ss -ltnp` TiKV port + manifest patch verify + dry-run wrapper env trace + `DRY_RUN=1` 跑到 prepare 前停 + dry-run-confirm anchor；**NOT go-tpc prepare / SPLIT / warmup / run**（K8s SPLIT 驗證留 Stage 2 因為需 table 存在）| ~30 min | redeploy K8s + 修 wrapper bug |
| **Stage 2 — real benchmark** | 完整 v4.7 K8s suite（go-tpc prepare via NodePort + 9-table SPLIT + verify + warmup + 4 thread × 5 round × 5min + collect + fetch + commit）| ~3-4h | rollback K8s state + redeploy |

**DRY_RUN env flag**（沿用 phase-threadcontrol 同一 deliverable）：

- `DRY_RUN=1` 跑：K8s pod ready check + NodePort 通 + `ss -ltnp` 20180 預檢 + manifest patch verify + wrapper env trace
- `DRY_RUN=1` 不跑：go-tpc prepare（128W table create）+ SPLIT + warmup + thread sweep
- 輸出：`dry-run/{process-check,db-config-check,wrapper-env-trace,k8s-pod-ready,nodeport-check}.txt` + `.dry-run.done`

## 1. 範疇

| 項 | 值 |
|---|---|
| Cell 數 | **1** |
| Topology | `k8s-3node-haproxy-3s3r-unlimit`（K8s 3-node + TiKV 3 pod × 3 replica + post-deploy SPLIT TABLE + NodePort 取代 HAProxy）|
| DB | TiDB |
| Resource | unlimit（最乾淨；resource limit 留後續 cell）|
| Isolation | `rc` |
| Output path | `results/tidb-tc1/S-K8S/tidb-k8s-3node-haproxy-3s3r-unlimit-rc-<TS>/` |
| 預估時間 | ~3h（同 VM v4.7 suite）|

## 2. 與 phase-k8s/manifest.yaml 對齊

manifest.yaml 目前：
```yaml
allowed_topology:
  - k8s-3node-limit
  - k8s-3node-unlimit
```

本 smoke 引入新 topology `k8s-3node-haproxy-3s3r-unlimit`，**須先 update manifest** 加入：
```yaml
allowed_topology:
  - k8s-3node-limit
  - k8s-3node-unlimit
  - k8s-3node-haproxy-3s3r-limit
  - k8s-3node-haproxy-3s3r-unlimit
```

manifest patch 為本 smoke pre-req。

## 3. K8s 與 VM haproxy-3s3r 對應

| VM 元件 | K8s 對應 |
|---|---|
| 3 個 TiKV process on .32/.33/.34 | TiDB Operator 自動建 3 個 TiKV Pod（每 node 1 個）|
| **9-table 全 split 為 3 region**（VM 3s3r baseline 慣例：warehouse, district, customer, history, new_order, order_line, orders, item, stock）| 同 9-table split via post-prepare `SPLIT TABLE <name> BETWEEN (1) AND (128) REGIONS 3`；per-table shard count verify |
| HAProxy `.20:4000` round-robin | NodePort `:30004` + K8s `Service` round-robin（k3s 預設 iptables mode）|
| `tests/common/run.sh` SSH 至 `.32/.33/.34` 採 metrics | SSH 至 k8s-node-1/2/3（=.32/.33/.34，本來就是 K3s host）採 node-level metrics |

→ K8s 與 VM haproxy-3s3r 在 baseline_family 區隔下**機制等價**；tpmC 數字差異視為 K8s vs VM family 對比的 sample point。

**Critical**（codex v7 blocking #2）：必須 9-table 全 split；只 split warehouse 結果不能稱為等價對照。詳 prepare-k8s.sh deliverable spec（§7 #4）。

## 4. 環境前置 / 假設

| 項 | 狀態 |
|---|---|
| 3 VM (.32/.33/.34) | **destroy + apply iac-idc**（phase-threadcontrol smoke 完成後）|
| K3s server / agent | 經 `ansible-playbook playbooks/k8s.yml` deploy |
| TiDB Operator + cluster | 經 `ansible-playbook playbooks/tidb-k8s.yml` deploy（vars=`tidb-k8s-3node-unlimit.yml`）|
| go-tpc client `.31` | 既有 |
| Connection endpoint | NodePort `172.24.40.32:30004`（也可 `.33` / `.34`，K8s Service 會 round-robin）|

## 5. 執行步驟

```bash
# === Stage 0: VM rebuild + K8s deploy ===
make new-idc-vms                                   # destroy + apply iac-idc
make ansible-ping                                  # confirm SSH
make ansible-setup                                 # site.yml + tpcc-client-ssh.yml

cd ansible
ansible-playbook -i ../ansible/inventory/hosts.ini playbooks/k8s.yml
ansible-playbook -i ../ansible/inventory/hosts.ini playbooks/tidb-k8s.yml \
  --extra-vars '@vars/tidb-k8s-3node-unlimit.yml'
ansible-playbook -i ../ansible/inventory/hosts.ini playbooks/tidb-k8s-status.yml

# 確認 NodePort 通：
mysql -h 172.24.40.32 -P 30004 -u root -D mysql -e 'SELECT @@version;'

# === Stage 1a: dry-run via DRY_RUN=1 ===
# IMPORTANT (codex v6 blocking #3): prepare-k8s.sh 內部處理 prepare → SPLIT → mark .prepare.done。
# 不能在 suite 啟動前外部跑 SPLIT，因為 suite 內 prepare.sh 會 DROP+CREATE 把 SPLIT 抹掉。
TS=$(date '+%Y%m%dT%H%M%S%z')

# wrapper invocation — thin wrapper sets env + delegates to tests/common/run.sh
# codex v6 blocking #5: TIDB_PORT 必須是 env (run.sh 不吃 --port)
# codex v6 blocking #1: phase wrapper 入口先 guard
ssh root@172.24.40.31 "env \
  DRY_RUN=1 \
  TPCC_TS=${TS} \
  PHASE_NAME=phase-k8s \
  RESULT_SCOPE=S-K8S \
  BASELINE_ELIGIBLE=true \
  BASELINE_FAMILY=k8s \
  TUNING_PROFILE=default \
  TIDB_HOST=172.24.40.32 \
  TIDB_PORT=30004 \
  CLUSTER_HOSTS='k8s-node-1@172.24.40.32 k8s-node-2@172.24.40.33 k8s-node-3@172.24.40.34' \
  TPCC_ARTIFACTS=/tmp/poc-tpcc/artifacts/S-K8S \
  bash /tmp/poc-tpcc/scripts/run-k8s-suite.sh \
    --db tidb --iso rc --topology k8s-3node-haproxy-3s3r-unlimit \
    --db-host 172.24.40.32 --ts ${TS}"

# 等 ~30 min；fetch dry-run artifact
DRY_OUT="results/tidb-tc1/S-K8S/tidb-k8s-3node-haproxy-3s3r-unlimit-rc-${TS}-dry-run"
rsync -av "root@172.24.40.31:/tmp/poc-tpcc/artifacts/S-K8S/tidb-k8s-3node-haproxy-3s3r-unlimit-rc-${TS}/" "$DRY_OUT/"

# === Stage 1 acceptance check ===
jq '.phase, .result_scope, .baseline_eligible, .baseline_family' "$DRY_OUT/.dry-run.done"
# expected: "phase-k8s" "S-K8S" true "k8s"
test -s "$DRY_OUT/dry-run/k8s-pod-ready.txt"
test -s "$DRY_OUT/dry-run/nodeport-check.txt"
test -s "$DRY_OUT/dry-run/wrapper-env-trace.txt"

# Stage 1 通過 → 進 Stage 2；不通過 → STOP, 修 K8s wrapper / NodePort / TiKV pod。

# === Stage 1b: Stage 2 real benchmark via run-k8s-suite.sh (DRY_RUN unset) ===
ssh root@172.24.40.31 "env \
  TPCC_TS=${TS} \
  PHASE_NAME=phase-k8s \
  RESULT_SCOPE=S-K8S \
  BASELINE_ELIGIBLE=true \
  BASELINE_FAMILY=k8s \
  TUNING_PROFILE=default \
  TIDB_HOST=172.24.40.32 \
  TIDB_PORT=30004 \
  CLUSTER_HOSTS='k8s-node-1@172.24.40.32 k8s-node-2@172.24.40.33 k8s-node-3@172.24.40.34' \
  TPCC_ARTIFACTS=/tmp/poc-tpcc/artifacts/S-K8S \
  bash /tmp/poc-tpcc/scripts/run-k8s-suite.sh \
    --db tidb --iso rc --topology k8s-3node-haproxy-3s3r-unlimit \
    --db-host 172.24.40.32 --ts ${TS}"

# === Stage 2: 等待 + fetch + verify ===
# 等 ~3h
rsync -av root@172.24.40.31:/tmp/poc-tpcc/artifacts/S-K8S/tidb-k8s-3node-haproxy-3s3r-unlimit-rc-${TS}/ \
  results/tidb-tc1/S-K8S/tidb-k8s-3node-haproxy-3s3r-unlimit-rc-${TS}/

# verify markers
jq '.phase, .result_scope, .baseline_eligible' \
  results/tidb-tc1/S-K8S/tidb-k8s-3node-haproxy-3s3r-unlimit-rc-${TS}/.suite.done
# expected: "phase-k8s" "S-K8S" true

# verify fan-out metrics existence
ls results/tidb-tc1/S-K8S/.../runs/threads-128/round-3/mpstat-db-k8s-node-*.txt
# expected: 3 files (k8s-node-1, -2, -3)

# verify metrics/hosts.json
cat results/tidb-tc1/S-K8S/.../runs/threads-128/round-3/metrics/hosts.json
# expected: 3 entries with kind=k8s-node, region=idc, ssh_host=172.24.40.{32,33,34}
```

## 6. 成功條件

- [ ] artifact 落於 `results/tidb-tc1/S-K8S/`（含 `/S-K8S/` segment）
- [ ] `.suite.done` JSON 含 `result_scope: S-K8S`、`baseline_eligible: true`、`baseline_family: k8s`
- [ ] per-round 含 3 個 `mpstat-db-k8s-node-{1,2,3}.txt`（fan-out 落地）
- [ ] `metrics/hosts.json` 含 3 entry，全 `kind: k8s-node` + `region: idc`
- [ ] `make run-vm1-tidb-rc` （baseline target）不受影響（無 regression）
- [ ] `bash results/verify-readme-gates.sh` 6/6 PASS
- [ ] tpmC vs `vm-3node-haproxy-3s3r-rc` baseline 數字落地於本 doc「結果」段（K8s vs VM family delta；caveat: 不可作為 baseline 對標）

## 7. Pending（執行前須補的 deliverable）

| # | 檔 | 內容 |
|---|---|---|
| 1 | `phase-k8s/manifest.yaml` patch | `allowed_topology` 加 `k8s-3node-haproxy-3s3r-{limit,unlimit}`（codex v6 blocking #4 一致命名）|
| 2 | `phase-k8s/run-k8s-suite.sh` | **thin phase wrapper**（codex v7 blocking #1 修正：**唯一 chain**，不 delegate baseline launcher）：(a) 入口先 `source tests/common/lib/guard.sh; assert_phase_k8s_target "$ROOT"` (b) validate `PHASE_NAME=phase-k8s` + `RESULT_SCOPE=S-K8S` + `BASELINE_ELIGIBLE=true` + `BASELINE_FAMILY=k8s` 已正確 set（漏設 → fail-fast）(c) export `CLUSTER_HOSTS` + `TIDB_PORT=30004` + `TPCC_ARTIFACTS` (d) **固定 chain**：`gate-k8s.sh` → `prepare-k8s.sh` → `tests/common/run.sh` → `collect-k8s.sh` → write `.suite.done`（含 phase/result_scope/baseline_eligible/baseline_family 全 metadata）|
| 3 | `phase-k8s/gate-k8s.sh` | K8s OS gate：`kubectl get pods -A` 驗 ready + `nc -zv 172.24.40.32 30004` 驗 NodePort + `ssh root@<each k8s-node> 'ss -ltnp \| grep 20180'` 驗 TiKV status port |
| 4 | `phase-k8s/prepare-k8s.sh` | **prepare → 9-table SPLIT (mirror VM TiDB) → verify → mark**（codex v6 blocking #3 + v7 blocking #2 + v8 blocking）：<br>(a) go-tpc prepare via NodePort（生成 9 TPCC tables）<br>(b) **9-table split SQL 必須 mirror VM TiDB 實作**（[`tests/common/prepare.sh:134-144`](../tests/common/prepare.sh)），不可用 generic BETWEEN/REGIONS（會觸發 ERROR 8212 region size too small）：<br>```sql<br>SPLIT TABLE warehouse  BY (43),         (86);<br>SPLIT TABLE district   BY (43, 1),      (86, 1);<br>SPLIT TABLE customer   BY (43, 1, 1),   (86, 1, 1);<br>SPLIT TABLE new_order  BY (43, 1, 2101),(86, 1, 2101);<br>SPLIT TABLE orders     BY (43, 1, 1),   (86, 1, 1);<br>SPLIT TABLE order_line BY (43,1,1,1),   (86,1,1,1);<br>SPLIT TABLE stock      BY (43, 1),      (86, 1);<br>SPLIT TABLE item       BY (33334),      (66667);<br>SPLIT TABLE history    BY (1280000),    (2560000);<br>```<br>(c) per-table verify：先試 `information_schema.tikv_region_status` group by TABLE_NAME；失敗則 fallback `SHOW TABLE <name> REGIONS`；**兩者結果都正規化到同一 schema** 寫入 `prepare/shard-count.txt`（per-table region 數）；最終 9 表都未驗到 ≥3 region → hard fail（codex v8/v9 non-blocking）<br>(d) write `.prepare.done` 含 per-table shard count（與 shard-count.txt 同一資料） |
| 5 | `phase-k8s/collect-k8s.sh` | `kubectl logs --tail=1000 -l app.kubernetes.io/name=tidb` + `kubectl describe pod -l app.kubernetes.io/name=tidb` + 三家 status playbook output |
| 6 | `tests/common/lib/common.sh::write_phase_done` patch | env auto-inject（codex v6 blocking #2 + v7-v9 細化）：<br>**Required 4 (common)**: `PHASE_NAME` / `RESULT_SCOPE` / `BASELINE_ELIGIBLE` / `BASELINE_FAMILY`<br>**Conditional**: `RESULT_SCOPE=T-THRD` → `TUNING_PROFILE` 必填且 ≠ `default`；其他 phase 自動寫 `tuning_profile_id=default`<br>**規則**：任一上述 env 出現 → 必驗對應 env + `$ROOT` scope 一致；缺一 `die` + `exit 1`<br>4 common env 全未設 → legacy baseline 行為 |
| 7 | `tests/common/run-vm1-suite.sh` + `tests/common/prepare.sh` scope guard | codex v8 non-blocking #2：對 `/S-K8S/` 與 `/X-CROSS/` / `/T-THRD/` scope artifact path fail-fast（要求只能走對應 phase wrapper，不能從 baseline launcher 進來）|
| 8 | Makefile `phase-k8s-run` target body | 取代目前 exit 1；call ssh + launch wrapper |
| 9 | **`tests/common/run.sh` DRY_RUN flag**（與 phase-threadcontrol 共用 deliverable）| 新增 `DRY_RUN=1` env：跑到 prepare 前停；產 `dry-run/{process-check, db-config-check, wrapper-env-trace, k8s-pod-ready, nodeport-check}.txt` + `.dry-run.done` marker。K8s 場景需新增 K8s-specific dump（kubectl get pods + nc -zv NodePort + ss -ltnp 20180 via SSH）|

## 8. Rollback

| 失敗類型 | rollback action |
|---|---|
| K8s deploy 失敗 | `make new-idc-vms` 重新開始 |
| TiDB Pod CrashLoop | `kubectl describe pod` + `kubectl logs` 看原因；視情況改 vars 再 redeploy |
| Suite 跑到一半 | `make status` 看 marker；rerun 或 manual cleanup |
| Fan-out metrics 未生成 | 驗 `$CLUSTER_HOSTS` env 確實設定 + `host-resolution.sh` debug |

## 9. 估時

| Stage | 時間 |
|---|---|
| Pending deliverable 補 (5 scripts + Makefile body + manifest patch) | ~半天-1 天 |
| Stage 0（VM rebuild + K8s deploy）| ~30 min |
| Stage 1（phase-k8s smoke suite: gate-k8s + prepare-k8s(prepare+9-table split+verify) + run + collect）| ~3h 15min |
| Stage 2（fetch + verify markers + per-table shard）| ~10 min |
| **合計（首次，含 deliverable 補）** | **~1-1.5 工作天** |
| **合計（純 run, deliverable 已就緒）**| **~4h** |

## 變更歷史

| 日期 | commit | 變更 |
|---|---|---|
| 2026-06-06 | （本 commit）| 初版 smoke plan，Q1-Q6 拍板（cell=1 / topology=k8s-haproxy-3s3r 等價 / wrapper=thin / VM rebuild 排在 phase-threadcontrol 之後）|
| 2026-06-06 | （本 commit fixup）| codex v6 review changes-required 修正 6 blocking：topology 命名 `haproxy-3s3r` 一致 / `TIDB_PORT` 用 env / Stage 1 改為 suite 內 prepare-k8s.sh (prepare→SPLIT→mark) / phase wrapper 入口先 guard / `write_phase_done` env auto-inject 規劃 / deliverable list 補 #6 common.sh patch |
| 2026-06-06 | （本 commit fixup-2）| codex v7 review changes-required 修正 2 blocking + 4 non-blocking：(1) wrapper 改唯一 chain `gate-k8s → prepare-k8s → run → collect-k8s`，不 delegate baseline launcher (2) prepare-k8s.sh 9-table 全 split + per-table shard verify (3) write_phase_done env validate fail-fast (4) gate-k8s.sh 補 `ss -ltnp` 20180 預檢 (5) baseline_family 加入 marker (6) Stage 1 估時 wording 整併（SPLIT 已併入 prepare）|
| 2026-06-06 | （本 commit fixup-3）| codex v8 review changes-required 修正 1 blocking + 3 non-blocking：(1) prepare-k8s.sh split SQL 改 mirror VM TiDB 明確 split points（`SPLIT TABLE <name> BY (43)...(86)...`）取代 generic BETWEEN/REGIONS，避免 ERROR 8212 region too small；(2) SHOW TABLE REGIONS fallback；(3) write_phase_done 改 die()/exit 1，5 phase env 任一出現必驗全 + scope；(4) 新增 deliverable #8: launch-vm1-suite.sh + prepare.sh 對 /S-K8S/ /T-THRD/ /X-CROSS/ scope fail-fast |
| 2026-06-06 | （本 commit fixup-4）| codex v9 review non-blocking 修正：write_phase_done 規則細化（4 common required + RESULT_SCOPE=T-THRD 時 TUNING_PROFILE 必填且 ≠ default）；deliverable 編號 1-8 順序整理；prepare-k8s.sh fallback 結果與 information_schema 結果正規化到同一 shard-count.txt schema |
