# 冰雪島的測試工具和給關卡設定用的介面

## 怎麼跑（都從專案根目錄；Godot 的位置用環境變數 `GODOT` 指定）

```bash
export GODOT=/Applications/Godot.app/Contents/MacOS/Godot
bash levels/ice/tests/check_baseline.sh          # 舊三關 12 筆回歸，事件紀錄要和 baseline/ 逐字相同（加 sweep 連第 11 關掃線一起比）
bash levels/ice/tests/check_mechanics.sh         # 薄冰、飼料、追人繞洞…每個機制的自動檢查（要看到 MECHANICS: ALL PASS）
bash levels/ice/tests/smoke.sh                   # 冒煙測試
bash levels/ice/tests/storyboards.sh <輸出資料夾>   # 拍分鏡（要開視窗）；新關卡："名稱|13|-1,0,x,z;-1,1,x,z"
```

單跑一局、掃線：

```bash
$GODOT --headless --path . --script res://levels/ice/tests/play.gd -- --stage=13 "--strategy=prep:0,1.5,-6;prep:1,5.7,-3.8"
#   prep:道具序號,x,z＝準備階段放（序號照 _make_items() 的順序）；會印出完整事件紀錄和 RESULT
$GODOT --headless --path . --script res://levels/ice/tests/sweep.gd -- 13 0 0.8,-11.3 2.8,-2.0 0.25 "1,5.7,-3.8"
#   <關卡> <道具序號> <起點 x,z> <終點 x,z> <間隔> ["固定先放的 道具,x,z;…"]：沿線每隔一段放一個，各跑一局
```

`save_baseline.sh` 會覆寫基準，只有確定要換基準時才跑。測試用的臨時關卡放在 `tests/stage_t*/`，不列進 chapter.gd。

## 給關卡設定（stage_N/battle.gd、world.gd）的介面

打「（未完成）」的還沒接上，名稱已經定了，可以先寫進關卡。

### world.gd
- 薄冰：`thin_spots = [{"center": Vector2(x, z), "r": 1.1}]`（現有欄位）。

### battle.gd：道具
```gdscript
const RescueFeed := preload("res://levels/ice/items/rescue_feed_item.gd")
func _make_items() -> Array:
	return [
		BananaItem.new().uses_shared(2).cooldown_sec(0.0),
		RescueFeed.new().uses(1, 0).cooldown_sec(0.0),     # 飼料：只有準備階段一包
	]
```

### battle.gd：人
- `rusher("阿土", 出生點, [紅線的點…])`、`guard("守衛", 位置)`（現有）。
- 造型照名字套：工人、阿土、阿水、阿火、阿木、守衛、守衛甲、守衛乙；其他名字照工人／守衛的預設造型。

### battle.gd：旗標（在 `_level_setup()` 裡 `super()` 之後設）
| 名稱 | 預設 | 作用 |
|---|---|---|
| `preview_full` | true | false＝預告只畫到第一個碰到的東西（第 2 關起都設 false） |
| `chase_avoids_holes` | false | true＝追人的攔截點不會直線穿過開著的洞（第 3–6 關開） |
| `show_timing` | false | 舊的總開關（stage_11 用）：等於下面時機輔助全開＋開場示範 |
| `aid_cross_mark` | false | 交叉點的地上標記 |
| `aid_ghost` | false | 瞄準「滑的人」的紅線時，畫穿越的人的剪影和滑行道 |
| `aid_last_try` | 0 | 重來後留幾個「上次的記號」（0＝不留；第 2 關設 1，其他設 3） |
| `aid_tab_seconds` | false | Tab 俯視時紅線上的秒數刻度 |
| `aid_demo` | false | 開場示範（只有 stage_11 用） |
| `aid_after_first_star` | false | true＝`aid_cross_mark`、`aid_ghost` 要拿過第一顆星（rescue）之後再進來才出現 |
| `timing_slider` | "" | 滑的人的名字（例如 "阿土"）；空白＝第一個工人 |
| `timing_crosser` | "" | 穿越的人的名字（例如 "阿水"）；空白＝第二個工人 |

「差一點！」的特寫和撞上的慢動作每一關都有，不用開。

### battle.gd：星星條件的 id（`_checklist()` 的 "id"）
現有：`rescue` 過關、`fall1` 有人進洞、`fall2` 兩人進洞、`carom` 連環撞、`guard_carom` 守衛被撞進洞、`guard_slip` 守衛撲上香蕉皮、
`one_banana` 只用一片香蕉皮過關、`two_banana` 只用兩片、`snow_hole` 戴雪人頭進洞、`pile` 有人倒栽雪堆、`clean_fall2` 沒人戴雪人頭、兩人進洞、`first_try`。

新的：
| id | 條件 |
|---|---|
| `guard_thin` | 有守衛踩破薄冰掉下去 |
| `pair_hole` | 過關時有一個洞泡著兩個人以上 |
| `thin_intact` | 過關時所有薄冰都沒破 |
| `no_feed` | 沒用飼料過關 |
| `all_sunk` | 開籠前所有人都泡在洞裡 |

### battle.gd：文字
- `_how_to()`：便利貼一行字；`[Tab]` 這種方括號會畫成鍵帽。
- `_defeat_tip()`：失敗卡的一行提示（預設）。
- `_defeat_tip_for(誰抓到的名字) -> String`：照抓到家豪的人給不同提示；回傳空字串就用 `_defeat_tip()`。
- `win_line`、`caught_line`（字串變數）：過關、被抓時家豪的台詞；空白就用預設的。
