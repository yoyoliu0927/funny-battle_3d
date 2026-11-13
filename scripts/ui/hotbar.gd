extends Control
## 技能欄
## 手帳風格的快捷欄：每個道具一張米色紙卡，選中的往上浮、紅框；右上角紅色圓徽章是次數
## 所有關卡共用（template）。道具資料來自 scripts/items/item.gd。
const UIStyle := preload("res://scripts/ui/ui_style.gd")   # 全遊戲共用的介面美術（手帳風格）
const S := 84.0          # 一格的大小
const PX := 4.0          # 圖示一個像素的大小
var skills: Array = []
var counts: Array = []
var cooldowns: Array = []
var selected := 0
var name_t := 0.0        # 切換後在上方顯示技能名稱的剩餘時間
# 按開始時的次數切換動畫：舊數字往上淡出、新數字放大彈進來，一格接一格
const SW_DUR := 0.8
const SW_STAGGER := 0.12
var old_counts: Array = []
var sw: Dictionary = {}  # 格子 → 動畫已經播了幾秒（負的 = 還在排隊）

func bar_size() -> Vector2:
	return Vector2(skills.size() * S + 4.0, S + 4.0)

func play_switch(before: Array, slots: Array) -> void:
	old_counts = before.duplicate()
	sw.clear()
	for k in slots.size():
		sw[slots[k]] = -SW_STAGGER * k
	queue_redraw()

func stop_switch() -> void:
	sw.clear()
	queue_redraw()

func switching() -> bool:
	return not sw.is_empty()

func _process(dt: float) -> void:
	if name_t > 0.0:
		name_t = maxf(name_t - dt, 0.0)
		queue_redraw()
	if not sw.is_empty():
		for i in sw.keys():
			sw[i] += dt
			if sw[i] >= SW_DUR:
				sw.erase(i)
		queue_redraw()

static func count_text(cnt: int) -> String:
	return "∞" if cnt < 0 else str(cnt)

## 右上角紅色圓徽章裡的數量：置中，可以位移、縮放、淡出
func _draw_count(font: Font, center: Vector2, cnt: int, fs: int, dy: float, col: Color) -> void:
	var txt := count_text(cnt)
	var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(font, center + Vector2(-tw * 0.5, fs * 0.36 + dy), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)

static func _count_color(_cnt: int) -> Color:
	return Color(1, 1, 1)

