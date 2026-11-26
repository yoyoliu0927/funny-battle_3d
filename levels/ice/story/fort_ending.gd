extends "res://levels/ice/story/story_kit.gd"
## 人類要塞的結尾動畫（第 4 天傍晚）。分鏡在 levels/ice/docs/大關開場與結尾動畫.md 第 7 節。
## 第一次破完要塞最後一關（stage_3「指揮官的院子」）回到地圖時播（見 story_registry.gd），播完回地圖。
## 場地借第 3 關（拿掉戰局、玩家和介面）。要塞的關卡沒有海，這裡在島外面鋪一片海、東岸鋪一條沙灘給小船離岸。
## 整個遊戲情緒最低的一章：出貨板那一拍配樂停掉，靜音拍不放笑點，羽毛那一拍配樂才回來。
##
## 七拍：收場（指揮官倒地、砲手投降、要塞雞從砲管探頭）→ 號碼（出貨板：六十六號「已出貨」，拿不掉）
##       → 腳牌（摸牌子；砲手說老闆上了丹穴山）→ 靜音拍（日落，打碟打到一半停下來）
##       → 羽毛（四根）→ 上船（船頭第一次朝北，鳥群也往北飛）→ 手帳

const STAGE := "res://levels/fort/stage_3/stage.tscn"
const SEA_Y := -0.9
const PURPLE := Color("9a72d8")            # 要塞的羽毛（紫）
const FEATHERS := [Color("4fc3d9"), Color("f2d03a"), Color("e2483a"), Color("9a72d8")]   # 青 冰雪、黃 森林、紅 霧山、紫 要塞
const RED := Color(0.78, 0.12, 0.10)
const INK := Color(0.16, 0.12, 0.09)
const BOARD_FIRST := 43                    # 出貨板上的號碼：43～66，六欄四列，66 在右下角
const UNTICKED := [47, 52, 58, 63]         # 還沒打勾的格子
const TOUCH_WR := Vector3(-1.2, 0.0, -0.35)   # 摸脖子上的牌子：右翅膀收到胸前
const GULLS := 9
const BOSS_AT := Vector2(21.6, -5.2)       # 指揮官倒在哪（院子裡、梯子西邊）
const BOAT_A := Vector3(49.7, SEA_Y, 7.0)  # 東岸沙灘邊
const BOAT_B := Vector3(51.5, SEA_Y, -26.0) # 往北開

func _lines() -> Array:
	return [
		{"shot": "yard", "hold": 3.1, "cue": "y_wide", "fade_in": 1.0},
		{"shot": "yard", "who": "要塞雞", "text": "報告！今天不用試砲了嗎？", "cue": "y_hen", "snap": 1.8},
		{"shot": "climb", "hold": 3.2, "cue": "c_climb"},
		{"shot": "board", "hold": 3.7, "cue": "b_search"},
		{"shot": "board", "hold": 2.6, "cue": "b_66"},
		{"shot": "board", "who": "神明", "text": "……門關上之後的事，我也看不到。", "cue": "b_god"},
		{"shot": "board", "hold": 2.8, "cue": "g_touch"},
		{"shot": "board", "who": "砲手", "text": "老闆帶人上丹穴山了。說山上有會發光的鳥。", "cue": "g_boss"},
		{"shot": "dj", "hold": 6.0, "cue": "d_dj", "fade_out": 0.8, "fade_in": 1.2},
		{"shot": "dj", "hold": 5.0, "cue": "d_stop"},
		{"shot": "hood", "hold": 2.2, "cue": "w_gust"},
		{"shot": "hood", "who": "神明", "text": "四根了。你換毛換很兇。", "cue": "w_god"},
		{"shot": "hood", "who": "家豪", "text": "……壓力大。", "cue": "w_stress", "snap": 1.4},
		{"shot": "leave", "hold": 5.5, "cue": "l_leave", "fade_out": 0.6, "fade_in": 1.0},
		{"shot": "journal", "hold": 5.6, "cue": "j_page", "fade_out": 0.6, "fade_in": 0.8},
	]

func _skip_text() -> String:
	return "跳過"

func _voice_pitch(who: String) -> float:
	match who:
		"要塞雞": return 1.75
		"砲手": return 0.68
	return super(who)

func _actor_of(who: String) -> Dictionary:
	if who == "要塞雞":
		return _hen
	return super(who)

var _world
var _pc := Vector2(30.0, -10.0)      # 指揮官高台的中心
var _top := 5.0                      # 台頂多高
var _fwd := Vector2(0, 1)           # 從高台中心指向梯子（往院子）
var _side := Vector2(1, 0)
var _lfoot := Vector2.ZERO           # 梯子腳
var _ltop := Vector2.ZERO            # 梯子頂（台頂邊緣）
var _board: Node3D
var _cells := {}                     # 號碼 → 那一格在世界上的位置
var _cannon: Node3D                  # 東院的大砲（砲口對著高台）
var _muzzle := Vector3.ZERO
var _cdir := Vector3.FORWARD
var _hen: Dictionary = {}
var _hen_boat := false
var _boss: Node3D                    # 指揮官（胖商人模型）
var _gunners: Array = []             # {node, head, arms, palm}
var _birds: Array = []               # {node, wl, wr, off, ph}
var _boat: Node3D
var _leave_on := false
var _journal_p: Control
var _mats := {}
var _mountains: Node3D               # 島外圍的石山：最後出海那兩個鏡頭收起來（看得到海平線）

