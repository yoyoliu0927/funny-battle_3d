extends "res://scripts/world_builder.gd"
## 範例關的場地：農場（範例，不屬於任何人的大關）
##
## 平緩的農場地形（不再有大坡和石柱），外圍一圈密林是世界邊界。
## 家豪從南邊的農場大門外出發；農場裡有三個農夫守在不同位置。
##
## 版面（世界座標，公尺；-Z 是北邊/農場深處）
##   大門      (0, 13)，雞從門外 (0, 17) 出發
##   農場      x -17~17、z -20~13，四周被森林包住；只有大門兩側有一小段圍欄
##   台地      東南邊（大門右手邊），一階一階升進森林；石球從北邊滾下去能推倒水塔
##   水塔      五座排成一串，從台地北邊排到大穀倉：骨牌
##   大穀倉    西北邊，老闆坐在最裡面的辦公桌後面
##   中庭      (0, -2.4) 附近，一條土路從大門通到中庭，再分岔到大穀倉和風車

const FARM_MIN := Vector2(-17.0, -20.0)
const FARM_MAX := Vector2(17.0, 13.0)
const GATE_HALF := 2.4
const YARD_HALF := 7.5           # 大門外的入口空地（|x| < 7.5, z 13~21）
const YARD_MAX_Z := 21.0
const FOREST_BAND := 11.0        # 遊玩範圍外包一圈這麼厚的森林
## 台地：農場東南邊（大門右手邊）一階一階往上抬，連後面的森林一起升高（樹也跟著長在高處）。
## 每階之間是陡坡，人和雞都上不去；台面微微往外傾斜，石球放上去會滾到邊緣再滾下來。
## 北邊的邊緣正對著第一座水塔：石球從那裡滾下去就能推倒水塔，像骨牌一樣一路倒到大穀倉。
const PLAT_X0 := 5.0                       # 台地範圍：x 大於這裡、
const PLAT_Z0 := -1.0                      #           z 大於這裡、
const PLAT_ZMAX := 11.0                    #           z 小於這裡（只限大門附近；更東邊的台地一路延伸進森林）
const PLAT_GATE_X := 10.5                  # x 超過這裡，台地就不再被大門那條邊擋住
## 水池（原本風車的位置）：中間有一座小島，家豪可以飛過去，追上來的農夫會掉進水裡淹死
const POND_CENTER := Vector2(-13.0, 2.0)
const POND_R := 4.6
const ISLAND_R := 1.4
const PLAT_ROUND := 5.0                    # 轉角圓滑程度
const TIERS := [[0.0, 4.0], [6.5, 4.0], [13.5, 3.5]]   # [從台地邊往內多遠開始, 這一階抬高多少]
const TIER_RAMP := 1.3                     # 階與階之間陡坡的寬度
const TOP_TILT := 0.16                     # 台面往農場傾斜的坡度
const HILL_CENTER := Vector2(11.0, 5.0)    # 台地第一階的大概中央（裝飾、測試用）
const HILL_WALK_LIMIT := 1.0               # 地形比平地高出這麼多就走不上去
## 建築腳下的平台（中心、半徑）：這裡的地面會整平
const PADS := [
	[Vector2(-9.6, -13.2), 5.2], [Vector2(-13.0, 2.0), 5.6], [Vector2(0.0, 13.0), 3.0],
	[Vector2(0.5, -13.2), 2.0], [Vector2(5.0, -14.2), 2.0], [Vector2(9.3, -13.0), 2.0],
	[Vector2(11.6, -9.0), 2.0], [Vector2(11.8, -4.6), 2.0],
]
## 五座水塔（骨牌）：第 0 座最靠近大穀倉，第 4 座最靠近台地。被撞到就往前一座倒，最後一座砸向大穀倉
const WATER_TOWERS := [Vector2(0.5, -13.2), Vector2(5.0, -14.2), Vector2(9.3, -13.0), Vector2(11.6, -9.0), Vector2(11.8, -4.6)]
const TOWER_SCALE := 0.9
const BARN_POS := Vector3(-9.6, 0, -13.2)
## 老闆：坐在大穀倉最裡面的辦公桌後面
const BOSS_POST := Vector3(-9.6, 0, -16.1)   # 往前坐一點，不要卡進後牆
const HERO_START := Vector3(0.0, 0.0, 17.0)
const MODEL_FARM := "res://assets/farm/"
const MODEL_NATURE := "res://assets/nature/"

## 每個農夫各自的巡邏路線：route 依序走，loop=true 繞圈、false 來回；每到一個點停下來張望 pause 秒
const FARMER_ROUTES := [
	# 大門內的守衛：沿著大門內側左右來回
	{"route": [Vector3(3.2, 0, 7.6), Vector3(-3.2, 0, 7.6)], "loop": false, "pause": 1.6},
	# 中庭：繞著中庭走一圈
	{"route": [Vector3(-3.2, 0, 0.8), Vector3(-5.2, 0, -4.8), Vector3(1.2, 0, -6.8), Vector3(3.2, 0, -0.8)], "loop": true, "pause": 0.9},
	# 水塔附近：在水塔之間來回
	{"route": [Vector3(2.0, 0, -9.0), Vector3(6.5, 0, -9.5), Vector3(8.0, 0, -6.0)], "loop": false, "pause": 1.3},
]

