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
## 工人的冰釣營地（純裝飾）：[{"pos": Vector3, "yaw": 弧度}]，通常放在工人出發點後面
var camps: Array = []
## 外圈裝飾（雪松、石頭）要避開的點，例如籠子、家豪出發點：[Vector3, ...]
var keep_clear: Array = []
## 要不要自動擺外圈裝飾、冰洞釣具、下雪
var decor := true
## 冰湖周圍的區域（純裝飾，讓地圖不只是中間一個湖）：
##   {"type": "village", "pos", "yaw"}  冰釣小村（小屋、柴堆、雪橇、燈）
##   {"type": "pier", "pos", "yaw"}     伸進湖裡的木棧道（往 yaw 方向）
##   {"type": "crystals", "pos"}        發光的冰晶簇
##   {"type": "sculptures", "pos", "yaw"}  冰雕公園（冰做的企鵝、魚）
##   {"type": "lamps", "from", "to"}    路兩旁的燈籠
##   {"type": "creek", "from", "to"}    結冰的小溪
var zones: Array = []

const KH := "res://levels/ice/assets/kenney_holiday/"
const KS := "res://levels/ice/assets/kenney_survival/"
const MB := "res://levels/ice/assets/blender/"
const MP := "res://levels/ice/assets/polypizza/"
var _jump_fish: Array = []     # 冰洞裡偶爾跳出來的魚 {node, center, phase}
var _fires: Array = []         # 營火的光 {light, flame}
var _snow_ps: GPUParticles3D
var _clutter: Array = []       # 過關演出時要收起來的小東西（釣竿、水桶、招牌字）

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
	tree_green = Color(0.26, 0.45, 0.50)   # 外圈森林用深一點的藍綠色：把白色的場地框出來
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
		if sn.has("home"):
			h.transform = sn.home
		else:
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
		var pile := _prop(root, KH + "snow-pile.glb", Vector3(p.x, height_at(p.x, p.z) - 0.1, p.z), p.x, 2.6)
		if pile == null:
			var mi := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 1.1
			sm.height = 1.3
			mi.mesh = sm
			mi.material_override = _snow_mat
			mi.position = Vector3(p.x, height_at(p.x, p.z) - 0.05, p.z)
			mi.scale = Vector3(1.3, 1.0, 1.0)
			root.add_child(mi)
	if decor:
		_build_decor(root)
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
			crow.append(Color(0.30, 0.60, 0.90).lerp(Color(0.14, 0.38, 0.70), edge))   # 冰湖要在雪地上跳出來
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
	# 有 Blender 做的雪人模型就用模型（頭是獨立的節點，可以被撞下來扣在工人頭上）
	var model := _prop(node, MB + "snowman.glb", Vector3.ZERO, 0.0, 1.0)
	if model:
		var hd := model.find_child("Head", true, false) as Node3D
		if hd:
			hd.reparent(node)
			snowman_nodes.append({"pos": Vector3(p.x, y, p.z), "node": node, "head": hd, "home": hd.transform})
			obstacles.append([Vector2(p.x, p.z), 0.6])
			return
		model.queue_free()
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
	if _prop(parent, KH + "tree-snow-a.glb", Vector3(p.x, y, p.z), p.x, 2.8):
		obstacles.append([Vector2(p.x, p.z), 0.7])
		return
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
	# 企鵝模型（Poly Pizza / sugamo，CC-BY）：高度 1，臉朝 +Z
	if _prop(node, MP + "penguin_stand.glb", Vector3.ZERO, 0.0, 0.95):
		return node
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
		env.fog_density = 0.0016
		env.ambient_light_color = Color(0.70, 0.80, 0.96)
		env.adjustment_enabled = true
		env.adjustment_saturation = 1.22
		env.adjustment_contrast = 1.07
		env_node.environment = env
	var sun := get_parent().get_node_or_null("Sun") as DirectionalLight3D
	if sun:
		sun.light_color = Color(1.0, 0.95, 0.88)
		sun.light_energy = 1.55

# ---------------------------------------------------------------- 裝飾（Kenney CC0 模型，見 assets/CREDITS.txt）

