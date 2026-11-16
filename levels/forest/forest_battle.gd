extends "res://scripts/battle/battle_base.gd"
## 森林戰局。
## 伐木工會去砍離自己最近、還沒人佔的樹；抽菸的人站在原地抽。
## 假獵物把附近的人引開（狼外婆不理）。飼料把家豪引走。
## 引路點依「離家豪現在多近」排序，近的先走；走到人旁邊會停下來打。
## 小紅帽的計時不會停，狼外婆還活著就會一直倒數。

const CHOP_TIME := 5.0
const LURE_LIFE := 12.0
const ATTRACT := 11.0
const ENGAGE := 2.55          # 家豪走到這麼近就會停下來打
const STICKY := 4.4           # 已經開打的話，拉開到這麼遠才會回去跟引路點
const LOCK := ["windup", "recover", "stagger", "down", "getup", "slip", "startled"]

var want_trees := false
var tree_cap := 20
var want_smoke := false
var smoke_cap := 45.0
var want_hood := false
var hood_cap := 80.0

var grove: Array = []
var trees_cut := 0
var smoke_time := 0.0
var dinner := 0.0
var hood_saved := false
var hood: Node3D
var hood_home := Vector3.ZERO
var hood_run := 0.0
var escape_point := Vector3(0, 0, 4.4)
var guides: Array = []        # {pos, node, label, used}
var decoys: Array = []        # {pos, node, life}
var fail := ""
var warn_trees := false
var warn_smoke := false
var warn_hood := false
var ignited := false
var _range: MeshInstance3D

func _want_trees() -> bool:
	return false

func _tree_cap() -> int:
	return 20

func _want_smoke() -> bool:
	return false

func _smoke_cap() -> float:
	return 45.0

func _want_hood() -> bool:
	return false

func _hood_cap() -> float:
	return 80.0

# ---------------------------------------------------------------- 建立

func _level_setup() -> void:
	want_trees = _want_trees()
	tree_cap = _tree_cap()
	want_smoke = _want_smoke()
	smoke_cap = _smoke_cap()
	want_hood = _want_hood()
	hood_cap = _hood_cap()
	var listed = world.get("trees")
	grove = listed if listed != null else []
	hood = world.get_node_or_null("RedHood") as Node3D
	if hood:
		hood_home = hood.position
	var door = world.get("escape_point")
	if door != null:
		escape_point = door
	_dress_fighters()
	_build_range_ring()
	_free_cursor()
	var hint := get_node_or_null("../HUD/Hint") as Label
	if hint:
		hint.text = "移動滑鼠把圈圈對到地面｜左鍵 放下｜WASD 移動鏡頭｜空白 上升｜Shift 下降｜數字鍵／滾輪 選道具｜Enter 開始｜R 重試｜M 地圖｜Esc 選單"

func _dress_fighters() -> void:
	for f in enemies:
		if f.kind == "wolf":
			_wear_wolf(f)
		elif f.kind == "chopper":
			_wear_axe(f)
		elif f.kind == "smoker":
			_wear_smoke(f)

func _wear_wolf(f: Fighter) -> void:
	var gray := _tint(Color(0.55, 0.55, 0.58))
	var cloth := _tint(Color(0.85, 0.82, 0.74))
	_peg(f.node, Vector3(0.16, 0.28, 0.16), Vector3(-0.2, 2.42, 0.05), gray, Vector3(0, 0, 0.5))
	_peg(f.node, Vector3(0.16, 0.28, 0.16), Vector3(0.2, 2.42, 0.05), gray, Vector3(0, 0, -0.5))
	_peg(f.node, Vector3(0.22, 0.16, 0.28), Vector3(0, 2.05, 0.38), gray)          # 狼嘴
	_peg(f.node, Vector3(0.34, 0.28, 0.34), Vector3(0, 2.55, 0), cloth)            # 睡帽
	_peg(f.node, Vector3(0.5, 0.08, 0.5), Vector3(0, 1.35, 0.05), _tint(Color(0.45, 0.18, 0.22)))  # 披肩

