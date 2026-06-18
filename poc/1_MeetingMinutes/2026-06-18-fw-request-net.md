# 2026-06-18 NET FW 開通申請（IDC ↔ GCP 跨專線 PoC）

> 用途：分散式資料庫 PoC 需開通自有機房（IDC）至 GCP 之雙向防火牆規則，
> 以驗證 TiDB / CockroachDB / YugabyteDB 三家跨 region 同步機制。
> 對應 Jira: ITDBA-3596（分散式資料庫架構 PoC）。

---

## Email Draft

**主旨**：[FW 申請] IDC ↔ GCP 跨專線開通 — 分散式資料庫 PoC (ITDBA-3596)

**收件人**：NET 維運 / Network admin team

**副本**：DBA team / 主管

```
NET 同仁：

申請開通 IDC ↔ GCP 雙向 FW 規則，作為「分散式資料庫導入 PoC」第二階段
「跨專線（X-CROSS）」場景測試之用。

== 申請範圍 ==

來源 / 目的 (雙向)：
  IDC 側 hosts:
    172.24.40.31         (driver / TPCC 壓測 client)
    172.24.40.32 / .33 / .34   (DB 節點 × 3)
    172.24.47.20         (HAProxy / monitor)

  GCP 側 hosts (asia-east1-a/b/c):
    10.160.152.11 / .12 / .13  (DB 節點 × 3)
    10.160.152.14              (HAProxy)
    10.160.152.15              (TPCC client)

方向：**雙向**（IDC → GCP 與 GCP → IDC 皆需）

== 需開通 Port (TCP，依 DB 分群) ==

【TiDB v8.5 — 6 個 port】
  2379       PD client API           (集群中控、tiup 健康檢查、TSO 取得)
  2380       PD peer RPC             (PD 6-node Raft 選舉與 region 路由同步)
  4000       TiDB SQL                (MySQL 8.0 wire protocol；client 連線)
  10080      TiDB status / metrics   (Prometheus pull、健康檢查)
  20160      TiKV server RPC         (跨 region Raft replication、coprocessor)
  20180      TiKV status / metrics   (Prometheus pull、Raft 狀態查詢)

【CockroachDB v23+ — 2 個 port】
  26257      CockroachDB SQL + RPC   (Postgres wire + 節點 Raft；同 port 雙用)
  8080       DB Console / HTTP admin (健康檢查、UI、metrics)

【YugabyteDB v2024+ — 5 個 port】
  7100       yb-master RPC           (master 跨節點 Raft 同步、tablet 路由)
  7000       yb-master HTTP / UI     (健康檢查、tablet 狀態)
  9100       yb-tserver RPC          (tserver 跨節點 Raft、tablet 副本同步)
  9000       yb-tserver HTTP / UI    (健康檢查、tablet 狀態)
  5433       YSQL (Postgres wire)    (client 連線、TPCC workload)

【共通基礎服務 (TCP/UDP) — 已驗證可通，列出以求完整性】
  22  / TCP  SSH                     (ansible 部署、tiup 控制；目前已通)
  123 / UDP chrony NTP               (跨 region 時鐘同步；目前已通，median drift 0.02ms)
  5201 / TCP iperf3                  (WAN probe；opt-in，本輪未啟用可不開)

== 統計 ==

3 家 DB 合計：**13 個 TCP port**（TiDB 6 + CRDB 2 + YBDB 5）
加共通：+22 (TCP, 已通) + 123 (UDP, 已通)

註：本 PoC 同一時間只啟用一家 DB（sequential 測試），但為避免每次切換都重申請，
建議一次性開通三家全部 port。

== 期程 ==

申請開通生效：2026-06-XX 之後越早越好（目前 PoC 待 FW 即可重啟）
預計使用期間：2026-06 ~ 2026-09（含三家 DB sweep × P-A/P-B 兩 placement，
                    9 cell-tracks × 360 rounds 全跑 ~150h sweep 時間）
PoC 結束後：可關閉

== 申請理由 / 業務影響 ==

1. 對應 PoC 階段：phase-crossregion (X-CROSS) — 驗證自有機房 ↔ GCP 跨專線
   同步式高可用 (Active-Active / Active-Standby) 是否可行。
2. 對應業務拍板：2026-06-09 D1「跨區災難復原中長期必需」之技術前置驗證。
3. 不開通的話：今天（2026-06-18）已實測，TiDB 6-node 跨 region 集群因
   PD 健康檢查跨 region 阻擋導致 raft commit ack 超時 → workload 無法穩定產數字。

== 安全 / 範圍限制 ==

- 開通範圍限上述 5 IDC IP × 5 GCP IP，非整個 VLAN。
- TCP port 一一列舉，無 ANY-ANY 申請。
- 無外部 internet 暴露：5 GCP VM 已用 IAP-only（無 external IP）。
- 結束後可立即關閉（PoC 為時間框架，非長期 prod 路徑）。

附件：
- 拓樸圖：phase-crossregion/topology/P-A.md / P-B.md
- 拍板紀錄：1_MeetingMinutes/2026-06-09-distributed-db-adoption-non-technical.md (D1)
- 驗證紀錄：phase-crossregion/SESSION-2026-06-18-iac-verify.md (今天 FW 確認阻擋)

請協助評估開通時程，謝謝。

—
wn.lin@104.com.tw
DBA team
```

---

## 補充：來自實測證據

今天（2026-06-18）已親跑 IaC 兩邊 + TiDB deploy，確認三件事：

1. **chrony NTP (123/UDP) 與 SSH (22/TCP) 已通**
   - 10-host drift gate PASS：median 0.02ms / worst 0.05ms（門檻 100/250ms）
2. **GCP ↔ IDC private network 可 ping**
   - .31 → 10.160.152.11 ICMP 7.5ms（gcloud private peering 配置正確）
3. **TiDB 跨 region 控制平面被擋**
   - g-test-poc-1 上 tidb-server log：
     `failed to get cluster id ... dial tcp 172.24.40.32:2379: i/o timeout` × 3 IDC PD
   - 三條都是 PD 2379 port 跨 region 阻擋。

→ 申請的 port 清單裡 **2379 / 2380 / 4000 / 20160 / 20180**（TiDB 跨節點 RPC 全 5 port）
   是今天直接被阻擋的，**最高優先**。CRDB / YBDB 對等 port 雖未實測但
   架構相同（每家都是 SQL port + RPC port + status port），預期同樣需要開通。

---

## 後續 follow-up

- [ ] 寄出後追蹤 ticket / 排程
- [ ] 開通生效後重啟 phase-crossregion sweep（重新 terraform apply GCP 5 VM）
- [ ] 收尾：今天殘留 IDC TiDB 集群（tpcc-tidb-vm6 metadata 含 GCP 孤兒 entries）
      下輪 GCP 重建前需先 `tiup cluster destroy tpcc-tidb-vm6` 清理
