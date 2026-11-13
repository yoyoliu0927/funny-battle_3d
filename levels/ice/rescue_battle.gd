extends "res://levels/ice/billiards_battle.gd"
## 【救企鵝＋整人清單】
##
## 一眼就懂：籠子裡的企鵝在喊「救我！」。家豪會沿著地上的黃色虛線自己走過去開籠子。
## 工人的衝刺路線一開始就畫在地上（紅色虛線，終點紅叉＝他要在那裡抓家豪）。
## 守衛站著不動；家豪走進紅圈，他就會沿紅色箭頭撲過去。
## 你要在準備階段想好：香蕉皮丟在路線的哪一段，工人就會往那一段的方向滑出去。
##
##   - 香蕉皮：在冰上奔跑的工人踩到會沿著「那一段路線的方向」直線滑出去
##              進冰洞出局；撞到別人會把別人一起撞出去（連環撞）；撞到雪人會停；滑到雪地就停
##   - 準備階段拿著香蕉皮、瞄在紅線上：黃線畫出他會滑到哪（只畫到第一次撞到東西為止）
##   - 已經放下的香蕉皮：淡淡標出它真正的結果
##   - 整人清單（左上角）：做到就打勾，勾幾項就是幾顆星
## 小關的 battle.gd：extends 這個檔案，設定 _make_items()、_enemy_specs()、_checklist()、_how_to()。
## 工人：rusher(名字, 出生點, [衝刺路線點…])；守衛：guard(名字, 位置)。

const UISkin := preload("res://scripts/ui/ui_style.gd")
const BODY_K := 1.1            # 工人放大（畫面上角色要夠大）；Q 版小人含安全帽大約 2.9 公尺高
const BIRD_WALK := 2.3         # 家豪走路的速度
const BIRD_RUN := 4.5          # 擋路的人都解決了：家豪衝向籠子
const RUSH_SPEED := 2.1        # 工人衝刺的速度
const CATCH := 1.1             # 碰到家豪的距離
const LUNGE_R := 2.6           # 守衛撲過來的距離
const CAGE_REACH := 2.7        # 籠子變大了，走到籠門前就算
const ON_ROUTE := 0.75         # 香蕉皮離路線多近算「在路線上」
const LIFT_TIME := 0.9         # 被抓住之後拎起來晃多久才結束
const WIN_SHOW := 2.8          # 過關演出幾秒後才跳結算
const HAT_Y := 2.45            # 雪人頭扣在工人頭上的高度（貼著頭頂）
const PILE_R := 1.9
const PEEL_STEP := 0.55        # 走到離香蕉皮這麼近就踩到（跟 banana_item 的 PEEL_RADIUS 一樣）
const HANG := 1.05            # 家豪被拎著：手到他腳底的距離（抓著帽 T 的帽子；腳離地半公尺以上）            # 滑停在雪堆這麼近的地方，就倒栽進雪堆

var path: Array = []
var path_i := 0
var falls := 0
var caroms := 0
var _done := {}
var _list_layer: CanvasLayer
var _list_label: Label
var _how_label: Label
var _goal_label: Label
var _path_line: MeshInstance3D
var _route_line: MeshInstance3D
var _peel_line: MeshInstance3D
var _bird_tag: Label3D
var _bird_ring: MeshInstance3D
var _cut_cam: Camera3D
var _cut_t := 0.0              # 特寫還剩幾秒（遊戲時間）
var _ended_t := 0.0            # 結束後過了幾秒（遊戲時間）
var _summary_pending := false
var _hint_until := 0
var _caught_by := ""
var _catcher: Fighter
var _ran := false
## 預告完整度：true＝畫出滑到哪、結果是什麼（教學關）；false＝只畫方向箭頭（後面的關卡自己想）
var preview_full := true
var _new_stars: Array = []
var _guard_labels := {}        # 守衛 -> 「撲」字
var _stars := {}               # 暈倒的人 -> 頭上轉圈的星星 [Label3D x3]
var _vb: Array = []            # 要畫的三角形：[顏色, 頂點, 顏色, 頂點…]（沒有頂點就不開 surface）
var _recap_t := 0.0            # 過關前「今日最佳」受害者特寫還剩幾秒
var _told_giveup := false
var _miss_text := ""            # 時機差一點時：晚了／早了幾秒（寫進失敗提示）
## 第 3 關（時機）：紅線上每 1 秒標一個點；瞄準時標出「他踩到的那一刻，別人在哪」
var show_timing := false
var _time_labels: Array = []
var _ghost_label: Label3D
var _reroute_label: Label3D
var _cross_label: Label3D
var _top_cam: Camera3D
var _cross_lead: Array = []
var _victim_in_shot := false
var _phase_mode := ""
var _follow: Fighter             # 滑行特寫要跟著誰
var _follow_off := Vector3.ZERO
var _card: Control               # 結算卡的內容
var _how_tab: Label              # 「怎麼玩」收起來後的小標籤
var _pending_line := ""          # 過關時家豪晚一點才說的台詞
var _prep_t0 := 0.0              # 準備階段開始的時間（開場示範用）
var _demo_labels: Array = []
## 紅色大標題「救出企鵝！」：只有第一關打開（而且只在第一次進來時出現）
var show_goal := false
static var _goal_seen := {}
## 測試／截圖用：不用按 Tab 也切到正上方視角
var force_top := false
var _std_focus := Vector3.ZERO
var _std_offset := Vector3(0, 2, 5)
var _reroute_used := false
var _pop_seen := {}            # 「字 + 誰」 -> 上次跳字的時間（0.5 秒內同一個字不重複跳）

## 每一關拿過的星星（這次開遊戲期間累積；不同解法可以分次拿）
static var best_stars := {}

# ---------------------------------------------------------------- 關卡設定用

## 會沿著路線衝過來的工人
func rusher(name: String, spawn: Vector3, rush: Array) -> Dictionary:
	var d := worker(name, [spawn], {"rush": rush})
	d.has_cone = false
	d.reach = 0.6
	d.model = MODEL_WORKER
	return d

## 站著不動、家豪靠近就沿箭頭撲過去的守衛
func guard(name: String, at: Vector3) -> Dictionary:
	var d := worker(name, [at], {"guard": true})
	d.has_cone = false
	d.reach = 0.6
	d.model = MODEL_GUARD
	return d

## 這關的整人清單：[{"id", "text"}]。可用的 id：
##   rescue 救出企鵝　fall1 有人掉進冰洞　fall2 兩個人掉進冰洞　carom 連環撞
##   guard_carom 用連環撞把守衛撞進冰洞　guard_slip 讓守衛自己撲上香蕉皮
##   one_banana 只用 1 片香蕉皮救出　two_banana 只用 2 片
##   snow_hole 戴著雪人頭掉進冰洞　pile 有人倒栽進雪堆
##   first_try 第一次就成功（這次開遊戲以來的第一局）　clean_fall2 不碰雪人、兩個一起泡進冰洞
func _checklist() -> Array:
	return [{"id": "rescue", "text": "救出企鵝"}]

## 左上角「怎麼玩」的說明（每關自己寫）
func _how_to() -> String:
	return ""

## 救企鵝模式不用會自動翻頁的教學框（改用左上角的「怎麼玩」）
func _tutorial_texts() -> Array:
	return []

# ---------------------------------------------------------------- 建立、重置

func _level_setup() -> void:
	super()
	show_tutorial = false
	avoid_thin = true
	path = world.bird_path.duplicate()
	var specs := _enemy_specs()
	for i in enemies.size():
		var s: Dictionary = specs[i]
		enemies[i].set_meta("rush", s.get("rush", []))
		enemies[i].set_meta("guard", s.get("guard", false))
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.disable_fog = true           # 路線是謎題的重點：不吃光、不吃霧，早晨、夕陽、黃昏三關看起來都一樣
	_path_line = _mesh_node(m)
	_route_line = _mesh_node(m)
	_peel_line = _mesh_node(m)
	# 家豪：放大一點、加大紅雞冠和黃嘴、頭上掛名字、腳下一圈光，一眼認得出主角（也跟黑白的企鵝分開）
	bird.node.scale = Vector3.ONE * 1.6
	fall_toast = false
	for i in enemies.size():
		enemies[i].node.scale = enemies[i].node.scale * BODY_K
		_setup_mini(enemies[i], i)
	var head := bird.node.find_child("Head", true, false) as Node3D
	if head:
		var comb := MeshInstance3D.new()
		comb.mesh = prop_mesh("rescue/rooster_comb")
		comb.position = Vector3(0, 0.1, 0.01)
		comb.scale = Vector3.ONE * 1.25
		head.add_child(comb)
		var beak := MeshInstance3D.new()
		beak.mesh = prop_mesh("rescue/rooster_beak")
		beak.position = Vector3(0, 0.0, 0.1)
		head.add_child(beak)
	_bird_tag = Label3D.new()
	_bird_tag.text = "家豪"
	_bird_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_bird_tag.no_depth_test = true
	_bird_tag.font_size = 44
	_bird_tag.pixel_size = 0.0006
	_bird_tag.fixed_size = true
	_bird_tag.outline_size = 16
	_bird_tag.outline_modulate = Color(0, 0, 0, 0.85)
	world.add_child(_bird_tag)
	_bird_ring = MeshInstance3D.new()
	_bird_ring.mesh = prop_mesh("rescue/aim_ring")
	var rmat := StandardMaterial3D.new()
	rmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rmat.albedo_color = Color(0.35, 0.95, 1.0)
	rmat.disable_fog = true
	_bird_ring.material_override = rmat
	_bird_ring.scale = Vector3(1.15, 1.0, 1.15)
	_bird_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(_bird_ring)
	# 道具格的圖示：拿香蕉皮模型算出來的圖
	for it in items:
		if it.id == "banana" and ResourceLoader.exists(PROP_DIR + "rescue/banana_peel_icon.png"):
			it.icon = load(PROP_DIR + "rescue/banana_peel_icon.png")
	_cut_cam = Camera3D.new()
	_cut_cam.fov = 60.0
	world.add_child(_cut_cam)
	for f in enemies:
		if f.get_meta("guard", false):
			var gl := Label3D.new()
			gl.text = "撲"
			gl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			gl.no_depth_test = true
			gl.font_size = 64
			gl.pixel_size = 0.0006
			gl.fixed_size = true
			gl.outline_size = 16
			gl.modulate = Color(1.0, 0.6, 0.15)
			world.add_child(gl)
			_guard_labels[f] = gl
	if _players.has("bgm"):
		(_players["bgm"] as AudioStreamPlayer).volume_db = -16.0
		_players["bgm"].play()
	# 左上角：整人清單＋怎麼玩
	_list_layer = CanvasLayer.new()
	_list_layer.layer = 5
	add_child(_list_layer)
	var box := VBoxContainer.new()
	box.position = Vector2(20, 60)
	box.add_theme_constant_override("separation", 10)
	_list_layer.add_child(box)
	_list_label = _panel_label(box, 22)
	_how_label = _panel_label(box, 19)
	_how_tab = Label.new()
	_how_tab.text = "H  說明"
	_how_tab.label_settings = UISkin.ls(18, UISkin.INK)
	UISkin.pill(_how_tab, UISkin.STICKY, UISkin.STICKY_EDGE, UISkin.INK)
	_how_tab.visible = false
	_how_tab.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN   # 小標籤，不要跟清單一樣寬
	box.add_child(_how_tab)
	_goal_label = Label.new()
	_goal_label.text = "救出企鵝！"
	_goal_label.add_theme_font_size_override("font_size", 50)
	UISkin.ribbon(_goal_label)
	_goal_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_goal_label.offset_top = 26   # 貼著畫面上緣：鏡頭收窄後籠子在畫面上方，標題再低就會蓋到「救我！」
	_goal_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_goal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_list_layer.add_child(_goal_label)
	var hint := get_node_or_null("../HUD/Hint") as Label
	if hint:
		hint.text = "滑鼠 看　WASD／空白／Shift 移動　左鍵 丟道具　Enter 開始　R 重來　F 快轉"
		UISkin.pill(hint, Color(0.1, 0.13, 0.2, 0.75), Color(1, 1, 1, 0.35), Color(1, 1, 1))
	_skin_hud()
	_hint_until = Time.get_ticks_msec() + 3000

func _mesh_node(m: Material) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.mesh = ImmediateMesh.new()
	n.material_override = m
	n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(n)
	return n

func _panel_label(parent: Control, size: int) -> Label:
	# 美術：整人清單是筆記紙、怎麼玩是便利貼（參考 Untitled Goose Game 的待辦清單）
	var panel := PanelContainer.new()
	parent.add_child(panel)
	if size >= 22:
		UISkin.paper(panel)
	else:
		UISkin.sticky(panel)
	var l := Label.new()
	UISkin.use_font(l, size + 2, UISkin.INK)
	l.add_theme_constant_override("line_spacing", 6)
	panel.add_child(l)
	return l

func _level_reset() -> void:
	super()
	if world.has_method("reset_cage"):
		world.reset_cage()
	path_i = 0
	falls = 0
	caroms = 0
	_done.clear()
	_summary_pending = false
	_cut_t = 0.0
	_ended_t = 0.0
	_caught_by = ""
	_catcher = null
	_ran = false
	_new_stars.clear()
	_chip_list.clear()      # 冰屑放在 fx_root 底下，已經被一起刪掉了
	_boxes_ready = false
	_pop_seen.clear()
	_recap_t = 0.0
	_told_giveup = false
	_pending_line = ""
	_follow = null
	_phase_mode = ""
	_prep_t0 = _clock
	_demo_caption_text = ""
	if world.has_method("set_clutter"):
		world.set_clutter(true)
	_miss_text = ""
	bird.data.erase("held")
	bird.data.erase("sighed")
	# 雪人扶正（被撞倒過的）
	for sn in world.get("snowman_nodes"):
		(sn.node as Node3D).rotation = Vector3(0, (sn.pos as Vector3).x * 0.7, 0)
		for nm in ["Scarf", "ScarfTail"]:
			var sc := (sn.node as Node3D).find_child(nm, true, false) as Node3D
			if sc:
				sc.visible = true
		(sn.node as Node3D).position = sn.pos
		(sn.node as Node3D).visible = true
		for ob in world.obstacles:
			if (ob[0] as Vector2).distance_to(Vector2(sn.pos.x, sn.pos.z)) < 0.05:
				ob[1] = 0.6
	for f in enemies:
		f.data.erase("pile")
		f.data.erase("chase_to")
		f.data.erase("pair")
		f.data.erase("hit_any")
		_set_frost(f, false)
		f.data.erase("hit_once")
		f.data.erase("missed")
		f.data.erase("snow_hat")
	if _list_layer:
		_list_layer.visible = true
	if camera:
		camera.make_current()
	for f in enemies:
		f.data.rush = f.get_meta("rush", [])
		f.data.guard = f.get_meta("guard", false)
		f.data.ri = 0
	if _goal_label:
		_goal_label.visible = false
	_refresh_list()
	if _how_label:
		_how_label.text = _how_to()
		(_how_label.get_parent() as Control).visible = true
	if _hotbar:
		var hb := _hotbar.bar_size()
		_hotbar.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
		_hotbar.offset_left = 28
		_hotbar.offset_right = 28 + hb.x
		_hotbar.offset_top = -hb.y - 30
		_hotbar.offset_bottom = -30
	# 字卡放在畫面下三分之一，不要擋住事件
	if _toast_label:
		_toast_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
		_toast_label.offset_top = -200
		_toast_label.offset_bottom = -160
		_toast_label.grow_horizontal = Control.GROW_DIRECTION_BOTH

func _level_start() -> void:
	_goal_label.visible = false
	_goal_seen[_stage_key()] = true
	for f in enemies:
		f.aggro = true
		f.set_state("rush" if not f.data.get("guard", false) else "guard")
		anim(f, "Run" if not f.data.get("guard", false) else "Idle")
	for f in enemies:
		if not f.data.get("guard", false):
			pop_label("！", f.pos + Vector3(0, 3.2, 0), Color(1.0, 0.3, 0.25), 800, f)
	(_how_label.get_parent() as Control).visible = false   # 開打後收起說明

func _prepare_hint() -> String:
	return "準備中　｜　Enter 開始"

func _update_phase_label() -> void:
	# 準備：右下角一顆綠色「開始」按鈕；開打：右上角小小的「R 重來」；結束：不放字（結算卡有按鈕）
	var mode := "none"
	if phase == Phase.PREPARE:
		mode = "start"
	elif phase == Phase.RUNNING:
		mode = "retry"
	if mode == _phase_mode:
		return
	_phase_mode = mode
	match mode:
		"start":
			_phase_label.text = "開始 ▶　Enter"
			UISkin.pill(_phase_label, Color("58b85a"), Color("2f7a33"), Color(1, 1, 1))
			_phase_label.label_settings.font_size = 30
			_dock(_phase_label, Control.PRESET_BOTTOM_RIGHT, Vector2(-36, -40))
		"retry":
			_phase_label.text = "R 重來"
			UISkin.pill(_phase_label)
			_phase_label.label_settings.font_size = 20
			_dock(_phase_label, Control.PRESET_TOP_RIGHT, Vector2(-24, 20))
		_:
			_phase_label.text = ""

func _dock(l: Control, preset: int, off: Vector2) -> void:
	l.set_anchors_preset(preset)
	l.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	l.grow_vertical = Control.GROW_DIRECTION_BEGIN if off.y < 0.0 else Control.GROW_DIRECTION_END
	l.offset_left = off.x
	l.offset_right = off.x
	l.offset_top = off.y
	l.offset_bottom = off.y
	l.reset_size()

# ---------------------------------------------------------------- 整人清單

func _stage_key() -> String:
	var root := get_parent()
	return root.scene_file_path if root else "?"

func _best() -> Dictionary:
	var k := _stage_key()
	if not best_stars.has(k):
		best_stars[k] = {}
	return best_stars[k]

func mark(id: String) -> void:
	if _done.has(id) or not _checklist().any(func(c): return c.id == id):
		return
	_done[id] = true
	if not _best().has(id):
		_new_stars.append(id)
	var text: String = _checklist().filter(func(c): return c.id == id)[0].text
	toast("☑ %s" % text, 1.4)
	sfx("win")
	log_event("整人清單：%s" % text)
	_refresh_list()

func stars() -> int:
	return _done.size()

## 清單：這一局做到的打勾；以前拿過的顯示「★（之前）」
func _refresh_list() -> void:
	if _list_label == null:
		return
	var lines: PackedStringArray = []      # 不放標題：筆記紙本身就看得出是清單
	var best := _best()
	for c in _checklist():
		var tag := "☐ "
		if _done.has(c.id):
			tag = "☑ "
		elif best.has(c.id):
			tag = "★ "
		lines.append(tag + String(c.text) + ("（之前拿過）" if best.has(c.id) and not _done.has(c.id) else ""))
	_list_label.text = "\n".join(lines)

func fall_in(f: Fighter) -> void:
	# 同一個洞已經有人：並排露頭（左右各讓開一點），兩顆頭一起入鏡
	for o in enemies:
		if o != f and o.data.get("sunk", false) and flat_dist(o.pos, f.pos) < 0.9:
			var side := _cam_side()
			var mid: Vector3 = o.pos
			f.pos = mid + side * PAIR_HALF
			o.pos = mid - side * PAIR_HALF
			f.data.pair = true
			o.data.pair = true
	super(f)
	# 臉朝鏡頭，凍得發抖、吐泡泡
	var cp: Vector3 = camera.global_position if camera else f.pos + Vector3(0, 0, 10)
	f.yaw = atan2(cp.x - f.pos.x, cp.z - f.pos.z)
	f.data.sunk_yaw = f.yaw
	f.data.blub = false
	_set_frost(f, true)
	var first_in := true
	for o in enemies:
		if o != f and o.data.get("sunk", false) and flat_dist(o.pos, f.pos) < 2.4 and float(o.data.get("sink_t", 9.0)) < 0.8:
			first_in = false       # 兩個人一起掉進同一個洞：只跳一個「撲通！」
	if first_in:
		pop_label("撲通！", f.pos + Vector3(0, 2.4, 0), Color(0.62, 0.9, 1.0), 900, f)
	if f.data.get("snow_hat") != null:
		mark("snow_hole")
	falls += 1
	mark("fall1")
	if falls >= 2:
		mark("fall2")
	if f.data.get("guard", false) and f.data.get("was_hit", false):
		mark("guard_carom")
	if _cut_cam and _cut_cam.current:
		_cut_t = maxf(_cut_t, 1.7 if f.data.get("snow_hat") != null else 0.9)
	elif phase == Phase.RUNNING and camera:
		# 沒有特寫的時候掉洞：補一個 1 秒近拍，對準掉下去的人
		var away2: Vector3 = camera.global_position - f.pos
		away2.y = 0.0
		away2 = away2.normalized() if away2.length() > 0.1 else Vector3.BACK
		_cut_smart(f.pos + Vector3(0, 0.8, 0), away2 * 4.8 + Vector3(0, 2.2, 0), 1.0)

