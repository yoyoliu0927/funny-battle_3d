extends "res://levels/ice/rescue_world.gd"
## 測試用的臨時場地：設定從 Engine 的 meta "ice_test" 讀（mechanics.gd 每個檢查項目各給一份）。不列進 chapter.gd。

func _ice_configure() -> void:
	var c: Dictionary = Engine.get_meta("ice_test", {})
	play_min = Vector2(-20.0, -23.0)
	play_max = Vector2(20.0, 18.0)
	hero_start = c.get("hero", Vector3(0, 0, 8))
	camera_start = Vector3(-1.5, 11.0, 20.3)
	camera_look = Vector3(-1.0, -2.7, -1.6)
	camera_fov = 45.0
	mood = "morning"
	cage = c.get("cage", Vector3(0, 0, -11.8))
	bird_path = c.get("path", [Vector3(0, 0, 5), Vector3(0, 0, -9.4)])
	lakes = c.get("lakes", [{"center": Vector2(0.0, -2.5), "rx": 12.0, "rz": 8.0}])
	ponds = c.get("ponds", [])
	thin_spots = c.get("thin", [])
	snowmen = c.get("snowmen", [])
	snow_piles = c.get("piles", [])
	pines = c.get("pines", [])
	front_props = false
	camps = []
	zones = []
