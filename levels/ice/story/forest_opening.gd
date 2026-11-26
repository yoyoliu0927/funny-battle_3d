extends "res://levels/ice/story/story_kit.gd"
## 駁大莖森的開場動畫（第 2 天）。分鏡在 levels/ice/docs/大關開場與結尾動畫.md 第 5 節。
## 第一次進森林第 1 關之前播（選關地圖問 story_registry.gd），播完進第 1 關。
## 場地借第 1 關「伐木場・早晨」（拿掉戰局和玩家）。森林的場地本來沒有海：島的南邊（平台邊緣、林子外面）
## 自己鋪一段沙灘斜斜地伸進海裡，再鋪一片海，小船從那裡上岸。
##
## 五拍：靠岸（路標「外婆家 →」，小紅帽提著籃子走過去，籃子裡探出小黃雞）→ 號碼（樹幹上的紅漆號碼、松鼠叼著小松鼠跑過去）
##       → 對話（最後天上掉下假獵物和引路點）→ 尋雞啟事（被紅漆噴到一半）→ 標題卡

const STAGE := "res://levels/forest/stage_1/stage.tscn"
const Models := preload("res://levels/forest/items/models.gd")   # 假獵物、引路點的模型（跟遊戲裡同一個）
const K_CASTLE := "res://levels/forest/assets/kenney_castle/"
const SAND := "res://assets/textures/gravelly_sand_diff_1k.jpg"
const SEA_Y := -0.35                 # 自己鋪的海面
const RAMP_Z := 46.5                 # 島的南邊從這裡開始是沙灘，斜斜地伸進海裡
const RAMP_K := 0.33                 # 沙灘的斜度
const PATH_X := 2.9                  # 沙灘進林子的小路
const SIGN_AT := Vector2(1.3, 42.9)  # 路標
const LAND := Vector2(0.4, 50.9)     # 家豪跳上岸的地方
const BOAT_A := Vector3(5.6, SEA_Y, 66.0)
const BOAT_B := Vector3(0.9, SEA_Y, 53.3)
const PAINT := Color(0.84, 0.09, 0.07)   # 紅漆
## 小紅帽走的路：沙灘上從西邊走過來，經過路標，往北走進林子
const GIRL_PATH := [Vector2(-7.6, 45.4), Vector2(0.3, 44.7), Vector2(2.4, 43.6), Vector2(2.9, 41.0), Vector2(3.3, 33.0)]
const GIRL_SPEED := 1.9
const GIRL_PAUSE_D := 8.3            # 走到路標前面停一下（籃子朝著家豪），小黃雞探出頭跟家豪對看
const GIRL_PAUSE_T := 1.7
## 鏡頭前那一排噴了號碼的樹（找離這幾個點最近的樹）：12、13、14。對話在 13 號樹下面
const NUM_SPOTS := [Vector2(-5.9, 12.2), Vector2(-3.3, 8.6), Vector2(-4.7, 5.2)]
const DOLLY_EYE := Vector2(0.4, 9.6)     # 號碼都噴在朝這裡的那一面（「號碼」那個鏡頭就擺在這裡）
const BASKET_HIP := Vector3(-0.31, -0.28, 0.08)   # 籃子掛在右手邊（走過沙灘時朝著家豪那一側）

func _lines() -> Array:
	return [
		{"shot": "sea", "hold": 4.6, "cue": "o_sea", "fade_in": 1.4},
		{"shot": "shore", "hold": 3.2, "cue": "o_land"},
		{"shot": "hood", "hold": 3.6, "cue": "o_hood"},
		{"shot": "chick", "hold": 2.8, "cue": "o_chick", "fade_out": 0.15, "fade_in": 0.2},
		{"shot": "trees", "hold": 4.2, "cue": "o_trees"},
		{"shot": "talk", "who": "神明", "text": "噴了號碼的樹，今天都要倒。", "cue": "t_fall"},
		{"shot": "talk", "who": "家豪", "text": "……跟腳牌一樣。", "cue": "t_tag", "snap": 1.8},
		{"shot": "talk", "who": "神明", "text": "這片森林的神請假。今天我代班。", "cue": "t_sub"},
		{"shot": "talk", "who": "家豪", "text": "……你會嗎。", "cue": "t_can", "snap": 1.2},
		{"shot": "talk", "who": "神明", "text": "不會。但這裡的供品比較多。", "cue": "t_offer"},
		{"shot": "talk", "hold": 2.6, "cue": "t_drop"},
		{"shot": "talk", "hold": 1.6, "cue": "p_in"},
		{"shot": "talk", "who": "家豪", "text": "……漲了。", "cue": "p_read", "snap": 1.0},
		{"shot": "talk", "hold": 1.8, "cue": "p_out"},
		{"shot": "card", "hold": 4.0, "cue": "card", "fade_out": 0.5, "fade_in": 0.9},
	]

func _skip_text() -> String:
	return "跳過開場"

