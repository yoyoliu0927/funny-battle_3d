extends RefCounted
## 選關地圖上的「要塞島」（chapter.gd 的 MAP_SCRIPT；由 scripts/level_select.gd 呼叫，不是關卡腳本）。
## 一座砂岩峭壁的草地島，中間一道城牆把島切成兩半：路從西邊的灘頭穿過城門進到要塞裡。
## 三個小關是島上的三個地點，模型都是關卡裡用的那幾套（Kenney 城堡、海盜、塔防）：
##   1 學大砲：城牆外的砲兵陣地（大砲、砲彈、瞭望台）　2 三座炮塔：城牆裡三座高低不同的圓炮塔
##   3 指揮官的院子：小山丘上的主堡（高塔、旗子、城牆）
## 天色是傍晚的暖色，越往裡面走越接近日落。
## 島的網格借用冰雪島的 art/isle_builder.gd（只是算形狀的工具，跟冰雪無關）。

const Isle := preload("res://levels/ice/art/isle_builder.gd")
const C := "res://levels/fort/assets/castle/"
const P := "res://levels/fort/assets/pirate/"
const T := "res://levels/fort/assets/tdkit/"
const TEX := "res://assets/textures/"
const KIT := 2.0                # 城堡零件放大幾倍（原本一格 1 公尺）
const HILL_R := 6.5             # 主堡那座小山丘的半徑
const HILL_H := 1.5

var _top_y := 1.5
var _ctx := {}
var _o := {}
var _hill := Vector2(INF, INF)
var _wall_x := INF              # 城牆在哪個 x（南北走向）
var _rng := RandomNumberGenerator.new()

# ================================================================== 給 level_select.gd 呼叫的函式

## 走到第 k 小關時的天色：午後 → 金色傍晚 → 日落
func mood(k: int) -> Dictionary:
	match k:
		0:
			return {
				"sun": Color(1.0, 0.90, 0.68), "energy": 1.8, "rot": Vector3(-0.70, 0.9, 0),
				"amb": Color(0.76, 0.78, 0.82), "amb_e": 0.9, "fog": Color(0.90, 0.88, 0.76),
				"sky.top_color": Color(0.36, 0.64, 0.86), "sky.horizon_color": Color(0.94, 0.90, 0.74),
				"sky.cloud_color": Color(1.0, 0.97, 0.90), "sky.cloud_shade": Color(0.86, 0.80, 0.72),
				"sea.deep": Color(0.08, 0.40, 0.58), "sea.near_c": Color(0.22, 0.60, 0.68), "sea.stroke_c": Color(0.84, 0.94, 0.90),
				"sea.foam_c": Color(1, 1, 0.96), "sea.horizon_c": Color(0.90, 0.88, 0.76),
			}
		1:
			return {
				"sun": Color(1.0, 0.80, 0.52), "energy": 1.75, "rot": Vector3(-0.48, 0.95, 0),
				"amb": Color(0.78, 0.72, 0.74), "amb_e": 0.9, "fog": Color(0.94, 0.84, 0.66),
				"sky.top_color": Color(0.38, 0.56, 0.80), "sky.horizon_color": Color(0.99, 0.84, 0.58),
				"sky.cloud_color": Color(1.0, 0.92, 0.76), "sky.cloud_shade": Color(0.86, 0.66, 0.56),
				"sea.deep": Color(0.08, 0.34, 0.52), "sea.near_c": Color(0.26, 0.54, 0.62), "sea.stroke_c": Color(0.98, 0.90, 0.72),
				"sea.foam_c": Color(1, 0.98, 0.90), "sea.horizon_c": Color(0.96, 0.82, 0.60),
			}
		_:
			return {
				"sun": Color(1.0, 0.62, 0.36), "energy": 1.6, "rot": Vector3(-0.30, 1.05, 0),
				"amb": Color(0.74, 0.60, 0.66), "amb_e": 0.9, "fog": Color(0.96, 0.70, 0.52),
				"sky.top_color": Color(0.34, 0.40, 0.70), "sky.horizon_color": Color(1.0, 0.66, 0.40),
				"sky.cloud_color": Color(1.0, 0.80, 0.62), "sky.cloud_shade": Color(0.74, 0.46, 0.50),
				"sea.deep": Color(0.10, 0.24, 0.46), "sea.near_c": Color(0.36, 0.42, 0.56), "sea.stroke_c": Color(1.0, 0.80, 0.60),
				"sea.foam_c": Color(1, 0.94, 0.86), "sea.horizon_c": Color(0.98, 0.66, 0.46),
			}

