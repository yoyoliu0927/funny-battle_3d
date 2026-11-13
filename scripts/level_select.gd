extends Node3D
## 選關畫面（卡片式）
##
## 參考市面上的選關畫面：
##   - Angry Birds／Cut the Rope：一個大關一張卡片、星星進度；還沒開放的只有一個鎖。
##   - Candy Crush／瑪利歐世界地圖：小關是一條路上的編號圓點，每一關底下三顆星。
##   - Overcooked 的世界地圖：背景是一座可愛的小島，前景的介面一眼就看得懂。
##
## 版面（盡量不用字，留白讓背景小島露出來）：
##   標題緞帶 → 島的卡片（開放的是大卡片：島名＋圓徽章＋總星數「★ 7/9」；還沒做好的是小卡片：鎖頭＋？？？）
##   → 這座島的小關：同一條路上的編號圓點，每個圓點底下三顆小星（名字只寫在下方面板，不重複）
##   → 下方面板：編號徽章＋關名＋三顆星＋綠色「開始」按鈕（Enter 鍵帽畫在按鈕裡）
##   「範例關」（農場範例、範本大關）是開發測試用的：預設收起來，按 F1 才顯示／收起。
##
## 大關從 scripts/registry.gd 自動找到（levels/*/chapter.gd、examples/*/chapter.gd），各關不用改這個檔案。
## chapter.gd 可以多寫兩個選用的常數：
##   const ICON := "冰"                                   # 卡片圓徽章上的字（不寫：冰雪島畫雪花，其他畫旗子）
##   const STARS_SCRIPT := "res://levels/xxx/battle.gd"   # 有 static var best_stars 的腳本（不寫：找大關資料夾裡的 rescue_battle.gd）
##   const MAP_LOOK := "snow"                             # 選到這個大關時背景小島的樣子（MAP_LOOKS 的鍵；不寫：冰雪島是 snow，其他是 green）
## 沒有三星紀錄的大關，過關就用打勾表示。
##
## 操作：← → 選島、↑ ↓ 或數字鍵選小關、Enter 開始、Esc 回到開場、F1 範例關；
##       滑鼠移到卡片／圓點上會選取，點「開始」或再點一次圓點就開始。

const TerrainShader := preload("res://shaders/terrain.gdshader")
const Progress := preload("res://scripts/progress.gd")
const Registry := preload("res://scripts/registry.gd")
const UIStyle := preload("res://scripts/ui/ui_style.gd")   # 全遊戲共用的介面美術
const TEX := "res://assets/textures/"
const INTRO_SCENE := "res://scenes/intro.tscn"

## 正式的「島」一共幾座（四個組員各一座）；不夠的用「建造中」補滿
const ISLAND_SLOTS := 4
## 每個小關幾顆星
const STAR_MAX := 3
const SHAKE_TIME := 0.5

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

## 背景小島和海的配色：選到哪個大關就慢慢換成那個大關的樣子（雪白的島配偏冷的海、綠色的島配暖一點的海）
const MAP_LOOKS := {
	"green": {
		"ground_a": Color(0.58, 0.65, 0.33), "ground_b": Color(0.50, 0.60, 0.29), "grassy": Color(0.44, 0.58, 0.27),
		"sand_c": Color(0.90, 0.80, 0.56), "dirt_c": Color(0.76, 0.66, 0.40), "rock_c": Color(0.66, 0.64, 0.58),
		"deep": Color(0.24, 0.52, 0.60), "light_c": Color(0.55, 0.80, 0.80),
		"tree_a": Color(1, 1, 1), "tree_b": Color(1, 1, 1), "tree_mix": 0.0,
	},
	"snow": {
		"ground_a": Color(0.84, 0.93, 1.0), "ground_b": Color(0.75, 0.88, 1.0), "grassy": Color(0.68, 0.83, 0.98),
		"sand_c": Color(0.66, 0.85, 0.96), "dirt_c": Color(0.80, 0.90, 0.98), "rock_c": Color(0.56, 0.66, 0.80),
		"deep": Color(0.19, 0.43, 0.63), "light_c": Color(0.66, 0.85, 0.96),
		"tree_a": Color(0.92, 0.96, 1.0), "tree_b": Color(0.30, 0.62, 0.56), "tree_mix": 1.0,   # 積雪的樹和露出來的松綠
	},
}
const LOOK_TIME := 0.45        # 換配色要幾秒

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
var _ex_visible := false     # 範例區有沒有打開（F1 切換）
var _shake_t := 0.0          # 鎖頭還要抖多久
var _shake_i := -1           # 哪一張卡片的鎖頭在抖
var _star_src := {}          # 大關 id -> 星星紀錄表（Dictionary）或 null
var _consts := {}            # 大關 id -> chapter.gd 的常數
var _island_mat: ShaderMaterial
var _sea_mat: ShaderMaterial
var _tree_mm: MultiMesh
var _tree_cols: Array[Color] = []   # 樹原本的顏色（綠色的島）
var _look := ""              # 背景現在是哪一種配色
var _look_from := {}
var _look_to := {}
var _look_k := 1.0

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
	_island_mat = mat
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
	_sea_mat = m
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
	_tree_mm = mm
	_tree_cols = cs
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Trees"
	mmi.multimesh = mm
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/forest_crown.gdshader")
	mmi.material_override = m
	add_child(mmi)

