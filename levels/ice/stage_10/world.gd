extends "res://levels/ice/rescue_world.gd"
## 【救企鵝 2】守衛站在家豪的路上不動（香蕉皮對他沒用）。另一個工人從西邊衝過來，
## 他第一段路線的延長線剛好穿過守衛，再過去就是冰洞：一片香蕉皮撞兩個。

func _ice_configure() -> void:
	play_min = Vector2(-20.0, -23.0)
	play_max = Vector2(20.0, 18.0)
	hero_start = Vector3(-6.0, 0.0, 9.5)
	camera_start = Vector3(-1.5, 12.5, 16.0)
	camera_look = Vector3(-1.0, 0.0, -1.0)
	mood = "sunset"
	cage = Vector3(4.0, 0.0, -11.8)
	bird_path = [Vector3(-6.0, 0, 1.0), Vector3(1.0, 0, -5.0), Vector3(4.0, 0, -9.0)]
	lakes = [{"center": Vector2(0.0, -2.5), "rx": 10.5, "rz": 7.0}]
	ponds = [{"center": Vector2(7.5, -6.8), "r": 1.5}]
	snowmen = []
	# 冰湖北岸的雪堆：在第二段被香蕉皮滑出去的工人，會一頭栽進去只露出兩條腿
	snow_piles = [Vector3(-0.6, 0, 6.0)]
	pines = [Vector3(-5.5, 0, -12.5), Vector3(10.5, 0, -11.5), Vector3(11.5, 0, 2.0)]
	# 工人的冰釣營地（裝飾）：在他們出發點後面
	camps = [{"pos": Vector3(-15.0, 0, -12.5), "yaw": 1.0}, {"pos": Vector3(13.5, 0, -16.5), "yaw": -0.6}]
	# 冰湖周圍的區域（純裝飾）：讓整張地圖都有東西看，不只中間一個湖
	zones = [
		{"type": "village", "pos": Vector3(14.0, 0, 0.5), "yaw": -1.57},
		{"type": "pier", "pos": Vector3(9.0, 0, 3.6), "yaw": 1.57},
		{"type": "crystals", "pos": Vector3(-13.0, 0, 5.0)},
		{"type": "crystals", "pos": Vector3(12.5, 0, -9.5)},
		{"type": "sculptures", "pos": Vector3(4.5, 0, 9.5), "yaw": 0.0},
		{"type": "creek", "from": Vector3(-15.0, 0, 11.0), "to": Vector3(-9.0, 0, 2.0)},
	]
