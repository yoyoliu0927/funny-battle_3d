extends "res://levels/ice/story/story_kit.gd"
## 霧山楓燃的開場動畫（第 3 天午後）。分鏡在 levels/ice/docs/大關開場與結尾動畫.md 第 6 節。
## 第一次進霧山第 1 關之前播（選關地圖問 story_registry.gd），播完進第 1 關；
## 這一章自己的開場（全島飛一圈、Chapter 牌子、神蹟介紹卡）在關卡裡照常接在後面。
## 場地借第 1 關「南岸」（拿掉戰局和玩家）；島外那一雙巨大的神之手跟選關地圖上那一雙同一個畫法（map_isles.gd）。
##
## 五拍：靠岸（霧散開，小船從兩隻巨手中間划進去）→ 號碼（「豪王秋收祭」布條和菜單看板）
##       → 對話（神明的島）→ 尋雞啟事（被蓋了「豪王　已預訂」）→ 標題卡

const STAGE := "res://levels/liuchiyu/stage_1/stage.tscn"
const LA := "res://levels/liuchiyu/assets/"
const KH := LA + "kaykit_halloween/"
const QV := LA + "quaternius_village/"
const ARMS := LA + "hand/arms_rig.glb"
const HAND_SHADER := preload("res://levels/liuchiyu/shaders/map_hand.gdshader")
const CLOUD_SHADER := preload("res://levels/liuchiyu/shaders/oil_cloud.gdshader")
const SEA_Y := -4.5                  # 海面（oil_world.gd 的 sea_level）
const X0 := 1.0                      # 小船靠岸、家豪上岸的那一條線（x）
const HAND_S := 80.0                 # 神之手放大幾倍（選關地圖上是 32 倍；這裡的島比較大）
const HAND_OUT := 50.0               # 神之手的肩膀在崖腳外面多遠的海上（手掌往島那邊伸，大約在崖腳外 20 公尺）
const HAND_SINK := -6.0              # 肩膀在海面下多深（升起來之後）
const HAND_LEAN := 16.0              # 往島這邊傾幾度
const MENU := ["前菜　小紅雞", "主菜　烤雞（六十七號）", "甜點　楓糖"]

func _lines() -> Array:
	return [
		{"shot": "sea", "hold": 5.2, "cue": "o_mist", "fade_in": 1.4},
		{"shot": "gap", "hold": 3.3, "cue": "o_gap", "fade_out": 0.4, "fade_in": 0.5},
		{"shot": "shore", "hold": 4.4, "cue": "o_land", "fade_out": 0.3, "fade_in": 0.4},
		{"shot": "menu", "hold": 3.4, "cue": "o_menu", "fade_out": 0.3, "fade_in": 0.4},
		{"shot": "talk", "who": "家豪", "text": "……夢裡你沒給我看這座。", "cue": "t_dream"},
		{"shot": "talk", "who": "神明", "text": "……這座是我的。", "cue": "t_mine"},
		{"shot": "talk", "who": "神明", "text": "以前大家拜我。第一顆南瓜給我。", "cue": "t_pumpkin"},
		{"shot": "talk", "who": "家豪", "text": "現在呢。", "cue": "t_now", "snap": 1.2},
		{"shot": "talk", "who": "神明", "text": "現在給豪王。", "cue": "t_king"},
		{"shot": "talk", "who": "神明", "text": "在這裡，我還叫得動風跟雷。", "cue": "t_power", "snap": 2.4},
		{"shot": "board", "hold": 2.2, "cue": "p_in"},
		{"shot": "board", "who": "家豪", "text": "……被訂走了。", "cue": "p_read", "snap": 1.0},
		{"shot": "board", "hold": 1.8, "cue": "p_out"},
		{"shot": "card", "hold": 4.0, "cue": "card", "fade_out": 0.5, "fade_in": 0.9},
	]

func _skip_text() -> String:
	return "跳過開場"

func _next_scene() -> String:
	return _stage_after(STAGE)

