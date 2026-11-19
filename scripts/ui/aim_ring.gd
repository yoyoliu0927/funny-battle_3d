extends MeshInstance3D
## 地上的瞄準圈（所有大關共用）：每一幀沿著地形重新長一次，整圈貼在地面上，不會一半插進土裡、一半浮在空中。
## 參考動作遊戲的範圍提示（技能範圍、落點）：
##   - 一條細細的實線圈，內外兩邊淡出（不是立體的甜甜圈）
##   - 圈內一層很淡的底色，中心一個小十字標出精確落點
##   - 會被前面的東西擋住（跟場景在同一層）；被擋住的部分用很淡的「透視」畫出來，還是找得到
## 用法跟原本一樣：戰局程式照舊設 global_position（圓心）、scale.x（半徑）、material_override.albedo_color（顏色）。
## rotation 不影響形狀（地形本身就決定了圈的起伏）。
##   var ring = preload("res://scripts/ui/aim_ring.gd").new(); ring.world = world; world.add_child(ring)

const SEG := 40                 # 圈分幾段
const LINE := 0.04              # 實線半寬（公尺）：細細的一條
const FEATHER := 0.07           # 實線兩邊淡出的寬度
const LIFT := 0.04              # 離地多高（避免跟地面搶深度而閃爍）
const FILL_A := 0.13            # 圈內底色的透明度
const XRAY_A := 0.28            # 被擋住時的透明度（相對於實線）

var world: Node                 # 要有 height_at(x, z)
var _main: StandardMaterial3D
var _xray: StandardMaterial3D
var _last_xf := Transform3D()
var _built := false

func _ready() -> void:
	process_priority = 100      # 等戰局程式擺好位置再長
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh = ArrayMesh.new()
	if material_override == null:
		material_override = make_material()
	_main = material_override as StandardMaterial3D
	_setup_material(_main)

## 主材質：會被擋住（有深度測試）；next_pass 是被擋住時的淡淡透視
static func make_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1, 1, 1, 0.9)
	return m

func _setup_material(m: StandardMaterial3D) -> void:
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.no_depth_test = false
	m.render_priority = 2
	_xray = StandardMaterial3D.new()
	_xray.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_xray.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_xray.vertex_color_use_as_albedo = true
	_xray.cull_mode = BaseMaterial3D.CULL_DISABLED
	_xray.no_depth_test = true
	_xray.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	_xray.render_priority = 1
	m.next_pass = _xray

func _height(x: float, z: float) -> float:
	return world.height_at(x, z) if world and world.has_method("height_at") else global_position.y

func _process(_dt: float) -> void:
	if not visible:
		return
	if _main and _xray:
		var c := _main.albedo_color
		_xray.albedo_color = Color(c.r, c.g, c.b, c.a * XRAY_A)
	# 圈本身不轉、不縮放（半徑從 scale.x 讀），頂點直接用世界座標算好
	var r := maxf(absf(scale.x), 0.05)
	var center := global_position
	var gxf := global_transform
	# 只有圓心移動超過 3 公分、或大小／角度變了才重長（停著瞄準時完全不花力氣）
	if _built and gxf.origin.distance_to(_last_xf.origin) < 0.03 and gxf.basis.is_equal_approx(_last_xf.basis):
		return
	_last_xf = gxf
	_built = true
	# 頂點用世界座標算，再換回這個節點的座標（節點被設了縮放、旋轉也沒關係）
	var inv := gxf.affine_inverse()
	var verts := PackedVector3Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	var radii := [r - LINE - FEATHER, r - LINE, r + LINE, r + LINE + FEATHER]
	var alphas := [0.0, 1.0, 1.0, 0.0]
	# 實線圈：四排頂點（淡出、實、實、淡出）
	for i in SEG:
		var a := TAU * i / SEG
		var dir := Vector3(cos(a), 0, sin(a))
		for k in 4:
			var p: Vector3 = center + dir * maxf(float(radii[k]), 0.0)
			p.y = _height(p.x, p.z) + LIFT
			verts.append(inv * p)
			cols.append(Color(1, 1, 1, alphas[k]))
	for i in SEG:
		var j := (i + 1) % SEG
		for k in 3:
			var a0 := i * 4 + k
			var b0 := j * 4 + k
			idx.append_array([a0, b0, a0 + 1, a0 + 1, b0, b0 + 1])
	# 圈內淡淡的底色（從中心往外，一樣貼地）
	var base := verts.size()
	var cp := center
	cp.y = _height(cp.x, cp.z) + LIFT * 0.5
	verts.append(inv * cp)
	cols.append(Color(1, 1, 1, FILL_A * 0.6))
	for i in SEG:
		var a := TAU * i / SEG
		var p := center + Vector3(cos(a), 0, sin(a)) * maxf(r - LINE, 0.0)
		p.y = _height(p.x, p.z) + LIFT * 0.5
		verts.append(inv * p)
		cols.append(Color(1, 1, 1, FILL_A))
	for i in SEG:
		idx.append_array([base, base + 1 + i, base + 1 + (i + 1) % SEG])
	# 中心小十字：精確落點
	var arm := clampf(r * 0.22, 0.18, 0.45)
	for d in [Vector3(1, 0, 0), Vector3(0, 0, 1)]:
		var side: Vector3 = Vector3(-d.z, 0, d.x) * 0.035
		var s0 := verts.size()
		for t in [-1.0, 1.0]:
			for w in [-1.0, 1.0]:
				var p: Vector3 = center + d * arm * t + side * w
				p.y = _height(p.x, p.z) + LIFT * 1.5
				verts.append(inv * p)
				cols.append(Color(1, 1, 1, 0.95))
		idx.append_array([s0, s0 + 1, s0 + 2, s0 + 1, s0 + 3, s0 + 2])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_INDEX] = idx
	var am := mesh as ArrayMesh
	am.clear_surfaces()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
