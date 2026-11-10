extends "res://scripts/world_builder.gd"
## 通用場地（template，所有關卡共用；各關不要改這個檔案）
##
## 一塊長方形的遊玩範圍、外面一圈森林當世界邊界、地面微微起伏、長草。
## 各小關的 world.gd 這樣寫：
##   extends "res://scripts/world/arena_world.gd"
##   func _configure() -> void:
##       play_min = Vector2(-14, -12)
##       hero_start = Vector3(0, 0, 10)
##       props = [{"model": "res://assets/farm/Hay.glb", "pos": Vector3(-4, 0, 2), "scale": 7.0, "block": 0.7}]
##       ponds = [{"center": Vector2(6, -4), "r": 3.5}]
## 想要更特別的地形：覆寫 _extra_height(x, z) 加高度，或覆寫 _build_extra() 自己蓋東西。
## 戰局（battle_base.gd）會用到的東西都在這裡：height_at、walkable、in_water、clamp_play、
## obstacles、fence_segments、wall_segments、ray_ground…

# ---------------------------------------------------------------- 在 _configure() 裡改這些

var play_min := Vector2(-14.0, -14.0)    # 遊玩範圍（x, z）的最小角
var play_max := Vector2(14.0, 14.0)      # 遊玩範圍的最大角
var hero_start := Vector3(0.0, 0.0, 11.0)
var hero_yaw := PI                       # 家豪一開始面向哪（PI = 面向 -Z）
var camera_start := Vector3(4.0, 6.0, 17.0)   # 神（玩家）一開始在哪
var camera_look := Vector3(0.0, 0.0, 0.0)     # 神一開始看哪
var hill_amount := 1.0                   # 地面起伏的大小（0 = 平地）
var forest_band := 10.0                  # 外圍森林的厚度
var grass_count := 1800                  # 草叢數量
var ground_a := Color(0.52, 0.70, 0.26)  # 地面顏色
var ground_b := Color(0.42, 0.64, 0.22)
var dirt_color := Color(0.82, 0.56, 0.32)
var tree_green := Color(0.29, 0.49, 0.25)
## 擺設：[{"model": glb 路徑, "pos": Vector3, "yaw": 0.0, "scale": 1.0, "block": 擋路半徑（0 = 不擋）}]
var props: Array = []
## 矮圍欄（家豪飛得過去、敵人要繞）：[[Vector2 起點, Vector2 終點], ...]
var fences: Array = []
## 牆（誰都過不去）：[[Vector2, Vector2], ...]
var walls: Array = []
## 水池：[{"center": Vector2, "r": 半徑, "island": 小島半徑（可省略）}]，敵人走進去會淹死
var ponds: Array = []

# ---------------------------------------------------------------- 給戰局用的（自動算好，不用改）

var obstacles: Array = []           # [[Vector2 center, float radius], ...]
var fence_segments: Array = []
var wall_segments: Array = []
var water_y := 0.0

## 子類別覆寫：設定上面那些變數
func _configure() -> void:
	pass

## 子類別覆寫：在地面高度上再加東西（世界座標，公尺）
func _extra_height(_x: float, _z: float) -> float:
	return 0.0

## 子類別覆寫：場地建好之後再蓋自己的東西
func _build_extra() -> void:
	pass

func _ready() -> void:
	_configure()
	_rng.seed = world_seed
	_noise.seed = world_seed
	_noise.frequency = 0.035
	_noise.fractal_octaves = 3
	_detail.seed = world_seed + 1
	_detail.frequency = 0.2
	fence_segments = fences.duplicate()
	wall_segments = walls.duplicate()
	_layout = Node3D.new()
	_layout.name = "Layout"
	_layout.scale = Vector3.ONE * LAYOUT_SCALE
	add_child(_layout)
	_make_materials()
	_build_heights()
	_build_terrain()
	_build_far_ground()
	_build_rock_variants()
	_build_distant_layers()
	_build_fence_visuals()
	_build_props()
	_build_ponds()
	_build_extra()
	_build_arena_grass()
	_build_arena_forest()
	_place_player()

# ---------------------------------------------------------------- 地形

func arena_height(x: float, z: float) -> float:
	var h := (_noise.get_noise_2d(x * 1.1 + 40.0, z * 1.1) * 1.9 + _noise.get_noise_2d(x * 2.6, z * 2.6 + 17.0) * 0.45) * hill_amount
	h += _noise.get_noise_2d(x * 2.0, z * 2.0) * 0.08
	# 水池挖下去
	for p in ponds:
		var c: Vector2 = p.center
		var r: float = p.r
		var isl: float = p.get("island", 0.0)
		var pd := Vector2(x, z).distance_to(c)
		var basin := 1.0 - sstep(r - 1.2, r + 0.3, pd)
		if isl > 0.0:
			basin *= sstep(isl - 0.2, isl + 0.9, pd)
		h -= 1.5 * basin
	# 遊玩範圍外慢慢升高一點，森林看起來比較厚
	h += sstep(0.0, 14.0, play_dist(x, z)) * 1.5
	return h + _extra_height(x, z)

