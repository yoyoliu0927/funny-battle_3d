extends "res://levels/ice/ice_world.gd"
## 3-2 薄冰：兩個守衛在湖上冰釣，湖面有幾塊薄冰（顏色比較白、有裂痕）。企鵝被關在北岸的籠子裡。

var cage := Vector3(0.0, 0.0, -11.8)   # 企鵝籠的位置（戰局會讀）

func _ice_configure() -> void:
	play_min = Vector2(-13.0, -14.0)
	play_max = Vector2(13.0, 14.0)
	hero_start = Vector3(0.0, 0.0, 11.0)
	camera_start = Vector3(8.0, 10.0, 14.0)
	camera_look = Vector3(0.0, 0.0, -4.0)
	lakes = [{"center": Vector2(0.0, -2.0), "rx": 11.0, "rz": 7.0}]
	thin_spots = [
		{"center": Vector2(-6.0, -2.0), "r": 1.5},
		{"center": Vector2(5.5, -2.5), "r": 1.5},
		{"center": Vector2(-1.5, 2.5), "r": 1.3},
	]
	snowmen = [Vector3(-9.0, 0, 9.5), Vector3(9.5, 0, 9.0)]
	pines = [Vector3(-11.0, 0, -11.0), Vector3(-6.5, 0, -12.5), Vector3(7.0, 0, -12.5), Vector3(11.0, 0, -9.0), Vector3(11.5, 0, 5.0)]

func _build_extra() -> void:
	super()
	_build_cage()

## 企鵝籠：木頭框＋鐵欄杆，裡面三隻企鵝
func _build_cage() -> void:
	var root := Node3D.new()
	root.name = "PenguinCage"
	root.position = Vector3(cage.x, height_at(cage.x, cage.z), cage.z)
	add_child(root)
	var wood := _toon(Color(0.55, 0.38, 0.24))
	var bar := _toon(Color(0.35, 0.38, 0.42))
	_box(root, Vector3(2.6, 0.15, 2.0), Vector3(0, 0.07, 0), wood)
	_box(root, Vector3(2.6, 0.15, 2.0), Vector3(0, 1.45, 0), wood)
	for i in 9:
		var x := -1.2 + i * 0.3
		_box(root, Vector3(0.06, 1.4, 0.06), Vector3(x, 0.75, 0.95), bar)
		_box(root, Vector3(0.06, 1.4, 0.06), Vector3(x, 0.75, -0.95), bar)
	for i in 6:
		var z := -0.9 + i * 0.36
		_box(root, Vector3(0.06, 1.4, 0.06), Vector3(1.25, 0.75, z), bar)
		_box(root, Vector3(0.06, 1.4, 0.06), Vector3(-1.25, 0.75, z), bar)
	for k in 3:
		make_penguin(root, Vector3(-0.6 + k * 0.6, 0, 0.1 * k) + root.position, 0.2 * (k - 1))
	obstacles.append([Vector2(cage.x, cage.z), 1.3])