## 放一個模型（找不到檔案就回傳 null，不會讓關卡壞掉）
func _prop(parent: Node3D, path: String, pos: Vector3, yaw := 0.0, scale := 1.0) -> Node3D:
	if not ResourceLoader.exists(path):
		return null
	var ps := load(path) as PackedScene
	if ps == null:
		return null
	var n := ps.instantiate() as Node3D
	n.position = pos
	n.rotation.y = yaw
	n.scale = Vector3.ONE * scale
	parent.add_child(n)
	return n

func _g(x: float, z: float) -> Vector3:
	return Vector3(x, height_at(x, z), z)

func _build_decor(root: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	# 外圈：雪松和石頭（只在場地邊緣那一圈，不擋路、不擋鏡頭）
	var cx := (play_min.x + play_max.x) * 0.5
	var cz := (play_min.y + play_max.y) * 0.5
	var rx := (play_max.x - play_min.x) * 0.5
	var rz := (play_max.y - play_min.y) * 0.5
	var clear: Array = keep_clear.duplicate()
	clear.append(hero_start)
	for c in camps:
		clear.append(c.pos)
	for i in 46:
		var a := rng.randf() * TAU
		var k := rng.randf_range(0.80, 0.97)
		var x := cx + cos(a) * rx * k
		var z := cz + sin(a) * rz * k
		if on_ice(x, z) or in_water(x, z):
			continue
		var bad := false
		for c in clear:
			if Vector2(x - c.x, z - c.z).length() < 4.0:
				bad = true
		# 鏡頭那一側（比家豪出發點更靠近鏡頭的地方）不放，免得擋住畫面
		var cam2 := Vector2(camera_start.x, camera_start.z)
		if Vector2(x, z).distance_to(cam2) < Vector2(hero_start.x, hero_start.z).distance_to(cam2) + 9.0:
			bad = true
		if bad:
			continue
		if rng.randf() < 0.72:
			var t: String = ["tree-snow-a", "tree-snow-b", "tree-snow-c"][rng.randi() % 3]
			_prop(root, KH + t + ".glb", _g(x, z), rng.randf() * TAU, rng.randf_range(1.8, 2.8))
		else:
			var r: String = ["rocks-large", "rocks-medium", "rocks-small"][rng.randi() % 3]
			_prop(root, KH + r + ".glb", _g(x, z) + Vector3(0, -0.05, 0), rng.randf() * TAU, rng.randf_range(1.6, 2.4))
	# 冰洞＝工人的釣魚洞：旁邊有釣竿、水桶、魚；洞裡的魚偶爾跳出來
	for p in ponds:
		_fishing_hole(root, p.center, float(p.r), rng)
	for c in camps:
		_camp(root, c.pos, float(c.get("yaw", 0.0)))
	for z in zones:
		match String(z.type):
			"village": _village(root, z.pos, float(z.get("yaw", 0.0)))
			"pier": _prop(root, MB + "pier.glb", _g(z.pos.x, z.pos.z), float(z.get("yaw", 0.0)), 1.0)
			"crystals": _crystals(root, z.pos)
			"sculptures": _sculptures(root, z.pos, float(z.get("yaw", 0.0)))
			"lamps": _lamps(root, z.from, z.to)
			"creek": _creek(root, z.from, z.to)
	_snowfall(root)

func _fishing_hole(root: Node3D, c: Vector2, r: float, rng: RandomNumberGenerator) -> void:
	# 釣具放在冰洞「離鏡頭遠」的那一側，特寫時才不會橫在畫面前面
	var a := atan2(c.y - camera_start.z, c.x - camera_start.x) + rng.randf_range(-0.6, 0.6)
	var edge := Vector3(c.x + cos(a) * (r + 0.55), 0, c.y + sin(a) * (r + 0.55))
	edge.y = height_at(edge.x, edge.z)
	_clutter.append(_prop(root, KS + "bucket.glb", edge, a, 1.4))
	var f := _prop(root, KS + "fish.glb", edge + Vector3(cos(a + 1.3) * 0.55, 0.02, sin(a + 1.3) * 0.55), a + 0.6, 1.2)
	_clutter.append(f)
	if f:
		f.rotation.z = PI * 0.5   # 躺在冰上的魚
	# 釣竿：從洞邊斜斜伸到洞中央上方，垂一條線下去
	var rod := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.012
	cm.bottom_radius = 0.022
	cm.height = 1.5
	rod.mesh = cm
	rod.material_override = _toon(Color(0.45, 0.3, 0.18))
	# 短釣竿：插在洞邊，斜斜伸到洞口上方一點點
	var base := Vector3(c.x + cos(a + 0.5) * (r + 0.35), 0, c.y + sin(a + 0.5) * (r + 0.35))
	base.y = height_at(base.x, base.z) + 0.1
	var inward := Vector3(c.x - base.x, 0, c.y - base.z).normalized()
	var tip := base + inward * 1.1 + Vector3(0, 1.0, 0)
	rod.position = (base + tip) * 0.5
	rod.look_at_from_position(rod.position, tip, Vector3.UP)
	rod.rotate_object_local(Vector3.RIGHT, PI * 0.5)
	root.add_child(rod)
	_clutter.append(rod)
	var line := MeshInstance3D.new()
	var lm := CylinderMesh.new()
	lm.top_radius = 0.006
	lm.bottom_radius = 0.006
	lm.height = 1.0
	line.mesh = lm
	line.material_override = _toon(Color(0.95, 0.95, 0.95))
	line.position = tip - Vector3(0, 0.5, 0)
	root.add_child(line)
	_clutter.append(line)
	var jf := _prop(root, KS + "fish.glb", Vector3(c.x, -5, c.y), 0.0, 1.3)
	if jf:
		jf.visible = false
		_jump_fish.append({"node": jf, "center": Vector3(c.x, water_surface_y(c.x, c.y), c.y), "phase": rng.randf() * 5.0, "r": r})

## 工人的冰釣營地：帳篷、營火＋烤魚架、木桶、木箱、雪橇、燈籠、路標
func _camp(root: Node3D, p: Vector3, yaw: float) -> void:
	var fw := Vector3(sin(yaw), 0, cos(yaw))
	var rt := fw.cross(Vector3.UP)
	var at := func(f: float, r: float) -> Vector3: return _g(p.x + fw.x * f + rt.x * r, p.z + fw.z * f + rt.z * r)
	_prop(root, KS + "tent.glb", at.call(-1.6, -1.8), yaw + PI, 2.4)
	var fire_p: Vector3 = at.call(0.4, 0.6)
	_prop(root, KS + "campfire-pit.glb", fire_p, yaw, 1.8)
	_prop(root, KS + "campfire-fishing-stand.glb", fire_p, yaw + 0.3, 1.8)
	_prop(root, KS + "barrel.glb", at.call(-0.6, 2.4), yaw, 1.6)
	_prop(root, KS + "box-large.glb", at.call(-1.4, 2.6), yaw + 0.4, 1.5)
	_prop(root, KS + "box.glb", at.call(-0.9, 3.3), yaw + 0.9, 1.4)
	_prop(root, KH + "sled-long.glb", at.call(1.5, -1.6), yaw + 0.8, 1.8)
	_prop(root, KS + "fish-large.glb", at.call(1.6, -1.6) + Vector3(0, 0.45, 0), yaw + 0.8, 1.3)
	_prop(root, KH + "lantern.glb", at.call(-0.3, -0.6), yaw, 1.6)
	var sign := _prop(root, KS + "signpost-single.glb", at.call(1.2, 1.9), yaw + PI, 2.0)
	if sign:
		var l := Label3D.new()
		# 字寫在路標的木牌上（不是浮在空中的字）
		l.text = "冰釣營地\n閒雞勿近"
		l.font_size = 48
		l.pixel_size = 0.006
		l.outline_size = 6
		l.modulate = Color(0.25, 0.14, 0.06)
		l.outline_modulate = Color(0.95, 0.85, 0.6)
		l.position = Vector3(0, 0.62, -0.06)
		l.rotation.y = PI
		l.scale = Vector3.ONE / 2.0
		sign.add_child(l)
		_clutter.append(l)
	# 營火：會閃的光＋火焰
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.6, 0.25)
	light.light_energy = 2.2
	light.omni_range = 5.0
	light.position = fire_p + Vector3(0, 0.8, 0)
	root.add_child(light)
	var flame := MeshInstance3D.new()
	var fm := CylinderMesh.new()
	fm.top_radius = 0.0
	fm.bottom_radius = 0.28
	fm.height = 0.7
	flame.mesh = fm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.55, 0.15)
	flame.material_override = mat
	flame.position = fire_p + Vector3(0, 0.45, 0)
	root.add_child(flame)
	_fires.append({"light": light, "flame": flame, "base": flame.position})

