extends CanvasLayer
## 冰雪島前三關的新手教學：「聚光燈＋圖解卡」，一步只講一件事。
##   聚光燈：畫面其他地方變暗，只亮要看的東西（外面一圈會轉的虛線圈）。
##   圖解卡：一排圖示（場上角色的即時特寫、道具圖、符號）＋一句短短的話。
##   說明的步驟按 Enter 繼續；要動手的步驟做到了才往下走（做到時打一個大勾）。Esc 跳過整段教學。
## 用法（rescue_battle.gd）：tut = IceTutorial.new(); add_child(tut); tut.begin(self, _tutorial_steps())
## 每一步：{
##   "pic":  圖示，由左到右（見 _token()）："who:阿土"（那個人的特寫）、"hero"、"cage"、"hole:0"、"thin:0"（第幾個冰洞／薄冰）、
##           "banana"、"feed"、符號 "line_y" 黃線、"line_r" 紅線、"slide" 滑出去、"lunge" 撲過來、"aim" 準心、"lmb" 左鍵、"mouse" 移動滑鼠、
##           "ok"、"no"、"to" →、"plus" ＋、"key:2" 鍵帽。圖示後面加 "+no" / "+ok" 會在右下角掛一個小 ✕／✓（例如 "banana+no"）。
##   "say":  一句話（越短越好）,
##   "spot": 聚光燈照哪裡（陣列，最多 3 個）—— Vector3、Callable（回傳 Vector3）、"slot:N"（第 N 格道具）、"start"（開始鈕）；空陣列＝不照,
##   "r":    聚光燈半徑（公尺；UI 目標會自動用它的大小）,
##   "wait": "next"（Enter 繼續）、"start"（等玩家按 Enter 開打）、或 Callable（回傳 true 就往下）,
##   "help_after": 秒數, "help_say" / "help_spot" / "help_pic": 卡住這麼久還沒做到時換上的提示（選填）,
## }

signal finished

const UISkin := preload("res://scripts/ui/ui_style.gd")
const Hotbar := preload("res://scripts/ui/hotbar.gd")
const ICON := 104.0              # 圖示格的大小
const LIVE_PX := 256             # 即時特寫的解析度
const TEX := {
	"banana": "res://levels/ice/assets/blender/rescue/banana_peel_icon.png",
	"feed": "res://levels/ice/assets/blender/rescue/feed_icon.png",
}
const DIM := 0.55                # 聚光燈外面暗多少

const SPOT_SHADER := """
shader_type canvas_item;
uniform vec2 rect_size = vec2(1280.0, 720.0);
uniform vec4 spot0 = vec4(0.0);   // xy 中心（像素）、z 半徑、w 開關
uniform vec4 spot1 = vec4(0.0);
uniform vec4 spot2 = vec4(0.0);
uniform float dim = 0.0;
float hole(vec2 p, vec4 s) {
	if (s.w < 0.5) return 1.0;
	return smoothstep(s.z, s.z + 18.0, length(p - s.xy));
}
void fragment() {
	vec2 p = UV * rect_size;
	float m = hole(p, spot0) * hole(p, spot1) * hole(p, spot2);
	COLOR = vec4(0.04, 0.06, 0.12, dim * m);
}
"""

var bt: Node
var steps: Array = []
var i := -1
var _t := 0.0
var _nudge := 0.0
var _tick := 0.0                 # 剛做到一步：大勾的動畫
var _dim := 0.0
var _help_lv := 0               # 0＝原本的說法；1、2＝卡住之後越來越直白的提示
var _ok_t := 0.0
var _card_slot := -1             # 卡片現在放在第幾個候選位置

var _shade: ColorRect
var _rings: Control
var _card: PanelContainer
var _dots: HBoxContainer
var _pic: HBoxContainer
var _say: Label
var _foot: HBoxContainer
var _check: Control
var _lives: Array = []           # 這一步的即時特寫 SubViewport
var _avoid_px: Array = []
var _spots_px: Array = []        # [[中心, 半徑], ...]（畫面像素）

