# phase-threadcontrol — Smoke Test Plan (1 cell)

> Goal: 驗證 phase-threadcontrol 三層 hard gate + manifest + T-THRD artifact path 全鏈在真實 run 下 work；不追求 throughput 結論。

## 1. 範疇

| 項 | 值 |
|---|---|
| Cell 數 | **1** |
| Topology | `vm-3node-haproxy-3s3r`（既有 baseline，符合 phase-threadcontrol/manifest.yaml allowed_topology）|
| DB | TiDB |
| Isolation | `rc` |
| Knob category | TiKV `readpool.unified.max-thread-count` + `readpool.unified.auto-adjust-pool-size` |
| Tuning profile id | `tidb-readpool-a` |
| Baseline 對照 | 既有 `results/tidb-tc1/S-BASE/vm-3node-haproxy-3s3r-rc/tidb-vm-3node-haproxy-3s3r-rc-20260601T003316+0800/summary.json` |
| 結果 output path | `results/tidb-tc1/T-THRD/tidb-vm-3node-haproxy-3s3r-rc-tidb-readpool-a-<TS>/` |
| Suite wrapper | **`phase-threadcontrol/run-threadcontrol-suite.sh`**（新增；外層 guard 包 `launch-vm1-suite.sh` 之前先 assert_threadcontrol_target + export env）|
| 預估時間 | ~3h（gate + prepare + warmup 20min + 4 thread × 5 round × 5min = ~25min × 4 thr + collect）|

## 2. Knob 變動內容

| 參數 | Default | 本 smoke | 目的 |
|---|---|---|---|
| `readpool.unified.max-thread-count` | `MIN(CPU_cores, 16)` = 4（4 vCPU 機器）| **8**（2× CPU cores）| 驗 CPU 飽和下加倍 read pool 對 tpmC / p99 影響 |
| `readpool.unified.auto-adjust-pool-size` | `true` | **`false`**（鎖死值）| 避免 auto-adjust 蓋過手動設定 |

其他參數**完全不動**（保留 vm-3node-haproxy-3s3r baseline 對應）。

## 3. 環境前置 / 假設

| 項 | 狀態 |
|---|---|
| 3 VM (.32/.33/.34) | **保留**目前 vm-3node-haproxy-3s3r 部署狀態（不 destroy） |
| TiDB cluster | 已 deploy；可用 `make status-vm3-tidb-haproxy-3s3r-rc` 確認 |
| HAProxy `.20:4000` | 已 active |
| go-tpc client `.31` | 既有 |
| baseline summary.json | 必存在 `results/tidb-tc1/S-BASE/vm-3node-haproxy-3s3r-rc/.../summary.json`（前置驗證）|

如 3 VM 已被破壞或 TiDB cluster 不在，需先：
```
make deploy-vm3-tidb-haproxy-3s3r
make gate-vm3-tidb-haproxy-3s3r-rc
make prepare-vm3-tidb-haproxy-3s3r-rc
```
**但 baseline 不重跑**（沿用 commit 6f...4 的 canonical TS）。

## 4. 三層 hard gate 驗證點（本 smoke 主要產出）

### Layer 1 — artifact path
- output dir 必含 `/T-THRD/`
- `tests/common/run.sh` 入口 source guard.sh + `assert_threadcontrol_target $ROOT`
- 驗證：`echo $ROOT | grep -q /T-THRD/`

### Layer 2 — marker
- `.suite.done` JSON 含 `"phase": "phase-threadcontrol"` `"result_scope": "T-THRD"` `"baseline_eligible": false` `"tuning_profile_id": "tidb-readpool-a"`
- `summary.json` 同步含上述（schema metadata 部分，T108b 後續 commit 補；本 smoke 先驗 `.suite.done`）

### Layer 3 — Makefile fail-fast
- 驗證：誤用 baseline target + `TUNING_PROFILE=tidb-readpool-a` → guard 應 exit 1
- 驗證：phase-threadcontrol target + 缺 `TUNING_PROFILE` → exit 1
- 6 scope×scenario combo 已 codex v4 verified（無須 re-run）

### Layer 4 — README 主表 readback
- 跑完後 `results/verify-readme-gates.sh` P4f 應 PASS（artifact 雖在 T-THRD/ 但 README 未 reference）

