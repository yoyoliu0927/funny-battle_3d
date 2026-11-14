extends "res://levels/ice/ice_battle.gd"
## 【實驗 A】冰上撞球：家豪是球桿，人類是球，冰洞是球袋。
##
##   - 人穿著很厚的羽絨衣：平常啄他只會「噗」一聲，沒用
##   - 人露出「破綻」時被啄＝會心一擊：扣一顆心，而且被啄飛，沿著「家豪 → 他」的方向直線滑到底
##       冰上：一直滑，滑進冰洞或踩破薄冰就出局；撞到別人就把別人撞出去（連環撞）；撞到東西會暈一下
##       雪地：滑一小段就停
##   - 破綻怎麼來：香蕉皮讓他滑倒、偷襲嚇他一跳、他重踢落空（用飼料把家豪拉開）
##     （被撞暈、滑停下來都不算破綻：不然家豪會一直連續會心，瞄準就沒意義了）
##   - 每個人頭上顯示下一招（追、踢、重踢倒數、破綻倒數）和剩幾顆心
##   - 有人露出破綻時，畫出「家豪現在啄下去，他會滑到哪」；瞄準飼料時改畫「家豪從飼料那邊過去啄，他會滑到哪」
## 心掉光也會倒下，但冰洞才是主要的勝利方式。

const BananaItem := preload("res://scripts/items/banana_item.gd")

const SLIDE_SPEED := 6.0       # 被啄飛的滑行速度
const SNOW_SLIDE := 1.2        # 在雪地上滑多遠就停
const STUN_TIME := 1.2         # 被啄飛停下來後暈多久（不是破綻）
const OPEN_SLIP := 5.0         # 踩到香蕉皮躺多久（破綻）
const CRIT_SEEK := 9.0         # 家豪會主動衝過去啄多遠內的破綻
const HIT_R := 0.95            # 滑行中撞到別人的距離
const HEARTS := 3

var _intents := {}             # Fighter -> Label3D
var _lines: MeshInstance3D     # 預告滑行路線
var _ends: Array = []          # 預告終點的字

func worker(name: String, route: Array, extra := {}) -> Dictionary:
	var d := super(name, route, extra)
	d.hp = float(extra.get("hp", HEARTS))
	return d

# ---------------------------------------------------------------- 建立、重置

## 家豪的血（撞球模式要打好幾桿，給他多一點時間）
const BIRD_HP := 15.0

func _level_setup() -> void:
	super()
	bird.max_hp = BIRD_HP
	walk_slides = false
	feed_hazard_marks = false
	for f in enemies:
		var l := Label3D.new()
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		l.font_size = 64
		l.pixel_size = 0.00062
		l.fixed_size = true   # 固定在畫面上的大小，鏡頭拉近也不會變巨大
		l.outline_size = 16
		l.outline_modulate = Color(0, 0, 0, 0.85)
		world.add_child(l)
		_intents[f] = l
	_lines = MeshInstance3D.new()
	_lines.mesh = ImmediateMesh.new()
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.no_depth_test = true
	_lines.material_override = m
	_lines.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(_lines)
	for i in 6:
		var l := Label3D.new()
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		l.font_size = 64
		l.pixel_size = 0.00068
		l.fixed_size = true   # 固定在畫面上的大小，鏡頭拉近也不會變巨大
		l.outline_size = 18
		l.outline_modulate = Color(0, 0, 0, 0.85)
		l.visible = false
		world.add_child(l)
		_ends.append(l)

func _level_reset() -> void:
	super()
	bird.fled_half = true   # 拿掉「半血自動飛走」：只有被重踢才會飛走（重踢有倒數，看得到）
	_slowmo_until = 0
	_shake_until = 0

func _defeat_tip() -> String:
	return "提示：等頭上出現「破綻」再讓家豪啄。用飼料決定家豪從哪個方向啄過去，人會往反方向滑。"

# ---------------------------------------------------------------- 破綻與會心

func _farmer_open(f: Fighter) -> bool:
	return super(f) and f.state != "stunned"

## 家豪優先去啄有破綻的人
func nearest_enemy(from: Vector3) -> Fighter:
	var best: Fighter = null
	var bd := CRIT_SEEK
	for f in enemies:
		if f.alive() and _farmer_open(f):
			var d := flat_dist(from, f.pos)
			if d < bd:
				bd = d
				best = f
	return best if best else super(from)

