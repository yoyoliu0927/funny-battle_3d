extends "res://scripts/battle/battle_base.gd"
## 冰雪島共用戰局規則。各小關的 battle.gd 寫 extends "res://levels/ice/ice_battle.gd"。
##
## 冰雪島只有一條規則：冰雪對雞友善，對人類不友善。
##   - 雞不滑，人會滑：人在冰面上轉不了彎、停不下來（家豪完全不受影響）
##   - 雞不破，人會破：薄冰撐得住家豪，人一踩上去就裂開
##   - 人掉進冰洞就出局（凍成冰棒）；家豪遇到冰洞會拍翅飛過去
##   - 人穿著很厚的羽絨衣，家豪啄起來不太痛：正面打架贏不了，要靠冰把人整掉
## 另外每關有時間限制（天黑了就算輸），避免卡在打不完的局面。
##
## 操作回饋（每個小關都有）：
##   - 撒飼料：有聲音、家豪頭上冒「！」；家豪聞不到就直接說
##   - 瞄準飼料：畫出家豪聞得到的範圍（10 公尺）和他會走的路，誰追過來可能會掉進冰洞就標 ✕
##   - 人在冰上停不下來會喊、掉下去有慢動作和震動、按住 F 快轉

const FeedItem := preload("res://levels/ice/items/ice_feed_item.gd")
const Sfx := preload("res://levels/ice/sfx.gd")

const ICE_GRIP := 1.1          # 人在冰上的抓地力（越小越滑、越轉不了彎）
const SNOW_GRIP := 14.0        # 人在雪地上的抓地力（幾乎馬上就能轉向）
const MAX_SLIDE := 4.5         # 滑行速度上限
const CRACK_TIME := 0.3        # 薄冰從裂開到破掉
const SINK_TIME := 0.9
const SINK_DEPTH := 1.55       # 掉進冰洞後沉多深（從水面算；頭和肩膀露在水面上）
const AVOID_LOOK := [0.7, 1.4]   # 人往前看幾公尺有沒有冰洞
const SLOWMO_SCALE := 0.25
const SLOWMO_MS := 900
const FAST_SCALE := 3.0

## 每關的時間限制（秒）；小關可以改
var time_limit := 90.0
## 人會不會想繞開看得到的冰洞（路線版設成 false：人只盯著路線走）
var avoid_holes := true
## 人走路時在冰上會不會滑（實驗玩法可以關掉，改用自己的滑行規則）
var walk_slides := true
## 瞄準飼料時要不要標「誰追過來可能掉進冰洞」（這個預告只看直線，不準；實驗玩法關掉）
var feed_hazard_marks := true
## 人走路時會不會也繞開看得到的薄冰（救企鵝模式打開：走路繞得開，滑出去就停不下來）
var avoid_thin := false
## 倒帶重播中：不出聲、不跳字、不慢動作
var silent := false
## 字和跳字用的時鐘：開打後跟著遊戲時間走，準備階段跟著真實時間走（慢動作、快轉、截圖都對得上）
var _clock := 0.0
var _toast_until := -1.0
var _warned_dark := false
var _players := {}
var _labels: Array = []        # 會自己消失的字 {node, until, start, follow, dy}
var _slowmo_until := 0
var _shake_until := 0
var _fallen := 0
var _ring: MeshInstance3D      # 瞄準飼料時：家豪聞得到的範圍
var _aim_marks: Array = []     # 瞄準飼料時：誰可能掉下去

## 冰雪島的人類：羽絨衣很厚（血多、啄不太痛），但動作慢、踢人不太痛（家豪撐得比較久，你有時間出手）
func worker(name: String, route: Array, extra := {}) -> Dictionary:
	var d := {"name": name, "route": route, "hp": 30.0, "speed": 1.8, "loop": false, "pause": 1.4,
		"kick_damage": 1.0, "heavy_damage": 2.0}
	d.merge(extra, true)
	return d

# ---------------------------------------------------------------- 建立、重置、輸贏

