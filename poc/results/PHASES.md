# Phase Registry — PoC IaC 環境隔離

> SSOT for phase scope mapping. 任何新 phase 必須先在此檔註冊。

## 0. 命名規範速查（canonical naming）

| 維度 | Canonical 形式 | 範例 | 規則 |
|---|---|---|---|
| **Logical scope** | UPPERCASE-HYPHEN | `S-BASE` `S-K8S` `T-THRD` `X-CROSS` | manifest `result_scope` 欄、env `RESULT_SCOPE`、JSON metadata 一律此寫法 |
| **Physical 主目錄**（sibling 結構） | 沿用邏輯名 UPPERCASE | `results/{db}-tc1/S-BASE/` `S-K8S/` `T-THRD/` | 三家各自 sibling，禁嵌套 |
| **Physical 跨家集中目錄**（X-CROSS only） | lowercase-hyphen | `results/x-cross/` | 跨家不依 `{db}-tc1/` 切；單一目錄 |
| **Phase family** | `phase-{family}` (lowercase-hyphen) | `phase-k8s` `phase-threadcontrol` `phase-crossregion` | 目錄名、env `PHASE_NAME`、manifest `phase` 欄一致 |
| **Makefile 內部步驟序次** | `phase{N}` (數字後綴) | `phase1` `phase2` ... `phase9` | 與 phase family 切開；只是 IaC 部署 step ordering，不是 phase 識別碼 |
| **Placement / Topology 標籤** | `P-{LETTER}` UPPERCASE | `P-A` `P-B` | manifest `placements`、目錄複合名、prose 一律「placement P-A」（不寫「topology P-A」）|
| **複合 run-id 命名** | `{db}-{infra}-{N}node-{topo}-{iso}-{ts}` | `tidb-vm-6node-P-A-rc-20260622T131459+0800` | 順序固定；分隔符一律 `-`；timestamp 一律 ISO 8601 + 時區 |
| **manifest 雙欄位寫法** | `result_scope` (logical) + `artifact_prefix` (physical) | `result_scope: X-CROSS` / `artifact_prefix: results/x-cross/` | 邏輯與物理切開；不用單欄混寫 |

> 速查表為 enforcement-spec：driver script、ansible playbook、Makefile target、文件 prose 均依此規則。違反規則由 `tests/common/validate-phase-manifest.sh` + `tests/common/lib/guard.sh` 攔下。

## 1. Scope 對照表

| result_scope | phase | baseline_family | comparison_scope | baseline_eligible | input source |
|---|---|---|---|:---:|---|
| `S-BASE` | （無對應 phase；既有 vm-1node / vm-3node baseline） | `vm` | `vm-only` | ✓ | [`PoC-DESIGN.md`](./PoC-DESIGN.md) §1–§12 |
| `S-K8S` | [`phase-k8s`](../phase-k8s/) | `k8s` | `k8s-only` | ✓（K8s 內部）；**不可混入 S-BASE VM baseline** | [`phase-k8s/manifest.yaml`](../phase-k8s/manifest.yaml) |
| `T-THRD` | [`phase-threadcontrol`](../phase-threadcontrol/) | `tuning` | `tuning-only` | ✗ | [`phase-threadcontrol/manifest.yaml`](../phase-threadcontrol/manifest.yaml) |
| `X-CROSS` | [`phase-crossregion`](../phase-crossregion/) | `crossregion` | `crossregion-only` | ✗ | [`phase-crossregion/manifest.yaml`](../phase-crossregion/manifest.yaml) |

### 1.1 sibling 結構

```
results/{db}-tc1/
├── S-BASE/      ← 既有 vm baseline（不可被新 phase 嵌入）
├── S-K8S/       ← phase-k8s
└── T-THRD/      ← phase-threadcontrol

results/x-cross/ ← phase-crossregion 本機彙整目錄（result_scope 仍為 X-CROSS）
```

`S-K8S` / `T-THRD` 必為 `S-BASE` 的 sibling；`phase-crossregion` 改採集中式 `results/x-cross/`。三者皆嚴禁嵌入 `S-BASE/` 下。

## 2. baseline_eligible 與 baseline_family 規則

- **baseline_eligible: true** 表示該 scope 的 summary.json 可供「baseline_family 內部」對標主表引用。
- **baseline_family** 限制跨 family 對標：
  - `vm` (S-BASE) 與 `k8s` (S-K8S) 不可互相直引；任何 README 主表跨 family 對比須明標 family。
  - `tuning` (T-THRD) 與 `crossregion` (X-CROSS) 為 `baseline_eligible: false`，永不入主表。
