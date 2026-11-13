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
var _door: Node3D             # 籠門（模型版）
var _lock: Node3D             # 門上的鎖
var _lock_drop: Node3D        # 開籠後掉在地上的鎖
var _penguins: Array = []      # {node, home, out, t0}
var _freed := false
var _free_target := Vector3.ZERO
var _free_t := 0.0             # 開籠之後過了幾秒（遊戲時間，由戰局每一步推進）
var _spots := {}
var _free_cam := Vector3.ZERO  # 過關鏡頭的位置：企鵝只站在家豪背後（不擋鏡頭），臉朝鏡頭

func _build_extra() -> void:
	keep_clear.append(cage)
	for p in bird_path:
		keep_clear.append(p)
	super()
	_build_cage()

## 企鵝籠：木頭框＋鐵欄杆（正面欄杆會打開），裡面三隻大企鵝在跳，頭上寫「救我！」
func _build_cage() -> void:
	_cage_root = Node3D.new()
	_cage_root.name = "PenguinCage"
	_cage_root.position = Vector3(cage.x, height_at(cage.x, cage.z), cage.z)
	_cage_root.scale = Vector3.ONE * CAGE_SCALE
	add_child(_cage_root)
	# Blender 做的籠子（籠門 Door 是獨立節點，轉軸在左前角，過關時會轉開）
	var model := _prop(_cage_root, MB + "cage.glb", Vector3.ZERO, 0.0, 1.0)
	if model:
		_door = model.find_child("Door", true, false) as Node3D
		if _door:
			_lock = _door.find_child("Lock", true, false) as Node3D
			var sh := _door.find_child("Shackle", true, false) as Node3D
			if _lock and sh:
				# 掉在地上的鎖（開籠時才出現）：鎖頭＋鎖環的複製品，倒在門前
				_lock_drop = Node3D.new()
				_cage_root.add_child(_lock_drop)
				var a := _lock.duplicate() as Node3D
				var b := sh.duplicate() as Node3D
				_lock_drop.add_child(a)
				_lock_drop.add_child(b)
				a.position = Vector3.ZERO
				b.position = Vector3(0, 0.12, 0)
				_lock_drop.position = Vector3(0.7, 0.08, 1.35)
				_lock_drop.rotation = Vector3(0, 0.6, 1.4)
				_lock_drop.visible = false
				var lk := Node3D.new()
				_lock.get_parent().add_child(lk)
				_lock.reparent(lk)
				sh.reparent(lk)
				_lock = lk
	else:
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
	_cage_label.font_size = 60
	_cage_label.pixel_size = 0.00052
	_cage_label.fixed_size = true   # 固定在畫面上的大小，鏡頭拉近也不會變巨大
	_cage_label.outline_size = 24
	_cage_label.outline_modulate = Color(0, 0, 0, 0.85)
	_cage_label.modulate = Color(1.0, 0.9, 0.3)
	add_child(_cage_label)

## 打開籠子：正面欄杆消失，企鵝跳出來圍著家豪
func open_cage(target: Vector3, cam := Vector3.ZERO) -> void:
	_freed = true
	_free_target = target
	_free_cam = cam
	_free_t = 0.0
	_pick_spots()
	for b in _front_bars:
		(b as Node3D).visible = false
	_cage_label.text = "謝謝家豪！"
	_cage_label.font_size = 48

## 開籠動畫往前推一步（戰局每 1/60 秒呼叫一次）
func tick_cage(dt: float) -> void:
	if _freed:
		_free_t += dt

func reset_cage() -> void:
	_freed = false
	for b in _front_bars:
		(b as Node3D).visible = true
	if _door:
		_door.rotation.y = 0.0
	if _cage_label:
		_cage_label.text = "救我！"
		_cage_label.font_size = 60
	for p in _penguins:
		(p.node as Node3D).position = p.home

func _process(_dt: float) -> void:
	super(_dt)
	if _cage_label == null:
		return
	var now := Time.get_ticks_msec()
	if not _freed:
		_cage_label.position = _cage_root.position + Vector3(0, 3.0 + sin(now * 0.004) * 0.12, 0)
	if _door:
		# 開籠：籠門往外轉開（0.35 秒）
		# 籠門轉 90 度貼到側邊；鎖掉到地上
		var k := clampf(_free_t / 0.35, 0.0, 1.0)
		_door.rotation.y = PI * 0.5 * k if _freed else 0.0
		if _lock:
			_lock.visible = not _freed
		if _lock_drop:
			_lock_drop.visible = _freed
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
		# 站位：家豪兩旁排成一排（稍微在後面一點，不擋家豪也不擋鏡頭），一隻一隻輪流跳
		var away := _free_target - _free_cam
		away.y = 0.0
		away = away.normalized() if away.length() > 0.1 else Vector3.FORWARD
		var lateral := away.cross(Vector3.UP)
		var spot_w: Vector3 = _spots.get(k, _free_target + lateral * 1.5)
		var around: Vector3 = _cage_root.to_local(spot_w)
		var hop := maxf(sin(_free_t * 7.0 - k * 1.3), 0.0) * 0.35
		if t < 0.45:
			n.position = p.home.lerp(door, t / 0.45) + Vector3(0, hop, 0)
			n.rotation.y = 0.0
		else:
			var s2 := clampf((t - 0.45) / 0.6, 0.0, 1.0)
			n.position = door.lerp(around, s2) + Vector3(0, hop, 0)
			# 臉朝鏡頭
			var to_cam := _cage_root.to_local(_free_cam) - n.position
			n.rotation.y = atan2(to_cam.x, to_cam.z)
		# 收尾小動作：最後一隻企鵝撲倒，用肚子往前滑一段
		if k == 2 and _free_t > 2.4:
			var sl := clampf((_free_t - 2.4) / 0.6, 0.0, 1.0)
			# 往畫面的側邊滑（從鏡頭看是橫著滑過去），仰躺露出白肚子
			var to_cam := (_cage_root.to_local(_free_cam) - around)
			to_cam.y = 0.0
			to_cam = to_cam.normalized() if to_cam.length() > 0.01 else Vector3.BACK
			var side := to_cam.cross(Vector3.UP)
			n.position = around + side * (sl * 1.6) + Vector3(0, 0.08, 0)
			n.rotation = Vector3(-1.35 * minf(sl * 3.0, 1.0), atan2(to_cam.x, to_cam.z), sin(_free_t * 12.0) * 0.08)
		if k == 1:
			# 「謝謝家豪！」是左邊那隻企鵝說的：跑到定位才開口，字貼在牠頭上
			_cage_label.text = "謝謝家豪！" if t >= 1.1 else ""
			_cage_label.position = _cage_root.to_global(n.position) + Vector3(0, 1.75, 0)

## 企鵝的站位（開籠時算一次）：固定在家豪左、右、更左邊（以鏡頭看過去的左右），只避開水
func _pick_spots() -> void:
	_spots.clear()
	var away := _free_target - _free_cam
	away.y = 0.0
	away = away.normalized() if away.length() > 0.1 else Vector3.FORWARD
	var right := away.cross(Vector3.UP)    # 畫面右邊
	var want: Array = [-1.6, 1.6, -2.4]
	var back: Array = [0.3, 0.3, 2.6]     # 第三隻站後面一點，三隻不會疊在一起
	for k in 3:
		var q: Vector3 = _free_target + right * float(want[k]) + away * float(back[k])
		if in_water(q.x, q.z):
			q = _free_target - right * float(want[k]) + away * 0.3
		_spots[k] = q
