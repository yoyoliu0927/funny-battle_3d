extends "res://scripts/items/rock_item.gd"
## 仙境的巨石：就是共用的巨石（滾動規則完全沒改），只多一條限制——只能放在雲階（斜坡）上。
## 準備階段放下去先停著（路線照樣畫出來），按開始才滾。規格 3.7。
## 用法（關卡的 _make_items()）：StairRock.new().uses(1, 0).cooldown_sec(0.0)

func _init() -> void:
	super()
	tutorial = "放在雲階上：開打後自己滾下去。"
	cooldown = 0.0

func placement_error(bt, p: Vector3) -> String:
	if bt.world.has_method("on_stairs") and not bt.world.on_stairs(p.x, p.z):
		return "巨石只能放在雲階上"
	# 南天門立在雲階中間：放在門的正後方（北邊）會被門擋住滾不下去，放的時候就說，不要讓人開打後才發現
	var gate: Vector3 = bt.world.cage
	if String(bt.world.get("goal")) == "gate" and ((p.z < gate.z + 0.4 and absf(p.x - gate.x) < 1.38) or Vector2(p.x - gate.x, p.z - gate.z).length() < 1.45):
		return "南天門擋著，巨石滾不下去：往旁邊放"
	return super(bt, p)
