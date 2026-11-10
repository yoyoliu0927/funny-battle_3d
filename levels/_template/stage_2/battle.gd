extends "res://scripts/battle/battle_base.gd"
## 第二小關：示範「自己做的道具」（levels/_template/items/firecracker_item.gd）。

const FeedItem := preload("res://scripts/items/feed_item.gd")
const BananaItem := preload("res://scripts/items/banana_item.gd")
const FirecrackerItem := preload("res://levels/_template/items/firecracker_item.gd")

func _make_items() -> Array:
	return [
		FeedItem.new().uses(1, 4),
		BananaItem.new().uses(1, 1),
		FirecrackerItem.new().uses(0, 2),   # 只能開打後用
	]

func _enemy_specs() -> Array:
	return [
		{"name": "農夫1", "route": [Vector3(0, 0, 3), Vector3(4, 0, 0)], "loop": false, "pause": 1.2},
		{"name": "農夫2", "route": [Vector3(-1, 0, -6), Vector3(-9, 0, -7)], "loop": false, "pause": 1.4},
		{"name": "農夫3", "route": [Vector3(5, 0, -3), Vector3(9, 0, 3), Vector3(3, 0, 6)], "loop": true, "pause": 0.8},
	]
