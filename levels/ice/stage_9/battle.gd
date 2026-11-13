extends "res://levels/ice/rescue_battle.gd"
## 【救企鵝 1】教學：香蕉皮丟在紅線的哪一段，工人就往那一段的方向滑。
## 第一段在雪地上：只會跌倒；第二段：看起來對著冰洞，但會撞到雪人停下；最後一段：一路滑進冰洞。

func _make_items() -> Array:
	return [
		BananaItem.new().uses_shared(2).cooldown_sec(0.0),
	]

func _enemy_specs() -> Array:
	return [
		rusher("工人", Vector3(-9.0, 0, -8.0), [Vector3(-6.0, 0, -8.0), Vector3(-3.0, 0, -4.0), Vector3(0.0, 0, -2.5)]),
	]

func _checklist() -> Array:
	return [
		{"id": "rescue", "text": "救出企鵝"},
		{"id": "fall1", "text": "工人進冰洞", "hint": "瞄紅線的每一段，看哪一段通到冰洞"},
		{"id": "snow_hole", "text": "戴雪人頭進冰洞", "hint": "先讓他撞雪人，再丟第二片在粉紅線上"},
	]

func _how_to() -> String:
	return "把香蕉皮丟到紅線上"

func _defeat_tip() -> String:
	return "換紅線的另一段試試"

func _level_setup() -> void:
	super()
	show_goal = true    # 紅色大標題「救出企鵝！」只在第一關、第一次進來時出現