var _world
var _h := 0.6                        # 崖頂的地面高度
var _edge := 21.0                    # 崖頂邊緣的 z（家豪上岸的地方）
var _foot := 28.0                    # 崖腳（碰到海面）的 z
var _boat: Node3D
var _boat_a := Vector3.ZERO          # 這個鏡頭小船從哪裡划到哪裡
var _boat_b := Vector3.ZERO
var _boat_dur := 1.0
var _hands: Dictionary = {}          # {node, mat, ap}
var _hand_y := 0.0                   # 手升起來之後的高度
var _rise := 1.0                     # 0 = 還沉在海裡、1 = 升起來了
var _banner: Node3D
var _board: Node3D
var _offer: Node3D                   # 獻給豪王的那一顆大南瓜
var _leaves: CPUParticles3D          # 一陣風吹過去的落葉
var _storm: Node3D                   # 打雷那一團烏雲
var _bolt_mat: StandardMaterial3D
var _bolt: MeshInstance3D
var _fog0 := 0.0
var _fog_c0 := Color.WHITE
var _fog_sky0 := 0.0
var _poster_p: Control
var _stamp_p: Control
var _card_p: Control

## 地面上的點（崖邊用島自己算的岩階高度，跟畫面上的岩壁一致）
func G(x: float, z: float) -> Vector3:
	return Vector3(x, _gy(x, z), z)

func _gy(x: float, z: float) -> float:
	if _world.has_method("_gy"):
		return float(_world._gy(x, z))
	return float(_world.height_at(x, z))

func _story_build() -> void:
	mark_seen("liuchiyu_opening")    # 先記下來：底下借第 1 關的場地時，那一關就不會又轉回開場
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
	# 找南岸的崖邊：從家豪出發的地方往南走，地面一往下掉就是崖頂，碰到海面就是崖腳
	_h = _gy(X0, 14.0)
	var top_found := false
	for i in 400:
		var z := 14.0 + i * 0.1
		var y := _gy(X0, z)
		if not top_found and y < _h - 0.6:
			_edge = z - 0.4
			top_found = true
		if top_found and y < SEA_Y - 0.8:
			_foot = z
			break
	_h = _gy(X0, _edge - 1.6)
	_make_hero(self)
	_boat = _make_boat()
	_hands = _god_hands(HAND_S)
	_hand_y = SEA_Y + HAND_SINK
	_build_fest()
	_build_fx()
	_make_story_sounds()

# ================================================================== 佈景

## 神之手：關卡裡那雙半透明的手放大好幾倍，從海裡伸上來、手指朝天、手心朝著島（像捧著這座島）
func _god_hands(scale: float) -> Dictionary:
	var ps := load(ARMS) as PackedScene
	if ps == null:
		return {}
	var holder := Node3D.new()
	holder.name = "GodHands"
	add_child(holder)
	var tilt := Node3D.new()
	holder.add_child(tilt)
	# 模型裡手指朝 +Z、手背朝 +Y：立起來讓手指朝上，再往島那邊傾一點；外面那層轉半圈，手心朝北（朝著島）
	tilt.basis = Basis(Vector3.RIGHT, deg_to_rad(HAND_LEAN)) * Basis(Vector3.RIGHT, -PI * 0.5)
	var arms := ps.instantiate() as Node3D
	arms.position = Vector3(0.0, -1.743, 0.0)       # 模型的「眼睛」在 1.743 公尺高：移到原點
	tilt.add_child(arms)
	holder.scale = Vector3.ONE * scale
	holder.rotation.y = PI
	var mat := ShaderMaterial.new()
	mat.shader = HAND_SHADER
	mat.render_priority = 10            # 比海面（也是半透明）晚畫
	mat.set_shader_parameter("body_alpha", 0.26)
	mat.set_shader_parameter("rim_alpha", 0.92)
	mat.set_shader_parameter("glow", 0.25)
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
	return {"node": holder, "mat": mat, "ap": ap}

## 神之手在哪（升到一半的時候比較低）
func _hands_pos() -> Vector3:
	var k := 1.0 - pow(1.0 - _rise, 2.0)
	return Vector3(X0 + 0.4, lerpf(_hand_y - HAND_S * 0.75, _hand_y, k) + sin(_t * 0.35) * 0.35, _foot + HAND_OUT)

## 手掌大概在哪（肩膀往島那邊伸過去，手指頭朝天）
func _palms() -> Vector3:
	return _hands_pos() + Vector3(0, HAND_S * 0.3, -HAND_S * 0.36)

