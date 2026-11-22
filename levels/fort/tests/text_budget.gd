extends SceneTree
## 字量檢查：每個畫面「一直看得到的字」和「介面蓋住多少畫面」有沒有超過預算。
## 要開視窗（量覆蓋率要截圖；--headless 只能數字數）。
##   Godot --path . -s res://levels/fort/tests/text_budget.gd -- [場景.tscn ...] [--max-chars=40] [--max-ui=12] [--max-parts=5] [--wait=120] [--press=W,E] [--out=資料夾]
## 不給場景：量主島（農莊）和 fort 的每一小關。
##
## 量四件事：
##   1. 節點裡的字（Label、Button、RichTextLabel、Label3D）：算字數（中文一個字算 1、英文一個單字算 1，標點不算），
##      同一句話同時出現兩次以上也列出來（重複資訊）。透明度幾乎 0 的（已經淡出）不算。
##   2. 介面覆蓋率：有介面／把介面全部藏起來各截一張，比對像素，算介面佔畫面百分之幾，
##      再切成九宮格看擠在哪裡、列出每個介面元件各佔多少。用 draw_string 畫的字和圖示也量得到。
##   3. 搶注意力的介面塊數：把靠得近的介面像素併成一塊，數畫面上同時有幾塊（標題、計數、按鈕、提示列……）。
##      面積不大但塊數多，一樣很吵。
##   4. 用 draw_string 在程式裡畫字的腳本另外列出來：字數數不到，只能看覆蓋率、塊數和截圖。
## 每個畫面輸出 <名字>.png（原圖）和 <名字>_ui.png（介面的地方塗紅）。
## 全部在預算內印 TEXT_BUDGET: PASS，否則 TEXT_BUDGET: FAIL（結束碼 1）。

const Journal := preload("res://scripts/hub/journal.gd")
const HUB := "res://scenes/level_select.tscn"
const SMALL := Vector2i(480, 270)     # 比對像素用的縮圖大小（全解析度在 GDScript 裡太慢）
const DIFF := 26                      # 0~255：任一色版差超過這麼多就算「這裡有介面」
const MERGE := 4                      # 縮圖上相距幾格以內的介面像素算同一塊（一個按鈕的圖示和底下的字算一塊）
const MIN_BLOB := 0.08                # 佔畫面不到這麼多 % 的小點不算一塊

var max_chars := 40
var max_ui := 12.0
var max_parts := 5
var wait := 120
var out := "user://text_budget"
var scenes: Array[String] = []
var press: PackedStringArray = []     # 量之前先按這些鍵（像玩家已經玩過一下），例如 --press=W,E
var failed := false

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--max-chars="):
			max_chars = int(a.get_slice("=", 1))
		elif a.begins_with("--max-ui="):
			max_ui = float(a.get_slice("=", 1))
		elif a.begins_with("--max-parts="):
			max_parts = int(a.get_slice("=", 1))
		elif a.begins_with("--wait="):
			wait = int(a.get_slice("=", 1))
		elif a.begins_with("--press="):
			press = a.get_slice("=", 1).split(",", false)
		elif a.begins_with("--out="):
			out = a.get_slice("=", 1)
		elif a.ends_with(".tscn"):
			scenes.append(a)
	if scenes.is_empty():
		scenes.append(HUB)
		for n in 10:
			var p := "res://levels/fort/stage_%d/stage.tscn" % n
			if ResourceLoader.exists(p):
				scenes.append(p)
	Journal.persist = false            # 測試不寫玩家的手帳存檔
	DirAccess.make_dir_recursive_absolute(out)
	_go.call_deferred()

func _go() -> void:
	for path in scenes:
		Engine.set_meta("title_done", true)     # 跳過標題畫面
		paused = false
		change_scene_to_file(path)
		for i in wait:
			await process_frame
		for k in press:
			for down in [true, false]:
				var ev := InputEventKey.new()
				ev.keycode = OS.find_keycode_from_string(k)
				ev.pressed = down
				Input.parse_input_event(ev)
				for i in 6:
					await process_frame
		if not press.is_empty():
			for i in 90:
				await process_frame
		await _measure(path)
	print("")
	print("TEXT_BUDGET: %s" % ("FAIL" if failed else "PASS"))
	print("截圖在 %s" % ProjectSettings.globalize_path(out))
	quit(1 if failed else 0)

