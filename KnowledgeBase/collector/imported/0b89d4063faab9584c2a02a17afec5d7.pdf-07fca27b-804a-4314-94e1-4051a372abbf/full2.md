# 使用 Blue-Green Deploy 把 MySQL 5.7 升級到 8.0

Justin Hollly · Feb 11, 2024 · 9 min read

最近因為 MySQL 官方公佈 5.7 EOL 是 2023/10/01，AWS RDS 也公布他們只支援到 2024/02。我們公司算一算若不升級，會有一個保護費，每月要付約 20 萬台幣左右。其實很早就得知這個消息，但是公司往往會等到要開始付錢才重視升級計畫。

今天我分享如何在短時間內盡可能覆蓋到所有整合測試的方式。如果你也使用 AWS RDS，也許可以參考。不過在我發文的這個時間點，如果你還沒有升級完成，那你真的有點危險。

## 為什麼要使用 Blue-Green Deployment?

初步評估後，我們決定使用 RDS 內建的藍綠部署（Blue-Green Deployment）升級功能。原因很簡單：

- AWS 幫我們處理即時資料同步（blue-green sync），並提供一鍵部署，幾乎是 zero downtime。
- 缺點是無法自動 roll back：部署完成後，會留下備份 DB（通常命名會帶 `-old` suffix），如果要回復必須手動轉移連線到那台備援 DB。

我們今年 SRE 離職並且人事凍結，沒有足夠人力做人工部署，因此使用託管服務的部署是最佳選擇。

## AWS Blue-Green Deployment 簡介

官方已有詳細文件，這裡簡單列出執行順序與重點：

1. 按下 Blue-Green Deploy 按鈕後，會選擇一系列參數，例如是否升級到 MySQL 8.0、是否擴增儲存空間、要不要修改 parameter group 等。設定完成後，會啟動一個樹狀結構：藍色是目前環境，綠色是已升級到 MySQL 8.0 的環境，等待切換。
2. 由於服務都仍連到藍色環境，RDS 會透過 binlog 同步到綠色環境。但需注意：綠色環境的異動不會被同步回藍色環境。如果不小心在綠色環境異動資料，可能導致資料衝突，甚至無法繼續下一步驟，因為 RDS 會檢查資料一致性。官方亦建議盡可能把綠色環境設為 Read Only。
3. 當在綠色環境測試完成後，可以按下 switch over 按鈕進行切換，RDS 會把原 endpoint 從藍色 instance 轉到綠色 instance。切換完成後，會建議刪除這個 Blue/Green Deployment task，但會保留一台同名但已升級到 MySQL 8.0 的 instance，且會以 `-old` suffix 做一個複製備用，萬一升級後發生問題可以緊急切回。

以上就是官方流程的簡要說明。

---

接下來根據我們團隊使用 RDS 的情況，列出較擔心的幾個坑，以及我們的檢查與實作步驟。

## 坑的評估

我們使用 Node.js 開發後端，許多 legacy 使用 Sequelize v3，因此擔心語法與 MySQL 8.0 不相容，會造成套件錯誤，這點需要整合測試檢查。

其他可能的問題：

- character set / collation 設定不相容：MySQL 8.0 預設變成 utf8mb4，需要檢查是否有資料是不相容的。
- storage engine type：MySQL 8.0 預設是 InnoDB，需確認既有資料與查詢行為是否受影響。

基於以上，我們整理出以下檢查事項與升級步驟。

## 升級步驟

1. 先使用官方 SOP 檢查是否有不相容的 configuration，可以於 DB 層級先調整。雖然 RDS 會自動協助處理，但手動檢查可提早發現問題並修正。
2. 備份 snapshot。點擊 RDS Blue-Green Deployment，先挑一個使用量最大的 DB instance snapshot 做一個 dummy instance，走一遍 Blue-Green Deployment 確認流程沒有問題。
3. 準備 API 整合測試。這是最困難的一步，因為團隊過去沒有完整的 API 整合測試。盤點後我們有近百支 API。幸好 Postman 最近推出了 Postbot AI，可以根據 request/response 自動產生測試案例，對於大量 CRUD API 能快速產出測試。金流相關則需獨立處理，因為第三方（LinePay、TapPay 等）往往沒有完整 sandbox，或需與前端綁定，我們只能在 staging 做完整購買流程驗證（幸運的是 staging 會自動退款）。
   - 使用 Postman 的自動化工具可以快速產生大量 test cases，節省時間。
4. 開啟 Blue-Green Deployment，並在綠色環境進行整合測試。這是關鍵階段。因為 RDS 預設綠色環境為 Read-Only，無法執行 write 操作做整合測試。我們與 AWS Support 討論後採取的策略是：再開一台綠色環境的 replica，並強制修改其 parameter group，將 read-only 改成 0（即 writable）。我們將這台 replica 命名為 `green-for-inte-test`。
   - 綠色環境的任何 instance 都不會影響其他綠色或藍色環境，因此在這台 instance 做任何測試基本上沒問題。測試完成後再刪除這台 replica。
   - 我們把 services 的連線先暫時改成這台新 DB（幸好有 IaC，否則改起來會很痛苦），接著執行 Postman 的整合測試。
   - 在這個階段會繼續發掘 charset、collation、以及 ORM（例如 Sequelize）和 MySQL 8.0 的相容性問題。大部分會在 API 層級噴錯，如果找不到，可能會等到 production 才會暴露問題。
5. 測試完畢後，記得刪除剛建立的 replica `green-for-inte-test`，並把連線資訊改回原本設定，然後按下 switch over 完成切換。

注意一件事：我第一次執行 switch over 就失敗了，原因是 data conflict。當時我沒有把所有服務的連線都改到 `green-for-inte-test`，反而連到 `slave-1`，導致髒資料殘留。最後在 switch over 時，RDS 比對發現資料不一致（例如 primary key 重複，binlog 無法寫入），就直接中斷了 switch over。這種情況只能取消整個 Deployment，重來一次。

切換完成後，RDS 會保留一台 `-old` suffix 的機器作為救援機。如果 production 發生問題又沒辦法即時 hot fix，可以迅速把連線切回那台舊機器。我們目前只把部分 instance 升到 8.0，預計觀察一季，確認沒有問題才會把舊機器移除。

## 反省

說真的，這次 DB 升級時間很趕，所以沒有做到非常謹慎。如果你參考 GitHub 他們升級 MySQL 8.0 的方式，可以看到更多分批、分階段的 read/write 策略（例如 GitHub 的案例是較為保守與完整的分批上線流程）。他們的做法很值得學習。

我們的規模比較小，也沒有做 shard，又大多使用 ORM（很少直接調整 DB 參數），因此相對風險較低，最後也沒有發生嚴重問題。但他們分批上線與混合 read/write 的策略真的很酷，希望未來有機會參與或設計更完整的部署升級流程。

寫下來才會記得。