extends RefCounted
## 要塞大關自己的存檔（跟共用的 scripts/progress.gd 存在同一個檔案 user://progress.cfg，放在 [fort] 這一區）。
## 原本這幾個函式寫在共用的 progress.gd 裡；合併進 develop 時搬到大關資料夾，共用檔案不用改。

const PATH := "user://progress.cfg"

## 要塞已經攻下幾個小關（0~3）
static func fort_stages() -> int:
	var cf := ConfigFile.new()
	if cf.load(PATH) != OK:
		return 0
	return int(cf.get_value("fort", "stages", 0))

static func mark_fort_stage(stage: int) -> void:
	var cf := ConfigFile.new()
	cf.load(PATH)
	cf.set_value("fort", "stages", maxi(fort_stages(), stage))
	cf.save(PATH)

## 新手教學彈窗看過了沒（看過就不再自動跳出，按 H 還是能打開）
static func tutorial_seen() -> bool:
	var cf := ConfigFile.new()
	if cf.load(PATH) != OK:
		return false
	return bool(cf.get_value("fort", "tutorial_seen", false))

static func mark_tutorial_seen() -> void:
	var cf := ConfigFile.new()
	cf.load(PATH)
	cf.set_value("fort", "tutorial_seen", true)
	cf.save(PATH)
