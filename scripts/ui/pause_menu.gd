extends CanvasLayer
## 暫停選單（戰局中按 Esc）。所有關卡共用（template），由 battle_base.gd 建立，各關不用做任何事。
##
## 打開的時候：
##   - 整個小關場景停住：把場景根節點的 process_mode 設成「停用」，所以戰局（含各關自己覆寫的
##     _process／_physics_process）、玩家鏡頭、場地、角色動畫、音樂都不會再跑；只有這個選單自己還在動。
##     戰局是固定每 1/60 秒算一步，暫停期間一步都不會算，關掉選單後從同一步接著算，結果和沒暫停一樣。
##   - 游標放開、畫面壓暗、中間一張筆記紙：繼續（Esc）、重來（R）、回地圖（M）、操作說明（H）。
##     滑鼠可以點；也可以用 ↑↓ 選、Enter 確定。
## 關掉的時候：場景恢復原本的 process_mode、時間倍率和游標狀態。
##
## 沒有用 get_tree().paused：那是整個遊戲共用的開關，換場景時忘了關會讓下一個畫面也停住；
## 這裡只停這一個小關場景，場景被換掉就什麼都不會留下。
##
## 注意：各關如果用「真實時間」（Time.get_ticks_msec()）算特效的長度（例如慢動作、震動），
## 那些計時在暫停期間還是會走完；戰局本身不受影響。

const UIStyle := preload("res://scripts/ui/ui_style.gd")

signal opened
signal closed
## 選了會離開選單的項目："resume"（繼續）、"restart"（重來）、"map"（回地圖）。選單已經先關好了才發
signal picked(id: String)

const ITEMS := [
	{"id": "resume", "text": "繼續", "key": "Esc"},
	{"id": "restart", "text": "重來", "key": "R"},
	{"id": "map", "text": "回地圖", "key": "M"},
	{"id": "help", "text": "操作說明", "key": "H"},
]
const ROW_W := 340.0

var stage_root: Node           # 要停住的那棵樹（整個小關場景）
var player: Node               # 幽靈觀察者（scripts/player.gd）：關掉選單時把游標還給它
var help_rows: Callable        # 回傳操作說明 [[按鍵, 做什麼], ...]
var hotkey := true             # false：不接 Esc（只能用程式呼叫 open()）
var is_open := false
var selected := 0

var _root: Control
var _card: PanelContainer
var _rows: Array = []          # 每個選項的底板（PanelContainer）
var _marks: Array = []         # 每個選項前面的「▶」
var _help_box: VBoxContainer
var _help_on := false
var _was_mode := Node.PROCESS_MODE_INHERIT
var _was_scale := 1.0
var _was_looking := false
var _was_mouse := Input.MOUSE_MODE_VISIBLE

func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS   # 場景停住的時候只有選單還在動
	visible = false
	_build()

func _exit_tree() -> void:
	# 選單開著的時候場景被換掉：時間倍率要還回去（process_mode 跟著場景一起消失，不用管）
	if is_open:
		Engine.time_scale = _was_scale

# ---------------------------------------------------------------- 畫面

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	UIStyle.apply_theme(_root)
	# 壓暗的一層（順便擋住滑鼠，不會點到後面）
	var dim := ColorRect.new()
	dim.color = Color(0.10, 0.07, 0.05, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)
	# 筆記紙（和結算卡同一套）
	_card = PanelContainer.new()
	UIStyle.paper(_card, 0.0)
	var sb := _card.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	sb.content_margin_left = 54
	sb.content_margin_right = 40
	sb.content_margin_top = 28
	sb.content_margin_bottom = 24
	_card.add_theme_stylebox_override("panel", sb)
	center.add_child(_card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	_card.add_child(v)
	var title := Label.new()
	title.text = "暫停"
	title.label_settings = UIStyle.ls(40, UIStyle.INK)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 4)
	v.add_child(gap)
	for i in ITEMS.size():
		v.add_child(_make_row(i))
	# 操作說明：選了「操作說明」才在卡片裡展開
	_help_box = VBoxContainer.new()
	_help_box.add_theme_constant_override("separation", 8)
	_help_box.visible = false
	v.add_child(_help_box)
	# 最下面一行小字：怎麼選
	var foot := HBoxContainer.new()
	foot.alignment = BoxContainer.ALIGNMENT_CENTER
	foot.add_theme_constant_override("separation", 20)
	foot.modulate.a = 0.75
	foot.add_child(UIStyle.key_hint("↑／↓", "選", 13))
	foot.add_child(UIStyle.key_hint("Enter", "確定", 13))
	var gap2 := Control.new()
	gap2.custom_minimum_size = Vector2(0, 2)
	v.add_child(gap2)
	v.add_child(foot)
	_refresh()

