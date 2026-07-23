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
    **口徑注意（07-18 補注）**：上式為樣本標準差 CV（06-22 era／pipeline-log 舊口徑）。
    07-11 起的 w128 suite 用 `tpmC_range_mean_pct` = (max−min)/mean——兩者對同組
    數據可差 2-3 倍（如 YBDB t64：range% 81.1% vs 樣本 CV 35.1%）。結案報告
    07-18 起統一改稱 **range%**、不再稱 CV；比對數字前先確認口徑（報告 §5）。
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
  - **（07-03 勘誤）** 上方 ②「專線沒開 5201」前提**實測不成立**——5201 從 .31 亦可達，專線實為 /24↔/24
    整段放行（非逐埠），詳見文末 2026-07-03 節。改埠 20170（後續 Q17 再改 19999）仍正確，但理由是
    「離開 TiKV range 的衛生考量」而非「5201 被擋」。

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

### 2026-07-07 Path C 移除 + iperf3 daemon 拆除 + 埠改 19999（Fable 健檢 D9 拍板落地）

Fable 健檢（`fable-refactor/healthcheck-report.md`）挖出的 R1/R2 拍板（decisions D9）於本次落地：

- **Path C 全刪**（R2）：`phase-warmup-only-{tidb,crdb,ybdb}`、`phase-roundrun-only-{tidb,crdb,ybdb}`、
  orchestrator `phase-c-validate-hypothesis`、CV report `phase-c-cv-report`、`run-round-only.sh` 檔案本身。
  原因：`phase2-bootstrap` 只 rsync `scripts/` 子目錄，`run-round-only.sh` 在其上一層，遠端必缺檔——
  這條鏈在現部署模式下從未真正跑通（warmup 段 `\|\| true` 靜默假成功、量測段硬炸）。Wave 4 走
  `run-vm6-suite.sh` 正式路徑，Path C 無回歸價值。**保留未動**：`phase-freeze-*`/`phase-unfreeze-*`（獨立
  可重用的凍結工具，非本鏈成員）、`phase-smoke-only-*`（走 `run.sh` 直連，非本鏈成員，只更新其
  DEPRECATED 提示訊息不再指向已刪目標）、`phase-leader-gate-tidb-postprepare`（通用 gate 工具）。
- **iperf3 常駐 daemon 拆除**（R1）：`iac-gcp/main.tf` 移除 `iperf3-server.service` 常駐段，cloud-init
  仍裝 binary。貫徹 wan-probe.sh 早已宣稱的「臨時起 server」架構，兌現 0.0.0.0 常駐監聽的安全顧慮
  （此前 main.tf 與 wan-probe.sh 的敘述長期不一致，本次補平）。
- **iperf3 埠改 19999**：5201（main.tf 舊常駐埠）與 20170（wan-probe.sh 原改埠值，落在 TiKV
  20160-20180 range 內）皆棄用，統一改**專用高埠 19999**（離所有 DB service range 與 OS ephemeral
  range 32768+）。**澄清**：iperf3 對 benchmark 的干擾早由時序 gate 解決（只在 round 間隙跑，量測輪
  跳過）——改埠純為衛生/歸因考量，與「哪個埠被 FW 擋」無關（07-03 已證兩者皆可達）。

驗證：`bash -n` 全過、`terraform validate`/`terraform fmt -check` PASS、`idc-iperf3-bootstrap.sh
--dry-run` 確認 systemd unit 埠=19999、`--dry-run --install-only`（phase2-iperf3-idc 實際模式）確認
仍只裝 binary 不建常駐 unit、Makefile 正式 target（phase-freeze-tidb/phase-smoke-only-tidb/
phase-leader-gate-tidb-postprepare/phase-crossregion-w128-suite）`make -n` 皆展開正常（確認未誤刪
依賴）。**未 live 驗證**：19999 埠與拆常駐後的 cloud-init 需下次 phase1 rebuild 才會實際生效。

**Last updated**：2026-07-07 Path C 移除 + iperf3 daemon 拆除 + 埠改 19999（M1/S2/S2b 落地，D9 拍板兌現）。
**Next review**：下次 phase1 rebuild 驗 iperf3 binary-only + 19999 埠是否如預期；Win-1 CRDB/YBDB smoke 驗 S5 的 YBDB freeze fail-closed 路徑。

### 2026-07-08 TiDB cross-region smoke live 重跑（驗證 S1-S8 全數修復 + 抓到 2 個新 bug）

`make phase1` 全重建 → `phase1-wait-via-31`（5/5 GCP READY，elapsed=0s，證實 S2b 拆 iperf3
常駐 daemon 沒讓 cloud-init 掛掉）→ `phase2`（含 phase2-iperf3-idc --install-only，`.32` 驗證
iperf3 binary 裝好、`systemctl is-active iperf3-server`=inactive，S2b live 驗證通過）→
`phase3-tidb-deploy`（一次成功，PD health 6/6 true）→ W=1 t16 N=1 smoke（略過 Makefile
`win-tidb-as-detach`，直接 ssh 帶 `WAREHOUSES=1 ROUNDS=1 THREADS_LIST=16` 呼叫
`win-tidb-as-w128.sh`；**未同時設 `WARMUP_SEC`，沿用預設 1200s** 完整跑完 20 分鐘固定
threads=64 warmup——`tests/common/run.sh` 禁改，warmup 執行緒數與時長不受 THREADS_LIST 覆寫）。

**bug（已修 `29dad344`）：freeze/lib-pd-drain.sh 路徑錯誤**。S5(YBDB)/S8(CRDB)/07-08(CRDB 補
接線) 寫的 5 處 freeze 呼叫都用 `$SELF/../freeze/...`——這是**本機** repo 佈局（scripts/ 與
freeze/ 同層）。但**遠端部署佈局不同**：`win-tidb-as-detach` 把 freeze/ rsync 到
`$(CROSS_SCRIPTS_REMOTE)/freeze/`（crossregion/ 底下的**子目錄**）；`win-tidb-as-w128.sh` 自
己用 `FREEZE_DIR="$SELF/freeze"`（無 `..`）才是正確慣例。全部改 `$SELF/freeze/`。
**教訓**：驗證遠端路徑絕不能只查本機檔案系統——bash -n + 本機 `ls` 存在性檢查完全查不出
「本機佈局 vs 遠端佈局不一致」，只有 live 執行才會現形。`phase2-bootstrap` 本身也不 rsync
`freeze/`（只有 `win-tidb-as-detach` 額外做），繞過 Makefile 直接呼叫需手動補 rsync。

**死路（重試方法論陷阱，非程式碼 bug）**：修完路徑 bug 後沿用同一 TPCC_TS 重跑，prepare
跑完但 placement gate idc=0/19（應 ≥70%）。根因：TiDB `tpcc` database 名稱不受 TS 影響，
placement watcher 靠「drop-create.log 存在」+「9 張表存在」判斷「已 drop+create」——但
`tee` 一開管線就建立空檔，上一輪殘留的 9 張舊表在**這一輪**真正 DROP DATABASE 完成前就
滿足條件 → watcher 搶跑套 placement SQL，撞併發 DDL。正式生產每個 cell 都全新 TS + VM
rebuild（Q11），不會有殘留表，純粹是省時間沿用同 TS 重試才踩到的邊界案例。處置：手動
`DROP DATABASE tpcc` 清乾淨 + 換新 TS，不修框架碼。

**bug（已修 `c82ff64b`）：iperf3 埠 19999 revert 回 20170 + wan-probe.sh 漏檢 JSON error 欄位**。
smoke 跑出 iperf3 forward (idc→gcp) 成功、reverse (gcp→idc) `"error": "...Connection timed out"`；
但 `wan-probe.sh` 的 `note_fail` 只檢查輸出是否為空字串，沒檢查 JSON 內 `"error"` 欄位——
iperf3 逾時仍印出格式良好但含 error 的 JSON，導致這次真實失敗被誤判成功（"all probes
succeeded"，且**這次 smoke 的 failed.txt 確實掛零**，親身印證了這個漏洞）。用原始 TCP
handshake（`/dev/tcp`，不靠 iperf3）+ 使用者手動測 CRDB port 26257（`Bitrate 124-208
Mbits/sec` 成功）雙重驗證：**專線對 GCP→IDC 方向是逐埠白名單**（只放行 fw-request R1-R9
核准範圍：2379-2380/4000/5433/7000-7100/8080/9000-9100/10080/20160-20180/26257），
非「/24 整段放行」——07-03 的「整段放行」結論只驗證過 IDC→GCP 方向。19999 不在任何核准
範圍 → GCP→IDC 擋；20170（R8 範圍內、未被真實 TiKV 佔用）雙向皆通。**D9 埠選擇 revert 回
20170**（決策記錄詳見 `fable-refactor/decisions.md` D9 修正段）；`wan-probe.sh` 補
`"error"` 欄位檢查。**尚未重新 live 驗證新埠**（改動未 sync 到 .31，避免干擾當時仍在跑的
smoke；下次跑 suite 時會自動用上新版）。

**結論**：S1-S8 全部修復對 TiDB 實際執行路徑**無破壞性影響**——3 次嘗試中，前 2 次的失敗
皆非 S1-S8 本身邏輯錯誤（分別是路徑慣例疏漏、我自己的重試方法論陷阱），第 3 次（新 TS）
全鏈 PASS：`.window.done` status=DONE、freeze→run→unfreeze→collect→leader gate 100%
IDC→leader snapshot→PD 解凍驗證全部正確；summary.json tpmC_mean=593.0（W=1 t16，quick
smoke 數值非正式基準）。資料存 `results/x-cross/smoke/early-runs/20260708T160747+0800/`。

**Last updated**：2026-07-08 TiDB smoke 三連跑（2 bug 修復 + 1 方法論教訓 + iperf3 埠 revert），S1-S8 全數驗證無破壞。
**Next review**：下次 suite 執行時驗證 20170 埠 + error 欄位偵測是否如預期生效；CRDB/YBDB smoke 待排（Stage 1 剩餘項，含 07-08 補接線的 CRDB freeze 首驗）。

### 2026-07-08（續）CRDB cross-region smoke 首跑（趁設備還在，一次抓 3 個新 bug）

前一輪 TiDB smoke 收尾後重建 VM，順道驗證 iperf3 20170 埠 + CRDB freeze 補接線（`d73cac65`）。
`phase1` 重建 → `phase2`（**驗證 `phase2-bootstrap` 新補的 freeze/ 自動同步生效，這次不用再手動
rsync**）→ `phase5-crdb-deploy`（一次成功，`cockroach node status` 6/6 live）→ 直接呼叫
`run-vm6-suite.sh --db crdb`（無 win-crdb-as-*.sh wrapper，手動複製 win-tidb-as-w128.sh 的
env 設置）。三次嘗試，抓到 3 個此前從未 live 測過的真 bug：

**bug（已修）：CRDB 缺少 TiDB 已有的「早套 placement」watcher**（同 bug #9 病灶，CRDB 版本從未修）。
`prepare.sh` 內建 §6.6 placement gate 在 wrapper case 分支套用 CRDB per-table lease_preferences
**之前**就先跑；`run-vm6-suite.sh` 沒有 CRDB 對應的背景 watcher 提早套用（TiDB 有，line 224
`if [[ "$DB" == "tidb" ]]`），導致 gate 100% 踩到「policy 還沒套用」的窗口期（實測
idc=5/10=50% FAIL）。修法：新增對稱的 `elif [[ "$DB" == "crdb" ]]` watcher 分支（等
drop-create.log + 9 張表 → 用 cockroach sql 套 placement SQL）。**live 驗證 PASS**：
`placement-gate-P-A.txt` 顯示所有 range lease_holder_locality 皆為 `region=idc`。

