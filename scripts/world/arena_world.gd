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
## 太陽陰影涵蓋到離鏡頭多遠（公尺）；0 = 照遊玩範圍大小自動算
var shadow_distance := 0.0
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
	_tune_shadows()

## 太陽的陰影只要涵蓋遊玩範圍：分兩層就好（原本四層，每一層都要把會投影的東西再畫一次），
## 距離照「鏡頭起點到遊玩範圍最遠的角」算。各關在 _configure() 設 shadow_distance 可以自己指定。
func _tune_shadows() -> void:
	var sun := get_parent().get_node_or_null("Sun") as DirectionalLight3D if get_parent() else null
	if sun == null or not sun.shadow_enabled:
		return
	var dist := shadow_distance
	if dist <= 0.0:
		var cam := Vector2(camera_start.x, camera_start.z)
		var far := 0.0
		for c in [play_min, play_max, Vector2(play_min.x, play_max.y), Vector2(play_max.x, play_min.y)]:
			far = maxf(far, cam.distance_to(c))
		dist = clampf(far + 15.0, 45.0, 80.0)
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = dist
	sun.directional_shadow_split_1 = 0.25

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
	var xfs: Array[Transform3D] = []
	var cols: Array[Color] = []
	for k in spots.size():
		var sp := spots[k]
		var s := sp.z * 0.8
		var bb := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(s, s * _rng.randf_range(0.8, 1.2), s))
		xfs.append(Transform3D(bb, Vector3(sp.x, height_at(sp.x, sp.y) - 0.04, sp.y)))
		var v := _rng.randf_range(0.85, 1.05)
		cols.append(Color(0.62 * v, 0.95 * v, 0.5 * v) if _rng.randf() < 0.55 else Color(v, v, v * 0.95))
	var gm := ShaderMaterial.new()
	gm.shader = load("res://shaders/grass.gdshader")
	_spawn_grass_chunks(xfs, cols, gm)

## 草叢切成 GRASS_CHUNK 公尺見方的小塊：鏡頭背後、太遠的小塊引擎會自動略過不畫。
## 第一塊叫 "Grass"，其他塊都是它的子節點，而且共用同一個材質——
## 所以各關用 get_node("Grass") 改材質、或把 "Grass" 藏起來，整片草都會跟著變。
const GRASS_CHUNK := 8.0
const GRASS_HIDE := 50.0      # 草的小塊離鏡頭超過這麼遠就不畫（草很小，這麼遠本來就看不太到）

