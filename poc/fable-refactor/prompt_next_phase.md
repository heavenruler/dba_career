# 任務：phase-crossregion 接續推進 — 修正 → 驗證 → Wave 4 正式採樣

Repo：/Users/wn.lin/vscode-git/dba_career/poc
角色：執行 operator + coordinator。實際跑指令、盯進度、驗收數據；不要只提建議。
允許 subagent（機械編輯用 haiku、盤點比對用 sonnet、Makefile/shell 手術用預設繼承）；
subagent 一律禁 commit，事後 parent 必驗 `git status`；subagent 的數據宣稱必抽查（一正一反例）。

## 開工必讀（順序）
1. `phase-crossregion/README.md` — Make targets + hard rules
2. `phase-crossregion/SESSION-HISTORY.md` — 「關鍵結論速查」+ 07-02/07-03 章節（14 bugs + iperf3 實測）
3. `poc/fable-refactor/healthcheck-report.md` + `plan.md` + `risks.md` + `decisions.md`（同目錄）（2026-07-06 健檢：20 findings、修復步驟 S1-S8/S2b；R1/R2/iperf3 埠已於 2026-07-07 拍板，見 D9）
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

## 現況（2026-07-08 更新，已驗證）
- **master @ d73cac65**；VM 全拆（iac-idc/iac-gcp state 0）；每 cell 從 `make phase1` 起（Q11）
- **Win-1 TiDB cell 已完成**：`baseline/w128/20260703T092243+0800/` 8/8 驗收（tpmC t128=16,808.6 CV 2.4%、GCP per-round 300/300、WAN probe 80/80）→ pipeline-log §2.3。**不需再跑**
- bug #13（wan-probe IAP→直連）/ bug #14（ALTER→freeze race，pre-freeze operator drain）已修並經 W=1 t16 N=1 驗證輪確認
- **iperf3 埠已改 19999**（棄用 5201/20170）：GCP=phase1 cloud-init 裝 binary（**常駐 daemon 已拆**，
  只剩 ephemeral `iperf3 -s -1 -p 19999`）、IDC=phase2-iperf3-idc target 裝；**19999 埠+binary-only
  未 live 驗證**（需下次 phase1 rebuild 才生效，下輪 warmup-post 首驗 JSON 採樣）
- 專線 FW 認知更正：實測 /24↔/24 整段放行（5201/20170 皆可達）；別再用「埠沒列 fw-request＝被擋」推論
- **Fable 健檢 S1-S8 + M1-M9 全數完成**（見下表 commit hash）；**Path C 全鏈已刪除**；**S9 明確 PENDING**（方案已定案 Q17，延後到 Win-2 prep 才做，不擋 Stage 1/Win-1）
- **CRDB freeze/unfreeze 補接線**（`d73cac65`，07-08 盤點 smoke 前置時發現）：`run-vm6-suite.sh` 原本完全沒呼叫 `freeze-crdb.sh`/`unfreeze-crdb.sh`（比已知的 YBDB 問題更嚴重——YBDB 至少有呼叫）。已比照 YBDB 模式接線，**未 live 驗證**，Stage 1 CRDB smoke 是首次驗證機會
- CRDB/YBDB 的 deploy/suite/teardown 三家化後**未 live 驗證——當作會炸**，先小 W smoke
- **報表採樣落差核對**（對照 `results/x-cross/demo/x-cross-report-demo.md` TL;DR，見 risks R10）：tpmC/p99/error/系統面/WAN/placement 採樣**已足夠支撐 TL;DR §A**；`summary.json` 缺 5 個 schema 欄位（expected_rounds 等）+ DB 內部 queue/lock 指標**仍缺**，但這些是 Wave 6 report 產出前的 framework patch，不擋 Stage 1 smoke

## Stage 0：修正（全數完成，見 fable-refactor/plan.md S1-S8）

**S1-S8 + CRDB freeze 修復全數完成**。逐項對應 commit：

| # | 內容 | commit |
|---|---|---|
| M1 | spike 合入 + IPERF_PORT 統一 19999（實際執行時發現 spike 從未真正合入 master，補做並改用 19999 非原 20170） | `edd6d5b4`（併入 S2+S2b）|
| M2 | cleanup-ybdb.sh 補 VERIFY 段（重寫為 crdb 兩段式結構） | `24a59df5` |
| M3 | freeze/unfreeze-ybdb.sh SSH= 補 accept-new | `24a59df5` |
| M4 | cleanup-{tidb,crdb} =no→accept-new（實際 16 處，非原估 11） | `24a59df5` |
| M5 | run-vm6-suite.sh ybdb 分支改呼叫 freeze/unfreeze-ybdb.sh | `24a59df5`（**live 驗證仍待 YBDB smoke**）|
| M6 | Makefile 補 .PHONY ×6 | `ee3e014f` |
| M7 | 文件勘誤批 + tracked .pyc 移出版控 | `ee3e014f` |
| M8 | 刪除 Path C（含 phase-c-cv-report、.PHONY 清單、phase-smoke-only-* 的 DEPRECATED 提示更新） | `edd6d5b4` |
| M9 | 拆 main.tf iperf3 常駐 daemon | `edd6d5b4`（**19999 埠+binary-only 待下次 phase1 rebuild live 驗**）|
| S8 | P2-1(共用 drain lib)/P2-2/P2-4(hardcode→變數)/R7(check-gcp-via-31 accept-new)/P3-4~6(文件註記) | `ae1a55f8` |
| **新** | **CRDB freeze/unfreeze 補接線**（S8 之後、07-08 盤點時發現） | `d73cac65`（**live 驗證仍待 CRDB smoke**）|

