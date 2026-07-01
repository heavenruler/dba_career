# Claude Code Prompt: X-CROSS PoC 報告反向審查與重寫

## 使用目的

把以下 prompt 交給 Claude Code session。目標不是擴充 demo，而是從「哪些證據會改變 PoC 採用決策」反推最小必要報告，先修正 SSOT 衝突，再重寫 `results/x-cross/demo/x-cross-report-demo.md`。

---

## Prompt

你是本專案的資深 PoC reviewer 與技術主理人。請在 repo root 下工作，審查並重寫：

`results/x-cross/demo/x-cross-report-demo.md`

這不是文字潤飾任務。請用反向邏輯執行：先定義這份 PoC 要支持哪些決策，再只保留能回答決策的實驗、數據與限制。任何不會改變 go / no-go、部署模式、候選 DB 或後續投資優先序的資訊，都應刪除、縮成連結，或移到 appendix。

### 1. 執行原則

1. 先讀完下列 SSOT 與實作，不可只讀 demo：
   - `phase-crossregion/manifest.yaml`
   - `phase-crossregion/Makefile`
   - `phase-crossregion/README.md`（Phase 狀態表，原 `NEXT-STEPS.md`）
   - `phase-crossregion/decisions-2026-06-08.md`
   - `phase-crossregion/topology/P-A.md`
   - `phase-crossregion/topology/P-B.md`
   - `phase-crossregion/workload-profiles/{A-S,A-A-RO,A-A}.md`
   - `phase-crossregion/chaos/{README,C1,C4,C7}.md`
   - `phase-crossregion/scripts/chaos/chaos-c1-node-down-plan.sh`
   - `phase-crossregion/scripts/chaos/chaos-c4-network-partition-plan.sh`
   - `phase-crossregion/failover/{F1,RTO-RPO-methodology}.md`
   - `results/x-cross/pipeline-log.md`
   - `results/PHASES.md`
   - `results/PoC-DESIGN.md`
   - `tests/common/summary-from-stdout.py`
2. 用程式與 artifacts 驗證文件宣稱。文件彼此衝突時，不可自行挑一份當真；先列出衝突，依「實作行為 > artifact > registry/manifest > plan/doc > demo」判定目前事實。
3. 不可執行正式 benchmark、chaos、failover、VM destroy/apply 或任何會改動遠端環境的命令。本任務只處理文件、schema 與靜態驗證。
4. 不可新增 fake 數字、模擬排名、假 CI、假 RTO/RPO 或看似合理的瓶頸結論。尚未量到的值一律寫 `TBD (not measured)`。
5. 每個結論必須標示證據狀態：`MEASURED`、`DERIVED`、`INFERRED`、`PLANNED`、`BLOCKED`。`INFERRED` 不可寫成實測結論。

### 2. 先修正或明確登記的 SSOT 衝突

在改報告前，建立一張 conflict table，至少處理以下問題。若能由 repo 靜態證據確定，修正權威文件；不能確定則建立 blocker，不可默默合理化。

1. **DEV-1x1 誤標**：`results/x-cross/determinism/run1`、`run2` 是 true six-node、W=4 same-cluster determinism，不是 DEV-1x1。demo 的相關敘述必須修正。
2. **W=128 target stale doc**：`phase-crossregion/Makefile` 已有 `phase-crossregion-w128-suite`，但 `README.md` Phase 狀態表（原 `NEXT-STEPS.md`）仍寫不存在。同步目前狀態與尚未驗證的限制。
3. **N=5 語意錯置**：現有 target 只設定 `ROUNDS=5`。這代表同一 suite 的五個 rounds，不等於五個 independent suites。不得把它描述成 independent `N=5`，除非另有外層 repeat orchestration 與獨立 artifacts。
4. **統計口徑衝突**：`results/PHASES.md` 與 code 定義 canonical `tpmC_mean = R1-R5 mean`；`results/x-cross/pipeline-log.md` 又要求 `R2-R5 median / CV`。先決定 primary estimator 並統一 SSOT。若 code 未改，報告主表必須以實際 schema 為準，其他 robust estimator只能列 secondary analysis。
5. **A-A-RO 定義錯誤**：`workload-profiles/A-A-RO.md` 把 `NEW_ORDER` 寫成 read path；但決策文件與 `run-vm6-aa.sh` 使用 `ORDER_STATUS + STOCK_LEVEL`。`NEW_ORDER` 是 write transaction。先修正 profile SSOT，並驗證 go-tpc `--mix` 實際是否由 `tests/common/run.sh` 傳入。
6. **Chaos C1/C4 對應衝突**：spec 定義與 planner script 名稱/行為互換。C1/C4 未有單一一致模型前，不得在報告列 scenario 結果 schema，更不得聲稱 planner 已符合 spec。
7. **非 repo memory 引用**：移除 `feedback_iap_tunnel_avoid`、`feedback_xcross_serial_per_db` 等不可追溯 memory 引用。必要決策請寫入 repo decision record，附日期、owner、rationale。
8. **每 cell VM rebuild 規則**：確認這是已批准的實驗控制，還是未落地 memory。說明 rebuild 會降低殘留污染，但也會增加 between-suite environment variance；不得直接寫成科學必然。
9. **拓撲語意**：驗證 P-B 所稱 `arbiter` 是否真能由三家 DB 對應實現。若只是位置/角色抽象，改用各 DB 的實際 voter、replica、leaseholder/leader 語意。
10. **endpoint 圖錯誤**：不可把三家 HAProxy endpoint 都畫成 `:4000`，也不可統稱 `jdbc/pg`。從 inventory/config 取得各 DB 真實 protocol 與 port；取不到就省略 port。

