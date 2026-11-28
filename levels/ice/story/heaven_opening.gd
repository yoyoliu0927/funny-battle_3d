extends "res://levels/ice/story/story_kit.gd"
## 丹穴山海的開場動畫（第 5 天）。分鏡在 levels/ice/docs/大關開場與結尾動畫.md 第 8 節。
## 每次在選關地圖按丹穴山第 1 關都先播（見 story_registry.gd；直接開第 1 關的保險在丹穴山 1 的 world.gd、battle.gd），播完進第 1 關。
## 場地借第 1 關「雲階」：南邊是雪地和紅梅（從冰雪島走過來），越往北雪越融，霧裡是南天門。
## 丹穴山不是島、看不到海，所以不坐船：企鵝在雪地的山腳送行，家豪自己爬上去。
## 丹穴山的結尾就是整個遊戲的結局（levels/heaven/ending/ending.gd），這裡只有開場。
##
## 五拍：山腳（企鵝送行）→ 往上爬（鳥群往山頂飛）→ 對話 → 尋雞啟事（阿土、阿水追上來）→ 標題卡

const STAGE := "res://levels/heaven/stage_1/stage.tscn"
const RB := preload("res://levels/ice/rescue_battle.gd")   # 工人的模型和造型
const HM := "res://levels/heaven/assets/blender/"

func _lines() -> Array:
	return [
		{"shot": "foot", "hold": 5.2, "cue": "f_foot", "fade_in": 1.4},
		{"shot": "climb", "hold": 4.8, "cue": "c_climb"},
		{"shot": "gate", "who": "神明", "text": "丹穴山。傳說鳳凰住的地方。", "cue": "g_name"},
		{"shot": "gate", "who": "家豪", "text": "……鳥都往這裡飛。", "cue": "g_birds"},
		{"shot": "gate", "who": "神明", "text": "先說，這裡沒人認識我。山上的時間也不照順序走。", "cue": "g_nobody"},
		{"shot": "gate", "hold": 3.4, "cue": "p_fly"},
		{"shot": "gate", "who": "阿土", "text": "一卡車欸。你不是說要調單位？", "cue": "p_atu"},
		{"shot": "gate", "who": "阿水", "text": "……我說的不是這種調。", "cue": "p_ashui", "snap": 1.4},
		{"shot": "card", "hold": 4.0, "cue": "card", "fade_out": 0.5, "fade_in": 0.9},
	]

func _skip_text() -> String:
	return "跳過開場"

func _next_scene() -> String:
	return _stage_after(STAGE)

func _voice_pitch(who: String) -> float:
	return 0.9 if who == "阿水" else super(who)

var _world
var _gate := Vector3(0, 0, -11.8)    # 南天門
var _pens: Array = []
var _cranes: Array = []              # {node, wl, wr, from, to, t0, dur, ph}
var _workers: Array = []             # {wrap, ap, rig, name}
var _paper: Node3D                   # 被風吹上來的那張懸賞單
var _poster_p: Control

## 地面上的點
func G(x: float, z: float) -> Vector3:
	return Vector3(x, float(_world.height_at(x, z)), z)