## 土路（折線，世界座標）
const ROADS := [
	[Vector2(0, 21), Vector2(0, 13), Vector2(0.4, 3.2), Vector2(0, -2.4)],
	[Vector2(0, -2.4), Vector2(-5.6, -7.2), Vector2(-9.0, -8.0)],
	[Vector2(0, -2.4), Vector2(-7.0, 1.5), Vector2(-10.0, 1.0)],
]
const YARD_CENTER := Vector2(0.0, -2.4)

## 給 AI 用的障礙：圍欄線段（主角飛得過去、農夫要繞）與建築/樹的圓形範圍
var hero_start: Vector3 = HERO_START
var farmer_routes: Array = FARMER_ROUTES
var hill_center: Vector2 = HILL_CENTER
var boss_post: Vector3 = BOSS_POST
var barn_pos: Vector3 = BARN_POS
var pond_center: Vector2 = POND_CENTER
var pond_r: float = POND_R
var island_r: float = ISLAND_R
var water_y := 0.0
var towers: Array = []             # [{node, pos(Vector2), radius, height}]，順序同 WATER_TOWERS
var barn_node: Node3D
var fence_segments: Array = []      # [[Vector2 a, Vector2 b], ...]  矮圍欄：家豪飛得過去
var wall_segments: Array = []       # 大穀倉的牆：誰都穿不過，只能從南邊的大門進出，子彈也打不穿
var barn_rect := Rect2()            # 大穀倉內部（x, z）
var door_out := Vector3.ZERO        # 門外一點點
var door_in := Vector3.ZERO         # 門內一點點
var plateau_rocks: Array[Vector2] = []   # 台地上的裝飾石頭位置
var obstacles: Array = []           # [[Vector2 center, float radius], ...]

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
	_build_distant_layers()
	_build_fences()
	_build_buildings()
	_build_inner_trees()
	_build_farm_grass()
	_build_farm_forest()
	_build_farm_characters()
	_place_player()

# ---------------------------------------------------------------- 地形（平緩）

## 世界座標的農場地形高度
func farm_height(x: float, z: float) -> float:
	var n := _noise.get_noise_2d(x * 2.0, z * 2.0)
	# 平面上有明顯但不誇張的起伏（約 2~3 公尺）
	var h := _rolling(x, z)
	# 建築腳下整平
	for pad in PADS:
		var c: Vector2 = pad[0]
		var w := 1.0 - sstep(pad[1], pad[1] + 3.5, Vector2(x, z).distance_to(c))
		if w > 0.0:
			h = lerpf(h, _rolling(c.x, c.y), w)
	h += n * 0.08
	# 水池：挖一個池底，中間留一座小島
	var pd := Vector2(x, z).distance_to(POND_CENTER)
	var basin := (1.0 - sstep(POND_R - 1.2, POND_R + 0.3, pd)) * sstep(ISLAND_R - 0.2, ISLAND_R + 0.9, pd)
	h -= 1.5 * basin
	h += sstep(-24.0, -44.0, z) * 1.5
	h += sstep(22.0, 42.0, absf(x)) * 1.0
	# 台地上的台面幾乎不要起伏，只留往外的微斜，石球才滾得順
	var pb := hill_bump(x, z)
	h *= lerpf(1.0, 0.08, sstep(0.3, 2.5, pb))
	h += pb
	return h

## 大範圍的緩丘
func _rolling(x: float, z: float) -> float:
	return _noise.get_noise_2d(x * 1.1 + 40.0, z * 1.1) * 1.9 + _noise.get_noise_2d(x * 2.6, z * 2.6 + 17.0) * 0.45

## 離台地邊緣往內多遠（台地外是負的）：兩條邊用圓角接起來，邊緣加一點自然的起伏
func plateau_q(x: float, z: float) -> float:
	var a := x - PLAT_X0
	var b := z - PLAT_Z0
	# 南邊的邊只在大門附近才有；再往東就沒有這條邊，台地一路延伸進森林
	var c := -_smin(-(PLAT_ZMAX - z), -(x - PLAT_GATE_X))
	var q := _smin(_smin(a, b), c)
	return q + _detail.get_noise_2d(x * 0.6, z * 0.6) * 0.7

func _smin(a: float, b: float) -> float:
	return (a + b - sqrt((a - b) * (a - b) + PLAT_ROUND * PLAT_ROUND)) * 0.5