## 岸邊的秋收祭：「豪王秋收祭」大布條、菜單看板（旁邊貼著懸賞單）、獻給豪王的南瓜
func _build_fest() -> void:
	var wood := _tex_mat(LA + "polyhaven/weathered_brown_planks_diff_1k.jpg", 1.0, Color(0.95, 0.85, 0.75))
	var gold := _toon(Color(0.98, 0.78, 0.26))
	# 大布條：兩根木柱中間拉一條紅布，柱頂吊燈籠
	_banner = Node3D.new()
	add_child(_banner)
	_banner.position = G(X0, _edge - 9.0)
	for x in [-3.3, 3.3]:
		_box(_banner, Vector3(0.22, 4.6, 0.22), Vector3(x, 2.3, 0), wood)
		_ball(_banner, 0.17, Vector3(x, 4.66, 0), gold, Vector3.ONE, 10)
		var lt := _glb(_banner, KH + "lantern_hanging.gltf", Vector3(x, 4.3, 0.26), 0.0, 0.62)
		_no_shadow(lt)
	_box(_banner, Vector3(6.4, 1.25, 0.06), Vector3(0, 3.55, 0), _toon(Color(0.74, 0.13, 0.10)))
	_box(_banner, Vector3(6.5, 0.09, 0.09), Vector3(0, 4.2, 0), gold)
	_box(_banner, Vector3(6.5, 0.09, 0.09), Vector3(0, 2.9, 0), gold)
	for k in 9:
		# 布條底下一排小三角旗
		var fl := _cyl(_banner, 0.0, 0.2, 0.36, Vector3(-2.8 + k * 0.7, 2.66, 0), _toon([Color(0.98, 0.78, 0.26), Color(0.92, 0.48, 0.14)][k % 2]), Vector3(PI, 0, 0), 3)
		fl.scale = Vector3(1.0, 1.0, 0.18)
	_sign_text(_banner, "豪王秋收祭", 150, 0.0062, Vector3(0, 3.55, 0.05), Color(1.0, 0.93, 0.62), Color(0.38, 0.05, 0.04), 22)
	# 菜單看板
	_board = _menu_board(self, wood)
	_board.position = G(X0 - 4.9, _edge - 7.0)
	_board.rotation.y = 0.42
	# 獻給豪王的南瓜：木箱上一顆特別大的，旁邊堆一堆
	_offer = Node3D.new()
	add_child(_offer)
	_offer.position = G(X0 + 4.7, _edge - 7.4)
	_offer.rotation.y = -0.45
	_glb(_offer, QV + "Prop_Crate.gltf", Vector3(0, 0, 0), 0.2, 0.9)
	_glb(_offer, KH + "pumpkin_orange.gltf", Vector3(0, 0.95, 0), 0.4, 1.45)
	var card := Node3D.new()
	card.position = Vector3(0.0, 0.58, 0.6)
	card.rotation.x = -0.08
	_offer.add_child(card)
	_box(card, Vector3(1.05, 0.36, 0.02), Vector3.ZERO, _toon(Color(0.97, 0.93, 0.82)))
	_sign_text(card, "獻給豪王", 52, 0.0034, Vector3(0, 0, 0.015), Color(0.62, 0.10, 0.08), Color(1, 1, 1, 0), 0)
	for p in [[Vector3(1.1, 0, 0.4), "pumpkin_orange.gltf", 0.9], [Vector3(-1.2, 0, 0.3), "pumpkin_orange_small.gltf", 1.1],
			[Vector3(1.3, 0, -0.5), "pumpkin_orange_small.gltf", 1.0], [Vector3(-0.9, 0, -0.6), "pumpkin_orange.gltf", 0.8],
			[Vector3(-1.5, 0, 1.0), "pumpkin_orange_small.gltf", 0.8]]:
		_glb(_offer, KH + String(p[1]), p[0], float(p[0].x) * 2.0, float(p[2]))
	_glb(_offer, QV + "Prop_Wagon.gltf", Vector3(2.6, 0, -1.2), 1.2, 0.62)

