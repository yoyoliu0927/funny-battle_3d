extends Node3D
## 開場動畫：夜裡的雞舍 → 夢裡見到神明 → 醒來
##
## 操作：Enter / 空白鍵 / 滑鼠左鍵 下一句（字還在打時先把整句顯示出來）；Esc 跳過整段開場
##
## ★ 對話內容都在下面的 DIALOGUE，之後直接改 text 就好。
##   shot 決定這一句的畫面：
##     "barn"   夜裡的雞舍，家豪睡在稻草堆上
##     "dream"  夢境：發光的神明出現
##     "wake"   回到雞舍，家豪醒來站起來
##   切換 shot 時會自動淡出淡入。

const DIALOGUE := [
	{"shot": "barn", "speaker": "旁白", "text": "（待補：夜深了，農場裡的動物都睡了。）"},
	{"shot": "barn", "speaker": "旁白", "text": "（待補：雞舍角落的稻草堆裡，家豪縮成一團。）"},
	{"shot": "dream", "speaker": "？？？", "text": "（待補：家豪……家豪……）"},
	{"shot": "dream", "speaker": "神明", "text": "（待補：神明現身，說出動物們受到的不公平。）"},
	{"shot": "dream", "speaker": "神明", "text": "（待補：「你就是天選之雞。」）"},
	{"shot": "dream", "speaker": "家豪", "text": "（待補：家豪的回應。）"},
	{"shot": "dream", "speaker": "神明", "text": "（待補：要他去推翻人類的統治，神會在旁邊幫他。）"},
	{"shot": "wake", "speaker": "家豪", "text": "（待補：醒來，覺得只是一場夢？）"},
	{"shot": "wake", "speaker": "家豪", "text": "（待補：決定出發。）"},
]

const NEXT_SCENE := "res://scenes/level_select.tscn"
const TYPE_SPEED := 38.0        # 每秒打幾個字

var _i := -1
var _shown := 0.0
var _typing := false
var _shot := ""
var _busy := false
var _t := 0.0

var _chars: Node
var _hero: Node3D
var _zzz: Label3D
var _god: Node3D
var _barn_cam: Camera3D
var _dream_cam: Camera3D
var _barn_env: Environment
var _dream_env: Environment
var _world_env: WorldEnvironment

var _fade: ColorRect
var _dlg: PanelContainer
var _name: Label
var _text: Label
var _arrow: Label

func _ready() -> void:
	_world_env = $WorldEnvironment
	_barn_env = _world_env.environment
	_chars = Node3D.new()
	_chars.set_script(load("res://scripts/characters.gd"))
	add_child(_chars)
	_build_barn()
	_build_dream()
	_build_ui()
	_fade.color.a = 1.0
	_next()
	if "--autotest" in OS.get_cmdline_user_args():
		_autotest.call_deferred()

# ---------------------------------------------------------------- 小工具

