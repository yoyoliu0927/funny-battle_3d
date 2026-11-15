extends "res://scripts/farm_builder.gd"
## 第二關：人類要塞（場地草稿 / blockout）
##
## 沿用農場的地形、草、森林、材質，只換掉地形高度和擺設；戰鬥用 battle.gd。
##
## 版面（世界座標，公尺；-Z 是北邊/要塞深處）
##   要塞      橢圓形，中心 (0, -3)，東西半徑 17、南北半徑 13
##   城牆      西邊和南邊（含城門）是人類蓋的城牆：牆上放不了巨石
##   天然山坡  北邊到東邊是天然的山坡，往中庭傾斜：巨石放在坡上會滾下來
##   城門      南牆偏左 (-4, 9.6)，家豪從門外 (-5, 15.5) 出發
##   炮塔 A    北邊靠牆 (-1, -11)：北坡的巨石滾下來會撞到它
##   炮塔 B    東邊中庭 (6.5, -0.5)：東坡的巨石往西滾會撞到它
##             兩座塔頂都有砲手，家豪進射程就瞄準開砲（地上先出紅圈）；
##             南面梯子腳下撒飼料，家豪會爬上去把砲手踢下去，炮塔改打人類
##   大砲      西邊 (-9.5, -1)，砲口朝東；砲口前撒飼料，家豪鑽進去卡住，
##             引信燒完（或左鍵）就射向準心；射上指揮官高台能撞翻指揮官
##   指揮官高台 東北角 (10.5, -9)，比地面高 5 公尺，走不上去，只能被大砲射上去

const FORT_C := Vector2(0.0, -3.0)
const FORT_RX := 17.0
const FORT_RZ := 13.0
const GATE_X := -4.0
const GATE_HALF_W := 2.4          # 城門洞半寬
const BERM_H := 0.7               # 城牆腳下的小土堤
const RIDGE_H := 6.0              # 天然山坡的稜線高度
const RIDGE_E0 := 0.6             # 山坡從橢圓的這個比例開始升起……
const RIDGE_E1 := 1.02            # ……到這裡升到稜線
const RIDGE_CREST := 0.14         # 稜線往外多留這麼寬（橢圓比例）不長樹，放巨石用
## 天然山坡的範圍（橢圓上的角度，0 = 正東、-90° = 正北）；其他部分是城牆
const NATURE_FROM := deg_to_rad(-118.0)
const NATURE_TO := deg_to_rad(28.0)
const NATURE_SOFT := 0.2          # 城牆和山坡交界的過渡（弧度）
const WALL_SEGMENTS := 40
const WALL_H := 4.2               # 城牆高度
const WALL_T := 2.0               # 城牆厚度
const OUTER_YARD := Rect2(-9.5, 9.0, 11.0, 9.5)   # 城門外的空地（x, z, w, h）
const PLATFORM_C := Vector2(10.5, -9.0)
const PLATFORM_R := 3.6
const PLATFORM_H := 5.0
const TOWER_A := Vector2(-1.0, -11.0)
const TOWER_B := Vector2(6.5, -0.5)
const CANNON_POS := Vector2(-9.5, -1.0)
const FUSE_TIME := 4.0            # 引信從點燃到發射的秒數（= 瞄準時間）
const FORT_HERO_START := Vector3(-5.0, 0.0, 15.5)
## 守衛的巡邏路線（格式同第一關）
const FORT_ROUTES := [
	# 城門內側：左右來回
	{"route": [Vector3(-7.0, 0, 4.0), Vector3(-1.5, 0, 5.0)], "loop": false, "pause": 1.5},
	# 中庭：繞一圈，會經過炮塔 B 前面
	{"route": [Vector3(-3.0, 0, -1.0), Vector3(0.5, 0, -6.5), Vector3(4.5, 0, -4.0), Vector3(3.5, 0, 2.0)], "loop": true, "pause": 0.9},
	# 西北角：在大砲和炮塔 A 之間來回
	{"route": [Vector3(-7.0, 0, -4.5), Vector3(-4.0, 0, -8.5), Vector3(1.5, 0, -8.0)], "loop": false, "pause": 1.2},
]
const M_CASTLE := "res://assets/castle/"
const M_PIRATE := "res://assets/pirate/"
const M_TD := "res://assets/tdkit/"

