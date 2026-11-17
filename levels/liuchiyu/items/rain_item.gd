extends "res://scripts/items/item.gd"
## 神蹟「雨」：按住左鍵，準心指的那一小塊地方上面聚起一團黑灰色的烏雲，底下下雨。放開就停。
## 雨本身不傷人，但是：
##   - 地上的幼苗被雨一直淋會長大，長成一棵樹（各關自己的 on_rain()）
##   - 剛淋過雨的地方是濕的，這時候打雷，電會沿著水傳開（見 thunder_item.gd）

const CLOUD_SHADER := preload("res://levels/liuchiyu/shaders/oil_cloud.gdshader")
const RAIN_RADIUS := 3.5       # 雨下多大一圈
const WET_TIME := 2.5          # 雨停之後地面還濕多久

var hold := true               # 按住持續施放（見 island_battle.gd 的 _hold_tick）
var any_aim := true
var wet_pos := Vector3.ZERO    # 最近淋濕的地方
var wet_left := 0.0            # 那裡還要濕多久
var _cloud: Node3D
var _fx: CPUParticles3D

func _init() -> void:
	id = "rain"
	name = "雨"
	tutorial = "按住左鍵，準心指的那一小塊地方會下雨。\n地上的幼苗被雨一直淋，會長成一棵樹。"
	color = Color(0.45, 0.65, 0.95)
	radius = RAIN_RADIUS
	cooldown = 0.0

func placement_error(_bt, _p: Vector3) -> String:
	return ""

func reset(_bt) -> void:
	wet_left = 0.0
	_cloud = null
	_fx = null

func cast(_bt, _p: Vector3) -> void:
	pass

func step(_bt, dt: float) -> void:
	if wet_left > 0.0:
		wet_left -= dt

## 這個位置現在是不是濕的
func is_wet(bt, p: Vector3) -> bool:
	return wet_left > 0.0 and bt.flat_dist(p, wet_pos) <= RAIN_RADIUS + 1.0

func hold_step(bt, p: Vector3, _dir: Vector3, dt: float, fresh: bool) -> void:
	if fresh:
		bt.log_event("開始下雨（%.1f, %.1f）" % [p.x, p.z])
	wet_pos = p
	wet_left = WET_TIME
	_show(bt, p)
	if bt.has_method("on_rain"):
		bt.on_rain(p, dt)

func hold_end(_bt) -> void:
	if _fx and is_instance_valid(_fx):
		_fx.emitting = false
	if _cloud and is_instance_valid(_cloud):
		_cloud.visible = false

## 烏雲（一團一團鼓起來的黑灰色積雲）和底下的雨絲，跟著準心走
func _show(bt, p: Vector3) -> void:
	if _cloud == null or not is_instance_valid(_cloud):
		_cloud = Node3D.new()
		bt.fx_root.add_child(_cloud)
		# 跟天空的雲同一種畫法：一格一格平塗、只分幾階明暗，顏色是黑灰色（shaders/oil_cloud.gdshader）
		var cm := ShaderMaterial.new()
		cm.shader = CLOUD_SHADER
		var rng := RandomNumberGenerator.new()
		rng.seed = 4242
		for k in 14:
			var puff := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 1.0
			sm.height = 2.0
			sm.radial_segments = 8
			sm.rings = 4
			puff.mesh = sm
			puff.material_override = cm
			var a := TAU * float(k) / 14.0
			var rr := rng.randf_range(0.0, RAIN_RADIUS * 0.85)
			# 底下平平的、上面一團一團鼓起來，像積雲
			var sc := rng.randf_range(1.3, 2.5)
			puff.position = Vector3(cos(a) * rr, sc * 0.35 + rng.randf_range(0.0, 0.5), sin(a) * rr)
			puff.scale = Vector3(sc, sc * 0.7, sc)
			puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_cloud.add_child(puff)
		var qm := QuadMesh.new()
		qm.size = Vector2(0.03, 0.8)
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(0.82, 0.90, 1.0, 0.6)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
		qm.material = m
		_fx = CPUParticles3D.new()
		_fx.mesh = qm
		_fx.amount = 160
		_fx.lifetime = 0.42
		_fx.local_coords = false
		_fx.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		_fx.emission_box_extents = Vector3(RAIN_RADIUS * 0.8, 0.2, RAIN_RADIUS * 0.8)
		_fx.direction = Vector3.DOWN
		_fx.spread = 1.0
		_fx.initial_velocity_min = 19.0
		_fx.initial_velocity_max = 23.0
		_fx.gravity = Vector3.ZERO
		_cloud.add_child(_fx)
	_cloud.visible = true
	_cloud.global_position = Vector3(p.x, p.y + 8.5, p.z)
	_fx.emitting = true
