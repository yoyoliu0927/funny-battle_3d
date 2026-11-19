extends "res://levels/heaven/heaven_world.gd"
## 【丹穴山 2 山海迴廊】金黃樓閣的街市：兩條白玉鋪的街交叉成一個街口，四個角是木造的樓閣和銀杏。
## 陸吾趴在街口的西北角，面前那塊金光橫過南北向的大街，蓋住黃線：誰先走進去誰被吹走。

func _ice_configure() -> void:
	# ==================================================================
	# 【玩法】
	# ==================================================================
	play_min = Vector2(-24.0, -24.0)
	play_max = Vector2(24.0, 18.0)
	hero_start = Vector3(0.0, 0.0, 10.5)
	cage = Vector3(0.0, 0.0, -11.8)
	bird_path = [Vector3(0.0, 0, 6.0), Vector3(0.0, 0, -9.4)]
	# 街口：東西向的橫街（阿土、阿水的紅線都在上面）、南北向的大街（黃線）
	courts = [
		{"c": Vector2(0.0, -4.75), "hx": 11.5, "hz": 4.25},
		{"c": Vector2(0.0, -1.5), "hx": 4.6, "hz": 8.0},
	]
	ponds = [{"center": Vector2(7.2, -6.5), "r": 1.2}]
	snow_piles = [Vector3(7.5, 0, 0.0)]
	# 陸吾朝東：視線是 x -3.5 到 1.0、z -2.1 到 0.1，蓋住黃線
	luwu_spec = {"pos": Vector3(-4.5, 0, -1.0), "face": Vector3(1, 0, 0)}
	pines = [Vector3(-10.0, 0, -11.5), Vector3(10.5, 0, -11.5)]
	goal = "steps"
	goal_text = "山門"
	hole_word = "錦鯉池"
	rough_word = "石板路"
	pile_word = "落葉堆"
	# ==================================================================
	# 【外觀】
	# ==================================================================
	camera_start = Vector3(-1.0, 12.2, 22.4)
	camera_look = Vector3(-1.0, -2.9, -1.8)
	camera_fov = 45.0
	mood = "gold"
	isle = {"seed": 6.1}
	clear_paths = [[Vector3(-24.0, 0, -6.5), Vector3(-3.0, 0, -6.5), Vector3(7.2, 0, -6.5)],
		[Vector3(7.5, 0, -8.5), Vector3(3.5, 0, -4.0), Vector3(-3.5, 0, 3.0)],
		[Vector3(3.5, 0, -4.0), Vector3(5.0, 0, -2.5), Vector3(7.5, 0, 0.0), Vector3(8.4, 0, 0.9)]]
	# 街往四個方向延伸出去（石板路）
	walks = [
		[Vector3(0.0, 0, 24.0), Vector3(0.0, 0, 6.5), 5.0],
		[Vector3(-34.0, 0, -4.75), Vector3(-11.5, 0, -4.75), 6.0],
		[Vector3(11.5, 0, -4.75), Vector3(34.0, 0, -4.75), 6.0],
		[Vector3(0.0, 0, -9.5), Vector3(0.0, 0, -30.0), 5.0],
	]
	front_props = false
	rim_kinds = [["ginkgo", 3.0], ["lantern", 0.8], ["rock", 0.4]]
	rim_count = 26
	rim_far = 34.0
	zones = [
		# ---- 西北角：三層的樓閣接一段迴廊
		{"type": "tower", "pos": Vector3(-12.5, 0, -16.0), "yaw": 0.0, "scale": 1.15},
		{"type": "corridor", "pos": Vector3(-6.6, 0, -15.6), "yaw": 1.5708},
		{"type": "house", "pos": Vector3(-19.5, 0, -13.0), "yaw": 0.0},
		# ---- 東北角：木樓、亭子
		{"type": "house", "pos": Vector3(13.6, 0, -15.4), "yaw": 0.0, "scale": 1.1},
		{"type": "pavilion", "pos": Vector3(7.0, 0, -15.6), "yaw": 0.5, "scale": 0.9},
		{"type": "house", "pos": Vector3(20.5, 0, -13.6), "yaw": -0.2},
		# ---- 西南角：臨街的木樓（正面朝大街）、大銀杏
		{"type": "house", "pos": Vector3(-11.0, 0, 5.2), "yaw": 1.5708, "scale": 1.05},
		{"type": "ginkgo", "pos": Vector3(-8.6, 0, 9.6), "yaw": 0.7, "scale": 0.9},
		{"type": "house", "pos": Vector3(-18.0, 0, 3.4), "yaw": 3.1416},
		{"type": "ginkgo", "pos": Vector3(-17.5, 0, 11.5), "yaw": 2.0, "scale": 1.3},
		# ---- 東南角：落葉堆旁邊的大銀杏、木樓退後一點
		{"type": "ginkgo", "pos": Vector3(12.6, 0, 1.6), "yaw": 2.1, "scale": 1.1},
		{"type": "house", "pos": Vector3(15.0, 0, 6.6), "yaw": -1.5708, "scale": 1.05},
		{"type": "ginkgo", "pos": Vector3(19.0, 0, 11.0), "yaw": 4.0, "scale": 1.3},
		# ---- 紅綢帶：橫過北邊的街、從樓閣拉到對面
		{"type": "ribbon", "from": Vector3(-11.5, 0, -14.6), "to": Vector3(12.6, 0, -14.4), "h": 7.6, "sag": 1.8},
		# ---- 一串一串的小燈籠：兩邊的街、北邊的街
		{"type": "lanterns", "from": Vector3(-14.4, 0, 3.6), "to": Vector3(-13.6, 0, -14.6), "h": 5.4, "sag": 1.2, "n": 9},
		{"type": "lanterns", "from": Vector3(14.6, 0, 5.2), "to": Vector3(14.0, 0, -14.2), "h": 5.4, "sag": 1.2, "n": 9},
		{"type": "lanterns", "from": Vector3(-10.5, 0, -15.6), "to": Vector3(10.5, 0, -15.6), "h": 6.4, "sag": 1.0, "n": 10},
		# ---- 小吃攤和幌子：街口四個角
		{"type": "stall", "pos": Vector3(-7.6, 0, 3.0), "yaw": 1.5708, "scale": 1.0},
		{"type": "stall", "pos": Vector3(9.2, 0, 5.0), "yaw": -1.5708, "scale": 1.0},
		{"type": "stall", "pos": Vector3(-6.0, 0, -12.2), "yaw": 0.0, "scale": 1.0},
		{"type": "stall", "pos": Vector3(5.6, 0, -12.4), "yaw": 0.0, "scale": 1.0},
		{"type": "banner", "pos": Vector3(-9.6, 0, 1.2), "yaw": 0.3, "text": "餅"},
		{"type": "banner", "pos": Vector3(-13.0, 0, -11.0), "yaw": 0.0, "text": "茶"},
		{"type": "banner", "pos": Vector3(12.6, 0, -11.2), "yaw": 0.0, "text": "酒"},
		{"type": "banner", "pos": Vector3(10.6, 0, 7.4), "yaw": -0.3, "text": "麵"},
		# ---- 街邊的宮燈
		{"type": "lantern", "pos": Vector3(-3.4, 0, 9.6), "scale": 0.95},
		{"type": "lantern", "pos": Vector3(3.4, 0, 9.6), "scale": 0.95},
		{"type": "lantern", "pos": Vector3(-13.2, 0, -0.2), "scale": 1.0},
		{"type": "lantern", "pos": Vector3(13.2, 0, -9.4), "scale": 1.0},
		# ---- 西邊的水道，橫街過一座小拱橋
		{"type": "river", "pts": [Vector3(-27.0, 0, -44.0), Vector3(-26.0, 0, -12.0), Vector3(-27.5, 0, 8.0), Vector3(-25.0, 0, 32.0)], "w": 6.0},
		{"type": "bridge", "pos": Vector3(-26.2, 0, -4.75), "yaw": 1.5708, "scale": 1.3},
		# ---- 遠處的樓閣（背景）
		{"type": "tower", "pos": Vector3(-34.0, 0, -30.0), "yaw": 0.4, "scale": 1.6},
		{"type": "tower", "pos": Vector3(30.0, 0, -34.0), "yaw": -0.4, "scale": 1.5},
		{"type": "tower", "pos": Vector3(36.0, 0, 2.0), "yaw": -1.2, "scale": 1.2},
		{"type": "gate", "pos": Vector3(0.0, 0, -32.0), "yaw": 0.0, "scale": 1.8},
	]