var stage := 3                    # 現在是第幾個小關（1~3）

## 這個小關有哪幾組守衛（2-1 只留中庭那一個，路過炮塔 B 前面）
func stage_routes(s: int) -> Array:
	if s <= 1:
		return [FORT_ROUTES[1]]
	return FORT_ROUTES

var gate_pos := Vector2.ZERO     # 城門中心（牆線上）
var gate_dir := Vector2.ZERO      # 從要塞中心指向城門（往外）
var fort_towers: Array = []       # [{node, pos, radius, height}]
var cannon_node: Node3D
var fuse_pts: Array[Vector3] = []   # 引信的點（世界座標），第 0 點在砲尾的點火孔
var fuse_segs: Array[MeshInstance3D] = []
var fuse_spark: Node3D
const CANNON_SCALE := 1.9
const CANNON_YAW0 := PI * 0.5     # 一開始砲口朝東

func _ready() -> void:
	var th := _gate_theta()
	gate_pos = _ellipse(th)
	gate_dir = (gate_pos - FORT_C).normalized()
	hero_start = FORT_HERO_START
	# 小關：2-1 只有一個農夫；2-2 三個農夫；2-3 三個農夫加指揮官（共用同一張場地）
	# 平常照存檔從還沒過的小關開始；--fortstage=N 可指定（自動測試用）
	stage = clampi(preload("res://scripts/progress.gd").fort_stages() + 1, 1, 3)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--fortstage="):
			stage = clampi(int(a.substr(12)), 1, 3)
	farmer_routes = stage_routes(stage)
	demo_rock_start = null      # 這關沒有示範石頭
	tower_chain = false         # 炮塔不是骨牌：被巨石撞到就順著巨石的方向倒
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
	_build_walls()
	_build_gate()
	_build_towers()
	_build_cannon()
	_build_platform()
	_build_props()
	_build_fort_grass()
	_build_farm_forest()
	_build_fort_characters()
	_place_player()

# ---------------------------------------------------------------- 形狀

func _ellipse(theta: float) -> Vector2:
	return FORT_C + Vector2(FORT_RX * cos(theta), FORT_RZ * sin(theta))

func _gate_theta() -> float:
	return acos(clampf(GATE_X / FORT_RX, -1.0, 1.0))   # sin > 0：南邊

## 橢圓的「半徑比例」：中心 0、牆線 1
func fort_e(x: float, z: float) -> float:
	return Vector2((x - FORT_C.x) / FORT_RX, (z - FORT_C.y) / FORT_RZ).length()

## 離城門通道（從門外 6m 穿到門內 6m 的線段）多遠
func _gate_dist(p: Vector2) -> float:
	var a := gate_pos + gate_dir * 6.0
	var b := gate_pos - gate_dir * 6.0
	var t := clampf((p - a).dot(b - a) / (b - a).length_squared(), 0.0, 1.0)
	return p.distance_to(a.lerp(b, t))

## 這一點屬於天然山坡的程度（0 = 城牆那邊、1 = 山坡那邊）
func nature_w(x: float, z: float) -> float:
	var th := atan2((z - FORT_C.y) / FORT_RZ, (x - FORT_C.x) / FORT_RX)
	var mid := (NATURE_FROM + NATURE_TO) * 0.5
	var half := (NATURE_TO - NATURE_FROM) * 0.5
	var off := absf(wrapf(th - mid, -PI, PI))
	return 1.0 - sstep(half - NATURE_SOFT, half + NATURE_SOFT, off)

func _theta_is_nature(th: float) -> bool:
	var mid := (NATURE_FROM + NATURE_TO) * 0.5
	return absf(wrapf(th - mid, -PI, PI)) < (NATURE_TO - NATURE_FROM) * 0.5

