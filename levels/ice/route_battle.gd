extends "res://levels/ice/ice_battle.gd"
## 路線玩法（對照版）：你撒一條飼料路，家豪沿著路一路吃過去；人類踩著家豪的腳印追。讓這條路經過陷阱。
##
##   - 家豪不打架，只負責跑；跑到路線尾端會停下來挑釁
##   - 人類一開打就看到家豪，先走到「路線上離自己最近的點」，再沿著路線往前追
##     （比家豪早到就在那裡埋伏）
##   - 被人類碰到就輸
##   - 瞄準時就會預告：每個人會在哪裡掉下去（紅色 ✕）、在哪裡埋伏、會不會追到家豪
##   - 回饋：放點有聲音和飼料灑落、人滑倒會喊、掉下去有慢動作和震動、按住 F 快轉
## 小關的 battle.gd 寫 extends "res://levels/ice/route_battle.gd"，設定 _make_items() 和 _enemy_specs()。

const RouteItem := preload("res://levels/ice/items/route_item.gd")

const RUN_SPEED := 3.4         # 家豪沿路線跑的速度
const JOIN_DIST := 0.45        # 人走到路線這麼近就算「踩上路線」
const CATCH_DIST := 0.95       # 人碰到家豪的距離
const PELLET_STEP := 0.5       # 飼料粒間距
const CORNER_DEG := 55.0       # 冰上轉角超過幾度，人會滑出去
const OVERSHOOT := 1.8         # 人在冰上轉角會滑出去多遠

var route: Array = []          # 玩家撒的路線點 [Vector3]
var route_i := 0               # 家豪正在跑向第幾個點
var route_ver := 0             # 路線每改一次 +1（還沒踩上路線的人要重新找會合點）
var _joins: MeshInstance3D     # 每個人走向路線的紅色虛線
var pellets: Array = []        # 地上的飼料粒 {pos, node, seg, t0}
var _ribbon: MeshInstance3D
var _marks: Array = []         # 預告 ✕ 的 Label3D
var _pellet_mesh: SphereMesh
var _pellet_mat: StandardMaterial3D

func _make_items() -> Array:
	return [RouteItem.new().uses(5, 2)]

# ---------------------------------------------------------------- 建立、重置、開始

func _level_setup() -> void:
	super()
	avoid_holes = false
	time_limit = 60.0
	_pellet_mesh = SphereMesh.new()
	_pellet_mesh.radius = 0.07
	_pellet_mesh.height = 0.1
	_pellet_mesh.radial_segments = 6
	_pellet_mesh.rings = 3
	_pellet_mat = StandardMaterial3D.new()
	_pellet_mat.albedo_color = Color(1.0, 0.82, 0.25)
	_pellet_mat.emission_enabled = true
	_pellet_mat.emission = Color(0.6, 0.4, 0.0)
	_pellet_mat.emission_energy_multiplier = 0.4
	_ribbon = MeshInstance3D.new()
	_ribbon.mesh = ImmediateMesh.new()
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rm.vertex_color_use_as_albedo = true
	rm.cull_mode = BaseMaterial3D.CULL_DISABLED
	_ribbon.material_override = rm
	_ribbon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(_ribbon)
	_joins = MeshInstance3D.new()
	_joins.mesh = ImmediateMesh.new()
	_joins.material_override = rm
	_joins.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(_joins)
	for i in 10:
		var l := Label3D.new()
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		l.font_size = 72
		l.pixel_size = 0.011
		l.outline_size = 22
		l.outline_modulate = Color(0.1, 0.05, 0.05, 0.9)
		l.modulate = Color(1.0, 0.25, 0.2)
		l.visible = false
		world.add_child(l)
		_marks.append(l)
	var hint := get_node_or_null("../HUD/Hint") as Label
	if hint:
		hint.text = "WASD 飄移｜空白 上升｜Shift 下降｜滑鼠 轉視角｜左鍵 撒飼料路線｜右鍵 收回｜Enter 開始｜按住 F 快轉｜R 重試｜M 地圖｜Esc 放開游標"

func _level_reset() -> void:
	super()
	route.clear()
	route_i = 0
	route_ver += 1
	pellets.clear()      # 飼料粒放在 fx_root 底下，已經被一起刪掉了

func _level_start() -> void:
	for f in enemies:
		aggro(f)
	toast("家豪對工人扮了個鬼臉！", 1.4)
	pop_label("略略略～", bird.pos + Vector3(0, 2.0, 0), Color(1, 1, 1), 1200, bird)
	sfx("pop")

