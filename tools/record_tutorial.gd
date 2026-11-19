extends SceneTree
## 錄教學彈窗的示範動畫（按 H 打開的那個；格式見 scripts/ui/tutorial_popup.gd）：
##   Godot --path . -s res://tools/record_tutorial.gd -- --chapter=forest
##   （劉起佑大關的樹很高：加 --cam_h=18）
## 不能加 --headless（要真的畫出畫面）。會依序打開這個大關的每一小關，每一種道具第一次出現時錄一段，
## 另外在第一小關錄一段「什麼都不放，家豪自己去打人」（hero）。
## 共用道具（scripts/items/ 裡的飼料、香蕉皮、巨石）和「家豪自己行動」存到共用的 res://assets/tutorial/，
## 已經有了就跳過（全遊戲只放一份；加 --force 重錄）；大關自己的道具存到 res://levels/<大關>/assets/tutorial/<道具 id>.jpg（一張影格表：每格 480×270、一列 6 格、每秒 10 格）。
## 錄好之後 battle_base.gd 的教學頁面會自動找這些檔案；沒有的就照舊顯示道具圖示。
##
## 道具放哪裡是自動挑的（家豪和最近的敵人之間），挑不好的話可以在大關資料夾自己錄、或改這裡的 _spot()。

const Registry := preload("res://scripts/registry.gd")
const TutorialPopup := preload("res://scripts/ui/tutorial_popup.gd")
const FRAMES := 40              # 4 秒
const CAST_AT := 6              # 第幾格施放
const START_AT := 9             # 第幾格開打

var chapter := ""
var only := ""                  # --only=<道具 id>：只重錄這一種
var force := false              # --force：共用的動畫已經有了也重錄
const SHARED := "res://assets/tutorial"
var cam_h := 8.0                # --cam_h=<公尺>：鏡頭至少比畫面中心高多少（樹很高的大關要調高，免得卡在樹冠裡）

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--chapter="):
			chapter = a.substr(10)
		elif a.begins_with("--only="):
			only = a.substr(7)
		elif a == "--force":
			force = true
		elif a.begins_with("--cam_h="):
			cam_h = float(a.substr(8))
	root.size = Vector2i(1600, 900)
	_run.call_deferred()

func _run() -> void:
	var ch := {}
	for c in Registry.chapters():
		if c.id == chapter:
			ch = c
	if ch.is_empty():
		print("[REC] 找不到大關：", chapter)
		quit(1)
		return
	var out: String = String(ch.dir).path_join("assets/tutorial")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	var done := {}
	for st in ch.stages:
		Engine.set_meta("stage_id", st.id)
		var sc: Node = load(st.scene).instantiate()
		root.add_child(sc)
		current_scene = sc
		await _wait(0.6)
		var bt := sc.get_node_or_null("Battle")
		if bt == null or not bt.get("items") is Array:
			print("[REC] %s 不是共用戰局，跳過" % st.id)
			sc.queue_free()
			await _wait(0.2)
			continue
		_prepare(sc, bt)
		if int(st.n) == 1 and (only == "" or only == "hero") and not done.has("hero") 				and (force or not FileAccess.file_exists(SHARED.path_join("hero.jpg"))):
			await _record_hero(sc, bt, SHARED.path_join("hero.jpg"))
			done["hero"] = true
		for i in bt.items.size():
			var id: String = bt.items[i].id
			if done.has(id) or (only != "" and only != id):
				continue
			var shared_item := String((bt.items[i].get_script() as Script).resource_path).begins_with("res://scripts/items/")
			var dest := SHARED.path_join(id + ".jpg") if shared_item else out.path_join(id + ".jpg")
			if shared_item and not force and FileAccess.file_exists(dest):
				continue
			if await _record_item(sc, bt, i, dest):
				done[id] = true
		sc.queue_free()
		current_scene = null
		await _wait(0.3)
	print("[REC] 完成：", done.keys())
	quit()

