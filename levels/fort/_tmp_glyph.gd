extends SceneTree
## 暫時的檢查：畫面文字裡有哪些字 jf 粉圓體沒有（會變成方框）
func _initialize() -> void:
	var font: Font = load("res://assets/fonts/jf-openhuninn-2.1.ttf")
	var files := []
	for d in ["res://levels/fort", "res://scripts/ui", "res://scripts", "res://scripts/battle", "res://scripts/items"]:
		var da := DirAccess.open(d)
		if da == null: continue
		for f in da.get_files():
			if f.ends_with(".gd"):
				files.append(d + "/" + f)
	var bad := {}
	var re := RegEx.new()
	re.compile("\"([^\"\\]|\\.)*\"")
	for path in files:
		var txt := FileAccess.get_file_as_string(path)
		var ln := 0
		for line in txt.split("\n"):
			ln += 1
			var code := line
			var hash := line.find("#")
			for m in re.search_all(line):
				var s: String = m.get_string()
				for i in s.length():
					var c := s.unicode_at(i)
					if c < 32 or c == 0xFF5C: continue
					if not font.has_char(c):
						var key := "%s U+%04X" % [char(c), c]
						if not bad.has(key): bad[key] = []
						if bad[key].size() < 4: bad[key].append("%s:%d" % [path.get_file(), ln])
	for k in bad:
		print(k, "  ", bad[k])
	print("檢查了 %d 個檔案" % files.size())
	quit()