## 台地抬高的高度：一階一階疊上去，台面微微往外傾斜
func hill_bump(x: float, z: float) -> float:
	var q := plateau_q(x, z)
	var h := 0.0
	for t in TIERS:
		h += t[1] * sstep(t[0], t[0] + TIER_RAMP, q)
	if h > 0.5:
		h += TOP_TILT * q
	return h

## 在大穀倉裡面嗎
func in_barn(p: Vector3) -> bool:
	return barn_rect.has_point(Vector2(p.x, p.z))

## 從 from 走到 to 的下一個路點：進出大穀倉都要經過門口
func route_point(from: Vector3, to: Vector3) -> Vector3:
	var a := in_barn(from)
	var b := in_barn(to)
	if a == b:
		return to
	if not a:
		# 在外面要進去：先到門外，再進門
		if Vector2(from.x - door_out.x, from.z - door_out.z).length() > 0.7 and from.z < door_out.z - 0.4 or absf(from.x - door_out.x) > 1.2:
			return door_out
		return door_in
	# 在裡面要出去：先到門內，再出門
	if Vector2(from.x - door_in.x, from.z - door_in.z).length() > 0.7:
		return door_in
	return door_out

## 走得上去嗎：在遊玩範圍內，不在山丘的陡坡上，也不在水裡
func walkable(x: float, z: float) -> bool:
	return in_play(x, z) and hill_bump(x, z) < HILL_WALK_LIMIT and not in_water(x, z)

## 在水池的水裡（小島不算）
func in_water(x: float, z: float) -> bool:
	var d := Vector2(x, z).distance_to(POND_CENTER)
	return d > ISLAND_R + 0.35 and d < POND_R - 0.25

## 在小島上
func on_island(x: float, z: float) -> bool:
	return Vector2(x, z).distance_to(POND_CENTER) <= ISLAND_R + 0.35

## 是否在遊玩範圍內（農場 + 大門外的入口空地）
func in_play(x: float, z: float) -> bool:
	var farm := x >= FARM_MIN.x and x <= FARM_MAX.x and z >= FARM_MIN.y and z <= FARM_MAX.y
	var yard := absf(x) <= YARD_HALF and z > FARM_MAX.y and z <= YARD_MAX_Z
	return farm or yard

## 到遊玩範圍的距離（範圍內為 0）
func play_dist(x: float, z: float) -> float:
	var df := Vector2(maxf(maxf(FARM_MIN.x - x, x - FARM_MAX.x), 0.0), maxf(maxf(FARM_MIN.y - z, z - FARM_MAX.y), 0.0)).length()
	var dy := Vector2(maxf(absf(x) - YARD_HALF, 0.0), maxf(maxf(FARM_MAX.y - z, z - YARD_MAX_Z), 0.0)).length()
	return minf(df, dy)

## 把點拉回遊玩範圍內、並推離山坡
func clamp_play(p: Vector3) -> Vector3:
	var q := p
	if not in_play(q.x, q.z):
		var a := Vector3(clampf(q.x, FARM_MIN.x, FARM_MAX.x), q.y, clampf(q.z, FARM_MIN.y, FARM_MAX.y))
		var b := Vector3(clampf(q.x, -YARD_HALF, YARD_HALF), q.y, clampf(q.z, FARM_MAX.y, YARD_MAX_Z))
		q = a if Vector2(a.x - p.x, a.z - p.z).length() <= Vector2(b.x - p.x, b.z - p.z).length() else b
	# 在山丘上就順著坡往下推，直到走得上去的地方
	for i in 80:
		if hill_bump(q.x, q.z) < HILL_WALK_LIMIT:
			break
		var g := Vector2(hill_bump(q.x + 0.2, q.z) - hill_bump(q.x - 0.2, q.z), hill_bump(q.x, q.z + 0.2) - hill_bump(q.x, q.z - 0.2))
		var dir := -g.normalized() if g.length() > 0.0001 else Vector2(-1, 0)
		q = Vector3(q.x + dir.x * 0.25, q.y, q.z + dir.y * 0.25)
	return q

## 巨石滾動的阻力：台地上（高起來的地方）幾乎沒有阻力，巨石會沿著微斜的台面一路滾到邊緣再滾下去
func roll_resist(x: float, z: float) -> float:
	return 3.2 if hill_bump(x, z) < 1.0 else 0.2

## 石球可以放的地方：遊玩範圍內或山丘上
func rock_ground(x: float, z: float) -> bool:
	return in_play(x, z) or hill_bump(x, z) >= HILL_WALK_LIMIT

func _raw_height(x: float, z: float) -> float:
	var wx := x * LAYOUT_SCALE
	var wz := z * LAYOUT_SCALE
	var h := farm_height(wx, wz) / LAYOUT_SCALE
	var e := maxf(absf(x), absf(z))
	return lerpf(h, -45.0, sstep(92.0, 119.0, e))

