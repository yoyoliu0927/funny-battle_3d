extends CanvasLayer
## 暫停選單（戰局中按 Esc 或 P）。所有關卡共用（template），由 battle_base.gd 建立，各關不用做任何事。
##
## 打開的時候：
##   - 整個小關場景停住：把場景根節點的 process_mode 設成「停用」，所以戰局（含各關自己覆寫的
##     _process／_physics_process）、玩家鏡頭、場地、角色動畫、音樂都不會再跑；只有這個選單自己還在動。
##     戰局是固定每 1/60 秒算一步，暫停期間一步都不會算，關掉選單後從同一步接著算，結果和沒暫停一樣。
##   - 游標放開、畫面壓暗、中間一張筆記紙：繼續（Esc／P）、重來（R）、回地圖（M）、聲音開關（V）、操作說明（H）。
##     聲音開關關掉的是整個遊戲的聲音（Master），跟選關畫面右上角的喇叭是同一個設定（存在 user://settings.cfg）。
##     滑鼠可以點；也可以用 ↑↓ 選、Enter 確定。
## 關掉的時候：場景恢復原本的 process_mode、時間倍率和游標狀態。
##
## 網頁版（itch.io）：瀏覽器把 Esc 留給「離開全螢幕／放開滑鼠」，這一下 Esc 不會傳進遊戲。所以：
##   - 畫面上的暫停鍵寫 P（P 在全螢幕裡也按得到，不會縮小）；Esc 還是能用。
##   - 視窗突然變小（離開全螢幕）、或瀏覽器自己把鎖住的滑鼠放開（按了 Esc、切到別的分頁），就自動打開這個選單，
##     玩家按 Esc 的感覺還是「暫停」，只是畫面同時縮小。
##   - 不是全螢幕的時候，選單多一列「全螢幕」（F），點一下回到全螢幕，不用去找 itch.io 頁面下面的小按鈕。
##   - make_button() 給戰局右上角一顆圓的暫停按鈕（滑鼠點得到的時候用）。
##   用 --webui 啟動可以在電腦版看到網頁版的畫面（按鍵寫 P、有「全螢幕」那一列），方便截圖檢查。
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
	{"id": "fullscreen", "text": "全螢幕", "key": "F"},
	{"id": "restart", "text": "重來", "key": "R"},
	{"id": "map", "text": "回地圖", "key": "M"},
	{"id": "sound", "text": "聲音", "key": "V"},
	{"id": "help", "text": "操作說明", "key": "H"},
]
const ROW_W := 340.0
## 自動打開之後這段時間內的 Esc 不算「繼續」（有的瀏覽器放開滑鼠之後還會把那一下 Esc 送進來）
const ESC_GRACE_MS := 400

var stage_root: Node           # 要停住的那棵樹（整個小關場景）
var player: Node               # 幽靈觀察者（scripts/player.gd）：關掉選單時把游標還給它
var help_rows: Callable        # 回傳操作說明 [[按鍵, 做什麼], ...]
var hotkey := true             # false：不接 Esc／P，網頁版也不自動打開（只能用程式呼叫 open()）
var is_open := false
var selected := 0

var _root: Control
var _card: PanelContainer
var _rows: Array = []          # 每個選項的底板（PanelContainer）
var _marks: Array = []         # 每個選項前面的「▶」
var _texts: Array = []         # 每個選項的字（Label）
var _help_box: VBoxContainer
var _help_on := false
var _was_mode := Node.PROCESS_MODE_INHERIT
var _was_scale := 1.0
var _was_looking := false
var _was_mouse := Input.MOUSE_MODE_VISIBLE

# 網頁版用
var _js: Object = null         # 瀏覽器那邊記錄「滑鼠被放開幾次」的小物件（window.__fbPause）
var _lost_seen := 0
var _err_seen := 0
var _last_win := Vector2i.ZERO
var _auto_at := -100000        # 上一次自動打開的時間（毫秒）
var _web := false              # web_ui() 的結果（每一格都要看，先記起來）

## 網頁版（或用 --webui 假裝網頁版）
static func web_ui() -> bool:
	return OS.has_feature("web") or "--webui" in OS.get_cmdline_user_args()

## 畫面上要寫的暫停鍵：網頁版寫 P（Esc 會被瀏覽器拿去離開全螢幕），電腦版寫 Esc
static func pause_key() -> String:
	return "P" if web_ui() else "Esc"

func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS   # 場景停住的時候只有選單還在動
	visible = false
	_web = web_ui()
	_build()
	_last_win = DisplayServer.window_get_size()
	if OS.has_feature("web"):
		_install_js()

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
	# 「繼續」的鍵帽：網頁版寫 P
	h.add_child(UIStyle.keycap(pause_key() if String(it.id) == "resume" else String(it.key), 18))
	row.mouse_entered.connect(func(): select(i))
	row.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			row.accept_event()
			select(i)
			activate(i))
	row.visible = _row_shown(i)
	_rows.append(row)
	_marks.append(mark)
	_texts.append(t)
	return row

