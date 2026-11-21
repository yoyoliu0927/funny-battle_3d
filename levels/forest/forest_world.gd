extends "res://scripts/world/arena_world.gd"
## 森林場地的共用外觀：深綠地面、可砍的樹、木屋、小紅帽。
## 每一小關覆寫 _layout_level()（範圍、出生點）和 _dress()（要種什麼）。

var trees: Array = []          # {pos, node, rest, block, radius, alive, fall}
var has_house := false
var house_center := Vector2.ZERO
var house_half_x := 3.0
var house_half_z := 2.55
var door_half := 1.2
var house_clear := 6.5         # 木屋周圍這段不種樹
var escape_point := Vector3(0, 0, 4.4)

func _configure() -> void:
	hill_amount = 0.12
	forest_band = 8.0
	grass_count = 1100
	ground_a = Color(0.34, 0.52, 0.22)
	ground_b = Color(0.26, 0.42, 0.16)
	dirt_color = Color(0.42, 0.30, 0.16)
	tree_green = Color(0.16, 0.30, 0.13)   # 外圈深林；場內可砍的樹另外畫得亮一點
	_layout_level()

## 小關覆寫：遊玩範圍、鏡頭、牆
func _layout_level() -> void:
	pass

## 灰色混凝土牆不畫，木屋自己畫。擋路仍靠 wall_segments。
func _build_fence_visuals() -> void:
	pass

func _build_extra() -> void:
	_dress()

## 小關覆寫：種樹、蓋房子
func _dress() -> void:
	pass

func in_house(x: float, z: float) -> bool:
	if not has_house:
		return false
	var lx := x - house_center.x
	var lz := z - house_center.y
	var room := absf(lx) < house_half_x - 0.15 and absf(lz) < house_half_z - 0.05
	# 門開在 +Z。站在門檻上也算進了屋子，家豪才救得到小紅帽。
	var porch := absf(lx) < door_half + 0.45 and lz > house_half_z - 0.55 and lz < house_half_z + 1.25
	return room or porch

## 繞過木屋的路：直線被牆擋住時，回傳下一個要先走去的點。
## 共用的「繞牆」只看擋住的那一面牆、往近的那一端走，走到屋角會被另一面牆推回去，卡在屋角來回抖。
## 這裡用屋子四個外角＋門口內外兩點做一張小地圖，找最短路（每一格都重算，結果穩定，不會來回跳）。
const ROUTE_PAD := 0.9          # 外角離牆多遠
func route_point(from: Vector3, to: Vector3) -> Vector3:
	if not has_house or _route_clear(Vector2(from.x, from.z), Vector2(to.x, to.z)):
		return to
	var c := house_center
	var ex := house_half_x + ROUTE_PAD
	var ez := house_half_z + ROUTE_PAD
	var nodes: Array = [Vector2(from.x, from.z), Vector2(to.x, to.z),
		c + Vector2(-ex, -ez), c + Vector2(ex, -ez), c + Vector2(ex, ez), c + Vector2(-ex, ez),
		c + Vector2(0, house_half_z + 1.0), c + Vector2(0, house_half_z - 0.9)]
	var n := nodes.size()
	var dist: Array = []
	var prev: Array = []
	var done: Array = []
	for i in n:
		dist.append(INF)
		prev.append(-1)
		done.append(false)
	dist[0] = 0.0
	for _k in n:
		var u := -1
		for i in n:
			if not done[i] and (u < 0 or dist[i] < dist[u]):
				u = i
		if u < 0 or dist[u] == INF:
			break
		done[u] = true
		if u == 1:
			break
		for v in n:
			if done[v] or v == u:
				continue
			var a: Vector2 = nodes[u]
			var b: Vector2 = nodes[v]
			if not _route_clear(a, b):
				continue
			var nd: float = dist[u] + a.distance_to(b)
			if nd < dist[v]:
				dist[v] = nd
				prev[v] = u
	if prev[1] < 0:
		return to                    # 找不到路：照舊直直走
	var step := 1
	while prev[step] != 0:
		step = prev[step]
	var p: Vector2 = nodes[step]
	return Vector3(p.x, to.y, p.y)

