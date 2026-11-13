extends "res://levels/ice/rescue_battle.gd"
## 【救企鵝 3】時機：只有一片香蕉皮、兩個工人。
## 紅線上每 1 秒有一個白點；瞄準時會標出「他踩到的那一刻，另一個人在哪」。

func _make_items() -> Array:
	return [
		BananaItem.new().uses_shared(1).cooldown_sec(0.0),
	]

func _enemy_specs() -> Array:
	return [
		rusher("阿土", Vector3(-12.0, 0, -6.5), [Vector3(-1.0, 0, -6.5)]),
		rusher("阿水", Vector3(6.0, 0, -12.0), [Vector3(0.6, 0, -5.0)]),
	]

func _checklist() -> Array:
	return [
		{"id": "rescue", "text": "救出企鵝"},
		{"id": "snow_hole", "text": "讓阿水戴著雪人頭泡進冰洞"},
		{"id": "clean_fall2", "text": "不碰雪人，兩個一起泡進冰洞"},
	]

func _how_to() -> String:
	return "新規則：時機\n・紅線上的白點：每 1 秒走到哪\n・瞄準時黃線上的橫槓：滑 0.5 秒（滑比跑快 3 倍）\n・白圈＝他踩到香蕉皮那一刻，另一個人在哪"

func _defeat_tip() -> String:
	return "提示：阿土滑到交叉點要多久（數黃線上的橫槓）？那時阿水要剛好走到那裡。"

func _level_setup() -> void:
	super()
	preview_full = false
	show_timing = true
