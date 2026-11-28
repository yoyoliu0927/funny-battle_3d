extends "res://levels/ice/story/story_kit.gd"
## 人類要塞的開場動畫（第 4 天）。分鏡在 levels/ice/docs/大關開場與結尾動畫.md 第 7 節。
## 每次在選關地圖按要塞第 1 關（stage_0「偷襲！」）都先播（見 story_registry.gd），播完進第 1 關；那一關自己的三張開場卡照播。
## 場地借要塞第 0 關（拿掉戰局、玩家和介面）。要塞的關卡沒有海，這裡在島外面鋪一片海、南岸鋪一條沙灘給小船靠岸。
##
## 五拍：靠岸（城門「人類要塞」、牆外砲口朝裡的大砲）→ 號碼（卡車載著蓋「貨」字章的木箱進出城門）
##       → 對話（神明看向大砲，家豪把帽子拉低）→ 尋雞啟事（整面城牆貼滿懸賞單）→ 標題卡

const STAGE := "res://levels/fort/stage_0/stage.tscn"
const FA := "res://levels/fort/assets/"
const SEA_Y := -0.9                  # 島外面鋪的海（島面大約在 0，邊緣往下掉）
const RED := Color(0.80, 0.12, 0.10)
const LAND := Vector3(-22.0, 0.0, 46.4)   # 家豪跳上岸的地方（南岸的沙灘）

func _lines() -> Array:
	return [
		{"shot": "sea", "hold": 4.5, "cue": "o_sea", "fade_in": 1.4},
		{"shot": "gate", "hold": 3.3, "cue": "o_gate"},
		{"shot": "truck", "hold": 3.7, "cue": "n_truck"},
		{"shot": "tag", "hold": 2.6, "cue": "n_tag"},
		{"shot": "talk", "who": "神明", "text": "老闆的總部。每座島的貨，都從這裡出去。", "cue": "t_hq"},
		{"shot": "talk", "who": "家豪", "text": "……卡車也是？", "cue": "t_truck", "snap": 1.6},
		{"shot": "talk", "who": "神明", "text": "……也是。", "cue": "t_also", "snap": 1.4},
		{"shot": "talk", "who": "神明", "text": "牆裡沒有廟。在這裡，我跟幽靈差不多。", "cue": "t_ghost"},
		{"shot": "talk", "hold": 2.3, "cue": "t_cannon"},
		{"shot": "talk", "who": "家豪", "text": "……我不要。", "cue": "t_no", "snap": 1.5},
		{"shot": "wall", "hold": 3.2, "cue": "p_wall"},
		{"shot": "wall", "hold": 1.3, "cue": "p_in"},
		{"shot": "wall", "who": "家豪", "text": "……一卡車。", "cue": "p_read", "snap": 1.2},
		{"shot": "wall", "hold": 1.7, "cue": "p_out"},
		{"shot": "card", "hold": 4.0, "cue": "card", "fade_out": 0.5, "fade_in": 0.9},
	]

func _skip_text() -> String:
	return "跳過開場"

func _next_scene() -> String:
	return _stage_after(STAGE)

var _world
var _g := Vector2(-4.0, 9.6)         # 城門（牆線上）
var _out := Vector2(0, 1)            # 從要塞往門外
var _perp := Vector2(-1, 0)          # 站在門外面向城門時的左手邊
var _boat: Node3D
var _cannon: Node3D
var _trucks: Array = []              # {node, wheels}
var _runs: Array = []                # 卡車正在開的路線 {i, a0, a1, b, t0, dur}
var _track := -1                     # 家豪的眼睛跟著哪一輛卡車
var _poster_p: Control
var _spots: Array = []               # 貼了懸賞單的那幾段牆 {c（牆腳、外牆面的中間）, n（往外）, b, h}
var _aim := Vector3.FORWARD          # 大砲對著哪個方向
var _card_p: Control
var _boat_go := false
var _mats := {}

