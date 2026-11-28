extends SceneTree
## 第一次玩的人進 2-0（偷襲！）看到什麼：進場鏡頭每一段、進場後、卡住幾秒後各截一張。
## 要開視窗。會暫時把存檔裡「學會了」的紀錄拿掉，截完還原。
##   Godot --path . -s res://levels/fort/tests/entry_shots.gd -- <輸出資料夾>

const PATH := "user://progress.cfg"
var out := "user://entry_shots"

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		out = a
	DirAccess.make_dir_recursive_absolute(out)
	_go.call_deferred()

func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("截圖 ", name)

func _wait(sec: float) -> void:
	var end := Time.get_ticks_msec() + int(sec * 1000.0)
	while Time.get_ticks_msec() < end:
		await process_frame

func _go() -> void:
	var backup := FileAccess.get_file_as_bytes(PATH) if FileAccess.file_exists(PATH) else PackedByteArray()
	var cf := ConfigFile.new()
	cf.load(PATH)
	if cf.has_section("mechanics"):
		cf.erase_section("mechanics")
	cf.set_value("fort", "tutorial_seen", false)
	cf.save(PATH)
	var sc: Node = (load("res://levels/fort/stage_0/stage.tscn") as PackedScene).instantiate()
	root.add_child(sc)
	await _wait(1.5)
	await _shot("1_intro_a")
	await _wait(3.0)
	await _shot("2_intro_b")
	await _wait(3.2)
	await _shot("3_intro_c")
	await _wait(4.0)
	await _shot("4_after_intro")
	await _wait(9.0)
	await _shot("5_stuck")
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if backup.is_empty():
		f.close()
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	else:
		f.store_buffer(backup)
		f.close()
	print("ENTRY_SHOTS: DONE（存檔已還原）")
	quit()
