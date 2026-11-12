extends "res://levels/ice/ice_world.gd"
## 【實驗 A1】冰上撞球：一個工人、一個冰洞（球袋）。

func _ice_configure() -> void:
	play_min = Vector2(-13.0, -13.0)
	play_max = Vector2(13.0, 14.0)
	hero_start = Vector3(0.0, 0.0, 10.0)
	camera_start = Vector3(-3.0, 10.0, 13.0)
	camera_look = Vector3(1.0, 0.0, -2.0)
	lakes = [{"center": Vector2(0.0, -2.0), "rx": 10.0, "rz": 7.0}]
	ponds = [{"center": Vector2(6.0, -2.5), "r": 1.8}]
	snowmen = [Vector3(-9.0, 0, 9.5)]
	pines = [Vector3(-11.0, 0, -10.5), Vector3(-6.0, 0, -11.5), Vector3(8.0, 0, -11.0), Vector3(11.5, 0, -5.0)]
