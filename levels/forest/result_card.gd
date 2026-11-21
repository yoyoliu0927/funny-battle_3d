extends RefCounted
## 森林的結算卡（過關）和落敗卡：筆記紙卡片、圖示、會一顆一顆亮起來的星星，不是一整段文字。
## 用法（forest_battle.gd）：ResultCard.win(self) / ResultCard.defeat(self) 回傳一張 Control，放進結算面板或落敗畫面。

const UISkin := preload("res://scripts/ui/ui_style.gd")
const Models := preload("res://levels/forest/items/models.gd")
const GOLD := Color("f6c445")
const DIM_STAR := Color("f4ebd3")

# ================================================================== 過關

static func win(bt) -> Control:
	var v := _col(12)
	# 標題：小紅帽＋一句話
	var head := _row(12)
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_child(_icon("hood" if bt.want_hood else "tree", 64))
	var title := _label(bt._win_title(), 38)
	head.add_child(title)
	v.add_child(head)
	# 三顆大星（累積的紀錄），新拿到的底下寫「新！」
	var list: Array = bt._objectives()
	if not list.is_empty():
		var best: Dictionary = bt._best()
		var stars := _row(18)
		stars.alignment = BoxContainer.ALIGNMENT_CENTER
		v.add_child(stars)
		var k := 0
		for c in list:
			var got: bool = best.has(c.id)
			var fresh: bool = bt._new_stars.has(c.id)
			var cell := _col(0)
			var st := _label("★", 74, GOLD if got else DIM_STAR, 10, UISkin.INK)
			st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			cell.add_child(st)
			var tag := _label("新！" if fresh else " ", 18, UISkin.accent())
			tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			cell.add_child(tag)
			stars.add_child(cell)
			_pop_in(st, 0.15 + 0.22 * k, got)
			k += 1
		for c in list:
			var got2: bool = best.has(c.id)
			var r := _row(10)
			r.add_child(_label("★", 24, GOLD if got2 else DIM_STAR, 6, UISkin.INK if got2 else Color(UISkin.INK, 0.4)))
			r.add_child(_label(String(c.text), 23, UISkin.INK if got2 else Color(UISkin.INK, 0.5)))
			v.add_child(r)
	v.add_child(_rule())
	_stats(bt, v)
	v.add_child(_gap(4))
	# 按鈕：有下一關就按空白鍵出發（森林不自動出發，見 forest_battle.gd 的 go_next_stage），不然回地圖
	var btns := _row(10)
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	var nxt: Dictionary = bt.next_stage_info()
	if nxt != null and not nxt.is_empty():
		btns.add_child(_go_button("下一關 ▶", "空白"))
	else:
		btns.add_child(_go_button("回地圖 ▶", "M"))
	_key_hint(btns, "R", "再玩一次")
	v.add_child(btns)
	return _paper(v, 0.012)

# ================================================================== 落敗