# ================================================================== 量一個畫面

func _measure(path: String) -> void:
	var nm := path.get_base_dir().get_file() if path.get_file() == "stage.tscn" else path.get_file().get_basename()
	if path.begins_with("res://levels/"):
		nm = path.get_slice("/", 3) + "_" + nm
	print("")
	print("== %s  (%s)" % [nm, path])

	# ---- 1. 節點裡的字
	var texts: Array = []
	var drawn := {}
	_walk(root, 1.0, texts, drawn)
	var chars := 0
	var seen := {}
	for t in texts:
		chars += int(t.n)
		var key := String(t.text).strip_edges().replace("\n", " ")
		seen[key] = int(seen.get(key, 0)) + 1
	texts.sort_custom(func(x, y): return int(x.n) > int(y.n))
	print("  節點裡的字：%d 字（預算 %d）%s" % [chars, max_chars, "  ← 超過" if chars > max_chars else ""])
	for t in texts.slice(0, 10):
		print("    %3d  「%s」  %s" % [t.n, _short(String(t.text)), t.where])
	var dups := seen.keys().filter(func(k): return int(seen[k]) > 1 and _count(k) > 0)
	if not dups.is_empty():
		print("  重複出現：")
		for k in dups:
			print("    ×%d 「%s」" % [seen[k], _short(k)])
	if not drawn.is_empty():
		print("  用 draw_string 畫字的腳本（字數數不到，看覆蓋率和截圖）：")
		for s in drawn:
			print("    %s" % s)
	if chars > max_chars:
		failed = true

	# ---- 2. 介面覆蓋率
	if DisplayServer.get_name() == "headless":
		print("  （headless 沒有畫面，覆蓋率沒量）")
		return
	paused = true                        # 定住雞、螢火蟲這些會動的東西，比對才準
	var full := await _shot_full()
	full.save_png(out.path_join(nm + ".png"))
	var a := _small(full)
	var a2 := _small(await _shot_full())
	var noise := _grow(_mask(a, a2))     # 兩張都有介面還是會變的地方（水面、天空動畫）不算
	var roots := _ui_roots()
	for n in roots:
		n.visible = false
	var b := _small(await _shot_full())
	for n in roots:
		n.visible = true
	var ui := _sub(_mask(a, b), noise)
	var pct := _pct(ui)
	print("  介面覆蓋率：%.1f%%（預算 %.0f%%）%s" % [pct, max_ui, "  ← 超過" if pct > max_ui else ""])
	print("  九宮格（每格佔整個畫面的 %）：")
	var g := _grid(ui)
	for r in 3:
		print("    %5.1f  %5.1f  %5.1f" % [g[r * 3], g[r * 3 + 1], g[r * 3 + 2]])
	var blobs := _blobs(ui)
	print("  搶注意力的介面塊數：%d 塊（預算 %d）%s" % [blobs.size(), max_parts, "  ← 超過" if blobs.size() > max_parts else ""])
	var where: Array = []
	for bl in blobs:
		where.append("%s %.1f%%" % [_zone(bl.c), bl.p])
	print("    " + "、".join(where))
	_overlay(a, ui).save_png(out.path_join(nm + "_ui.png"))
	if pct > max_ui or blobs.size() > max_parts:
		failed = true

	# ---- 每個介面元件各佔多少
	var parts: Array = []
	for el in _ui_parts(roots):
		el.visible = false
		var c := _small(await _shot_full())
		el.visible = true
		var p := _pct(_sub(_mask(a, c), noise))
		if p >= 0.2:
			parts.append({"p": p, "name": _label(el)})
	parts.sort_custom(func(x, y): return float(x.p) > float(y.p))
	if not parts.is_empty():
		print("  佔最多的介面元件：")
		for e in parts.slice(0, 8):
			print("    %5.1f%%  %s" % [e.p, e.name])
	paused = false

# ================================================================== 找字

