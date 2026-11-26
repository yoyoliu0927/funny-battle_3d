extends "res://levels/ice/story/story_kit.gd"
## 駁大莖森的結尾動畫（第 2 天晚上）。分鏡在 levels/ice/docs/大關開場與結尾動畫.md 第 5 節。
## 第一次破完森林第 3 關、回到選關地圖時播（選關地圖問 story_registry.gd），播完回地圖。
## 場地借第 3 關「狼外婆的木屋」，天色調到最暗（夜）。森林的場地本來沒有海：跟開場一樣，
## 島的南邊自己鋪一段沙灘接到海裡，最後小船從那裡離岸。
##
## 七拍：收場（狼外婆追著兔子標本衝進林子、睡帽掛在樹枝上；伐木工和抽菸的人躺了一地）→ 號碼（小紅帽提水桶刷掉紅漆號碼）
##       → 腳牌 → 靜音拍（家豪站上柴堆打碟，小紅帽接住一顆音符、拍錯拍）→ 羽毛（青、黃兩根）
##       → 上船（小黃雞從籃子跳出來跟家豪走，小紅帽提著燈揮手）→ 手帳

const STAGE := "res://levels/forest/stage_3/stage.tscn"
const Models := preload("res://levels/forest/items/models.gd")   # 假獵物、水桶的模型（跟遊戲裡同一個）
const K_CASTLE := "res://levels/forest/assets/kenney_castle/"
const SAND := "res://assets/textures/gravelly_sand_diff_1k.jpg"
const CYAN := Color("4fc3d9")          # 冰雪島的羽毛
const YELLOW := Color("f2d03a")        # 森林的羽毛
const SEA_Y := -0.35
const RAMP_Z := 46.5
const RAMP_K := 0.33
const PAINT := Color(0.84, 0.09, 0.07)
const BASKET_HIP := Vector3(0.31, -0.28, 0.08)
## 狼外婆從門口衝出去的路（往西北邊的林子）
const CHASE := [Vector2(0.0, 2.3), Vector2(-2.6, 5.6), Vector2(-4.5, 7.6), Vector2(-7.4, 9.7), Vector2(-11.5, 11.3), Vector2(-16.0, 13.0)]
const CAP_SPOT := Vector2(-5.2, 6.5)   # 睡帽掛住的那棵樹（找離這裡最近的樹）
const PILE := Vector2(4.3, 5.4)        # 柴堆
const PILE_TOP := 0.82                 # 柴堆頂多高（離地）
const GIRL_DJ := Vector2(3.15, 5.15)   # 靜音拍時小紅帽站的地方（柴堆西邊）
const TAG_HERO := Vector2(-0.45, 7.3)
const TAG_GIRL := Vector2(0.55, 7.3)
## 海邊：小紅帽、家豪、小船
const SHORE_GIRL := Vector2(-0.7, 50.0)
const SHORE_HERO := Vector2(0.55, 50.5)
const BOAT_A := Vector3(2.4, SEA_Y, 53.4)
const BOAT_B := Vector3(4.6, SEA_Y, 68.0)

func _lines() -> Array:
	return [
		{"shot": "chase", "hold": 4.2, "cue": "c_chase", "fade_in": 1.0},
		{"shot": "yard", "who": "神明", "text": "……代班第一天，還行。", "cue": "y_god", "snap": 2.4},
		{"shot": "scrub", "hold": 4.4, "cue": "s_scrub"},
		{"shot": "tag", "who": "小紅帽", "text": "公雞先生，這是項鍊嗎？", "cue": "g_ask", "snap": 1.8},
		{"shot": "tag", "who": "家豪", "text": "……朋友的。", "cue": "g_friend", "snap": 1.4},
		{"shot": "tag", "who": "小紅帽", "text": "她在哪裡？", "cue": "g_where", "snap": 1.2},
		{"shot": "tag", "who": "家豪", "text": "……我在找。", "cue": "g_look", "snap": 1.6},
		{"shot": "dj", "hold": 7.8, "cue": "d_silence", "fade_out": 0.6, "fade_in": 0.9},
		{"shot": "dj", "who": "家豪", "text": "……嘉欣會說這首太吵。", "cue": "d_line", "snap": 2.2},
		{"shot": "hood", "hold": 2.2, "cue": "w_gust"},
		{"shot": "hood", "who": "神明", "text": "又一根。", "cue": "w_god", "snap": 1.0},
		{"shot": "hood", "who": "家豪", "text": "……換毛啦。", "cue": "w_molt", "snap": 1.4},
		{"shot": "boat", "hold": 2.4, "cue": "b_give", "fade_out": 0.6, "fade_in": 0.9},
		{"shot": "boat", "who": "小紅帽", "text": "外婆家不安全。牠跟你走。", "cue": "b_line", "snap": 2.2},
		{"shot": "leave", "hold": 5.6, "cue": "l_leave", "fade_out": 0.5, "fade_in": 0.8},
		{"shot": "journal", "hold": 6.4, "cue": "j_page", "fade_out": 0.6, "fade_in": 0.8},
	]

func _skip_text() -> String:
	return "跳過"

func _voice_pitch(who: String) -> float:
	if who == "小紅帽":
		return 1.8
	return super(who)

var _world
var _foam: MeshInstance3D
var _shore_z := 52.0
var _boat: Node3D
var _leave_on := false
var _g: Dictionary = {}              # 小紅帽
var _chick: Dictionary = {}          # 小黃雞（先在籃子裡）
var _wolf: Node3D                    # 狼外婆
var _wolf_ap: AnimationPlayer
var _cap: Node3D                     # 睡帽
var _cap_branch := Vector3.ZERO      # 睡帽掛住的樹枝
var _cap_d := 7.0                    # 狼外婆跑到這裡，睡帽被樹枝勾走
var _cap_off := false
var _rabbit: Node3D                  # 兔子標本（假獵物）
var _chase_on := false
var _men: Array = []                 # 躺了一地的人
var _butt := Vector3.ZERO            # 被水桶澆熄的菸蒂
var _smoke: Array = []               # 菸蒂冒出來的一縷白煙（幾顆小球輪流往上飄）
var _numbers: Array = []             # 樹上的紅漆號碼 {label, tree}
var _scrub: Dictionary = {}          # 小紅帽刷的那一棵 {label, pos, face}
var _bucket: Node3D
var _water: MeshInstance3D           # 水桶裡的水
var _lantern: Node3D
var _clap_prev := 0.0
var _journal_p: Control
var _far: Node3D                     # 場地遠處的石山（海邊的鏡頭藏起來，海才看得到海平線）