- **forbidden 規則**（落地於 `verify-readme-gates.sh` + `tests/common/lib/guard.sh`）：
  - `results/README.md` 主表 source list 禁讀 `T-THRD/*`、`x-cross/*` 與 logical scope `X-CROSS/*`
  - `S-K8S/*` 僅可入 README 「K8s 對照」章節，不入 VM 主表
  - 任何 baseline target (`vm1-*` / `vm3-*` / `phase-k8s-*`) 偵測 `TUNING_PROFILE` env 直接 exit 1
  - `phase-threadcontrol-*` target 偵測 output path 屬 `S-BASE` / `S-K8S` / `X-CROSS` / `x-cross` 直接 exit 1

## 3. manifest schema（每 phase 一份 `manifest.yaml`）

```yaml
phase: phase-k8s | phase-threadcontrol | phase-crossregion
phase_version: 1
result_scope: S-K8S | T-THRD | X-CROSS
baseline_family: k8s | tuning | crossregion
comparison_scope: k8s-only | tuning-only | crossregion-only
allowed_result_scopes: [<list>]      # 該 phase target 允許輸出的 scope
forbidden_result_scopes: [<list>]    # 該 phase target 禁止輸出的 scope
allowed_topology: [<list>]           # 例如 [k8s-3node-limit, k8s-3node-unlimit]
isolation: [rc]                      # phase 允許的 iso；K8s/crossregion 限 rc
warehouses: 128
warmup_sec: 1200
warmup_threads: 64
threads_list: [16, 32, 64, 128]
rounds: 5
requires_n: 1                        # exploratory N=1；正式 baseline N=3
metrics_hosts:
  source: topology-derived | inventory | explicit
  kind: vm | k8s-node | k8s-pod | crossregion-vm
  ids: [<logical id list>]           # 例如 [dbhost-1, dbhost-2, dbhost-3]
artifact_prefix: results/{db}-tc1/{result_scope}/   # phase-crossregion 例外使用 results/x-cross/
baseline_eligible: true | false
tuning_profile_id: <id or "default"> # phase-threadcontrol 必填；其他 phase 寫 default
owner_doc: <path to authoritative source doc>
```

驗證：[`tests/common/validate-phase-manifest.sh`](../tests/common/validate-phase-manifest.sh)（落地於 T108a fixture）。

## 4. metrics/hosts.json schema

每次 fan-out 開跑前在 `<round-dir>/metrics/hosts.json` 落地：

```json
{
  "phase": "phase-k8s",
  "result_scope": "S-K8S",
  "manifest_sha256": "<hash of manifest.yaml>",
  "hosts": [
    {
      "id": "k8s-node-1",
      "kind": "k8s-node",
      "region": "idc",
      "zone": "vlan241",
      "node": "l-test-poc-1",
      "pod": null,
      "ssh_host": "172.24.40.32",
      "artifact_suffix": "k8s-node-1"
    }
  ]
}
```

artifact 命名以 `artifact_suffix` 為準，禁用 IP 短碼（pod IP 動態、跨區 IP 碰撞）。

## 5. summary.json schema 與 metadata

實際 schema 以 [`tests/common/summary-from-stdout.py`](../tests/common/summary-from-stdout.py) **產出** 為準（v1 為主要 SSOT；本檔僅列 per-phase metadata 附加欄位）：

```json
{
  "schema_version": 1,
  "phase": "phase-k8s",
  "result_scope": "S-K8S",
  "baseline_family": "k8s",
  "baseline_eligible": true,
  "tuning_profile_id": "default",
  "manifest_sha256": "<sha256 of manifest.yaml>",
  "thread_results": {
    "<N>": {
      "tpmC_mean": <5-round mean across R1-R5>,
      "tpmC_per_round": [r1, r2, r3, r4, r5],
      "tpmC_range_mean_pct": <(max-min)/mean * 100>,
      "NEW_ORDER": {"p50_mean_ms": ..., "p95_mean_ms": ..., "p99_mean_ms": ..., "total_count": ..., "error_count": ..., "error_rate_pct": ...},
      "all_txn":   {"total_count": ..., "error_count": ..., "error_rate_pct": ...}
    }
  }
}
```

下游 parser 對未識別欄位採 forward-compatible 忽略；既有 `S-BASE` summary.json 不需 retrofit。

> **取數口徑**：`tpmC_mean` 為 **5-round mean across R1-R5**（與 code 實際輸出一致；歷史 PoC-DESIGN §8.3「median drop round 1」為設計初衷，未落地）。引用 summary.json 為主表來源時，需取 `thread_results.<N>.tpmC_mean` 與 `NEW_ORDER.p99_mean_ms` 配對；不要混用 design-intent 寫法。

## 6. 變更歷史

| 日期 | 變更 | 來源 |
|---|---|---|
| 2026-06-26 | 新增 §0 命名規範速查；§5 schema 對齊 code 實際輸出（`tpmC_mean = R1-R5 mean`，澄清「median drop R1」未落地） | SSOT 收斂 sub-agent audit |
| 2026-06-06 | 初版 registry 建立 | codex review v2 approve-with-constraints（session `019e38f2`）|
