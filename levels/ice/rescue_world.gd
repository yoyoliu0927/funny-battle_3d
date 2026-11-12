extends "res://levels/ice/ice_world.gd"
## 【救企鵝】場地：冰雪島的地形，加上關企鵝的籠子和家豪要走的路線。
## 小關的 world.gd 寫 extends "res://levels/ice/rescue_world.gd"，在 _ice_configure() 設定 cage 和 bird_path。

## 企鵝籠的位置
var cage := Vector3(0.0, 0.0, -11.0)
## 家豪要走的路線（從出生點到籠子前），家豪會照順序走過每個點
var bird_path: Array = []

var _cage_label: Label3D

func _build_extra() -> void:
	super()
	_build_cage()

## 企鵝籠：木頭框＋鐵欄杆，裡面三隻企鵝，頭上寫「救我！」
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
	_cage_label = Label3D.new()
	_cage_label.text = "救我！"
	_cage_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_cage_label.no_depth_test = true
	_cage_label.font_size = 96
	_cage_label.pixel_size = 0.012
	_cage_label.outline_size = 22
	_cage_label.outline_modulate = Color(0, 0, 0, 0.85)
	_cage_label.modulate = Color(1.0, 0.9, 0.3)
	_cage_label.position = root.position + Vector3(0, 3.0, 0)
	add_child(_cage_label)

func _process(_dt: float) -> void:
	if _cage_label:
		_cage_label.position.y = height_at(cage.x, cage.z) + 3.0 + sin(Time.get_ticks_msec() * 0.004) * 0.15
