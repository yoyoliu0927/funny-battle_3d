extends "res://levels/ice/ice_world.gd"
## 3-1 冰湖（教學）：結冰的湖中間有一個冰釣的洞，兩個工人在冰上釣魚。

func _ice_configure() -> void:
	play_min = Vector2(-13.0, -13.0)
	play_max = Vector2(13.0, 14.0)
	hero_start = Vector3(0.0, 0.0, 11.0)
	camera_start = Vector3(7.0, 9.0, 15.0)
	camera_look = Vector3(-1.0, 0.0, -2.0)
	lakes = [{"center": Vector2(0.0, -1.5), "rx": 10.0, "rz": 7.5}]
	ponds = [{"center": Vector2(3.5, -1.5), "r": 1.5}]
	snowmen = [Vector3(-9.0, 0, 9.5), Vector3(10.0, 0, 10.0)]
	pines = [Vector3(-11.0, 0, -10.0), Vector3(-6.0, 0, -11.5), Vector3(8.0, 0, -11.0), Vector3(11.5, 0, -6.0), Vector3(-11.5, 0, 4.0)]
