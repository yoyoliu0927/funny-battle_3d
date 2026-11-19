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
	# 第 3 關（2026-11-20 重新設計，規格第 14 節）：五個人、香蕉皮只有 2 片、飼料 2 把。
	# 位置的代號：水門＝阿水第一段（穿畫門、從大老闆背後衝出來，撞走大老闆和守衛）　水光＝阿水第二段（被陸吾吹走）
	#             土一＝阿土第一段的後半（撞上阿金，兩人進星洞乙）　土二＝阿土第二段（撞上阿金，兩人進金光）
	#             盤＝唱盤上的飼料　彎＝黃線西邊的飼料（黃線繞開金光）
	3: [
		["什麼都不放", [], "lose", [], []],
		["只放唱盤的飼料", [["bait", 0.0, -11.8]], "lose", [], []],
		["解法甲：水門＋土二＋盤（陸吾一口氣吹走阿土和阿金）", [["banana", -9.0, -1.75], ["banana", -3.53, 1.65], ["bait", 0.0, -11.8]], "win", ["rescue", "luwu_two"], ["all_sunk"]],
		["解法乙：水門＋土一＋盤＋彎（五個人都進星洞）", [["banana", -9.0, -1.75], ["banana", -5.8, 2.6], ["bait", 0.0, -11.8], ["bait", -2.6, -2.5]], "win", ["rescue", "all_sunk"], ["luwu_two"]],
		["解法甲再加彎也可以", [["banana", -9.0, -1.75], ["banana", -3.53, 1.65], ["bait", 0.0, -11.8], ["bait", -2.6, -2.5]], "win", ["rescue", "luwu_two"], ["all_sunk"]],
		["解法甲的邊界：水門放最前面、土二放第二段 1.25 公尺", [["banana", -10.3, -2.4], ["banana", -4.1, 1.98], ["bait", 0.0, -11.8]], "win", ["rescue", "luwu_two"], []],
		["解法甲的邊界：水門放最後面、土二放第二段 2.5 公尺", [["banana", -7.7, -1.1], ["banana", -3.02, 1.35], ["bait", 0.0, -11.8]], "win", ["rescue", "luwu_two"], []],
		["解法乙的邊界：土一放最西邊", [["banana", -9.0, -1.75], ["banana", -6.5, 2.6], ["bait", 0.0, -11.8], ["bait", -3.5, -6.0]], "win", ["rescue", "all_sunk"], []],
		["解法乙的邊界：土一放轉彎前", [["banana", -9.0, -1.75], ["banana", -5.0, 2.6], ["bait", 0.0, -11.8], ["bait", -1.5, 1.0]], "win", ["rescue", "all_sunk"], []],
		["解法甲但唱盤上沒放飼料", [["banana", -9.0, -1.75], ["banana", -3.53, 1.65]], "lose", [], ["rescue"]],
		["解法乙但沒繞路（家豪被陸吾吹走）", [["banana", -9.0, -1.75], ["banana", -5.8, 2.6], ["bait", 0.0, -11.8]], "lose", [], ["rescue"]],
		["解法乙但繞路的飼料放在東邊（黃線還在金光裡）", [["banana", -9.0, -1.75], ["banana", -5.8, 2.6], ["bait", 0.0, -11.8], ["bait", 2.0, -6.5]], "lose", [], ["rescue"]],
		["時機：阿土第一段放太前面（阿土先滑過去，沒撞到阿金）", [["banana", -9.0, -1.75], ["banana", -7.2, 2.6], ["bait", 0.0, -11.8], ["bait", -2.6, -2.5]], "lose", [], ["rescue"]],
		["時機：阿土第二段放太前面（阿土一個人被陸吾吹走）", [["banana", -9.0, -1.75], ["banana", -4.5, 2.2], ["bait", 0.0, -11.8]], "lose", [], ["rescue", "luwu_two"]],
		["香蕉皮太靠近阿金的紅線（被阿金先踩到）", [["banana", -9.0, -1.75], ["banana", -2.6, 1.1], ["bait", 0.0, -11.8]], "lose", [], ["rescue"]],
		["香蕉皮放在石地上的紅線（只會跌倒）", [["banana", -9.0, -1.75], ["banana", -8.4, 2.6], ["bait", 0.0, -11.8]], "lose", [], ["rescue"]],
		["第 2 關的做法：水光＋土二（陸吾先吹走阿水，大老闆沒人撞）", [["banana", -6.1, -1.32], ["banana", -3.53, 1.65], ["bait", 0.0, -11.8]], "lose", [], ["rescue"]],
		["水光＋土一（大老闆沒人撞）", [["banana", -6.1, -1.32], ["banana", -5.8, 2.6], ["bait", 0.0, -11.8]], "lose", [], ["rescue"]],
		["香蕉皮放在大老闆腳下（他不怕滑）＋土二", [["banana", -5.0, -5.6], ["banana", -3.53, 1.65], ["bait", 0.0, -11.8]], "lose", [], ["rescue"]],
		["水門＋香蕉皮放在阿金的紅線上（阿土沒人處理）", [["banana", -9.0, -1.75], ["banana", -2.4, 4.0], ["bait", 0.0, -11.8]], "lose", [], ["rescue"]],
		["阿土、阿金各一片（沒有香蕉皮給阿水了）", [["banana", -7.0, 2.6], ["banana", -2.4, 4.0], ["bait", 0.0, -11.8], ["bait", -2.6, -2.5]], "lose", [], ["rescue"]],
		["水門＋盤＋彎，南邊兩個沒處理", [["banana", -9.0, -1.75], ["bait", 0.0, -11.8], ["bait", -2.6, -2.5]], "lose", [], ["rescue"]],
		["土二＋盤，大老闆那邊沒處理", [["banana", -3.53, 1.65], ["bait", 0.0, -11.8]], "lose", [], ["rescue"]],
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
		Engine.set_meta("stage_id", "")          # 不帶小關編號：贏了也不會寫進玩家的存檔
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
