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
	return super(bt, p)
