extends "res://levels/ice/ice_world.gd"
## 【救企鵝】場地：冰雪島的地形，加上關企鵝的籠子和家豪要走的路線。
## 小關的 world.gd 寫 extends "res://levels/ice/rescue_world.gd"，在 _ice_configure() 設定 cage 和 bird_path。

## 企鵝籠的位置
var cage := Vector3(0.0, 0.0, -11.0)
## 家豪要走的路線（從出生點到籠子前），家豪會照順序走過每個點
var bird_path: Array = []

const CAGE_SCALE := 1.4
const UISkin := preload("res://scripts/ui/ui_style.gd")

var _cage_root: Node3D
var _cage_label: Label3D
const LABEL_SIZE := 32         # 「救我！」的字級（泡泡會跟著字的大小畫）
const LABEL_PIXEL := 0.00076   # 字在螢幕上的大小：主鏡頭（視角 45 度）下大約 24 px 高。_process 會照現在鏡頭的視角換算，特寫、結算也差不多這麼大
var _front_bars: Array = []    # （舊版用方塊拼的欄杆；現在籠子是模型，這個陣列是空的）
var _door: Node3D             # 籠門（模型版）
var _lock: Node3D             # 門上的鎖
var _lock_drop: Node3D        # 開籠後掉在地上的鎖
var _penguins: Array = []      # {node, home, out, t0}
var _freed := false
var _free_target := Vector3.ZERO
var _free_t := 0.0             # 開籠之後過了幾秒（遊戲時間，由戰局每一步推進）
var _spots := {}
var _free_cam := Vector3.ZERO  # 過關鏡頭的位置：企鵝只站在家豪背後（不擋鏡頭），臉朝鏡頭
var _slide_trail: Decal        # 滑出去的那隻企鵝在雪地上拖出來的痕跡
var _finale_cheer := false     # 全章收尾：三隻都面向鏡頭歡呼

func _build_extra() -> void:
	keep_clear.append(cage)
	for p in bird_path:
		keep_clear.append(p)
	super()
	_build_cage()

## 企鵝籠（Blender 模型：木頭框＋鐵欄杆，籠門會轉開），裡面三隻大企鵝在跳，頭上寫「救我！」
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
				b.position = Vector3(0, 0.27, 0)
				_lock_drop.position = Vector3(0.7, 0.08, 1.35)
				_lock_drop.rotation = Vector3(0, 0.6, 1.4)
				_lock_drop.visible = false
				var lk := Node3D.new()
				_lock.get_parent().add_child(lk)
				_lock.reparent(lk)
				sh.reparent(lk)
				_lock = lk
	# 三隻方塊企鵝（Kenney Cube Pets）擠在籠子前半邊，從主鏡頭看得到臉
	for k in 3:
		var home := Vector3(-0.72 + k * 0.72, 0.19, 0.30 - 0.22 * (k % 2))
		var p := make_penguin(_cage_root, Vector3.ZERO, 0.2 * (k - 1))
		p.position = home
		p.scale = Vector3.ONE * 0.9
		_penguins.append({"node": p, "home": home, "k": k, "wl": p.find_child("wing-left", true, false), "wr": p.find_child("wing-right", true, false)})
	# 籠子裡補一盞柔光：屋頂底下才不會黑成一片，看不到企鵝的臉
	var fill := OmniLight3D.new()
	fill.light_color = Color(0.95, 0.97, 1.0)
	fill.light_energy = 0.9
	fill.omni_range = 3.2
	fill.light_specular = 0.0
	fill.position = Vector3(0, 1.0, 1.3)
	_cage_root.add_child(fill)
	_blob_shadow(self, _cage_root.position, 2.9, 0.55)
	obstacles.append([Vector2(cage.x, cage.z), 1.3 * CAGE_SCALE])
	_cage_label = Label3D.new()
	_cage_label.text = "救我！"
	_cage_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_cage_label.no_depth_test = true
	_cage_label.font_size = LABEL_SIZE
	_cage_label.pixel_size = 0.00052
	_cage_label.fixed_size = true   # 固定在畫面上的大小，鏡頭拉近也不會變巨大
	add_child(_cage_label)
	# 白色的對話泡泡（跟家豪的對話框同一套），不是紅底的牌子
	UISkin.plate(_cage_label, "bubble")

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
	_cage_label.font_size = LABEL_SIZE + 2
	for p in _penguins:
		penguin_anim(p.node, "")        # 出籠後的姿勢由下面的程式擺（面向鏡頭、舉手、上下跳），不播模型自己的動畫

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
		_cage_label.font_size = LABEL_SIZE
	for p in _penguins:
		(p.node as Node3D).position = p.home
		(p.node as Node3D).rotation = Vector3(0, 0.2 * (int(p.k) - 1), 0)
		_wings(p, 0.0)
		penguin_anim(p.node, "idle")
	if _slide_trail:
		_slide_trail.visible = false

## 全章收尾（見 ice_world.gd 的 finale_show）：加上三隻企鵝面向鏡頭歡呼
func finale_show(on: bool) -> void:
	super(on)
	_finale_cheer = on

## 企鵝的翅膀舉多高（0 = 垂著，1 = 舉手歡呼）
func _wings(p: Dictionary, up: float) -> void:
	if p.get("wl"):
		(p.wl as Node3D).rotation.z = 1.0 * up
	if p.get("wr"):
		(p.wr as Node3D).rotation.z = -1.0 * up

