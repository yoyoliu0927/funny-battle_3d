extends Node3D
## 第一關場地：程序化生成山坡地形、岩壁、草叢、遠景岩壁層。
##
## 版面配置（俯視，-Z 為「往山上」）：
##   坡腳空地   z ≈ +12 ~ +36，高度 0
##   砂土坡道   z ≈ +12 → -38，高度 0 → 18
##   坡頂平台   z ≈ -38 ~ -52，高度 18
##   岩壁       沿坡道左側（-X）一路錯落堆疊
##   遠景       三圈岩壁輪廓，距離 160 / 240 / 340 m，靠霧做出深度

const TERRAIN_SIZE := 240.0
const TERRAIN_RES := 200          # 每邊格數
const SLOPE_BOTTOM_Z := 12.0
const SLOPE_TOP_Z := -38.0
const SLOPE_HEIGHT := 18.0

const TEX := "res://assets/textures/"
const LAYOUT_SCALE := 0.5      # 小型世界：佈局整體縮成一半

var _layout: Node3D

@export var world_seed := 20261109
@export var player_path: NodePath = ^"../Player"

var _noise := FastNoiseLite.new()
var _detail := FastNoiseLite.new()
var _rng := RandomNumberGenerator.new()
var _heights := PackedFloat32Array()
var _n := 0
var _cell := 0.0

## 地形快取：算高度和組地形網格是進關卡時最花時間的兩步（幾乎全部的載入時間）。
## 同一張地形在這次執行期間只算一次，之後再進同一關、或共用同一張地形的其他小關，直接拿來用。
## 只留最近用到的幾張，免得一路玩下來越佔越多記憶體。
const TERRAIN_CACHE_MAX := 4
static var _terrain_cache := {}        # 快取鍵 → {heights, mesh, shape}
static var _terrain_cache_order: Array[String] = []

## 這張地形的快取鍵。預設是「場地腳本 + 種子」：同一個腳本生出來的地形一定一樣。
## 好幾個小關共用同一張地形（高度和地面顏色都一樣）時，在各自的場地腳本覆寫成同一個字串，就只會生成一次。
## 地形會依執行當下的東西改變（例如讀存檔決定地形）時，回傳空字串關掉快取。
func _terrain_cache_key() -> String:
	var sc := get_script() as Script
	if sc == null or sc.resource_path == "":
		return ""
	return "%s#%d" % [sc.resource_path, world_seed]

static func _terrain_cache_put(key: String, entry: Dictionary) -> void:
	_terrain_cache[key] = entry
	_terrain_cache_order.erase(key)
	_terrain_cache_order.append(key)
	while _terrain_cache_order.size() > TERRAIN_CACHE_MAX:
		_terrain_cache.erase(_terrain_cache_order.pop_front())

var _rock_material: ShaderMaterial
var _far_rock_material: ShaderMaterial
var _shrub_material: ShaderMaterial
var _rock_meshes: Array[ArrayMesh] = []
var _rock_shapes: Array[Shape3D] = []
var _rock_bases: Array = []   # [Vector3 位置, float 半徑]：用來在岩腳種草

# ---------------------------------------------------------------- 場地形狀

static func sstep(a: float, b: float, x: float) -> float:
	var t := clampf((x - a) / (b - a), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)

func path_x(z: float) -> float:
	return 2.6 * sin(z * 0.065 + 0.6)

func path_half_width(z: float) -> float:
	var w := lerpf(4.5, 13.0, sstep(6.0, 18.0, z))      # 坡腳空地變寬
	return lerpf(w, 9.0, sstep(-36.0, -46.0, z))         # 坡頂平台

func path_height(z: float) -> float:
	var t := clampf((SLOPE_BOTTOM_Z - z) / (SLOPE_BOTTOM_Z - SLOPE_TOP_Z), 0.0, 1.0)
	return SLOPE_HEIGHT * t * t * (3.0 - 2.0 * t)

func _cc() -> Vector2:   # 佈局座標的空地中心
	return Vector2(path_x(24.0), 24.0)

func _raw_height(x: float, z: float) -> float:
	var d := x - path_x(z)
	var hw := path_half_width(z)
	var h := path_height(z)
	var n := _noise.get_noise_2d(x, z)
	if d < 0.0:
		var a := -d - hw + n * 1.5          # 左側：岩壁腳下快速升高
		h += sstep(0.0, 9.0, a) * 13.0 + maxf(a - 9.0, 0.0) * 0.7
	else:
		var a := d - hw + n * 2.0           # 右側：緩坡草地
		h += sstep(0.0, 24.0, a) * 6.5 + maxf(a - 24.0, 0.0) * 0.3
	h += sstep(36.0, 60.0, z) * 7.0         # 空地後緣
	h += sstep(-52.0, -85.0, z) * 10.0      # 坡頂再往後升高
	var rough := lerpf(0.2, 1.4, sstep(hw - 1.0, hw + 6.0, absf(d)))
	h += n * rough + _detail.get_noise_2d(x, z) * 0.1
	var e := maxf(absf(x), absf(z))
	return lerpf(h, -45.0, sstep(92.0, 119.0, e))   # 邊緣沉入霧中

