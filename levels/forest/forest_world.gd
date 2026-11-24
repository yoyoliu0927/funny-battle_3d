extends "res://scripts/world/arena_world.gd"
## 森林場地的共用外觀：深綠地面、可砍的樹、木屋、小紅帽。
## 每一小關覆寫 _layout_level()（範圍、出生點）和 _dress()（要種什麼）。

var trees: Array = []          # {pos, node, rest, block, radius, alive, fall}
var has_house := false
var house_center := Vector2.ZERO
var house_half_x := 3.0
var house_half_z := 2.55
var door_half := 1.2
var house_clear := 6.5         # 木屋周圍這段不種樹
var escape_point := Vector3(0, 0, 4.4)

func _configure() -> void:
	hill_amount = 0.12
	forest_band = 3.5
	grass_count = 560
	ground_a = Color(0.34, 0.52, 0.22)
	ground_b = Color(0.26, 0.42, 0.16)
	dirt_color = Color(0.42, 0.30, 0.16)
	tree_green = Color(0.16, 0.30, 0.13)   # 外圈深林；場內可砍的樹另外畫得亮一點
	_layout_level()

## 小關覆寫：遊玩範圍、鏡頭、牆
func _layout_level() -> void:
	pass

## 灰色混凝土牆不畫，木屋自己畫。擋路仍靠 wall_segments。
func _build_fence_visuals() -> void:
	pass

func _build_extra() -> void:
	_dress()
	forest_wall()
	ferns(int((play_max.x - play_min.x) * (play_max.y - play_min.y) * 0.05))
	mossy_rocks()
	ground_patches()
	ground_detail()
	ambient_motes()
	_setup_look()

# ---------------------------------------------------------------- 場地細節（沿用共用的卡通 3D 畫法，不換繪圖方式）
var paint_warm := 0.0          # （舊）不再使用，保留給小關設定檔相容

## 屋子用的材質：跟其他地方一樣的卡通著色
func painted(c: Color, _rim := 0.35, _mottle := 0.3) -> ShaderMaterial:
	return _toon(c)

## 共用場地外圈那一圈（有圓傘樹冠、淡色團塊）不要：換成下面自己的針葉樹牆，畫法統一、俯看不會有發白的球
func _build_arena_forest() -> void:
	pass

## 遊玩範圍外面緊貼著的幾排樹（只是外觀，不擋路、不能砍）：讓場地看起來是林子裡的一塊空地，不是一片草原。
## 樹種混著用：Kenney 的針葉樹（大小不一）、共用素材的樺樹和秋樹（顏色多一點變化）。
func forest_wall() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed + 500
	var pool := [K_CASTLE + "tree-large.glb", K_CASTLE + "tree-large.glb", K_CASTLE + "tree-large.glb", K_CASTLE + "tree-small.glb", K_CASTLE + "tree-small.glb", K_CASTLE + "tree-small.glb", K_CASTLE + "tree-large.glb", K_CASTLE + "tree-small.glb"]
	var x0 := play_min.x - 0.2
	var x1 := play_max.x + 0.2
	var z0 := play_min.y - 0.2
	var z1 := play_max.y + 0.2
	for row in 5:
		var off := 1.2 + 2.2 * float(row)
		var step := 2.3 + 0.2 * float(row)
		var pts: Array[Vector2] = []
		var x := x0 - off
		while x <= x1 + off:
			pts.append(Vector2(x, z0 - off))
			pts.append(Vector2(x, z1 + off + 4.5))       # 南邊（鏡頭那一側）退到鏡頭後面，不要擋住視線
			x += step
		var z := z0 - off
		while z <= z1 + off:
			pts.append(Vector2(x0 - off, z))
			pts.append(Vector2(x1 + off, z))
			z += step
		for p in pts:
			var q := p + Vector2(rng.randf_range(-0.7, 0.7), rng.randf_range(-0.7, 0.7))
			var path: String = pool[rng.randi() % pool.size()]
			var ps := load(path) as PackedScene
			if ps == null:
				continue
			var n := ps.instantiate() as Node3D
			var birch := path.contains("nature")
			var sc := rng.randf_range(2.0, 2.9) if not birch else rng.randf_range(0.5, 0.7)
			n.scale = Vector3.ONE * sc
			n.position = Vector3(q.x, height_at(q.x, q.y) - 0.1, q.y)
			n.rotation.y = rng.randf() * TAU
			add_child(n)
			_soften_tree(n, 0.78)

