extends SceneTree
## 掃線：沿著一條線每隔一段距離放一個道具，各跑一局，印出結果和關鍵事件。
## Godot --headless --path <專案> --script res://levels/ice/tests/sweep.gd -- <關卡號碼或場景路徑> <道具序號> <x0,z0> <x1,z1> <間隔> ["固定先放的：i,x,z;i,x,z"]
const DT := 1.0 / 60.0
func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	change_scene_to_file(String(a[0]) if String(a[0]).begins_with("res://") else "res://levels/ice/stage_%s/stage.tscn" % a[0])
	_go.call_deferred()
func _v(s: String) -> Vector3:
	var p := s.split(",")
	return Vector3(float(p[0]), 0, float(p[1]))
func _go() -> void:
	var a := OS.get_cmdline_user_args()
	for i in 10:
		await process_frame
	var bt = current_scene.get_node("Battle")
	bt.set_physics_process(false)
	bt.set_process(false)
	bt.silent = true
	var item := int(a[1])
	var p0 := _v(a[2])
	var p1 := _v(a[3])
	var step := float(a[4])
	var fixed: Array = []
	if a.size() > 5 and String(a[5]) != "":
		for part in String(a[5]).split(";"):
			var v := part.split(",")
			fixed.append([int(v[0]), Vector3(float(v[1]), 0, float(v[2]))])
	var n := maxi(int(round(p0.distance_to(p1) / step)), 1)
	for k in n + 1:
		bt.reset()
		var ok := true
		var p := p0.lerp(p1, float(k) / n)
		for c in fixed + [[item, p]]:
			var q: Vector3 = c[1]
			q.y = bt.world.height_at(q.x, q.z)
			bt.cooldowns[c[0]] = 0.0
			if not bt.cast(c[0], q):
				ok = false
		if not ok:
			print("(%.2f,%.2f) 放不了：%s" % [p.x, p.z, bt.placement_error(item, Vector3(p.x, bt.world.height_at(p.x, p.z), p.z))])
			continue
		bt.start()
		while bt.phase == bt.Phase.RUNNING and bt.time < 60.0:
			bt._tick_cooldowns(DT)
			bt._step(DT)
		var ev: PackedStringArray = []
		for v in bt.events:
			var t: String = v.text
			for key in ["掉進", "撞到", "追不上", "抓住", "雪堆", "雪人", "差一點", "薄冰", "整人清單"]:
				if t.contains(key):
					ev.append("%.1f %s" % [v.t, t])
					break
		print("(%.2f,%.2f) %s %.1f | %s" % [p.x, p.z, bt.outcome, bt.time, "; ".join(ev)])
	quit()
