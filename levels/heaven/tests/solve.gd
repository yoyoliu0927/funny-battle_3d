extends SceneTree
## 仙境三關的解法檢查：照規格（docs/仙境關卡規格.md 第 4 節）的保底解法、進階解法、「不放一定輸」各跑一局，
## 看輸贏和拿到的星星對不對。不對的那一局會印出事件紀錄。
##   Godot --headless --path . --script res://levels/heaven/tests/solve.gd            （三關都跑）
##   Godot --headless --path . --script res://levels/heaven/tests/solve.gd -- 2 -v    （只跑第 2 關，每一局都印事件）
const DT := 1.0 / 60.0

## 每一局：[說明, [[道具 id, x, z], ...], 預期輸贏, [一定要有的星星], [一定不能有的星星]]
const CASES := {
	1: [
		["什麼都不放", [], "lose", [], []],
		["只放兩片香蕉皮（守衛沒處理）", [["banana", -6.0, -4.0], ["banana", -5.0, -6.67]], "lose", [], []],
		["只放巨石", [["rock", 2.4, -12.0]], "lose", [], []],
		["保底：阿土一片、阿水第一段一片、巨石", [["banana", -6.0, -4.0], ["banana", -5.0, -6.67], ["rock", 2.4, -12.0]], "win", ["rescue", "pair_hole"], []],
		["巨石放在雲階偏東、比較低的地方", [["banana", -6.0, -4.0], ["banana", -5.0, -6.67], ["rock", 3.0, -10.6]], "win", ["rescue"], []],
		["巨石放在雲階最上面、靠近南天門", [["banana", -6.0, -4.0], ["banana", -5.0, -6.67], ["rock", 2.0, -12.9]], "win", ["rescue"], []],
	],
	2: [
		["什麼都不放", [], "lose", [], []],
		["兩片都拿去整人、沒人進視線（家豪被吹走）", [["banana", -6.0, -6.5], ["banana", 4.25, -3.25]], "lose", [], []],
		["保底：阿土一片、阿水第一段一片", [["banana", -6.0, -6.5], ["banana", 5.5, -6.25]], "win", ["rescue", "luwu_blow"], ["luwu_idle"]],
		["進階：飼料繞開視線、阿水改放第二段", [["bait", 2.6, -1.0], ["banana", -6.0, -6.5], ["banana", 4.25, -3.25]], "win", ["rescue", "luwu_idle"], ["luwu_blow"]],
	],
	3: [
		["什麼都不放", [], "lose", [], []],
		["保底但唱盤上沒放飼料", [["banana", -7.0, -6.2], ["banana", -8.0, -2.5], ["banana", -6.0, -8.0]], "lose", [], []],
		["保底：三片各一批、飼料放唱盤", [["banana", -7.0, -6.2], ["banana", -8.0, -2.5], ["banana", -6.0, -8.0], ["bait", 0.0, -11.8]], "win", ["rescue", "boss_hole"], ["boss_blown"]],
		["進階：陸吾留給大老闆", [["bait", 0.0, -11.8], ["bait", -2.6, -2.5], ["banana", -7.0, -6.2], ["banana", -5.5, -1.65], ["banana", -3.85, -7.5]], "win", ["rescue", "boss_blown"], ["boss_hole"]],
		["想把陸吾留給大老闆但沒放飼料繞路（家豪先被吹走）", [["bait", 0.0, -11.8], ["banana", -7.0, -6.2], ["banana", -5.5, -1.65], ["banana", -3.85, -7.5]], "lose", [], []],
	],
}

var fails := 0

func _initialize() -> void:
	_go.call_deferred()

func _go() -> void:
	var args := OS.get_cmdline_user_args()
	var verbose := args.has("-v")
	var only := 0
	for a in args:
		if a.is_valid_int():
			only = int(a)
	for n in [1, 2, 3]:
		if only != 0 and only != n:
			continue
		change_scene_to_file("res://levels/heaven/stage_%d/stage.tscn" % n)
		for i in 10:
			await process_frame
		var bt = current_scene.get_node("Battle")
		bt.set_physics_process(false)
		bt.set_process(false)
		bt.silent = true
		for c in CASES[n]:
			bt.reset()
			var bad := ""
			for it in c[1]:
				var idx: int = bt.skill_index(String(it[0]))
				var p := Vector3(float(it[1]), bt.world.height_at(float(it[1]), float(it[2])), float(it[2]))
				var why: String = bt.placement_error(idx, p) if idx >= 0 else "沒有這個道具"
				if why != "":
					bad += "　%s (%.1f, %.1f) 放不下去：%s" % [it[0], it[1], it[2], why]
					continue
				bt.cast(idx, p)
			bt.start()
			while bt.phase == bt.Phase.RUNNING and bt.time < 60.0:
				bt._tick_cooldowns(DT)
				bt._step(DT)
			var got: Array = bt._done.keys()
			var ok: bool = bad == "" and bt.outcome == String(c[2])
			for s in c[3]:
				ok = ok and got.has(s)
			for s in c[4]:
				ok = ok and not got.has(s)
			if not ok:
				fails += 1
			print("[%s] 第 %d 關　%s → %s（%.1f 秒）星星 %s%s" % ["PASS" if ok else "FAIL", n, c[0], bt.outcome if bt.outcome != "" else "沒結束", bt.time, str(got), bad])
			if not ok or verbose:
				for e in bt.events:
					print("      %5.1f  %s" % [e.t, e.text])
	print("SOLVE: %s" % ("ALL PASS" if fails == 0 else "FAILED (%d)" % fails))
	quit(fails)