# ---------------------------------------------------------------- 路線

## 下一段路線從哪裡開始：準備階段是路線尾端，開打後是家豪現在的位置（改道）
func route_tail() -> Vector3:
	if phase == Phase.RUNNING:
		return bird.pos
	return route.back() if not route.is_empty() else bird.start_pos

func add_route_point(p: Vector3) -> void:
	var from := route_tail()
	if phase == Phase.RUNNING:
		# 改道：丟下還沒跑的路，直接衝去新的點
		for i in range(pellets.size() - 1, -1, -1):
			if int(pellets[i].seg) >= route_i:
				(pellets[i].node as Node3D).queue_free()
				pellets.remove_at(i)
		route.resize(route_i)
		route.append(bird.pos)     # 家豪現在的位置也算路線的一個點，路才接得起來
		route_i += 1
		toast("改道！", 0.9)
		pop_label("！", bird.pos + Vector3(0, 2.0, 0), Color(1, 0.9, 0.3), 700, bird)
		if bird.state == "linger":
			bird.set_state("charge")
	route.append(p)
	route_ver += 1
	_spawn_pellets(from, p, route.size() - 1)
	if phase == Phase.PREPARE:
		bird.yaw = _yaw_to(bird.start_pos, route[0])
		if route.size() == 1:
			pop_label("！", bird.start_pos + Vector3(0, 2.0, 0), Color(1, 0.9, 0.3), 700, bird)
	sfx("pop")
	sfx("drop")

## 準備階段收回最後一段（次數退回）
func undo_route_point() -> void:
	if phase != Phase.PREPARE or route.is_empty():
		return
	var seg := route.size() - 1
	for i in range(pellets.size() - 1, -1, -1):
		if int(pellets[i].seg) == seg:
			(pellets[i].node as Node3D).queue_free()
			pellets.remove_at(i)
	route.pop_back()
	route_ver += 1
	charges[0] += 1
	_refresh_slots()
	sfx("undo")

func _spawn_pellets(a: Vector3, b: Vector3, seg: int) -> void:
	var d := flat_dist(a, b)
	var n := maxi(int(d / PELLET_STEP), 1)
	var now := Time.get_ticks_msec()
	for i in range(1, n + 1):
		var q := a.lerp(b, float(i) / n)
		q += Vector3(sin(i * 12.9898) * 0.08, 0, cos(i * 78.233) * 0.08)
		q = ground(q)
		var node := MeshInstance3D.new()
		node.mesh = _pellet_mesh
		node.material_override = _pellet_mat
		node.position = q + Vector3(0, 2.5, 0)
		fx_root.add_child(node)
		pellets.append({"pos": q, "node": node, "seg": seg, "t0": now + i * 18})

func _input_undo(event: InputEvent) -> bool:
	return event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT \
		and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if _input_undo(event):
		undo_route_point()
		get_viewport().set_input_as_handled()
		return
	super(event)

# ---------------------------------------------------------------- 家豪：沿著路線跑

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
		"charge":
			if route_i < route.size():
				var tgt: Vector3 = route[route_i]
				if flat_dist(b.pos, tgt) < 0.2:
					route_i += 1
				else:
					_bird_walk(tgt, RUN_SPEED, dt, "charge")
			else:
				b.set_state("linger")
				log_event("家豪跑到路線尾端，停下來挑釁")
				pop_label("來抓我啊～", b.pos + Vector3(0, 2.0, 0), Color(1, 1, 1), 1400, b)
		"linger":
			var nf := nearest_enemy(b.pos)
			if nf:
				_face(b, nf.pos)
	# 吃掉經過的飼料
	for i in range(pellets.size() - 1, -1, -1):
		if flat_dist(pellets[i].pos, b.pos) < 0.45:
			(pellets[i].node as Node3D).queue_free()
			pellets.remove_at(i)

# ---------------------------------------------------------------- 路線的幾何

## 整條路線的折線：家豪起點 + 每個路線點
func trail() -> Array:
	return [bird.start_pos] + route

## 每個折線點離起點的路線長度
func trail_cum(tr: Array) -> Array:
	var out: Array = [0.0]
	for i in range(1, tr.size()):
		out.append(float(out[i - 1]) + flat_dist(tr[i - 1], tr[i]))
	return out

