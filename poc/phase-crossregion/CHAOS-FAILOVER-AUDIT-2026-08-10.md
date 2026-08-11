# Chaos/Failover 稽核回應報告（2026-08-10）

> 稽核來源：Codex 提供的 `/tmp/chaos_recommand` prompt，針對
> [`XCROSS-CHAOS-FAILOVER-3DB-COMPARISON.md`](./XCROSS-CHAOS-FAILOVER-3DB-COMPARISON.md)
> 與其引用的 6 份 `results/x-cross/chaos/*-SUMMARY.md`、`DISTRIBUTED-DB-SCORING.md` 第 6 項提出
> 10 項 Critical Findings（F-001～F-010）。本報告是對該稽核的**獨立驗證**回應——每一項先用
> raw evidence（`probe.txt`、`rto-rpo.json`、`write-reject-validation.txt`、腳本原始碼）核實，
> 屬實才修正/撤回，證據不足或推論過度則駁回或降級，不照單全收。
>
> 本次稽核**未重跑任何 chaos 注入、未 SSH 到任何 VM、未 push、未 commit**；
> `results/x-cross/chaos/**` 下的既有 raw artifact 全程只讀，`debug.log`（untracked、空檔）未觸碰。

## 1. 結論（Verdict）

**Codex 的核心發現成立，但補救範圍的一部分被判定超出目前可驗證/可安全執行的範圍而駁回或延後。**

- CockroachDB、YugabyteDB 全部 8 組 F1/C4 RTO 數字（各 DB×2 placement×4 情境）**已確認無效**
  （`outage_observed=false`），已撤回，非「數字偏保守」而是「探測從未觀測到中斷」。
- TiDB 15/16 組 F1/C4 數字**維持有效**（探測皆記錄到真實 post-incident error），1 組已知無效
  （檔名自帶 `-INVALID-not-haproxy-backend` 標記，稽核前即已知）。
- C1（partition）在非 TiDB 環境下的探測完全打錯資料庫端口，**F-008 成立**，已修正腳本並撤回
  相關「6/6 無影響」宣稱。
- C7（disk-slow）「3 DB 皆無感」的宣稱**證據力不足**（fail-fast 缺失、iostat 檔名/欄位語意疑
  義未核實），已降級為觀察而非結論，並修正腳本的 fail-fast 缺陷（F-009 部分）。
- F2（IDC 全滅）的復原時間數字**基本可信**，但 write-reject 分類有誤（CockroachDB 的
  `ERROR: result is ambiguous` 被誤判為乾淨拒絕），已修正分類邏輯並重新分類歷史結果（F-006）。
- Codex 要求的**大型架構重寫**（per-DB role resolver、sentinel-key FIFO RPO、雙側 C1 探測、
  trap-based idempotent restore 全套、C7 從頭重設計）**全部延後、不在本次執行**——理由見
  §6，這些變更需要真實環境測試才能信任，而本次規則明確禁止重跑/SSH。

## 2. Critical Findings 處理結果

