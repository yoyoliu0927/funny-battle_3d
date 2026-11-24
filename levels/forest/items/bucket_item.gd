extends "res://scripts/items/item.gd"
## 水桶：潑出一圈水。圈子裡的菸蒂熄掉、著火的樹救得回來；沒著火的樹淋濕之後一陣子點不著。
## 準備階段先把怕燒的地方淋濕，開打後留幾桶來救火（次數兩段分開算，見 chapter 的 _make_items）。
const Models := preload("res://levels/forest/items/models.gd")

func _init() -> void:
	id = "bucket"
	name = "水桶"
	tutorial = "潑出一圈水：圈子裡的菸蒂會熄掉、著火的樹救得回來。\n沒著火的樹淋濕之後一陣子點不著——抽菸的人旁邊先潑一桶最保險。"
	color = Color(0.35, 0.66, 0.95)
	radius = 3.8
	icon_tex = Models.icon("bucket")
	cooldown = 0.5

func placement_error(bt, p: Vector3) -> String:
	if bt.has_method("bucket_error"):
		return bt.bucket_error(p)
	return super.placement_error(bt, p)

func cast(bt, p: Vector3) -> void:
	bt.add_bucket(p)