func _next_scene() -> String:
	return _stage_after(STAGE)

func _voice_pitch(who: String) -> float:
	if who == "小紅帽":
		return 1.8
	return super(who)

var _world
var _env: Environment
var _fog0 := 0.004
var _boat: Node3D
var _boat_go := false
var _foam: MeshInstance3D
var _shore_z := 52.0                 # 沙灘碰到海的地方
var _sign: Node3D
var _g: Dictionary = {}              # 小紅帽
var _chick: Dictionary = {}          # 籃子裡的小黃雞
var _walk_t := -1.0                  # 小紅帽走了幾秒（-1＝還沒開始走）
var _squirrel: Node3D
var _sq_t := -1.0
var _t13: Dictionary = {}            # 13 號樹 {pos, sc, big}
var _f13 := Vector3(0, 0, 1)         # 13 號樹噴號碼的那一面朝哪（水平）
var _talk_at := Vector3.ZERO         # 家豪在 13 號樹下站的地方
var _poster3d := Vector3.ZERO        # 樹幹上那張懸賞單
var _decoy: Node3D
var _flag: Node3D
var _poster_p: Control
var _card_p: Control

func _story_build() -> void:
	mark_seen("forest_opening")      # 先記下來：底下借第 1 關的場地時，那一關就不會又轉回開場
	var stage := _borrow_stage(STAGE)
	_world = stage.get_node("World")
	_env = _env_node.environment if _env_node else null
	if _env:
		_fog0 = _env.fog_density
	_make_forest_sounds()
	var motes = _world.get_node_or_null("Motes")
	if motes is Node3D:
		(motes as Node3D).visible = false   # 空氣裡飄的花粉：遊戲的鏡頭很遠才好看，特寫時會變成一顆一顆的大圓片
	_build_shore(Color(0.10, 0.38, 0.52), Color(0.48, 0.78, 0.82))
	_edge_trees()
	if _world.has_method("dirt_path"):
		_world.dirt_path(Vector2(PATH_X - 0.1, 42.2), Vector2(3.3, 30.0))
	_build_sign()
	_number_trees()
	_make_hero(self)
	_boat = _make_boat()
	_g = _make_girl()
	_chick = _make_chick(_g.basket as Node3D)
	(_chick.node as Node3D).visible = false
	_squirrel = _make_squirrel()
	_squirrel.visible = false
	# 神明丟下來的供品：假獵物（兔子標本）和引路點（插在地上的小旗子）
	_decoy = Node3D.new()
	add_child(_decoy)
	Models.decoy(_decoy)
	_decoy.scale = Vector3.ONE * 0.95
	_decoy.visible = false
	_flag = Node3D.new()
	add_child(_flag)
	Models.guide(_flag)
	var num := _label3d("1", 56, Color(1, 0.95, 0.55), 12)
	num.position = Vector3(0, 1.28, 0)
	_flag.add_child(num)
	_flag.scale = Vector3.ONE * 1.2
	_flag.visible = false

## 地面上（沙灘或草地）的點
func _ground(p: Vector2) -> Vector3:
	return Vector3(p.x, _sand_y(p.x, p.y), p.y)

## 早晨的薄霧：海邊那幾個鏡頭霧濃一點
func _mist(on: bool) -> void:
	if _env:
		_env.fog_density = 0.0075 if on else _fog0

# ================================================================== 海邊（森林的場地沒有海：自己鋪一段沙灘，接到島外的海）

## 沙灘的高度：平台上貼著地面；過了平台邊緣，照固定的斜度往下伸進海裡（蓋住原本的懸崖）
func _sand_y(x: float, z: float) -> float:
	var t := float(_world.height_at(x, z)) + 0.05
	if z <= RAMP_Z:
		return t
	return maxf(t, float(_world.height_at(x, RAMP_Z)) + 0.05 - (z - RAMP_Z) * RAMP_K)

func _build_shore(deep: Color, light: Color) -> void:
	_shore_z = RAMP_Z + (float(_world.height_at(0.0, RAMP_Z)) + 0.05 - SEA_Y) / RAMP_K
	# 沙灘：一張貼著地形的網格。北邊的邊緣歪歪扭扭的，跟草地交界
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
	# 海：一大片，蓋住島外面往下掉的地形。靠岸那一條半透明，看得到底下的沙
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
	# 浪花：沿著岸邊一條白線，前前後後地動
	_foam = _box(self, Vector3(44.0, 0.01, 0.4), Vector3(0, SEA_Y + 0.02, _shore_z), _glow(Color(1, 1, 1), 0.55))
	_foam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

## 林子的邊緣：沙灘後面補一排樹（跟場地外圈的樹同一種、同一個上色），小路那裡空著
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
		if absf(x - PATH_X) < 2.0 or Vector2(x, z).distance_to(SIGN_AT) < 2.4:
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

