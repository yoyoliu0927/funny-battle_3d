extends Node3D
## 神的雙手（第一人稱）：掛在鏡頭底下，半透明、邊緣發光。
## 模型和動畫來自 PSX First Person Arms（Drillimpact，CC0），見 assets/CREDITS.txt。
##
## island_battle.gd 會呼叫：
##   cast_pulse(道具 id)：按一下型的道具（雷、鞭炮…）放出去的那一下，手動一下就回到待機
##   set_hold(道具 id)  ：按住型的道具（風、雨、夜）按著的時候手一直維持出力的姿勢；放開時傳 ""
##   show_hands(開/關)  ：過場、鏡頭被借走的時候淡出
## 手一直都在，但平常只低低地露在畫面最下面，不搶戲；用道具的時候才抬上來一點做動作，做完停一下再落回去。
## 這些都只是畫面效果，不影響戰局（所以放在 _process，不放在 1/60 秒的戰局函式裡）。

const ARMS := preload("res://levels/liuchiyu/assets/hand/arms_rig.glb")
const GHOST := preload("res://levels/liuchiyu/shaders/ghost_hand.gdshader")

const EYE_HEIGHT := 1.743                 # 模型裡「camera」骨頭的高度：把它對到鏡頭的位置
const BASE_OFFSET := Vector3(0.0, -0.06, -0.07)   # 做動作時手的位置：壓在畫面下半部，不要擋到準心
const LOWER_DROP := 0.025          # 平常（沒做動作）的時候再往下多少：只露出手掌和手指
const IDLE_FADE := 0.75            # 平常的時候淡一點（1 = 和做動作時一樣）
const RAISE_TIME := 0.14           # 抬上來要幾秒
const LOWER_TIME := 0.35           # 收回去要幾秒
const LINGER := 0.45               # 動作做完之後停多久才收回去

## 每個道具放出去時手要做的動作（沒列到的用 DEFAULT_*）
const PULSE_ANIM := {
	"thunder": "finger_gun_fire",   # 手指一指，雷就打下去
	"firecracker": "grab_L",
	"feed": "grab_R",
	"banana": "grab_R",
	"rock": "push_L",
}
## 按住型的道具：播到 hold_at（秒）就停在那個姿勢
const HOLD_ANIM := {
	"wind": ["push_R", 0.16],
	"rain": ["push_L", 0.16],
	"night": ["guard_draw", 0.55],
}
const DEFAULT_PULSE := "push_R"
const DEFAULT_HOLD := ["push_R", 0.16]
const IDLE := "relax"

var _pivot: Node3D
var _ap: AnimationPlayer
var _mat: ShaderMaterial
var _hold_id := ""
var _hold_at := -1.0
var _pulsing := false
var _glow := 0.0
var _fade := 1.0
var _want_visible := true
var _t := 0.0
var _raise := 0.0                  # 0 = 收在畫面下面、1 = 抬上來
var _linger := 0.0                 # 動作做完之後還要停幾秒
var _sway := Vector2.ZERO          # 轉鏡頭時手稍微落後一點（x：左右、y：上下）
var _last_basis := Basis.IDENTITY
var _has_last := false

func _ready() -> void:
	_pivot = Node3D.new()
	_pivot.name = "Pivot"
	_pivot.position = BASE_OFFSET
	add_child(_pivot)
	var arms: Node3D = ARMS.instantiate()
	# 模型的前方是 +Z、鏡頭的前方是 -Z：轉半圈，再把眼睛那根骨頭移到原點
	arms.transform = Transform3D(Basis(Vector3.UP, PI), Vector3(0.0, -EYE_HEIGHT, 0.0))
	_pivot.add_child(arms)

	_mat = ShaderMaterial.new()
	_mat.shader = GHOST
	_mat.render_priority = 10           # 比場景裡其他半透明的東西（雨、葉子）晚畫，手永遠疊在最上面
	for m in arms.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		var src := mi.get_active_material(0) as BaseMaterial3D
		if src and src.albedo_texture:
			_mat.set_shader_parameter("skin_tex", src.albedo_texture)
		mi.material_override = _mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.extra_cull_margin = 2.0      # 動畫把手伸出去的時候不要被裁掉

	_ap = arms.find_children("*", "AnimationPlayer", true, false)[0]
	var idle := _ap.get_animation(IDLE)
	if idle:
		idle.loop_mode = Animation.LOOP_LINEAR
	_ap.animation_finished.connect(_on_anim_finished)
	_ap.play(IDLE)