func _level_setup() -> void:
	var sounds := Sfx.make_all()
	for k in sounds:
		var p := AudioStreamPlayer.new()
		p.stream = sounds[k]
		p.max_polyphony = 4
		p.volume_db = -4.0
		add_child(p)
		_players[k] = p
	var hint := get_node_or_null("../HUD/Hint") as Label
	if hint:
		hint.text = "WASD 飄移｜空白 上升｜Shift 下降｜滑鼠 轉視角｜數字鍵／滾輪 選道具｜左鍵 施放｜Enter 開始｜按住 F 快轉｜R 重試｜M 地圖｜Esc 放開游標"
	_ring = MeshInstance3D.new()
	_ring.mesh = ImmediateMesh.new()
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rm.vertex_color_use_as_albedo = true
	rm.cull_mode = BaseMaterial3D.CULL_DISABLED
	_ring.material_override = rm
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(_ring)
	for i in 6:
		var l := Label3D.new()
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		l.font_size = 72
		l.pixel_size = 0.00044
		l.fixed_size = true   # 固定在畫面上的大小，鏡頭拉近也不會變巨大
		l.outline_size = 22
		l.outline_modulate = Color(0.1, 0.05, 0.05, 0.9)
		l.visible = false
		world.add_child(l)
		_aim_marks.append(l)

func _level_reset() -> void:
	world.reset_ice()
	_warned_dark = false
	_labels.clear()      # 字放在 fx_root 底下，已經被一起刪掉了
	_fallen = 0
	Engine.time_scale = 1.0

func _exit_tree() -> void:
	Engine.time_scale = 1.0

func _check_end() -> String:
	var r := super()
	if r != "":
		return r
	if time >= time_limit:
		log_event("天黑了")
		return "lose"
	if not _warned_dark and time >= time_limit - 15.0:
		_warned_dark = true
		toast("天快黑了！", 1.6)
	return ""

func _end(result: String) -> void:
	super(result)
	sfx("win" if result == "win" else "caught")
	if result == "lose":
		_slowmo_until = Time.get_ticks_msec() + SLOWMO_MS

func _lose_line(left: int) -> String:
	if time >= time_limit:
		return "天黑了，家豪冷得受不了…（還剩 %d 個人）" % left
	return super(left)

func _defeat_title() -> String:
	return "家豪被抓去當晚餐了……"

func _defeat_tip() -> String:
	return "提示：人在冰上轉不了彎。讓家豪在冰洞旁邊急轉彎，追過來的人就會滑進去。"

# ---------------------------------------------------------------- 家豪：飼料一撒下去就有反應

## 飼料優先：家豪正在出招或挨打時，一看到飼料也會馬上丟下手邊的事跑去吃
func _tick_bird(dt: float) -> void:
	if not feeds.is_empty() and bird.state in ["windup", "recover", "hop", "land"] and _nearest_feed(bird.pos, FEED_SENSE) >= 0:
		bird.set_state("charge")
	super(dt)

## 撒下飼料的瞬間（ice_feed_item.gd 會呼叫）
func on_feed_cast(p: Vector3) -> void:
	sfx("pop")
	sfx("drop")
	if flat_dist(bird.pos, p) > FEED_SENSE:
		var msg := "家豪還聞不到（跑近了才會聞到）" if phase == Phase.PREPARE else "太遠了，家豪聞不到"
		pop_label(msg, p + Vector3(0, 1.4, 0), Color(0.85, 0.85, 0.85), 1600)
	else:
		pop_label("！", bird.pos + Vector3(0, 2.0, 0), Color(1, 0.9, 0.3), 800, bird)

# ---------------------------------------------------------------- 人在冰上滑

