extends "res://levels/ice/rescue_world.gd"
## 【救企鵝 1】家豪從南邊直直走到北岸的籠子。工人從西北角衝出來，路線有三段：
##   第一段在雪地上（只會跌倒）；第二段看起來對著一個冰洞，但中間有雪人擋著；最後一段才真的對著另一個冰洞。

func _ice_configure() -> void:
	play_min = Vector2(-20.0, -23.0)
	play_max = Vector2(20.0, 18.0)
	hero_start = Vector3(0.0, 0.0, 9.5)
	camera_start = Vector3(1.5, 12.0, 15.5)
	camera_look = Vector3(1.0, 0.0, -1.5)
	mood = "morning"
	cage = Vector3(0.0, 0.0, -11.6)
	bird_path = [Vector3(0.0, 0, 6.0), Vector3(0.0, 0, -9.2)]
	lakes = [{"center": Vector2(0.0, -1.5), "rx": 9.5, "rz": 6.5}]
	ponds = [{"center": Vector2(3.5, -0.7), "r": 1.6}, {"center": Vector2(1.95, 2.6), "r": 1.3},
		# 東邊的小冰洞：被雪人扣頭的工人爬起來再踩一次香蕉皮，就會往這裡滑
		{"center": Vector2(5.0, -4.2), "r": 1.2}]
	snowmen = [Vector3(-1.5, 0, -2.0)]
	pines = [Vector3(-6.0, 0, -12.5), Vector3(6.0, 0, -12.5), Vector3(11.0, 0, -9.0)]
	# 工人的冰釣營地（裝飾）：在他們出發點後面
	camps = [{"pos": Vector3(-14.5, 0, -14.5), "yaw": 0.9}, {"pos": Vector3(13.5, 0, -16.0), "yaw": -0.7}]
	# 冰湖周圍的區域（純裝飾）：讓整張地圖都有東西看，不只中間一個湖
	zones = [
		{"type": "village", "pos": Vector3(13.0, 0, 1.0), "yaw": -1.57},
		{"type": "pier", "pos": Vector3(-8.6, 0, 0.0), "yaw": -1.57},
		{"type": "crystals", "pos": Vector3(11.5, 0, -8.5)},
		{"type": "crystals", "pos": Vector3(-12.5, 0, 6.5)},
		{"type": "sculptures", "pos": Vector3(6.5, 0, 9.0), "yaw": 0.0},
		{"type": "creek", "from": Vector3(14.0, 0, -13.0), "to": Vector3(8.6, 0, -5.2)},
	]
