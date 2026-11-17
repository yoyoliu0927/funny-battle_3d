extends RefCounted
## 選關地圖上的「油畫秋島」（chapter.gd 的 MAP_SCRIPT；由 scripts/level_select.gd 呼叫，不是關卡腳本）。
## 整個大關是一座秋天的油畫島，跟關卡裡同一套畫法：地面、岩壁、葉子、岩漿、河水都用關卡自己的著色器，
## 所以從地圖上看就是關卡裡那座島的縮小版。三個小關是島上的三個地點：
##   1 南岸・午後：風車和滾石　2 北岸・黃昏：水池和鞭炮攤　3 高原・夜晚：火山
## 島的上空懸著一雙半透明的神之手（關卡裡第一人稱的那雙手，放大好幾倍）。
## 島的網格借用冰雪島的 art/isle_builder.gd（只是算形狀的工具，跟冰雪無關）。

const Isle := preload("res://levels/ice/art/isle_builder.gd")
const GROUND := preload("res://levels/liuchiyu/shaders/oil_ground.gdshader")
const ROCK := preload("res://levels/liuchiyu/shaders/oil_rock.gdshader")
const LEAF := preload("res://levels/liuchiyu/shaders/oil_leaf.gdshader")
const LAVA := preload("res://levels/liuchiyu/shaders/oil_lava.gdshader")
const RIVER := preload("res://levels/liuchiyu/shaders/oil_river.gdshader")
const GHOST := preload("res://levels/liuchiyu/shaders/map_hand.gdshader")
const A := "res://levels/liuchiyu/assets/"
const KH := A + "kaykit_halloween/"
const KT := A + "kenney_town/"
const KG := A + "kenney_graveyard/"
const QV := A + "quaternius_village/"
const ARMS := A + "hand/arms_rig.glb"
const BOULDER := A + "polyhaven/boulder_01/boulder_01.gltf"
const WINDMILL := "res://assets/farm/Windmill.glb"

## 葉子的顏色（跟 oil_world.gd 的 LEAF_COLORS 同一組：黃、橘為主，一點紅）
const LEAF_COLORS := [
	Color(0.90, 0.62, 0.16), Color(0.84, 0.46, 0.12), Color(0.92, 0.70, 0.24), Color(0.72, 0.34, 0.12),
	Color(0.56, 0.24, 0.12), Color(0.70, 0.44, 0.14), Color(0.94, 0.74, 0.30), Color(0.78, 0.52, 0.18),
]
const LEAF_SHADE := Color(0.34, 0.14, 0.12)       # 背光那一面的葉子往這個顏色靠
const SUN_DIR := Vector3(-0.36, 0.89, -0.27)
const TREES := [["tree_dead_large.gltf", 5.07], ["tree_dead_medium.gltf", 4.19], ["tree_dead_small.gltf", 2.99]]   # [模型, 原本多高]
const MOUND_R := 6.0            # 高原（火山腳下那塊台地）的半徑
const MOUND_H := 2.0            # 高原比島面高多少
const VOLCANO_H := 3.4
const HAND_SCALE := 32.0        # 神之手放大幾倍
const HAND_Y := -5.0            # 肩膀在海面下多深（手臂從海裡伸上來）
const HAND_BACK := 7.0          # 肩膀在島的北岸再往北多遠（手掌在肩膀南邊大約 5 公尺，剛好貼著北岸）
const HAND_LEAN := 12.0         # 往島這邊傾幾度

var _top_y := 1.5
var _ctx := {}
var _o := {}                    # 島的輪廓（Isle 用的字典）
var _mound := Vector2(INF, INF) # 高原的中心（第 3 小關的地標那裡）
var _spring := Vector2.ZERO     # 小溪的源頭
var _leaf_xf: Array[Transform3D] = []
var _leaf_col: Array[Color] = []
var _rng := RandomNumberGenerator.new()
var _rock_mat: ShaderMaterial
var _leaf_mat: ShaderMaterial

