extends SceneTree
## 冰雪島試玩腳本：載入小關、逐幀推進、照策略施放道具、印出事件與結果。
## Godot --headless --path <專案> --script res://levels/ice/tests/play.gd -- --stage=9 --strategy="prep:0,-1.5,-3.25" [--trace]
##   --stage=N 載入 levels/ice/stage_N；--scene=res://… 直接指定場景（測試用的臨時關卡）
##   --strategy：分號分隔；prep:道具序號,x,z＝準備階段放；at:秒,道具序號,x,z＝開打後放

const DT := 1.0 / 60.0
var bt: Node
var world: Node
var stage := "1"
var strat := "none"
var trace := false
var st := {}
var scene := ""

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--stage="):
			stage = a.substr(8)
		elif a.begins_with("--strategy="):
			strat = a.substr(11)
		elif a.begins_with("--scene="):
			scene = a.substr(8)
		elif a == "--trace":
			trace = true
	change_scene_to_file(scene if scene != "" else "res://levels/ice/stage_%s/stage.tscn" % stage)
	_go.call_deferred()

func _go() -> void:
	for i in 5:
		await process_frame
	bt = current_scene.get_node("Battle")
	world = bt.world
	bt.set_physics_process(false)
	bt.set_process(false)
	if "--sweep" in OS.get_cmdline_user_args():
		await _sweep()
		quit()
		return
	bt.reset()
	_prepare()
	if bt.has_method("predict_all"):
		for r in bt.predict_all(bt.trail()):
			print("  [預告] %s：%s %s @ (%.1f,%.1f)" % [r.f.name, r.kind, r.text, r.pos.x, r.pos.z])
	bt.start()
	var last := -1.0
	while bt.phase == bt.Phase.RUNNING and bt.time < 200.0:
		if trace and bt.time - last >= 0.5:
			last = bt.time
			var s := "  T%5.1f bird %-7s (%5.1f,%5.1f) hp%.0f" % [bt.time, bt.bird.state, bt.bird.pos.x, bt.bird.pos.z, bt.bird.hp]
			for f in bt.enemies:
				s += " | %s %-6s (%5.1f,%5.1f)" % [f.name, f.state, f.pos.x, f.pos.z]
			print(s)
		_play()
		bt._tick_cooldowns(DT)
		bt._step(DT)
	for e in bt.events:
		print("  %6.2fs %s" % [e.t, e.text])
	print("RESULT stage=%s strategy=%s outcome=%s time=%.1f bird_hp=%.1f left=%d casts=%d" % [
		stage, strat, bt.outcome, bt.time, bt.bird.hp, bt.enemies_left(), bt.casts.size()])
	quit()

func g(x: float, z: float) -> Vector3:
	return Vector3(x, world.height_at(x, z), z)

func pcast(i: int, x: float, z: float) -> void:
	bt.cooldowns[i] = 0.0
	if not bt.cast(i, g(x, z)):
		print("  [準備] 施放失敗 %d @ (%.1f,%.1f)：%s" % [i, x, z, bt.placement_error(i, g(x, z))])

func once(key: String, cond: bool, i: int, x: float, z: float) -> void:
	if st.has(key) or not cond:
		return
	if bt.cast(i, g(x, z)):
		st[key] = true
		print("  [開打] %.2fs 施放 %d @ (%.1f,%.1f)" % [bt.time, i, x, z])

func _prepare() -> void:
	var parts := strat.split(";")
	for p in parts:
		if p.begins_with("prep:"):
			# prep:i,x,z
			var v := p.substr(5).split(",")
			pcast(int(v[0]), float(v[1]), float(v[2]))

func _play() -> void:
	# at:t,i,x,z → 開打後第 t 秒施放；near:k,i,x,z → 任一敵人追家豪且距離 < k 時施放
	var parts := strat.split(";")
	for idx in parts.size():
		var p: String = parts[idx]
		if p.begins_with("at:"):
			var v := p.substr(3).split(",")
			once(p, bt.time >= float(v[0]), int(v[1]), float(v[2]), float(v[3]))
		elif p.begins_with("billiard:"):
			# billiard:香蕉皮序號,飼料序號 → 會打撞球的玩家
			var v := p.substr(9).split(",")
			_billiard(int(v[0]), int(v[1]))
		elif p.begins_with("smartsalt:"):
			# smartsalt:i,lead → 有人追家豪時，把鹽撒在他前方 lead 公尺（等鹽融的時候他剛好走到）
			var v := p.substr(10).split(",")
			_smart_salt(int(v[0]), float(v[1]))
		elif p.begins_with("left:"):
			# left:n,i,x,z → 剩 n 個敵人、而且有人在追家豪時施放
			var v := p.substr(5).split(",")
			var chasing: bool = bt.enemies.any(func(f): return f.alive() and f.aggro)
			once(p, chasing and bt.enemies_left() <= int(v[0]), int(v[1]), float(v[2]), float(v[3]))
		elif p.begins_with("aggro:"):
			var v := p.substr(6).split(",")
			var any: bool = bt.enemies.any(func(f): return f.alive() and f.aggro)
			once(p, any and bt.time >= float(v[0]), int(v[1]), float(v[2]), float(v[3]))