static func defeat(bt) -> Control:
	var v := _col(10)
	var head := _row(12)
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	match String(bt.fail):
		"hood":
			head.add_child(_icon("hood", 56, Color(0.55, 0.55, 0.55)))
		"fire":
			head.add_child(_icon("flame", 56))
		"trees":
			head.add_child(_icon("log", 56))
	head.add_child(_label(bt._defeat_title(), 34))
	v.add_child(head)
	# 只放跟輸掉原因有關的那一條（卡片不要太高，蓋住後面的晚餐畫面）
	var why := String(bt.fail)
	if bt.want_trees and why != "hood":
		v.add_child(_stat_row("森林", _forest_bar(bt), "%d / %d" % [bt.trees_lost(), bt.tree_cap]))
	if bt.want_hood and why != "trees" and why != "fire":
		v.add_child(_stat_row("小紅帽", _hood_bar(bt), _hood_text(bt)))
	v.add_child(_stat_row("時間", _label("撐了 %.1f 秒" % bt.time, 22), "第 %d 次" % bt.attempts.size()))
	var tip := _label(_tip_only(bt), 21, Color(UISkin.INK, 0.75))
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	tip.custom_minimum_size = Vector2(520, 0)
	v.add_child(tip)
	# 這一局拿到的星星（小小的，沒拿到也不會記）
	var list: Array = bt._objectives()
	if not list.is_empty():
		var r := _row(14)
		r.alignment = BoxContainer.ALIGNMENT_CENTER
		for c in list:
			var got: bool = bt._done.has(c.id)
			var cell := _row(4)
			cell.add_child(_label("★", 20, GOLD if got else DIM_STAR, 5, UISkin.INK if got else Color(UISkin.INK, 0.35)))
			cell.add_child(_label(String(c.text), 17, UISkin.INK if got else Color(UISkin.INK, 0.45)))
			r.add_child(cell)
		v.add_child(r)
	v.add_child(_gap(2))
	var btns := _row(10)
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	btns.add_child(_go_button("再試一次 ▶", "R"))
	_key_hint(btns, "M", "地圖")
	v.add_child(btns)
	return _paper(v, -0.01)

## _defeat_tip() 後面接了星星的文字版，卡片上只要第一行提示
static func _tip_only(bt) -> String:
	return String(bt._defeat_tip()).split("\n")[0]

# ================================================================== 數據：森林、小紅帽、道具、時間

static func _stats(bt, v: VBoxContainer) -> void:
	if bt.want_trees:
		v.add_child(_stat_row("森林", _forest_bar(bt), "%d / %d" % [bt.trees_lost(), bt.tree_cap]))
	if bt.want_hood:
		v.add_child(_stat_row("小紅帽", _hood_bar(bt), _hood_text(bt)))
	var used := _items_used(bt)
	if used.get_child_count() > 0:
		v.add_child(_stat_row("道具", used, ""))
	v.add_child(_stat_row("時間", _label("%.1f 秒" % bt.time, 22), "第 %d 次" % bt.attempts.size()))

static func _stat_row(name: String, body: Control, right: String) -> Control:
	var r := _row(12)
	var n := _label(name, 20, Color(UISkin.INK, 0.6))
	n.custom_minimum_size = Vector2(64, 0)
	r.add_child(n)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_child(body)
	if right != "":
		r.add_child(_label(right, 20, Color(UISkin.INK, 0.7)))
	return r

## 一棵樹一格：砍倒的畫樹幹、燒掉的畫樹樁、還在的畫樹（最多畫上限這麼多格，超過的那格畫紅框）
static func _forest_bar(bt) -> Control:
	var r := _row(1)
	var cut: int = bt.trees_cut
	var burnt: int = bt.trees_burnt
	var cap: int = bt.tree_cap
	var total := maxi(cap, cut + burnt)
	for i in total:
		var name := "tree"
		if i < cut:
			name = "log"
		elif i < cut + burnt:
			name = "stump"
		var ic := _icon(name, 30)
		if i >= cap:
			var frame := PanelContainer.new()
			frame.add_theme_stylebox_override("panel", UISkin._box(Color(1, 0.85, 0.8), Color(0.85, 0.25, 0.2), 6, 2, false))
			frame.add_child(ic)
			r.add_child(frame)
		else:
			r.add_child(ic)
	return r

## 小紅帽還剩多少時間：紅色的條
static func _hood_bar(bt) -> Control:
	var r := _row(8)
	r.add_child(_icon("hood", 30, Color(1, 1, 1) if bt.hood_saved or bt.fail != "hood" else Color(0.5, 0.5, 0.5)))
	var left: float = clampf((bt.hood_cap - bt.dinner) / bt.hood_cap, 0.0, 1.0)
	var bar := PanelContainer.new()
	bar.custom_minimum_size = Vector2(200, 18)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_theme_stylebox_override("panel", UISkin._box(Color(0.93, 0.89, 0.8), UISkin.INK, 8, 2, false))
	var fill := ColorRect.new()
	fill.color = Color(0.84, 0.16, 0.18)
	fill.custom_minimum_size = Vector2(196.0 * left, 14)
	fill.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	bar.add_child(fill)
	r.add_child(bar)
	return r