## 島面高度：緩緩起伏，主堡（最後一小關）底下是一座小山丘
func ground_y(x: float, z: float) -> float:
	var y := _top_y + 0.10 * sin(x * 0.45 + 2.0) * cos(z * 0.55)
	if _hill.x != INF:
		y += HILL_H * smoothstep(HILL_R, HILL_R * 0.45, Vector2(x, z).distance_to(_hill))
	return y

## 蓋整座島（世界座標；y = 0 是海面）
func build_island(root: Node3D, ctx: Dictionary) -> void:
	_ctx = ctx
	_top_y = float(ctx.get("top_y", 1.5))
	_rng.seed = 1815
	var c: Vector2 = ctx.center
	var pads: Array = ctx.pads
	var spots: Array = ctx.spots
	var last: Vector3 = spots[spots.size() - 1]
	if spots.size() >= 2:
		_hill = Vector2(last.x + 0.4, last.z - 0.8)
	_o = {"c": c, "rx": float(ctx.rx), "rz": float(ctx.rz), "seed": 8.4, "pow": 3.2, "wob": 1.2, "depth": _top_y + 1.4, "slope": 0.10, "lobe": 3.0,
		"coves": [[0.9, 2.0, 0.16], [3.5, 2.4, 0.20], [5.3, 1.8, 0.14]]}
	var top := MeshInstance3D.new()
	top.name = "Top"
	top.mesh = Isle.build_top(_o, ground_y, 128, 12, 0.35)
	top.material_override = _tex_mat("grass_ground_diff_1k.jpg", Color(0.78, 1.30, 0.52), 0.2)
	root.add_child(top)
	var cliff := MeshInstance3D.new()
	cliff.name = "Cliff"
	cliff.mesh = Isle.build_cliff(_o, func(a: float) -> float:
		var p := Isle.rim_point(_o, a)
		return ground_y(p.x, p.y), 128, 6)
	var cm := _tex_mat("lichen_rock_diff_1k.jpg", Color(1.25, 0.98, 0.74), 0.16)
	cm.vertex_color_use_as_albedo = true        # isle_builder 給每一層岩層不同的明暗
	cliff.material_override = cm
	root.add_child(cliff)
	if pads.size() >= 2:
		_build_curtain_wall(root, pads)
	# 城牆外（西邊）：攻城器械對著要塞；到處是樹和石頭
	var p0: Vector3 = pads[0]
	_piece(root, C + "siege-trebuchet.glb", _on(p0.x - 5.2, p0.z + 3.6), 0.3, KIT)
	_piece(root, C + "siege-catapult.glb", _on(p0.x - 6.6, p0.z - 3.4), -0.2, KIT)
	var placed := 0
	for i in 500:
		if placed >= 26:
			break
		var a := _rng.randf() * TAU
		var d := Isle.radius(_o, a) * sqrt(_rng.randf()) - 1.5
		var x := c.x + cos(a) * d
		var z := c.y + sin(a) * d
		if d < 0.0 or not _free(x, z):
			continue
		var g := _on(x, z)
		match placed % 6:
			4: _piece(root, C + "rocks-large.glb", g, _rng.randf() * TAU, _rng.randf_range(1.2, 1.8))
			5: _piece(root, C + "rocks-small.glb", g, _rng.randf() * TAU, _rng.randf_range(1.0, 1.6))
			_: _piece(root, C + ("tree-large.glb" if placed % 2 == 0 else "tree-small.glb"), g, _rng.randf() * TAU, _rng.randf_range(1.5, 2.1))
		placed += 1
	# 海上的礁石
	for i in 6:
		var a := (i + _rng.randf_range(-0.3, 0.3)) * TAU / 6.0
		var d := Isle.cliff_radius(_o, a, _top_y) + _rng.randf_range(2.5, 6.0)
		_piece(root, C + "rocks-large.glb", Vector3(c.x + cos(a) * d, -0.25, c.y + sin(a) * d), _rng.randf() * TAU, _rng.randf_range(1.8, 3.0))

