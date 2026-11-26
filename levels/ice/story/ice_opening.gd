extends "res://levels/ice/story/story_kit.gd"
## 冰羽踏雪的開場動畫（第 1 天）。分鏡在 levels/ice/docs/大關開場與結尾動畫.md 第 4 節。
## 第一次進冰雪島第 1 關之前播（見 ice_story.gd），播完進第 1 關。
## 場地借第 1 關「漁村・早晨」（拿掉戰局和玩家）。
##
## 五拍：靠岸 → 號碼（籠子裡的企鵝翅膀上扣著號碼）→ 對話（最後天上掉下一片香蕉皮）→ 尋雞啟事 → 標題卡

const STAGE := "res://levels/ice/stage_9/stage.tscn"
const SEA_Y := -3.0                  # 海面（ice_world.gd 的 SEA_Y）
const BOAT_FROM_X := 4.6

func _lines() -> Array:
	return [
		{"shot": "sea", "hold": 5.0, "cue": "o_sea", "fade_in": 1.4},
		{"shot": "shore", "hold": 3.2, "cue": "o_land"},
		{"shot": "cage", "hold": 3.6, "cue": "o_cage"},
		{"shot": "talk", "who": "神明", "text": "冰雪島。老闆在這裡開了企鵝樂園。", "cue": "t_open"},
		{"shot": "talk", "who": "家豪", "text": "……樂園有籠子喔。", "cue": "t_cage"},
		{"shot": "talk", "who": "神明", "text": "遊客說牠們過得比較好。有魚吃，有人拍。", "cue": "t_photo"},
		{"shot": "talk", "who": "家豪", "text": "……嘉欣也是去更好的地方。", "cue": "t_tag", "snap": 1.8},
		{"shot": "talk", "who": "神明", "text": "……記住：在冰上，人會滑，你不會。", "cue": "t_rule"},
		{"shot": "talk", "hold": 2.4, "cue": "t_peel"},
		{"shot": "talk", "hold": 1.4, "cue": "p_in"},
		{"shot": "talk", "who": "家豪", "text": "……才一包。", "cue": "p_read", "snap": 1.0},
		{"shot": "talk", "hold": 1.8, "cue": "p_out"},
		{"shot": "card", "hold": 4.0, "cue": "card", "fade_out": 0.5, "fade_in": 0.9},
	]

func _skip_text() -> String:
	return "跳過開場"

func _next_scene() -> String:
	return _stage_after(STAGE)

var _world
var _h := 0.0                        # 雪地的高度
var _edge := 15.0                    # 南岸崖頂的 z（家豪上岸的地方）
var _cage := Vector3(0, 0, -11.6)
var _boat: Node3D
var _sign: Node3D
var _leader: Node3D                  # 企鵝老大（翅膀上扣著 01）
var _poster_p: Control
var _card_p: Control
var _boat_go := false

func _story_build() -> void:
	mark_seen("ice_opening")         # 先記下來：底下借第 1 關的場地時，那一關就不會又轉回開場
	var stage := _borrow_stage(STAGE)
	_world = stage.get_node("World")
	if _world.get("cage") is Vector3:
		_cage = _world.get("cage")
	_h = float(_world.height_at(0.0, 9.0))
	# 找南岸的崖邊：從家豪出發的地方往南走，地面一往下掉就是了
	for i in 160:
		var z := 9.0 + i * 0.12
		if float(_world.height_at(0.0, z)) < _h - 0.8:
			_edge = z - 0.4
			break
	_make_hero(self)
	_boat = _make_boat()
	# 船邊幾塊浮冰
	for f in [[Vector3(3.4, SEA_Y, _edge + 6.5), "a", 0.9], [Vector3(-2.2, SEA_Y, _edge + 4.5), "b", 0.8], [Vector3(6.5, SEA_Y, _edge + 11.0), "c", 1.1], [Vector3(-4.6, SEA_Y, _edge + 10.0), "a", 1.2]]:
		var fl := _glb(self, MB + "ice_floe_%s.glb" % f[1], f[0], float(f[0].x), f[2])
		if fl:
			_no_shadow(fl)
	_build_sign()
	# 籠子裡的企鵝：胸前都掛著號碼牌
	var pens = _world.get("_penguins")
	if pens is Array:
		var nums := ["21", "01", "22"]
		for k in (pens as Array).size():
			var pn := (pens[k] as Dictionary).node as Node3D
			_tag_penguin(pn, nums[k % 3])
			if k == 1:
				_leader = pn

