extends "res://scripts/world/arena_world.gd"
## 第一小關的場地。可以設定的東西見 scripts/world/arena_world.gd 最上面。

func _configure() -> void:
	play_min = Vector2(-12.0, -12.0)
	play_max = Vector2(12.0, 14.0)
	hero_start = Vector3(0.0, 0.0, 11.0)
	camera_start = Vector3(5.0, 7.0, 18.0)
	camera_look = Vector3(0.0, 0.0, 0.0)
	# 一道矮圍欄：家豪會拍翅飛過去，敵人要繞到兩端
	fences = [[Vector2(-7.0, 6.0), Vector2(7.0, 6.0)]]
	props = [
		{"model": "res://assets/farm/Hay.glb", "pos": Vector3(-6.0, 0, -3.0), "scale": 7.0, "block": 0.7},
		{"model": "res://assets/nature/BirchTree.glb", "pos": Vector3(8.0, 0, -7.0), "scale": 1.6, "block": 0.7},
		{"model": "res://assets/nature/BushBerries.glb", "pos": Vector3(-9.0, 0, 9.0), "scale": 1.3},
	]
