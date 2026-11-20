extends Control
## 道具欄的權宜之計：共用的道具欄（scripts/ui/hotbar.gd）在每個圖示底下畫一顆深棕色圓貼紙，
## 森林的道具有自己的模型圖示，不需要那顆圓。共用檔案不能改，所以疊一層在道具欄上面：
## 有 icon_tex 的格子，用卡片的底色把圓蓋掉，再把圖示（和冷卻的暗影）畫回去。
## 位置、大小都照抄 hotbar.gd 的 _draw()；那邊改了排版，這裡也要跟著改。
## 用法：bar.add_child(IconOverlay.new())（bar 是 battle 的 _hotbar）

const UIStyle := preload("res://scripts/ui/ui_style.gd")
const S := 84.0                # 跟 hotbar.gd 的 S 一樣

var bar: Control

func _ready() -> void:
	bar = get_parent() as Control
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)

func _process(_dt: float) -> void:
	queue_redraw()

func _draw() -> void:
	if bar == null:
		return
	var skills: Array = bar.get("skills")
	var counts: Array = bar.get("counts")
	var cooldowns: Array = bar.get("cooldowns")
	var sel: int = bar.get("selected")
	var font := get_theme_default_font()
	for i in skills.size():
		var it = skills[i]
		var tex: Texture2D = it.icon_tex if it.icon_tex != null else it.icon
		if tex == null:
			continue                   # 沒有自己圖示的道具：保留原本的樣子
		var cell := Rect2(Vector2(2.0 + i * S, 2.0), Vector2(S, S))
		var card := cell.grow(-5.0)
		if i == sel:
			card.position.y -= 7.0
		var cnt: int = counts[i] if i < counts.size() else 0
		var cd: float = cooldowns[i] if i < cooldowns.size() else 0.0
		# 1. 用卡片底色蓋掉圓貼紙（hotbar.gd：中心往下 2、半徑 29）
		var paper := Color(1.0, 0.973, 0.906) if cnt != 0 else Color(0.86, 0.84, 0.8)
		draw_circle(card.get_center() + Vector2(0, 2), 29.5, paper)
		# 2. 圖示畫回去，比原本大一點（沒有圓框住了）
		var tint := Color(0.45, 0.45, 0.45) if cnt == 0 else Color(1, 1, 1)
		var ts := tex.get_size()
		var k := 60.0 / maxf(maxf(ts.x, ts.y), 1.0)
		var c := card.get_center() + Vector2(0, 2)
		draw_texture_rect(tex, Rect2(c - ts * k * 0.5, ts * k), false, tint)
		# 3. 冷卻中的暗影和秒數（原本畫在圓上，被蓋掉了，重畫一次）
		if cd > 0.0:
			var frac := clampf(cd / float(it.cooldown), 0.0, 1.0)
			var inner := card.grow(-4.0)
			draw_rect(Rect2(inner.position + Vector2(0, inner.size.y * (1.0 - frac)), Vector2(inner.size.x, inner.size.y * frac)), Color(0, 0, 0, 0.55))
			var ct := "%.1f" % cd if cd < 10.0 else "%d" % ceili(cd)
			var cw := font.get_string_size(ct, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
			var at := card.get_center() + Vector2(-cw * 0.5, 9)
			draw_string(font, at + Vector2(2, 2), ct, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(0.15, 0.15, 0.15))
			draw_string(font, at, ct, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(1, 1, 1))
