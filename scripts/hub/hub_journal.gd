extends CanvasLayer
## 冒險手帳（主島「冒險手帳」站點按 Enter 打開）：一本三頁的手帳。
##   旅程：每座島一張卡片（星星、每個小關過了沒、羽毛、通關蓋章）
##   貼紙：二十張貼紙（旅程、戳戳樂、釣魚），拿到的有顏色，沒拿到的是灰色問號，選到會顯示怎麼拿
##   魚圖鑑：池塘裡釣到過的東西（魚、垃圾、寶物），記著最大的尺寸
## 操作：← → 換頁（或 1 2 3、Tab、點上面的頁籤）、↑ ↓ 選格子（或滑鼠移上去）、Esc／Enter／點 ✕ 合上。
## 資料在 journal.gd（存檔 user://journal.cfg）；旅程的星星、羽毛從主島（level_select.gd）拿。

const Journal := preload("res://scripts/hub/journal.gd")
const Sfx := preload("res://scripts/hub/hub_sfx.gd")
const HubUI := preload("res://scripts/hub/hub_ui.gd")
const UIStyle := preload("res://scripts/ui/ui_style.gd")

const TABS := ["旅程", "貼紙", "魚圖鑑"]
const PANEL := Vector2(1240, 840)

var map                          # 選關畫面（level_select.gd）
var tab := 0
var sel := 0
var _shown := false
var _t := 0.0
var _ctx := {}
var _ui: HubUI.Canvas
var _tab_rects: Array = []
var _cell_rects: Array = []
var _scroll := 0              # 貼紙頁：從第幾列開始顯示（貼紙多的時候上下捲）
var _close_rect := Rect2()
var _snd := {}

func _ready() -> void:
	layer = 12
	visible = false
	_snd = Sfx.attach(self, -5.0)
	_ui = HubUI.Canvas.new()
	_ui.painter = _paint
	_ui.on_move = _hover
	_ui.on_click = _click
	_ui.mouse_filter = Control.MOUSE_FILTER_STOP
	_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_ui)

func is_open() -> bool:
	return _shown

func open(at_tab := 0) -> void:
	if _shown:
		return
	_shown = true
	_t = 0.0
	tab = clampi(at_tab, 0, TABS.size() - 1)
	sel = 0
	visible = true
	_ctx = map._journal_ctx()
	_snd.page.play()
	_ui.queue_redraw()

func close() -> void:
	if not _shown:
		return
	_shown = false
	visible = false
	_snd.page.play()

func chime() -> void:
	var p: AudioStreamPlayer = _snd.get("sticker")
	if p:
		p.play()

func set_tab(i: int) -> void:
	i = posmod(i, TABS.size())
	if i != tab:
		tab = i
		sel = 0
		_snd.page.play()

func _count() -> int:
	match tab:
		1:
			return Journal.stickers(_ctx).size()
		2:
			return Journal.FISH.size()
	return 0

func _process(dt: float) -> void:
	if _shown:
		_t += dt
		_ui.queue_redraw()

# ---------------------------------------------------------------- 輸入

