extends "res://scripts/world/arena_world.gd"
## 劉起佑版的美術底：黃昏的歪斜童話小鎮。
## 小關的 world.gd 改成 extends 這個檔案就會整個換風格，關卡配置（_configure）照舊寫。
## 這裡只動「看起來的樣子」：天空、光、地面、外圍的樹和房子、燈串。
## 遊玩範圍裡不會多出任何擋路的東西，戰局邏輯完全不受影響。

const SKY_SHADER := preload("res://levels/liuchiyu/shaders/dusk_sky.gdshader")
const PAINT_SHADER := preload("res://levels/liuchiyu/shaders/painted.gdshader")
const GLOW_SHADER := preload("res://levels/liuchiyu/shaders/glow.gdshader")
const COBBLE_SHADER := preload("res://levels/liuchiyu/shaders/cobble.gdshader")
const VIGNETTE_SHADER := preload("res://levels/liuchiyu/shaders/vignette.gdshader")

## 牆面、屋頂、旗子、燈泡的配色
const WALL_COLORS := [Color(0.44, 0.30, 0.23), Color(0.33, 0.27, 0.30), Color(0.27, 0.31, 0.32), Color(0.50, 0.38, 0.26), Color(0.37, 0.24, 0.23)]
const ROOF_COLORS := [Color(0.36, 0.15, 0.13), Color(0.21, 0.17, 0.27), Color(0.15, 0.24, 0.26), Color(0.42, 0.24, 0.13)]
## 屋瓦染色：暗紅、紫灰、藍綠、鏽橘
const TILE_TINTS := [Color(0.62, 0.36, 0.36), Color(0.50, 0.42, 0.62), Color(0.36, 0.56, 0.58), Color(0.78, 0.52, 0.36)]
const FAR_WALL := Color(0.17, 0.20, 0.33)
const FAR_ROOF := Color(0.12, 0.13, 0.25)
const CRATE := Color(0.46, 0.33, 0.21)
const STONE := Color(0.30, 0.28, 0.32)
const FLAG_COLORS := [Color(0.50, 0.10, 0.12), Color(0.24, 0.13, 0.40), Color(0.80, 0.42, 0.12), Color(0.12, 0.30, 0.36), Color(0.62, 0.16, 0.30)]
const BULB_COLORS := [Color(1.0, 0.78, 0.45), Color(0.45, 0.95, 1.0), Color(1.0, 0.45, 0.55), Color(1.0, 0.60, 0.25), Color(0.75, 0.60, 1.0)]
const WARM := Color(1.0, 0.70, 0.34)
## 素材包（來源和授權見 assets/CREDITS.txt）
const Q := "res://levels/liuchiyu/assets/quaternius_village/"     # 木框架房子的零件（牆、窗、屋頂）
const KK := "res://levels/liuchiyu/assets/kaykit_halloween/"      # 枯樹、燈籠、南瓜
const KT := "res://levels/liuchiyu/assets/kenney_town/"           # 市集攤位、推車
const KG := "res://levels/liuchiyu/assets/kenney_graveyard/"      # 火盆
const ACCENTS := [Color(1.0, 0.36, 0.52), Color(0.40, 0.92, 1.0), Color(1.0, 0.50, 0.22)]
const WOOD_DARK := Color(0.15, 0.11, 0.15)
const TRUNK := Color(0.20, 0.14, 0.19)

var _art: Node3D                       # 所有裝飾都掛在這底下
var _ar := RandomNumberGenerator.new() # 裝飾專用的亂數（固定 seed，每次長得一樣）
var _paint_cache := {}
var _glow_cache := {}
var _segs: Array[Transform3D] = []     # 樹幹、樹枝、電線：全部用同一個 MultiMesh 畫
var _bulbs: Array[Transform3D] = []
var _bulb_cols: Array[Color] = []
var _leaves: Array[Transform3D] = []
var _leaf_cols: Array[Color] = []

func _init() -> void:
	grass_count = 650

# ---------------------------------------------------------------- 材質小工具

func _paint(c: Color, plank := 0.0, rim := 0.5, shingle := 0.0) -> ShaderMaterial:
	var key := "%s|%.2f|%.2f|%.2f" % [c.to_html(), plank, rim, shingle]
	if not _paint_cache.has(key):
		var m := ShaderMaterial.new()
		m.shader = PAINT_SHADER
		m.set_shader_parameter("albedo", c)
		m.set_shader_parameter("plank", plank)
		m.set_shader_parameter("rim", rim)
		m.set_shader_parameter("shingle", shingle)
		_paint_cache[key] = m
	return _paint_cache[key]

func _glow(c: Color, energy := 3.0) -> ShaderMaterial:
	var key := "%s|%.2f" % [c.to_html(), energy]
	if not _glow_cache.has(key):
		var m := ShaderMaterial.new()
		m.shader = GLOW_SHADER
		m.set_shader_parameter("tint", c)
		m.set_shader_parameter("energy", energy)
		_glow_cache[key] = m
	return _glow_cache[key]

var _scene_cache := {}

## 放一個素材包的模型（位置是 parent 裡的座標）
func _kit(parent: Node3D, path: String, pos := Vector3.ZERO, yaw := 0.0, s := 1.0) -> Node3D:
	if not _scene_cache.has(path):
		_scene_cache[path] = load(path)
	var ps := _scene_cache[path] as PackedScene
	if ps == null:
		push_warning("找不到模型：" + path)
		return Node3D.new()
	var n := ps.instantiate() as Node3D
	n.position = pos
	n.rotation.y = yaw
	n.scale = Vector3.ONE * s
	parent.add_child(n)
	return n

## 把模型裡的玻璃換成會發光的材質（窗戶亮起來）
func _light_glass(n: Node, mat: Material) -> void:
	if n is MeshInstance3D and (n as MeshInstance3D).mesh:
		var mi := n as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(i)
			if m and m.resource_name.contains("WindowGlass"):
				mi.set_surface_override_material(i, mat)
	for c in n.get_children():
		_light_glass(c, mat)

var _tint_cache := {}

## 把模型裡名字含 key 的材質換成染過色的版本（例如每棟房子的屋瓦顏色不一樣）
func _tint(n: Node, key: String, c: Color) -> void:
	if n is MeshInstance3D and (n as MeshInstance3D).mesh:
		var mi := n as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(i) as BaseMaterial3D
			if m and m.resource_name.contains(key):
				var ck := "%s|%s" % [m.resource_name, c.to_html()]
				if not _tint_cache.has(ck):
					var d := m.duplicate() as BaseMaterial3D
					d.albedo_color = c
					_tint_cache[ck] = d
				mi.set_surface_override_material(i, _tint_cache[ck])
	for ch in n.get_children():
		_tint(ch, key, c)