func _spawn_grass_chunks(xfs: Array[Transform3D], cols: Array[Color], mat: Material) -> MultiMeshInstance3D:
	if xfs.is_empty():
		return null
	var groups := {}
	for i in xfs.size():
		var o := xfs[i].origin
		var key := Vector2i(floori(o.x / GRASS_CHUNK), floori(o.z / GRASS_CHUNK))
		if not groups.has(key):
			groups[key] = []
		groups[key].append(i)
	var keys := groups.keys()
	keys.sort()   # 固定順序，每次載入都一樣
	var mesh := _make_grass_mesh()
	var root: MultiMeshInstance3D = null
	for key in keys:
		var ids: Array = groups[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = mesh
		mm.instance_count = ids.size()
		for j in ids.size():
			mm.set_instance_transform(j, xfs[ids[j]])
			mm.set_instance_color(j, cols[ids[j]])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = mat
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.visibility_range_end = GRASS_HIDE
		mmi.visibility_range_end_margin = 5.0
		if root == null:
			mmi.name = "Grass"
			add_child(mmi)
			root = mmi
		else:
			mmi.name = "Grass_%d_%d" % [key.x, key.y]
			root.add_child(mmi)
	return root

## （這一區的函式和常數都用 _forest／FOREST_ 開頭：各關的場地會繼承這個檔案，名字太普通會跟它們自己的函式撞名）
## 外圍的樹：只是用來標出「這裡是邊界」，所以種得稀疏、像原野上一叢一叢的樹（參考原神那種開闊的草原）。
## 一棵樹 = 主幹 → 在六成高左右分成 2～4 根斜枝 → 每根枝頭一團樹冠（幾顆低多邊形圓團擠在一起），頭頂再一團。
## 結構借自劉起佑大關的油畫樹（主幹、分枝、枝頭長葉），但葉子用圓團不用葉片，跟城堡的低多邊形風格一致、也比較省。
## 樹冠每一顆圓團的亮暗依太陽方向先算好（向陽那面亮、偏黃；背光那面暗、偏藍），一樣是借劉起佑的做法。
##
## 擺法：
##   - 稀疏、成叢：雜訊決定哪裡有一叢 2～4 棵，叢和叢之間是空草地
##   - 高低錯落：同一叢裡有大有小，偶爾一棵特別高的主角樹；越外面整體越高，從院子看出去有層次
##   - 林緣：靠近院子的地方零星幾叢矮灌木
## 依離遊玩範圍遠近分三層，越遠越省：
##   前排：完整的樹（3～4 根枝、每團 3～4 顆），會投影
##   中排：枝和圓團少一點，不投影
##   後排：主幹＋兩三團樹冠，不投影；鏡頭拉很遠時整塊隱藏
## 整片切成一塊一塊（FOREST_CHUNK 公尺見方），鏡頭背後的區塊會被引擎自動略過不畫。
const FOREST_NEAR_D := 3.5       # 離遊玩範圍這麼近以內是前排
const FOREST_FAR_D := 7.0        # 超過這裡是後排
const FOREST_STEP := 3.6         # 前、中排找種樹點的間距（稀疏）
const FOREST_FAR_STEP := 4.4     # 後排
const FOREST_CHUNK := 16.0
const FOREST_FAR_HIDE := 120.0   # 後排區塊離鏡頭超過這麼遠就不畫
const FOREST_BUSH_STEP := 2.2           # 林緣灌木找點的間距
const FOREST_BUSH_D := 2.6              # 離遊玩範圍這麼近以內才種灌木
const FOREST_SUN_TO := Vector3(0.38, 0.46, 0.8)   # 朝太陽的方向（scenes/stage_base.tscn 的 Sun：rotation (-0.48, 0.95, 0) 的 +Z）
## 樹冠的顏色從關卡的 tree_green 推出來：偏藍綠／偏黃綠兩種分區，背光那面混進更深的顏色
## 葉片樹（參考劉起佑大關）：細樹幹、枝頭一撮一撮的葉片，顏色亮一點，當作綠色樹林裡跳出來的點綴
const FOREST_LEAFY_CHANCE := 0.35       # 前、中排每棵樹有這個機率是葉片樹
const FOREST_LEAFY_COLORS := [Color(0.98, 0.83, 0.3), Color(0.95, 0.72, 0.24), Color(0.68, 0.8, 0.32)]   # 金黃、橘黃、嫩綠
const FOREST_LEAFY_SHADE := Color(0.42, 0.22, 0.1)  # 葉片背光那面混進去的深棕

func _build_arena_forest() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = world_seed + 31
	var blob_rng := RandomNumberGenerator.new()
	blob_rng.seed = world_seed + 32
	var blob := make_rock_mesh(blob_rng, 0, 0.22, false)
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.75       # 一段枝幹：上細下粗（半徑 1 = 底），由 _forest_seg 縮放
	trunk.bottom_radius = 1.0
	trunk.height = 1.0
	trunk.radial_segments = 6
	trunk.rings = 1
	# 雜訊：哪裡有一叢、顏色分區。固定 seed，每次載入都一樣
	var n_clump := FastNoiseLite.new()
	n_clump.seed = world_seed + 41
	n_clump.frequency = 0.08
	var n_tint := FastNoiseLite.new()
	n_tint.seed = world_seed + 43
	n_tint.frequency = 0.045
	var chunks := {}
	var fr := Rect2(play_min - Vector2.ONE * forest_band, (play_max - play_min) + Vector2.ONE * forest_band * 2.0)
	for far in [false, true]:
		var step: float = FOREST_FAR_STEP if far else FOREST_STEP
		var x := fr.position.x
		while x <= fr.end.x:
			var z := fr.position.y
			while z <= fr.end.y:
				var cx := x + r.randf_range(-step * 0.45, step * 0.45)
				var cz := z + r.randf_range(-step * 0.45, step * 0.45)
				var roll := r.randf()
				var clump := smoothstep(-0.25, 0.35, n_clump.get_noise_2d(cx, cz))
				var keep := lerpf(0.35, 0.95, clump) if far else clump * 0.85
				var d0 := play_dist(cx, cz)
				var ok: bool = (d0 >= FOREST_FAR_D) if far else (d0 > 0.8 and d0 < FOREST_FAR_D)
				# 神（玩家）一開始站的地方附近不種樹，免得一進關卡鏡頭卡在樹裡
				var near_cam := Vector2(cx - camera_start.x, cz - camera_start.z).length() < 6.0
				if ok and d0 < forest_band and not near_cam and roll < keep:
					# 一叢 1～4 棵，有大有小
					var n := r.randi_range(1, 3) + (1 if clump > 0.7 else 0)
					for k in n:
						var px := cx + (r.randf_range(-1.6, 1.6) if k > 0 else 0.0)
						var pz := cz + (r.randf_range(-1.6, 1.6) if k > 0 else 0.0)
						var d := play_dist(px, pz)
						if d < 0.6 or d >= forest_band:
							continue
						var tier := 2 if far else (0 if d < FOREST_NEAR_D else 1)
						var size := 1.0 if k == 0 else r.randf_range(0.55, 0.85)
						_forest_tree(_forest_chunk(chunks, px, pz, tier), r, px, pz, d, tier, size, n_tint.get_noise_2d(px, pz))
				z += step
			x += step
	# 林緣：零星幾叢矮灌木
	var bx := fr.position.x
	while bx <= fr.end.x:
		var bz := fr.position.y
		while bz <= fr.end.y:
			var px := bx + r.randf_range(-0.8, 0.8)
			var pz := bz + r.randf_range(-0.8, 0.8)
			var d := play_dist(px, pz)
			var roll := r.randf()
			if d > 0.3 and d < FOREST_BUSH_D and roll < 0.3:
				_forest_bush(_forest_chunk(chunks, px, pz, 0), r, px, pz, n_tint.get_noise_2d(px, pz))
			bz += FOREST_BUSH_STEP
		bx += FOREST_BUSH_STEP
	var trunk_mat := _toon(Color(0.42, 0.3, 0.22))
	# 所有樹冠共用同一個材質：特寫鏡頭改一次鏤空參數，每一塊都會跟著變
	var crown_mat := ShaderMaterial.new()
	crown_mat.shader = load("res://shaders/forest_crown.gdshader")
	var leaf := QuadMesh.new()
	leaf.size = Vector2(1.0, 1.0)
	var leaf_mat := ShaderMaterial.new()
	leaf_mat.shader = load("res://shaders/forest_leaf.gdshader")
	var forest := Node3D.new()
	forest.name = "Forest"
	add_child(forest)
	var keys := chunks.keys()
	keys.sort()   # 固定順序，每次載入節點都一樣
	for key in keys:
		var ch: Dictionary = chunks[key]
		var tier: int = key.z
		var tag := "%d_%d_%d" % [key.x, key.y, tier]
		_add_forest_mm(forest, "ForestTrunks_" + tag, trunk, ch.trunks, [], trunk_mat, tier)
		_add_forest_mm(forest, "ForestCrowns_" + tag, blob, ch.crowns, ch.cols, crown_mat, tier)
		_add_forest_mm(forest, "ForestLeaves_" + tag, leaf, ch.leaves, ch.leaf_cols, leaf_mat, tier)

func _forest_cool() -> Color:
	return Color(tree_green.r * 0.6, tree_green.g * 0.95, tree_green.b * 1.6 + 0.04)
func _forest_warm() -> Color:
	return Color(tree_green.r * 1.3 + 0.05, tree_green.g * 1.2 + 0.02, tree_green.b * 1.0)
func _forest_shade() -> Color:
	return tree_green.darkened(0.6).lerp(Color(0.05, 0.12, 0.18), 0.4)

func _forest_chunk(chunks: Dictionary, px: float, pz: float, tier: int) -> Dictionary:
	var key := Vector3i(floori(px / FOREST_CHUNK), floori(pz / FOREST_CHUNK), tier)
	if not chunks.has(key):
		chunks[key] = {"trunks": [], "crowns": [], "cols": [], "leaves": [], "leaf_cols": []}
	return chunks[key]

## 一段枝幹：從 a 到 b、底部半徑 rad（圓柱的 Y 軸對準這一段）
func _forest_seg(ch: Dictionary, a: Vector3, b: Vector3, rad: float) -> void:
	var dir := b - a
	var l := dir.length()
	if l < 0.01:
		return
	var y := dir / l
	var x := y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
	var z := x.cross(y)
	ch.trunks.append(Transform3D(Basis(x * rad, y * l, z * rad), (a + b) * 0.5))

## 一團樹冠：在 c 附近擠 n 顆圓團；每顆的顏色依朝不朝太陽先算好
func _forest_canopy(ch: Dictionary, r: RandomNumberGenerator, c: Vector3, rc: float, n: int, base: Color) -> void:
	var sun := FOREST_SUN_TO.normalized()
	for k in n:
		var o := Vector3(r.randf_range(-1.0, 1.0), r.randf_range(-0.35, 0.6), r.randf_range(-1.0, 1.0))
		if k == 0:
			o = Vector3(0, 0.15, 0)
		elif o.length() > 1.0:
			o = o.normalized()
		var s := rc * r.randf_range(0.5, 0.72)
		var b := Basis(Vector3.UP, r.randf() * TAU).scaled(Vector3(s, s * 0.78, s))
		ch.crowns.append(Transform3D(b, c + Vector3(o.x * rc * 0.75, o.y * rc * 0.55, o.z * rc * 0.75)))
		var lit := clampf((o + Vector3(0, 0.7, 0)).normalized().dot(sun) * 0.7 + 0.45 + r.randf_range(-0.1, 0.1), 0.0, 1.0)
		var col := _forest_shade().lerp(base, 0.45 + 0.55 * lit)
		if lit > 0.82:
			col = col.lerp(Color(0.85, 0.95, 0.55), 0.18)   # 最亮的那幾顆帶一點陽光的黃
		ch.cols.append(col)

func _forest_tree(ch: Dictionary, r: RandomNumberGenerator, px: float, pz: float, d: float, tier: int, size: float, tint: float) -> void:
	var gy := height_at(px, pz)
	# 高低錯落：基本高度隨機、越外面越高，偶爾一棵主角樹
	var h := r.randf_range(3.6, 6.4) * size * (1.0 + clampf(d, 0.0, 10.0) * 0.045)
	if tier < 2 and size >= 1.0 and r.randf() < 0.1:
		h *= 1.45
	var base := _forest_cool().lerp(_forest_warm(), smoothstep(-0.5, 0.5, tint + r.randf_range(-0.15, 0.15)))
	var rad := 0.11 + h * 0.022
	if tier < 2 and r.randf() < FOREST_LEAFY_CHANCE:
		_forest_leafy_tree(ch, r, Vector3(px, gy, pz), h * 0.85, rad * 0.75, tier)
		return
	# 主幹：微微歪一點，在六成高左右分枝
	var up := Vector3(r.randf_range(-0.08, 0.08), 1.0, r.randf_range(-0.08, 0.08)).normalized()
	var root := Vector3(px, gy - 0.3, pz)
	var fork := root + up * (h * r.randf_range(0.5, 0.62) + 0.3)
	_forest_seg(ch, root, fork, rad)
	var crown_r := h * 0.27
	if tier == 2:
		# 後排：主幹往上直接長兩三團
		var top := fork + up * h * 0.25
		_forest_seg(ch, fork - up * 0.05, top, rad * 0.75)
		_forest_canopy(ch, r, top, crown_r * 1.25, 3, base)
		return
	var limbs := r.randi_range(3, 4) if tier == 0 else r.randi_range(2, 3)
	var per := 4 if tier == 0 else 3
	var az0 := r.randf() * TAU
	for k in limbs:
		var az := az0 + TAU * float(k) / limbs + r.randf_range(-0.4, 0.4)
		var tilt := r.randf_range(0.55, 1.0)                    # 枝往外斜的角度
		var dir := (Vector3(cos(az) * sin(tilt), cos(tilt), sin(az) * sin(tilt))).normalized()
		var l := h * r.randf_range(0.22, 0.32)
		var tip := fork + dir * l
		_forest_seg(ch, fork - up * 0.05, tip, rad * 0.62)
		_forest_canopy(ch, r, tip + Vector3(0, crown_r * 0.25, 0), crown_r * r.randf_range(0.8, 1.05), per, base)
	# 頭頂一團
	var top := fork + up * h * 0.3
	_forest_seg(ch, fork - up * 0.05, top, rad * 0.6)
	_forest_canopy(ch, r, top + Vector3(0, crown_r * 0.2, 0), crown_r * 1.05, per, base)

## 葉片樹：細直的樹幹，六成高以上分出 2～3 根細枝，每根枝頭一撮葉片（像劉起佑大關的樹，但小一點、稀一點）
func _forest_leafy_tree(ch: Dictionary, r: RandomNumberGenerator, base: Vector3, h: float, rad: float, tier: int) -> void:
	var tint: Color = FOREST_LEAFY_COLORS[r.randi() % FOREST_LEAFY_COLORS.size()]
	var up := Vector3(r.randf_range(-0.06, 0.06), 1.0, r.randf_range(-0.06, 0.06)).normalized()
	var root := base - Vector3(0, 0.3, 0)
	var fork := root + up * (h * r.randf_range(0.55, 0.68) + 0.3)
	_forest_seg(ch, root, fork, rad)
	var per := 22 if tier == 0 else 15   # 一片葉子只有 2 個三角形，多放一點才看得出一撮
	var n := r.randi_range(2, 3)
	var az0 := r.randf() * TAU
	for k in n:
		var az := az0 + TAU * float(k) / n + r.randf_range(-0.4, 0.4)
		var tilt := r.randf_range(0.45, 0.8)
		var dir := Vector3(cos(az) * sin(tilt), cos(tilt), sin(az) * sin(tilt)).normalized()
		var tip := fork + dir * h * r.randf_range(0.2, 0.3)
		_forest_seg(ch, fork - up * 0.05, tip, rad * 0.5)
		_forest_leaf_clump(ch, r, tip, h * 0.2, per, tint)
	var top := fork + up * h * 0.32
	_forest_seg(ch, fork - up * 0.05, top, rad * 0.5)
	_forest_leaf_clump(ch, r, top, h * 0.23, per + 4, tint)

## 一撮葉片：在 c 附近散 n 片，每片隨意翻轉；朝太陽那面用亮色、背光那面混進深棕（顏色就是顏料，不靠打光）
func _forest_leaf_clump(ch: Dictionary, r: RandomNumberGenerator, c: Vector3, rc: float, n: int, tint: Color) -> void:
	var sun := FOREST_SUN_TO.normalized()
	for k in n:
		var o := Vector3(r.randf_range(-1.0, 1.0), r.randf_range(-0.6, 0.75), r.randf_range(-1.0, 1.0))
		if o.length() > 1.0:
			o = o.normalized() * r.randf_range(0.5, 1.0)
		var s := r.randf_range(0.9, 1.6)
		var b := Basis.from_euler(Vector3(r.randf_range(-1.2, 1.2), r.randf() * TAU, r.randf_range(-0.8, 0.8))).scaled(Vector3(s, s * 0.6, s))
		ch.leaves.append(Transform3D(b, c + o * rc))
		var v := r.randf_range(0.85, 1.1)
		var col := Color(tint.r * v, tint.g * v, tint.b * v)
		var lit := clampf(o.normalized().dot(sun) * 0.75 + 0.5 + r.randf_range(-0.2, 0.2), 0.0, 1.0)
		col = FOREST_LEAFY_SHADE.lerp(col, 0.3 + 0.7 * lit)
		if lit > 0.8:
			col = col.lerp(Color(1.0, 0.95, 0.6), 0.25)
		ch.leaf_cols.append(col)

## 矮灌木：1～3 顆壓扁的小圓團
func _forest_bush(ch: Dictionary, r: RandomNumberGenerator, px: float, pz: float, tint: float) -> void:
	var gy := height_at(px, pz)
	var base := _forest_cool().lerp(_forest_warm(), smoothstep(-0.5, 0.5, tint)).lightened(0.08)
	_forest_canopy(ch, r, Vector3(px, gy + 0.3, pz), r.randf_range(0.6, 1.0), r.randi_range(2, 3), base)

func _add_forest_mm(parent: Node3D, nm: String, mesh: Mesh, xfs: Array, cols: Array, mat: Material, tier: int) -> void:
	if xfs.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = not cols.is_empty()
	mm.mesh = mesh
	mm.instance_count = xfs.size()
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i])
		if mm.use_colors:
			mm.set_instance_color(i, cols[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = nm
	mmi.multimesh = mm
	mmi.material_override = mat
	if tier > 0:
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if tier == 2:
		mmi.visibility_range_end = FOREST_FAR_HIDE
		mmi.visibility_range_end_margin = 10.0
	parent.add_child(mmi)

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