## 路標「外婆家 →」，旁邊釘著一塊新的「伐木區　閒人勿進」
func _build_sign() -> void:
	_sign = Node3D.new()
	add_child(_sign)
	_sign.position = _ground(SIGN_AT)
	_sign.rotation.y = -0.2
	var wood := _toon(Color(0.50, 0.34, 0.20))
	var board := _toon(Color(0.80, 0.62, 0.40))
	_box(_sign, Vector3(0.13, 2.0, 0.13), Vector3(0, 1.0, 0), wood)
	_box(_sign, Vector3(1.1, 0.36, 0.07), Vector3(0.42, 1.68, 0.08), board)
	_box(_sign, Vector3(0.27, 0.27, 0.07), Vector3(0.97, 1.68, 0.08), board, Vector3(0, 0, PI * 0.25))   # 箭頭尖
	_sign_text("外婆家 →", 70, Color(0.30, 0.18, 0.10), Vector3(0.44, 1.68, 0.122))
	# 新釘上去的牌子：白底紅字
	_box(_sign, Vector3(1.0, 0.46, 0.05), Vector3(-0.08, 1.06, 0.1), _toon(Color(0.96, 0.94, 0.88)))
	_box(_sign, Vector3(1.0, 0.07, 0.055), Vector3(-0.08, 1.26, 0.103), _toon(Color(0.84, 0.12, 0.10)))
	_sign_text("伐木區", 58, Color(0.82, 0.10, 0.08), Vector3(-0.08, 1.11, 0.13))
	_sign_text("閒人勿進", 44, Color(0.25, 0.16, 0.10), Vector3(-0.08, 0.95, 0.13))
	for x in [-0.5, 0.34]:
		_box(_sign, Vector3(0.03, 0.03, 0.02), Vector3(x, 1.23, 0.13), _toon(Color(0.3, 0.3, 0.32)))

func _sign_text(text: String, size: int, col: Color, at: Vector3) -> void:
	var l := Label3D.new()
	l.text = text
	if UIStyle.font():
		l.font = UIStyle.font()
	l.font_size = size
	l.pixel_size = 0.0034
	l.modulate = col
	l.outline_size = 0
	l.double_sided = false
	l.shaded = true
	l.position = at
	l.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_sign.add_child(l)

# ================================================================== 樹幹上的紅漆號碼

## 每一棵樹噴一個號碼：鏡頭前那一排是 12、13、14，其他照離小路口的遠近往下編
func _number_trees() -> void:
	var trees = _world.get("trees")
	if not (trees is Array) or (trees as Array).is_empty():
		return
	var nums := {}
	var n := 12
	for spot in NUM_SPOTS:
		var best := -1
		var bd := 1e9
		for i in (trees as Array).size():
			var p: Vector3 = trees[i].pos
			var d := Vector2(p.x, p.z).distance_to(spot)
			if d < bd and not nums.has(i):
				bd = d
				best = i
		if best >= 0:
			nums[best] = n
			n += 1
	var rest: Array = []
	for i in (trees as Array).size():
		if not nums.has(i):
			rest.append(i)
	var dist := func(i: int) -> float:
		var p: Vector3 = trees[i].pos
		return Vector2(p.x, p.z).distance_to(Vector2(0, 13))
	rest.sort_custom(func(a, b): return float(dist.call(a)) < float(dist.call(b)))
	for i in rest:
		nums[i] = n
		n += 1
	for i in nums:
		var info := _tree_info(trees[i])
		_paint_number(str(nums[i]), info, DOLLY_EYE)
		if int(nums[i]) == 13:
			_t13 = info
	if _t13.is_empty():
		return
	# 13 號樹：家豪站的地方、樹幹上的懸賞單
	var p13: Vector3 = _t13.pos
	var f := DOLLY_EYE - Vector2(p13.x, p13.z)
	f = f.normalized()
	_f13 = Vector3(f.x, 0, f.y)
	var right := Vector3(-_f13.z, 0, _f13.x) * -1.0     # 從正面看過去的右手邊
	var at := p13 + _f13 * 1.05 + right * 1.1
	_talk_at = Vector3(at.x, float(_world.height_at(at.x, at.z)), at.z)
	_trunk_poster()

## 樹的大小：樹幹（樹冠底下露出來的那一段）多粗、多高
func _tree_info(t: Dictionary) -> Dictionary:
	var n := t.node as Node3D
	var h := float(n.get_meta("h", 3.0))
	var big := true
	var crown := n.get_node_or_null("Crown")
	if crown and crown.get_child_count() > 0:
		big = String(crown.get_child(0).scene_file_path).contains("large")
	return {"pos": n.global_position, "sc": h / (1.85 if big else 1.35), "big": big}

## 噴在樹幹上的號碼（朝 eye 那一面）
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