func _cyl(parent: Node3D, bottom: float, top: float, h: float, sides: int, mat: Material, pos: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.bottom_radius = bottom
	cm.top_radius = top
	cm.height = h
	cm.radial_segments = sides
	cm.rings = 1
	mi.mesh = cm
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi

func _lamp_light(parent: Node3D, pos: Vector3, c: Color, energy: float, rng: float) -> void:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = c
	l.light_energy = energy * 1.5
	l.omni_range = rng * 1.15
	l.omni_attenuation = 1.3
	l.shadow_enabled = false
	parent.add_child(l)

## 一段圓柱（樹幹、樹枝、電線共用）：從 p 沿 dir 長 length，半徑 rad
func _seg(p: Vector3, dir: Vector3, length: float, rad: float) -> void:
	var up := dir.normalized()
	var side := up.cross(Vector3(0.31, 0.12, 0.94)).normalized()
	var fwd := side.cross(up)
	_segs.append(Transform3D(Basis(side * rad, up * length, fwd * rad), p + up * length * 0.5))

# ---------------------------------------------------------------- 蓋的順序（接在共用場地的各個步驟後面）

func _tweak_terrain_material(mat: ShaderMaterial) -> void:
	mat.shader = COBBLE_SHADER
	var tex := "res://levels/liuchiyu/assets/polyhaven/monastery_stone_floor_"
	mat.set_shader_parameter("diff_tex", load(tex + "diff_1k.jpg"))
	mat.set_shader_parameter("nor_tex", load(tex + "nor_gl_1k.jpg"))
	mat.set_shader_parameter("rough_tex", load(tex + "rough_1k.jpg"))
	mat.set_shader_parameter("ao_tex", load(tex + "ao_1k.jpg"))
	mat.set_shader_parameter("play_min", play_min)
	mat.set_shader_parameter("play_max", play_max)

func _build_far_ground() -> void:
	super()
	var fg := _layout.get_node_or_null("FarGround") as MeshInstance3D
	if fg and fg.material_override is ShaderMaterial:
		(fg.material_override as ShaderMaterial).set_shader_parameter("color", Color(0.17, 0.17, 0.30))

func _build_distant_layers() -> void:
	super()
	# 遠山變成霧裡的深藍紫剪影，頂端帶一點夕陽的暖色
	_far_rock_material.set_shader_parameter("base_color", Color(0.20, 0.21, 0.37))
	_far_rock_material.set_shader_parameter("dark_color", Color(0.11, 0.12, 0.25))
	_far_rock_material.set_shader_parameter("top_color", Color(0.55, 0.36, 0.40))
	_far_rock_material.set_shader_parameter("top_amount", 0.30)
	_far_rock_material.set_shader_parameter("detail_amount", 0.04)

func _build_fence_visuals() -> void:
	var node := Node3D.new()
	node.name = "Fences"
	add_child(node)
	var wood := _paint(Color(0.36, 0.25, 0.22), 0.0, 0.8)
	var dark := _paint(Color(0.22, 0.15, 0.17), 0.0, 0.8)
	for seg in fence_segments:
		_fence_line(node, seg[0], seg[1], wood, dark)
	var wall_mat := _paint(Color(0.34, 0.30, 0.40))
	for seg in wall_segments:
		var a: Vector2 = seg[0]
		var b: Vector2 = seg[1]
		var m := (a + b) * 0.5
		var y := height_at(m.x, m.y)
		_box(node, Vector3(0.3, 3.0, a.distance_to(b)), Vector3(m.x, y + 1.5, m.y), wall_mat, Vector3(0, atan2((b - a).x, (b - a).y), 0))

func _ensure_art() -> void:
	if _art == null:
		_art = Node3D.new()
		_art.name = "DuskArt"
		add_child(_art)

## 場內擺設：位置和擋路半徑照關卡設定，只把外觀換成小鎮的東西
##   樹 → 扭曲的枯樹；乾草堆 → 木箱木桶堆；灌木 → 矮刺叢；其他模型照原樣放
func _build_props() -> void:
	_ensure_art()
	var pr := RandomNumberGenerator.new()
	pr.seed = world_seed + 77
	var node := Node3D.new()
	node.name = "Props"
	add_child(node)
	for p in props:
		var path := String(p.model)
		var pos: Vector3 = p.pos
		var block := float(p.get("block", 0.0))
		var ground := Vector3(pos.x, height_at(pos.x, pos.z), pos.z)
		var kind := path.get_file().to_lower()
		if kind.contains("tree"):
			_kit(node, KK + "tree_dead_large.gltf", ground - Vector3(0, 0.1, 0), pr.randf() * TAU, 1.35)
		elif kind.contains("hay"):
			_crate_stack(node, ground, pr)
		elif kind.contains("bush"):
			_thorn_bush(ground, pr)
		else:
			place_model(node, path, pos, float(p.get("yaw", 0.0)), float(p.get("scale", 1.0)), block)
			continue
		if block > 0.0:
			obstacles.append([Vector2(pos.x, pos.z), block])

func _crate(parent: Node3D, pos: Vector3, s: float, yaw: float, tilt := 0.0) -> void:
	var root := Node3D.new()
	root.position = pos
	root.rotation = Vector3(0, yaw, tilt)
	parent.add_child(root)
	var edge := _paint(WOOD_DARK, 0.0, 0.8)
	_box(root, Vector3(s, s, s), Vector3(0, s * 0.5, 0), _paint(CRATE, 2.4, 0.8))
	var e := s * 0.09
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_box(root, Vector3(e, s * 1.02, e), Vector3(sx * s * 0.5, s * 0.5, sz * s * 0.5), edge)
	for y in [0.0, s]:
		for sx in [-1.0, 1.0]:
			_box(root, Vector3(e, e, s * 1.02), Vector3(sx * s * 0.5, y, 0), edge)
			_box(root, Vector3(s * 1.02, e, e), Vector3(0, y, sx * s * 0.5), edge)

func _barrel(parent: Node3D, pos: Vector3, r: float, h: float) -> void:
	var root := Node3D.new()
	root.position = pos
	parent.add_child(root)
	var wood := _paint(Color(0.40, 0.26, 0.19), 2.2, 0.8)
	var hoop := _paint(Color(0.13, 0.12, 0.15), 0.0, 0.8)
	_cyl(root, r * 0.84, r, h * 0.5, 10, wood, Vector3(0, h * 0.25, 0))
	_cyl(root, r, r * 0.84, h * 0.5, 10, wood, Vector3(0, h * 0.75, 0))
	for k in [0.2, 0.8]:
		_cyl(root, r * 0.95, r * 0.95, h * 0.07, 10, hoop, Vector3(0, h * k, 0))
	_cyl(root, r * 0.80, r * 0.80, 0.03, 10, hoop, Vector3(0, h, 0))

## 木箱堆：一個大木箱、上面歪歪疊一個小的、旁邊一顆南瓜，頂上放一盞燈籠
func _crate_stack(parent: Node3D, g: Vector3, r: RandomNumberGenerator) -> void:
	var yaw := r.randf() * TAU
	_kit(parent, Q + "Prop_Crate.gltf", g + Vector3(-0.12, -0.04, 0.0), yaw, 0.78)
	_kit(parent, Q + "Prop_Crate.gltf", g + Vector3(-0.08, 0.78, 0.04), yaw + r.randf_range(0.4, 0.9), 0.50)
	_kit(parent, KK + "pumpkin_orange_small.gltf", g + Vector3(0.52, -0.03, 0.24), r.randf() * TAU, 0.9)
	_kit(parent, KK + "lantern_standing.gltf", g + Vector3(-0.08, 1.30, 0.04), r.randf() * TAU, 0.55)
	_box(_art, Vector3(0.13, 0.16, 0.13), g + Vector3(-0.08, 1.52, 0.04), _glow(WARM, 3.6))
	_lamp_light(_art, g + Vector3(-0.08, 1.75, 0.04), WARM, 1.5, 5.0)

## 矮刺叢（不擋路）：貼地的深色葉團，上面幾顆會發光的小果子
func _thorn_bush(g: Vector3, r: RandomNumberGenerator) -> void:
	for k in 5:
		var cr := r.randf_range(0.38, 0.60)
		var off := Vector3(r.randf_range(-0.55, 0.55), r.randf_range(0.10, 0.32), r.randf_range(-0.55, 0.55))
		_leaves.append(Transform3D(Basis(Vector3.UP, r.randf() * TAU).scaled(Vector3(cr, cr * 0.65, cr)), g + off))
		_leaf_cols.append(Color(0.11, 0.20, 0.20).lightened(r.randf_range(0.0, 0.08)))
	for k in 6:
		var off := Vector3(r.randf_range(-0.6, 0.6), r.randf_range(0.35, 0.62), r.randf_range(-0.6, 0.6))
		_bulbs.append(Transform3D(Basis().scaled(Vector3.ONE * 0.05), g + off))
		_bulb_cols.append(Color(1.0, 0.35, 0.50))
	for k in 3:
		var a := r.randf() * TAU
		_seg(g - Vector3(0, 0.1, 0), Vector3(cos(a) * 0.7, 1.0, sin(a) * 0.7), r.randf_range(0.7, 1.0), 0.035)

func _build_extra() -> void:
	_ar.seed = world_seed + 4242
	_ensure_art()
	_apply_atmosphere()
	_build_town()
	_build_kit_decor()
	_build_lights_and_flags()
	_build_fence_lanterns()
	_build_dust()
	_build_vignette()

func _build_arena_grass() -> void:
	super()
	var g := get_node_or_null("Grass") as MultiMeshInstance3D
	if g and g.material_override is ShaderMaterial:
		var m := g.material_override as ShaderMaterial
		m.set_shader_parameter("root_color", Color(0.10, 0.13, 0.16))
		m.set_shader_parameter("tip_color", Color(0.36, 0.44, 0.36))

## 外圍不種原本的圓樹，改成扭來扭去的枯樹（房子在 _build_town 蓋）
func _build_arena_forest() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = world_seed + 31
	var step := 2.6
	var x := play_min.x - forest_band
	while x <= play_max.x + forest_band:
		var z := play_min.y - forest_band
		while z <= play_max.y + forest_band:
			var px := x + r.randf_range(-1.0, 1.0)
			var pz := z + r.randf_range(-1.0, 1.0)
			var d := play_dist(px, pz)
			var near_cam := Vector2(px - camera_start.x, pz - camera_start.z).length() < 7.0
			var pick := r.randf()
			if d > 1.0 and d < forest_band and not near_cam and not _near_house(px, pz) and pick < 0.62:
				if r.randf() < 0.42:
					var tn: String = ["tree_dead_large", "tree_dead_medium", "tree_dead_small", "tree_dead_large"][r.randi() % 4]
					_kit(_art, KK + tn + ".gltf", Vector3(px, height_at(px, pz) - 0.1, pz), r.randf() * TAU, r.randf_range(1.3, 2.3))
				else:
					_twisted_tree(Vector3(px, height_at(px, pz), pz), r, r.randf_range(0.85, 1.35) * (1.0 + clampf(d, 0.0, 8.0) * 0.06))
			z += step
		x += step
	_flush_multimeshes()

# ---------------------------------------------------------------- 天空和光

func _apply_atmosphere() -> void:
	var main := get_parent()
	if main == null:
		return
	var we := main.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if we and we.environment:
		# 先複製一份再改，才不會動到別人關卡共用的那一份
		var env: Environment = we.environment.duplicate()
		var mat := ShaderMaterial.new()
		mat.shader = SKY_SHADER
		var sky := Sky.new()
		sky.sky_material = mat
		env.sky = sky
		# 陰影裡是藍紫色，亮的地方靠夕陽和燈
		env.ambient_light_color = Color(0.45, 0.48, 0.60)
		env.ambient_light_energy = 0.92
		env.fog_light_color = Color(0.20, 0.30, 0.46)
		env.fog_density = 0.007
		env.fog_sun_scatter = 0.12
		env.fog_sky_affect = 0.0
		env.fog_aerial_perspective = 0.25
		env.glow_intensity = 0.9
		env.glow_bloom = 0.18
		env.glow_hdr_threshold = 0.95
		env.adjustment_saturation = 0.98
		env.adjustment_contrast = 1.15
		# 貼地的薄霧，燈光會在霧裡暈開（網頁版的繪圖模式不支援，會自動略過）
		env.volumetric_fog_enabled = true
		env.volumetric_fog_density = 0.008
		env.volumetric_fog_albedo = Color(0.45, 0.66, 0.82)
		env.volumetric_fog_emission = Color(0.02, 0.04, 0.07)
		env.volumetric_fog_anisotropy = 0.55
		env.volumetric_fog_length = 90.0
		env.volumetric_fog_ambient_inject = 0.4
		we.environment = env
	var sun := main.get_node_or_null("Sun") as DirectionalLight3D
	if sun:
		# 很低的夕陽，從場地後方斜斜照過來：影子拉長，東西的邊緣有一圈橘光
		sun.rotation = Vector3(-0.40, 2.05, 0.0)
		sun.light_color = Color(1.0, 0.66, 0.42)
		sun.light_energy = 1.7
		sun.light_volumetric_fog_energy = 0.22
	# 從鏡頭這一側補一盞很弱的冷色光，背光的角色才看得清楚
	var fill := DirectionalLight3D.new()
	fill.name = "FillLight"
	fill.rotation = Vector3(-0.75, -0.5, 0.0)
	fill.light_color = Color(0.55, 0.75, 1.0)
	fill.light_energy = 0.45
	fill.shadow_enabled = false
	fill.light_volumetric_fog_energy = 0.0
	_art.add_child(fill)
	# 場地正上方一盞很大的暖光，像舞台燈一樣把遊玩範圍打亮，外圍維持昏暗
	var c := (play_min + play_max) * 0.5
	var stage := OmniLight3D.new()
	stage.name = "StageLight"
	stage.position = Vector3(c.x, height_at(c.x, c.y) + 11.0, c.y)
	stage.light_color = Color(1.0, 0.84, 0.66)
	stage.light_energy = 2.2
	stage.omni_range = maxf(play_max.x - play_min.x, play_max.y - play_min.y) * 0.5 + 12.0
	stage.omni_attenuation = 0.8
	stage.shadow_enabled = false
	stage.light_volumetric_fog_energy = 0.0
	_art.add_child(stage)

# ---------------------------------------------------------------- 外圍的小鎮

var _house_spots: Array[Vector2] = []

## 這棟房子的窗戶顏色：大部分是暖黃，少數是粉紅、青色
func _house_glow() -> Color:
	return WARM if _ar.randf() < 0.72 else ACCENTS[_ar.randi() % ACCENTS.size()]

var _hg := WARM

func _near_house(x: float, z: float) -> bool:
	for h in _house_spots:
		if h.distance_to(Vector2(x, z)) < 3.4:
			return true
	return false

func _build_town() -> void:
	var c := (play_min + play_max) * 0.5
	# 沿著遊玩範圍外面繞一圈放房子。南邊（鏡頭那一側）放少一點、矮一點，才不會擋住視線
	var spots: Array = []
	var x := play_min.x + 1.5
	while x < play_max.x:
		spots.append([Vector2(x, play_min.y - _ar.randf_range(3.2, 6.0)), 1.0])
		x += _ar.randf_range(5.2, 7.5)
	var z := play_min.y + 1.0
	while z < play_max.y:
		spots.append([Vector2(play_min.x - _ar.randf_range(3.2, 5.5), z), 0.9])
		spots.append([Vector2(play_max.x + _ar.randf_range(3.2, 5.5), z + _ar.randf_range(-1.5, 1.5)), 0.9])
		z += _ar.randf_range(6.0, 8.5)
	# 後面再一排更高的，疊出層次
	x = play_min.x - 4.0
	while x < play_max.x + 4.0:
		spots.append([Vector2(x, play_min.y - _ar.randf_range(8.5, 11.0)), 1.45])
		x += _ar.randf_range(6.0, 8.0)
	_build_far_silhouettes(c)
	for s in spots:
		var p: Vector2 = s[0]
		var big: float = s[1]
		if Vector2(p.x - camera_start.x, p.y - camera_start.z).length() < 9.0:
			continue
		_house_spots.append(p)
		var pos := Vector3(p.x, height_at(p.x, p.y), p.y)
		var yaw := atan2(c.x - p.x, c.y - p.y) + _ar.randf_range(-0.35, 0.35)
		_hg = _house_glow()
		_kit_house(pos, yaw, big, _ar.randf() < 0.4)

## 用素材包的零件組一棟木框架房子：一樓石牆、樓上灰泥牆，每層比下面凸出一點、歪一點
##   tower = 三層樓、尖塔屋頂；否則兩層樓、斜屋頂
func _kit_house(pos: Vector3, yaw: float, big: float, tower: bool) -> void:
	var s := 0.70 * big
	var root := Node3D.new()
	root.position = pos - Vector3(0, 0.25, 0)
	root.rotation = Vector3(_ar.randf_range(-0.05, 0.05), yaw, _ar.randf_range(-0.10, 0.10))
	root.scale = Vector3(s, s * _ar.randf_range(1.0, 1.18), s)
	_art.add_child(root)
	var glass := _glow(_hg, 2.6)
	var length := 4.0 if (tower or _ar.randf() < 0.5) else 6.0
	var floors := 3 if tower else 2
	var top_scale := 1.0
	for f in floors:
		var fl := Node3D.new()
		top_scale = 1.0 + 0.09 * f
		fl.position = Vector3(0, f * 3.0, 0)
		fl.scale = Vector3(top_scale, 1.0, top_scale)
		fl.rotation = Vector3(0, _ar.randf_range(-0.06, 0.06) * f, _ar.randf_range(-0.03, 0.03) * f)
		root.add_child(fl)
		var kind := "UnevenBrick" if f == 0 else "Plaster"
		# 這一層每一片牆的位置和朝向（正面兩片、背面兩片、兩側各 length/2 片）
		var slots: Array = [[Vector3(-1, 0, length * 0.5), 0.0], [Vector3(1, 0, length * 0.5), 0.0], [Vector3(-1, 0, -length * 0.5), PI], [Vector3(1, 0, -length * 0.5), PI]]
		for k in int(length / 2.0):
			var z := -length * 0.5 + 1.0 + 2.0 * k
			slots.append([Vector3(2, 0, z), PI * 0.5])
			slots.append([Vector3(-2, 0, z), -PI * 0.5])
		for i in slots.size():
			var p: Vector3 = slots[i][0]
			var a: float = slots[i][1]
			var pick := _ar.randf()
			if f == 0 and i == 0:
				_kit(fl, Q + "Wall_%s_Door_Round.gltf" % kind, p, a)
				var door := _kit(fl, Q + "Door_1_Round.gltf", p, a)
				door.translate_object_local(Vector3(-0.53, 0, 0))
				_light_glass(door, glass)
			elif pick < 0.52:
				_kit(fl, Q + "Wall_%s_Window_Wide_Round.gltf" % kind, p, a)
				_light_glass(_kit(fl, Q + "Window_Wide_Round1.gltf", p, a), glass)
				if _ar.randf() < 0.5:
					_kit(fl, Q + "WindowShutters_Wide_Round_Open.gltf", p, a)
			elif pick < 0.70 and f > 0:
				_kit(fl, Q + "Wall_Plaster_Window_Wide_Flat.gltf", p, a)
				_light_glass(_kit(fl, Q + "Window_Wide_Flat1.gltf", p, a), glass)
				if _ar.randf() < 0.5:
					_kit(fl, Q + "WindowShutters_Wide_Flat_Open.gltf", p, a)
			elif pick < 0.86 and f > 0:
				_kit(fl, Q + "Wall_Plaster_WoodGrid.gltf", p, a)
			else:
				_kit(fl, Q + "Wall_%s_Straight.gltf" % kind, p, a)
		for sx in [-2.0, 2.0]:
			for sz in [-0.5, 0.5]:
				_kit(fl, Q + "Corner_Exterior_Wood.gltf", Vector3(sx, 0, sz * length))
		if f > 0 and _ar.randf() < 0.5:
			_kit(fl, Q + ("Prop_Vine1.gltf" if _ar.randf() < 0.5 else "Prop_Vine2.gltf"), Vector3(1.0 if _ar.randf() < 0.5 else -1.0, 2.9, length * 0.5 + 0.10))
	# 屋頂（再歪一點）
	var rf := Node3D.new()
	rf.position = Vector3(0, floors * 3.0, 0)
	rf.scale = Vector3(top_scale, 1.0, top_scale)
	rf.rotation = Vector3(0, 0, _ar.randf_range(-0.07, 0.07))
	root.add_child(rf)
	var tile: Color = TILE_TINTS[_ar.randi() % TILE_TINTS.size()]
	if tower:
		_kit(rf, Q + "Roof_Tower_RoundTiles.gltf")
	else:
		_kit(rf, Q + ("Roof_RoundTiles_4x4.gltf" if length < 5.0 else "Roof_RoundTiles_4x6.gltf"))
		_kit(rf, Q + "Roof_Front_Brick4.gltf", Vector3(0, 0, length * 0.5), 0.0)
		_kit(rf, Q + "Roof_Front_Brick4.gltf", Vector3(0, 0, -length * 0.5), PI)
		var cx := 1.25 if _ar.randf() < 0.5 else -1.25
		_kit(rf, Q + ("Prop_Chimney.gltf" if _ar.randf() < 0.5 else "Prop_Chimney2.gltf"), Vector3(cx, 0.3, -length * 0.2))
		if _ar.randf() < 0.7:
			_smoke(rf, Vector3(cx, 3.7, -length * 0.2), 1.0, false)
	_tint(rf, "RoundTiles", tile)
	# 門口：招牌、南瓜、暖光
	_sign(root, 0.42, 2.7, length * 0.5)
	if _ar.randf() < 0.6:
		var pk: String = ["pumpkin_orange_jackolantern", "pumpkin_yellow_jackolantern", "pumpkin_orange"][_ar.randi() % 3]
		_kit(root, KK + pk + ".gltf", Vector3(0.7, 0.0, length * 0.5 + 0.9), _ar.randf_range(-0.6, 0.6), 0.8)
	if _ar.randf() < 0.6:
		_lamp_light(root, Vector3(-1.0, 1.4, length * 0.5 + 1.6), _hg, 1.6, 6.0)

## 遊玩範圍外面的市集小物：攤位、推車、馬車、長椅、火盆、南瓜、掛燈籠的柱子
func _build_kit_decor() -> void:
	var c := (play_min + play_max) * 0.5
	var size := play_max - play_min
	var items: Array = [
		[KT + "stall-red.glb", Vector2(play_min.x - 2.3, play_min.y + size.y * 0.30), 2.3],
		[KT + "stall-green.glb", Vector2(play_min.x - 2.3, play_min.y + size.y * 0.72), 2.3],
		[KT + "stall-red.glb", Vector2(play_max.x + 2.3, play_min.y + size.y * 0.28), 2.3],
		[KT + "cart.glb", Vector2(play_max.x + 2.0, play_min.y + size.y * 0.70), 2.2],
		[Q + "Prop_Wagon.gltf", Vector2(play_max.x - 3.0, play_min.y - 2.2), 0.8],
		[KK + "bench_decorated.gltf", Vector2(c.x - 5.0, play_min.y - 1.7), 0.9],
		[KK + "post_lantern.gltf", Vector2(c.x + 5.5, play_min.y - 1.5), 1.0],
		[KK + "post_lantern.gltf", Vector2(play_min.x - 1.4, c.y - 6.5), 1.0],
		[KK + "post_lantern.gltf", Vector2(play_max.x + 1.4, c.y + 0.5), 1.0],
	]
	for it in items:
		var p: Vector2 = it[1]
		if Vector2(p.x - camera_start.x, p.y - camera_start.z).length() < 6.0:
			continue
		var path: String = it[0]
		var yaw := atan2(c.x - p.x, c.y - p.y) + _ar.randf_range(-0.2, 0.2)
		if path.contains("Wagon") or path.contains("cart"):
			yaw += 1.3
		var g := Vector3(p.x, height_at(p.x, p.y), p.y)
		var n := _kit(_art, path, g - Vector3(0, 0.03, 0), yaw, float(it[2]))
		_house_spots.append(p)
		if path.contains("post_lantern"):
			# 燈籠在柱子前面吊著：補一個發光的芯和一點光
			var lp := n.to_global(Vector3(0, 1.95, 1.0))
			_box(_art, Vector3(0.16, 0.20, 0.16), lp, _glow(WARM, 3.6))
			_lamp_light(_art, lp, WARM, 1.4, 5.5)
	# 火盆：兩個，放在後方
	for sx in [-1.0, 1.0]:
		var p := Vector2(c.x + sx * 3.5, play_min.y - 1.2)
		var g := Vector3(p.x, height_at(p.x, p.y), p.y)
		_kit(_art, KG + "fire-basket.glb", g, 0.0, 3.0)
		_box(_art, Vector3(0.5, 0.35, 0.5), g + Vector3(0, 0.55, 0), _glow(Color(1.0, 0.45, 0.15), 4.0), Vector3(0.3, 0.6, 0.2))
		_lamp_light(_art, g + Vector3(0, 1.1, 0), Color(1.0, 0.50, 0.20), 2.2, 7.0)
	# 外圈散落的南瓜
	for k in 9:
		var ang := _ar.randf() * TAU
		var p := c + Vector2(cos(ang) * (size.x * 0.5 + _ar.randf_range(0.9, 1.8)), sin(ang) * (size.y * 0.5 + _ar.randf_range(0.9, 1.8)))
		if Vector2(p.x - camera_start.x, p.y - camera_start.z).length() < 5.0:
			continue
		var pk: String = ["pumpkin_orange", "pumpkin_orange_small", "pumpkin_yellow_jackolantern", "pumpkin_orange_jackolantern"][_ar.randi() % 4]
		_kit(_art, KK + pk + ".gltf", Vector3(p.x, height_at(p.x, p.y) - 0.03, p.y), _ar.randf() * TAU, _ar.randf_range(0.6, 0.9))

## 更遠的地方再疊一圈很高的塔樓，只剩深藍色的剪影和幾扇亮著的窗
func _build_far_silhouettes(c: Vector2) -> void:
	var half := (play_max - play_min) * 0.5
	var n := 11
	for i in n:
		# 只繞北半圈（鏡頭在南邊，南邊不放）
		var ang := lerpf(-1.75, 1.75, (float(i) + _ar.randf_range(-0.3, 0.3)) / float(n - 1))
		var dist := maxf(half.x, half.y) + forest_band + _ar.randf_range(9.0, 24.0)
		var p := c + Vector2(sin(ang), -cos(ang)) * dist
		_hg = _house_glow()
		_tower(Vector3(p.x, height_at(p.x, p.y) - 1.0, p.y), atan2(c.x - p.x, c.y - p.y), _ar.randf_range(2.4, 3.8), true)

## 圓圓歪歪的塔樓：每一層上寬下窄，戴一頂歪掉的尖帽子。far = 遠景剪影（省略細節）
func _tower(pos: Vector3, yaw: float, big: float, far := false) -> void:
	var root := Node3D.new()
	root.position = pos
	root.rotation = Vector3(_ar.randf_range(-0.06, 0.06), yaw, _ar.randf_range(-0.11, 0.11))
	_art.add_child(root)
	var wall := _paint(WALL_COLORS[_ar.randi() % WALL_COLORS.size()], 1.0)
	var beam := _paint(WOOD_DARK)
	var roof := _paint(ROOF_COLORS[_ar.randi() % ROOF_COLORS.size()], 0.0, 0.5, 2.4 / big)
	if far:
		wall = _paint(FAR_WALL, 0.0, 0.0)
		beam = wall
		roof = _paint(FAR_ROOF, 0.0, 0.0)
	var y := -0.6
	var rad := _ar.randf_range(1.25, 1.75) * big
	var top := rad
	var floors := _ar.randi_range(2, 3) + (1 if far else 0)
	for f in floors:
		var h := _ar.randf_range(2.1, 3.0) * big
		top = rad * _ar.randf_range(1.08, 1.30)
		_cyl(root, rad, top, h, 9, wall, Vector3(0, y + h * 0.5, 0))
		_cyl(root, top * 1.07, top * 1.10, 0.20 * big, 9, beam, Vector3(0, y + h, 0))
		var wr := lerpf(rad, top, 0.58)
		if far:
			for k in _ar.randi_range(1, 2):
				_round_window(root, y + h * _ar.randf_range(0.35, 0.75), wr, _ar.randf_range(-0.7, 0.7), 0.13 * big, false)
		else:
			# 一根一根直的木樑，跟著牆面往外斜
			var tilt := atan2(top - rad, h)
			for a in [0.62, -0.62, 1.70, -1.70, 2.70, -2.70]:
				var pv := Node3D.new()
				pv.position = Vector3(0, y + h * 0.5, 0)
				pv.rotation.y = a
				root.add_child(pv)
				_box(pv, Vector3(0.13 * big, h / cos(tilt), 0.10 * big), Vector3(0, 0, (rad + top) * 0.5 * 0.955), beam, Vector3(tilt, 0, 0))
			# 窗戶：正面一定有，側面隨機
			_round_window(root, y + h * 0.58, wr, 0.0, _ar.randf_range(0.30, 0.44) * big)
			if _ar.randf() < 0.55:
				_round_window(root, y + h * 0.50, wr, 1.16 * (1.0 if _ar.randf() < 0.5 else -1.0), 0.28 * big)
			# 牆上補過的木板
			if _ar.randf() < 0.6:
				var pp := Node3D.new()
				pp.position = Vector3(0, y + h * _ar.randf_range(0.25, 0.8), 0)
				pp.rotation = Vector3(0, _ar.randf_range(-0.45, 0.45) + (2.2 if _ar.randf() < 0.5 else -2.2), 0)
				root.add_child(pp)
				_box(pp, Vector3(0.7 * big, 0.5 * big, 0.06), Vector3(0, 0, wr * 0.95), _paint(CRATE.darkened(0.15), 2.5), Vector3(0, 0, _ar.randf_range(-0.2, 0.2)))
		y += h
		rad = top * _ar.randf_range(0.70, 0.84)
	# 帽簷 + 尖頂 + 歪掉的尖，尖端掛一顆小燈
	var rh := _ar.randf_range(2.0, 2.8) * big
	_cyl(root, top * 1.55, top * 1.30, 0.22 * big, 9, roof, Vector3(0, y + 0.10 * big, 0))
	_cyl(root, top * 1.28, top * 0.32, rh, 9, roof, Vector3(0, y + 0.2 * big + rh * 0.5, 0))
	var tip := Node3D.new()
	tip.position = Vector3(0, y + 0.2 * big + rh * 0.96, 0)
	tip.rotation = Vector3(_ar.randf_range(-0.3, 0.3), 0, _ar.randf_range(0.45, 0.85) * (1.0 if _ar.randf() < 0.5 else -1.0))
	root.add_child(tip)
	var th := rh * 0.62
	_cyl(tip, top * 0.33, 0.03, th, 7, roof, Vector3(0, th * 0.5, 0))
	if far:
		return
	_box(tip, Vector3.ONE * 0.20 * big, Vector3(0, th + 0.06, 0), _glow(_hg, 3.4), Vector3(0.6, 0.6, 0))
	# 門：門框、發光的門、雨棚、門階
	var wd := _wall_dist(root)
	_box(root, Vector3(0.98 * big, 1.58 * big, 0.14), Vector3(0, 0.22 + 0.72 * big, wd - 0.03), beam)
	_box(root, Vector3(0.75 * big, 1.35 * big, 0.10), Vector3(0, 0.25 + 0.65 * big, wd + 0.04), _glow(_hg, 2.2))
	_box(root, Vector3(1.35 * big, 0.08, 0.80 * big), Vector3(0, 0.30 + 1.52 * big, wd + 0.30 * big), roof, Vector3(0.42, 0, 0))
	_box(root, Vector3(1.20 * big, 0.20, 0.70), Vector3(0, 0.02, wd + 0.30), _paint(STONE))
	_sign(root, 0.80 * (1.0 if _ar.randf() < 0.5 else -1.0), 0.3 + 2.0 * big, wd)
	if _ar.randf() < 0.6:
		_smoke(root, Vector3(top * 0.55, y + rh * 0.55, -top * 0.3), big)

## 塔樓最底層正面的牆大概在多遠（門要貼在上面）
func _wall_dist(root: Node3D) -> float:
	var first := root.get_child(0) as MeshInstance3D
	var cm := first.mesh as CylinderMesh
	return lerpf(cm.bottom_radius, cm.top_radius, 0.3) * 0.94

## 圓窗：發光的玻璃 + 深色窗框 + 十字窗格。angle 是繞著塔轉多少（0 = 正面）
func _round_window(root: Node3D, y: float, dist: float, angle: float, r: float, framed := true) -> void:
	var pivot := Node3D.new()
	pivot.position = Vector3(0, y, 0)
	pivot.rotation.y = angle
	root.add_child(pivot)
	var zf := dist * 0.93
	var face := Vector3(PI * 0.5, 0, 0)
	_cyl(pivot, r, r, 0.20, 14, _glow(_hg, 3.2 if framed else 1.5), Vector3(0, 0, zf + 0.01), face)
	if not framed:
		return
	var frame := _paint(WOOD_DARK)
	_cyl(pivot, r * 1.22, r * 1.22, 0.16, 14, frame, Vector3(0, 0, zf), face)
	_box(pivot, Vector3(r * 2.1, 0.06, 0.05), Vector3(0, 0, zf + 0.12), frame)
	_box(pivot, Vector3(0.06, r * 2.1, 0.05), Vector3(0, 0, zf + 0.12), frame)
	# 窗台
	_box(pivot, Vector3(r * 2.3, 0.07, 0.22), Vector3(0, -r * 1.2, zf + 0.10), frame)

## 掛在牆外的小招牌：一支橫桿吊著木牌，牌子中間有個發光的記號
func _sign(root: Node3D, angle: float, y: float, dist: float) -> void:
	var pv := Node3D.new()
	pv.position = Vector3(0, y, 0)
	pv.rotation.y = angle
	root.add_child(pv)
	var dark := _paint(WOOD_DARK)
	_box(pv, Vector3(0.07, 0.07, 1.0), Vector3(0, 0, dist + 0.42), dark)
	for dz in [0.50, 0.86]:
		_box(pv, Vector3(0.025, 0.20, 0.025), Vector3(0, -0.12, dist + dz), dark)
	_box(pv, Vector3(0.06, 0.46, 0.62), Vector3(0, -0.44, dist + 0.68), _paint(CRATE, 0.0, 0.8), Vector3(_ar.randf_range(-0.10, 0.10), 0, 0))
	_box(pv, Vector3(0.09, 0.20, 0.20), Vector3(0, -0.44, dist + 0.68), _glow(_hg, 2.6), Vector3(PI * 0.25, 0, 0))

var _smoke_mesh: SphereMesh

## 煙囪冒的煙（純裝飾）
func _smoke(root: Node3D, at: Vector3, big: float, with_box := true) -> void:
	if _smoke_mesh == null:
		_smoke_mesh = SphereMesh.new()
		_smoke_mesh.radius = 0.28
		_smoke_mesh.height = 0.56
		_smoke_mesh.radial_segments = 7
		_smoke_mesh.rings = 4
		var sm := StandardMaterial3D.new()
		sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		sm.vertex_color_use_as_albedo = true
		sm.albedo_color = Color(0.36, 0.33, 0.46, 0.55)
		_smoke_mesh.material = sm
	if with_box:
		_box(root, Vector3(0.36 * big, 1.3 * big, 0.36 * big), at, _paint(Color(0.23, 0.19, 0.22)), Vector3(0.0, 0.0, 0.12))
		_box(root, Vector3(0.48 * big, 0.12 * big, 0.48 * big), at + Vector3(-0.08 * big, 0.66 * big, 0), _paint(WOOD_DARK), Vector3(0.0, 0.0, 0.12))
	var ps := CPUParticles3D.new()
	ps.position = at + Vector3(-0.08 * big, 0.8 * big, 0)
	ps.amount = 9
	ps.lifetime = 5.0
	ps.preprocess = 5.0
	ps.mesh = _smoke_mesh
	ps.direction = Vector3(0, 1, 0)
	ps.spread = 12.0
	ps.gravity = Vector3(0.10, 0.05, 0.04)
	ps.initial_velocity_min = 0.45
	ps.initial_velocity_max = 0.75
	ps.scale_amount_min = 0.7 * big
	ps.scale_amount_max = 1.2 * big
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.35))
	grow.add_point(Vector2(1.0, 1.6))
	ps.scale_amount_curve = grow
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0.0))
	fade.add_point(0.15, Color(1, 1, 1, 1.0))
	fade.set_color(fade.get_point_count() - 1, Color(1, 1, 1, 0.0))
	ps.color_ramp = fade
	ps.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(ps)