# ================================================================== 給 level_select.gd 呼叫的函式

## 走到第 k 小關時的天色：午後的金黃 → 黃昏 → 火山的夜
func mood(k: int) -> Dictionary:
	match k:
		0:
			return {
				"sun": Color(1.0, 0.88, 0.60), "energy": 1.8, "rot": Vector3(-0.78, 0.62, 0),
				"amb": Color(0.82, 0.70, 0.56), "amb_e": 0.95, "fog": Color(0.94, 0.88, 0.68),
				"sky.top_color": Color(0.60, 0.74, 0.80), "sky.horizon_color": Color(0.97, 0.91, 0.66),
				"sky.cloud_color": Color(1.0, 0.97, 0.84), "sky.cloud_shade": Color(0.90, 0.80, 0.62),
				"sea.deep": Color(0.15, 0.33, 0.46), "sea.near_c": Color(0.30, 0.50, 0.58), "sea.stroke_c": Color(0.80, 0.88, 0.84),
				"sea.foam_c": Color(0.98, 0.97, 0.90), "sea.horizon_c": Color(0.92, 0.87, 0.68),
			}
		1:
			return {
				"sun": Color(1.0, 0.64, 0.40), "energy": 1.55, "rot": Vector3(-0.42, 1.0, 0),
				"amb": Color(0.72, 0.54, 0.58), "amb_e": 0.9, "fog": Color(0.92, 0.66, 0.52),
				"sky.top_color": Color(0.36, 0.38, 0.62), "sky.horizon_color": Color(0.98, 0.66, 0.44),
				"sky.cloud_color": Color(1.0, 0.80, 0.66), "sky.cloud_shade": Color(0.66, 0.44, 0.52),
				"sea.deep": Color(0.12, 0.22, 0.40), "sea.near_c": Color(0.34, 0.38, 0.52), "sea.stroke_c": Color(0.98, 0.76, 0.62),
				"sea.foam_c": Color(1.0, 0.92, 0.84), "sea.horizon_c": Color(0.92, 0.62, 0.48),
			}
		_:
			return {
				"sun": Color(0.70, 0.78, 1.0), "energy": 1.25, "rot": Vector3(-0.9, -0.5, 0),
				"amb": Color(0.46, 0.50, 0.72), "amb_e": 1.25, "fog": Color(0.20, 0.18, 0.32),
				"sky.top_color": Color(0.05, 0.08, 0.22), "sky.horizon_color": Color(0.42, 0.22, 0.28),
				"sky.cloud_color": Color(0.40, 0.36, 0.52), "sky.cloud_shade": Color(0.14, 0.14, 0.28),
				"sea.deep": Color(0.03, 0.08, 0.20), "sea.near_c": Color(0.10, 0.20, 0.36), "sea.stroke_c": Color(0.50, 0.62, 0.86),
				"sea.foam_c": Color(0.80, 0.86, 0.98), "sea.horizon_c": Color(0.32, 0.20, 0.30),
			}

## 島面高度（路、站點、家豪都貼在上面）：緩緩起伏，第 3 小關那裡隆起一塊岩石高原
func ground_y(x: float, z: float) -> float:
	var y := _top_y + 0.12 * sin(x * 0.5 + 1.0) * cos(z * 0.6)
	if _mound.x != INF:
		y += MOUND_H * smoothstep(MOUND_R, MOUND_R * 0.4, Vector2(x, z).distance_to(_mound))
	return y

