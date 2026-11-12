extends "res://levels/ice/rescue_world.gd"
## 【救企鵝 2】兩個工人從東西兩岸衝過來攔家豪。兩個冰洞各在一條衝刺線的盡頭，籠子前還有一塊薄冰。

func _ice_configure() -> void:
	play_min = Vector2(-13.0, -14.0)
	play_max = Vector2(13.0, 14.0)
	hero_start = Vector3(-6.0, 0.0, 11.0)
	camera_start = Vector3(-9.0, 12.0, 11.0)
	camera_look = Vector3(1.0, 0.0, -3.0)
	cage = Vector3(5.0, 0.0, -11.5)
	bird_path = [Vector3(-6.0, 0, 4.0), Vector3(0.0, 0, -3.0), Vector3(5.0, 0, -9.6)]
	lakes = [{"center": Vector2(0.0, -2.5), "rx": 10.5, "rz": 7.0}]
	ponds = [{"center": Vector2(1.0, 2.4), "r": 1.5}, {"center": Vector2(-4.3, -1.6), "r": 1.5}]
	thin_spots = [{"center": Vector2(2.6, -7.0), "r": 1.2}]
	snowmen = [Vector3(9.5, 0, 9.0)]
	pines = [Vector3(-11.0, 0, -11.5), Vector3(-5.5, 0, -12.5), Vector3(10.5, 0, -11.5), Vector3(11.5, 0, -6.0)]
