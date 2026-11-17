extends "res://scripts/items/item.gd"
## 神蹟「日夜」：按住左鍵的時候是晚上，放開就變回白天。
## 晚上的時候，場地上可以用技能互動的東西（枯樹、滾石、風車、水池、火山……）會閃淡淡的藍綠色光，
## 找不到下一步的時候可以按住看一下。

const PixelIcon := preload("res://levels/liuchiyu/items/pixel_icon.gd")

var hint := ""                 # 切到這個道具時，技能欄上面那一行小字
var any_aim := true            # 準心不用指到地面也能用
var hold := true               # 按住型（見 island_battle.gd 的 _hold_tick）
var hold_any := true           # 準備階段也能按

func _init() -> void:
	id = "night"
	name = "夜"
	tutorial = "按住左鍵變成晚上，放開就變回白天。\n晚上的時候，可以互動的東西會閃淡淡的藍綠色光。"
	color = Color(0.70, 0.80, 1.0)
	hint = "按住左鍵：變成晚上，可以互動的東西會閃藍綠色的光"
	radius = 0.4
	cooldown = 0.0
	# 像素風圖示：彎月和兩顆星
	icon = PixelIcon.make([
		".............",
		"....KKKK.....",
		"...KMMMK..S..",
		"..KMMKK......",
		".KMMK........",
		".KMMK....S...",
		".KMMK........",
		".KMMMK.......",
		"..KMMMKKKK...",
		"...KMMMMMMK..",
		"....KKMMMK...",
		"......KKK....",
		".............",
	], {"M": Color(0.86, 0.92, 1.0), "S": Color(1.0, 0.88, 0.40), "K": Color(0.14, 0.18, 0.32)})

func placement_error(_bt, _p: Vector3) -> String:
	return ""

## 按一下型的入口用不到（這是按住型道具）
func cast(_bt, _p: Vector3) -> void:
	pass

## 按住的每 1/60 秒：第一下變成晚上
func hold_step(bt, _p: Vector3, _dir: Vector3, _dt: float, fresh: bool) -> void:
	if fresh:
		_night(bt, true)

## 放開（或換道具）：變回白天
func hold_end(bt) -> void:
	_night(bt, false)

func reset(bt) -> void:
	_night(bt, false)

func _night(bt, on: bool) -> void:
	var w = bt.world
	if w == null or w.get("night") == null or w.night == on:
		return
	w.night = on
	w._apply_time()