## 蓋整座島（世界座標；y = 0 是海面）
func build_island(root: Node3D, ctx: Dictionary) -> void:
	_ctx = ctx
	_top_y = float(ctx.get("top_y", 1.5))
	_rng.seed = 20261118
	var c: Vector2 = ctx.center
	var spots: Array = ctx.spots
	var pads: Array = ctx.pads
	if spots.size() >= 3:
		_mound = Vector2(spots[2].x + 0.6, spots[2].z - 0.6)
	_o = {"c": c, "rx": float(ctx.rx), "rz": float(ctx.rz), "seed": 5.1, "pow": 2.6, "wob": 1.5, "depth": _top_y + 1.4, "slope": 0.22, "lobe": 2.6,
		"coves": [[1.2, 2.2, 0.20], [2.9, 1.8, 0.16], [4.6, 2.0, 0.18]]}
	_rock_mat = ShaderMaterial.new()
	_rock_mat.shader = ROCK
	_leaf_mat = ShaderMaterial.new()
	_leaf_mat.shader = LEAF
	# 島面：油畫地面（滿地落葉的筆觸）；陡的地方畫成岩石
	var top := MeshInstance3D.new()
	top.name = "Top"
	top.mesh = _painted_top(Isle.build_top(_o, ground_y, 128, 14, 0.4))
	var gm := ShaderMaterial.new()
	gm.shader = GROUND
	top.material_override = gm
	root.add_child(top)
	var cliff := MeshInstance3D.new()
	cliff.name = "Cliff"
	cliff.mesh = Isle.build_cliff(_o, func(a: float) -> float:
		var p := Isle.rim_point(_o, a)
		return ground_y(p.x, p.y), 128, 6)
	cliff.material_override = _rock_mat
	root.add_child(cliff)
	# 小溪：從路南邊的泉眼流到南岸，掉下懸崖變成瀑布（從前一座島看過來正好看得到）
	if pads.size() >= 2:
		_build_stream(root, ((pads[0] as Vector3) + (pads[1] as Vector3)) * 0.5)
	# 空地上的秋天的樹和石頭（不擋路、不擋地標）
	var placed := 0
	for i in 500:
		if placed >= 22:
			break
		var a := _rng.randf() * TAU
		var d := Isle.radius(_o, a) * sqrt(_rng.randf()) - 1.6
		var x := c.x + cos(a) * d
		var z := c.y + sin(a) * d
		if d < 0.0 or not _free(x, z):
			continue
		var g := Vector3(x, ground_y(x, z), z)
		if placed % 5 == 4:
			_rock(root, g - Vector3(0, 0.15, 0), _rng.randf_range(0.9, 1.5))
		else:
			# 路南邊的樹離鏡頭近，矮一點才不會擋住畫面
			var near_cam := z > _path_z(x) + 2.0
			_oil_tree(root, g, _rng.randf_range(1.9, 2.5) if near_cam else _rng.randf_range(2.8, 3.8), placed)
		placed += 1
	_flush_leaves(root)
	# 海上幾塊礁石
	for i in 7:
		var a := (i + _rng.randf_range(-0.3, 0.3)) * TAU / 7.0
		var d := Isle.cliff_radius(_o, a, _top_y) + _rng.randf_range(2.5, 6.0)
		_rock(root, Vector3(c.x + cos(a) * d, -0.3, c.y + sin(a) * d), _rng.randf_range(1.2, 2.4))
	_god_hands(root, Vector3(c.x, _top_y, c.y))

## 蓋第 k 小關的地標（root 在那個地點的島面上，+z 是鏡頭和站點那一邊）
func build_spot(k: int, root: Node3D, _c: Dictionary) -> void:
	match k:
		0: _south_shore(root)
		1: _north_shore(root)
		_: _plateau(root)
	_flush_leaves(root)

# ================================================================== 三個地點

## 1 南岸：風車、滾石、木柵欄、南瓜
func _south_shore(root: Node3D) -> void:
	_fit(root, WINDMILL, Vector3(-0.4, -0.05, -1.4), 0.5, 4.6)
	_rock(root, Vector3(2.4, -0.1, -0.6), 1.5)
	_rock(root, Vector3(3.2, -0.1, 0.9), 1.0)
	_rock(root, Vector3(-2.9, -0.1, 0.6), 1.1)
	_prop(root, QV + "Prop_Wagon.gltf", Vector3(1.6, 0, 1.7), 1.0, 0.42)
	_prop(root, KH + "pumpkin_orange.gltf", Vector3(-1.9, 0, 1.6), 0.4, 0.7)
	_prop(root, KH + "pumpkin_orange_small.gltf", Vector3(-1.2, 0, 2.0), 1.4, 0.8)
	_oil_tree(root, Vector3(-3.3, 0, -2.2), 3.6, 0)
	_oil_tree(root, Vector3(3.3, 0, -2.6), 3.0, 1)
	root.set_meta("bubble_y", 5.6)

