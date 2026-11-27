extends "res://scripts/items/item.gd"
## 引路點：家豪照放下的順序一個一個走過去，沿路遇到人就打。
const Models := preload("res://levels/forest/items/models.gd")

func _init() -> void:
	id = "guide"
	name = "引路點"
	tutorial = "點在地上。家豪會照你放下的順序一個一個走過去。\n路上遇到人會停下來打、踩到菸蒂會踩熄。點上的數字就是他的順序。"
	color = Color(0.95, 0.86, 0.25)
	radius = 0.55
	icon_tex = Models.icon("guide")      # 道具欄畫場上那個模型的樣子
	cooldown = 0.15

func placement_error(bt, p: Vector3) -> String:
	if bt.has_method("guide_error"):
		return bt.guide_error(p)
	return super.placement_error(bt, p)

func cast(bt, p: Vector3) -> void:
	bt.add_guide(p)
