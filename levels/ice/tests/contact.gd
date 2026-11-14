extends SceneTree
## 把多張截圖拼成一張總覽：Godot --headless --script contact.gd -- <輸出.png> <欄數> <每格寬> <圖1> <圖2> ...
func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var cols := int(a[1])
	var tw := int(a[2])
	var th := int(tw * 9.0 / 16.0)
	var files := a.slice(3)
	var rows := int(ceil(files.size() / float(cols)))
	var sheet := Image.create(cols * tw, rows * th, false, Image.FORMAT_RGB8)
	for i in files.size():
		var im := Image.load_from_file(files[i])
		if im == null:
			continue
		im.convert(Image.FORMAT_RGB8)
		im.resize(tw, th, Image.INTERPOLATE_LANCZOS)
		sheet.blit_rect(im, Rect2i(0, 0, tw, th), Vector2i((i % cols) * tw, (i / cols) * th))
	sheet.save_png(a[0])
	print("SHEET ", a[0])
	quit()
