extends "res://levels/ice/billiards_battle.gd"
## 【救企鵝＋整人清單】
##
## 一眼就懂的目標：籠子裡關著企鵝（頭上寫「救我！」），家豪會沿著地上的黃色虛線自己走過去開籠子。
## 一開打工人就聽到警報，跑到家豪「前面」去攔（紅色虛線畫出他要去的位置），被碰到就輸。
## 你要讓工人出糗，讓家豪走到籠子。
##
##   - 家豪不打架，只會走路（他的路線一直畫在地上）
##   - 香蕉皮：工人在冰上踩到，會沿著他原本走的方向一路滑出去，前面有洞就掉進去、撞到別人就連環撞
##            （在雪地上只是滑倒躺一下）。瞄準時就畫出他會滑去哪
##   - 飼料：家豪聞到會先去吃再回到路線上（用來讓他等一下、繞一下）
##   - 整人清單：左上角列出這關可以做的事，做到就打勾；勾幾項就是幾顆星
## 小關的 battle.gd：extends 這個檔案，設定 _make_items()、_enemy_specs()、_checklist()。

const BIRD_WALK := 2.3         # 家豪走路的速度（比工人快一點：從後面追不上，只能從前面攔）
const CATCH := 1.1             # 工人碰到家豪的距離
const CAGE_REACH := 1.9

var path: Array = []
var path_i := 0
var falls := 0
var caroms := 0
var _done := {}                # 清單裡做到的 id
var _list_layer: CanvasLayer
var _list_label: Label
var _goal_label: Label
var _path_line: MeshInstance3D
var _intercept_line: MeshInstance3D

## 這關的整人清單：[{"id": ..., "text": ...}]。可用的 id：
##   rescue 救出企鵝　fall1 一個工人掉進冰洞　fall2 兩個工人掉進冰洞　carom 讓工人撞在一起
##   fast 在 time_fast 秒內救出　nofeed 不用飼料救出
func _checklist() -> Array:
	return [{"id": "rescue", "text": "救出企鵝"}]

var time_fast := 20.0

func worker(name: String, route: Array, extra := {}) -> Dictionary:
	var d := super(name, route, extra)
	d.reach = 0.8      # 工人不踢人，碰到家豪就抓住
	return d

# ---------------------------------------------------------------- 建立、重置

func _level_setup() -> void:
	super()
	avoid_thin = true
	path = world.bird_path.duplicate()
	_path_line = MeshInstance3D.new()
	_path_line.mesh = ImmediateMesh.new()
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_path_line.material_override = m
	_path_line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(_path_line)
	_intercept_line = MeshInstance3D.new()
	_intercept_line.mesh = ImmediateMesh.new()
	_intercept_line.material_override = m
	_intercept_line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(_intercept_line)
	_list_layer = CanvasLayer.new()
	_list_layer.layer = 5
	add_child(_list_layer)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.1, 0.14, 0.72)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 16
	sb.content_margin_right = 18
	sb.content_margin_top = 10
	sb.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", sb)
	panel.position = Vector2(20, 110)
	_list_layer.add_child(panel)
	_list_label = Label.new()
	_list_label.add_theme_font_size_override("font_size", 22)
	panel.add_child(_list_label)
	_goal_label = Label.new()
	_goal_label.text = "目標：救出企鵝！"
	_goal_label.add_theme_font_size_override("font_size", 46)
	_goal_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_goal_label.add_theme_constant_override("outline_size", 14)
	_goal_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	_goal_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_goal_label.offset_top = 120
	_goal_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_goal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_list_layer.add_child(_goal_label)
	var hint := get_node_or_null("../HUD/Hint") as Label
	if hint:
		hint.text = "WASD 飄移｜空白 上升｜Shift 下降｜滑鼠 轉視角｜數字鍵 選道具｜左鍵 施放｜Enter 開始｜按住 F 快轉｜R 重來｜M 地圖"

func _level_reset() -> void:
	super()
	if world._cage_label:
		world._cage_label.text = "救我！"
	path_i = 0
	falls = 0
	caroms = 0
	_done.clear()
	if _goal_label:
		_goal_label.visible = true
	_refresh_list()

func _level_start() -> void:
	_goal_label.visible = false
	for f in enemies:
		aggro(f)
	toast("警報！工人發現家豪了", 1.4)
	pop_label("救出企鵝！", bird.pos + Vector3(0, 2.2, 0), Color(1, 0.9, 0.3), 1200, bird)

func _prepare_hint() -> String:
	return "準備中：家豪會沿著黃色虛線走去籠子，工人會來攔他　按 Enter 開始"

# ---------------------------------------------------------------- 整人清單

func mark(id: String) -> void:
	if _done.has(id) or not _checklist().any(func(c): return c.id == id):
		return
	_done[id] = true
	var text: String = _checklist().filter(func(c): return c.id == id)[0].text
	toast("☑ %s" % text, 1.8)
	sfx("win")
	log_event("整人清單：%s" % text)
	_refresh_list()

