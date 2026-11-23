extends "res://levels/forest/forest_battle.gd"
## 第一小關「林道」：兩個伐木工，打倒他們就過關；倒下的樹超過 6 棵就輸。
## 教引路點和假獵物：伐木工很壯（要啄三下、還會踢人），但看假獵物看到出神的人，從背後一啄就倒。

const DecoyItem := preload("res://levels/forest/items/decoy_item.gd")
const GuideItem := preload("res://levels/forest/items/guide_item.gd")

func _want_trees() -> bool:
	return true

func _tree_cap() -> int:
	return 6

func _make_items() -> Array:
	return [
		DecoyItem.new().uses_shared(3),
		GuideItem.new().uses_shared(5),
	]

func _enemy_specs() -> Array:
	return [
		{"name": "伐木1", "hud_name": "伐木1", "kind": "chopper", "route": [Vector3(-6.5, 0, -2.0)], "yaw": 0.4,
			"hp": 6.0, "speed": 1.4, "hears_noise": false, "vision_range": 6.0, "vision_deg": 60},
		{"name": "伐木2", "hud_name": "伐木2", "kind": "chopper", "route": [Vector3(6.5, 0, -5.5)], "yaw": -0.6,
			"hp": 6.0, "speed": 1.4, "hears_noise": false, "vision_range": 6.0, "vision_deg": 60},
	]

func _objectives() -> Array:
	return [
		{"id": "chop", "text": "打倒兩個伐木工"},
		{"id": "trees_ok", "text": "倒下的樹不超過 2 棵"},
		{"id": "lure_ko", "text": "趁人看假獵物，一擊打倒他"},
	]

func _tree_star_cap() -> int:
	return 2

func _tutorial_steps() -> Array:
	var hero_at := func(): return bird.pos + Vector3(0, 0.6, 0)
	var chop_at := func(): return tut_enemy("伐木1").pos + Vector3(0, 1.0, 0)
	return [
		{"pic": ["hero"], "say": "這是家豪。她會自己衝去打離她最近的人。\n你是駁大莖森之神，用道具在旁邊幫她。",
			"spot": [hero_at], "r": 1.3},
		{"pic": ["who:伐木1", "to", "icon:log"], "say": "伐木工在砍樹。打倒兩個伐木工就過關，\n倒下的樹超過 6 棵就輸。",
			"spot": [chop_at], "r": 1.6, "look": chop_at},
		{"pic": ["who:伐木1", "plus", "hero"], "say": "伐木工很壯：家豪要啄三下，還會被踢。\n正面硬打很吃虧。",
			"spot": [chop_at], "r": 1.6},
		{"pic": ["key:1", "to", "icon:decoy"], "say": "按 1 拿起假獵物。",
			"spot": ["slot:0"], "wait": func(): return tut_selected("decoy"),
			"help_after": 8.0, "help_say": "按鍵盤上的 1，或用滑鼠滾輪換到兔子。"},
		{"pic": ["icon:decoy", "to", "who:伐木1"], "say": "放在伐木工旁邊。\n他會跑去看假兔子，不砍樹，還會背對家豪。",
			"spot": [chop_at], "r": 2.6, "look": chop_at,
			"wait": _tut_decoy_on_chopper,
			"help_after": 12.0, "help_say": "讓地上的大圈罩住伐木工，再按左鍵。"},
		{"pic": ["hero", "to", "who:伐木1", "ok"], "say": "看假獵物看到出神的人，家豪從背後一啄就倒！",
			"spot": [chop_at], "r": 2.0},
		{"pic": ["key:2", "to", "icon:guide"], "say": "按 2 拿起引路點。",
			"spot": ["slot:1"], "wait": func(): return tut_selected("guide"),
			"help_after": 8.0, "help_say": "按鍵盤上的 2，或用滑鼠滾輪換到黃色小旗子。"},
		{"pic": ["icon:guide", "plus", "lmb"], "say": "在地上插旗子，家豪會照順序走過去。\n帶她繞到伐木工的背後。",
			"spot": [chop_at], "r": 3.2,
			"wait": _tut_any_guide,
			"help_after": 12.0, "help_say": "滑鼠移到地上，按左鍵插一支旗子。"},
		{"pic": ["icon:tree", "to", "no"], "say": "站著的樹會擋住視線，躲在樹後面比較不會被發現。\n砍倒的樹會橫躺在地上擋路。"},
		{"pic": ["key:Enter"], "say": "準備好了就按 Enter 開打！\n打輸了按 R 重來；按 T 再看一次教學。",
			"spot": ["start"], "wait": "start"},
	]

func _prepare_hint() -> String:
	return "打倒兩個伐木工。倒下的樹超過 6 棵就輸　Enter 開始"

func _win_title() -> String:
	return "林道保住了！" if trees_lost() > 0 else "一棵樹都沒少！"