func _on_carom(_a: Fighter, b: Fighter) -> void:
	caroms += 1
	b.data.was_hit = true
	mark("carom")

# ---------------------------------------------------------------- 輸贏

func _check_end() -> String:
	if bird.alive() and bird_near(world.cage, CAGE_REACH):
		mark("rescue")
		var bananas := casts.filter(func(c): return c.id == "banana").size()
		if bananas <= 1:
			mark("one_banana")
		if bananas <= 2:
			mark("two_banana")
		if attempts.is_empty():
			mark("first_try")
		if falls >= 2 and not enemies.any(func(e): return e.data.get("snow_hat") != null):
			mark("clean_fall2")
		return "win"
	if not bird.alive():
		return "lose"
	if time >= time_limit:
		log_event("天黑了")
		return "lose"
	return ""

func _end(result: String) -> void:
	if result == "win":
		for id in _done:
			_best()[id] = true
		win_count[_stage_key()] = int(win_count.get(_stage_key(), 0)) + 1
	super(result)
	_ended_t = 0.0
	toast("", 0.0)
	# 跳字清掉，但對白泡泡（例如被抓時的「……完了」）留著
	for i in range(_labels.size() - 1, -1, -1):
		var l: Dictionary = _labels[i]
		if l.get("fixed", false):
			continue
		if is_instance_valid(l.node):
			l.node.queue_free()
		_labels.remove_at(i)
	if result == "win":
		# 特寫一開始就把小道具、招牌字收起來，水花也清掉（不然會蓋住受害者）
		if world.has_method("set_clutter"):
			world.set_clutter(false)
		for c in fx_root.get_children():
			if c is MeshInstance3D and (c as MeshInstance3D).mesh is SphereMesh:
				(c as Node3D).visible = false
		# 先演：籠門打開、企鵝衝出來圍著家豪，家豪轉向鏡頭；WIN_SHOW 秒後才從右邊跳結算
		_summary_panel.visible = false
		_summary_pending = true
		_phase_label.text = ""
		var v := _best_victim()
		if not v.is_empty():
			# 先回顧今天最好笑的受害者（1.4 秒），再演企鵝出籠
			_recap_t = RECAP
			var tgt: Vector3 = v.target
			var away: Vector3 = (camera.global_position - tgt) if camera else Vector3(0, 0, 1)
			away.y = 0.0
			away = away.normalized() if away.length() > 0.1 else Vector3.BACK
			away = away.rotated(Vector3.UP, 0.32)    # 偏一點角度：頭後面不要剛好是一棵樹
			if v.get("low", false):
				# 泡在洞裡的人：鏡頭貼著水面從正前方拍，帽簷才不會擋住臉
				_cut_smart(tgt + Vector3(0, -0.5, 0), away * 4.6 + Vector3(0, 1.3, 0), 99.0)
			else:
				_cut_smart(tgt + Vector3(0, -0.4, 0), away * 5.0 + Vector3(0, 1.5, 0), 99.0)
			toast(String(v.text), RECAP)
		else:
			_start_win_show()

const RECAP := 1.3

## 今天最好笑的那一幕：雪人頭泡在洞裡 > 雪堆裡的腿 > 同一個洞兩個人 > 冰棒工人 > 坐著喘的人
func _best_victim() -> Dictionary:
	var best := {}
	var rank := 0
	for f in enemies:
		var r := 0
		var text := ""
		var tgt: Vector3 = head_pos(f)
		if f.data.get("sunk", false) and f.data.get("snow_hat") != null:
			r = 5
			text = "今日最佳：雪人頭先生"
		elif f.data.get("pile") != null:
			r = 4
			text = "今日最佳：雪堆裡的兩條腿"
			tgt = (f.data.pile as Vector3) + Vector3(0, 1.1, 0)
		elif f.data.get("sunk", false) and f.data.get("pair", false):
			r = 3
			text = "今日最佳：一個洞泡兩個"
		elif f.data.get("sunk", false):
			r = 2
			text = "今日最佳：冰棒%s" % f.name
		elif f.alive() and f.state == "giveup":
			r = 1
			text = "今日最佳：追不上的%s" % f.name
		if r > rank:
			rank = r
			best = {"f": f, "text": text, "target": tgt, "low": f.data.get("sunk", false)}
	return best

## 企鵝出籠：側面鏡頭，企鵝排在家豪兩旁，家豪說一句（依這局做到的事換台詞）
func _start_win_show() -> void:
	_boxes_ready = false      # 擺設有的已經收起來了：重新量一次
	_ended_t = 0.0
	toast("", 0.0)
	var to_cage: Vector3 = world.cage - bird.pos
	to_cage.y = 0.0
	to_cage = to_cage.normalized() if to_cage.length() > 0.1 else Vector3.FORWARD
	# 家豪站在籠門外 1.5 公尺左右（不要看起來像自己站進籠子裡）
	bird.pos = ground(world.cage - to_cage * 3.6)
	var side := to_cage.cross(Vector3.UP)
	# 鏡頭在家豪正前方偏一點：打開的籠門在他身後入鏡，企鵝跑出來站到他左右兩邊
	# 結算會從右邊出來：鏡頭往右偏，家豪和企鵝站在畫面左半邊
	var focus: Vector3 = bird.pos + to_cage * 0.9 + side * 1.6 + Vector3(0, 0.8, 0)
	var offset: Vector3 = -to_cage * 5.4 + side * 1.0 + Vector3(0, 2.0, 0)
	# 家豪前面有雪人、受害者的帽子擋著：鏡頭拉高或往旁邊挪，直到看得到他
	var std_ok := false
	for ang in [0.0, 0.45, -0.45, 0.9, -0.9, 1.35, -1.35]:
		for back in [5.4, 4.3, 6.8]:
			for h in [2.0, 3.2, 4.6]:
				if std_ok:
					break
				var dirc: Vector3 = (-to_cage).rotated(Vector3.UP, float(ang))
				var rgt: Vector3 = (-dirc).cross(Vector3.UP)
				var try_focus: Vector3 = bird.pos - dirc * 0.9 + rgt * 1.6 + Vector3(0, 0.8, 0)
				var try_off: Vector3 = dirc * float(back) + rgt * 1.0 + Vector3(0, float(h), 0)
				if _sees_bird(try_focus + try_off) and _cam_clear(try_focus + try_off, try_focus, 6.0):
					focus = try_focus
					offset = try_off
					std_ok = true
	# 結算出來時切回這個正面構圖（家豪、企鵝在左半邊，結算在右邊）
	_std_focus = focus
	_std_offset = offset
	var std_cam: Vector3 = focus + offset
	# 有受害者而且不太遠：鏡頭擺在受害者後面，讓他在右前景、家豪和企鵝在中景左邊（家豪的吐槽才有對象）
	var v := _best_victim()
	if not v.is_empty():
		var vp: Vector3 = v.target
		var bv: Vector3 = vp - bird.pos
		bv.y = 0.0
		var dist := bv.length()
		_victim_in_shot = dist > 2.5 and dist < 10.0
		var dirv := bv / maxf(dist, 0.01)
		var left := Vector3.UP.cross(dirv)          # 從受害者看向家豪時的左手邊
		var cam := Vector3.ZERO
		if _victim_in_shot:
			# 鏡頭在受害者後上方偏一邊：受害者在前景一角、家豪和企鵝在中景。試幾個位置，挑看得到家豪的
			_victim_in_shot = false
			for back in [5.6, 7.4]:
				for lat in [3.0, -3.0, 4.6, -4.6, 0.8, -0.8]:
					for h in [3.2, 4.6, 6.0]:
						if _victim_in_shot:
							break
						cam = ground(vp) + dirv * float(back) + left * float(lat) + Vector3(0, float(h), 0)
						_victim_in_shot = _sees_bird(cam) and _cam_clear(cam, bird.pos, 3.4)
		if _victim_in_shot:
			focus = bird.pos.lerp(ground(vp), 0.42) + Vector3(0, 0.9, 0)
			offset = cam - focus
			# 洞裡的受害者轉向鏡頭（看得到臉），家豪在他們後面吐槽
			var near: Array = enemies.filter(func(e): return e.data.get("sunk", false) and flat_dist(e.pos, vp) < 3.0)
			if near.size() >= 2:
				# 兩個人並排（以這個鏡頭的左右排開），兩張臉都入鏡
				var ctr: Vector3 = (near[0].pos + near[1].pos) * 0.5
				var vd: Vector3 = cam - ctr
				vd.y = 0.0
				var sideways := vd.normalized().cross(Vector3.UP)
				near[0].pos = ctr - sideways * PAIR_HALF
				near[1].pos = ctr + sideways * PAIR_HALF
			for e in near:
				e.data.sunk_yaw = atan2(cam.x - e.pos.x, cam.z - e.pos.z)
				e.yaw = e.data.sunk_yaw   # 戰局已經停了，直接轉（不等下一步）
	if world.has_method("set_clutter"):
		world.set_clutter(false)       # 過關演出時收起釣竿、水桶、招牌字（不搶畫面）
	for sn in world.get("snowman_nodes"):
		if absf((sn.node as Node3D).rotation.z) > 0.5:
			(sn.node as Node3D).visible = false   # 倒下的雪人身體（正面看像棒棒糖）收起來
	if world.has_method("open_cage"):
		world.open_cage(bird.pos, std_cam)
	bird.yaw = atan2(offset.x, offset.z)
	bird.air = 0.0
	_cut_to(focus, offset, 99.0)
	var line := "……可以回家了嗎"
	if _done.has("snow_hole"):
		line = "……他頭上那個是什麼"
	elif _done.has("pile") or enemies.any(func(f): return f.data.get("pile") != null):
		line = "……那是腿嗎" if _victim_in_shot else "……我什麼都沒看到"
	elif _done.has("guard_carom") or _done.has("carom") or _done.has("clean_fall2"):
		line = "……一次兩個"
	# 企鵝先說「謝謝家豪！」，家豪 0.8 秒後才吐槽（一來一往）
	_pending_line = "唉" + line

func _level_step_ended(dt: float) -> void:
	super(dt)
	_tick_chips(dt)
	if _recap_t > 0.0:
		_recap_t -= dt
		if _recap_t <= 0.0:
			_start_win_show()
		return
	_ended_t += dt
	if world.has_method("tick_cage"):
		world.tick_cage(dt)
	if _pending_line != "" and _ended_t >= 1.9:
		bubble(_pending_line, bird, 1.7, int((WIN_SHOW + 3.0) * 1000))
		_pending_line = ""
	if _summary_pending and _ended_t >= WIN_SHOW:
		_summary_pending = false
		# 結算卡放右上角（那裡是樹林，不會擋到角色和洞裡的受害者）
		_summary_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		_summary_panel.offset_right = -36
		_summary_panel.offset_top = 36
		_summary_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		_summary_panel.grow_vertical = Control.GROW_DIRECTION_END
		_summary_panel.visible = true
		_skin_summary()
		_update_phase_label()
		_cut_to(_std_focus, _std_offset, 99.0)
		bird.yaw = atan2(_std_offset.x, _std_offset.z)
		var std_cam2: Vector3 = _std_focus + _std_offset
		for e in enemies:
			if e.data.get("sunk", false):
				e.data.sunk_yaw = atan2(std_cam2.x - e.pos.x, std_cam2.z - e.pos.z)
				e.yaw = e.data.sunk_yaw

func _win_line() -> String:
	var best := _best()
	var list := _checklist()
	var n := list.filter(func(c): return best.has(c.id)).size()
	var stars_s := "★".repeat(n) + "☆".repeat(list.size() - n)
	var lines: PackedStringArray = ["企鵝救出來了！　%s（%d/%d）" % [stars_s, n, list.size()]]
	for c in list:
		var tag := "☑ " if best.has(c.id) else "☐ "
		lines.append(tag + String(c.text) + ("　新！" if _new_stars.has(c.id) else ""))
		if not best.has(c.id) and String(c.get("hint", "")) != "":
			lines.append("　　（%s）" % c.hint)
	lines.append("按 Enter 下一關")
	return "\n".join(lines)

func _lose_line(_left: int) -> String:
	if time >= time_limit:
		return "天黑了，企鵝還關在籠子裡…"
	return "家豪被%s抓住了…" % (_caught_by if _caught_by != "" else "工人")

func _defeat_title() -> String:
	return "今晚加菜：烤家豪……"

func _defeat_tip() -> String:
	return "把香蕉皮丟在紅線上"

## 輸了的晚餐畫面：不要寫「還剩幾個敵人」，改成誰抓到的
func _show_defeat() -> void:
	super()
	_list_layer.visible = false
	# 共用的深色字條收起來，換成跟結算同一種筆記紙卡片：標題、一行提示、按鈕
	var band := _defeat_label.get_parent().get_parent() as Control
	if band:
		band.visible = false
	if _defeat_card and is_instance_valid(_defeat_card):
		_defeat_card.queue_free()
	_recast_dinner()
	var tip := _defeat_tip()
	if _miss_text != "":
		# 時機差一點：直接說香蕉皮該往哪邊挪
		var late := _miss_text.contains("晚")
		var who := _miss_text.substr(0, _miss_text.find("晚") if late else _miss_text.find("早"))
		tip = ("香蕉皮往%s那邊挪一點" % who) if late else ("香蕉皮離%s遠一點" % who)
	var panel := PanelContainer.new()
	UISkin.paper(panel, -0.01)
	var s := UISkin._box(UISkin.PAPER, UISkin.PAPER_EDGE, 6, 3)
	s.content_margin_left = 54
	s.content_margin_right = 42
	s.content_margin_top = 26
	s.content_margin_bottom = 24
	panel.add_theme_stylebox_override("panel", s)
	_defeat_layer.add_child(panel)
	_defeat_card = panel
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	var title := Label.new()
	title.text = "天黑了，企鵝還在籠子裡……" if time >= time_limit else _defeat_title()
	title.label_settings = UISkin.ls(34, UISkin.INK)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var tl := Label.new()
	tl.text = tip
	tl.label_settings = UISkin.ls(22, Color(UISkin.INK, 0.72))
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(tl)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 4)
	v.add_child(gap)
	var btns := HBoxContainer.new()
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	btns.add_theme_constant_override("separation", 10)
	v.add_child(btns)
	var go := Label.new()
	go.text = "重來 ▶"
	go.label_settings = UISkin.ls(26, Color(1, 1, 1))
	UISkin.pill(go, Color("58b85a"), Color("2f7a33"), Color(1, 1, 1))
	btns.add_child(go)
	btns.add_child(_keycap("R"))
	_key_hint(btns, "M", "地圖")
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.offset_bottom = -46

# ---------------------------------------------------------------- 過關後按 Enter 到下一關

func _unhandled_input(event: InputEvent) -> void:
	if phase == Phase.ENDED and outcome == "win" and event.is_action_pressed("battle_start"):
		_go_next()
		get_viewport().set_input_as_handled()
		return
	super(event)

func _go_next() -> void:
	var chapter := load(get_script().resource_path.get_base_dir().get_base_dir() + "/chapter.gd") as Script
	if chapter == null:
		return
	var stages: Array = chapter.get_script_constant_map().get("STAGES", [])
	var base := chapter.resource_path.get_base_dir()
	var here := _stage_key()
	for i in stages.size():
		if base.path_join(String(stages[i].scene)) == here and i + 1 < stages.size():
			Engine.set_meta("stage_id", "%s/%d" % [base.get_file(), i + 2])
			Engine.time_scale = 1.0
			get_tree().change_scene_to_file(base.path_join(String(stages[i + 1].scene)))
			return
	get_tree().change_scene_to_file(LEVEL_SELECT_SCENE)

# ---------------------------------------------------------------- 家豪：沿路線走、聞到飼料先去吃

func _tick_bird(dt: float) -> void:
	var b := bird
	b.t += dt
	match b.state:
		"dead", "cheer":
			if b.data.get("held", false):
				_hold_bird(b)
			return
		"lifted":
			# 被工人拎在胸前、臉朝鏡頭：腳懸空亂踢（一直拎著到輸了的畫面，不會趴回地上）
			_hold_bird(b)
			if b.t >= LIFT_TIME:
				b.hp = 0.0
				b.set_state("dead")
				b.data.held = true
			return
		"fly":
			var k := clampf(b.t / b.fly_dur, 0.0, 1.0)
			b.pos = ground(b.fly_from.lerp(b.fly_to, k))
			b.air = sin(k * PI) * b.fly_peak
			b.yaw = atan2(b.fly_to.x - b.fly_from.x, b.fly_to.z - b.fly_from.z)
			if k >= 1.0:
				b.air = 0.0
				b.set_state(b.after_fly)
		"slip":
			if b.t >= 2.0:
				b.set_state("charge")
		"feed":
			if b.feed_target < 0 or b.feed_target >= feeds.size():
				b.set_state("charge")
			else:
				var fp: Vector3 = feeds[b.feed_target].pos
				_bird_walk(fp, BIRD_WALK, dt, "feed")
				if flat_dist(b.pos, fp) < 0.35:
					b.set_state("eat")
		"eat":
			if b.t >= FEED_EAT_TIME:
				var fi := _nearest_feed(b.pos, 0.8)
				if fi >= 0:
					(feeds[fi].node as Node3D).queue_free()
					feeds.remove_at(fi)
					log_event("家豪吃掉一把飼料")
				b.set_state("linger")
		"linger":
			if b.t >= 1.0:
				b.set_state("charge")
		_:
			var fi := _nearest_feed(b.pos, FEED_SENSE)
			if fi >= 0:
				b.feed_target = fi
				b.set_state("feed")
				log_event("家豪看到飼料，先去吃")
				return
			# 擋路的人都解決了（掉進洞或追不上）：家豪衝向籠子（不用乾等）
			var spd := BIRD_WALK
			if not enemies.any(func(f): return f.alive() and f.state != "giveup"):
				spd = BIRD_RUN
				if not _ran:
					_ran = true
					pass
			if path_i < path.size():
				var tgt: Vector3 = ground(path[path_i])
				if flat_dist(b.pos, tgt) < 0.3:
					path_i += 1
				else:
					_bird_walk(tgt, spd, dt, "charge")
			else:
				_bird_walk(world.cage, spd, dt, "charge")

# ---------------------------------------------------------------- 工人：照畫好的路線衝；守衛沿箭頭撲

func _tick_enemy(f: Fighter, dt: float) -> void:
	# 已經在滑的人不會再踩到香蕉皮（不然會被第二片從半路彈回來，預告就不準了）
	f.can_slip = f.state not in ["kslide", "stunned"]
	if bird.state == "lifted" or bird.data.get("held", false):
		return
	if f.data.get("pile") != null:
		return
	if f.state == "slip" and f.alive():
		# 雪地上踩到香蕉皮：只跌一下就爬起來繼續追（冰上才會滑出去）
		f.t += dt
		if f.t >= 1.2:
			f.set_state("chase")
		return
	if f.data.get("sunk", false) or not f.alive() or f.state in ["kslide", "stunned", "getup"]:
		super(f, dt)
		return
	if phase != Phase.RUNNING:
		return
	f.t += dt
	if world.in_water(f.pos.x, f.pos.z):
		fall_in(f)
		return
	match f.state:
		"rush":
			var rush: Array = f.data.rush
			var ri: int = f.data.ri
			if ri >= rush.size():
				f.set_state("chase")
				return
			var tgt: Vector3 = ground(rush[ri])
			if flat_dist(f.pos, tgt) < 0.25:
				f.data.ri = ri + 1
			else:
				_walk(f, tgt, RUSH_SPEED, dt)
				anim(f, "Run")
		"guard":
			_face(f, bird.pos)
			anim(f, "Idle")
			if bird.alive() and flat_dist(f.pos, bird.pos) < LUNGE_R:
				log_event("%s撲過來了" % f.name)
				f.data.lunge_to = lunge_point(f)
				f.set_state("lunge")
		"lunge":
			var lt: Vector3 = f.data.get("lunge_to", bird.pos)
			if flat_dist(f.pos, lt) < 0.3:
				f.set_state("chase")
			else:
				_walk(f, lt, RUSH_SPEED * 1.2, dt)
				anim(f, "Run")
		"giveup":
			# 追不上了：坐在原地喘氣
			anim(f, "Idle")
		_:
			# chase（或被撞停下來之後）：跑到家豪前面去攔；追不上就放棄
			if f.state != "chase":
				f.set_state("chase")
				f.data.erase("chase_to")
			# 爬起來就認定一個攔截點直直跑過去（跟準備時預告的新紅線一樣），到了再重新看
			var ip = f.data.get("chase_to")
			if ip == null or flat_dist(f.pos, ip) < 0.3:
				ip = intercept_point(f)
				f.data.chase_to = ip
				if ip != null:
					log_event("%s改追攔截點 (%.2f, %.2f)，從 (%.2f, %.2f)" % [f.name, ip.x, ip.z, f.pos.x, f.pos.z])
			if ip == null:
				f.set_state("giveup")
				log_event("%s追不上了" % f.name)
				pop_label("追不上了…", f.pos + Vector3(0, 3.0, 0), Color(0.85, 0.85, 0.85), 1500, f)
				if not _told_giveup:
					_told_giveup = true
					toast("被甩到後面就追不上了", 1.8)
				return
			_walk(f, ip, RUSH_SPEED, dt)
			anim(f, "Run")
	if world.in_water(f.pos.x, f.pos.z):
		fall_in(f)