## 這個大關的背景配色：chapter.gd 有寫 MAP_LOOK 就用它；沒寫的話冰雪島是雪白的，其他是綠色的。
## 上鎖／還沒做的格子回傳空字串（背景維持原樣）
func _look_of(ch: Dictionary) -> String:
	if ch.is_empty():
		return ""
	var want := String(_chapter_consts(ch).get("MAP_LOOK", "snow" if String(ch.id) == "ice" else "green"))
	return want if MAP_LOOKS.has(want) else "green"

## 把背景換成某一種配色（instant：直接換，不做漸變）
func _set_look(name: String, instant := false) -> void:
	if name == "" or name == _look or not MAP_LOOKS.has(name):
		return
	_look_from = _blend_look(_look_k) if not _look_to.is_empty() else MAP_LOOKS["green"]
	_look_to = MAP_LOOKS[name]
	_look = name
	_look_k = 1.0 if instant else 0.0
	_apply_look(_blend_look(_look_k))

func _blend_look(k: float) -> Dictionary:
	var e := k * k * (3.0 - 2.0 * k)
	var out := {}
	for key in _look_to:
		var a = _look_from.get(key, _look_to[key])
		var b = _look_to[key]
		out[key] = (a as Color).lerp(b, e) if b is Color else lerpf(float(a), float(b), e)
	return out

func _apply_look(l: Dictionary) -> void:
	if _island_mat:
		for key in ["ground_a", "ground_b", "grassy", "sand_c", "dirt_c", "rock_c"]:
			_island_mat.set_shader_parameter(key, l[key])
	if _sea_mat:
		_sea_mat.set_shader_parameter("deep", l.deep)
		_sea_mat.set_shader_parameter("light_c", l.light_c)
	if _tree_mm:
		var mix: float = l.tree_mix
		for i in _tree_cols.size():
			# 五棵裡面三棵積雪、兩棵露出松綠（固定照編號分，不用亂數）
			var snowy: Color = l.tree_a if i % 5 < 3 else l.tree_b
			_tree_mm.set_instance_color(i, _tree_cols[i].lerp(snowy, mix))

# ================================================================== 星星、圖示的資料

## 這個大關 chapter.gd 裡的常數（ICON、STARS_SCRIPT 這類選用的設定）
func _chapter_consts(ch: Dictionary) -> Dictionary:
	if ch.is_empty():
		return {}
	if not _consts.has(ch.id):
		var c := {}
		var path := String(ch.dir).path_join("chapter.gd")
		if ResourceLoader.exists(path):
			var scr := load(path) as Script
			if scr:
				c = scr.get_script_constant_map()
		_consts[ch.id] = c
	return _consts[ch.id]

## 這個大關的星星紀錄表（{關卡場景路徑: {條件 id: true}}）；沒有三星制度的大關回傳 null
## 預設找大關資料夾裡的 rescue_battle.gd 的 static var best_stars；chapter.gd 也可以用 STARS_SCRIPT 指定別的腳本。
## 注意：這張表只在這次開遊戲期間累積，所以重開遊戲後，過關的小關至少算 1 顆（照存檔）。
func _star_table(ch: Dictionary):
	if ch.is_empty():
		return null
	if not _star_src.has(ch.id):
		var table = null
		var path := String(_chapter_consts(ch).get("STARS_SCRIPT", String(ch.dir).path_join("rescue_battle.gd")))
		if ResourceLoader.exists(path):
			var scr = load(path)
			if scr is Script:
				var v = (scr as Script).get("best_stars")
				if v is Dictionary:
					table = v
		_star_src[ch.id] = table
	return _star_src[ch.id]

## 這一小關拿了幾顆星（0～STAR_MAX）；-1 代表這個大關沒有三星制度（只用打勾表示過關）
func _stars(ch: Dictionary, st: Dictionary) -> int:
	var table = _star_table(ch)
	if table == null:
		return -1
	var got = (table as Dictionary).get(String(st.scene), {})
	var n := mini(STAR_MAX, (got as Dictionary).size()) if got is Dictionary else 0
	if n == 0 and Progress.is_cleared(st.id):
		n = 1
	return n

# ================================================================== 介面

