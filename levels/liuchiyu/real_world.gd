extends "res://scripts/world/arena_world.gd"
## 劉起佑版的「超寫實」美術：照片掃描的地面貼圖、石頭、植物（Poly Haven，CC0），
## 天空用真實的全景照片（HDRI）打光。小關的 world.gd 改成 extends 這個檔案就會套用。
## 只換外觀，遊玩範圍、障礙物半徑、水池位置都跟原本一樣。

const PH := "res://levels/liuchiyu/assets/polyhaven/"
const GROUND_SHADER := preload("res://levels/liuchiyu/shaders/real_ground.gdshader")
const WATER_SHADER := preload("res://levels/liuchiyu/shaders/real_water.gdshader")
const LEAF_SHADER := preload("res://levels/liuchiyu/shaders/real_leaf.gdshader")
## 全景照片裡太陽的方向（從場地看向太陽），陰影要跟照片對得上
const SUN_DIR := Vector3(0.52, 0.45, -0.72)

var _rr := RandomNumberGenerator.new()
var _parts_cache := {}
var _batches := {}      # 模型零件 → 要擺的位置，最後一次做成 MultiMesh
var _mat_cache := {}

# ---------------------------------------------------------------- 素材工具

## 讀一個 Poly Haven 模型，回傳裡面每個零件的 Mesh
func _parts(model: String) -> Array:
	if _parts_cache.has(model):
		return _parts_cache[model]
	var out: Array = []
	var ps := load(PH + model + "/" + model + ".gltf") as PackedScene
	if ps:
		var n := ps.instantiate()
		_collect(n, out)
		n.free()
	else:
		push_warning("找不到模型：" + model)
	_parts_cache[model] = out
	return out

func _collect(n: Node, out: Array) -> void:
	if n is MeshInstance3D and n.mesh:
		out.append(n.mesh)
	for c in n.get_children():
		_collect(c, out)

## 在 pos 擺一個零件（先記下來，_flush() 再一次建立）
func _put(model: String, part: int, pos: Vector3, yaw: float, s: Vector3, tilt := Vector3.ZERO, leafy := false, shadow := true) -> void:
	var parts := _parts(model)
	if parts.is_empty():
		return
	var mesh: Mesh = parts[part % parts.size()]
	var key := "%s#%d" % [model, part % parts.size()]
	if not _batches.has(key):
		_batches[key] = {"mesh": mesh, "xf": [], "leafy": leafy, "shadow": shadow, "model": model}
	var b := Basis.from_euler(Vector3(tilt.x, yaw, tilt.z)).scaled(s)
	_batches[key].xf.append(Transform3D(b, pos))

func _put_mesh(key: String, mesh: Mesh, mat: Material, xf: Transform3D) -> void:
	if not _batches.has(key):
		_batches[key] = {"mesh": mesh, "xf": [], "leafy": false, "shadow": true, "mat": mat}
	_batches[key].xf.append(xf)

