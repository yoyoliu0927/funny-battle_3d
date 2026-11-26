extends "res://levels/ice/story/story_kit.gd"
## 冰羽踏雪的結尾動畫（第 1 天晚上）。分鏡在 levels/ice/docs/大關開場與結尾動畫.md 第 4 節。
## 第一次破完第 6 關、「冰羽踏雪　完成！」卡片按 Enter 之後播（見 ice_story.gd），播完回地圖。
## 場地借第 6 關「燈籠夜市・極光夜」（拿掉戰局和玩家）；極光和肚滑過湖的企鵝用場地自己的全章收尾。
##
## 七拍：收場（洞裡泡著的人）→ 號碼（企鵝咬掉翅膀上的號碼丟進冰洞）→ 腳牌 → 靜音拍（站在空籠子上打碟）
##       → 羽毛（風掀起帽沿）→ 上船（企鵝推船，企鵝老大跟著走）→ 手帳

const STAGE := "res://levels/ice/stage_16/stage.tscn"
const RB := preload("res://levels/ice/rescue_battle.gd")   # 工人的模型和造型（style_mini、LOOKS）
const SEA_Y := -3.0
const CYAN := Color("4fc3d9")          # 冰雪島的羽毛（跟選關地圖 FEATHER_COLORS 同一色）
const HOLE := Vector2(7.6, -6.5)       # 冰洞乙：阿土、阿水、守衛乙
const HOLE2 := Vector2(6.0, 1.2)       # 冰洞甲：阿火、守衛甲
const PEN_NUMS := ["01", "21", "22", "23", "24"]
const HEAD_OUT := 0.8                  # 泡在冰洞裡的人：頭頂高出水面多少（臉在水面上、肩膀剛好碰到水）

func _lines() -> Array:
	return [
		{"shot": "hole", "who": "阿土", "text": "唉……又是洞。", "cue": "h_sigh", "fade_in": 1.0},
		{"shot": "hole", "who": "阿水", "text": "我要調單位。", "cue": "h_transfer"},
		{"shot": "hole", "hold": 5.0, "cue": "r_rings"},
		{"shot": "tag", "who": "企鵝老大", "text": "嘎？（你也有？）", "cue": "g_ask", "snap": 1.6},
		{"shot": "tag", "who": "家豪", "text": "……這個不是我的。", "cue": "g_not", "snap": 1.8},
		{"shot": "dj", "hold": 7.6, "cue": "d_silence", "fade_out": 0.6, "fade_in": 0.9},
		{"shot": "dj", "who": "家豪", "text": "……今天放什麼歌。也沒人問。", "cue": "d_line", "snap": 2.2},
		{"shot": "hood", "hold": 2.2, "cue": "w_gust"},
		{"shot": "hood", "who": "神明", "text": "你帽子裡是不是有東西？", "cue": "w_god"},
		{"shot": "hood", "who": "家豪", "text": "沒有。", "cue": "w_no", "snap": 1.4},
		{"shot": "leave", "hold": 5.6, "cue": "l_leave", "fade_out": 0.6, "fade_in": 1.0},
		{"shot": "journal", "hold": 6.4, "cue": "j_page", "fade_out": 0.6, "fade_in": 0.8},
	]

func _skip_text() -> String:
	return "跳過"

var _world
var _h := 0.0
var _edge := 15.0
var _cage := Vector3(0, 0, -11.8)
var _cage_top := 2.5
var _workers: Array = []             # {wrap, rig, v, ph, id}
var _pens: Array = []                # {node, tag, home}
var _leader: Dictionary = {}
var _boat: Node3D
var _journal_p: Control
var _leave_on := false
var _water := -0.6                   # 冰洞的水面
var _ice := 0.0                      # 冰洞旁邊的冰面

## 地面上的點
func G(x: float, z: float) -> Vector3:
	return Vector3(x, float(_world.height_at(x, z)), z)

