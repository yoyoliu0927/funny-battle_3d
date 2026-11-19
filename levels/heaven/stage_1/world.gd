extends "res://levels/heaven/heaven_world.gd"
## 【丹穴山 1 雲階】青綠水墨的月夜霧。白玉台上兩幅畫（畫門），北邊一段雲階通到南天門。
## 阿土、阿水的紅線都通到門甲；從門乙出來正對著雲洞。守衛站在雲階腳下，只有巨石滾下去撞得到他。

func _ice_configure() -> void:
	# ==================================================================
	# 【玩法】每個數字都對著規格（docs/仙境關卡規格.md 第 4 節），改了要重掃
	# ==================================================================
	play_min = Vector2(-20.0, -23.0)
	play_max = Vector2(20.0, 18.0)
	hero_start = Vector3(0.0, 0.0, 9.5)
	cage = Vector3(0.0, 0.0, -11.8)
	bird_path = [Vector3(0.0, 0, 6.0), Vector3(0.0, 0, -9.4)]
	lakes = [{"center": Vector2(0.0, -2.0), "rx": 10.0, "rz": 7.0}]
	ponds = [{"center": Vector2(5.5, 1.0), "r": 1.4}]
	# 門甲朝西（往東滑的人進得去）；門乙朝東（出來往東滑，正對雲洞）
	door_specs = [
		{"pos": Vector3(5.0, 0, -4.0), "face": Vector3(-1, 0, 0)},
		{"pos": Vector3(-6.5, 0, 1.0), "face": Vector3(1, 0, 0)},
	]
	pines = [Vector3(-9.0, 0, -11.5), Vector3(9.0, 0, -11.5)]
	# 雲階：白玉台北邊的一段斜坡，南天門立在斜坡中間
	stairs = {"x0": -5.0, "x1": 5.0, "z0": -9.4, "z1": -13.0, "h": 2.0}
	goal = "gate"
	goal_text = "南天門"
	# ==================================================================
	# 【外觀】不影響玩法
	# ==================================================================
	camera_start = Vector3(-1.0, 11.0, 20.3)
	camera_look = Vector3(-1.0, -2.6, -1.2)
	camera_fov = 45.0
	mood = "ink"
	isle = {"seed": 2.7, "c": Vector2(0.0, -4.0), "rz": 19.5,
		"coves": [[0.10, 5.0, 0.13], [-1.25, 4.5, 0.12], [-1.95, 4.5, 0.12], [3.30, 4.5, 0.12]]}
	clear_paths = [[Vector3(-11.0, 0, -4.0), Vector3(-2.0, 0, -4.0), Vector3(5.0, 0, -4.0)],
		[Vector3(-9.0, 0, -8.0), Vector3(-3.0, 0, -6.0), Vector3(5.0, 0, -3.3)],
		[Vector3(-3.0, 0, -6.0), Vector3(-1.0, 0, -3.0), Vector3(3.0, 0, 3.0)],
		[Vector3(-6.5, 0, 1.0), Vector3(5.5, 0, 1.0)]]
	front_props = false
	rim_kinds = [["pine", 3.0], ["rock", 1.2], ["blossom", 1.0]]
	rim_count = 20
	zones = [
		# 西岸：松林裡一座小亭子（這一關唯一的建築，半藏在霧裡）
		{"type": "pavilion", "pos": Vector3(-14.0, 0, -6.5), "yaw": 1.2, "scale": 0.9},
		{"type": "pine", "pos": Vector3(-15.5, 0, -2.0), "yaw": 0.4, "scale": 1.4},
		{"type": "pine", "pos": Vector3(-12.5, 0, -11.0), "yaw": 2.0, "scale": 1.2},
		{"type": "blossom", "pos": Vector3(-12.6, 0, 2.6), "yaw": 0.3, "scale": 1.1},
		# 東岸：山石和一棵斜出去的松
		{"type": "rock", "pos": Vector3(13.6, 0, -6.0), "yaw": 0.8, "scale": 1.5},
		{"type": "pine", "pos": Vector3(14.6, 0, -1.5), "yaw": 3.5, "scale": 1.3},
		{"type": "blossom", "pos": Vector3(12.8, 0, 4.4), "yaw": 1.9, "scale": 0.9},
		# 家豪出發點附近：兩盞宮燈（避開左下的道具格、右下的開始鈕、黃線）
		{"type": "lantern", "pos": Vector3(-3.4, 0, 10.4), "scale": 0.9},
		{"type": "lantern", "pos": Vector3(3.4, 0, 10.4), "scale": 0.9},
		{"type": "rock", "pos": Vector3(-7.6, 0, 9.4), "yaw": 2.2, "scale": 0.8},
	]
