extends Node3D
## 農莊的池塘＋釣魚小遊戲（主島的「釣魚」站點）。
##
## 玩法（一次只要幾秒）：
##   1. Space 甩竿：浮標飛進池塘。　2. 等：浮標靜靜浮著，太早收線會嚇跑魚。
##   3. 浮標一沉、頭上冒出「！」：一秒內按 Space 拉鉤。　4. 拉線：一條時機條，游標來回跑，
##   在綠色區域裡按 Space 就拉上來一點；稀有的魚綠色區域更窄、要拉不只一次。
##   5. 釣到的東西會飛出水面，圖鑑記下名字、大小（第一次釣到是「新發現」）。垃圾和寶物也算圖鑑。
## 按 Esc 收竿。魚種、稀有度在 journal.gd。池塘裡看得到魚影在游，上鉤的那一條會游過來。
##
## 主島（level_select.gd）蓋站點時呼叫 build_pond()；進入站點按 Enter 呼叫 begin()。

const Journal := preload("res://scripts/hub/journal.gd")
const Sfx := preload("res://scripts/hub/hub_sfx.gd")
const HubUI := preload("res://scripts/hub/hub_ui.gd")
const UIStyle := preload("res://scripts/ui/ui_style.gd")
const WaterShader := preload("res://scripts/hub/pond.gdshader")

const ROD := "res://levels/ice/assets/blender/fishing_rod.glb"
const ROCKS := "res://levels/fort/assets/castle/rocks-small.glb"
const ROD_SCALE := 1.7
const ROD_TIP := Vector3(0.0, 0.88, 1.25)        # 釣竿模型的竿尖（模型座標）
const BOB_SCALE := 2.6
const BITE_WINDOW := 1.0
const FACE_YAW := PI * 0.9                       # 釣魚時家豪朝北（池塘那邊）

var map                         # 選關畫面
var active := false
var state := "off"              # off／aim／cast／wait／bite／reel／catch／fail

var pond_node: Node3D           # 池塘中心（跟著主島）
var pond_rx := 6.4
var pond_rz := 4.6
var _swimmers: Array = []
var _lilies: Array = []
var _ripples: Array = []
var _ring_tex: ImageTexture
var _snd := {}
var _rng := RandomNumberGenerator.new()
var _t := 0.0
var _st := 0.0                  # 目前這個階段過了幾秒
var _rod: Node3D
var _bob: Node3D
var _line: MeshInstance3D
var _target := Vector3.ZERO
var _from := Vector3.ZERO
var _wait := 2.0
var _biter := -1
var _sp := {}                   # 這次咬鉤的東西（Journal.FISH 的一筆）
var _cm := 0
var _rounds := 1
var _round := 0
var _mark := 0.0
var _dir := 1.0
var _zone_c := 0.5
var _zone_w := 0.3
var _speed := 1.0
var _flash := 0.0               # 拉線按下去：>0 綠光、<0 紅光
var _fish3d: Node3D
var _result := {}
var _layer: CanvasLayer
var _ui: HubUI.Canvas

func _ready() -> void:
	_rng.seed = 5150
	_snd = Sfx.attach(self, -4.0)
	_layer = CanvasLayer.new()
	_layer.layer = 8
	add_child(_layer)
	_ui = HubUI.Canvas.new()
	_ui.painter = _paint
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(_ui)

# ---------------------------------------------------------------- 蓋池塘