# ================================================================== 建立

func _ready() -> void:
	layer = 6
	visible = false
	_shade = ColorRect.new()
	_shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = SPOT_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = sh
	_shade.material = mat
	add_child(_shade)
	_rings = Rings.new()
	_rings.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rings.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rings)
	_card = PanelContainer.new()
	UISkin.paper(_card, 0.0)
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	_card.add_child(v)
	_dots = HBoxContainer.new()
	_dots.alignment = BoxContainer.ALIGNMENT_CENTER
	_dots.add_theme_constant_override("separation", 6)
	v.add_child(_dots)
	_pic = HBoxContainer.new()
	_pic.alignment = BoxContainer.ALIGNMENT_CENTER
	_pic.add_theme_constant_override("separation", 10)
	v.add_child(_pic)
	_say = Label.new()
	UISkin.use_font(_say, 30, UISkin.INK)
	_say.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_say)
	_foot = HBoxContainer.new()
	_foot.alignment = BoxContainer.ALIGNMENT_CENTER
	_foot.add_theme_constant_override("separation", 22)
	v.add_child(_foot)
	_check = Glyph.new()
	_check.kind = "ok"
	_check.size = Vector2(56, 56)
	_check.pivot_offset = Vector2(28, 28)
	_check.z_index = 1
	_check.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_check.visible = false
	add_child(_check)

func active() -> bool:
	return i >= 0

func begin(battle: Node, list: Array) -> void:
	bt = battle
	steps = list
	if steps.is_empty():
		return
	visible = true
	_go(0)

func stop() -> void:
	if i < 0:
		return
	i = -1
	_clear_lives()
	visible = false
	finished.emit()

func waiting_start() -> bool:
	return i >= 0 and steps[i].get("wait") is String and steps[i].wait == "start"

func _is_next(s: Dictionary) -> bool:
	return s.get("wait") is String and s.wait == "next"

func _go(n: int) -> void:
	if i >= 0 and not _is_next(steps[i]) and not waiting_start():
		_tick = 0.7                  # 自己做到的：打一個大勾
	if n >= steps.size():
		stop()
		return
	i = n
	_t = 0.0
	_ok_t = 0.0
	_help_lv = 0
	_refresh()

func _cur(key: String, def = null):
	var s: Dictionary = steps[i]
	if _help_lv >= 2 and s.has("help2_" + key):
		return s["help2_" + key]
	if _help_lv >= 1 and s.has("help_" + key):
		return s["help_" + key]
	return s.get(key, def)

# ================================================================== 卡片內容

func _refresh() -> void:
	_clear_lives()
	for c in _dots.get_children():
		c.free()
	for k in steps.size():
		var d := ColorRect.new()
		d.color = UISkin.accent() if k == i else (Color(UISkin.INK, 0.45) if k < i else Color(UISkin.INK, 0.15))
		d.custom_minimum_size = Vector2(22 if k == i else 8, 8)
		d.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_dots.add_child(d)
	for c in _pic.get_children():
		c.free()
	for tk in _cur("pic", []):
		_pic.add_child(_token(String(tk)))
	_say.text = String(_cur("say", ""))
	for c in _foot.get_children():
		c.free()
	var s: Dictionary = steps[i]
	if _is_next(s):
		_foot.add_child(UISkin.key_hint("Enter", "繼續", 17))
	elif waiting_start():
		_foot.add_child(UISkin.key_hint("Enter", "開始！", 17))
	else:
		var tip := Label.new()
		tip.text = "換你試試"
		tip.label_settings = UISkin.ls(17, UISkin.accent())
		_foot.add_child(tip)
	var esc := UISkin.key_hint("Esc", "跳過教學", 15)
	esc.modulate.a = 0.6
	_foot.add_child(esc)
	_card.reset_size()