## 岸邊的招牌：「企鵝樂園　歡迎光臨」，上面站一隻企鵝吉祥物
func _build_sign() -> void:
	_sign = Node3D.new()
	add_child(_sign)
	_sign.position = Vector3(-2.7, _h, _edge - 1.8)
	_sign.rotation.y = 0.3
	var wood := _toon(Color(0.55, 0.38, 0.24))
	for x in [-1.25, 1.25]:
		_box(_sign, Vector3(0.14, 2.1, 0.14), Vector3(x, 1.05, 0), wood)
	_box(_sign, Vector3(3.0, 1.15, 0.12), Vector3(0, 1.75, 0), _toon(Color(0.36, 0.70, 0.92)))
	_box(_sign, Vector3(3.12, 0.12, 0.16), Vector3(0, 2.36, 0), _toon(Color(1.0, 0.86, 0.30)))
	_box(_sign, Vector3(3.12, 0.12, 0.16), Vector3(0, 1.14, 0), _toon(Color(1.0, 0.86, 0.30)))
	for t in [["企鵝樂園", 120, 1.92, Color(1, 1, 1)], ["歡迎光臨", 64, 1.46, Color(1.0, 0.95, 0.6)]]:
		var l := Label3D.new()
		l.text = t[0]
		if UIStyle.font():
			l.font = UIStyle.font()
		l.font_size = t[1]
		l.pixel_size = 0.0055
		l.modulate = t[3]
		l.outline_size = 18
		l.outline_modulate = Color(0.10, 0.22, 0.42)
		l.position = Vector3(0, t[2], 0.07)
		l.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_sign.add_child(l)
	if _world.has_method("make_penguin"):
		var p: Node3D = _world.make_penguin(_sign, Vector3.ZERO, 0.0)
		p.position = Vector3(1.05, 2.42, 0)
		p.scale = Vector3.ONE * 0.75
		if _world.has_method("penguin_anim"):
			_world.penguin_anim(p, "dance")

## 船從外海往岸邊划：起點、終點
func _boat_a() -> Vector3:
	return Vector3(BOAT_FROM_X, SEA_Y, _edge + 13.0)

func _boat_b() -> Vector3:
	return Vector3(0.7, SEA_Y, _edge + 2.6)

## 家豪坐在船上（跟著船一起晃）
func _hero_in_boat() -> void:
	if _boat:
		(_hero.node as Node3D).global_position = _boat.to_global(Vector3(0, 0.24, -0.3))

func _story_tick(_dt: float) -> void:
	if _boat_go:
		var k := clampf(_shot_t / 4.6, 0.0, 1.0)
		var e := 1.0 - pow(1.0 - k, 2.2)
		_boat_at(_boat, _boat_a().lerp(_boat_b(), e), _boat_b() - _boat_a())
		_hero_in_boat()
	elif _shot == "shore":
		_boat_at(_boat, _boat_b(), _boat_b() - _boat_a())

# ================================================================== 鏡頭

func _enter_shot(s: String) -> void:
	var hero := _hero.node as Node3D
	hero.visible = true
	hero.rotation = Vector3.ZERO
	_hero.look = null
	_set_anim(_hero, "idle")
	_boat_go = false
	if _boat:
		_boat.visible = s in ["sea", "shore"]
	match s:
		"sea":
			_boat_go = true
			_boat_at(_boat, _boat_a(), _boat_b() - _boat_a())
			_hero_in_boat()
			_face(_hero, Vector3(0, 0, -20))
			_hero.look = _sign.global_position + Vector3(0, 1.8, 0)
		"shore":
			_boat_at(_boat, _boat_b(), _boat_b() - _boat_a())
			_hero_in_boat()
		"cage":
			hero.visible = false
		"talk":
			hero.position = Vector3(0, _h, 9.6)
			hero.rotation.y = PI
		"card":
			hero.visible = false

