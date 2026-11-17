extends "res://levels/liuchiyu/oil_world.gd"
## 整座島：三個小關都在同一座島上，只是每一小關的遊玩範圍在島上不同的地方。
##
## 島的樣子（俯視，上面是北 = -Z）：圓圓的一座島，
##   左邊一大塊圓形的岩石高原 = 第三小關（比樹還高）
##   右上的低地 = 第二小關　右下的低地 = 第一小關，中間隔著一小片樹林和一道柵欄
##   第二小關的西邊有一道石階，切進岩壁一路爬到高原上。
##
## 各小關的 world.gd 只要在 _configure() 最前面呼叫 use_zone(第幾小關)，
## 其他座標照舊以「自己那一關的中心是 (0, 0)」來寫，這裡會把整座島搬到對的位置。

## 三個小關的空地（島座標），樹不會長進去
const ZONES := [
	Rect2(31.0, 7.0, 24.0, 26.0),       # 第一小關（右下）
	Rect2(30.0, -31.0, 26.0, 26.0),     # 第二小關（右上）
	Rect2(-12.0, -12.0, 26.0, 26.0),    # 第三小關（左邊高原上）
]
## 每個小關的 (0, 0) 在島座標的哪裡
const ZONE_ORIGIN := [Vector2(43.0, 19.0), Vector2(43.0, -19.0), Vector2(0.0, 0.0)]
## 每個小關的擺設（座標以那一小關自己的 (0, 0) 為準）。自己那一關的會擋路，別關的只是遠遠看得到
const ZONE_PROPS := [
	[],        # 第一小關：盆地裡是風車和滾石（見 _build_windmill()、stage_1/battle.gd）
	[],        # 第二小關：原本穀倉的位置改成一個不規則的淺水池（見 ZONE_POOLS）
	[],        # 第三小關：東邊一個小湖（見 ZONE_POOLS），瀑布從湖裡流下去
]
## 第三顆星星在第三小關那個小湖中間的島上（見 ZONE_POOLS、stage_3/battle.gd）
## 每個小關的水池（同樣以那一小關自己的 (0, 0) 為準）
const ZONE_PONDS := [[], [], []]
## 每個小關的淺水池（同樣以那一小關自己的 (0, 0) 為準）：只到腳踝，誰都可以走進去，不會淹死。
## 站在裡面的時候被雷劈到會被電（見 stage_2/battle.gd）
## center 是水池中心、r 是平均半徑；實際的岸邊是不規則的（見 _pool_r()）
## isle 是池子中間小島的平均半徑（0 = 沒有島）
const ZONE_POOLS := [
	[],
	# 第二小關：場上五灘小水灘（大小、形狀都不一樣），分散在農夫巡邏會踩到的地方（踩進去的時候用雷劈水灘，他就被電倒）
	[
		{"center": Vector2(2.0, 1.5), "r": 2.0, "ph": 0.0}, {"center": Vector2(4.5, -7.5), "r": 2.4, "ph": 1.3},
		{"center": Vector2(6.5, 5.0), "r": 1.7, "ph": 2.6}, {"center": Vector2(-5.0, -7.2), "r": 2.1, "ph": 3.9},
		{"center": Vector2(9.0, -2.0), "r": 1.6, "ph": 5.2},
	],
	# 第三小關：高原東邊（靠第一、二小關那一側）的小湖，中間有個小島（第三顆星星在上面）；瀑布從這個湖流下去
	[{"center": Vector2(10.5, 1.0), "r": 6.4, "isle": 1.7}],
]
## 第二小關中間這一圈不長一般的樹（只留戰局自己種的枯樹）；圈外、靠島邊的地方照常長樹，把場地圍起來。
## 中心、半徑（島座標）
const BARE_C := Vector2(43.0, -19.0)
const BARE_R := 17.5
const BARE_KEEP := 62         # 最外圈每 100 個可以長樹的位置留幾棵
const BARRIER_SHADER := preload("res://levels/liuchiyu/shaders/oil_barrier.gdshader")
## 小關之間的柵欄（島座標的起點、終點）：第一↔第二小關改用河隔開，第二↔第三小關擋在石階腳下
const SEALS := [
	[],        # 第一↔第二小關：沿著河中線立在水面上（位置在 _seal_points() 算）
	[Vector2(30.6, -20.6), Vector2(31.4, -13.4)],
]
const FENCE_FLOAT := 0.7      # 柵欄離地多高
const FENCE_HEIGHT := 2.2     # 柵欄本身多高
## 河：從高原東側（第三小關外面的山坡頂）流出來，在岩壁變成瀑布衝下去，
## 再彎彎曲曲地往東流進海裡，剛好把第一、第二小關隔開。
const RIVER_SHADER := preload("res://levels/liuchiyu/shaders/oil_river.gdshader")
const RIVER_X0 := 16.2        # 源頭：第三小關那個小湖的東岸（湖水從這裡流出來）
const RIVER_LIP := 20.6       # 瀑布口（高原的邊緣）
const RIVER_FOOT := 28.6      # 瀑布底下的水潭
const RIVER_Z := 1.0          # 河的中線大概在哪（z）
const RIVER_W := 3.6          # 低地那一段河多寬
const RIVER_BEND := 1.8       # 左右彎多大
const RIVER_THICK := 1.6        # 瀑布那幾段的水有多厚（兩側和底下也有水面）
const RIVER_DEPTH := 0.95     # 水有多深（河床到水面）
## 第一小關的盆地：圓形的碗，中間低、四周一圈比較高的平台（滾石停在平台上）。中心是那一小關座標的 (0, 1)
const BASIN_C := Vector2(43.0, 20.0)
const BASIN_FLOOR_R := 5.0      # 碗底的半徑
const BASIN_RIM_R := 10.0       # 斜坡到這裡爬完，外面是一圈平台
const BASIN_SHELF_R := 11.2     # 滾石停在平台上的這個半徑
const BASIN_DEPTH := 2.6        # 平台比碗底高多少
## 第一小關的風車（那一小關的座標）：很大一座，立在盆地西南邊的平台外側（離第二小關比較遠的那一側），葉片朝著盆地中間
const MILL_POS := Vector2(-9.5, 10.5)
const MILL_SCALE := 2.3
## 火山：在高原東南邊（第三小關旁邊的山坡上），一座冒煙的圓錐，火山口裡是岩漿
const LAVA_SHADER := preload("res://levels/liuchiyu/shaders/oil_lava.gdshader")
const VOLCANO_C := Vector2(-19.5, 11.0)      # 高原西邊偏南、靠海（離第一、二小關最遠；從石階走上來看是在右前方）
const VOLCANO_R := 8.0          # 山腳的半徑
const VOLCANO_PAD := 4.0        # 山腳外面還有幾公尺平地，之後才是懸崖（島在火山這邊往海裡多凸出一塊）
const VOLCANO_H := 12.0         # 比周圍高多少
const CRATER_R := 2.0           # 火山口的半徑
## 第二小關的枯樹林（那一小關的座標）和高度。戰局在第二小關自己種、自己管；
## 在別的小關這裡會照樣種出來（只是外觀），這樣從哪一關看過去島都是完整的
const GROVE_TREES := [
	# 除了第 GROVE_BRIDGE 棵（水池邊、當橋的那一棵），其他每一棵離小島都超過「樹高 + 小島半徑」，
	# 怎麼倒都碰不到小島，才不會出現「明明搭到了卻走不上去」的樣子
	# 場地上的枯樹離石階腳下的守門員都超過一棵樹的長度：倒下來碰不到他們，
	# 玩家一看就知道只能用崖壁上那一棵
	Vector3(0.5, 0, 6.5), Vector3(9.5, 0, 7.5), Vector3(-4.0, 0, -10.5), Vector3(19.5, 0, -4.0),
	Vector3(0.5, 0, -3.5), Vector3(6.5, 0, 11.0),
]
const GROVE_H := 12.0
const GROVE_BRIDGE := 3        # 第幾棵是東邊海岸上、可以倒向外海礁石當橋的那一棵（樣子跟其他枯樹一樣）
## 第二小關東邊外海的一塊大礁石（那一小關的座標），第二顆星星在上面。
## 離海岸那棵枯樹 11 公尺多：樹要剛好朝它倒，樹梢才搭得上去
const STAR_ROCK := Vector2(30.8, -4.0)
const STAR_ROCK_R := 3.4       # 礁石多寬（半徑）
const STAR_ROCK_OK := 2.3      # 樹梢落在離礁石中心這麼近以內才算搭上
## 第二小關石階腳下站著兩個守門員；旁邊的懸崖壁上側著長出一棵枯樹，斜斜地伸在他們頭上
## （用雷可以把它劈下來砸守門員）。都是那一小關的座標
const GATE_GUARDS := [Vector3(-11.5, 0, 0.6), Vector3(-11.5, 0, 3.4)]
const GATE_ROOT := Vector2(-20.5, 8.0)     # 樹根插在崖壁的哪裡
const GATE_TREE_H := 14.0
const GATE_LEAN := 0.96                    # 還長在崖壁上的時候，樹幹從直立往外倒幾弧度（約 55 度）
## 第一小關的滾石：一開始在哪（那一小關的座標，東南邊的平台上）、多大
const ROCK_HOME := Vector2(8.624, 8.168)
const ROCK_RADIUS := 1.7
## 河邊的枯樹（島座標，在第一小關這一岸）：朝河的方向吹風就會倒下去變成橋
const BRIDGE_X := 46.0
const BRIDGE_TREE_H := 11.0
## 鏡頭可以飛出島外多遠
const FLY_MARGIN := 30.0
const ZONE_FLY := 10.0         # 玩家可以飛出這一小關的場地多遠（水平方向）
## 玩家最遠可以飛到哪（這一小關的座標，x / z）。預設不另外限制；有柵欄的方向填柵欄的位置
var fly_min := Vector2(-INF, -INF)
var fly_max := Vector2(INF, INF)
## 每個小關鏡頭一開始在哪（那一小關的座標 x, z）；附近不長樹
const CAM_HOMES := [Vector2(5.0, 18.0), Vector2(4.0, 17.0), Vector2(-2.0, 16.5)]
## 高原：圓形，中心、半徑、高度（一般的樹 11～16 公尺，高原要比樹高）
const PLATEAU_C := Vector2(1.0, 1.0)
const PLATEAU_R := 26.0
const PLATEAU_H := 15.0
const PLATEAU_STEPS := 4.0      # 岩壁分成幾層岩階
## 高原東側的山坡（第三小關讓巨石滾下來用）
const HILL_X := -13.0        # 高原西邊的山坡從這裡開始往西隆起（火山就在這片山坡上；場地在它東邊）
## 石階：從第二小關西邊的 STAIR_A（低地）斜斜切進岩壁，爬到高原上的 STAIR_B
const STAIR_A := Vector2(31.0, -17.0)
const STAIR_B := Vector2(6.0, -20.5)
const STAIR_W := 3.6
const STAIR_STEPS := 44
const STAIR_DEPTH := 9.0        # 每一階的石塊往下有多深（要深到插進地裡）
## 島的外框（島座標）
const ISLE_MIN := Vector2(-45.0, -45.0)
const ISLE_MAX := Vector2(70.0, 46.0)

var stage_index := 3
var _off := Vector2.ZERO        # 島的原點在這一小關的座標裡的位置
var _barrier_mat: ShaderMaterial        # 通往下一小關的那一道柵欄（過關後會打開）

## 小關的 _configure() 最前面呼叫：把島搬到對的位置，並帶入這一關的擺設和水池
func use_zone(n: int) -> void:
	stage_index = n
	_off = -ZONE_ORIGIN[n - 1]
	props = ZONE_PROPS[n - 1].duplicate(true)
	ponds = ZONE_PONDS[n - 1].duplicate(true)

## 這個位置（這一小關的座標）是不是在第 n 小關的空地裡
func in_zone(n: int, x: float, z: float) -> bool:
	return (ZONES[n - 1] as Rect2).has_point(_isl(x, z))

## 這一小關的座標 → 島座標
func _isl(x: float, z: float) -> Vector2:
	return Vector2(x, z) - _off

## 河的中線在這個 x 的 z（低地那一段才開始彎）
func _river_z(x: float) -> float:
	return RIVER_Z + RIVER_BEND * sstep(RIVER_FOOT, RIVER_FOOT + 6.0, x) * sin((x - RIVER_FOOT) * 0.21)

## 離河的中線多遠（還沒到源頭的地方算很遠）
func _river_d(p: Vector2) -> float:
	if p.x < RIVER_X0 - 1.0:
		return 1e6
	return absf(p.y - _river_z(p.x))

## 低地那一段的河床高度：一路往海慢慢降，河才不會倒著流
func _river_bed(x: float) -> float:
	return lerpf(-1.7, -2.9, clampf((x - RIVER_FOOT) / 36.0, 0.0, 1.0))

## 低地那一段的水面高度（比兩岸低一截，看得到河岸）
func _river_water(x: float) -> float:
	return _river_bed(x) + RIVER_DEPTH

func _rock_ok(x: float, z: float) -> bool:
	var p := _isl(x, z)
	if p.distance_to(VOLCANO_C) < VOLCANO_R + 1.0:
		return false        # 火山的山坡上不放一般的石頭（山腳自己有一圈火山岩）
	return _river_d(p) > RIVER_W * 0.5 + 2.4       # 河口不要被石頭堵住

## 石階上的座標：x = 沿著石階走了多少（0 = 階梯腳，1 = 階梯頂），y = 離石階中線多遠（公尺）
func _stair_ts(p: Vector2) -> Vector2:
	var ab := STAIR_B - STAIR_A
	var t := (p - STAIR_A).dot(ab) / ab.length_squared()
	var side := absf((p - STAIR_A).dot(Vector2(-ab.y, ab.x).normalized()))
	return Vector2(t, side)

func _on_stairs(p: Vector2, margin := 0.0) -> bool:
	var ts := _stair_ts(p)
	var m := margin / STAIR_A.distance_to(STAIR_B)
	return ts.y < STAIR_W * 0.5 + margin and ts.x > -0.04 - m and ts.x < 1.06 + m

