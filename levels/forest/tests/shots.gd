extends SceneTree
## 森林三關的截圖（美術與玩法檢查用）。在背景跑、不搶滑鼠：Player 換成 still_player.gd。
##   open -g -n -a <Godot.app> --args --path <專案> --resolution 1280x720 -s res://levels/forest/tests/shots.gd -- --out=<資料夾> [--only=2] [--run=秒]
const STILL := preload("res://levels/forest/tests/still_player.gd")
const Wardrobe := preload("res://scripts/wardrobe.gd")
const Play := preload("res://levels/forest/tests/play.gd")

func _initialize() -> void:
	_go.call_deferred()

func _wait(sec: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		await process_frame

## 俯看／回到家豪旁邊（Tab 的那個視角切換）
func _top(bt, on: bool) -> void:
	if bt.view and bt.view.overview != on:
		bt.view.toggle()
		await _wait(0.8)

func _snap(out: String, name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))

func _go() -> void:
	var out := "user://forest_shots"
	var only := 0
	var run := 0.0
	var chapter := "forest"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		if a.begins_with("--chapter="):
			chapter = a.substr(10)
		if a.begins_with("--only="):
			only = int(a.substr(7))
		if a.begins_with("--run="):
			run = float(a.substr(6))
	DirAccess.make_dir_recursive_absolute(out)
	Wardrobe.preview = {"body": "hoodie"}
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for n in [1, 2, 3]:
		if only != 0 and only != n:
			continue
		var path := "res://levels/%s/stage_%d/stage.tscn" % [chapter, n]
		if not ResourceLoader.exists(path):
			continue
		var sc := (load(path) as PackedScene).instantiate()
		sc.get_node("Player").set_script(STILL)
		Engine.set_meta("stage_id", "")
		root.add_child(sc)
		current_scene = sc
		await _wait(1.5)
		var bt = sc.get_node("Battle")
		await _snap(out, "s%d_a_open" % n)
		if bt.has_method("_set_tut_step"):
			bt._set_tut_step(-1)
		if bt.help_popup:
			bt.help_popup.visible = false
		await _wait(0.5)
		await _snap(out, "s%d_b_plan" % n)
		await _top(bt, true)
		await _snap(out, "s%d_c_top" % n)
		if run > 0.0:
			# 照 play.gd 裡內建的放法先放好，再開打；每隔幾秒拍一張（一般視角＋俯看）
			for part in String(Play.PLANS.get(n, "")).split(";", false):
				var v := part.strip_edges().split(",")
				if v.size() < 3 or v.size() > 3:
					continue
				var idx: int = bt.skill_index(String(v[0]))
				if idx >= 0:
					bt.cooldowns[idx] = 0.0
					bt.cast(idx, bt.ground(Vector3(float(v[1]), 0, float(v[2]))))
			await _wait(0.4)
			await _snap(out, "s%d_d_placed_top" % n)
			await _top(bt, false)
			await _snap(out, "s%d_e_placed" % n)
			bt.start()
			var t := 0.0
			var k := 0
			while t < run and bt.phase == bt.Phase.RUNNING:
				await _top(bt, k % 2 == 1)
				await _wait(2.0)
				t += 2.8
				k += 1
				await _snap(out, "s%d_f_run%02d%s" % [n, k, "_top" if bt.view.overview else ""])
		else:
			await _top(bt, false)
		sc.queue_free()
		await process_frame
	print("DONE")
	var f := FileAccess.open(out.path_join("DONE"), FileAccess.WRITE)
	f.store_string("ok")
	f.close()
	quit()
