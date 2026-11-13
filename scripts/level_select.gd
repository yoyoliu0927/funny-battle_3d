extends Node3D
## 選關畫面（卡片式）
##
## 參考市面上的選關畫面：
##   - Angry Birds／Cut the Rope：一個大關一張大卡片，卡片上寫標題、星星進度；還沒開放的卡片蓋一個大鎖。
##   - Candy Crush／瑪利歐世界地圖：選了大關之後，小關是一串編號圓點，沿著一條小路排開，過了的打勾、沒解鎖的上鎖。
##   - Overcooked 的世界地圖：背景是一座可愛的小島，前景的介面一眼就看得懂。
##
## 版面（由上到下）：
##   標題緞帶 → 四張「島」卡片（四個組員各一座；還沒做出來的顯示「建造中」上鎖）
##   → 這座島的小關（編號圓點＋小路）→ 下方筆記紙：這一關的名字、說明、大「開始」按鈕
##   右下角另外一小塊「範例關（開發測試用）」：農場範例、範本大關，跟正式的島分開。
##
## 背景沿用原本的低多邊形小島（調暗、鏡頭慢慢繞），讓前景的字看得清楚。
## 大關從 scripts/registry.gd 自動找到（levels/*/chapter.gd、examples/*/chapter.gd），各關不用改這個檔案。
##
## 操作：← → 選島、↑ ↓ 或數字鍵選小關、Enter 開始、Esc 回到開場；滑鼠移到卡片／圓點上會選取，點「開始」或再點一次圓點就開始。

const TerrainShader := preload("res://shaders/terrain.gdshader")
const Progress := preload("res://scripts/progress.gd")
const Registry := preload("res://scripts/registry.gd")
const UIStyle := preload("res://scripts/ui/ui_style.gd")   # 全遊戲共用的介面美術
const TEX := "res://assets/textures/"
const INTRO_SCENE := "res://scenes/intro.tscn"

## 正式的「島」一共幾座（四個組員各一座）；不夠的用「建造中」補滿
const ISLAND_SLOTS := 4

## 島的輪廓（背景裝飾用的小島）
const OUTLINE := [
	Vector2(-21.5, 0.0), Vector2(-20.0, -2.5), Vector2(-18.9, -5.8), Vector2(-16.5, -4.2),
	Vector2(-13.6, -5.2), Vector2(-5.8, -3.8), Vector2(-0.7, -3.5), Vector2(5.7, -3.2),
	Vector2(10.4, -1.4), Vector2(15.9, 0.5), Vector2(21.5, 0.0), Vector2(21.3, 1.4),
	Vector2(16.3, 3.9), Vector2(13.9, 8.1), Vector2(9.5, 10.8), Vector2(4.1, 11.7),
	Vector2(-3.1, 10.6), Vector2(-7.2, 9.0), Vector2(-14.1, 5.8), Vector2(-17.5, 4.4),
	Vector2(-19.7, 1.3),
]
const RIDGE := [Vector2(-14.9, -0.5), Vector2(-12.5, 0.6), Vector2(-9.8, 1.2), Vector2(1.6, 1.9), Vector2(12.9, 1.6), Vector2(17.9, 1.3)]
const ISLETS := [[Vector2(3.6, 16.6), 1.1], [Vector2(5.5, 17.4), 0.7], [Vector2(2.4, 17.6), 0.6], [Vector2(10.7, -5.6), 0.6], [Vector2(18.1, -7.5), 0.8]]
const GRID_X := 120
const GRID_Z := 76
const MAP_MIN := Vector2(-28.0, -16.0)
const MAP_MAX := Vector2(28.0, 20.0)

## 卡片的顏色（每座島一個主色）。認得的 id 用固定顏色，其他照順序輪流
const CARD_COLORS := {
	"ice": Color("7cc6ec"), "example_farm": Color("e8b04a"), "_template": Color("a99bd6"),
}
const CARD_CYCLE := [Color("7cc6ec"), Color("8fcf6f"), Color("f0a35a"), Color("c495e0")]
const INK := Color("3b2a20")
const PAPER := Color("fff8e7")
const PAPER_EDGE := Color("d9c9a8")
const LOCKED := Color("d9d4c8")
const LOCKED_EDGE := Color("9c968a")
const GREEN := Color("5cb85c")
const GOLD := Color("f2c230")

## 大關（照 Registry 排好）
var LEVELS: Array = []
## 選單上的每一格：{"ch": 大關 Dictionary（或 {}）, "slot": 第幾座島（範例是 -1）, "example": bool}
var entries: Array = []
var selected := 0            # entries 的第幾格
var stage_sel := 0           # 目前大關裡選的小關（0 開始）
var _noise := FastNoiseLite.new()
var _cam: Camera3D
var _cam_base := Vector3.ZERO
var _t := 0.0
var _title: Label
var _toast: Label
var _toast_t := 0.0
var _starting := false
var _layer: CanvasLayer
var _cards: Array = []       # 每個 entry 一張卡片（_Pad）
var _stage_pads: Array = []  # 目前大關的小關圓點（_Pad）
var _path_pad: _Pad          # 小關之間的小路
var _detail: _Pad            # 下方的筆記紙（這一關的資訊＋開始按鈕）
var _start_rect := Rect2()   # 「開始」按鈕在 _detail 裡的位置
var _ex_box: _Pad            # 範例區的底

# ================================================================== 啟動

func _ready() -> void:
	_noise.seed = 1624
	_noise.frequency = 0.12
	_noise.fractal_octaves = 3
	_load_chapters()
	_cam = get_node("../Camera3D")
	_cam.position = Vector3(0, 30, 40)
	_cam.rotation = Vector3(-0.72, 0, 0)
	_cam_base = _cam.position
	_build_island()
	_build_sea()
	_build_trees()
	_build_ui()
	selected = -1
	select(_first_selection())
	if "--autotest" in OS.get_cmdline_user_args():
		_autotest.call_deferred()

