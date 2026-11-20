extends RefCounted
## 主島小東西（釣魚、手帳）共用的畫圖工具，用全遊戲的「手帳」風格（scripts/ui/ui_style.gd）。
## 都是 static：const HubUI := preload("res://scripts/hub/hub_ui.gd")。畫在一張 Control 上（c.draw_*）。
## 尺寸都以 1600×900 的畫面為準，u 是目前畫面的縮放比例。

const UIStyle := preload("res://scripts/ui/ui_style.gd")

const INK := Color("3b2a20")
const PAPER := Color("fff8e7")
const PAPER_EDGE := Color("d9c9a8")
const GOLD := Color("f2c230")
const GOLD_EDGE := Color("8a6410")
const GREEN := Color("5cb85c")
const RED := Color("e8483a")

## 一張自己畫的 Control：畫圖交給 painter，滑鼠交給 on_move／on_click
class Canvas:
	extends Control
	var painter: Callable
	var on_move: Callable
	var on_click: Callable
	func _draw() -> void:
		if painter.is_valid():
			painter.call(self)
	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseMotion and on_move.is_valid():
			on_move.call(e.position)
		elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT and on_click.is_valid():
			on_click.call(e.position)
			accept_event()

static func scale_of(vp: Vector2) -> float:
	return minf(vp.x / 1600.0, vp.y / 900.0)

static func font() -> Font:
	var f := UIStyle.font()
	return f if f else ThemeDB.fallback_font

static func box(bg: Color, edge: Color, radius: float, border := 3.0, shadow := true) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = edge
	s.set_border_width_all(int(border))
	s.border_width_bottom = int(border) + 2
	s.set_corner_radius_all(int(radius))
	if shadow:
		s.shadow_color = Color(0, 0, 0, 0.3)
		s.shadow_size = 8
		s.shadow_offset = Vector2(3, 6)
	return s

static func text(c: Control, pos: Vector2, t: String, size: float, col: Color, w := -1.0, align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	c.draw_string(font(), pos, t, align, w, int(size), col)

static func text_w(t: String, size: float) -> float:
	return font().get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, int(size)).x

## 置中的字（x 是中心）
static func text_c(c: Control, center: Vector2, t: String, size: float, col: Color) -> void:
	c.draw_string(font(), Vector2(center.x - text_w(t, size) * 0.5, center.y + size * 0.36), t, HORIZONTAL_ALIGNMENT_LEFT, -1, int(size), col)

## 字太寬就縮小字級
static func fit(t: String, size: float, w: float, min_size := 11.0) -> float:
	while size > min_size and text_w(t, size) > w:
		size -= 1.0
	return size

## 自動換行（照寬度切）；回傳每一行
static func wrap(t: String, size: float, w: float) -> PackedStringArray:
	var lines := PackedStringArray()
	var cur := ""
	for i in t.length():
		var ch := t.substr(i, 1)
		if text_w(cur + ch, size) > w and cur != "":
			lines.append(cur)
			cur = ch
		else:
			cur += ch
	if cur != "":
		lines.append(cur)
	return lines

static func star(c: Control, center: Vector2, r: float, col: Color, edge := Color(0, 0, 0, 0)) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI * 0.5 + i * PI / 5.0
		var rr := r if i % 2 == 0 else r * 0.46
		pts.append(center + Vector2(cos(a), sin(a)) * rr)
	c.draw_colored_polygon(pts, col)
	if edge.a > 0.0:
		pts.append(pts[0])
		c.draw_polyline(pts, edge, maxf(r * 0.12, 1.5), true)

## 一條魚的剪影（側面）：身體、尾巴、眼睛。len 是全長，flip 讓牠朝左
static func fish_icon(c: Control, center: Vector2, len: float, col: Color, flip := false, known := true) -> void:
	var s := -1.0 if flip else 1.0
	var h := len * 0.34
	var body := PackedVector2Array()
	for i in 21:
		var a := i * TAU / 20.0
		body.append(center + Vector2(cos(a) * len * 0.34 * s, sin(a) * h * 0.62) - Vector2(len * 0.06 * s, 0))
	var tail := PackedVector2Array([center + Vector2(-len * 0.28 * s, 0), center + Vector2(-len * 0.5 * s, -h * 0.58), center + Vector2(-len * 0.5 * s, h * 0.58)])
	var fin := PackedVector2Array([center + Vector2(-len * 0.04 * s, -h * 0.5), center + Vector2(len * 0.08 * s, -h * 0.95), center + Vector2(len * 0.16 * s, -h * 0.4)])
	var edge := col.darkened(0.45)
	var fill := col if known else Color("b9b2a2")
	var line_col := edge if known else Color("8a847a")
	c.draw_colored_polygon(tail, fill.darkened(0.08))
	c.draw_colored_polygon(fin, fill.darkened(0.08))
	c.draw_colored_polygon(body, fill)
	var body_edge := body.duplicate()
	body_edge.append(body[0])
	c.draw_polyline(body_edge, line_col, maxf(len * 0.025, 1.5), true)
	if known:
		c.draw_circle(center + Vector2(len * 0.19 * s, -h * 0.1), len * 0.035, Color.WHITE)
		c.draw_circle(center + Vector2(len * 0.2 * s, -h * 0.1), len * 0.02, INK)
		c.draw_polyline(PackedVector2Array([center + Vector2(len * 0.09 * s, h * 0.08), center + Vector2(len * 0.1 * s, h * 0.22)]), edge, maxf(len * 0.02, 1.2), true)