func _raw_height(x: float, z: float) -> float:
	var h := arena_height(x * LAYOUT_SCALE, z * LAYOUT_SCALE) / LAYOUT_SCALE
	var e := maxf(absf(x), absf(z))
	return lerpf(h, -45.0, sstep(92.0, 119.0, e))

func _terrain_weights(x: float, z: float, nrm: Vector3) -> Color:
	var dirt := sstep(0.35, 0.7, _noise.get_noise_2d(x * 2.3, z * 2.3)) * 0.55
	var steep := sstep(0.35, 0.7, 1.0 - nrm.y)
	return Color(0.0, dirt, steep, 1.0)

func _tweak_terrain_material(mat: ShaderMaterial) -> void:
	mat.set_shader_parameter("ground_a", ground_a)
	mat.set_shader_parameter("ground_b", ground_b)
	mat.set_shader_parameter("grassy", ground_b.darkened(0.1))
	mat.set_shader_parameter("sand_c", Color(0.95, 0.70, 0.42))
	mat.set_shader_parameter("dirt_c", dirt_color)
	mat.set_shader_parameter("rock_c", Color(0.58, 0.52, 0.46))

# ---------------------------------------------------------------- 給戰局用的查詢

func in_play(x: float, z: float) -> bool:
	return x >= play_min.x and x <= play_max.x and z >= play_min.y and z <= play_max.y

## 到遊玩範圍的距離（範圍內為 0）
func play_dist(x: float, z: float) -> float:
	return Vector2(maxf(maxf(play_min.x - x, x - play_max.x), 0.0), maxf(maxf(play_min.y - z, z - play_max.y), 0.0)).length()

func clamp_play(p: Vector3) -> Vector3:
	return Vector3(clampf(p.x, play_min.x, play_max.x), p.y, clampf(p.z, play_min.y, play_max.y))

func in_water(x: float, z: float) -> bool:
	for p in ponds:
		var d := Vector2(x, z).distance_to(p.center)
		var isl: float = p.get("island", 0.0)
		if d < float(p.r) - 0.25 and (isl <= 0.0 or d > isl + 0.35):
			return true
	return false

func on_island(x: float, z: float) -> bool:
	for p in ponds:
		var isl: float = p.get("island", 0.0)
		if isl > 0.0 and Vector2(x, z).distance_to(p.center) <= isl + 0.35:
			return true
	return false

func walkable(x: float, z: float) -> bool:
	return in_play(x, z) and not in_water(x, z)

## 巨石可以放的地方
func rock_ground(x: float, z: float) -> bool:
	return in_play(x, z)

## 從 from 走到 to 的下一個路點（有門的建築可以覆寫，見農場範例）
func route_point(_from: Vector3, to: Vector3) -> Vector3:
	return to

## 從 origin 沿 dir 打到地面的點（給道具瞄準用）；沒打到回傳 null
func ray_ground(origin: Vector3, dir: Vector3, max_dist := 80.0) -> Variant:
	var step := 0.25
	var prev := origin
	var t := 0.0
	while t < max_dist:
		t += step
		var p := origin + dir * t
		if p.y <= height_at(p.x, p.z):
			var lo := prev
			var hi := p
			for i in 8:
				var mid := (lo + hi) * 0.5
				if mid.y <= height_at(mid.x, mid.z):
					hi = mid
				else:
					lo = mid
			return Vector3(hi.x, height_at(hi.x, hi.z), hi.z)
		prev = p
		step = minf(step * 1.04, 1.0)
	return null

# ---------------------------------------------------------------- 建東西的小工具（子類別也可以用）

func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi

func _toon(c: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/toon_color.gdshader")
	m.set_shader_parameter("albedo", c)
	return m

## 放一個 glb 模型；block_radius > 0 的話角色會繞開它
func place_model(parent: Node3D, path: String, pos: Vector3, yaw := 0.0, scale := 1.0, block_radius := 0.0) -> Node3D:
	var ps := load(path) as PackedScene
	if ps == null:
		push_warning("找不到模型：" + path)
		return null
	var n := ps.instantiate() as Node3D
	n.position = Vector3(pos.x, height_at(pos.x, pos.z) - 0.05, pos.z)
	n.rotation.y = yaw
	n.scale = Vector3.ONE * scale
	parent.add_child(n)
	if block_radius > 0.0:
		obstacles.append([Vector2(pos.x, pos.z), block_radius])
	return n

func _build_props() -> void:
	var node := Node3D.new()
	node.name = "Props"
	add_child(node)
	for p in props:
		place_model(node, String(p.model), p.pos, float(p.get("yaw", 0.0)), float(p.get("scale", 1.0)), float(p.get("block", 0.0)))

func _build_fence_visuals() -> void:
	var node := Node3D.new()
	node.name = "Fences"
	add_child(node)
	var wood := _toon(Color(0.66, 0.48, 0.30))
	var dark := _toon(Color(0.52, 0.37, 0.23))
	for seg in fence_segments:
		_fence_line(node, seg[0], seg[1], wood, dark)
	var wall_mat := _toon(Color(0.78, 0.74, 0.68))
	for seg in wall_segments:
		var a: Vector2 = seg[0]
		var b: Vector2 = seg[1]
		var m := (a + b) * 0.5
		var y := height_at(m.x, m.y)
		_box(node, Vector3(0.3, 3.0, a.distance_to(b)), Vector3(m.x, y + 1.5, m.y), wall_mat, Vector3(0, atan2((b - a).x, (b - a).y), 0))

func _fence_line(parent: Node3D, a: Vector2, b: Vector2, wood: Material, dark: Material) -> void:
	var len := a.distance_to(b)
	var count := maxi(int(len / 2.2), 1)
	var dir := (b - a) / len
	var yaw := atan2(dir.x, dir.y)
	for i in count + 1:
		var p := a.lerp(b, float(i) / count)
		var y := height_at(p.x, p.y)
		_box(parent, Vector3(0.16, 1.1, 0.16), Vector3(p.x, y + 0.5, p.y), dark, Vector3(0, yaw, 0.03 * sin(i * 1.9)))
	for h in [0.4, 0.8]:
		for i in count:
			var p0 := a.lerp(b, float(i) / count)
			var p1 := a.lerp(b, float(i + 1) / count)
			var m := (p0 + p1) * 0.5
			var y := (height_at(p0.x, p0.y) + height_at(p1.x, p1.y)) * 0.5
			_box(parent, Vector3(0.08, 0.12, p0.distance_to(p1) + 0.1), Vector3(m.x, y + h, m.y), wood, Vector3(0, yaw, 0))

func _build_ponds() -> void:
	for p in ponds:
		var c: Vector2 = p.center
		var r: float = p.r
		var wy := arena_height(c.x + r * 0.7, c.y) - 0.6
		water_y = wy
		var water := MeshInstance3D.new()
		water.name = "Pond"
		var cm := CylinderMesh.new()
		cm.top_radius = r - 0.05
		cm.bottom_radius = r - 0.05
		cm.height = 0.04
		cm.radial_segments = 48
		water.mesh = cm
		var wm := ShaderMaterial.new()
		wm.shader = load("res://shaders/water.gdshader")
		wm.set_shader_parameter("island_radius", Vector2(1000.0, 1000.0))
		wm.set_shader_parameter("deep", Color(0.2, 0.55, 0.72))
		wm.set_shader_parameter("light_c", Color(0.6, 0.88, 0.92))
		water.material_override = wm
		water.position = Vector3(c.x, wy, c.y)
		water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(water)

func _build_arena_grass() -> void:
	var spots: Array[Vector3] = []
	for o in obstacles:
		var c: Vector2 = o[0]
		var r: float = o[1]
		for k in int(r * 14):
			var ang := _rng.randf() * TAU
			var p := c + Vector2(cos(ang), sin(ang)) * r * _rng.randf_range(0.85, 1.25)
			spots.append(Vector3(p.x, p.y, _rng.randf_range(0.9, 1.4)))
	var size := play_max - play_min
	for k in grass_count:
		var p := Vector2(_rng.randf_range(play_min.x - 6.0, play_max.x + 6.0), _rng.randf_range(play_min.y - 6.0, play_max.y + 6.0))
		if play_dist(p.x, p.y) > 0.5 or in_water(p.x, p.y):
			continue
		spots.append(Vector3(p.x, p.y, _rng.randf_range(0.7, 1.15)))
	if size.x <= 0.0 or spots.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = _make_grass_mesh()
	mm.instance_count = spots.size()
	for k in spots.size():
		var sp := spots[k]
		var s := sp.z * 0.8
		var bb := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(s, s * _rng.randf_range(0.8, 1.2), s))
		mm.set_instance_transform(k, Transform3D(bb, Vector3(sp.x, height_at(sp.x, sp.y) - 0.04, sp.y)))
		var v := _rng.randf_range(0.85, 1.05)
		mm.set_instance_color(k, Color(0.62 * v, 0.95 * v, 0.5 * v) if _rng.randf() < 0.55 else Color(v, v, v * 0.95))
	var grass := MultiMeshInstance3D.new()
	grass.name = "Grass"
	grass.multimesh = mm
	var gm := ShaderMaterial.new()
	gm.shader = load("res://shaders/grass.gdshader")
	grass.material_override = gm
	grass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(grass)