**bug（已修）：`freeze-crdb.sh` 讀 CRDB `--format=tsv` 布林值格式錯誤**。這個 CRDB 版本
（v26.2.0）對 BOOL 欄位回傳 postgres 慣例 `t`/`f`，非 `true`/`false`；`freeze-crdb.sh` 的
驗證 `case ... in true|false)` 因此判定失敗（`unexpected value 't' for lease_rebal`）。
修法：讀值後立刻 `_normalize_bool`（t→true, f→false）再驗證/寫 dump 檔，讓後續 rollback SQL
與 `unfreeze-crdb.sh` 全程只看到合法字面量，`unfreeze-crdb.sh` 不用改。**live 驗證 PASS**：
unfreeze 正確印出 `restoring ... = true`（非 `t`）。

**環境問題（非程式碼 bug）：本機網路（連線名稱含 `warp-svc`，疑似 VPN client）中途斷線**，
前景 ssh 執行的 CRDB smoke 於 quiesce 5 分鐘結束、進 ANALYZE 瞬間被 SIGPIPE 殺掉
（`.suite.failed exit_code:141`），本機 ssh session 卡在半開連線狀態收不到結果，誤以為還在
跑（實際已於 1.5 小時前失敗）。**教訓**：任何超過幾分鐘的 smoke 都該遵守既有紀律
「長跑一律 nohup detach 在 .31」，不要圖方便前景跑——本次改 nohup 後順利跑完，不再受本機
網路波動影響。

**bug（已修）：`check-static-artifacts.py` 只認 `placement-gate-*.json`，CRDB 只寫 `.txt`**。
TiDB 的 `prepare.sh` 分支寫 `.json`（結構化 verdict）+ `.txt`；CRDB 分支只寫 `.txt`（原始
SHOW RANGES 輸出，無結構化 verdict）——`prepare.sh` 兩個 DB 分支本身實作不對稱（該檔案屬
tests/common/ 不可改）。修 `check-static-artifacts.py` 改接受 `.json` 或 `.txt` 任一，驗證
的本意是「gate 真的留了證據」而非強制格式。

**bug（後續已修 `bea9ae1d`，使用者明確 override 禁改清單）**：`prepare.sh` placement gate
段 `列 358: 0 0: 表示式語法錯誤` 是經典 `grep -c` exit-code 陷阱——0 筆匹配時 `grep -c` 印出
正確的 "0" 但 exit 1，`|| echo 0` fallback 因此又印一次 "0"，兩行 "0\n0" 塞進變數讓
`$((idc_cnt + gcp_cnt))` 算式畸形。這次 100% leader 集中 IDC（watcher 修好的直接結果）才
讓 `region=gcp` 真的 0 筆匹配踩到這個陷阱；先前 50/50 分布的失敗輪兩邊都非零故未觸發。
修法：`idc_cnt=$(grep -cE '...' 2>/dev/null); idc_cnt=${idc_cnt:-0}`（grep -c 對存在檔案
永遠印單一數字；`${var:-0}` 只在變數真空時才補 0，三種情境皆對）。**同款 bug 也在 YBDB
分支**（line 413-414，IP prefix grep，同樣的 copy-paste 起源）一併修；已核對 line 542/555
（wc -l）/569（awk）無此 exit-code 怪癖，兩處是窮盡修復。

**結論**：CRDB × P-A × A-S 全鏈 PASS（`.suite.done`）：freeze→run→unfreeze→collect 全部正確，
tpmC=4623.5（W=1 t16 quick smoke，非正式基準）。TiDB + CRDB 兩家皆完成 Stage 1 smoke；
YBDB 待排（唯一剩餘）。資料存 `results/x-cross/smoke/early-runs/20260708T214141+0800/`。

**Last updated**：2026-07-09 補修 `prepare.sh` grep -c 零匹配算式錯誤（CRDB+YBDB 兩分支，使用者明確 override 禁改清單），Stage 1 進度：TiDB+CRDB 完成，YBDB 待排。
**Next review**：YBDB smoke（驗證 S5 的 freeze idle 確認路徑首次 live + 本次 grep -c 修正首次 live）；正式 Win-1 CRDB W=128 前記得移除本次 smoke 遺留的低 warehouse 測試資料。

### 2026-07-09 YBDB smoke 首跑（未跑完，抓到 2 個真 bug + 1 個部署層存量 bug）

`phase1` 重建 → `phase2` → `phase4-ybdb-deploy` + `phase4-ybdb-fix6n`（load_move_completion
100%、6/6 ALIVE、placement idc:3 live + gcp:3 read_replica 皆正確）→ 直接呼叫
`run-vm6-suite.sh --db ybdb`（無 win-ybdb-as-*.sh wrapper，手動複製 env，同 CRDB 模式）。

**bug（已修）：`prepare.sh` 08-08 二修（`bea9ae1d`）本身仍有 bug**。原修法
`idc_cnt=$(grep -cE ... 2>/dev/null); idc_cnt=${idc_cnt:-0}` 在 `set -euo pipefail` 下，
`grep -c` 零匹配時 exit 1，**`var=$(failing_cmd)` 這種 assignment 形式的指令，bash 的
set -e 語意不比照 if/&&/|| 語境豁免，會在 `${var:-0}` fallback 執行前就直接把整支腳本
殺死**（`bash -c 'set -e; x=$(grep -c zzz /etc/hostname); echo after'` 可重現：exit 2，
"after" 永遠不印）。YBDB smoke 100% leader 落 IDC（gcp_cnt 真的 0 筆匹配）直接踩爆，log
印完 "X-CROSS placement gate" 後無任何錯誤訊息瞬間死亡，`.suite.failed exit_code:1`。
CRDB 分支先前聲稱的「間接驗證修正邏輯正確」其實從未真正重跑驗證過，這次才現形。
修法：`$(...)` 內加 `|| true` 吸收 exit code（不影響 grep 本身印出的 stdout；已驗證
零匹配/正匹配/檔案不存在三種情境皆對）。使用者二次明確 override 禁改清單授權
（commit `44d95c42`）。

**bug（已修）：`coldreset-ybdb.sh` 首次 live 驗證即炸——cold-reset 造成 master split-brain**。
`run.sh` 的 YBDB cold-reset 呼叫 `yugabyted start --advertise_address=172.24.40.32
--tserver_flags=...`，**沒帶 `--join`**。重啟 .32 時被當成全新 single-node cluster
（`replication_factor=1`、`master_addresses` 只剩自己），與現存 master quorum 分裂，
之後所有 `LookupByIdRpc` 全部 timeout（"passed 15s of 4.8s deadline"）。修法：加
`--join=172.24.40.33`（一定要填另一台現存 master，不能填自己，否則不觸發正確的
peer-discovery 路徑）。使用者明確 override 授權（commit `44d95c42`）。

**未修（部署層存量 bug，範圍外，下次複驗）：master quorum 實際是 4 台，非設計預期
3 台 IDC-only**。修復上述 cold-reset bug、對 .32 做 wipe+rejoin 過程中，用
`curl http://<idc-host>:7000/api/v1/masters` 直接查詢才發現：現存 master quorum
是 `{.32, .33, .34, 10.160.152.12(GCP g-test-poc-2)}` 共 4 台，其中 GCP 那台是
SESSION-HISTORY 06-19 記錄過的「yugabyted v2 master add 限制」歷史 bug 重演——
ansible `yugabyte-vm6.yml` 的 join 環節顯然沒有嚴格序列化（IDC .33/.34 先 join、
GCP 1-3 後 join），讓某台 GCP 節點搶到 master 名額；`phase4-ybdb-fix6n` 的
DEAD-tserver 清理步驟只處理 tserver 名單，從未檢查/修正 master raft membership，
因此這個 bug 在全新 `phase1` rebuild 上原封重現，不是本次操作造成的迴歸。當下
存活 quorum 剛好卡在門檻（3 alive / 4 total = 剛好過半，任何一台再掛就斷
quorum）——脆弱但當時尚未斷線。診斷過程曾誤 wipe 一台真正的 IDC master（.32），
確認 RF=3 下 .33/.34 仍持有完整資料副本、純觸發 re-replicate、無資料遺失後才
執行；使用者最終決定用 `teardown-ybdb` + 全套 `phase4` 重新部署處理，而非手動
`yb-admin change_master_config REMOVE_SERVER` 精準摘除。重部署跑到「Join
YugabyteDB workers」中途，使用者改口「先拆全部 VM，稍後重新跑 YBDB smoke」，
故本輪未跑完（無 tpmC 數字），VM 已全部 destroy。**下次 YBDB smoke 起手式**：
phase4 完成後、進 run-vm6-suite.sh 之前，先用上述 curl 指令核對 master quorum
剛好 3 台且都是 IDC，若又是 4 台以上，需在 playbook 或 fix6n 補一道 master
membership 檢查/修正的 fail-closed gate，不能再假設 ansible 一定生出乾淨 3-master。

**結論**：YBDB Stage 1 smoke 仍未完成（3 家 DB 中最後一家）。2 個腳本 bug 已修
（`44d95c42`），下次重跑理論上能過這兩關；部署層 master quorum 存量 bug 待下次
複驗，若重現則需追加修復（不在 tests/common 保護清單內，屬 ansible playbook /
Makefile fix6n 範圍，改動風險較低）。

**Last updated**：2026-07-09 YBDB smoke 首跑抓到 2 bug（已修）+ 1 部署層存量 bug（待複驗），Stage 1 進度：TiDB+CRDB 完成，YBDB 仍待重跑。
**Next review**：YBDB smoke 重跑，起手式先核對 master quorum 剛好 3 台 IDC；若過關則 3 家 DB Stage 1 全數完成。

### 2026-07-09（續）YBDB smoke 二輪重跑 — 抓到 master quorum race 兩次復現 + catalog-wait 連環，中止未完成

前一輪記錄「master quorum 存量 bug 待複驗」，本輪重建 VM 複驗，**兩次全新 phase1
rebuild + phase4 重部署，master quorum race 皆 100% 重現**（分別是 `10.160.152.12`
和 `10.160.152.11` 這兩台不同 GCP 節點搶到 master 名額）——確認是 ansible
`yugabyte-vm6.yml` 的可重現 race，非偶發，且比原判斷更深：直接查 LEADER 的
`yb-admin list_all_masters`（而非 FOLLOWER 的 HTTP API，其回報的是過期 peer 快取）
才發現真正 raft quorum 一度只有 2 台（`.32` + 1 台 GCP），`.33`/`.34` 雖本機在跑
yb-master process 卻從未真正 join 進共識。手動用 `yb-admin change_master_config
ADD_SERVER`/`REMOVE_SERVER`（注意參數順序是 `<ip> <port> [<uuid>]`，uuid 在最後）
修復至 `{.32,.33,.34}` 3 台 IDC-only，驗證 tablet 資料無遺失（RF=3 期間其他
replica 撐著，純觸發 re-replicate）。

修完 master quorum 後重跑，卡在 cold-reset 重啟 `.32`：發現 `/var/yugabyte/conf/
yugabyted.conf` 的 `current_masters` JSON 快取欄位**不會因 yb-admin CLI 改真實
raft membership 而自動更新**——`yugabyted start` 用這個過期快取值決定
`--tserver_master_addrs`，把 `.32` 導向已被移除的 GCP 舊 master 位址，YSQL
proxy 因此連不到正確 leader 而卡死初始化（port 5433 從未 bind）。手動 `sed`
校正該欄位 + 重啟後解決。**已修**（`44d95c42` 的 `--join` fix 不足以解這個問題，
需額外校正快取欄位，本次記錄為完整成因）。

接著 `coldreset-ybdb.sh` 補完 `current_masters` 校正後，prepare 又炸
`pq: timed out waiting for postgres backends to catch up`（06-19 記錄過的
catalog-wait 歷史 bug 重演）——查出 `coldreset-ybdb.sh` 的 `YB_TSERVER_FLAGS`
從未帶 `wait_for_ysql_backends_catalog_version_client_master_rpc_{timeout,
margin}_ms`（ansible 部署時已幫 `.33`/`.34` 加，但 cold-reset 重啟 `.32` 時遺漏）。
**已修**（`9f3306fe`，補上與 `.33`/`.34` 一致的 300000/600000 ms）。

