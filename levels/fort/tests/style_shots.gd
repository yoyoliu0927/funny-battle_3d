extends SceneTree
## 每個大關第一小關各截一張（準備階段），比較渲染風格。（要開視窗）
## Godot --path . -s res://levels/fort/tests/style_shots.gd -- <輸出資料夾>
const Registry := preload("res://scripts/registry.gd")
func _initialize() -> void:
	_go.call_deferred()
func _go() -> void:
	var out := "user://style_shots"
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		out = a[0]
	DirAccess.make_dir_recursive_absolute(out)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	for ch in Registry.chapters():
		if ch.example or ch.stages.is_empty() or (a.size() > 1 and ch.id != a[1]):
			continue
		change_scene_to_file(ch.stages[0].scene)
		for i in 150:
			await process_frame
		var img := root.get_texture().get_image()
		img.save_png(out.path_join("%s.png" % ch.id))
		print("SHOT | ", ch.id)
		var env: Environment = root.get_camera_3d().get_world_3d().environment if root.get_camera_3d() else null
		var we := current_scene.find_children("*", "WorldEnvironment", true, false)
		if not we.is_empty():
			env = (we[0] as WorldEnvironment).environment
		var sun := current_scene.find_children("*", "DirectionalLight3D", true, false)
		if env:
			print("ENV | %s | tonemap %d exp %.2f white %.2f | ambient src %d col %s e %.2f | glow %s | adj %s b%.2f c%.2f s%.2f | fog %s | bg %d" % [ch.id, env.tonemap_mode, env.tonemap_exposure, env.tonemap_white, env.ambient_light_source, env.ambient_light_color, env.ambient_light_energy, env.glow_enabled, env.adjustment_enabled, env.adjustment_brightness, env.adjustment_contrast, env.adjustment_saturation, env.fog_enabled, env.background_mode])
		for s in sun:
			var l := s as DirectionalLight3D
			print("SUN | %s | col %s e %.2f shadow %s rot %s" % [ch.id, l.light_color, l.light_energy, l.shadow_enabled, l.global_rotation_degrees])
	quit()
