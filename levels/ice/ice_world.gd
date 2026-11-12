extends "res://scripts/world/arena_world.gd"
## 冰雪島共用場地：雪地、結冰的湖（冰面）、冰洞、薄冰。
## 各小關的 world.gd 寫 extends "res://levels/ice/ice_world.gd"，在 _ice_configure() 裡設定：
##   lakes      結冰的湖（橢圓）：人走上去會滑
##   ponds      冰洞（沿用共用的水池）：人掉進去就出局，家豪會飛過去
##   thin_spots 薄冰：家豪走得過去，人一踩就破
## 戰局規則（人怎麼滑、薄冰怎麼破）寫在 ice_battle.gd。

## 結冰的湖：[{"center": Vector2, "rx": 橫向半徑, "rz": 縱向半徑}]
var lakes: Array = []
## 一開始就在的薄冰：[{"center": Vector2, "r": 半徑}]
var thin_spots: Array = []
## 雪人擺設（會擋路）：[Vector3, ...]
var snowmen: Array = []
## 建好的雪人：[{pos, node, head}]（head 是最上面那顆雪球，撞到時會掉下來）
var snowman_nodes: Array = []
## 冰湖邊的松樹（裝飾，會擋路）：[Vector3, ...]
var pines: Array = []
## 雪堆（不擋路）：滑出去停在雪堆旁的人會倒栽進去，只露出兩條腿。[Vector3, ...]
var snow_piles: Array = []

## 執行中的薄冰：[{center, r, state ("solid" / "cracking" / "broken"), t, node, water, dynamic}]
var thin: Array = []

var _ice_mat: StandardMaterial3D
var _thin_mat: StandardMaterial3D
var _crack_mat: StandardMaterial3D
var _hole_mat: StandardMaterial3D
var _snow_mat: ShaderMaterial

## 子類別覆寫：設定 lakes、ponds、thin_spots、hero_start、camera_start…
func _ice_configure() -> void:
	pass

func _configure() -> void:
	hill_amount = 0.35
	grass_count = 0
	ground_a = Color(0.93, 0.96, 1.0)
	ground_b = Color(0.85, 0.90, 0.97)
	dirt_color = Color(0.80, 0.86, 0.94)
	tree_green = Color(0.50, 0.66, 0.68)
	_ice_configure()

# ---------------------------------------------------------------- 地形

## 冰湖要平：把地面起伏扣掉，再往下壓一點點
func _extra_height(x: float, z: float) -> float:
	var w := lake_weight(x, z)
	if w <= 0.0:
		return 0.0
	return -(_bumps(x, z) + 0.12) * w

## 共用地形的起伏（跟 arena_world.gd 的公式一樣，用來把湖面整平）
func _bumps(x: float, z: float) -> float:
	var h := (_noise.get_noise_2d(x * 1.1 + 40.0, z * 1.1) * 1.9 + _noise.get_noise_2d(x * 2.6, z * 2.6 + 17.0) * 0.45) * hill_amount
	return h + _noise.get_noise_2d(x * 2.0, z * 2.0) * 0.08

## 1 = 在湖裡面，0 = 在湖外面（邊緣平滑過渡）
func lake_weight(x: float, z: float) -> float:
	var best := 0.0
	for l in lakes:
		best = maxf(best, 1.0 - sstep(0.92, 1.12, _lake_e(l, x, z)))
	return best

func _lake_e(l: Dictionary, x: float, z: float) -> float:
	var c: Vector2 = l.center
	return Vector2((x - c.x) / float(l.rx), (z - c.y) / float(l.rz)).length()

func _tweak_terrain_material(mat: ShaderMaterial) -> void:
	super(mat)
	mat.set_shader_parameter("rock_c", Color(0.66, 0.76, 0.86))
	mat.set_shader_parameter("sand_c", Color(0.90, 0.94, 0.99))

# ---------------------------------------------------------------- 給戰局用的查詢

## 這裡是不是冰面（人會滑）
func on_ice(x: float, z: float) -> bool:
	for l in lakes:
		if _lake_e(l, x, z) < 1.0:
			return true
	return false

## 薄冰破掉的地方也算水
func in_water(x: float, z: float) -> bool:
	if super(x, z):
		return true
	for th in thin:
		if th.state == "broken" and Vector2(x, z).distance_to(th.center) < float(th.r) - 0.15:
			return true
	return false

## 水面高度：冰洞底下的地形是挖下去的，水面取洞口外一圈的高度；不在冰洞裡就是地面
func water_surface_y(x: float, z: float) -> float:
	for p in ponds:
		var c: Vector2 = p.center
		var r: float = p.r
		if Vector2(x, z).distance_to(c) < r + 0.3:
			var y := -INF
			for k in 8:
				var a := k * TAU / 8.0
				y = maxf(y, height_at(c.x + cos(a) * (r + 0.4), c.y + sin(a) * (r + 0.4)))
			return y
	return height_at(x, z)

