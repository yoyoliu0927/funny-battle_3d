extends "res://levels/heaven/heaven_world.gd"
## 【丹穴山 3 天門】星空下的金色圓環。畫門加陸吾，五個人分兩批；黃線只走到唱盤前面，唱盤上要放飼料。

func _ice_configure() -> void:
	# ==================================================================
	# 【玩法】
	# ==================================================================
	play_min = Vector2(-20.0, -23.0)
	play_max = Vector2(20.0, 18.0)
	hero_start = Vector3(0.0, 0.0, 10.5)
	cage = Vector3(0.0, 0.0, -11.8)
	bird_path = [Vector3(0.0, 0, 6.0), Vector3(0.0, 0, -9.6)]
	lakes = [{"center": Vector2(0.0, -2.5), "rx": 11.0, "rz": 7.5}]
	# 雲洞甲（東）：阿土撞上守衛後兩人進去，從門乙出來的人也掉這裡；雲洞乙（北）：大老闆那條線的第一段
	ponds = [{"center": Vector2(7.5, -6.2), "r": 1.3}, {"center": Vector2(5.0, -8.0), "r": 1.2}]
	# 陸吾朝西：視線是 x -0.5 到 4.0、z -3.6 到 -1.4，蓋住黃線
	luwu_spec = {"pos": Vector3(5.0, 0, -2.5), "face": Vector3(-1, 0, 0)}
	# 門甲的正面朝西北（阿水第二段往東南滑會進去）；門乙朝北，在陸吾背後，出口正對雲洞甲
	door_specs = [
		{"pos": Vector3(-4.0, 0, 0.9), "face": Vector3(-0.707, 0, -0.707)},
		{"pos": Vector3(8.0, 0, -3.4), "face": Vector3(0, 0, -1)},
	]
	goal = "disc"
	goal_text = "唱盤"
	# ==================================================================
	# 【外觀】
	# ==================================================================
	camera_start = Vector3(-1.0, 11.6, 21.4)
	camera_look = Vector3(-1.0, -2.7, -1.7)
	camera_fov = 45.0
	finale_cam_pos = Vector3(0.0, 7.5, 6.0)
	finale_cam_look = Vector3(0.0, 4.0, -14.0)
	mood = "astral"
	isle = {"seed": 9.3, "c": Vector2(0.0, -4.0), "rz": 19.5,
		"coves": [[0.15, 4.5, 0.12], [-1.28, 4.5, 0.12], [-1.90, 4.5, 0.12], [3.30, 4.0, 0.12]]}
	clear_paths = [[Vector3(-10.5, 0, -6.2), Vector3(-3.5, 0, -6.2), Vector3(7.5, 0, -6.2)],
		[Vector3(-10.5, 0, -2.5), Vector3(-6.0, 0, -2.5), Vector3(4.0, 0, -2.5)],
		[Vector3(-6.0, 0, -2.5), Vector3(-5.0, 0, -0.8), Vector3(-4.0, 0, 0.9)],
		[Vector3(-9.5, 0, -8.0), Vector3(-4.5, 0, -8.0), Vector3(5.0, 0, -8.0)],
		[Vector3(-4.5, 0, -8.0), Vector3(-3.2, 0, -7.0), Vector3(1.2, 0, -3.6)],
		[Vector3(8.0, 0, -3.4), Vector3(7.5, 0, -6.2)]]
	front_props = false
	rim_kinds = [["stele", 1.0], ["lantern", 1.6], ["rock", 0.8]]
	rim_count = 14
	zones = [
		# 路兩旁的宮燈：一路排到唱盤（發光的路）
		{"type": "lantern", "pos": Vector3(-3.0, 0, 10.6), "scale": 0.9},
		{"type": "lantern", "pos": Vector3(3.0, 0, 10.6), "scale": 0.9},
		{"type": "lantern", "pos": Vector3(-3.2, 0, -10.6), "scale": 1.0},
		{"type": "lantern", "pos": Vector3(3.2, 0, -10.6), "scale": 1.0},
		# 兩邊立著寫滿字的石碑
		{"type": "stele", "pos": Vector3(-13.6, 0, -8.0), "yaw": 0.5, "scale": 1.6},
		{"type": "stele", "pos": Vector3(13.6, 0, -9.0), "yaw": -0.5, "scale": 1.6},
		{"type": "stele", "pos": Vector3(-14.6, 0, -1.0), "yaw": 0.9, "scale": 1.2},
		{"type": "stele", "pos": Vector3(14.6, 0, 0.5), "yaw": -0.9, "scale": 1.2},
	]