## 蕨葉：幾片斜斜的葉子一簇，種在樹腳、石頭旁
func ferns(n: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed + 610
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var leaf := BoxMesh.new()
	leaf.size = Vector3(0.09, 0.62, 0.02)
	mm.mesh = leaf
	var xfs: Array[Transform3D] = []
	var cs: Array[Color] = []
	var guard := 0
	var greens := [Color(0.22, 0.48, 0.2), Color(0.28, 0.54, 0.22), Color(0.2, 0.42, 0.24)]
	while xfs.size() < n * 5 and guard < n * 8:
		guard += 1
		var x := rng.randf_range(play_min.x + 0.5, play_max.x - 0.5)
		var z := rng.randf_range(play_min.y + 0.5, play_max.y - 0.5)
		if has_house and Vector2(x, z).distance_to(house_center) < house_half_x + 0.8:
			continue
		var near := false
		for t in trees:
			var tp: Vector3 = t.pos
			if Vector2(x, z).distance_to(Vector2(tp.x, tp.z)) < 1.8:
				near = true
				break
		if not near and rng.randf() > 0.25:
			continue
		var y := height_at(x, z)
		var col: Color = greens[rng.randi() % greens.size()]
		for k in 5:
			var yaw := TAU * float(k) / 5.0 + rng.randf() * 0.5
			var b := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, rng.randf_range(0.7, 1.1))
			xfs.append(Transform3D(b.scaled(Vector3.ONE * rng.randf_range(0.8, 1.4)), Vector3(x, y + 0.18, z)))
			cs.append(col.lightened(rng.randf_range(-0.05, 0.1)))
	mm.instance_count = xfs.size()
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i])
		mm.set_instance_color(i, cs[i])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)

## 長苔蘚的石頭：Kenney 的石頭疊上一個綠色的苔蘚頂
func mossy_rocks() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed + 720
	var moss := _toon(Color(0.28, 0.5, 0.2))
	var placed := 0
	var guard := 0
	var want := int((play_max.x - play_min.x) * (play_max.y - play_min.y) / 55.0)
	while placed < want and guard < 300:
		guard += 1
		var x := rng.randf_range(play_min.x + 1.0, play_max.x - 1.0)
		var z := rng.randf_range(play_min.y + 1.0, play_max.y - 1.0)
		if has_house and Vector2(x, z).distance_to(house_center) < house_clear:
			continue
		if _near_tree(x, z, 1.4) or _spawn_clear(x, z) or Vector2(x, z).distance_to(Vector2(hero_start.x, hero_start.z)) < 3.2:
			continue
		var sc := rng.randf_range(0.9, 1.6)
		var r := prop(K_CASTLE + "rocks-small.glb", x, z, rng.randf() * TAU, sc, 0.0)
		if r:
			var cap := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.28 * sc
			sm.height = 0.2 * sc
			cap.mesh = sm
			cap.material_override = moss
			cap.position = Vector3(0.05, 0.34 * sc, 0.0)
			r.add_child(cap)
		placed += 1

## 出生點、敵人站的地方附近不放（小關設 spawn_keep）
var spawn_keep: Array = []
func _spawn_clear(x: float, z: float) -> bool:
	for p in spawn_keep:
		if Vector2(x, z).distance_to(Vector2(p.x, p.z)) < 2.2:
			return true
	return false

## 地上的小東西（用 MultiMesh，幾百個也不花什麼）：小花叢、落葉、苔蘚。顏色由小關的 detail_* 決定。
var detail_flowers: Array = [Color(0.96, 0.82, 0.30), Color(0.95, 0.95, 0.9), Color(0.9, 0.5, 0.6)]
var detail_leaves: Array = [Color(0.8, 0.5, 0.15), Color(0.6, 0.3, 0.12)]
var detail_count := 1.0
var detail_moss: Array = [Color(0.16, 0.34, 0.14), Color(0.2, 0.38, 0.16)]

## 大塊的深淺草地斑塊（又大又扁的圓，顏色比地面深一點或淺一點）：地面不再是單一綠色
func ground_patches() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed + 411
	var disc := CylinderMesh.new()
	disc.top_radius = 0.5
	disc.bottom_radius = 0.5
	disc.height = 1.0
	disc.radial_segments = 14
	var cols := [ground_a.darkened(0.12), ground_b.darkened(0.1), ground_a.darkened(0.2), ground_b.lightened(0.03)]
	var area := (play_max.x - play_min.x) * (play_max.y - play_min.y)
	_scatter_mm(rng, disc, int(area / 20.0), cols, Vector3(3.6, 0.012, 2.8), 0.0)

func ground_detail() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed + 301
	var area := (play_max.x - play_min.x) * (play_max.y - play_min.y)
	var disc := CylinderMesh.new()
	disc.top_radius = 0.5
	disc.bottom_radius = 0.5
	disc.height = 1.0
	disc.radial_segments = 8
	_scatter_mm(rng, BoxMesh.new(), int(area * 0.12 * detail_count), detail_leaves, Vector3(0.15, 0.015, 0.11), 0.0)
	_scatter_mm(rng, disc, int(area * 0.1 * detail_count), detail_moss, Vector3(0.9, 0.025, 0.7), 0.0)
	var fl := SphereMesh.new()
	fl.radius = 0.5
	fl.height = 1.0
	fl.radial_segments = 6
	fl.rings = 3
	_scatter_mm(rng, fl, int(area * 0.05 * detail_count), detail_flowers, Vector3(0.12, 0.12, 0.12), 0.12)