func _walk(n: Node, alpha: float, texts: Array, drawn: Dictionary) -> void:
	if n is CanvasLayer and not (n as CanvasLayer).visible:
		return
	if n is CanvasItem:
		var ci := n as CanvasItem
		if not ci.visible:
			return
		alpha *= ci.modulate.a
		if alpha < 0.05:
			return
	if n is Node3D and not (n as Node3D).visible:
		return
	var s := ""
	var a := alpha
	if n is Label:
		s = (n as Label).text
		a *= (n as Label).self_modulate.a
	elif n is Button:
		s = (n as Button).text
	elif n is RichTextLabel:
		s = (n as RichTextLabel).get_parsed_text()
	elif n is Label3D:
		var l3 := n as Label3D
		var cam := l3.get_viewport().get_camera_3d()
		if cam == null or cam.is_position_in_frustum(l3.global_position):
			s = l3.text
			a = l3.modulate.a
	if s.strip_edges() != "" and a >= 0.05:
		var k := _count(s)
		if k > 0:
			texts.append({"text": s, "n": k, "where": _where(n)})
	if n is CanvasItem:
		# 自己的腳本有 draw_string，或是別的腳本幫它畫：draw.connect(...)，或塞一個 Callable 屬性（像主島的 _Pad.painter）
		var srcs: Array = [n.get_script()]
		var cbs: Array = []
		for con in n.get_signal_connection_list("draw"):
			cbs.append(con.callable)
		for prop in n.get_property_list():
			if int(prop.type) == TYPE_CALLABLE:
				cbs.append(n.get(prop.name))
		for cb in cbs:
			var obj: Object = (cb as Callable).get_object()
			if obj:
				srcs.append(obj.get_script())
		for sc in srcs:
			if sc is Script and (sc as Script).resource_path != "" and not drawn.has((sc as Script).resource_path):
				if (sc as Script).source_code.contains("draw_string"):
					drawn[(sc as Script).resource_path] = true
	for c in n.get_children():
		_walk(c, alpha, texts, drawn)

## 算字數：中日文一個字算 1，英文／數字一串算 1，標點和符號不算
func _count(s: String) -> int:
	var n := 0
	var in_word := false
	for i in s.length():
		var u := s.unicode_at(i)
		if (u >= 0x3400 and u <= 0x9FFF) or (u >= 0xF900 and u <= 0xFAFF) or (u >= 0x3040 and u <= 0x30FF):
			n += 1
			in_word = false
		elif (u >= 48 and u <= 57) or (u >= 65 and u <= 90) or (u >= 97 and u <= 122):
			if not in_word:
				n += 1
			in_word = true
		else:
			in_word = false
	return n

func _short(s: String) -> String:
	s = s.strip_edges().replace("\n", " ")
	return s if s.length() <= 28 else s.substr(0, 27) + "…"

func _where(n: Node) -> String:
	var sc := n.get_script() as Script
	var p := n.get_parent()
	var host := ""
	while p and host == "":
		var ps := p.get_script() as Script
		if ps and ps.resource_path != "":
			host = ps.resource_path.get_file()
		p = p.get_parent()
	if sc and sc.resource_path != "":
		host = sc.resource_path.get_file()
	return "[%s · %s]" % [n.name, host]

func _label(n: Node) -> String:
	var sc := n.get_script() as Script
	var cls := sc.resource_path.get_file() if sc and sc.resource_path != "" else n.get_class()
	return "%s（%s）" % [n.name, cls]

# ================================================================== 介面節點

## 介面最上層：看得到的 CanvasLayer，以及直接掛在 3D 節點底下的 Control
func _ui_roots() -> Array:
	var outl: Array = []
	_find_roots(root, outl)
	return outl

func _find_roots(n: Node, outl: Array) -> void:
	for c in n.get_children():
		if c is CanvasLayer:
			if (c as CanvasLayer).visible:
				outl.append(c)
		elif c is CanvasItem:
			if (c as CanvasItem).visible and not (n is CanvasItem):
				outl.append(c)
		else:
			_find_roots(c, outl)

## 拆成一個一個元件：CanvasLayer 底下每個看得到的子節點
func _ui_parts(roots: Array) -> Array:
	var outp: Array = []
	for r in roots:
		if r is CanvasLayer:
			for c in r.get_children():
				if c is CanvasItem and (c as CanvasItem).visible:
					outp.append(c)
		else:
			outp.append(r)
	return outp

