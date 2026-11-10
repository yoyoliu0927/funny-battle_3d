extends RefCounted
## 存檔：記錄攻下到第幾關（user://progress.cfg）

const PATH := "user://progress.cfg"

static func cleared() -> int:
	var cf := ConfigFile.new()
	if cf.load(PATH) != OK:
		return 0
	return int(cf.get_value("progress", "cleared", 0))

static func mark_cleared(level: int) -> void:
	var cf := ConfigFile.new()
	cf.load(PATH)
	cf.set_value("progress", "cleared", maxi(cleared(), level))
	cf.save(PATH)