func _lh(x: float, z: float) -> float:   # 佈局座標的地面高度
	var fx := clampf((x + TERRAIN_SIZE * 0.5) / _cell, 0.0, _n - 1.001)
	var fz := clampf((z + TERRAIN_SIZE * 0.5) / _cell, 0.0, _n - 1.001)
	var i := int(fx)
	var j := int(fz)
	var tx := fx - i
	var tz := fz - j
	var h00 := _heights[j * _n + i]
	var h10 := _heights[j * _n + i + 1]
	var h01 := _heights[(j + 1) * _n + i]
	var h11 := _heights[(j + 1) * _n + i + 1]
	# 與網格三角形切法一致的插值
	if tx + tz <= 1.0:
		return h00 + (h10 - h00) * tx + (h01 - h00) * tz
	return h11 + (h01 - h11) * (1.0 - tx) + (h10 - h11) * (1.0 - tz)

# ---------------------------------------------------------------- 世界座標 API（給角色、玩家、測試用）
# 整個佈局（地形、岩石、遠景）放在縮放 LAYOUT_SCALE 的 Layout 節點下；
# 草叢、灌木、角色、玩家維持真實尺寸，只把位置換算過去。

func height_at(x: float, z: float) -> float:
	return _lh(x / LAYOUT_SCALE, z / LAYOUT_SCALE) * LAYOUT_SCALE

func clearing_center() -> Vector2:
	return _cc() * LAYOUT_SCALE

func world_path_x(z: float) -> float:
	return path_x(z / LAYOUT_SCALE) * LAYOUT_SCALE

func world_path_height(z: float) -> float:
	return path_height(z / LAYOUT_SCALE) * LAYOUT_SCALE

# ---------------------------------------------------------------- 主流程

func _ready() -> void:
	_rng.seed = world_seed
	_noise.seed = world_seed
	_noise.frequency = 0.035
	_noise.fractal_octaves = 3
	_detail.seed = world_seed + 1
	_detail.frequency = 0.2
	_layout = Node3D.new()
	_layout.name = "Layout"
	_layout.scale = Vector3.ONE * LAYOUT_SCALE
	add_child(_layout)
	_make_materials()
	_build_heights()
	_build_terrain()
	_build_far_ground()
	_build_rock_variants()
	_build_rock_wall()
	_build_boulders()
	_build_cairn()
	_build_distant_layers()
	_build_vegetation()
	_build_forest()
	_build_characters()
	_place_player()

func _make_materials() -> void:
	_rock_material = ShaderMaterial.new()
	_rock_material.shader = load("res://shaders/rock.gdshader")
	_rock_material.set_shader_parameter("detail_tex", load(TEX + "lichen_rock_diff_1k.jpg"))

	_far_rock_material = _rock_material.duplicate()
	_far_rock_material.set_shader_parameter("tex_scale", 0.02)
	_far_rock_material.set_shader_parameter("top_amount", 0.2)

	_shrub_material = ShaderMaterial.new()
	_shrub_material.shader = load("res://shaders/bush.gdshader")

# ---------------------------------------------------------------- 地形

func _build_heights() -> void:
	_n = TERRAIN_RES + 1
	_cell = TERRAIN_SIZE / TERRAIN_RES
	var cached: Variant = _terrain_cache.get(_terrain_cache_key())
	if cached != null:
		_heights = cached.heights
		return
	_heights.resize(_n * _n)
	for j in _n:
		var z := -TERRAIN_SIZE * 0.5 + j * _cell
		for i in _n:
			var x := -TERRAIN_SIZE * 0.5 + i * _cell
			_heights[j * _n + i] = _raw_height(x, z)

func _build_terrain() -> void:
	var key := _terrain_cache_key()
	var cached: Variant = _terrain_cache.get(key)
	if cached != null:
		_terrain_cache_put(key, cached)   # 剛用過，排到最後面
		_add_terrain(cached.mesh, cached.shape)
		return
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	verts.resize(_n * _n)
	normals.resize(_n * _n)
	colors.resize(_n * _n)
	var cc := _cc()
	for j in _n:
		var z := -TERRAIN_SIZE * 0.5 + j * _cell
		for i in _n:
			var x := -TERRAIN_SIZE * 0.5 + i * _cell
			var k := j * _n + i
			var h := _heights[k]
			verts[k] = Vector3(x, h, z)
			var hl := _heights[j * _n + maxi(i - 1, 0)]
			var hr := _heights[j * _n + mini(i + 1, _n - 1)]
			var hd := _heights[maxi(j - 1, 0) * _n + i]
			var hu := _heights[mini(j + 1, _n - 1) * _n + i]
			var nrm := Vector3(hl - hr, 2.0 * _cell, hd - hu).normalized()
			normals[k] = nrm

			colors[k] = _terrain_weights(x, z, nrm)

	indices.resize((_n - 1) * (_n - 1) * 6)
	var w := 0
	for j in _n - 1:
		for i in _n - 1:
			var a := j * _n + i
			var c := a + _n
			indices[w] = a
			indices[w + 1] = a + 1
			indices[w + 2] = c
			indices[w + 3] = a + 1
			indices[w + 4] = c + 1
			indices[w + 5] = c
			w += 6

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var shape := mesh.create_trimesh_shape()
	if key != "":
		_terrain_cache_put(key, {"heights": _heights, "mesh": mesh, "shape": shape})
	_add_terrain(mesh, shape)