func _story_build() -> void:
	mark_seen("heaven_opening")      # 先記下來：底下借第 1 關的場地時，那一關就不會又轉回開場
	var stage := _borrow_stage(STAGE)
	_world = stage.get_node("World")
	if _world.get("cage") is Vector3:
		_gate = _world.get("cage")
	_make_hero(self)
	# 山腳送行的企鵝（留在冰雪島上的那幾隻，一路陪到雪地的盡頭）
	if _world.has_method("make_penguin"):
		for k in 4:
			var p: Node3D = _world.make_penguin(self, Vector3.ZERO, 0.0)
			p.scale = Vector3.ONE * 0.95
			_pens.append(p)
	# 往山頂飛的鳥（仙鶴）
	for k in 6:
		var c := _glb(self, HM + "crane.glb", Vector3.ZERO, 0.0, 0.42 + 0.06 * (k % 3))
		if c == null:
			continue
		_no_shadow(c)
		c.visible = false
		_cranes.append({"node": c, "wl": c.find_child("WingL", true, false), "wr": c.find_child("WingR", true, false),
			"from": Vector3.ZERO, "to": Vector3.ZERO, "t0": -1.0, "dur": 1.0, "ph": k * 1.37})
	# 阿土、阿水：從冰雪島一路追上來，頭髮還結著冰
	for nm in ["阿土", "阿水"]:
		_worker(nm)
	# 被風吹上雲階的懸賞單（一張小紙）
	_paper = Node3D.new()
	add_child(_paper)
	_box(_paper, Vector3(0.5, 0.66, 0.02), Vector3.ZERO, _toon(Color("f1e2b8")))
	var t := Label3D.new()
	t.text = "尋雞\n啟事"
	if UIStyle.font():
		t.font = UIStyle.font()
	t.font_size = 64
	t.pixel_size = 0.0032
	t.modulate = UIStyle.RIBBON
	t.outline_size = 0
	t.position = Vector3(0, 0.08, 0.012)
	_paper.add_child(t)
	_paper.visible = false

## 一個站著的工人（走路、撿東西用模型自己的動畫）；頭上放幾顆冰
func _worker(nm: String) -> void:
	var path: String = RB.MODEL_WORKER
	var scene := load(path) as PackedScene
	if scene == null:
		return
	var model := scene.instantiate() as Node3D
	var wrap := Node3D.new()
	wrap.add_child(model)
	wrap.set_meta("source", path)
	model.scale = Vector3.ONE * 2.05
	add_child(wrap)
	var rig: Dictionary = RB.style_mini(wrap, RB.LOOKS.get(nm, RB.LOOKS["工人"]), nm)
	var ap := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	# 頭髮結冰：頭頂幾顆冰塊
	if not rig.is_empty():
		var top := wrap.to_local(RB.mini_point(rig, "head", Vector3(0, 0.52, 0)))
		var ice := _glow(Color(0.80, 0.93, 1.0))
		for k in 4:
			var a := k * 1.7
			_no_shadow(_ball(wrap, 0.06 + 0.02 * (k % 2), top + Vector3(cos(a) * 0.12, -0.04 + 0.03 * k, sin(a) * 0.1), ice, Vector3(1.0, 0.7, 1.0), 6))
	wrap.visible = false
	_workers.append({"wrap": wrap, "ap": ap, "rig": rig, "name": nm})

func _worker_anim(w: Dictionary, anim: String) -> void:
	var ap := w.ap as AnimationPlayer
	if ap and ap.has_animation(anim):
		ap.get_animation(anim).loop_mode = Animation.LOOP_LINEAR if anim in ["walk", "idle"] else Animation.LOOP_NONE
		ap.play(anim, 0.2)

## 工人從 a 走到 b（dur 秒），走到了站好
func _worker_walk(w: Dictionary, a: Vector3, b: Vector3, dur: float, delay := 0.0) -> void:
	var n := w.wrap as Node3D
	n.visible = true
	n.global_position = a
	n.rotation.y = atan2(b.x - a.x, b.z - a.z)
	var tw := _tw()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_callback(func(): _worker_anim(w, "walk"))
	tw.tween_property(n, "global_position", b, dur)
	tw.tween_callback(func(): _worker_anim(w, "idle"))

## 一隻仙鶴從 a 飛到 b
func _crane_fly(k: int, a: Vector3, b: Vector3, dur: float, delay := 0.0) -> void:
	if k >= _cranes.size():
		return
	var c: Dictionary = _cranes[k]
	c.from = a
	c.to = b
	c.t0 = _t + delay
	c.dur = dur
	(c.node as Node3D).visible = delay <= 0.0
	(c.node as Node3D).global_position = a

