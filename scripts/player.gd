extends CharacterBody3D
## 幽靈觀察者（第一人稱）
## - WASD：依鏡頭水平面向前後左右飄移（抬頭/低頭不影響，只在水平面上移動）
## - 空白鍵：上升　Shift：下降
## - 移動滑鼠：畫面直接跟著轉（游標鎖在畫面中央，中央圓圈是準心）
## - Esc：戰局裡會打開暫停選單（scripts/ui/pause_menu.gd 先接走 Esc、放開游標，關掉選單時再把游標還回來）；
##   沒有暫停選單的場合才是這裡直接放開游標（停止轉動），在視窗內點一下滑鼠即可回到操作
## - 只有游標真的鎖住時滑鼠才轉視角：游標放出來的時候（教學彈窗、結算畫面、網頁版被瀏覽器放開…）
##   移動滑鼠去點東西，視角不會跟著跑
## 幽靈不受重力影響，會停在空中；碰到地形或岩石會被擋住，不會鑽進地底。
##
## 網頁版：瀏覽器偶爾會送來一下特別大的滑鼠位移（剛鎖住的第一下、Chrome 的已知問題），會讓視角猛然一甩，直接丟掉。
## （瀏覽器自己放開游標、鎖不起來的處理在 scripts/ui/pause_menu.gd）

@export var move_speed := 4.5
@export var vertical_speed := 3.5
@export var acceleration := 10.0       # 起步/停下的柔順度，越小越「飄」
@export var mouse_sensitivity := 0.0025
@export var pitch_limit_deg := 85.0
@export var bounds_min := Vector2(-19.0, -22.0)   # 森林邊界（x, z）
@export var bounds_max := Vector2(19.0, 22.0)
@export var max_height := 35.0

const HEAD_Y := 1.65
const WEB_SPIKE := 400.0               # 網頁版：一幀裡滑鼠位移超過這麼多像素就當作瀏覽器送錯，不轉

@onready var head: Node3D = $Head

var looking := false
var _released_by_focus := false
var _bob_t := 0.0
var _web := OS.has_feature("web")
var _motion_live := false              # 游標鎖住之後已經收過滑鼠移動了（剛鎖住的第一下網頁版要丟掉）
var _tick_from := Vector3.ZERO         # 上一個物理格開始時的位置（鏡頭補間用）
var _tick_to := Vector3.ZERO           # 上一個物理格結束時的位置

func _ready() -> void:
	_ensure_actions()
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	_set_looking(true)

func _ensure_actions() -> void:
	var map := {
		"move_forward": KEY_W, "move_back": KEY_S, "move_left": KEY_A, "move_right": KEY_D,
		"fly_up": KEY_SPACE, "fly_down": KEY_SHIFT,
	}
	for action in map:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			var ev := InputEventKey.new()
			ev.physical_keycode = map[action]
			InputMap.action_add_event(action, ev)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_look(event.relative)
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		# 戰局裡 Esc 會先被暫停選單接走，到不了這裡；到得了＝這個場合沒有選單，直接放開游標
		_set_looking(false)
	elif event is InputEventMouseButton and event.pressed and not looking and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
		# 游標被放開時，點一下視窗就回到視角操作（這一下不當作點擊）
		_set_looking(true)
		get_viewport().set_input_as_handled()

## 滑鼠轉視角：只在游標真的鎖住的時候
func _look(rel: Vector2) -> void:
	if not looking or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		_motion_live = false
		return
	var first := not _motion_live
	_motion_live = true
	if _web and (first or maxf(absf(rel.x), absf(rel.y)) > WEB_SPIKE):
		return
	rotate_y(-rel.x * mouse_sensitivity)
	var lim := deg_to_rad(pitch_limit_deg)
	head.rotation.x = clampf(head.rotation.x - rel.y * mouse_sensitivity, -lim, lim)

func _set_looking(on: bool) -> void:
	looking = on
	_motion_live = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if on else Input.MOUSE_MODE_VISIBLE

func _notification(what: int) -> void:
	# 切到其他視窗時放開游標
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_released_by_focus = looking
		if looking:
			_set_looking(false)
	# 切回來時，若剛才是因為失焦才放開，就自動恢復視角操作
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN and _released_by_focus:
		_released_by_focus = false
		_set_looking(true)

func _physics_process(delta: float) -> void:
	_tick_from = global_position
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	# 只取身體的水平朝向（俯仰角在 Head 上），所以 WASD 永遠是水平移動
	var forward := -global_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var right := global_basis.x
	right.y = 0.0
	right = right.normalized()
	var dir := right * input.x - forward * input.y
	if dir.length() > 1.0:
		dir = dir.normalized()
	var vert := Input.get_axis("fly_down", "fly_up")

	var target := Vector3(dir.x * move_speed, vert * vertical_speed, dir.z * move_speed)
	velocity = velocity.lerp(target, clampf(acceleration * delta, 0.0, 1.0))
	move_and_slide()

	# 外圍是密林，幽靈不能再往外飄
	global_position.x = clampf(global_position.x, bounds_min.x, bounds_max.x)
	global_position.z = clampf(global_position.z, bounds_min.y, bounds_max.y)
	global_position.y = minf(global_position.y, max_height)
	_tick_to = global_position

func _process(delta: float) -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		_motion_live = false
	_place_head(delta)

## 鏡頭（Head）的位置：幽靈的輕微漂浮感＋物理格之間的補間（都只動鏡頭，不影響實際位置）。
## 移動是在物理格算的（每秒 60 次），畫面幀數跟物理格對不齊時（網頁版常常這樣）鏡頭會一頓一頓；
## 這裡把鏡頭放到上一格和這一格之間對應的位置，走起來就順了。
## 身體被別人搬走（傳送、過場、俯看切回來）或物理停住時不補間，直接放在原位。
func _place_head(delta: float) -> void:
	if is_physics_processing():
		_bob_t += delta
	var off := Vector3.ZERO
	if is_physics_processing() and global_position.is_equal_approx(_tick_to) \
			and _tick_from.distance_squared_to(_tick_to) < 1.0:
		off = _tick_from.lerp(_tick_to, Engine.get_physics_interpolation_fraction()) - _tick_to
	head.position = Vector3(0.0, HEAD_Y + sin(_bob_t * 1.6) * 0.04, 0.0) + global_basis.inverse() * off
