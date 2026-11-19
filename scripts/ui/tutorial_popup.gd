extends CanvasLayer
## 教學彈窗（所有大關共用；按 H 打開）：畫面變暗、中間一張卡片，左邊示範動畫（或道具圖示），右邊標題和說明。
## 從要塞大關（levels/fort/tutorial_popup.gd）的版本搬過來，改成可以指定影格表資料夾、沒有動畫時改顯示道具圖示。
## 開著的時候整個遊戲暫停；A/D 或 ←/→ 換頁，空白/Enter/左鍵 下一頁，Esc 或 ✕ 關掉。
## 頁面格式：{title, body, keys: [[鍵或 "LMB", 說明], ...], clip: 影格表檔名, icon: Texture2D, controls: [[鍵, 說明], ...]}
## 示範動畫是一張「影格表」圖（<clip_dir>/<clip>.jpg），每格 FW×FH、一列 COLS 格，由左到右、由上到下播放。
## 外觀用全遊戲共用的「手帳」風格（scripts/ui/ui_style.gd）：筆記紙卡片、鍵帽、滑鼠圖示。

signal closed

const UIStyle := preload("res://scripts/ui/ui_style.gd")

const FW := 480
const FH := 270
const COLS := 6
const FPS := 10.0
const HOLD := 0.8          # 播完停在最後一格一下再重播
const CLIP_SIZE := Vector2(640, 360)

var pages: Array = []      # [{title, body, keys: [[鍵或 "LMB", 說明], ...], clip}]；有 controls 的頁面左邊改放操作表
var page := -1             # -1 = 沒開
var clip_dir := ""         # 影格表放哪個資料夾（例如 "res://levels/forest/assets/tutorial"）；空字串 = 沒有動畫
var kicker_text := "教學"
var hotkey_h := false      # true：關著的時候按 H 自己打開（戰局用）
var can_open: Callable     # 回傳 false 時不接 H（例如暫停選單開著）

var _card: PanelContainer
var _clip: TextureRect
var _atlas := AtlasTexture.new()
var _frames := 0
var _clip_t := 0.0
var _no_clip: Label
var _icon: TextureRect     # 沒有動畫時改放道具圖示
var _icon_bg: PanelContainer
var _slot_holder: CenterContainer   # 道具沒有圖檔時：放一格放大的技能欄（用技能欄自己畫的圖示）
var _controls: PanelContainer   # 「操作方式」那一頁：左邊放一張鍵帽表，取代示範動畫
var _kicker: Label
var _title: Label
var _body: Label
var _keys: HBoxContainer
var _dots: HBoxContainer
var _next_btn: Button
var _prev_btn: Button
var _open_t := 0.0
var _sheets := {}

func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build()

func is_open() -> bool:
	return page >= 0

func open(at := 0) -> void:
	if pages.is_empty():
		return
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	visible = true
	_open_t = 0.0
	_show_page(clampi(at, 0, pages.size() - 1))

func close() -> void:
	if page < 0:
		return
	page = -1
	visible = false
	get_tree().paused = false
	closed.emit()