## 折線上離 q 最近的點：{seg: 第幾段（tr[seg]→tr[seg+1]）, pos, s: 離起點的路線長度}
func nearest_on_trail(tr: Array, cum: Array, q: Vector3) -> Dictionary:
	if tr.size() < 2:
		return {"seg": 0, "pos": tr[0], "s": 0.0}
	var best := {}
	var bd := INF
	for i in tr.size() - 1:
		var a: Vector3 = tr[i]
		var b: Vector3 = tr[i + 1]
		var ab := Vector2(b.x - a.x, b.z - a.z)
		var l2 := ab.length_squared()
		var t := 0.0 if l2 < 0.0001 else clampf(Vector2(q.x - a.x, q.z - a.z).dot(ab) / l2, 0.0, 1.0)
		var c := a.lerp(b, t)
		var d := flat_dist(c, q)
		if d < bd:
			bd = d
			best = {"seg": i, "pos": ground(c), "s": float(cum[i]) + sqrt(l2) * t}
	return best

## 家豪已經沿路線跑了多遠
func bird_progress(tr: Array, cum: Array) -> float:
	if route_i >= route.size():
		return float(cum.back())
	var a: Vector3 = tr[route_i]
	var b: Vector3 = tr[route_i + 1]
	var ab := Vector2(b.x - a.x, b.z - a.z)
	var l := ab.length()
	var t := 0.0 if l < 0.001 else clampf(Vector2(bird.pos.x - a.x, bird.pos.z - a.z).dot(ab) / l, 0.0, l)
	return float(cum[route_i]) + t

# ---------------------------------------------------------------- 人類：走到路線上，再沿著路線追

func _tick_melee(f: Fighter, dt: float) -> void:
	if f.state != "walk" or not f.aggro:
		super(f, dt)
		return
	f.t += dt
	_apply_knockback(f, dt)
	var tgt := _chase_target(f)
	if flat_dist(f.pos, tgt) > 0.05:
		_walk(f, tgt, f.speed, dt)
		anim(f, "Walk")
	else:
		_face(f, bird.pos)
		anim(f, "Idle")

## 走向路線的途中會繞開冰洞；踩上路線之後就只盯著路線走（所以會跟著掉下去）
func _avoids_holes(f: Fighter) -> bool:
	return not f.data.get("joined", false)

func _chase_target(f: Fighter) -> Vector3:
	var tr := trail()
	if tr.size() < 2:
		return bird.pos
	var cum := trail_cum(tr)
	if not f.data.get("joined", false):
		if int(f.data.get("ver", -1)) != route_ver:
			f.data.ver = route_ver
			f.data.join = nearest_on_trail(tr, cum, f.pos)
		var j: Dictionary = f.data.join
		if flat_dist(f.pos, j.pos) > JOIN_DIST:
			return j.pos
		if bird_progress(tr, cum) < float(j.s) - 0.3:
			return f.pos     # 比家豪早到：在這裡埋伏
		f.data.joined = true
		f.data.seg = int(j.seg) + 1
	var seg: int = f.data.seg
	while seg < tr.size() and flat_dist(f.pos, tr[seg]) < JOIN_DIST:
		seg += 1
	f.data.seg = seg
	if seg > route_i or seg >= tr.size():
		return bird.pos      # 已經追到家豪正在跑的那一段：直接追家豪
	return tr[seg]

# ---------------------------------------------------------------- 抓到、掉下去、滑倒

func _level_step(dt: float) -> void:
	super(dt)
	for f in enemies:
		if not f.alive():
			continue
		if bird.alive() and bird.air < 0.5 and flat_dist(f.pos, bird.pos) < CATCH_DIST:
			bird.hp = 0.0
			bird.set_state("dead")
			log_event("%s抓到家豪了" % f.name)
			toast("被抓到了！", 1.6)
			break

func _defeat_title() -> String:
	return "家豪被抓去做成雞肉冰棒了……"

func _defeat_tip() -> String:
	return "提示：看路線上的紅色 ✕，那裡會有人掉下去。讓每個工人都經過一個 ✕。"

func _lose_line(left: int) -> String:
	if time >= time_limit:
		return "天黑了…（還剩 %d 個工人）" % left
	return "家豪被抓到了…（還剩 %d 個工人）" % left

# ---------------------------------------------------------------- 預告：每個人會怎樣