## 在 parent（站點地標的節點）底下蓋一座池塘：中心在 local_c，半徑 rx × rz。回傳池塘節點
func build_pond(parent: Node3D, local_c: Vector3, rx: float, rz: float) -> Node3D:
	pond_rx = rx
	pond_rz = rz
	pond_node = Node3D.new()
	pond_node.name = "Pond"
	pond_node.position = local_c
	parent.add_child(pond_node)
	# 岸：比水面大一圈的沙地
	var bank := MeshInstance3D.new()
	bank.mesh = _disc(rx * 1.2, rz * 1.22, 56, 0.9)
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Color("d8c288")
	bm.roughness = 1.0
	bm.cull_mode = BaseMaterial3D.CULL_DISABLED
	bank.material_override = bm
	bank.position.y = -0.03
	bank.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pond_node.add_child(bank)
	# 水
	var water := MeshInstance3D.new()
	water.mesh = _disc(rx, rz, 56, 0.0)
	var sm := ShaderMaterial.new()
	sm.shader = WaterShader
	water.material_override = sm
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pond_node.add_child(water)
	# 魚影：幾條在水裡游（暗藍半透明，從水面看得到）
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.05, 0.28, 0.45, 0.55)
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.render_priority = 2
	for i in 6:
		var f := _model(Journal.MODELS["large" if i % 3 == 0 else "fish"], 0.95 if i % 3 == 0 else 0.7)
		if f == null:
			continue
		_apply_mat(f, fm)
		pond_node.add_child(f)
		var rr := _rng.randf_range(0.35, 0.85)
		_swimmers.append({"node": f, "a": _rng.randf() * TAU, "sp": _rng.randf_range(0.18, 0.4) * (1.0 if i % 2 == 0 else -1.0),
			"rx": rx * rr * 0.92, "rz": rz * rr * 0.9, "mode": "loop", "pos": Vector3.ZERO, "size": 1.0, "ph": i * 1.3})
	# 睡蓮：幾片葉子飄著，兩朵粉紅的花
	var lm := StandardMaterial3D.new()
	lm.albedo_color = Color("5fb34f")
	lm.roughness = 0.9
	var pm := StandardMaterial3D.new()
	pm.albedo_color = Color("ff9fc0")
	for i in 5:
		var pad := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.42
		cyl.bottom_radius = 0.42
		cyl.height = 0.03
		cyl.radial_segments = 14
		pad.mesh = cyl
		pad.material_override = lm
		pond_node.add_child(pad)
		var base := Vector3(_rng.randf_range(-0.7, 0.7) * rx, 0.045, _rng.randf_range(-0.75, 0.55) * rz)
		if i < 2:
			var fl := MeshInstance3D.new()
			var sph := SphereMesh.new()
			sph.radius = 0.14
			sph.height = 0.26
			fl.mesh = sph
			fl.material_override = pm
			fl.position = Vector3(0.05, 0.12, 0)
			pad.add_child(fl)
		_lilies.append({"node": pad, "base": base, "ph": i * 1.9})
	# 岸邊的石頭（南邊留一個缺口：家豪站在那裡）
	for i in 11:
		var a := TAU * (float(i) + 0.5) / 11.0
		if sin(a) > 0.55 and absf(cos(a)) < 0.6:
			continue
		var wob := 1.22 + 0.05 * sin(a * 3.0)
		map._spawn_fit(pond_node, ROCKS, Vector3(cos(a) * rx * wob, -0.03, sin(a) * rz * wob), 1.0 + 0.5 * absf(sin(i * 2.7)), a * 3.0)
	return pond_node

## 平的橢圓盤（扇形三角面）。UV = (x / rx, z / rz)；wob：邊緣不規則的程度
func _disc(rx: float, rz: float, segs: int, wob: float) -> ArrayMesh:
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var norms := PackedVector3Array()
	var idx := PackedInt32Array()
	verts.append(Vector3.ZERO)
	uvs.append(Vector2.ZERO)
	norms.append(Vector3.UP)
	for i in segs:
		var a := TAU * i / segs
		var k := 1.0 + (0.05 * sin(3.0 * a + 1.0) + 0.035 * sin(5.0 * a + 2.0)) * (0.4 + wob)
		verts.append(Vector3(cos(a) * rx * k, 0, sin(a) * rz * k))
		uvs.append(Vector2(cos(a) * k, sin(a) * k) * (1.0 if wob < 0.01 else 1.0 / 1.2))
		norms.append(Vector3.UP)
		idx.append_array([0, 1 + (i + 1) % segs, 1 + i])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m

# ---------------------------------------------------------------- 模型小工具

func _aabb(node: Node, xf: Transform3D) -> AABB:
	var out := AABB()
	var have := false
	if node is Node3D:
		xf = xf * (node as Node3D).transform
	if node is MeshInstance3D and (node as MeshInstance3D).mesh:
		out = xf * (node as MeshInstance3D).mesh.get_aabb()
		have = true
	for c in node.get_children():
		var b := _aabb(c, xf)
		if b.size != Vector3.ZERO:
			out = out.merge(b) if have else b
			have = true
	return out