## 一個圖示：特寫／道具圖放在圓角框裡；符號直接畫
func _token(tk: String) -> Control:
	if "@" in tk:                    # 「圖示@小字」：圖示下面加一行小字（只給第一次出現、不好懂的符號用）
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 2)
		box.add_child(_token(tk.get_slice("@", 0)))
		var lb := Label.new()
		lb.text = tk.get_slice("@", 1)
		lb.label_settings = UISkin.ls(19, UISkin.INK)
		lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(lb)
		return box
	var badge := ""
	if tk.ends_with("+no") or tk.ends_with("+ok"):
		badge = tk.right(2)
		tk = tk.left(tk.length() - 3)
	var tex: Texture2D = null
	if TEX.has(tk):
		tex = load(TEX[tk])
	else:
		var focus = _focus_of(tk)
		if focus != null:
			tex = _live(focus[0], focus[1])
	if tk.begins_with("key:"):
		var kc := UISkin.keycap(tk.substr(4), 40)
		var cc := CenterContainer.new()
		cc.custom_minimum_size = Vector2(ICON * 0.8, ICON)
		cc.add_child(kc)
		return cc
	if tex == null:
		var g := Glyph.new()
		g.kind = "hole" if tk.begins_with("hole") else tk      # 這一關沒有現成的冰洞可以拍：畫一個
		var small := tk in ["to", "plus", "eq"]
		g.framed = not small                                      # 符號跟特寫用同一種圓角框（風格一致；角落的小勾、小叉不在這裡）
		g.custom_minimum_size = Vector2(ICON * (0.34 if small else 1.0), ICON)
		g.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return g
	var frame := Panel.new()
	frame.custom_minimum_size = Vector2(ICON, ICON)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("dfe9ef")
	sb.set_corner_radius_all(22)
	frame.add_theme_stylebox_override("panel", sb)
	frame.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	var tr := TextureRect.new()
	tr.texture = tex
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if TEX.has(tk):
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.offset_left = 10
		tr.offset_top = 10
		tr.offset_right = -10
		tr.offset_bottom = -10
	frame.add_child(tr)
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(ICON, ICON)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(frame)
	frame.size = Vector2(ICON, ICON)
	var edge := Panel.new()       # 外框畫在特寫上面（clip 的框自己不畫邊）
	var eb := StyleBoxFlat.new()
	eb.draw_center = false
	eb.border_color = UISkin.INK
	eb.set_border_width_all(3)
	eb.set_corner_radius_all(22)
	edge.add_theme_stylebox_override("panel", eb)
	edge.size = Vector2(ICON, ICON)
	edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(edge)
	if badge != "":
		var b := Glyph.new()
		b.kind = badge
		b.size = Vector2(46, 46)
		b.position = Vector2(ICON - 34, ICON - 34)
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(b)
	return holder

## 特寫要對著哪裡、離多遠：[位置, 距離]；不是特寫回傳 null
func _focus_of(tk: String):
	if tk == "hero":
		return [bt.bird.pos + Vector3(0, 0.9, 0), 3.6]
	if tk == "cage":
		return [bt.world.cage + Vector3(0, 1.3, 0), 5.2]
	if tk.begins_with("who:"):
		var f = bt.tut_enemy(tk.substr(4))
		return null if f == null else [f.pos + Vector3(0, 1.4, 0), 4.6]
	if tk.begins_with("hole:"):
		var pd: Array = bt.world.ponds
		var k := int(tk.substr(5))
		if k >= pd.size():
			return null
		var c: Vector2 = pd[k].center
		return [Vector3(c.x, 0, c.y), float(pd[k].r) * 3.0 + 1.0]
	if tk.begins_with("thin:"):
		var th: Array = bt.world.thin_spots
		var k2 := int(tk.substr(5))
		if k2 >= th.size():
			return null
		var c2: Vector2 = th[k2].center
		return [Vector3(c2.x, 0, c2.y), float(th[k2].r) * 3.0 + 1.0]
	return null

