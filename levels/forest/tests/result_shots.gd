extends SceneTree
## 結算卡截圖：過關一張、三種落敗各一張。（要開視窗，不能 --headless）
## Godot --path . --script res://levels/forest/tests/result_shots.gd -- <輸出資料夾>
const DT := 1.0 / 60.0
const S1 := "res://levels/forest/stage_3/stage.tscn"
var bt
var out := "user://forest_results"

func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		out = a[0]
	DirAccess.make_dir_recursive_absolute(out)
	_go.call_deferred()

func frames(n: int) -> void:
	for k in n:
		await process_frame

func shot(name: String) -> void:
	await frames(3)
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("  shot ", name)

func steps(sec: float, each: Callable = Callable()) -> void:
	for i in int(sec / DT):
		if bt.phase != bt.Phase.RUNNING:
			return
		bt._step(DT)
		if each.is_valid():
			each.call()

func fresh() -> void:
	bt.reset()
	await frames(2)

func _go() -> void:
	change_scene_to_file(S1)
	await frames(8)
	bt = current_scene.get_node("Battle")
	bt.set_physics_process(false)
	if bt.help_popup:
		bt.help_popup.visible = false

	# 過關：放幾個道具、籃子引開狼外婆、家豪進屋
	await fresh()
	bt.cast(bt.skill_index("guide"), bt.ground(bt.escape_point))
	bt.cast(bt.skill_index("decoy"), bt.ground(Vector3(-8.0, 0, 5.0)))
	bt.start()
	steps(6.0)
	bt._fell(bt._nearest_tree(Vector3(9, 0, -4), 99.0), Vector3(8, 0, -4))
	bt._ignite_tree(bt._nearest_tree(Vector3(-7, 0, 8), 99.0), "測試")
	bt.cast(bt.skill_index("basket"), bt.ground(bt.escape_point + Vector3(1.2, 0, -0.6)))
	steps(4.0)
	for f in bt.enemies:
		if f.kind == "smoker":
			f.hp = 0.0
			f.set_state("dead")
	bt.bird.pos = bt.ground(bt.escape_point + Vector3(0, 0, -1.4))
	steps(1.0)
	print("  過關：", bt.outcome)
	await frames(80)
	await shot("win")

	# 落敗：樹太多（燒的比砍的多 → 火災）
	await fresh()
	bt.start()
	for k in 4:
		var i: int = bt._nearest_tree(Vector3(10, 0, -4), 99.0)
		bt._fell(i, bt.grove[i].pos + Vector3(-1, 0, 0))
	for k in 7:
		bt._ignite_tree(bt._nearest_tree(Vector3(-6, 0, 6), 99.0), "測試")
	steps(0.2)
	print("  落敗：", bt.outcome, " ", bt.fail)
	await frames(150)
	await shot("lose_fire")

	# 落敗：小紅帽時間到
	await fresh()
	bt.start()
	bt.dinner = bt.hood_cap - 0.1
	steps(0.5)
	print("  落敗：", bt.outcome, " ", bt.fail)
	await frames(150)
	await shot("lose_hood")
	print("done -> ", ProjectSettings.globalize_path(out))
	quit()