func _unhandled_input(ev: InputEvent) -> void:
	if not _shown:
		return
	if ev is InputEventKey and ev.pressed and not ev.echo:
		match ev.keycode:
			KEY_ESCAPE, KEY_ENTER, KEY_KP_ENTER, KEY_BACKSPACE:
				close()
			KEY_LEFT, KEY_A:
				set_tab(tab - 1)
			KEY_RIGHT, KEY_D, KEY_TAB:
				set_tab(tab + 1)
			KEY_1, KEY_2, KEY_3:
				set_tab(ev.keycode - KEY_1)
			KEY_UP, KEY_W:
				if _count() > 0:
					sel = posmod(sel - 1, _count())
			KEY_DOWN, KEY_S:
				if _count() > 0:
					sel = posmod(sel + 1, _count())
			KEY_V:
				return
		get_viewport().set_input_as_handled()
	elif ev is InputEventMouseButton:
		if ev.pressed and tab == 1 and (ev.button_index == MOUSE_BUTTON_WHEEL_UP or ev.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			var step := -5 if ev.button_index == MOUSE_BUTTON_WHEEL_UP else 5       # 滾輪：一次一列（一列 5 張）
			sel = clampi(sel + step, 0, maxi(_count() - 1, 0))
		get_viewport().set_input_as_handled()

func _hover(pos: Vector2) -> void:
	for i in _cell_rects.size():
		if (_cell_rects[i] as Rect2).has_point(pos):
			sel = i
			return

func _click(pos: Vector2) -> void:
	if _close_rect.has_point(pos):
		close()
		return
	for i in _tab_rects.size():
		if (_tab_rects[i] as Rect2).has_point(pos):
			set_tab(i)
			return
	for i in _cell_rects.size():
		if (_cell_rects[i] as Rect2).has_point(pos):
			sel = i
			return

# ---------------------------------------------------------------- 畫面

func _paint(c: Control) -> void:
	if not _shown:
		return
	var vs := c.size
	var u := HubUI.scale_of(vs)
	var k := clampf(_t / 0.22, 0.0, 1.0)
	var pop := 1.0 - pow(1.0 - k, 3.0)
	c.draw_rect(Rect2(Vector2.ZERO, vs), Color(0.1, 0.07, 0.05, 0.5 * pop))
	var uu := u * (0.94 + 0.06 * pop)
	var r := Rect2(vs * 0.5 - PANEL * uu * 0.5 + Vector2(0, 8 * uu), PANEL * uu)
	c.draw_style_box(HubUI.box(HubUI.PAPER, HubUI.PAPER_EDGE, 34 * uu, 4.0), r)
	# 筆記本的橫線和左邊的紅線
	var y := r.position.y + 190 * uu
	while y < r.end.y - 40 * uu:
		c.draw_line(Vector2(r.position.x + 30 * uu, y), Vector2(r.end.x - 30 * uu, y), UIStyle.RULE, 2.0, true)
		y += 46 * uu
	c.draw_line(Vector2(r.position.x + 58 * uu, r.position.y + 40 * uu), Vector2(r.position.x + 58 * uu, r.end.y - 30 * uu), UIStyle.MARGIN, 2.5, true)
	# 標題
	HubUI.text(c, r.position + Vector2(84, 76) * uu, "冒險手帳", 58 * uu, HubUI.RED)
	_chips(c, uu, r)
	# 頁籤
	_tab_rects.clear()
	var tx := r.position.x + 84 * uu
	for i in TABS.size():
		var w := (150 if i < 2 else 190) * uu
		var tr := Rect2(Vector2(tx, r.position.y + 104 * uu), Vector2(w, 54 * uu))
		_tab_rects.append(tr)
		var on := i == tab
		c.draw_style_box(HubUI.box(HubUI.GOLD if on else Color("efe6cf"), HubUI.GOLD_EDGE if on else HubUI.PAPER_EDGE, 20 * uu, 3.0, false), tr)
		HubUI.text_c(c, tr.get_center() + Vector2(0, -2 * uu), String(TABS[i]), 28 * uu, HubUI.INK if on else Color("8a7a60"))
		tx += w + 14 * uu
	# 關閉
	var cc := Vector2(r.end.x - 52 * uu, r.position.y + 52 * uu)
	_close_rect = Rect2(cc - Vector2(32, 32) * uu, Vector2(64, 64) * uu)
	c.draw_circle(cc + Vector2(1, 3) * uu, 28 * uu, Color(0, 0, 0, 0.22))
	c.draw_circle(cc, 28 * uu, Color("e8483a"))
	c.draw_line(cc + Vector2(-9, -9) * uu, cc + Vector2(9, 9) * uu, Color.WHITE, 5 * uu, true)
	c.draw_line(cc + Vector2(-9, 9) * uu, cc + Vector2(9, -9) * uu, Color.WHITE, 5 * uu, true)
	var body := Rect2(r.position + Vector2(84, 188) * uu, Vector2(PANEL.x - 140, PANEL.y - 230) * uu)
	_cell_rects.clear()
	match tab:
		0:
			_paint_journey(c, uu, body)
		1:
			_paint_stickers(c, uu, body)
		2:
			_paint_book(c, uu, body)
	HubUI.key_strip(c, u, [[["←", "→"], "換頁"], [["↑", "↓"], "選擇"] if tab > 0 else [["1", "2", "3"], "直接翻"], [["Esc"], "合上"]])

## 右上角的小統計：星星、羽毛、貼紙
func _chips(c: Control, u: float, r: Rect2) -> void:
	var st: Array = [int(_ctx.get("stars", 0)), int(_ctx.get("stars_max", 0))]
	var cnt: Array = Journal.sticker_count(_ctx)
	var x := r.end.x - 120 * u
	var y := r.position.y + 52 * u
	var items := [["貼紙 %d/%d" % [cnt[0], cnt[1]], "tag"], ["%d/%d" % [st[0], st[1]], "star"]]
	for it in items:
		var label := String(it[0])
		var w := HubUI.text_w(label, 24 * u) + 62 * u
		x -= w
		var cr := Rect2(Vector2(x, y - 21 * u), Vector2(w, 42 * u))
		c.draw_style_box(HubUI.box(Color("fff1bf"), Color("d9b84a"), 20 * u, 2.0, false), cr)
		if String(it[1]) == "star":
			HubUI.star(c, cr.position + Vector2(24, 21) * u, 12 * u, HubUI.GOLD, HubUI.GOLD_EDGE)
		else:
			HubUI.sticker(c, cr.position + Vector2(24, 21) * u, 12 * u, "貼", Color("6dbb55"), true)
		HubUI.text(c, Vector2(cr.position.x + 44 * u, cr.position.y + 30 * u), label, 24 * u, HubUI.INK)
		x -= 12 * u

# ---------------------------------------------------------------- 頁：旅程

func _paint_journey(c: Control, u: float, body: Rect2) -> void:
	var rows: Array = map._journal_rows()
	var cw := (body.size.x - 24 * u) * 0.5
	var ch := 150.0 * u
	for i in rows.size():
		var row: Dictionary = rows[i]
		var col := i % 2
		var rr := i / 2
		var cr := Rect2(body.position + Vector2(col * (cw + 24 * u), rr * (ch + 16 * u)), Vector2(cw, ch))
		_journey_card(c, u, cr, row)

func _journey_card(c: Control, u: float, r: Rect2, row: Dictionary) -> void:
	var locked := bool(row.locked)
	c.draw_style_box(HubUI.box(Color("fffdf4") if not locked else Color("efebe0"), HubUI.PAPER_EDGE, 22 * u, 3.0), r)
	var bc := r.position + Vector2(70, 75) * u
	var col: Color = row.col
	if locked:
		HubUI.sticker(c, bc, 40 * u, "", Color.GRAY, false)
		HubUI.text(c, r.position + Vector2(136, 70) * u, "？？？", 38 * u, Color("9c968a"))
		HubUI.text(c, r.position + Vector2(138, 112) * u, "即將開放", 24 * u, Color("9c968a"))
		return
	c.draw_circle(bc + Vector2(0, 3) * u, 44 * u, Color(0, 0, 0, 0.2))
	c.draw_circle(bc, 44 * u, Color.WHITE)
	c.draw_circle(bc, 38 * u, col)
	HubUI.text_c(c, bc + Vector2(0, -2) * u, String(row.icon), 40 * u, Color.WHITE)
	var title := String(row.title)
	HubUI.text(c, r.position + Vector2(136, 56) * u, title, HubUI.fit(title, 36 * u, r.size.x - 136 * u - 150 * u), HubUI.INK)
	# 星星
	HubUI.star(c, r.position + Vector2(150, 90) * u, 14 * u, HubUI.GOLD, HubUI.GOLD_EDGE)
	HubUI.text(c, r.position + Vector2(172, 99) * u, "%d/%d" % [int(row.stars), int(row.stars_max)], 26 * u, HubUI.INK)
	# 每個小關：圓點（過了是綠色）
	var sx := r.position.x + 312 * u
	for j in int(row.stages):
		var done: bool = j < int(row.done)
		c.draw_circle(Vector2(sx + j * 26 * u, r.position.y + 90 * u), 9 * u, HubUI.GREEN if done else Color("e2dccb"))
		c.draw_arc(Vector2(sx + j * 26 * u, r.position.y + 90 * u), 9 * u, 0, TAU, 16, HubUI.GREEN.darkened(0.3) if done else HubUI.PAPER_EDGE, 2.0 * u, true)
	# 羽毛和蓋章
	var fc: Color = row.feather
	map._feather(c, r.position + Vector2(r.size.x - 118 * u, 128 * u), 62 * u, 0.32, fc, bool(row.cleared))
	if bool(row.cleared):
		var sc := r.position + Vector2(r.size.x - 70 * u, 52 * u)
		c.draw_set_transform(sc, -0.22, Vector2.ONE)
		c.draw_arc(Vector2.ZERO, 30 * u, 0, TAU, 32, Color("d9423a"), 4 * u, true)
		c.draw_arc(Vector2.ZERO, 24 * u, 0, TAU, 32, Color("d9423a"), 2 * u, true)
		HubUI.text_c(c, Vector2.ZERO, "通關", 22 * u, Color("d9423a"))
		c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# ---------------------------------------------------------------- 頁：貼紙

func _paint_stickers(c: Control, u: float, body: Rect2) -> void:
	var list := Journal.stickers(_ctx)
	var cols := 5
	var cw := body.size.x / cols
	var chh := 104.0 * u
	var rows := int(ceil(float(list.size()) / cols))
	var vis := maxi(int((body.size.y - 70.0 * u) / chh), 3)               # 放得下幾列；貼紙更多就上下捲，不要把每一列擠扁
	sel = clampi(sel, 0, list.size() - 1)
	var srow := sel / cols
	_scroll = clampi(_scroll, 0, maxi(rows - vis, 0))
	if srow < _scroll:
		_scroll = srow
	elif srow >= _scroll + vis:
		_scroll = srow - vis + 1
	for i in list.size():
		var row := i / cols
		if row < _scroll or row >= _scroll + vis:
			_cell_rects.append(Rect2())                                  # 捲出畫面的：佔個位置（滑鼠找格子是照順序找的）
			continue
		var s: Dictionary = list[i]
		var cr := Rect2(body.position + Vector2((i % cols) * cw, (row - _scroll) * chh), Vector2(cw - 8 * u, chh - 8 * u))
		_cell_rects.append(cr)
		if i == sel:
			c.draw_style_box(HubUI.box(Color(UIStyle.STICKY, 0.9), UIStyle.STICKY_EDGE, 18 * u, 3.0, false), cr)
		var got := bool(s.got)
		var cat: Color = Journal.CAT_COLORS[String(s.cat)]
		HubUI.sticker(c, cr.position + Vector2(48, 52) * u, 34 * u, String(s.glyph), cat, got)
		var nm := String(s.name) if got else "？？？"
		HubUI.text(c, cr.position + Vector2(94, 46) * u, nm, HubUI.fit(nm, 24 * u, cr.size.x - 100 * u), HubUI.INK if got else Color("9c968a"))
		var prog := "已解鎖" if got else "%d/%d" % [int(s.cur), int(s.need)]
		HubUI.text(c, cr.position + Vector2(94, 78) * u, prog, 20 * u, Color("3c7d3c") if got else Color("8a847a"))
	# 還有沒看到的：右邊的上下小三角和「第幾列／共幾列」
	if rows > vis:
		var ax := body.end.x - 14.0 * u
		var tri := Color("c9a95a")
		if _scroll > 0:
			c.draw_colored_polygon(PackedVector2Array([Vector2(ax, body.position.y - 14 * u), Vector2(ax - 11 * u, body.position.y + 4 * u), Vector2(ax + 11 * u, body.position.y + 4 * u)]), tri)
		if _scroll + vis < rows:
			var by := body.position.y + vis * chh
			c.draw_colored_polygon(PackedVector2Array([Vector2(ax, by + 2 * u), Vector2(ax - 11 * u, by - 16 * u), Vector2(ax + 11 * u, by - 16 * u)]), tri)
		HubUI.text(c, Vector2(body.end.x - 150 * u, body.position.y + vis * chh + 24 * u), "第 %d–%d 列／共 %d 列" % [_scroll + 1, mini(_scroll + vis, rows), rows], 18 * u, Color("8a847a"))
	var cur: Dictionary = list[sel]
	var dr := Rect2(Vector2(body.position.x, body.end.y - 60 * u), Vector2(body.size.x, 52 * u))
	c.draw_style_box(HubUI.box(Color("fff1bf"), Color("d9b84a"), 20 * u, 2.0, false), dr)
	var line := "%s：%s" % [String(cur.name) if bool(cur.got) else "？？？", String(cur.desc)]
	HubUI.text(c, dr.position + Vector2(24, 35) * u, line, HubUI.fit(line, 26 * u, dr.size.x - 48 * u), HubUI.INK)

# ---------------------------------------------------------------- 頁：魚圖鑑

func _paint_book(c: Control, u: float, body: Rect2) -> void:
	var cols := 5
	var cw := body.size.x / cols
	var chh := 212.0 * u
	sel = clampi(sel, 0, Journal.FISH.size() - 1)
	for i in Journal.FISH.size():
		var f: Dictionary = Journal.FISH[i]
		var id := String(f.id)
		var times := Journal.n("fish", "caught_" + id)
		var known := times > 0
		var cr := Rect2(body.position + Vector2((i % cols) * cw, (i / cols) * (chh + 8 * u)), Vector2(cw - 10 * u, chh))
		_cell_rects.append(cr)
		c.draw_style_box(HubUI.box(Color("fffdf4") if known else Color("efebe0"), HubUI.GOLD if i == sel else HubUI.PAPER_EDGE, 22 * u, 4.0 if i == sel else 3.0, i == sel), cr)
		var ic := cr.position + Vector2(cr.size.x * 0.5, 76 * u)
		c.draw_circle(ic, 58 * u, Color("e4f3fb") if known else Color("e6e0d2"))
		if String(f.kind) == "fish":
			HubUI.fish_icon(c, ic, 104 * u, f.col, false, known)
		elif not known:
			HubUI.text_c(c, ic, "？", 56 * u, Color("9c968a"))
		elif id == "star":
			HubUI.star(c, ic, 40 * u, HubUI.GOLD, HubUI.GOLD_EDGE)
		else:
			HubUI.text_c(c, ic, "蕉" if id == "peel" else "桶", 60 * u, HubUI.INK)
		var nm := String(f.name) if known else "？？？"
		HubUI.text_c(c, Vector2(cr.get_center().x, cr.position.y + 150 * u), nm, HubUI.fit(nm, 28 * u, cr.size.x - 20 * u), HubUI.INK if known else Color("9c968a"))
		var sub := "沒釣過"
		if known:
			var best := Journal.n("fish", "best_" + id)
			sub = ("最大 %d 公分" % best) if best > 0 else "釣到 %d 次" % times
		HubUI.text_c(c, Vector2(cr.get_center().x, cr.position.y + 184 * u), sub, 20 * u, Color("3c7d3c") if known else Color("8a847a"))
	var cur: Dictionary = Journal.FISH[sel]
	var dr := Rect2(Vector2(body.position.x, body.end.y - 62 * u), Vector2(body.size.x, 52 * u))
	c.draw_style_box(HubUI.box(Color("e4f3fb"), Color("9cc9e2"), 20 * u, 2.0, false), dr)
	var known2 := Journal.n("fish", "caught_" + String(cur.id)) > 0
	var line := ("%s：%s" % [String(cur.name), String(cur.line)]) if known2 else "還沒釣到。去農莊的池塘試試運氣。"
	HubUI.text(c, dr.position + Vector2(24, 35) * u, line, HubUI.fit(line, 26 * u, dr.size.x - 48 * u), HubUI.INK)
