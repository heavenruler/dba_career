# Scenario 1 (P-A×A-S, TiDB) — chaos/failover 實跑進度 (2026-08-07)

DBA 自授權（見對話記錄，非正式 PR+review 流程）於既有環境
`tidb-vm-6node-P-A-rc-20260807T121624+0800` 上依序執行 C7→C1→F1（C4/F2 待續）。
新增執行腳本一律為新檔，未改動既有 planner-only script。

## 已完成情境結果

| 情境 | 機制 | 結果 | 備註 |
|---|---|---|---|
| C7 disk-slow | fio O_DIRECT 磁碟競爭（非 cgroup throttle，見下方限制） | 佇列深度 (aqu-sz) 0.25→50-109，fio 130k+ IOPS，同時段 tpmC 無明顯下降 | `chaos-c7/` 為最終有效結果；`chaos-c7-attempt1~4-*/` 為除錯過程留存，非有效數字 |
| C1 partition | 6 host 雙向 iptables DROP 60s | 60 秒乾淨完成；起始 6 秒內 120 次 context-canceled 錯誤，之後零錯誤 | 曾發生自鎖事故（見下方）已修復重跑 |
| F1 graceful kill | PD leader resign + `systemctl stop tidb-4000` | **RTO = 6.987s，RPO = 0 lost tx** | 首次執行 kill 指令因 unit name 錯誤完全無效，已修復重跑；RTO 計算邏輯修正兩輪見 `f1/rto-rpo.json` 內 `rto_recompute_note` |

## 過程中發現並修復的既有腳本 bug（均已改在 repo 對應腳本）

1. **`chaos-c7-disk-slow-execute.sh`**：cgroup v1 blkio.throttle 對 TiKV buffered write 無效（已改用 fio 磁碟競爭）；MAJ:MIN 需為整顆磁碟而非分割區；後台 fio 啟動需 `setsid` 且需包成 subshell 整體重導向，否則 ssh 會卡住等 fio 跑完。
2. **`chaos-c1-partition-execute.sh`**：orchestrator (.31) 本身在被封鎖的 IDC CIDR 內，導致 restore 的 ssh 永久掛住 → 造成一次約 4 分鐘的失控斷線（設計為 60 秒）。修復為白名單 (GCP host 上 ACCEPT orchestrator IP) + 每台 host 自帶自進過期安全網 timer 雙保險。
3. **`run-vm6-chaos-execute.sh`**（F1/C4 共用）：
   - TiDB kill 指令 unit name 錯誤（`tidb-server` → `tidb-4000`），首次執行完全沒有真的停掉服務。已加 post-kill pgrep 驗證，未來若 kill 未生效會直接 FATAL 中止。
   - F1 缺少 F1.md 要求的 PD leader resign 優雅步驟（原本 F1/C4 動作完全相同）。
   - `LEADER_QUERY` 引用不存在的欄位（`tikv_region_status.store_id/is_leader`），已改為 join `tikv_region_peers`。
   - `S_PRE_QUERY` 欄位名錯（`w_id`→`o_w_id`）。
4. **`wall-clock-wrapper.sh`**：`stamp-first-ok` 原本抓「檔案內第一個 ok」，會抓到 incident 之前殘留的探測成功，導致 RTO 恆為近似 0；修正為只看 t_incident 之後。第二輪修正：failover 過程有 flapping（成功探測夾在兩次失敗中間），改為錨定「最後一次錯誤之後」才算真正恢復。

## 目錄內容

- `chaos-c7/`, `chaos-c1/`, `f1/` — 各情境最終有效 raw artifact（inject.log / plan.txt / probe.txt / rto-rpo.json 等）。
- `chaos-c7-attempt1~4-*/` — C7 除錯過程的失敗嘗試，保留作為問題排查紀錄，**不可**作為結果引用。
- `gate/`, `.prepare.done`, `.gate.done` — 環境部署與 placement gate 的原始判定證據。
- `logs/scenario1-steady-workload.log` — 全程背景 go-tpc TPC-C 穩態流量 raw log（含 C1/F1 注入窗口期間的錯誤訊息）。
- `logs/prepare-tidb-20260807T121624+0800.log` — 環境資料載入 raw log。

## 待續

C4（abrupt kill，同一支已修復腳本 `--scenario c4`）、F2（IDC 全滅+復原時間量測）尚未執行；環境仍存活、背景 workload 已改連 GCP HAProxy VIP (`10.160.152.14:4000`) 以避免單節點被殺時連帶中斷量測用流量。
