extends SceneTree
## 仙境三關的截圖（美術檢查用）。在背景跑、不搶滑鼠：Player 換成 still_player.gd（不鎖游標）。
##   open -g -n -a <Godot.app> --args --path <專案> --resolution 1280x720 -s res://levels/heaven/tests/shots.gd -- --out=<資料夾> [--only=2] [--run] [--strategy="banana,-6,-4;rock,2.4,-12"]
## 每一關拍：play（開場鏡頭）、top（正上方）、幾個地標的近景；加 --run 會放好保底解法、開打，每隔一段時間拍一張。
const STILL := preload("res://levels/heaven/tests/still_player.gd")
## 每一關另外拍的鏡頭：[名字, 鏡頭位置, 看哪裡]
const VIEWS := {
	1: [["wide", Vector3(0, 26, 44), Vector3(0, 0, -6)], ["gate", Vector3(6, 5, -2), Vector3(0, 2.5, -12)], ["door", Vector3(-1, 3.2, -1), Vector3(5, 1.5, -4)],
		["west", Vector3(4, 6, 6), Vector3(-14, 1, -10)], ["east", Vector3(-2, 6, 8), Vector3(17, 0.5, -4)], ["low", Vector3(-3, 2.2, 15), Vector3(0, 2.0, -6)]],
	2: [["wide", Vector3(0, 26, 44), Vector3(0, 0, -6)], ["luwu", Vector3(2.5, 2.6, 3.5), Vector3(-4.5, 1.0, -1)], ["street", Vector3(0, 3.0, 16), Vector3(0, 2.5, -12)],
		["nw", Vector3(6, 7, 4), Vector3(-12, 3, -15)], ["se", Vector3(-4, 6, -8), Vector3(12, 2, 4)], ["low", Vector3(-9, 2.0, -2), Vector3(8, 2.5, -8)]],
	3: [["wide", Vector3(0, 26, 44), Vector3(0, 0, -6)], ["disc", Vector3(3.5, 3.2, -5.5), Vector3(0, 2.6, -13)], ["luwu", Vector3(-1, 2.8, 2), Vector3(5, 1, -2.5)],
		["walk", Vector3(0, 2.6, 20), Vector3(0, 3.5, -14)], ["door", Vector3(-9, 3, -4), Vector3(-4, 1.5, 0.9)], ["low", Vector3(-12, 2.2, 6), Vector3(6, 3, -12)]],
}
const SOLVE := {
	1: [["banana", -6.0, -4.0], ["banana", -5.0, -6.67], ["rock", 2.4, -12.0]],
	2: [["banana", -6.0, -6.5], ["banana", 5.5, -6.25]],
	3: [["banana", -7.0, -6.2], ["banana", -8.0, -2.5], ["banana", -6.0, -8.0], ["bait", 0.0, -11.8]],
}

func _initialize() -> void:
	_go.call_deferred()

func _wait(sec: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		await process_frame

func _snap(out: String, name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))

func _go() -> void:
	var out := "user://heaven_shots"
	var only := 0
	var run := false
	var custom = null
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		if a.begins_with("--only="):
			only = int(a.substr(7))
		if a == "--run":
			run = true
		if a.begins_with("--strategy="):
			# 自己的放法（跟 play.gd 一樣："banana,-6,-4;rock,2.4,-12"）：取代內建的保底解法，只拍開打過程
			run = true
			custom = []
			for part in a.substr(11).split(";", false):
				var v := part.strip_edges().split(",")
				if v.size() >= 3:
					custom.append([String(v[0]).strip_edges(), float(v[1]), float(v[2])])
	DirAccess.make_dir_recursive_absolute(out)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for n in [1, 2, 3]:
		if only != 0 and only != n:
			continue
		var sc := (load("res://levels/heaven/stage_%d/stage.tscn" % n) as PackedScene).instantiate()
		sc.get_node("Player").set_script(STILL)
		Engine.set_meta("stage_id", "")          # 不帶小關編號：就算這一局贏了也不會寫進玩家的存檔
		root.add_child(sc)
		current_scene = sc
		await _wait(1.2)
		var bt = sc.get_node("Battle")
		await _snap(out, "s%d_play" % n)
		bt.force_top = true
		for i in 20:
			await process_frame
		await _snap(out, "s%d_top" % n)
		bt.force_top = false
		for i in 5:
			await process_frame
		# 自己的鏡頭拍地標
		var cam := Camera3D.new()
		cam.fov = 55.0
		cam.far = 900.0
		sc.add_child(cam)
		var hud_off: Array = []
		for c in sc.find_children("*", "CanvasLayer", true, false):
			if (c as CanvasLayer).visible:
				hud_off.append(c)
				(c as CanvasLayer).visible = false
		for v in (VIEWS[n] if custom == null else []):
			cam.global_position = v[1]
			cam.look_at(v[2])
			cam.make_current()
			for i in 8:
				await process_frame
			await _snap(out, "s%d_%s" % [n, v[0]])
		for c in hud_off:
			(c as CanvasLayer).visible = true
		(bt.camera as Camera3D).make_current()
		cam.queue_free()
		if run:
			for it in (custom if custom != null else SOLVE[n]):
				var idx: int = bt.skill_index(String(it[0]))
				var p := Vector3(float(it[1]), bt.world.height_at(float(it[1]), float(it[2])), float(it[2]))
				if idx >= 0 and bt.placement_error(idx, p) == "":
					bt.cast(idx, p)
			for i in 10:
				await process_frame
			await _snap(out, "s%d_run0_placed" % n)
			bt.start()
			var shot := 1
			var t0 := Time.get_ticks_msec()
			while Time.get_ticks_msec() - t0 < 13000 and shot <= 9:
				if Time.get_ticks_msec() - t0 >= shot * 1300:
					await _snap(out, "s%d_run%d" % [n, shot])
					shot += 1
				await process_frame
			# 最後一關贏了：按 Enter 之後的全章收尾，每 1.1 秒拍一張
			if n == 3 and String(bt.outcome) == "win":
				bt._go_next()
				for k in 8:
					await _wait(1.1)
					await _snap(out, "s3_fin%d" % (k + 1))
		sc.queue_free()
		for i in 5:
			await process_frame
	var f := FileAccess.open(out.path_join("DONE"), FileAccess.WRITE)
	f.store_string("ok")
	f.close()
	quit()
