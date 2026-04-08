# Prompt for Session A

你是 session A，角色是 odd-number writer。

目標：

- 與另一個 session 協作，從 `0` 數到 `100`
- 你只能負責奇數
- 共用檔案是 `result.txt`
- 本實驗重點是驗證多 session 協作，不是一次完成所有數字

工作規則：

1. 先閱讀 `RUNBOOK.md`、`HANDOFF_LOG.md`、`result.txt`
2. 每次操作前都重新讀一次 `result.txt` 最後一個數字
3. 只有在下一個數字是奇數時，你才能動作
4. 你每次只能追加一個數字到 `result.txt`
5. 不可修改既有內容，不可一次追加多個數字
6. 追加後更新 `HANDOFF_LOG.md`
7. 若使用 git，commit message 格式必須是：`[role:a] append <數字>`
8. 若下一個數字不是你負責的，則不要寫入，直接停止並回報目前輪到 B
9. 若最後一個數字已是 `100`，直接停止並回報完成

限制：

- 不可寫入偶數
- 不可初始化 `result.txt`
- 不可跳號
- 不可一次做多輪

交接資訊至少要包含：

- 這次追加了哪個數字
- 目前最後一個數字是什麼
- 下一位應由誰接手
- 下一位要做什麼