## 2 北岸：淺水池、賣鞭炮的紅攤子、燈籠、長椅
func _north_shore(root: Node3D) -> void:
	_pool(root, Vector3(-0.6, 0.05, -0.6), 2.4, 1.7)
	_prop(root, KT + "stall-red.glb", Vector3(2.5, 0, -1.6), -0.5, 1.7)
	_prop(root, QV + "Prop_Crate.gltf", Vector3(3.4, 0, -0.2), 0.3, 0.6)
	_prop(root, KH + "post_lantern.gltf", Vector3(1.4, 0, 1.4), 0.0, 0.8)
	_light(root, Vector3(1.4, 2.2, 1.9), Color(1.0, 0.70, 0.36), 1.6, 5.0)
	_prop(root, KH + "bench_decorated.gltf", Vector3(-2.7, 0, 1.5), 0.6, 0.7)
	_prop(root, KH + "pumpkin_orange_jackolantern.gltf", Vector3(-3.3, 0, -0.8), 0.9, 0.55)
	_rock(root, Vector3(-2.6, -0.1, -2.0), 1.2)
	_oil_tree(root, Vector3(-0.4, 0, -3.2), 3.4, 2)
	_oil_tree(root, Vector3(3.5, 0, -3.0), 2.8, 1)
	root.set_meta("bubble_y", 4.8)

## 3 高原：火山（火山口和兩道岩漿）、火盆、枯樹
func _plateau(root: Node3D) -> void:
	var h := VOLCANO_H
	var prof := [Vector2(0.05, h - 0.85), Vector2(0.80, h - 0.70), Vector2(1.10, h), Vector2(1.55, h - 0.55),
		Vector2(2.2, h * 0.5), Vector2(3.0, 0.5), Vector2(3.9, -0.15)]
	var cone := MeshInstance3D.new()
	cone.name = "Volcano"
	cone.mesh = _lathe(prof, 36, 3.7)
	cone.material_override = _rock_mat
	cone.position = Vector3(0.2, 0, -1.2)
	root.add_child(cone)
	var lava_mat := ShaderMaterial.new()
	lava_mat.shader = LAVA
	# 火山口裡的岩漿湖
	var lake := MeshInstance3D.new()
	lake.mesh = _lathe([Vector2(0.02, 0.0), Vector2(0.55, 0.0), Vector2(1.02, 0.0)], 24, 3.7)
	lake.material_override = lava_mat
	lake.position = cone.position + Vector3(0, h - 0.5, 0)
	root.add_child(lake)
	# 兩道流下來的岩漿（朝鏡頭這一面）
	for a in [1.25, 2.15]:
		var pts := PackedVector3Array()
		for i in 13:
			var t := i / 12.0
			var r := lerpf(1.02, 3.3, t)
			var y := _profile_y(prof, r) + 0.06
			var aa: float = a + 0.22 * sin(t * 5.0 + a * 3.0)
			pts.append(cone.position + Vector3(cos(aa) * r * _lathe_wob(aa, 3.7), y, sin(aa) * r * _lathe_wob(aa, 3.7)))
		var s := MeshInstance3D.new()
		s.mesh = _ribbon(pts, 0.42, 0.0, 0.0)
		s.material_override = lava_mat
		root.add_child(s)
	_light(root, cone.position + Vector3(0, h + 0.8, 0), Color(1.0, 0.45, 0.12), 3.0, 9.0)
	_light(root, cone.position + Vector3(0.6, 1.2, 2.6), Color(1.0, 0.40, 0.10), 1.6, 5.0)
	_prop(root, KG + "fire-basket.glb", Vector3(3.0, 0, 1.6), 0.0, 2.2)
	_light(root, Vector3(3.0, 0.9, 1.6), Color(1.0, 0.62, 0.25), 1.4, 4.0)
	_prop(root, KH + "tree_dead_small.gltf", Vector3(-3.4, 0.2, 1.0), 1.0, 0.8)
	_prop(root, KH + "tree_dead_medium.gltf", Vector3(3.6, 0.2, -1.6), 2.0, 0.7)
	_rock(root, Vector3(-2.6, 0.0, 2.2), 1.0)
	root.set_meta("bubble_y", 6.2)

