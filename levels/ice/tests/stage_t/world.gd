extends "res://levels/ice/rescue_world.gd"
## 測試用的臨時場地：設定從 Engine 的 meta "ice_test" 讀（mechanics.gd 每個檢查項目各給一份）。不列進 chapter.gd。

## 沒給設定時的樣子（拍分鏡用）：照規格第 3 關「薄冰」的座標排
const DEMO := {"hero": Vector3(3.0, 0, 2.4), "path": [Vector3(3.0, 0, -9.4)], "cage": Vector3(3.0, 0, -11.8),
	"lakes": [{"center": Vector2(0.0, -2.5), "rx": 10.5, "rz": 7.0}],
	"thin": [{"center": Vector2(3.0, 2.4), "r": 1.6}, {"center": Vector2(5.1, -5.15), "r": 1.1}],
	"pines": [Vector3(-5.5, 0, -12.5), Vector3(10.5, 0, -11.5), Vector3(11.5, 0, 2.0)],
	"items": [["banana", 1], ["feed", 1]],
	"enemies": [["rusher", "阿土", Vector3(4.9, 0, 2.4), [Vector3(3.3, 0, 2.4)]], ["rusher", "阿水", Vector3(0.8, 0, -11.3), [Vector3(2.8, 0, -2.0)]],
		["guard", "守衛", Vector3(4.5, 0, -6.5)]],
	"stars": ["guard_thin", "pair_hole"], "flags": {"preview_full": false, "chase_avoids_holes": true}}

func _ice_configure() -> void:
	var c: Dictionary = Engine.get_meta("ice_test", DEMO)
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
