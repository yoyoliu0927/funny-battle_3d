extends Node
## 標題畫面：一開遊戲先看到的那一頁。由選關畫面（scripts/level_select.gd）掛在自己底下，
## 直接拿世界地圖的島當背景，所以按下開始之後鏡頭可以一路滑到農莊，不用換場景。
##
## 流程：
##   1. 開場動畫（約 9 秒）：一根金色的羽毛從雲上飄下來，鏡頭跟著它穿過雲層、掠過北方的島、飛過海，
##      最後落在農莊裡家豪的頭上。
##   2. 標題：四個大字一個一個蹦出來，後面張開五根羽毛，下面一條紙帶寫「按 空白鍵 開始」。
##      鏡頭繞著農莊慢慢晃，天上有綁著氣球的母雞飄過去。
##   3. 按下去：第一次玩（還沒看過開場劇情）→ 接開場劇情（scenes/intro.tscn）；看過了 → 鏡頭滑下去，直接到農莊。
##
## 操作：空白鍵／Enter／滑鼠左鍵 開始（開場動畫播到一半按是跳過動畫）；V 開關聲音。
## 要改遊戲的名字：改下面的 TITLE、SUBTITLE。
## 開發用：命令列加 -- --titleshots=<資料夾>，會在幾個時間點各截一張圖然後關掉（不會寫存檔）。

const UIStyle := preload("res://scripts/ui/ui_style.gd")
const INTRO_SCENE := "res://scenes/intro.tscn"
const SETTINGS_PATH := "user://settings.cfg"
const PROGRESS_PATH := "user://progress.cfg"
const CLOUD := "res://levels/ice/assets/blender/cloud_puff_%s.glb"

const TITLE := "天選之雞"
const SUBTITLE := "家豪的大冒險"
const TAGLINE := "一隻不會飛的雞，要去看看更好的地方"
const CREDIT := "115-1 遊戲設計 期末專題"
const STORY := "一根羽毛，從很高很高的地方飄了下來……"
const STORY2 := "它要找的，是一隻不會飛的雞。"

const LAND := 8.2          # 羽毛落到家豪頭上
const LOGO := 9.3          # 標題開始蹦出來
const OPEN := 10.3         # 鏡頭到定位
const FACE := 0.62          # 標題畫面家豪轉向哪邊（弧度）：鏡頭從東南邊看過去，他背後是田和海，不是雞舍
const RISER := 0.5           # 家豪腳下墊的木箱多高（胸口才露得出打碟台）
const LEAVE := 1.7         # 按下開始之後，鏡頭滑到農莊要幾秒
const INK := Color("3b2a20")
const PAPER := Color("fff8e7")
const PAPER_EDGE := Color("d9c9a8")
const RED := Color("e8483a")
const RED_EDGE := Color("8f231c")
const GOLD := Color("ffc93a")
const FEATHERS := [Color("4fc3d9"), Color("e2483a"), Color("f0a81c"), Color("f2d03a"), Color("9a72d8")]

var map: Node                 # 選關畫面（level_select.gd）
var _t := 0.0
var _state := "open"          # open 開場動畫 → title 等玩家按 → leave 鏡頭滑下去／淡出 → done
var _leave_t := 0.0
var _first := false           # 這次按下去要接開場劇情
var _landed := false
var _done_t := 0.0

var _world: Node3D
var _feather: Node3D
var _halo: Node3D
var _trail: Array = []
var _trail_pos: Array = []
var _burst: Array = []        # 落地時炸開的光點 {node, dir}
var _burst_t := -1.0
var _bang: Label3D            # 家豪頭上的「！」
var _balloons: Array = []     # {node, c, r, sp, ph, y}
var _clouds: Array = []
var _glow_mat: StandardMaterial3D
var _deck: Node3D
var _discs: Array = []
var _knobs: Array = []
var _notes: Array = []
var _leds: Array = []
var _cones: Array = []
var _pop: Label3D
var _pop_t := 9.0
var _bits: Array = []
var _bits_at := Vector3.ZERO
var _gag_next := OPEN + 3.4
var _gag_i := 0

var _hub := Vector3.ZERO
var _north := Vector3.ZERO
var _hero := Vector3.ZERO
var _fk: Array = []           # 羽毛的路線 [t, 位置]
var _ck: Array = []           # 鏡頭的路線 [t, 位置]

var _layer: CanvasLayer
var _ov: Control              # 開場動畫的字幕、上下黑邊
var _logo: Control
var _band: Control
var _fade: ColorRect
var _skip: Control
var _chars_hit := 0
var _feathers_hit := 0

# ================================================================== 存檔：看過開場劇情了沒

## 看過開場劇情了沒（設定檔有記，或是已經有過關紀錄的老玩家）
static func intro_seen() -> bool:
	var cf := ConfigFile.new()
	if cf.load(SETTINGS_PATH) == OK and bool(cf.get_value("story", "intro_seen", false)):
		return true
	var pg := ConfigFile.new()
	return pg.load(PROGRESS_PATH) == OK and pg.has_section("cleared")

static func mark_intro_seen() -> void:
	var cf := ConfigFile.new()
	cf.load(SETTINGS_PATH)
	cf.set_value("story", "intro_seen", true)
	cf.save(SETTINGS_PATH)

## 這次開遊戲要不要先放標題畫面（測試、從關卡回來、剛看完開場劇情都不用）
static func wanted() -> bool:
	var args := OS.get_cmdline_user_args()
	for a in args:
		if a.begins_with("--titleshots="):
			return true
		if a == "--autotest" or a.begins_with("--mapshots="):
			return false
	return not Engine.has_meta("title_done") and not Engine.has_meta("map_last")

# ================================================================== 啟動

func _ready() -> void:
	_hub = map.worlds[0].center
	_hero = map._stand_now()         # 家豪待機時站的位置（剛進場那一格 _hero.position 還沒擺好）
	_north = _hub + Vector3(-34, 0, -52)
	for e in map.entries.size():
		if String(map.entries[e].ch.get("id", "")) == "ice":
			_north = map.worlds[e].center
	_world = Node3D.new()
	add_child(_world)
	_build_paths()
	_build_feather()
	_build_clouds()
	_build_balloons()
	_build_deck()
	_build_ui()
	if Engine.has_meta("title_skip_open"):
		Engine.remove_meta("title_skip_open")       # 從世界地圖按 Esc 回來：不用再播一次開場動畫
		_t = LOGO - 0.2
		_landed = true
	else:
		map._play("fly", 0.7)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--titleshots="):
			_titleshots.call_deferred(a.substr(13))

func _build_paths() -> void:
	var a := _north + Vector3(-6, 80, -34)
	var b := _north + Vector3(4, 21, 4)
	var c := (_north + _hub) * 0.5 + Vector3(6, 13, 4)
	var d := _hero + Vector3(-1.2, 5.2 + RISER, -1.5)
	var e := _hero + Vector3(0, 2.3 + RISER, 0)
	_fk = [[0.0, a], [3.0, b], [5.4, c], [7.3, d], [LAND, e]]
	_ck = [
		[0.0, a + Vector3(3, 9, -15)],
		[1.6, a.lerp(b, 0.45) + Vector3(11, 8, -12)],
		[3.2, b + Vector3(17, 7, 3)],
		[5.4, c + Vector3(21, 4, 13)],
		[6.6, _rel(Vector3(4, 5.0, 19))],
		[7.5, _rel(Vector3(2.5, 3.2, 12))],
		[LAND + 0.15, _rel(Vector3(1.3, 2.4, 5.8))],      # 羽毛落到頭上：給家豪一個特寫
		[LAND + 0.8, _rel(Vector3(1.2, 2.5, 6.2))],
		[OPEN, _orbit(OPEN)[0]],
	]