func _toon(c: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/toon_color.gdshader")
	m.set_shader_parameter("albedo", c)
	return m

func _glow(c: Color, alpha := 1.0, add := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(c, alpha)
	if alpha < 1.0 or add:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if add:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi

func _ball(parent: Node3D, r: float, pos: Vector3, mat: Material, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 10
	sm.rings = 6
	mi.mesh = sm
	mi.material_override = mat
	mi.position = pos
	mi.scale = scl
	parent.add_child(mi)
	return mi

# ---------------------------------------------------------------- 夜裡的雞舍

func _build_barn() -> void:
	var barn := Node3D.new()
	barn.name = "Barn"
	add_child(barn)
	var wood := _toon(Color(0.52, 0.36, 0.24))
	var dark := _toon(Color(0.36, 0.24, 0.16))
	var straw := _toon(Color(0.86, 0.72, 0.38))
	_box(barn, Vector3(10, 0.1, 8), Vector3(0, -0.05, 0), _toon(Color(0.55, 0.42, 0.28)))
	_box(barn, Vector3(10, 4, 0.2), Vector3(0, 2, -3.0), wood)
	_box(barn, Vector3(0.2, 4, 8), Vector3(-4.6, 2, 0.5), wood)
	_box(barn, Vector3(0.2, 4, 8), Vector3(4.6, 2, 0.5), wood)
	_box(barn, Vector3(10, 0.2, 8), Vector3(0, 4.0, 0.5), dark)
	for i in 7:
		_box(barn, Vector3(9.8, 0.03, 0.05), Vector3(0, 0.5 + i * 0.5, -2.88), dark)
	for x in [-3.0, 0.0, 3.0]:
		_box(barn, Vector3(0.26, 4, 0.26), Vector3(x, 2, -2.85), dark)
	# 月光窗
	_box(barn, Vector3(1.4, 1.1, 0.05), Vector3(-1.5, 2.5, -2.86), _glow(Color(0.35, 0.45, 0.75)))
	_ball(barn, 0.2, Vector3(-1.2, 2.75, -2.84), _glow(Color(0.95, 0.95, 0.85)))
	_box(barn, Vector3(0.08, 1.2, 0.1), Vector3(-1.5, 2.5, -2.8), dark)
	_box(barn, Vector3(1.5, 0.08, 0.1), Vector3(-1.5, 2.5, -2.8), dark)
	# 稻草：地上一大片，加上幾堆
	_box(barn, Vector3(5, 0.12, 3.6), Vector3(0.4, 0.06, -0.6), straw)
	# 牆邊幾堆圓圓的稻草堆
	var straw2 := _toon(Color(0.9, 0.76, 0.42))
	for p in [Vector3(-3.0, 0.4, -2.0), Vector3(-2.2, 0.3, -2.3), Vector3(3.0, 0.45, -1.9), Vector3(3.6, 0.35, -0.6)]:
		_ball(barn, 0.75, p, straw2, Vector3(1.3, 0.75, 1.0))
	for k in 40:
		var a := k * 2.39996
		var r := 0.4 + sqrt(float(k)) * 0.35
		_box(barn, Vector3(0.5, 0.03, 0.04), Vector3(0.4 + cos(a) * r, 0.13, -0.6 + sin(a) * r * 0.7), straw, Vector3(0, a, 0))
	# 吊燈
	_box(barn, Vector3(0.24, 0.34, 0.24), Vector3(2.0, 2.6, -2.7), _toon(Color(0.22, 0.2, 0.18)))
	_ball(barn, 0.1, Vector3(2.0, 2.6, -2.56), _glow(Color(1.0, 0.82, 0.45)))
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(1.8, 2.4, -1.8)
	lamp.light_color = Color(1.0, 0.75, 0.45)
	lamp.light_energy = 1.6
	lamp.omni_range = 6.5
	barn.add_child(lamp)
	# 其他雞在旁邊睡（圓滾滾的白雞）
	for p in [Vector3(-2.0, 0.12, -0.9), Vector3(2.4, 0.12, -0.4), Vector3(-1.2, 0.12, 0.8)]:
		var c: Node3D = _chars._make_round_chicken(false)
		_chars.add_child(c)
		c.position = p
		c.scale *= 0.75
		c.rotation.y = p.x * 0.6
	# 家豪：睡在中間的稻草上
	_hero = _chars._make_standin_rooster(true)
	_chars.add_child(_hero)
	_zzz = Label3D.new()
	_zzz.text = "Z z z"
	_zzz.font_size = 64
	_zzz.pixel_size = 0.006
	_zzz.outline_size = 10
	_zzz.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_zzz.modulate = Color(0.85, 0.9, 1.0)
	add_child(_zzz)
	_barn_cam = Camera3D.new()
	_barn_cam.fov = 45.0
	add_child(_barn_cam)
	_barn_cam.position = Vector3(0.8, 2.0, 3.6)
	_barn_cam.look_at(Vector3(0.3, 0.6, -0.6))

func _pose_sleep() -> void:
	_hero.position = Vector3(0.3, 0.14, -0.4)
	_hero.rotation = Vector3(0, 0.4, 1.35)   # 側躺
	_zzz.visible = true

func _pose_wake() -> void:
	_hero.position = Vector3(0.3, 0.12, -0.4)
	_hero.rotation = Vector3(0, 0.3, 0)
	_zzz.visible = false

# ---------------------------------------------------------------- 夢境

func _build_dream() -> void:
	var dream := Node3D.new()
	dream.name = "Dream"
	dream.position = Vector3(0, 0, 300)
	add_child(dream)
	# 雲海地面
	var r := RandomNumberGenerator.new()
	r.seed = 3
	var cloud := _toon(Color(0.98, 0.96, 1.0))
	for k in 60:
		var p := Vector3(r.randf_range(-14, 14), r.randf_range(-0.6, -0.1), r.randf_range(-14, 8))
		_ball(dream, r.randf_range(0.8, 2.0), p, cloud, Vector3(1.4, 0.5, 1.2))
	# 從天而降的光柱
	var beam := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 1.6
	cm.bottom_radius = 2.4
	cm.height = 30
	cm.cap_top = false
	cm.cap_bottom = false
	beam.mesh = cm
	beam.material_override = _glow(Color(1.0, 0.92, 0.6), 0.25, true)
	beam.position = Vector3(0, 14, -3)
	dream.add_child(beam)
	# 神明：發光的身影 + 光環 + 環繞的小光點
	_god = Node3D.new()
	_god.position = Vector3(0, 3.0, -3)
	dream.add_child(_god)
	_ball(_god, 0.9, Vector3.ZERO, _glow(Color(1.0, 0.82, 0.38)), Vector3(0.85, 1.25, 0.85))
	_ball(_god, 0.5, Vector3(0, 1.45, 0), _glow(Color(1.0, 0.88, 0.5)))
	_ball(_god, 1.6, Vector3(0, 0.3, 0), _glow(Color(1.0, 0.9, 0.55), 0.18, true))
	for k in 2:
		var halo := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 1.25 + k * 0.45
		tm.outer_radius = 1.35 + k * 0.45
		tm.rings = 48
		halo.mesh = tm
		halo.material_override = _glow(Color(1.0, 0.85, 0.4), 0.8, true)
		halo.name = "Halo%d" % k
		halo.rotation = Vector3(PI * 0.5 - 0.3 * k, 0, 0.2 * k)
		halo.position.y = 0.4
		_god.add_child(halo)
	for k in 8:
		var orb := _ball(_god, 0.08, Vector3.ZERO, _glow(Color(1.0, 0.95, 0.7)))
		orb.name = "Orb%d" % k
	var light := OmniLight3D.new()
	light.position = Vector3(0, 3.5, -1.5)
	light.light_color = Color(1.0, 0.9, 0.7)
	light.light_energy = 2.5
	light.omni_range = 14.0
	dream.add_child(light)
	_dream_cam = Camera3D.new()
	_dream_cam.fov = 50.0
	dream.add_child(_dream_cam)
	_dream_cam.position = Vector3(0, 2.0, 6.5)
	_dream_cam.look_at(dream.global_position + Vector3(0, 2.2, -3))
	# 夢境的環境：明亮、帶點紫的霧
	_dream_env = _barn_env.duplicate()
	_dream_env.background_mode = Environment.BG_COLOR
	_dream_env.background_color = Color(0.62, 0.56, 0.82)
	_dream_env.ambient_light_color = Color(0.95, 0.9, 1.0)
	_dream_env.ambient_light_energy = 1.2
	_dream_env.fog_enabled = true
	_dream_env.fog_light_color = Color(0.92, 0.88, 1.0)
	_dream_env.fog_density = 0.012

func _pose_dream() -> void:
	# 夢裡的家豪站在光柱前，抬頭看神明
	_hero.position = Vector3(0, 0.0, 302.0)
	_hero.rotation = Vector3(0, PI, 0)
	_zzz.visible = false

# ---------------------------------------------------------------- 介面

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_dlg = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.12, 0.17, 0.88)
	sb.set_corner_radius_all(16)
	sb.set_content_margin_all(22)
	sb.border_color = Color(1, 0.9, 0.6, 0.6)
	sb.set_border_width_all(2)
	_dlg.add_theme_stylebox_override("panel", sb)
	_dlg.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_dlg.offset_left = 120
	_dlg.offset_right = -120
	_dlg.offset_top = -210
	_dlg.offset_bottom = -36
	layer.add_child(_dlg)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	_dlg.add_child(v)
	var ns := LabelSettings.new()
	ns.font_size = 26
	ns.font_color = Color(1.0, 0.86, 0.45)
	_name = Label.new()
	_name.label_settings = ns
	v.add_child(_name)
	var ts := LabelSettings.new()
	ts.font_size = 28
	ts.line_spacing = 6
	_text = Label.new()
	_text.label_settings = ts
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(0, 80)
	v.add_child(_text)
	var as_ := LabelSettings.new()
	as_.font_size = 18
	as_.font_color = Color(1, 1, 1, 0.6)
	_arrow = Label.new()
	_arrow.label_settings = as_
	_arrow.text = "Enter ▶ 下一句　｜　Esc 跳過開場"
	_arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_child(_arrow)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 1)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_fade)

