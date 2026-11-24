extends "res://levels/forest/forest_battle.gd"
## 第二小關「煙圈」：三個抽菸的人各彈菸蒂，菸蒂幾秒後點著附近的樹，火還會延燒。
## 新道具：水桶。準備階段先把抽菸的人旁邊淋濕（點不著），開打後留幾桶救火。
## 輸：砍倒加燒掉超過 6 棵樹，或家豪倒下。

const DecoyItem := preload("res://levels/forest/items/decoy_item.gd")
const GuideItem := preload("res://levels/forest/items/guide_item.gd")
const BucketItem := preload("res://levels/forest/items/bucket_item.gd")

func _want_trees() -> bool:
	return true

func _tree_cap() -> int:
	return 6

func _want_smoke() -> bool:
	return true

## 這裡的人菸癮大：每 4.5 秒一根
func _butt_every() -> float:
	return 4.5

func _make_items() -> Array:
	return [
		DecoyItem.new().uses_shared(2),
		GuideItem.new().uses_shared(5),
		BucketItem.new().uses(1, 2),      # 準備階段 1 桶先淋濕、開打後 2 桶救火
	]

func _enemy_specs() -> Array:
	return [
		{"name": "抽菸1", "hud_name": "抽菸1", "kind": "smoker", "route": [Vector3(-7.0, 0, 1.5)], "yaw": 0.4,
			"hp": 4.5, "speed": 1.35, "hears_noise": false, "vision_range": 6.0, "vision_deg": 55},
		{"name": "抽菸2", "hud_name": "抽菸2", "kind": "smoker", "route": [Vector3(7.5, 0, -2.0)], "yaw": 2.2,
			"hp": 4.5, "speed": 1.35, "hears_noise": false, "vision_range": 6.0, "vision_deg": 55},
		{"name": "抽菸3", "hud_name": "抽菸3", "kind": "smoker", "route": [Vector3(0.0, 0, -7.0)], "yaw": 1.2,
			"hp": 4.5, "speed": 1.35, "hears_noise": false, "vision_range": 6.0, "vision_deg": 55},
		{"name": "伐木1", "hud_name": "伐木1", "kind": "chopper", "route": [Vector3(-10.0, 0, -8.5)], "hp": 4.5,
			"speed": 1.4, "hears_noise": false, "vision_range": 6.0, "vision_deg": 55},
	]

func _objectives() -> Array:
	return [
		{"id": "all", "text": "打倒所有人"},
		{"id": "burnt_le_0", "text": "一棵樹都沒燒掉", "end": true},
		{"id": "hp_ge_6", "text": "家豪還剩 3 顆心以上", "end": true},
	]

func _tutorial_steps() -> Array:
	var smoke1 := func(): return tut_enemy("抽菸1").pos + Vector3(0, 1.0, 0)
	var smoke2 := func(): return tut_enemy("抽菸2").pos + Vector3(0, 1.0, 0)
	var hero_at := func(): return bird.pos + Vector3(0, 0.6, 0)
	return [
		{"pic": ["who:抽菸1", "plus", "who:抽菸2"], "say": "這裡的人在抽菸。每隔一陣子就彈一根菸蒂，\n幾秒後點著旁邊的樹，火還會往旁邊燒。",
			"spot": [smoke1, smoke2], "r": 1.8, "look": smoke1},
		{"pic": ["hero", "to", "no"], "say": "家豪走到菸蒂上就會踩熄。\n用引路點帶她過去，也可以順便打人。",
			"spot": [hero_at], "r": 1.3},
		{"pic": ["key:3", "to", "icon:bucket"], "say": "按 3 拿起水桶。",
			"spot": ["slot:2"], "wait": func(): return tut_selected("bucket"),
			"help_after": 8.0, "help_say": "按鍵盤上的 3，或用滑鼠滾輪換到水桶。"},
		{"pic": ["icon:bucket", "to", "who:抽菸1"], "say": "準備階段先潑一桶在抽菸的人旁邊：\n淋濕的樹一陣子點不著，菸蒂掉上去就熄了。",
			"spot": [smoke1], "r": 3.3, "look": smoke1,
			"wait": func(): return _tut_bucket_near("抽菸1"),
			"help_after": 12.0, "help_say": "準心對到抽菸的人旁邊的地面，再按左鍵。"},
		{"pic": ["icon:bucket", "to", "ok"], "say": "開打後水桶會補滿。\n樹著火了就潑水——水一到火就熄，樹也救得回來。",
			"spot": ["slot:2"], "r": 1.0},
		{"pic": ["key:Enter"], "say": "準備好了就按 Enter 開打！",
			"spot": ["start"], "wait": "start"},
	]

func _tut_bucket_near(who: String) -> bool:
	var f := tut_enemy(who)
	for q in puddles:
		if flat_dist(q.pos, f.pos) < 4.5:
			return true
	return false

func _prepare_hint() -> String:
	return "打倒所有人，別讓森林燒起來（超過 6 棵就輸）　Enter 開始　T 再看教學"