func _story_tick(_dt: float) -> void:
	for c in _cranes:
		var n := c.node as Node3D
		if float(c.t0) < 0.0:
			continue
		var k := (_t - float(c.t0)) / float(c.dur)
		if k < 0.0:
			continue
		n.visible = k <= 1.0
		k = clampf(k, 0.0, 1.0)
		var a: Vector3 = c.from
		var b: Vector3 = c.to
		n.global_position = a.lerp(b, k) + Vector3(0, sin(k * PI) * 1.2 + sin(_t * 3.0 + float(c.ph)) * 0.15, 0)
		var d := b - a
		n.rotation = Vector3(0, atan2(d.x, d.z), 0)
		var fl := sin(_t * 9.0 + float(c.ph) * 3.0) * 0.6
		if c.wl:
			(c.wl as Node3D).rotation.z = -fl
		if c.wr:
			(c.wr as Node3D).rotation.z = fl

# ================================================================== 鏡頭

func _enter_shot(s: String) -> void:
	var hero := _hero.node as Node3D
	hero.visible = s != "card"
	hero.rotation = Vector3(0, PI, 0)       # 面向北邊（山上）
	_hero.look = null
	_set_anim(_hero, "idle")
	for p in _pens:
		(p as Node3D).visible = s == "foot"
	for w in _workers:
		(w.wrap as Node3D).visible = false
	_paper.visible = false
	match s:
		"foot":
			hero.global_position = G(0.0, 21.0)
			# 企鵝站在雪地的盡頭，面向家豪的背影
			for k in _pens.size():
				var p := _pens[k] as Node3D
				p.global_position = G(-2.2 + 1.5 * k, 22.4 + 0.4 * (k % 2))
				p.rotation.y = PI
				if _world.has_method("penguin_anim"):
					_world.penguin_anim(p, "idle")
		"climb":
			hero.global_position = G(0.0, 13.0)
		"gate":
			hero.global_position = G(0.0, 5.6)