## 手帳風格：每個道具是一張米色圓角紙卡（選中的往上浮、紅框），中間一顆圓貼紙放圖示，右上角紅色圓徽章是次數
func _draw() -> void:
	var bs := bar_size()
	var font := get_theme_default_font()
	for i in skills.size():
		var cell := Rect2(Vector2(2.0 + i * S, 2.0), Vector2(S, S))
		var is_sel := i == selected
		var card := cell.grow(-5.0)
		if is_sel:
			card.position.y -= 7.0
		var cnt: int = counts[i] if i < counts.size() else 0
		var cd: float = cooldowns[i] if i < cooldowns.size() else 0.0
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(1.0, 0.973, 0.906) if cnt != 0 else Color(0.86, 0.84, 0.8)
		sb.border_color = UIStyle.accent() if is_sel else UIStyle.INK
		sb.set_border_width_all(4 if is_sel else 3)
		sb.border_width_bottom = 6 if is_sel else 5
		sb.set_corner_radius_all(14)
		sb.shadow_color = Color(0, 0, 0, 0.28)
		sb.shadow_size = 5
		sb.shadow_offset = Vector2(2, 4)
		draw_style_box(sb, card)
		# 圖示底下的圓貼紙（讓黃色的像素圖示在米色紙上也清楚）
		draw_circle(card.get_center() + Vector2(0, 2), 29.0, Color(0.36, 0.27, 0.2, 0.92 if cnt != 0 else 0.5))
		_draw_item_icon(skills[i], Rect2(card.position + Vector2(0, 2), card.size), cnt == 0)
		if cd > 0.0:
			# 冷卻中：一片暗色從上往下縮短，中間顯示剩下的秒數
			var frac := clampf(cd / float(skills[i].cooldown), 0.0, 1.0)
			var inner := card.grow(-4.0)
			draw_rect(Rect2(inner.position + Vector2(0, inner.size.y * (1.0 - frac)), Vector2(inner.size.x, inner.size.y * frac)), Color(0, 0, 0, 0.55))
			var ct := "%.1f" % cd if cd < 10.0 else "%d" % ceili(cd)
			var cw := font.get_string_size(ct, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
			_shadow_text(font, card.get_center() + Vector2(-cw * 0.5, 9), ct, 26, Color(1, 1, 1))
		# 左上角小小的按鍵數字（只有一種道具時不用寫）
		if skills.size() > 1:
			draw_string(font, card.position + Vector2(9, 22), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(UIStyle.INK, 0.7))
		# 右上角的次數徽章
		var bc := card.position + Vector2(card.size.x - 5.0, 5.0)
		draw_circle(bc, 17.0, UIStyle.INK)
		draw_circle(bc, 14.5, UIStyle.accent() if cnt != 0 else Color(0.55, 0.55, 0.55))
		if sw.has(i):
			var e: float = sw[i]
			var old: int = old_counts[i] if i < old_counts.size() else cnt
			if e < 0.0:
				_draw_count(font, bc, old, 20, 0.0, _count_color(old))
			else:
				var u := e / SW_DUR
				# 舊數字：往上滑走、淡出
				if u < 0.35:
					var o := u / 0.35
					var oc := _count_color(old)
					oc.a = 1.0 - o
					_draw_count(font, bc, old, 20, -14.0 * o * o, oc)
				# 新數字：從下面冒上來、先放大再縮回原本大小，顏色由金黃變回白
				if u > 0.25:
					var v := (u - 0.25) / 0.75
					var ev := 1.0 - pow(1.0 - v, 3.0)
					var pop := sin(PI * minf(v * 1.6, 1.0))
					var nc := _count_color(cnt)
					if cnt != 0:
						nc = Color(1.0, 0.86, 0.3).lerp(nc, ev)
					nc.a = minf(v * 4.0, 1.0)
					_draw_count(font, bc, cnt, int(round(20.0 + 10.0 * pop)), 8.0 * (1.0 - ev), nc)
					# 徽章閃一下金光，提示「這格換成開打後的次數了」
					draw_arc(bc, 18.0, 0.0, TAU, 24, Color(1.0, 0.85, 0.3, 0.9 * (1.0 - ev)), 3.0, true)
		else:
			_draw_count(font, bc, cnt, 20, 0.0, _count_color(cnt))
	# 切換時在上方浮出技能名稱
	if name_t > 0.0 and selected < skills.size():
		var nm: String = skills[selected].name
		var a := clampf(name_t / 0.5, 0.0, 1.0)
		var w := font.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
		_shadow_text(font, Vector2((bs.x - w) * 0.5, -20), nm, 24, Color(1, 1, 1, a))

func _shadow_text(font: Font, pos: Vector2, txt: String, fs: int, col: Color) -> void:
	draw_string(font, pos + Vector2(2, 2), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.15, 0.15, 0.15, col.a))
	draw_string(font, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)

func _px(c: Vector2, x: int, y: int, col: Color) -> void:
	draw_rect(Rect2(c + Vector2(x, y) * PX, Vector2(PX, PX)), col)