## 13 號樹的樹幹上釘著一張尋雞啟事，號碼噴在它上面，蓋掉一半
func _trunk_poster() -> void:
	var p13: Vector3 = _t13.pos
	var sc := float(_t13.sc)
	var r := 0.13 * sc + 0.012
	var hy := 0.33 * sc
	var right := Vector3(_f13.z, 0, -_f13.x)
	_poster3d = p13 + _f13 * r + Vector3(0, hy, 0) - right * 0.05
	var holder := Node3D.new()
	add_child(holder)
	holder.global_position = _poster3d
	holder.rotation = Vector3(0, atan2(_f13.x, _f13.z), -0.05)
	_box(holder, Vector3(0.30, 0.40, 0.01), Vector3.ZERO, _toon(Color(0.95, 0.88, 0.70)))
	_box(holder, Vector3(0.14, 0.13, 0.012), Vector3(-0.02, 0.02, 0.002), _toon(Color(0.30, 0.28, 0.30)))   # 照片
	var t := _label3d("尋雞啟事", 40, Color(0.80, 0.22, 0.18), 0)
	t.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	t.no_depth_test = false
	t.pixel_size = 0.0016
	t.double_sided = false
	t.position = Vector3(0, 0.14, 0.008)
	holder.add_child(t)
	var rw := _label3d("懸賞：飼料三包", 26, Color(0.25, 0.16, 0.1), 0)
	rw.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	rw.no_depth_test = false
	rw.pixel_size = 0.0016
	rw.double_sided = false
	rw.position = Vector3(0, -0.13, 0.008)
	holder.add_child(rw)
	_box(holder, Vector3(0.02, 0.02, 0.02), Vector3(0, 0.18, 0.01), _toon(Color(0.3, 0.3, 0.32)))     # 釘子

# ================================================================== 2D 的懸賞單：上半張被紅漆噴了一個大大的 13

func _spray(p: Control) -> void:
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func(): _draw_spray(c))
	p.add_child(c)

func _draw_spray(c: Control) -> void:
	var sz := c.size
	var red := Color(PAINT, 0.86)
	var f := UIStyle.font()
	if f:
		c.draw_set_transform(Vector2(sz.x * 0.36, sz.y * 0.47), -0.2, Vector2.ONE)
		c.draw_string(f, Vector2.ZERO, "13", HORIZONTAL_ALIGNMENT_LEFT, -1, 190, red)
		c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	c.draw_line(Vector2(sz.x * 0.30, sz.y * 0.13), Vector2(sz.x * 1.04, sz.y * 0.05), red, 16.0, true)
	c.draw_line(Vector2(sz.x * 0.56, sz.y * 0.07), Vector2(sz.x * 1.02, sz.y * 0.30), Color(red, 0.6), 10.0, true)
	# 往下流的漆
	for k in 5:
		var x := sz.x * (0.50 + 0.1 * k)
		var y0 := sz.y * (0.44 + 0.02 * float(k % 2))
		var ln := 26.0 + float((k * 37) % 50)
		c.draw_line(Vector2(x, y0), Vector2(x, y0 + ln), red, 6.0, true)
		c.draw_circle(Vector2(x, y0 + ln), 5.0, red)

# ================================================================== 小紅帽（跟木屋裡那個同一個樣子：白洋裝、紅斗篷、紅兜帽；多了手，可以提籃子、拍手、揮手）

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
	_cyl(upper, 0.11, 0.40, 0.74, Vector3(0, 0.07, -0.04), red, Vector3.ZERO, 14)       # 斗篷
	_box(upper, Vector3(0.1, 0.1, 0.1), Vector3(0, 0.46, 0.0), skin)
	_ball(upper, 0.038, Vector3(0, 0.41, 0.115), dress, Vector3.ONE, 8)                  # 領口的結
	var head := Node3D.new()
	head.position = Vector3(0, 0.5, 0)
	upper.add_child(head)
	_ball(head, 0.18, Vector3(0, 0.08, 0.02), skin)
	_ball(head, 0.185, Vector3(0, 0.12, -0.02), hair, Vector3(1.0, 0.82, 1.0))
	_box(head, Vector3(0.24, 0.06, 0.06), Vector3(0, 0.19, 0.15), hair)                  # 瀏海
	for sx in [-1.0, 1.0]:
		_ball(head, 0.022, Vector3(0.065 * sx, 0.08, 0.188), dark, Vector3(1.0, 1.35, 0.5), 8)
		_ball(head, 0.03, Vector3(0.11 * sx, 0.03, 0.155), _toon(Color(0.98, 0.62, 0.62)), Vector3(1.0, 0.6, 0.5), 8)
	_box(head, Vector3(0.05, 0.012, 0.012), Vector3(0, 0.005, 0.196), _toon(Color(0.6, 0.18, 0.18)))
	_ball(head, 0.215, Vector3(0, 0.11, -0.045), red)                                    # 兜帽
	_ball(head, 0.06, Vector3(0, 0.23, -0.25), red, Vector3(1.0, 1.0, 1.4), 8)           # 兜帽尖
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

