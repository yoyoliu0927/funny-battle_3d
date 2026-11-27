extends "res://levels/forest/forest_battle.gd"
## 第三小關「狼外婆的木屋」：把家豪送進木屋、救出小紅帽。
## 前兩關學的全部用上：引路點帶路、假獵物引開伐木工、水桶救火；新的是狼外婆——
## 狼外婆守著小紅帽，家豪直接進門會被拍出來，要先把假獵物放在門口引開她。
## 天色會隨著小紅帽的計時慢慢變暗（傍晚→天黑）。
## 輸：小紅帽的計時走完、砍倒加燒掉超過 6 棵樹、或家豪倒下。

const DecoyItem := preload("res://levels/forest/items/decoy_item.gd")
const GuideItem := preload("res://levels/forest/items/guide_item.gd")
const BucketItem := preload("res://levels/forest/items/bucket_item.gd")

func _want_trees() -> bool:
	return true

func _tree_cap() -> int:
	return 7

func _want_smoke() -> bool:
	return true

func _want_hood() -> bool:
	return true

func _hood_cap() -> float:
	return 56.0

## 抽菸的人菸癮大：不淋濕的話，打他們的路上菸蒂就會點著樹（所以這關要用水桶）
func _butt_every() -> float:
	return 3.5

func _look_k() -> float:
	return clampf(dinner / _hood_cap(), 0.0, 1.0)

func _make_items() -> Array:
	return [
		DecoyItem.new().uses_shared(3),
		GuideItem.new().uses_shared(5),
		BucketItem.new().uses(1, 2),
	]

func _enemy_specs() -> Array:
	return [
		{"name": "伐木1", "hud_name": "伐木1", "kind": "chopper", "route": [Vector3(-10.5, 0, 3.0)], "hp": 4.5,
			"speed": 1.4, "hears_noise": false, "vision_range": 6.0, "vision_deg": 55},
		{"name": "伐木2", "hud_name": "伐木2", "kind": "chopper", "route": [Vector3(10.0, 0, -4.5)], "hp": 4.5,
			"speed": 1.4, "hears_noise": false, "vision_range": 6.0, "vision_deg": 55},
		{"name": "抽菸1", "hud_name": "抽菸1", "kind": "smoker", "route": [Vector3(8.0, 0, 1.5)], "yaw": 0.6, "hp": 4.5,
			"speed": 1.35, "hears_noise": false, "vision_range": 6.0, "vision_deg": 55},
		{"name": "狼外婆", "hud_name": "狼外婆", "kind": "wolf",
			"route": [Vector3(0.2, 0, -0.9)], "yaw": 0.0, "hp": 5.0, "speed": 1.15, "reach": 1.65,
			"hears_noise": false, "vision_range": 3.2, "vision_deg": 65, "bar_y": 2.9},
	]

## 新手教學：只講這一關新的東西——狼外婆。前兩關學過的不再重講。
func _tutorial_steps() -> Array:
	var door := ground(escape_point)
	var hero_at := func(): return bird.pos + Vector3(0, 0.6, 0)
	var wolf_at := func(): return tut_enemy("狼外婆").pos + Vector3(0, 1.0, 0)
	return [
		{"pic": ["at:0,1.2", "to", "ok"], "say": "目標：把家豪送進木屋，救出小紅帽。\n小紅帽撐不了多久，天黑之前要救出來。",
			"spot": [Vector3(0, 1.2, 0.5)], "r": 3.6, "look": Vector3(0, 0, 2.0)},
		{"pic": ["who:狼外婆", "to", "no"], "say": "狼外婆守著小紅帽。\n家豪直接進門會被拍出來！",
			"spot": [wolf_at], "r": 1.6, "look": wolf_at},
		{"pic": ["key:1", "to", "icon:decoy"], "say": "按 1 拿起假獵物。",
			"spot": ["slot:0"], "wait": func(): return tut_selected("decoy"),
			"help_after": 8.0, "help_say": "按鍵盤上的 1，或用滑鼠滾輪換到兔子。"},
		{"pic": ["icon:decoy", "to", "who:狼外婆"], "say": "把假獵物放在木屋門口。狼外婆去聞的時候，\n家豪才救得到人。",
			"spot": [door, wolf_at], "r": 1.5, "look": door,
			"wait": func(): return not baskets.is_empty(),
			"help_after": 12.0, "help_say": "假獵物要放在木屋裡面或門口。圈圈變紅就是放不了。"},
		{"pic": ["key:2", "to", "icon:guide"], "say": "按 2 拿起引路點，插在木屋門口。\n家豪不會自己進屋，要靠旗子帶他去。",
			"spot": [door], "r": 1.5, "look": door,
			"wait": _tut_guide_at_door,
			"help_after": 12.0, "help_say": "準心對到發亮的圈圈裡（木屋的門口），再按左鍵。"},
		{"pic": ["icon:bucket", "to", "who:抽菸1"], "say": "這關抽菸的人菸癮更大：開打前先用水桶\n淋濕他旁邊的樹，三種道具這關都用得到。",
			"spot": [func(): return tut_enemy("抽菸1").pos + Vector3(0, 1.0, 0)], "r": 2.4, "look": func(): return tut_enemy("抽菸1").pos + Vector3(0, 1.0, 0)},
		{"pic": ["hero", "to", "who:伐木2"], "say": "外面還有伐木的人和抽菸的人，\n用前兩關學的對付他們。",
			"spot": [hero_at], "r": 1.3},
		{"pic": ["key:Enter"], "say": "準備好了就按 Enter 開打！\n打輸了按 R 重來；按 T 再看一次教學。",
			"spot": ["start"], "wait": "start"},
	]

func _objectives() -> Array:
	return [
		{"id": "hood", "text": "救出小紅帽"},
		{"id": "burnt_le_0", "text": "一棵樹都沒燒掉（水桶）", "end": true},
		{"id": "chop", "text": "小紅帽得救前打倒伐木的人"},
	]

func _tut_guide_at_door() -> bool:
	for g in guides:
		if not g.used and flat_dist(g.pos, escape_point) < 2.6:
			return true
	return false

func _prepare_hint() -> String:
	return "小紅帽有倒數！砍倒加燒掉的樹超過 7 棵就輸"      # 目標（救出小紅帽）寫在左上角的目標卡，這裡只補提醒和輸的條件
