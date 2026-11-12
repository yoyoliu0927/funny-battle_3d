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
		rusher("阿水", Vector3(6.0, 0, -12.0), [Vector3(0.6, 0, -5.0)]),
	]

func _checklist() -> Array:
	return [
		{"id": "rescue", "text": "救出企鵝"},
		{"id": "carom", "text": "一片香蕉皮撞兩個人"},
		{"id": "first_try", "text": "第一次就成功（先看白點再丟）"},
	]

func _how_to() -> String:
	return "新規則：時機\n・只有一片香蕉皮，卻有兩個人\n・紅線上的白點：每 1 秒走到哪\n・瞄準時白圈＝他踩到的那一刻，另一個人在哪"

func _defeat_tip() -> String:
	return "提示：讓阿土滑出去的時候，阿水剛好擋在他前面——看白圈在哪。"

func _level_setup() -> void:
	super()
	preview_full = false
	show_timing = true
