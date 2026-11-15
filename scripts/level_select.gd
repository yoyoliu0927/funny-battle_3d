extends Node3D
## 選關畫面（世界地圖）
##
## 整個畫面是一張 3D 的世界地圖：每個大關是一座大島（WORLD 1、WORLD 2…），每個小關是島上一個主題不同的地標，
## 地標之間用一條畫在島上的路連起來。家豪站在路上的站點，一格一格走過去；走到哪一關，
## 那個地標上面就冒出一張泡泡（關名＋三顆星＋開始），天色和海的顏色也慢慢換成那一關的時段。
##   - 走過的路是金色的、還沒走的是米白色；過關的站點是綠色、插一支金色旗子。
##   - 還沒做好的大關是一座被雲蓋住的島（鎖頭＋？？？）。
##   - 「範例關」（農場範例、範本大關）排在第一個大關前面（南邊、靠鏡頭這一側）：從 WORLD 1 按 ↓ 就飛得到，左上角顯示「範例」。
##
## 大關從 scripts/registry.gd 自動找到（levels/*/chapter.gd、examples/*/chapter.gd），各關不用改這個檔案。
## chapter.gd 可以多寫幾個選用的常數：
##   const ICON := "冰"                                   # （保留）大關的代表字
##   const STARS_SCRIPT := "res://levels/xxx/battle.gd"   # 有 static var best_stars 的腳本（不寫：找大關資料夾裡的 rescue_battle.gd）
##   const MAP_SCRIPT := "res://levels/xxx/map_isles.gd"  # 自己蓋地圖上的大島（不寫：用共用素材蓋預設的草地島，每一小關輪流換地標）
##   const MAP_SKY := "res://levels/xxx/shaders/sky.gdshader"   # 走到這個大關時換用的天空著色器（不寫：共用的天空）
## MAP_SCRIPT 是一個 extends RefCounted 的腳本，裡面的函式都是選用的：
##   func build_island(root: Node3D, ctx: Dictionary) -> void
##       蓋整座大島（世界座標，y = 0 是海面）。ctx = {"center": 島中心 Vector2(x, z), "rx"／"rz": 東西／南北半徑, "top_y": 島面高度,
##       "pads": 每個站點的位置, "spots": 每一小關地標的位置, "index": 第幾排}。路、站點、旗子由這個檔案鋪在島上。
##   func ground_y(x: float, z: float) -> float
##       島面在 (x, z) 的高度（路、站點、家豪貼在上面）。不寫就是平的 TOP_Y。
##   func build_spot(k: int, root: Node3D, ctx: Dictionary) -> void
##       蓋第 k 小關（0 開始）的地標。root 的原點在那個地點的島面上，+z 是站點和鏡頭那一邊，大約 4 公尺見方。
##       地標比較高的話 root.set_meta("bubble_y", 高度)，泡泡就會浮在那個高度上面。
##   func mood(k: int) -> Dictionary
##       走到第 k 小關時的天色，鍵跟 DEFAULT_MOOD 一樣（只寫要改的）；"sky.xxx"／"sea.xxx" 是天空／海著色器的參數。
## 沒有三星紀錄的大關，過關就用打勾表示。
##
## 操作：← → 沿著路走到前一關／下一關、↑ ↓ 換大關、數字鍵直接走到那一關、Enter 開始、Esc 回到開場；
##       V 開關聲音；滑鼠點站點就走過去，點泡泡上的「開始」（或再點一次所在的站點）就開始。
## 音效：全部用程式即時合成（不用音效檔，跟冰雪島關卡同一種做法），音色統一用音樂盒／木琴那種圓圓的鈴聲。
##       右上角的喇叭按鈕（或按 V）開關聲音；關掉的是整個遊戲的聲音（Master），設定存在 user://settings.cfg，下次開遊戲還記得。
## 開發用：命令列加 -- --mapshots=<資料夾>，會把第一個大關的每一小關各截一張圖然後關掉。

const Progress := preload("res://scripts/progress.gd")
const Registry := preload("res://scripts/registry.gd")
const UIStyle := preload("res://scripts/ui/ui_style.gd")   # 全遊戲共用的介面美術
const SeaShader := preload("res://shaders/map_sea.gdshader")
const TEX := "res://assets/textures/"
const INTRO_SCENE := "res://scenes/intro.tscn"

## 正式的「島」一共幾座（四個組員各一座）；不夠的用「建造中」補滿
const ISLAND_SLOTS := 4
## 每個小關幾顆星
const STAR_MAX := 3
const SHAKE_TIME := 0.5

# ---- 地圖的尺寸（公尺）
const STEP := 11.5            # 同一個大關裡，站點和站點的間隔（東西向）
const SPOT_BACK := 5.0        # 地標在站點北邊多遠
const ROW := 48.0             # 大關和大關的間隔（南北向；下一個大關在北邊、畫面上方）
const ISLE_R := 4.6           # 還沒做好的大關那座小島的半徑
const TOP_Y := 1.5            # 島面比海面高多少
const PATH_LIFT := 0.06        # 路面比島面高多少
const WALK_SPEED := 21.0      # 家豪在路上走多快
const JUMP_TIME := 0.75       # 換大關時飛過去要幾秒
const CAM_OFFSET := Vector3(0, 9.5, 19.5)     # 鏡頭壓低：畫面最上面看得到地平線和天空（極光、晚霞）
const CAM_LOOK := Vector3(0, 3.2, -3.5)

## 每座島的主色（站點、旗子）。認得的 id 用固定顏色，其他照順序輪流
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
const PATH_DONE := Color("ffd24a")
const PATH_TODO := Color("fff6dc")
const PATH_EDGE := Color("6b4a2a")

## 預設的天色（大關沒有自己的 MAP_SCRIPT.mood() 就用這個）
const DEFAULT_MOOD := {
	"sun": Color(1.0, 0.90, 0.70), "energy": 1.7, "rot": Vector3(-0.85, 0.7, 0),
	"amb": Color(0.62, 0.74, 0.90), "amb_e": 0.9, "fog": Color(0.74, 0.88, 0.92),
	"sky.top_color": Color(0.30, 0.66, 0.90), "sky.horizon_color": Color(0.80, 0.92, 0.94),
	"sky.cloud_color": Color(0.99, 0.99, 0.96), "sky.cloud_shade": Color(0.76, 0.86, 0.90),
	"sea.deep": Color(0.08, 0.44, 0.68), "sea.near_c": Color(0.20, 0.64, 0.80), "sea.stroke_c": Color(0.74, 0.94, 0.98),
	"sea.foam_c": Color(1, 1, 1), "sea.horizon_c": Color(0.78, 0.91, 0.94),
}
const MOOD_TIME := 0.7        # 換天色要幾秒
const HOP_LEN := 2.6          # 家豪走路時一跳多遠（公尺）
const SETTINGS_PATH := "user://settings.cfg"
const SND_RATE := 22050
const BGM_DB := -15.0         # 背景音樂的音量（比音效小聲很多）

## 預設小島的主題（沒有 MAP_SCRIPT 的大關，每一小關照順序輪流用）：島面的顏色、地標模型、樹
const DEFAULT_THEMES := [
	{"top": Color(0.62, 0.80, 0.36), "cliff": Color(0.80, 0.70, 0.56), "tex": "grass_ground_diff_1k.jpg", "model": "res://assets/farm/Barn.glb", "tree": "res://assets/nature/BirchTree.glb"},
	{"top": Color(0.86, 0.74, 0.38), "cliff": Color(0.74, 0.62, 0.52), "tex": "grass_ground_diff_1k.jpg", "model": "res://assets/farm/Windmill.glb", "tree": "res://assets/nature/AutumnTree.glb"},
	{"top": Color(0.98, 0.90, 0.66), "cliff": Color(0.86, 0.76, 0.60), "tex": "gravelly_sand_diff_1k.jpg", "model": "res://assets/farm/Silo.glb", "tree": "res://assets/nature/BushBerries.glb"},
	{"top": Color(0.46, 0.70, 0.40), "cliff": Color(0.66, 0.66, 0.62), "tex": "grass_ground_diff_1k.jpg", "model": "res://assets/farm/ChickenCoop.glb", "tree": "res://assets/nature/BirchTree.glb"},
	{"top": Color(0.78, 0.62, 0.44), "cliff": Color(0.70, 0.58, 0.50), "tex": "forest_ground_04_diff_1k.jpg", "model": "res://assets/farm/BigBarn.glb", "tree": "res://assets/nature/AutumnTree.glb"},
	{"top": Color(0.70, 0.84, 0.44), "cliff": Color(0.78, 0.72, 0.62), "tex": "grass_ground_diff_1k.jpg", "model": "res://assets/farm/SiloHouse.glb", "tree": "res://assets/nature/BirchTree.glb"},
]

