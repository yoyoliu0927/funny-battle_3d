extends SceneTree
## 每一關從上面俯看拍一張（看場地排得好不好）。要開視窗。
## Godot --path . --script res://levels/forest/tests/overview.gd -- <輸出資料夾>
var out := "user://forest_overview"

func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		out = a[0]
	DirAccess.make_dir_recursive_absolute(out)
	_go.call_deferred()

func _go() -> void:
	for n in [1, 2, 3]:
		change_scene_to_file("res://levels/forest/stage_%d/stage.tscn" % n)
		for i in 8:
			await process_frame
		var bt = current_scene.get_node("Battle")
		bt.set_process(false)                       # 偵測扇形不畫（會蓋住地面）
		for f in bt.enemies:
			if f.cone:
				f.cone.visible = false
		var pond := bt.world.get_node_or_null("Pond") as Node3D
		if pond:
			print("    水面 y=%.2f  中心地面 %.2f  岸邊地面 %.2f  可見 %s" % [pond.global_position.y,
				bt.world.height_at(0.0, -1.0), bt.world.height_at(2.6, -1.0), pond.is_visible_in_tree()])
		var cam := Camera3D.new()
		cam.fov = 55.0
		bt.world.add_child(cam)
		cam.global_position = Vector3(0, 30, 13)
		cam.look_at(Vector3(0, 0, 0.5), Vector3.UP)
		cam.make_current()
		for i in 6:
			await process_frame
		root.get_texture().get_image().save_png(out.path_join("stage_%d.png" % n))
		print("  stage ", n)
	quit()
