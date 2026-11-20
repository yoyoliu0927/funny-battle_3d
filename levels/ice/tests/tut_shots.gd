extends SceneTree
## 冰雪島前三關的新手教學截圖。在背景跑、不搶滑鼠（Player 換成 still_player.gd）。
##   bash levels/ice/tests/tut_shots.sh <輸出資料夾> [--only=9]
## 每一關：進場後每隔一段時間拍一張（看教學一步一步怎麼出現）。
const STILL := preload("res://levels/ice/tests/still_player.gd")
const Wardrobe := preload("res://scripts/wardrobe.gd")

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
	var out := "user://ice_tut_shots"
	var only := 0
	var every := 1.5
	var count := 4
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		if a.begins_with("--only="):
			only = int(a.substr(7))
		if a.begins_with("--every="):
			every = float(a.substr(8))
		if a.begins_with("--count="):
			count = int(a.substr(8))
	DirAccess.make_dir_recursive_absolute(out)
	Wardrobe.preview = {"body": "hoodie"}
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Engine.set_meta("ice_tut_force", true)      # 平常自動測試不跑教學；截圖要看教學
	for n in [9, 12, 13]:
		if only != 0 and only != n:
			continue
		var sc := (load("res://levels/ice/stage_%d/stage.tscn" % n) as PackedScene).instantiate()
		sc.get_node("Player").set_script(STILL)
		Engine.set_meta("stage_id", "")          # 不寫玩家存檔
		root.add_child(sc)
		current_scene = sc
		var bt = sc.get_node("Battle")
		await _wait(1.5)
		# 教學每一步拍一張，拍完直接跳到下一步（要動手的步驟不模擬，只看畫面）
		var k := 0
		while bt.tut != null and bt.tut.active() and k < 20:
			await _wait(0.4)
			await _snap(out, "s%d_step%d" % [n, k + 1])
			bt.tut._go(bt.tut.i + 1)
			k += 1
		await _wait(0.4)
		await _snap(out, "s%d_after" % n)
		sc.queue_free()
		for i in 5:
			await process_frame
	FileAccess.open(out.path_join("DONE"), FileAccess.WRITE).store_string("ok")
	quit()
