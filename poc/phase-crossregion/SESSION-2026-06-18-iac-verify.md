# SESSION 2026-06-18 — IaC + Deploy 驗證 (X-CROSS, partial)

> 目的：今天內驗 GCP 5 + IDC 5 standby + 三家 DB 部署 + 1-round smoke。
> 結果：IaC 兩邊重建+毀均通過；TiDB deploy 通過；FW 阻擋 IDC↔GCP 控制平面，cross-region runtime 無法產數字；中途收尾。
> 拍板狀態：D1 仍為「現行 No」，framework reserve 維持。

---

## 1. 達成項目

| # | 項目 | 結果 |
|---|---|---|
| 1 | IDC 3 VM (l-test-poc-1/2/3) terraform destroy + apply | ✅ destroy 25s / apply 1m20s |
| 2 | IDC .31 driver + .47.20 monitor SSH/chrony check | ✅ chrony Stratum 7 / Leap Normal |
| 3 | GCP 5 VM (g-test-poc-1..5) terraform destroy + apply | ✅ 含 startup-script heredoc bug 修正並 commit |
| 4 | chrony 10-host cross-region drift gate | ✅ drift median 0.02ms / worst 0.05ms (threshold 100/250ms) |
| 5 | .47.20 disk cleanup (PMM 14GB + docker 2.7GB) | ✅ 100% → 19% |
| 6 | TiDB 6-node tiup cluster deploy (`tpcc-tidb-vm6 v8.5.2`) | ✅ 15 instances 全 topology applied |
| 7 | Placement policy `p_a_idc_majority` CREATE | ✅ `SHOW PLACEMENT` 可見 |
| 8 | TPCC prepare W=4 (smoke) | ⚠️ 50% 卡住（W=1,2 完成 / W=3,4 因跨 region raft commit 等不到 ack） |

---

## 2. 真正 blocker：FW 阻擋 IDC ↔ GCP 控制平面

```
IDC（172.24.40.0/24）↔ GCP（10.160.152.0/24）
  data plane (TiKV raft, ping-able)         : 部分可達 (icmp 7.5ms)
  control plane (PD probe, tiup health-check): 多數阻擋
  application (TiDB → PD discovery)          : 跨 region 2min timeout (ansible "Start TiDB" task 失敗)
  raft commit ack 跨 region                   : 等不到 → prepare 卡住

  →「半通」狀態：raft heartbeat 還能傳，但 cross-region commit 不可預期慢
```

**證據**：
- `tiup cluster display tpcc-tidb-vm6` 報 GCP 3 PD + 1 TiDB "Down" (但 GCP 本地 systemctl active)
- TiDB log on g-test-poc-1：`failed to get cluster id ... dial tcp 172.24.40.32:2379: i/o timeout` × 3 IDC PD
- prepare TPCC W=4 在 warehouse 3-4 階段停滯 ~5 min 無進展

---

## 3. 修正過程

| commit | 內容 |
|---|---|
| `61311cd` | iac-gcp/main.tf startup-script `<<-EOF` 內 nested heredoc（PROXYEOF / UNIT_EOF）indent 對齊 → `[Unit]` 與 outer EOF 都置 col 6，HCL 統一 strip 6 |
| `61311cd` | phase-crossregion/scripts/gate-chrony-cross-region.sh KeyError fix（drift empty 時 if drift: 後再讀） |
| (uncommitted) | phase-crossregion/scripts/run-vm6-suite.sh 加 `GATE_SKIP=1` env 支援（gate 從 .31 跑時無 IAP tunnel） |

### Workarounds（未進 commit，臨時應變）

- known_hosts 殘留舊 key → MAC + .31 ssh-keygen -R + 重 prime
- .31 self-ssh：append `/root/.ssh/id_rsa.pub` 至 authorized_keys
- .32 tiup self-ssh：append tiup `/root/.ssh/id_rsa.pub` 至 authorized_keys（playbook bug：authorize task 漏 .32 自己）
- .47.20 haproxy 未配置 → smoke 改 DB_HOST=172.24.40.32 直連繞過
- Playbook 缺 `-e tidb_placement=P-A` 預設 → 補 flag

---

## 4. Cleanup 狀態

```
GCP            terraform destroy → 0 VMs (terraform.tfstate clean)
IAP tunnels    bash tunnel.sh stop → 5 tunnel processes killed

殘留：
  IDC 3 VM .32/.33/.34 + tpcc-tidb-vm6 集群（half-broken metadata）
  placement policy p_a_idc_majority（無 GCP region peer 可分配）
  tpcc DB (W=1,2 部分資料)
  .47.20 haproxy 仍 inactive（從未啟動 / 從未配置）
```

---

## 5. D1 框架狀態（不變）

- 業務面 D1 拍板「現行 No」維持（2026-06-09）
- 技術面今天驗證：
  - IaC 兩邊框架可重建可毀（**證明可行**）
  - 跨 region 同步 cluster：FW 解開前無法產數字（**技術 blocker 移到 FW**）
- 不拆除 commit `0c17ae9`；framework reserve 持續

---

## 6. 下一輪 prereq

1. **FW 規則開放**：IDC ↔ GCP 的 PD (2379)、TiDB (4000)、TiKV (20160-20180) 雙向 — sweep 跨 region 必須通
2. **idc-haproxy on .47.20**：需 haproxy.cfg + start service（或業務面確認 sweep 用直連而不要走 haproxy）
3. **tidb-vm6.yml playbook**：補 control node (.32) 自己 authorize 自己 task；補 `-e tidb_placement=` 預設或 require check
4. **Cleanup .31 / .32 stale tpcc state**：tiup destroy tpcc-tidb-vm6 + drop tpcc database（下次 GCP rebuild 時順手做）
