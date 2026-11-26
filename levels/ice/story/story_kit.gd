extends "res://scripts/ui/cutscene.gd"
## 大關開場和結尾動畫共用的零件。設計在 levels/ice/docs/大關開場與結尾動畫.md 第 3 節。
## 冰雪島先用；之後其他大關的開場、結尾也可以 extends 這個檔案。
##
## 這裡管：
##   什麼時候播：只播一次；測試、截圖、無頭模式不自動播，也不寫存檔。
##   家豪：腳上六十七號、脖子上六十六號；帽沿可以被風掀起來，看得到帽子底下的羽毛尖。
##   灰色音符：沒有聲音的打碟，同伴接住一顆音符。
##   天上掉下來的香蕉皮。
##   畫面上的紙：標題卡、尋雞啟事、手帳頁。
##   聲音：海浪、風、翻頁、啪、撲通，和一段音樂盒配樂。
##
## 子類別寫 _story_build()（蓋場景）和 _story_tick(dt)（每一畫面），其他照 cutscene.gd 的寫法。

const Progress := preload("res://scripts/progress.gd")
const SETTINGS := "user://settings.cfg"
const PORTRAIT := "res://assets/ui/jiahao_portrait.png"
const MB := "res://levels/ice/assets/blender/"
const ROWBOAT := MB + "rowboat.glb"
const BEAT := 0.6                    # 配樂一拍幾秒（100 BPM）；打碟也跟著這個拍子
const GREY := Color(0.80, 0.80, 0.86)

## 這次執行已經播過（或正在播）的：記在 Engine 上，換場景、腳本被卸掉也還在
## （不然加 -- --story 的時候，結尾播完回地圖，地圖又會再叫一次結尾）
const SEEN_META := "story_seen_now"

static func _seen_now() -> Dictionary:
	if not Engine.has_meta(SEEN_META):
		Engine.set_meta(SEEN_META, {})
	return Engine.get_meta(SEEN_META)

# ================================================================== 什麼時候播

## 這次執行是測試、截圖或無頭模式：不自動播，也不寫存檔。
## --story 是開發用的：不管看過沒有都會播，也不寫存檔。
static func quiet() -> bool:
	if DisplayServer.get_name() == "headless":
		return true
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and not a in ["--no-dev", "--fresh", "--story"]:
			return true
	return false

static func seen(key: String) -> bool:
	if _seen_now().has(key):
		return true
	if "--story" in OS.get_cmdline_user_args():
		return false
	var cf := ConfigFile.new()
	return cf.load(SETTINGS) == OK and bool(cf.get_value("story", key, false))

## 記下「播過了」：一開始播就記（按 Esc 跳過也算看過）
static func mark_seen(key: String) -> void:
	_seen_now()[key] = true
	if quiet() or "--story" in OS.get_cmdline_user_args():
		return
	var cf := ConfigFile.new()
	cf.load(SETTINGS)               # 檔案還不存在也沒關係
	cf.set_value("story", key, true)
	cf.save(SETTINGS)

## 該不該播：還沒看過、不是測試。already 裡任何一小關已經過了（開場做出來之前的舊存檔），也當作看過
static func pending(key: String, already: Array = []) -> bool:
	if quiet() or seen(key):
		return false
	for id in already:
		if Progress.is_cleared(String(id)):
			return false
	return true

# ================================================================== 場景

var _hero: Dictionary = {}
var _tag66: Node3D
var _hood: Array = []                # 帽兜的零件 {node, pos, rot}
var _tips: Node3D                    # 帽子底下的羽毛尖（平常藏著）
var _amb: AudioStreamPlayer          # 環境音（海浪、風）：跟配樂分開，靜音拍的時候還留著
var _papers: Control                 # 畫面上的紙（標題卡、懸賞單、手帳頁）：在對話框底下
var _notes_on := false
var _notes_t := 0.0
var _flying: Array = []              # 飛向同伴的音符 {node, from, to, t, dur, done}

func _build() -> void:
	_papers = Control.new()
	_papers.set_anchors_preset(Control.PRESET_FULL_RECT)
	_papers.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_papers)
	_layer.move_child(_papers, _dlg.get_index())
	_amb = AudioStreamPlayer.new()
	add_child(_amb)
	_make_kit_sounds()
	_story_build()

func _story_build() -> void:
	pass

func _tick(dt: float) -> void:
	_tick_notes(dt)
	_story_tick(dt)