func _tick_enemy(f: Fighter, dt: float) -> void:
	if f.data.get("sunk", false):
		_tick_sunk(f, dt)
		return
	if not f.alive():
		super(f, dt)
		return
	if world.in_water(f.pos.x, f.pos.z):
		fall_in(f)
		return
	var before := f.pos
	super(f, dt)   # 一般的 AI 決定「想往哪走」
	if not f.alive():
		return
	var want := (f.pos - before) / dt
	want.y = 0.0
	if _avoids_holes(f):
		want = _steer_around_holes(before, want)
	var on_ice: bool = walk_slides and world.on_ice(before.x, before.z)
	var vel: Vector3 = f.data.get("vel", Vector3.ZERO)
	vel = vel.lerp(want, 1.0 - exp(-(ICE_GRIP if on_ice else SNOW_GRIP) * dt))
	if vel.length() > MAX_SLIDE:
		vel = vel.normalized() * MAX_SLIDE
	var nxt: Vector3 = world.clamp_play(_avoid(before, before + vel * dt, 0.5))
	if fence_crossing(before, nxt) != null:
		vel = Vector3.ZERO
		nxt = before
	f.pos = ground(nxt)
	f.data.vel = vel
	var sliding := on_ice and vel.length() > 0.5 and (want - vel).length() > 0.8
	if sliding and not f.data.get("sliding", false) and f.aggro:
		log_event("%s在冰上停不下來" % f.name)
	f.data.sliding = sliding
	if world.in_water(f.pos.x, f.pos.z):
		fall_in(f)

## 這個人現在會不會繞開冰洞（關卡可以覆寫）
func _avoids_holes(_f: Fighter) -> bool:
	return avoid_holes

## 人看得到冰洞（已經破掉的冰）會想繞開；在雪地上繞得過去，在冰上就不一定了
func _steer_around_holes(from: Vector3, want: Vector3) -> Vector3:
	var spd := want.length()
	if spd < 0.05:
		return want
	var dir := want / spd
	if not _hole_ahead(from, dir):
		return want
	for ang in [0.6, -0.6, 1.1, -1.1, 1.6, -1.6]:
		var d2 := dir.rotated(Vector3.UP, ang)
		if not _hole_ahead(from, d2):
			return d2 * spd
	return want

func _hole_ahead(from: Vector3, dir: Vector3) -> bool:
	for d in AVOID_LOOK:
		var p: Vector3 = from + dir * d
		if world.in_water(p.x, p.z):
			return true
		if avoid_thin and world.thin_at(p.x, p.z, -0.2) >= 0:
			return true
	return false

## 掉進冰洞：沉下去只剩頭，出局（慢動作、震動、撲通）
func fall_in(f: Fighter) -> void:
	# 冰洞底下的地形是挖下去的：從水面高度開始沉，頭才會留在水面上
	if world.has_method("water_surface_y"):
		f.pos.y = world.water_surface_y(f.pos.x, f.pos.z)
	f.hp = 0.0
	f.set_state("dead")
	f.kb_vel = Vector3.ZERO
	f.data.vel = Vector3.ZERO
	f.data.sunk = true
	f.data.sink_t = 0.0
	anim(f, "HitRecieve", 0.6)
	spawn_splash(f.pos)
	_fallen += 1
	toast("撲通！　落水 %d / %d" % [_fallen, enemies.size()], 1.6)
	log_event("%s掉進冰洞，凍成冰棒了" % f.name)
	sfx("splash")
	if not silent:
		_slowmo_until = Time.get_ticks_msec() + SLOWMO_MS
		_shake_until = Time.get_ticks_msec() + 450

func _tick_sunk(f: Fighter, dt: float) -> void:
	f.data.sink_t = f.data.sink_t + dt
	var k := clampf(f.data.sink_t / SINK_TIME, 0.0, 1.0)
	f.air = -SINK_DEPTH * (1.0 - pow(1.0 - k, 3.0)) + sin(f.data.sink_t * 3.0) * 0.04 * k

# ---------------------------------------------------------------- 薄冰、慘叫

## 字卡：同一時間只有一則，時間到就消失（用遊戲時鐘）
func toast(text: String, dur: float) -> void:
	super(text, dur)
	_toast_until = _clock + dur if text != "" else -1.0