func _process(_dt: float) -> void:
	super(_dt)
	if _cage_label == null:
		return
	var now := Time.get_ticks_msec()
	var cam := get_viewport().get_camera_3d()
	if cam:
		# 標籤在螢幕上維持差不多的大小：視角越寬（特寫、結算鏡頭）字會被畫得越小，照視角補回來
		var ps := LABEL_PIXEL * tan(deg_to_rad(cam.fov * 0.5)) / tan(deg_to_rad(22.5))
		_cage_label.pixel_size = ps
		var plate := _cage_label.get_node_or_null("Plate") as Sprite3D
		if plate:
			plate.pixel_size = ps
	UISkin.refresh(_cage_label)          # 字變了泡泡要重畫
	if not _freed:
		_cage_label.position = _cage_root.position + Vector3(0, 3.75 + sin(now * 0.004) * 0.12, 0)
	if _door:
		# 開籠：籠門往外轉開（0.35 秒）
		# 籠門轉 90 度貼到側邊；鎖掉到地上
		var k := clampf(_free_t / 0.35, 0.0, 1.0)
		_door.rotation.y = PI * 0.5 * k if _freed else 0.0
		if _lock:
			_lock.visible = not _freed
		if _lock_drop:
			_lock_drop.visible = _freed
	# 企鵝要面向「現在這個鏡頭」（過關後鏡頭會換位置，不能只記開籠那一刻的）
	var cam_local := _cage_root.to_local(cam.global_position if cam else _free_cam)
	for p in _penguins:
		var n := p.node as Node3D
		var k: int = p.k
		if not _freed:
			# 在籠子裡跳上跳下求救（身體只微微晃，不會歪到像倒了）
			n.position = p.home + Vector3(0, absf(sin(now * 0.008 + k * 1.7)) * 0.12, 0)
			n.rotation = Vector3(0, 0.2 * (k - 1), sin(now * 0.012 + k) * 0.10)
			continue
		# 一隻接一隻：先走到籠門口，再跑到家豪身邊，面向鏡頭舉手上下跳
		var t := maxf(_free_t - k * 0.2, 0.0)
		var door: Vector3 = Vector3(p.home.x * 0.6, 0.0, 1.35)
		# 站位：家豪兩旁排成一排（稍微在後面一點，不擋家豪也不擋鏡頭），一隻一隻輪流跳
		var away := _free_target - _free_cam
		away.y = 0.0
		away = away.normalized() if away.length() > 0.1 else Vector3.FORWARD
		var lateral := away.cross(Vector3.UP)
		var spot_w: Vector3 = _spots.get(k, _free_target + lateral * 1.5)
		var around: Vector3 = _cage_root.to_local(spot_w)
		var hop := maxf(sin(_free_t * 7.0 - k * 1.3), 0.0) * (0.45 if _finale_cheer else 0.32)
		if t < 0.45:
			n.position = p.home.lerp(door, t / 0.45) + Vector3(0, hop, 0)
			n.rotation = Vector3.ZERO
			_wings(p, 0.3)
		else:
			var s2 := clampf((t - 0.45) / 0.6, 0.0, 1.0)
			n.position = door.lerp(around, s2) + Vector3(0, hop, 0)
			var to_cam := cam_local - n.position
			n.rotation = Vector3(0, atan2(to_cam.x, to_cam.z), 0)          # 站得直直的，臉朝鏡頭
			_wings(p, 0.85 + 0.25 * sin(_free_t * 9.0 + k * 2.0))
		# 收尾小動作：最後一隻企鵝往旁邊溜出去（站得直直地滑），雪地上拖一道痕跡
		if k == 2 and _free_t > 2.4 and not _finale_cheer:
			var sl := clampf((_free_t - 2.4) / 0.7, 0.0, 1.0)
			var to_cam := cam_local - around
			to_cam.y = 0.0
			to_cam = to_cam.normalized() if to_cam.length() > 0.01 else Vector3.BACK
			var side := to_cam.cross(Vector3.UP)
			var ease_k := 1.0 - (1.0 - sl) * (1.0 - sl)
			n.position = around + side * (ease_k * 2.4)
			n.rotation = Vector3(0, atan2(to_cam.x, to_cam.z), 0)
			_wings(p, 0.6)
			_trail_between(_cage_root.to_global(around), _cage_root.to_global(n.position))
		if k == 1:
			# 「謝謝家豪！」是左邊那隻企鵝說的：跑到定位才開口，字貼在牠頭上
			_cage_label.text = "謝謝家豪！" if (t >= 1.1 and not _finale_cheer) else ""     # 收尾的大遠景不放對話框
			_cage_label.position = _cage_root.to_global(n.position) + Vector3(0, 2.0, 0)

## 企鵝滑過去在雪地上留下的痕跡（一張拉長的軟陰影貼在地上，從起點拉到現在的位置）
func _trail_between(a: Vector3, b: Vector3) -> void:
	if _slide_trail == null:
		_slide_trail = Decal.new()
		_slide_trail.texture_albedo = load(TX + "shadow_blob.png")
		_slide_trail.albedo_mix = 0.55
		add_child(_slide_trail)
	var d := b - a
	d.y = 0.0
	var length := maxf(d.length(), 0.05)
	_slide_trail.visible = true
	_slide_trail.size = Vector3(1.0, 1.2, length + 0.8)
	_slide_trail.global_position = (a + b) * 0.5
	_slide_trail.rotation.y = atan2(d.x, d.z)

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
