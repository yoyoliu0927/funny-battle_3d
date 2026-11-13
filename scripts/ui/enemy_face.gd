extends Control
## 右上角敵人欄的頭像（用畫的：農夫戴草帽、老闆戴深色帽子和眼鏡）
## 所有關卡共用（template）。有給 portrait（頭像圖片）就直接畫圖片。
var boss := false
var dead := false
var portrait: Texture2D

func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, Color(0.1, 0.11, 0.13, 0.8))
	draw_rect(r, Color(1, 0.85, 0.4, 0.9) if boss else Color(1, 1, 1, 0.35), false, 3.0 if boss else 2.0)
	var c := size * Vector2(0.5, 0.58)
	var k := size.x / 56.0
	if portrait:
		draw_texture_rect(portrait, r.grow(-3.0), false)
	else:
		_draw_face(c, k)
	if dead:
		draw_rect(r, Color(0.1, 0.1, 0.1, 0.55))
		draw_line(Vector2(8, 8) * k, size - Vector2(8, 8) * k, Color(0.95, 0.3, 0.25), 4.0 * k)
		draw_line(Vector2(size.x - 8 * k, 8 * k), Vector2(8 * k, size.y - 8 * k), Color(0.95, 0.3, 0.25), 4.0 * k)

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