# ================================================================== 樹、石頭、水、手

## 這個位置能不能放裝飾（離路、站點、地標、小溪夠遠）
func _free(x: float, z: float) -> bool:
	var p := Vector2(x, z)
	var pads: Array = _ctx.pads
	for k in pads.size():
		var a := Vector2(pads[k].x, pads[k].z)
		if p.distance_to(a) < 3.2:
			return false
		if absf(x - a.x) < 4.6 and z > a.y:      # 站點正前方（鏡頭那一邊）留空：樹才不會擋住家豪和旗子
			return false
		if k + 1 < pads.size():
			var b := Vector2(pads[k + 1].x, pads[k + 1].z)
			if Geometry2D.get_closest_point_to_segment(p, a, b).distance_to(p) < 2.6:
				return false
		var sp: Vector3 = _ctx.spots[k]
		if p.distance_to(Vector2(sp.x, sp.z)) < 5.0:
			return false
	if p.distance_to(_mound) < MOUND_R:
		return false
	if absf(x - _spring.x) < 1.8 and z > _spring.y - 1.5:
		return false
	return true

## 路在這個 x 大約在哪個 z（用最近的站點）
func _path_z(x: float) -> float:
	var best := 0.0
	var bd := INF
	for p in _ctx.pads:
		if absf(x - p.x) < bd:
			bd = absf(x - p.x)
			best = p.z
	return best

## 一棵油畫的樹：枯樹模型當樹幹，枝頭一團一團的葉子是一筆一筆的顏料（葉子先記起來，_flush_leaves() 一次畫）
func _oil_tree(parent: Node3D, pos: Vector3, height: float, kind: int) -> void:
	var t: Array = TREES[kind % TREES.size()]
	var s := height / float(t[1])
	_prop(parent, KH + String(t[0]), pos + Vector3(0, 0.28 * s, 0), _rng.randf() * TAU, s)
	var tint: Color = LEAF_COLORS[_rng.randi() % LEAF_COLORS.size()]
	for i in 6:
		var a := _rng.randf() * TAU
		var d := height * _rng.randf_range(0.05, 0.26)
		var cc := pos + Vector3(cos(a) * d, height * _rng.randf_range(0.62, 0.98), sin(a) * d)
		_leaf_clump(cc, height * _rng.randf_range(0.20, 0.28), 20, tint, height / 3.4)

func _leaf_clump(c: Vector3, rc: float, n: int, tint: Color, size: float) -> void:
	for k in n:
		var o := Vector3(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-0.6, 0.75), _rng.randf_range(-1.0, 1.0))
		if o.length() > 1.0:
			o = o.normalized() * _rng.randf_range(0.5, 1.0)
		var s := _rng.randf_range(0.55, 1.0) * size
		var b := Basis.from_euler(Vector3(_rng.randf_range(-1.2, 1.2), _rng.randf() * TAU, _rng.randf_range(-0.8, 0.8))).scaled(Vector3(s, s * 0.6, s))
		_leaf_xf.append(Transform3D(b, c + o * rc))
		var col: Color = LEAF_COLORS[_rng.randi() % LEAF_COLORS.size()]
		if _rng.randf() < 0.72:
			col = tint
		var v := _rng.randf_range(0.82, 1.12)
		col = Color(col.r * v, col.g * v, col.b * v)
		# 朝太陽那一面用亮的顏色，背光那一面混進深紅棕
		var lit := clampf(o.normalized().dot(SUN_DIR.normalized()) * 0.75 + 0.5 + _rng.randf_range(-0.2, 0.2), 0.0, 1.0)
		col = LEAF_SHADE.lerp(col, 0.25 + 0.75 * lit)
		if lit > 0.8:
			col = col.lerp(Color(1.0, 0.93, 0.55), 0.3)
		_leaf_col.append(col)