func _wear_axe(f: Fighter) -> void:
	_peg(f.node, Vector3(0.08, 0.72, 0.08), Vector3(0.32, 1.05, 0.2), _tint(Color(0.45, 0.28, 0.14)))
	_peg(f.node, Vector3(0.34, 0.16, 0.08), Vector3(0.32, 1.4, 0.2), _tint(Color(0.65, 0.66, 0.7)))

func _wear_smoke(f: Fighter) -> void:
	_peg(f.node, Vector3(0.05, 0.05, 0.22), Vector3(0.22, 1.55, 0.32), _tint(Color(0.9, 0.9, 0.86)))
	var puff := _peg(f.node, Vector3(0.18, 0.18, 0.18), Vector3(0.22, 1.75, 0.48), _tint(Color(0.8, 0.8, 0.82)))
	puff.name = "CigarettePuff"

func _peg(parent: Node3D, size: Vector3, pos: Vector3, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi

func _tint(c: Color) -> Material:
	return world._toon(c)

func _level_reset() -> void:
	_free_cursor()
	guides.clear()
	decoys.clear()
	trees_cut = 0
	smoke_time = 0.0
	dinner = 0.0
	hood_saved = false
	hood_run = 0.0
	fail = ""
	warn_trees = false
	warn_smoke = false
	warn_hood = false
	ignited = false
	for t in grove:
		t.alive = true
		t.fall = 0.0
		t.block[1] = t.radius
		var n := t.node as Node3D
		n.rotation = Vector3.ZERO
		n.position = t.rest
		var crown := n.get_node_or_null("Crown") as Node3D
		if crown:
			crown.scale = Vector3.ONE
	if hood:
		hood.visible = true
		hood.position = hood_home
		hood.rotation.y = PI

func _level_start() -> void:
	if want_hood:
		toast("小紅帽在木屋裡！", 1.6)
		log_event("狼外婆正要吃掉小紅帽")

# ---------------------------------------------------------------- 瞄準
## 共用的準心把游標鎖在畫面正中，滑鼠只能轉鏡頭。這裡改成游標可以移動，圈圈跟著游標。

func _free_cursor() -> void:
	if player and player.has_method("_set_looking"):
		player.call("_set_looking", false)
	if crosshair:
		crosshair.visible = false

func _build_range_ring() -> void:
	if _range != null:
		return
	_range = MeshInstance3D.new()
	_range.name = "DecoyRange"
	var tm := TorusMesh.new()
	tm.inner_radius = 0.985
	tm.outer_radius = 1.0
	tm.rings = 48
	tm.ring_segments = 6
	_range.mesh = tm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.72, 0.46, 0.22, 0.45)
	_range.material_override = mat
	_range.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_range.visible = false
	world.add_child(_range)

func _update_aim() -> void:
	if camera == null:
		return
	var origin := camera.global_position
	var dir := -camera.global_basis.z
	if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		var m := get_viewport().get_mouse_position()
		origin = camera.project_ray_origin(m)
		dir = camera.project_ray_normal(m)
	aim_point = world.ray_ground(origin, dir, 80.0)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if phase != Phase.ENDED and not defeat_shown:
			_update_aim()
			try_cast()
		get_viewport().set_input_as_handled()
		return
	super(event)

func _show_range() -> void:
	if _range == null:
		return
	var show: bool = phase != Phase.ENDED and aim_point != null and not items.is_empty() and items[selected].id == "decoy" and not defeat_shown
	_range.visible = show
	if show:
		_range.global_position = (aim_point as Vector3) + Vector3(0, 0.05, 0)
		_range.scale = Vector3(ATTRACT, 1.0, ATTRACT)

# ---------------------------------------------------------------- 放置

func guide_error(p: Vector3) -> String:
	if world.in_water(p.x, p.z):
		return "不能放在水裡"
	if not world.walkable(p.x, p.z):
		return "這裡放不了"
	if hits_obstacle(Vector2(p.x, p.z)):
		return "樹擋住了"
	for g in guides:
		if not g.used and flat_dist(g.pos, p) < 1.05:
			return "離另一個點太近"
	return ""

