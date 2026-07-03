# phase-crossregion — Session 執行歷史（歸檔）

> 本檔由 SESSION-2026-06-{18,19,21,22}*.md 合併歸檔（原檔已刪）。
> 依時序記錄跨區部署驗證過程；durable 結論見最上方「關鍵結論速查」。

## 關鍵結論速查（不隨時間失效）

- **FW blocker（06-18）**：IDC（172.24.40.0/24）↔ GCP（10.160.152.0/24）**控制平面被擋**是最初的真正 blocker。
  data plane（TiKV raft、icmp 7.5ms）部分可達，但 control plane（PD probe 2379、tiup health-check）多數被阻，
  TiDB 跨 region PD discovery 2min timeout，raft commit ack 等不到 → TPCC prepare 卡在 W=3/4。
  **解法**：開放 IDC↔GCP 雙向 PD(2379)/TiDB(4000)/TiKV(20160-20180)。FW 開通後（06-19）3 家 DB 真 6-node 跨 region 全可運作。

- **YBDB 部署修正（06-19）**——三連環 root cause 與正確設定：
  1. **yugabyted v2 master add 限制**：只在前 3 個 joiner 啟 yb-master，後續 joiner 只啟 yb-tserver
     → GCP node（第 4-6 順位）沒 yb-master → `yugabyted configure data_placement` 加 master 失敗。
  2. **IPv6 解析陷阱**：`--advertise_address=g-test-poc-1` 在 GCP 端解析到 IPv6 `fe80::xxx`，register 與 advertise 不一致
     → 假錯誤 "A node is already running on 172.24.40.33"。**Fix：advertise_address 直接用 IPv4 IP**（如 `10.160.152.11`）。
  3. **catalog wait timeout**：cross-region catalog ack 慢，YSQL DDL（CREATE INDEX）觸發
     `pq: timed out waiting for postgres backends to catch up`（default 5s 不夠）。**Fix：tserver_flags 加**
     `wait_for_ysql_backends_catalog_version_client_master_rpc_timeout_ms=60000`
     + `..._margin_ms=300000`。
  - placement 正解：`yb-admin modify_placement_info "104.idc.vlan241:2,104.gcp.asia-east1-a:1" 3`
    + `yb-admin set_preferred_zones 104.idc.vlan241`（leader pin IDC）。

- **determinism（06-21 / 06-22）**：
  - **W=4 短測變異達 ±50%，不可作排名/baseline**。root cause = 16 threads × 4 W = 4 threads/W 高 lock contention，
    throughput 由 lock release timing 決定（timing-dependent，無法消除）。實測 TiDB run-1/run-2 為 1552.2 → 9719.2（+526%）。
  - **須用 W=128 baseline**（user baseline）：16 threads × 128 W = 0.125 threads/W，contention 趨近 0，throughput 由真實 latency 決定。
  - **通過閾值 CV ≤ 10%**（≤5% 穩定可直接進 W=128；5-10% 可接受並標註；>10% NG 先排查）。
  - **CV 計算公式**（06-22）：
    ```python
    import statistics
    tpmc = [r1, r2, r3, r4, r5]   # 5 round 結果
    mean = statistics.mean(tpmc)
    stdev = statistics.stdev(tpmc)
    cv = stdev / mean             # → 印成 CV%
    ```
  - 主 noise 來源（Codex round-1，06-22）判定不是 W 大小，而是「每輪 redeploy」→ 改採同 cluster suite 模式。

- **兩段式驗證協議 Path C → Path A（06-22）**：
  - Step 1（Path C）：同 cluster 一次 deploy+prepare，連跑 5 輪 W=4 RUN_SEC=300 THREADS=16，算 CV，per DB CV ≤ 10% 通過。
  - Step 2（Path A）：Step 1 通過才觸發，3 DB × W=128 × 1 suite（20m warmup + 5 rounds × 5min），取 R2-R5 median + CV，預估 16-18h。

- **go-tpc 無原生 warmup flag（06-22）**：實測 `--warmup` / `--ramp-up` / `--keying-time` / `--think-time` **皆不存在**；
  keying/think time 由 `--wait` 控制。**warmup 須用外部 loop（短跑丟棄 R1）**，非旗標。go-tpc 亦無原生 p50/p99 輸出。

- **VM rebuild 後 host key 輪替（07-02）**：phase1 重建 VM 必然輪替 host key，**Mac 與 .31 的 known_hosts
  都要先清再 accept-new**，否則 ProxyJump/直連被拒且症狀詭異（探測 ERR、gate FAIL、boot_id=?）。
  首次跑會過（accept-new 無舊 key）、第二次起才炸——這類 bug 只有「重跑第二輪」才現形。
  已入 `phase1-wait-via-31` 自動清除。同場加映：**「從未 live 跑過的 code 一律當作會炸」**——
  7/2 三輪 DRY_RUN 抓出 6 個 planner 看不到的 bug，全是 make 摺行 / IAP 殘留 / 字典序這類實跑才現形的類型。

- **GCP startup（cloud-init）耗時口徑（07-02）**：dnf 精簡後（單 transaction + no-weak-deps + 3 retry +
  砍 10 個非必要包）READY 區間 **100–390s**（視 gproxy squid 快取與時段），wait 上限 1200s。
  慢的從來不是 GCP 開機，是 dnf 過 proxy。

