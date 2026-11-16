extends RefCounted
## 選關地圖上的森林島（chapter.gd 的 MAP_SCRIPT；由 scripts/level_select.gd 呼叫）。
## 一座草地大島，三個地標：木屋（小紅帽）、伐木、營火。

const TOP := 1.5
const BIRCH := "res://assets/nature/BirchTree.glb"

func mood(_k: int) -> Dictionary:
	return {
		"sun": Color(1.0, 0.96, 0.78), "amb": Color(0.52, 0.76, 0.48),
		"fog": Color(0.70, 0.88, 0.68),
		"sky.top_color": Color(0.36, 0.66, 0.90), "sky.horizon_color": Color(0.76, 0.90, 0.70),
		"sky.cloud_color": Color(0.96, 0.98, 0.92), "sky.cloud_shade": Color(0.68, 0.82, 0.64),
		"sea.deep": Color(0.07, 0.38, 0.50), "sea.near_c": Color(0.16, 0.54, 0.56),
		"sea.horizon_c": Color(0.68, 0.86, 0.72),
	}

func ground_y(_x: float, _z: float) -> float:
	return TOP

func build_island(root: Node3D, ctx: Dictionary) -> void:
	var c: Vector2 = ctx.center
	var radius := maxf(float(ctx.rx), float(ctx.rz))
	_disc(root, c, radius * 0.78, (TOP + 0.4) * 0.5 - 0.35, TOP + 0.9, Color(0.42, 0.30, 0.18))
	_disc(root, c, radius * 0.96, TOP - 0.16, 0.38, Color(0.36, 0.62, 0.28))
	var rng := RandomNumberGenerator.new()
	rng.seed = 481516
	var placed := 0
	for i in 80:
		if placed >= 16:
			break
		var a := rng.randf() * TAU
		var d := radius * rng.randf_range(0.28, 0.82)
		var x := c.x + cos(a) * d
		var z := c.y + sin(a) * d * 0.72
		if not _clear(ctx, x, z):
			continue
		_tree(root, Vector3(x, TOP, z), rng.randf() * TAU, rng.randf_range(2.4, 3.6))
		placed += 1

func build_spot(k: int, root: Node3D, _ctx: Dictionary) -> void:
	match k:
		0:
			_house(root)
		1:
			_lumber(root)
		_:
			_camp(root)

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
	var wood := Color(0.48, 0.30, 0.16)
	for p in [Vector3(-1.15, 0.22, 0.15), Vector3(1.05, 0.22, -0.35), Vector3(0.15, 0.22, -1.15)]:
		_cyl(root, 0.32, 0.42, p, wood)
	var log := _cyl(root, 0.22, 2.2, Vector3(0.35, 0.28, 0.55), Color(0.55, 0.36, 0.18))
	log.rotation.z = PI * 0.5
	root.set_meta("bubble_y", 3.6)

func _camp(root: Node3D) -> void:
	_cyl(root, 0.72, 0.22, Vector3(0, 0.12, 0), Color(0.34, 0.26, 0.18))
	_sphere(root, 0.32, Vector3(0, 0.42, 0), Color(0.95, 0.42, 0.10))
	_sphere(root, 0.26, Vector3(0.12, 1.05, 0.02), Color(0.72, 0.72, 0.72))
	_sphere(root, 0.2, Vector3(-0.08, 1.48, 0.04), Color(0.84, 0.84, 0.84))
	root.set_meta("bubble_y", 3.8)

func _clear(ctx: Dictionary, x: float, z: float) -> bool:
	var p := Vector2(x, z)
	var pads: Array = ctx.pads
	for k in pads.size():
		var pad: Vector3 = pads[k]
		var a := Vector2(pad.x, pad.z)
		if p.distance_to(a) < 3.6:
			return false
		if absf(x - a.x) < 3.4 and z > a.y and z - a.y < 7.0:
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

func _tree(root: Node3D, pos: Vector3, yaw: float, height: float) -> void:
	var ps := load(BIRCH) as PackedScene
	if ps == null:
		_cone(root, pos, height)
		return
	var n := ps.instantiate() as Node3D
	root.add_child(n)
	var bb := _bounds(n)
	if bb.size.y > 0.01:
		var s := height / bb.size.y
		n.scale = Vector3.ONE * s
		n.position = pos - Vector3(bb.position.x * s, bb.position.y * s, bb.position.z * s)
	else:
		n.position = pos
	n.rotation.y = yaw

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

func _disc(root: Node3D, c: Vector2, radius: float, y: float, height: float, col: Color) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius * 0.86
	mesh.height = height
	mesh.radial_segments = 64
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = Vector3(c.x, y, c.y)
	mi.material_override = _mat(col)
	root.add_child(mi)

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