## 城牆腳的小土堤／天然山坡 + 指揮官高台的高度（走不上去的部分）
func hill_bump(x: float, z: float) -> float:
	var e := fort_e(x, z)
	var berm := BERM_H * sstep(0.86, 0.97, e) * (1.0 - sstep(1.06, 1.2, e))
	var ridge := RIDGE_H * sstep(RIDGE_E0, RIDGE_E1, e) + 2.0 * sstep(1.05, 1.5, e)
	ridge += _detail.get_noise_2d(x * 0.35, z * 0.35) * 0.8 * sstep(0.7, 1.0, e)
	var rim := lerpf(berm, ridge, nature_w(x, z))
	rim *= sstep(GATE_HALF_W + 0.4, GATE_HALF_W + 2.2, _gate_dist(Vector2(x, z)))   # 城門通道挖平
	var d := Vector2(x, z).distance_to(PLATFORM_C) + _detail.get_noise_2d(x * 0.8, z * 0.8) * 0.3
	var plat := PLATFORM_H * (1.0 - sstep(PLATFORM_R, PLATFORM_R + 1.1, d))
	return maxf(rim, plat)

func farm_height(x: float, z: float) -> float:
	var h := _rolling(x, z) * 0.35 + _noise.get_noise_2d(x * 2.0, z * 2.0) * 0.06
	var pb := hill_bump(x, z)
	h *= lerpf(1.0, 0.15, sstep(0.3, 2.0, pb))
	return h + pb

func in_play(x: float, z: float) -> bool:
	return fort_e(x, z) < 1.0 or OUTER_YARD.has_point(Vector2(x, z))

