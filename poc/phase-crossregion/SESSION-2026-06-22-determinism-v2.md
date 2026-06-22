# SESSION 2026-06-22 — Determinism v2 (Path C 兩段式驗證 + W=128 baseline)

> 接續 SESSION-2026-06-21-determinism.md
> Decision: Path C → Path A
> Codex round-1: 263s reply, 5-block strategy

---

## 1. 昨日結論回顧

- W=4 × run-1/run-2 測出 ±50% variance，不具決定性
- 推測主要 noise 來自 redeploy 與 cluster 狀態不穩定
- 決定採用**兩段式**驗證：先 30min 同 cluster 測試，再根據結果進 Path A

## 2. Codex round-1 關鍵 insights

| Insight | 影響 |
|---|---|
| 主 noise 不是 W，是「每輪 redeploy」 | 改變測試協定 |
| W=128 已夠 (16 threads 碰撞 0.9) | 不需 W=256/512 |
| Suite 模式：1 deploy → warmup → 5 rounds → 取 R2-R5 median | Makefile 重構 |
| Freeze scheduler/balancer per DB | 新增 phase |
| go-tpc 可能無 --warmup 旗標 | 用外部 warmup loop |

## 3. Path C 兩段式設計

### Step 1: 30-min 假說驗證 (同 cluster W=4 N=5)
- 先 deploy + prepare (一次)
- 連跑 5 輪 W=4 RUN_SEC=300 THREADS=16
- 收 5 個 tpmC，計算 CV
- 通過條件：CV ≤ 10% (per DB)
- 失敗對策：診斷其他 noise source，不貿然進 Path A

### Step 2: Path A 正式 baseline (W=128)
- 觸發條件：Step 1 通過
- 3 DB × W=128 × 1 suite × (20m warmup + 5 rounds × 5min)
- 取 R2-R5 median + CV
- 預估 16-18h

## 4. 4 Agents 並行任務拆分

| Agent | Model | 任務 | 狀態 |
|---|---|---|---|
| Agent-Make | sonnet | Makefile 新增 freeze/unfreeze + smoke-only + validate-hypothesis | pending |
| Agent-Verify | haiku | go-tpc 旗標真實性驗證 | pending |
| Agent-Doc | haiku | 本 SSOT | complete |
| Agent-Probe | sonnet | per-DB freeze/unfreeze script | pending |

## 5. CV 計算與通過條件

```python
import statistics
tpmc = [r1, r2, r3, r4, r5]  # 5 round 結果
mean = statistics.mean(tpmc)
stdev = statistics.stdev(tpmc)
cv = stdev / mean
print(f"mean={mean:.1f} stdev={stdev:.1f} CV={cv:.2%}")
```

| CV | 判讀 |
|---|---|
| ≤ 5% | 穩定，可直接進 W=128 |
| 5-10% | 可接受，進 W=128 並標註 |
| > 10% | NG，先排查再進 Path A |

## 6. 風險與 fallback

- Step 1 任一 DB CV > 20% → 該 DB 進 Path A 前先單獨偵錯
- Step 2 任一 DB 中途失敗 → 用 R2 以前的 round 補；不退回重 deploy
- 2 天時程：Day1 (今天) Step 1 + Step 2 開跑；Day2 收 Step 2 結果 + 文件

## 7. Agents 並行成果（回填）

### 7.1 Makefile 改動摘要（Agent-Make / sonnet）

`poc/Makefile` +256 lines (678 → 933)

| 類別 | 新增 target | 用途 |
|---|---|---|
| freeze | `phase-freeze-tidb` / `phase-freeze-crdb` / `phase-freeze-ybdb` | dump 原 config 後關閉 scheduler/balancer |
| unfreeze | `phase-unfreeze-tidb/crdb/ybdb` | 從 dump 還原 |
| smoke-only | `phase-smoke-only-tidb/crdb/ybdb` | 跳過 deploy/prepare 直接 run，依 `SMOKE_ROUND` 寫入 `round-N/` |
| orchestration | `phase-c-validate-hypothesis` | freeze 3 DB → 5 round loop → unfreeze → cv-report |
| CV 分析 | `phase-c-cv-report` | R2-R5 mean/stddev/CV%，分 STABLE/MARGINAL/NOISY |

