extends "res://scripts/ui/cutscene.gd"
## 開場動畫：屋頂（家豪對著空氣打碟）→ 夜裡的雞舍 → 夢裡見到神明 → 醒來出發
##
## 操作：Enter / 空白鍵 / 滑鼠左鍵 下一句（字還在打時先把整句顯示出來）；Esc 跳過整段開場
##
## ★ 台詞都在下面的 _lines()，要改字直接改 text 就好；劇本在 levels/ice/docs/開頭與結局劇情.md 第 4 節。
##   shot 決定這一句在哪個景：
##     "roof"   黃昏的雞舍屋頂，家豪在上面打碟（沒有聲音），公雞在下面喊
##     "barn"   夜裡的雞舍裡面，一格一格的窩，六十六號那一格是空的
##     "dream"  夢境：雲海上的神明
##     "wake"   回到雞舍，家豪醒來、撿起腳牌出門
##   cue 決定這一句演什麼（運鏡和動作寫在 _on_line()）。切換 shot 時會自動淡出淡入。

const NEXT_SCENE := "res://scenes/level_select.tscn"
const ENDING_SCENE := "res://levels/heaven/ending/ending.tscn"   # 結局動畫（隱藏按鍵 Shift＋E 直接播，展示用）
const BARN_Z := 200.0
const DREAM_Z := 400.0
const STALL_X := [-2.6, -1.3, 0.0, 1.3, 2.6]      # 五格窩：64、65、66（空的）、67（家豪）、68
const STALL_NUM := ["64", "65", "66", "67", "68"]
const HEN_S := 0.82

func _lines() -> Array:
	return [
		{"shot": "roof", "who": "公雞", "text": "家豪！下來啦。你又不會飛，摔下來誰接你？", "cue": "roof_call"},
		{"shot": "roof", "who": "公雞", "text": "你每天在上面對著空氣比來比去，到底是在幹嘛？", "cue": "roof_air"},
		{"shot": "roof", "who": "家豪", "text": "……懂的都懂。", "cue": "roof_cool"},
		{"shot": "roof", "who": "公雞", "text": "整個雞舍沒有一隻懂啦！", "cue": "roof_none"},
		{"shot": "roof", "who": "公雞", "text": "你這樣，以後誰要跟你站同一排？", "cue": "roof_row"},
		{"shot": "roof", "who": "家豪", "text": "……本來就沒有。", "cue": "roof_alone"},
		{"shot": "barn", "who": "旁白", "text": "夜深了。雞舍的燈從來不關。", "cue": "barn_wide"},
		{"shot": "barn", "who": "旁白", "text": "隔壁的嘉欣上禮拜被抓上卡車，只剩一塊扯斷的腳牌掉在稻草上：六十六。", "cue": "barn_tag"},
		{"shot": "barn", "who": "家豪", "text": "「今天放什麼歌？」……整個雞舍只有嘉欣會這樣問。", "cue": "barn_ghost", "snap": 2.2},
		{"shot": "dream", "who": "？？？", "text": "家豪。……家豪，抬頭。", "cue": "dream_call", "snap": 2.0},
		{"shot": "dream", "who": "神明", "text": "企鵝被關著給人拍照，森林一棵一棵倒下。你隔壁的嘉欣，也沒有去更好的地方。", "cue": "dream_world", "snap": 3.9},
		{"shot": "dream", "who": "家豪", "text": "……她還在嗎。", "cue": "dream_ask"},
		{"shot": "dream", "who": "神明", "text": "我不知道。門關上之後，我就看不到了。", "cue": "dream_door", "snap": 2.0},
		{"shot": "dream", "who": "神明", "text": "家豪，你是天選之雞。", "cue": "dream_chosen", "snap": 0.9},
		{"shot": "dream", "who": "家豪", "text": "你認錯了。我是這裡最沒用的一隻。", "cue": "dream_deny"},
		{"shot": "dream", "who": "神明", "text": "我要找的，就是被笑了還照樣爬上屋頂的那一隻。", "cue": "dream_roof", "snap": 1.8},
		{"shot": "dream", "who": "家豪", "text": "……", "cue": "dream_silent"},
		{"shot": "dream", "who": "神明", "text": "我不能替你打，但你往前走的時候，路上會剛好多出一些東西。", "cue": "dream_peel", "snap": 3.2},
		{"shot": "dream", "who": "家豪", "text": "……我不會輸。只是偶爾不想贏。", "cue": "dream_cool", "snap": 2.5},
		{"shot": "wake", "fade": "white", "who": "家豪", "text": "……做夢喔。也是，怎麼可能是我。", "cue": "wake_up"},
		{"shot": "wake", "who": "家豪", "text": "……好啦。", "cue": "wake_peel", "snap": 1.8},
		{"shot": "wake", "who": "家豪", "text": "我去看看那個更好的地方，到底長什麼樣子。", "cue": "wake_tag", "snap": 2.4},
		{"shot": "wake", "who": "家豪", "text": "……這波，就很你們懂吧。", "cue": "wake_go", "snap": 2.2},
	]

func _next_scene() -> String:
	return NEXT_SCENE

## 隱藏按鍵（展示用，畫面上不提示）：開場播到一半按 Shift＋E，直接跳去播結局
func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo and e.keycode == KEY_E and e.shift_pressed:
		if not _leaving and ResourceLoader.exists(ENDING_SCENE):
			_leaving = true
			get_tree().change_scene_to_file(ENDING_SCENE)
		return
	super(e)

func _skip_text() -> String:
	return "跳過開場"

var _farm: Dictionary = {}
var _barn: Node3D
var _dream: Node3D
var _env_dusk: Environment
var _env_barn: Environment
var _env_dream: Environment

var _hero: Dictionary = {}
var _cock: Dictionary = {}
var _chick: Dictionary = {}
var _hens: Array = []            # 屋頂那場，地上的母雞
var _sleepers: Array = []        # 雞舍裡睡著的母雞
var _ghost: Dictionary = {}      # 嘉欣（只是家豪想起來的樣子）
var _ghost_mat: StandardMaterial3D
var _mini: Dictionary = {}       # 夢裡那個小小的屋頂上的小家豪

var _tag66: Node3D
var _barn_peel: Node3D
var _tubes: Array = []           # 雞舍的日光燈 {mat, light}
var _notes_t := 0.0
var _zzz_t := 0.0

