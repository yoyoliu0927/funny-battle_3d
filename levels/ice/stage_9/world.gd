extends "res://levels/ice/rescue_world.gd"
## 【救企鵝 1】家豪從南邊直直走到北岸的籠子。工人從西北角衝出來，路線有三段：
##   第一段在雪地上（只會跌倒）；第二段看起來對著一個冰洞，但中間有雪人擋著；最後一段才真的對著另一個冰洞。

func _ice_configure() -> void:
	play_min = Vector2(-20.0, -23.0)
	play_max = Vector2(20.0, 18.0)
	hero_start = Vector3(0.0, 0.0, 9.5)
	# 鏡頭：視角收窄到 45 度、退遠一點（像看一個小模型）。家豪在畫面最下面、籠子在最上面、冰湖佔中間一半以上
	camera_start = Vector3(0.5, 11.0, 20.3)
	camera_look = Vector3(0.5, -2.6, -1.2)       # y 只用來調俯角：家豪腳下留一點空間
	camera_fov = 45.0
	mood = "morning"
	cage = Vector3(0.0, 0.0, -11.6)
	bird_path = [Vector3(0.0, 0, 6.0), Vector3(0.0, 0, -9.2)]
	lakes = [{"center": Vector2(0.0, -1.5), "rx": 9.5, "rz": 6.5}]
	ponds = [{"center": Vector2(3.5, -0.7), "r": 1.6}, {"center": Vector2(1.95, 2.6), "r": 1.3},
		# 東邊的小冰洞：被雪人扣頭的工人爬起來再踩一次香蕉皮，就會往這裡滑
		{"center": Vector2(5.0, -4.2), "r": 1.2}]
	snowmen = [Vector3(-1.5, 0, -2.0)]
	pines = [Vector3(-6.0, 0, -12.5), Vector3(6.0, 0, -12.5), Vector3(11.0, 0, -9.0)]
	# ---- 以下都是外觀（不影響玩法）
	# 地圖的輪廓：南邊（鏡頭這一側）收短一點；coves 是岸邊凹進來的小海灣（看得到對面的冰崖）
	isle = {"seed": 1.3, "c": Vector2(0.0, -4.0), "rz": 19.5,
		"coves": [[0.05, 5.0, 0.13], [-1.20, 4.5, 0.12], [-1.98, 4.5, 0.12], [3.40, 4.5, 0.12]]}
	# 裝飾要讓開的路線（工人的紅線）
	clear_paths = [[Vector3(-9.0, 0, -8.0), Vector3(-6.0, 0, -8.0), Vector3(-3.0, 0, -4.0), Vector3(0.0, 0, -2.5)]]
	# 工人的冰釣營地（裝飾）：在他們出發點後面
	camps = [{"pos": Vector3(-14.5, 0, -14.5), "yaw": 0.9}, {"pos": Vector3(13.5, 0, -16.0), "yaw": -0.7}]
	# 冰湖周圍的區域（純裝飾）。高的東西都離冰洞 9 公尺以上：過關特寫的鏡頭會繞著冰洞拍
	zones = [
		# 這一關的地標：西岸的碼頭漁村——伸進湖裡的棧道、三間小屋、拖上岸的漁船
		{"type": "pier", "pos": Vector3(-8.6, 0, 0.0), "yaw": -1.57},
		{"type": "village", "pos": Vector3(-13.6, 0, -3.2), "yaw": 1.57},
		{"type": "boats", "pos": Vector3(-10.8, 0, 4.6), "yaw": 1.2},
		{"type": "crystals", "pos": Vector3(14.5, 0, -9.5)},
		{"type": "crystals", "pos": Vector3(14.0, 0, 2.0)},
		{"type": "creek", "from": Vector3(16.5, 0, -17.0), "to": Vector3(8.6, 0, -5.2)},
	]
