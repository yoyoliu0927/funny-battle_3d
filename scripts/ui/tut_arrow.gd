extends Control
## 開場教學用的白色大箭頭（往下指，粗粗方方的）

func _draw() -> void:
	var w := size.x
	var h := size.y
	var shaft := Rect2(Vector2(w * 0.5 - 7, 0), Vector2(14, h - 26))
	var head := PackedVector2Array([Vector2(w * 0.5 - 26, h - 30), Vector2(w * 0.5 + 26, h - 30), Vector2(w * 0.5, h)])
	# 黑色外框
	draw_rect(shaft.grow(3), Color(0.1, 0.1, 0.1, 0.85))
	var ho := PackedVector2Array([Vector2(w * 0.5 - 32, h - 33), Vector2(w * 0.5 + 32, h - 33), Vector2(w * 0.5, h + 5)])
	draw_colored_polygon(ho, Color(0.1, 0.1, 0.1, 0.85))
	draw_rect(shaft, Color(1, 1, 1))
	draw_colored_polygon(head, Color(1, 1, 1))