## 地面上的點
func G(x: float, z: float) -> Vector3:
	return Vector3(x, float(_world.height_at(x, z)), z)

## 台頂上的點：從高台中心往院子 f 公尺、往右 s 公尺
func T(f: float, s: float) -> Vector3:
	var q := _pc + _fwd * f + _side * s
	return Vector3(q.x, _top, q.y)

## 家豪在出貨板前面站的地方
func HB() -> Vector3:
	return T(1.1, 0.0)

func _story_build() -> void:
	mark_seen("fort_ending")
	var had := Engine.has_meta("fort_stage")
	var old = Engine.get_meta("fort_stage") if had else null
	var stage := _borrow_stage(STAGE)
	if had:
		Engine.set_meta("fort_stage", old)
	else:
		Engine.remove_meta("fort_stage")
	_world = stage.get_node("World")
	# 天色要從傍晚調到日落：天空和環境光複製一份再改，不動到關卡本身的資源
	var env := (_env_node.environment as Environment).duplicate(true) as Environment
	if env.sky:
		env.sky = env.sky.duplicate(true) as Sky
		if env.sky.sky_material:
			env.sky.sky_material = env.sky.sky_material.duplicate(true) as Material
	_env_node.environment = env
	_pc = _world.PLATFORM_C
	_top = float(_world.height_at(_pc.x, _pc.y))
	var lad: Array = _world.platform_ladder()
	if lad.size() == 2:
		_lfoot = lad[0]
		_ltop = lad[1]
		_fwd = (_lfoot - _pc).normalized()
	_side = Vector2(_fwd.y, -_fwd.x)
	_make_mats()
	_build_sea()
	_mountains = _world.get_node_or_null("Layout/DistantLayers/Mountains") as Node3D
	var post := _world.find_child("BossPost", true, false) as Node3D
	if post:
		post.visible = false        # 指揮官站位的紅色記號
	# 場地自己帶的角色：家豪、農夫藏起來；指揮官拿出來倒在院子裡
	var chars = _world.get_node_or_null("Characters")
	if chars:
		if chars.get("hero") is Node3D:
			(chars.hero as Node3D).visible = false
		var list: Array = chars.get("enemies") if chars.get("enemies") is Array else []
		for k in list.size():
			var e := list[k] as Node3D
			if k == list.size() - 1 and e.get_meta("source", "") == "merchant":
				_boss = e
			else:
				e.visible = false
	_lay_boss()
	# 炮塔上原本的砲手藏起來（換成舉手投降的）
	var top_gunner := Vector3.ZERO
	for t in _world.get("fort_towers"):
		var gn = (t as Dictionary).get("gunner")
		if gn is Node3D:
			(gn as Node3D).visible = false
			if (t.pos as Vector2).x > 20.0:
				top_gunner = (gn as Node3D).global_position
	# 東院的大砲：砲管裡躲著要塞雞
	var cl: Array = _world.get("cannons")
	if cl.size() >= 2:
		_cannon = cl[1].node
	elif not cl.is_empty():
		_cannon = cl[0].node
	if _cannon:
		var d := _cannon.global_basis.z
		d.y = 0.0
		_cdir = d.normalized()
		_muzzle = _cannon.global_position + Vector3(0, 0.78 * 1.9, 0) + _cdir * (1.4 * 1.9)
		# 砲管真正的前端（模型的範圍）：雞從這裡探出頭
		var box := AABB()
		var first := true
		for c in _cannon.find_children("*", "MeshInstance3D", true, false):
			var mi := c as MeshInstance3D
			var b := (_cannon.global_transform.affine_inverse() * mi.global_transform) * mi.get_aabb()
			box = b if first else box.merge(b)
			first = false
		if not first:
			var tip := _cannon.global_transform * Vector3(box.get_center().x, 0.0, box.end.z)
			_muzzle = Vector3(tip.x, _muzzle.y, tip.z)
	_make_hen()
	# 舉手投降的砲手：一個在梯子附近（接住音符、說老闆的事），兩個在炮塔下，一個在塔頂
	for g in [[Vector2(23.9, -2.4)], [Vector2(29.4, 1.0)], [Vector2(31.4, -0.6)]]:
		var p: Vector2 = g[0]
		_gunners.append(_gunner(G(p.x, p.y), HB()))
	if top_gunner != Vector3.ZERO:
		_gunners.append(_gunner(top_gunner + Vector3(0, -0.3, 0), HB()))
	_build_board()
	_make_hero(self, FEATHERS)
	_boat = _make_boat()
	for k in GULLS:
		_birds.append(_make_bird(k))
	_grade("gold")