| # | Codex 發現 | 驗證方式 | 結論 | 處置 |
|---|---|---|---|---|
| F-001 | `outage_observed` 語意混淆：probe 下一次排程 tick vs 真實觀測到失敗 | 逐一 grep 全部 32 個 F1/C4 `probe.txt` 的 err 計數 | **成立**，且範圍比 Codex 舉例的更廣（CRDB 8/8、YBDB 8/8 全部無效） | 已修正 `wall-clock-wrapper.sh`；已撤回 16 組數字（見 §3 矩陣） |
| F-002 | probe 週期非固定 100ms，實際依 DB 起伏 | 讀 `probe-rto-driver.sh` 起訖時間戳 | **成立**（CRDB 均 80ms／YBDB 均 536ms／TiDB 均 220ms+一次 3.12s 尖峰） | 記錄為已知限制；**駁回**「合併 Bash/Go 兩份 probe driver」的重寫要求——現有 Bash 版本語意已修正且可信，重寫需要新環境驗證，風險大於效益 |
| F-003 | leader/follower 角色判定無 hard-fail 驗證 | 讀 `run-vm6-chaos-execute.sh` 的 `LEADER_QUERY`/`S_PRE_QUERY` 邏輯 | **成立**（YBDB P-A F1-leader 的「master LEADER」標籤已證實寫錯，見 SUMMARY 修正） | 已於對應 SUMMARY.md 更正標籤；**駁回**「建置 `role-evidence.json` + per-DB resolver」全套框架——單一已知的人工標記錯誤不足以證成一個新子系統，且無法在不重跑的前提下驗證新 resolver 的正確性 |
| F-004 | F1 graceful-kill 計時基準不對稱（TiDB/YBDB 在 t_incident 前 resign，CRDB 在之後 drain） | 讀 3 家的 KILL_CMD 實作與 t_incident 打點順序 | **成立** | 已在比較報告加註「跨 DB graceful/ungraceful 對照方法論不成立」；**駁回**「重新設計 F1 使三家計時基準對齊」——這需要更動已收集數據的定義本身，且要重跑才能驗證新設計是否真的對齊 |
| F-005 | 未記錄探測的真實來源（client-origin），「GCP 端體感」的敘述無佐證 | 讀 `probe-rto-driver.sh` 啟動位置：`nohup bash ... &` 從 `.31`（IDC 子網）內起 | **成立** | 已在比較報告移除/修正「GCP-side client experience」措辭；**駁回**「探測加 route-trace 佐證」——屬新增量測能力，需重跑 |
| F-006 | RPO「=0」宣稱不可靠；CRDB ambiguous-write 被誤判為乾淨拒絕 | grep 全部 CRDB F2 `write-reject-validation.txt`，兩個 placement 皆含 `ambiguous` | **成立** | 已修正 `run-vm6-f2-idc-death-execute.sh`（INSERT/DELETE 拆分 + 三態判定：ambiguous/rejected/unexpected-success）；已重新分類兩個 CRDB F2 結果為 `ambiguous_result_manual_review_required`；**駁回**「sentinel-key ack-backed FIFO RPO 全套重測框架」——現有 high-water-mark 量測本身標明是簡化版，修正誤判已解決本次最嚴重的分類錯誤，完整 FIFO 框架需重跑且工作量遠超本次稽核範圍 |
| F-007 | F2 精度不一致（health 確認與 write 確認之間有未量測窗口） | 逐一算 6 組 run 的 `t_all_idc_healthy` 到 `t_first_write_ok` 秒差 | **部分成立，且發現新現象**：YBDB 兩個 placement 皆同一 poll 確認（緊密）、CRDB P-B 緊密／P-A 有 5.8s 窗口、**TiDB 兩個 placement 皆有 38.9~44.1s 的巨大窗口**（storage healthy 極快但 SQL 層可寫慢很多，此前未被記錄） | 已在比較報告加入精度分級表；**駁回** Codex「YBDB 3.05s/3.2s 因小於一個 poll bucket 故不精確」的子論點——實測 YBDB 兩次都在 poll=1 即確認，不存在 bucketing 效應，此子論點與數據不符 |
| F-008 | C1 探測腳本沒有 `--db` 參數，非 TiDB 環境誤測 TiDB MySQL 端口 | 讀 `chaos-c1-partition-execute.sh` 原始碼，確認硬編碼 `-P 4000` mysql 探測 | **成立** | 已修正腳本（加 `--db tidb\|crdb\|ybdb` + per-DB 探測指令）；已撤回 CRDB/YBDB 的「C1 6/6 無影響」宣稱（改標記為方法論失效，非結論） |
| F-009 | C7 未 fail-fast；`FIO_OK=false` 仍以 exit 0 結束 | 讀完整 `chaos-c7-disk-slow-execute.sh`，確認 `set -uo pipefail`（無 `-e`）且原本 `FIO_OK=0` 分支只 log WARN、寫 `plan.txt`、無 `exit` | **成立**（本次稽核期間自行完整追蹤到腳本結尾確認） | 已修正：`FIO_OK≠1` 且非 dry-run 時，寫完 `plan.txt` 後 `exit 1`；`bash -n` 驗證語法正確；**駁回**「C7 從頭重設計（no-injection 對照組、pre/during/post DB 指標、baseline I/O）」——這是全新的量測設計，需要重跑且工作量等同重新做一輪測試，非本次稽核範圍 |
| F-010 | `run-vm6-chaos-execute.sh`/`run-vm6-f2-idc-death-execute.sh` 缺 idempotent restore（trap-based，含 pre/postcondition JSON） | 讀兩份腳本目前的 restore 邏輯 | **成立**（目前無結構化 pre/postcondition 記錄） | **駁回**——這是流程健壯性強化，非本次數據有效性問題；在無法重跑驗證新 trap 邏輯是否正確的前提下貿然改寫核心執行腳本風險高於效益，列為下一輪重測前的待辦（見 §5） |