## 籃子（開口朝上，小黃雞坐在裡面）：原點在籃底中間
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
	_box(b, Vector3(w + 0.02, 0.04, 0.012), Vector3(0, h * 0.45, d * 0.5 + 0.016), weave)   # 編織紋
	for sx in [-1.0, 1.0]:
		_box(b, Vector3(0.03, 0.28, 0.03), Vector3(sx * (w * 0.5 - 0.03), h + 0.14, 0), wick)
	_box(b, Vector3(w - 0.03, 0.03, 0.03), Vector3(0, h + 0.28, 0), wick)
	# 紅格子布掛在籃邊
	_box(b, Vector3(0.2, 0.12, 0.012), Vector3(-0.1, h - 0.04, d * 0.5 + 0.022), _toon(Color(0.86, 0.24, 0.22)))
	_box(b, Vector3(0.05, 0.05, 0.014), Vector3(-0.15, h - 0.02, d * 0.5 + 0.024), _toon(Color(0.97, 0.94, 0.88)))
	_box(b, Vector3(0.05, 0.05, 0.014), Vector3(-0.05, h - 0.07, d * 0.5 + 0.024), _toon(Color(0.97, 0.94, 0.88)))
	return b

## 小黃雞：農莊的圓滾滾小雞換成黃色、拿掉雞冠
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
			mi.visible = false               # 雞冠：小雞還沒長
		elif cc.r > 0.9 and cc.g > 0.7 and cc.b < 0.4:
			sm.set_shader_parameter("albedo", Color(1.0, 0.56, 0.16))
	_no_shadow(c.node)
	return c

## 小紅帽的動作：走路（蹦蹦跳跳）、拍手……每一畫面照 _g.anim 慢慢轉過去
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

## 走了 d 公尺：在路上的哪裡、往哪個方向。走完了回傳 {}
func _path_at(pts: Array, d: float) -> Dictionary:
	for i in pts.size() - 1:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var ln := a.distance_to(b)
		if d <= ln:
			return {"p": a.lerp(b, d / ln), "dir": (b - a) / ln}
		d -= ln
	return {}

# ================================================================== 松鼠（叼著小松鼠，從鏡頭前面跑過去）

func _make_squirrel() -> Node3D:
	var n := Node3D.new()
	add_child(n)
	var fur := _toon(Color(0.48, 0.27, 0.13))
	var pale := _toon(Color(0.95, 0.82, 0.62))
	var eye := _toon(Color(0.08, 0.06, 0.05))
	_box(n, Vector3(0.15, 0.14, 0.28), Vector3(0, 0.13, 0), fur)
	_box(n, Vector3(0.12, 0.08, 0.18), Vector3(0, 0.07, 0.02), pale)
	_box(n, Vector3(0.13, 0.12, 0.13), Vector3(0, 0.21, 0.17), fur)
	for sx in [-1.0, 1.0]:
		_box(n, Vector3(0.035, 0.06, 0.02), Vector3(0.04 * sx, 0.29, 0.15), fur)
		_box(n, Vector3(0.02, 0.025, 0.01), Vector3(0.05 * sx, 0.23, 0.236), eye)
	_ball(n, 0.075, Vector3(0, 0.2, -0.17), fur, Vector3(0.8, 1.3, 0.8), 8)
	_ball(n, 0.09, Vector3(0, 0.35, -0.21), fur, Vector3(0.8, 1.2, 0.8), 8)
	_ball(n, 0.07, Vector3(0, 0.46, -0.14), fur, Vector3.ONE, 8)
	# 嘴裡叼著的小松鼠
	_box(n, Vector3(0.07, 0.06, 0.12), Vector3(0, 0.15, 0.29), pale)
	_ball(n, 0.035, Vector3(0, 0.19, 0.22), fur, Vector3.ONE, 6)
	_no_shadow(n)
	n.scale = Vector3.ONE * 1.8
	return n

# ================================================================== 每一畫面

