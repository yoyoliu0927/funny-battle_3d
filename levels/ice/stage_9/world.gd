extends "res://levels/ice/rescue_world.gd"
## 【救企鵝 1】家豪從南邊直直走到北岸的籠子。工人從西北角衝出來，路線有三段：
##   第一段在雪地上（只會跌倒）；第二段看起來對著一個冰洞，但中間有雪人擋著；最後一段才真的對著另一個冰洞。

func _ice_configure() -> void:
	play_min = Vector2(-20.0, -23.0)
	play_max = Vector2(20.0, 18.0)
	hero_start = Vector3(0.0, 0.0, 9.5)
	# 鏡頭：家豪在畫面下方約 3/4 高、冰湖在中間、遠處看得到島緣和天空（camera_look 的 y 只用來調俯角）
	camera_start = Vector3(0.5, 8.3, 16.5)
	camera_look = Vector3(0.5, -2.95, -1.5)
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
	isle = {"seed": 1.3, "c": Vector2(0.0, -4.0), "rz": 19.5}   # 地圖的輪廓：南邊（鏡頭這一側）收短一點，其他照遊玩範圍
	# 裝飾要讓開的路線（工人的紅線）
	clear_paths = [[Vector3(-9.0, 0, -8.0), Vector3(-6.0, 0, -8.0), Vector3(-3.0, 0, -4.0), Vector3(0.0, 0, -2.5)]]
	# 工人的冰釣營地（裝飾）：在他們出發點後面
	camps = [{"pos": Vector3(-14.5, 0, -14.5), "yaw": 0.9}, {"pos": Vector3(13.5, 0, -16.0), "yaw": -0.7}]
	# 冰湖周圍的區域（純裝飾）：讓整張地圖都有東西看，不只中間一個湖
	# （冰晶、冰雕、小屋這些高的東西都離冰洞 9 公尺以上：過關特寫的鏡頭會繞著冰洞拍）
	zones = [
		{"type": "village", "pos": Vector3(14.5, 0, 1.0), "yaw": -1.57},
		{"type": "pier", "pos": Vector3(-8.6, 0, 0.0), "yaw": -1.57},
		{"type": "crystals", "pos": Vector3(14.5, 0, -9.5)},
		{"type": "crystals", "pos": Vector3(-13.5, 0, 6.5)},
		{"type": "sculptures", "pos": Vector3(9.0, 0, 9.5), "yaw": 0.0},
		{"type": "creek", "from": Vector3(16.5, 0, -17.0), "to": Vector3(8.6, 0, -5.2)},
	]
