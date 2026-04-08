# PoC: OpenCode Multi-Session Handoff

此 PoC 用於驗證多個 OpenCode session 在同一個 repo 內，針對同一個目標進行分工、溝通與交接。

## 目標

- 每個 session 有明確角色
- 以 `commit` 作為主要進度紀錄
- 每次提交都要留下可交接資訊
- 清楚指出下一位身份需要做的事情

## 建議角色

- `architect`：定義目標、拆解任務、確認邊界
- `implementer`：撰寫程式、文件或腳本
- `reviewer`：檢查成果、風險與缺口
- `tester`：驗證流程、執行測試、回報結果

可依實驗需要增減角色，但每次提交都應固定標明目前身份。

## 協作規則

1. 每個 session 啟動時先閱讀 `HANDOFF_LOG.md`
2. 開工前確認自己本次身份
3. 完成後提交 commit，並更新 `HANDOFF_LOG.md`
4. 交接時必須寫明：
   - 哪個身份提交
   - 這次做了什麼
   - 目前狀態與限制
   - 下一步要由誰接手
   - 下一位要做什麼

## 建議 commit 訊息格式

```text
[role:<身份>] <動作摘要>
```

例如：

```text
[role:architect] define collaboration workflow
[role:implementer] add handoff log template
[role:reviewer] review gaps in session coordination
```

## 文件

- `HANDOFF_LOG.md`：跨 session 交接主紀錄
