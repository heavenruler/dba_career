# 健檢決策文件 — poc/ (2026-07-06)

> 交接對象：任何後續模型（Opus/Sonnet）。每條決策含理由與被捨棄方案。
> 基準點：master @ `6677bfc9`。

## D1. 「不動的特定模組」具體化

**決策**：邊界白名單解釋為——
- `terraform.tfvars` / `*.tfstate`（正式設定檔，且含密碼，嚴禁讀寫與輸出）
- `tests/common/*.sh`（既有 standing rule：共用庫不動）
- IDC 執行檔（`iac-idc/` 的 tf 與 IDC 端腳本執行語意）
- `results/` 原始數據目錄（artifact 目錄名絕不改）
- master branch（不 commit 到 master；一切變更走 spike branch）

**理由**：goal 只寫「特定模組」沒點名；以上是本專案 CLAUDE.md/歷次會話累積的 standing rules 全集，取聯集最安全。
**捨棄方案**：向使用者追問清單——被 goal 的「不要停下來問我」排除。

## D2. 健檢方法 = 純靜態，不碰 live 環境

**決策**：全程不 ssh .31/GCP、不跑會產生副作用的 make target、不起 VM。
**理由**：健檢目標是「重複與衝突點」——是程式碼/文件層問題，靜態可完整覆蓋；live 操作有費用與環境風險，且與健檢無關。
**捨棄方案**：跑一輪 smoke 驗證全鏈——成本高（VM 費用+小時級時間），且 07-03 已做過等效驗證（SESSION-HISTORY 有記錄）。

## D3. 分工設計

**決策**：5 路平行唯讀 subagent——
| # | 任務 | 模型 | 理由 |
|---|---|---|---|
| A | 語法掃描（bash -n / py_compile / yaml / terraform fmt -check） | Haiku | 純機械 |
| B | Makefile 健檢（重複 target/孤兒/死路徑/CWD 雷） | Sonnet | 需解析 include 語意 |
| C | 重複邏輯掃描（ssh wrapper/poll loop/PD API/teardown） | Sonnet | 需判斷「真重複」 |
| D | doc-code drift（死連結/死 target/埠號陳述過時） | Sonnet | 需交叉比對 |
| E | 硬編碼常數交叉表（IP/埠/cluster 名） | Haiku | 純 grep 統計 |

每個 subagent prompt 內硬規則重複三次（不 commit/不改檔/不 ssh/不碰 tfvars），完成後自附 `git status --short` 證明；本體再獨立驗證一次 git status（過去有 subagent 無視 no-commit 的前科）。
**捨棄方案**：單一大 agent 全掃——context 塞爆且無法平行；Workflow 編排——任務只有一層 fan-out，Agent 工具即足。

## D4. 修復不在本輪做，只產出計畫（除 spike POC 外）

**決策**：健檢輪只「發現+分級+計畫」；實際修復留待 plan.md 逐步執行。唯一例外：挑 1–2 個低風險、已被 07-03 live 實測直接證偽的項目在 spike branch 做 POC 修復（示範修法與驗法）。
**理由**：goal 驗收要求「每項可獨立驗證」——批量修復會讓驗證面爆炸；且「不順手重構無關程式」的紅線要求最小動作。
**捨棄方案**：發現即修——違反紀律邊界。

## D5. 掃描 E（Haiku 常數交叉表）——中途版棄用、最終版採信

**決策**：E 的**中途摘要**（宣稱 20170/gproxy 零使用）棄用；E 的**最終交叉表**（自我修正後）採信並納入報告。
**理由**：中途版兩條宣稱被本體抽查證偽；最終版與本體抽查（wan-probe.sh 20170 ×3、main.tf gproxy）及掃描 C/D 的交集全部吻合，且附可重現 grep 命令。
**捨棄方案**：整份棄用——最終版有 C/D 沒有的增量（舊 IP 殘留 .25/.17、HAProxy 三套入口值、ConnectTimeout 全分佈 57/14/2/1）。
**教訓（交接必讀）**：便宜模型的「中途進度回報」不可當結論；只認附重現命令且被抽查通過的最終版。所有 subagent 數據宣稱需本體抽查至少一正一反例。

## D6. Severity 分級模型

**決策**：P0=會壞執行（跑了會炸或靜默假成功）→ P1=安全/數據效度 → P2=重複邏輯（同步改會漏）→ P3=文件/衛生。修復順序照此，P3 允許批量文字修正。
**理由**：本專案是量測管線，「靜默假成功」比 crash 更毒（污染數據）；fail-open 一律視為 P0/P1。
**捨棄方案**：按檔案模組分組修——會把高低風險混在一個 PR，驗收困難。

## D7. Spike POC 選擇

**決策**：spike branch `spike/healthcheck-poc` 只做兩個 POC 修復示範：
- POC-1：`wan-probe.sh` 行 26/245 錯誤前提註解修正（「5201 未開通」→ 實測可達、20170 為避免佔用 TiKV range 內既定選擇）
- POC-2：`idc-iperf3-bootstrap.sh` `IPERF_PORT` 預設 5201→20170（與 wan-probe.sh 對齊）

**理由**：兩者都（a）被 07-03 live 實測直接支撐、(b) 單檔小改、(c) 有現成驗證器（`bash -n` + `--dry-run`）、(d) 檔案本身非「不動清單」成員且本 session 已改過（授權慣性成立）。作為示範，能展示「修法+驗法」樣板供後續模型照抄。
**捨棄方案**：POC 修 FAIL-1（Path C）——動 Makefile 核心編排，需 live 驗證才能收，超出 spike 安全界線；修 main.tf 5201 daemon——正式 IaC，需使用者拍板架構方向（見 risks）。

## D8. 明確「不修」清單（防越界）

| 項目 | 為何不修 |
|---|---|
| F8 prepare/run-all 32 檔鏡像 | 有意設計（準備/執行分離）；重構=無被要求的功能變更 |
| F9 log 函式不共用 | 屬風格統一，非錯誤；「不順手重構無關程式」紅線 |
| tests/common/* 任何內容 | 不動清單成員（即使 F3 涉及 dry-run-confirm.sh） |
| iac-gcp/main.tf 5201 daemon（A1） | 正式 IaC + 架構決策（常駐 vs 臨時 server 二選一）須使用者拍板 |
| results/ 內 md 的歷史段落 | 數據紀錄的歷史陳述不回改，只在最新段落勘誤（pipeline-log §4 例外，見 plan S6，因它是「現況陳述」非歷史） |
| Makefile.tc1 / tunnel.sh | legacy 工具，phase9-tunnels-stop 仍引用 tunnel.sh；刪除涉及執行路徑確認 |
