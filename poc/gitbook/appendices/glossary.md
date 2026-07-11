# 附錄：術語

| 術語 | 定義 |
|---|---|
| N=1 | 單次或單組環境觀察；可作探索，不足以估計穩定性或採購容量。 |
| A/S | Active/Standby；主區服務、備區待命接手。 |
| A/A-RO | Active/Active Read Only；主區寫入、兩區可讀，異地讀可能為 stale。 |
| A/A | Active/Active；兩區皆可讀寫，須處理延遲、衝突與 retry。 |
| RTO | 事故到第一筆成功寫入 commit 的時間量測定義。 |
| RPO | 事故前後已 commit 交易遺失差異；非備份排程的同義詞。 |
| placement | 副本/leader/leaseholder 的區域與節點配置。 |
| quorum | 寫入需取得的一致性多數。 |
| stale read | 可讀到較舊但可接受的一致性版本。 |
| canary | 受控小流量切換，用於驗證並保留回退能力。 |
| hard gate | 未通過即不可進入下一階段的強制條件。 |
| spec-only | 已有設計或方法，但尚無符合口徑的實跑證據。 |

來源：[PoC 設計](../../results/PoC-DESIGN.md)｜[RTO/RPO 方法](../../phase-crossregion/failover/RTO-RPO-methodology.md)