- **make 一律從 poc/ 層跑（07-03）**：`poc/Makefile` 是頂層入口（include phase-crossregion/Makefile），
  recipe 內相對路徑（iac-idc/ansible/results/tests）都以 poc/ 為基準。從 phase-crossregion/ 內跑 make
  會 `cd: iac-idc: No such file or directory`——destroy 因 `-` 前綴被 ignored 靜默略過、apply 才炸。
  正確：`make -C <abs>/poc <target>`。

- **iperf3 接線與埠選擇（07-03）**：wan-probe 的 iperf3 一直 skip 有兩層原因——
  ①IDC 端 binary 未裝（`idc-iperf3-bootstrap.sh` 早存在但未接 Makefile）；
  ②**專線 FW 沒開 5201**（fw-request 2026-06-18 行 80 明載「本輪未啟用」）——就算裝了 binary，
  forward/reverse 都會 connect timeout。解法：埠改用 **R8（20160-20180，TiKV range）內閒置的 20170**
  （TiKV 每台僅佔 20160 service + 20180 status），雙向已通免新 FW 申請；server 改**臨時起**
  （`iperf3 -s -1` 單次連線即退 + timeout 30 兜底），不留常駐 daemon，避開 bootstrap script
  自述的 0.0.0.0 常駐監聽安全顧慮。安裝歸屬：GCP=phase1 cloud-init（main.tf 已含+rpm -q verify）、
  IDC=phase2 新 target `phase2-iperf3-idc`（--install-only，idempotent，rebuild 後自動補）。
  **未 live 驗證**（改時 VM 已拆）——下個視窗 warmup-post 會自動首驗，屆時當作會炸盯著。

- **bug #14 — ALTER→freeze race：placement ALTER 後立即 freeze 撞排水 fail-closed（07-03）**：
  wrapper 在 table-level placement ALTER + leader gate 後立即呼叫 freeze-tidb.sh，小資料（W=1）時
  PD 仍有 1 個 in-flight operator，150s 排水逾時 → suite FAIL。W=128 大資料輪反而不踩（收斂時間長，
  operators 早清空）——**小 W smoke 比正式輪更容易踩此 race**。修法：wrapper 於 FREEZE_SCRIPT 前
  加「等 PD operators==0」pre-wait（max 300s fail-closed）；freeze 內 150s 語意不動，另加
  `FREEZE_DRAIN_MAX_SEC` env 可調。live 驗證 PASS（20260703T143409 W=1 全鏈 DONE）。
  同場教訓：**gate-isolation 的 tiup start 若中途炸（TiKV 跨區 2min timeout），tidb-server 不會被啟動**
  ——PD/TiKV Up 但 4000 連線被拒，補救須 `bash -lc "tiup cluster start tpcc-tidb-vm6 --wait-timeout 300"`（login shell，.32 上）。

- **bug #13 — wan-probe.sh GCP 定址殘留 IAP tunnel（07-03）**：wan-probe.sh 的 `ssh_gcp()` 寫死
  `ssh -p 1221x root@localhost`（IAP tunnel 埠轉發），detached 在 .31 跑無 tunnel → GCP chrony/netdev 全 rc=255；
  這是 **bug #11（CLUSTER_HOSTS）的漏網同類**，另一支腳本沒跟著改。同時 netdev 寫死 `WAN_NIC=eth0`，
  但 **IDC 主網卡是 `ens33`、GCP 才是 `eth0`** → IDC netdev 抓空行（rc=0 卻標 failed）。
  **修法**：ssh_gcp 改直連內網 IP（.15/.11/.14），比照 CLUSTER_HOSTS；netdev 改 `WAN_NIC=auto` 遠端偵測
  default-route NIC 逐台適配；iperf3 缺 binary 改資訊性 skip（opt-in 工具缺席≠probe 失敗，不寫 failed.txt，
  IDC 端目前無 iperf3）。實測 6 host chrony（GCP stratum=3 offset 有值）+ 6 host netdev（rx/tx 有值）全通、
  `all probes succeeded` 無 failed.txt。修在 local repo，隨下輪 win-tidb-as-detach rsync 生效（未 live 全鏈驗證前當作會炸）。

---

## 2026-06-18 — IaC verify

> 目的：一天內驗 GCP 5 + IDC 5 standby + 三家 DB 部署 + 1-round smoke。
> 結果：IaC 兩邊重建+毀均通過；TiDB deploy 通過；FW 阻擋 IDC↔GCP 控制平面，cross-region runtime 無法產數字；中途收尾。
> 拍板狀態：D1 仍為「現行 No」，framework reserve 維持。

### 達成項目

| # | 項目 | 結果 |
|---|---|---|
| 1 | IDC 3 VM (l-test-poc-1/2/3) terraform destroy + apply | destroy 25s / apply 1m20s |
| 2 | IDC .31 driver + .47.20 monitor SSH/chrony check | chrony Stratum 7 / Leap Normal |
| 3 | GCP 5 VM (g-test-poc-1..5) terraform destroy + apply | 含 startup-script heredoc bug 修正並 commit |
| 4 | chrony 10-host cross-region drift gate | drift median 0.02ms / worst 0.05ms (threshold 100/250ms) |
| 5 | .47.20 disk cleanup (PMM 14GB + docker 2.7GB) | 100% → 19% |
| 6 | TiDB 6-node tiup cluster deploy (`tpcc-tidb-vm6 v8.5.2`) | 15 instances 全 topology applied |
| 7 | Placement policy `p_a_idc_majority` CREATE | `SHOW PLACEMENT` 可見 |
| 8 | TPCC prepare W=4 (smoke) | 50% 卡住（W=1,2 完成 / W=3,4 因跨 region raft commit 等不到 ack） |

