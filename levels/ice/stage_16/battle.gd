extends "res://levels/ice/rescue_battle.gd"
## 【冰雪島 6 全員泡湯】五個人分前後兩批，三片香蕉皮怎麼分。
## 前一批：阿火撞守衛甲進冰洞甲。後一批：阿土、阿水各一片，或用第 5 關的時機一片解兩個；守衛乙用飼料或省下的那一片。

func _make_items() -> Array:
	return [
		BananaItem.new().uses_shared(3).cooldown_sec(0.0),
		# 待接：飼料一包
	]

## 前兩個一定是阿土、阿水（時機輔助現在寫死看前兩個人）
func _enemy_specs() -> Array:
	return [
		rusher("阿土", Vector3(-12.0, 0, -6.5), [Vector3(-1.0, 0, -6.5)]),
		rusher("阿水", Vector3(7.2, 0, -13.6), [Vector3(0.6, 0, -5.0)]),
		rusher("阿火", Vector3(-6.5, 0, 1.2), [Vector3(-1.2, 0, 1.2)]),
		guard("守衛甲", Vector3(1.5, 0, 1.2)),
		guard("守衛乙", Vector3(-1.5, 0, -5.0)),
	]

func _checklist() -> Array:
	return [
		{"id": "rescue", "text": "救出企鵝"},
		# 待接：下面兩個 id 等玩法線定名（A9）
		{"id": "no_feed", "text": "飼料沒拆封", "hint": "守衛的紅箭頭上也能放"},
		{"id": "all_sunk", "text": "全員泡湯", "hint": "讓兩個工人撞在一起"},
	]

func _how_to() -> String:
	return "分兩批來：先南邊、再北邊"

func _defeat_tip() -> String:
	if _catcher != null and _catcher.data.get("guard", false):
		return "先處理守衛"
	return "他的紅線上還沒放"

func _level_setup() -> void:
	super()
	preview_full = false