## 雪人頭掉下來（被撞到的時候）；重試時放回去
func reset_snowmen() -> void:
	for sn in snowman_nodes:
		var h := sn.head as Node3D
		if h.get_parent() != sn.node:
			h.get_parent().remove_child(h)
			(sn.node as Node3D).add_child(h)
		h.position = Vector3(0, 1.65, 0)
		h.rotation = Vector3.ZERO

## 這一點底下是哪一塊還沒破的薄冰（沒有回傳 -1）
func thin_at(x: float, z: float, margin := 0.0) -> int:
	for i in thin.size():
		var th: Dictionary = thin[i]
		if th.state != "broken" and Vector2(x, z).distance_to(th.center) < float(th.r) - margin:
			return i
	return -1

## 薄冰破掉：冰片消失，露出黑色的水
func break_thin(i: int) -> void:
	var th: Dictionary = thin[i]
	th.state = "broken"
	th.t = 0.0
	(th.node as Node3D).visible = false
	(th.water as Node3D).visible = true

## 多一塊薄冰（鹽撒下去會用到）；parent 放 bt.fx_root，重試時會一起刪掉
func add_thin(center: Vector2, r: float, parent: Node3D) -> int:
	var th := _make_thin(center, r, parent)
	th.dynamic = true
	thin.append(th)
	return thin.size() - 1

## 重試：薄冰恢復原狀，鹽做出來的薄冰拿掉
func reset_ice() -> void:
	reset_snowmen()
	for i in range(thin.size() - 1, -1, -1):
		var th: Dictionary = thin[i]
		if th.dynamic:
			thin.remove_at(i)
			continue
		th.state = "solid"
		th.t = 0.0
		(th.node as Node3D).visible = true
		(th.node as Node3D).position = th.base
		(th.water as Node3D).visible = false

# ---------------------------------------------------------------- 蓋東西

func _build_extra() -> void:
	_ice_mat = StandardMaterial3D.new()
	_ice_mat.vertex_color_use_as_albedo = true
	_ice_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_ice_mat.roughness = 0.35
	_ice_mat.metallic_specular = 0.25
	_thin_mat = StandardMaterial3D.new()
	_thin_mat.albedo_color = Color(0.90, 0.97, 1.0)
	_thin_mat.roughness = 0.35
	_thin_mat.emission_enabled = true
	_thin_mat.emission = Color(0.35, 0.55, 0.7)
	_thin_mat.emission_energy_multiplier = 0.25
	_crack_mat = StandardMaterial3D.new()
	_crack_mat.albedo_color = Color(0.25, 0.45, 0.62)
	_crack_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_hole_mat = StandardMaterial3D.new()
	_hole_mat.albedo_color = Color(0.04, 0.14, 0.26)
	_hole_mat.roughness = 0.1
	_hole_mat.metallic_specular = 0.6
	_snow_mat = _toon(Color(0.96, 0.98, 1.0))
	var root := Node3D.new()
	root.name = "Ice"
	add_child(root)
	for l in lakes:
		_build_lake_sheet(root, l)
	for p in ponds:
		_build_hole(root, p.center, float(p.r))
	for s in thin_spots:
		thin.append(_make_thin(s.center, float(s.r), root))
	for p in snowmen:
		_snowman(root, p)
	for p in pines:
		_pine(root, p)
	for p in snow_piles:
		var pile := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 1.1
		sm.height = 1.3
		pile.mesh = sm
		pile.material_override = _snow_mat
		pile.position = Vector3(p.x, height_at(p.x, p.z) - 0.05, p.z)
		pile.scale = Vector3(1.3, 1.0, 1.0)
		root.add_child(pile)
	_cold_weather()

