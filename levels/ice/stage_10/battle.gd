extends "res://levels/ice/rescue_battle.gd"
## 【救企鵝 2】守衛站著不動，香蕉皮對他沒用。把衝過來的工人滑過去撞他，兩個一起進洞。

func _make_items() -> Array:
	return [
		BananaItem.new().uses_shared(2).cooldown_sec(0.0),
	]

func _enemy_specs() -> Array:
	return [
		rusher("工人", Vector3(-11.0, 0, -6.8), [Vector3(-3.0, 0, -6.8), Vector3(-2.0, 0, -1.0)]),
		guard("守衛", Vector3(2.5, 0, -6.8)),
	]

func _checklist() -> Array:
	return [
		{"id": "rescue", "text": "救出企鵝"},
		{"id": "guard_carom", "text": "一片香蕉皮撞兩個人"},
		{"id": "guard_slip", "text": "讓守衛自己撲上香蕉皮"},
	]

func _how_to() -> String:
	return "新角色：守衛\n・平常站著不動（踩不到香蕉皮）\n・家豪走進紅圈，他會沿紅色箭頭撲過去\n・滑出去的人撞到別人，會一起滑走\n・被甩到家豪後面的人，就追不上了"

func _defeat_tip() -> String:
	return "提示：站著不動的守衛踩不到香蕉皮……那他什麼時候會動？會被什麼撞到？"

func _level_setup() -> void:
	super()
	preview_full = false   # 第 2 關開始：瞄準只給方向，結果自己想