func _scatter_mm(rng: RandomNumberGenerator, mesh: Mesh, n: int, cols: Array, size: Vector3, lift: float) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	var xfs: Array[Transform3D] = []
	var cs: Array[Color] = []
	var guard := 0
	while xfs.size() < n and guard < n * 6:
		guard += 1
		var x := rng.randf_range(play_min.x + 0.6, play_max.x - 0.6)
		var z := rng.randf_range(play_min.y + 0.6, play_max.y - 0.6)
		if has_house and Vector2(x, z).distance_to(house_center) < house_half_x + 0.8:
			continue
		if _near_tree(x, z, 0.5):
			continue
		var sc := rng.randf_range(0.7, 1.4)
		var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(size * sc * Vector3(rng.randf_range(0.65, 1.35), 1.0, rng.randf_range(0.65, 1.35)))
		xfs.append(Transform3D(b, Vector3(x, height_at(x, z) + size.y * 0.5 + lift, z)))
		cs.append((cols[rng.randi() % cols.size()] as Color).lightened(rng.randf_range(-0.05, 0.1)))
	mm.instance_count = xfs.size()
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i])
		mm.set_instance_color(i, cs[i])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)

## 空氣裡慢慢飄的小光點（早晨花粉、午後塵埃、黃昏螢火蟲）。顏色與亮度由小關設。
var mote_color := Color(1.0, 0.95, 0.7)
var mote_glow := 1.2
var mote_count := 70

func ambient_motes() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var pt := CPUParticles3D.new()
	pt.name = "Motes"
	pt.amount = mote_count
	pt.lifetime = 7.0
	pt.preprocess = 7.0
	pt.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	var ext := Vector3((play_max.x - play_min.x) * 0.5, 1.6, (play_max.y - play_min.y) * 0.5)
	pt.emission_box_extents = ext
	pt.position = Vector3((play_min.x + play_max.x) * 0.5, 2.2, (play_min.y + play_max.y) * 0.5)
	pt.direction = Vector3(0.3, 0.4, 0.1)
	pt.spread = 180.0
	pt.initial_velocity_min = 0.15
	pt.initial_velocity_max = 0.5
	pt.gravity = Vector3(0, 0.02, 0)
	pt.scale_amount_min = 0.1
	pt.scale_amount_max = 0.2
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	sm.radial_segments = 6
	sm.rings = 3
	pt.mesh = sm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = mote_color
	m.emission_enabled = true
	m.emission = mote_color
	m.emission_energy_multiplier = mote_glow
	pt.material_override = m
	pt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(pt)