補完 flag 後同一 panic 又發生一次（15 分鐘才逾時，比之前久但仍炸），追查發現
**`.33` 本機 postgres backend 完全死鎖**——連本機 `SELECT 1` 都逾時，且有一堆
卡在 `[local] startup` 狀態、持續累積從未清掉的 backend process；但同時
`list_all_tablet_servers` 顯示 `.33` 的 tserver 心跳完全正常。**成因未查完，
user 於此時下令中止**（改走全拆 VM + 彙整交接文件，轉交 Fable 規劃）。

**結論**：YBDB Stage 1 smoke 本輪仍未完成。3 個腳本修復已 commit（見下），但
master quorum race 本身**未落回 playbook/fix6n**（2/2 復現率，下次大概率重演）；
postgres 死鎖成因未查出，不建議直接重跑賭它不會再發生。完整分析、手動修復步驟、
待查線索、建議路線見 `fable-refactor/ybdb-master-quorum-handoff.md`（交接文件，
本次新增）。VM 已全拆（`phase9-tunnels-stop phase9-destroy`）。

**Last updated**：2026-07-09 YBDB smoke 二輪重跑，抓到 master quorum race 復現 2/2 + catalog-wait 連環 3 層，postgres 死鎖成因未查完中止，交接 `fable-refactor/ybdb-master-quorum-handoff.md`。
**Next review**：依交接文件建議路線處理 master quorum race 治本（ansible join 序列化）或治標（fix6n gate + current_masters 動態校正）；`.33` postgres 死鎖成因需先定位才能安全重跑 YBDB smoke。

**（07-09 補記，Fable 規劃）**：上兩行的懸念已定案——join play 早有 `serial: 1`，race
真正機制是 yugabyted master 選擇 region-blind（`--cloud_location` 從未設定，master 擴編
發生在 `configure data_placement --rf=3`，選節點無 region 概念）。解法不走 playbook 治本
（yugabyted 設計是跨 zone 分散、與 P-A 單 zone 集中相反，賭不得），改在 `phase4-ybdb-fix6n`
接入強制手術 gate `scripts/ybdb-master-quorum-gate.sh`（raft 修正 + 全節點 current_masters
conf 校正 + 6/6 YSQL 健檢，fail-closed，postgres 死鎖類問題自動留證據+重啟修復）。
完整根因分析、測試計畫（Stage 0/A/B/C）、交辦 kickoff prompt 見
`fable-refactor/ybdb-master-quorum-handoff-solution.md`，待另一 session 執行驗證。

### 2026-07-09（三續）YBDB smoke 執行 solution doc 測試計畫，Stage 0→A→B→C 全過，Stage 1 三家 DB 至此全數完成

照 `ybdb-master-quorum-handoff-solution.md` §4 逐 Stage 執行：

**Stage 0**：`bash -n` + `make -n phase4-ybdb-fix6n` 靜態檢查皆過。

**Stage A**（phase1→phase2→phase4）：gate 首次 live 跑就抓到 gate 腳本自己的
bug（非部署層 race）——`while read ... done < <(...)` 迴圈裡呼叫 ssh 的經典
「ssh 吃掉迴圈 stdin」陷阱，REMOVE 非 IDC master 那段只處理了一半（4 台裡的
1 台非 IDC 被吞掉，終局 assert 正確 fail-closed 擋下）。本輪 pre-repair 現況
更嚴重：2 台 GCP 節點同時搶到 master（`10.160.152.13` + `10.160.152.11`），
比先前記錄的「1 台」更確認 race 的嚴重度。修 `$SSH` 加 `-n`（連帶把衝突的
python3 heredoc 改寫成純 sed，更簡單也更穩健），重跑 `phase4-ybdb-fix6n` 收尾：
`quorum gate PASS`，人工複核 `yb-admin list_all_masters` 確認恰 3 台全 IDC、
恰 1 LEADER。證據（`.33`/`.34` 的 `yugabyted.log`）scp 回 repo：`.33` 自己的
log 顯示它剛啟動時查詢 `.32`「目前 masters 是誰」，得到回覆包含 2 台 GCP IP——
坐實 race 發生在 `configure data_placement --rf=3` 搶先選中 GCP 節點，而非
join 序列化問題（與規劃階段的根因分析一致）。

**Stage B**（cold-reset 隔離演練）：`coldreset-ybdb.sh` 本身四項驗收全過，但
擴大驗證時發現交接問題 3（`.33` postgres 死鎖懸案）的真正成因——**`.33`/`.34`
從部署以來持續運行、從未重啟過，各自的 `--tserver_master_addrs` 仍是部署當下
的殘缺清單（各缺 1 台其他 IDC peer）**。conf 校正（gate step 5）只影響「下次
restart」，對這種從未重啟的既有 process 無效。手動逐台 restart（`.33`→`.34`，
一次僅停 1 台不失 majority）修復後 6/6 YSQL 健檢過。隨即把這個檢查+自動修復
邏輯補進 gate 本身（新 step 5.5：逐台核對 live flag，缺漏就重啟該台一次），
重跑整支 gate 驗證冪等——全 6 節點回報 OK，無需再重啟。

**Stage C**（全鏈 smoke，TS=`20260709T140516+0800`）：**YBDB × P-A × A-S 首次
一次跑到底**，`.suite.done`、placement gate PASS（idc=3/3=100%，07-08/07-09
grep -c 修正首次 live 驗證生效）、freeze-state dump 齊（M5 首驗）、無非預期
failed.txt、`summary.json` 有值：tpmC_mean=2999.0，**全交易 error_count=0**
（先前 3 次嘗試全敗在 master quorum race / catalog-wait 連環，這是首次乾淨
跑完整個 benchmark）。收尾：static-check PASS → fetch（去重，只留本輪 TS 目錄）
→ `phase9-tunnels-stop phase9-destroy` 拆 VM → commit。

**結論**：TiDB（`20260708T160747+0800`）+ CRDB（`20260708T214141+0800`）+
YBDB（`20260709T140516+0800`）三家 Stage 1 cross-region smoke **至此全數完成**。
本輪額外修復並 commit：master-quorum gate 的 while-read/ssh-stdin bug、
tserver_master_addrs live flag 校驗（解交接問題 3 懸案）。

**Last updated**：2026-07-09 YBDB smoke 執行交辦測試計畫 Stage 0→A→B→C 全過，Stage 1 三家 DB（TiDB+CRDB+YBDB）全數完成。
**Next review**：Win-1 CRDB/YBDB W=128 前記得移除本輪 smoke 遺留的低 warehouse 測試資料；master-quorum gate 已驗證可重複使用於後續每次 YBDB deploy，往後 phase4-ybdb-fix6n 皆會自動套用不需再手動介入。

### 2026-07-11/12 W=128×N=5×3-DB 正式測試（`phase-crossregion-w128-suite`）首輪，抓到 TiDB t128 tpmC 異常 + leader-snapshot SQL 少 tpcc 過濾的舊 bug

Stage 1 三家 smoke 全過（07-09）後，依 NEXT-STEPS Path 1.2 進入正式 W=128 測試。
`make phase-crossregion-w128-suite`（TiDB→CRDB→YBDB 同一 VM 生命週期/同一時間窗）
一次跑完，TPCC_TS=`20260711T215200+0800`，總耗時約 11h17m。

**結果總覽**（t128 主水位）：

| DB | t16 | t32 | t64 | t128 | 全程交易錯誤 |
|---|---:|---:|---:|---:|---:|
| TiDB | 2066.3 | 4072.7 | 7425.6 (CV6.3%) | **7576.0 (CV 102.2%)** | 0/1,175,475 |
| CRDB | 8776.9 | 9963.9 | 10249.7 (CV2.0%) | 10453.5 (CV5.2%) | 0/2,189,931 |
| YBDB | 7836.8 | 8991.4 | 9727.0 (CV8.9%) | 9581.4 (CV8.6%) | 0/2,000,524 |

CRDB/YBDB 皆正常收斂（CV<10%）；**TiDB t128 五輪 tpmC = `13601.5, 6513.7,
6030.0, 5855.2, 5879.5`**——round 1 對齊 07-03 baseline 量級（16,808.6 同級距），
round 2 起腰斬到 ~6000 並穩定盤整，CV 102.2%，不能視為合格的正式 cell。

**排查過程（重要：第一版懷疑「leader 漂到 GCP」是誤判，已修正）**：

1. 一開始比對 post-run leader-snapshot（`leader-snapshot/tidb-region-leaders.txt`）
   看到 GCP store 反而 leader 數較多（GCP 13 vs IDC 10），懷疑是 PD 在 t128 高負載下
   把 leader 均衡到 GCP、P-A policy 只在 prepare 時驗一次沒有持續校正——**這個懷疑事後
   證實是誤判**。
2. 回頭讀 `Makefile` 才發現：phase6-tidb-smoke 裡有兩條 SQL，一條是跑完全程後的
   **leader gate**（`phase-crossregion/Makefile:472`，有 `JOIN tikv_region_status ...
   WHERE r.DB_NAME='tpcc'`，正確只算 tpcc 表的 leader），另一條才是 **leader-snapshot**
   （`:480-488`，少了 `DB_NAME='tpcc'` 過濾，整個 cluster 的 region 都算進去）。
3. 查 pipeline log：leader gate 在跑完全部 5 輪×4 檔 threads 之後**第一次輪詢就命中
   100%**（`TiDB tpcc region leaders 100% on IDC`，沒有任何「XX/30 leaders on IDC: NN%」
   的中間輸出），代表 tpcc 表的 leader 從頭到尾都沒漂移。leader-snapshot 顯示的 GCP
   leader 數，其實是系統 schema／未套 placement policy 的其他 region 的 leader
   （PD 預設對這些 region 做全域 leader 均衡，本來就正常分布到 GCP store，跟 tpcc
   資料無關）——**不是真正的漂移，是量測腳本本身的 schema bug 造成的誤導訊號**。
4. 已修正 `Makefile:480-488` 補上 `JOIN tikv_region_status` + `WHERE r.DB_NAME='tpcc'`
   過濾，跟 gate 查詢一致，避免下次再被系統表雜訊誤導。

**（07-14 補記）「leader 飄移」誤判的 raw 證據路徑索引**（供稽核，兩組對照）：

- 誤導訊號本體（當時被讀成飄移的檔案）：
  [07-11 tidb-region-leaders.txt](../results/x-cross/baseline/w128/20260711T215200+0800/tidb-vm-6node-P-A-rc-20260711T215200+0800/leader-snapshot/tidb-region-leaders.txt)
  ——全 cluster 無過濾快照，GCP store 合計 13 leader 全屬系統 schema region
  （PD 對未掛 policy 的 region 本就全域均衡），非 tpcc 資料。
- 證偽證據 1（同輪、prepare 時 tpcc-scoped gate）：
  [07-11 placement-gate-P-A.json](../results/x-cross/baseline/w128/20260711T215200+0800/tidb-vm-6node-P-A-rc-20260711T215200+0800/prepare/placement-gate-P-A.json)，
  `idc=19/19、gcp=0`。
- 證偽證據 2（重跑輪、修正後查詢的同型快照）：
  [07-12 tidb-region-leaders.txt](../results/x-cross/baseline/w128/20260712T164221+0800/tidb-vm-6node-P-A-rc-20260712T164221+0800/leader-snapshot/tidb-region-leaders.txt)
  ——加上 tpcc 過濾後 post-run 只列 3 台 IDC store（8/8/3）、0 GCP。
- 證偽證據 3（查詢邏輯差異本身）：`phase-crossregion/Makefile` gate 查詢（有
  `DB_NAME='tpcc'`）vs 舊 snapshot 查詢（無），修正 commit `621f24f1`。
