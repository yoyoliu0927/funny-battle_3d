extends SceneTree
## 每個機制的自動檢查（不開視窗）：一項一個臨時場地（tests/stage_t），跑完檢查事件和狀態。
## Godot --headless --path . --script res://levels/ice/tests/mechanics.gd [-- 只跑名字裡有這個字的項目]
const DT := 1.0 / 60.0
const SCENE := "res://levels/ice/tests/stage_t/stage.tscn"
var bt
var fails := 0
var checks := 0
var only := ""

func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		only = a[0]
	_go.call_deferred()

func ok(cond: bool, what: String) -> void:
	checks += 1
	if cond:
		print("  ok    ", what)
	else:
		fails += 1
		print("  FAIL  ", what)

func g(x: float, z: float) -> Vector3:
	return Vector3(x, bt.world.height_at(x, z), z)

## 載入一個臨時場地
func load_stage(cfg: Dictionary) -> void:
	Engine.set_meta("ice_test", cfg)
	change_scene_to_file(SCENE)
	for i in 6:
		await process_frame
	bt = current_scene.get_node("Battle")
	bt.set_physics_process(false)
	bt.set_process(false)
	bt.silent = true

## 跑到結束（或 limit 秒）；each＝每一步都呼叫的檢查
func run(limit := 40.0, each: Callable = Callable()) -> void:
	bt.start()
	while bt.phase == bt.Phase.RUNNING and bt.time < limit:
		bt._tick_cooldowns(DT)
		bt._step(DT)
		if each.is_valid():
			each.call()

func ev(key: String) -> float:
	for e in bt.events:
		if String(e.text).contains(key):
			return e.t
	return -1.0

func who(name: String):
	for f in bt.enemies:
		if f.name == name:
			return f
	return null

func _go() -> void:
	for m in get_script().get_script_method_list():
		var n: String = m.name
		if n.begins_with("t_") and (only == "" or n.contains(only)):
			print("== ", n.substr(2))
			await call(n)
	print("MECHANICS: %s（%d 項檢查，%d 項沒過）" % ["ALL PASS" if fails == 0 else "FAIL", checks, fails])
	quit()

# ================================================================ 薄冰

const THIN := [{"center": Vector2(4.0, -2.0), "r": 1.2}]

func t_thin_walk() -> void:
	# 工人走過薄冰：定住 0.3 秒再掉；定住時抓不到家豪；家豪走過不破
	await load_stage({"thin": [{"center": Vector2(0.0, 2.0), "r": 1.2}], "hero": Vector3(0, 0, 4.5), "path": [Vector3(0, 0, -9.4)],
		"enemies": [["rusher", "阿土", Vector3(3.0, 0, 2.0), [Vector3(0.0, 0, 2.0)]]], "stars": ["thin_intact"]})
	var th: Dictionary = bt.world.thin[0]
	var seen := {"bird_on": false, "state_when_bird_on": "", "caught_while_crack": false}
	run(40.0, func():
		if bt.flat_dist(bt.bird.pos, Vector3(0, 0, 2.0)) < 1.0 and not seen.bird_on:
			seen.bird_on = true
			seen.state_when_bird_on = String(th.state)
		if who("阿土").state == "crack" and bt.bird.state == "lifted":
			seen.caught_while_crack = true)
	var t_crack := ev("踩上薄冰")
	var t_break := ev("薄冰破了")
	var t_fall := ev("阿土掉進冰洞")
	ok(seen.bird_on and seen.state_when_bird_on == "solid", "家豪走過薄冰，冰沒破")
	ok(t_crack > 0.0 and absf((t_break - t_crack) - 0.3) < 0.03, "踩到後 0.3 秒冰才破（%.2f → %.2f）" % [t_crack, t_break])
	ok(absf(t_fall - t_break) < 0.02 and who("阿土").data.get("sunk", false), "冰破的同時掉下去出局")
	ok(not seen.caught_while_crack and bt.outcome == "win", "定住的人抓不到家豪，家豪過關")
	ok(not bt._done.has("thin_intact"), "薄冰破過：拿不到「薄冰沒破」")
	bt.reset()
	ok(bt.world.thin[0].state == "solid" and who("阿土").state != "crack", "重來後薄冰復原")