## 把地形網格和碰撞放進場景（材質每次重新設定，因為各關的地面顏色可以不同）
func _add_terrain(mesh: ArrayMesh, shape: Shape3D) -> void:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/terrain.gdshader")
	mat.set_shader_parameter("detail_tex", load(TEX + "gravelly_sand_diff_1k.jpg"))
	_tweak_terrain_material(mat)

	var mi := MeshInstance3D.new()
	mi.name = "Terrain"
	mi.mesh = mesh
	mi.material_override = mat
	_layout.add_child(mi)

	var body := StaticBody3D.new()
	body.name = "TerrainCollision"
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)
	_layout.add_child(body)

## 地形材質權重（佈局座標）：r=砂土路, g=泥土, b=岩面，其餘為地面。子類別可覆寫。
func _terrain_weights(x: float, z: float, nrm: Vector3) -> Color:
	var cc := _cc()
	var lat := absf(x - path_x(z))
	var dn := _detail.get_noise_2d(x * 0.5, z * 0.5)
	var on_slope := sstep(SLOPE_BOTTOM_Z + 4.0, SLOPE_BOTTOM_Z - 1.0, z) * sstep(-56.0, -46.0, z)
	var sand := (1.0 - sstep(2.3, 4.3, lat + dn * 1.2)) * on_slope
	var cdist := Vector2(x, z).distance_to(cc)
	sand = maxf(sand, 1.0 - sstep(5.5, 10.0, cdist + dn * 3.0))
	var dirt := (1.0 - sstep(3.5, 6.5, lat + dn)) * on_slope * (1.0 - sand)
	dirt = maxf(dirt, (1.0 - sstep(8.0, 12.5, cdist + dn * 2.5)) * (1.0 - sand))
	dirt = maxf(dirt, sstep(0.25, 0.6, _noise.get_noise_2d(x * 2.3, z * 2.3)) * 0.7)
	var rock := sstep(0.2, 0.4, 1.0 - nrm.y)
	return Color(sand, dirt, rock, 1.0)

## 子類別可覆寫，調整地形材質參數
func _tweak_terrain_material(_mat: ShaderMaterial) -> void:
	pass

func _build_far_ground() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(4000, 4000)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/far_ground.gdshader")
	var mi := MeshInstance3D.new()
	mi.name = "FarGround"
	mi.mesh = plane
	mi.material_override = mat
	mi.position.y = -44.0
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_layout.add_child(mi)

# ---------------------------------------------------------------- 岩石

## 以球體為底，用雜訊扭曲並以隨機平面「切削」，做出大片不規則平切面。
func make_rock_mesh(rng: RandomNumberGenerator, cuts: int, roughness: float, flat_bottom := true) -> ArrayMesh:
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 9
	sphere.rings = 6
	var src := sphere.get_mesh_arrays()
	var sv: PackedVector3Array = src[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = src[Mesh.ARRAY_INDEX]

	var nz := FastNoiseLite.new()
	nz.seed = rng.randi()
	nz.frequency = 0.8
	var planes := []
	for k in cuts:
		var pn := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.5, 1.0), rng.randf_range(-1, 1)).normalized()
		planes.append([pn, rng.randf_range(0.5, 0.88)])

	var moved := PackedVector3Array()
	moved.resize(sv.size())
	for v in sv.size():
		var p := sv[v]
		var dir := p.normalized() if p.length() > 0.0001 else Vector3.UP
		p = dir * (1.0 + nz.get_noise_3dv(dir * 1.6) * roughness)
		for pl in planes:
			var dd: float = p.dot(pl[0]) - pl[1]
			if dd > 0.0:
				p -= pl[0] * dd * 0.94
		if flat_bottom and p.y < -0.4:
			p.y = -0.4 + (p.y + 0.4) * 0.25
		moved[v] = p

	var pos := PackedVector3Array()
	var nor := PackedVector3Array()
	var col := PackedColorArray()
	for t in range(0, idx.size(), 3):
		var a := moved[idx[t]]
		var b := moved[idx[t + 1]]
		var c := moved[idx[t + 2]]
		var fn := (b - a).cross(c - a)
		if fn.length_squared() < 1e-9:
			continue
		fn = fn.normalized()
		if fn.dot((a + b + c) / 3.0) < 0.0:
			fn = -fn
		# 同一切面給同一個微小色差 → 低對比的面狀斑駁
		var key := fn.snapped(Vector3(0.15, 0.15, 0.15))
		var hsh := fposmod(sin(key.dot(Vector3(12.9898, 78.233, 37.719))) * 43758.5453, 1.0)
		var s := 0.93 + hsh * 0.12
		var cc := Color(s, s * 0.995, s * 0.985)
		for q in [a, b, c]:
			pos.append(q)
			nor.append(fn)
			col.append(cc)

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = pos
	arrays[Mesh.ARRAY_NORMAL] = nor
	arrays[Mesh.ARRAY_COLOR] = col
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m