func _on_line(l: Dictionary) -> void:
	var hero := _hero.node as Node3D
	match String(l.get("cue", "")):
		# ---------------------------------------------------------- ① 山腳
		"f_foot":
			# 從企鵝背後看：家豪沿著雪地的步道往山上走，企鵝搖翅膀送行
			_shot_cam(G(4.8, 28.0) + Vector3(0, 3.4, 0), G(-0.4, 17.0) + Vector3(0, 0.6, 0), 46.0, 0.0, Vector3(-0.05, 0.02, -0.2))
			_music_play("theme", -17.0, 2.5)
			_amb_play("wind", -18.0, 1.5)
			_at(0.3, func(): _walk(_hero, G(0.0, 16.5), 4.6))
			_at(0.8, func():
				for p in _pens:
					if _world.has_method("penguin_anim"):
						_world.penguin_anim(p, "gesture-positive"))
			_at(2.6, func():
				_face(_hero, G(0.0, 26.0), 0.3)
				_emote(_hero, "…", Color(1, 1, 1), 1.0, 0.8))
			_at(3.3, func(): _face(_hero, G(0.0, 0.0), 0.3))
		# ---------------------------------------------------------- ② 往上爬
		"c_climb":
			# 雪越來越少、露出青綠的山水；一群仙鶴從頭上飛過去，往山頂
			_shot_cam(G(6.5, 12.0) + Vector3(0, 2.6, 0), G(0.0, 6.0) + Vector3(0, 1.6, 0), 46.0, 0.0, Vector3(-0.1, 0.03, -0.25))
			_walk(_hero, G(0.0, 6.4), 4.6)
			for k in _cranes.size():
				var a := G(-4.0 + 1.6 * k, 20.0) + Vector3(0, 5.0 + 0.4 * (k % 3), 0)
				var b := Vector3(_gate.x - 3.0 + 1.2 * k, a.y + 4.0, _gate.z - 6.0)
				_crane_fly(k, a, b, 4.2, 0.4 + 0.25 * k)
			_at(1.6, func():
				_hero.look = Vector3(0, 8, -4)
				_set_anim(_hero, "lookup"))
		# ---------------------------------------------------------- ③ 對話
		"g_name":
			# 從背後看：霧裡的南天門
			_shot_cam(G(1.1, 10.2) + Vector3(0, 2.0, 0), G(0.0, -4.0) + Vector3(0, 1.4, 0), 44.0, 0.0, Vector3(0, 0, -0.1))
			_hero.look = _gate + Vector3(0, 2.0, 0)
		"g_birds":
			_shot_cam(G(0.9, 2.6) + Vector3(0, 1.55, 0), hero.global_position + Vector3(0, 1.15, 0), 34.0, 0.0, Vector3(0.02, 0, 0.02))
			_set_anim(_hero, "lookup")
		"g_nobody":
			# 神明的角度：從上面往下看
			_shot_cam(hero.global_position + Vector3(0.4, 6.4, 2.2), hero.global_position + Vector3(0, 0.4, 0), 38.0, 0.0, Vector3(0, -0.06, 0))
			_set_anim(_hero, "idle")
		# ---------------------------------------------------------- ④ 尋雞啟事
		"p_fly":
			# 一張懸賞單被風吹上雲階，落在家豪後面；阿土、阿水從山腳爬上來，阿土撿起來
			var land := G(0.7, 8.4) + Vector3(0, 0.02, 0)
			_shot_cam(G(-3.4, 4.4) + Vector3(0, 1.7, 0), G(0.4, 9.0) + Vector3(0, 0.9, 0), 42.0, 0.0, Vector3(0.03, 0, 0.03))
			_play("whoosh", -10.0, 0.6)
			_paper.visible = true
			_paper.global_position = G(-2.0, 16.0) + Vector3(0, 2.6, 0)
			var arc := func(k: float) -> void:
				var a := G(-2.0, 16.0) + Vector3(0, 2.6, 0)
				var q := a.lerp(land, k)
				q.y += sin(k * PI) * 1.6
				_paper.global_position = q
				_paper.rotation = Vector3(-PI * 0.5 * k + sin(k * 9.0) * 0.4, k * 4.0, sin(k * 7.0) * 0.5)
			_tw().tween_method(arc, 0.0, 1.0, 1.3)
			_face(_hero, G(0.0, 12.0), 0.5)
			_emote(_hero, "？", Color(1, 1, 1), 0.9, 0.9)
			if _workers.size() >= 2:
				_worker_walk(_workers[0], G(0.4, 14.0), G(0.9, 9.0), 1.6, 0.4)
				_worker_walk(_workers[1], G(-1.0, 14.6), G(-0.6, 9.4), 1.8, 0.6)
				var w0: Dictionary = _workers[0]
				_at(2.2, func():
					_worker_anim(w0, "pick-up")
					_play("pop", -14.0, 1.4))
				_at(2.7, func(): _paper.visible = false)
		"p_atu":
			# 阿土把懸賞單舉起來給家豪看
			_shot_cam(G(-2.4, 6.6) + Vector3(0, 1.6, 0), G(0.2, 8.8) + Vector3(0, 1.1, 0), 40.0)
			for w in _workers:
				(w.wrap as Node3D).visible = true
				(w.wrap as Node3D).rotation.y = atan2(hero.global_position.x - (w.wrap as Node3D).global_position.x, hero.global_position.z - (w.wrap as Node3D).global_position.z)
				_worker_anim(w, "idle")
			if not _workers.is_empty():
				(_workers[0].wrap as Node3D).global_position = G(0.9, 9.0)
				(_workers[1].wrap as Node3D).global_position = G(-0.6, 9.4)
				_worker_anim(_workers[0], "holding-right")
			_poster_p = _poster("飼料一卡車")
		"p_ashui":
			_hide_paper(_poster_p, true)
			_poster_p = null
			for w in _workers:
				(w.wrap as Node3D).visible = true
			_at(0.6, func():
				_set_anim(_hero, "cool")
				_emote(_hero, "…", Color(1, 1, 1), 1.0, 0.8))
		# ---------------------------------------------------------- ⑤ 標題卡
		"card":
			_shot_cam(G(-10.0, 24.0) + Vector3(0, 9.0, 0), _gate + Vector3(0, 1.0, 0), 46.0, 0.0, Vector3(0.2, -0.04, -0.2))
			_at(0.45, func(): _title_card(5, "丹穴山海", "鳳凰住的地方"))