func play_dist(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var e := fort_e(x, z)
	var de := maxf(e - 1.0 - RIDGE_CREST * nature_w(x, z), 0.0) * minf(FORT_RX, FORT_RZ)
	var r := OUTER_YARD
	var dy := Vector2(maxf(maxf(r.position.x - x, x - r.end.x), 0.0), maxf(maxf(r.position.y - z, z - r.end.y), 0.0)).length()
	return minf(de, dy)

## 這關沒有水池
func in_water(_x: float, _z: float) -> bool:
	return false

func on_island(_x: float, _z: float) -> bool:
	return false

## 巨石可以放／滾的地方：中庭、門外空地、天然山坡（一直到稜線）；城牆上不行
func rock_ground(x: float, z: float) -> bool:
	var e := fort_e(x, z)
	if nature_w(x, z) > 0.5:
		return e < 1.0 + RIDGE_CREST
	return e < 0.93 or OUTER_YARD.has_point(Vector2(x, z))

func _inside(p: Vector3) -> bool:
	return fort_e(p.x, p.z) < 0.98

## 從 from 走到 to 的下一個路點：進出城牆都要經過城門
func route_point(from: Vector3, to: Vector3) -> Vector3:
	var a := _inside(from)
	var b := _inside(to)
	if a == b:
		return to
	var g_in := gate_pos - gate_dir * 2.6
	var g_out := gate_pos + gate_dir * 2.2
	var gin := Vector3(g_in.x, 0, g_in.y)
	var gout := Vector3(g_out.x, 0, g_out.y)
	var rel := Vector2(from.x, from.z) - gate_pos
	var lateral := absf(rel.dot(Vector2(-gate_dir.y, gate_dir.x)))   # 離門洞中線多遠
	var depth := rel.dot(gate_dir)                                  # 正 = 門外、負 = 門內
	if not a:
		# 在外面要進去：還沒對準門洞就先走到門外，對準了就穿進去
		return gout if lateral > 1.0 or depth > 2.4 else gin
	return gin if lateral > 1.0 or depth < -2.8 else gout

## 把點拉回遊玩範圍內（城牆裡或門外空地），並推離土坡和高台
func clamp_play(p: Vector3) -> Vector3:
	var q := p
	if not in_play(q.x, q.z):
		# 拉回橢圓內
		var d := Vector2(q.x - FORT_C.x, q.z - FORT_C.y)
		var e := fort_e(q.x, q.z)
		var a := FORT_C + d / maxf(e, 0.001) * 0.97
		var r := OUTER_YARD
		var b := Vector2(clampf(q.x, r.position.x, r.end.x), clampf(q.z, r.position.y, r.end.y))
		var c := a if a.distance_to(Vector2(p.x, p.z)) <= b.distance_to(Vector2(p.x, p.z)) else b
		q = Vector3(c.x, q.y, c.y)
	for i in 80:
		if hill_bump(q.x, q.z) < HILL_WALK_LIMIT:
			break
		var g := Vector2(hill_bump(q.x + 0.2, q.z) - hill_bump(q.x - 0.2, q.z), hill_bump(q.x, q.z + 0.2) - hill_bump(q.x, q.z - 0.2))
		var dir := -g.normalized() if g.length() > 0.0001 else (FORT_C - Vector2(q.x, q.z)).normalized()
		q = Vector3(q.x + dir.x * 0.25, q.y, q.z + dir.y * 0.25)
	return q

func _build_fort_characters() -> void:
	var chars := Node3D.new()
	chars.name = "Characters"
	chars.set_script(load("res://scripts/characters.gd"))
	add_child(chars)
	var posts: Array = []
	for r in farmer_routes:
		posts.append(r.route[0])
	if stage >= 3:
		posts.append(boss_post)   # 最後一個是指揮官（暫時沿用第一關老闆的模型和行為）
	chars.setup_multi(self, FORT_HERO_START, posts, true)

func _forest_rect() -> Rect2:
	return Rect2(FORT_C.x - FORT_RX - 9.0, FORT_C.y - FORT_RZ - 9.0, FORT_RX * 2.0 + 18.0, FORT_RZ * 2.0 + 30.0)

func _road_dist(p: Vector2) -> float:
	# 從門外一路到中庭的土路
	var a := Vector2(-5.0, 18.0)
	var b := gate_pos
	var c := FORT_C
	var best := INF
	for seg in [[a, b], [b, c]]:
		var s0: Vector2 = seg[0]
		var s1: Vector2 = seg[1]
		var t := clampf((p - s0).dot(s1 - s0) / (s1 - s0).length_squared(), 0.0, 1.0)
		best = minf(best, p.distance_to(s0.lerp(s1, t)))
	return best

func _terrain_weights(x: float, z: float, _nrm: Vector3) -> Color:
	var w := Vector2(x, z) * LAYOUT_SCALE
	var dn := _detail.get_noise_2d(x * 0.5, z * 0.5)
	var road := 1.0 - sstep(1.0, 1.9, _road_dist(w) + dn * 0.4)
	# 要塞中庭是踩硬的泥土地
	var yard := 1.0 - sstep(0.45, 0.62, fort_e(w.x, w.y) + dn * 0.05)
	var dirt := maxf(yard * (1.0 - road) * 0.85, sstep(0.35, 0.7, _noise.get_noise_2d(x * 2.3, z * 2.3)) * 0.4)
	var steep := sstep(0.35, 0.7, 1.0 - _nrm.y)
	return Color(road, dirt, steep, 1.0)

# ---------------------------------------------------------------- 城牆與城門

func _model(path: String) -> Node3D:
	var ps := load(path) as PackedScene
	return ps.instantiate() as Node3D if ps else null

func _build_walls() -> void:
	var node := Node3D.new()
	node.name = "FortWalls"
	add_child(node)
	var th_g := _gate_theta()
	var n := WALL_SEGMENTS
	for i in n:
		var th := TAU * (i + 0.5) / n
		var p := _ellipse(th)
		var tan := Vector2(-FORT_RX * sin(th), FORT_RZ * cos(th))
		var seg_len := tan.length() * TAU / n
		# 城門那一段空出來；天然山坡那一段不蓋牆
		if absf(wrapf(th - th_g, -PI, PI)) * tan.length() < GATE_HALF_W + seg_len * 0.5:
			continue
		if _theta_is_nature(th):
			continue
		var w := _model(M_CASTLE + "wall.glb")
		if w == null:
			continue
		w.position = Vector3(p.x, _wall_base(p), p.y)
		w.rotation.y = atan2(-tan.y, tan.x)
		w.scale = Vector3(seg_len * 1.12, WALL_H / 1.31, WALL_T)
		node.add_child(w)
		wall_segments.append([_ellipse(TAU * i / n), _ellipse(TAU * (i + 1) / n)])
		# 每隔幾段立一根柱子
		var end_cap := _theta_is_nature(TAU * (i + 1.5) / n) or _theta_is_nature(TAU * (i - 0.5) / n)
		if i % 5 == 0 or end_cap:
			var pl := _model(M_CASTLE + "wall-pillar.glb")
			pl.position = w.position
			pl.rotation.y = w.rotation.y
			pl.scale = Vector3(2.4, (WALL_H + 0.6) / 1.31, 2.4)
			node.add_child(pl)

## 牆腳最低點（牆放在土坡頂上，不要懸空）
func _wall_base(p: Vector2) -> float:
	var lo := INF
	for k in 6:
		var a := TAU * k / 6.0
		var q := p + Vector2(cos(a), sin(a)) * 1.0
		lo = minf(lo, height_at(q.x, q.y))
	return lo - 0.1

func _build_gate() -> void:
	var node := Node3D.new()
	node.name = "FortGate"
	add_child(node)
	var side := Vector2(-gate_dir.y, gate_dir.x)
	var yaw := atan2(-side.y, side.x)
	# 城門兩側的塔
	for s in [-1.0, 1.0]:
		var p: Vector2 = gate_pos + side * s * (GATE_HALF_W + 1.4)
		var t := _model(M_CASTLE + "tower-base.glb")
		var gy := height_at(p.x, p.y) - 0.1
		t.position = Vector3(p.x, gy, p.y)
		t.rotation.y = yaw
		t.scale = Vector3(2.8, (WALL_H + 1.5) / 1.31, 2.8)
		node.add_child(t)
		var top := _model(M_CASTLE + "tower-top.glb")
		top.position = t.position + Vector3(0, WALL_H + 1.5, 0)
		top.rotation.y = yaw
		top.scale = Vector3(2.8, 2.8, 2.8)
		node.add_child(top)
		var fl := _model(M_CASTLE + "flag-banner-long.glb")
		fl.position = top.position + Vector3(0, 0.3, 0)
		fl.scale = Vector3.ONE * 1.4
		fl.rotation.y = yaw
		node.add_child(fl)
		obstacles.append([p, 1.6])
	# 門洞上方的拱
	var gy := height_at(gate_pos.x, gate_pos.y)
	var arch := _box(node, Vector3(GATE_HALF_W * 2.0 + 0.8, 1.4, WALL_T), Vector3(gate_pos.x, gy + WALL_H + 0.9, gate_pos.y), _toon(Color(0.62, 0.6, 0.58)), Vector3(0, yaw, 0))
	arch.name = "GateArch"
	# 吊起來的鐵柵門（半開）
	var mg := _model(M_CASTLE + "metal-gate.glb")
	mg.position = Vector3(gate_pos.x, gy + WALL_H - 0.6, gate_pos.y)
	mg.rotation.y = yaw + PI * 0.5
	mg.scale = Vector3(2.0, 2.2, (GATE_HALF_W * 2.0) / 0.7)
	node.add_child(mg)
	var sign := Label3D.new()
	sign.text = "人類要塞"
	sign.font_size = 72
	sign.pixel_size = 0.007
	sign.modulate = Color(0.25, 0.2, 0.16)
	sign.outline_size = 0
	sign.position = Vector3(gate_pos.x, gy + WALL_H + 0.9, gate_pos.y) + Vector3(gate_dir.x, 0, gate_dir.y) * (WALL_T * 0.5 + 0.05)
	sign.rotation.y = atan2(gate_dir.x, gate_dir.y)
	node.add_child(sign)

# ---------------------------------------------------------------- 炮塔

func _build_towers() -> void:
	var node := Node3D.new()
	node.name = "CannonTowers"
	add_child(node)
	for i in 2:
		var tp: Vector2 = [TOWER_A, TOWER_B][i]
		var holder := Node3D.new()
		holder.name = "CannonTower%s" % ["A", "B"][i]
		holder.position = Vector3(tp.x, height_at(tp.x, tp.y) - 0.1, tp.y)
		node.add_child(holder)
		var s := 2.6
		var y := 0.0
		for part in ["tower-square-base", "tower-square-mid-windows", "tower-square-mid", "tower-square-top"]:
			var m := _model(M_CASTLE + part + ".glb")
			m.position.y = y
			m.scale = Vector3.ONE * s
			holder.add_child(m)
			y += (0.3 if part.ends_with("top") else 1.01) * s
		# 塔頂的大砲（朝向中庭）
		var gun := _model(M_TD + "weapon-cannon.glb")
		gun.position.y = y - 0.3 * s + 0.4
		gun.scale = Vector3.ONE * 3.2
		var to_c := FORT_C - tp
		gun.rotation.y = atan2(to_c.x, to_c.y)
		holder.add_child(gun)
		# 塔頂的砲手（家豪爬上去會把他踢下去）
		var gunner := _make_gunner()
		gunner.position = Vector3(-0.6, y - 0.3 * s + 0.3, -0.5)
		gunner.rotation.y = gun.rotation.y
		holder.add_child(gunner)
		# 南面的梯子（家豪可以爬）
		_ladder(holder, Vector3(0, 0, s * 0.5 + 0.12), y - 0.3 * s)
		var r := s * 0.62
		obstacles.append([tp, r])
		fort_towers.append({"node": holder, "pos": tp, "radius": r, "height": y,
			"gun": gun, "gunner": gunner,
			"ladder": Vector2(tp.x, tp.y + s * 0.5 + 0.75),   # 梯子腳下（飼料撒這裡，家豪就會爬上去）
			"top_y": y - 0.3 * s + 0.3})
	towers = fort_towers   # 給戰鬥用：巨石撞得倒

## 塔頂砲手：戴深色頭盔的小兵（簡單幾何）
func _make_gunner() -> Node3D:
	var g := Node3D.new()
	g.name = "Gunner"
	var coat := _toon(Color(0.55, 0.2, 0.18))
	var skin := _toon(Color(0.96, 0.78, 0.62))
	var dark := _toon(Color(0.2, 0.2, 0.24))
	_box(g, Vector3(0.5, 0.7, 0.32), Vector3(0, 0.75, 0), coat)
	_box(g, Vector3(0.36, 0.36, 0.36), Vector3(0, 1.3, 0), skin)
	_box(g, Vector3(0.44, 0.14, 0.44), Vector3(0, 1.52, 0), dark)
	for sx in [-0.13, 0.13]:
		_box(g, Vector3(0.16, 0.42, 0.18), Vector3(sx, 0.21, 0), dark)
	return g

func _ladder(parent: Node3D, base: Vector3, h: float) -> void:
	var wood := _toon(Color(0.6, 0.42, 0.25))
	for sx in [-0.38, 0.38]:
		_box(parent, Vector3(0.1, h, 0.1), base + Vector3(sx, h * 0.5, 0), wood)
	var rungs := int(h / 0.42)
	for k in rungs:
		_box(parent, Vector3(0.76, 0.07, 0.08), base + Vector3(0, 0.3 + k * 0.42, 0), wood)

# ---------------------------------------------------------------- 大砲與引信

func _build_cannon() -> void:
	var node := Node3D.new()
	node.name = "Cannon"
	add_child(node)
	cannon_node = _place_model(node, M_PIRATE + "cannon.glb", Vector3(CANNON_POS.x, 0, CANNON_POS.y), CANNON_YAW0, CANNON_SCALE, 1.6)
	cannon_node.name = "BigCannon"
	# 砲尾的點火孔往後上方翹出一小段彎彎的引信（跟著砲身轉）
	var fuse_mat := _toon(Color(0.3, 0.24, 0.16))
	for k in 10:
		var seg := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.035
		cm.bottom_radius = 0.035
		cm.height = 0.1
		cm.radial_segments = 6
		cm.rings = 1
		seg.mesh = cm
		seg.material_override = fuse_mat
		node.add_child(seg)
		fuse_segs.append(seg)
	# 火花：一顆會閃的小亮球＋一盞小燈，平常藏起來
	fuse_spark = Node3D.new()
	fuse_spark.name = "FuseSpark"
	fuse_spark.visible = false
	var ball := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.11
	sm.height = 0.22
	ball.mesh = sm
	var em := StandardMaterial3D.new()
	em.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	em.albedo_color = Color(1.0, 0.85, 0.35)
	ball.material_override = em
	fuse_spark.add_child(ball)
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.7, 0.3)
	lamp.light_energy = 1.6
	lamp.omni_range = 2.2
	fuse_spark.add_child(lamp)
	node.add_child(fuse_spark)
	_place_fuse()

