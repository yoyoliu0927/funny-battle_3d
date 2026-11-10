extends Node3D
## 載入畫面：一大群白雞整齊排排站，穿黑帽 T 的家豪混在正中間。
## 在背景載入下一個場景（Engine 的 meta "next_scene"），最少顯示 MIN_TIME 秒。

const MIN_TIME := 2.0
const TIPS := [
	"提示：撒飼料可以把家豪引開，讓他一次只對上一個農夫。",
	"提示：走進農夫前方的紅色區域就會被發現。",
	"提示：巨石……好像可以讓它自己滾起來？",
	"提示：香蕉皮誰踩到都會滑倒，家豪也一樣。",
	"提示：沒被發現就啄下去，農夫會嚇一跳愣住。",
]

var _target := ""
var _t := 0.0
var _done := false
var _label: Label
var _bar: ColorRect
var _bar_bg: ColorRect
var _tip: Label

func _ready() -> void:
	_target = String(Engine.get_meta("next_scene", "res://examples/farm/stage.tscn"))
	ResourceLoader.load_threaded_request(_target)
	_build_ground()
	_build_crowd()
	_build_ui()

func _toon(c: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/toon_color.gdshader")
	m.set_shader_parameter("albedo", c)
	return m

func _box(size: Vector3, pos: Vector3, c: Color, rot := Vector3.ZERO) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _toon(c)
	mi.position = pos
	mi.rotation = rot
	add_child(mi)

func _build_ground() -> void:
	var grass := MeshInstance3D.new()
	var gp := PlaneMesh.new()
	gp.size = Vector2(120, 120)
	grass.mesh = gp
	grass.material_override = _toon(Color(0.50, 0.62, 0.30))
	grass.position.y = -0.02
	add_child(grass)
	var dirt := MeshInstance3D.new()
	var dp := CylinderMesh.new()
	dp.top_radius = 9.5
	dp.bottom_radius = 9.5
	dp.height = 0.02
	dp.radial_segments = 40
	dirt.mesh = dp
	dirt.material_override = _toon(Color(0.74, 0.60, 0.42))
	dirt.scale = Vector3(1.25, 1, 0.75)
	add_child(dirt)
	# 後面的木柵欄
	var wood := Color(0.55, 0.38, 0.24)
	for i in 17:
		var x := -12.0 + i * 1.5
		_box(Vector3(0.16, 1.1, 0.16), Vector3(x, 0.55, -6.0), wood.darkened(0.1))
	for h in [0.45, 0.85]:
		_box(Vector3(24.5, 0.1, 0.08), Vector3(0, h, -6.0), wood)
	# 遠處的樹和緩丘
	var blob := SphereMesh.new()
	blob.radius = 1.0
	blob.height = 1.8
	blob.radial_segments = 8
	blob.rings = 5
	var r := RandomNumberGenerator.new()
	r.seed = 5
	for i in 14:
		var x := -22.0 + i * 3.4 + r.randf_range(-0.8, 0.8)
		var z := -13.0 - r.randf_range(0.0, 6.0)
		var h := r.randf_range(2.5, 4.0)
		_box(Vector3(0.35, h * 0.6, 0.35), Vector3(x, h * 0.3, z), Color(0.45, 0.32, 0.2))
		var c := MeshInstance3D.new()
		c.mesh = blob
		c.material_override = _toon(Color(r.randf_range(0.26, 0.36), r.randf_range(0.46, 0.56), 0.24))
		c.position = Vector3(x, h * 0.75, z)
		c.scale = Vector3.ONE * h * 0.45
		add_child(c)
	for i in 3:
		var hill := MeshInstance3D.new()
		hill.mesh = blob
		hill.material_override = _toon(Color(0.47, 0.6, 0.3))
		hill.position = Vector3(-24.0 + i * 24.0, -6.0, -32.0)
		hill.scale = Vector3(18, 9, 10)
		add_child(hill)

func _build_crowd() -> void:
	var chars := Node3D.new()
	chars.set_script(load("res://scripts/characters.gd"))
	add_child(chars)
	var rows := [[-3.6, 8], [-2.0, 7], [-0.4, 8], [1.2, 7]]
	for ri in rows.size():
		var z: float = rows[ri][0]
		var n: int = rows[ri][1]
		for k in n:
			var x := (k - (n - 1) * 0.5) * 1.3
			var hero := ri == 1 and k == 3    # 家豪混在第二排正中間
			var c: Node3D = chars._make_round_chicken(hero)
			chars.add_child(c)
			c.position = Vector3(x, 0, z)
			c.rotation.y = sin(k * 1.7 + ri) * 0.08

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var band := ColorRect.new()
	band.color = Color(0.11, 0.14, 0.2)
	band.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	band.anchor_top = 0.86
	band.offset_top = 0
	layer.add_child(band)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 8)
	band.add_child(box)
	var ls := LabelSettings.new()
	ls.font_size = 28
	_label = Label.new()
	_label.label_settings = ls
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_label)
	var bar_box := CenterContainer.new()
	box.add_child(bar_box)
	_bar_bg = ColorRect.new()
	_bar_bg.color = Color(1, 1, 1, 0.15)
	_bar_bg.custom_minimum_size = Vector2(420, 8)
	bar_box.add_child(_bar_bg)
	_bar = ColorRect.new()
	_bar.color = Color(1.0, 0.85, 0.35)
	_bar.size = Vector2(0, 8)
	_bar_bg.add_child(_bar)
	var ts := LabelSettings.new()
	ts.font_size = 18
	ts.font_color = Color(1, 1, 1, 0.7)
	_tip = Label.new()
	_tip.label_settings = ts
	_tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tip.text = TIPS[int(Time.get_ticks_msec() / 1000) % TIPS.size()]
	box.add_child(_tip)

func _process(dt: float) -> void:
	_t += dt
	var prog := []
	var status := ResourceLoader.load_threaded_get_status(_target, prog)
	var p: float = prog[0] if prog.size() > 0 else 0.0
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		p = 1.0
	var shown := minf(p, _t / MIN_TIME)
	_bar.size.x = 420.0 * shown
	_label.text = "載入中" + ".".repeat(int(_t * 3.0) % 4)
	if _done:
		return
	if status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		_done = true
		get_tree().change_scene_to_file(_target)
	elif status == ResourceLoader.THREAD_LOAD_LOADED and _t >= MIN_TIME:
		_done = true
		_finish()

func _finish() -> void:
	if "--autotest" in OS.get_cmdline_user_args() and DisplayServer.window_can_draw():
		var out_dir := "user://autotest"
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--outdir="):
				out_dir = a.substr(9)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out_dir.path_join("00c_loading.png"))
	get_tree().change_scene_to_packed(ResourceLoader.load_threaded_get(_target))
