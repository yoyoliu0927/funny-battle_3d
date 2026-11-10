extends "res://scripts/battle/battle_base.gd"
## 第一小關的戰局。可以覆寫的函式見 scripts/battle/battle_base.gd 的「關卡可以覆寫」那一區。

const FeedItem := preload("res://scripts/items/feed_item.gd")
const BananaItem := preload("res://scripts/items/banana_item.gd")

func _make_items() -> Array:
	return [
		FeedItem.new().uses(2, -1),        # 準備階段 2 把、開打後不限
		BananaItem.new().uses_shared(2),   # 整場共用 2 片
	]

func _enemy_specs() -> Array:
	return [
		{"name": "農夫1", "route": [Vector3(-4, 0, 1), Vector3(4, 0, 1)], "loop": false, "pause": 1.5},
		{"name": "農夫2", "route": [Vector3(3, 0, -6), Vector3(-3, 0, -8), Vector3(0, 0, -3)], "loop": true, "pause": 1.0},
	]

func _win_line() -> String:
	return "第一小關過了！"