## 依砲身目前的方向重新擺引信
func _place_fuse() -> void:
	var back := -cannon_dir()
	var side := Vector3.UP.cross(back).normalized()
	var hole := cannon_node.position + Vector3(0, 1.72, 0) + back * 0.75
	fuse_pts.clear()
	for k in 11:
		var t := k / 10.0
		fuse_pts.append(hole + back * (t * 0.7) + Vector3.UP * (sin(t * PI * 0.8) * 0.45) + side * (sin(t * TAU) * 0.12))
	for k in fuse_segs.size():
		var a := fuse_pts[k]
		var b := fuse_pts[k + 1]
		var seg := fuse_segs[k]
		(seg.mesh as CylinderMesh).height = a.distance_to(b) + 0.02
		seg.position = (a + b) * 0.5
		seg.basis = _basis_along(b - a)

## 讓 Y 軸對準 d 的 Basis（圓柱是沿 Y 軸）
func _basis_along(d: Vector3) -> Basis:
	var y := d.normalized()
	var x := y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
	return Basis(x, y, x.cross(y)).orthonormalized()

# ---- 給戰鬥用的大砲介面（battle.gd 用 has_method("cannon_muzzle") 判斷這關有沒有大砲）

## 砲口中心（世界座標）
func cannon_muzzle() -> Vector3:
	return cannon_node.position + Vector3(0, 0.78 * CANNON_SCALE, 0) + cannon_dir() * (1.4 * CANNON_SCALE)

