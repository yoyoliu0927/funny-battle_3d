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
		{"id": "fall1", "text": "讓工人滑進冰洞"},
		{"id": "snow_hole", "text": "讓他戴著雪人頭掉進冰洞"},
	]

func _how_to() -> String:
	return "怎麼玩\n・黃線：家豪自己走去籠子\n・紅線：工人衝過來抓他\n・香蕉皮丟在紅線上，他會順著那一段滑出去\n　（拿著香蕉皮瞄紅線，黃線＝他會滑去哪）"

func _defeat_tip() -> String:
	return "提示：試試紅線的別一段？每一段滑出去的方向都不一樣。"