### 真正 blocker：FW 阻擋 IDC ↔ GCP 控制平面

```
IDC（172.24.40.0/24）↔ GCP（10.160.152.0/24）
  data plane (TiKV raft, ping-able)         : 部分可達 (icmp 7.5ms)
  control plane (PD probe, tiup health-check): 多數阻擋
  application (TiDB → PD discovery)          : 跨 region 2min timeout (ansible "Start TiDB" task 失敗)
  raft commit ack 跨 region                   : 等不到 → prepare 卡住

  →「半通」狀態：raft heartbeat 還能傳，但 cross-region commit 不可預期慢
```

**證據**：
- `tiup cluster display tpcc-tidb-vm6` 報 GCP 3 PD + 1 TiDB "Down"（但 GCP 本地 systemctl active）
- TiDB log on g-test-poc-1：`failed to get cluster id ... dial tcp 172.24.40.32:2379: i/o timeout` × 3 IDC PD
- prepare TPCC W=4 在 warehouse 3-4 階段停滯 ~5 min 無進展

### 修正過程

| commit | 內容 |
|---|---|
| `61311cd` | iac-gcp/main.tf startup-script `<<-EOF` 內 nested heredoc（PROXYEOF / UNIT_EOF）indent 對齊 → `[Unit]` 與 outer EOF 都置 col 6，HCL 統一 strip 6 |
| `61311cd` | phase-crossregion/scripts/gate-chrony-cross-region.sh KeyError fix（drift empty 時 if drift: 後再讀） |
| (uncommitted) | phase-crossregion/scripts/run-vm6-suite.sh 加 `GATE_SKIP=1` env 支援（gate 從 .31 跑時無 IAP tunnel） |

**Workarounds（未進 commit，臨時應變）**：
- known_hosts 殘留舊 key → MAC + .31 ssh-keygen -R + 重 prime
- .31 self-ssh：append `/root/.ssh/id_rsa.pub` 至 authorized_keys
- .32 tiup self-ssh：append tiup `id_rsa.pub` 至 authorized_keys（playbook bug：authorize task 漏 .32 自己）
- .47.20 haproxy 未配置 → smoke 改 DB_HOST=172.24.40.32 直連繞過
- Playbook 缺 `-e tidb_placement=P-A` 預設 → 補 flag

### Cleanup 狀態

```
GCP            terraform destroy → 0 VMs (terraform.tfstate clean)
IAP tunnels    bash tunnel.sh stop → 5 tunnel processes killed

殘留：
  IDC 3 VM .32/.33/.34 + tpcc-tidb-vm6 集群（half-broken metadata）
  placement policy p_a_idc_majority（無 GCP region peer 可分配）
  tpcc DB (W=1,2 部分資料)
  .47.20 haproxy 仍 inactive（從未啟動 / 從未配置）
```

### 下一輪 prereq

1. **FW 規則開放**：IDC↔GCP 的 PD(2379)、TiDB(4000)、TiKV(20160-20180) 雙向 — sweep 跨 region 必須通
2. **idc-haproxy on .47.20**：需 haproxy.cfg + start service（或確認 sweep 用直連不走 haproxy）
3. **tidb-vm6.yml playbook**：補 control node(.32) 自己 authorize 自己 task；補 `-e tidb_placement=` 預設或 require check
4. **Cleanup .31 / .32 stale tpcc state**：tiup destroy tpcc-tidb-vm6 + drop tpcc database

---

## 2026-06-19 — 3DB smoke

> 接續 06-18：FW 開通後重啟 3 DB phase-crossregion smoke。
> TiDB + CRDB 6-node 跨 region 完整 smoke；YBDB 一度因 yugabyted master add 限制改 IDC-only，後補做真 6-node 跑成。
> 不拆 commit `0c17ae9`；framework reserve 維持。

### Result summary

| DB | Deploy | Smoke | tpmC | tpmTotal | 備註 |
|---|---|---|---|---|---|
| **TiDB v8.5.2** | OK | OK | **11112.9** | 24967.1 | 6-node cluster, P-A leader pinned IDC |
| **CRDB v26.2.0** | OK | OK | **2145.2** | 4896.0 | 6 nodes all ALIVE, region locality 正確 |
| **YBDB 2025.2.2.2 (IDC-only)** | deploy 6-node OK | IDC-only OK | 4324.6 | 9546.6 | 6 tservers deploy / 3 IDC masters / kill GCP 後 IDC-only 3-tserver 跑 |
| **YBDB 2025.2.2.2 (true 6-node)** | OK | OK | **6812.2** | 15129.2 | 真 6 tservers ALIVE (3 IDC + 3 GCP IP) + placement idc:2+gcp:1 + leader-pin IDC + 60s catalog wait |

**Smoke 設定**：W=4 warehouses / 16 threads / 60s run（YBDB IDC-only 為 86s）/ 1 round / Read Committed isolation。
IDC writer client 從 .31 連 .32。
YBDB 6-node vs IDC-only：加上 GCP 3 tserver 作 follower 後 tpmC 從 4324.6 升到 6812.2（+58%）。

### Cross-region 性能觀察

```
TiDB tpmC  11112.9  ≈ 5.2 × CRDB   (true 6-node, P-A leader-pinned IDC)
YBDB tpmC   6812.2  ≈ 3.2 × CRDB   (true 6-node, idc:2+gcp:1, leader-pinned IDC)
YBDB tpmC   4324.6  ≈ 2.0 × CRDB   (IDC-only 3-tserver workaround，前期 fallback)
CRDB tpmC   2145.2  ≈ 1 × baseline (true 6-node, cross-region Raft commit per write)
```