- **已知證據缺口（誠實揭露）**：上文第 3 點引用的「leader gate 首次輪詢即 100%」
  console 輸出，出自 Mac 端 pipeline log（session 暫存目錄），**未歸檔進 repo、
  現已不存在**，僅剩本節文字記載。此缺口是後續把 gate 證據一律落檔到 suite 目錄
  （如 `gate/gcp-replica-gate-*.txt`）的動機之一；結論本身由上列 in-repo 證據鏈
  獨立支撐，不依賴該遺失檔。

**t128 tpmC 腰斬的真正成因仍未確認**：go-tpc 全程無 error/retry/warn，round 1→2 是
乾淨的 step-function 下降後盤整（不是漸進式衰退），推測是 t128 高並發持續 25 分鐘
下 TiKV compaction / write-stall 或 buffer pool 由 round 1 殘留的暖態退回真實穩態
（round 1 數字才是異常偏高，而非 round 2-5 異常偏低），但因 VM 已於 phase9 拆除
無法回頭查 TiKV metrics 佐證，需靠重跑驗證是否可重現。

**下一步**：重跑一次「只跑 TiDB」的 W=128（同 4 檔 threads、5 rounds、20min warmup，
不含 CRDB/YBDB，省下 ~7hr），確認 t128 CV 是否恢復正常（<10%）。若可重現，代表
是需要處理的容量/調校問題（TiKV compaction 或 rate-limiter 設定）；若這次正常，
判定為單次環境雜訊（例如剛 rebuild 的 VM 磁碟尚未進入穩態），07-03 的
`16,808.6 tpmC / CV2.4%` 仍是有效的正式 TiDB baseline 直到有新的乾淨 cell 取代。

**Last updated**：2026-07-12 W=128 三家正式測試首輪完成，CRDB/YBDB 收斂正常，
TiDB t128 CV 異常但排查後排除「leader 漂到 GCP」的誤判（leader-snapshot SQL
schema bug 已修正），真正成因待重跑驗證。
**Next review**：TiDB-only W=128 重跑結果出爐後，回填此節判定 t128 異常是否可重現；
若可重現需另開 TiKV compaction/write-stall 調校議題。

### 2026-07-12（續）TiDB-only W=128 重跑驗證：t128 CV 恢復正常，判定首輪為單次環境雜訊

依上節「下一步」重跑 TiDB-only W=128（`phase1 phase2 phase3-tidb-deploy
phase6-tidb-smoke phase6-tidb-result phase8.5-static-check teardown-tidb phase9`，
不含 CRDB/YBDB，省下 ~7hr），TPCC_TS=`20260712T164221+0800`，全鏈約 4h。

**結果**：四檔 threads 全部收斂正常，`all_txn` 全程 0 error（1,490,296 筆交易）：

| threads | tpmC_mean | CV | 備註 |
|---:|---:|---:|---|
| 16 | 2077.1 | 3.6% | |
| 32 | 3820.8 | 28.0% | round-2 單輪偏低（3048.1 vs 其餘 3965~4119），非持續性 |
| 64 | 7681.8 | 4.6% | |
| **128** | **13251.6** | **4.0%** | 五輪 13188.2/13087.6/13268.1/13099.1/13614.8，緊密收斂 |

t128 CV 從首輪的 102.2% 降到 4.0%，**首輪的 round-2 起腰斬（~13600→~6000盤整）
判定為單次環境雜訊，不可重現**（可能是剛 rebuild 的 VM/磁碟首次高負載尚未進穩態，
或 vSphere host 端偶發資源競爭；因首輪 VM 已拆除無法回頭查證，暫不深究，判定
不影響 pipeline 或 P-A 設計正確性）。

**驗證修正的 leader-snapshot 查詢**：套用 tpcc-scoped 過濾後，post-run 快照只
列出 3 台 IDC store（172.24.40.32/33/34，leader_count 8/8/3=19），**完全沒有
GCP store 出現**——證實 P-A leader pinning 全程正確，先前的「GCP leader 較多」
訊號確定是系統 schema 雜訊造成的誤判，修正後的查詢邏輯正確可信。

**結論**：本輪 `13251.6 tpmC / CV4.0%` 是乾淨的 TiDB W=128 t128 cell，可作為
正式 baseline 候選（與 07-03 的 `16,808.6 tpmC / CV2.4%` 量級有落差，約低 21%，
推測是不同批次 VM/環境正常變異，非缺陷；若要精確比對需同批次重跑三家）。

**Last updated**：2026-07-12 TiDB-only W=128 重跑驗證完成，t128 CV 4.0% 恢復正常，
確認首輪 CV102.2% 為單次環境雜訊不可重現；leader-snapshot SQL 修正後驗證 P-A
全程 100% IDC 屬實。
**Next review**：若後續要用本輪 TiDB cell（`20260712T164221+0800`）取代 07-03
baseline 需更新 `results/x-cross/pipeline-log.md` §2.3；CRDB/YBDB 尚未有同批次
重跑版本，跨家精確比較仍待补齊。

**（07-12 補記）**：依上述四份數據（TiDB 首輪不採用、CRDB/YBDB 首輪 + TiDB 重跑採用）
產出 X-CROSS 階段結案報告雛形 `XCROSS-CLOSING-REPORT-DRAFT.md`——全實測數據、
參數口徑逐項連結原始採樣（summary.json 欄位 / gate / freeze-state / wan-probe /
leader-snapshot），效度邊界含批次差與 YBDB read-replica 架構語意差異。

### 2026-07-13 重大效度發現：CRDB/YBDB 的 GCP 節點零 tpcc 資料 — 三根因修正 + 新 gate（重跑待 approve）

驗證「P-A 的 A/S standby 存在紀錄」時發現 w128 首輪 CRDB/YBDB 的 GCP 節點
**完全沒有 tpcc 資料**——benchmark 全程等於 IDC-only 3 節點 + 3 台空 GCP 成員，
「IDC CRUD 同步 GCP」未被驗證。tpmC 數字本身有效（流量本就全走 IDC），但
CRDB/YBDB 兩個 cell 不符 P-A「GCP 持有副本/就近讀」語意，降級為備查。

**三個根因（全部檔案級證據）**：

1. **CRDB**：[tests/cockroach/placement-p-a.sql](../tests/cockroach/placement-p-a.sql)
   的 `constraints='[+region=idc]'`（list form＝約束**全部**副本）與
   `voter_constraints '{+region=gcp: 1}'` 自相矛盾，allocator 以前者為準 →
   3 voters 全 IDC。證據：suite 的
   [prepare/schema.txt](../results/x-cross/baseline/w128/20260711T215200+0800/crdb-vm-6node-P-A-rc-20260711T215200+0800/prepare/schema.txt)
   顯示 config 有套上，但
   [placement-gate-P-A.txt](../results/x-cross/baseline/w128/20260711T215200+0800/crdb-vm-6node-P-A-rc-20260711T215200+0800/prepare/placement-gate-P-A.txt)
   的 `replica_localities` 全 `{idc,idc,idc}`。**修**：constraints 改 counted
   form `'{+region=idc: 2}'`（DATABASE + 9 表，經 user 授權修改保護區檔案）。
2. **YBDB**：fix6n Plan B 的 `add_read_replica_placement_info ... ybdb_gcp_rr`
   要求 placement_uuid=`ybdb_gcp_rr` 的 tserver，但
   [yugabyte-vm6.yml](../ansible/playbooks/yugabyte-vm6.yml) 從未設
   placement_uuid flag → **零台 tserver 匹配，RR tablet 永不實體化**。證據：
   [ybdb-tservers.txt](../results/x-cross/baseline/w128/20260711T215200+0800/ybdb-vm-6node-P-A-rc-20260711T215200+0800/leader-snapshot/ybdb-tservers.txt)
   三台 GCP SST=0B、[sar-net GCP](../results/x-cross/baseline/w128/20260711T215200+0800/ybdb-vm-6node-P-A-rc-20260711T215200+0800/runs/threads-128/round-1/sar-net-db-gcp-dbhost-1.txt)
   rx≈3kB/s。**修**：fix6n 改 live 2 IDC + 1 GCP(zone-a) voter
   （`modify_placement_info '104.idc.vlan241:2,104.gcp.asia-east1-a:1' 3` +
   `set_preferred_zones 104.idc.vlan241`），對齊 TiDB/CRDB 語意：quorum 2/3
   IDC-local commit、GCP follower 持續收 raft log。
3. **GCP probe fail-quiet**：`run.sh` 的 GCP 端 probe 打 `.14` GCP haproxy，
   四 suite × 每 round 100% 連線失敗（例：TiDB#1 的
   [probe-iso-latency-gcp-t128-r1.json](../results/x-cross/baseline/w128/20260711T215200+0800/tidb-vm-6node-P-A-rc-20260711T215200+0800/runs/threads-128/round-1/probe-iso-latency-gcp-t128-r1.json)，
   fail_count≈520、全 null）但 `|| true` 吞掉。**修**：
   [Makefile](Makefile) 三個 smoke target 加 `GCP_PROBE_DB_HOST=10.160.152.11`
   直打 GCP DB 節點（env override，不動保護區 run.sh）。

**新 fail-closed gate（堵靜默通過）**：

- 新增 [scripts/gcp-replica-gate.sh](scripts/gcp-replica-gate.sh)，接入
  [run-vm6-suite.sh](scripts/run-vm6-suite.sh) post-prepare（freeze 前）：
  TiDB 驗 gcp follower>0 且 gcp leader=0（順便落 follower 分布證據，補 TiDB
  只存 leader snapshot 的缺口）；CRDB 逐 range 驗 replica_localities 含 gcp
  且 lease 全 idc；YBDB 驗 universe live placement 含 gcp + GCP tserver
  SST>0（含 flush retry）。證據落 `gate/gcp-replica-gate-*.txt`。
- [check-static-artifacts.py](scripts/check-static-artifacts.py) 加驗：
  gcp-replica-gate 證據檔必須存在；每 suite 至少 1 份
  `probe-iso-latency-gcp-*.json` 且全部 `select_1.fail_count==0`。

**對照組**：TiDB 本來就正確（policy `REGIONS="idc,gcp"` + MAJORITY_IN_PRIMARY，
GCP round 級 rx≈1.7MB/s = follower 持續收 log），TiDB#4 cell 維持有效。

**下一步**：user push 修正後 approve 重跑 CRDB+YBDB w128（各 ~4hr）；報告
§5/§7 已同步標注兩 cell 降級，重跑後回填。

**（07-13 續）YBDB GCP 副本分散設計調整**：user 要求 GCP 三台（.11/.12/.13）
都要承載資料，但 yb-admin placement block 是 cloud.region.zone 粒度、三台各在
不同 GCP zone（a/b/c），照實填 zone 會把 1 個 GCP 副本 pin 死單台。調整：
`yugabyte-vm6.yml` 把 GCP tserver 的 `placement_zone` 統一為 `asia-east1`
（僅 YBDB 標籤，inventory zone var 不動、不影響 TiDB/CRDB label），fix6n
placement block 改 `104.gcp.asia-east1:1`——LB 會把各 tablet 的 GCP 副本均衡
到三台。gcp-replica-gate YBDB 檢查同步加嚴為 3/3 GCP tserver SST>0
（`GCP_MIN_TS_WITH_DATA` 可調）。TiDB/CRDB 本就是 region 級約束、聚合天然分散
三台，無需調整。