func decoy_error(p: Vector3) -> String:
	var err := guide_error(p)
	if err == "離另一個點太近":
		err = ""
	if err != "":
		return err
	for d in decoys:
		if d.life > 0.0 and flat_dist(d.pos, p) < 1.4:
			return "離另一隻太近"
	if world.has_method("in_house") and world.in_house(p.x, p.z):
		return "不能放進木屋"
	return ""

func add_guide(p: Vector3) -> void:
	var root := Node3D.new()
	root.position = ground(p)
	fx_root.add_child(root)
	_peg(root, Vector3(0.08, 0.9, 0.08), Vector3(0, 0.45, 0), _tint(Color(0.95, 0.82, 0.25)))
	_peg(root, Vector3(0.28, 0.16, 0.06), Vector3(0, 0.95, 0.08), _tint(Color(0.9, 0.25, 0.18)))
	var label := Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.fixed_size = true
	label.font_size = 64
	label.pixel_size = 0.00048
	label.outline_size = 16
	label.outline_modulate = Color(0.15, 0.12, 0.02)
	label.modulate = Color(1, 0.95, 0.55)
	label.position = Vector3(0, 1.25, 0)
	label.text = "·"
	root.add_child(label)
	guides.append({"pos": ground(p), "node": root, "label": label, "used": false})

func add_decoy(p: Vector3) -> void:
	var root := Node3D.new()
	root.position = ground(p)
	fx_root.add_child(root)
	var fur := _tint(Color(0.62, 0.42, 0.24))
	var ear := _tint(Color(0.45, 0.28, 0.16))
	_peg(root, Vector3(0.46, 0.28, 0.7), Vector3(0, 0.28, 0), fur)
	_peg(root, Vector3(0.28, 0.26, 0.28), Vector3(0, 0.5, 0.28), fur)
	_peg(root, Vector3(0.1, 0.28, 0.08), Vector3(-0.1, 0.72, 0.3), ear, Vector3(0.2, 0, 0.3))
	_peg(root, Vector3(0.1, 0.28, 0.08), Vector3(0.1, 0.72, 0.3), ear, Vector3(0.2, 0, -0.3))
	decoys.append({"pos": ground(p), "node": root, "life": LURE_LIFE})
	log_event("放了一隻假獵物")

# ---------------------------------------------------------------- 時鐘

func _level_step(dt: float) -> void:
	_mark_saved()
	if want_hood and not hood_saved:
		dinner += dt
	var smoking := false
	for f in enemies:
		if f.alive() and f.kind == "smoker" and f.state == "smoke":
			smoking = true
			break
	if smoking:
		smoke_time += dt
	for d in decoys:
		if d.life > 0.0:
			d.life -= dt
			if d.life <= 0.0:
				(d.node as Node3D).visible = false
	_advance_falls(dt)
	_move_hood(dt)
	_warnings()

func _level_step_ended(dt: float) -> void:
	_advance_falls(dt)
	_move_hood(dt)

func _mark_saved() -> void:
	if hood_saved or not want_hood:
		return
	if not bird.alive() or bird.state == "fly" or not _bird_in_house():
		return
	hood_saved = true
	log_event("小紅帽得救了")
	toast("小紅帽得救了！", 1.4)

func _bird_in_house() -> bool:
	return world.has_method("in_house") and bool(world.call("in_house", bird.pos.x, bird.pos.z))

func _warnings() -> void:
	if want_trees and not warn_trees and trees_cut >= tree_cap - 3 and trees_cut > 0 and trees_cut <= tree_cap:
		warn_trees = true
		toast("樹快被砍光了！", 1.1)
	if want_smoke and not warn_smoke and smoke_time > smoke_cap * 0.65 and smoke_time <= smoke_cap:
		warn_smoke = true
		toast("快著火了！", 1.1)
	if want_hood and not warn_hood and not hood_saved and dinner > hood_cap - 25.0:
		warn_hood = true
		toast("小紅帽快撐不住了！", 1.2)

func _advance_falls(dt: float) -> void:
	for t in grove:
		if t.fall > 0.0 and t.fall < 1.0:
			t.fall = minf(t.fall + dt / 0.75, 1.0)

