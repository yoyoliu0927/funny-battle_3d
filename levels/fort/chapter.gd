extends RefCounted
## 大關：人類要塞（yujuan）。原本是分支 level2-fort 的「第二關」，合併進 develop 時整包搬進這個資料夾。
## 這個大關用的是 template 之前的那一版戰局程式（fort_battle.gd，自己帶著），不是 scripts/battle/battle_base.gd；
## 三個小關共用同一張場地（fort_world.gd），差別在敵人、炮塔和東邊的院子。

const TITLE := "人類要塞"
const CITY := ""
const AUTHOR := "yujuan"
const ORDER := 20           # 地圖上的順序（小的排前面）
const ICON := "砦"
const DESC := "用大砲把家豪射進要塞：拿下炮塔、打倒指揮官。"
## 選關地圖：一座石頭城堡島（城牆、三座炮塔、指揮官的高塔），傍晚的暖色天光
const MAP_SCRIPT := "res://levels/fort/map_isles.gd"
const STAGES := [
	{"title": "學大砲", "desc": "把飼料撒在砲口前面，家豪會鑽進砲管；瞄準、發射！", "scene": "stage_1/stage.tscn"},
	{"title": "三座炮塔", "desc": "三座炮塔都要拿下：巨石撞倒，或讓家豪爬梯子上去佔領。", "scene": "stage_2/stage.tscn"},
	{"title": "指揮官的院子", "desc": "從要塞把家豪射到東邊院子的高台上，打倒指揮官。", "scene": "stage_3/stage.tscn"},
]