## 用一支小鏡頭拍場上的東西，當作圖示（跟玩家看到的一模一樣）
func _live(at: Vector3, dist: float) -> Texture2D:
	var main := get_viewport().get_camera_3d()
	var vp := SubViewport.new()
	vp.size = Vector2i(LIVE_PX, LIVE_PX)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.msaa_3d = Viewport.MSAA_4X
	add_child(vp)
	var cam := Camera3D.new()
	cam.fov = 38.0
	vp.add_child(cam)
	var d := Vector3(0, 0.8, 1)
	if main:
		d = main.global_position - at
	d = Vector3(d.x, maxf(d.y, 0.0) * 0.8 + 0.6, d.z).normalized()
	cam.position = at + d * dist
	cam.look_at(at)
	_lives.append(vp)
	return vp.get_texture()

func _clear_lives() -> void:
	for vp in _lives:
		if is_instance_valid(vp):
			vp.queue_free()
	_lives.clear()

# ================================================================== 輸入

func _input(event: InputEvent) -> void:
	if i < 0 or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var key: int = (event as InputEventKey).physical_keycode
	if key == KEY_ESCAPE:
		stop()
		get_viewport().set_input_as_handled()
		return
	if key in [KEY_ENTER, KEY_KP_ENTER]:
		if waiting_start():
			return                      # 放行：戰局自己開打（開打後 _process 會收掉教學）
		if _is_next(steps[i]):
			_go(i + 1)
		else:
			_nudge = 0.4
		get_viewport().set_input_as_handled()

# ================================================================== 每一畫面

func _process(dt: float) -> void:
	_tick = maxf(_tick - dt, 0.0)
	_update_check()
	if i < 0 or bt == null:
		return
	if int(bt.get("phase")) != 0 or bt.get("defeat_shown"):    # 0＝準備階段
		stop()
		return
	_t += dt
	var s: Dictionary = steps[i]
	var lv := 0
	if s.has("help_after") and _t >= float(s.help_after):
		lv = 1
	if s.has("help2_after") and _t >= float(s.help2_after):
		lv = 2
	if lv != _help_lv:
		_help_lv = lv
		_refresh()
	var w = s.get("wait")
	# 動手的步驟：條件要連續成立一小段時間才算（剛好掃過去不算，也讓玩家看清楚結果）
	if w is Callable and (w as Callable).call():
		_ok_t += dt
		if _ok_t >= float(s.get("hold", 0.4)):
			_go(i + 1)
			if i < 0:
				return
	else:
		_ok_t = 0.0
	_layout(dt)