## 附近有人露出破綻：家豪一口吞掉飼料、不發呆，馬上衝過去啄（不然破綻會錯過）
func _tick_bird(dt: float) -> void:
	if bird.state in ["eat", "linger"]:
		for f in enemies:
			if f.alive() and _farmer_open(f) and flat_dist(bird.pos, f.pos) < CRIT_SEEK:
				if bird.state == "eat":
					var fi := _nearest_feed(bird.pos, 0.8)
					if fi >= 0:
						(feeds[fi].node as Node3D).queue_free()
						feeds.remove_at(fi)
						bird.hp = minf(bird.hp + FEED_HEAL, bird.max_hp)
						log_event("家豪一口吞掉飼料，衝向%s的破綻" % f.name)
				bird.set_state("charge")
				break
	super(dt)

func _hit_enemy(f: Fighter, _dmg: float, _from: Vector3) -> void:
	if not f.alive() or f.state == "kslide":
		return
	aggro(f)
	noise_at(f.pos)
	if _farmer_open(f):
		f.hp -= 1.0
		hit_spots.append(f.pos)
		var dir := f.pos - bird.pos
		dir.y = 0.0
		dir = dir.normalized() if dir.length() > 0.01 else Vector3.FORWARD
		log_event("會心一擊！%s被啄飛（剩 %d 顆心）" % [f.name, int(f.hp)])
		pop_label("會心！", f.pos + Vector3(0, 4.4, 0), Color(1, 0.85, 0.2), 900, f)
		sfx("crack")
		_shake_until = Time.get_ticks_msec() + 250
		start_slide(f, dir)
	else:
		pop_label("噗", f.pos + Vector3(0, 2.6, 0), Color(0.85, 0.85, 0.85), 450, f)
		log_event("家豪啄%s：羽絨衣太厚，沒用" % f.name)

## 偷襲：不扣血，但會嚇一跳愣住（破綻）
func _sneak(f: Fighter) -> void:
	noise_at(f.pos)
	f.aggro = true
	f.alert_t = -1.0
	f.heavy = false
	f.set_state("startled")
	f.yaw = _yaw_to(f.pos, bird.pos)
	anim(f, "HitRecieve", 0.8)
	log_event("家豪偷襲%s，嚇他一跳！" % f.name)
	pop_label("嚇！", f.pos + Vector3(0, 3.0, 0), Color(1, 0.9, 0.3), 700, f)

func start_slide(f: Fighter, dir: Vector3) -> void:
	f.data.erase("hit_by")
	f.set_state("kslide")
	f.data.sdir = dir
	f.data.snow = 0.0
	f.kb_vel = Vector3.ZERO
	f.heavy = false
	f.yaw = atan2(-dir.x, -dir.z)
	anim(f, "HitRecieve", 0.6)
	sfx("yell")

## 連環撞發生時（關卡可以覆寫，例如整人清單打勾）
func _on_carom(_a: Fighter, _b: Fighter) -> void:
	pass

func _stop_slide(f: Fighter, msg: String) -> void:
	if f.hp <= 0.0:
		knock_out(f, "%s的心掉光了，倒下" % f.name)
		return
	f.set_state("stunned")
	anim(f, "Idle")
	if msg != "":
		pop_label(msg, f.pos + Vector3(0, 3.0, 0), Color(1, 1, 1), 700, f)

# ---------------------------------------------------------------- 每個人每一步

func _tick_enemy(f: Fighter, dt: float) -> void:
	if f.data.get("sunk", false) or not f.alive():
		super(f, dt)
		return
	match f.state:
		"kslide":
			f.t += dt
			_tick_slide(f, dt)
			return
		"stunned":
			f.t += dt
			if f.t >= STUN_TIME:
				f.set_state("walk")
			return
		"slip":
			f.t += dt
			if f.t >= OPEN_SLIP:
				anim(f, "Idle")
				f.set_state("getup" if f.aggro else "patrol")
			return
	super(f, dt)