## 月光：場地自己的「夜」是紅紫色的黃昏，這裡換成偏藍的月光，屋裡的燈和小紅帽的燈籠才顯得暖
func _night() -> void:
	if _sun:
		_sun.light_color = Color(0.62, 0.70, 1.0)
		_sun.light_energy = 0.8
		_sun.rotation = Vector3(-0.85, 0.5, 0.0)
	var env := _env_node.environment if _env_node else null
	if env:
		env.ambient_light_color = Color(0.36, 0.40, 0.64)
		env.fog_light_color = Color(0.14, 0.16, 0.30)
		env.fog_density = 0.006
	var sm = _world.get("_sky_mat")
	if sm is ShaderMaterial:
		(sm as ShaderMaterial).set_shader_parameter("top_color", Vector3(0.04, 0.06, 0.18))
		(sm as ShaderMaterial).set_shader_parameter("horizon_color", Vector3(0.20, 0.22, 0.40))

## 地面上（沙灘或草地）的點
func G(p: Vector2) -> Vector3:
	return Vector3(p.x, _sand_y(p.x, p.y), p.y)

func _story_build() -> void:
	mark_seen("forest_ending")
	var stage := _borrow_stage(STAGE)
	_world = stage.get_node("World")
	if _world.has_method("set_look"):
		_world.set_look(1.0)             # 天黑了：窗子亮起來
	_night()
	_far = _world.get_node_or_null("Layout/DistantLayers") as Node3D
	var hood_in_house = _world.get_node_or_null("RedHood")
	if hood_in_house is Node3D:
		(hood_in_house as Node3D).visible = false   # 木屋裡那個小紅帽已經救出來了（換成會動的這一個）
	_make_forest_sounds()
	_build_shore(Color(0.05, 0.13, 0.26), Color(0.32, 0.42, 0.62))
	_edge_trees()
	_number_trees()
	_make_hero(self, [CYAN, YELLOW])
	_boat = _make_boat()
	_g = _make_girl()
	_chick = _make_chick(_g.basket as Node3D)
	(_chick.node as Node3D).position = Vector3(0, 0.08, 0)
	_make_wolf()
	_make_men()
	_build_pile()
	# 水桶（刷號碼的時候放在腳邊）、燈籠（提在手上）
	_bucket = Node3D.new()
	add_child(_bucket)
	Models.bucket(_bucket)
	_bucket.scale = Vector3.ONE * 0.6
	_no_shadow(_bucket)
	_bucket.visible = false
	_water = _ball(_bucket, 0.2, Vector3(0, 0.55, 0), _glow(Color(0.45, 0.70, 1.0), 0.8), Vector3(1.0, 0.1, 1.0), 10)
	_lantern = _make_lantern(_g.arm_n as Node3D)
	_lantern.visible = false

# ================================================================== 海邊（跟開場同一段沙灘）

func _sand_y(x: float, z: float) -> float:
	var t := float(_world.height_at(x, z)) + 0.05
	if z <= RAMP_Z:
		return t
	return maxf(t, float(_world.height_at(x, RAMP_Z)) + 0.05 - (z - RAMP_Z) * RAMP_K)

func _build_shore(deep: Color, light: Color) -> void:
	_shore_z = RAMP_Z + (float(_world.height_at(0.0, RAMP_Z)) + 0.05 - SEA_Y) / RAMP_K
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nx := 45
	var nz := 47
	for j in nz:
		for i in nx:
			var x := -22.0 + float(i)
			var z := 36.0 + float(j) * 0.5
			var y := _sand_y(x, z)
			var edge := 41.0 + 1.3 * sin(x * 0.45) + 0.6 * sin(x * 1.3 + 1.0)
			if z < edge:
				y = float(_world.height_at(x, z)) - 0.12
			st.set_uv(Vector2(x, z) * 0.16)
			st.add_vertex(Vector3(x, y, z))
	for j in nz - 1:
		for i in nx - 1:
			var a := j * nx + i
			for idx in [a, a + 1, a + nx, a + 1, a + nx + 1, a + nx]:
				st.add_index(idx)
	st.generate_normals()
	var sand := MeshInstance3D.new()
	sand.mesh = st.commit()
	sand.material_override = _tex_mat(SAND, 1.0, Color(1.0, 0.92, 0.78))
	sand.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sand)
	var sea := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(900, 900)
	sea.mesh = pm
	var wm := ShaderMaterial.new()
	wm.shader = load("res://shaders/water.gdshader")
	wm.set_shader_parameter("deep", deep)
	wm.set_shader_parameter("light_c", light)
	wm.set_shader_parameter("island_center", Vector2(0.0, _shore_z))
	wm.set_shader_parameter("island_radius", Vector2(24.0, 2.4))
	sea.material_override = wm
	sea.position = Vector3(0, SEA_Y, 0)
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sea)
	_foam = _box(self, Vector3(44.0, 0.01, 0.4), Vector3(0, SEA_Y + 0.02, _shore_z), _glow(Color(0.8, 0.85, 1.0), 0.45))
	_foam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _edge_trees() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2207
	var placed: Array = []
	var guard := 0
	while placed.size() < 26 and guard < 800:
		guard += 1
		var x := rng.randf_range(-20.0, 20.0)
		var z := rng.randf_range(30.5, 40.2)
		var big := rng.randf() < 0.6
		var yaw := rng.randf() * TAU
		var sc := rng.randf_range(2.0, 2.8)
		if absf(x - 2.9) < 2.0 or Vector2(x, z).distance_to(Vector2(1.3, 42.9)) < 2.4:
			continue
		var ok := true
		for p in placed:
			if (p as Vector2).distance_to(Vector2(x, z)) < 2.7:
				ok = false
				break
		if not ok:
			continue
		placed.append(Vector2(x, z))
		var n := _glb(self, K_CASTLE + ("tree-large.glb" if big else "tree-small.glb"), Vector3(x, float(_world.height_at(x, z)) - 0.1, z), yaw, sc)
		if n and _world.has_method("_soften_tree"):
			_world._soften_tree(n, 0.85)

# ================================================================== 樹上的紅漆號碼（開場噴上去的，這裡一個一個刷掉）

func _number_trees() -> void:
	var trees = _world.get("trees")
	if not (trees is Array) or (trees as Array).is_empty():
		return
	var best := -1
	var bd := 1e9
	for i in (trees as Array).size():
		var p: Vector3 = trees[i].pos
		var d := Vector2(p.x, p.z).distance_to(CAP_SPOT)
		if d < bd:
			bd = d
			best = i
	var n := 21
	for i in (trees as Array).size():
		var info := _tree_info(trees[i])
		var p: Vector3 = info.pos
		var eye := Vector2(0, 9.0)
		if Vector2(p.x, p.z).distance_to(eye) < 1.5:
			eye = Vector2(0, 14.0)
		var l := _paint_number(str(n), info, eye)
		n += 1
		_numbers.append(l)
		if i == best:
			var d := (eye - Vector2(p.x, p.z)).normalized()
			_scrub = {"label": l, "info": info, "face": Vector3(d.x, 0, d.y)}
	# 睡帽掛住的樹枝：刷號碼那一棵，朝狼外婆跑過去那一側的樹冠邊上
	if not _scrub.is_empty():
		var info: Dictionary = _scrub.info
		var tp: Vector3 = info.pos
		var sc := float(info.sc)
		var hy := (1.15 if info.big else 0.7) * sc
		var near := Vector2(tp.x, tp.z)
		var bestd := 1e9
		for i in 200:
			var w := _path_at(CHASE, float(i) * 0.1)
			if w.is_empty():
				break
			var q: Vector2 = w.p
			if q.distance_to(near) < bestd:
				bestd = q.distance_to(near)
				_cap_d = float(i) * 0.1
		var side := (_path_at(CHASE, _cap_d).p as Vector2) - near
		side = side.normalized()
		var r := (0.34 if info.big else 0.3) * sc
		_cap_branch = tp + Vector3(side.x, 0, side.y) * r + Vector3(0, hy, 0)