## 把記起來的葉子做成一個 MultiMesh 掛到 parent 底下
func _flush_leaves(parent: Node3D) -> void:
	if _leaf_xf.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var qm := QuadMesh.new()
	qm.size = Vector2(1.0, 1.0)
	mm.mesh = qm
	mm.instance_count = _leaf_xf.size()
	for i in _leaf_xf.size():
		mm.set_instance_transform(i, _leaf_xf[i])
		mm.set_instance_color(i, _leaf_col[i])
	var mi := MultiMeshInstance3D.new()
	mi.name = "Leaves"
	mi.multimesh = mm
	mi.material_override = _leaf_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	_leaf_xf.clear()
	_leaf_col.clear()

## 一塊石頭（巨石模型，換成油畫岩石的畫法）。size = 大約多寬（公尺）
func _rock(parent: Node3D, pos: Vector3, size: float) -> void:
	var n := _fit(parent, BOULDER, pos, _rng.randf() * TAU, size)
	if n:
		for m in n.find_children("*", "MeshInstance3D", true, false):
			(m as MeshInstance3D).material_override = _rock_mat

## 淺水池：不規則的一灘水（關卡裡河水的畫法）
func _pool(parent: Node3D, pos: Vector3, rx: float, rz: float) -> void:
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	verts.append(Vector3.ZERO)
	uvs.append(Vector2(0.5, 0.0))
	cols.append(Color(0, 0, 0))
	var n := 28
	for i in n:
		var a := i * TAU / n
		var k := 1.0 + 0.12 * sin(a * 3.0 + 1.0) + 0.08 * sin(a * 5.0)
		verts.append(Vector3(cos(a) * rx * k, 0, sin(a) * rz * k))
		uvs.append(Vector2(0.5 + 0.5 * cos(a), sin(a) * rz * k))
		cols.append(Color(0, 0, 0))
		idx.append_array([0, 1 + (i + 1) % n, 1 + i])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := MeshInstance3D.new()
	mi.name = "Pool"
	mi.mesh = mesh
	var m := ShaderMaterial.new()
	m.shader = RIVER
	m.set_shader_parameter("flow", 0.25)
	m.set_shader_parameter("width", rx * 2.0)
	mi.material_override = m
	mi.position = pos
	parent.add_child(mi)

## 小溪＋瀑布：從 from 往南流到岸邊，再順著懸崖掉進海裡
func _build_stream(root: Node3D, mid: Vector3) -> void:
	var c: Vector2 = _o.c
	var x0 := mid.x + 0.8
	_spring = Vector2(x0, mid.z + 3.4)
	var a := atan2((c.y + float(_o.rz)) - c.y, x0 - c.x)
	var rim := Isle.rim_point(_o, a, -0.25)
	var pts := PackedVector3Array()
	var falls := PackedFloat32Array()
	for i in 9:
		var t := i / 8.0
		var x := lerpf(_spring.x, rim.x, t) + 0.5 * sin(t * 5.0)
		var z := lerpf(_spring.y, rim.y, t)
		pts.append(Vector3(x, ground_y(x, z) + 0.05, z))
		falls.append(0.0)
	var edge := pts[pts.size() - 1]
	for i in 6:
		var t := (i + 1) / 6.0
		pts.append(Vector3(edge.x, lerpf(edge.y, 0.05, t), edge.z + 0.35 + 0.5 * t))
		falls.append(1.0)
	var mi := MeshInstance3D.new()
	mi.name = "Stream"
	mi.mesh = _ribbon(pts, 1.1, 0.0, 1.0, falls)
	var m := ShaderMaterial.new()
	m.shader = RIVER
	m.set_shader_parameter("width", 1.1)
	mi.material_override = m
	root.add_child(mi)
	_rock(root, Vector3(_spring.x - 0.2, ground_y(_spring.x, _spring.y) - 0.1, _spring.y - 0.7), 1.4)
	_rock(root, Vector3(edge.x - 1.1, edge.y - 0.2, edge.z - 0.3), 1.0)
	_rock(root, Vector3(edge.x + 1.2, edge.y - 0.2, edge.z - 0.2), 1.2)

