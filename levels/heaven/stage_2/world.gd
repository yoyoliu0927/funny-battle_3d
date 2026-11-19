extends "res://levels/heaven/heaven_world.gd"
## 【丹穴山 2 山海迴廊】金黃樓閣的午後。陸吾趴在黃線西邊，面前那塊金光蓋住黃線：誰先走進去誰被吹走。

func _ice_configure() -> void:
	# ==================================================================
	# 【玩法】
	# ==================================================================
	play_min = Vector2(-20.0, -23.0)
	play_max = Vector2(20.0, 18.0)
	hero_start = Vector3(0.0, 0.0, 10.5)
	cage = Vector3(0.0, 0.0, -11.8)
	bird_path = [Vector3(0.0, 0, 6.0), Vector3(0.0, 0, -9.4)]
	lakes = [{"center": Vector2(0.0, -2.5), "rx": 10.5, "rz": 7.0}]
	ponds = [{"center": Vector2(7.2, -6.5), "r": 1.2}]
	snow_piles = [Vector3(7.5, 0, 0.0)]
	# 陸吾朝東：視線是 x -3.5 到 1.0、z -2.1 到 0.1，蓋住黃線
	luwu_spec = {"pos": Vector3(-4.5, 0, -1.0), "face": Vector3(1, 0, 0)}
	pines = [Vector3(-10.0, 0, -11.5), Vector3(10.5, 0, -11.5)]
	goal = "steps"
	goal_text = "山門"
	# ==================================================================
	# 【外觀】
	# ==================================================================
	camera_start = Vector3(-1.0, 11.3, 20.8)
	camera_look = Vector3(-1.0, -2.7, -1.5)
	camera_fov = 45.0
	mood = "gold"
	isle = {"seed": 6.1, "c": Vector2(0.0, -4.0), "rz": 19.5,
		"coves": [[0.20, 5.0, 0.13], [-1.20, 4.5, 0.12], [-1.92, 4.5, 0.12], [3.25, 4.5, 0.12]]}
	clear_paths = [[Vector3(-10.5, 0, -6.5), Vector3(-3.0, 0, -6.5), Vector3(7.2, 0, -6.5)],
		[Vector3(7.5, 0, -8.5), Vector3(3.5, 0, -4.0), Vector3(-3.5, 0, 3.0)],
		[Vector3(3.5, 0, -4.0), Vector3(5.0, 0, -2.5), Vector3(7.5, 0, 0.0)]]
	front_props = false
	rim_kinds = [["ginkgo", 3.0], ["rock", 0.6], ["lantern", 0.5]]
	rim_count = 18
	zones = [
		# 這一關的地標：西岸一排木造迴廊接一座樓閣，簷下掛紅綢帶
		{"type": "tower", "pos": Vector3(-15.0, 0, -9.0), "yaw": 0.9, "scale": 1.0},
		{"type": "corridor", "pos": Vector3(-14.4, 0, -3.2), "yaw": 0.0},
		{"type": "corridor", "pos": Vector3(-14.4, 0, 1.6), "yaw": 0.0},
		{"type": "ginkgo", "pos": Vector3(-12.0, 0, 5.6), "yaw": 0.7, "scale": 1.4},
		# 東岸：亭子和大銀杏
		{"type": "pavilion", "pos": Vector3(14.6, 0, -8.5), "yaw": -0.8, "scale": 1.0},
		{"type": "ginkgo", "pos": Vector3(13.6, 0, -2.6), "yaw": 2.1, "scale": 1.5},
		{"type": "ginkgo", "pos": Vector3(12.4, 0, 5.2), "yaw": 4.0, "scale": 1.1},
		# 紅綢帶：從樓閣拉到東岸的亭子，橫過北邊的天空
		{"type": "ribbon", "from": Vector3(-14.0, 0, -9.6), "to": Vector3(14.0, 0, -9.4), "h": 7.5, "sag": 1.6},
		{"type": "ribbon", "from": Vector3(-14.4, 0, -4.0), "to": Vector3(-9.5, 0, -12.5), "h": 5.0, "sag": 0.9},
		{"type": "lantern", "pos": Vector3(-3.6, 0, 11.2), "scale": 0.9},
		{"type": "lantern", "pos": Vector3(3.6, 0, 11.2), "scale": 0.9},
	]
