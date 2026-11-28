extends RefCounted
## 冰羽踏雪的開場、結尾動畫什麼時候播（關卡腳本只要問這裡）。
##   開場：每次在選關地圖按第 1 關都先播（地圖問 story_registry.gd）。這裡的 opening_pending() 是第 1 關自己問的保險：
##         不是從地圖進來、又從來沒看過，stage_9 的 world.gd、battle.gd 才轉過去，播完進第 1 關。
##   結尾：第一次破完第 6 關，「冰羽踏雪　完成！」卡片按 Enter 之後（stage_16/battle.gd），播完回地圖。
## 看過記在 user://settings.cfg 的 [story]（結尾只播一次）；測試、截圖不播也不寫（見 story_kit.gd）。
## 開發時想重看：命令列加 -- --story（不管看過沒有都播，也不寫存檔）。

const Kit := preload("res://levels/ice/story/story_kit.gd")
const OPENING := "res://levels/ice/story/ice_opening.tscn"
const ENDING := "res://levels/ice/story/ice_ending.tscn"
const OPENING_KEY := "ice_opening"
const ENDING_KEY := "ice_ending"
## 這幾關任何一關過了（開場做出來之前就在玩的存檔），就不補播開場
const STAGE_IDS := ["ice/1", "ice/2", "ice/3", "ice/4", "ice/5", "ice/6"]

static func opening_pending() -> bool:
	return Kit.pending(OPENING_KEY, STAGE_IDS)

static func ending_pending() -> bool:
	return Kit.pending(ENDING_KEY)
