extends SceneTree
## 每個大關第一小關的「教學彈窗」（第一次進來自動打開、按 H 打開的那張）：每一頁截一張圖，檢查教學的樣子。
##   Godot --path . -s res://levels/fort/tests/help_shots.gd -- [輸出資料夾] [場景.tscn ...]
## 不給場景：範本、要塞、森林、冰雪、劉起佑島的第 1 小關。

var out := "user://help_shots"
var scenes: Array[String] = []

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.ends_with(".tscn"):
			scenes.append(a)
		else:
			out = a
	if scenes.is_empty():
		for ch in ["_template", "fort", "forest", "ice", "liuchiyu"]:
			scenes.append("res://levels/%s/stage_1/stage.tscn" % ch)
	DirAccess.make_dir_recursive_absolute(out)
	_go.call_deferred()

func _shot(name: String) -> void:
	for i in 40:                 # 等彈窗淡入、示範動畫跑起來
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))

func _go() -> void:
	for path in scenes:
		var ch := path.get_slice("/", 3)
		change_scene_to_file(path)
		for i in 240:
			await process_frame
		var bt: Node = current_scene.get_node_or_null("Battle")
		var pop = bt.get("help_popup") if bt else null
		if pop == null and bt:
			pop = bt.get("_tut")          # 要塞的戰局腳本把教學彈窗叫做 _tut
		if pop == null:
			print("%s：找不到教學彈窗（help_popup）" % ch)
			continue
		pop.open(0)
		var n: int = (pop.pages as Array).size()
		print("%s：教學 %d 頁" % [ch, n])
		for p in mini(n, 6):
			if p > 0:
				pop.open(p)
			await _shot("%s_p%d" % [ch, p + 1])
		if pop.has_method("close"):
			pop.close()
	quit()