func _make_mats() -> void:
	_mats.wood = _toon(Color(0.56, 0.40, 0.25))
	_mats.wood_d = _toon(Color(0.40, 0.28, 0.18))
	_mats.board = _toon(Color(0.80, 0.66, 0.46))
	_mats.line = _toon(Color(0.30, 0.22, 0.15))
	_mats.coat = _toon(Color(0.66, 0.18, 0.16))
	_mats.skin = _toon(Color(0.96, 0.78, 0.62))
	_mats.dark = _toon(Color(0.18, 0.18, 0.22))
	_mats.white = _toon(Color(0.95, 0.93, 0.88))
	_mats.brass = _toon(Color(0.86, 0.66, 0.30))
	_mats.lens = _glow(Color(0.75, 0.92, 1.0))
	_mats.helmet = _toon(Color(0.36, 0.42, 0.24))
	_mats.bird = _toon(Color(0.22, 0.20, 0.24))
	_mats.sand = _toon(Color(0.93, 0.84, 0.62))

# ================================================================== 佈景

## 島外面的海、東岸的沙灘
func _build_sea() -> void:
	var pm := PlaneMesh.new()
	pm.size = Vector2(3000, 3000)
	var wm := ShaderMaterial.new()
	wm.shader = load("res://shaders/water.gdshader")
	wm.set_shader_parameter("island_center", Vector2(9000, 9000))
	wm.set_shader_parameter("deep", Color(0.20, 0.45, 0.58))
	wm.set_shader_parameter("light_c", Color(0.60, 0.78, 0.82))
	var sea := _mesh(self, pm, Vector3(0, SEA_Y, 0), wm)
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for s in [[Vector3(5.0, 0.1, 40.0), Vector3(44.6, -0.01, 2.0), 0.0], [Vector3(3.9, 0.1, 40.0), Vector3(48.2, -0.80, 2.0), -0.44]]:
		var sand := _box(self, s[0], s[1], _mats.sand, Vector3(0, 0, float(s[2])))
		sand.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

## 指揮官倒在院子裡：仰躺、兩腳朝天，望遠鏡摔成兩截
func _lay_boss() -> void:
	if _boss == null:
		return
	_boss.reparent(self)
	for c in _boss.get_children():
		if c is MeshInstance3D:
			(c as MeshInstance3D).visible = false      # 椅子
	var at := G(BOSS_AT.x, BOSS_AT.y)
	_boss.global_position = at
	_boss.rotation = Vector3(0, 1.29, 0)      # 頭朝西（從院子的鏡頭看過去在左邊），兩腳朝天
	var body := _boss.get_node_or_null("Body") as Node3D
	if body:
		body.rotation.x = -1.45
		body.position.y = 0.72
		var arm := body.find_child("ArmR", false, false) as Node3D
		if arm:
			arm.rotation = Vector3(0.4, 0.0, -1.1)
		var head := body.find_child("Head", false, false) as Node3D
		if head:
			head.rotation.x = 0.25
			# 頭上轉圈圈的星星（暈了）
			var ring := Node3D.new()
			head.add_child(ring)
			ring.position = Vector3(0, 0.75, 0)
			for k in 3:
				var s := _label3d("✦", 56, Color(1.0, 0.9, 0.4), 10)
				s.no_depth_test = false
				ring.add_child(s)
				s.position = Vector3(cos(TAU * k / 3.0) * 0.45, 0, sin(TAU * k / 3.0) * 0.45)
			_spin_add(ring, Vector3.UP, 3.2)
	# 摔破的望遠鏡
	var tel := Node3D.new()
	add_child(tel)
	tel.global_position = at + Vector3(0.9, 0.0, 1.3)
	_cyl(tel, 0.07, 0.07, 0.5, Vector3(0, 0.08, 0), _mats.brass, Vector3(PI * 0.5, 0.4, PI * 0.5))
	_cyl(tel, 0.1, 0.1, 0.36, Vector3(0.55, 0.1, 0.35), _mats.brass, Vector3(PI * 0.5, -0.9, PI * 0.5))
	for k in 4:
		_box(tel, Vector3(0.07, 0.015, 0.05), Vector3(0.25 + 0.12 * k, 0.01, 0.6 - 0.1 * k), _mats.lens, Vector3(0, k * 0.9, 0))
	_no_shadow(tel)

