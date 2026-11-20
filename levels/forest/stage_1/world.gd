extends "res://levels/forest/forest_world.gd"
## 第一小關「伐木場」：林子中間被砍出來的一塊空地，早晨的薄霧。
## 南邊是家豪進來的路，西北角有伐木工的營地、東邊是一堆樹墩（砍倒的樹的下場）。

func _layout_level() -> void:
	world_seed = 481516
	play_min = Vector2(-16.0, -14.0)
	play_max = Vector2(16.0, 14.0)
	hero_start = Vector3(0.0, 0.0, 11.0)
	hero_yaw = PI
	camera_start = Vector3(3.0, 8.8, 18.0)
	camera_look = Vector3(0.0, 0.6, 2.0)
	ground_a = Color(0.26, 0.46, 0.26)
	ground_b = Color(0.20, 0.38, 0.22)
	tree_tint = Color(0.68, 0.84, 0.74)
	paint_warm = 0.0
	mote_color = Color(1.0, 0.97, 0.8)
	detail_flowers = [Color(0.96, 0.96, 0.9), Color(0.9, 0.72, 0.95), Color(0.98, 0.85, 0.35)]
	detail_leaves = [Color(0.55, 0.62, 0.3), Color(0.7, 0.5, 0.2)]
	look = {
		"sky_top": Color(0.50, 0.78, 0.90), "sky_hor": Color(0.88, 0.94, 0.88),
		"sun_color": Color(1.0, 0.90, 0.68), "sun_energy": 1.65, "sun_rot": Vector3(-0.62, 0.95, 0.0),
		"ambient": Color(0.64, 0.78, 0.84), "fog": Color(0.74, 0.90, 0.80), "fog_density": 0.004,
	}

func _dress() -> void:
	var avoid := [
		{"p": Vector3(0, 0, 11.0), "r": 3.6},
		{"p": Vector3(-9.0, 0, 3.0), "r": 2.2},
		{"p": Vector3(9.5, 0, -2.5), "r": 2.2},
		{"p": Vector3(0, 0, -8.0), "r": 3.4},
		{"p": Vector3(-12.5, 0, -9.5), "r": 4.2},
		{"p": Vector3(7.0, 0, 7.0), "r": 3.2},
	]
	var lane := {"a": Vector2(0, 2.0), "b": Vector2(0, 12.5), "half": 1.7}
	dirt_path(Vector2(0, 12.8), Vector2(0, 1.0))
	camp(Vector2(-12.5, -9.5), 0.5)
	stumps([Vector2(8.0, -4.6), Vector2(11.0, -1.2), Vector2(7.4, -0.6), Vector2(11.8, -4.0), Vector2(-7.4, 4.8), Vector2(-10.6, 1.0)])
	logs([Vector3(10.2, -5.3, 0.4), Vector3(-8.0, 2.0, 1.2), Vector3(6.0, -3.2, 2.2)])
	rocks([Vector3(13.0, 5.5, 2.0), Vector3(-14.0, 7.5, 1.4), Vector3(4.5, -11.5, 1.6)])
	prop(K_SURV + "signpost-single.glb", 1.9, 10.4, 0.3, 2.3)
	scatter_trees(34, 4.3, avoid, lane)
	undergrowth(34)
	mushrooms(14)
