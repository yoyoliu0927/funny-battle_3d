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

# ================================================================ 飼料

const FAR_GUARD := ["guard", "守衛", Vector3(15.0, 0, -16.0)]     # 站很遠的守衛：只是讓家豪維持走路的速度

func _feed_cfg(extra := {}) -> Dictionary:
	var c := {"items": [["banana", 1], ["feed", 1]], "hero": Vector3(0, 0, 8), "path": [Vector3(0, 0, 5), Vector3(0, 0, -9.4)],
		"ponds": [{"center": Vector2(-4.0, 0.0), "r": 1.3}], "snowmen": [Vector3(4.0, 0, -4.0)], "enemies": [FAR_GUARD], "stars": ["no_feed"]}
	c.merge(extra, true)
	return c

func t_feed_place() -> void:
	await load_stage(_feed_cfg())
	ok(bt.placement_error(1, g(2.5, -1.0)) == "", "黃線旁邊 2.5 公尺：可以放")
	ok(bt.placement_error(1, g(4.6, 1.0)) != "", "離黃線 4.6 公尺：太遠，不能放（%s）" % bt.placement_error(1, g(4.6, 1.0)))
	ok(bt.placement_error(1, g(-3.9, 2.4)) != "" or bt.placement_error(1, g(-3.9, -2.4)) != "", "新黃線會穿過冰洞：不能放")
	ok(bt.placement_error(1, g(3.9, -1.5)) != "" or bt.placement_error(1, g(3.9, -6.5)) != "", "新黃線會穿過雪人：不能放")
	var before: Array = bt.path.duplicate()
	ok(bt.cast(1, g(2.5, -1.0)) and bt.path.size() == before.size() + 1, "放下去：黃線多一個轉折點")
	ok(bt.flat_dist(bt.path[1], Vector3(2.5, 0, -1.0)) < 0.01, "轉折點插在最近那一段的兩個端點之間")
	bt.reset()
	ok(bt.path.size() == before.size() and bt.feed_pos == null, "重來後黃線還原")
	bt.start()
	ok(not bt.cast(1, g(2.5, -1.0)), "開打後不能放")

func t_feed_walk() -> void:
	# 家豪實際走的路貼著黃線；到每個轉折點的時間和照黃線算的一樣
	await load_stage(_feed_cfg())
	bt.cast(1, g(3.0, -1.5))
	var line: Array = [bt.bird.start_pos]
	for p in bt.path:
		line.append(g(p.x, p.z))
	line.append(bt.world.cage)
	var want: Array = []
	var acc := 0.0
	for i in range(1, line.size() - 1):
		acc += bt.flat_dist(line[i - 1], line[i])
		if bt.flat_dist(line[i], bt.world.cage) > bt.CAGE_REACH + 0.3:      # 籠門前的最後一個點走不到（先到籠子了）
			want.append(acc / bt.BIRD_WALK)
	var got: Array = []
	var worst := {"d": 0.0}
	run(40.0, func():
		var bp: Vector3 = bt.bird.pos
		var best := 1e9
		for i in range(1, line.size()):
			var a: Vector3 = line[i - 1]
			var b: Vector3 = line[i]
			var ab := Vector2(b.x - a.x, b.z - a.z)
			var t := clampf(Vector2(bp.x - a.x, bp.z - a.z).dot(ab) / ab.length_squared(), 0.0, 1.0)
			best = minf(best, bt.flat_dist(a.lerp(b, t), bp))
		worst.d = maxf(worst.d, best)
		if got.size() < want.size() and bt.flat_dist(bp, line[got.size() + 1]) < 0.31:
			got.append(bt.time))
	ok(worst.d <= 0.305, "家豪離黃線最遠 %.2f 公尺（要在 0.3 以內）" % worst.d)
	var tmax := 0.0
	for i in mini(got.size(), want.size()):
		tmax = maxf(tmax, absf(float(got[i]) - float(want[i]) + 0.3 / bt.BIRD_WALK))
	ok(got.size() == want.size() and tmax < 0.2, "到每個轉折點的時間誤差最大 %.2f 秒（要小於 0.2）" % tmax)
	ok(bt.outcome == "win" and ev("邊走邊啄") > 0.0 and not bt._done.has("no_feed"), "家豪路過飼料不停、照樣過關；用了飼料拿不到「不用飼料」")

