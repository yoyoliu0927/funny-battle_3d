extends SceneTree
## 通用掃線：--stage=N --jobs=<檔案>。檔案每行「標籤|道具序號,x,z;道具序號,x,z…」（空的＝不放）。
## 每行印：標籤 | 結果 時間 | 星星 | 誰抓的 | 事件
const DT := 1.0 / 60.0
var stage := "12"
var jobs := ""
var verbose := false
func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--stage="):
			stage = a.substr(8)
		elif a.begins_with("--jobs="):
			jobs = a.substr(7)
		elif a == "--verbose":
			verbose = true
	change_scene_to_file("res://levels/ice/stage_%s/stage.tscn" % stage)
	_go.call_deferred()
func _go() -> void:
	for i in 10:
		await process_frame
	var bt = current_scene.get_node("Battle")
	bt.set_physics_process(false)
	bt.set_process(false)
	bt.silent = true
	var fa := FileAccess.open(jobs, FileAccess.READ)
	if fa == null or bt.world == null or not ("bird_path" in bt.world):
		print("SCRIPT ERROR: 開不了 jobs 檔或場景沒載好")
		quit()
		return
	while not fa.eof_reached():
		var line := fa.get_line().strip_edges()
		if line == "":
			continue
		var parts := line.split("|")
		bt.reset()
		var fail := ""
		if parts.size() > 1 and parts[1] != "":
			for c in parts[1].split(";"):
				var v := c.split(",")
				var p := Vector3(float(v[1]), 0, float(v[2]))
				p.y = bt.world.height_at(p.x, p.z)
				bt.cooldowns[int(v[0])] = 0.0
				if not bt.cast(int(v[0]), p):
					fail += " castfail(%s)" % c
		bt.start()
		while bt.phase == bt.Phase.RUNNING and bt.time < 60.0:
			bt._tick_cooldowns(DT)
			bt._step(DT)
		var ev: PackedStringArray = []
		for e in bt.events:
			var t: String = e.text
			if verbose or t.contains("掉進") or t.contains("撞到") or t.contains("追不上") or t.contains("抓住") or t.contains("雪堆") or t.contains("雪人") or t.contains("差一點") or t.contains("撲") or t.contains("薄冰") or t.contains("踩"):
				ev.append("%.2f %s" % [e.t, t])
		var ids: Array = bt._done.keys()
		ids.sort()
		print("JOB %s | %s %.1f%s | %s | %s | %s" % [parts[0], bt.outcome, bt.time, fail, ",".join(PackedStringArray(ids)), bt._caught_by, "; ".join(ev)])
	quit()
