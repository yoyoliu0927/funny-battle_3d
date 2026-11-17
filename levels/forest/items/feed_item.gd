extends "res://scripts/items/feed_item.gd"
## 跟共用飼料一樣，只是說明改成這一關的用法：把家豪引開、順便補血。

func _init() -> void:
	super()
	tutorial = "撒在地上，家豪會跑去吃，把她引到你要的方向。\n吃一把回一點血。"
	cooldown = 0.4