## 0 = 低地，1 = 高原上面。中間的岩壁是一層一層的岩階；石階那一條是從岩壁切進去的斜坡
func _plateau_mask(p: Vector2) -> float:
	var sd := p.distance_to(PLATEAU_C) - PLATEAU_R + _noise.get_noise_2d(p.x * 1.3 + 9.0, p.y * 1.3) * 1.6
	# 火山底下的高原往外多凸出一塊（一個伸向海邊的岬角），整座火山才會完整站在平地上，
	# 不會一半掛在懸崖的階梯上、岩漿流到一半斷掉
	# （sd <= -5.5 才是完整的高原頂，所以要再減 5.5：火山山腳外面還留 VOLCANO_PAD 公尺的平地）
	sd = minf(sd, p.distance_to(VOLCANO_C) - (VOLCANO_R + VOLCANO_PAD) - 5.5)
	var m := 1.0 - sstep(-5.5, 1.5, sd)
	if m > 0.0 and m < 1.0:
		var st := m * PLATEAU_STEPS
		var fl := floorf(st)
		m = (fl + smoothstep(0.0, 0.45, st - fl)) / PLATEAU_STEPS
	var ts := _stair_ts(p)
	if ts.x > -0.04 and ts.x < 1.2 and ts.y < STAIR_W * 0.5 + 1.4:
		# 石階的斜坡蓋過岩壁（兩側 1.4 公尺內慢慢接回岩壁）
		var w := 1.0 - sstep(STAIR_W * 0.5, STAIR_W * 0.5 + 1.4, ts.y)
		# 整條石階底下的地面就是這個斜坡：岩壁比它高的地方挖下去，比它低的地方墊起來（石階才不會懸空）
		m = lerpf(m, clampf(ts.x, 0.0, 1.0), w)
	return m

# ---------------------------------------------------------------- 覆寫 oil_world 的形狀

## 原本微微起伏的地面（島座標），還沒加上盆地、高原、河、水池這些
func _base_h(p: Vector2) -> float:
	var h := (_noise.get_noise_2d(p.x * 1.1 + 40.0, p.y * 1.1) * 1.9 + _noise.get_noise_2d(p.x * 2.6, p.y * 2.6 + 17.0) * 0.45) * hill_amount * 0.7
	return h + _noise.get_noise_2d(p.x * 2.0, p.y * 2.0) * 0.08

func _land_h(x: float, z: float) -> float:
	var p := _isl(x, z)
	var h := _base_h(p)
	# 每一小關的水池都挖下去（不管現在在哪一關，島都長一樣）
	for k in ZONE_PONDS.size():
		for pond in ZONE_PONDS[k]:
			var c: Vector2 = pond.center + ZONE_ORIGIN[k]
			var r: float = pond.r
			var isl: float = pond.get("island", 0.0)
			var pd := p.distance_to(c)
			var basin := 1.0 - sstep(r - 1.2, r + 0.3, pd)
			if isl > 0.0:
				basin *= sstep(isl - 0.2, isl + 0.9, pd)
			h -= 1.5 * basin
	# 山坡只在第三小關那一段；靠北邊石階上來的地方保持平的
	# 淺水池：整平、稍微凹下去一點
	for k in ZONE_POOLS.size():
		for pool in ZONE_POOLS[k]:
			var pc: Vector2 = pool.center + ZONE_ORIGIN[k]
			var pr := _pool_r(float(pool.r), p - pc, float(pool.get("ph", 0.0)))
			# 池子裡整平成同一個高度（比池中心原本的地面低一點），岸邊外面一小段慢慢接回原本的地面；
			# 不整平的話地面的起伏會高過水面，水只露出一小塊
			h = lerpf(h, _base_h(pc) - 0.45, 1.0 - sstep(pr - 0.3, pr + 1.6, p.distance_to(pc)))
			# 中間的小島：高出水面一點
			var isle: float = pool.get("isle", 0.0)
			if isle > 0.0:
				var ir := _isle_r(isle, p - pc)
				h = lerpf(h, _base_h(pc) + 0.12, 1.0 - sstep(ir - 0.1, ir + 0.7, p.distance_to(pc)))
	# 第一小關的盆地：碗底 → 斜坡 → 一圈平台，再往外慢慢接回原本的地面
	var br := p.distance_to(BASIN_C)
	if br < BASIN_SHELF_R + 5.0:
		var bowl := -1.7 + BASIN_DEPTH * sstep(BASIN_FLOOR_R, BASIN_RIM_R, br)
		h = lerpf(h * 0.25 + bowl, h, sstep(BASIN_SHELF_R + 1.2, BASIN_SHELF_R + 5.0, br))
	var rd := _river_d(p)
	if rd < RIVER_W * 0.5 + 2.6:
		# 低地的河道：挖成一條平滑往海降的河床，兩岸慢慢接回原本的地面
		var k := (1.0 - sstep(RIVER_W * 0.5 - 0.2, RIVER_W * 0.5 + 2.3, rd)) * sstep(RIVER_FOOT - 3.0, RIVER_FOOT + 1.0, p.x)
		h = lerpf(h, _river_bed(p.x), k)
	h += _plateau_mask(p) * (PLATEAU_H + (1.0 - sstep(HILL_X - 6.0, HILL_X, p.x)) * 4.0 * sstep(-15.5, -12.0, p.y))
	# 火山：圓錐，頂上削平再挖一個火山口
	var vd := p.distance_to(VOLCANO_C)
	if vd < VOLCANO_R:
		var cone := minf(VOLCANO_H * (1.0 - vd / VOLCANO_R), VOLCANO_H * (1.0 - CRATER_R / VOLCANO_R))
		cone -= 1.7 * (1.0 - sstep(0.4, CRATER_R, vd))
		h += cone * sstep(0.0, 0.5, _plateau_mask(p))
	if rd < 2.4 and p.x < RIVER_FOOT:
		# 小湖流出來的小溪和瀑布：沿路把地面挖到水面底下（不然水會被地面蓋住，看起來像從土裡冒出來）。
		# 小溪那一段挖成跟湖底一樣高的溝；到了高原邊緣，照著瀑布往下掉的弧線在崖壁上切一道缺口
		var bed := _river_surface(p.x) - 0.5
		var k := (1.0 - sstep(1.1, 2.3, rd)) * sstep(RIVER_X0 - 1.5, RIVER_X0 - 0.2, p.x)
		h = minf(h, lerpf(h, bed, k))
	return h

## 小湖的水面高度（島座標算的，不經過 _land_h()，所以 _land_h() 裡面也能用）
func _lake_surface() -> float:
	var pc: Vector2 = ZONE_POOLS[2][0].center + ZONE_ORIGIN[2]
	return _base_h(pc) - 0.45 + PLATEAU_H + 0.24

## 小溪和瀑布在島座標 x 這個位置的水面高度：小溪跟湖面一樣高，過了瀑布口照拋物線往下掉到低地的河
func _river_surface(x: float) -> float:
	var top := _lake_surface()
	if x <= RIVER_LIP:
		return top
	var u := clampf((x - RIVER_LIP) / (RIVER_FOOT - RIVER_LIP), 0.0, 1.0)
	var t := pow(u, 1.0 / 0.6)
	return lerpf(top, _river_water(RIVER_FOOT), t * t)

func _edge_d(x: float, z: float) -> float:
	var p := _isl(x, z)
	# 島 = 左邊高原那個大圓 ＋ 右上、右下兩個小一點的圓
	var d := p.distance_to(PLATEAU_C) - (PLATEAU_R + 8.0)
	d = minf(d, p.distance_to(Vector2(43.0, 20.0)) - 25.0)
	d = minf(d, p.distance_to(Vector2(43.0, -19.0)) - 25.0)
	# 火山那一側往海裡多凸出一塊：火山 + 外面的平地 + 懸崖 + 岸邊
	d = minf(d, p.distance_to(VOLCANO_C) - (VOLCANO_R + VOLCANO_PAD + 7.0 + 4.0))
	return d + (_noise.get_noise_2d(p.x * 0.9 + 31.0, p.y * 0.9 - 17.0) * 0.5 + 0.5) * 3.0

func _clear_d(x: float, z: float) -> float:
	var p := _isl(x, z)
	var best := 1e9
	for zr in ZONES:
		var r: Rect2 = zr
		var dx := maxf(maxf(r.position.x - p.x, p.x - r.end.x), 0.0)
		var dz := maxf(maxf(r.position.y - p.y, p.y - r.end.y), 0.0)
		best = minf(best, Vector2(dx, dz).length())
	return best

func _tree_ok(x: float, z: float) -> bool:
	var p := _isl(x, z)
	if _on_stairs(p, 2.2) or _river_d(p) < RIVER_W * 0.5 + 1.6:
		return false
	if p.distance_to(VOLCANO_C) < VOLCANO_R + 1.5:
		return false        # 火山上不長樹
	# 第二小關海岸那棵當橋的枯樹：它四周和倒向礁石的那條路上不長樹（不然擋住、也看不清楚）
	var bt: Vector2 = Vector2(GROVE_TREES[GROVE_BRIDGE].x, GROVE_TREES[GROVE_BRIDGE].z) + ZONE_ORIGIN[1]
	var br: Vector2 = STAR_ROCK + ZONE_ORIGIN[1]
	var bu := clampf((p - bt).dot(br - bt) / (br - bt).length_squared(), -0.4, 1.0)
	if p.distance_to(bt + (br - bt) * bu) < 4.5:
		return false
	var bd := p.distance_to(BARE_C)
	if bd < BARE_R:
		return false        # 第二小關中間不長一般的樹
	if bd < BARE_R + 10.0 and absi(hash(Vector2i(roundi(p.x * 2.0), roundi(p.y * 2.0)))) % 100 >= BARE_KEEP:
		return false        # 最外圈還是有幾棵，但是比別的地方稀疏很多
	if absf(p.x - BRIDGE_X) < 3.0 and absf(p.y - _river_z(p.x)) < BRIDGE_TREE_H:
		return false        # 枯樹倒下去的那一條不要有別的樹擋著
	var m := _plateau_mask(p)
	return m < 0.04 or m > 0.97        # 岩壁上不長樹

func _amin() -> Vector2:
	return ISLE_MIN + Vector2(14.0, 14.0) + _off
func _amax() -> Vector2:
	return ISLE_MAX - Vector2(14.0, 14.0) + _off

func _forest_origin() -> Vector2:
	return _off

func _ground_origin() -> Vector2:
	return _off

## 三個小關鏡頭一開始的位置附近都不長樹（不然同一個地方，在這一關有樹、在那一關沒樹）
func _near_camera(px: float, pz: float) -> bool:
	var p := _isl(px, pz)
	for k in CAM_HOMES.size():
		if p.distance_to(CAM_HOMES[k] + ZONE_ORIGIN[k]) < 10.0:
			return true
	return false

## 三個小關的空地都撒落葉、長草叢（編號就是第幾小關，所以每一關看到的都一樣）
func _leaf_areas() -> Array:
	var out: Array = []
	for k in ZONES.size():
		var zr: Rect2 = ZONES[k]
		out.append([Rect2(zr.position + _off, zr.size), k])
	return out

## 草：共用程式只會在現在這一關的空地長草，而且每次長的位置不一定一樣；
## 所以這裡不用它，自己在三個小關的空地都種（位置固定），用的是同一種草的模型和 shader
func _build_arena_grass() -> void:
	var r := RandomNumberGenerator.new()
	var spots: Array = []
	for k in ZONES.size():
		var zr: Rect2 = ZONES[k]
		r.seed = world_seed + 900 + k
		for i in grass_count:
			var ip := Vector2(zr.position.x - 6.0 + r.randf() * (zr.size.x + 12.0), zr.position.y - 6.0 + r.randf() * (zr.size.y + 12.0))
			var sc := r.randf_range(0.7, 1.15)
			var yaw := r.randf() * TAU
			var tall := r.randf_range(0.8, 1.2)
			var v := r.randf_range(0.85, 1.05)
			var green := r.randf() < 0.55
			var x := ip.x + _off.x
			var z := ip.y + _off.y
			if not zr.grow(0.5).has_point(ip) or in_pool(k + 1, x, z):
				continue
			spots.append([x, z, sc, yaw, tall, v, green])
	if spots.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = _make_grass_mesh()
	mm.instance_count = spots.size()
	for i in spots.size():
		var sp: Array = spots[i]
		var s: float = sp[2] * 0.8
		var bb := Basis(Vector3.UP, sp[3]).scaled(Vector3(s, s * float(sp[4]), s))
		mm.set_instance_transform(i, Transform3D(bb, Vector3(sp[0], _land_h(sp[0], sp[1]) - 0.04, sp[1])))
		var v: float = sp[5]
		mm.set_instance_color(i, Color(0.62 * v, 0.95 * v, 0.5 * v) if sp[6] else Color(v, v, v * 0.95))
	var grass := MultiMeshInstance3D.new()
	grass.name = "Grass"
	grass.multimesh = mm
	var gm := ShaderMaterial.new()
	gm.shader = load("res://shaders/grass.gdshader")
	grass.material_override = gm
	grass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(grass)
	_grass_mat = gm
	_apply_time()

func _gy(x: float, z: float) -> float:
	return _land_h(x, z) + cliff_h(x, z)

## 共用地形只有 120 公尺見方；邊緣不要自己沉下去（島的外面我們自己會讓它沉到海裡）
func _raw_height(x: float, z: float) -> float:
	return arena_height(x * LAYOUT_SCALE, z * LAYOUT_SCALE) / LAYOUT_SCALE

# ---------------------------------------------------------------- 島上多蓋的東西

func _build_extra() -> void:
	super()
	_build_far_land()
	_build_stairs()
	_build_plateau_rocks()
	_build_other_zones()
	_build_barriers()
	_build_river()
	_build_banks()
	_build_dead_tree()
	_build_windmill()
	_build_volcano()
	_build_star_rock()
	_build_pools()
	_build_remembered()
	_build_stars()
	_build_signs()

# ---------------------------------------------------------------- 天空中的關卡名稱

const SIGN_NAMES := ["Chapter 1", "Chapter 2", "Chapter 3"]
const SIGN_H := 22.0               # 字浮在那一小關的空地中間、離地多高
const SIGN_BIG := 2.8              # 玩家現在所在的那一關：字有多高（公尺）
const SIGN_SMALL := 1.8            # 別的關：字比較小
var _signs: Array = []             # [{root, glow, here, y}]

## 字：不受光、不被霧蓋掉的純色（遠遠也看得清楚）
const SIGN_TEXT_SHADER := "shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled, shadows_disabled;
uniform vec4 tint : source_color = vec4(1.0);
void fragment() {
	ALBEDO = tint.rgb;
}
"
## 字後面的光暈：橫的一團軟軟的光，疊加上去；沒有光的地方不畫
const SIGN_GLOW_SHADER := "shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
uniform vec4 tint : source_color = vec4(1.0);
void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float v = exp(-dot(p, p) * 3.2) * smoothstep(1.0, 0.55, length(p)) * tint.a;
	if (v < 0.004) {
		discard;
	}
	ALBEDO = tint.rgb * v;
	ALPHA = clamp(v, 0.0, 1.0);
}
"