## 家豪面前的座標（x 往他的左手邊、z 往鏡頭）換成世界座標
func _rel(v: Vector3) -> Vector3:
	return _hero + v.rotated(Vector3.UP, FACE)

## 一條通過所有點的平滑曲線在時間 t 的位置
func _sample(keys: Array, t: float) -> Vector3:
	var n := keys.size()
	if t <= float(keys[0][0]):
		return keys[0][1]
	if t >= float(keys[n - 1][0]):
		return keys[n - 1][1]
	var i := 0
	while i < n - 2 and t > float(keys[i + 1][0]):
		i += 1
	var w := (t - float(keys[i][0])) / (float(keys[i + 1][0]) - float(keys[i][0]))
	var p0: Vector3 = keys[maxi(i - 1, 0)][1]
	var p1: Vector3 = keys[i][1]
	var p2: Vector3 = keys[i + 1][1]
	var p3: Vector3 = keys[mini(i + 2, n - 1)][1]
	return p1.cubic_interpolate(p2, p0, p3, w)

## 標題畫面的鏡頭：在農莊南邊慢慢左右晃。回傳 [位置, 看哪裡]
func _orbit(t: float) -> Array:
	var s := t - OPEN
	var th := FACE + 0.05 + 0.13 * sin(s * 0.11)
	var r := 8.6 + 0.4 * sin(s * 0.07)
	var pos := _hero + Vector3(sin(th) * r, 2.0 + 0.2 * sin(s * 0.13), cos(th) * r)
	return [pos, _hero + Vector3(0, 1.78, 0)]

func _feather_pos(t: float) -> Vector3:
	var k := 1.0 - smoothstep(7.0, LAND, t)
	return _sample(_fk, t) + Vector3(sin(t * 3.1) * 0.9, sin(t * 2.3) * 0.45, cos(t * 2.7) * 0.9) * k

# ================================================================== 3D：羽毛、雲、氣球雞

func _glow() -> StandardMaterial3D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = 64
	tex.height = 64
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.billboard_keep_scale = true
	m.albedo_texture = tex
	m.albedo_color = Color(1.0, 0.82, 0.35, 0.9)
	m.disable_fog = true
	return m

func _sprite(size: float) -> MeshInstance3D:
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = _glow_mat
	mi.scale = Vector3.ONE * size
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_world.add_child(mi)
	return mi

## 一片羽毛形狀的面（立在 XY 平面上，根部在原點）
func _feather_mesh(h: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 48
	var left: Array = []
	var right: Array = []
	for i in n + 1:
		var t := float(i) / n
		var y := h * (0.2 + 0.8 * t)
		var w := sin(pow(t, 0.75) * PI) * h
		# 邊緣幾個缺口：才像羽毛，不像葉子
		var nl := 1.0 - 0.55 * maxf(0.0, 1.0 - absf(t - 0.58) / 0.035) - 0.45 * maxf(0.0, 1.0 - absf(t - 0.80) / 0.03)
		var nr := 1.0 - 0.55 * maxf(0.0, 1.0 - absf(t - 0.45) / 0.035) - 0.5 * maxf(0.0, 1.0 - absf(t - 0.70) / 0.035)
		left.append(Vector3(-w * 0.17 * nl, y, 0))
		right.append(Vector3(w * 0.21 * nr, y, 0))
	for i in n:
		for v in [left[i], right[i], right[i + 1], left[i], right[i + 1], left[i + 1]]:
			st.add_vertex(v)
	return st.commit()

func _build_feather() -> void:
	_glow_mat = _glow()
	_feather = Node3D.new()
	_world.add_child(_feather)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = Color(1.0, 0.80, 0.22)
	mat.disable_fog = true
	var mi := MeshInstance3D.new()
	mi.mesh = _feather_mesh(2.0)
	mi.material_override = mat
	mi.position = Vector3(0, -1.15, 0.015)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_feather.add_child(mi)
	var back := mi.duplicate() as MeshInstance3D
	back.position.z = -0.03
	_feather.add_child(back)
	var rim := StandardMaterial3D.new()
	rim.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rim.cull_mode = BaseMaterial3D.CULL_DISABLED
	rim.albedo_color = Color("7a4a10")
	rim.disable_fog = true
	var edge := MeshInstance3D.new()
	edge.mesh = mi.mesh
	edge.material_override = rim
	edge.scale = Vector3(1.28, 1.1, 1.0)
	edge.position = Vector3(0, -1.27, -0.015)
	edge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_feather.add_child(edge)
	# 羽軸
	var rod := CylinderMesh.new()
	rod.top_radius = 0.02
	rod.bottom_radius = 0.06
	rod.height = 2.1
	var rmat := mat.duplicate() as StandardMaterial3D
	rmat.albedo_color = Color(1.0, 0.96, 0.75)
	var ri := MeshInstance3D.new()
	ri.mesh = rod
	ri.material_override = rmat
	ri.position = Vector3(0, -0.15, 0)
	ri.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_feather.add_child(ri)
	var halo := _sprite(0.9)
	_halo = halo
	_world.remove_child(halo)
	_feather.add_child(halo)
	for i in 48:
		var s := _sprite(1.0)
		s.visible = false
		_trail.append(s)
	for i in 14:
		var s2 := _sprite(1.2)
		s2.visible = false
		var ang := TAU * i / 14.0
		_burst.append({"node": s2, "dir": Vector3(cos(ang), 0.45 + 0.4 * sin(i * 2.4), sin(ang))})
	_bang = Label3D.new()
	_bang.text = "!"
	_bang.font = UIStyle.font()
	_bang.font_size = 160
	_bang.pixel_size = 0.008
	_bang.outline_size = 36
	_bang.modulate = Color("ffd23a")
	_bang.outline_modulate = INK
	_bang.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_bang.no_depth_test = true
	_bang.visible = false
	_world.add_child(_bang)

func _build_clouds() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1, 1, 1)
	mat.emission_enabled = true
	mat.emission = Color(0.80, 0.86, 0.95)
	mat.emission_energy_multiplier = 0.3
	mat.roughness = 1.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 67
	var top: Vector3 = _fk[0][1]
	for i in 96:
		var path := CLOUD % ["a", "b", "c"][i % 3]
		if not ResourceLoader.exists(path):
			return
		var n := (load(path) as PackedScene).instantiate() as Node3D
		var pos: Vector3
		if i < 70:
			# 羽毛一開始穿過去的那一層雲
			pos = Vector3(top.x + rng.randf_range(-150, 150), rng.randf_range(40, 60), top.z + rng.randf_range(-110, 150))
			# 鏡頭會經過的地方不放（鑽進雲裡面只會看到一大片白色的面）
			var near := false
			for j in 36:
				var cp := _sample(_ck, j * 0.1)
				near = near or Vector2(cp.x - pos.x, cp.z - pos.z).length() < 58.0
			if near:
				continue
		else:
			# 遠遠掛在天邊的雲（標題畫面的背景）
			var ang := rng.randf_range(0, TAU)
			var r := rng.randf_range(150, 300)
			pos = _hub + Vector3(cos(ang) * r, rng.randf_range(38, 78), sin(ang) * r)
		n.position = pos
		n.rotation.y = rng.randf_range(0, TAU)
		n.scale = Vector3(1.0, 0.62 if i < 70 else 0.9, 1.0) * rng.randf_range(7.0, 15.0)
		_world.add_child(n)
		_paint(n, mat)
		_clouds.append({"node": n, "base": pos, "phase": rng.randf_range(0, TAU)})