func _level_step(dt: float) -> void:
	super(dt)
	_tick_chips(dt)
	if _cut_t > 0.0:
		_cut_t -= dt
		if _cut_t <= 0.0:
			camera.make_current()
	if not bird.alive() or bird.air > 0.5 or bird.state == "lifted":
		return
	for f in enemies:
		if f.alive() and f.state in ["rush", "chase", "guard", "lunge"] and flat_dist(f.pos, bird.pos) < CATCH:
			_caught_by = f.name
			_catcher = f
			bird.set_state("lifted")
			_face(f, bird.pos)
			# 旁邊有雪人或樹：轉身背對它，家豪拎在另一邊，不會嵌進去
			for ob in world.obstacles:
				var c2: Vector2 = ob[0]
				var away := Vector2(f.pos.x - c2.x, f.pos.z - c2.y)
				if float(ob[1]) > 0.0 and away.length() < float(ob[1]) + 2.0 and away.length() > 0.01:
					f.yaw = atan2(away.x, away.y)
					break
			anim(f, "Idle")
			log_event("%s抓住了家豪" % f.name)
			var fw := Vector3(sin(f.yaw), 0, cos(f.yaw))
			var sd := fw.cross(Vector3.UP)          # 工人的右手邊：家豪拎在這一邊（畫面上是左邊）
			var others := 0
			for o in enemies:
				if o != f and o.alive() and flat_dist(o.pos, f.pos) < 3.4:
					# 別人往畫面的另一邊站開（至少 2.5 公尺），不要跟抓到家豪的人疊成一團
					others += 1
					o.pos = ground(f.pos - sd * (2.5 + 1.9 * (others - 1)) - fw * 0.5)
					o.yaw = f.yaw + 0.35
			for li in range(_labels.size() - 1, -1, -1):   # 只留「……完了」，其他跳字清掉
				if not _labels[li].get("fixed", false):
					if is_instance_valid(_labels[li].node):
						_labels[li].node.queue_free()
					_labels.remove_at(li)
			# 泡泡放在家豪外側上方：不蓋住工人的臉
			bubble("……完了", bird, 2.15, 4000, sd * 0.7)
			# 鏡頭在工人正前方、偏家豪那一邊：壞笑的工人和被拎著的家豪都完整入鏡
			_cut_smart(f.pos + sd * (1.0 - 1.0 * others) + Vector3(0, 1.75, 0), fw * (7.0 + 1.4 * others) + sd * 0.8 + Vector3(0, 1.2, 0), LIFT_TIME + 3.0, false, [0.0, 0.3, -0.3, 0.6, -0.6])
			return

## 守衛撲過去的點：家豪的路線上，第一個走進紅圈的位置
func lunge_point(f: Fighter) -> Vector3:
	var pts: Array = [bird.start_pos]
	for p in path:
		pts.append(ground(p))
	pts.append(world.cage)
	for i in range(1, pts.size()):
		var a: Vector3 = pts[i - 1]
		var b: Vector3 = pts[i]
		var n := maxi(int(flat_dist(a, b) / 0.2), 1)
		for k in range(0, n + 1):
			var q := a.lerp(b, float(k) / n)
			if flat_dist(q, f.pos) < LUNGE_R:
				return q
	return f.pos

## 香蕉皮：在冰上衝刺的工人踩到，沿這一步的方向直線滑出去（並切特寫）
func make_slip(f: Fighter, what := "香蕉皮") -> void:
	if not f.is_bird and world.on_ice(f.pos.x, f.pos.z):
		var dir := Vector3(sin(f.yaw), 0.0, cos(f.yaw))
		log_event("%s踩到%s，在冰上一路滑出去" % [f.name, what])
		if f.state == "lunge":
			mark("guard_slip")
		var pr: Array = predict_slide(f, dir)
		start_slide(f, dir)
		# 特寫：同時拍到起滑點和預計停下的地方
		var end_p: Vector3 = f.pos
		if not pr.is_empty():
			end_p = pr.back().end
		var mid: Vector3 = (f.pos + end_p) * 0.5
		var span := maxf(flat_dist(f.pos, end_p), 3.0)
		var side := (end_p - f.pos)
		side.y = 0.0
		side = side.normalized().cross(Vector3.UP) if side.length() > 0.1 else Vector3.RIGHT
		# 特寫跟著滑的人走（近、低），鏡頭在靠玩家的那一側
		if camera and side.dot(camera.global_position - f.pos) < 0.0:
			side = -side
		# 家豪剛好在鏡頭這一側（會擋在鏡頭前面、被畫面邊切一半）：換到另一側拍
		var near_a := 99.0
		var near_b := 99.0
		for k in 3:
			var at: Vector3 = f.pos.lerp(end_p, k * 0.5) + dir * 1.2
			near_a = minf(near_a, flat_dist(at + side * 5.2, bird.pos))
			near_b = minf(near_b, flat_dist(at - side * 5.2, bird.pos))
		var lift := 0.0
		var t0: Vector3 = f.pos + dir * 0.9 + Vector3(0, 1.2, 0)
		var t1: Vector3 = end_p + dir * 0.9 + Vector3(0, 1.2, 0)
		for opt in [[1.0, 0.0, near_a], [-1.0, 0.0, near_b], [1.0, 1.8, 99.0], [-1.0, 1.8, 99.0]]:
			# 這一側 → 另一側 → 這一側拉高 → 另一側拉高：挑第一個沒被樹、籠子、冰晶擋住，家豪也不在鏡頭前面的
			var off_t: Vector3 = side * 5.2 * float(opt[0]) + Vector3(0, 2.3 + float(opt[1]), 0) + dir * 1.2
			if float(opt[2]) < 4.6 or _blocked(t0 + off_t, t0, true) or _blocked(t1 + off_t, t1, true):
				continue
			side = side * float(opt[0])
			lift = float(opt[1])
			break
		# 他是腳朝前滑：鏡頭在側面偏前一點，拍得到嚇壞的臉和亂揮的手
		_follow_off = side * 5.2 + Vector3(0, 2.3 + lift, 0) + dir * 1.2
		_cut_to(f.pos + dir * 0.9 + Vector3(0, 1.2, 0), _follow_off, minf(span / SLIDE_SPEED + 1.0, 2.6))
		_follow = f
		_slowmo_until = Time.get_ticks_msec() + 300
		return
	toast("跌倒了…（雪地上不會滑）", 1.0)
	super(f, what)

## 工人接下來要走的折線（包含他現在的位置）
func planned_route(f: Fighter) -> Array:
	var pts: Array = [f.pos]
	if f.data.get("guard", f.get_meta("guard", false)):
		if f.state in ["guard", "idle", "patrol"]:
			pts.append(lunge_point(f))
		elif f.state == "lunge":
			pts.append(f.data.get("lunge_to", f.pos))
		return pts
	var rush: Array = f.data.get("rush", f.get_meta("rush", []))
	var ri: int = f.data.get("ri", 0)
	if f.state in ["rush", "idle", "patrol", "look", "alert"]:
		for i in range(ri, rush.size()):
			pts.append(ground(rush[i]))
	return pts

## 攔截點：沿著家豪接下來要走的路往前看，找第一個工人能比家豪先到（或同時到）的點；追不上回傳 null
func intercept_point(f: Fighter):
	var pts: Array = [bird.pos]
	for i in range(path_i, path.size()):
		pts.append(ground(path[i]))
	pts.append(world.cage)
	var walked := 0.0
	for i in range(1, pts.size()):
		var a: Vector3 = pts[i - 1]
		var b: Vector3 = pts[i]
		var seg := flat_dist(a, b)
		var n := maxi(int(seg / 0.5), 1)
		for k in range(0, n + 1):
			var q := a.lerp(b, float(k) / n)
			if flat_dist(f.pos, q) / RUSH_SPEED <= (walked + seg * float(k) / n) / BIRD_WALK:
				return q
		walked += seg
	return null

func _chase_line(f: Fighter) -> Array:
	var ip = f.data.get("chase_to")
	if ip == null:
		ip = intercept_point(f)
	return [f.pos, ip] if ip != null else [f.pos]

## 滑行時撞到別人：兩個人一起往前滑（一片香蕉皮可以帶走兩個人）
func _tick_slide(f: Fighter, dt: float) -> void:
	var r := slide_step(f, f.pos, f.data.sdir, f.data.snow, dt)
	if r.kind == "wall":
		# 撞到雪人：雪人的頭掉下來扣在他頭上
		for sn in world.get("snowman_nodes"):
			if flat_dist(sn.pos, f.pos) < 1.6 and (sn.head as Node3D).get_parent() == sn.node:
				var h := sn.head as Node3D
				sn.node.remove_child(h)
				world.add_child(h)
				f.data.snow_hat = h
				# 雪人剩下的身體也倒了（一眼看得出「雪人被撞爛、頭跑到他頭上」）
				(sn.node as Node3D).rotation.z = 1.35
				for nm in ["Scarf", "ScarfTail"]:
					var sc := (sn.node as Node3D).find_child(nm, true, false) as Node3D
					if sc:
						sc.visible = false   # 倒下時不露出圍巾（正面看像救生圈）
				(sn.node as Node3D).position = (sn.pos as Vector3) + Vector3(0, 0.25, 0)
				# 倒掉的雪人不再擋路（等他停下來才拿掉，不然這一步會直接穿過去）
				f.data.knock_at = Vector2(sn.pos.x, sn.pos.z)
				log_event("雪人的頭掉下來扣在%s頭上" % f.name)
				pop_label("咚！", f.pos + Vector3(0, 3.4, 0), Color(1, 1, 1), 900, f)
				sfx("crack")
				break
	if r.kind != "hit":
		super(f, dt)
		# 差一點：從別人身邊滑過去沒撞到 → 那個人嚇一跳回頭看
		# （只在對方已經落到滑行方向的後面、這一趟又沒撞到任何人時才算）
		if f.state == "kslide" and not f.data.get("missed", false) and not f.data.get("hit_any", false):
			var sdir: Vector3 = f.data.sdir
			for o in enemies:
				if o == f or not o.alive() or o.state in ["kslide", "stunned", "giveup"]:
					continue
				var rel: Vector3 = o.pos - f.pos
				rel.y = 0.0
				if flat_dist(o.pos, f.pos) < 3.0 and rel.dot(sdir) < 0.0:
					f.data.missed = true
					o.yaw = _yaw_to(o.pos, f.pos)
					pop_label("？！", o.pos + Vector3(0, 3.0, 0), Color(1, 1, 1), 1100, o)
					pop_label("差一點！", f.pos + Vector3(0, 3.2, 0), Color(1, 1, 1), 1100, f)
					_miss_text = _late_by(f, o)
					log_event("%s從%s身邊滑過去，差一點（%s）" % [f.name, o.name, _miss_text])
					# 擦身而過：慢動作＋近拍，兩個人都入鏡
					var mid: Vector3 = (f.pos + o.pos) * 0.5
					var side := sdir.cross(Vector3.UP)
					_cut_to(mid + Vector3(0, 1.0, 0), side * 5.0 + Vector3(0, 2.2, 0) - sdir * 1.0, 1.1)
					_slowmo_until = Time.get_ticks_msec() + 700
					break
		return
	var o: Fighter = r.other
	f.data.hit_any = true
	if not o.data.get("hit_once", false) and show_timing:
		# 第 3 關：撞上的那一刻插近拍（兩個人一起滑出去）
		o.data.hit_once = true
		var sd2: Vector3 = f.data.sdir
		_cut_to(o.pos + sd2 * 2.0 + Vector3(0, 1.0, 0), sd2.cross(Vector3.UP) * 6.0 + Vector3(0, 2.6, 0) - sd2 * 1.5, 1.6)
	log_event("%s撞到%s，連環撞！" % [f.name, o.name])
	pop_label("連環撞！", o.pos + Vector3(0, 3.6, 0), Color(1.0, 0.97, 0.9), 900, o)
	start_slide(o, f.data.sdir)
	o.data.hit_by = f
	if _cut_cam and _cut_cam.current and not show_timing:
		_follow = o
	_on_carom(f, o)
	_slowmo_until = Time.get_ticks_msec() + 250   # 撞上的瞬間頓一下
	_shake_until = Time.get_ticks_msec() + 300

# ---------------------------------------------------------------- 鏡頭特寫

func _cut_to(target: Vector3, offset: Vector3, sec: float) -> void:
	_follow = null
	if silent or _cut_cam == null or not is_inside_tree():
		return
	_cut_cam.global_position = target + offset
	_cut_cam.look_at(target, Vector3.UP)
	_cut_cam.make_current()
	_cut_t = sec

# ---------------------------------------------------------------- 每一畫面

func _process(dt: float) -> void:
	super(dt)
	var cut := _cut_cam != null and _cut_cam.current
	if cut and _follow != null and phase == Phase.RUNNING and _follow.state == "kslide":
		var sd3: Vector3 = _follow.data.get("sdir", Vector3.ZERO)
		var tgt3: Vector3 = _follow.pos + sd3 * 0.9 + Vector3(0, 1.2, 0)
		_cut_cam.global_position = _cut_cam.global_position.lerp(tgt3 + _follow_off, 0.25)
		_cut_cam.look_at(tgt3, Vector3.UP)
	_update_mini_light()
	_style_peels()
	# 特寫時收起場上的小道具和招牌字（結束後的演出由 _end 控制）
	if phase != Phase.ENDED and world.has_method("set_clutter"):
		world.set_clutter(not cut)
	# 救企鵝模式不用血條、不用右上角敵人欄
	for f in all_fighters():
		if f.bar:
			f.bar.visible = false
	if not _enemy_rows.is_empty():
		var col: Control = (_enemy_rows[0].face as Control).get_parent().get_parent()
		col.visible = false
	var hint := get_node_or_null("../HUD/Hint") as Label
	if hint:
		hint.visible = not cut and Input.is_physical_key_pressed(KEY_H)   # 操作說明只在按住 H 時出現
	if crosshair:
		crosshair.visible = not cut and (phase == Phase.PREPARE or (phase == Phase.RUNNING and not items.is_empty() and charges[selected] != 0))
	if _phase_label:
		_phase_label.visible = not cut and _phase_label.text != ""   # 特寫時連計時器一起收起來；沒字時收起膠囊
	# 準備時按住 Tab：從正上方看整個場地（方便算距離和時間）
	if _top_cam == null:
		_top_cam = Camera3D.new()
		_top_cam.fov = 55.0
		world.add_child(_top_cam)
	var want_top: bool = phase == Phase.PREPARE and not cut and (Input.is_physical_key_pressed(KEY_TAB) or force_top)
	if want_top and not _top_cam.current:
		var c: Vector3 = world.get("camera_look") if world.get("camera_look") != null else Vector3.ZERO
		_top_cam.global_position = Vector3(c.x, 26.0, c.z + 0.01)
		_top_cam.look_at(Vector3(c.x, 0, c.z), Vector3.FORWARD)
		_top_cam.make_current()
	elif not want_top and _top_cam.current:
		camera.make_current()
	var top_now := _top_cam.current
	if _list_layer and phase == Phase.PREPARE:
		for ch in _list_layer.get_children():
			(ch as CanvasItem).visible = not top_now   # 俯視時收起左邊面板和大標題
	if world.has_method("set_snow"):
		world.set_snow(not top_now)
	if _hotbar:
		# 道具格在左下角（原本在正下方會擋住家豪的起點）；不浮出「香蕉皮」三個字；開打後用完就收起來
		_hotbar.name_t = 0.0
		var left := phase == Phase.PREPARE
		for c in charges:
			if c != 0:
				left = true
		_hotbar.visible = not cut and phase != Phase.ENDED and left
	if cut and _preview:
		_preview.visible = false
		for d in _dots:
			d.visible = false
	_update_aim_marker(cut)
	_bird_tag.visible = false   # 家豪不掛名牌：腳下的光圈就夠了
	_bird_tag.position = bird.pos + Vector3(0, 2.4 + bird.air, 0)
	_bird_ring.position = bird.pos + Vector3(0, 0.04, 0)
	_bird_ring.rotation.y = _clock * 0.6
	_bird_ring.visible = bird.alive() and phase != Phase.ENDED and not cut
	for f in enemies:
		(_intents[f] as Label3D).visible = (_intents[f] as Label3D).visible and not cut
	if _how_label and cut:
		(_how_label.get_parent() as Control).visible = false
	# 畫面上少放字：「怎麼玩」8 秒後收成一個小標籤（按住 H 再打開）；大標題 4 秒後收起
	if phase == Phase.PREPARE and not cut and _how_label:
		var t_in := _clock - _prep_t0
		var first_time: bool = attempts.is_empty()     # 說明、大標題、示範都只在第一次進這一關時出現
		# 示範播放時先不貼說明（畫面上只留示範的一行字）；示範播完再貼幾秒
		var show_how: bool = (first_time and not _demo_playing and t_in < (15.0 if show_timing else 5.0)) or Input.is_physical_key_pressed(KEY_H)
		(_how_label.get_parent() as Control).visible = show_how and not (_top_cam != null and _top_cam.current)
		if _goal_label:
			# 紅色大標題只在第一關、第一次進來時出現一下
			_goal_label.visible = show_goal and first_time and not _goal_seen.has(_stage_key()) and t_in < 2.5 \
				and not (_top_cam != null and _top_cam.current)
		if _how_tab:
			_how_tab.visible = not show_how
	elif _how_tab:
		_how_tab.visible = false
	if _list_label:
		(_list_label.get_parent() as Control).visible = not cut and not defeat_shown
	var cl = world.get("_cage_label")
	if cl:
		(cl as Label3D).visible = world.get("_freed") or not cut   # 特寫時籠子的「救我！」不要蓋到人臉
	_path_line.visible = not cut
	_route_line.visible = not cut
	_peel_line.visible = not cut
	for f in _guard_labels:
		var gl: Label3D = _guard_labels[f]
		var show_g: bool = not cut and f.alive() and f.state in ["guard", "idle", "patrol"] and phase != Phase.ENDED
		gl.visible = false and show_g   # 箭頭本身就夠，不寫「撲」字
		if show_g:
			gl.position = lunge_point(f) + Vector3(0, 0.9, 0)
	for f in enemies:
		var hat = f.data.get("snow_hat")
		if hat and is_instance_valid(hat):
			_wear_snow_head(f, hat as Node3D)
	_draw_path()
	_draw_routes()
	_draw_placed_peels()
	_refresh_plates()

func _draw_path() -> void:
	var im := _path_line.mesh as ImmediateMesh
	im.clear_surfaces()
	if phase == Phase.ENDED:
		return
	var pts: Array = [bird.pos]
	for i in range(path_i, path.size()):
		pts.append(ground(path[i]))
	pts.append(world.cage)
	_vb.clear()
	# 家豪的路線退後一步（細一點、淡一點）：畫面上最搶眼的要是紅色的敵人路線
	_dashes(im, pts, Color(1.0, 0.8, 0.22, 0.9), 0.1)
	_flush(im)