func _tree_info(t: Dictionary) -> Dictionary:
	var n := t.node as Node3D
	var h := float(n.get_meta("h", 3.0))
	var big := true
	var crown := n.get_node_or_null("Crown")
	if crown and crown.get_child_count() > 0:
		big = String(crown.get_child(0).scene_file_path).contains("large")
	return {"pos": n.global_position, "sc": h / (1.85 if big else 1.35), "big": big}

func _paint_number(num: String, info: Dictionary, eye: Vector2) -> Label3D:
	var p: Vector3 = info.pos
	var sc := float(info.sc)
	var d := (eye - Vector2(p.x, p.z)).normalized()
	var l := Label3D.new()
	l.text = num
	if UIStyle.font():
		l.font = UIStyle.font()
	l.font_size = 96
	l.pixel_size = 0.00135 * sc
	l.modulate = PAINT
	l.outline_size = 0
	l.double_sided = false
	l.shaded = true
	l.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(l)
	l.global_position = p + Vector3(d.x, 0, d.y) * (0.13 * sc + 0.02) + Vector3(0, (0.33 if info.big else 0.22) * sc, 0)
	l.rotation = Vector3(0, atan2(d.x, d.y), 0.09 * (1.0 if int(num) % 2 == 0 else -1.0))
	return l

## 號碼刷掉了：只剩一點淡淡的粉紅
func _rubbed(l: Label3D) -> void:
	l.modulate = Color(PAINT, 0.14)

# ================================================================== 狼外婆、躺了一地的人、柴堆

## 狼外婆：跟遊戲裡一樣，人類的身體加上狼耳朵、狼嘴、睡帽、披肩
func _make_wolf() -> void:
	_wolf = _chars._load_model(["farmer"], 2.6, ["Idle"])
	if _wolf == null:
		return
	add_child(_wolf)
	var gray := _toon(Color(0.55, 0.55, 0.58))
	var cloth := _toon(Color(0.85, 0.82, 0.74))
	# 零件的位置照農夫模型的頭（頭骨大約在 y 2.17、臉朝 +Z）擺：遊戲裡從很遠看，這裡是特寫，要貼在頭上
	var ear_l := _box(_wolf, Vector3(0.13, 0.26, 0.11), Vector3(-0.15, 2.66, 0.06), gray, Vector3(0, 0, 0.4))
	var ear_r := _box(_wolf, Vector3(0.13, 0.26, 0.11), Vector3(0.15, 2.66, 0.06), gray, Vector3(0, 0, -0.4))
	var snout := _box(_wolf, Vector3(0.2, 0.14, 0.24), Vector3(0, 2.27, 0.40), gray)
	var nose := _box(_wolf, Vector3(0.07, 0.05, 0.05), Vector3(0, 2.32, 0.53), _toon(Color(0.1, 0.08, 0.08)))   # 鼻頭
	var shawl := _box(_wolf, Vector3(0.62, 0.1, 0.44), Vector3(0, 1.96, 0.08), _toon(Color(0.45, 0.18, 0.22)))
	# 睡帽：方方的帽身（蓋住農夫的帽子）、往後垂的帽尖、一顆小毛球
	_cap = Node3D.new()
	_cap.position = Vector3(0, 2.6, 0.08)
	_wolf.add_child(_cap)
	_box(_cap, Vector3(0.34, 0.28, 0.34), Vector3.ZERO, cloth)
	_box(_cap, Vector3(0.2, 0.2, 0.2), Vector3(0, 0.12, -0.2), cloth, Vector3(-0.6, 0, 0))
	_ball(_cap, 0.07, Vector3(0, 0.12, -0.36), _toon(Color(0.98, 0.97, 0.94)), Vector3.ONE, 8)
	_wolf_ap = _wolf.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _wolf_ap and _wolf_ap.has_animation("Run"):
		_wolf_ap.get_animation("Run").loop_mode = Animation.LOOP_LINEAR
	# 耳朵、狼嘴、睡帽黏在頭上，披肩黏在胸口：跑起來身體往前傾，才不會浮在半空中
	if _wolf_ap:
		_wolf_ap.advance(0.0)
	var sk := _wolf.find_child("Skeleton3D", true, false) as Skeleton3D
	if sk:
		_pin_to_bone(sk, "Head", [ear_l, ear_r, snout, nose, _cap])
		_pin_to_bone(sk, "Chest", [shawl])
	_rabbit = Node3D.new()
	add_child(_rabbit)
	Models.decoy(_rabbit)
	_rabbit.scale = Vector3.ONE * 1.0
	_wolf.visible = false
	_rabbit.visible = false

## 把零件掛到骨頭上（照現在的姿勢，位置不變）
func _pin_to_bone(sk: Skeleton3D, bone: String, parts: Array) -> void:
	var idx := sk.find_bone(bone)
	if idx < 0:
		return
	var att := BoneAttachment3D.new()
	att.bone_name = bone
	sk.add_child(att)
	att.transform = sk.get_bone_global_pose(idx)
	for p in parts:
		(p as Node3D).reparent(att)