func _show_page(i: int) -> void:
	page = i
	var p: Dictionary = pages[i]
	_kicker.text = "%s　%d / %d" % [kicker_text, i + 1, pages.size()]
	_title.text = p.title
	_body.text = p.body
	for c in _keys.get_children():
		c.free()
	for k in p.get("keys", []):
		var key: String = k[0]
		_keys.add_child(UIStyle.mouse_hint("left", k[1], 16) if key == "LMB" else UIStyle.key_hint(key, k[1], 16))
	var tex: Texture2D = _sheet(p.get("clip", ""))
	var ctl: Array = p.get("controls", [])
	_clip_t = 0.0
	_controls.visible = not ctl.is_empty()
	if not ctl.is_empty():
		for c in _controls.get_children():
			c.free()
		var grid := _control_grid(ctl)
		_controls.add_child(grid)
	var icon: Texture2D = p.get("icon", null)
	var item = p.get("item", null)
	for c in _slot_holder.get_children():
		c.free()
	var use_slot: bool = tex == null and ctl.is_empty() and icon == null and item != null
	if use_slot:
		var hb = preload("res://scripts/ui/hotbar.gd").new()
		UIStyle.apply_theme(hb)
		hb.skills = [item]
		hb.counts = [item.charges_for(false) if item.has_method("charges_for") else -1]   # 徽章顯示準備階段能用幾次
		hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var holder := Control.new()
		holder.custom_minimum_size = hb.bar_size() * 3.0
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hb.scale = Vector2.ONE * 3.0
		hb.size = hb.bar_size()
		holder.add_child(hb)
		_slot_holder.add_child(holder)
	_slot_holder.visible = use_slot
	_icon.texture = icon
	_icon.visible = tex == null and ctl.is_empty() and icon != null
	_no_clip.visible = tex == null and ctl.is_empty() and icon == null and not use_slot
	# 直接設：_icon 一開始就是 visible，第一頁設成 true 不會觸發 visibility_changed，米色底板就不會出現
	_icon_bg.visible = _icon.visible or use_slot
	_clip.visible = tex != null and ctl.is_empty()
	if tex:
		_atlas.atlas = tex
		_frames = COLS * int(tex.get_height() / FH)
		_set_frame(0)
	for k in _dots.get_child_count():
		var d := _dots.get_child(k) as ColorRect
		d.color = UIStyle.accent() if k == i else Color(UIStyle.INK, 0.2)
		d.custom_minimum_size = Vector2(26 if k == i else 10, 10)
	_prev_btn.disabled = i == 0
	_next_btn.text = "開始吧 ▶" if i == pages.size() - 1 else "下一頁 ▶"

func _sheet(clip: String) -> Texture2D:
	if clip == "" or clip_dir == "":
		return null
	if not _sheets.has(clip):
		var path := clip_dir.path_join(clip + ".jpg")
		var tex: Texture2D = null
		if ResourceLoader.exists(path):
			tex = load(path)
		elif FileAccess.file_exists(path):
			# 剛錄好、編輯器還沒匯入的影格表：直接讀檔
			var img := Image.load_from_file(ProjectSettings.globalize_path(path))
			if img:
				tex = ImageTexture.create_from_image(img)
		_sheets[clip] = tex
	return _sheets[clip]

func _set_frame(n: int) -> void:
	_atlas.region = Rect2((n % COLS) * FW, (n / COLS) * FH, FW, FH)

func _process(dt: float) -> void:
	if page < 0:
		return
	# 進場：卡片從稍小、透明長到正常大小
	_open_t += dt
	var k := clampf(_open_t / 0.22, 0.0, 1.0)
	var e := 1.0 - pow(1.0 - k, 3.0)
	_card.pivot_offset = _card.size * 0.5
	_card.scale = Vector2.ONE * lerpf(0.94, 1.0, e)
	_card.modulate.a = e
	if _frames > 0 and _clip.visible:
		_clip_t += dt
		var total := _frames / FPS + HOLD
		if _clip_t >= total:
			_clip_t = fmod(_clip_t, total)
		_set_frame(mini(int(_clip_t * FPS), _frames - 1))

func _next() -> void:
	if page >= pages.size() - 1:
		close()
	else:
		_show_page(page + 1)

func _prev() -> void:
	if page > 0:
		_show_page(page - 1)

func _input(event: InputEvent) -> void:
	if page < 0:
		if hotkey_h and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_H:
			if not can_open.is_valid() or can_open.call():
				open(0)
				get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_D, KEY_RIGHT, KEY_SPACE, KEY_ENTER, KEY_KP_ENTER:
				_next()
			KEY_A, KEY_LEFT:
				_prev()
			KEY_ESCAPE:
				close()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		get_viewport().set_input_as_handled()   # 暫停時也別讓視角跟著轉

# ------------------------------------------------------------------ 版面