## 蓋第 k 小關的地標（root 在那個地點的島面上，+z 是鏡頭和站點那一邊）
func build_spot(k: int, root: Node3D, _c: Dictionary) -> void:
	match k:
		0: _training_yard(root)   # 教學：從背後偷襲
		1: _battery(root)
		2: _three_towers(root)
		4: _windy(root)          # 風口
		_: _keep(root)

# ================================================================== 三個地點

## 4 風口：一排被風吹得歪向同一邊的旗子和木桶
func _windy(root: Node3D) -> void:
	for k in 3:
		_piece(root, C + "flag-banner-short.glb", Vector3(-1.4 + k * 1.4, 0, -0.4 + k * 0.2), PI * 0.5, KIT * 0.7)
	_piece(root, P + "barrel.glb", Vector3(-1.0, 0, 1.0), 0.0, KIT * 0.6)
	_piece(root, P + "barrel.glb", Vector3(1.2, 0, 0.9), 0.0, KIT * 0.6)

## 0 教學：練習場——幾個木箱、木桶圍出一小塊空地，插一支旗子
func _training_yard(root: Node3D) -> void:
	for it in [[P + "crate.glb", Vector3(-1.2, 0, 0.6), 0.3], [P + "crate.glb", Vector3(-0.6, 0, -0.9), -0.4],
			[P + "barrel.glb", Vector3(1.1, 0, -0.5), 0.0], [P + "barrel.glb", Vector3(0.9, 0, 0.9), 0.0]]:
		_piece(root, it[0], it[1], it[2], KIT * 0.6)
	_piece(root, C + "flag-banner-short.glb", Vector3(0, 0, 0), 0.0, KIT * 0.8)

## 1 學大砲：木頭平台上的一門大砲、砲彈、木桶、瞭望台
func _battery(root: Node3D) -> void:
	_piece(root, P + "platform.glb", Vector3(-0.6, 0, -0.6), 0.0, 1.5)
	_piece(root, P + "cannon.glb", Vector3(-0.6, 0.32, -0.6), PI * 0.5, 1.5)      # 砲口朝東：對著城牆裡面
	for q in [Vector3(-2.3, 0.3, 0.9), Vector3(-1.8, 0.3, 1.2), Vector3(-2.0, 0.72, 1.05)]:
		_piece(root, P + "cannon-ball.glb", q, q.x, 0.8)
	_piece(root, P + "barrel.glb", Vector3(1.9, 0, 0.9), 0.4, 0.7)
	_piece(root, P + "barrel.glb", Vector3(2.7, 0, 0.3), 1.3, 0.7)
	_piece(root, P + "crate.glb", Vector3(2.2, 0, -0.5), 0.2, 0.8)
	_piece(root, P + "tower-watch.glb", Vector3(2.6, 0, -2.8), 0.3, 1.25)
	_piece(root, P + "flag-high-pennant.glb", Vector3(-3.0, 0, -2.2), 0.6, 1.1)
	root.set_meta("bubble_y", 5.4)

