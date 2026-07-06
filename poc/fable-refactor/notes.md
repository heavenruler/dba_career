# 健檢工作筆記 — poc/ (2026-07-06)

## 範圍與邊界（開工前定義）
- 專案範圍：`/Users/wn.lin/vscode-git/dba_career/poc/`（phase-crossregion / ansible / tests / iac-gcp / iac-idc / 1_MeetingMinutes / results 的 md）
- HEAD：master @ 6677bfc9（健檢基準點）
- 不動：master（不 commit 到 master）、正式設定檔（terraform.tfvars / *.tfstate / ansible inventory）、特定模組（tests/common/*.sh、IDC 執行檔、results/ 原始數據目錄）
- 不做：live 環境操作（純靜態健檢，不 ssh .31）、無關重構、新功能
- 規模：phase-crossregion 56 + ansible 47 + tests 60 + iac 12 + minutes 21 + results md 65 ≈ 261 檔

## 進行中
- [x] 5 路平行掃描（A 語法 / B Makefile / C 重複 / D drift / E 常數）
- [x] 綜合判讀 → decisions.md(D1-D8) / plan.md(S1-S8) / risks.md(R1-R6+未驗證表) / healthcheck-report.md(P0×3 P1×5 P2×5 P3×7)
- [x] spike branch `spike/healthcheck-poc` @ 5cd6d6d8（POC-1 wan-probe 註解勘誤 + POC-2 埠對齊 20170；驗收 bash -n / --dry-run port=20170 / grep 未開通=0 全過）
- [x] 完整性終驗：master 仍 @ 6677bfc9 未動、working tree 乾淨、五份交接檔已遷至 poc/fable-refactor/

## 交接指引（給下一個模型）
1. 讀順序：healthcheck-report.md → decisions.md → risks.md → plan.md
2. 動手前：R1（iperf3 架構二選一）與 R2（Path C 修/廢）要先問使用者
3. 執行順序：S3+S6+S7（零風險批）→ S4 → S5 → S2 → S8；S1 已在 spike branch
4. 鐵律：不 commit master、不動 tests/common、commit 用 -F、subagent 數據要抽查

## 死路
- **[死路] 掃描 E（Haiku 常數交叉表）棄用**：宣稱「20170 零使用」「gproxy 未使用」——本體抽查兩條皆證偽（wan-probe.sh:245 有 20170、main.tf:86 有 gproxy）。Haiku 對「多 pattern 大範圍 grep 統計」會產生 false negative 而不自知。教訓：便宜模型適合「跑固定命令回報輸出」（如掃描 A 逐檔 bash -n），不適合「自行設計 grep 策略的統計」。E 的職責由掃描 C（SSH 選項）/ D（埠 drift）+ 本體補查（IAP 1221x 全清單）覆蓋。
- **[本體補查] IAP 1221x 殘留**：功能性殘留僅 `scripts/sweep-archive.sh`（預設 12215）；`ansible/playbooks/*-vm6.yml` 頂部註解與 `tests/common/lib/host-resolution.sh:22` 為過時註解；`iac-gcp/tunnel.sh` 是 tunnel 工具本身（phase9-tunnels-stop 還引用，屬 legacy 工具非執行路徑）。

## Learnings / 死路 / 意外發現
- **[意外發現] tracked .pyc**：`poc/tpmc-report/__pycache__/*.pyc` 兩檔在版控內（`git ls-files '*.pyc'` 可證）。掃描 agent 跑 py_compile 時碰到才暴露；已 `git checkout --` 還原、tree 乾淨。→ 列入 findings（建議 rm --cached + .gitignore）。
- **[掃描C結果] 重複邏輯 9 條**（agent 附 git status 乾淨）：
  - F1 高：cleanup-{tidb,crdb,ybdb} 用 `StrictHostKeyChecking=no`（11 處），其餘全專案 `accept-new` → 安全政策分裂
  - F2 高：PD operators drain 兩份實作（freeze-tidb.sh 150s vs run-vm6-suite.sh 300s，bug #14 補丁造成）
  - F3 高：TiKV RF 收斂 poll 三份（tidb-vm3.yml 用變數 / tidb-vm6.yml hardcode 3 / dry-run-confirm.sh 又一種寫法）
  - F4 中高：SSH wrapper 6+ 處自定義（ConnectTimeout 5/8/10 不一；freeze-ybdb.sh 的 SSH 變數**缺 StrictHostKeyChecking → known_hosts 沒記錄會 hang**）
  - F5 中高：cleanup-ybdb.sh 缺 VERIFY 段（tidb/crdb 都有）；crdb 只清 3 GCP IP、tidb/ybdb 清 5
  - F6 中：tiup display poll 兩 playbook hardcode cluster name
  - F7 中：YBDB LB freeze 有兩條路徑（freeze-ybdb.sh 有 idle 確認 fail-closed；run-vm6-suite.sh inline 版沒有）→ 行為不一致
  - F8 低：tests/prepare 與 tests/run-all 16 對鏡像檔（有意設計，但共同參數要改 32 檔）
  - F9 低：tests/common 的 log 函式只有 run-vm6-suite.sh 在用，其他腳本各自 echo
- **[掃描D結果] drift findings**（agent 附 git status 乾淨）：
  - A1 **架構矛盾**：iac-gcp/main.tf:122-139 仍 `iperf3 -s -p 5201` 常駐 systemd；SESSION-HISTORY 宣稱「改臨時起、不留常駐」但 IaC 沒落地 → GCP rebuild 後仍有 0.0.0.0:5201 常駐監聽（自己說的安全顧慮沒兌現）
  - A2 wan-probe.sh:26,245 「5201 未開通」錯誤前提註解（07-03 已實測證偽）
  - A3 idc-iperf3-bootstrap.sh IPERF_PORT default 仍 5201（--execute 不帶 --install-only 會起 5201 service）；wan-probe 已改 20170 → 兩腳本預設不同步
  - A4 wan/baseline-measurement.md:30 IAP tunnel 殘留（已標 supersede，複製即炸）
  - A5 **sweep-archive.sh:33,69 預設 GCP_CLIENT_PORT=12215 IAP tunnel** → 違反 via-31 硬規則，從 Mac 跑會失敗
  - B1/B2 baseline-measurement.md 引用兩個不存在腳本（自述 Pending 的 placeholder）
  - C1 pipeline-log.md **自我矛盾**：§4:91「目前沒有 summary.json」vs §2.3:68 已有（§2.3 更新後 §4 沒同步）
  - C2 probe-rto-driver 同名雙實作（.sh + Go 目錄），README 只提其一
  - D 「5201 未開通」殘留 4 位置；SESSION-HISTORY **同文件內前後矛盾**（:64 舊說法 vs :539 勘誤）
  - E/F make targets 與腳本引用全部存在（0 死 target、0 死腳本）
- **[掃描B結果] Makefile**（agent 附 git status 乾淨）：
  - FAIL-1 **已本體覆核屬實（Path C 全鏈壞）**：phase2-bootstrap（Makefile:329）只 rsync `phase-crossregion/scripts/` → `/tmp/poc-tpcc/scripts/crossregion/`；`run-round-only.sh` 在 scripts/ 上一層，遠端必缺。症狀兩段式：phase-warmup-only-*（:1145 附近）包 `|| true` → **fail-open 靜默跳過**；phase-roundrun-only-*（:1176+）沒包 → R1 硬炸。Path C orchestrator（:1268 起）三 DB 全中。正式 W=128 走 run-vm6-suite 路徑**不受影響**。驗證：`git ls-files poc/phase-crossregion/scripts/ | grep run-round-only` 為空、上一層有檔。
  - （更正掃描中的初判）`Makefile.bak-2026-06-26` 是 **ignored untracked**（git status --ignored 顯 `!!`），不在版控內 → 只是工作目錄殘檔，嚴重度低
  - .PHONY 缺漏 6 個（phase8.5-fetch 被 phase9 依賴，風險最高；另 phase-cleanup-{tidb,crdb,ybdb}、phase2-iperf3-idc、phase0-preflight-fix-only-processes）
  - 孤兒 target 5 個（new-idc-vms/new-gcp-vms/gcp-wait-startup/ansible-ping 只被未 include 的 Makefile.tc1 引用；phase0-preflight-fix-only-processes 完全無引用）
  - 重複 target 0、變數衝突 0、CWD cd 危險 0（都有 && 串接）
- **[掃描A結果] 語法全綠**：118 sh（bash -n）/ 130 py（py_compile）/ 7 tf（fmt -check + validate）全 PASS；90 yaml 只做了基本結構檢查（本機無 PyYAML/yamllint，完整驗證未做 → 標註未驗證項）。