## 城門前面的座標：a 是往門外幾公尺（負的是門裡面），b 是往左手邊幾公尺（從門外看）
func P(a: float, b: float) -> Vector3:
	var q := _g + _out * a + _perp * b
	return Vector3(q.x, float(_world.height_at(q.x, q.y)), q.y)

## (x, z) 落到地面上
func G3(p: Vector3) -> Vector3:
	return Vector3(p.x, float(_world.height_at(p.x, p.z)), p.z)

## 拿來拍「整面牆」的那段牆：城門東邊、離城門大約 9 公尺
func _wall_spot() -> Dictionary:
	var best := {"c": P(-2.0, -9.0), "n": Vector3(_out.x, 0, _out.y), "b": -9.0, "h": 4.2}
	var d := INF
	for s in _spots:
		var k := absf(float(s.b) + 9.5)
		if float(s.b) < 0.0 and k < d:
			d = k
			best = s
	return best

## 家豪對話時站的地方：門外路邊
func H0() -> Vector3:
	return P(10.0, -3.0)

func _story_build() -> void:
	mark_seen("fort_opening")        # 先記下來：底下借第 0 關的場地時，那一關就不會又轉回開場
	# 要塞的根節點一進場景就把「現在是第幾小關」寫進 Engine（fort_world.gd 讀）；借完場地要放回原本的值
	var had := Engine.has_meta("fort_stage")
	var old = Engine.get_meta("fort_stage") if had else null
	var stage := _borrow_stage(STAGE)
	if had:
		Engine.set_meta("fort_stage", old)
	else:
		Engine.remove_meta("fort_stage")
	_world = stage.get_node("World")
	_g = _world.gate_pos
	_out = (_world.gate_dir as Vector2).normalized()
	_perp = Vector2(-_out.y, _out.x)
	# 場地自己帶的家豪藏起來（守衛留著，站在門裡面）
	var chars = _world.get_node_or_null("Characters")
	if chars and chars.get("hero") is Node3D:
		(chars.hero as Node3D).visible = false
	# 卡車要開過的路上，中庭的木箱先收起來
	var props: Node = _world.get_node_or_null("Props")
	if props:
		var a := P(-14.0, 0.0)
		var b := P(1.0, 0.0)
		for c in props.get_children():
			var n := c as Node3D
			if n and _seg_dist(Vector2(n.position.x, n.position.z), Vector2(a.x, a.z), Vector2(b.x, b.z)) < 2.4:
				n.visible = false
	_make_mats()
	_build_sea()
	_make_hero(self)
	_boat = _make_boat()
	_build_cannon()
	for k in 2:
		_trucks.append(_make_truck([Color(0.30, 0.40, 0.55), Color(0.62, 0.20, 0.18)][k]))
	_build_posters()
	_clear_trees(-4.5, 13.0, -15.0, -4.5)
	_make_fort_sounds()

func _seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var t := clampf((p - a).dot(b - a) / maxf((b - a).length_squared(), 0.0001), 0.0, 1.0)
	return p.distance_to(a.lerp(b, t))

func _make_mats() -> void:
	_mats.dark = _toon(Color(0.16, 0.16, 0.18))
	_mats.glass = _toon(Color(0.22, 0.30, 0.36))
	_mats.wood = _toon(Color(0.58, 0.42, 0.26))
	_mats.wood_d = _toon(Color(0.42, 0.30, 0.19))
	_mats.tire = _toon(Color(0.10, 0.10, 0.11))
	_mats.light = _glow(Color(1.0, 0.95, 0.75))
	_mats.red = _glow(RED)
	_mats.sand = _toon(Color(0.93, 0.84, 0.62))

# ================================================================== 佈景

