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
const BODY_K := 1.25           # 工人放大（畫面上角色要夠大）
const HEAD_K := 1.4            # 工人的頭再放大：跟圓滾滾的雞、企鵝同一種 Q 版比例
const VEST := [Color("f08a24"), Color("2a9fd6"), Color("e0559a"), Color("7cb342")]   # 每個工人一種背心顏色
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
const HANG := 1.3             # 家豪被拎著：手到他腳底的距離            # 滑停在雪堆這麼近的地方，就倒栽進雪堆

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
	return d

## 站著不動、家豪靠近就沿箭頭撲過去的守衛
func guard(name: String, at: Vector3) -> Dictionary:
	var d := worker(name, [at], {"guard": true})
	d.has_cone = false
	d.reach = 0.6
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
	_path_line = _mesh_node(m)
	_route_line = _mesh_node(m)
	_peel_line = _mesh_node(m)
	# 家豪：放大一點、加大紅雞冠和黃嘴、頭上掛名字、腳下一圈光，一眼認得出主角（也跟黑白的企鵝分開）
	bird.node.scale = Vector3.ONE * 1.6
	fall_toast = false
	for i in enemies.size():
		enemies[i].node.scale = enemies[i].node.scale * BODY_K
		_dress(enemies[i], i)
	var head := bird.node.find_child("Head", true, false) as Node3D
	if head:
		var red := StandardMaterial3D.new()
		red.albedo_color = Color(0.9, 0.1, 0.1)
		for k in 3:
			var c := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.06
			sm.height = 0.16
			c.mesh = sm
			c.material_override = red
			c.position = Vector3(0, 0.17 + (0.03 if k == 1 else 0.0), 0.08 - k * 0.07)
			head.add_child(c)
		var beak := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0
		cm.bottom_radius = 0.05
		cm.height = 0.13
		beak.mesh = cm
		var yel := StandardMaterial3D.new()
		yel.albedo_color = Color(1.0, 0.75, 0.1)
		beak.material_override = yel
		beak.rotation.x = PI * 0.5
		beak.position = Vector3(0, 0.0, 0.17)
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
	var tm := TorusMesh.new()
	tm.inner_radius = 0.75
	tm.outer_radius = 0.95
	_bird_ring.mesh = tm
	var rmat := StandardMaterial3D.new()
	rmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rmat.albedo_color = Color(0.35, 0.95, 1.0)
	_bird_ring.material_override = rmat
	_bird_ring.scale = Vector3(1, 0.1, 1)
	world.add_child(_bird_ring)
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
	_goal_label.offset_top = 100
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
		_goal_label.visible = true
	_refresh_list()
	if _how_label:
		_how_label.text = _how_to()
		(_how_label.get_parent() as Control).visible = true
	# 字卡放在畫面下三分之一，不要擋住事件
	if _toast_label:
		_toast_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
		_toast_label.offset_top = -200
		_toast_label.offset_bottom = -160
		_toast_label.grow_horizontal = Control.GROW_DIRECTION_BOTH

func _level_start() -> void:
	_goal_label.visible = false
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
			f.pos = o.pos + side * 0.65
			o.pos = o.pos - side * 0.1
			f.data.pair = true
			o.data.pair = true
	super(f)
	# 臉朝鏡頭，凍得發抖、吐泡泡
	var cp: Vector3 = camera.global_position if camera else f.pos + Vector3(0, 0, 10)
	f.yaw = atan2(cp.x - f.pos.x, cp.z - f.pos.z)
	f.data.sunk_yaw = f.yaw
	f.data.blub = false
	_set_frost(f, true)
	pop_label("撲通！", f.pos + Vector3(0, 2.4, 0), Color(0.6, 0.88, 1.0), 900, f)
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
		_cut_to(f.pos + Vector3(0, 0.6, 0), away2 * 3.2 + Vector3(0, 1.6, 0), 1.0)

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
				_cut_to(tgt + Vector3(0, -0.05, 0), away * 2.3 + Vector3(0, 0.35, 0), 99.0)
			else:
				_cut_to(tgt, away * 3.0 + Vector3(0, 1.3, 0), 99.0)
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
		if _victim_in_shot:
			var dirv := bv / dist
			var left := Vector3.UP.cross(dirv)          # 從受害者看向家豪時的左手邊
			var cam: Vector3 = ground(vp) + dirv * 2.6 + left * 1.6 + Vector3(0, 1.7, 0)
			focus = bird.pos.lerp(ground(vp), 0.45) + Vector3(0, 0.7, 0) - left * 0.6
			offset = cam - focus
			# 洞裡的受害者轉向鏡頭（看得到臉），家豪在他們後面吐槽
			var near: Array = enemies.filter(func(e): return e.data.get("sunk", false) and flat_dist(e.pos, vp) < 3.0)
			if near.size() >= 2:
				# 兩個人並排（以這個鏡頭的左右排開），兩張臉都入鏡
				var ctr: Vector3 = (near[0].pos + near[1].pos) * 0.5
				var vd: Vector3 = cam - ctr
				vd.y = 0.0
				var sideways := vd.normalized().cross(Vector3.UP)
				near[0].pos = ctr - sideways * 0.42
				near[1].pos = ctr + sideways * 0.42
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
	return "提示：香蕉皮丟在紅線的哪一段，工人就會往那一段的方向滑。準備時瞄在紅線上看黃線滑到哪。"

