extends "res://levels/forest/forest_battle.gd"
## 小紅帽：送進木屋就過關。樹超過 10 棵或抽菸超過 20 秒就輸，家豪血還在也一樣。

const DecoyItem := preload("res://levels/forest/items/decoy_item.gd")
const FeedItem := preload("res://levels/forest/items/feed_item.gd")
const GuideItem := preload("res://levels/forest/items/guide_item.gd")

func _want_trees() -> bool:
	return true

func _tree_cap() -> int:
	return 10

func _want_smoke() -> bool:
	return true

func _smoke_cap() -> float:
	return 20.0

func _want_hood() -> bool:
	return true

func _hood_cap() -> float:
	return 80.0

func _make_items() -> Array:
	return [
		DecoyItem.new().uses_shared(3),
		FeedItem.new().uses_shared(3),
		GuideItem.new().uses_shared(6),
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

func _prepare_hint() -> String:
	return "過關：把家豪送進木屋。樹超過 10 或抽菸超過 20 秒就輸　Enter 開始"
