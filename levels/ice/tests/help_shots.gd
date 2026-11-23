extends SceneTree
## 按 H 的說明卡截圖（冰雪島六關＋丹穴山三關）。在背景跑、不搶滑鼠（Player 換成 still_player.gd）。
##   bash levels/ice/tests/help_shots.sh <輸出資料夾> [--only=ice9] [--fails=2] [--tab]
## 每一關：進場 → 打開說明卡 → 每一頁拍一張。--fails=N 假裝這一關已經輸過 N 次（看提示一層一層打開的樣子）。
## --tab：打開之前先等「怎麼玩」收成左上角的「? 提示 H」，拍一張 <關>_tab。
const STILL := preload("res://levels/ice/tests/still_player.gd")
const Wardrobe := preload("res://scripts/wardrobe.gd")
const STAGES := [
	["ice9", "res://levels/ice/stage_9/stage.tscn"],
	["ice12", "res://levels/ice/stage_12/stage.tscn"],
	["ice13", "res://levels/ice/stage_13/stage.tscn"],
	["ice14", "res://levels/ice/stage_14/stage.tscn"],
	["ice15", "res://levels/ice/stage_15/stage.tscn"],
	["ice16", "res://levels/ice/stage_16/stage.tscn"],
	["heaven1", "res://levels/heaven/stage_1/stage.tscn"],
	["heaven2", "res://levels/heaven/stage_2/stage.tscn"],
	["heaven3", "res://levels/heaven/stage_3/stage.tscn"],
]

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
	var out := "user://help_shots"
	var only := ""
	var fails := 0
	var tab := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		if a.begins_with("--only="):
			only = a.substr(7)
		if a.begins_with("--fails="):
			fails = int(a.substr(8))
		if a == "--tab":
			tab = true
	DirAccess.make_dir_recursive_absolute(out)
	Wardrobe.preview = {"body": "hoodie"}
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for s in STAGES:
		var tag: String = s[0]
		if only != "" and only != tag:
			continue
		var sc := (load(s[1]) as PackedScene).instantiate()
		sc.get_node("Player").set_script(STILL)
		Engine.set_meta("stage_id", "")          # 不寫玩家存檔
		root.add_child(sc)
		current_scene = sc
		var bt = sc.get_node("Battle")
		await _wait(1.2)
		if fails > 0 and bt.has_method("help_fake_fails"):
			bt.help_fake_fails(fails)
		if tab:
			await _wait(5.5)
			await _snap(out, "%s_tab" % tag)
		var pop = bt.get("help_popup")
		if pop == null:
			push_warning("%s 沒有說明卡" % tag)
		else:
			if bt.has_method("help_open"):
				bt.help_open()
			else:
				pop.open(0)
			var n: int = pop.pages.size()
			for k in n:
				await _wait(0.35)
				await _snap(out, "%s_p%d" % [tag, k + 1])
				if k < n - 1:
					pop._show_page(k + 1)
			pop.close()
		sc.queue_free()
		for i in 5:
			await process_frame
	FileAccess.open(out.path_join("DONE"), FileAccess.WRITE).store_string("ok")
	quit()
