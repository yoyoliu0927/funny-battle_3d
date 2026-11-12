extends "res://levels/ice/rewind_battle.gd"
## 【實驗 B2】鹽＋倒帶：跟 3-3 同一張圖、同樣規則，多了「Q 倒帶 3 秒」。鹽要等 2 秒才融，最適合倒帶抓時機。

const SaltItem := preload("res://levels/ice/items/salt_item.gd")

func _make_items() -> Array:
	return [
		FeedItem.new().uses(2, 1).cooldown_sec(0.15),
		SaltItem.new().uses(2, 2).cooldown_sec(0.15),
	]

func _enemy_specs() -> Array:
	return [
		worker("工人1", [Vector3(-5.0, 0, -6.5), Vector3(-1.0, 0, -6.5)]),
		worker("工人2", [Vector3(2.0, 0, -8.0), Vector3(6.0, 0, -6.0)]),
		worker("工人3", [Vector3(0.0, 0, -11.0)], {"yaw": 0.0}),
	]

func _tutorial_texts() -> Array:
	return [
		"【2 鹽】撒在冰面上，2 秒後那一塊會變成薄冰，人一踩就破。",
		"鹽要撒在工人「2 秒後會走到」的地方。\n抓不準？按 Q 倒帶 3 秒再撒一次！",
		"【倒帶之神】每局 3 次，輸了也能倒帶。\n天黑前整倒三個工人。",
	]

func _prepare_hint() -> String:
	return "準備中：撒錯了就按 Q 倒帶　按 Enter 開始"

func _win_line() -> String:
	return "三個工人都掉進鹽融出來的洞裡了。"