## 菜單看板：兩根腳、木框、深色的板子，三行粉筆字；右邊的柱子上貼著一張尋雞啟事
func _menu_board(parent: Node3D, wood: Material) -> Node3D:
	var b := Node3D.new()
	parent.add_child(b)
	for x in [-1.3, 1.3]:
		_box(b, Vector3(0.14, 2.5, 0.14), Vector3(x, 1.25, 0), wood)
	_box(b, Vector3(2.8, 1.85, 0.1), Vector3(0, 1.62, 0), wood)
	_box(b, Vector3(2.56, 1.62, 0.04), Vector3(0, 1.62, 0.055), _toon(Color(0.17, 0.21, 0.17)))
	_sign_text(b, "菜　單", 76, 0.0042, Vector3(0, 2.18, 0.085), Color(1.0, 0.86, 0.42), Color(0, 0, 0, 0), 0)
	for k in MENU.size():
		var l := _sign_text(b, MENU[k], 50, 0.0041, Vector3(0, 1.80 - k * 0.34, 0.085), Color(0.96, 0.95, 0.90), Color(0, 0, 0, 0), 0)
		l.name = "Line%d" % k
	# 尋雞啟事（被蓋了紅印）
	var p := Node3D.new()
	p.position = Vector3(1.32, 1.35, 0.1)
	p.rotation.z = -0.06
	b.add_child(p)
	_box(p, Vector3(0.56, 0.74, 0.012), Vector3.ZERO, _toon(Color(0.95, 0.88, 0.70)))
	_sign_text(p, "尋雞啟事", 40, 0.0030, Vector3(0, 0.27, 0.01), Color(0.80, 0.20, 0.16), Color(0, 0, 0, 0), 0)
	_sign_text(p, "懸賞：飼料十包", 26, 0.0026, Vector3(0, -0.24, 0.01), Color(0.30, 0.20, 0.14), Color(0, 0, 0, 0), 0)
	var st := _sign_text(p, "已預訂", 46, 0.0032, Vector3(0.02, 0.0, 0.012), Color(0.86, 0.10, 0.08), Color(0, 0, 0, 0), 0)
	st.rotation.z = 0.32
	_box(p, Vector3(0.36, 0.36, 0.01), Vector3(0, 0.02, 0.004), _toon(Color(0.86, 0.78, 0.62)))
	return b

## 招牌上的字（不是一直朝著鏡頭的那種）
func _sign_text(parent: Node3D, text: String, size: int, px: float, pos: Vector3, col: Color, outline: Color, ol := 12) -> Label3D:
	var l := Label3D.new()
	l.text = text
	if UIStyle.font():
		l.font = UIStyle.font()
	l.font_size = size
	l.pixel_size = px
	l.modulate = col
	l.outline_size = ol
	l.outline_modulate = outline
	l.position = pos
	l.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(l)
	return l

## 一陣風吹過的落葉、打雷用的烏雲和閃電（都先做好藏著）
func _build_fx() -> void:
	_leaves = CPUParticles3D.new()
	_leaves.emitting = false
	_leaves.one_shot = true
	_leaves.amount = 90
	_leaves.lifetime = 2.6
	_leaves.explosiveness = 0.75
	var q := QuadMesh.new()
	q.size = Vector2(0.22, 0.16)
	var lm := StandardMaterial3D.new()
	lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lm.vertex_color_use_as_albedo = true
	lm.cull_mode = BaseMaterial3D.CULL_DISABLED
	q.material = lm
	_leaves.mesh = q
	_leaves.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_leaves.emission_box_extents = Vector3(6.0, 2.5, 3.0)
	_leaves.direction = Vector3(-1.0, 0.25, -0.6)
	_leaves.spread = 25.0
	_leaves.initial_velocity_min = 7.0
	_leaves.initial_velocity_max = 12.0
	_leaves.gravity = Vector3(0, -1.2, 0)
	_leaves.angular_velocity_min = -400.0
	_leaves.angular_velocity_max = 400.0
	_leaves.particle_flag_rotate_y = true
	var grad := Gradient.new()
	grad.set_color(0, Color(0.95, 0.62, 0.16))
	grad.set_color(1, Color(0.80, 0.30, 0.10))
	_leaves.color_initial_ramp = grad
	add_child(_leaves)
	# 烏雲
	_storm = Node3D.new()
	add_child(_storm)
	var cm := ShaderMaterial.new()
	cm.shader = CLOUD_SHADER
	var r := RandomNumberGenerator.new()
	r.seed = 33
	for k in 14:
		var a := TAU * float(k) / 14.0
		var rr := r.randf_range(0.0, 7.0)
		var sc := r.randf_range(3.2, 6.0)
		var puff := _ball(_storm, 1.0, Vector3(cos(a) * rr, r.randf_range(0.0, 1.6), sin(a) * rr), cm, Vector3(sc, sc * 0.6, sc), 10)
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