## 載入模型，最長邊縮放成 target 公尺，原點在中心
func _model(path: String, target: float) -> Node3D:
	if not ResourceLoader.exists(path):
		return null
	var ps := load(path) as PackedScene
	if ps == null:
		return null
	var holder := Node3D.new()
	var n := ps.instantiate() as Node3D
	holder.add_child(n)
	var bb := _aabb(n, Transform3D.IDENTITY)
	var s := target / maxf(maxf(bb.size.x, bb.size.y), maxf(bb.size.z, 0.001))
	n.transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * s), -bb.get_center() * s) * n.transform
	return holder

func _apply_mat(n: Node, m: Material) -> void:
	if n is MeshInstance3D:
		(n as MeshInstance3D).material_override = m
	for c in n.get_children():
		_apply_mat(c, m)

## 把顏色乘在模型原本的材質上（每個面複製一份，不會改到別的魚）
func _tint(n: Node, col: Color) -> void:
	if n is MeshInstance3D and (n as MeshInstance3D).mesh:
		var mi := n as MeshInstance3D
		for s in mi.mesh.get_surface_count():
			var m := mi.get_active_material(s) as BaseMaterial3D
			if m:
				var d := m.duplicate() as BaseMaterial3D
				d.albedo_color = col
				mi.set_surface_override_material(s, d)
	for c in n.get_children():
		_tint(c, col)

# ---------------------------------------------------------------- 進出

func pond_center() -> Vector3:
	return pond_node.global_position if pond_node else Vector3.ZERO

func begin() -> bool:
	if pond_node == null or active:
		return false
	active = true
	_layer.visible = true
	_make_rod()
	_make_bob()
	state = "aim"
	_st = 0.0
	map._face_yaw = FACE_YAW
	var hp: Vector3 = (map._hero as Node3D).global_position
	map._cam_bias_to = (pond_center() - hp) * 0.45 + Vector3(0, 0.5, 0)
	_play("tick")
	return true

func end() -> void:
	if not active:
		return
	active = false
	state = "off"
	for n in [_rod, _bob, _line, _fish3d]:
		if n and is_instance_valid(n):
			(n as Node).queue_free()
	_rod = null
	_bob = null
	_line = null
	_fish3d = null
	_release_biter()
	map._face_yaw = 0.0
	map._cam_bias_to = Vector3.ZERO
	_ui.queue_redraw()

func _make_rod() -> void:
	var hero: Node3D = map._hero
	_rod = _load_part(ROD, ["Rod", "Reel"])
	if _rod:
		_rod.scale = Vector3.ONE * ROD_SCALE
		_rod.position = Vector3(0.62, 0.75, 0.3)
		hero.add_child(_rod)
	_line = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.012
	cyl.bottom_radius = 0.012
	cyl.height = 1.0
	cyl.radial_segments = 4
	_line.mesh = cyl
	var lm := StandardMaterial3D.new()
	lm.albedo_color = Color(1, 1, 1, 0.9)
	lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_line.material_override = lm
	_line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_line)

func _make_bob() -> void:
	_bob = _load_part(ROD, ["BobTop", "BobLow"])
	if _bob == null:
		_bob = Node3D.new()
	_bob.scale = Vector3.ONE * BOB_SCALE
	add_child(_bob)

## 從釣竿模型裡只留下指定名字的零件（其他的刪掉），中心搬到原點
func _load_part(path: String, keep: Array) -> Node3D:
	if not ResourceLoader.exists(path):
		return null
	var n := (load(path) as PackedScene).instantiate() as Node3D
	for c in n.get_children():
		if not String(c.name) in keep:
			n.remove_child(c)
			c.queue_free()
	var holder := Node3D.new()
	holder.add_child(n)
	if String(keep[0]).begins_with("Bob"):
		var bb := _aabb(n, Transform3D.IDENTITY)
		n.position = -bb.get_center()
	return holder

func _rod_tip() -> Vector3:
	return _rod.to_global(ROD_TIP) if _rod else (map._hero as Node3D).global_position + Vector3(0, 2, 2)