## 下雪：大範圍、慢慢飄
func _snowfall(root: Node3D) -> void:
	var ps := GPUParticles3D.new()
	ps.amount = 320
	ps.lifetime = 9.0
	ps.preprocess = 9.0
	ps.visibility_aabb = AABB(Vector3(-20, -2, -20), Vector3(40, 26, 40))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(18, 0.5, 18)
	pm.direction = Vector3(0.15, -1, 0.05)
	pm.spread = 12.0
	pm.initial_velocity_min = 1.2
	pm.initial_velocity_max = 2.0
	pm.gravity = Vector3(0, -0.3, 0)
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.4
	ps.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.09, 0.09)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_color = Color(1, 1, 1, 0.9)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	q.material = m
	ps.draw_pass_1 = q
	ps.position = Vector3((play_min.x + play_max.x) * 0.5, 18, (play_min.y + play_max.y) * 0.5)
	root.add_child(ps)
	_snow_ps = ps

func _process(_dt: float) -> void:
	_animate_decor()

## 裝飾的動畫（純畫面，不影響戰局）：魚跳出冰洞、營火閃爍
func _animate_decor() -> void:
	var t := Time.get_ticks_msec() / 1000.0
	for jf in _jump_fish:
		var n: Node3D = jf.node
		var k := fmod(t + float(jf.phase), 5.5)
		if k < 0.9:
			var s := k / 0.9
			var c: Vector3 = jf.center
			var r: float = jf.r
			n.visible = true
			n.position = c + Vector3(lerpf(-r * 0.4, r * 0.4, s), sin(s * PI) * 1.3 - 0.1, 0)
			n.rotation = Vector3(0, 0, lerpf(0.9, -0.9, s))
		else:
			n.visible = false
	for f in _fires:
		var fl: OmniLight3D = f.light
		fl.light_energy = 2.0 + sin(t * 13.0) * 0.4 + sin(t * 7.3) * 0.3
		var fm: Node3D = f.flame
		fm.scale = Vector3(1.0, 1.0 + sin(t * 11.0) * 0.18, 1.0)