## 伐木工和抽菸的人：倒在地上（農夫的「Death」動作最後一格），斧頭掉在旁邊
func _make_men() -> void:
	for spec in [[Vector2(2.95, 8.1), 0.6, "axe"], [Vector2(4.3, 9.9), -2.1, "axe"], [Vector2(-2.75, 8.9), 2.5, "smoke"]]:
		var m: Node3D = _chars._load_model(["farmer"], 2.6, ["Idle"])
		if m == null:
			continue
		add_child(m)
		var at: Vector2 = spec[0]
		m.global_position = Vector3(at.x, float(_world.height_at(at.x, at.y)), at.y)
		m.rotation.y = float(spec[1])
		var ap := m.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if ap and ap.has_animation("Death"):
			ap.get_animation("Death").loop_mode = Animation.LOOP_NONE
			ap.play("Death")
			ap.seek(ap.current_animation_length - 0.02, true)
			ap.pause()
		_men.append(m)
		if String(spec[2]) == "axe":
			var axe := Node3D.new()
			add_child(axe)
			axe.global_position = m.global_position + m.global_basis * Vector3(0.9, 0.04, 0.6)
			axe.rotation.y = m.rotation.y + 0.8
			_box(axe, Vector3(0.06, 0.06, 0.72), Vector3(0, 0, 0), _toon(Color(0.45, 0.28, 0.14)))
			_box(axe, Vector3(0.24, 0.05, 0.14), Vector3(0.08, 0.0, 0.32), _toon(Color(0.65, 0.66, 0.7)))
		else:
			_butt = m.global_position + m.global_basis * Vector3(0.7, 0.0, 1.25)
			_butt.y = float(_world.height_at(_butt.x, _butt.z))
	# 菸蒂：泡在一灘水裡，冒著一縷白煙
	if _butt != Vector3.ZERO:
		_cyl(self, 0.42, 0.42, 0.012, _butt + Vector3(0, 0.012, 0), _glow(Color(0.35, 0.55, 0.85), 0.5), Vector3.ZERO, 18)
		_cyl(self, 0.022, 0.022, 0.1, _butt + Vector3(0, 0.03, 0), _toon(Color(0.95, 0.94, 0.9)), Vector3(0, 0.5, PI * 0.5), 8)
		_cyl(self, 0.023, 0.023, 0.03, _butt + Vector3(0.045, 0.03, -0.025), _toon(Color(0.55, 0.42, 0.25)), Vector3(0, 0.5, PI * 0.5), 8)
		var puff := _glow(Color(0.92, 0.92, 0.95), 0.42)
		for k in 5:
			var b := _ball(self, 0.06, _butt, puff, Vector3.ONE, 8)
			b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_smoke.append(b)

## 柴堆：一根一根疊起來的木頭（木頭朝南，鏡頭看得到切口的年輪）
func _build_pile() -> void:
	var y0 := float(_world.height_at(PILE.x, PILE.y))
	var bark := _toon(Color(0.42, 0.27, 0.15))
	var cut := _toon(Color(0.86, 0.70, 0.46))
	var rows := [[0.15, [-0.45, -0.15, 0.15, 0.45]], [0.41, [-0.3, 0.0, 0.3]], [0.67, [-0.15, 0.15]]]
	for row in rows:
		for x in row[1]:
			var p := Vector3(PILE.x + float(x), y0 + float(row[0]), PILE.y)
			_cyl(self, 0.15, 0.15, 1.4, p, bark, Vector3(PI * 0.5, 0, 0), 10)
			_cyl(self, 0.12, 0.12, 0.02, p + Vector3(0, 0, 0.7), cut, Vector3(PI * 0.5, 0, 0), 10)

func _pile_top() -> Vector3:
	return Vector3(PILE.x, float(_world.height_at(PILE.x, PILE.y)) + PILE_TOP, PILE.y)

## 燈籠：掛在手上，裡面一顆暖暖的光（加一盞小點光源，不開陰影）
func _make_lantern(arm: Node3D) -> Node3D:
	var n := Node3D.new()
	arm.add_child(n)
	n.position = Vector3(0, -0.44, 0.02)
	var frame := _toon(Color(0.22, 0.16, 0.12))
	_box(n, Vector3(0.15, 0.03, 0.15), Vector3(0, -0.02, 0), frame)
	_box(n, Vector3(0.15, 0.03, 0.15), Vector3(0, -0.22, 0), frame)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_box(n, Vector3(0.018, 0.2, 0.018), Vector3(0.065 * sx, -0.12, 0.065 * sz), frame)
	_box(n, Vector3(0.11, 0.17, 0.11), Vector3(0, -0.12, 0), _glow(Color(1.7, 1.15, 0.5)))
	_torus(n, 0.03, 0.045, Vector3(0, 0.02, 0), frame, Vector3(PI * 0.5, 0, 0))
	var lt := OmniLight3D.new()
	lt.light_color = Color(1.0, 0.75, 0.42)
	lt.light_energy = 1.8
	lt.omni_range = 4.5
	lt.shadow_enabled = false
	lt.position = Vector3(0, -0.12, 0.1)
	n.add_child(lt)
	_no_shadow(n)
	return n

# ================================================================== 小紅帽（跟開場同一個）

func _make_girl() -> Dictionary:
	var root := Node3D.new()
	add_child(root)
	var skin := _toon(Color(0.96, 0.80, 0.68))
	var red := _toon(Color(0.80, 0.16, 0.18))
	var dress := _toon(Color(0.96, 0.94, 0.88))
	var hair := _toon(Color(0.42, 0.25, 0.13))
	var dark := _toon(Color(0.12, 0.08, 0.07))
	var body := Node3D.new()
	root.add_child(body)
	var lower := Node3D.new()
	body.add_child(lower)
	_cyl(lower, 0.15, 0.36, 0.66, Vector3(0, 0.34, 0), dress, Vector3.ZERO, 14)
	var shoe := _toon(Color(0.36, 0.20, 0.12))
	for sx in [-1.0, 1.0]:
		_box(lower, Vector3(0.1, 0.07, 0.17), Vector3(0.09 * sx, 0.035, 0.07), shoe)
	var upper := Node3D.new()
	upper.position = Vector3(0, 0.62, 0)
	body.add_child(upper)
	_cyl(upper, 0.11, 0.40, 0.74, Vector3(0, 0.07, -0.04), red, Vector3.ZERO, 14)
	_box(upper, Vector3(0.1, 0.1, 0.1), Vector3(0, 0.46, 0.0), skin)
	_ball(upper, 0.038, Vector3(0, 0.41, 0.115), dress, Vector3.ONE, 8)
	var head := Node3D.new()
	head.position = Vector3(0, 0.5, 0)
	upper.add_child(head)
	_ball(head, 0.18, Vector3(0, 0.08, 0.02), skin)
	_ball(head, 0.185, Vector3(0, 0.12, -0.02), hair, Vector3(1.0, 0.82, 1.0))
	_box(head, Vector3(0.24, 0.06, 0.06), Vector3(0, 0.19, 0.15), hair)
	for sx in [-1.0, 1.0]:
		_ball(head, 0.022, Vector3(0.065 * sx, 0.08, 0.188), dark, Vector3(1.0, 1.35, 0.5), 8)
		_ball(head, 0.03, Vector3(0.11 * sx, 0.03, 0.155), _toon(Color(0.98, 0.62, 0.62)), Vector3(1.0, 0.6, 0.5), 8)
	_box(head, Vector3(0.05, 0.012, 0.012), Vector3(0, 0.005, 0.196), _toon(Color(0.6, 0.18, 0.18)))
	_ball(head, 0.215, Vector3(0, 0.11, -0.045), red)
	_ball(head, 0.06, Vector3(0, 0.23, -0.25), red, Vector3(1.0, 1.0, 1.4), 8)
	var arms: Array = []
	for sx in [-1.0, 1.0]:
		var piv := Node3D.new()
		piv.position = Vector3(0.15 * sx, 0.36, 0.0)
		upper.add_child(piv)
		_cyl(piv, 0.045, 0.058, 0.34, Vector3(0, -0.17, 0), red, Vector3.ZERO, 10)
		_ball(piv, 0.052, Vector3(0, -0.37, 0), skin, Vector3.ONE, 10)
		arms.append(piv)
	var basket := _make_basket(upper)
	basket.position = BASKET_HIP
	_no_shadow(root)
	return {"node": root, "body": body, "lower": lower, "upper": upper, "head": head, "arm_n": arms[0], "arm_p": arms[1],
		"basket": basket, "anim": "idle", "look": null, "v": {}}

