# poc/ 健檢報告（2026-07-06）

- 基準：master @ `6677bfc9`；方法：純靜態（不碰 live 環境）；掃描範圍 ~261 檔（排除 results/ 原始數據）
- 產出鏈：本報告（findings+驗證）→ `plan.md`（修復步驟）→ `decisions.md`（決策依據）→ `risks.md`（風險與未解）
- 每條 finding 附驗證命令，皆可在 repo root（`/Users/wn.lin/vscode-git/dba_career`）獨立重跑。

## 總覽

| 級別 | 條數 | 定義 |
|---|---|---|
| P0 會壞執行 | 3 | 跑了會炸，或靜默假成功污染數據 |
| P1 安全/數據效度 | 5 | 不炸但埋雷（hang、量測期干擾、金鑰安全） |
| P2 重複邏輯 | 5 | 同步修改必漏的多份實作 |
| P3 文件/衛生 | 6 | 誤導閱讀者但不影響執行 |

語法面全綠：118 sh（bash -n）、130 py（py_compile）、7 tf（fmt+validate）全 PASS。90 yaml 僅基本結構檢查（本機無 PyYAML，**完整驗證未做=未驗證項**）。

---

## P0 — 會壞執行

### P0-1 Path C 全鏈壞：`run-round-only.sh` 從未被送上 .31【本體已覆核】
`phase2-bootstrap`（`phase-crossregion/Makefile:329`）只 rsync `phase-crossregion/scripts/` → 遠端 `/tmp/poc-tpcc/scripts/crossregion/`；但 `run-round-only.sh` 位於 `phase-crossregion/`（scripts/ 上一層）→ 遠端必缺檔。症狀兩段式：
- `phase-warmup-only-*`（:1145 附近）整段包 `|| true` → **fail-open 靜默跳過**（warmup 假成功）
- `phase-roundrun-only-*`（:1176 起）沒包 → R1 量測輪**硬炸**

Path C orchestrator（:1268 起）三 DB 全中。正式 W=128（run-vm6-suite 路徑）不受影響。
```bash
git ls-files poc/phase-crossregion/scripts/ | grep run-round-only   # 空 = scripts/ 下沒有
git ls-files poc/ | grep run-round-only                             # 在上一層
grep -n 'run-round-only' poc/phase-crossregion/Makefile
```

### P0-2 `sweep-archive.sh` 預設走 IAP tunnel 12215（違反 via-31 硬規則）
`scripts/sweep-archive.sh:33,69` 預設 `GCP_CLIENT_PORT=12215`（Mac 本機 IAP tunnel）。現行架構 tunnel 不建（README 硬規則「絕不走 IAP」）→ 從 Mac 直接執行必失敗。
```bash
grep -n '12215\|GCP_CLIENT_PORT' poc/phase-crossregion/scripts/sweep-archive.sh
```

### P0-3 `cleanup-ybdb.sh` 缺 VERIFY 段（清理不對稱）
cleanup-tidb/crdb 都是「CLEANUP + VERIFY」兩段式；cleanup-ybdb 只 dispatch cleanup、不驗證 yb-master/yb-tserver 真的停了 → 殘留進程會污染下一輪。另 cleanup-crdb 只清 3 個 GCP IP（.11-.13），tidb/ybdb 清 5 個——非 bug 但不對稱（crdb 不裝 .14/.15），交接者易誤判。
```bash
grep -n 'VERIFY_CMD' poc/phase-crossregion/scripts/cleanup-{tidb,crdb,ybdb}.sh   # ybdb 無輸出
```

## P1 — 安全/數據效度

### P1-1 YBDB freeze 兩路徑語義不同（量測效度風險）
`freeze/freeze-ybdb.sh:53-64`：disable LB 後 poll `get_is_load_balancer_idle` 30×5s（fail-closed）；但 `run-vm6-suite.sh:292` inline 版只 disable 就繼續、:351 unfreeze 也 inline。**suite 實際走 inline 版** → YBDB 量測窗內 LB 可能還在搬 tablet。
```bash
grep -n 'set_load_balancer_enabled' poc/phase-crossregion/scripts/run-vm6-suite.sh poc/phase-crossregion/freeze/{freeze,unfreeze}-ybdb.sh
```

### P1-2 `freeze-ybdb.sh`/`unfreeze-ybdb.sh` SSH 缺 StrictHostKeyChecking → 可能 hang
`SSH=` 變數無該選項（系統預設 ask）→ VM rebuild 後 known_hosts 沒記錄時互動卡死，detached suite 無人可答。
```bash
grep -n '^SSH=' poc/phase-crossregion/freeze/{freeze,unfreeze}-ybdb.sh
```

### P1-3 cleanup 三件套用 `StrictHostKeyChecking=no`（11 處），全專案其餘 `accept-new`
`=no` 對已知主機金鑰變更靜默接受（MITM 面）；且政策分裂本身即隱患。
```bash
grep -rn 'StrictHostKeyChecking=no' poc/phase-crossregion/scripts/ poc/phase-crossregion/freeze/
```