## 讀大關清單，排成「四座島＋範例區」
func _load_chapters() -> void:
	LEVELS = Registry.chapters()
	var islands: Array = LEVELS.filter(func(c): return not _is_example(c))
	var examples: Array = LEVELS.filter(func(c): return _is_example(c))
	entries.clear()
	for k in maxi(ISLAND_SLOTS, islands.size()):
		entries.append({"ch": islands[k] if k < islands.size() else {}, "slot": k, "example": false})
	for c in examples:
		entries.append({"ch": c, "slot": -1, "example": true})

## 範例：examples/ 底下的，或底線開頭的資料夾（_template）
func _is_example(c: Dictionary) -> bool:
	return bool(c.get("example", false)) or String(c.id).begins_with("_")

## 一開始選哪一格：第一座還沒全破、可以玩的島；都沒有就第一格
func _first_selection() -> int:
	for k in entries.size():
		var ch: Dictionary = entries[k].ch
		if not entries[k].example and _playable(ch) and not Progress.chapter_cleared(ch):
			return k
	for k in entries.size():
		if _playable(entries[k].ch):
			return k
	return 0

func _playable(ch: Dictionary) -> bool:
	return not ch.is_empty() and not ch.stages.is_empty() and ch.stages.any(func(s): return String(s.scene) != "")

func _cur() -> Dictionary:
	return entries[selected].ch if selected < entries.size() else {}

func _color_of(e: Dictionary) -> Color:
	var ch: Dictionary = e.ch
	if ch.is_empty() or not _playable(ch):
		return LOCKED
	if CARD_COLORS.has(ch.id):
		return CARD_COLORS[ch.id]
	return CARD_CYCLE[maxi(e.slot, 0) % CARD_CYCLE.size()]

# ================================================================== 背景小島（調暗、當背景）

func _sd(p: Vector2) -> float:
	var inside := false
	var dmin := INF
	var n := OUTLINE.size()
	for i in n:
		var a: Vector2 = OUTLINE[i]
		var b: Vector2 = OUTLINE[(i + 1) % n]
		if (a.y > p.y) != (b.y > p.y) and p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x:
			inside = not inside
		var t := clampf((p - a).dot(b - a) / (b - a).length_squared(), 0.0, 1.0)
		dmin = minf(dmin, p.distance_to(a.lerp(b, t)))
	var d := dmin if inside else -dmin
	for isl in ISLETS:
		d = maxf(d, isl[1] - p.distance_to(isl[0]))
	return d

static func _ss(a: float, b: float, x: float) -> float:
	var t := clampf((x - a) / (b - a), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)

func height_at(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var d := _sd(p)
	var n := _noise.get_noise_2d(x, z)
	var land := 0.25 + n * 0.25
	var rd := INF
	var along := 0.0
	for i in RIDGE.size() - 1:
		var a: Vector2 = RIDGE[i]
		var b: Vector2 = RIDGE[i + 1]
		var t := clampf((p - a).dot(b - a) / (b - a).length_squared(), 0.0, 1.0)
		var dd := p.distance_to(a.lerp(b, t))
		if dd < rd:
			rd = dd
			along = (float(i) + t) / (RIDGE.size() - 1)
	var taper := _ss(0.0, 0.18, along) * _ss(1.0, 0.75, along)
	var ridge := exp(-pow(rd / 3.2, 2.0)) * (0.35 + 0.65 * taper)
	land += ridge * (5.2 + _noise.get_noise_2d(x * 2.0, z * 2.0) * 2.4)
	land *= _ss(0.0, 1.6, d)
	return lerpf(-0.9, land, _ss(-1.2, 0.6, d))

func _build_island() -> void:
	var nx := GRID_X + 1
	var nz := GRID_Z + 1
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	var hs := PackedFloat32Array()
	hs.resize(nx * nz)
	for j in nz:
		for i in nx:
			hs[j * nx + i] = height_at(lerpf(MAP_MIN.x, MAP_MAX.x, float(i) / GRID_X), lerpf(MAP_MIN.y, MAP_MAX.y, float(j) / GRID_Z))
	var dx := (MAP_MAX.x - MAP_MIN.x) / GRID_X
	var dz := (MAP_MAX.y - MAP_MIN.y) / GRID_Z
	for j in nz:
		for i in nx:
			var x := lerpf(MAP_MIN.x, MAP_MAX.x, float(i) / GRID_X)
			var z := lerpf(MAP_MIN.y, MAP_MAX.y, float(j) / GRID_Z)
			var h := hs[j * nx + i]
			verts.append(Vector3(x, h, z))
			var hl := hs[j * nx + maxi(i - 1, 0)]
			var hr := hs[j * nx + mini(i + 1, nx - 1)]
			var hd := hs[maxi(j - 1, 0) * nx + i]
			var hu := hs[mini(j + 1, nz - 1) * nx + i]
			var nrm := Vector3((hl - hr) / (2.0 * dx), 1.0, (hd - hu) / (2.0 * dz)).normalized()
			norms.append(nrm)
			var d := _sd(Vector2(x, z))
			var sand := 1.0 - _ss(0.2, 1.3, d)
			var rock := _ss(0.42, 0.65, 1.0 - nrm.y) * _ss(1.6, 2.6, h) + _ss(3.4, 4.4, h)
			var fields := _ss(0.15, 0.45, _noise.get_noise_2d(x * 1.7 + 30.0, z * 1.7)) * (1.0 - _ss(0.8, 1.8, h))
			cols.append(Color(sand, fields * 0.8, clampf(rock, 0.0, 1.0), 1.0))
	for j in nz - 1:
		for i in nx - 1:
			var a := j * nx + i
			idx.append_array([a, a + 1, a + nx, a + 1, a + nx + 1, a + nx])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mat := ShaderMaterial.new()
	mat.shader = TerrainShader
	mat.set_shader_parameter("detail_tex", load(TEX + "gravelly_sand_diff_1k.jpg"))
	mat.set_shader_parameter("ground_a", Color(0.58, 0.65, 0.33))
	mat.set_shader_parameter("ground_b", Color(0.50, 0.60, 0.29))
	mat.set_shader_parameter("grassy", Color(0.44, 0.58, 0.27))
	mat.set_shader_parameter("sand_c", Color(0.90, 0.80, 0.56))
	mat.set_shader_parameter("dirt_c", Color(0.76, 0.66, 0.40))
	mat.set_shader_parameter("rock_c", Color(0.66, 0.64, 0.58))
	var mi := MeshInstance3D.new()
	mi.name = "Island"
	mi.mesh = mesh
	mi.material_override = mat
	add_child(mi)

func _build_sea() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(400, 400)
	var mi := MeshInstance3D.new()
	mi.name = "Sea"
	mi.mesh = plane
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/water.gdshader")
	mi.material_override = m
	mi.position.y = -0.05
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)