## 島外面的海、南岸的沙灘
func _build_sea() -> void:
	var pm := PlaneMesh.new()
	pm.size = Vector2(3000, 3000)
	var wm := ShaderMaterial.new()
	wm.shader = load("res://shaders/water.gdshader")
	wm.set_shader_parameter("island_center", Vector2(9000, 9000))   # 整片不透明
	wm.set_shader_parameter("deep", Color(0.20, 0.47, 0.58))
	wm.set_shader_parameter("light_c", Color(0.55, 0.80, 0.82))
	var sea := _mesh(self, pm, Vector3(0, SEA_Y, 0), wm)
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# 沙灘：島邊一條平的，再斜斜地伸進海裡
	for s in [[Vector3(56.0, 0.1, 7.0), Vector3(-12.0, -0.01, 43.0), 0.0], [Vector3(56.0, 0.1, 3.9), Vector3(-12.0, -0.80, 48.2), 0.44]]:
		var sand := _box(self, s[0], s[1], _mats.sand, Vector3(float(s[2]), 0, 0))
		sand.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

## 牆外的大砲：砲口對著牆裡面，旁邊一小堆砲彈
func _build_cannon() -> void:
	var at := P(6.5, 7.0)
	var aim := P(-9.0, 2.5)
	var d := aim - at
	_aim = Vector3(d.x, 0, d.z).normalized()
	_cannon = _glb(self, FA + "pirate/cannon.glb", at, atan2(d.x, d.z), 1.9)
	_no_shadow(_cannon)
	for k in 3:
		var bp := at + Vector3(-1.3 + 0.35 * k, 0, 1.2 + 0.25 * (k % 2))
		_no_shadow(_glb(self, FA + "pirate/cannon-ball.glb", bp, 0.0, 1.4))

## 卡車：車頭、車斗、四個輪子，車斗上三個蓋著「貨」字章的木箱。車頭朝 +Z
func _make_truck(col: Color) -> Dictionary:
	var t := Node3D.new()
	add_child(t)
	var body := _toon(col)
	var roof := _toon(col.darkened(0.25))
	_box(t, Vector3(1.9, 0.28, 5.0), Vector3(0, 0.62, -0.2), _mats.dark)          # 底盤
	_box(t, Vector3(2.0, 1.3, 1.5), Vector3(0, 1.41, 1.55), body)                  # 車頭
	_box(t, Vector3(2.04, 0.12, 1.56), Vector3(0, 2.1, 1.55), roof)
	_box(t, Vector3(1.76, 0.56, 0.06), Vector3(0, 1.72, 2.3), _mats.glass)         # 擋風玻璃
	for sx in [-1.0, 1.0]:
		_box(t, Vector3(0.06, 0.5, 0.78), Vector3(sx * 1.0, 1.72, 1.72), _mats.glass)
		_box(t, Vector3(0.3, 0.16, 0.06), Vector3(sx * 0.7, 1.0, 2.31), _mats.light)   # 車燈
	_box(t, Vector3(1.9, 0.22, 0.12), Vector3(0, 0.72, 2.34), _mats.dark)          # 保險桿
	# 車斗
	_box(t, Vector3(2.1, 0.14, 3.3), Vector3(0, 0.84, -0.95), _mats.wood_d)
	for sx in [-1.0, 1.0]:
		_box(t, Vector3(0.08, 0.28, 3.3), Vector3(sx * 1.01, 1.04, -0.95), _mats.wood)
	_box(t, Vector3(2.1, 0.28, 0.08), Vector3(0, 1.04, -2.57), _mats.wood)
	_box(t, Vector3(2.1, 0.6, 0.08), Vector3(0, 1.2, 0.68), _mats.wood)
	# 輪子（開的時候會轉）
	var wheels: Array = []
	for z in [1.45, -1.85]:
		for sx in [-1.0, 1.0]:
			var w := _cyl(t, 0.42, 0.42, 0.3, Vector3(sx * 0.92, 0.42, z), _mats.tire, Vector3(0, 0, PI * 0.5), 14)
			wheels.append(w)
	# 木箱：兩箱並排、後面一箱疊高
	for cp in [Vector3(-0.48, 0.91, -0.3), Vector3(0.48, 0.91, -0.3), Vector3(0.0, 0.91, -1.65)]:
		_crate(t, cp, 0.92)
	_no_shadow(t)
	t.visible = false
	return {"node": t, "wheels": wheels}

