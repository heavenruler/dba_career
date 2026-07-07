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

## S4. 【P0-2】sweep-archive.sh 去 IAP（Sonnet 可做，模仿既有樣板）

`scripts/sweep-archive.sh` 的 GCP fetch 段改為 via-31 直連（樣板：`wan-probe.sh` 的 `ssh_gcp`，或 Makefile `phase8.5-fetch` 的 `ssh $(TPCC_CLIENT) ssh root@10.160.152.15` 兩跳法）。刪 `GCP_CLIENT_PORT`/12215 預設。

驗收：
```bash
grep -c '1221[0-9]' poc/phase-crossregion/scripts/sweep-archive.sh   # 0
bash -n poc/phase-crossregion/scripts/sweep-archive.sh
```
（live 驗收待下輪 suite 收檔時實跑一次。）

## S5. 【P0-3 + P1-1 + P1-2 + P1-3】YBDB/cleanup 安全對齊（Sonnet 可做，一步一 commit）

5a. `cleanup-ybdb.sh` 補 VERIFY 段：抄 `cleanup-crdb.sh` 的兩段式結構，verify 內容=確認無 yb-master/yb-tserver 進程。
5b. `freeze/freeze-ybdb.sh` + `unfreeze-ybdb.sh` 的 `SSH=` 變數補 `-o StrictHostKeyChecking=accept-new`。
5c. cleanup-{tidb,crdb,ybdb} 的 `StrictHostKeyChecking=no` 全改 `accept-new`（11 處；行為變化見 risks R6）。
5d. `run-vm6-suite.sh` ybdb 分支（:292/:351）改呼叫 `freeze/freeze-ybdb.sh`/`unfreeze-ybdb.sh`（拿到 idle 確認），刪 inline 版。**此項動 suite 主鏈，需下輪 YBDB smoke 驗證後才可信**。

驗收：
```bash
grep -n 'VERIFY_CMD' poc/phase-crossregion/scripts/cleanup-ybdb.sh          # 有輸出
grep -rn 'StrictHostKeyChecking=no' poc/phase-crossregion/                  # 0 hit
grep -n 'StrictHostKeyChecking' poc/phase-crossregion/freeze/{freeze,unfreeze}-ybdb.sh  # 皆 accept-new
grep -n 'set_load_balancer_enabled' poc/phase-crossregion/scripts/run-vm6-suite.sh      # 只剩經 freeze script 的呼叫
bash -n <各修改檔>
```

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

## 執行順序建議

S1（已完成）→ S3+S6+S7（零風險批，可一次 PR）→ S4 → S5（5d 需等 YBDB smoke 窗口）→ S2（等 R2 拍板）→ S8（最後，量大）。
每個 PR 合併前在 spike/fix branch 上跑該步驗收命令並貼輸出。
