# 任務：phase-crossregion 接續推進 — 修正 → 驗證 → Wave 4 正式採樣

Repo：/Users/wn.lin/vscode-git/dba_career/poc
角色：執行 operator + coordinator。實際跑指令、盯進度、驗收數據；不要只提建議。
允許 subagent（機械編輯用 haiku、盤點比對用 sonnet、Makefile/shell 手術用預設繼承）；
subagent 一律禁 commit，事後 parent 必驗 `git status`；subagent 的數據宣稱必抽查（一正一反例）。

## 開工必讀（順序）
1. `phase-crossregion/README.md` — Make targets + hard rules
2. `phase-crossregion/SESSION-HISTORY.md` — 「關鍵結論速查」+ 07-02/07-03 章節（14 bugs + iperf3 實測）
3. `poc/fable-refactor/healthcheck-report.md` + `plan.md` + `risks.md`（同目錄）（2026-07-06 健檢：20 findings、修復步驟 S1-S8、待拍板 R1/R2）
4. `results/x-cross/pipeline-log.md` — 採信數據口徑（§2.3 = W=128 正式 cell 樣板）
5. `phase-crossregion/decisions-2026-06-08.md` — Q11（per-cell full rebuild）/ Q15（CV=R1-R5 mean）

## 硬規則（違反即失敗）
- 機敏（vsphere_password/token/私鑰）不得出現在任何輸出、檔案、log
- 不 push（human 才 push）；不重命名 artifact 目錄；不改 terraform.tfvars/tfstate；不改 tests/common/*.sh
- 環境操作一律 `ssh root@172.24.40.31` jump；**絕不走 IAP localhost:1221x**
- commit 一律 `git commit -F <file>`（RTK hook 會把 `-m` 換成 "update"）
- 長跑（>30min）detach 在 .31（nohup），Mac 只做短觸發；Mac 在線段配 `caffeinate -i`
- **一律從 poc/ 跑 make**（`make -C /abs/poc <target>`；相對路徑以 poc/ 為基準）
- chaos/F1 planner-only；`--execute` 實跑須單獨 PR + DBA review
- region-schedule-limit=0 是部署值，不得改非零；X-CROSS baseline_eligible=false 不變

## 現況（2026-07-06 快照，已驗證）
- **master @ 6677bfc9**；VM 全拆（iac-idc/iac-gcp state 0）；每 cell 從 `make phase1` 起（Q11）
- **Win-1 TiDB cell 已完成**：`baseline/w128/20260703T092243+0800/` 8/8 驗收（tpmC t128=16,808.6 CV 2.4%、GCP per-round 300/300、WAN probe 80/80）→ pipeline-log §2.3。**不需再跑**
- bug #13（wan-probe IAP→直連）/ bug #14（ALTER→freeze race，pre-freeze operator drain）已修並經 W=1 t16 N=1 驗證輪確認
- iperf3 已接線（commit d00c1a03）：GCP=phase1 cloud-init 裝、IDC=phase2-iperf3-idc target 裝、
  wan-probe 臨時 server（`iperf3 -s -1 -p 20170`）、機制經 07-03 單 VM 實測；**JSON 採樣未 live 首驗**（下輪 warmup-post 自動發生）
- 專線 FW 認知更正：實測 /24↔/24 整段放行（5201 也可達）；別再用「埠沒列 fw-request＝被擋」推論
- **spike/healthcheck-poc @ 5cd6d6d8 尚未合入 master**（wan-probe 註解勘誤 + idc-iperf3-bootstrap 埠 20170）
- CRDB/YBDB 的 deploy/suite/teardown 三家化後**未 live 驗證——當作會炸**，先小 W smoke

## Stage 0：修正（Wave 4 阻斷項優先；對應 fable-refactor/plan.md 步驟編號）

| # | 內容 | 依據 | 驗收 |
|---|---|---|---|
| M1 | cherry-pick `5cd6d6d8`（spike/healthcheck-poc）入 master | plan S1 | `git log -1`；`grep -c '未開通' scripts/wan-probe.sh` = 0 |
| M2 | cleanup-ybdb.sh 補 VERIFY 段（抄 cleanup-crdb 兩段式） | P0-3/S5a | `grep -n VERIFY_CMD scripts/cleanup-ybdb.sh` 有輸出 |
| M3 | freeze/unfreeze-ybdb.sh `SSH=` 補 `-o StrictHostKeyChecking=accept-new` | P1-2/S5b | grep 確認兩檔皆有 |
| M4 | cleanup-{tidb,crdb,ybdb} `=no`→`accept-new`（11 處） | P1-3/S5c | `grep -rn 'StrictHostKeyChecking=no' phase-crossregion/` = 0 |
| M5 | run-vm6-suite.sh ybdb 分支改呼叫 freeze/unfreeze-ybdb.sh（拿 LB idle 確認），刪 inline | P1-1/S5d | grep `set_load_balancer_enabled` 只剩 freeze script 內；**live 驗證在 Stage 1 YBDB smoke** |
| M6 | Makefile 補 .PHONY ×6（phase8.5-fetch 最要緊） | P1-5/S3 | plan S3 的 for-loop 檢查全 OK |
| M7 | 文件勘誤批：SESSION-HISTORY:64 加勘誤指標、pipeline-log §4 summary.json 句、tracked .pyc 移出版控 | S6/S7 | plan 對應驗收命令 |

每步：最小 diff → `bash -n` → 單獨 commit（`fix(phase-crossregion):` 前綴、-F）。
**勿碰**：Path C（warmup-only/roundrun-only；已知壞、Wave 4 不用、修/廢等 user 拍板 R2）、
iac-gcp/main.tf 5201 常駐段（R1 待拍板；與 ephemeral 20170 並存不衝突不擋路）、sweep-archive.sh（S4，非 Wave 4 必經，時間富裕才修）。

## Stage 1：驗證（確認無誤才進正式）
1. 靜態：`bash -n` 全改檔 + `make -C poc -n phase2 phase8.5-fetch TPCC_TS=dummy` 正常展開
2. **CRDB smoke**：W=1 t16 N=1 全鏈（phase1→phase2→phase2-gate→phase3-crdb-deploy→suite→static-check→fetch smoke/early-runs→phase9-tunnels-stop phase9-destroy）
3. **YBDB smoke**：同上（含 M5 的 freeze idle 確認路徑 live 首驗）
4. smoke 驗收（每家）：`.window.done`、wan-probe per-phase 檔齊（chrony 6 host + netdev + **iperf3 section 首現**：warmup-post 應有 forward/reverse JSON 或明確 skip 行）、summary.json 有值、freeze/unfreeze 痕跡正確、無 failed.txt 非預期項
5. smoke 數據入 `smoke/early-runs/`，commit（`data(x-cross):`），SESSION-HISTORY 記踩坑
6. TiDB 不需重 smoke（鏈已驗）；若 CRDB/YBDB smoke 因框架 bug 失敗：修 → bash -n → rsync .31 → 重跑；同因兩敗即停，整理現場等 user

## Stage 2：正式採樣（Wave 4，每 cell 照 Q11 full rebuild）
執行序模板（TiDB 版已驗證；換 DB 換 target 名）：
```bash
TS=$(date +%Y%m%dT%H%M%S%z)
caffeinate -i make -C /Users/wn.lin/vscode-git/dba_career/poc phase1 phase1-wait-via-31 phase2 phase2-gate
make -C ... phase3-{tidb|crdb|ybdb}-deploy PLACEMENT=P-A TPCC_TS=$TS
make -C ... win-{db}-as-detach PLACEMENT=P-A TPCC_TS=$TS      # detach 後 Mac 可關機
# 輪詢 240s：win-{db}-as-status；.window.done 後：
make -C ... phase8.5-static-check TPCC_TS=$TS
make -C ... phase8.5-fetch TPCC_TS=$TS LOCAL_RESULT_CATEGORY=baseline/w128
make -C ... phase9                                             # 正式輪收尾拆 VM
```
驗收 fail-closed 9 項（少一項不得宣告 DONE；樣板=baseline/w128/20260703T092243）：
1 `.window.done` status=DONE；2 WAN probe 檔每輪齊（W=128 口徑 80/80）；3 GCP per-round metrics 300/300；
4 summary.json tpmC 有值（efficiency >100% 忽略）；5 leader-snapshot + P-A gate 100% IDC；
6 PD/等效凍結已解除（TiDB：`curl :2379/pd/api/v1/config/schedule` leader-schedule-limit ≠ 0；YBDB：LB re-enabled）；
7 static-check PASS；8 **iperf3 section 有 JSON**（bits_per_second/retransmits 兩方向）；
9 收檔 commit + pipeline-log 記一筆
順序：Win-1 CRDB → Win-1 YBDB（TiDB 已完）→ **Win-2 前必解四缺口** → Win-2…Win-6 → Wave 5（audit-9 文件盤點可隨時並行）→ Wave 6。

Win-2 前必解四缺口（勿臨場踩雷）：
1. A-A / A-A-RO 無 Makefile 進入點：`run-vm6-aa.sh` 存在但從未接線；GCP 端 client 路徑需走 .31（先驗 FW 涵蓋 .31→GCP client ssh）
2. artifact 命名不含 PROFILE：`{db}-vm-6node-{P-A|P-B}-rc-<ts>` 同 placement 不同 profile 會混淆 static-check/promotion glob → 先拍板命名方案（連動 promotion-gate.sh、summary regex、result targets）
3. 六視窗全矩陣是對既有 3-cell 決策的擴張 → 先補一筆 decisions（Q16）再跑
4. probe driver（`scripts/probe-rto-driver/`，Go 版）未接 Makefile；promotion #7 要 probe-stats.json（Wave 5 前接線設計，planner 審查後才實跑）

## Wave 4→6 路線圖（user 指定，依序）
```
Wave 4: Win-1 P-A×A-S 三家 → Win-2 P-A×A-A-RO → Win-3 P-A×A-A → Win-4 P-B×A-S → Win-5 P-B×A-A-RO → Win-6 P-B×A-A
Wave 5: audit-9 admin CLI confirm → F1 planned failover → C1 WAN partition → C4 IDC leader die → C7 gate fail-closed（皆三家）
Wave 6: 三結論框架入 final report → TL;DR §A/§B/§C [SYNTHETIC]→[MEASURED] → header flip（F7+Q12#9 gate）→ 結案合稿
```

## 已知陷阱（合併版速查；細節在 SESSION-HISTORY）
- `tiup cluster display` GCP 元件顯示 Down = 跨區 probe 假象 → 以 `curl PD:/pd/api/v1/health` 為準
- gate-isolation 重啟整 cluster 偶發 TiKV 2min timeout → `.32` 上 `bash -lc "tiup cluster start tpcc-tidb-vm6 --wait-timeout 300"`（**要 login shell**，否則 tiup 找不到）再重跑
- VM 同 IP 重建 → known_hosts 舊 key 衝突（`accept-new` 不覆蓋衝突 key）→ phase1-wait-via-31 已自動清 Mac+.31；手動 ssh 先 `ssh-keygen -R <ip>`
- kill driver 後 trap 不觸發 → 必手動驗解凍（驗收 #6）
- phase8.5-fetch 整目錄抓取 → fetch 後去重（各 category 只留本輪 TS，勿重命名勿刪舊輪）
- driver log：`.31:/tmp/poc-tpcc/logs/`；套件裝機時間：cloud-init READY 100-390s、W=128 load ~57min、全 suite ~4.5h
- 純 DRY_RUN/失敗輪收尾走 `phase9-tunnels-stop phase9-destroy`（phase9 的 F-Gate 對無 artifact 輪 fail-closed 是預期）

## 異常處置紀律
先抓 log 斷因不盲重跑；最小 diff 修復；每視窗收尾：踩坑進 SESSION-HISTORY（含 hash）、數據進 pipeline-log；
同因兩敗即停，整理現場（log 摘要+判斷）等 user。
