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

const BIRD_WALK := 2.3         # 家豪走路的速度
const BIRD_RUN := 4.5          # 擋路的人都解決了：家豪衝向籠子
const RUSH_SPEED := 2.1        # 工人衝刺的速度
const CATCH := 1.1             # 碰到家豪的距離
const LUNGE_R := 2.6           # 守衛撲過來的距離
const CAGE_REACH := 2.7        # 籠子變大了，走到籠門前就算
const ON_ROUTE := 0.75         # 香蕉皮離路線多近算「在路線上」
const LIFT_TIME := 0.9         # 被抓住之後拎起來晃多久才結束
const WIN_SHOW := 3.2          # 過關演出幾秒後才跳結算

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
	bird.node.scale = Vector3.ONE * 1.35
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
	_bird_tag.font_size = 64
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
	_list_label = _panel_label(box, 24)
	_how_label = _panel_label(box, 19)
	_goal_label = Label.new()
	_goal_label.text = "救出企鵝！"
	_goal_label.add_theme_font_size_override("font_size", 52)
	_goal_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_goal_label.add_theme_constant_override("outline_size", 16)
	_goal_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	_goal_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_goal_label.offset_top = 100
	_goal_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_goal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_list_layer.add_child(_goal_label)
	var hint := get_node_or_null("../HUD/Hint") as Label
	if hint:
		hint.text = "滑鼠 看　WASD／空白／Shift 移動　左鍵 丟道具　Enter 開始　R 重來　F 快轉"
	_hint_until = Time.get_ticks_msec() + 12000

func _mesh_node(m: Material) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.mesh = ImmediateMesh.new()
	n.material_override = m
	n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(n)
	return n

func _panel_label(parent: Control, size: int) -> Label:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.1, 0.14, 0.75)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 16
	sb.content_margin_right = 18
	sb.content_margin_top = 10
	sb.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", sb)
	parent.add_child(panel)
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
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
	toast("工人衝過來了！", 0.8)
	(_how_label.get_parent() as Control).visible = false   # 開打後收起說明

func _prepare_hint() -> String:
	return "準備中：先想好香蕉皮丟在紅線的哪一段　按 Enter 開始"

func _update_phase_label() -> void:
	match phase:
		Phase.PREPARE:
			_phase_label.text = _prepare_hint()
		Phase.RUNNING:
			_phase_label.text = "救援中　%.1f 秒　｜　R 重來" % time
		Phase.ENDED:
			_phase_label.text = ("按 Enter 下一關　｜　R 再玩一次" if outcome == "win" else "按 R 再試一次")

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
	var lines: PackedStringArray = ["整人清單"]
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
	super(f)
	falls += 1
	mark("fall1")
	if falls >= 2:
		mark("fall2")
	if f.data.get("guard", false) and f.data.get("was_hit", false):
		mark("guard_carom")
	if _cut_cam and _cut_cam.current:
		_cut_t = maxf(_cut_t, 0.9)

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
	for l in _labels:
		if is_instance_valid(l.node):
			l.node.queue_free()
	_labels.clear()
	if result == "win":
		# 先演：籠門打開、企鵝衝出來圍著家豪，家豪轉向鏡頭；WIN_SHOW 秒後才從右邊跳結算
		_summary_panel.visible = false
		_summary_pending = true
		if world.has_method("open_cage"):
			world.open_cage(bird.pos)
		bird.yaw = 0.0
		bird.air = 0.0
		_cut_to(bird.pos + Vector3(0, 0.9, -0.6), Vector3(2.6, 1.6, 5.2), 99.0)
		pop_label("……可以回家了嗎", bird.pos + Vector3(0, 2.0, 0), Color(1, 1, 1), 3500, bird)

func _level_step_ended(dt: float) -> void:
	super(dt)
	_ended_t += dt
	if world.has_method("tick_cage"):
		world.tick_cage(dt)
	if _summary_pending and _ended_t >= WIN_SHOW:
		_summary_pending = false
		_summary_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
		_summary_panel.offset_right = -40
		_summary_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		_summary_panel.visible = true

