extends "res://levels/heaven/heaven_battle.gd"
## 【丹穴山 1 雲階】教畫門：滑進一幅畫，會從另一幅畫出來，方向是出口那扇門朝的方向。
## 保底：阿土、阿水各一片（都從門乙滑出來進雲洞）；守衛用巨石（放在雲階上，開打後滾下去）。
## 進階：只丟一片在阿土線上靠後的位置，阿土撞上走到線上的阿水，兩人一起穿門。

const StairRock := preload("res://levels/heaven/items/stair_rock_item.gd")

func _make_items() -> Array:
	return [
		BananaItem.new().uses_shared(2).cooldown_sec(0.0),
		StairRock.new().uses(1, 0),
	]

func _enemy_specs() -> Array:
	return [
		rusher("阿土", Vector3(-11.0, 0, -4.0), [Vector3(-2.0, 0, -4.0)]),
		rusher("阿水", Vector3(-9.0, 0, -8.0), [Vector3(-3.0, 0, -6.0), Vector3(-1.0, 0, -3.0)]),
		guard("守衛", Vector3(1.6, 0, -8.6)),
	]

func _checklist() -> Array:
	return [
		{"id": "rescue", "text": "抵達南天門"},
		{"id": "pair_hole", "text": "一個水潭泡兩個", "hint": "兩條紅線都通到同一扇門"},
		{"id": "one_banana", "text": "只丟一片香蕉皮", "hint": "等第二個人走到線上 [Tab]"},
	]

func _how_to() -> String:
	return "滑進畫門，會從另一扇門出來"

## 按 H 的說明卡「這一關」：規則（右邊）和兩層提示（左邊，輸 1 次、3 次才打開；後面那張比較直白）
func _level_rule() -> String:
	return "滑進一幅畫，會從另一幅畫出來，往那扇門朝的方向繼續滑。\n\n巨石只能放在雲階上，開打後自己滾下去。"

func _level_hints() -> Array:
	return [
		"紅線的延長線通到哪一幅畫？從另一扇門出來之後，他會滑去哪？",
		"阿土、阿水各丟一片，讓他們從另一扇門滑出來掉進水潭；守衛用巨石：放在他後面的雲階上（避開南天門）。",
	]

func _defeat_tip() -> String:
	return "紅線的延長線通到哪一幅畫？"

func _defeat_tip_for(who: String) -> String:
	match who:
		"守衛": return "巨石放在守衛後面的雲階上（避開南天門）：開打後會滾下來"
		"阿水": return "他的另一段通到哪？"
	return super(who)

func _level_setup() -> void:
	super()
	show_names_always = true
	intro_tags = ["畫門"]            # 這一關新登場：畫門的名牌常駐（其他名牌指到才出現）
	aid_last_try = 1
	aid_tab_seconds = true
	timing_slider = "阿土"
	timing_crosser = "阿水"
	win_line = "……門還會動"
	caught_line = "……這裡也有你們"