## 輸了的晚餐畫面：不要寫「還剩幾個敵人」，改成誰抓到的
func _show_defeat() -> void:
	super()
	_list_layer.visible = false
	var tip := _defeat_tip()
	if _miss_text != "":
		var who := _miss_text.substr(0, _miss_text.find("晚") if _miss_text.contains("晚") else _miss_text.find("早"))
		var way := "往%s的來路挪一點（早點踩到）" % who if _miss_text.contains("晚") else "往%s的去路挪一點（晚點踩到）" % who
		tip = "%s：香蕉皮%s" % [_miss_text, way]
	_defeat_detail.text = "%s\nR 重來　｜　M 地圖" % tip

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
					toast("追不上了！家豪走得比工人快，被甩到後面就追不上", 2.2)
				return
			_walk(f, ip, RUSH_SPEED, dt)
			anim(f, "Run")
	if world.in_water(f.pos.x, f.pos.z):
		fall_in(f)

func _level_step(dt: float) -> void:
	super(dt)
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
			for o in enemies:
				if o != f and o.alive() and flat_dist(o.pos, f.pos) < 1.9:
					var push: Vector3 = o.pos - f.pos
					push.y = 0.0
					push = push.normalized() if push.length() > 0.05 else Vector3.RIGHT
					o.pos = ground(f.pos + push * 2.0)   # 別人站開一點，不要兩個人疊在一起
					_face(o, bird.pos)
			for li in range(_labels.size() - 1, -1, -1):   # 只留「……完了」，其他跳字清掉
				if not _labels[li].get("fixed", false):
					if is_instance_valid(_labels[li].node):
						_labels[li].node.queue_free()
					_labels.remove_at(li)
			bubble("……完了", bird, 1.75, 4000)
			# 鏡頭在兩人斜前方：工人的臉和被拎著的家豪的臉都拍得到
			var fw := Vector3(sin(f.yaw), 0, cos(f.yaw))
			var sd := fw.cross(Vector3.UP)
			_cut_to(f.pos + fw * 0.3 - sd * 0.2 + Vector3(0, 1.5, 0), fw * 2.8 - sd * 2.2 + Vector3(0, 0.5, 0), LIFT_TIME + 3.0)
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
		_follow_off = side * 4.6 + Vector3(0, 2.1, 0) - dir * 1.4
		_cut_to(f.pos + dir * 1.2 + Vector3(0, 1.0, 0), _follow_off, minf(span / SLIDE_SPEED + 1.0, 2.6))
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
					pop_label("？！", o.pos + Vector3(0, 3.0, 0), Color(1, 0.9, 0.3), 1100, o)
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
	pop_label("連環撞！", o.pos + Vector3(0, 3.6, 0), Color(1, 0.85, 0.2), 900, o)
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
		var tgt3: Vector3 = _follow.pos + sd3 * 1.2 + Vector3(0, 1.0, 0)
		_cut_cam.global_position = _cut_cam.global_position.lerp(tgt3 + _follow_off, 0.25)
		_cut_cam.look_at(tgt3, Vector3.UP)
	# 工人的頭放大（Q 版比例）；動畫每一格會重設，所以每一格再設一次
	for f in enemies:
		var hb = f.data.get("head_bi")
		if hb == null:
			bone_pos(f, "Head")
			var sk0 = f.data.get("skel")
			hb = (sk0 as Skeleton3D).find_bone("Head") if sk0 is Skeleton3D else -1
			f.data.head_bi = hb
		if int(hb) >= 0:
			(f.data.skel as Skeleton3D).set_bone_pose_scale(int(hb), Vector3.ONE * HEAD_K)
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
		_hotbar.visible = not cut        # 特寫、過關演出時收起道具格
	if cut and _preview:
		_preview.visible = false
		for d in _dots:
			d.visible = false
	_bird_tag.visible = false   # 家豪不掛名牌：腳下的光圈就夠了
	_bird_tag.position = bird.pos + Vector3(0, 2.4 + bird.air, 0)
	_bird_ring.position = bird.pos + Vector3(0, 0.06, 0)
	_bird_ring.visible = bird.alive() and phase != Phase.ENDED and not cut
	for f in enemies:
		(_intents[f] as Label3D).visible = (_intents[f] as Label3D).visible and not cut
	if _how_label and cut:
		(_how_label.get_parent() as Control).visible = false
	# 畫面上少放字：「怎麼玩」8 秒後收成一個小標籤（按住 H 再打開）；大標題 4 秒後收起
	if phase == Phase.PREPARE and not cut and _how_label:
		var t_in := _clock - _prep_t0
		var demo_on: bool = show_timing and t_in < 9.0
		var first_time: bool = attempts.is_empty()     # 說明、大標題、示範都只在第一次進這一關時出現
		demo_on = demo_on and first_time
		var show_how: bool = (first_time and t_in < 5.0) or demo_on or Input.is_physical_key_pressed(KEY_H)
		(_how_label.get_parent() as Control).visible = show_how and not (_top_cam != null and _top_cam.current)
		if _goal_label:
			_goal_label.visible = first_time and t_in < 2.5 and not (_top_cam != null and _top_cam.current)
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
			(hat as Node3D).global_position = head_pos(f) + Vector3(0, 0.3, 0)
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
	_dashes(im, pts, Color(1.0, 0.82, 0.2, 0.95), 0.16)
	_flush(im)

