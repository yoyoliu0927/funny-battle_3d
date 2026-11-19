extends "res://levels/heaven/heaven_battle.gd"
## 【丹穴山 2 山海迴廊】教陸吾：牠誰都吹，只吹第一個。讓人比家豪先到。
## 保底：一片放阿土線上（撞守衛、兩人進雲洞），一片放阿水第一段（滑進陸吾的視線被吹走，陸吾睡著）。
## 進階：飼料讓黃線繞開視線，阿水那一片改放第二段（倒栽雲堆），陸吾整局沒出手。

const RescueFeed := preload("res://levels/ice/items/rescue_feed_item.gd")

func _make_items() -> Array:
	return [
		BananaItem.new().uses_shared(2).cooldown_sec(0.0),
		RescueFeed.new().uses(1, 0).cooldown_sec(0.0),
	]

func _enemy_specs() -> Array:
	return [
		rusher("阿土", Vector3(-10.5, 0, -6.5), [Vector3(-3.0, 0, -6.5)]),
		guard("守衛", Vector3(1.5, 0, -6.5)),
		rusher("阿水", Vector3(7.5, 0, -8.5), [Vector3(3.5, 0, -4.0), Vector3(5.0, 0, -2.5)]),
	]

func _checklist() -> Array:
	return [
		{"id": "rescue", "text": "走過迴廊"},
		{"id": "luwu_blow", "text": "陸吾吹走一個人", "hint": "哪一條紅線通到金光？"},
		{"id": "luwu_idle", "text": "陸吾睡到最後", "hint": "黃線繞遠一點"},
	]

func _how_to() -> String:
	return "陸吾只吹第一個走進金光的"

func _defeat_tip() -> String:
	return "牠只吹第一個到的"

func _defeat_tip_for(who: String) -> String:
	match who:
		"守衛": return "守衛會被什麼撞到？"
		"阿水": return "他的紅線有兩段"
	return super(who)

func _level_setup() -> void:
	super()
	preview_full = false
	show_names_always = true
	win_line = "……牠睡了"
	caught_line = "……又是你們"
