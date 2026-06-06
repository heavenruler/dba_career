# phase-k8s — Kubernetes 對照組（v4.7 detached suite，RC only）

## 目的

重跑 Kubernetes 對照組為 K8s baseline，與 vm-1node / vm-3node baseline（S-BASE）**家族隔離**對照。

`baseline_family: k8s` → 與 S-BASE 不可直引；跨家對比須於 README 明標 `baseline_family`。

## 必要條件（取自 manifest.yaml）

| 欄位 | 值 |
|---|---|
| result_scope | `S-K8S` |
| baseline_family | `k8s` |
| baseline_eligible | `true`（K8s family 內）|
| isolation | `rc` only（不跑 RR / strict）|
| allowed_topology | `k8s-3node-limit`, `k8s-3node-unlimit` |
| warmup | 20 min @ 64 threads（必 v4.7）|
| threads | 16 / 32 / 64 / 128 |
| rounds | 5 × 5 min |
| metrics_hosts | `k8s-node-1/2/3`（SSH 至 k3s-server + 2 agents 採 OS metrics；不採 pod-level）|
| artifact_prefix | `results/{db}-tc1/S-K8S/` |

詳 [`manifest.yaml`](./manifest.yaml) + [`../results/PHASES.md`](../results/PHASES.md)。

## 路徑追溯

| 元件 | 位置 |
|---|---|
| K8s deploy playbook | [`ansible/playbooks/tidb-k8s.yml`](../ansible/playbooks/tidb-k8s.yml) / [`cockroach-k8s.yml`](../ansible/playbooks/cockroach-k8s.yml) / [`yugabyte-k8s.yml`](../ansible/playbooks/yugabyte-k8s.yml) |
| K8s deploy vars | [`ansible/vars/tidb-k8s-3node-{limit,unlimit}.yml`](../ansible/vars/) / `cockroach-k8s-3node-*.yml` / `yuga-k8s-3node-*.yml` |
| K8s status check | [`ansible/playbooks/{tidb,cockroach,yugabyte}-k8s-status.yml`](../ansible/playbooks/) |
| pre-v4.7 K8s 測試（不可引用）| [`tests/run-all/{tidb,crdb,yuga}-k8s-3node-{limit,unlimit}.sh`](../tests/run-all/) — `WARMUP=5m DURATION=10m SCENARIO=S-BASE`，**不符 v4.7**，僅作 history reference |
| v4.7 detached suite（VM 已有，K8s 需 wrap）| [`tests/common/run.sh`](../tests/common/run.sh)（T108b 後支援 `CLUSTER_HOSTS` fan-out）|

## 與 pre-v4.7 K8s 數據的關係

`tests/run-all/*-k8s-3node-*.sh`（`tests/prepare/*-k8s-3node-*.sh`）為 **pre-v4.7 legacy**：

- WARMUP 5 min（v4.7 要 20 min）
- DURATION 10 min（v4.7 為 5 round × 5 min = 25 min 結構不同）
- SCENARIO 寫死 `S-BASE`（應為 `S-K8S`）
- 無 `.suite.done` / `.gate.done` / `.run.done` marker
- 無 fan-out metrics（SSH 至 k3s-server only）

→ **本 phase 任何 output 不可由這些舊腳本直接產生**；v4.7 K8s wrapper 為待補項（詳 §「Pending v4.7 K8s wrapper」）。

## Pending v4.7 K8s wrapper

T104 commit 含基本 orchestration（Make target + README + manifest），但 K8s 完整 v4.7 detached suite **wrapper 尚未實作**：

| 缺項 | 說明 |
|---|---|
| `phase-k8s/run-k8s-suite.sh` | 包 `tests/common/run.sh` + 設 `CLUSTER_HOSTS=k8s-node-1@172.24.40.32 k8s-node-2@172.24.40.33 k8s-node-3@172.24.40.34` + 設 `PHASE_NAME=phase-k8s` `RESULT_SCOPE=S-K8S` `MANIFEST_SHA=$(sha256 manifest.yaml)` + 確保 `WARMUP_SEC=1200` 等 |
| K8s gate（取代 `gate-os.sh`）| K8s 環境 OS gate 需考慮 pod scheduling + 確認 pod ready 後再 prepare |
| K8s prepare（取代 `prepare.sh`）| go-tpc prepare 連 `:30004`/`:30005`/`:30007` NodePort 入口 |
| K8s collect | `kubectl logs` + ansible status playbook output 各 DB 一份 |

→ 補完前 `make phase-k8s-run` 為 **「未實作」echo target**（exit 1 + 提示文字）。

## Make target

```
make phase-k8s-plan       # echo 本 phase scope / topology / 缺項；安全
make phase-k8s-deploy     # 三家 ansible-playbook *-k8s.yml（current 既有路徑）
make phase-k8s-run        # 待補；目前 echo "TODO: v4.7 K8s wrapper not yet implemented" + exit 1
```

## 變更歷史

| 日期 | commit | 變更 |
|---|---|---|
| 2026-06-06 | （本 commit）| 初版：README + manifest（via T108a）+ 補缺漏 `tests/prepare/yuga-k8s-3node-limit.sh` stub + Make target 框架 |
