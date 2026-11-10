# 給 AI 的規則（Claude Code、Codex、Cursor 等都會讀這個檔案）

這是一個四人小組的 Godot 4.7 遊戲專案。每個人做一個「大關」，每個大關至少 3 個「小關」，最後合併成一個遊戲。
完整說明在 `docs/開發守則.md`，動手前請先讀。

## 最重要的規則：只改自己的大關資料夾

1. 先問使用者（或看目前的 git 分支 `level/<名字>`）他負責哪個大關，例如 `levels/tainan/`。
2. **只能新增或修改 `levels/<自己的名字>/` 底下的檔案。** 其他地方都是四個人共用的 template：
   `scripts/`、`scenes/`、`shaders/`、`assets/`、`tools/`、`examples/`、`project.godot`、`docs/`、`AGENTS.md`、`CLAUDE.md`、`.github/`。
   這些檔案不能改、不能搬、不能刪、不能重新命名，也不能「順手修一下」。
3. 如果需求真的做不到、非改共用檔案不可，**停下來告訴使用者**要改什麼、為什麼，請他找 template 負責人，不要自己改。
4. 做完之後跑 `git status`，確認只有 `levels/<名字>/` 底下有變動。共用檔案如果被 Godot 編輯器自動改到，用 `git restore <檔案>` 還原。

## 怎麼做關卡（不用改共用檔案就能做到的事）

- 新的大關：`bash tools/new_chapter.sh <名字>`（會從 `levels/_template` 複製並改好路徑）。不要手動複製。
- 大關名稱、選關地圖上的城市、小關清單：`levels/<名字>/chapter.gd`。
- 每個小關一個資料夾 `stage_N/`，裡面三個檔案：
  - `stage.tscn`：繼承 `res://scenes/stage_base.tscn`，只換 World 和 Battle 兩個節點的腳本。
  - `world.gd`：場地。`extends "res://scripts/world/arena_world.gd"`，在 `_configure()` 設定範圍、擺設、圍欄、牆、水池；特殊地形覆寫 `_extra_height()`；自己蓋東西寫在 `_build_extra()`。
  - `battle.gd`：戰局。`extends "res://scripts/battle/battle_base.gd"`，覆寫 `_make_items()`（道具和次數）、`_enemy_specs()`（敵人）、其他「關卡可以覆寫」的函式（見 battle_base.gd 裡標示的那一區）。
- 道具：共用道具在 `scripts/items/`（飼料、香蕉皮、巨石），用 `.uses(準備次數, 開打次數)` 或 `.uses_shared(次數)` 設定，-1 是不限次數。
  新道具寫在 `levels/<名字>/items/`，`extends "res://scripts/items/item.gd"`，參考 `levels/_template/items/firecracker_item.gd`。
- 新敵人行為：在 `_enemy_specs()` 給 `"kind": "自己取的名字"`，然後覆寫 `_tick_enemy(f, dt)` 處理，其他交給 `super(f, dt)`。參考 `levels/_template/stage_3/battle.gd`。
- 機關：用 `_level_setup()`、`_level_reset()`、`_level_step()`、`_on_rock_rolling()`。完整範例在 `examples/farm/farm_battle.gd`（只能看，不能改）。
- 素材（模型、圖片、音效）：放 `levels/<名字>/assets/`，來源和授權寫進同一層的 `CREDITS.txt`。共用的 `assets/` 可以讀、不能改。

## 寫程式的規則

- 不要用 `class_name`（四個人的類別名稱會撞在一起）。要用別的腳本就 `const X := preload("res://...")`。
- 不要新增 autoload、不要改 Input Map、不要改 `project.godot` 的任何設定。需要的按鍵在自己的腳本裡用 `InputMap.add_action()` 加（先檢查 `has_action`）。
- 戰局邏輯要可重演：放在 `_level_step()` 這類每 1/60 秒的函式裡，不要用 `randf()` 這種每次不一樣的亂數（要亂數就用固定 seed 的 `RandomNumberGenerator`）。
- 註解和畫面上的文字用繁體中文。
- 路徑一律寫 `res://levels/<名字>/...` 的完整路徑。

## 改完要驗證

```bash
Godot --headless --path . -s res://tools/smoke_test.gd -- --chapter=<名字>
```

要看到 `SMOKE: ALL PASS`。想看畫面就拿掉 `--headless`，在最後加 `--shots=<資料夾>` 會每關截圖。
（Mac 上 Godot 執行檔通常是 `/Applications/Godot.app/Contents/MacOS/Godot`，以組員自己的安裝位置為準。）
