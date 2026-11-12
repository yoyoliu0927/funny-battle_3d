extends "res://levels/ice/ice_world.gd"
## 冰湖（路線版）：結冰的湖上有兩個冰洞，工人站在北岸。

func _ice_configure() -> void:
	play_min = Vector2(-13.0, -14.0)
	play_max = Vector2(13.0, 14.0)
	hero_start = Vector3(0.0, 0.0, 10.0)
	camera_start = Vector3(7.0, 10.0, 14.0)
	camera_look = Vector3(-1.0, 0.0, -2.0)
	lakes = [{"center": Vector2(0.0, -1.5), "rx": 10.0, "rz": 7.5}]
	ponds = [{"center": Vector2(3.5, -1.5), "r": 1.5}, {"center": Vector2(-4.5, -3.5), "r": 1.3}]
	snowmen = [Vector3(-9.0, 0, 9.5), Vector3(10.0, 0, 10.0)]
	pines = [Vector3(-11.0, 0, -11.5), Vector3(-7.0, 0, -12.5), Vector3(8.0, 0, -12.0), Vector3(11.5, 0, -6.0), Vector3(-11.5, 0, 4.0)]