## 砲口朝向（水平）
func cannon_dir() -> Vector3:
	var d := cannon_node.global_basis.z
	d.y = 0.0
	return d.normalized()

## 砲口前方地面（飼料放在這附近，家豪就會鑽進砲管）
func cannon_bait_spot() -> Vector3:
	var m := cannon_muzzle() + cannon_dir() * 0.5
	return Vector3(m.x, height_at(m.x, m.z), m.z)

## 把砲口轉向 target（只轉水平方向）
func aim_cannon(target: Vector3) -> void:
	var d := target - cannon_node.position
	if Vector2(d.x, d.z).length() < 0.5:
		return
	cannon_node.rotation.y = atan2(d.x, d.z)
	_place_fuse()

## 引信燒到哪：1 = 剛點燃（完整），0 = 燒完；< 0 = 沒點燃（引信完整、沒有火花）
func set_fuse(f: float) -> void:
	if fuse_segs.is_empty():
		return
	if f < 0.0:
		for seg in fuse_segs:
			seg.visible = true
		fuse_spark.visible = false
		return
	var x := clampf(f, 0.0, 1.0) * (fuse_pts.size() - 1)
	var i := mini(int(x), fuse_pts.size() - 2)
	fuse_spark.visible = f > 0.0
	fuse_spark.position = fuse_pts[i].lerp(fuse_pts[i + 1], x - i)
	fuse_spark.scale = Vector3.ONE * (1.0 + sin(Time.get_ticks_msec() * 0.05) * 0.25 + randf() * 0.2)
	for k in fuse_segs.size():
		fuse_segs[k].visible = k < ceili(x)

