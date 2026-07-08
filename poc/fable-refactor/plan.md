# 修復執行計畫 — poc/ 健檢（2026-07-06）

> 粒度：每步可由 Opus/Sonnet 獨立照做，含精確位置、修法、驗收命令。
> 全程規則：**絕不 commit 到 master**（一律 spike/fix branch）；不動 `tests/common/*`、`terraform.tfvars`、`*.tfstate`；commit 用 `git commit -F <msgfile>`（RTK 會改寫 `-m`）；每步修完跑該步驗收 + `git status --short` 確認只動了預期檔案。
> 依據：finding 編號對應 `healthcheck-report.md`；決策依據見 `decisions.md`；動手前讀 `risks.md`。

## S1. 【已做，spike branch】POC 示範：iperf3 註解與埠對齊（P3-1 部分 + P2-3）

分支 `spike/healthcheck-poc`（見報告尾註）。內容：
- `phase-crossregion/scripts/wan-probe.sh:26,245`：註解改為「20170 = R8 range 內既定閒置埠；5201 實測亦可達（2026-07-03，SESSION-HISTORY 勘誤），非改埠原因」
- `phase-crossregion/scripts/idc-iperf3-bootstrap.sh`：`IPERF_PORT` 預設 5201→20170，header 註解同步

驗收：
```bash
bash -n poc/phase-crossregion/scripts/wan-probe.sh poc/phase-crossregion/scripts/idc-iperf3-bootstrap.sh
bash poc/phase-crossregion/scripts/idc-iperf3-bootstrap.sh --dry-run | grep 'port=20170'
grep -c '未開通' poc/phase-crossregion/scripts/wan-probe.sh   # 預期 0
```

## S2. 【P0-1】Path C **刪除**（R2 已拍板 2026-07-07 = 廢，見 decisions D9）

刪 `phase-warmup-only-{tidb,crdb,ybdb}`、`phase-roundrun-only-*`、Path C orchestrator（Makefile:1268 一帶）、`run-round-only.sh`；README/SESSION-HISTORY 若有提及一併清。最小 diff、單獨 commit。

驗收：`grep -rn 'run-round-only\|warmup-only\|roundrun-only' poc/ --include=Makefile --include='*.md' | grep -v results/ | grep -v '\.bak'` 為空；`make -C poc -n phase-crossregion-w128-suite`（或現行正式 target）仍正常展開（確認沒誤刪正式路徑依賴）。

## S2b. 【R1 已拍板】拆 main.tf iperf3 常駐 daemon + 埠統一 19999（見 decisions D9）

- `iac-gcp/main.tf:122-139`：刪 `iperf3-server.service` 常駐段（`systemctl enable --now iperf3-server` 那整塊）；**保留** cloud-init 的 iperf3 binary 安裝（dnf 那行不動）。
- 埠 19999 統一：`wan-probe.sh`（IPERF_PORT 預設 + header 註，spike 原寫 20170）、`idc-iperf3-bootstrap.sh`（IPERF_PORT 預設）改 19999。
- 注意：這是正式 IaC 變更，下次 phase1 rebuild 生效；本項與 S1 的 spike 合入合併處理（見 M1 備註）。

驗收：
```bash
grep -c 'iperf3-server.service\|enable --now iperf3-server' poc/iac-gcp/main.tf   # 0
grep -c 'iperf3' poc/iac-gcp/main.tf                                              # >0（binary 安裝still在）
grep -rn 'IPERF_PORT' poc/phase-crossregion/scripts/{wan-probe,idc-iperf3-bootstrap}.sh | grep 19999
grep -c '20170\|5201' poc/phase-crossregion/scripts/wan-probe.sh                  # 僅剩勘誤性提及（見 header 註）
```

## S3. 【P1-5 + B 全部】.PHONY 補宣告（Sonnet/Haiku 可做）

`phase-crossregion/Makefile` 為以下 6 個 target 補 .PHONY（加入既有 .PHONY 行或新開一行）：
`phase8.5-fetch`、`phase-cleanup-tidb`、`phase-cleanup-crdb`、`phase-cleanup-ybdb`、`phase2-iperf3-idc`、`phase0-preflight-fix-only-processes`

驗收：
```bash
for t in phase8.5-fetch phase-cleanup-tidb phase-cleanup-crdb phase-cleanup-ybdb phase2-iperf3-idc phase0-preflight-fix-only-processes; do
  grep -l "\.PHONY.*$t" poc/phase-crossregion/Makefile >/dev/null && echo "OK $t" || echo "MISS $t"
done
# 行為不變檢查：修改前後各跑一次，diff 必須為空
make -C poc -n phase8.5-fetch TPCC_TS=dummy > /tmp/before.txt 2>&1  # （修改前先存）
```