## 大關（照 Registry 排好）
var LEVELS: Array = []
## 地圖上的每一排：{"ch": 大關 Dictionary（或 {}）, "slot": 第幾座島（範例是 -1）, "example": bool}
var entries: Array = []
## 每一排在 3D 裡的東西：{"root", "n", "pads": [Vector3], "isles": [Vector3], "isle_roots": [Node3D], "segs": [PackedVector3Array], "pad_nodes": [Node3D], "hook"}
var worlds: Array = []
var selected := 0            # entries 的第幾排
var stage_sel := 0           # 目前大關裡家豪站在哪個小關（0 開始）
var _cam: Camera3D
var _sun: DirectionalLight3D
var _env: Environment
var _sky_default: ShaderMaterial
var _sky_mats := {}          # 著色器路徑 -> 天空材質（大關自己的天空）
var _sky_mat: ShaderMaterial # 現在用的天空材質
var _sea_mat: ShaderMaterial
var _sea: MeshInstance3D
var _focus := Vector3.ZERO   # 鏡頭看的地方（慢慢跟上家豪）
var _hero: Node3D            # 家豪（外層：位置和朝向）
var _hero_body: Node3D       # 家豪（內層：跳動）
var _walk := {}              # 走路中：{"pts": PackedVector3Array, "d": 已走幾公尺, "len": 全長, "to": 目的地小關}
var _jump := {}              # 換大關飛行中：{"from", "to", "t", "e": 目的地那一排, "k": 小關}
var _queued := 0             # 走路中又按了方向鍵：-1／+1，走到之後接著走
var _bump_t := 0.0           # 被擋住時抖一下還剩幾秒
var _bump_dir := Vector3.ZERO
var _t := 0.0
var _toast: Label
var _toast_t := 0.0
var _starting := false
var _layer: CanvasLayer
var _overlay: _Pad           # 蓋滿畫面的一張透明畫布：站點編號、泡泡、左上角的 WORLD 都畫在這裡
var _start_rect := Rect2()   # 泡泡上「開始」按鈕在畫面上的位置
var _bubble_a := 0.0         # 泡泡現在多不透明（走到了才慢慢出現）
var _shake_t := 0.0          # 鎖頭還要抖多久
var _star_src := {}          # 大關 id -> 星星紀錄表（Dictionary）或 null
var _consts := {}            # 大關 id -> chapter.gd 的常數
var _hooks := {}             # 大關 id -> MAP_SCRIPT 的實體（或 null）
var _mood_from := {}
var _mood_to := {}
var _mood_k := 1.0
var _snd := {}               # 音效名字 -> AudioStreamPlayer
var _snd_rect := Rect2()     # 右上角喇叭按鈕在畫面上的位置
var _snd_pop := 0.0          # 喇叭按鈕剛被按：彈一下還剩幾秒
var _hop_i := 0              # 走路時已經跳了幾下（每落地一次響一聲）
var _flags: Array = []       # 會飄的旗子 {node, phase}
var _clouds: Array = []      # 蓋住未開放小島的雲 {node, base, phase}

# ================================================================== 啟動

func _ready() -> void:
	_load_chapters()
	_cam = get_node("../Camera3D")
	_sun = get_node("../Sun")
	_env = (get_node("../WorldEnvironment") as WorldEnvironment).environment
	_sky_default = _env.sky.sky_material as ShaderMaterial
	_sky_mat = _sky_default
	_build_sea()
	for e in entries.size():
		worlds.append(_build_world(e))
	_build_hero()
	_build_ui()
	_build_audio()
	selected = -1
	select(_first_selection())
	if "--autotest" in OS.get_cmdline_user_args():
		_autotest.call_deferred()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--mapshots="):
			_mapshots.call_deferred(a.substr(11))

## 讀大關清單，排成「範例關＋四座島」：範例關在最前面（地圖的南邊），接著才是 WORLD 1、2、3、4
func _load_chapters() -> void:
	LEVELS = Registry.chapters()
	var islands: Array = LEVELS.filter(func(c): return not _is_example(c))
	var examples: Array = LEVELS.filter(func(c): return _is_example(c))
	entries.clear()
	for c in examples:
		entries.append({"ch": c, "slot": -1, "example": true})
	for k in maxi(ISLAND_SLOTS, islands.size()):
		entries.append({"ch": islands[k] if k < islands.size() else {}, "slot": k, "example": false})

## 範例：examples/ 底下的，或底線開頭的資料夾（_template）
func _is_example(c: Dictionary) -> bool:
	return bool(c.get("example", false)) or String(c.id).begins_with("_")

## 一開始站在哪一排：第一座還沒全破、可以玩的島；都沒有就第一排
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
	return entries[selected].ch if selected >= 0 and selected < entries.size() else {}

func _color_of(e: Dictionary) -> Color:
	var ch: Dictionary = e.ch
	if ch.is_empty() or not _playable(ch):
		return LOCKED
	if CARD_COLORS.has(ch.id):
		return CARD_COLORS[ch.id]
	return CARD_CYCLE[maxi(e.slot, 0) % CARD_CYCLE.size()]

## 開發版（編輯器、命令列執行）不擋路：還沒解鎖的站點也走得過去。自動驗收時照正式規則。
func _dev() -> bool:
	return OS.is_debug_build() and not "--autotest" in OS.get_cmdline_user_args()

# ================================================================== 3D 地圖

## 第 e 排第 k 個站點在地圖上的位置（y 之後再貼到島面上）：一條左右蜿蜒的路
func _pad_xz(e: int, k: int) -> Vector3:
	return Vector3(k * STEP, 0.0, -e * ROW + sin(k * 1.9 + e * 2.3) * 3.5)

## 那一小關的地標放在哪（站點北邊）
func _spot_xz(e: int, k: int) -> Vector3:
	return _pad_xz(e, k) + Vector3(sin(k * 2.7 + e) * 1.2, 0.0, -SPOT_BACK)

## 第 e 排那座大島的範圍和上面的點（交給 MAP_SCRIPT 或預設的蓋法）
func _island_ctx(e: int, n: int) -> Dictionary:
	var pads: Array = []
	var spots: Array = []
	var zmin := INF
	var zmax := -INF
	for k in n:
		pads.append(_pad_xz(e, k))
		spots.append(_spot_xz(e, k))
		zmin = minf(zmin, spots[k].z - 5.0)
		zmax = maxf(zmax, pads[k].z + 5.5)
	var half := (n - 1) * STEP * 0.5
	return {"center": Vector2(half, (zmin + zmax) * 0.5), "rx": half + 9.5, "rz": (zmax - zmin) * 0.5,
		"top_y": TOP_Y, "pads": pads, "spots": spots, "index": e}

## (x, z) 這個位置能不能放裝飾：離路／站點／地標夠遠才行。ctx 是 _island_ctx() 的結果
static func spot_free(ctx: Dictionary, x: float, z: float, room := 2.6) -> bool:
	var p := Vector2(x, z)
	var pads: Array = ctx.pads
	for k in pads.size():
		var a := Vector2(pads[k].x, pads[k].z)
		if p.distance_to(a) < room + 0.6:
			return false
		# 站點正前方（鏡頭那一邊）留空：樹才不會擋住家豪和旗子
		if absf(x - a.x) < 3.4 and z > a.y and z - a.y < 7.0:
			return false
		if k + 1 < pads.size():
			var b := Vector2(pads[k + 1].x, pads[k + 1].z)
			if Geometry2D.get_closest_point_to_segment(p, a, b).distance_to(p) < room:
				return false
		var sp: Vector3 = ctx.spots[k]
		if p.distance_to(Vector2(sp.x, sp.z)) < room + 2.2:
			return false
	return true

func _build_sea() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(900, 900)
	_sea = MeshInstance3D.new()
	_sea.name = "Sea"
	_sea.mesh = plane
	_sea_mat = ShaderMaterial.new()
	_sea_mat.shader = SeaShader
	_sea.material_override = _sea_mat
	_sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_sea)

## 這個大關的 MAP_SCRIPT（沒有就 null）
func _hook(ch: Dictionary) -> Object:
	if ch.is_empty():
		return null
	if not _hooks.has(ch.id):
		var h: Object = null
		var path := String(_chapter_consts(ch).get("MAP_SCRIPT", ""))
		if path != "" and ResourceLoader.exists(path):
			var scr := load(path) as Script
			if scr and scr.can_instantiate():
				h = scr.new()
		_hooks[ch.id] = h
	return _hooks[ch.id]