## 方方的歪木屋：木板牆、尖屋頂、發光的門和方窗、歪煙囪
func _shack(pos: Vector3, yaw: float, big: float) -> void:
	var root := Node3D.new()
	root.position = pos
	root.rotation = Vector3(_ar.randf_range(-0.05, 0.05), yaw, _ar.randf_range(-0.13, 0.13))
	_art.add_child(root)
	var wall := _paint(WALL_COLORS[_ar.randi() % WALL_COLORS.size()], 1.1)
	var beam := _paint(WOOD_DARK)
	var roof_col: Color = ROOF_COLORS[_ar.randi() % ROOF_COLORS.size()]
	var roof := _paint(roof_col, 0.0, 0.5, 2.4 / big)
	var w := _ar.randf_range(2.6, 3.6) * big
	var d := _ar.randf_range(2.4, 3.2) * big
	var h := _ar.randf_range(2.6, 3.8) * big
	_box(root, Vector3(w, h, d), Vector3(0, h * 0.5 - 0.5, 0), wall)
	# 二樓比一樓凸出來一點
	var h2 := _ar.randf_range(1.6, 2.4) * big
	_box(root, Vector3(w * 1.14, h2, d * 1.14), Vector3(0, h - 0.5 + h2 * 0.5, 0), wall)
	_box(root, Vector3(w * 1.20, 0.18, d * 1.20), Vector3(0, h - 0.5, 0), beam)
	# 四個角的木柱、二樓的木樑和斜撐
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_box(root, Vector3(0.16, h, 0.16), Vector3(sx * w * 0.5, h * 0.5 - 0.5, sz * d * 0.5), beam)
			_box(root, Vector3(0.14, h2, 0.14), Vector3(sx * w * 0.57, h - 0.5 + h2 * 0.5, sz * d * 0.57), beam)
		# 一樓凸出的二樓下面的斜撐
		_box(root, Vector3(0.10, 0.9 * big, 0.10), Vector3(sx * w * 0.53, h - 0.5 - 0.36 * big, d * 0.5 + 0.02), beam, Vector3(0, 0, sx * -0.55))
	var zf := d * 0.5 + 0.03
	# 一樓正面的 X 形木樑
	var bx := w * 0.22
	var by := h * 0.45 - 0.5
	var bl := minf(w * 0.42, h * 0.7)
	for s in [-1.0, 1.0]:
		_box(root, Vector3(0.09, bl, 0.06), Vector3(bx, by, zf), beam, Vector3(0, 0, s * 0.75))
	var ytop := h - 0.5 + h2
	var rh := _ar.randf_range(2.0, 3.0) * big
	_cyl(root, w * 0.95, 0.06, rh, 4, roof, Vector3(0, ytop + rh * 0.5, 0), Vector3(0, PI * 0.25, 0))
	_box(root, Vector3(w * 1.32, 0.14, d * 1.32), Vector3(0, ytop + 0.04, 0), roof)
	if _ar.randf() < 0.75:
		_smoke(root, Vector3(w * 0.22, ytop + rh * 0.50, -d * 0.1), big)
	# 門：門框、發光的門、雨棚、門階
	_box(root, Vector3(0.95 * big, 1.6 * big, 0.10), Vector3(-w * 0.18, 0.8 * big - 0.3, zf), beam)
	_box(root, Vector3(0.72 * big, 1.38 * big, 0.10), Vector3(-w * 0.18, 0.74 * big - 0.3, zf + 0.03), _glow(_hg, 2.2))
	_box(root, Vector3(1.30 * big, 0.08, 0.80 * big), Vector3(-w * 0.18, 1.68 * big - 0.3, zf + 0.32 * big), roof, Vector3(0.42, 0, 0))
	_box(root, Vector3(1.15 * big, 0.20, 0.70), Vector3(-w * 0.18, 0.0, zf + 0.30), _paint(STONE))
	# 二樓的方窗：窗框、窗格、窗台、兩邊的百葉板
	var zf2 := d * 0.57 + 0.03
	var wy := h - 0.5 + h2 * 0.5
	var shutter := _paint(roof_col.lightened(0.08), 3.0)
	for sx in [-0.26, 0.26]:
		_box(root, Vector3(0.78 * big, 0.88 * big, 0.10), Vector3(sx * w, wy, zf2), beam)
		_box(root, Vector3(0.62 * big, 0.72 * big, 0.10), Vector3(sx * w, wy, zf2 + 0.03), _glow(_hg, 3.0))
		_box(root, Vector3(0.05, 0.74 * big, 0.05), Vector3(sx * w, wy, zf2 + 0.09), beam)
		_box(root, Vector3(0.64 * big, 0.05, 0.05), Vector3(sx * w, wy, zf2 + 0.09), beam)
		_box(root, Vector3(0.92 * big, 0.07, 0.24), Vector3(sx * w, wy - 0.47 * big, zf2 + 0.10), beam)
		for side in [-1.0, 1.0]:
			_box(root, Vector3(0.26 * big, 0.80 * big, 0.05), Vector3(sx * w + side * 0.56 * big, wy, zf2 + 0.04), shutter, Vector3(0, side * -0.35, _ar.randf_range(-0.06, 0.06)))
	# 掛在牆角的招牌
	var sp := Node3D.new()
	sp.position = Vector3(w * 0.5, 0, d * 0.5)
	root.add_child(sp)
	_sign(sp, 0.0, 0.3 + 1.9 * big, 0.0)
	_lamp_light(root, Vector3(-w * 0.18, 1.0, zf + 1.2), _hg, 1.6, 6.0)

