# phase-threadcontrol — Three-layer Hard Gate Spec

> codex v2 constraint #5：phase-threadcontrol 必須 path / marker / Makefile **三層 hard gate**；不可只靠文件標註。

本檔為 SSOT；任何違反規則的 PR 應被 review 阻擋。

## Layer 1 — artifact path

### 規則

任何 phase-threadcontrol 產出的 artifact dir 必須符合：

```
results/{db}-tc1/T-THRD/<run-name>-<TS>/
```

### 驗證

- `tests/common/lib/guard.sh::assert_threadcontrol_path` — 在 `flock_phase` 開頭驗證 `$ROOT` 含 `/T-THRD/`；fail → exit 1
- `tests/common/lib/guard.sh::assert_baseline_path` — 在 baseline target (`vm1-*` / `vm3-*` / `phase-k8s-*` / `phase-crossregion-*`) 驗證 `$ROOT` **不**含 `/T-THRD/`

### 違反範例（必擋）

```
results/tidb-tc1/S-BASE/tidb-vm-1node-rc-tuning-readpool-a-...   ✗ T-THRD 應在路徑中
results/tidb-tc1/T-THRD/...                                       ✓
```

## Layer 2 — marker

### 規則

`.suite.done`、`.run.done`、`.collect.done`、`.gate.done`、`.prepare.done` 5 markers 與 `summary.json` 必含：

```json
{
  "phase": "phase-threadcontrol",
  "result_scope": "T-THRD",
  "baseline_eligible": false,
  "tuning_profile_id": "<required, 非 default>",
  "manifest_sha256": "<sha256 of phase-threadcontrol/manifest.yaml>"
}
```

### 驗證

- `tests/common/lib/common.sh::write_phase_done` 在寫入時自動補上述四欄（需 T108a 後續擴充）
- `tests/common/validate-phase-manifest.sh` 驗證 manifest.yaml schema
- pipeline-log review 時：reviewer 必查 summary.json `baseline_eligible: false`

### 違反範例（必擋）

```json
{"phase": "phase-threadcontrol", "result_scope": "S-BASE"}      ✗ 矛盾
{"baseline_eligible": true, "result_scope": "T-THRD"}            ✗ T-THRD 必為 false
{"tuning_profile_id": "default", "result_scope": "T-THRD"}       ✗ 必填具體 profile
```

## Layer 3 — Makefile fail-fast

### 規則

`tests/common/lib/guard.sh` 在 Makefile target 起始時驗證 env / output path 對齊：

#### baseline target (vm1-* / vm3-* / phase-k8s-* / phase-crossregion-*)

```bash
[[ -z "${TUNING_PROFILE:-}" ]] || die "TUNING_PROFILE set on baseline target — refusing to run"
[[ "$OUTPUT_PATH" != */T-THRD/* ]] || die "baseline target output path contains /T-THRD/ — wrong scope"
```

#### phase-threadcontrol-* target

```bash
[[ "$OUTPUT_PATH" == */T-THRD/* ]] || die "phase-threadcontrol output path missing /T-THRD/"
[[ -n "${TUNING_PROFILE:-}" && "$TUNING_PROFILE" != "default" ]] \
  || die "TUNING_PROFILE must be set to a non-default value (e.g. tidb-readpool-a)"
```

### 實作位置

- `tests/common/lib/guard.sh` — 提供 4 個 assert helper（commit `06fe573`，10/10 self-test pass）
- `tests/common/run.sh` 入口處 source guard.sh 並依 `$ROOT` 自動 dispatch（commit `0b59897`）：
  ```bash
  case "$ROOT" in
    */T-THRD/*)  assert_threadcontrol_target "$ROOT" ;;
    */S-K8S/*)   assert_phase_k8s_target "$ROOT" ;;
    */X-CROSS/*) assert_phase_crossregion_target "$ROOT" ;;
    *)           assert_baseline_target "$ROOT" ;;   # vm-1node / vm-3node baseline
  esac
  ```
  → baseline target 偵測 `TUNING_PROFILE` 或 `/T-THRD/` path → exit 1
  → threadcontrol target 偵測 path 不含 `/T-THRD/` 或 TUNING_PROFILE 缺/為 default → exit 1
  → 6 scope×scenario combo 全 pass (codex review v4 verified)

## Layer 4（衍生） — README / pipeline-log 主表讀取防護

### 規則

`results/README.md` 主表的 source list、`results/{db}-tc1/S-BASE/pipeline-log.md` 的 cross-link，**禁讀** `T-THRD/`：

### 驗證

`results/verify-readme-gates.sh` 新增 sub-phase **P4f**（待 T107 docs sync 時加入）：

```bash
# P4f: phase-threadcontrol main-table contamination check
rg -n 'T-THRD' results/README.md results/{tidb,crdb,yuga}-tc1/S-BASE/pipeline-log.md
# Expected: 0 hits in source-list / canonical-row context.
# Allowed: only in §「Phase Registry」/「Forbidden 章節」 reference context.
```

## 緊急覆寫

僅在 incident response 場景允許覆寫，且必須：

1. 在 `manifest.yaml` 加 `override_reason: <description>` + `override_approver: <name>`
2. 提 PR 同時包含 PoC-DESIGN.md changelog entry
3. 提 PR description 引用 0602-agenda.md §6 議題 4「tuning vs baseline 分離」決議

無此三項 → CI 拒收。

## 變更歷史

| 日期 | 變更 | source |
|---|---|---|
| 2026-06-06 | 初版四層 guardrail 規範 | codex v2 review constraint #5 + 0605.md / 0602-agenda.md §6 |
