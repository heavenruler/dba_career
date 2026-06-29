# X-CROSS Pipeline Log — phase-crossregion

> 本檔是 `phase-crossregion` 的跨區域流程紀錄索引。  
> 目前 X-CROSS 數據用於 framework / determinism 驗證，不作為正式 W=128 跨家效能排名。

---

## 0. 目錄歸屬

| 目錄 | 角色 | 判讀方式 |
|---|---|---|
| `results/x-cross/preflight/time-sync/` | time server / chrony 同步檢查 | 只作跨區時間同步與前置檢查佐證，不作為 benchmark 結果目錄 |
| `results/x-cross/dry-run/` | dry-run framework probe | 驗證 wrapper / gate / binary / endpoint；不含正式 go-tpc run |
| `results/x-cross/smoke/early-runs/` | 早期 smoke / partial run | 可用來追溯建置與路徑修正，不作正式 benchmark 結論 |
| `results/x-cross/determinism/` | same-cluster determinism 驗證 | 目前唯一可引用的 W=4 重現性觀察來源；仍非 W=128 baseline |

本檔引用的 tpmC 直接來自各 round 的 `go-tpc-stdout.txt`；同步以 `tests/common/summary-from-stdout.py` 對 `determinism/run1` 與 `run2` 三家 suite-dir 補產 `summary.json`（W=4；YBDB 採 `--skip-rounds 2` 跳過 R1/R2 暖機異常）。

---

## 1. TL;DR

- 2026-06-19 已完成三家資料庫真六節點跨區 smoke，證明 IDC + GCP 路徑可跑通。
- 2026-06-21 的 W=4 redeploy run-to-run 變異過大，不可作正式結果。
- 2026-06-22/23 改成 same-cluster N-round 後，三家重現性收斂到 CV <= 5%。
- 目前 workload 是 W=4、threads=16、每 round 5 分鐘；不同於 S-BASE / S-K8S 的 W=128 正式口徑。
- 正式 X-CROSS baseline 仍需 W=128、20 分鐘 warmup、**canonical primary = `tpmC_mean = R1-R5 mean` per PHASES.md §5 + `summary-from-stdout.py`**（與 S-BASE / S-K8S 一致）；R2-R5 median / CV 只作為 secondary / sensitivity analysis，不取代 primary。完整 DB-host metrics 與 `summary.json` 必齊。

---

## 2. 已採用資料點

### 2.1 Same-cluster determinism run

| 資料庫 | 採用來源 | R1 | R2 | R3 | R4 | R5 | 採用平均 | CV | 備註 |
|---|---|---:|---:|---:|---:|---:|---:|---:|---|
| TiDB | [`run1-20260622T131459`](./determinism/run1-20260622T131459+0800/tidb-vm-6node-P-A-rc-run1-20260622T131459+0800/) | 9,525.5 | 9,553.2 | 9,786.9 | 9,393.2 | 9,530.8 | 9,557.9 | 1.5% | 5 rounds 全採 |
| CockroachDB | [`run1-20260622T131459`](./determinism/run1-20260622T131459+0800/crdb-vm-6node-P-A-rc-run1-20260622T131459+0800/) | 8,409.5 | 8,055.3 | 7,902.5 | 7,720.9 | 7,472.3 | 7,912.1 | 4.5% | 5 rounds 全採 |
| YugabyteDB | [`run2-20260622T231927`](./determinism/run2-20260622T231927+0800/ybdb-vm-6node-P-A-rc-run2-20260622T231927+0800/) | 102.0 | 226.9 | 6,424.2 | 6,259.3 | 6,206.2 | 6,296.6 | 1.8% | 只採 R3-R5；R1/R2 為暖機異常 |

取數來源：

- TiDB / CockroachDB：`results/x-cross/determinism/run1-20260622T131459+0800/*/runs/threads-16/round-*/go-tpc-stdout.txt`
- YugabyteDB：`results/x-cross/determinism/run2-20260622T231927+0800/ybdb-vm-6node-P-A-rc-run2-20260622T231927+0800/runs/threads-16/round-*/go-tpc-stdout.txt`

### 2.2 2026-06-19 true six-node smoke

| 資料庫 | tpmC | tpmTotal | 驗證到的事項 | 來源 |
|---|---:|---:|---|---|
| TiDB | 11,112.9 | 24,967.1 | 真六節點、P-A leader-pinned IDC 可執行 | [`SESSION-2026-06-19-3db-smoke.md`](../../phase-crossregion/SESSION-2026-06-19-3db-smoke.md) |
| CockroachDB | 2,145.2 | 4,896.0 | 真六節點、region locality 正確 | [`SESSION-2026-06-19-3db-smoke.md`](../../phase-crossregion/SESSION-2026-06-19-3db-smoke.md) |
| YugabyteDB | 6,812.2 | 15,129.2 | 真六節點、leader-pin IDC、catalog wait 後可執行 | [`SESSION-2026-06-19-3db-smoke.md`](../../phase-crossregion/SESSION-2026-06-19-3db-smoke.md) |