## 要塞雞：戴小頭盔的雞（試砲用的），平常躲在砲管裡
func _make_hen() -> void:
	_hen = _actor(self, "hen", _muzzle - _cdir * 1.2, atan2(_cdir.x, _cdir.z), 0.45)
	var head := _hen.head as Node3D
	if head:
		var dome := SphereMesh.new()
		dome.radius = 0.2
		dome.height = 0.2
		dome.is_hemisphere = true
		dome.radial_segments = 14
		dome.rings = 5
		_mesh(head, dome, Vector3(0, 0.24, -0.01), _mats.helmet, Vector3(0.12, 0, 0), Vector3(1.12, 0.9, 1.16))
		_cyl(head, 0.26, 0.26, 0.025, Vector3(0, 0.245, -0.01), _mats.helmet, Vector3(0.12, 0, 0), 16)
		_box(head, Vector3(0.06, 0.06, 0.02), Vector3(0, 0.33, 0.2), _glow(Color(1.0, 0.85, 0.3)), Vector3(0.5, 0, 0))
	(_hen.node as Node3D).visible = false

## 舉著手的砲手（跟炮塔上的砲手同一種造型，多了手臂）。面向 look
func _gunner(at: Vector3, look: Vector3) -> Dictionary:
	var g := Node3D.new()
	add_child(g)
	g.global_position = at
	var d := look - at
	g.rotation.y = atan2(d.x, d.z)
	g.scale = Vector3.ONE * 1.4
	for sx in [-0.13, 0.13]:
		_box(g, Vector3(0.16, 0.42, 0.18), Vector3(sx, 0.21, 0), _mats.dark)
	_box(g, Vector3(0.52, 0.72, 0.34), Vector3(0, 0.78, 0), _mats.coat)
	for r in [0.55, -0.55]:
		_box(g, Vector3(0.06, 0.82, 0.36), Vector3(0, 0.8, 0), _mats.white, Vector3(0, 0, r))
	var head := Node3D.new()
	head.position = Vector3(0, 1.32, 0)
	g.add_child(head)
	_box(head, Vector3(0.36, 0.36, 0.36), Vector3.ZERO, _mats.skin)
	_box(head, Vector3(0.44, 0.15, 0.44), Vector3(0, 0.24, 0), _mats.dark)
	_box(head, Vector3(0.3, 0.12, 0.3), Vector3(0, 0.36, 0), _mats.dark)
	for sx in [-0.08, 0.08]:
		_box(head, Vector3(0.05, 0.07, 0.02), Vector3(sx, 0.03, 0.185), _mats.dark)
	_box(head, Vector3(0.07, 0.06, 0.02), Vector3(0, -0.1, 0.185), _mats.dark)
	var arms: Array = []
	var palm := Node3D.new()
	for sx in [-1.0, 1.0]:
		var pv := Node3D.new()
		pv.position = Vector3(0.33 * sx, 1.08, 0)
		pv.rotation.z = 2.84 * sx
		g.add_child(pv)
		_box(pv, Vector3(0.14, 0.56, 0.16), Vector3(0, -0.28, 0), _mats.coat)
		_box(pv, Vector3(0.15, 0.15, 0.15), Vector3(0, -0.6, 0), _mats.skin)
		arms.append(pv)
		if sx > 0.0:
			pv.add_child(palm)
			palm.position = Vector3(0, -0.72, 0)
	_no_shadow(g)
	return {"node": g, "head": head, "arms": arms, "palm": palm, "ph": float(_gunners.size()) * 1.7}

## 出貨板：木頭板子上一格一格的號碼，有的打了勾；66 下面寫著「已出貨」
func _build_board() -> void:
	_board = Node3D.new()
	add_child(_board)
	var bc := _pc - _fwd * 1.3
	_board.global_position = Vector3(bc.x, _top - 0.05, bc.y)
	_board.rotation.y = atan2(_fwd.x, _fwd.y)
	for sx in [-2.35, 2.35]:
		_box(_board, Vector3(0.16, 3.9, 0.16), Vector3(sx, 1.95, -0.1), _mats.wood_d)
	_box(_board, Vector3(4.6, 3.0, 0.12), Vector3(0, 2.3, 0), _mats.board)
	_box(_board, Vector3(4.86, 0.16, 0.2), Vector3(0, 3.85, 0), _mats.wood_d)
	_box(_board, Vector3(4.86, 0.16, 0.2), Vector3(0, 0.76, 0), _mats.wood_d)
	# 標題
	var title := _board_label("出 貨", 96, INK)
	title.position = Vector3(0, 3.45, 0.075)
	# 格線：六欄四列
	var x0 := -2.1
	var cw := 0.7
	var y_top := 3.15
	var rh := 0.56
	for i in 7:
		_box(_board, Vector3(0.025, rh * 4.0, 0.02), Vector3(x0 + cw * i, y_top - rh * 2.0, 0.07), _mats.line)
	for j in 5:
		_box(_board, Vector3(cw * 6.0, 0.025, 0.02), Vector3(0, y_top - rh * j, 0.07), _mats.line)
	for j in 4:
		for i in 6:
			var num := BOARD_FIRST + j * 6 + i
			var cx := x0 + cw * (i + 0.5)
			var cy := y_top - rh * (j + 0.5)
			var big := num == 66
			var l := _board_label(str(num), 72, INK)
			l.position = Vector3(cx - (0.0 if big else 0.1), cy + (0.09 if big else 0.0), 0.08)
			if big:
				var s := _board_label("已出貨", 44, RED)
				s.position = Vector3(cx, cy - 0.15, 0.08)
			elif not num in UNTICKED:
				var tk := _board_label("✓", 64, RED)
				tk.position = Vector3(cx + 0.2, cy, 0.08)
			_cells[num] = _board.to_global(Vector3(cx, cy, 0.08))
	_no_shadow(_board)