func _story_tick(_dt: float) -> void:
	pass

func _voice_pitch(who: String) -> float:
	match who:
		"企鵝老大": return 1.9
		"阿土": return 0.95
	return super(who)

func _actor_of(who: String) -> Dictionary:
	return _hero if who == "家豪" else {}

## 開場播完要去哪一關：選關地圖已經排好要進這一關（Engine 的 next_scene）就走載入畫面，不然直接進
func _stage_after(stage_path: String) -> String:
	if String(Engine.get_meta("next_scene", "")) == stage_path:
		return "res://scenes/loading.tscn"
	return stage_path

## 把一個關卡場景搬過來當佈景：拿掉戰局、玩家和介面，用它的天空和太陽
func _borrow_stage(path: String) -> Node3D:
	var stage := (load(path) as PackedScene).instantiate() as Node3D
	for nm in ["Battle", "Player", "HUD"]:
		var n := stage.get_node_or_null(nm)
		if n:
			stage.remove_child(n)
			n.free()
	add_child(stage)
	_env_node = stage.get_node("WorldEnvironment") as WorldEnvironment
	_sun = stage.get_node("Sun") as DirectionalLight3D
	return stage

## 模型等比例縮放到最長的一邊是 length 公尺
func _fit(n: Node3D, length: float) -> void:
	var box := AABB()
	var first := true
	for c in n.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		var b := (n.global_transform.affine_inverse() * mi.global_transform) * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	var big := maxf(box.size.x, maxf(box.size.y, box.size.z))
	if big > 0.001:
		n.scale *= length / big

## 小木船（地圖上開船用的同一艘）：外面包一層，船頭一律朝外面那層的 +Z；要往哪走就轉外面那層
func _make_boat(length := 2.9) -> Node3D:
	var holder := Node3D.new()
	add_child(holder)
	var m := _glb(holder, ROWBOAT, Vector3.ZERO, 0.0, 1.0)
	if m:
		_fit(m, length)
		_no_shadow(m)
		var box := AABB()
		var first := true
		for c in m.find_children("*", "MeshInstance3D", true, false):
			var mi := c as MeshInstance3D
			var b := (holder.global_transform.affine_inverse() * mi.global_transform) * mi.get_aabb()
			box = b if first else box.merge(b)
			first = false
		if box.size.x > box.size.z:
			m.rotation.y = PI * 0.5        # 長邊轉到前後（跟選關地圖的做法一樣）
	return holder

## 船放到 p、船頭朝 dir，跟著浪上下晃
func _boat_at(boat: Node3D, p: Vector3, dir := Vector3(0, 0, 1)) -> void:
	if boat == null:
		return
	boat.global_position = p + Vector3(0, sin(_t * 1.8) * 0.06, 0)
	boat.rotation = Vector3(0, atan2(dir.x, dir.z), sin(_t * 1.3) * 0.04)

## 企鵝胸前掛一塊號碼牌（跟雞腳上的、家豪脖子上那塊同一種黃色塑膠牌）：照模型的大小貼在肚子正前方
func _tag_penguin(p: Node3D, num: String) -> Node3D:
	var box := AABB()
	var first := true
	for c in p.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		var b := (p.global_transform.affine_inverse() * mi.global_transform) * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	var tag := _foot_tag(num)
	p.add_child(tag)
	if first:
		tag.position = Vector3(0, 0.5, 0.4)
		tag.scale = Vector3.ONE * 0.4
	else:
		var s := box.size.x * 0.34 / 0.2
		tag.scale = Vector3.ONE * s
		tag.position = Vector3(box.get_center().x, box.position.y + box.size.y * 0.42, box.end.z + 0.012 * s)
	tag.rotation = Vector3(-0.12, 0, 0.1)
	return tag

# ================================================================== 家豪

