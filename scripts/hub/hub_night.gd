extends Node3D
## 農莊的夜晚：螢火蟲（田裡、池塘邊、雞圈外）和每個站點旁邊路燈的光。天色（hub_time.gd）一暗，它們就慢慢亮起來；天亮了就收起來。
## 螢火蟲是一團一團會閃的小光點（粒子，加法混色）；路燈是一顆暖色的小燈泡＋一盞不投影的點光源。

var map                           # 選關畫面（level_select.gd）
var _clouds: Array = []           # 螢火蟲粒子
var _mats: Array = []             # 螢火蟲的材質（一起調亮度）
var _lamps: Array = []            # {"bulb": MeshInstance3D, "light": OmniLight3D}
var _k := 0.0                     # 現在亮到哪（0～1，慢慢追著目標走）

func build() -> void:
	var w: Dictionary = map.worlds[0]
	var ctr: Vector3 = w.center
	var y := ctr.y + 1.4
	# 螢火蟲：三團——北邊的田、池塘邊、雞圈外的草地
	var pond: Vector3 = map._fishing.pond_center() if map._fishing != null and map._fishing.pond_node != null else ctr + Vector3(24, 0, -4)
	_firefly(Vector3(ctr.x - 4.0, y, ctr.z - 15.0), Vector3(30.0, 2.2, 8.0), 70)
	_firefly(Vector3(pond.x, y, pond.z), Vector3(9.0, 1.8, 6.5), 36)
	_firefly(Vector3(ctr.x + 2.0, y, ctr.z + 8.0), Vector3(26.0, 2.0, 4.0), 40)
	# 路燈：每個站點旁邊（_build_farm 把路燈放在站點右邊 2.6 公尺、後面 0.4 公尺的地方）
	for k in int(w.n):
		var p: Vector3 = (w.pads[k] as Vector3) + Vector3(2.6, 2.3, 0.4)
		var bulb := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.22
		sm.height = 0.44
		sm.radial_segments = 10
		sm.rings = 5
		bulb.mesh = sm
		var bm: StandardMaterial3D = map._flat_mat(Color(1.0, 0.82, 0.45), true)
		bulb.material_override = bm
		bulb.position = p
		bulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		bulb.visible = false
		add_child(bulb)
		var li := OmniLight3D.new()
		li.light_color = Color(1.0, 0.78, 0.46)
		li.omni_range = 9.0
		li.light_energy = 0.0
		li.shadow_enabled = false
		li.position = p
		li.visible = false
		add_child(li)
		_lamps.append({"bulb": bulb, "light": li})

func _firefly(at: Vector3, ext: Vector3, amount: int) -> void:
	var ps := CPUParticles3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.11
	sm.height = 0.22
	sm.radial_segments = 8
	sm.rings = 4
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color(0.85, 1.0, 0.4, 0.0)
	sm.material = mat
	ps.mesh = sm
	ps.amount = amount
	ps.lifetime = 5.0
	ps.preprocess = 5.0
	ps.local_coords = false
	ps.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	ps.emission_box_extents = ext
	ps.direction = Vector3(0, 0.3, 0)
	ps.spread = 180.0
	ps.initial_velocity_min = 0.3
	ps.initial_velocity_max = 1.1
	ps.gravity = Vector3.ZERO
	ps.damping_min = 0.2
	ps.damping_max = 0.5
	ps.scale_amount_min = 0.6
	ps.scale_amount_max = 1.3
	# 一閃一閃：生出來慢慢亮、再慢慢暗（顏色的透明度）
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.25, 0.5, 0.75, 1.0])
	g.colors = PackedColorArray([Color(0.85, 1.0, 0.4, 0.0), Color(0.85, 1.0, 0.4, 0.95), Color(0.7, 1.0, 0.3, 0.25), Color(0.9, 1.0, 0.45, 0.9), Color(0.85, 1.0, 0.4, 0.0)])
	ps.color_ramp = g
	ps.position = at
	ps.emitting = false
	add_child(ps)
	_clouds.append(ps)
	_mats.append(mat)

## 每一幕。night：0 = 白天、1 = 深夜
func tick(dt: float, night: float) -> void:
	_k = move_toward(_k, night, dt * 0.5)
	var on := _k > 0.04
	for ps in _clouds:
		(ps as CPUParticles3D).emitting = _k > 0.3
		(ps as CPUParticles3D).visible = on
	for m in _mats:
		(m as StandardMaterial3D).albedo_color = Color(0.85, 1.0, 0.4, clampf(_k * 1.3, 0.0, 1.0))
	for l in _lamps:
		var li: OmniLight3D = l.light
		var bulb: MeshInstance3D = l.bulb
		li.visible = on
		bulb.visible = on
		li.light_energy = _k * 1.7 * (0.94 + 0.06 * sin(Time.get_ticks_msec() * 0.003 + li.position.x))
		bulb.scale = Vector3.ONE * clampf(_k * 1.2, 0.2, 1.0)