func _board_label(text: String, size: int, col: Color) -> Label3D:
	var l := Label3D.new()
	l.text = text
	if UIStyle.font():
		l.font = UIStyle.font()
	l.font_size = size
	l.pixel_size = 0.004
	l.modulate = col
	l.outline_size = 0
	l.double_sided = false
	l.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_board.add_child(l)
	return l

## 一隻往北飛的鳥（翅膀會拍）
func _make_bird(k: int) -> Dictionary:
	var b := Node3D.new()
	add_child(b)
	_ball(b, 0.16, Vector3.ZERO, _mats.bird, Vector3(0.75, 0.65, 1.7), 8)
	var wings: Array = []
	for sx in [-1.0, 1.0]:
		var w := Node3D.new()
		w.position = Vector3(0.07 * sx, 0.03, 0.02)
		b.add_child(w)
		_box(w, Vector3(0.62, 0.03, 0.24), Vector3(0.31 * sx, 0, 0), _mats.bird)
		wings.append(w)
	b.scale = Vector3.ONE * 1.9
	_no_shadow(b)
	b.visible = false
	# V 字隊形：第 0 隻帶頭，左右兩排往後排
	var row := (k + 1) / 2
	var side := -1.0 if k % 2 == 1 else 1.0
	var off := Vector3(side * row * 1.5, -row * 0.25, row * 1.9) if k > 0 else Vector3.ZERO
	return {"node": b, "wl": wings[0], "wr": wings[1], "off": off, "ph": float(k) * 0.9}

# ================================================================== 天色

## gold：午後的金色；sunset：日落（太陽在出貨板後面、北邊低低的）；dusk：天快黑了
func _grade(kind: String) -> void:
	var back := Vector3(-_fwd.x, 0.0, -_fwd.y)
	var g := {}
	match kind:
		"gold":
			g = {"top": Color(0.40, 0.60, 0.82), "hor": Color(0.98, 0.85, 0.68), "cl": Color(1.0, 0.95, 0.86), "cs": Color(0.94, 0.78, 0.68),
				"amb": Color(0.82, 0.72, 0.64), "amb_e": 0.8, "fog": Color(0.98, 0.86, 0.72), "sun": Color(1.0, 0.82, 0.58), "sun_e": 1.6,
				"dir": Vector3(-0.45, 0.62, 0.64), "vis": 0.0}
		"sunset":
			g = {"top": Color(0.32, 0.34, 0.58), "hor": Color(1.0, 0.60, 0.38), "cl": Color(1.0, 0.76, 0.58), "cs": Color(0.80, 0.48, 0.52),
				"amb": Color(0.66, 0.54, 0.60), "amb_e": 0.78, "fog": Color(0.96, 0.64, 0.50), "sun": Color(1.0, 0.58, 0.34), "sun_e": 1.3,
				"dir": back + Vector3(0.25, 0.16, 0.0), "vis": 1.0}
		_:
			g = {"top": Color(0.20, 0.22, 0.44), "hor": Color(0.94, 0.54, 0.44), "cl": Color(0.88, 0.62, 0.60), "cs": Color(0.52, 0.38, 0.50),
				"amb": Color(0.56, 0.52, 0.68), "amb_e": 0.95, "fog": Color(0.70, 0.52, 0.55), "sun": Color(0.98, 0.54, 0.42), "sun_e": 0.9,
				"dir": back + Vector3(0.25, 0.06, 0.0), "vis": 1.0}
	var env := _env_node.environment
	env.ambient_light_color = g.amb
	env.ambient_light_energy = g.amb_e
	env.fog_light_color = g.fog
	if env.sky and env.sky.sky_material is ShaderMaterial:
		var sm := env.sky.sky_material as ShaderMaterial
		sm.set_shader_parameter("top_color", g.top)
		sm.set_shader_parameter("horizon_color", g.hor)
		sm.set_shader_parameter("cloud_color", g.cl)
		sm.set_shader_parameter("cloud_shade", g.cs)
		sm.set_shader_parameter("sun_vis", g.vis)
		sm.set_shader_parameter("sun_dir", (g.dir as Vector3).normalized())
	_sun.light_color = g.sun
	_sun.light_energy = g.sun_e
	_sun.global_basis = Basis.looking_at(-(g.dir as Vector3).normalized(), Vector3.UP)

# ================================================================== 動作

