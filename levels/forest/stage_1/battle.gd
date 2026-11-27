extends "res://levels/forest/forest_battle.gd"
## 第一小關「伐木場」：兩個伐木工一直砍樹，一個工頭在北邊巡邏。
## 學三件事：用引路點帶家豪去打人、用假獵物把伐木工引開、從樹後面摸過去偷襲。
## 輸：砍倒超過 5 棵樹，或家豪倒下。

const DecoyItem := preload("res://levels/forest/items/decoy_item.gd")
const GuideItem := preload("res://levels/forest/items/guide_item.gd")

func _want_trees() -> bool:
	return true

func _tree_cap() -> int:
	return 5

func _make_items() -> Array:
	return [
		DecoyItem.new().uses_shared(2),
		GuideItem.new().uses_shared(5),
	]

func _enemy_specs() -> Array:
	return [
		{"name": "伐木1", "hud_name": "伐木1", "kind": "chopper", "route": [Vector3(-9.0, 0, 3.0)], "hp": 4.5,
			"speed": 1.4, "hears_noise": false, "vision_range": 6.0, "vision_deg": 55},
		{"name": "伐木2", "hud_name": "伐木2", "kind": "chopper", "route": [Vector3(9.5, 0, -2.5)], "hp": 4.5,
			"speed": 1.4, "hears_noise": false, "vision_range": 6.0, "vision_deg": 55},
		{"name": "工頭2", "hud_name": "工頭2", "route": [Vector3(7.0, 0, 5.0), Vector3(7.0, 0, 9.0)], "loop": true, "pause": 2.0, "hp": 4.5,
			"speed": 1.25, "hears_noise": false, "vision_range": 6.5, "vision_deg": 60},
		{"name": "工頭", "hud_name": "工頭", "route": [Vector3(-4.0, 0, -8.0), Vector3(4.0, 0, -8.0)], "loop": true, "pause": 2.0, "hp": 4.5,
			"speed": 1.25, "hears_noise": false, "vision_range": 6.5, "vision_deg": 60},
	]

func _objectives() -> Array:
	return [
		{"id": "all", "text": "打倒四個人"},
		{"id": "lost_le_1", "text": "砍倒的樹不超過 1 棵", "end": true},
		{"id": "sneak", "text": "從背後偷襲成功一次"},
	]

func _tutorial_steps() -> Array:
	var hero_at := func(): return bird.pos + Vector3(0, 0.6, 0)
	var chop1 := func(): return tut_enemy("伐木1").pos + Vector3(0, 1.0, 0)
	var chop2 := func(): return tut_enemy("伐木2").pos + Vector3(0, 1.0, 0)
	var boss := func(): return tut_enemy("工頭").pos + Vector3(0, 1.0, 0)
	return [
		{"pic": ["hero"], "say": "這是家豪。他會自己衝去打離他最近的人。\n你是駁大莖森之神，用道具在旁邊幫他。",
			"spot": [hero_at], "r": 1.3},
		{"pic": ["who:伐木1", "plus", "who:伐木2"], "say": "伐木工一直砍樹，砍倒的樹會橫躺在地上擋路。\n砍倒超過 5 棵就輸了。",
			"spot": [chop1, chop2], "r": 1.7, "look": chop1},
		{"pic": ["key:2", "to", "icon:guide"], "say": "按 2 拿起引路點。",
			"spot": ["slot:1"], "wait": func(): return tut_selected("guide"),
			"help_after": 8.0, "help_say": "按鍵盤上的 2，或用滑鼠滾輪換到黃色小旗子。"},
		{"pic": ["icon:guide", "plus", "lmb"], "say": "準心對著伐木工旁邊的地上，按左鍵插一支旗子。\n家豪會走過去，遇到人就打。",
			"spot": [chop1], "r": 3.2, "look": chop1,
			"wait": func(): return _tut_guide_near("伐木1"),
			"help_after": 12.0, "help_say": "轉動滑鼠，讓畫面中間的圓圈對到伐木工旁邊的地面，再按左鍵。"},
		{"pic": ["icon:guide", "plus", "icon:guide"], "say": "旗子可以插好幾支，家豪照順序一支一支走。\n旗子上的數字就是順序。"},
		{"pic": ["key:1", "to", "icon:decoy"], "say": "按 1 拿起假獵物。",
			"spot": ["slot:0"], "wait": func(): return tut_selected("decoy"),
			"help_after": 8.0, "help_say": "按鍵盤上的 1，或用滑鼠滾輪換到兔子。"},
		{"pic": ["icon:decoy", "to", "who:伐木2"], "say": "把假獵物放在另一個伐木工旁邊。\n他會跑去看兔子，這段時間不砍樹。",
			"spot": [chop2], "r": 2.8, "look": chop2,
			"wait": func(): return _tut_decoy_near("伐木2"),
			"help_after": 12.0, "help_say": "讓大圈罩住伐木工，再按左鍵。"},
		{"pic": ["who:工頭", "to", "no"], "say": "工頭會巡邏。他看到家豪就會追過來打。\n站著的樹會擋住視線——",
			"spot": [boss], "r": 1.8, "look": boss},
		{"pic": ["hero", "to", "who:工頭"], "say": "讓家豪從樹後面、從背後摸過去，就能偷襲！"},
		{"pic": ["key:Enter"], "say": "準備好了就按 Enter 開打！\n打輸了按 R 重來；按 T 再看一次教學。",
			"spot": ["start"], "wait": "start"},
	]

func _tut_guide_near(who: String) -> bool:
	var f := tut_enemy(who)
	for g in guides:
		if not g.used and flat_dist(g.pos, f.pos) < 3.6:
			return true
	return false

func _tut_decoy_near(who: String) -> bool:
	var f := tut_enemy(who)
	for d in decoys:
		if flat_dist(d.pos, f.pos) < 4.0:
			return true
	return false

func _prepare_hint() -> String:
	return "倒下的樹超過 5 棵就輸"