func _tick_clock(dt: float) -> void:
	_clock += dt
	if _toast_until >= 0.0 and _clock >= _toast_until:
		_toast_until = -1.0
		if _toast_label:
			_toast_label.text = ""
			_toast_label.visible = false

func _level_step_ended(dt: float) -> void:
	super(dt)
	_tick_clock(dt)

func _level_step(dt: float) -> void:
	_tick_clock(dt)
	for i in world.thin.size():
		var th: Dictionary = world.thin[i]
		match th.state:
			"solid":
				for f in enemies:
					if f.alive() and f.air < 0.5 and flat_dist(f.pos, Vector3(th.center.x, 0, th.center.y)) < float(th.r) - 0.05:
						th.state = "cracking"
						th.t = 0.0
						toast("喀啦……", 0.8)
						log_event("%s腳下的薄冰裂開了" % f.name)
						sfx("crack")
						break
			"cracking":
				th.t += dt
				if th.t >= CRACK_TIME:
					world.break_thin(i)
					log_event("薄冰破了！")
	# 追人追到在冰上停不下來：喊一聲
	for f in enemies:
		if not f.alive():
			continue
		var sl: bool = f.data.get("sliding", false) and f.aggro and (f.data.get("vel", Vector3.ZERO) as Vector3).length() > 1.2
		if sl and not f.data.get("yelled", false):
			f.data.yelled = true
			sfx("yell")
			pop_label("哇啊啊！", f.pos + Vector3(0, 3.0, 0), Color(1, 1, 1), 1100, f)
		elif not f.data.get("sliding", false):
			f.data.yelled = false

func _level_visuals() -> void:
	# 裂開中的薄冰抖一抖
	for th in world.thin:
		if th.state == "cracking":
			(th.node as Node3D).position = th.base + Vector3(sin(th.t * 90.0) * 0.04, 0, cos(th.t * 70.0) * 0.04)
	# 在冰上停不下來的人：身體往後仰、左右晃
	for f in enemies:
		if f.alive() and f.data.get("sliding", false):
			f.node.rotation = Vector3(-0.22, f.yaw, sin(time * 14.0) * 0.14)

# ---------------------------------------------------------------- 每一畫面：快轉、慢動作、震動、字、瞄準預告

func _process(dt: float) -> void:
	super(dt)
	if phase == Phase.PREPARE:
		_tick_clock(dt)
	var now := Time.get_ticks_msec()
	var scale := 1.0
	if phase == Phase.RUNNING and Input.is_physical_key_pressed(KEY_F):
		scale = FAST_SCALE
	if now < _slowmo_until:
		scale = SLOWMO_SCALE
	Engine.time_scale = scale
	if now < _shake_until:
		var k := float(_shake_until - now) / 450.0
		camera.h_offset = sin(now * 0.11) * 0.09 * k
		camera.v_offset = cos(now * 0.13) * 0.07 * k
	else:
		camera.h_offset = 0.0
		camera.v_offset = 0.0
	_update_labels(now)
	_update_feed_preview()