- **TiDB 領先**：P-A placement 把 region leader 釘在 IDC，2 follower 可同 region（IDC quorum），寫入 commit 只需 IDC 內 majority ack，client 看不到跨 region latency。
- **CRDB 較慢**：每筆寫入走 Raft consensus 含跨 region replica。NEW_ORDER p99 1140ms vs TiDB p99 104.9ms（約 11 倍延遲差）。
- **YBDB 卡點**：master quorum 在 IDC，tablet allocation DDL 需等所有 tserver 回應，跨 region tablet creation timeout（`pq: timed out waiting for postgres backends to catch up`）。

### YBDB 失敗→成功 root cause 與 fix 過程

**FW verdict**：雙向 nc listener 測 7100 / 9100，IDC↔GCP 都通 — 不是 FW 問題。

**Root cause 3 連環**：
1. **yugabyted v2 master add 限制**：只在前 3 個 joiner 啟 yb-master；後續 joiner 只啟 yb-tserver。GCP 3 node（第 4-6 順位）→ 沒 yb-master → `yugabyted configure data_placement` add master 失敗。
2. **預設 placement_info 含 `cloud1.datacenter1.rack1:1` 假 zone block**：yb-master 啟動帶 `--placement_cloud=cloud1 --placement_region=datacenter1 --placement_zone=rack1` 作最後一組 flag（cmdline 重複後 wins）→ master 自報 default zone → universe placementBlocks 多一塊「沒任何 tserver 在裡面」的 zone，RF=3 之 1 replica 永遠 allocate 失敗。
3. **DDL catalog wait**：YSQL `CREATE INDEX` 觸發 catalog version 更新，需等所有 ALIVE tservers 的 postgres backend ack。GCP 3 tservers 仍 ALIVE 但跨 region catalog ack 慢 → 超過 pg_backend 等待上限 → `pq: timed out waiting for postgres backends to catch up`。

**Fix steps（按順序）**：
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
**結果**：原 panic 在 `creating index idx_customer`，fix 後 prepare 全跑完，run 出 tpmC 4324.6（IDC-only）。

### YBDB 真 6-node 跨 region 突破（追加）

**新發現關鍵 bug**：yugabyted `--advertise_address=g-test-poc-1` 在 GCP 端解析到 IPv6 `fe80::xxx`（Linux hostname resolution priority），register address 與 advertise 不一致 → 假錯誤 "A node is already running on 172.24.40.33"。
Fix：`--advertise_address=10.160.152.11`（直接用 IPv4 IP）。

**追加 fix step**：
```
# 1. tserver_flags 加兩個 catalog wait timeout (default 5s 對 cross-region 不夠)
   wait_for_ysql_backends_catalog_version_client_master_rpc_timeout_ms=60000
   wait_for_ysql_backends_catalog_version_client_master_rpc_margin_ms=300000

# 2. yugabyted start 在 GCP 用 IP 而非 hostname:
   sudo -u yugabyte yugabyted start --advertise_address=10.160.152.11 --join=172.24.40.32 ...

# 3. yb-admin modify_placement_info "104.idc.vlan241:2,104.gcp.asia-east1-a:1" 3
   yb-admin set_preferred_zones 104.idc.vlan241
```
**結果**：tpmC 從 IDC-only 4324.6 → 真 6-node **6812.2 (+58%)**。GCP follower 分擔讀負載；leader pinned IDC 仍享 IDC-quorum-local commit；跨 region replica 帶 1 額外 raft RTT，但 IDC quorum(2/3) 不卡 GCP slow follower。

### 修正過程（含已 commit 與待 commit）

環境層：IDC 3 dbhost DNS 172.29.254.5 不通 → 改 nameserver 10.0.1.5 + chattr +i；IDC chrony 0 sources（rebuild 後 DNS 壞）→ chrony.conf 加 `server 172.19.254.7`（IP），gate PASS drift 0.3ms；known_hosts 舊 key → ssh-keygen -R + accept-new prime；.31 self-ssh + .31 pubkey 寫到 GCP 5 VM。

程式碼層：

| 檔案 | 修正 | 已 commit |
|---|---|---|
| `iac-gcp/main.tf` | startup-script heredoc indent | 是（`61311cd`） |
| `phase-crossregion/scripts/gate-chrony-cross-region.sh` | drift empty KeyError | 是（`61311cd`） |
| `phase-crossregion/scripts/run-vm6-suite.sh` | 加 `GATE_SKIP=1` env | 是（`d8af817`） |
| `ansible/playbooks/tidb-vm6.yml` | 加 control node self-auth task | 待 commit |
| `ansible/playbooks/{tidb,cockroach,yugabyte}-vm6.yml` | `proxy_url` 改 region-aware（`sproxy` vs `gproxy`） | 待 commit |
| `tests/common/run.sh` | `WAN_PROBE_SH=$(cd ... && pwd)` 在 set -e 下 silent exit → 包 `if _wan_dir=...` | 待 commit |

**仍未修（follow-up）**：
1. `tidb-vm6.yml` include_role `haproxy_deploy` 缺檔 → `g-test-poc-4 failed=1`；今天用 DB_HOST=.32 直連繞過。
2. `cockroach-vm6.yml` 最後 `Apply placement SQL` task 太早跑 → `ERROR: database "tpcc" does not exist`；應 defer 到 prepare 後（同 TiDB：deploy 只 CREATE POLICY，ALTER 留給 suite）。
3. `yugabyte-vm6.yml` data_placement 失敗 → root cause + fix 已找出（見上）；follow-up 把步驟做成 playbook tasks 取代 yugabyted CLI data_placement step。
4. `.47.20` haproxy.cfg 仍未設定 → follow-up 配 haproxy 給 sweep 走 6-backend 均衡。