### 3. 從主報告刪除或降級的內容

主報告要服務 PoC 決策，不是展示「報告可以有多完整」。請做以下縮減：

1. 刪除所有 synthetic tpmC、p95/p99、error rate、commit latency、WAN、cost、RTO/RPO 數字與 fake 排名。
2. 刪除由 fake 數字推導的三家瓶頸分析、勝負敘事、ASCII chart、fake bootstrap CI 與 fake trend。
3. P-A/P-B 的預期 drop range 只能標示為 `PLANNED ASSUMPTION`，不可當 acceptance criteria，也不可用捏造結果去「驗證落在預期範圍」。
4. 將七階段 pipeline 詳解、34 筆 reference mapping、16 維 rigor、11-item gate、16 個 anti-pattern 等重複方法論移到 appendix 或既有 SSOT，只在主報告保留必要 gate 摘要與連結。
5. 把 steady-state performance 與 resilience 分成兩個 decision track。正式 chaos/F1 未解 blocker 前，主報告只列 `BLOCKED` 狀態與 blocker，不放 demo 結果表。
6. `19/19 PASS` 若只是 plan 與文件欄位對齊，改成 `plan conformance reviewed`。沒有 runtime evidence 不得寫 PASS。
7. `baseline_eligible=false` 的精確含義是不可混入 S-BASE/S-K8S canonical baseline 主表；不要擴張成「X-CROSS phase 內永遠不能比較」。正式、受控、同 phase 的 X-CROSS 候選比較仍可成立。
8. 刪除 p99.9/p99.99，除非先證明每個 cell 的 transaction sample count 足以穩定估計，並明示 estimator 與 uncertainty。
9. 不採 `±3σ from median` 或「最多剔除一個 suite」規則。預設不得自動排除；保留所有 raw data，異常需有事前規則、原因證據與含/不含異常值的 sensitivity analysis。若使用 robust z-score，採 median/MAD 並寫清公式。
10. 報告總長以約 250-350 行為目標。詳細 runbook 與 methodology 用連結，不重抄。

### 4. 主報告目前缺少、必須補上的決策資訊

請將下列內容提升到報告前半部，而不是埋在 caveat 或 appendix：

