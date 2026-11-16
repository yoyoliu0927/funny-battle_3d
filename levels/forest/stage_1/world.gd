extends "res://levels/forest/forest_world.gd"
## 第一小關：木屋在中間，南邊是家豪進來的路。樹要種滿，但路和屋子周圍留空。

func _layout_level() -> void:
	world_seed = 481516
	play_min = Vector2(-16.0, -14.0)
	play_max = Vector2(16.0, 14.0)
	hero_start = Vector3(0.0, 0.0, 11.2)
	hero_yaw = PI
	camera_start = Vector3(2.4, 8.6, 17.8)
	camera_look = Vector3(0.0, 1.3, -0.4)
	has_house = true
	house_center = Vector2.ZERO
	walls = house_walls()
	escape_point = Vector3(0.0, 0.0, house_half_z + 1.9)

func _dress() -> void:
	var avoid := [
		{"p": Vector3(0, 0, 11.2), "r": 2.4},
		{"p": Vector3(-10.5, 0, 3.0), "r": 2.0},
		{"p": Vector3(10.0, 0, -4.5), "r": 2.0},
		{"p": Vector3(-6.5, 0, 7.5), "r": 2.3},
	]
	# 南邊一條空路，家豪才進得了木屋的門
	var lane := {"a": Vector2(0, 2.8), "b": Vector2(0, 12.5), "half": 1.8}
	build_house()
	dirt_path(Vector2(0, 11.0), Vector2(0, 3.2))
	ring_trees(8.8, 10, 4.5, avoid, lane)
	scatter_trees(30, 5.0, avoid, lane)
	build_hood(Vector3(-0.15, 0, 0.75))
	undergrowth(28)
	mushrooms(12)
