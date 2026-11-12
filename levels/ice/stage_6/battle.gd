extends "res://levels/ice/billiards_battle.gd"
## 【實驗 A2】連環撞：一個工人被啄飛撞到另一個，兩個一起滑。三個工人都要進洞（或心掉光）。

func _make_items() -> Array:
	return [
		BananaItem.new().uses(2, 3).cooldown_sec(0.15),
		FeedItem.new().uses(3, 3).cooldown_sec(0.15),
	]

func _enemy_specs() -> Array:
	return [
		worker("工人1", [Vector3(-2.0, 0, -1.5), Vector3(2.0, 0, -1.5)], {"pause": 1.2}),
		worker("工人2", [Vector3(4.5, 0, -1.5)], {"yaw": PI}),
		worker("工人3", [Vector3(-3.0, 0, -5.5), Vector3(1.0, 0, -5.5)], {"pause": 1.0}),
	]

func _tutorial_texts() -> Array:
	return [
		"【連環撞】被啄飛的人撞到別人，會把別人一起撞出去。",
		"【1 香蕉皮】製造破綻。工人重踢落空時也會露出破綻：\n看到頭上「重踢」倒數，就用飼料把家豪拉開！",
		"【2 飼料】決定家豪從哪邊啄。黃線是滑行路線，紅色 ✕ 會進洞。\n三個工人都要解決！",
	]

func _prepare_hint() -> String:
	return "準備中：想想誰撞誰會進洞　按 Enter 開始"

func _win_line() -> String:
	return "清台！"