## 掃描：每個格點各試一次「開打後有人追家豪時撒一把飼料」，印出會贏的位置
func _sweep() -> void:
	var item_i := 0
	var wins := []
	var total := 0
	var base_strat := strat
	for gx in range(-10, 11, 2):
		for gz in range(-9, 8, 2):
			if _trig() == "prep":
				strat = base_strat + ";prep:%d,%d,%d" % [_item(), gx, gz]
			else:
				strat = base_strat + ";%s,%d,%d,%d" % [_trig(), _item(), gx, gz]
			st.clear()
			bt.reset()
			_prepare()
			bt.start()
			while bt.phase == bt.Phase.RUNNING and bt.time < 200.0:
				_play()
				bt._tick_cooldowns(DT)
				bt._step(DT)
			total += 1
			if bt.outcome == "win":
				wins.append("(%d,%d) %.0fs" % [gx, gz, bt.time])
	print("SWEEP base=%s wins %d/%d: %s" % [base_strat, wins.size(), total, ", ".join(wins)])

func _trig() -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--trig="):
			return a.substr(7)
	return "aggro:0"

func _delay() -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--delay="):
			return a.substr(8)
	return "0"

func _item() -> int:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--item="):
			return int(a.substr(7))
	return 0

func _smart_salt(i: int, lead: float) -> void:
	if bt.charges[i] == 0 or bt.cooldowns[i] > 0.0:
		return
	for f in bt.enemies:
		if not f.alive() or not f.aggro or f.state != "walk":
			continue
		var to: Vector3 = bt.bird.pos - f.pos
		to.y = 0
		var d := to.length()
		if d < 2.5 or d > 8.0:
			continue
		var p: Vector3 = f.pos + to.normalized() * minf(lead, d - 0.3)
		if bt.placement_error(i, g(p.x, p.z)) == "":
			bt.cast(i, g(p.x, p.z))
			print("  [聰明鹽] %.2fs @ (%.1f,%.1f) 對 %s" % [bt.time, p.x, p.z, f.name])
			return

var _bl_feed_for := {}
func _billiard(bi: int, fi: int) -> void:
	var b = bt.bird
	# 1) 有破綻：找一個能進洞的角度，在後面撒飼料（每個破綻只撒一次）
	for f in bt.enemies:
		if not f.alive() or not bt._farmer_open(f):
			continue
		var key := "%s@%d" % [f.name, int(bt.time)]
		if _bl_feed_for.has(f.name) and bt.time - float(_bl_feed_for[f.name]) < 3.0:
			continue
		if bt.charges[fi] == 0 or bt.cooldowns[fi] > 0.0:
			continue
		var best_p = null
		for k in 36:
			var a := k * TAU / 36.0
			var dir := Vector3(cos(a), 0, sin(a))
			var res: Array = bt.predict_slide(f, dir)
			if res.is_empty() or not String(res.back().text).begins_with("✕"):
				continue
			var fp: Vector3 = f.pos - dir * 2.2
			if bt.placement_error(fi, g(fp.x, fp.z)) == "" and bt.flat_dist(b.pos, fp) < 9.5:
				best_p = fp
				break
		if best_p != null and bt.cast(fi, g(best_p.x, best_p.z)):
			_bl_feed_for[f.name] = bt.time
			print("  [撞球] %.2fs 對 %s 瞄準，飼料 @ (%.1f,%.1f)" % [bt.time, f.name, best_p.x, best_p.z])
			return
	# 1.5) 有人要重踢家豪：撒飼料把家豪拉開（順便站到能把他打進洞的角度）
	if bt.charges[fi] != 0 and bt.cooldowns[fi] <= 0.0:
		for f in bt.enemies:
			if f.alive() and f.state == "windup" and f.heavy and f.t < 0.35 and bt.flat_dist(f.pos, b.pos) < 3.0:
				var spot = null
				for k in 36:
					var a := k * TAU / 36.0
					var dir := Vector3(cos(a), 0, sin(a))
					var res: Array = bt.predict_slide(f, dir)
					if res.is_empty() or not String(res.back().text).begins_with("✕"):
						continue
					var fp: Vector3 = f.pos - dir * 2.8
					if bt.placement_error(fi, g(fp.x, fp.z)) == "":
						spot = fp
						break
				if spot == null:
					var away: Vector3 = b.pos - f.pos
					away.y = 0
					spot = f.pos + away.normalized() * 3.0
				if bt.cast(fi, g(spot.x, spot.z)):
					_bl_feed_for[f.name] = bt.time
					print("  [撞球] %.2fs %s 要重踢，撒飼料閃開 @ (%.1f,%.1f)" % [bt.time, f.name, spot.x, spot.z])
					return
	# 2) 沒有破綻：在追家豪的人前面 1.5 公尺丟香蕉皮
	if bt.charges[bi] == 0 or bt.cooldowns[bi] > 0.0:
		return
	if bt.enemies.any(func(f): return f.alive() and bt._farmer_open(f)):
		return
	var peels: Array = bt.items[bi].peels
	for f in bt.enemies:
		if f.alive() and f.aggro and f.state == "walk":
			var to: Vector3 = b.pos - f.pos
			to.y = 0
			var waiting := false
			for pl in peels:
				if bt.flat_dist(pl.pos, f.pos) < 4.0:
					waiting = true
			if waiting:
				continue
			if to.length() > 2.5 and to.length() < 7.0:
				var pp: Vector3 = f.pos + to.normalized() * 1.5
				if bt.cast(bi, g(pp.x, pp.z)):
					print("  [撞球] %.2fs 香蕉皮丟在 %s 前面" % [bt.time, f.name])
					return