## 這一列現在要不要出現：「全螢幕」只在網頁版、而且還不是全螢幕的時候出現
func _row_shown(i: int) -> bool:
	if String(ITEMS[i].id) == "fullscreen":
		return _web and not _is_fullscreen()
	return true

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
		(_rows[i] as PanelContainer).visible = _row_shown(i)
	if not _row_shown(selected):
		selected = 0
	for i in _rows.size():
		var on := i == selected
		(_rows[i] as PanelContainer).add_theme_stylebox_override("panel", _row_box(on))
		(_marks[i] as Label).modulate.a = 1.0 if on else 0.0
		if String(ITEMS[i].id) == "sound":
			(_texts[i] as Label).text = "聲音：關" if AudioServer.is_bus_mute(0) else "聲音：開"

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

## ↑↓ 移動選項：跳過沒出現的那幾列
func _step(d: int) -> void:
	var i := selected
	for _n in ITEMS.size():
		i = (i + d + ITEMS.size()) % ITEMS.size()
		if _row_shown(i):
			select(i)
			return

func activate(i: int) -> void:
	if i < 0 or i >= ITEMS.size() or not _row_shown(i):
		return
	var id := String(ITEMS[i].id)
	match id:
		"help":
			toggle_help()
		"sound":
			# 開／關整個遊戲的聲音，並記到設定檔（選單不關）
			var muted := not AudioServer.is_bus_mute(0)
			AudioServer.set_bus_mute(0, muted)
			var cf := ConfigFile.new()
			cf.load("user://settings.cfg")
			cf.set_value("audio", "muted", muted)
			cf.save("user://settings.cfg")
			_refresh()
		"fullscreen":
			# 回到全螢幕（選單不關：游標還沒鎖回去，玩家再按「繼續」就好）。
			# 瀏覽器規定全螢幕只能在玩家點擊／按鍵的時候開，這裡剛好是在點擊或按鍵裡
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
			selected = 0
			_refresh()
		"resume":
			close()
			picked.emit(id)
		_:
			close(id == "map")
			picked.emit(id)

func _activate_id(id: String) -> void:
	for i in ITEMS.size():
		if String(ITEMS[i].id) == id:
			if not _row_shown(i):
				return
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
		# 還沒開：Esc 或 P 打開選單（用 _input，比玩家和戰局的 _unhandled_input 早拿到，不會再被別人處理一次）
		if hotkey and event is InputEventKey and event.pressed and not event.echo and _key_of(event) in [KEY_ESCAPE, KEY_P]:
			open()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventKey:
		var vp := get_viewport()   # 先拿好：選了「回地圖」之後這個節點就不在場景樹上了
		if event.pressed and not event.echo:
			match _key_of(event):
				KEY_ESCAPE:
					# 剛剛才因為瀏覽器放開滑鼠而自動打開：這一下 Esc 是同一下，不要馬上又關掉
					if Time.get_ticks_msec() - _auto_at > ESC_GRACE_MS:
						_activate_id("resume")
				KEY_P:
					_activate_id("resume")
				KEY_UP, KEY_W:
					_step(-1)
				KEY_DOWN, KEY_S:
					_step(1)
				KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
					activate(selected)
				KEY_F:
					_activate_id("fullscreen")
				KEY_R:
					_activate_id("restart")
				KEY_M:
					_activate_id("map")
				KEY_V:
					_activate_id("sound")
				KEY_H:
					_activate_id("help")
		# 選單開著的時候，鍵盤不會漏到別的地方
		if vp:
			vp.set_input_as_handled()

# ---------------------------------------------------------------- 網頁版：自動暫停

## 在瀏覽器裝一個小記錄器：
##   lost：滑鼠鎖「不是遊戲自己放開」的次數（玩家按 Esc、切分頁、離開全螢幕都算）
##   err：要鎖滑鼠被瀏覽器拒絕的次數（例如玩家剛按 Esc 放開，馬上又要鎖）
## 遊戲自己放開滑鼠一律走 document.exitPointerLock()，所以包一層記下「這次是遊戲自己放的」。
func _install_js() -> void:
	JavaScriptBridge.eval("""
(function () {
	if (window.__fbPause) return;
	var st = { lost: 0, err: 0, byCode: false };
	window.__fbPause = st;
	var orig = document.exitPointerLock;
	if (orig) {
		document.exitPointerLock = function () {
			if (document.pointerLockElement) st.byCode = true;
			return orig.apply(document, arguments);
		};
	}
	document.addEventListener('pointerlockchange', function () {
		if (document.pointerLockElement) { st.byCode = false; return; }
		if (st.byCode) { st.byCode = false; return; }
		st.lost += 1;
	});
	document.addEventListener('pointerlockerror', function () { st.err += 1; });
})();
""", true)
	_js = JavaScriptBridge.get_interface("__fbPause")
	if _js:
		_lost_seen = int(_js.get("lost"))
		_err_seen = int(_js.get("err"))