# ---------------------------------------------------------------- 流程

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo:
		if e.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
			advance()
		elif e.keycode == KEY_ESCAPE:
			skip()
	elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		advance()

## 下一句：字還在打就先整句顯示
func advance() -> void:
	if _busy:
		return
	if _typing:
		_shown = float(_text.text.length())
		_text.visible_characters = -1
		_typing = false
		return
	_next()

func skip() -> void:
	if _busy:
		return
	_busy = true
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 0.4)
	await tw.finished
	get_tree().change_scene_to_file(NEXT_SCENE)

func _next() -> void:
	_i += 1
	if _i >= DIALOGUE.size():
		skip()
		return
	var line: Dictionary = DIALOGUE[_i]
	if line.shot != _shot:
		_busy = true
		_dlg.visible = false
		var tw := create_tween()
		tw.tween_property(_fade, "color:a", 1.0, 0.35 if _shot != "" else 0.0)
		await tw.finished
		_set_shot(line.shot)
		var tw2 := create_tween()
		tw2.tween_property(_fade, "color:a", 0.0, 0.6)
		await tw2.finished
		_busy = false
		_dlg.visible = true
	_name.text = line.speaker
	_text.text = line.text
	_text.visible_characters = 0
	_shown = 0.0
	_typing = true

func _set_shot(s: String) -> void:
	_shot = s
	match s:
		"barn":
			_pose_sleep()
			_world_env.environment = _barn_env
			_barn_cam.current = true
		"dream":
			_pose_dream()
			_world_env.environment = _dream_env
			_dream_cam.current = true
		"wake":
			_pose_wake()
			_world_env.environment = _barn_env
			_barn_cam.current = true

