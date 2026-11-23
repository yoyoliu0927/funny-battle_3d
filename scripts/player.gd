extends CharacterBody3D
## 幽靈觀察者（第一人稱）
## - WASD：依鏡頭水平面向前後左右飄移（抬頭/低頭不影響，只在水平面上移動）
## - 空白鍵：上升　Shift：下降
## - 移動滑鼠：畫面直接跟著轉（游標鎖在畫面中央，中央圓圈是準心）
## - Esc：戰局裡會打開暫停選單（scripts/ui/pause_menu.gd 先接走 Esc、放開游標，關掉選單時再把游標還回來）；
##   沒有暫停選單的場合才是這裡直接放開游標（停止轉動），在視窗內點一下滑鼠即可回到操作
## 幽靈不受重力影響，會停在空中；碰到地形或岩石會被擋住，不會鑽進地底。

@export var move_speed := 4.5
@export var vertical_speed := 3.5
@export var acceleration := 10.0       # 起步/停下的柔順度，越小越「飄」
@export var mouse_sensitivity := 0.0025
@export var pitch_limit_deg := 85.0
@export var bounds_min := Vector2(-19.0, -22.0)   # 森林邊界（x, z）
@export var bounds_max := Vector2(19.0, 22.0)
@export var max_height := 35.0

@onready var head: Node3D = $Head

var looking := false
var _released_by_focus := false
var _bob_t := 0.0

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
	if event is InputEventMouseMotion and looking:
		rotate_y(-event.relative.x * mouse_sensitivity)
		var lim := deg_to_rad(pitch_limit_deg)
		head.rotation.x = clampf(head.rotation.x - event.relative.y * mouse_sensitivity, -lim, lim)
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		# 戰局裡 Esc 會先被暫停選單接走，到不了這裡；到得了＝這個場合沒有選單，直接放開游標
		_set_looking(false)
	elif event is InputEventMouseButton and event.pressed and not looking and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
		# 游標被放開時，點一下視窗就回到視角操作（這一下不當作點擊）
		_set_looking(true)
		get_viewport().set_input_as_handled()

func _set_looking(on: bool) -> void:
	looking = on
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

	# 幽靈的輕微漂浮感（只晃鏡頭，不影響實際位置）
	_bob_t += delta
	head.position.y = 1.65 + sin(_bob_t * 1.6) * 0.04