## 瞄準飼料時：畫出家豪聞得到的範圍；追過來的人如果會經過冰洞或薄冰，就標 ✕
func _update_feed_preview() -> void:
	var on: bool = phase != Phase.ENDED and aim_point != null and not items.is_empty() \
		and items[selected].id == "feed" and not defeat_shown
	var im := _ring.mesh as ImmediateMesh
	im.clear_surfaces()
	var marks: Array = []
	if on:
		var c := bird.pos
		var segs := 64
		im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in segs:
			if i % 2 == 1:
				continue
			var a0 := i * TAU / segs
			var a1 := (i + 1) * TAU / segs
			var p0 := c + Vector3(cos(a0), 0, sin(a0)) * FEED_SENSE
			var p1 := c + Vector3(cos(a1), 0, sin(a1)) * FEED_SENSE
			p0 = ground(p0) + Vector3(0, 0.1, 0)
			p1 = ground(p1) + Vector3(0, 0.1, 0)
			var side := (p1 - p0).normalized().cross(Vector3.UP) * 0.07
			for v in [p0 - side, p0 + side, p1 + side, p0 - side, p1 + side, p1 - side]:
				im.surface_set_color(Color(1.0, 0.85, 0.3, 0.6))
				im.surface_add_vertex(v)
		im.surface_end()
		if aim_error == "" and feed_hazard_marks:
			if flat_dist(bird.pos, aim_point) > FEED_SENSE:
				marks.append([aim_point, "家豪現在聞不到", Color(0.85, 0.85, 0.85)])
			else:
				# 追家豪的人會直直衝向他：從每個人到飼料的直線上，有冰洞或薄冰就標出來
				var hits := {}
				for f in enemies:
					if not f.alive():
						continue
					var h: Variant = _first_hazard(f.pos, aim_point)
					if h != null:
						var key := "%d,%d" % [roundi(h[0].x), roundi(h[0].z)]
						if not hits.has(key):
							hits[key] = [h[0], h[1], []]
						hits[key][2].append(f.name)
				for k in hits:
					var e: Array = hits[k]
					marks.append([e[0], "✕ %s 追過來\n可能%s" % ["、".join(e[2]), e[1]], Color(1.0, 0.3, 0.2)])
	for i in _aim_marks.size():
		var l: Label3D = _aim_marks[i]
		if i < marks.size():
			l.visible = true
			l.text = marks[i][1]
			l.modulate = marks[i][2]
			l.position = (marks[i][0] as Vector3) + Vector3(0, 1.0, 0)
		else:
			l.visible = false

## 從 a 直線走到 b，第一個會出事的地方：[位置, "掉進冰洞" / "踩破薄冰"]，沒有回傳 null
func _first_hazard(a: Vector3, b: Vector3) -> Variant:
	var d := flat_dist(a, b)
	var n := maxi(int(d / 0.25), 1)
	for k in range(1, n + 1):
		var q := a.lerp(b, float(k) / n)
		if world.in_water(q.x, q.z):
			return [ground(q), "掉進冰洞"]
		var ti: int = world.thin_at(q.x, q.z, 0.1)
		if ti >= 0 and world.thin[ti].state == "solid":
			return [ground(q), "踩破薄冰"]
	return null

# ---------------------------------------------------------------- 小工具

## 家豪有沒有走到某個地方
func bird_near(p: Vector3, r: float) -> bool:
	return bird.alive() and bird.air < 0.5 and flat_dist(bird.pos, p) <= r

func sfx(name: String) -> void:
	if silent:
		return
	var p: AudioStreamPlayer = _players.get(name)
	if p:
		p.play()

## 在空中跳出一行字（follow = 跟著某個角色）
func pop_label(text: String, pos: Vector3, color: Color, ms: int, follow: Fighter = null) -> void:
	if silent:
		return
	var l := Label3D.new()
	l.text = text
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.font_size = 72
	l.pixel_size = 0.00055
	l.fixed_size = true   # 固定在畫面上的大小，鏡頭拉近也不會變巨大
	l.outline_size = 16
	l.modulate = color
	l.position = pos
	fx_root.add_child(l)
	_labels.append({"node": l, "until": _clock + ms / 1000.0, "start": _clock, "follow": follow,
		"dy": pos.y - (follow.pos.y if follow else pos.y)})

func _update_labels(_now: int) -> void:
	for i in range(_labels.size() - 1, -1, -1):
		var e: Dictionary = _labels[i]
		var l = e.node
		if not is_instance_valid(l) or _clock >= float(e.until):
			if is_instance_valid(l):
				l.queue_free()
			_labels.remove_at(i)
			continue
		var rise := (_clock - float(e.start)) * 0.5
		if e.follow:
			var f: Fighter = e.follow
			l.position = f.pos + Vector3(0, float(e.dy) + f.air + rise, 0)