## 自己畫的方塊（卡片、圓點、面板都用它）：畫圖交給 painter，滑鼠交給 on_hover／on_click
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
	# 只在最上面壓一層淡淡的漸層（標題看得清楚），其他地方讓背景小島露出來
	var dim := _pad(_layer, _paint_dim, false)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_title = Label.new()
	_title.text = "家豪的起義之路"
	_title.label_settings = UIStyle.ls(40)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_title.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_title.offset_top = 14
	UIStyle.ribbon(_title)
	_layer.add_child(_title)
	# 島的卡片；範例區（預設收起來，F1 才打開）
	_ex_box = _pad(_layer, _paint_ex_box, false)
	for k in entries.size():
		var c := _pad(_layer, _paint_card)
		c.data = {"i": k}
		c.on_hover = func(_p, _e): _hover_entry(k)
		c.on_click = func(_p, _e): select(k)
		_cards.append(c)
	# 小關之間的路（在圓點底下）
	_path_pad = _pad(_layer, _paint_path, false)
	# 下方面板：這一關＋開始按鈕
	_detail = _pad(_layer, _paint_detail)
	_detail.on_click = func(_p, e: InputEventMouseButton):
		if _start_rect.has_point(e.position):
			start_selected()
	# 操作說明（只留最少的字）：一張米色小紙片，按鍵畫成鍵帽
	var hint := PanelContainer.new()
	UIStyle.slip(hint, Vector2(16, 6))
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hrow := HBoxContainer.new()
	hrow.add_theme_constant_override("separation", 24)
	hrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.add_child(hrow)
	hrow.add_child(UIStyle.key_hint("←／→", "島", 14))
	hrow.add_child(UIStyle.key_hint("↑／↓", "關", 14))
	hrow.add_child(UIStyle.key_hint("Esc", "返回", 14))
	_layer.add_child(hint)
	hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hint.offset_bottom = -10
	# 提示字卡
	_toast = Label.new()
	_toast.label_settings = UIStyle.ls(26)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast.offset_top = -60
	_toast.visible = false
	UIStyle.pill(_toast)
	_layer.add_child(_toast)
	get_viewport().size_changed.connect(_layout)
	_layout()

## 依畫面大小排版（以 1600×900 為準，按比例縮放）
func _layout() -> void:
	var vs := get_viewport().get_visible_rect().size
	var u := minf(vs.x / 1600.0, vs.y / 900.0)
	# 上排：開放的島是大卡片（主角），還沒做好的島是小卡片（只有鎖頭）
	var big := Vector2(230.0, 200.0) * u
	var small := Vector2(112.0, 144.0) * u   # 上鎖的卡片小一號、淡一點，讓可以玩的那張更突出
	var gap := 20.0 * u
	var y0 := 112.0 * u
	var total := 0.0
	var n_isl := 0
	for e in entries:
		if not e.example:
			total += (big.x if _playable(e.ch) else small.x) + (gap if n_isl > 0 else 0.0)
			n_isl += 1
	var x := (vs.x - total) * 0.5
	for k in entries.size():
		var e: Dictionary = entries[k]
		if e.example:
			continue
		var c: _Pad = _cards[k]
		var sz := big if _playable(e.ch) else small
		c.position = Vector2(x, y0 + (big.y - sz.y) * 0.5)
		c.size = sz
		c.data.small = false
		x += sz.x + gap
	# 範例區：右下角一個小盒子（預設隱藏）
	var ew := 200.0 * u
	var eh := 66.0 * u
	var n_ex := entries.filter(func(e2): return e2.example).size()
	var box_h := 40.0 * u + n_ex * (eh + 8.0 * u) + 6.0 * u
	var bx := vs.x - ew - 34.0 * u
	var by := vs.y - box_h - 70.0 * u + 40.0 * u
	_ex_box.position = Vector2(bx - 12.0 * u, by - 40.0 * u)
	_ex_box.size = Vector2(ew + 24.0 * u, box_h)
	_ex_box.visible = _ex_visible and n_ex > 0
	var j := 0
	for k in entries.size():
		if entries[k].example:
			var c: _Pad = _cards[k]
			c.position = Vector2(bx, by + j * (eh + 8.0 * u))
			c.size = Vector2(ew, eh)
			c.data.small = true
			c.visible = _ex_visible
			j += 1
	# 下方面板（置中、不佔滿整排）、小關的路（卡片和面板中間，壓在背景小島上，像地圖上的站點）
	var pw := 720.0 * u
	var ph := 150.0 * u
	_detail.position = Vector2((vs.x - pw) * 0.5, vs.y - ph - 64.0 * u)
	_detail.size = Vector2(pw, ph)
	var top := y0 + big.y
	_path_pad.position = Vector2(60.0 * u, top)
	_path_pad.size = Vector2(vs.x - 120.0 * u, _detail.position.y - top)
	_rebuild_stage_pads()
	_redraw_all()