## 過關演出時收起小道具（釣竿、水桶、招牌字），重來時放回
func set_clutter(on: bool) -> void:
	for n in _clutter:
		if n != null and is_instance_valid(n):
			(n as Node3D).visible = on

## 俯視時暫停下雪（雪花跟時間白點長得很像）
func set_snow(on: bool) -> void:
	if _snow_ps:
		_snow_ps.visible = on

# ---------------------------------------------------------------- 冰湖周圍的區域

func _warm_light(root: Node3D, p: Vector3, energy := 1.4, rng := 4.5) -> void:
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.72, 0.4)
	l.light_energy = energy
	l.omni_range = rng
	l.position = p
	root.add_child(l)

## 冰釣小村：兩三間小屋（Blender 自製）、柴堆、雪橇、雪堆、掛燈
func _village(root: Node3D, p: Vector3, yaw: float) -> void:
	var fw := Vector3(sin(yaw), 0, cos(yaw))
	var rt := fw.cross(Vector3.UP)
	var at := func(f: float, r: float) -> Vector3: return _g(p.x + fw.x * f + rt.x * r, p.z + fw.z * f + rt.z * r)
	_prop(root, MB + "fishing_hut.glb", at.call(0.0, 0.0), yaw, 1.15)
	_prop(root, MB + "fishing_hut.glb", at.call(-2.2, 3.0), yaw + 0.35, 1.0)
	_prop(root, MB + "fishing_hut.glb", at.call(-1.0, -3.2), yaw - 0.3, 0.95)
	_prop(root, KS + "resource-wood.glb", at.call(1.4, 1.8), yaw + 0.5, 1.8)
	_prop(root, KH + "sled.glb", at.call(1.8, -1.6), yaw + 1.2, 1.6)
	_prop(root, KS + "barrel.glb", at.call(1.3, 2.9), yaw, 1.5)
	_prop(root, KH + "snow-pile.glb", at.call(-2.8, -0.6), yaw, 2.2)
	_prop(root, KH + "lantern.glb", at.call(1.6, 0.4), yaw, 1.8)
	_warm_light(root, at.call(1.6, 0.4) + Vector3(0, 1.4, 0))