## 3. F1/C4 `outage_observed` 完整矩陣（F-001，全部 32 個 probe.txt 逐一驗證）

| DB | Placement | 情境 | ok | err | outage_observed | 數字狀態 |
|---|---|---|---|---|---|---|
| CRDB | P-A | F1-leader | 887 | 0 | false | 撤回 |
| CRDB | P-A | F1-follower | 972 | 0 | false | 撤回 |
| CRDB | P-A | C4-leader | 505 | 0 | false | 撤回 |
| CRDB | P-A | C4-follower | 489 | 0 | false | 撤回 |
| CRDB | P-B | F1-leader | 502 | 0 | false | 撤回 |
| CRDB | P-B | F1-follower | 508 | 0 | false | 撤回 |
| CRDB | P-B | C4-leader | 508 | 0 | false | 撤回 |
| CRDB | P-B | C4-follower | 504 | 0 | false | 撤回 |
| YBDB | P-A | F1-leader | 122 | 0 | false | 撤回 |
| YBDB | P-A | F1-follower | 127 | 0 | false | 撤回 |
| YBDB | P-A | C4-leader | 109 | 0 | false | 撤回 |
| YBDB | P-A | C4-follower | 124 | 0 | false | 撤回 |
| YBDB | P-B | F1-leader | 108 | 0 | false | 撤回 |
| YBDB | P-B | F1-follower | 117 | 0 | false | 撤回 |
| YBDB | P-B | C4-leader | 109 | 0 | false | 撤回 |
| YBDB | P-B | C4-follower | 117 | 0 | false | 撤回 |
| TiDB | P-A | F1-leader (tikv) | 244 | 2 | true | 維持有效（6.934s） |
| TiDB | P-A | F1-leader (tikvpd) | 160 | 2 | true | 維持有效 |
| TiDB | P-A | F1-follower (tikv) | 174 | 2 | true | 維持有效 |
| TiDB | P-A | F1-follower (tikvpd) | 161 | 2 | true | 維持有效 |
| TiDB | P-A | C4-leader (tikv) | 243 | 2 | true | 維持有效 |
| TiDB | P-A | C4-leader (tikvpd) | 154 | 2 | true | 維持有效 |
| TiDB | P-A | C4-follower (tikv) | 178 | 0 | false | 撤回（本組唯一 TiDB 無效） |
| TiDB | P-A | C4-follower (tikvpd) | 149 | 2 | true | 維持有效 |
| TiDB | P-A | C4-leader (tikv, INVALID) | 176 | 0 | false | 稽核前已知無效（檔名自帶標記，非 haproxy backend） |
| TiDB | P-B | F1-leader (tikv) | 227 | 2 | true | 維持有效 |
| TiDB | P-B | F1-leader (tikvpd) | 170 | 2 | true | 維持有效 |
| TiDB | P-B | F1-follower (tikv) | 192 | 2 | true | 維持有效（4.180s outlier，err=2 為真實觀測，成因仍待查） |
| TiDB | P-B | F1-follower (tikvpd) | 266 | 2 | true | 維持有效 |
| TiDB | P-B | C4-leader (tikv) | 112 | 2 | true | 維持有效 |
| TiDB | P-B | C4-leader (tikvpd) | 95 | 2 | true | 維持有效 |
| TiDB | P-B | C4-follower (tikv) | 171 | 3 | true | 維持有效 |
| TiDB | P-B | C4-follower (tikvpd) | 147 | 2 | true | 維持有效 |