## 工人的路線（紅色虛線、終點紅叉）、守衛的撲擊圈和撲過去的箭頭
func _draw_routes() -> void:
	var im := _route_line.mesh as ImmediateMesh
	im.clear_surfaces()
	if phase == Phase.ENDED:
		return
	_vb.clear()
	_ghost_used.clear()
	var flow := _clock * 1.3          # 虛線往工人要去的方向流動（只是畫面效果）
	for f in enemies:
		if not f.alive() or f.state in ["kslide", "stunned", "slip"]:
			continue
		var waiting: bool = f.data.get("guard", false) and f.state in ["guard", "idle", "patrol"]
		if waiting:
			# 守衛的撲擊圈：淡淡的紅色圓盤＋虛線邊
			var ring: Array = []
			for k in 49:
				var a := k * TAU / 48.0
				ring.append(ground(f.pos + Vector3(cos(a), 0, sin(a)) * LUNGE_R))
			var c0 := ground(f.pos) + Vector3(0, 0.07, 0)
			for k in 48:
				for v in [c0, (ring[k] as Vector3) + Vector3(0, 0.07, 0), (ring[k + 1] as Vector3) + Vector3(0, 0.07, 0)]:
					_v(Color(ROUTE_RED, 0.13), v)
			_flow(ring, Color(1, 1, 1, 0.85), 0.085, 0.09, 0.42, 0.34, _clock * 0.35)
			_flow(ring, Color(ROUTE_RED, 0.95), 0.05, 0.11, 0.42, 0.34, _clock * 0.35)
		var er := effective_route(f) if f.state != "chase" else {"main": _chase_line(f), "ghost": [], "ended": false}
		var route: Array = er.main
		var ghost: Array = er.ghost
		if ghost.size() >= 2:
			# 撞停爬起來之後改追的新路線（粉紅）
			_route(ghost, Color("ff4fb0"), flow, true)
		if route.size() < 2:
			continue
		if waiting:
			# 守衛：實心的紅色粗箭頭（家豪走進圈裡，他就沿這個方向撲過去）
			var a0: Vector3 = route[0]
			var a1: Vector3 = route[1]
			var dirv := (a1 - a0)
			dirv.y = 0
			if dirv.length() > 0.3:
				dirv = dirv.normalized()
				_solid(im, a0 + dirv * 0.9, a1 - dirv * 0.3, Color(1, 1, 1, 0.95), 0.2, 0.09)
				_solid(im, a0 + dirv * 0.95, a1 - dirv * 0.3, ROUTE_RED, 0.14, 0.11)
				_arrow_head(a1 - dirv * 0.35, dirv, ROUTE_RED, 1.25)
			continue
		_route(route, ROUTE_RED, flow, not (er.ended or not ghost.is_empty()))
	if not _reroute_used and _reroute_label:
		_reroute_label.visible = false
	_reroute_used = false
	_draw_demo(im)
	_draw_time_dots()
	_cross_lead = []
	_draw_timing_ghosts(im)
	if _cross_lead.size() == 2:
		_solid(im, _cross_lead[0], _cross_lead[1], Color(1.0, 0.95, 0.6, 0.9), 0.04)
	_flush(im)
	for f in _ghosts:
		if not _ghost_used.has(f):
			(_ghosts[f].node as Node3D).visible = false

func _cross(b: Vector3, c: Color) -> void:
	for v in [b + Vector3(-0.4, 0.12, -0.4), b + Vector3(-0.28, 0.12, -0.52), b + Vector3(0.52, 0.12, 0.28),
			b + Vector3(-0.4, 0.12, -0.4), b + Vector3(0.52, 0.12, 0.28), b + Vector3(0.4, 0.12, 0.4),
			b + Vector3(0.4, 0.12, -0.4), b + Vector3(0.52, 0.12, -0.28), b + Vector3(-0.28, 0.12, 0.52),
			b + Vector3(0.4, 0.12, -0.4), b + Vector3(-0.28, 0.12, 0.52), b + Vector3(-0.4, 0.12, 0.4)]:
		_v(c, v)

const ROUTE_RED := Color("e5484d")
const ROUTE_W := 0.19             # 紅線的半寬（比家豪的黃線粗一倍）

## 一條敵人路線：白邊＋飽和紅的粗虛線，往前流動；head＝終點畫箭頭
func _route(pts: Array, col: Color, flow: float, head: bool) -> void:
	var cut := 0.55 if head else 0.0       # 箭頭佔掉的長度
	_flow(pts, Color(1, 1, 1, 0.95), ROUTE_W + 0.05, 0.09, 0.7, 0.4, flow, 0.05, cut)
	_flow(pts, col, ROUTE_W, 0.11, 0.7, 0.4, flow, 0.0, cut)
	if head and pts.size() >= 2:
		var b: Vector3 = pts.back()
		var d: Vector3 = b - (pts[pts.size() - 2] as Vector3)
		d.y = 0.0
		if d.length() > 0.05:
			_arrow_head(b, d.normalized(), col, 1.0)

## 箭頭：白邊的三角形，尖端在 tip
func _arrow_head(tip: Vector3, dir: Vector3, col: Color, k: float) -> void:
	var side := dir.cross(Vector3.UP)
	var g := ground(tip)
	var base := g - dir * 0.62 * k
	for pass_i in 2:
		var grow := 0.09 if pass_i == 0 else 0.0
		var y := 0.1 if pass_i == 0 else 0.12
		var c := Color(1, 1, 1, 0.95) if pass_i == 0 else col
		var t0 := g + dir * grow * 1.6 + Vector3(0, y, 0)
		var b0 := base - dir * grow + Vector3(0, y, 0)
		for v in [t0, b0 + side * (0.42 * k + grow), b0 - side * (0.42 * k + grow)]:
			_v(c, v)

## 流動的虛線：沿著折線每 dash 公尺一段、空 gap 公尺，整條往前移 phase 公尺。
## y＝離地高度，pad＝每段前後多畫一點（白邊用），trim＝終點前留白（給箭頭）
func _flow(pts: Array, c: Color, w: float, y: float, dash: float, gap: float, phase_m: float, pad := 0.0, trim := 0.0) -> void:
	var total := 0.0
	for i in range(1, pts.size()):
		total += flat_dist(pts[i - 1], pts[i])
	total -= trim
	if total <= 0.05:
		return
	var period := dash + gap
	var s0 := fposmod(phase_m, period) - period
	var acc := 0.0
	for i in range(1, pts.size()):
		var a: Vector3 = pts[i - 1]
		var b: Vector3 = pts[i]
		var seg := flat_dist(a, b)
		if seg < 0.01:
			continue
		var dir := (b - a)
		dir.y = 0
		dir = dir.normalized()
		var side := dir.cross(Vector3.UP) * w
		# 這一段線上有哪些虛線格
		var k0 := int(floor((acc - s0) / period)) - 1
		var d0 := s0 + k0 * period
		while d0 < acc + seg:
			var lo := maxf(maxf(d0 - pad, acc), 0.0)
			var hi := minf(minf(d0 + dash + pad, acc + seg), total)
			if hi - lo > 0.02:
				var p0 := ground(a.lerp(b, (lo - acc) / seg)) + Vector3(0, y, 0)
				var p1 := ground(a.lerp(b, (hi - acc) / seg)) + Vector3(0, y, 0)
				for v in [p0 - side, p0 + side, p1 + side, p0 - side, p1 + side, p1 - side]:
					_v(c, v)
			d0 += period
		acc += seg

func _dashes(im: ImmediateMesh, pts: Array, c: Color, w: float) -> void:
	var dash := 0
	for i in range(1, pts.size()):
		var a: Vector3 = pts[i - 1]
		var b: Vector3 = pts[i]
		var side := (b - a)
		side.y = 0
		if side.length() < 0.01:
			continue
		side = side.normalized().cross(Vector3.UP) * w
		var n := maxi(int(flat_dist(a, b) / 0.35), 1)
		for k in n:
			dash += 1
			if dash % 2 == 0:
				continue
			var p0 := ground(a.lerp(b, float(k) / n)) + Vector3(0, 0.1, 0)
			var p1 := ground(a.lerp(b, float(k + 1) / n)) + Vector3(0, 0.1, 0)
			for v in [p0 - side, p0 + side, p1 + side, p0 - side, p1 + side, p1 - side]:
				_v(c, v)

## 頭上只放一個小圖示，不放長字
func _update_intents() -> void:
	# 頭上不常駐掛字：多人關卡第一次進場的前 2.5 秒顯示名字（之後靠背心顏色分辨；按住 H 再看）
	var show_names: bool = phase == Phase.PREPARE and enemies.size() > 1 \
		and ((attempts.is_empty() and _clock - _prep_t0 < 4.0) or Input.is_physical_key_pressed(KEY_H))
	for f in enemies:
		var l: Label3D = _intents[f]
		l.visible = show_names and f.alive()
		if l.visible:
			l.text = f.name
			l.position = top_pos(f) + Vector3(0, 0.75, 0)

## 一片香蕉皮放在 p，誰會踩到、會滑去哪（只預告到第一次撞到東西）
func peel_outcome(p: Vector3, skip = null) -> Array:
	var out: Array = []
	for f in enemies:
		if not f.alive() or f.state in ["kslide", "slip", "stunned"]:
			continue
		var er := effective_route(f, skip) if f.state != "chase" else {"main": _chase_line(f), "ghost": []}
		# 檢查的線段：還會走的紅線＋撞停之後的新紅線（不檢查他滑過去的那一段）
		var segs: Array = []
		var m: Array = er.main
		for i in range(1, m.size()):
			segs.append([m[i - 1], m[i], false])
		var gh: Array = er.ghost
		for i in range(1, gh.size()):
			segs.append([gh[i - 1], gh[i], true])
		for sg in segs:
			var a: Vector3 = sg[0]
			var b: Vector3 = sg[1]
			var on_ghost: bool = sg[2]
			var ab := Vector2(b.x - a.x, b.z - a.z)
			var l := ab.length()
			if l < 0.01:
				continue
			var t := clampf(Vector2(p.x - a.x, p.z - a.z).dot(ab) / (l * l), 0.0, 1.0)
			var q := a.lerp(b, t)
			if flat_dist(q, p) > ON_ROUTE:
				continue
			var dir := Vector3(ab.x, 0, ab.y) / l
			if not world.on_ice(p.x, p.z):
				out.append({"pts": [], "end": p, "text": "雪地", "color": Color(0.9, 0.9, 0.9)})
			else:
				var start_p: Vector3 = ground(q - dir * minf(PEEL_STEP, flat_dist(a, q)))
				if on_ghost:
					# 新紅線上：他走到這裡時家豪在哪？已經被抓到就來不及了
					var t_at: float = float(er.get("t0", 0.0)) + flat_dist(a, start_p) / RUSH_SPEED
					var bp: Vector3 = _bird_route_at(t_at)[0]
					if flat_dist(bp, start_p) < CATCH + 0.25:
						out.append({"pts": [], "end": p, "text": "太晚", "color": Color(1.0, 0.4, 0.3)})
						break
				var knock: int = er.get("knock", -1) if on_ghost else -1
				var keep_r := 0.0
				if knock >= 0:
					keep_r = world.obstacles[knock][1]
					world.obstacles[knock][1] = 0.0
				var pr: Array = predict_slide(f, dir, start_p) if preview_full else [_terrain_slide(f, dir, start_p)]
				if knock >= 0:
					world.obstacles[knock][1] = keep_r
				if not pr.is_empty():
					var r: Dictionary = pr[0]
					var tx := String(r.text)
					if tx.begins_with("✕"):
						r.text = "冰洞"
						r.color = Color(0.4, 0.8, 1.0)
					elif tx.begins_with("撞到雪") or tx.begins_with("撞牆"):
						r.text = "咚"
						r.color = Color(0.9, 0.9, 0.9)
					elif tx.begins_with("撞到"):
						r.text = tx.trim_prefix("撞到")      # 撞到誰就寫誰的名字
						r.color = Color(1.0, 0.85, 0.2)
					else:
						r.text = "停"
						r.color = Color(0.9, 0.9, 0.9)
					out.append(r)
			break
	return out

## 預告只在「準備階段、手上拿香蕉皮、準心在紅線上」才出現；開打後不畫
func _update_slide_preview() -> void:
	var im := _lines.mesh as ImmediateMesh
	im.clear_surfaces()
	var results: Array = []
	var aiming: bool = phase == Phase.PREPARE and aim_point != null and aim_error == "" \
		and not items.is_empty() and items[selected].id == "banana" and charges[selected] != 0
	if aiming:
		results = _tier(peel_outcome(aim_point))
	_aim_on_route = not results.is_empty()
	_aim_ends.clear()
	_draw_slides(im, results, Color(1.0, 0.9, 0.22, 1.0), 0.13, Color(0.23, 0.16, 0.12, 0.95))
	for i in _ends.size():
		var lb: Label3D = _ends[i]
		if i < results.size():
			lb.visible = true
			lb.text = results[i].text
			lb.position = (results[i].end as Vector3) + Vector3(0, 1.0, 0)
			_aim_ends.append(results[i].end)
		else:
			lb.visible = false

## 已經放下的香蕉皮：淡淡畫出它真正的結果（準備階段）
func _draw_placed_peels() -> void:
	var im := _peel_line.mesh as ImmediateMesh
	im.clear_surfaces()
	if phase != Phase.PREPARE:
		return
	var bi := skill_index("banana")
	if bi < 0:
		return
	var results: Array = []
	for pl in items[bi].peels:
		results.append_array(_tier(peel_outcome(pl.pos, pl.pos)))
	_draw_slides(im, results, Color(1.0, 1.0, 1.0, 0.45), 0.07)

func _draw_slides(im: ImmediateMesh, results: Array, col: Color, w: float, edge := Color(0, 0, 0, 0)) -> void:
	var drew := false
	# 先畫深色的邊（寬一點），再畫上面的顏色：同一批三角形，後畫的蓋在上面
	var passes: Array = [[edge, w + 0.06], [col, w]] if edge.a > 0.0 else [[col, w]]
	for ps in passes:
		var c: Color = ps[0]
		var hw: float = ps[1]
		for r in results:
			var pts: Array = r.pts
			if pts.size() < 2:
				continue
			if not drew:
				_vb.clear()
				drew = true
			for i in range(1, pts.size()):
				var a: Vector3 = pts[i - 1] + Vector3(0, 0.12, 0)
				var b: Vector3 = pts[i] + Vector3(0, 0.12, 0)
				var side := (b - a)
				side.y = 0
				if side.length() < 0.001:
					continue
				side = side.normalized().cross(Vector3.UP) * hw
				for v in [a - side, a + side, b + side, a - side, b + side, b - side]:
					_v(c, v)
			if r.get("ticks", false):
				# 每 0.5 秒（滑 3 公尺）一道橫線：滑行比跑步快 3 倍
				var d := 0.0
				var next := SLIDE_SPEED * 0.5
				for i in range(1, pts.size()):
					var a2: Vector3 = pts[i - 1]
					var b2: Vector3 = pts[i]
					var seg := flat_dist(a2, b2)
					while seg > 0.001 and d + seg >= next:
						var q: Vector3 = a2.lerp(b2, (next - d) / seg) + Vector3(0, 0.13, 0)
						var dv := (b2 - a2)
						dv.y = 0
						var sd := dv.normalized().cross(Vector3.UP) * (w * 3.4 + (hw - w))
						var fw2 := dv.normalized() * (0.07 + (hw - w))
						for v in [q - sd - fw2, q + sd - fw2, q + sd + fw2, q - sd - fw2, q + sd + fw2, q - sd + fw2]:
							_v(c, v)
						next += SLIDE_SPEED * 0.5
					d += seg
	if drew:
		_flush(im)

# ---------------------------------------------------------------- 第五輪：演出細節

## 鏡頭的「右手邊」（平放在地上），用來把兩顆頭左右排開
func _cam_side() -> Vector3:
	if camera == null:
		return Vector3.RIGHT
	var x := camera.global_basis.x
	x.y = 0.0
	return x.normalized() if x.length() > 0.01 else Vector3.RIGHT

## 被拎著：在工人胸前、臉朝跟工人同一邊（也就是朝鏡頭），一直亂扭
func _hold_bird(b: Fighter) -> void:
	if _catcher == null:
		return
	var fw := Vector3(sin(_catcher.yaw), 0, cos(_catcher.yaw))
	var sd := fw.cross(Vector3.UP)
	var hand = hand_pos(_catcher)
	if hand != null:
		# 掛在工人舉起來的右手上（手抓著帽 T 的帽子）：家豪在手的前面一點、背對著手
		var g := ground((hand as Vector3) + sd * 0.5 + fw * 0.1)
		# 不要嵌進雪人／樹裡：太近就往外推
		for ob in world.obstacles:
			var c2: Vector2 = ob[0]
			var off := Vector2(g.x - c2.x, g.z - c2.y)
			var need: float = float(ob[1]) + 0.55
			if off.length() < need and off.length() > 0.01:
				var push := off.normalized() * (need - off.length())
				g += Vector3(push.x, 0, push.y)
		for sn in world.get("snowman_nodes"):
			if (sn.node as Node3D).visible:
				var off2 := Vector2(g.x - (sn.pos as Vector3).x, g.z - (sn.pos as Vector3).z)
				if off2.length() < 1.3 and off2.length() > 0.01:
					var push2 := off2.normalized() * (1.3 - off2.length())
					g += Vector3(push2.x, 0, push2.y)
		b.pos = g
		b.air = minf(b.air + 0.12, maxf((hand as Vector3).y - g.y - HANG, 0.0))
	else:
		b.pos = ground(_catcher.pos + fw * 0.6 - sd * 0.45)
		b.air = minf(b.air + 0.08, 1.1)
	b.yaw = _catcher.yaw + sin(_clock * 40.0) * 0.3

## 被拎著的家豪：身體左右扭、翅膀狂拍
func _bird_pose() -> void:
	var b := bird
	if phase == Phase.ENDED and outcome == "win" and b.body != null and _recap_t <= 0.0 and _ended_t > 2.7 and _ended_t < 4.2:
		# 收尾：家豪嘆一口氣、聳聳肩（身體先縮再挺，翅膀往上一抬）
		var k := clampf((_ended_t - 2.7) / 1.5, 0.0, 1.0)
		var shrug := sin(k * PI)
		b.body.rotation = Vector3(-0.15 * shrug, 0, 0)
		b.body.scale = Vector3(1.0 + 0.08 * shrug, 1.0 - 0.12 * shrug, 1.0 + 0.08 * shrug)
		b.body.set_meta("posed", false)
		for w in b.wings:
			var sx := -1.0 if w.name == "WingL" else 1.0
			w.rotation = Vector3(0, 0, sx * (0.2 + 1.1 * shrug))
		return
	if b.body != null and (b.state == "lifted" or b.data.get("held", false)):
		# 每 0.3 秒左右用力扭一下（掙扎）
		var jerk := 1.0 if fmod(_clock, 0.3) < 0.12 else 0.35
		b.body.rotation = Vector3(-0.2 + 0.25 * jerk * sin(_clock * 17.0), 0, sin(_clock * 23.0) * 0.6 * jerk)
		b.body.scale = Vector3.ONE
		b.body.set_meta("posed", false)
		for w in b.wings:
			var sx := -1.0 if w.name == "WingL" else 1.0
			w.rotation = Vector3(0, 0, sx * (0.4 + 0.9 * absf(sin(_clock * 30.0))))
		return
	super()

## 對白泡泡：固定在頭上（不會往上飄），白字粗黑邊
func bubble(text: String, who: Fighter, dy: float, ms: int, off := Vector3.ZERO) -> void:
	if silent:
		return
	pop_label(text, who.pos + Vector3(0, dy, 0), Color(1, 1, 1), ms, who)
	if _labels.is_empty():
		return
	var e: Dictionary = _labels.back()
	e.fixed = true
	e.tilt = 0.0
	e.off = off
	e.dy = dy
	var l: Label3D = e.node
	l.font_size = 56
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_plate(l, "bubble")

## 同一個人頭上同一個字 0.5 秒內只跳一次（不會「咚！咚！」疊在一起）
func pop_label(text: String, pos: Vector3, color: Color, ms: int, follow: Fighter = null) -> void:
	var key := "%s|%s" % [text, str(follow.get_instance_id()) if follow else "-"]
	if _pop_seen.has(key) and _clock - float(_pop_seen[key]) < 0.5:
		return
	_pop_seen[key] = _clock
	if follow and not follow.is_bird and _rigs.has(follow):
		pos = top_pos(follow) + Vector3(0, 0.15, 0)   # 一律放在帽頂上方：不蓋臉、也不會黃字疊在黃帽子上
	elif follow and pos.y - follow.pos.y > 2.7:
		pos.y = follow.pos.y + 2.7
	if follow:
		# 同一個人頭上同時只留一個跳字（新的蓋掉舊的），不會疊成一團
		for i in range(_labels.size() - 1, -1, -1):
			var e: Dictionary = _labels[i]
			if e.follow == follow and not e.get("fixed", false):
				if is_instance_valid(e.node):
					e.node.queue_free()
				_labels.remove_at(i)
	super(text, pos, color, ms, follow)
	if not _labels.is_empty():
		# 狀聲字：大、粗描邊、微微歪一邊（漫畫字）；字的下緣對齊定位點，往上長
		var e2: Dictionary = _labels.back()
		var pl := e2.node as Label3D
		if UISkin.font():
			pl.font = UISkin.font()
		pl.font_size = 108
		pl.outline_size = 36
		pl.outline_modulate = UISkin.INK
		pl.billboard = BaseMaterial3D.BILLBOARD_DISABLED     # 自己對著鏡頭轉（才歪得了）
		pl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		_pop_n += 1
		e2.tilt = 0.13 if _pop_n % 2 == 0 else -0.1
		_face_label(e2)