func stars() -> int:
	return _done.size()

func _refresh_list() -> void:
	if _list_label == null:
		return
	var lines: PackedStringArray = ["整人清單"]
	for c in _checklist():
		lines.append(("☑ " if _done.has(c.id) else "☐ ") + String(c.text))
	_list_label.text = "\n".join(lines)

func fall_in(f: Fighter) -> void:
	super(f)
	falls += 1
	mark("fall1")
	if falls >= 2:
		mark("fall2")

func _on_carom(_a: Fighter, _b: Fighter) -> void:
	caroms += 1
	mark("carom")

# ---------------------------------------------------------------- 輸贏

func _check_end() -> String:
	if bird.alive() and bird_near(world.cage, CAGE_REACH):
		mark("rescue")
		if world._cage_label:
			world._cage_label.text = "謝謝家豪！"
		if time <= time_fast:
			mark("fast")
		if not casts.any(func(c): return c.id == "feed"):
			mark("nofeed")
		return "win"
	if not bird.alive():
		return "lose"
	if time >= time_limit:
		log_event("天黑了")
		return "lose"
	return ""

func _win_line() -> String:
	var s := ""
	for k in _checklist().size():
		s += "★" if k < stars() else "☆"
	return "企鵝救出來了！　%s" % s

func _lose_line(_left: int) -> String:
	if time >= time_limit:
		return "天黑了，企鵝還關在籠子裡…"
	return "家豪被抓住了…"

func _defeat_title() -> String:
	return "家豪被抓去做成雞肉冰棒了……"

func _defeat_tip() -> String:
	return "提示：在工人前面丟香蕉皮，他在冰上會順著走的方向一路滑出去。瞄準時看黃線滑到哪。"

# ---------------------------------------------------------------- 家豪：沿路線走、聞到飼料先去吃

func _tick_bird(dt: float) -> void:
	var b := bird
	b.t += dt
	match b.state:
		"dead", "cheer":
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
			if path_i < path.size():
				var tgt: Vector3 = ground(path[path_i])
				if flat_dist(b.pos, tgt) < 0.3:
					path_i += 1
				else:
					_bird_walk(tgt, BIRD_WALK, dt, "charge")
			else:
				_bird_walk(world.cage, BIRD_WALK, dt, "charge")

# ---------------------------------------------------------------- 工人：碰到家豪就抓住；踩到香蕉皮在冰上會滑出去

func _level_step(dt: float) -> void:
	super(dt)
	if not bird.alive() or bird.air > 0.5:
		return
	for f in enemies:
		if f.alive() and f.state in ["walk", "windup", "recover", "alert"] and flat_dist(f.pos, bird.pos) < CATCH:
			bird.hp = 0.0
			bird.set_state("dead")
			log_event("%s抓住了家豪" % f.name)
			toast("被抓住了！", 1.6)
			return

## 工人追家豪：跑到家豪路線上「前面」的點去攔（不是追他現在的位置）
func _tick_melee(f: Fighter, dt: float) -> void:
	if f.state != "walk" or not f.aggro:
		super(f, dt)
		return
	f.t += dt
	_apply_knockback(f, dt)
	_walk(f, intercept_point(f), f.speed, dt)
	anim(f, "Walk")

## 攔截點：沿著家豪接下來要走的路往前看，找第一個工人能比家豪先到（或同時到）的點
func intercept_point(f: Fighter) -> Vector3:
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
		for k in range(1, n + 1):
			var q := a.lerp(b, float(k) / n)
			var t_bird := (walked + seg * float(k) / n) / BIRD_WALK
			var t_me := flat_dist(f.pos, q) / f.speed
			if t_me <= t_bird:
				return q
		walked += seg
	return bird.pos

## 工人往哪個方向走（踩到香蕉皮就往這個方向滑）
func heading(f: Fighter) -> Vector3:
	return Vector3(sin(f.yaw), 0.0, cos(f.yaw))

func make_slip(f: Fighter, what := "香蕉皮") -> void:
	if not f.is_bird and world.on_ice(f.pos.x, f.pos.z):
		log_event("%s踩到%s，在冰上一路滑出去" % [f.name, what])
		toast("滑出去了！", 1.2)
		start_slide(f, heading(f))
		return
	super(f, what)

# ---------------------------------------------------------------- 畫面：家豪的路線、工人頭上的意圖、香蕉皮的預告

func _process(dt: float) -> void:
	super(dt)
	_draw_path()
	_draw_intercepts()