var _god: Node3D
var _god_light: OmniLight3D
var _beam: MeshInstance3D
var _spot: SpotLight3D
var _vis: Dictionary = {}        # 夢裡的四個畫面：penguin / forest / shed / roof
var _trees: Array = []
var _shed_door: Node3D
var _dream_peel: Node3D
var _flash_t := 0.0

func _actor_of(who: String) -> Dictionary:
	match who:
		"家豪": return _hero
		"公雞": return _cock
	return {}

func _build() -> void:
	_sun = get_node_or_null("Moon") as DirectionalLight3D
	_build_roof()
	_build_barn()
	_build_dream()
	_make_sounds()

func B(v: Vector3) -> Vector3:
	return v + Vector3(0, 0, BARN_Z)

func D(v: Vector3) -> Vector3:
	return v + Vector3(0, 0, DREAM_Z)

# ================================================================== 屋頂

func _build_roof() -> void:
	_farm = _build_farm(self)
	# 黃昏：上面深藍紫、地平線橘紅，太陽在雞舍後面（角色是逆光的剪影）
	_env_dusk = _make_env(Color(0.17, 0.19, 0.46), Color(1.0, 0.60, 0.34), Color(0.80, 0.64, 0.76), 1.0, Color(0.98, 0.64, 0.46), 0.0035)
	for c in _farm.clouds:
		_paint(c, _glow(Color(1.0, 0.72, 0.60)))
	_hero = _actor(self, "hero", _ridge(_farm, 1.1), 0.0)
	_leg_tag(_hero, "67")
	_cock = _actor(self, "rooster", Vector3(-1.4, 0, 6.0), 0.0, 1.12)
	for p in [Vector3(-3.6, 0, 5.2), Vector3(-5.2, 0, 3.4), Vector3(1.8, 0, 6.6), Vector3(3.2, 0, 4.6), Vector3(-2.4, 0, 3.2)]:
		var h := _actor(self, "hen", p, 0.0, HEN_S)
		h["home"] = p
		_hens.append(h)
	_chick = _actor(self, "chick", Vector3(0.2, 0, 6.9), 0.0)

func _roof_people(on: bool) -> void:
	for a in [_cock, _chick] + _hens:
		(a.node as Node3D).visible = on

## 把天上那顆太陽擺到「從鏡頭看過去剛好在 target 後面」
func _sun_behind(cam_pos: Vector3, target: Vector3, lift := 0.0) -> void:
	var d := (target - cam_pos).normalized()
	(_farm.sun as Node3D).global_position = cam_pos + d * 150.0 + Vector3(0, lift, 0)

func _hero_top() -> Vector3:
	return _ridge(_farm, 1.1) + Vector3(0, 1.0, 0)

# ================================================================== 夜裡的雞舍

