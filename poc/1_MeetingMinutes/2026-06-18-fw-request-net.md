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
理由：3 家 DB 都是 mesh-topology cluster（每節點同時為 client + server），PD/master
      Raft 選舉與副本同步必須雙向；單向開只能達到「client → DB」一半流量。

== Source / Destination 網段 (CIDR) ==

  IDC 側（2 網段）：
    172.24.40.0/24   ← .31 driver + .32/.33/.34 DB
    172.24.47.0/24   ← .20 haproxy/monitor

  GCP 側（1 網段）：
    10.160.152.0/24  ← .11-.13 DB + .14 haproxy + .15 client

  雙向 rule：(IDC 2 segs) ↔ (GCP 1 seg)

== 需開通 Port range (TCP，9 rule 整合) ==

  Rule  Port range    Proto  涵蓋 service                         備註
  ─────────────────────────────────────────────────────────────────────────
  R1    2379-2380     TCP    TiDB PD client + peer                集群中控 / Raft 選舉
  R2    4000          TCP    TiDB SQL                             MySQL wire
  R3    5433          TCP    YBDB YSQL                            Postgres wire (client)
  R4    7000-7100     TCP    YBDB yb-master HTTP + RPC            UI + 跨節點同步
  R5    8080          TCP    CRDB DB Console                      HTTP admin / UI
  R6    9000-9100     TCP    YBDB yb-tserver HTTP + RPC           UI + 跨節點同步
  R7    10080         TCP    TiDB status / metrics                Prometheus pull
  R8    20160-20180   TCP    TiKV RPC + status                    跨 region Raft + metrics
  R9    26257         TCP    CRDB SQL + 節點 Raft                  同 port 雙用 (Postgres wire)

  合計：9 rule / 涵蓋 13 個具名 port

== 優先序（如 NET 一次無法開齊）==

  P0 (跨節點 cluster mesh 必須，6 rule)：
    R1 (TiDB PD)、R8 (TiKV)、R4 (YBDB master)、R6 (YBDB tserver)、R9 (CRDB)、
    R2/R3 (TiDB / YBDB client)

  P1 (status/HTTP UI，建議開但非阻塞，3 rule)：
    R5 (CRDB HTTP)、R7 (TiDB status)、(R4/R6 HTTP 部分 — 已含於 P0 range)

== 共通基礎服務 (TCP/UDP) — 已驗證可通 ==

  22  / TCP  SSH                ansible 部署、tiup 控制 (目前已通)
  123 / UDP chrony NTP          時鐘同步 (目前已通，median drift 0.02ms)
  5201 / TCP iperf3 (opt-in)    WAN probe (本輪未啟用，可暫不開)

註：本 PoC 同一時間只啟用一家 DB（sequential 測試），但為避免每次切換都重申請，
建議一次性開通 9 rule 全部 port range。

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

- 開通範圍限上述兩個 IDC /24 網段 × 一個 GCP /24 網段（host 級別本 PoC 5×5 = 25 對）。
- TCP port range 9 rule，非 ANY-ANY 申請；最寬單一 range 為 7000-7100 / 9000-9100 (各 101 port，YBDB master/tserver 雙服務同段)。
- 無外部 internet 暴露：5 GCP VM 已用 IAP-only（無 external IP）。
- 結束後可立即關閉（PoC 為時間框架，非長期 prod 路徑）。

附件：
- 拓樸圖：phase-crossregion/topology/P-A.md / P-B.md
- 拍板紀錄：1_MeetingMinutes/2026-06-09-distributed-db-adoption-non-technical.md (D1)
- 驗證紀錄：phase-crossregion/SESSION-HISTORY.md (06-18 iac-verify，今天 FW 確認阻擋)

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

→ 申請的 port range 裡 **R1 (2379-2380) / R2 (4000) / R8 (20160-20180)**（TiDB 跨節點 RPC 全 5 port）
   是今天直接被阻擋的，**最高優先**。CRDB / YBDB 對等 port range（R3/R4/R6/R9）雖未實測但
   架構相同（每家都是 SQL port + RPC port + status port），預期同樣需要開通。

---

## 後續 follow-up

- [ ] 寄出後追蹤 ticket / 排程
- [ ] 開通生效後重啟 phase-crossregion sweep（重新 terraform apply GCP 5 VM）
- [ ] 收尾：今天殘留 IDC TiDB 集群（tpcc-tidb-vm6 metadata 含 GCP 孤兒 entries）
      下輪 GCP 重建前需先 `tiup cluster destroy tpcc-tidb-vm6` 清理
