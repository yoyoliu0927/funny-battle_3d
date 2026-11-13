extends Control
## 開場教學用的大箭頭（往下指，粗粗方方的）：便利貼的黃色、深色外框，和上面那張便利貼是一組

func _draw() -> void:
	var w := size.x
	var h := size.y
	var ink := Color(0.231, 0.165, 0.125)
	var fill := Color(1.0, 0.914, 0.541)
	var shaft := Rect2(Vector2(w * 0.5 - 7, 0), Vector2(14, h - 26))
	var head := PackedVector2Array([Vector2(w * 0.5 - 26, h - 30), Vector2(w * 0.5 + 26, h - 30), Vector2(w * 0.5, h)])
	# 深色外框
	draw_rect(shaft.grow(3), ink)
	var ho := PackedVector2Array([Vector2(w * 0.5 - 32, h - 33), Vector2(w * 0.5 + 32, h - 33), Vector2(w * 0.5, h + 5)])
	draw_colored_polygon(ho, ink)
	draw_rect(shaft, fill)
	draw_colored_polygon(head, fill)
