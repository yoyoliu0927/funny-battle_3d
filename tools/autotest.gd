extends Node
## 自動驗收：模擬鍵盤/滑鼠輸入事件，檢查場景載入、WASD、右鍵轉頭，並截圖。
## 用法：Godot --path <專案> -- --autotest --outdir=<截圖資料夾>

var out_dir := "user://autotest"
var lines: PackedStringArray = []
var fails := 0
var player: CharacterBody3D
var head: Node3D

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--outdir="):
			out_dir = a.substr(9)
	DirAccess.make_dir_recursive_absolute(out_dir)
	# 選關地圖的驗收結果（先跑完才進到這一關）
	if Engine.has_meta("intro_lines"):
		for l in Engine.get_meta("intro_lines"):
			lines.append(l)
		fails += int(Engine.get_meta("intro_fails"))
	if Engine.has_meta("ls_lines"):
		for l in Engine.get_meta("ls_lines"):
			lines.append(l)
		fails += int(Engine.get_meta("ls_fails"))
	_run.call_deferred()

func _check(name: String, ok: bool, detail := "") -> void:
	if not ok:
		fails += 1
	var s := "[%s] %s %s" % ["PASS" if ok else "FAIL", name, detail]
	lines.append(s)
	print(s)

func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout

func _key(code: Key, pressed: bool) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.keycode = code
	e.pressed = pressed
	Input.parse_input_event(e)

func _esc() -> void:
	var e := InputEventKey.new()
	e.keycode = KEY_ESCAPE
	e.physical_keycode = KEY_ESCAPE
	e.pressed = true
	Input.parse_input_event(e)

func _click() -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	e.position = get_viewport().get_visible_rect().size * 0.5
	Input.parse_input_event(e)