func _update_labels(now: int) -> void:
	super(now)
	for e in _labels:
		if not is_instance_valid(e.node):
			continue
		if e.get("fixed", false) and e.follow:
			var f: Fighter = e.follow
			(e.node as Label3D).position = f.pos + Vector3(0, float(e.dy) + f.air, 0) + (e.get("off", Vector3.ZERO) as Vector3)
		_face_label(e)

var _pop_n := 0

## 跳字、對白泡泡自己面向鏡頭（跳字再歪一點）
func _face_label(e: Dictionary) -> void:
	if not e.has("tilt") or not is_inside_tree():
		return
	var cam := get_viewport().get_camera_3d()
	if cam:
		(e.node as Node3D).global_basis = cam.global_basis * Basis(Vector3.BACK, float(e.tilt))

## 滑停的時候旁邊有雪堆：倒栽進雪堆，只露出兩條腿在空中亂踢（出局）
func _stop_slide(f: Fighter, msg: String) -> void:
	var ka = f.data.get("knock_at")
	if ka != null:
		f.data.erase("knock_at")
		for ob in world.obstacles:
			if (ob[0] as Vector2).distance_to(ka) < 0.05:
				ob[1] = 0.0
	if f.hp > 0.0:
		for p in world.get("snow_piles"):
			if flat_dist(p, f.pos) < PILE_R:
				f.hp = 0.0
				f.set_state("dead")
				f.data.pile = ground(p)
				f.pos = ground(p)
				log_event("%s倒栽進雪堆，只剩兩條腿在外面" % f.name)
				pop_label("噗！", f.pos + Vector3(0, 1.9, 0), Color(1, 1, 1), 900)
				sfx("crack")
				mark("pile")
				_shake_until = Time.get_ticks_msec() + 300
				anim(f, "Run")
				var away: Vector3 = (camera.global_position - f.pos) if camera else Vector3(0, 0, 1)
				away.y = 0.0
				away = away.normalized() if away.length() > 0.1 else Vector3.BACK
				_cut_smart(f.pos + Vector3(0, 1.1, 0), away * 5.2 + Vector3(0, 1.8, 0), 1.6)
				return
	super(f, msg)

## 泡在冰洞裡：一直發抖，過一下吐泡泡「噗嚕…」
func _tick_sunk(f: Fighter, dt: float) -> void:
	super(f, dt)
	var rig = _rigs.get(f)
	if rig != null:
		f.air = f.air / SINK_DEPTH * (SINK_SHOW * float(rig.unit))   # 小人比較矮：水面剛好到肩膀
	f.yaw = float(f.data.get("sunk_yaw", f.yaw)) + sin(f.data.sink_t * 45.0) * 0.06
	if f.data.sink_t > 1.0 and not f.data.get("blub", false):
		f.data.blub = true
		for o in enemies:
			if o != f and o.data.get("blub", false) and flat_dist(o.pos, f.pos) < 1.5:
				return   # 同一個洞只冒一次「喀喀喀…」
		pop_label("喀喀喀…", f.pos + Vector3(0, 0.0, 0), Color(0.62, 0.88, 1.0), 2400, f)

func _update_stars(f: Fighter, on: bool) -> void:
	if not _stars.has(f):
		if not on:
			return
		var arr: Array = []
		for k in 3:
			var mi := MeshInstance3D.new()
			mi.mesh = prop_mesh("fx_star")
			mi.material_override = _fx_mat("star")
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			world.add_child(mi)
			arr.append(mi)
		_stars[f] = arr
	for k in 3:
		var l: Node3D = _stars[f][k]
		l.visible = on
		if on:
			var a := _clock * 5.0 + k * TAU / 3.0
			var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
			l.position = top_pos(f) + Vector3(cos(a) * 1.0, -0.35 + sin(a * 2.0) * 0.08, sin(a) * 1.0)
			var b := cam.global_basis if cam else Basis.IDENTITY
			l.global_basis = (b * Basis(Vector3.BACK, _clock * 3.0 + k)).scaled(Vector3.ONE * 1.35)

## 實心粗線（守衛撲過去的箭頭用）
func _solid(im: ImmediateMesh, a: Vector3, b: Vector3, c: Color, w: float, y := 0.12) -> void:
	var side := (b - a)
	side.y = 0
	if side.length() < 0.01:
		return
	side = side.normalized().cross(Vector3.UP) * w
	var p0 := ground(a) + Vector3(0, y, 0)
	var p1 := ground(b) + Vector3(0, y, 0)
	for v in [p0 - side, p0 + side, p1 + side, p0 - side, p1 + side, p1 - side]:
		_v(c, v)

## 預告分級：preview_full＝false 的關卡只給 1.5 公尺的方向箭頭（瞄準中和已經放下的都一樣）
func _tier(results: Array) -> Array:
	if preview_full:
		return results
	for r in results:
		if r.get("terrain", false):
			r.text = r.terrain_text
			r.color = Color(1.0, 0.92, 0.25)
	return results

# ---------------------------------------------------------------- 第六輪：畫線緩衝、改道預告、時機

func _v(c: Color, v: Vector3) -> void:
	_vb.append(c)
	_vb.append(v)

## 有頂點才開 surface（不然 Godot 會一直噴「No vertices were added」）
func _flush(im: ImmediateMesh) -> void:
	if _vb.is_empty():
		return
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(0, _vb.size(), 2):
		im.surface_set_color(_vb[i])
		im.surface_add_vertex(_vb[i + 1])
	im.surface_end()
	_vb.clear()

## 準備階段：已經放下的香蕉皮會改變工人的路線。
##   {"main": 還會走的紅線, "ghost": 撞停爬起來之後改追的新紅線（可能是空的）, "ended": 他在那片香蕉皮之後就出局了}
## skip：算某一片香蕉皮自己的結果時，不要把它自己算進去
func effective_route(f: Fighter, skip = null) -> Dictionary:
	var route := planned_route(f)
	var out := {"main": route, "ghost": [], "ended": false}
	if phase != Phase.PREPARE or not preview_full or f.data.get("guard", f.get_meta("guard", false)):
		return out
	var bi := skill_index("banana")
	if bi < 0:
		return out
	var walked := 0.0
	for i in range(1, route.size()):
		var a: Vector3 = route[i - 1]
		var b: Vector3 = route[i]
		var ab := Vector2(b.x - a.x, b.z - a.z)
		var l := ab.length()
		if l < 0.01:
			continue
		var best_t := 2.0
		var best_q = null
		for pl in items[bi].peels:
			var pp: Vector3 = pl.pos
			if skip != null and flat_dist(pp, skip) < 0.05:
				continue
			var t := clampf(Vector2(pp.x - a.x, pp.z - a.z).dot(ab) / (l * l), 0.0, 1.0)
			var q := a.lerp(b, t)
			if flat_dist(q, pp) <= ON_ROUTE and t < best_t:
				best_t = t
				best_q = q
		if best_q != null and world.on_ice((best_q as Vector3).x, (best_q as Vector3).z):
			var dir := Vector3(ab.x, 0, ab.y) / l
			var pre: Array = route.slice(0, i)
			pre.append(best_q)
			out.main = pre
			# 走到離香蕉皮 PEEL_R 公尺就踩到了：從那裡開始滑
			var step_on: Vector3 = (best_q as Vector3) - dir * minf(PEEL_STEP, flat_dist(a, best_q))
			var pr: Array = predict_slide(f, dir, ground(step_on))
			if pr.is_empty():
				return out
			var r: Dictionary = pr[0]
			var tx := String(r.text)
			if not (tx.begins_with("撞到雪") or tx.begins_with("撞牆") or tx.begins_with("停")):
				out.ended = true    # 掉洞、撞人：之後的事就不預告了
				return out
			var stop: Vector3 = r.end
			for pile in world.get("snow_piles"):
				if flat_dist(pile, stop) < PILE_R:
					out.ended = true
					return out
			var slide_len := 0.0
			var pts: Array = r.pts
			for k in range(1, pts.size()):
				slide_len += flat_dist(pts[k - 1], pts[k])
			var t_stop: float = (walked + flat_dist(a, best_q) - PEEL_STEP) / RUSH_SPEED + slide_len / SLIDE_SPEED + STUN_TIME
			var q2 = _intercept_from(stop, t_stop)
			out.ghost = [stop, q2] if q2 != null else [stop]
			out.t0 = t_stop
			# 撞到的雪人到時候已經倒了：之後的預告不要再把它當牆
			if tx.begins_with("撞到雪") or tx.begins_with("撞牆"):
				for k in world.obstacles.size():
					var ob: Array = world.obstacles[k]
					if (ob[0] as Vector2).distance_to(Vector2(stop.x, stop.z)) < 1.6 and float(ob[1]) > 0.0:
						out.knock = k
						break
			return out
		walked += l
	return out

## 家豪在 t 秒時的位置和接下來的路（照黃線走，準備階段用）
func _bird_route_at(t: float) -> Array:
	var pts: Array = [bird.start_pos]
	for p in path:
		pts.append(ground(p))
	pts.append(world.cage)
	var d := t * BIRD_WALK
	for i in range(1, pts.size()):
		var seg := flat_dist(pts[i - 1], pts[i])
		if d <= seg:
			var out: Array = [(pts[i - 1] as Vector3).lerp(pts[i], d / maxf(seg, 0.001))]
			out.append_array(pts.slice(i))
			return out
		d -= seg
	return [world.cage]

## 從 from 出發、t0 秒後開始追：攔得到家豪的第一個點（攔不到就 null）
func _intercept_from(from: Vector3, t0: float):
	var pts := _bird_route_at(t0)
	var walked := 0.0
	for i in range(1, pts.size()):
		var a: Vector3 = pts[i - 1]
		var b: Vector3 = pts[i]
		var seg := flat_dist(a, b)
		var n := maxi(int(seg / 0.5), 1)
		for k in range(0, n + 1):
			var q := a.lerp(b, float(k) / n)
			if flat_dist(from, q) / RUSH_SPEED <= (walked + seg * float(k) / n) / BIRD_WALK:
				return q
		walked += seg
	return null

## 沿著折線走 d 公尺的位置
func _along(pts: Array, d: float) -> Vector3:
	for i in range(1, pts.size()):
		var seg := flat_dist(pts[i - 1], pts[i])
		if d <= seg:
			return (pts[i - 1] as Vector3).lerp(pts[i], d / maxf(seg, 0.001))
		d -= seg
	return pts.back()

## 第 3 關：紅線上每 1 秒一個點＋秒數
func _draw_time_dots() -> void:
	var used := 0
	if show_timing and phase == Phase.PREPARE:
		for f in enemies:
			if not f.alive() or f.data.get("guard", false):
				continue
			var route := planned_route(f)
			var total := 0.0
			for i in range(1, route.size()):
				total += flat_dist(route[i - 1], route[i])
			var sec := 1
			while sec * RUSH_SPEED <= total and used < 40:
				var p := _along(route, sec * RUSH_SPEED)
				var w := 0.22
				for v in [p + Vector3(-w, 0.13, -w), p + Vector3(w, 0.13, -w), p + Vector3(w, 0.13, w),
						p + Vector3(-w, 0.13, -w), p + Vector3(w, 0.13, w), p + Vector3(-w, 0.13, w)]:
					_v(Color(1, 1, 1, 0.95), v)
				if used >= _time_labels.size():
					var l := Label3D.new()
					l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
					l.no_depth_test = true
					l.font_size = 60
					l.pixel_size = 0.0005
					l.fixed_size = true
					l.outline_size = 12
					world.add_child(l)
					_time_labels.append(l)
				var tl: Label3D = _time_labels[used]
				tl.text = "%d" % sec
				var top_on: bool = _top_cam != null and _top_cam.current
				tl.position = p + (Vector3(0, 0.3, 0.75) if top_on else Vector3(0, 0.6, 0))
				tl.font_size = 84 if top_on else 60
				tl.visible = top_on and not (aim_point != null and flat_dist(p, aim_point) < 1.3)   # 秒數只在俯視出現；不要被落點圈壓住
				used += 1
				sec += 1
	for i in range(used, _time_labels.size()):
		(_time_labels[i] as Label3D).visible = false

## 第 3 關：瞄準某人的紅線時，標出「他踩到的那一刻，其他人在哪」（白圈＋名字）
func _draw_timing_ghosts(_im: ImmediateMesh) -> void:
	if _cross_label:
		_cross_label.visible = false
	var aiming: bool = show_timing and phase == Phase.PREPARE and aim_point != null and aim_error == "" \
		and not items.is_empty() and items[selected].id == "banana" and charges[selected] != 0
	if not aiming or _demo_playing:
		return
	var p: Vector3 = aim_point
	for f in enemies:
		if f.data.get("guard", false):
			continue
		var route := planned_route(f)
		var walked := 0.0
		for i in range(1, route.size()):
			var a: Vector3 = route[i - 1]
			var b: Vector3 = route[i]
			var ab := Vector2(b.x - a.x, b.z - a.z)
			var l := ab.length()
			if l < 0.01:
				continue
			var t := clampf(Vector2(p.x - a.x, p.z - a.z).dot(ab) / (l * l), 0.0, 1.0)
			if flat_dist(a.lerp(b, t), p) <= ON_ROUTE:
				# 走到離香蕉皮 PEEL_STEP 就踩到了：用踩到的那一刻算
				var t_hit := maxf(walked + l * t - PEEL_STEP, 0.0) / RUSH_SPEED
				var dir := Vector3(ab.x, 0, ab.y) / l
				for o in enemies:
					if o == f or o.data.get("guard", false):
						continue
					var cr := _crossing(f, o, p, dir, t_hit)
					if cr.is_empty():
						continue
					# 分身：他滑到交叉點的那一刻，另一個人走到哪（站在黃線上＝撞得到；差多少自己用眼睛看）
					var ro := planned_route(o)
					var d_o: float = float(cr.arrive) * RUSH_SPEED
					var gp := _along(ro, d_o)
					var gp2 := _along(ro, d_o + 0.5)
					var back := _along(ro, maxf(d_o - 0.5, 0.0))
					_show_ghost(o, gp, _yaw_to(back, gp2) if flat_dist(back, gp2) > 0.05 else o.yaw, "run")
					_cross_tag(f, o, cr)
				return
			walked += l

## 改追的新紅線起點：寫「撞停爬起來，改追這裡」
func _reroute_tag(at: Vector3) -> void:
	if _reroute_label == null:
		_reroute_label = Label3D.new()
		_reroute_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_reroute_label.no_depth_test = true
		_reroute_label.font_size = 56
		_reroute_label.pixel_size = 0.0005
		_reroute_label.fixed_size = true
		_reroute_label.outline_size = 14
		_reroute_label.modulate = Color(1.0, 0.65, 0.75)
		_reroute_label.text = "撞停→爬起來→改走粉紅線"
		world.add_child(_reroute_label)
		_plate(_reroute_label, "yellow")
	_reroute_used = true
	_reroute_label.position = at + Vector3(0, 1.4, 0)
	_reroute_label.visible = phase == Phase.PREPARE and not (_cut_cam != null and _cut_cam.current)

## 「場地照實畫、人不畫」：只看冰洞、牆、雪地，不管會不會撞到人（第 2 關以後用）
func _terrain_slide(f: Fighter, dir: Vector3, start: Vector3) -> Dictionary:
	var pos := start
	var snow := 0.0
	var pts: Array = [pos]
	var res := {}
	for i in 600:
		var r := slide_step(f, pos, dir, snow, SIM_DT, enemies)
		snow = r.snow
		if r.kind == "move":
			# 站著不動的人（守衛）會擋住：線畫到他為止，後面留給玩家想
			var blocker = null
			for o in enemies:
				if o != f and o.alive() and o.state in ["guard", "idle", "patrol"] and o.data.get("guard", o.get_meta("guard", false)) \
						and flat_dist(r.pos, o.pos) < HIT_R:
					blocker = o
			if blocker != null:
				res = {"kind": "person", "pos": pos, "who": blocker}
				break
			pos = r.pos
			if i % 6 == 0:
				pts.append(pos)
			continue
		res = r
		break
	pts.append(res.get("pos", pos))
	var kind: String = res.get("kind", "stop")
	var t := "停"
	if kind == "person":
		t = (res.who as Fighter).name
	elif kind in ["hole", "thin"]:
		t = "冰洞"
	elif kind == "wall":
		t = "咚"
	return {"pts": pts, "end": pts.back(), "text": t, "color": Color(1.0, 0.92, 0.25),
		"terrain": true, "terrain_text": t, "ticks": true}

## 擦身而過時：滑行的人晚（或早）了幾秒——他經過對方路線時，對方已經過去多久了
func _late_by(f: Fighter, o: Fighter) -> String:
	var rush: Array = o.get_meta("rush", [])
	if rush.is_empty():
		return ""
	var sdir: Vector3 = f.data.sdir
	# 對方路線上離「滑行線」最近的點，就是交叉點
	var best_d := 1e9
	var best_along := 0.0
	var along := 0.0
	var pts: Array = [ground(o.start_pos)]
	for p in rush:
		pts.append(ground(p))
	for i in range(1, pts.size()):
		var a: Vector3 = pts[i - 1]
		var b: Vector3 = pts[i]
		var seg := flat_dist(a, b)
		var n := maxi(int(seg / 0.1), 1)
		for k in n + 1:
			var q := a.lerp(b, float(k) / n)
			var rel := q - f.pos
			rel.y = 0.0
			var perp := (rel - sdir * rel.dot(sdir)).length()
			if perp < best_d:
				best_d = perp
				best_along = along + seg * float(k) / n
		along += seg
	var t_o := best_along / RUSH_SPEED
	var dt := time - t_o
	if absf(dt) < 0.05:
		return ""
	return "%s晚了 %.1f 秒" % [f.name, dt] if dt > 0.0 else "%s早了 %.1f 秒" % [f.name, -dt]

## 第 3 關：瞄準時在交叉點寫「阿水 3.3 秒經過」
func _crossing(f: Fighter, o: Fighter, p: Vector3, dir: Vector3, t_hit: float) -> Dictionary:
	# 交叉點：o 的路線上，剛好落在 f 滑行線上的那一點。回傳 {q 交叉點, arrive f 幾秒滑到, pass o 幾秒走到}
	var route := planned_route(o)
	var along := 0.0
	for i in range(1, route.size()):
		var a: Vector3 = route[i - 1]
		var b: Vector3 = route[i]
		var seg := flat_dist(a, b)
		var n := maxi(int(seg / 0.1), 1)
		for k in n + 1:
			var q := a.lerp(b, float(k) / n)
			var rel := q - p
			rel.y = 0.0
			if rel.dot(dir) > 0.0 and (rel - dir * rel.dot(dir)).length() < 0.06:
				var start := p - dir * PEEL_STEP
				return {"q": q, "arrive": t_hit + flat_dist(start, q) / SLIDE_SPEED, "pass": (along + seg * float(k) / n) / RUSH_SPEED}
		along += seg
	return {}

## 按住 Tab 的俯視才直接給秒數：字放在離交叉點、落點圈、終點泡泡都遠的那一邊，拉一條引線指回去
func _cross_tag(f: Fighter, o: Fighter, cr: Dictionary) -> void:
	if _top_cam == null or not _top_cam.current:
		return
	if _cross_label == null:
		_cross_label = Label3D.new()
		_cross_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_cross_label.no_depth_test = true
		_cross_label.font_size = 50
		_cross_label.pixel_size = 0.0005
		_cross_label.fixed_size = true
		world.add_child(_cross_label)
		_plate(_cross_label, "ice")
	var q: Vector3 = cr.q
	_cross_label.text = "%s %.1f 秒 ／ %s %.1f 秒" % [f.name, float(cr.arrive), o.name, float(cr.pass)]
	var best := Vector3(0, 0, 2.6)
	var best_d := -1.0
	for off in [Vector3(0, 0, 2.6), Vector3(0, 0, -2.6), Vector3(3.6, 0, 1.6), Vector3(-3.6, 0, 1.6)]:
		var at: Vector3 = q + off
		var d := flat_dist(at, aim_point) if aim_point != null else 99.0
		for e in _aim_ends:
			d = minf(d, flat_dist(at, e))
		for g in enemies:
			d = minf(d, flat_dist(at, g.pos))
			var rt := planned_route(g)
			for k in range(1, rt.size()):
				for u in 9:
					d = minf(d, flat_dist(at, (rt[k - 1] as Vector3).lerp(rt[k], u / 8.0)) + 0.8)
		if d > best_d:
			best_d = d
			best = off
	_cross_label.position = q + best + Vector3(0, 0.5, 0)
	_cross_label.visible = true
	_cross_lead = [q, q + best]

# ---------------------------------------------------------------- 第 3 關開場示範（一個「太早」的例子，教怎麼看時間，不洩漏答案）

const DEMO_SPEED := 1.1
const DEMO_HOLD := 3.0