## 5. 執行步驟

```bash
# === Stage 0: 前置驗證 ===
make status-vm3-tidb-haproxy-3s3r-rc                          # 確認 baseline state
test -f results/tidb-tc1/S-BASE/vm-3node-haproxy-3s3r-rc/tidb-vm-3node-haproxy-3s3r-rc-20260601T003316+0800/summary.json
tests/common/validate-phase-manifest.sh phase-threadcontrol/manifest.yaml

# === Stage 1: 採 before-config dump (read-only via TiKV status HTTP :20180) ===
TS=$(date '+%Y%m%dT%H%M%S%z')
PROFILE_ID="tidb-readpool-a"
OUT="results/tidb-tc1/T-THRD/tidb-vm-3node-haproxy-3s3r-rc-${PROFILE_ID}-${TS}"
mkdir -p "$OUT/db-config"

# Read-only HTTP config dump (per codex v6 blocking #6); verifies 2 keys × 3 nodes.
# `tikv-ctl modify-tikv-config -n KEY` is a modify interface and only peeks one key.
for ip in 172.24.40.32 172.24.40.33 172.24.40.34; do
  curl -sS "http://$ip:20180/config" > "$OUT/db-config/before-tikv-config-${ip##*.}.json"
  jq -r '.readpool.unified | {max_thread_count: ."max-thread-count", auto_adjust: ."auto-adjust-pool-size"}' \
    "$OUT/db-config/before-tikv-config-${ip##*.}.json" \
    > "$OUT/db-config/before-readpool-${ip##*.}.txt"
done

# === Stage 2: 套 tuning profile via ansible ===
# (待新增 phase-threadcontrol/playbooks/apply-tidb-readpool.yml)
ansible-playbook -i ansible/inventory/hosts.ini \
  phase-threadcontrol/playbooks/apply-tidb-readpool.yml \
  --extra-vars 'readpool_max_threads=8 auto_adjust=false'

# === Stage 3: 採 after-config dump (read-only via :20180, 同 Stage 1) ===
for ip in 172.24.40.32 172.24.40.33 172.24.40.34; do
  curl -sS "http://$ip:20180/config" > "$OUT/db-config/after-tikv-config-${ip##*.}.json"
  jq -r '.readpool.unified | {max_thread_count: ."max-thread-count", auto_adjust: ."auto-adjust-pool-size"}' \
    "$OUT/db-config/after-tikv-config-${ip##*.}.json" \
    > "$OUT/db-config/after-readpool-${ip##*.}.txt"
done

# 驗 2 key 都已調整 + 3 nodes 一致：
for ip in 32 33 34; do
  before=$(cat "$OUT/db-config/before-readpool-${ip}.txt")
  after=$(cat "$OUT/db-config/after-readpool-${ip}.txt")
  echo "[node .${ip}] before=$before  after=$after"
done
# expected: max_thread_count: before=4 after=8; auto_adjust: before=true after=false

# === Stage 4: 跑 v4.7 suite via phase-threadcontrol/run-threadcontrol-suite.sh ===
# Phase wrapper 是 codex v6 blocking #1 修正：在 suite 入口先 guard，避免 gate/prepare 階段
# 在 guard 之前已寫 artifact 到錯路徑。
ssh root@172.24.40.31 "env \
  TPCC_TS=${TS} \
  TUNING_PROFILE=${PROFILE_ID} \
  PHASE_NAME=phase-threadcontrol \
  RESULT_SCOPE=T-THRD \
  BASELINE_ELIGIBLE=false \
  CLUSTER_HOSTS='dbhost-1@172.24.40.32 dbhost-2@172.24.40.33 dbhost-3@172.24.40.34' \
  TPCC_ARTIFACTS=/tmp/poc-tpcc/artifacts/T-THRD \
  bash /tmp/poc-tpcc/scripts/run-threadcontrol-suite.sh \
    --db tidb --iso rc --topology vm-3node-haproxy-3s3r \
    --db-host 172.24.47.20 --ts ${TS}"

# === Stage 5: 等待 + fetch + verify ===
# 等 ~3h；status check via:
make status-vm3-tidb-haproxy-3s3r-rc
# fetch when .suite.done present：
rsync -av root@172.24.40.31:/tmp/poc-tpcc/artifacts/T-THRD/tidb-vm-3node-haproxy-3s3r-rc-${TS}/ "$OUT/"

# verify markers
jq '.phase, .result_scope, .baseline_eligible, .tuning_profile_id' "$OUT/.suite.done"
# expected: "phase-threadcontrol" "T-THRD" false "tidb-readpool-a"

# === Stage 6: revert tuning profile ===
ansible-playbook -i ansible/inventory/hosts.ini \
  phase-threadcontrol/playbooks/revert-tidb-readpool.yml
```