func _build_barn() -> void:
	_barn = Node3D.new()
	_barn.name = "Barn"
	_barn.position = Vector3(0, 0, BARN_Z)
	add_child(_barn)
	_env_barn = _make_env(Color(0.02, 0.03, 0.07), Color(0.05, 0.07, 0.14), Color(0.50, 0.58, 0.80), 0.5, Color(0.1, 0.12, 0.2), 0.0, 0.6)
	var wood := _toon(Color(0.56, 0.39, 0.26))
	var wood_l := _toon(Color(0.68, 0.50, 0.33))
	var dark := _toon(Color(0.36, 0.24, 0.16))
	var straw := _toon(Color(0.88, 0.74, 0.40))
	var straw2 := _toon(Color(0.80, 0.64, 0.32))
	_box(_barn, Vector3(11.4, 0.1, 9.0), Vector3(0, -0.05, 0.9), _toon(Color(0.50, 0.38, 0.26)))
	_box(_barn, Vector3(10.6, 0.08, 6.4), Vector3(0, 0.04, -0.1), straw2)
	# 後牆（木板一條一條）、左牆、右牆（留一個門）
	_box(_barn, Vector3(11.4, 4.4, 0.2), Vector3(0, 2.2, -3.2), wood)
	for i in 8:
		_box(_barn, Vector3(11.2, 0.03, 0.04), Vector3(0, 0.5 + i * 0.5, -3.08), dark)
	_box(_barn, Vector3(0.2, 4.4, 8.8), Vector3(-5.6, 2.2, 1.0), wood)
	_box(_barn, Vector3(0.2, 4.4, 3.2), Vector3(5.6, 2.2, -1.7), wood)
	_box(_barn, Vector3(0.2, 4.4, 4.0), Vector3(5.6, 2.2, 3.5), wood)
	_box(_barn, Vector3(0.2, 2.0, 1.7), Vector3(5.6, 3.4, 0.7), wood)
	for z in [-0.18, 1.58]:
		_box(_barn, Vector3(0.3, 2.5, 0.16), Vector3(5.55, 1.25, z), dark)
	_box(_barn, Vector3(0.3, 0.16, 1.92), Vector3(5.55, 2.48, 0.7), dark)
	_box(_barn, Vector3(11.4, 0.2, 9.0), Vector3(0, 4.4, 0.9), dark)
	for x in [-3.95, 3.95]:
		_box(_barn, Vector3(0.26, 4.4, 0.26), Vector3(x, 2.2, -3.02), dark)
	for x in [-3.7, 0.0, 3.7]:
		_box(_barn, Vector3(0.22, 0.22, 8.6), Vector3(x, 4.2, 1.0), dark)
	# 門外：月光
	_box(_barn, Vector3(0.05, 7.0, 9.0), Vector3(9.4, 2.4, 0.7), _glow(Color(0.07, 0.11, 0.30)))
	_ball(_barn, 0.42, Vector3(9.2, 2.2, 0.2), _glow(Color(1.5, 1.5, 1.3)))
	for k in 9:
		_ball(_barn, 0.03, Vector3(9.3, 1.3 + fmod(k * 0.77, 1.5), -0.6 + fmod(k * 1.31, 2.6)), _glow(Color(1, 1, 0.9)), Vector3.ONE, 6)
	_ball(_barn, 1.5, Vector3(9.0, -0.5, 2.6), _glow(Color(0.04, 0.08, 0.16)), Vector3(1, 1.2, 1.4), 10)
	_box(_barn, Vector3(3.0, 0.06, 1.9), Vector3(7.0, -0.02, 0.7), _toon(Color(0.30, 0.42, 0.34)))
	var moon := OmniLight3D.new()
	moon.position = Vector3(5.0, 1.6, 0.7)
	moon.light_color = Color(0.55, 0.70, 1.0)
	moon.light_energy = 2.4
	moon.omni_range = 5.5
	_barn.add_child(moon)
	# 一格一格的窩：隔板、稻草窩、牆上的號碼牌
	for k in STALL_X.size():
		var x: float = STALL_X[k]
		_ball(_barn, 0.56, Vector3(x, 0.10, -2.3), straw, Vector3(1.0, 0.3, 0.95), 12)
		_torus(_barn, 0.36, 0.56, Vector3(x, 0.17, -2.3), straw2, Vector3.ZERO)
		_box(_barn, Vector3(0.62, 0.36, 0.05), Vector3(x, 1.5, -3.06), wood_l)
		var num := Label3D.new()
		num.text = STALL_NUM[k]
		if UIStyle.font():
			num.font = UIStyle.font()
		num.font_size = 72
		num.pixel_size = 0.0034
		num.modulate = Color(0.22, 0.14, 0.09)
		num.outline_size = 0
		num.position = Vector3(x, 1.5, -3.03)
		_barn.add_child(num)
	for k in STALL_X.size() + 1:
		var x := -3.25 + k * 1.3
		_box(_barn, Vector3(0.07, 1.0, 1.5), Vector3(x, 0.5, -2.4), wood_l)
		_box(_barn, Vector3(0.11, 0.08, 1.56), Vector3(x, 1.02, -2.4), dark)
	# 散在地上的稻草
	for k in 46:
		var a := k * 2.39996
		var r := 0.6 + sqrt(float(k)) * 0.62
		_box(_barn, Vector3(0.5, 0.03, 0.04), Vector3(cos(a) * r, 0.09, 0.2 + sin(a) * r * 0.55), straw, Vector3(0, a, 0))
	for p in [Vector3(-4.6, 0.36, 1.4), Vector3(-4.3, 0.3, 2.6), Vector3(-4.8, 0.3, -0.4)]:
		_ball(_barn, 0.7, p, straw, Vector3(1.2, 0.72, 1.0), 12)
	# 日光燈：從來不關（偶爾閃一下）
	for x in [-2.3, 2.3]:
		var tm := _glow(Color(0.92, 0.98, 1.0))
		_box(_barn, Vector3(2.6, 0.09, 0.14), Vector3(x, 3.55, -0.9), tm)
		_box(_barn, Vector3(2.8, 0.06, 0.26), Vector3(x, 3.63, -0.9), _toon(Color(0.24, 0.26, 0.3)))
		for dx in [-1.1, 1.1]:
			_box(_barn, Vector3(0.02, 0.6, 0.02), Vector3(x + dx, 3.96, -0.9), dark)
		var l := OmniLight3D.new()
		l.position = Vector3(x, 3.2, -1.0)
		l.light_color = Color(0.84, 0.94, 1.0)
		l.light_energy = 1.7
		l.omni_range = 8.5
		l.shadow_enabled = x < 0.0
		_barn.add_child(l)
		_tubes.append({"mat": tm, "light": l})
	# 睡在窩裡的母雞（腳上都有號碼牌）
	for k in [0, 1, 4]:
		var h := _actor(self, "hen", B(Vector3(STALL_X[k], 0.1, -2.25)), 0.25 * (k - 2), HEN_S)
		h.anim = "sleep"
		var tag := _foot_tag(STALL_NUM[k])
		(h.node as Node3D).add_child(tag)
		tag.position = Vector3(0.17, 0.13, 0.43)
		tag.rotation = Vector3(-0.25, 0.3, 0.1)
		tag.scale = Vector3.ONE * 0.8
		_sleepers.append(h)
	# 六十六號那一格：空的，只剩一塊扯斷的腳牌
	_tag66 = _foot_tag("66", true)
	add_child(_tag66)
	# 嘉欣：家豪想起來的樣子（半透明）
	_ghost = _actor(self, "hen", B(Vector3(STALL_X[2], 0.1, -2.25)), 0.5, HEN_S)
	_ghost_mat = _glow(Color(0.86, 0.94, 1.0), 0.0)
	_ghost_mat.cull_mode = BaseMaterial3D.CULL_BACK
	_paint(_ghost.node, _ghost_mat)
	_no_shadow(_ghost.node)
	(_ghost.node as Node3D).visible = false
	_barn_peel = _peel(self, B(Vector3(-0.28, 0.2, -2.05)), 0.8)

func _place_tag_on_straw() -> void:
	if _tag66.get_parent() != self:
		_tag66.reparent(self)
	_tag66.global_position = B(Vector3(0.2, 0.33, -1.86))
	_tag66.rotation = Vector3(-0.62, 0.3, 0.16)
	_tag66.scale = Vector3.ONE * 1.7

## 腳牌掛到家豪脖子上
func _hang_tag() -> void:
	var upper := (_hero.node as Node3D).find_child("Upper", true, false) as Node3D
	if upper == null:
		return
	_tag66.reparent(upper)
	_tag66.position = Vector3(0.115, 0.47, 0.335)
	_tag66.rotation = Vector3(0.12, 0.0, -0.18)
	_tag66.scale = Vector3.ONE * 0.5

func _hero_in_stall(lying: bool) -> void:
	var n := _hero.node as Node3D
	n.position = B(Vector3(STALL_X[3], 0.16, -2.2))
	n.rotation = Vector3(0, -0.45, 1.35) if lying else Vector3(0, -0.45, 0)

# ================================================================== 夢境

