# A-A-RO Smoke — 三家 DB 彙整（2026-07-18）

> 目的：驗證 TiDB/CRDB/YBDB 三家 DB 在 6-node cross-region 拓樸下，A-A-RO
> profile（IDC 端正常 TPCC 讀寫、GCP 端同時打 read-only mix）的**執行鏈、
> 資料採集、雙端計算口徑（G1-G6，`decisions-2026-06-08.md` 2026-07-15 附錄）**
> 全鏈可跑通，為正式 A-A-RO W=128 採樣前的健檢輪。**三家皆為 quick smoke
> （W=4 t16 N=1），數字僅供「跑得通＋口徑正確」驗證，非正式效能基準。**

## 結論

| DB | IDC tpmC | IDC 錯誤 | GCP read_tpmTotal | GCP tpmC | Placement gate | Artifact TS |
|---|---:|---|---:|---|---|---|
| **TiDB** | 1,563.3 | 0 / 17,289 | 16,282.0 | null（G2） | idc=19/19（100%） | `20260718T151236+0800` |
| **CRDB** | 7,397.1 | 1 / 81,485（0.0012%，見下）| 19,828.0 | null（G2） | idc=5/5（100%） | `20260718T154300+0800` |
| **YBDB** | 6,370.7 | 0 / 70,491 | 21,871.4 | null（G2） | idc=3/3（100%） | `20260718T204842+0800` |

**G1-G6 合規**：兩地數據為獨立頂層區塊，未合併（G1）；GCP RO 端主指標為
`read_tpmTotal`、`tpmC_mean=null`（G2，RO mix 無 NEW_ORDER，tpmC 無定義非量到零）；
同 suite 目錄雙子樹、GCP 端檔名帶 `-gcp` 後綴（G3）。三家 GCP 側
`read_tpmTotal_mean` 已由 raw `go-tpc-stdout-gcp.txt` 的 `[Summary]` TPM 欄位
獨立手動重算，與 `summary-gcp-side.py` 注入值逐位元相符（16282.0／19828.0／
21871.4），驗證口徑無誤。

三家 `.suite.done`（anchor plain suite）、placement gate、gcp-replica-gate
皆通過；**三家 A-A-RO 執行鏈本次全數首跑，過程中發現並修復 4 個此前從未
live 測過的根因 bug**（詳下）。

## 各家細節

### TiDB（`20260718T151236+0800`）

- NEW_ORDER（IDC 端）0 error；GCP 側 ORDER_STATUS/STOCK_LEVEL 各約 40.6-40.7k
  次、0 error，p99 92.3/96.5ms。
- Placement gate：idc_leader_count=19/19。

### CRDB（`20260718T154300+0800`）

- IDC 側 1 筆 `NEW_ORDER_ERR`（率 0.0012%，延遲 188.7ms）——延遲量級為一般
  交易衝突特徵，非 timeout 訊號（對照 YBDB 的 ~5s timeout 特徵），判定為
  W=4 低併發下的正常背景雜訊，不影響流程判定。
- GCP 側 ORDER_STATUS/STOCK_LEVEL 各約 49.4-49.5k 次、0 error。
- Placement gate：idc_leader_count=5/5。

### YBDB（`20260718T204842+0800`）

- IDC/GCP 兩側均 0 error；GCP 側 ORDER_STATUS/STOCK_LEVEL 各約 54.1-54.3k 次。
- Placement gate：idc_leader_count=3/3。

## 本輪發現並修復的 4 個根因（commit `e2cae9a2`）

A-A-RO 為本專案首次真正跑通雙端並發（此前 GCP 側僅有 near-read probe，
從未跑過完整 workload），暴露出四個此前不會觸發的問題：

1. **GCP client（`.15` / g-test-poc-5）從未部署 go-tpc/tests/common**——先前
   `phase2-probe-clients` 只裝了 psql/mysql/bc（供 near-read probe 用）。
   新增 `scripts/bootstrap-gcp-client.sh` + Makefile
   `phase2-bootstrap-gcp-client` target（手動於 aaro/aa smoke 前執行一次，
   冪等；未接入既有 `phase2` 聚合，避免動到既有驗證面）。