func reset_cannon() -> void:
	cannon_node.rotation.y = CANNON_YAW0
	_place_fuse()
	set_fuse(-1.0)

## 落在指揮官高台上嗎
func on_boss_platform(p: Vector3) -> bool:
	return Vector2(p.x, p.z).distance_to(PLATFORM_C) < PLATFORM_R + 0.4

# ---------------------------------------------------------------- 指揮官高台

func _build_platform() -> void:
	var node := Node3D.new()
	node.name = "CommanderPlatform"
	add_child(node)
	var c := PLATFORM_C
	var y := height_at(c.x, c.y)
	# 指揮官自己的大砲（第二階段推出來）、旗子、帳篷頂
	var big := _model(M_PIRATE + "cannon-mobile.glb")
	big.position = Vector3(c.x - 1.0, y - 0.05, c.y + 0.6)
	big.rotation.y = atan2(FORT_C.x - c.x, FORT_C.y - c.y)
	big.scale = Vector3.ONE * 1.5
	node.add_child(big)
	var fl := _model(M_CASTLE + "flag-wide.glb")
	fl.position = Vector3(c.x + 1.6, y - 0.05, c.y - 1.4)
	fl.scale = Vector3.ONE * 3.0
	node.add_child(fl)
	for k in 3:
		var cr := _model(M_PIRATE + "crate.glb")
		cr.position = Vector3(c.x + 1.8 - k * 0.2, y - 0.05 + k * 0.0, c.y + 0.8 + k * 1.1)
		cr.rotation.y = k * 0.6
		cr.scale = Vector3.ONE * 0.9
		node.add_child(cr)
	# 指揮官的位置（之後放 Boss）
	var post := _box(node, Vector3(0.9, 0.08, 0.9), Vector3(c.x + 0.4, y + 0.04, c.y - 0.4), _toon(Color(0.8, 0.2, 0.18)))
	post.name = "BossPost"
	boss_post = Vector3(c.x + 0.4, 0, c.y - 0.4)