func _flat_mat(col: Color, unshaded := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.9
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if col.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m

## 沿著一串點鋪一條平平的帶子（路面）
func _strip(pts: PackedVector3Array, width: float, lift: float) -> ArrayMesh:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var idx := PackedInt32Array()
	for i in pts.size():
		var a := pts[maxi(i - 1, 0)]
		var b := pts[mini(i + 1, pts.size() - 1)]
		var dir := (b - a)
		dir.y = 0.0
		dir = dir.normalized()
		var side := Vector3(-dir.z, 0, dir.x) * width * 0.5
		verts.append(pts[i] + Vector3(0, lift, 0) - side)
		verts.append(pts[i] + Vector3(0, lift, 0) + side)
		norms.append(Vector3.UP)
		norms.append(Vector3.UP)
		if i > 0:
			var v := i * 2
			idx.append_array([v - 2, v - 1, v, v - 1, v + 1, v])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return mesh

func _strip_node(parent: Node3D, pts: PackedVector3Array, width: float, lift: float, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = _strip(pts, width, lift)
	if mat is BaseMaterial3D:
		(mat as BaseMaterial3D).cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi

## 蓋第 e 排：一整座大島，島上有每一小關的地標、站點、路、旗子。還沒做好的大關是一座被雲蓋住的小島。
func _build_world(e: int) -> Dictionary:
	var ent: Dictionary = entries[e]
	var ch: Dictionary = ent.ch
	var playable := _playable(ch)
	var n: int = ch.stages.size() if playable else 1
	var root := Node3D.new()
	root.name = "World%d" % e
	add_child(root)
	var hook := _hook(ch) if playable else null
	var col := _color_of(ent)
	var w := {"root": root, "n": n, "pads": [], "isles": [], "isle_roots": [], "segs": [], "pad_nodes": [], "hook": hook}
	var ctx := {}
	if playable:
		ctx = _island_ctx(e, n)
		if hook and hook.has_method("build_island"):
			hook.build_island(root, ctx)
		else:
			_default_island(root, e, ctx)
	# 把一個點貼到島面上
	var on_ground := func(p: Vector3) -> Vector3:
		if not playable:
			return p
		var y := float(hook.ground_y(p.x, p.z)) if hook and hook.has_method("ground_y") else TOP_Y
		return Vector3(p.x, y, p.z)
	for k in n:
		if playable:
			w.pads.append(on_ground.call(ctx.pads[k]))
			w.isles.append(on_ground.call(ctx.spots[k]))
		else:
			w.pads.append(_pad_xz(e, 0))
			w.isles.append(_pad_xz(e, 0) + Vector3(0, 0, -(ISLE_R + 1.7)))
	# 路：一條平滑的曲線穿過所有站點，一段一段鋪在島面上（走過的那一段是金色）
	var edge_mat := _flat_mat(PATH_EDGE, true)
	for k in n - 1:
		var p0: Vector3 = w.pads[maxi(k - 1, 0)]
		var p1: Vector3 = w.pads[k]
		var p2: Vector3 = w.pads[k + 1]
		var p3: Vector3 = w.pads[mini(k + 2, n - 1)]
		var pts := PackedVector3Array()
		for i in 25:
			pts.append(on_ground.call(p1.cubic_interpolate(p2, p0, p3, i / 24.0)))
		w.segs.append(pts)
		var done: bool = Progress.is_cleared(ch.stages[k].id)
		_strip_node(root, pts, 1.5, PATH_LIFT, edge_mat)
		_strip_node(root, pts, 1.05, PATH_LIFT + 0.04, _flat_mat(PATH_DONE if done else PATH_TODO, true))
	for k in n:
		var open: bool = playable and _unlocked_ch(ch, k + 1)
		var cleared: bool = playable and Progress.is_cleared(ch.stages[k].id)
		w.pad_nodes.append(_build_pad(root, w.pads[k], GREEN if cleared else (col if open else LOCKED)))
		if open:
			_build_flag(root, (w.pads[k] as Vector3) + Vector3(1.75, 0, -0.5), GOLD if cleared else col, k * 1.3 + e)
		# 這一小關的地標
		var ir := Node3D.new()
		ir.name = "Spot%d" % k
		ir.position = w.isles[k]
		root.add_child(ir)
		w.isle_roots.append(ir)
		if not playable:
			_mystery_isle(ir, e)
		elif hook and hook.has_method("build_spot"):
			hook.build_spot(k, ir, ctx)
		else:
			_default_spot(ir, e, k)
	return w

## 站點：路上的圓墊（白邊＋主色）
func _build_pad(parent: Node3D, pos: Vector3, col: Color) -> Node3D:
	var node := Node3D.new()
	node.position = pos
	parent.add_child(node)
	for spec in [[1.62, 0.30, PATH_EDGE, 0.0], [1.46, 0.36, Color(1, 1, 1), 0.0], [1.18, 0.42, col, 0.0]]:
		var cyl := CylinderMesh.new()
		cyl.top_radius = spec[0]
		cyl.bottom_radius = float(spec[0]) * 0.94
		cyl.height = spec[1]
		cyl.radial_segments = 40
		var mi := MeshInstance3D.new()
		mi.mesh = cyl
		mi.material_override = _flat_mat(spec[2])
		mi.position.y = float(spec[1]) * 0.5 - 0.12
		node.add_child(mi)
	return node

## 旗子：白色旗桿＋三角旗（過關的是金色）
func _build_flag(parent: Node3D, pos: Vector3, col: Color, phase: float) -> void:
	var node := Node3D.new()
	node.position = pos
	parent.add_child(node)
	var pole := CylinderMesh.new()
	pole.top_radius = 0.06
	pole.bottom_radius = 0.08
	pole.height = 2.6
	var pm := MeshInstance3D.new()
	pm.mesh = pole
	pm.material_override = _flat_mat(Color(0.98, 0.96, 0.9))
	pm.position.y = 1.3
	node.add_child(pm)
	var ball := SphereMesh.new()
	ball.radius = 0.14
	ball.height = 0.28
	var bm := MeshInstance3D.new()
	bm.mesh = ball
	bm.material_override = _flat_mat(GOLD)
	bm.position.y = 2.66
	node.add_child(bm)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(0, 0.55, 0), Vector3(1.15, 0.1, 0), Vector3(0, -0.45, 0)])
	arr[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.BACK, Vector3.BACK, Vector3.BACK])
	var tri := ArrayMesh.new()
	tri.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var fm := _flat_mat(col)
	fm.cull_mode = BaseMaterial3D.CULL_DISABLED
	var flag := MeshInstance3D.new()
	flag.mesh = tri
	flag.material_override = fm
	flag.position = Vector3(0.05, 2.0, 0)
	node.add_child(flag)
	_flags.append({"node": flag, "phase": phase})

# ---------------------------------------------------------------- 預設的小島（共用素材）

static func _grid_indices(cols: int, rows: int) -> PackedInt32Array:
	var idx := PackedInt32Array()
	for si in cols:
		var sj := (si + 1) % cols
		for ri in rows - 1:
			var a := si * rows + ri
			var b := si * rows + ri + 1
			var c := sj * rows + ri + 1
			var d := sj * rows + ri
			idx.append_array([a, b, c, a, c, d])
	return idx

static func _surface(mesh: ArrayMesh, verts: PackedVector3Array, idx: PackedInt32Array) -> void:
	var norms := PackedVector3Array()
	norms.resize(verts.size())
	for i in range(0, idx.size(), 3):
		var a := verts[idx[i]]
		var fn := (verts[idx[i + 2]] - a).cross(verts[idx[i + 1]] - a)
		norms[idx[i]] += fn
		norms[idx[i + 1]] += fn
		norms[idx[i + 2]] += fn
	for i in norms.size():
		norms[i] = norms[i].normalized() if norms[i].length_squared() > 1e-12 else Vector3.UP
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_INDEX] = idx
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)

## 預設大島的輪廓：圓角方形（rx = rz 時是圓的）加一點歪扭。從中心往 a 這個方向到岸邊的距離
static func _outline(rx: float, rz: float, a: float, s: float) -> float:
	var n := 2.0 if is_equal_approx(rx, rz) else 3.0
	var base := pow(pow(absf(cos(a)) / rx, n) + pow(absf(sin(a)) / rz, n), -1.0 / n)
	return base * (1.0 + 0.05 * sin(2.0 * a + s) + 0.04 * sin(3.0 * a + s * 2.1) + 0.03 * sin(5.0 * a + s * 3.3) + 0.015 * sin(9.0 * a + s))

## 預設的島的網格：第 0 面是島面（平的，草皮往外垂一點），第 1 面是岩壁（一層一層往下收，插進海裡）
func _island_mesh(rx: float, rz: float, s: float) -> ArrayMesh:
	var segs := 48 if rx < 8.0 else 120
	var mesh := ArrayMesh.new()
	var top := PackedVector3Array()
	var rings := 6
	for si in segs:
		var a := si * TAU / segs
		var rr := _outline(rx, rz, a, s)
		for ri in rings + 1:
			var t := float(ri) / rings
			top.append(Vector3(cos(a) * rr * t, TOP_Y, sin(a) * rr * t))
		# 草皮的邊：往外一點、往下垂
		var lip := 0.35 + 0.25 * absf(sin(a * 9.0 + s))
		top.append(Vector3(cos(a) * (rr + 0.16), TOP_Y - lip * 0.5, sin(a) * (rr + 0.16)))
		top.append(Vector3(cos(a) * (rr + 0.02), TOP_Y - lip, sin(a) * (rr + 0.02)))
	_surface(mesh, top, _grid_indices(segs, rings + 3))
	var cliff := PackedVector3Array()
	var rows := 6
	for si in segs:
		var a := si * TAU / segs
		var rr := _outline(rx, rz, a, s) - 0.12
		for ri in rows + 1:
			var d := float(ri) / rows
			var bump := 0.22 * sin(a * 17.0 + ri * 2.1 + s) * sin(a * 7.0 - ri * 1.3)
			var q := rr - 0.9 * pow(d, 1.4) + bump * (0.3 + d)
			cliff.append(Vector3(cos(a) * q, lerpf(TOP_Y - 0.2, -1.4, d), sin(a) * q))
	_surface(mesh, cliff, _grid_indices(segs, rows + 1))
	return mesh

func _tex_mat(tex: String, tint: Color, scale := 0.22) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(TEX + tex)
	m.albedo_color = tint
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE * scale
	m.roughness = 1.0
	return m

func _aabb(node: Node, xf: Transform3D) -> AABB:
	var out := AABB()
	var have := false
	if node is Node3D:
		xf = xf * (node as Node3D).transform
	if node is MeshInstance3D and (node as MeshInstance3D).mesh:
		out = xf * (node as MeshInstance3D).mesh.get_aabb()
		have = true
	for c in node.get_children():
		var b := _aabb(c, xf)
		if b.size != Vector3.ZERO:
			out = out.merge(b) if have else b
			have = true
	return out

## 放一個模型：縮放到最長邊 = target 公尺，底部貼在 pos
func _spawn_fit(parent: Node3D, path: String, pos: Vector3, target: float, yaw := 0.0) -> Node3D:
	if not ResourceLoader.exists(path):
		return null
	var ps := load(path) as PackedScene
	if ps == null:
		return null
	var holder := Node3D.new()
	holder.position = pos
	holder.rotation.y = yaw
	parent.add_child(holder)
	var n := ps.instantiate() as Node3D
	holder.add_child(n)
	var bb := _aabb(n, Transform3D.IDENTITY)
	var s := target / maxf(maxf(bb.size.x, bb.size.y), maxf(bb.size.z, 0.001))
	var c := bb.get_center()
	n.transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * s), -Vector3(c.x, bb.position.y, c.z) * s) * n.transform
	return holder

