extends RefCounted
## 選關地圖上的駁大莖森島（chapter.gd 的 MAP_SCRIPT；由 scripts/level_select.gd 呼叫）。
## 駁大莖森：一座長滿樹的島。三個地標依小關順序：0 伐木場（柴堆和樹墩）、1 煙圈（營火冒煙）、2 狼外婆的木屋。
## （合併進 develop 時改過：島的本體換成不規則海岸＋土崖的網格，樹換成整片樹林；天色和三個地標照原樣。）

const Isle := preload("res://levels/ice/art/isle_builder.gd")
const TOP := 1.5
const BIRCH := "res://assets/nature/BirchTree.glb"
const BUSH := "res://assets/nature/BushBerries.glb"
const TEX := "res://assets/textures/"
const SURV := "res://levels/forest/assets/kenney_survival/"
const CASTLE := "res://levels/forest/assets/kenney_castle/"

func mood(_k: int) -> Dictionary:
	return {
		"sun": Color(1.0, 0.96, 0.78), "amb": Color(0.52, 0.76, 0.48),
		"fog": Color(0.70, 0.88, 0.68),
		"sky.top_color": Color(0.36, 0.66, 0.90), "sky.horizon_color": Color(0.76, 0.90, 0.70),
		"sky.cloud_color": Color(0.96, 0.98, 0.92), "sky.cloud_shade": Color(0.68, 0.82, 0.64),
		"sea.deep": Color(0.07, 0.38, 0.50), "sea.near_c": Color(0.16, 0.54, 0.56),
		"sea.horizon_c": Color(0.68, 0.86, 0.72),
	}

## 島面高度：緩緩起伏的林地
func ground_y(x: float, z: float) -> float:
	return TOP + 0.14 * sin(x * 0.6 + 0.5) * cos(z * 0.5)

## 蓋整座島（世界座標；y = 0 是海面）：不規則的海岸、一層一層的土崖，島上長滿了樹，只有路、站點和地標周圍是空地。
## 島的網格借用冰雪島的 art/isle_builder.gd（只是算形狀的工具，跟冰雪無關）；樹和灌木是共用的 assets/nature。
func build_island(root: Node3D, ctx: Dictionary) -> void:
	var c: Vector2 = ctx.center
	var o := {"c": c, "rx": float(ctx.rx), "rz": float(ctx.rz), "seed": 3.7, "pow": 2.4, "wob": 1.6, "depth": TOP + 1.4, "slope": 0.20, "lobe": 2.4,
		"coves": [[0.6, 1.6, 0.20], [2.4, 1.8, 0.18], [4.3, 1.5, 0.16], [5.5, 1.3, 0.14]]}
	var top := MeshInstance3D.new()
	top.name = "Top"
	top.mesh = Isle.build_top(o, ground_y, 112, 12, 0.4)
	top.material_override = _tex_mat("grass_ground_diff_1k.jpg", Color(0.52, 1.05, 0.40), 0.2)
	root.add_child(top)
	var cliff := MeshInstance3D.new()
	cliff.name = "Cliff"
	cliff.mesh = Isle.build_cliff(o, func(a: float) -> float:
		var p := Isle.rim_point(o, a)
		return ground_y(p.x, p.y), 112, 6)
	var cm := _tex_mat("forest_ground_04_diff_1k.jpg", Color(1.0, 0.78, 0.56), 0.16)
	cm.vertex_color_use_as_albedo = true        # isle_builder 給每一層不同的明暗
	cliff.material_override = cm
	root.add_child(cliff)
	# 樹林：能種的地方都種（樹和樹之間留一點距離），靠鏡頭那一側種矮一點；空隙補灌木
	var rng := RandomNumberGenerator.new()
	rng.seed = 481516
	var trees: Array[Vector2] = []
	for i in 1200:
		var a := rng.randf() * TAU
		var d := Isle.radius(o, a) * sqrt(rng.randf()) - 1.3
		var x := c.x + cos(a) * d
		var z := c.y + sin(a) * d
		if d < 0.0 or not _clear(ctx, x, z):
			continue
		var p := Vector2(x, z)
		var near := INF
		for q in trees:
			near = minf(near, p.distance_to(q))
		var g := Vector3(x, ground_y(x, z) - 0.05, z)
		if near > 2.0:
			var south := z > float(ctx.pads[0].z) + 2.0
			_model(root, BIRCH, g, rng.randf() * TAU, rng.randf_range(2.0, 2.6) if south else rng.randf_range(2.8, 4.2))
			trees.append(p)
		elif near > 1.1 and rng.randf() < 0.35:
			_model(root, BUSH, g, rng.randf() * TAU, rng.randf_range(0.6, 0.9))

func build_spot(k: int, root: Node3D, _ctx: Dictionary) -> void:
	match k:
		0:
			_lumber(root)
		1:
			_camp(root)
		_:
			_house(root)