## 三個小關的空地正上方各浮著一行發光的白字（Chapter 1 / 2 / 3，斜體的襯線字）。
## 玩家現在在的那一關：字大、純白、金色的字影、後面一團金色的光暈一明一暗、整行慢慢上下飄；
## 別的關：字小、淡淡的灰白色、不動，遠遠看得出那邊是第幾關
func _build_signs() -> void:
	_signs.clear()
	var tsh := Shader.new()
	tsh.code = SIGN_TEXT_SHADER
	var gsh := Shader.new()
	gsh.code = SIGN_GLOW_SHADER
	# 用電腦裡現成的襯線字型（Mac、Windows 各列幾個，找不到就用系統預設的襯線字）
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Palatino", "Palatino Linotype", "Book Antiqua", "Georgia", "Baskerville", "Times New Roman", "serif"])
	font.font_italic = true
	font.font_weight = 700
	for k in ZONES.size():
		var c: Vector2 = (ZONES[k] as Rect2).get_center() + _off
		var here: bool = k == stage_index - 1
		var size: float = SIGN_BIG if here else SIGN_SMALL
		var root := Node3D.new()
		root.name = "Sign%d" % (k + 1)
		var y: float = _land_h(c.x, c.y) + SIGN_H
		root.position = Vector3(c.x, y, c.y)
		add_child(root)
		var tm := TextMesh.new()
		tm.text = SIGN_NAMES[k]
		tm.font = font
		tm.font_size = 64
		tm.pixel_size = size / 64.0
		tm.depth = 0.1
		# 前面白字、後面往右下錯開一點的字影（襯出字的邊，背景是亮的天空也看得清楚）
		var layers := [
			[Color(1, 1, 1) if here else Color(0.9, 0.93, 0.97), Vector3.ZERO],
			[Color(0.78, 0.46, 0.1) if here else Color(0.5, 0.56, 0.66), Vector3(size * 0.028, -size * 0.028, -0.2)],
		]
		for ly in layers:
			var mi := MeshInstance3D.new()
			mi.mesh = tm
			var mat := ShaderMaterial.new()
			mat.shader = tsh
			mat.set_shader_parameter("tint", ly[0])
			mi.material_override = mat
			mi.position = ly[1]
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(mi)
		var gm: ShaderMaterial = null
		if here:
			var glow := MeshInstance3D.new()
			var qm := QuadMesh.new()
			qm.size = Vector2(size * 8.5, size * 3.4)
			glow.mesh = qm
			gm = ShaderMaterial.new()
			gm.shader = gsh
			gm.set_shader_parameter("tint", Color(1.0, 0.8, 0.4, 0.7))
			glow.material_override = gm
			glow.position = Vector3(0.0, 0.0, -0.5)
			glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(glow)
		_signs.append({"root": root, "glow": gm, "here": here, "y": y})

## 字永遠正面朝著鏡頭；現在這一關的字：光暈一明一暗、整行慢慢上下飄
func _tick_signs() -> void:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	var t := Time.get_ticks_msec() / 1000.0
	for sg in _signs:
		if not is_instance_valid(sg.root):
			continue
		var root: Node3D = sg.root
		if sg.here:
			root.position.y = float(sg.y) + sin(t * 0.9) * 0.35
			(sg.glow as ShaderMaterial).set_shader_parameter("tint", Color(1.0, 0.8, 0.4, 0.65 + 0.25 * sin(t * 2.2)))
		if cam:
			var d: Vector3 = cam.global_position - root.global_position
			d.y = 0.0
			if d.length() > 0.5:
				root.rotation.y = atan2(d.x, d.z)

## 別的小關的擺設和水池：只有外觀，飛過去看得到
func _build_other_zones() -> void:
	var holder := Node3D.new()
	holder.name = "OtherZones"
	add_child(holder)
	for k in ZONE_PROPS.size():
		if k == stage_index - 1:
			continue
		var o: Vector2 = ZONE_ORIGIN[k] + _off
		for pr in ZONE_PROPS[k]:
			var pos: Vector3 = pr.pos + Vector3(o.x, 0.0, o.y)
			var n := place_model(holder, pr.model, pos, pr.get("yaw", 0.0), pr.get("scale", 1.0), 0.0)
			if n:
				n.position.y = _land_h(pos.x, pos.z) - 0.05      # 太遠的地方共用地形量不到高度
		for pond in ZONE_PONDS[k]:
			var c: Vector2 = pond.center + o
			var r: float = pond.r
			var water := MeshInstance3D.new()
			water.name = "FarPond"
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
			water.position = Vector3(c.x, _land_h(c.x + r * 0.7, c.y) - 0.6, c.y)
			water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			holder.add_child(water)

## 小關之間的分界：一排浮在半空中、會發光的柵欄（白天金黃、晚上藍白）。只立在兩關交界的地方，不把整關框起來。
## SEALS[k] 是第 k+1 小關和第 k+2 小關之間的那一道；還沒打開的都立著，這一關過了就打開自己前面那一道。
## 第 k 道柵欄的幾段線（每一段是一串點）。第二↔第三小關那一道有兩段：石階腳下一段、石階頂上一段
func _seal_lines(k: int) -> Array:
	var lines: Array = []
	if k == 0:
		# 沿著河的中線，浮在水面上，從水潭一路到海邊
		var pts: Array[Vector3] = []
		var x := RIVER_FOOT + 2.0
		while x < ISLE_MAX.x:
			var z := _river_z(x)
			if _edge_d(x + _off.x, z + _off.y) > -0.5:
				break
			pts.append(Vector3(x + _off.x, _river_water(x) + FENCE_FLOAT, z + _off.y))
			x += 0.5
		lines.append(pts)
		return lines
	var segs: Array = [[SEALS[k][0], SEALS[k][1]]]
	if k == 1:
		# 石階頂上再橫一段
		var d := (STAIR_B - STAIR_A).normalized()
		var side := Vector2(-d.y, d.x) * 3.2
		var c := STAIR_B + d * 1.4
		segs.append([c - side, c + side])
	for sg in segs:
		var a: Vector2 = sg[0] + _off
		var b: Vector2 = sg[1] + _off
		var n := int(ceil(a.distance_to(b) / 0.5))
		var pts2: Array[Vector3] = []
		for i in n + 1:
			var p := a.lerp(b, float(i) / n)
			pts2.append(Vector3(p.x, _land_h(p.x, p.y) + FENCE_FLOAT, p.y))     # 跟著地面起伏，離地一段距離浮著
		lines.append(pts2)
	return lines

## 每一道柵欄都立著（已經走過的那幾道也在，擋在身後）；這一關過了才打開通往下一關的那一道
func _build_barriers() -> void:
	for k in SEALS.size():
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var any := false
		for pts in _seal_lines(k):
			var run := 0.0
			for i in pts.size() - 1:
				var p0: Vector3 = pts[i]
				var p1: Vector3 = pts[i + 1]
				var u0 := run
				run += Vector2(p0.x, p0.z).distance_to(Vector2(p1.x, p1.z))
				var v := [p0, p1, p1 + Vector3(0.0, FENCE_HEIGHT, 0.0), p0 + Vector3(0.0, FENCE_HEIGHT, 0.0)]
				var uv := [Vector2(u0, 0.0), Vector2(run, 0.0), Vector2(run, 1.0), Vector2(u0, 1.0)]
				for t in [0, 1, 2, 0, 2, 3]:
					st.set_uv(uv[t])
					st.add_vertex(v[t])
				any = true
		if not any:
			continue
		var m := ShaderMaterial.new()
		m.shader = BARRIER_SHADER
		m.set_shader_parameter("night", 1.0 if night else 0.0)
		m.set_shader_parameter("height", FENCE_HEIGHT)
		_leaf_mats.append(m)
		if k == stage_index - 1:
			_barrier_mat = m
		var mi := MeshInstance3D.new()
		mi.name = "Fence%d" % (k + 1)
		mi.mesh = st.commit()
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)

var _barrier_tween: Tween

## 過關：通往下一關的那一道柵欄一根一根熄掉
func open_barrier() -> void:
	_set_barrier(1.0, 1.6)

## 重試：柵欄回來
func close_barrier() -> void:
	if bridge_ready() and stage_index == 1:
		return        # 樹已經倒了、橋還在，柵欄不用回來
	_set_barrier(0.0, 0.3)

func _set_barrier(target: float, secs: float) -> void:
	var mats: Array[ShaderMaterial] = []
	if _barrier_mat:
		mats.append(_barrier_mat)
	if mats.is_empty():
		return
	if _barrier_tween:
		_barrier_tween.kill()
	_barrier_tween = create_tween().set_parallel(true)
	for m in mats:
		var from: float = m.get_shader_parameter("open") if m.get_shader_parameter("open") != null else 0.0
		_barrier_tween.tween_method(func(val: float) -> void: m.set_shader_parameter("open", val), from, target, secs)

## 鏡頭可以飛遍整座島（共用的 Player 預設只能在場地附近飛）；從上一關飛過來的話，接在同一個位置
func _place_player() -> void:
	super()
	var player := get_node_or_null(player_path) as Node3D
	if player == null:
		return
	# 玩家只能在這一小關的場地上空飛（往外多留 ZONE_FLY 公尺，看得到場地邊上的東西），高度不限；
	# 不然飛太遠會不知道要做什麼。換關的時候鏡頭是程式帶著走的，不受這個限制
	# 有柵欄的那一邊只能飛到柵欄（各小關在 _configure() 裡用 fly_min / fly_max 設定），不能飛到隔壁那一關去
	var lo := play_min - Vector2(ZONE_FLY, ZONE_FLY)
	var hi := play_max + Vector2(ZONE_FLY, ZONE_FLY)
	lo = Vector2(maxf(lo.x, fly_min.x), maxf(lo.y, fly_min.y))
	hi = Vector2(minf(hi.x, fly_max.x), minf(hi.y, fly_max.y))
	player.set("bounds_min", lo)
	player.set("bounds_max", hi)
	player.set("max_height", 85.0)
	if Engine.has_meta("liuchiyu_cam"):
		var c: Dictionary = Engine.get_meta("liuchiyu_cam")
		Engine.remove_meta("liuchiyu_cam")
		var ip: Vector3 = c.pos
		player.global_position = Vector3(ip.x + _off.x, ip.y, ip.z + _off.y)
		player.rotation = Vector3(0.0, c.yaw, 0.0)
		var head := player.get_node_or_null("Head") as Node3D
		if head:
			head.rotation.x = c.pitch
		if c.get("night", false) and not night:
			night = true
			_apply_time()

## 把鏡頭現在的位置（換成島座標）記下來，下一關接著用
func remember_camera() -> void:
	var player := get_node_or_null(player_path) as Node3D
	if player == null:
		return
	var head := player.get_node_or_null("Head") as Node3D
	var gp := player.global_position
	Engine.set_meta("liuchiyu_cam", {
		"pos": Vector3(gp.x - _off.x, gp.y, gp.z - _off.y), "yaw": player.rotation.y,
		"pitch": head.rotation.x if head else 0.0, "night": night,
	})

## 共用地形蓋不到的地方（離這一小關超過 60 公尺的那一段島）自己補一片地面
func _build_far_land() -> void:
	var half := 60.0
	var step := 1.5
	var lo := ISLE_MIN + _off
	var hi := ISLE_MAX + _off
	var ix0 := int(floor(lo.x / step))
	var ix1 := int(ceil(hi.x / step))
	var iz0 := int(floor(lo.y / step))
	var iz1 := int(ceil(hi.y / step))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var any := false
	for ix in range(ix0, ix1):
		for iz in range(iz0, iz1):
			var cx := (ix + 0.5) * step
			var cz := (iz + 0.5) * step
			if absf(cx) < half and absf(cz) < half:
				continue        # 這裡有共用地形
			if _edge_d(cx, cz) > -1.2:
				continue        # 崖邊和海上：不鋪地面。地面只鋪到崖邊內側一點，邊緣整個藏在崖邊那一圈岩石底下；
				                # 鋪到崖邊外面的話，一格一格的地面會從懸崖上凸出去，變成一排鋸齒
			var c: Array[Vector3] = []
			for o in [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]:
				var x: float = (ix + o.x) * step
				var z: float = (iz + o.y) * step
				c.append(Vector3(x, _land_h(x, z), z))
			for tri in [[0, 1, 2], [0, 2, 3]]:
				var a := c[tri[0]]
				var b := c[tri[1]]
				var d := c[tri[2]]
				var n := (d - a).cross(b - a).normalized()
				st.set_normal(n)
				st.set_color(Color(0.0, 0.0, sstep(0.35, 0.7, 1.0 - n.y)))      # 陡的地方畫成岩石
				st.add_vertex(a)
				st.add_vertex(b)
				st.add_vertex(d)
				any = true
	if not any:
		return
	var gm := ShaderMaterial.new()
	gm.shader = GROUND_SHADER
	gm.set_shader_parameter("origin", _ground_origin())
	gm.set_shader_parameter("night", 1.0 if night else 0.0)
	_leaf_mats.append(gm)
	var mi := MeshInstance3D.new()
	mi.name = "FarLand"
	mi.mesh = st.commit()
	mi.material_override = gm
	add_child(mi)

## 第二小關通到高原的石階：一階一階的石板，鋪在切進岩壁的斜坡上
func _build_stairs() -> void:
	var holder := Node3D.new()
	holder.name = "Stairs"
	add_child(holder)
	var mat := _cliff_material()
	var a := STAIR_A + _off
	var b := STAIR_B + _off
	var dir := (b - a).normalized()
	var yaw := atan2(dir.x, dir.y)        # 石板的長邊橫在石階上
	var run := a.distance_to(b) / STAIR_STEPS
	var y0 := _land_h(a.x - dir.x * 0.3, a.y - dir.y * 0.3)
	var y1 := _land_h(b.x + dir.x * 0.5, b.y + dir.y * 0.5)
	var r := RandomNumberGenerator.new()
	r.seed = world_seed + 211
	for k in STAIR_STEPS:
		var top := y0 + (y1 - y0) * float(k + 1) / STAIR_STEPS
		var c := a + dir * ((k + 0.5) * run)
		# 每一階寬度、位置稍微不一樣，像一塊一塊鋪上去的石板。
		# 每一塊都是一根很深的岩石柱，一路插到地底下：石階兩側和底下看到的都是岩石，不會懸空
		var w := STAIR_W + r.randf_range(-0.3, 0.3)
		_box(holder, Vector3(w, STAIR_DEPTH, run + 0.14), Vector3(c.x, top - STAIR_DEPTH * 0.5, c.y), mat, Vector3(0.0, yaw + r.randf_range(-0.03, 0.03), 0.0))