### Artifact 路徑（.31 driver）

```
/tmp/poc-tpcc/artifacts/X-CROSS/tidb-vm-6node-P-A-rc-20260619-010846/  ← TiDB 完整
/tmp/poc-tpcc/artifacts/X-CROSS/crdb-vm-6node-P-A-rc-20260619-015549/  ← CRDB 完整
/tmp/poc-tpcc/artifacts/X-CROSS/ybdb-vm-6node-P-A-rc-20260619-025055/  ← YBDB #1 (prepare panic)
/tmp/poc-tpcc/artifacts/X-CROSS/ybdb-vm-6node-P-A-rc-20260619-034736/  ← YBDB #2 (panic 仍在, placement 修但 GCP 還 ALIVE)
/tmp/poc-tpcc/artifacts/X-CROSS/ybdb-vm-6node-P-A-rc-20260619-045217/  ← YBDB #3 完整 (IDC-only after GCP kill)
/tmp/poc-tpcc/artifacts/X-CROSS/ybdb-vm-6node-P-A-rc-20260619-071031/  ← YBDB #4 完整 (真 6-node, tpmC 6812.2)
```

### Cleanup 狀態

```
TiDB cluster      destroyed (tiup cluster destroy --force)
CRDB              all 6 nodes systemctl stop + /var/lib/cockroach/* wiped
YBDB              all 6 nodes pkill + /var/yugabyte/* wiped
GCP 5 VM          alive (待 P5 後依需求決定 destroy 或保留)
IDC 3 DB VM       alive, services off, data dirs clean
IAP tunnels       MAC 端 still running
```

---

## 2026-06-21 — determinism

> Goal：ensure consistent results across runs for TiDB / CRDB / YBDB。
> Verdict：**W=4 short smoke 達不到 deterministic — root cause = lock contention，需用 W=128 (user baseline) 才可比**。

### 4 fix 套用後仍 non-deterministic（W=4 smoke）

Best-practice Makefile 整合（commit pending）涉及的 gate：phase8.5-fetch 改 ssh+tar（macOS openrsync v15+ 與 GNU rsync 不相容，用 ssh+tar pipe bypass）；YBDB Plan B（read_replica，live_replicas=IDC RF=3 + GCP read_replica RF=3，無 cache stale）；DEAD blacklist+remove+unblacklist（yb-admin 要求 blacklist 才能 remove_tablet_server）；Sustained Idle gate（60s × 6 consecutive）；TiDB pre-smoke leader gate（mysql query tikv_region_peers，issue：跑在 prepare 前）；CRDB post-prepare lease gate（crdb_internal.ranges，issue：empty result 待修 SQL）；Health check 6 tservers ALIVE。

**BP run-1 vs run-2（同 cluster，重新 deploy DB）— 5min run / W=4 / 16 threads**：

| DB | Run-1 | Run-2 | Variance |
|---|---|---|---|
| TiDB | 1552.2 | 9719.2 | **+526%** |
| YBDB (Plan B) | 41.8 | 23.0 | -45% |
| CRDB | 3929.6 | 2365.6 | -40% |

3 DB 都未 deterministic。

**6/19 outlier 解釋**：TiDB 6/19 的 10568 看似異常，但今天 run-2 9719 接近該值 → 反而 1500 那批是 outlier（PD scheduler 在某些 cold-start 狀態 leader 沒搬到 IDC）。

### Root cause — W=4 太小

```
TPCC standard: 理論 max tpmC per warehouse ≈ 12.86 (NEW_ORDER rate)

實測 tpmC/W:
  TiDB W=4:  1552 ~ 9719 / 4  → 388 ~ 2430 tpmC/W  (300× over standard)
  CRDB W=4:  2366 ~ 3930 / 4  → 591 ~ 982 tpmC/W
  YBDB W=4:    23 ~ 42 / 4    → 5.7 ~ 10.5 tpmC/W

16 threads × 4 warehouses = 4 threads/W → 高 lock contention
→ throughput 由 lock release timing 決定，run-to-run 變動 ±50%

vs W=128:
  16 threads × 128 W = 0.125 threads/W → contention 趨近 0
  → throughput 由真實 cluster latency 決定 → deterministic
```
**W=4 永遠 non-deterministic**：contention 是 timing-dependent，無法消除。

### 對 baseline 對比的意義

User baseline = W=128。今天所有 W=4 數據**不可比**。

| 維度 | W=4 (今天) | W=128 (user baseline) |
|---|---|---|
| Prepare data size | ~100MB | ~12GB (~32×) |
| Prepare time | 1-2 min/DB | 30-60 min/DB |
| Hot-spot contention | 強 (主因 variance) | 弱 |
| Run-to-run variance | ±50% | ±5% (typical) |
| TPCC tpmC standard | 超 standard 100-300× | 接近 standard |
| 對真實 prod 估值 | 不準 | 準 |

### 下一步建議

**1 個完整 W=128 run**（預估 2.5h）：
```bash
make phase-crossregion-all TPCC_TS=$(date +%Y%m%dT%H%M%S%z) \
  WAREHOUSES=128 RUN_SEC=300 THREADS_LIST=16
```
預期 W=128 tpmC：TiDB ~1500（12.86 × 128 efficiency）/ CRDB ~800-1200（cross-region commit）/ YBDB ~400-800（Plan B read_replica）。兩次 W=128 比較 variance 應在 ±5% 內（真 deterministic）。