func _road_dist(p: Vector2) -> float:
	var best := INF
	for road in ROADS:
		for i in road.size() - 1:
			var a: Vector2 = road[i]
			var b: Vector2 = road[i + 1]
			var t := clampf((p - a).dot(b - a) / (b - a).length_squared(), 0.0, 1.0)
			best = minf(best, p.distance_to(a.lerp(b, t)))
	return best

func _terrain_weights(x: float, z: float, _nrm: Vector3) -> Color:
	var w := Vector2(x, z) * LAYOUT_SCALE
	var dn := _detail.get_noise_2d(x * 0.5, z * 0.5)
	var road := 1.0 - sstep(1.0, 1.9, _road_dist(w) + dn * 0.4)
	var yard := 1.0 - sstep(4.0, 6.5, w.distance_to(YARD_CENTER) + dn * 1.5)
	var dirt := maxf(yard * (1.0 - road), sstep(0.35, 0.7, _noise.get_noise_2d(x * 2.3, z * 2.3)) * 0.55)
	var steep := sstep(0.35, 0.7, 1.0 - _nrm.y)
	return Color(road, dirt, steep, 1.0)

func _tweak_terrain_material(mat: ShaderMaterial) -> void:
	# 鮮豔一點：飽和的草綠和暖沙色（參考 PEAK）
	mat.set_shader_parameter("ground_a", Color(0.52, 0.70, 0.26))
	mat.set_shader_parameter("ground_b", Color(0.42, 0.64, 0.22))
	mat.set_shader_parameter("grassy", Color(0.36, 0.60, 0.20))
	mat.set_shader_parameter("sand_c", Color(0.95, 0.70, 0.42))
	mat.set_shader_parameter("dirt_c", Color(0.82, 0.56, 0.32))
	mat.set_shader_parameter("rock_c", Color(0.58, 0.52, 0.46))

# ---------------------------------------------------------------- 圍欄與大門

func _build_fences() -> void:
	var node := Node3D.new()
	node.name = "FarmFence"
	add_child(node)
	var wood := _toon(Color(0.66, 0.48, 0.30))
	var dark := _toon(Color(0.52, 0.37, 0.23))
	var a := FARM_MIN
	var b := FARM_MAX
	# 圍欄只在大門兩側，接到入口空地兩邊的森林
	fence_segments = [
		[Vector2(-YARD_HALF - 0.6, b.y), Vector2(-GATE_HALF, b.y)],
		[Vector2(GATE_HALF, b.y), Vector2(YARD_HALF + 0.6, b.y)],
	]
	for seg in fence_segments:
		_fence_line(node, seg[0], seg[1], wood, dark)
	# 大門：兩根高柱 + 橫樑 + 招牌
	for sx in [-1.0, 1.0]:
		var p := Vector3(sx * (GATE_HALF + 0.1), 0, b.y)
		_box(node, Vector3(0.35, 3.6, 0.35), p + Vector3(0, height_at(p.x, p.z) + 1.8, 0), dark)
	var gy := height_at(0, b.y)
	_box(node, Vector3(GATE_HALF * 2.0 + 1.2, 0.35, 0.4), Vector3(0, gy + 3.5, b.y), dark)
	_box(node, Vector3(2.6, 0.8, 0.12), Vector3(0, gy + 2.95, b.y + 0.12), _toon(Color(0.86, 0.74, 0.5)))
	var sign := Label3D.new()
	sign.text = "人類農場"
	sign.font_size = 72
	sign.pixel_size = 0.006
	sign.modulate = Color(0.32, 0.2, 0.12)
	sign.outline_size = 0
	sign.position = Vector3(0, gy + 2.95, b.y + 0.2)
	node.add_child(sign)

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

# ---------------------------------------------------------------- 建築與樹

func _place_model(parent: Node3D, path: String, pos: Vector3, yaw: float, scale: float, block_radius := 0.0) -> Node3D:
	var ps := load(path) as PackedScene
	if ps == null:
		return null
	var n := ps.instantiate() as Node3D
	n.position = Vector3(pos.x, height_at(pos.x, pos.z) - 0.05, pos.z)
	n.rotation.y = yaw
	n.scale = Vector3.ONE * scale
	parent.add_child(n)
	if block_radius > 0.0:
		obstacles.append([Vector2(pos.x, pos.z), block_radius])
	return n