## 高原的岩壁上堆大石頭，看起來是一整塊岩石平台；石階兩側也堆一排
func _build_plateau_rocks() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = world_seed + 233
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.radial_segments = 6
	sm.rings = 3
	var xf: Array[Transform3D] = []
	for k in 30000:
		if xf.size() >= 640:
			break
		var ang := r.randf() * TAU
		var p := PLATEAU_C + Vector2(cos(ang), sin(ang)) * r.randf_range(PLATEAU_R - 8.0, PLATEAU_R + 4.0)
		var big := false
		if k % 3 == 0:
			# 火山那一側往海邊凸出去的那一圈崖壁也要鋪岩石（不然露出來的是被拉長的地面）
			p = VOLCANO_C + Vector2(cos(ang), sin(ang)) * r.randf_range(VOLCANO_R + VOLCANO_PAD - 1.5, VOLCANO_R + VOLCANO_PAD + 8.5)
			big = true
		var m := _plateau_mask(p)
		if m < 0.03 or m > 0.97 or _on_stairs(p, 0.8) or _river_d(p) < 4.2:
			continue        # 石階和瀑布前面不要堆石頭擋住
		if p.distance_to(VOLCANO_C) < VOLCANO_R + 1.0:
			continue        # 火山的山坡上不要卡著懸崖的石頭
		var sc := r.randf_range(2.2, 4.2) if big else r.randf_range(1.3, 3.6)
		var bs := Basis.from_euler(Vector3(r.randf() * TAU, r.randf() * TAU, r.randf() * TAU)).scaled(Vector3(sc * r.randf_range(0.9, 1.5), sc * r.randf_range(0.8, 1.4), sc * r.randf_range(0.9, 1.4)))
		var x := p.x + _off.x
		var z := p.y + _off.y
		xf.append(Transform3D(bs, Vector3(x, _land_h(x, z) + sc * 0.1, z)))
	# 石階兩側
	var ab := STAIR_B - STAIR_A
	var nrm := Vector2(-ab.y, ab.x).normalized()
	for k in 46:
		var side := -1.0 if k % 2 == 0 else 1.0
		var t := r.randf_range(0.02, 1.0)
		var p := STAIR_A + ab * t + nrm * side * (STAIR_W * 0.5 + r.randf_range(0.7, 1.6))
		var sc := r.randf_range(0.9, 1.8)
		var bs := Basis.from_euler(Vector3(r.randf() * TAU, r.randf() * TAU, r.randf() * TAU)).scaled(Vector3(sc, sc * r.randf_range(0.9, 1.5), sc * 1.2))
		var x := p.x + _off.x
		var z := p.y + _off.y
		xf.append(Transform3D(bs, Vector3(x, _land_h(x, z) + sc * 0.25, z)))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = sm
	mm.instance_count = xf.size()
	for i in xf.size():
		mm.set_instance_transform(i, xf[i])
	var mi := MultiMeshInstance3D.new()
	mi.name = "PlateauRocks"
	mi.multimesh = mm
	mi.material_override = _cliff_material()
	add_child(mi)

## 河面：沿著中線鋪一條帶子（高原上的小溪 → 瀑布 → 低地的河 → 流進海裡的小瀑布）
func _build_river() -> void:
	# 每一個點：[島座標 x, 高度 y, 半寬, 是不是瀑布(0~1)]
	var pts: Array = []
	# 水從高原上的小湖流出來：一小段小溪（和湖面一樣高）流到高原邊緣，再往下掉
	var x := RIVER_X0
	var top: float = _lake_surface()
	while x < RIVER_LIP:
		pts.append([x, top, 1.2, 0.0])
		x += 0.7
	var pool := _river_water(RIVER_FOOT)
	# 瀑布：水從瀑布口衝出去，畫一條拋物線掉到水潭
	for i in range(0, 15):
		var t := float(i) / 14.0
		pts.append([lerpf(RIVER_LIP, RIVER_FOOT, pow(t, 0.6)), lerpf(top, pool, t * t), lerpf(1.2, 2.0, t), 1.0 if i > 0 else 0.0])
	x = RIVER_FOOT + 0.8
	var out_x := x
	while x < ISLE_MAX.x + 4.0:
		var z := _river_z(x)
		if _edge_d(x + _off.x, z + _off.y) > 0.6:
			break        # 到海邊了
		pts.append([x, _river_water(x), lerpf(2.0, RIVER_W * 0.5 + 0.9, sstep(RIVER_FOOT, RIVER_FOOT + 4.0, x)), 1.0 - sstep(RIVER_FOOT, RIVER_FOOT + 2.5, x)])
		out_x = x
		x += 0.8
	# 最後從崖邊衝出去，畫一條拋物線掉進海裡（要飛過底下一層一層的岩階）
	var h0 := _river_water(out_x)
	for i in range(1, 11):
		var t := float(i) / 10.0
		pts.append([out_x + (cliff_width + 1.5) * t, lerpf(h0, sea_level + 0.06, t * t), RIVER_W * 0.5 + 0.9 + 0.5 * t, sstep(0.0, 0.3, t)])
	var c3: Array[Vector3] = []
	for q in pts:
		c3.append(Vector3(q[0] + _off.x, q[1], _river_z(q[0]) + _off.y))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var run := 0.0
	var left: Array[Vector3] = []
	var right: Array[Vector3] = []
	var vs: Array[float] = []
	for i in c3.size():
		var d := (c3[mini(i + 1, c3.size() - 1)] - c3[maxi(i - 1, 0)])
		var side := Vector3(-d.z, 0.0, d.x).normalized() * float(pts[i][2])
		if i > 0:
			run += c3[i].distance_to(c3[i - 1])
		left.append(c3[i] - side)
		right.append(c3[i] + side)
		vs.append(run)
	for i in c3.size() - 1:
		var quad := [[left[i], Vector2(0.0, vs[i]), pts[i][3]], [right[i], Vector2(1.0, vs[i]), pts[i][3]],
			[right[i + 1], Vector2(1.0, vs[i + 1]), pts[i + 1][3]], [left[i + 1], Vector2(0.0, vs[i + 1]), pts[i + 1][3]]]
		for t in [0, 1, 2, 0, 2, 3]:
			st.set_color(Color(quad[t][2], 0.0, 0.0))
			st.set_uv(quad[t][1])
			st.add_vertex(quad[t][0])
		# 瀑布（從崖壁流出來那一段、流進海裡那一段）不是一張薄薄的紙：兩側和底下也用水包起來，變成一整條厚厚的水柱
		if float(pts[i][3]) > 0.02 or float(pts[i + 1][3]) > 0.02:
			var dn := Vector3(0.0, -RIVER_THICK, 0.0)
			var f0: float = pts[i][3]
			var f1: float = pts[i + 1][3]
			var faces := [
				[[left[i], 0.0, vs[i], f0], [left[i + 1], 0.0, vs[i + 1], f1], [left[i + 1] + dn, 0.25, vs[i + 1], f1], [left[i] + dn, 0.25, vs[i], f0]],
				[[right[i], 1.0, vs[i], f0], [right[i + 1], 1.0, vs[i + 1], f1], [right[i + 1] + dn, 0.75, vs[i + 1], f1], [right[i] + dn, 0.75, vs[i], f0]],
				[[left[i] + dn, 0.25, vs[i], f0], [left[i + 1] + dn, 0.25, vs[i + 1], f1], [right[i + 1] + dn, 0.75, vs[i + 1], f1], [right[i] + dn, 0.75, vs[i], f0]],
			]
			for fc in faces:
				for t in [0, 1, 2, 0, 2, 3]:
					st.set_color(Color(fc[t][3], 0.0, 0.0))
					st.set_uv(Vector2(fc[t][1], fc[t][2]))
					st.add_vertex(fc[t][0])
	var m := ShaderMaterial.new()
	m.shader = RIVER_SHADER
	m.set_shader_parameter("night", 1.0 if night else 0.0)
	m.set_shader_parameter("width", RIVER_W)
	_leaf_mats.append(m)
	var mi := MeshInstance3D.new()
	mi.name = "River"
	mi.mesh = st.commit()
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	# 瀑布底下濺起來的白色水霧：大瀑布衝進水潭那裡一大團，流進海裡的小瀑布底下小一團
	var foot := Vector3(RIVER_FOOT + _off.x, pool, _river_z(RIVER_FOOT) + _off.y)
	_build_falls_mist("FallsMist", foot, 2.2, 1.0)
	_build_falls_mist("SeaFallsMist", c3[c3.size() - 1], RIVER_W * 0.5 + 1.4, 0.7)

## 一團邊緣軟軟的白色圓點（水霧、水花共用）
func _soft_dot() -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.45, Color(1, 1, 1, 0.75))
	var tex := GradientTexture2D.new()
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = 64
	tex.height = 64
	tex.gradient = g
	return tex

## 瀑布衝下去的地方：一層慢慢往上飄、往外散開的白霧（像雲），加一些往上噴再掉回去的小水花。
## foot 是水落下來那一點，half_w 是瀑布在那裡的半寬，k 是整體大小
func _build_falls_mist(nm: String, foot: Vector3, half_w: float, k: float) -> void:
	var tint := Color(0.62, 0.66, 0.78) if night else Color(1.0, 1.0, 1.0)
	var holder := Node3D.new()
	holder.name = nm
	holder.position = foot
	add_child(holder)
	# 漸漸變淡、漸漸變大
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0.0))
	fade.set_color(1, Color(1, 1, 1, 0.0))
	fade.add_point(0.15, Color(1, 1, 1, 0.85))
	fade.add_point(0.6, Color(1, 1, 1, 0.55))
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.45))
	grow.add_point(Vector2(1.0, 1.0))
	var specs := [
		# [名字, 數量, 存活秒數, 粒子大小, 往上速度(最小,最大), 重力, 散開角度, 大小倍數(最小,最大), 透明度]
		["Foam", 50, 2.2, 2.6, Vector2(0.6, 1.4), Vector3(0.0, -0.2, 0.0), 88.0, Vector2(0.9, 1.6), 0.85],      # 貼著水面往四周鋪開的一圈白泡泡
		["Mist", 70, 3.6, 3.0, Vector2(0.8, 1.8), Vector3(0.0, 0.25, 0.0), 60.0, Vector2(0.8, 2.0), 0.6],       # 往上飄高的白霧，像一朵雲
		["Spray", 70, 1.1, 0.5, Vector2(3.0, 5.2), Vector3(0.0, -7.0, 0.0), 38.0, Vector2(0.5, 1.2), 0.95],     # 往上噴再掉下去的小水花
	]
	for s in specs:
		var p := CPUParticles3D.new()
		p.name = s[0]
		var qm := QuadMesh.new()
		qm.size = Vector2.ONE * float(s[3]) * k
		var sm := StandardMaterial3D.new()
		sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		sm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		sm.vertex_color_use_as_albedo = true
		sm.albedo_texture = _soft_dot()
		sm.albedo_color = Color(tint.r, tint.g, tint.b, float(s[8]))
		sm.disable_receive_shadows = true
		qm.material = sm
		p.mesh = qm
		p.amount = int(float(s[1]) * k)
		p.lifetime = s[2]
		p.preprocess = s[2]          # 一進關卡就已經是一整團，不是從零慢慢冒出來
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		p.emission_box_extents = Vector3(0.9, 0.15, half_w) * k
		p.direction = Vector3(0.25, 1.0, 0.0)        # 稍微往下游那邊（+x）飄
		p.spread = s[6]
		p.initial_velocity_min = (s[4] as Vector2).x * k
		p.initial_velocity_max = (s[4] as Vector2).y * k
		p.gravity = s[5]
		p.damping_min = 0.3
		p.damping_max = 0.8
		p.scale_amount_min = (s[7] as Vector2).x
		p.scale_amount_max = (s[7] as Vector2).y
		p.scale_amount_curve = grow
		p.color_ramp = fade
		p.angle_min = 0.0
		p.angle_max = 360.0
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		p.visibility_aabb = AABB(Vector3(-8, -3, -8) * k, Vector3(16, 12, 16) * k)
		holder.add_child(p)

## 河岸：兩岸堆一排大小不一的石頭、水裡露出幾塊，岸邊長一叢一叢比較高的草
func _build_banks() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = world_seed + 251
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.radial_segments = 6
	sm.rings = 3
	var rocks: Array[Transform3D] = []
	var xf: Array[Transform3D] = []
	var cols: Array[Color] = []
	var reed_cols := [Color(0.60, 0.66, 0.24), Color(0.78, 0.70, 0.26), Color(0.42, 0.54, 0.24), Color(0.86, 0.62, 0.20)]
	var x := RIVER_FOOT - 0.5
	while x < ISLE_MAX.x:
		var zc := _river_z(x)
		if _edge_d(x + _off.x, zc + _off.y) > 1.5:
			break
		for side in [-1.0, 1.0]:
			# 岸邊的石頭：貼著水邊，有大有小
			if r.randf() < 0.8:
				var d := RIVER_W * 0.5 + r.randf_range(0.3, 1.3)
				var px := x + r.randf_range(-0.4, 0.4)
				var pz: float = _river_z(px) + side * d
				var sc := r.randf_range(0.28, 0.85) * (1.6 if r.randf() < 0.12 else 1.0)
				var b := Basis.from_euler(Vector3(r.randf() * TAU, r.randf() * TAU, r.randf() * TAU)).scaled(Vector3(sc * r.randf_range(0.9, 1.5), sc * r.randf_range(0.55, 0.9), sc * r.randf_range(0.9, 1.4)))
				rocks.append(Transform3D(b, Vector3(px + _off.x, _land_h(px + _off.x, pz + _off.y) + sc * 0.15, pz + _off.y)))
			# 岸上的草叢：比一般的草高，往外倒
			if r.randf() < 0.6:
				var d2 := RIVER_W * 0.5 + r.randf_range(1.2, 2.6)
				var qx := x + r.randf_range(-0.4, 0.4)
				var qz: float = _river_z(qx) + side * d2
				var gy := _land_h(qx + _off.x, qz + _off.y)
				var c: Color = reed_cols[r.randi() % reed_cols.size()]
				var size := r.randf_range(0.5, 0.95)
				var n := r.randi_range(5, 8)
				for j in n:
					var yaw := TAU * float(j) / float(n) + r.randf_range(-0.3, 0.3)
					var lean := r.randf_range(0.1, 0.45)
					var l := size * r.randf_range(0.8, 1.3)
					var bb := Basis.from_euler(Vector3(0.0, yaw, PI * 0.5 - lean)).scaled(Vector3(l, l * 0.3, l))
					xf.append(Transform3D(bb, Vector3(qx + _off.x, gy + 0.02, qz + _off.y) + bb.x.normalized() * l * 0.4))
					var v := r.randf_range(0.6, 0.9)
					cols.append(Color(c.r * v, c.g * v, c.b * v))
		# 水裡偶爾露出一塊石頭
		if r.randf() < 0.16:
			var wz := zc + r.randf_range(-RIVER_W * 0.35, RIVER_W * 0.35)
			var sc2 := r.randf_range(0.4, 0.75)
			var b2 := Basis.from_euler(Vector3(r.randf() * TAU, r.randf() * TAU, r.randf() * TAU)).scaled(Vector3(sc2 * 1.3, sc2 * 0.8, sc2 * 1.2))
			rocks.append(Transform3D(b2, Vector3(x + _off.x, _river_water(x) - sc2 * 0.2, wz + _off.y)))
		x += 0.75
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = sm
	mm.instance_count = rocks.size()
	for i in rocks.size():
		mm.set_instance_transform(i, rocks[i])
	var mi := MultiMeshInstance3D.new()
	mi.name = "BankRocks"
	mi.multimesh = mm
	mi.material_override = _cliff_material()
	add_child(mi)
	_leaf_multimesh("BankReeds", xf, cols)