func t_feed_guard() -> void:
	# 守衛的撲擊點跟著黃線變：預告的點和實際撲的點一樣；黃線繞出圈外他就不撲
	await load_stage(_feed_cfg({"enemies": [["guard", "守衛", Vector3(1.5, 0, -1.0)]]}))
	var gd = who("守衛")
	var p0: Vector3 = bt.lunge_point(gd)
	bt.cast(1, g(2.6, 1.5))
	var p1: Vector3 = bt.lunge_point(gd)
	ok(bt.flat_dist(p0, p1) > 0.5, "放了飼料，預告的撲擊點跟著變（移了 %.1f 公尺）" % bt.flat_dist(p0, p1))
	run(12.0)
	ok(ev("守衛撲過來了") > 0.0 and bt.flat_dist(gd.data.get("lunge_to", Vector3.ZERO), p1) < 0.05, "實際撲的點和預告一致")
	await load_stage(_feed_cfg({"enemies": [["guard", "守衛", Vector3(1.5, 0, -1.0)]]}))
	bt.cast(1, g(-3.2, -1.0))
	ok(bt.planned_route(who("守衛")).size() < 2 or bt.flat_dist(bt.lunge_point(who("守衛")), who("守衛").pos) < 0.01, "黃線繞出守衛的圈：沒有紅箭頭")
	run()
	ok(ev("守衛撲過來了") < 0.0 and bt.outcome == "win", "守衛從頭站到尾，家豪過關")

# ================================================================ 追人繞洞

func _chase_cfg(flag: bool) -> Dictionary:
	# 工人的紅線停在洞的西邊，家豪的黃線在洞的東邊：直線去攔會穿過洞
	return {"hero": Vector3(3.0, 0, 8), "path": [Vector3(3.0, 0, -9.4)], "cage": Vector3(3.0, 0, -11.8),
		"ponds": [{"center": Vector2(-0.3, -3.6), "r": 1.6}],
		"enemies": [["rusher", "阿土", Vector3(-8.0, 0, -1.0), [Vector3(-3.0, 0, -1.0)]]], "flags": {"chase_avoids_holes": flag}}

func t_chase_holes() -> void:
	await load_stage(_chase_cfg(false))
	run()
	if ev("阿土掉進冰洞") < 0.0:
		for e in bt.events:
			print("     ", e.t, " ", e.text)
	ok(ev("阿土掉進冰洞") > 0.0, "旗標沒開（第 1、2 關）：照舊直線追過去，掉進洞")
	await load_stage(_chase_cfg(true))
	var crossed := {"v": false}
	run(40.0, func():
		var f = who("阿土")
		if f.state == "chase" and f.data.get("chase_to") != null and bt._crosses_hole(f.pos, f.data.chase_to):
			crossed.v = true)
	ok(ev("阿土掉進冰洞") < 0.0 and not crossed.v, "旗標開著：攔截點不會直線穿過開著的洞")
	ok(ev("阿土改追攔截點") > 0.0 or ev("阿土追不上了") > 0.0, "換下一個攔得到的點，都不行就坐下（%s）" % ("改追" if ev("阿土改追攔截點") > 0.0 else "追不上"))
	# 每個點都要穿過洞：坐下
	var c := _chase_cfg(true)
	c.ponds = [{"center": Vector2(0.0, -1.0), "r": 1.6}, {"center": Vector2(0.0, -4.4), "r": 1.6}, {"center": Vector2(0.0, -7.8), "r": 1.6}, {"center": Vector2(0.0, 2.4), "r": 1.6}, {"center": Vector2(0.0, -11.0), "r": 1.5}, {"center": Vector2(0.0, 5.6), "r": 1.5}]
	await load_stage(c)
	run()
	ok(ev("阿土追不上了") > 0.0 and ev("阿土掉進冰洞") < 0.0 and bt.outcome == "win", "沒有不穿過洞的攔截點：坐下「追不上了」")

