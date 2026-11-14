extends "res://levels/ice/rescue_battle.gd"
## 【冰雪島 2 守衛】守衛不怕香蕉皮，要把別人撞過去。
## 保底：一片放阿土第一段（撞上守衛、兩人進冰洞甲），一片放阿水第一段（滑進冰洞乙）。
## 進階：只丟一片在阿土第一段靠後的位置，阿土先撞上走到線上的阿水，再帶走守衛。

func _make_items() -> Array:
	return [
		BananaItem.new().uses_shared(2).cooldown_sec(0.0),
	]

func _enemy_specs() -> Array:
	return [
		rusher("阿土", Vector3(-11.0, 0, -6.8), [Vector3(-3.0, 0, -6.8), Vector3(-2.0, 0, -1.0)]),
		guard("守衛", Vector3(2.5, 0, -6.8)),
		rusher("阿水", Vector3(-6.6, 0, -12.4), [Vector3(-0.6, 0, -6.4), Vector3(-0.6, 0, -3.6)]),
	]

func _checklist() -> Array:
	return [
		{"id": "rescue", "text": "救出企鵝"},
		{"id": "pile", "text": "有人倒栽雪堆", "hint": "紅線的另一段通到哪？"},
		{"id": "one_banana", "text": "只丟一片香蕉皮", "hint": "等第二個人走到線上 [Tab]"},
	]

func _how_to() -> String:
	return "守衛：家豪走進紅圈才會撲"

func _defeat_tip() -> String:
	if _catcher != null and _catcher.data.get("guard", false):
		return "守衛會被什麼撞到？"
	return "另一條紅線也能放"

func _level_setup() -> void:
	super()
	preview_full = false   # 第 2 關開始：瞄準只給方向，結果自己想