## 一個木箱：左右兩面、後面蓋著紅色的「貨」字章
func _crate(parent: Node3D, pos: Vector3, size: float) -> void:
	var holder := Node3D.new()
	holder.position = pos
	parent.add_child(holder)
	var m := _glb(holder, FA + "pirate/crate.glb", Vector3.ZERO, 0.0, 1.0)
	var half := size * 0.5
	if m:
		_fit(m, size)
		var box := _local_box(holder)
		m.position = Vector3(-box.get_center().x, -box.position.y, -box.get_center().z)
		half = maxf(box.size.x, box.size.z) * 0.5
	else:
		_box(holder, Vector3.ONE * size, Vector3(0, half, 0), _mats.wood)
	for f in [[Vector3(1, 0, 0), PI * 0.5], [Vector3(-1, 0, 0), -PI * 0.5], [Vector3(0, 0, -1), PI]]:
		_stamp_on(holder, (f[0] as Vector3) * (half + 0.012) + Vector3(0, size * 0.6, 0), float(f[1]))

## 紅圈裡一個「貨」字（章朝 yaw 那一面）
func _stamp_on(parent: Node3D, pos: Vector3, yaw: float) -> void:
	var s := Node3D.new()
	s.position = pos
	s.rotation.y = yaw
	parent.add_child(s)
	var l := Label3D.new()
	l.text = "貨"
	if UIStyle.font():
		l.font = UIStyle.font()
	l.font_size = 96
	l.pixel_size = 0.0024
	l.modulate = RED
	l.outline_size = 0
	l.double_sided = false
	l.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	s.add_child(l)
	_torus(s, 0.17, 0.2, Vector3(0, 0.0, 0.0), _mats.red, Vector3(PI * 0.5, 0, 0))

## 一個節點底下所有網格合起來的範圍（用它自己的座標）
func _local_box(n: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for c in n.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		var b := (n.global_transform.affine_inverse() * mi.global_transform) * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box

## 城門兩邊的城牆外面：貼滿尋雞啟事（一整面都是家豪的臉）。全部畫成一個 MultiMesh
func _build_posters() -> void:
	var walls: Node = _world.get_node_or_null("FortWalls")
	if walls == null:
		return
	var r := RandomNumberGenerator.new()
	r.seed = 66
	var xfs: Array = []
	var fc: Vector2 = _world.FORT_C
	for c in walls.get_children():
		var n := c as Node3D
		if n == null or is_equal_approx(n.scale.x, n.scale.z):
			continue                 # 柱子跳過
		var p := Vector2(n.global_position.x, n.global_position.z)
		var b := (p - _g).dot(_perp)
		if not ((b < -5.6 and b > -17.0) or (b > 5.6 and b < 13.0)):
			continue
		if (p - _g).dot(_out) < -6.0:
			continue
		var box := _local_box(n)
		var outward := (p - fc).normalized()
		var bz := n.global_basis.z
		var sgn := 1.0 if Vector2(bz.x, bz.z).dot(outward) > 0.0 else -1.0
		var zf := box.end.z if sgn > 0.0 else box.position.z
		var normal := (bz * sgn).normalized()
		_spots.append({"c": n.global_transform * Vector3(box.get_center().x, box.position.y, zf), "n": normal, "b": b,
			"h": box.size.y * n.scale.y})
		var cols := 3
		var rows := 4
		for i in cols:
			for j in rows:
				if r.randf() < 0.07:
					continue
				var x := lerpf(box.position.x, box.end.x, (float(i) + 0.5) / cols) + r.randf_range(-0.05, 0.05) * box.size.x
				var y := lerpf(box.position.y, box.end.y, 0.14 + 0.62 * (float(j) + 0.5) / rows) + r.randf_range(-0.03, 0.03) * box.size.y
				var wp := n.global_transform * Vector3(x, y, zf)
				wp += normal * (0.03 + 0.004 * float((i + j) % 3))
				var basis := Basis.looking_at(-normal, Vector3.UP).rotated(normal, r.randf_range(-0.16, 0.16))
				xfs.append(Transform3D(basis.scaled(Vector3.ONE * r.randf_range(0.92, 1.08)), wp))
	if xfs.is_empty():
		return
	var qm := QuadMesh.new()
	qm.size = Vector2(0.66, 0.88)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = _poster_texture()
	mat.roughness = 1.0
	mat.metallic_specular = 0.0
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = qm
	mm.instance_count = xfs.size()
	for k in xfs.size():
		mm.set_instance_transform(k, xfs[k])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)

