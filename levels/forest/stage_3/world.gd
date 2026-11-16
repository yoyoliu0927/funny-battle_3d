extends "res://levels/forest/forest_world.gd"
## 第三小關：三個人抽菸。樹只是林子，沒有人砍。

func _layout_level() -> void:
	world_seed = 481530
	play_min = Vector2(-13.0, -12.0)
	play_max = Vector2(13.0, 12.0)
	hero_start = Vector3(0.0, 0.0, 9.0)
	hero_yaw = PI
	camera_start = Vector3(1.2, 7.8, 15.6)
	camera_look = Vector3(0.0, 0.6, -1.0)

func _dress() -> void:
	var avoid := [
		{"p": Vector3(0, 0, 9.0), "r": 2.3},
		{"p": Vector3(-6.0, 0, 2.0), "r": 2.4},
		{"p": Vector3(6.5, 0, -1.0), "r": 2.4},
		{"p": Vector3(0.0, 0, -6.5), "r": 2.4},
	]
	scatter_trees(18, 5.0, avoid, {})
	undergrowth(18)
	mushrooms(8)