func _tick_slide(f: Fighter, dt: float) -> void:
	var r := slide_step(f, f.pos, f.data.sdir, f.data.snow, dt)
	f.data.snow = r.snow
	match r.kind:
		"move":
			f.pos = r.pos
		"hole":
			f.pos = r.pos
			fall_in(f)
		"thin":
			world.break_thin(r.thin)
			sfx("crack")
			f.pos = r.pos
			fall_in(f)
		"hit":
			var o: Fighter = r.other
			log_event("%s撞到%s，連環撞！" % [f.name, o.name])
			_on_carom(f, o)
			pop_label("連環撞！", o.pos + Vector3(0, 3.2, 0), Color(1, 0.85, 0.2), 900, o)
			start_slide(o, f.data.sdir)
			o.data.hit_by = f
			_stop_slide(f, "")
		"wall":
			_stop_slide(f, "咚！")
		"stop":
			f.pos = r.pos
			_stop_slide(f, "")

## 滑行的一步（實際滑行和預告共用同一套規則，所以預告是準的）
func slide_step(f: Fighter, pos: Vector3, dir: Vector3, snow: float, dt: float, ignore := []) -> Dictionary:
	var nxt: Vector3 = pos + dir * SLIDE_SPEED * dt
	if world.in_water(nxt.x, nxt.z):
		return {"kind": "hole", "pos": ground(nxt), "snow": snow}
	var ti: int = world.thin_at(nxt.x, nxt.z, 0.1)
	if ti >= 0 and world.thin[ti].state == "solid":
		return {"kind": "thin", "thin": ti, "pos": ground(nxt), "snow": snow}
	if not world.in_play(nxt.x, nxt.z) or hits_obstacle(Vector2(nxt.x, nxt.z)) or fence_crossing(pos, nxt) != null:
		return {"kind": "wall", "pos": pos, "snow": snow}
	for o in enemies:
		if o == f or not o.alive() or ignore.has(o) or o.state == "kslide" or o == f.data.get("hit_by"):
			continue
		var ahead: Vector3 = o.pos - pos
		ahead.y = 0.0
		# 只會撞到「前方」的人（剛撞過來的那個人在後面，不會又撞回去）
		if flat_dist(nxt, o.pos) < HIT_R and ahead.dot(dir) > 0.0:
			return {"kind": "hit", "other": o, "pos": pos, "snow": snow}
	if not world.on_ice(nxt.x, nxt.z):
		snow += SLIDE_SPEED * dt
		if snow >= SNOW_SLIDE:
			return {"kind": "stop", "pos": ground(nxt), "snow": snow}
	return {"kind": "move", "pos": ground(nxt), "snow": snow}

## 預告：f 被從 dir 方向啄飛，會滑到哪裡（含連環撞）。回傳 [{pts, end, text, color}]
func predict_slide(f: Fighter, dir: Vector3, start = null) -> Array:
	var out: Array = []
	var who: Fighter = f
	var pos: Vector3 = f.pos if start == null else start
	var snow := 0.0
	var moved: Array = [f]
	for chain in 3:
		var pts: Array = [pos]
		var res := {}
		for i in 600:
			var r := slide_step(who, pos, dir, snow, SIM_DT, moved)
			snow = r.snow
			if r.kind == "move":
				pos = r.pos
				if i % 6 == 0:
					pts.append(pos)
				continue
			res = r
			break
		pts.append(res.get("pos", pos))
		match res.get("kind", "stop"):
			"hole":
				out.append({"pts": pts, "end": res.pos, "text": "✕ %s 掉進冰洞" % who.name, "color": Color(1.0, 0.3, 0.2)})
				return out
			"thin":
				out.append({"pts": pts, "end": res.pos, "text": "薄冰 %s 踩破" % who.name, "color": Color(1.0, 0.3, 0.2)})
				return out
			"hit":
				var o: Fighter = res.other
				out.append({"pts": pts, "end": pos, "text": "撞到%s" % o.name, "color": Color(1.0, 0.85, 0.2)})
				who = o
				pos = o.pos
				snow = 0.0
				moved.append(o)
				continue
			"wall":
				out.append({"pts": pts, "end": pos, "text": "撞牆，暈倒", "color": Color(0.9, 0.9, 0.9)})
				return out
			_:
				out.append({"pts": pts, "end": pos, "text": "停在這", "color": Color(0.9, 0.9, 0.9)})
				return out
	return out

