extends RefCounted
## 全遊戲共用的介面美術：「手帳」風格（參考 Untitled Goose Game 的筆記紙待辦清單）。
## 所有底板都用程式畫（圓角、邊框、陰影、對話框尾巴），放大也清楚；字型用 jf 粉圓體（OFL，assets/fonts/）。
## 每個大關可以換「主題色」（UIStyle.use_theme("ice") 之類），形狀和字型全遊戲一致。
##
## 用法：
##   const UIStyle := preload("res://scripts/ui/ui_style.gd")
##   UIStyle.ls(28)           做一個用共用字型的 LabelSettings（2D 字）
##   Skin.paper(panel)        筆記紙（整人清單、結算）
##   Skin.sticky(panel)       便利貼（怎麼玩）
##   Skin.ribbon(label)       紅色緞帶（大標題）
##   Skin.pill(label)         圓角膠囊（字卡、上方提示）
##   Skin.plate(label3d, "bubble" / "wood" / "ice" / "red")   3D 字後面加底板（每畫面呼叫 Skin.refresh 更新大小）

const FONT_PATH := "res://assets/fonts/jf-openhuninn-2.1.ttf"

const INK := Color("3b2a20")
const PAPER := Color("fff8e7")
const PAPER_EDGE := Color("d9c9a8")
const RULE := Color(0.45, 0.62, 0.85, 0.28)
const MARGIN := Color(0.88, 0.36, 0.36, 0.55)
const STICKY := Color("ffe98a")
const STICKY_EDGE := Color("d9b84a")
const RIBBON := Color("e2483d")
const RIBBON_EDGE := Color("8f231c")
const ICE := Color("e2f4ff")
const ICE_EDGE := Color("2c5d8a")
const WOOD := Color("9a6a42")
const WOOD_EDGE := Color("4a2e1b")
const TAPE := Color(0.95, 0.88, 0.6, 0.75)

static var _font: Font
static var _tex_cache := {}

## 主題色：各大關的強調色（緞帶、標籤）。形狀、字型、紙張全遊戲一樣，只換這幾個顏色
const THEMES := {
	"default": {"accent": Color("e2483d"), "accent_edge": Color("8f231c"), "tag": Color("e2f4ff"), "tag_edge": Color("2c5d8a")},
	"ice": {"accent": Color("e2483d"), "accent_edge": Color("8f231c"), "tag": Color("e2f4ff"), "tag_edge": Color("2c5d8a")},
	"farm": {"accent": Color("d9822b"), "accent_edge": Color("7a4512"), "tag": Color("fff1c9"), "tag_edge": Color("8a6a1c")},
	"forest": {"accent": Color("4f9a4a"), "accent_edge": Color("244d22"), "tag": Color("e8f6df"), "tag_edge": Color("3d6b35")},
	"volcano": {"accent": Color("d6452b"), "accent_edge": Color("6e1d10"), "tag": Color("ffe3d6"), "tag_edge": Color("8a3a22")},
}
static var theme_name := "default"

static func use_theme(name: String) -> void:
	theme_name = name if THEMES.has(name) else "default"

static func accent() -> Color:
	return THEMES[theme_name].accent

static func accent_edge() -> Color:
	return THEMES[theme_name].accent_edge

## 用共用字型的 LabelSettings（2D 字）。outline 0 就是沒有外框
static func ls(size: int, color := INK, outline := 0, outline_color := Color(0, 0, 0, 0.6)) -> LabelSettings:
	var s := LabelSettings.new()
	var f := font()
	if f:
		s.font = f
	s.font_size = size
	s.font_color = color
	s.outline_size = outline
	s.outline_color = outline_color
	return s

## 把一整棵 2D 介面（沒有用 LabelSettings 的字）都換成共用字型
static func apply_theme(root: Control) -> void:
	var f := font()
	if f == null:
		return
	var t := Theme.new()
	t.default_font = f
	root.theme = t

static func font() -> Font:
	if _font == null and ResourceLoader.exists(FONT_PATH):
		_font = load(FONT_PATH)
	return _font

## 2D 控制項換字型
static func use_font(c: Control, size := -1, color := INK) -> void:
	var f := font()
	if f:
		c.add_theme_font_override("font", f)
	if size > 0:
		c.add_theme_font_size_override("font_size", size)
	c.add_theme_color_override("font_color", color)

