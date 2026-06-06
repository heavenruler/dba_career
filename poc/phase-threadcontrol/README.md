# phase-threadcontrol — process / thread / admission tuning isolation

## 目的

隔離 process / thread / admission control 參數實驗，**避免混入 baseline**。

`baseline_family: tuning` → `baseline_eligible: false` → **任何輸出不可入 README 主表或 pipeline-log canonical row**。

## 必要條件（取自 manifest.yaml）

| 欄位 | 值 |
|---|---|
| result_scope | `T-THRD` |
| baseline_family | `tuning` |
| baseline_eligible | `false` |
| allowed_result_scopes | `[T-THRD]`（不得輸出至 S-BASE / S-K8S / X-CROSS）|
| isolation | rc / rr / strict（視 tuning experiment 而定）|
| tuning_profile_id | **REQUIRED**（每跑必填，如 `tidb-readpool-a`）|
| artifact_prefix | `results/{db}-tc1/T-THRD/` |

詳 [`manifest.yaml`](./manifest.yaml) + [`../results/PHASES.md`](../results/PHASES.md)。

## 三層 hard gate（codex v2 constraint #5 落地）

防止 tuning 數據污染 baseline 的 hard gate，分三層：

### Layer 1 — artifact path

artifact dir 必須含 `T-THRD`，例如：
- ✓ `results/tidb-tc1/T-THRD/tidb-vm-1node-rc-tuning-readpool-a-20260606T...+0800/`
- ✗ `results/tidb-tc1/S-BASE/...`（baseline 路徑）
- ✗ `results/tidb-tc1/S-K8S/...`（K8s baseline 路徑）

由 `tests/common/lib/guard.sh` 在 `flock_phase` / `write_phase_done` 時驗證。

### Layer 2 — marker

`.suite.done` / `.run.done` 等 JSON marker 必須含：

```json
{
  "phase": "phase-threadcontrol",
  "result_scope": "T-THRD",
  "baseline_eligible": false,
  "tuning_profile_id": "tidb-readpool-a"
}
```

`summary.json` top-level 同步含上述四欄。

### Layer 3 — Makefile fail-fast

`tests/common/lib/guard.sh` 提供 `assert_baseline_target` 與 `assert_threadcontrol_target`：

- **baseline target** (`vm1-*` / `vm3-*` / `phase-k8s-*` / `phase-crossregion-*`)：若偵測到 `TUNING_PROFILE` 環境變數設定 → `exit 1`
- **threadcontrol target** (`phase-threadcontrol-*`)：若 output path 解析後屬於 `S-BASE` / `S-K8S` / `X-CROSS` → `exit 1`

外加 [`results/verify-readme-gates.sh`](../results/verify-readme-gates.sh) **新增 P4f gate**：`rg` 檢查 `results/README.md` 主表 source list 不允許 `T-THRD/` 字串（落地於 T107 docs sync）。

詳 [`guardrails.md`](./guardrails.md)。

## 路徑追溯

| 元件 | 位置 |
|---|---|
| 三家 process/thread 參數盤點（SSOT，不複製）| [`1_MeetingMinutes/0605.md`](../1_MeetingMinutes/0605.md) §3 (TiDB) / §4 (YBDB) / §5 (CRDB) |
| 4 議題 decision agenda（CPU ~80% 調參目的 / config dump checklist / cross-DB caveat / tuning vs baseline 分離）| [`1_MeetingMinutes/0602-agenda.md`](../1_MeetingMinutes/0602-agenda.md) §6 |
| guardrail 細部 | [`guardrails.md`](./guardrails.md) |
| 三家 tuning vars 範本 | [`vars/`](./vars/) |

## tuning_profile_id 規範

每次 phase-threadcontrol run 必須指定 `tuning_profile_id`（不可用 `default`）。命名格式：

```
<db>-<knob-category>-<variant>
```

範例：

| profile_id | 對象 | knob |
|---|---|---|
| `tidb-readpool-a` | TiDB | `readpool.unified.max-thread-count` |
| `tidb-grpc-a` | TiDB | `server.grpc-concurrency` |
| `tidb-executor-a` | TiDB | `tidb_executor_concurrency` |
| `ybdb-rpc-a` | YBDB | `--rpc_workers_limit` |
| `ybdb-reactor-a` | YBDB | `--num_reactor_threads` |
| `ybdb-tabletq-a` | YBDB | `--tablet_server_svc_queue_length` |
| `crdb-admission-a` | CRDB | `admission.kv.enabled` + `admission.sql_kv_response.enabled` |
| `crdb-cache-a` | CRDB | `--cache` / `--max-sql-memory` |

對應 vars 範本：[`vars/{tidb,ybdb,crdb}-tuning-template.yml`](./vars/)。

## Make target

```
make phase-threadcontrol-plan      # read-only echo manifest + 4 議題 doc ref
make phase-threadcontrol-verify    # validate manifest + 三層 hard gate spec
```

實際跑 benchmark **暫不在本輪 scope**；待 0605.md §6 4 議題拍板後再啟。

## 變更歷史

| 日期 | commit | 變更 |
|---|---|---|
| 2026-06-06 | （本 commit）| 初版：README + manifest（via T108a）+ guardrails + 三家 vars 範本 + Make target |