func _house(root: Node3D) -> void:
	var wood := Color(0.58, 0.38, 0.18)
	var dark := Color(0.40, 0.24, 0.12)
	var roof := Color(0.62, 0.20, 0.14)
	_box(root, Vector3(3.8, 0.16, 3.0), Vector3(0, 0.08, -0.15), wood)
	_box(root, Vector3(0.16, 1.65, 3.0), Vector3(-1.82, 0.95, -0.15), dark)
	_box(root, Vector3(0.16, 1.65, 3.0), Vector3(1.82, 0.95, -0.15), dark)
	_box(root, Vector3(3.8, 1.65, 0.16), Vector3(0, 0.95, -1.6), dark)
	_box(root, Vector3(1.2, 1.65, 0.16), Vector3(-1.25, 0.95, 1.3), dark)
	_box(root, Vector3(1.2, 1.65, 0.16), Vector3(1.25, 0.95, 1.3), dark)
	_box(root, Vector3(4.2, 0.22, 3.5), Vector3(0, 1.88, -0.15), roof)
	_box(root, Vector3(0.32, 0.7, 0.22), Vector3(0.05, 0.48, 0.55), Color(0.86, 0.14, 0.16))
	_box(root, Vector3(0.46, 0.12, 0.42), Vector3(0.05, 0.9, 0.48), Color(0.92, 0.18, 0.16))
	root.set_meta("bubble_y", 4.4)

func _lumber(root: Node3D) -> void:
	_model(root, SURV + "resource-wood.glb", Vector3(-0.9, 0.0, 0.3), 0.5, 1.0)
	_model(root, CASTLE + "tree-trunk.glb", Vector3(1.15, 0.0, -0.4), 0.0, 0.7)
	_model(root, CASTLE + "tree-trunk.glb", Vector3(0.35, 0.0, 1.05), 1.2, 0.55)
	_model(root, CASTLE + "tree-log.glb", Vector3(0.2, 0.0, -1.2), 1.0, 0.45)
	_model(root, SURV + "tool-shovel.glb", Vector3(-0.2, 0.0, 0.0), 0.8, 0.9)
	root.set_meta("bubble_y", 3.6)

func _camp(root: Node3D) -> void:
	_model(root, SURV + "campfire-pit.glb", Vector3(0, 0.0, 0), 0.0, 0.7)
	_model(root, SURV + "tent.glb", Vector3(-1.5, 0.0, -0.5), 0.5, 1.3)
	_sphere(root, 0.26, Vector3(0.12, 1.05, 0.02), Color(0.72, 0.72, 0.72))
	_sphere(root, 0.2, Vector3(-0.08, 1.48, 0.04), Color(0.84, 0.84, 0.84))
	_sphere(root, 0.15, Vector3(0.05, 1.85, 0.0), Color(0.9, 0.9, 0.9))
	root.set_meta("bubble_y", 3.8)

func _clear(ctx: Dictionary, x: float, z: float) -> bool:
	var p := Vector2(x, z)
	var pads: Array = ctx.pads
	for k in pads.size():
		var pad: Vector3 = pads[k]
		var a := Vector2(pad.x, pad.z)
		if p.distance_to(a) < 3.6:
			return false
		if absf(x - a.x) < 3.6 and z > a.y:        # 站點正前方（鏡頭那一邊）留空：樹才不會擋住家豪和旗子
			return false
		if k + 1 < pads.size():
			var nxt: Vector3 = pads[k + 1]
			var b := Vector2(nxt.x, nxt.z)
			if Geometry2D.get_closest_point_to_segment(p, a, b).distance_to(p) < 2.6:
				return false
		var sp: Vector3 = ctx.spots[k]
		if p.distance_to(Vector2(sp.x, sp.z)) < 5.2:
			return false
	return true

## 放一個模型，縮放到 height 公尺高，底部貼在 pos
func _model(root: Node3D, path: String, pos: Vector3, yaw: float, height: float) -> void:
	var ps := load(path) as PackedScene
	if ps == null:
		_cone(root, pos, height)
		return
	var n := ps.instantiate() as Node3D
	root.add_child(n)
	var bb := _bounds(n)
	if bb.size.y > 0.01:
		var s := height / bb.size.y
		n.scale = Vector3.ONE * s
		n.position = pos - Vector3(bb.position.x + bb.size.x * 0.5, bb.position.y, bb.position.z + bb.size.z * 0.5) * s
	else:
		n.position = pos
	n.rotation.y = yaw

func _tex_mat(tex: String, tint: Color, scale: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(TEX + tex)
	m.albedo_color = tint
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE * scale
	m.roughness = 1.0
	return m

func _bounds(n: Node3D) -> AABB:
	return _bounds_xf(n, Transform3D.IDENTITY)

func _bounds_xf(n: Node, xf: Transform3D) -> AABB:
	var box := AABB()
	var any := false
	if n is VisualInstance3D:
		box = xf * (n as VisualInstance3D).get_aabb()
		any = true
	for c in n.get_children():
		if not (c is Node3D):
			continue
		var sub := _bounds_xf(c, xf * (c as Node3D).transform)
		if sub.size.length() < 0.001:
			continue
		box = sub if not any else box.merge(sub)
		any = true
	return box

func _box(root: Node3D, size: Vector3, pos: Vector3, col: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = _mat(col)
	root.add_child(mi)
	return mi

func _cyl(root: Node3D, radius: float, height: float, pos: Vector3, col: Color) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = _mat(col)
	root.add_child(mi)
	return mi

func _sphere(root: Node3D, radius: float, pos: Vector3, col: Color) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = _mat(col)
	root.add_child(mi)

func _cone(root: Node3D, pos: Vector3, height: float) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.05
	mesh.bottom_radius = height * 0.28
	mesh.height = height
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos + Vector3(0, height * 0.5, 0)
	mi.material_override = _mat(Color(0.22, 0.48, 0.2))
	root.add_child(mi)

func _mat(col: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.9
	return m
