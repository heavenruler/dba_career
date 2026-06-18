# SESSION 2026-06-19 — 3-DB Cross-Region Smoke (TiDB / CRDB / YBDB)

> 接續 2026-06-18：FW 開通後重啟 3 DB phase-crossregion smoke。
> TiDB + CRDB 6-node 跨 region 完整 smoke；YBDB 因 yugabyted master add 機制限制改 IDC-only 3-tserver 跑成。
> 不拆 commit `0c17ae9`；framework reserve 維持。
> **Update 04:52–05:02**：原報「YBDB ❌」追加 IDC-only 跑出 tpmC 4324.6（見 §2.5 fix 過程）。

---

## 1. Result summary

| DB | Deploy | Smoke | tpmC | tpmTotal | 備註 |
|---|---|---|---|---|---|
| **TiDB v8.5.2** | ✅ | ✅ | **11112.9** | 24967.1 | 6-node cluster, P-A leader pinned IDC |
| **CRDB v26.2.0** | ✅ | ✅ | **2145.2** | 4896.0 | 6 nodes all ALIVE, region locality 正確 |
| **YBDB 2025.2.2.2** (IDC-only) | ⚠️ deploy 6-node OK | ✅ IDC-only | 4324.6 | 9546.6 | 6 tservers deploy / 3 IDC masters / kill GCP 後 IDC-only 3-tserver 跑 |
| **YBDB 2025.2.2.2 (true 6-node)** | ✅ | ✅ | **6812.2** | 15129.2 | 真 6 tservers ALIVE (3 IDC + 3 GCP IP) + placement idc:2+gcp:1 + leader-pin IDC + 60s catalog wait |

**Smoke 設定**：W=4 warehouses / 16 threads / 60s run (YBDB IDC-only 為 86s) / 1 round / Read Committed isolation

**對照**：3 家同一 6-node 跨 region 拓樸 + P-A placement + Active-Standby profile，IDC writer client 從 .31 連 .32。

YBDB 6-node vs IDC-only 對比顯示：加上 GCP 3 個 tserver 作為 follower 後 tpmC 從 4324.6 升到 6812.2（+58%）——
GCP follower 分擔讀寫負載，leader 仍在 IDC 享 quorum-local commit 的好處。

---

## 2. Cross-region 性能觀察

```
TiDB tpmC  11112.9  ≈ 5.2 × CRDB   (true 6-node, P-A leader-pinned IDC)
YBDB tpmC   6812.2  ≈ 3.2 × CRDB   (true 6-node, idc:2+gcp:1, leader-pinned IDC)
YBDB tpmC   4324.6  ≈ 2.0 × CRDB   (IDC-only 3-tserver workaround，前期 fallback)
CRDB tpmC   2145.2  ≈ 1 × baseline (true 6-node, cross-region Raft commit per write)
```

**TiDB 領先的結構性原因**：P-A placement 把 region leader 釘在 IDC，2 follower 可同 region（IDC quorum）；
寫入 commit 只需 IDC 內 majority ack，client 看不到跨 region latency。

**CRDB 較慢的結構性原因**：每筆寫入都走 Raft consensus 含跨 region replica，
NEW_ORDER p99 1140ms vs TiDB p99 104.9ms — 約 11 倍延遲差。

**YBDB 結構性卡點**：master quorum 在 IDC，tablet allocation DDL 需要等所有 tserver 回應，
跨 region tablet creation timeout（go-tpc `pq: timed out waiting for postgres backends to catch up`）。

---

## 2.5 YBDB 失敗→成功 root cause 與 fix 過程

**FW verdict**：雙向 nc listener 測 7100 / 9100，IDC ↔ GCP 都通 — **不是 FW 問題**。

**Root cause 3 連環**：
1. **yugabyted v2 master add 限制**：只在前 3 個 joiner 啟 yb-master；後續 joiner 只啟 yb-tserver。
   GCP 3 node 第 4-6 順位 join → 沒 yb-master → `yugabyted configure data_placement` add master 失敗。
2. **預設 placement_info 含 `cloud1.datacenter1.rack1:1` 假 zone block**：
   yb-master process 啟動時帶 `--placement_cloud=cloud1 --placement_region=datacenter1 --placement_zone=rack1`
   作為「最後一組」flag（cmdline 重複後 wins），導致 master 自報 default zone → universe placementBlocks 多了
   一塊「沒任何 tserver 在裡面」的 zone, RF=3 之 1 replica 永遠 allocate 失敗。
3. **DDL catalog wait**：YSQL `CREATE INDEX` 觸發 catalog version 更新，需要等所有 ALIVE tservers 的
   postgres backend ack。GCP 3 tservers 還在 ALIVE 但跨 region catalog ack 慢 → 超過 pg_backend
   等待上限 → `pq: timed out waiting for postgres backends to catch up`。