**（07-13 續二）事故：`ps aux` 截斷誤判導致同一 YBDB cluster 被兩個 runner 同時打**：
approve 後啟動重跑，中途因誤判前一 runner「已死」（用 `ps aux | grep <完整路徑>`
檢查，macOS `ps aux` 在非寬終端下截斷 COMMAND 欄，grep 完整路徑因而撲空）而補開
第二個 runner——實際兩個 `run-vm6-suite.sh --db ybdb` 同時對同一 cluster 跑
`prepare.sh`（DROP+CREATE+load），存在資料競態風險。user 發現後下令全部 kill +
手動 `phase9-tunnels-stop`/`phase9-destroy` 止血，中止的 TS
（`20260713T110750+0800`）殘留本機 artifact 已清除（未 track，直接刪）。
教訓：存活判斷一律用 `pgrep -f`（比對完整 cmdline 不截斷），不用 `ps aux | grep`；
新版 runner script（`rerun3-ybdb-only.sh`）加兩道防線：(1) lock file 擋同腳本重入、
(2) preflight 用 `pgrep -af` 確認 .31 遠端無殘留 `run-vm6-suite.sh|prepare.sh|go-tpc`
進程才准起跑（preflight 自身也踩過一次「pgrep 抓到自己指令字串」的自我比對 bug，
已修正加 `grep -v pgrep`）。重新以 YBDB-only（先 YBDB、user 訊號後才跑 CRDB）
單一乾淨嘗試重跑，TPCC_TS=`20260713T152813+0800`。

**Last updated**：2026-07-13 CRDB/YBDB GCP 零副本三根因修正完成（constraints
counted form / fix6n live 2+1 / probe 直打 .11）+ gcp-replica-gate 接入 +
YBDB GCP 統一 zone 讓三台均載；重跑過程一度因 `ps aux` 截斷誤判造成雙 runner
競態，已 kill+destroy 止血並修正存活判斷方式，YBDB-only 重跑進行中
（TS=`20260713T152813+0800`）。
**Next review**：重跑後驗 gate 首過（CRDB range 級 gcp 副本、YBDB GCP SST>0、
probe fail_count=0），更新結案報告 §5 主表與 §7。

### 2026-07-14 rerun4 YBDB full test：gcp-replica-gate 首過（3/3 GCP SST>0）；static-check 抓到 probe 第五根因（.15 無 DB client）

前置：vSphere 連線恢復後補跑 `phase9-destroy` 清掉 07-13 殘留的 3 台 IDC VM，
兩邊 terraform state 歸零，以加固 runner（lock + pgrep preflight）重跑
TS=`20260714T085154+0800`（phase1 全重建 → phase2 → YBDB cell）。

**修正鏈驗證成功（本輪核心目標）**：

- master-quorum gate 四連過；fix6n live 2+1（統一 zone `104.gcp.asia-east1:1`）
  + preferred_zones 下發正常。
- **gcp-replica-gate 首次 live 開槍即 PASS**：`gcp_tservers_with_sst=3`（3/3 台
  GCP tserver 都有 SST 資料，.11/.12/.13 全數承載），leader/lease 全 IDC。
  對照 07-11 輪的 GCP SST=0B，「IDC CRUD 同步 GCP + 三台均載」資料面驗證成立。
- benchmark 全程 0 error；t128 五輪 10856.8/9312.9/9671.4/9995.8/10113.9。
  各檔位較 07-11 無效輪（GCP 零副本＝沒付 WAN 複製成本）低約 15-27%，
  方向符合預期（真實 P-A 成本）。

**static-check 抓到 GCP probe 的真正根因（第五根因，推翻 07-13 的 .14 推論）**：

probe 改直打 `.11` 後仍然全滅（每輪 fail_count≈512-523），新加的 fail-closed
斷言在 teardown 前擋下（集群保住可 live 排查）。排查：`.11:5433` TCP 通，但
**probe 主機 `.15`（g-test-poc-5）根本沒有任何 DB client**——`run.sh` 註解宣稱
「go-tpc client host with all 3 DB clients」但 VM 每輪重建、pipeline 從無安裝
步驟。四個 suite 的 probe 全滅都是 `command not found` 快速失敗，
**不是 `.14` haproxy 連線問題（07-13 的推論錯誤，予以修正）**。

**修**（commit 同節）：
1. `Makefile` 新增 `phase2-probe-clients`（fail-closed）：phase2 於 `.15` 裝
   psql/mysql/bc；`phase5-crdb-deploy` 加 cockroach binary 複製到 `.15`。
2. 手動於 `.15` 裝好 client 後 live 驗證 probe：`fail_count=0`，GCP 端
   SELECT p99 207ms / UPDATE p99 734ms（含 psql 每次重連的 WAN 往返，供
   報告判讀 GCP 端就近讀實際成本）。

**續行**：同集群（placement/資料管線已驗證）以新 TS 重跑 YBDB smoke 取得
probe 齊全的乾淨 suite；通過後依 goal 續跑 CRDB cell + phase9。
TS=`20260714T085154+0800` 的 suite 保留備查（benchmark 與 gate 證據有效、
probe 缺 client 證據）。

### 2026-07-14（續）指揮鏈搬 .31 detached；YBDB 乾淨 cell 產出；發現第六問題：transaction status tablet leader 落 GCP

**指揮鏈重構**（user 指示：Mac 斷網/休眠兩度滅掉 live ssh 指揮鏈）：中斷 rerun5、
清空 07-13/07-14 全部中止 TS 的兩端紀錄、VM 全拆重建後，新增
`make win-ybdb-crdb-detach`——rsync Makefile+scripts 到 .31，driver
（`scripts/win-ybdb-crdb-w128.sh`）在 .31 nohup 以 make 跑 YBDB cell →
static-check fail-closed 全綠才進 CRDB cell（零邏輯複製；Mac 只負責
phase1/2 起頭與 phase9 收尾，中途可關機）。TS=`20260714T163716+0800`。
實測：監看 ssh 斷線 driver 不受影響，設計目的達成。

**YBDB cell 全綠**（本輪三重驗證）：quorum gate 五連過；gcp-replica-gate
3/3 GCP tserver SST>0；**GCP probe 全 20 輪 fail_count==0**（phase2-probe-clients
首次入鏈生效）；static-check PASS。t128 tpmC_mean=11,138.6（range/mean 10.4%）。

**第六問題（user 於 raw log 發現，監看 filter 漏抓）**：t32/t64/t128 共 309 筆
交易錯誤（率 0.011-0.03%），型態一致：`UpdateTransaction RPC to
10.160.152.12:9100 timed out after 5s` + `Leader changed
(transaction_coordinator.cc:380)`——**部分 transaction status tablet 的
leader 落在 GCP**，該批交易 commit 協調跨 WAN 撞 5s deadline；t32 的
5,836 dip 輪（range/mean 41.9%）與 NEW_ORDER p99.9 5.4s 尖刺同源。
機制：placement/replica gate 只驗 tpcc 表 tablet；status tablet 屬系統層，
preferred_zones 應管但量測期 LB freeze——若 leader 在 freeze 前已在 GCP
即整場停留。與 TiDB leader 誤判事件同類盲區（系統層漏網）。

**修正方向（下輪前）**：gcp-replica-gate 增 step：`yb-admin list_tablets`
檢查 transaction status tablet leader 全 IDC，違者 `leader_stepdown` 修復
後才放行 freeze（fail-closed）。另記：assistant 先前回報「0 error」為未查
summary.json 的慣性錯誤，已更正；監看 filter 已知漏抓 `execute run failed`
樣式。

**Last updated**：2026-07-14 detached 指揮鏈上線；YBDB 乾淨 cell 產出
（gate/probe 全綠）；發現 status-tablet-leader-on-GCP 問題待下輪 gate 補強；
CRDB cell 進行中。

### 2026-07-15 CRDB cell 三修後全綠；YBDB+CRDB 兩正式 cell 完成（TS=20260714T163716+0800）

CRDB cell 首跑 placement gate FAIL（idc=11/22=50%）連環抓出三個問題並修復：

1. **lease 被動收斂太慢**（constraints counted-form 修正的副作用：GCP 有 voter
   後新 range 的 lease 要靠 preference 慢慢搬，prepare 內建 gate 搶先開槍）。
   修：wrapper watcher 加 lease enforcer——load 期間每 15s 把 lease 在 GCP 的
   tpcc range `ALTER RANGE ... RELOCATE LEASE` 到該 range 的 IDC replica store
   （commit `2aa8450b`；RELOCATE 語法活集群實測）。
2. **同 TS 重跑 stale-marker race**：前次殘留 `drop-create.log` 讓 watcher 提早
   開火撞 concurrent DROP、殘留 placement-gate 檔讓 enforcer 誤判提前退出。
   修：prepare 前清 stale markers + watcher apply 加 5s×24 retry（`1b971cd0`）。
3. **gate 計數 bug（第七問題，藏了整個專案週期）**：`prepare.sh` crdb gate 對
   `SHOW RANGES WITH DETAILS` 整行 `grep -c`——每行同時含副本與 lease 字串，
   P-A 帶 GCP 副本後恆 50% FAIL；舊 config 全副本鎖 IDC 行內無 gcp 字串才
   「碰巧」正確。經 user 授權修 `tests/common/prepare.sh`：計數改
   lease_holder_locality 單欄查詢，GATE_OUT 原始證據不動（`9dc7c720`）。

三修後：placement gate PASS（idc=11/11=100%）、**gcp-replica-gate CRDB 分支
首驗 PASS（ranges_missing_gcp_replica=0、gcp_leaseholders=0）**、benchmark
全程 0 error、20 份 GCP probe 全 fail_count=0、static-check 2 suites PASS、
driver `.done`。

**兩正式 cell 數據（W=128、P-A、A-S、R1-R5 mean）**：

| threads | YBDB tpmC (range%) | CRDB tpmC (range%) | YBDB err | CRDB err |
|---:|---:|---:|---:|---:|
| 16 | 7,207.5 (7.8%) | 9,478.9 (15.2%) | 0 | 0 |
| 32 | 8,148.7 (41.9%*) | 10,364.3 (6.2%) | 57 | 0 |
| 64 | 10,904.1 (11.5%) | 10,809.3 (4.7%) | 67 | 0 |
| 128 | **11,138.6 (10.4%)** | **11,001.1 (4.8%)** | 185 | 0 |

t128 NEW_ORDER p99：YBDB 1,214.7ms / CRDB 959.7ms。
\* YBDB 錯誤與 t32 dip 輪同源於第六問題（status tablet leader 落 GCP，
0.011-0.03%），引用需帶 caveat；CRDB 無此問題（txn record 隨 tpcc range，
lease 全 IDC）。

**收尾**：phase9 fetch 完成（本地 `baseline/w128/20260714T163716+0800/` 已
去重）、GCP 5 台已拆；**IDC 3 台 destroy 卡 vSphere API 斷線（連兩晚同模式，
疑夜間網路維護窗），待恢復補跑 `phase9-destroy`**。

## 2026-07-17/18 — #3 同批三家重跑（win-3db 單鏈、零人工介入）

**目的**：一輪消 O3（非同批）/O9（流程穩定）/TiDB 證據缺口，並驗證 S1
status-tablet gate（07-17 上線，commit `f779242b`）能否讓 YBDB timeout 歸零。

**執行**：`TPCC_TS=20260717T143238+0800`、PLACEMENT=P-A、W=128×4 檔×5 輪。
新 driver [win-3db-w128.sh](scripts/win-3db-w128.sh)（commit `abcfa903`）於 .31
detached 依序 TiDB→YBDB→CRDB，每 cell static-check fail-closed 全綠才進下一家、
完成即歸檔 `/var/lib/poc-tpcc-archive/`。14:32 發射；suite 級完成時刻
（`.suite.done`，repo 內可驗）：TiDB 18:31:07、YBDB 22:21:26、CRDB **01:40:02**
（≈11h07m）。01:45 為 .31 端 driver 歸檔完成 marker（未入庫，driver 口徑
≈11h13m）。**全程零人工介入**為本節操作紀錄（O9 證據等級見報告 §8.1）。
phase9 fetch（去重後 120M 入 `baseline/w128/20260717T143238+0800/`）
＋兩側 VM destroy、terraform state 歸零。

**結果**（t128 主水位，range% 口徑）：TiDB 12,526.5（5.7%）0 err、
CRDB 10,163.4（19.2%，R4 單輪塌 8,673）0 err、YBDB 12,769.5（13.0%）156 err。