func _water_y() -> float:
	return pond_center().y

# ---------------------------------------------------------------- 按鍵

func _unhandled_input(ev: InputEvent) -> void:
	if not active:
		return
	if ev is InputEventKey and ev.pressed and not ev.echo:
		match ev.keycode:
			KEY_SPACE, KEY_ENTER, KEY_KP_ENTER:
				press()
				get_viewport().set_input_as_handled()
			KEY_ESCAPE, KEY_BACKSPACE:
				end()
				get_viewport().set_input_as_handled()
			KEY_V:
				pass
			_:
				get_viewport().set_input_as_handled()
	elif ev is InputEventMouseButton and ev.pressed:
		if ev.button_index == MOUSE_BUTTON_LEFT:
			press()
		get_viewport().set_input_as_handled()

func press() -> void:
	match state:
		"aim":
			_cast()
		"wait":
			# 太早收線：魚嚇跑了
			_say("太早了！")
			_play("miss")
			_to("aim")
			_release_biter()
		"bite":
			_hook()
		"reel":
			_pull()
		"catch":
			if _st > 1.2:
				_clear_catch()
				_to("aim")

func _to(s: String) -> void:
	state = s
	_st = 0.0

func _say(t: String, col := Color.WHITE) -> void:
	var hp: Vector3 = (map._hero as Node3D).global_position
	map._life.say(hp + Vector3(0, 3.4, 0), t, col)

func _play(id: String, pitch := 1.0) -> void:
	var p: AudioStreamPlayer = _snd.get(id)
	if p:
		p.pitch_scale = pitch
		p.play()

# ---------------------------------------------------------------- 流程

func _cast() -> void:
	var c := pond_center()
	var a := _rng.randf() * TAU
	var r := sqrt(_rng.randf_range(0.12, 0.7))
	_target = Vector3(c.x + cos(a) * pond_rx * r * 0.85, _water_y(), c.z + sin(a) * pond_rz * r * 0.8 - 0.4)
	_from = _rod_tip()
	_to("cast")
	_play("whoosh")
	_play("tick", 0.7)

func _land() -> void:
	_ripple(_target, 1.0)
	_play("splash")
	_wait = _rng.randf_range(1.8, 4.4)
	_sp = Journal.roll(_rng)
	_cm = Journal.roll_size(_sp, _rng)
	# 最靠近浮標的那條魚影，等一下游過來咬
	_biter = -1
	var best := INF
	for i in _swimmers.size():
		var s: Dictionary = _swimmers[i]
		var d: float = ((s.node as Node3D).global_position - _target).length()
		if String(s.mode) == "loop" and d < best:
			best = d
			_biter = i
	_to("wait")

func _bite() -> void:
	_to("bite")
	_play("bite")
	_ripple(_target, 0.6)
	_say("！", Color("ff7a6a"))

func _hook() -> void:
	var rar := int(_sp.rar)
	_rounds = 1 + (1 if rar >= 2 else 0) + (1 if rar >= 3 else 0)
	_round = 0
	_new_round()
	_to("reel")
	_play("splash", 1.4)

func _new_round() -> void:
	var rar := int(_sp.rar)
	_zone_w = 0.30 - 0.045 * rar
	_zone_c = _rng.randf_range(_zone_w * 0.5 + 0.08, 1.0 - _zone_w * 0.5 - 0.08)
	_speed = 0.8 + 0.2 * rar + 0.12 * _round
	_mark = 0.0 if _rng.randf() < 0.5 else 1.0
	_dir = 1.0 if _mark < 0.5 else -1.0

func _pull() -> void:
	var ok := absf(_mark - _zone_c) <= _zone_w * 0.5
	if ok:
		_flash = 0.25
		_play("tick", 1.4 + 0.2 * _round)
		_ripple(_target, 0.7)
		_round += 1
		if _round >= _rounds:
			_land_fish()
		else:
			_new_round()
	else:
		_flash = -0.3
		_play("miss")
		_say("跑掉了…", Color("ffd0d0"))
		_release_biter()
		_to("fail")