新增變數：`TIDB_PD` / `SMOKE_ROUND` / `SMOKE_RESULT_BASE` / `CRDB_FREEZE_DUMP` / `YBDB_UNIV_DUMP`

dry-run 確認 chain 順序正確、語法無誤。

### 7.2 go-tpc 旗標 ground truth（Agent-Verify / haiku）

⚠️ **Codex 部分假設不成立**。實測 go-tpc 旗標：

| 旗標 | Codex 假設 | 真實 | 應對 |
|---|---|---|---|
| `--wait` | 存在 | ✅ | 統一控制 keying + think time |
| `--warmup` | 質疑 | ❌ 不存在 | **外部 warmup loop**（短跑一輪丟棄） |
| `--ramp-up` | 質疑 | ❌ 不存在 | 無漸進啟動 |
| `--keying-time` | 質疑 | ❌ 不存在 | 由 `--wait` 控制 |
| `--think-time` | 質疑 | ❌ 不存在 | 由 `--wait` 控制 |
| `--check-all` | 存在 | ✅ | 用於 `go-tpc tpcc check` 子命令 |
| `--ignore-error` | 質疑 | ✅ 存在（global） | 預設 NOT 開啟 |
| `--weight` | 存在 | ✅ | `--weight 45,43,4,4,4` |
| `--conn-refresh-interval` | 存在 | ✅ | 預設 0；可設 `10s` 平衡流量 |

額外：
- `--output {plain|table|json}` — json 可用於下游解析
- `--max-measure-latency 16s` — 控制 latency 測量精度
- **無原生 p50/p99 輸出**

⚠️ Warmup 策略確認：**外部跑「丟棄 R1」即可**，不用 `--warmup` 旗標。

help dump：`/tmp/go-tpc-help-1782065848.txt`（暫存，下次重啟可能消失）

### 7.3 Freeze/Unfreeze 獨立 script（Agent-Probe / sonnet）

目錄：`poc/phase-crossregion/freeze/`

| 檔案 | 內容 |
|---|---|
| `freeze-tidb.sh` | dump PD config → 5 limit=0 → sleep 30s → operator show 確認無 pending |
| `unfreeze-tidb.sh` | `jq` 讀 dump 還原各 limit |
| `freeze-crdb.sh` | dump 2 setting → SET false → sleep 10s |
| `unfreeze-crdb.sh` | `awk` 讀 dump 還原（含原本就是 false） |
| `freeze-ybdb.sh` | dump universe + lb_idle → set_load_balancer_enabled 0 → sleep 15s → confirm Idle=1 |
| `unfreeze-ybdb.sh` | set_load_balancer_enabled 1 |
| `README.md` | env 變數 / 用法 / freeze 後禁忌 / 緊急 unfreeze |

6 script 全部 `bash -n` 語法通過。`set -euo pipefail` + `ssh -o BatchMode=yes`。

⚠️ 注意：Makefile inline freeze/unfreeze 與此目錄 script 功能重疊。建議下次重構統一 → Makefile call shell script，避免雙份維護。Step 1 不阻塞，先沿用 Makefile inline。

---

## 8. 下一步（待 user 啟動）

1. `cd iac-gcp && terraform apply` (~10 min)
2. `cd iac-idc && terraform apply` (~5 min)
3. `make phase2-init` (ansible inventory) + `make phase3-tidb-deploy` / `phase4-ybdb-deploy` / `phase5-crdb-deploy`
4. 各 DB prepare W=4 (~2-3min)
5. `make phase-c-validate-hypothesis WAREHOUSES=4 RUN_SEC=300 THREADS_LIST=16 TPCC_TS=$(date +%Y%m%dT%H%M%S%z)`
6. 收 CV report：CV ≤ 10% 通過 → 進 Step 2 (W=128)；否則先偵錯

預估 Step 1 wall-clock：deploy 30min + prepare 9min + 5 round × 3 DB × 5min = ~1.2h

---

**Last updated**: 2026-06-22 agents 完成回填
**Next review**: Step 1 跑完後填 §9（W=4 N=5 結果 + CV per DB + 是否通過）
