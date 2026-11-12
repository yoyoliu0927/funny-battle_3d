extends "res://levels/ice/billiards_battle.gd"
## 【實驗 A1】冰上撞球（教學）：讓工人露出破綻，再讓家豪從對的方向啄，把他「打」進冰洞。

func _make_items() -> Array:
	return [
		BananaItem.new().uses(1, 1).cooldown_sec(0.15),
		FeedItem.new().uses(1, 2).cooldown_sec(0.15),
	]

func _enemy_specs() -> Array:
	return [
		worker("工人", [Vector3(-3.0, 0, -2.5), Vector3(2.5, 0, -2.5)], {"pause": 1.0}),
	]

func _tutorial_texts() -> Array:
	return [
		"【冰上撞球】家豪是球桿，工人是球，冰洞是球袋。\n平常啄工人沒用（羽絨衣太厚），只會「噗」。",
		"【1 香蕉皮】工人踩到會滑倒＝「破綻」。破綻時被啄，\n會沿著「家豪 → 工人」的方向一路滑到底。",
		"【2 飼料】決定家豪從哪個方向過去啄。看黃線：\n那是工人會滑的路，紅色 ✕ 就是會掉進冰洞！",
	]

func _prepare_hint() -> String:
	return "準備中：香蕉皮放在工人的路上，飼料決定家豪從哪邊啄　按 Enter 開始"

func _win_line() -> String:
	return "一桿進洞！"