func _land_fish() -> void:
	_result = Journal.caught(_sp, _cm)
	_result["sp"] = _sp
	_result["cm"] = _cm
	_play("catch")
	_to("catch")
	var path: String = Journal.MODELS[String(_sp.model)]
	var len := 0.7 + float(_cm) / 70.0 if _cm > 0 else 0.85
	_fish3d = _model(path, len)
	if _fish3d:
		if String(_sp.kind) == "fish":
			_tint(_fish3d, _sp.col)
		add_child(_fish3d)
		_fish3d.global_position = _target
	_release_biter()
	map._life.puff(_target + Vector3(0, 0.3, 0), Color(0.8, 0.95, 1.0), 14, 4.0, 0.2, -6.0, 0.9)
	map.call("_journal_check")

func _clear_catch() -> void:
	if _fish3d and is_instance_valid(_fish3d):
		map._life.puff(_fish3d.global_position, Color("fff3b0"), 10, 3.0, 0.18, -2.0, 0.8)
		_fish3d.queue_free()
	_fish3d = null

func _release_biter() -> void:
	if _biter >= 0 and _biter < _swimmers.size():
		var s: Dictionary = _swimmers[_biter]
		if String(s.mode) != "loop":
			var rel: Vector3 = (s.node as Node3D).position
			s.a = atan2(rel.z / maxf(float(s.rz), 0.1), rel.x / maxf(float(s.rx), 0.1))
			s.mode = "loop"
			(s.node as Node3D).scale = Vector3.ONE
	_biter = -1

## 水面一圈漣漪
func _ripple(pos: Vector3, size: float) -> void:
	if _ring_tex == null:
		var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
		for y in 64:
			for x in 64:
				var d := Vector2(x - 31.5, y - 31.5).length() / 31.5
				var a := smoothstep(0.55, 0.78, d) * (1.0 - smoothstep(0.86, 1.0, d))
				img.set_pixel(x, y, Color(1, 1, 1, a))
		_ring_tex = ImageTexture.create_from_image(img)
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2.ONE
	mi.mesh = pm
	var m := StandardMaterial3D.new()
	m.albedo_texture = _ring_tex
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.render_priority = 3
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.global_position = Vector3(pos.x, _water_y() + 0.03, pos.z)
	_ripples.append({"node": mi, "mat": m, "t": 0.0, "size": size})

# ---------------------------------------------------------------- 每一格（主島每格都呼叫；沒在釣的時候只動池塘）

func tick(dt: float, t: float) -> void:
	_t = t
	if pond_node == null:
		return
	_tick_pond(dt)
	if active:
		_tick_fishing(dt)

func _tick_pond(dt: float) -> void:
	var c := pond_center()
	for i in _swimmers.size():
		var s: Dictionary = _swimmers[i]
		var n: Node3D = s.node
		var prev := n.position
		var mode := String(s.mode)
		if mode == "loop":
			s.a = float(s.a) + float(s.sp) * dt
			var tgt := Vector3(cos(float(s.a)) * float(s.rx), -0.02, sin(float(s.a)) * float(s.rz))
			n.position = prev.lerp(tgt, 1.0 - exp(-dt * 6.0)) if prev.length() > 0.001 else tgt
		else:
			# 咬鉤：游到浮標旁邊（chase），咬住之後在那裡抖（hold）
			var goal := _target - c + Vector3(0, -0.02, 0)
			var spd := 2.4 if mode == "chase" else 6.0
			n.position = prev.move_toward(goal + (Vector3(sin(_t * 23.0), 0, cos(_t * 19.0)) * 0.12 if mode == "hold" else Vector3.ZERO), spd * dt)
		var d := n.position - prev
		d.y = 0.0
		if d.length() > 0.0005:
			n.rotation.y = lerp_angle(n.rotation.y, atan2(-d.z, d.x), 1.0 - exp(-dt * 10.0))
		n.rotation.z = sin(_t * 6.0 + float(s.ph)) * 0.08
	for l in _lilies:
		var ln: Node3D = l.node
		ln.position = (l.base as Vector3) + Vector3(sin(_t * 0.3 + float(l.ph)) * 0.25, sin(_t * 1.1 + float(l.ph)) * 0.008, cos(_t * 0.25 + float(l.ph)) * 0.2)
	for i in range(_ripples.size() - 1, -1, -1):
		var r: Dictionary = _ripples[i]
		r.t = float(r.t) + dt
		var k: float = float(r.t) / 1.1
		if k >= 1.0:
			(r.node as Node3D).queue_free()
			_ripples.remove_at(i)
			continue
		(r.node as Node3D).scale = Vector3.ONE * (0.4 + 2.2 * k) * float(r.size)
		(r.mat as StandardMaterial3D).albedo_color = Color(1, 1, 1, 1.0 - k)

