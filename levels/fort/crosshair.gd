extends Control
## 畫面中央的準心：圓圈 + 中心點，外面一圈深色描邊（亮色地面上也看得清楚）。
## state：0 = 平常（白）、1 = 這裡可以放（綠、放大一點）、2 = 這裡不能放（紅、打叉）

const INK := Color("3b2a20")   # 跟 ui_style.gd 的墨色一樣

@export var radius := 17.0
@export var ring_width := 3.0
@export var dot_radius := 3.0
@export var color := Color(1, 1, 1, 0.95)
@export var ok_color := Color("58b85a")
@export var bad_color := Color("e2483d")

var state := 0:
	set(v):
		if v != state:
			state = v
			queue_redraw()

## 舊的介面：true = 可以放（綠）
var highlight := false:
	set(v):
		highlight = v
		state = 1 if v else 0

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	var c := size * 0.5
	var r := radius * (1.2 if state == 1 else 1.0)
	var col: Color = [color, ok_color, bad_color][state]
	# 深色描邊在下面、彩色圈在上面
	draw_arc(c, r, 0.0, TAU, 48, Color(INK, 0.85), ring_width + 3.0, true)
	draw_circle(c, r - ring_width, Color(col, 0.16))
	draw_arc(c, r, 0.0, TAU, 48, col, ring_width, true)
	if state == 2:
		var k := r * 0.42
		for d in [Vector2(k, k), Vector2(k, -k)]:
			draw_line(c - d, c + d, Color(INK, 0.85), 6.0, true)
			draw_line(c - d, c + d, col, 3.0, true)
	else:
		draw_circle(c, dot_radius + 1.5, Color(INK, 0.85))
		draw_circle(c, dot_radius, col)
