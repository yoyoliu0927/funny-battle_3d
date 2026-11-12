extends "res://levels/ice/rescue_battle.gd"
## 【救企鵝 1】教學：只有一個工人。開打後他沿紅線衝過來，把香蕉皮丟在紅線上，他就會滑進後面的冰洞。

func _make_items() -> Array:
	return [
		BananaItem.new().uses_shared(2).cooldown_sec(0.15),
	]

func _enemy_specs() -> Array:
	return [
		worker("工人", [Vector3(-7.0, 0, -3.0)], {"yaw": PI * 0.5}),
	]

func _checklist() -> Array:
	return [
		{"id": "rescue", "text": "救出企鵝"},
		{"id": "fall1", "text": "讓工人滑進冰洞"},
		{"id": "fast", "text": "18 秒內救出企鵝"},
	]

func _level_setup() -> void:
	super()
	time_fast = 18.0

func _tutorial_texts() -> Array:
	return [
		"【目標】救出企鵝！家豪會沿著黃色虛線自己走過去。\n工人看到他會跑來攔，被碰到就輸。",
		"【1 香蕉皮】開打後，工人會沿著紅線衝過來。把香蕉皮丟在紅線上，\n他在冰上踩到會一路滑出去。瞄準時看黃線滑到哪！",
	]

func _win_line() -> String:
	return super()
