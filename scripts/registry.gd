extends RefCounted
## 大關清單（template，所有關卡共用；各關不要改這個檔案）
##
## 自動找出 res://levels/*/chapter.gd 和 res://examples/*/chapter.gd，不用到任何共用檔案「登記」關卡，
## 所以四個人各自新增大關時不會改到同一個檔案、不會衝突。
## 資料夾名字就是大關的 id（只能用英文小寫、數字、底線）。底線開頭的資料夾（例如 _template）
## 只在開發版（編輯器、命令列執行）出現，匯出的正式版會隱藏。

const ROOTS := ["res://examples", "res://levels"]

## 回傳排好順序的大關：[{id, dir, title, city, author, order, desc, stages: [{n, id, title, desc, scene}]}]
static func chapters() -> Array:
	var out: Array = []
	for root in ROOTS:
		var dir := DirAccess.open(root)
		if dir == null:
			continue
		for sub in dir.get_directories():
			if sub.begins_with("_") and not OS.is_debug_build():
				continue
			var base: String = root.path_join(sub)
			var path := base.path_join("chapter.gd")
			if not ResourceLoader.exists(path):
				continue
			var script := load(path) as Script
			if script == null:
				push_warning("大關設定讀不到：" + path)
				continue
			var c: Dictionary = script.get_script_constant_map()
			var id: String = ("example_" + sub) if root == "res://examples" else sub
			var ch := {
				"id": id, "dir": base,
				"title": String(c.get("TITLE", sub)), "city": String(c.get("CITY", "")),
				"author": String(c.get("AUTHOR", "")), "order": int(c.get("ORDER", 100)),
				"desc": String(c.get("DESC", "")), "example": root == "res://examples",
				"stages": [],
			}
			var stages: Array = c.get("STAGES", [])
			for k in stages.size():
				var s: Dictionary = stages[k]
				var scene := String(s.get("scene", ""))
				if scene != "" and not scene.begins_with("res://"):
					scene = base.path_join(scene)
				ch.stages.append({"n": k + 1, "id": "%s/%d" % [id, k + 1],
					"title": String(s.get("title", "第 %d 小關" % (k + 1))), "desc": String(s.get("desc", "")), "scene": scene})
			out.append(ch)
	out.sort_custom(func(a, b): return a.order < b.order if a.order != b.order else a.id < b.id)
	return out

## 所有小關（給自動測試用）
static func all_stages() -> Array:
	var out: Array = []
	for ch in chapters():
		for s in ch.stages:
			out.append(s)
	return out
