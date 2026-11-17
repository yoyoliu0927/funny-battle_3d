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
var PLATFORM_C := Vector2(31.0, -12.0)   # 指揮官高台（只有 2-3 有，在東邊的第二個院子）
const PLATFORM_R := 3.6
const PLATFORM_H := 5.0
## 2-3 東邊的第二個院子（橢圓），和要塞之間隔一道牆，南邊留一條通道
const R2_C := Vector2(27.0, -5.0)
const R2_RX := 13.0
const R2_RZ := 14.0
const R2_NATURE_FROM := deg_to_rad(-160.0)   # 第二個院子北邊是天然山坡
const R2_NATURE_TO := deg_to_rad(-20.0)
const DIVIDER_FROM := deg_to_rad(-30.0)      # 要塞東邊這一段弧變成隔牆（2-3）
const DIVIDER_TO := deg_to_rad(4.4)
const PASS_A := Vector2(11.0, 1.0)           # 兩個院子之間的通道（線段）
const PASS_B := Vector2(21.0, -0.5)
const PASS_HALF_W := 2.2
const PASS_L := Vector3(13.5, 0, 0.0)        # 通道兩頭的路點（左院／右院）
const PASS_R := Vector3(19.5, 0, -0.5)
## 每個小關的擺設：炮塔、我方大砲（aim = 一開始砲口對著哪裡）、寶箱、守衛路線
const STAGES := {
	1: {"towers": [Vector2(0.0, -4.0)],
		"cannons": [{"pos": Vector2(-9.0, 3.0), "aim": Vector2(0.0, -4.0)}],
		"chests": [],
		"routes": [
			{"route": [Vector3(-8.0, 0, -3.5), Vector3(-5.5, 0, -7.0)], "loop": false, "pause": 1.4},
			{"route": [Vector3(5.5, 0, -7.0), Vector3(8.0, 0, -3.5)], "loop": false, "pause": 1.4}]},
	2: {"towers": [Vector2(3.0, -11.0), Vector2(0.0, -3.0), Vector2(-10.0, -2.0)],
		"cannons": [{"pos": Vector2(7.0, 5.0), "aim": Vector2(0.0, -3.0)}],
		"chests": [Vector2(-3.0, -8.0), Vector2(11.0, -2.0)],
		"routes": []},
	3: {"towers": [Vector2(7.0, -8.0), Vector2(33.0, 3.0)],
		"cannons": [{"pos": Vector2(-11.0, -6.0), "aim": Vector2(7.0, -8.0)},
			{"pos": Vector2(6.0, 5.0), "aim": Vector2(31.0, -12.0)}],
		"chests": [Vector2(-2.0, -11.0), Vector2(37.0, -2.0)],
		"routes": [
			{"route": [Vector3(-8.0, 0, 2.0), Vector3(-4.0, 0, 4.5)], "loop": false, "pause": 1.3},
			{"route": [Vector3(19.0, 0, -6.0), Vector3(20.0, 0, 0.0)], "loop": false, "pause": 1.2}]},
}
const FUSE_TIME := 4.0            # 引信從點燃到發射的秒數（= 瞄準時間）
const FORT_HERO_START := Vector3(-5.0, 0.0, 15.5)
const M_CASTLE := "res://assets/castle/"
const M_PIRATE := "res://assets/pirate/"
const M_TD := "res://assets/tdkit/"

var stage := 3                    # 現在是第幾個小關（1~3）
var east := false                 # 有沒有東邊的第二個院子（2-3）
var stage_name := ""              # 進場鏡頭和介面上顯示的小關名稱
var stage_goal := ""

## 這個小關有哪幾組守衛
func stage_routes(s: int) -> Array:
	return STAGES[s].routes