## 目前大關的小關圓點：排在同一條水平的路上
func _rebuild_stage_pads() -> void:
	for p in _stage_pads:
		(p as _Pad).queue_free()
	_stage_pads.clear()
	var ch := _cur()
	var area := Rect2(_path_pad.position, _path_pad.size)
	var n: int = ch.stages.size() if _playable(ch) else 0
	_path_pad.data = {"pts": []}
	_detail.visible = n > 0
	if n == 0:
		_path_pad.queue_redraw()
		return
	var u := minf(get_viewport().get_visible_rect().size.x / 1600.0, get_viewport().get_visible_rect().size.y / 900.0)
	var r := 34.0 * u
	var step := minf(170.0 * u, (area.size.x - 2.0 * r - 40.0 * u) / maxf(n - 1, 1))
	var span := step * (n - 1)
	var sx := area.position.x + (area.size.x - span) * 0.5
	var base_y := area.position.y + area.size.y * 0.5 - 12.0 * u
	var pw := minf(step - 6.0 * u, r * 4.4) if n > 1 else r * 4.4
	var pts: Array = []
	for k in n:
		var cx := sx + k * step
		pts.append(Vector2(cx, base_y))
		var p := _pad(_layer, _paint_stage)
		p.position = Vector2(cx - pw * 0.5, base_y - r * 1.3)
		p.size = Vector2(pw, r * 2.3 + 40.0 * u)
		p.data = {"k": k, "r": r, "u": u}
		p.on_hover = func(_p, _e): _hover_stage(k)
		p.on_click = func(_p, _e):
			if stage_sel == k:
				start_selected()
			else:
				select_stage(k)
		_stage_pads.append(p)
	_path_pad.data = {"pts": pts, "u": u}
	_path_pad.queue_redraw()
	_detail.queue_redraw()

## 滑鼠移到卡片上：開放的島就選它；上鎖的島只抖一下鎖頭（不搶走目前的選擇）
func _hover_entry(k: int) -> void:
	if k == selected:
		return
	if entries[k].example or _playable(entries[k].ch):
		select(k)
	elif _shake_t <= 0.0:
		_shake(k)

func _hover_stage(k: int) -> void:
	if k != stage_sel:
		select_stage(k)

func _shake(k: int) -> void:
	_shake_i = k
	_shake_t = SHAKE_TIME

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

## 字太寬就縮小字級（不截斷）
func _fit(t: String, size: float, w: float, min_size := 11.0) -> float:
	var f := _font()
	while size > min_size and f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, int(size)).x > w:
		size -= 1.0
	return size

func _lock_icon(c: Control, center: Vector2, s: float, col: Color, rot := 0.0) -> void:
	# 大鎖：U 形鎖環＋圓角鎖身＋鑰匙孔（rot 是抖動的角度，以鎖身中心為軸）
	c.draw_set_transform(center + Vector2(0, s * 0.3), rot, Vector2.ONE)
	var o := Vector2(0, -s * 0.3)
	c.draw_arc(o + Vector2(0, -s * 0.15), s * 0.42, PI, TAU, 24, col, s * 0.14, true)
	c.draw_line(o + Vector2(-s * 0.42, -s * 0.15), o + Vector2(-s * 0.42, s * 0.1), col, s * 0.14, true)
	c.draw_line(o + Vector2(s * 0.42, -s * 0.15), o + Vector2(s * 0.42, s * 0.1), col, s * 0.14, true)
	c.draw_style_box(_box(col, col.darkened(0.3), s * 0.12, 2.0, false), Rect2(o + Vector2(-s * 0.62, 0.0), Vector2(s * 1.24, s * 0.9)))
	c.draw_circle(o + Vector2(0, s * 0.36), s * 0.11, Color(0, 0, 0, 0.45))
	c.draw_rect(Rect2(o + Vector2(-s * 0.04, s * 0.38), Vector2(s * 0.08, s * 0.22)), Color(0, 0, 0, 0.45))
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _check_icon(c: Control, center: Vector2, s: float, col: Color) -> void:
	c.draw_polyline(PackedVector2Array([center + Vector2(-s * 0.45, 0), center + Vector2(-s * 0.1, s * 0.35), center + Vector2(s * 0.5, -s * 0.4)]), col, s * 0.2, true)

func _star(c: Control, center: Vector2, r: float, col: Color, edge := Color(0, 0, 0, 0)) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI * 0.5 + i * PI / 5.0
		var rr := r if i % 2 == 0 else r * 0.47
		pts.append(center + Vector2(cos(a), sin(a)) * rr)
	c.draw_colored_polygon(pts, col)
	if edge.a > 0.0:
		pts.append(pts[0])
		c.draw_polyline(pts, edge, maxf(r * 0.16, 1.5), true)

## 三顆星：拿到幾顆亮幾顆（沒拿到的是空心灰星）
func _star_row(c: Control, center: Vector2, r: float, have: int, on_dark := false) -> void:
	var gap := r * 2.5
	for i in STAR_MAX:
		var p := center + Vector2((i - (STAR_MAX - 1) * 0.5) * gap, 0)
		if i < have:
			_star(c, p, r, GOLD, Color("8a6410"))
		else:
			_star(c, p, r, Color(1, 1, 1, 0.35) if on_dark else Color(0, 0, 0, 0.12), Color(1, 1, 1, 0.75) if on_dark else Color(0, 0, 0, 0.3))

