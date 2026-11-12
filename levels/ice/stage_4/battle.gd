extends "res://levels/ice/route_battle.gd"
## 冰湖（路線版・對照）：跟 3-1 差不多的冰湖和兩個工人，但玩法換成「撒一條飼料路」。
## 拿來跟 3-1 比較：哪一個比較知道自己在玩什麼。

func _make_items() -> Array:
	return [RouteItem.new().uses(5, 2)]

func _enemy_specs() -> Array:
	return [
		worker("工人1", [Vector3(-3.5, 0, -10.5)], {"yaw": 0.0}),
		worker("工人2", [Vector3(4.0, 0, -10.5)], {"yaw": 0.0}),
	]

func _tutorial_texts() -> Array:
	return [
		"【飼料路線】點一下撒一段飼料，家豪會沿著路一路跑。\n工人會踩著家豪的腳印追，被碰到就輸。",
		"人在冰上轉不了彎：在冰洞旁邊急轉彎，追的人會滑進去。\n瞄準時看紅色 ✕：那裡會有人掉下去。",
		"右鍵收回最後一段，開打後點一下＝改道。\n讓兩個工人都掉進冰洞！（按住 F 快轉）",
	]

func _prepare_hint() -> String:
	return "準備中：撒一條飼料路，讓它經過紅色 ✕　按 Enter 開始"

func _win_line() -> String:
	return "兩個工人跟著家豪，一個接一個滑進冰洞。"
