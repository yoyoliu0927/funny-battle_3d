extends SceneTree
## 效能量測：選關地圖（農莊、世界地圖）和每個小關的繪製次數、三角形數、一畫面多少毫秒。（要開視窗）
## Godot --path . -s res://levels/fort/tests/perf_probe.gd -- [--only=fort] [--frames=180]
## 會關掉垂直同步、不鎖 FPS，量到的是桌面版的極限；網頁版大約慢 2～3 倍。
const Registry := preload("res://scripts/registry.gd")

var _frames := 180
var _only := ""

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--frames="):
			_frames = int(a.substr(9))
		elif a.begins_with("--only="):
			_only = a.substr(7)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_go.call_deferred()

func _key(k: Key) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = k
	ev.keycode = k
	ev.pressed = true
	root.push_input(ev)
	var up := ev.duplicate()
	up.pressed = false
	root.push_input(up)

func _wait(n: int) -> void:
	for i in n:
		await process_frame

## 量 _frames 畫面：平均毫秒、最慢 5% 的毫秒、繪製次數、物件數、三角形數
func _measure(label: String) -> void:
	await _wait(30)
	var rs := RenderingServer
	var dts: Array = []
	var t := Time.get_ticks_usec()
	for i in _frames:
		await process_frame
		var now := Time.get_ticks_usec()
		dts.append((now - t) / 1000.0)
		t = now
	dts.sort()
	var avg := 0.0
	for d in dts:
		avg += d
	avg /= dts.size()
	var p95: float = dts[int(dts.size() * 0.95)]
	var dc := rs.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	var ob := rs.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)
	var pr := rs.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
	print("PERF | %-28s | %6.2f ms (%5.0f fps) | p95 %6.2f ms | draw %5d | obj %5d | tri %8d" % [label, avg, 1000.0 / avg, p95, dc, ob, pr])

func _go() -> void:
	var size := Vector2i(1280, 720)
	DisplayServer.window_set_size(size)
	if _only == "" or _only == "hub":
		change_scene_to_file("res://scenes/level_select.tscn")
		await _wait(60)
		for k in 3:
			_key(KEY_SPACE)
			await _wait(40)
		await _measure("農莊")
		_key(KEY_M)
		await _wait(120)
		await _measure("世界地圖")
	for s in Registry.all_stages():
		var id: String = s.id
		if id.begins_with("example_") or id.begins_with("_"):
			continue
		if _only != "" and not id.begins_with(_only + "/"):
			continue
		change_scene_to_file(s.scene)
		await _wait(90)
		await _measure(id + " " + String(s.title))
	print("PERF | done")
	quit()
