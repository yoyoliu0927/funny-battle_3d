extends SceneTree
## 量「站在主島上，背後那幾座主題島」花了多少：主島照常量一次，再把其他島藏起來量一次，相減就是遠方的島的成本。
## 也量世界地圖（替身）和開地圖場景要多久。只讀 level_select 的狀態，不改共用檔案。（要開視窗）
##   Godot --path . -s res://levels/fort/tests/hub_isles_probe.gd

func _initialize() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_go.call_deferred()

func _wait(n: int) -> void:
	for i in n:
		await process_frame

func _key(k: Key) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = k
	ev.keycode = k
	ev.pressed = true
	root.push_input(ev)
	var up := ev.duplicate()
	up.pressed = false
	root.push_input(up)

func _measure(label: String) -> void:
	await _wait(30)
	var t := Time.get_ticks_usec()
	var tot := 0.0
	for i in 120:
		await process_frame
		var now := Time.get_ticks_usec()
		tot += (now - t) / 1000.0
		t = now
	var rs := RenderingServer
	var cam := root.get_camera_3d()
	print("PROBE | 鏡頭 %s 看 %s" % [cam.global_position.round(), (-cam.global_basis.z).snapped(Vector3.ONE * 0.1)])
	print("PROBE | %-22s | %6.2f ms | draw %5d | obj %5d | tri %8d" % [label, tot / 120.0,
		rs.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		rs.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
		rs.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)])