func _story_tick(dt: float) -> void:
	_girl_tick(dt)
	if _foam:
		_foam.position.z = _shore_z + sin(_t * 1.1) * 0.22
	if _boat_go:
		var k := clampf(_shot_t / 4.4, 0.0, 1.0)
		var e := 1.0 - pow(1.0 - k, 2.2)
		_boat_at(_boat, BOAT_A.lerp(BOAT_B, e), BOAT_B - BOAT_A)
		_hero_in_boat()
	elif _boat and _boat.visible:
		_boat_at(_boat, BOAT_B, BOAT_B - BOAT_A)
	# 小紅帽：沿著路蹦蹦跳跳地走，走進林子就不見了
	if _walk_t >= 0.0:
		_walk_t += dt
		var d := _walk_t * GIRL_SPEED
		var paused := d > GIRL_PAUSE_D and d < GIRL_PAUSE_D + GIRL_PAUSE_T * GIRL_SPEED
		if d > GIRL_PAUSE_D:
			d = maxf(GIRL_PAUSE_D, d - GIRL_PAUSE_T * GIRL_SPEED)
		var w := _path_at(GIRL_PATH, d)
		var gn := _g.node as Node3D
		if w.is_empty():
			gn.visible = false
			_walk_t = -1.0
		else:
			var p: Vector2 = w.p
			var dir: Vector2 = w.dir
			gn.global_position = _ground(p)
			gn.rotation.y = lerp_angle(gn.rotation.y, atan2(dir.x, dir.y), 1.0 - exp(-dt * 8.0))
			_g.anim = "idle" if paused else "walk"
			_g.look = (_hero.node as Node3D).global_position + Vector3(0, 1.2, 0) if paused else null
			# 家豪一直看著她；推近籃子的那個鏡頭跟著籃子走
			_hero.look = (_g.head as Node3D).global_position
			# 籃子裡的小黃雞整隻轉過去看家豪
			var ch := _chick.node as Node3D
			if ch.visible:
				var hd := (_hero.node as Node3D).global_position - ch.global_position
				ch.global_rotation = Vector3(0, atan2(hd.x, hd.z), 0)
			if _shot == "chick":
				_track((_g.basket as Node3D).global_position + Vector3(0, 0.5, 0))
	# 松鼠：一蹦一蹦地橫過鏡頭前面
	if _sq_t >= 0.0 and _squirrel:
		_sq_t += dt
		var k := _sq_t / 1.3
		if k >= 1.0:
			_squirrel.visible = false
			_sq_t = -1.0
		else:
			var a := Vector2(-2.8, 11.3)
			var b := Vector2(-1.8, 6.6)
			var q := a.lerp(b, k)
			_squirrel.visible = true
			_squirrel.global_position = Vector3(q.x, float(_world.height_at(q.x, q.y)) + absf(sin(k * PI * 5.0)) * 0.4, q.y)
			_squirrel.rotation = Vector3(0, atan2(b.x - a.x, b.y - a.y), 0)

func _hero_in_boat() -> void:
	if _boat:
		(_hero.node as Node3D).global_position = _boat.to_global(Vector3(0, 0.24, -0.3))
		(_hero.node as Node3D).rotation.y = _boat.rotation.y

## 鏡頭一直看著某個東西（跟著走）
func _track(look: Vector3) -> void:
	_cam_a.l = look
	_cam_b.l = look

# ================================================================== 鏡頭

func _enter_shot(s: String) -> void:
	var hero := _hero.node as Node3D
	hero.visible = true
	hero.rotation = Vector3.ZERO
	_hero.look = null
	_set_anim(_hero, "idle")
	_boat_go = false
	if _boat:
		_boat.visible = s in ["sea", "shore", "hood"]
	if s != "chick":
		(_g.node as Node3D).visible = s == "hood"
	if not (s in ["hood", "chick"]):
		_walk_t = -1.0                   # 快轉過去的話：小紅帽已經走進林子了
	if _squirrel:
		_squirrel.visible = false
		_sq_t = -1.0
	_mist(s in ["sea", "shore", "hood", "chick"])
	match s:
		"sea":
			_boat_go = true
			_boat_at(_boat, BOAT_A, BOAT_B - BOAT_A)
			_hero_in_boat()
			_hero.look = _sign.global_position + Vector3(0, 1.6, 0)
		"shore":
			_boat_at(_boat, BOAT_B, BOAT_B - BOAT_A)
			_hero_in_boat()
		"hood", "chick":
			hero.global_position = _ground(LAND)
			_face(_hero, _ground(Vector2(0.5, 44.0)))
			if s == "hood":
				_walk_t = 0.0
				var gn := _g.node as Node3D
				gn.visible = true
				var w := _path_at(GIRL_PATH, 0.0)
				gn.global_position = _ground(w.p)
				gn.rotation.y = atan2((w.dir as Vector2).x, (w.dir as Vector2).y)
				var ch := _chick.node as Node3D
				ch.visible = false
				ch.position = Vector3(0, -0.06, 0)
		"trees":
			hero.visible = false
		"talk":
			hero.global_position = _talk_at
			_face(_hero, _talk_at + _f13 * 3.0)
		"card":
			hero.visible = false