## 預設的大島（沒有 MAP_SCRIPT 的大關）：共用貼圖的草地島，空地上種一些樹
func _default_island(root: Node3D, e: int, ctx: Dictionary) -> void:
	var th: Dictionary = DEFAULT_THEMES[e % DEFAULT_THEMES.size()]
	var c: Vector2 = ctx.center
	var s := 1.0 + e * 0.9
	var mi := MeshInstance3D.new()
	mi.name = "Island"
	mi.mesh = _island_mesh(ctx.rx, ctx.rz, s)
	mi.position = Vector3(c.x, 0, c.y)
	mi.set_surface_override_material(0, _tex_mat(String(th.tex), (th.top as Color) * 1.25))
	mi.set_surface_override_material(1, _tex_mat("lichen_rock_diff_1k.jpg", (th.cliff as Color) * 1.3, 0.18))
	root.add_child(mi)
	var rng := RandomNumberGenerator.new()
	rng.seed = 700 + e
	var placed := 0
	for i in 200:
		if placed >= 8 + int(float(ctx.rx) * 0.5):
			break
		var a := rng.randf() * TAU
		var d := _outline(ctx.rx, ctx.rz, a, s) * sqrt(rng.randf()) - 1.6
		var x := c.x + cos(a) * d
		var z := c.y + sin(a) * d
		if d < 0.0 or not spot_free(ctx, x, z):
			continue
		var tree := String(DEFAULT_THEMES[(e + placed) % DEFAULT_THEMES.size()].tree)
		_spawn_fit(root, tree, Vector3(x, TOP_Y - 0.05, z), rng.randf_range(2.0, 3.2) * (0.4 if tree.contains("Bush") else 1.0), rng.randf() * TAU)
		placed += 1

## 預設的地標（沒有 MAP_SCRIPT 的大關）：每一小關輪流換一個模型（穀倉、風車、筒倉…），旁邊兩三棵樹
func _default_spot(root: Node3D, e: int, k: int) -> void:
	var th: Dictionary = DEFAULT_THEMES[(k + e * 2) % DEFAULT_THEMES.size()]
	_spawn_fit(root, String(th.model), Vector3(0, -0.05, -0.3), 4.2, 0.35)
	var tree := String(th.tree)
	var small := tree.contains("Bush")
	for t in [[2.9, 0.4, 2.4], [-3.0, 0.6, 2.0], [2.4, -2.2, 2.8]]:
		_spawn_fit(root, tree, Vector3(t[0], -0.05, t[1]), float(t[2]) * (0.45 if small else 1.0), t[0] * 2.0)
	root.set_meta("bubble_y", 5.2)

## 還沒做好的大關：一座灰色的小島，被幾團雲蓋住（root 在海面上）
func _mystery_isle(root: Node3D, e: int) -> void:
	var s := 1.0 + e * 0.9
	var mi := MeshInstance3D.new()
	mi.mesh = _island_mesh(ISLE_R, ISLE_R, s)
	mi.set_surface_override_material(0, _tex_mat("grass_ground_diff_1k.jpg", Color(0.80, 0.82, 0.86)))
	mi.set_surface_override_material(1, _tex_mat("lichen_rock_diff_1k.jpg", Color(0.62, 0.64, 0.70), 0.18))
	root.add_child(mi)
	var cm := StandardMaterial3D.new()
	cm.albedo_color = Color(1, 1, 1)
	cm.emission_enabled = true
	cm.emission = Color(0.80, 0.86, 0.94)
	cm.emission_energy_multiplier = 0.55
	cm.roughness = 1.0
	for i in 9:
		var a := i * TAU / 9.0 + s
		var d := 0.0 if i == 0 else (1.6 if i < 4 else 3.4)
		var blob := SphereMesh.new()
		blob.radius = 1.0
		blob.height = 2.0
		blob.radial_segments = 16
		blob.rings = 8
		var b := MeshInstance3D.new()
		b.mesh = blob
		b.material_override = cm
		b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var sc := 2.6 - d * 0.32 + 0.4 * sin(i * 2.3)
		b.scale = Vector3(sc * 1.25, sc * 0.8, sc)
		b.position = Vector3(cos(a) * d, TOP_Y + 1.5 + 0.5 * sin(i * 1.7), sin(a) * d)
		root.add_child(b)
		_clouds.append({"node": b, "base": b.position, "phase": i * 0.9 + e})
	root.set_meta("bubble_y", 5.6)

# ---------------------------------------------------------------- 家豪

func _build_hero() -> void:
	_hero = Node3D.new()
	_hero.name = "Hero"
	add_child(_hero)
	_hero_body = Node3D.new()
	_hero.add_child(_hero_body)
	var chars := Node3D.new()
	chars.set_script(load("res://scripts/characters.gd"))
	chars.set_process(false)
	_hero_body.add_child(chars)
	var chicken: Node3D = chars._make_round_chicken(true)
	chars.add_child(chicken)
	var bb := _aabb(chicken, Transform3D.IDENTITY)
	if bb.size.y > 0.01:
		chars.scale = Vector3.ONE * (1.7 / bb.size.y)
		chars.position.y = -bb.position.y * chars.scale.y

## 家豪站在站點上的位置
func _stand(e: int, k: int) -> Vector3:
	return (worlds[e].pads[k] as Vector3) + Vector3(0, 0.3, 0)

# ================================================================== 音效（程式合成）

## 整個遊戲現在是不是靜音
static func sound_muted() -> bool:
	return AudioServer.is_bus_mute(0)

## 開／關整個遊戲的聲音，並記到設定檔
static func set_sound_muted(on: bool) -> void:
	AudioServer.set_bus_mute(0, on)
	var cf := ConfigFile.new()
	cf.load(SETTINGS_PATH)
	cf.set_value("audio", "muted", on)
	cf.save(SETTINGS_PATH)

func _build_audio() -> void:
	var cf := ConfigFile.new()
	if cf.load(SETTINGS_PATH) == OK:
		AudioServer.set_bus_mute(0, bool(cf.get_value("audio", "muted", false)))
	var streams := {
		"hop": _snd_hop(), "arrive": _snd_arrive(), "bump": _snd_bump(), "fly": _snd_fly(),
		"land": _snd_land(), "start": _snd_start(), "click": _snd_click(), "bgm": _snd_bgm(),
	}
	for id in streams:
		var p := AudioStreamPlayer.new()
		p.stream = streams[id]
		p.volume_db = BGM_DB if id == "bgm" else -4.0
		add_child(p)
		_snd[id] = p
	(_snd["bgm"] as AudioStreamPlayer).play()

## 播一個音效。pitch：音高倍率（走路的每一跳稍微不一樣，才不會像機關槍）
func _play(id: String, pitch := 1.0) -> void:
	var p: AudioStreamPlayer = _snd.get(id)
	if p:
		p.pitch_scale = pitch
		p.play()

## 換場景之後還要繼續響的音效（按下開始）：播放器掛在最上層，播完自己消失
func _play_detached(id: String) -> void:
	var src: AudioStreamPlayer = _snd.get(id)
	if src == null:
		return
	var p := AudioStreamPlayer.new()
	p.stream = src.stream
	p.volume_db = src.volume_db
	get_tree().root.add_child(p)
	p.finished.connect(p.queue_free)
	p.play()

## V／喇叭按鈕：開關聲音（打開的時候響一聲，讓人知道有聲音了）
func _toggle_sound() -> void:
	set_sound_muted(not sound_muted())
	_snd_pop = 0.25
	if not sound_muted():
		_play("click")