**S1 驗證（O1 關鍵證據）**：prepare 後 gate dump 到 **9/16 transaction status
tablet leader 在 GCP** → `leader_stepdown` → 10s 後 16/16 IDC 才放行
（[status-tablets 前後 dump](../results/x-cross/baseline/w128/20260717T143238+0800/ybdb-vm-6node-P-A-rc-20260717T143238+0800/gate/gcp-replica-gate-ybdb-status-tablets.txt)）。
「leader 落 GCP」由機制推論升級為實測事實；`list_tablets system transactions`
第一形式即成功（dual-form fallback 未動用）。**但錯誤未歸零**：156 筆
（3/9/59/85 隨併發遞增；#2 批為 309 筆——跨批觀察，不得解讀為 S1 效果）。
其中 10 筆為 `Not the leader (tablet server error 15)`——run 中 status tablet
leader 曾變動的 raft 層直接證據。候選機制與證據強弱詳報告 §6.3
（07-18 audit 勘誤：本節先前記載「t128 99.9th 3.9-4.8s」有誤，實為 2.7-3.6s，
4.3s 出現在 t64 R4）。→ 依拍板備援走
`transaction_rpc_timeout_ms` 5000→15000（下輪 YBDB 驗證）。

**額外收穫**：TiDB 本批補上 gcp-replica-gate（gcp_followers=19/gcp_leaders=0，
#2 批缺此層）；YBDB tpmC 較 #2 批 +14.6%（跨批觀察，落在已知批次噪音帶
——RETRO 記錄同參數跨批差可達 21%）。
**新單輪異常**（O2 追加，均根因未確認）：TiDB t16 前二輪偏低（~-43%）、
TiDB t32 R4 小幅下降（與 #2 批 t32 同型態）、YBDB t64 R4 深塌 3,893（與該檔
59 筆錯誤同檔位）、CRDB t128 R4 塌 8,673。

**工具事故（RTK，操作紀錄；因果為推論）**：07-17 首次 phase1 重建中斷——
make ~2 分鐘假性 exit=0、terraform apply 中途被殺、鑑識命令輸出失真；症狀與
RTK hook（PreToolUse Bash 命令改寫層）的已知行為一致，移除 hook 後重跑全綠。
單一事件、移除後未回測重現，因果未受控驗證。教訓：任何改寫命令/輸出的
中間層都是量測與運維的失真源。

**報告**：07-18 [XCROSS-CLOSING-REPORT-DRAFT.md](XCROSS-CLOSING-REPORT-DRAFT.md)
改採 #3 批為正式數據（#2 批轉備查、§9.4 保留證據索引）；O3/O9 移 §8.1 結案、
O8 已結、O1/O2/O4/O6 更新。

## 2026-07-18（續）— O1 收殘輪：YBDB 單家重跑，flag 未生效但 0 錯誤（自然對照）

**執行**：`TPCC_TS=20260718T060324+0800`、`DBS=ybdb`（driver 選家功能首用，
commit `c9ae41b6`）。06:03 發射 → 09:52 done（3h49m），static-check 全綠，
phase9 fetch＋兩側 destroy 歸零。suite：
[baseline/w128/20260718T060324+0800](../results/x-cross/baseline/w128/20260718T060324+0800/)。

**結果**：**0/1,794,566 錯誤**；t128 mean 11,015.7、range% 3.8（歷來最緊）。
S1 gate 本輪也在 prepare 抓到 **12/24** status tablet leader 在 GCP → stepdown
修復後放行（gate 證據檔同 suite `gate/`）。

**關鍵反轉（artifact 實證）**：varz 顯示 `transaction_rpc_timeout_ms` 仍
**5000**——playbook 設的 15000 未生效；同 varz 亦見 `enable_automatic_tablet_splitting`
設 false 顯 true（0717 批同病），而同串 `memory_limit_hard_bytes` 等正常套用
⇒ **yugabyted start 的 --tserver_flags 對部分 runtime flag 不生效**。因此：
(1) timeout 單變量實驗「尚未真正執行」；(2) 本輪意外成為自然對照——同設定
（5000）下錯誤 156→0，證明錯誤為陣發/批間變動，增強 §6.3 候選 (b)（離散
leader 事件）、削弱「5000 必然產生錯誤」的預期。

**措施（implemented, pending validation）**：新增
[ybdb-runtime-gflags.sh](scripts/ybdb-runtime-gflags.sh)（yb-ts-cli set_flag
runtime 強制 + 6/6 varz 驗證 fail-closed，volatile——tserver 重啟即還原）接入
`phase4-ybdb-fix6n`；playbook 加警示註解。

**Last updated**：2026-07-18 O1 收殘輪完成（0 錯誤；timeout 真實驗待跑）、
84e84d audit 修訂五檔、報告改採 #3 批。
**Next review**：是否加跑「真 15000」單變量輪（O1 定案）由拍板決定；
P-B×A-S（CRDB 先行）。

## 2026-07-18（續）— A-A-RO smoke：三家首跑雙端並發，抓出 4 個根因 bug

**目的**：驗證 A-A-RO（IDC 讀寫＋GCP read-only）執行鏈、雙端資料採集、
read-tpmTotal 計算是否符合 G1-G6（`decisions-2026-06-08.md` 07-15 附錄）。
Sonnet subagent 執行（省 Fable token），per-cell 獨立重建 VM（TiDB→CRDB→YBDB，
中斷後不沿用舊環境）。

**結果**（W=4 t16 smoke）：三家 PASS。TiDB tpmC=1,563.3/0 err、CRDB
tpmC=7,397.1/1 err（0.0012%，延遲 188.7ms 非 timeout 特徵，判噪音）、YBDB
tpmC=6,370.7/0 err；GCP 側 read_tpmTotal 16,282.0／19,828.0／21,871.4，皆與
raw stdout 手動重算逐位元相符，`tpmC=null`（G2 正確）。完整彙整見
[SMOKE-AARO-SUMMARY.md](SMOKE-AARO-SUMMARY.md)。

**4 個根因 bug**（此前 GCP 側從未跑過完整 workload、僅 near-read probe，
故從未觸發）：
1. GCP client（`.15`）從未部署 go-tpc/tests/common → 新增
   `scripts/bootstrap-gcp-client.sh` + `phase2-bootstrap-gcp-client` target。
2. GCP 側經 `tests/common/run.sh` 必炸——`coldreset-${DB}.sh` 一律 SSH 回
   IDC 控制節點，`.15` 無路由。改 GCP 側直呼 go-tpc（不經 protected 的
   run.sh），round-barrier 與 IDC 側對齊。
3. `--mix`（冒號分隔）go-tpc 無此 flag，實際是 `--weight`（逗號分隔、
   順序不同）——修正映射。
4. `tests/common/prepare.sh` 的 placement-gate regex `P-[AB]$` 認不得 Q17
   token 目錄（`P-A-aaro` 非字串結尾）→ 新增 `prepare-bridge`：從同
   DB/PLACEMENT 的 plain anchor 複製已驗證證據（同一顆共用 cluster，非
   造假）。

Commit：`e2cae9a2`（Makefile／run-vm6-aa.sh／bootstrap-gcp-client.sh）。

**Last updated**：2026-07-18 A-A-RO smoke 三家 PASS、READY 進正式輪。
**Next review**：正式 A-A-RO W=128 輪（執行前確認 plain anchor 仍存在，
prepare-bridge 依賴它）；P-B×A-S（CRDB 先行）。

## 2026-07-20/21 — A-A-RO W=128 正式全輪：三家 0 錯誤，中途抓到新 bug

**執行**：`TPCC_TS=20260720T101928+0800`，`win-aaro-w128.sh`（前一輪補齊的
detached driver）TiDB→YBDB→CRDB。10:19 發射；每家 deploy→`ANCHOR_ONLY=1`
prepare（快速產生 plain anchor，省去整段 baseline workload 才能拿到
prepare-bridge 證據）→ aaro-smoke（真 W=128×4 檔位×5 輪）→
`check-aaro-artifacts.py` 驗證→ teardown→ 歸檔，三家共用同一批 VM
（teardown 只拆軟體不動 VM，`phase1+phase2` 只在批次開頭建一次）。

**結果**：三家全程 **0 錯誤**（IDC `_ERR` 與 GCP `execute run failed` 雙口徑
核實）。IDC t128 主水位：TiDB 15,182.5、YBDB 12,882.5、CRDB 11,331.1；GCP
read_tpmTotal t128：TiDB 31,571.3、YBDB 56,787.9、CRDB 41,056.3。完整彙整見
[XCROSS-AARO-CLOSING-REPORT-DRAFT.md](XCROSS-AARO-CLOSING-REPORT-DRAFT.md)。

**中途插曲（新 bug，已修復）**：TiDB cell 首次驗證 FAIL——`merge-gcp-stdout.sh`
的 `while read` 迴圈內 `ssh ... cat ...` 未把 stdin 導向 `/dev/null`，偷走
迴圈自己的 here-string 輸入，20 筆待合併檔案只處理 1 筆（`threads-128/round-1`）。
與先前 `ybdb-master-quorum-gate.sh` 同一種陷阱重演（見 07-08 節）。
`check-aaro-artifacts.py` 正確 fail-closed 攔下，未讓半套 artifact 靜默通過。
修復：`< /dev/null`（commit `78796957`）。修復後**手動補救 TiDB 既有結果**
（IDC/GCP 兩側 raw stdout 本就完整，只有合併步驟出錯）——重跑修好的
`merge-gcp-stdout.sh`（20/20 落位）→ 重生 `summary.json` → 重驗 PASS →
teardown → 歸檔，**不必重跑 ~3hr workload**；YBDB/CRDB 兩家沿用修好版本，
全程零人工介入。

**收尾**：`phase8.5-fetch`＋`phase8.5-check-receipt`（跳過
`phase8.5-static-check`——該腳本假設 plain 4 檔位＋near-read probe json，
對 anchor 目錄與 aaro suite 皆會誤判 fail，改用逐家 `check-aaro-artifacts.py`
把關）；`phase9-tunnels-stop`＋`phase9-destroy`，兩側 terraform state 歸零。
原始 artifact（121M）依拍板**暫不 commit**，`.gitignore` 排除
（`results/x-cross/baseline/w128/20260720T101928+0800/`）。

**Last updated**：2026-07-21 A-A-RO W=128 正式輪三家完成、0 錯誤、報告落檔。
**Next review**：A-A-RO 原始 artifact 留存與否待拍板；P-B×A-S（CRDB 先行）。

## 2026-07-21（續）— GCP 就近讀根因定位與修復（三家）

**背景**：報告 §5.4 查核發現「就近讀執行面未證實生效」，使用者質疑這是
「不合理的推托」，要求找根因並補生效檢驗。深挖後三家各有一個實際阻擋點：

1. **TiDB**：`tidb_replica_read=closest-replicas` 要求 zone 標籤**完全相同**
   才判定「近」（PingCAP docs）；GCP 三台原各自不同 zone（-a/-b/-c），只有
   落在 zone=a 的節點算近。修法：統一為單一 zone `gcp-asia-east1`
   （[ansible/playbooks/tidb-vm6.yml](../ansible/playbooks/tidb-vm6.yml)）。
2. **CRDB**：`kv.closed_timestamp.follower_reads.enabled=t` 只開能力，plain
   SELECT 不會自動用。修法：GCP 側連線加
   `default_transaction_use_follower_reads=on`（僅 GCP 側 session 層）。
3. **YBDB**：`yb_read_from_followers=on` 只在交易本身 read-only 才生效。
   修法：GCP 側連線加 `default_transaction_read_only=on`。

兩處修法皆落在 [run-vm6-aa.sh](scripts/run-vm6-aa.sh) 的 `GCP_CONN_PARAMS`
（僅 GCP 側，IDC 寫入路徑不受影響）。

**驗證**（smoke 規模，各家用最強可得證據，而非延遲/netflow 推論）：
- TiDB：500 筆讀取乾淨網路流量測試，GCP 入口節點對 IDC 流量比值從（隱含）
  等同強制 leader，降到 **5.7%**。