# ---------------------------------------------------------------- 枯樹

func _twisted_tree(base: Vector3, r: RandomNumberGenerator, s: float, force_leafy := false) -> void:
	var p := base - Vector3(0, 0.4, 0)
	var dir := Vector3(r.randf_range(-0.18, 0.18), 1.0, r.randf_range(-0.18, 0.18)).normalized()
	var curl := Vector3(r.randf_range(-1.0, 1.0), 0.0, r.randf_range(-1.0, 1.0)).normalized()
	var rad := r.randf_range(0.24, 0.36) * s
	var n := r.randi_range(4, 6)
	var leafy := r.randf() < 0.6 or force_leafy
	var leaf_col := _leaf_color(r)
	for i in n:
		var length := r.randf_range(1.0, 1.5) * s
		_seg(p, dir, length * 1.08, rad)
		p += dir * length
		# 越往上越彎，最後捲起來
		dir = (dir + curl * r.randf_range(0.18, 0.50) + Vector3(0, -0.04 * i, 0)).normalized()
		if i >= 1 and r.randf() < 0.75:
			_branch(p, dir, curl, rad * 0.62, s, r, leafy, leaf_col)
		rad *= 0.74
	_seg(p, (dir + curl * 0.8 - Vector3(0, 0.5, 0)).normalized(), 0.7 * s, rad)
	if leafy:
		_leaf_tuft(p, s * 0.9, r, leaf_col)

