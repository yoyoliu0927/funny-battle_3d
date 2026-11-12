extends "res://levels/ice/ice_battle.gd"
## 3-2 薄冰：學會「薄冰撐得住雞，撐不住人」。
## 目標：家豪走到北岸的企鵝籠，救出企鵝（守衛全掉下去也算過關）。

const CAGE_REACH := 2.0

func _make_items() -> Array:
	return [
		FeedItem.new().uses(3, 1).cooldown_sec(0.15),   # 有次數限制就不需要冷卻（0.15 秒只是防連點）
	]

func _enemy_specs() -> Array:
	return [
		worker("守衛1", [Vector3(-6.0, 0, -6.0), Vector3(-2.0, 0, -6.0)]),
		worker("守衛2", [Vector3(2.0, 0, -6.0), Vector3(6.0, 0, -6.0)]),
		worker("看守", [Vector3(0.0, 0, -9.9)], {"yaw": 0.0}),
	]

func _check_end() -> String:
	if phase == Phase.RUNNING and bird_near(world.cage, CAGE_REACH):
		log_event("家豪打開了企鵝籠")
		return "win"
	return super()

func _tutorial_texts() -> Array:
	return [
		"【薄冰】顏色比較白、有裂痕的冰是薄冰。\n家豪很輕，走得過去；人一踩上去就會破。",
		"【1 飼料】把家豪引到薄冰附近，讓守衛追過來。",
		"目標：帶家豪走到北岸的企鵝籠，救出企鵝！\n（天黑前，90 秒）",
	]

func _prepare_hint() -> String:
	return "準備中：讓守衛追家豪追上薄冰　目標：走到北岸的企鵝籠　按 Enter 開始"

func _win_line() -> String:
	return "籠子打開了，企鵝們搖搖擺擺地跟著家豪走了。"

func _defeat_tip() -> String:
	return "提示：守衛會直直追向家豪。讓家豪站在薄冰的另一邊，守衛就會踩上去。"
