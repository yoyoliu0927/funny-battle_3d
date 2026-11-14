extends SceneTree
## 分鏡：用玩家一開始的鏡頭位置，把一局拍成連續截圖（像看實況）。
## Godot --path <專案> --script storyboard.gd -- <stage> <輸出資料夾> "<施放列表>"
##   施放列表：分號分隔，每項 "秒,道具序號,x,z"；秒 = -1 代表準備階段。例："-1,0,2,-2;1.0,0,-3,-1.5"
## 會拍：教學每一頁、準備畫面、每次施放前的「瞄準」畫面、開打後每 0.75 秒一張、結束畫面。

const DT := 1.0 / 60.0
var bt
var world
var player
var head
var out := ""
var n := 0
var cam_pos: Vector3
var cam_rot: Vector3
var head_rot: Vector3
var took_top := false

func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	out = a[1]
	DirAccess.make_dir_recursive_absolute(out)
	change_scene_to_file(String(a[0]) if String(a[0]).begins_with("res://") else "res://levels/ice/stage_%s/stage.tscn" % a[0])
	_go.call_deferred()

func g(x: float, z: float) -> Vector3:
	return Vector3(x, world.height_at(x, z), z)

func _shot(tag: String) -> void:
	bt._apply_visuals()
	for i in 3:
		await process_frame
	# 背景執行時 macOS 會暫停視窗繪圖，等 frame_post_draw 可能等不到：直接強制畫一張
	RenderingServer.force_draw(true, 0.0)
	n += 1
	var name := "%02d_%s.png" % [n, tag]
	root.get_viewport().get_texture().get_image().save_png(out.path_join(name))
	var c := root.get_viewport().get_camera_3d()
	print("frame ", name, " cam=", c.name, " pos=", c.global_position, " fwd=", -c.global_basis.z, " head=", head.rotation, " player_rot=", player.rotation)

func _aim(p: Vector3) -> void:
	var cam: Camera3D = player.get_node("Head/Camera3D")
	var d: Vector3 = p - cam.global_position
	player.rotation.y = atan2(-d.x, -d.z)
	head.rotation.x = atan2(d.y, Vector2(d.x, d.z).length())

func _restore() -> void:
	player.global_position = cam_pos
	player.rotation = cam_rot
	head.rotation = head_rot

func _go() -> void:
	# 場景一出現就先關掉真的滑鼠鍵盤（使用者正在用電腦，前幾格點到視窗會多丟一片香蕉皮）
	for i in 10:
		await process_frame
		if current_scene and current_scene.has_node("Battle"):
			current_scene.get_node("Battle").set_process_unhandled_input(false)
			current_scene.get_node("Player").set_process_unhandled_input(false)
	bt = current_scene.get_node("Battle")
	if not bt.casts.is_empty():
		bt.reset()
	world = bt.world
	player = current_scene.get_node("Player")
	head = player.get_node("Head")
	bt.set_physics_process(false)
	# 戰局本身也不吃真的滑鼠鍵盤（不然有人點到視窗就會多丟一片香蕉皮）
	bt.set_process_unhandled_input(false)
	bt.set_process_input(false)
	# 分鏡時不吃真的滑鼠（不然有人在用電腦時鏡頭會被轉走）
	player.set_process_unhandled_input(false)
	player.set_physics_process(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	cam_pos = player.global_position
	cam_rot = player.rotation
	head_rot = head.rotation
	var casts: Array = []
	var a := OS.get_cmdline_user_args()
	if a.size() > 2 and String(a[2]) != "":
		for part in String(a[2]).split(";"):
			var v := part.split(",")
			casts.append([float(v[0]), int(v[1]), float(v[2]), float(v[3])])
	# 教學每一頁
	var texts: Array = bt._tutorial_texts()
	for i in texts.size():
		bt._set_tut_step(i)
		bt._tick_tutorial(0.0)
		await _shot("tutorial%d" % (i + 1))
	bt._set_tut_step(-1)
	# 有開場示範的關卡：推進準備階段的時間，拍示範的幾個瞬間，最後跳過示範
	if bt.get("show_timing") == true:
		var t0: float = bt._prep_t0
		for k in [1.0, 2.2, 3.4, 4.6]:
			bt._tick_clock(t0 + k - bt._clock)
			await _shot("demo_%.1f" % k)
		bt._tick_clock(t0 + 12.0 - bt._clock)
	await _shot("prepare")
	# 幾秒後的「平常狀態」：說明、大標題都收起來了
	bt._tick_clock(7.0)
	await _shot("prepare_steady")
	for c in casts:
		if c[0] < 0:
			bt.selected = c[1]
			_aim(g(c[2], c[3]))
			await _shot("prep_aim")
			# 第一次瞄準時，順便拍一張按住 Tab 的俯視圖
			if bt.get("force_top") != null and not took_top:
				took_top = true
				bt.force_top = true
				bt._process(0.016)
				await _shot("top_view")
				bt.force_top = false
				bt._process(0.016)
			bt.cooldowns[c[1]] = 0.0
			bt.cast(c[1], g(c[2], c[3]))
			_restore()
	if casts.any(func(c): return c[0] < 0):
		await _shot("prepare_done")
	bt.start()
	var next_shot := 0.0
	var k := 0
	var run_casts: Array = casts.filter(func(c): return c[0] >= 0)
	while bt.phase == bt.Phase.RUNNING and bt.time < 40.0:
		if k < run_casts.size() and bt.time >= run_casts[k][0]:
			var c: Array = run_casts[k]
			bt.selected = c[1]
			_aim(g(c[2], c[3]))
			await _shot("aim_t%.1f" % bt.time)
			bt.cast(c[1], g(c[2], c[3]))
			_restore()
			k += 1
		if bt.time >= next_shot:
			await _shot("t%.2f" % bt.time)
			next_shot += 0.75
		bt._tick_cooldowns(DT)
		bt._step(DT)
	await _shot("end_%s" % bt.outcome)
	# 結束後：照遊戲時間往前推，拍演出和結算
	var t_end := 0.0
	for mark in [0.5, 1.2, 2.6, 4.4]:
		while t_end < mark:
			bt._step(DT)
			t_end += DT
		if mark >= 2.6:
			bt._process(2.0)
		await _shot("after_%.1fs" % mark)
	for e in bt.events:
		print("EV %.2f %s" % [e.t, e.text])
	print("outcome ", bt.outcome, " time ", bt.time)
	quit()