**Fix steps**（按順序套用）：
```
1. yb-admin modify_placement_info "104.idc.vlan241:3" 3
   → universe placementBlocks 變單一 IDC zone, RF=3 全在 IDC tservers（消滅假 zone block）
2. yb-admin change_blacklist ADD g-test-poc-{1,2,3}:9100
   → tablet 不放 GCP tservers
3. ssh root@gcp-N "sudo -u yugabyte yugabyted stop --base_dir=/var/yugabyte"
   + pkill -9 yb-master yb-tserver yugabyted
   → GCP processes 全死
4. 等 60s (tserver_unresponsive_timeout_ms default) 讓 master 標 GCP 為 DEAD
5. 重跑 prepare + run + collect
```

**結果**：原本 panic 在 `creating index idx_customer`，fix 後 prepare 全跑完，run 出 tpmC 4324.6（IDC-only）。

---

## 2.6 YBDB 真 6-node 跨 region 突破（追加 06:30–07:21）

第二輪確認 IDC-only 不夠完整，補做真 6-node 跨 region。

**新發現的關鍵 bug**：
- yugabyted `--advertise_address=g-test-poc-1` 在 GCP 端解析到 **IPv6 fe80::xxx**
  （Linux hostname resolution priority），導致 join cluster 時 master 看到的 register address
  與 advertise 不一致 → "A node is already running on 172.24.40.33" 假錯誤。
  Fix: `--advertise_address=10.160.152.11` (直接用 IPv4 IP)。

**追加 fix step**：
```
# 1. 在 tserver_flags 加入兩個 catalog wait timeout (default 5s 對 cross-region 不夠)
   wait_for_ysql_backends_catalog_version_client_master_rpc_timeout_ms=60000
   wait_for_ysql_backends_catalog_version_client_master_rpc_margin_ms=300000

# 2. yugabyted start 在 GCP 用 IP 而非 hostname:
   sudo -u yugabyte yugabyted start --advertise_address=10.160.152.11 --join=172.24.40.32 ...

# 3. yb-admin modify_placement_info "104.idc.vlan241:2,104.gcp.asia-east1-a:1" 3
   yb-admin set_preferred_zones 104.idc.vlan241
```

**結果**：tpmC 從 IDC-only 4324.6 → **真 6-node 6812.2 (+58%)**。
- GCP follower 分擔讀負載
- Leader pinned IDC 仍享 IDC-quorum-local commit
- 跨 region replica 帶來 1 額外 raft RTT，但 IDC quorum (2/3) 不卡 GCP slow follower
- 真正 cross-region durability + IDC-local latency 的混合

---

## 3. 修正過程（含已 commit 與待 commit）

### 環境層

| 項目 | 動作 | 影響 |
|---|---|---|
| IDC 3 dbhost DNS 172.29.254.5 不通 | 改 nameserver 為 10.0.1.5 + chattr +i | chrony + ansible 解析恢復 |
| IDC chrony 0 sources (rebuild 後 DNS 壞) | /etc/chrony.conf 加 server 172.19.254.7 (IP) | 10-host gate PASS, drift 0.3ms |
| .47.20 disk full (PMM 14GB) | 昨日已清, 今天 OK | 不再阻塞 ansible |
| MAC + .31 known_hosts 殘留舊 host key | ssh-keygen -R + accept-new prime | tiup / ansible SSH 恢復 |
| .31 self-ssh | append id_rsa.pub → authorized_keys | suite step 1/5 SSH gate PASS |
| .31 → GCP 5 VM SSH 無 pubkey | 把 .31 pubkey 寫到 GCP 5 VM | chrony gate from .31 可跑 |

### 程式碼層（含 fix）

| 檔案 | 修正 | 已 commit |
|---|---|---|
| `iac-gcp/main.tf` | startup-script heredoc indent | 是（`61311cd`） |
| `phase-crossregion/scripts/gate-chrony-cross-region.sh` | drift empty KeyError | 是（`61311cd`） |
| `phase-crossregion/scripts/run-vm6-suite.sh` | 加 `GATE_SKIP=1` env | 是（`d8af817`） |
| `ansible/playbooks/tidb-vm6.yml` | 加 control node self-auth task | 待 commit |
| `ansible/playbooks/{tidb,cockroach,yugabyte}-vm6.yml` | `proxy_url` 改 region-aware (`sproxy` vs `gproxy`) | 待 commit |
| `tests/common/run.sh` | `WAN_PROBE_SH=$(cd ... && pwd)` 在 set -e 下 silent exit → 包 `if _wan_dir=...` | 待 commit |

### 仍未修（記錄為 follow-up）