func _win_line() -> String:
	var best := _best()
	var s := ""
	for c in _checklist():
		s += "★" if best.has(c.id) else "☆"
	var news: PackedStringArray = []
	for c in _checklist():
		if _new_stars.has(c.id):
			news.append("新！" + String(c.text))
	return "企鵝救出來了！　%s%s\n按 Enter 下一關" % [s, ("\n" + "\n".join(news)) if not news.is_empty() else ""]

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
	_defeat_detail.text = "家豪被%s抓住了　｜　第 %d 次嘗試\n%s\nR 重試　｜　M 回到地圖" % [
		_caught_by if _caught_by != "" else "工人", attempts.size(), _defeat_tip()]

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
			return
		"lifted":
			# 被工人拎在胸前：腳懸空亂踢
			if _catcher:
				var fw := Vector3(sin(_catcher.yaw), 0, cos(_catcher.yaw))
				b.pos = ground(_catcher.pos + fw * 0.75)
				b.yaw = _catcher.yaw + PI
			b.air = minf(b.t * 4.0, 1.25)
			b.yaw += sin(b.t * 40.0) * 0.3   # 被拎著亂扭
			if b.t >= LIFT_TIME:
				b.hp = 0.0
				b.set_state("dead")
				b.air = 0.0
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
					toast("沒人擋了！家豪衝向籠子", 1.2)
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
	if bird.state == "lifted":
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
			var ip = intercept_point(f)
			if ip == null:
				f.set_state("giveup")
				log_event("%s追不上了" % f.name)
				pop_label("追不上了…", f.pos + Vector3(0, 3.0, 0), Color(0.85, 0.85, 0.85), 1500, f)
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
			anim(f, "Idle")
			log_event("%s抓住了家豪" % f.name)
			pop_label("……", bird.pos + Vector3(0, 3.0, 0), Color(1, 1, 1), 1500, bird)
			var fw := Vector3(sin(f.yaw), 0, cos(f.yaw))
			_cut_to(f.pos + fw * 0.75 + Vector3(0, 1.4, 0), fw * 3.6 + Vector3(1.2, 0.6, 0), LIFT_TIME + 3.0)
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
		_cut_to(mid + Vector3(0, 0.6, 0), side * span * 0.9 + Vector3(0, span * 0.55 + 1.5, 0) + Vector3(0, 0, 1.0), minf(span / SLIDE_SPEED + 1.0, 2.6))
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
	var ip = intercept_point(f)
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
				log_event("雪人的頭掉下來扣在%s頭上" % f.name)
				pop_label("咚！", f.pos + Vector3(0, 3.4, 0), Color(1, 1, 1), 900, f)
				sfx("crack")
				break
	if r.kind != "hit":
		super(f, dt)
		return
	var o: Fighter = r.other
	log_event("%s撞到%s，連環撞！" % [f.name, o.name])
	pop_label("連環撞！", o.pos + Vector3(0, 3.6, 0), Color(1, 0.85, 0.2), 900, o)
	start_slide(o, f.data.sdir)
	o.data.hit_by = f
	_on_carom(f, o)
	_slowmo_until = Time.get_ticks_msec() + 250   # 撞上的瞬間頓一下
	_shake_until = Time.get_ticks_msec() + 300

# ---------------------------------------------------------------- 鏡頭特寫

func _cut_to(target: Vector3, offset: Vector3, sec: float) -> void:
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
	# 救企鵝模式不用血條、不用右上角敵人欄
	for f in all_fighters():
		if f.bar:
			f.bar.visible = false
	if not _enemy_rows.is_empty():
		var col: Control = (_enemy_rows[0].face as Control).get_parent().get_parent()
		col.visible = false
	var hint := get_node_or_null("../HUD/Hint") as Label
	if hint:
		hint.visible = not cut and (Time.get_ticks_msec() < _hint_until or Input.is_physical_key_pressed(KEY_H))
	if crosshair:
		crosshair.visible = not cut
	if cut and _preview:
		_preview.visible = false
		for d in _dots:
			d.visible = false
	_bird_tag.visible = phase != Phase.ENDED and bird.alive() and not cut
	_bird_tag.position = bird.pos + Vector3(0, 2.4 + bird.air, 0)
	_bird_ring.position = bird.pos + Vector3(0, 0.06, 0)
	_bird_ring.visible = bird.alive() and phase != Phase.ENDED and not cut
	for f in enemies:
		(_intents[f] as Label3D).visible = (_intents[f] as Label3D).visible and not cut
	if _how_label and cut:
		(_how_label.get_parent() as Control).visible = false
	if _list_label:
		(_list_label.get_parent() as Control).visible = not cut and not defeat_shown
	_path_line.visible = not cut
	_route_line.visible = not cut
	_peel_line.visible = not cut
	for f in _guard_labels:
		var gl: Label3D = _guard_labels[f]
		var show_g: bool = not cut and f.alive() and f.state in ["guard", "idle", "patrol"] and phase != Phase.ENDED
		gl.visible = show_g
		if show_g:
			gl.position = lunge_point(f) + Vector3(0, 0.9, 0)
	for f in enemies:
		var hat = f.data.get("snow_hat")
		if hat and is_instance_valid(hat):
			(hat as Node3D).global_position = f.pos + Vector3(0, 2.75 + f.air, 0)
	_draw_path()
	_draw_routes()
	_draw_placed_peels()

func _draw_path() -> void:
	var im := _path_line.mesh as ImmediateMesh
	im.clear_surfaces()
	if phase == Phase.ENDED:
		return
	var pts: Array = [bird.pos]
	for i in range(path_i, path.size()):
		pts.append(ground(path[i]))
	pts.append(world.cage)
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	_dashes(im, pts, Color(1.0, 0.85, 0.25, 0.85), 0.11)
	im.surface_end()