# ---------------------------------------------------------------- 枯樹橋

var _dead_tree: Node3D
var _tree_fall := -1.0        # < 0 還站著；0～1 正在倒；>= 1 已經橫在河上
var _tree_struck := false     # 被雷劈開了沒（樹太粗，要先劈開風才吹得倒）
var _tree_mat: ShaderMaterial
var _smoke: CPUParticles3D
var raining := false

## 枯樹的樹根在哪（這一小關的座標）
func dead_tree_pos() -> Vector3:
	var z := _river_z(BRIDGE_X) + RIVER_W * 0.5 + 2.4
	return Vector3(BRIDGE_X + _off.x, _land_h(BRIDGE_X + _off.x, z + _off.y), z + _off.y)

func bridge_ready() -> bool:
	return _tree_fall >= 1.0

## 在 st 裡加一段由粗到細的樹幹（六角柱），從 a 到 b
func _dead_seg(st: SurfaceTool, a: Vector3, b: Vector3, ra: float, rb: float, col: Color) -> void:
	var axis := (b - a).normalized()
	var side := axis.cross(Vector3.UP if absf(axis.y) < 0.95 else Vector3.RIGHT).normalized()
	var up := side.cross(axis).normalized()
	var n := 6
	for i in n:
		var a0 := TAU * float(i) / n
		var a1 := TAU * float(i + 1) / n
		var d0 := side * cos(a0) + up * sin(a0)
		var d1 := side * cos(a1) + up * sin(a1)
		var q := [a + d0 * ra, a + d1 * ra, b + d1 * rb, b + d0 * rb]
		var nrm := ((d0 + d1) * 0.5).normalized()
		for t in [0, 2, 1, 0, 3, 2]:
			st.set_normal(nrm)
			st.set_color(col)
			st.add_vertex(q[t])

## 一根枝幹：長一段之後分岔成兩三根更細的，越分越細，最後是尖尖的小枝
func _dead_limb(st: SurfaceTool, r: RandomNumberGenerator, from: Vector3, dir: Vector3, length: float, rad: float, depth: int, col: Color) -> void:
	# 枯樹的枝幹彎彎扭扭的：一根分成兩小段，中間拐一下
	var bend := Vector3(r.randf_range(-0.3, 0.3), r.randf_range(-0.05, 0.3), r.randf_range(-0.3, 0.3))
	var mid := from + dir * length * 0.5
	var d2 := (dir + bend).normalized()
	var tip := mid + d2 * length * 0.5
	var v := r.randf_range(0.85, 1.1)
	var c := Color(col.r * v, col.g * v, col.b * v)
	_dead_seg(st, from, mid, rad, rad * 0.82, c)
	_dead_seg(st, mid, tip, rad * 0.82, rad * (0.62 if depth > 0 else 0.1), c)
	if depth <= 0:
		return
	var forks := 3 if (depth >= 2 and r.randf() < 0.5) else 2
	for k in forks:
		var spread := r.randf_range(0.45, 0.85)
		var ang := TAU * (float(k) / forks) + r.randf_range(-0.5, 0.5)
		var perp := d2.cross(Vector3.UP if absf(d2.y) < 0.9 else Vector3.RIGHT).normalized()
		var perp2 := perp.cross(d2).normalized()
		var nd := (d2 * cos(spread) + (perp * cos(ang) + perp2 * sin(ang)) * sin(spread) + Vector3(0.0, 0.18, 0.0)).normalized()
		_dead_limb(st, r, tip, nd, length * r.randf_range(0.6, 0.78), rad * 0.6, depth - 1, col)

## 河邊的枯樹：樹幹很粗、根往外張開，幾根大枝幹分岔成一堆禿枝，一片葉子都沒有
func _build_dead_tree() -> void:
	_dead_tree = Node3D.new()
	_dead_tree.name = "DeadTree"
	_dead_tree.position = dead_tree_pos() - Vector3(0.0, 0.3, 0.0)
	add_child(_dead_tree)
	var r := RandomNumberGenerator.new()
	r.seed = world_seed + 271
	var col := Color(0.40, 0.50, 0.30)        # 紅色通道要小於 0.5（大於的話樹幹的 shader 會畫成白樺）；綠色通道是筆觸的亂數
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# 樹幹：底下最粗，往上稍微歪一點
	var p0 := Vector3.ZERO
	var p1 := Vector3(0.12, 1.5, 0.05)
	var p2 := Vector3(-0.1, 3.3, -0.05)
	_dead_seg(st, p0, p1, 1.05, 0.78, col)
	_dead_seg(st, p1, p2, 0.78, 0.64, col)
	# 往外張開的樹根
	for k in 5:
		var ang := TAU * float(k) / 5.0 + r.randf_range(-0.3, 0.3)
		var out := Vector3(cos(ang), 0.0, sin(ang))
		_dead_seg(st, Vector3(0.0, 0.9, 0.0) + out * 0.35, out * r.randf_range(1.5, 2.1) + Vector3(0.0, -0.1, 0.0), 0.42, 0.1, col.darkened(0.12))
	# 三根大枝幹：其中一根幾乎直直往上當主幹（倒下去的時候它橫過河面）
	_dead_limb(st, r, p2, Vector3(0.05, 1.0, 0.0).normalized(), BRIDGE_TREE_H - 5.4, 0.56, 3, col)
	_dead_limb(st, r, p2 - Vector3(0.0, 0.3, 0.0), Vector3(0.75, 0.66, 0.1).normalized(), 3.2, 0.42, 3, col)
	_dead_limb(st, r, p2 - Vector3(0.0, 0.5, 0.0), Vector3(-0.7, 0.7, -0.12).normalized(), 3.0, 0.4, 3, col)
	_dead_limb(st, r, p1 + Vector3(0.0, 0.6, 0.0), Vector3(-0.85, 0.45, 0.25).normalized(), 2.0, 0.24, 2, col)
	var m := ShaderMaterial.new()
	m.shader = TRUNK_SHADER
	_tree_mat = m
	var mi := MeshInstance3D.new()
	mi.name = "Wood"
	mi.mesh = st.commit()
	mi.material_override = m
	_dead_tree.add_child(mi)
	if stage_index >= 2:
		_tree_fall = 1.0        # 第二小關以後，橋已經搭好了
		_tree_struck = true
		m.set_shader_parameter("burnt", 1.0)
		_dead_tree.rotation.x = -PI * 0.5

## 風吹過來（風道具會叫這個）：p 是準心的位置，dir 是風向。回傳要顯示給玩家的話（沒有就空字串）
func wind_gust(p: Vector3, dir: Vector3) -> String:
	if _dead_tree == null or _tree_fall >= 0.0:
		return ""
	var tp := dead_tree_pos()
	if Vector2(p.x - tp.x, p.z - tp.z).length() > 6.5:
		return ""
	if not _tree_struck or dir.z > -0.45:
		return ""        # 還沒被雷劈開、或是風不是朝河的方向：吹不倒
	_tree_fall = 0.0
	if _smoke:
		_smoke.emitting = false
	return ""

func tree_struck() -> bool:
	return _tree_struck

## 做一團往上冒的黑煙（被雷劈過的樹用），放在 pos
func make_smoke(pos: Vector3) -> CPUParticles3D:
	var smoke := CPUParticles3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(0.9, 0.9)
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.albedo_color = Color(0.20, 0.18, 0.20, 0.5)
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	qm.material = sm
	smoke.mesh = qm
	smoke.amount = 26
	smoke.lifetime = 2.6
	smoke.direction = Vector3(0.1, 1.0, 0.0)
	smoke.spread = 14.0
	smoke.initial_velocity_min = 1.2
	smoke.initial_velocity_max = 2.2
	smoke.gravity = Vector3.ZERO
	smoke.scale_amount_min = 0.6
	smoke.scale_amount_max = 1.8
	smoke.position = pos
	return smoke

## 雷劈下來（雷道具會叫這個）：p 是準心的位置。回傳要顯示給玩家的話（沒有就空字串）
func lightning_strike(p: Vector3) -> String:
	if _dead_tree == null or _tree_struck:
		return ""
	var tp := dead_tree_pos()
	if Vector2(p.x - tp.x, p.z - tp.z).length() > 7.0:
		return ""
	_tree_struck = true
	if _tree_mat:
		_tree_mat.set_shader_parameter("burnt", 1.0)
	_dead_tree.rotation.x = -0.11        # 劈開之後歪向河那一邊，看得出來快倒了
	# 冒一陣子煙
	_smoke = CPUParticles3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(0.9, 0.9)
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.albedo_color = Color(0.20, 0.18, 0.20, 0.5)
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	qm.material = sm
	_smoke.mesh = qm
	_smoke.amount = 26
	_smoke.lifetime = 2.6
	_smoke.direction = Vector3(0.1, 1.0, 0.0)
	_smoke.spread = 14.0
	_smoke.initial_velocity_min = 1.2
	_smoke.initial_velocity_max = 2.2
	_smoke.gravity = Vector3.ZERO
	_smoke.scale_amount_min = 0.6
	_smoke.scale_amount_max = 1.8
	_smoke.position = tp + Vector3(0.0, 3.6, 0.0)
	add_child(_smoke)
	return "枯樹被劈開了！現在朝河的方向吹風"

## 下雨／雨停：天色變暗、霧變濃（雨絲是雨道具自己畫的）
func set_rain(on: bool) -> void:
	raining = on
	_apply_time()

func _apply_time() -> void:
	super()
	# 島比較大，霧淡一點：不然從這一關看另一關，整片被黃霧蓋住，走過去才發現顏色不一樣
	if _env:
		_env.fog_density *= 0.6
	if raining:
		if _sun:
			_sun.light_energy *= 0.5
		if _env:
			_env.ambient_light_energy *= 0.8
			_env.fog_density *= 2.4

func _process(delta: float) -> void:
	_tick_glow_mat(delta)
	_tick_signs()
	if _dead_tree and _tree_fall >= 0.0 and _tree_fall < 1.0:
		_tree_fall = minf(_tree_fall + delta / 1.1, 1.0)
		# 一開始慢、越倒越快，最後彈一下
		var t := _tree_fall * _tree_fall
		var bounce := sin(clampf((_tree_fall - 0.86) / 0.14, 0.0, 1.0) * PI) * 0.05
		_dead_tree.rotation.x = -PI * 0.5 * t + bounce
		if _tree_fall >= 1.0:
			open_barrier()        # 橋搭好了，河上那道浮空柵欄就消失
	_spin_windmill(delta)
	for sn in _star_nodes.values():
		if is_instance_valid(sn):
			(sn as Node3D).rotate_y(delta * 1.6)        # 星星慢慢轉

## 家豪過橋要走的路（這一小關的座標，y 是腳要踩的高度）：樹根旁邊 → 沿著樹幹走過河 → 對岸
func bridge_path() -> Array[Vector3]:
	var tp := dead_tree_pos()
	var top := tp.y + 0.55        # 倒下來的樹幹上面
	return [
		Vector3(tp.x + 1.4, tp.y, tp.z + 0.6),
		Vector3(tp.x + 0.3, top, tp.z - 1.2),
		Vector3(tp.x, top, tp.z - 7.6),
		Vector3(tp.x + 0.6, _land_h(tp.x + 0.6, tp.z - 10.5), tp.z - 10.5),
	]

# ---------------------------------------------------------------- 風車

var _mill: Node3D
var _mill_wheel: Node3D
var _mill_speed := 0.0          # 葉片現在轉多快（弧度／秒）
var _mill_target := 0.0
var _wheel_home := Vector3.ZERO
var _wheel_tween: Tween

## 風車在哪（這一小關的座標）
func windmill_pos() -> Vector3:
	var x := MILL_POS.x + ZONE_ORIGIN[0].x + _off.x
	var z := MILL_POS.y + ZONE_ORIGIN[0].y + _off.y
	return Vector3(x, _land_h(x, z), z)

## 石頭砌的塔、深色的尖屋頂、四片葉片
func _build_windmill() -> void:
	_mill = Node3D.new()
	_mill.name = "Windmill"
	_mill.position = windmill_pos() - Vector3(0.0, 0.4, 0.0)
	_mill.scale = Vector3.ONE * MILL_SCALE
	_mill.rotation.y = PI * 0.75        # 葉片那一面朝東北（盆地中間）
	add_child(_mill)
	var tower := MeshInstance3D.new()
	var tm := CylinderMesh.new()
	tm.bottom_radius = 1.35
	tm.top_radius = 0.9
	tm.height = 5.6
	tm.radial_segments = 8
	tm.rings = 2
	tower.mesh = tm
	tower.material_override = _cliff_material()
	tower.position.y = 2.8
	_mill.add_child(tower)
	var roof := MeshInstance3D.new()
	var rm := CylinderMesh.new()
	rm.bottom_radius = 1.2
	rm.top_radius = 0.0
	rm.height = 1.5
	rm.radial_segments = 8
	roof.mesh = rm
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.30, 0.16, 0.14)
	dark.roughness = 1.0
	roof.material_override = dark
	roof.position.y = 6.3
	_mill.add_child(roof)
	# 葉片：面向南邊（+Z，鏡頭一開始在的那一側），繞著自己的 Z 軸轉
	_mill_wheel = Node3D.new()
	_mill_wheel.name = "Wheel"
	_wheel_home = Vector3(0.0, 4.7, 1.25)
	_mill_wheel.position = _wheel_home
	_mill_wheel.rotation.z = PI * 0.25        # 一開始葉片是斜的（X 形），不擋到頂上的星星
	_mill.add_child(_mill_wheel)
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.86, 0.76, 0.56)
	wood.roughness = 1.0
	var spar_mat := StandardMaterial3D.new()
	spar_mat.albedo_color = Color(0.34, 0.20, 0.14)
	spar_mat.roughness = 1.0
	for k in 4:
		var arm := Node3D.new()
		arm.rotation.z = PI * 0.5 * k
		_mill_wheel.add_child(arm)
		var spar := MeshInstance3D.new()
		var sb := BoxMesh.new()
		sb.size = Vector3(0.12, 3.3, 0.12)
		spar.mesh = sb
		spar.material_override = spar_mat
		spar.position.y = 1.65
		arm.add_child(spar)
		var sail := MeshInstance3D.new()
		var bb := BoxMesh.new()
		bb.size = Vector3(0.75, 2.5, 0.05)
		sail.mesh = bb
		sail.material_override = wood
		sail.position = Vector3(0.42, 1.95, 0.0)
		arm.add_child(sail)
	var hub := MeshInstance3D.new()
	var hm := SphereMesh.new()
	hm.radius = 0.28
	hm.height = 0.56
	hm.radial_segments = 8
	hm.rings = 4
	hub.mesh = hm
	hub.material_override = spar_mat
	_mill_wheel.add_child(hub)
	if stage_index == 1:
		var wp := windmill_pos()
		obstacles.append([Vector2(wp.x, wp.z), 1.5 * MILL_SCALE])        # 塔會擋路