func _on_line(l: Dictionary) -> void:
	var hero := _hero.node as Node3D
	match String(l.get("cue", "")):
		# ---------------------------------------------------------- ① 靠岸
		"o_sea":
			# 低低的貼著海面：小木船擠開浮冰，往崖上的招牌划過去
			_shot_cam(Vector3(8.5, SEA_Y + 1.7, _edge + 17.0), Vector3(-0.8, _h - 0.2, _edge - 1.0), 42.0, 0.0, Vector3(-0.25, 0.02, -0.35))
			_music_play("theme", -17.0, 2.5)
			_amb_play("waves", -15.0, 1.5)
		"o_land":
			# 從海這邊看崖頂：家豪從船上一跳跳上岸，招牌在旁邊
			_shot_cam(Vector3(2.4, _h + 2.1, _edge + 5.0), Vector3(-1.0, _h + 0.9, _edge - 2.0), 44.0, 0.0, Vector3(-0.08, 0.0, -0.12))
			_face(_hero, Vector3(0, _h, _edge - 3.0))
			_at(0.5, func():
				_hop(_hero, Vector3(0.0, _h, _edge - 1.7), 0.7, 1.6, 0.0, "idle")
				_play("whoosh", -14.0, 1.3))
			_at(1.25, func(): _play("thud", -14.0, 1.2))
			_at(1.6, func():
				_face(_hero, _sign.global_position + Vector3(0, 0, 2.0), 0.4)
				_hero.look = _sign.global_position + Vector3(0, 1.8, 0))
			_at(2.3, func(): _emote(_hero, "…", Color(1, 1, 1), 1.0, 0.8))
		# ---------------------------------------------------------- ② 號碼
		"o_cage":
			# 推近籠子：企鵝翅膀上扣著號碼，中間那隻（01）轉過來盯著鏡頭
			var c := _cage + Vector3(0, _h, 0)
			_shot_cam(c + Vector3(1.7, 2.5, 9.4), c + Vector3(0, 0.9, 0.3), 32.0, 0.0, Vector3(-0.1, -0.03, -0.3))
			_at(1.4, func():
				if _leader:
					_emote(_leader.global_position + Vector3(0, 1.1, 0), "…", Color(1, 1, 1), 1.1, 0.7))
		# ---------------------------------------------------------- ③ 對話
		"t_open":
			# 從家豪背後看過去：冰湖對面就是籠子
			_shot_cam(Vector3(0.9, _h + 2.4, 13.8), Vector3(0, _h + 0.2, -6.0), 44.0, 0.0, Vector3(0, -0.01, -0.12))
			_hero.look = _cage + Vector3(0, 1.0, 0)
		"t_cage":
			_shot_cam(Vector3(1.0, _h + 1.55, 6.6), Vector3(0, _h + 1.15, 9.6), 34.0, 0.0, Vector3(0.02, 0, 0.03))
			_hero.look = _cage + Vector3(0, 1.0, 0)
		"t_photo":
			# 籠子那邊一直有人在拍照
			var c := _cage + Vector3(0, _h, 0)
			_shot_cam(c + Vector3(1.8, 1.5, 6.4), c + Vector3(0, 0.8, 0), 30.0, 0.0, Vector3(0.06, 0, -0.05))
			for k in 3:
				_at(0.5 + 0.7 * k, func():
					_emote(c + Vector3(-1.6 + 1.6 * k, 1.9 + 0.3 * (k % 2), 1.6), "喀嚓", Color(1, 1, 1), 0.7, 0.55, 0.2)
					_flash(Color(1, 1, 1), 0.28, 0.18)
					_play("pop", -16.0, 2.0))
		"t_tag":
			# 低頭看脖子上的牌子
			_shot_cam(Vector3(-0.8, _h + 1.25, 7.5), Vector3(0, _h + 0.95, 9.6), 30.0, 0.0, Vector3(0.02, 0, 0.02))
			_set_anim(_hero, "sad")
		"t_rule":
			# 神明的角度：從上面往下看
			_shot_cam(Vector3(0.4, _h + 6.4, 7.4), Vector3(0, _h + 0.4, 9.6), 38.0, 0.0, Vector3(0, -0.06, 0))
			_set_anim(_hero, "lookup")
		"t_peel":
			# 天上掉下來一片香蕉皮（跟開場醒來時隔壁空位上那一片一樣）
			_shot_cam(Vector3(1.7, _h + 1.5, 6.6), Vector3(0, _h + 0.5, 9.0), 40.0)
			_set_anim(_hero, "lookup")
			_drop_peel(Vector3(0.0, _h + 0.02, 8.7), 0.1)
			_at(1.5, func():
				_set_anim(_hero, "idle")
				_hero.look = Vector3(0, _h, 8.7)
				_emote(_hero, "？", Color(1, 1, 1), 0.9, 0.9)
				_play("pop", -12.0))
		# ---------------------------------------------------------- ④ 尋雞啟事
		"p_in":
			_shot_cam(Vector3(1.0, _h + 1.5, 6.8), Vector3(0, _h + 1.15, 9.6), 36.0)
			_hero.look = null
			_play("whoosh", -10.0, 0.7)
			_at(0.45, func():
				_poster_p = _poster("飼料一包")
				_set_anim(_hero, "shock"))
		"p_read":
			_set_anim(_hero, "idle")
		"p_out":
			_hide_paper(_poster_p, true)
			_poster_p = null
			_at(0.45, func():
				_set_anim(_hero, "cool")
				_emote(_hero, "…", Color(1, 1, 1), 1.0, 0.8))
		# ---------------------------------------------------------- ⑤ 標題卡
		"card":
			_shot_cam(Vector3(-17.0, _h + 15.0, 31.0), Vector3(0, _h - 1.0, -4.0), 46.0, 0.0, Vector3(0.25, -0.05, -0.2))
			_at(0.45, func(): _card_p = _title_card(1, "冰羽踏雪", "企鵝樂園"))