## S4. 【已完成，fix/sweep-archive-via31 @ 8195c64d】sweep-archive.sh 去 IAP（P0-2）

`scripts/sweep-archive.sh` 跑在 Mac（非 .31，本身還做本機 terraform destroy），故非 wan-probe.sh 的單跳 `ssh_gcp`（那是跑在 .31 上），而是比照 **Mac 側既有 ProxyJump 樣板**（`check-homogeneity.sh` / `gate-chrony-cross-region.sh`）：`ssh -o ProxyJump=root@172.24.40.31 root@10.160.152.15`。新增 `JUMP_HOST`/`GCP_CLIENT_HOST` env，移除 `GCP_CLIENT_PORT`(12215)/`GCP_CLIENT_SSH_KEY`。

驗收（已過）：`bash -n` PASS；`grep 1221x` = 0；合成 `.suite.done` 資料跑 `--dry-run` 全 7 步 PASS，rsync 命令實際印出正確走 ProxyJump→10.160.152.15。
（live 驗收待下輪真實 sweep 收檔時實跑一次——這是 150h sweep 收尾腳本，目前尚無對應 live 窗口。）

## S5. 【已完成，fix/s5-ybdb-safety @ 24a59df5】YBDB/cleanup 安全對齊（P0-3+P1-1+P1-2+P1-3）

5a. `cleanup-ybdb.sh` 重寫為 `cleanup-crdb.sh` 兩段式結構（CLEANUP_CMD+VERIFY_CMD），補 VERIFY（確認無 yb-master/yb-tserver 進程）；順帶消掉舊版 GCP 側巢狀引號的脆弱 inline 命令。
5b. `freeze/freeze-ybdb.sh` + `unfreeze-ybdb.sh` 的 `SSH=` 補 `-o StrictHostKeyChecking=accept-new`（已完成）。
5c. cleanup-{tidb,crdb}.sh 的 `StrictHostKeyChecking=no`（實際 16 處，非原估 11）全改 `accept-new`；ybdb 新版直接寫 accept-new（行為變化見 risks R6）。
5d. `run-vm6-suite.sh` ybdb 分支改呼叫 `freeze/freeze-ybdb.sh`/`unfreeze-ybdb.sh`（拿到 idle 確認）：freeze 保持無 `|| true`（fail-closed，同 TiDB FREEZE_SCRIPT）、unfreeze 保持 `|| true`（best-effort）。**未 live 驗證**（需下輪 YBDB smoke 視窗）。

驗收（已過）：`grep VERIFY_CMD` 有輸出；`grep StrictHostKeyChecking=no` 於 cleanup 三檔 = 0；freeze/unfreeze-ybdb.sh 皆 accept-new；`set_load_balancer_enabled` 只剩 freeze/unfreeze script 內；`bash -n` 全過；CLEANUP_CMD/VERIFY_CMD 字串抽出後額外做語法+本機功能驗證（VERIFY_CMD 乾淨機器印 OK exit=0）。

**意外發現（範圍外，未修）**：`check-gcp-via-31.sh` 亦有 2 處 `StrictHostKeyChecking=no`，不在原 P1-3 finding 點名清單（只列 cleanup-{tidb,crdb,ybdb}）。留待未來收斂批次處理，不在此次擴大範圍。

## S6. 【P3-1 + P3-2】文件矛盾勘誤（Haiku 可做，純文字）

6a. `SESSION-HISTORY.md:64` 該段句尾加註「（07-03 勘誤：5201 實測可達，見文末 2026-07-03 節）」——不刪原文（歷史紀錄），只加指標。
6b. `results/x-cross/pipeline-log.md` §4:91「目前沒有 summary.json」改為「determinism（06-26 retrofit）與 baseline/w128（07-03）已有 summary.json；更早期資料點仍無」。§7 變更紀錄加一行。

驗收：
```bash
grep -n '勘誤' poc/phase-crossregion/SESSION-HISTORY.md | head -3
grep -n '目前沒有 summary.json' poc/results/x-cross/pipeline-log.md   # 0 hit
```

## S7. 【P3-3】tracked .pyc 移出版控（Haiku 可做）