func _story_build() -> void:
	mark_seen("ice_ending")
	var stage := _borrow_stage(STAGE)
	_world = stage.get_node("World")
	if _world.get("cage") is Vector3:
		_cage = _world.get("cage")
	_h = float(_world.height_at(0.0, 9.0))
	for i in 160:
		var z := 9.0 + i * 0.12
		if float(_world.height_at(0.0, z)) < _h - 0.8:
			_edge = z - 0.4
			break
	# 全章收尾：極光放大、四隻企鵝肚子貼著冰面滑過湖
	if _world.has_method("finale_show"):
		_world.finale_show(true)
	# 籠子已經開了、裡面空了
	if _world.has_method("open_cage"):
		_world.open_cage(Vector3(0, 0, -8.0), Vector3(0, 6, 12))
		_world.set("_free_t", 9.0)
	var wp = _world.get("_penguins")
	if wp is Array:
		for p in wp:
			((p as Dictionary).node as Node3D).visible = false
	var lbl = _world.get("_cage_label")
	if lbl is Node3D:
		(lbl as Node3D).visible = false
	var cr = _world.get("_cage_root")
	if cr is Node3D:
		_cage_top = _top_y(cr, _cage.x, _cage.z)
		if _cage_top < -100.0:
			_cage_top = _h + 2.4
	_make_hero(self, [CYAN])
	# 泡在冰洞裡的人：水面在冰面底下一點（arena_world 的 water_y）
	_ice = float(_world.height_at(HOLE.x + 2.4, HOLE.y))
	_water = float(_world.get("water_y")) if _world.get("water_y") != null else _ice - 0.6
	var hy := _water
	var hy2 := _water
	var cam := _hole_cam()
	for w in [["阿土", Vector2(-0.55, 0.35), 1], ["阿水", Vector2(0.6, 0.3), 1], ["守衛乙", Vector2(0.05, -0.5), 1]]:
		var at := Vector3(HOLE.x + w[1].x, hy, HOLE.y + w[1].y)
		_worker(w[0], at, atan2(cam.x - at.x, cam.z - at.z), w[2])
	for w in [["阿火", Vector2(-0.4, 0.1)], ["守衛甲", Vector2(0.45, -0.15)]]:
		var at := Vector3(HOLE2.x + w[1].x, hy2, HOLE2.y + w[1].y)
		_worker(w[0], at, 0.3, 1)
	# 企鵝：老大大一號，每一隻胸前都掛著號碼牌
	for k in 5:
		var p: Node3D = _world.make_penguin(self, Vector3.ZERO, 0.0)
		p.scale = Vector3.ONE * (1.15 if k == 0 else 0.92)
		var tag := _tag_penguin(p, PEN_NUMS[k])
		var d := {"node": p, "tag": tag, "k": k}
		_pens.append(d)
	_leader = _pens[0]
	_boat = _make_boat()

## 冰洞乙的特寫鏡頭位置（從西南邊看過去）
func _hole_cam() -> Vector3:
	return Vector3(HOLE.x - 2.0, _ice + 2.3, HOLE.y + 2.3)

## 一個泡在冰洞裡的人：只露出頭和肩膀，一直發抖
func _worker(id: String, at: Vector3, yaw: float, v: int) -> void:
	var path: String = RB.MODEL_GUARD if id.begins_with("守衛") else RB.MODEL_WORKER
	var scene := load(path) as PackedScene
	if scene == null:
		return
	var model := scene.instantiate() as Node3D
	var wrap := Node3D.new()
	wrap.add_child(model)
	wrap.set_meta("source", path)
	model.scale = Vector3.ONE * 2.05
	add_child(wrap)
	wrap.global_position = at
	wrap.rotation.y = yaw
	var rig: Dictionary = RB.style_mini(wrap, RB.LOOKS.get(id, RB.LOOKS["工人"]), id)
	var ap := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap:
		ap.pause()
	if not rig.is_empty():
		# 頭頂（含帽子）露出水面 HEAD_OUT 公尺：臉在水面上、肩膀以下泡在水裡
		RB.pose_mini(rig, {})
		var top := RB.mini_point(rig, "head", Vector3(0, 0.52, 0))
		wrap.global_position.y += at.y + HEAD_OUT - top.y
	_workers.append({"wrap": wrap, "rig": rig, "v": v, "ph": _workers.size() * 1.37, "id": id})

func _worker_of(id: String) -> Dictionary:
	for w in _workers:
		if String(w.id) == id:
			return w
	return {}

