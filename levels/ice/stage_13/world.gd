extends "res://levels/ice/rescue_world.gd"
## 【冰雪島 3 薄冰】家豪一開始就站在薄冰甲上（雞踩了沒事）。阿土的紅線直接穿過那塊薄冰，一開打就踩破。
## 阿水從北邊迎面跑來，延長線正對薄冰甲；守衛站在黃線東邊，薄冰乙在他的東南邊。

func _ice_configure() -> void:
	# ==================================================================
	# 【玩法】（關卡設定線負責）：範圍、湖、冰洞、薄冰、雪人、雪堆、松樹、籠子、家豪起點、黃線。
	#   這一段的每個數字都掃過線，改了要重掃（見 levels/ice/docs/關卡規格.md 第 3 節「要確認」）。
	# ==================================================================
	play_min = Vector2(-20.0, -23.0)
	play_max = Vector2(20.0, 18.0)
	hero_start = Vector3(3.0, 0.0, 2.4)
	cage = Vector3(3.0, 0.0, -11.8)
	bird_path = [Vector3(3.0, 0, -9.4)]
	lakes = [{"center": Vector2(0.0, -2.5), "rx": 10.5, "rz": 7.0}]
	ponds = []
	# 薄冰甲：家豪腳下、阿土一開打就踩破；薄冰乙：飼料把黃線拉到這一側，守衛撲過來就踩到
	thin_spots = [{"center": Vector2(3.0, 2.4), "r": 1.6}, {"center": Vector2(5.1, -5.15), "r": 1.1}]
	snowmen = []
	pines = [Vector3(-5.5, 0, -12.5), Vector3(10.5, 0, -11.5), Vector3(11.5, 0, 2.0)]
	# ==================================================================
	# 【外觀】（環境代理負責）：mood、isle、zones、camps、clear_paths、鏡頭 camera_*。
	#   目前是從 stage_10 複製來、能跑的暫時值；不影響玩法。
	# ==================================================================
	camera_start = Vector3(-1.5, 11.0, 20.3)
	camera_look = Vector3(-1.0, -2.7, -1.6)      # y 只用來調俯角：家豪的圓環完整入鏡、腳下留一點空間
	camera_fov = 45.0
	mood = "sunset"
	# ---- 以下都是外觀（不影響玩法）
	# 地圖的輪廓：南邊（鏡頭這一側）收短一點；coves 是岸邊凹進來的小海灣（看得到對面的冰崖）
	isle = {"seed": 4.6, "c": Vector2(0.0, -4.0), "rz": 19.5,
		"coves": [[0.15, 5.0, 0.13], [-1.30, 4.5, 0.12], [-1.90, 4.5, 0.12], [3.25, 4.5, 0.12]]}
	# 裝飾要讓開的路線（工人的紅線、滑出去的方向）
	clear_paths = [[Vector3(4.9, 0, 2.4), Vector3(3.3, 0, 2.4)], [Vector3(0.8, 0, -11.3), Vector3(2.8, 0, -2.0), Vector3(3.0, 0, 2.4)]]
	# 工人的冰釣營地（裝飾）：在他們出發點後面
	camps = [{"pos": Vector3(-15.0, 0, -12.5), "yaw": 1.0}, {"pos": Vector3(13.5, 0, -16.5), "yaw": -0.6}]
	# 冰湖周圍的擺設（純裝飾）。高的東西都離冰洞 9 公尺以上：過關特寫的鏡頭會繞著冰洞拍
	front_props = false
	zones = [
		# 這一關的地標：湖西南岸的冰雕廣場——大冰企鵝、冰魚圍著一簇冰晶，兩盞燈
		{"type": "statue", "kind": "penguin", "pos": Vector3(-11.4, 0, 1.6), "yaw": 0.5, "scale": 1.8},
		{"type": "statue", "kind": "fish", "pos": Vector3(-13.2, 0, -1.4), "yaw": 0.9, "scale": 2.4},
		{"type": "statue", "kind": "penguin", "pos": Vector3(-9.4, 0, 4.0), "yaw": 0.2, "scale": 1.0},
		{"type": "statue", "kind": "fish", "pos": Vector3(-13.0, 0, 4.4), "yaw": 0.6, "scale": 1.8},
		{"type": "lantern", "pos": Vector3(-9.4, 0, 1.4)},
		{"type": "lantern", "pos": Vector3(-11.6, 0, 4.6)},
		# 廣場延伸到家豪出發點附近：兩座小冰雕（避開左下的道具格、右下的開始鈕、黃線）
		{"type": "statue", "kind": "penguin", "pos": Vector3(-9.8, 0, 9.0), "yaw": 0.4, "scale": 0.8},
		{"type": "statue", "kind": "fish", "pos": Vector3(-1.4, 0, 10.6), "yaw": -0.3, "scale": 1.5},
		{"type": "pier", "pos": Vector3(9.0, 0, 3.6), "yaw": 1.57},
		{"type": "crystals", "pos": Vector3(16.5, 0, -11.0)},
	]
