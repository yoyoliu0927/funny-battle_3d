extends "res://levels/ice/ice_world.gd"
## 【救企鵝】場地：冰雪島的地形，加上關企鵝的籠子和家豪要走的路線。
## 小關的 world.gd 寫 extends "res://levels/ice/rescue_world.gd"，在 _ice_configure() 設定 cage 和 bird_path。

## 企鵝籠的位置
var cage := Vector3(0.0, 0.0, -11.0)
## 家豪要走的路線（從出生點到籠子前），家豪會照順序走過每個點
var bird_path: Array = []

const CAGE_SCALE := 1.4

var _cage_root: Node3D
var _cage_label: Label3D
var _front_bars: Array = []
var _penguins: Array = []      # {node, home, out, t0}
var _freed := false
var _free_target := Vector3.ZERO
var _free_t := 0.0             # 開籠之後過了幾秒（遊戲時間，由戰局每一步推進）

func _build_extra() -> void:
	super()
	_build_cage()

## 企鵝籠：木頭框＋鐵欄杆（正面欄杆會打開），裡面三隻大企鵝在跳，頭上寫「救我！」
func _build_cage() -> void:
	_cage_root = Node3D.new()
	_cage_root.name = "PenguinCage"
	_cage_root.position = Vector3(cage.x, height_at(cage.x, cage.z), cage.z)
	_cage_root.scale = Vector3.ONE * CAGE_SCALE
	add_child(_cage_root)
	var wood := _toon(Color(0.55, 0.38, 0.24))
	var bar := _toon(Color(0.35, 0.38, 0.42))
	_box(_cage_root, Vector3(2.6, 0.15, 2.0), Vector3(0, 0.07, 0), wood)
	_box(_cage_root, Vector3(2.6, 0.15, 2.0), Vector3(0, 1.45, 0), wood)
	for i in 9:
		var x := -1.2 + i * 0.3
		_front_bars.append(_box(_cage_root, Vector3(0.05, 1.4, 0.05), Vector3(x, 0.75, 0.95), bar))
		_box(_cage_root, Vector3(0.05, 1.4, 0.05), Vector3(x, 0.75, -0.95), bar)
	for i in 6:
		var z := -0.9 + i * 0.36
		_box(_cage_root, Vector3(0.05, 1.4, 0.05), Vector3(1.25, 0.75, z), bar)
		_box(_cage_root, Vector3(0.05, 1.4, 0.05), Vector3(-1.25, 0.75, z), bar)
	for k in 3:
		var home := Vector3(-0.65 + k * 0.65, 0.15, 0.15 * k)
		var p := make_penguin(_cage_root, Vector3.ZERO, 0.2 * (k - 1))
		p.position = home
		p.scale = Vector3.ONE * 1.2
		_penguins.append({"node": p, "home": home, "k": k})
	obstacles.append([Vector2(cage.x, cage.z), 1.3 * CAGE_SCALE])
	_cage_label = Label3D.new()
	_cage_label.text = "救我！"
	_cage_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_cage_label.no_depth_test = true
	_cage_label.font_size = 96
	_cage_label.pixel_size = 0.00052
	_cage_label.fixed_size = true   # 固定在畫面上的大小，鏡頭拉近也不會變巨大
	_cage_label.outline_size = 24
	_cage_label.outline_modulate = Color(0, 0, 0, 0.85)
	_cage_label.modulate = Color(1.0, 0.9, 0.3)
	add_child(_cage_label)

## 打開籠子：正面欄杆消失，企鵝跳出來圍著家豪
func open_cage(target: Vector3) -> void:
	_freed = true
	_free_target = target
	_free_t = 0.0
	for b in _front_bars:
		(b as Node3D).visible = false
	_cage_label.text = "謝謝家豪！"

## 開籠動畫往前推一步（戰局每 1/60 秒呼叫一次）
func tick_cage(dt: float) -> void:
	if _freed:
		_free_t += dt

func reset_cage() -> void:
	_freed = false
	for b in _front_bars:
		(b as Node3D).visible = true
	if _cage_label:
		_cage_label.text = "救我！"
	for p in _penguins:
		(p.node as Node3D).position = p.home

func _process(_dt: float) -> void:
	if _cage_label == null:
		return
	var now := Time.get_ticks_msec()
	_cage_label.position = _cage_root.position + Vector3(0, 3.0 + sin(now * 0.004) * 0.12, 0)
	for p in _penguins:
		var n := p.node as Node3D
		var k: int = p.k
		if not _freed:
			# 在籠子裡跳上跳下、拍翅膀（求救）
			n.position = p.home + Vector3(0, absf(sin(now * 0.008 + k * 1.7)) * 0.12, 0)
			n.rotation.z = sin(now * 0.012 + k) * 0.25
			continue
		# 一隻接一隻：先走到籠門口，再跑到家豪身邊繞圈圈跳
		var t := maxf(_free_t - k * 0.2, 0.0)
		var door: Vector3 = Vector3(p.home.x * 0.6, 0.0, 1.35)
		var around: Vector3 = _cage_root.to_local(_free_target) + Vector3(cos(k * 2.1 + _free_t * 1.2), 0, sin(k * 2.1 + _free_t * 1.2)) * 1.9
		var hop := absf(sin(_free_t * 9.0 + k)) * 0.3
		if t < 0.45:
			n.position = p.home.lerp(door, t / 0.45) + Vector3(0, hop, 0)
			n.rotation.y = 0.0
		else:
			var s2 := clampf((t - 0.45) / 0.6, 0.0, 1.0)
			n.position = door.lerp(around, s2) + Vector3(0, hop, 0)
			n.rotation.y = _free_t * 3.0 + k