## 一道閃電從 top 折下來打在 at（網格每打一次做一次，不是每一畫面）
func _strike(top: Vector3, at: Vector3, seed_n: int, width := 0.5) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_n
	var prev := at
	var n := 12
	var span := top.distance_to(at)
	for k in n:
		var u := float(k + 1) / n
		var wob := span * 0.07 * (1.0 - u)
		var nxt := at.lerp(top, u) + Vector3(rng.randf_range(-wob, wob), 0, rng.randf_range(-wob, wob))
		for side in [Vector3(width, 0, 0), Vector3(0, 0, width)]:
			var qd := [prev - side, prev + side, nxt + side, nxt - side]
			for t in [0, 1, 2, 0, 2, 3]:
				st.add_vertex(qd[t])
		prev = nxt
	_bolt.mesh = st.commit()
	_bolt.visible = true
	_flash(Color(0.86, 0.92, 1.0), 0.7, 0.4)
	_play("thunder", -6.0)
	_shake = 0.5
	var tw := _tw()
	tw.tween_interval(0.12)
	tw.tween_callback(func(): _bolt.visible = false)
	tw.tween_interval(0.08)
	tw.tween_callback(func(): _bolt.visible = true)
	tw.tween_interval(0.1)
	tw.tween_callback(func(): _bolt.visible = false)

# ================================================================== 聲音

func _make_story_sounds() -> void:
	# 一條細細的弦：兩個長音慢慢漲起來又退下去（循環）
	var dur := 8.0
	var b := s_buf(dur)
	for nt in [[0.0, 76, 4.2], [4.0, 74, 4.0]]:
		var n0 := int(float(nt[0]) * RATE)
		var n := int(float(nt[2]) * RATE)
		var hz := s_hz(int(nt[1]))
		var len_s := float(nt[2])
		for i in n:
			var j := (n0 + i) % b.size()
			var t := float(i) / RATE
			var env := minf(t / 1.3, 1.0) * clampf((len_s - t) / 1.5, 0.0, 1.0)
			var ph := TAU * hz * t + 0.5 * sin(TAU * 5.2 * t)
			b[j] += (sin(ph) + 0.22 * sin(ph * 2.0) + 0.1 * sin(ph * 3.0)) * env * 0.16
	_snd["string"] = s_wav(b, true)
	# 打雷：一聲很亮的「啪」，接著低低的隆隆聲
	b = s_buf(2.4)
	s_noise(b, 0.0, 0.3, 0.9, 0.7, 78, 12.0)
	s_kick(b, 0.0, 0.9)
	s_noise(b, 0.05, 2.3, 0.8, 0.04, 77, 1.5)
	_snd["thunder"] = s_wav(b)
	# 紅印蓋下去的「咚」
	b = s_buf(0.3)
	s_kick(b, 0.0, 0.8)
	s_noise(b, 0.0, 0.08, 0.5, 0.5, 5, 40.0)
	_snd["stamp"] = s_wav(b)

# ================================================================== 每一畫面

## 家豪坐在船上（跟著船一起晃）
func _hero_in_boat() -> void:
	if _boat:
		var hero := _hero.node as Node3D
		hero.global_position = _boat.to_global(Vector3(0, 0.24, -0.3))
		hero.rotation.y = _boat.rotation.y

func _story_tick(_dt: float) -> void:
	if not _hands.is_empty():
		var hn := _hands.node as Node3D
		hn.position = _hands_pos()
		(_hands.mat as ShaderMaterial).set_shader_parameter("fade", clampf(_rise * 1.4, 0.0, 1.0))
	if _boat and _boat.visible and _boat_b != _boat_a:
		var k := clampf(_shot_t / _boat_dur, 0.0, 1.0)
		var e := 1.0 - pow(1.0 - k, 1.8) if _shot == "shore" else k
		_boat_at(_boat, _boat_a.lerp(_boat_b, e), _boat_b - _boat_a)
		if _shot != "shore" or k < 0.999:
			_hero_in_boat()