## 雪花（冰雪島的圖示）
func _snowflake(c: Control, center: Vector2, r: float, col: Color, w: float) -> void:
	for i in 6:
		var a := i * PI / 3.0 - PI * 0.5
		var d := Vector2(cos(a), sin(a))
		c.draw_line(center, center + d * r, col, w, true)
		for sgn in [-1.0, 1.0]:
			var b: Vector2 = d.rotated(sgn * 0.85)
			c.draw_line(center + d * r * 0.55, center + d * r * 0.55 + b * r * 0.34, col, w, true)
	c.draw_circle(center, w * 0.9, col)

## 預設圖示：小土丘上一支旗子
func _flag_icon(c: Control, center: Vector2, r: float, col: Color, w: float) -> void:
	c.draw_arc(center + Vector2(0, r * 0.95), r * 0.75, PI * 1.15, PI * 1.85, 16, col, w, true)
	c.draw_line(center + Vector2(-r * 0.15, r * 0.3), center + Vector2(-r * 0.15, -r * 0.85), col, w, true)
	c.draw_colored_polygon(PackedVector2Array([center + Vector2(-r * 0.15, -r * 0.85), center + Vector2(r * 0.7, -r * 0.5), center + Vector2(-r * 0.15, -r * 0.15)]), col)

## 島的圓徽章：chapter.gd 有 ICON 常數就用那個字；冰雪島畫雪花；其他畫旗子
func _island_badge(c: Control, ch: Dictionary, center: Vector2, r: float, col: Color) -> void:
	c.draw_circle(center + Vector2(0, r * 0.08), r, col.darkened(0.35))
	c.draw_circle(center, r, col.darkened(0.12))
	c.draw_circle(center, r * 0.86, col.lightened(0.25))
	var glyph := String(_chapter_consts(ch).get("ICON", ""))
	var ink := col.darkened(0.6)
	if glyph != "":
		_text(c, center + Vector2(-r, r * 0.36), glyph.substr(0, 1), r * 1.0, INK, r * 2.0, HORIZONTAL_ALIGNMENT_CENTER)
	elif String(ch.id) == "ice":
		_snowflake(c, center, r * 0.62, ink, r * 0.17)
		_snowflake(c, center, r * 0.62, Color(1, 1, 1), r * 0.09)
	else:
		_flag_icon(c, center, r * 0.6, ink, r * 0.12)

## 圓形數字徽章（小關編號）
func _num_badge(c: Control, center: Vector2, r: float, n: int, col: Color, ring := Color(1, 1, 1, 0.95)) -> void:
	c.draw_circle(center + Vector2(0, r * 0.14), r + r * 0.1, Color(0, 0, 0, 0.22))
	c.draw_circle(center, r + maxf(r * 0.12, 3.0), ring)
	c.draw_circle(center, r, col)
	_text(c, center + Vector2(-r, r * 0.38), str(n), r * 1.05, INK, r * 2.0, HORIZONTAL_ALIGNMENT_CENTER)

func _paint_dim(c: Control) -> void:
	var bands := 14
	var h := c.size.y * 0.3
	for i in bands:
		var a := 0.34 * (1.0 - float(i) / bands)
		c.draw_rect(Rect2(Vector2(0, h * i / bands), Vector2(c.size.x, h / bands + 1.0)), Color(0.05, 0.09, 0.16, a))

func _paint_ex_box(c: Control) -> void:
	c.draw_style_box(_box(Color(PAPER, 0.94), PAPER_EDGE, 12, 2.0), Rect2(Vector2.ZERO, c.size))
	var u := c.size.x / 224.0
	_text(c, Vector2(14 * u, 27 * u), "範例關", 16 * u, INK)
	var ks := UIStyle.keycap_size("F1", 13 * u)
	UIStyle.draw_keycap(c, Vector2(c.size.x - 14 * u - ks.x, 8 * u), "F1", 13 * u)

