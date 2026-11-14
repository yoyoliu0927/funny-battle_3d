extends SceneTree
## 從高處拍整張地圖：Godot --path . --script overview.gd -- <stage 號碼> <輸出.png>
func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	change_scene_to_file("res://levels/ice/stage_%s/stage.tscn" % a[0])
	_go.call_deferred()
func _go() -> void:
	var a := OS.get_cmdline_user_args()
	for i in 30:
		await process_frame
	var bt = current_scene.get_node("Battle")
	bt.set_physics_process(false)
	var player = current_scene.get_node("Player")
	player.set_process_unhandled_input(false)
	player.set_physics_process(false)
	var cam := Camera3D.new()
	cam.fov = 60.0
	current_scene.add_child(cam)
	var look: Vector3 = bt.world.camera_look
	cam.global_position = Vector3(look.x + 2.0, 30.0, look.z + 30.0)
	cam.look_at(Vector3(look.x, 0, look.z - 2.0), Vector3.UP)
	cam.make_current()
	for i in 6:
		await process_frame
	RenderingServer.force_draw(true, 0.0)
	root.get_viewport().get_texture().get_image().save_png(a[1])
	print("SHOT ", a[1])
	quit()
