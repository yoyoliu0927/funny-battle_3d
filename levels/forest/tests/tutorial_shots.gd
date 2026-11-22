extends SceneTree
## 三關的新手教學：每一步截一張圖，要動手的步驟由腳本代做（選道具、放道具），確認做到就會往下走。
## Godot --path . --script res://levels/forest/tests/tutorial_shots.gd -- <輸出資料夾>
var bt
var out := "user://forest_tutorial"
var fails := 0

func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		out = a[0]
	DirAccess.make_dir_recursive_absolute(out)
	Engine.set_meta("forest_tut_force", true)
	_go.call_deferred()

func frames(n: int) -> void:
	for k in n:
		await process_frame

func shot(name: String) -> void:
	var img := root.get_texture().get_image()
	img.save_png(out.path_join(name + ".png"))

func _go() -> void:
	for stage in [1, 2, 3]:
		await _walk(stage)
	print("TUTORIAL: ALL PASS" if fails == 0 else "TUTORIAL: FAILED (%d)" % fails)
	print("shots -> ", ProjectSettings.globalize_path(out))
	quit(1 if fails > 0 else 0)

func _walk(stage: int) -> void:
	change_scene_to_file("res://levels/forest/stage_%d/stage.tscn" % stage)
	await frames(10)
	bt = current_scene.get_node("Battle")
	var t = bt.tut
	if t == null or not t.active():
		print("FAIL 第 %d 關的教學沒有開始" % stage)
		fails += 1
		return
	var n: int = t.steps.size()
	var guard := 0
	while t.active() and guard < 40:
		guard += 1
		var k: int = t.i
		await frames(70)                     # 等鏡頭飛完、聚光燈亮起來
		await shot("s%d_step_%02d" % [stage, k + 1])
		var s: Dictionary = t.steps[k]
		var w = s.get("wait", "next")
		print("  第 %d 關 %d/%d  %s" % [stage, k + 1, n, String(s.say).split("\n")[0]])
		if w is String and w == "next":
			t._go(k + 1)
		elif w is String and w == "start":
			break
		else:
			_do(String(s.say))
			await frames(40)
			if t.i == k:
				print("FAIL 第 %d 關第 %d 步做了還是沒往下走" % [stage, k + 1])
				fails += 1
				return
	bt.start()
	await frames(5)
	if t.active():
		print("FAIL 第 %d 關開打後教學沒收掉" % stage)
		fails += 1

## 代替玩家做這一步（看說明文字判斷要做什麼）
func _do(s: String) -> void:
	for k in ["1", "2", "3"]:
		if s.contains("按 %s 拿起" % k):
			bt.select_skill(int(k) - 1)
			return
	if s.contains("伐木工旁邊"):
		bt.cast(bt.skill_index("decoy"), bt.ground(bt.tut_enemy("伐木1").pos + Vector3(-0.5, 0, -2.5)))
	elif s.begins_with("放在木屋門口"):
		bt.cast(bt.skill_index("basket"), bt.ground(bt.escape_point + Vector3(1.2, 0, -0.6)))
	elif s.contains("木屋門口插"):
		bt.cast(bt.skill_index("guide"), bt.ground(bt.escape_point))
	elif s.contains("插旗子"):
		bt.cast(bt.skill_index("guide"), bt.ground(bt.tut_enemy("伐木1").pos + Vector3(1.5, 0, -2.5)))
