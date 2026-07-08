# 健檢工作筆記 — poc/ (2026-07-06)

## 範圍與邊界（開工前定義）
- 專案範圍：`/Users/wn.lin/vscode-git/dba_career/poc/`（phase-crossregion / ansible / tests / iac-gcp / iac-idc / 1_MeetingMinutes / results 的 md）
- HEAD：master @ 6677bfc9（健檢基準點）
- 不動：master（不 commit 到 master）、正式設定檔（terraform.tfvars / *.tfstate / ansible inventory）、特定模組（tests/common/*.sh、IDC 執行檔、results/ 原始數據目錄）
- 不做：live 環境操作（純靜態健檢，不 ssh .31）、無關重構、新功能
- 規模：phase-crossregion 56 + ansible 47 + tests 60 + iac 12 + minutes 21 + results md 65 ≈ 261 檔

## 2026-07-08 TiDB cross-region smoke 重跑（live 驗證 S1-S8 修復）

**目的**：S1-S8 這波改動動到 TiDB 實際執行路徑（Path C 刪除、iperf3 daemon 拆除+埠改 19999、
PD drain 共用化 lib-pd-drain.sh、CRDB freeze 補接線、Makefile .PHONY），需要 live 重跑驗證沒破壞。

**環境**：`make phase1`（IDC 3 VM + GCP 5 VM 全重建）→ `phase1-wait-via-31`（5/5 READY，elapsed=0s，
證明 iperf3 daemon 拆除沒讓 cloud-init 掛掉）→ `phase2`（含 phase2-iperf3-idc --install-only，
`.32` 上驗證 `iperf3` binary 裝好、`systemctl is-active iperf3-server`=inactive，證明常駐 daemon
真的沒起——S2b 修復 live 驗證通過）→ `phase3-tidb-deploy`（第一次即成功，15 節點、PD health 6/6 true）。

### 死路 1（已修 `29dad344`）：freeze/lib-pd-drain.sh 路徑錯誤
S5(YBDB)/S8(CRDB)/今日(CRDB 補接線) 寫的 5 處 freeze 呼叫都用 `$SELF/../freeze/...`——這是
**本機** repo 佈局（`phase-crossregion/scripts/` 與 `phase-crossregion/freeze/` 同層）。但**遠端
部署佈局不同**：`win-tidb-as-detach` 把 `freeze/` rsync 到 `$(CROSS_SCRIPTS_REMOTE)/freeze/`
（crossregion/ 底下的**子目錄**，非同層）；`win-tidb-as-w128.sh` 自己用 `FREEZE_DIR="$SELF/freeze"`
（無 `..`）才是正確慣例。教訓：**驗證遠端路徑絕不能只查本機檔案系統**——bash -n 語法檢查 + 本機
`ls path/../other/file` 存在性檢查 完全查不出這種「本機佈局 vs 遠端佈局不一致」的路徑 bug，
只有真的 live 執行才會現形。這正是 Stage 1 smoke「先炸再修」存在的意義。

**衍生教訓**：`phase2-bootstrap` 本身不 rsync `freeze/` 目錄（只有 `win-tidb-as-detach` 額外做這步）。
本次繞過 Makefile 直接 ssh 呼叫 `win-tidb-as-w128.sh` 做客製化 smoke 參數時，得手動
`rsync phase-crossregion/freeze/ .31:.../crossregion/freeze/` 補上，否則會缺檔。

### 死路 2（重試方法論陷阱，非程式碼 bug）：沿用同一 TPCC_TS 重跑造成 placement watcher 競態
修完路徑 bug 後沿用同一 TS 重跑，prepare 順利跑完但 placement gate 顯示 idc=0/19（應 ≥70%）。
根因：TiDB `tpcc` database **名稱不受 TS 影響**（TS 只決定 artifact 目錄名）；run-vm6-suite.sh
的 placement watcher 靠「`drop-create.log` 存在」+「9 張表存在」判斷「prepare 已完成 drop+create」
才套用 placement SQL——但 `tee` 一開管線就會建立（哪怕 0 bytes）drop-create.log，而上一輪殘留的
9 張舊表在**這一輪**真正 DROP DATABASE 完成前就已滿足「9 張表」條件 → watcher 搶在真正
drop+create 完成前套用 placement SQL，撞上並發 DDL（`ERROR 1008: Can't drop database ''`）。
**這不是新回歸**——正式生產跑法每個 cell 都是全新 TS + 全新 VM rebuild（Q11），資料庫從空的
開始，不會有殘留 9 張表的情境。純粹是我為了省時間沿用同一 TS 重試才踩到的邊界案例。
**處置**：手動 `DROP DATABASE tpcc`清乾淨殘留狀態 + 換新 TS 重跑，不修框架程式碼（範圍外，
真實場景不會發生）。

### 死路 3（新發現，未修，等 smoke 跑完再處理）：iperf3 reverse (GCP→IDC) 埠 19999 timeout
`wan-probe.sh` 的 iperf3 forward (idc→gcp) 成功、reverse (gcp→idc) 出現
`"error": "error - unable to connect to server: Connection timed out"`。用原始 TCP 連線測試
（不靠 iperf3，`/dev/tcp` from GCP to `172.24.40.32:19999`）**確認是真的網路層封鎖**，非偶發。
但同時觀察到：目前跑的 TiDB 叢集本身 PD/TiKV 在 GCP↔IDC 雙向都健康（proves 專線本身沒有
「GCP 不能主動連 IDC」的通則性限制）——推論：**專線對 GCP→IDC 方向可能是逐埠白名單**
（只放行 fw-request R1-R9 核准的埠範圍：2379-2380/4000/5433/7000-7100/8080/9000-9100/
10080/20160-20180/26257），19999 不在任何核准範圍內。這與 07-03 舊認知「/24 整段放行」
**不一致**——07-03 的驗證只測過 IDC→GCP 方向，從未測過反向，過去的「整段放行」結論可能
只對 IDC→GCP 方向成立，GCP→IDC 方向實際受埠範圍限制。**若這推論成立**，D9 選 19999
（刻意離開 TiKV range 求衛生）反而讓 reverse 方向失效；改回 20170（落在 R8 TiKV 核准範圍內）
可能兩個方向都通，但犧牲埠衛生（20170 在 DB service range 內）。需與使用者確認怎麼處理。

### 死路 4（新發現的程式碼 bug，未修，等 smoke 跑完再處理）：wan-probe.sh 漏檢 iperf3 JSON 內的 error 欄位
`wan-probe.sh` 的 `note_fail` 只在 `[[ -z "$rev" ]]`（輸出**完全空白**）才觸發——這只涵蓋
「SSH 失敗 / iperf3 binary 缺失」的失敗模式。但 iperf3 client 連線逾時時，**仍會印出格式良好的
JSON**（含 `"error": "..."` 欄位），並非空字串——導致這次的真實連線失敗被誤判為「探測成功」，
`=== wan-probe done (all probes succeeded) ===` 訊息掩蓋了真正的失敗。forward 與 reverse 兩處
（wan-probe.sh 行 251-257 與 263-269）都有此漏洞。修法：在寫入前多檢查一次
`echo "$rev" | grep -q '"error"'`，命中即呼叫 `note_fail`。

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
