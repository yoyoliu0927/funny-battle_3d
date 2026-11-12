extends "res://levels/ice/rescue_battle.gd"
## 【救企鵝 2】兩個工人。香蕉皮把巡邏的工人滑出去；守籠子的工人可以用飼料讓家豪等一下、繞一下。

func _make_items() -> Array:
	return [
		BananaItem.new().uses_shared(3).cooldown_sec(0.15),
		FeedItem.new().uses_shared(2).cooldown_sec(0.15),
	]

func _enemy_specs() -> Array:
	return [
		worker("工人1", [Vector3(-10.0, 0, -3.0)], {"yaw": PI * 0.5}),
		worker("工人2", [Vector3(9.5, 0, -4.0)], {"yaw": -PI * 0.5}),
	]

func _checklist() -> Array:
	return [
		{"id": "rescue", "text": "救出企鵝"},
		{"id": "fall2", "text": "兩個工人都掉進冰洞"},
		{"id": "carom", "text": "讓工人撞在一起"},
	]

func _tutorial_texts() -> Array:
	return [
		"【目標】救出企鵝！這次有兩個工人。",
		"【1 香蕉皮】工人在冰上踩到會一路滑出去，\n撞到別人會把別人也撞出去。",
		"【2 飼料】家豪聞到會先去吃，可以讓他等一下、繞一下。\n薄冰撐得住雞，撐不住滑過去的工人。",
	]