# ---------------------------------------------------------------- 雜物

func _build_props() -> void:
	var node := Node3D.new()
	node.name = "Props"
	add_child(node)
	# 中庭的木箱、砲彈堆
	var crates := [Vector3(-3.5, 0, 2.5), Vector3(-2.6, 0, 3.4), Vector3(3.0, 0, -6.0), Vector3(-7.0, 0, -7.5)]
	for i in crates.size():
		_place_model(node, M_PIRATE + "crate.glb", crates[i], i * 0.9, 1.0, 0.7)
	var balls := [Vector3(-8.2, 0, 0.6), Vector3(-8.0, 0, 1.1), Vector3(-8.6, 0, 1.0)]
	for b in balls:
		_place_model(node, M_PIRATE + "cannon-ball.glb", b, 0.0, 1.4)
	# 攻城武器當裝飾（人類的軍械庫）
	_place_model(node, M_CASTLE + "siege-catapult.glb", Vector3(-4.5, 0, -10.5), 0.5, 1.8, 1.6)
	_place_model(node, M_CASTLE + "siege-ballista.glb", Vector3(2.8, 0, 4.2), -0.6, 1.6, 1.0)

func _build_fort_grass() -> void:
	var spots: Array[Vector3] = []
	for o in obstacles:
		var c: Vector2 = o[0]
		var r: float = o[1]
		for k in int(r * 12):
			var ang := _rng.randf() * TAU
			var p := c + Vector2(cos(ang), sin(ang)) * r * _rng.randf_range(0.9, 1.3)
			spots.append(Vector3(p.x, p.y, _rng.randf_range(0.8, 1.3)))
	for k in 3000:
		var p := Vector2(_rng.randf_range(-24.0, 24.0), _rng.randf_range(-22.0, 22.0))
		var e := fort_e(p.x, p.y)
		# 中庭踩硬了不長草；土坡、牆外、門外比較多
		if _road_dist(p) < 2.0 or (e < 0.55 and _rng.randf() < 0.85) or play_dist(p.x, p.y) > 0.5:
			continue
		if absf(e - 1.0) < 0.07:   # 牆底下不要長
			continue
		spots.append(Vector3(p.x, p.y, _rng.randf_range(0.7, 1.15)))
	_spawn_grass(spots)

# ---------------------------------------------------------------- 玩家

func _place_player() -> void:
	var player := get_node_or_null(player_path) as Node3D
	if player == null:
		return
	var p := Vector3(-2.0, 0, 19.0)
	player.global_position = Vector3(p.x, height_at(p.x, p.z) + 6.0, p.z)
	var target := Vector3(0.0, 0.0, -3.0)
	var d := target - player.global_position
	player.rotation = Vector3(0.0, atan2(-d.x, -d.z), 0.0)
	var head := player.get_node_or_null("Head") as Node3D
	if head:
		head.rotation.x = deg_to_rad(-20.0)