static func _box(bg: Color, edge: Color, radius := 10, border := 3, shadow := true) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = edge
	s.set_border_width_all(border)
	s.border_width_bottom = border + 2
	s.set_corner_radius_all(radius)
	if shadow:
		s.shadow_color = Color(0, 0, 0, 0.28)
		s.shadow_size = 6
		s.shadow_offset = Vector2(3, 5)
	s.content_margin_left = 22
	s.content_margin_right = 22
	s.content_margin_top = 14
	s.content_margin_bottom = 16
	return s

## 筆記紙：米白底、淡藍橫線、紅色邊線、上方紙膠帶，微微歪一點
static func paper(panel: Control, tilt := -0.012) -> void:
	var s := _box(PAPER, PAPER_EDGE, 4, 2)
	s.content_margin_left = 46   # 文字從紅色邊線右邊開始（邊線在 x=24）
	panel.add_theme_stylebox_override("panel", s)
	panel.rotation = tilt
	var deco := _Ruled.new()
	deco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	deco.show_behind_parent = false
	panel.add_child(deco)
	panel.move_child(deco, 0)
	deco.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tape(panel)

## 便利貼：黃色、反方向歪一點
static func sticky(panel: Control, tilt := 0.015) -> void:
	var s := _box(STICKY, STICKY_EDGE, 3, 2)
	panel.add_theme_stylebox_override("panel", s)
	panel.rotation = tilt
	_tape(panel)

static func _tape(panel: Control) -> void:
	# 容器會把直接子節點拉滿：膠帶放在一個不會被拉伸的子節點（_Deco）裡面
	var holder: Control = null
	for c in panel.get_children():
		if c is _Ruled or (c is Control and c.name == "Deco"):
			holder = c
	if holder == null:
		holder = Control.new()
		holder.name = "Deco"
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(holder)
		panel.move_child(holder, 0)
	var t := ColorRect.new()
	t.color = TAPE
	t.size = Vector2(86, 22)
	t.position = Vector2(26, -11)
	t.rotation = -0.06
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(t)

## 紅色緞帶（大標題）
static func ribbon(l: Label) -> void:
	var s := _box(accent(), accent_edge(), 14, 4)
	s.content_margin_left = 34
	s.content_margin_right = 34
	s.content_margin_top = 6
	s.content_margin_bottom = 10
	l.add_theme_stylebox_override("normal", s)
	use_font(l, -1, Color(1, 0.97, 0.88))
	l.add_theme_color_override("font_outline_color", accent_edge())
	if l.label_settings:
		var ls2 := l.label_settings.duplicate() as LabelSettings
		ls2.font = font()
		ls2.font_color = Color(1, 0.97, 0.88)
		ls2.outline_color = accent_edge()
		ls2.outline_size = 8
		l.label_settings = ls2
	l.add_theme_constant_override("outline_size", 10)

## 圓角膠囊（字卡、提示列）
static func pill(l: Label, bg := Color(1, 0.98, 0.93, 0.95), edge := INK, color := INK) -> void:
	var s := _box(bg, edge, 22, 3)
	s.content_margin_top = 6
	s.content_margin_bottom = 8
	l.add_theme_stylebox_override("normal", s)
	use_font(l, -1, color)
	l.add_theme_constant_override("outline_size", 0)
	if l.label_settings:
		var ls2 := l.label_settings.duplicate() as LabelSettings
		ls2.font = font()
		ls2.font_color = color
		ls2.outline_size = 0
		l.label_settings = ls2

# ---------------------------------------------------------------- 3D 字的底板

const KINDS := {
	"bubble": {"bg": Color(1, 1, 1, 0.97), "edge": INK, "text": INK, "radius": 26, "tail": true},
	"wood": {"bg": WOOD, "edge": WOOD_EDGE, "text": Color(1, 0.95, 0.82), "radius": 10, "tail": false},
	"ice": {"bg": ICE, "edge": ICE_EDGE, "text": Color("163a5c"), "radius": 18, "tail": false},
	"red": {"bg": RIBBON, "edge": RIBBON_EDGE, "text": Color(1, 0.97, 0.88), "radius": 16, "tail": false},
	"yellow": {"bg": STICKY, "edge": Color("98802f"), "text": INK, "radius": 16, "tail": false},
}

## 底板樣式（"red"／"ice" 跟著主題色換）
static func _kind(kind: String) -> Dictionary:
	var k: Dictionary = KINDS.get(kind, KINDS.bubble).duplicate()
	if kind == "red":
		k.bg = accent()
		k.edge = accent_edge()
	elif kind == "ice":
		k.bg = THEMES[theme_name].tag
		k.edge = THEMES[theme_name].tag_edge
	return k