func _layout(dt: float) -> void:
	var vs := get_viewport().get_visible_rect().size
	_spots_px.clear()
	var r_m: float = float(_cur("r", 1.8))
	for at in _cur("spot", []):
		var sp = _spot_px(at, r_m)
		if sp != null and _spots_px.size() < 3:
			_spots_px.append(sp)
	_merge_spots()
	_avoid_px.clear()
	var cg = _spot_px(bt.world.cage + Vector3(0, 1.4, 0), 2.4)
	if cg != null:
		var cc: Vector2 = cg[0]
		var cr: float = cg[1]
		_avoid_px.append(Rect2(cc - Vector2(cr, cr * 1.3), Vector2(cr * 2.0, cr * 2.3)))
	var want := DIM if not _spots_px.is_empty() else 0.0
	_dim = move_toward(_dim, want, dt * 2.5)
	var mat := _shade.material as ShaderMaterial
	mat.set_shader_parameter("rect_size", vs)
	mat.set_shader_parameter("dim", _dim)
	for k in 3:
		var v4 := Vector4.ZERO
		if k < _spots_px.size():
			var c: Vector2 = _spots_px[k][0]
			v4 = Vector4(c.x, c.y, _spots_px[k][1], 1.0)
		mat.set_shader_parameter("spot%d" % k, v4)
	(_rings as Rings).spots = _spots_px
	(_rings as Rings).t = _t
	_rings.queue_redraw()
	# 卡片放哪：幾個候選位置裡，蓋到聚光燈最少的那個（差不多就維持原位，不要一直跳）
	var cs := _card.get_combined_minimum_size()
	_card.size = cs
	var cands := [
		Vector2((vs.x - cs.x) * 0.5, 22.0),                    # 上方正中
		Vector2((vs.x - cs.x) * 0.5, vs.y - cs.y - 26.0),      # 下方正中
		Vector2(vs.x - cs.x - 20.0, (vs.y - cs.y) * 0.45),     # 右邊
		Vector2(20.0, (vs.y - cs.y) * 0.45),                   # 左邊
		Vector2(vs.x - cs.x - 20.0, 70.0),                     # 右上（讓開「R 重來」）
		Vector2(20.0, 160.0),                                  # 左上（讓開整人清單）
	]
	var best := 0
	var best_cost := INF
	var costs: Array = []
	for k in cands.size():
		var rc := Rect2(cands[k], cs).grow(14.0)
		var cost := k * 400.0                                  # 同樣沒蓋到時，照上面的順序選
		for sp in _spots_px:
			var c2: Vector2 = sp[0]
			var rr: float = sp[1] * 0.9
			cost += rc.intersection(Rect2(c2 - Vector2(rr, rr), Vector2(rr, rr) * 2.0)).get_area()
		for av in _avoid_px:                                   # 籠子（遊戲目標）也盡量不要蓋到
			cost += rc.intersection(av).get_area() * 0.6
		costs.append(cost)
		if cost < best_cost:
			best_cost = cost
			best = k
	if _card_slot < 0 or _card_slot >= cands.size() or costs[_card_slot] > best_cost + 3000.0:
		_card_slot = best
	var shake := sin(_nudge * 60.0) * 10.0 * (_nudge / 0.4) if _nudge > 0.0 else 0.0
	_nudge = maxf(_nudge - dt, 0.0)
	_card.position = cands[_card_slot] + Vector2(shake, 0)

## 疊在一起的聚光燈合成一個大圈（兩圈虛線交錯很亂）
func _merge_spots() -> void:
	var merged := true
	while merged:
		merged = false
		for a in _spots_px.size():
			for b in range(a + 1, _spots_px.size()):
				var ca: Vector2 = _spots_px[a][0]
				var cb: Vector2 = _spots_px[b][0]
				var ra: float = _spots_px[a][1]
				var rb: float = _spots_px[b][1]
				var d := ca.distance_to(cb)
				if d < (ra + rb) * 1.15:             # 碰在一起或靠很近就合成一個
					var r := (d + ra + rb) * 0.5
					var c := ca if d < 0.01 else ca + (cb - ca).normalized() * (r - ra)
					_spots_px[a] = [c, maxf(r, maxf(ra, rb))]
					_spots_px.remove_at(b)
					merged = true
					break
			if merged:
				break

## 聚光燈的位置和半徑（像素）
func _spot_px(at, r_m: float):
	if at is Callable:
		at = (at as Callable).call()
	if at == null:
		return null
	if at is String:
		var a := String(at)
		var ctl: Control = null
		var rect := Rect2()
		if a.begins_with("slot:"):
			ctl = bt.get("_hotbar")
			if ctl == null or not ctl.is_visible_in_tree():
				return null
			var r: Rect2 = ctl.get_global_rect()
			var k := int(a.substr(5))
			rect = Rect2(Vector2(r.position.x + 2.0 + k * Hotbar.S, r.position.y), Vector2(Hotbar.S, r.size.y))
		elif a == "center":                 # 畫面正中間的綠圈（準心）
			var vs2 := get_viewport().get_visible_rect().size
			return [vs2 * 0.5, 70.0, Color(0.35, 0.95, 0.45)]
		elif a == "start":
			ctl = bt.get("_start_box")
			if ctl == null or not ctl.is_visible_in_tree():
				return null
			rect = ctl.get_global_rect()
		else:
			return null
		return [rect.get_center(), rect.size.length() * 0.5 + 10.0]
	if at is Vector3:
		var cam := get_viewport().get_camera_3d()
		var w: Vector3 = at
		if cam == null or cam.is_position_behind(w):
			return null
		var c := cam.unproject_position(w)
		var e := cam.unproject_position(w + cam.global_basis.x * r_m)
		return [c, maxf(c.distance_to(e), 40.0)]
	return null