var gate_pos := Vector2.ZERO     # 城門中心（牆線上）
var gate_dir := Vector2.ZERO      # 從要塞中心指向城門（往外）
var fort_towers: Array = []       # [{node, pos, radius, height}]
var cannon_node: Node3D           # 現在作用中的那門大砲（家豪鑽進哪一門就是哪一門）
var fuse_pts: Array[Vector3] = []   # 引信的點（世界座標），第 0 點在砲尾的點火孔
var fuse_segs: Array[MeshInstance3D] = []
var fuse_spark: Node3D
var cannons: Array = []           # 每一門大砲 {node, segs, spark, yaw0}
var cannon_nodes: Array = []
var chests: Array = []            # 寶箱 {pos, node, yaw}
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
	if Engine.has_meta("fort_stage"):   # 地圖上選的小關（或在要塞裡按 F1~F3 切換）
		stage = clampi(int(Engine.get_meta("fort_stage")), 1, 3)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--fortstage="):
			stage = clampi(int(a.substr(12)), 1, 3)
	farmer_routes = stage_routes(stage)
	east = stage >= 3
	stage_name = ["", "2-1 學大砲", "2-2 三座炮塔", "2-3 指揮官的院子"][stage]
	stage_goal = ["", "目標：佔領炮塔、打倒兩個農夫", "目標：拿下三座炮塔（撞倒或佔領）", "目標：拿下炮塔、打倒農夫和指揮官"][stage]
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
	if east:
		_build_platform()
	_build_props()
	_build_chests()
	_build_fort_grass()
	_build_farm_forest()
	_build_fort_characters()
	_place_player()

# ---------------------------------------------------------------- 形狀

func _ellipse(theta: float) -> Vector2:
	return FORT_C + Vector2(FORT_RX * cos(theta), FORT_RZ * sin(theta))

func _gate_theta() -> float:
	return acos(clampf(GATE_X / FORT_RX, -1.0, 1.0))   # sin > 0：南邊

## 橢圓的「半徑比例」：中心 0、牆線 1（2-3 是兩個院子取比較近的那個）
func fort_e(x: float, z: float) -> float:
	var e := e1(x, z)
	return minf(e, e2(x, z)) if east else e

func e1(x: float, z: float) -> float:
	return Vector2((x - FORT_C.x) / FORT_RX, (z - FORT_C.y) / FORT_RZ).length()

func e2(x: float, z: float) -> float:
	return Vector2((x - R2_C.x) / R2_RX, (z - R2_C.y) / R2_RZ).length()

func _ellipse2(theta: float) -> Vector2:
	return R2_C + Vector2(R2_RX * cos(theta), R2_RZ * sin(theta))

## 在第二個院子（隔牆東邊）嗎
func in_east(x: float, z: float) -> bool:
	return east and e1(x, z) >= 1.0 and e2(x, z) < 1.0

func _pass_dist(p: Vector2) -> float:
	var t := clampf((p - PASS_A).dot(PASS_B - PASS_A) / (PASS_B - PASS_A).length_squared(), 0.0, 1.0)
	return p.distance_to(PASS_A.lerp(PASS_B, t))

## 離城門通道（從門外 6m 穿到門內 6m 的線段）多遠
func _gate_dist(p: Vector2) -> float:
	var a := gate_pos + gate_dir * 6.0
	var b := gate_pos - gate_dir * 6.0
	var t := clampf((p - a).dot(b - a) / (b - a).length_squared(), 0.0, 1.0)
	return p.distance_to(a.lerp(b, t))

## 這一點屬於天然山坡的程度（0 = 城牆那邊、1 = 山坡那邊）
func nature_w(x: float, z: float) -> float:
	if east and e2(x, z) < e1(x, z):
		var th2 := atan2((z - R2_C.y) / R2_RZ, (x - R2_C.x) / R2_RX)
		return _soft_range(th2, R2_NATURE_FROM, R2_NATURE_TO)
	var th := atan2((z - FORT_C.y) / FORT_RZ, (x - FORT_C.x) / FORT_RX)
	return _soft_range(th, NATURE_FROM, _nature_to())

## 2-3 要塞東邊那段山坡改成隔牆，山坡只到隔牆北端
func _nature_to() -> float:
	return DIVIDER_FROM if east else NATURE_TO