## a→b 有沒有穿過木屋的牆（牆兩端多算 0.3，跟共用的繞牆判斷一樣）
func _route_clear(a: Vector2, b: Vector2) -> bool:
	for seg in wall_segments:
		var s0: Vector2 = seg[0]
		var s1: Vector2 = seg[1]
		var d := (s1 - s0).normalized()
		if Geometry2D.segment_intersects_segment(a, b, s0 - d * 0.3, s1 + d * 0.3) != null:
			return false
	return true

## 狼外婆不准走出木屋
func clamp_house(p: Vector3) -> Vector3:
	var x := clampf(p.x, house_center.x - house_half_x + 0.55, house_center.x + house_half_x - 0.55)
	var z := clampf(p.z, house_center.y - house_half_z + 0.55, house_center.y + house_half_z - 0.5)
	return Vector3(x, p.y, z)

func house_walls() -> Array:
	var c := house_center
	var x0 := c.x - house_half_x
	var x1 := c.x + house_half_x
	var z0 := c.y - house_half_z
	var z1 := c.y + house_half_z
	var g := door_half
	# 門開在 +Z（朝家豪來的方向）
	return [
		[Vector2(x0, z0), Vector2(x0, z1)],
		[Vector2(x1, z0), Vector2(x1, z1)],
		[Vector2(x0, z0), Vector2(x1, z0)],
		[Vector2(x0, z1), Vector2(c.x - g, z1)],
		[Vector2(c.x + g, z1), Vector2(x1, z1)],
	]

func add_tree(x: float, z: float, spacing: float, avoid: Array, corridor: Dictionary) -> bool:
	if _tree_blocked(x, z, spacing, avoid, corridor):
		return false
	var y := height_at(x, z)
	var n := Node3D.new()
	n.name = "Tree%d" % trees.size()
	n.position = Vector3(x, y, z)
	add_child(n)
	var trunk := _toon(Color(0.40, 0.26, 0.14))
	var h := 2.3 + 0.7 * absf(sin(x * 1.7 + z * 0.8))
	_box(n, Vector3(0.28, h, 0.28), Vector3(0, h * 0.5, 0), trunk)
	var crown := Node3D.new()
	crown.name = "Crown"
	n.add_child(crown)
	var green := Color(0.30, 0.55, 0.22).lightened(0.08 * absf(sin(z * 2.1)))
	var leaf := _toon(green)
	_box(crown, Vector3(1.7, 1.15, 1.7), Vector3(0, h + 0.35, 0), leaf)
	_box(crown, Vector3(1.15, 0.85, 1.15), Vector3(0, h + 1.05, 0), _toon(green.lightened(0.12)))
	var spot := [Vector2(x, z), 0.42]
	obstacles.append(spot)
	trees.append({
		"pos": Vector3(x, y, z), "node": n, "rest": n.position, "block": spot,
		"radius": 0.42, "alive": true, "fall": 0.0,
	})
	return true