func _rmb(pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_RIGHT
	e.pressed = pressed
	e.position = get_viewport().get_visible_rect().size * 0.5
	Input.parse_input_event(e)

func _motion(rel: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.relative = rel
	e.position = get_viewport().get_visible_rect().size * 0.5
	Input.parse_input_event(e)

func _shot(name: String) -> void:
	# 視窗被遮住/縮小時 macOS 不會繪製，避免卡住
	if not DisplayServer.window_can_draw():
		print("[SKIP] 截圖 %s：視窗目前無法繪製" % name)
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(out_dir.path_join(name + ".png"))

func _move_test(code: Key, label: String, expect_local: Vector3) -> float:
	var p0 := player.global_position
	_key(code, true)
	await _wait(0.6)
	_key(code, false)
	await _wait(0.25)
	var dp := player.global_position - p0
	var local := player.global_basis.inverse() * dp
	local.y = 0.0
	var ok := local.length() > 1.5 and local.normalized().dot(expect_local) > 0.95
	_check("按 %s 移動" % label, ok, "位移(本地)=(%.2f, %.2f) 距離=%.2fm" % [local.x, local.z, local.length()])
	return local.length()

func _run() -> void:
	player = get_node("/root/Main/Player")
	head = player.get_node("Head")
	await _wait(2.0)
	var world := get_node("/root/Main/World")
	_check("場景載入", world.get_node_or_null("Layout/Terrain") != null and world.get_node_or_null("Buildings") != null and world.get_node_or_null("FarmFence") != null and world.get_node_or_null("InnerTrees") != null and world.get_node_or_null("Grass") != null,
		"World 子節點=%d, 草叢=%d 叢" % [world.get_child_count(), world.get_node("Grass").multimesh.instance_count])
	var chars := world.get_node_or_null("Characters")
	_check("家豪、三個農夫和老闆都已放置", chars != null and chars.hero != null and chars.enemies.size() == 4,
		"主角=%s, 敵人=%s" % [chars.hero.get_meta("source", "?"), chars.enemy.get_meta("source", "?")] if chars else "")
	var ap_list: Array = chars.enemy.find_children("*", "AnimationPlayer", true, false) if chars else []
	if not ap_list.is_empty():
		var ap: AnimationPlayer = ap_list[0]
		_check("敵人播放待機動畫", ap.is_playing(), "動畫=%s，共 %d 個動作" % [ap.current_animation, ap.get_animation_list().size()])
	await _shot("01_spawn_view")
	player.global_position.y += 5.0   # 離起伏的地面遠一點，移動測試才不會擦到地形
	await _wait(0.2)
	var y_start := player.global_position.y
	await _wait(1.0)
	_check("幽靈懸空不下墜", absf(player.global_position.y - y_start) < 0.05, "1 秒內高度變化 %.3fm" % (player.global_position.y - y_start))

	await _move_test(KEY_W, "W(前)", Vector3(0, 0, -1))
	await _move_test(KEY_S, "S(後)", Vector3(0, 0, 1))
	await _move_test(KEY_A, "A(左)", Vector3(-1, 0, 0))
	await _move_test(KEY_D, "D(右)", Vector3(1, 0, 0))

	# 一進場游標就鎖在中央，移動滑鼠畫面直接跟著轉（不用按任何鍵）
	_check("進場即鎖定游標", Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and player.looking,
		"視窗焦點=%s" % str(get_window().has_focus()))
	var yaw0 := player.rotation.y
	var pit0 := head.rotation.x
	_motion(Vector2(200, -80))
	await _wait(0.1)
	var dyaw := rad_to_deg(player.rotation.y - yaw0)
	var dpit := rad_to_deg(head.rotation.x - pit0)
	_check("不按鍵移動滑鼠就轉動視角", absf(dyaw) > 10.0 and dpit > 5.0, "左右轉 %.1f°、上下 %.1f°" % [dyaw, dpit])
	_check("準心在畫面中央", get_node_or_null("/root/Main/HUD/Crosshair") != null and get_node("/root/Main/HUD/Crosshair").visible)

	# Esc 放開游標 → 不再轉動；點一下視窗 → 回到視角操作
	_esc()
	await _wait(0.05)
	_check("Esc 放開游標", Input.mouse_mode == Input.MOUSE_MODE_VISIBLE)
	var yaw1 := player.rotation.y
	var pit1 := head.rotation.x
	_motion(Vector2(-300, 150))
	await _wait(0.1)
	_check("放開游標時不轉動", is_equal_approx(yaw1, player.rotation.y) and is_equal_approx(pit1, head.rotation.x))
	_click()
	await _wait(0.05)
	_check("點一下視窗恢復視角操作", Input.mouse_mode == Input.MOUSE_MODE_CAPTURED)

	# 低頭 / 抬頭時 W 仍水平移動
	for pitch_case in [[2000.0, "低頭到底"], [-4000.0, "抬頭到底"]]:
		_motion(Vector2(0, pitch_case[0]))
		await _wait(0.05)
		var p0 := player.global_position
		_key(KEY_W, true)
		await _wait(0.6)
		_key(KEY_W, false)
		await _wait(0.25)
		var dp := player.global_position - p0
		var horiz := Vector2(dp.x, dp.z).length()
		var fwd := -player.global_basis.z
		var along := Vector2(dp.x, dp.z).normalized().dot(Vector2(fwd.x, fwd.z).normalized())
		_check("%s(%.0f°)時 W 仍水平前進" % [pitch_case[1], rad_to_deg(head.rotation.x)], horiz > 1.5 and along > 0.95,
			"水平位移=%.2fm 垂直位移=%.2fm" % [horiz, dp.y])
	_motion(Vector2(0, -head.rotation.x / player.mouse_sensitivity))

	# 空白鍵上升 / Shift 下降
	var p0 := player.global_position
	_key(KEY_SPACE, true)
	await _wait(1.0)
	_key(KEY_SPACE, false)
	await _wait(0.4)
	var up := player.global_position - p0
	_check("空白鍵上升", up.y > 2.5 and Vector2(up.x, up.z).length() < 0.2, "上升 %.2fm，水平偏移 %.2fm" % [up.y, Vector2(up.x, up.z).length()])
	await _shot("05_ghost_up")
	p0 = player.global_position
	_key(KEY_SHIFT, true)
	await _wait(0.6)
	_key(KEY_SHIFT, false)
	await _wait(0.4)
	var dn := player.global_position - p0
	_check("Shift 下降", dn.y < -1.0 and Vector2(dn.x, dn.z).length() < 0.2, "下降 %.2fm" % -dn.y)
	# 一直按 Shift：不會穿進地面
	_key(KEY_SHIFT, true)
	await _wait(4.0)
	_key(KEY_SHIFT, false)
	await _wait(0.3)
	var ground: float = world.height_at(player.global_position.x, player.global_position.z)
	_check("下降到底不會穿過地面", player.global_position.y > ground - 0.05, "腳底 %.2f，地面 %.2f" % [player.global_position.y, ground])

	# 角色特寫
	var hp: Vector3 = chars.hero.global_position
	var ep: Vector3 = chars.enemy.global_position
	var mid := (hp + ep) * 0.5
	var side := (ep - hp).cross(Vector3.UP).normalized()
	var cam_pos := mid + side * 5.5 + Vector3(0, 0.8, 0)
	player.global_position = cam_pos
	player.velocity = Vector3.ZERO
	var d := mid - cam_pos
	player.rotation.y = atan2(-d.x, -d.z)
	head.rotation.x = deg_to_rad(-12.0)
	await _wait(0.6)
	await _shot("06_characters")
	# 主角正面特寫
	var hf: Vector3 = chars.hero.global_basis.z.normalized()
	var cp := hp + hf * 2.6 + Vector3(0, 0.05, 0)
	player.global_position = cp
	var d2 := (hp + Vector3(0, 0.95, 0)) - (cp + Vector3(0, 1.65, 0))
	player.rotation.y = atan2(-d2.x, -d2.z)
	head.rotation.x = atan2(d2.y, Vector2(d2.x, d2.z).length())
	await _wait(0.6)
	await _shot("07_hero_closeup")

	# 額外截圖：大門、農場全景、雞舍
	_place(Vector3(0.0, 0, 20.0), 0.0, -4.0)
	await _wait(0.5)
	await _shot("02_farm_gate")
	_place(Vector3(15.0, 0, 18.0), deg_to_rad(40.0), -30.0)
	player.global_position.y += 13.0
	await _wait(0.5)
	await _shot("03_farm_overview")
	_place(Vector3(-5.0, 0, 5.0), atan2(-15.0, 17.0), 4.0)
	player.global_position.y += 2.0
	await _wait(0.5)
	await _shot("04_plateau")

	await _battle_tests()

	lines.append("RESULT: %s (%d fail)" % ["ALL PASS" if fails == 0 else "FAILED", fails])
	print(lines[-1])
	var f := FileAccess.open(out_dir.path_join("report.txt"), FileAccess.WRITE)
	f.store_string("\n".join(lines))
	f.close()
	get_tree().quit(0 if fails == 0 else 1)

func _place(pos: Vector3, yaw: float, pitch_deg: float) -> void:
	var wb := get_node("/root/Main/World")
	pos.y = wb.height_at(pos.x, pos.z) + 0.6
	player.global_position = pos
	player.velocity = Vector3.ZERO
	player.rotation.y = yaw
	head.rotation.x = deg_to_rad(pitch_deg)

# ------------------------------------------------------------ 重演流程

func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

func _press(code: Key) -> void:
	# 輸入事件在下一個「畫面幀」才會被處理，加速時物理幀會先跑好幾次，所以要等 process_frame
	_key(code, true)
	await get_tree().process_frame
	await get_tree().process_frame
	_key(code, false)
	await get_tree().process_frame

func _wait_end(bt: Node, limit := 90.0) -> void:
	var t0: float = bt.time
	while bt.phase != bt.Phase.ENDED and bt.time - t0 < limit:
		await get_tree().physics_frame

func _battle_tests() -> void:
	var bt := get_node("/root/Main/Battle")
	bt.no_cooldown = true   # 驗收時連續施放很多次，冷卻另外測
	var world := get_node("/root/Main/World")
	Engine.time_scale = 1.0
	bt.reset()   # 清掉前面滑鼠測試時誤放的神蹟
	# 觀察位置：大門內側上空，看得到大門、守衛和中庭
	_place(Vector3(7.0, 0, 17.0), deg_to_rad(28.0), -32.0)
	player.global_position.y += 9.0
	await _wait(0.3)
	var keep_pos := player.global_position

	# 準備狀態
	var b0: Vector3 = bt.bird.pos
	var f0: Vector3 = bt.farmers[0].pos
	await _wait(1.0)
	_check("準備狀態角色原地待命", bt.phase == bt.Phase.PREPARE and bt.bird.pos == b0 and bt.farmers[0].pos == f0)
	await _press(KEY_2)
	var s2: int = bt.selected
	await _press(KEY_3)
	var s3: int = bt.selected
	await _press(KEY_1)
	_check("按 1 / 2 / 3 切換神蹟", s2 == 1 and s3 == 2 and bt.selected == 0)
	# 滑鼠滾輪／觸控板兩指滑動也能換技能
	var sel_before: int = bt.selected
	for btn in [MOUSE_BUTTON_WHEEL_DOWN]:
		var we := InputEventMouseButton.new()
		we.button_index = btn
		we.pressed = true
		we.position = get_viewport().get_visible_rect().size * 0.5
		Input.parse_input_event(we)
	await get_tree().process_frame
	await get_tree().process_frame
	var after_wheel: int = bt.selected
	var we2 := InputEventMouseButton.new()
	we2.button_index = MOUSE_BUTTON_WHEEL_UP
	we2.pressed = true
	we2.position = get_viewport().get_visible_rect().size * 0.5
	Input.parse_input_event(we2)
	await get_tree().process_frame
	await get_tree().process_frame
	var after_up: int = bt.selected
	var pg := InputEventPanGesture.new()
	pg.delta = Vector2(0, 3.2)
	pg.position = get_viewport().get_visible_rect().size * 0.5
	Input.parse_input_event(pg)
	await get_tree().process_frame
	await get_tree().process_frame
	var after_pan: int = bt.selected
	_check("滑鼠滾輪／觸控板滑動切換神蹟", sel_before == 0 and after_wheel == 1 and after_up == 0 and after_pan != 0,
		"滾下→%d 滾上→%d 兩指滑→%d" % [after_wheel, after_up, after_pan])
	await _press(KEY_1)
	await _shot("08_prepare_skillbar")
	# 開場教學：箭頭依序指著三格技能，各有一段說明；開打就收起來
	bt._tut_seen = false
	bt.start_tutorial()
	await _wait(0.6)
	var hbr: Rect2 = bt._hotbar.get_global_rect()
	var arrow_cx: float = bt._tut_arrow.position.x + bt._tut_arrow.size.x * 0.5
	var slot0_cx: float = hbr.position.x + 2.0 + 0.5 * 84.0
	var t0_ok: bool = bt.tutorial_step == 0 and bt._tut_arrow.visible and absf(arrow_cx - slot0_cx) < 4.0 and bt._tut_label.text.contains("飼料")
	await _shot("08e_tutorial_rock")
	bt._set_tut_step(1)
	await _wait(0.6)
	await _shot("08f_tutorial_feed")
	bt._set_tut_step(2)
	await _wait(0.3)
	var t2_ok: bool = bt.tutorial_step == 2 and bt.selected == 2 and bt._tut_label.text.contains("自己滾起來")
	bt._set_tut_step(3)
	await _wait(0.1)
	_check("開場教學：箭頭依序指著三格技能並說明，最後收起來", t0_ok and t2_ok and bt.tutorial_step == -1 and not bt._tut_arrow.visible and bt.selected == 0)

	# 巡邏與偵測區
	_check("每個農夫前方都有紅色偵測區", bt.farmers.all(func(f): return f.is_boss or f.cone.visible))
	_check("右上角敵人欄：四列頭像＋血條，老闆（持槍）在最上面", bt._enemy_rows.size() == 4 and bt._enemy_rows[0].fighter.is_boss)
	# 從穀倉門口看進去：胖商人老闆坐在最裡面
	var dout: Vector3 = world.door_out
	player.global_position = Vector3(dout.x + 0.5, world.height_at(dout.x, dout.z) + 0.3, dout.z + 4.0)
	var bpos: Vector3 = bt.boss.pos + Vector3(0, 1.6, 0)
	var dd := bpos - (player.global_position + Vector3(0, 1.65, 0))
	player.rotation.y = atan2(-dd.x, -dd.z)
	head.rotation.x = atan2(dd.y, Vector2(dd.x, dd.z).length())
	await _wait(0.4)
	_check("老闆是坐著的胖商人", bt.boss.node.get_meta("source", "") == "merchant")
	await _shot("08c_boss_merchant")
	var w = bt.world
	var back_gap: float = bt.boss.node.global_position.z - w.barn_rect.position.y
	var tr: Node = w.find_child("Treasure", true, false)
	_check("老闆往前坐、穀倉裡有紅地毯和金銀財寶", back_gap > 1.8 and w.find_child("RedCarpet", true, false) != null and tr != null and tr.get_child_count() > 20,
		"離後牆 %.1fm，財寶 %d 件" % [back_gap, tr.get_child_count() if tr else 0])
	var din: Vector3 = world.door_in
	player.global_position = Vector3(din.x, world.height_at(din.x, din.z) + 0.6, din.z + 0.5)
	var dd2 := bpos - (player.global_position + Vector3(0, 1.65, 0))
	player.rotation.y = atan2(-dd2.x, -dd2.z)
	head.rotation.x = atan2(dd2.y, Vector2(dd2.x, dd2.z).length())
	await _wait(0.4)
	await _shot("08d_barn_inside")
	player.global_position = keep_pos
	player.velocity = Vector3.ZERO
	# 示範石頭：開打一下下後自己從台地坡頂滑下來
	await _press(KEY_R)
	var demo_start: Vector3 = bt.demo_rock.position
	await _press(KEY_ENTER)
	await _wait(6.0)
	var demo_moved: float = Vector2(bt.demo_rock.position.x - demo_start.x, bt.demo_rock.position.z - demo_start.z).length()
	_check("台地坡頂的示範石頭會自己滑下來", demo_moved > 3.0 and bt.demo_rock.position.y < demo_start.y - 1.5,
		"滑了 %.1fm，下降 %.1fm" % [demo_moved, demo_start.y - bt.demo_rock.position.y])
	var plat_rocks: Array = bt.world.plateau_rocks
	var pr_clear := true
	for c in plat_rocks:
		for p in bt.demo_path:
			if Vector2(p.x, p.z).distance_to(c) < 1.2:
				pr_clear = false
	_check("台地台面上有不會動的裝飾石頭、且不擋示範石頭", plat_rocks.size() >= 3 and pr_clear, "%d 顆" % plat_rocks.size())
	await _press(KEY_R)
	Engine.time_scale = 1.0
	await _press(KEY_ENTER)
	await _wait(2.0)
	var walked := 0
	for f in bt.farmers:
		if not f.is_boss and _flat(f.pos, f.start_pos) > 1.0:
			walked += 1
	_check("一開打農夫就各自巡邏", walked == 3, "%d 個農夫在走動" % walked)
	# 走進偵測區 → 被發現
	await _press(KEY_R)
	await _press(KEY_ENTER)
	var f3 = bt.farmers[2]
	var fwd3 := Vector3(sin(f3.yaw), 0, cos(f3.yaw))
	bt.bird.pos = bt._ground(f3.pos + fwd3 * 4.0)
	await _wait(0.2)
	_check("走進紅色偵測區就會被發現", f3.aggro, "%s 狀態=%s" % [f3.name, f3.state])
	# 從背後偷襲沒發現的農夫
	await _press(KEY_R)
	await _press(KEY_ENTER)
	await get_tree().physics_frame
	var f2 = bt.farmers[1]
	var fwd2 := Vector3(sin(f2.yaw), 0, cos(f2.yaw))
	bt.bird.pos = bt._ground(f2.pos - fwd2 * 0.9)
	var hp_before: float = f2.hp
	var sneaked := false
	for i in 90:
		await get_tree().physics_frame
		for e in bt.events:
			if e.text.contains("偷襲" + f2.name):
				sneaked = true
		if sneaked:
			break
	_check("沒被發現時可以偷襲（農夫嚇一跳愣住）", sneaked and f2.hp <= hp_before - 2.4 and f2.state == "startled",
		"%s 血量 %.1f → %.1f，狀態=%s" % [f2.name, hp_before, f2.hp, f2.state])
	await _look_at_point(f2.pos + Vector3(0, 1.0, 0), 8.0, 5.0)
	await _shot("08b_sneak_attack")
	player.global_position = keep_pos
	player.velocity = Vector3.ZERO
	await _press(KEY_R)

	# 第 1 輪：不出手 → 雞衝進去被圍毆
	Engine.time_scale = 4.0
	await _press(KEY_ENTER)
	_check("Enter 開始", bt.phase == bt.Phase.RUNNING)
	var shot_gang := false
	var t0: float = bt.time
	while bt.phase != bt.Phase.ENDED and bt.time - t0 < 150.0:
		await get_tree().physics_frame
		var aggro: int = bt.farmers.filter(func(f): return f.aggro and f.alive()).size()
		if not shot_gang and aggro >= 2 and _flat(bt.bird.pos, bt.farmers[1].pos) < 6.0:
			shot_gang = true
			Engine.time_scale = 0.0
			await _look_at_point(bt.bird.pos + Vector3(0, 1.0, 0), 9.0, 4.0)
			await _shot("09_ganged_up")
			player.global_position = keep_pos
			player.velocity = Vector3.ZERO
			Engine.time_scale = 4.0
	Engine.time_scale = 1.0
	var ev1: Array = bt.events.duplicate(true)
	for e in ev1:
		print("    %.2fs %s" % [e.t, e.text])
	var texts := ""
	for e in ev1:
		texts += e.text + "\n"
	var found := 0
	for f in bt.farmers:
		if texts.contains(f.name + "發現"):
			found += 1
	# 勝負平衡先不驗證，只記錄結果
	print("[INFO] 不出手的結果：%s（%.1f 秒），%d 個農夫發現家豪" % [bt.outcome, bt.time, found])
	if bt.outcome == "lose":
		await _wait(2.2)
		_check("輸了之後切到農夫吃烤雞的畫面", bt.defeat_shown and bt.defeat_room.cam.current)
		await _shot("10_defeat_dinner")
	else:
		await _wait(0.4)
		await _shot("10_win_summary")

	# 重試 → 第 2 輪不出手：完全重演
	await _press(KEY_R)
	_check("R 重試回到準備狀態", bt.phase == bt.Phase.PREPARE and bt.bird.hp == bt.bird.max_hp and bt.casts.is_empty())
	_check("重試後回到戰場鏡頭", not bt.defeat_shown and player.get_node("Head/Camera3D").current)
	_check("重試保留觀察位置", player.global_position.distance_to(keep_pos) < 0.05,
		"現在 %s，原本 %s" % [str(player.global_position), str(keep_pos)])
	Engine.time_scale = 4.0
	await _press(KEY_ENTER)
	await _wait_end(bt, 150.0)
	Engine.time_scale = 1.0
	var same: bool = bt.events.size() == ev1.size()
	if same:
		for i in ev1.size():
			if ev1[i].t != bt.events[i].t or ev1[i].text != bt.events[i].text:
				same = false
				break
	if not same:
		for i in mini(ev1.size(), bt.events.size()):
			if ev1[i].t != bt.events[i].t or ev1[i].text != bt.events[i].text:
				print("    DIFF #%d  第1輪 %.3f %s ｜ 第2輪 %.3f %s" % [i, ev1[i].t, ev1[i].text, bt.events[i].t, bt.events[i].text])
				break
	_check("不出手時戰局完全重演", same, "兩輪事件 %d / %d 筆" % [ev1.size(), bt.events.size()])

	# 第 3 輪：準備階段用準心撒飼料 → 雞先跑去吃
	await _press(KEY_R)
	await _press(KEY_1)
	var feed_a := Vector3(-4.0, 0, 17.5)
	var feed_b := Vector3(-6.4, 0, 15.0)
	await _aim_click_ground(feed_a)
	await _aim_click_ground(feed_b)
	_check("準心左鍵撒下飼料", bt.feeds.size() == 2, "地上 %d 把飼料" % bt.feeds.size())
	Engine.time_scale = 4.0
	await _press(KEY_ENTER)
	var shot_eat := false
	var linger_t := 0.0
	var min_x := 99.0
	while bt.phase == bt.Phase.RUNNING and bt.time < 12.0:
		await get_tree().physics_frame
		min_x = minf(min_x, bt.bird.pos.x)
		if bt.bird.state == "linger":
			linger_t = maxf(linger_t, bt.bird.t)
		if not shot_eat and bt.bird.state == "eat":
			shot_eat = true
			Engine.time_scale = 0.0
			await _look_at_point(bt.bird.pos + Vector3(0, 0.6, 0), 5.0, 2.0)
			await _shot("11_feed_lure")
			player.global_position = keep_pos
			player.velocity = Vector3.ZERO
			Engine.time_scale = 4.0
	var eaten := 0
	for e in bt.events:
		if e.text.contains("吃掉"):
			eaten += 1
	_check("家豪被飼料引開、傻傻吃完", eaten >= 2 and min_x < -5.0, "吃了 %d 把，最遠走到 x=%.1f" % [eaten, min_x])
	_check("吃完飼料會在原地待一下才繼續衝", linger_t >= 2.5, "停留 %.1f 秒" % linger_t)
	Engine.time_scale = 1.0

	# 第 4 輪：香蕉皮——家豪和農夫走過去踩到都會滑倒，躺一陣子再起來
	await _press(KEY_R)
	Engine.time_scale = 1.0
	await _press(KEY_ENTER)
	await _wait(0.4)
	var bdir: Vector3 = (bt.bird.target.pos - bt.bird.pos) if bt.bird.target else Vector3.FORWARD
	bdir.y = 0
	var peel_pt: Vector3 = bt._ground(bt.bird.pos + bdir.normalized() * 1.2)
	var peel_ok: bool = bt.cast(1, peel_pt)
	var bird_slip := false
	var slip_len := 0.0
	for i in 400:
		await get_tree().physics_frame
		if bt.bird.state == "slip":
			bird_slip = true
			slip_len = bt.bird.t
		elif bird_slip:
			break
	_check("家豪踩到香蕉皮會滑倒、躺一陣子再起來", peel_ok and bird_slip and slip_len >= 2.5 and bt.peels.is_empty(),
		"躺了 %.1f 秒" % slip_len)
	# 農夫：在正在巡邏走路的農夫腳邊丟一片
	var walker = null
	for i in 600:
		await get_tree().physics_frame
		for f in bt.farmers:
			if not f.is_boss and f.alive() and f.state == "patrol":
				walker = f
		if walker:
			break
	var farmer_slip := false
	if walker:
		bt.cast(1, bt._ground(walker.pos))
		for i in 120:
			await get_tree().physics_frame
			if walker.state == "slip":
				farmer_slip = true
				break
	_check("農夫踩到香蕉皮也會滑倒", farmer_slip, (walker.name if walker else "沒有在巡邏的農夫"))
	if farmer_slip:
		await _wait(0.8)
		await _look_at_point(walker.pos + Vector3(0, 0.6, 0), 5.0, 2.5)
		await _wait(0.2)
		await _shot("12_banana_slip")
	player.global_position = keep_pos

	# 冷卻時間：用過一次要等一下；三個依序越來越長
	await _press(KEY_R)
	bt.no_cooldown = false
	var fpt: Vector3 = bt._ground(Vector3(-4.0, 0, 17.5))
	var c1: bool = bt.cast(0, fpt)
	var c2: bool = bt.cast(0, fpt + Vector3(0.5, 0, 0))
	var cd_order: bool = bt.SKILLS[0].cooldown < bt.SKILLS[1].cooldown and bt.SKILLS[1].cooldown < bt.SKILLS[2].cooldown
	await _wait(0.3)
	await _shot("08g_cooldown")
	await _wait(bt.SKILLS[0].cooldown)
	var c3: bool = bt.cast(0, fpt + Vector3(1.0, 0, 0))
	_check("神蹟有冷卻時間（飼料＜香蕉皮＜巨石）", c1 and not c2 and c3 and cd_order,
		"%s / %s / %s 秒" % [bt.SKILLS[0].cooldown, bt.SKILLS[1].cooldown, bt.SKILLS[2].cooldown])
	bt.no_cooldown = true
	await _press(KEY_R)

	# 巨石規則：平地也能放、有人站的地方不能放、放在坡上會滾下來
	await _press(KEY_R)
	await _press(KEY_3)
	var slope_pt := Vector3(14.0, 0, 2.0)   # 台地第一階的台面上（靠北邊）
	slope_pt.y = world.height_at(slope_pt.x, slope_pt.z)
	var flat_pt := Vector3(0, world.height_at(0, -2.4), -2.4)
	_check("巨石可以放在平地", bt.cast(2, flat_pt) and bt.rocks.size() == 1)
	await _press(KEY_R)
	var keep_f: Vector3 = bt.farmers[2].pos
	bt.farmers[2].pos = slope_pt
	_check("有敵人站的地方不能放巨石", not bt.cast(2, slope_pt) and bt.rocks.is_empty())
	bt.farmers[2].pos = keep_f
	var bird_pt: Vector3 = bt.bird.pos
	_check("有家豪站的地方也不能放巨石", not bt.cast(2, bird_pt) and bt.rocks.is_empty())
	await _aim_only(slope_pt)
	await get_tree().process_frame
	_check("瞄準山坡時顯示預測滾動路徑", bt.visible_dots() >= 4 and bt.aim_error == "", "路徑點 %d 個" % bt.visible_dots())
	await _look_at_point(slope_pt + Vector3(-3, 0, 0), 12.0, 6.0)
	await _aim_only(slope_pt)
	await get_tree().process_frame
	await _shot("13_rock_path_preview")
	player.global_position = keep_pos
	player.velocity = Vector3.ZERO
	Engine.time_scale = 1.0
	await _press(KEY_ENTER)
	var ok_cast: bool = bt.cast(2, slope_pt)
	var start_pt: Vector3 = bt.rocks[0].node.position if ok_cast else Vector3.ZERO
	await _wait(3.0)
	var end_pt: Vector3 = bt.rocks[0].node.position if ok_cast else Vector3.ZERO
	var moved := Vector2(end_pt.x - start_pt.x, end_pt.z - start_pt.z).length()
	_check("巨石放在山坡上會滾下來", ok_cast and moved > 4.0 and end_pt.y < start_pt.y - 1.5,
		"滾了 %.1fm，下降 %.1fm，路徑共 %d 點" % [moved, start_pt.y - end_pt.y, bt.rocks[0].path.size() if ok_cast else 0])

	# 老闆：家豪靠近就開槍，家豪被打中會逃走、啄不到老闆
	await _press(KEY_R)
	Engine.time_scale = 1.0
	await _press(KEY_ENTER)
	for f in bt.farmers:
		if not f.is_boss:
			f.hp = 0.0
			f.set_state("dead")
	var bossf = bt.boss
	var bc: Vector3 = world.barn_pos
	# 家豪在穀倉東牆外（在射程內，但被牆擋住）：老闆不能開槍
	var east: Vector3 = bt._ground(Vector3(bc.x + 7.0, 0, bc.z - 1.0))
	for k in 4:
		bt.cast(0, east + Vector3(0.2 * k, 0, 0.1 * k))
	bt.bird.pos = east
	var shot_through_wall := false
	for i in 150:
		await get_tree().physics_frame
		for e in bt.events:
			if e.text.contains("老闆開槍"):
				shot_through_wall = true
	_check("牆擋住時老闆不會開槍", not shot_through_wall and _flat(bt.bird.pos, bossf.pos) < 11.0,
		"家豪離老闆 %.1fm" % _flat(bt.bird.pos, bossf.pos))
	# 吃完飼料後家豪會繞到門口進去：全程不能穿牆，從門口被看到就會挨槍
	var crossed_wall := false
	var prev: Vector3 = bt.bird.pos
	var shot := false
	var hp_before_shot: float = bt.bird.hp
	for i in 600:
		await get_tree().physics_frame
		if bt._wall_crossing(prev, bt.bird.pos) != null:
			crossed_wall = true
		prev = bt.bird.pos
		for e in bt.events:
			if e.text.contains("老闆開槍"):
				shot = true
		if shot:
			break
	_check("家豪只從穀倉門口進去，不會穿牆", not crossed_wall)
	_check("老闆會開槍，家豪被槍聲嚇得飛走（不扣血）", shot and bt.bird.state == "fly" and bossf.alive() and bt.bird.hp >= hp_before_shot, "家豪狀態=%s，血 %.1f→%.1f" % [bt.bird.state, hp_before_shot, bt.bird.hp])
	_check("嚇跑時對話框跳出 THERE IS NOTHING I CAN DO（含拿破崙圖）", bt._dialog.showing() and bt._dialog.text == "THERE IS NOTHING I CAN DO" and bt._dialog.pic != null and bt._dialog.portrait != null)
	await _wait(0.4)
	await _shot("13g_nothing_i_can_do")
	await _look_at_point(bossf.pos + Vector3(0, 1.5, 4.0), 9.0, 4.0)
	await _shot("13b_boss_shoots")
	player.global_position = keep_pos
	player.velocity = Vector3.ZERO

	# 骨牌：從台地放巨石 → 撞倒水塔 → 一座接一座 → 砸垮大穀倉 → 老闆倒下
	await _press(KEY_R)
	await _press(KEY_ENTER)
	var t4: Dictionary = bt.towers[4]
	var spot := Vector3.ZERO
	for gx in range(6, 18):
		for gz in range(0, 11):
			var c := Vector3(float(gx), 0, float(gz))
			if bt.placement_error(2, c) != "":
				continue
			var path: PackedVector3Array = bt.simulate_roll(c)
			if path.size() > 2:
				var last := path[path.size() - 1]
				if Vector2(last.x - t4.pos.x, last.z - t4.pos.y).length() < t4.radius + 1.5:
					spot = c
					break
		if spot != Vector3.ZERO:
			break
	# 瞄準這個點：路徑會撞到的水塔要亮綠色
	await _press(KEY_3)
	Engine.time_scale = 1.0
	await _look_at_point(bt._ground(spot) + Vector3(-2, 0, -4), 14.0, 9.0)
	await _aim_only(bt._ground(spot))
	await get_tree().process_frame
	await get_tree().process_frame
	# 用這個放置點的預測路徑檢查（滑鼠準心打到的點會差一點點）
	bt._path_cache_at = bt._ground(spot)
	bt._path_cache = bt.simulate_roll(bt._ground(spot))
	bt._update_highlights(bt._path_cache, true)
	_check("巨石路徑會撞到的水塔亮綠色", bt.highlighted == [4], "亮綠色：%s" % str(bt.highlighted))
	await _shot("13e_green_highlight")
	# 準心直接指著水塔（巨石沒有滾過去）時不要亮綠色
	var t4p: Vector2 = bt.towers[4].pos
	var at_tower: Vector3 = bt._ground(Vector3(t4p.x + bt.towers[4].radius + 0.3, 0, t4p.y))
	bt._update_highlights(bt.simulate_roll(at_tower), true)
	_check("準心直接指著水塔時不亮綠色", bt.highlighted.is_empty(), "亮綠色：%s" % str(bt.highlighted))
	bt._update_highlights(bt._path_cache, true)
	var cast_ok: bool = spot != Vector3.ZERO and bt.cast(2, bt._ground(spot))
	var shot_mid := false
	for i in 900:
		await get_tree().physics_frame
		if not shot_mid and bt.towers[2].state == "fall":
			shot_mid = true
			Engine.time_scale = 0.0
			await _look_at_point(Vector3(5.0, 3.0, -10.0), 20.0, 13.0)
			await _shot("13c_domino")
			Engine.time_scale = 1.0
		if not bt.boss.alive():
			break
	var fallen: int = bt.towers.filter(func(t): return t.state != "stand").size()
	_check("骨牌：巨石撞倒水塔，五座接連倒下，砸垮穀倉打倒老闆", cast_ok and fallen == 5 and bt.barn_state != "stand" and not bt.boss.alive(),
		"放置點 %s，倒下 %d 座，穀倉=%s，老闆存活=%s" % [str(spot), fallen, bt.barn_state, str(bt.boss.alive())])
	await _wait(1.0)
	await _look_at_point(Vector3(-4.0, 2.0, -12.0), 18.0, 11.0)
	await _shot("13d_barn_down")
	player.global_position = keep_pos
	player.velocity = Vector3.ZERO

	# 水池：把飼料撒在小島上，家豪飛過去；發現他、追過去的農夫會掉進水裡淹死
	await _press(KEY_R)
	await _press(KEY_ENTER)
	var pc: Vector2 = world.pond_center
	var pr: float = world.pond_r
	bt.cast(0, bt._ground(Vector3(pc.x, 0, pc.y)))
	bt.cast(0, bt._ground(Vector3(pc.x + 0.4, 0, pc.y + 0.3)))
	bt.cast(0, bt._ground(Vector3(pc.x - 0.4, 0, pc.y - 0.2)))
	bt.bird.pos = bt._ground(Vector3(pc.x + pr + 1.5, 0, pc.y))
	var fd = bt.farmers[1]
	fd.pos = bt._ground(Vector3(pc.x + pr + 4.0, 0, pc.y + 1.0))
	bt._aggro(fd)
	var on_island := false
	var drowned := false
	var shot_pond := false
	for i in 600:
		await get_tree().physics_frame
		if world.on_island(bt.bird.pos.x, bt.bird.pos.z) and bt.bird.state == "eat":
			on_island = true
		if not shot_pond and fd.state == "drown":
			shot_pond = true
			Engine.time_scale = 0.0
			await _look_at_point(Vector3(pc.x, 0.5, pc.y), 11.0, 7.0)
			await _shot("13f_pond_drown")
			Engine.time_scale = 1.0
		for e in bt.events:
			if e.text.contains("溺死"):
				drowned = true
		if drowned and on_island:
			break
	_check("飼料撒在小島上，家豪會飛上去", on_island)
	_check("追家豪的農夫掉進水池溺死", drowned, "%s 狀態=%s" % [fd.name, fd.state])
	player.global_position = keep_pos
	player.velocity = Vector3.ZERO

	# 第 5 輪：簡單的出手策略 → 能贏（確認關卡打得過）
	# 準備階段先撒一排飼料，把家豪引到山坡腳下，在巨石滾得到的地方開打
	await _press(KEY_R)
	for fp in [Vector3(2.0, 0, 11.5), Vector3(4.5, 0, 7.5), Vector3(5.5, 0, 3.0), Vector3(4.0, 0, -2.0)]:
		bt.cast(0, Vector3(fp.x, world.height_at(fp.x, fp.z), fp.z))
	Engine.time_scale = 4.0
	await _press(KEY_ENTER)
	var shot_rock := false
	while bt.phase == bt.Phase.RUNNING and bt.time < 200.0:
		await get_tree().physics_frame
		_bot(bt)
		if not shot_rock and bt.rocks.size() > 0 and bt.rocks[0].i > 25 and not bt.rocks[0].done:
			shot_rock = true
			Engine.time_scale = 0.0
			await _look_at_point(bt.rocks[0].node.position + Vector3(0, 1.0, 0), 10.0, 5.0)
			await _shot("14_stone_ball_rolling")
			player.global_position = keep_pos
			player.velocity = Vector3.ZERO
			Engine.time_scale = 4.0
	Engine.time_scale = 1.0
	for e in bt.events:
		print("    BOT %.2fs %s" % [e.t, e.text])
	print("[INFO] 自動出手策略的結果：%s，%.1f 秒，剩 %d 個農夫" % [bt.outcome, bt.time,
		bt.farmers.filter(func(f): return f.alive()).size()])
	await _wait(0.4)
	await _shot("15_win_summary")
	await _press(KEY_R)

## 簡單策略：農夫離雞有點距離時砸巨石；雞血少、旁邊沒人時撒飼料回血；被兩個以上圍住時撒飼料把雞引開
func _bot(bt: Node) -> void:
	var b = bt.bird
	var used := {}
	for c in bt.casts:
		used[c.id] = used.get(c.id, 0) + 1
	if used.get("rock", 0) >= 2 and used.get("feed", 0) >= 8:
		return
	# 一次只放一個：上一顆巨石還沒落地時先不放
	for r in bt.rocks:
		if not r.done:
			return
	if bt.charges[2] != 0 and Engine.get_physics_frames() % 12 == 0:
		var best := Vector3.ZERO
		var best_i := 99999
		for gx in range(6, 18):
			for gz in range(0, 11, 2):
				var c := Vector3(float(gx), 0, float(gz))
				if bt.placement_error(2, c) != "":
					continue
				var path: PackedVector3Array = bt.simulate_roll(c)
				for f in bt.farmers:
					if not f.alive() or not f.aggro or not f.state in ["idle", "pant", "recover", "alert", "windup", "down"]:
						continue
					if _flat(f.pos, b.pos) < 2.6:
						continue
					for i in range(1, mini(path.size(), 150)):
						if _flat(path[i], f.pos) < 0.9 and _flat(path[i], path[i - 1]) * 60.0 > 1.6:
							if i < best_i:
								best_i = i
								best = c
							break
		if best_i < 150:
			bt.cast(2, best)
			return
	# 血少、附近沒農夫：在身邊撒飼料讓牠吃一口回血
	if bt.charges[0] != 0 and b.hp <= 6.0 and bt.feeds.is_empty() and b.state in ["charge", "return"]:
		var nf = bt._nearest_farmer(b.pos)
		if nf and _flat(nf.pos, b.pos) > 6.0:
			var away2: Vector3 = b.pos - nf.pos
			away2.y = 0
			bt.cast(0, b.pos + away2.normalized() * 1.5)
			return
	if bt.charges[0] != 0 and b.state in ["charge", "return"]:
		var close: Array = bt.farmers.filter(func(f): return f.alive() and _flat(f.pos, b.pos) < 7.0)
		if close.size() >= 2 and bt.feeds.is_empty():
			var away: Vector3 = b.pos - close[0].pos
			away.y = 0
			bt.cast(0, b.pos + away.normalized() * 5.0)

func _look_at_point(target: Vector3, dist: float, up: float) -> void:
	player.velocity = Vector3.ZERO
	var dir := Vector3(0.6, 0, 0.8).normalized()
	player.global_position = target + dir * dist + Vector3(0, up - 1.65, 0)
	var d := target - (player.global_position + Vector3(0, 1.65, 0))
	player.rotation.y = atan2(-d.x, -d.z)
	head.rotation.x = atan2(d.y, Vector2(d.x, d.z).length())
	await get_tree().process_frame
	await get_tree().process_frame

## 只轉向地面上的某一點（不按）
func _aim_only(p: Vector3) -> void:
	var cam: Camera3D = player.get_node("Head/Camera3D")
	var d: Vector3 = p - cam.global_position
	player.rotation.y = atan2(-d.x, -d.z)
	head.rotation.x = atan2(d.y, Vector2(d.x, d.z).length())
	await get_tree().process_frame

## 轉向地面上的某一點，按左鍵施放目前選的神蹟
func _aim_click_ground(p: Vector3) -> void:
	var world := get_node("/root/Main/World")
	var tgt := Vector3(p.x, world.height_at(p.x, p.z), p.z)
	for attempt in 3:
		player.call("_set_looking", true)
		var cam: Camera3D = player.get_node("Head/Camera3D")
		var d: Vector3 = tgt - cam.global_position
		player.rotation.y = atan2(-d.x, -d.z)
		head.rotation.x = atan2(d.y, Vector2(d.x, d.z).length())
		await get_tree().process_frame
		var bt := get_node("/root/Main/Battle")
		var before: int = bt.casts.size()
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			_click()
			await get_tree().process_frame
			await get_tree().process_frame
		if bt.casts.size() > before:
			return
	# 視窗沒有焦點時 macOS 不讓程式鎖游標；改用同一條準心判定直接施放
	print("[INFO] 視窗未取得焦點，改用準心判定直接施放")
	get_node("/root/Main/Battle").try_cast()
