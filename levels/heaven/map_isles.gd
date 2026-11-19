extends RefCounted
## 選關地圖上的「丹穴山」（chapter.gd 的 MAP_SCRIPT；由 scripts/level_select.gd 呼叫，不是關卡腳本）。
## 選關地圖上每個大關都是一座島，所以這裡還是一座島（關卡裡面不是島，見 heaven_world.gd）：一座雲霧裡的仙山。
## 三個小關是島上的三個地點，模型跟關卡裡是同一批（assets/blender/）：
##   1 雲階：松林裡的畫門和亭子（青綠的霧）　2 山海迴廊：銀杏樹下的木樓和陸吾（金黃的午後）　3 天門：圓門、唱盤和金環（星空）
## 島的網格借用冰雪島的 art/isle_builder.gd（只是算形狀的工具）。

const Isle := preload("res://levels/ice/art/isle_builder.gd")
const World := preload("res://levels/heaven/heaven_world.gd")     # 只借用 HEAVEN_MOODS（每一關的配色）
const HM := "res://levels/heaven/assets/blender/"
const TEX := "res://assets/textures/"
const STAGE_MOODS := ["ink", "gold", "astral"]

var _top_y := 1.5
var _ctx := {}
var _o := {}
var _rng := RandomNumberGenerator.new()

## 走到第 k 小關時的天色（照那一關的配色）
func mood(k: int) -> Dictionary:
	var md: Dictionary = World.HEAVEN_MOODS[STAGE_MOODS[clampi(k, 0, STAGE_MOODS.size() - 1)]]
	return {
		"sun": md.sun, "energy": md.energy, "rot": md.rot, "amb": md.amb, "amb_e": md.amb_e, "fog": md.fog,
		"sky.top_color": md.top, "sky.horizon_color": md.hor, "sky.cloud_color": md.cloud, "sky.cloud_shade": md.cloud_sh,
		"sea.deep": md.sea_deep, "sea.near_c": md.sea_near, "sea.stroke_c": md.sea_stroke,
		"sea.foam_c": (md.sea_stroke as Color).lerp(Color.WHITE, 0.6), "sea.horizon_c": md.sea_far,
	}

func ground_y(x: float, z: float) -> float:
	return _top_y + 0.10 * sin(x * 0.5 + 0.7) * cos(z * 0.6)

