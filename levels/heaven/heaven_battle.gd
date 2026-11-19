extends "res://levels/ice/rescue_battle.gd"
## 【仙境丹穴山】戰局：沿用冰雪島「救企鵝」的玩法（準備階段在線旁邊放東西、按開始後只看），
## 只多兩樣新東西，規則見 levels/heaven/docs/仙境關卡規格.md：
##   畫門（3.1）：滑行中的人從正面滑進一扇門，從成對的另一扇門出來，沿出口那扇門的朝向繼續滑。
##   陸吾（3.2）：面前有一塊金色的視線；第一個進去的不管是人還是家豪都被吹走，吹完牠就睡了。
## 另外：巨石（3.7，只能放在雲階上）、唱盤上的飼料（3.8）、大老闆和阿金（3.3）。
## 場地那邊（heaven_world.gd）提供：doors、luwu、disc、on_stairs()。
## 小關的 battle.gd：extends 這個檔案，照冰雪島的寫法設定道具、人物、清單。
##
## 沒有動到冰雪島的檔案：畫門和陸吾都是覆寫 slide_step() 之類的函式接上去的（實際滑行和預告共用同一套，所以預告是準的）。

const DOOR_W := 2.4            # 畫門多寬
const DOOR_MAX := 2            # 一次滑行最多穿幾次門
const GAZE_NEAR := 1.0         # 陸吾的視線：面前幾公尺開始
const GAZE_FAR := 5.5          # 到幾公尺為止
const GAZE_HALF := 1.1         # 左右各多寬
const INHALE := 0.4            # 陸吾吸一口氣的時間（這段時間內進來的人一起吹走）
const BOSS_SPEED := 1.6        # 大老闆和阿金走路的速度
const DISC_R := 1.2            # 飼料離唱盤中心多近算「放在唱盤上」
const DISC_WAIT := 2.5         # 人都解決了、家豪卻站在唱盤前面不動：幾秒後算失敗

var luwu_awake := true
var _beam_label: Label3D
var _pile_labels: Array = []
var _inhale := -1.0            # 陸吾吸氣吸了幾秒（-1＝沒在吸）
var _blow_tail := -1.0         # 吹完之後那一口氣的尾勁還剩幾秒
var _breath_n := 0             # 這一口氣吹走幾個工人
var _victims: Array = []       # 這一口氣要吹走的人
var disc_fed := false          # 唱盤上有沒有放飼料（第 3 關）
var _disc_node: Node3D
var _disc_wait := 0.0
var _gaze_line: MeshInstance3D
var _gaze_label: Label3D
var _door_labels: Array = []
var _disc_label: Label3D
var doors_used := 0            # 這一局有幾個人次穿過畫門
var _rock_hits := 0

# ================================================================== 場地給的東西

## 這一關怎麼叫「洞」「不會滑的地面」「堆」（場地的 hole_word、rough_word、pile_word）
func _word(key: String, fallback: String) -> String:
	var v = world.get(key)
	return String(v) if v != null and String(v) != "" else fallback

func _doors() -> Array:
	var d = world.get("doors")
	return d if d != null else []

func _luwu() -> Dictionary:
	var l = world.get("luwu")
	return l if l != null else {}

## 唱盤的位置（null＝這一關沒有唱盤，黃線直接走到終點）
func _turntable():
	return world.get("disc")

func _needs_turntable() -> bool:
	return _turntable() != null

# ================================================================== 設定、重來

func _level_setup() -> void:
	super()
	chase_avoids_holes = true         # 追人的攔截線會繞開雲洞，也會繞開畫門和醒著的陸吾（見 _crosses_hole）
	var specs := _enemy_specs()
	for i in enemies.size():
		for key in ["slow", "delay", "boss"]:
			if (specs[i] as Dictionary).has(key):
				enemies[i].set_meta(key, specs[i][key])
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.disable_fog = true
	_gaze_line = _mesh_node(m)
	if not _luwu().is_empty():
		_gaze_label = _tag("陸吾")
		_beam_label = _tag("金光")
	# 只有一對門就叫「畫門」；兩對以上寫甲乙丙丁（甲乙一對、丙丁一對，地上的光也是一對一個顏色）
	var dn := _doors().size()
	for di in dn:
		_door_labels.append(_tag("畫門" if dn <= 2 else "畫門" + "甲乙丙丁戊己"[di]))
	if _needs_turntable():
		_disc_label = _tag("唱盤上要放飼料")
	for p in world.snow_piles:
		var pl := _tag(_word("pile_word", "落葉堆"))
		pl.position = ground(p) + Vector3(0, 1.9, 0)
		_pile_labels.append(pl)

## 地上的小字牌（跟冰雪島「薄冰」的牌子同一種）
func _tag(text: String) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.pixel_size = 0.0005
	l.fixed_size = true
	l.font_size = 30
	world.add_child(l)
	_plate(l, "bubble")
	_beige(l)
	l.visible = false
	return l

func _level_reset() -> void:
	super()
	_blow_tail = -1.0
	_breath_n = 0
	luwu_awake = true
	_inhale = -1.0
	_victims.clear()
	disc_fed = false
	_disc_node = null
	_disc_wait = 0.0
	doors_used = 0
	_rock_hits = 0
	if world.has_method("luwu_wake"):
		world.luwu_wake()
	for f in enemies:
		f.data.erase("blown")
		f.data.erase("door_n")
		f.data.erase("rocked")
		f.node.visible = true
	bird.data.erase("blown")
	bird.node.visible = true

# ================================================================== 畫門

## 線段 a→b 有沒有穿過哪一扇門的門線：[第幾扇, 是不是從正面進去]；沒有回傳 []
func _door_hit(a: Vector3, b: Vector3) -> Array:
	var ds := _doors()
	for i in ds.size():
		var d: Dictionary = ds[i]
		var n: Vector3 = d.face
		var c: Vector3 = d.pos
		var sa := (a.x - c.x) * n.x + (a.z - c.z) * n.z
		var sb := (b.x - c.x) * n.x + (b.z - c.z) * n.z
		if sa * sb > 0.0 or is_equal_approx(sa, sb):
			continue
		var q := a.lerp(b, sa / (sa - sb))
		var along := (q.x - c.x) * -n.z + (q.z - c.z) * n.x
		if absf(along) <= DOOR_W * 0.5:
			return [i, sa > 0.0]
	return []