func t_thin_lunge() -> void:
	# 守衛撲過薄冰：定住再掉，拿到「守衛踩破冰」
	await load_stage({"thin": [{"center": Vector2(1.0, 0.83), "r": 0.7}], "enemies": [["guard", "守衛", Vector3(2.0, 0, 0.0)]], "stars": ["guard_thin"],
		"hero": Vector3(0, 0, 6)})
	var route: Array = bt.planned_route(who("守衛"))
	ok(who("守衛").data.has("thin_stop") and bt.flat_dist(route.back(), Vector3(1.0, 0, 0.83)) < 0.76, "預告：守衛的紅箭頭在薄冰邊緣截斷")
	run()
	var t_l := ev("守衛撲過來了")
	var t_c := ev("守衛踩上薄冰")
	ok(t_l > 0.0 and t_c > t_l and ev("守衛掉進冰洞") - t_c > 0.28, "守衛撲到一半踩上薄冰，定住 0.3 秒後掉下去")
	ok(bt._done.has("guard_thin") and bt.outcome == "win", "拿到「守衛踩破冰」，過關")

func t_thin_slide() -> void:
	# 滑上薄冰：定住再掉；預告的終點寫「薄冰」；破掉的洞接得住下一個滑過來的人
	await load_stage({"thin": THIN, "preview": false, "enemies": [
		["rusher", "阿土", Vector3(-9.0, 0, -2.0), [Vector3(-1.5, 0, -2.0)]],
		["rusher", "阿水", Vector3(-11.5, 0, -2.0), [Vector3(-1.5, 0, -2.0)]]], "items": [["banana", 2]], "flags": {"preview_full": false}})
	var pre: Array = bt.peel_outcome(g(-5.0, -2.0))
	ok(pre.size() >= 1 and pre.all(func(r): return String(r.text) == "薄冰"), "預告終點寫「薄冰」（實際：%s）" % (String(pre[0].text) if pre.size() > 0 else "沒有"))
	ok(bt.placement_error(0, g(4.0, -2.0)) != "" and bt.placement_error(0, g(4.0, -4.0)) == "", "香蕉皮不能放在薄冰上")
	bt.cast(0, g(-5.0, -2.0))
	bt.cast(0, g(-6.5, -2.0))
	run()
	var t_c := ev("阿土踩上薄冰")
	ok(ev("阿土踩到香蕉皮") > 0.0 and t_c > 0.0 and absf(ev("阿土掉進冰洞") - t_c - 0.3) < 0.03, "滑上薄冰：定住 0.3 秒再掉（實際結果和預告一致）")
	ok(ev("阿水掉進冰洞") > ev("阿土掉進冰洞") and ev("阿水踩上") < 0.0, "下一個滑過來的人掉進破掉的洞（已經是冰洞，不用再裂一次）")
	ok(bt.outcome == "win", "過關")

func t_thin_join() -> void:
	# 0.3 秒內又有人進來：一起掉；暈在冰上的人也一起掉
	await load_stage({"thin": [{"center": Vector2(-3.0, 3.0), "r": 1.5}], "hero": Vector3(8, 0, 8), "path": [Vector3(8, 0, -9.0)], "cage": Vector3(8, 0, -11.8),
		"enemies": [["rusher", "阿土", Vector3(-6.0, 0, 3.0), [Vector3(-2.0, 0, 3.0)]], ["rusher", "阿水", Vector3(-3.0, 0, 6.2), [Vector3(-3.0, 0, 2.0)]]]})
	run(6.0)
	ok(ev("也踩上裂開的薄冰") > 0.0, "第二個人在冰裂開的 0.3 秒內踩進來")
	ok(ev("阿土掉進冰洞") > 0.0 and absf(ev("阿土掉進冰洞") - ev("阿水掉進冰洞")) < 0.02, "兩個人一起掉")