# ================================================================== 鏡頭

func _enter_shot(s: String) -> void:
	var hero := _hero.node as Node3D
	hero.visible = true
	hero.rotation = Vector3.ZERO
	_hero.look = null
	_set_anim(_hero, "idle")
	if _boat:
		_boat.visible = s in ["sea", "gap", "shore"]
	_boat_a = Vector3.ZERO
	_boat_b = Vector3.ZERO
	match s:
		"sea":
			_rise = 0.0
			_boat_a = Vector3(X0 + 1.2, SEA_Y, _foot + 118.0)
			_boat_b = Vector3(X0 + 0.4, SEA_Y, _foot + 84.0)
			_boat_dur = 5.2
			_boat_at(_boat, _boat_a, _boat_b - _boat_a)
			_hero_in_boat()
		"gap":
			_rise = 1.0
			_boat_a = Vector3(X0 + 0.4, SEA_Y, _foot + 50.0)
			_boat_b = Vector3(X0 + 0.2, SEA_Y, _foot + 14.0)
			_boat_dur = 3.3
			_boat_at(_boat, _boat_a, _boat_b - _boat_a)
			_hero_in_boat()
		"shore":
			_rise = 1.0
			_boat_a = Vector3(X0 + 0.1, SEA_Y, _foot + 12.0)
			_boat_b = Vector3(X0, SEA_Y, _foot + 1.7)
			_boat_dur = 1.9
			_boat_at(_boat, _boat_a, _boat_b - _boat_a)
			_hero_in_boat()
			_set_anim(_hero, "lookup")
		"menu":
			_rise = 1.0
			hero.position = G(X0 + 0.2, _edge - 1.4)
			_face(_hero, _banner.global_position)
			_hero.look = _banner.global_position + Vector3(0, 3.5, 0)
		"talk":
			_rise = 1.0
			hero.position = G(X0, _edge - 1.8)
			hero.rotation.y = 0.0          # 面向海（神之手那邊）
		"board":
			_rise = 1.0
			var hb := _board.global_position + _board.basis * Vector3(2.3, 0, 1.5)
			hero.position = G(hb.x, hb.z)
			_face(_hero, _board.global_position + _board.basis * Vector3(0.6, 0, 0))
		"card":
			_rise = 1.0
			hero.visible = false

