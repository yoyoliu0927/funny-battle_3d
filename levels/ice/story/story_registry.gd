extends RefCounted
## 每一大關的開場、結尾動畫放在哪、什麼時候播。選關地圖（scripts/level_select.gd）會問這裡：
##   第一次進某一章 → opening_for(章)：還沒看過、這一章一關都還沒過，就先播開場（播完它自己進第 1 關）
##   從關卡回到地圖 → ending_on_return()：剛剛玩的那一章已經全破、結尾還沒看過，就先播結尾（播完回地圖）
## 全遊戲的劇情和分鏡在 levels/ice/docs/全遊戲劇情.md、大關開場與結尾動畫.md，所以動畫都放在冰雪島的 story/ 底下，
## 不用動到其他組員的大關資料夾。只播一次（記在 user://settings.cfg 的 [story]），測試和截圖不播（見 story_kit.gd）。

const Kit := preload("res://levels/ice/story/story_kit.gd")
const Progress := preload("res://scripts/progress.gd")
const D := "res://levels/ice/story/"

## 章的 id（levels/ 底下的資料夾名）→ 開場、結尾。丹穴山的結尾就是整個遊戲的結局（丹穴山 3 自己播），這裡不用列
const CHAPTERS := {
	"ice": {"opening": D + "ice_opening.tscn", "ending": D + "ice_ending.tscn"},
	"forest": {"opening": D + "forest_opening.tscn", "ending": D + "forest_ending.tscn"},
	"liuchiyu": {"opening": D + "liuchiyu_opening.tscn", "ending": D + "liuchiyu_ending.tscn"},
	"fort": {"opening": D + "fort_opening.tscn", "ending": D + "fort_ending.tscn"},
	"heaven": {"opening": D + "heaven_opening.tscn", "ending": ""},
}

## 這一章有幾個小關（照它自己的 chapter.gd）
static func _stage_ids(id: String) -> Array:
	var path := "res://levels/%s/chapter.gd" % id
	if not ResourceLoader.exists(path):
		return []
	var ch := load(path) as Script
	if ch == null:
		return []
	var stages: Array = ch.get_script_constant_map().get("STAGES", [])
	var out: Array = []
	for i in stages.size():
		out.append("%s/%d" % [id, i + 1])
	return out

static func _path(id: String, kind: String) -> String:
	var p := String((CHAPTERS.get(id, {}) as Dictionary).get(kind, ""))
	return p if p != "" and ResourceLoader.exists(p) else ""

## 第一次進這一章要先播的開場（不用播就回傳空字串）
static func opening_for(id: String) -> String:
	var p := _path(id, "opening")
	if p == "":
		return ""
	return p if Kit.pending(id + "_opening", _stage_ids(id)) else ""

## 這一章全破了、結尾還沒播：結尾的路徑（不用播就回傳空字串）
static func ending_for(id: String) -> String:
	var p := _path(id, "ending")
	if p == "":
		return ""
	var ids := _stage_ids(id)
	if ids.is_empty():
		return ""
	for sid in ids:
		if not Progress.is_cleared(String(sid)):
			return ""
	return p if Kit.pending(id + "_ending") else ""

## 從關卡回到地圖的時候：剛剛玩的是哪一章（Engine 的 meta "stage_id"，例如 "forest/3"），那一章的結尾要不要播
static func ending_on_return() -> String:
	var sid := String(Engine.get_meta("stage_id", ""))
	if not sid.contains("/"):
		return ""
	return ending_for(sid.get_slice("/", 0))