## 工人的路線（紅色虛線、終點紅叉）、守衛的撲擊圈和撲過去的箭頭
func _draw_routes() -> void:
	var im := _route_line.mesh as ImmediateMesh
	im.clear_surfaces()
	if phase == Phase.ENDED:
		return
	_vb.clear()
	var red := Color(1.0, 0.25, 0.2, 0.9)
	for f in enemies:
		if not f.alive() or f.state in ["kslide", "stunned", "slip"]:
			continue
		if f.data.get("guard", false) and f.state in ["guard", "idle", "patrol"]:
			var pts: Array = []
			for k in 41:
				var a := k * TAU / 40.0
				pts.append(ground(f.pos + Vector3(cos(a), 0, sin(a)) * LUNGE_R))
			_dashes(im, pts, Color(red, 0.6), 0.06)
		var er := effective_route(f) if f.state != "chase" else {"main": _chase_line(f), "ghost": [], "ended": false}
		var route: Array = er.main
		var ghost: Array = er.ghost
		if ghost.size() >= 2:
			# 撞停爬起來之後改追的新紅線（粉紅）＋終點紅叉＋說明
			_dashes(im, ghost, Color(1, 1, 1, 0.95), 0.17)
			_dashes(im, ghost, Color(1.0, 0.2, 0.75, 1.0), 0.11)
			_cross(ghost.back(), Color(1.0, 0.5, 0.6, 0.95))
			pass   # 粉紅線本身就說明了改道，不另外寫字
		if route.size() < 2:
			continue
		if f.data.get("guard", false) and f.state in ["guard", "idle", "patrol"]:
			# 守衛：橘色粗箭頭（撲過去的方向）
			var org := Color(1.0, 0.55, 0.15, 0.95)
			var a0: Vector3 = route[0]
			var a1: Vector3 = route[1]
			var dirv := (a1 - a0)
			dirv.y = 0
			dirv = dirv.normalized()
			_solid(im, a0, a1 - dirv * 0.2, org, 0.22)
			var sidev := dirv.cross(Vector3.UP) * 0.75
			var tip := a1 - dirv * 0.2 + Vector3(0, 0.13, 0)
			for v in [tip + dirv * 1.0, tip + sidev, tip - sidev]:
				_v(org, v)
			continue
		_dashes(im, route, red, 0.14)
		if er.ended or not ghost.is_empty():
			continue
		var b: Vector3 = route.back()
		for v in [b + Vector3(-0.4, 0.12, -0.4), b + Vector3(-0.28, 0.12, -0.52), b + Vector3(0.52, 0.12, 0.28),
				b + Vector3(-0.4, 0.12, -0.4), b + Vector3(0.52, 0.12, 0.28), b + Vector3(0.4, 0.12, 0.4),
				b + Vector3(0.4, 0.12, -0.4), b + Vector3(0.52, 0.12, -0.28), b + Vector3(-0.28, 0.12, 0.52),
				b + Vector3(0.4, 0.12, -0.4), b + Vector3(-0.28, 0.12, 0.52), b + Vector3(-0.4, 0.12, 0.4)]:
			_v(red, v)
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

func _cross(b: Vector3, c: Color) -> void:
	for v in [b + Vector3(-0.4, 0.12, -0.4), b + Vector3(-0.28, 0.12, -0.52), b + Vector3(0.52, 0.12, 0.28),
			b + Vector3(-0.4, 0.12, -0.4), b + Vector3(0.52, 0.12, 0.28), b + Vector3(0.4, 0.12, 0.4),
			b + Vector3(0.4, 0.12, -0.4), b + Vector3(0.52, 0.12, -0.28), b + Vector3(-0.28, 0.12, 0.52),
			b + Vector3(0.4, 0.12, -0.4), b + Vector3(-0.28, 0.12, 0.52), b + Vector3(-0.4, 0.12, 0.4)]:
		_v(c, v)

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
		and ((attempts.is_empty() and _clock - _prep_t0 < 2.5) or Input.is_physical_key_pressed(KEY_H))
	for f in enemies:
		var l: Label3D = _intents[f]
		l.visible = show_names and f.alive()
		if l.visible:
			l.text = f.name
			l.position = f.pos + Vector3(0, 3.7, 0)

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
						r.text = "冰洞！"
						r.color = Color(0.4, 0.8, 1.0)
					elif tx.begins_with("撞到雪") or tx.begins_with("撞牆"):
						r.text = "咚！"
						r.color = Color(0.9, 0.9, 0.9)
					elif tx.begins_with("撞到"):
						r.text = "撞！"
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
	_draw_slides(im, results, Color(1.0, 0.92, 0.25, 0.95), 0.11)
	for i in _ends.size():
		var lb: Label3D = _ends[i]
		if i < results.size():
			lb.visible = true
			lb.text = results[i].text
			lb.position = (results[i].end as Vector3) + Vector3(0, 1.0, 0)
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

