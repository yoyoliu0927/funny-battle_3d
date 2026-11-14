extends SceneTree
## 臉部貼合檢查（有視窗、讓遊戲照平常的方式每格自己跑，不是手動推進）。
## Godot --path <專案> --script res://levels/ice/tests/face_watch.gd -- <stage> <輸出資料夾> "<走法>" [結束後多跑幾秒]
##   走法和 play.gd 一樣（prep:道具,x,z；at:秒,道具,x,z）。
## 做兩件事：
##  1. 量：每個角色兩台「鎖在頭骨上」的鏡頭（正面、側 45 度），只拍那個人的頭和表情。
##     鏡頭跟著頭骨走，所以只要表情真的黏在臉上，每一格畫出來的眼睛位置（相對於頭的輪廓）都一樣；
##     沒跟著頭動、晚一格、被另外轉過，位置都會跑掉。超過 TOL 像素就印 FAIL。
##  2. 拍：每個角色（含家豪）狀態一變，就繞著他拍一圈（每 30 度一格，一圈和頭同高、一圈俯角 30 度），
##     只拍那個角色自己（看得清楚眼睛在不在臉的正面）。每個狀態拍兩次（剛變的第 2 格和第 8 格）。
const N := 160                   # 量測鏡頭的邊長（像素）
const M := 128                   # 繞一圈每一格的邊長
const TOL := 1.5                 # 眼睛位置容許跑掉幾個像素
const MAX_T := 7

class Late extends Node:
	var cb: Callable
	func _process(_dt: float) -> void:
		cb.call()

var bt
var world
var out := ""
var strat := ""
var extra := 6.0
var targets: Array = []
var holder: Node
var frame := 0
var stats := {}                  # "誰|表情|鏡頭" → {n, min, max}
var fired := {}
var rows := {}                   # 誰 → [[Image, 說明]…]
var last_tag := {}
var since := {}
var seen := {}

func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	out = a[1]
	strat = a[2] if a.size() > 2 else ""
	extra = float(a[3]) if a.size() > 3 else 6.0
	DirAccess.make_dir_recursive_absolute(out)
	change_scene_to_file(String(a[0]) if String(a[0]).begins_with("res://") else "res://levels/ice/stage_%s/stage.tscn" % a[0])
	_go.call_deferred()

func g(x: float, z: float) -> Vector3:
	return Vector3(x, world.height_at(x, z), z)

func _mute() -> void:
	# 不吃真的滑鼠鍵盤（使用者正在用電腦），但戰局照平常每格自己跑
	if current_scene and current_scene.has_node("Battle"):
		current_scene.get_node("Battle").set_process_unhandled_input(false)
		current_scene.get_node("Battle").set_process_input(false)
		current_scene.get_node("Player").set_process_unhandled_input(false)
		current_scene.get_node("Player").set_physics_process(false)

func _go() -> void:
	for i in 10:
		await process_frame
		_mute()
	bt = current_scene.get_node("Battle")
	if not bt.casts.is_empty():
		bt.reset()
	world = bt.world
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if bt.has_method("_set_tut_step"):
		bt._set_tut_step(-1)
	holder = Node.new()
	root.add_child(holder)
	# 擺鏡頭要排在這一格所有東西（動畫、擺姿勢、轉頭）都跑完之後
	var late := Late.new()
	late.process_priority = 100000
	late.cb = _place
	root.add_child(late)
	for p in strat.split(";"):
		if p.begins_with("prep:"):
			var v := p.substr(5).split(",")
			bt.cooldowns[int(v[0])] = 0.0
			bt.cast(int(v[0]), g(float(v[1]), float(v[2])))
	# 準備階段（站著、頭轉向玩家的鏡頭）
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 1500:
		await _one()
	bt.start()
	var t_end := -1.0
	t0 = Time.get_ticks_msec()
	while true:
		for p in strat.split(";"):
			if p.begins_with("at:") and not fired.has(p):
				var v := p.substr(3).split(",")
				if bt.time >= float(v[0]):
					fired[p] = true
					bt.cast(int(v[1]), g(float(v[2]), float(v[3])))
		await _one()
		if bt.phase == bt.Phase.ENDED and t_end < 0.0:
			t_end = Time.get_ticks_msec()
		if t_end >= 0.0 and Time.get_ticks_msec() - t_end > extra * 1000.0:
			break
		if Time.get_ticks_msec() - t0 > 90000:
			break
	_finish()