### 今日 artifacts 已 fetch

```
results/x-cross/smoke/early-runs/
  20260620T213459+0800/  Plan A run (3 DB) - YBDB Plan A backfire
  20260621T054627+0800/  BP run-1 (3 DB)   - Plan B + best-practice gates
  20260621T075351+0800/  BP run-2 (3 DB)   - same cluster re-deploy, determinism test
```

---

## 2026-06-22 — determinism v2

> 接續 06-21。Decision：Path C → Path A。Codex round-1：263s reply, 5-block strategy。

### 昨日結論回顧

- W=4 × run-1/run-2 測出 ±50% variance，不具決定性
- 推測主要 noise 來自 redeploy 與 cluster 狀態不穩定
- 決定採**兩段式**驗證：先 30min 同 cluster 測試，再依結果進 Path A

### Codex round-1 關鍵 insights

| Insight | 影響 |
|---|---|
| 主 noise 不是 W，是「每輪 redeploy」 | 改變測試協定 |
| W=128 已夠（16 threads 碰撞 0.9） | 不需 W=256/512 |
| Suite 模式：1 deploy → warmup → 5 rounds → 取 R2-R5 median | Makefile 重構 |
| Freeze scheduler/balancer per DB | 新增 phase |
| go-tpc 可能無 --warmup 旗標 | 用外部 warmup loop |

### Path C 兩段式設計

**Step 1：30-min 假說驗證（同 cluster W=4 N=5）** — 先 deploy + prepare（一次），連跑 5 輪 W=4 RUN_SEC=300 THREADS=16，收 5 個 tpmC 算 CV。通過條件 CV ≤ 10%（per DB）。失敗對策：診斷其他 noise source，不貿然進 Path A。

**Step 2：Path A 正式 baseline（W=128）** — 觸發條件 Step 1 通過。3 DB × W=128 × 1 suite ×（20m warmup + 5 rounds × 5min），取 R2-R5 median + CV。預估 16-18h。

### 4 Agents 並行任務拆分

| Agent | Model | 任務 | 狀態 |
|---|---|---|---|
| Agent-Make | sonnet | Makefile 新增 freeze/unfreeze + smoke-only + validate-hypothesis | pending |
| Agent-Verify | haiku | go-tpc 旗標真實性驗證 | pending |
| Agent-Doc | haiku | 本 SSOT | complete |
| Agent-Probe | sonnet | per-DB freeze/unfreeze script | pending |

### CV 計算與通過條件

```python
import statistics
tpmc = [r1, r2, r3, r4, r5]  # 5 round 結果
mean = statistics.mean(tpmc)
stdev = statistics.stdev(tpmc)
cv = stdev / mean
print(f"mean={mean:.1f} stdev={stdev:.1f} CV={cv:.2%}")
```

| CV | 判讀 |
|---|---|
| ≤ 5% | 穩定，可直接進 W=128 |
| 5-10% | 可接受，進 W=128 並標註 |
| > 10% | NG，先排查再進 Path A |

### 風險與 fallback

- Step 1 任一 DB CV > 20% → 該 DB 進 Path A 前先單獨偵錯
- Step 2 任一 DB 中途失敗 → 用 R2 以前的 round 補；不退回重 deploy
- 2 天時程：Day1（今天）Step 1 + Step 2 開跑；Day2 收 Step 2 結果 + 文件

### Agents 並行成果（回填）

**7.1 Makefile 改動摘要（Agent-Make / sonnet）** — `poc/Makefile` +256 lines（678 → 933）：

| 類別 | 新增 target | 用途 |
|---|---|---|
| freeze | `phase-freeze-tidb/crdb/ybdb` | dump 原 config 後關閉 scheduler/balancer |
| unfreeze | `phase-unfreeze-tidb/crdb/ybdb` | 從 dump 還原 |
| smoke-only | `phase-smoke-only-tidb/crdb/ybdb` | 跳過 deploy/prepare 直接 run，依 `SMOKE_ROUND` 寫入 `round-N/` |
| orchestration | `phase-c-validate-hypothesis` | freeze 3 DB → 5 round loop → unfreeze → cv-report |
| CV 分析 | `phase-c-cv-report` | R2-R5 mean/stddev/CV%，分 STABLE/MARGINAL/NOISY |

新增變數：`TIDB_PD` / `SMOKE_ROUND` / `SMOKE_RESULT_BASE` / `CRDB_FREEZE_DUMP` / `YBDB_UNIV_DUMP`。dry-run 確認 chain 順序正確、語法無誤。

**7.2 go-tpc 旗標 ground truth（Agent-Verify / haiku）** — Codex 部分假設不成立。實測：

| 旗標 | Codex 假設 | 真實 | 應對 |
|---|---|---|---|
| `--wait` | 存在 | 存在 | 統一控制 keying + think time |
| `--warmup` | 質疑 | 不存在 | **外部 warmup loop**（短跑一輪丟棄） |
| `--ramp-up` | 質疑 | 不存在 | 無漸進啟動 |
| `--keying-time` | 質疑 | 不存在 | 由 `--wait` 控制 |
| `--think-time` | 質疑 | 不存在 | 由 `--wait` 控制 |
| `--check-all` | 存在 | 存在 | 用於 `go-tpc tpcc check` 子命令 |
| `--ignore-error` | 質疑 | 存在（global） | 預設 NOT 開啟 |
| `--weight` | 存在 | 存在 | `--weight 45,43,4,4,4` |
| `--conn-refresh-interval` | 存在 | 存在 | 預設 0；可設 `10s` 平衡流量 |