## 柱狀岩塊：4~6 邊形柱體，頂面斜切、側面微傾，做出參考圖那種方正的岩柱
func make_column_mesh(rng: RandomNumberGenerator) -> ArrayMesh:
	var sides := rng.randi_range(4, 6)
	var ring_b: Array[Vector3] = []
	var ring_t: Array[Vector3] = []
	var a0 := rng.randf() * TAU
	var tilt := Vector3(rng.randf_range(-0.35, 0.35), 0, rng.randf_range(-0.35, 0.35))
	var top_h := 1.0
	for k in sides:
		var a := a0 + k * TAU / sides + rng.randf_range(-0.25, 0.25)
		var r := rng.randf_range(0.75, 1.0)
		var b := Vector3(cos(a) * r, -0.3, sin(a) * r)
		ring_b.append(b)
		var t := Vector3(b.x * 0.88, top_h + b.x * tilt.x + b.z * tilt.z, b.z * 0.88)
		ring_t.append(t)
	# 頂部再加一圈小倒角，讓輪廓不那麼死板
	var cap: Array[Vector3] = []
	var cap_c := Vector3.ZERO
	for t in ring_t:
		cap_c += t
	cap_c /= sides
	for t in ring_t:
		cap.append(t.lerp(cap_c, 0.22) + Vector3(0, 0.08, 0))
	var tris: Array = []
	for k in sides:
		var k2 := (k + 1) % sides
		tris.append([ring_b[k], ring_t[k], ring_t[k2]]); tris.append([ring_b[k], ring_t[k2], ring_b[k2]])
		tris.append([ring_t[k], cap[k], cap[k2]]); tris.append([ring_t[k], cap[k2], ring_t[k2]])
		tris.append([cap[k], cap_c + Vector3(0, 0.1, 0), cap[k2]])
	return _flat_mesh(tris, Vector3(0, 0.35, 0))

func _flat_mesh(tris: Array, center: Vector3) -> ArrayMesh:
	var pos := PackedVector3Array()
	var nor := PackedVector3Array()
	var col := PackedColorArray()
	for tr in tris:
		var a: Vector3 = tr[0]
		var b: Vector3 = tr[1]
		var c: Vector3 = tr[2]
		var fn := (b - a).cross(c - a)
		if fn.length_squared() < 1e-9:
			continue
		fn = fn.normalized()
		# Godot 正面為順時針：(b-a)x(c-a) 應朝內，否則交換頂點順序
		if fn.dot((a + b + c) / 3.0 - center) > 0.0:
			var tmp := b
			b = c
			c = tmp
		else:
			fn = -fn
		var hsh := fposmod(sin(fn.snapped(Vector3(0.1, 0.1, 0.1)).dot(Vector3(12.9898, 78.233, 37.719))) * 43758.5453, 1.0)
		var s := 0.95 + hsh * 0.08
		for q in [a, b, c]:
			pos.append(q); nor.append(fn); col.append(Color(s, s, s * 0.99))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = pos
	arrays[Mesh.ARRAY_NORMAL] = nor
	arrays[Mesh.ARRAY_COLOR] = col
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m

var _column_meshes: Array[ArrayMesh] = []
var _column_shapes: Array[Shape3D] = []

func _build_rock_variants() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = world_seed + 99
	for k in 12:
		# 少段數 + 多切面 → 大塊平面、稜角分明
		var m := make_rock_mesh(r, r.randi_range(6, 10), r.randf_range(0.1, 0.2))
		_rock_meshes.append(m)
		_rock_shapes.append(m.create_convex_shape())
	for k in 14:
		var c := make_column_mesh(r)
		_column_meshes.append(c)
		_column_shapes.append(c.create_convex_shape())

func _ground_min(x: float, z: float, radius: float) -> float:
	var h := _lh(x, z)
	for a in 6:
		var ang := a * TAU / 6.0
		h = minf(h, _lh(x + cos(ang) * radius, z + sin(ang) * radius))
	return h

