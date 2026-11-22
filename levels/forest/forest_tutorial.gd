extends CanvasLayer
## 森林的新手教學：一步只講一件事。
##   聚光燈：畫面其他地方變暗，只亮要看的東西（外面一圈會轉的虛線）。鏡頭會自己飛過去對準它。
##   說明卡：一排圖示（道具圖、場上角色的即時特寫、按鍵）＋一句短短的話。
##   說明的步驟按 Enter 繼續；要動手的步驟做到了才往下走（做到時打一個大勾）。Esc 跳過整段教學。
## 用法（forest_battle.gd）：tut = ForestTutorial.new(); add_child(tut); tut.begin(self, 步驟陣列)
## 每一步：{
##   "pic":  圖示（由左到右）："icon:decoy"（道具圖）、"hero"（家豪的即時特寫）、"who:伐木1"（那個人的特寫）、
##           "at:x,z"（場上那個位置的特寫）、"key:2"（鍵帽）、"lmb"（滑鼠左鍵）、"to" →、"plus" ＋、"ok" ✓、"no" ✕,
##   "say":  一句話,
##   "spot": 聚光燈照哪裡（陣列）—— Vector3、Callable（回傳 Vector3）、"slot:N"（第 N 格道具）、"start"（開始鈕）,
##   "r":    聚光燈半徑（公尺）,
##   "look": 鏡頭飛過去看哪裡（Vector3 或 Callable；選填）,
##   "wait": "next"（Enter 繼續）、"start"（等玩家按 Enter 開打）、或 Callable（回傳 true 就往下）,
##   "help_after" 秒數 + "help_say"：卡住這麼久還沒做到時換上的提示（選填）,
## }

signal finished

const UISkin := preload("res://scripts/ui/ui_style.gd")
const Models := preload("res://levels/forest/items/models.gd")
const ICON := 96.0
const LIVE_PX := 192
const DIM := 0.55

const SPOT_SHADER := """
shader_type canvas_item;
uniform vec2 rect_size = vec2(1280.0, 720.0);
uniform vec4 spot0 = vec4(0.0);
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
	COLOR = vec4(0.03, 0.07, 0.04, dim * m);
}
"""

var bt: Node
var steps: Array = []
var i := -1
var _t := 0.0
var _ok_t := 0.0
var _helped := false
var _nudge := 0.0
var _tick := 0.0
var _dim := 0.0
var _spots_px: Array = []        # [[中心, 半徑], ...]
var _lives: Array = []           # {vp, cam, at: Callable, dist}

var _shade: ColorRect
var _rings: Rings
var _card: PanelContainer
var _pic: HBoxContainer
var _say: Label
var _foot: HBoxContainer
var _dots: HBoxContainer
var _check: Label

func _init() -> void:
	layer = 6

func _ready() -> void:
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
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UISkin.paper(_card)
	add_child(_card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(col)
	_dots = HBoxContainer.new()
	_dots.add_theme_constant_override("separation", 5)
	_dots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_dots)
	_pic = HBoxContainer.new()
	_pic.add_theme_constant_override("separation", 10)
	_pic.alignment = BoxContainer.ALIGNMENT_CENTER
	_pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_pic)
	_say = Label.new()
	_say.label_settings = UISkin.ls(24, UISkin.INK)
	_say.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_say.custom_minimum_size = Vector2(540, 0)
	_say.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_say.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_say)
	_foot = HBoxContainer.new()
	_foot.add_theme_constant_override("separation", 18)
	_foot.alignment = BoxContainer.ALIGNMENT_CENTER
	_foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_foot)
	_check = Label.new()
	_check.text = "✓"
	_check.label_settings = UISkin.ls(64, Color(0.3, 0.75, 0.3), 10, Color(1, 1, 1))
	_check.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_check.visible = false
	add_child(_check)
	visible = false

# ================================================================== 流程

func begin(battle: Node, list: Array) -> void:
	bt = battle
	steps = list
	if steps.is_empty():
		return
	visible = true
	_hotkeys(false)
	_go(0)

func active() -> bool:
	return i >= 0

func stop() -> void:
	if i < 0:
		return
	i = -1
	_clear_lives()
	visible = false
	_hotkeys(true)
	finished.emit()

## 教學時 Esc 是「跳過教學」，不要打開暫停選單
func _hotkeys(on: bool) -> void:
	var pm = bt.get("pause_menu") if bt else null
	if pm != null and "hotkey" in pm:
		pm.hotkey = on

func _wait(s: Dictionary):
	return s.get("wait", "next")

func _is_next(s: Dictionary) -> bool:
	return _wait(s) is String and _wait(s) == "next"

func waiting_start() -> bool:
	return i >= 0 and _wait(steps[i]) is String and _wait(steps[i]) == "start"

