extends "res://levels/forest/forest_battle.gd"
## 煙圈：三個人抽菸，菸蒂會點著樹、火會延燒。燒掉超過 6 棵就輸。

const DecoyItem := preload("res://levels/forest/items/decoy_item.gd")
const GuideItem := preload("res://levels/forest/items/guide_item.gd")

func _want_trees() -> bool:
	return true

func _tree_cap() -> int:
	return 6

func _want_smoke() -> bool:
	return true

func _make_items() -> Array:
	return [
		DecoyItem.new().uses_shared(2),
		GuideItem.new().uses_shared(4),
	]

func _enemy_specs() -> Array:
	return [
		{"name": "抽菸1", "hud_name": "抽菸1", "kind": "smoker", "route": [Vector3(-6.0, 0, 2.0)], "yaw": 0.4,
			"speed": 1.35, "hears_noise": false, "vision_range": 6.0, "vision_deg": 55},
		{"name": "抽菸2", "hud_name": "抽菸2", "kind": "smoker", "route": [Vector3(6.5, 0, -1.0)], "yaw": 2.2,
			"speed": 1.35, "hears_noise": false, "vision_range": 6.0, "vision_deg": 55},
		{"name": "抽菸3", "hud_name": "抽菸3", "kind": "smoker", "route": [Vector3(0.0, 0, -6.5)], "yaw": 1.2,
			"speed": 1.35, "hears_noise": false, "vision_range": 6.0, "vision_deg": 55},
	]

func _prepare_hint() -> String:
	return "菸蒂會點著樹，讓家豪去踩熄。燒掉超過 6 棵就輸　Enter 開始"
