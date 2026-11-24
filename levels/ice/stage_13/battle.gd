extends "res://levels/ice/rescue_battle.gd"
## 【冰雪島 3 薄冰】雞踩薄冰沒事、人會破；飼料改黃線，守衛的箭頭跟著轉。
## 保底：香蕉皮放阿水線上（滑進阿土踩破的洞）；飼料拖到薄冰乙外側（守衛撲過來踩破冰）。

const RescueFeed := preload("res://levels/ice/items/rescue_feed_item.gd")

func _make_items() -> Array:
	return [
		BananaItem.new().uses_shared(1).cooldown_sec(0.0),
		RescueFeed.new().uses(1, 0).cooldown_sec(0.0),     # 飼料：只有準備階段一包
	]

func _enemy_specs() -> Array:
	return [
		rusher("阿土", Vector3(4.9, 0, 2.4), [Vector3(3.3, 0, 2.4)]),
		rusher("阿水", Vector3(-0.2, 0, -10.6), [Vector3(2.5, 0, -2.0)]),
		guard("守衛", Vector3(4.5, 0, -6.5)),
	]

func _checklist() -> Array:
	return [
		{"id": "rescue", "text": "救出企鵝"},
		{"id": "guard_thin", "text": "守衛踩破冰", "hint": "讓紅箭頭穿過薄冰"},
		{"id": "pair_hole", "text": "一個洞泡兩個", "hint": "那個洞還裝得下一個"},
	]

func _how_to() -> String:
	return "飼料：家豪會繞過去"

## 按 H 的說明卡「這一關」：規則（右邊）和兩層提示（左邊，輸 1 次、3 次才打開；後面那張比較直白）
func _level_rule() -> String:
	return "雞踩薄冰沒事，人一踩就破、掉下去。\n\n飼料放在黃線旁邊，家豪會繞過去；守衛撲過來的紅箭頭也跟著轉。"

func _level_hints() -> Array:
	return [
		"守衛撲過來是走直線：讓他的紅箭頭穿過薄冰。",
		"飼料放在守衛旁邊那塊薄冰的另一邊，黃線一繞，守衛就撲過薄冰；香蕉皮丟在阿水的紅線上，讓他滑進阿土踩破的洞。",
	]

func _defeat_tip() -> String:
	return "他的紅線通到哪？"

func _defeat_tip_for(who: String) -> String:
	return "讓守衛隔著薄冰撲過來" if who == "守衛" else "他的紅線通到哪？"

func _level_setup() -> void:
	super()
	preview_full = false
	chase_avoids_holes = true
	show_names_always = true
	intro_tags = ["薄冰"]            # 這一關新登場：「薄冰」的牌子常駐（其他名牌指到才出現）
	win_line = "……我只是去吃飯"
	caught_line = "……飯還沒吞"

## 新手教學（圖解）：薄冰（雞不破、人會破）→ 拿飼料 → 放黃線旁 → 飼料也會改守衛撲的方向 → 開始
func _tutorial_steps() -> Array:
	var thin := func(k: int):
		var c: Vector2 = world.thin_spots[k].center
		return ground(Vector3(c.x, 0, c.y))
	return [
		{"pic": ["hero", "plus", "thin", "eq", "ok"], "say": "雞踩薄冰沒事",
			"spot": [thin.bind(0)], "r": 2.0, "wait": "next"},
		{"pic": ["who:阿土", "plus", "thin", "eq", "hole"], "say": "人一踩就破成冰洞",
			"spot": [thin.bind(1)], "r": 1.6, "wait": "next"},
		{"pic": ["key:2", "to", "feed"], "say": "按 2 拿起飼料",
			"spot": ["slot:1"], "wait": func(): return selected == 1,
			"help_after": 8.0, "help_say": "也可以滾滑鼠滾輪換道具"},
		{"pic": ["feed", "to", "line_y"], "say": "放在黃線旁，家豪會繞過去",
			"spot": [tut_bird_seg(0)], "r": 2.6, "wait": func(): return tut_used("bait") >= 1,
			"help_after": 14.0, "help_pic": ["aim", "plus", "lmb"], "help_say": "綠圈出現時，按左鍵放下"},
		{"pic": ["feed", "to", "line_y", "to", "turn"], "say": "黃線一彎，守衛撲的方向也跟著轉",
			"spot": [tut_head("守衛"), _lunge_end], "r": 1.8, "wait": "next"},
		{"pic": [], "say": "放好就按開始（放錯按 R 重來）",
			"spot": ["start"], "wait": "start"},
	]

## 守衛撲過去的終點（第 5 步教學的聚光燈照這裡）
func _lunge_end():
	var g := tut_enemy("守衛")
	return null if g == null else lunge_point(g)