func _make_basket(parent: Node3D) -> Node3D:
	var b := Node3D.new()
	parent.add_child(b)
	var wick := _toon(Color(0.74, 0.54, 0.30))
	var weave := _toon(Color(0.56, 0.38, 0.18))
	var w := 0.44
	var d := 0.32
	var h := 0.24
	var t := 0.03
	_box(b, Vector3(w, t, d), Vector3(0, t * 0.5, 0), weave)
	_box(b, Vector3(w, h, t), Vector3(0, h * 0.5, d * 0.5), wick)
	_box(b, Vector3(w, h, t), Vector3(0, h * 0.5, -d * 0.5), wick)
	_box(b, Vector3(t, h, d), Vector3(w * 0.5, h * 0.5, 0), wick)
	_box(b, Vector3(t, h, d), Vector3(-w * 0.5, h * 0.5, 0), wick)
	_box(b, Vector3(w + 0.02, 0.035, 0.04), Vector3(0, h, d * 0.5), weave)
	_box(b, Vector3(w + 0.02, 0.035, 0.04), Vector3(0, h, -d * 0.5), weave)
	_box(b, Vector3(w + 0.02, 0.04, 0.012), Vector3(0, h * 0.45, d * 0.5 + 0.016), weave)
	for sx in [-1.0, 1.0]:
		_box(b, Vector3(0.03, 0.28, 0.03), Vector3(sx * (w * 0.5 - 0.03), h + 0.14, 0), wick)
	_box(b, Vector3(w - 0.03, 0.03, 0.03), Vector3(0, h + 0.28, 0), wick)
	_box(b, Vector3(0.2, 0.12, 0.012), Vector3(-0.1, h - 0.04, d * 0.5 + 0.022), _toon(Color(0.86, 0.24, 0.22)))
	_box(b, Vector3(0.05, 0.05, 0.014), Vector3(-0.15, h - 0.02, d * 0.5 + 0.024), _toon(Color(0.97, 0.94, 0.88)))
	_box(b, Vector3(0.05, 0.05, 0.014), Vector3(-0.05, h - 0.07, d * 0.5 + 0.024), _toon(Color(0.97, 0.94, 0.88)))
	return b

func _make_chick(parent: Node3D) -> Dictionary:
	var c := _actor(parent, "chick", Vector3.ZERO, 0.0, 0.55)
	for m in (c.node as Node3D).find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		var sm := mi.material_override as ShaderMaterial
		if sm == null:
			continue
		var col = sm.get_shader_parameter("albedo")
		if not (col is Color):
			continue
		var cc := col as Color
		if cc.r > 0.85 and cc.g > 0.85 and cc.b > 0.85:
			sm.set_shader_parameter("albedo", Color(1.0, 0.86, 0.30))
		elif cc.r > 0.8 and cc.g < 0.4:
			mi.visible = false
		elif cc.r > 0.9 and cc.g > 0.7 and cc.b < 0.4:
			sm.set_shader_parameter("albedo", Color(1.0, 0.56, 0.16))
	_no_shadow(c.node)
	return c

func _girl_tick(dt: float) -> void:
	if _g.is_empty():
		return
	var root := _g.node as Node3D
	if not root.visible:
		return
	var t := _t
	var g := {"by": 0.0, "brz": 0.0, "ux": 0.0, "uy": 0.0, "ls": 1.0, "hx": sin(t * 1.3) * 0.04, "hy": sin(t * 0.6) * 0.12, "hz": 0.0,
		"nx": 0.0, "nz": -0.38, "px": -0.1, "pz": 0.4}
	match String(_g.anim):
		"walk":
			var s := sin(t * 7.0)
			g.by = absf(s) * 0.09
			g.brz = s * 0.06
			g.nx = s * 0.6
			g.nz = -0.3
			g.hx = 0.04
		"crouch":
			g.ls = 0.55
			g.uy = -0.28
			g.ux = 0.3
			g.hx = 0.2
			g.nx = -0.7
			g.nz = -0.25
		"clap":
			# 跟著拍手：一秒 1.13 下，跟音符的拍子（0.6 秒一拍）對不上
			var c := sin(t * TAU * 1.13)
			var open := maxf(c, 0.0)
			g.nx = -1.3
			g.px = -1.3
			g.nz = 0.32 - open * 0.6
			g.pz = -0.32 + open * 0.6
			g.by = absf(c) * 0.03
			g.hz = sin(t * 2.0) * 0.12
		"reach":
			g.px = -2.6
			g.pz = 0.15
			g.hx = -0.35
		"scrub":
			var sc := sin(t * 15.0)
			g.px = -0.95 + sc * 0.12
			g.pz = 0.1 + sc * 0.3
			g.brz = sc * 0.03
			g.ux = 0.12
			g.nx = -0.2
			g.nz = -0.3
		"give":
			g.nx = -1.2
			g.px = -1.2
			g.nz = 0.12
			g.pz = -0.12
			g.ux = 0.08
		"wave":
			# 手舉到旁邊揮（從背後看也看得到）
			g.px = -2.3
			g.pz = 0.95 + sin(t * 9.0) * 0.35
			g.nx = -0.35
			g.nz = -0.12
			g.hz = sin(t * 4.5) * 0.06
		"hold":
			g.nx = -0.4
			g.nz = -0.12
	if _g.look is Vector3:
		var head := _g.head as Node3D
		var d: Vector3 = (_g.look as Vector3) - head.global_position
		var yaw := wrapf(atan2(d.x, d.z) - root.global_rotation.y, -PI, PI)
		g.hy = clampf(yaw, -1.0, 1.0)
		g.hx = float(g.hx) + clampf(-atan2(d.y, Vector2(d.x, d.z).length()), -0.6, 0.6)
	if _typing and _name.text == "小紅帽":
		g.hx = float(g.hx) + sin(_t * 15.0) * 0.07
	var v: Dictionary = _g.v
	var k := 1.0 - exp(-dt * 12.0)
	for key in g:
		v[key] = lerpf(float(v.get(key, g[key])), float(g[key]), k)
	(_g.body as Node3D).position.y = float(v.by)
	(_g.body as Node3D).rotation.z = float(v.brz)
	var ls := float(v.ls)
	(_g.lower as Node3D).scale = Vector3(1.0 + (1.0 - ls) * 0.45, ls, 1.0 + (1.0 - ls) * 0.45)
	(_g.upper as Node3D).position.y = 0.62 + float(v.uy)
	(_g.upper as Node3D).rotation.x = float(v.ux)
	(_g.head as Node3D).rotation = Vector3(v.hx, v.hy, v.hz)
	(_g.arm_n as Node3D).rotation = Vector3(v.nx, 0, v.nz)
	(_g.arm_p as Node3D).rotation = Vector3(v.px, 0, v.pz)
	# 拍手：手合起來的那一下冒一個「啪」（沒有聲音：靜音拍只留蟲鳴）
	if String(_g.anim) == "clap":
		var c2 := sin(t * TAU * 1.13)
		if _clap_prev > 0.0 and c2 <= 0.0:
			var up := _g.upper as Node3D
			_emote(up.global_position + up.global_basis.z * 0.42 + Vector3(0, 0.45, 0), "啪", Color(1, 0.95, 0.8), 0.5, 0.45, 0.3)
		_clap_prev = c2

