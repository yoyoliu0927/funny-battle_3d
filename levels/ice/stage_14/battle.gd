extends "res://levels/ice/rescue_battle.gd"
## 【冰雪島 4 排隊】順序：兩個人走同一條紅線，香蕉皮一定是前面的人先踩，雪人只擋第一個。
## 保底：第一片讓阿土撞倒雪人暈在線上；第二片放在第一片東邊，阿水滑過去把他一起推進冰洞；飼料讓守衛踩破薄冰。

func _make_items() -> Array:
	return [
		BananaItem.new().uses_shared(2).cooldown_sec(0.0),
		# 待接：飼料一包
	]

func _enemy_specs() -> Array:
	return [
		rusher("阿土", Vector3(-9.5, 0, -2.0), [Vector3(-1.2, 0, -2.0)]),
		rusher("阿水", Vector3(-10.8, 0, -2.0), [Vector3(-1.2, 0, -2.0)]),
		# 待接：守衛 (1.5, -6.5) 等薄冰和飼料完成後加回來（現在加了就沒有任何過關解）
	]

func _checklist() -> Array:
	return [
		{"id": "rescue", "text": "救出企鵝"},
		# 待接：下面兩個 id 等玩法線定名（A9）
		{"id": "guard_thin", "text": "薄冰收掉守衛", "hint": "讓紅箭頭穿過薄冰"},
		{"id": "thin_intact", "text": "薄冰一塊沒破", "hint": "黃線繞遠一點，他就不動"},
	]

func _how_to() -> String:
	return "前面的人先踩到"

func _defeat_tip() -> String:
	if _catcher != null and _catcher.data.get("guard", false):
		return "守衛還沒處理"
	if _catcher != null and _catcher.name == "阿土":
		return "兩片放近一點"
	return "後面那個也要一片"

func _level_setup() -> void:
	super()
	preview_full = false
