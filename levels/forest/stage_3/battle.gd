extends "res://levels/forest/forest_battle.gd"
## 第三小關「小紅帽」：送進木屋就過關。砍倒加燒掉的樹超過 10 棵就輸，家豪血還在也一樣。
## 前兩關學過引路點、假獵物、菸蒂；這一關新的是狼外婆守著小紅帽、外婆的籃子。

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

## 新手教學：只講這一關新的東西（引路點、假獵物、菸蒂前兩關教過了）
func _tutorial_steps() -> Array:
	var door := ground(escape_point)
	var wolf_at := func(): return tut_enemy("狼外婆").pos + Vector3(0, 1.0, 0)
	return [
		{"pic": ["at:0,1.2", "to", "ok"], "say": "目標：把家豪送進木屋，救出小紅帽。\n小紅帽撐不了多久；樹被砍光、燒光也會輸。",
			"spot": [Vector3(0, 1.2, 0.5)], "r": 3.6, "look": Vector3(0, 0, 2.0)},
		{"pic": ["who:狼外婆", "to", "no"], "say": "狼外婆守著小紅帽。\n家豪直接進門，會被她一掌拍出來！",
			"spot": [wolf_at], "r": 1.6},
		{"pic": ["key:3", "to", "icon:basket"], "say": "按 3 拿起外婆的籃子。",
			"spot": ["slot:2"], "wait": func(): return tut_selected("basket"),
			"help_after": 8.0, "help_say": "按鍵盤上的 3，或用滑鼠滾輪換到籃子。"},
		{"pic": ["icon:basket", "to", "who:狼外婆"], "say": "放在木屋門口。狼外婆會走過去聞，\n聞的時候家豪才救得到人，小紅帽的時間也會停。",
			"spot": [door, wolf_at], "r": 1.5, "look": door,
			"wait": func(): return not baskets.is_empty(),
			"help_after": 12.0, "help_say": "籃子只能放在木屋裡面或門口。圈圈變紅就是放不了。"},
		{"pic": ["key:2", "to", "icon:guide"], "say": "家豪不會自己進屋。按 2 拿起引路點。",
			"spot": ["slot:1"], "wait": func(): return tut_selected("guide"),
			"help_after": 8.0, "help_say": "按鍵盤上的 2，或用滑鼠滾輪換到黃色小旗子。"},
		{"pic": ["icon:guide", "plus", "lmb"], "say": "在木屋門口插一支旗子，帶她進去。\n要算好時間：籃子的味道只撐一下子。",
			"spot": [door], "r": 1.5, "look": door,
			"wait": _tut_guide_at_door,
			"help_after": 12.0, "help_say": "滑鼠移到發亮的圈圈裡（木屋的門口），再按左鍵。"},
		{"pic": ["key:Enter"], "say": "準備好了就按 Enter 開打！\n打輸了按 R 重來；按 T 再看一次教學。",
			"spot": ["start"], "wait": "start"},
	]

func _prepare_hint() -> String:
	return "砍倒加燒掉的樹超過 10 棵就輸"      # 目標（救出小紅帽）寫在左上角的目標卡，這裡只補輸的條件