func _draw_slides(im: ImmediateMesh, results: Array, col: Color, w: float) -> void:
	var drew := false
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
			side = side.normalized().cross(Vector3.UP) * w
			for v in [a - side, a + side, b + side, a - side, b + side, b - side]:
				_v(col, v)
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
					var sd := dv.normalized().cross(Vector3.UP) * (w * 4.0)
					var fw2 := dv.normalized() * 0.08
					for v in [q - sd - fw2, q + sd - fw2, q + sd + fw2, q - sd - fw2, q + sd + fw2, q - sd + fw2]:
						_v(col, v)
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
	var hand = bone_pos(_catcher, "Wrist.R")
	if hand != null and _catcher.data.get("frozen_pose", "") == "Interact":
		# 掛在工人伸出去的右手上（手抓著帽T的帽子）
		var g := ground(hand)
		# 不要嵌進雪人／樹裡：太近就往外推
		for ob in world.obstacles:
			var c2: Vector2 = ob[0]
			var off := Vector2(g.x - c2.x, g.z - c2.y)
			var need: float = float(ob[1]) + 0.55
			if off.length() < need and off.length() > 0.01:
				var push := off.normalized() * (need - off.length())
				g += Vector3(push.x, 0, push.y)
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
func bubble(text: String, who: Fighter, dy: float, ms: int) -> void:
	if silent:
		return
	pop_label(text, who.pos + Vector3(0, dy, 0), Color(1, 1, 1), ms, who)
	if _labels.is_empty():
		return
	var e: Dictionary = _labels.back()
	e.fixed = true
	var l: Label3D = e.node
	l.font_size = 56
	_plate(l, "bubble")

## 同一個人頭上同一個字 0.5 秒內只跳一次（不會「咚！咚！」疊在一起）
func pop_label(text: String, pos: Vector3, color: Color, ms: int, follow: Fighter = null) -> void:
	var key := "%s|%s" % [text, str(follow.get_instance_id()) if follow else "-"]
	if _pop_seen.has(key) and _clock - float(_pop_seen[key]) < 0.5:
		return
	_pop_seen[key] = _clock
	if follow and pos.y - follow.pos.y > 2.7:
		pos.y = follow.pos.y + 2.7   # 貼著頭頂，不要飄到樹上
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
		# 狀聲字：大、粗描邊（漫畫字）
		var pl := _labels.back().node as Label3D
		if UISkin.font():
			pl.font = UISkin.font()
		pl.font_size = 92
		pl.outline_size = 30
		pl.outline_modulate = UISkin.INK

func _update_labels(now: int) -> void:
	super(now)
	for e in _labels:
		if e.get("fixed", false) and e.follow and is_instance_valid(e.node):
			var f: Fighter = e.follow
			(e.node as Label3D).position = f.pos + Vector3(0, float(e.dy) + f.air, 0)

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
				pop_label("噗！", f.pos + Vector3(0, 2.6, 0), Color(1, 1, 1), 900)
				sfx("crack")
				mark("pile")
				_shake_until = Time.get_ticks_msec() + 300
				anim(f, "Run")
				var away: Vector3 = (camera.global_position - f.pos) if camera else Vector3(0, 0, 1)
				away.y = 0.0
				away = away.normalized() if away.length() > 0.1 else Vector3.BACK
				_cut_to(f.pos + Vector3(0, 1.1, 0), away * 3.6 + Vector3(0, 1.4, 0), 1.6)
				return
	super(f, msg)

## 泡在冰洞裡：一直發抖，過一下吐泡泡「噗嚕…」
func _tick_sunk(f: Fighter, dt: float) -> void:
	super(f, dt)
	f.air *= BODY_K
	f.yaw = float(f.data.get("sunk_yaw", f.yaw)) + sin(f.data.sink_t * 45.0) * 0.06
	if f.data.sink_t > 1.0 and not f.data.get("blub", false):
		f.data.blub = true
		for o in enemies:
			if o != f and o.data.get("blub", false) and flat_dist(o.pos, f.pos) < 1.5:
				return   # 同一個洞只冒一次「喀喀喀…」
		pop_label("喀喀喀…", f.pos + Vector3(0, 0.0, 0), Color(0.6, 0.85, 1.0), 2400, f)
		var e: Dictionary = _labels.back() if not _labels.is_empty() else {}
		if not e.is_empty():
			e.dy = 2.3

