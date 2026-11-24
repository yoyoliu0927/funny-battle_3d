extends "res://scripts/ui/tutorial_popup.gd"
## 冰雪島、丹穴山按 H 的說明卡：第一頁是「這一關」的提示，後面才是道具、規則、操作。
## 版面、翻頁、暫停都沿用共用的教學彈窗（scripts/ui/tutorial_popup.gd，只繼承、不改它）；
## 多的只有「這一關」那一頁左邊的提示板：一排便利貼，從上到下越來越直白，還沒打開的那幾張蓋著。
##
## 頁面多一種：{"title", "body", "level": true}；提示板的內容每次翻到這一頁都跟戰局要一次（board），
## 所以輸了一次再按 H，就會看到剛打開的那一張。
## board 回傳 [{tag: 左邊的小標, text: 內容, open: 打開了沒, lock: 蓋著時寫什麼, fresh: 剛打開還沒看過, star: 星星的那一列}, ...]

const UIS := preload("res://scripts/ui/ui_style.gd")

var board: Callable              # 戰局給的：現在提示板上有哪幾列
var seen: Callable               # 翻到「這一關」這一頁時通知戰局（「新」的記號就收起來）
var _board: PanelContainer
var _rows: VBoxContainer

func _ready() -> void:
	super()
	kicker_text = "提示"
	var frame := _controls.get_parent()
	_board = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("f6ecd4")
	sb.content_margin_left = 26
	sb.content_margin_right = 26
	sb.content_margin_top = 22
	sb.content_margin_bottom = 22
	_board.add_theme_stylebox_override("panel", sb)
	_board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_board.visible = false
	frame.add_child(_board)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 12)
	_rows.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_board.add_child(_rows)

func _show_page(i: int) -> void:
	super(i)
	var on: bool = pages[i].get("level", false)
	_board.visible = on
	if not on:
		return
	_no_clip.visible = false
	for c in _rows.get_children():
		c.free()
	var list: Array = board.call() if board.is_valid() else []
	for r in list:
		_rows.add_child(_row(r))
	# 還有蓋著的提示：最下面一行小字說怎麼打開
	if list.any(func(r): return not r.get("open", true)):
		var note := Label.new()
		note.text = "多試幾次，蓋著的提示會一張一張打開；過關以後全部打開。"
		note.label_settings = UIS.ls(15, Color(UIS.INK, 0.5))
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_rows.add_child(note)
	if seen.is_valid():
		seen.call()

## 一列：左邊小標（怎麼玩／提示 1／提示 2／★），右邊一張便利貼；還沒打開的是蓋著的灰紙
func _row(r: Dictionary) -> Control:
	var open: bool = r.get("open", true)
	var star: bool = r.get("star", false)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tag := Label.new()
	tag.text = String(r.get("tag", ""))
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.custom_minimum_size = Vector2(92, 0)
	tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var ts := StyleBoxFlat.new()
	ts.bg_color = (Color("f6c445") if star else UIS.accent()) if open else Color(UIS.INK, 0.14)
	ts.set_corner_radius_all(14)
	ts.content_margin_left = 10
	ts.content_margin_right = 10
	ts.content_margin_top = 3
	ts.content_margin_bottom = 5
	tag.add_theme_stylebox_override("normal", ts)
	tag.label_settings = UIS.ls(17, (UIS.INK if star else Color(1, 1, 1)) if open else Color(UIS.INK, 0.45))
	h.add_child(tag)
	var note := PanelContainer.new()
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ns := StyleBoxFlat.new()
	if open:
		ns.bg_color = UIS.STICKY
		ns.border_color = UIS.STICKY_EDGE
		ns.set_border_width_all(2)
		ns.border_width_bottom = 4
	else:
		ns.bg_color = Color(UIS.INK, 0.05)
		ns.border_color = Color(UIS.INK, 0.18)
		ns.set_border_width_all(2)
	ns.set_corner_radius_all(6)
	ns.content_margin_left = 16
	ns.content_margin_right = 14
	ns.content_margin_top = 9
	ns.content_margin_bottom = 11
	note.add_theme_stylebox_override("panel", ns)
	h.add_child(note)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 8)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	note.add_child(line)
	var t := Label.new()
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var txt := String(r.get("text", "")) if open else String(r.get("lock", ""))
	# [Tab] 這種寫法畫成鍵帽，放在句子後面
	var keys: Array = []
	var re := RegEx.new()
	re.compile("\\[(\\w+)\\]")
	for m in re.search_all(txt):
		keys.append(m.get_string(1))
		txt = txt.replace(m.get_string(0), "")
	t.text = txt.strip_edges()
	var st := UIS.ls(20 if open else 17, UIS.INK if open else Color(UIS.INK, 0.5))
	st.line_spacing = 4
	t.label_settings = st
	line.add_child(t)
	for k in keys:
		var kc := UIS.keycap(String(k), 16)
		kc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(kc)
	if open and r.get("fresh", false):
		var nw := Label.new()
		nw.text = "新！"
		nw.label_settings = UIS.ls(16, UIS.RIBBON)
		nw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(nw)
	return h
