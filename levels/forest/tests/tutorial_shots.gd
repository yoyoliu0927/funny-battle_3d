extends SceneTree
## 新手教學每一步截一張圖，要動手的步驟由腳本代做（選道具、放道具），確認做到就會往下走。
## Godot --path . --script res://levels/forest/tests/tutorial_shots.gd -- <輸出資料夾>
const S1 := "res://levels/forest/stage_1/stage.tscn"
var bt
var out := "user://forest_tutorial"

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
	change_scene_to_file(S1)
	await frames(10)
	bt = current_scene.get_node("Battle")
	var t = bt.tut
	if t == null or not t.active():
		print("FAIL 教學沒有開始")
		quit(1)
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
				print("FAIL 第 %d 步做了還是沒往下走" % (k + 1))
				quit(1)
				return
	print("done (%d steps) -> %s" % [n, ProjectSettings.globalize_path(out)])
	bt.start()
	await frames(5)
	print("教學在開打後收掉：", not t.active())
	quit()

## 代替玩家做這一步
func _do(k: int) -> void:
	var s: String = bt.tut.steps[k].say
	if s.begins_with("按 2"):
		bt.select_skill(bt.skill_index("guide"))
	elif s.begins_with("按 1"):
		bt.select_skill(bt.skill_index("decoy"))
	elif s.begins_with("按 3"):
		bt.select_skill(bt.skill_index("basket"))
	elif s.contains("插一支旗子"):
		bt.cast(bt.skill_index("guide"), bt.ground(bt.escape_point))
	elif s.contains("伐木工旁邊"):
		bt.cast(bt.skill_index("decoy"), bt.ground(bt.tut_enemy("伐木1").pos + Vector3(2.0, 0, 1.5)))
	elif s.contains("籃子放在門口"):
		bt.cast(bt.skill_index("basket"), bt.ground(bt.escape_point + Vector3(1.2, 0, -0.6)))