func _update_check() -> void:
	_check.visible = _tick > 0.0
	if not _check.visible:
		return
	var k := 1.0 - _tick / 0.7
	var vw := get_viewport().get_visible_rect().size.x
	_check.position = _card.position + Vector2(_card.size.x - 34.0, -22.0)   # 貼在卡片右上角（不蓋圖示和字）
	_check.position.x = minf(_check.position.x, vw - _check.size.x - 10.0)
	var sc := 0.6 + 0.6 * minf(k * 4.0, 1.0) - 0.15 * maxf(k * 4.0 - 1.0, 0.0) / 3.0
	_check.scale = Vector2.ONE * sc
	_check.modulate.a = 1.0 if k < 0.7 else (1.0 - k) / 0.3

# ================================================================== 畫圖用的小元件

## 聚光燈外圈：白色虛線圈，慢慢轉
class Rings extends Control:
	var spots: Array = []
	var t := 0.0
	func _draw() -> void:
		for sp in spots:
			var c: Vector2 = sp[0]
			var r: float = sp[1] + 6.0 + sin(t * 4.0) * 3.0
			var n := 28
			for k in n:
				if k % 2 == 1:
					continue
				var a0 := t * 0.8 + k * TAU / n
				var a1 := a0 + TAU / n
				draw_arc(c, r, a0, a1, 6, Color(0.1, 0.1, 0.1, 0.5), 7.0, true)
				draw_arc(c, r, a0, a1, 6, sp[2] if sp.size() > 2 else Color(1, 1, 1), 4.0, true)

