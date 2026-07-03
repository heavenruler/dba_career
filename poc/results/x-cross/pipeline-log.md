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
| `results/x-cross/determinism/` | same-cluster determinism 驗證 | W=4 重現性觀察來源；非 W=128 baseline |
| `results/x-cross/baseline/w128/` | W=128 正式口徑 suite（same-cluster、20min warmup、freeze）| X-CROSS 內可引用的主數據；跨家排名仍受 `baseline_eligible=false` 限制 |
| `results/x-cross/compare/` | 對照性 suite（如 W=1 contention 探索）| 只作機制對照，不入任何排名 |

本檔引用的 tpmC 直接來自各 round 的 `go-tpc-stdout.txt`；同步以 `tests/common/summary-from-stdout.py` 對 `determinism/run1` 與 `run2` 三家 suite-dir 補產 `summary.json`（W=4；YBDB 採 `--skip-rounds 2` 跳過 R1/R2 暖機異常）。

---

## 1. TL;DR

- 2026-06-19 已完成三家資料庫真六節點跨區 smoke，證明 IDC + GCP 路徑可跑通。
- 2026-06-21 的 W=4 redeploy run-to-run 變異過大，不可作正式結果。
- 2026-06-22/23 改成 same-cluster N-round 後，三家重現性收斂到 CV <= 5%。
- 目前 workload 是 W=4、threads=16、每 round 5 分鐘；不同於 S-BASE / S-K8S 的 W=128 正式口徑。
- 正式 X-CROSS baseline 仍需 W=128、20 分鐘 warmup、**canonical primary = `tpmC_mean = R1-R5 mean` per PHASES.md §5 + `summary-from-stdout.py`**（與 S-BASE / S-K8S 一致）；R2-R5 median / CV 只作為 secondary / sensitivity analysis，不取代 primary。完整 DB-host metrics 與 `summary.json` 必齊。
- **2026-07-03：TiDB × P-A × A-S 首個正式口徑 W=128 cell 完成**（§2.3）：t128 tpmC 16,808.6、CV 2.4%、error 0%；GCP per-round metrics 300/300 齊全。取代 07-02 網路採樣缺失輪。

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
| TiDB | 11,112.9 | 24,967.1 | 真六節點、P-A leader-pinned IDC 可執行 | [`SESSION-HISTORY.md`](../../phase-crossregion/SESSION-HISTORY.md) (06-19) |
| CockroachDB | 2,145.2 | 4,896.0 | 真六節點、region locality 正確 | [`SESSION-HISTORY.md`](../../phase-crossregion/SESSION-HISTORY.md) (06-19) |
| YugabyteDB | 6,812.2 | 15,129.2 | 真六節點、leader-pin IDC、catalog wait 後可執行 | [`SESSION-HISTORY.md`](../../phase-crossregion/SESSION-HISTORY.md) (06-19) |

此段只能證明跨區 framework 已跑通；不可與 S-BASE / S-K8S 的 W=128 結果直接比較。

### 2.3 2026-07-03 TiDB × P-A × A-S W=128 正式口徑 cell（首個）

| threads | tpmC_mean (R1-R5) | CV | NEW_ORDER p99 | error | 備註 |
|---:|---:|---:|---:|---:|---|
| 16 | 9,905.5 | 1.6% | 78.0 ms | 0% | |
| 32 | 13,943.6 | 3.0% | 123.3 ms | 0% | |
| 64 | 15,627.4 | 1.3% | 241.6 ms | 0% | |
| 128 | **16,808.6** | 2.4% | 486.5 ms | 0% | 主水位 |

- 來源：[`baseline/w128/20260703T092243+0800/`](./baseline/w128/20260703T092243+0800/tidb-vm-6node-P-A-rc-20260703T092243+0800/)（`summary.json` + per-round go-tpc-stdout）
- 口徑：same-cluster、W=128、warmup 20min、5r×5min、placement 收斂後 freeze（PD API）、量測後 unfreeze；P-A leader gate 100% IDC PASS
- 採樣完整性：**GCP per-round metrics 300/300**（3 host × 5 metric × 4 threads × 5 rounds）、WAN probe per-round 80/80（GCP 端子探測空缺與 W=1 樣板一致，wan-probe.sh 直連化修正 bug #13 於本輪後才 commit，下輪生效）
- 對照：W=1 contention 探索輪見 [`compare/w1-pa/20260703T040155+0800/`](./compare/w1-pa/20260703T040155+0800/)（t128 平頂 ~4,600 tpmC = 鎖競爭天花板；只作機制對照）
- 效度邊界：X-CROSS `baseline_eligible=false` 不變——本 cell 是 X-CROSS 內部主數據，仍不入跨家正式排名；efficiency 欄為無 think/keying 口徑，忽略

---

## 3. 不採用為正式結果的資料

| 類型 | 位置 | 原因 |
|---|---|---|
| 2026-07-02 W=128 首跑輪 | `results/x-cross/baseline/w128/20260702T232256+0800/` | tpmC 有效但**網路採樣失敗**（WAN probe 未跑、GCP per-round metrics 全缺，IAP 殘留 bug #10/#11 修復前）；由 §2.3 的 20260703T092243 輪取代，保留供 bug 溯源 |
| 2026-06-21 redeploy run-to-run | [`SESSION-HISTORY.md`](../../phase-crossregion/SESSION-HISTORY.md) (06-21) | W=4 且每輪 redeploy；TiDB 1,552.2 -> 9,719.2，CockroachDB 3,929.6 -> 2,365.6，YugabyteDB 41.8 -> 23.0，變異不可作正式 benchmark |
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

- [`phase-crossregion/SESSION-HISTORY.md`](../../phase-crossregion/SESSION-HISTORY.md) (06-19 3db-smoke)
- [`phase-crossregion/SESSION-HISTORY.md`](../../phase-crossregion/SESSION-HISTORY.md) (06-21 determinism)
- [`phase-crossregion/SESSION-HISTORY.md`](../../phase-crossregion/SESSION-HISTORY.md) (06-22 determinism-v2)
- [`1_MeetingMinutes/0616-slide-draft.md`](../../1_MeetingMinutes/0616-slide-draft.md)
- [`results/PHASES.md`](../PHASES.md)

---

## 7. 變更紀錄

| 日期 | 內容 |
|---|---|
| 2026-07-03 | §2.3 新增 TiDB P-A A-S W=128 正式口徑 cell（20260703T092243；GCP per-round 300/300 齊）；§3 標註 07-02 輪因網路採樣失敗不採用；§0 目錄表補 baseline/w128 與 compare |
| 2026-06-26 | retrofit `summary.json` 至 determinism 三家 suite-dir（W=4；YBDB skip R1/R2）；同步 patch `summary-from-stdout.py` 支援 `--warehouses` / `--skip-rounds` 與 `-run<N>` suffix |
| 2026-06-24 | 依用途重整目錄：time-sync、dry-run、early smoke、determinism 分層 |
| 2026-06-24 | 目錄由 `results/X-CROSS/` 改為 `results/x-cross/`；前期 `results/x-cross-tc1/` 內容彙整至 `results/x-cross/preflight/` |
| 2026-06-23 | 建立 X-CROSS pipeline-log，確認 `results/x-cross/` 為 phase-crossregion 主資料目錄，`results/x-cross/preflight/` 為 chrony / preflight 證據目錄 |