## 葉片要轉多快（0 = 幾乎不動，3 = 快要飛出去）
func windmill_set_level(level: float) -> void:
	_mill_target = level * 4.5        # 沒風的時候不轉，停在斜斜的位置

## 葉片飛出去，掉在 to（這一小關的座標），dur 秒後落地
func windmill_launch(to: Vector3, dur: float) -> void:
	if _mill_wheel == null:
		return
	if _wheel_tween:
		_wheel_tween.kill()
	var from := _mill_wheel.global_position
	var land := Vector3(to.x, _land_h(to.x, to.z) + 0.4, to.z)
	_wheel_tween = create_tween()
	_wheel_tween.tween_method(func(t: float) -> void:
		var p := from.lerp(land, t)
		p.y += sin(t * PI) * 3.0          # 拋物線
		_mill_wheel.global_position = p
		_mill_wheel.rotation.x = -PI * 0.5 * t        # 邊飛邊倒，最後平躺在地上
		, 0.0, 1.0, dur)
	_mill_target = 0.0

## 重試：葉片裝回去
func windmill_reset() -> void:
	if _mill_wheel == null:
		return
	if _wheel_tween:
		_wheel_tween.kill()
	_mill_wheel.position = _wheel_home
	_mill_wheel.rotation = Vector3(0.0, 0.0, PI * 0.25)        # 回到一開始斜斜的樣子
	_mill_speed = 0.0
	_mill_target = 0.0

func _spin_windmill(delta: float) -> void:
	if _mill_wheel == null:
		return
	_mill_speed = lerpf(_mill_speed, _mill_target, clampf(delta * 2.5, 0.0, 1.0))
	_mill_wheel.rotate_object_local(Vector3(0, 0, 1), _mill_speed * delta)
	# 沒風、快停下來的時候，慢慢轉回最近的斜角（X 形），葉片不會停在星星前面
	if _mill_target <= 0.01 and _mill_speed < 0.6 and absf(_mill_wheel.rotation.x) < 0.01:
		var z: float = _mill_wheel.rotation.z
		var want: float = roundf((z - PI * 0.25) / (PI * 0.5)) * (PI * 0.5) + PI * 0.25
		_mill_wheel.rotation.z = lerpf(z, want, clampf(delta * 3.0, 0.0, 1.0))

# ---------------------------------------------------------------- 準心指到可以互動的東西：變白

var _hl_mat: StandardMaterial3D
var _hl_on := {}        # 哪些東西現在是亮的（避免每一畫面都重設）

## 把 root 底下所有模型蓋上一層白色（on = false 就拿掉）
func set_highlight(root: Node, on: bool) -> void:
	if root == null or _hl_on.get(root, false) == on:
		return
	_hl_on[root] = on
	_apply_overlay(root)

## 晚上的提示：可以互動的東西閃淡淡的藍綠色光（戰局每一畫面叫一次；亮度在 _process 裡一起閃）
## spec（可以不給）= {"pos": 圈底的中心, "r": 半徑, "h": 高度}：極光圈放在指定的位置，不照模型外框算
func set_glow(root: Node, on: bool, spec = null) -> void:
	if root == null or _glow_on.get(root, false) == on:
		return
	_glow_on[root] = on
	_apply_overlay(root)
	_set_ring(root, on, spec)

var _ring_mat: ShaderMaterial
var _rings := {}        # 每個發光的東西外面那一圈極光

## 一圈極光簾子圍住這個東西（大小照它的模型算）；關掉就拿掉
func _set_ring(root: Node, on: bool, spec = null) -> void:
	if _rings.has(root):
		if is_instance_valid(_rings[root]):
			_rings[root].queue_free()
		_rings.erase(root)
	if not on:
		return
	# 把底下所有模型的範圍合起來
	var box := AABB()
	var first := true
	var todo: Array = [root]
	while not todo.is_empty():
		var n: Node = todo.pop_back()
		if n is VisualInstance3D and (n as Node3D).is_inside_tree():
			var b: AABB = (n as VisualInstance3D).global_transform * (n as VisualInstance3D).get_aabb()
			if b.size.length() > 0.01:
				box = b if first else box.merge(b)
				first = false
		for c in n.get_children():
			todo.append(c)
	if first and spec == null:
		return
	var hh: float = box.size.y
	var r: float = maxf(box.size.x, box.size.z) * 0.5
	if hh > r * 1.6:
		r = minf(r, maxf(hh * 0.16, 1.4))        # 高高的東西（樹）：圈住樹幹就好，不用包到樹梢
	r = clampf(r * 1.05, 1.4, 12.0)
	var ch: float = clampf(maxf(hh * 0.4, r * 0.8), 3.0, 6.0)
	if hh < 1.0:
		ch = 2.6        # 扁扁的東西（水池）：矮矮一圈就好
	if _ring_mat == null:
		_ring_mat = ShaderMaterial.new()
		_ring_mat.shader = load("res://levels/liuchiyu/shaders/oil_aurora_ring.gdshader")
	var cm := CylinderMesh.new()
	cm.top_radius = 1.0
	cm.bottom_radius = 1.0
	cm.height = 1.0
	cm.radial_segments = 48
	cm.rings = 6
	cm.cap_top = false
	cm.cap_bottom = false
	var ring := MeshInstance3D.new()
	ring.name = "AuroraRing"
	ring.mesh = cm
	# 圈越大越淡，不然好幾個大圈疊在一起整個畫面會泛白
	var rm: ShaderMaterial = _ring_mat.duplicate()
	rm.set_shader_parameter("strength", clampf(1.9 / r, 0.3, 0.9))
	ring.material_override = rm
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.extra_cull_margin = 4.0
	add_child(ring)
	var c3 := box.get_center()
	var gy: float = maxf(box.position.y, height_at(c3.x, c3.z)) + 0.15
	if spec != null:
		r = spec.r
		ch = spec.h
		c3 = spec.pos
		gy = c3.y
		rm.set_shader_parameter("strength", clampf(1.9 / r, 0.3, 0.9))
	ring.global_transform = Transform3D(Basis.IDENTITY.scaled(Vector3(r, ch, r)), Vector3(c3.x, gy + ch * 0.5, c3.z))
	_rings[root] = ring

var _glow_mat: Material
var _glow_on := {}
var _glow_t := 0.0

func _tick_glow_mat(_delta: float) -> void:
	pass        # 光帶自己會動（shader 用 TIME），這裡不用做事

## 準心指到（白）優先，其次是晚上的極光，都沒有就拿掉
func _apply_overlay(root: Node) -> void:
	var on: bool = _hl_on.get(root, false)
	var glow: bool = _glow_on.get(root, false)
	if _hl_mat == null:
		_hl_mat = StandardMaterial3D.new()
		_hl_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_hl_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_hl_mat.albedo_color = Color(1.0, 1.0, 1.0, 0.24)        # 淺淺一層白
	if _glow_mat == null:
		var gm := ShaderMaterial.new()
		gm.shader = load("res://levels/liuchiyu/shaders/oil_glow.gdshader")
		_glow_mat = gm        # 像極光的光帶（顏色和飄動都在 shader 裡）
	var mat: Material = _hl_mat if on else (_glow_mat if glow else null)
	var todo: Array = [root]
	while not todo.is_empty():
		var n: Node = todo.pop_back()
		if n is GeometryInstance3D:
			(n as GeometryInstance3D).material_overlay = mat
		for c in n.get_children():
			todo.append(c)

## 枯樹、風車的節點（給戰局打亮用）
func dead_tree_node() -> Node3D:
	return _dead_tree
func windmill_node() -> Node3D:
	return _mill
## 風現在吹不吹得動枯樹（還站著、而且準心夠近）
func tree_in_reach(p: Vector3) -> bool:
	if _dead_tree == null or _tree_fall >= 0.0 or not _tree_struck:
		return false
	var tp := dead_tree_pos()
	return Vector2(p.x - tp.x, p.z - tp.z).length() <= 6.5

# ---------------------------------------------------------------- 可以長大、可以倒下來的樹（第二小關的幼苗用）

## 做一棵樹的模型（樹根在原點，高 h 公尺）。回傳 {"node": 節點, "mat": 樹幹的材質（burnt 參數可以把它燒焦）}。
## 幼苗就是把同一棵樹縮得很小，淋雨長大的時候慢慢放大。
func make_tree_node(h: float, seed_n: int) -> Dictionary:
	var root := Node3D.new()
	var r := RandomNumberGenerator.new()
	r.seed = world_seed + 400 + seed_n
	var col := Color(0.30, r.randf(), 0.30)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var top := Vector3(r.randf_range(-0.15, 0.15), h * 0.5, r.randf_range(-0.15, 0.15))
	_dead_seg(st, Vector3.ZERO, top, 0.36, 0.24, col)
	for k in 3:
		var ang := TAU * float(k) / 3.0 + r.randf_range(-0.4, 0.4)
		_dead_limb(st, r, top - Vector3(0.0, 0.2, 0.0), Vector3(cos(ang) * 0.55, 0.8, sin(ang) * 0.55).normalized(), h * 0.27, 0.2, 2, col)
	var m := ShaderMaterial.new()
	m.shader = TRUNK_SHADER
	var wood := MeshInstance3D.new()
	wood.name = "Wood"
	wood.mesh = st.commit()
	wood.material_override = m
	root.add_child(wood)
	# 樹冠：一堆朝各個方向的葉子筆觸
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var qm := QuadMesh.new()
	qm.size = Vector2(1.0, 1.0)
	mm.mesh = qm
	mm.instance_count = 170
	for i in 170:
		var d := Vector3(r.randf_range(-1.0, 1.0), r.randf_range(-0.7, 1.0), r.randf_range(-1.0, 1.0)).normalized() * pow(r.randf(), 0.5)
		var pos := Vector3(d.x * h * 0.3, h * 0.74 + d.y * h * 0.22, d.z * h * 0.3)
		var s := r.randf_range(0.5, 0.95)
		var b := Basis.from_euler(Vector3(r.randf() * TAU, r.randf() * TAU, r.randf() * TAU)).scaled(Vector3(s, s * 0.6, s))
		mm.set_instance_transform(i, Transform3D(b, pos))
		mm.set_instance_color(i, _leaf_color(r))
	var leaves := MultiMeshInstance3D.new()
	leaves.name = "Leaves"
	leaves.multimesh = mm
	leaves.material_override = _leaf_material()
	root.add_child(leaves)
	return {"node": root, "mat": m}

## 家豪從第二小關走上石階要走的路（這一小關的座標，y 是腳要踩的高度）：石階腳下 → 一階一階往上 → 高原上
func stairs_path() -> Array[Vector3]:
	var out: Array[Vector3] = []
	var d := (STAIR_B - STAIR_A).normalized()
	var pts: Array[Vector2] = [STAIR_A - d * 2.0]
	for i in 9:
		pts.append(STAIR_A.lerp(STAIR_B, float(i) / 8.0))
	pts.append(STAIR_B + d * 2.5)
	for q in pts:
		var x := q.x + _off.x
		var z := q.y + _off.y
		out.append(Vector3(x, _land_h(x, z) + 0.3, z))
	return out

# ---------------------------------------------------------------- 火山

var _volcano: Node3D
var _lava: MeshInstance3D
var _lava_mat: ShaderMaterial
var _lava_light: OmniLight3D
var _flow_mat: ShaderMaterial        # 山坡上那幾道岩漿流
var _sparks: CPUParticles3D

## 火山口邊緣的位置（這一小關的座標）
func volcano_top() -> Vector3:
	var x := VOLCANO_C.x + _off.x
	var z := VOLCANO_C.y + _off.y
	return Vector3(x, _land_h(x + CRATER_R, z), z)

func volcano_node() -> Node3D:
	return _volcano

