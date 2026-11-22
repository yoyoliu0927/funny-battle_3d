extends SceneTree
## 特寫截圖：每一種特寫各拍一張，看機位有沒有被樹或牆擋住。（要開視窗，不能 --headless）
## Godot --path . --script res://levels/forest/tests/closeups.gd -- <輸出資料夾>
const DT := 1.0 / 60.0
const S1 := "res://levels/forest/stage_3/stage.tscn"
var bt
var out := "user://forest_closeups"

func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		out = a[0]
	DirAccess.make_dir_recursive_absolute(out)
	_go.call_deferred()

func steps(sec: float) -> void:
	for i in int(sec / DT):
		if bt.phase != bt.Phase.RUNNING:
			return
		bt.bird.t = -9999.0
		bt._step(DT)

func shot(name: String) -> void:
	bt._apply_visuals()
	bt._level_visuals()
	for i in 4:
		await process_frame
	var img := root.get_texture().get_image()
	img.save_png(out.path_join(name + ".png"))
	print("  shot ", name, "  cut=", bt._cutting())

func who(name: String):
	for f in bt.enemies:
		if f.name == name:
			return f
	return null

func fresh() -> void:
	bt.reset()
	bt.start()
	bt.bird.pos = bt.ground(Vector3(15.5, 0, -13.5))
	bt.bird.set_state("linger")

func _go() -> void:
	change_scene_to_file(S1)
	for i in 8:
		await process_frame
	bt = current_scene.get_node("Battle")
	bt.set_physics_process(false)
	bt.cuts_in_tests = true
	if bt.help_popup:
		bt.help_popup.visible = false
	bt._set_tut_step(-1)

	fresh()
	var ti: int = bt._nearest_tree(Vector3(5, 0, 4), 99.0)
	bt._fell(ti, bt.grove[ti].pos + Vector3(-1.0, 0, 0.4))
	steps(0.45)
	await shot("1_fell_mid")
	steps(0.5)
	await shot("2_fell_down")

	fresh()
	var t2: int = bt._nearest_tree(Vector3(-6, 0, 7), 99.0)
	bt._ignite_tree(t2, "測試")
	steps(1.4)
	await shot("3_spark")

	fresh()
	var sm = who("抽菸1")
	steps(10.0)
	bt._cut_off()
	bt._cut_gap = 0.0
	bt.add_decoy(bt.ground(sm.pos + Vector3(3.0, 0, -2.0)))
	steps(0.3)
	await shot("4_drop")

	fresh()
	bt.add_basket(bt.ground(bt.escape_point))
	for i in 400:
		steps(DT)
		if bt._cutting():
			break
	steps(0.5)
	await shot("5_basket")

	fresh()
	var ch = who("伐木1")
	bt.bird.pos = bt.ground(ch.pos + Vector3(0.8, 0, 0.6))
	bt.bird.set_state("charge")
	bt._sneak(ch)
	steps(0.1)
	await shot("6_sneak")

	fresh()
	bt.bird.pos = bt.ground(bt.escape_point + Vector3(0, 0, -1.2))
	bt.bird.set_state("charge")
	steps(1.2)
	await shot("7_hood")
	print("done -> ", ProjectSettings.globalize_path(out))
	quit()