func _level_visuals() -> void:
	super()
	for f in enemies:
		if f.alive() and f.state == "kslide":
			f.node.rotation = Vector3(-0.45, f.yaw, sin(time * 18.0) * 0.25)
		elif f.alive() and f.state == "stunned":
			f.node.rotation = Vector3(0.0, f.yaw + sin(time * 6.0) * 0.3, sin(time * 9.0) * 0.12)

# ---------------------------------------------------------------- 畫面：頭上意圖、滑行預告

func _process(dt: float) -> void:
	super(dt)
	# 露出破綻、被啄飛的人：收起紅色視野扇形，畫面才不會亂
	for f in enemies:
		if f.cone and f.alive() and (_farmer_open(f) or f.state in ["kslide", "stunned"]):
			f.cone.visible = false
	_update_intents()
	_update_slide_preview()

func _update_intents() -> void:
	for f in enemies:
		var l: Label3D = _intents[f]
		if not f.alive() or phase == Phase.ENDED:
			l.visible = false
			continue
		l.visible = true
		var hearts := ""
		for k in HEARTS:
			hearts += "♥" if k < int(f.hp) else "♡"
		var t := ""
		var c := Color(0.85, 0.85, 0.85)
		match f.state:
			"kslide":
				t = "哇啊啊！"
				c = Color(1, 1, 1)
				hearts = ""
			"windup":
				if f.heavy:
					t = "重踢 %.1f" % maxf(0.8 - f.t, 0.0)
					c = Color(1.0, 0.3, 0.2)
				else:
					t = "踢"
					c = Color(1.0, 0.6, 0.2)
			"recover":
				if f.heavy:
					t = "破綻！%.1f" % maxf(1.7 - f.t, 0.0)
					c = Color(1.0, 0.9, 0.2)
				else:
					t = "…"
			"slip":
				t = "破綻！%.1f" % maxf(OPEN_SLIP - f.t, 0.0)
				c = Color(1.0, 0.9, 0.2)
			"startled":
				t = "破綻！%.1f" % maxf(STARTLE_TIME - f.t, 0.0)
				c = Color(1.0, 0.9, 0.2)
			"stunned":
				t = "暈…"
			"pant":
				t = "破綻！%.1f" % maxf(1.3 - f.t, 0.0)
				c = Color(1.0, 0.9, 0.2)
			"walk", "alert", "getup":
				t = "追" + ("（下一招重踢）" if f.attack_n % 3 == 2 else "")
				c = Color(1, 1, 1)
			_:
				t = "巡邏中"
		l.text = t if hearts == "" else "%s\n%s" % [hearts, t]
		l.modulate = c
		l.position = f.pos + Vector3(0, 3.3 + f.air, 0)

func _update_slide_preview() -> void:
	var im := _lines.mesh as ImmediateMesh
	im.clear_surfaces()
	var results: Array = []
	if phase == Phase.RUNNING or phase == Phase.PREPARE:
		# 瞄準飼料：假設家豪從飼料那邊過去啄；不然就用家豪現在的位置
		var from: Vector3 = bird.pos
		var aiming_feed: bool = aim_point != null and aim_error == "" and not items.is_empty() and items[selected].id == "feed"
		if aiming_feed:
			from = aim_point
		for f in enemies:
			if not f.alive() or f.state == "kslide":
				continue
			if not (_farmer_open(f) or aiming_feed):
				continue
			if flat_dist(from, f.pos) > CRIT_SEEK + 2.0:
				continue
			var dir: Vector3 = f.pos - from
			dir.y = 0.0
			if dir.length() < 0.05:
				continue
			results.append_array(predict_slide(f, dir.normalized()))
	var drew := false
	for r in results:
		var pts: Array = r.pts
		if pts.size() < 2:
			continue
		if not drew:
			im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
			drew = true
		var col := Color(1.0, 0.92, 0.25)
		for i in range(1, pts.size()):
			var a: Vector3 = pts[i - 1] + Vector3(0, 0.12, 0)
			var b: Vector3 = pts[i] + Vector3(0, 0.12, 0)
			var side := (b - a)
			side.y = 0
			if side.length() < 0.001:
				continue
			side = side.normalized().cross(Vector3.UP) * 0.11
			for v in [a - side, a + side, b + side, a - side, b + side, b - side]:
				im.surface_set_color(Color(col, 0.95))
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