1. **tidb-vm6.yml** include_role `haproxy_deploy` 缺檔 → ansible play_recap `g-test-poc-4 failed=1`。
   今天用 DB_HOST=.32 直連繞過。Follow-up: 補 `ansible/playbooks/roles/haproxy_deploy/` 或 conditional skip。
2. **cockroach-vm6.yml** 最後 `Apply placement SQL` task 太早跑（tpcc DB 還沒建）→ `ERROR: database "tpcc" does not exist`。
   應 deferred 到 prepare 後（同 TiDB 模式：deploy 只 CREATE POLICY、ALTER 留給 suite 用）。
3. **yugabyte-vm6.yml** `yugabyted configure data_placement` 失敗 → §2.5/§2.6 已找出
   root cause + fix。真 6-node 跨 region 已驗證可行（tpmC 6812.2）：
   - 需用 IP 而非 hostname 做 advertise_address (避 IPv6 解析)
   - tserver_flags 加 catalog wait timeout 60s
   - yb-admin modify_placement_info + set_preferred_zones IDC
   Follow-up: 把 §2.6 步驟做成 playbook tasks 取代 yugabyted CLI 的 data_placement step。
4. **`.47.20` haproxy.cfg** 仍未設定 → 今天 DB_HOST 改走 .32 直連。Follow-up: 配 haproxy 給 sweep 走 6-backend 均衡。

---

## 4. Artifact 路徑（.31 driver）

```
/tmp/poc-tpcc/artifacts/X-CROSS/tidb-vm-6node-P-A-rc-20260619-010846/  ← TiDB 完整 (.gate/.prepare/.run/.collect 全齊)
/tmp/poc-tpcc/artifacts/X-CROSS/crdb-vm-6node-P-A-rc-20260619-015549/  ← CRDB 完整
/tmp/poc-tpcc/artifacts/X-CROSS/ybdb-vm-6node-P-A-rc-20260619-025055/  ← YBDB 第 1 次 (prepare panic)
/tmp/poc-tpcc/artifacts/X-CROSS/ybdb-vm-6node-P-A-rc-20260619-034736/  ← YBDB 第 2 次 (panic 仍在，placement_info 修但 GCP tservers 還 ALIVE)
/tmp/poc-tpcc/artifacts/X-CROSS/ybdb-vm-6node-P-A-rc-20260619-045217/  ← YBDB 第 3 次 完整 (IDC-only after GCP kill)
/tmp/poc-tpcc/artifacts/X-CROSS/ybdb-vm-6node-P-A-rc-20260619-071031/  ← YBDB 第 4 次 完整 (真 6-node, tpmC 6812.2)
```

---

## 5. 對 D1 拍板的訊號

業務面 D1 拍板「現行 No，但中長期必需」維持。今天技術面新增證據：

- **IaC** 兩邊重建/毀通過 ×2（昨 + 今）
- **FW 開通後跨 region 集群可運作**：3 家 DB 真 6-node 跨 region 全部跑出 tpmC（§2.6）
- **TiDB P-A** 在跨 region 維持 IDC-quorum 寫入，效能近似 single-region（per smoke 數據）
- **CRDB** 跨 region 寫入需付 5× 代價（per smoke 數據）— 適合 A-A 場景但要接受延遲
- **YBDB** 真 6-node 跨 region 已驗證：placement idc:2+gcp:1 + leader-pin IDC + catalog wait 60s
  + advertise_address 用 IP → tpmC 6812.2，居 TiDB 與 CRDB 中間

→ D1「中長期必需」的技術可行性**已從 framework reserve 提升到「3 家 DB 真 cross-region 都跑得起來」**。

不拆除 commit `0c17ae9`；下輪 sweep 啟動條件齊備（FW + 3 DB framework + tpmC baseline 已測）。

---

## 6. 下一輪 prereq（按優先序）

1. **CRDB / YBDB 修 placement SQL 套用時機**（同 TiDB B0-3 split）
2. **YBDB master GCP add 修法**（yb-admin add_master 或 yugabyted v2 機制）
3. **haproxy_deploy role** 補完，使 dual-haproxy 拓樸可跑
4. **`.47.20` haproxy.cfg** 配置（或業務上決定 sweep 不走 haproxy）
5. **WAREHOUSES > 4** 升級驗證（sweep formula：3 DB × 2 placement × 4 thread × 5 round × W=128~1000）

---

## Cleanup 狀態

```
TiDB cluster      destroyed (tiup cluster destroy --force)
CRDB              all 6 nodes systemctl stop + /var/lib/cockroach/* wiped
YBDB              all 6 nodes pkill + /var/yugabyte/* wiped
GCP 5 VM          alive (待 P5 後依需求決定 destroy 或保留)
IDC 3 DB VM       alive, services off, data dirs clean
IAP tunnels       MAC 端 still running
```