func _on_line(l: Dictionary) -> void:
	var hero := _hero.node as Node3D
	var hp := hero.global_position
	var hands := _hands_pos()
	match String(l.get("cue", "")):
		# ---------------------------------------------------------- ① 靠岸
		"o_mist":
			# 午後，海上起霧。霧散開：海裡伸出兩隻半透明的巨手，捧著一座秋天的島。小船往兩隻手中間划
			_shot_cam(Vector3(X0 + 12.0, SEA_Y + 3.0, _foot + 150.0), Vector3(X0 - 5.0, 9.0, _edge - 12.0), 36.0, 0.0, Vector3(-0.3, 0.06, -1.6))
			var env := _env_node.environment
			if env:
				_fog0 = env.fog_density
				_fog_c0 = env.fog_light_color
				_fog_sky0 = env.fog_sky_affect
				env.fog_density = 0.07
				env.fog_light_color = Color(0.95, 0.92, 0.84)
				env.fog_sky_affect = 0.9
				var tw := _tw()
				tw.set_parallel(true)
				tw.tween_property(env, "fog_density", _fog0, 4.2).set_delay(0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
				tw.tween_property(env, "fog_sky_affect", _fog_sky0, 4.2).set_delay(0.5)
				tw.tween_property(env, "fog_light_color", _fog_c0, 4.2).set_delay(0.5)
			var tw2 := _tw()
			tw2.tween_property(self, "_rise", 1.0, 4.4).set_delay(0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			_music_play("string", -19.0, 3.0)
			_amb_play("waves", -15.0, 1.5)
			_face(_hero, Vector3(X0, 0, _edge))
		"o_gap":
			# 小船從兩隻手的指縫之間划過去：低低的貼著海面往上看
			_shot_cam(Vector3(X0 + 6.0, SEA_Y + 2.2, _foot + 66.0), Vector3(X0 - 1.0, SEA_Y + 14.0, _foot + 6.0), 48.0, 0.0, Vector3(-0.2, 0.05, -1.6))
			_hero.look = _palms()
			_set_anim(_hero, "lookup")
		"o_land":
			# 崖頂往下看：小船靠上崖腳，家豪一階一階跳上岩階
			# 從旁邊的海上看崖壁：小船靠上崖腳，家豪一階一階跳上岩階
			_shot_cam(Vector3(X0 + 10.5, SEA_Y + 2.4, _foot + 5.5), Vector3(X0 - 0.5, (_h + SEA_Y) * 0.5 + 0.6, (_edge + _foot) * 0.5 + 0.5), 46.0, 0.0, Vector3(-0.05, 0.02, -0.08))
			var steps := _cliff_steps()
			var at := 1.95
			for p in steps:
				var to: Vector3 = p
				_at(at, func():
					_set_anim(_hero, "flap")
					_face(_hero, Vector3(to.x, hp.y, to.z) + Vector3(0, 0, -1.0))
					_hop(_hero, to, 0.4, 1.0, 0.0, "idle")
					_play("whoosh", -16.0, 1.4))
				at += 0.45
			_at(at - 0.05, func():
				_play("thud", -14.0, 1.2)
				_face(_hero, _banner.global_position, 0.4)
				_hero.look = _banner.global_position + Vector3(0, 3.5, 0))
			_at(at + 0.25, func(): _emote(_hero, "…", Color(1, 1, 1), 1.0, 0.8))
		# ---------------------------------------------------------- ② 號碼
		"o_menu":
			# 布條「豪王秋收祭」往下搖到菜單看板
			var bp := _banner.global_position
			_shot_cam(bp + Vector3(1.4, 3.1, 7.4), bp + Vector3(-0.6, 3.3, 0), 40.0)
			_shot_cam(_board.global_position + Vector3(1.6, 1.7, 4.2), _board.global_position + Vector3(0.1, 1.55, 0), 36.0, 2.2)
		# ---------------------------------------------------------- ③ 對話
		"t_dream":
			# 家豪抬頭看海上那雙手
			_shot_cam(hp + Vector3(-0.9, 0.95, -3.1), hp + Vector3(0.2, 6.0, 12.0), 56.0, 0.0, Vector3(0.02, 0.0, -0.03))
			_hero.look = _palms()
			_set_anim(_hero, "lookup")
		"t_mine":
			# 神明的角度：從手指頭那麼高的地方往下看整座島
			_shot_cam(_palms() + Vector3(10.0, 14.0, 12.0), Vector3(X0 - 14.0, _h, _edge - 26.0), 50.0, 0.0, Vector3(-0.15, -0.05, -0.2))
			_hero.look = _palms()
		"t_pumpkin":
			var op := _offer.global_position
			_shot_cam(op + _offer.basis * Vector3(0.9, 1.5, 4.0), op + Vector3(0, 0.95, 0), 36.0, 0.0, Vector3(-0.05, 0, -0.06))
		"t_now":
			_shot_cam(hp + Vector3(0.8, 1.45, 3.4), hp + Vector3(0, 1.05, 0), 32.0, 0.0, Vector3(0.0, 0, -0.03))
			_hero.look = null
			_set_anim(_hero, "idle")
		"t_king":
			var bp := _banner.global_position
			_shot_cam(bp + Vector3(1.8, 1.4, 6.4), bp + Vector3(0.4, 3.0, 0), 42.0, 0.0, Vector3(0.0, 0.03, -0.08))
		"t_power":
			# 一陣風吹過整片林子，風車轉起來；遠處打一聲雷
			var mill := G(-9.5, 10.5)
			_shot_cam(hp + Vector3(7.0, 2.2, 7.5), mill + Vector3(0, 11.0, 0), 58.0, 0.0, Vector3(0.05, 0.02, 0.06))
			_hero.look = mill + Vector3(0, 9.0, 0)
			_set_anim(_hero, "lookup")
			_at(0.5, func():
				_amb_play("wind", -9.0, 0.3)
				_play("whoosh", -8.0, 0.55)
				_leaves.global_position = hp + Vector3(3.0, 2.0, 2.0)
				_leaves.restart()
				if _world.has_method("windmill_set_level"):
					_world.windmill_set_level(1.0))
			var strike := G(-30.0, -14.0)
			_at(1.5, func():
				_storm.global_position = strike + Vector3(0, 26.0, 0)
				_storm.visible = true)
			_at(1.9, func():
				_strike(strike + Vector3(0, 25.0, 0), strike, 91, 0.45)
				_set_anim(_hero, "shock"))
			_at(2.6, func():
				_set_anim(_hero, "lookup")
				_amb.volume_db = -16.0)
		# ---------------------------------------------------------- ④ 尋雞啟事
		"p_in":
			# 菜單旁邊貼著懸賞單，上面被蓋了一個紅印
			_storm.visible = false
			var bp := _board.global_position
			_shot_cam(bp + _board.basis * Vector3(1.1, 1.75, 6.4), bp + _board.basis * Vector3(1.0, 1.25, 0), 40.0)
			_hero.look = bp + Vector3(0, 1.4, 0)
			_at(0.3, func():
				_poster_p = _poster("飼料十包")
				_set_anim(_hero, "shock"))
			_at(1.15, func():
				_stamp_p = _reserved_stamp()
				_set_anim(_hero, "idle"))
		"p_read":
			_set_anim(_hero, "idle")
		"p_out":
			_hide_paper(_poster_p, true)
			_hide_paper(_stamp_p, true)
			_poster_p = null
			_stamp_p = null
			_at(0.45, func():
				_hero.look = null
				_set_anim(_hero, "cool")
				_emote(_hero, "…", Color(1, 1, 1), 1.0, 0.8))
		# ---------------------------------------------------------- ⑤ 標題卡
		"card":
			_shot_cam(hands + Vector3(40.0, 30.0, 70.0), Vector3(X0 - 12.0, 6.0, _edge - 16.0), 44.0, 0.0, Vector3(-0.4, -0.05, -0.3))
			_at(0.45, func(): _card_p = _title_card(3, "霧山楓燃", "秋收祭"))

## 崖腳到崖頂的岩階：家豪一階一階跳上去的落點（最後一個是崖頂）
func _cliff_steps() -> Array:
	# 從崖腳往崖頂找每一層岩階的平台（高度跟前一階差一截的地方）
	var out: Array = []
	var last := SEA_Y - 1.0
	var z := _foot
	while z > _edge:
		var y := _gy(X0, z)
		var y2 := _gy(X0, z - 0.3)
		if y > last + 1.0 and absf(y2 - y) < 0.15 and y >= SEA_Y - 0.1:
			out.append(Vector3(X0, y, z - 0.35))
			last = y
		z -= 0.25
	out.append(G(X0, _edge - 1.4))
	return out

## 紅印「豪王　已預訂」：蓋在尋雞啟事上面
func _reserved_stamp() -> Control:
	var p := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.86, 0.10, 0.08, 0.06)
	s.border_color = Color(0.84, 0.10, 0.08, 0.9)
	s.set_border_width_all(8)
	s.set_corner_radius_all(16)
	s.content_margin_left = 26
	s.content_margin_right = 26
	s.content_margin_top = 10
	s.content_margin_bottom = 12
	p.add_theme_stylebox_override("panel", s)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", -6)
	p.add_child(v)
	v.add_child(_paper_label("豪王", 50, Color(0.84, 0.10, 0.08, 0.92)))
	v.add_child(_paper_label("已預訂", 66, Color(0.84, 0.10, 0.08, 0.92)))
	_papers.add_child(p)
	p.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.grow_vertical = Control.GROW_DIRECTION_BOTH
	# 蓋在懸賞單正中間偏右下（大頭照和金額那一帶）
	p.offset_left += 70.0
	p.offset_right += 70.0
	p.offset_top += 50.0
	p.offset_bottom += 50.0
	p.pivot_offset = p.get_combined_minimum_size() * 0.5
	p.rotation = -0.24
	p.scale = Vector2.ONE * 2.4
	p.modulate.a = 0.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(p, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(p, "modulate:a", 1.0, 0.1)
	tw.chain().tween_callback(func():
		_play("stamp", -4.0)
		_shake = 0.3)
	return p
