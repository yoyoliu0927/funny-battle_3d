extends Node3D
## 輸了之後的畫面：農舍裡，農夫們圍著餐桌開心地吃一隻烤雞，牆上掛著家豪的黑色 W 帽 T。
## 整個場景用程式拼出來（卡通低多邊形），放在離農場很遠的地方，用自己的鏡頭拍。

var cam: Camera3D

func build(chars: Node) -> void:
	# 地板、牆、天花板
	var wood := Color(0.62, 0.43, 0.28)
	var dark := Color(0.42, 0.28, 0.18)
	_box(Vector3(11, 0.1, 8), Vector3(0, -0.05, 0), Color(0.55, 0.40, 0.28))
	_box(Vector3(11, 4.4, 0.2), Vector3(0, 2.2, -3.2), wood)
	_box(Vector3(0.2, 4.4, 8), Vector3(-5.4, 2.2, 0.5), wood.darkened(0.05))
	_box(Vector3(0.2, 4.4, 8), Vector3(5.4, 2.2, 0.5), wood.darkened(0.05))
	_box(Vector3(11, 0.2, 8), Vector3(0, 4.4, 0.5), dark)
	for i in 8:   # 牆上的木板縫
		_box(Vector3(10.8, 0.03, 0.05), Vector3(0, 0.5 + i * 0.5, -3.08), dark)
	for x in [-4.0, -1.2, 2.2, 4.9]:   # 柱子
		_box(Vector3(0.28, 4.4, 0.28), Vector3(x, 2.2, -3.0), dark)
	_box(Vector3(10.8, 0.3, 0.3), Vector3(0, 3.9, -3.0), dark)
	# 窗戶：外面是農場風景
	_box(Vector3(2.2, 1.7, 0.05), Vector3(-2.7, 2.4, -3.05), Color(0.62, 0.82, 0.88), true)
	_box(Vector3(2.2, 0.5, 0.06), Vector3(-2.7, 1.8, -3.04), Color(0.55, 0.72, 0.38), true)
	_box(Vector3(0.45, 0.35, 0.07), Vector3(-3.2, 2.1, -3.03), Color(0.75, 0.25, 0.2), true)
	_box(Vector3(0.18, 0.55, 0.07), Vector3(-2.6, 2.2, -3.03), Color(0.85, 0.85, 0.82), true)
	for k in 3:
		_box(Vector3(0.08, 1.8, 0.1), Vector3(-3.75 + k * 0.7 + 0.35, 2.4, -2.98), dark)
	for k in 3:
		_box(Vector3(2.3, 0.08, 0.1), Vector3(-2.7, 1.55 + k * 0.85, -2.98), dark)
	# 架子：罐子、盆栽、小雞擺飾
	_box(Vector3(2.2, 0.08, 0.35), Vector3(0.6, 2.9, -2.9), dark)
	_cyl(0.16, 0.28, Vector3(-0.1, 3.08, -2.9), Color(0.92, 0.88, 0.78))
	_cyl(0.165, 0.06, Vector3(-0.1, 3.24, -2.9), Color(0.75, 0.3, 0.22))
	for k in 5:
		_ball(0.14, Vector3(0.6 + (k - 2) * 0.12, 3.08 + (k % 2) * 0.1, -2.88), Color(0.36, 0.58, 0.28))
	_cyl(0.13, 0.18, Vector3(0.6, 3.0, -2.9), Color(0.7, 0.42, 0.26))
	var deco: Node3D = chars._make_round_chicken(false)
	add_child(deco)
	deco.scale *= 0.18
	deco.position = Vector3(1.4, 2.94, -2.9)
	# 吊燈（暖黃光）
	_box(Vector3(0.28, 0.4, 0.28), Vector3(2.0, 2.7, -2.85), Color(0.25, 0.22, 0.2))
	_ball(0.11, Vector3(2.0, 2.7, -2.7), Color(1.0, 0.85, 0.5), true)
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(2.0, 2.6, -2.2)
	lamp.light_color = Color(1.0, 0.78, 0.5)
	lamp.light_energy = 2.2
	lamp.omni_range = 7.0
	add_child(lamp)
	var fill := OmniLight3D.new()
	fill.position = Vector3(0, 3.6, 1.5)
	fill.light_color = Color(1.0, 0.86, 0.66)
	fill.light_energy = 1.6
	fill.omni_range = 9.0
	add_child(fill)
	# 掛勾板 + 家豪的黑色 W 帽 T
	_box(Vector3(1.6, 0.25, 0.08), Vector3(3.7, 3.2, -3.05), Color(0.6, 0.42, 0.26))
	for k in 3:
		_box(Vector3(0.06, 0.06, 0.2), Vector3(3.2 + k * 0.5, 3.15, -2.95), dark)
	var black := Color(0.1, 0.1, 0.11)
	_box(Vector3(0.95, 0.9, 0.22), Vector3(3.7, 2.4, -2.95), black)
	_ball(0.3, Vector3(3.7, 2.92, -2.98), black)
	for sx in [-1.0, 1.0]:
		var arm := MeshInstance3D.new()
		var cm := CapsuleMesh.new()
		cm.radius = 0.12
		cm.height = 0.9
		arm.mesh = cm
		arm.material_override = _toon(black)
		arm.position = Vector3(3.7 + sx * 0.55, 2.35, -2.95)
		arm.rotation.z = sx * 0.18
		add_child(arm)
		_box(Vector3(0.035, 0.32, 0.03), Vector3(3.7 + sx * 0.1, 2.68, -2.83), Color(0.95, 0.95, 0.93))
	chars._w_mark(self, Vector3(3.7, 2.3, -2.83), 0.11, Color(0.95, 0.95, 0.93))
	_ball(0.035, Vector3(3.83, 2.16, -2.83), Color(0.9, 0.2, 0.15))
	# 木桶、蘋果箱、麥穗花瓶
	_cyl(0.42, 1.0, Vector3(-4.7, 0.5, -2.4), Color(0.55, 0.36, 0.22))
	_box(Vector3(0.9, 0.55, 0.6), Vector3(4.6, 0.28, -1.8), Color(0.72, 0.5, 0.3))
	for k in 4:
		_ball(0.12, Vector3(4.35 + k * 0.17, 0.62, -1.8 + (k % 2) * 0.12), Color(0.85, 0.2, 0.15))
	# 餐桌與桌巾
	_box(Vector3(3.6, 0.12, 1.6), Vector3(0, 0.88, 0), Color(0.6, 0.4, 0.25))
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_box(Vector3(0.14, 0.86, 0.14), Vector3(sx * 1.6, 0.43, sz * 0.65), dark)
	_box(Vector3(1.0, 0.02, 1.62), Vector3(0, 0.95, 0), Color(0.93, 0.88, 0.78))
	for sx in [-0.3, 0.3]:
		_box(Vector3(0.06, 0.025, 1.63), Vector3(sx, 0.955, 0), Color(0.85, 0.35, 0.3))
	# 烤雞大餐
	_cyl(0.62, 0.05, Vector3(0, 0.98, 0), Color(0.96, 0.95, 0.92))
	var roast := MeshInstance3D.new()
	var rm := SphereMesh.new()
	rm.radius = 0.36
	rm.height = 0.72
	rm.radial_segments = 8
	rm.rings = 5
	roast.mesh = rm
	roast.material_override = _toon(Color(0.88, 0.52, 0.22))
	roast.position = Vector3(0, 1.18, 0)
	roast.scale = Vector3(1.25, 0.7, 0.95)
	add_child(roast)
	for sx in [-1.0, 1.0]:
		var leg := MeshInstance3D.new()
		var lm := CapsuleMesh.new()
		lm.radius = 0.11
		lm.height = 0.42
		leg.mesh = lm
		leg.material_override = _toon(Color(0.85, 0.48, 0.2))
		leg.position = Vector3(sx * 0.38, 1.15, 0.18)
		leg.rotation = Vector3(0.4, 0, sx * 1.1)
		add_child(leg)
		_ball(0.045, Vector3(sx * 0.6, 1.25, 0.28), Color(0.97, 0.95, 0.9))
	var veg := [Color(0.95, 0.55, 0.2), Color(0.95, 0.82, 0.35), Color(0.4, 0.65, 0.3)]
	for k in 12:
		var a := k * TAU / 12.0
		_ball(0.07, Vector3(cos(a) * 0.5, 1.03, sin(a) * 0.42), veg[k % 3])
	# 盤子和杯子
	for p in [Vector3(-1.2, 0, 0.45), Vector3(1.2, 0, 0.45), Vector3(-1.2, 0, -0.45), Vector3(1.2, 0, -0.45), Vector3(-0.6, 0, 0.55), Vector3(0.6, 0, -0.55)]:
		_cyl(0.2, 0.03, Vector3(p.x, 0.96, p.z), Color(0.97, 0.96, 0.93))
		_ball(0.06, Vector3(p.x, 1.0, p.z), Color(0.88, 0.55, 0.3))
		_cyl(0.07, 0.15, Vector3(p.x + 0.25, 1.02, p.z), Color(0.95, 0.92, 0.85))
	# 農夫們圍著餐桌（後面三個、兩側各一個）
	var spots := [[Vector3(-1.1, 0, -1.25), 0.0], [Vector3(0.0, 0, -1.35), 0.0], [Vector3(1.1, 0, -1.25), 0.0],
		[Vector3(-2.35, 0, 0.1), PI * 0.5], [Vector3(2.35, 0, 0.1), -PI * 0.5]]
	for sp in spots:
		var f: Node3D = chars._load_model(["farmer"], 2.1, ["Interact", "Idle"])
		if f == null:
			continue
		add_child(f)
		f.position = sp[0]
		f.rotation.y = sp[1]
	# 鏡頭
	cam = Camera3D.new()
	cam.fov = 50.0
	add_child(cam)
	cam.position = Vector3(0, 2.7, 4.8)
	cam.look_at(global_position + Vector3(0, 1.3, -0.8))

func _toon(c: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/toon_color.gdshader")
	m.set_shader_parameter("albedo", c)
	return m

func _mat(c: Color, glow: bool) -> Material:
	if not glow:
		return _toon(c)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	return m

func _box(size: Vector3, pos: Vector3, c: Color, glow := false) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _mat(c, glow)
	mi.position = pos
	add_child(mi)

func _ball(r: float, pos: Vector3, c: Color, glow := false) -> void:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 8
	sm.rings = 5
	mi.mesh = sm
	mi.material_override = _mat(c, glow)
	mi.position = pos
	add_child(mi)

func _cyl(r: float, h: float, pos: Vector3, c: Color) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = h
	cm.radial_segments = 14
	mi.mesh = cm
	mi.material_override = _toon(c)
	mi.position = pos
	add_child(mi)
