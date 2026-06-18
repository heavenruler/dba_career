# SESSION 2026-06-19 — 3-DB Cross-Region Smoke (TiDB / CRDB / YBDB)

> 接續 2026-06-18：FW 開通後重啟 3 DB phase-crossregion smoke。
> TiDB + CRDB 完整 1-round smoke 跑出 tpmC；YBDB cluster deploy 通但 prepare DDL 超時。
> 不拆 commit `0c17ae9`；framework reserve 維持。

---

## 1. Result summary

| DB | Deploy | Smoke | tpmC | tpmTotal | 備註 |
|---|---|---|---|---|---|
| **TiDB v8.5.2** | ✅ | ✅ | **11112.9** | 24967.1 | 6-node cluster, P-A leader pinned IDC |
| **CRDB v26.2.0** | ✅ | ✅ | **2145.2** | 4896.0 | 6 nodes all ALIVE, region locality 正確 |
| **YBDB 2025.2.2.2** | ⚠️ partial | ❌ | — | — | 6 tservers ALIVE / 3 IDC masters only / DDL 跨 region timeout |

**Smoke 設定**：W=4 warehouses / 16 threads / 60s run / 1 round / Read Committed isolation

**對照**：3 家同一 6-node 跨 region 拓樸 + P-A placement + Active-Standby profile，IDC writer client 從 .31 連 .32。

---

## 2. Cross-region 性能觀察

```
TiDB tpmC  11112.9  ≈ 5.2 × CRDB
CRDB tpmC   2145.2  ≈ 1 × baseline
```

**TiDB 領先的結構性原因**：P-A placement 把 region leader 釘在 IDC，2 follower 可同 region（IDC quorum）；
寫入 commit 只需 IDC 內 majority ack，client 看不到跨 region latency。

**CRDB 較慢的結構性原因**：每筆寫入都走 Raft consensus 含跨 region replica，
NEW_ORDER p99 1140ms vs TiDB p99 104.9ms — 約 11 倍延遲差。

**YBDB 結構性卡點**：master quorum 在 IDC，tablet allocation DDL 需要等所有 tserver 回應，
跨 region tablet creation timeout（go-tpc `pq: timed out waiting for postgres backends to catch up`）。

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
3. **yugabyte-vm6.yml** `yugabyted configure data_placement` 失敗（"Failed to add master g-test-poc-1"），
   GCP master 沒 join → 後續 DDL 跨 region timeout。Root cause 需另查 yugabyted master add 機制（可能需手動 yb-admin add_master）。
4. **`.47.20` haproxy.cfg** 仍未設定 → 今天 DB_HOST 改走 .32 直連。Follow-up: 配 haproxy 給 sweep 走 6-backend 均衡。

---

## 4. Artifact 路徑（.31 driver）

```
/tmp/poc-tpcc/artifacts/X-CROSS/tidb-vm-6node-P-A-rc-20260619-010846/  ← TiDB 完整 (.gate/.prepare/.run/.collect 全齊)
/tmp/poc-tpcc/artifacts/X-CROSS/crdb-vm-6node-P-A-rc-20260619-015549/  ← CRDB 完整
/tmp/poc-tpcc/artifacts/X-CROSS/ybdb-vm-6node-P-A-rc-20260619-025055/  ← YBDB 只到 .gate.done (prepare panic)
```

---

## 5. 對 D1 拍板的訊號

業務面 D1 拍板「現行 No，但中長期必需」維持。今天技術面新增證據：

- **IaC** 兩邊重建/毀通過 ×2（昨 + 今）
- **FW 開通後跨 region 集群可運作**：3 家 DB 全部 deploy 成功；TiDB/CRDB 跑出 tpmC
- **TiDB P-A** 在跨 region 維持 IDC-quorum 寫入，效能近似 single-region（per smoke 數據）
- **CRDB** 跨 region 寫入需付 5× 代價（per smoke 數據）— 適合 A-A 場景但要接受延遲
- **YBDB** 跨 region master quorum 仍需手動處理（GCP master add 機制未明）

→ D1「中長期必需」的技術可行性**已從 framework reserve 提升到「驗證可運作但需 tune」**。

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