# ================================================================== 截圖和比對

func _shot_full() -> Image:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()

func _small(img: Image) -> Image:
	var s := img.duplicate() as Image
	s.convert(Image.FORMAT_RGB8)
	s.resize(SMALL.x, SMALL.y, Image.INTERPOLATE_BILINEAR)
	return s

func _mask(a: Image, b: Image) -> PackedByteArray:
	var da := a.get_data()
	var db := b.get_data()
	var m := PackedByteArray()
	m.resize(SMALL.x * SMALL.y)
	for i in m.size():
		var j := i * 3
		if absi(da[j] - db[j]) > DIFF or absi(da[j + 1] - db[j + 1]) > DIFF or absi(da[j + 2] - db[j + 2]) > DIFF:
			m[i] = 1
	return m

## 往外擴一格（動畫的邊緣也當成雜訊）
func _grow(m: PackedByteArray) -> PackedByteArray:
	var o := m.duplicate()
	for y in SMALL.y:
		for x in SMALL.x:
			if m[y * SMALL.x + x] == 1:
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var q: Vector2i = Vector2i(x, y) + d
					if q.x >= 0 and q.y >= 0 and q.x < SMALL.x and q.y < SMALL.y:
						o[q.y * SMALL.x + q.x] = 1
	return o

func _sub(m: PackedByteArray, noise: PackedByteArray) -> PackedByteArray:
	var o := m.duplicate()
	for i in o.size():
		if noise[i] == 1:
			o[i] = 0
	return o

func _pct(m: PackedByteArray) -> float:
	var k := 0
	for v in m:
		k += v
	return 100.0 * k / m.size()

func _grid(m: PackedByteArray) -> Array:
	var g := [0, 0, 0, 0, 0, 0, 0, 0, 0]
	for y in SMALL.y:
		for x in SMALL.x:
			if m[y * SMALL.x + x] == 1:
				g[mini(y * 3 / SMALL.y, 2) * 3 + mini(x * 3 / SMALL.x, 2)] += 1
	return g.map(func(v): return 100.0 * v / m.size())

## 把靠得近的介面像素併成一塊（相距 MERGE 格以內算同一塊），太小的不算。回傳 [{p: 佔畫面 %, c: 中心點 0~1}]
func _blobs(m: PackedByteArray) -> Array:
	var w := SMALL.x
	var h := SMALL.y
	var grown := m.duplicate()
	for i in MERGE:
		grown = _grow(grown)
	var seen := PackedByteArray()
	seen.resize(w * h)
	var found: Array = []
	for start in w * h:
		if grown[start] == 0 or seen[start] == 1:
			continue
		var stack := [start]
		seen[start] = 1
		var real := 0
		var sum := Vector2.ZERO
		while not stack.is_empty():
			var i: int = stack.pop_back()
			if m[i] == 1:
				real += 1
				sum += Vector2(i % w, i / w)
			for j in [i - 1, i + 1, i - w, i + w]:
				if j < 0 or j >= w * h or seen[j] == 1 or grown[j] == 0:
					continue
				if (j == i - 1 or j == i + 1) and j / w != i / w:
					continue
				seen[j] = 1
				stack.append(j)
		var p := 100.0 * real / (w * h)
		if p >= MIN_BLOB:
			found.append({"p": p, "c": sum / real / Vector2(w, h)})
	found.sort_custom(func(x, y): return float(x.p) > float(y.p))
	return found

func _zone(c: Vector2) -> String:
	var row: String = ["上", "中", "下"][mini(int(c.y * 3), 2)]
	var col: String = ["左", "中", "右"][mini(int(c.x * 3), 2)]
	return "正中" if row == "中" and col == "中" else row + col

func _overlay(a: Image, m: PackedByteArray) -> Image:
	var o := a.duplicate() as Image
	for y in SMALL.y:
		for x in SMALL.x:
			if m[y * SMALL.x + x] == 1:
				o.set_pixel(x, y, o.get_pixel(x, y).lerp(Color(1, 0, 0), 0.6))
			else:
				o.set_pixel(x, y, o.get_pixel(x, y).darkened(0.45))
	return o
