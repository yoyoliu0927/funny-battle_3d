extends SceneTree
## 森林的「自動試玩」：照一份放法打一局，印出結果和星星。不開視窗：
##   Godot --headless --path . --script res://levels/forest/tests/play.gd -- --stage=1 --plan="decoy,-9,3;guide,-9,5;bucket,-7,1.5,12"
## plan：用分號分開的道具。每項「道具id,x,z」（準備階段放）或「道具id,x,z,秒」（開打後第幾秒放）。
## 不給 plan 就用 PLANS 裡的「好好玩」放法；--plan=none 是完全不放（家豪自己打）。
## --all 把三關各用內建放法打一遍。
const DT := 1.0 / 60.0
## 每關一份「看得懂規則的人會這樣放」的放法（調整關卡數值後，用它確認過得去、拿得到星）
const PLANS := {
	1: "decoy,-9.0,0.0;decoy,9.5,-5.5;guide,-9.0,2.0;guide,9.5,-3.6;guide,7.0,7.0;guide,0,-7.2",
	2: "bucket,-7.0,1.5;bucket,7.5,-2.0,0.5;bucket,0.0,-7.0,1;guide,-7.0,3.2;guide,0.0,-5.5;guide,7.5,-0.5;guide,-10,-7.0",
	3: "bucket,8.0,1.5;guide,-10.5,4.5;guide,10.0,-3.0;guide,8.0,3.5;guide,0,3.2;decoy,0,4.0,30",
}
var bt
var fails := 0

func _initialize() -> void:
	_go.call_deferred()

func _arg(name: String, def := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % name):
			return a.substr(name.length() + 3)
		if a == "--" + name:
			return "1"
	return def

func _go() -> void:
	var stages := [int(_arg("stage", "1"))]
	if _arg("all") != "":
		stages = [1, 2, 3]
	for n in stages:
		await _play(n, _arg("plan", PLANS.get(n, "")))
	quit()

func _play(n: int, plan: String) -> void:
	change_scene_to_file("res://levels/forest/stage_%d/stage.tscn" % n)
	for i in 6:
		await process_frame
	bt = current_scene.get_node("Battle")
	bt.set_physics_process(false)
	bt.set_process(false)
	if bt.help_popup:
		bt.help_popup.visible = false
	bt._set_tut_step(-1)
	bt.reset()
	var timed: Array = []
	if plan != "none":
		for part in plan.split(";", false):
			var v := part.strip_edges().split(",")
			if v.size() < 3:
				continue
			var e := {"id": String(v[0]), "p": Vector3(float(v[1]), 0, float(v[2])), "t": float(v[3]) if v.size() > 3 else 0.0}
			if e.t <= 0.0:
				var i: int = bt.skill_index(e.id)
				if i >= 0:
					bt.cooldowns[i] = 0.0
				if i < 0 or not bt.cast(i, bt.ground(e.p)):
					print("   （準備階段放不了：%s %s）" % [e.id, bt.placement_error(i, bt.ground(e.p)) if i >= 0 else "沒有這個道具"])
			else:
				timed.append(e)
	bt.start()
	var guard := 0
	while bt.phase == bt.Phase.RUNNING and bt.time < 150.0 and guard < 20000:
		guard += 1
		for e in timed:
			if not e.get("done", false) and bt.time >= e.t:
				e["done"] = true
				var i: int = bt.skill_index(e.id)
				if i >= 0:
					bt.cooldowns[i] = 0.0
					bt.cast(i, bt.ground(e.p))
		bt._step(DT)
		if _arg("trace") != "" and guard % 300 == 0:
			var w = null
			for f in bt.enemies:
				if f.kind == "wolf":
					w = f
			print("     t=%.0f 家豪 (%.1f, %.1f) %s hp %.0f　狼 %s　引路點剩 %d" % [bt.time, bt.bird.pos.x, bt.bird.pos.z, bt.bird.state, bt.bird.hp, w.state if w else "-", bt.guides.filter(func(g): return not g.used).size()])
	var stars := []
	for c in bt._objectives():
		stars.append("%s%s" % ["★" if bt._done.has(c.id) else "☆", c.text])
	print("stage %d：%s %s　用時 %.0f 秒　家豪 %.0f/%.0f　砍 %d 燒 %d　敵人剩 %d　小紅帽 %s" % [n, bt.outcome, bt.fail, bt.time, bt.bird.hp, bt.bird.max_hp, bt.trees_cut, bt.trees_burnt, bt.enemies_left(), "救出" if bt.hood_saved else "-"])
	print("   ", "　".join(stars))
	if _arg("log") != "":
		for e in bt.events:
			print("     %5.1f  %s" % [e.t, e.text])