## 城門東邊那幾段貼滿懸賞單的牆前面：樹先移開（只動這次借來的場地，關卡本身不受影響）。
## 範圍用城門座標：往門外 a0～a1 公尺、往左手邊 b0～b1 公尺
func _clear_trees(a0: float, a1: float, b0: float, b1: float) -> void:
	var forest: Node = _world.get_node_or_null("Forest")
	if forest == null:
		return
	var gone := Transform3D(Basis().scaled(Vector3.ZERO), Vector3(0, -100, 0))
	for c in forest.get_children():
		var mmi := c as MultiMeshInstance3D
		if mmi == null or mmi.multimesh == null:
			continue
		var mm := mmi.multimesh
		for i in mm.instance_count:
			var o := mm.get_instance_transform(i).origin
			var q := Vector2(o.x, o.z) - _g
			var a := q.dot(_out)
			var b := q.dot(_perp)
			if a > a0 and a < a1 and b > b0 and b < b1:
				mm.set_instance_transform(i, gone)

## 懸賞單的貼圖：黃紙、上面一條紅（尋雞啟事）、家豪的頭像、幾行字、紅色的懸賞金額
func _poster_texture() -> Texture2D:
	var w := 120
	var h := 160
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color("b08f55"))
	img.fill_rect(Rect2i(3, 3, w - 6, h - 6), Color("f1e2b8"))
	img.fill_rect(Rect2i(12, 11, w - 24, 17), RED)
	var tex := load(PORTRAIT) as Texture2D
	if tex:
		var pi := tex.get_image()
		if pi:
			if pi.is_compressed():
				pi.decompress()
			pi.convert(Image.FORMAT_RGBA8)
			pi.resize(90, 90, Image.INTERPOLATE_BILINEAR)
			img.blend_rect(pi, Rect2i(0, 0, 90, 90), Vector2i(15, 33))
	for k in 2:
		img.fill_rect(Rect2i(24 + 8 * k, 127 + 7 * k, w - 48 - 16 * k, 3), Color(0.35, 0.29, 0.22))
	img.fill_rect(Rect2i(16, 143, w - 32, 9), RED)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

# ================================================================== 聲音

func _make_fort_sounds() -> void:
	# 卡車開過去：低低的引擎聲，慢慢大聲再變小
	var dur := 3.0
	var b := s_buf(dur)
	s_noise(b, 0.0, dur, 0.35, 0.02, 77, 0.0)
	var ph := 0.0
	for i in b.size():
		var t := float(i) / RATE
		ph += TAU * (44.0 + 5.0 * sin(t * 11.0)) / RATE
		b[i] = (b[i] + sin(ph) * 0.45 + sin(ph * 2.0) * 0.22 + sin(ph * 3.0) * 0.1) * sin(PI * t / dur)
	_snd["engine"] = s_wav(b)
	# 遠處的號角：低低的兩個音
	dur = 2.4
	b = s_buf(dur)
	ph = 0.0
	for i in b.size():
		var t := float(i) / RATE
		var f := 196.0 if t < 0.95 else 261.6
		ph += TAU * f / RATE
		var env := minf(t / 0.22, 1.0) * minf((dur - t) / 0.7, 1.0) * (0.75 if t < 0.95 else 1.0)
		var s := 0.0
		for k in 5:
			s += sin(ph * float(k + 1)) / float(k + 1) * (0.9 if k == 0 else 0.55)
		b[i] = s * env * 0.3
	_snd["horn"] = s_wav(b)

# ================================================================== 每一畫面

## 船從外海往沙灘划
func _boat_a() -> Vector3:
	return Vector3(LAND.x - 9.0, SEA_Y, 57.0)