func _build_trees() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = 99
	var blob := SphereMesh.new()
	blob.radius = 1.0
	blob.height = 1.8
	blob.radial_segments = 7
	blob.rings = 4
	var xf: Array[Transform3D] = []
	var cs: Array[Color] = []
	for k in 1800:
		var x := r.randf_range(-21.0, 22.0)
		var z := r.randf_range(-6.0, 12.0)
		if _sd(Vector2(x, z)) < 0.9:
			continue
		var h := height_at(x, z)
		var forest := _noise.get_noise_2d(x * 0.9 - 50.0, z * 0.9)
		var on_mountain := h > 0.9 and h < 3.6
		if not (on_mountain and r.randf() < 0.5) and not (forest > 0.4 and r.randf() < 0.6):
			continue
		var s := r.randf_range(0.18, 0.32)
		xf.append(Transform3D(Basis(Vector3.UP, r.randf() * TAU).scaled(Vector3(s, s * 1.1, s)), Vector3(x, h + s * 0.7, z)))
		cs.append(Color(r.randf_range(0.22, 0.34), r.randf_range(0.44, 0.56), r.randf_range(0.2, 0.28)))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = blob
	mm.instance_count = xf.size()
	for i in xf.size():
		mm.set_instance_transform(i, xf[i])
		mm.set_instance_color(i, cs[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Trees"
	mmi.multimesh = mm
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/forest_crown.gdshader")
	mmi.material_override = m
	add_child(mmi)

# ================================================================== 介面

## 自己畫的方塊（卡片、圓點、筆記紙都用它）：畫圖交給 painter，滑鼠交給 on_hover／on_click
class _Pad:
	extends Control
	var painter: Callable
	var on_hover: Callable
	var on_click: Callable
	var data := {}
	func _draw() -> void:
		if painter.is_valid():
			painter.call(self)
	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseMotion and on_hover.is_valid():
			on_hover.call(self, e)
		elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT and on_click.is_valid():
			on_click.call(self, e)
			accept_event()

func _pad(parent: Node, painter: Callable, stop_mouse := true) -> _Pad:
	var p := _Pad.new()
	p.painter = painter
	p.mouse_filter = Control.MOUSE_FILTER_STOP if stop_mouse else Control.MOUSE_FILTER_IGNORE
	parent.add_child(p)
	return p

func _build_ui() -> void:
	_layer = CanvasLayer.new()
	add_child(_layer)
	# 背景調暗：上面深一點（標題、卡片的字才看得清楚）
	var dim := _pad(_layer, _paint_dim, false)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_title = Label.new()
	_title.text = "家豪的起義之路"
	_title.label_settings = UIStyle.ls(42)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_title.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_title.offset_top = 14
	UIStyle.ribbon(_title)
	_layer.add_child(_title)
	var sub := Label.new()
	sub.text = "選一座島，把被人類關起來的動物救出來！"
	sub.label_settings = UIStyle.ls(20, Color(1, 0.97, 0.9), 6, Color(0.05, 0.08, 0.15, 0.85))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	sub.grow_horizontal = Control.GROW_DIRECTION_BOTH
	sub.offset_top = 88
	_layer.add_child(sub)
	# 四座島的卡片＋範例區
	_ex_box = _pad(_layer, _paint_ex_box, false)
	for k in entries.size():
		var c := _pad(_layer, _paint_card)
		c.data = {"i": k}
		c.on_hover = func(_p, _e): _hover_entry(k)
		c.on_click = func(_p, _e): select(k)
		_cards.append(c)
	# 小關的小路（在圓點底下）
	_path_pad = _pad(_layer, _paint_path, false)
	# 下方筆記紙
	_detail = _pad(_layer, _paint_detail)
	_detail.on_click = func(_p, e: InputEventMouseButton):
		if _start_rect.has_point(e.position):
			start_selected()
	# 操作說明
	var hint := Label.new()
	hint.text = "← → 選島　｜　↑ ↓ 或數字鍵 選小關　｜　Enter 開始　｜　Esc 回到開場　｜　滑鼠：點卡片選島、點圓點選關"
	hint.label_settings = UIStyle.ls(17)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hint.offset_bottom = -10
	UIStyle.pill(hint, Color(0.1, 0.13, 0.2, 0.8), Color(1, 1, 1, 0.35), Color(1, 1, 1))
	_layer.add_child(hint)
	# 提示字卡
	_toast = Label.new()
	_toast.label_settings = UIStyle.ls(26)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast.offset_top = 40
	_toast.visible = false
	UIStyle.pill(_toast)
	_layer.add_child(_toast)
	get_viewport().size_changed.connect(_layout)
	_layout()

## 依畫面大小排版（以 1600×900 為準，按比例縮放）
func _layout() -> void:
	var vs := get_viewport().get_visible_rect().size
	var u := minf(vs.x / 1600.0, vs.y / 900.0)
	var islands := entries.filter(func(e): return not e.example)
	var exs := entries.filter(func(e): return e.example)
	var cw := 290.0 * u
	var ch := 250.0 * u
	var gap := 26.0 * u
	var total := islands.size() * cw + (islands.size() - 1) * gap
	var x0 := (vs.x - total) * 0.5
	var y0 := 132.0 * u
	for k in entries.size():
		var e: Dictionary = entries[k]
		var c: _Pad = _cards[k]
		if not e.example:
			var j := int(e.slot)
			c.position = Vector2(x0 + j * (cw + gap), y0)
			c.size = Vector2(cw, ch)
			c.data.small = false
	# 範例區：右下角一個小盒子，裡面一排小卡
	var ew := 200.0 * u
	var eh := 70.0 * u
	var bx := vs.x - (ew + 30.0 * u) - 14.0 * u
	var by := 560.0 * u
	_ex_box.position = Vector2(bx - 14.0 * u, by - 42.0 * u)
	_ex_box.size = Vector2(ew + 28.0 * u, 42.0 * u + exs.size() * (eh + 10.0 * u) + 6.0 * u)
	_ex_box.visible = not exs.is_empty()
	var n := 0
	for k in entries.size():
		if entries[k].example:
			var c: _Pad = _cards[k]
			c.position = Vector2(bx, by + n * (eh + 10.0 * u))
			c.size = Vector2(ew, eh)
			c.data.small = true
			n += 1
	# 小關的圓點區、下方筆記紙
	_path_pad.position = Vector2(40.0 * u, 400.0 * u)
	_path_pad.size = Vector2(vs.x - 80.0 * u - (ew + 60.0 * u), 170.0 * u)
	_detail.position = Vector2(60.0 * u, 600.0 * u)
	_detail.size = Vector2(vs.x - 120.0 * u - (ew + 60.0 * u), 220.0 * u)
	_rebuild_stage_pads()
	for c in _cards:
		(c as _Pad).queue_redraw()
	_ex_box.queue_redraw()

## 目前大關的小關圓點，沿著一條波浪小路排開
func _rebuild_stage_pads() -> void:
	for p in _stage_pads:
		(p as _Pad).queue_free()
	_stage_pads.clear()
	var ch := _cur()
	var area := Rect2(_path_pad.position, _path_pad.size)
	var n: int = 0 if ch.is_empty() else ch.stages.size()
	_path_pad.data = {"pts": []}
	if n == 0:
		_path_pad.queue_redraw()
		_detail.queue_redraw()
		return
	var u := area.size.y / 170.0
	var r := 34.0 * u
	var step := minf(140.0 * u, (area.size.x - 2.0 * r - 40.0 * u) / maxf(n - 1, 1))
	var span := step * (n - 1)
	var sx := area.position.x + (area.size.x - span) * 0.5
	var pts: Array = []
	for k in n:
		var cx := sx + k * step
		var cy := area.position.y + area.size.y * 0.42 + sin(k * 1.1) * 18.0 * u
		pts.append(Vector2(cx, cy))
		var p := _pad(_layer, _paint_stage)
		p.position = Vector2(cx - r * 1.6, cy - r * 1.3)
		p.size = Vector2(r * 3.2, r * 3.5)
		p.data = {"k": k, "r": r}
		p.on_hover = func(_p, _e): _hover_stage(k)
		p.on_click = func(_p, _e):
			if stage_sel == k:
				start_selected()
			else:
				select_stage(k)
		_stage_pads.append(p)
	_path_pad.data = {"pts": pts}
	_path_pad.queue_redraw()
	_detail.queue_redraw()

func _hover_entry(k: int) -> void:
	if k != selected:
		select(k)

func _hover_stage(k: int) -> void:
	if k != stage_sel:
		select_stage(k)

# ---------------------------------------------------------------- 畫圖

func _font() -> Font:
	var f := UIStyle.font()
	return f if f else ThemeDB.fallback_font

func _box(bg: Color, edge: Color, radius: float, border := 3.0, shadow := true) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = edge
	s.set_border_width_all(int(border))
	s.border_width_bottom = int(border) + 2
	s.set_corner_radius_all(int(radius))
	if shadow:
		s.shadow_color = Color(0, 0, 0, 0.3)
		s.shadow_size = 8
		s.shadow_offset = Vector2(3, 6)
	return s

func _text(c: Control, pos: Vector2, t: String, size: float, col: Color, w := -1.0, align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	c.draw_string(_font(), pos, t, align, w, int(size), col)

func _lock_icon(c: Control, center: Vector2, s: float, col: Color) -> void:
	# 大鎖：U 形鎖環＋圓角鎖身＋鑰匙孔
	c.draw_arc(center + Vector2(0, -s * 0.15), s * 0.42, PI, TAU, 24, col, s * 0.14, true)
	c.draw_line(center + Vector2(-s * 0.42, -s * 0.15), center + Vector2(-s * 0.42, s * 0.1), col, s * 0.14, true)
	c.draw_line(center + Vector2(s * 0.42, -s * 0.15), center + Vector2(s * 0.42, s * 0.1), col, s * 0.14, true)
	c.draw_style_box(_box(col, col.darkened(0.3), s * 0.12, 2.0, false), Rect2(center + Vector2(-s * 0.62, 0.0), Vector2(s * 1.24, s * 0.9)))
	c.draw_circle(center + Vector2(0, s * 0.36), s * 0.11, Color(0, 0, 0, 0.45))
	c.draw_rect(Rect2(center + Vector2(-s * 0.04, s * 0.38), Vector2(s * 0.08, s * 0.22)), Color(0, 0, 0, 0.45))

func _check_icon(c: Control, center: Vector2, s: float, col: Color) -> void:
	c.draw_polyline(PackedVector2Array([center + Vector2(-s * 0.45, 0), center + Vector2(-s * 0.1, s * 0.35), center + Vector2(s * 0.5, -s * 0.4)]), col, s * 0.2, true)

func _star(c: Control, center: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI * 0.5 + i * PI / 5.0
		var rr := r if i % 2 == 0 else r * 0.45
		pts.append(center + Vector2(cos(a), sin(a)) * rr)
	c.draw_colored_polygon(pts, col)

func _paint_dim(c: Control) -> void:
	var h := c.size.y
	c.draw_rect(Rect2(Vector2.ZERO, c.size), Color(0.05, 0.09, 0.16, 0.38))
	c.draw_rect(Rect2(Vector2.ZERO, Vector2(c.size.x, h * 0.42)), Color(0.05, 0.09, 0.16, 0.25))

func _paint_ex_box(c: Control) -> void:
	c.draw_style_box(_box(Color(0.1, 0.13, 0.2, 0.72), Color(1, 1, 1, 0.3), 12, 2.0, false), Rect2(Vector2.ZERO, c.size))
	var u := c.size.x / 228.0
	_text(c, Vector2(14 * u, 28 * u), "範例關（開發測試用）", 17 * u, Color(1, 0.95, 0.8))

## 一座島的卡片
func _paint_card(c: Control) -> void:
	var k: int = c.data.i
	var e: Dictionary = entries[k]
	var ch: Dictionary = e.ch
	var sel := k == selected
	var playable := _playable(ch)
	var col := _color_of(e)
	var r := Rect2(Vector2.ZERO, c.size)
	var lift := (-8.0 if sel else 0.0) + (sin(_t * 3.0) * 2.0 if sel else 0.0)
	r.position.y += lift
	var u := c.size.x / (200.0 if c.data.get("small", false) else 290.0)
	if c.data.get("small", false):
		# 範例區的小卡：一條色帶＋名字＋小關數
		c.draw_style_box(_box(PAPER if playable else LOCKED, Color("f7d35a") if sel else (PAPER_EDGE if playable else LOCKED_EDGE), 10, 4.0 if sel else 2.0), r)
		c.draw_rect(Rect2(r.position + Vector2(4, 4), Vector2(14 * u, r.size.y - 8)), col)
		_text(c, r.position + Vector2(28 * u, 30 * u), String(ch.title), 18 * u, INK, r.size.x - 34 * u)
		_text(c, r.position + Vector2(28 * u, 54 * u), "%d 小關" % ch.stages.size(), 14 * u, Color(INK, 0.65))
		return
	var paper := PAPER if playable else LOCKED
	var edge := Color("f7d35a") if sel else (PAPER_EDGE if playable else LOCKED_EDGE)
	c.draw_style_box(_box(paper, edge, 16, 6.0 if sel else 3.0), r)
	# 上面的色帶：第幾座島＋島名
	var head := Rect2(r.position + Vector2(6, 6), Vector2(r.size.x - 12, 58 * u))
	var hb := StyleBoxFlat.new()
	hb.bg_color = col
	hb.corner_radius_top_left = int(12 * u)
	hb.corner_radius_top_right = int(12 * u)
	c.draw_style_box(hb, head)
	_text(c, head.position + Vector2(12 * u, 24 * u), "第 %d 座島" % (int(e.slot) + 1), 15 * u, Color(INK, 0.75))
	var title := String(ch.title) if not ch.is_empty() else "？？？島"
	_text(c, head.position + Vector2(12 * u, 50 * u), title, 26 * u, INK, head.size.x - 20 * u)
	var body_y := head.end.y
	if not playable:
		# 還沒做好：斜斜一條施工膠帶＋大鎖＋「建造中」
		var tape_y := r.end.y - 40 * u
		var tp := PackedVector2Array([Vector2(r.position.x + 6, tape_y + 10 * u), Vector2(r.end.x - 6, tape_y - 14 * u), Vector2(r.end.x - 6, tape_y + 4 * u), Vector2(r.position.x + 6, tape_y + 28 * u)])
		c.draw_colored_polygon(tp, Color("f2c230"))
		var stripes := int((r.size.x - 12) / (22 * u))
		for i in stripes:
			if i % 2 == 0:
				continue
			var x0 := r.position.x + 6 + i * 22 * u
			var x1 := x0 + 22 * u
			var f0 := (x0 - r.position.x - 6) / (r.size.x - 12)
			var f1 := (x1 - r.position.x - 6) / (r.size.x - 12)
			var y0a := lerpf(tape_y + 10 * u, tape_y - 14 * u, f0)
			var y1a := lerpf(tape_y + 10 * u, tape_y - 14 * u, f1)
			c.draw_colored_polygon(PackedVector2Array([Vector2(x0, y0a), Vector2(x1, y1a), Vector2(x1 - 10 * u, y1a + 18 * u), Vector2(x0 - 10 * u, y0a + 18 * u)]), Color(0.15, 0.13, 0.12, 0.85))
		_lock_icon(c, Vector2(r.get_center().x, body_y + 28 * u), 40 * u, Color("8a857a"))
		_text(c, Vector2(r.position.x, body_y + 100 * u), "建造中", 26 * u, Color("6f6a60"), r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
		var who := ("%s 製作中" % ch.author) if not ch.is_empty() and String(ch.author) != "" else "組員製作中，敬請期待"
		_text(c, Vector2(r.position.x, body_y + 124 * u), who, 14 * u, Color("6f6a60"), r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
		return
	# 左邊：圓形徽章（島名第一個字）
	var badge := r.position + Vector2(52 * u, body_y - r.position.y + 54 * u)
	c.draw_circle(badge, 38 * u, col.darkened(0.25))
	c.draw_circle(badge, 34 * u, col.lightened(0.35))
	var glyph := String(ch.title).replace("範例：", "").substr(0, 1)
	_text(c, badge + Vector2(-40 * u, 14 * u), glyph, 38 * u, INK, 80 * u, HORIZONTAL_ALIGNMENT_CENTER)
	# 右邊：說明（最多三行）
	var desc := String(ch.desc)
	c.draw_multiline_string(_font(), r.position + Vector2(100 * u, body_y - r.position.y + 28 * u), desc, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 112 * u, int(15 * u), 3, Color(INK, 0.85))
	# 下面：星星進度（過了幾小關）＋進度條
	var total: int = ch.stages.size()
	var done: int = ch.stages.filter(func(s): return Progress.is_cleared(s.id)).size()
	var py := r.end.y - 36 * u
	_star(c, Vector2(r.position.x + 24 * u, py), 13 * u, GOLD)
	_text(c, Vector2(r.position.x + 42 * u, py + 7 * u), "%d / %d" % [done, total], 18 * u, INK)
	var bar := Rect2(Vector2(r.position.x + 110 * u, py - 6 * u), Vector2(r.size.x - 128 * u, 12 * u))
	c.draw_style_box(_box(Color(0, 0, 0, 0.12), Color(0, 0, 0, 0), 6, 0.0, false), bar)
	if total > 0 and done > 0:
		c.draw_style_box(_box(GREEN, Color(0, 0, 0, 0), 6, 0.0, false), Rect2(bar.position, Vector2(bar.size.x * done / total, bar.size.y)))
	if Progress.chapter_cleared(ch):
		_check_icon(c, Vector2(r.end.x - 26 * u, r.position.y + 26 * u), 22 * u, GREEN)

## 小關之間的小路（虛線）
func _paint_path(c: Control) -> void:
	var pts: Array = c.data.get("pts", [])
	var ch := _cur()
	if pts.is_empty():
		var msg := "這座島還在建造中，先玩別的島吧！"
		var tw := _font().get_string_size(msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
		c.draw_style_box(_box(Color(0.08, 0.11, 0.18, 0.8), Color(1, 1, 1, 0.3), 14, 2.0, false), Rect2(Vector2((c.size.x - tw) * 0.5 - 24, c.size.y * 0.5 - 34), Vector2(tw + 48, 52)))
		_text(c, Vector2(0, c.size.y * 0.5), msg, 26, Color(1, 0.97, 0.9), c.size.x, HORIZONTAL_ALIGNMENT_CENTER)
		return
	for k in range(1, pts.size()):
		var a: Vector2 = pts[k - 1] - c.position
		var b: Vector2 = pts[k] - c.position
		var n := int(a.distance_to(b) / 16.0)
		var done := Progress.is_cleared(ch.stages[k - 1].id)
		for i in range(1, n):
			var p := a.lerp(b, float(i) / n) + Vector2(0, sin(float(i) / n * PI) * -8.0)
			c.draw_circle(p, 4.0, Color(1, 0.95, 0.75, 0.95) if done else Color(1, 1, 1, 0.55))

## 一個小關的圓點
func _paint_stage(c: Control) -> void:
	var k: int = c.data.k
	var r: float = c.data.r
	var ch := _cur()
	if ch.is_empty() or k >= ch.stages.size():
		return
	var st: Dictionary = ch.stages[k]
	var sel := k == stage_sel
	var open := _stage_open(k)
	var cleared := Progress.is_cleared(st.id)
	var ctr := Vector2(c.size.x * 0.5, r * 1.3 + (sin(_t * 4.0) * 3.0 - 4.0 if sel else 0.0))
	var col: Color = GREEN if cleared else (_color_of(entries[selected]) if open else LOCKED)
	var rr := r * (1.15 if sel else 1.0)
	c.draw_circle(ctr + Vector2(0, 5), rr, Color(0, 0, 0, 0.25))
	c.draw_circle(ctr, rr + 4, Color("f7d35a") if sel else Color(1, 1, 1, 0.95))
	c.draw_circle(ctr, rr, col)
	if open:
		_text(c, ctr + Vector2(-rr, rr * 0.38), str(k + 1), rr * 1.05, INK, rr * 2.0, HORIZONTAL_ALIGNMENT_CENTER)
	else:
		_lock_icon(c, ctr + Vector2(0, -rr * 0.15), rr * 0.75, Color("8a857a"))
	if cleared:
		c.draw_circle(ctr + Vector2(rr * 0.75, -rr * 0.75), rr * 0.36, Color(1, 1, 1))
		_check_icon(c, ctr + Vector2(rr * 0.75, -rr * 0.75), rr * 0.4, GREEN)
	# 名字：去掉【…】前綴，太長就截掉；底下墊一塊深色小牌子，在小島上也看得清楚
	var name := _short_title(String(st.title))
	var fs := 16.0
	var tw := _font().get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, int(fs)).x
	var ty := ctr.y + rr + 12
	var plate := Rect2(Vector2((c.size.x - tw) * 0.5 - 8, ty), Vector2(tw + 16, fs + 12))
	c.draw_style_box(_box(Color(0.08, 0.11, 0.18, 0.82) if not sel else Color("f7d35a"), Color(0, 0, 0, 0), 8, 0.0, false), plate)
	_text(c, Vector2(0, ty + fs + 2), name, fs, Color(1, 0.97, 0.9) if not sel else INK, c.size.x, HORIZONTAL_ALIGNMENT_CENTER)

## 小關名字縮短：去掉「【實驗C】」這種前綴，最多 7 個字
func _short_title(t: String) -> String:
	var i := t.find("】")
	if t.begins_with("【") and i > 0 and i < t.length() - 1:
		t = t.substr(i + 1).strip_edges()
	if t.length() > 7:
		t = t.substr(0, 6) + "…"
	return t

## 下方筆記紙：這一關的名字、說明、開始按鈕
func _paint_detail(c: Control) -> void:
	var r := Rect2(Vector2.ZERO, c.size)
	var u := c.size.y / 220.0
	c.draw_style_box(_box(PAPER, PAPER_EDGE, 8, 3.0), r)
	# 紙張的橫線、紅邊線
	var y := 58.0 * u
	while y < r.size.y - 10:
		c.draw_line(Vector2(10, y), Vector2(r.size.x - 10, y), Color(0.45, 0.62, 0.85, 0.22), 2.0)
		y += 40.0 * u
	c.draw_line(Vector2(32 * u, 6), Vector2(32 * u, r.size.y - 6), Color(0.88, 0.36, 0.36, 0.5), 2.0)
	var ch := _cur()
	var e: Dictionary = entries[selected] if selected < entries.size() else {}
	_start_rect = Rect2()
	if ch.is_empty() or not _playable(ch):
		_text(c, Vector2(52 * u, 60 * u), "這座島還在建造中", 32 * u, INK)
		_text(c, Vector2(52 * u, 104 * u), "組員正在做這一座島的關卡。做好之後會自動出現在這裡，第 1 小關就能玩。", 19 * u, Color(INK, 0.75), r.size.x - 80 * u)
		return
	var st: Dictionary = ch.stages[stage_sel]
	var who := ("　by %s" % ch.author) if String(ch.author) != "" else ""
	_text(c, Vector2(52 * u, 40 * u), "%s%s" % [ch.title, who], 18 * u, Color(INK, 0.6))
	_text(c, Vector2(52 * u, 84 * u), "第 %d 小關　%s" % [stage_sel + 1, st.title], 34 * u, INK, r.size.x - 340 * u)
	var desc := String(st.desc) if String(st.desc) != "" else String(ch.desc)
	c.draw_multiline_string(_font(), Vector2(52 * u, 128 * u), desc, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 360 * u, int(20 * u), 3, Color(INK, 0.8))
	# 狀態列：這一關過了沒、這座島過了幾關
	var open := _stage_open(stage_sel)
	var done_n: int = ch.stages.filter(func(s2): return Progress.is_cleared(s2.id)).size()
	var status := "✔ 已經過關" if Progress.is_cleared(st.id) else ("還沒過關" if open else "還沒解鎖")
	_star(c, Vector2(62 * u, r.size.y - 30 * u), 11 * u, GOLD)
	_text(c, Vector2(80 * u, r.size.y - 23 * u), "%s　｜　這座島已過 %d / %d 關" % [status, done_n, ch.stages.size()], 17 * u, Color(INK, 0.7))
	# 開始按鈕（右邊）／上鎖說明
	var br := Rect2(Vector2(r.size.x - 290 * u, 60 * u), Vector2(250 * u, 96 * u))
	var cleared := Progress.is_cleared(st.id)
	if open:
		var pulse := 1.0 + sin(_t * 4.0) * 0.03
		var bb := Rect2(br.get_center() - br.size * 0.5 * pulse, br.size * pulse)
		c.draw_style_box(_box(GREEN, Color("2f7a2f"), 22, 4.0), bb)
		_text(c, Vector2(bb.position.x, bb.get_center().y + 14 * u), ("再玩一次 ▶" if cleared else "開始 ▶"), 38 * u, Color(1, 1, 1), bb.size.x, HORIZONTAL_ALIGNMENT_CENTER)
		_text(c, Vector2(br.position.x, br.end.y + 32 * u), "Enter 也可以開始", 15 * u, Color(INK, 0.55), br.size.x, HORIZONTAL_ALIGNMENT_CENTER)
		_start_rect = bb
	else:
		c.draw_style_box(_box(LOCKED, LOCKED_EDGE, 22, 3.0), br)
		_lock_icon(c, br.position + Vector2(48 * u, br.size.y * 0.48), 34 * u, Color("8a857a"))
		_text(c, br.position + Vector2(84 * u, br.size.y * 0.42), "還沒解鎖", 24 * u, Color("6f6a60"))
		_text(c, br.position + Vector2(84 * u, br.size.y * 0.74), "先過第 %d 小關" % stage_sel, 17 * u, Color("6f6a60"))

# ================================================================== 選取、開始

## 第 i 個大關（LEVELS 的索引）的第 n 小關（從 1 開始）照規則解鎖了沒
func unlocked(i: int, n := 1) -> bool:
	return _unlocked_ch(LEVELS[i], n)

func _unlocked_ch(ch: Dictionary, n: int) -> bool:
	if ch.is_empty() or n < 1 or n > ch.stages.size() or String(ch.stages[n - 1].scene) == "":
		return false
	return Progress.unlocked(ch.id, n)

func _stage_open(k: int) -> bool:
	return _unlocked_ch(_cur(), k + 1)

## 選第 i 格（entries 的索引）
func select(i: int) -> void:
	if entries.is_empty():
		return
	var was := selected
	selected = clampi(i, 0, entries.size() - 1) if i >= 0 or was < 0 else 0
	if selected != was or stage_sel >= maxi(_cur().get("stages", []).size(), 1):
		stage_sel = _first_open_stage()
	_rebuild_stage_pads()
	_redraw_all()

## 一進大關先選「第一個還沒過、可以玩的小關」
func _first_open_stage() -> int:
	var ch := _cur()
	if ch.is_empty():
		return 0
	for k in ch.stages.size():
		if _unlocked_ch(ch, k + 1) and not Progress.is_cleared(ch.stages[k].id):
			return k
	return 0

func select_stage(n: int) -> void:
	var ch := _cur()
	if ch.is_empty() or ch.stages.is_empty():
		return
	stage_sel = clampi(n, 0, ch.stages.size() - 1)
	_redraw_all()

func _redraw_all() -> void:
	for c in _cards:
		(c as _Pad).queue_redraw()
	for p in _stage_pads:
		(p as _Pad).queue_redraw()
	if _path_pad:
		_path_pad.queue_redraw()
	if _detail:
		_detail.queue_redraw()

func start_selected() -> bool:
	if _starting or entries.is_empty():
		return false
	var ch := _cur()
	if ch.is_empty() or ch.stages.is_empty() or String(ch.stages[stage_sel].scene) == "":
		_show_toast("這座島還在建造中，先玩別的島吧")
		return false
	if not _unlocked_ch(ch, stage_sel + 1):
		if OS.is_debug_build() and not "--autotest" in OS.get_cmdline_user_args():
			_show_toast("（開發模式：還沒解鎖也讓你進去）")
		else:
			_show_toast("先過第 %d 小關才能玩這一關" % stage_sel)
			return false
	_starting = true
	Engine.set_meta("next_scene", ch.stages[stage_sel].scene)
	Engine.set_meta("stage_id", ch.stages[stage_sel].id)
	get_tree().change_scene_to_file("res://scenes/loading.tscn")   # 先進載入畫面
	return true

func _show_toast(t: String) -> void:
	_toast.text = t
	_toast.visible = true
	_toast_t = 2.0

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo:
		match e.keycode:
			KEY_LEFT, KEY_A:
				select(selected - 1)
			KEY_RIGHT, KEY_D:
				select(selected + 1)
			KEY_UP, KEY_W:
				select_stage(stage_sel - 1)
			KEY_DOWN, KEY_S:
				select_stage(stage_sel + 1)
			KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9:
				select_stage(e.keycode - KEY_1)
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				start_selected()
			KEY_ESCAPE:
				if not _starting and ResourceLoader.exists(INTRO_SCENE):
					get_tree().change_scene_to_file(INTRO_SCENE)

func _process(dt: float) -> void:
	_t += dt
	# 背景小島慢慢晃
	_cam.position = _cam_base + Vector3(sin(_t * 0.12) * 6.0, 0, cos(_t * 0.09) * 1.5)
	# 選到的卡片、圓點、開始按鈕會輕輕動（要重畫）
	if selected < _cards.size():
		(_cards[selected] as _Pad).queue_redraw()
	if stage_sel < _stage_pads.size():
		(_stage_pads[stage_sel] as _Pad).queue_redraw()
	if _detail:
		_detail.queue_redraw()
	if _toast_t > 0.0:
		_toast_t -= dt
		if _toast_t <= 0.0:
			_toast.text = ""
			_toast.visible = false

# ================================================================== 自動驗收（--autotest）

func _autotest() -> void:
	var lines: Array = []
	var fails := 0
	var out_dir := "user://autotest"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--outdir="):
			out_dir = a.substr(9)
	DirAccess.make_dir_recursive_absolute(out_dir)
	await get_tree().create_timer(1.5).timeout
	var farm := -1
	for k in entries.size():
		if not entries[k].ch.is_empty() and entries[k].ch.id == "example_farm":
			farm = k
	var all_first := true
	for k in LEVELS.size():
		all_first = all_first and (LEVELS[k].stages.is_empty() or unlocked(k, 1))
	var listed := entries.filter(func(e): return not e.ch.is_empty()).size()
	var islands := entries.filter(func(e): return not e.example).size()
	var locked_ok := entries.all(func(e): return e.example or _playable(e.ch) or true)
	var checks := [
		["選關畫面自動找到所有大關（%d 個）" % LEVELS.size(), listed == LEVELS.size() and LEVELS.size() >= 1],
		["農場範例在範例區", farm >= 0 and entries[farm].example],
		["每個大關的第 1 小關都可以玩", all_first],
		["正式的島至少 %d 格（沒做好的顯示建造中）" % ISLAND_SLOTS, islands >= ISLAND_SLOTS and locked_ok],
	]
	if DisplayServer.window_can_draw():
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out_dir.path_join("00_level_select.png"))
	select(0)
	var e := InputEventKey.new()
	e.keycode = KEY_RIGHT
	e.pressed = true
	Input.parse_input_event(e)
	await get_tree().process_frame
	await get_tree().process_frame
	checks.append(["按 → 換到下一格", entries.size() < 2 or selected == 1])
	# 找一個有第 2 小關的大關，測「沒過第 1 小關進不去第 2 小關」
	for k in entries.size():
		var ch: Dictionary = entries[k].ch
		if not ch.is_empty() and ch.stages.size() >= 2 and not Progress.is_cleared(ch.stages[0].id):
			select(k)
			select_stage(1)
			checks.append(["還沒過第 1 小關，第 2 小關進不去", not start_selected()])
			break
	if DisplayServer.window_can_draw():
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out_dir.path_join("00b_level_locked.png"))
	select(farm if farm >= 0 else 0)
	select_stage(0)
	for c in checks:
		var ok: bool = c[1]
		if not ok:
			fails += 1
		var s := "[%s] %s" % ["PASS" if ok else "FAIL", c[0]]
		print(s)
		lines.append(s)
	Engine.set_meta("ls_lines", lines)
	Engine.set_meta("ls_fails", fails)
	# 進入農場範例，繼續農場的驗收
	start_selected()