此段只能證明跨區 framework 已跑通；不可與 S-BASE / S-K8S 的 W=128 結果直接比較。

---

## 3. 不採用為正式結果的資料

| 類型 | 位置 | 原因 |
|---|---|---|
| 2026-06-21 redeploy run-to-run | [`SESSION-2026-06-21-determinism.md`](../../phase-crossregion/SESSION-2026-06-21-determinism.md) | W=4 且每輪 redeploy；TiDB 1,552.2 -> 9,719.2，CockroachDB 3,929.6 -> 2,365.6，YugabyteDB 41.8 -> 23.0，變異不可作正式 benchmark |
| YugabyteDB `run1-20260622T131459` | `results/x-cross/determinism/run1-20260622T131459+0800/ybdb-vm-6node-P-A-rc-run1-*` | round 1 僅 10.1 tpmC，round 2 缺 tpmC 行；改採 run2 的 R3-R5 |
| `results/x-cross/preflight/time-sync/` | `results/x-cross/preflight/time-sync/chrony-gate-*` | 只包含 chrony / gate 檢查；不是 go-tpc suite 結果 |
| `run2` 內 TiDB / CockroachDB 複製目錄 | `results/x-cross/determinism/run2-20260622T231927+0800/{tidb,crdb}-vm-6node-P-A-rc-run1-*` | 目錄名仍為 run1，視為 run1 artifact copy，不視為新的 run2 採樣 |

---

## 4. 判讀限制

- workload：W=4、threads=16、5 分鐘 round；不是正式 W=128 workload。
- 目前沒有 `summary.json`，error rate / latency 統計尚未統一納入。
- DB-host metrics 與 WAN inline metrics 尚未形成可直接引用的飽和分析。
- X-CROSS 在 phase registry 中屬 `baseline_eligible=false`，目前只作 cross-region framework / determinism 證據。
- 若要進入正式跨家排序，必須重跑 W=128 same-cluster suite，並統一 warmup、round 選取、summary 與 metrics。

---

## 5. 下一步

1. X-CROSS artifact layout 已收斂為 `preflight/time-sync`、`dry-run`、`smoke/early-runs`、`determinism` 四類。
2. 為 X-CROSS 補 `summary.json` 產生流程，避免後續只靠 raw stdout 手動讀數。
3. 正式 W=128 測試需固定：same cluster、不 redeploy、placement gate、scheduler / balancer freeze、20 分鐘 warmup；primary estimator = R1-R5 mean（per PHASES §5 / `summary-from-stdout.py`），secondary = R2-R5 median + CV（sensitivity only，不入主表）。
4. 將 chrony gate / WAN preflight 只作為 X-CROSS 附屬證據，不與 benchmark 結果混放。

---

## 6. 參考

- [`phase-crossregion/SESSION-2026-06-19-3db-smoke.md`](../../phase-crossregion/SESSION-2026-06-19-3db-smoke.md)
- [`phase-crossregion/SESSION-2026-06-21-determinism.md`](../../phase-crossregion/SESSION-2026-06-21-determinism.md)
- [`phase-crossregion/SESSION-2026-06-22-determinism-v2.md`](../../phase-crossregion/SESSION-2026-06-22-determinism-v2.md)
- [`1_MeetingMinutes/0616-slide-draft.md`](../../1_MeetingMinutes/0616-slide-draft.md)
- [`results/PHASES.md`](../PHASES.md)

---

## 7. 變更紀錄

| 日期 | 內容 |
|---|---|
| 2026-06-26 | retrofit `summary.json` 至 determinism 三家 suite-dir（W=4；YBDB skip R1/R2）；同步 patch `summary-from-stdout.py` 支援 `--warehouses` / `--skip-rounds` 與 `-run<N>` suffix |
| 2026-06-24 | 依用途重整目錄：time-sync、dry-run、early smoke、determinism 分層 |
| 2026-06-24 | 目錄由 `results/X-CROSS/` 改為 `results/x-cross/`；前期 `results/x-cross-tc1/` 內容彙整至 `results/x-cross/preflight/` |
| 2026-06-23 | 建立 X-CROSS pipeline-log，確認 `results/x-cross/` 為 phase-crossregion 主資料目錄，`results/x-cross/preflight/` 為 chrony / preflight 證據目錄 |