## 冰晶簇（Blender 自製，半透明會發光）＋淡藍色的光
func _crystals(root: Node3D, p: Vector3) -> void:
	_prop(root, MB + "ice_crystals.glb", _g(p.x, p.z), p.x, 1.6)
	_prop(root, MB + "ice_crystals.glb", _g(p.x + 1.1, p.z + 0.6), p.x + 1.0, 1.0)
	_prop(root, MB + "ice_crystals.glb", _g(p.x - 0.8, p.z + 0.9), p.x + 2.0, 0.8)
	var l := OmniLight3D.new()
	l.light_color = Color(0.55, 0.85, 1.0)
	l.light_energy = 1.2
	l.omni_range = 4.0
	l.position = _g(p.x, p.z) + Vector3(0, 1.4, 0)
	root.add_child(l)

## 冰雕公園：雪做的台座上，冰雕的企鵝和魚（彩蛋）
func _sculptures(root: Node3D, p: Vector3, yaw: float) -> void:
	var ice := StandardMaterial3D.new()
	ice.albedo_color = Color(0.72, 0.9, 1.0, 0.62)
	ice.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ice.roughness = 0.05
	ice.metallic_specular = 1.0
	ice.emission_enabled = true
	ice.emission = Color(0.2, 0.42, 0.6)
	ice.rim_enabled = true
	ice.rim = 0.8
	var rt := Vector3(cos(yaw), 0, -sin(yaw))
	var spots := [[-1.6, MP + "penguin_stand.glb", 1.5], [0.0, MP + "penguin_stand.glb", 2.0], [1.6, KS + "fish-large.glb", 2.2]]
	for sp in spots:
		var q: Vector3 = _g(p.x, p.z) + rt * float(sp[0])
		var base := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(1.0, 0.5, 1.0)
		base.mesh = bm
		base.material_override = _snow_mat
		base.position = q + Vector3(0, 0.25, 0)
		root.add_child(base)
		var st := _prop(root, String(sp[1]), q + Vector3(0, 0.5, 0), yaw, float(sp[2]))
		if st:
			for m in st.find_children("*", "MeshInstance3D", true, false):
				(m as MeshInstance3D).material_override = ice

## 路兩旁的燈籠（家豪出發的那條路）
func _lamps(root: Node3D, a: Vector3, b: Vector3) -> void:
	var d := b - a
	d.y = 0.0
	var n := maxi(int(d.length() / 2.5), 1)
	var side := d.normalized().cross(Vector3.UP) * 1.5
	for k in n + 1:
		var q := a.lerp(b, float(k) / n)
		for sgn in [-1.0, 1.0]:
			var pos: Vector3 = q + side * sgn
			_prop(root, KH + "lantern.glb", _g(pos.x, pos.z), 0.0, 1.5)
	_warm_light(root, _g(a.x, a.z) + Vector3(0, 1.2, 0), 1.0, 5.0)

## 結冰的小溪：一段一段淡藍色的冰面，兩旁一點雪堆
func _creek(root: Node3D, a: Vector3, b: Vector3) -> void:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.62, 0.82, 0.95)
	m.roughness = 0.2
	m.metallic_specular = 0.6
	var d := b - a
	d.y = 0.0
	var n := maxi(int(d.length() / 1.2), 1)
	var side := d.normalized().cross(Vector3.UP)
	for k in n:
		var t0 := float(k) / n
		var q := a.lerp(b, t0 + 0.5 / n) + side * sin(t0 * 6.0) * 0.6
		var seg := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 1.0
		cm.bottom_radius = 1.0
		cm.height = 0.05
		cm.radial_segments = 12
		seg.mesh = cm
		seg.material_override = m
		seg.position = _g(q.x, q.z) + Vector3(0, 0.02, 0)
		seg.scale = Vector3(1.0 - 0.3 * t0, 1.0, 1.0 - 0.3 * t0)
		root.add_child(seg)
		if k % 2 == 0:
			var bank: Vector3 = q + side * (1.3 if k % 4 == 0 else -1.3)
			_prop(root, KH + "snow-pile.glb", _g(bank.x, bank.z) + Vector3(0, -0.15, 0), t0 * 3.0, 1.2)
