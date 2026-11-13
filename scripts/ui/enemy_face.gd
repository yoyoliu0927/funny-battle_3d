extends Control
## 右上角敵人名單的小頭像（用畫的：農夫戴草帽、老闆戴深色帽子和眼鏡）
## 所有關卡共用（template）。有給 portrait（頭像圖片）就直接畫圖片。
## 手帳風格：米色圓角小方塊、深色細邊（Boss 是金色邊）。
var boss := false
var dead := false
var portrait: Texture2D

func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("f1e5c8")
	sb.border_color = Color("c9962b") if boss else Color("3b2a20")
	sb.set_border_width_all(3 if boss else 2)
	sb.set_corner_radius_all(int(size.x * 0.24))
	sb.anti_aliasing = true
	draw_style_box(sb, r)
	var c := size * Vector2(0.5, 0.6)
	var k := size.x / 60.0
	if portrait:
		draw_texture_rect(portrait, r.grow(-3.0), false)
	else:
		_draw_face(c, k)
	if dead:
		sb.bg_color = Color(0.2, 0.17, 0.15, 0.6)
		sb.set_border_width_all(0)
		draw_style_box(sb, r)
		var m := size.x * 0.24
		draw_line(Vector2(m, m), size - Vector2(m, m), Color(0.95, 0.3, 0.25), 4.0 * k, true)
		draw_line(Vector2(size.x - m, m), Vector2(m, size.y - m), Color(0.95, 0.3, 0.25), 4.0 * k, true)

func _draw_face(c: Vector2, k: float) -> void:
	var skin := Color(0.96, 0.78, 0.62)
	draw_circle(c, 15 * k, skin)
	# 帽子
	var hat := Color(0.25, 0.2, 0.18) if boss else Color(0.92, 0.82, 0.55)
	draw_rect(Rect2(c + Vector2(-20, -16) * k, Vector2(40, 5) * k), hat)
	draw_rect(Rect2(c + Vector2(-11, -27) * k, Vector2(22, 12) * k), hat)
	if not boss:
		draw_rect(Rect2(c + Vector2(-11, -19) * k, Vector2(22, 3) * k), Color(0.8, 0.25, 0.2))
	# 眼睛 / 眼鏡、嘴、鬍子
	if boss:
		for sx in [-1.0, 1.0]:
			draw_arc(c + Vector2(6 * sx, -2) * k, 4.5 * k, 0, TAU, 16, Color(0.1, 0.1, 0.1), 2.0 * k)
		draw_line(c + Vector2(-1.5, -2) * k, c + Vector2(1.5, -2) * k, Color(0.1, 0.1, 0.1), 2.0 * k)
		draw_rect(Rect2(c + Vector2(-7, 6) * k, Vector2(14, 3) * k), Color(0.35, 0.22, 0.15))
	else:
		for sx in [-1.0, 1.0]:
			draw_circle(c + Vector2(6 * sx, -2) * k, 2.0 * k, Color(0.12, 0.1, 0.1))
		draw_line(c + Vector2(-5, 7) * k, c + Vector2(5, 7) * k, Color(0.55, 0.3, 0.25), 2.0 * k)
