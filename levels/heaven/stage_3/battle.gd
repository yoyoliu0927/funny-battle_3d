extends "res://levels/heaven/heaven_battle.gd"
## 【丹穴山 3 天門】集大成：畫門和陸吾一起用，五個人分兩批，陸吾只能用一次。最後一步是把飼料放在唱盤上。
## 保底：阿土一片（撞守衛進雲洞甲）、阿水第一段一片（被陸吾吹走）、大老闆那條線第一段一片（阿金撞上大老闆，兩人進雲洞乙）、
##       一把飼料放唱盤上。
## 進階（陸吾留給大老闆）：另一把飼料讓黃線繞開視線；阿水改放第二段（穿畫門、掉進雲洞甲）；
##       大老闆那條線放第二段（阿金撞上大老闆，一起滑進視線，陸吾一口氣吹走兩個）。

const RescueFeed := preload("res://levels/ice/items/rescue_feed_item.gd")

func _make_items() -> Array:
	return [
		BananaItem.new().uses_shared(3).cooldown_sec(0.0),
		RescueFeed.new().uses(2, 0).cooldown_sec(0.0),
	]

func _enemy_specs() -> Array:
	return [
		rusher("阿土", Vector3(-10.5, 0, -6.2), [Vector3(-3.5, 0, -6.2)]),
		guard("守衛", Vector3(1.5, 0, -6.2)),
		rusher("阿水", Vector3(-10.5, 0, -2.5), [Vector3(-6.0, 0, -2.5), Vector3(-5.0, 0, -0.8)]),
		slow_rusher("大老闆", Vector3(-8.0, 0, -8.0), [Vector3(-4.5, 0, -8.0), Vector3(-3.2, 0, -7.0)], 2.0, true),
		slow_rusher("阿金", Vector3(-9.5, 0, -8.0), [Vector3(-4.5, 0, -8.0), Vector3(-3.2, 0, -7.0)], 2.0),
	]

func _checklist() -> Array:
	return [
		{"id": "rescue", "text": "抵達天門"},
		{"id": "boss_hole", "text": "大老闆掉進雲洞", "hint": "他不怕香蕉皮，後面那個怕"},
		{"id": "boss_blown", "text": "陸吾吹走大老闆", "hint": "陸吾只吹一次，留給誰？"},
	]

func _how_to() -> String:
	return "唱盤上要放一把飼料"

func _defeat_tip() -> String:
	return "牠只吹第一個到的"

func _defeat_tip_for(who: String) -> String:
	match who:
		"大老闆": return "後面抬籠子的那個會滑"
		"阿金": return "後面抬籠子的那個會滑"
		"守衛": return "守衛會被什麼撞到？"
		"阿水": return "他的紅線有兩段"
	return super(who)

func _level_setup() -> void:
	super()
	preview_full = false
	show_names_always = true
	aid_last_try = 3
	win_line = "……這是唱盤"
	caught_line = "……太小了。搓不開。"