```bash
git rm -r --cached poc/tpmc-report/__pycache__/
echo '__pycache__/' >> poc/tpmc-report/.gitignore   # 或 repo 根 .gitignore，先查有無既有規則
```
驗收：`git ls-files '*.pyc'` 為空；`git status --short` 顯示預期的 D + .gitignore 修改。

## S8. 【P2-1 P2-2 P2-4 P2-5 + P3-4~7】收斂與清理（合併一個 PR，Opus 判讀 + Sonnet 執行）

- P2-1：`run-vm6-suite.sh` 的 drain 段改呼叫 `freeze-tidb.sh` 已有的 drain（或抽成 `freeze/lib-pd-drain.sh` 供兩者 source）；統一超時語義（建議取 300s）
- P2-2：`tidb-vm6.yml:373` hardcode `"3"` 改 `{{ tidb_replicas }}`（vars 檔已有此變數；確認 p-a/p-b vars 值皆 3）
- P2-4：兩 playbook 的 cluster name/host 抽到 vars（`tidb_cluster_name` 已在 vars？先查，有就引用）
- P2-5：SSH wrapper 統一——**不強推**（詳 D8 邊界精神）；僅將無 StrictHostKeyChecking 的補上（已含 S5b）
- P3-4：README 補一句說明 .sh 與 Go 版 probe-rto-driver 的取捨；P3-5/P3-6/P3-7：過時註解與 legacy 標註（只加 DEPRECATED 註記，不刪檔）

驗收：每項附於 PR 描述；共通：`bash -n` 全過、`ansible-playbook --syntax-check`（若環境可用，否則標未驗證）、`make -n` 前後 diff 為空（除預期變更）。

## S9. 【Win-2 prep，Q17 已拍板】PROFILE token 命名實作（與 Win-2 gap#1 A-A 接線綁做）

方案定案見 decisions Q17：A-S token-less（不變）、A-A→`-aa-`、A-A-RO→`-aaro-`，插在 placement 與 `rc` 之間；token 藏 topology 段 → **tests/common 三檔（common.sh/run.sh/summary-from-stdout.py）零改動**。

做法（皆可改檔）：
1. 引入 `PROFILE` make-var（`PROFILE ?= A-S`）+ 派生 `PROFILE_TOKEN`（A-S→空、A-A→`-aa`、A-A-RO→`-aaro`）。
2. Makefile ~13 處 `{db}-vm-6node-$(PLACEMENT)-$(ISO)-$(TPCC_TS)` → 插入 `$(PROFILE_TOKEN)`（placement 與 ISO 之間）。清單見 decisions Q17 觸點 + 觸點 agent 報告（phase6/7/8 smoke+result、win-*-status、smoke-only×3 已 DEPRECATED 可略）。
3. `run-vm6-suite.sh:115`、`win-tidb-as-w128.sh:49`(+crdb/ybdb 對應)：同樣依 PROFILE 派生 token 插入 ROOT。
4. `promotion-gate.sh`：現行 #1/#2 glob（`P-A-rc-*`/`P-B-rc-*`）針對 A-S/P-B baseline **不動**；A-A/A-A-RO 若要納入 promotion 另加對應 glob。

驗收：
```bash
# A-S 零迴歸：改前後 make -n 輸出 diff 為空
make -C poc -n win-tidb-as-status PLACEMENT=P-A TPCC_TS=dummy > /tmp/as-before.txt   # 改前存
# A-A 生效：
make -C poc -n <aa-target> PLACEMENT=P-A PROFILE=A-A TPCC_TS=dummy | grep -- '-aa-rc-'
bash -n phase-crossregion/scripts/{run-vm6-suite,win-tidb-as-w128}.sh
# tests/common 未被碰：
git status --short | grep tests/common   # 必須為空
```
**綁做**：與 Win-2 gap#1（`run-vm6-aa.sh` 接 Makefile）同一 PR；先驗 FW 涵蓋 .31→GCP client SSH（A-A 雙 client 前置）。

## 執行順序建議

S1（已完成 2591f33e）→ S3+S6+S7（已完成 ee3e014f）→ S4（已完成 8195c64d）→ S5（已完成 24a59df5，5d 待 YBDB smoke live 驗）→ **S2+S2b（下一步：Path C 刪除 + main.tf 拆 daemon，R1/R2 已拍板）** → S8（收斂清理）→ S9（Win-1 三家 A-S 跑完、進 Win-2 前）。
每個 PR 合併前在 spike/fix branch 上跑該步驗收命令並貼輸出。