## 按一下型的道具放出去了
func cast_pulse(item_id: String) -> void:
	_glow = 1.0
	if _hold_id != "":
		return                          # 正按著別的道具：只亮一下就好
	var anim: String = PULSE_ANIM.get(item_id, DEFAULT_PULSE)
	if not _ap.has_animation(anim):
		return
	_pulsing = true
	_ap.speed_scale = 1.0
	_ap.play(anim, 0.08)
	_ap.seek(0.0, true)

## 按住型的道具：按著的時候每一畫面都會傳 id 進來，放開時傳 ""
func set_hold(item_id: String) -> void:
	if item_id == _hold_id:
		return
	_hold_id = item_id
	_ap.speed_scale = 1.0
	if item_id == "":
		_hold_at = -1.0
		_ap.play(IDLE, 0.3)
		return
	var spec: Array = HOLD_ANIM.get(item_id, DEFAULT_HOLD)
	if not _ap.has_animation(spec[0]):
		return
	_pulsing = false
	_hold_at = spec[1]
	_glow = 0.6
	_ap.play(spec[0], 0.12)
	_ap.seek(0.0, true)

func show_hands(on: bool) -> void:
	_want_visible = on

func _on_anim_finished(anim: StringName) -> void:
	if anim == StringName(IDLE) or _hold_id != "":
		return
	_pulsing = false
	_ap.play(IDLE, 0.3)

func _process(dt: float) -> void:
	_t += dt
	# 按住型：播到出力的那一格就停住
	if _hold_id != "" and _hold_at >= 0.0 and _ap.speed_scale > 0.0 and _ap.current_animation_position >= _hold_at:
		_ap.speed_scale = 0.0

	# 有動作就抬上來；沒事了停一下再收回去
	var active := _hold_id != "" or _pulsing
	if active:
		_linger = LINGER
	else:
		_linger = maxf(_linger - dt, 0.0)
	var up := (active or _linger > 0.0) and _want_visible
	_raise = move_toward(_raise, 1.0 if up else 0.0, dt / (RAISE_TIME if up else LOWER_TIME))
	var lift := 1.0 - pow(1.0 - _raise, 3.0)        # 抬起來先快後慢

	# 淡入淡出（過場時整個淡掉；平常低低的時候也淡一點）
	_fade = move_toward(_fade, 1.0 if _want_visible else 0.0, dt * 4.0)
	visible = _fade > 0.01
	_glow = move_toward(_glow, 0.25 if _hold_id != "" else 0.0, dt * 2.5)
	_mat.set_shader_parameter("fade", _fade * lerpf(IDLE_FADE, 1.0, lift))
	_mat.set_shader_parameter("glow", _glow)

	# 轉鏡頭時手稍微落後，再慢慢跟上
	var par := get_parent() as Node3D
	var b: Basis = par.global_basis.orthonormalized() if par else Basis.IDENTITY
	if _has_last:
		var d: Basis = _last_basis.inverse() * b
		var e: Vector3 = d.get_euler()
		_sway += Vector2(e.y, e.x) * 0.6
	_last_basis = b
	_has_last = true
	_sway = _sway.lerp(Vector2.ZERO, clampf(dt * 8.0, 0.0, 1.0))
	_sway = _sway.clamp(Vector2(-0.08, -0.08), Vector2(0.08, 0.08))

	# 漂浮的神：手慢慢上下晃，按著道具的時候微微抖動（像在出力）
	var bob := Vector3(sin(_t * 0.9) * 0.006, sin(_t * 1.8) * 0.008, 0.0)
	if _hold_id != "":
		bob += Vector3(sin(_t * 23.0), cos(_t * 19.0), 0.0) * 0.0025
	_pivot.position = BASE_OFFSET + bob + Vector3(-_sway.x * 0.5, -_sway.y * 0.5 - (1.0 - lift) * LOWER_DROP, 0.0)
	_pivot.rotation = Vector3(_sway.y, _sway.x, 0.0)