func _tick_fishing(dt: float) -> void:
	_st += dt
	_flash = move_toward(_flash, 0.0, dt)
	var tip := _rod_tip()
	var bob_pos := tip + Vector3(0, -1.0, 0)
	match state:
		"aim":
			bob_pos = tip + Vector3(sin(_t * 2.0) * 0.08, -1.1 + sin(_t * 3.0) * 0.04, 0.05)
		"cast":
			var k := minf(_st / 0.6, 1.0)
			bob_pos = _from.lerp(_target, k) + Vector3(0, sin(k * PI) * 2.4, 0)
			if k >= 1.0:
				_land()
		"wait":
			bob_pos = _target + Vector3(0, sin(_t * 2.6) * 0.025, 0)
			if _biter >= 0 and _st > _wait - 1.2 and String(_swimmers[_biter].mode) == "loop":
				_swimmers[_biter].mode = "chase"
				(_swimmers[_biter].node as Node3D).scale = Vector3.ONE * clampf(0.55 + float(_cm) / 90.0, 0.7, 1.5)
			if _st >= _wait:
				if _biter >= 0:
					_swimmers[_biter].mode = "hold"
				_bite()
		"bite":
			bob_pos = _target + Vector3(0, -0.16 * absf(sin(_st * 14.0)), 0)
			if fmod(_st, 0.28) < dt:
				_ripple(_target, 0.5)
			if _st >= BITE_WINDOW:
				_say("跑掉了…", Color("ffd0d0"))
				_play("miss")
				_release_biter()
				_to("fail")
		"reel":
			bob_pos = _target + Vector3(sin(_t * 31.0) * 0.07, -0.08 + sin(_t * 17.0) * 0.05, cos(_t * 27.0) * 0.07)
			_mark += _dir * _speed * dt
			if _mark >= 1.0:
				_mark = 1.0
				_dir = -1.0
			elif _mark <= 0.0:
				_mark = 0.0
				_dir = 1.0
			if fmod(_st, 0.22) < dt:
				_ripple(_target, 0.4)
		"catch":
			var k2 := minf(_st / 0.9, 1.0)
			var hp: Vector3 = (map._hero as Node3D).global_position
			var hold := hp + Vector3(0, 3.6, -1.2)
			bob_pos = tip + Vector3(0, -1.0, 0)
			if _fish3d and is_instance_valid(_fish3d):
				var e := k2 * k2 * (3.0 - 2.0 * k2)
				_fish3d.global_position = _target.lerp(hold, e) + Vector3(0, sin(k2 * PI) * 2.0, 0)
				_fish3d.rotation.y += dt * (14.0 * (1.0 - k2) + 1.6)
				_fish3d.rotation.z = sin(_t * 8.0) * 0.15 * (1.0 - k2)
		"fail":
			bob_pos = tip + Vector3(0, -1.0, 0)
			if _st > 0.7:
				_to("aim")
	if _bob:
		_bob.global_position = bob_pos
	_set_line(tip, bob_pos)
	_ui.queue_redraw()