func _move_hood(dt: float) -> void:
	if not hood_saved or hood == null or hood_run >= 1.0:
		return
	hood_run = minf(hood_run + dt / 2.4, 1.0)
	var goal := escape_point
	goal.y = hood_home.y
	hood.position = hood_home.lerp(goal, hood_run)
	hood.rotation.y = 0.0

func _check_end() -> String:
	_mark_saved()
	# 樹和抽菸一超過就輸，家豪血還滿也一樣。
	if want_smoke and smoke_time > smoke_cap:
		fail = "fire"
		_ignite()
		return "lose"
	if want_trees and trees_cut > tree_cap:
		fail = "trees"
		return "lose"
	if want_hood and not hood_saved and dinner > hood_cap:
		fail = "hood"
		if hood:
			hood.visible = false
		log_event("小紅帽被吃掉了")
		return "lose"
	if not bird.alive():
		fail = "bird"
		return "lose"
	if want_hood and hood_saved:
		return "win"
	if not want_hood and enemies_left() == 0:
		return "win"
	return ""

func _ignite() -> void:
	if ignited:
		return
	ignited = true
	toast("森林燒起來了！", 1.5)
	log_event("森林燒起來了")
	var n := 0
	for t in grove:
		if n % 2 == 0:
			_flame(t.pos)
		n += 1
	for f in enemies:
		if f.kind == "smoker":
			_flame(f.pos)

func _flame(p: Vector3) -> void:
	var root := Node3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.04
	cone.bottom_radius = 0.42
	cone.height = 1.25
	var mi := MeshInstance3D.new()
	mi.mesh = cone
	mi.position.y = 0.62
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.42, 0.08)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.32, 0.04)
	m.emission_energy_multiplier = 1.8
	mi.material_override = m
	root.add_child(mi)
	root.position = ground(p) + Vector3(0, 0.15, 0)
	spawn_timed(root, 6.0)

# ---------------------------------------------------------------- 敵人

func _tick_enemy(f: Fighter, dt: float) -> void:
	if f.kind == "wolf":
		_tick_wolf(f, dt)
	elif f.kind == "chopper" or f.kind == "smoker":
		_tick_worker(f, dt)
	else:
		super(f, dt)

func _tick_wolf(f: Fighter, dt: float) -> void:
	# 狼外婆只是待在床上的角色，不追、不打。家豪走進門就把小紅帽帶走。
	if not f.alive():
		return
	f.aggro = false
	var home: Vector3 = f.route[0]
	if flat_dist(f.pos, home) > 0.35:
		_walk(f, home, f.speed * 0.6, dt)
		anim(f, "Walk", 0.5)
		f.pos = ground(world.clamp_house(f.pos))
		return
	if f.state != "eat":
		f.set_state("eat")
		anim(f, "Idle")
	if hood and not hood_saved:
		_face(f, hood.position)
	else:
		_face(f, escape_point)

func _tick_worker(f: Fighter, dt: float) -> void:
	if not f.alive():
		return
	if f.state in LOCK:
		_tick_melee(f, dt)
		return
	if _bird_close(f):
		_fight(f, dt)
		return
	var lure := _nearest_decoy(f.pos)
	if lure >= 0:
		_tick_lure(f, dt, lure)
		return
	if f.aggro and bird.alive() and flat_dist(f.pos, bird.pos) < f.vision_range + 1.2:
		_fight(f, dt)
		return
	f.aggro = false
	if sees_bird(f):
		_fight(f, dt)
		return
	if f.kind == "chopper":
		_tick_chop(f, dt)
	else:
		_tick_smoke(f, dt)

func _bird_close(f: Fighter) -> bool:
	return bird.alive() and bird.state != "fly" and flat_dist(f.pos, bird.pos) < 2.35

func _fight(f: Fighter, _dt: float) -> void:
	f.aggro = true
	if f.state in ["idle", "patrol", "look", "smoke", "chop", "lure", "goto", "eat"]:
		f.set_state("alert")
	_tick_melee(f, _dt)

