extends "res://levels/ice/rescue_battle.gd"
## 【冰雪島 4 排隊】順序：兩個人走同一條紅線，香蕉皮一定是前面的人先踩，雪人只擋第一個。
## 保底：第一片讓阿土撞倒雪人暈在線上；第二片放在第一片東邊，阿水滑過去把他一起推進冰洞；飼料讓守衛踩破薄冰。

const RescueFeed := preload("res://levels/ice/items/rescue_feed_item.gd")

func _make_items() -> Array:
	return [
		BananaItem.new().uses_shared(2).cooldown_sec(0.0),
		RescueFeed.new().uses(1, 0).cooldown_sec(0.0),     # 飼料：只有準備階段一包
	]

## 兩人的起點掃過線：再往西 3 公尺，他們會晚到，追著彎掉的黃線踩進薄冰，變成只放飼料也能過
func _enemy_specs() -> Array:
	return [
		rusher("阿土", Vector3(-6.5, 0, -2.0), [Vector3(-1.2, 0, -2.0)]),
		rusher("阿水", Vector3(-7.8, 0, -2.0), [Vector3(-1.2, 0, -2.0)]),
		guard("守衛", Vector3(1.5, 0, -6.5)),
	]

func _checklist() -> Array:
	return [
		{"id": "rescue", "text": "救出企鵝"},
		{"id": "guard_thin", "text": "薄冰收掉守衛", "hint": "讓紅箭頭穿過薄冰"},
		{"id": "thin_intact", "text": "薄冰一塊沒破", "hint": "黃線繞遠一點，他就不動"},
	]

func _how_to() -> String:
	return "前面的人先踩到"

func _defeat_tip() -> String:
	return "後面那個也要一片"

func _defeat_tip_for(who: String) -> String:
	if who == "守衛":
		return "守衛還沒處理"
	return "兩片放近一點" if who == "阿土" else "後面那個也要一片"

func _level_setup() -> void:
	super()
	preview_full = false
	chase_avoids_holes = true
	show_names_always = true
	aid_last_try = 3
	win_line = "……後面的不用排了"
	caught_line = "……有人插隊"