## 在準備階段一開始自動播一次：虛影香蕉皮→阿土虛影走過去、滑出去（黃線格子一格一格亮）→阿水虛影同步走→在交叉點比時間
func _draw_demo(_im: ImmediateMesh) -> void:
	_demo_playing = false
	if _demo_peel:
		_demo_peel.visible = false
	if not show_timing or phase != Phase.PREPARE or enemies.size() < 2 or not attempts.is_empty():
		return
	var a_f: Fighter = enemies[0]
	var b_f: Fighter = enemies[1]
	var ra := planned_route(a_f)
	var rb := planned_route(b_f)
	if ra.size() < 2 or rb.size() < 2:
		return
	var dir: Vector3 = (ra[1] as Vector3) - (ra[0] as Vector3)
	dir.y = 0.0
	var la := dir.length()
	dir = dir / la
	var peel_d := la * 0.2                       # 示範：香蕉皮放在紅線前 20%（太早的例子）
	var step_d := maxf(peel_d - PEEL_STEP, 0.0)
	var t_step := step_d / RUSH_SPEED
	# 交叉點：阿水路線上離阿土那條線最近的點
	var best_d := 1e9
	var cross := Vector3.ZERO
	for i in range(1, rb.size()):
		var p0: Vector3 = rb[i - 1]
		var p1: Vector3 = rb[i]
		for k in 41:
			var q := p0.lerp(p1, k / 40.0)
			var rel := q - (ra[0] as Vector3)
			rel.y = 0.0
			var perp := (rel - dir * rel.dot(dir)).length()
			if perp < best_d:
				best_d = perp
				cross = (ra[0] as Vector3) + dir * rel.dot(dir)
	var slide_to_cross := flat_dist(cross, (ra[0] as Vector3) + dir * step_d)
	var t_a := t_step + slide_to_cross / SLIDE_SPEED
	var tau := (_clock - _prep_t0) * DEMO_SPEED
	var t_end := t_a + 0.4
	if Input.is_physical_key_pressed(KEY_SPACE) and tau < t_end + DEMO_HOLD * DEMO_SPEED:
		_prep_t0 -= 100.0      # 空白鍵跳過示範
		tau = 1e9
	if tau > t_end + DEMO_HOLD * DEMO_SPEED or tau < 0.0:
		if _demo_caption_text != "" and _demo_caption_text != "換你了！":
			_demo_caption_text = "換你了！"
			toast(_demo_caption_text, 2.0)
		return
	_demo_playing = true
	var tt := minf(tau, t_end)
	# 畫面上只有：兩個半透明的分身、示範用的香蕉皮、下面一行字
	var pa: Vector3
	if tt < t_step:
		pa = (ra[0] as Vector3) + dir * (tt * RUSH_SPEED)
	else:
		pa = (ra[0] as Vector3) + dir * (step_d + (tt - t_step) * SLIDE_SPEED)
	var pb := _along(rb, tt * RUSH_SPEED)
	var pb2 := _along(rb, tt * RUSH_SPEED + 0.5)
	_show_ghost(a_f, pa, atan2(dir.x, dir.z), "run" if tt < t_step else "slide")
	_show_ghost(b_f, pb, _yaw_to(pb, pb2) if flat_dist(pb, pb2) > 0.05 else b_f.yaw, "run")
	if _demo_peel == null:
		_demo_peel = MeshInstance3D.new()
		_demo_peel.mesh = prop_mesh("banana_peel")
		_demo_peel.scale = Vector3.ONE * PEEL_K
		_demo_peel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		world.add_child(_demo_peel)
	_demo_peel.visible = tt < t_step + 0.15
	_demo_peel.global_position = ground((ra[0] as Vector3) + dir * peel_d)
	_demo_caption("示範：%s太早滑過去，撞不到%s" % [a_f.name, b_f.name])

# ---------------------------------------------------------------- 美術：介面和 3D 字的底板（ui_skin.gd）

var _plated: Array = []

## 共用介面（字卡、上方提示、結算、失敗說明）在這一關換成冰釣手帳風格（只改執行時的外觀，不改共用檔案）
func _skin_hud() -> void:
	UISkin.use_theme("ice")
	if _toast_label:
		UISkin.pill(_toast_label)
	if _phase_label:
		UISkin.pill(_phase_label, Color(0.1, 0.13, 0.2, 0.78), Color(1, 1, 1, 0.4), Color(1, 1, 1))
	_skin_summary()
	if _defeat_detail:
		UISkin.use_font(_defeat_detail, -1, Color(1, 0.97, 0.9))
	for f in enemies:
		var l: Label3D = _intents.get(f)
		if l:
			l.font_size = 44                 # 牌子小一號：資訊在，但不搶畫面
			_plate(l, "wood")
	for l in _ends:
		l.font_size = 44
		_plate(l, "bubble")
	if _bird_tag:
		_plate(_bird_tag, "yellow")
	var cl = world.get("_cage_label")
	if cl:
		_plate(cl, "red")

func _plate(l: Label3D, kind: String) -> void:
	if l == null or l.has_meta("plate_kind"):
		return
	UISkin.plate(l, kind)
	_plated.append(l)

func _refresh_plates() -> void:
	for i in range(_plated.size() - 1, -1, -1):
		var l = _plated[i]
		if not is_instance_valid(l):
			_plated.remove_at(i)
			continue
		UISkin.refresh(l)

## 結算面板換成筆記紙（共用程式每次打開會重設樣式，所以打開時再套一次）
func _skin_summary() -> void:
	if _summary_panel == null:
		return
	var s := UISkin._box(UISkin.PAPER, UISkin.PAPER_EDGE, 6, 3)
	s.content_margin_left = 50
	s.content_margin_right = 38
	s.content_margin_top = 30
	s.content_margin_bottom = 28
	_summary_panel.add_theme_stylebox_override("panel", s)
	_summary_panel.rotation = 0.012
	for l in _summary_panel.find_children("*", "Label", true, false):
		UISkin.use_font(l as Label, -1, UISkin.INK)
		(l as Label).add_theme_constant_override("outline_size", 0)
	for r in _summary_panel.find_children("*", "RichTextLabel", true, false):
		var f := UISkin.font()
		if f:
			(r as RichTextLabel).add_theme_font_override("normal_font", f)
		(r as RichTextLabel).add_theme_color_override("default_color", UISkin.INK)

var _demo_done_t := -1.0
var _demo_caption_text := ""

## 示範的字卡放在畫面下方（不壓在路線上）
func _demo_caption(t: String) -> void:
	if t != _demo_caption_text:
		_demo_caption_text = t
		toast(t, 0.6)
	elif _toast_until - _clock < 0.3:
		toast(t, 0.6)

# ---------------------------------------------------------------- 美術第二輪：結算卡

## 結算卡：三顆大星、三行條件、按鈕（不放除錯資訊）
func _show_summary() -> void:
	if outcome != "win":
		super()
		return
	if _card and is_instance_valid(_card):
		_card.queue_free()
	_summary_label.visible = false
	var best := _best()
	var list := _checklist()
	var got_n: int = list.filter(func(c): return best.has(c.id)).size()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	_card = v
	_summary_panel.add_child(v)
	# 三顆大星：拿到幾顆就從左邊亮幾顆（沒拿到的＝同樣的外框、紙色的底）
	var stars := HBoxContainer.new()
	stars.alignment = BoxContainer.ALIGNMENT_CENTER
	stars.add_theme_constant_override("separation", 16)
	v.add_child(stars)
	for i in list.size():
		var st := Label.new()
		st.text = "★"
		st.label_settings = UISkin.ls(78, Color("f6c445") if i < got_n else Color("f4ebd3"), 10, UISkin.INK)
		stars.add_child(st)
	# 每個條件一行，前面一顆小星星；沒拿到的提示要過關兩次以後才給（先讓玩家自己想）
	var wins: int = win_count.get(_stage_key(), 0)
	for c in list:
		var got: bool = best.has(c.id)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		v.add_child(row)
		var mk := Label.new()
		mk.text = "★"
		mk.label_settings = UISkin.ls(24, Color("f6c445") if got else Color("f4ebd3"), 6, UISkin.INK if got else Color(UISkin.INK, 0.4))
		row.add_child(mk)
		var txt := Label.new()
		txt.text = String(c.text)
		txt.label_settings = UISkin.ls(24, UISkin.INK if got else Color(UISkin.INK, 0.5))
		row.add_child(txt)
		if not got and wins >= 2 and String(c.get("hint", "")) != "":
			var hint_l := Label.new()
			hint_l.text = "　　 " + String(c.hint)
			hint_l.label_settings = UISkin.ls(17, Color(UISkin.INK, 0.55))
			v.add_child(hint_l)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 6)
	v.add_child(gap)
	var btns := HBoxContainer.new()
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	btns.add_theme_constant_override("separation", 10)
	v.add_child(btns)
	var go := Label.new()
	go.text = "下一關 ▶"
	go.label_settings = UISkin.ls(26, Color(1, 1, 1))
	UISkin.pill(go, Color("58b85a"), Color("2f7a33"), Color(1, 1, 1))
	btns.add_child(go)
	btns.add_child(_keycap("Enter"))
	_key_hint(btns, "R", "重來")
	_key_hint(btns, "M", "地圖")
	_summary_panel.visible = true

## 鍵帽：白底、深色邊、底邊厚一點的小方塊
func _keycap(key: String) -> Label:
	var l := Label.new()
	l.text = key
	l.label_settings = UISkin.ls(18, UISkin.INK)
	var s := StyleBoxFlat.new()
	s.bg_color = Color(1, 1, 1)
	s.border_color = UISkin.INK
	s.set_border_width_all(2)
	s.border_width_bottom = 5
	s.set_corner_radius_all(7)
	s.content_margin_left = 10
	s.content_margin_right = 10
	s.content_margin_top = 3
	s.content_margin_bottom = 4
	l.add_theme_stylebox_override("normal", s)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return l

func _key_hint(parent: Control, key: String, text: String) -> void:
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(12, 0)
	parent.add_child(sp)
	parent.add_child(_keycap(key))
	var t := Label.new()
	t.text = text
	t.label_settings = UISkin.ls(20, UISkin.INK)
	parent.add_child(t)

var _defeat_card: Control
## 每一關過關幾次（這次開遊戲期間）：過關兩次以後，結算卡才給沒拿到的星星的提示
static var win_count := {}

# ---------------------------------------------------------------- 美術第三輪：工人換成 Q 版大頭小人（Kenney Mini Characters，CC0）
#
# 模型只有 7 個零件（root、兩條腿、身體、兩隻手、頭），原本的臉是兩個小黑點。這裡在載入時改造一次：
#   換配色（安全帽、工作服一人一色）→ 拿掉小黑點臉 → 貼上大眼睛的表情 → 帽子拆成獨立零件（往後斜戴、可以被雪人頭換掉）
# 跑、站用模型自己的動畫；滑倒、坐著、泡冰洞、倒栽、拎家豪這些姿勢用程式直接擺骨頭（mini_pose）。

const MINI_DIR := "res://levels/ice/assets/kenney_mini/"
const MODEL_WORKER := MINI_DIR + "character-worker.glb"
const MODEL_GUARD := MINI_DIR + "character-male-c.glb"
const COLORMAP := MINI_DIR + "Textures/colormap.png"

## 每個人的造型（帽子是從上面看最顯眼的地方：一人一色；阿水不用藍色，藍色黃昏關才看得到）
const LOOKS := {
	"工人": {"hat": Color("ffcf33"), "hat2": Color("ffe27a"), "suit": Color("f07f2b"), "skin": Color("f6c7a0"), "hair": Color("5b3a29")},
	"阿土": {"hat": Color("ff8a1f"), "hat2": Color("ffb45e"), "suit": Color("7a9a3a"), "skin": Color("e8a878"), "hair": Color("3a2a22")},
	"阿水": {"hat": Color("ff5fa2"), "hat2": Color("ff9cc6"), "suit": Color("8a5bd1"), "skin": Color("f8d2b0"), "hair": Color("7a4a2a")},
	"守衛": {"hat": Color("27406b"), "visor": Color("16223d"), "badge": Color("ffd23f"), "suit": Color("d63b3b"), "dark": Color("2c3350"),
		"skin": Color("f2bb93"), "hair": Color("4a3024")},
}
const LOOK_SHARED := {"belt": Color("6b4a35"), "boot": Color("5a4638"), "button": Color("fff4d6")}

## 調色盤上哪一格是什麼（欄, 列）：模型名稱 → 零件 → 格子 → 角色
const MINI_ROLES := {
	"character-worker": {
		"body-mesh": {"1,1": "suit", "1,2": "belt", "1,3": "boot", "3,2": "skin", "5,3": "button"},
		"head-mesh": {"0,3": "hat2", "1,3": "hat", "3,2": "skin", "7,3": "hair"},
	},
	"character-male-c": {
		"body-mesh": {"1,1": "suit", "1,3": "badge", "5,2": "skin", "7,3": "dark"},
		"head-mesh": {"1,1": "hat", "1,3": "badge", "1,2": "hair", "5,2": "skin", "7,3": "dark"},
	},
}
const HAT_PIVOT := Vector3(0, 0.6, 0.0)     # 帽子往後斜戴時繞著轉的點（模型自己的座標）
const HAT_TILT := 0.2                       # 往後斜多少（露出眼睛：鏡頭從上面往下看，帽簷才不會把臉蓋住）
const FACE_INK := Color("2e1c16")           # 模型自己的眼睛、嘴巴的顏色（跟手繪表情的線條同一個深咖啡色）
const FACE_SIZE := 0.39                     # 表情貼片的邊長（模型自己的座標；頭寬 0.32）
const FACE_AT := Vector3(0, 0.137, 0.1752)  # 貼片中心（相對於頭骨）：貼在臉的正前方
const HAND_AT := Vector3(-0.27, -0.02, 0.02) # 右手掌心（相對於右手骨）
const SINK_SHOW := 0.27                      # 泡在冰洞裡：水面在模型的這個高度（肩膀；只剩頭和肩膀露出來）

## 手繪的表情（Codex 生成的 PNG）只有三張：嚇到、暈、凍僵。其他時候用模型自己的臉。
const FACES := {
	"shock": "res://levels/ice/assets/faces/face_shock.png",
	"dizzy": "res://levels/ice/assets/faces/face_dizzy.png",
	"frozen": "res://levels/ice/assets/faces/face_frozen.png",
}

static var _mini_cache := {}        # 改造好的網格（同一種造型共用）
static var _mini_shader: Shader
static var _mini_pal: Image
static var _face_tex := {}

var _rigs := {}                     # 工人 -> {skel, bones, hat, mat, face, face_mat}
var _ghosts := {}                   # 工人 -> 半透明的分身（第 3 關看時機用）
var _ghost_used := {}
var _chips := {}                    # 工人 -> 滑行時腳邊噴的冰屑

## 卡通材質：頂點色、柔和的兩階光影；frost＝結霜（只蓋在朝上的面：帽頂、肩膀，衣服顏色還看得出來）
## 不吃場景的環境光（藍色的環境光會把膚色、橘色洗成灰色）：暗面用 amb 補，只帶一點點場景的色調
static func _mini_toon() -> Shader:
	if _mini_shader == null:
		_mini_shader = Shader.new()
		_mini_shader.code = """
shader_type spatial;
render_mode specular_disabled, ambient_light_disabled;
uniform float frost = 0.0;
uniform vec3 frost_color : source_color = vec3(0.86, 0.95, 1.0);
uniform vec3 amb = vec3(0.42, 0.44, 0.48);
varying float up;
void vertex() {
	up = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz).y;
}
void fragment() {
	vec3 c = COLOR.rgb;
	c = mix(pow((c + 0.055) / 1.055, vec3(2.4)), c / 12.92, lessThan(c, vec3(0.04045)));
	float f = frost * (0.04 + 0.96 * smoothstep(0.3, 0.85, up));
	c = mix(c, frost_color, f);
	ALBEDO = c;
	ROUGHNESS = 1.0;
	EMISSION = c * amb;
}
void light() {
	float ndl = dot(NORMAL, LIGHT);
	float t = smoothstep(-0.12, 0.18, ndl) * 0.8 + clamp(ndl, 0.0, 1.0) * 0.2;
	DIFFUSE_LIGHT += t * ATTENUATION * LIGHT_COLOR / PI;
}
"""
	return _mini_shader

static func _mini_palette() -> Image:
	if _mini_pal == null:
		var tex := load(COLORMAP) as Texture2D
		_mini_pal = tex.get_image() if tex else null
		if _mini_pal == null or _mini_pal.is_empty():
			_mini_pal = Image.create(16, 4, false, Image.FORMAT_RGBA8)     # 拿不到調色盤（沒有畫面的測試模式）：用空白的頂著
			_mini_pal.fill(Color(0.8, 0.8, 0.8))
		elif _mini_pal.is_compressed():
			_mini_pal.decompress()
	return _mini_pal

## 表情貼圖（縮成 512、加 mipmap：遠看不閃）
static func face_texture(kind: String) -> Texture2D:
	if not _face_tex.has(kind):
		var src := load(FACES[kind]) as Texture2D
		var img := src.get_image() if src else null
		if img == null or img.is_empty():
			_face_tex[kind] = src
			return src
		if img.is_compressed():
			img.decompress()
		img.convert(Image.FORMAT_RGBA8)
		img.resize(512, 512, Image.INTERPOLATE_LANCZOS)
		img.generate_mipmaps()
		_face_tex[kind] = ImageTexture.create_from_image(img)
	return _face_tex[kind]

## 把剛載入的 Kenney 小人改造成這一關的角色。回傳之後擺姿勢、換表情要用的東西。
static func style_mini(wrapper: Node3D, look: Dictionary, look_id: String) -> Dictionary:
	var sk := wrapper.find_child("Skeleton3D", true, false) as Skeleton3D
	if sk == null:
		return {}
	var model_key := String(wrapper.get_meta("source", "")).get_file().get_basename()
	var roles: Dictionary = MINI_ROLES.get(model_key, {})
	var mat := ShaderMaterial.new()
	mat.shader = _mini_toon()
	var rig := {"skel": sk, "bones": {}, "hat": null, "face0": null, "mat": mat}
	for b in sk.get_bone_count():
		rig.bones[sk.get_bone_name(b)] = b
	for n in sk.find_children("*", "MeshInstance3D", false, false):
		var mi := n as MeshInstance3D
		var part := String(mi.name)
		var key := "%s|%s|%s" % [model_key, part, look_id]
		if not _mini_cache.has(key):
			_mini_cache[key] = _restyle_mesh(mi.mesh, roles.get(part, {}), look, part.begins_with("head"))
		var built: Dictionary = _mini_cache[key]
		mi.mesh = built.main
		mi.material_override = mat
		if built.hat != null:
			var hat := MeshInstance3D.new()
			hat.name = "Hat"
			hat.mesh = built.hat
			hat.skin = mi.skin
			hat.material_override = mat
			sk.add_child(hat)
			rig.hat = hat
		if built.face0 != null:
			# 模型自己的眼睛、嘴巴：獨立一個零件，貼手繪表情時收起來
			var f0 := MeshInstance3D.new()
			f0.name = "Face0"
			f0.mesh = built.face0
			f0.skin = mi.skin
			f0.material_override = mat
			f0.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			sk.add_child(f0)
			rig.face0 = f0
	# 手繪表情（嚇到、暈、凍僵）：一張貼片掛在頭骨上（跟著頭轉、低頭；背面看不到），平常收起來
	var ba := BoneAttachment3D.new()
	ba.name = "FaceAt"
	sk.add_child(ba)
	ba.bone_name = "head"
	var face := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(FACE_SIZE, FACE_SIZE)
	face.mesh = q
	face.position = FACE_AT
	face.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	fm.alpha_scissor_threshold = 0.5
	fm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	fm.albedo_color = Color(0.97, 0.96, 0.94)
	face.material_override = fm
	face.visible = false
	ba.add_child(face)
	rig.face = face
	rig.face_mat = fm
	rig.face_kind = ""
	return rig