**總計**：CRDB 8/8 無效、YBDB 8/8 無效、TiDB 15/16 有效（含 1 組本稽核新發現無效 + 1 組稽核前已知無效，另有 1 組 TiDB 有效但異常慢的 outlier 尚未解釋成因）。

## 4. 可引用結論（Codex 問題 1）

- TiDB F1/C4 全部 15 組有效 RTO 數字（P-A/P-B 各 7~8 組，見 §3）。
- F2（三 DB 皆有）的復原時間數字：TiDB（44.1s/38.9s 兩段 write-gap，本身即新發現）、
  YBDB（≈3.05s/3.2s，兩 placement 精度皆緊密）、CRDB（≈12.95s P-A 精度較粗/≈7.21s P-B 精度緊密）。
- YBDB master 執行緒暴增 bug（`.34` NLWP 1147）：獨立於探測方法論問題之外，直接查證屬實。
- `go-tpc` 對 CRDB 容錯度偏低（累積錯誤後提前 Finished）：屬工具行為觀察，非探測數字，不受
  F-001 影響。
- TiDB storage-healthy 與 SQL-write-ready 之間 38.9~44.1s 的落差：本次稽核新發現，兩個 placement
  獨立重現，可信。

## 5. 僅為執行證據、不構成跨 DB 結論（Codex 問題 2）

- C7「3 DB 皆無感」：僅代表「這次注入沒讓 DB 掛掉」，不代表「無延遲影響」——`fio_launch_ok`
  未經 fail-fast 保護（已修正）、iostat 欄位是否真的反映 DB 進程延遲未逐一核對。
- C1「6/6 復原」：僅 TiDB 環境的探測是打對端口的；CRDB/YBDB 環境的「6/6」只證明 partition
  30 秒後网络自動恢復，未證明應用層在 partition 期間真的被正確阻斷/事後正確復原。
- F2 write-reject 對 TiDB/YBDB 的「乾淨拒絕」判定：判定邏輯本身沒錯（`PD server timeout`／
  `psql: timeout expired` 確實不含 ambiguous 語意），但這只是「探測腳本沒有誤判」的證據，不能
  過度推廣為「TiDB/YBDB 一致乾淨拒絕、CRDB 保守」這種效能對比結論——三者的底層一致性保證機制
  不同，錯誤訊息只反映各自的逾時/協定實作細節。

## 6. 已撤回／降級結論（Codex 問題 3）

**已撤回（證據基礎不成立）**：
1. CRDB/YBDB 全部 16 組 F1/C4 RTO 數字，以及建立在其上的所有「graceful vs ungraceful」
   「leader vs follower」「pin vs 不 pin」比較敘述。
2. YBDB P-B「殺真實 tablet 資料 leader 導致 RTO 變慢 10 倍」的因果推論（原「重大發現」，
   master 執行緒暴增 bug 本身維持成立，未撤回）。
3. CRDB「graceful drain 對 range lease 復原幫助有限」（建立在已撤回的 0.035s/0.100s 對比上）。
4. CRDB/YBDB 環境的 C1「partition 期間/之後行為正常」宣稱（探測打錯端口）。

**已降級（原本語氣過強，現改為附條件的方向性觀察）**：
1. C7「3 DB 對磁碟競爭無感」→ 降級為「本次注入未觀察到明顯異常，但驗證深度不足以排除影響」。
2. F2 跨 DB 復原時間排名（TiDB 最慢／YBDB 最快／CRDB 居中，且 P-A/P-B 內部相對順序一致）→
   維持排名本身（因 F2 復原時間不受 F-001 影響），但拿掉「信心最高的跨 DB 結論」這種強語氣，
   改為「中等信心的方向性觀察」，因為每個 DB 只各測 2 次（各 placement 1 次），樣本量小。

## 7. 程式修改（本次已完成，皆為 `bash -n` 驗證過語法且非破壞性的最小修正）