static func _hood_text(bt) -> String:
	if bt.hood_saved:
		return "還剩 %.0f 秒" % maxf(bt.hood_cap - bt.dinner, 0.0)
	if bt.fail == "hood":
		return "時間到"
	return "%.0f 秒" % maxf(bt.hood_cap - bt.dinner, 0.0)

## 這一局放了哪些道具、各幾次：道具圖示＋「×N」
static func _items_used(bt) -> Control:
	var counts := {}
	for c in bt.casts:
		counts[c.id] = int(counts.get(c.id, 0)) + 1
	var r := _row(14)
	for it in bt.items:
		var n: int = counts.get(it.id, 0)
		var cell := _row(2)
		var ic := _icon(String(it.id), 36, Color(1, 1, 1) if n > 0 else Color(1, 1, 1, 0.35))
		cell.add_child(ic)
		cell.add_child(_label("×%d" % n, 20, UISkin.INK if n > 0 else Color(UISkin.INK, 0.4)))
		r.add_child(cell)
	return r

# ================================================================== 小零件

static func _paper(content: Control, tilt: float) -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var s := UISkin._box(UISkin.PAPER, UISkin.PAPER_EDGE, 6, 3)
	s.content_margin_left = 44
	s.content_margin_right = 36
	s.content_margin_top = 26
	s.content_margin_bottom = 24
	p.add_theme_stylebox_override("panel", s)
	p.rotation = tilt
	p.add_child(content)
	return p

static func _col(sep: int) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return v

static func _row(sep: int) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return h

static func _gap(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c

static func _rule() -> Control:
	var c := ColorRect.new()
	c.color = Color(UISkin.INK, 0.18)
	c.custom_minimum_size = Vector2(0, 2)
	return c

static func _label(text: String, size: int, color := UISkin.INK, outline := 0, outline_color := Color(0, 0, 0, 0)) -> Label:
	var l := Label.new()
	l.text = text
	l.label_settings = UISkin.ls(size, color, outline, outline_color)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

static func _icon(name: String, px: float, tint := Color(1, 1, 1)) -> TextureRect:
	var t := TextureRect.new()
	t.texture = Models.icon(name)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = Vector2(px, px)
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	t.modulate = tint
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t

## 綠色的主要按鈕：字＋鍵帽放在同一顆按鈕裡
static func _go_button(text: String, key: String) -> Control:
	var p := PanelContainer.new()
	var sb := UISkin._box(Color("58b85a"), Color("2f7a33"), 22, 3)
	sb.content_margin_left = 20
	sb.content_margin_right = 14
	sb.content_margin_top = 6
	sb.content_margin_bottom = 8
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := _row(10)
	p.add_child(h)
	h.add_child(_label(text, 26, Color(1, 1, 1)))
	var kc := UISkin.keycap(key, 18)
	kc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(kc)
	return p

static func _key_hint(parent: Control, key: String, text: String) -> void:
	parent.add_child(_gap(0))
	var kc := UISkin.keycap(key, 18)
	kc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	parent.add_child(kc)
	parent.add_child(_label(text, 20))

## 大星星一顆一顆「啵」地彈出來（沒拿到的只是淡淡地出現）
static func _pop_in(l: Label, delay: float, got: bool) -> void:
	l.pivot_offset = Vector2(40, 44)
	l.scale = Vector2.ZERO
	var tw := l.create_tween()
	tw.tween_interval(delay)
	if got:
		tw.tween_property(l, "scale", Vector2.ONE * 1.25, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(l, "scale", Vector2.ONE, 0.12)
	else:
		tw.tween_property(l, "scale", Vector2.ONE, 0.2)