## 工人的路線（紅色虛線、終點紅叉）、守衛的撲擊圈和撲過去的箭頭
func _draw_routes() -> void:
	var im := _route_line.mesh as ImmediateMesh
	im.clear_surfaces()
	if phase == Phase.ENDED:
		return
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
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
		var route := planned_route(f) if f.state != "chase" else _chase_line(f)
		if route.size() < 2:
			continue
		if f.data.get("guard", false) and f.state in ["guard", "idle", "patrol"]:
			# 守衛：橘色粗箭頭（撲過去的方向）
			var org := Color(1.0, 0.55, 0.15, 0.95)
			var a0: Vector3 = route[0]
			var a1: Vector3 = route[1]
			_dashes(im, [a0, a1], org, 0.14)
			var dirv := (a1 - a0)
			dirv.y = 0
			dirv = dirv.normalized()
			var sidev := dirv.cross(Vector3.UP) * 0.5
			var tip := a1 + Vector3(0, 0.13, 0)
			for v in [tip + dirv * 0.6, tip + sidev, tip - sidev]:
				im.surface_set_color(org)
				im.surface_add_vertex(v)
			continue
		_dashes(im, route, red, 0.09)
		var b: Vector3 = route.back()
		for v in [b + Vector3(-0.4, 0.12, -0.4), b + Vector3(-0.28, 0.12, -0.52), b + Vector3(0.52, 0.12, 0.28),
				b + Vector3(-0.4, 0.12, -0.4), b + Vector3(0.52, 0.12, 0.28), b + Vector3(0.4, 0.12, 0.4),
				b + Vector3(0.4, 0.12, -0.4), b + Vector3(0.52, 0.12, -0.28), b + Vector3(-0.28, 0.12, 0.52),
				b + Vector3(0.4, 0.12, -0.4), b + Vector3(-0.28, 0.12, 0.52), b + Vector3(-0.4, 0.12, 0.4)]:
			im.surface_set_color(red)
			im.surface_add_vertex(v)
	im.surface_end()

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
				im.surface_set_color(c)
				im.surface_add_vertex(v)

## 頭上只放一個小圖示，不放長字
func _update_intents() -> void:
	for f in enemies:
		var l: Label3D = _intents[f]
		if not f.alive() or phase == Phase.ENDED:
			l.visible = false
			continue
		l.visible = true
		var t := ""
		var c := Color(1, 1, 1)
		match f.state:
			"kslide":
				t = "哇啊啊！"
			"slip":
				t = "跌倒"
			"stunned":
				t = "暈"
			"guard":
				t = "守"
				c = Color(1.0, 0.5, 0.3)
			"rush", "chase", "lunge":
				t = "！"
				c = Color(1.0, 0.35, 0.25)
			_:
				t = ""
		l.text = t
		l.modulate = c
		l.position = f.pos + Vector3(0, 3.1 + f.air, 0)

## 一片香蕉皮放在 p，誰會踩到、會滑去哪（只預告到第一次撞到東西）
func peel_outcome(p: Vector3) -> Array:
	var out: Array = []
	for f in enemies:
		if not f.alive() or f.state in ["kslide", "slip", "stunned"]:
			continue
		var route := planned_route(f) if f.state != "chase" else _chase_line(f)
		for i in range(1, route.size()):
			var a: Vector3 = route[i - 1]
			var b: Vector3 = route[i]
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
				out.append({"pts": [], "end": p, "text": "雪地：只會跌倒", "color": Color(0.9, 0.9, 0.9)})
			else:
				var pr: Array = predict_slide(f, dir, ground(q))
				if not pr.is_empty():
					var r: Dictionary = pr[0]
					var tx := String(r.text)
					if tx.begins_with("✕"):
						r.text = "撲通！"
						r.color = Color(0.4, 0.8, 1.0)
					elif tx.begins_with("撞到雪") or tx.begins_with("撞牆"):
						r.text = "咚（撞到停下）"
						r.color = Color(0.9, 0.9, 0.9)
					elif tx.begins_with("撞到"):
						r.text = "撞！"
						r.color = Color(1.0, 0.85, 0.2)
					else:
						r.text = "停（滑到雪地）"
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
		results = peel_outcome(aim_point)
		if not preview_full:
			# 後面的關卡：只畫 1.5 公尺的方向箭頭，結果自己想
			for r in results:
				var pts: Array = r.pts
				if pts.size() >= 2:
					var a: Vector3 = pts[0]
					var d: Vector3 = (pts[1] - pts[0])
					d.y = 0
					d = d.normalized()
					r.pts = [a, a + d * 1.5]
					r.end = a + d * 1.5
				r.text = "→"
				r.color = Color(1.0, 0.92, 0.25)
	_draw_slides(im, results, Color(1.0, 0.92, 0.25, 0.95), 0.11)
	for i in _ends.size():
		var lb: Label3D = _ends[i]
		if i < results.size():
			lb.visible = true
			lb.text = results[i].text
			lb.modulate = results[i].color
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
		results.append_array(peel_outcome(pl.pos))
	_draw_slides(im, results, Color(1.0, 1.0, 1.0, 0.45), 0.07)

func _draw_slides(im: ImmediateMesh, results: Array, col: Color, w: float) -> void:
	var drew := false
	for r in results:
		var pts: Array = r.pts
		if pts.size() < 2:
			continue
		if not drew:
			im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
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
				im.surface_set_color(col)
				im.surface_add_vertex(v)
	if drew:
		im.surface_end()
