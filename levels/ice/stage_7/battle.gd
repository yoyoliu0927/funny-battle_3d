extends "res://levels/ice/rewind_battle.gd"
## 【實驗 B1】冰湖＋倒帶：跟 3-1 同一張圖、同樣規則，多了「Q 倒帶 3 秒」。

func _make_items() -> Array:
	return [
		FeedItem.new().uses(2, 2).cooldown_sec(0.15),
	]

func _enemy_specs() -> Array:
	return [
		worker("工人1", [Vector3(-2.5, 0, -4.4)], {"yaw": 0.0}),
		worker("工人2", [Vector3(2.0, 0, -6.0), Vector3(6.0, 0, -6.0)]),
	]

func _tutorial_texts() -> Array:
	return [
		"【冰雪島】人在冰上轉不了彎、停不下來。\n讓家豪在冰洞旁邊急轉彎，追過來的人就會滑進去。",
		"【1 飼料】撒在地上，家豪會馬上跑去吃。",
		"【倒帶之神】按 Q 時間倒回 3 秒，改一個決定（每局 3 次）。\n輸了也可以倒帶！",
	]

func _prepare_hint() -> String:
	return "準備中：不確定就先試，出事了按 Q 倒帶　按 Enter 開始"

func _win_line() -> String:
	return "兩個工人都去冰洞裡泡澡了。"