func _build_arena_forest() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = world_seed + 31
	var blob_rng := RandomNumberGenerator.new()
	blob_rng.seed = world_seed + 32
	var blob := make_rock_mesh(blob_rng, 0, 0.22, false)
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.12
	trunk.bottom_radius = 0.2
	trunk.height = 1.0
	trunk.radial_segments = 6
	trunk.rings = 1
	var trunks: Array[Transform3D] = []
	var crowns: Array[Transform3D] = []
	var cols: Array[Color] = []
	var step := 1.8
	var x := play_min.x - forest_band
	while x <= play_max.x + forest_band:
		var z := play_min.y - forest_band
		while z <= play_max.y + forest_band:
			var px := x + r.randf_range(-0.7, 0.7)
			var pz := z + r.randf_range(-0.7, 0.7)
			var d := play_dist(px, pz)
			# 神（玩家）一開始站的地方附近不種樹，免得一進關卡鏡頭卡在樹裡
			var near_cam := Vector2(px - camera_start.x, pz - camera_start.z).length() < 6.0
			if d > 0.4 and d < forest_band and not near_cam and r.randf() < 0.93:
				var gy := height_at(px, pz)
				var h := r.randf_range(3.6, 6.2) * (1.0 + clampf(d, 0.0, 8.0) * 0.04)
				trunks.append(Transform3D(Basis(Vector3.UP, r.randf() * TAU).scaled(Vector3(1, h * 0.55, 1)), Vector3(px, gy + h * 0.27, pz)))
				var green := Color(tree_green.r + r.randf_range(-0.07, 0.07), tree_green.g + r.randf_range(-0.07, 0.07), tree_green.b + r.randf_range(-0.05, 0.05))
				for k in r.randi_range(2, 3):
					var cr := h * (0.36 - k * 0.07)
					var cb := Basis(Vector3.UP, r.randf() * TAU).scaled(Vector3(cr, cr * 0.85, cr))
					crowns.append(Transform3D(cb, Vector3(px + r.randf_range(-0.2, 0.2), gy + h * (0.55 + k * 0.2), pz + r.randf_range(-0.2, 0.2))))
					cols.append(green.lightened(k * 0.08))
			z += step
		x += step
	var tm := MultiMesh.new()
	tm.transform_format = MultiMesh.TRANSFORM_3D
	tm.mesh = trunk
	tm.instance_count = trunks.size()
	for i in trunks.size():
		tm.set_instance_transform(i, trunks[i])
	var tmi := MultiMeshInstance3D.new()
	tmi.name = "ForestTrunks"
	tmi.multimesh = tm
	tmi.material_override = _toon(Color(0.45, 0.32, 0.2))
	add_child(tmi)
	var cm := MultiMesh.new()
	cm.transform_format = MultiMesh.TRANSFORM_3D
	cm.use_colors = true
	cm.mesh = blob
	cm.instance_count = crowns.size()
	for i in crowns.size():
		cm.set_instance_transform(i, crowns[i])
		cm.set_instance_color(i, cols[i])
	var cmi := MultiMeshInstance3D.new()
	cmi.name = "ForestCrowns"
	cmi.multimesh = cm
	var crown_mat := ShaderMaterial.new()
	crown_mat.shader = load("res://shaders/forest_crown.gdshader")
	cmi.material_override = crown_mat
	add_child(cmi)

func _place_player() -> void:
	var player := get_node_or_null(player_path) as Node3D
	if player == null:
		return
	var p := camera_start
	player.global_position = Vector3(p.x, height_at(p.x, p.z) + p.y, p.z)
	var d := camera_look - player.global_position
	player.rotation = Vector3(0.0, atan2(-d.x, -d.z), 0.0)
	var head := player.get_node_or_null("Head") as Node3D
	if head:
		head.rotation.x = clampf(atan2(d.y, Vector2(d.x, d.z).length()), deg_to_rad(-80.0), deg_to_rad(10.0))