## 每個在追的工人：紅色虛線畫到他要去攔家豪的位置
func _draw_intercepts() -> void:
	var im := _intercept_line.mesh as ImmediateMesh
	im.clear_surfaces()
	if phase != Phase.RUNNING:
		return
	var drew := false
	for f in enemies:
		if not f.alive() or not f.aggro or f.state != "walk":
			continue
		var a: Vector3 = f.pos
		var b: Vector3 = intercept_point(f)
		var d := flat_dist(a, b)
		if d < 0.5:
			continue
		if not drew:
			im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
			drew = true
		var side := (b - a)
		side.y = 0
		side = side.normalized().cross(Vector3.UP) * 0.08
		var n := maxi(int(d / 0.4), 1)
		for k in n:
			if k % 2 == 1:
				continue
			var p0 := ground(a.lerp(b, float(k) / n)) + Vector3(0, 0.11, 0)
			var p1 := ground(a.lerp(b, float(k + 1) / n)) + Vector3(0, 0.11, 0)
			for v in [p0 - side, p0 + side, p1 + side, p0 - side, p1 + side, p1 - side]:
				im.surface_set_color(Color(1.0, 0.25, 0.2, 0.9))
				im.surface_add_vertex(v)
		# 攔截點畫一個叉
		for v in [b + Vector3(-0.35, 0.12, -0.35), b + Vector3(-0.25, 0.12, -0.45), b + Vector3(0.45, 0.12, 0.25),
				b + Vector3(-0.35, 0.12, -0.35), b + Vector3(0.45, 0.12, 0.25), b + Vector3(0.35, 0.12, 0.35),
				b + Vector3(0.35, 0.12, -0.35), b + Vector3(0.45, 0.12, -0.25), b + Vector3(-0.25, 0.12, 0.45),
				b + Vector3(0.35, 0.12, -0.35), b + Vector3(-0.25, 0.12, 0.45), b + Vector3(-0.35, 0.12, 0.35)]:
			im.surface_set_color(Color(1.0, 0.25, 0.2, 0.95))
			im.surface_add_vertex(v)
	if drew:
		im.surface_end()

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
	var c := Color(1.0, 0.85, 0.25, 0.8)
	var dash := 0
	for i in range(1, pts.size()):
		var a: Vector3 = pts[i - 1]
		var b: Vector3 = pts[i]
		var n := maxi(int(flat_dist(a, b) / 0.35), 1)
		var side := (b - a)
		side.y = 0
		if side.length() < 0.01:
			continue
		side = side.normalized().cross(Vector3.UP) * 0.09
		for k in n:
			dash += 1
			if dash % 2 == 0:
				continue
			var p0 := ground(a.lerp(b, float(k) / n)) + Vector3(0, 0.1, 0)
			var p1 := ground(a.lerp(b, float(k + 1) / n)) + Vector3(0, 0.1, 0)
			for v in [p0 - side, p0 + side, p1 + side, p0 - side, p1 + side, p1 - side]:
				im.surface_set_color(c)
				im.surface_add_vertex(v)
	im.surface_end()

func _update_intents() -> void:
	for f in enemies:
		var l: Label3D = _intents[f]
		if not f.alive() or phase == Phase.ENDED:
			l.visible = false
			continue
		l.visible = true
		var t := ""
		var c := Color(0.85, 0.85, 0.85)
		match f.state:
			"kslide":
				t = "哇啊啊！"
				c = Color(1, 1, 1)
			"slip":
				t = "滑倒"
			"stunned":
				t = "暈…"
			"walk", "alert", "windup", "recover":
				t = "攔截！" if f.aggro else "…"
				c = Color(1.0, 0.35, 0.25)
			_:
				t = "巡邏中"
		l.text = t
		l.modulate = c
		l.position = f.pos + Vector3(0, 3.2 + f.air, 0)

## 瞄準香蕉皮時：如果工人正朝著準心走過去，就畫出他踩到之後會滑去哪
func _update_slide_preview() -> void:
	var im := _lines.mesh as ImmediateMesh
	im.clear_surfaces()
	var results: Array = []
	var aiming_banana: bool = phase != Phase.ENDED and aim_point != null and aim_error == "" \
		and not items.is_empty() and items[selected].id == "banana" and charges[selected] != 0
	if aiming_banana:
		for f in enemies:
			if not f.alive() or f.state in ["kslide", "slip", "stunned"]:
				continue
			var h := heading(f)
			var to: Vector3 = aim_point - f.pos
			to.y = 0.0
			var along := to.dot(h)
			var off := (to - h * along).length()
			if along < 0.2 or along > 9.0 or off > 0.9:
				continue
			if not world.on_ice(aim_point.x, aim_point.z):
				results.append({"pts": [], "end": aim_point, "text": "%s 會滑倒（雪地上不會滑出去）" % f.name, "color": Color(0.9, 0.9, 0.9)})
				continue
			results.append_array(predict_slide(f, h, ground(f.pos + h * along)))
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
			side = side.normalized().cross(Vector3.UP) * 0.11
			for v in [a - side, a + side, b + side, a - side, b + side, b - side]:
				im.surface_set_color(Color(1.0, 0.92, 0.25, 0.95))
				im.surface_add_vertex(v)
	if drew:
		im.surface_end()
	for i in _ends.size():
		var l: Label3D = _ends[i]
		if i < results.size():
			l.visible = true
			l.text = results[i].text
			l.modulate = results[i].color
			l.position = (results[i].end as Vector3) + Vector3(0, 1.2, 0)
		else:
			l.visible = false