func scatter_trees(count: int, spacing: float, avoid: Array, corridor: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed + 90
	var guard := 0
	while trees.size() < count and guard < 5000:
		guard += 1
		var x := rng.randf_range(play_min.x + 1.4, play_max.x - 1.4)
		var z := rng.randf_range(play_min.y + 1.4, play_max.y - 1.4)
		add_tree(x, z, spacing, avoid, corridor)
	if trees.size() < count:
		guard = 0
		while trees.size() < count and guard < 4000:
			guard += 1
			var x := rng.randf_range(play_min.x + 1.4, play_max.x - 1.4)
			var z := rng.randf_range(play_min.y + 1.4, play_max.y - 1.4)
			add_tree(x, z, spacing * 0.82, avoid, corridor)

## 繞著木屋種一圈，南邊留給回家豪的路
func ring_trees(radius: float, n: int, spacing: float, avoid: Array, corridor: Dictionary) -> void:
	for i in n:
		var a := TAU * float(i) / float(n)
		if absf(wrapf(a, -PI, PI)) < 0.62:
			continue
		add_tree(house_center.x + sin(a) * radius, house_center.y + cos(a) * radius * 0.92, spacing, avoid, corridor)

func build_house() -> void:
	has_house = true
	var y0 := height_at(house_center.x, house_center.y)
	var house := Node3D.new()
	house.name = "House"
	house.position = Vector3(house_center.x, y0, house_center.y)
	add_child(house)
	var wood := _toon(Color(0.62, 0.42, 0.22))
	var dark := _toon(Color(0.40, 0.26, 0.13))
	var roof_c := _toon(Color(0.55, 0.18, 0.14))
	var hx := house_half_x
	var hz := house_half_z
	# 西、東、北三面牆
	_box(house, Vector3(0.18, 2.25, hz * 2.0), Vector3(-hx, 1.12, 0), wood)
	_box(house, Vector3(0.18, 2.25, hz * 2.0), Vector3(hx, 1.12, 0), wood)
	_box(house, Vector3(hx * 2.0, 2.25, 0.18), Vector3(0, 1.12, -hz), wood)
	# 南牆開門
	var side_len := hx - door_half
	var side_cx := (hx + door_half) * 0.5
	_box(house, Vector3(side_len, 2.25, 0.18), Vector3(-side_cx, 1.12, hz), wood)
	_box(house, Vector3(side_len, 2.25, 0.18), Vector3(side_cx, 1.12, hz), wood)
	_box(house, Vector3(door_half * 2.0, 0.22, 0.2), Vector3(0, 2.15, hz), dark)   # 門楣
	_box(house, Vector3(0.16, 2.05, 0.16), Vector3(-door_half, 1.02, hz), dark)
	_box(house, Vector3(0.16, 2.05, 0.16), Vector3(door_half, 1.02, hz), dark)
	# 屋頂
	_box(house, Vector3(hx * 2.0 + 0.8, 0.16, hz + 0.5), Vector3(0, 2.45, -hz * 0.42), roof_c, Vector3(0.5, 0, 0))
	_box(house, Vector3(hx * 2.0 + 0.8, 0.16, hz + 0.5), Vector3(0, 2.45, hz * 0.42), roof_c, Vector3(-0.5, 0, 0))
	_box(house, Vector3(0.4, 0.7, 0.4), Vector3(-hx + 0.7, 2.7, -hz + 0.6), dark)   # 煙囪
	# 裡面：床、桌子。高度用木屋本地座標
	var cloth := _toon(Color(0.75, 0.22, 0.28))
	_box(house, Vector3(1.3, 0.28, 0.7), Vector3(-1.5, 0.2, -1.15), dark)
	_box(house, Vector3(1.35, 0.12, 0.75), Vector3(-1.5, 0.38, -1.15), cloth)
	_box(house, Vector3(0.7, 0.42, 0.5), Vector3(1.35, 0.28, -0.15), wood)
	# 窗（暗色，牆還是過不去）
	var glass := _toon(Color(0.55, 0.72, 0.78))
	_box(house, Vector3(0.08, 0.55, 0.7), Vector3(-hx - 0.02, 1.35, 0.2), glass)
	_box(house, Vector3(0.08, 0.55, 0.7), Vector3(hx + 0.02, 1.35, -0.3), glass)

func build_hood(pos: Vector3) -> void:
	var y := height_at(pos.x, pos.z)
	var n := Node3D.new()
	n.name = "RedHood"
	n.position = Vector3(pos.x, y, pos.z)
	n.rotation.y = PI   # 面向木屋裡面的狼外婆（-Z）
	add_child(n)
	var skin := _toon(Color(0.96, 0.78, 0.66))
	var red := _toon(Color(0.84, 0.10, 0.13))
	var dress := _toon(Color(0.45, 0.16, 0.22))
	_box(n, Vector3(0.32, 0.62, 0.24), Vector3(0, 0.55, 0), dress)
	_box(n, Vector3(0.38, 0.75, 0.30), Vector3(0, 0.62, -0.04), red)   # 紅斗篷
	_box(n, Vector3(0.24, 0.24, 0.24), Vector3(0, 1.08, 0), skin)
	_box(n, Vector3(0.42, 0.16, 0.42), Vector3(0, 1.24, 0), red)       # 帽緣
	_box(n, Vector3(0.2, 0.12, 0.2), Vector3(0.26, 0.42, 0.16), _toon(Color(0.58, 0.38, 0.16)))  # 篮子

func dirt_path(a: Vector2, b: Vector2) -> void:
	var mat := _toon(Color(0.46, 0.34, 0.18))
	var length := a.distance_to(b)
	var n := maxi(int(length / 1.3), 1)
	var yaw := atan2(b.x - a.x, b.y - a.y)
	for i in n:
		var p := a.lerp(b, (float(i) + 0.5) / float(n))
		var y := height_at(p.x, p.y)
		_box(self, Vector3(1.7, 0.03, length / float(n) + 0.08), Vector3(p.x, y + 0.015, p.y), mat, Vector3(0, yaw, 0))

func _tree_blocked(x: float, z: float, spacing: float, avoid: Array, corridor: Dictionary) -> bool:
	if x < play_min.x + 1.0 or x > play_max.x - 1.0 or z < play_min.y + 1.0 or z > play_max.y - 1.0:
		return true
	if has_house and Vector2(x, z).distance_to(house_center) < house_clear:
		return true
	if not corridor.is_empty() and _seg_dist(Vector2(x, z), corridor.a, corridor.b) < float(corridor.half):
		return true
	for item in avoid:
		var p: Vector3 = item.p
		if Vector2(x, z).distance_to(Vector2(p.x, p.z)) < float(item.r):
			return true
	for t in trees:
		var tp: Vector3 = t.pos
		if Vector2(x, z).distance_to(Vector2(tp.x, tp.z)) < spacing:
			return true
	return false

## 樹腳的灌木，不擋路、也不能砍，只是讓林子看起來滿
func undergrowth(n: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed + 44
	var leaf := _toon(Color(0.20, 0.40, 0.16))
	var moss := _toon(Color(0.34, 0.48, 0.18))
	var placed := 0
	var guard := 0
	while placed < n and guard < 2500:
		guard += 1
		var x := rng.randf_range(play_min.x + 0.8, play_max.x - 0.8)
		var z := rng.randf_range(play_min.y + 0.8, play_max.y - 0.8)
		if has_house and Vector2(x, z).distance_to(house_center) < house_clear - 0.8:
			continue
		if _near_tree(x, z, 1.15):
			continue
		var y := height_at(x, z)
		var s := rng.randf_range(0.28, 0.62)
		var mat := leaf if placed % 3 else moss
		_box(self, Vector3(s, s * 0.55, s), Vector3(x, y + s * 0.22, z), mat)
		placed += 1

func mushrooms(n: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed + 71
	var cap := _toon(Color(0.72, 0.18, 0.16))
	var stem := _toon(Color(0.9, 0.86, 0.78))
	var placed := 0
	var guard := 0
	while placed < n and guard < 1500:
		guard += 1
		var x := rng.randf_range(play_min.x + 1.0, play_max.x - 1.0)
		var z := rng.randf_range(play_min.y + 1.0, play_max.y - 1.0)
		if has_house and Vector2(x, z).distance_to(house_center) < 4.2:
			continue
		if _near_tree(x, z, 0.7):
			continue
		var y := height_at(x, z)
		_box(self, Vector3(0.08, 0.16, 0.08), Vector3(x, y + 0.08, z), stem)
		_box(self, Vector3(0.22, 0.08, 0.22), Vector3(x, y + 0.18, z), cap)
		placed += 1

func _near_tree(x: float, z: float, r: float) -> bool:
	for t in trees:
		var p: Vector3 = t.pos
		if Vector2(x, z).distance_to(Vector2(p.x, p.z)) < r:
			return true
	return false

func _seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var len2 := ab.length_squared()
	if len2 < 0.001:
		return p.distance_to(a)
	var t := clampf((p - a).dot(ab) / len2, 0.0, 1.0)
	return p.distance_to(a + ab * t)
