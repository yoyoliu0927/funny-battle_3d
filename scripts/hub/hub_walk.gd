extends RefCounted
## 主島自由走（實驗）：家豪在整座農莊上用 WASD／方向鍵隨便跑，走近站點才冒泡泡。
##
## 這個檔案只管「位置」：
##   - 障礙是一堆圓（樹、穀倉、風車、攤棚、雞圈柵欄、破關長出來的小地標），池塘是一個橢圓，岸邊用島的輪廓擋住。
##   - 擋到就沿著邊滑過去，不會卡住。
##   - 站點用「吸附」：離最近的站點夠近就算到了（泡泡、Enter 都看這個），level_select.gd 的 stage_sel 永遠是最近的站點。
## 其他島還是沿路一格一格走，完全不受影響（level_select.gd 用 _free_hub() 決定這座島要不要用自由走）。
## 命令列加 -- --no-freewalk 可以關掉，回到原本沿路走的主島。

const HubGrowth := preload("res://scripts/hub/hub_growth.gd")

const RADIUS := 0.7          # 家豪的身體半徑（公尺）
const SPEED := 15.0          # 跑多快（公尺／秒）
const EDGE := 2.6            # 離岸邊留多遠（南岸的矮柵欄在岸邊內 1.5 公尺）
const NEAR := 3.6            # 離站點多近算「到了」
const FAR := 4.6             # 到了之後要離開多遠才算走開（避免在邊界上泡泡一直閃）
const OUTLINE_S := 1.9       # 主島輪廓的形狀參數（跟 _build_farm 的 s 一樣）
const GROW_R := 1.7          # 破關長出來的小地標擋多大一圈

var map                      # 選關畫面（level_select.gd）
var pos := Vector3.ZERO      # 家豪現在的位置（世界座標；y = 站點上家豪腳下的高度）
var circles: Array = []      # 障礙：Vector3(x, z, 半徑)（世界座標）
var _occ: Array = []         # 會擋住鏡頭的東西 {pos: Vector2, vis: 範圍, fade: 現在多透明, meshes: [MeshInstance3D]}

## 蓋完島之後呼叫一次：把 level_select.gd 登記的障礙換成世界座標
func build() -> void:
	circles.clear()
	_occ.clear()
	for b in map._hub_blocks:
		var h: Node3D = b[0]
		if not is_instance_valid(h) or not h.is_inside_tree():
			continue
		var p: Vector3 = h.global_position + (b[2] as Vector3)
		circles.append(Vector3(p.x, p.z, float(b[1]) * h.global_transform.basis.get_scale().x))
		if float(b[3]) > 0.0:
			var ms: Array = []
			for m in h.find_children("*", "MeshInstance3D", true, false):
				ms.append(m)
			_occ.append({"pos": Vector2(p.x, p.z), "vis": float(b[3]), "fade": 0.0, "meshes": ms})

## 站點 k 的位置（家豪站在上面的高度）
func station(k: int) -> Vector3:
	return (map.worlds[0].pads[k] as Vector3) + Vector3(0, 0.3, 0)

## 最近的站點：{"k": 第幾個, "d": 水平距離}
func nearest(p: Vector3) -> Dictionary:
	var best := 0
	var best_d := INF
	for k in int(map.worlds[0].n):
		var s: Vector3 = map.worlds[0].pads[k]
		var d := Vector2(p.x - s.x, p.z - s.z).length()
		if d < best_d:
			best_d = d
			best = k
	return {"k": best, "d": best_d}

## 把一個點推到不在任何障礙裡面、也不出島、不進池塘（碰到就沿著邊滑）
func resolve(p: Vector3) -> Vector3:
	var w: Dictionary = map.worlds[0]
	var ctr: Vector3 = w.center
	var off: Vector3 = w.origin
	var fish = map._fishing
	for _i in 6:
		# 岸邊
		var d := Vector2(p.x - ctr.x, p.z - ctr.z)
		var lim: float = map._outline(float(w.rx), float(w.rz), atan2(d.y, d.x), OUTLINE_S) - EDGE
		if d.length() > lim:
			d = d.normalized() * lim
			p.x = ctr.x + d.x
			p.z = ctr.z + d.y
		# 池塘：橢圓
		if fish != null and fish.pond_node != null:
			var pc: Vector3 = fish.pond_center()
			var ax: float = fish.pond_rx * 0.95 + 0.3
			var az: float = fish.pond_rz * 0.95 + 0.3
			var qx := p.x - pc.x
			var qz := p.z - pc.z
			var v := (qx / ax) * (qx / ax) + (qz / az) * (qz / az)
			if v < 1.0:
				if v < 0.0001:
					qz = 1.0
					v = (qz / az) * (qz / az)
				var k := 1.0 / sqrt(v)
				p.x = pc.x + qx * k
				p.z = pc.z + qz * k
		# 最後才推開建築和樹：就算貼著岸邊，也不會穿進建築裡
		for c in circles:
			p = _push(p, Vector2(c.x, c.y), float(c.z))
		for gid in HubGrowth.ids():
			if map._growth.has_grown(String(gid)):
				var gs := HubGrowth.slot(String(gid))
				p = _push(p, Vector2(gs.x + off.x, gs.y + off.z), GROW_R)
	return p

func _push(p: Vector3, c: Vector2, r: float) -> Vector3:
	var d := Vector2(p.x - c.x, p.z - c.y)
	var m := RADIUS + r
	var l2 := d.length_squared()
	if l2 >= m * m:
		return p
	var n := Vector2(0, 1)
	if l2 > 0.000001:
		n = d / sqrt(l2)
	p.x = c.x + n.x * m
	p.z = c.y + n.y * m
	return p

## 朝 dir（世界座標的水平方向，長度 ≤ 1）走 dt 秒，回傳實際走了多遠
func step(dt: float, dir: Vector2) -> float:
	var before := pos
	var np := Vector3(pos.x + dir.x * SPEED * dt, pos.y, pos.z + dir.y * SPEED * dt)
	pos = resolve(np)
	return Vector2(pos.x - before.x, pos.z - before.z).length()

## 家豪被樹或建築擋在鏡頭後面的時候，把擋住的東西變半透明（看得到家豪）；離開了再慢慢變回來
func update_occlusion(dt: float, cam: Vector3, hero: Vector3, active: bool) -> void:
	var a := Vector2(cam.x, cam.z)
	var b := Vector2(hero.x, hero.z)
	var ab := b - a
	var l2 := ab.length_squared()
	for o in _occ:
		var target := 0.0
		if active and l2 > 1.0:
			var pos: Vector2 = o.pos
			var t := clampf((pos - a).dot(ab) / l2, 0.0, 1.0)
			if t < 0.97 and (a + ab * t).distance_to(pos) < float(o.vis):
				target = 0.8
		var f := float(o.fade)
		if absf(f - target) > 0.001:
			f = move_toward(f, target, dt * 4.0)
			o.fade = f
			for m in o.meshes:
				if is_instance_valid(m):
					(m as GeometryInstance3D).transparency = f
