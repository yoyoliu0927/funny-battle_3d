extends "res://scripts/items/item.gd"
## 外婆的籃子：只引得動狼外婆。她去聞的時候不再守著小紅帽，家豪才救得到人；小紅帽的計時也會停。
const Models := preload("res://levels/forest/items/models.gd")

func _init() -> void:
	id = "basket"
	name = "外婆的籃子"
	tutorial = "狼外婆守著小紅帽，家豪直接進屋會被拍出來。\n把籃子放在木屋裡或門口，狼外婆會走過去聞——趁這時候讓家豪進屋救人。\n聞的時候小紅帽的計時也會停。一次只能放一個，過一陣子就沒味道了。"
	color = Color(0.86, 0.3, 0.26)
	radius = 0.5
	icon_tex = Models.icon("basket")      # 道具欄畫場上那個模型的樣子
	cooldown = 0.4

func placement_error(bt, p: Vector3) -> String:
	if bt.has_method("basket_error"):
		return bt.basket_error(p)
	return super.placement_error(bt, p)

func cast(bt, p: Vector3) -> void:
	bt.add_basket(p)