## 神之手：關卡裡那雙半透明的手放大好幾倍，從島北邊的海裡伸上來，掌心朝著島，像捧著這座島
func _god_hands(root: Node3D, center: Vector3) -> void:
	var ps := load(ARMS) as PackedScene
	if ps == null:
		return
	var holder := Node3D.new()
	holder.name = "GodHands"
	root.add_child(holder)
	# 模型裡手指朝 +Z、手背朝 +Y：立起來讓手指朝上、掌心朝南（朝著島和鏡頭），再往島這邊傾一點
	var b := Basis(Vector3.RIGHT, deg_to_rad(HAND_LEAN)) * Basis(Vector3.RIGHT, -PI * 0.5)
	holder.transform = Transform3D(b.scaled(Vector3.ONE * HAND_SCALE), Vector3(center.x, HAND_Y, center.z - float(_o.rz) - HAND_BACK))
	var arms := ps.instantiate() as Node3D
	arms.position = Vector3(0.0, -1.743, 0.0)       # 模型的「眼睛」在 1.743 公尺高：移到原點（肩膀就在原點附近）
	holder.add_child(arms)
	var mat := ShaderMaterial.new()
	mat.shader = GHOST
	mat.render_priority = 10            # 比海面（也是半透明）晚畫，不然背景是海的地方手會被海蓋掉
	mat.set_shader_parameter("body_alpha", 0.30)
	mat.set_shader_parameter("rim_alpha", 0.95)
	mat.set_shader_parameter("glow", 0.2)
	for m in arms.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		var src := mi.get_active_material(0) as BaseMaterial3D
		if src and src.albedo_texture:
			mat.set_shader_parameter("skin_tex", src.albedo_texture)
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.extra_cull_margin = 60.0
	var ap := arms.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap and ap.has_animation("relax"):
		ap.get_animation("relax").loop_mode = Animation.LOOP_LINEAR
		ap.speed_scale = 0.5
		ap.play("relax")

# ================================================================== 網格和模型的小工具

## 頂面的網格加上頂點顏色：地面著色器用藍色那一格當「多陡」（陡的地方畫成岩石）
func _painted_top(mesh: ArrayMesh) -> ArrayMesh:
	var arr := mesh.surface_get_arrays(0)
	var nrm: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var cols := PackedColorArray()
	cols.resize(nrm.size())
	for i in nrm.size():
		cols[i] = Color(0, 0, clampf((1.0 - nrm[i].y) * 2.4, 0.0, 1.0))
	arr[Mesh.ARRAY_COLOR] = cols
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return out

static func _lathe_wob(a: float, seed: float) -> float:
	return 1.0 + 0.10 * sin(a * 3.0 + seed) + 0.06 * sin(a * 7.0 + seed * 2.0)

## 旋轉體（火山）：profile 是一串 (半徑, 高度)，從中心往外排
func _lathe(profile: Array, segs: int, seed: float) -> ArrayMesh:
	var verts := PackedVector3Array()
	for si in segs:
		var a := si * TAU / segs
		var w := _lathe_wob(a, seed)
		for p in profile:
			var q: Vector2 = p
			verts.append(Vector3(cos(a) * q.x * w, q.y, sin(a) * q.x * w))
	var idx := Isle._grid_indices(segs, profile.size(), true)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = Isle._normals(verts, idx)
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

