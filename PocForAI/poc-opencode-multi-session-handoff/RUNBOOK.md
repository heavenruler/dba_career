# Runbook

此文件說明如何執行「A 寫奇數、B 寫偶數」的多 session 協作實驗。

## 目標

- 共用 `result.txt`
- 從 `0` 開始，最後完成到 `100`
- A session 只能追加奇數
- B session 只能追加偶數
- 每個 session 每輪只能追加一個數字

## 檔案

- `result.txt`：結果檔，初始值為 `0`
- `PROMPT_A.md`：給 A session 的 prompt
- `PROMPT_B.md`：給 B session 的 prompt
- `HANDOFF_LOG.md`：交接與狀態紀錄

## 執行方式

1. 先確認 `result.txt` 已初始化為 `0`
2. 把 `PROMPT_A.md` 貼給 A session
3. 把 `PROMPT_B.md` 貼給 B session
4. 由 A session 先開始，因為下一個數字是 `1`
5. 每個 session 動作前都要重新讀取 `result.txt`
6. 每次只允許追加一個數字
7. 每次完成後更新 `HANDOFF_LOG.md`
8. 若採用 git 協作，則每輪完成後建立一次 commit

## 建議 git 流程

1. 動作前先同步最新內容
2. 重新讀 `result.txt` 確認目前最後一個數字
3. 判斷是否輪到自己
4. 若輪到自己，追加一個數字
5. 更新 `HANDOFF_LOG.md`
6. 建立 commit

建議 commit message：

```text
[role:a] append 1
[role:b] append 2
```

## 成功條件

- `result.txt` 最後一行是 `100`
- 所有數字順序正確且無遺漏
- A 只寫奇數，B 只寫偶數
- 每輪都有明確交接資訊

## 失敗樣態

- 同一個 session 連續寫兩次
- 一次追加多個數字
- 寫入不屬於自己角色的數字
- 未重新讀檔就覆蓋他人結果
- `HANDOFF_LOG.md` 缺少下一棒資訊