func _vp(sz: int, mask: int) -> Dictionary:
	var vp := SubViewport.new()
	vp.size = Vector2i(sz, sz)
	vp.world_3d = root.world_3d
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.transparent_bg = true
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.cull_mask = mask
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0, 0, 0, 0)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(1, 1, 1)
	cam.environment = e
	cam.near = 0.05
	cam.far = 200.0
	vp.add_child(cam)
	holder.add_child(vp)
	cam.current = true
	return {"vp": vp, "cam": cam}

func _add(who: String, f, sk, head: Node3D, face, body: Node) -> void:
	var i := targets.size()
	if i >= MAX_T:
		return
	var lock_bit := 1 << (5 + 2 * i)
	var body_bit := 1 << (6 + 2 * i)
	for m in body.find_children("*", "MeshInstance3D", true, false):
		m.layers |= body_bit
	var t := {"who": who, "f": f, "sk": sk, "head": head, "face": face, "body": body, "lock": [], "orbit": []}
	if sk != null:
		t.hb = (sk as Skeleton3D).find_bone("head")
		face.layers |= lock_bit
		for m in (sk as Skeleton3D).find_children("head*", "MeshInstance3D", false, false):
			m.layers |= lock_bit
		t.lock = [_vp(N, lock_bit), _vp(N, lock_bit)]
	for k in 24:
		t.orbit.append(_vp(M, body_bit))
	targets.append(t)
	rows[who] = []

func _scan() -> void:
	if targets.is_empty() and bt.bird != null and bt.get("_bird_head") != null:
		_add("家豪", bt.bird, null, bt._bird_head, null, bt.bird.node)
	for n in root.find_children("FaceDecal", "MeshInstance3D", true, false):
		if targets.any(func(t): return t.face == n):
			continue
		var sk := n.get_parent() as Skeleton3D
		var who := ""
		var fighter = null
		for f in bt._rigs:
			if bt._rigs[f].skel == sk:
				who = f.name
				fighter = f
		if who == "":
			if not n.is_visible_in_tree():
				continue
			who = "外加%d" % targets.size()
		_add(who, fighter, sk, null, n, sk.get_parent())

func _head_xf(t: Dictionary) -> Transform3D:
	if t.sk != null:
		return (t.sk as Skeleton3D).global_transform * (t.sk as Skeleton3D).get_bone_global_pose(t.hb)
	return (t.head as Node3D).global_transform

func _place() -> void:
	for t in targets:
		if not is_instance_valid(t.body):
			continue
		var H := _head_xf(t)
		var s: float = H.basis.get_scale().x
		var B: Basis = H.basis.orthonormalized()
		if t.sk != null:
			var fc: Vector3 = H * Vector3(0, 0.1, 0.16)
			for k in 2:
				var cam: Camera3D = t.lock[k].cam
				var cb := B * Basis(Vector3.UP, 0.0 if k == 0 else 0.785)
				cam.size = 0.56 * s
				cam.global_transform = Transform3D(cb, fc + cb.z * 3.0 * s)
		# 繞一圈：以身體的正面為 0 度，繞世界的垂直軸；第二圈俯角 30 度
		var body: Basis = (t.body as Node3D).global_basis.orthonormalized()
		var fwd := Vector3(body.z.x, 0, body.z.z)
		fwd = fwd.normalized() if fwd.length() > 0.01 else Vector3.BACK
		var unit: float = s if t.sk != null else s / 1.35 * 0.55
		var hc: Vector3 = H * (Vector3(0, 0.19, 0.0) if t.sk != null else Vector3(0, 0.02, 0.0))
		for k in 24:
			var cam2: Camera3D = t.orbit[k].cam
			var d := fwd.rotated(Vector3.UP, deg_to_rad(30.0 * (k % 12)))
			if k >= 12:
				d = (d * cos(deg_to_rad(30.0)) + Vector3.UP * sin(deg_to_rad(30.0))).normalized()
			cam2.size = (0.62 if t.sk != null else 1.05) * unit
			cam2.global_position = hc + d * 6.0 * unit
			cam2.look_at(hc, Vector3.UP)

func _tag(t: Dictionary) -> String:
	var f = t.f
	var kind := "-"
	if f != null and bt._rigs.has(f):
		kind = String(bt._rigs[f].get("face_kind", "")) if (t.face as Node3D).visible else ""
	return "%s|%s" % [f.state if f != null else "-", kind]