- CRDB：`EXPLAIN ANALYZE` 8/8 一致顯示 `used follower read`＋`regions: gcp`
  ＋單節點（n4）執行，KV time 600-960µs。
- YBDB：`EXPLAIN (ANALYZE, DIST)` 對照，follower-read 穩態 ~2.5ms vs 強制
  leader-read ~9-13ms（量級吻合 WAN RTT）。

**過程插曲**：本地背景任務（Bash `run_in_background`）兩度在長時間操作
（TiDB／CRDB 的 ANCHOR_ONLY 資料載入）中途被砍，導致遠端程序透過斷開的
pipe 收到 SIGPIPE（exit 141）而中止——與先前 A-A-RO 全輪 driver 已採用的
「nohup 完全脫離本地 session」原則相同，本次補上後穩定運作。

**方法論教訓**：延遲對照與 netflow 流量比值兩種「執行面」驗證手段證據力
皆弱——延遲被 TSO 往返/併發競爭混淆，netflow 在小資料量下被叢集背景流量
（raft heartbeat/gossip）淹沒，即使放大 10 倍 burst 比值仍不變也可能只是
訊噪比問題（CRDB 即為此例：netflow 測 74-85%，但 EXPLAIN ANALYZE 決定性
證實生效）。已落成可重用腳本 [check-nearread.sh](scripts/check-nearread.sh)，
用各 DB 最強證據取代弱推論。

**限制**：僅 smoke 規模（W=4/單筆查詢）驗證，未重跑完整 W=128 A-A-RO 批次；
報告 §1-§6 採用數字仍是修法前的 07-20 批（吞吐數字本身不受影響）。

修改檔案：`ansible/playbooks/tidb-vm6.yml`、`run-vm6-aa.sh`、
`check-nearread.sh`（新增）、報告 §5.5/§8 A6 更新（本節同批 commit）。

**Last updated**：2026-07-21 就近讀根因定位＋三家修法驗證完成（smoke 規模）。
**Next review**：是否重跑完整 W=128 A-A-RO 批次（用修法後配置＋
`check-nearread.sh` 驗證）；P-B×A-S（CRDB 先行）。

## 2026-07-22 — 就近讀修復獨立審查（codex）＋修正

**背景**：上一節（07-21）的根因定位／修法／驗證未經第三方複核即寫入報告，
使用者要求用 `codex exec --sandbox read-only` 對報告 §5.4/§5.5 與相關檔案
（`ansible/playbooks/tidb-vm6.yml`、`run-vm6-aa.sh`、`check-nearread.sh`）
做無背景脈絡的獨立審查，確認問題判定與驗證方法方向是否正確。

**總評**：PASS WITH CAVEATS。機制診斷（三家根因）與修法方向（zone 統一／
session 層 follower-read 開關）均與官方文件一致，判定正確；但指出 4 項
具體問題，逐一經 parent 用 grep/程式碼複核，**全部屬實**：

1. `check-nearread.sh` 未真正 fail-closed：
   - TiDB 分支算出 GCP TiKV store 的 zone 集合（`STORE_ZONES`）後從未拿去
     跟 `OWN_ZONE` 比對，實際只驗「zone label 存在」，不驗「近讀條件是否
     成立」（原第 45-52 行）。
   - CRDB 分支 region 非 gcp 時只印 `WARN`，不 `exit 1`，也未驗
     `sql nodes`/`kv nodes` 是否皆為 GCP（原第 65-69 行）。
   - YBDB 僅單次取樣、`<70%` 門檻易受單次抖動誤判。
2. 報告 §5.3 TiDB 列仍寫「機制驗證成功」，未區分「執行鏈驗證成功」與
   「近讀生效已驗證」兩件事。
3. 報告 §6 仍有一句與 §5.4/§5.5 判讀矛盾的舊敘述（暗示 read-only 查詢
   多數已走 GCP 本地副本，早於根因修復前寫下）。
4. TiDB 的 zone 統一修法有未揭露的代價：PD 用
   `replication.location-labels: ["region", "zone"]` 排程副本、辨識故障域，
   壓平 GCP 三個實體 AZ 為單一邏輯 zone 後，PD 不再能用 zone 區分 GCP 內部
   故障域（P-A/RF=3 下影響有限，但 P-B 或未來提高 GCP replica 數時需重新
   評估）。

**修正**（本節同批 commit）：
- `check-nearread.sh`：TiDB 分支改為實際比對每一台 GCP TiKV store 的 zone
  與 `OWN_ZONE`，不符即 `exit 1`；CRDB 分支 region 非純 gcp 或
  sql/kv nodes 出現 idc 節點改為 `exit 1`；YBDB 分支改為 5 次交錯取樣取
  中位數。
- 報告 §5.3：TiDB 判讀改為「執行鏈驗證成功（近讀狀態見 §5.5，本批未修
  法）」，不再單獨宣稱「機制驗證成功」。
- 報告 §6：修正與 §5.4/§5.5 矛盾的舊敘述。
- 報告 §5.5：改寫為逐家信心等級表（CRDB 近乎決定性；TiDB／YBDB 為強支持
  證據，非決定性），新增 TiDB 故障域代價段落，修訂方法論修正段落。
- 報告新增 §5.6「獨立審查（codex，2026-07-22）」，完整記錄審查範圍、總評、
  4 項發現與修正狀態、5 項尚未執行的後續補做建議（依優先序：真實交易取代
  單筆查詢、TiDB 嚴格 A/B、staleness/freshness 驗證、高併發檔位執行期採證、
  統一 zone 前的 placement/故障域評估）。
- 新增 [nearread-verify-evidence-20260721/](nearread-verify-evidence-20260721/README.md)：
  07-21 三家驗證的原始輸出（TiDB zone 標籤查詢、CRDB 8 次 EXPLAIN ANALYZE、
  YBDB on/off 對照、4 輪 netflow pre/post JSON），供第三方獨立複核，回應
  codex 指出的「原始 artifact 未存入 repo」缺口。
- 報告 §8 新增 A7：codex 5 項補做建議（除原始 artifact 補存已完成外）均
  尚未執行，列為重跑完整 W=128 前的把關項目。

**方法論教訓**：外部第二意見的具體技術指控（尤其是「某段程式碼邏輯有洞」
這類可驗證的陳述）應先用 grep/直接讀程式碼逐一複核，而非照單全收或直接
反駁——本次 4 項指控複核後全部屬實，直接依審查意見修正，比爭辯「初版證據
夠不夠」更有生產力。

修改檔案：`check-nearread.sh`（TiDB/CRDB/YBDB 三處 fail-closed 修正）、
`XCROSS-AARO-CLOSING-REPORT-DRAFT.md`（§5.3/§5.5/§5.6/§6/§8/§9 更新）、
新增 `nearread-verify-evidence-20260721/`（README + 12 個原始輸出檔）。

**Last updated**：2026-07-22 codex 獨立審查回應完成——4 項指控全部驗證屬實
並修正；`check-nearread.sh` 現為真正 fail-closed。
**Next review**：依報告 §5.6/§8 A7 優先序決定是否／如何補做剩餘 5 項驗證，
以及是否／何時重跑完整 W=128 A-A-RO 批次。

## 2026-07-22（續）— A7(1)(4) 補強驗證：真實交易＋t128 高併發，意外抓到 go-tpc 結構性 bug

**背景**：codex 審查（§5.6）建議的 5 項後續補做中，用戶指定先做 (1)(4)：
真實 ORDER_STATUS/STOCK_LEVEL 交易取代 `LIMIT 1` 單筆查詢、在高併發（t128）
執行期間持續採樣近讀證據，而非只測空閒連線的單筆查詢。環境已完全 destroy
（terraform state 兩邊皆空），先跑 `make phase1 phase2` 重建 6 台 VM。

**新增 driver**：[verify-a7-smoke.sh](scripts/verify-a7-smoke.sh)（smoke
規模 W=4，仿 win-aaro-w128.sh 結構）＋
[check-nearread-realtxn.sh](scripts/check-nearread-realtxn.sh)（A7-1）＋
[sample-nearread-loop.sh](scripts/sample-nearread-loop.sh)（A7-4，每 12s
採樣一次 check-nearread.sh）。

**過程踩到的坑**（環境重建/驅動本身的問題，與近讀機制無關）：
1. 第一次試跑漏寫 `phase2-bootstrap-gcp-client`（GCP client 沒有
   go-tpc/tests/common），GCP side rc=127 command not found——已補上
   （commit `8e9552c9`）。
2. 補上後重跑，TiDB deploy 卡在殘留的舊 placement policy（第一次失敗前
   沒跑到 teardown-tidb）——手動 `teardown-tidb` 清乾淨後重跑正常。
3. YBDB `gcp-replica-gate` 連兩次卡在 GCP 3 台 tserver 中 `.11` 恆 0
   tablet（W=4 資料量小、`enable_automatic_tablet_splitting=false`，LB
   分配非保證均勻）；使用者授權手動 `yb-admin change_config` 搬 tablet，
   但因清理舊 YBDB cluster 時已把整個 cluster 砍了，搬移對象不存在；
   第三次全新部署後 LB 自然分配到 3/3，未動用手動搬遷。

**重大發現：go-tpc 與 CRDB/YBDB 近讀機制結構性衝突**。CRDB 第一次在真實
go-tpc 負載下測試，GCP 側查詢 **100% 報錯**
`AS OF SYSTEM TIME specified with READ WRITE mode`。追查到：go-tpc
（`tpcc/workload.go`）的 `beginTx` 從未把 `sql.TxOptions.ReadOnly` 設
`true`，go-tpc 對 CRDB/YBDB 都用 `-d postgres`（`lib/pq` driver），
`lib/pq` 看到 `ReadOnly=false` 會明確送出 `BEGIN ... READ WRITE`，蓋過
session 層 `default_transaction_read_only=on`（SQL 標準：顯式設定優先於
預設值）。CRDB 因此 100% 報錯，YBDB 依官方文件會靜默 fallback 回
leader——不報錯，但近讀完全不生效，是本次調查最初就想抓的那種「靜默
失效」，只是換了個更深層的成因。

**修法**：clone `github.com/pingcap/go-tpc`（base commit
`a9ca4818625deef91ff80f6c395a575ccae22b7c`），patch 只讓 `ORDER_STATUS`/
`STOCK_LEVEL`（TPC-C 定義上本就純讀）明確傳 `ReadOnly: true`，其餘涉及
寫入的交易類型不受影響。跨編譯 `GOOS=linux GOARCH=amd64`，只部署到 GCP
client（10.160.152.15，A-A-RO 唯一發起純讀 mix 的一側），原始 binary
備份為 `go-tpc.orig`。TiDB 用 zone-based 物理路由，不受此問題影響，不需
套用。Patch 存入
[phase-crossregion/patches/go-tpc-readonly-fix.patch](patches/go-tpc-readonly-fix.patch)。

**修法後三家結果**（詳見 [nearread-verify-a7-20260722/](nearread-verify-a7-20260722/README.md)）：
- TiDB：A7(1) PASS；A7(4) 28 次採樣 25 PASS/3 FAIL，FAIL 全集中在採樣
  視窗最前面（sample 2-4），之後穩定 100% PASS。
- CRDB：套用修法後 aaro-smoke 查詢錯誤率從 100% 降到 ~0.1%（僅收尾正常
  timeout）；A7(1) PASS；A7(4) 22 PASS/6 FAIL，FAIL 同樣全集中在最前面
  （sample 2-7），之後穩定 100% PASS。
- YBDB：A7(1) 表面 3/12 FAIL，覆核後確認是 `check-nearread-realtxn.sh`
  本身沒做暖機查詢造成的假陽性（第一組樣本 on≈off，與 07-21 已知的「冷
  catalog cache」現象一致，其餘 3 組樣本全 PASS 且差距懸殊）——已修正
  腳本補暖機。A7(4) 14 PASS/1 FAIL（僅測到 15 個樣本；最後一次採樣間隔
  異常拉長，疑與 aaro-smoke 收尾資源競爭有關）。