## 從第 i 扇門進去，會從哪裡、往哪個方向出來
func _door_out(i: int) -> Dictionary:
	var ds := _doors()
	var o: Dictionary = ds[int(ds[i].pair)]
	var n: Vector3 = o.face
	return {"pos": ground(o.pos + n * 0.45), "dir": n, "door": int(ds[i].pair)}

## p 離最近的門線多遠
func _door_dist(p: Vector3) -> float:
	var best := 1e9
	for d in _doors():
		var n: Vector3 = d.face
		var side := Vector3(-n.z, 0, n.x)
		var a: Vector3 = d.pos - side * DOOR_W * 0.5
		var b: Vector3 = d.pos + side * DOOR_W * 0.5
		var ab := Vector2(b.x - a.x, b.z - a.z)
		var t := clampf(Vector2(p.x - a.x, p.z - a.z).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
		best = minf(best, flat_dist(a.lerp(b, t), p))
	return best

## 滑行的一步：多兩種結果——"door"（從正面滑進畫門）、"gaze"（滑進陸吾醒著的視線）；門的背面等同撞牆
func slide_step(f: Fighter, pos: Vector3, dir: Vector3, snow: float, dt: float, ignore := []) -> Dictionary:
	var nxt: Vector3 = pos + dir * SLIDE_SPEED * dt
	var dh := _door_hit(pos, nxt)
	if not dh.is_empty():
		if dh[1]:
			return {"kind": "door", "door": int(dh[0]), "pos": pos, "snow": snow}
		return {"kind": "wall", "pos": pos, "snow": snow}
	if luwu_awake and in_gaze(nxt):
		return {"kind": "gaze", "pos": ground(nxt), "snow": snow}
	return super(f, pos, dir, snow, dt, ignore)

func start_slide(f: Fighter, dir: Vector3) -> void:
	super(f, dir)
	f.data.door_n = 0
	f.data.bumped = []

## 滑行時不會撞到的人：被陸吾盯住的（滑過去的人自己也會進視線，一起被吹走）、這一趟已經撞過的
## （前面那個人撞到東西停下來之後，後面的人不會貼著他一撞再撞）
func _slide_skip(f: Fighter) -> Array:
	var out: Array = super(f)
	for e in enemies:
		if e.state == "gazed":
			out.append(e)
	out.append_array(f.data.get("bumped", []))
	return out

func _on_carom(a: Fighter, b: Fighter) -> void:
	super(a, b)
	if not a.data.has("bumped"):
		a.data.bumped = []
	(a.data.bumped as Array).append(b)

func _tick_slide(f: Fighter, dt: float) -> void:
	var r := slide_step(f, f.pos, f.data.sdir, f.data.snow, dt, _slide_skip(f))
	if r.kind == "door":
		if int(f.data.get("door_n", 0)) >= DOOR_MAX:
			_stop_slide(f, "咚！")           # 第三次：不再傳了，停在門前
			return
		var o := _door_out(int(r.door))
		log_event("%s滑進畫門，從另一扇門出來" % f.name)
		if world.has_method("door_flash"):
			world.door_flash(int(r.door))
			world.door_flash(int(o.door))
		f.pos = o.pos
		f.data.sdir = o.dir
		f.data.snow = 0.0
		f.data.door_n = int(f.data.get("door_n", 0)) + 1
		f.data.erase("hit_by")
		f.data.ahead = enemies.filter(func(e): return e != f and (e.pos - f.pos).dot(o.dir) > 0.0)
		f.yaw = atan2(-(o.dir as Vector3).x, -(o.dir as Vector3).z)
		f.data.vis_snap = true             # 畫面上直接出現在另一扇門（不要從這扇門滑過整張地圖）
		doors_used += 1
		pop_label("咻！", f.pos + Vector3(0, 3.2, 0), Color(1.0, 0.86, 0.5), 800, f)
		sfx("pop")
		mark("door")
		# 鏡頭跟到出口那一邊
		if _follow == f and _cut_cam != null and _cut_cam.current:
			_cut_to(f.pos + (o.dir as Vector3) * 0.9 + Vector3(0, 1.2, 0), _follow_off, 1.6)
		return
	if r.kind == "gaze":
		f.pos = r.pos                      # 滑進視線：停在裡面，陸吾那邊會把他吹走（_step_luwu）
		f.set_state("gazed")
		return
	super(f, dt)

## 預告（教學關：畫到結果為止，含連環撞）。跟原本的一樣，多處理畫門和陸吾。
## 穿過門的那一條會多一個 "segs"：門前、門後各一段（畫線時分開畫，中間不連起來）。
func predict_slide(f: Fighter, dir: Vector3, start = null) -> Array:
	var out: Array = []
	var who: Fighter = f
	var pos: Vector3 = f.pos if start == null else start
	var snow := 0.0
	var moved: Array = [f]
	for chain in 3:
		var segs: Array = [[pos]]
		var res := {}
		var through := 0
		for i in 900:
			var r := slide_step(who, pos, dir, snow, SIM_DT, moved)
			snow = r.snow
			if r.kind == "move":
				pos = r.pos
				if i % 6 == 0:
					(segs.back() as Array).append(pos)
				continue
			if r.kind == "door" and through < DOOR_MAX:
				through += 1
				(segs.back() as Array).append(pos + dir * 0.35)
				var o := _door_out(int(r.door))
				pos = o.pos
				dir = o.dir
				snow = 0.0
				segs.append([pos])
				continue
			res = r
			break
		(segs.back() as Array).append(res.get("pos", pos))
		var pts: Array = []
		for s in segs:
			pts.append_array(s)
		var one := {"pts": pts, "end": pos, "text": "停在這", "color": Color(0.9, 0.9, 0.9)}
		if segs.size() > 1:
			one["segs"] = segs
		match String(res.get("kind", "stop")):
			"hole":
				one.end = res.pos
				one.text = "✕ %s 掉進%s" % [who.name, _word("hole_word", "洞")]
				one.color = Color(1.0, 0.3, 0.2)
				out.append(one)
				return out
			"gaze":
				one.end = res.pos
				one.text = "撞到陸吾"            # peel_outcome 會把「撞到」拿掉，只留「陸吾」
				one.color = Color(1.0, 0.85, 0.2)
				out.append(one)
				return out
			"hit":
				var o2: Fighter = res.other
				one.text = "撞到%s" % o2.name
				one.color = Color(1.0, 0.85, 0.2)
				out.append(one)
				who = o2
				pos = o2.pos
				snow = 0.0
				moved.append(o2)
				continue
			"wall", "door":
				one.text = "撞牆，暈倒"
				out.append(one)
				return out
			_:
				out.append(one)
				return out
	return out

## 預告（第 2 關開始：只畫場地，站著的守衛會擋住）。跟原本的一樣，多處理畫門和陸吾。
func _terrain_slide(f: Fighter, dir: Vector3, start: Vector3) -> Dictionary:
	var pos := start
	var snow := 0.0
	var segs: Array = [[pos]]
	var res := {}
	var through := 0
	# 還沒出發、紅線第一段的方向是哪：滑的人如果沿著同一條線從他背後追上來，一定撞得到（走的比滑的慢）
	var lanes := {}
	if phase == Phase.PREPARE:
		for o in enemies:
			if o == f or not o.alive() or o.data.get("guard", o.get_meta("guard", false)):
				continue
			var m: Array = effective_route(o, null).main
			if m.size() >= 2:
				var d0: Vector3 = (m[1] as Vector3) - (m[0] as Vector3)
				d0.y = 0.0
				if d0.length() > 0.2:
					lanes[o] = d0.normalized()
	for i in 900:
		var r := slide_step(f, pos, dir, snow, SIM_DT, enemies)
		snow = r.snow
		if r.kind == "move":
			var blocker = null
			for o in enemies:
				if o != f and o.alive() and o.state in ["guard", "idle", "patrol"] and o.data.get("guard", o.get_meta("guard", false)) \
						and flat_dist(r.pos, o.pos) < HIT_R:
					blocker = o
			for o in lanes:
				if blocker == null and flat_dist(r.pos, (o as Fighter).pos) < HIT_R and (lanes[o] as Vector3).dot(Vector3(dir.x, 0, dir.z).normalized()) > 0.96:
					blocker = o
			if blocker != null:
				res = {"kind": "person", "pos": pos, "who": blocker}
				break
			pos = r.pos
			if i % 6 == 0:
				(segs.back() as Array).append(pos)
			continue
		if r.kind == "door" and through < DOOR_MAX:
			through += 1
			(segs.back() as Array).append(pos + dir * 0.35)
			var o3 := _door_out(int(r.door))
			pos = o3.pos
			dir = o3.dir
			snow = 0.0
			segs.append([pos])
			continue
		res = r
		break
	(segs.back() as Array).append(res.get("pos", pos))
	var pts: Array = []
	for s in segs:
		pts.append_array(s)
	var kind: String = res.get("kind", "stop")
	var t := "停"
	if kind == "person":
		t = (res.who as Fighter).name
	elif kind == "hole":
		t = _word("hole_word", "洞")
	elif kind == "gaze":
		t = "陸吾"
	elif kind == "wall" or kind == "door":
		t = "咚"
	var one := {"pts": pts, "end": pts.back(), "text": t, "color": Color(1.0, 0.92, 0.25),
		"terrain": true, "terrain_text": t, "ticks": true}
	if segs.size() > 1:
		one["segs"] = segs
	return one

## 一片香蕉皮的結果：字換成仙境的說法
func peel_outcome(p: Vector3, skip = null) -> Array:
	var out: Array = super(p, skip)
	for r in out:
		match String(r.text):
			"冰洞": r.text = _word("hole_word", "洞")
			"雪地": r.text = _word("rough_word", "地面")
	return out

## 畫滑行線：穿過門的那一條拆成門前、門後兩段各畫各的
func _draw_slides(im: ImmediateMesh, results: Array, col: Color, w: float, edge := Color(0, 0, 0, 0), arrow := false) -> void:
	var ex: Array = []
	for r in results:
		var sg = r.get("segs")
		if sg == null:
			ex.append(r)
			continue
		for s in sg:
			var c: Dictionary = (r as Dictionary).duplicate()
			c.pts = s
			ex.append(c)
	super(im, ex, col, w, edge, arrow)

## 香蕉皮不能放在門的線上
func placement_error(i: int, p: Vector3) -> String:
	if items[i].id == "banana" and _door_dist(p) < 0.7:
		return "不能放在畫門上"
	return super(i, p)

## 黃線不能穿過畫門
func _line_blocked(a: Vector3, b: Vector3) -> String:
	if not _door_hit(a, b).is_empty():
		return "畫門"
	var why := super(a, b)
	match why:
		"冰洞": return _word("hole_word", "洞")
		"雪人或松樹": return "香爐或石柱"
		"籠子": return "終點"
	return why

## 追人的攔截線：除了開著的雲洞，也不穿過畫門、不穿過醒著的陸吾的視線
func _crosses_hole(a: Vector3, b: Vector3) -> bool:
	if super(a, b):
		return true
	if not _door_hit(a, b).is_empty():
		return true
	if luwu_awake and not _luwu().is_empty():
		var n := maxi(int(flat_dist(a, b) / 0.2), 1)
		for k in range(0, n + 1):
			if in_gaze(a.lerp(b, float(k) / n)):
				return true
	return false

# ================================================================== 陸吾

## p 在不在陸吾的視線裡（不管牠醒著沒）
func in_gaze(p: Vector3) -> bool:
	var l := _luwu()
	if l.is_empty():
		return false
	var n: Vector3 = l.face
	var c: Vector3 = l.pos
	var fwd := (p.x - c.x) * n.x + (p.z - c.z) * n.z
	var side := (p.x - c.x) * -n.z + (p.z - c.z) * n.x
	return fwd >= GAZE_NEAR and fwd <= GAZE_FAR and absf(side) <= GAZE_HALF

## 視線那塊長方形的四個角
func _gaze_corners() -> Array:
	var l := _luwu()
	var n: Vector3 = l.face
	var side := Vector3(-n.z, 0, n.x)
	var c: Vector3 = l.pos
	return [ground(c + n * GAZE_NEAR - side * GAZE_HALF), ground(c + n * GAZE_NEAR + side * GAZE_HALF),
		ground(c + n * GAZE_FAR + side * GAZE_HALF), ground(c + n * GAZE_FAR - side * GAZE_HALF)]

func _step_luwu(dt: float) -> void:
	if _luwu().is_empty():
		return
	# 家豪已經被抓走了：陸吾不再吹（不然旁邊站開的人會在失敗畫面被吹走）
	if bird.state == "lifted" or bird.data.get("held", false):
		return
	if not luwu_awake:
		# 那一口氣的尾勁：剛吹完的半秒內，跟在後面滑進金光的工人一起被吹走（被撞歪、晚一點到的同伴）。家豪不算。
		if _blow_tail > 0.0:
			_blow_tail -= dt
			for f in enemies:
				if f.alive() and not f.data.get("sunk", false) and not f.data.has("blown") and f.air < 0.5 and f.state == "kslide" and in_gaze(f.pos):
					f.data.blown = 0.0
					f.data.blow_dir = (_luwu().face as Vector3).normalized()
					f.hp = 0.0
					f.set_state("dead")
					log_event("%s也被陸吾那一口氣吹走了" % f.name)
					if f.get_meta("boss", false):
						mark("boss_blown")
					_breath_n += 1
					if _breath_n >= 2:
						mark("luwu_two")
		return
	# 誰在視線裡（走進去的、滑進去的、撲進去的都算；已經出局的不算）
	for f in enemies:
		if f.alive() and not f.data.get("sunk", false) and not _victims.has(f) and f.air < 0.5 and in_gaze(f.pos):
			_victims.append(f)
			f.set_state("gazed")
			f.kb_vel = Vector3.ZERO
			anim(f, "Idle")
			log_event("%s進了陸吾的視線" % f.name)
	if bird.alive() and bird.state not in ["gazed", "blown", "lifted"] and not _victims.has(bird) and in_gaze(bird.pos):
		_victims.append(bird)
		bird.set_state("gazed")
		log_event("家豪進了陸吾的視線")
	if _victims.is_empty():
		return
	if _inhale < 0.0:
		_inhale = 0.0
		if world.has_method("luwu_inhale"):
			world.luwu_inhale()
		pop_label("嘶——", ground(_luwu().pos) + Vector3(0, 3.4, 0), Color(1.0, 0.9, 0.5), 600)
	_inhale += dt
	if _inhale < INHALE:
		return
	# 吹！
	var n: Vector3 = _luwu().face
	for v in _victims:
		var f: Fighter = v
		f.data.blown = 0.0
		f.data.blow_dir = (n + Vector3(0, 0, 0)).normalized()
		if f.is_bird:
			f.set_state("blown")
			_caught_by = "陸吾"
			log_event("家豪被陸吾吹走了")
			bubble("……我又沒做什麼", bird, 2.15, 2500)
		else:
			f.hp = 0.0
			f.set_state("dead")
			log_event("%s被陸吾吹走了" % f.name)
			mark("luwu_blow")
			if f.get_meta("boss", false):
				mark("boss_blown")
	_breath_n = 0 if _victims.has(bird) else _victims.size()
	_blow_tail = 0.5
	if _victims.size() >= 2 and not _victims.has(bird):
		mark("luwu_two")
	pop_label("呼——！", ground(_luwu().pos) + n * 2.0 + Vector3(0, 3.0, 0), Color(1.0, 0.95, 0.7), 1200)
	sfx("yell")
	_shake_until = Time.get_ticks_msec() + 350
	_victims.clear()
	_inhale = -1.0
	luwu_awake = false
	if world.has_method("luwu_sleep"):
		world.luwu_sleep()
	log_event("陸吾吹完，睡著了")

## 被吹走的人：往陸吾面對的方向飛出去、越飛越高，飛出畫面就收起來
func _tick_blown(f: Fighter, dt: float) -> void:
	var t: float = float(f.data.blown) + dt
	f.data.blown = t
	var dir: Vector3 = f.data.get("blow_dir", Vector3.FORWARD)
	f.pos += dir * 13.0 * dt
	f.air = 7.0 * t + 6.0 * t * t
	f.yaw += dt * 16.0
	if t > 1.3:
		f.node.visible = false

# ================================================================== 每一步

func _tick_enemy(f: Fighter, dt: float) -> void:
	if f.data.has("blown"):
		if float(f.data.blown) <= 1.3:
			_tick_blown(f, dt)
		return
	if f.state == "gazed":
		f.t += dt                          # 被陸吾盯住：定在原地發抖
		f.yaw += sin(f.t * 60.0) * 0.02
		return
	# 晚出發的人（大老闆那一批）：開打後先站著等
	var wait: float = float(f.get_meta("delay", 0.0))
	if phase == Phase.RUNNING and wait > 0.0 and time < wait and f.state == "rush":
		anim(f, "Idle")
		return
	# 走得慢的人（大老闆和阿金）：紅線那一段用自己的速度走
	if phase == Phase.RUNNING and f.get_meta("slow", false) and f.state == "rush" and f.alive() \
			and bird.state != "lifted" and not bird.data.get("held", false):
		f.can_slip = not f.get_meta("boss", false)
		f.t += dt
		var rush: Array = f.data.rush
		var ri: int = f.data.ri
		if ri >= rush.size():
			f.set_state("chase")
			return
		var tgt: Vector3 = ground(rush[ri])
		if flat_dist(f.pos, tgt) < 0.25:
			f.data.ri = ri + 1
		else:
			_walk(f, tgt, BOSS_SPEED, dt)
			anim(f, "Run")
		if f.get_meta("boss", false):
			_boss_peek(f)
		if world.in_water(f.pos.x, f.pos.z):
			fall_in(f)
		return
	super(f, dt)
	if f.get_meta("boss", false) and f.state not in ["kslide", "stunned"]:
		f.can_slip = false                 # 金釘鞋：踩到香蕉皮沒事（被滑過來的人撞到還是會一起滑）

## 大老闆走過香蕉皮：頭上冒「？」（跟守衛一樣），香蕉皮留在原地給後面的人踩
func _boss_peek(f: Fighter) -> void:
	var bi := skill_index("banana")
	if bi < 0:
		return
	for pl in items[bi].peels:
		if flat_dist(pl.pos, f.pos) < PEEL_STEP and _clock - float(f.data.get("peek_t", -9.0)) > 2.0:
			f.data.peek_t = _clock
			pop_label("？", f.pos + Vector3(0, 3.2, 0), Color(1, 1, 1), 900, f)

func _tick_bird(dt: float) -> void:
	var b := bird
	if b.state == "gazed":
		b.t += dt
		return
	if b.state == "blown":
		_tick_blown(b, dt)
		if float(b.data.blown) > 1.0:
			b.hp = 0.0
			b.set_state("dead")
			b.node.visible = false
		return
	# 第 3 關：黃線只走到唱盤前面；唱盤上沒有飼料，家豪就站在那裡不動
	if _needs_turntable() and not disc_fed and b.state in ["charge", "idle"] and path_i >= path.size():
		b.t += dt
		if not enemies.any(func(f): return f.alive() and f.state != "giveup"):
			_disc_wait += dt
			if not b.data.get("sighed", false):
				b.data.sighed = true
				bubble("……然後呢", bird, 2.15, 2500)
		return
	super(dt)

func _level_step(dt: float) -> void:
	super(dt)
	_step_luwu(dt)
	# 巨石撞到人：算進清單
	for f in enemies:
		if not f.alive() and f.state == "dead" and not f.data.get("sunk", false) and not f.data.has("blown") \
				and f.data.get("pile") == null and not f.data.get("rocked", false) and _rock_rolling_near(f):
			f.data.rocked = true
			_rock_hits += 1
			mark("rock_hit")
			if f.data.get("guard", f.get_meta("guard", false)):
				mark("rock_guard")
			pop_label("咚！", f.pos + Vector3(0, 3.2, 0), Color(1, 1, 1), 900, f)

## 巨石撞到人就停在那裡（不會帶著一路滾過整個白玉台，把別人的滑行路線擋住）
func _on_rock_rolling(rock: Dictionary, _pos: Vector3, _speed: float) -> bool:
	return not (rock.hit as Array).is_empty()

func _rock_rolling_near(f: Fighter) -> bool:
	var ri := skill_index("rock")
	if ri < 0:
		return false
	for r in items[ri].rocks:
		if (r.hit as Array).has(f):
			return true
	return false

# ================================================================== 唱盤上的飼料

func feed_error(p: Vector3) -> String:
	if _needs_turntable() and flat_dist(p, _turntable() as Vector3) <= DISC_R:
		if phase != Phase.PREPARE:
			return "飼料只能在準備階段放"
		return "唱盤上已經有飼料了" if disc_fed else ""
	if feed_pos != null:
		return "黃線只能彎一次（另一把放唱盤上）" if _needs_turntable() else "已經放過了"
	var why := super(p)
	return why.replace("冰洞", _word("hole_word", "洞")).replace("水裡", _word("hole_word", "洞") + "裡")

func place_feed(p: Vector3, node: Node3D) -> void:
	if _needs_turntable() and flat_dist(p, _turntable() as Vector3) <= DISC_R:
		disc_fed = true
		_disc_node = node
		pop_label("！", bird.pos + Vector3(0, 2.0, 0), Color(1, 0.9, 0.3), 800, bird)
		sfx("pop")
		log_event("唱盤上放了飼料")
		return
	super(p, node)

func _check_end() -> String:
	if _needs_turntable() and not disc_fed:
		# 沒有飼料把牠引上唱盤：到不了終點
		if not bird.alive():
			return "lose"
		if _disc_wait >= DISC_WAIT:
			_caught_by = "唱盤"
			log_event("家豪站在唱盤前面，沒有走上去")
			return "lose"
		if time >= time_limit:
			return "lose"
		return ""
	var res := super()
	if res == "win":
		if luwu_awake and not _luwu().is_empty():
			mark("luwu_idle")
		if doors_used >= 2:
			mark("door2")
	return res

func fall_in(f: Fighter) -> void:
	super(f)
	if f.get_meta("boss", false):
		mark("boss_hole")

# ================================================================== 字、標籤、視線的光

## 冰雪島的字換成仙境的說法
const WORDS := {"喀喀喀…": "咕嚕嚕…"}

func pop_label(text: String, pos: Vector3, color: Color, ms: int, follow: Fighter = null) -> void:
	super(String(WORDS.get(text, text)), pos, color, ms, follow)

## 事件紀錄的字也換成仙境的說法（冰雪島的程式寫的是冰上、冰洞、雪堆）
func log_event(text: String) -> void:
	var t := text.replace("在冰上一路滑出去", "在白玉地上一路滑出去").replace("掉進冰洞，凍成冰棒了", "掉進" + _word("hole_word", "洞") + "，出局了")
	t = t.replace("冰洞", _word("hole_word", "洞")).replace("雪堆", _word("pile_word", "落葉堆")).replace("雪地", _word("rough_word", "地上")).replace("冰上", "白玉地上")
	super(t)

func toast(text: String, dur: float) -> void:
	super(text.replace("雪地上不會滑", _word("rough_word", "這裡") + "上不會滑"), dur)

## 失敗提示分兩層：同一種死法（被同一個人抓到）第一次只點方向，第二次起才講明白。
## 關卡的 _defeat_tip_for() 裡用 _t2("只點方向的那一句", "講明白的那一句")。
static var _fail_counts := {}
var _tip_level := 0            # 0＝這種死法第一次；1＝第二次以後（測試工具會直接設這個值，兩句都印出來）

func _t2(first: String, later: String) -> String:
	return later if _tip_level >= 1 else first

func _show_defeat() -> void:
	var k := "%s/%s" % [_stage_key(), _caught_by]
	_fail_counts[k] = int(_fail_counts.get(k, 0)) + 1
	_tip_level = 1 if int(_fail_counts[k]) >= 2 else 0
	super()

func _defeat_tip_for(who: String) -> String:
	match who:
		"陸吾": return "陸吾只吹一口氣：讓別人先走進金光"
		"唱盤": return "黃線只到唱盤前面：唱盤上要放飼料"
	return super(who)

## 泡在雲洞裡的人不會結霜
func _set_frost(_f: Fighter, _on: bool) -> void:
	pass

func _process(dt: float) -> void:
	super(dt)
	_draw_gaze()
	_update_tags()

## 陸吾的視線：地上一塊金色的光（醒著才有）；黃線穿過去的那一段畫成紅色
func _draw_gaze() -> void:
	if _gaze_line == null:
		return
	var im := _gaze_line.mesh as ImmediateMesh
	im.clear_surfaces()
	if _luwu().is_empty() or not luwu_awake or phase == Phase.ENDED:
		return
	_vb.clear()
	var q := _gaze_corners()
	var pulse := 0.5 + 0.5 * sin(_clock * 3.0)
	var hot := _inhale >= 0.0
	# 一道從陸吾眼前照出去的金光：靠近牠的地方最濃，一波一波往外推（吸氣的時候變橘紅）
	var up := Vector3(0, 0.075, 0)
	var gl := _luwu()
	var gn: Vector3 = gl.face
	var gs := Vector3(-gn.z, 0, gn.x)
	var gc: Vector3 = gl.pos
	var strips := 9
	for s in strips:
		var t0 := float(s) / strips
		var t1 := float(s + 1) / strips
		var wave := 0.5 + 0.5 * sin(_clock * 4.0 - float(s) * 1.1)
		var a0 := lerpf(0.66, 0.30, t0) + 0.12 * wave
		var col := Color(1.0, 0.34, 0.12, a0) if hot else Color(1.0, 0.70, 0.08, a0)
		var d0 := lerpf(GAZE_NEAR, GAZE_FAR, t0)
		var d1 := lerpf(GAZE_NEAR, GAZE_FAR, t1)
		var c0 := ground(gc + gn * d0 - gs * GAZE_HALF) + up
		var c1 := ground(gc + gn * d0 + gs * GAZE_HALF) + up
		var c2 := ground(gc + gn * d1 + gs * GAZE_HALF) + up
		var c3 := ground(gc + gn * d1 - gs * GAZE_HALF) + up
		for v in [c0, c1, c2, c0, c2, c3]:
			_v(col, v)
	var ring: Array = [q[0], q[1], q[2], q[3], q[0]]
	var k := _px(q[0]) * 1.35
	_flow(ring, Color(0.72, 0.34, 0.02, 1.0), maxf(0.085, 2.6 * k), 0.085, 0.5, 0.35, _clock * 0.5)
	_flow(ring, Color(1.0, 0.93, 0.50, 1.0), maxf(0.05, 1.5 * k), 0.095, 0.5, 0.35, _clock * 0.5)
	# 黃線在視線裡的那一段：紅色
	if phase == Phase.PREPARE or bird.alive():
		var pts: Array = [bird.pos]
		for i in range(path_i, path.size()):
			pts.append(ground(path[i]))
		pts.append(world.cage)
		for i in range(1, pts.size()):
			var a: Vector3 = pts[i - 1]
			var b: Vector3 = pts[i]
			var n := maxi(int(flat_dist(a, b) / 0.25), 1)
			var run_a = null
			for s in range(0, n + 2):
				var p: Vector3 = a.lerp(b, minf(float(s) / n, 1.0))
				var inside: bool = s <= n and in_gaze(p)
				if inside and run_a == null:
					run_a = p
				elif not inside and run_a != null:
					var e: Vector3 = a.lerp(b, float(s - 1) / n)
					_solid(im, run_a, e, Color(0.86, 0.12, 0.17, 0.95), maxf(0.09, 2.2 * k), 0.13)
					run_a = null
	_flush(im)

func _update_tags() -> void:
	var cut := _cut_cam != null and _cut_cam.current
	var prep := phase == Phase.PREPARE and not cut
	if _gaze_label:
		_gaze_label.visible = prep and luwu_awake
		if _gaze_label.visible:
			var l := _luwu()
			_gaze_label.position = ground(l.pos as Vector3) + Vector3(0, 2.9, 0)       # 名牌掛在陸吾身上
	if _beam_label:
		_beam_label.visible = prep and luwu_awake
		if _beam_label.visible:
			var l2 := _luwu()
			_beam_label.position = ground((l2.pos as Vector3) + (l2.face as Vector3) * (GAZE_FAR + 0.5)) + Vector3(0, 0.7, 0)
	var ds := _doors()
	for i in _door_labels.size():
		var lb: Label3D = _door_labels[i]
		lb.visible = prep and i < ds.size()
		if lb.visible:
			# 名牌掛在門的背面那一側（正面那邊常常站著人，名牌才不會疊在一起）
			lb.position = (ds[i].pos as Vector3) - (ds[i].face as Vector3) * 1.1 + Vector3(0, 4.3, 0)
	for pl in _pile_labels:
		(pl as Label3D).visible = prep
	if _disc_label:
		_disc_label.visible = prep and not disc_fed
		if _disc_label.visible:
			var lastp: Vector3 = ground(path.back()) if not path.is_empty() else bird.pos
			_disc_label.position = lastp + Vector3(-2.2, 0.9, 0)

# ================================================================== 全章收尾

## 收尾的卡片：字換成這一章的名字
func _make_finale_card() -> Control:
	var panel := super()
	for l in panel.find_children("*", "Label", true, false):
		if String((l as Label).text).contains("完成"):
			(l as Label).text = "山海畫卷　全破！"
	# 全遊戲的最後一張卡：多一行收尾的話
	var vbs := panel.find_children("*", "VBoxContainer", true, false)
	var vb: VBoxContainer = vbs[0] if not vbs.is_empty() else null
	if vb:
		var thanks := Label.new()
		thanks.text = "家豪回家了。感謝遊玩！"
		thanks.label_settings = UISkin.ls(24, UISkin.INK)
		thanks.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(thanks)
		vb.move_child(thanks, 1)
	return panel

## 冰雪島的落點標記只管香蕉皮和飼料，而且會把共用的瞄準圈藏掉；選到巨石的時候把共用的瞄準圈（和滾動路線）放回來
func _update_aim_marker(cut: bool) -> void:
	super(cut)
	# 仙境的地是白玉色的：冰雪島那個白色的小圓圈會跟地板混在一起，改成橘色（放不下去是深灰）
	if _aim_dot and _aim_dot.material_override is StandardMaterial3D:
		(_aim_dot.material_override as StandardMaterial3D).albedo_color = Color(1.0, 0.46, 0.06) if aim_error == "" else Color(0.34, 0.36, 0.42)
		if _aim_dot.visible:
			_aim_dot.scale *= 1.6        # 順便放大一點
	if _preview == null or items.is_empty():
		return
	var rock_on: bool = String(items[selected].id) == "rock" and charges[selected] != 0 and phase == Phase.PREPARE \
			and not cut and not defeat_shown and aim_point != null
	if rock_on:
		_preview.visible = true
		_preview.global_position = (aim_point as Vector3) + Vector3(0, 0.08, 0)
		if aim_error == "" and _preview.material_override is StandardMaterial3D:
			(_preview.material_override as StandardMaterial3D).albedo_color = Color(1.0, 0.46, 0.06, 0.9)

## 這一章先不顯示家豪的血量（使用者 2026-11-19 的要求）：道具欄旁邊那張愛心紙片不蓋
func _build_hero_card(_layer: CanvasLayer, _hb: Vector2) -> void:
	pass

## 大老闆：黑帽金邊、深紫西裝（跟後面黃帽的阿金分得出來）
const BOSS_LOOK := {"hat": Color("23232c"), "hat2": Color("ffc93a"), "suit": Color("4a3378"), "skin": Color("f1bf98"), "hair": Color("2a1c14")}

func _setup_mini(f: Fighter, i: int) -> void:
	if f.name != "大老闆":
		super(f, i)
		return
	var rig := style_mini(f.node, BOSS_LOOK, "大老闆")
	if rig.is_empty():
		return
	rig.unit = (rig.skel as Skeleton3D).global_transform.basis.get_scale().y
	_rigs[f] = rig
	if f.anim:
		for a in ["idle", "walk", "sprint"]:
			if f.anim.has_animation(a):
				f.anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR

## 名牌：大老闆的寫上「不怕滑」，而且掛高一點，不跟旁邊的阿金疊在一起
func _update_intents() -> void:
	super()
	for f in enemies:
		if f.get_meta("boss", false) and _intents.has(f):
			var l: Label3D = _intents[f]
			if l.visible:
				l.text = "大老闆（不怕滑）"
				l.position += Vector3(0, 0.85, 0)

## 掉進洞裡的人：仙境的水不冰，不發抖——泡在裡面暈頭轉向、慢慢地浮沉（星洞裡是飄著慢慢晃）
func _mini_state(f: Fighter) -> Array:
	var st := super(f)
	if String(st[0]) == "sunk":
		return ["sunk", "dizzy"]
	return st

func _tick_sunk(f: Fighter, dt: float) -> void:
	super(f, dt)
	f.yaw = float(f.data.get("sunk_yaw", f.yaw))        # 不抖

func _level_visuals() -> void:
	super()
	var astral := String(world.get("mood")) == "astral"
	for i in enemies.size():
		var f: Fighter = enemies[i]
		var rig = _rigs.get(f)
		if rig == null or not f.data.get("sunk", false) or f.node == null:
			continue
		if _finale_t >= 0.0 and f.data.has("fin"):
			continue
		var t := _clock * 2.0 + float(i) * 1.7
		# 把冰雪島加的抖動拿掉，換成慢慢地浮沉
		f.node.global_position += Vector3(-sin(_clock * 63.0) * 0.03, sin(t) * (0.09 if astral else 0.045), 0)
		if astral:
			f.node.rotation.z = sin(t * 0.6) * 0.22
		pose_mini(rig, {
			"torso": Vector3(0.08, 0, sin(t * 0.5) * 0.05),
			"head": Vector3(-0.18 + cos(t * 1.2) * 0.12, 0, sin(t * 1.2) * 0.2),
			"arm-left": Vector3(0.3, -1.45, 0.45 + sin(t) * 0.08),
			"arm-right": Vector3(0.3, 1.45, -0.45 - sin(t) * 0.08),
		})
	# 特寫鏡頭貼著畫門、宮燈的時候，先把它藏起來（不然木架、燈柱會擋掉半個畫面）
	var cut := _cut_cam != null and _cut_cam.current
	var lns = world.get("lantern_nodes")
	if lns is Array:
		for ln in lns:
			if ln != null and is_instance_valid(ln):
				(ln as Node3D).visible = not (cut and _cut_cam.global_position.distance_to((ln as Node3D).global_position + Vector3(0, 1.5, 0)) < 3.4)
	for d in _doors():
		var dn = d.get("node")
		if dn != null and is_instance_valid(dn):
			(dn as Node3D).visible = not (cut and _cut_cam.global_position.distance_to((d.pos as Vector3) + Vector3(0, 1.6, 0)) < 4.2)

## 冰雪島收尾時有企鵝滑去撞人，仙境沒有
func _plan_bumps() -> void:
	pass

## 仙境的收尾（三個鏡頭）：家豪站上唱盤打碟（狀聲字一拍一個）→ 拉遠：山海轉盤轉起來、鳳凰金光升起、百鳥飛起 → 家豪和背後的鳳凰
const HFIN_DJ := 2.4          # 打碟的特寫到第幾秒（跟 heaven_world.gd 的 FIN_DJ 一樣）
const HFIN_WIDE := 5.6        # 拉遠看轉盤和鳳凰到第幾秒
const HFIN_LINE := 6.2        # 家豪說話
const HFIN_CARD := 7.4        # 卡片出現
const HFIN_SFX := ["嚓！", "♪", "嚓嚓！", "♫", "嚓！", "嚓嚓嚓！", "♪"]
var _hfin_beat := -1
var _hfin_gag = null           # 最後一鏡說話的那個人（泡在星洞裡的）
var _hfin_gag_said := false
var _hfin_card_t := 7.4        # 卡片第幾秒出現（有最後一鏡的話晚一點）

func _start_finale() -> void:
	super()
	_hfin_beat = -1
	var dp = world.get("disc")
	var disc: Vector3 = dp if dp is Vector3 else ground(bird.pos)
	_finale_bird = disc + Vector3(0, 0.22, 0)
	_finale_shots.a_on = false
	_finale_shots.dj_pos = disc + Vector3(2.4, 1.9, 4.6)
	_finale_shots.dj_look = disc + Vector3(0, 1.25, 0)
	_finale_shots.c_pos = disc + Vector3(-1.6, 2.6, 8.2)
	_finale_shots.c_look = disc + Vector3(0.7, 4.0, 0)
	# 唱盤上那把飼料已經吃掉了
	if _disc_node != null and is_instance_valid(_disc_node):
		_disc_node.visible = false
	# 最後一個鏡頭：泡在星洞裡的人抬頭看鳳凰（沒有人泡在洞裡就沒有這一鏡）
	_hfin_gag = null
	_hfin_gag_said = false
	_hfin_card_t = HFIN_CARD
	var sunk2: Array = enemies.filter(func(e): return e.data.get("sunk", false))
	if not sunk2.is_empty():
		var ctr := Vector3.ZERO
		for e in sunk2:
			ctr += e.pos
		ctr /= float(sunk2.size())
		var away := ctr - disc
		away.y = 0.0
		away = away.normalized() if away.length() > 0.5 else Vector3(0, 0, 1)
		var side := Vector3(-away.z, 0, away.x)
		# 鏡頭退到洞的外側、高一點：畫面下緣是泡在洞裡回頭看鏡頭的人，後面遠處是天上的鳳凰
		_finale_shots.d_pos = ctr + away * 7.0 + side * 1.4 + Vector3(0, 2.7, 0)
		_finale_shots.d_look = disc + Vector3(0, 1.8, 0)
		for e in sunk2:
			e.data.sunk_yaw = atan2(away.x, away.z)
			e.yaw = e.data.sunk_yaw
		_hfin_gag = sunk2[0]
		_hfin_card_t = HFIN_CARD + 2.4
	_finale_update()

## 收尾播放中按 Enter：先跳到卡片，卡片出來之後再按才回地圖
func _go_next() -> void:
	if _finale_t >= 0.0 and _finale_t < _hfin_card_t:
		_finale_t = _hfin_card_t
		return
	super()

func _finale_update() -> void:
	if _finale_t < 0.0 or _cut_cam == null or not is_inside_tree():
		return
	var sh := _finale_shots
	if not sh.has("dj_pos"):
		return
	var t := _finale_t
	world.set("_fin_t", t)             # 場地那邊的演出（唱盤、鳳凰、百鳥）跟著同一個時間
	_cut_cam.make_current()
	_cut_t = 99.0
	if t < HFIN_DJ:
		var dj_pos: Vector3 = sh.dj_pos
		var dj_look: Vector3 = sh.dj_look
		_cut_cam.fov = 44.0
		_cut_cam.global_position = dj_pos + (dj_look - dj_pos).normalized() * (t * 0.3)
		_cut_cam.look_at(dj_look, Vector3.UP)
		_cut_look = dj_look
		var beat := int(t / 0.34)
		if beat != _hfin_beat:
			_hfin_beat = beat
			var side := 1.0 if beat % 2 == 0 else -1.0
			pop_label(HFIN_SFX[beat % HFIN_SFX.size()], _finale_bird + Vector3(0.9 * side, 1.5 + 0.25 * (beat % 3), 0.4), Color(1.0, 0.84, 0.36), 520)
	elif t < HFIN_WIDE:
		var k := (t - HFIN_DJ) / (HFIN_WIDE - HFIN_DJ)
		var b_pos: Vector3 = sh.b_pos
		var b_look: Vector3 = sh.b_look
		var dirb := (b_look - b_pos).normalized()
		_cut_cam.fov = 54.0
		_cut_cam.global_position = b_pos - dirb * 2.0 + dirb * (k * 3.0)
		_cut_cam.look_at(b_pos + dirb * 60.0, Vector3.UP)
		_cut_look = b_look
	elif t >= HFIN_CARD + 0.4 and sh.has("d_pos") and _hfin_gag != null:
		# 泡在星洞裡的人，從他們背後看出去是天上的鳳凰
		_cut_cam.fov = 52.0
		_cut_cam.global_position = (sh.d_pos as Vector3) + Vector3(0, minf((t - HFIN_CARD - 0.4) * 0.12, 0.4), 0)
		_cut_cam.look_at(sh.d_look, Vector3.UP)
		_cut_look = sh.d_look
		if t >= HFIN_CARD + 1.0 and not _hfin_gag_said:
			_hfin_gag_said = true
			bubble("……那我們可以下班了嗎", _hfin_gag, 1.7, 60000)
	else:
		# 家豪在鳳凰的胸口，浮在半空；鏡頭慢慢往後退
		var c_pos: Vector3 = sh.c_pos
		var c_look: Vector3 = sh.c_look
		var back := (c_pos - c_look).normalized()
		_cut_cam.fov = 56.0
		_cut_cam.global_position = c_pos + back * minf((t - HFIN_WIDE) * 0.4, 2.2)
		_cut_cam.look_at(c_look, Vector3.UP)
		_cut_look = _finale_bird + Vector3(0, 1.2, 0)
	if t >= HFIN_LINE and not _finale_said:
		_finale_said = true
		bubble("……這次真的有聲音", bird, 1.7, 60000)
	if t >= _hfin_card_t and (_finale_card == null or not is_instance_valid(_finale_card)):
		_finale_card = _make_finale_card()

## 收尾時家豪站在唱盤上：打碟的時候身體跟著拍子晃、面向鏡頭
func _bird_visuals(vcam: Camera3D) -> void:
	super(vcam)
	if _finale_t < 0.0 or not _finale_shots.has("dj_pos") or bird.node == null:
		return
	var n: Node3D = bird.node
	var t := _finale_t
	var cam_p: Vector3 = _finale_shots.dj_pos if t < HFIN_DJ else (_finale_shots.b_pos if t < HFIN_WIDE else _finale_shots.c_pos)
	var d := cam_p - _finale_bird
	var bob := absf(sin(t * 9.2)) * 0.10 if t < HFIN_DJ else 0.0
	var up: float = world.fin_rise(t) if world.has_method("fin_rise") else 0.0
	n.global_position = _finale_bird + Vector3(0, bob + up + (0.12 * sin(t * 2.2) if up > 0.1 else 0.0), 0)
	n.rotation = Vector3(0.10 * sin(t * 9.2) if t < HFIN_DJ else -0.10, atan2(d.x, d.z), 0.16 * sin(t * 4.6) if t < HFIN_DJ else 0.0)
	# 打碟：身體壓低、往前傾，跟著拍子左右搓（蓋掉過關歡呼的跳）
	var body = bird.get("body")
	if body is Node3D and t < HFIN_DJ:
		(body as Node3D).position.y = 0.0
		(body as Node3D).rotation = Vector3(0.42 + 0.10 * sin(t * 18.4), sin(t * 9.2) * 0.35, sin(t * 9.2) * 0.22)
	n.visible = true

## 工人：跟冰雪島一樣，多幾個可以寫的欄位（_enemy_specs() 裡用）
##   slow_rusher：走得慢、晚出發的人（大老闆那一批）。boss＝穿金釘鞋不怕香蕉皮
func slow_rusher(name: String, spawn: Vector3, rush: Array, delay: float, boss := false) -> Dictionary:
	var d := rusher(name, spawn, rush)
	d["slow"] = true
	d["delay"] = delay
	d["boss"] = boss
	return d