func _flush() -> void:
	var node := Node3D.new()
	node.name = "RealScatter"
	add_child(node)
	for key in _batches:
		var b: Dictionary = _batches[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = b.mesh
		mm.instance_count = b.xf.size()
		for i in b.xf.size():
			mm.set_instance_transform(i, b.xf[i])
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = mm
		if b.has("mat"):
			mi.material_override = b.mat
		elif b.leafy:
			mi.material_override = _leaf_mat(b.model)
		if not b.shadow:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_child(mi)
	_batches.clear()

## 葉子和草：用模型自己的貼圖加上透明遮罩
func _leaf_mat(model: String, tint := Color.WHITE, sway := 0.03) -> ShaderMaterial:
	var key := "leaf|%s|%s" % [model, tint]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var t := PH + model + "/textures/" + model
	var m := ShaderMaterial.new()
	m.shader = LEAF_SHADER
	m.set_shader_parameter("diff", load(t + "_diff_1k.jpg"))
	m.set_shader_parameter("nor", load(t + "_nor_gl_1k.jpg"))
	m.set_shader_parameter("arm", load(t + "_arm_1k.jpg"))
	m.set_shader_parameter("alpha_tex", load(t + "_alpha_1k.png"))
	m.set_shader_parameter("tint", tint)
	m.set_shader_parameter("sway", sway)
	_mat_cache[key] = m
	return m

## 用一組貼圖（顏色、法線、AO/粗糙度）做一個寫實材質；triplanar 讓方塊不用 UV 也貼得上
func _pbr(tex: String, scale := 1.0, triplanar := true, tint := Color.WHITE) -> StandardMaterial3D:
	var key := "%s|%s|%s|%s" % [tex, scale, triplanar, tint]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(PH + tex + "_diff_1k.jpg")
	m.albedo_color = tint
	m.normal_enabled = true
	m.normal_texture = load(PH + tex + "_nor_gl_1k.jpg")
	var arm: Texture2D = load(PH + tex + "_arm_1k.jpg")
	m.ao_enabled = true
	m.ao_texture = arm
	m.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	m.roughness_texture = arm
	m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
	m.uv1_triplanar = triplanar
	m.uv1_scale = Vector3.ONE * scale
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_mat_cache[key] = m
	return m

func _rbox(parent: Node3D, size: Vector3, pos: Vector3, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi

# ---------------------------------------------------------------- 地面

func _terrain_weights(x: float, z: float, nrm: Vector3) -> Color:
	var c := super(x, z, nrm)
	var wx := x * LAYOUT_SCALE
	var wz := z * LAYOUT_SCALE
	var mud := c.g * 0.7
	for p in ponds:                      # 水池邊是濕泥
		var pd := Vector2(wx, wz).distance_to(p.center)
		mud = maxf(mud, 1.0 - sstep(float(p.r) - 0.5, float(p.r) + 1.6, pd))
	for o in _mud_spots():               # 建築物周圍被踩成泥地
		mud = maxf(mud, (1.0 - sstep(o[1] * 0.7, o[1] * 1.5, Vector2(wx, wz).distance_to(o[0]))) * 0.9)
	mud = maxf(mud, sstep(3.0, 9.0, play_dist(wx, wz)) * 0.75)   # 樹林底下是落葉泥地
	return Color(0.0, mud, c.b, 1.0)

## [[中心, 半徑], ...]：這些地方的草被踩掉
func _mud_spots() -> Array:
	var out: Array = []
	for p in props:
		if String(p.model).contains("Barn") or String(p.model).contains("Silo"):
			out.append([Vector2(p.pos.x, p.pos.z), float(p.get("block", 2.0)) * 1.25])
	return out

func _tweak_terrain_material(mat: ShaderMaterial) -> void:
	mat.shader = GROUND_SHADER
	for pair in [["g", "forrest_ground_01"], ["m", "brown_mud_leaves_01"], ["r", "rocky_terrain_02"]]:
		mat.set_shader_parameter(pair[0] + "_diff", load(PH + pair[1] + "_diff_1k.jpg"))
		mat.set_shader_parameter(pair[0] + "_nor", load(PH + pair[1] + "_nor_gl_1k.jpg"))
		mat.set_shader_parameter(pair[0] + "_arm", load(PH + pair[1] + "_arm_1k.jpg"))

func _build_far_ground() -> void:
	pass        # 遠處交給全景照片

func _build_distant_layers() -> void:
	pass

# ---------------------------------------------------------------- 光線和天空

func _apply_look() -> void:
	var main := get_parent()
	if main == null:
		return
	var we := main.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if we and we.environment:
		var env: Environment = we.environment.duplicate()
		var pm := PanoramaSkyMaterial.new()
		pm.panorama = load(PH + "meadow_2_2k.hdr")
		pm.energy_multiplier = 1.0
		var sky := Sky.new()
		sky.sky_material = pm
		env.background_mode = Environment.BG_SKY
		env.sky = sky
		env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
		env.ambient_light_sky_contribution = 1.0
		env.ambient_light_energy = 1.0
		env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
		env.tonemap_mode = Environment.TONE_MAPPER_ACES
		env.tonemap_exposure = 1.0
		env.tonemap_white = 6.0
		env.ssao_enabled = true
		env.ssao_radius = 1.2
		env.ssao_intensity = 2.2
		env.ssil_enabled = false
		env.ssr_enabled = false      # 粗糙表面的螢幕反射會變成雜點，水面反射天空就夠了
		env.sdfgi_enabled = false
		env.glow_enabled = true
		env.glow_intensity = 0.25
		env.glow_bloom = 0.02
		env.glow_hdr_threshold = 1.4
		env.fog_enabled = true
		env.fog_light_color = Color(0.72, 0.78, 0.82)
		env.fog_density = 0.0035
		env.fog_sun_scatter = 0.25
		env.fog_sky_affect = 0.0
		env.fog_aerial_perspective = 0.4
		env.volumetric_fog_enabled = false
		env.adjustment_enabled = true
		env.adjustment_brightness = 1.0
		env.adjustment_contrast = 1.05
		env.adjustment_saturation = 0.95
		we.environment = env
	var sun := main.get_node_or_null("Sun") as DirectionalLight3D
	if sun:
		sun.basis = Basis.looking_at(-SUN_DIR.normalized())
		sun.light_color = Color(1.0, 0.92, 0.80)
		sun.light_energy = 2.6
		sun.light_angular_distance = 1.2
		sun.shadow_enabled = true
		sun.shadow_blur = 1.4
		sun.directional_shadow_max_distance = 48.0
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS    # 樹葉很多，陰影分兩層就好，比較順
		sun.light_volumetric_fog_energy = 0.0

# ---------------------------------------------------------------- 擺設

func _build_props() -> void:
	var node := Node3D.new()
	node.name = "Props"
	add_child(node)
	_rr.seed = world_seed + 77
	for p in props:
		var path := String(p.model)
		var pos: Vector3 = p.pos
		var block := float(p.get("block", 0.0))
		if path.contains("Barn"):
			_barn(node, pos, float(p.get("yaw", 0.0)), float(p.get("scale", 1.0)))
		elif path.contains("Tree"):
			_tree(Vector3(pos.x, height_at(pos.x, pos.z), pos.z), 7.5, _rr, Color(1.25, 0.95, 0.45))
		else:
			place_model(node, path, pos, float(p.get("yaw", 0.0)), float(p.get("scale", 1.0)))
		if block > 0.0:
			obstacles.append([Vector2(pos.x, pos.z), block])

## 老木板穀倉：方塊加上照片貼圖
func _barn(parent: Node3D, pos: Vector3, yaw: float, s: float) -> void:
	var root := Node3D.new()
	root.position = Vector3(pos.x, height_at(pos.x, pos.z) - 0.1, pos.z)
	root.rotation.y = yaw
	root.scale = Vector3.ONE * s
	parent.add_child(root)
	var planks := _pbr("weathered_brown_planks", 0.55)
	var dark := _pbr("weathered_brown_planks", 0.55, true, Color(0.55, 0.5, 0.46))
	var roof := _pbr("red_slate_roof_tiles_01", 0.6, true, Color(0.75, 0.72, 0.7))
	var stone := _pbr("rocky_terrain_02", 0.5)
	var w := 4.2
	var d := 3.4
	var h := 2.5
	_rbox(root, Vector3(w + 0.2, 0.5, d + 0.2), Vector3(0, 0.2, 0), stone)
	_rbox(root, Vector3(w, h, d), Vector3(0, 0.4 + h * 0.5, 0), planks)
	# 山牆（三角形）
	for z in [-1.0, 1.0]:
		var g := MeshInstance3D.new()
		var pr := PrismMesh.new()
		pr.size = Vector3(w, 1.5, 0.12)
		g.mesh = pr
		g.material_override = planks
		g.position = Vector3(0, 0.4 + h + 0.75, z * (d * 0.5 - 0.06))
		root.add_child(g)
	# 屋頂兩片
	var slope := atan2(1.5, w * 0.5)
	var rl := sqrt(1.5 * 1.5 + w * w * 0.25) + 0.45
	for sx in [-1.0, 1.0]:
		_rbox(root, Vector3(rl, 0.1, d + 0.7), Vector3(sx * (w * 0.25 + 0.12), 0.4 + h + 0.72, 0), roof, Vector3(0, 0, -sx * slope))
	_rbox(root, Vector3(0.22, 0.14, d + 0.75), Vector3(0, 0.4 + h + 1.55, 0), dark)
	# 門、門框、橫樑、角柱
	_rbox(root, Vector3(1.5, 2.0, 0.08), Vector3(0, 1.4, d * 0.5 + 0.03), dark)
	_rbox(root, Vector3(1.75, 0.14, 0.14), Vector3(0, 2.45, d * 0.5 + 0.05), dark)
	_rbox(root, Vector3(2.1, 0.1, 0.05), Vector3(0, 1.4, d * 0.5 + 0.09), planks, Vector3(0, 0, 0.92))
	for sx in [-1.0, 1.0]:
		_rbox(root, Vector3(0.14, 2.05, 0.14), Vector3(sx * 0.82, 1.42, d * 0.5 + 0.05), dark)
		for sz in [-1.0, 1.0]:
			_rbox(root, Vector3(0.16, h, 0.16), Vector3(sx * w * 0.5, 0.4 + h * 0.5, sz * d * 0.5), dark)
	_rbox(root, Vector3(0.7, 0.7, 0.06), Vector3(0, 0.4 + h + 0.55, d * 0.5 + 0.02), dark)
	# 門口的木桶、木箱（都在穀倉的障礙半徑裡面，不影響走位）
	var gp := root.global_transform
	for it in [["wooden_barrels_01", 0, Vector3(1.55, 0.3, 2.0), 0.3], ["wooden_barrels_01", 1, Vector3(-1.6, 0.3, 2.05), 1.1],
			["wooden_crate_02", 0, Vector3(-1.75, 0.3, 1.15), 1.4], ["wooden_barrels_01", 2, Vector3(1.9, 0.3, 1.0), 2.0]]:
		var lp: Vector3 = gp * (it[2] as Vector3)
		lp.y = height_at(lp.x, lp.z) - 0.03
		_put(it[0], it[1], lp, yaw + float(it[3]), Vector3.ONE * 1.15)

## 一棵樹：樹皮貼圖的樹幹和枝條，樹冠用掃描的灌木枝葉放大拼出來
func _tree(base: Vector3, h: float, r: RandomNumberGenerator, tint := Color.WHITE) -> void:
	var bark := _pbr("bark_brown_02", 1.0, false)
	bark.uv1_scale = Vector3(3.0, 5.0, 1.0)
	var unit := _unit_trunk()
	var lean := Vector3(r.randf_range(-0.07, 0.07), r.randf() * TAU, r.randf_range(-0.07, 0.07))
	var tb := Basis.from_euler(lean)
	var tr := h * r.randf_range(0.032, 0.042)
	var th := h * 0.8
	_put_mesh("trunk", unit, bark, Transform3D(tb.scaled(Vector3(tr, th, tr)), base + tb.y * (th * 0.5 - 0.15)))
	_put_mesh("trunk", unit, bark, Transform3D(tb.scaled(Vector3(tr * 1.7, h * 0.07, tr * 1.7)), base + Vector3(0, h * 0.02, 0)))
	var key := "leaf%s" % tint.to_html(false)
	var tips: Array[Vector3] = [base + tb.y * th]
	for k in 4:
		var ang := TAU * k / 4.0 + r.randf_range(-0.5, 0.5)
		var up := r.randf_range(0.45, 0.8)
		var dir := (Vector3(cos(ang), 0, sin(ang)) * (1.0 - up * 0.5) + Vector3.UP * up).normalized()
		var from := base + tb.y * th * r.randf_range(0.5, 0.82)
		var bl := h * r.randf_range(0.2, 0.32)
		var bb := Basis(Quaternion(Vector3.UP, dir))
		_put_mesh("trunk", unit, bark, Transform3D(bb.scaled(Vector3(tr * 0.42, bl, tr * 0.42)), from + dir * bl * 0.5))
		tips.append(from + dir * bl)
	var parts := _parts("shrub_02")
	if parts.is_empty():
		return
	for t in tips:
		for k in 3:
			var part := r.randi() % parts.size()
			var s := h * r.randf_range(0.30, 0.40)
			var off := Vector3(r.randf_range(-0.5, 0.5), r.randf_range(-0.9, 0.1), r.randf_range(-0.5, 0.5)) * h * 0.1
			var b := Basis.from_euler(Vector3(r.randf_range(-0.5, 0.5), r.randf() * TAU, r.randf_range(-0.5, 0.5))).scaled(Vector3.ONE * s)
			var pk := "%s#%d" % [key, part]
			if not _batches.has(pk):
				_batches[pk] = {"mesh": parts[part], "xf": [], "leafy": false, "shadow": true, "mat": _leaf_mat("shrub_02", tint, 0.012)}
			_batches[pk].xf.append(Transform3D(b, t + off - b.y * 0.6))

var _trunk_mesh: CylinderMesh
func _unit_trunk() -> CylinderMesh:
	if _trunk_mesh == null:
		_trunk_mesh = CylinderMesh.new()
		_trunk_mesh.bottom_radius = 1.0
		_trunk_mesh.top_radius = 0.3
		_trunk_mesh.height = 1.0
		_trunk_mesh.radial_segments = 14
		_trunk_mesh.rings = 3
	return _trunk_mesh

# ---------------------------------------------------------------- 水池

func _build_ponds() -> void:
	super()
	var nt := NoiseTexture2D.new()
	var fn := FastNoiseLite.new()
	fn.seed = world_seed + 5
	fn.frequency = 0.02
	fn.fractal_octaves = 4
	nt.noise = fn
	nt.seamless = true
	nt.as_normal_map = true
	nt.bump_strength = 5.0
	var wm := ShaderMaterial.new()
	wm.shader = WATER_SHADER
	wm.set_shader_parameter("ripple", nt)
	for c in get_children():
		if c is MeshInstance3D and String(c.name).begins_with("Pond"):
			c.material_override = wm
			# 共用程式算出來的水面比池底還低（看不到水），這裡只把「看到的水面」抬到岸邊下面一點
			for p in ponds:
				var pc: Vector2 = p.center
				if Vector2(c.position.x, c.position.z).distance_to(pc) < 0.1:
					var rim := 0.0
					for k in 12:
						var a := TAU * k / 12.0
						rim += height_at(pc.x + cos(a) * (float(p.r) + 0.3), pc.y + sin(a) * (float(p.r) + 0.3)) / 12.0
					c.position.y = rim - 0.22
					(c.mesh as CylinderMesh).top_radius = float(p.r) + 0.6
					(c.mesh as CylinderMesh).bottom_radius = float(p.r) + 0.6
	# 岸邊：石頭和蕨類
	_rr.seed = world_seed + 91
	for p in ponds:
		var n := int(float(p.r) * 5.0)
		for k in n:
			var ang := TAU * k / n + _rr.randf_range(-0.2, 0.2)
			var rad := float(p.r) + _rr.randf_range(0.2, 0.9)
			var q: Vector2 = p.center + Vector2(cos(ang), sin(ang)) * rad
			if _rr.randf() < 0.45:
				var s := _rr.randf_range(0.14, 0.3)
				_put("rock_moss_set_01", _rr.randi() % 6, Vector3(q.x, height_at(q.x, q.y) + 0.02, q.y), _rr.randf() * TAU, Vector3.ONE * s)
			else:
				_put("fern_02", _rr.randi() % 4, Vector3(q.x, height_at(q.x, q.y) - 0.02, q.y), _rr.randf() * TAU, Vector3.ONE * _rr.randf_range(0.9, 1.5), Vector3.ZERO, true)

# ---------------------------------------------------------------- 其他

func _build_extra() -> void:
	_apply_look()
	_rr.seed = world_seed + 123
	# 場邊的石頭、樹樁、枯木、枯枝
	var n := 46
	for k in n:
		var t := float(k) / n
		var q := _edge_point(t, _rr.randf_range(0.8, 5.0))
		var y := height_at(q.x, q.y)
		var roll := _rr.randf()
		if roll < 0.42:
			var s := _rr.randf_range(0.35, 1.0)
			_put("rock_moss_set_01", _rr.randi() % 6, Vector3(q.x, y + 0.1 * s, q.y), _rr.randf() * TAU, Vector3.ONE * s)
		elif roll < 0.52:
			_put("boulder_01", 0, Vector3(q.x, y - 0.05, q.y), _rr.randf() * TAU, Vector3.ONE * _rr.randf_range(0.9, 1.7))
		elif roll < 0.62:
			_put("tree_stump_01", 0, Vector3(q.x, y + 0.08, q.y), _rr.randf() * TAU, Vector3.ONE * _rr.randf_range(0.7, 1.0))
		elif roll < 0.70:
			_put("dead_tree_trunk", 0, Vector3(q.x, y + 0.02, q.y), _rr.randf() * TAU, Vector3.ONE * _rr.randf_range(1.0, 1.5))
		else:
			_put("dry_branches_medium_01", _rr.randi() % 3, Vector3(q.x, y + 0.03, q.y), _rr.randf() * TAU, Vector3.ONE * _rr.randf_range(1.0, 1.8))

## 沿著遊玩範圍外框走一圈，t = 0..1，out = 往外幾公尺
func _edge_point(t: float, out: float) -> Vector2:
	var a := play_min - Vector2(out, out)
	var b := play_max + Vector2(out, out)
	var w := b.x - a.x
	var h := b.y - a.y
	var d := t * 2.0 * (w + h)
	if d < w:
		return Vector2(a.x + d, a.y)
	d -= w
	if d < h:
		return Vector2(b.x, a.y + d)
	d -= h
	if d < w:
		return Vector2(b.x - d, b.y)
	return Vector2(a.x, b.y - (d - w))

func _build_arena_grass() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = world_seed + 55
	var gparts := _parts("grass_bermuda_01").size()
	if gparts == 0:
		return
	var spots := _mud_spots()
	for k in 9000:
		var x := r.randf_range(play_min.x - 5.0, play_max.x + 5.0)
		var z := r.randf_range(play_min.y - 5.0, play_max.y + 5.0)
		if in_water(x, z):
			continue
		var skip := false
		for p in ponds:
			if Vector2(x, z).distance_to(p.center) < float(p.r) + 0.5:
				skip = true
		for o in spots:
			if Vector2(x, z).distance_to(o[0]) < o[1] * 0.85:
				skip = true
		# 草長成一叢一叢，中間露出地面
		if skip or _noise.get_noise_2d(x * 4.0 + 90.0, z * 4.0) < -0.12 + r.randf() * 0.25:
			continue
		var s := r.randf_range(3.0, 6.0)
		_put("grass_bermuda_01", r.randi() % gparts, Vector3(x, height_at(x, z) - 0.01, z), r.randf() * TAU, Vector3(s, s * r.randf_range(0.9, 1.6), s), Vector3.ZERO, true, false)
	for k in 260:
		var x := r.randf_range(play_min.x - 4.0, play_max.x + 4.0)
		var z := r.randf_range(play_min.y - 4.0, play_max.y + 4.0)
		if in_water(x, z):
			continue
		var pos := Vector3(x, height_at(x, z) - 0.01, z)
		var roll := r.randf()
		if roll < 0.5:
			_put("weed_plant_02", r.randi() % 5, pos, r.randf() * TAU, Vector3.ONE * r.randf_range(2.0, 3.5), Vector3.ZERO, true, false)
		elif roll < 0.8:
			_put("shrub_03", r.randi() % 4, pos, r.randf() * TAU, Vector3.ONE * r.randf_range(1.0, 1.8), Vector3.ZERO, true)
		elif play_dist(x, z) > -2.5:
			_put("fern_02", r.randi() % 4, pos, r.randf() * TAU, Vector3.ONE * r.randf_range(0.9, 1.5), Vector3.ZERO, true)

func _build_arena_forest() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = world_seed + 31
	var step := 4.3
	var x := play_min.x - forest_band
	while x <= play_max.x + forest_band:
		var z := play_min.y - forest_band
		while z <= play_max.y + forest_band:
			var px := x + r.randf_range(-1.3, 1.3)
			var pz := z + r.randf_range(-1.3, 1.3)
			var d := play_dist(px, pz)
			var near_cam := Vector2(px - camera_start.x, pz - camera_start.z).length() < 6.5
			if d > 1.6 and d < forest_band and not near_cam and r.randf() < 0.66:
				var gy := height_at(px, pz)
				_tree(Vector3(px, gy, pz), r.randf_range(7.5, 11.5), r, Color(0.75, 1.0, 0.55))
				# 樹下的灌木和蕨類
				for k in 2:
					var q := Vector2(px, pz) + Vector2(r.randf_range(-1.6, 1.6), r.randf_range(-1.6, 1.6))
					if play_dist(q.x, q.y) > 0.6:
						if r.randf() < 0.5:
							_put("shrub_02", r.randi() % 4, Vector3(q.x, height_at(q.x, q.y), q.y), r.randf() * TAU, Vector3.ONE * r.randf_range(0.7, 1.2), Vector3.ZERO, true)
						else:
							_put("fern_02", r.randi() % 4, Vector3(q.x, height_at(q.x, q.y), q.y), r.randf() * TAU, Vector3.ONE * r.randf_range(1.2, 2.0), Vector3.ZERO, true)
			z += step
		x += step
	_flush()
