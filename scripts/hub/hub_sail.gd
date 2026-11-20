extends RefCounted
## 出航（實驗）：家豪在碼頭上船，真的開船去不同的島。這個檔案只管「海上的位置」：
##   - 島是一圈一圈的障礙（用世界地圖上每座島的中心和半徑），船碰到只會沿著岸滑開，開不上島。
##   - 船的操作：W 加速、S 煞車／倒車、A／D 轉彎；有慣性，轉彎和速度有關。
##   - 自動航行：照島的位置用格子找一條繞過所有島的路（A*），再用「看前面一點」的方式自己轉彎。
##   - 靠岸：離哪座島的岸邊夠近就能靠岸；level_select.gd 管畫面、鏡頭、按鍵和上下船的動作。

const MAX_SPEED := 24.0       # 全速（公尺／秒）
const ACCEL := 15.0
const DRAG := 7.0             # 放開 W 之後多快慢下來
const BACK_SPEED := -5.0
const TURN := 1.7             # 轉彎速度（弧度／秒，全速時）
const SCALE := 1.06           # 島的岸邊畫得比算的大一點點，所以多留 6%
const MARGIN := 2.5           # 離岸邊再多留幾公尺（船身半徑）
const DOCK_RANGE := 13.0      # 離岸邊多近可以靠岸
const PLAN_MARGIN := 3.0      # 自動航行規劃路線時，離（已經留了餘裕的）岸邊至少再多遠；島和島之間只隔 18～26 公尺，不能留太多
const CELL := 4.0             # 找路用的格子大小
const OUT := 70.0             # 最外面的島再往外多遠，是海的邊界

var map                       # 選關畫面（level_select.gd）
var isles: Array = []         # {"e": 第幾座, "c": 中心 Vector2(x, z), "rx", "rz"}
var lo := Vector2.ZERO        # 海的邊界（西北角）
var hi := Vector2.ZERO        # 海的邊界（東南角）

## 蓋完所有的島之後呼叫一次
func build() -> void:
	isles.clear()
	lo = Vector2(INF, INF)
	hi = Vector2(-INF, -INF)
	for e in map.worlds.size():
		var w: Dictionary = map.worlds[e]
		var c := Vector2(float(w.center.x), float(w.center.z))
		var rx := float(w.rx)
		var rz := float(w.rz)
		isles.append({"e": e, "c": c, "rx": rx, "rz": rz})
		lo = Vector2(minf(lo.x, c.x - rx), minf(lo.y, c.y - rz))
		hi = Vector2(maxf(hi.x, c.x + rx), maxf(hi.y, c.y + rz))
	lo -= Vector2(OUT, OUT)
	hi += Vector2(OUT, OUT)

## 第 e 座島（isles 的索引）從中心往 a 這個方向，船碰得到的岸邊在多遠
func edge(i: int, a: float) -> float:
	var s: Dictionary = isles[i]
	return map._outline(float(s.rx), float(s.rz), a, 0.0) * SCALE + MARGIN

## 點 p 離第 i 座島的岸邊多遠（負的 = 在島裡面）
func shore(i: int, p: Vector2) -> float:
	var s: Dictionary = isles[i]
	var d: Vector2 = p - (s.c as Vector2)
	return d.length() - edge(i, atan2(d.y, d.x))

## 最近的島：{"i": isles 的索引, "e": 第幾座, "d": 離岸邊多遠}
func nearest(p: Vector2) -> Dictionary:
	var best := {"i": -1, "e": -1, "d": INF}
	for i in isles.size():
		var d := shore(i, p)
		if d < float(best.d):
			best = {"i": i, "e": int(isles[i].e), "d": d}
	return best

## 把船推出所有的島、留在海的邊界裡（碰到就沿著岸滑）
func resolve(p: Vector2) -> Vector2:
	for _k in 2:
		for i in isles.size():
			var s: Dictionary = isles[i]
			var d: Vector2 = p - (s.c as Vector2)
			var a := atan2(d.y, d.x)
			var r := edge(i, a)
			if d.length() < r:
				p = (s.c as Vector2) + Vector2(cos(a), sin(a)) * r
	return Vector2(clampf(p.x, lo.x, hi.x), clampf(p.y, lo.y, hi.y))

## 船的一步：b = {"pos": Vector2, "yaw", "spd"}；thr：油門 -1～1；steer：轉彎 -1（左）～1（右）。回傳這一步有沒有擦到岸
func step(b: Dictionary, dt: float, thr: float, steer: float) -> bool:
	var spd := float(b.spd)
	var boost := bool(b.get("boost", false))
	var top := float(b.get("max", MAX_SPEED)) * (1.55 if boost else 1.0)
	var acc := float(b.get("acc", ACCEL)) * (2.0 if boost else 1.0)
	var grip := clampf(absf(spd) / 6.0, 0.25, 1.0)          # 靜止時也能慢慢轉，全速時轉得最靈
	b.yaw = float(b.yaw) - steer * float(b.get("turn", TURN)) * grip * dt * (1.0 if spd >= -0.5 else -1.0)
	var target := top * thr if thr >= 0.0 else BACK_SPEED * -thr
	spd = move_toward(spd, target, (acc if absf(target) > absf(spd) else DRAG) * dt)
	var heading := Vector2(sin(float(b.yaw)), cos(float(b.yaw)))
	var np: Vector2 = (b.pos as Vector2) + heading * spd * dt
	var rp := resolve(np)
	var scraped := rp.distance_to(np) > 0.02
	if scraped:
		spd *= 0.93
	b.pos = rp
	b.spd = spd
	return scraped

