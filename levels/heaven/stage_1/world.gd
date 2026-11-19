extends "res://levels/heaven/heaven_world.gd"
## 【丹穴山 1 雲階】青綠水墨的霧景：松林裡一座十字形的白玉平台，北邊一段雲階通到南天門，東邊一條小河。
## 平台上兩幅畫（畫門）。阿土、阿水的紅線都通到門甲；從門乙出來正對著水潭。守衛站在雲階腳下，只有巨石滾下去撞得到他。

func _ice_configure() -> void:
	# ==================================================================
	# 【玩法】每個數字都對著規格（docs/仙境關卡規格.md 第 4 節），改了要重跑 tests/solve.gd
	# ==================================================================
	play_min = Vector2(-24.0, -24.0)
	play_max = Vector2(24.0, 18.0)
	hero_start = Vector3(0.0, 0.0, 9.5)
	cage = Vector3(0.0, 0.0, -11.8)
	bird_path = [Vector3(0.0, 0, 6.0), Vector3(0.0, 0, -9.4)]
	# 十字形的白玉平台：東西向一橫（阿土的紅線走在上面）、南北向一豎（黃線走在上面）
	courts = [
		{"c": Vector2(0.0, -4.0), "hx": 11.5, "hz": 3.6},
		{"c": Vector2(0.0, -1.9), "hx": 7.6, "hz": 7.4},
	]
	ponds = [{"center": Vector2(5.5, 1.0), "r": 1.4}]
	# 門甲朝西（往東滑的人進得去）；門乙朝東（出來往東滑，正對水潭）
	door_specs = [
		{"pos": Vector3(5.0, 0, -4.0), "face": Vector3(-1, 0, 0)},
		{"pos": Vector3(-6.5, 0, 1.0), "face": Vector3(1, 0, 0)},
	]
	pines = [Vector3(-9.0, 0, -11.5), Vector3(9.0, 0, -11.5)]
	# 雲階：平台北邊的一段斜坡，南天門立在斜坡中間
	stairs = {"x0": -5.0, "x1": 5.0, "z0": -9.4, "z1": -13.0, "h": 2.0}
	goal = "gate"
	goal_text = "南天門"
	hole_word = "水潭"
	rough_word = "草地"
	# ==================================================================
	# 【外觀】不影響玩法
	# ==================================================================
	camera_start = Vector3(-1.0, 12.0, 22.0)
	camera_look = Vector3(-1.0, -2.8, -1.6)
	camera_fov = 45.0
	mood = "ink"
	isle = {"seed": 2.7}
	clear_paths = [[Vector3(-22.0, 0, -4.0), Vector3(-2.0, 0, -4.0), Vector3(5.0, 0, -4.0)],
		[Vector3(-16.0, 0, -10.3), Vector3(-9.0, 0, -8.0), Vector3(-3.0, 0, -6.0), Vector3(5.0, 0, -3.3)],
		[Vector3(-3.0, 0, -6.0), Vector3(-1.0, 0, -3.0), Vector3(4.7, 0, 5.5), Vector3(5.6, 0, 6.8)],
		[Vector3(-6.5, 0, 1.0), Vector3(5.5, 0, 1.0)]]
	# 步道：家豪從南邊走上來；工人從西邊的林子裡跑出來；東邊過橋到河對岸
	walks = [
		[Vector3(0.0, 0, 22.0), Vector3(0.0, 0, 5.5), 3.2],
		[Vector3(-30.0, 0, -4.0), Vector3(-11.5, 0, -4.0), 2.6],
		[Vector3(-22.0, 0, -12.3), Vector3(-7.4, 0, -7.4), 2.2],
		[Vector3(11.5, 0, -4.0), Vector3(30.0, 0, -4.0), 2.6],
	]
	front_props = false
	rim_kinds = [["pine", 3.2], ["rock", 1.0], ["blossom", 1.0]]
	rim_count = 46
	rim_far = 36.0
	zones = [
		# 東邊的小河，從北邊的山裡流下來；步道過一座小拱橋
		{"type": "river", "pts": [Vector3(30.0, 0, -44.0), Vector3(21.0, 0, -24.0), Vector3(17.5, 0, -6.0), Vector3(19.5, 0, 9.0), Vector3(15.0, 0, 30.0)], "w": 5.5},
		{"type": "bridge", "pos": Vector3(17.6, 0, -4.0), "yaw": 1.5708},
		# 西北：松林裡一座亭子（半藏在霧裡）
		{"type": "pavilion", "pos": Vector3(-15.5, 0, -15.5), "yaw": 0.8, "scale": 1.0},
		{"type": "pine", "pos": Vector3(-18.5, 0, -9.5), "yaw": 0.4, "scale": 1.5},
		{"type": "pine", "pos": Vector3(-12.0, 0, -19.0), "yaw": 2.0, "scale": 1.7},
		{"type": "blossom", "pos": Vector3(-13.4, 0, 4.6), "yaw": 0.3, "scale": 1.2},
		{"type": "pine", "pos": Vector3(-16.5, 0, 2.0), "yaw": 5.0, "scale": 1.3},
		# 東岸：山石和斜出去的松，花樹在水邊
		{"type": "rock", "pos": Vector3(12.6, 0, -10.6), "yaw": 0.8, "scale": 1.6},
		{"type": "pine", "pos": Vector3(13.4, 0, 3.5), "yaw": 3.5, "scale": 1.4},
		{"type": "blossom", "pos": Vector3(14.2, 0, -0.6), "yaw": 1.9, "scale": 1.0},
		{"type": "blossom", "pos": Vector3(22.4, 0, 4.4), "yaw": 4.2, "scale": 1.3},
		# 平台四個凹進去的角：石頭、宮燈
		{"type": "lantern", "pos": Vector3(-9.2, 0, 1.4), "scale": 1.0},
		{"type": "lantern", "pos": Vector3(9.2, 0, 1.4), "scale": 1.0},
		{"type": "rock", "pos": Vector3(-10.4, 0, 3.6), "yaw": 2.2, "scale": 1.0},
		{"type": "rock", "pos": Vector3(10.2, 0, -9.4), "yaw": 4.0, "scale": 0.9},
		# 步道兩旁的宮燈（避開左下的道具格、右下的開始鈕、黃線）
		{"type": "lantern", "pos": Vector3(-2.8, 0, 11.4), "scale": 0.9},
		{"type": "lantern", "pos": Vector3(2.8, 0, 11.4), "scale": 0.9},
		# 遠處：霧裡的樓閣和牌樓（背景）
		{"type": "tower", "pos": Vector3(-30.0, 0, -36.0), "yaw": 0.6, "scale": 1.5},
		{"type": "tower", "pos": Vector3(34.0, 0, -30.0), "yaw": -0.5, "scale": 1.2},
		{"type": "gate", "pos": Vector3(0.0, 0, -34.0), "yaw": 0.0, "scale": 1.6},
	]