func _tick_lure(f: Fighter, _dt: float, idx: int) -> void:
	var d: Dictionary = decoys[idx]
	if f.state != "lure" and f.state != "goto":
		log_event("%s去看假獵物" % f.name)
	if flat_dist(f.pos, d.pos) > 0.85:
		if f.state != "goto":
			f.set_state("goto")
		_walk(f, d.pos, f.speed, _dt)
		anim(f, "Walk", 0.85)
	else:
		if f.state != "lure":
			f.set_state("lure")
			anim(f, "Idle")
		_face(f, d.pos)

func _tick_chop(f: Fighter, _dt: float) -> void:
	var idx := _claim_tree(f)
	if idx < 0:
		if f.state != "idle":
			f.set_state("idle")
			anim(f, "Idle")
		return
	var pos: Vector3 = grove[idx].pos
	if flat_dist(f.pos, pos) > 1.2:
		if f.state != "goto":
			f.set_state("goto")
		_walk(f, pos, f.speed, _dt)
		anim(f, "Walk", 0.8)
		return
	if f.state != "chop":
		f.set_state("chop")
		anim(f, "Kick_Right", 0.65)
	_face(f, pos)
	f.t += _dt
	if f.t >= CHOP_TIME:
		_fell(idx)
		f.data["tree"] = -1
		f.set_state("idle")

func _tick_smoke(f: Fighter, _dt: float) -> void:
	var home: Vector3 = f.route[0]
	if flat_dist(f.pos, home) > 0.5:
		if f.state != "goto":
			f.set_state("goto")
		_walk(f, home, f.speed, _dt)
		anim(f, "Walk", 0.7)
		return
	if f.state != "smoke":
		f.set_state("smoke")
		anim(f, "Idle")
	f.yaw = f.start_yaw
	f.t += _dt

func _claim_tree(f: Fighter) -> int:
	var cur := int(f.data.get("tree", -1))
	if cur >= 0 and cur < grove.size() and grove[cur].alive:
		return cur
	var best := -1
	var bd := INF
	for i in grove.size():
		if not grove[i].alive or _tree_taken(i, f):
			continue
		var d := flat_dist(f.pos, grove[i].pos)
		if d < bd:
			bd = d
			best = i
	f.data["tree"] = best
	return best

func _tree_taken(i: int, self_f: Fighter) -> bool:
	for o in enemies:
		if o == self_f or not o.alive() or o.kind != "chopper":
			continue
		if int(o.data.get("tree", -1)) == i:
			return true
	return false

func _fell(i: int) -> void:
	var t: Dictionary = grove[i]
	if not t.alive:
		return
	t.alive = false
	t.fall = 0.01
	t.block[1] = 0.0
	trees_cut += 1
	log_event("砍倒第 %d 棵樹" % trees_cut)

func _nearest_decoy(p: Vector3) -> int:
	var best := -1
	var bd := ATTRACT
	for i in decoys.size():
		if decoys[i].life <= 0.0:
			continue
		var d := flat_dist(p, decoys[i].pos)
		if d < bd:
			bd = d
			best = i
	return best

# ---------------------------------------------------------------- 家豪