### P1-4 `iac-gcp/main.tf:122-139` 仍起 5201 常駐 iperf3 daemon（架構矛盾）
SESSION-HISTORY 宣稱已改「臨時起、不留常駐（安全顧慮）」，但 IaC 沒落地 → 每次 rebuild 仍有 0.0.0.0:5201 常駐監聽。二選一（拆常駐 or 承認常駐並撤 ephemeral 敘述）須拍板——見 risks。
```bash
grep -n 'iperf3' poc/iac-gcp/main.tf
```

### P1-5 `phase8.5-fetch` 不在 .PHONY（phase9 依賴它）
若 poc/ 下出現同名檔案/目錄，make 誤判 up-to-date 跳過 → phase9 拿不到 artifact。同類缺漏共 6 個（另：phase-cleanup-{tidb,crdb,ybdb}、phase2-iperf3-idc、phase0-preflight-fix-only-processes）。
```bash
grep -n 'phase8.5-fetch' poc/phase-crossregion/Makefile | head -3
grep -c 'phase8.5-fetch' <(grep '.PHONY' poc/phase-crossregion/Makefile)   # 0 = 缺
```

## P2 — 重複邏輯（同步風險）

| # | 內容 | 位置 | 差異 |
|---|---|---|---|
| P2-1 | PD operators drain 兩份（bug #14 補丁複製了 freeze 內建邏輯） | `freeze/freeze-tidb.sh:69-78` vs `scripts/run-vm6-suite.sh:322-328` | 150s vs 300s、變數名、PD_URL 來源 |
| P2-2 | TiKV RF 收斂 poll 三份 | `ansible/playbooks/tidb-vm3.yml:373` 用 `{{ tidb_replicas }}`、`tidb-vm6.yml:373` hardcode `3`、`tests/common/dry-run-confirm.sh:122` 又一種寫法 | 同 SQL 三寫法 |
| P2-3 | iperf3 埠預設不同步 | `scripts/wan-probe.sh` 20170 vs `scripts/idc-iperf3-bootstrap.sh:68` 5201 | `--execute` 全模式會起 5201 service |
| P2-4 | tiup display poll 兩 playbook 各自 hardcode cluster name | `tidb-vm3.yml:352` / `tidb-vm6.yml:356` | vm6 連 host 都 hardcode |
| P2-5 | SSH wrapper 6+ 處自定義 | wan-probe / idc-vm-baseline-reset / cleanup-* / check-homogeneity / freeze-ybdb / promotion-gate | ConnectTimeout 5/8/10 不一 |

驗證命令見 plan.md 對應步驟。

## P3 — 文件/衛生

| # | 內容 | 位置 |
|---|---|---|
| P3-1 | 「5201 未開通」錯誤前提殘留（07-03 實測證偽）| `wan-probe.sh:26,245`；`SESSION-HISTORY.md:64`（與 :539 勘誤**同文件矛盾**）|
| P3-2 | pipeline-log.md 自我矛盾：§4:91「目前沒有 summary.json」vs §2.3:68 已有 | `results/x-cross/pipeline-log.md` |
| P3-3 | tracked `.pyc` 2 檔 | `poc/tpmc-report/__pycache__/`（`git ls-files '*.pyc'`）|
| P3-4 | `probe-rto-driver` 同名雙實作（.sh + Go 目錄），README 只提其一 | `scripts/probe-rto-driver{.sh,/}` |
| P3-5 | `wan/baseline-measurement.md` 引用 2 個不存在腳本 + IAP 殘留（已標 supersede） | 行 30/50/91 |
| P3-6 | 孤兒 target 5 個（Makefile.tc1 未被 include）+ 過時 IAP 註解（playbooks 頂部、host-resolution.sh:22） | `phase-crossregion/Makefile:878-950,1380` |
| P3-7 | 舊拓撲 IP 殘留：`172.24.40.25`（×5 檔）/ `.17`（×1）只存在於 legacy 報告腳本 | `tidb/report/report-4/*.sh`、`tidb/tmp/benchmark_#2/` |

**記錄不列缺陷**（設計使然，交接者須知）：HAProxy 入口三套值（3-node = `.34:4000` 或 `.32:15257/15433`；vm6 X-CROSS = `172.24.47.20`）——per-topology 有意區分；GCP probe 目標 `.15`（SSH latency）與 `.14`（DB probe）並存——用途不同。

## 掃描信度聲明

- 掃描 A/B/C/D 皆附 `git status` 乾淨證明；B 的 FAIL-1 與 D 的 A1/A5 經本體獨立覆核屬實。
- 掃描 E（Haiku 常數交叉表）**中途摘要**兩條宣稱被本體證偽（棄用）；其**最終交叉表**經自我修正後與本體抽查及 C/D 交集全部吻合 → 採信（詳 decisions.md D5）。ConnectTimeout 分佈實測：=5 ×57、=10 ×14、=3 ×2、=8 ×1。
- 唯讀承諾驗證：全程 tree 乾淨；唯一擾動為掃描 A 觸碰 tracked .pyc（已 `git checkout --` 還原，且該 .pyc 入版控本身成為 P3-3）。
