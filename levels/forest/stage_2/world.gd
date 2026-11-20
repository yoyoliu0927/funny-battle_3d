extends "res://levels/forest/forest_world.gd"
## 第二小關「煙圈」：午後被曬得乾乾的草地，東南角有一個小池塘（水桶的水從那裡來）。
## 三個抽菸的人各占一塊樹林；樹乾得很，菸蒂一掉就會燒。

func _layout_level() -> void:
	world_seed = 481522
	play_min = Vector2(-15.0, -13.0)
	play_max = Vector2(15.0, 13.0)
	hero_start = Vector3(0.0, 0.0, 10.0)
	hero_yaw = PI
	camera_start = Vector3(-2.0, 8.4, 17.0)
	camera_look = Vector3(0.0, 0.6, 1.0)
	ground_a = Color(0.36, 0.50, 0.26)
	ground_b = Color(0.30, 0.42, 0.22)
	ponds = [{"center": Vector2(10.0, 6.5), "r": 3.1}]
	tree_tint = Color(0.82, 0.78, 0.56)
	paint_warm = 0.08
	mote_color = Color(1.0, 0.85, 0.5)
	detail_flowers = [Color(0.98, 0.78, 0.25), Color(0.95, 0.55, 0.2), Color(0.95, 0.95, 0.85)]
	detail_leaves = [Color(0.85, 0.55, 0.15), Color(0.7, 0.35, 0.12), Color(0.55, 0.4, 0.15)]
	look = {
		"sky_top": Color(0.46, 0.72, 0.90), "sky_hor": Color(1.0, 0.92, 0.72),
		"sun_color": Color(1.0, 0.80, 0.46), "sun_energy": 1.95, "sun_rot": Vector3(-0.5, 0.95, 0.0),
		"ambient": Color(0.80, 0.76, 0.62), "fog": Color(0.90, 0.86, 0.72), "fog_density": 0.0035,
	}

func _dress() -> void:
	var avoid := [
		{"p": Vector3(0, 0, 10.0), "r": 3.6},
		{"p": Vector3(-7.0, 0, 1.5), "r": 2.4},
		{"p": Vector3(7.5, 0, -2.0), "r": 2.4},
		{"p": Vector3(0.0, 0, -7.0), "r": 2.4},
		{"p": Vector3(-10.0, 0, -8.5), "r": 2.2},
		{"p": Vector3(10.0, 0, 6.5), "r": 5.0},
	]
	var lane := {"a": Vector2(0, 3.0), "b": Vector2(0, 11.5), "half": 1.6}
	dirt_path(Vector2(0, 11.8), Vector2(0, 4.0))
	rocks([Vector3(13.4, 3.0, 1.5), Vector3(12.5, 9.8, 1.8), Vector3(7.0, 9.6, 1.3), Vector3(7.4, 3.6, 1.2), Vector3(-13.5, -3.0, 1.8)])
	pond_life(Vector2(10.0, 6.5), 3.1)
	# 池塘岸邊：一圈石頭
	for k in 9:
		var a := TAU * float(k) / 9.0 + 0.3
		prop(K_CASTLE + "rocks-small.glb", 10.0 + cos(a) * 3.5, 6.5 + sin(a) * 3.5, a * 2.0, 0.9 + 0.3 * float(k % 3), 0.0)
	prop(K_SURV + "barrel.glb", 4.4, 8.6, 0.0, 2.0, 0.45)
	prop(K_SURV + "bedroll-packed.glb", -3.0, 5.0, 0.8, 2.4, 0.0)
	prop(K_SURV + "campfire-pit.glb", -5.0, 4.4, 0.0, 2.0, 0.6)
	stumps([Vector2(-11.0, -5.5), Vector2(11.5, -9.0)])
	scatter_trees(36, 4.0, avoid, lane)
	undergrowth(30)
	mushrooms(8)
