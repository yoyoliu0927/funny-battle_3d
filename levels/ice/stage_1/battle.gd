extends "res://levels/ice/ice_battle.gd"
## 3-1 冰湖（教學）：學會「人在冰上轉不了彎」。
## 目標：讓兩個工人都掉進冰洞（或用別的方法打倒）。

func _make_items() -> Array:
	return [
		FeedItem.new().uses(2, 2).cooldown_sec(0.15),   # 有次數限制就不需要冷卻（0.15 秒只是防連點）
	]

func _enemy_specs() -> Array:
	return [
		worker("工人1", [Vector3(-2.5, 0, -4.4)], {"yaw": 0.0}),
		worker("工人2", [Vector3(2.0, 0, -6.0), Vector3(6.0, 0, -6.0)]),
	]

func _tutorial_texts() -> Array:
	return [
		"【冰雪島】冰雪對雞友善，對人類不友善：\n家豪在冰上不會滑，人一上冰就轉不了彎、停不下來。",
		"【1 飼料】撒在地上，家豪會忍不住跑去吃。\n讓家豪在冰洞旁邊急轉彎，追過來的人就會滑進去。",
		"人穿著很厚的羽絨衣，家豪正面打架贏不了。\n天黑之前（90 秒）讓兩個工人都掉進冰洞！",
	]

func _prepare_hint() -> String:
	return "準備中：人在冰上轉不了彎，用飼料讓家豪繞著冰洞跑　按 Enter 開始"

func _win_line() -> String:
	return "兩個工人都去冰洞裡泡澡了。"