func _branch(p: Vector3, trunk_dir: Vector3, curl: Vector3, rad: float, s: float, r: RandomNumberGenerator, leafy: bool, col: Color) -> void:
	var out := Vector3(r.randf_range(-1.0, 1.0), r.randf_range(0.2, 0.7), r.randf_range(-1.0, 1.0)).normalized()
	var dir := (out + trunk_dir * 0.3).normalized()
	var q := p
	for i in r.randi_range(2, 3):
		var length := r.randf_range(0.6, 1.0) * s
		_seg(q, dir, length * 1.08, rad)
		q += dir * length
		dir = (dir + Vector3(0, 0.45, 0) + curl * 0.2).normalized()
		rad *= 0.68
	if leafy and r.randf() < 0.7:
		_leaf_tuft(q, s * 0.7, r, col)

func _leaf_color(r: RandomNumberGenerator) -> Color:
	var pick := r.randf()
	if pick < 0.50:
		return Color(0.09, 0.19, 0.20)      # 深藍綠
	if pick < 0.78:
		return Color(0.18, 0.12, 0.24)      # 紫
	return Color(0.42, 0.17, 0.09)          # 鏽紅

func _leaf_tuft(p: Vector3, s: float, r: RandomNumberGenerator, col: Color) -> void:
	for k in r.randi_range(2, 3):
		var cr := r.randf_range(0.55, 0.95) * s
		var b := Basis(Vector3.UP, r.randf() * TAU).scaled(Vector3(cr, cr * 0.7, cr))
		_leaves.append(Transform3D(b, p + Vector3(r.randf_range(-0.5, 0.5), r.randf_range(-0.1, 0.4), r.randf_range(-0.5, 0.5)) * s))
		_leaf_cols.append(col.lightened(r.randf_range(0.0, 0.12)))

