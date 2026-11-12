extends "res://levels/ice/rescue_world.gd"
## 【救企鵝 1】冰湖：家豪從南邊直直走過冰湖到北岸的籠子。工人在西岸，會往東衝過來攔；他衝的方向再過去就是冰洞。

func _ice_configure() -> void:
	play_min = Vector2(-13.0, -14.0)
	play_max = Vector2(13.0, 14.0)
	hero_start = Vector3(0.0, 0.0, 11.0)
	camera_start = Vector3(-6.0, 11.0, 12.0)
	camera_look = Vector3(1.0, 0.0, -2.0)
	cage = Vector3(0.0, 0.0, -11.5)
	bird_path = [Vector3(0.0, 0, 6.0), Vector3(0.0, 0, -9.6)]
	lakes = [{"center": Vector2(0.0, -1.5), "rx": 9.5, "rz": 6.5}]
	ponds = [{"center": Vector2(5.5, 2.0), "r": 1.8}]
	snowmen = [Vector3(-9.0, 0, 9.5), Vector3(9.5, 0, 9.0)]
	pines = [Vector3(-11.0, 0, -11.5), Vector3(-5.5, 0, -12.5), Vector3(5.5, 0, -12.5), Vector3(11.0, 0, -9.0)]