## 摸脖子上的牌子（"touch"）：右翅膀收到胸前、頭低下來。底層沒有這個動作，接在它後面加
func _animate(a: Dictionary, dt: float) -> void:
	var touching := String(a.anim) == "touch"
	if touching:
		a.anim = "still"
	super(a, dt)
	if touching:
		a.anim = "touch"
	var k: float = a.get("touch_k", 0.0)
	k = move_toward(k, 1.0 if touching else 0.0, dt * 2.6)
	a["touch_k"] = k
	if not _hero.is_empty() and a.node == _hero.node and _tag66:
		# 摸牌子的時候，牌子被翅膀托起來一點、翻上來給自己看
		_tag66.rotation.x = lerpf(0.12, -0.75, _ease(k))
		_tag66.position.y = 0.47 + 0.05 * _ease(k)
	if k > 0.001:
		var wr := a.wr as Node3D
		if wr:
			wr.rotation = wr.rotation.lerp(TOUCH_WR, _ease(k))
		var head := a.head as Node3D
		if head:
			head.rotation.x += 0.4 * _ease(k)

func _story_tick(dt: float) -> void:
	# 砲手：兩手舉著，一直在發抖；講話的那個頭會動
	for g in _gunners:
		var t := _t + float(g.ph)
		var arms: Array = g.arms
		for k in arms.size():
			var sx := -1.0 if k == 0 else 1.0
			(arms[k] as Node3D).rotation.z = 2.84 * sx + sin(t * 31.0 + k) * 0.035
		var talking: bool = g == _gunners[0] and _typing and _name.text == "砲手"
		(g.head as Node3D).rotation.x = sin(_t * 15.0) * 0.08 if talking else sin(t * 1.1) * 0.03
	# 鳥群往北飛
	for b in _birds:
		var n := b.node as Node3D
		if not n.visible:
			continue
		var f := sin(_t * 9.0 + float(b.ph))
		(b.wl as Node3D).rotation.z = f * 0.65
		(b.wr as Node3D).rotation.z = -f * 0.65
	if _leave_on:
		var k := clampf((_shot_t - 1.3) / 4.5, 0.0, 1.0)
		var e := k * k * (3.0 - 2.0 * k) * 0.6 + k * 0.4
		_boat_at(_boat, BOAT_A.lerp(BOAT_B, e), BOAT_B - BOAT_A)
		(_hero.node as Node3D).global_position = _boat.to_global(Vector3(0, 0.24, -0.4))
		(_hero.node as Node3D).rotation.y = _boat.rotation.y
		if _hen_boat:
			(_hen.node as Node3D).global_position = _boat.to_global(Vector3(-0.3, 0.36, -1.0))
			(_hen.node as Node3D).rotation.y = _boat.rotation.y
		var bk := clampf((_shot_t - 0.6) / 5.2, 0.0, 1.0)
		for b in _birds:
			var n := b.node as Node3D
			n.visible = true
			n.global_position = Vector3(53.0, 6.0, 26.0).lerp(Vector3(49.0, 12.0, -40.0), bk) + (b.off as Vector3)
			n.rotation.y = PI
	elif _shot == "journal":
		var bk := clampf(_shot_t / 6.4, 0.0, 1.0)
		for b in _birds:
			var n := b.node as Node3D
			n.visible = true
			n.global_position = Vector3(46.0, 20.0, -50.0).lerp(Vector3(42.0, 26.0, -120.0), bk) + (b.off as Vector3) * 1.6
			n.rotation.y = PI

# ================================================================== 鏡頭

func _enter_shot(s: String) -> void:
	var hero := _hero.node as Node3D
	hero.visible = true
	hero.rotation = Vector3.ZERO
	_hero.look = null
	_set_anim(_hero, "idle")
	_hood_reset()
	_notes(false)
	_leave_on = false
	if _boat:
		_boat.visible = s == "leave"
	for b in _birds:
		(b.node as Node3D).visible = false
	var hen := _hen.node as Node3D
	match s:
		"yard":
			hero.global_position = G(22.4, -0.6)
			_face(_hero, G(BOSS_AT.x, BOSS_AT.y))
			hen.visible = false
		"climb":
			hen.visible = false
			hero.global_position = G(_lfoot.x, _lfoot.y) + Vector3(_fwd.x, 0, _fwd.y) * 0.4
			_face(_hero, Vector3(_pc.x, 0, _pc.y))
		"board":
			hen.visible = false
			hero.global_position = HB()
			_face(_hero, Vector3(_pc.x - _fwd.x * 3.0, _top, _pc.y - _fwd.y * 3.0))
		"dj", "hood":
			if s == "dj":
				_grade("sunset")
			hen.visible = false
			hero.global_position = HB()
			# 打碟時面向院子；羽毛那一拍轉回去看著出貨板（從背後拍，板子在前面）
			_face(_hero, HB() + Vector3(_fwd.x, 0, _fwd.y) * (3.0 if s == "dj" else -3.0))
		"leave":
			_grade("sunset")
			if _mountains:
				_mountains.visible = false
			_leave_on = true
			_hen_boat = false
			_boat_at(_boat, BOAT_A, BOAT_B - BOAT_A)
			hen.visible = true
			hen.global_position = G(47.0, 7.8)
			_set_anim(_hen, "idle")
			_face(_hen, _boat.global_position)
		"journal":
			_grade("dusk")
			if _mountains:
				_mountains.visible = false
			hero.visible = false
			hen.visible = false
			for g in _gunners:
				(g.node as Node3D).visible = true