## 路線上的陷阱：[{s: 路線長度, pos, text}]，照順序排
func trail_traps(tr: Array, cum: Array) -> Array:
	var out: Array = []
	var used_thin := {}
	for i in range(1, tr.size()):
		var a: Vector3 = tr[i - 1]
		var b: Vector3 = tr[i]
		var d := flat_dist(a, b)
		var n := maxi(int(d / 0.2), 1)
		var in_hole := false
		for k in range(1, n + 1):
			var q := a.lerp(b, float(k) / n)
			var s := float(cum[i - 1]) + d * float(k) / n
			if world.in_water(q.x, q.z):
				if not in_hole:
					out.append({"s": s, "pos": ground(q), "text": "跟著跳進冰洞"})
				in_hole = true
			else:
				in_hole = false
				var ti: int = world.thin_at(q.x, q.z, 0.1)
				if ti >= 0 and not used_thin.has(ti) and world.thin[ti].state == "solid":
					used_thin[ti] = true
					out.append({"s": s, "pos": ground(q), "text": "踩破薄冰"})
	# 冰上急轉彎：人會沿原方向滑出去
	for i in range(1, tr.size() - 1):
		var p: Vector3 = tr[i]
		if not world.on_ice(p.x, p.z):
			continue
		var din: Vector3 = p - tr[i - 1]
		var dout: Vector3 = tr[i + 1] - p
		din.y = 0
		dout.y = 0
		if din.length() < 0.5 or dout.length() < 0.1 or rad_to_deg(din.angle_to(dout)) < CORNER_DEG:
			continue
		var dir := din.normalized()
		for k in range(1, 10):
			var q: Vector3 = p + dir * (OVERSHOOT * k / 9.0)
			if world.in_water(q.x, q.z):
				out.append({"s": float(cum[i]), "pos": ground(q), "text": "轉彎滑進冰洞"})
				break
	out.sort_custom(func(x, y): return x.s < y.s)
	return out

## 預告每個還沒出局的人：[{f, kind: "trap"/"ambush"/"catch", pos, text, join}]
func predict_all(tr: Array) -> Array:
	var out: Array = []
	if tr.size() < 2:
		return out
	var cum := trail_cum(tr)
	var traps := trail_traps(tr, cum)
	for f in enemies:
		if not f.alive():
			continue
		var j: Dictionary
		if f.data.get("joined", false):
			j = {"seg": int(f.data.seg) - 1, "pos": f.pos, "s": float(cum[clampi(int(f.data.seg) - 1, 0, cum.size() - 1)])}
		else:
			j = nearest_on_trail(tr, cum, f.pos)
		var t_h: float = (0.6 if phase == Phase.PREPARE else 0.0) + flat_dist(f.pos, j.pos) / f.speed * 1.15
		var s_b: float = 0.0 if phase == Phase.PREPARE else bird_progress(tr, cum)
		var t_b: float = (float(j.s) - s_b) / RUN_SPEED
		var r := {"f": f, "join": j.pos}
		if not f.data.get("joined", false) and t_h < t_b - 0.3:
			r.kind = "ambush"
			r.pos = j.pos
			r.text = "%s 在這裡埋伏" % f.name
		else:
			r.kind = "catch"
			r.pos = tr.back()
			r.text = "%s 會追到家豪" % f.name
			for tp in traps:
				if float(tp.s) > float(j.s) - 0.2:
					r.kind = "trap"
					r.pos = tp.pos
					r.text = tp.text
					break
		out.append(r)
	return out