## 姿勢：暈倒、追不上 → 坐在地上；雪堆裡 → 倒栽只露腿；暈倒頭上星星轉圈
func _level_visuals() -> void:
	super()
	for f in enemies:
		if f.data.get("sunk", false):
			# 凍得發抖：左右小幅快速抖動
			f.node.global_position += Vector3(sin(_clock * 63.0) * 0.035, 0, 0)
		_update_face(f)
		if f == _catcher and (bird.state == "lifted" or bird.data.get("held", false)):
			_freeze_pose(f, "Interact", 0.7)   # 手往前伸：拎著家豪
			continue
		var pile = f.data.get("pile")
		if pile != null:
			f.node.global_position = (pile as Vector3) + Vector3(0, 1.45 * BODY_K, 0)
			f.node.rotation = Vector3(PI, f.yaw, sin(_clock * 11.0) * 0.06)
			continue
		var sitting: bool = f.alive() and f.state in ["stunned", "giveup"]
		if sitting:
			_freeze_pose(f, "Death", 0.4)
			f.node.global_position = f.pos + Vector3(0, f.air - 0.35 * BODY_K, 0)
			var wob := sin(_clock * 6.0) * 0.15 if f.state == "stunned" else 0.0
			f.node.rotation = Vector3(0.1, f.yaw + wob, 0.0)
		elif f.data.get("frozen_pose", "") != "":
			f.data.frozen_pose = ""
			if f.anim:
				f.anim.play()
		_update_stars(f, f.alive() and f.state == "stunned" and phase != Phase.ENDED)

## 把動畫停在某一格（Death 的前段＝一屁股坐下）
func _freeze_pose(f: Fighter, name: String, frac: float) -> void:
	if f.anim == null or not f.anim.has_animation(name):
		return
	if f.data.get("frozen_pose", "") == name and f.anim.current_animation == name and not f.anim.is_playing():
		return   # 已經停在那一格（被別的地方改播動畫的話會重新停一次）
	f.data.frozen_pose = name
	f.anim.play(name, 0.0)   # 不混合：直接跳到那一格（混合到一半停住會變成站著）
	f.anim.seek(f.anim.get_animation(name).length * frac, true)
	f.anim.pause()

func _update_stars(f: Fighter, on: bool) -> void:
	if not _stars.has(f):
		if not on:
			return
		var arr: Array = []
		for k in 3:
			var l := Label3D.new()
			l.text = "★"
			l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			l.no_depth_test = true
			l.font_size = 96
			l.pixel_size = 0.004
			l.outline_size = 12
			l.modulate = Color(1.0, 0.9, 0.2)
			world.add_child(l)
			arr.append(l)
		_stars[f] = arr
	for k in 3:
		var l: Label3D = _stars[f][k]
		l.visible = on
		if on:
			var a := _clock * 5.0 + k * TAU / 3.0
			var top := 0.55 if f.data.get("snow_hat") == null else 1.0
			l.position = head_pos(f) + Vector3(cos(a) * 0.55, top + sin(a * 2.0) * 0.05, sin(a) * 0.55)

## 實心粗線（守衛撲過去的箭頭用）
func _solid(im: ImmediateMesh, a: Vector3, b: Vector3, c: Color, w: float) -> void:
	var side := (b - a)
	side.y = 0
	if side.length() < 0.01:
		return
	side = side.normalized().cross(Vector3.UP) * w
	var p0 := a + Vector3(0, 0.12, 0)
	var p1 := b + Vector3(0, 0.12, 0)
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

## 這個人頭頂的位置（照骨架的頭骨算，坐下、仰倒都跟得上）
func bone_pos(f: Fighter, bone: String):
	var sk = f.data.get("skel")
	if sk == null:
		sk = f.node.find_child("Skeleton3D", true, false)
		f.data.skel = sk if sk else false
	if sk is Skeleton3D:
		var bi: int = (sk as Skeleton3D).find_bone(bone)
		if bi >= 0:
			return (sk as Skeleton3D).global_transform * (sk as Skeleton3D).get_bone_global_pose(bi).origin
	return null

func head_pos(f: Fighter) -> Vector3:
	var sk = f.data.get("skel")
	if sk == null:
		sk = f.node.find_child("Skeleton3D", true, false)
		f.data.skel = sk if sk else false
	if sk is Skeleton3D:
		var bi: int = (sk as Skeleton3D).find_bone("Head")
		if bi >= 0:
			return (sk as Skeleton3D).global_transform * (sk as Skeleton3D).get_bone_global_pose(bi).origin + Vector3(0, 0.2 * BODY_K * HEAD_K, 0)
	return f.pos + Vector3(0, HAT_Y - 0.42 + f.air, 0)

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
				tl.visible = top_on   # 秒數只在按住 Tab 的俯視出現；平常只有白點
				used += 1
				sec += 1
	for i in range(used, _time_labels.size()):
		(_time_labels[i] as Label3D).visible = false