func _spawn_rock(parent: Node3D, pos: Vector3, scl: Vector3, yaw: float, collide := true, mat: Material = null, column := false) -> void:
	var meshes := _column_meshes if column else _rock_meshes
	var shapes := _column_shapes if column else _rock_shapes
	var k := _rng.randi() % meshes.size()
	var basis := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, _rng.randf_range(-0.12, 0.12)) * Basis(Vector3.FORWARD, _rng.randf_range(-0.12, 0.12))
	var xf := Transform3D(basis.scaled_local(scl), pos)
	var mi := MeshInstance3D.new()
	mi.mesh = meshes[k]
	mi.material_override = mat if mat else _rock_material
	mi.transform = xf
	parent.add_child(mi)
	if collide:
		var body := StaticBody3D.new()
		body.transform = xf
		var cs := CollisionShape3D.new()
		cs.shape = shapes[k]
		body.add_child(cs)
		parent.add_child(body)

func _build_rock_wall() -> void:
	var wall := Node3D.new()
	wall.name = "RockWall"
	_layout.add_child(wall)
	var z := 40.0
	while z > -64.0:
		var px := path_x(z)
		var hw := path_half_width(z)
		for tier in 4:
			# 每一層放 1~3 根高矮不一的岩柱，彼此錯開
			for c in _rng.randi_range(1, 3):
				var out := hw + 2.0 + tier * 4.5 + _rng.randf_range(-1.0, 2.0)
				var x := px - out
				var zz := z + _rng.randf_range(-2.5, 2.5)
				var wdt := _rng.randf_range(1.6, 3.2)
				var s := Vector3(wdt, _rng.randf_range(2.5, 6.0) * (1.0 + tier * 0.35), wdt * _rng.randf_range(0.8, 1.2))
				var g := _ground_min(x, zz, wdt)
				var pos := Vector3(x, g - 0.4 + tier * _rng.randf_range(0.0, 1.5), zz)
				_spawn_rock(wall, pos, s, _rng.randf() * TAU, tier < 2, null, true)
				if tier == 0:
					_rock_bases.append([Vector3(x, g, zz), wdt])
		# 偶爾夾一顆大塊石
		if _rng.randf() < 0.5:
			var x := px - hw - _rng.randf_range(3.0, 8.0)
			var s := Vector3.ONE * _rng.randf_range(2.5, 4.0)
			_spawn_rock(wall, Vector3(x, _ground_min(x, z, s.x) - 0.5, z), s, _rng.randf() * TAU)
		z -= _rng.randf_range(3.0, 5.0)

func _build_boulders() -> void:
	var node := Node3D.new()
	node.name = "Boulders"
	_layout.add_child(node)
	# 坡道兩側的小石頭，標示坡道邊界
	for k in 16:
		var z := _rng.randf_range(SLOPE_TOP_Z - 6.0, SLOPE_BOTTOM_Z)
		var side := 1.0 if _rng.randf() < 0.65 else -1.0
		var x := path_x(z) + side * (path_half_width(z) + _rng.randf_range(0.3, 2.5))
		var s := Vector3.ONE * _rng.randf_range(0.5, 1.3) * Vector3(1.2, 0.8, 1.0)
		var g := _ground_min(x, z, s.x)
		_spawn_rock(node, Vector3(x, g - 0.1, z), s, _rng.randf() * TAU)
		_rock_bases.append([Vector3(x, g, z), s.x])
	# 右側緩坡上的大石
	for k in 14:
		var z := _rng.randf_range(-60.0, 40.0)
		var x := path_x(z) + path_half_width(z) + _rng.randf_range(5.0, 35.0)
		var s := Vector3(_rng.randf_range(1.2, 3.5), _rng.randf_range(1.0, 3.0), _rng.randf_range(1.2, 3.5))
		var g := _ground_min(x, z, s.x)
		_spawn_rock(node, Vector3(x, g - 0.3, z), s, _rng.randf() * TAU)
		_rock_bases.append([Vector3(x, g, z), s.x])
	# 空地邊緣
	var cc := _cc()
	for k in 5:
		var ang := _rng.randf_range(-0.6, 2.4)
		var r := _rng.randf_range(12.0, 15.0)
		var x := cc.x + cos(ang) * r
		var z := cc.y + sin(ang) * r
		var s := Vector3.ONE * _rng.randf_range(0.8, 1.8)
		var g := _ground_min(x, z, s.x)
		_spawn_rock(node, Vector3(x, g - 0.2, z), s, _rng.randf() * TAU)
		_rock_bases.append([Vector3(x, g, z), s.x])
	# 坡頂後方的岩塊群，框住坡頂
	for k in 22:
		var z := _rng.randf_range(-72.0, -54.0)
		var x := path_x(z) + _rng.randf_range(-22.0, 18.0)
		var s := Vector3(_rng.randf_range(2.0, 4.0), _rng.randf_range(4.0, 10.0), _rng.randf_range(2.0, 4.0))
		var g := _ground_min(x, z, s.x)
		_spawn_rock(node, Vector3(x, g - 0.5, z), s, _rng.randf() * TAU, true, null, true)
		_rock_bases.append([Vector3(x, g, z), s.x])

