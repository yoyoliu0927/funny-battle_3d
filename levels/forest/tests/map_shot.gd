extends SceneTree
## 選關地圖截一張圖，順便檢查大關名稱的字型裡有沒有每個字。（要開視窗）
## Godot --path . --script res://levels/forest/tests/map_shot.gd -- <輸出資料夾>
const UISkin := preload("res://scripts/ui/ui_style.gd")
const Chapter := preload("res://levels/forest/chapter.gd")

func _initialize() -> void:
	_go.call_deferred()

func _go() -> void:
	var out := "user://forest_map"
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		out = a[0]
	DirAccess.make_dir_recursive_absolute(out)
	var f: Font = UISkin.font()
	var title: String = Chapter.TITLE
	var missing := ""
	for i in title.length():
		if f and not f.has_char(title.unicode_at(i)):
			missing += title[i]
	print("字型：", f.resource_path if f else "（預設）", "  缺字：", missing if missing != "" else "沒有")
	change_scene_to_file("res://scenes/level_select.tscn")
	for i in 60:
		await process_frame
	for k in 3:                                  # 開場動畫：按空白鍵跳過
		var ev := InputEventKey.new()
		ev.physical_keycode = KEY_SPACE
		ev.keycode = KEY_SPACE
		ev.pressed = true
		root.push_input(ev)
		var up := ev.duplicate()
		up.pressed = false
		root.push_input(up)
		for i in 40:
			await process_frame
	for i in 60:
		await process_frame
	var m := InputEventKey.new()                 # 打開世界地圖（每座島的名字都在上面）
	m.physical_keycode = KEY_M
	m.keycode = KEY_M
	m.pressed = true
	root.push_input(m)
	var mu := m.duplicate()
	mu.pressed = false
	root.push_input(mu)
	for i in 120:
		await process_frame
	root.get_texture().get_image().save_png(out.path_join("map.png"))
	print("map -> ", ProjectSettings.globalize_path(out))
	quit()