額外：`--output {plain|table|json}`（json 可下游解析）；`--max-measure-latency 16s`；**無原生 p50/p99 輸出**。
Warmup 策略：外部跑「丟棄 R1」即可，不用 `--warmup`。help dump 暫存於 `/tmp/go-tpc-help-*.txt`（重啟可能消失）。

**7.3 Freeze/Unfreeze 獨立 script（Agent-Probe / sonnet）** — 目錄 `poc/phase-crossregion/freeze/`：

| 檔案 | 內容 |
|---|---|
| `freeze-tidb.sh` | dump PD config → 5 limit=0 → sleep 30s → operator show 確認無 pending |
| `unfreeze-tidb.sh` | `jq` 讀 dump 還原各 limit |
| `freeze-crdb.sh` | dump 2 setting → SET false → sleep 10s |
| `unfreeze-crdb.sh` | `awk` 讀 dump 還原（含原本就是 false） |
| `freeze-ybdb.sh` | dump universe + lb_idle → set_load_balancer_enabled 0 → sleep 15s → confirm Idle=1 |
| `unfreeze-ybdb.sh` | set_load_balancer_enabled 1 |
| `README.md` | env 變數 / 用法 / freeze 後禁忌 / 緊急 unfreeze |

6 script 全部 `bash -n` 語法通過（`set -euo pipefail` + `ssh -o BatchMode=yes`）。注意：Makefile inline freeze/unfreeze 與此目錄 script 功能重疊，建議下次重構統一（Makefile call shell script），Step 1 不阻塞先沿用 Makefile inline。

### 下一步（待 user 啟動）

1. `cd iac-gcp && terraform apply`（~10 min）
2. `cd iac-idc && terraform apply`（~5 min）
3. `make phase2-init`（ansible inventory）+ `make phase3-tidb-deploy` / `phase4-ybdb-deploy` / `phase5-crdb-deploy`
4. 各 DB prepare W=4（~2-3min）
5. `make phase-c-validate-hypothesis WAREHOUSES=4 RUN_SEC=300 THREADS_LIST=16 TPCC_TS=$(date +%Y%m%dT%H%M%S%z)`
6. 收 CV report：CV ≤ 10% 通過 → 進 Step 2 (W=128)；否則先偵錯

預估 Step 1 wall-clock：deploy 30min + prepare 9min + 5 round × 3 DB × 5min = ~1.2h。

---

## 2026-07-02 — Step 0 DRY_RUN（tidb-validate）三輪執行

> 目的：TiDB P-A × A-S × W=128 workflow 全鏈驗證（`make phase-crossregion-tidb-validate`，
> DRY_RUN=1 不跑 go-tpc benchmark），作為 Touch 1（P-A 正式 cell）發車前的 Step 0。
> 執行方式：Mac 端 `nohup caffeinate -i make ...` detached + Monitor/subagent 觀測。

### 三輪時間軸

| 輪 | TPCC_TS | 起訖 | 結果 | 死因 / 備註 |
|---|---|---|---|---|
| v1 | `20260702T143425+0800` | 15:13 → 15:27 | 💥 `phase1-proof` | Python SyntaxError（make 摺行）；wait 390s READY（舊 startup script）|
| v1 續跑 | 同上 | 15:31 → 15:3x | 💥 `phase2-ssh-prime` | IAP tunnel Error 255；**修復後續跑至 DRY_RUN=1 PASS + teardown**（15:37）|
| v2 | `20260702T155023+0800` | 15:50 → 16:00 | 💥 `phase2-gate` | stale host key → ProxyJump 全拒（homogeneity GCP 全 ERR 卻假 PASS、boot_id=?、chrony verdict=FAIL）；wait **100s** READY（新 dnf script 首測）|
| v3 | `20260702T215151+0800` | 21:52 → 22:1x | ✅ **全鏈一次過 `tidb-validate PASS`** | wait 390s；homogeneity WARN（真值）；chrony verdict=PASS 首試即過；DRY_RUN=1 PASS |

### 抓出並修復的 6 個 bug（全部 planner 看不到、實跑才現形）

