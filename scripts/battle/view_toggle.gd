extends Node
## 兩種視角快速切換（所有大關共用；按 Tab）：
##   家豪旁邊：平常的幽靈視角（WASD 飄、滑鼠轉），開場就在家豪附近
##   俯看全場：鏡頭飛到場地斜上方看整個場地（像開場預覽的空拍），游標放出來，可以直接點地面放神蹟——當小地圖用
## 從俯看切回來時，鏡頭會飛到家豪「現在」的位置旁邊，所以也是「一鍵回到家豪身邊」。
##
## 用法（battle_base.gd 已經接好；要塞的 fort_battle.gd 也接了）：
##   var vt = preload("res://scripts/battle/view_toggle.gd").new()
##   vt.setup(player, 玩家鏡頭, 取得家豪位置的 Callable, 取得場地範圍的 Callable)
##   add_child(vt)
##   瞄準時：if vt.overview: 用 vt.mouse_ray() 取代準心射線

signal changed(overview: bool)

const FLY_TIME := 0.45           # 切換時鏡頭飛過去的秒數
const HEAD_H := 1.65             # 玩家身體到眼睛（Head）的高度
const OVERVIEW_PITCH := deg_to_rad(58.0)   # 俯看的俯角（90 = 正上方）

var player: Node3D
var player_cam: Camera3D
var hero_pos: Callable           # () -> Vector3：家豪現在在哪
var on_click: Callable           # 俯看時左鍵點地面要做什麼（施放神蹟）
var blocked: Callable            # 回傳 true 時不能切換（關卡的過場正在借鏡頭）
var area: Callable               # () -> Rect2：場地範圍（x, z）
var enabled := true
var overview := false            # 現在是不是俯看
var busy := false                # 鏡頭正在飛

var _cam: Camera3D               # 俯看和飛行時用的鏡頭
var _t := 0.0
var _from: Transform3D
var _to: Transform3D
var _to_overview := false

func setup(p: Node3D, cam: Camera3D, hero: Callable, rect: Callable) -> void:
	player = p
	player_cam = cam
	hero_pos = hero
	area = rect

func _ready() -> void:
	_cam = Camera3D.new()
	_cam.name = "OverviewCam"
	add_child(_cam)

## 切換（Tab）
func toggle() -> void:
	if not enabled or busy or player_cam == null:
		return
	if blocked.is_valid() and blocked.call():
		return
	if overview:
		_fly(_cam.global_transform, hero_pose(), false)
	else:
		_cam.fov = player_cam.fov
		_cam.far = maxf(player_cam.far, 300.0)
		_fly(player_cam.global_transform, overview_pose(), true)

## 直接把幽靈放到家豪旁邊（開場用，不播飛行）
func snap_to_hero() -> void:
	if player == null:
		return
	_place_player(hero_pose())

## 俯看的鏡頭位置：從場地南邊斜上方，整個範圍剛好裝進畫面
func overview_pose() -> Transform3D:
	var r: Rect2 = area.call()
	var c := Vector3(r.get_center().x, 0.0, r.get_center().y)
	var half := maxf(r.size.x * 0.5, r.size.y * 0.62)
	var fov := deg_to_rad(_cam.fov if _cam else 70.0)
	var dist := half / tan(fov * 0.5) * 1.05 + 6.0
	var eye := c + Vector3(0.0, sin(OVERVIEW_PITCH), cos(OVERVIEW_PITCH)) * dist
	return Transform3D(Basis.looking_at(c - eye, Vector3.UP), eye)

## 家豪旁邊的鏡頭位置：在家豪和場地中心連線的外側、稍微高一點，看著家豪和他前方
func hero_pose() -> Transform3D:
	var h: Vector3 = hero_pos.call()
	var r: Rect2 = area.call()
	var c := Vector3(r.get_center().x, h.y, r.get_center().y)
	var out := h - c
	out.y = 0.0
	if out.length() < 0.5:
		out = Vector3(0, 0, 1)
	out = out.normalized()
	var eye := h + out * 4.5 + Vector3(0, 3.2, 0)
	var look := h + (c - h).normalized() * 2.0 + Vector3(0, 0.6, 0)
	return Transform3D(Basis.looking_at(look - eye, Vector3.UP), eye)

## 俯看時：從滑鼠位置打出去的射線 [起點, 方向]
func mouse_ray() -> Array:
	var mp := _cam.get_viewport().get_mouse_position()
	return [_cam.project_ray_origin(mp), _cam.project_ray_normal(mp)]

func _unhandled_input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_TAB:
		toggle()
		get_viewport().set_input_as_handled()
	elif overview and not busy and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if on_click.is_valid():
			on_click.call()
		get_viewport().set_input_as_handled()

func _fly(from: Transform3D, to: Transform3D, to_overview: bool) -> void:
	busy = true
	_t = 0.0
	_from = from
	_to = to
	_to_overview = to_overview
	_cam.global_transform = from
	_cam.make_current()
	_freeze_player(true)

func _process(dt: float) -> void:
	if busy:
		_t += dt
		var k := clampf(_t / FLY_TIME, 0.0, 1.0)
		var e := k * k * (3.0 - 2.0 * k)
		_cam.global_transform = Transform3D(_from.basis.slerp(_to.basis, e).orthonormalized(), _from.origin.lerp(_to.origin, e))
		if k >= 1.0:
			busy = false
			overview = _to_overview
			if overview:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			else:
				_place_player(_to)
				player_cam.make_current()
				_freeze_player(false)
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			changed.emit(overview)
	elif overview and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not get_tree().paused:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE   # 暫停選單關掉時會把游標鎖回去，俯看時要放出來

## 把幽靈（身體＋頭）擺到某個鏡頭位置
func _place_player(xf: Transform3D) -> void:
	var fwd := -xf.basis.z
	player.global_position = xf.origin - Vector3(0, HEAD_H, 0)
	player.rotation = Vector3(0.0, atan2(-fwd.x, -fwd.z), 0.0)
	var head := player.get_node_or_null("Head") as Node3D
	if head:
		head.rotation.x = asin(clampf(fwd.y, -1.0, 1.0))
	if "velocity" in player:
		player.velocity = Vector3.ZERO

func _freeze_player(on: bool) -> void:
	player.set_physics_process(not on)
	player.set_process_unhandled_input(not on)