func _soft_range(th: float, from: float, to: float) -> float:
	var mid := (from + to) * 0.5
	var half := (to - from) * 0.5
	var off := absf(wrapf(th - mid, -PI, PI))
	return 1.0 - sstep(half - NATURE_SOFT, half + NATURE_SOFT, off)

func _theta_is_nature(th: float) -> bool:
	var mid := (NATURE_FROM + _nature_to()) * 0.5
	return absf(wrapf(th - mid, -PI, PI)) < (_nature_to() - NATURE_FROM) * 0.5

func _theta2_is_nature(th: float) -> bool:
	var mid := (R2_NATURE_FROM + R2_NATURE_TO) * 0.5
	return absf(wrapf(th - mid, -PI, PI)) < (R2_NATURE_TO - R2_NATURE_FROM) * 0.5

## 城牆腳的小土堤／天然山坡 + 指揮官高台的高度（走不上去的部分）
func hill_bump(x: float, z: float) -> float:
	var e := fort_e(x, z)
	var berm := BERM_H * sstep(0.86, 0.97, e) * (1.0 - sstep(1.06, 1.2, e))
	var ridge := RIDGE_H * sstep(RIDGE_E0, RIDGE_E1, e) + 2.0 * sstep(1.05, 1.5, e)
	ridge += _detail.get_noise_2d(x * 0.35, z * 0.35) * 0.8 * sstep(0.7, 1.0, e)
	var rim := lerpf(berm, ridge, nature_w(x, z))
	rim *= sstep(GATE_HALF_W + 0.4, GATE_HALF_W + 2.2, _gate_dist(Vector2(x, z)))   # 城門通道挖平
	if not east:
		return rim
	rim *= sstep(PASS_HALF_W + 0.4, PASS_HALF_W + 2.2, _pass_dist(Vector2(x, z)))   # 兩個院子之間的通道挖平
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
	if a and b and east:
		return _pass_route(from, to)
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

## 2-3：兩個院子之間要走南邊的通道
func _pass_route(from: Vector3, to: Vector3) -> Vector3:
	var sa := in_east(from.x, from.z)
	var sb := in_east(to.x, to.z)
	if sa == sb:
		return to
	var near_l := Vector2(from.x - PASS_L.x, from.z - PASS_L.z).length() < 1.2 or (from.x > 13.0 and from.z > -2.5 and from.z < 3.0)
	var near_r := Vector2(from.x - PASS_R.x, from.z - PASS_R.z).length() < 1.2 or (from.x < 19.5 and from.z > -2.5 and from.z < 3.0)
	if not sa:
		return PASS_R if near_l else PASS_L
	return PASS_L if near_r else PASS_R

## 把點拉回遊玩範圍內（城牆裡或門外空地），並推離土坡和高台
func clamp_play(p: Vector3) -> Vector3:
	var q := p
	if not in_play(q.x, q.z):
		# 拉回橢圓內
		var d := Vector2(q.x - FORT_C.x, q.z - FORT_C.y)
		var e := e1(q.x, q.z)
		var a := FORT_C + d / maxf(e, 0.001) * 0.97
		if east:
			var d2 := Vector2(q.x - R2_C.x, q.z - R2_C.y)
			var a2 := R2_C + d2 / maxf(e2(q.x, q.z), 0.001) * 0.97
			if a2.distance_to(Vector2(p.x, p.z)) < a.distance_to(Vector2(p.x, p.z)):
				a = a2
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
	chars.setup_multi(self, FORT_HERO_START, posts, stage >= 3)