| 檔案 | 修改內容 | 對應 Finding |
|---|---|---|
| `phase-crossregion/scripts/wall-clock-wrapper.sh` | `stamp-first-ok`/`compute-rto` 加入 `outage_observed` 判定：post-incident err=0 時明確標記 `RTO not applicable`，不再默默套用 fallback 邏輯產生假數字 | F-001 |
| `phase-crossregion/scripts/chaos/chaos-c1-partition-execute.sh` | 新增必填 `--db tidb\|crdb\|ybdb`，依 DB 切換探測指令（原為硬編碼 TiDB MySQL 探測） | F-008 |
| `phase-crossregion/scripts/run-vm6-f2-idc-death-execute.sh` | INSERT/DELETE 探測拆分；write-reject 判定改三態（`ambiguous_result_manual_review_required` / `write_correctly_rejected` / `UNEXPECTED_WRITE_SUCCEEDED_review_manually`），修正 CRDB ambiguous 誤判 | F-006 |
| `phase-crossregion/scripts/chaos/chaos-c7-disk-slow-execute.sh` | `FIO_OK≠1` 且非 dry-run 時，寫完 `plan.txt` 後 `exit 1`（原本無條件 exit 0） | F-009 |

## 8. 文件修改（本次已完成）

- `phase-crossregion/XCROSS-CHAOS-FAILOVER-3DB-COMPARISON.md`：§2/§3（F1/C4）、§4（C1）、§5（C7）、
  §6（F2）、§7/§8（結論）、§9（bug 表新增 #15-24）、§10（下一步）全面改寫，加入本次稽核通知。
- 6 份 `results/x-cross/chaos/*-SUMMARY.md`：各自加上稽核修正註記，撤回/更正對應數字與敘述
  （YBDB P-A 的 kill-target 角色標籤錯誤同步修正）。
- `DISTRIBUTED-DB-SCORING.md`：第 6 項星等與加權總分撤回為「待重測」，§3.3 改寫為條件式敘述，
  §4/§5 回復到未含第 6 項的原始版本並加註稽核教訓。

## 9. 驗證結果（本次執行的 §6 檢查子集）

```
bash -n（4 份修改過的腳本）→ 全部 OK
jq empty（37 份 rto-rpo.json）→ 全部 OK
git status --short → 12 份既有檔案 modified，1 份 debug.log untracked（未觸碰、未加入 commit 範圍）
git diff --stat → 12 files changed, 669 insertions(+), 409 deletions(-)
stale phrase 掃描（planner-only/尚未實跑/信心最高/Failover 表現最佳）→ 僅出現在「已撤回此語氣」
  的說明句中，無殘留誤導文字
```

未執行（超出本次安全範圍或無對應環境）：`shellcheck`（本機未裝）、`go test`/`go vet`
（probe-rto-driver 的 Go 實作本次未變更，且 F-002 的合併重寫已駁回）、
`python3 results/verify-readme-links.py`（本次新增的檔案間互相引用已人工核對，見 §8 清單）。

## 10. 下一輪最小重測矩陣

| 環境 | 需重測情境 | 原因 |
|---|---|---|
| CockroachDB P-A / P-B | F1-leader/follower、C4-leader/follower、C1 | probe 方法論失效，目前 0 筆有效數字 |
| YugabyteDB P-A / P-B | F1-leader/follower、C4-leader/follower、C1 | 同上 |
| TiDB P-A / P-B | 無需重跑 F1/C4（15/16 已有效）；C1 若要正式列入比較才需補測（此前從未對非 TiDB 目標測過，TiDB 自己的 C1 探測端口原本就正確） | — |
| 全部 3 DB × 2 placement | C7 | 現有腳本已加 fail-fast，但「無感」結論仍需搭配 DB 端指標（例如 commit latency p99）才能升級為可信結論，非僅靠 fail-fast 修正 |

