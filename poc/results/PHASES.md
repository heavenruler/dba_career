# Phase Registry — PoC IaC 環境隔離

> SSOT for phase scope mapping. 任何新 phase 必須先在此檔註冊。

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
├── T-THRD/      ← phase-threadcontrol
└── X-CROSS/     ← phase-crossregion
```

`S-K8S` / `T-THRD` / `X-CROSS` 必為 `S-BASE` 的 sibling；嚴禁嵌入 `S-BASE/` 下。

## 2. baseline_eligible 與 baseline_family 規則

- **baseline_eligible: true** 表示該 scope 的 summary.json 可供「baseline_family 內部」對標主表引用。
- **baseline_family** 限制跨 family 對標：
  - `vm` (S-BASE) 與 `k8s` (S-K8S) 不可互相直引；任何 README 主表跨 family 對比須明標 family。
  - `tuning` (T-THRD) 與 `crossregion` (X-CROSS) 為 `baseline_eligible: false`，永不入主表。
- **forbidden 規則**（落地於 `verify-readme-gates.sh` + `tests/common/lib/guard.sh`）：
  - `results/README.md` 主表 source list 禁讀 `T-THRD/*` 與 `X-CROSS/*`
  - `S-K8S/*` 僅可入 README 「K8s 對照」章節，不入 VM 主表
  - 任何 baseline target (`vm1-*` / `vm3-*` / `phase-k8s-*`) 偵測 `TUNING_PROFILE` env 直接 exit 1
  - `phase-threadcontrol-*` target 偵測 output path 屬 `S-BASE` / `S-K8S` / `X-CROSS` 直接 exit 1

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
artifact_prefix: results/{db}-tc1/{result_scope}/
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

## 5. summary.json 附加 metadata（不破壞 v1 schema）

per-phase 跑出的 `summary.json` 在 top-level 加：

```json
{
  "schema_version": 1,
  "phase": "phase-k8s",
  "result_scope": "S-K8S",
  "baseline_family": "k8s",
  "baseline_eligible": true,
  "tuning_profile_id": "default",
  "manifest_sha256": "<sha256 of manifest.yaml>",
  "thread_results": { ... }
}
```

下游 parser 對未識別欄位採 forward-compatible 忽略；既有 `S-BASE` summary.json 不需 retrofit。

## 6. 變更歷史

| 日期 | 變更 | 來源 |
|---|---|---|
| 2026-06-06 | 初版 registry 建立 | codex review v2 approve-with-constraints（session `019e38f2`）|