# ---------------------------------------------------------------- 自動航行

func _blocked(p: Vector2, margin: float) -> bool:
	for i in isles.size():
		if shore(i, p) < margin:
			return true
	return p.x < lo.x or p.y < lo.y or p.x > hi.x or p.y > hi.y

## a 到 b 的直線上有沒有碰到島（每 2.5 公尺看一次）
func clear(a: Vector2, b: Vector2, margin: float) -> bool:
	var n := maxi(int(a.distance_to(b) / 2.5), 1)
	for k in n + 1:
		if _blocked(a.lerp(b, float(k) / n), margin):
			return false
	return true

## 從 from 到 to 找一條繞過所有島的路：先留足餘裕找，找不到（島和島靠得很近）就一次比一次放寬
func plan(from: Vector2, to: Vector2) -> PackedVector2Array:
	var chain := PackedVector2Array()
	var margin := PLAN_MARGIN
	for m in [PLAN_MARGIN, 1.0, -4.0]:
		margin = m
		chain = _astar(from, to, m)
		if not chain.is_empty():
			break
	var pts: Array[Vector2] = [from]
	for p in chain:
		pts.append(p)
	pts.append(to)
	# 拉直：能直接開過去的就不要繞
	var out := PackedVector2Array([from])
	var i := 0
	while i < pts.size() - 1:
		var j := pts.size() - 1
		while j > i + 1 and not clear(pts[i], pts[j], minf(margin, 2.0)):
			j -= 1
		out.append(pts[j])
		i = j
	return out

## A*（格子 CELL 公尺；出發點和終點附近放寬，才出得了港、靠得了岸）。找不到回傳空的
func _astar(from: Vector2, to: Vector2, margin: float) -> PackedVector2Array:
	var cols := int(ceil((hi.x - lo.x) / CELL))
	var rows := int(ceil((hi.y - lo.y) / CELL))
	var cell_of := func(p: Vector2) -> Vector2i:
		return Vector2i(clampi(int((p.x - lo.x) / CELL), 0, cols - 1), clampi(int((p.y - lo.y) / CELL), 0, rows - 1))
	var center_of := func(c: Vector2i) -> Vector2:
		return lo + Vector2((c.x + 0.5) * CELL, (c.y + 0.5) * CELL)
	var s: Vector2i = cell_of.call(from)
	var g: Vector2i = cell_of.call(to)
	var free := func(c: Vector2i) -> bool:
		var p: Vector2 = center_of.call(c)
		if p.distance_to(from) < 16.0 or p.distance_to(to) < 16.0:
			return not _blocked(p, minf(1.5, margin))
		return not _blocked(p, margin)
	var open: Array = [s]
	var came := {}
	var cost := {s: 0.0}
	var closed := {}
	var found := false
	while not open.is_empty():
		var bi := 0
		var bf := INF
		for i in open.size():
			var c: Vector2i = open[i]
			var f := float(cost[c]) + Vector2(c).distance_to(Vector2(g))
			if f < bf:
				bf = f
				bi = i
		var cur: Vector2i = open[bi]
		open.remove_at(bi)
		if cur == g:
			found = true
			break
		closed[cur] = true
		for dx in [-1, 0, 1]:
			for dz in [-1, 0, 1]:
				if dx == 0 and dz == 0:
					continue
				var nb := Vector2i(cur.x + dx, cur.y + dz)
				if nb.x < 0 or nb.y < 0 or nb.x >= cols or nb.y >= rows or closed.has(nb) or not free.call(nb):
					continue
				var nc := float(cost[cur]) + (1.4142 if dx != 0 and dz != 0 else 1.0)
				if not cost.has(nb) or nc < float(cost[nb]):
					cost[nb] = nc
					came[nb] = cur
					if not open.has(nb):
						open.append(nb)
	var out := PackedVector2Array()
	if not found:
		return out
	var rev: Array[Vector2] = []
	var c2: Vector2i = g
	while c2 != s:
		rev.push_front(center_of.call(c2))
		c2 = came[c2]
	for p in rev:
		out.append(p)
	return out

## 第 e 座島靠岸的停船點：從 from 那一側靠過去，離岸邊再外面一點
func stop_point(i: int, from: Vector2) -> Vector2:
	var s: Dictionary = isles[i]
	var d: Vector2 = from - (s.c as Vector2)
	var a := atan2(d.y, d.x)
	return (s.c as Vector2) + Vector2(cos(a), sin(a)) * (edge(i, a) + 3.0)

## 自動航行這一步的油門和轉彎：b 要有 "path"（PackedVector2Array）和 "idx"。回傳 Vector3(thr, steer, 到了沒（1／0）)
func auto_control(b: Dictionary) -> Vector3:
	var path: PackedVector2Array = b.path
	var pos: Vector2 = b.pos
	var i := int(b.idx)
	while i < path.size() - 1 and pos.distance_to(path[i]) < 7.0:
		i += 1
	b.idx = i
	var last: Vector2 = path[path.size() - 1]
	var left := pos.distance_to(last)
	if left < 3.5:
		return Vector3(0, 0, 1)
	var to: Vector2 = path[i] - pos
	var diff := angle_difference(float(b.yaw), atan2(to.x, to.y))
	var steer := clampf(-diff * 2.2, -1.0, 1.0)
	var thr := 1.0 if absf(diff) < 0.9 else 0.35
	if i == path.size() - 1:
		thr = minf(thr, clampf(left / 20.0, 0.25, 1.0))      # 最後一段慢慢靠過去
	return Vector3(thr, steer, 0)