func _paint(n: Node, mat: Material) -> void:
	if n is MeshInstance3D:
		(n as MeshInstance3D).material_override = mat
		(n as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for ch in n.get_children():
		_paint(ch, mat)

## 綁著氣球飄在天上的母雞
func _build_balloons() -> void:
	var spots := [Vector3(-11.5, 3.2, -11), Vector3(10.0, 6.4, -13), Vector3(-19, 8.5, -26), Vector3(13, 9.0, -22), Vector3(-20, 10.5, -20)]
	for i in spots.size():
		var root := Node3D.new()
		_world.add_child(root)
		var col: Color = FEATHERS[i % FEATHERS.size()]
		var bm := StandardMaterial3D.new()
		bm.albedo_color = col
		bm.roughness = 0.25
		bm.emission_enabled = true
		bm.emission = col
		bm.emission_energy_multiplier = 0.25
		var ball := SphereMesh.new()
		ball.radius = 0.95
		ball.height = 2.2
		var bi := MeshInstance3D.new()
		bi.mesh = ball
		bi.material_override = bm
		bi.position = Vector3(0, 3.1, 0)
		root.add_child(bi)
		var knot := CylinderMesh.new()
		knot.top_radius = 0.02
		knot.bottom_radius = 0.16
		knot.height = 0.22
		var ki := MeshInstance3D.new()
		ki.mesh = knot
		ki.material_override = bm
		ki.position = Vector3(0, 1.95, 0)
		root.add_child(ki)
		var sm := StandardMaterial3D.new()
		sm.albedo_color = Color(0.98, 0.96, 0.9)
		sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		var line := CylinderMesh.new()
		line.top_radius = 0.018
		line.bottom_radius = 0.018
		line.height = 1.1
		var li := MeshInstance3D.new()
		li.mesh = line
		li.material_override = sm
		li.position = Vector3(0, 1.35, 0)
		root.add_child(li)
		var hc := Node3D.new()
		hc.set_script(load("res://scripts/characters.gd"))
		hc.set_process(false)
		root.add_child(hc)
		var hen: Node3D = hc._make_round_chicken(false)
		hc.add_child(hen)
		var hb: AABB = map._aabb(hen, Transform3D.IDENTITY)
		if hb.size.y > 0.01:
			var hs := 1.25 / hb.size.y
			hen.scale = Vector3.ONE * hs
			hen.position.y = -hb.position.y * hs - 0.35
		root.scale = Vector3.ONE * (1.05 + 0.12 * sin(i * 1.9))
		_balloons.append({"node": root, "base": _rel(spots[i]), "ph": i * 1.7, "up": 0.0, "parts": [bi, ki, li], "hen": hc, "pop": -1.0, "drop": Vector3.ZERO})

# ================================================================== 介面

class _Paint:
	extends Control
	var painter: Callable
	func _draw() -> void:
		if painter.is_valid():
			painter.call(self)

func _pad(painter: Callable) -> Control:
	var p := _Paint.new()
	p.painter = painter
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(p)
	return p

func _build_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 6
	add_child(_layer)
	_band = _pad(_paint_band)
	_logo = _pad(_paint_logo)
	_fade = ColorRect.new()
	_fade.color = Color(1, 1, 1, 1)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(_fade)
	_ov = _pad(_paint_open)
	_skip = _pad(_paint_skip)

func _font() -> Font:
	var f := UIStyle.font()
	return f if f else ThemeDB.fallback_font

func _u(c: Control) -> float:
	return minf(c.size.x / 1600.0, c.size.y / 900.0)

func _back(k: float) -> float:
	var x := clampf(k, 0.0, 1.0) - 1.0
	return 1.0 + 2.7 * x * x * x + 1.7 * x * x

func _inout(t: float, a: float, b: float, c: float, d: float) -> float:
	return smoothstep(a, b, t) * (1.0 - smoothstep(c, d, t))

## 置中寫一行有外框的字
func _line(c: Control, center: Vector2, text: String, size: float, col: Color, edge: Color, out := 0.22, plate := 0.0) -> void:
	var f := _font()
	var fs := int(size)
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var pos := Vector2(center.x - w * 0.5, center.y + f.get_ascent(fs) - f.get_height(fs) * 0.5)
	if plate > 0.0:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.06, 0.05, 0.09, 0.55 * plate)
		sb.set_corner_radius_all(int(size * 0.9))
		c.draw_style_box(sb, Rect2(center.x - w * 0.5 - size * 0.9, center.y - size * 0.85, w + size * 1.8, size * 1.7))
	if edge.a > 0.0:
		c.draw_string_outline(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, int(size * out), edge)
	c.draw_string(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)

## 四角的閃光
func _sparkle(c: Control, at: Vector2, r: float, col: Color) -> void:
	if r < 0.5:
		return
	var pts := PackedVector2Array()
	for i in 8:
		var ang := TAU * i / 8.0
		pts.append(at + Vector2(cos(ang), sin(ang)) * (r if i % 2 == 0 else r * 0.26))
	c.draw_colored_polygon(pts, col)

## 標題後面的大羽毛（貼紙的樣子：白邊、單色、一條淺色的羽軸）
func _plume(c: Control, base: Vector2, h: float, ang: float, col: Color) -> void:
	if h < 2.0:
		return
	var dir := Vector2(sin(ang), -cos(ang))
	var side := Vector2(-dir.y, dir.x)
	var pts := PackedVector2Array()
	var n := 14
	for i in n + 1:
		var t := float(i) / n
		pts.append(base + dir * h * (0.2 + 0.8 * t) + side * sin(pow(t, 0.7) * PI) * h * 0.16)
	for i in range(n, -1, -1):
		var t := float(i) / n
		pts.append(base + dir * h * (0.2 + 0.8 * t) - side * sin(pow(t, 0.7) * PI) * h * 0.16)
	var ring := pts.duplicate()
	ring.append(pts[0])
	c.draw_polyline(ring, Color(INK, 0.9), h * 0.075, true)
	c.draw_polyline(ring, Color(1, 1, 1), h * 0.045, true)
	c.draw_colored_polygon(pts, col)
	c.draw_line(base + dir * h * 0.3, base + dir * h * 0.93, col.lightened(0.45), h * 0.022, true)
	for k in [0.52, 0.68, 0.82]:
		var at: Vector2 = base + dir * h * float(k)
		c.draw_line(at, at + dir * h * 0.07 + side * h * 0.09, col.lightened(0.45), h * 0.016, true)
		c.draw_line(at, at + dir * h * 0.07 - side * h * 0.09, col.lightened(0.45), h * 0.016, true)

## 開場動畫那一層：上下黑邊、字幕、跳過提示
func _paint_open(c: Control) -> void:
	var u := _u(c)
	var vs := c.size
	var bars := 1.0 - smoothstep(LOGO - 0.5, LOGO, _t)
	if bars <= 0.0:
		return
	var bh := 74.0 * u * bars
	c.draw_rect(Rect2(0, 0, vs.x, bh), Color(0.06, 0.05, 0.09))
	c.draw_rect(Rect2(0, vs.y - bh, vs.x, bh), Color(0.06, 0.05, 0.09))
	var a1 := _inout(_t, 0.5, 1.1, 3.3, 3.9)
	if a1 > 0.0:
		_line(c, Vector2(vs.x * 0.5, vs.y - 150.0 * u), STORY, 36.0 * u, Color(1, 0.97, 0.86, a1), Color(0, 0, 0, 0), 0.22, a1)
	var a2 := _inout(_t, 4.2, 4.8, 6.2, 6.7)
	if a2 > 0.0:
		_line(c, Vector2(vs.x * 0.5, vs.y - 150.0 * u), STORY2, 36.0 * u, Color(1, 0.97, 0.86, a2), Color(0, 0, 0, 0), 0.22, a2)