func _build_buildings() -> void:
	var node := Node3D.new()
	node.name = "Buildings"
	add_child(node)
	barn_node = _place_model(node, MODEL_FARM + "BigBarn.glb", BARN_POS, 0.0, 1.3, 0.0)
	barn_node.name = "BossBarn"
	# 大穀倉的四面牆（門在南邊，正對農場大門）
	var hx := 7.73 * 1.3 * 0.5 - 0.1
	var hz := 8.22 * 1.3 * 0.5 - 0.1
	var cx := BARN_POS.x
	var cz := BARN_POS.z
	var door := 1.9
	barn_rect = Rect2(cx - hx, cz - hz, hx * 2.0, hz * 2.0)
	door_out = Vector3(cx, 0, cz + hz + 1.3)
	door_in = Vector3(cx, 0, cz + hz - 1.2)
	wall_segments = [
		[Vector2(cx - hx, cz - hz), Vector2(cx + hx, cz - hz)],   # 北
		[Vector2(cx - hx, cz - hz), Vector2(cx - hx, cz + hz)],   # 西
		[Vector2(cx + hx, cz - hz), Vector2(cx + hx, cz + hz)],   # 東
		[Vector2(cx - hx, cz + hz), Vector2(cx - door, cz + hz)], # 南（門的左邊）
		[Vector2(cx + door, cz + hz), Vector2(cx + hx, cz + hz)], # 南（門的右邊）
	]
	# 大穀倉最裡面的辦公桌（老闆站在後面）
	var bp := BOSS_POST
	var desk_y := height_at(bp.x, bp.z)
	var desk_mat := _toon(Color(0.45, 0.3, 0.2))
	# 矮一點的辦公桌，從門口看進去擋不住坐在後面的老闆
	_box(node, Vector3(2.6, 0.12, 1.0), Vector3(bp.x, desk_y + 0.85, bp.z + 1.35), desk_mat)
	for sx in [-1.0, 1.0]:
		_box(node, Vector3(0.12, 0.8, 0.9), Vector3(bp.x + sx * 1.2, desk_y + 0.4, bp.z + 1.35), desk_mat)
	_box(node, Vector3(0.5, 0.06, 0.35), Vector3(bp.x - 0.6, desk_y + 0.94, bp.z + 1.3), _toon(Color(0.95, 0.94, 0.9)))
	_box(node, Vector3(0.3, 0.2, 0.3), Vector3(bp.x + 0.7, desk_y + 1.0, bp.z + 1.3), _toon(Color(1.0, 0.82, 0.3)))   # 一袋金幣
	_build_barn_interior(node, cx, cz, hx, hz)
	# 五座水塔（骨牌）
	for i in WATER_TOWERS.size():
		var tp: Vector2 = WATER_TOWERS[i]
		var holder := Node3D.new()
		holder.name = "WaterTower%d" % i
		holder.position = Vector3(tp.x, height_at(tp.x, tp.y) - 0.05, tp.y)
		node.add_child(holder)
		var silo := (load(MODEL_FARM + "Silo.glb") as PackedScene).instantiate() as Node3D
		silo.scale = Vector3.ONE * TOWER_SCALE * 1.2
		silo.rotation.y = i * 0.8
		holder.add_child(silo)
		var r := 1.65 * TOWER_SCALE / 0.9
		obstacles.append([tp, r])
		towers.append({"node": holder, "pos": tp, "radius": r, "height": 9.07 * TOWER_SCALE * 1.2})
	_build_plateau_rocks(node)
	_build_pond(node)
	# 乾草堆
	var hay := [Vector3(-4.8, 0, 6.0), Vector3(-12.0, 0, -8.8)]
	for i in hay.size():
		_place_model(node, MODEL_FARM + "Hay.glb", hay[i], i * 0.9, 7.0, 0.7)

func _build_inner_trees() -> void:
	var node := Node3D.new()
	node.name = "InnerTrees"
	add_child(node)
	var trees := [
		["BirchTree", Vector3(-3.0, 0, -17.0), 1.6], ["AutumnTree", Vector3(15.0, 0, -18.0), 1.7],
		["BirchTree", Vector3(-14.0, 0, 10.4), 1.5], ["AutumnTree", Vector3(-7.2, 0, -1.2), 1.5],
		["BirchTree", Vector3(-5.2, 0, 18.0), 1.7], ["AutumnTree", Vector3(6.0, 0, 17.6), 1.8],
	]
	for i in trees.size():
		var t: Array = trees[i]
		_place_model(node, MODEL_NATURE + t[0] + ".glb", t[1], i * 1.3, t[2], 0.7)
	var bushes := [Vector3(-15.2, 0, 12.0), Vector3(-3.0, 0, 14.0), Vector3(3.0, 0, 14.0),
		Vector3(-15.2, 0, -18.4), Vector3(-8.0, 0, 11.6),
		Vector3(-1.6, 0, -9.6), Vector3(-0.5, 0, -14.5)]
	for i in bushes.size():
		_place_model(node, MODEL_NATURE + "BushBerries.glb", bushes[i], i * 0.7, 1.3)