static func _snd_wav(s: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(s.size() * 2)
	for i in s.size():
		data.encode_s16(i * 2, int(clampf(s[i], -1.0, 1.0) * 30000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = SND_RATE
	w.stereo = false
	w.data = data
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = s.size()
	return w

static func _snd_buf(sec: float) -> PackedFloat32Array:
	var s := PackedFloat32Array()
	s.resize(int(sec * SND_RATE))
	return s

## 在 buf 的第 at 秒加一顆音樂盒的音（基音＋兩個泛音，敲下去之後慢慢變小）。wrap：超出尾巴的部分繞回開頭（循環音樂用）
static func _bell(buf: PackedFloat32Array, at: float, note: int, dur: float, amp: float, wrap := false) -> void:
	var f := 440.0 * pow(2.0, (note - 69) / 12.0)
	var n := int(dur * SND_RATE)
	var start := int(at * SND_RATE)
	var size := buf.size()
	for j in n:
		var i := start + j
		if i >= size:
			if not wrap:
				break
			i %= size
		var t := float(j) / SND_RATE
		var env := minf(float(j) / 60.0, 1.0) * exp(-t * 5.0 / dur)
		buf[i] += (sin(TAU * f * t) + 0.35 * sin(TAU * f * 2.0 * t) * exp(-t * 6.0) + 0.15 * sin(TAU * f * 4.0 * t) * exp(-t * 12.0)) * env * amp

## 走路的每一跳：很短、往上滑的「啵」
static func _snd_hop() -> AudioStreamWAV:
	var s := _snd_buf(0.07)
	var ph := 0.0
	for i in s.size():
		var k := float(i) / s.size()
		ph += TAU * lerpf(420.0, 760.0, k) / SND_RATE
		s[i] = sin(ph) * sin(k * PI) * 0.32
	return _snd_wav(s)

## 走到站點：往上的兩顆音「叮咚」
static func _snd_arrive() -> AudioStreamWAV:
	var s := _snd_buf(0.6)
	_bell(s, 0.0, 76, 0.35, 0.4)
	_bell(s, 0.09, 81, 0.5, 0.45)
	return _snd_wav(s)

## 被擋住（還沒解鎖、走到盡頭）：兩下悶悶的「咚咚」
static func _snd_bump() -> AudioStreamWAV:
	var s := _snd_buf(0.3)
	for hit in 2:
		var at := int(hit * 0.11 * SND_RATE)
		var ph := 0.0
		for j in int(0.12 * SND_RATE):
			var k := float(j) / (0.12 * SND_RATE)
			ph += TAU * lerpf(190.0, 110.0, k) / SND_RATE
			s[at + j] += sin(ph) * (1.0 - k) * 0.6
	return _snd_wav(s)

## 飛到別的大關：一聲往上再往下的口哨
static func _snd_fly() -> AudioStreamWAV:
	var s := _snd_buf(JUMP_TIME)
	var ph := 0.0
	for i in s.size():
		var k := float(i) / s.size()
		var f := lerpf(500.0, 1500.0, sin(k * PI)) * (1.0 + 0.02 * sin(k * 70.0))
		ph += TAU * f / SND_RATE
		s[i] = sin(ph) * sin(k * PI) * 0.22
	return _snd_wav(s)

## 落地：一下軟軟的「砰」加一顆低音
static func _snd_land() -> AudioStreamWAV:
	var s := _snd_buf(0.5)
	var ph := 0.0
	for j in int(0.16 * SND_RATE):
		var k := float(j) / (0.16 * SND_RATE)
		ph += TAU * lerpf(170.0, 70.0, k) / SND_RATE
		s[j] += sin(ph) * (1.0 - k) * 0.7
	_bell(s, 0.04, 72, 0.4, 0.3)
	return _snd_wav(s)

## 按下開始：往上的四顆音，最後一顆拉長
static func _snd_start() -> AudioStreamWAV:
	var s := _snd_buf(1.1)
	var notes := [72, 76, 79, 84]
	for i in notes.size():
		_bell(s, i * 0.085, notes[i], 0.35 if i < 3 else 0.8, 0.36)
	_bell(s, 0.255, 88, 0.8, 0.16)
	return _snd_wav(s)

## 按鈕：一顆短短的高音
static func _snd_click() -> AudioStreamWAV:
	var s := _snd_buf(0.2)
	_bell(s, 0.0, 84, 0.18, 0.4)
	return _snd_wav(s)

## 背景音樂：音樂盒的四小節循環（C–Am–F–G，9.6 秒），音符的尾巴繞回開頭，所以接起來聽不出接縫
static func _snd_bgm() -> AudioStreamWAV:
	var step := 0.3
	var melody := [76, -1, 79, -1, 84, -1, 79, 76,  81, -1, 76, -1, 72, -1, 76, -1,
		77, -1, 81, -1, 84, -1, 81, 77,  79, -1, 74, -1, 79, 83, 86, -1]
	var bass := [48, 55, 52, 55,  45, 52, 48, 52,  41, 48, 45, 48,  43, 50, 47, 50]
	var s := _snd_buf(melody.size() * step)
	for i in melody.size():
		if melody[i] >= 0:
			_bell(s, i * step, melody[i], 1.1, 0.20, true)
	for i in bass.size():
		_bell(s, i * step * 2.0, bass[i], 0.9, 0.22, true)
	return _snd_wav(s, true)

# ================================================================== 天色

## 第 e 排第 k 小關的天色：DEFAULT_MOOD 加上大關自己的 mood(k)
func _mood_of(e: int, k: int) -> Dictionary:
	var m := DEFAULT_MOOD.duplicate()
	var hook: Object = worlds[e].hook if e < worlds.size() else null
	if hook and hook.has_method("mood"):
		m.merge(hook.mood(k), true)
	return m

## 第 e 排用哪個天空材質（大關有 MAP_SKY 就用它的著色器）
func _sky_of(e: int) -> ShaderMaterial:
	var ch: Dictionary = entries[e].ch
	var path := String(_chapter_consts(ch).get("MAP_SKY", "")) if _playable(ch) else ""
	if path == "" or not ResourceLoader.exists(path):
		return _sky_default
	if not _sky_mats.has(path):
		var m := ShaderMaterial.new()
		m.shader = load(path)
		_sky_mats[path] = m
	return _sky_mats[path]

func _set_mood(e: int, k: int, instant := false) -> void:
	_mood_from = _blend_mood(_mood_k) if not _mood_to.is_empty() else {}
	_mood_to = _mood_of(e, k)
	var sky := _sky_of(e)
	if sky != _sky_mat:
		_sky_mat = sky
		_env.sky.sky_material = sky
	_mood_k = 1.0 if instant or _mood_from.is_empty() else 0.0
	_apply_mood(_blend_mood(_mood_k))

func _blend_mood(k: float) -> Dictionary:
	var e := k * k * (3.0 - 2.0 * k)
	var out := {}
	for key in _mood_to:
		var b = _mood_to[key]
		var a = _mood_from.get(key, b)
		if b is Color and a is Color:
			out[key] = (a as Color).lerp(b, e)
		elif b is Vector3 and a is Vector3:
			out[key] = (a as Vector3).lerp(b, e)
		elif (b is float or b is int) and (a is float or a is int):
			out[key] = lerpf(float(a), float(b), e)
		else:
			out[key] = b
	return out

func _apply_mood(m: Dictionary) -> void:
	_sun.light_color = m.sun
	_sun.light_energy = m.energy
	_sun.rotation = m.rot
	_env.ambient_light_color = m.amb
	_env.ambient_light_energy = m.amb_e
	_env.fog_light_color = m.fog
	for key in m:
		var s := String(key)
		if s.begins_with("sky."):
			_sky_mat.set_shader_parameter(s.substr(4), m[key])
		elif s.begins_with("sea."):
			_sea_mat.set_shader_parameter(s.substr(4), m[key])

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

# ================================================================== 畫圖工具

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

# ================================================================== 介面（畫在 3D 地圖上面）

func _build_ui() -> void:
	_layer = CanvasLayer.new()
	add_child(_layer)
	_overlay = _pad(_layer, _paint_overlay, false)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# 操作說明（只留最少的字）：一張米色小紙片，按鍵畫成鍵帽
	var hint := PanelContainer.new()
	UIStyle.slip(hint, Vector2(16, 6))
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hrow := HBoxContainer.new()
	hrow.add_theme_constant_override("separation", 24)
	hrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.add_child(hrow)
	hrow.add_child(UIStyle.key_hint("←／→", "走", 14))
	hrow.add_child(UIStyle.key_hint("↑／↓", "換島", 14))
	hrow.add_child(UIStyle.key_hint("Enter", "開始", 14))
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
	_toast.offset_top = 150
	_toast.visible = false
	UIStyle.pill(_toast)
	_layer.add_child(_toast)

## 畫面的縮放比例（以 1600×900 為準）
func _u() -> float:
	var vs := get_viewport().get_visible_rect().size
	return minf(vs.x / 1600.0, vs.y / 900.0)

## 這個大關的星星：[拿到幾顆, 一共幾顆, 有沒有三星制度]
func _star_total(ch: Dictionary) -> Array:
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
	return [have, maxn, starred]

func _paint_overlay(c: Control) -> void:
	if worlds.is_empty() or selected < 0:
		return
	var u := _u()
	_paint_nodes(c, u)
	_paint_bubble(c, u)
	_paint_hud(c, u)
	_paint_sound_button(c, u)

## 每個站點上面浮著的編號徽章＋三顆小星（家豪站的那一格不畫，那一格有泡泡）
func _paint_nodes(c: Control, u: float) -> void:
	var busy := _busy()
	for e in entries.size():
		var ent: Dictionary = entries[e]
		var ch: Dictionary = ent.ch
		var playable := _playable(ch)
		var w: Dictionary = worlds[e]
		for k in int(w.n):
			if e == selected and k == stage_sel and not busy:
				continue
			if e != selected and k > 0:
				continue            # 別的大關只標第一個站點（遠遠的一排小徽章很亂）
			var wp: Vector3 = (w.pads[k] as Vector3) + Vector3(0, 1.5, 0)
			if _cam.is_position_behind(wp):
				continue
			var sp := _cam.unproject_position(wp)
			if sp.x < -80 or sp.y < -80 or sp.x > c.size.x + 80 or sp.y > c.size.y + 80:
				continue
			var s := clampf(24.0 / _cam.global_position.distance_to(wp), 0.4, 1.1) * u
			var r := 25.0 * s
			if not playable:
				c.draw_circle(sp + Vector2(0, r * 0.14), r * 1.1, Color(0, 0, 0, 0.22))
				c.draw_circle(sp, r + maxf(r * 0.12, 3.0), Color(1, 1, 1, 0.95))
				c.draw_circle(sp, r, LOCKED)
				_lock_icon(c, sp + Vector2(0, -r * 0.15), r * 0.72, Color("8a857a"))
				continue
			var st: Dictionary = ch.stages[k]
			var open := _unlocked_ch(ch, k + 1)
			var cleared := Progress.is_cleared(st.id)
			if open:
				_num_badge(c, sp, r, k + 1, GREEN if cleared else _color_of(ent))
			else:
				c.draw_circle(sp + Vector2(0, r * 0.14), r * 1.1, Color(0, 0, 0, 0.22))
				c.draw_circle(sp, r + maxf(r * 0.12, 3.0), Color(1, 1, 1, 0.95))
				c.draw_circle(sp, r, LOCKED)
				_lock_icon(c, sp + Vector2(0, -r * 0.15), r * 0.72, Color("8a857a"))
			var stars := _stars(ch, st)
			if stars >= 0 and open:
				var y := sp.y + r + 17.0 * s
				c.draw_style_box(_box(Color(PAPER, 0.96), PAPER_EDGE, 11 * s, 2.0, false), Rect2(Vector2(sp.x - 33 * s, y - 11 * s), Vector2(66 * s, 22 * s)))
				_star_row(c, Vector2(sp.x, y), 7.5 * s, stars)
			elif cleared:
				c.draw_circle(sp + Vector2(r * 0.75, -r * 0.75), r * 0.36, Color(1, 1, 1))
				_check_icon(c, sp + Vector2(r * 0.75, -r * 0.75), r * 0.4, GREEN)

## 家豪所在那一關的泡泡：浮在小島上面，尖角指著小島
func _paint_bubble(c: Control, u: float) -> void:
	_start_rect = Rect2()
	if _bubble_a <= 0.02 or _busy():
		return
	var w: Dictionary = worlds[selected]
	var ir: Node3D = w.isle_roots[stage_sel]
	var wp: Vector3 = (w.isles[stage_sel] as Vector3) + Vector3(0, float(ir.get_meta("bubble_y", 5.0)), 0)
	if _cam.is_position_behind(wp):
		return
	var ent: Dictionary = entries[selected]
	var ch: Dictionary = ent.ch
	var playable := _playable(ch)
	# 冒出來的時候從小放大（尺寸直接乘上去，不用畫布的變形：_lock_icon 會自己改變形）
	u *= 0.6 + 0.4 * (1.0 - pow(1.0 - _bubble_a, 3.0))
	var bw := 400.0 * u
	var bh := 132.0 * u
	var tail := 24.0 * u
	var anchor := _cam.unproject_position(wp)
	anchor.y = maxf(anchor.y, bh + tail + 20.0 * u) + sin(_t * 2.2) * 3.0 * u
	# 泡泡不要跑出畫面：框框往裡面推，尖角還是指著小島
	var vw := get_viewport().get_visible_rect().size.x
	var r := Rect2(Vector2(clampf(anchor.x - bw * 0.5, 16.0 * u, vw - bw - 16.0 * u), anchor.y - bh - tail), Vector2(bw, bh))
	c.draw_style_box(_box(PAPER, PAPER_EDGE, 26 * u, 3.0), r)
	var tx := clampf(anchor.x, r.position.x + 40 * u, r.end.x - 40 * u)
	var ty := anchor.y - tail
	c.draw_colored_polygon(PackedVector2Array([Vector2(tx - 17 * u, ty - 4.0), Vector2(tx + 17 * u, ty - 4.0), Vector2(tx, anchor.y)]), PAPER)
	c.draw_polyline(PackedVector2Array([Vector2(tx - 17 * u, ty - 1.0), Vector2(tx, anchor.y), Vector2(tx + 17 * u, ty - 1.0)]), PAPER_EDGE, 3.0, true)
	var o := r.position
	var bc := o + Vector2(50 * u, 46 * u)
	var text_x := o.x + 92 * u
	if not playable:
		# 還沒做好的大關
		var rot := sin(_shake_t * 42.0) * 0.28 * (_shake_t / SHAKE_TIME) if _shake_t > 0.0 else 0.0
		_lock_icon(c, bc + Vector2(0, 14 * u), 34 * u, Color("8a857a"), rot)
		_text(c, Vector2(text_x, o.y + 60 * u), "？？？", 34 * u, Color("7d776c"))
		_text(c, Vector2(text_x, o.y + 100 * u), "即將開放", 22 * u, Color("7d776c"))
		return
	var st: Dictionary = ch.stages[stage_sel]
	var open := _unlocked_ch(ch, stage_sel + 1)
	var cleared := Progress.is_cleared(st.id)
	var stars := _stars(ch, st)
	var col: Color = GREEN if cleared else (_color_of(ent) if open else LOCKED)
	if open:
		_num_badge(c, bc, 27 * u, stage_sel + 1, col, col.darkened(0.3))
	else:
		c.draw_circle(bc, 31 * u, LOCKED_EDGE)
		c.draw_circle(bc, 27 * u, LOCKED)
		_lock_icon(c, bc + Vector2(0, -5 * u), 21 * u, Color("8a857a"))
	var title := String(st.title)
	var fs := _fit(title, 32 * u, r.end.x - text_x - 20 * u, 16.0)
	_text(c, Vector2(text_x, o.y + 46 * u + fs * 0.36), title, fs, INK)
	var row_y := o.y + 96 * u
	if not open:
		_text(c, Vector2(text_x, row_y + 8 * u), "先過第 %d 關" % stage_sel, 22 * u, Color("6f6a60"))
	else:
		if stars >= 0:
			_star_row(c, Vector2(text_x + 44 * u, row_y), 15 * u, stars)
		elif cleared:
			c.draw_circle(Vector2(text_x + 14 * u, row_y), 13 * u, GREEN)
			_check_icon(c, Vector2(text_x + 14 * u, row_y), 14 * u, Color(1, 1, 1))
		# 開始按鈕（Enter 鍵帽畫在按鈕裡）
		var br := Rect2(Vector2(r.end.x - 176 * u, row_y - 24 * u), Vector2(158 * u, 48 * u))
		var pulse := 1.0 + sin(_t * 4.0) * 0.03
		var bb := Rect2(br.get_center() - br.size * 0.5 * pulse, br.size * pulse)
		c.draw_style_box(_box(GREEN, Color("2f7a2f"), 22 * u, 3.0, false), bb)
		_text(c, Vector2(bb.position.x + 16 * u, bb.get_center().y + 9 * u), "開始", 25 * u, Color(1, 1, 1))
		var ks := UIStyle.keycap_size("Enter", 14 * u)
		UIStyle.draw_keycap(c, Vector2(bb.end.x - 12 * u - ks.x, bb.get_center().y - ks.y * 0.5), "Enter", 14 * u)
		_start_rect = bb

## 左上角：WORLD 幾、大關的名字、總星數
func _paint_hud(c: Control, u: float) -> void:
	var ent: Dictionary = entries[selected]
	var ch: Dictionary = ent.ch
	var f := _font()
	var head := "範例" if ent.example else "WORLD %d" % (int(ent.slot) + 1)
	var pos := Vector2(40 * u, 92 * u)
	var size := int(70 * u)
	c.draw_set_transform(pos, -0.035, Vector2.ONE)
	c.draw_string_outline(f, Vector2(0, 6 * u), head, HORIZONTAL_ALIGNMENT_LEFT, -1, size, int(20 * u), Color(0.20, 0.10, 0.06, 0.35))
	c.draw_string_outline(f, Vector2.ZERO, head, HORIZONTAL_ALIGNMENT_LEFT, -1, size, int(18 * u), Color(1, 1, 1))
	c.draw_string(f, Vector2.ZERO, head, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color("e8483a"))
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var playable := _playable(ch)
	var title := String(ch.title) if playable else "？？？"
	var ts := 30.0 * u
	var tw := f.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, int(ts)).x
	var chip := Rect2(Vector2(44 * u, 116 * u), Vector2(tw + 40 * u, 50 * u))
	c.draw_style_box(_box(PAPER, PAPER_EDGE, 14 * u, 3.0), chip)
	c.draw_rect(Rect2(chip.position + Vector2(5, 5), Vector2(10 * u, chip.size.y - 12)), _color_of(ent))
	_text(c, chip.position + Vector2(26 * u, 36 * u), title, ts, INK)
	if not playable:
		return
	# 總星數「★ 7/18」；沒有三星制度的大關顯示過了幾關
	var tot := _star_total(ch)
	var label := "%d/%d" % [tot[0], tot[1]]
	var lw := f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, int(24 * u)).x
	var sr := Rect2(Vector2(chip.end.x + 12 * u, chip.position.y), Vector2(lw + 62 * u, 50 * u))
	c.draw_style_box(_box(PAPER, PAPER_EDGE, 14 * u, 3.0), sr)
	var ic := sr.position + Vector2(26 * u, 24 * u)
	if tot[2]:
		_star(c, ic, 14 * u, GOLD, Color("8a6410"))
	else:
		c.draw_circle(ic, 13 * u, GREEN)
		_check_icon(c, ic, 14 * u, Color(1, 1, 1))
	_text(c, sr.position + Vector2(48 * u, 34 * u), label, 24 * u, INK)

## 右上角的喇叭按鈕：圓形的米色紙片，喇叭有聲波＝開、打叉＝關；下面掛一顆 V 鍵帽
func _paint_sound_button(c: Control, u: float) -> void:
	var vs := get_viewport().get_visible_rect().size
	var muted := sound_muted()
	var r := 34.0 * u * (1.0 + 0.18 * sin(_snd_pop / 0.25 * PI))
	var ctr := Vector2(vs.x - 62.0 * u, 62.0 * u)
	_snd_rect = Rect2(ctr - Vector2(44, 44) * u, Vector2(88, 88) * u)
	c.draw_circle(ctr + Vector2(2, 5) * u, r + 3.0 * u, Color(0, 0, 0, 0.25))
	c.draw_circle(ctr, r + 3.0 * u, LOCKED_EDGE if muted else PAPER_EDGE)
	c.draw_circle(ctr, r, LOCKED if muted else PAPER)
	var ink := Color("8a857a") if muted else INK
	var k := r / 34.0
	# 喇叭：後面的小方塊＋往前張開的喇叭口
	var o := ctr + Vector2(-7, 0) * k
	c.draw_colored_polygon(PackedVector2Array([o + Vector2(-11, -6) * k, o + Vector2(-3, -6) * k, o + Vector2(7, -15) * k,
		o + Vector2(7, 15) * k, o + Vector2(-3, 6) * k, o + Vector2(-11, 6) * k]), ink)
	if muted:
		var x := ctr + Vector2(13, 0) * k
		c.draw_line(x + Vector2(-6, -6) * k, x + Vector2(6, 6) * k, Color("d9534f"), 4.0 * k, true)
		c.draw_line(x + Vector2(-6, 6) * k, x + Vector2(6, -6) * k, Color("d9534f"), 4.0 * k, true)
	else:
		c.draw_arc(o + Vector2(7, 0) * k, 8.0 * k, -0.9, 0.9, 12, ink, 3.2 * k, true)
		c.draw_arc(o + Vector2(7, 0) * k, 15.0 * k, -0.9, 0.9, 16, ink, 3.2 * k, true)
	var ks := UIStyle.keycap_size("V", 13 * u)
	UIStyle.draw_keycap(c, Vector2(ctr.x - ks.x * 0.5, ctr.y + 34.0 * u + 2.0 * u), "V", 13 * u)

# ================================================================== 選取、移動、開始

## 第 i 個大關（LEVELS 的索引）的第 n 小關（從 1 開始）照規則解鎖了沒
func unlocked(i: int, n := 1) -> bool:
	return _unlocked_ch(LEVELS[i], n)

func _unlocked_ch(ch: Dictionary, n: int) -> bool:
	if ch.is_empty() or n < 1 or n > ch.stages.size() or String(ch.stages[n - 1].scene) == "":
		return false
	return Progress.unlocked(ch.id, n)

func _stage_open(k: int) -> bool:
	return _unlocked_ch(_cur(), k + 1)

func _busy() -> bool:
	return not _walk.is_empty() or not _jump.is_empty()

## 一進大關先站在「第一個還沒過、可以玩的小關」
func _first_open_stage_of(e: int) -> int:
	var ch: Dictionary = entries[e].ch
	if not _playable(ch):
		return 0
	for k in ch.stages.size():
		if _unlocked_ch(ch, k + 1) and not Progress.is_cleared(ch.stages[k].id):
			return k
	return 0

func _first_open_stage() -> int:
	return _first_open_stage_of(selected)

## 直接站到第 i 排（不走路；一進畫面、自動驗收時用）
func select(i: int) -> void:
	if entries.is_empty():
		return
	var was := selected
	selected = clampi(i, 0, entries.size() - 1)
	if selected != was or stage_sel >= int(worlds[selected].n):
		stage_sel = _first_open_stage()
	if not _playable(_cur()):
		_shake_t = SHAKE_TIME            # 還沒做好的島：鎖頭抖一下
	_place_hero()

## 直接站到目前大關的第 n 小關（0 開始；不走路）
func select_stage(n: int) -> void:
	if entries.is_empty():
		return
	stage_sel = clampi(n, 0, int(worlds[selected].n) - 1)
	_place_hero()

func _place_hero() -> void:
	_walk = {}
	_jump = {}
	_queued = 0
	_hero.position = _stand(selected, stage_sel)
	_hero.rotation.y = 0.0
	_hero_body.position = Vector3.ZERO
	_hero_body.rotation = Vector3.ZERO
	var first := _t <= 0.0
	if first:
		_focus = Vector3(_hero.position.x, _hero.position.y - 0.3, _hero.position.z)
		_bubble_a = 1.0
	_set_mood(selected, stage_sel, first)

## 沿著路走到目前大關的第 k 小關（0 開始）。中間有還沒解鎖的站點就停在它前面。
func walk_to(k: int) -> void:
	if _busy() or _starting:
		return
	var w: Dictionary = worlds[selected]
	var d := signi(k - stage_sel)
	if d == 0:
		return
	if k < 0 or k >= int(w.n):
		_bump(Vector3(d, 0, 0))
		return
	var ch := _cur()
	var to := stage_sel
	while to != k:
		if d > 0 and not _dev() and not _unlocked_ch(ch, to + d + 1):
			break
		to += d
	if to == stage_sel:
		_bump(Vector3(d, 0, 0))
		_show_toast("先過第 %d 關" % (stage_sel + 1))
		return
	var pts := PackedVector3Array()
	var j := stage_sel
	while j != to:
		var seg: PackedVector3Array = w.segs[j if d > 0 else j - 1]
		for i in seg.size():
			var p := seg[i if d > 0 else seg.size() - 1 - i]
			if pts.is_empty() or pts[pts.size() - 1].distance_to(p) > 0.001:
				pts.append(p)
		j += d
	var total := 0.0
	for i in pts.size() - 1:
		total += pts[i].distance_to(pts[i + 1])
	_walk = {"pts": pts, "d": 0.0, "len": total, "to": to}
	_hop_i = 0
	_bubble_a = 0.0
	_set_mood(selected, to)

## ↑ ↓：飛到隔壁的大關（↑ 是北邊的下一個大關，↓ 是南邊的上一個；最南邊是範例關）
func _move_world(d: int) -> void:
	if _busy() or _starting:
		return
	var to := selected + d
	if to < 0 or to >= entries.size():
		_bump(Vector3(0, 0, -d))
		return
	_jump_to(to, _first_open_stage_of(to))

func _jump_to(e: int, k: int) -> void:
	if _busy() or _starting:
		return
	_jump = {"from": _hero.position, "to": _stand(e, k), "t": 0.0, "e": e, "k": k}
	_play("fly")
	_bubble_a = 0.0
	_set_mood(e, k)

## 被擋住：往那個方向頂一下再彈回來
func _bump(dir: Vector3) -> void:
	_bump_dir = dir
	_bump_t = 0.25
	_play("bump")

func start_selected() -> bool:
	if _starting or entries.is_empty() or _busy():
		return false
	var ch := _cur()
	if ch.is_empty() or ch.stages.is_empty() or String(ch.stages[stage_sel].scene) == "":
		_shake_t = SHAKE_TIME           # 還沒做好的島：不跳字，鎖頭抖一下就好
		_play("bump")
		return false
	if not _unlocked_ch(ch, stage_sel + 1):
		if _dev():
			_show_toast("（開發模式：還沒解鎖也讓你進去）")
		else:
			_show_toast("先過第 %d 關" % stage_sel)
			_play("bump")
			return false
	_starting = true
	_play_detached("start")
	Engine.set_meta("next_scene", ch.stages[stage_sel].scene)
	Engine.set_meta("stage_id", ch.stages[stage_sel].id)
	get_tree().change_scene_to_file("res://scenes/loading.tscn")   # 先進載入畫面
	return true

func _show_toast(t: String) -> void:
	_toast.text = t
	_toast.visible = true
	_toast_t = 2.0

## 滑鼠點在哪個站點上（找不到回傳 [-1, -1]）
func _node_at(pos: Vector2) -> Array:
	var best := [-1, -1]
	var best_d := 80.0 * _u()
	for e in entries.size():
		var w: Dictionary = worlds[e]
		for k in int(w.n):
			for h in [0.3, 1.5]:
				var wp: Vector3 = (w.pads[k] as Vector3) + Vector3(0, h, 0)
				if _cam.is_position_behind(wp):
					continue
				var d := _cam.unproject_position(wp).distance_to(pos)
				if d < best_d:
					best_d = d
					best = [e, k]
	return best

func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		if _snd_rect.has_point(ev.position):
			_toggle_sound()
			return
		if _start_rect.has_point(ev.position):
			start_selected()
			return
		var hit := _node_at(ev.position)
		if hit[0] < 0:
			return
		if hit[0] == selected and hit[1] == stage_sel:
			start_selected()
		elif hit[0] == selected:
			walk_to(hit[1])
		else:
			var ch: Dictionary = entries[hit[0]].ch
			var k: int = hit[1]
			if _playable(ch) and not _dev() and not _unlocked_ch(ch, k + 1):
				k = _first_open_stage_of(hit[0])
			_jump_to(hit[0], k)
	elif ev is InputEventKey and ev.pressed and not ev.echo:
		match ev.keycode:
			KEY_LEFT, KEY_A:
				_step(-1)
			KEY_RIGHT, KEY_D:
				_step(1)
			KEY_UP, KEY_W:
				_move_world(1)
			KEY_DOWN, KEY_S:
				_move_world(-1)
			KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9:
				walk_to(ev.keycode - KEY_1)
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				start_selected()
			KEY_V:
				_toggle_sound()
			KEY_ESCAPE:
				if not _starting and ResourceLoader.exists(INTRO_SCENE):
					get_tree().change_scene_to_file(INTRO_SCENE)

## ← →：走到前一關／下一關（走路中再按一次：走到之後接著走）
func _step(d: int) -> void:
	if not _walk.is_empty():
		_queued = d
	else:
		walk_to(stage_sel + d)

func _process(dt: float) -> void:
	_t += dt
	_tick_hero(dt)
	# 鏡頭慢慢跟上家豪；海跟著鏡頭走（花紋用世界座標，不會跟著滑）
	var target := Vector3(_hero.position.x, _hero.position.y - 0.3, _hero.position.z)
	_focus = _focus.lerp(target, 1.0 - exp(-dt * 5.5))
	_cam.position = _focus + CAM_OFFSET + Vector3(sin(_t * 0.25) * 0.5, 0, 0)
	_cam.look_at(_focus + CAM_LOOK)
	_sea.position = Vector3(_focus.x, 0, _focus.z)
	if _mood_k < 1.0:
		_mood_k = minf(_mood_k + dt / MOOD_TIME, 1.0)
		_apply_mood(_blend_mood(_mood_k))
	if not _busy():
		_bubble_a = minf(_bubble_a + dt * 4.0, 1.0)
	for fl in _flags:
		(fl.node as Node3D).rotation.y = sin(_t * 2.4 + float(fl.phase)) * 0.35
	for cl in _clouds:
		(cl.node as Node3D).position = (cl.base as Vector3) + Vector3(sin(_t * 0.5 + float(cl.phase)) * 0.25, sin(_t * 0.8 + float(cl.phase)) * 0.15, 0)
	# 家豪站的那個站點輕輕縮放
	for e in worlds.size():
		var pn: Array = worlds[e].pad_nodes
		for k in pn.size():
			var on := e == selected and k == stage_sel and not _busy()
			(pn[k] as Node3D).scale = Vector3.ONE * ((1.06 + sin(_t * 4.0) * 0.04) if on else 1.0)
	if _shake_t > 0.0:
		_shake_t = maxf(_shake_t - dt, 0.0)
	_snd_pop = maxf(_snd_pop - dt, 0.0)
	if _toast_t > 0.0:
		_toast_t -= dt
		if _toast_t <= 0.0:
			_toast.text = ""
			_toast.visible = false
	_overlay.queue_redraw()

## 家豪的動作：走路（一跳一跳）、換大關（飛過去）、原地待機
func _tick_hero(dt: float) -> void:
	if not _walk.is_empty():
		var pts: PackedVector3Array = _walk.pts
		_walk.d = minf(float(_walk.d) + WALK_SPEED * dt, float(_walk.len))
		var left: float = _walk.d
		var pos := pts[pts.size() - 1]
		var dir := Vector3.ZERO
		for i in pts.size() - 1:
			var seg := pts[i].distance_to(pts[i + 1])
			if left <= seg:
				pos = pts[i].lerp(pts[i + 1], left / maxf(seg, 0.0001))
				dir = pts[i + 1] - pts[i]
				break
			left -= seg
		_hero.position = pos + Vector3(0, 0.3, 0)
		if dir.length_squared() > 0.0001:
			_hero.rotation.y = lerp_angle(_hero.rotation.y, atan2(dir.x, dir.z), 1.0 - exp(-dt * 18.0))
		_hero_body.position.y = absf(sin(float(_walk.d) * PI / HOP_LEN)) * 0.7
		# 每落地一次響一聲（音高一高一低）
		var hops := int(float(_walk.d) / HOP_LEN)
		if hops != _hop_i:
			_hop_i = hops
			_play("hop", 1.0 + 0.12 * (hops % 2))
		if float(_walk.d) >= float(_walk.len):
			stage_sel = _walk.to
			_walk = {}
			_hero_body.position.y = 0.0
			_play("arrive")
			if _queued != 0:
				var q := _queued
				_queued = 0
				walk_to(stage_sel + q)
		return
	if not _jump.is_empty():
		_jump.t = minf(float(_jump.t) + dt / JUMP_TIME, 1.0)
		var k: float = _jump.t
		var e := k * k * (3.0 - 2.0 * k)
		var a: Vector3 = _jump.from
		var b: Vector3 = _jump.to
		_hero.position = a.lerp(b, e)
		_hero_body.position.y = sin(k * PI) * 7.0
		_hero_body.rotation.x = e * TAU * signf(a.z - b.z)       # 翻一個筋斗
		_hero.rotation.y = lerp_angle(_hero.rotation.y, atan2(b.x - a.x, b.z - a.z), 1.0 - exp(-dt * 14.0))
		if k >= 1.0:
			selected = _jump.e
			stage_sel = _jump.k
			_jump = {}
			_hero_body.position.y = 0.0
			_hero_body.rotation = Vector3.ZERO
			_play("land")
			if not _playable(_cur()):
				_shake_t = SHAKE_TIME
		return
	# 待機：轉回來面對鏡頭、輕輕彈；被擋住時往那邊頂一下
	_hero.rotation.y = lerp_angle(_hero.rotation.y, 0.0, 1.0 - exp(-dt * 8.0))
	_hero_body.position.y = absf(sin(_t * 3.2)) * 0.08
	var base := _stand(selected, stage_sel)
	if _bump_t > 0.0:
		_bump_t = maxf(_bump_t - dt, 0.0)
		base += _bump_dir * sin(_bump_t / 0.25 * PI) * 0.6
	_hero.position = base

# ================================================================== 開發用：每一關截一張圖（--mapshots=資料夾）

func _snap_view() -> void:
	_focus = Vector3(_hero.position.x, _hero.position.y - 0.3, _hero.position.z)
	_mood_k = 1.0
	_apply_mood(_blend_mood(1.0))
	_bubble_a = 1.0

func _mapshots(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	# 順便檢查合成的音效：長度、最大音量（超過 1 會破音）
	for id in _snd:
		var w := (_snd[id] as AudioStreamPlayer).stream as AudioStreamWAV
		var peak := 0
		for i in range(0, w.data.size(), 2):
			peak = maxi(peak, absi(w.data.decode_s16(i)))
		print("SND %s %.2fs peak=%.2f" % [id, w.get_length(), peak / 30000.0])
	await get_tree().create_timer(0.8).timeout
	for e in entries.size():
		select(e)
		for k in int(worlds[e].n):
			select_stage(k)
			_snap_view()
			await get_tree().create_timer(0.35).timeout
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(dir.path_join("map_w%d_s%d.png" % [e, k + 1]))
	get_tree().quit()

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
	var first_island := -1
	for k in entries.size():
		if not entries[k].example and first_island < 0:
			first_island = k
	var checks := [
		["選關畫面自動找到所有大關（%d 個）" % LEVELS.size(), listed == LEVELS.size() and LEVELS.size() >= 1],
		["農場範例是範例關，排在第一個大關前面", farm >= 0 and entries[farm].example and farm < first_island],
		["一進畫面站在正式的大關（不是範例關）", selected >= first_island],
		["每個大關的第 1 小關都可以玩", all_first],
		["正式的島至少 %d 格（沒做好的上鎖）" % ISLAND_SLOTS, islands >= ISLAND_SLOTS],
	]
	if DisplayServer.window_can_draw():
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out_dir.path_join("00_level_select.png"))
	select(first_island)
	var e := InputEventKey.new()
	e.keycode = KEY_UP
	e.pressed = true
	Input.parse_input_event(e)
	await get_tree().create_timer(JUMP_TIME + 0.4).timeout
	checks.append(["按 ↑ 飛到下一個大關", selected == first_island + 1])
	# 範例關在第一個大關前面：從第一個大關按 ↓ 就到
	select(first_island)
	var dn := InputEventKey.new()
	dn.keycode = KEY_DOWN
	dn.pressed = true
	Input.parse_input_event(dn)
	await get_tree().create_timer(JUMP_TIME + 0.4).timeout
	checks.append(["從第一個大關按 ↓ 飛到範例關", first_island > 0 and selected == first_island - 1 and entries[selected].example])
	# 找一個有第 2 小關的大關：從第 2 小關沿著路走回第 1 小關（往回走永遠可以）
	for k in entries.size():
		if _playable(entries[k].ch) and entries[k].ch.stages.size() >= 2:
			select(k)
			select_stage(1)
			walk_to(0)
			await get_tree().create_timer(1.5).timeout
			checks.append(["沿著路從第 2 小關走回第 1 小關", stage_sel == 0 and not _busy()])
			break
	# 找一個有第 2 小關的大關，測「沒過第 1 小關，走不到也進不去第 2 小關」
	for k in entries.size():
		var ch: Dictionary = entries[k].ch
		if not ch.is_empty() and ch.stages.size() >= 2 and not Progress.is_cleared(ch.stages[0].id):
			select(k)
			select_stage(0)
			walk_to(1)
			checks.append(["還沒過第 1 小關，走不到第 2 小關", _walk.is_empty() and stage_sel == 0])
			select_stage(1)
			checks.append(["還沒過第 1 小關，第 2 小關進不去", not start_selected()])
			break
	# 聲音開關：按 V 切換、再按一次切回來（測完恢復原本的設定）
	var was_muted := sound_muted()
	var v := InputEventKey.new()
	v.keycode = KEY_V
	v.pressed = true
	Input.parse_input_event(v)
	await get_tree().process_frame
	await get_tree().process_frame
	var flipped := sound_muted() != was_muted
	var saved := ConfigFile.new()
	saved.load(SETTINGS_PATH)
	checks.append(["按 V 開關聲音，設定有存檔", flipped and bool(saved.get_value("audio", "muted", was_muted)) == sound_muted()])
	if DisplayServer.window_can_draw():
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out_dir.path_join("00d_sound_toggled.png"))
	set_sound_muted(was_muted)
	checks.append(["音效都合成出來了（%d 個）、背景音樂在播" % _snd.size(), _snd.size() == 8 and (_snd["bgm"] as AudioStreamPlayer).playing])
	if DisplayServer.window_can_draw():
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out_dir.path_join("00b_level_locked.png"))
	# 自動驗收直接用程式選到農場範例
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