## 冰面：從湖中心往外一圈一圈的網格（邊緣平滑），中心淡藍、邊緣深藍；冰洞的地方挖空
func _build_lake_sheet(parent: Node3D, l: Dictionary) -> void:
	var c: Vector2 = l.center
	var rx: float = l.rx
	var rz: float = l.rz
	var segs := 96
	var rings := 22
	var pts: Array = []
	var cols: Array = []
	for ri in rings + 1:
		var k := float(ri) / rings
		var row: Array = []
		var crow: Array = []
		for si in segs:
			var a := si * TAU / segs
			var x := c.x + cos(a) * rx * k
			var z := c.y + sin(a) * rz * k
			row.append(Vector3(x, height_at(x, z) + 0.04, z))
			var edge := sstep(0.75, 1.0, k)
			crow.append(Color(0.34, 0.62, 0.86).lerp(Color(0.22, 0.46, 0.74), edge))
		pts.append(row)
		cols.append(crow)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ri in rings:
		for si in segs:
			var sj := (si + 1) % segs
			var quad := [[ri, si], [ri + 1, si], [ri + 1, sj], [ri, sj]]
			var mid: Vector3 = (pts[ri][si] + pts[ri + 1][sj]) * 0.5
			if _in_hole(mid.x, mid.z):
				continue
			for k in [0, 2, 1, 0, 3, 2]:
				var q: Array = quad[k]
				st.set_color(cols[q[0]][q[1]])
				st.set_normal(Vector3.UP)
				st.add_vertex(pts[q[0]][q[1]])
	var mi := MeshInstance3D.new()
	mi.name = "LakeIce"
	mi.mesh = st.commit()
	mi.material_override = _ice_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	# 冰面上的刮痕，看起來比較像冰
	var r := RandomNumberGenerator.new()
	r.seed = world_seed + 77
	var scratch := StandardMaterial3D.new()
	scratch.albedo_color = Color(0.85, 0.95, 1.0)
	scratch.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for k in int(rx * rz * 0.5):
		var a := r.randf() * TAU
		var d := sqrt(r.randf()) * 0.9
		var px := c.x + cos(a) * rx * d
		var pz := c.y + sin(a) * rz * d
		if _in_hole(px, pz):
			continue
		_box(parent, Vector3(0.03, 0.01, r.randf_range(0.6, 1.8)), Vector3(px, height_at(px, pz) + 0.05, pz), scratch, Vector3(0, r.randf() * TAU, 0))

func _in_hole(x: float, z: float) -> bool:
	for p in ponds:
		if Vector2(x, z).distance_to(p.center) < float(p.r) - 0.05:
			return true
	return false

## 冰洞：一圈黑色的水，邊緣堆著碎冰塊
func _build_hole(parent: Node3D, c: Vector2, r: float) -> void:
	var water := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r + 0.05
	cm.bottom_radius = r + 0.05
	cm.height = 0.02
	cm.radial_segments = 36
	water.mesh = cm
	water.material_override = _hole_mat
	# 冰洞底下的地形是挖下去的，水面要放在冰面的高度（取洞口外一圈的高度）
	var rim_y := -INF
	for k in 8:
		var a := k * TAU / 8.0
		rim_y = maxf(rim_y, height_at(c.x + cos(a) * (r + 0.4), c.y + sin(a) * (r + 0.4)))
	water.position = Vector3(c.x, rim_y + 0.03, c.y)
	parent.add_child(water)
	var n := int(r * 7)
	for k in n:
		var a := k * TAU / n + 0.3 * sin(k * 2.3)
		var p := c + Vector2(cos(a), sin(a)) * (r + 0.05)
		var s := 0.18 + 0.12 * absf(sin(k * 1.7))
		_box(parent, Vector3(s * 1.6, s * 0.7, s), Vector3(p.x, height_at(p.x, p.y) + 0.08, p.y), _snow_mat, Vector3(0.2 * sin(k), a, 0.15 * cos(k)))

## 一塊薄冰：顏色比較白、有裂痕；底下藏著一圈黑水，破掉時才出現
func _make_thin(center: Vector2, r: float, parent: Node3D) -> Dictionary:
	var y := height_at(center.x, center.y)
	var node := Node3D.new()
	node.name = "ThinIce"
	var base := Vector3(center.x, y + 0.06, center.y)
	node.position = base
	parent.add_child(node)
	var disc := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = 0.03
	cm.radial_segments = 28
	disc.mesh = cm
	disc.material_override = _thin_mat
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(disc)
	# 裂痕：從中間往外放射
	for k in 7:
		var a := k * TAU / 7.0 + 0.4 * sin(k * 3.1)
		var len := r * (0.55 + 0.35 * absf(sin(k * 1.3)))
		var mid := Vector3(cos(a), 0, sin(a)) * len * 0.5
		_box(node, Vector3(0.035, 0.01, len), mid + Vector3(0, 0.02, 0), _crack_mat, Vector3(0, atan2(cos(a), sin(a)), 0))
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = r - 0.06
	tm.outer_radius = r
	ring.mesh = tm
	ring.material_override = _crack_mat
	ring.scale = Vector3(1, 0.15, 1)
	ring.position.y = 0.02
	node.add_child(ring)
	var water := Node3D.new()
	water.name = "BrokenIce"
	water.position = Vector3(center.x, y + 0.065, center.y)
	water.visible = false
	parent.add_child(water)
	var wd := MeshInstance3D.new()
	var wm := CylinderMesh.new()
	wm.top_radius = r
	wm.bottom_radius = r
	wm.height = 0.02
	wm.radial_segments = 28
	wd.mesh = wm
	wd.material_override = _hole_mat
	water.add_child(wd)
	for k in 6:
		var a := k * TAU / 6.0 + 0.5
		var p := Vector3(cos(a), 0, sin(a)) * r * 0.55
		_box(water, Vector3(0.35, 0.05, 0.28), p + Vector3(0, 0.03, 0), _thin_mat, Vector3(0, a * 1.7, 0.1))
	return {"center": center, "r": r, "state": "solid", "t": 0.0, "node": node, "water": water, "base": base, "dynamic": false}