## 6. 成功條件 (acceptance criteria)

- [ ] artifact 落於 `results/tidb-tc1/T-THRD/...`（含 `/T-THRD/` segment）
- [ ] `.suite.done` JSON 含 `result_scope: T-THRD`、`baseline_eligible: false`、`tuning_profile_id: tidb-readpool-a`
- [ ] before / after config dump 不同（patch 確實 apply）
- [ ] `make run-vm1-tidb-rc TUNING_PROFILE=tidb-readpool-a` 應 **exit 1**（guard fail-fast 驗證；用 dry-run 模擬即可，不真跑）
- [ ] `bash results/verify-readme-gates.sh` 仍 6/6 PASS（artifact 未污染 README 主表）
- [ ] tpmC delta vs baseline 數字落地於本 doc 末尾「結果」段（≠0 即驗證 patch 生效；不論升 / 降）

## 7. Pending（執行前須補的 deliverable）

| # | 檔 | 內容 |
|---|---|---|
| 1 | `phase-threadcontrol/playbooks/apply-tidb-readpool.yml` | ansible playbook：set TiKV `readpool.unified.max-thread-count=8` + `readpool.unified.auto-adjust-pool-size=false`，via online config reload（無須 restart）|
| 2 | `phase-threadcontrol/playbooks/revert-tidb-readpool.yml` | revert above（restore default `max-thread-count=auto`, `auto-adjust-pool-size=true`）|
| 3 | **`phase-threadcontrol/run-threadcontrol-suite.sh`** | phase wrapper（codex v6 blocking #1）：在 suite 入口先 `source tests/common/lib/guard.sh; assert_threadcontrol_target "$ROOT"`，然後 delegate 到 `launch-vm1-suite.sh`。確保 gate / prepare 階段都已過 guard |
| 4 | **`tests/common/lib/common.sh::write_phase_done` patch** | 從 env auto-inject `phase` / `result_scope` / `baseline_eligible` / `tuning_profile_id` 至 `.<phase>.done` JSON（codex v6 blocking #2；backward-compat：未設 env 維持原行為）|

## 8. Rollback

| 失敗類型 | rollback action |
|---|---|
| tuning patch 失敗 | run revert playbook + 重啟 TiKV |
| run.sh guard reject | 確認 `$ROOT` 含 `/T-THRD/` + `$TUNING_PROFILE` 設定 |
| Suite 跑到一半中斷 | `make status` 確認 .suite.done 缺；rerun 或 manual cleanup |
| TiKV 因 readpool 設定錯誤無法啟動 | ssh + restore TiKV config from backup（before-config dump） |

## 9. 估時

| Stage | 時間 |
|---|---|
| Pending deliverable 補（2 playbook + 可選 write_phase_done patch）| ~1h |
| Stage 0-3（前置 + dump + patch）| ~10 min |
| Stage 4（v4.7 suite run）| ~3h（20min warmup + 4 × 25min thread sweep + collect）|
| Stage 5-6（fetch + verify + revert）| ~10 min |
| **合計** | **~4h 15min** |

## 變更歷史

| 日期 | commit | 變更 |
|---|---|---|
| 2026-06-06 | （本 commit）| 初版 smoke plan，Q1-Q6 拍板（cell=1 / topology=haproxy-3s3r / wrapper=thin / codex review enabled）|
| 2026-06-06 | （本 commit fixup）| codex v6 review changes-required 修正 6 blocking：命名統一 haproxy-3s3r / 改用 read-only :20180/config dump / 引入 phase wrapper / `write_phase_done` patch 規劃 / TUNING_PROFILE-aware acceptance criteria |