## 家豪：腳上六十七號、脖子上六十六號（扯斷的那塊）。feathers 是帽子底下的羽毛尖（一章多一根）
func _make_hero(parent: Node3D, feathers: Array = []) -> Dictionary:
	_hero = _actor(parent, "hero", Vector3.ZERO, 0.0)
	_hero.beat = PI / BEAT
	_leg_tag(_hero, "67")
	var upper := (_hero.node as Node3D).find_child("Upper", true, false) as Node3D
	_tag66 = _foot_tag("66", true)
	if upper:
		upper.add_child(_tag66)
		_tag66.position = Vector3(0.115, 0.47, 0.335)
		_tag66.rotation = Vector3(0.12, 0.0, -0.18)
		_tag66.scale = Vector3.ONE * 0.5
	# 帽兜：頭上那顆黑色的球和帽沿那一圈
	var head := _hero.head as Node3D
	if head:
		for c in head.get_children():
			var mi := c as MeshInstance3D
			if mi == null or mi.mesh == null:
				continue
			var hood: bool = mi.mesh is SphereMesh and absf((mi.mesh as SphereMesh).radius - 0.16) < 0.004
			var rim: bool = mi.mesh is TorusMesh and absf((mi.mesh as TorusMesh).inner_radius - 0.105) < 0.004
			if hood or rim:
				_hood.append({"node": mi, "pos": mi.position, "rot": mi.rotation, "rim": rim})
	# 帽子底下的羽毛尖：從後腦勺往後翹出來，平常收著
	if upper and not feathers.is_empty():
		_tips = Node3D.new()
		_tips.position = Vector3(0, 0.74, -0.20)
		upper.add_child(_tips)
		for k in feathers.size():
			var f := _feather(0.5 if k == feathers.size() - 1 else 0.44, 0.14, feathers[k])
			f.rotation = Vector3(0.35, 0, (float(k) - (feathers.size() - 1) * 0.5) * 0.42)
			_tips.add_child(f)
		_tips.visible = false
	return _hero

