extends "res://levels/ice/rescue_battle.gd"
## 【冰雪島 6 全員泡湯】五個人分前後兩批，三片香蕉皮怎麼分。
## 前一批：阿火撞守衛甲進冰洞甲。後一批：阿土、阿水各一片，或用第 5 關的時機一片解兩個；守衛乙用飼料或省下的那一片。

const RescueFeed := preload("res://levels/ice/items/rescue_feed_item.gd")

func _make_items() -> Array:
	return [
		BananaItem.new().uses_shared(3).cooldown_sec(0.0),
		RescueFeed.new().uses(1, 0).cooldown_sec(0.0),     # 飼料：只有準備階段一包
	]

## 阿土、阿水這一組的座標和第 5 關一樣
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
		{"id": "no_feed", "text": "飼料沒拆封", "hint": "守衛的紅箭頭上也能放"},
		{"id": "all_sunk", "text": "全員泡湯", "hint": "讓兩個工人撞在一起"},
	]

func _how_to() -> String:
	return "分兩批來：先南邊、再北邊"

func _defeat_tip() -> String:
	return "香蕉皮要放在冰上的紅線"

func _defeat_tip_for(who: String) -> String:
	return "先處理守衛" if who.begins_with("守衛") else "香蕉皮要放在冰上的紅線"

func _level_setup() -> void:
	super()
	preview_full = false
	chase_avoids_holes = true
	show_names_always = true
	# 「差一點」的記號從頭就有；交叉點和剪影拿過第一顆星才開（保底不需要時機）
	aid_last_try = 3
	aid_tab_seconds = true
	aid_cross_mark = true
	aid_ghost = true
	aid_after_first_star = true
	timing_slider = "阿土"
	timing_crosser = "阿水"
	win_line = "……可以回家了吧"
	caught_line = "……都最後一關了"