func _on_line(l: Dictionary) -> void:
	var hero := _hero.node as Node3D
	var hb := HB()
	var fd := Vector3(_fwd.x, 0, _fwd.y)
	var sd := Vector3(_side.x, 0, _side.y)
	match String(l.get("cue", "")):
		# ---------------------------------------------------------- ① 收場
		"y_wide":
			# 指揮官倒在院子裡，望遠鏡摔破；砲手們舉手投降；後面高台上是出貨板
			_shot_cam(G(19.4, 7.2) + Vector3(0, 4.6, 0), G(26.0, -3.6) + Vector3(0, 2.2, 0), 48.0, 0.0, Vector3(0.1, 0.0, -0.12))
			_music_play("theme", -20.0, 2.0)
			_amb_play("wind", -19.0, 1.0)
			_hero.look = _boss.global_position if _boss else null
		"y_hen":
			# 砲管裡探出一隻戴小頭盔的雞
			var cs := Vector3(-_cdir.z, 0, _cdir.x)
			_shot_cam(_muzzle + _cdir * 3.1 + cs * 1.4 + Vector3(0, 0.55, 0), _muzzle - _cdir * 0.3 + Vector3(0, 0.0, 0), 34.0, 0.0, Vector3(0.02, 0, 0.03))
			var hen := _hen.node as Node3D
			var lift := Vector3(0, 0.48 * 1.38 * 0.45, 0)
			hen.visible = true
			hen.global_position = _muzzle - _cdir * 1.2 - lift
			var tw := _tw()
			tw.tween_interval(0.25)
			tw.tween_property(hen, "global_position", _muzzle - _cdir * 0.06 - lift, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			_at(0.3, func(): _play("pop", -10.0, 1.3))
			_at(0.55, func(): _emote(hen.global_position + Vector3(0, 0.9, 0), "！", Color(1, 1, 1), 0.8, 0.8))
		# ---------------------------------------------------------- ② 號碼
		"c_climb":
			# 家豪爬上高台
			var foot := G(_lfoot.x, _lfoot.y)
			_shot_cam(foot + fd * 3.8 - sd * 0.8 + Vector3(0, 1.3, 0), Vector3(_ltop.x, _top + 0.6, _ltop.y) + fd * 0.6, 46.0, 0.0, Vector3(0, 0.15, 0))
			var up := Vector3(_pc.x, _top, _pc.y) + fd * 5.5 + Vector3(0, 0.05, 0)
			_set_anim(_hero, "flap")
			var tw := _tw()
			tw.tween_interval(0.3)
			tw.tween_property(hero, "global_position", up - fd * 0.2 + Vector3(0, -0.1, 0), 2.6)
			tw.tween_callback(func(): _set_anim(_hero, "idle"))
			for k in 4:
				_at(0.5 + 0.65 * k, func(): _play("thud", -20.0, 1.8 + 0.06 * k))
			_hop(_hero, T(4.2, 0.0), 0.5, 0.5, 3.0, "idle")
		"b_search":
			# 一格一格找。配樂在這裡停掉
			_music_stop(2.4)
			var cam := hb + fd * 1.6 + sd * 0.9 + Vector3(0, 1.75, 0)
			_shot_cam(cam, _cells[43], 40.0)
			_hero.look = _cells[43]
			var order := [45, 50, 57, 54, 61, 63, 65]
			for k in order.size():
				var n: int = order[k]
				_at(0.3 + 0.44 * k, func():
					_shot_cam(cam, _cells[n], 40.0, 0.4)
					_hero.look = _cells[n])
		"b_66":
			# 六十六。下面寫著：已出貨
			var c66: Vector3 = _cells[66]
			_hero.look = c66
			_shot_cam(c66 + fd * 1.7 + Vector3(0, 0.05, 0), c66 + Vector3(0, -0.03, 0), 30.0, 0.0, fd * -0.05)
		"b_god":
			# 神明的角度：從上面往下看，家豪很小，出貨板很大
			_shot_cam(hb + fd * 4.5 - sd * 1.5 + Vector3(0, 7.5, 0), hb - fd * 1.0 + Vector3(0, 1.0, 0), 40.0, 0.0, Vector3(0, 0.05, 0))
			_hero.look = _cells[66]
		# ---------------------------------------------------------- ③ 腳牌
		"g_touch":
			# 家豪沒有說話，摸了一下脖子上的牌子
			_shot_cam(hb - fd * 1.8 - sd * 1.2 + Vector3(0, 1.2, 0), hb + Vector3(0, 1.0, 0), 34.0, 0.0, Vector3(0, 0, 0))
			_hero.look = null
			_at(0.5, func(): _set_anim(_hero, "touch"))
		"g_boss":
			var g: Dictionary = _gunners[0]
			var gn := g.node as Node3D
			var gp := gn.global_position
			var to := (Vector3(hb.x, gp.y, hb.z) - gp).normalized()
			var gs := Vector3(-to.z, 0, to.x)
			# 從高台邊上（家豪那邊）往下看：砲手舉著手，抬頭往上說
			var edge := _pc + Vector2(gp.x - _pc.x, gp.z - _pc.y).normalized() * 5.1
			_shot_cam(Vector3(edge.x, _top + 0.9, edge.y) + gs * 0.6, gp + Vector3(0, 2.1, 0), 40.0, 0.0, Vector3(0, -0.02, 0))
			_at(0.3, func(): _emote(gp + Vector3(0, 3.4, 0), "…", Color(1, 1, 1), 1.0, 0.8))
		# ---------------------------------------------------------- ④ 靜音拍
		"d_dj":
			# 日落。家豪站在出貨板前面打碟；灰色音符落在砲手舉起來的手心上
			var g0 := (_gunners[0].node as Node3D).global_position
			var to0 := (Vector3(hb.x, g0.y, hb.z) - g0).normalized()
			var gs0 := Vector3(-to0.z, 0, to0.x)
			var palm0 := (_gunners[0].palm as Node3D).global_position
			_shot_cam(G(g0.x, g0.z) - to0 * 6.0 + gs0 * 1.6 + Vector3(0, 3.6, 0), (hb + Vector3(0, 1.0, 0)) * 0.42 + palm0 * 0.58, 42.0, 0.0, to0 * 0.05)
			_amb_play("wind", -15.0, 1.2)
			_at(0.5, func():
				_set_anim(_hero, "dj", 0.7)
				_notes(true))
			_at(2.4, func():
				var palm := (_gunners[0].palm as Node3D).global_position
				_note_to(palm + Vector3(0, 0.15, 0), 1.6, func():
					_emote(palm + Vector3(0, 0.7, 0), "？", Color(1, 1, 1), 1.1, 0.7)))
		"d_stop":
			# 打到一半停下來，摸一下牌子，什麼都沒說
			_shot_cam(hb + fd * 3.0 + sd * 0.5 + Vector3(0, 1.25, 0), hb + Vector3(0, 1.1, 0), 32.0, 0.0, fd * 0.03)
			_set_anim(_hero, "dj", 0.7)
			_notes(true)
			_at(1.4, func():
				_notes(false)
				_set_anim(_hero, "still"))
			_at(2.3, func(): _set_anim(_hero, "touch"))
		# ---------------------------------------------------------- ⑤ 羽毛
		"w_gust":
			# 從背後看：帽沿被風掀起來，四根
			_shot_cam(hb + fd * 1.9 + sd * 0.7 + Vector3(0, 2.55, 0), hb + Vector3(0, 0.8, 0) - fd * 0.2, 34.0, 0.0, fd * 0.02)
			_set_anim(_hero, "idle")
			_amb_play("wind", -9.0, 0.3)
			_at(0.2, func(): _play("whoosh", -8.0, 0.6))
			_at(0.4, func():
				_hood_lift()
				_play("ding", -16.0, 1.2))
			_at(1.4, func(): _amb.volume_db = -17.0)
		"w_god":
			_music_play("theme", -18.0, 2.5)
		"w_stress":
			_at(0.2, func():
				_set_anim(_hero, "cool")
				_hood_down()
				_emote(_hero, "…", Color(1, 1, 1), 1.0, 0.8))
		# ---------------------------------------------------------- ⑥ 上船
		"l_leave":
			# 要塞雞跳上船；小船離岸，船頭第一次朝北，一群鳥從頭上飛過去，也往北
			# 淡入 1 秒之後才跳（看得到）；船在淡入後第 1.3 秒才開
			_shot_cam(Vector3(52.2, 2.1, 13.0), Vector3(49.6, 1.2, -6.0), 48.0, 0.0, Vector3(-0.03, 0.05, -0.55))
			_amb_play("waves", -15.0, 1.0)
			_at(1.2, func():
				_hop(_hen, _boat.to_global(Vector3(-0.3, 0.36, -1.0)), 0.55, 0.9, 0.0, "idle")
				_play("whoosh", -14.0, 1.6))
			_at(1.8, func():
				_hen_boat = true
				_play("thud", -16.0, 1.6))
			_at(2.6, func(): _play("whoosh", -16.0, 0.5))      # 鳥群飛過去
		# ---------------------------------------------------------- ⑦ 手帳
		"j_page":
			_shot_cam(Vector3(36.0, 14.0, 26.0), Vector3(46.0, 18.0, -80.0), 60.0, 0.0, Vector3(0, 0.03, -0.1))
			_at(0.5, func(): _journal_p = _journal_page(4, "牆裡面。\n六十六號下面寫著已出貨。", PURPLE, "丹穴山海"))