func _build_pond(parent: Node3D) -> void:
	water_y = _rolling(POND_CENTER.x, POND_CENTER.y) - 0.45
	var water := MeshInstance3D.new()
	water.name = "Pond"
	var cm := CylinderMesh.new()
	cm.top_radius = POND_R - 0.05
	cm.bottom_radius = POND_R - 0.05
	cm.height = 0.04
	cm.radial_segments = 48
	water.mesh = cm
	var wm := ShaderMaterial.new()
	wm.shader = load("res://shaders/water.gdshader")
	wm.set_shader_parameter("island_radius", Vector2(1000.0, 1000.0))   # 整片都是半透明淺水
	wm.set_shader_parameter("deep", Color(0.2, 0.55, 0.72))
	wm.set_shader_parameter("light_c", Color(0.6, 0.88, 0.92))
	water.material_override = wm
	water.position = Vector3(POND_CENTER.x, water_y, POND_CENTER.y)
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(water)
	# 小島上一叢灌木
	_place_model(parent, MODEL_NATURE + "BushBerries.glb", Vector3(POND_CENTER.x + 0.5, 0, POND_CENTER.y - 0.5), 0.3, 0.9)

func _build_farm_grass() -> void:
	var spots: Array[Vector3] = []
	# 圍欄內外兩側
	for seg in fence_segments:
		var a: Vector2 = seg[0]
		var b: Vector2 = seg[1]
		var n := Vector2(-(b - a).y, (b - a).x).normalized()
		for k in int(a.distance_to(b) * 9):
			var p := a.lerp(b, _rng.randf()) + n * _rng.randfn(0.0, 0.9)
			spots.append(Vector3(p.x, p.y, _rng.randf_range(0.8, 1.3)))
	# 建築與樹腳
	for o in obstacles:
		var c: Vector2 = o[0]
		var r: float = o[1]
		for k in int(r * 14):
			var ang := _rng.randf() * TAU
			var p := c + Vector2(cos(ang), sin(ang)) * r * _rng.randf_range(0.85, 1.25)
			spots.append(Vector3(p.x, p.y, _rng.randf_range(0.9, 1.4)))
	# 草地上零星草叢（避開土路和中庭）
	for k in 2600:
		var p := Vector2(_rng.randf_range(-24.0, 24.0), _rng.randf_range(-27.0, 22.0))
		if _road_dist(p) < 2.2 or p.distance_to(YARD_CENTER) < 5.0 or play_dist(p.x, p.y) > 0.5:
			continue
		spots.append(Vector3(p.x, p.y, _rng.randf_range(0.7, 1.15)))

	# 大穀倉裡面不長草（不然會從地板穿出來）
	var inside := barn_rect.grow(0.4)
	spots.assign(spots.filter(func(sp): return not inside.has_point(Vector2(sp.x, sp.y))))
	spots.assign(spots.filter(func(sp): return Vector2(sp.x, sp.y).distance_to(POND_CENTER) > POND_R - 0.1 or Vector2(sp.x, sp.y).distance_to(POND_CENTER) < ISLAND_R - 0.1))
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

# ---------------------------------------------------------------- 森林包住遊玩範圍

func _build_farm_forest() -> void:
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
	var x := FARM_MIN.x - FOREST_BAND
	while x <= FARM_MAX.x + FOREST_BAND:
		var z := FARM_MIN.y - FOREST_BAND
		while z <= YARD_MAX_Z + FOREST_BAND:
			var px := x + r.randf_range(-0.7, 0.7)
			var pz := z + r.randf_range(-0.7, 0.7)
			var d := play_dist(px, pz)
			if d > 0.4 and d < FOREST_BAND and r.randf() < 0.93:
				var gy := height_at(px, pz)
				var h := r.randf_range(3.6, 6.2) * (1.0 + clampf(d, 0.0, 8.0) * 0.04)
				trunks.append(Transform3D(Basis(Vector3.UP, r.randf() * TAU).scaled(Vector3(1, h * 0.55, 1)), Vector3(px, gy + h * 0.27, pz)))
				var green := Color(r.randf_range(0.22, 0.36), r.randf_range(0.42, 0.56), r.randf_range(0.2, 0.3))
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

# ---------------------------------------------------------------- 角色與玩家

func _build_farm_characters() -> void:
	var chars := Node3D.new()
	chars.name = "Characters"
	chars.set_script(load("res://scripts/characters.gd"))
	add_child(chars)
	var posts: Array = []
	for r in FARMER_ROUTES:
		posts.append(r.route[0])
	posts.append(BOSS_POST)   # 第 4 個敵人是老闆
	chars.setup_multi(self, HERO_START, posts, true)

func _place_player() -> void:
	var player := get_node_or_null(player_path) as Node3D
	if player == null:
		return
	var p := Vector3(3.2, 0, 19.6)
	player.global_position = Vector3(p.x, height_at(p.x, p.z) + 3.5, p.z)
	var target := Vector3(0.0, 0.0, 1.6)
	var d := target - player.global_position
	player.rotation = Vector3(0.0, atan2(-d.x, -d.z), 0.0)
	var head := player.get_node_or_null("Head") as Node3D
	if head:
		head.rotation.x = deg_to_rad(-16.0)

