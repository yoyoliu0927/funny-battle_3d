extends SceneTree
## 過關後前往下一關：森林不自動出發——等 6 秒還在原地；按空白鍵才淡出、讀取、載入下一關，中間不能出錯。
## Godot --path . --script res://levels/forest/tests/next_stage.gd -- --nexttest
## （--nexttest：讓共用程式在測試時也照平常的規則跑；森林本來就不自動出發，有沒有加都一樣）

func _initialize() -> void:
	_go.call_deferred()

func _go() -> void:
	for pair in [[1, 2], [2, 3]]:
		await _hop(pair[0], pair[1])
	quit()

func _hop(from: int, to: int) -> void:
	Engine.set_meta("stage_id", "forest/%d" % from)
	var here := "res://levels/forest/stage_%d/stage.tscn" % from
	change_scene_to_file(here)
	for i in 8:
		await process_frame
	var bt = current_scene.get_node("Battle")
	bt.start()
	for f in bt.enemies:
		f.hp = 0.0
		f.set_state("dead")
	if bt.want_hood:
		bt.hood_saved = true
	# 等 6 秒：不能自己跑掉
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 6000:
		await process_frame
	var stayed: bool = current_scene != null and current_scene.scene_file_path == here
	print("  %s 第 %d 關過關後留在原地（%s）" % ["ok  " if stayed else "FAIL", from, bt._phase_label.text])
	# 按空白鍵
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_SPACE
	ev.keycode = KEY_SPACE
	ev.pressed = true
	root.push_input(ev)
	var want := "res://levels/forest/stage_%d/stage.tscn" % to
	t0 = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 20000:
		await process_frame
		if current_scene != null and current_scene.scene_file_path == want:
			break
	var ok := current_scene != null and current_scene.scene_file_path == want
	for i in 60:
		await process_frame
	print("  %s 按空白鍵換到 %s（%.1f 秒）" % ["ok  " if ok else "FAIL", current_scene.scene_file_path if current_scene else "null",
		(Time.get_ticks_msec() - t0) / 1000.0])