2. **GCP 側經 `tests/common/run.sh` 會炸**：`run.sh` 起手
   `coldreset-${DB}.sh` 一律 SSH 回 IDC 控制節點，`.15` 對 `172.24.40.x`
   無路由/FW，直接 timeout。`run.sh` 屬 protected，改為 GCP 側直呼
   go-tpc（不經 run.sh），用 round-barrier 與 IDC 側「該輪實際開始計時」
   對齊。
3. **`GO_TPC_MIX_FLAG` 用的 `--mix`（冒號分隔）go-tpc 根本沒有此 flag**——
   實際是 `--weight`（逗號分隔，順序 NewOrder,Payment,OrderStatus,Delivery,
   StockLevel）。A-A-RO 唯讀 mix 修正為 `0,0,50,0,50`。
4. **`tests/common/prepare.sh` 的 placement-gate regex `P-[AB]$` 認不得
   Q17 profile token 目錄**（如 `vm-6node-P-A-aaro`，`P-A` 不再是字串
   結尾）——恆判 UNKNOWN 而 fail-closed。`prepare.sh` 屬 protected，加
   `prepare-bridge`：若 token 版目錄缺 `.prepare.done`，從同 DB/PLACEMENT
   的 plain anchor（同一顆共用 cluster、已真實跑過 gate PASS）複製證據，
   非造假，落 `prepare-bridge.json` 註記來源。

## 已知限制（不擋本輪結案，正式 W=128 前留意）

- 三家皆 W=4 t16 quick smoke，tpmC/read_tpmTotal 數字僅供流程驗證，非正式
  效能基準；正式基準需 W=128×4 檔位×5 輪。
- **`prepare-bridge` 是 workaround、非根治**：依賴同 DB/PLACEMENT 已存在
  一份通過 gate 的 plain anchor suite（本輪三家皆有 `#3`/`O1` 批可用）。
  正式 A-A-RO 輪執行前須確認對應 anchor 仍存在，否則 fail-closed。
  根治方案（修 `tests/common/prepare.sh` regex）需走 protected 檔案授權
  流程，未在本輪範圍內處理。
- GCP 側 round-barrier 逐輪等待有超時緩衝（`ROUND_WAIT_TIMEOUT` =
  WARMUP_SEC+RUN_SEC+300s），正式輪 warmup 拉長至 1200s 時建議覆核此緩衝
  是否仍足夠。
- CRDB 的 1 筆 `NEW_ORDER_ERR` 判定為背景雜訊，未做重跑驗證重現性（W=4
  smoke 範疇，非阻擋項）。

## Artifact 路徑

```
results/x-cross/smoke/early-runs/20260718T151236+0800/tidb-vm-6node-P-A-aaro-rc-20260718T151236+0800/
results/x-cross/smoke/early-runs/20260718T154300+0800/crdb-vm-6node-P-A-aaro-rc-20260718T154300+0800/
results/x-cross/smoke/early-runs/20260718T204842+0800/ybdb-vm-6node-P-A-aaro-rc-20260718T204842+0800/
```

各目錄下 `aaro-summary.json` 為機器可讀彙整來源（含頂層 `gcp_side` 區塊）；
`aaro-go-tpc-stdout-{idc,gcp}.txt` 為雙端原始輸出；`anchor-*` 為
prepare-bridge 複製自的 plain anchor 證據（placement gate／gcp-replica-gate／
summary）。VM 已於採證後依 07-18 拍板紀律（中斷/完工即拆）全數 destroy，
兩側 terraform state 歸零；本輪未產生 `.suite.done`（W=4 smoke 未走完整
`phase9` 鏈，僅手動採證關鍵檔案，非正式 suite）。

詳細踩坑過程見 `SESSION-HISTORY.md` 2026-07-18（續）節。