## 右下角的「空白鍵 跳過」（自己一層，整組一起淡入淡出）
func _paint_skip(c: Control) -> void:
	var u := _u(c)
	var vs := c.size
	var bh := 74.0 * u
	var a3 := 1.0
	c.modulate.a = _inout(_t, 0.0, 0.3, LOGO - 0.5, LOGO - 0.2)
	if c.modulate.a > 0.0:
		var f := _font()
		var ks := 19.0 * u
		var sz := UIStyle.keycap_size("空白鍵", ks)
		var tw := f.get_string_size("跳過", HORIZONTAL_ALIGNMENT_LEFT, -1, int(22 * u)).x
		var x := vs.x - 30.0 * u - tw - 10.0 * u - sz.x
		var y := vs.y - bh * 0.5 - sz.y * 0.5
		UIStyle.draw_keycap(c, Vector2(x, y), "空白鍵", ks)
		c.draw_string(f, Vector2(x + sz.x + 10.0 * u, y + sz.y * 0.5 + 7.0 * u), "跳過", HORIZONTAL_ALIGNMENT_LEFT, -1, int(22 * u), Color(1, 1, 1, a3))

## 標題：五根羽毛、四個大字、紅色副標緞帶、閃光
func _paint_logo(c: Control) -> void:
	var lt := _t - LOGO
	if lt < 0.0:
		return
	var u := _u(c)
	var vs := c.size
	var f := _font()
	var s := 164.0 * u
	var fs := int(s)
	var cx := vs.x * 0.5
	var cy := vs.y * 0.205
	# 後面的光暈
	var halo := smoothstep(0.0, 0.8, lt)
	for i in 5:
		c.draw_circle(Vector2(cx, cy + 10.0 * u), (430.0 - i * 62.0) * u * (0.9 + 0.1 * halo), Color(1.0, 0.97, 0.80, 0.055 * halo))
	# 五根羽毛：從字後面像尾巴一樣張開
	for i in 5:
		var k := _back((lt - 0.55 - i * 0.07) / 0.38)
		if lt - 0.55 - i * 0.07 <= 0.0:
			continue
		var ang := (i - 2) * 0.38 + sin(lt * 1.3 + i) * 0.03
		var base := Vector2(cx + (i - 2) * 128.0 * u, cy - (20.0 - 4.0 * absf(i - 2.0)) * u)
		_plume(c, base, s * 0.86 * k * (1.0 - 0.09 * absf(i - 2.0)), ang, FEATHERS[i])
	# 四個大字
	var n := TITLE.length()
	var widths: Array = []
	var total := 0.0
	for i in n:
		var w := f.get_string_size(TITLE[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		widths.append(w)
		total += w
	var gap := -0.02 * s
	total += gap * (n - 1)
	var x := cx - total * 0.5
	var tilt := [-0.07, 0.035, -0.03, 0.075]
	var lift := [8.0, -8.0, 6.0, -10.0]
	for i in n:
		var w: float = widths[i]
		var tau := lt - i * 0.13
		if tau > 0.0:
			var k := clampf(tau / 0.42, 0.0, 1.0)
			var sc := lerpf(2.7, 1.0, _back(k))
			var a := 1.0
			var bob := sin(lt * 1.7 + i * 0.9) * 5.0 * u * k
			var ctr := Vector2(x + w * 0.5, cy + float(lift[i % 4]) * u + bob)
			var rot := float(tilt[i % 4]) + (1.0 - k) * 0.5 + sin(lt * 1.1 + i * 1.7) * 0.012
			c.draw_set_transform(ctr, rot, Vector2(sc, sc))
			var p := Vector2(-w * 0.5, f.get_ascent(fs) - f.get_height(fs) * 0.5)
			var last := i == n - 1
			var fill := Color("ffb41c") if last else RED
			var edge := Color("7a4a10") if last else RED_EDGE
			c.draw_string_outline(f, p + Vector2(0, 0.075 * s), TITLE[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, int(0.19 * s), Color(0.42, 0.10, 0.06, 0.42 * a))
			c.draw_string_outline(f, p, TITLE[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, int(0.19 * s), Color(INK, a))
			c.draw_string_outline(f, p, TITLE[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, int(0.12 * s), Color(1, 1, 1, a))
			c.draw_string_outline(f, p + Vector2(0, 0.022 * s), TITLE[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, int(0.018 * s), Color(edge, a))
			c.draw_string(f, p, TITLE[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(fill, a))
			c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		x += w + gap
	# 副標：紅色緞帶
	var rk := _back((lt - 0.95) / 0.45)
	if lt > 0.95:
		var rc := Vector2(cx, cy + 0.78 * s)
		var hw := 262.0 * u * rk
		var hh := 27.0 * u
		c.draw_set_transform(rc, -0.02, Vector2.ONE)
		for side in [-1.0, 1.0]:
			var tail := PackedVector2Array([
				Vector2(side * (hw - 6.0 * u), -hh + 12.0 * u), Vector2(side * (hw + 52.0 * u), -hh + 12.0 * u),
				Vector2(side * (hw + 34.0 * u), 12.0 * u), Vector2(side * (hw + 52.0 * u), hh + 12.0 * u),
				Vector2(side * (hw - 6.0 * u), hh + 12.0 * u)])
			c.draw_colored_polygon(tail, RED_EDGE)
		c.draw_rect(Rect2(-hw, -hh + 5.0 * u, hw * 2.0, hh * 2.0), Color(0.16, 0.09, 0.05, 0.25))
		c.draw_rect(Rect2(-hw, -hh, hw * 2.0, hh * 2.0), RED)
		c.draw_rect(Rect2(-hw, -hh, hw * 2.0, hh * 2.0), RED_EDGE, false, 3.0 * u)
		c.draw_line(Vector2(-hw + 8.0 * u, -hh + 8.0 * u), Vector2(hw - 8.0 * u, -hh + 8.0 * u), Color(1, 1, 1, 0.35), 2.0 * u)
		c.draw_line(Vector2(-hw + 8.0 * u, hh - 8.0 * u), Vector2(hw - 8.0 * u, hh - 8.0 * u), Color(1, 1, 1, 0.35), 2.0 * u)
		if rk > 0.5:
			_line(c, Vector2(0, -1.0 * u), "～ " + SUBTITLE + " ～", 32.0 * u, PAPER, Color(0, 0, 0, 0))
		c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# 閃光
	var marks := [Vector2(-430, -90), Vector2(445, -70), Vector2(-350, 85), Vector2(380, 95), Vector2(-150, -150), Vector2(210, -155), Vector2(520, 20), Vector2(-520, 10)]
	for i in marks.size():
		var tw := maxf(sin(lt * 2.1 + i * 1.9), 0.0)
		var r := pow(tw, 3.0) * (22.0 + 8.0 * (i % 3)) * u * smoothstep(0.6, 1.2, lt)
		_sparkle(c, Vector2(cx, cy) + (marks[i] as Vector2) * u, r, Color(1, 1, 0.86, 0.95))

## 下面的紙帶：按鍵提示、一句話簡介、製作資訊
func _paint_band(c: Control) -> void:
	var lt := _t - LOGO - 1.3
	if lt < 0.0:
		return
	var u := _u(c)
	var vs := c.size
	var f := _font()
	var h := 114.0 * u
	var y0 := vs.y - h * _back(lt / 0.5)
	c.draw_rect(Rect2(0, y0 - 8.0 * u, vs.x, 8.0 * u), Color(0.16, 0.09, 0.05, 0.16))
	c.draw_rect(Rect2(0, y0, vs.x, h + 60.0 * u), PAPER)
	c.draw_rect(Rect2(0, y0, vs.x, 5.0 * u), PAPER_EDGE)
	# 縫線
	var dx := 0.0
	while dx < vs.x:
		c.draw_line(Vector2(dx, y0 + 16.0 * u), Vector2(dx + 14.0 * u, y0 + 16.0 * u), Color(RED, 0.55), 2.5 * u)
		dx += 26.0 * u
	# 左邊：五根小羽毛＋一句話
	var got: Array = map._feathers()
	var have := 0
	for i in got.size():
		var on := bool(got[i].have)
		have += 1 if on else 0
		map._feather(c, Vector2((48.0 + i * 30.0) * u, y0 + h * 0.5 + 4.0 * u), 56.0 * u, (i - (got.size() - 1) * 0.5) * 0.1, got[i].col, on)
	var fx := (50.0 + got.size() * 30.0) * u
	if not got.is_empty():
		c.draw_string(f, Vector2(fx, y0 + h * 0.5 - 6.0 * u), "%d/%d" % [have, got.size()], HORIZONTAL_ALIGNMENT_LEFT, -1, int(26 * u), INK)
	c.draw_string(f, Vector2(34.0 * u, y0 + h * 0.5 + 34.0 * u), TAGLINE, HORIZONTAL_ALIGNMENT_LEFT, -1, int(23 * u), Color(INK, 0.92))
	# 右邊：聲音鍵、製作資訊
	var ks := 15.0 * u
	var ksz := UIStyle.keycap_size("V", ks)
	var rw := f.get_string_size("聲音", HORIZONTAL_ALIGNMENT_LEFT, -1, int(19 * u)).x
	var rx := vs.x - 40.0 * u - rw
	c.draw_string(f, Vector2(rx, y0 + h * 0.5 + 8.0 * u), "聲音", HORIZONTAL_ALIGNMENT_LEFT, -1, int(20 * u), Color(INK, 0.9))
	UIStyle.draw_keycap(c, Vector2(rx - ksz.x - 8.0 * u, y0 + h * 0.5 - 13.0 * u), "V", ks)
	var cw := f.get_string_size(CREDIT, HORIZONTAL_ALIGNMENT_LEFT, -1, int(21 * u)).x
	c.draw_string(f, Vector2(vs.x - 40.0 * u - cw, y0 + h * 0.5 + 34.0 * u), CREDIT, HORIZONTAL_ALIGNMENT_LEFT, -1, int(21 * u), Color(INK, 0.9))
	var alt := "Enter 或點一下滑鼠也可以"
	var aw := f.get_string_size(alt, HORIZONTAL_ALIGNMENT_LEFT, -1, int(22 * u)).x
	c.draw_string(f, Vector2(vs.x * 0.5 - aw * 0.5, y0 + h - 14.0 * u), alt, HORIZONTAL_ALIGNMENT_LEFT, -1, int(22 * u), INK)
	# 中間：按 空白鍵 開始（鍵帽一下一下被按）
	var ps := 42.0 * u
	var pfs := int(ps)
	var kcs := 32.0 * u
	var kc := UIStyle.keycap_size("空白鍵", kcs)
	var w1 := f.get_string_size("按", HORIZONTAL_ALIGNMENT_LEFT, -1, pfs).x
	var w2 := f.get_string_size("開始", HORIZONTAL_ALIGNMENT_LEFT, -1, pfs).x
	var sp := 18.0 * u
	var total := w1 + sp + kc.x + sp + w2
	var beat := maxf(sin(lt * 3.4), 0.0)
	var pulse := 1.0 + 0.035 * beat
	var mid := Vector2(vs.x * 0.5, y0 + h * 0.5 - 14.0 * u)
	var a := 1.0
	c.draw_set_transform(mid, 0.0, Vector2(pulse, pulse))
	var base := f.get_ascent(pfs) - f.get_height(pfs) * 0.5
	var px := -total * 0.5
	c.draw_string(f, Vector2(px, base), "按", HORIZONTAL_ALIGNMENT_LEFT, -1, pfs, Color(INK, a))
	px += w1 + sp
	UIStyle.draw_keycap(c, Vector2(px, -kc.y * 0.5 + beat * 5.0 * u), "空白鍵", kcs)
	px += kc.x + sp
	c.draw_string(f, Vector2(px, base), "開始", HORIZONTAL_ALIGNMENT_LEFT, -1, pfs, Color(RED.darkened(0.08), a))
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# ================================================================== 操作

func _unhandled_input(ev: InputEvent) -> void:
	var go := false
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		go = true
	elif ev is InputEventKey and ev.pressed and not ev.echo:
		if ev.keycode == KEY_V:
			map._toggle_sound()
		go = ev.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]
	if go:
		press()

## 按下開始：開場動畫播到一半是跳過動畫；標題出來了才是開始
func press(force_seen := false) -> void:
	if _state == "open" and _t < LOGO:
		_t = LOGO - 0.15
		_landed = true
		for s in _trail:
			(s as Node3D).visible = false
		_fade.color = Color(1, 1, 1, 0.85)
		return
	if _state == "leave" or _state == "done" or _t < LOGO + 1.5:
		return
	_state = "leave"
	_leave_t = 0.0
	_first = not force_seen and not intro_seen() and ResourceLoader.exists(INTRO_SCENE)
	Engine.set_meta("title_done", true)
	map._play("start")
	_fade.color = Color(1, 1, 1, 0.55)

func _finish() -> void:
	_state = "done"
	_layer.visible = false
	# 羽毛就留在家豪頭上（這次開遊戲都戴著）
	_feather.get_parent().remove_child(_feather)
	map._hero_body.add_child(_feather)
	_feather.position = Vector3(0.55, 1.75, 0.0)
	_feather.rotation = Vector3(0.0, 0.0, -1.2)
	_feather.scale = Vector3.ONE * 0.56
	_halo.visible = false
	_deck.visible = false
	_pop.visible = false
	for bit in _bits:
		(bit as Node3D).visible = false
	for n in _notes:
		(n as Node3D).visible = false
	map._hero_body.rotation = Vector3.ZERO
	map._hero_body.scale = Vector3.ONE
	for h in map._hens:
		(h.node as Node3D).scale = Vector3.ONE
	map._title_end()

# ================================================================== 每一畫面

func _process(dt: float) -> void:
	dt = minf(dt, 0.05)
	_t += dt
	if _state == "done":
		# 標題收掉之後：氣球雞往上飄走，幾秒後整個拿掉
		_done_t += dt
		_tick_sky(dt, true)
		if _done_t > 7.0:
			queue_free()
		return
	if _state == "open" and _t >= OPEN:
		_state = "title"
	var cam: Camera3D = map._cam
	var map_xf := cam.global_transform
	var pose := _pose()
	var xf := Transform3D(Basis.looking_at((pose[1] as Vector3) - (pose[0] as Vector3)), pose[0])
	var lk := 0.0
	if _state == "leave":
		_leave_t += dt
		if _first:
			# 第一次玩：畫面淡成黑的，接開場劇情
			_fade.color = _fade.color.lerp(Color(0.02, 0.02, 0.05, 1.0), minf(dt * 5.0, 1.0))
			if _leave_t > 0.9:
				set_process(false)
				get_tree().change_scene_to_file(INTRO_SCENE)
				return
		else:
			var k := clampf(_leave_t / LEAVE, 0.0, 1.0)
			lk = k * k * (3.0 - 2.0 * k)
			xf = xf.interpolate_with(map_xf, lk)
			var fly := smoothstep(0.0, 0.42, k)
			_logo.pivot_offset = Vector2(_logo.size.x * 0.5, _logo.size.y * 0.205)
			_logo.scale = Vector2.ONE * (1.0 + 0.25 * fly)
			_logo.position.y = -fly * fly * 620.0 * _u(_logo)
			_band.position.y = smoothstep(0.0, 0.45, k) * 220.0 * _u(_band)
			if k >= 1.0:
				_finish()
				return
	cam.global_transform = xf
	# 鏡頭飛得高的時候：霧散掉、海畫遠一點、影子畫遠一點（跟世界地圖一樣）
	var hk := smoothstep(14.0, 60.0, cam.global_position.y)
	var env: Environment = map._env
	env.fog_density = lerpf(lerpf(0.0009, env.fog_density, lk), 0.0003, hk)
	map._sun.directional_shadow_max_distance = lerpf(lerpf(150.0, 90.0, lk), 420.0, hk)
	map._sea.position = Vector3(cam.global_position.x, 0, cam.global_position.z).lerp(map._sea.position, lk)
	map._sea_mat.set_shader_parameter("fade_near", lerpf(lerpf(120.0, 60.0, lk), 700.0, hk))
	map._sea_mat.set_shader_parameter("fade_far", lerpf(lerpf(520.0, 260.0, lk), 1400.0, hk))
	map._hero.position.y += RISER * (1.0 - smoothstep(0.0, 0.25, lk))      # 木箱沉下去，家豪跟著落回地面
	_tick_feather(dt)
	_tick_sky(dt, _state == "leave")
	var vh := get_viewport().get_visible_rect().size.y
	for h in map._hens:
		var hn := h.node as Node3D
		var front := not cam.is_position_behind(hn.global_position)
		var sy := cam.unproject_position(hn.global_position + Vector3(0, 0.6, 0)).y / vh if front else 2.0
		hn.scale = Vector3.ONE * lerpf(1.0 - smoothstep(0.58, 0.68, sy), 1.0, lk)      # 會被下面那條紙帶切到的先縮起來
	var pads: Array = map.worlds[0].pad_nodes
	if lk < 0.25 and int(map.stage_sel) < pads.size():
		(pads[int(map.stage_sel)] as Node3D).visible = false
	_tick_dj(dt, 1.0 - lk)
	_tick_gag(dt)
	# 穿過雲層的時候畫面白一下；一開始從全白淡進來
	var y := cam.global_position.y
	var in_cloud := clampf(1.0 - absf(y - 54.0) / 11.0, 0.0, 1.0) if _t < 4.0 else 0.0
	var want := maxf(in_cloud * 0.35, 1.0 - smoothstep(0.0, 0.3, _t))
	if _state != "leave" or not _first:
		_fade.color = Color(1, 1, 1, maxf(want, move_toward(_fade.color.a, 0.0, dt * 1.6)))
	# 音效：字一個一個落下、羽毛一根一根張開
	var lt := _t - LOGO
	while _chars_hit < TITLE.length() and lt > _chars_hit * 0.13 + 0.25:
		map._play("hop", 0.8 + _chars_hit * 0.12)
		_chars_hit += 1
	while _feathers_hit < 5 and lt > 0.55 + _feathers_hit * 0.07 + 0.15:
		map._play("click", 1.0 + _feathers_hit * 0.14)
		_feathers_hit += 1
	_ov.queue_redraw()
	_skip.queue_redraw()
	_logo.queue_redraw()
	_band.queue_redraw()

## 現在鏡頭該在哪：[位置, 看哪裡]
func _pose() -> Array:
	if _t >= OPEN:
		return _orbit(_t)
	var end := _orbit(OPEN)
	var pos := _sample(_ck, _t)
	var ahead := _feather_pos(minf(_t + 0.25, LAND))
	var look := ahead.lerp(_hero + Vector3(0, 1.5 + RISER, 0), smoothstep(6.2, LAND, _t) * 0.999)
	look = look.lerp(end[1], smoothstep(LAND + 0.7, OPEN, _t))
	return [pos, look]

func _tick_feather(dt: float) -> void:
	if not _landed and _t < LAND:
		var p := _feather_pos(_t)
		_feather.position = p
		# 永遠正面朝著鏡頭（側面會變成一條線），只左右搖擺
		var cp: Vector3 = map._cam.global_position
		if cp.distance_to(p) > 0.5:
			_feather.look_at(cp, Vector3.UP)
		_feather.rotate_object_local(Vector3.BACK, 0.9 + sin(_t * 1.9) * 0.7)
		_feather.scale = Vector3.ONE * lerpf(2.0, 0.62, smoothstep(6.3, LAND, _t))
		_trail_pos.push_front(p)
		if _trail_pos.size() > _trail.size() + 2:
			_trail_pos.pop_back()
		for i in _trail.size():
			var s := _trail[i] as MeshInstance3D
			var j := i + 1
			s.visible = j < _trail_pos.size()
			if s.visible:
				s.position = _trail_pos[j]
				s.scale = Vector3.ONE * (1.2 * pow(1.0 - float(i) / _trail.size(), 1.5) + 0.08)
	elif not _landed:
		# 落在家豪頭上：光點炸開、家豪嚇一跳
		_landed = true
		_burst_t = 0.0
		_bang.visible = true
		map._play("land", 1.3)
		map._play("arrive")
	if _landed and _feather.visible:
		# 羽毛插在家豪頭上，跟著風晃
		_feather.position = map._hero.position + Vector3(0.55, 1.75, 0.0).rotated(Vector3.UP, FACE)
		_feather.rotation = Vector3(0.0, FACE, -1.2 + sin(_t * 2.2) * 0.1)
		_feather.scale = Vector3.ONE * 0.56
		_halo.scale = Vector3.ONE * (1.2 + 0.2 * sin(_t * 3.0))
	if _burst_t >= 0.0:
		_burst_t += dt
		var k := clampf(_burst_t / 0.9, 0.0, 1.0)
		for b in _burst:
			var n := b.node as MeshInstance3D
			n.visible = k < 1.0
			n.position = _hero + Vector3(0, 2.2 + RISER, 0) + (b.dir as Vector3) * (4.5 * (1.0 - pow(1.0 - k, 3.0)))
			n.scale = Vector3.ONE * 1.6 * (1.0 - k)
		for i in _trail.size():
			(_trail[i] as MeshInstance3D).scale *= maxf(1.0 - dt * 5.0, 0.0)
		_bang.position = _rel(Vector3(1.15, 1.9 + RISER + 0.4 * _back(_burst_t / 0.3), 0.3))
		_bang.visible = _burst_t < 0.8
		if _burst_t > 1.6:
			_burst_t = -1.0
			for s in _trail:
				(s as Node3D).visible = false

## 家豪面前的打碟台：乾草箱上兩張唱片
func _build_deck() -> void:
	_deck = Node3D.new()
	_deck.position = _rel(Vector3(0, -0.3, 1.25))
	_deck.rotation.y = FACE
	_world.add_child(_deck)
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color("c98a4b")
	wood.roughness = 0.9
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color("2a2430")
	dark.roughness = 0.35
	var box := BoxMesh.new()
	box.size = Vector3(2.5, 0.85, 0.9)
	var bi := MeshInstance3D.new()
	bi.mesh = box
	bi.material_override = wood
	bi.position = Vector3(0, 0.43, 0)
	_deck.add_child(bi)
	var top := BoxMesh.new()
	top.size = Vector3(2.7, 0.1, 1.05)
	var ti := MeshInstance3D.new()
	ti.mesh = top
	ti.material_override = dark
	ti.position = Vector3(0, 0.9, 0)
	_deck.add_child(ti)
	var riser := BoxMesh.new()
	riser.size = Vector3(1.5, RISER, 1.5)
	var rsi := MeshInstance3D.new()
	rsi.mesh = riser
	rsi.material_override = wood
	rsi.position = Vector3(0, RISER * 0.5 + 0.02, -1.25)
	_deck.add_child(rsi)
	# 木板的縫、前面的招牌、一排會閃的燈、兩邊的喇叭
	var seam := StandardMaterial3D.new()
	seam.albedo_color = Color("8f5a2c")
	for i in 4:
		var pl := BoxMesh.new()
		pl.size = Vector3(0.04, 0.8, 0.02)
		var pi := MeshInstance3D.new()
		pi.mesh = pl
		pi.material_override = seam
		pi.position = Vector3(-0.94 + i * 0.63, 0.43, 0.455)
		_deck.add_child(pi)
	var sign := Label3D.new()
	sign.text = "DJ 家豪"
	sign.font = UIStyle.font()
	sign.font_size = 110
	sign.pixel_size = 0.0042
	sign.outline_size = 28
	sign.modulate = Color("fff3c4")
	sign.outline_modulate = INK
	sign.position = Vector3(0, 0.42, 0.47)
	sign.rotation.z = -0.04
	_deck.add_child(sign)
	for i in 9:
		var led := BoxMesh.new()
		led.size = Vector3(0.2, 0.07, 0.03)
		var lm0 := StandardMaterial3D.new()
		lm0.albedo_color = FEATHERS[i % FEATHERS.size()]
		lm0.emission_enabled = true
		lm0.emission = FEATHERS[i % FEATHERS.size()]
		var ledi := MeshInstance3D.new()
		ledi.mesh = led
		ledi.material_override = lm0
		ledi.position = Vector3((i - 4) * 0.27, 0.8, 0.47)
		_deck.add_child(ledi)
		_leds.append(lm0)
	for side in [-1.0, 1.0]:
		var sp := BoxMesh.new()
		sp.size = Vector3(0.8, 1.35, 0.7)
		var spi := MeshInstance3D.new()
		spi.mesh = sp
		spi.material_override = dark
		spi.position = Vector3(side * 1.85, 0.68, -0.05)
		spi.rotation.y = -side * 0.25
		_deck.add_child(spi)
		for j in 2:
			var cone := CylinderMesh.new()
			cone.top_radius = 0.2 + j * 0.08
			cone.bottom_radius = 0.2 + j * 0.08
			cone.height = 0.04
			var cm := StandardMaterial3D.new()
			cm.albedo_color = Color("3c3644") if j == 1 else Color("ece4d6")
			var ci := MeshInstance3D.new()
			ci.mesh = cone
			ci.material_override = cm
			ci.rotation.x = PI * 0.5
			ci.position = Vector3(0, 0.3 - j * 0.62, 0.36)
			spi.add_child(ci)
			var ring := TorusMesh.new()
			ring.inner_radius = 0.2 + j * 0.08
			ring.outer_radius = 0.26 + j * 0.08
			var rm := StandardMaterial3D.new()
			rm.albedo_color = Color("8a8494")
			rm.metallic = 0.4
			rm.roughness = 0.4
			var rgi := MeshInstance3D.new()
			rgi.mesh = ring
			rgi.material_override = rm
			rgi.rotation.x = PI * 0.5
			rgi.position = ci.position
			spi.add_child(rgi)
			_cones.append(ci)
	for side in [-1.0, 1.0]:
		var disc := Node3D.new()
		disc.position = Vector3(side * 0.78, 0.98, 0)
		_deck.add_child(disc)
		var rec := CylinderMesh.new()
		rec.top_radius = 0.42
		rec.bottom_radius = 0.42
		rec.height = 0.05
		var ri := MeshInstance3D.new()
		ri.mesh = rec
		ri.material_override = dark
		disc.add_child(ri)
		var lab := CylinderMesh.new()
		lab.top_radius = 0.16
		lab.bottom_radius = 0.16
		lab.height = 0.06
		var lm := StandardMaterial3D.new()
		lm.albedo_color = RED if side < 0.0 else GOLD
		var li := MeshInstance3D.new()
		li.mesh = lab
		li.material_override = lm
		disc.add_child(li)
		var dot := BoxMesh.new()
		dot.size = Vector3(0.1, 0.07, 0.3)
		var di := MeshInstance3D.new()
		di.mesh = dot
		di.material_override = lm
		di.position = Vector3(0, 0, 0.25)
		disc.add_child(di)
		_discs.append(disc)
	for i in 3:
		var knob := BoxMesh.new()
		knob.size = Vector3(0.09, 0.12, 0.16)
		var ki := MeshInstance3D.new()
		ki.mesh = knob
		var km := StandardMaterial3D.new()
		km.albedo_color = FEATHERS[i]
		km.emission_enabled = true
		km.emission = FEATHERS[i]
		ki.material_override = km
		ki.position = Vector3((i - 1) * 0.16, 1.0, 0)
		_deck.add_child(ki)
		_knobs.append(ki)
	for i in 4:
		var n := Label3D.new()
		n.text = "♪" if i % 2 == 0 else "♫"
		n.font = UIStyle.font()
		n.font_size = 120
		n.pixel_size = 0.006
		n.outline_size = 30
		n.modulate = FEATHERS[(i + 1) % FEATHERS.size()]
		n.outline_modulate = Color(1, 1, 1)
		n.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		n.visible = false
		_world.add_child(n)
		_notes.append(n)
	_pop = Label3D.new()
	_pop.text = "啵！"
	_pop.font = UIStyle.font()
	_pop.font_size = 150
	_pop.pixel_size = 0.0068
	_pop.outline_size = 36
	_pop.modulate = Color(1, 1, 1)
	_pop.outline_modulate = INK
	_pop.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_pop.visible = false
	_world.add_child(_pop)
	for i in 7:
		var q := QuadMesh.new()
		q.size = Vector2(0.35, 0.22)
		var qm := StandardMaterial3D.new()
		qm.cull_mode = BaseMaterial3D.CULL_DISABLED
		qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		var qi := MeshInstance3D.new()
		qi.mesh = q
		qi.material_override = qm
		qi.visible = false
		qi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_world.add_child(qi)
		_bits.append(qi)

## 家豪在打碟：跟著拍子點頭、左右晃，唱片轉、音符飄；羽毛敲到頭的時候壓扁彈一下
func _tick_dj(dt: float, k: float) -> void:
	var body: Node3D = map._hero_body
	var beat := absf(sin(_t * 5.2))
	var hit := 0.0
	if _burst_t >= 0.0:
		hit = 0.4 * exp(-_burst_t * 5.0) * cos(_burst_t * 20.0)
	body.position.y = beat * 0.14 * k
	body.rotation.z = sin(_t * 2.6) * 0.12 * k
	body.rotation.x = beat * 0.04 * k
	body.scale = Vector3(1.0 + 0.5 * hit, 1.0 - hit, 1.0 + 0.5 * hit)
	var dk := smoothstep(0.0, 0.3, 1.0 - k)
	_deck.position.y = _hero.y - 0.3 - dk * 3.4          # 按下開始：整座打碟台沉進地裡
	_deck.visible = dk < 0.99
	for i in _discs.size():
		(_discs[i] as Node3D).rotation.y += dt * (3.4 + 2.6 * sin(_t * 1.3 + i * 2.0))
	for i in _leds.size():
		(_leds[i] as StandardMaterial3D).emission_energy_multiplier = 0.3 + 2.2 * maxf(sin(_t * 5.2 - i * 0.7), 0.0)
	for i in _cones.size():
		(_cones[i] as Node3D).scale = Vector3.ONE * (1.0 + 0.12 * beat)
	(map._hero as Node3D).rotation.y = FACE * k
	for i in _knobs.size():
		(_knobs[i] as Node3D).position.z = sin(_t * 2.0 + i * 1.9) * 0.22
	for i in _notes.size():
		var n := _notes[i] as Label3D
		var ph := fposmod(_t * 0.45 + i * 0.25, 1.0)
		n.visible = k > 0.9 and _t > OPEN - 0.3
		n.position = _rel(Vector3((2.0 + ph * 1.6) * (-1.0 if i % 2 == 0 else 1.0) + sin(ph * 9.0 + i) * 0.2, 1.2 + ph * 1.3, 0.8))
		n.modulate.a = sin(ph * PI)
		n.outline_modulate.a = sin(ph * PI)
		n.scale = Vector3.ONE * (0.7 + 0.5 * ph)

## 每隔幾秒一顆氣球「啵」一聲破掉，那隻母雞拍著翅膀掉下去，過一下又吹一顆新的飄回來
func _tick_gag(dt: float) -> void:
	if _state == "title" and _t > _gag_next:
		_gag_next = _t + 7.5
		var b: Dictionary = _balloons[_gag_i % 2]          # 輪流破離鏡頭最近的那兩顆（看得最清楚）
		_gag_i += 1
		b.pop = 0.0
		var at: Vector3 = (b.node as Node3D).position + Vector3(0, 3.1 * (b.node as Node3D).scale.y, 0)
		var col: Color = FEATHERS[(_gag_i - 1) % 2]
		_pop.position = at
		_pop.visible = true
		_pop_t = 0.0
		_bits_at = at
		for bit in _bits:
			((bit as MeshInstance3D).material_override as StandardMaterial3D).albedo_color = col
		map._play("bump", 1.6)
	if _pop.visible:
		_pop_t += dt
		_pop.scale = Vector3.ONE * (0.5 + 0.5 * _back(_pop_t / 0.18))
		_pop.visible = _pop_t < 0.55
	# 破掉的氣球皮往四周飛
	for i in _bits.size():
		var bit := _bits[i] as MeshInstance3D
		bit.visible = _pop_t < 0.7 and _gag_i > 0
		var ang := TAU * i / _bits.size()
		bit.position = _bits_at + Vector3(cos(ang), sin(ang) * 0.8, sin(ang * 2.0) * 0.3) * (2.2 * (1.0 - pow(1.0 - minf(_pop_t / 0.7, 1.0), 3.0))) + Vector3(0, -3.0 * _pop_t * _pop_t, 0)
		bit.rotation = Vector3(_pop_t * 9.0 + i, _pop_t * 7.0, i)
	for bi in _balloons.size():
		var b: Dictionary = _balloons[bi]
		var pt: float = b.pop
		if pt < 0.0:
			continue
		pt += dt
		b.pop = pt
		var hen := b.hen as Node3D
		# 掉到打碟台旁邊的草地上（拍翅膀亂轉）→ 坐著發呆 → 吹一顆新氣球 → 慢慢飄回去
		var land: Vector3 = _rel(Vector3(-4.6 if bi == 0 else 4.4, 0.15, 0.6)) - (b.base as Vector3)
		var fall_t := sqrt(absf(land.y) / 7.0)
		var f := minf(pt / fall_t, 1.0)
		var grounded := f >= 1.0
		var back_up := smoothstep(3.6, 6.6, pt)
		b.drop = Vector3(land.x * f, land.y * f * f, land.z * f) * (1.0 - back_up)
		hen.rotation.z = 0.0 if grounded else sin(pt * 24.0) * 0.6
		hen.rotation.y = (FACE + 0.35 * (1.0 if bi == 0 else -1.0) - (b.node as Node3D).rotation.y) * (1.0 - back_up)
		var squash := 0.0
		if grounded and pt < 2.8:
			squash = 0.35 * exp(-(pt - fall_t) * 6.0) * cos((pt - fall_t) * 18.0)
		hen.scale = Vector3(1.0 + squash * 0.5, 1.0 - squash, 1.0 + squash * 0.5)
		for part in b.parts:
			(part as Node3D).visible = pt > 2.8
			(part as Node3D).scale = Vector3.ONE * _back((pt - 2.8) / 0.6)
		if pt > 6.7:
			b.pop = -1.0
			b.drop = Vector3.ZERO
			hen.rotation.y = 0.0

func _tick_sky(dt: float, leaving: bool) -> void:
	for b in _balloons:
		if leaving:
			b.up = float(b.up) + dt * (7.0 + float(b.up) * 2.2)
		var ph: float = b.ph
		var n := b.node as Node3D
		var rise := smoothstep(LAND + 0.3 + ph * 0.12, OPEN + 1.2 + ph * 0.12, _t)
		n.visible = rise > 0.0
		n.position = (b.base as Vector3) + Vector3(sin(_t * 0.16 + ph) * 1.0, sin(_t * 0.7 + ph) * 0.4 + float(b.up) - 26.0 * (1.0 - rise), cos(_t * 0.13 + ph) * 1.0) + (b.drop as Vector3)
		n.rotation = Vector3(sin(_t * 0.9 + ph) * 0.07, _t * 0.2 + ph, sin(_t * 0.6 + ph) * 0.10)
	for cl in _clouds:
		(cl.node as Node3D).position = (cl.base as Vector3) + Vector3(_t * 0.5 + sin(_t * 0.1 + float(cl.phase)) * 2.0, 0, 0)

# ================================================================== 開發用：截圖

func _titleshots(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	for at in [0.3, 0.9, 1.5, 2.3, 3.3, 4.6, 5.8, 7.0, 7.9, 8.35, 8.8, 9.5, 9.9, 10.8, 12.5, 13.9, 14.3, 15.2, 16.5, 18.5, 24.0]:
		while _t < float(at):
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var keep := _t
		get_viewport().get_texture().get_image().save_png(dir.path_join("title_%05.2f.png" % float(at)))
		_t = keep
	press(true)
	for at2 in [0.5, 1.1, 2.6]:
		var until := _t + float(at2) - (0.0 if at2 == 0.5 else (0.5 if at2 == 1.1 else 1.1))
		while _t < until:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(dir.path_join("leave_%.1f.png" % float(at2)))
	var done := FileAccess.open(dir.path_join("DONE"), FileAccess.WRITE)
	done.store_string("ok")
	done.close()
	get_tree().quit()
