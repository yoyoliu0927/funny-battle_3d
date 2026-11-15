extends RefCounted
## 存檔：記錄攻下到第幾關（user://progress.cfg）

const PATH := "user://progress.cfg"

static func cleared() -> int:
	var cf := ConfigFile.new()
	if cf.load(PATH) != OK:
		return 0
	return int(cf.get_value("progress", "cleared", 0))

## 第 2 關（要塞）已經攻下幾個小關（0~3）
static func fort_stages() -> int:
	var cf := ConfigFile.new()
	if cf.load(PATH) != OK:
		return 0
	return int(cf.get_value("progress", "fort_stages", 0))

static func mark_fort_stage(stage: int) -> void:
	var cf := ConfigFile.new()
	cf.load(PATH)
	cf.set_value("progress", "fort_stages", maxi(fort_stages(), stage))
	cf.save(PATH)

static func mark_cleared(level: int) -> void:
	var cf := ConfigFile.new()
	cf.load(PATH)
	cf.set_value("progress", "cleared", maxi(cleared(), level))
	cf.save(PATH)

## 新手教學彈窗看過了沒（看過就不再自動跳出，按 H 還是能打開）
static func tutorial_seen() -> bool:
	var cf := ConfigFile.new()
	if cf.load(PATH) != OK:
		return false
	return bool(cf.get_value("progress", "tutorial_seen", false))

static func mark_tutorial_seen() -> void:
	var cf := ConfigFile.new()
	cf.load(PATH)
	cf.set_value("progress", "tutorial_seen", true)
	cf.save(PATH)