# ---------------------------------------------------------------- 燈串、三角旗、路燈

func _build_lights_and_flags() -> void:
	# 遊玩範圍外面一圈歪歪的燈柱
	var m := 1.6
	var a := play_min - Vector2(m, m)
	var b := play_max + Vector2(m, m)
	var mid_z := (a.y + b.y) * 0.5
	var posts: Array[Vector2] = [
		Vector2(a.x, a.y), Vector2((a.x + b.x) * 0.5, a.y - 0.8), Vector2(b.x, a.y),
		Vector2(b.x + 0.6, mid_z), Vector2(b.x, b.y), Vector2(a.x, b.y), Vector2(a.x - 0.6, mid_z),
	]
	var tops: Array[Vector3] = []
	for i in posts.size():
		var p := posts[i]
		var near_cam := Vector2(p.x - camera_start.x, p.y - camera_start.z).length() < 7.0
		tops.append(_lamp_post(Vector3(p.x, height_at(p.x, p.y), p.y), _ar.randf_range(4.6, 5.4), not near_cam))
	# 柱子之間拉燈串（沿著外圈）
	for i in tops.size():
		_string_lights(tops[i], tops[(i + 1) % tops.size()], _ar.randf_range(0.7, 1.2))
	# 後半場上空橫著兩條三角旗，再斜拉一條燈串
	_bunting(tops[0] + Vector3(0, -0.5, 0), tops[2] + Vector3(0, -0.5, 0), 1.3)
	_bunting(tops[6] + Vector3(0, -0.3, 0), tops[1] + Vector3(0, -0.6, 0), 1.0)
	_string_lights(tops[1], tops[3], 1.6)

