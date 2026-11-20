extends SceneTree
## 新手教學每一步截一張圖，要動手的步驟由腳本代做（選道具、放道具），確認做到就會往下走。
## 在背景跑、不搶滑鼠（Player 換成 still_player.gd）：用 tutorial_shots.sh。
##   open -g -n -a <Godot.app> --args --path <專案> --resolution 1280x720 -s res://levels/forest/tests/tutorial_shots.gd -- --out=<資料夾> --stage=1
const STILL := preload("res://levels/forest/tests/still_player.gd")
const Wardrobe := preload("res://scripts/wardrobe.gd")
var bt
var out := "user://forest_tutorial"
var stage := 1

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		if a.begins_with("--stage="):
			stage = int(a.substr(8))
	DirAccess.make_dir_recursive_absolute(out)
	Engine.set_meta("forest_tut_force", true)
	_go.call_deferred()

func frames(n: int) -> void:
	for k in n:
		await process_frame

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))

func _done(msg: String, code := 0) -> void:
	print(msg)
	var f := FileAccess.open(out.path_join("DONE"), FileAccess.WRITE)
	f.store_string(msg)
	f.close()
	quit(code)

func _go() -> void:
	Wardrobe.preview = {"body": "hoodie"}
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var sc := (load("res://levels/forest/stage_%d/stage.tscn" % stage) as PackedScene).instantiate()
	sc.get_node("Player").set_script(STILL)
	Engine.set_meta("stage_id", "")
	root.add_child(sc)
	current_scene = sc
	await frames(12)
	bt = sc.get_node("Battle")
	var t = bt.tut
	if t == null or not t.active():
		_done("FAIL 教學沒有開始", 1)
		return
	var n: int = t.steps.size()
	var guard := 0
	while t.active() and guard < 40:
		guard += 1
		var k: int = t.i
		await frames(70)                     # 等鏡頭飛完、聚光燈亮起來
		await shot("step_%02d" % (k + 1))
		var s: Dictionary = t.steps[k]
		var w = s.get("wait", "next")
		print("  step %d/%d  %s" % [k + 1, n, String(s.say).split("\n")[0]])
		if w is String and w == "next":
			t._go(k + 1)
		elif w is String and w == "start":
			break
		else:
			_do(k)
			await frames(40)
			if t.i == k:
				_done("FAIL 第 %d 步做了還是沒往下走" % (k + 1), 1)
				return
	bt.start()
	await frames(5)
	_done("done (%d steps)，教學在開打後收掉：%s" % [n, str(not t.active())])

## 代替玩家做這一步
func _do(k: int) -> void:
	var s: String = bt.tut.steps[k].say
	if s.begins_with("按 "):
		bt.select_skill(int(s.substr(2, 1)) - 1)
	var cd := func(id: String):
		bt.cooldowns[bt.skill_index(id)] = 0.0
	if s.contains("插在木屋門口"):
		cd.call("guide")
		bt.cast(bt.skill_index("guide"), bt.ground(bt.escape_point))
	elif s.contains("伐木工旁邊的地上"):
		cd.call("guide")
		bt.cast(bt.skill_index("guide"), bt.ground(bt.tut_enemy("伐木1").pos + Vector3(1.5, 0, 1.5)))
	elif s.contains("放在另一個伐木工旁邊"):
		cd.call("decoy")
		bt.cast(bt.skill_index("decoy"), bt.ground(bt.tut_enemy("伐木2").pos + Vector3(2.0, 0, 1.5)))
	elif s.contains("潑一桶"):
		cd.call("bucket")
		bt.cast(bt.skill_index("bucket"), bt.ground(bt.tut_enemy("抽菸1").pos + Vector3(1.5, 0, 1.0)))
	elif s.contains("假獵物放在木屋門口"):
		cd.call("decoy")
		bt.cast(bt.skill_index("decoy"), bt.ground(bt.escape_point + Vector3(1.2, 0, -0.6)))
