extends Control
## 畫面中央的準心：白色圓圈 + 中心白點，代表點擊時會作用的位置

@export var radius := 17.0
@export var ring_width := 2.5
@export var dot_radius := 3.0
@export var color := Color(1, 1, 1, 0.9)
@export var shadow := Color(0, 0, 0, 0.3)
@export var fill := Color(1, 1, 1, 0.18)
@export var highlight_color := Color(1.0, 0.85, 0.3, 1.0)

## 準心對到可互動的機關時變成黃色並放大
var highlight := false:
	set(v):
		if v != highlight:
			highlight = v
			queue_redraw()

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	var c := size * 0.5
	var r := radius * (1.25 if highlight else 1.0)
	var col := highlight_color if highlight else color
	var fil := Color(highlight_color, 0.25) if highlight else fill
	# 淡淡的陰影，讓準心在亮色砂地上也看得清楚
	draw_arc(c, r, 0.0, TAU, 48, shadow, ring_width + 2.0, true)
	draw_circle(c, dot_radius + 1.0, shadow)
	draw_circle(c, r, fil)   # 圓內一層淡白，標示作用範圍
	draw_arc(c, r, 0.0, TAU, 48, col, ring_width, true)
	draw_circle(c, dot_radius, col)