**勿碰**（仍有效）：`sweep-archive.sh` 的 GCP fetch 已在 S4 修（`8195c64d`）；`tests/common/*`、`tfvars/tfstate` 硬規則不變。

**剩餘僅 S9（PENDING，Win-2 prep 才做，見 plan.md）**——Stage 0 對 Stage 1/Win-1 已無阻擋項。

## Stage 1：驗證（現在可以開始——Stage 0 已無阻擋項）
1. 靜態：`bash -n` 全改檔 + `make -C poc -n phase2 phase8.5-fetch TPCC_TS=dummy` 正常展開
2. **CRDB smoke**：W=1 t16 N=1 全鏈（phase1→phase2→phase2-gate→phase3-crdb-deploy→suite→static-check→fetch smoke/early-runs→phase9-tunnels-stop phase9-destroy）。**首次驗證新接的 freeze-crdb.sh/unfreeze-crdb.sh 呼叫**——盯 `[wrapper] pre-run: freeze CRDB...` / `post-run: unfreeze CRDB...` 兩行是否正常輸出、`freeze-state/crdb-lease-rebal-before.tsv` 等 dump 檔是否落地
3. **YBDB smoke**：同上（含 M5 的 freeze idle 確認路徑 live 首驗）
4. smoke 驗收（每家）：`.window.done`、wan-probe per-phase 檔齊（chrony 6 host + netdev + **iperf3 section 首現**：warmup-post 應有 forward/reverse JSON 或明確 skip 行）、summary.json 有值、**freeze/unfreeze 痕跡正確**（CRDB/YBDB 皆須有 freeze-state/ 下的 dump 檔 + log 行，不只 TiDB）、無 failed.txt 非預期項
5. smoke 數據入 `smoke/early-runs/`，commit（`data(x-cross):`），SESSION-HISTORY 記踩坑
6. TiDB 不需重 smoke（鏈已驗）；若 CRDB/YBDB smoke 因框架 bug 失敗：修 → bash -n → rsync .31 → 重跑；同因兩敗即停，整理現場等 user
7. **已知次要缺口，smoke 不會炸但要留意**（見 risks R9）：wrapper 若在 freeze 之後、unfreeze 之前中途崩潰，CRDB/YBDB 會停留凍結狀態（`_suite_failed` trap 只認 TiDB）——smoke 走完整鏈不會踩到，但異常中斷測試時要記得手動跑 unfreeze 或下次 cleanup 會處理

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
1. **【仍待做，07-08 補查加重】** A-A / A-A-RO 無 Makefile 進入點：`run-vm6-aa.sh` 存在但從未接線；GCP 端 client 路徑需走 .31（先驗 FW 涵蓋 .31→GCP client ssh）。**且該檔 header 註解仍寫「GCP client 走 localhost:12215 IAP tunnel」**——接線時要一併改成 via-31 直連（同 wan-probe.sh/sweep-archive.sh 已修的樣板），否則接完線也是壞的。與 #2 命名實作綁一起做。
2. **【已拍板 Q17，剩實作】** artifact 命名納入 PROFILE token：A-S 維持 token-less（既有 cell 不改名、Win-1 零改動）、A-A→`aa`、A-A-RO→`aaro`，插在 placement 與 `rc` 之間。**token 藏 topology 段 → tests/common 三檔零改動**。需改可改檔：`run-vm6-suite.sh:115`、`win-tidb-as-w128.sh:49`(+crdb/ybdb)、`Makefile` ~13 處 ROOT（引入 `PROFILE`→`PROFILE_TOKEN` make-var）、`promotion-gate.sh:45/66`（A-A/A-A-RO 另加檢查）。驗收：A-S 路徑 `make -n` 前後不變、A-A dry-run 出 `-aa-rc-` 目錄、`check-static-artifacts.py` glob 仍中。詳 decisions Q17。
3. **【已拍板 Q16】** 六視窗全矩陣（{P-A,P-B}×{A-S,A-A-RO,A-A}×3家=18 cells）已補 decisions Q16：A-S=主數據候選、A-A/A-A-RO=exploratory-only observed envelope；per-cell rebuild(Q11)、CV R1-R5 mean(Q15)。無需再拍板，照矩陣跑。
4. **【仍待做】** probe driver（`scripts/probe-rto-driver/`，Go 版）未接 Makefile；promotion #7 要 probe-stats.json（Wave 5 前接線設計，planner 審查後才實跑）

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
