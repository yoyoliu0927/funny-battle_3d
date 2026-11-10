extends RefCounted
## 存檔：記錄哪些小關過了（user://progress.cfg）。小關的 id 長這樣："example_farm/1"、"tainan/2"。
## 解鎖規則：每個大關的第 1 小關一開始就能玩；第 n 小關要先過第 n-1 小關。
## 開發版（編輯器、命令列執行）不擋：沒解鎖也能進，方便測試。

const PATH := "user://progress.cfg"

static func is_cleared(stage_id: String) -> bool:
	var cf := ConfigFile.new()
	if cf.load(PATH) != OK:
		return false
	return bool(cf.get_value("cleared", stage_id, false))

static func mark_cleared(stage_id: String) -> void:
	var cf := ConfigFile.new()
	cf.load(PATH)
	cf.set_value("cleared", stage_id, true)
	cf.save(PATH)

## 第 n 小關（從 1 開始）照規則解鎖了沒
static func unlocked(chapter_id: String, n: int) -> bool:
	return n <= 1 or is_cleared("%s/%d" % [chapter_id, n - 1])

## 這個大關全部小關都過了沒
static func chapter_cleared(ch: Dictionary) -> bool:
	if ch.stages.is_empty():
		return false
	for s in ch.stages:
		if not is_cleared(s.id):
			return false
	return true
