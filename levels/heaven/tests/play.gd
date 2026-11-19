extends SceneTree
## 仙境試玩（不開視窗、不寫存檔）：先印出這一關準備階段看得到的東西，再照放法擺道具、開打，印出預告、事件、結果和星星。
##   Godot --headless --path . --script res://levels/heaven/tests/play.gd -- <關卡 1-3> ["<放法>"]
##   放法：分號分隔，每一項「道具,x,z」；道具＝banana（香蕉皮）、rock（巨石）、bait（飼料）。例："banana,-6,-4;rock,2.4,-12"
##   不給放法＝什麼都不放。加 --brief 只印場地說明、不開打。
const DT := 1.0 / 60.0

func _initialize() -> void:
	_go.call_deferred()

func _p(v) -> String:
	if v is Vector3:
		return "(%.1f, %.1f)" % [v.x, v.z]
	return "(%.1f, %.1f)" % [v.x, v.y]

func _go() -> void:
	var args := OS.get_cmdline_user_args()
	var n := 1
	var strat := ""
	var brief := false
	for a in args:
		if a == "--brief":
			brief = true
		elif a.is_valid_int():
			n = int(a)
		elif not a.begins_with("--"):
			strat = a
	Engine.set_meta("stage_id", "")
	change_scene_to_file("res://levels/heaven/stage_%d/stage.tscn" % n)
	for i in 10:
		await process_frame
	var bt = current_scene.get_node("Battle")
	var w = bt.world
	bt.set_physics_process(false)
	bt.set_process(false)
	bt.silent = true
	bt.reset()
	print("================ 丹穴山 第 %d 關 ================" % n)
	print("座標：x 往東（畫面右邊）是正、z 往南（靠近鏡頭）是正，單位公尺。")
	print("【家豪】起點 %s，沿黃線走：%s。終點「%s」在 %s。" % [_p(w.hero_start), " → ".join(w.bird_path.map(func(q): return _p(q))), w.goal_text, _p(w.cage)])
	for ct in w.courts:
		print("【白玉地（會滑）】長方形：x %.1f ~ %.1f、z %.1f ~ %.1f" % [ct.c.x - ct.hx, ct.c.x + ct.hx, ct.c.y - ct.hz, ct.c.y + ct.hz])
	for lk in w.lakes:
		print("【白玉地（會滑）】橢圓：中心 %s、東西半徑 %.1f、南北半徑 %.1f" % [_p(lk.center), lk.rx, lk.rz])
	for pd in w.ponds:
		print("【%s（洞：滑進去就出局）】中心 %s、半徑 %.1f" % [w.hole_word, _p(pd.center), pd.r])
	for p in w.snow_piles:
		print("【%s】%s（滑到旁邊停下來的人會倒栽進去）" % [w.pile_word, _p(p)])
	for i in w.door_specs.size():
		var d: Dictionary = w.door_specs[i]
		print("【畫門%s】位置 %s，正面朝 (%.1f, %.1f)，寬 2.4；跟畫門%s是一對：從正面滑進去，會從另一扇出來，沿那扇門正面的方向繼續滑。背面撞上去等於撞牆。" % [
			"甲乙丙丁"[i], _p(d.pos), d.face.x, d.face.z, "甲乙丙丁"[i + 1 if i % 2 == 0 else i - 1]])
	if not w.luwu_spec.is_empty():
		var c: Vector3 = w.luwu_spec.pos
		var f: Vector3 = (w.luwu_spec.face as Vector3).normalized()
		var a := c + f * 1.0
		var b := c + f * 5.5
		print("【陸吾】趴在 %s，面朝 (%.1f, %.1f)。金光（視線）：面前 1.0 ~ 5.5 公尺、左右各 1.1 公尺，也就是 x %.1f ~ %.1f、z %.1f ~ %.1f。第一個進金光的不管是誰都被吹走（家豪被吹走＝失敗），吹完陸吾就睡著，金光消失。" % [
			_p(c), f.x, f.z, minf(a.x, b.x) - absf(f.z) * 1.1, maxf(a.x, b.x) + absf(f.z) * 1.1, minf(a.z, b.z) - absf(f.x) * 1.1, maxf(a.z, b.z) + absf(f.x) * 1.1])
	if not w.stairs.is_empty():
		print("【雲階（斜坡，北高南低）】x %.1f ~ %.1f、z %.1f（腳下）~ %.1f（最高）。巨石只能放在這裡，開打後往南滾下去。" % [w.stairs.x0, w.stairs.x1, w.stairs.z0, w.stairs.z1])
	for p in w.pines:
		print("【石柱（擋路）】%s" % _p(p))
	var specs: Array = bt._enemy_specs()
	for i in bt.enemies.size():
		var f = bt.enemies[i]
		var s: Dictionary = specs[i]
		var line := "【%s】站在 %s" % [f.name, _p(f.pos)]
		if s.has("rush"):
			line += "，開打後沿紅線跑：%s，跑到底就衝去抓家豪" % " → ".join((s.rush as Array).map(func(q): return _p(q)))
		if s.get("guard", false):
			line += "，守衛：站著不動，家豪走近（紅色虛線圈內）就撲過去抓"
		if s.get("slow", false):
			line += "；走得慢、晚 %.0f 秒出發" % float(s.get("delay", 0.0))
		if s.get("boss", false):
			line += "；穿金釘鞋，踩到香蕉皮不會滑"
		print(line)
	for k in bt.items.size():
		var it = bt.items[k]
		print("【道具 %s】id=%s，準備階段可以放 %d 個" % [it.name, it.id, it.charges_for(false)])
	for c in bt._checklist():
		print("【星星】%s%s" % [c.text, ("（提示：%s）" % c.hint) if c.has("hint") else ""])
	print("【畫面上的便利貼】%s" % bt._how_to())
	print("規則：工人踩到香蕉皮會沿著他當時前進的方向一路滑，滑到白玉地外面才停；滑的人撞到別人，被撞的也會滑出去；滑進洞就出局。所有會抓家豪的人都處理掉、家豪走到終點＝過關。")
	if brief:
		quit()
		return
	print("---------------- 你的放法：%s" % (strat if strat != "" else "（什麼都不放）"))
	for part in strat.split(";", false):
		var v := part.strip_edges().split(",")
		if v.size() < 3:
			continue
		var idx: int = bt.skill_index(String(v[0]).strip_edges())
		var p := Vector3(float(v[1]), w.height_at(float(v[1]), float(v[2])), float(v[2]))
		var why: String = bt.placement_error(idx, p) if idx >= 0 else "這一關沒有這個道具"
		if why != "":
			print("  放不下去：%s %s → %s" % [v[0], _p(p), why])
			continue
		bt.cast(idx, p)
	if bt.has_method("predict_all"):
		for r in bt.predict_all(bt.trail()):
			print("  [預告線] %s：%s %s，在 %s" % [r.f.name, r.kind, r.text, _p(r.pos)])
	bt.start()
	while bt.phase == bt.Phase.RUNNING and bt.time < 60.0:
		bt._tick_cooldowns(DT)
		bt._step(DT)
	print("---------------- 開打之後發生的事")
	for e in bt.events:
		print("  %5.1f 秒  %s" % [e.t, e.text])
	var got: Array = bt._done.keys()
	print("---------------- 結果：%s（%.1f 秒）" % [{"win": "過關", "lose": "失敗"}.get(String(bt.outcome), "沒結束"), bt.time])
	for c in bt._checklist():
		print("  %s %s" % ["★" if got.has(c.id) else "☆", c.text])
	if String(bt.outcome) == "lose" and bt.has_method("_defeat_tip"):
		print("  失敗卡上的提示：%s" % bt._defeat_tip())
	quit()
