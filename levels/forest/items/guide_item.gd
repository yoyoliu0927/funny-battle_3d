extends "res://scripts/items/item.gd"
## 引路點：家豪會先去離她最近的點，再到下一個最近的，沿路遇到人就打。

func _init() -> void:
	id = "guide"
	name = "引路點"
	tutorial = "點在地上。家豪會依「離她現在多近」的順序走過去，近的先走。\n路上遇到人會停下來打。點上的數字就是她接下來的順序。"
	color = Color(0.95, 0.86, 0.25)
	radius = 0.55
	cooldown = 0.15

func placement_error(bt, p: Vector3) -> String:
	if bt.has_method("guide_error"):
		return bt.guide_error(p)
	return super.placement_error(bt, p)

func cast(bt, p: Vector3) -> void:
	bt.add_guide(p)
