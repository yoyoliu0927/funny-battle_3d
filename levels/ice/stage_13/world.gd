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
	# 【外觀】（環境代理負責）：mood、isle、zones、camps、clear_paths、鏡頭 camera_*。不影響玩法。
	# ==================================================================
	# 鏡頭：家豪從湖上出發（不在南岸），所以鏡頭比別關靠前、靠東一點，家豪腳下的薄冰在畫面下方三分之一
	camera_start = Vector3(1.5, 10.5, 14.5)
	camera_look = Vector3(1.5, -2.6, -5.5)
	camera_fov = 45.0
	mood = "overcast"                            # 陰天細雪：灰白的柔光、雪下得密
	isle = {"seed": 3.1, "c": Vector2(0.0, -4.0), "rz": 19.5,
		"coves": [[0.10, 5.0, 0.13], [-1.20, 4.5, 0.12], [-1.92, 4.5, 0.12], [3.45, 4.5, 0.12]]}
	# 裝飾要讓開的路線（工人的紅線、滑出去的方向、守衛撲的方向）
	clear_paths = [[Vector3(4.9, 0, 2.4), Vector3(3.3, 0, 2.4)], [Vector3(-0.2, 0, -10.6), Vector3(2.5, 0, -2.0), Vector3(3.0, 0, 2.4)], [Vector3(4.5, 0, -6.5), Vector3(5.7, 0, -3.8)]]
	camps = [{"pos": Vector3(13.5, 0, -16.5), "yaw": -0.6}]
	# 冰湖周圍的擺設（純裝飾）。高的東西都離薄冰 9 公尺以上（薄冰破了就是冰洞，過關特寫的鏡頭會繞著拍）
	front_props = false
	zones = [
		# 這一關的地標：冰晶溪谷——兩條結冰的小溪從西邊流進湖裡，兩岸長滿大大小小的冰晶
		{"type": "creek", "from": Vector3(-17.5, 0, -14.5), "to": Vector3(-9.3, 0, -5.6)},
		{"type": "creek", "from": Vector3(-17.5, 0, 9.5), "to": Vector3(-9.6, 0, 0.2)},
		{"type": "crystals", "pos": Vector3(-15.0, 0, -9.0), "scale": 1.5},
		{"type": "crystals", "pos": Vector3(-11.0, 0, -10.2), "scale": 1.1},
		{"type": "crystals", "pos": Vector3(-13.6, 0, -4.4), "scale": 0.9},
		{"type": "crystals", "pos": Vector3(-12.6, 0, 0.6), "scale": 1.3},
		{"type": "crystals", "pos": Vector3(-15.2, 0, 3.6), "scale": 1.0},
		{"type": "crystals", "pos": Vector3(-10.4, 0, 6.2), "scale": 1.2},
		{"type": "lantern", "pos": Vector3(-10.6, 0, -2.6)},
		# 溪谷延伸到南岸（鏡頭前面）：幾簇小冰晶
		{"type": "crystals", "pos": Vector3(-5.6, 0, 8.4), "scale": 0.8},
		{"type": "crystals", "pos": Vector3(10.6, 0, 8.6), "scale": 0.7},
		{"type": "crystals", "pos": Vector3(15.0, 0, -8.0), "scale": 1.0},
	]
