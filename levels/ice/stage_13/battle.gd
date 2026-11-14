extends "res://levels/ice/rescue_battle.gd"
## 【冰雪島 3 薄冰】雞踩薄冰沒事、人會破；飼料改黃線，守衛的箭頭跟著轉。
## 保底：香蕉皮放阿水線上（滑進阿土踩破的洞）；飼料拖到薄冰乙外側（守衛撲過來踩破冰）。

const RescueFeed := preload("res://levels/ice/items/rescue_feed_item.gd")

func _make_items() -> Array:
	return [
		BananaItem.new().uses_shared(1).cooldown_sec(0.0),
		RescueFeed.new().uses(1, 0).cooldown_sec(0.0),     # 飼料：只有準備階段一包
	]

func _enemy_specs() -> Array:
	return [
		rusher("阿土", Vector3(4.9, 0, 2.4), [Vector3(3.3, 0, 2.4)]),
		rusher("阿水", Vector3(0.8, 0, -11.3), [Vector3(2.8, 0, -2.0)]),
		guard("守衛", Vector3(4.5, 0, -6.5)),
	]

func _checklist() -> Array:
	return [
		{"id": "rescue", "text": "救出企鵝"},
		{"id": "guard_thin", "text": "守衛踩破冰", "hint": "讓紅箭頭穿過薄冰"},
		{"id": "pair_hole", "text": "一個洞泡兩個", "hint": "那個洞還裝得下一個"},
	]

func _how_to() -> String:
	return "飼料：家豪會繞過去"

func _defeat_tip() -> String:
	return "他的紅線通到哪？"

func _defeat_tip_for(who: String) -> String:
	return "讓守衛隔著薄冰撲過來" if who == "守衛" else "他的紅線通到哪？"

func _level_setup() -> void:
	super()
	preview_full = false
	chase_avoids_holes = true
	show_names_always = true
	win_line = "……我只是去吃飯"
	caught_line = "……飯還沒吞"