## 岩漿用的材質（噴出去的岩漿塊、落地的岩漿也用這個）
func lava_material(heat := 1.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = LAVA_SHADER
	m.set_shader_parameter("heat", heat)
	return m

## 火山：整座山包一層深色的岩石、幾道從火山口流下山坡的岩漿、火山口裡的岩漿、
## 往上噴的岩漿火花、橘色的光、往上冒的煙
func _build_volcano() -> void:
	_volcano = Node3D.new()
	_volcano.name = "Volcano"
	_volcano.position = volcano_top()
	add_child(_volcano)
	var cx := VOLCANO_C.x + _off.x
	var cz := VOLCANO_C.y + _off.y
	# 山體：貼著地形鋪一層深色的岩石（地形本身是落葉的顏色，蓋掉它）
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := 16
	var segs := 44
	var grid: Array = []
	for i in rings + 1:
		var rr := (VOLCANO_R + 0.6) * float(i) / rings
		var row: Array[Vector3] = []
		for j in segs:
			var a := TAU * float(j) / segs
			var x := cx + cos(a) * rr
			var z := cz + sin(a) * rr
			row.append(Vector3(x, _land_h(x, z) + 0.07, z))
		grid.append(row)
	for i in rings:
		for j in segs:
			var j2 := (j + 1) % segs
			var q: Array = [grid[i][j], grid[i + 1][j], grid[i + 1][j2], grid[i][j2]]
			for t in [0, 1, 2, 0, 2, 3]:
				st.add_vertex(q[t])
	st.generate_normals()
	var rock_mat := ShaderMaterial.new()
	rock_mat.shader = ROCK_SHADER
	rock_mat.set_shader_parameter("origin", _ground_origin())
	# 比懸崖的岩石深很多的火山岩，上面不要有落葉的斑點
	var lava_rock := Color(0.13, 0.11, 0.13)
	rock_mat.set_shader_parameter("shade", Color(0.06, 0.05, 0.07))
	rock_mat.set_shader_parameter("half_tone", Color(0.17, 0.14, 0.16))
	rock_mat.set_shader_parameter("light", Color(0.34, 0.28, 0.27))
	for key in ["leaf_a", "leaf_b", "night_leaf_a", "night_leaf_b"]:
		rock_mat.set_shader_parameter(key, lava_rock)
	var cone := MeshInstance3D.new()
	cone.name = "Cone"
	cone.mesh = st.commit()
	cone.material_override = rock_mat
	cone.top_level = true        # 頂點已經是這一小關的座標，不要再被 Volcano 節點的位置加一次
	_volcano.add_child(cone)
	cone.global_transform = Transform3D.IDENTITY
	# 山腳堆一圈大石頭（同一種火山岩）：火山才不會像一個圓錐直接插在地上
	var r := RandomNumberGenerator.new()
	r.seed = world_seed + 311
	var bsm := SphereMesh.new()
	bsm.radius = 1.0
	bsm.height = 2.0
	bsm.radial_segments = 6
	bsm.rings = 3
	var bxf: Array[Transform3D] = []
	for k in 44:
		var a := r.randf() * TAU
		# 只堆在山腳那一圈（山坡上不放，山的輪廓才乾淨）
		var rr := r.randf_range(VOLCANO_R - 0.6, VOLCANO_R + 2.6)
		var sc := r.randf_range(1.1, 2.9)
		var x := cx + cos(a) * rr
		var z := cz + sin(a) * rr
		var bb := Basis.from_euler(Vector3(r.randf() * TAU, r.randf() * TAU, r.randf() * TAU)).scaled(Vector3(sc * r.randf_range(0.9, 1.5), sc * r.randf_range(0.7, 1.2), sc * r.randf_range(0.9, 1.4)))
		bxf.append(Transform3D(bb, Vector3(x, _land_h(x, z) + sc * 0.15, z)))
	var bmm := MultiMesh.new()
	bmm.transform_format = MultiMesh.TRANSFORM_3D
	bmm.mesh = bsm
	bmm.instance_count = bxf.size()
	for i in bxf.size():
		bmm.set_instance_transform(i, bxf[i])
	var boulders := MultiMeshInstance3D.new()
	boulders.name = "VolcanoRocks"
	boulders.multimesh = bmm
	boulders.material_override = rock_mat
	boulders.top_level = true
	_volcano.add_child(boulders)
	boulders.global_transform = Transform3D.IDENTITY
	# 岩漿流：從火山口邊緣一路流到山腳，貼著山坡、彎彎曲曲、越往下越寬
	var ls := SurfaceTool.new()
	ls.begin(Mesh.PRIMITIVE_TRIANGLES)
	ls.set_normal(Vector3.UP)
	for ang in [PI - 0.55, PI + 0.35, PI * 0.5 + 0.3, -PI * 0.5 - 0.25, 0.35]:
		var steps := 14
		var prev_l := Vector3.ZERO
		var prev_r := Vector3.ZERO
		var phase := r.randf() * TAU
		var length := r.randf_range(0.8, 1.0)
		for i in steps + 1:
			var t := float(i) / steps
			var rr := lerpf(CRATER_R - 0.3, (VOLCANO_R - 0.4) * length, t)
			var a: float = ang + sin(t * 5.0 + phase) * 0.16 * t
			var w := lerpf(0.28, 0.75, t)
			var dir := Vector2(cos(a), sin(a))
			var side := Vector2(-dir.y, dir.x) * w
			var c := Vector2(cx, cz) + dir * rr
			var pl := Vector3(c.x - side.x, _land_h(c.x - side.x, c.y - side.y) + 0.17, c.y - side.y)
			var pr := Vector3(c.x + side.x, _land_h(c.x + side.x, c.y + side.y) + 0.17, c.y + side.y)
			if i > 0:
				for v in [prev_l, prev_r, pr, prev_l, pr, pl]:
					ls.add_vertex(v)
			prev_l = pl
			prev_r = pr
	var flows := MeshInstance3D.new()
	flows.name = "LavaFlows"
	flows.mesh = ls.commit()
	_flow_mat = lava_material()
	flows.material_override = _flow_mat
	flows.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flows.top_level = true
	_volcano.add_child(flows)
	flows.global_transform = Transform3D.IDENTITY
	# 火山口裡的岩漿
	_lava = MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = CRATER_R
	cm.bottom_radius = CRATER_R
	cm.height = 0.12
	cm.radial_segments = 16
	_lava.mesh = cm
	_lava_mat = lava_material()
	_lava.material_override = _lava_mat
	_lava.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_volcano.add_child(_lava)
	_lava_light = OmniLight3D.new()
	_lava_light.light_color = Color(1.0, 0.45, 0.12)
	_lava_light.omni_range = 16.0
	_lava_light.position.y = 1.0
	_volcano.add_child(_lava_light)
	# 往上噴的岩漿火花：越快噴發噴得越高
	_sparks = CPUParticles3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.16, 0.34, 0.16)
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.albedo_color = Color(3.0, 1.3, 0.25)        # 很亮，會發光
	bm.material = fm
	_sparks.mesh = bm
	_sparks.amount = 70
	_sparks.lifetime = 1.5
	_sparks.local_coords = false
	_sparks.particle_flag_align_y = true
	_sparks.direction = Vector3.UP
	_sparks.spread = 16.0
	_sparks.gravity = Vector3(0.0, -9.0, 0.0)
	_sparks.initial_velocity_min = 4.0
	_sparks.initial_velocity_max = 8.0
	_sparks.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_sparks.emission_sphere_radius = 0.9
	_sparks.scale_amount_min = 0.5
	_sparks.scale_amount_max = 1.3
	_volcano.add_child(_sparks)
	var smoke := CPUParticles3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(1.1, 1.1)
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.albedo_color = Color(0.20, 0.17, 0.19, 0.6)
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	qm.material = sm
	smoke.mesh = qm
	smoke.amount = 46
	smoke.lifetime = 4.5
	smoke.direction = Vector3(0.15, 1.0, 0.0)
	smoke.spread = 12.0
	smoke.initial_velocity_min = 1.4
	smoke.initial_velocity_max = 2.4
	smoke.gravity = Vector3.ZERO
	smoke.scale_amount_min = 0.7
	smoke.scale_amount_max = 2.4
	smoke.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	smoke.emission_sphere_radius = 1.0
	smoke.position.y = 2.0
	_volcano.add_child(smoke)
	volcano_set(0.6)

## 岩漿漲到多高（0 = 沉在火山口底，1 = 滿到邊緣、快噴出來了）
func volcano_set(pressure: float) -> void:
	if _lava == null:
		return
	var k := clampf(pressure, 0.0, 1.0)
	_lava.position.y = lerpf(-1.5, -0.1, k)
	_lava_mat.set_shader_parameter("heat", 0.45 + 0.55 * k)
	_lava_light.light_energy = 0.8 + 4.2 * k
	if _flow_mat:
		_flow_mat.set_shader_parameter("heat", 0.55 + 0.45 * k)
	if _sparks:
		# 岩漿越滿，火花噴得越高
		_sparks.initial_velocity_min = 3.0 + 5.0 * k
		_sparks.initial_velocity_max = 5.5 + 9.0 * k

## 做一棵枯樹的模型（樹根在原點，高 h 公尺）：粗樹幹、根往外張、幾根大枝幹分岔成禿枝，沒有葉子。
## 回傳 {"node": 節點, "mat": 樹幹的材質（burnt 參數可以把它燒焦）}。第二小關的枯樹用這個。
## bare 版的樹（高 h）在離樹根 s 公尺的地方，樹幹有多粗（半徑）
func dead_trunk_radius(h: float, s: float) -> float:
	var k := h / 11.0
	if s <= 1.5 * k:
		return lerpf(0.95, 0.72, s / (1.5 * k)) * k
	if s <= 3.3 * k:
		return lerpf(0.72, 0.60, (s - 1.5 * k) / (1.8 * k)) * k
	return lerpf(0.52, 0.30, clampf((s - 3.3 * k) / (h - 5.2 * k), 0.0, 1.0)) * k

## bare = 樹幹上沒有往旁邊岔的大枝幹，只有樹梢分岔（倒下來當橋的那一棵用：家豪踩在上面走，不會穿過翹起來的樹枝）
func make_dead_tree_node(h: float, seed_n: int, sparse := false, bare := false) -> Dictionary:
	var root := Node3D.new()
	var r := RandomNumberGenerator.new()
	r.seed = world_seed + 600 + seed_n
	var k := h / 11.0        # 以河邊那棵（11 公尺）為準，照比例縮
	var col := Color(0.40, r.randf(), 0.30)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var p0 := Vector3.ZERO
	var p1 := Vector3(r.randf_range(-0.15, 0.15), 1.5, r.randf_range(-0.1, 0.1)) * k
	var p2 := Vector3(r.randf_range(-0.15, 0.15), 3.3, r.randf_range(-0.1, 0.1)) * k
	_dead_seg(st, p0, p1, 0.95 * k, 0.72 * k, col)
	_dead_seg(st, p1, p2, 0.72 * k, 0.6 * k, col)
	for i in 5:
		var ang := TAU * float(i) / 5.0 + r.randf_range(-0.3, 0.3)
		var out := Vector3(cos(ang), 0.0, sin(ang))
		_dead_seg(st, Vector3(0.0, 0.9 * k, 0.0) + out * 0.3 * k, out * r.randf_range(1.4, 2.0) * k + Vector3(0.0, -0.1, 0.0), 0.4 * k, 0.1 * k, col.darkened(0.12))
	# 主幹幾乎直直往上（倒下去的時候就是它壓在地上），旁邊兩三根大枝幹往外岔
	# sparse = 分枝少的版本：主幹只分兩層，旁邊只有兩根大枝幹
	if bare:
		# 當橋的那一棵：樹幹筆直往上、慢慢變細（倒下來之後家豪要踩在上面走，粗細見 dead_trunk_radius()），只有樹梢岔兩根小枝
		var p3 := Vector3(0.0, h - 1.9 * k, 0.0)
		_dead_seg(st, p2, p3, 0.52 * k, 0.30 * k, col)
		for i in 2:
			var ta := r.randf() * TAU
			_dead_limb(st, r, p3, Vector3(cos(ta) * 0.5, 0.8, sin(ta) * 0.5).normalized(), 1.9 * k, 0.24 * k, 0, col)
	else:
		_dead_limb(st, r, p2, Vector3(r.randf_range(-0.08, 0.08), 1.0, r.randf_range(-0.08, 0.08)).normalized(), h - 5.2 * k, 0.52 * k, 2 if sparse else 3, col)
	var a0 := r.randf() * TAU
	var side_n := 0 if bare else (2 if sparse else 3)
	for i in side_n:
		var ang := a0 + TAU * float(i) / float(side_n) + r.randf_range(-0.3, 0.3)
		var depth := 1 if sparse else (2 if i == 2 else 3)
		_dead_limb(st, r, p2 - Vector3(0.0, 0.3 * k * float(i), 0.0), Vector3(cos(ang) * 0.72, 0.68, sin(ang) * 0.72).normalized(), r.randf_range(2.4, 3.2) * k, 0.38 * k, depth, col)
	var m := ShaderMaterial.new()
	m.shader = TRUNK_SHADER
	var wood := MeshInstance3D.new()
	wood.name = "Wood"
	wood.mesh = st.commit()
	wood.material_override = m
	root.add_child(wood)
	return {"node": root, "mat": m}

# ---------------------------------------------------------------- 淺水池

var _pool_nodes := {}        # 第幾小關（從 0 算）→ 那一關的水池節點（陣列）

## 水池在這個方向（從中心看出去）的岸邊離中心多遠：幾個不同頻率的起伏疊起來，岸邊才會歪歪扭扭的
## ph = 這個池子自己的形狀（每個池子給不一樣的數字，岸邊凹凸的地方就不一樣：有的長、有的圓、有的像豆子）
func _pool_r(base: float, rel: Vector2, ph := 0.0) -> float:
	var a := atan2(rel.y, rel.x)
	return base * (1.0 + 0.20 * sin(a * 2.0 + 1.0 + ph * 2.3) + 0.14 * sin(a * 3.0 + 2.3 + ph * 4.1) + 0.09 * sin(a * 5.0 + 0.4 + ph * 1.7) + 0.05 * sin(a * 7.0 + 4.0 + ph * 3.3))

## 池子中間小島在這個方向的半徑（也是歪歪扭扭的）
func _isle_r(base: float, rel: Vector2) -> float:
	var a := atan2(rel.y, rel.x)
	return base * (1.0 + 0.18 * sin(a * 2.0 + 3.0) + 0.12 * sin(a * 3.0 + 0.7))

## 這個位置（這一小關的座標）是不是在第 n 小關的淺水池裡（margin > 0 = 岸邊外面一點也算）。
## whole = true：中間的小島也算在池子的範圍裡（瞄準用：準心指在小島上也是在劈這個池子）
func in_pool(n: int, x: float, z: float, margin := 0.0, whole := false) -> bool:
	var p := _isl(x, z)
	for pool in ZONE_POOLS[n - 1]:
		var rel: Vector2 = p - (pool.center + ZONE_ORIGIN[n - 1])
		var isle: float = pool.get("isle", 0.0)
		if not whole and isle > 0.0 and rel.length() <= _isle_r(isle, rel) + 0.15:
			continue        # 站在中間的小島上，不算在水裡
		if rel.length() <= _pool_r(float(pool.r), rel, float(pool.get("ph", 0.0))) - 0.2 + margin:
			return true
	return false

## 第 n 小關的淺水池：[{"center": 這一小關座標的位置, "r": 平均半徑, "node": 水面的節點}]
func zone_pools(n: int) -> Array:
	var out: Array = []
	var list: Array = ZONE_POOLS[n - 1]
	for i in list.size():
		var c: Vector2 = list[i].center + ZONE_ORIGIN[n - 1] + _off
		var nodes: Array = _pool_nodes.get(n - 1, [])
		out.append({"center": Vector3(c.x, _land_h(c.x, c.y), c.y), "r": float(list[i].r), "isle": float(list[i].get("isle", 0.0)), "node": nodes[i] if i < nodes.size() else null})
	return out

