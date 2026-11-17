extends "res://levels/forest/forest_battle.gd"
## 林道：兩個伐木的人，砍倒超過 10 棵就輸。

const DecoyItem := preload("res://levels/forest/items/decoy_item.gd")
const FeedItem := preload("res://levels/forest/items/feed_item.gd")
const GuideItem := preload("res://levels/forest/items/guide_item.gd")

func _want_trees() -> bool:
	return true

func _tree_cap() -> int:
	return 10

func _make_items() -> Array:
	return [
		DecoyItem.new().uses_shared(2),
		FeedItem.new().uses_shared(2),
		GuideItem.new().uses_shared(4),
	]

func _enemy_specs() -> Array:
	return [
		{"name": "伐木1", "hud_name": "伐木1", "kind": "chopper", "route": [Vector3(-7.5, 0, 1.0)],
			"speed": 1.4, "hears_noise": false, "vision_range": 6.0, "vision_deg": 55},
		{"name": "伐木2", "hud_name": "伐木2", "kind": "chopper", "route": [Vector3(6.5, 0, -5.5)],
			"speed": 1.4, "hears_noise": false, "vision_range": 6.0, "vision_deg": 55},
	]

func _prepare_hint() -> String:
	return "別讓他們砍倒超過 10 棵　Enter 開始"
