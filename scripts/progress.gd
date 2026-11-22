extends RefCounted
## 存檔：記錄哪些小關過了（user://progress.cfg）。小關的 id 長這樣："example_farm/1"、"tainan/2"。
## 解鎖規則：每個大關的第 1 小關一開始就能玩；第 n 小關要先過第 n-1 小關。
## 開發版（編輯器、命令列執行）不擋：沒解鎖也能進，方便測試。
##
## 「哪些小關過了」只在第一次用到時讀一次檔，之後放在記憶體裡（選關地圖每一畫面會問上百次，
## 每次都讀檔在網頁版會很卡）。同一個檔案的其他區段（[fort]、[map]…）各關會自己讀寫，這裡不碰。

const PATH := "user://progress.cfg"

static var _cleared := {}        # 小關 id → true
static var _loaded := false

static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	_cleared.clear()
	var cf := ConfigFile.new()
	if cf.load(PATH) != OK or not cf.has_section("cleared"):
		return
	for k in cf.get_section_keys("cleared"):
		if bool(cf.get_value("cleared", k, false)):
			_cleared[k] = true

## 存檔被外面改掉（例如測試工具刪檔）時呼叫，下次會重新讀檔
static func reload() -> void:
	_loaded = false

static func is_cleared(stage_id: String) -> bool:
	_ensure()
	return _cleared.has(stage_id)

static func mark_cleared(stage_id: String) -> void:
	_ensure()
	_cleared[stage_id] = true
	# 寫檔照舊：先讀整個檔再改，才不會蓋掉其他關存在同一個檔案的資料
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
