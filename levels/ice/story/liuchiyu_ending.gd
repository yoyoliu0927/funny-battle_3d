extends "res://levels/ice/story/story_kit.gd"
## 霧山楓燃的結尾動畫（第 3 天晚上）。分鏡在 levels/ice/docs/大關開場與結尾動畫.md 第 6 節。
## 第一次破完霧山第 3 關、回到選關地圖時播（選關地圖問 story_registry.gd），播完回地圖。
## 場地借第 3 關「高原」（拿掉戰局和玩家），整段都是晚上。島外那雙巨手跟選關地圖上那一雙同一個畫法（map_isles.gd）。
##
## 這一章沒有「腳牌」那一拍，換成神明的一拍。七拍：
##   收場（豪王倒在湖邊掀開頭盔）→ 號碼（風把菜單吹進火山口燒掉，雷劈開小紅雞的籠子）
##   → 神明（農夫們對著家豪跪下來）→ 靜音拍（青苔小廟前打碟，巨手升起來接住一顆音符）
##   → 羽毛（青、黃、紅三根）→ 上船（小紅雞跳上船，巨手把船推出海）→ 手帳

const STAGE := "res://levels/liuchiyu/stage_3/stage.tscn"
const LA := "res://levels/liuchiyu/assets/"
const KH := LA + "kaykit_halloween/"
const KG := LA + "kenney_graveyard/"
const QV := LA + "quaternius_village/"
const ARMS := LA + "hand/arms_rig.glb"
const BOULDER := LA + "polyhaven/boulder_01/boulder_01.gltf"
const MOSS_ROCKS := LA + "polyhaven/rock_moss_set_01/rock_moss_set_01.gltf"
const FARMER := "res://assets/characters/Farmer.gltf"
const FLAME := "res://levels/ice/assets/blender/flame.glb"
const FLAME_SHADER := "res://levels/ice/shaders/flame.gdshader"
const HAND_SHADER := preload("res://levels/liuchiyu/shaders/map_hand.gdshader")
const CLOUD_SHADER := preload("res://levels/liuchiyu/shaders/oil_cloud.gdshader")
const ROCK_SHADER := preload("res://levels/liuchiyu/shaders/oil_rock.gdshader")
const SEA_Y := -4.5
const RED := Color("e2483a")           # 霧山的羽毛（青冰雪、黃森林、紅霧山）
const FEATHERS := [Color("4fc3d9"), Color("f2d03a"), Color("e2483a")]
const MENU := ["前菜　小紅雞", "主菜　烤雞（六十七號）", "甜點　楓糖"]
## 高原上的擺設（第 3 關的座標 x, z）
const SHRINE := Vector2(-6.0, -9.6)    # 長滿青苔的小廟（正面朝南）
const DJ := Vector2(-6.0, -7.1)        # 家豪在廟前打碟的地方
const OVEN := Vector2(0.8, -6.6)       # 豪王架在廟前的烤爐
const CAGE := Vector2(2.9, -5.6)       # 烤爐旁的小籠子（小紅雞）
const BOARD := Vector2(-9.8, -4.4)     # 菜單看板
const KING := Vector2(4.8, 4.6)        # 豪王倒在湖邊（腳朝湖）
const HERO3 := Vector2(-2.8, -2.0)     # 神明那一拍家豪站的地方
const FARM3 := [Vector2(-5.6, 1.6), Vector2(-3.2, 2.4), Vector2(-0.9, 1.6)]
const KNEEL4 := [Vector2(-9.0, -5.0), Vector2(-7.9, -2.4), Vector2(-3.1, -5.0)]
const COAST_X := -2.0                  # 上船的北岸
const HAND_S := 80.0                   # 靜音拍升起來的那雙手放大幾倍
const PUSH_S := 14.0                   # 推船的那隻手（從海裡伸出來，一隻手推船尾）
const KING_H := 3.25                   # 豪王多高（農夫的 1.25 倍）

func _lines() -> Array:
	return [
		{"shot": "king", "hold": 2.7, "cue": "k_down", "fade_in": 1.0},
		{"shot": "king", "who": "豪王", "text": "……不通風真的很熱。", "cue": "k_hot"},
		{"shot": "wind", "hold": 2.5, "cue": "r_wind", "fade_out": 0.3, "fade_in": 0.35},
		{"shot": "burn", "hold": 3.1, "cue": "r_burn", "fade_out": 0.25, "fade_in": 0.3},
		{"shot": "cage", "hold": 2.3, "cue": "r_bolt", "fade_out": 0.3, "fade_in": 0.4},
		{"shot": "cage", "who": "神明", "text": "我不能碰人。籠子可以。", "cue": "r_free"},
		{"shot": "farm", "hold": 3.0, "cue": "f_kneel", "fade_out": 0.3, "fade_in": 0.4},
		{"shot": "farm", "who": "農夫", "text": "剛剛那是……神蹟？是那隻雞叫來的！", "cue": "f_miracle"},
		{"shot": "farm", "who": "神明", "text": "……拜錯了。", "cue": "f_wrong", "snap": 1.4},
		{"shot": "dj", "hold": 8.2, "cue": "d_silence", "fade_out": 0.6, "fade_in": 0.9},
		{"shot": "dj", "who": "家豪", "text": "今天放的是……算了。", "cue": "d_line", "snap": 2.0},
		{"shot": "dj", "who": "神明", "text": "……好久沒人在這裡放歌了。", "cue": "d_god", "snap": 2.2},
		{"shot": "hood", "hold": 2.0, "cue": "w_gust", "fade_out": 0.3, "fade_in": 0.4},
		{"shot": "hood", "who": "神明", "text": "顏色還不一樣。", "cue": "w_god"},
		{"shot": "hood", "who": "家豪", "text": "……換毛啦。", "cue": "w_no", "snap": 1.4},
		{"shot": "leave", "hold": 5.3, "cue": "l_leave", "fade_out": 0.5, "fade_in": 0.8},
		{"shot": "journal", "hold": 5.8, "cue": "j_page", "fade_out": 0.5, "fade_in": 0.7},
	]

func _skip_text() -> String:
	return "跳過"

func _voice_pitch(who: String) -> float:
	match who:
		"豪王": return 0.6
		"農夫": return 0.92
	return super(who)

var _world
var _water := 14.7                   # 湖面
var _crater := Vector3(-19.5, 27.6, 11.0)
var _c_edge := -31.3                 # 北岸崖頂的 z
var _c_foot := -35.0                 # 北岸崖腳的 z
var _c_h := 0.7                      # 北岸低地的高度
var _king: Dictionary = {}           # {node, set, helm, steam}
var _farmers: Array = []             # {node, sk, ap, bones, base, kneel, bow, sway, ph, knee}
var _chick: Dictionary = {}
var _board: Node3D
var _board_mats: Array = []          # 看板燒焦時要變黑的材質
var _flames: Array = []
var _cage: Node3D
var _door: Node3D
var _lock: Node3D
var _oven_fire: Node3D
var _hands: Dictionary = {}          # {node, tilt, mat, ap, sk}
var _hand_y := 8.0
var _rise := 0.0
var _storm: Node3D
var _bolt: MeshInstance3D
var _bolt_mat: StandardMaterial3D
var _leaves: CPUParticles3D
var _sparks: CPUParticles3D
var _boat: Node3D
var _leave_on := false
var _push_on := false
var _track := false                  # 鏡頭一直盯著飛走的看板
var _push_at := Vector3.ZERO         # 手掌推的那個點（船尾）
var _big_note: Label3D               # 飛向巨手的那一顆音符
var _note_from := Vector3.ZERO
var _note_t := -1.0
var _note_dur := 2.4
var _held := false                   # 音符已經在手心裡了
var _dip := 0.0                      # 接住音符的時候手往下沉多少
var _journal_p: Control

## 地面上的點（崖邊用島自己算的岩階高度，跟畫面上的岩壁一致）
func G(x: float, z: float) -> Vector3:
	return Vector3(x, _gy(x, z), z)

func G2(p: Vector2) -> Vector3:
	return G(p.x, p.y)

func _gy(x: float, z: float) -> float:
	if _world.has_method("_gy"):
		return float(_world._gy(x, z))
	return float(_world.height_at(x, z))

