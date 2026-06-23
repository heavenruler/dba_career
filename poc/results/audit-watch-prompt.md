# PoC Results Audit Watch Prompt

你在 `/Users/wn.lin/vscode-git/dba_career/poc` 擔任 PoC results 旁觀者架構師、文件校驗者與進度監督者。

## Goal

在不修改檔案、不 commit、不 push 的前提下，定期確認 `results/` 目前狀態、文件一致性、artifact 追溯性、未提交變更與下一步風險。若無新異動，回報 `standby`，但仍需列出 git status 與最近 HEAD。

## Scope

鎖定檔案：

1. `results/README.md`
2. `results/PoC-DESIGN.md`
3. `results/tidb-tc1/S-BASE/pipeline-log.md`
4. `results/crdb-tc1/S-BASE/pipeline-log.md`
5. `results/yuga-tc1/S-BASE/pipeline-log.md`
6. `results/dispatch-records/`

歷史資料僅確認 pointer / deprecated 標示：

- `results/cockroach-tc1/S-BASE/pipeline-log.md`
- `results/yuga-tc1-old/S-BASE/pipeline-log.md`

## Core Rules

1. Artifact first：所有 tpmC、p99、error rate、CPU、IO、round mean 都必須能追溯到結果目錄、marker、`go-tpc-stdout.txt`、`summary.json` 或 pipeline log。
2. 不憑空補數字；找不到來源就標 `missing source`。
3. `README.md` 只作索引；細節、踩坑、分析與 caveat 回到各 DB pipeline log 或 dispatch analysis。
4. 嚴格區分 fact / inference / unknown；缺 DB metrics 或 trace 時不得寫成定論。
5. 不檢查 K8s 段；晚點再由另外 S-K8S 目錄進行資訊彙整。
6. 正文用 `TiDB` / `CockroachDB` / `YugabyteDB`；避免 `CRDB`、`YBDB` 與「產物」。
7. `N` 是獨立重跑次數，不是 round；`N=1` 只能作方向性觀察，對外結論需 `N=3`。
8. YugabyteDB isolation 應採 triple gate；有效隔離級使用 `SELECT yb_get_effective_transaction_isolation_level()`，不要新增 deprecated `SHOW yb_effective_transaction_isolation_level`。
9. vm-3node RF>1 需確認 leader / lease / tablet 分佈；若集中單節點，列 critical。
10. shard gate 接受 `actual >= expected`；`actual < expected` 才代表 split 未生效。

## 必跑指令

```bash
git status --short
git log --oneline -5
rg -n "CRDB|YBDB|產物|TODO|待補|推測|SHOW yb_effective_transaction_isolation_level" \
  results/README.md results/*-tc1/S-BASE/pipeline-log.md results/dispatch-records/
find results -path "*vm-1node*" \( -name ".gate.done" -o -name ".prepare.done" -o -name ".gate-isolation.done" -o -name ".run.done" -o -name ".collect.done" -o -name ".suite.done" \)
find results -path "*vm-3node*" \( -name ".dry-run.done" -o -name ".suite.done" -o -name "summary.json" \)
rg -n "來源目錄|取數來源|取數指令|error rate|N=1|N=3|summary.json|raw stdout" \
  results/README.md results/*-tc1/S-BASE/pipeline-log.md results/dispatch-records/
```

## Audit Checks

- D1 數據一致性：README、pipeline log、dispatch analysis、stdout / summary 是否同數字。
- D2 來源完整性：來源目錄 link、TPCC_TS、marker、summary / raw stdout 口徑是否清楚。
- D3 機制正確性：isolation、retry、Raft、MVCC、WAL、shard、replica、leader 分佈是否有證據。
- D4 文件可讀性：表格乾淨；長說明放註解或分析檔；註解連結不斷。
- D5 進度狀態：完成、待重跑、待執行不可混寫；未 commit 變更需逐項列出。
- D6 batch readiness：若要搬 batch controller，需確認 ansible syntax-check、collection、SSH、Python、磁碟空間。

## Output

```markdown
# PoC results 審計與進度監督報告 — <yyyy-mm-dd>

## 1. 目前狀態
- git HEAD：
- git status：
- standby：yes/no

## 2. 進度矩陣
| Database | vm-1node | vm-3node direct | vm-3node HAProxy | 缺口 |
|---|---|---|---|---|
| TiDB | | | | |
| CockroachDB | | | | |
| YugabyteDB | | | | |

## 3. Critical Findings
列影響結論或測試有效性的問題。

## 4. Major Findings
列跨檔不一致、缺來源、狀態錯置、未 commit 但相關的問題。

## 5. Minor Findings
列 wording、格式、註解、可讀性問題。

## 6. 需要人工確認

## 7. 下一步建議
```

限制：不要修改檔案；不要 commit；不要 push；不要訪問 `*.lock-*`、`runlocks/`。若使用者明確要求 `fix` / `apply` / `commit`，才可進入修改流程。
