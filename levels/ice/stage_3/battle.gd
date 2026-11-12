extends "res://levels/ice/ice_battle.gd"
## 3-3 鹽（新道具）：鹽撒下去 2 秒後，那一塊厚冰會變成薄冰。自己做陷阱。
## 目標：整倒三個工人。

const SaltItem := preload("res://levels/ice/items/salt_item.gd")

func _make_items() -> Array:
	return [
		FeedItem.new().uses(2, 1).cooldown_sec(0.15),   # 有次數限制就不需要冷卻（0.15 秒只是防連點）
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
		"【1 飼料】把家豪引到你想要的地方。",
		"【2 鹽】撒在冰面上，2 秒後那一塊冰會變成薄冰。\n薄冰撐得住家豪，人一踩就破。",
		"這片湖全是厚冰，沒有現成的陷阱：自己做！\n天黑前（90 秒）整倒三個工人。",
	]

func _prepare_hint() -> String:
	return "準備中：先想好工人會從哪裡追過來，再把鹽撒在那條路上　按 Enter 開始"

func _win_line() -> String:
	return "三個工人都掉進鹽融出來的洞裡了。"

func _defeat_tip() -> String:
	return "提示：鹽要等 2 秒才會融。撒在工人追家豪「會經過」的地方，而不是他現在站的地方。"
