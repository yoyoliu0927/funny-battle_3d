extends "res://levels/ice/rescue_battle.gd"
## 【救企鵝 3】時機：只有一片香蕉皮、兩個工人。
## 紅線上每 1 秒有一個白點；瞄準時會標出「他踩到的那一刻，另一個人在哪」。

func _make_items() -> Array:
	return [
		BananaItem.new().uses_shared(1).cooldown_sec(0.0),
	]

func _enemy_specs() -> Array:
	return [
		rusher("阿土", Vector3(-12.0, 0, -6.5), [Vector3(-1.0, 0, -6.5)]),
		rusher("阿水", Vector3(7.2, 0, -13.6), [Vector3(0.6, 0, -5.0)]),
	]

func _checklist() -> Array:
	return [
		{"id": "rescue", "text": "救出企鵝"},
		{"id": "snow_hole", "text": "阿水戴雪人頭進洞", "hint": "早一點撞，阿水會偏向雪人"},
		{"id": "clean_fall2", "text": "兩人乾淨進洞", "hint": "兩人剛好同時到交叉點"},
	]

func _how_to() -> String:
	return "同時到才撞得到 [Tab]"

func _defeat_tip() -> String:
	return "要兩人同時到交叉點"

func _level_setup() -> void:
	super()
	preview_full = false
	show_timing = true