## 頭頂在哪（狀聲字、砸到頭用）
func _head_top(w: Dictionary) -> Vector3:
	if w.is_empty():
		return Vector3.ZERO
	if (w.rig as Dictionary).is_empty():
		return (w.wrap as Node3D).global_position + Vector3(0, 1.0, 0)
	return RB.mini_point(w.rig, "head", Vector3(0, 0.52, 0))

func _pen_anim(p: Dictionary, anim: String) -> void:
	if _world.has_method("penguin_anim"):
		_world.penguin_anim(p.node, anim)

func _pen_face(p: Dictionary, target: Vector3) -> void:
	var n := p.node as Node3D
	var d := target - n.global_position
	n.rotation.y = atan2(d.x, d.z)

## 企鵝把胸前的號碼牌咬下來，往 to 丟過去
func _toss_tag(p: Dictionary, to: Vector3, then := Callable()) -> void:
	var tag := p.tag as Node3D
	if tag == null or not tag.visible:
		return
	var from := tag.global_position
	tag.reparent(self)
	var arc := func(k: float) -> void:
		var q := from.lerp(to, k)
		q.y += sin(k * PI) * 1.3
		tag.global_position = q
		tag.rotation = Vector3(k * 9.0, k * 5.0, 0)
	var tw := _tw()
	tw.tween_method(arc, 0.0, 1.0, 0.7)
	tw.tween_callback(func():
		tag.visible = false
		if then.is_valid():
			then.call())

func _story_tick(dt: float) -> void:
	# 洞裡的人：凍得一直發抖（兩手扒著冰面）
	for w in _workers:
		var rig: Dictionary = w.rig
		if rig.is_empty() or not (w.wrap as Node3D).visible:
			continue
		var t := _t + float(w.ph)
		var sh := sin(t * 55.0) * 0.07
		RB.pose_mini(rig, {
			"torso": Vector3(0.1, 0, sh * 0.5),
			"head": Vector3(-0.05, 0, sin(t * 47.0) * 0.06),
			"arm-left": Vector3(0.3, -1.45, 0.45 + sh),
			"arm-right": Vector3(0.3, 1.45, -0.45 + sh),
		})
	# 上船：企鵝在水裡推著船往外海走
	if _leave_on and _boat:
		var k := clampf(_shot_t / 5.4, 0.0, 1.0)
		var e := k * k * (3.0 - 2.0 * k)
		var a := Vector3(0.6, SEA_Y, _edge + 3.0)
		var b := Vector3(3.2, SEA_Y, _edge + 16.0)
		_boat_at(_boat, a.lerp(b, e), b - a)
		(_hero.node as Node3D).global_position = _boat.to_global(Vector3(0, 0.24, -0.35))
		(_hero.node as Node3D).rotation.y = _boat.rotation.y
		var ld := _leader.node as Node3D
		ld.global_position = _boat.to_global(Vector3(0, 0.22, 0.85))
		ld.rotation.y = _boat.rotation.y
		for p in _pens:
			if p == _leader:
				continue
			var i := int(p.k) - 1
			var n := p.node as Node3D
			n.global_position = _boat.to_global(Vector3(-0.75 + 0.5 * i, -0.45, -1.7 - 0.25 * (i % 2)))
			n.rotation.y = _boat.rotation.y

# ================================================================== 鏡頭