## 坡頂的小石堆，讓坡頂位置一眼可辨
func _build_cairn() -> void:
	var node := Node3D.new()
	node.name = "Cairn"
	_layout.add_child(node)
	var x := path_x(-44.0) + 3.0
	var z := -44.0
	var y := _lh(x, z)
	var scales := [1.0, 0.8, 0.62, 0.45, 0.3]
	for k in scales.size():
		var s: float = scales[k]
		_spawn_rock(node, Vector3(x + _rng.randf_range(-0.05, 0.05), y + 0.15, z), Vector3(s, s * 0.45, s), _rng.randf() * TAU, k == 0)
		y += s * 0.55

func _build_distant_layers() -> void:
	var node := Node3D.new()
	node.name = "DistantLayers"
	_layout.add_child(node)
	var layers := [
		{"r": 150.0, "count": 22, "w": Vector2(25, 45), "h": Vector2(40, 85)},
		{"r": 230.0, "count": 24, "w": Vector2(35, 65), "h": Vector2(70, 140)},
		{"r": 330.0, "count": 26, "w": Vector2(50, 90), "h": Vector2(100, 210)},
	]
	# 坡頂正後方的巨大岩山（參考圖中被霧籠罩的主峰）
	var mr := RandomNumberGenerator.new()
	mr.seed = world_seed + 7
	for k in 70:
		var t := mr.randf()
		var hgt := pow(t, 0.7) * 230.0
		var spread := (1.0 - t * 0.6) * 90.0
		var pos := Vector3(mr.randf_range(-spread, spread) - 10.0, -40.0 + hgt, -300.0 + mr.randf_range(-40.0, 40.0))
		var sc := Vector3.ONE * mr.randf_range(28.0, 55.0) * Vector3(1.0, mr.randf_range(0.7, 1.2), 1.0)
		var mi := MeshInstance3D.new()
		mi.mesh = _rock_meshes[mr.randi() % _rock_meshes.size()]
		mi.material_override = _far_rock_material
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.transform = Transform3D(Basis(Vector3.UP, mr.randf() * TAU).scaled_local(sc), pos)
		node.add_child(mi)
	for layer in layers:
		for k in layer.count:
			var ang: float = (k + _rng.randf_range(-0.35, 0.35)) * TAU / float(layer.count)
			var r: float = layer.r * _rng.randf_range(0.9, 1.1)
			var pos := Vector3(sin(ang) * r, -48.0, -cos(ang) * r)
			var w := _rng.randf_range(layer.w.x, layer.w.y)
			var s := Vector3(w, _rng.randf_range(layer.h.x, layer.h.y), w * _rng.randf_range(0.6, 1.0))
			var k2 := _rng.randi() % _rock_meshes.size()
			var mi := MeshInstance3D.new()
			mi.mesh = (_column_meshes if k2 % 2 == 0 else _rock_meshes)[k2 % 12]
			mi.material_override = _far_rock_material
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.transform = Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled_local(s), pos)
			node.add_child(mi)

# ---------------------------------------------------------------- 植被

func _make_grass_mesh() -> ArrayMesh:
	var r := RandomNumberGenerator.new()
	r.seed = 77
	var pos := PackedVector3Array()
	var nor := PackedVector3Array()
	var uv := PackedVector2Array()
	var col := PackedColorArray()
	for b in 11:
		var ang := r.randf() * TAU
		var base := Vector3(cos(ang), 0, sin(ang)) * r.randf_range(0.0, 0.2)
		var h := r.randf_range(0.3, 0.7)
		var w := r.randf_range(0.035, 0.06)
		var face := r.randf() * TAU
		var side := Vector3(cos(face), 0, sin(face)) * w
		var lean := Vector3(cos(ang), 0, sin(ang)) * r.randf_range(0.06, 0.25)
		var mid := base + Vector3(0, h * 0.55, 0) + lean * 0.35
		var tip := base + Vector3(0, h, 0) + lean
		var shade := r.randf_range(0.85, 1.1)
		var c := Color(shade, shade, shade)
		var n := side.cross(Vector3.UP).normalized()
		# 兩段式葉片（下段四邊形 + 上段三角形）
		var quad := [base - side, base + side, mid + side * 0.6, base - side, mid + side * 0.6, mid - side * 0.6]
		var quv := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 0.55), Vector2(0, 0), Vector2(1, 0.55), Vector2(0, 0.55)]
		for q in 6:
			pos.append(quad[q]); uv.append(quv[q]); nor.append(n); col.append(c)
		var tri := [mid - side * 0.6, mid + side * 0.6, tip]
		var tuv := [Vector2(0, 0.55), Vector2(1, 0.55), Vector2(0.5, 1.0)]
		for q in 3:
			pos.append(tri[q]); uv.append(tuv[q]); nor.append(n); col.append(c)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = pos
	arrays[Mesh.ARRAY_NORMAL] = nor
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_COLOR] = col
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m