## 一個零件的改造：重新上色（頂點色）、模型自己的眼睛嘴巴拆成獨立零件、帽子也拆出去
static func _restyle_mesh(src: Mesh, roles: Dictionary, look: Dictionary, is_head: bool) -> Dictionary:
	var arr := src.surface_get_arrays(0)
	var fmt: int = (src as ArrayMesh).surface_get_format(0)
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var uvs: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var pal := _mini_palette()
	var cols := PackedColorArray()
	cols.resize(verts.size())
	var done := PackedByteArray()
	done.resize(verts.size())
	var in_hat := PackedByteArray()
	in_hat.resize(verts.size())
	var main_idx := PackedInt32Array()
	var hat_idx := PackedInt32Array()
	var face_idx := PackedInt32Array()
	for t in range(0, idx.size(), 3):
		var tri := [idx[t], idx[t + 1], idx[t + 2]]
		var uvc: Vector2 = (uvs[tri[0]] + uvs[tri[1]] + uvs[tri[2]]) / 3.0
		var cell := "%d,%d" % [int(uvc.x * 16.0), int(uvc.y * 4.0)]
		var role: String = roles.get(cell, "")
		var is_hat := false
		if is_head:
			# 模型自己的眼睛、嘴巴：貼在臉正前方的深色小薄片，拆成獨立零件（顏色照原本的）
			var sticker := cell == "7,3"
			var low := 9.0
			for v in tri:
				var p: Vector3 = verts[v]
				low = minf(low, p.y)
				if p.z < 0.1595 or p.y > 0.52 or absf(p.x) > 0.11:
					sticker = false
			if sticker:
				for v in tri:
					if done[v] == 0:
						done[v] = 1
						cols[v] = FACE_INK
				face_idx.append_array(tri)
				continue
			if role == "dark" and low >= 0.55:
				role = "visor"
			is_hat = role in ["hat", "hat2", "badge", "visor"]
		for v in tri:
			if done[v] == 0:
				done[v] = 1
				cols[v] = _mini_color(pal, _cell_uv(uvs[v], uvc), role, look)
				in_hat[v] = 1 if is_hat else 0
		if is_hat:
			hat_idx.append_array(tri)
		else:
			main_idx.append_array(tri)
	# 帽子往後斜戴一點、放大一點點
	var tilt := Basis(Vector3.RIGHT, -float(look.get("hat_tilt", HAT_TILT)))
	var grow: float = look.get("hat_scale", 1.06)
	for v in verts.size():
		if in_hat[v] == 1:
			verts[v] = HAT_PIVOT + tilt * ((verts[v] - HAT_PIVOT) * grow)
			norms[v] = tilt * norms[v]
	var out := {"main": _mini_mesh(arr, fmt, verts, norms, cols, main_idx), "hat": null, "face0": null}
	if not hat_idx.is_empty():
		out.hat = _mini_mesh(arr, fmt, verts, norms, cols, hat_idx)
	if not face_idx.is_empty():
		out.face0 = _mini_mesh(arr, fmt, verts, norms, cols, face_idx)
	return out

## 頂點在調色盤上的位置：左右用三角形中心那一格（不會踩到交界），上下留在同一列裡（保留漸層）
static func _cell_uv(uv: Vector2, center: Vector2) -> Vector2:
	var row0 := floorf(center.y * 4.0) / 4.0
	return Vector2(center.x, clampf(uv.y, row0 + 0.006, row0 + 0.244))

static func _mini_mesh(arr: Array, fmt: int, verts: PackedVector3Array, norms: PackedVector3Array, cols: PackedColorArray, idx: PackedInt32Array) -> ArrayMesh:
	var a := []
	a.resize(Mesh.ARRAY_MAX)
	a[Mesh.ARRAY_VERTEX] = verts
	a[Mesh.ARRAY_NORMAL] = norms
	a[Mesh.ARRAY_COLOR] = cols
	a[Mesh.ARRAY_BONES] = arr[Mesh.ARRAY_BONES]
	a[Mesh.ARRAY_WEIGHTS] = arr[Mesh.ARRAY_WEIGHTS]
	a[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a, [], {}, fmt & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS)
	return m

## 新顏色：保留調色盤那一格「由上到下變深」的漸層，只是換成造型表的顏色
static func _mini_color(pal: Image, uv: Vector2, role: String, look: Dictionary) -> Color:
	var x := clampi(int(uv.x * pal.get_width()), 0, pal.get_width() - 1)
	var y := clampi(int(uv.y * pal.get_height()), 0, pal.get_height() - 1)
	var target = look.get(role, LOOK_SHARED.get(role))
	if target == null:
		return pal.get_pixel(x, y)
	var row_h := pal.get_height() / 4
	var y0 := (y / row_h) * row_h
	var top := pal.get_pixel(x, y0 + 3)
	var bot := pal.get_pixel(x, y0 + row_h - 4)
	var t := clampf(float(y - y0) / float(row_h), 0.0, 1.0)
	var c: Color = target
	return Color(c.r * lerpf(1.0, clampf(bot.r / maxf(top.r, 0.05), 0.5, 1.1), t),
		c.g * lerpf(1.0, clampf(bot.g / maxf(top.g, 0.05), 0.5, 1.1), t),
		c.b * lerpf(1.0, clampf(bot.b / maxf(top.b, 0.05), 0.5, 1.1), t))

## 程式擺的姿勢：骨頭 → 轉幾度（弧度，Vector3＝繞 X、Y、Z）。沒寫的骨頭就是原本的 T 字站姿。
## 模型面向 +Z；左手在 +X。手：繞 Z 是上下（左手負的往下）、繞 Y 是前後；腳：繞 X 負的往前踢；身體：繞 X 負的往後仰。
static func mini_pose(kind: String, t: float) -> Dictionary:
	match kind:
		"slide":
			# 踩到香蕉皮：屁股著地往前滑，兩手在空中亂揮、兩腳輪流亂踢
			return {
				"torso": Vector3(-0.2 + sin(t * 17.0) * 0.07, 0, sin(t * 9.0) * 0.1),
				"head": Vector3(0.35 + sin(t * 23.0) * 0.05, 0, 0),
				"arm-left": Vector3(0, sin(t * 13.0) * 0.5, 0.95 + sin(t * 21.0) * 0.55),
				"arm-right": Vector3(0, sin(t * 15.0) * 0.5, -0.95 - sin(t * 21.0 + 2.1) * 0.55),
				"leg-left": Vector3(-1.15 + sin(t * 19.0) * 0.5, 0, 0.22),
				"leg-right": Vector3(-1.15 - sin(t * 19.0) * 0.5, 0, -0.22),
			}
		"dizzy":
			# 撞到雪人：一屁股坐在地上，頭轉圈圈
			return {
				"torso": Vector3(0.05, 0, sin(t * 6.0) * 0.1),
				"head": Vector3(cos(t * 6.0) * 0.16, 0, sin(t * 6.0) * 0.22),
				"arm-left": Vector3(0, 0.25, -1.05),
				"arm-right": Vector3(0, -0.25, 1.05),
				"leg-left": Vector3(-1.5, 0.3, 0),
				"leg-right": Vector3(-1.5, -0.3, 0),
			}
		"tired":
			# 追不上了：坐著喘氣，肩膀一上一下
			var puff := sin(t * 7.0)
			return {
				"torso": Vector3(0.22 + puff * 0.06, 0, 0),
				"head": Vector3(0.18 - puff * 0.08, 0, 0),
				"arm-left": Vector3(0, 0.5, -0.95 + puff * 0.06),
				"arm-right": Vector3(0, -0.5, 0.95 - puff * 0.06),
				"leg-left": Vector3(-1.5, 0.35, 0),
				"leg-right": Vector3(-1.5, -0.35, 0),
			}
		"sunk":
			# 泡在冰洞裡：兩手扒著水面發抖
			var sh := sin(t * 55.0) * 0.07
			return {
				"torso": Vector3(0, 0, sh * 0.3),
				"head": Vector3(-0.12, 0, sin(t * 47.0) * 0.05),
				"arm-left": Vector3(0, -0.5, 0.22 + sh),
				"arm-right": Vector3(0, 0.5, -0.22 + sh),
			}
		"pile":
			# 倒栽在雪堆裡：只剩兩條腿在外面亂踢
			return {
				"leg-left": Vector3(sin(t * 11.0) * 0.75, 0, 0.25),
				"leg-right": Vector3(-sin(t * 11.0) * 0.75, 0, -0.25),
				"arm-left": Vector3(0, 0, 1.2),
				"arm-right": Vector3(0, 0, -1.2),
			}
		"cheer":
			# 同伴抓到家豪了：兩手舉高一跳一跳
			var hop := absf(sin(t * 7.0))
			return {
				"torso": Vector3(-0.05, 0, sin(t * 7.0) * 0.06),
				"arm-left": Vector3(0, 0, 0.9 + hop * 0.35),
				"arm-right": Vector3(0, 0, -0.9 - hop * 0.35),
				"leg-left": Vector3(0, 0, 0.12),
				"leg-right": Vector3(0, 0, -0.12),
			}
		"hold":
			# 抓到家豪：右手往旁邊舉高，拎著他的帽 T；左手叉腰
			var bob := sin(t * 5.0) * 0.05
			return {
				"torso": Vector3(-0.06, 0.0, 0.06),
				"head": Vector3(0, -0.25, 0.06),
				"arm-right": Vector3(0, 0.05, -0.82 + bob * 0.6),
				"arm-left": Vector3(0, -0.25, -1.0),
			}
	return {}

static func pose_mini(rig: Dictionary, pose: Dictionary) -> void:
	var sk: Skeleton3D = rig.skel
	for bone in rig.bones:
		var bi: int = rig.bones[bone]
		sk.set_bone_pose_rotation(bi, Quaternion.from_euler(pose.get(bone, Vector3.ZERO)))
		sk.set_bone_pose_position(bi, sk.get_bone_rest(bi).origin)

## 某根骨頭上的一個點在世界上的位置
static func mini_point(rig: Dictionary, bone: String, local: Vector3) -> Vector3:
	var sk: Skeleton3D = rig.skel
	return sk.global_transform * (sk.get_bone_global_pose(int(rig.bones[bone])) * local)

# ---- 以下是戰局裡怎麼用這些小人

## 共用程式照 _enemy_specs() 生出模型之後：換造型、設定哪些動畫要循環
func _setup_mini(f: Fighter, _i: int) -> void:
	var id := f.name if LOOKS.has(f.name) else ("守衛" if f.get_meta("guard", false) else "工人")
	var rig := style_mini(f.node, LOOKS[id], id)
	if rig.is_empty():
		return
	rig.unit = (rig.skel as Skeleton3D).global_transform.basis.get_scale().y   # 模型的 1 單位是幾公尺
	_rigs[f] = rig
	if f.anim:
		for a in ["idle", "walk", "sprint"]:
			if f.anim.has_animation(a):
				f.anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR

## 共用程式用農夫模型的動畫名字（Idle、Run…）：換成小人的動畫
const ANIM_MAP := {"Idle": "idle", "Run": "sprint", "Walk": "walk", "Death": "die", "HitRecieve": "fall",
	"Interact": "holding-right", "Wave": "emote-yes"}

func anim(f: Fighter, name: String, speed := 1.0) -> void:
	if not _rigs.has(f):
		super(f, name, speed)
		return
	var n: String = ANIM_MAP.get(name, name)
	if f.anim == null or not f.anim.has_animation(n):
		return
	if f.anim.current_animation != n or not f.anim.is_playing():
		f.anim.play(n, 0.12, speed)

## 這個人現在該擺哪個姿勢（""＝播模型自己的動畫）和哪個表情（""＝模型自己的臉；手繪的只有嚇到、暈、凍僵）
func _mini_state(f: Fighter) -> Array:
	var caught: bool = bird.state == "lifted" or bird.data.get("held", false)
	if f == _catcher and caught:
		return ["hold", ""]
	if f.data.get("pile") != null:
		return ["pile", ""]
	if f.data.get("sunk", false):
		return ["sunk", "frozen"]
	if caught and f.alive():
		return ["cheer", ""]
	if not f.alive():
		return ["dizzy", "dizzy"]
	match f.state:
		"kslide", "slip":
			return ["slide", "shock"]
		"stunned":
			return ["dizzy", "dizzy"]
		"giveup":
			return ["tired", ""]
	return ["", ""]

## 姿勢：滑倒、坐著、泡冰洞、倒栽、拎家豪用程式擺；其他播模型的動畫。表情跟著狀態換。
func _level_visuals() -> void:
	super()
	var vcam := get_viewport().get_camera_3d() if is_inside_tree() else null
	for f in enemies:
		var rig = _rigs.get(f)
		if rig == null:
			continue
		var st := _mini_state(f)
		var kind: String = st[0]
		var u: float = rig.unit
		_set_face(rig, st[1])
		var hat = f.data.get("snow_hat")
		var has_snow: bool = hat != null and is_instance_valid(hat)
		if rig.hat:
			(rig.hat as Node3D).visible = not has_snow     # 雪人頭扣上來：安全帽被撞掉了
		_chip_fx(f, f.alive() and f.state == "kslide" and phase == Phase.RUNNING)
		if kind == "":
			if f.anim and not f.anim.is_playing() and f.anim.current_animation != "":
				f.anim.play()      # 從程式擺的姿勢回到模型的動畫
			_update_stars(f, false)
			continue
		if f.anim and f.anim.is_playing():
			f.anim.pause()
		var pose := mini_pose(kind, _clock)
		if kind == "sunk":
			for o in enemies:
				if o != f and o.data.get("sunk", false) and flat_dist(o.pos, f.pos) < 2.4:
					# 同一個洞泡兩個：靠同伴的那隻手垂在水裡，不要插進對方身體（照現在面對的方向算哪一隻）
					var loc: Vector3 = Basis(Vector3.UP, f.yaw).inverse() * (o.pos - f.pos)
					var arm := "arm-left" if loc.x > 0.0 else "arm-right"
					pose[arm] = Vector3(0, 0, 1.3 if arm == "arm-right" else -1.3)
		var yaw: float = f.yaw
		match kind:
			"slide":
				# 腳朝前、屁股著地滑出去（看的是滑行方向，不是他原本面對的方向）
				var sd: Vector3 = f.data.get("sdir", Vector3(sin(f.yaw), 0, cos(f.yaw)))
				yaw = atan2(sd.x, sd.z)
				f.data.vis_yaw = yaw
				f.node.global_position = f.pos + Vector3(0, f.air - 0.07 * u, 0)
				f.node.rotation = Vector3(-0.4, yaw, sin(_clock * 16.0) * 0.12)
			"dizzy", "tired":
				if kind == "dizzy":
					yaw = float(f.data.get("vis_yaw", f.yaw))
				f.node.global_position = f.pos + Vector3(0, f.air - 0.12 * u, 0)
				f.node.rotation = Vector3(-0.08, yaw, 0.0)
			"sunk":
				f.node.global_position += Vector3(sin(_clock * 63.0) * 0.03, 0, 0)   # 凍得發抖
			"cheer":
				f.node.global_position = f.pos + Vector3(0, f.air + absf(sin(_clock * 7.0)) * 0.25, 0)
			"pile":
				f.node.global_position = (f.data.pile as Vector3) + Vector3(0, 0.42 * u, 0)
				f.node.rotation = Vector3(PI, f.yaw, sin(_clock * 11.0) * 0.08)
		# 頭轉向鏡頭、抬頭看鏡頭（帽簷才不會把表情蓋住；鏡頭在高處時特別需要）
		if vcam and kind in ["slide", "dizzy", "tired", "sunk", "hold", "cheer"]:
			var to_cam: Vector3 = f.node.global_basis.orthonormalized().inverse() * (vcam.global_position - head_pos(f))
			var look := clampf(atan2(to_cam.x, to_cam.z), -1.1, 1.1) * 0.85
			var up_a := clampf(atan2(to_cam.y, Vector2(to_cam.x, to_cam.z).length()), -0.2, 0.75) * 0.75
			var h: Vector3 = pose.get("head", Vector3.ZERO)
			var tor: Vector3 = pose.get("torso", Vector3.ZERO)
			pose["head"] = Vector3(-up_a - tor.x, h.y + look, h.z)
		pose_mini(rig, pose)
		_update_stars(f, f.alive() and f.state == "stunned" and phase != Phase.ENDED)
	_separate_pairs(vcam)

func _set_face(rig: Dictionary, kind: String) -> void:
	var face: MeshInstance3D = rig.face
	face.visible = kind != ""
	if rig.face0:
		(rig.face0 as Node3D).visible = kind == ""      # 貼手繪表情時，模型自己的小眼睛收起來
	if kind == "" or rig.face_kind == kind:
		return
	rig.face_kind = kind
	(rig.face_mat as StandardMaterial3D).albedo_texture = face_texture(kind)

## 滑行時腳邊噴出來的冰屑（小碎冰，照遊戲時間飛：慢動作、截圖都對得上）
func _chip_fx(f: Fighter, on: bool) -> void:
	if not on or silent or not world.on_ice(f.pos.x, f.pos.z):
		return
	var last: float = f.data.get("chip_t", -1.0)
	if _clock - last < 0.035:
		return
	f.data.chip_t = _clock
	if _chip_mesh == null:
		_chip_mesh = prop_mesh("fx_shard")
		_chip_mat = _fx_mat("ice")
		_chip_rng.seed = 20261113
	var sd: Vector3 = f.data.get("sdir", Vector3.FORWARD)
	var side := sd.cross(Vector3.UP)
	for k in 2:
		var mi := MeshInstance3D.new()
		mi.mesh = _chip_mesh
		mi.material_override = _chip_mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		fx_root.add_child(mi)
		mi.global_position = f.pos + sd * 0.5 + side * _chip_rng.randf_range(-0.5, 0.5) + Vector3(0, 0.08, 0)
		mi.rotation = Vector3(_chip_rng.randf() * TAU, _chip_rng.randf() * TAU, _chip_rng.randf() * TAU)
		mi.scale = Vector3.ONE * _chip_rng.randf_range(0.7, 1.5)
		var vel := sd * _chip_rng.randf_range(0.5, 2.5) + side * _chip_rng.randf_range(-2.6, 2.6) + Vector3(0, _chip_rng.randf_range(2.2, 4.6), 0)
		_chip_list.append({"node": mi, "vel": vel, "t": 0.0, "life": 0.6})

var _chip_mesh: Mesh
var _chip_mat: StandardMaterial3D
var _chip_rng := RandomNumberGenerator.new()
var _chip_list: Array = []

func _tick_chips(dt: float) -> void:
	for i in range(_chip_list.size() - 1, -1, -1):
		var c: Dictionary = _chip_list[i]
		var n = c.node
		c.t += dt
		if not is_instance_valid(n) or c.t > float(c.life):
			if is_instance_valid(n):
				n.queue_free()
			_chip_list.remove_at(i)
			continue
		c.vel += Vector3(0, -13.0, 0) * dt
		(n as Node3D).position += (c.vel as Vector3) * dt
		if c.get("drop", false):
			continue        # 水滴不轉、不縮（尖端朝上飛出去再掉下來）
		(n as Node3D).rotate_x(dt * 9.0)
		(n as Node3D).scale *= 1.0 - dt * 1.2

## 頭頂（不含帽子）：照頭骨算，坐下、後仰、倒栽都跟得上
func head_pos(f: Fighter) -> Vector3:
	var rig = _rigs.get(f)
	if rig == null:
		return f.pos + Vector3(0, HAT_Y - 0.42 + f.air, 0)
	return mini_point(rig, "head", Vector3(0, 0.3, 0))

## 帽頂上方（跳字、星星放這裡，不會蓋到臉）
func top_pos(f: Fighter) -> Vector3:
	var rig = _rigs.get(f)
	if rig == null:
		return f.pos + Vector3(0, 3.0 + f.air, 0)
	var p := mini_point(rig, "head", Vector3(0, 0.16, 0))
	return p + Vector3(0, 0.36 * float(rig.unit) + (0.12 if f.data.get("snow_hat") != null else 0.0), 0)

## 右手掌心（拎家豪用）
func hand_pos(f: Fighter):
	var rig = _rigs.get(f)
	if rig == null:
		return null
	return mini_point(rig, "arm-right", HAND_AT)

## 泡在冰水裡：帽頂、肩膀結一層霜（衣服顏色還看得出來是誰）
func _set_frost(f: Fighter, on: bool) -> void:
	var rig = _rigs.get(f)
	if rig == null:
		return
	(rig.mat as ShaderMaterial).set_shader_parameter("frost", 0.6 if on else 0.0)

## 雪人的頭扣在工人頭上：放大到蓋得住整個頭頂，跟著頭一起歪
func _wear_snow_head(f: Fighter, hat: Node3D) -> void:
	var rig = _rigs.get(f)
	if rig == null:
		hat.global_position = head_pos(f) + Vector3(0, 0.3, 0)
		return
	var sk: Skeleton3D = rig.skel
	var hx: Transform3D = sk.global_transform * sk.get_bone_global_pose(int(rig.bones["head"]))
	var b := hx.basis.orthonormalized()
	hat.global_transform = Transform3D(b.scaled(Vector3.ONE * SNOW_HEAD_K), hx.origin + b.y * (0.33 * float(rig.unit)))

const SNOW_HEAD_K := 1.9      # 雪人頭戴在大頭小人頭上要放大（不然像一顆小雪球）
const PAIR_HALF := 0.74       # 同一個洞泡兩個人：各往左右讓開多少
const PAIR_GAP := 1.7         # 兩個人在畫面上至少隔這麼遠（不然兩個大頭會疊成一個）
const PAIR_GAP_SLIDE := 2.5   # 兩個人一起往後躺著滑：隔更開

