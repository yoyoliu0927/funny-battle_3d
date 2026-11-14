extends "res://levels/ice/rescue_battle.gd"
## 【冰雪島 3 薄冰】雞踩薄冰沒事、人會破；飼料改黃線，守衛的箭頭跟著轉。
## 保底：香蕉皮放阿水線上（滑進阿土踩破的洞）；飼料拖到薄冰乙外側（守衛撲過來踩破冰）。

func _make_items() -> Array:
	return [
		BananaItem.new().uses_shared(1).cooldown_sec(0.0),
		# 待接：飼料一包（玩法線的 items/rescue_feed_item.gd 完成後加在這裡）
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
		# 待接：下面兩個 id 等玩法線定名（A9）
		{"id": "guard_thin", "text": "守衛踩破冰", "hint": "讓紅箭頭穿過薄冰"},
		{"id": "thin_pair", "text": "一個洞泡兩個", "hint": "那個洞還裝得下一個"},
	]

func _how_to() -> String:
	return "飼料：家豪會繞過去"

func _defeat_tip() -> String:
	if _catcher != null and _catcher.data.get("guard", false):
		return "讓守衛隔著薄冰撲過來"
	return "他的紅線通到哪？"

func _level_setup() -> void:
	super()
	preview_full = false
