extends "res://levels/forest/forest_world.gd"
## 第二小關：沒有木屋，只有一條林道和兩個伐木的人。

func _layout_level() -> void:
	world_seed = 481522
	play_min = Vector2(-13.0, -12.0)
	play_max = Vector2(13.0, 12.0)
	hero_start = Vector3(0.0, 0.0, 9.2)
	hero_yaw = PI
	camera_start = Vector3(1.6, 7.6, 15.4)
	camera_look = Vector3(0.0, 0.8, -1.0)

func _dress() -> void:
	var avoid := [
		{"p": Vector3(0, 0, 9.2), "r": 2.3},
		{"p": Vector3(-7.5, 0, 1.0), "r": 2.0},
		{"p": Vector3(6.5, 0, -5.5), "r": 2.0},
	]
	scatter_trees(16, 5.1, avoid, {})
	undergrowth(16)
	mushrooms(6)