**尚未排除**：YBDB 這輪的良好結果是在套用 go-tpc 修法「之後」才測的，未
套用修法時 YBDB 在真實負載下的表現從未單獨驗證過（機制與 CRDB 同構，
高度懷疑同樣會靜默失效，但未直接測過這個反事實）。

**方法論收穫**：A7(4) 的 t128 高併發真實負載測試不只是「重複驗證同一件
事」，直接抓到了一個 07-21 用手動 EXPLAIN 查詢完全測不出來的結構性 bug
——這正是當初設計 A7(4)（而非只信任單筆診斷查詢）的意義所在。FAIL 樣本
「集中在採樣視窗最前面、之後穩定 PASS」的時間分布模式，也證明了逐次記錄
時間戳而非只看總計 PASS/FAIL 數字的價值——同樣的「25/28」，究竟是「持續
低機率隨機失敗」還是「短暫暖機過渡後完全穩定」，只看聚合數字看不出來，
必須看逐筆時間序列。

環境已於本輪結束後 `phase9-destroy`（VM 已全部拆除，terraform state
兩邊皆空）。

修改檔案：`verify-a7-smoke.sh`（新增，2 次 bug 修正）、
`check-nearread-realtxn.sh`（新增，YBDB 暖機修正）、
`sample-nearread-loop.sh`（新增）、`run-vm6-aa.sh`（CRDB
GCP_CONN_PARAMS 補 `default_transaction_read_only=on`，但實測發現此修
法本身仍不夠，見上）、`patches/go-tpc-readonly-fix.patch`（新增）、
`patches/README.md`（新增）、`nearread-verify-a7-20260722/`（新增）、
報告 §5.5/§5.6/§5.7（新增）/§8（A7/A8/A9）/§9 更新。

**Last updated**：2026-07-22 A7(1)(4) 補強驗證完成，三家皆有結果；意外
發現並修正 go-tpc/lib/pq 與 CRDB/YBDB 近讀機制的結構性衝突（CRDB 修法前
100% 報錯，修法後才成立）；環境已 destroy。
**Next review**：codex §5.6 剩餘 (2)(3)(5) 三項（TiDB 嚴格 A/B、
staleness/freshness 驗證、統一 zone 前 placement/故障域評估）；YBDB
「反事實」（不套用 go-tpc patch 時真實負載下是否也 100% 失效）未驗證；
是否／何時重跑完整 W=128 A-A-RO 批次（**務必先確認 go-tpc patch 已套用**，
見報告 §8 A8）。

## 2026-07-22/23（續）— codex §5.6 (2)(3) 補強驗證：TiDB 嚴格 A/B、staleness、YBDB go-tpc 反事實

**背景**：使用者拍板順序「先補驗證再決定 aaro#2」（順序 2→3→1：YBDB
反事實 → codex 剩餘 (2)(3) → 才發 aaro#2），合併成一次 smoke 批次，
避免三次獨立 VM 重建循環。新增
[verify-a8-batch-smoke.sh](scripts/verify-a8-batch-smoke.sh) driver
＋ [check-staleness.sh](scripts/check-staleness.sh)（三家 staleness）＋
[relabel-tidb-gcp-zone.sh](scripts/relabel-tidb-gcp-zone.sh)／
[verify-tidb-zone-ab.sh](scripts/verify-tidb-zone-ab.sh)（TiDB A/B，用
`pd-ctl store label` 即時切換 zone，不需重新部署）。

**(3) staleness/freshness——三家皆決定性，與理論預期吻合**：TiDB 近讀
78ms（近乎即時，符合「zone-based 路由不引入過期」的預期）；CRDB 近讀
4,152ms（與 `follower_read_timestamp()` 預設 ~4.8s 量級吻合）；YBDB 近讀
28,283ms（與 `yb_follower_read_staleness_ms=30000` 量級吻合）。三家皆用
IDC 寫入 marker → GCP 輪詢直到可見的方法，同時測 leader-read 基準線排除
複寫延遲干擾。**A-A-RO 測試定義本身未明文規定可接受的過期讀取上限**，
YBDB ~28.3s 是否合理需使用者拍板（報告 §8 A10）。

**(2) TiDB 嚴格 A/B——未取得決定性結果**：unified／mismatched 兩種 zone
設定（後者故意讓 2/3 GCP store 與 tidb-server 不同 zone，模擬 07-20 批
問題但控制變因更乾淨）× closest-replicas／leader 兩種 session 設定，共
4 組 netflow 比值：129.5%／110.9%／113.9%／112.1%——全部擠在一起，看不出
方向性，甚至 leader-forced 組跟 closest-replicas 組幾乎沒差異。判定為
netflow 方法論在 W=4＋200 次查詢規模下被背景流量淹沒，**非近讀機制有
問題，是量測手法本身不夠力**（TiDB 缺乏 CRDB 那種 EXPLAIN 決定性欄位）。
環境已 teardown，未來若要補上決定性證據需要更大規模 burst 或新量測手法。

**YBDB go-tpc 反事實——延遲/吞吐量證據決定性，netflow 無效**：套用
§5.7 go-tpc patch 前後，用真實 aaro-smoke 流量對照：ORDER_STATUS 平均
延遲 60.7ms→27.1ms、STOCK_LEVEL 37.9ms→25.3ms，吞吐量從 ~18.6k 筆升到
~34k/~34.3k 筆（近乎翻倍），套用後出現 ~0.04% 極低錯誤率（同量級於 CRDB
已知 ~0.1%）。netflow ratio 本身幾乎沒變（105.9%→91.2%）——與 CRDB 早先
「EXPLAIN 決定性、netflow 卻測到 74-85%」同一套教訓。**確認 YBDB 拿掉
patch 確實會像 CRDB 一樣近讀實質失效，只是不報錯而是延遲/吞吐量劣化**，
補上 07-22 報告留下的「YBDB 反事實未直接驗證」缺口。

**過程插曲（環境/腳本層，與近讀機制無關）**：
1. YBDB 部署本輪 3 次嘗試中 2 次卡在已知的 `gcp-replica-gate` flaky
   （累計兩輪共 6 次嘗試、4 次卡住——flaky 率比原評估更高，見報告 §8
   A9 更新），第 3 次自然通過，未動用手動 tablet 搬遷。
2. `verify-a8-batch-smoke.sh` 的 `count_err()`（YBDB 反事實錯誤計數
   輔助函式）踩到 `pipefail`＋`set -e` 真 bug：0 錯誤時 go-tpc 根本不印
   `_ERR` 摘要行（非印 `Count: 0`），grep 找不到東西導致 pipeline 回傳
   非 0，誤觸發整個 driver 中止——這時「未套 patch」那輪真實負載其實
   已經跑完（IDC/GCP 兩側 rc=0），只是統計步驟自己中止。已修正（grep
   拿掉 `^` 錨點以吃到 go-tpc 輸出的 `[gcp] ` 前綴、函式尾端加
   `return 0` 避免 pipefail 誤判）；未套 patch 那輪的 netflow 暫存檔
   在 driver 中止前未被清除，手動撈回算出 ratio，未浪費那輪已完成的
   真實測試資料。
3. Mac↔.31 SSH 在 phase2-bootstrap 期間又出現 2 次 kex 階段連線重置
   （已知瞬斷模式，`retry-cmd.sh` 未覆蓋到的 `tests/common/
   bootstrap-client.sh` 內部呼叫——該檔案受保護，未經授權不動，改用
   立即重試吸收）；期間 Mac 端 VPN 介面（utun7）也掉線過一次，需人工
   重連，純本機網路問題，與遠端環境無關。

環境已於本輪結束後 `phase9-destroy`（VM 已全部拆除，terraform state
兩邊皆空）。

修改檔案：`check-staleness.sh`（新增）、`relabel-tidb-gcp-zone.sh`（新增）、
`verify-tidb-zone-ab.sh`（新增）、`verify-a8-batch-smoke.sh`（新增，含
`count_err()` pipefail 修正）、`nearread-verify-a8-20260723/`（新增，8
個原始輸出檔）、報告 §5.7（尚未排除的疑點段落更新）/§5.8（新增）/§8
（A7/A8/A9 更新＋新增 A10）/§9 更新。

**Last updated**：2026-07-23 codex §5.6 (2)(3) 補強驗證完成——staleness
三家決定性、YBDB 反事實決定性、TiDB 嚴格 A/B 因方法論限制未取得決定性
結果；環境已 destroy。
**Next review**：使用者拍板 A-A-RO 測試定義的過期讀取上限（YBDB ~28.3s
是否可接受，報告 §8 A10）；codex (5)（統一 zone 對 P-B 故障域衝擊）待
P-B 立項時處理，不擋 P-A；是否／何時發 aaro#2 全跑（前提仍是 §8 A8：
GCP client go-tpc 已套用 patch）。

## 2026-07-23（續）— aaro#2 前置：固化 A8＋排除 A9 風險，拍板 A10

**使用者拍板**：A10（YBDB staleness 上限）維持現況 ~30 秒不變，不調
`yb_follower_read_staleness_ms`。

**A8 已固化**（commit `759105dc`/`f48238c0`）：新增
[apply-gotpc-patch.sh](scripts/apply-gotpc-patch.sh)，冪等從原始碼
（clone 固定 base commit → git apply → go build）重建 patched go-tpc
並部署到 GCP client，不依賴預先 build 好、需要人工 rsync 的 binary 檔
（避免把 21MB binary 塞進 git）。已接進
[win-aaro-w128.sh](scripts/win-aaro-w128.sh) 的
`phase2-bootstrap-gcp-client` 之後，在 `.31` 上實測 build 全流程成功
（部署到 GCP client 那步當時因 VM 已 destroy 而預期失敗，屬正常情況，
尚未在真正的 W=128 全跑中端到端驗證過部署步驟本身）。Makefile 的
`win-aaro-detach`／`verify-a7-detach` 補上 `patches/` rsync 到 `.31`。

**A9 風險已排除**：原本評估 YBDB `gcp-replica-gate` 在 W=4 smoke 規模
flaky 率偏高（累計 6 次嘗試 4 次卡住），擔心會拖累 aaro#2。實測驗證：
重建 VM → 部署 YBDB → 直接跑 **W=128**（非 smoke W=4）的 `ANCHOR_ONLY`
prepare → gate **第一次嘗試即通過**（`gcp_tservers_with_sst=3`，無需
重試）。確認 flaky 是 W=4 smoke 資料量太小（多數表僅 1 tablet）造成的
特有現象，W=128 真實資料量下 tablet 自然分散到 3 台，非 aaro#2 的真實
風險。報告 §8 A9 已更新為「已排除」。

**過程插曲**：驗證途中 Mac 端需要重開機，當時 YBDB W=128 prepare 正在
跑到 warehouse 25/128（透過本機 `make` 前景呼叫、非 detached）。處理
方式：先確認並清掉本機 ssh 子行程（避免遠端行程收到 SIGHUP 而中斷在
不明確的中間狀態）、`teardown-ybdb` 清乾淨、寫一個一次性腳本
（teardown → 重新部署 → W=128 prepare）scp 到 `.31` 後用
`nohup ... &` + `disown` 完全脫離本機 session（`ps` 確認 PPID=1）才讓
Mac 重開機，避免半途而廢的資料污染後續判讀。

環境已 `phase9-destroy`（VM 已全部拆除，terraform state 兩邊皆空）。

修改檔案：報告 §8（A9 更新為已排除）、SESSION-HISTORY.md（本節）。

**Last updated**：2026-07-23 aaro#2 前置條件全數清空——A8 已固化、A9 已
排除、A10 已拍板（維持現況）。
**Next review**：可發 aaro#2（完整 W=128 A-A-RO 全跑，用
`win-aaro-detach`）；(5)（統一 zone 對 P-B 故障域衝擊）仍待 P-B 立項時
處理，不擋本輪。