func _label(fs: int, col: Color) -> Label:
	var l := Label.new()
	var st := UIStyle.ls(fs, col)
	st.line_spacing = 6
	l.label_settings = st
	return l

## 可以點的按鈕：go = 綠色主要按鈕，否則是米色小紙片
func _btn(txt: String, fs: int, go := false) -> Button:
	var b := Button.new()
	b.text = txt
	b.focus_mode = Control.FOCUS_NONE
	UIStyle.use_font(b, fs, Color(1, 1, 1) if go else UIStyle.INK)
	for st in ["normal", "hover", "pressed", "disabled"]:
		var sb: StyleBoxFlat = UIStyle._box(UIStyle.GO, UIStyle.GO_EDGE, 18, 3, false) if go \
			else UIStyle._box(UIStyle.PAPER, UIStyle.INK, 18, 2, false)
		sb.content_margin_top = 6
		sb.content_margin_bottom = 8
		sb.content_margin_left = 18
		sb.content_margin_right = 18
		if st == "hover":
			sb.bg_color = sb.bg_color.lightened(0.08)
		elif st == "pressed":
			sb.bg_color = sb.bg_color.darkened(0.08)
			sb.border_width_bottom = sb.border_width_top
		elif st == "disabled":
			sb.bg_color = Color(sb.bg_color, 0.5)
			sb.border_color = Color(sb.border_color, 0.25)
		b.add_theme_stylebox_override(st, sb)
	b.add_theme_color_override("font_hover_color", b.get_theme_color("font_color"))
	b.add_theme_color_override("font_pressed_color", b.get_theme_color("font_color"))
	b.add_theme_color_override("font_disabled_color", Color(UIStyle.INK, 0.3))
	return b