## 一個選項：整條是按鈕（滑鼠移上去就選到、按下去就執行），左邊是字、右邊是鍵帽
func _make_row(i: int) -> Control:
	var it: Dictionary = ITEMS[i]
	var row := PanelContainer.new()
	row.custom_minimum_size = Vector2(ROW_W, 54)
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(h)
	var mark := Label.new()
	mark.text = "▶"
	mark.label_settings = UIStyle.ls(18, UIStyle.accent())
	mark.custom_minimum_size = Vector2(22, 0)
	mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(mark)
	var t := Label.new()
	t.text = String(it.text)
	t.label_settings = UIStyle.ls(26, UIStyle.INK)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(t)
	h.add_child(UIStyle.keycap(String(it.key), 18))
	row.mouse_entered.connect(func(): select(i))
	row.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			row.accept_event()
			select(i)
			activate(i))
	_rows.append(row)
	_marks.append(mark)
	return row

func _row_box(on: bool) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = UIStyle.STICKY if on else Color("f6ecd2")
	s.border_color = UIStyle.INK if on else UIStyle.PAPER_EDGE
	s.set_border_width_all(3 if on else 2)
	s.border_width_bottom = 6 if on else 4
	s.set_corner_radius_all(12)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 6
	s.content_margin_bottom = 8
	s.anti_aliasing = true
	return s

func _refresh() -> void:
	for i in _rows.size():
		var on := i == selected
		(_rows[i] as PanelContainer).add_theme_stylebox_override("panel", _row_box(on))
		(_marks[i] as Label).modulate.a = 1.0 if on else 0.0

# ---------------------------------------------------------------- 開關

func open() -> void:
	if is_open:
		return
	is_open = true
	selected = 0
	_set_help(false)
	_refresh()
	# 停住整個小關場景（這個選單自己是 PROCESS_MODE_ALWAYS，不受影響）
	_was_scale = Engine.time_scale
	Engine.time_scale = 1.0
	if stage_root:
		_was_mode = stage_root.process_mode
		stage_root.process_mode = Node.PROCESS_MODE_DISABLED
	# 放開游標；記住原本是不是在轉視角，關掉時還回去
	_was_mouse = Input.mouse_mode
	_was_looking = player != null and player.get("looking") == true
	if player and player.has_method("_set_looking"):
		player.call("_set_looking", false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	visible = true
	_root.modulate.a = 0.0
	create_tween().tween_property(_root, "modulate:a", 1.0, 0.12)
	opened.emit()

## 關掉選單、戰局接著跑。keep_cursor：游標維持放開（要離開這一關的時候用）
func close(keep_cursor := false) -> void:
	if not is_open:
		return
	is_open = false
	visible = false
	if stage_root:
		stage_root.process_mode = _was_mode
	Engine.time_scale = _was_scale
	if not keep_cursor:
		if player and player.has_method("_set_looking"):
			player.call("_set_looking", _was_looking)
		else:
			Input.mouse_mode = _was_mouse
	closed.emit()

func toggle() -> void:
	if is_open:
		close()
	else:
		open()

# ---------------------------------------------------------------- 選項

func select(i: int) -> void:
	selected = clampi(i, 0, ITEMS.size() - 1)
	_refresh()

func activate(i: int) -> void:
	if i < 0 or i >= ITEMS.size():
		return
	var id := String(ITEMS[i].id)
	match id:
		"help":
			toggle_help()
		"resume":
			close()
			picked.emit(id)
		_:
			close(id == "map")
			picked.emit(id)

func _activate_id(id: String) -> void:
	for i in ITEMS.size():
		if String(ITEMS[i].id) == id:
			select(i)
			activate(i)
			return

func toggle_help() -> void:
	_set_help(not _help_on)

func _set_help(on: bool) -> void:
	_help_on = on
	if _help_box == null:
		return
	for c in _help_box.get_children():
		_help_box.remove_child(c)
		c.queue_free()
	if on:
		var rule := ColorRect.new()
		rule.color = UIStyle.PAPER_EDGE
		rule.custom_minimum_size = Vector2(0, 2)
		_help_box.add_child(rule)
		var rows: Array = help_rows.call() if help_rows.is_valid() else []
		_help_box.add_child(UIStyle.key_grid(rows, 2, 15))
	_help_box.visible = on

# ---------------------------------------------------------------- 鍵盤

static func _key_of(e: InputEventKey) -> Key:
	return e.physical_keycode if e.physical_keycode != KEY_NONE else e.keycode

func _input(event: InputEvent) -> void:
	if not is_open:
		# 還沒開：Esc 打開選單（用 _input，比玩家和戰局的 _unhandled_input 早拿到，Esc 不會再被別人處理一次）
		if hotkey and event is InputEventKey and event.pressed and not event.echo and _key_of(event) == KEY_ESCAPE:
			open()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventKey:
		var vp := get_viewport()   # 先拿好：選了「回地圖」之後這個節點就不在場景樹上了
		if event.pressed and not event.echo:
			match _key_of(event):
				KEY_ESCAPE:
					_activate_id("resume")
				KEY_UP, KEY_W:
					select((selected - 1 + ITEMS.size()) % ITEMS.size())
				KEY_DOWN, KEY_S:
					select((selected + 1) % ITEMS.size())
				KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
					activate(selected)
				KEY_R:
					_activate_id("restart")
				KEY_M:
					_activate_id("map")
				KEY_H:
					_activate_id("help")
		# 選單開著的時候，鍵盤不會漏到別的地方
		if vp:
			vp.set_input_as_handled()