func _story_build() -> void:
	mark_seen("liuchiyu_ending")
	var stage := _borrow_stage(STAGE)
	_world = stage.get_node("World")
	# 天上那三行「Chapter」字、場上的星星是關卡自己的東西：過場不要
	var signs = _world.get("_signs")
	if signs is Array:
		for sg in signs:
			if sg.root is Node3D:
				(sg.root as Node3D).visible = false
	var stars = _world.get("_star_nodes")
	if stars is Dictionary:
		for sn in (stars as Dictionary).values():
			if sn is Node3D:
				(sn as Node3D).visible = false
	# 高原・夜
	if _world.get("night") != null:
		_world.night = true
		_world._apply_time()
	if _world.has_method("volcano_set"):
		_world.volcano_set(1.0)
	if _world.has_method("volcano_top"):
		_crater = _world.volcano_top()
	_water = _gy(10.5, 5.05) + 0.24
	_find_coast()
	_make_hero(self, FEATHERS)
	_boat = _make_boat()
	_build_shrine()
	_build_oven()
	_build_cage()
	_board = _menu_board(self)
	_board.position = G2(BOARD)
	_board.rotation.y = 0.5
	_build_lava_path()
	_make_king()
	for p in FARM3:
		_farmers.append(_farmer(G2(p), 0.0))
	_make_chick()
	_hands = _god_hands()
	_build_fx()
	_make_story_sounds()

## 北岸：從高原北邊往北走，找低地的崖頂和崖腳（上船的地方）
func _find_coast() -> void:
	var top := false
	_c_h = _gy(COAST_X, -28.0)
	for i in 200:
		var z := -27.0 - i * 0.1
		var y := _gy(COAST_X, z)
		if not top and y < _c_h - 0.6:
			_c_edge = z + 0.4
			top = true
		if top and y < SEA_Y - 0.8:
			_c_foot = z
			break

# ================================================================== 佈景

## 長滿青苔的小廟：石頭台座、四根舊木柱、圓瓦屋頂、垂下來的藤蔓；裡面一尊斷了一隻手的神像
func _build_shrine() -> void:
	var root := Node3D.new()
	root.name = "Shrine"
	add_child(root)
	root.position = G2(SHRINE)
	var moss := ShaderMaterial.new()
	moss.shader = ROCK_SHADER
	moss.set_shader_parameter("leaf_a", Color(0.30, 0.46, 0.20))
	moss.set_shader_parameter("leaf_b", Color(0.46, 0.62, 0.28))
	moss.set_shader_parameter("night_leaf_a", Color(0.28, 0.48, 0.36))
	moss.set_shader_parameter("night_leaf_b", Color(0.44, 0.66, 0.48))
	moss.set_shader_parameter("night", 1.0)
	var wood := _tex_mat(LA + "polyhaven/weathered_brown_planks_diff_1k.jpg", 1.0, Color(0.55, 0.50, 0.46))
	var green := _toon(Color(0.36, 0.56, 0.26))
	# 台座和台階
	_box(root, Vector3(3.6, 0.5, 3.0), Vector3(0, 0.2, 0), moss)
	_box(root, Vector3(1.8, 0.24, 0.6), Vector3(0, 0.08, 1.75), moss)
	# 四根柱子、屋頂
	for x in [-1.25, 1.25]:
		for z in [-1.0, 1.0]:
			var post := _glb(root, QV + "Corner_Exterior_Wood.gltf", Vector3(x, 0.44, z), 0.0, 1.0)
			if post:
				post.scale = Vector3(1.1, 0.78, 1.1)
				_paint(post, wood)
	var roof := _glb(root, QV + "Roof_RoundTiles_4x4.gltf", Vector3(0, 0.44 + 2.34 + 0.29, 0), 0.0, 0.56)
	_no_shadow(roof)
	# 屋簷垂下來的藤蔓（青苔）
	var v1 := _glb(root, QV + "Prop_Vine1.gltf", Vector3(-0.85, 3.0, 1.45), 0.0, 0.62)
	var v2 := _glb(root, QV + "Prop_Vine2.gltf", Vector3(0.9, 3.0, 1.45), 0.0, 0.55)
	var v3 := _glb(root, QV + "Prop_Vine1.gltf", Vector3(1.5, 2.9, 0.2), PI * 0.5, 0.5)
	for v in [v1, v2, v3]:
		_no_shadow(v)
	# 台座邊上長青苔的石頭
	for r in [[Vector3(-2.2, 0, 0.9), 1.3, 0.4], [Vector3(2.1, 0, -0.6), 1.1, 2.0], [Vector3(-1.9, 0, -1.6), 0.9, 1.1]]:
		var rk := _glb(root, MOSS_ROCKS, r[0], float(r[2]), 1.0)
		if rk:
			_fit(rk, float(r[1]))
	# 神像：坐著，右手往前伸、手心朝上；左手斷了，斷掉的手掌掉在腳邊
	var st := Node3D.new()
	st.position = Vector3(0, 0.44, -0.55)
	root.add_child(st)
	_box(st, Vector3(1.0, 0.46, 0.8), Vector3(0, 0.23, 0), moss)
	_cyl(st, 0.24, 0.36, 0.86, Vector3(0, 0.89, 0), moss, Vector3.ZERO, 12)
	_ball(st, 0.2, Vector3(0, 1.5, 0.02), moss, Vector3(1.0, 1.08, 1.0), 12)
	_cyl(st, 0.05, 0.11, 0.16, Vector3(0, 1.74, 0), moss, Vector3.ZERO, 8)       # 頭上的髻
	_ball(st, 0.11, Vector3(0.28, 1.22, 0.0), moss, Vector3.ONE, 8)               # 右肩
	_cyl(st, 0.07, 0.08, 0.5, Vector3(0.31, 1.05, 0.2), moss, Vector3(1.15, 0, 0), 8)   # 右手臂往前伸
	_ball(st, 0.1, Vector3(0.31, 0.96, 0.44), moss, Vector3(1.0, 0.45, 1.25), 8)  # 手心朝上
	_ball(st, 0.11, Vector3(-0.28, 1.22, 0.0), moss, Vector3.ONE, 8)              # 左肩
	_cyl(st, 0.07, 0.08, 0.18, Vector3(-0.31, 1.11, 0.06), moss, Vector3(0.5, 0, 0), 8)  # 左手只剩一截
	_ball(st, 0.1, Vector3(-0.62, 0.5, 0.5), moss, Vector3(1.0, 0.45, 1.25), 8)   # 斷掉的手掌掉在台座上
	_cyl(st, 0.06, 0.07, 0.18, Vector3(-0.72, 0.5, 0.36), moss, Vector3(PI * 0.5, 0.6, 0), 8)
	for g in [[Vector3(0.05, 1.68, 0.06), 0.09], [Vector3(-0.22, 1.3, 0.12), 0.07], [Vector3(0.3, 1.3, -0.08), 0.06], [Vector3(-0.3, 0.5, 0.36), 0.12]]:
		_ball(st, float(g[1]), g[0], green, Vector3(1.4, 0.5, 1.4), 8)           # 一塊一塊的青苔

## 烤爐：大火盆上架一支烤雞用的鐵叉
func _build_oven() -> void:
	var root := Node3D.new()
	add_child(root)
	root.position = G2(OVEN)
	root.rotation.y = 0.25
	# 一圈石頭圍著火
	var rock := ShaderMaterial.new()
	rock.shader = ROCK_SHADER
	rock.set_shader_parameter("night", 1.0)
	for k in 7:
		var a := TAU * float(k) / 7.0
		var b := _glb(root, BOULDER, Vector3(cos(a) * 0.95, -0.05, sin(a) * 0.75), a * 2.0, 1.0)
		if b:
			b.scale = Vector3(0.55, 0.42, 0.5)
			_paint(b, rock)
			_no_shadow(b)
	_cyl(root, 0.7, 0.8, 0.12, Vector3(0, 0.04, 0), _toon(Color(0.10, 0.07, 0.06)), Vector3.ZERO, 14)   # 燒黑的炭
	var wood := _tex_mat(LA + "polyhaven/weathered_brown_planks_diff_1k.jpg", 1.0, Color(0.7, 0.6, 0.5))
	var iron := _iron()
	for x in [-1.25, 1.25]:
		_box(root, Vector3(0.12, 1.9, 0.12), Vector3(x, 0.95, 0), wood)
		_box(root, Vector3(0.1, 0.5, 0.1), Vector3(x - 0.12, 1.9, 0), wood, Vector3(0, 0, 0.5))
		_box(root, Vector3(0.1, 0.5, 0.1), Vector3(x + 0.12, 1.9, 0), wood, Vector3(0, 0, -0.5))
	_cyl(root, 0.035, 0.035, 2.9, Vector3(0, 1.82, 0), iron, Vector3(0, 0, PI * 0.5), 8)
	_oven_fire = _flame(root, Vector3(0, 0.08, 0), 1.25)

