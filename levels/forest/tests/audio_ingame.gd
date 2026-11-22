extends SceneTree
## 開著聲音實際跑一下小紅帽關：背景合成時畫面不卡、配樂淡入、開打換熱鬧版、事件真的有出聲。
## Godot --path . --script res://levels/forest/tests/audio_ingame.gd
const S1 := "res://levels/forest/stage_3/stage.tscn"
var bt
var fails := 0

func ok(c: bool, what: String) -> void:
	print("  ", "ok    " if c else "FAIL  ", what)
	if not c:
		fails += 1

func _initialize() -> void:
	Engine.set_meta("forest_audio_force", true)
	_go.call_deferred()

func _go() -> void:
	change_scene_to_file(S1)
	for i in 6:
		await process_frame
	bt = current_scene.get_node("Battle")
	# 背景合成：記下最慢的一格畫面
	var worst := 0
	var t0 := Time.get_ticks_msec()
	var last := t0
	while bt._sounds.is_empty() and Time.get_ticks_msec() - t0 < 20000:
		await process_frame
		var now := Time.get_ticks_msec()
		worst = maxi(worst, now - last)
		last = now
	ok(not bt._sounds.is_empty(), "合成完成（%.1f 秒）" % ((Time.get_ticks_msec() - t0) / 1000.0))
	ok(worst < 250, "合成時畫面沒有卡住（最慢一格 %d 毫秒）" % worst)
	for i in 90:
		await process_frame
	ok(bt._music["bgm_plan"].playing and bt._music["bgm_plan"].volume_db > -20.0, "準備階段放安靜版（%.0f dB）" % bt._music["bgm_plan"].volume_db)
	# 放道具：每個都要出聲
	var before: int = bt.fx_root.get_child_count()
	bt.cast(bt.skill_index("guide"), bt.ground(bt.escape_point))
	bt.cast(bt.skill_index("decoy"), bt.ground(Vector3(-8.0, 0, 5.0)))
	await process_frame
	var players := 0
	for c in bt.fx_root.get_children():
		if c is AudioStreamPlayer3D:
			players += 1
	ok(players >= 2, "放道具有出聲（%d 個場上音效）" % players)
	bt.start()
	for i in 150:
		await process_frame
	ok(bt._music["bgm_run"].volume_db > -20.0 and bt._music["bgm_plan"].volume_db < -40.0,
		"開打換熱鬧版（run %.0f dB／plan %.0f dB）" % [bt._music["bgm_run"].volume_db, bt._music["bgm_plan"].volume_db])
	ok(bt._music["bgm_run"].get_playback_position() > 0.0, "配樂在播")
	# 點一棵樹：火要有劈啪聲
	var ti: int = bt._nearest_tree(Vector3(8, 0, 8), 99.0)
	bt._ignite_tree(ti, "測試")
	await process_frame
	var crackle := false
	var fl = bt.grove[ti].flame
	if fl != null:
		for c in (fl as Node3D).get_children():
			if c is AudioStreamPlayer3D and (c as AudioStreamPlayer3D).playing:
				crackle = true
	ok(crackle, "著火的樹有劈啪聲")
	bt.reset()
	await process_frame
	ok(bt.phase == bt.Phase.PREPARE, "按 R 重來沒出錯")
	print("AUDIO INGAME: ALL PASS" if fails == 0 else "AUDIO INGAME: FAILED (%d)" % fails)
	quit(1 if fails > 0 else 0)