## profile 上半徑 r 那裡的高度
func _profile_y(profile: Array, r: float) -> float:
	for i in profile.size() - 1:
		var a: Vector2 = profile[i]
		var b: Vector2 = profile[i + 1]
		if r >= a.x and r <= b.x:
			return lerpf(a.y, b.y, (r - a.x) / maxf(b.x - a.x, 0.001))
	return (profile[profile.size() - 1] as Vector2).y

## 沿著一串點鋪一條帶子（河、岩漿）。UV.x = 橫向 0～1、UV.y = 沿著帶子的公尺數；COLOR.r = fall（瀑布那一段是 1）
func _ribbon(pts: PackedVector3Array, width: float, fall0: float, _fall1: float, falls := PackedFloat32Array()) -> ArrayMesh:
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	var dist := 0.0
	for i in pts.size():
		var p := pts[i]
		var dir := (pts[mini(i + 1, pts.size() - 1)] - pts[maxi(i - 1, 0)]).normalized()
		var side := Vector3(dir.z, 0, -dir.x)
		if side.length() < 0.05:
			side = Vector3(1, 0, 0)        # 垂直往下掉的那一段：帶子朝東西向展開
		side = side.normalized() * width * 0.5
		if i > 0:
			dist += p.distance_to(pts[i - 1])
		var f := falls[i] if i < falls.size() else fall0
		verts.append(p - side)
		verts.append(p + side)
		uvs.append(Vector2(0.0, dist))
		uvs.append(Vector2(1.0, dist))
		cols.append(Color(f, 0, 0))
		cols.append(Color(f, 0, 0))
		if i > 0:
			var b := i * 2
			idx.append_array([b - 2, b - 1, b, b - 1, b + 1, b])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

## 放一個模型（scale 是倍率）
func _prop(parent: Node3D, path: String, pos: Vector3, yaw := 0.0, scale := 1.0) -> Node3D:
	if not ResourceLoader.exists(path):
		push_warning("油畫秋島地圖：找不到模型 " + path)
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

## 放一個模型，縮放到最長邊 = size 公尺，底部貼在 pos
func _fit(parent: Node3D, path: String, pos: Vector3, yaw: float, size: float) -> Node3D:
	if not ResourceLoader.exists(path):
		push_warning("油畫秋島地圖：找不到模型 " + path)
		return null
	var ps := load(path) as PackedScene
	if ps == null:
		return null
	var holder := Node3D.new()
	holder.position = pos
	holder.rotation.y = yaw
	parent.add_child(holder)
	var n := ps.instantiate() as Node3D
	holder.add_child(n)
	var bb := _bounds(n, Transform3D.IDENTITY)
	var s := size / maxf(maxf(bb.size.x, bb.size.y), maxf(bb.size.z, 0.001))
	var c := bb.get_center()
	n.transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * s), -Vector3(c.x, bb.position.y, c.z) * s) * n.transform
	return holder

func _bounds(node: Node, xf: Transform3D) -> AABB:
	var out := AABB()
	var have := false
	if node is Node3D:
		xf = xf * (node as Node3D).transform
	if node is MeshInstance3D and (node as MeshInstance3D).mesh:
		out = xf * (node as MeshInstance3D).mesh.get_aabb()
		have = true
	for ch in node.get_children():
		var b := _bounds(ch, xf)
		if b.size != Vector3.ZERO:
			out = out.merge(b) if have else b
			have = true
	return out

func _light(parent: Node3D, p: Vector3, col: Color, energy: float, rng: float) -> void:
	var l := OmniLight3D.new()
	l.light_color = col
	l.light_energy = energy
	l.omni_range = rng
	l.light_specular = 0.0
	l.position = p
	parent.add_child(l)
