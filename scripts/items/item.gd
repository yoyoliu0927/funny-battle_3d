extends RefCounted
## 道具（神蹟）的基底。所有關卡共用（template）。
##
## 在關卡的 battle.gd 裡這樣挑道具、設次數：
##   const FeedItem := preload("res://scripts/items/feed_item.gd")
##   func _make_items() -> Array:
##       return [
##           FeedItem.new().uses(2, -1),            # 準備階段 2 次、開打後不限次數
##           BananaItem.new().uses_shared(3),       # 準備＋開打共用 3 次
##           RockItem.new().uses(0, 2).cooldown_sec(6.0),
##       ]
##   -1 代表不限次數（技能欄顯示 ∞）。
##
## 想做新道具：在自己的關卡資料夾新增一個 .gd，extends "res://scripts/items/item.gd"，
## 在 _init() 設好 id / name / tutorial / color，覆寫 cast()（必要）、step()、placement_error()、preview_path()。
## 道具圖示：把 PNG 指給 icon；沒有圖片的話技能欄會畫一個彩色圓圈＋名字的第一個字。

var id := ""
var name := ""
var tutorial := ""                 # 開場教學顯示的說明
var color := Color(1, 1, 1)        # 瞄準圈的顏色
var radius := 0.6                  # 瞄準圈的大小（公尺）
var cooldown := 1.0                # 用一次之後要等幾秒
var icon: Texture2D
var prep := -1                     # 準備階段（按開始前）能用幾次
var battle := -1                   # 開打後能用幾次
var shared := false                # true：準備＋開打共用 prep 這個次數

## 準備階段 prep 次、開打後 battle 次，兩段分開算（-1 = 不限次數）
func uses(prep_count: int, battle_count: int):
	prep = prep_count
	battle = battle_count
	shared = false
	return self

## 準備＋開打共用同一個次數（-1 = 不限次數）
func uses_shared(count: int):
	prep = count
	battle = count
	shared = true
	return self

func cooldown_sec(sec: float):
	cooldown = sec
	return self

## 準備和開打是不是同一個數字（開始時技能欄不切換）
func is_shared() -> bool:
	return shared or (prep < 0 and battle < 0)

## 某個階段一開始有幾次
func charges_for(running: bool) -> int:
	if shared:
		return prep
	return battle if running else prep

# ---------------------------------------------------------------- 給子類別覆寫

## 每次重試（R）時呼叫：把自己記的狀態清掉。場上的模型放在 bt.fx_root 底下，會被自動刪掉。
func reset(_bt) -> void:
	pass

## 這裡能不能放；可以回傳空字串，不行回傳原因（會顯示在畫面上）
func placement_error(bt, p: Vector3) -> String:
	if bt.world.in_water(p.x, p.z):
		return "不能放在水裡"
	if not bt.world.walkable(p.x, p.z):
		return "這裡放不了"
	return ""

## 放下去：在 p 生出東西
func cast(_bt, _p: Vector3) -> void:
	pass

## 戰鬥中每 1/60 秒呼叫一次（只在開打後）
func step(_bt, _dt: float) -> void:
	pass

## 瞄準時要畫的預測路徑（例如巨石會怎麼滾）；不用畫就回傳空的
func preview_path(_bt, _p: Vector3) -> PackedVector3Array:
	return PackedVector3Array()