## 第 3 關：瞄準某人的紅線時，標出「他踩到的那一刻，其他人在哪」（白圈＋名字）
func _draw_timing_ghosts(im: ImmediateMesh) -> void:
	if _ghost_label == null:
		_ghost_label = Label3D.new()
		_ghost_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_ghost_label.no_depth_test = true
		_ghost_label.font_size = 64
		_ghost_label.pixel_size = 0.0005
		_ghost_label.fixed_size = true
		_ghost_label.outline_size = 12
		_ghost_label.modulate = Color(0.8, 0.95, 1.0)
		world.add_child(_ghost_label)
		_plate(_ghost_label, "ice")
	_ghost_label.visible = false
	if _cross_label:
		_cross_label.visible = false
	var aiming: bool = show_timing and phase == Phase.PREPARE and aim_point != null and aim_error == "" \
		and not items.is_empty() and items[selected].id == "banana" and charges[selected] != 0
	if not aiming:
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
				# 走到離香蕉皮 PEEL_STEP 就踩到了：用踩到的那一刻算（數字才誠實）
				var t_hit := maxf(walked + l * t - PEEL_STEP, 0.0) / RUSH_SPEED
				var names: PackedStringArray = []
				for o in enemies:
					if o == f or o.data.get("guard", false):
						continue
					var oq := _along(planned_route(o), t_hit * RUSH_SPEED)
					var pts: Array = []
					for k in 25:
						var ang := k * TAU / 24.0
						pts.append(ground(oq + Vector3(cos(ang), 0, sin(ang)) * 0.7))
					_dashes(im, pts, Color(0.8, 0.95, 1.0, 0.95), 0.07)
					names.append(o.name)
					_ghost_label.position = oq + Vector3(2.2, 1.0, 0.4)
				if not names.is_empty():
					_ghost_label.text = "踩到時%s在這" % "、".join(names)
					_ghost_label.font_size = 42
					_ghost_label.visible = _top_cam != null and _top_cam.current
				# 交叉點：別人「幾秒經過這裡」（阿土那邊要自己數黃線上的橫槓）
				_mark_crossing(f, p, Vector3(ab.x, 0, ab.y) / l, t_hit)
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
		t = "%s？" % (res.who as Fighter).name
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

## 泡在冰水裡：全身蓋一層藍白色的霜（凍僵的樣子）
var _frost_mat: StandardMaterial3D
func _set_frost(f: Fighter, on: bool) -> void:
	if f.node == null:
		return
	if _frost_mat == null:
		_frost_mat = StandardMaterial3D.new()
		_frost_mat.albedo_color = Color(0.7, 0.88, 1.0, 0.3)
		_frost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_frost_mat.emission_enabled = true
		_frost_mat.emission = Color(0.12, 0.22, 0.35)
	for m in f.node.find_children("*", "MeshInstance3D", true, false):
		(m as MeshInstance3D).material_overlay = _frost_mat if on else null

## 第 3 關：瞄準時在交叉點寫「阿水 3.3 秒經過」
func _mark_crossing(f: Fighter, p: Vector3, dir: Vector3, t_hit := 0.0) -> void:
	if _cross_label == null:
		_cross_label = Label3D.new()
		_cross_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_cross_label.no_depth_test = true
		_cross_label.font_size = 50
		_cross_label.outline_modulate = Color(0.15, 0.1, 0.0, 1.0)
		_cross_label.pixel_size = 0.0005
		_cross_label.fixed_size = true
		_cross_label.outline_size = 24
		_cross_label.modulate = Color(1.0, 0.95, 0.6)
		world.add_child(_cross_label)
		_plate(_cross_label, "ice")
	for o in enemies:
		if o == f or o.data.get("guard", false):
			continue
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
					# 跟示範一樣比兩個數字：阿土的秒數要自己數黃線格子（按住 Tab 俯視時才直接顯示）
					var start := p - dir * PEEL_STEP
					var arrive := t_hit + flat_dist(start, q) / SLIDE_SPEED
					var mine := ("%.1f" % arrive) if (_top_cam != null and _top_cam.current) else "?"
					_cross_label.text = "%s %s 秒 ／ %s %.1f 秒" % [f.name, mine, o.name, (along + seg * float(k) / n) / RUSH_SPEED]
					# 字放在交叉點南邊（離開路線和白點），拉一條引線指回去
					var off := Vector3(0, 0, 2.2)
					_cross_label.position = q + off + Vector3(0, 0.5, 0)
					if _top_cam != null and _top_cam.current:
						_cross_lead = [q, q + off]
						_cross_label.visible = true
					return
			along += seg

# ---------------------------------------------------------------- 工人的表情（Codex 生成的貼圖，貼在臉上）