func build_island(root: Node3D, ctx: Dictionary) -> void:
	_ctx = ctx
	_top_y = float(ctx.get("top_y", 1.5))
	_rng.seed = 9090
	var c: Vector2 = ctx.center
	_o = {"c": c, "rx": float(ctx.rx), "rz": float(ctx.rz), "seed": 6.6, "pow": 2.8, "wob": 1.3, "depth": _top_y + 1.4, "slope": 0.14, "lobe": 2.8,
		"coves": [[0.8, 2.0, 0.18], [2.6, 1.8, 0.16], [4.4, 2.2, 0.18], [5.6, 1.6, 0.14]]}
	var top := MeshInstance3D.new()
	top.name = "Top"
	top.mesh = Isle.build_top(_o, ground_y, 128, 12, 0.35)
	top.material_override = _tex_mat("grass_ground_diff_1k.jpg", Color(0.62, 1.10, 0.86), 0.2)
	root.add_child(top)
	var cliff := MeshInstance3D.new()
	cliff.name = "Cliff"
	cliff.mesh = Isle.build_cliff(_o, func(a: float) -> float:
		var p := Isle.rim_point(_o, a)
		return ground_y(p.x, p.y), 128, 6)
	var cm := _tex_mat("lichen_rock_diff_1k.jpg", Color(0.80, 1.0, 0.98), 0.16)
	cm.vertex_color_use_as_albedo = true
	cliff.material_override = cm
	root.add_child(cliff)
	# 空地上的樹：西邊（第 1 關那一頭）是松和花樹，中間是銀杏，東邊（第 3 關）是石碑和山石
	var placed := 0
	var span := maxf(float(ctx.rx) * 2.0, 1.0)
	for i in 500:
		if placed >= 26:
			break
		var a := _rng.randf() * TAU
		var d := Isle.radius(_o, a) * sqrt(_rng.randf()) - 1.5
		var x := c.x + cos(a) * d
		var z := c.y + sin(a) * d
		if d < 0.0 or not _free(x, z):
			continue
		var t := (x - (c.x - float(ctx.rx))) / span        # 0 = 最西邊，1 = 最東邊
		var south := z > _near_pad_z(x) + 2.0
		var sc := _rng.randf_range(0.42, 0.55) if south else _rng.randf_range(0.6, 0.85)
		var g := Vector3(x, ground_y(x, z) - 0.03, z)
		if t < 0.38:
			_piece(root, HM + ["pine_a.glb", "pine_b.glb", "blossom.glb"][placed % 3], g, _rng.randf() * TAU, sc)
		elif t < 0.70:
			_piece(root, HM + ["ginkgo_a.glb", "ginkgo_b.glb"][placed % 2], g, _rng.randf() * TAU, sc * 0.85)
		else:
			_piece(root, HM + ["stele.glb", "scholar_rock.glb", "palace_lantern.glb"][placed % 3], g, _rng.randf() * TAU, sc * 1.1)
		placed += 1
	# 島的四周繞著幾朵雲（仙山在雲裡）
	var cloud_mat := StandardMaterial3D.new()
	cloud_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cloud_mat.albedo_color = Color(1, 1, 1, 0.96)
	for i in 9:
		var a := (i + _rng.randf_range(-0.3, 0.3)) * TAU / 9.0
		var d := Isle.cliff_radius(_o, a, _top_y) + _rng.randf_range(0.5, 3.0)
		var cl := _piece(root, "res://levels/ice/assets/blender/cloud_puff_" + ["a", "b", "c"][i % 3] + ".glb", Vector3(c.x + cos(a) * d, 0.1, c.y + sin(a) * d), a, _rng.randf_range(0.5, 0.85))
		if cl:
			for m in cl.find_children("*", "MeshInstance3D", true, false):
				(m as MeshInstance3D).material_override = cloud_mat
				(m as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func build_spot(k: int, root: Node3D, _c: Dictionary) -> void:
	match k:
		0:
			# 雲階：畫門、亭子、松
			_piece(root, HM + "picture_gate.glb", Vector3(-0.4, 0, -0.9), 0.35, 0.95)
			_piece(root, HM + "pavilion.glb", Vector3(2.6, 0, -2.4), 0.6, 0.5)
			_piece(root, HM + "pine_a.glb", Vector3(-2.9, 0, -2.2), 0.4, 0.7)
			_piece(root, HM + "scholar_rock.glb", Vector3(-2.6, 0, 1.2), 2.0, 0.6)
			_piece(root, HM + "palace_lantern.glb", Vector3(1.9, 0, 1.3), 0.0, 0.6)
			_light(root, Vector3(0.0, 1.8, 0.6), Color(1.0, 0.75, 0.4), 1.0, 4.5)
			root.set_meta("bubble_y", 5.0)
		1:
			# 山海迴廊：木樓、陸吾、銀杏
			_piece(root, HM + "house.glb", Vector3(-1.6, 0, -2.0), 0.3, 0.55)
			_piece(root, HM + "luwu.glb", Vector3(1.5, 0, 0.6), -0.5, 0.9)
			_piece(root, HM + "ginkgo_a.glb", Vector3(3.2, 0, -2.2), 1.0, 0.7)
			_piece(root, HM + "ginkgo_b.glb", Vector3(-3.4, 0, 0.8), 2.0, 0.5)
			_piece(root, HM + "leaf_pile.glb", Vector3(-0.8, 0, 1.6), 0.0, 0.6)
			root.set_meta("bubble_y", 5.8)
		_:
			# 天門：圓門、唱盤、金環、石碑
			_piece(root, HM + "ring_gate.glb", Vector3(0, 0, -2.2), 0.0, 0.55)
			_piece(root, HM + "turntable.glb", Vector3(0, 0, 0.4), 0.0, 0.9)
			var ring := _piece(root, HM + "gold_ring.glb", Vector3(0, 2.6, -3.4), 0.0, 1.05)
			if ring:
				for m in ring.find_children("*", "MeshInstance3D", true, false):
					(m as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_piece(root, HM + "stele.glb", Vector3(-3.0, 0, -0.6), 0.5, 0.8)
			_piece(root, HM + "stele.glb", Vector3(3.0, 0, -0.6), -0.5, 0.8)
			_piece(root, HM + "palace_lantern.glb", Vector3(-1.7, 0, 1.6), 0.0, 0.6)
			_piece(root, HM + "palace_lantern.glb", Vector3(1.7, 0, 1.6), 0.0, 0.6)
			_light(root, Vector3(0, 2.4, -1.4), Color(1.0, 0.85, 0.45), 2.2, 7.0)
			root.set_meta("bubble_y", 6.6)

func _near_pad_z(x: float) -> float:
	var best := 0.0
	var bd := INF
	for p in _ctx.pads:
		if absf(x - p.x) < bd:
			bd = absf(x - p.x)
			best = p.z
	return best

func _free(x: float, z: float) -> bool:
	var p := Vector2(x, z)
	var pads: Array = _ctx.pads
	for k in pads.size():
		var a := Vector2(pads[k].x, pads[k].z)
		if p.distance_to(a) < 3.2:
			return false
		if absf(x - a.x) < 4.6 and z > a.y:
			return false
		if k + 1 < pads.size():
			var b := Vector2(pads[k + 1].x, pads[k + 1].z)
			if Geometry2D.get_closest_point_to_segment(p, a, b).distance_to(p) < 2.6:
				return false
		var sp: Vector3 = _ctx.spots[k]
		if p.distance_to(Vector2(sp.x, sp.z)) < 5.2:
			return false
	return true

func _tex_mat(tex: String, tint: Color, scale: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(TEX + tex)
	m.albedo_color = tint
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE * scale
	m.roughness = 1.0
	return m

func _piece(parent: Node3D, path: String, pos: Vector3, yaw := 0.0, scale := 1.0) -> Node3D:
	if not ResourceLoader.exists(path):
		push_warning("丹穴山地圖：找不到模型 " + path)
		return null
	var ps := load(path) as PackedScene
	if ps == null:
		return null
	var n := ps.instantiate() as Node3D
	n.position = pos
	n.rotation.y = yaw
	n.scale = Vector3.ONE * scale
	parent.add_child(n)
	var shut := n.find_child("EyesShut", true, false) as Node3D
	if shut:
		shut.visible = false
	return n

func _light(parent: Node3D, p: Vector3, col: Color, energy: float, rng: float) -> void:
	var l := OmniLight3D.new()
	l.light_color = col
	l.light_energy = energy
	l.omni_range = rng
	l.light_specular = 0.0
	l.position = p
	parent.add_child(l)