1. **Decision statement**：本 PoC 最終要決定什麼，例如是否採跨區、採 P-A 或 P-B、採哪個 DB、哪些 workload 只適用 DR/read-scale/active-write。
2. **候選使用情境**：A-S、A-A-RO、A-A 各自對應哪個真實業務需求；沒有需求 owner 的 profile 不應自動進正式矩陣。
3. **預先定義的 acceptance criteria**：由業務/架構 owner 提供最低 tpmC、p99、error rate、RTO、RPO、read freshness、最大 WAN cost。沒有門檻時只能做探索，不能下 go/no-go。
4. **Primary endpoint**：每個 decision track 只能有清楚的主要指標；secondary diagnostics 另列。不要用大量 metrics 事後挑有利結論。
5. **最小實驗矩陣**：每個 cell 都要回答「哪個結果會改變哪個決策」。若 P-A/A-S 已不符合需求，或 A-A 不會進 production，刪除對應 cell。不要因為 2 placements × 3 profiles × 3 DB 看起來完整就全部跑。
6. **對照組**：要量化 WAN/placement cost，需同硬體、同版本、同 W、同 workload 的 IDC-only six-node control。沒有 paired control 時，不可宣稱 retain/drop vs IDC-only。
7. **容量映射**：說明 W=128、thread sweep、資料量與執行時間如何對應 production peak、成長 headroom 與 hotspot。若無 production demand data，標成 blocker。
8. **實驗單位與 repeat 設計**：明確區分 within-suite rounds、independent suites、same-cluster repeats 與 rebuild repeats；說明配對方式、執行順序、randomization/blocking 與環境漂移控制。
9. **結果不確定性**：主表至少報 raw rounds、canonical estimator、CV/range、樣本數與 caveat。CI 只能由真實 independent samples 產生。
10. **正確性與耐久性 gate**：transaction mix、資料筆數、consistency/durability、error/retry/abort 必須先 PASS，效能數字才可 promotion。
11. **client 與系統飽和證據**：CPU、disk latency/IOPS、network、DB queue/lock/retry、client CPU/connection saturation。沒有這些證據時，只能說觀察到 throughput plateau，不能指定瓶頸根因。
12. **可營運性**：部署/升級、backup/restore、故障處理、觀測、支援與 license 限制。這些可獨立於 benchmark 形成 must-pass gate。
13. **成本**：GCP VM、HAProxy/client、inter-region egress、儲存、license、工程維運成本。steady-state 與 failover cost 分開。
14. **安全與治理**：data residency、加密、IAM、稽核、網路邊界與合規限制。
15. **責任與時程**：每個 blocker 要有 owner、due date、解除證據與對決策的影響。
16. **Evidence provenance**：每個主結論連到 artifact/summary/config hash；提供 confidence (`high/medium/low`) 與 promotion status。

### 5. 建議的新報告結構

請依下列順序重寫：

1. `Executive decision`：目前狀態、可做/不可做的決策、最大 blocker。
2. `Decision questions and gates`：decision、owner、threshold、evidence、status。
3. `Scope and candidate scenarios`：只列有業務用途的 profile/placement。
4. `Current evidence inventory`：
   - true six-node W=4 smoke/determinism = framework evidence
   - W=128 formal = not measured
   - P-B = not measured
   - chaos/F1 = blocked/planner-only
5. `Minimal experiment matrix`：cell、hypothesis、primary endpoint、control、結果如何改變決策。
6. `Measurement contract`：canonical schema、repeat unit、statistics、correctness gate、artifact path。
7. `Results`：目前只放真實 artifacts；未跑欄位保持 TBD，不用假數據示範。
8. `Risks, cost, operability`。
9. `Blockers and next actions`：owner/date/evidence。
10. `Appendix`：拓撲、pipeline 與完整 reference links。

### 6. 產出要求

1. 先輸出一份 audit summary，列出：
   - `Remove`：PoC 主報告不需要的內容與原因。
   - `Add`：缺少且會影響決策的資訊。
   - `Correct`：錯誤或互相矛盾的事實。
   - `Block`：缺證據時不能下的結論。
2. 修正能由 repo 證明的 SSOT 衝突；每個修改需附來源與理由。不要改動無關檔案。
3. 重寫 `results/x-cross/demo/x-cross-report-demo.md`，保留 DEMO/NOT-FOR-DECISION 狀態，但改成無 synthetic 數值的決策報告模板。
4. 另產 `results/x-cross/demo/x-cross-report-demo-audit.md`，記錄刪除、補充、衝突處理與 unresolved blockers。
5. 執行以下靜態檢查並回報結果：
   - 搜尋 `fake|synthetic|speculative`，確認只留必要警語，不留假結果。
   - 搜尋 `feedback_`，確認沒有不可追溯 memory 引用。
   - 搜尋 `DEV-1x1`、`N=5`、`R1-R5`、`R2-R5`，確認語意一致。
   - 搜尋 C1/C4 script/spec 引用，確認沒有把不同行為當同一 scenario。
   - 驗證 Markdown 內所有 repo-relative links 存在。
6. 最後回報：修改檔案、已解衝突、未解 blocker、以及哪些條件完成後才可 promotion 成正式 PoC 報告。

### 7. 禁止事項

- 不得用架構常識替代本 repo 的 runtime evidence。
- 不得因數字有 `fake` 標籤就保留 realistic fake ranking；它仍會造成決策錨定。
- 不得把計畫符合、script 存在或 gate spec 存在寫成 runtime PASS。
- 不得把五 rounds 當五 independent experiments。
- 不得把理論 `RPO=0` 寫成觀測結果。
- 不得把 correlation 寫成 bottleneck root cause。
- 不得為追求矩陣完整而擴大執行範圍。

完成標準：讀者在前三個章節就能回答「現在能決定什麼、不能決定什麼、還缺哪個證據、補證據是否值得花成本」，而不是先讀完大量方法論與假數字。