## 燈柱：兩段歪歪的木桿 + 掛著的燈籠。回傳柱頂位置（燈串綁在這裡）
func _lamp_post(base: Vector3, h: float, lantern: bool) -> Vector3:
	var lean := Vector3(_ar.randf_range(-0.10, 0.10), 1.0, _ar.randf_range(-0.10, 0.10)).normalized()
	var p := base - Vector3(0, 0.3, 0)
	_seg(p, lean, h * 0.6, 0.11)
	p += lean * h * 0.58
	var lean2 := (lean + Vector3(_ar.randf_range(-0.16, 0.16), 0, _ar.randf_range(-0.16, 0.16))).normalized()
	_seg(p, lean2, h * 0.45, 0.085)
	var top := p + lean2 * h * 0.44
	if lantern:
		# 往場內伸出去的一支橫桿，下面吊燈籠
		var c := (play_min + play_max) * 0.5
		var inward := Vector3(c.x - base.x, 0, c.y - base.z).normalized()
		var arm_from := p + lean2 * h * 0.12
		_seg(arm_from, (inward + Vector3(0, 0.25, 0)).normalized(), 0.9, 0.05)
		var lp := arm_from + inward * 0.85 + Vector3(0, -0.25, 0)
		var lan := Node3D.new()
		lan.position = lp
		lan.rotation = Vector3(0, _ar.randf() * TAU, _ar.randf_range(-0.12, 0.12))
		_art.add_child(lan)
		_box(lan, Vector3(0.30, 0.40, 0.30), Vector3.ZERO, _glow(WARM, 4.0))
		_cyl(lan, 0.30, 0.04, 0.22, 4, _paint(WOOD_DARK), Vector3(0, 0.31, 0), Vector3(0, PI * 0.25, 0))
		_box(lan, Vector3(0.36, 0.05, 0.36), Vector3(0, -0.22, 0), _paint(WOOD_DARK))
		_lamp_light(_art, lp + Vector3(0, -0.2, 0), WARM, 2.6, 8.5)
	return top

