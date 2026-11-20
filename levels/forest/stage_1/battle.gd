extends "res://levels/forest/forest_battle.gd"
## 小紅帽：送進木屋就過關。砍倒加燒掉的樹超過 10 棵就輸，家豪血還在也一樣。

const DecoyItem := preload("res://levels/forest/items/decoy_item.gd")
const GuideItem := preload("res://levels/forest/items/guide_item.gd")
const BasketItem := preload("res://levels/forest/items/basket_item.gd")

func _want_trees() -> bool:
	return true

func _tree_cap() -> int:
	return 10

func _want_smoke() -> bool:
	return true

func _want_hood() -> bool:
	return true

func _hood_cap() -> float:
	return 80.0

func _make_items() -> Array:
	return [
		DecoyItem.new().uses_shared(3),
		GuideItem.new().uses_shared(6),
		BasketItem.new().uses_shared(2),
	]

func _enemy_specs() -> Array:
	return [
		{"name": "伐木1", "hud_name": "伐木1", "kind": "chopper", "route": [Vector3(-10.5, 0, 3.0)],
			"speed": 1.4, "hears_noise": false, "vision_range": 6.0, "vision_deg": 55},
		{"name": "伐木2", "hud_name": "伐木2", "kind": "chopper", "route": [Vector3(10.0, 0, -4.5)],
			"speed": 1.4, "hears_noise": false, "vision_range": 6.0, "vision_deg": 55},
		{"name": "抽菸1", "hud_name": "抽菸1", "kind": "smoker", "route": [Vector3(-6.5, 0, 7.5)], "yaw": 0.6,
			"speed": 1.35, "hears_noise": false, "vision_range": 6.0, "vision_deg": 55},
		{"name": "狼外婆", "hud_name": "狼外婆", "kind": "wolf",
			"route": [Vector3(0.2, 0, -0.9)], "yaw": 0.0, "hp": 5.0, "speed": 1.15, "reach": 1.65,
			"hears_noise": false, "vision_range": 3.2, "vision_deg": 65, "bar_y": 2.9},
	]

## 新手教學：每個道具怎麼用，一邊講一邊真的放下去（放的東西就是開打時的佈置）
func _tutorial_steps() -> Array:
	var door := ground(escape_point)
	var hero_at := func(): return bird.pos + Vector3(0, 0.6, 0)
	var chop_at := func(): return tut_enemy("伐木1").pos + Vector3(0, 1.0, 0)
	var smoke_at := func(): return tut_enemy("抽菸1").pos + Vector3(0, 1.0, 0)
	var wolf_at := func(): return tut_enemy("狼外婆").pos + Vector3(0, 1.0, 0)
	return [
		{"pic": ["hero"], "say": "這是家豪。她會自己衝去打離她最近的人。\n你是森林之神，用道具在旁邊幫她。",
			"spot": [hero_at], "r": 1.3},
		{"pic": ["at:0,1.2", "to", "ok"], "say": "目標：把家豪送進木屋，救出小紅帽。\n小紅帽撐不了多久；樹被砍光、燒光也會輸。",
			"spot": [Vector3(0, 1.2, 0.5)], "r": 3.6, "look": Vector3(0, 0, 2.0)},
		# 引路點
		{"pic": ["key:2", "to", "icon:guide"], "say": "按 2 拿起引路點。",
			"spot": ["slot:1"], "wait": func(): return tut_selected("guide"),
			"help_after": 8.0, "help_say": "按鍵盤上的 2，或用滑鼠滾輪換到黃色小旗子。"},
		{"pic": ["icon:guide", "plus", "lmb"], "say": "把圈圈移到木屋門口，按左鍵插一支旗子。\n家豪不會自己進屋，要靠旗子帶她去。",
			"spot": [door], "r": 1.5, "look": door,
			"wait": _tut_guide_at_door,
			"help_after": 12.0, "help_say": "滑鼠移到發亮的圈圈裡（木屋的門口），再按左鍵。"},
		{"pic": ["icon:guide", "plus", "icon:guide"], "say": "旗子可以插好幾支，家豪會照你插的順序一支一支走過去。\n旗子上的數字就是順序。",
			"spot": [door], "r": 1.5},
		# 假獵物
		{"pic": ["who:伐木1"], "say": "伐木工會一直砍樹。\n砍倒的樹會橫躺在地上，擋住路。",
			"spot": [chop_at], "r": 1.6, "look": chop_at},
		{"pic": ["key:1", "to", "icon:decoy"], "say": "按 1 拿起假獵物。",
			"spot": ["slot:0"], "wait": func(): return tut_selected("decoy"),
			"help_after": 8.0, "help_say": "按鍵盤上的 1，或用滑鼠滾輪換到兔子。"},
		{"pic": ["icon:decoy", "to", "who:伐木1"], "say": "放在伐木工旁邊。\n他會跑去看假兔子，這段時間不砍樹。",
			"spot": [chop_at], "r": 2.6, "look": chop_at,
			"wait": _tut_decoy_on_chopper,
			"help_after": 12.0, "help_say": "讓地上的大圈罩住伐木工，再按左鍵。"},
		# 抽菸、起火
		{"pic": ["who:抽菸1", "to", "no"], "say": "抽菸的人會亂丟菸蒂，放著不管會點著樹，\n火還會往旁邊燒。\n插旗子帶家豪走過去，就能踩熄。",
			"spot": [smoke_at], "r": 1.8, "look": smoke_at},
		{"pic": ["icon:decoy", "to", "who:抽菸1"], "say": "小心：抽菸的人跑去看假獵物的時候，\n手上的菸也會掉在地上。",
			"spot": [smoke_at], "r": 1.8},
		# 外婆的籃子
		{"pic": ["key:3", "to", "icon:basket"], "say": "按 3 拿起外婆的籃子。",
			"spot": ["slot:2"], "wait": func(): return tut_selected("basket"),
			"help_after": 8.0, "help_say": "按鍵盤上的 3，或用滑鼠滾輪換到籃子。"},
		{"pic": ["icon:basket", "to", "who:狼外婆"], "say": "狼外婆守著小紅帽，家豪直接進門會被拍出來！\n把籃子放在門口，狼外婆去聞的時候，家豪才救得到人。",
			"spot": [door, wolf_at], "r": 1.5, "look": door,
			"wait": func(): return not baskets.is_empty(),
			"help_after": 12.0, "help_say": "籃子只能放在木屋裡面或門口。圈圈變紅就是放不了。"},
		# 偷襲
		{"pic": ["hero", "to", "who:伐木2"], "say": "站著的樹會擋住視線。\n讓家豪從樹後面摸過去，就能偷襲！"},
		{"pic": ["key:Enter"], "say": "準備好了就按 Enter 開打！\n打輸了按 R 重來；按 T 再看一次教學。",
			"spot": ["start"], "wait": "start"},
	]

func _tut_guide_at_door() -> bool:
	for g in guides:
		if not g.used and flat_dist(g.pos, escape_point) < 2.6:
			return true
	return false

func _tut_decoy_on_chopper() -> bool:
	for d in decoys:
		for f in enemies:
			if f.kind == "chopper" and flat_dist(d.pos, f.pos) < ATTRACT:
				return true
	return false

func _prepare_hint() -> String:
	return "過關：把家豪送進木屋。砍倒加燒掉的樹超過 10 棵就輸　Enter 開始"