| # | Bug | 根因 | 修法 | Commit |
|---|---|---|---|---|
| 1 | `phase1-proof` SyntaxError | make `\` 摺行把多行 Python if/else 壓成 `python3 -c` 單行 | 抽成 `scripts/vm-rebuild-proof.py` | `1f73d375` |
| 2 | `phase2-ssh-prime` Error 255 | prime 從未建立的 IAP tunnel（違反 via-31 硬規則）；tunnel 推 pubkey 段早已被 terraform metadata 取代 | 改 .31→GCP 5/5 直連 prime，刪 tunnel 段 | `2a870e92` |
| 3 | stale host key 連鎖（homogeneity ERR / boot_id=? / chrony gate FAIL）| VM rebuild 輪替 host key，Mac/. 31 known_hosts 留舊 key → 第二輪起 ProxyJump 全拒 | `phase1-wait-via-31` 開頭自動清 Mac+.31 stale keys | `88d2acda` |
| 4 | homogeneity fail-open | `grep -v ERR` 把 ERR 濾掉再比對 → 全 ERR 反而 PASS | 任何 ERR → FAIL exit 1 fail-closed | `88d2acda` |
| 5 | teardown GCP UNREACHABLE | via31 inventory 設計給 .31 controller，但 teardown ansible 在 Mac 本機跑 | 三個 teardown 改 `ssh .31` 執行；live 驗 6/6（`no_tidb`/`ybdb_clean`/`crdb_clean`）| `79b79129` |
| 6 | static-check 挑錯 suite | `sorted()[-1]` 字典序：`run1-20260622` 排在 `20260702` 後 → per-cell gate 會挑 6/22 歷史目錄（Win-1 blocker）| `--ts` 鎖定本輪 TS + dry-run 目錄跳過 + fallback 改 mtime | `7ad38acb` |

配套：GCP startup dnf 精簡（單 transaction + no-weak-deps + 3 retry + 砍 10 包，READY 100–390s）、
wait `MAX_WAIT_SEC=1200`、chrony gate 3 次 retry（`1f73d375`/`88d2acda`）。

### v3 全鏈驗證清單（最終 PASS 的證據鏈）

- phase1：destroy → apply（IDC 3 + GCP 5）→ wait 390s READY → homogeneity **WARN**（IDC/GCP kernel
  `.124` vs `.129`、disk 99/100G——真值如實回報，非 ERR）→ proof（15 IDC + 5 GCP resources、6 組 boot_id 真值）
- phase2：dns-fix → ssh-prime `5/5 GCP primed` → bootstrap rsync → **chrony gate verdict=PASS**（首試即過，retry 未動用）
- phase3：TiDB 6-node deploy，ansible PLAY RECAP 全綠
- phase6：`DRY_RUN=1 PASS`（SSH / endpoint / binary / placement-SQL 五項 pre-flight）
- teardown：tiup `Destroyed cluster tpcc-tidb-vm6 successfully`；修復後補驗 6/6 全可達
- 收尾：`phase9-tunnels-stop phase9-destroy`（IDC+GCP state 歸零省費）。phase9 的 F-Gate 對純 DRY_RUN
  session 屬合理 fail-closed（無 suite artifact 可驗），需明知地走子 target bypass。

### 結果檔案

- VM rebuild proof（本 repo）：`results/x-cross/smoke/early-runs/20260702T{143425,155023,215151}+0800/vm-rebuild-proof-*.json`
- DRY_RUN artifact（.31，VM 已拆但 .31 為常駐 jump host）：`/tmp/poc-tpcc/artifacts/X-CROSS/tidb-vm-6node-P-A-rc-20260702T{143425,215151}+0800/{.dry-run.done, dry-run/}`
- 執行 log（Mac /tmp，ephemeral）：`/tmp/step0-dryrun.log`、`/tmp/step0v2-dryrun.log`、`/tmp/step0v3-dryrun.log`

### 當日拍板（詳 `decisions-2026-06-08.md`）

- **Q15**：W=128 驗收 CV 口徑 = **R1–R5 mean 維持**（現行 code canonical，與 S-BASE 一致）
- **Q11 澄清**：placement 變更（P-A→P-B）之間 **VM full rebuild（per-cell）**

### Touch 1 發車條件（全數就緒）

workflow 全鏈綠 ✅、`win-tidb-as-detach` driver 就緒（長跑 detached 於 .31，Mac 可關機）✅、
CV/Q11 已拍板 ✅、teardown 6/6 ✅、static-check TS-scoped ✅。
流程：`make phase1 phase2 phase2-gate phase3-tidb-deploy` → `make win-tidb-as-detach PLACEMENT=P-A TPCC_TS=<ts>`。

### 2026-07-03 iperf3 flow 單 VM 實測 + 專線 FW 實測發現

用 `terraform apply -target='google_compute_instance.poc[0]'` 只開 **一台** GCP VM（g-test-poc-1
= 10.160.152.11，不動 `main.tf` 的 `count=5`）驗 iperf3 flow。IDC 端 .32/.33/.34 未部署（No route），
唯一存活 IDC 主機為 .31。**已驗（無需在 .31 裝 iperf3）**：cloud-init 裝好 iperf3、ephemeral
`iperf3 -s -1 -p 20170` bind 成功（`ss` 見 LISTEN）、.31→GCP:20170 TCP 三向握手通、RTT 8.08ms
（符 fw-request 7.5ms）。**真實 `-J` JSON 頻寬採樣延到日後 all-phase 兩地 VM 全建後再做**（.31 不裝，
使用者拍板 standby）。收尾：destroy 單 VM、清 .31 known_hosts stale key、tfstate 歸零。

- ⚠ **與 code 註解前提矛盾的實測發現**：`wan-probe.sh` 註解引用「5201 專線未開通」作為改埠 20170 的理由，
  但實測 **5201 從 .31 也可達**。真因：(1) GCP VPC FW `lab-service-vpc-allow-default-policy`（host
  project lab-host-project-104）對來源 `172.16.0.0/12` 放行 **all protocol/port**；(2) IDC↔GCP 專線
  的 /24↔/24 規則實際是**整段放行、非逐埠**。→ 改埠 20170 仍正確安全（20170 確定可用、屬 R8 TiKV
  閒置埠），但「5201 被擋」的前提在此環境**不成立**；日後別再以「某埠沒在 fw-request 列出＝被擋」推論。

**Last updated**：2026-07-03 iperf3 flow 單 VM 實測（機制全驗、JSON 採樣 standby 待 all-phase；專線 FW 實為 /24 整段開）。
**Next review**：Touch 1（P-A 正式 cell）跑完後填 W=128 N=5 結果；all-phase 兩地 VM 全建後補 iperf3 -J 雙向 JSON 採樣。
