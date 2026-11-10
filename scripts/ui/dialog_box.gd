extends Control
## 畫面中下方的對話框：左邊家豪的頭像、右邊文字，自己滑上來、停一下、再自己滑下去
## 可以另外帶一張圖放在右側，圖比框高，會超出框外
## 所有關卡共用（template）。
const W := 760.0
const H := 120.0
const SHOW_TIME := 3.2
var text := ""
var pic: Texture2D
var portrait: Texture2D
var t := -1.0          # <0 表示沒在顯示

func say(s: String, tex: Texture2D = null) -> void:
	text = s
	pic = tex
	t = 0.0
	visible = true
	queue_redraw()

func showing() -> bool:
	return t >= 0.0

func _process(dt: float) -> void:
	if t < 0.0:
		return
	t += dt
	if t >= SHOW_TIME:
		t = -1.0
		visible = false
	queue_redraw()

func _draw() -> void:
	if t < 0.0:
		return
	# 進場 0.25 秒、出場 0.3 秒：上下滑動＋淡入淡出
	var k_in := clampf(t / 0.25, 0.0, 1.0)
	var k_out := clampf((SHOW_TIME - t) / 0.3, 0.0, 1.0)
	var k := minf(k_in, k_out)
	var e := 1.0 - pow(1.0 - k, 3.0)
	var off := Vector2((size.x - W) * 0.5, (1.0 - e) * 50.0)
	var a := e
	var box := Rect2(off, Vector2(W, H))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.07, 0.09, 0.45 * a)   # 半透明，看得到後面的場景
	sb.border_color = Color(1, 1, 1, 0.6 * a)
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(10)
	draw_style_box(sb, box)
	# 左邊：家豪的頭像（圓形大頭照，外面一圈白框）
	var pc := off + Vector2(70, H * 0.5)
	draw_circle(pc, 50, Color(1, 1, 1, 0.85 * a))
	if portrait:
		draw_texture_rect(portrait, Rect2(pc - Vector2(47, 47), Vector2(94, 94)), false, Color(1, 1, 1, a))
	# 右邊：文字
	var font := get_theme_default_font()
	var fs := 34
	var tx := off.x + 140.0
	var avail := W - 150.0 - (190.0 if pic else 20.0)
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	while tw > avail and fs > 18:
		fs -= 2
		tw = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var ty := off.y + H * 0.5 + fs * 0.35
	draw_string(font, Vector2(tx + 3, ty + 3), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.8 * a))
	draw_string(font, Vector2(tx, ty), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, a))
	# 右側的圖：底部貼著框底，往上超出框外
	if pic:
		var ph := 210.0
		var pw := ph * float(pic.get_width()) / float(pic.get_height())
		var pr := Rect2(Vector2(off.x + W - pw + 40.0, off.y + H - ph + 8.0), Vector2(pw, ph))
		draw_texture_rect(pic, pr, false, Color(1, 1, 1, a))
