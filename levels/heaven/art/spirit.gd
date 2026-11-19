extends Node3D
## 鳳羽靈光：一道金色的光拖著長長的尾巴，沿著黃線替家豪引路，再從場地外側繞回終點上空（純裝飾，不影響戰局，也不進重演）。
## 場地（heaven_world.gd）蓋好之後呼叫 setup()；過關時呼叫 orbit() 讓它在終點上空盤旋。

const TRAIL_N := 80
const HS := "res://levels/heaven/shaders/"

var loop: Array = []           # 繞圈的路線（封閉的一圈，Vector3）
var speed := 7.5
var _s := 0.0                  # 走到路線的第幾段（含小數）
var _pos := Vector3.ZERO
var _dir := Vector3(0, 0, -1)
var _trail: Array = []
var _mesh := ImmediateMesh.new()
var _mi: MeshInstance3D
var _head: Node3D
var _sparks: CPUParticles3D
var _orbit := false
var _orbit_c := Vector3.ZERO
var _orbit_r := 2.4
var _orbit_t := 0.0
var _t := 0.0

func setup(points: Array, head: Node3D, night := true) -> void:
	loop = points
	_pos = loop[0]
	_mi = MeshInstance3D.new()
	_mi.name = "Trail"
	_mi.top_level = true
	_mi.mesh = _mesh
	_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mi.extra_cull_margin = 200.0
	var m := ShaderMaterial.new()
	m.shader = load(HS + ("spirit_trail.gdshader" if night else "spirit_trail_mix.gdshader"))
	_mi.material_override = m
	add_child(_mi)
	_head = head
	if _head:
		_head.top_level = true
		add_child(_head)
	_sparks = CPUParticles3D.new()
	_sparks.top_level = true
	_sparks.amount = 36
	_sparks.lifetime = 1.6
	_sparks.local_coords = false
	_sparks.direction = Vector3(0, -1, 0)
	_sparks.spread = 60.0
	_sparks.initial_velocity_min = 0.2
	_sparks.initial_velocity_max = 0.9
	_sparks.gravity = Vector3(0, -0.6, 0)
	_sparks.scale_amount_min = 0.5
	_sparks.scale_amount_max = 1.2
	var q := QuadMesh.new()
	q.size = Vector2(0.12, 0.12)
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	if night:
		sm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.albedo_color = Color(1.0, 0.82, 0.36) if night else Color(1.0, 0.60, 0.10)
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(0.5, 0.0)
	gt.width = 32
	gt.height = 32
	sm.albedo_texture = gt
	q.material = sm
	_sparks.mesh = q
	add_child(_sparks)

## 過關：飛到這一點上空盤旋
func orbit(center: Vector3, radius := 2.4) -> void:
	_orbit = true
	_orbit_c = center
	_orbit_r = radius

func release() -> void:
	_orbit = false

func _sample(s: float) -> Vector3:
	var n := loop.size()
	var i: int = int(floor(s)) % n
	var f: float = s - floor(s)
	var p0: Vector3 = loop[(i - 1 + n) % n]
	var p1: Vector3 = loop[i]
	var p2: Vector3 = loop[(i + 1) % n]
	var p3: Vector3 = loop[(i + 2) % n]
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * f + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * f * f + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * f * f * f)

func _process(dt: float) -> void:
	if loop.size() < 4:
		return
	_t += dt
	var target: Vector3
	if _orbit:
		_orbit_t += dt
		var a: float = _orbit_t * 2.2
		target = _orbit_c + Vector3(cos(a) * _orbit_r, 0.6 * sin(_orbit_t * 1.3), sin(a) * _orbit_r)
	else:
		var n := loop.size()
		var i: int = int(floor(_s)) % n
		var seg: float = maxf((loop[i] as Vector3).distance_to(loop[(i + 1) % n]), 0.5)
		_s = fmod(_s + speed * dt / seg, float(n))
		target = _sample(_s)
	var prev := _pos
	_pos = _pos.lerp(target, 1.0 - exp(-dt * 5.0))
	var d := _pos - prev
	if d.length() > 0.0005:
		_dir = _dir.lerp(d.normalized(), 1.0 - exp(-dt * 8.0)).normalized()
	_trail.push_front(_pos)
	if _trail.size() > TRAIL_N:
		_trail.resize(TRAIL_N)
	var up := Vector3.UP
	var side := _dir.cross(up)
	if side.length() < 0.05:
		side = Vector3.RIGHT
	side = side.normalized()
	var up2 := side.cross(_dir).normalized()
	if _head:
		var flap: float = 0.72 + 0.28 * sin(_t * 9.0)
		_head.global_transform = Transform3D(Basis(side * 0.42 * flap, _dir * 0.42, up2 * 0.42), _pos + _dir * 0.25)
	if _sparks:
		_sparks.global_position = _pos
	# 尾巴：兩片互相垂直的光帶（從哪個角度看都看得到），帶一點蛇行
	_mesh.clear_surfaces()
	var n2 := _trail.size()
	if n2 < 3:
		return
	for pass_i in 2:
		_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
		for k in n2:
			var p: Vector3 = _trail[k]
			var nxt: Vector3 = _trail[mini(k + 1, n2 - 1)]
			var prv: Vector3 = _trail[maxi(k - 1, 0)]
			var td: Vector3 = (prv - nxt)
			td = td.normalized() if td.length() > 0.0001 else _dir
			var s2: Vector3 = td.cross(Vector3.UP)
			s2 = s2.normalized() if s2.length() > 0.05 else Vector3.RIGHT
			var u2: Vector3 = s2.cross(td).normalized()
			var u: float = float(k) / float(TRAIL_N - 1)
			var w: float = 0.36 * pow(1.0 - u, 0.6) + 0.03
			var wave: float = sin(u * 9.0 - _t * 5.0) * 0.22 * u
			var c: Vector3 = p + u2 * wave
			var ax: Vector3 = s2 if pass_i == 0 else u2
			_mesh.surface_set_uv(Vector2(u, 0.0))
			_mesh.surface_add_vertex(c - ax * w)
			_mesh.surface_set_uv(Vector2(u, 1.0))
			_mesh.surface_add_vertex(c + ax * w)
		_mesh.surface_end()