## 幫 3D 字加底板（Sprite3D 子節點，跟字一樣的大小規則）。之後文字變了要呼叫 refresh()
static func plate(l: Label3D, kind: String) -> void:
	var k: Dictionary = _kind(kind)
	var f := font()
	if f:
		l.font = f
	l.modulate = k.text
	l.outline_size = 0
	l.render_priority = 3
	l.set_meta("plate_kind", kind)
	var sp := Sprite3D.new()
	sp.name = "Plate"
	sp.billboard = l.billboard
	sp.no_depth_test = l.no_depth_test
	sp.fixed_size = l.fixed_size
	sp.pixel_size = l.pixel_size
	sp.render_priority = 2
	sp.shaded = false
	sp.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	sp.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	l.add_child(sp)
	refresh(l)

## 依文字大小重畫（文字沒變就不動）
static func refresh(l: Label3D) -> void:
	if not l.has_meta("plate_kind"):
		return
	var sp := l.get_node_or_null("Plate") as Sprite3D
	if sp == null:
		return
	sp.visible = l.visible and l.text != ""
	var key := "%s|%d|%s" % [l.text, l.font_size, l.get_meta("plate_kind")]
	if l.get_meta("plate_key", "") == key:
		return
	l.set_meta("plate_key", key)
	var f: Font = l.font if l.font else font()
	var sz := Vector2(l.font_size * 4, l.font_size)
	if f:
		sz = f.get_multiline_string_size(l.text, HORIZONTAL_ALIGNMENT_CENTER, -1, l.font_size)
	var k: Dictionary = _kind(l.get_meta("plate_kind"))
	var pad := Vector2(l.font_size * 0.7, l.font_size * 0.45)
	var w := int(ceil((sz.x + pad.x * 2.0) / 16.0) * 16)
	var h := int(ceil((sz.y + pad.y * 2.0) / 8.0) * 8)
	var tail: bool = k.tail
	sp.texture = _plate_tex(w, h, k.bg, k.edge, int(k.radius), tail)
	# 尾巴在底下：整張圖往下偏，讓圓角框剛好包住字
	sp.centered = true
	if tail:
		sp.offset = Vector2(0, -float(h) * 0.2)

## 畫一張圓角框（可加對話框尾巴）的貼圖，同樣大小重複使用
static func _plate_tex(w: int, h: int, bg: Color, edge: Color, radius: int, tail: bool) -> ImageTexture:
	var key := "%d,%d,%s,%s,%d,%s" % [w, h, bg.to_html(), edge.to_html(), radius, tail]
	if _tex_cache.has(key):
		return _tex_cache[key]
	var th := int(h * 0.4) if tail else 0
	var img := Image.create(w, h + th, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var bw := 4.0
	var r := float(mini(radius, h / 2))
	for y in h + th:
		for x in w:
			var px := float(x) + 0.5
			var py := float(y) + 0.5
			var d: float
			if py <= h:
				# 圓角矩形的有號距離（負的在裡面）
				var qx := absf(px - w * 0.5) - (w * 0.5 - r)
				var qy := absf(py - h * 0.5) - (h * 0.5 - r)
				d = Vector2(maxf(qx, 0.0), maxf(qy, 0.0)).length() + minf(maxf(qx, qy), 0.0) - r
			else:
				d = 1e9
			if tail:
				# 尾巴：底邊中間往下的三角形
				var ty := (py - (h - bw)) / float(th)
				if ty >= 0.0 and ty <= 1.0:
					var half := (1.0 - ty) * h * 0.28
					var cx := w * 0.42 + ty * w * 0.06
					var dt := absf(px - cx) - half
					d = minf(d, maxf(dt, py - (h + th - 2)))
			if d > 1.0:
				continue
			var a := clampf(1.0 - d, 0.0, 1.0)
			var c := edge if d > -bw else bg
			if d > -bw and d < -bw + 1.0:
				c = edge.lerp(bg, clampf(-(d + bw - 1.0), 0.0, 1.0))
			img.set_pixel(x, y, Color(c.r, c.g, c.b, c.a * a))
	var tex := ImageTexture.create_from_image(img)
	_tex_cache[key] = tex
	return tex

## 筆記紙的橫線和紅色邊線
class _Ruled:
	extends Control
	func _draw() -> void:
		# 只畫左邊的紅色邊線（橫線會穿過字，拿掉比較乾淨）
		draw_line(Vector2(24, 4), Vector2(24, size.y - 4), MARGIN, 2.0)
	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			queue_redraw()