## 池塘邊的蘆葦和睡蓮
func pond_life(center: Vector2, r: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed + 77
	var reed := _toon(Color(0.36, 0.52, 0.2))
	var tip := _toon(Color(0.55, 0.4, 0.2))
	for k in 90:
		var a := rng.randf() * TAU
		var d := r + rng.randf_range(-0.3, 1.0)
		var x := center.x + cos(a) * d
		var z := center.y + sin(a) * d
		var h := rng.randf_range(1.2, 2.3)
		var y := height_at(x, z)
		var lean := Vector3(rng.randf_range(-0.2, 0.2), 0, rng.randf_range(-0.2, 0.2))
		_box(self, Vector3(0.09, h, 0.09), Vector3(x, y + h * 0.5, z), reed, lean)
		if k % 3 == 0:
			_box(self, Vector3(0.16, 0.42, 0.16), Vector3(x, y + h + 0.1, z), tip, lean)
	var pad := _toon(Color(0.2, 0.42, 0.22))
	var flower := _toon(Color(0.98, 0.7, 0.8))
	for k in 16:
		var a := rng.randf() * TAU
		var d := rng.randf_range(0.0, r * 0.8)
		var x := center.x + cos(a) * d
		var z := center.y + sin(a) * d
		var wy := water_y + 0.05
		var disc := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = rng.randf_range(0.45, 0.75)
		cm.bottom_radius = cm.top_radius
		cm.height = 0.02
		cm.radial_segments = 12
		disc.mesh = cm
		disc.material_override = pad
		disc.position = Vector3(x, wy, z)
		disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(disc)
		if k % 3 == 0:
			_box(self, Vector3(0.22, 0.14, 0.22), Vector3(x, wy + 0.08, z), flower)

# ---------------------------------------------------------------- 天色
## 每一小關一個時段：第一關早晨、第二關午後、第三關黃昏（第三關會隨著小紅帽的計時慢慢變暗）。
## 小關在 _layout_level() 設 look（和 look2，有的話 set_look(k) 會在兩者之間漸變）。
## 只改這個場景自己的 WorldEnvironment（先 duplicate，不會影響到別的關卡）。
var look := {}
var look2 := {}
var _env: Environment
var _sky_mat: ShaderMaterial
var _sun: DirectionalLight3D
var _lamp: OmniLight3D

func _setup_look() -> void:
	var main := get_parent()
	if main == null or look.is_empty():
		return
	var we := main.get_node_or_null("WorldEnvironment") as WorldEnvironment
	_sun = main.get_node_or_null("Sun") as DirectionalLight3D
	if we and we.environment:
		_env = we.environment.duplicate(true)
		we.environment = _env
		if _env.sky:
			_sky_mat = _env.sky.sky_material as ShaderMaterial
	_lamp = get_node_or_null("House/Lamp") as OmniLight3D
	set_look(0.0)

func _lk(key: String, k: float) -> Variant:
	var a = look.get(key)
	var b = look2.get(key, a)
	if a == null:
		return null
	return lerp(a, b, k)

func set_look(k: float) -> void:
	k = clampf(k, 0.0, 1.0)
	if _env:
		var amb = _lk("ambient", k)
		if amb != null:
			_env.ambient_light_color = amb
		var fog = _lk("fog", k)
		if fog != null:
			_env.fog_light_color = fog
		var fd = _lk("fog_density", k)
		if fd != null:
			_env.fog_density = fd
	if _sky_mat:
		var top = _lk("sky_top", k)
		if top != null:
			_sky_mat.set_shader_parameter("top_color", Vector3(top.r, top.g, top.b))
		var hor = _lk("sky_hor", k)
		if hor != null:
			_sky_mat.set_shader_parameter("horizon_color", Vector3(hor.r, hor.g, hor.b))
	if _sun:
		var sc = _lk("sun_color", k)
		if sc != null:
			_sun.light_color = sc
		var se = _lk("sun_energy", k)
		if se != null:
			_sun.light_energy = se
		var sr = _lk("sun_rot", k)
		if sr != null:
			_sun.rotation = sr
	if _lamp:
		_lamp.light_energy = lerpf(0.4, 6.0, k)
		_lamp.omni_range = lerpf(7.0, 11.0, k)

## 小關覆寫：種樹、蓋房子
func _dress() -> void:
	pass

func in_house(x: float, z: float) -> bool:
	if not has_house:
		return false
	var lx := x - house_center.x
	var lz := z - house_center.y
	var room := absf(lx) < house_half_x - 0.15 and absf(lz) < house_half_z - 0.05
	# 門開在 +Z。站在門檻上也算進了屋子，家豪才救得到小紅帽。
	var porch := absf(lx) < door_half + 0.45 and lz > house_half_z - 0.55 and lz < house_half_z + 1.25
	return room or porch

## 繞過木屋的路：直線被牆擋住時，回傳下一個要先走去的點。
## 共用的「繞牆」只看擋住的那一面牆、往近的那一端走，走到屋角會被另一面牆推回去，卡在屋角來回抖。
## 這裡用屋子四個外角＋門口內外兩點做一張小地圖，找最短路（每一格都重算，結果穩定，不會來回跳）。
const ROUTE_PAD := 0.9          # 外角離牆多遠
func route_point(from: Vector3, to: Vector3) -> Vector3:
	if not has_house or _route_clear(Vector2(from.x, from.z), Vector2(to.x, to.z)):
		return to
	var c := house_center
	var ex := house_half_x + ROUTE_PAD
	var ez := house_half_z + ROUTE_PAD
	var nodes: Array = [Vector2(from.x, from.z), Vector2(to.x, to.z),
		c + Vector2(-ex, -ez), c + Vector2(ex, -ez), c + Vector2(ex, ez), c + Vector2(-ex, ez),
		c + Vector2(0, house_half_z + 1.0), c + Vector2(0, house_half_z - 0.9)]
	var n := nodes.size()
	var dist: Array = []
	var prev: Array = []
	var done: Array = []
	for i in n:
		dist.append(INF)
		prev.append(-1)
		done.append(false)
	dist[0] = 0.0
	for _k in n:
		var u := -1
		for i in n:
			if not done[i] and (u < 0 or dist[i] < dist[u]):
				u = i
		if u < 0 or dist[u] == INF:
			break
		done[u] = true
		if u == 1:
			break
		for v in n:
			if done[v] or v == u:
				continue
			var a: Vector2 = nodes[u]
			var b: Vector2 = nodes[v]
			if not _route_clear(a, b):
				continue
			var nd: float = dist[u] + a.distance_to(b)
			if nd < dist[v]:
				dist[v] = nd
				prev[v] = u
	if prev[1] < 0:
		return to                    # 找不到路：照舊直直走
	var step := 1
	while prev[step] != 0:
		step = prev[step]
	var p: Vector2 = nodes[step]
	return Vector3(p.x, to.y, p.y)

## a→b 有沒有穿過木屋的牆（牆兩端多算 0.3，跟共用的繞牆判斷一樣）
func _route_clear(a: Vector2, b: Vector2) -> bool:
	for seg in wall_segments:
		var s0: Vector2 = seg[0]
		var s1: Vector2 = seg[1]
		var d := (s1 - s0).normalized()
		if Geometry2D.segment_intersects_segment(a, b, s0 - d * 0.3, s1 + d * 0.3) != null:
			return false
	return true

## 狼外婆不准走出木屋
func clamp_house(p: Vector3) -> Vector3:
	var x := clampf(p.x, house_center.x - house_half_x + 0.55, house_center.x + house_half_x - 0.55)
	var z := clampf(p.z, house_center.y - house_half_z + 0.55, house_center.y + house_half_z - 0.5)
	return Vector3(x, p.y, z)

func house_walls() -> Array:
	var c := house_center
	var x0 := c.x - house_half_x
	var x1 := c.x + house_half_x
	var z0 := c.y - house_half_z
	var z1 := c.y + house_half_z
	var g := door_half
	# 門開在 +Z（朝家豪來的方向）
	return [
		[Vector2(x0, z0), Vector2(x0, z1)],
		[Vector2(x1, z0), Vector2(x1, z1)],
		[Vector2(x0, z0), Vector2(x1, z0)],
		[Vector2(x0, z1), Vector2(c.x - g, z1)],
		[Vector2(c.x + g, z1), Vector2(x1, z1)],
	]

const K_CASTLE := "res://levels/forest/assets/kenney_castle/"
const K_SURV := "res://levels/forest/assets/kenney_survival/"
const K_PLAT := "res://levels/forest/assets/kenney_platformer/"

## 樹：用 Kenney 的樹模型。結構跟舊的一樣（第 0 個孩子是樹幹、"Crown" 是樹冠），戰局腳本靠這個結構做倒樹、燒焦。
## 整棵模型放在 Crown 底下（著火時整棵一起變焦黑、縮小）；第 0 個孩子只是空的樹幹節點，真正的高度記在 meta "h"。
func add_tree(x: float, z: float, spacing: float, avoid: Array, corridor: Dictionary) -> bool:
	if _tree_blocked(x, z, spacing, avoid, corridor):
		return false
	var y := height_at(x, z)
	var n := Node3D.new()
	n.name = "Tree%d" % trees.size()
	n.position = Vector3(x, y, z)
	add_child(n)
	var roll := absf(sin(x * 3.7 + z * 1.3))
	var big := roll > 0.38
	var sc := (1.55 + 0.55 * absf(sin(x * 1.7 + z * 0.8))) if big else (1.9 + 0.4 * absf(sin(z * 2.9)))
	var h := (1.85 if big else 1.35) * sc
	var trunk := Node3D.new()
	trunk.name = "Trunk"
	n.add_child(trunk)
	var crown := Node3D.new()
	crown.name = "Crown"
	n.add_child(crown)
	var ps := load(K_CASTLE + ("tree-large.glb" if big else "tree-small.glb")) as PackedScene
	if ps:
		var m := ps.instantiate() as Node3D
		m.scale = Vector3.ONE * sc
		m.rotation.y = fmod(x * 5.1 + z * 2.3, TAU)
		crown.add_child(m)
		_soften_tree(m)
	n.set_meta("h", h)
	var spot := [Vector2(x, z), 0.42]
	obstacles.append(spot)
	trees.append({
		"pos": Vector3(x, y, z), "node": n, "rest": n.position, "block": spot,
		"radius": 0.42, "alive": true, "fall": 0.0,
	})
	return true

var _tree_mats := {}
var tree_tint := Color(0.74, 0.80, 0.66)      # 小關在 _layout_level 設：每一關樹的顏色跟著時段變

## 樹的材質：顏色壓暗、降一點飽和（原本薄荷綠＋亮橘像玩具），鏡頭貼近時用抖色漸隱，不會一棵樹擋掉半個畫面
func _soften_tree(root: Node3D, mul := 1.0) -> void:
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		for i in m.mesh.get_surface_count():
			var src := m.get_active_material(i) as StandardMaterial3D
			if src == null:
				continue
			var key := "%d_%.2f" % [src.get_instance_id(), mul]
			if not _tree_mats.has(key):
				var d := src.duplicate() as StandardMaterial3D
				d.albedo_color = Color(tree_tint.r * mul, tree_tint.g * mul, tree_tint.b * mul)
				d.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
				d.distance_fade_min_distance = 0.9
				d.distance_fade_max_distance = 3.2
				_tree_mats[key] = d
			m.set_surface_override_material(i, _tree_mats[key])

## 擺一個模型（不擋路，除非給 block）。path 是 K_SURV / K_CASTLE 底下的檔名
func prop(path: String, x: float, z: float, yaw := 0.0, scale := 1.0, block := 0.0) -> Node3D:
	return place_model(self, path, Vector3(x, 0, z), yaw, scale, block)

## 營地：帳篷、營火、柴堆、木桶、木箱（中心 c）
func camp(c: Vector2, yaw := 0.0) -> void:
	var r := Basis(Vector3.UP, yaw)
	var at := func(v: Vector3) -> Vector2:
		var w: Vector3 = r * v
		return Vector2(c.x + w.x, c.y + w.z)
	var t: Vector2 = at.call(Vector3(-1.6, 0, 0.0))
	prop(K_SURV + "tent.glb", t.x, t.y, yaw + 0.4, 2.4, 1.5)
	var f: Vector2 = at.call(Vector3(1.0, 0, 0.9))
	prop(K_SURV + "campfire-pit.glb", f.x, f.y, 0.0, 2.0, 0.6)
	var w: Vector2 = at.call(Vector3(0.9, 0, -1.4))
	prop(K_SURV + "resource-wood.glb", w.x, w.y, yaw + 0.7, 2.2, 0.8)
	var b: Vector2 = at.call(Vector3(-0.6, 0, 1.9))
	prop(K_SURV + "barrel.glb", b.x, b.y, 0.0, 2.0, 0.45)
	var bx: Vector2 = at.call(Vector3(2.0, 0, -0.2))
	prop(K_SURV + "box.glb", bx.x, bx.y, yaw - 0.5, 2.0, 0.5)

## 樹墩（砍完留下來的）和橫躺的原木，純裝飾
func stumps(pts: Array) -> void:
	for p in pts:
		var v: Vector2 = p
		prop(K_CASTLE + "tree-trunk.glb", v.x, v.y, fmod(v.x * 3.0, TAU), 2.6)

func logs(pts: Array) -> void:
	for p in pts:
		var v: Vector3 = p       # x, z, yaw
		prop(K_CASTLE + "tree-log.glb", v.x, v.y, v.z, 2.4, 0.0)

## 石頭堆（擋路的小岩石）
func rocks(pts: Array) -> void:
	for p in pts:
		var v: Vector3 = p       # x, z, scale
		var big: bool = v.z > 1.6
		prop(K_CASTLE + ("rocks-large.glb" if big else "rocks-small.glb"), v.x, v.y, fmod(v.x * 1.7 + v.y, TAU), v.z, 0.9 * v.z / 2.0)

## 一排矮木柵欄
func fence_row(a: Vector2, b: Vector2, step := 1.05) -> void:
	var len := a.distance_to(b)
	var n := maxi(int(len / step), 1)
	var yaw := atan2(b.x - a.x, b.y - a.y) + PI * 0.5
	for i in n:
		var q := a.lerp(b, (float(i) + 0.5) / float(n))
		prop(K_PLAT + "fence-rope.glb", q.x, q.y, yaw, 1.5)

func scatter_trees(count: int, spacing: float, avoid: Array, corridor: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed + 90
	var guard := 0
	while trees.size() < count and guard < 5000:
		guard += 1
		var x := rng.randf_range(play_min.x + 1.4, play_max.x - 1.4)
		var z := rng.randf_range(play_min.y + 1.4, play_max.y - 1.4)
		add_tree(x, z, spacing, avoid, corridor)
	if trees.size() < count:
		guard = 0
		while trees.size() < count and guard < 4000:
			guard += 1
			var x := rng.randf_range(play_min.x + 1.4, play_max.x - 1.4)
			var z := rng.randf_range(play_min.y + 1.4, play_max.y - 1.4)
			add_tree(x, z, spacing * 0.82, avoid, corridor)

## 繞著木屋種一圈，南邊留給回家豪的路
func ring_trees(radius: float, n: int, spacing: float, avoid: Array, corridor: Dictionary) -> void:
	for i in n:
		var a := TAU * float(i) / float(n)
		if absf(wrapf(a, -PI, PI)) < 0.62:
			continue
		add_tree(house_center.x + sin(a) * radius, house_center.y + cos(a) * radius * 0.92, spacing, avoid, corridor)

func build_house() -> void:
	has_house = true
	var y0 := height_at(house_center.x, house_center.y)
	var house := Node3D.new()
	house.name = "House"
	house.position = Vector3(house_center.x, y0, house_center.y)
	add_child(house)
	var wood := painted(Color(0.50, 0.33, 0.18), 0.3, 0.4)
	var wood2 := painted(Color(0.42, 0.27, 0.14), 0.3, 0.4)
	var dark := _toon(Color(0.28, 0.17, 0.09))
	var roof_c := painted(Color(0.40, 0.21, 0.17), 0.4, 0.45)
	var roof2 := painted(Color(0.36, 0.14, 0.11), 0.3, 0.4)
	var stone := _toon(Color(0.52, 0.50, 0.47))
	var hx := house_half_x
	var hz := house_half_z
	# 石頭地基
	_box(house, Vector3(hx * 2.0 + 0.4, 0.28, hz * 2.0 + 0.4), Vector3(0, 0.1, 0), stone)
	# 牆：一圈一圈橫的原木（深淺交錯），門開在 +Z
	var rows := 6
	for r in rows:
		var y := 0.42 + 0.36 * float(r)
		var m := wood if r % 2 == 0 else wood2
		_box(house, Vector3(0.22, 0.34, hz * 2.0 + 0.1), Vector3(-hx, y, 0), m)
		_box(house, Vector3(0.22, 0.34, hz * 2.0 + 0.1), Vector3(hx, y, 0), m)
		_box(house, Vector3(hx * 2.0 + 0.1, 0.34, 0.22), Vector3(0, y, -hz), m)
		var side_len := hx - door_half
		var side_cx := (hx + door_half) * 0.5
		_box(house, Vector3(side_len + 0.1, 0.34, 0.22), Vector3(-side_cx, y, hz), m)
		_box(house, Vector3(side_len + 0.1, 0.34, 0.22), Vector3(side_cx, y, hz), m)
	# 四根角柱、門框
	for cx in [-hx, hx]:
		for cz in [-hz, hz]:
			_box(house, Vector3(0.3, 2.5, 0.3), Vector3(cx, 1.3, cz), dark)
	_box(house, Vector3(door_half * 2.0 + 0.3, 0.22, 0.3), Vector3(0, 2.2, hz), dark)
	_box(house, Vector3(0.2, 2.1, 0.26), Vector3(-door_half, 1.1, hz), dark)
	_box(house, Vector3(0.2, 2.1, 0.26), Vector3(door_half, 1.1, hz), dark)
	_box(house, Vector3(door_half * 2.4, 0.1, 0.9), Vector3(0, 0.3, hz + 0.55), stone)   # 門前石階
	# 屋頂：兩片厚板加屋脊，屋簷伸出牆外
	_box(house, Vector3(hx * 2.0 + 0.7, 0.22, hz + 0.8), Vector3(0, 2.95, -hz * 0.5), roof_c, Vector3(0.62, 0, 0))
	_box(house, Vector3(hx * 2.0 + 0.7, 0.22, hz + 0.8), Vector3(0, 2.95, hz * 0.5), roof_c, Vector3(-0.62, 0, 0))
	_box(house, Vector3(hx * 2.0 + 1.3, 0.2, 0.34), Vector3(0, 3.5, 0), roof2)
	for k in 5:
		var rx := -hx + 0.3 + (hx * 2.0 - 0.6) * float(k) / 4.0
		_box(house, Vector3(0.12, 0.1, hz * 1.4), Vector3(rx, 3.02, -hz * 0.52), roof2, Vector3(0.62, 0, 0))
		_box(house, Vector3(0.12, 0.1, hz * 1.4), Vector3(rx, 3.02, hz * 0.52), roof2, Vector3(-0.62, 0, 0))
	# 石煙囪
	_box(house, Vector3(0.45, 1.3, 0.45), Vector3(-hx + 0.8, 3.0, -hz + 0.7), stone)
	_box(house, Vector3(0.58, 0.12, 0.58), Vector3(-hx + 0.8, 3.7, -hz + 0.7), dark)
	# 裡面：床、桌子
	var cloth := _toon(Color(0.75, 0.22, 0.28))
	_box(house, Vector3(1.3, 0.28, 0.7), Vector3(-1.5, 0.3, -1.15), dark)
	_box(house, Vector3(1.35, 0.12, 0.75), Vector3(-1.5, 0.48, -1.15), cloth)
	_box(house, Vector3(0.7, 0.42, 0.5), Vector3(1.35, 0.4, -0.15), wood)
	# 窗：會發光的窗片＋窗框＋窗台花箱
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(1.0, 0.82, 0.5)
	glow.emission_enabled = true
	glow.emission = Color(1.0, 0.7, 0.35)
	glow.emission_energy_multiplier = 1.4
	for w in [Vector3(-hx - 0.02, 1.55, 0.2), Vector3(hx + 0.02, 1.55, -0.3)]:
		var pane := _box(house, Vector3(0.1, 0.62, 0.74), w, glow)
		pane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_box(house, Vector3(0.16, 0.74, 0.12), w + Vector3(0, 0, 0.4), dark)
		_box(house, Vector3(0.16, 0.74, 0.12), w + Vector3(0, 0, -0.4), dark)
		_box(house, Vector3(0.16, 0.1, 0.9), w + Vector3(0, 0.38, 0), dark)
	var flower := [Color(0.95, 0.4, 0.5), Color(0.98, 0.85, 0.3), Color(0.9, 0.9, 0.95)]
	for i in 6:
		_box(house, Vector3(0.12, 0.12, 0.12), Vector3(-hx - 0.18, 1.05, -0.25 + 0.2 * float(i)), _toon(flower[i % 3]))
	# 屋裡的燈：天黑了窗子會亮起來（強度由 set_look 控制）
	var lamp := OmniLight3D.new()
	lamp.name = "Lamp"
	lamp.light_color = Color(1.0, 0.72, 0.4)
	lamp.light_energy = 0.5
	lamp.omni_range = 7.0
	lamp.position = Vector3(0, 1.7, 0.2)
	house.add_child(lamp)

func build_hood(pos: Vector3) -> void:
	var y := height_at(pos.x, pos.z)
	var n := Node3D.new()
	n.name = "RedHood"
	n.position = Vector3(pos.x, y, pos.z)
	n.rotation.y = PI   # 面向木屋裡面的狼外婆（-Z）
	add_child(n)
	var skin := _toon(Color(0.96, 0.78, 0.66))
	var red := _toon(Color(0.88, 0.10, 0.14))
	var dress := _toon(Color(0.95, 0.93, 0.86))
	var brown := _toon(Color(0.40, 0.24, 0.12))
	# 白洋裝、紅斗篷（錐形，遠看是個小人）、頭＋紅兜帽
	var skirt := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.14
	cm.bottom_radius = 0.34
	cm.height = 0.62
	cm.radial_segments = 10
	skirt.mesh = cm
	skirt.material_override = dress
	skirt.position = Vector3(0, 0.33, 0)
	n.add_child(skirt)
	var cape := MeshInstance3D.new()
	var cp := CylinderMesh.new()
	cp.top_radius = 0.1
	cp.bottom_radius = 0.4
	cp.height = 0.7
	cp.radial_segments = 10
	cape.mesh = cp
	cape.material_override = red
	cape.position = Vector3(0, 0.62, -0.05)
	n.add_child(cape)
	_box(n, Vector3(0.1, 0.1, 0.1), Vector3(0, 1.0, 0.0), skin)
	var head := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.16
	sm.height = 0.32
	head.mesh = sm
	head.material_override = skin
	head.position = Vector3(0, 1.1, 0.02)
	n.add_child(head)
	var hood := MeshInstance3D.new()
	var hm := SphereMesh.new()
	hm.radius = 0.2
	hm.height = 0.36
	hood.mesh = hm
	hood.material_override = red
	hood.position = Vector3(0, 1.15, -0.04)
	n.add_child(hood)
	_box(n, Vector3(0.22, 0.14, 0.2), Vector3(0.3, 0.45, 0.16), brown)   # 籃子
	# 頭頂一個會發光的小標記，遠看也找得到她
	var mark := StandardMaterial3D.new()
	mark.albedo_color = Color(1.0, 0.9, 0.3)
	mark.emission_enabled = true
	mark.emission = Color(1.0, 0.8, 0.2)
	mark.emission_energy_multiplier = 1.6
	mark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var m := MeshInstance3D.new()
	var mm := SphereMesh.new()
	mm.radius = 0.07
	mm.height = 0.14
	m.mesh = mm
	m.material_override = mark
	m.position = Vector3(0, 1.62, 0)
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(m)

func dirt_path(a: Vector2, b: Vector2) -> void:
	# 不規則的泥土小路：一塊一塊深淺不一、左右搖擺的土塊，兩側撒碎石
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed + 5
	var dark := _toon(Color(0.40, 0.29, 0.16))
	var light := _toon(Color(0.50, 0.38, 0.21))
	var length := a.distance_to(b)
	var n := maxi(int(length / 0.9), 1)
	var yaw := atan2(b.x - a.x, b.y - a.y)
	var side := Vector2(cos(yaw), -sin(yaw))
	for i in n:
		var p := a.lerp(b, (float(i) + 0.5) / float(n)) + side * rng.randf_range(-0.22, 0.22)
		var y := height_at(p.x, p.y)
		var w := rng.randf_range(1.3, 1.9)
		_box(self, Vector3(w, 0.03, length / float(n) + 0.35), Vector3(p.x, y + 0.012 + 0.004 * float(i % 3), p.y), dark if i % 2 == 0 else light, Vector3(0, yaw + rng.randf_range(-0.12, 0.12), 0))
	var stone := _toon(Color(0.55, 0.52, 0.48))
	for i in int(length * 1.2):
		var t := rng.randf()
		var q := a.lerp(b, t) + side * (rng.randf_range(0.9, 1.5) * (1.0 if rng.randf() < 0.5 else -1.0))
		var s2 := rng.randf_range(0.08, 0.2)
		_box(self, Vector3(s2, s2 * 0.6, s2), Vector3(q.x, height_at(q.x, q.y) + s2 * 0.25, q.y), stone, Vector3(0, rng.randf() * TAU, 0))

func _tree_blocked(x: float, z: float, spacing: float, avoid: Array, corridor: Dictionary) -> bool:
	if x < play_min.x + 1.0 or x > play_max.x - 1.0 or z < play_min.y + 1.0 or z > play_max.y - 1.0:
		return true
	if has_house and Vector2(x, z).distance_to(house_center) < house_clear:
		return true
	if not corridor.is_empty() and _seg_dist(Vector2(x, z), corridor.a, corridor.b) < float(corridor.half):
		return true
	for item in avoid:
		var p: Vector3 = item.p
		if Vector2(x, z).distance_to(Vector2(p.x, p.z)) < float(item.r):
			return true
	for t in trees:
		var tp: Vector3 = t.pos
		if Vector2(x, z).distance_to(Vector2(tp.x, tp.z)) < spacing:
			return true
	return false

## 樹腳的灌木（用共用素材的灌木模型，不擋路、也不能砍，只是讓林子看起來滿）
func undergrowth(n: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed + 44
	var ps := load("res://levels/forest/assets/BushBerries.glb") as PackedScene
	var placed := 0
	var guard := 0
	while placed < n and guard < 2500:
		guard += 1
		var x := rng.randf_range(play_min.x + 0.8, play_max.x - 0.8)
		var z := rng.randf_range(play_min.y + 0.8, play_max.y - 0.8)
		if has_house and Vector2(x, z).distance_to(house_center) < house_clear - 0.8:
			continue
		if _near_tree(x, z, 1.15):
			continue
		var y := height_at(x, z)
		var s := rng.randf_range(0.55, 0.95)
		if ps:
			var b := ps.instantiate() as Node3D
			b.position = Vector3(x, y - 0.03, z)
			b.rotation.y = rng.randf_range(0.0, TAU)
			b.scale = Vector3.ONE * s
			add_child(b)
		placed += 1

func mushrooms(n: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed + 71
	var cap := _toon(Color(0.72, 0.18, 0.16))
	var stem := _toon(Color(0.9, 0.86, 0.78))
	var placed := 0
	var guard := 0
	while placed < n and guard < 1500:
		guard += 1
		var x := rng.randf_range(play_min.x + 1.0, play_max.x - 1.0)
		var z := rng.randf_range(play_min.y + 1.0, play_max.y - 1.0)
		if has_house and Vector2(x, z).distance_to(house_center) < 4.2:
			continue
		if _near_tree(x, z, 0.7):
			continue
		var y := height_at(x, z)
		_box(self, Vector3(0.08, 0.16, 0.08), Vector3(x, y + 0.08, z), stem)
		_box(self, Vector3(0.22, 0.08, 0.22), Vector3(x, y + 0.18, z), cap)
		placed += 1

func _near_tree(x: float, z: float, r: float) -> bool:
	for t in trees:
		var p: Vector3 = t.pos
		if Vector2(x, z).distance_to(Vector2(p.x, p.z)) < r:
			return true
	return false

func _seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var len2 := ab.length_squared()
	if len2 < 0.001:
		return p.distance_to(a)
	var t := clampf((p - a).dot(ab) / len2, 0.0, 1.0)
	return p.distance_to(a + ab * t)