func _path_at(pts: Array, d: float) -> Dictionary:
	for i in pts.size() - 1:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var ln := a.distance_to(b)
		if d <= ln:
			return {"p": a.lerp(b, d / ln), "dir": (b - a) / ln}
		d -= ln
	return {}

## 小紅帽頭頂上面（冒字用）
func _girl_head() -> Vector3:
	return (_g.head as Node3D).global_position + Vector3(0, 0.55, 0)

## 小紅帽站到 p、面向 target
func _girl_at(p: Vector2, target: Vector3, anim := "idle") -> void:
	var n := _g.node as Node3D
	n.visible = true
	n.global_position = G(p)
	var d := target - n.global_position
	n.rotation = Vector3(0, atan2(d.x, d.z), 0)
	_g.anim = anim
	_g.look = null

# ================================================================== 每一畫面

func _story_tick(dt: float) -> void:
	_girl_tick(dt)
	if _foam:
		_foam.position.z = _shore_z + sin(_t * 1.1) * 0.22
	# 菸蒂的白煙：幾顆小球輪流往上飄、變大、散掉
	for k in _smoke.size():
		var b := _smoke[k] as MeshInstance3D
		var ph := fmod(_t * 0.42 + float(k) / float(_smoke.size()), 1.0)
		b.global_position = _butt + Vector3(sin(ph * 5.0 + float(k)) * 0.07 + ph * 0.12, 0.08 + ph * 0.95, 0)
		b.scale = Vector3.ONE * (0.4 + ph * 1.6) * sin(ph * PI)
	# 狼外婆追著兔子標本衝進林子
	if _chase_on and _wolf:
		var dw := maxf(_shot_t - 0.35, 0.0) * 3.4
		var w := _path_at(CHASE, dw)
		if w.is_empty():
			_wolf.visible = false
		else:
			var p: Vector2 = w.p
			var dir: Vector2 = w.dir
			_wolf.global_position = Vector3(p.x, float(_world.height_at(p.x, p.y)), p.y)
			_wolf.rotation.y = atan2(dir.x, dir.y)
		if not _cap_off and dw >= _cap_d:
			_cap_off = true
			_snag_cap()
		var r := _path_at(CHASE, dw + 1.9)
		if r.is_empty():
			_rabbit.visible = false
		else:
			var q: Vector2 = r.p
			var hop := absf(sin((dw + 1.9) * 1.6))
			_rabbit.global_position = Vector3(q.x, float(_world.height_at(q.x, q.y)) + hop * 0.55, q.y)
			_rabbit.rotation = Vector3(-(dw + 1.9) * 2.4, atan2((r.dir as Vector2).x, (r.dir as Vector2).y), 0)
	# 上船：小船往外海走
	if _leave_on and _boat:
		var k := clampf(_shot_t / 5.4, 0.0, 1.0)
		var e := k * k * (3.0 - 2.0 * k)
		_boat_at(_boat, BOAT_A.lerp(BOAT_B, e), BOAT_B - BOAT_A)
		_in_boat()
	elif _boat and _boat.visible:
		_boat_at(_boat, BOAT_A, BOAT_B - BOAT_A)

## 睡帽被樹枝勾走：從狼外婆頭上飛到樹枝上，掛在那裡
func _snag_cap() -> void:
	if _cap == null:
		return
	var from := _cap.global_position
	_cap.reparent(self)
	var to := _cap_branch
	var arc := func(k: float) -> void:
		var q := from.lerp(to, k)
		q.y += sin(k * PI) * 0.4
		_cap.global_position = q
		_cap.rotation = Vector3(-0.5 * k, k * 1.2, 0.6 * k)
	var tw := _tw()
	tw.tween_method(arc, 0.0, 1.0, 0.35)
	tw.tween_callback(func():
		_emote(to + Vector3(0, 0.35, 0), "沙沙", Color(0.8, 1.0, 0.7), 0.8, 0.6)
		_play("whoosh", -14.0, 1.6))

## 坐在船上：家豪和小黃雞都轉過頭去看岸上的小紅帽
func _in_boat() -> void:
	(_hero.node as Node3D).global_position = _boat.to_global(Vector3(0, 0.24, -0.2))
	(_hero.node as Node3D).rotation.y = _boat.rotation.y + PI
	var ch := _chick.node as Node3D
	ch.global_position = _boat.to_global(Vector3(0.45, 0.26, -0.55))
	ch.rotation.y = _boat.rotation.y + PI

