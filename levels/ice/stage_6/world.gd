extends "res://levels/ice/ice_world.gd"
## 【實驗 A2】連環撞：三個工人、兩個冰洞、一塊薄冰。

func _ice_configure() -> void:
	play_min = Vector2(-13.0, -13.0)
	play_max = Vector2(13.0, 14.0)
	hero_start = Vector3(0.0, 0.0, 10.0)
	camera_start = Vector3(0.0, 12.0, 14.0)
	camera_look = Vector3(0.0, 0.0, -2.0)
	lakes = [{"center": Vector2(0.0, -2.0), "rx": 11.0, "rz": 7.5}]
	ponds = [{"center": Vector2(7.5, -1.5), "r": 1.4}, {"center": Vector2(-7.0, -5.0), "r": 1.3}]
	thin_spots = [{"center": Vector2(0.0, -8.0), "r": 1.3}]
	snowmen = [Vector3(9.5, 0, 9.0), Vector3(-10.0, 0, 9.0)]
	pines = [Vector3(-11.5, 0, -11.0), Vector3(-4.0, 0, -12.0), Vector3(5.0, 0, -12.0), Vector3(11.5, 0, -10.0)]