func _build_dream() -> void:
	_dream = Node3D.new()
	_dream.name = "Dream"
	_dream.position = Vector3(0, 0, DREAM_Z)
	add_child(_dream)
	_env_dream = _make_env(Color(0.26, 0.20, 0.58), Color(0.90, 0.74, 0.96), Color(0.96, 0.90, 1.0), 1.1, Color(0.90, 0.82, 1.0), 0.012, 0.9)
	# 雲海
	var r := RandomNumberGenerator.new()
	r.seed = 3
	var cloud := _toon(Color(0.99, 0.97, 1.0))
	var pm := PlaneMesh.new()
	pm.size = Vector2(120, 120)
	_mesh(_dream, pm, Vector3(0, -0.04, 0), _toon(Color(0.97, 0.94, 1.0)))
	for k in 70:
		var cs := r.randf_range(0.7, 1.5)
		var p := Vector3(r.randf_range(-18, 18), 0.0, r.randf_range(-20, 9))
		# 雲的頂端大約跟腳一樣高；離中間越遠可以越高
		p.y = r.randf_range(0.0, 0.25) + maxf(Vector2(p.x, p.z - 1.5).length() - 5.0, 0.0) * 0.07 - 1.6 * cs
		var c := _glb(_dream, CLOUDS % ["a", "b", "c"][k % 3], p, r.randf_range(0, TAU), cs)
		if c:
			_paint(c, cloud)
			_no_shadow(c)
	for k in 24:
		var br := r.randf_range(0.8, 1.6)
		_ball(_dream, br, Vector3(r.randf_range(-7, 7), -br * 0.5 + r.randf_range(-0.05, 0.1), r.randf_range(-3, 7)), cloud, Vector3(1.5, 0.5, 1.3))
	# 星星
	for k in 60:
		var a := r.randf_range(0.0, TAU)
		_ball(_dream, r.randf_range(0.04, 0.11), Vector3(cos(a) * r.randf_range(8, 30), r.randf_range(5, 20), -6.0 + sin(a) * r.randf_range(6, 26)), _glow(Color(1.0, 0.96, 0.8)), Vector3.ONE, 6)
	# 從天而降的光柱
	var cm := CylinderMesh.new()
	cm.top_radius = 1.4
	cm.bottom_radius = 2.6
	cm.height = 34
	cm.cap_top = false
	cm.cap_bottom = false
	_beam = _mesh(_dream, cm, Vector3(0, 16, -3), _glow(Color(1.0, 0.92, 0.6), 0.22, true))
	# 神明：一團看不清楚的光，外面兩圈光環、一圈小光點、幾道往外的光芒
	_god = Node3D.new()
	_god.position = Vector3(0, 3.0, -3)
	_dream.add_child(_god)
	_ball(_god, 0.9, Vector3.ZERO, _glow(Color(2.4, 1.8, 0.8)), Vector3(0.85, 1.25, 0.85), 20)
	_ball(_god, 0.5, Vector3(0, 1.45, 0), _glow(Color(2.6, 2.1, 1.1)), Vector3.ONE, 16)
	_ball(_god, 1.7, Vector3(0, 0.4, 0), _glow(Color(1.0, 0.9, 0.55), 0.20, true), Vector3.ONE, 18)
	_ball(_god, 2.6, Vector3(0, 0.4, 0), _glow(Color(1.0, 0.86, 0.5), 0.08, true), Vector3.ONE, 18)
	for k in 2:
		var halo := _torus(_god, 1.25 + k * 0.45, 1.33 + k * 0.45, Vector3(0, 0.4, 0), _glow(Color(1.0, 0.86, 0.42), 0.85, true), Vector3(PI * 0.5 - 0.3 * k, 0, 0.2 * k))
		halo.name = "Halo%d" % k
	for k in 8:
		var orb := _ball(_god, 0.08, Vector3.ZERO, _glow(Color(1.0, 0.96, 0.72)), Vector3.ONE, 8)
		orb.name = "Orb%d" % k
	var rays := Node3D.new()
	rays.name = "Rays"
	rays.position = Vector3(0, 0.4, -0.3)
	_god.add_child(rays)
	for k in 10:
		var ray := _cyl(rays, 0.0, 0.16, 3.4, Vector3.ZERO, _glow(Color(1.0, 0.9, 0.6), 0.16, true), Vector3.ZERO, 6)
		var a := TAU * float(k) / 10.0
		ray.position = Vector3(cos(a), sin(a), 0) * 2.6
		ray.rotation.z = a + PI * 0.5
	_no_shadow(_god)
	_god_light = OmniLight3D.new()
	_god_light.position = Vector3(0, 3.6, -1.4)
	_god_light.light_color = Color(1.0, 0.9, 0.7)
	_god_light.light_energy = 2.4
	_god_light.omni_range = 15.0
	_dream.add_child(_god_light)
	# 「天選之雞」的聚光燈
	_spot = SpotLight3D.new()
	_spot.position = Vector3(-0.9, 8.0, 2.2)
	_spot.rotation.x = -PI * 0.5
	_spot.light_color = Color(1.0, 0.94, 0.7)
	_spot.light_energy = 0.0
	_spot.spot_range = 12.0
	_spot.spot_angle = 16.0
	_dream.add_child(_spot)
	# 神明給他看的畫面：一顆一顆的泡泡，裡面是小小的景
	_vis["penguin"] = _vision(Vector3(-3.7, 2.1, -0.8))
	var cage := _glb(_vis.penguin, "res://levels/ice/assets/blender/cage.glb", Vector3(0, -0.55, 0), 0.4, 0.4)
	_no_shadow(cage)
	var pg := _glb(_vis.penguin, "res://levels/ice/assets/kenney_cubepets/animal-penguin.glb", Vector3(0, -0.5, 0), 0.4, 0.36)
	_no_shadow(pg)
	var fl := _ball(_vis.penguin, 0.5, Vector3(0.9, 0.5, 0.9), _glow(Color(1, 1, 1), 0.0, true), Vector3.ONE, 10)
	fl.name = "Flash"
	_vis["forest"] = _vision(Vector3(3.7, 2.1, -0.8))
	for k in 3:
		var pivot := Node3D.new()
		pivot.position = Vector3(-0.5 + k * 0.5, -0.42, 0.25 - 0.2 * (k % 2))
		_vis.forest.add_child(pivot)
		var tr := _glb(pivot, "res://levels/fort/assets/castle/tree-large.glb", Vector3.ZERO, k * 1.3, 0.62)
		_no_shadow(tr)
		_trees.append(pivot)
		_no_shadow(_glb(_vis.forest, "res://levels/fort/assets/castle/tree-trunk.glb", pivot.position, 0.0, 0.5))
	_vis["shed"] = _vision(Vector3(1.5, 1.35, 0.4))
	var shed := _glb(_vis.shed, FARM + "SmallBarn.glb", Vector3(0, -0.62, -0.1), 0.0, 0.2)
	_paint(shed, _toon(Color(0.56, 0.60, 0.66)))
	_no_shadow(shed)
	_box(_vis.shed, Vector3(0.5, 0.56, 0.04), Vector3(0, -0.34, 0.52), _glow(Color(0.03, 0.03, 0.05)))
	_shed_door = _box(_vis.shed, Vector3(0.52, 0.6, 0.05), Vector3(0.56, -0.33, 0.56), _toon(Color(0.42, 0.45, 0.5)))
	var t66 := _foot_tag("66", true)
	_vis.shed.add_child(t66)
	t66.position = Vector3(-0.42, -0.5, 0.72)
	t66.rotation = Vector3(-0.3, 0.3, 0.2)
	t66.scale = Vector3.ONE * 1.3
	_vis["roof"] = _vision(Vector3(2.9, 2.7, -1.6))
	_no_shadow(_glb(_vis.roof, FARM + "ChickenCoop.glb", Vector3(0, -0.72, 0), PI * 0.5, 0.42))
	_mini = _actor(_vis.roof, "hero", Vector3(0.15, 0.06, 0.0), 0.0, 0.2)
	_mini.anim = "dj"
	_no_shadow(_mini.node)
	_dream_peel = _peel(_dream, Vector3(-0.5, 0.05, 1.0), 0.9)
	_dream_peel.visible = false