## 小黃雞從籃子跳出來（換到場景底下，之後自己走）
func _chick_out() -> void:
	var ch := _chick.node as Node3D
	if ch.get_parent() != self:
		ch.reparent(self)
		ch.rotation = Vector3.ZERO
		ch.scale = Vector3.ONE * (ch.scale.x)

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
	_chase_on = false
	if _boat:
		_boat.visible = s in ["boat", "leave"]
	if _wolf:
		_wolf.visible = false
	if _rabbit:
		_rabbit.visible = false
	(_g.node as Node3D).visible = false
	_g.look = null
	_bucket.visible = s == "scrub"
	if _far:
		_far.visible = not (s in ["boat", "leave", "journal"])
	_lantern.visible = s in ["boat", "leave"]
	# 刷過號碼之後：樹上的號碼都只剩淡淡的一點
	if not (s in ["chase", "yard", "scrub"]):
		for l in _numbers:
			_rubbed(l)
	match s:
		"chase":
			hero.visible = false
			_chase_on = true
			if _wolf:
				_wolf.visible = true
				_rabbit.visible = true
				if _wolf_ap and _wolf_ap.has_animation("Run"):
					_wolf_ap.play("Run", -1, 1.3)
		"yard":
			hero.visible = false
		"scrub":
			hero.visible = false
			var info: Dictionary = _scrub.get("info", {})
			if not info.is_empty():
				var tp: Vector3 = info.pos
				var f: Vector3 = _scrub.face
				var side := Vector3(-f.z, 0, f.x)
				var at := tp + f * 0.72 - side * 0.42
				_girl_at(Vector2(at.x, at.z), tp + Vector3(0, 0.7, 0), "idle")
				var b := at + side * 0.55 + f * 0.25
				_bucket.global_position = G(Vector2(b.x, b.z))
		"tag":
			# 兩個人面對面，各往鏡頭這邊轉一點
			hero.global_position = G(TAG_HERO)
			_face(_hero, G(TAG_GIRL) + Vector3(0, 0, 1.2))
			_girl_at(TAG_GIRL, G(TAG_HERO) + Vector3(0, 0, 1.2), "crouch")
			_g.look = _tag66.global_position if _tag66 else hero.global_position + Vector3(0, 1.0, 0)
		"dj", "hood":
			hero.global_position = _pile_top()
			_face(_hero, _pile_top() + Vector3(-0.4, 0, 3.0))   # 羽毛：背對鏡頭，看著南邊的海
			_girl_at(GIRL_DJ, _pile_top(), "idle")
			_g.look = _pile_top() + Vector3(0, 1.3, 0)
			if s == "dj":
				hero.global_position = G(PILE + Vector2(-0.4, 1.3))
				_face(_hero, _pile_top())
		"boat":
			hero.global_position = G(SHORE_HERO)
			_face(_hero, G(SHORE_GIRL) + Vector3(0, 0, 1.0))
			_girl_at(SHORE_GIRL, G(SHORE_HERO) + Vector3(0, 0, 1.0), "hold")
			_boat_at(_boat, BOAT_A, BOAT_B - BOAT_A)
		"leave":
			_leave_on = true
			_chick_out()
			_boat_at(_boat, BOAT_A, BOAT_B - BOAT_A)
			_in_boat()
			_girl_at(SHORE_GIRL, BOAT_B, "wave")
		"journal":
			hero.visible = false