func _tick_bird(dt: float) -> void:
	var b := bird
	if not b.alive():
		return
	b.t += dt
	if b.state != "fly":
		_apply_knockback(b, dt)
	var close := _sticky_enemy()
	var nxt := nearest_enemy(b.pos)
	b.target = close if close != null else nxt
	if b.target == null and _next_guide() == null:
		return
	if b.state in ["charge", "return", "feed", "linger"]:
		var fi := _nearest_feed(b.pos, FEED_SENSE)
		if fi >= 0:
			if b.state != "feed":
				log_event("家豪看到飼料，跑去吃")
			b.feed_target = fi
			b.state = "feed"
	match b.state:
		"charge", "return":
			_bird_toward(dt)
		"feed":
			if b.feed_target < 0 or b.feed_target >= feeds.size():
				b.set_state("charge")
			else:
				var fp: Vector3 = feeds[b.feed_target].pos
				_bird_walk(fp, b.speed * 0.85, dt, "feed")
				if flat_dist(b.pos, fp) < 0.35:
					b.set_state("eat")
		"eat":
			if b.t >= FEED_EAT_TIME:
				var food := _nearest_feed(b.pos, 0.8)
				if food >= 0:
					(feeds[food].node as Node3D).queue_free()
					feeds.remove_at(food)
					b.hp = minf(b.hp + FEED_HEAL, b.max_hp)
					log_event("家豪吃掉一把飼料（回到 %d）" % ceili(b.hp))
				b.set_state("linger")
		"linger":
			if b.t >= FEED_LINGER:
				b.set_state("charge")
		"slip":
			if b.t >= SLIP_TIME:
				b.set_state("charge")
		"windup":
			var foe: Fighter = b.target
			if foe == null or not foe.alive():
				b.set_state("charge")
			else:
				_face(b, foe.pos)
				if b.t >= b.windup:
					if flat_dist(b.pos, foe.pos) <= b.reach + 0.35 and foe.alive():
						if not foe.aggro and not foe.immune_peck:
							_sneak(foe)
						else:
							_hit_enemy(foe, PECK_DAMAGE, b.pos)
					b.set_state("recover")
		"recover":
			if b.t >= b.recover:
				var foe2: Fighter = b.target
				var still := foe2 != null and foe2.alive() and flat_dist(b.pos, foe2.pos) <= b.reach
				b.set_state("windup" if still else "charge")
		"hop":
			if b.t >= 0.4:
				b.set_state("charge")
		"fly":
			var k := clampf(b.t / b.fly_dur, 0.0, 1.0)
			b.pos = ground(b.fly_from.lerp(b.fly_to, k))
			b.air = sin(k * PI) * b.fly_peak
			b.yaw = atan2(b.fly_to.x - b.fly_from.x, b.fly_to.z - b.fly_from.z)
			if k >= 1.0:
				b.air = 0.0
				b.set_state("land" if b.after_fly == "land" else b.after_fly)
		"land":
			if b.target != null and b.t > 0.25:
				_face(b, b.target.pos)
			if b.t >= 0.7:
				b.set_state("charge")

func _bird_toward(dt: float) -> void:
	var b := bird
	var foe := _sticky_enemy()
	if foe != null:
		b.target = foe
		var spd := b.speed * (1.35 if foe.state == "down" else 1.0)
		_bird_walk(foe.pos, spd, dt, "charge")
		if flat_dist(b.pos, foe.pos) <= b.reach:
			b.set_state("windup")
		return
	# 還沒救出小紅帽、又已經靠近木屋：先進門，不要又跑去追外面的人
	if want_hood and not hood_saved and hood != null and flat_dist(b.pos, hood.position) < 7.5:
		_bird_walk(hood.position, b.speed, dt, "charge")
		return
	var g = _next_guide()
	if g != null:
		_bird_walk(g.pos, b.speed, dt, "charge")
		if flat_dist(b.pos, g.pos) < 0.7:
			g.used = true
			(g.node as Node3D).visible = false
			log_event("家豪經過引路點")
		return
	var far := nearest_enemy(b.pos)
	if far == null:
		return
	b.target = far
	_bird_walk(far.pos, b.speed, dt, "charge")
	if flat_dist(b.pos, far.pos) <= b.reach:
		b.set_state("windup")

func nearest_enemy(from: Vector3) -> Fighter:
	var best: Fighter = null
	var bd := INF
	for f in enemies:
		if not f.alive() or f.kind == "wolf":
			continue
		var d := flat_dist(from, f.pos)
		if d < bd:
			bd = d
			best = f
	return best

func enemies_left() -> int:
	var n := 0
	for f in enemies:
		if f.alive() and f.kind != "wolf":
			n += 1
	return n

func _sticky_enemy() -> Fighter:
	var cur = bird.target
	if cur != null and (cur as Fighter).kind == "wolf":
		cur = null
	if bird.state in ["windup", "recover"] and cur != null and (cur as Fighter).alive():
		if flat_dist(bird.pos, (cur as Fighter).pos) <= STICKY:
			return cur
	var best: Fighter = null
	var bd := ENGAGE
	for f in enemies:
		if not f.alive() or f.kind == "wolf":
			continue
		var d := flat_dist(bird.pos, f.pos)
		if d < bd:
			bd = d
			best = f
	return best

