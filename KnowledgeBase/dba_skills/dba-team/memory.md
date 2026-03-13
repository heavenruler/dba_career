# dba-team Memory Design

## 1. 記憶目的

`dba-team` 的記憶機制不是為了保存所有對話，而是為了讓後續任務可重複利用已知環境、歷史決策與使用偏好，降低重工、減少誤判，並提升回答的一致性與可維運性。

實務上，記憶主要解決三件事：

1. 避免每次都重新確認環境資訊，例如 OS、DB 版本、雲平台、容器平台。
2. 保留重要決策與事件脈絡，例如選型結論、已做過的 migration、已知 incident。
3. 讓輸出風格與建議方向貼近使用者慣例，例如優先給命令、偏好某些資料庫或文件格式。

## 2. 記憶分類

### 2.1 `env.json`

記錄相對穩定或半穩定的執行環境資訊，用於技術建議落地。

建議保存內容：

- 作業系統與版本
- 執行平台（bare metal、VM、container、Kubernetes、cloud）
- 資料庫產品、版本、拓撲
- 觀測、備份、部署工具
- 網路限制、資安限制、維運限制

適合的更新頻率：

- 環境確認時立即更新
- 版本升級或拓撲變更後更新
- 每次重大專案後做一次整理

### 2.2 `history.json`

記錄具時間序的歷史事件與決策，供後續查閱與避免重複討論。

建議保存內容：

- `tasks`: 已處理任務與處理狀態
- `decisions`: 技術決策與採納理由
- `incidents`: 故障、影響範圍、根因與改善項
- `migrations`: 遷移或升級計畫與結果
- `reviews`: 架構 review、SQL review、風險 review 結論

適合的更新頻率：

- 任務完成時更新摘要
- 發生 incident 後補 RCA
- 遷移結束或評審完成時寫入結論

### 2.3 `preferences.json`

記錄使用者或團隊偏好，幫助輸出更貼近實際工作方式。

建議保存內容：

- 語言偏好
- 回答格式偏好
- 是否優先給命令或先講架構
- 常用資料庫或技術棧
- 預設假設與風險承受度

適合的更新頻率：

- 當使用者反覆表達同一偏好時更新
- 文件模板或輸出要求改版時更新

## 3. 寫入原則

記憶寫入應遵循以下規則：

1. 只寫「可重用」資訊，不寫一次性對話雜訊。
2. 優先寫入已確認事實，不把推測當成事實。
3. 若是暫時假設，需標註 `confidence`、`source` 或 `status`。
4. 同一事件應寫摘要與關鍵欄位，不要塞入大段逐字稿。
5. 重大決策需寫入 `why`、`scope`、`date`、`owner`、`status`。
6. 若資訊涉及敏感內容，應保存描述而非明文秘密，例如記錄「使用 Vault 管理密鑰」，不要記密碼本身。

## 4. 讀取原則

回答前應先讀取與主題最相關的記憶，不需要每次全量讀取。

建議讀取策略：

- 問版本、架構、部署：先讀 `env.json`
- 問延續型任務、曾經做過什麼：先讀 `history.json`
- 問輸出格式、回覆風格：先讀 `preferences.json`
- 問重大設計取捨：同時讀 `history.json` 的 `decisions`

若記憶內容與當前需求矛盾：

1. 優先指出矛盾點。
2. 明確區分「歷史記錄」與「本次需求」。
3. 若無法判定，採保守假設並要求確認。

## 5. 更新策略

### 5.1 append vs overwrite

- `env.json`: 以 overwrite 為主，但保留 `last_updated` 與必要的 `notes`。
- `history.json`: 以 append 為主，不覆蓋既有事件。
- `preferences.json`: 以 overwrite 為主，但可在 `change_log` 保留偏好變更。

### 5.2 update triggers

以下情況建議更新記憶：

- 新增或確認環境資訊
- 做出新技術決策
- 完成 migration / upgrade / review
- 發生或結案 incident
- 使用者重複表達固定偏好

### 5.3 stale data handling

對於可能過時的資料，建議增加：

- `last_verified_at`
- `verified_by`
- `confidence`
- `status`: `active`, `deprecated`, `pending_verification`

## 6. 去重策略

避免記憶膨脹與衝突，建議採用以下去重方式：

1. 以 `id`、`system_name`、`project_name`、`decision_key` 作為主鍵。
2. 同一事件若有多次更新，保留同一 `id` 並更新 `status` 與 `last_updated`。
3. 相同結論但不同討論過程，只保留最終摘要與關鍵差異。
4. 若 `history.json` 內容已沉澱為 SOP 或標準模板，應搬移到 `references/`，history 僅保留索引。

## 7. 風險與限制

### 7.1 風險

- 記憶過期導致建議錯誤
- 使用暫時假設做永久決策
- 歷史偏好綁架當前需求
- 保存敏感資訊造成風險

### 7.2 限制

- 記憶只輔助決策，不取代即時查證
- 版本、授權、雲服務規格仍需依官方文件確認
- 歷史案例不能直接視為所有環境通用

## 8. 建議欄位設計

### 8.1 common fields

適用於多數記憶物件的共通欄位：

```json
{
  "id": "string",
  "title": "string",
  "status": "active",
  "summary": "string",
  "tags": ["string"],
  "source": "user|system|reference|inferred",
  "confidence": "high|medium|low",
  "created_at": "2026-03-13T00:00:00Z",
  "last_updated": "2026-03-13T00:00:00Z"
}
```

### 8.2 env fields

- `os.family`, `os.version`
- `platform.type`, `platform.region`
- `databases[].engine`, `databases[].version`, `databases[].topology`
- `constraints.security`, `constraints.network`, `constraints.operations`

### 8.3 history fields

- `tasks[].objective`, `tasks[].result`
- `decisions[].decision_key`, `decisions[].options`, `decisions[].chosen`
- `incidents[].severity`, `incidents[].impact`, `incidents[].root_cause`
- `migrations[].source`, `migrations[].target`, `migrations[].rollback_plan`
- `reviews[].review_type`, `reviews[].findings`, `reviews[].actions`

### 8.4 preferences fields

- `language.primary`
- `output_style.answer_order`
- `preferred_formats.documents`
- `preferred_databases`
- `risk_tolerance.level`

## 9. JSON 結構範例說明

### 9.1 `env.json` 範例意義

`env.json` 應足以支撐這類問題：

- 「目前是 Kubernetes 還是 VM？」
- 「MySQL 版本是 5.7 還是 8.0？」
- 「能不能用容器化部署？」
- 「觀測工具有沒有 Prometheus / Grafana？」

### 9.2 `history.json` 範例意義

`history.json` 應足以支撐這類問題：

- 「上次 PoC 為何沒有選 TiDB？」
- 「去年 Oracle 升級遇到什麼問題？」
- 「這個 incident 有沒有做過 RCA？」

### 9.3 `preferences.json` 範例意義

`preferences.json` 應足以支撐這類問題：

- 「這位使用者偏好先給架構圖解還是先給命令？」
- 「要用 markdown、表格還是 checklist？」
- 「平常偏好哪些資料庫與風險策略？」

## 10. 實務建議

1. `env.json` 內容不要追求完整 CMDB，而是保留影響建議品質的最小必要資訊。
2. `history.json` 應偏向可稽核紀錄，尤其是決策、incident、migration。
3. `preferences.json` 應保持精簡，避免把單次偏好誤當長期規則。
4. 若內容已成為標準知識，搬到 `references/`，記憶只存索引與摘要。
5. 每次輸出若有重大新結論，應思考是否值得寫入 memory，而不是一律寫入。