## 小人的暗面補光：亮度跟著場景的環境光，色調只跟四成（早晨、夕陽、藍色黃昏都融得進去，但膚色不會變灰）
func _update_mini_light() -> void:
	var a := Color(0.62, 0.7, 0.85)
	var env_node := get_node_or_null("../WorldEnvironment") as WorldEnvironment
	if env_node and env_node.environment:
		a = env_node.environment.ambient_light_color * env_node.environment.ambient_light_energy
	var l := a.get_luminance()
	var t := Color(l, l, l).lerp(a, 0.4) * 0.62
	for f in _rigs:
		(_rigs[f].mat as ShaderMaterial).set_shader_parameter("amb", Vector3(t.r + 0.05, t.g + 0.05, t.b + 0.05))

## 兩個人疊在一起時（一起滑出去、撞在一起、圍著家豪），畫面上往鏡頭的左右各讓開一點。
## 只動模型，不動戰局裡的位置（玩法不變）。
func _separate_pairs(vcam: Camera3D) -> void:
	var want := {}
	if vcam:
		var cr := vcam.global_basis.x
		cr.y = 0.0
		cr = cr.normalized() if cr.length() > 0.01 else Vector3.RIGHT
		for i in enemies.size():
			for j in range(i + 1, enemies.size()):
				var a: Fighter = enemies[i]
				var b: Fighter = enemies[j]
				if a.data.get("sunk", false) or b.data.get("sunk", false) or a.data.get("pile") != null or b.data.get("pile") != null:
					continue
				var d: Vector3 = b.pos - a.pos
				d.y = 0.0
				var gap := PAIR_GAP_SLIDE if (a.state == "kslide" and b.state == "kslide") else PAIR_GAP
				if d.length() > gap:
					continue
				var s := d.dot(cr)
				var push := (gap - absf(s)) * 0.5
				var sgn := 1.0 if s >= 0.0 else -1.0
				want[a] = (want.get(a, Vector3.ZERO) as Vector3) - cr * push * sgn
				want[b] = (want.get(b, Vector3.ZERO) as Vector3) + cr * push * sgn
	for f in enemies:
		var cur: Vector3 = f.data.get("vis_off", Vector3.ZERO)
		cur = cur.lerp(want.get(f, Vector3.ZERO), 0.25)
		f.data.vis_off = cur
		if cur.length() > 0.01:
			f.node.global_position += cur

# ---------------------------------------------------------------- Blender 做的小零件：香蕉皮、星星、碎冰、水滴

const PROP_DIR := "res://levels/ice/assets/blender/"
static var _prop_cache := {}
static var _fx_mats := {}

static func prop_mesh(name: String) -> Mesh:
	if not _prop_cache.has(name):
		var m: Mesh = null
		var ps := load(PROP_DIR + name + ".glb") as PackedScene
		if ps:
			var n := ps.instantiate()
			var mis := n.find_children("*", "MeshInstance3D", true, false)
			if not mis.is_empty():
				m = (mis[0] as MeshInstance3D).mesh
			n.free()
		_prop_cache[name] = m
	return _prop_cache[name]

static func _fx_mat(kind: String) -> StandardMaterial3D:
	if not _fx_mats.has(kind):
		var m := StandardMaterial3D.new()
		match kind:
			"star":
				m.albedo_color = Color(1.0, 0.82, 0.16)
				m.emission_enabled = true
				m.emission = Color(1.0, 0.72, 0.1)
				m.emission_energy_multiplier = 0.7
				m.roughness = 0.6
			"ice":
				m.albedo_color = Color(0.9, 0.97, 1.0)
				m.emission_enabled = true
				m.emission = Color(0.55, 0.75, 0.95)
				m.emission_energy_multiplier = 0.5
				m.roughness = 0.4
			"drop":
				m.albedo_color = Color(0.86, 0.95, 1.0, 0.9)
				m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				m.emission_enabled = true
				m.emission = Color(0.6, 0.8, 1.0)
				m.emission_energy_multiplier = 0.4
				m.roughness = 0.3
		_fx_mats[kind] = m
	return _fx_mats[kind]

## 共用的香蕉皮是幾顆膠囊拼的：放下去之後換成 Blender 做的香蕉皮（只換外觀）
func _style_peels() -> void:
	var bi := skill_index("banana")
	var mesh := prop_mesh("banana_peel")
	if bi < 0 or mesh == null:
		return
	for pl in items[bi].peels:
		var n = pl.node
		if not is_instance_valid(n) or (n as Node).has_meta("styled"):
			continue
		(n as Node).set_meta("styled", true)
		for c in (n as Node).get_children():
			(c as Node3D).visible = false
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.scale = Vector3.ONE * PEEL_K
		mi.position.y = -0.02
		(n as Node).add_child(mi)

const PEEL_K := 1.35

## 掉進冰洞的水花：一圈水滴往外噴（共用的是幾顆圓球）
func spawn_splash(p: Vector3) -> void:
	var mesh := prop_mesh("fx_drop")
	if mesh == null or silent:
		super(p)
		return
	var wy: float = world.get("water_y") if world.get("water_y") != null else p.y
	_chip_rng.seed = 77 + int(p.x * 10.0)
	for k in 14:
		var a := k * TAU / 14.0 + _chip_rng.randf() * 0.3
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = _fx_mat("drop")
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		fx_root.add_child(mi)
		mi.global_position = Vector3(p.x + cos(a) * 0.7, wy + 0.25, p.z + sin(a) * 0.7)
		mi.scale = Vector3.ONE * _chip_rng.randf_range(0.9, 1.7)
		var out := _chip_rng.randf_range(1.2, 3.2)
		_chip_list.append({"node": mi, "vel": Vector3(cos(a) * out, _chip_rng.randf_range(4.5, 7.5), sin(a) * out), "t": 0.0, "life": 0.85, "drop": true})

# ---------------------------------------------------------------- 瞄準：落點標記（取代準心和共用的瞄準圈）

var _aim_mark: Node3D
var _aim_ring: MeshInstance3D
var _aim_peel: MeshInstance3D
var _aim_gray: StandardMaterial3D
var _aim_on_route := false
var _aim_ends: Array = []

## 準備階段拿著香蕉皮：瞄到的地面上浮著一片香蕉皮＋一個圈。
## 綠圈＝丟在這裡有人會踩到；白圈＝放得下但沒人會經過；灰色＝這裡放不了
func _update_aim_marker(cut: bool) -> void:
	if _aim_mark == null:
		_aim_mark = Node3D.new()
		world.add_child(_aim_mark)
		_aim_ring = MeshInstance3D.new()
		_aim_ring.mesh = prop_mesh("rescue/aim_ring")
		var rm := StandardMaterial3D.new()
		rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		rm.disable_fog = true
		_aim_ring.material_override = rm
		_aim_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_aim_mark.add_child(_aim_ring)
		_aim_peel = MeshInstance3D.new()
		_aim_peel.mesh = prop_mesh("banana_peel")
		_aim_peel.scale = Vector3.ONE * PEEL_K
		_aim_peel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_aim_mark.add_child(_aim_peel)
		_aim_gray = StandardMaterial3D.new()
		_aim_gray.albedo_color = Color(0.62, 0.65, 0.7)
	var holding: bool = phase != Phase.ENDED and not cut and not defeat_shown and aim_point != null \
		and not items.is_empty() and items[selected].id == "banana" and (phase == Phase.PREPARE or charges[selected] != 0)
	_aim_mark.visible = holding
	if _preview and (holding or phase == Phase.PREPARE):
		_preview.visible = false          # 共用的瞄準圈是程式拼的圓環：這個模式一律用下面的模型標記
	if crosshair and holding:
		crosshair.visible = false
	if not holding:
		return
	var ok: bool = aim_error == "" and charges[selected] != 0
	var col := Color("9aa3ad")
	if ok:
		col = Color("3ddc6a") if _aim_on_route else Color(1, 1, 1)
	(_aim_ring.material_override as StandardMaterial3D).albedo_color = Color(col, 0.95 if ok else 0.75)
	_aim_peel.material_override = null if ok else _aim_gray
	_aim_mark.global_position = (aim_point as Vector3) + Vector3(0, 0.07, 0)
	var pulse := 1.0 + sin(_clock * 6.0) * 0.04
	_aim_ring.scale = Vector3(pulse, 1.0, pulse)
	_aim_ring.rotation.y = _clock * 0.8
	_aim_peel.position.y = 0.3 + sin(_clock * 4.0) * 0.07
	_aim_peel.rotation.y = _clock * 1.2

# ---------------------------------------------------------------- 半透明的分身（第 3 關：示範、看時機）

var _demo_playing := false
var _demo_peel: MeshInstance3D
static var _ghost_sh: Shader

static func _ghost_shader() -> Shader:
	if _ghost_sh == null:
		_ghost_sh = Shader.new()
		_ghost_sh.code = """
shader_type spatial;
render_mode unshaded, depth_draw_always, fog_disabled;
uniform float alpha = 0.68;
void fragment() {
	vec3 c = COLOR.rgb;
	c = mix(pow((c + 0.055) / 1.055, vec3(2.4)), c / 12.92, lessThan(c, vec3(0.04045)));
	ALBEDO = mix(c, vec3(1.0), 0.22);
	ALPHA = alpha;
}
"""
	return _ghost_sh

## 某個工人的分身：整個模型複製一份，換成半透明的材質
func _ghost(f: Fighter) -> Dictionary:
	if _ghosts.has(f):
		return _ghosts[f]
	var rig0 = _rigs.get(f)
	if rig0 == null:
		return {}
	var n := f.node.duplicate() as Node3D
	world.add_child(n)
	var sk := n.find_child("Skeleton3D", true, false) as Skeleton3D
	var bones := {}
	for b in sk.get_bone_count():
		bones[sk.get_bone_name(b)] = b
	var mat := ShaderMaterial.new()
	mat.shader = _ghost_shader()
	for c in n.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		mi.visible = true
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if mi.mesh is QuadMesh:
			mi.visible = false          # 手繪表情的貼片：分身不用
		else:
			mi.material_override = mat
	n.visible = false
	var g := {"node": n, "rig": {"skel": sk, "bones": bones}, "ap": n.find_child("AnimationPlayer", true, false), "unit": float(rig0.unit)}
	_ghosts[f] = g
	return g

func _show_ghost(f: Fighter, pos: Vector3, yaw: float, mode: String) -> void:
	var g := _ghost(f)
	if g.is_empty():
		return
	_ghost_used[f] = true
	var n: Node3D = g.node
	n.visible = true
	var ap: AnimationPlayer = g.ap
	if mode == "slide":
		if ap and ap.is_playing():
			ap.pause()
		pose_mini(g.rig, mini_pose("slide", _clock))
		n.global_position = ground(pos) + Vector3(0, -0.07 * float(g.unit), 0)
		n.rotation = Vector3(-0.4, yaw, 0)
	else:
		if ap and (ap.current_animation != "sprint" or not ap.is_playing()):
			ap.play("sprint")
		n.global_position = ground(pos)
		n.rotation = Vector3(0, yaw, 0)

# ---------------------------------------------------------------- 特寫鏡頭：不被擋住、不把家豪切一半

## 從 cam 看不看得到家豪：中間不能有別人的大頭、站著的雪人、樹和小屋
func _sees_bird(cam: Vector3) -> bool:
	for h in [0.3, 0.8, 1.35]:
		if _blocked(cam, bird.pos + Vector3(0, float(h) + bird.air, 0), false):
			return false
	return true

var _block_why := ""
func _blocked(cam: Vector3, tgt: Vector3, near_ok: bool) -> bool:
	_block_why = ""
	var ab := tgt - cam
	var l2 := ab.length_squared()
	if l2 < 0.01:
		return false
	var balls: Array = []
	for e in enemies:
		var c: Vector3 = e.pos + Vector3(0, 1.0 if e.data.get("sunk", false) else 1.9, 0)
		if e.data.get("pile") != null:
			c = (e.data.pile as Vector3) + Vector3(0, 1.0, 0)
		balls.append([c, 1.5])
	for sn in world.get("snowman_nodes"):
		if (sn.node as Node3D).visible and absf((sn.node as Node3D).rotation.z) < 0.5:
			balls.append([(sn.pos as Vector3) + Vector3(0, 1.1, 0), 1.0])
	for b in balls:
		var c2: Vector3 = b[0]
		if near_ok and c2.distance_to(tgt) < float(b[1]) + 0.2:
			continue                    # 拍的就是這個人：他自己不算擋
		var t := clampf((c2 - cam).dot(ab) / l2, 0.0, 1.0)
		if (cam + ab * t).distance_to(c2) < float(b[1]):
			_block_why = "ball %s" % c2
			return true
	# 場上的擺設（冰晶、樹、小屋…）：鏡頭不能塞在裡面，鏡頭到目標之間也不能穿過它
	var near_tgt := cam.lerp(tgt, 0.88)
	for bx in _prop_boxes():
		if (bx as AABB).grow(2.0).has_point(cam) or (bx as AABB).intersects_segment(cam, near_tgt):
			_block_why = "box %s" % bx
			return true
	# 樹、小屋、雪人（場地的障礙物是圓柱）
	for ob in world.obstacles:
		var r := float(ob[1])
		if r <= 0.0:
			continue
		var oc := Vector3((ob[0] as Vector2).x, 0, (ob[0] as Vector2).y)
		var flat := Vector3(ab.x, 0, ab.z)
		var fl2 := flat.length_squared()
		if fl2 < 0.01:
			continue
		# 鏡頭本身離障礙物至少 3 公尺（松樹的枝葉比樹幹寬很多，貼太近半個畫面都是樹）
		if flat_dist(cam, oc) < r + 3.0 and cam.y - ground(oc).y < 7.0:
			_block_why = "near obstacle %s" % oc
			return true
		# 大的障礙物（松樹、小屋）在鏡頭和主角之間的近景、而且在畫面裡：也不行（會蓋掉畫面的一大塊）
		if r > 0.65:
			var fwd := flat / sqrt(fl2)
			var rel := Vector3(oc.x - cam.x, 0, oc.z - cam.z)
			var depth := rel.dot(fwd)
			if depth > 0.5 and depth < minf(7.5, sqrt(fl2) - 1.0) and ((rel - fwd * depth).length() - (r + 1.6)) / depth < 0.95 \
					and cam.y - ground(oc).y < 5.5:
				_block_why = "foreground obstacle %s" % oc
				return true
		# 鏡頭到主角的連線也要離障礙物遠一點（從它上面越過去可以；主角身邊的不算）
		var t2 := clampf((oc - Vector3(cam.x, 0, cam.z)).dot(flat) / fl2, 0.0, 1.0)
		var hit := cam + ab * t2
		if t2 > 0.0 and t2 < 0.85 and flat_dist(hit, oc) < r + 1.9 and hit.y - ground(oc).y < 5.5:
			_block_why = "obstacle %s" % oc
			return true
	return false

## 鏡頭前面夠不夠空：往 look 看過去的那半邊，r 公尺內不能有別人的頭（不然畫面被一顆大頭佔掉一半）
func _cam_clear(cam: Vector3, look: Vector3, r: float) -> bool:
	var fwd := (look - cam).normalized()
	for e in enemies:
		var c: Vector3 = e.pos + Vector3(0, 0.9 if e.data.get("sunk", false) else 1.9, 0)
		var v := c - cam
		var depth := v.dot(fwd)
		if depth < 0.3:
			continue                                  # 在鏡頭後面
		var lateral := (v - fwd * depth).length()
		if (lateral - 1.4) / depth > 1.05:
			continue                                  # 在畫面外（頭的半徑也算進去）
		if flat_dist(c, cam) < r:
			return false
	return true

## 家豪在這個鏡頭裡是不是「只露一半」（一部分在畫面裡、一部分被畫面邊切掉）
func _bird_half_cut() -> bool:
	if _cut_cam == null or not is_inside_tree():
		return false
	var size := get_viewport().get_visible_rect().size
	var c: Vector3 = bird.pos + Vector3(0, 1.15 + bird.air, 0)
	var right := _cut_cam.global_basis.x * 1.05
	var inside := 0
	var total := 0
	for p in [c, c + right, c - right, c + Vector3(0, 1.3, 0), c - Vector3(0, 1.1, 0)]:
		total += 1
		if _cut_cam.is_position_behind(p):
			continue
		var s := _cut_cam.unproject_position(p)
		if s.x > 6.0 and s.x < size.x - 6.0 and s.y > 6.0 and s.y < size.y - 6.0:
			inside += 1
	return inside > 0 and inside < total

## 切特寫，但先挑角度：繞著目標轉幾個角度試，挑第一個「看得到目標、家豪沒被切一半」的。
## need_bird＝家豪一定要完整入鏡
func _cut_smart(target: Vector3, offset: Vector3, sec: float, need_bird := false, angles := [0.0, 0.4, -0.4, 0.8, -0.8, 1.3, -1.3]) -> void:
	if silent or _cut_cam == null or not is_inside_tree():
		_cut_to(target, offset, sec)
		return
	var pick: Vector3 = offset
	var found := false
	for up_more in [0.0, 2.4]:
		for a in angles:
			if found:
				break
			# 被擋到：先換角度（換另一側），都不行再把鏡頭拉高
			var off: Vector3 = offset.rotated(Vector3.UP, float(a)) + Vector3(0, float(up_more), 0)
			if _blocked(target + off, target, true):
				continue
			_cut_cam.global_position = target + off
			_cut_cam.look_at(target, Vector3.UP)
			if _bird_half_cut():
				continue
			if need_bird and (_cut_cam.is_position_behind(bird.pos) or not _sees_bird(target + off)):
				continue
			pick = off
			found = true
	_cut_to(target, pick if found else offset, sec)

## 輸了的晚餐畫面是共用的場景，圍著餐桌的是寫實比例的農夫：換成這一關的 Q 版小人（只換外觀）
var _dinner_done := false
func _recast_dinner() -> void:
	if _dinner_done or defeat_room == null:
		return
	_dinner_done = true
	var ids: Array = []
	for f in enemies:
		ids.append(f.name if LOOKS.has(f.name) else ("守衛" if f.get_meta("guard", false) else "工人"))
	var k := 0
	for c in defeat_room.get_children():
		if not (c is Node3D) or not String(c.get_meta("source", "")).to_lower().contains("farmer"):
			continue
		var old := c as Node3D
		var id: String = ids[k % ids.size()]
		k += 1
		var path := MODEL_GUARD if id == "守衛" else MODEL_WORKER
		var scene := load(path) as PackedScene
		if scene == null:
			continue
		var model := scene.instantiate() as Node3D
		var wrap := Node3D.new()
		wrap.add_child(model)
		wrap.set_meta("source", path)
		model.scale = Vector3.ONE * 2.05
		defeat_room.add_child(wrap)
		# 小人比較矮：後排墊高（像站在長椅上），臉才高過桌面；兩側的往外站一點
		wrap.position = old.position + (Vector3(0, 0.62, -0.15) if absf(old.rotation.y) < 0.1 else Vector3(signf(old.position.x) * 0.25, 0.3, 0.2))
		wrap.rotation = old.rotation
		old.visible = false
		var rig := style_mini(wrap, LOOKS[id], id)
		if rig.is_empty():
			continue
		var ap := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if ap:
			ap.pause()
		# 兩手往前伸向烤雞，笑得很開心
		pose_mini(rig, {"arm-left": Vector3(0, -1.1, 0.2 + 0.2 * (k % 2)), "arm-right": Vector3(0, 1.1, -0.2 - 0.2 * ((k + 1) % 2)),
			"head": Vector3(0.12, 0, 0.08 * (1 if k % 2 == 0 else -1)), "torso": Vector3(0.1, 0, 0)})
		(rig.mat as ShaderMaterial).set_shader_parameter("amb", Vector3(0.5, 0.42, 0.34))

## 場上每個擺設的外框盒子（特寫鏡頭挑位置用）。太扁的（冰面、地上的東西）和太大的（地形、海）不算。
var _boxes: Array = []
var _boxes_ready := false
func _prop_boxes() -> Array:
	if _boxes_ready:
		return _boxes
	_boxes_ready = true
	_boxes.clear()
	for n in world.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null or not mi.is_visible_in_tree():
			continue
		if (chars and chars.is_ancestor_of(mi)) or (fx_root and fx_root.is_ancestor_of(mi)) or (defeat_room and defeat_room.is_ancestor_of(mi)):
			continue
		var bx: AABB = mi.global_transform * mi.get_aabb()
		if bx.size.y < 0.7 or bx.size.x > 12.0 or bx.size.z > 12.0:
			continue
		_boxes.append(bx)
	return _boxes