func _go() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	if not "--title" in OS.get_cmdline_user_args():
		Engine.set_meta("title_done", true)   # 不放標題畫面：直接量主島上的畫面（加 --title 量真的第一次開遊戲）
	var t0 := Time.get_ticks_msec()
	var ps: PackedScene = load("res://scenes/level_select.tscn")
	var t1 := Time.get_ticks_msec()
	var sc: Node = ps.instantiate()
	root.add_child(sc)
	current_scene = sc
	var t2 := Time.get_ticks_msec()
	print("PROBE | 載入場景 %d ms、蓋地圖（_ready）%d ms" % [t1 - t0, t2 - t1])
	var lsm: Node = sc.get_node("Map")
	if "--early-map" in OS.get_cmdline_user_args():
		await _wait(3)
		var te := Time.get_ticks_usec()
		_key(KEY_M)
		await _wait(2)
		print("PROBE | 早早按 M：剩 %s，那兩格 %.0f ms" % [lsm.get("_isle_todo"), (Time.get_ticks_usec() - te) / 1000.0])
	if "_isle_todo" in lsm:
		var tq := Time.get_ticks_msec()
		print("PROBE | 背景要蓋的島：%s" % [lsm.get("_isle_todo")])
		while not (lsm.get("_isle_todo") as Array).is_empty():
			var tf := Time.get_ticks_usec()
			await process_frame
			print("PROBE |   一格 %.0f ms" % ((Time.get_ticks_usec() - tf) / 1000.0))
		print("PROBE | 背景蓋完：%d ms" % (Time.get_ticks_msec() - tq))
	await _wait(120)
	var ls: Node = sc.get_node("Map")
	var t_end := Time.get_ticks_msec() + 12000
	while Time.get_ticks_msec() < t_end:   # 標題畫面的鏡頭會動：等它停下來
		await process_frame
	# 試做 1：其他島在主島上也用替身（離替身中心超過「替身大小＋25 公尺」就換上）；原本和試做交替量兩次
	var old_begin := {}
	var new_begin := {}
	for p in ls.get("_far_proxies"):
		var mi := p as MeshInstance3D
		old_begin[mi] = mi.visibility_range_begin
		var bb: AABB = mi.global_transform * mi.get_aabb()
		new_begin[mi] = bb.size.length() * 0.5 + 25.0
	for rep in 2:
		for mi in old_begin:
			(mi as MeshInstance3D).visibility_range_begin = old_begin[mi]
		await _measure("主島（原本）")
		for mi in new_begin:
			(mi as MeshInstance3D).visibility_range_begin = new_begin[mi]
		await _measure("主島（替身）")
	var worlds: Array = ls.get("worlds")
	# 換成替身之後，其他島還有哪些東西是一直畫的（不在替身裡）：照原因分類，算「面數」（大約等於繪製次數，不算影子和視野外）
	var left := {}
	var proxy_surf := 0
	for mi in new_begin:
		proxy_surf += (mi as MeshInstance3D).mesh.get_surface_count()
	for e in worlds.size():
		var r0 = (worlds[e] as Dictionary).get("root")
		if ls._is_hub(e) or not is_instance_valid(r0):
			continue
		var ch_id := String(ls.entries[e].ch.get("id", "?"))
		for m in (r0 as Node).find_children("*", "GeometryInstance3D", true, false):
			var gi := m as GeometryInstance3D
			if not gi.is_visible_in_tree() or gi in new_begin or gi.visibility_parent != NodePath():
				continue
			var why := "其他"
			var surf := 1
			var anc: Node = gi
			var scripted := false
			while anc != r0:
				if anc.get_script() != null:
					scripted = true
				anc = anc.get_parent()
			if gi is MeshInstance3D and (gi as MeshInstance3D).mesh:
				var mm := (gi as MeshInstance3D).mesh
				surf = mm.get_surface_count()
				var nv := 0
				if mm is ArrayMesh:
					for si in surf:
						nv += (mm as ArrayMesh).surface_get_array_len(si)
				var see := false
				for si in surf:
					var mat := (gi as MeshInstance3D).get_active_material(si)
					if mat is BaseMaterial3D and (mat as BaseMaterial3D).transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
						see = true
				if scripted:
					why = "會動（腳本）"
				elif see:
					why = "半透明"
				elif nv > 4000:
					why = "頂點太多"
				elif mm.resource_path == "":
					why = "程式做的網格"
			elif scripted:
				why = "會動（腳本）"
			else:
				why = gi.get_class()
			var k2 := "%s｜%s" % [ch_id, why]
			left[k2] = int(left.get(k2, 0)) + surf
	print("PROBE | 替身共 %d 個、%d 面" % [new_begin.size(), proxy_surf])
	# 替身裡的材質：照「看起來一樣」分組（同一張貼圖、同顏色、同設定）能剩幾種
	var sigs := {}
	var mats := {}
	var kinds := {}
	for mi in new_begin:
		var mm := (mi as MeshInstance3D).mesh
		for si in mm.get_surface_count():
			var mat := mm.surface_get_material(si)
			mats[mat] = true
			var sig := _mat_sig(mat)
			sigs[sig] = true
			var kd := "貼圖" if mat is BaseMaterial3D and (mat as BaseMaterial3D).albedo_texture else ("著色器" if mat is ShaderMaterial else "純色")
			kinds[kd] = int(kinds.get(kd, 0)) + 1
	print("PROBE | 替身材質：%d 個物件、看起來不同的 %d 種、%s" % [mats.size(), sigs.size(), kinds])
	var keys := left.keys()
	keys.sort()
	for k in keys:
		print("PROBE | 沒進替身  %-24s %d 面" % [k, left[k]])
	var meshes := 0
	for e in worlds.size():
		var w: Dictionary = worlds[e]
		var r = w.get("root")
		if ls._is_hub(e) or not is_instance_valid(r):
			continue
		meshes += (r as Node).find_children("*", "MeshInstance3D", true, false).size()
		(r as Node3D).visible = false
	print("PROBE | 其他島共有 %d 個 MeshInstance3D" % meshes)
	await _measure("主島（其他島藏起來）")
	for e in worlds.size():
		var r = (worlds[e] as Dictionary).get("root")
		if is_instance_valid(r):
			(r as Node3D).visible = true
	for mi in old_begin:
		(mi as MeshInstance3D).visibility_range_begin = old_begin[mi]
	_key(KEY_M)
	await _wait(120)
	await _measure("世界地圖")
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			root.get_texture().get_image().save_png(a.substr(7))
	quit()

func _mat_sig(m: Material) -> String:
	if m == null:
		return "null"
	if m is ShaderMaterial:
		var sm := m as ShaderMaterial
		var parts := [str(sm.shader.get_instance_id())]
		for u in sm.shader.get_shader_uniform_list():
			parts.append(str(sm.get_shader_parameter(u.name)))
		return "|".join(parts)
	if m is BaseMaterial3D:
		var b := m as BaseMaterial3D
		var tex := ""
		if b.albedo_texture:
			tex = b.albedo_texture.resource_path if b.albedo_texture.resource_path != "" else str(b.albedo_texture.get_rid())
		return "%s|%s|%s|%d|%d|%s|%s|%s|%s|%s|%s" % [m.get_class(), tex, b.albedo_color, b.shading_mode, b.cull_mode, b.vertex_color_use_as_albedo,
			b.emission_enabled, b.emission, b.roughness, b.metallic, b.uv1_scale]
	return str(m.get_instance_id())
