extends "res://levels/ice/rescue_battle.gd"
## 【冰雪島 5 尖峰時刻】時機：阿土要在阿水穿過滑行線的那一刻滑出去（和 stage_11 同一組座標）。
## 保底：飼料讓守衛踩破薄冰；一片放阿火線上（滑進冰洞乙）；一片放阿土線上對的位置（撞上阿水，兩人進冰洞甲）。

const RescueFeed := preload("res://levels/ice/items/rescue_feed_item.gd")

func _make_items() -> Array:
	return [
		BananaItem.new().uses_shared(2).cooldown_sec(0.0),
		RescueFeed.new().uses(1, 0).cooldown_sec(0.0),     # 飼料：只有準備階段一包
	]

## 阿土、阿水這一組和 stage_11 一模一樣（不能動）
func _enemy_specs() -> Array:
	return [
		rusher("阿土", Vector3(-12.0, 0, -6.5), [Vector3(-1.0, 0, -6.5)]),
		rusher("阿水", Vector3(7.2, 0, -13.6), [Vector3(0.6, 0, -5.0)]),
		rusher("阿火", Vector3(9.0, 0, -3.4), [Vector3(1.2, 0, -3.4)]),
		guard("守衛", Vector3(-1.5, 0, -2.0)),
	]

func _checklist() -> Array:
	return [
		{"id": "rescue", "text": "救出企鵝"},
		{"id": "snow_hole", "text": "雪人頭也下水", "hint": "早一點撞"},
		{"id": "clean_fall2", "text": "沒碰雪人進洞", "hint": "兩人同時到交叉點"},
	]

func _how_to() -> String:
	return "同時到才撞得到 [Tab]"

func _defeat_tip() -> String:
	return "要兩人同時到交叉點"

func _defeat_tip_for(who: String) -> String:
	return "先處理守衛" if who == "守衛" else ""

func _level_setup() -> void:
	super()
	preview_full = false
	chase_avoids_holes = true
	show_names_always = true
	# 時機輔助一進關就開（不做開場示範）；剪影只畫穿過阿土那條線的阿水
	aid_cross_mark = true
	aid_ghost = true
	aid_last_try = 3
	aid_tab_seconds = true
	timing_slider = "阿土"
	timing_crosser = "阿水"
	win_line = "……走路要看路"
	caught_line = "……塞車也抓得到我"