## 下垂的線上面的一個點（t = 0~1）
func _hang(a: Vector3, b: Vector3, sag: float, t: float) -> Vector3:
	return a.lerp(b, t) - Vector3(0, sag * 4.0 * t * (1.0 - t), 0)

func _wire(a: Vector3, b: Vector3, sag: float) -> void:
	var n := maxi(int(a.distance_to(b) / 0.9), 4)
	for i in n:
		var p0 := _hang(a, b, sag, float(i) / n)
		var p1 := _hang(a, b, sag, float(i + 1) / n)
		_seg(p0, p1 - p0, p0.distance_to(p1) * 1.02, 0.014)

func _string_lights(a: Vector3, b: Vector3, sag: float) -> void:
	_wire(a, b, sag)
	var n := maxi(int(a.distance_to(b) / 0.75), 3)
	for i in range(1, n):
		var p := _hang(a, b, sag, float(i) / n) - Vector3(0, 0.07, 0)
		var s := _ar.randf_range(0.07, 0.10)
		_bulbs.append(Transform3D(Basis().scaled(Vector3.ONE * s), p))
		_bulb_cols.append(BULB_COLORS[_ar.randi() % BULB_COLORS.size()] if _ar.randf() < 0.55 else BULB_COLORS[0])

func _bunting(a: Vector3, b: Vector3, sag: float) -> void:
	_wire(a, b, sag)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var along := (b - a)
	along.y = 0.0
	along = along.normalized()
	var nrm := Vector3(0.0, 0.35, 0.0) + along.cross(Vector3.UP) * 0.2
	var n := maxi(int(a.distance_to(b) / 0.85), 3)
	for i in n:
		var t := (float(i) + 0.5) / n
		var p := _hang(a, b, sag, t)
		var half := 0.30
		var drop := _ar.randf_range(0.60, 0.80)
		var sway := along.cross(Vector3.UP) * _ar.randf_range(-0.12, 0.12)
		var v0 := p - along * half
		var v1 := p + along * half
		var v2 := p - Vector3(0, drop, 0) + sway
		var col: Color = FLAG_COLORS[i % FLAG_COLORS.size()]
		# 正反兩面都畫
		for tri in [[v0, v1, v2], [v1, v0, v2]]:
			for v in tri:
				st.set_color(col)
				st.set_normal((nrm + Vector3.UP).normalized())
				st.add_vertex(v)
	var mi := MeshInstance3D.new()
	mi.name = "Bunting"
	mi.mesh = st.commit()
	mi.material_override = _paint(Color(1, 1, 1), 0.0, 0.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_art.add_child(mi)

## 圍欄柱子上放幾盞小燈（純裝飾，不擋路）
func _build_fence_lanterns() -> void:
	for seg in fence_segments:
		var a: Vector2 = seg[0]
		var b: Vector2 = seg[1]
		for t in [0.0, 1.0]:
			var p := a.lerp(b, t)
			var y := height_at(p.x, p.y)
			var lan := Node3D.new()
			lan.position = Vector3(p.x, y + 1.28, p.y)
			_art.add_child(lan)
			_box(lan, Vector3(0.20, 0.26, 0.20), Vector3.ZERO, _glow(WARM, 3.6))
			_cyl(lan, 0.20, 0.03, 0.14, 4, _paint(WOOD_DARK), Vector3(0, 0.20, 0), Vector3(0, PI * 0.25, 0))
			_lamp_light(_art, Vector3(p.x, y + 1.5, p.y), WARM, 1.5, 5.0)

# ---------------------------------------------------------------- 空氣裡的光點、畫面暗角

func _build_dust() -> void:
	var size := play_max - play_min
	var c := (play_min + play_max) * 0.5
	var ps := CPUParticles3D.new()
	ps.name = "Dust"
	ps.amount = 110
	ps.lifetime = 9.0
	ps.preprocess = 9.0
	ps.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	ps.emission_box_extents = Vector3(size.x * 0.5 + 5.0, 3.0, size.y * 0.5 + 5.0)
	ps.position = Vector3(c.x, height_at(c.x, c.y) + 3.2, c.y)
	ps.direction = Vector3(1, 0.3, 0)
	ps.spread = 180.0
	ps.gravity = Vector3(0, 0.02, 0)
	ps.initial_velocity_min = 0.05
	ps.initial_velocity_max = 0.22
	ps.scale_amount_min = 0.5
	ps.scale_amount_max = 1.3
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.0))
	curve.add_point(Vector2(0.25, 1.0))
	curve.add_point(Vector2(0.75, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	ps.scale_amount_curve = curve
	var qm := QuadMesh.new()
	qm.size = Vector2(0.07, 0.07)
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))
	var dot := GradientTexture2D.new()
	dot.gradient = grad
	dot.fill = GradientTexture2D.FILL_RADIAL
	dot.fill_from = Vector2(0.5, 0.5)
	dot.fill_to = Vector2(1.0, 0.5)
	dot.width = 32
	dot.height = 32
	var dm := StandardMaterial3D.new()
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	dm.albedo_color = Color(2.2, 1.8, 1.2, 0.9)
	dm.albedo_texture = dot
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	qm.material = dm
	ps.mesh = qm
	ps.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_art.add_child(ps)

func _build_vignette() -> void:
	var layer := CanvasLayer.new()
	layer.name = "Vignette"
	layer.layer = 0          # 在 HUD 下面，不會蓋到介面文字
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = VIGNETTE_SHADER
	rect.material = m
	layer.add_child(rect)
	add_child(layer)

# ---------------------------------------------------------------- 把累積的東西一次畫出來

func _flush_multimeshes() -> void:
	var cm := CylinderMesh.new()
	cm.top_radius = 0.74
	cm.bottom_radius = 1.0
	cm.height = 1.0
	cm.radial_segments = 6
	cm.rings = 1
	_add_multimesh("Branches", cm, _segs, [], _paint(TRUNK, 0.0, 0.9), true)
	var blob_rng := RandomNumberGenerator.new()
	blob_rng.seed = world_seed + 32
	_add_multimesh("Leaves", make_rock_mesh(blob_rng, 0, 0.25, false), _leaves, _leaf_cols, _paint(Color(1, 1, 1), 0.0, 0.7), true)
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.radial_segments = 8
	sm.rings = 4
	_add_multimesh("Bulbs", sm, _bulbs, _bulb_cols, _glow(Color(1, 1, 1), 3.4), false)

func _add_multimesh(node_name: String, mesh: Mesh, xforms: Array[Transform3D], cols: Array, mat: Material, shadows: bool) -> void:
	if xforms.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = not cols.is_empty()
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
		if mm.use_colors:
			mm.set_instance_color(i, cols[i])
	var mi := MultiMeshInstance3D.new()
	mi.name = node_name
	mi.multimesh = mm
	mi.material_override = mat
	if not shadows:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
