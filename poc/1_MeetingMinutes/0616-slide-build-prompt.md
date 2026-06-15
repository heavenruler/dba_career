# Prompt — 根據 `0616-slide-draft.md` 建立可呈現的 Marp 簡報

> **用途**：把 `1_MeetingMinutes/0616-slide-draft.md` 的內容輸出成可直接於 VS Code Marp preview / pandoc → .pptx 渲染的簡報檔。
> **使用方式**：把下方整段 prompt 貼給 Claude（或 Claude Code）執行。

---

## Prompt（複製以下整段）

```
你是 C-level 簡報設計師。請依以下需求把 markdown 草稿轉成可直接渲染的 Marp 簡報。

# 任務
讀取 /Users/wn.lin/vscode-git/dba_career/poc/1_MeetingMinutes/0616-slide-draft.md，
把它輸出為 Marp 格式的 markdown 簡報，存到：
/Users/wn.lin/vscode-git/dba_career/poc/1_MeetingMinutes/0616-slide.md

# 輸入檔
草稿：1_MeetingMinutes/0616-slide-draft.md（已含 5-8 slide 結構與內容）

交叉引用（讀取以確認數字 / 命名一致，**不要憑空補數字**）：
- 1_MeetingMinutes/analytics-S-K8S-2026-06-15.md（tpmC / p99 / retention 來源）
- 1_MeetingMinutes/2026-06-09-distributed-db-adoption-non-technical.md（5 待決 + 4 拍板，非技術議題）
- phase-crossregion/decisions-2026-06-08.md（10 道技術議題）
- 1_MeetingMinutes/0611-TiDBx104-summary.md（PingCAP 對焦事項）

# 輸出格式
Marp markdown，含以下 front matter：

---
marp: true
theme: default
paginate: true
size: 16:9
header: 'PoC 第一階段成果與下一步決策'
footer: '2026-06-16'
style: |
  section {
    font-family: 'Noto Sans CJK TC', 'Microsoft JhengHei', sans-serif;
    font-size: 22px;
  }
  h1 { font-size: 36px; }
  h2 { font-size: 30px; }
  table { font-size: 20px; }
  strong { color: #c0392b; }
---

每頁以 `---` 分隔。第一頁為封面（標題 + 副標題 + 日期 + 受眾）。

# 內容規則

1. **每頁單一核心訊息**：以 H1 為頁標題，第一行 blockquote 寫一句「本頁核心」。
2. **5-8 頁**：對齊草稿；Slide 6-8 為選頁，可依內容密度決定保留與否。
3. **不重新詮釋**：草稿已決定的 narrative 直接搬，不要新增推論。
4. **不憑空補數字**：tpmC / retention 數字必須與 analytics-S-K8S-2026-06-15.md 一致；草稿用「約 87%」就保留約值，不擅自精準化或反向。
5. **表格瘦身**：草稿表格欄位過多時，挑 3-4 個關鍵欄位即可；保留來源 caveat。
6. **首次出現完整名稱**：TiDB / CockroachDB / YugabyteDB（不簡寫成 CRDB / YBDB）。

# 語言與用詞規則（依用戶風格 memory 收斂）

- 繁體中文。
- **禁用詞**：BSL、董事會層級摘要（BOD summary）、Gartner（除非直接引用 0616-slide-draft）、「14 道 Q&A」（已過時）、「100% ready」、「最快」單一排序判讀。
- **避免英文 jargon 連發**：Service Mesh / NodePort / iptables / pod anti-affinity 等首次出現可保留原文，但加 1 句中文白話補述。
- **TLS / IDC / IaC / TCO / DR 等縮寫**：首次出現補中文（傳輸加密 / 自有機房 / 基礎建設即程式碼 / 總持有成本 / 災難復原）。
- **「中資」字樣**：只用於 Slide 5 / Slide 6 的廠商商業實體討論欄；不放在技術比較主表內。
- 「YugabyteDB K8s 19% retention」呈現方式照草稿「成因尚未定位，列為後續調校項」；**不解釋成因**。
- 不寫「由會議決定」、「placeholder」、「待填」這類詞 — 簡報直接給結論或框架。

# 視覺規則

- 每頁不超過 50 字標題行 + 1 個表格（≤6 列）+ 3-5 個 bullet。
- bullet 不要超過 2 層巢狀。
- 不要塞 code block 滿頁；確實需要程式碼示意（如 phase-n 階段地圖）才用 ```text``` 框。
- 數字 / retention% 用 `**強調**`；列數字優先靠右對齊（`---:`）。
- footnote 用 `>` blockquote 標示，靠頁尾。

# 結構（對齊草稿）

第 1 頁：封面（標題 + 副標題「第一階段 PoC 成果與下一步決策」+ 日期 + 受眾）
第 2 頁：進度地圖 + 三點結論
第 3 頁：三家資料庫導入定位
第 4 頁：VM 與 Kubernetes 效能差異
第 5 頁：跨區域 / 跨專線進度（Done / Pending / Risk 三段）
第 6 頁：建議決策框架 + application owner 五項議題
第 7（選）：限制與風險（已驗證事實 / 工程推論 / 待補數據）
第 8（選）：後續推進階段（短期 / 中期 / 決策）
第 9（選）：Appendix 文件導引 + 預期問題回應

# 完成後動作

1. 寫入 1_MeetingMinutes/0616-slide.md
2. 跑以下檢查並報告：
   - rg -n 'BSL|董事會層級|Gartner|14 道|100% ready' 1_MeetingMinutes/0616-slide.md  → 預期 0 matches
   - 對照草稿章節數，列出新檔頁數 + 內容差異摘要
3. 若想預覽，提示用戶：
   - VS Code: 安裝 Marp for VS Code 後直接開 0616-slide.md 點右上 preview
   - CLI: `npx @marp-team/marp-cli 0616-slide.md -o 0616-slide.pptx`
4. **不要 commit**；交給用戶 review。

# 不在 scope

- 不重新做數據分析（直接取 analytics-S-K8S-2026-06-15.md 數字）
- 不替用戶決策（Slide 5 列框架不點名推薦）
- 不加封底「Thank you / Q&A」單獨頁（內建 Marp paginate 已有頁碼）
- 不渲染 .pptx（用戶決定工具後自渲）
```

---

## 使用範例

```bash
# 1. 把上方 prompt 整段（從 "你是 C-level 簡報設計師" 到「不渲染 .pptx」）複製
# 2. 開新 Claude Code session 在 poc/ 目錄下
# 3. 貼上 prompt 執行
# 4. Claude 會讀 4 個來源檔、寫入 0616-slide.md、跑 rg 檢查、列差異摘要
# 5. 用戶 review → 滿意後手動 commit + 渲染
```

## 設計筆記（給 prompt 作者 / 維護者參考）

- **為什麼用 Marp 而非 pandoc 直接 .pptx**：Marp markdown 可在 VS Code preview，會議中可直接展示；pandoc 多一步 binary 渲染
- **為什麼每頁限「1 表 + 5 bullet」**：C-level 簡報 readability 上限
- **為什麼禁 BSL / 董事會摘要**：依 user memory `feedback_meeting_minutes_style.md`，這些不在公司實際在審範圍
- **為什麼把「19% retention」標「不解釋成因」**：依 analytics 處理方式（dry-run 補強 deploy state，但不切分 K8s plane cost vs deploy misconfig）
- **為什麼跨區仍寫「三家 sweep」**：Q9 拍板對標三家；廠商收斂為 TiDB 為主屬於應用導入面向，sweep 階段不同
