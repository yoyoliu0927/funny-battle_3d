extends "res://levels/forest/forest_world.gd"
## 第三小關「狼外婆的木屋」：木屋在林子中間，南邊的小路是家豪進來的路。
## 從傍晚開始，天色會隨著小紅帽的計時越來越暗，屋裡的燈越來越亮。

func _layout_level() -> void:
	world_seed = 481530
	play_min = Vector2(-16.0, -14.0)
	play_max = Vector2(16.0, 14.0)
	hero_start = Vector3(0.0, 0.0, 11.2)
	hero_yaw = PI
	camera_start = Vector3(2.4, 8.6, 17.8)
	camera_look = Vector3(0.0, 0.6, 9.0)
	has_house = true
	house_center = Vector2.ZERO
	walls = house_walls()
	escape_point = Vector3(0.0, 0.0, house_half_z + 1.9)
	ground_a = Color(0.30, 0.48, 0.22)
	ground_b = Color(0.22, 0.38, 0.16)
	tree_tint = Color(0.70, 0.78, 0.58)
	paint_warm = 0.12
	mote_color = Color(0.85, 1.0, 0.45)
	mote_glow = 1.6
	mote_count = 40
	detail_flowers = [Color(0.9, 0.45, 0.55), Color(0.95, 0.9, 0.6), Color(0.7, 0.55, 0.95)]
	detail_leaves = [Color(0.7, 0.4, 0.15), Color(0.5, 0.25, 0.12)]
	look = {
		"sky_top": Color(0.42, 0.66, 0.86), "sky_hor": Color(1.0, 0.86, 0.62),
		"sun_color": Color(1.0, 0.78, 0.46), "sun_energy": 1.8, "sun_rot": Vector3(-0.42, 0.95, 0.0),
		"ambient": Color(0.74, 0.72, 0.68), "fog": Color(0.92, 0.80, 0.62), "fog_density": 0.0042,
	}
	look2 = {
		"sky_top": Color(0.10, 0.12, 0.32), "sky_hor": Color(0.92, 0.40, 0.30),
		"sun_color": Color(1.0, 0.45, 0.25), "sun_energy": 0.45, "sun_rot": Vector3(-0.10, 0.95, 0.0),
		"ambient": Color(0.30, 0.30, 0.55), "fog": Color(0.45, 0.28, 0.40), "fog_density": 0.008,
	}

func _dress() -> void:
	var avoid := [
		{"p": Vector3(0, 0, 11.2), "r": 3.4},
		{"p": Vector3(-10.5, 0, 3.0), "r": 2.0},
		{"p": Vector3(10.0, 0, -4.5), "r": 2.0},
		{"p": Vector3(8.0, 0, 1.5), "r": 2.3},
		{"p": Vector3(7.0, 0, 8.0), "r": 2.0},
	]
	# 南邊一條空路，家豪才進得了木屋的門
	var lane := {"a": Vector2(0, 2.8), "b": Vector2(0, 12.5), "half": 1.8}
	build_house()
	dirt_path(Vector2(0, 11.0), Vector2(0, 3.2))
	fence_row(Vector2(-2.3, 11.2), Vector2(-2.3, 5.2))
	fence_row(Vector2(2.3, 11.2), Vector2(2.3, 5.2))
	prop(K_SURV + "barrel.glb", -4.4, 1.2, 0.0, 2.0, 0.45)
	prop(K_SURV + "resource-wood.glb", 4.8, -1.4, 0.6, 2.2, 0.8)
	prop(K_SURV + "bucket.glb", -3.8, 3.6, 0.0, 2.6, 0.0)
	prop(K_SURV + "signpost-single.glb", 1.9, 10.4, 0.3, 2.3)
	rocks([Vector3(12.5, 6.0, 1.8), Vector3(-13.5, -6.0, 1.6)])
	ring_trees(8.8, 10, 4.5, avoid, lane)
	scatter_trees(34, 4.9, avoid, lane)
	build_hood(Vector3(-0.15, 0, 0.75))
	undergrowth(28)
	mushrooms(12)