func _on_line(l: Dictionary) -> void:
	var hero := _hero.node as Node3D
	var hp := hero.global_position
	var f := _f13
	var right := Vector3(f.z, 0, -f.x)               # 從 13 號樹正面看過去的右手邊
	match String(l.get("cue", "")):
		# ---------------------------------------------------------- ① 靠岸
		"o_sea":
			# 早晨的薄霧，貼著海面：小船往沙灘划過去，林子邊立著路標
			_shot_cam(Vector3(9.0, SEA_Y + 1.6, 66.5), Vector3(-0.5, 1.4, 45.0), 40.0, 0.0, Vector3(-0.25, 0.02, -0.4))
			_music_play("theme", -17.0, 2.5)
			_amb_play("shore", -13.0, 1.5)
			for k in 3:
				_at(1.2 + 1.1 * k, func(): _play("chop", -24.0, 0.9 + 0.03 * k))
		"o_land":
			# 從海這邊看：家豪從船上一跳跳上岸，路標在沙丘上
			_shot_cam(Vector3(4.6, 1.5, 57.2), Vector3(0.6, 0.9, 48.0), 42.0, 0.0, Vector3(-0.1, 0.0, -0.15))
			_face(_hero, _ground(Vector2(0.4, 44.0)))
			_at(0.5, func():
				_hop(_hero, _ground(LAND), 0.75, 1.3, 0.0, "idle")
				_play("whoosh", -14.0, 1.3))
			_at(1.3, func(): _play("thud", -16.0, 1.4))
			_at(1.6, func(): _hero.look = _sign.global_position + Vector3(0, 1.6, 0))
			_at(2.3, func(): _emote(_hero, "…", Color(1, 1, 1), 1.0, 0.8))
			_at(2.0, func(): _play("chop", -22.0, 1.0))
		"o_hood":
			# 從家豪背後看上去：戴紅帽子的小女孩提著籃子，蹦蹦跳跳走過路標
			_shot_cam(Vector3(-0.6, 2.5, 56.2), Vector3(-1.9, 1.5, 44.6), 36.0, 0.0, Vector3(0.1, 0.0, -0.1))
			_hero.look = (_g.node as Node3D).global_position + Vector3(0, 1.1, 0)
			_at(1.3, func():
				var ch := _chick.node as Node3D
				ch.visible = true
				_tw().tween_property(ch, "position:y", 0.08, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				_play("pop", -14.0, 1.6))
		"o_chick":
			# 推近籃子：小黃雞探出頭，跟家豪對看一眼
			_shot_cam(Vector3(1.5, 1.95, 48.5), (_g.basket as Node3D).global_position + Vector3(0, 0.5, 0), 25.0)
			var ch := _chick.node as Node3D
			ch.visible = true
			ch.position.y = 0.08
			_chick.look = hero.global_position + Vector3(0, 1.3, 0)
			_g.look = null
			_at(0.8, func():
				_emote(_chick, "？", Color(1, 1, 1), 1.0, 0.6)
				_play("pop", -14.0, 1.9))
			_at(1.6, func(): _emote(_hero, "…", Color(1, 1, 1), 1.0, 0.8))
		# ---------------------------------------------------------- ② 號碼
		"o_trees":
			# 林子裡：樹幹一棵一棵噴著紅漆號碼。遠處咚、咚、咚，一隻松鼠叼著小松鼠跑過去
			_shot_cam(Vector3(DOLLY_EYE.x, 0.95, DOLLY_EYE.y + 0.3), Vector3(-4.4, 0.75, 8.6), 46.0, 0.0, Vector3(0.0, 0.0, -0.16))
			_amb_play("woods", -15.0, 0.6)
			for k in 3:
				_at(0.4 + 0.75 * k, func():
					_play("chop", -12.0, 0.95)
					_emote(Vector3(-11.0, 2.4 + 0.3 * k, 4.0 + 2.2 * k), "咚", Color(1, 0.95, 0.85), 0.9, 0.8))
			_at(1.7, func(): _sq_t = 0.0)
		# ---------------------------------------------------------- ③ 對話
		"t_fall":
			# 低低的往上看：13 號樹和站在樹下的家豪
			_shot_cam(hp + f * 3.4 + right * 0.6 + Vector3(0, 0.45, 0), hp - f * 0.6 - right * 0.7 + Vector3(0, 1.15, 0), 44.0, 0.0, Vector3(0.02, 0.01, 0.0))
			_hero.look = (_t13.pos as Vector3) + Vector3(0, 1.2, 0)
		"t_tag":
			# 低頭看腳上的牌子
			_shot_cam(hp + f * 2.7 + right * 0.9 + Vector3(0, 1.05, 0), hp + Vector3(0, 0.8, 0), 32.0, 0.0, Vector3(0.0, 0, 0.02))
			_hero.look = null
			_set_anim(_hero, "sad")
		"t_sub":
			# 神明的角度：從樹梢往下看
			_shot_cam(hp + f * 2.2 + right * 0.4 + Vector3(0, 6.2, 0), hp + Vector3(0, 0.4, 0), 40.0, 0.0, Vector3(0, -0.05, 0))
			_set_anim(_hero, "lookup")
		"t_can":
			_shot_cam(hp + f * 2.7 - right * 0.6 + Vector3(0, 0.75, 0), hp + Vector3(0, 1.15, 0), 32.0, 0.0, Vector3(0.01, 0, 0.02))
			_set_anim(_hero, "lookup")
		"t_offer":
			_shot_cam(hp + f * 4.6 + right * 1.4 + Vector3(0, 1.6, 0), hp - right * 0.3 + Vector3(0, 0.75, 0), 40.0, 0.0, Vector3(0.03, 0, 0.02))
			_set_anim(_hero, "idle")
			_at(0.9, func(): _set_anim(_hero, "shrug"))
		"t_drop":
			# 天上掉下一隻兔子標本和一支路標旗，插在家豪旁邊
			_shot_cam(hp + f * 4.6 + right * 1.4 + Vector3(0, 1.6, 0), hp - right * 0.3 + Vector3(0, 0.75, 0), 40.0)
			_set_anim(_hero, "lookup")
			var d_at := hp + right * 0.85 + f * 0.35
			d_at.y = float(_world.height_at(d_at.x, d_at.z))
			var g_at := hp + right * 0.8 - f * 0.55
			g_at.y = float(_world.height_at(g_at.x, g_at.z))
			_drop(_decoy, d_at, 0.05, 6.0, atan2(-right.x, -right.z) + 0.6)
			_drop(_flag, g_at, 0.45, 3.0, 0.4)
			_at(1.7, func():
				_set_anim(_hero, "idle")
				_hero.look = d_at
				_emote(_hero, "？", Color(1, 1, 1), 0.9, 0.9)
				_play("pop", -12.0))
		# ---------------------------------------------------------- ④ 尋雞啟事
		"p_in":
			# 樹幹上釘著一張懸賞單，被紅漆噴到一半
			_shot_cam(_poster3d + f * 3.6 + Vector3(0, 0.25, 0), _poster3d, 20.0, 0.0, f * -0.1)
			_hero.look = _poster3d
			_at(0.85, func():
				_poster_p = _poster("飼料三包")
				_spray(_poster_p))
		"p_read":
			pass
		"p_out":
			_hide_paper(_poster_p, true)
			_poster_p = null
			_shot_cam(hp + f * 3.0 - right * 0.7 + Vector3(0, 1.1, 0), hp + right * 0.3 + Vector3(0, 0.85, 0), 36.0)
			_hero.look = null
			_at(0.4, func():
				_set_anim(_hero, "cool")
				_emote(_hero, "…", Color(1, 1, 1), 1.0, 0.8))
		# ---------------------------------------------------------- ⑤ 標題卡
		"card":
			_shot_cam(Vector3(-15.0, 14.0, 29.0), Vector3(0, -1.0, -3.0), 46.0, 0.0, Vector3(0.25, -0.05, -0.2))
			_at(0.45, func(): _card_p = _title_card(2, "駁大莖森", "外婆家"))

## 天上掉下來的東西：轉著圈掉下來，咚一聲插在地上
func _drop(n: Node3D, at: Vector3, delay: float, spin: float, yaw: float) -> void:
	n.visible = false
	n.global_position = at + Vector3(0, 9.0, 0)
	n.rotation = Vector3(0, yaw - spin, 0)
	var tw := _tw()
	tw.tween_interval(delay)
	tw.tween_callback(func(): n.visible = true)
	tw.set_parallel(true)
	tw.tween_property(n, "global_position", at, 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_property(n, "rotation:y", yaw, 1.1)
	tw.set_parallel(false)
	tw.tween_callback(func():
		_play("thud", -12.0, 1.3)
		_emote(at + Vector3(0, 0.5, 0), "咚", Color(1, 1, 1), 0.7, 0.6))

# ================================================================== 聲音

func _make_forest_sounds() -> void:
	# 海浪＋鳥叫（循環）
	var b := s_buf(4.0)
	for k in 4:
		s_noise(b, k * 1.0 + 0.1, 1.8, 0.34, 0.04, 140 + k, 1.1, true)
	for c in [[0.3, 2900.0, 3800.0], [0.42, 2900.0, 3700.0], [1.7, 2100.0, 2700.0], [1.84, 2400.0, 2000.0], [2.9, 3300.0, 4100.0], [3.02, 3300.0, 4200.0], [3.14, 3300.0, 4000.0]]:
		s_glide(b, c[0], c[1], c[2], 0.07, 0.07, 0.1)
	_snd["shore"] = s_wav(b, true)
	# 林子裡：風吹樹葉＋鳥叫（循環）
	b = s_buf(4.0)
	for k in 4:
		s_noise(b, k * 1.0, 1.5, 0.16, 0.08, 160 + k, 0.9, true)
	for c in [[0.5, 3100.0, 3900.0], [0.62, 3100.0, 3900.0], [0.74, 3100.0, 4100.0], [2.2, 2200.0, 2900.0], [2.36, 2900.0, 2300.0], [3.4, 3600.0, 4300.0]]:
		s_glide(b, c[0], c[1], c[2], 0.07, 0.08, 0.1)
	_snd["woods"] = s_wav(b, true)
	# 砍樹的「咚」：悶悶的木頭聲
	b = s_buf(0.35)
	s_kick(b, 0.0, 0.5)
	s_noise(b, 0.0, 0.12, 0.5, 0.45, 31, 30.0)
	s_tone(b, 0.0, 190.0, 0.2, 0.25, 0.5, 18.0)
	_snd["chop"] = s_wav(b)