func _process(dt: float) -> void:
	_t += dt
	if _typing:
		_shown += dt * TYPE_SPEED
		_text.visible_characters = int(_shown)
		if _shown >= _text.text.length():
			_typing = false
			_text.visible_characters = -1
	_arrow.modulate.a = 0.5 + 0.5 * absf(sin(_t * 3.0)) if not _typing else 0.25
	# 呼吸、Zzz 飄、神明的光環和光點轉
	if _zzz.visible:
		_zzz.position = _hero.position + Vector3(0.4, 1.1 + fmod(_t * 0.4, 0.6), 0)
		_zzz.modulate.a = 1.0 - fmod(_t * 0.4, 0.6) / 0.6
	if _god:
		_god.position.y = 3.0 + sin(_t * 1.2) * 0.15
		for k in 2:
			var h := _god.get_node("Halo%d" % k) as Node3D
			h.rotate_y(dt * (0.6 + k * 0.4))
		for k in 8:
			var o := _god.get_node("Orb%d" % k) as Node3D
			var a := _t * 0.8 + k * TAU / 8.0
			o.position = Vector3(cos(a) * 2.2, 0.4 + sin(a * 2.0) * 0.5, sin(a) * 2.2)
	if _shot == "wake":
		# 醒來：左右張望一下
		_hero.rotation.y = 0.3 + sin(_t * 1.5) * 0.35

# ---------------------------------------------------------------- 自動驗收（--autotest）

func _autotest() -> void:
	var out_dir := "user://autotest"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--outdir="):
			out_dir = a.substr(9)
	DirAccess.make_dir_recursive_absolute(out_dir)
	var lines: Array = []
	var fails := 0
	var shots := {}
	var seen := []
	while _i < DIALOGUE.size() and seen.size() < 40:
		await get_tree().create_timer(0.9).timeout
		if not shots.has(_shot) and not _busy and DisplayServer.window_can_draw():
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(out_dir.path_join("intro_%s.png" % _shot))
			shots[_shot] = true
		seen.append(_shot)
		if _i == DIALOGUE.size() - 1 and not _typing:
			break
		advance()
		if _typing:
			advance()
	var ok := seen.has("barn") and seen.has("dream") and seen.has("wake")
	lines.append("[%s] 開場動畫：雞舍 → 夢見神明 → 醒來（%d 句對話）" % ["PASS" if ok else "FAIL", DIALOGUE.size()])
	if not ok:
		fails += 1
	for l in lines:
		print(l)
	Engine.set_meta("intro_lines", lines)
	Engine.set_meta("intro_fails", fails)
	advance()