func _update_marks() -> void:
	var tr: Array = []
	var aiming: bool = aim_point != null and aim_error == "" and charges[0] != 0
	if phase == Phase.PREPARE or (phase == Phase.RUNNING and aiming):
		tr = trail()
		if phase == Phase.RUNNING:
			tr = tr.slice(0, route_i + 1) + [bird.pos] + route.slice(route_i)
		# 瞄準中的那一段也算進去：還沒放下就先看到結果
		if aim_point != null and aim_error == "" and charges[0] != 0:
			if phase == Phase.RUNNING:
				tr = tr.slice(0, route_i + 2) + [aim_point]
			else:
				tr = tr + [aim_point]
	var preds := predict_all(tr) if tr.size() >= 2 else []
	# 開打後畫面上不放預告字（太亂），改在上方狀態列顯示「改道預測」
	if phase == Phase.RUNNING:
		if _phase_label and not preds.is_empty():
			_phase_label.text = "戰鬥中 %.1f 秒｜改道預測：%s" % [time, _forecast_text(preds)]
		preds = []
	# 同一個位置的合在一起
	var groups: Array = []
	for r in preds:
		var g = null
		for x in groups:
			if flat_dist(x.pos, r.pos) < 0.6 and x.kind == r.kind:
				g = x
		if g == null:
			groups.append({"pos": r.pos, "kind": r.kind, "text": r.text, "names": [r.f.name]})
		else:
			g.names.append(r.f.name)
	for i in _marks.size():
		var l: Label3D = _marks[i]
		if i < groups.size():
			var g: Dictionary = groups[i]
			l.visible = true
			if g.kind == "trap":
				l.text = "✕ %s\n%s" % [g.text, "、".join(g.names)]
				l.modulate = Color(1.0, 0.25, 0.2)
			elif g.kind == "ambush":
				l.text = "⚠ %s 在這裡埋伏" % "、".join(g.names)
				l.modulate = Color(1.0, 0.6, 0.1)
			else:
				l.text = "⚠ %s 會追到家豪" % "、".join(g.names)
				l.modulate = Color(1.0, 0.6, 0.1)
			l.position = (g.pos as Vector3) + Vector3(0, 1.0, 0)
		else:
			l.visible = false
	# 每個人走向路線的紅色虛線
	var im := _joins.mesh as ImmediateMesh
	im.clear_surfaces()
	var any := false
	for r in preds:
		var f: Fighter = r.f
		if f.data.get("joined", false):
			continue
		var a: Vector3 = f.pos
		var b: Vector3 = r.join
		var dd := flat_dist(a, b)
		if dd < 0.3:
			continue
		if not any:
			im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
			any = true
		var side := (b - a)
		side.y = 0
		side = side.normalized().cross(Vector3.UP) * 0.1
		var n := int(dd / 0.5)
		for k in n:
			if k % 2 == 1:
				continue
			var p0 := ground(a.lerp(b, float(k) / n)) + Vector3(0, 0.09, 0)
			var p1 := ground(a.lerp(b, float(k + 1) / n)) + Vector3(0, 0.09, 0)
			for v in [p0 - side, p0 + side, p1 + side, p0 - side, p1 + side, p1 - side]:
				im.surface_set_color(Color(1.0, 0.2, 0.15, 0.95))
				im.surface_add_vertex(v)
	if any:
		im.surface_end()
	# 準備階段：上方提示改成預測結果
	if phase == Phase.PREPARE and _phase_label and tr.size() >= 2:
		_phase_label.text = "預測：" + _forecast_text(preds)
	elif phase == Phase.PREPARE and _phase_label:
		_phase_label.text = _prepare_hint()

func _process(dt: float) -> void:
	super(dt)
	var now := Time.get_ticks_msec()
	# 飼料粒從天上灑下來
	for p in pellets:
		var node := p.node as Node3D
		var k := clampf(float(now - int(p.t0)) / 220.0, 0.0, 1.0)
		node.position = p.pos + Vector3(0, 0.06 + 2.5 * (1.0 - k * k), 0)
	_draw_ribbon()
	_update_marks()

## 剩下的路線畫成一條淡黃色的帶子
func _draw_ribbon() -> void:
	var im := _ribbon.mesh as ImmediateMesh
	im.clear_surfaces()
	var pts: Array = [bird.pos if phase == Phase.RUNNING else bird.start_pos]
	for i in range(route_i if phase == Phase.RUNNING else 0, route.size()):
		pts.append(route[i])
	if pts.size() < 2 or phase == Phase.ENDED:
		return
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var c := Color(1.0, 0.78, 0.15, 0.7)
	for i in range(1, pts.size()):
		var a: Vector3 = pts[i - 1]
		var b: Vector3 = pts[i]
		var side := (b - a)
		side.y = 0
		side = side.normalized().cross(Vector3.UP) * 0.13
		var n := maxi(int(flat_dist(a, b) / 0.4), 1)
		for k in n:
			var p0 := ground(a.lerp(b, float(k) / n)) + Vector3(0, 0.08, 0)
			var p1 := ground(a.lerp(b, float(k + 1) / n)) + Vector3(0, 0.08, 0)
			for v in [p0 - side, p0 + side, p1 + side, p0 - side, p1 + side, p1 - side]:
				im.surface_set_color(c)
				im.surface_add_vertex(v)
	im.surface_end()

func _forecast_text(preds: Array) -> String:
	var parts: PackedStringArray = []
	var all_fall := true
	for r in preds:
		if r.kind == "trap":
			parts.append("%s %s" % [r.f.name, r.text])
		else:
			all_fall = false
			parts.append(r.text)
	var tail := ""
	if phase == Phase.PREPARE:
		tail = "　→ 全部掉下去！按 Enter 看看" if all_fall else "　按 Enter 開始"
	return "、".join(parts) + tail