## 小紅雞的籠子：圓圓的鳥籠，正面一扇小門，門上一顆金色的鎖
func _build_cage() -> void:
	_cage = Node3D.new()
	add_child(_cage)
	_cage.position = G2(CAGE)
	_cage.rotation.y = 0.35
	var iron := _iron()
	var gold := _toon(Color(0.95, 0.72, 0.22))
	var r := 0.66
	var hh := 1.25                      # 籠子多高（到圓頂的底）
	_cyl(_cage, r + 0.04, r + 0.06, 0.1, Vector3(0, 0.05, 0), iron, Vector3.ZERO, 20)
	_cyl(_cage, r + 0.02, r + 0.02, 0.06, Vector3(0, hh, 0), iron, Vector3.ZERO, 20)
	_ball(_cage, r, Vector3(0, hh + 0.02, 0), iron, Vector3(1.0, 0.42, 1.0), 14)
	_torus(_cage, 0.07, 0.11, Vector3(0, hh + 0.36, 0), iron, Vector3(PI * 0.5, 0, 0))
	var n := 16
	for k in n:
		var a := TAU * float(k) / n
		if absf(wrapf(a - PI * 0.5, -PI, PI)) < 0.45:
			continue                    # 正面（+Z）那幾根是門
		_cyl(_cage, 0.018, 0.018, hh - 0.08, Vector3(cos(a) * r, hh * 0.5, sin(a) * r), iron, Vector3.ZERO, 6)
	# 門：鉸鏈在左邊，打開的時候往外轉
	var a0 := PI * 0.5 + 0.42
	_door = Node3D.new()
	_door.position = Vector3(cos(a0) * r, 0, sin(a0) * r)
	_cage.add_child(_door)
	var a1 := PI * 0.5 - 0.42
	var span := Vector3(cos(a1) * r, 0, sin(a1) * r) - _door.position
	for k in 4:
		var u := (float(k) + 0.5) / 4.0
		_cyl(_door, 0.02, 0.02, hh - 0.16, span * u + Vector3(0, hh * 0.5, 0), iron, Vector3.ZERO, 6)
	for y in [0.16, hh - 0.08]:
		var bar := _cyl(_door, 0.02, 0.02, span.length(), span * 0.5 + Vector3(0, y, 0), iron, Vector3(0, 0, PI * 0.5), 6)
		bar.rotation.y = -atan2(span.z, span.x)
	_lock = Node3D.new()
	_lock.position = span * 0.92 + Vector3(0, hh * 0.5, 0.06)
	_door.add_child(_lock)
	_box(_lock, Vector3(0.18, 0.16, 0.07), Vector3.ZERO, gold)
	_torus(_lock, 0.045, 0.07, Vector3(0, 0.12, 0), gold, Vector3(PI * 0.5, 0, 0))

func _iron() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.30, 0.29, 0.32)
	m.metallic = 0.5
	m.roughness = 0.45
	return m

## 一團火（冰雪島營火的火焰模型和著色器）
var _flame_mats: Array = []

func _flame(parent: Node3D, pos: Vector3, size: float) -> Node3D:
	var f := _glb(parent, FLAME, pos, 0.0, 1.0)
	if f == null:
		return null
	_fit(f, size)
	_no_shadow(f)
	if _flame_mats.is_empty() and ResourceLoader.exists(FLAME_SHADER):
		for c in [[Color(1.0, 0.36, 0.06), Color(1.0, 0.70, 0.16)], [Color(1.0, 0.78, 0.22), Color(1.0, 0.97, 0.70)]]:
			var m := ShaderMaterial.new()
			m.shader = load(FLAME_SHADER)
			m.set_shader_parameter("base_c", c[0])
			m.set_shader_parameter("tip_c", c[1])
			m.set_shader_parameter("phase", float(c[0].g) * 7.0)
			_flame_mats.append(m)
	if not _flame_mats.is_empty():
		for mi in f.find_children("*", "MeshInstance3D", true, false):
			var msh := (mi as MeshInstance3D).mesh
			if msh == null:
				continue
			for i in msh.get_surface_count():
				var sn: String = msh.surface_get_name(i)
				if sn.contains("inner"):
					(mi as MeshInstance3D).set_surface_override_material(i, _flame_mats[1])
				else:
					(mi as MeshInstance3D).set_surface_override_material(i, _flame_mats[0])
	return f

## 菜單看板（跟開場那一塊同一個）：三行粉筆字可以一行一行燒掉
func _menu_board(parent: Node3D) -> Node3D:
	var wood := _tex_mat(LA + "polyhaven/weathered_brown_planks_diff_1k.jpg", 1.0, Color(0.95, 0.85, 0.75))
	var face := _toon(Color(0.17, 0.21, 0.17))
	_board_mats = [wood, face]
	var b := Node3D.new()
	parent.add_child(b)
	for x in [-1.3, 1.3]:
		_box(b, Vector3(0.14, 2.5, 0.14), Vector3(x, 1.25, 0), wood)
	_box(b, Vector3(2.8, 1.85, 0.1), Vector3(0, 1.62, 0), wood)
	_box(b, Vector3(2.56, 1.62, 0.04), Vector3(0, 1.62, 0.055), face)
	var head := _sign_text(b, "菜　單", 76, 0.0042, Vector3(0, 2.18, 0.085), Color(1.0, 0.86, 0.42))
	head.name = "Head"
	for k in MENU.size():
		var l := _sign_text(b, MENU[k], 50, 0.0041, Vector3(0, 1.80 - k * 0.34, 0.085), Color(0.96, 0.95, 0.90))
		l.name = "Line%d" % k
	# 燒起來的時候冒出來的火（先藏著）
	for x in [-0.9, 0.1, 1.0]:
		var f := _flame(b, Vector3(x, 0.75, 0.12), 0.9)
		if f:
			f.visible = false
			_flames.append(f)
	return b

func _sign_text(parent: Node3D, text: String, size: int, px: float, pos: Vector3, col: Color) -> Label3D:
	var l := Label3D.new()
	l.text = text
	if UIStyle.font():
		l.font = UIStyle.font()
	l.font_size = size
	l.pixel_size = px
	l.modulate = col
	l.outline_size = 0
	l.position = pos
	l.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(l)
	return l

## 岩漿球掉進湖裡凝固成的石頭路：從西岸一路接到湖中間的小島
func _build_lava_path() -> void:
	var mat: Material = _world.lava_material(0.12) if _world.has_method("lava_material") else _toon(Color(0.2, 0.16, 0.16))
	var r := RandomNumberGenerator.new()
	r.seed = 67
	for k in 5:
		var x := 4.6 + k * 1.25
		var p := Vector3(x, _water - 0.18, 1.0 + r.randf_range(-0.35, 0.35))
		var s := _glb(self, BOULDER, p, r.randf() * TAU, 1.0)
		if s:
			s.scale = Vector3(1.0, 0.32, 0.9) * r.randf_range(1.15, 1.35)
			_paint(s, mat)
			_no_shadow(s)

