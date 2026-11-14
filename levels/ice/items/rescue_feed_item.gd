extends "res://scripts/items/item.gd"
## 救企鵝模式的飼料：只在準備階段放，一包。放在黃線旁邊，家豪的黃線就會彎過去（路過不停，邊走邊啄）。
## 用法（關卡的 _make_items()）：RescueFeed.new().uses(1, 0).cooldown_sec(0.0)
## 跟共用的飼料不一樣：家豪不會「聞到就跑過去、吃完張望」，只是路線多一個轉折點。規則寫在 rescue_battle.gd（place_feed、feed_error）。

const SharedFeed := preload("res://scripts/items/feed_item.gd")

func _init() -> void:
	id = "bait"
	name = "飼料"
	tutorial = "放在黃線旁邊：家豪會繞過去。"
	color = Color(1.0, 0.85, 0.3)
	radius = 0.6
	cooldown = 0.0

func placement_error(bt, p: Vector3) -> String:
	if bt.has_method("feed_error"):
		return bt.feed_error(p)
	return super(bt, p)

func cast(bt, p: Vector3) -> void:
	# 外觀沿用共用飼料的那一小堆穀粒（放大一點）；不放進 bt.feeds，家豪的「聞飼料」行為就不會啟動
	var shared = SharedFeed.new()
	shared.cast(bt, p)
	var e: Dictionary = bt.feeds.pop_back()
	(e.node as Node3D).scale = Vector3.ONE * 1.7
	if bt.has_method("place_feed"):
		bt.place_feed(p, e.node)
