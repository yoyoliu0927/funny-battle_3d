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


## 新手教學（圖解，一步一件事）：目標 → 誰會抓家豪 → 綠圈移到紅線 → 讓白箭頭指進冰洞 → 丟 → 開始
func _tutorial_steps() -> Array:
	var hero_at := func(): return bird.pos + Vector3(0, 0.8, 0)
	return [
		{"pic": ["hero", "line_y", "cage"], "say": "家豪會自己走去救企鵝",
			"spot": [hero_at, world.cage + Vector3(0, 1.0, 0)], "r": 1.6, "wait": "next"},
		{"pic": ["who:工人", "line_r", "hero+no"], "say": "被工人碰到就輸了",
			"spot": [tut_head("工人"), hero_at], "r": 1.6, "wait": "next"},
		{"pic": ["mouse", "to", "aim", "to", "line_r"], "say": "移動滑鼠，把綠圈移到紅線上",
			"spot": ["center", tut_seg("工人", 1)], "r": 3.0, "wait": tut_aiming_route,
			"help_after": 6.0, "help_say": "綠圈在畫面正中間，跟著滑鼠動"},
		{"pic": ["aim", "to", "slide@他會滑去哪", "to", "hole:0"], "say": "沿著紅線移動，讓白箭頭指進冰洞",
			"spot": [tut_seg("工人", 1), tut_seg("工人", 2), _pond0], "r": 2.4, "wait": func(): return tut_aim_says("冰洞"),
			"help_after": 10.0, "help_say": "紅線有三段，每一段都試試看",
			"help2_after": 20.0, "help2_say": "試試靠近冰洞的那一段", "help2_spot": [tut_seg("工人", 2), _pond0]},
		{"pic": ["lmb", "to", "banana"], "say": "按左鍵，丟下香蕉皮",
			"spot": ["center"], "wait": func(): return tut_used("banana") >= 1},
		{"pic": [], "say": "放好了！按開始看看（放錯按 R 重來）",
			"spot": ["start"], "wait": "start"},
	]

func _pond0():
	var c: Vector2 = world.ponds[0].center
	return ground(Vector3(c.x, 0, c.y))