func _forest_rect() -> Rect2:
	var r := Rect2(FORT_C.x - FORT_RX - 9.0, FORT_C.y - FORT_RZ - 9.0, FORT_RX * 2.0 + 18.0, FORT_RZ * 2.0 + 30.0)
	if east:
		r = r.merge(Rect2(R2_C.x - R2_RX - 9.0, R2_C.y - R2_RZ - 9.0, R2_RX * 2.0 + 18.0, R2_RZ * 2.0 + 18.0))
	return r

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
		var divider := false
		if east and e2(p.x, p.y) < 1.0:
			# 伸進第二個院子的這段：北半段是隔牆，南半段空出來當通道
			var off := wrapf(th, -PI, PI)
			if off < DIVIDER_FROM or off > DIVIDER_TO:
				continue
			divider = true
		var end_cap := _theta_is_nature(TAU * (i + 1.5) / n) or _theta_is_nature(TAU * (i - 0.5) / n) or divider
		_wall_piece(node, p, tan, seg_len, _ellipse(TAU * i / n), _ellipse(TAU * (i + 1) / n), i % 5 == 0 or end_cap)
	if not east:
		return
	# 第二個院子：北邊是山坡，其他蓋牆；和要塞重疊的地方不蓋
	for i in n:
		var th := TAU * (i + 0.5) / n
		var p := _ellipse2(th)
		if e1(p.x, p.y) < 1.0 or _theta2_is_nature(th):
			continue
		var tan := Vector2(-R2_RX * sin(th), R2_RZ * cos(th))
		var seg_len := tan.length() * TAU / n
		var cap := i % 5 == 0 or _theta2_is_nature(TAU * (i + 1.5) / n) or _theta2_is_nature(TAU * (i - 0.5) / n)
		_wall_piece(node, p, tan, seg_len, _ellipse2(TAU * i / n), _ellipse2(TAU * (i + 1) / n), cap)

func _wall_piece(node: Node3D, p: Vector2, tan: Vector2, seg_len: float, a: Vector2, b: Vector2, pillar: bool) -> void:
	var w := _model(M_CASTLE + "wall.glb")
	if w == null:
		return
	w.position = Vector3(p.x, _wall_base(p), p.y)
	w.rotation.y = atan2(-tan.y, tan.x)
	w.scale = Vector3(seg_len * 1.12, WALL_H / 1.31, WALL_T)
	node.add_child(w)
	wall_segments.append([a, b])
	# 每隔幾段立一根柱子
	if pillar:
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
	var list: Array = STAGES[stage].towers
	for i in list.size():
		var tp: Vector2 = list[i]
		var holder := Node3D.new()
		holder.name = "CannonTower%s" % "ABCDEFG"[i]
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
		var to_c := (R2_C if in_east(tp.x, tp.y) else FORT_C) - tp
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
	var list: Array = STAGES[stage].cannons
	for i in list.size():
		var c: Dictionary = list[i]
		var cp: Vector2 = c.pos
		var d: Vector2 = c.aim - cp
		var yaw := atan2(d.x, d.y)
		fuse_segs = []
		cannon_node = _place_model(node, M_PIRATE + "cannon.glb", Vector3(cp.x, 0, cp.y), yaw, CANNON_SCALE, 1.6)
		cannon_node.name = "BigCannon%d" % (i + 1)
		_build_fuse(node)
		cannons.append({"node": cannon_node, "segs": fuse_segs, "spark": fuse_spark, "yaw0": yaw})
		cannon_nodes.append(cannon_node)
		_place_fuse()
	select_cannon(0)

## 換成第 i 門大砲（之後 cannon_muzzle() 等介面都是指這一門）
func select_cannon(i: int) -> void:
	var c: Dictionary = cannons[i]
	cannon_node = c.node
	fuse_segs = c.segs
	fuse_spark = c.spark
	_place_fuse()

func cannon_count() -> int:
	return cannons.size()

## 第 i 門大砲的砲口前方地面
func cannon_bait_spot_of(i: int) -> Vector3:
	var keep := 0
	for k in cannons.size():
		if cannons[k].node == cannon_node:
			keep = k
	select_cannon(i)
	var p := cannon_bait_spot()
	select_cannon(keep)
	return p

func _build_fuse(node: Node3D) -> void:
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
	for i in cannons.size():
		select_cannon(i)
		cannon_node.rotation.y = cannons[i].yaw0
		_place_fuse()
		set_fuse(-1.0)
	select_cannon(0)