## 一顆泡泡（裡面再放小模型）。一開始縮到看不見
func _vision(pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	_dream.add_child(n)
	var bubble := _ball(n, 1.05, Vector3.ZERO, _glow(Color(0.86, 0.94, 1.0), 0.13), Vector3.ONE, 22)
	bubble.name = "Bubble"
	_torus(n, 1.03, 1.08, Vector3.ZERO, _glow(Color(1.0, 0.9, 0.55), 0.7, true), Vector3(PI * 0.5, 0, 0))
	var puff := _glb(n, CLOUDS % "b", Vector3(0, -0.92, 0), 0.0, 0.24)
	if puff:
		_paint(puff, _toon(Color(1, 1, 1)))
	_no_shadow(n)
	n.scale = Vector3.ONE * 0.001
	n.visible = false
	return n

func _vis_show(key: String, on: bool, delay := 0.0) -> void:
	var n := _vis[key] as Node3D
	var tw := _tw()
	if delay > 0.0:
		tw.tween_interval(delay)
	if on:
		tw.tween_callback(func():
			n.visible = true
			_play("pop", -10.0, 1.2))
		tw.tween_property(n, "scale", Vector3.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		tw.tween_property(n, "scale", Vector3.ONE * 0.001, 0.25)
		tw.tween_callback(func(): n.visible = false)

func _vis_reset() -> void:
	for key in _vis:
		var n := _vis[key] as Node3D
		n.visible = false
		n.scale = Vector3.ONE * 0.001
	for t in _trees:
		(t as Node3D).rotation = Vector3.ZERO
	_shed_door.position.x = 0.56
	((_vis.shed as Node3D).get_node("Bubble") as MeshInstance3D).material_override = _glow(Color(0.86, 0.94, 1.0), 0.13)

func _god_show(on: bool) -> void:
	_god.visible = on
	_god.scale = Vector3.ONE
	_god_light.light_energy = 2.4 if on else 0.5
	_beam.visible = true

# ================================================================== 換鏡頭

func _enter_shot(s: String) -> void:
	(_farm.root as Node3D).visible = s == "roof"
	_barn.visible = s == "barn" or s == "wake"
	_dream.visible = s == "dream"
	_roof_people(s == "roof")
	for h in _sleepers:
		(h.node as Node3D).visible = _barn.visible
	(_ghost.node as Node3D).visible = false
	_tag66.visible = _barn.visible or _tag66.get_parent() != self
	_barn_peel.visible = s == "wake"
	_hero.look = null
	(_hero.body as Node3D).rotation = Vector3.ZERO
	match s:
		"roof":
			_light(_env_dusk, Color(1.0, 0.64, 0.38), 1.6, Vector3(-0.30, PI - 0.4, 0))
			(_hero.node as Node3D).position = _ridge(_farm, 1.1)
			(_hero.node as Node3D).rotation = Vector3.ZERO
			(_cock.node as Node3D).position = Vector3(-1.4, 0, 6.0)
			_face(_cock, _hero_top())
			for h in _hens:
				(h.node as Node3D).position = h.home
				_face(h, _hero_top())
			_face(_chick, _hero_top())
		"barn":
			_light(_env_barn, Color(1, 1, 1), 0.0, Vector3(-1, 0, 0))
			_place_tag_on_straw()
			_hero_in_stall(false)
		"dream":
			_light(_env_dream, Color(1.0, 0.95, 0.86), 0.9, Vector3(-1.0, 0.5, 0))
			(_hero.node as Node3D).position = D(Vector3(-0.9, 0.0, 2.2))
			(_hero.node as Node3D).rotation = Vector3(0, PI, 0)
			_vis_reset()
			_dream_peel.visible = false
			_spot.light_energy = 0.0
		"wake":
			_light(_env_barn, Color(1, 1, 1), 0.0, Vector3(-1, 0, 0))
			_place_tag_on_straw()
			_hero_in_stall(true)

# ================================================================== 每一句演什麼

func _on_line(l: Dictionary) -> void:
	var hero := _hero.node as Node3D
	match String(l.get("cue", "")):
		# ---------------------------------------------------------- 屋頂
		"roof_call":
			# 遠遠看：屋頂上一個逆光的小身影在亂比，下面一隻公雞在喊
			var cp := Vector3(-9.0, 2.6, 14.5)
			_shot_cam(cp, Vector3(-0.2, 2.0, 2.0), 40.0, 0.0, Vector3(0.22, 0.0, -0.22))
			_sun_behind(cp, _hero_top(), 4.0)
			_set_anim(_hero, "dj")
			_set_anim(_cock, "yell")
			_cock.look = _hero_top()
			for h in _hens:
				_set_anim(h, "peck" if int(h.ph * 10.0) % 2 == 0 else "idle")
			_set_anim(_chick, "lookup")
		"roof_air":
			# 靠近看家豪：越比越誇張，音符一顆一顆掉下來（沒有聲音）
			var cp2 := Vector3(3.6, float(_farm.ridge_y) + 0.35, 6.4)
			_shot_cam(cp2, _hero_top() + Vector3(0, -0.15, 0), 33.0, 0.0, Vector3(-0.14, 0.0, -0.05))
			_sun_behind(cp2, _hero_top(), 9.0)
			_set_anim(_hero, "dj_big")
		"roof_cool":
			var cp3 := Vector3(2.7, float(_farm.ridge_y) + 1.15, 3.2)
			_shot_cam(cp3, _hero_top() + Vector3(0, 0.05, 0), 27.0, 0.0, Vector3(-0.05, 0, -0.06))
			_sun_behind(cp3, _hero_top(), 14.0)
			_set_anim(_hero, "cool")
			hero.rotation.y = 0.5
		"roof_none":
			# 地上：公雞氣到拍翅膀，母雞一隻一隻搖頭；只有小雞偷偷在學
			_shot_cam(Vector3(2.4, 1.5, 11.6), Vector3(-1.9, 0.35, 4.8), 40.0, 0.0, Vector3(-0.1, 0, -0.1))
			_set_anim(_cock, "flap")
			_cock.look = null
			_face(_cock, Vector3(2.4, 0, 11.6), 0.3)
			for k in _hens.size():
				var h: Dictionary = _hens[k]
				_set_anim(h, "shake")
				_at(0.25 + 0.22 * k, func():
					_emote(h, "？", Color(1.0, 0.9, 0.5), 1.4, 0.8)
					_play("pop", -14.0, 0.9 + 0.06 * k))
			_set_anim(_chick, "dj")
			_at(1.6, func(): _set_anim(_cock, "yell"))
		"roof_row":
			# 母雞擠成一排，都抬頭看屋頂；最右邊空一格
			_shot_cam(Vector3(-2.2, 1.8, 11.2), Vector3(-2.9, 0.3, 3.8), 38.0, 0.0, Vector3(0.08, 0, 0))
			_set_anim(_cock, "shrug")
			(_cock.node as Node3D).position = Vector3(0.6, 0, 5.4)
			_face(_cock, _hero_top())
			_cock.look = _hero_top()
			for k in _hens.size():
				var h: Dictionary = _hens[k]
				var to := Vector3(-6.4 + k * 0.98, 0, 3.8)
				_set_anim(h, "idle")
				_hop(h, to, 0.42, 0.5, 0.12 * k, "lookup")
				_at(0.12 * k + 0.45, func():
					_face(h, Vector3(to.x, 0, 12.0))
					_play("thud", -20.0, 1.6))
			_set_anim(_chick, "idle")
			(_chick.node as Node3D).position = Vector3(1.6, 0, 6.2)
		"roof_alone":
			# 回到屋頂：他轉過去背對大家，對著太陽繼續比
			var cp4 := Vector3(-0.7, 2.6, 11.5)
			_shot_cam(cp4, _hero_top() + Vector3(0, -1.5, 0), 36.0, 0.0, Vector3(0.05, 0.03, -0.28))
			_sun_behind(cp4, _hero_top(), 1.5)
			_set_anim(_hero, "still")
			hero.rotation.y = 0.5
			_at(0.7, func(): _face(_hero, _hero_top() + Vector3(0.3, 0, -20), 0.7))
			_at(1.6, func(): _set_anim(_hero, "dj", 0.8))
		# ---------------------------------------------------------- 雞舍
		"barn_wide":
			_shot_cam(B(Vector3(-0.6, 2.9, 6.2)), B(Vector3(0.3, 0.3, -2.0)), 42.0, 0.0, Vector3(0.12, -0.03, -0.22))
			_set_anim(_hero, "sad")
			_hero.look = B(Vector3(0.2, 0.2, -1.9))
		"barn_tag":
			_shot_cam(B(Vector3(0.9, 1.1, 0.9)), B(Vector3(0.25, 0.05, -1.95)), 26.0, 2.2)
			_at(1.9, func():
				_emote(B(Vector3(0.45, 0.5, -1.9)), "✦", Color(1.0, 0.95, 0.6), 0.9, 0.6, 0.15)
				_play("ding", -14.0))
		"barn_ghost":
			# 他看著空的那一格，想起嘉欣歪著頭問他的樣子
			_shot_cam(B(Vector3(1.9, 1.5, 2.1)), B(Vector3(0.65, 0.5, -2.2)), 36.0, 0.0, Vector3(-0.05, 0, -0.06))
			_set_anim(_hero, "idle")
			var g := _ghost.node as Node3D
			_hero.look = g.global_position + Vector3(0, 0.7, 0)
			g.visible = true
			_ghost_mat.albedo_color.a = 0.0
			_set_anim(_ghost, "idle")
			_ghost.look = hero.global_position + Vector3(0, 0.9, 0)
			var tw := _tw()
			tw.tween_property(_ghost_mat, "albedo_color:a", 0.5, 0.7)
			tw.tween_callback(func(): _emote(_ghost, "♪？", Color(0.82, 0.94, 1.0), 1.8, 0.75))
			tw.tween_interval(2.4)
			tw.tween_property(_ghost_mat, "albedo_color:a", 0.0, 1.0)
			tw.tween_callback(func():
				g.visible = false
				_set_anim(_hero, "sad")
				_hero.look = null)
			tw.tween_interval(0.6)
			tw.tween_callback(func():
				# 躺下來睡
				_set_anim(_hero, "sleep")
				_hero_in_stall(true)
				_emote(_hero, "Zzz", Color(0.85, 0.9, 1.0), 2.0, 0.7))
		# ---------------------------------------------------------- 夢
		"dream_call":
			# 他站在雲海上，不知道誰在叫他；光打下來才抬頭
			_god_show(false)
			_shot_cam(D(Vector3(0.5, 1.25, -0.8)), D(Vector3(-0.9, 0.6, 2.2)), 36.0, 0.0, Vector3(0.03, 0.03, -0.05))
			_set_anim(_hero, "idle")
			_at(0.3, func():
				_emote(_hero, "？", Color(1, 1, 1), 1.1, 0.9)
				_play("pop", -12.0))
			_at(1.5, func():
				_set_anim(_hero, "lookup")
				_god_light.light_energy = 2.0
				_flash(Color(1.0, 0.95, 0.8), 0.35, 0.6))
		"dream_world":
			# 從他背後看出去：神明現身，三顆泡泡一顆一顆冒出來
			_god_show(true)
			_god.scale = Vector3.ONE * 0.05
			_tw().tween_property(_god, "scale", Vector3.ONE, 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			_flash(Color(1.0, 0.95, 0.8), 0.6, 0.7)
			_play("ding", -10.0, 0.7)
			_shot_cam(D(Vector3(0.9, 2.7, 7.4)), D(Vector3(0.1, 1.5, -2.0)), 46.0, 0.0, Vector3(0, 0.02, -0.07))
			_set_anim(_hero, "lookup")
			_vis_show("penguin", true, 0.5)
			_vis_show("forest", true, 2.0)
			_vis_show("shed", true, 3.5)
			for k in _trees.size():
				var tw2 := _tw()
				tw2.tween_interval(2.7 + 0.7 * k)
				tw2.tween_property(_trees[k], "rotation:x", 1.35, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
				tw2.tween_callback(func(): _play("thud", -18.0, 1.3))
		"dream_ask":
			_shot_cam(D(Vector3(0.7, 1.4, 0.0)), D(Vector3(-0.9, 0.75, 2.2)), 30.0, 0.0, Vector3(0.02, 0, -0.03))
			_set_anim(_hero, "idle")
			_hero.look = (_vis.shed as Node3D).global_position
		"dream_door":
			# 鐵皮屋的門關上，那顆泡泡暗下來
			var sp := (_vis.shed as Node3D).global_position
			_shot_cam(sp + Vector3(-0.6, 0.5, 4.0), sp + Vector3(0, -0.75, 0), 30.0, 0.0, Vector3(0.03, 0, -0.05))
			var tw3 := _tw()
			tw3.tween_interval(0.7)
			tw3.tween_property(_shed_door, "position:x", 0.0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tw3.tween_callback(func():
				_play("thud", -8.0, 0.8)
				_shake = 0.5
				((_vis.shed as Node3D).get_node("Bubble") as MeshInstance3D).material_override = _glow(Color(0.25, 0.27, 0.36), 0.5))
		"dream_chosen":
			# 聚光燈打在他身上，大字蓋下來；他嚇一跳，然後指指自己
			for key in ["penguin", "forest", "shed"]:
				_vis_show(key, false)
			_shot_cam(D(Vector3(-0.1, 0.9, -1.5)), D(Vector3(-0.9, 0.7, 2.2)), 44.0, 0.0, Vector3(0.0, 0.0, 0.05))
			_hero.look = null
			_set_anim(_hero, "shock")
			_spot.light_energy = 4.0
			_shake = 0.7
			_play("ding", -6.0)
			_stamp("天選之雞", Color(1.0, 0.84, 0.30), 1.5, 112, -215.0)
			_at(1.5, func():
				_set_anim(_hero, "point")
				_emote(_hero, "？", Color(1, 1, 1), 1.2, 0.9)
				_play("pop", -12.0))
		"dream_deny":
			_shot_cam(D(Vector3(-3.3, 1.35, 0.6)), D(Vector3(-0.9, 0.55, 2.2)), 33.0, 0.0, Vector3(0.06, 0, 0))
			_spot.light_energy = 3.0
			_set_anim(_hero, "shrug")
			_at(1.3, func(): _set_anim(_hero, "sad"))
		"dream_roof":
			# 神明旁邊冒出一顆泡泡：小小的屋頂上，小小的家豪還在比
			_spot.light_energy = 0.0
			_shot_cam(D(Vector3(-0.6, 2.4, 4.8)), D(Vector3(1.2, 2.2, -2.4)), 36.0, 0.0, Vector3(0.03, 0.01, -0.12))
			_set_anim(_hero, "lookup")
			_vis_show("roof", true, 0.4)
		"dream_silent":
			# 很近的特寫：他抬著頭，什麼都沒說
			_vis_show("roof", false)
			_shot_cam(D(Vector3(-0.35, 1.55, 0.4)), D(Vector3(-0.9, 1.05, 2.2)), 21.0, 0.0, Vector3(-0.015, 0, 0.05))
			_set_anim(_hero, "lookup")
		"dream_peel":
			# 光裡面慢慢飄下來一片香蕉皮，落在他前面
			_shot_cam(D(Vector3(1.7, 1.35, -1.2)), D(Vector3(-0.75, 0.55, 1.5)), 38.0, 0.0, Vector3(-0.03, 0, 0.03))
			_set_anim(_hero, "lookup")
			_dream_peel.visible = true
			_dream_peel.position = Vector3(-0.1, 3.4, -1.6)
			_hero.look = D(Vector3(-0.3, 2.2, -0.4))
			var land := Vector3(-0.62, 0.06, 0.9)
			var tw4 := _tw()
			tw4.set_parallel(true)
			tw4.tween_property(_dream_peel, "position", land, 2.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			tw4.tween_property(_dream_peel, "rotation:y", 7.0, 2.3)
			tw4.chain().tween_callback(func():
				_play("pop", -8.0, 0.8)
				_emote(D(land + Vector3(0, 0.5, 0)), "✦", Color(1.0, 0.95, 0.5), 0.9, 0.7, 0.2)
				_hero.look = D(land)
				_set_anim(_hero, "idle"))
			tw4.chain().tween_interval(0.5)
			tw4.chain().tween_callback(func():
				_emote(_hero, "？", Color(1, 1, 1), 1.1, 0.9)
				_play("pop", -12.0))
		"dream_cool":
			# 耍帥說完，往前跨一步——踩到那片香蕉皮，整隻滑下雲海
			_dream_peel.visible = true
			_dream_peel.position = Vector3(-0.62, 0.06, 0.9)
			_shot_cam(D(Vector3(1.9, 1.4, -1.0)), D(Vector3(-0.8, 0.6, 1.6)), 38.0, 0.0, Vector3(0.0, 0.0, 0.03))
			_hero.look = null
			_set_anim(_hero, "cool")
			var tw5 := _tw()
			tw5.tween_interval(2.3)
			tw5.tween_callback(func(): _set_anim(_hero, "walk"))
			tw5.tween_property(hero, "position", D(Vector3(-0.75, 0.0, 1.15)), 0.45)
			tw5.tween_callback(func():
				_set_anim(_hero, "shock")
				_play("whoosh", -6.0)
				_emote(_hero, "！", Color(1.0, 0.5, 0.4), 0.9, 1.1)
				_shake = 0.8)
			tw5.set_parallel(true)
			tw5.tween_property(hero, "rotation:x", 1.5, 0.3)
			tw5.tween_property(_dream_peel, "position", Vector3(-0.4, 1.6, -1.8), 0.5)
			tw5.tween_property(_dream_peel, "rotation:x", 9.0, 0.5)
			tw5.tween_property(hero, "position", D(Vector3(-0.8, 1.0, 1.8)), 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw5.chain().tween_property(hero, "position", D(Vector3(-0.8, -4.0, 2.4)), 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tw5.chain().tween_callback(func(): _play("thud", -10.0, 0.7))
		# ---------------------------------------------------------- 醒來
		"wake_up":
			# 嚇醒，整隻彈起來
			_shot_cam(B(Vector3(2.9, 1.3, 1.2)), B(Vector3(1.25, 0.4, -2.2)), 32.0, 0.0, Vector3(-0.03, 0, -0.03))
			_hero_in_stall(false)
			_set_anim(_hero, "shock")
			_shake = 0.6
			_play("thud", -8.0)
			_emote(_hero, "！", Color(1.0, 0.9, 0.5), 0.9, 1.0)
			_hop(_hero, hero.position, 0.35, 0.45)
			_at(0.9, func(): _set_anim(_hero, "idle"))
			_at(2.0, func(): _set_anim(_hero, "sad"))
		"wake_peel":
			# 隔壁那一格：腳牌旁邊多了一片香蕉皮
			_shot_cam(B(Vector3(0.8, 1.15, 0.8)), B(Vector3(0.0, 0.0, -2.0)), 27.0, 1.2)
			_set_anim(_hero, "idle")
			_hero.look = B(Vector3(0.0, 0.2, -2.0))
			_at(0.9, func():
				_emote(B(Vector3(-0.3, 0.55, -2.0)), "✦", Color(1.0, 0.95, 0.5), 1.0, 0.7, 0.2)
				_play("ding", -12.0))
		"wake_tag":
			# 走過去撿起腳牌，掛在脖子上
			_shot_cam(B(Vector3(1.9, 1.25, 1.7)), B(Vector3(0.75, 0.5, -1.7)), 30.0, 0.0, Vector3(-0.04, 0, -0.05))
			_hero.look = null
			_hero_in_stall(false)
			_walk(_hero, B(Vector3(0.85, 0.12, -1.75)), 0.8, "peck")
			_at(1.5, func():
				_hang_tag()
				_play("pop", -8.0, 1.1)
				_set_anim(_hero, "idle")
				_face(_hero, B(Vector3(1.9, 0, 1.3)), 0.4))
			_at(2.0, func(): _emote(B(Vector3(1.1, 1.55, -1.5)), "✦", Color(1.0, 0.95, 0.5), 0.9, 0.6, 0.15))
		"wake_go":
			# 門口，月光裡的背影回頭看一眼；整個雞舍都還在睡
			_hang_tag()
			_shot_cam(B(Vector3(-2.6, 1.6, 2.3)), B(Vector3(3.6, 0.55, 0.2)), 40.0, 0.0, Vector3(0.1, 0, 0))
			hero.position = B(Vector3(3.0, 0.0, 0.5))
			hero.rotation = Vector3(0, PI * 0.5, 0)
			_hero.look = null
			_walk(_hero, B(Vector3(4.6, 0.0, 0.7)), 0.9, "cool")
			_at(1.0, func(): _face(_hero, B(Vector3(-2.0, 0, 1.2)), 0.5))
			_at(3.4, func():
				_set_anim(_hero, "walk")
				_face(_hero, B(Vector3(9.0, 0, 0.7)), 0.3))
			_at(3.8, func(): _tw().tween_property(hero, "position", B(Vector3(7.2, 0.0, 0.7)), 1.3))

# ================================================================== 每一畫面

func _tick(dt: float) -> void:
	# 屋頂：音符一顆一顆掉下來（沒有聲音）
	if _shot == "roof" and String(_hero.anim).begins_with("dj") and not _busy:
		_notes_t -= dt
		if _notes_t <= 0.0:
			_notes_t = 0.5
			var side := 1.0 if int(_t * 2.0) % 2 == 0 else -1.0
			var hp := (_hero.node as Node3D).global_position
			_emote(hp + Vector3(0.9 * side, 1.5, 0.2), "♪" if side > 0.0 else "♫", Color(0.80, 0.80, 0.86), 1.2, 0.62, -1.1)
	# 雞舍：睡著的雞頭上的 Z、日光燈偶爾閃一下
	if _barn.visible and not _busy:
		_zzz_t -= dt
		if _zzz_t <= 0.0:
			_zzz_t = 0.9
			var k := int(_t / 0.9) % maxi(_sleepers.size(), 1)
			if not _sleepers.is_empty():
				_emote(_sleepers[k], "Z", Color(0.85, 0.9, 1.0), 1.8, 0.55, 0.6)
		var flick := 1.0
		if fmod(_t, 5.3) < 0.12 or (fmod(_t, 5.3) > 0.2 and fmod(_t, 5.3) < 0.26):
			flick = 0.55
		for tb in _tubes:
			(tb.light as OmniLight3D).light_energy = 1.7 * flick
			(tb.mat as StandardMaterial3D).albedo_color = Color(0.92, 0.98, 1.0) * (0.6 + 0.4 * flick)
	# 夢：神明浮著、光環和光點在轉、泡泡輕輕晃；企鵝那顆有閃光燈
	if _dream.visible:
		_god.position.y = 3.0 + sin(_t * 1.2) * 0.15
		for k in 2:
			(_god.get_node("Halo%d" % k) as Node3D).rotate_y(dt * (0.6 + k * 0.4))
		for k in 8:
			var o := _god.get_node("Orb%d" % k) as Node3D
			var a := _t * 0.8 + k * TAU / 8.0
			o.position = Vector3(cos(a) * 2.2, 0.4 + sin(a * 2.0) * 0.5, sin(a) * 2.2)
		(_god.get_node("Rays") as Node3D).rotation.z = _t * 0.15
		(_god.get_node("Rays") as Node3D).scale = Vector3.ONE * (1.0 + 0.06 * sin(_t * 2.0))
		var i := 0
		for key in _vis:
			var n := _vis[key] as Node3D
			n.rotation.y = sin(_t * 0.6 + i) * 0.25
			n.position.y += sin(_t * 1.4 + i * 1.7) * dt * 0.08
			i += 1
		_flash_t -= dt
		var fl := (_vis.penguin as Node3D).get_node("Flash") as MeshInstance3D
		if _flash_t <= 0.0:
			_flash_t = 0.9 + 0.5 * absf(sin(_t * 3.7))
			(fl.material_override as StandardMaterial3D).albedo_color.a = 0.9
			fl.position = Vector3(0.9 * (1.0 if int(_t * 3.0) % 2 == 0 else -1.0), 0.45, 0.85)
		var fm := fl.material_override as StandardMaterial3D
		fm.albedo_color.a = maxf(fm.albedo_color.a - dt * 6.0, 0.0)

# ================================================================== 聲音

func _make_sounds() -> void:
	pass

func _autotest_report(seen: Array) -> Array:
	var ok := seen.has("roof") and seen.has("barn") and seen.has("dream") and seen.has("wake")
	return [[ok, "開場動畫：屋頂 → 雞舍 → 夢見神明 → 醒來（%d 句對話）" % _script.size()]]