func _enter_shot(s: String) -> void:
	var hero := _hero.node as Node3D
	hero.visible = true
	hero.rotation = Vector3.ZERO
	_hero.look = null
	_set_anim(_hero, "idle")
	_hood_reset()
	_notes(false)
	_leave_on = false
	if _boat:
		_boat.visible = s == "leave"
	for w in _workers:
		(w.wrap as Node3D).visible = s in ["hole", "tag", "dj", "hood"]
	for p in _pens:
		(p.node as Node3D).visible = s != "journal"
		(p.node as Node3D).scale = Vector3.ONE * (1.15 if p == _leader else 0.92)
	match s:
		"hole":
			hero.global_position = G(HOLE.x + 2.1, HOLE.y + 1.7)
			_face(_hero, G(HOLE.x, HOLE.y))
			# 企鵝站在冰洞北邊（從鏡頭看過去在洞裡那幾個人後面）
			for p in _pens:
				var a := -2.25 + 0.42 * float(p.k)
				var n := p.node as Node3D
				n.global_position = G(HOLE.x + cos(a) * 2.2, HOLE.y + sin(a) * 2.2)
				_pen_face(p, G(HOLE.x, HOLE.y))
				_pen_anim(p, "idle")
		"tag":
			var hp := G(HOLE.x + 2.1, HOLE.y + 1.7)
			hero.global_position = hp
			var lp := hp + Vector3(-0.2, 0, -0.95)
			(_leader.node as Node3D).global_position = G(lp.x, lp.z)
			_face(_hero, lp)
			_pen_face(_leader, hp)
			_pen_anim(_leader, "idle")
		"dj", "hood":
			hero.global_position = Vector3(_cage.x, _cage_top, _cage.z + 0.1)
			hero.rotation.y = 0.0
			# 企鵝排在籠子前面，面向籠子上的家豪
			for p in _pens:
				var i := int(p.k)
				var n := p.node as Node3D
				var x: float = [0.0, -1.5, 1.5, -2.8, 2.8][i]
				var z: float = _cage.z + float([3.4, 3.0, 3.0, 2.4, 2.4][i])
				n.global_position = G(x, z)
				_pen_face(p, Vector3(_cage.x, _cage_top, _cage.z))
				_pen_anim(p, "idle")
		"leave":
			_leave_on = true
			hero.global_position = _boat.to_global(Vector3(0, 0.24, -0.35))
			for p in _pens:
				_pen_anim(p, "idle" if p == _leader else "run")
		"journal":
			hero.visible = false