## 2 三座炮塔：高低不同的三座圓塔，塔頂各一門砲
func _three_towers(root: Node3D) -> void:
	for t in [[Vector3(0.0, 0, -1.8), 3, 0.0], [Vector3(-2.7, 0, -0.2), 2, 0.5], [Vector3(2.7, 0, -0.4), 1, -0.5]]:
		var parts: Array = [T + "tower-round-base.glb", T + "tower-round-bottom-a.glb"]
		for i in int(t[1]):
			parts.append(T + "tower-round-middle-a.glb")
		parts.append(T + "tower-round-top-a.glb")
		parts.append(T + "weapon-cannon.glb")
		_stack(root, t[0], float(t[2]), 2.3, parts)
	_piece(root, P + "chest.glb", Vector3(0.9, 0, 1.4), 0.5, 0.6)
	_piece(root, C + "flag.glb", Vector3(-1.3, 0, 1.3), 0.4, 2.4)
	root.set_meta("bubble_y", 7.4)

## 3 指揮官的院子：山丘上的主堡——中間一座高塔，兩邊城牆接兩座角塔，塔頂插旗
func _keep(root: Node3D) -> void:
	var z := -1.6
	var top := _stack(root, Vector3(0, 0, z), 0.0, KIT, [C + "tower-square-base.glb", C + "tower-square-mid-windows.glb", C + "tower-square-mid.glb", C + "tower-square-top-roof-high.glb"])
	_piece(root, C + "flag.glb", Vector3(0, top, z), 0.3, KIT)
	for s in [-1.0, 1.0]:
		var sx: float = s
		_piece(root, C + "wall.glb", Vector3(sx * KIT, 0, z), 0.0, KIT)
		var t2 := _stack(root, Vector3(sx * KIT * 2.0, 0, z), 0.0, KIT, [C + "tower-square-base.glb", C + "tower-square-mid.glb", C + "tower-square-top.glb"])
		_piece(root, C + "flag-pennant.glb", Vector3(sx * KIT * 2.0, t2, z), sx, KIT)
	_piece(root, C + "stairs-stone.glb", Vector3(0, 0, z + KIT * 0.75), PI * 0.5, KIT)
	_piece(root, C + "flag-banner-long.glb", Vector3(-KIT, 0, z + KIT * 0.55), PI * 0.5, KIT * 0.9)
	_piece(root, C + "flag-banner-long.glb", Vector3(KIT, 0, z + KIT * 0.55), PI * 0.5, KIT * 0.9)
	_piece(root, C + "siege-ballista.glb", Vector3(3.0, 0, 1.6), -2.2, 1.4)
	root.set_meta("bubble_y", 9.2)

# ================================================================== 城牆

## 一道南北走向的城牆把島切成兩半，路穿過去的地方是城門（兩座門塔＋旗子）
func _build_curtain_wall(root: Node3D, pads: Array) -> void:
	var p0: Vector3 = pads[0]
	var p1: Vector3 = pads[1]
	var p2: Vector3 = pads[mini(2, pads.size() - 1)]
	var gate: Vector3 = p0.cubic_interpolate(p1, p0, p2, 0.5)     # 路的中點（跟 level_select.gd 鋪路用同一條曲線）
	_wall_x = gate.x
	var c: Vector2 = _o.c
	var step := KIT
	for d in [-1.0, 1.0]:
		var dir: float = d
		# 門塔
		var tz: float = gate.z + dir * (1.3 + step * 0.5)
		var th := _stack(root, _on(_wall_x, tz), 0.0, KIT, [C + "tower-square-base.glb", C + "tower-square-mid.glb", C + "tower-square-top.glb"])
		_piece(root, C + "flag-pennant.glb", _on(_wall_x, tz) + Vector3(0, th, 0), dir * 0.6, KIT)
		# 城牆一格一格排到岸邊
		var z: float = tz + dir * step
		while Isle.inside(_o, _wall_x, z, 1.4) and absf(z - c.y) < float(_o.rz) + 2.0:
			_piece(root, C + "wall.glb", _on(_wall_x, z), PI * 0.5, KIT)
			z += dir * step
	# 兩座門塔朝外（西邊、灘頭那一面）各掛一面長旗
	for d in [-1.0, 1.0]:
		var bz: float = gate.z + d * (1.3 + step * 0.5)
		_piece(root, C + "flag-banner-long.glb", _on(_wall_x - KIT * 0.53, bz) + Vector3(0, 0.5, 0), 0.0, KIT * 0.8)

