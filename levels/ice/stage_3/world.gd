extends "res://levels/ice/ice_world.gd"
## 3-3 鹽：一整片厚冰，沒有現成的陷阱。用鹽自己做薄冰。

func _ice_configure() -> void:
	play_min = Vector2(-13.0, -13.0)
	play_max = Vector2(13.0, 14.0)
	hero_start = Vector3(0.0, 0.0, 11.0)
	camera_start = Vector3(-8.0, 10.0, 14.0)
	camera_look = Vector3(0.0, 0.0, -3.0)
	lakes = [{"center": Vector2(0.0, -2.0), "rx": 11.5, "rz": 8.0}]
	snowmen = [Vector3(9.0, 0, 9.0), Vector3(-10.0, 0, 9.5)]
	pines = [Vector3(-11.5, 0, -11.0), Vector3(-5.0, 0, -12.0), Vector3(5.5, 0, -12.0), Vector3(11.5, 0, -10.5)]