func _go(n: int) -> void:
	if i >= 0 and not _is_next(steps[i]) and not waiting_start():
		_tick = 0.7
		if bt.has_method("sfx"):
			bt.sfx("check")
	if n >= steps.size():
		stop()
		return
	i = n
	_t = 0.0
	_ok_t = 0.0
	_helped = false
	var look = steps[i].get("look")
	if look is Callable:
		look = (look as Callable).call()
	if look is Vector3:
		_fly_to(look)
	_refresh()

## 鏡頭飛到能看清楚 target 的地方（從南邊斜上方往下看）
func _fly_to(target: Vector3) -> void:
	var view = bt.get("view")
	var cam := get_viewport().get_camera_3d()
	if view == null or cam == null or view.busy or view.overview:
		return
	var eye := target + Vector3(2.2, 7.0, 7.8)
	var to := Transform3D(Basis.looking_at(target - eye, Vector3.UP), eye)
	view._fly(cam.global_transform, to, false)

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
	for tk in steps[i].get("pic", []):
		_pic.add_child(_token(String(tk)))
	var s: Dictionary = steps[i]
	_say.text = String(s.get("help_say", s.say) if _helped else s.get("say", ""))
	for c in _foot.get_children():
		c.free()
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

func _token(tk: String) -> Control:
	var box := PanelContainer.new()
	box.custom_minimum_size = Vector2(ICON, ICON)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 0.98, 0.92)
	sb.border_color = Color(UISkin.INK, 0.55)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(4)
	box.add_theme_stylebox_override("panel", sb)
	if tk.begins_with("icon:"):
		var tr := TextureRect.new()
		tr.texture = Models.icon(tk.substr(5))
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(tr)
		return box
	if tk == "hero" or tk.begins_with("who:") or tk.begins_with("at:"):
		var at: Callable
		var dist := 3.2
		if tk == "hero":
			at = func(): return bt.bird.pos + Vector3(0, 0.6, 0)
			dist = 2.4
		elif tk.begins_with("who:"):
			var n := tk.substr(4)
			at = func():
				for f in bt.enemies:
					if f.name == n:
						return f.pos + Vector3(0, 1.3, 0)
				return Vector3.ZERO
		else:
			var xz := tk.substr(3).split(",")
			var p := Vector3(float(xz[0]), 0.0, float(xz[1]))
			at = func(): return bt.ground(p) + Vector3(0, 1.0, 0)
			dist = 5.0
		var tr2 := TextureRect.new()
		tr2.texture = _live(at, dist)
		tr2.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr2.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr2.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(tr2)
		box.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
		return box
	# 符號：不畫框
	var l := Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if tk.begins_with("key:"):
		return _centered(UISkin.keycap(tk.substr(4), 30))
	if tk == "lmb":
		return _centered(UISkin.keycap("左鍵", 26))
	match tk:
		"to":
			l.text = "→"
			l.label_settings = UISkin.ls(40, Color(UISkin.INK, 0.7))
		"plus":
			l.text = "＋"
			l.label_settings = UISkin.ls(36, Color(UISkin.INK, 0.7))
		"ok":
			l.text = "✓"
			l.label_settings = UISkin.ls(48, Color(0.3, 0.7, 0.3))
		"no":
			l.text = "✕"
			l.label_settings = UISkin.ls(44, Color(0.85, 0.25, 0.2))
		_:
			l.text = tk
			l.label_settings = UISkin.ls(24, UISkin.INK)
	return l

func _centered(c: Control) -> Control:
	var w := CenterContainer.new()
	w.custom_minimum_size = Vector2(ICON * 0.8, ICON)
	w.mouse_filter = Control.MOUSE_FILTER_IGNORE
	w.add_child(c)
	return w

## 場上某個東西的即時特寫（跟主畫面同一個世界，另一台小鏡頭）
func _live(at: Callable, dist: float) -> Texture2D:
	var vp := SubViewport.new()
	vp.size = Vector2i(LIVE_PX, LIVE_PX)
	vp.world_3d = get_viewport().world_3d
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var cam := Camera3D.new()
	cam.fov = 40.0
	vp.add_child(cam)
	add_child(vp)
	_lives.append({"vp": vp, "cam": cam, "at": at, "dist": dist})
	_aim_live(_lives.back())
	return vp.get_texture()

func _aim_live(e: Dictionary) -> void:
	var p: Vector3 = (e.at as Callable).call()
	var main := get_viewport().get_camera_3d()
	var d := Vector3(0.4, 0, 1)
	if main:
		d = main.global_position - p
	d.y = 0.0
	d = d.normalized() if d.length() > 0.1 else Vector3.BACK
	var eye: Vector3 = p + d * float(e.dist) + Vector3(0, float(e.dist) * 0.35, 0)
	(e.cam as Camera3D).global_position = eye
	(e.cam as Camera3D).look_at(p, Vector3.UP)

