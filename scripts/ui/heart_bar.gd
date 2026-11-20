extends Control
## 愛心血量（所有大關共用）：一顆心 = per_heart 點血，不滿一顆畫半顆。
## 用法：hb.max_hp = 10.0; hb.per_heart = 2.0; 每幀 hb.hp = 家豪的血
## 扣血時那顆心會抖一下。

const INK := Color("3b2a20")
const RED := Color("e8484a")
const RED_DARK := Color("b8282c")
const EMPTY := Color(1, 1, 1, 0.55)

var max_hp := 10.0
var per_heart := 2.0
var heart_size := 30.0
var gap := 6.0
var hp := 10.0:
	set(v):
		if v < hp - 0.01:
			_shake = 0.35
		hp = v
		queue_redraw()
var _shake := 0.0

func hearts() -> int:
	return maxi(ceili(max_hp / per_heart - 0.001), 1)

func _get_minimum_size() -> Vector2:
	var n := hearts()
	return Vector2(n * heart_size + (n - 1) * gap, heart_size)

func _process(dt: float) -> void:
	if _shake > 0.0:
		_shake = maxf(_shake - dt, 0.0)
		queue_redraw()

## 心形的外框點（中心 c、寬 s）
func _heart_pts(c: Vector2, s: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 48:
		var t := TAU * i / 48.0
		# 經典心形參數式，縮放到 s 寬
		var x := 16.0 * pow(sin(t), 3.0)
		var y := -(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))
		pts.append(c + Vector2(x, y + 2.0) * (s / 34.0))
	return pts

func _draw() -> void:
	var n := hearts()
	for i in n:
		var c := Vector2(heart_size * 0.5 + i * (heart_size + gap), heart_size * 0.5)
		var fill := clampf((hp - i * per_heart) / per_heart, 0.0, 1.0)
		# 最後一顆有血的心在扣血時抖一下
		if _shake > 0.0 and i == clampi(ceili(hp / per_heart), 0, n - 1):
			c.x += sin(_shake * 70.0) * 3.0
		var pts := _heart_pts(c, heart_size)
		var outline := pts.duplicate()
		outline.append(pts[0])
		draw_colored_polygon(pts, EMPTY)
		if fill >= 0.99:
			draw_colored_polygon(pts, RED)
			# 左上角一點反光
			draw_circle(c + Vector2(-heart_size * 0.2, -heart_size * 0.12), heart_size * 0.09, Color(1, 1, 1, 0.75))
		elif fill > 0.01:
			# 半顆：只畫左半邊
			var s := heart_size
			var left := PackedVector2Array([c + Vector2(-s, -s), c + Vector2(0, -s), c + Vector2(0, s), c + Vector2(-s, s)])
			for poly in Geometry2D.intersect_polygons(pts, left):
				draw_colored_polygon(poly, RED)
		draw_polyline(outline, INK, 2.5, true)