func _boat_b() -> Vector3:
	return Vector3(LAND.x - 0.4, SEA_Y, 49.4)

func _hero_in_boat() -> void:
	if _boat:
		(_hero.node as Node3D).global_position = _boat.to_global(Vector3(0, 0.24, -0.3))
		(_hero.node as Node3D).rotation.y = _boat.rotation.y

## 卡車 i 從 a0 開到 a1（城門座標），dur 秒，delay 秒後出發
func _run(i: int, a0: float, a1: float, dur: float, delay := 0.0, b := 0.0) -> void:
	for r in _runs:
		if int(r.i) == i:
			_runs.erase(r)
			break
	_runs.append({"i": i, "a0": a0, "a1": a1, "b": b, "t0": _t + delay, "dur": dur})
	_place_truck(i, a0, b, a1 > a0)
	(_trucks[i].node as Node3D).visible = true
	_at(delay, func(): _play("engine", -11.0, 0.9 + 0.1 * i))

func _place_truck(i: int, a: float, b: float, outward: bool) -> void:
	var t := _trucks[i].node as Node3D
	t.global_position = P(a, b) + Vector3(0, 0.02, 0)
	var d := _out if outward else -_out
	t.rotation = Vector3(0, atan2(d.x, d.y), 0)

func _truck_pos(i: int) -> Vector3:
	return (_trucks[i].node as Node3D).global_position

func _story_tick(dt: float) -> void:
	if _boat_go:
		var k := clampf(_shot_t / 3.6, 0.0, 1.0)
		var e := 1.0 - pow(1.0 - k, 2.2)
		_boat_at(_boat, _boat_a().lerp(_boat_b(), e), _boat_b() - _boat_a())
		if _shot_t < 3.7:
			_hero_in_boat()
	elif _shot == "sea":
		_boat_at(_boat, _boat_b(), _boat_b() - _boat_a())
	for r in _runs:
		var k := clampf((_t - float(r.t0)) / float(r.dur), 0.0, 1.0)
		var a := lerpf(float(r.a0), float(r.a1), k)
		_place_truck(int(r.i), a, float(r.b), float(r.a1) > float(r.a0))
		if k > 0.0 and k < 1.0:
			for w in _trucks[int(r.i)].wheels:
				(w as Node3D).rotation.x += dt * 13.0
	if _track >= 0:
		_hero.look = _truck_pos(_track) + Vector3(0, 1.4, 0)

# ================================================================== 鏡頭

func _enter_shot(s: String) -> void:
	var hero := _hero.node as Node3D
	hero.visible = true
	hero.rotation = Vector3.ZERO
	_hero.look = null
	_track = -1
	_set_anim(_hero, "idle")
	_hood_reset()
	_boat_go = false
	_runs.clear()
	for t in _trucks:
		(t.node as Node3D).visible = false
	if _boat:
		_boat.visible = s == "sea"
	match s:
		"sea":
			_boat_go = true
			_boat_at(_boat, _boat_a(), _boat_b() - _boat_a())
			_hero_in_boat()
		"gate":
			hero.global_position = P(19.0, -1.6)
			_face(_hero, P(0, 0))
		"truck":
			hero.global_position = P(8.4, -8.4)
			_face(_hero, P(0.0, -1.0))
		"tag", "talk":
			hero.global_position = H0()
			_face(_hero, P(0.0, -1.0))
		"wall":
			var sp := _wall_spot()
			hero.global_position = G3(sp.c + (sp.n as Vector3) * 2.3 + Vector3(sp.n.z, 0, -sp.n.x) * 0.7)
			_face(_hero, sp.c)
		"card":
			hero.visible = false