**是否已具備重測條件（Codex 問題 4）**：腳本層面已具備（3 項修正皆已 `bash -n` 驗證），但**尚未
在真實環境跑過一次驗證新邏輯**（例如故意讓 fio 失敗來確認 C7 exit 1、故意在 partition 情境送
CRDB/YBDB `--db` 參數確認探測連得上）。建議重測前**先跑一次乾跑（dry-run）+ 一次小規模真實驗證
（例如僅對 1 個環境跑 1 個情境）**，確認 3 支修改過的腳本行為符合預期，再展開完整 4 環境重測，
而非直接跳去跑全部 4×5=20 情境。

## 11. 未解決問題

- TiDB P-B F1-follower 的 4.180s outlier（err=2，真實觀測）成因未查——不同於已解釋的 P-A
  outlier（那組 err=0，屬 F-001）。
- `chaos/C7.md` spec 與實際 `chaos-c7-disk-slow-execute.sh` 實作的情境命名落差未解決（未建立
  scenario registry，未重寫 spec 文件）。
- `io-latency-p99.txt` 檔名與實際內容（完整 `iostat -x` 輸出，非僅 p99）不符，未重新命名
  （既有 artifact 唯讀，且改名屬於功能無關的命名整理，留待下次真實重跑腳本時一併修正）。
- F-003/F-004/F-005/F-010 與 F-002/F-006/F-009 的次要訴求（見 §2 表格「駁回」欄）——全部因
  「需要重跑才能驗證新設計正確性，而本次規則禁止重跑」而延後，非否定其價值。

## 12. 我的錯誤與 PDCA（使用者已詢問，正式記錄於此）

這些是我自己的真實錯誤，非 Codex 吹毛求疵——已逐項核對 raw artifact 確認屬實。

- **Plan 階段錯誤**：把「事件後 probe 沒有任何 err」這種邊界情況設計成靜默 fallback（套用最後
  一次觀測值），而不是設計成明確拒絕/標記為「無法判定」。正確設計應該是：任何 fallback 路徑都
  要先問「這條路徑的觸發條件本身是否意味著量測失敗」。
- **Do 階段錯誤**：驗證重心放在「腳本有沒有跑完、有沒有印出數字」，而非「這個數字的語意是否
  真的是它宣稱的東西」。
- **Check 階段錯誤（確認偏誤）**：只對「看起來異常」的數字（例如極端值）加強懷疑，對「看起來
  合理、講得通故事」的數字（例如 CRDB graceful 比 ungraceful 快、TiDB/YBDB RTO 在同一量級）
  反而少查——這正是本次 F-001 影響最大的原因：CRDB/YBDB 的假數字剛好都落在「看起來正常」的
  範圍內。
- **Act 階段補救**：已完成的部分——把驗證邏輯直接內建進工具本身（`outage_observed`、
  ambiguous-write 三態判定），讓下次執行「無法再靜默產生假數字」，而不是依賴人工事後複查。
  尚未完成的部分——建立「新腳本分支首次對到新目標前，先跑一次已知會失敗的對照組」的習慣
  （例如刻意打錯 DB 類型參數，確認腳本會 fail-closed 而非 fail-open）；建立發布前的 checklist
  （每個「N/A」「0」「6/6 無異常」這類看似乾淨的結果，發布前都要反問一次「沒有異常」和
  「沒有偵測到異常」是否被混為一談。

## 13. 是否需要重新執行採樣（使用者已詢問，正式記錄於此）

**需要，但非全部，且非立即**：CockroachDB、YugabyteDB 的 F1/C4/C1 目前是 0 筆有效數字，
若要在比較報告中保留這些情境的跨 DB 對照，就必須重跑（4 環境 × 3 情境類型）；TiDB 不需要重跑
F1/C4；F2 不需要重跑但需保留現有 caveat；C7 不建議直接照原設計重跑（同樣的設計缺陷會重現同一個
「無法回答」的問題，需先決定是否要補齊 DB 端指標再重跑）。**這次選擇的替代路徑**：不立即重跑，
改以現有紀錄+ 本報告完整揭露方法論落差與精度區間，讓比較報告的結論範圍與證據力對齊
（見 §4/§5/§6），把「重跑」列為下一步待辦（§10）而非本次交付的一部分。
