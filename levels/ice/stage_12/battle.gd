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
	return "另一條紅線也能放"

func _defeat_tip_for(who: String) -> String:
	return "守衛會被什麼撞到？" if who == "守衛" else "另一條紅線也能放"

func _level_setup() -> void:
	super()
	preview_full = false   # 第 2 關開始：瞄準只給方向，結果自己想
	# 追人繞洞不開（第 1、2 關維持舊行為）
	show_names_always = true
	# 時機只在第三顆星露面：「差一點」的記號從頭就有；交叉點和剪影拿過第一顆星才開
	aid_last_try = 1
	aid_tab_seconds = true
	aid_cross_mark = true
	aid_ghost = true
	aid_after_first_star = true
	timing_slider = "阿土"
	timing_crosser = "阿水"
	win_line = "唉……一次兩個"
	caught_line = "……他不是不會動嗎"

## 新手教學（圖解）：守衛不會滑 → 走進紅圈他會撲 → 讓工人的白箭頭指到守衛 → 開始
func _tutorial_steps() -> Array:
	return [
		{"pic": ["who:守衛", "plus", "banana+no"], "say": "守衛站著不動，香蕉皮對他沒用",
			"spot": [tut_head("守衛")], "r": 1.8, "wait": "next"},
		{"pic": ["hero", "to", "ring", "to", "who:守衛"], "say": "家豪走進紅圈，守衛就撲過來",
			"spot": [_guard_feet], "r": 2.8, "wait": "next"},
		{"pic": ["who:阿土", "slide", "who:守衛+ok"], "say": "讓阿土的白箭頭指到守衛",
			"spot": [tut_head("阿土"), tut_head("守衛")], "r": 1.8, "wait": func(): return tut_aim_hits("守衛"),
			"help_after": 8.0, "help_say": "把綠圈移到阿土的紅線上", "help_spot": [tut_seg("阿土", 0), tut_seg("阿土", 1)],
			"help2_after": 18.0, "help2_say": "試試阿土紅線的第一段", "help2_spot": [tut_seg("阿土", 0)]},
		{"pic": ["lmb", "to", "banana"], "say": "按左鍵，丟下香蕉皮",
			"spot": ["center"], "wait": func(): return tut_used("banana") >= 1},
		{"pic": [], "say": "還有一片，放好就按開始（放錯按 R 重來）",
			"spot": ["start"], "wait": "start"},
	]

func _guard_feet():
	var g := tut_enemy("守衛")
	return null if g == null else g.pos + Vector3(0, 0.3, 0)