## 落在指揮官高台上嗎
func on_boss_platform(p: Vector3) -> bool:
	return east and Vector2(p.x, p.z).distance_to(PLATFORM_C) < PLATFORM_R + 0.4

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
	big.rotation.y = atan2(R2_C.x - c.x, R2_C.y - c.y)
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

# ---------------------------------------------------------------- 寶箱

## 家豪走到寶箱旁邊就會打開（戰鬥那邊判斷：補滿血、神蹟冷卻清空）
func _build_chests() -> void:
	var node := Node3D.new()
	node.name = "Chests"
	add_child(node)
	for cp in STAGES[stage].chests:
		var to_c: Vector2 = (R2_C if in_east(cp.x, cp.y) else FORT_C) - cp
		var yaw := atan2(to_c.x, to_c.y)
		var ch := _place_model(node, M_PIRATE + "chest.glb", Vector3(cp.x, 0, cp.y), yaw, 1.6, 0.6)
		chests.append({"pos": cp, "node": ch, "yaw": yaw})

# ---------------------------------------------------------------- 雜物

func _build_props() -> void:
	var node := Node3D.new()
	node.name = "Props"
	add_child(node)
	# 中庭的木箱、砲彈堆
	var crates := [Vector3(-3.5, 0, 2.5), Vector3(-2.6, 0, 3.4), Vector3(3.0, 0, -6.0), Vector3(-7.0, 0, -7.5)]
	if east:
		crates += [Vector3(24.0, 0, 4.0), Vector3(24.8, 0, 4.9), Vector3(35.0, 0, -6.0)]
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
	var fr := _forest_rect()
	for k in (3000 if not east else 4800):
		var p := Vector2(_rng.randf_range(fr.position.x + 2.0, fr.end.x - 2.0), _rng.randf_range(-22.0, 22.0))
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
	if east and "bounds_max" in player:
		player.bounds_max.x = 46.0
	var p := Vector3(-2.0, 0, 19.0)
	player.global_position = Vector3(p.x, height_at(p.x, p.z) + 6.0, p.z)
	var target := Vector3(0.0, 0.0, -3.0)
	var d := target - player.global_position
	player.rotation = Vector3(0.0, atan2(-d.x, -d.z), 0.0)
	var head := player.get_node_or_null("Head") as Node3D
	if head:
		head.rotation.x = deg_to_rad(-20.0)

# ---------------------------------------------------------------- 進場鏡頭

## 進場的三個鏡頭（battle.gd 播）：入口推進 → 西南邊俯瞰 → 東北邊俯瞰
func intro_shots() -> Array:
	var c := Vector3(12.0, 0.0, -5.0) if east else Vector3(0.0, 0.0, -3.0)
	var hint: String = ["", "提示：在大砲口前撒飼料，把家豪射上炮塔", "提示：三座炮塔各有不同的拆法", "提示：兩個院子靠南邊的通道相連；指揮官的高台要用大砲射上去"][stage]
	var g := Vector3(gate_pos.x, 0, gate_pos.y)
	var out := Vector3(gate_dir.x, 0, gate_dir.y)
	var sw := Vector3(-26, 24, 20) if not east else Vector3(-22, 32, 26)
	var ne := Vector3(22, 26, -24) if not east else Vector3(46, 32, -30)
	return [
		{"from": g + out * 14.0 + Vector3(-1.5, 2.4, 0), "to": g + out * 5.5 + Vector3(-0.5, 2.8, 0),
			"look_from": g + Vector3(0, 3.5, 0), "look_to": g - out * 4.0 + Vector3(0, 2.0, 0),
			"dur": 3.0, "title": stage_name, "body": "人類要塞"},
		{"from": sw, "to": sw + Vector3(8, 2, 4),
			"look_from": c, "look_to": c + Vector3(1, 0, 0),
			"dur": 3.2, "title": stage_name, "body": stage_goal},
		{"from": ne, "to": ne + Vector3(-10, 2, -4),
			"look_from": c, "look_to": c + Vector3(-1, 0, 0),
			"dur": 3.2, "title": stage_name, "body": hint},
	]