## 現在是不是全螢幕。網頁版：遊戲自己開的全螢幕看 document.fullscreenElement；
## itch.io 按鈕開的全螢幕是整個 iframe 放大，遊戲那邊看不到，只能看「視窗跟螢幕一樣大」
func _is_fullscreen() -> bool:
	if OS.has_feature("web"):
		# 瀏覽器傳回來的 true／false 會變成 1／0，所以讓它直接回數字
		var r = JavaScriptBridge.eval("(document.fullscreenElement || (Math.abs(window.innerWidth - screen.width) < 4 && Math.abs(window.innerHeight - screen.height) < 4)) ? 1 : 0", true)
		return r != null and int(r) == 1
	return DisplayServer.window_get_mode() in [DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]

func _process(_dt: float) -> void:
	if not _web:
		return
	# 視窗變大變小：選單開著的話更新「全螢幕」那一列；變小（離開全螢幕）就自動暫停
	var win := DisplayServer.window_get_size()
	if win != _last_win and win.x > 0 and win.y > 0:
		var shrank := _last_win.x > 0 and (win.x < _last_win.x * 0.95 or win.y < _last_win.y * 0.95)
		_last_win = win
		if is_open:
			_refresh()
		elif shrank:
			_auto_open()
	if _js == null:
		return
	var lost := int(_js.get("lost"))
	if lost != _lost_seen:
		_lost_seen = lost
		_auto_open()
	var err := int(_js.get("err"))
	if err != _err_seen:
		_err_seen = err
		# 鎖滑鼠被拒絕：游標其實沒鎖住。讓玩家點一下畫面再鎖（scripts/player.gd 點一下會重新鎖）
		if not is_open and player and player.get("looking") == true and player.has_method("_set_looking"):
			player.call("_set_looking", false)

func _auto_open() -> void:
	if is_open or not hotkey:
		return
	open()
	_auto_at = Time.get_ticks_msec()

# ---------------------------------------------------------------- 畫面上的暫停按鈕

## 戰局右上角的圓按鈕（米色紙片＋暫停符號，下面掛暫停鍵的鍵帽）。點一下打開選單。
## 由戰局放進自己的 HUD 那一層（彈窗、結算會蓋在它上面）
func make_button() -> Control:
	var b := _PauseButton.new()
	b.menu = self
	b.key = pause_key()
	b.custom_minimum_size = _PauseButton.SIZE
	b.size = _PauseButton.SIZE
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return b

class _PauseButton extends Control:
	const SIZE := Vector2(76, 92)
	const R := 26.0
	var menu                       # 暫停選單（這個檔案）
	var key := "Esc"
	var _hover := false

	func _ready() -> void:
		mouse_entered.connect(_set_hover.bind(true))
		mouse_exited.connect(_set_hover.bind(false))

	func _set_hover(on: bool) -> void:
		_hover = on
		queue_redraw()

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			accept_event()
			if menu and not menu.is_open:
				menu.open()

	func _draw() -> void:
		var ctr := Vector2(SIZE.x * 0.5, R + 4.0)
		var bg := UIStyle.STICKY if _hover else UIStyle.PAPER
		var edge := UIStyle.STICKY_EDGE if _hover else UIStyle.PAPER_EDGE
		draw_circle(ctr + Vector2(2, 4), R + 3.0, Color(0, 0, 0, 0.25))
		draw_circle(ctr, R + 3.0, edge)
		draw_circle(ctr, R, bg)
		# 暫停符號：兩條圓角直槓
		for dx in [-6.5, 6.5]:
			var r := Rect2(ctr + Vector2(dx - 3.5, -10), Vector2(7, 20))
			draw_style_box(_bar_box(), r)
		# 下面：鍵帽＋「暫停」
		var f := UIStyle.font()
		var ks := UIStyle.keycap_size(key, 13.0)
		var label := "暫停"
		var lw := f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		var x := ctr.x - (ks.x + 4.0 + lw) * 0.5
		var y := ctr.y + R + 8.0
		UIStyle.draw_keycap(self, Vector2(x, y), key, 13.0)
		var base := Vector2(x + ks.x + 4.0, y + ks.y * 0.5 + 5.0)
		draw_string_outline(f, base, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 5, Color(1, 1, 1, 0.9))
		draw_string(f, base, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, UIStyle.INK)

	func _bar_box() -> StyleBoxFlat:
		var s := StyleBoxFlat.new()
		s.bg_color = UIStyle.INK
		s.set_corner_radius_all(3)
		s.anti_aliasing = true
		return s