func _wait(sec: float) -> void:
	await create_timer(sec, true).timeout

## 錄影時把介面都收起來、不要教學和冷卻
func _prepare(sc: Node, bt: Node) -> void:
	if bt.has_method("_end_intro"):
		bt._end_intro()       # 關卡自己的開場預覽會借走鏡頭，先結束
	if bt.get("help_popup") and bt.help_popup.is_open():
		bt.help_popup.close()
	if bt.has_method("_set_tut_step"):
		bt._set_tut_step(-1)
	bt.no_cooldown = true
	bt.no_limit = true
	for n in [bt.get("_hud_layer"), sc.get_node_or_null("HUD")]:
		if n and "visible" in n:
			n.visible = false
	for c in bt.get_children():
		if c is CanvasLayer:
			c.visible = false
	var hands = bt.get("hands")   # 劉起佑大關的「神的手」（第一人稱）錄影時不要入鏡
	if hands is Node3D:
		(hands as Node3D).process_mode = Node.PROCESS_MODE_DISABLED   # 關卡每一幀都會叫它顯示，直接停掉
		(hands as Node3D).visible = false

## 鏡頭擺在 from 看著 at（直接擺幽靈的身體和頭）
func _look(sc: Node, from: Vector3, at: Vector3) -> void:
	var p := sc.get_node("Player") as Node3D
	p.set_physics_process(false)
	p.global_position = from - Vector3(0, 1.65, 0)
	var d := at - from
	p.rotation = Vector3(0, atan2(-d.x, -d.z), 0)
	(sc.get_node("Player/Head") as Node3D).rotation.x = atan2(d.y, Vector2(d.x, d.z).length())

var _cam_eye := Vector3.ZERO
var _cam_at := Vector3.ZERO
var _cam_snap := true
var _frame_r := 0.0             # 取景至少要裝下的半徑（道具的作用範圍）

## 框住幾個點：從南邊斜上方看它們的中心，距離剛好裝得下（小格子裡角色才看得清楚）
func _frame(sc: Node, bt: Node, pts: Array) -> void:
	var c := Vector3.ZERO
	for p in pts:
		c += p
	c /= pts.size()
	var r := 2.0
	for p in pts:
		r = maxf(r, Vector2(p.x - c.x, p.z - c.z).length())
	r = maxf(r, _frame_r)
	# 比較陡的俯角、比樹冠高（森林的樹很密，鏡頭太低會卡在樹冠裡）
	var dist := r * 1.25 + 4.0
	var eye := c + Vector3(0.0, dist * 0.85, dist * 0.6)
	var gy: float = bt.world.height_at(eye.x, eye.z)
	eye.y = maxf(eye.y, maxf(gy + 3.0, c.y + cam_h))
	var at := c + Vector3(0, 0.4, 0)
	if _cam_snap:
		_cam_eye = eye
		_cam_at = at
		_cam_snap = false
	else:
		# 跟拍：慢慢跟上，不要一跳一跳
		_cam_eye = _cam_eye.lerp(eye, 0.25)
		_cam_at = _cam_at.lerp(at, 0.25)
	_look(sc, _cam_eye, _cam_at)

## 錄影時每一格要框住的點：家豪、道具的位置、最近的敵人
func _track_points(bt: Node, spot: Variant) -> Array:
	var pts: Array = [bt.bird.pos]
	if spot != null:
		pts.append(spot)
	var e_f = _nearest_enemy(bt)
	if e_f:
		pts.append(e_f.pos)
	return pts

func _nearest_enemy(bt: Node) -> Object:
	var best: Object = null
	var bd := INF
	for f in bt.enemies:
		if f.alive() and not f.data.get("hidden", false):
			var d: float = bt.flat_dist(f.pos, bt.bird.pos)
			if d < bd:
				bd = d
				best = f
	return best

