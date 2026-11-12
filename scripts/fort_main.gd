extends Node3D
## 第二關（要塞）主場景。
## 帶 `-- --fortshots=<資料夾>` 啟動時跑一輪自動測試：截圖、北坡放巨石撞炮塔 A、
## 用飼料把家豪引進大砲、瞄準指揮官高台發射，印出結果後結束。

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--fortshots="):
			_shots(a.substr(12))

func _look(from: Vector3, at: Vector3) -> void:
	var player := $Player as Node3D
	var head := $Player/Head as Node3D
	player.set_physics_process(false)
	player.global_position = from
	var d: Vector3 = at - (from + Vector3(0, 1.65, 0))
	player.rotation = Vector3(0, atan2(-d.x, -d.z), 0)
	head.rotation.x = atan2(d.y, Vector2(d.x, d.z).length())

func _snap(dir: String, name: String) -> void:
	for k in 4:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(dir.path_join(name + ".png"))

func _wait_until(cond: Callable, timeout: float) -> bool:
	var t := 0.0
	while t < timeout:
		if cond.call():
			return true
		await get_tree().process_frame
		t += get_process_delta_time()
	return false

func _shots(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var world := $World
	var bt := $Battle
	await get_tree().process_frame
	bt._set_tut_step(-1)         # 截圖時不要教學擋著
	_look(Vector3(0.0, 30.0, 24.0), Vector3(0, 0, -4))
	await _snap(dir, "fort_02_overview")
	_look(Vector3(-2.0, 7.0, 21.0), Vector3(0, 0, -3))
	await _snap(dir, "fort_01_entry")
	_look(Vector3(-4.0, 9.0, 2.0), Vector3(6, 3, -10))
	await _snap(dir, "fort_03_ridge")

	# 準備階段：在砲口前撒飼料
	var bait: Vector3 = world.cannon_bait_spot()
	print("[FORT] 砲口前的飼料點 (%.1f, %.1f)，放飼料：%s" % [bait.x, bait.z, bt.cast(0, bait)])
	# 北坡放巨石（城牆上放不了）
	var wall_spot: Vector3 = bt._ground(Vector3(-15.5, 0, 2.0))
	print("[FORT] 城牆邊放巨石：", bt.placement_error(2, wall_spot))
	var ridge_spot: Vector3 = bt._ground(Vector3(-0.6, 0, -15.0))
	var path: PackedVector3Array = bt.simulate_roll(ridge_spot)
	var pe := path[path.size() - 1] if path.size() > 0 else ridge_spot
	print("[FORT] 北坡巨石從 (%.1f, %.1f, 高 %.1f) 滾到 (%.1f, %.1f)" % [ridge_spot.x, ridge_spot.z, ridge_spot.y, pe.x, pe.z])

	_look(Vector3(-2.0, 9.0, 20.0), Vector3(0, 0, -3))
	bt.start()
	print("[FORT] 北坡放巨石：", bt.cast(2, ridge_spot), " ", bt.aim_error)
	await get_tree().create_timer(3.0).timeout
	print("[FORT] 炮塔 A=%s B=%s" % [bt.towers[0].state, bt.towers[1].state])

	# 等家豪鑽進大砲
	var stuck: bool = await _wait_until(func(): return bt.bird.state == "cannon", 40.0)
	print("[FORT] 家豪卡進大砲：%s（%.1f 秒，狀態 %s）" % [stuck, bt.time, bt.bird.state])
	if stuck:
		# 鏡頭（準心）對準指揮官高台
		_look(Vector3(-12.0, 4.0, 4.0), Vector3(10.6, 5.0, -9.2))
		await get_tree().create_timer(1.2).timeout
		print("[FORT] 瞄準落點 (%.1f, %.1f)，在高台上：%s" % [bt.cannon_target.x, bt.cannon_target.z, world.on_boss_platform(bt.cannon_target)])
		await _snap(dir, "fort_20_aim")
		_look(Vector3(-6.0, 3.2, 2.4), Vector3(-7.0, 1.4, -1.0))
		await _snap(dir, "fort_21_stuck")
		_look(Vector3(-12.0, 4.0, 4.0), Vector3(10.6, 5.0, -9.2))
		await _wait_until(func(): return bt.bird.state == "launch", 6.0)
		# 射出去的瞬間會切到特寫鏡頭（慢動作），播完切回來
		var cu: Node = null
		for c in bt.get_children():
			if c.has_method("shot_index"):
				cu = c
		if cu:
			await _wait_until(func(): return cu.shot_index() >= 0, 2.0)
			# 分鏡：1 背影一鏡到底（拍兩張：剛射出去、接近最高點）→ 2 落點那一頭 → 砸中
			for step in [[0, 6, "a"], [0, 50, "b"], [1, 16, "c"], [2, 14, "d"]]:
				await _wait_until(func(): return cu.shot_index() >= step[0] or cu.shot_index() < 0, 8.0)
				if cu.shot_index() < 0:
					break
				for k in step[1]:
					await get_tree().process_frame
				await _snap(dir, "fort_22%s_closeup" % step[2])
				print("[FORT] 特寫第 %d 鏡（time_scale %.2f，飛行進度 %.2f）" % [cu.shot_index() + 1, Engine.time_scale, cu._flight_k()])
			await _wait_until(func(): return cu.shot_index() < 0, 8.0)
		print("[FORT] 特寫結束，鏡頭切回：%s，家豪 %s" % [get_viewport().get_camera_3d().name, bt.bird.state])
		_look(Vector3(-2.0, 14.0, 10.0), Vector3(2, 4, -6))
		await get_tree().create_timer(0.6).timeout
		await _snap(dir, "fort_22_launch")
		await _wait_until(func(): return bt.bird.state != "launch", 6.0)
		_look(Vector3(4.0, 9.0, -1.0), Vector3(10.5, 5.0, -9.0))
		await _snap(dir, "fort_23_landed")
	await get_tree().create_timer(1.0).timeout
	var alive: Array = bt.farmers.filter(func(f): return f.alive()).map(func(f): return f.name)
	print("[FORT] %.1f 秒：phase=%s outcome=%s 家豪 %s（血 %.1f），還活著 %s" % [bt.time, bt.phase, bt.outcome, bt.bird.state, bt.bird.hp, alive])
	for l in bt.events:
		print("   %.1f  %s" % [l.t, l.text])

	# 第二輪：梯子腳下撒飼料，家豪爬上炮塔 B 把砲手踢下去
	bt.reset()
	var tb: Dictionary = bt.towers[1]
	var lad: Vector2 = tb.ladder
	var lp: Vector3 = bt._ground(Vector3(lad.x, 0, lad.y))
	print("[FORT] 第二輪：炮塔 B 梯子腳 (%.1f, %.1f)，放飼料：%s %s" % [lp.x, lp.z, bt.cast(0, lp), bt.aim_error])
	_look(Vector3(0.0, 9.0, 9.0), Vector3(6.5, 3.0, -0.5))
	bt.start()
	var climbed: bool = await _wait_until(func(): return bt.bird.state == "climb", 40.0)
	print("[FORT] 開始爬梯子：%s（%.1f 秒）" % [climbed, bt.time])
	if climbed:
		await get_tree().create_timer(1.6).timeout
		await _snap(dir, "fort_30_climb")
		await _wait_until(func(): return tb.side == "ally", 6.0)
		# 家豪翻過矮牆站在塔頂上（不是浮在梯子外面）
		_look(Vector3(tb.pos.x + 3.5, 10.5, tb.pos.y + 6.5), Vector3(tb.pos.x, 8.6, tb.pos.y))
		await get_tree().create_timer(0.5).timeout
		await _snap(dir, "fort_31_captured")
		_look(Vector3(0.0, 9.0, 9.0), Vector3(6.5, 3.0, -0.5))
	await get_tree().create_timer(10.0).timeout
	_look(Vector3(0.0, 22.0, 16.0), Vector3(2, 0, -3))
	await _snap(dir, "fort_32_after")
	var alive2: Array = bt.farmers.filter(func(f): return f.alive()).map(func(f): return f.name)
	print("[FORT] %.1f 秒：炮塔 B=%s/%s 家豪 %s（血 %.1f），還活著 %s" % [bt.time, tb.state, tb.side, bt.bird.state, bt.bird.hp, alive2])
	for l in bt.events:
		print("   %.1f  %s" % [l.t, l.text])
	get_tree().quit()
