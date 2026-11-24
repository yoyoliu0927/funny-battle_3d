extends "res://scripts/items/item.gd"
## 假獵物：附近的伐木工和抽菸的人會走過來看，暫時放下斧頭和菸。狼外婆不理。
const Models := preload("res://levels/forest/items/models.gd")

const ATTRACT := 11.0

func _init() -> void:
	id = "decoy"
	name = "假獵物"
	tutorial = "放一隻假動物。附近的人會走過去看，暫時不砍樹、也不抽菸。\n小心：抽菸的人會把手上的菸丟在地上，放著不管會點著樹。\n放在木屋門口，連狼外婆也會跑去聞。小圈是落點，大圈是引得動的範圍。"
	color = Color(0.72, 0.46, 0.22)
	radius = 0.7
	icon_tex = Models.icon("decoy")      # 道具欄畫場上那個模型的樣子
	cooldown = 0.4

func placement_error(bt, p: Vector3) -> String:
	if bt.has_method("decoy_error"):
		return bt.decoy_error(p)
	return super.placement_error(bt, p)

func cast(bt, p: Vector3) -> void:
	bt.add_decoy(p)