## 水面：照著不規則的岸邊做一片水，用跟海一樣的筆觸（一圈一圈繞著水池中心），靠岸的地方有白色水花
## 第 k 小關（從 0 算）某個水池的水面高度：量池子裡水底的地面（不是中間的島），再高一點點。
## 用 _land_h() 量，所以高原上的湖也會在高原的高度
func pool_water_y(k: int, pool: Dictionary) -> float:
	var mid: float = (float(pool.get("isle", 0.0)) + float(pool.r)) * 0.5
	var q: Vector2 = pool.center + ZONE_ORIGIN[k] + Vector2(0.0, mid) + _off
	return _land_h(q.x, q.y) + 0.24

func _build_pools() -> void:
	for k in ZONE_POOLS.size():
		var nodes: Array = []
		for pool in ZONE_POOLS[k]:
			var c: Vector2 = pool.center + ZONE_ORIGIN[k] + _off
			var y := pool_water_y(k, pool)        # 水面比池底高一點
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			st.set_normal(Vector3.UP)
			var seg := 48
			for i in seg:
				var a0 := TAU * float(i) / seg
				var a1 := TAU * float(i + 1) / seg
				var d0 := Vector2(cos(a0), sin(a0))
				var d1 := Vector2(cos(a1), sin(a1))
				var r0 := _pool_r(float(pool.r), d0, float(pool.get("ph", 0.0))) - 0.2
				var r1 := _pool_r(float(pool.r), d1, float(pool.get("ph", 0.0))) - 0.2
				# 中心（頂點顏色 1 = 深水）→ 岸邊（0.25 = 淺，有水花）；順序要讓面朝上
				st.set_color(Color(1, 0, 0))
				st.add_vertex(Vector3(c.x, y, c.y))
				st.set_color(Color(0.25, 0, 0))
				st.add_vertex(Vector3(c.x + d0.x * r0, y, c.y + d0.y * r0))
				st.set_color(Color(0.25, 0, 0))
				st.add_vertex(Vector3(c.x + d1.x * r1, y, c.y + d1.y * r1))
			var m := ShaderMaterial.new()
			m.shader = SEA_SHADER
			m.set_shader_parameter("sun_dir", SUN_DIR)
			m.set_shader_parameter("center", c)
			m.set_shader_parameter("night", 1.0 if night else 0.0)
			_leaf_mats.append(m)
			var water := MeshInstance3D.new()
			water.name = "Pool"
			water.mesh = st.commit()
			water.material_override = m
			water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(water)
			nodes.append(water)
		_pool_nodes[k] = nodes

# ---------------------------------------------------------------- 別的小關留下來的樣子

## 玩家在第 n 小關離開的時候，那一關的東西是什麼樣子（戰局換關時用 remember_zone() 記下來）。沒記過就是空的
static func zone_memory(n: int) -> Dictionary:
	var all: Dictionary = Engine.get_meta("liuchiyu_isle", {})
	return all.get(n, {})

static func remember_zone(n: int, state: Dictionary) -> void:
	var all: Dictionary = Engine.get_meta("liuchiyu_isle", {})
	all[n] = state
	Engine.set_meta("liuchiyu_isle", all)

static func forget_zones() -> void:
	if Engine.has_meta("liuchiyu_isle"):
		Engine.remove_meta("liuchiyu_isle")
	if Engine.has_meta("liuchiyu_stars"):
		Engine.remove_meta("liuchiyu_stars")

# ---------------------------------------------------------------- 星星（整個大關最後看拿到幾顆）

const STAR_TOTAL := 3
## 第一小關的星星掉下來之後落在哪（那一小關的座標）：盆地正中間
const STAR1_LAND := Vector2(0.0, 1.0)

## 第 n 小關的星星拿到了沒
static func star_taken(n: int) -> bool:
	var all: Dictionary = Engine.get_meta("liuchiyu_stars", {})
	return all.get(n, false)

static func take_star(n: int) -> void:
	var all: Dictionary = Engine.get_meta("liuchiyu_stars", {})
	all[n] = true
	Engine.set_meta("liuchiyu_stars", all)

static func star_count() -> int:
	var all: Dictionary = Engine.get_meta("liuchiyu_stars", {})
	return all.size()

var _star_nodes := {}        # 第幾小關 → 那一關星星的節點（拿走了就沒有）

func star_node(n: int) -> Node3D:
	return _star_nodes.get(n, null)

## 第 n 小關的星星一開始在哪（這一小關的座標）：第一關在風車頂上，第二關在水池中間的小島上
func star_home(n: int) -> Vector3:
	if n == 1:
		return windmill_pos() + Vector3(0.0, 7.2 * MILL_SCALE + 1.4, 0.0)
	if n == 2:
		return star_rock_top() + Vector3(0.0, 1.5, 0.0)        # 外海的礁石上
	if n == 3:
		var c3: Vector2 = ZONE_POOLS[2][0].center + ZONE_ORIGIN[2] + _off
		return Vector3(c3.x, _land_h(c3.x, c3.y) + 1.5, c3.y)        # 小湖中間的島上
	return Vector3.ZERO

## 第二小關外海那塊礁石的頂（這一小關的座標）：跟海岸那棵枯樹的樹根差不多高，樹倒過來剛好搭在上面
func star_rock_top() -> Vector3:
	var q := _zone_xz(1, STAR_ROCK)
	var t := _zone_xz(1, Vector2(GROVE_TREES[GROVE_BRIDGE].x, GROVE_TREES[GROVE_BRIDGE].z))
	return Vector3(q.x, _land_h(t.x, t.y) + 0.1, q.y)

## 那塊礁石：一顆從海裡冒出來的大石頭（跟海上其他礁石同一種岩石）
func _build_star_rock() -> void:
	var top := star_rock_top()
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.radial_segments = 8
	sm.rings = 4
	var mi := MeshInstance3D.new()
	mi.name = "StarRock"
	mi.mesh = sm
	mi.material_override = _cliff_material()
	var hh := 5.5        # 石頭一半的高度：頂在 top，底下一直埋進海裡
	mi.transform = Transform3D(Basis(Vector3.UP, 0.6).scaled(Vector3(STAR_ROCK_R, hh, STAR_ROCK_R * 0.9)), Vector3(top.x, top.y - hh, top.z))
	add_child(mi)

## 一顆立體的金色五角星：胖胖的、正面和背面都鼓起來，每個尖角是一個小斜面，會被光照出明暗
func make_star_node() -> Node3D:
	var root := Node3D.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts: Array[Vector3] = []
	for i in 10:
		var a := TAU * float(i) / 10.0 + PI * 0.5
		var rr := 0.9 if i % 2 == 0 else 0.5        # 尖角 / 凹進去的地方（凹得淺一點，星星才胖）
		pts.append(Vector3(cos(a) * rr, sin(a) * rr, 0.0))
	for side in [1.0, -1.0]:
		var apex := Vector3(0.0, 0.0, 0.34 * float(side))        # 正面、背面各鼓起來一個頂點
		for i in 10:
			var p0 := pts[i]
			var p1 := pts[(i + 1) % 10]
			var n: Vector3 = (p0 - apex).cross(p1 - apex).normalized() * float(side)
			st.set_normal(n)
			if float(side) > 0.0:
				st.add_vertex(apex)
				st.add_vertex(p1)
				st.add_vertex(p0)
			else:
				st.add_vertex(apex)
				st.add_vertex(p0)
				st.add_vertex(p1)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.80, 0.14)
	m.roughness = 0.35
	m.metallic = 0.25
	m.emission_enabled = true
	m.emission = Color(1.0, 0.62, 0.08)
	m.emission_energy_multiplier = 1.5         # 自己會發光，遠遠就看得到
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.85, 0.4)
	light.light_energy = 3.2
	light.omni_range = 8.0
	root.add_child(light)
	# 外面一團光暈和幾道光芒（永遠正對鏡頭）
	var halo := MeshInstance3D.new()
	halo.name = "StarGlow"
	var hq := QuadMesh.new()
	hq.size = Vector2(5.5, 5.5)
	halo.mesh = hq
	var hm := ShaderMaterial.new()
	hm.shader = load("res://levels/liuchiyu/shaders/oil_star_glow.gdshader")
	halo.material_override = hm
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(halo)
	return root

## 每一小關還沒被拿走的星星都擺出來（不是現在這一關的也看得到）
func _build_stars() -> void:
	for n in [1, 2, 3]:
		if star_taken(n):
			continue
		var node := make_star_node()
		node.name = "Star%d" % n
		add_child(node)
		var pos := star_home(n)
		if n == 1 and stage_index != 1 and zone_memory(1).get("mill_gone", false):
			# 風車的葉片已經被吹掉了：星星掉在第一小關盆地的正中間
			var wp := _zone_xz(0, STAR1_LAND)
			pos = Vector3(wp.x, _land_h(wp.x, wp.y) + 1.3, wp.y)
		node.position = pos
		_star_nodes[n] = node

## 崖壁上那棵枯樹的樹根（這一小關的座標；往崖壁裡面埋一點）
func gate_rock_top() -> Vector3:
	var gp := _zone_xz(1, GATE_ROOT)
	return Vector3(gp.x, _land_h(gp.x, gp.y) - 0.4, gp.y)

func _gate_mid() -> Vector3:
	var a: Vector3 = _zone_xz3(GATE_GUARDS[0])
	var b: Vector3 = _zone_xz3(GATE_GUARDS[1])
	return (a + b) * 0.5

func _zone_xz3(v: Vector3) -> Vector3:
	var q := _zone_xz(1, Vector2(v.x, v.z))
	return Vector3(q.x, 0.0, q.y)

## 那棵樹伸向哪邊（朝兩個守門員中間），水平方向
func gate_tree_dir() -> Vector3:
	var r := gate_rock_top()
	var m := _gate_mid()
	return Vector3(m.x - r.x, 0.0, m.z - r.z).normalized()

## 樹幹底下的地面中點（瞄準、發光用）
func gate_tree_mid() -> Vector3:
	var r := gate_rock_top()
	var q := r + gate_tree_dir() * (GATE_TREE_H * 0.5 * sin(GATE_LEAN))
	return Vector3(q.x, height_at(q.x, q.z), q.z)

## p 離那棵樹（從樹根到樹梢，看水平位置）多遠
func gate_tree_dist(p: Vector3) -> float:
	var r := gate_rock_top()
	var d := gate_tree_dir()
	var rel := Vector3(p.x - r.x, 0.0, p.z - r.z)
	var along := clampf(rel.dot(d), 0.0, GATE_TREE_H * sin(GATE_LEAN))
	return (rel - d * along).length()

## 樹的朝向：k = 0 還側著長在崖壁上；k = 1 整棵倒下來、樹梢砸在守門員那裡的地上
## （樹根在崖壁上比地面高，所以要倒超過 90 度樹梢才碰得到地）
func gate_tree_fallen_basis(k := 1.0) -> Basis:
	var d := gate_tree_dir()
	var r := gate_rock_top()
	var m := _gate_mid()
	var drop: float = maxf(r.y - height_at(m.x, m.z), 0.0)
	var done: float = PI * 0.5 + asin(clampf(drop / GATE_TREE_H, 0.0, 1.0))
	return Basis(Vector3.UP.cross(d).normalized(), lerpf(GATE_LEAN, done, k))

## 第 k 小關（從 0 算）的座標 → 現在這一小關的座標
func _zone_xz(k: int, v: Vector2) -> Vector2:
	return v + ZONE_ORIGIN[k] + _off

## 不是現在這一關的那些機關，也照樣擺出來（只有外觀）：
## 第一小關的滾石和風車葉片、第二小關的枯樹林。玩過的話照離開時的樣子擺（倒的樹還是倒的），沒玩過就是原本的樣子
func _build_remembered() -> void:
	if stage_index != 1:
		var m1 := zone_memory(1)
		var rp := _zone_xz(0, m1.get("rock", ROCK_HOME))
		var rock := MeshInstance3D.new()
		rock.name = "FarRock"
		var sm := SphereMesh.new()
		sm.radius = ROCK_RADIUS
		sm.height = ROCK_RADIUS * 2.0
		sm.radial_segments = 7
		sm.rings = 4
		rock.mesh = sm
		rock.material_override = _cliff_material()
		rock.position = Vector3(rp.x, _land_h(rp.x, rp.y) + ROCK_RADIUS * 0.85, rp.y)
		add_child(rock)
		if m1.get("mill_gone", false) and _mill_wheel:
			# 葉片已經被吹掉了：平躺在它掉下去的地方
			var wp := _zone_xz(0, m1.get("wheel", Vector2.ZERO))
			_mill_wheel.global_position = Vector3(wp.x, _land_h(wp.x, wp.y) + 0.4, wp.y)
			_mill_wheel.rotation.x = -PI * 0.5
			_mill_target = 0.0
	# 崖壁上側著長的那棵枯樹：第二小關由戰局自己管，別的關照離開時的樣子擺
	if stage_index != 2:
		var gmade := make_dead_tree_node(GATE_TREE_H, 99, true)
		var gnode: Node3D = gmade.node
		gnode.name = "FarGateTree"
		add_child(gnode)
		var gb := gate_tree_fallen_basis(0.0)
		if zone_memory(2).get("gate_tree", false):
			(gmade.mat as ShaderMaterial).set_shader_parameter("burnt", 1.0)
			gb = gate_tree_fallen_basis()
			gnode.visible = false        # 掉下來砸完守門員之後就消失了
		gnode.transform = Transform3D(gb, gate_rock_top())
	if stage_index != 2:
		var trees: Array = zone_memory(2).get("trees", [])
		for k in GROVE_TREES.size():
			var made := make_dead_tree_node(GROVE_H, k, true)
			var node: Node3D = made.node
			node.name = "FarGrove%d" % k
			add_child(node)
			var p := _zone_xz(1, Vector2(GROVE_TREES[k].x, GROVE_TREES[k].z))
			var basis := Basis(Vector3.UP, float(k) * 1.7)
			if k < trees.size():
				var t: Dictionary = trees[k]
				if t.get("struck", false):
					(made.mat as ShaderMaterial).set_shader_parameter("burnt", 1.0)
				if t.get("fallen", false):
					var d: Vector2 = t.get("dir", Vector2.RIGHT)
					basis = Basis(Vector3.UP.cross(Vector3(d.x, 0.0, d.y)).normalized(), PI * 0.5) * basis
				if t.get("gone", false):
					node.visible = false        # 倒下之後已經消失的樹（搭到小島的那棵會留著）
			node.transform = Transform3D(basis, Vector3(p.x, _land_h(p.x, p.y) - 0.25, p.y))

