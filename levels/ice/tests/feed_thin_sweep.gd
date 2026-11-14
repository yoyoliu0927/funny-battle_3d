extends SceneTree
## 飼料放在每塊薄冰上和周圍（半徑＋1.5 公尺的格點，每 0.5 公尺）各跑一局：不能有任何一局拖到時間上限。
## 另外每個位置再配「每條紅線中點一片香蕉皮」跑一次。
## Godot --headless --path . --script res://levels/ice/tests/feed_thin_sweep.gd -- <關卡號碼> [上限秒數=40]
const DT := 1.0 / 60.0
func _initialize() -> void:
	change_scene_to_file("res://levels/ice/stage_%s/stage.tscn" % OS.get_cmdline_user_args()[0])
	_go.call_deferred()
func _go() -> void:
	var a := OS.get_cmdline_user_args()
	var cap := float(a[1]) if a.size() > 1 else 40.0
	for i in 10:
		await process_frame
	var bt = current_scene.get_node("Battle")
	bt.set_physics_process(false)
	bt.set_process(false)
	bt.silent = true
	var fi: int = bt.skill_index("bait")
	var bi: int = bt.skill_index("banana")
	var peels: Array = [null]
	for f in bt.enemies:
		var rush: Array = f.get_meta("rush", [])
		if not rush.is_empty():
			peels.append((f.start_pos as Vector3).lerp(rush[0], 0.6))
	var total := 0
	var slow := 0
	var worst := 0.0
	for th in bt.world.thin_spots:
		var r: float = float(th.r) + 1.5
		var x: float = th.center.x - r
		while x <= th.center.x + r + 0.001:
			var z: float = th.center.y - r
			while z <= th.center.y + r + 0.001:
				for pe in peels:
					bt.reset()
					var p := Vector3(x, bt.world.height_at(x, z), z)
					if bt.placement_error(fi, p) != "":
						continue
					bt.cast(fi, p)
					if pe != null and bi >= 0:
						bt.cast(bi, Vector3(pe.x, bt.world.height_at(pe.x, pe.z), pe.z))
					bt.start()
					while bt.phase == bt.Phase.RUNNING and bt.time < cap:
						bt._tick_cooldowns(DT)
						bt._step(DT)
					total += 1
					worst = maxf(worst, bt.time)
					if bt.phase == bt.Phase.RUNNING:
						slow += 1
						print("SLOW 飼料(%.1f,%.1f) 香蕉皮%s：%.0f 秒還沒結束" % [x, z, str(pe), cap])
				z += 0.5
			x += 0.5
	print("FEEDTHIN stage=%s 跑了 %d 局，最久 %.1f 秒，%d 局超過 %.0f 秒 → %s" % [a[0], total, worst, slow, cap, "PASS" if slow == 0 and total > 0 else "FAIL"])
	quit()