func _build_vegetation() -> void:
	var spots: Array[Vector3] = []   # x, z, 尺寸倍率
	# 1) 坡道兩側：集中在砂土邊緣往外一點
	for side in [-1.0, 1.0]:
		for k in 1900:
			var z := _rng.randf_range(SLOPE_TOP_Z - 10.0, SLOPE_BOTTOM_Z + 2.0)
			var lat := 3.2 + absf(_rng.randfn(0.0, 2.2))
			if side < 0.0:
				lat = minf(lat, path_half_width(z) + 3.0)   # 左側到岩腳為止
			spots.append(Vector3(path_x(z) + side * lat, z, _rng.randf_range(0.8, 1.35)))
	# 2) 岩腳成簇
	for rb in _rock_bases:
		var p: Vector3 = rb[0]
		var rad: float = rb[1]
		for k in 14:
			var ang := _rng.randf() * TAU
			var d := rad * _rng.randf_range(0.7, 1.35)
			spots.append(Vector3(p.x + cos(ang) * d, p.z + sin(ang) * d, _rng.randf_range(0.9, 1.5)))
	# 3) 坡腳空地外圈
	var cc := _cc()
	for k in 600:
		var ang := _rng.randf() * TAU
		var r := 10.0 + absf(_rng.randfn(0.0, 2.8))
		spots.append(Vector3(cc.x + cos(ang) * r, cc.y + sin(ang) * r, _rng.randf_range(0.8, 1.3)))
	# 4) 右側緩坡零星草叢
	for k in 700:
		var z := _rng.randf_range(-70.0, 55.0)
		var x := path_x(z) + path_half_width(z) + _rng.randf_range(6.0, 45.0)
		spots.append(Vector3(x, z, _rng.randf_range(0.7, 1.1)))

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = _make_grass_mesh()
	# 太陡的地方（岩壁面）不長草
	var kept: Array[Vector3] = []
	for sp in spots:
		var gx := _lh(sp.x + 0.5, sp.y) - _lh(sp.x - 0.5, sp.y)
		var gz := _lh(sp.x, sp.y + 0.5) - _lh(sp.x, sp.y - 0.5)
		if Vector2(gx, gz).length() < 0.75:
			kept.append(sp)
	spots = kept
	mm.instance_count = spots.size()
	for k in spots.size():
		var sp := spots[k]
		var y := _lh(sp.x, sp.y) * LAYOUT_SCALE - 0.04
		var s := sp.z
		var b := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(s, s * _rng.randf_range(0.8, 1.3), s))
		mm.set_instance_transform(k, Transform3D(b, Vector3(sp.x * LAYOUT_SCALE, y, sp.y * LAYOUT_SCALE)))
		var greenish := _rng.randf() < 0.18
		var v := _rng.randf_range(0.88, 1.06)
		var c := Color(0.72, 0.9, 0.62) if greenish else Color(v, v * _rng.randf_range(0.96, 1.02), v * 0.97)
		mm.set_instance_color(k, c)
	var grass := MultiMeshInstance3D.new()
	grass.name = "Grass"
	grass.multimesh = mm
	var gm := ShaderMaterial.new()
	gm.shader = load("res://shaders/grass.gdshader")
	grass.material_override = gm
	grass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(grass)

	# 低矮灌叢：岩腳與坡道邊
	var shrubs := Node3D.new()
	shrubs.name = "Shrubs"
	add_child(shrubs)
	var r2 := RandomNumberGenerator.new()
	r2.seed = world_seed + 5
	var shrub_meshes: Array[ArrayMesh] = []
	for k in 4:
		shrub_meshes.append(make_rock_mesh(r2, 0, 0.18, true))
	var shrub_spots: Array = _rock_bases.duplicate()
	for k in 40:
		var z := _rng.randf_range(SLOPE_TOP_Z - 8.0, SLOPE_BOTTOM_Z)
		var side := 1.0 if _rng.randf() < 0.6 else -1.0
		var x := path_x(z) + side * (path_half_width(z) + _rng.randf_range(0.5, 3.0))
		shrub_spots.append([Vector3(x, _lh(x, z), z), 0.3])
	for rb in shrub_spots:
		if _rng.randf() < 0.35:
			continue
		var p: Vector3 = rb[0]
		var rad: float = rb[1]
		for k in _rng.randi_range(1, 3):
			var ang := _rng.randf() * TAU
			var x := p.x + cos(ang) * rad * 0.95
			var z := p.z + sin(ang) * rad * 0.95
			var gx := _lh(x + 0.5, z) - _lh(x - 0.5, z)
			var gz := _lh(x, z + 0.5) - _lh(x, z - 0.5)
			if Vector2(gx, gz).length() > 0.6:
				continue
			var s := _rng.randf_range(0.35, 0.75)
			var mi := MeshInstance3D.new()
			mi.mesh = shrub_meshes[_rng.randi() % shrub_meshes.size()]
			mi.material_override = _shrub_material
			mi.transform = Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled_local(Vector3(s * 1.2, s * 0.85, s * 1.1)), Vector3(x, _lh(x, z), z) * LAYOUT_SCALE + Vector3(0, s * 0.15, 0))
			shrubs.add_child(mi)