# ================================================================== 小工具

## (x, z) 那一點的島面
func _on(x: float, z: float) -> Vector3:
	return Vector3(x, ground_y(x, z), z)

## 這個位置能不能放裝飾（離路、站點、地標、城牆夠遠）
func _free(x: float, z: float) -> bool:
	var p := Vector2(x, z)
	var pads: Array = _ctx.pads
	for k in pads.size():
		var a := Vector2(pads[k].x, pads[k].z)
		if p.distance_to(a) < 3.2:
			return false
		if absf(x - a.x) < 4.6 and z > a.y:      # 站點正前方（鏡頭那一邊）留空：樹才不會擋住家豪和旗子
			return false
		if k + 1 < pads.size():
			var b := Vector2(pads[k + 1].x, pads[k + 1].z)
			if Geometry2D.get_closest_point_to_segment(p, a, b).distance_to(p) < 2.6:
				return false
		var sp: Vector3 = _ctx.spots[k]
		if p.distance_to(Vector2(sp.x, sp.z)) < 5.4:
			return false
	if p.distance_to(_hill) < HILL_R * 0.8:
		return false
	if absf(x - _wall_x) < 2.2:
		return false
	var p0: Vector3 = pads[0]
	if x < p0.x - 3.0 and absf(z - p0.z) < 6.0:       # 攻城器械那一塊
		return false
	return true

func _tex_mat(tex: String, tint: Color, scale: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(TEX + tex)
	m.albedo_color = tint
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE * scale
	m.roughness = 1.0
	return m

## 放一個零件（scale 是倍率；零件的原點在底部中央）
func _piece(parent: Node3D, path: String, pos: Vector3, yaw := 0.0, scale := 1.0) -> Node3D:
	if not ResourceLoader.exists(path):
		push_warning("要塞島地圖：找不到模型 " + path)
		return null
	var ps := load(path) as PackedScene
	if ps == null:
		return null
	var n := ps.instantiate() as Node3D
	n.position = pos
	n.rotation.y = yaw
	n.scale = Vector3.ONE * scale
	parent.add_child(n)
	var ap := n.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap:
		ap.stop()
	return n

## 把幾個零件由下往上疊起來（每個零件多高是量模型的），回傳疊完之後頂端的高度
func _stack(parent: Node3D, pos: Vector3, yaw: float, scale: float, parts: Array) -> float:
	var y := pos.y
	for path in parts:
		var n := _piece(parent, String(path), Vector3(pos.x, y, pos.z), yaw, scale)
		if n:
			y += _height(n) * scale
	return y

## 模型原本多高（還沒放大之前）
func _height(n: Node3D) -> float:
	var saved := n.transform
	n.transform = Transform3D.IDENTITY
	var bb := _bounds(n, Transform3D.IDENTITY)
	n.transform = saved
	return bb.position.y + bb.size.y

func _bounds(node: Node, xf: Transform3D) -> AABB:
	var out := AABB()
	var have := false
	if node is Node3D:
		xf = xf * (node as Node3D).transform
	if node is MeshInstance3D and (node as MeshInstance3D).mesh:
		out = xf * (node as MeshInstance3D).mesh.get_aabb()
		have = true
	for ch in node.get_children():
		var b := _bounds(ch, xf)
		if b.size != Vector3.ZERO:
			out = out.merge(b) if have else b
			have = true
	return out