func _on_line(l: Dictionary) -> void:
	var hero := _hero.node as Node3D
	match String(l.get("cue", "")):
		# ---------------------------------------------------------- ① 收場
		"c_chase":
			# 狼外婆從門口衝出來，追著兔子標本衝進林子；睡帽被樹枝勾走
			_shot_cam(Vector3(0.9, 1.6, 10.2), Vector3(-3.4, 1.5, 5.8), 48.0, 0.0, Vector3(-0.18, 0.0, -0.04))
			_music_play("theme", -20.0, 2.0)
			_amb_play("night", -17.0, 1.0)
			_at(0.25, func():
				if _wolf:
					_emote(_wolf.global_position + Vector3(0, 3.0, 0), "嗷嗚——！", Color(1, 0.95, 0.85), 1.4, 0.8)
				_play("howl", -10.0))
		"y_god":
			# 伐木工和抽菸的人躺了一地，被水桶澆熄的菸蒂冒出一縷白煙
			_shot_cam(Vector3(0.3, 2.3, 13.8), Vector3(0.6, 0.3, 8.5), 50.0, 0.0, Vector3(0.0, -0.04, -0.12))
			for k in _men.size():
				var m := _men[k] as Node3D
				_at(0.5 + 0.6 * k, func(): _emote(m.global_position + Vector3(0, 0.8, 0), "@_@" if k != 1 else "Zzz", Color(1, 1, 1), 1.2, 0.6, 0.3))
		# ---------------------------------------------------------- ② 號碼
		"s_scrub":
			# 小紅帽提著水桶，把樹上的紅漆號碼刷掉
			var info: Dictionary = _scrub.get("info", {})
			if info.is_empty():
				return
			var tp: Vector3 = info.pos
			var f: Vector3 = _scrub.face
			var side := Vector3(-f.z, 0, f.x)
			var lab := _scrub.label as Label3D
			_shot_cam(tp + f * 2.1 + side * 2.6 + Vector3(0, 1.05, 0), tp + f * 0.5 + Vector3(0, lab.position.y - tp.y + 0.25, 0), 38.0, 0.0, side * -0.04)
			_at(0.2, func():
				_emote(lab.global_position + f * 0.2 + Vector3(0, 0.3, 0), "嘩啦", Color(0.7, 0.88, 1.0), 0.8, 0.7)
				_play("splash", -10.0))
			_at(0.6, func(): _g.anim = "scrub")
			for k in 3:
				_at(1.0 + 0.8 * k, func():
					_emote(lab.global_position + f * 0.25 + side * (0.3 - 0.3 * k) + Vector3(0, 0.25, 0), "刷", Color(1, 1, 1), 0.6, 0.65)
					_play("brush", -11.0, 0.95 + 0.06 * k))
			_tw().tween_property(lab, "modulate:a", 0.14, 2.2).set_delay(0.9)
			_at(3.4, func():
				_g.anim = "idle"
				_emote(_girl_head(), "♪", Color(1, 0.9, 0.6), 0.9, 0.7))
		# ---------------------------------------------------------- ③ 腳牌
		"g_ask":
			# 小紅帽蹲下來，看家豪脖子上的牌子
			_shot_cam(Vector3(0.05, 1.25, 11.7), Vector3(0.05, 0.75, 7.3), 28.0, 0.0, Vector3(0.0, 0.0, -0.05))
			_amb_play("night", -17.0, 0.5)
		"g_friend":
			_shot_cam(G(TAG_GIRL) + Vector3(0.9, 1.1, 2.5), hero.global_position + Vector3(0, 1.05, 0), 30.0, 0.0, Vector3(0, 0, -0.03))
			_set_anim(_hero, "sad")
		"g_where":
			_shot_cam(G(TAG_HERO) + Vector3(-1.5, 1.0, 2.6), G(TAG_GIRL) + Vector3(0, 0.75, 0), 30.0, 0.0, Vector3(0.02, 0, -0.02))
			_set_anim(_hero, "idle")
			_g.look = hero.global_position + Vector3(0, 1.2, 0)
		"g_look":
			# 家豪看向海那邊
			_shot_cam(G(TAG_HERO) + Vector3(0.8, 1.2, 3.0), hero.global_position + Vector3(0, 1.1, 0), 30.0, 0.0, Vector3(0, 0, 0.03))
			_hero.look = hero.global_position + Vector3(0.5, 1.6, 20.0)
			_face(_hero, hero.global_position + Vector3(0.6, 0, 3.0), 0.5)
		# ---------------------------------------------------------- ④ 靜音拍
		"d_silence":
			# 配樂淡出，只剩蟲鳴。家豪跳上柴堆打碟，灰色的音符往下掉
			_shot_cam(Vector3(0.4, 1.5, 11.4), Vector3(3.7, 1.3, 5.2), 42.0, 0.0, Vector3(0.03, 0.0, -0.08))
			_music_stop(1.6)
			_amb_play("crickets", -13.0, 1.2)
			_at(0.3, func():
				_hop(_hero, _pile_top(), 0.6, 1.0, 0.0, "idle")
				_play("whoosh", -16.0, 1.4))
			_at(0.95, func():
				_face(_hero, G(GIRL_DJ))
				_set_anim(_hero, "dj", 0.8)
				_notes(true))
			# 小紅帽伸手接住一顆音符，放進籃子；跟著拍手，拍錯拍
			_at(2.0, func():
				_g.anim = "reach"
				_g.look = _pile_top() + Vector3(0, 1.8, 0))
			_at(2.3, func():
				var arm := _g.arm_p as Node3D
				_note_to(arm.global_position + Vector3(0, 0.45, 0), 1.2, func():
					_g.anim = "idle"
					_g.look = (_g.basket as Node3D).global_position
					_emote((_g.basket as Node3D).global_position + Vector3(0, 0.35, 0), "♪", GREY, 1.0, 0.6, 0.1)))
			_at(4.2, func():
				_g.look = _pile_top() + Vector3(0, 1.3, 0)
				_emote(_girl_head(), "？", Color(1, 1, 1), 1.0, 0.7))
			_at(4.9, func(): _g.anim = "clap")
		"d_line":
			_shot_cam(_pile_top() + Vector3(-2.2, 0.9, 2.6), _pile_top() + Vector3(0, 1.0, 0), 30.0, 0.0, Vector3(0.0, 0, 0.03))
			_set_anim(_hero, "dj", 0.45)
			_notes(true)
		# ---------------------------------------------------------- ⑤ 羽毛
		"w_gust":
			# 從背後拍：晚風掀起帽沿，帽子底下露出青、黃兩根羽毛尖
			var tp := _pile_top()
			_shot_cam(tp + Vector3(0.3, 1.85, -2.7), tp + Vector3(-0.05, 1.3, 0), 34.0, 0.0, Vector3(0.0, 0, 0.04))
			_set_anim(_hero, "idle")
			_amb_play("wind", -10.0, 0.3)
			_at(0.2, func(): _play("whoosh", -8.0, 0.6))
			_at(0.4, func():
				_hood_lift()
				_play("ding", -16.0, 1.2))
			_at(1.5, func(): _amb.volume_db = -18.0)
		"w_god":
			pass
		"w_molt":
			_at(0.15, func():
				_set_anim(_hero, "cool")
				_hood_down()
				_emote(_hero, "…", Color(1, 1, 1), 1.0, 0.8))
		# ---------------------------------------------------------- ⑥ 上船
		"b_give":
			# 海邊：小紅帽把籃子遞過來，小黃雞跳出來站到家豪旁邊
			_shot_cam(Vector3(-0.5, 1.45, 54.4), G(SHORE_GIRL).lerp(G(SHORE_HERO), 0.5) + Vector3(0.2, 0.75, 0), 34.0, 0.0, Vector3(0, 0, 0.04))
			_music_play("theme", -19.0, 2.5)
			_amb_play("waves", -16.0, 1.0)
			_g.look = hero.global_position + Vector3(0, 1.0, 0)
			_at(0.2, func():
				_g.anim = "give"
				_tw().tween_property(_g.basket, "position", Vector3(0.0, -0.08, 0.42), 0.45).set_trans(Tween.TRANS_SINE))
			_at(0.9, func():
				_chick_out()
				var to := G(SHORE_HERO) + Vector3(0.2, 0, 0.6)
				to.y = _sand_y(to.x, to.z)
				_hop(_chick, to, 0.55, 0.7, 0.0, "idle")
				_play("pop", -12.0, 1.8))
			_at(1.5, func():
				_face(_chick, G(SHORE_GIRL))
				_chick.look = _g.head.global_position
				_emote(_chick, "啾", Color(1, 0.95, 0.6), 0.8, 0.6)
				_hero.look = (_chick.node as Node3D).global_position)
		"b_line":
			_g.anim = "hold"
			_tw().tween_property(_g.basket, "position", BASKET_HIP, 0.4)
			_at(1.4, func():
				_chick.look = hero.global_position + Vector3(0, 1.2, 0)
				_hero.look = null
				_set_anim(_hero, "nod"))
			_at(2.0, func(): _set_anim(_hero, "idle"))
		"l_leave":
			# 小船離岸。小紅帽提著燈在岸邊揮手
			_shot_cam(G(SHORE_GIRL) + Vector3(-2.4, 1.45, -2.6), Vector3(1.6, SEA_Y + 0.6, 56.0), 46.0, 0.0, Vector3(0.03, 0, 0.03))
			_set_anim(_hero, "idle")
			_hero.look = G(SHORE_GIRL) + Vector3(0, 1.2, 0)
			_chick.look = G(SHORE_GIRL) + Vector3(0, 1.2, 0)
			_at(2.5, func(): _emote(_hero, "…", Color(1, 1, 1), 1.0, 0.7))
		# ---------------------------------------------------------- ⑦ 手帳
		"j_page":
			_shot_cam(G(SHORE_GIRL) + Vector3(0.6, 1.6, -1.5), Vector3(0, 16.0, 140.0), 62.0, 0.0, Vector3(0, 0.03, 0.05))
			_at(0.5, func(): _journal_p = _journal_page(2, "外婆家。外婆不在家。", YELLOW, "霧山楓燃"))

# ================================================================== 聲音

func _make_forest_sounds() -> void:
	# 夜裡的林子：低低的風（循環）
	var b := s_buf(4.0)
	for k in 4:
		s_noise(b, k * 1.0, 1.6, 0.14, 0.05, 170 + k, 0.9, true)
	_snd["night"] = s_wav(b, true)
	# 蟲鳴：兩隻蟋蟀一串一串地叫（循環）
	b = s_buf(3.0)
	for k in 6:
		for j in 3:
			s_tone(b, k * 0.5 + j * 0.05, 4300.0, 0.028, 0.08, 0.1, 40.0, true)
			s_tone(b, k * 0.5 + 0.23 + j * 0.06, 3800.0, 0.03, 0.05, 0.1, 40.0, true)
	for k in 3:
		s_noise(b, k * 1.0, 1.4, 0.06, 0.05, 180 + k, 0.9, true)
	_snd["crickets"] = s_wav(b, true)
	# 狼嚎（好笑的那種）
	b = s_buf(1.1)
	s_glide(b, 0.0, 330.0, 620.0, 0.45, 0.32, 0.4)
	s_glide(b, 0.42, 620.0, 380.0, 0.6, 0.3, 0.4)
	_snd["howl"] = s_wav(b)
	# 刷、刷
	b = s_buf(0.3)
	s_noise(b, 0.0, 0.25, 0.55, 0.55, 51, 10.0)
	_snd["brush"] = s_wav(b)
	# 嘩啦（水潑到樹上）
	b = s_buf(0.6)
	s_noise(b, 0.0, 0.55, 0.6, 0.35, 61, 6.0)
	s_glide(b, 0.0, 900.0, 300.0, 0.3, 0.12)
	_snd["splash"] = s_wav(b)