# ================================================================ 星星條件、時機輔助的旗標

func t_stars() -> void:
	# 兩個工人排隊滑進同一個洞、守衛沒事：pair_hole、no_feed、thin_intact 拿得到；all_sunk 拿不到
	var c := {"ponds": [{"center": Vector2(5.0, -2.0), "r": 1.4}], "thin": [{"center": Vector2(-6.0, 4.0), "r": 1.1}],
		"items": [["banana", 2], ["feed", 1]], "stars": ["pair_hole", "no_feed", "thin_intact", "all_sunk"],
		"enemies": [["rusher", "阿土", Vector3(-9.0, 0, -2.0), [Vector3(-1.5, 0, -2.0)]], ["rusher", "阿水", Vector3(-11.5, 0, -2.0), [Vector3(-1.5, 0, -2.0)]], FAR_GUARD]}
	await load_stage(c)
	bt.cast(0, g(-5.0, -2.0))
	bt.cast(0, g(-6.5, -2.0))
	run()
	ok(bt.outcome == "win" and bt._done.has("pair_hole"), "兩個人泡同一個洞：pair_hole")
	ok(bt._done.has("no_feed") and bt._done.has("thin_intact"), "沒用飼料、薄冰沒破：no_feed、thin_intact")
	ok(not bt._done.has("all_sunk"), "守衛還站著：拿不到 all_sunk")
	c.enemies = [c.enemies[0], c.enemies[1]]
	await load_stage(c)
	bt.cast(0, g(-5.0, -2.0))
	bt.cast(0, g(-6.5, -2.0))
	bt.cast(1, g(2.0, 0.0))
	run()
	ok(bt.outcome == "win" and bt._done.has("all_sunk") and not bt._done.has("no_feed"), "全員泡在洞裡：all_sunk；用了飼料沒有 no_feed")

func t_aids() -> void:
	var c := {"ponds": [{"center": Vector2(5.0, -2.0), "r": 1.4}], "items": [["banana", 1]],
		"enemies": [["guard", "守衛", Vector3(15.0, 0, -16.0)], ["rusher", "阿水", Vector3(-11.5, 0, -6.0), [Vector3(-1.5, 0, 0.0)]], ["rusher", "阿土", Vector3(-9.0, 0, -2.0), [Vector3(-1.5, 0, -2.0)]]],
		"flags": {"aid_cross_mark": true, "aid_ghost": true, "aid_after_first_star": true, "aid_last_try": 1, "timing_slider": "阿土", "timing_crosser": "阿水"}}
	await load_stage(c)
	bt.silent = false
	bt.best_stars.erase(bt._stage_key())
	var pair: Array = bt._timing_pair()
	ok(pair.size() == 2 and pair[0].name == "阿土" and pair[1].name == "阿水", "誰滑誰穿越照名字指定")
	ok(not bt._aid("cross") and not bt._aid("ghost") and not bt._aid("demo") and not bt._aid("tab"), "還沒拿過第一顆星：交叉點標記和剪影不出現；示範、秒數沒開")
	bt.cast(0, g(-5.0, -2.0))
	bt.silent = true
	run()
	bt.silent = false
	bt._record_try(bt.outcome)
	ok(bt._tries.size() <= 1, "上次的記號只留 1 個")
	bt.best_stars[bt._stage_key()] = {"rescue": true}
	bt.reset()
	ok(bt._aid("cross") and bt._aid("ghost"), "拿過第一顆星再進來：交叉點標記和剪影出現")
	bt.best_stars.erase(bt._stage_key())