func _measure(t: Dictionary, k: int, tag: String) -> void:
	var img: Image = t.lock[k].vp.get_texture().get_image()
	var hx := 0.0; var hy := 0.0; var hn := 0
	var ex := 0.0; var ey := 0.0; var en := 0
	for y in N:
		for x in N:
			var c := img.get_pixel(x, y)
			if c.a < 0.5:
				continue
			hx += x; hy += y; hn += 1
			# 表情的像素：墨線（很暗）和眼白、牙齒（很白）；膚色、頭髮都不是
			if c.get_luminance() < 0.1 or minf(c.r, minf(c.g, c.b)) > 0.82:
				ex += x; ey += y; en += 1
	if hn < 200 or en < 12:
		return
	var v := Vector3(ex / en - hx / hn, ey / en - hy / hn, float(en))
	var key := "%s|%s|%s" % [t.who, tag.get_slice("|", 1), "正面" if k == 0 else "側45"]
	if not stats.has(key):
		stats[key] = {"n": 0, "min": v, "max": v}
	var st: Dictionary = stats[key]
	st.n += 1
	st.min = Vector3(minf(st.min.x, v.x), minf(st.min.y, v.y), minf(st.min.z, v.z))
	st.max = Vector3(maxf(st.max.x, v.x), maxf(st.max.y, v.y), maxf(st.max.z, v.z))

func _orbit_row(t: Dictionary) -> Image:
	var row := Image.create(M * 12, M * 2, false, Image.FORMAT_RGBA8)
	row.fill(Color(0.42, 0.5, 0.58))
	for k in 24:
		var im: Image = t.orbit[k].vp.get_texture().get_image()
		im.convert(Image.FORMAT_RGBA8)
		row.blend_rect(im, Rect2i(0, 0, M, M), Vector2i((k % 12) * M, (k / 12) * M))
	return row

func _one() -> void:
	frame += 1
	if frame % 10 == 1:
		_scan()
	await RenderingServer.frame_post_draw
	for t in targets:
		if not is_instance_valid(t.body) or not (t.body as Node3D).is_visible_in_tree():
			continue
		var tag := _tag(t)
		if t.sk != null and tag.get_slice("|", 1) != "":
			for k in 2:
				_measure(t, k, tag)
		if last_tag.get(t.who, "") != tag:
			last_tag[t.who] = tag
			since[t.who] = 0
		since[t.who] = int(since.get(t.who, 0)) + 1
		var sn: int = since[t.who]
		var key := "%s|%s|%d" % [t.who, tag, sn]
		if (sn == 2 or sn == 8 or (t.f == null and sn == 30)) and not seen.has(key):
			seen[key] = true
			(rows[t.who] as Array).append([_orbit_row(t), "%s 第%d格（畫面第 %d 格，戰局 %.2f 秒）" % [tag, sn, frame, bt.time]])

func _finish() -> void:
	var bad := 0
	var keys := stats.keys()
	keys.sort()
	for key in keys:
		var st: Dictionary = stats[key]
		var d: Vector3 = st.max - st.min
		var ok: bool = d.x <= TOL and d.y <= TOL
		if not ok:
			bad += 1
		print("%s %-20s 格數 %4d　眼睛相對頭的位置 x %.2f~%.2f　y %.2f~%.2f　（差 %.2f, %.2f 像素）" % ["ok  " if ok else "FAIL", key, st.n, st.min.x, st.max.x, st.min.y, st.max.y, d.x, d.y])
	for who in rows:
		var rr: Array = rows[who]
		var per := 6
		var idx := 0
		var page := 0
		while idx < rr.size():
			var cnt: int = mini(per, rr.size() - idx)
			var sheet := Image.create(M * 12, M * 2 * cnt, false, Image.FORMAT_RGBA8)
			var lines := PackedStringArray()
			for j in cnt:
				sheet.blit_rect(rr[idx + j][0], Rect2i(0, 0, M * 12, M * 2), Vector2i(0, j * M * 2))
				lines.append("第 %d 組（上排同高、下排俯角 30 度；由左到右 0、30…330 度，0 度是身體正面）：%s" % [j + 1, rr[idx + j][1]])
			var base := "%s/%s_%02d" % [out, who, page]
			sheet.save_png(base + ".png")
			var fa := FileAccess.open(base + ".txt", FileAccess.WRITE)
			fa.store_string("\n".join(lines) + "\n")
			fa.close()
			idx += cnt
			page += 1
	print("FACE_WATCH: %s（%d 組，%d 組超過 %.1f 像素；共 %d 格畫面）" % ["ALL PASS" if bad == 0 and not keys.is_empty() else "FAIL", keys.size(), bad, TOL, frame])
	Engine.time_scale = 1.0
	quit(0 if bad == 0 and not keys.is_empty() else 1)