## 從 origin 沿 dir 打到地面的點（給神蹟瞄準用）；沒打到回傳 null
func ray_ground(origin: Vector3, dir: Vector3, max_dist := 80.0) -> Variant:
	var step := 0.25
	var prev := origin
	var t := 0.0
	while t < max_dist:
		t += step
		var p := origin + dir * t
		if p.y <= height_at(p.x, p.z):
			# 二分逼近
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


## 台地台面上的幾顆裝飾石頭：只放在每一階的「後方」（靠近上一階斜坡腳下），
## 台面往外傾斜，石球會往前滾，所以不會被它們卡住；石頭本身不會動。
func _build_plateau_rocks(parent: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var picked: Array[Vector2] = []
	var demo := Vector2(10.4, 4.2)
	var cands: Array[Vector2] = []
	var x := 6.0
	while x < 18.0:
		var z := -0.5
		while z < 20.0:
			cands.append(Vector2(x + rng.randf_range(-0.3, 0.3), z + rng.randf_range(-0.3, 0.3)))
			z += 0.9
		x += 0.9
	# 打散順序，讓位置看起來自然
	for i in range(cands.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var tmp := cands[i]
		cands[i] = cands[j]
		cands[j] = tmp
	for c in cands:
		if picked.size() >= 7:
			break
		var q := plateau_q(c.x, c.y)
		# 第一階後段 或 第二階後段（離下一個斜坡腳 0.5~2 公尺）
		var back1 := q > 4.5 and q < 6.0
		var back2 := q > 11.5 and q < 13.0
		if not (back1 or back2):
			continue
		if c.distance_to(demo) < 3.5:
			continue
		var ok := true
		for o in picked:
			if c.distance_to(o) < 2.6:
				ok = false
				break
		if not ok:
			continue
		picked.append(c)
	for c in picked:
		var s := rng.randf_range(0.45, 0.85)
		var pos := Vector3(c.x, height_at(c.x, c.y) - 0.1 * s, c.y)
		_spawn_rock(parent, pos, Vector3(s * rng.randf_range(0.9, 1.3), s * rng.randf_range(0.6, 0.9), s * rng.randf_range(0.9, 1.3)), rng.randf() * TAU)
		obstacles.append([c, s * 0.9])
	plateau_rocks = picked


## 大穀倉內部：屋頂的黃色燈、從門口一路鋪到老闆桌前的紅地毯、左右兩側的金銀財寶
func _build_barn_interior(parent: Node3D, cx: float, cz: float, hx: float, hz: float) -> void:
	var bp := BOSS_POST
	# 穀倉地板：取裡面地形最高的地方，東西才不會被地面起伏吃掉
	var gy := -INF
	for ix in 9:
		for iz in 9:
			gy = maxf(gy, height_at(cx - hx + hx * 2.0 * ix / 8.0, cz - hz + hz * 2.0 * iz / 8.0))
	# 紅地毯（兩邊金色滾邊）
	var front := cz + hz + 0.1
	var back := bp.z + 1.95
	var mid := (front + back) * 0.5
	var length := front - back
	var carpet := _box(parent, Vector3(1.7, 0.06, length), Vector3(cx, gy + 0.04, mid), _toon(Color(0.86, 0.1, 0.12)))
	carpet.name = "RedCarpet"
	for sx in [-1.0, 1.0]:
		_box(parent, Vector3(0.12, 0.08, length), Vector3(cx + sx * 0.85, gy + 0.05, mid), _toon(Color(1.0, 0.78, 0.25)))
	# 金銀財寶堆
	var gold := _toon(Color(1.0, 0.8, 0.22))
	var gold_dark := _toon(Color(0.9, 0.62, 0.12))
	var silver := _toon(Color(0.84, 0.87, 0.93))
	var gem_r := _toon(Color(0.95, 0.2, 0.35))
	var gem_b := _toon(Color(0.25, 0.55, 1.0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	var coin := CylinderMesh.new()
	coin.top_radius = 0.16
	coin.bottom_radius = 0.16
	coin.height = 0.05
	coin.radial_segments = 10
	var gem := SphereMesh.new()
	gem.radius = 0.12
	gem.height = 0.2
	gem.radial_segments = 6
	gem.rings = 2
	var treasure := Node3D.new()
	treasure.name = "Treasure"
	parent.add_child(treasure)
	for sx in [-1.0, 1.0]:
		var wx: float = cx + sx * (hx - 0.9)
		var z := cz - hz + 1.0
		while z < cz + hz - 1.6:
			var base := Vector3(wx + rng.randf_range(-0.2, 0.2), gy, z)
			# 一座金幣山（壓扁的半球）
			var mound := MeshInstance3D.new()
			var sm := SphereMesh.new()
			var r := rng.randf_range(0.7, 1.0)
			sm.radius = r
			sm.height = r * 2.0
			sm.radial_segments = 12
			sm.rings = 6
			mound.mesh = sm
			mound.material_override = gold if rng.randf() < 0.7 else silver
			mound.position = base + Vector3(0, -r * 0.15, 0)
			mound.scale = Vector3(1.0, 0.9, 1.0)
			treasure.add_child(mound)
			# 堆成金字塔的金條／銀條
			var bar_mat := gold_dark if rng.randf() < 0.6 else silver
			var bx := base + Vector3(-sx * 0.9, 0, rng.randf_range(-0.4, 0.4))
			for layer in 3:
				for k in 3 - layer:
					var off := (k - (2 - layer) * 0.5) * 0.24
					_box(treasure, Vector3(0.2, 0.12, 0.42), bx + Vector3(off, 0.06 + layer * 0.12, 0), bar_mat)
			# 一疊一疊的金幣
			for st in 3:
				var cpos := base + Vector3(rng.randf_range(-0.9, 0.4) * sx, 0, rng.randf_range(-0.9, 0.9))
				var h := rng.randi_range(3, 9)
				for c in h:
					var ci := MeshInstance3D.new()
					ci.mesh = coin
					ci.material_override = gold if (c + st) % 4 != 0 else silver
					ci.position = cpos + Vector3(rng.randf_range(-0.02, 0.02), 0.025 + c * 0.05, rng.randf_range(-0.02, 0.02))
					treasure.add_child(ci)
			# 撒幾顆寶石在金幣山上
			for g in 3:
				var gi := MeshInstance3D.new()
				gi.mesh = gem
				gi.material_override = gem_r if g % 2 == 0 else gem_b
				var ang := rng.randf() * TAU
				gi.position = base + Vector3(cos(ang) * r * 0.45, r * 0.3, sin(ang) * r * 0.45)
				treasure.add_child(gi)
			z += rng.randf_range(2.0, 2.6)
	# 老闆左右兩側：堆得高高的金條塔，一看就知道是黃金
	var bar_hi := _toon(Color(1.0, 0.86, 0.3))
	var bar_lo := _toon(Color(0.95, 0.7, 0.16))
	var bar := BoxMesh.new()
	bar.size = Vector3(0.42, 0.16, 0.22)
	var gold_side := Node3D.new()
	gold_side.name = "BossGold"
	parent.add_child(gold_side)
	for sx in [-1.0, 1.0]:
		var gc := Vector3(bp.x + sx * 2.35, gy, bp.z - 0.2)
		# 底下一座金幣山
		var hill := MeshInstance3D.new()
		var hs := SphereMesh.new()
		hs.radius = 1.1
		hs.height = 2.2
		hs.radial_segments = 14
		hs.rings = 7
		hill.mesh = hs
		hill.material_override = gold
		hill.position = gc + Vector3(0, -0.45, 0)
		hill.scale = Vector3(1.0, 0.7, 1.0)
		gold_side.add_child(hill)
		# 金條一層一層往上疊（每層轉 90 度，越上面越少）
		var layers := 11
		for layer in layers:
			var n := maxi(1, 4 - layer / 3)
			var turned := layer % 2 == 1
			for k in n:
				var off := (k - (n - 1) * 0.5) * 0.24
				var bi := MeshInstance3D.new()
				bi.mesh = bar
				bi.material_override = bar_hi if (k + layer) % 3 != 0 else bar_lo
				var lp := Vector3(0, 0.3 + layer * 0.16, off) if not turned else Vector3(off, 0.3 + layer * 0.16, 0)
				bi.position = gc + lp
				bi.rotation.y = PI * 0.5 if not turned else 0.0
				gold_side.add_child(bi)
		# 塔頂放一個金元寶
		var top := MeshInstance3D.new()
		var ts := SphereMesh.new()
		ts.radius = 0.24
		ts.height = 0.3
		top.mesh = ts
		top.material_override = bar_hi
		top.position = gc + Vector3(0, 0.3 + layers * 0.16 + 0.1, 0)
		top.scale = Vector3(1.4, 1.0, 0.9)
		gold_side.add_child(top)
	# 屋頂下的黃色燈（掛在穀倉上，穀倉垮掉時跟著一起倒）
	var lamp_parent: Node3D = barn_node if barn_node else parent
	for lz in [cz - hz + 3.0, cz + 0.8]:
		var lamp := MeshInstance3D.new()
		var lm := SphereMesh.new()
		lm.radius = 0.22
		lm.height = 0.44
		lamp.mesh = lm
		var lmat := StandardMaterial3D.new()
		lmat.albedo_color = Color(1.0, 0.85, 0.45)
		lmat.emission_enabled = true
		lmat.emission = Color(1.0, 0.78, 0.35)
		lmat.emission_energy_multiplier = 3.0
		lamp.material_override = lmat
		lamp_parent.add_child(lamp)
		lamp.global_position = Vector3(cx, gy + 4.6, lz)
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.8, 0.42)
		light.light_energy = 2.6
		light.omni_range = 8.5
		light.omni_attenuation = 0.8
		light.shadow_enabled = false
		lamp_parent.add_child(light)
		light.global_position = Vector3(cx, gy + 4.3, lz)