## 貼紙：圓形、中間一個字；沒拿到是灰色問號
static func sticker(c: Control, center: Vector2, r: float, glyph: String, col: Color, got: bool, tilt := 0.0) -> void:
	c.draw_circle(center + Vector2(0, r * 0.1), r + 4.0, Color(0, 0, 0, 0.2))
	if got:
		c.draw_circle(center, r + 4.0, Color(1, 1, 1))
		c.draw_circle(center, r, col)
		c.draw_arc(center, r * 0.82, 0.0, TAU, 40, Color(1, 1, 1, 0.55), maxf(r * 0.05, 1.5), true)
		text_c(c, center + Vector2(0, -r * 0.02), glyph, r * 1.05, Color.WHITE)
	else:
		c.draw_circle(center, r + 4.0, Color("e6e0d2"))
		c.draw_circle(center, r, Color("cfc8b8"))
		text_c(c, center, "？", r * 0.95, Color("9c968a"))

## 右下角的按鍵提示（一條橫的小紙片）。items：[[["←","→"], "走路"], [["Space"], "甩竿"]]
static func key_strip(c: Control, u: float, items: Array) -> void:
	var vs := c.size
	var ks := 16.0 * u
	var ts := 20.0 * u
	var gap := 4.0 * u
	var cap_h := UIStyle.keycap_size("M", ks).y
	var w := 0.0
	for it in items:
		for key in it[0]:
			w += UIStyle.keycap_size(String(key), ks).x + gap
		w += 5.0 * u + text_w(String(it[1]), ts)
	w += 26.0 * u * (items.size() - 1)
	var r := Rect2(Vector2(vs.x - w - 58.0 * u, vs.y - 68.0 * u), Vector2(w + 36.0 * u, 48.0 * u))
	c.draw_style_box(box(Color(PAPER, 0.94), PAPER_EDGE, 24 * u, 3.0), r)
	var x := r.position.x + 18.0 * u
	var cy := r.get_center().y - 1.0 * u
	for it in items:
		for key in it[0]:
			x += UIStyle.draw_keycap(c, Vector2(x, cy - cap_h * 0.5), String(key), ks).x + gap
		x += 5.0 * u
		var label := String(it[1])
		text(c, Vector2(x, cy + ts * 0.36), label, ts, INK)
		x += text_w(label, ts) + 26.0 * u

## 一個紙泡泡（圓角米色底），尖角往下指著 tip（畫面座標）。回傳泡泡的框
static func bubble(c: Control, center: Vector2, size: Vector2, tip: Vector2, u: float) -> Rect2:
	var r := Rect2(center - size * 0.5, size)
	c.draw_style_box(box(PAPER, PAPER_EDGE, 24 * u, 3.0), r)
	var tx := clampf(tip.x, r.position.x + 36 * u, r.end.x - 36 * u)
	var ty := r.end.y
	c.draw_colored_polygon(PackedVector2Array([Vector2(tx - 15 * u, ty - 4.0), Vector2(tx + 15 * u, ty - 4.0), tip]), PAPER)
	c.draw_polyline(PackedVector2Array([Vector2(tx - 15 * u, ty - 1.0), tip, Vector2(tx + 15 * u, ty - 1.0)]), PAPER_EDGE, 3.0, true)
	return r

## 一條緞帶小標籤（「新發現！」）
static func tag(c: Control, center: Vector2, label: String, size: float, bg: Color, edge: Color, rot := -0.08) -> void:
	var w := text_w(label, size) + size * 1.1
	c.draw_set_transform(center, rot, Vector2.ONE)
	c.draw_style_box(box(bg, edge, size * 0.45, 3.0, false), Rect2(Vector2(-w * 0.5, -size * 0.7), Vector2(w, size * 1.4)))
	text_c(c, Vector2.ZERO, label, size, Color.WHITE)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