## 這個道具放哪裡：依名字猜用途（飼料放家豪附近、香蕉皮放敵人前面），放不了就在附近找
func _spot(bt: Node, i: int) -> Variant:
	var it = bt.items[i]
	var h: Vector3 = bt.bird.pos
	var e_f = _nearest_enemy(bt)
	var e: Vector3 = e_f.pos if e_f else h + Vector3(0, 0, -6)
	var k := 0.5
	var id := String(it.id)
	if id.contains("feed") or id.contains("decoy") or id.contains("guide"):
		k = 0.3
	elif id.contains("banana") or id.contains("salt") or id.contains("slip"):
		k = 0.7
	var side := (e - h).cross(Vector3.UP).normalized()
	var base := h.lerp(e, k)
	for ring in 12:
		for a in 8:
			var ang := TAU * a / 8.0
			var off := Vector3(cos(ang), 0, sin(ang)) * ring * 0.8 + side * (1.2 if id.contains("feed") else 0.0)
			var p: Vector3 = base + off
			p.y = bt.world.height_at(p.x, p.z)
			if bt.placement_error(i, p) == "":
				return p
	return null

func _record_item(sc: Node, bt: Node, i: int, path: String) -> bool:
	bt.reset()
	_prepare(sc, bt)
	bt.select_skill(i)
	var p = _spot(bt, i)
	if p == null:
		print("[REC] %s：找不到可以放的位置，跳過" % bt.items[i].id)
		return false
	_cam_snap = true
	_frame_r = float(bt.items[i].radius) * 1.1
	_frame(sc, bt, _track_points(bt, p))
	var prep_ok: bool = bt.items[i].charges_for(false) != 0
	var ev := {START_AT: func(): bt.start()}
	if prep_ok:
		ev[CAST_AT] = func(): bt.cast(i, p)
	else:
		ev[START_AT + 2] = func(): bt.cast(i, p)   # 只能開打後用的道具
	await _record(path, ev, func(): _frame(sc, bt, _track_points(bt, p)))
	return true

func _record_hero(sc: Node, bt: Node, path: String) -> void:
	bt.reset()
	_prepare(sc, bt)
	_cam_snap = true
	_frame_r = 0.0
	_frame(sc, bt, _track_points(bt, null))
	await _record(path, {3: func(): bt.start()}, func(): _frame(sc, bt, _track_points(bt, null)))

## 錄 FRAMES 格（每秒 10 格），events = {第幾格: 要做的事}
func _record(path: String, events: Dictionary, track: Callable = Callable()) -> void:
	var imgs: Array[Image] = []
	var acc := 1.0
	var step := 1.0 / TutorialPopup.FPS
	var last := Time.get_ticks_msec()
	while imgs.size() < FRAMES:
		await RenderingServer.frame_post_draw
		var now := Time.get_ticks_msec()
		acc += (now - last) / 1000.0
		last = now
		if acc < step:
			continue
		acc = 0.0 if imgs.is_empty() else acc - step
		var n := imgs.size()
		if track.is_valid():
			track.call()
		if events.has(n):
			events[n].call()
			await RenderingServer.frame_post_draw
		var im := root.get_texture().get_image()
		im.convert(Image.FORMAT_RGB8)
		im.resize(TutorialPopup.FW, TutorialPopup.FH, Image.INTERPOLATE_LANCZOS)
		imgs.append(im)
	var cols := TutorialPopup.COLS
	var rows := ceili(float(FRAMES) / cols)
	var sheet := Image.create(TutorialPopup.FW * cols, TutorialPopup.FH * rows, false, Image.FORMAT_RGB8)
	for k in imgs.size():
		sheet.blit_rect(imgs[k], Rect2i(0, 0, TutorialPopup.FW, TutorialPopup.FH), Vector2i((k % cols) * TutorialPopup.FW, (k / cols) * TutorialPopup.FH))
	sheet.save_jpg(ProjectSettings.globalize_path(path), 0.8)
	print("[REC] ", path)