const FACES := {
	"frozen": "res://levels/ice/assets/faces/face_frozen.png",
	"dizzy": "res://levels/ice/assets/faces/face_dizzy.png",
	"shock": "res://levels/ice/assets/faces/face_shock.png",
}
var _face_tex := {}
var _faces := {}             # 工人 -> Sprite3D

func _update_face(f: Fighter) -> void:
	var want := ""
	if f.data.get("pile") != null:
		want = ""                      # 倒栽在雪堆裡：看不到臉
	elif f.data.get("sunk", false):
		want = "frozen"
	elif f.alive() and f.state in ["stunned", "giveup"]:
		want = "dizzy"
	# （滑行時身體是斜的，貼圖對不上臉，所以滑行中不貼表情）
	if not _faces.has(f):
		if want == "":
			return
		var sp := Sprite3D.new()
		sp.pixel_size = 0.00024 * BODY_K * HEAD_K
		sp.no_depth_test = true      # 卡通臉畫在最上層（背面會被剔除，背對時看不到）
		sp.render_priority = 2
		sp.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		sp.shaded = false
		sp.double_sided = false
		world.add_child(sp)
		_faces[f] = sp
	var sp: Sprite3D = _faces[f]
	sp.visible = want != ""
	if want == "":
		return
	if not _face_tex.has(want):
		_face_tex[want] = load(FACES[want])
	sp.texture = _face_tex[want]
	# 貼在頭的正前方（跟著身體轉向）
	var basis := f.node.global_basis.orthonormalized()
	var fwd := basis.z
	var hb = bone_pos(f, "Head")
	var hp: Vector3 = (hb as Vector3) if hb != null else head_pos(f) - Vector3(0, 0.2, 0)
	# 頭骨原點大約在臉的上緣：往下一點、往前貼到臉上
	# 從側面或背面看時收起來（不然像一張飄在頭旁邊的卡片）
	var vcam := get_viewport().get_camera_3d()
	if vcam and fwd.dot((vcam.global_position - hp).normalized()) < 0.4:
		sp.visible = false
		return
	sp.global_transform = Transform3D(basis, hp + fwd * 0.24 * BODY_K * HEAD_K + Vector3(0, 0.04 * BODY_K * HEAD_K, 0))

# ---------------------------------------------------------------- 第 3 關開場示範（一個「太早」的例子，教怎麼看時間，不洩漏答案）

const DEMO_SPEED := 1.1
const DEMO_HOLD := 3.0

## 在準備階段一開始自動播一次：虛影香蕉皮→阿土虛影走過去、滑出去（黃線格子一格一格亮）→阿水虛影同步走→在交叉點比時間
func _draw_demo(im: ImmediateMesh) -> void:
	for l in _demo_labels:
		(l as Label3D).visible = false
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
	var along_b := 0.0
	var acc := 0.0
	for i in range(1, rb.size()):
		var p0: Vector3 = rb[i - 1]
		var p1: Vector3 = rb[i]
		var seg := flat_dist(p0, p1)
		for k in 41:
			var q := p0.lerp(p1, k / 40.0)
			var rel := q - (ra[0] as Vector3)
			rel.y = 0.0
			var perp := (rel - dir * rel.dot(dir)).length()
			if perp < best_d:
				best_d = perp
				cross = (ra[0] as Vector3) + dir * rel.dot(dir)
				along_b = acc + seg * k / 40.0
		acc += seg
	var slide_to_cross := flat_dist(cross, (ra[0] as Vector3) + dir * step_d)
	var t_a := t_step + slide_to_cross / SLIDE_SPEED
	var t_b := along_b / RUSH_SPEED
	var tau := (_clock - _prep_t0) * DEMO_SPEED
	var t_end := t_a + 0.4
	if Input.is_physical_key_pressed(KEY_SPACE) and tau < t_end + DEMO_HOLD * DEMO_SPEED:
		_prep_t0 -= 100.0      # 空白鍵跳過示範
		tau = 1e9
	if tau > t_end + DEMO_HOLD * DEMO_SPEED or tau < 0.0:
		if _demo_caption_text != "" and _demo_caption_text != "換你了！（Tab：從上面看秒數）":
			_demo_caption_text = "換你了！（Tab：從上面看秒數）"
			toast(_demo_caption_text, 3.0)
		return
	var tt := minf(tau, t_end)
	# 阿土虛影
	var pa: Vector3
	if tt < t_step:
		pa = (ra[0] as Vector3) + dir * (tt * RUSH_SPEED)
	else:
		pa = (ra[0] as Vector3) + dir * (step_d + (tt - t_step) * SLIDE_SPEED)
	var pb := _along(rb, tt * RUSH_SPEED)
	var ghost := Color(1, 1, 1, 0.85)
	_demo_ring(pa, 0.55, ghost)
	_demo_ring(pb, 0.55, Color(0.75, 0.9, 1.0, 0.85))
	# 示範的香蕉皮位置＋已經滑過的黃線格子
	_demo_ring((ra[0] as Vector3) + dir * peel_d, 0.3, Color(1.0, 0.92, 0.25, 0.9))
	if tt > t_step:
		var slid := (tt - t_step) * SLIDE_SPEED
		var s0 := (ra[0] as Vector3) + dir * step_d
		_solid(im, s0, s0 + dir * slid, Color(1.0, 0.92, 0.25, 0.9), 0.08)
		var k := 1
		while k * SLIDE_SPEED * 0.5 <= slid:
			var q := s0 + dir * (k * SLIDE_SPEED * 0.5)
			_solid(im, q - dir.cross(Vector3.UP) * 0.35, q + dir.cross(Vector3.UP) * 0.35, Color(1.0, 0.92, 0.25, 1.0), 0.07)
			k += 1
	if tau < t_end:
		_demo_label(0, pa + Vector3(0, 1.5, 0), a_f.name)
		_demo_label(1, pb + Vector3(0, 1.5, 0), b_f.name)
		_demo_caption("示範（空白鍵跳過）")
	else:
		_demo_caption("%s太早到！要同時到才撞得到" % a_f.name)
		_demo_done_t = _clock

