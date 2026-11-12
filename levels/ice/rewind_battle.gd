extends "res://levels/ice/ice_battle.gd"
## 【實驗 B】倒帶之神：原本的玩法（家豪自己打、你用道具幫），多一個神蹟「倒帶」。
##
##   - 按 Q：時間倒回 3 秒，你可以改一個決定（每局 3 次）
##   - 輸了也能倒帶：看到家豪被打倒，倒回去改，不用整局重來
##   - 倒帶怎麼做到的：戰局每次都一樣（沒有亂數），所以從頭照你做過的事快速重播到 3 秒前就好
##
## 想法來源：評審說「重來成本要低才能精通」「最好笑的是看到慘劇發生的那一刻」。

const REWIND_SEC := 3.0
const REWINDS := 3

var rewinds_left := REWINDS
var _timeline: Array = []      # 你做過的事 {t, i, pos, prep}
var _replaying := false

func _level_setup() -> void:
	super()
	var hint := get_node_or_null("../HUD/Hint") as Label
	if hint:
		hint.text = "WASD 飄移｜空白 上升｜Shift 下降｜滑鼠 轉視角｜數字鍵／滾輪 選道具｜左鍵 施放｜Enter 開始｜Q 倒帶 3 秒｜按住 F 快轉｜R 重來｜M 地圖"

func _level_reset() -> void:
	super()
	if not _replaying:
		rewinds_left = REWINDS
		_timeline.clear()

## 記下每一次施放（倒帶重播要用）
func cast(i: int, p: Vector3) -> bool:
	var was_prep := phase == Phase.PREPARE
	var t := time
	var ok: bool = super(i, p)
	if ok and not _replaying:
		_timeline.append({"t": t, "i": i, "pos": p, "prep": was_prep})
	return ok

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_Q:
		rewind()
		get_viewport().set_input_as_handled()
		return
	super(event)

## 倒帶：重新開始一局，照記錄快速重播到 3 秒前
func rewind() -> void:
	if phase == Phase.PREPARE:
		return
	if rewinds_left <= 0:
		toast("倒帶用完了（按 R 重來）", 1.4)
		return
	var target := maxf(time - REWIND_SEC, 0.0)
	var keep: Array = _timeline.filter(func(c): return c.prep or float(c.t) < target - 0.000001)
	var left := rewinds_left - 1
	_replaying = true
	silent = true
	reset()
	no_cooldown = true
	for c in keep:
		if c.prep:
			cast(int(c.i), c.pos)
	start()
	var runs: Array = keep.filter(func(c): return not c.prep)
	var k := 0
	while phase == Phase.RUNNING and time < target - 0.000001:
		while k < runs.size() and float(runs[k].t) <= time + 0.000001:
			cast(int(runs[k].i), runs[k].pos)
			k += 1
		_step(SIM_DT)
	no_cooldown = false
	silent = false
	_replaying = false
	_timeline = keep
	rewinds_left = left
	_apply_visuals()
	Engine.time_scale = 1.0
	_slowmo_until = Time.get_ticks_msec() + 500   # 倒帶後先慢一下，讓你看清楚
	toast("⏪ 倒帶 3 秒！（還剩 %d 次）" % rewinds_left, 1.6)
	sfx("undo")
	log_event("倒帶到 %.1f 秒" % time)

func _defeat_tip() -> String:
	if rewinds_left > 0:
		return "按 Q 倒帶 3 秒，改一個決定（還剩 %d 次）。按 R 從頭來。" % rewinds_left
	return super()

func _lose_line(left: int) -> String:
	var base := super(left)
	return base + ("　｜　按 Q 倒帶 3 秒" if rewinds_left > 0 else "")