## 道具有 icon（PNG 圖片）就畫圖片；內建道具（飼料、香蕉皮、巨石）用像素圖示；
## 都沒有的話畫一個道具顏色的圓，中間寫道具名稱的第一個字
func _draw_item_icon(item, cell: Rect2, empty: bool) -> void:
	var tint := Color(0.45, 0.45, 0.45) if empty else Color(1, 1, 1)
	if item.icon:
		draw_texture_rect(item.icon, Rect2(cell.get_center() - Vector2(26, 26), Vector2(52, 52)), false, tint)
		return
	if item.id in ["feed", "banana", "rock"]:
		_draw_icon(item.id, cell.get_center(), empty)
		return
	var col: Color = item.color.darkened(0.55 if empty else 0.0)
	draw_circle(cell.get_center(), 22, col)
	var font := get_theme_default_font()
	var ch := String(item.name).left(1)
	var w := font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
	draw_string(font, cell.get_center() + Vector2(-w * 0.5, 9), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(0.1, 0.1, 0.1))

## 12×12 的像素圖示（左上角是 c - 6 格）
func _draw_icon(id: String, center: Vector2, empty: bool) -> void:
	var c := center - Vector2(6, 6) * PX
	var dim := 0.55 if empty else 0.0
	match id:
		"rock":
			for y in 12:
				for x in 12:
					var d := Vector2(x - 5.5, y - 5.8).length()
					if d > 5.6:
						continue
					var light := clampf(0.5 - (x + y - 11) * 0.06, 0.0, 1.0)
					var col := Color(0.4, 0.41, 0.43).lerp(Color(0.82, 0.83, 0.84), light)
					if d > 4.7:
						col = Color(0.22, 0.22, 0.24)
					elif (x * 7 + y * 3) % 11 == 0:
						col = col.darkened(0.18)
					_px(c, x, y, col.darkened(dim))
			_px(c, 3, 3, Color(0.95, 0.95, 0.95).darkened(dim))
			_px(c, 4, 3, Color(0.92, 0.92, 0.92).darkened(dim))
		"feed":
			# 一小堆飼料粒：深淺黃色像素
			var grains := [[5, 2], [7, 3], [3, 4], [6, 5], [8, 5], [2, 6], [4, 6], [10, 6], [5, 7], [7, 7], [9, 7],
				[1, 8], [3, 8], [6, 8], [8, 8], [10, 8], [2, 9], [4, 9], [5, 9], [7, 9], [9, 9], [3, 10], [6, 10], [8, 10]]
			for k in grains.size():
				var g: Array = grains[k]
				var col := Color(1.0, 0.86, 0.3) if k % 3 != 0 else Color(0.86, 0.6, 0.15)
				_px(c, g[0], g[1], col.darkened(dim))
				if k % 4 == 0:
					_px(c, g[0], g[1] + 1, Color(0.6, 0.4, 0.1).darkened(dim))
		"banana":
			# 一片攤開的香蕉皮：黃色三瓣、中間一點咖啡色
			var pts := [[5, 1], [6, 1], [5, 2], [6, 2], [5, 3], [6, 3], [5, 4], [6, 4],
				[4, 5], [5, 5], [6, 5], [7, 5], [3, 6], [4, 6], [5, 6], [6, 6], [7, 6], [8, 6],
				[2, 7], [3, 7], [4, 7], [7, 7], [8, 7], [9, 7], [1, 8], [2, 8], [3, 8], [8, 8], [9, 8], [10, 8],
				[1, 9], [2, 9], [9, 9], [10, 9], [5, 7], [6, 7], [5, 8], [6, 8]]
			for q in pts:
				var col := Color(1.0, 0.88, 0.25)
				if q[1] <= 2 or (q[0] + q[1]) % 5 == 0:
					col = Color(0.95, 0.72, 0.12)
				if q[0] in [5, 6] and q[1] >= 7:
					col = Color(1.0, 0.97, 0.75)
				_px(c, q[0], q[1], col.darkened(dim))
			_px(c, 5, 0, Color(0.4, 0.26, 0.1).darkened(dim))
			_px(c, 6, 0, Color(0.4, 0.26, 0.1).darkened(dim))
			_px(c, 1, 10, Color(0.4, 0.26, 0.1).darkened(dim))
			_px(c, 10, 10, Color(0.4, 0.26, 0.1).darkened(dim))