func _snowman(parent: Node3D, p: Vector3) -> void:
	var y := height_at(p.x, p.z)
	var node := Node3D.new()
	node.position = Vector3(p.x, y, p.z)
	node.rotation.y = p.x * 0.7
	parent.add_child(node)
	var top: MeshInstance3D
	for b in [[0.55, 0.45], [0.4, 1.15], [0.28, 1.65]]:
		var s := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = b[0]
		sm.height = b[0] * 2.0
		s.mesh = sm
		s.material_override = _snow_mat
		s.position.y = b[1]
		node.add_child(s)
		top = s
	snowman_nodes.append({"pos": Vector3(p.x, y, p.z), "node": node, "head": top})
	var nose := MeshInstance3D.new()
	var cn := CylinderMesh.new()
	cn.top_radius = 0.0
	cn.bottom_radius = 0.06
	cn.height = 0.3
	nose.mesh = cn
	nose.material_override = _toon(Color(0.95, 0.5, 0.15))
	nose.position = Vector3(0, 0.0, 0.36)
	nose.rotation.x = PI * 0.5
	top.add_child(nose)
	var coal := _toon(Color(0.1, 0.1, 0.12))
	for e in [-0.1, 0.1]:
		_box(top, Vector3(0.06, 0.06, 0.04), Vector3(e, 0.1, 0.25), coal)
	obstacles.append([Vector2(p.x, p.z), 0.6])

func _pine(parent: Node3D, p: Vector3) -> void:
	var y := height_at(p.x, p.z)
	var green := _toon(Color(0.20, 0.38, 0.34))
	var node := Node3D.new()
	node.position = Vector3(p.x, y, p.z)
	parent.add_child(node)
	_box(node, Vector3(0.25, 0.8, 0.25), Vector3(0, 0.4, 0), _toon(Color(0.42, 0.30, 0.2)))
	for k in 3:
		var cone := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0
		cm.bottom_radius = 1.2 - k * 0.3
		cm.height = 1.3
		cm.radial_segments = 8
		cone.mesh = cm
		cone.material_override = green
		cone.position.y = 1.2 + k * 0.75
		node.add_child(cone)
		var cap := MeshInstance3D.new()
		var cc := CylinderMesh.new()
		cc.top_radius = 0.0
		cc.bottom_radius = (1.2 - k * 0.3) * 0.55
		cc.height = 0.6
		cc.radial_segments = 8
		cap.mesh = cc
		cap.material_override = _snow_mat
		cap.position.y = 1.2 + k * 0.75 + 0.38
		node.add_child(cap)
	obstacles.append([Vector2(p.x, p.z), 0.7])

## 企鵝（裝飾）
func make_penguin(parent: Node3D, pos: Vector3, yaw := 0.0) -> Node3D:
	var node := Node3D.new()
	node.position = Vector3(pos.x, height_at(pos.x, pos.z), pos.z)
	node.rotation.y = yaw
	parent.add_child(node)
	var body := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.22
	cap.height = 0.75
	body.mesh = cap
	body.material_override = _toon(Color(0.12, 0.13, 0.18))
	body.position.y = 0.38
	node.add_child(body)
	var belly := MeshInstance3D.new()
	var bc := CapsuleMesh.new()
	bc.radius = 0.16
	bc.height = 0.55
	belly.mesh = bc
	belly.material_override = _snow_mat
	belly.position = Vector3(0, 0.34, 0.09)
	node.add_child(belly)
	_box(node, Vector3(0.1, 0.06, 0.16), Vector3(0, 0.6, 0.24), _toon(Color(1.0, 0.6, 0.1)))
	for e in [-0.08, 0.08]:
		_box(node, Vector3(0.05, 0.05, 0.03), Vector3(e, 0.66, 0.19), _snow_mat)
	return node

## 冷色調的霧和陽光
func _cold_weather() -> void:
	var env_node := get_parent().get_node_or_null("WorldEnvironment") as WorldEnvironment
	if env_node and env_node.environment:
		var env := env_node.environment.duplicate() as Environment
		env.fog_light_color = Color(0.82, 0.90, 1.0)
		env.fog_density = 0.0032
		env.ambient_light_color = Color(0.70, 0.80, 0.96)
		env.adjustment_saturation = 1.12
		env_node.environment = env
	var sun := get_parent().get_node_or_null("Sun") as DirectionalLight3D
	if sun:
		sun.light_color = Color(1.0, 0.95, 0.88)
		sun.light_energy = 1.55