func _demo_ring(c: Vector3, r: float, col: Color) -> void:
	var pts: Array = []
	for k in 21:
		var a := k * TAU / 20.0
		pts.append(ground(c + Vector3(cos(a), 0, sin(a)) * r))
	_dashes(_route_line.mesh as ImmediateMesh, pts, col, 0.06)

func _demo_label(i: int, pos: Vector3, text: String) -> void:
	while _demo_labels.size() <= i:
		var l := Label3D.new()
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		l.font_size = 56
		l.pixel_size = 0.0005
		l.fixed_size = true
		l.outline_size = 20
		l.outline_modulate = Color(0.05, 0.08, 0.15, 1.0)
		l.modulate = Color(1.0, 0.97, 0.8)
		world.add_child(l)
		_demo_labels.append(l)
		_plate(l, "ice")
	var lb: Label3D = _demo_labels[i]
	lb.text = text
	lb.position = pos
	lb.visible = true

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
	s.content_margin_left = 44
	s.content_margin_top = 22
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

# ---------------------------------------------------------------- 美術第二輪：工人造型、結算卡

## 工人換上高彩度的背心和安全帽（在藍白色的場地上一眼看得到；每個人一種顏色，不用名牌也分得出來）
func _dress(f: Fighter, i: int) -> void:
	var is_guard: bool = f.get_meta("guard", false)
	var vest: Color = Color("c0392b") if is_guard else VEST[i % VEST.size()]
	var hat: Color = Color("34495e") if is_guard else Color("ffd23f")
	for m in f.node.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null:
			continue
		for si in mi.mesh.get_surface_count():
			var mat := mi.get_active_material(si)
			if not (mat is BaseMaterial3D):
				continue
			var col = null
			match String(mat.resource_name):
				"Brown":
					col = vest
				"Beige":
					col = hat
				"LightBlue":
					col = Color("3d4f66")
			if col != null:
				var d := (mat as BaseMaterial3D).duplicate() as BaseMaterial3D
				d.albedo_color = col
				d.roughness = 1.0
				mi.set_surface_override_material(si, d)

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
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	_card = v
	_summary_panel.add_child(v)
	var stars := HBoxContainer.new()
	stars.alignment = BoxContainer.ALIGNMENT_CENTER
	stars.add_theme_constant_override("separation", 14)
	v.add_child(stars)
	for c in list:
		var st := Label.new()
		var got: bool = best.has(c.id)
		st.text = "★"
		st.label_settings = UISkin.ls(76, Color("f6c445") if got else Color(0.82, 0.8, 0.74), 10 if got else 0, UISkin.INK)
		stars.add_child(st)
	for c in list:
		var got2: bool = best.has(c.id)
		var row := Label.new()
		row.text = ("✓ " if got2 else "・ ") + String(c.text)
		row.label_settings = UISkin.ls(24, UISkin.INK if got2 else Color(UISkin.INK, 0.5))
		v.add_child(row)
		if not got2 and String(c.get("hint", "")) != "":
			var hint_l := Label.new()
			hint_l.text = "　　" + String(c.hint)
			hint_l.label_settings = UISkin.ls(17, Color(UISkin.INK, 0.55))
			v.add_child(hint_l)
	var btns := HBoxContainer.new()
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	btns.add_theme_constant_override("separation", 12)
	v.add_child(btns)
	var go := Label.new()
	go.text = "下一關 ▶　Enter"
	go.label_settings = UISkin.ls(26, Color(1, 1, 1))
	UISkin.pill(go, Color("58b85a"), Color("2f7a33"), Color(1, 1, 1))
	btns.add_child(go)
	for t in ["R 重來", "M 地圖"]:
		var b := Label.new()
		b.text = t
		b.label_settings = UISkin.ls(20, UISkin.INK)
		UISkin.pill(b)
		btns.add_child(b)
	_summary_panel.visible = true