func _on_line(l: Dictionary) -> void:
	var hero := _hero.node as Node3D
	var hole := Vector3(HOLE.x, _water, HOLE.y)
	match String(l.get("cue", "")):
		# ---------------------------------------------------------- ① 收場
		"h_sigh":
			_shot_cam(_hole_cam(), hole + Vector3(0.05, 0.3, -0.25), 44.0, 0.0, Vector3(0.03, 0, -0.04))
			_amb_play("wind", -18.0, 1.0)
			_music_play("theme", -20.0, 2.0)
			_at(0.3, func(): _emote(_head_top(_worker_of("阿土")), "唉", Color(0.75, 0.9, 1.0), 1.2, 0.7))
		"h_transfer":
			_at(0.2, func(): _emote(_head_top(_worker_of("阿水")), "…", Color(0.75, 0.9, 1.0), 1.0, 0.7))
		# ---------------------------------------------------------- ② 號碼
		"r_rings":
			# 企鵝一隻一隻把翅膀上的號碼咬下來，丟進冰洞；有一個砸在阿土頭上
			_shot_cam(Vector3(HOLE.x - 4.4, _ice + 2.4, HOLE.y + 4.4), hole + Vector3(0, 0.7, -0.8), 42.0, 0.0, Vector3(0.05, -0.02, -0.08))
			for i in _pens.size():
				var p: Dictionary = _pens[i]
				_at(0.3 + 0.75 * i, func(): _pen_anim(p, "eat"))
				var to := hole + Vector3(-0.6 + 0.3 * i, 0.02, 0.2 * (i % 2))
				var hit := i == 2
				if hit:
					to = _head_top(_worker_of("阿土"))
				_at(0.6 + 0.75 * i, func():
					_toss_tag(p, to, func():
						if hit:
							_emote(to + Vector3(0, 0.2, 0), "咚！", Color(1, 1, 1), 0.9, 0.9)
							_play("thud", -10.0, 1.5)
						else:
							_emote(to + Vector3(0, 0.6, 0), "撲通", Color(0.62, 0.9, 1.0), 0.8, 0.7)
							_play("plop", -9.0, 0.9 + 0.08 * i))
					_pen_anim(p, "gesture-positive"))
		# ---------------------------------------------------------- ③ 腳牌
		"g_ask":
			var hp := hero.global_position
			_shot_cam(hp + Vector3(-3.6, 1.7, 2.7), hp + Vector3(-0.15, 0.8, -0.45), 36.0, 0.0, Vector3(0.03, 0, -0.03))
			_at(0.2, func():
				_pen_anim(_leader, "eat")
				_play("pop", -14.0, 1.6))
			_at(1.0, func():
				_pen_anim(_leader, "idle")
				_emote((_leader.node as Node3D).global_position + Vector3(0, 1.3, 0), "？", Color(1, 1, 1), 1.0, 0.8))
		"g_not":
			var hp := hero.global_position
			_shot_cam(hp + Vector3(-1.0, 1.6, -3.3), hp + Vector3(0, 1.1, 0), 30.0, 0.0, Vector3(0.02, 0, -0.02))
			_set_anim(_hero, "sad")
			_at(1.3, func(): _set_anim(_hero, "cool"))
		# ---------------------------------------------------------- ④ 靜音拍
		"d_silence":
			# 站在空掉的籠子上，背後是極光。配樂收掉，只剩風聲
			_shot_cam(G(2.2, _cage.z + 8.6) + Vector3(0, 2.0, 0), Vector3(_cage.x, _cage_top * 0.62, _cage.z + 0.8), 50.0, 0.0, Vector3(-0.04, 0.01, -0.12))
			_music_stop(1.6)
			_at(0.4, func():
				_set_anim(_hero, "dj", 0.8)
				_notes(true))
			_at(1.4, func():
				for p in _pens:
					_pen_anim(p, "dance"))
			# 企鵝老大用嘴接住一顆音符，像吞魚一樣吞下去；聽不到
			_at(2.6, func():
				var ld := _leader.node as Node3D
				_note_to(ld.global_position + Vector3(0, 1.05, 0.15), 1.3, func():
					_pen_anim(_leader, "eat")
					_emote(ld.global_position + Vector3(0, 1.4, 0), "咕嘟", Color(1, 1, 1), 0.9, 0.7)
					_play("pop", -12.0, 0.8)))
			_at(4.4, func():
				_pen_anim(_leader, "dance")
				_emote((_leader.node as Node3D).global_position + Vector3(0, 1.4, 0), "？", Color(1, 1, 1), 1.0, 0.7))
		"d_line":
			_shot_cam(Vector3(_cage.x + 1.3, _cage_top + 1.05, _cage.z + 3.4), Vector3(_cage.x, _cage_top + 0.9, _cage.z), 30.0, 0.0, Vector3(0.02, 0, 0.03))
			_set_anim(_hero, "dj", 0.45)
			_notes(true)
		# ---------------------------------------------------------- ⑤ 羽毛
		"w_gust":
			# 從背後看：一陣冷風掀起帽沿，帽子底下露出一根青色的羽毛尖
			_shot_cam(Vector3(_cage.x - 1.1, _cage_top + 2.0, _cage.z - 4.6), Vector3(_cage.x, _cage_top + 1.2, _cage.z), 34.0, 0.0, Vector3(0.02, 0, 0.05))
			_set_anim(_hero, "idle")
			_amb_play("wind", -9.0, 0.3)
			_at(0.2, func(): _play("whoosh", -8.0, 0.6))
			_at(0.4, func():
				_hood_lift()
				_play("ding", -16.0, 1.2))
			_at(1.4, func(): _amb.volume_db = -18.0)
		"w_god":
			pass
		"w_no":
			_at(0.15, func():
				_set_anim(_hero, "cool")
				_hood_down()
				_emote(_hero, "…", Color(1, 1, 1), 1.0, 0.8))
		# ---------------------------------------------------------- ⑥ 上船
		"l_leave":
			_shot_cam(Vector3(-1.4, _h + 1.6, _edge - 0.9), Vector3(1.6, SEA_Y + 0.4, _edge + 7.0), 46.0, 0.0, Vector3(0.05, 0, 0.1))
			_amb_play("waves", -15.0, 1.0)
			_music_play("theme", -18.0, 2.5)
		# ---------------------------------------------------------- ⑦ 手帳
		"j_page":
			_shot_cam(Vector3(0, _h + 1.6, 8.0), Vector3(0, 16.0, -60.0), 62.0, 0.0, Vector3(0, 0.03, -0.05))
			_at(0.5, func(): _journal_p = _journal_page(1, "企鵝樂園。企鵝不覺得是樂園。", CYAN, "駁大莖森"))