## 一陣風把帽沿掀起來：看得到帽子底下的羽毛尖
func _hood_lift(dur := 0.35) -> void:
	for h in _hood:
		var n := h.node as Node3D
		var tw := _tw()
		tw.set_parallel(true)
		tw.tween_property(n, "position", (h.pos as Vector3) + Vector3(0, 0.09, 0.05), dur).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(n, "rotation:x", float((h.rot as Vector3).x) - (0.7 if h.rim else 0.3), dur)
	if _tips:
		_tips.visible = true
		_tips.scale = Vector3.ONE * 0.2
		_tw().tween_property(_tips, "scale", Vector3.ONE, dur * 1.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## 帽子拉回去：羽毛又藏起來
func _hood_down(dur := 0.25) -> void:
	for h in _hood:
		var n := h.node as Node3D
		var tw := _tw()
		tw.set_parallel(true)
		tw.tween_property(n, "position", h.pos, dur)
		tw.tween_property(n, "rotation", h.rot, dur)
	if _tips and _tips.visible:
		var tw2 := _tw()
		tw2.tween_property(_tips, "scale", Vector3.ONE * 0.1, dur)
		tw2.tween_callback(func(): _tips.visible = false)

## 帽子馬上回到原位（換鏡頭的時候）
func _hood_reset() -> void:
	for h in _hood:
		(h.node as Node3D).position = h.pos
		(h.node as Node3D).rotation = h.rot
	if _tips:
		_tips.visible = false

## 一根羽毛：往後、往上翹，尾端有一顆眼斑（跟結局長出來的尾羽同一個樣子，短一點）
func _feather(length: float, width: float, col: Color) -> Node3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 10
	var pl := Vector3.ZERO
	var pr := Vector3.ZERO
	var pc := col
	var eye := Vector3.ZERO
	for i in n + 1:
		var k := float(i) / n
		var c := Vector3(0, length * (0.8 * k - 0.6 * k * k), -length * 0.95 * k)
		var w := width * pow(sin(PI * minf(0.06 + k * 0.94, 1.0)), 0.7) * 0.5
		var cc := col.darkened(0.4).lerp(col, minf(k * 2.5, 1.0)).lerp(Color(1.0, 0.95, 0.7), maxf(k - 0.78, 0.0) * 2.4)
		var l := c + Vector3(-w, 0, 0)
		var r := c + Vector3(w, 0, 0)
		if i > 0:
			for v in [[pl, pc], [pr, pc], [r, cc], [pl, pc], [r, cc], [l, cc]]:
				st.set_color(v[1])
				st.add_vertex(v[0])
		if i == 8:
			eye = c
		pl = l
		pr = r
		pc = cc
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var holder := Node3D.new()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(mi)
	_no_shadow(_ball(holder, width * 0.2, eye, _glow(Color(1.8, 1.5, 0.5)), Vector3(1.0, 0.25, 1.3), 8))
	return holder

# ================================================================== 音符

## 沒有聲音的打碟：灰色音符從家豪頭上一顆一顆往下掉（跟開場屋頂那一幕一樣）
func _notes(on: bool) -> void:
	_notes_on = on
	_notes_t = 0.0

## 一顆灰色音符飄到某個位置（同伴伸手、張嘴接住）。到了之後叫 then
func _note_to(to: Vector3, dur := 1.3, then := Callable()) -> void:
	var from := (_hero.node as Node3D).global_position + Vector3(0.4, 1.6, 0)
	var l := _label3d("♪", 48, GREY)
	add_child(l)
	l.global_position = from
	_flying.append({"node": l, "from": from, "to": to, "t": 0.0, "dur": dur, "then": then})

func _tick_notes(dt: float) -> void:
	if _notes_on and not _busy and not _hero.is_empty():
		_notes_t -= dt
		if _notes_t <= 0.0:
			_notes_t = BEAT
			var hp := (_hero.node as Node3D).global_position
			var side := 1.0 if int(_t / BEAT) % 2 == 0 else -1.0
			_emote(hp + Vector3(0.9 * side, 1.5, 0.2), "♪" if side > 0.0 else "♫", GREY, 1.2, 0.62, -1.1)
	for i in range(_flying.size() - 1, -1, -1):
		var f: Dictionary = _flying[i]
		var l := f.node as Label3D
		if not is_instance_valid(l):
			_flying.remove_at(i)
			continue
		f.t = float(f.t) + dt
		var k := minf(float(f.t) / float(f.dur), 1.0)
		var p: Vector3 = (f.from as Vector3).lerp(f.to, k)
		p.y += sin(k * PI) * 0.9
		l.global_position = p
		l.scale = Vector3.ONE * (1.0 - 0.5 * k)
		if k >= 1.0:
			l.queue_free()
			_flying.remove_at(i)
			var c: Callable = f.then
			if c.is_valid():
				c.call()

# ================================================================== 天上掉下來的香蕉皮

func _drop_peel(at: Vector3, delay := 0.0) -> Node3D:
	var p := _peel(self, at + Vector3(0, 9.0, 0), 0.9)
	if p == null:
		return null
	p.visible = false
	var tw := _tw()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_callback(func(): p.visible = true)
	tw.set_parallel(true)
	tw.tween_property(p, "global_position", at, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_property(p, "rotation:y", p.rotation.y + 7.0, 1.2)
	tw.set_parallel(false)
	tw.tween_callback(func(): _play("slip", -10.0))
	return p

# ================================================================== 畫面上的紙

## 標題卡（手帳紙）：「第 N 天」「大關名」「更好的地方：○○？」
func _title_card(day: int, title: String, place: String) -> Control:
	var p := PanelContainer.new()
	UIStyle.paper(p, -0.02)
	var s := UIStyle._box(UIStyle.PAPER, UIStyle.PAPER_EDGE, 6, 3)
	s.content_margin_left = 70
	s.content_margin_right = 70
	s.content_margin_top = 34
	s.content_margin_bottom = 38
	p.add_theme_stylebox_override("panel", s)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	v.add_child(_paper_label("第 %d 天" % day, 30, UIStyle.accent()))
	v.add_child(_paper_label(title, 84, UIStyle.INK))
	var line := ColorRect.new()
	line.color = Color(UIStyle.INK, 0.25)
	line.custom_minimum_size = Vector2(0, 3)
	v.add_child(line)
	v.add_child(_paper_label("更好的地方：%s？" % place, 34, UIStyle.INK))
	_show_paper(p, -0.02)
	_play("page", -6.0)
	return p

## 尋雞啟事：一張舊舊的黃紙「啪」地貼到鏡頭上
func _poster(reward: String) -> Control:
	var p := PanelContainer.new()
	var s := UIStyle._box(Color("f1e2b8"), Color("b08f55"), 4, 3)
	s.content_margin_left = 44
	s.content_margin_right = 44
	s.content_margin_top = 26
	s.content_margin_bottom = 26
	p.add_theme_stylebox_override("panel", s)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	v.add_child(_paper_label("尋雞啟事", 62, UIStyle.RIBBON))
	var pic := TextureRect.new()
	pic.texture = load(PORTRAIT)
	pic.custom_minimum_size = Vector2(200, 200)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	v.add_child(pic)
	v.add_child(_paper_label("六十七號", 36, UIStyle.INK))
	v.add_child(_paper_label("白公雞　黑帽子　黑口罩", 24, UIStyle.INK))
	v.add_child(_paper_label("懸賞：%s" % reward, 42, UIStyle.RIBBON))
	v.add_child(_paper_label("（有看到請通知農場）", 18, Color(UIStyle.INK, 0.6)))
	_show_paper(p, 0.06, 1.9)
	_play("slap", -4.0)
	_shake = 0.35
	return p

## 手帳頁：寫下這一章「更好的地方」的答案，貼上這一章的羽毛
func _journal_page(day: int, line: String, col: Color, next_stop: String) -> Control:
	var p := PanelContainer.new()
	UIStyle.paper(p, 0.015)
	var s := UIStyle._box(UIStyle.PAPER, UIStyle.PAPER_EDGE, 6, 3)
	s.content_margin_left = 60
	s.content_margin_right = 60
	s.content_margin_top = 30
	s.content_margin_bottom = 30
	p.add_theme_stylebox_override("panel", s)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	p.add_child(v)
	v.add_child(_paper_label("第 %d 天" % day, 28, UIStyle.accent(), false))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 26)
	v.add_child(row)
	var txt := _paper_label(line, 44, UIStyle.INK, false)
	txt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	txt.custom_minimum_size = Vector2(680, 0)
	txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	txt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(txt)
	# 羽毛貼紙：先空著，晚一點才「貼」上去
	var sticker := Control.new()
	sticker.custom_minimum_size = Vector2(96, 132)
	sticker.draw.connect(func(): _draw_feather(sticker, col))
	sticker.modulate.a = 0.0
	row.add_child(sticker)
	var line2 := ColorRect.new()
	line2.color = Color(UIStyle.INK, 0.2)
	line2.custom_minimum_size = Vector2(0, 2)
	v.add_child(line2)
	if next_stop != "":
		var nx := _paper_label("下一站：%s　→" % next_stop, 26, UIStyle.accent(), false)
		nx.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		v.add_child(nx)
	_show_paper(p, 0.015)
	_play("page", -6.0)
	# 字一個一個寫出來，寫完貼羽毛
	txt.visible_ratio = 0.0
	var tw := _tw()
	tw.tween_interval(0.35)
	tw.tween_property(txt, "visible_ratio", 1.0, 0.06 * line.length())
	tw.tween_callback(func():
		sticker.modulate.a = 1.0
		sticker.pivot_offset = sticker.size * 0.5
		sticker.scale = Vector2.ONE * 1.6
		_play("slap", -12.0, 1.4))
	tw.tween_property(sticker, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return p

func _paper_label(text: String, size: int, color: Color, center := true) -> Label:
	var l := Label.new()
	l.text = text
	l.label_settings = UIStyle.ls(size, color)
	if center:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l

## 紙放到畫面正中間：從 from 倍大、斜斜的彈到定位
func _show_paper(p: Control, tilt: float, from := 1.25) -> void:
	_papers.add_child(p)
	p.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.grow_vertical = Control.GROW_DIRECTION_BOTH
	p.modulate.a = 0.0
	p.scale = Vector2.ONE * from
	p.rotation = tilt + 0.25 * (from - 1.0)
	p.pivot_offset = p.get_combined_minimum_size() * 0.5
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(p, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(p, "rotation", tilt, 0.24)
	tw.tween_property(p, "modulate:a", 1.0, 0.12)

## 紙拿掉：往下掉出畫面（drop）或淡掉
func _hide_paper(p: Control, drop := false) -> void:
	if p == null or not is_instance_valid(p):
		return
	var tw := create_tween()
	tw.set_parallel(true)
	if drop:
		tw.tween_property(p, "position:y", p.position.y + 900.0, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(p, "rotation", p.rotation + 0.35, 0.55)
	else:
		tw.tween_property(p, "modulate:a", 0.0, 0.35)
	tw.set_parallel(false)
	tw.tween_callback(p.queue_free)

## 羽毛貼紙：一根斜斜的羽毛，外面一圈白邊（像貼紙）
func _draw_feather(c: Control, col: Color) -> void:
	var sz := c.size
	var ctr := sz * 0.5
	var ang := 0.42
	var length := sz.y * 0.86
	var width := sz.x * 0.36
	var left: PackedVector2Array = []
	var right: PackedVector2Array = []
	for i in 21:
		var k := float(i) / 20.0
		var w := width * pow(sin(PI * minf(0.04 + k * 0.96, 1.0)), 0.75) * 0.5
		var y := length * (0.5 - k)
		left.append(Vector2(-w, y).rotated(ang) + ctr)
		right.append(Vector2(w, y).rotated(ang) + ctr)
	right.reverse()
	var pts := left + right
	# 白邊（貼紙）
	var grow: PackedVector2Array = []
	for q in pts:
		grow.append(ctr + (q - ctr) * 1.13)
	c.draw_colored_polygon(grow, Color(1, 1, 1, 0.95))
	c.draw_colored_polygon(pts, col)
	var spine_a := Vector2(0, length * 0.62).rotated(ang) + ctr
	var spine_b := Vector2(0, -length * 0.45).rotated(ang) + ctr
	c.draw_line(spine_a, spine_b, col.darkened(0.45), 3.0, true)
	c.draw_circle(Vector2(0, -length * 0.3).rotated(ang) + ctr, width * 0.13, Color(1.0, 0.93, 0.6))

# ================================================================== 聲音

func _amb_play(snd_name: String, db := -14.0, fade := 0.6) -> void:
	if not _snd.has(snd_name):
		return
	_amb.stream = _snd[snd_name]
	_amb.volume_db = -50.0
	_amb.play()
	create_tween().tween_property(_amb, "volume_db", db, fade)

func _make_kit_sounds() -> void:
	# 海浪：低低的沙沙聲一波一波（循環）
	var b := s_buf(4.0)
	for k in 4:
		s_noise(b, k * 1.0 + 0.1, 1.8, 0.42, 0.04, 40 + k, 1.1, true)
	_snd["waves"] = s_wav(b, true)
	# 風：比較亮的沙沙聲（循環）
	b = s_buf(3.0)
	for k in 3:
		s_noise(b, k * 1.0, 1.6, 0.3, 0.09, 60 + k, 0.9, true)
	_snd["wind"] = s_wav(b, true)
	# 翻頁
	b = s_buf(0.3)
	s_noise(b, 0.0, 0.26, 0.55, 0.5, 7, 13.0)
	s_glide(b, 0.02, 1400.0, 700.0, 0.2, 0.05)
	_snd["page"] = s_wav(b)
	# 啪（紙貼上來）
	b = s_buf(0.3)
	s_noise(b, 0.0, 0.1, 0.9, 0.8, 3, 38.0)
	s_kick(b, 0.0, 0.45)
	_snd["slap"] = s_wav(b)
	# 撲通（東西掉進冰洞）
	b = s_buf(0.5)
	s_glide(b, 0.0, 700.0, 200.0, 0.16, 0.45)
	s_noise(b, 0.03, 0.4, 0.45, 0.35, 9, 9.0)
	_snd["plop"] = s_wav(b)
	# 香蕉皮落地（軟軟的「啪嘰」）
	b = s_buf(0.25)
	s_noise(b, 0.0, 0.12, 0.5, 0.3, 21, 30.0)
	s_glide(b, 0.0, 300.0, 140.0, 0.1, 0.3)
	_snd["slip"] = s_wav(b)
	# 音樂盒：四小節、五聲音階，叮叮噹噹（循環）
	var bars := 4
	b = s_buf(BEAT * 4.0 * bars)
	var mel := [
		[79, 76, 74, 76, 79, -1, 81, 79],
		[76, 74, 72, 74, 76, -1, -1, -1],
		[72, 74, 76, 79, 81, 79, 76, 74],
		[76, -1, 74, 72, 74, -1, -1, -1],
	]
	var bass := [48, 45, 53, 43]
	for bar in bars:
		var t0 := bar * BEAT * 4.0
		s_tone(b, t0, s_hz(bass[bar]), BEAT * 3.0, 0.22, 0.35, 1.4, true)
		s_tone(b, t0 + BEAT * 2.0, s_hz(bass[bar] + 7), BEAT * 1.8, 0.12, 0.35, 1.8, true)
		for i in 8:
			var note: int = mel[bar][i]
			if note < 0:
				continue
			var at := t0 + i * BEAT * 0.5
			s_tone(b, at, s_hz(note), BEAT * 1.4, 0.2, 0.75, 4.5, true)
			s_tone(b, at, s_hz(note) * 3.01, BEAT * 0.4, 0.03, 0.2, 12.0, true)
	_snd["theme"] = s_wav(b, true)