## 豪王：放大的農夫，換成深色的鋼鐵，外面套頭盔（紅色羽飾）、胸甲、肩甲、裙甲（照第 3 關的做法）。倒在地上
func _make_king() -> void:
	var w: Node3D = _chars._load_model_path(FARMER, KING_H, ["Idle"])
	if w == null:
		return
	add_child(w)
	var yaw := PI * 0.5                  # 面朝湖、往後倒：頭在西邊
	w.global_position = G2(KING)
	w.rotation.y = yaw
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.30, 0.33, 0.40)
	steel.metallic = 0.25
	steel.roughness = 0.55
	var plate := StandardMaterial3D.new()
	plate.albedo_color = Color(0.52, 0.56, 0.66)
	plate.metallic = 0.3
	plate.roughness = 0.5
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.07, 0.07, 0.09)
	var red := StandardMaterial3D.new()
	red.albedo_color = Color(0.82, 0.12, 0.12)
	for c in w.find_children("*", "MeshInstance3D", true, false):
		if String(c.name) != "Farmer_Head":       # 臉留著：掀開頭盔的時候看得到
			(c as MeshInstance3D).material_override = steel
	var ap := w.find_children("*", "AnimationPlayer", true, false)
	if not ap.is_empty():
		var p := ap[0] as AnimationPlayer
		if p.has_animation("Death"):
			p.play("Death")
			p.seek(p.get_animation("Death").length - 0.02, true)
			p.pause()
	var tall := KING_H
	var k := tall / 3.1
	var set := Node3D.new()
	set.name = "KingArmor"
	add_child(set)
	set.transform = Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, -PI * 0.5), w.global_position + Vector3(0, 0.25, 0))
	var parts: Array = [
		["box", Vector3(0.78, 0.74, 0.50), Vector3(0.0, 0.64, 0.0), plate],             # 胸甲
		["sphere", Vector3(0.25, 0.20, 0.25), Vector3(-0.48, 0.755, 0.0), plate],       # 左肩甲
		["sphere", Vector3(0.25, 0.20, 0.25), Vector3(0.48, 0.755, 0.0), plate],        # 右肩甲
		["box", Vector3(0.70, 0.30, 0.46), Vector3(0.0, 0.445, 0.0), steel],            # 裙甲
		["box", Vector3(0.20, 0.10, 0.52), Vector3(0.0, 0.66, 0.02), red],              # 胸前一道紅色的紋
	]
	var helm := Node3D.new()
	helm.position = Vector3(0, 0.895 * tall, 0)
	set.add_child(helm)
	var helm_parts: Array = [
		["sphere", Vector3(0.46, 0.46, 0.48), Vector3(0.0, 0.0, 0.02), plate],
		["box", Vector3(0.56, 0.10, 0.20), Vector3(0.0, -0.02, 0.40), dark],
		["box", Vector3(0.10, 0.44, 0.62), Vector3(0.0, 0.165, -0.05), red],
	]
	for pt in parts:
		var at: Vector3 = pt[2]
		_armor_part(set, pt, Vector3(at.x * k, at.y * tall, at.z * k), k)
	for pt in helm_parts:
		var at: Vector3 = pt[2]
		_armor_part(helm, pt, Vector3(at.x * k, at.y * tall, at.z * k), k)
	# 盔甲冒煙
	var steam := CPUParticles3D.new()
	steam.amount = 22
	steam.lifetime = 1.6
	var sm := SphereMesh.new()
	sm.radius = 0.09
	sm.height = 0.18
	sm.radial_segments = 8
	sm.rings = 4
	var smat := StandardMaterial3D.new()
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smat.vertex_color_use_as_albedo = true
	sm.material = smat
	steam.mesh = sm
	steam.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	steam.emission_box_extents = Vector3(0.6, 0.2, 1.2)
	steam.direction = Vector3(0, 1, 0)
	steam.spread = 18.0
	steam.gravity = Vector3(0, 0.6, 0)
	steam.initial_velocity_min = 0.6
	steam.initial_velocity_max = 1.3
	steam.scale_amount_min = 0.7
	steam.scale_amount_max = 1.6
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.92, 0.92, 0.95, 0.32))
	ramp.set_color(1, Color(0.8, 0.8, 0.85, 0.0))
	steam.color_ramp = ramp
	add_child(steam)
	steam.global_position = w.global_position + Basis(Vector3.UP, yaw) * Vector3(0, 0.7, -1.3)
	_king = {"node": w, "set": set, "helm": helm, "home": helm.position, "steam": steam, "yaw": yaw}

func _armor_part(parent: Node3D, pt: Array, pos: Vector3, k: float) -> void:
	var mi := MeshInstance3D.new()
	if pt[0] == "sphere":
		var sm := SphereMesh.new()
		sm.radius = 1.0
		sm.height = 2.0
		sm.radial_segments = 10
		sm.rings = 5
		mi.mesh = sm
		mi.scale = (pt[1] as Vector3) * k
	else:
		var bm := BoxMesh.new()
		bm.size = (pt[1] as Vector3) * k
		mi.mesh = bm
	mi.material_override = pt[3]
	mi.position = pos
	parent.add_child(mi)

## 豪王的頭在哪（掀開頭盔之後的臉）
func _king_head() -> Vector3:
	if _king.is_empty():
		return G2(KING)
	return (_king.set as Node3D).to_global(Vector3(0, 0.895 * KING_H, 0.0)) + Vector3(0, 0.3, 0)

## 一個農夫（共用的農夫模型，跟戰局裡的一樣大）
func _farmer(pos: Vector3, yaw: float) -> Dictionary:
	var w: Node3D = _chars._load_model_path(FARMER, 2.6, ["Idle"])
	if w == null:
		return {}
	add_child(w)
	w.global_position = pos
	w.rotation.y = yaw
	var sks := w.find_children("*", "Skeleton3D", true, false)
	var aps := w.find_children("*", "AnimationPlayer", true, false)
	var f := {"node": w, "sk": sks[0] if not sks.is_empty() else null, "ap": aps[0] if not aps.is_empty() else null,
		"base": {}, "kneel": 0.0, "bow": 0.0, "sway": false, "ph": float(_farmers.size()) * 1.3, "home": pos, "knee": 0.0, "posed": false}
	return f

## 跪下來：小腿往後折到貼地、整個人往下沉一個小腿的高度；bow 是上半身往前彎多少（弧度）
func _pose_farmer(f: Dictionary) -> void:
	var sk := f.sk as Skeleton3D
	if sk == null:
		return
	if not f.posed:
		# 第一次：動作停在現在這一格，記下要轉的那幾根骨頭原本的位置
		if f.ap:
			(f.ap as AnimationPlayer).pause()
		var base := {}
		for nm in ["LowerLeg.L", "LowerLeg.R", "Foot.L", "Foot.R", "Abdomen"]:
			var i := sk.find_bone(nm)
			if i >= 0:
				base[nm] = sk.get_bone_global_pose(i)
		f.base = base
		if base.has("LowerLeg.L"):
			var knee: Vector3 = sk.global_transform * (base["LowerLeg.L"] as Transform3D).origin
			f.knee = knee.y - (f.node as Node3D).global_position.y
		f.posed = true
	var base: Dictionary = f.base
	var kn: float = f.kneel
	var r := Basis(Vector3.RIGHT, PI * 0.5 * kn)
	for side in ["L", "R"]:
		var ll: String = "LowerLeg." + side
		var ft: String = "Foot." + side
		if not base.has(ll) or not base.has(ft):
			continue
		var l0: Transform3D = base[ll]
		var f0: Transform3D = base[ft]
		sk.set_bone_global_pose(sk.find_bone(ll), Transform3D(r * l0.basis, l0.origin))
		sk.set_bone_global_pose(sk.find_bone(ft), Transform3D(r * f0.basis, l0.origin + r * (f0.origin - l0.origin)))
	if base.has("Abdomen"):
		var a0: Transform3D = base["Abdomen"]
		sk.set_bone_global_pose(sk.find_bone("Abdomen"), Transform3D(Basis(Vector3.RIGHT, float(f.bow)) * a0.basis, a0.origin))
	var w := f.node as Node3D
	w.global_position.y = (f.home as Vector3).y - float(f.knee) * kn * 0.92

## 農夫轉過去面向某個點
func _farmer_face(f: Dictionary, target: Vector3) -> void:
	var w := f.node as Node3D
	var d := target - w.global_position
	w.rotation.y = atan2(d.x, d.z)

## 農夫擺到某個位置（還站著）
func _farmer_put(f: Dictionary, pos: Vector3) -> void:
	f.home = pos
	(f.node as Node3D).global_position = pos