func _build() -> void:
	# 背景只是一層均勻的暗色，不加漸層或光暈
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.04, 0.03, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_next())
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	# 卡片＝筆記紙（米白底、深色實線邊、左邊紅線、上面紙膠帶；只有一道小小的硬陰影）
	_card = PanelContainer.new()
	UIStyle.paper(_card, 0.0)
	_card.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(_card)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	_card.add_child(col)

	# 上排：小標（第幾頁）＋ 右邊 ✕
	var top := HBoxContainer.new()
	col.add_child(top)
	_kicker = _label(17, Color(UIStyle.INK, 0.6))
	_kicker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_kicker.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(_kicker)
	var x := _btn("✕", 16)
	x.pressed.connect(close)
	x.tooltip_text = "關閉（Esc）"
	top.add_child(x)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 30)
	col.add_child(row)

	# 左：示範動畫（深色實線框，跟鍵帽同一個墨色）
	var frame := PanelContainer.new()
	var fsb := StyleBoxFlat.new()
	fsb.bg_color = UIStyle.INK
	fsb.border_color = UIStyle.INK
	fsb.set_border_width_all(3)
	fsb.set_corner_radius_all(8)
	fsb.anti_aliasing = true
	frame.add_theme_stylebox_override("panel", fsb)
	frame.custom_minimum_size = CLIP_SIZE + Vector2(6, 6)
	frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(frame)
	_clip = TextureRect.new()
	_clip.texture = _atlas
	_clip.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_clip.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_clip.custom_minimum_size = CLIP_SIZE
	frame.add_child(_clip)
	_no_clip = _label(18, Color(1, 1, 1, 0.5))
	_no_clip.text = "（沒有示範動畫）"
	_no_clip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_no_clip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	frame.add_child(_no_clip)
	# 沒有示範動畫時：米色底上放一個大大的道具圖示
	var icon_bg := PanelContainer.new()
	var isb := StyleBoxFlat.new()
	isb.bg_color = Color("f6ecd4")
	icon_bg.add_theme_stylebox_override("panel", isb)
	icon_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(icon_bg)
	_icon_bg = icon_bg
	_icon = TextureRect.new()
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_icon.custom_minimum_size = Vector2(220, 220)
	_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon_bg.add_child(_icon)
	_icon.visibility_changed.connect(func(): icon_bg.visible = _icon.visible or _slot_holder.visible)
	icon_bg.visible = false
	_slot_holder = CenterContainer.new()
	_slot_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_slot_holder.visible = false
	_slot_holder.visibility_changed.connect(func(): icon_bg.visible = _icon.visible or _slot_holder.visible)
	frame.add_child(_slot_holder)
	_controls = PanelContainer.new()
	var csb := StyleBoxFlat.new()
	csb.bg_color = Color("f6ecd4")
	csb.set_content_margin_all(26)
	_controls.add_theme_stylebox_override("panel", csb)
	_controls.visible = false
	frame.add_child(_controls)

	# 右：標題、分隔線、說明、操作（鍵帽／滑鼠圖示）
	var info := VBoxContainer.new()
	info.custom_minimum_size = Vector2(330, 0)
	info.add_theme_constant_override("separation", 12)
	row.add_child(info)
	_title = _label(38, UIStyle.accent())
	info.add_child(_title)
	var line := ColorRect.new()
	line.color = Color(UIStyle.INK, 0.25)
	line.custom_minimum_size = Vector2(0, 2)
	info.add_child(line)
	_body = _label(21, UIStyle.INK)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size = Vector2(330, 0)
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	info.add_child(_body)
	_keys = HBoxContainer.new()
	_keys.add_theme_constant_override("separation", 22)
	info.add_child(_keys)

	# 下排：◀ 上一頁｜頁點｜按鍵提示｜下一頁 ▶
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 16)
	col.add_child(bottom)
	_prev_btn = _btn("◀ 上一頁", 18)
	_prev_btn.pressed.connect(_prev)
	bottom.add_child(_prev_btn)
	var mid := CenterContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(mid)
	_dots = HBoxContainer.new()
	_dots.add_theme_constant_override("separation", 8)
	_dots.alignment = BoxContainer.ALIGNMENT_CENTER
	mid.add_child(_dots)
	var hints := HBoxContainer.new()
	hints.add_theme_constant_override("separation", 16)
	hints.modulate.a = 0.75
	hints.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(hints)
	hints.add_child(UIStyle.key_hint("A／D", "換頁", 13))
	hints.add_child(UIStyle.key_hint("Space", "繼續", 13))
	hints.add_child(UIStyle.key_hint("Esc", "跳過", 13))
	_next_btn = _btn("下一頁 ▶", 18, true)
	_next_btn.pressed.connect(_next)
	bottom.add_child(_next_btn)

## 操作表：兩欄，每列「鍵帽或滑鼠圖示（靠右）＋說明」。MOUSE = 移動滑鼠，LMB = 左鍵
func _control_grid(rows: Array) -> GridContainer:
	var g := GridContainer.new()
	g.columns = 4
	g.add_theme_constant_override("h_separation", 14)
	g.add_theme_constant_override("v_separation", 16)
	g.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	g.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var half := ceili(rows.size() / 2.0)
	for r in half:
		for side in 2:
			var i := r + side * half
			if i >= rows.size():
				g.add_child(Control.new())
				g.add_child(Control.new())
				continue
			var key: String = rows[i][0]
			var icon: Control
			if key == "LMB":
				icon = UIStyle.mouse_hint("left", "", 18)
			elif key == "MOUSE":
				icon = UIStyle.mouse_hint("none", "", 18)
			else:
				icon = UIStyle.key_hint(key, "", 18)
			icon.alignment = BoxContainer.ALIGNMENT_END
			icon.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			g.add_child(icon)
			var t := _label(20, UIStyle.INK)
			t.text = rows[i][1]
			t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			t.custom_minimum_size = Vector2(150 if side == 0 else 0, 0)
			g.add_child(t)
	return g

func set_pages(p: Array) -> void:
	pages = p
	for c in _dots.get_children():
		c.free()
	for k in pages.size():
		var d := ColorRect.new()
		d.custom_minimum_size = Vector2(10, 10)
		d.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_dots.add_child(d)