# ---------------------------------------------------------------- 森林邊界

## 遊玩範圍外圍一圈密林（世界座標）：內側就是幽靈能飄到的邊界
const FOREST_INNER_MIN := Vector2(-30.0, -34.0)
const FOREST_INNER_MAX := Vector2(30.0, 26.0)
const FOREST_DEPTH := 11.0

func _build_forest() -> void:
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
	var crown_cols: Array[Color] = []
	var step := 1.9
	var x := FOREST_INNER_MIN.x - FOREST_DEPTH
	while x <= FOREST_INNER_MAX.x + FOREST_DEPTH:
		var z := FOREST_INNER_MIN.y - FOREST_DEPTH
		while z <= FOREST_INNER_MAX.y + FOREST_DEPTH:
			var px := x + r.randf_range(-0.8, 0.8)
			var pz := z + r.randf_range(-0.8, 0.8)
			# 到內側邊界的距離（在邊界外才種）
			var dx := maxf(FOREST_INNER_MIN.x - px, px - FOREST_INNER_MAX.x)
			var dz := maxf(FOREST_INNER_MIN.y - pz, pz - FOREST_INNER_MAX.y)
			var outside := maxf(dx, dz)
			if outside > -0.5 and r.randf() < 0.92:
				var gy := height_at(px, pz)
				var h := r.randf_range(3.2, 5.8) * (1.0 + clampf(outside, 0.0, 8.0) * 0.04)
				var yaw := r.randf() * TAU
				var tb := Basis(Vector3.UP, yaw).scaled(Vector3(1, h * 0.55, 1))
				trunks.append(Transform3D(tb, Vector3(px, gy + h * 0.27, pz)))
				var green := Color(r.randf_range(0.22, 0.36), r.randf_range(0.42, 0.56), r.randf_range(0.2, 0.3))
				# 兩到三團圓圓的樹冠疊起來
				var layers := r.randi_range(2, 3)
				for k in layers:
					var cr := h * (0.36 - k * 0.07)
					var cy := gy + h * (0.55 + k * 0.2)
					var cb := Basis(Vector3.UP, r.randf() * TAU).scaled(Vector3(cr, cr * 0.85, cr))
					crowns.append(Transform3D(cb, Vector3(px + r.randf_range(-0.2, 0.2), cy, pz + r.randf_range(-0.2, 0.2))))
					crown_cols.append(green.lightened(k * 0.08))
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
	var trunk_mat := ShaderMaterial.new()
	trunk_mat.shader = load("res://shaders/toon_color.gdshader")
	trunk_mat.set_shader_parameter("albedo", Color(0.45, 0.32, 0.2))
	tmi.material_override = trunk_mat
	add_child(tmi)

	var cm := MultiMesh.new()
	cm.transform_format = MultiMesh.TRANSFORM_3D
	cm.use_colors = true
	cm.mesh = blob
	cm.instance_count = crowns.size()
	for i in crowns.size():
		cm.set_instance_transform(i, crowns[i])
		cm.set_instance_color(i, crown_cols[i])
	var cmi := MultiMeshInstance3D.new()
	cmi.name = "ForestCrowns"
	cmi.multimesh = cm
	var crown_mat := ShaderMaterial.new()
	crown_mat.shader = load("res://shaders/forest_crown.gdshader")
	cmi.material_override = crown_mat
	add_child(cmi)

# ---------------------------------------------------------------- 角色

func _build_characters() -> void:
	var chars := Node3D.new()
	chars.name = "Characters"
	chars.set_script(load("res://scripts/characters.gd"))
	add_child(chars)
	chars.setup(self)

# ---------------------------------------------------------------- 玩家起點

func _place_player() -> void:
	var player := get_node_or_null(player_path) as Node3D
	if player == null:
		return
	var cc := clearing_center()
	var x := cc.x + 6.0
	var z := cc.y + 7.0
	player.global_position = Vector3(x, height_at(x, z) + 1.5, z)   # 幽靈：離地漂浮
	var target := Vector3(world_path_x(0.0), 0.0, 0.0)
	var dir := target - player.global_position
	player.rotation = Vector3(0.0, atan2(-dir.x, -dir.z), 0.0)
	var head := player.get_node_or_null("Head") as Node3D
	if head:
		head.rotation.x = deg_to_rad(-6.0)
