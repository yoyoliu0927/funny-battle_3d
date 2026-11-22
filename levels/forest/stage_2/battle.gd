extends "res://levels/forest/forest_battle.gd"
## 第二小關「煙圈」：三個抽菸的人圍著水塘。打倒所有抽菸的人就過關；燒掉的樹超過 5 棵就輸。
## 教菸蒂和起火：菸蒂放著會點著樹、火會延燒，家豪走過去就踩熄。
## 假獵物一樣能讓人背對家豪、一擊打倒，但抽菸的人走開時手上的菸會掉在地上——用之前要想好誰去踩。

const DecoyItem := preload("res://levels/forest/items/decoy_item.gd")
const GuideItem := preload("res://levels/forest/items/guide_item.gd")

func _want_trees() -> bool:
	return true

func _tree_cap() -> int:
	return 5

func _want_smoke() -> bool:
	return true

func _make_items() -> Array:
	return [
		DecoyItem.new().uses_shared(2),
		GuideItem.new().uses_shared(6),
	]

func _enemy_specs() -> Array:
	return [
		{"name": "抽菸1", "hud_name": "抽菸1", "kind": "smoker", "route": [Vector3(-6.5, 0, 2.5)], "yaw": 2.3,
			"hp": 4.0, "speed": 1.35, "hears_noise": false, "vision_range": 6.0, "vision_deg": 60},
		{"name": "抽菸2", "hud_name": "抽菸2", "kind": "smoker", "route": [Vector3(6.5, 0, 1.0)], "yaw": -2.0,
			"hp": 4.0, "speed": 1.35, "hears_noise": false, "vision_range": 6.0, "vision_deg": 60},
		{"name": "抽菸3", "hud_name": "抽菸3", "kind": "smoker", "route": [Vector3(0.5, 0, -7.5)], "yaw": 0.1,
			"hp": 4.0, "speed": 1.35, "hears_noise": false, "vision_range": 6.0, "vision_deg": 60},
	]

func _objectives() -> Array:
	return [
		{"id": "smoker", "text": "打倒所有抽菸的人"},
		{"id": "no_fire", "text": "一棵樹都沒燒掉"},
		{"id": "stomp3", "text": "踩熄 3 根菸蒂"},
	]

func _tutorial_steps() -> Array:
	var smoke_at := func(): return tut_enemy("抽菸1").pos + Vector3(0, 1.0, 0)
	return [
		{"pic": ["who:抽菸1", "to", "icon:flame"], "say": "抽菸的人每隔一陣子彈一根菸蒂。\n放著不管會點著旁邊的樹，火還會往旁邊燒。",
			"spot": [smoke_at], "r": 1.8, "look": smoke_at},
		{"pic": ["icon:guide", "to", "hero", "ok"], "say": "家豪走過菸蒂就會踩熄。\n用旗子帶她繞過去。",
			"spot": [smoke_at], "r": 2.6},
		{"pic": ["icon:decoy", "to", "who:抽菸1", "no"], "say": "假獵物一樣能讓人背對家豪、一擊打倒；\n可是抽菸的人走開時，手上的菸會掉在地上！",
			"spot": [smoke_at], "r": 2.2},
		{"pic": ["icon:stump", "plus", "icon:stump"], "say": "燒掉超過 5 棵就輸。打倒所有抽菸的人就過關。\n水塘和倒下的樹都能擋火。"},
		{"pic": ["key:Enter"], "say": "準備好了就按 Enter 開打！\n打輸了按 R 重來；按 T 再看一次教學。",
			"spot": ["start"], "wait": "start"},
	]

func _prepare_hint() -> String:
	return "燒掉的樹超過 5 棵就輸"      # 目標寫在左上角的目標卡，這裡只補輸的條件

func _win_title() -> String:
	return "菸都熄了！" if trees_burnt == 0 else "火撲滅了！"