## 一座島的卡片
func _paint_card(c: Control) -> void:
	var k: int = c.data.i
	var e: Dictionary = entries[k]
	var ch: Dictionary = e.ch
	var sel := k == selected
	var playable := _playable(ch)
	var col := _color_of(e)
	var r := Rect2(Vector2.ZERO, c.size)
	if c.data.get("small", false):
		# 範例區的小卡：一條色帶＋名字＋小關數
		var us := c.size.x / 200.0
		c.draw_style_box(_box(PAPER if playable else LOCKED, Color("f7d35a") if sel else (PAPER_EDGE if playable else LOCKED_EDGE), 10, 4.0 if sel else 2.0), r)
		c.draw_rect(Rect2(r.position + Vector2(4, 4), Vector2(14 * us, r.size.y - 8)), col)
		_text(c, r.position + Vector2(28 * us, 28 * us), String(ch.title), _fit(String(ch.title), 18 * us, r.size.x - 36 * us), INK)
		_text(c, r.position + Vector2(28 * us, 52 * us), "%d 小關" % ch.stages.size(), 14 * us, Color(INK, 0.65))
		return
	if not playable:
		# 還沒做好的島：小小一張，只有鎖頭和「？？？」；選到的時候鎖頭抖一下、多一行「即將開放」
		var us := c.size.x / 140.0
		var rot := 0.0
		if _shake_i == k and _shake_t > 0.0:
			rot = sin(_shake_t * 42.0) * 0.28 * (_shake_t / SHAKE_TIME)
		c.modulate.a = 1.0 if sel else 0.72
		c.draw_style_box(_box(Color(LOCKED, 0.9), Color("f7d35a") if sel else LOCKED_EDGE, 14, 4.0 if sel else 2.0), r)
		_lock_icon(c, Vector2(r.get_center().x, 70 * us), 40 * us, Color("8a857a"), rot)
		_text(c, Vector2(0, 136 * us), "？？？", 22 * us, Color("7d776c"), r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
		if sel:
			_text(c, Vector2(0, 162 * us), "即將開放", 15 * us, Color("7d776c"), r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
		return
	# 開放的島：大卡片＝島名色帶＋圓徽章＋總星數
	var u := c.size.x / 230.0
	var lift := (-6.0 + sin(_t * 3.0) * 2.0) * u if sel else 0.0
	r.position.y += lift
	r.size.y -= 8.0 * u
	c.draw_style_box(_box(PAPER, Color("f7d35a") if sel else PAPER_EDGE, 18, 6.0 if sel else 3.0), r)
	var head := Rect2(r.position + Vector2(6, 6), Vector2(r.size.x - 12, 50 * u))
	var hb := StyleBoxFlat.new()
	hb.bg_color = col
	hb.corner_radius_top_left = int(13 * u)
	hb.corner_radius_top_right = int(13 * u)
	c.draw_style_box(hb, head)
	var title := String(ch.title)
	var fs := _fit(title, 28 * u, head.size.x - 16 * u)
	_text(c, Vector2(head.position.x, head.position.y + head.size.y * 0.5 + fs * 0.36), title, fs, INK, head.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	_island_badge(c, ch, Vector2(r.get_center().x, head.end.y + 50 * u), 38 * u, col)
	# 總星數「★ 7/9」；沒有三星制度的大關顯示過了幾關
	var have := 0
	var maxn := 0
	var starred := _star_table(ch) != null
	for st in ch.stages:
		if starred:
			have += maxi(_stars(ch, st), 0)
			maxn += STAR_MAX
		else:
			have += 1 if Progress.is_cleared(st.id) else 0
			maxn += 1
	var py := r.end.y - 22 * u
	var label := "%d/%d" % [have, maxn]
	var tw := _font().get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, int(22 * u)).x
	var x0 := r.get_center().x - (tw + 34 * u) * 0.5
	if starred:
		_star(c, Vector2(x0 + 12 * u, py - 1 * u), 13 * u, GOLD, Color("8a6410"))
	else:
		c.draw_circle(Vector2(x0 + 12 * u, py - 1 * u), 12 * u, GREEN)
		_check_icon(c, Vector2(x0 + 12 * u, py - 1 * u), 13 * u, Color(1, 1, 1))
	_text(c, Vector2(x0 + 34 * u, py + 7 * u), label, 22 * u, INK)

## 小關之間的路：一條連續的粗線，走過的那一段比較亮
func _paint_path(c: Control) -> void:
	var pts: Array = c.data.get("pts", [])
	if pts.size() < 2:
		return
	var u: float = c.data.get("u", 1.0)
	var ch := _cur()
	var a0: Vector2 = pts[0] - c.position
	var b0: Vector2 = pts[pts.size() - 1] - c.position
	c.draw_line(a0 + Vector2(0, 4 * u), b0 + Vector2(0, 4 * u), Color(0, 0, 0, 0.22), 16 * u, true)
	c.draw_line(a0, b0, Color(INK, 0.55), 16 * u, true)   # 深色描邊：背景是草地或雪地都看得清楚
	c.draw_line(a0, b0, Color(1, 1, 1, 0.95), 11 * u, true)
	for k in range(1, pts.size()):
		if Progress.is_cleared(ch.stages[k - 1].id):
			c.draw_line(pts[k - 1] - c.position, pts[k] - c.position, Color("ffd76a"), 11 * u, true)

## 一個小關：編號圓點＋三顆小星（名字寫在下方面板，這裡不重複）
func _paint_stage(c: Control) -> void:
	var k: int = c.data.k
	var r: float = c.data.r
	var u: float = c.data.u
	var ch := _cur()
	if ch.is_empty() or k >= ch.stages.size():
		return
	var st: Dictionary = ch.stages[k]
	var sel := k == stage_sel
	var open := _stage_open(k)
	var cleared := Progress.is_cleared(st.id)
	var ctr := Vector2(c.size.x * 0.5, r * 1.3)          # 圓心都在同一條基線上
	var col: Color = GREEN if cleared else (_color_of(entries[selected]) if open else LOCKED)
	var rr := r * ((1.14 + sin(_t * 4.0) * 0.03) if sel else 1.0)
	if open:
		_num_badge(c, ctr, rr, k + 1, col, Color("f7d35a") if sel else Color(1, 1, 1, 0.95))
	else:
		c.draw_circle(ctr + Vector2(0, rr * 0.14), rr * 1.1, Color(0, 0, 0, 0.22))
		c.draw_circle(ctr, rr + maxf(rr * 0.12, 3.0), Color("f7d35a") if sel else Color(1, 1, 1, 0.95))
		c.draw_circle(ctr, rr, col)
		_lock_icon(c, ctr + Vector2(0, -rr * 0.15), rr * 0.72, Color("8a857a"))
	# 三顆小星（拿到幾顆亮幾顆）；沒有三星制度的大關：過關就在右上角打勾
	var stars := _stars(ch, st)
	var y := ctr.y + r + 22 * u
	if stars >= 0:
		# 星星墊一小塊米色紙片（背景是雪地時白色的空心星會看不到）
		var chip := Rect2(Vector2(ctr.x - 36 * u, y - 12 * u), Vector2(72 * u, 24 * u))
		c.draw_style_box(_box(Color(PAPER, 0.96), PAPER_EDGE, 12 * u, 2.0, false), chip)
		_star_row(c, Vector2(ctr.x, y), 8.0 * u, stars)
	elif cleared:
		c.draw_circle(ctr + Vector2(rr * 0.75, -rr * 0.75), rr * 0.36, Color(1, 1, 1))
		_check_icon(c, ctr + Vector2(rr * 0.75, -rr * 0.75), rr * 0.4, GREEN)

## 下方面板：編號徽章＋關名＋三顆星＋開始按鈕（Enter 鍵帽畫在按鈕裡）
func _paint_detail(c: Control) -> void:
	_start_rect = Rect2()
	var ch := _cur()
	if not _playable(ch) or stage_sel >= ch.stages.size():
		return
	var r := Rect2(Vector2.ZERO, c.size)
	var u := c.size.y / 150.0
	c.draw_style_box(_box(PAPER, PAPER_EDGE, 16, 3.0), r)
	# 一小段紙膠帶（跟遊戲裡的筆記紙同一套語言）
	c.draw_set_transform(Vector2(34 * u, -9 * u), -0.05, Vector2.ONE)
	c.draw_rect(Rect2(Vector2.ZERO, Vector2(84 * u, 20 * u)), Color(0.95, 0.88, 0.6, 0.8))
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var st: Dictionary = ch.stages[stage_sel]
	var open := _stage_open(stage_sel)
	var cleared := Progress.is_cleared(st.id)
	var stars := _stars(ch, st)
	var col: Color = GREEN if cleared else (_color_of(entries[selected]) if open else LOCKED)
	var bc := Vector2(70 * u, 75 * u)
	if open:
		_num_badge(c, bc, 34 * u, stage_sel + 1, col, col.darkened(0.3))
	else:
		c.draw_circle(bc, 38 * u, LOCKED_EDGE)
		c.draw_circle(bc, 34 * u, LOCKED)
		_lock_icon(c, bc + Vector2(0, -6 * u), 26 * u, Color("8a857a"))
	var tx := 124 * u
	var tw_max := r.size.x - tx - 280 * u
	var title := String(st.title)
	var fs := _fit(title, 36 * u, tw_max, 18.0)
	var has_row := stars >= 0 or cleared
	_text(c, Vector2(tx, (70 * u if has_row else 88 * u)), title, fs, INK)
	if stars >= 0:
		_star_row(c, Vector2(tx + 44 * u, 106 * u), 14 * u, stars)
	elif cleared:
		c.draw_circle(Vector2(tx + 14 * u, 106 * u), 13 * u, GREEN)
		_check_icon(c, Vector2(tx + 14 * u, 106 * u), 14 * u, Color(1, 1, 1))
	# 右邊：開始按鈕／上鎖
	var br := Rect2(Vector2(r.size.x - 262 * u, 30 * u), Vector2(232 * u, 90 * u))
	if open:
		var pulse := 1.0 + sin(_t * 4.0) * 0.025
		var bb := Rect2(br.get_center() - br.size * 0.5 * pulse, br.size * pulse)
		c.draw_style_box(_box(GREEN, Color("2f7a2f"), 24, 4.0), bb)
		var cy := bb.get_center().y
		_text(c, Vector2(bb.position.x + 22 * u, cy + 13 * u), "開始", 36 * u, Color(1, 1, 1))
		var tri := Vector2(bb.position.x + 112 * u, cy)
		c.draw_colored_polygon(PackedVector2Array([tri + Vector2(-8, -13) * u, tri + Vector2(12, 0) * u, tri + Vector2(-8, 13) * u]), Color(1, 1, 1))
		# Enter 鍵帽（全遊戲共用的那一顆）
		var ks := UIStyle.keycap_size("Enter", 17 * u)
		UIStyle.draw_keycap(c, Vector2(bb.end.x - 18 * u - ks.x, cy - ks.y * 0.5), "Enter", 17 * u)
		_start_rect = bb
	else:
		c.draw_style_box(_box(LOCKED, LOCKED_EDGE, 24, 3.0), br)
		_lock_icon(c, br.position + Vector2(46 * u, br.size.y * 0.42), 30 * u, Color("8a857a"))
		_text(c, br.position + Vector2(84 * u, br.size.y * 0.5 + 10 * u), "先過", 26 * u, Color("6f6a60"))
		_num_badge(c, br.position + Vector2(176 * u, br.size.y * 0.5), 20 * u, stage_sel, _color_of(entries[selected]), Color(1, 1, 1, 0.95))

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
	selected = clampi(i, 0, entries.size() - 1)
	if selected != was or stage_sel >= maxi(_cur().get("stages", []).size(), 1):
		stage_sel = _first_open_stage()
	if not _playable(_cur()):
		_shake(selected)            # 上鎖的島：鎖頭抖一下
	else:
		_set_look(_look_of(_cur()), _t <= 0.0)   # 背景的島和海跟著選到的大關換（一進畫面直接是那個樣子）
	_rebuild_stage_pads()
	_redraw_all()

## ← →：在看得到的格子之間移動（範例區收起來時跳過範例）
func _move_entry(d: int) -> void:
	var vis: Array = []
	for k in entries.size():
		if not entries[k].example or _ex_visible:
			vis.append(k)
	if vis.is_empty():
		return
	var at := vis.find(selected)
	select(vis[clampi(at + d, 0, vis.size() - 1)] if at >= 0 else vis[0])

## F1：顯示／收起範例關（開發測試用，玩家平常看不到）
func _toggle_examples() -> void:
	_ex_visible = not _ex_visible
	if not _ex_visible and selected < entries.size() and entries[selected].example:
		select(_first_selection())
	_layout()

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
	if _ex_box:
		_ex_box.queue_redraw()

func start_selected() -> bool:
	if _starting or entries.is_empty():
		return false
	var ch := _cur()
	if ch.is_empty() or ch.stages.is_empty() or String(ch.stages[stage_sel].scene) == "":
		_shake(selected)            # 還沒做好的島：不跳字，鎖頭抖一下就好
		return false
	if not _unlocked_ch(ch, stage_sel + 1):
		if OS.is_debug_build() and not "--autotest" in OS.get_cmdline_user_args():
			_show_toast("（開發模式：還沒解鎖也讓你進去）")
		else:
			_show_toast("先過第 %d 關" % stage_sel)
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
				_move_entry(-1)
			KEY_RIGHT, KEY_D:
				_move_entry(1)
			KEY_UP, KEY_W:
				select_stage(stage_sel - 1)
			KEY_DOWN, KEY_S:
				select_stage(stage_sel + 1)
			KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9:
				select_stage(e.keycode - KEY_1)
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				start_selected()
			KEY_F1:
				_toggle_examples()
			KEY_ESCAPE:
				if not _starting and ResourceLoader.exists(INTRO_SCENE):
					get_tree().change_scene_to_file(INTRO_SCENE)

func _process(dt: float) -> void:
	_t += dt
	# 背景小島慢慢晃
	_cam.position = _cam_base + Vector3(sin(_t * 0.12) * 6.0, 0, cos(_t * 0.09) * 1.5)
	if _look_k < 1.0:
		_look_k = minf(_look_k + dt / LOOK_TIME, 1.0)
		_apply_look(_blend_look(_look_k))
	# 選到的卡片、圓點、開始按鈕會輕輕動；鎖頭抖動中的卡片也要重畫
	if selected < _cards.size():
		(_cards[selected] as _Pad).queue_redraw()
	if stage_sel < _stage_pads.size():
		(_stage_pads[stage_sel] as _Pad).queue_redraw()
	if _detail and _detail.visible:
		_detail.queue_redraw()
	if _shake_t > 0.0:
		_shake_t = maxf(_shake_t - dt, 0.0)
		if _shake_i >= 0 and _shake_i < _cards.size():
			(_cards[_shake_i] as _Pad).queue_redraw()
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
	var ex_hidden := not _ex_visible and entries.all(func(e): return not e.example or not (_cards[entries.find(e)] as Control).visible)
	var checks := [
		["選關畫面自動找到所有大關（%d 個）" % LEVELS.size(), listed == LEVELS.size() and LEVELS.size() >= 1],
		["農場範例在範例區", farm >= 0 and entries[farm].example],
		["範例區預設收起來（F1 才顯示）", ex_hidden],
		["每個大關的第 1 小關都可以玩", all_first],
		["正式的島至少 %d 格（沒做好的上鎖）" % ISLAND_SLOTS, islands >= ISLAND_SLOTS],
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
	# 範例關平常收起來，自動驗收直接用程式選到農場範例
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
