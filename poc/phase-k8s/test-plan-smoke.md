# phase-k8s — Smoke Test Plan (1 cell, k8s haproxy-3s3r 等價)

> Goal: 驗證 phase-k8s wrapper + S-K8S artifact path + fan-out metrics (k8s-node-N) + manifest 全鏈在 K8s 環境下 work；不追求三家完整對照。

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
| 3 shard via manual `SPLIT TABLE warehouse` | 同手動 SPLIT（post-prepare）|
| HAProxy `.20:4000` round-robin | NodePort `:30004` + K8s `Service` round-robin（k3s 預設 iptables mode）|
| `tests/common/run.sh` SSH 至 `.32/.33/.34` 採 metrics | SSH 至 k8s-node-1/2/3（=.32/.33/.34，本來就是 K3s host）採 node-level metrics |

→ K8s 與 VM haproxy-3s3r 在 baseline_family 區隔下**機制等價**；tpmC 數字差異視為 K8s vs VM family 對比的 sample point。

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

# === Stage 1: 跑 phase-k8s smoke suite ===
# IMPORTANT (codex v6 blocking #3): prepare-k8s.sh 內部處理 prepare → SPLIT → mark .prepare.done。
# 不能在 suite 啟動前外部跑 SPLIT，因為 suite 內 prepare.sh 會 DROP+CREATE 把 SPLIT 抹掉。
TS=$(date '+%Y%m%dT%H%M%S%z')

# wrapper invocation — thin wrapper sets env + delegates to tests/common/run.sh
# codex v6 blocking #5: TIDB_PORT 必須是 env (run.sh 不吃 --port)
# codex v6 blocking #1: phase wrapper 入口先 guard
ssh root@172.24.40.31 "env \
  TPCC_TS=${TS} \
  PHASE_NAME=phase-k8s \
  RESULT_SCOPE=S-K8S \
  BASELINE_ELIGIBLE=true \
  BASELINE_FAMILY=k8s \
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
| 2 | `phase-k8s/run-k8s-suite.sh` | **thin phase wrapper**（codex v6 blocking #1）：入口先 `source tests/common/lib/guard.sh; assert_phase_k8s_target "$ROOT"`，然後 export `CLUSTER_HOSTS` + `PHASE_NAME` + `RESULT_SCOPE` + `BASELINE_ELIGIBLE` + `TIDB_PORT=30004` + `TPCC_ARTIFACTS`，最後 delegate 到 baseline `launch-vm1-suite.sh` (or 內建 gate → prepare-k8s → run → collect chain) |
| 3 | `phase-k8s/gate-k8s.sh` | K8s OS gate：`kubectl get pods -A` 驗 ready + `nc -zv 172.24.40.32 30004` 驗 NodePort |
| 4 | `phase-k8s/prepare-k8s.sh` | **prepare → SPLIT → mark**（codex v6 blocking #3）：(a) go-tpc prepare via NodePort (b) `SPLIT TABLE warehouse BETWEEN (1) AND (128) REGIONS 3` (c) verify 3 region via `information_schema.tikv_region_status` (d) write `.prepare.done`。順序固定，避免外部 SPLIT 被內部 DROP 清掉 |
| 5 | `phase-k8s/collect-k8s.sh` | `kubectl logs --tail=1000 -l app.kubernetes.io/name=tidb` + `kubectl describe pod -l app.kubernetes.io/name=tidb` + 三家 status playbook output |
| 6 | `tests/common/lib/common.sh::write_phase_done` patch | env auto-inject `phase`/`result_scope`/`baseline_eligible`/`tuning_profile_id`（codex v6 blocking #2，與 phase-threadcontrol 共用）|
| 7 | Makefile `phase-k8s-run` target body | 取代目前 exit 1；call ssh + launch wrapper |

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
| Stage 1（SPLIT TABLE）| ~5 min |
| Stage 2（v4.7 suite run）| ~3h |
| Stage 3（fetch + verify）| ~10 min |
| **合計（首次，含 deliverable 補）** | **~1-1.5 工作天** |
| **合計（純 run, deliverable 已就緒）**| **~4h** |

## 變更歷史

| 日期 | commit | 變更 |
|---|---|---|
| 2026-06-06 | （本 commit）| 初版 smoke plan，Q1-Q6 拍板（cell=1 / topology=k8s-haproxy-3s3r 等價 / wrapper=thin / VM rebuild 排在 phase-threadcontrol 之後）|
| 2026-06-06 | （本 commit fixup）| codex v6 review changes-required 修正 6 blocking：topology 命名 `haproxy-3s3r` 一致 / `TIDB_PORT` 用 env / Stage 1 改為 suite 內 prepare-k8s.sh (prepare→SPLIT→mark) / phase wrapper 入口先 guard / `write_phase_done` env auto-inject 規劃 / deliverable list 補 #6 common.sh patch |