## 一個一個跪下來
func _kneel(f: Dictionary, delay: float, bow := 0.45) -> void:
	var tw := _tw()
	tw.tween_interval(maxf(delay, 0.001))
	tw.tween_callback(func(): _play("thud", -18.0, 1.3))
	tw.set_parallel(true)
	tw.tween_method(func(v: float):
		f.kneel = v
		f.bow = bow * v
		_pose_farmer(f), 0.0, 1.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

## 小紅雞：小雞染成紅的，頭上、身上幾撮捲捲的羽毛（被火山烤捲了）
func _make_chick() -> void:
	_chick = _actor(self, "chick", Vector3.ZERO, 0.0, 1.0)
	var red := _toon(Color(0.88, 0.24, 0.14))
	var wing := _toon(Color(0.74, 0.16, 0.10))
	var curl := _toon(Color(0.98, 0.50, 0.20))
	for c in (_chick.node as Node3D).find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		var m := mi.material_override as ShaderMaterial
		if m == null:
			continue
		var col = m.get_shader_parameter("albedo")
		if col is Color:
			var cc := col as Color
			if cc.r > 0.85 and cc.g > 0.85 and cc.b > 0.85:
				mi.material_override = red if cc.r > 0.93 else wing
	var head := _chick.head as Node3D
	if head:
		for t in [[Vector3(-0.08, 0.4, -0.06), Vector3(0.3, 0, 0.5)], [Vector3(0.07, 0.43, -0.02), Vector3(-0.2, 0, -0.4)], [Vector3(0.0, 0.36, -0.16), Vector3(1.0, 0, 0)]]:
			_torus(head, 0.035, 0.06, t[0], curl, t[1])
	var body := _chick.body as Node3D
	if body:
		for t in [[Vector3(0.0, 0.72, -0.38), Vector3(0.6, 0, 0)], [Vector3(-0.34, 0.42, -0.16), Vector3(0, 0, 1.2)], [Vector3(0.34, 0.42, -0.16), Vector3(0, 0, -1.2)]]:
			_torus(body, 0.05, 0.085, t[0], curl, t[1])

## 神之手：關卡裡那雙半透明的手放大好幾倍。靜音拍：從島北邊的海裡升起來、手指朝天、手心朝著島；
## 上船：換成一隻手從海裡伸出來推船尾
func _god_hands() -> Dictionary:
	var ps := load(ARMS) as PackedScene
	if ps == null:
		return {}
	var holder := Node3D.new()
	holder.name = "GodHands"
	add_child(holder)
	var tilt := Node3D.new()
	holder.add_child(tilt)
	var arms := ps.instantiate() as Node3D
	arms.position = Vector3(0.0, -1.743, 0.0)
	tilt.add_child(arms)
	var mat := ShaderMaterial.new()
	mat.shader = HAND_SHADER
	mat.render_priority = 10
	mat.set_shader_parameter("body_alpha", 0.28)
	mat.set_shader_parameter("rim_alpha", 0.95)
	mat.set_shader_parameter("glow", 0.3)
	for m in arms.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		var src := mi.get_active_material(0) as BaseMaterial3D
		if src and src.albedo_texture:
			mat.set_shader_parameter("skin_tex", src.albedo_texture)
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.extra_cull_margin = 80.0
	var ap := arms.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap and ap.has_animation("relax"):
		ap.get_animation("relax").loop_mode = Animation.LOOP_LINEAR
		ap.speed_scale = 0.45
		ap.play("relax")
	var sks := arms.find_children("*", "Skeleton3D", true, false)
	holder.visible = false
	return {"node": holder, "tilt": tilt, "mat": mat, "ap": ap, "sk": sks[0] if not sks.is_empty() else null}

## 靜音拍的那雙手：手指朝天、手心朝南（朝著小廟），往島這邊傾一點
func _hands_rise_pose() -> void:
	var hn := _hands.node as Node3D
	hn.scale = Vector3.ONE * HAND_S
	hn.rotation = Vector3.ZERO
	(_hands.tilt as Node3D).basis = Basis(Vector3.RIGHT, deg_to_rad(14.0)) * Basis(Vector3.RIGHT, -PI * 0.5)
	hn.visible = true

func _hands_rise_pos() -> Vector3:
	var k := 1.0 - pow(1.0 - _rise, 2.0)
	return Vector3(SHRINE.x + 1.0, lerpf(_hand_y - 46.0, _hand_y, k) + sin(_t * 0.35) * 0.3 + _dip, -88.0)

## 手心朝哪邊（音符放在手心前面一點）
func _palm_up() -> Vector3:
	var hn := _hands.node as Node3D
	return (hn.global_basis * (_hands.tilt as Node3D).basis * Vector3(0, -1, 0)).normalized()

## 骨頭在世界裡的位置（手心）
func _bone_world(bone: String) -> Vector3:
	var sk := _hands.get("sk") as Skeleton3D
	if sk == null:
		return (_hands.node as Node3D).global_position
	var i := sk.find_bone(bone)
	if i < 0:
		return (_hands.node as Node3D).global_position
	return sk.global_transform * sk.get_bone_global_pose(i).origin

## 打雷的烏雲、閃電、一陣風吹過的落葉、燒完的火星（都先做好藏著）
func _build_fx() -> void:
	_storm = Node3D.new()
	add_child(_storm)
	var cm := ShaderMaterial.new()
	cm.shader = CLOUD_SHADER
	var r := RandomNumberGenerator.new()
	r.seed = 33
	for k in 16:
		var a := TAU * float(k) / 16.0
		var rr := r.randf_range(0.0, 8.0)
		var sc := r.randf_range(3.0, 5.6)
		var puff := _ball(_storm, 1.0, Vector3(cos(a) * rr, r.randf_range(0.0, 1.6), sin(a) * rr), cm, Vector3(sc, sc * 0.55, sc), 10)
		puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_storm.visible = false
	_bolt_mat = StandardMaterial3D.new()
	_bolt_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_bolt_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_bolt_mat.albedo_color = Color(4.0, 4.0, 5.0)
	_bolt = MeshInstance3D.new()
	_bolt.material_override = _bolt_mat
	_bolt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_bolt.visible = false
	add_child(_bolt)
	_leaves = _burst(Color(0.95, 0.62, 0.16), Color(0.80, 0.30, 0.10), Vector2(0.22, 0.16), 90, 2.4)
	_leaves.emission_box_extents = Vector3(4.0, 2.0, 3.0)
	_leaves.direction = Vector3(-1.0, 0.5, 0.9)
	_leaves.gravity = Vector3(0, -0.8, 0)
	_sparks = _burst(Color(1.0, 0.85, 0.3), Color(1.0, 0.3, 0.05), Vector2(0.12, 0.12), 50, 1.2)
	_sparks.emission_box_extents = Vector3(1.0, 0.4, 0.3)
	_sparks.direction = Vector3(0, 1, 0)
	_sparks.spread = 60.0
	_sparks.gravity = Vector3(0, -3.0, 0)

func _burst(a: Color, b: Color, size: Vector2, amount: int, life: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.emitting = false
	p.one_shot = true
	p.amount = amount
	p.lifetime = life
	p.explosiveness = 0.8
	var q := QuadMesh.new()
	q.size = size
	var lm := StandardMaterial3D.new()
	lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lm.vertex_color_use_as_albedo = true
	lm.cull_mode = BaseMaterial3D.CULL_DISABLED
	lm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	q.material = lm
	p.mesh = q
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.initial_velocity_min = 5.0
	p.initial_velocity_max = 10.0
	p.spread = 25.0
	p.angular_velocity_min = -400.0
	p.angular_velocity_max = 400.0
	var grad := Gradient.new()
	grad.set_color(0, a)
	grad.set_color(1, b)
	p.color_initial_ramp = grad
	add_child(p)
	return p

## 一道閃電從 top 折下來打在 at（網格每打一次做一次，不是每一畫面）
func _strike(top: Vector3, at: Vector3, seed_n: int, width := 0.35) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_n
	var prev := at
	var n := 12
	var span := top.distance_to(at)
	for k in n:
		var u := float(k + 1) / n
		var wob := span * 0.07 * (1.0 - u) * minf(u * 4.0, 1.0)
		var nxt := at.lerp(top, u) + Vector3(rng.randf_range(-wob, wob), 0, rng.randf_range(-wob, wob))
		for side in [Vector3(width, 0, 0), Vector3(0, 0, width)]:
			var qd := [prev - side, prev + side, nxt + side, nxt - side]
			for t in [0, 1, 2, 0, 2, 3]:
				st.add_vertex(qd[t])
		prev = nxt
	_bolt.mesh = st.commit()
	_bolt.visible = true
	_flash(Color(0.86, 0.92, 1.0), 0.75, 0.45)
	_play("thunder", -5.0)
	_shake = 0.6
	var tw := _tw()
	tw.tween_interval(0.12)
	tw.tween_callback(func(): _bolt.visible = false)
	tw.tween_interval(0.08)
	tw.tween_callback(func(): _bolt.visible = true)
	tw.tween_interval(0.12)
	tw.tween_callback(func(): _bolt.visible = false)

# ================================================================== 聲音

func _make_story_sounds() -> void:
	# 打雷：一聲很亮的「啪」，接著低低的隆隆聲
	var b := s_buf(2.4)
	s_noise(b, 0.0, 0.3, 0.9, 0.7, 78, 12.0)
	s_kick(b, 0.0, 0.9)
	s_noise(b, 0.05, 2.3, 0.8, 0.04, 77, 1.5)
	_snd["thunder"] = s_wav(b)
	# 滋——（燙的盔甲冒煙）
	b = s_buf(1.6)
	s_noise(b, 0.0, 1.6, 0.35, 0.92, 15, 1.4)
	_snd["sizzle"] = s_wav(b)
	# 火燒起來的「呼」
	b = s_buf(0.9)
	s_noise(b, 0.0, 0.9, 0.7, 0.12, 19, 3.0)
	_snd["fire"] = s_wav(b)
	# 鎖彈開的「鏘」
	b = s_buf(0.5)
	s_tone(b, 0.0, 1320.0, 0.45, 0.35, 0.8, 9.0)
	s_tone(b, 0.0, 1975.0, 0.35, 0.2, 0.5, 12.0)
	_snd["clang"] = s_wav(b)

# ================================================================== 每一畫面

func _story_tick(dt: float) -> void:
	# 看板被吹走：鏡頭一路盯著它
	if _track and _board:
		var want := _board.global_position + Vector3(0, 1.5, 0)
		_cam_b["l"] = (_cam_b["l"] as Vector3).lerp(want, 1.0 - exp(-dt * 6.0))
	# 跪著的農夫跟著拍子一下一下地拜
	for f in _farmers:
		if f.sway:
			f.bow = 0.42 + sin(_t * PI / BEAT * 0.5 + float(f.ph)) * 0.16
			_pose_farmer(f)
	# 靜音拍的那雙手慢慢升起來
	if not _hands.is_empty() and (_hands.node as Node3D).visible and not _push_on:
		(_hands.node as Node3D).global_position = _hands_rise_pos()
		(_hands.mat as ShaderMaterial).set_shader_parameter("fade", clampf(_rise * 1.5, 0.0, 1.0))
	# 飛向巨手的那一顆音符：越飛越大（離鏡頭很遠還看得到），到了就被手心接住
	if _note_t >= 0.0 and is_instance_valid(_big_note):
		_note_t += dt
		var k := clampf(_note_t / _note_dur, 0.0, 1.0)
		var to := _bone_world("palm.02.R")
		var p := _note_from.lerp(to, k * k * (3.0 - 2.0 * k))
		p.y += sin(k * PI) * 4.0
		_big_note.global_position = p
		_big_note.scale = Vector3.ONE * lerpf(1.0, 5.0, k)
		if k >= 1.0:
			_note_t = -1.0
			_caught()
	if _held and is_instance_valid(_big_note):
		_big_note.global_position = _bone_world("palm.02.R") + _palm_up() * 1.6
		_big_note.scale = Vector3.ONE * (5.0 + sin(_t * 3.0) * 0.4)
	# 上船：小船離岸，那隻手跟在船尾推一段
	if _leave_on and _boat:
		var t := _shot_t
		var k := clampf((t - 1.9) / 3.4, 0.0, 1.0)
		var e := k * k * (3.0 - 2.0 * k)
		var a := _leave_a()
		var b := _leave_b()
		_boat_at(_boat, a.lerp(b, e), b - a)
		var hero := _hero.node as Node3D
		hero.global_position = _boat.to_global(Vector3(0, 0.24, -0.35))
		hero.rotation.y = _boat.rotation.y
		if _chick.get("in_boat", false):
			(_chick.node as Node3D).global_position = _boat.to_global(Vector3(0, 0.22, 0.9))
			(_chick.node as Node3D).rotation.y = _boat.rotation.y
		if _push_on:
			# 手掌貼著船尾推一段（推到 3.4 秒），之後停下來、慢慢沉回海裡
			var rise := clampf((t - 1.1) / 0.8, 0.0, 1.0)
			var sink := clampf((t - 3.6) / 1.4, 0.0, 1.0)
			if t < 3.4:
				_push_at = _boat.to_global(Vector3(0, 0.35, -1.5))
			var dir := (b - a).normalized()
			var hand := Basis(Vector3.UP, atan2(dir.x, dir.z)) * Vector3(-0.06, -0.13, 0.36) * PUSH_S
			(_hands.node as Node3D).global_position = _push_at - hand + Vector3(0, -(1.0 - rise) * PUSH_S * 0.6 - sink * PUSH_S * 0.5, 0)
			(_hands.mat as ShaderMaterial).set_shader_parameter("fade", rise * (1.0 - sink))

## 火山口自己往上噴的火花：看板在火山口上面燒的那個特寫先收起來（太近了，整個畫面都是火花，看不到看板）
func _volcano_sparks(on: bool) -> void:
	var sp = _world.get("_sparks")
	if sp is Node3D:
		(sp as Node3D).visible = on

## 上船：小船從北岸的崖腳往西北划出去
func _leave_a() -> Vector3:
	return Vector3(COAST_X, SEA_Y, _c_foot - 1.6)

func _leave_b() -> Vector3:
	return Vector3(COAST_X - 9.0, SEA_Y, _c_foot - 15.0)

## 音符被手心接住：音符留在手心裡變成淡淡的金色，整隻手往下沉一下（接住的重量）、亮一下
func _caught() -> void:
	_held = true
	if is_instance_valid(_big_note):
		_big_note.modulate = Color(1.0, 0.92, 0.62)
	var mat := _hands.mat as ShaderMaterial
	var tw := _tw()
	tw.tween_method(func(v: float): mat.set_shader_parameter("glow", v), 1.3, 0.4, 1.8)
	var tw2 := _tw()
	tw2.tween_property(self, "_dip", -2.6, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw2.tween_property(self, "_dip", 0.0, 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_play("ding", -14.0, 0.7)

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
	_push_on = false
	_track = false
	_note_t = -1.0
	if is_instance_valid(_big_note):
		_big_note.visible = _held and s in ["dj", "hood"]
	if _boat:
		_boat.visible = s in ["leave", "journal"]
	var cn := _chick.node as Node3D
	cn.visible = true
	cn.rotation = Vector3.ZERO
	_chick.look = null
	_chick.in_boat = false
	_set_anim(_chick, "idle")
	if not _king.is_empty():
		(_king.steam as CPUParticles3D).emitting = s == "king"
	(_hands.node as Node3D).visible = s in ["dj", "hood", "leave"]
	_storm.visible = s in ["cage", "farm"]
	_volcano_sparks(s != "burn")
	for f in _farmers:
		f.sway = false
		(f.node as Node3D).visible = s in ["farm", "dj", "hood"]
	match s:
		"king":
			hero.position = G(KING.x - 1.2, KING.y - 2.6)
			_face(_hero, _king_head())
			cn.position = G2(CAGE) + Vector3(0, 0.1, 0)
		"wind", "burn":
			hero.position = G(BOARD.x + 2.2, BOARD.y - 2.0)
			_face(_hero, G2(BOARD))
			cn.position = G2(CAGE) + Vector3(0, 0.1, 0)
		"cage":
			hero.position = G(CAGE.x - 1.6, CAGE.y + 1.6)
			_face(_hero, G2(CAGE))
			cn.position = G2(CAGE) + Vector3(0, 0.1, 0)
			cn.rotation.y = 0.35
			_set_anim(_chick, "cower")
			_storm.global_position = G2(CAGE) + Vector3(0, 20.0, 0)
		"farm":
			hero.position = G2(HERO3)
			hero.rotation.y = 0.0
			cn.position = G2(HERO3) + Vector3(0.9, 0, -0.5)
			cn.rotation.y = 0.3
			_storm.global_position = G2(CAGE) + Vector3(2.0, 20.0, 0)
			for i in _farmers.size():
				var f: Dictionary = _farmers[i]
				_farmer_put(f, G2(FARM3[i]))
				_farmer_face(f, G(8.0, 1.0))           # 一開始看著湖上那條岩漿鋪出來的路
		"dj":
			hero.position = G2(DJ)
			hero.rotation.y = 0.0
			cn.position = G(DJ.x + 1.1, DJ.y + 0.9)
			cn.rotation.y = -0.2
			for i in _farmers.size():
				var f: Dictionary = _farmers[i]
				_farmer_put(f, G2(KNEEL4[i]))
				_farmer_face(f, G2(DJ))
				f.kneel = 1.0
				f.bow = 0.42
				_pose_farmer(f)
			_hands_rise_pose()
			_rise = 0.0
			_hand_y = 8.0
		"hood":
			hero.position = G2(DJ)
			hero.rotation.y = PI               # 面向小廟和海（那雙手）
			cn.position = G(DJ.x + 1.1, DJ.y + 0.9)
			cn.rotation.y = PI
			for i in _farmers.size():
				var f: Dictionary = _farmers[i]
				f.kneel = 1.0
				f.sway = true
			_hands_rise_pose()
			_rise = 1.0
			var ap := _hands.ap as AnimationPlayer
			if ap:
				ap.speed_scale = 0.45
				ap.play("relax", 0.8)
		"leave":
			_leave_on = true
			var hn := _hands.node as Node3D
			hn.scale = Vector3.ONE * PUSH_S
			var dir := _leave_b() - _leave_a()
			hn.rotation = Vector3(0, atan2(dir.x, dir.z), 0)    # 模型的前方 +Z 轉到船要去的方向（外海）
			_push_at = _leave_a() + Vector3(0, 0.35, 1.5)
			(_hands.tilt as Node3D).basis = Basis.IDENTITY
			var ap := _hands.ap as AnimationPlayer
			if ap:
				ap.speed_scale = 0.45
				ap.play("relax")
			_push_on = true
			(_hands.mat as ShaderMaterial).set_shader_parameter("fade", 0.0)
			cn.position = G(COAST_X + 0.4, _c_edge - 0.6)
			cn.rotation.y = PI
		"journal":
			hero.visible = false
			cn.visible = false
			_boat_at(_boat, _leave_b() + (_leave_b() - _leave_a()) * 0.9, _leave_b() - _leave_a())
			(_hero.node as Node3D).visible = false

func _on_line(l: Dictionary) -> void:
	var hero := _hero.node as Node3D
	match String(l.get("cue", "")):
		# ---------------------------------------------------------- ① 收場
		"k_down":
			# 豪王倒在湖邊，盔甲冒煙。自己把頭盔掀開散熱
			var hd := _king_head()
			var mid := hd.lerp(G2(KING), 0.5)
			_shot_cam(mid + Vector3(0.4, 1.7, 4.0), mid + Vector3(0, 0.1, -0.3), 40.0, 0.0, Vector3(0.03, -0.02, -0.04))
			_music_play("theme", -20.0, 2.0)
			_amb_play("wind", -19.0, 1.0)
			_play("sizzle", -12.0)
			_at(0.3, func(): _emote(G2(KING) + Vector3(-0.8, 1.2, 0), "滋——", Color(1.0, 0.75, 0.5), 1.4, 0.7, 0.4))
			var helm := _king.helm as Node3D
			var home: Vector3 = _king.home
			_at(1.3, func():
				var tw := _tw()
				tw.tween_property(helm, "position", home + Vector3(0.1, 0.25, 1.0), 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				tw.parallel().tween_property(helm, "rotation", Vector3(-0.6, 0.0, 0.3), 0.45)
				tw.tween_property(helm, "position", home + Vector3(-1.05, 0.15, 0.2), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
				tw.parallel().tween_property(helm, "rotation", Vector3(-1.4, 0.3, -1.2), 0.35)
				tw.tween_callback(func(): _play("thud", -12.0, 0.8))
				_play("pop", -12.0, 0.7))
			_at(1.7, func():
				var steam := _king.steam as CPUParticles3D
				steam.global_position = _king_head()
				_emote(_king_head() + Vector3(0, 0.3, 0), "呼——", Color(1, 1, 1), 1.2, 0.75, 0.5))
			_hero.look = _king_head()
		"k_hot":
			_at(0.2, func(): _emote(_king_head() + Vector3(0, 0.2, 0), "…", Color(1, 1, 1), 1.0, 0.8))
		# ---------------------------------------------------------- ② 號碼
		"r_wind":
			# 一陣風把菜單看板吹起來，飛過火山口
			# 先近近地看著看板被風吹得一直晃，接著它被整塊掀起來，鏡頭跟著往上搖到火山
			var bp := _board.global_position
			var cam := bp + Vector3(6.0, 0.9, 5.0)
			_shot_cam(bp + Vector3(3.4, 1.2, 3.6), bp + Vector3(0, 1.7, 0), 44.0)
			_at(0.45, func():
				_shot_cam(cam, bp + Vector3(0, 2.0, 0), 62.0, 1.0)
				_track = true)
			_amb_play("wind", -8.0, 0.3)
			_play("whoosh", -8.0, 0.5)
			_leaves.global_position = bp + Vector3(4.0, 1.5, -2.0)
			_leaves.restart()
			_set_anim(_hero, "shock")
			var from := bp
			var to := _crater + Vector3(0, 3.4, 0)
			var tw0 := _tw()
			tw0.tween_method(func(k: float): _board.rotation = Vector3(sin(k * 40.0) * 0.08, 0.5, sin(k * 31.0) * 0.06), 0.0, 1.0, 0.45)
			_at(0.45, func():
				var tw := _tw()
				tw.tween_method(func(k: float):
					var p := from.lerp(to, k)
					p.y += sin(k * PI) * 12.0
					_board.global_position = p
					# 正面一直朝著鏡頭（看得到上面的字），一邊飛一邊晃
					_board.global_basis = Basis.looking_at((p - cam).normalized(), Vector3.UP) * Basis.from_euler(Vector3(sin(k * 9.0) * 0.25, sin(k * 6.0) * 0.3, cos(k * 7.0) * 0.25)), 0.0, 1.0, 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT))
			_at(1.0, func():
				_hero.look = to
				_set_anim(_hero, "lookup"))
		"r_burn":
			# 看板飛過火山口燒起來：「前菜」「甜點」先燒掉，「六十七號」那一行最後才燒完
			var cam := _crater + Vector3(5.2, 7.4, 6.6)
			_board.global_position = _crater + Vector3(0.6, 3.6, 0.8)
			_shot_cam(cam, _board.global_position + Vector3(0, 1.3, 0), 36.0, 0.0, Vector3(-0.08, -0.04, -0.08))
			_volcano_sparks(false)
			var d := cam - _board.global_position
			_board.rotation = Vector3(0.12, atan2(d.x, d.z), 0.05)
			_amb_play("wind", -16.0, 0.6)
			_at(0.15, func():
				_play("fire", -6.0)
				for f in _flames:
					(f as Node3D).visible = true
					(f as Node3D).scale *= 0.3
					_tw().tween_property(f, "scale", (f as Node3D).scale / 0.3, 0.5)
				var tw := _tw()
				tw.set_parallel(true)
				tw.tween_property(_board_mats[0], "albedo_color", Color(0.12, 0.08, 0.06), 2.4)
				tw.tween_method(func(c: Color): (_board_mats[1] as ShaderMaterial).set_shader_parameter("albedo", c), Color(0.17, 0.21, 0.17), Color(0.05, 0.04, 0.04), 2.4))
			var order := [["Line0", 0.6], ["Line2", 1.0], ["Head", 1.3], ["Line1", 2.1]]
			for o in order:
				var lbl := _board.get_node_or_null(String(o[0])) as Label3D
				if lbl == null:
					continue
				var last: bool = o[0] == "Line1"
				_at(float(o[1]), func():
					var tw := _tw()
					tw.tween_property(lbl, "modulate", Color(1.0, 0.45, 0.1), 0.25 if not last else 0.45)
					tw.tween_property(lbl, "modulate", Color(0.2, 0.1, 0.05, 0.0), 0.3 if not last else 0.5)
					_play("fire", -14.0 if not last else -8.0, 1.3 if not last else 0.9))
			_at(2.75, func():
				_sparks.global_position = _board.global_position
				_sparks.restart()
				var tw := _tw()
				tw.tween_property(_board, "global_position", _crater + Vector3(0, -0.5, 0), 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
				tw.parallel().tween_property(_board, "scale", Vector3.ONE * 0.2, 0.45)
				tw.tween_callback(func(): _board.visible = false))
		"r_bolt":
			# 烤爐旁的小籠子關著一隻羽毛捲捲的小紅雞。一道雷打在鎖上，籠門彈開
			var cp := _cage.global_position
			_shot_cam(cp + _cage.basis * Vector3(1.4, 1.9, 4.6), cp + _cage.basis * Vector3(0.4, 0.35, 0), 40.0, 0.0, Vector3(-0.03, 0.01, -0.05))
			_storm.visible = true
			_hero.look = cp + Vector3(0, 0.5, 0)
			_at(0.2, func(): _emote(_chick, "？", Color(1, 1, 1), 0.9, 0.7))
			_at(0.7, func():
				var lp := _lock.global_position
				_strike(lp + Vector3(1.5, 22.0, -2.0), lp, 7, 0.16)
				_set_anim(_chick, "shock")
				_set_anim(_hero, "shock"))
			_at(0.8, func():
				_play("clang", -6.0)
				var lp := _lock.global_position
				_lock.reparent(self)
				var tw := _tw()
				tw.tween_method(func(k: float):
					var p := lp.lerp(lp + Vector3(1.6, 0, 1.8), k)
					p.y = lp.y + sin(k * PI) * 0.8 - k * (lp.y - _cage.global_position.y)
					_lock.global_position = p
					_lock.rotation = Vector3(k * 9.0, k * 6.0, 0), 0.0, 1.0, 0.6)
				_tw().tween_property(_door, "rotation:y", 1.9, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))
			_at(1.5, func():
				_set_anim(_chick, "flap")
				_hop(_chick, cp + _cage.basis * Vector3(1.1, 0, 1.0), 0.45, 0.6, 0.0, "shake"))
		"r_free":
			_hero.look = null
			_set_anim(_hero, "idle")
			_at(0.6, func():
				_set_anim(_chick, "lookup")
				_chick.look = _storm.global_position)
		# ---------------------------------------------------------- ③ 神明
		"f_kneel":
			# 農夫們看看岩漿鋪出來的路，又看看天上的雷雲，一個一個對著家豪跪下來
			_shot_cam(G2(HERO3) + Vector3(-5.4, 2.4, 9.6), G2(HERO3).lerp(G2(FARM3[1]), 0.5) + Vector3(0, 1.0, 0), 46.0, 0.0, Vector3(0.05, 0, -0.08))
			_at(0.3, func(): _emote((_farmers[1].node as Node3D).global_position + Vector3(0, 3.0, 0), "？", Color(1, 1, 1), 0.9, 0.9))
			_at(1.0, func():
				for f in _farmers:
					_farmer_face(f, _storm.global_position)
				_emote((_farmers[0].node as Node3D).global_position + Vector3(0, 3.0, 0), "！", Color(1, 1, 1), 0.9, 0.9)
				_emote((_farmers[2].node as Node3D).global_position + Vector3(0, 3.0, 0), "！", Color(1, 1, 1), 0.9, 0.9))
			for i in _farmers.size():
				var f: Dictionary = _farmers[i]
				_at(1.7 + 0.35 * i, func(): _farmer_face(f, hero.global_position))
				_kneel(f, 1.75 + 0.35 * i)
			_at(2.4, func():
				_set_anim(_hero, "shock")
				_emote(_hero, "！？", Color(1, 1, 1), 1.0, 0.8))
		"f_miracle":
			var hp := hero.global_position
			_shot_cam(hp + Vector3(-3.0, 2.3, -1.8), G2(FARM3[1]) + Vector3(0.6, 0.9, 0), 42.0, 0.0, Vector3(0.03, 0, 0.02))
			_set_anim(_hero, "idle")
			for f in _farmers:
				f.sway = true
		"f_wrong":
			var hp := hero.global_position
			_shot_cam(hp + Vector3(1.2, 2.6, 5.4), hp + Vector3(0, 1.0, 0), 34.0, 0.0, Vector3(0.0, 0, -0.04))
			_set_anim(_hero, "shrug")
			_hero.look = _storm.global_position
		# ---------------------------------------------------------- ④ 靜音拍
		"d_silence":
			# 配樂淡出。家豪在青苔小廟前打碟，農夫跪著跟著晃。島外那雙巨手慢慢升起來，用手心接住一顆音符
			_shot_cam(G2(DJ) + Vector3(1.2, 2.6, 7.8), G2(DJ) + Vector3(-0.4, 4.0, -26.0), 54.0, 0.0, Vector3(-0.02, 0.01, -0.06))
			_music_stop(1.6)
			_amb_play("waves", -15.0, 1.5)
			_at(0.4, func():
				_set_anim(_hero, "dj", 0.8)
				_notes(true)
				_set_anim(_chick, "nod")
				for f in _farmers:
					f.sway = true)
			_tw().tween_property(self, "_rise", 1.0, 5.0).set_delay(0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			_at(4.6, func():
				_note_from = hero.global_position + Vector3(0.3, 1.8, 0)
				_big_note = _label3d("♪", 200, GREY)
				add_child(_big_note)
				_big_note.global_position = _note_from
				_note_dur = 2.2
				_note_t = 0.0)
		"d_line":
			var hp := hero.global_position
			_shot_cam(hp + Vector3(1.1, 1.35, 3.3), hp + Vector3(0, 1.05, 0), 32.0, 0.0, Vector3(0.02, 0, 0.03))
			_set_anim(_hero, "dj", 0.45)
			_notes(true)
			for f in _farmers:
				f.sway = true
		"d_god":
			var hp := hero.global_position
			_shot_cam(hp + Vector3(0.4, 3.0, 9.0), hp + Vector3(-2.0, 7.5, -26.0), 50.0, 0.0, Vector3(0.0, 0.02, 0.04))
			_set_anim(_hero, "lookup")
			_hero.look = _bone_world("palm.02.R")
			for f in _farmers:
				f.sway = true
		# ---------------------------------------------------------- ⑤ 羽毛
		"w_gust":
			# 從背後拍：一陣風掀起帽沿，帽子底下青、黃、紅三根羽毛尖
			var hp := hero.global_position
			_shot_cam(hp + Vector3(0.8, 2.0, 3.6), hp + Vector3(0, 1.5, -1.0), 34.0, 0.0, Vector3(-0.02, 0, -0.05))
			_set_anim(_hero, "idle")
			_amb_play("wind", -9.0, 0.3)
			_at(0.2, func(): _play("whoosh", -8.0, 0.6))
			_at(0.4, func():
				_hood_lift()
				_play("ding", -16.0, 1.2))
			_at(1.4, func(): _amb.volume_db = -18.0)
		"w_god":
			pass
		"w_no":
			_at(0.15, func():
				_set_anim(_hero, "cool")
				_hood_down()
				_emote(_hero, "…", Color(1, 1, 1), 1.0, 0.8))
		# ---------------------------------------------------------- ⑥ 上船
		"l_leave":
			# 小紅雞跳上船。巨手從海裡伸出來，把小船輕輕推出海
			# 從海上往回看北岸：小船朝鏡頭這邊離岸，手在船尾推
			_shot_cam(Vector3(COAST_X + 3.0, SEA_Y + 10.5, _c_foot - 16.0), Vector3(COAST_X - 3.5, SEA_Y + 0.4, _c_foot - 6.5), 50.0, 0.0, Vector3(-0.1, 0.0, -0.06))
			_amb_play("waves", -14.0, 1.0)
			_music_play("theme", -18.0, 2.5)
			var cn := _chick.node as Node3D
			_at(0.4, func():
				_set_anim(_chick, "flap")
				var to := _boat.to_global(Vector3(0, 0.22, 0.9))
				var tw := _tw()
				var from := cn.global_position
				tw.tween_method(func(k: float):
					var p := from.lerp(to, k)
					p.y += sin(k * PI) * 1.6
					cn.global_position = p, 0.0, 1.0, 0.7)
				tw.tween_callback(func():
					_chick.in_boat = true
					_set_anim(_chick, "idle")
					_play("thud", -16.0, 1.6)))
			_at(1.8, func():
				var ap := _hands.ap as AnimationPlayer
				if ap and ap.has_animation("push_R"):
					ap.speed_scale = 0.5
					ap.play("push_R", 0.3))
			_at(2.6, func():
				var ap := _hands.ap as AnimationPlayer
				if ap:
					ap.speed_scale = 0.0)
		# ---------------------------------------------------------- ⑦ 手帳
		"j_page":
			_shot_cam(Vector3(COAST_X + 7.0, SEA_Y + 2.4, _c_foot - 12.0), Vector3(COAST_X - 6.0, 12.0, _c_foot - 90.0), 60.0, 0.0, Vector3(0, 0.03, -0.05))
			_at(0.5, func(): _journal_p = _journal_page(3, "秋收祭。主菜是我。", RED, "人類要塞"))