## 符號：黃線、紅線、滑出去、撲過來、準心、滑鼠、✓、✕、→、＋
class Glyph extends Control:
	const INK := Color("3b2a20")
	const FLOW := Color(0.23, 0.16, 0.12, 0.45)    # 流程符號（→ ＋ ＝）用淡淡的灰，跟場上的箭頭分開
	var kind := ""
	var framed := false
	func _ready() -> void:
		resized.connect(queue_redraw)
	func _draw() -> void:
		var w := size.x
		var h := size.y
		var c := size * 0.5
		if framed:
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color("dcefd9") if kind == "ok" else Color("dfe9ef")
			sb.border_color = INK
			sb.set_border_width_all(3)
			sb.set_corner_radius_all(22)
			draw_style_box(sb, Rect2(Vector2.ZERO, size))
		match kind:
			"to":
				_arrow(Vector2(2, c.y), Vector2(w - 2, c.y), FLOW, 4.0, 10.0)
			"plus":
				draw_line(Vector2(c.x - 10, c.y), Vector2(c.x + 10, c.y), FLOW, 4.0)
				draw_line(Vector2(c.x, c.y - 10), Vector2(c.x, c.y + 10), FLOW, 4.0)
			"eq":
				draw_line(Vector2(c.x - 10, c.y - 5), Vector2(c.x + 10, c.y - 5), FLOW, 4.0)
				draw_line(Vector2(c.x - 10, c.y + 5), Vector2(c.x + 10, c.y + 5), FLOW, 4.0)
			"thin":
				# 薄冰：白白的圓盤＋裂痕（跟場上的薄冰同一個樣子）
				_ellipse(c + Vector2(0, 4), Vector2(38, 26), Color(0.62, 0.8, 0.9))
				_ellipse(c, Vector2(38, 26), Color(0.96, 0.98, 1.0))
				for a in [0.3, 1.5, 2.6, 3.9, 5.1]:
					var tip := c + Vector2(cos(a) * 30, sin(a) * 20)
					draw_polyline(PackedVector2Array([c, c.lerp(tip, 0.5) + Vector2(4, -3), tip]), Color(0.3, 0.4, 0.6), 2.0, true)
			"turn":
				# 撲的方向轉彎：紅圈＋往旁邊彎的箭頭
				var tc := Vector2(c.x - 10, c.y + 12)
				for k in 12:
					if k % 2 == 0:
						draw_arc(tc, 26, k * TAU / 12, (k + 1) * TAU / 12, 6, Color(0.9, 0.2, 0.2), 5.0, true)
				var pts := PackedVector2Array()
				for k in 9:
					var a := lerpf(PI * 1.05, PI * 1.75, k / 8.0)
					pts.append(tc + Vector2(cos(a), sin(a)) * 34.0 + Vector2(18, 4))
				draw_polyline(pts, Color(0.9, 0.2, 0.2), 8.0, true)
				_head(pts[pts.size() - 2], pts[pts.size() - 1] + (pts[pts.size() - 1] - pts[pts.size() - 2]).normalized() * 8.0, Color(0.9, 0.2, 0.2), 14.0)
			"ring":
				# 守衛腳下的紅圈
				for k in 14:
					if k % 2 == 0:
						draw_arc(c, 32, k * TAU / 14, (k + 1) * TAU / 14, 6, Color(0.9, 0.2, 0.2), 6.0, true)
			"line_y":
				_dashes(Vector2(10, h * 0.7), Vector2(w - 10, h * 0.3), Color(1.0, 0.82, 0.2), Color(0.35, 0.25, 0.05), 9.0)
			"line_r":
				_dashes(Vector2(10, h * 0.7), Vector2(w - 24, h * 0.3), Color(0.9, 0.2, 0.2), Color(0.35, 0.05, 0.05), 11.0)
				_head(Vector2(w - 24, h * 0.3), Vector2(w - 8, h * 0.22), Color(0.9, 0.2, 0.2), 14.0)
			"slide":
				# 跟場上預告的白箭頭同一個樣子：白色、深色粗外框，底下墊一塊淡藍（米色紙上才看得清楚）
				var a0 := Vector2(14, h * 0.7)
				var a1 := Vector2(w - 10, h * 0.3)
				_arrow(a0, a1, Color(0.2, 0.14, 0.1), 18.0, 34.0)
				var dd := (a1 - a0).normalized()
				_arrow(a0 + dd * 3.0, a1 - dd * 5.0, Color(1, 1, 1), 10.0, 24.0)
			"lunge":
				var rc := Vector2(c.x - 6, c.y + 6)
				for k in 12:
					if k % 2 == 0:
						draw_arc(rc, 30, k * TAU / 12, (k + 1) * TAU / 12, 6, Color(0.9, 0.2, 0.2), 5.0, true)
				_arrow(rc, Vector2(w - 10, 12), Color(0.9, 0.2, 0.2), 9.0, 20.0)
			"aim":
				draw_arc(c, 30, 0, TAU, 40, Color(0.15, 0.15, 0.15), 9.0, true)
				draw_arc(c, 30, 0, TAU, 40, Color(0.35, 0.95, 0.45), 5.0, true)
				draw_circle(c, 5, Color(1, 1, 1))
			"lmb", "mouse":
				var body := Rect2(c.x - 24, c.y - 36, 48, 72)
				_round(body, 22, Color(1, 1, 1), INK)
				if kind == "lmb":
					var lb := PackedVector2Array([Vector2(c.x - 22, c.y - 6), Vector2(c.x - 22, c.y - 18), Vector2(c.x - 14, c.y - 32), Vector2(c.x - 2, c.y - 34), Vector2(c.x - 2, c.y - 6)])
					draw_colored_polygon(lb, Color(1.0, 0.55, 0.2))
				draw_line(Vector2(c.x, c.y - 34), Vector2(c.x, c.y - 6), INK, 3.0)
				draw_line(Vector2(c.x - 23, c.y - 6), Vector2(c.x + 23, c.y - 6), INK, 3.0)
				if kind == "mouse":
					_arrow(Vector2(c.x - 30, c.y + 30), Vector2(c.x - 46, c.y + 30), INK, 4.0, 9.0)
					_arrow(Vector2(c.x + 30, c.y + 30), Vector2(c.x + 46, c.y + 30), INK, 4.0, 9.0)
			"hole":
				var hc := Vector2(c.x, c.y + 4)
				_ellipse(hc, Vector2(44, 30), Color(0.85, 0.95, 1.0))
				_ellipse(hc, Vector2(36, 23), Color(0.1, 0.3, 0.38))
				_ellipse(hc + Vector2(-6, 4), Vector2(20, 11), Color(0.05, 0.18, 0.24))
			"q":
				var rq := minf(w, h) * 0.36
				draw_circle(c, rq + 3, INK)
				draw_circle(c, rq, Color(1.0, 0.92, 0.55))
				var f := get_theme_default_font()
				draw_string(f, Vector2(c.x - rq, c.y + rq * 0.45), "?", HORIZONTAL_ALIGNMENT_CENTER, rq * 2.0, int(rq * 1.3), INK)
			"ok":
				var r := minf(w, h) * (0.3 if framed else 0.42)
				draw_circle(c, r + 3, Color(1, 1, 1))
				draw_circle(c, r, Color(0.3, 0.72, 0.32))
				draw_polyline(PackedVector2Array([c + Vector2(-r * 0.5, 0), c + Vector2(-r * 0.12, r * 0.4), c + Vector2(r * 0.55, -r * 0.42)]), Color(1, 1, 1), maxf(r * 0.22, 3.0), true)
			"no":
				var r2 := minf(w, h) * (0.3 if framed else 0.42)
				draw_circle(c, r2 + 3, Color(1, 1, 1))
				draw_circle(c, r2, Color(0.85, 0.22, 0.2))
				var q := r2 * 0.45
				draw_line(c + Vector2(-q, -q), c + Vector2(q, q), Color(1, 1, 1), maxf(r2 * 0.22, 3.0))
				draw_line(c + Vector2(q, -q), c + Vector2(-q, q), Color(1, 1, 1), maxf(r2 * 0.22, 3.0))
	func _dashes(a: Vector2, b: Vector2, col: Color, edge: Color, wd: float) -> void:
		var n := 5
		for k in n:
			var p0 := a.lerp(b, float(k) / n)
			var p1 := a.lerp(b, (k + 0.6) / n)
			draw_line(p0, p1, edge, wd + 4.0)
			draw_line(p0, p1, col, wd)
	func _head(from: Vector2, tip: Vector2, col: Color, s: float) -> void:
		var d := (tip - from).normalized()
		var n := Vector2(-d.y, d.x)
		draw_colored_polygon(PackedVector2Array([tip + d * 4.0, from + n * s * 0.8, from - n * s * 0.8]), col)
	func _arrow(a: Vector2, b: Vector2, col: Color, wd: float, head: float) -> void:
		var d := (b - a).normalized()
		var n := Vector2(-d.y, d.x)
		var base := b - d * head
		draw_line(a, base, col, wd)
		draw_colored_polygon(PackedVector2Array([b, base + n * head * 0.7, base - n * head * 0.7]), col)
	func _ellipse(cc: Vector2, rr: Vector2, col: Color) -> void:
		var pts := PackedVector2Array()
		for k in 32:
			var a := k * TAU / 32
			pts.append(cc + Vector2(cos(a) * rr.x, sin(a) * rr.y))
		draw_colored_polygon(pts, col)
	func _round(r: Rect2, rad: float, fill: Color, edge: Color) -> void:
		var sb := StyleBoxFlat.new()
		sb.bg_color = fill
		sb.border_color = edge
		sb.set_border_width_all(3)
		sb.set_corner_radius_all(int(rad))
		draw_style_box(sb, r)