func _clear_lives() -> void:
	for e in _lives:
		if is_instance_valid(e.vp):
			(e.vp as Node).queue_free()
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
			_nudge = 0.4                # 還沒做到：卡片搖一下
		get_viewport().set_input_as_handled()

# ================================================================== 每一畫面

func _process(dt: float) -> void:
	_tick = maxf(_tick - dt, 0.0)
	_update_check()
	if i < 0 or bt == null:
		return
	if int(bt.get("phase")) != 0 or bt.get("defeat_shown"):    # 0＝準備階段；開打就收掉
		stop()
		return
	_t += dt
	var s: Dictionary = steps[i]
	if not _helped and s.has("help_after") and _t >= float(s.help_after):
		_helped = true
		_refresh()
	var w = _wait(s)
	if w is Callable and (w as Callable).call():
		_ok_t += dt
		if _ok_t >= 0.35:
			_go(i + 1)
			if i < 0:
				return
	else:
		_ok_t = 0.0
	for e in _lives:
		_aim_live(e)
	_layout(dt)

func _layout(dt: float) -> void:
	var vs := get_viewport().get_visible_rect().size
	_spots_px.clear()
	var r_m: float = float(steps[i].get("r", 1.8))
	for at in steps[i].get("spot", []):
		var sp = _spot_px(at, r_m)
		if sp != null and _spots_px.size() < 3:
			_spots_px.append(sp)
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
	_rings.spots = _spots_px
	_rings.t = _t
	_rings.queue_redraw()
	# 卡片放在蓋到聚光燈最少的位置（上、下、右、左）
	var cs := _card.get_combined_minimum_size()
	_card.size = cs
	var cands := [
		Vector2((vs.x - cs.x) * 0.5, 22.0),
		Vector2(vs.x - cs.x - 20.0, (vs.y - cs.y) * 0.4),
		Vector2(20.0, (vs.y - cs.y) * 0.4),
		Vector2((vs.x - cs.x) * 0.5, vs.y - cs.y - 150.0),
	]
	var best := 0
	var best_cost := INF
	for k in cands.size():
		var rc := Rect2(cands[k], cs).grow(14.0)
		var cost := k * 400.0
		for sp in _spots_px:
			var c2: Vector2 = sp[0]
			var rr: float = sp[1]
			cost += rc.intersection(Rect2(c2 - Vector2(rr, rr), Vector2(rr, rr) * 2.0)).get_area()
		if cost < best_cost:
			best_cost = cost
			best = k
	var shake := sin(_nudge * 60.0) * 10.0 * (_nudge / 0.4) if _nudge > 0.0 else 0.0
	_nudge = maxf(_nudge - dt, 0.0)
	_card.position = _card.position.lerp(cands[best], minf(dt * 10.0, 1.0)) if _card.position != Vector2.ZERO else cands[best]
	_card.position.x += shake

## 聚光燈的位置和半徑（像素）；看不到就回傳 null
func _spot_px(at, r_m: float):
	if at is Callable:
		at = (at as Callable).call()
	if at == null:
		return null
	if at is String:
		var a := String(at)
		var rect := Rect2()
		if a.begins_with("slot:"):
			var hb: Control = bt.get("_hotbar")
			if hb == null or not hb.is_visible_in_tree():
				return null
			var r: Rect2 = hb.get_global_rect()
			var k := int(a.substr(5))
			# 道具欄可能被縮放過：用實際寬度除以格數，不用 Hotbar.S
			var n := maxi((bt.get("items") as Array).size(), 1)
			var w := (r.size.x - 4.0) / float(n)
			rect = Rect2(Vector2(r.position.x + 2.0 + k * w, r.position.y), Vector2(w, r.size.y))
		elif a == "start":
			var sb: Control = bt.get("_start_btn")
			if sb == null or not sb.is_visible_in_tree():
				return null
			rect = sb.get_global_rect()
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
	_check.position = _card.position + Vector2(_card.size.x - 40.0, -34.0)
	_check.pivot_offset = _check.size * 0.5
	_check.scale = Vector2.ONE * (0.6 + 0.6 * minf(k * 4.0, 1.0) - 0.15 * maxf(k * 4.0 - 1.0, 0.0) / 3.0)
	_check.modulate.a = 1.0 if k < 0.7 else (1.0 - k) / 0.3

## 聚光燈外面那圈會轉的虛線
class Rings extends Control:
	var spots: Array = []
	var t := 0.0
	func _draw() -> void:
		for sp in spots:
			var c: Vector2 = sp[0]
			var r: float = float(sp[1]) + 10.0 + 3.0 * sin(t * 4.0)
			var n := 28
			for k in n:
				if k % 2 == 1:
					continue
				var a0 := t * 0.8 + TAU * k / n
				draw_arc(c, r, a0, a0 + TAU / n, 6, Color(1.0, 0.92, 0.55, 0.95), 4.0, true)