func _set_line(a: Vector3, b: Vector3) -> void:
	if _line == null:
		return
	var d := b - a
	var len := d.length()
	if len < 0.02:
		_line.visible = false
		return
	_line.visible = true
	var y := d / len
	var x := y.cross(Vector3.RIGHT if absf(y.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD).normalized()
	var z := x.cross(y)
	_line.global_transform = Transform3D(Basis(x, y * len, z), (a + b) * 0.5)

# ---------------------------------------------------------------- 畫面

func _paint(c: Control) -> void:
	if not active:
		return
	var vs := c.size
	var u := HubUI.scale_of(vs)
	var items: Array = []
	match state:
		"aim":
			items = [[["Space"], "甩竿"], [["Esc"], "收竿"]]
		"wait":
			items = [[["Space"], "收線"], [["Esc"], "收竿"]]
		"bite":
			items = [[["Space"], "拉鉤！"]]
		"reel":
			items = [[["Space"], "拉線"]]
		"catch":
			items = [[["Space"], "繼續"], [["Esc"], "收竿"]]
		_:
			items = [[["Esc"], "收竿"]]
	HubUI.key_strip(c, u, items)
	var cam: Camera3D = map._cam
	var hp: Vector3 = (map._hero as Node3D).global_position + Vector3(0, 2.6, 0)
	var hs := cam.unproject_position(hp) if not cam.is_position_behind(hp) else vs * 0.5
	match state:
		"aim":
			_hint_bubble(c, u, hs, "甩竿", "Space")
		"wait":
			var dots := "・".repeat(1 + int(_t * 2.0) % 3)
			var r := HubUI.bubble(c, hs + Vector2(0, -70 * u), Vector2(150, 64) * u, hs + Vector2(0, -26 * u), u)
			HubUI.text_c(c, r.get_center() + Vector2(0, -2 * u), dots, 34 * u, HubUI.INK)
		"bite":
			var bp := cam.unproject_position(_target + Vector3(0, 1.2, 0)) if not cam.is_position_behind(_target) else hs
			var pulse := 1.0 + 0.12 * sin(_t * 22.0)
			var rr := 46.0 * u * pulse
			c.draw_circle(bp + Vector2(0, 4 * u), rr + 5 * u, Color(0, 0, 0, 0.25))
			c.draw_circle(bp, rr + 4 * u, Color.WHITE)
			c.draw_circle(bp, rr, HubUI.RED)
			HubUI.text_c(c, bp, "！", 60 * u, Color.WHITE)
			var left := 1.0 - _st / BITE_WINDOW
			c.draw_arc(bp, rr + 12 * u, -PI * 0.5, -PI * 0.5 + TAU * left, 32, Color("ffe27a"), 6 * u, true)
		"reel":
			_paint_reel(c, u, vs)
		"catch":
			if _st > 0.7:
				_paint_card(c, u, vs)

func _hint_bubble(c: Control, u: float, hs: Vector2, label: String, key: String) -> void:
	var ks := UIStyle.keycap_size(key, 18 * u)
	var w := HubUI.text_w(label, 28 * u) + ks.x + 56 * u
	var r := HubUI.bubble(c, hs + Vector2(0, -74 * u), Vector2(w, 66 * u), hs + Vector2(0, -26 * u), u)
	HubUI.text(c, Vector2(r.position.x + 22 * u, r.get_center().y + 10 * u), label, 28 * u, HubUI.INK)
	UIStyle.draw_keycap(c, Vector2(r.end.x - 18 * u - ks.x, r.get_center().y - ks.y * 0.5), key, 18 * u)

func _paint_reel(c: Control, u: float, vs: Vector2) -> void:
	var bar := Rect2(Vector2(vs.x * 0.5 - 300 * u, vs.y - 78 * u), Vector2(600, 44) * u)
	var panel := Rect2(bar.position - Vector2(28, 52) * u, bar.size + Vector2(56, 74) * u)
	c.draw_style_box(HubUI.box(Color(HubUI.PAPER, 0.96), HubUI.PAPER_EDGE, 24 * u, 3.0), panel)
	HubUI.text(c, Vector2(panel.position.x + 28 * u, panel.position.y + 36 * u), "拉！在綠色裡按 Space", 24 * u, HubUI.INK)
	# 第幾次拉（小圓點）
	for i in _rounds:
		var cc := Vector2(panel.end.x - 38 * u - (_rounds - 1 - i) * 30 * u, panel.position.y + 28 * u)
		c.draw_circle(cc, 11 * u, HubUI.GREEN if i < _round else Color("e2dccb"))
		c.draw_arc(cc, 11 * u, 0, TAU, 20, HubUI.PAPER_EDGE, 2.5 * u, true)
	# 條
	c.draw_style_box(HubUI.box(Color("5aa6d6"), Color("2c5d8a"), 24 * u, 3.0, false), bar)
	var zr := Rect2(Vector2(bar.position.x + (_zone_c - _zone_w * 0.5) * bar.size.x, bar.position.y + 5 * u), Vector2(_zone_w * bar.size.x, bar.size.y - 10 * u))
	c.draw_style_box(HubUI.box(Color("6fd36a"), Color("2f7a2f"), 16 * u, 3.0, false), zr)
	var mx := bar.position.x + _mark * bar.size.x
	var col := Color.WHITE
	if _flash > 0.0:
		col = Color("b8ffb0")
	elif _flash < 0.0:
		col = Color("ff9a9a")
	c.draw_line(Vector2(mx, bar.position.y - 8 * u), Vector2(mx, bar.end.y + 8 * u), HubUI.INK, 10 * u, true)
	c.draw_line(Vector2(mx, bar.position.y - 6 * u), Vector2(mx, bar.end.y + 6 * u), col, 5 * u, true)
	c.draw_colored_polygon(PackedVector2Array([Vector2(mx - 12 * u, bar.position.y - 18 * u), Vector2(mx + 12 * u, bar.position.y - 18 * u), Vector2(mx, bar.position.y - 4 * u)]), col)

func _paint_card(c: Control, u: float, vs: Vector2) -> void:
	var sp: Dictionary = _result.sp
	var k := clampf((_st - 0.7) / 0.3, 0.0, 1.0)
	var s := 0.7 + 0.3 * (1.0 - pow(1.0 - k, 3.0))
	var size := Vector2(620, 290) * u * s
	var r := Rect2(Vector2(vs.x * 0.5, vs.y * 0.34) - size * 0.5, size)
	c.draw_style_box(HubUI.box(HubUI.PAPER, HubUI.PAPER_EDGE, 30 * u * s, 3.0), r)
	var uu := u * s
	var kind := String(sp.kind)
	var icon_c := r.position + Vector2(130, 130) * uu
	c.draw_circle(icon_c, 92 * uu, Color("e4f3fb"))
	c.draw_arc(icon_c, 92 * uu, 0, TAU, 40, Color("9cc9e2"), 3 * uu, true)
	if kind == "fish":
		HubUI.fish_icon(c, icon_c, 150 * uu, sp.col)
	elif String(sp.id) == "star":
		HubUI.star(c, icon_c, 56 * uu, HubUI.GOLD, HubUI.GOLD_EDGE)
	else:
		HubUI.text_c(c, icon_c, "蕉" if String(sp.id) == "peel" else "桶", 84 * uu, HubUI.INK)
	var tx := r.position.x + 250 * uu
	var nm := String(sp.name)
	HubUI.text(c, Vector2(tx, r.position.y + 78 * uu), nm, HubUI.fit(nm, 46 * uu, r.end.x - tx - 24 * uu), HubUI.INK)
	if int(_result.cm) > 0:
		HubUI.text(c, Vector2(tx, r.position.y + 124 * uu), "%d 公分" % int(_result.cm), 30 * uu, Color("3c7d3c"))
	var y := r.position.y + 164 * uu
	for line in HubUI.wrap(String(sp.line), 23 * uu, r.end.x - tx - 24 * uu):
		HubUI.text(c, Vector2(tx, y), line, 23 * uu, Color("6f6a60"))
		y += 30 * uu
	if bool(_result.new):
		HubUI.tag(c, r.position + Vector2(r.size.x - 96 * uu, 20 * uu), "新發現！", 24 * uu, HubUI.RED, Color("8f231c"))
	elif bool(_result.record):
		HubUI.tag(c, r.position + Vector2(r.size.x - 96 * uu, 20 * uu), "新紀錄！", 24 * uu, Color("e3a31c"), Color("8a6410"))
	if _st > 1.2:
		var ks := UIStyle.keycap_size("Space", 16 * uu)
		var label := "繼續釣"
		var lw := HubUI.text_w(label, 22 * uu)
		var x := r.get_center().x - (lw + ks.x + 10 * uu) * 0.5
		HubUI.text(c, Vector2(x, r.end.y - 22 * uu), label, 22 * uu, HubUI.INK)
		UIStyle.draw_keycap(c, Vector2(x + lw + 10 * uu, r.end.y - 22 * uu - ks.y * 0.72), "Space", 16 * uu)