func _on_line(l: Dictionary) -> void:
	var hero := _hero.node as Node3D
	var h0 := H0()
	match String(l.get("cue", "")):
		# ---------------------------------------------------------- ① 靠岸
		"o_sea":
			# 從海上看：小船往南岸的沙灘划，遠遠看得到城牆和城門
			_shot_cam(Vector3(LAND.x - 3.0, 3.0, 64.5), Vector3(-9.0, -2.4, 12.0), 34.0, 0.0, Vector3(0.12, 0.0, -0.35))
			_music_play("theme", -19.0, 2.5)
			_amb_play("waves", -15.0, 1.5)
			_face(_hero, P(0, 0))
			_at(1.1, func(): _play("horn", -15.0))
			_at(5.1, func():                 # 淡入 1.4 秒之後的第 3.7 秒：船剛好靠岸
				_hop(_hero, LAND + Vector3(0, float(_world.height_at(LAND.x, LAND.z)), 0), 0.6, 1.2, 0.0, "idle")
				_play("whoosh", -15.0, 1.3))
		"o_gate":
			# 城門：「人類要塞」；牆外架著一門大砲，砲口對著牆裡
			_shot_cam(P(27.0, -6.5) + Vector3(0, 2.4, 0), P(0.0, 2.2) + Vector3(0, 3.0, 0), 34.0, 0.0, Vector3(-0.15, 0.02, -0.5))
			_amb_play("wind", -20.0, 1.0)
			_walk(_hero, P(14.5, -2.4), 3.6)
			_at(0.5, func(): _play("horn", -12.0, 0.98))
		# ---------------------------------------------------------- ② 號碼
		"n_truck":
			# 卡車從城門開出來，車斗的木箱都蓋著紅色的「貨」字章
			_shot_cam(P(10.0, -3.7) + Vector3(0, 1.5, 0), P(0.0, -0.4) + Vector3(0, 2.6, 0), 40.0, 0.0, Vector3(0, 0, 0))
			_run(0, -6.0, 3.6, 4.6, 0.0)
		"n_tag":
			# 又一輛開過去：家豪脖子上的牌子晃了一下
			_shot_cam(h0 - Vector3(_out.x, 0, _out.y) * 3.1 + Vector3(_perp.x, 0, _perp.y) * -1.0 + Vector3(0, 1.4, 0), h0 + Vector3(0, 1.2, 0), 34.0, 0.0, Vector3(0, 0, 0))
			_run(1, 0.0, 30.0, 4.2, 0.0)
			_hero.look = h0 - Vector3(_out.x, 0, _out.y) * 3.0 + Vector3(0, 1.3, 0)
			_at(1.7, func(): _emote(_hero, "…", Color(1, 1, 1), 0.9, 0.7))
			_at(0.65, func():
				_swing_tag()
				_play("whoosh", -12.0, 0.55))
		# ---------------------------------------------------------- ③ 對話
		"t_hq":
			# 從家豪背後往上看：城牆把天空擋掉一半
			_shot_cam(h0 + Vector3(_out.x, 0, _out.y) * 3.6 + Vector3(_perp.x, 0, _perp.y) * -1.0 + Vector3(0, 0.6, 0), P(0.0, 0.0) + Vector3(0, 4.4, 0), 42.0, 0.0, Vector3(0, 0.03, -0.05))
			_hero.look = P(0, 0) + Vector3(0, 4.0, 0)
			_run(0, -6.0, 26.0, 7.0, 0.8)
		"t_truck":
			_shot_cam(h0 - Vector3(_out.x, 0, _out.y) * 2.6 + Vector3(_perp.x, 0, _perp.y) * 1.0 + Vector3(0, 1.45, 0), h0 + Vector3(0, 1.1, 0), 32.0, 0.0, Vector3(0.0, 0, 0.0))
			_track = 0
		"t_also":
			_track = -1
			_hero.look = null
			_set_anim(_hero, "sad")
			_shot_cam(h0 - Vector3(_out.x, 0, _out.y) * 2.2 + Vector3(_perp.x, 0, _perp.y) * 0.8 + Vector3(0, 1.3, 0), h0 + Vector3(0, 1.0, 0), 30.0, 0.0, Vector3(0.01, 0, 0.02))
		"t_ghost":
			# 神明的角度：從牆頂上往裡面看，牆裡只有兵和箱子，沒有廟
			_set_anim(_hero, "idle")
			_shot_cam(P(3.0, 5.0) + Vector3(0, 13.0, 0), Vector3(_world.FORT_C.x, 0.0, _world.FORT_C.y), 46.0, 0.0, Vector3(0.0, 0.02, -0.25))
		"t_cannon":
			# 神明看向那門大砲
			var cp := _cannon.global_position
			var cs := Vector3(-_aim.z, 0, _aim.x)
			_shot_cam(cp - _aim * 4.6 + cs * 1.8 + Vector3(0, 5.2, 0), cp + _aim * 3.0 + Vector3(0, 1.0, 0), 40.0)
			_at(0.1, func(): _shot_cam(cp - _aim * 4.0 + cs * 1.4 + Vector3(0, 3.4, 0), cp + _aim * 3.0 + Vector3(0, 1.3, 0), 40.0, 2.2))
			_at(1.5, func(): _hero.look = cp + Vector3(0, 1.0, 0))
		"t_no":
			_shot_cam(h0 - Vector3(_out.x, 0, _out.y) * 2.4 + Vector3(_perp.x, 0, _perp.y) * 0.4 + Vector3(0, 1.4, 0), h0 + Vector3(0, 1.1, 0), 30.0, 0.0, Vector3(0, 0, 0.02))
			_hero.look = _cannon.global_position + Vector3(0, 1.0, 0)
			_at(0.35, func():
				_hero.look = null
				_set_anim(_hero, "cool"))
			_at(1.0, func(): _emote(_hero, "…", Color(1, 1, 1), 1.0, 0.8))
		# ---------------------------------------------------------- ④ 尋雞啟事
		"p_wall":
			# 鏡頭往上搖：整面城牆貼滿懸賞單
			var sp := _wall_spot()
			var wb: Vector3 = sp.c
			var wn: Vector3 = sp.n
			var ws := Vector3(wn.z, 0, -wn.x)
			var cam := wb + wn * 5.6 - ws * 1.0 + Vector3(0, 0.7, 0)
			_shot_cam(cam, wb + Vector3(0, 0.9, 0), 54.0)
			_at(0.2, func(): _shot_cam(cam + Vector3(0, 0.3, 0), wb + Vector3(0, float(sp.h) * 0.95, 0), 54.0, 2.8))
			_set_anim(_hero, "lookup")
		"p_in":
			_play("whoosh", -10.0, 0.7)
			_at(0.35, func():
				_poster_p = _poster("飼料一卡車")
				_set_anim(_hero, "shock"))
		"p_read":
			_set_anim(_hero, "lookup")
		"p_out":
			_hide_paper(_poster_p, true)
			_poster_p = null
			var hp := hero.global_position
			var wn: Vector3 = _wall_spot().n
			_shot_cam(hp + wn * 2.8 + Vector3(wn.z, 0, -wn.x) * 0.9 + Vector3(0, 1.4, 0), hp + Vector3(0, 1.15, 0), 32.0)
			_face(_hero, hp + wn * 3.0)
			_at(0.4, func():
				_set_anim(_hero, "cool")
				_emote(_hero, "…", Color(1, 1, 1), 1.0, 0.8))
		# ---------------------------------------------------------- ⑤ 標題卡
		"card":
			_shot_cam(Vector3(-46.0, 26.0, 92.0), Vector3(-2.0, 0.0, 0.0), 44.0, 0.0, Vector3(0.3, -0.05, -0.25))
			_amb_play("waves", -18.0, 1.0)
			_at(0.45, func(): _card_p = _title_card(4, "人類要塞", "牆裡面"))

## 卡車開過去帶起一陣風：脖子上的牌子晃一晃
func _swing_tag() -> void:
	if _tag66 == null:
		return
	var base := _tag66.rotation
	var tw := _tw()
	for k in [[0.55, -0.35, 0.12], [-0.4, 0.25, 0.16], [0.28, -0.18, 0.18], [-0.14, 0.1, 0.2], [0.0, 0.0, 0.24]]:
		tw.tween_property(_tag66, "rotation", base + Vector3(k[0], 0.0, k[1]), k[2]).set_trans(Tween.TRANS_SINE)