func _next_guide():
	var best = null
	var bd := INF
	for g in guides:
		if g.used:
			continue
		var d := flat_dist(bird.pos, g.pos)
		if d < bd:
			bd = d
			best = g
	return best

# ---------------------------------------------------------------- 畫面

func _update_bars(dt: float) -> void:
	super(dt)
	for f in enemies:
		if f.kind == "wolf" and f.bar:
			f.bar.visible = false

func _level_visuals() -> void:
	_free_cursor()
	_show_range()
	_number_guides()
	for row in _enemy_rows:
		var who: Fighter = row.fighter
		if who.kind != "wolf":
			continue
		var face: Node = row.face
		if face.get_parent():
			face.get_parent().visible = false
	for t in grove:
		if t.fall <= 0.0:
			continue
		var n := t.node as Node3D
		n.rotation.z = t.fall * 1.25
		var crown := n.get_node_or_null("Crown") as Node3D
		if crown:
			crown.scale = Vector3.ONE * (1.0 - 0.45 * t.fall)
	for f in enemies:
		var puff := f.node.find_child("CigarettePuff", true, false) as Node3D
		if puff == null:
			continue
		puff.visible = f.alive() and f.state == "smoke"
		if puff.visible:
			puff.position.y = 1.75 + 0.2 * sin(f.t * 3.5)
			var s := 0.55 + 0.45 * absf(sin(f.t * 2.4))
			puff.scale = Vector3.ONE * s

func _number_guides() -> void:
	var left: Array = []
	for g in guides:
		if not g.used:
			left.append(g)
	var cursor := bird.pos
	var n := 1
	while not left.is_empty():
		var best_i := 0
		var bd := INF
		for i in left.size():
			var d := flat_dist(cursor, left[i].pos)
			if d < bd:
				bd = d
				best_i = i
		var g: Dictionary = left[best_i]
		(g.label as Label3D).text = str(n)
		cursor = g.pos
		left.remove_at(best_i)
		n += 1

func _update_phase_label() -> void:
	super()
	if phase == Phase.RUNNING and _phase_label != null:
		_phase_label.text = _meter_line()

func _meter_line() -> String:
	var bits := PackedStringArray()
	if want_trees:
		bits.append("樹 %d/%d" % [trees_cut, tree_cap])
	if want_smoke:
		bits.append("煙 %.0f/%.0f" % [minf(smoke_time, smoke_cap), smoke_cap])
	if want_hood:
		if hood_saved:
			bits.append("小紅帽安全")
		else:
			bits.append("小紅帽 %.0f" % maxf(hood_cap - dinner, 0.0))
	return "　".join(bits)

func _prepare_hint() -> String:
	return "假獵物引開人、飼料引家豪、引路點由近到遠　Enter 開始"

func _win_line() -> String:
	if want_hood:
		return "小紅帽跑出木屋了。"
	if want_smoke and not want_trees:
		return "煙滅了，森林沒有著火。"
	return "人倒下了，樹還在。"

func _lose_line(_left: int) -> String:
	match fail:
		"hood":
			return "小紅帽被狼外婆吃掉了。"
		"fire":
			return "抽菸超過 %.0f 秒，森林燒起來了。" % smoke_cap
		"trees":
			return "樹被砍倒超過 %d 棵了。" % tree_cap
		_:
			return "家豪倒下了…（還剩 %d 個敵人）" % _left

func _defeat_title() -> String:
	match fail:
		"hood":
			return "小紅帽被吃掉了……"
		"fire":
			return "森林燒起來了……"
		"trees":
			return "樹都被砍光了……"
		_:
			return "家豪被抓去當晚餐了……"

func _defeat_tip() -> String:
	match fail:
		"hood":
			return "引路點可以排進木屋。小紅帽的計時不會停。"
		"fire":
			return "假獵物能讓抽菸的人把菸放下。全部停下，計時才會停。"
		"trees":
			return "假獵物能把伐木的人引離樹。人在打架或看假獵物時不會砍。"
		_:
			return "用引路點讓家豪一次只打到一個人，飼料可以把她拉出包圍。"
