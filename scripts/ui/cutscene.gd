extends Node3D
## 過場動畫的底層：開場（scripts/intro.gd）和結局（levels/heaven/ending/ending.gd）共用。
##
## 這裡管的事：對話框和打字、一句一句往下走、切鏡頭時的淡出淡入、運鏡、角色的動作、
## 頭上的狀聲字、音效和配樂（都是程式合成的，沒有音效檔）、農場外景（兩邊的「屋頂」鏡頭是同一個景）。
##
## 操作：Enter / 空白鍵 / 滑鼠左鍵 下一句（字還在打就先整句顯示）；Esc 跳過整段。
## 沒有台詞的那幾拍（"hold" 秒）自己會往下走，按 Enter 是快轉。
##
## 子類別要寫的：
##   _lines()            台詞表：[{"shot": 鏡頭, "who": 誰, "text": 台詞, "cue": 這一句要演什麼, "hold": 沒台詞時停幾秒}]
##   _build()            蓋場景、放角色
##   _enter_shot(shot)   換到這個鏡頭時：擺位置、換光
##   _on_line(line)      每一句開始時：運鏡、動作（照 line.cue 分）
##   _tick(dt)           每一畫面要自己動的東西
##   _next_scene()       播完去哪個場景

const UIStyle := preload("res://scripts/ui/ui_style.gd")   # 全遊戲共用的介面美術
const LoadingCard := preload("res://scripts/ui/loading_card.gd")   # 換場景時的「載入中」
const TYPE_SPEED := 30.0        # 每秒打幾個字
const RATE := 22050             # 合成音效的取樣率
const FARM := "res://assets/farm/"
const NATURE := "res://assets/nature/"
const PEEL := "res://levels/ice/assets/blender/banana_peel.glb"
const CLOUDS := "res://levels/ice/assets/blender/cloud_puff_%s.glb"

var _chars: Node
var _cam: Camera3D
var _env_node: WorldEnvironment
var _sun: DirectionalLight3D

var _script: Array = []
var _i := -1
var _line: Dictionary = {}
var _shot := ""
var _shot_t := 0.0              # 這個鏡頭播了幾秒
var _line_t := 0.0              # 這一句播了幾秒
var _t := 0.0
var _hold := -1.0
var _shown := 0.0
var _typing := false
var _busy := false
var _leaving := false
var _blip_n := 0

var _tweens: Array = []
var _actors: Array = []
var _emotes: Array = []
var _spin: Array = []           # 一直轉的東西 {node, axis, speed}

# 運鏡
var _cam_a := {"p": Vector3(0, 2, 6), "l": Vector3.ZERO, "f": 45.0}
var _cam_b := {"p": Vector3(0, 2, 6), "l": Vector3.ZERO, "f": 45.0}
var _cam_k := 1.0
var _cam_dur := 0.0
var _cam_drift := Vector3.ZERO
var _cam_drift_t := 0.0
var _shake := 0.0

# 介面
var _layer: CanvasLayer
var _fade: ColorRect
var _dlg: PanelContainer
var _name: Label
var _text: Label
var _arrow: Label
var _stamp_label: Label
var _hint_next: Control
var _bars: Array = []

# 聲音
var _snd := {}
var _voices: Array = []
var _voice_i := 0
var _music: AudioStreamPlayer
var _music_db := -10.0

# ================================================================== 子類別覆寫

func _lines() -> Array:
	return []

func _build() -> void:
	pass

func _enter_shot(_s: String) -> void:
	pass

func _on_line(_l: Dictionary) -> void:
	pass

func _tick(_dt: float) -> void:
	pass

func _next_scene() -> String:
	return "res://scenes/level_select.tscn"

func _skip_text() -> String:
	return "跳過"

## 這個人講話時的「嘟嘟」聲多高（0＝不出聲）
func _voice_pitch(who: String) -> float:
	match who:
		"家豪": return 0.78
		"神明", "？？？": return 1.5
		"公雞": return 1.05
		"陸吾": return 0.56
		"阿水": return 0.9
	return 0.0

## 這一句是誰在講（回傳角色，講話時頭會跟著動）
func _actor_of(_who: String) -> Dictionary:
	return {}

# ================================================================== 啟動

func _ready() -> void:
	_chars = Node3D.new()
	_chars.set_script(load("res://scripts/characters.gd"))
	add_child(_chars)
	_chars.set_process(false)       # 角色的動作都由這裡管，不用共用的待機動畫
	_cam = Camera3D.new()
	add_child(_cam)
	_cam.current = true
	_build_ui()
	_make_base_sounds()
	_build()
	if _env_node == null:
		_env_node = get_node_or_null("WorldEnvironment") as WorldEnvironment
		if _env_node == null:
			_env_node = WorldEnvironment.new()
			add_child(_env_node)
	if _sun == null:
		_sun = DirectionalLight3D.new()
		_sun.shadow_enabled = true
		_sun.directional_shadow_max_distance = 60.0
		add_child(_sun)
	_script = _lines()
	_fade.color = Color(0, 0, 0, 1)
	_next()
	var args := OS.get_cmdline_user_args()
	for a in args:
		if a.begins_with("--cutshots="):
			_cutshots.call_deferred(a.substr(11))
			return
	if "--autotest" in args:
		_autotest.call_deferred()

# ================================================================== 材質和小零件

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

func _tex_mat(path: String, tile: float, tint := Color.WHITE) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(path) as Texture2D
	m.albedo_color = tint
	m.uv1_scale = Vector3(tile, tile, 1)
	m.roughness = 1.0
	m.metallic_specular = 0.0
	return m

func _mesh(parent: Node3D, mesh: Mesh, pos: Vector3, mat: Material, rot := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.scale = scl
	parent.add_child(mi)
	return mi

func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var bm := BoxMesh.new()
	bm.size = size
	return _mesh(parent, bm, pos, mat, rot)

func _ball(parent: Node3D, r: float, pos: Vector3, mat: Material, scl := Vector3.ONE, seg := 14) -> MeshInstance3D:
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = seg
	sm.rings = maxi(seg / 2, 4)
	return _mesh(parent, sm, pos, mat, Vector3.ZERO, scl)

func _cyl(parent: Node3D, r_top: float, r_bot: float, h: float, pos: Vector3, mat: Material, rot := Vector3.ZERO, seg := 20) -> MeshInstance3D:
	var cm := CylinderMesh.new()
	cm.top_radius = r_top
	cm.bottom_radius = r_bot
	cm.height = h
	cm.radial_segments = seg
	return _mesh(parent, cm, pos, mat, rot)

func _torus(parent: Node3D, r_in: float, r_out: float, pos: Vector3, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var tm := TorusMesh.new()
	tm.inner_radius = r_in
	tm.outer_radius = r_out
	tm.rings = 40
	tm.ring_segments = 10
	return _mesh(parent, tm, pos, mat, rot)

## 載入一個模型（.glb）放進場景
func _glb(parent: Node3D, path: String, pos: Vector3, yaw := 0.0, scl := 1.0) -> Node3D:
	var ps := load(path) as PackedScene
	if ps == null:
		return null
	var n := ps.instantiate() as Node3D
	parent.add_child(n)
	n.position = pos
	n.rotation.y = yaw
	n.scale = Vector3.ONE * scl
	return n

## 把模型底下所有網格換成同一個材質
func _paint(n: Node, mat: Material) -> void:
	if n == null:
		return
	for m in n.find_children("*", "MeshInstance3D", true, false):
		(m as MeshInstance3D).material_override = mat
	if n is MeshInstance3D:
		(n as MeshInstance3D).material_override = mat

func _no_shadow(n: Node) -> void:
	if n == null:
		return
	for m in n.find_children("*", "GeometryInstance3D", true, false):
		(m as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if n is GeometryInstance3D:
		(n as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

## 模型在 (x, z) 這個位置最高的地方有多高（站上屋頂用）。模型要已經在場景裡
func _top_y(n: Node3D, x: float, z: float) -> float:
	var best := -1000.0
	var list: Array = n.find_children("*", "MeshInstance3D", true, false)
	if n is MeshInstance3D:
		list.append(n)
	for m in list:
		var mi := m as MeshInstance3D
		if mi.mesh == null:
			continue
		var xf := mi.global_transform
		var faces := mi.mesh.get_faces()
		for k in range(0, faces.size() - 2, 3):
			var a: Vector3 = xf * faces[k]
			var b: Vector3 = xf * faces[k + 1]
			var c: Vector3 = xf * faces[k + 2]
			var d := (b.z - c.z) * (a.x - c.x) + (c.x - b.x) * (a.z - c.z)
			if absf(d) < 0.000001:
				continue
			var w0 := ((b.z - c.z) * (x - c.x) + (c.x - b.x) * (z - c.z)) / d
			var w1 := ((c.z - a.z) * (x - c.x) + (a.x - c.x) * (z - c.z)) / d
			var w2 := 1.0 - w0 - w1
			if w0 < 0.0 or w1 < 0.0 or w2 < 0.0:
				continue
			best = maxf(best, a.y * w0 + b.y * w1 + c.y * w2)
	return best

func _label3d(text: String, size: int, color: Color, outline := 14) -> Label3D:
	var l := Label3D.new()
	l.text = text
	if UIStyle.font():
		l.font = UIStyle.font()
	l.font_size = size
	l.pixel_size = 0.004
	l.modulate = color
	l.outline_size = outline
	l.outline_modulate = Color(0.16, 0.10, 0.07)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return l

## 雞腳上的號碼牌：黃色的塑膠牌、黑色號碼、一圈扣環。torn＝扯斷的（扣環只剩半圈）
func _foot_tag(num: String, torn := false) -> Node3D:
	var n := Node3D.new()
	var yellow := _toon(Color(0.98, 0.80, 0.16))
	_box(n, Vector3(0.20, 0.14, 0.018), Vector3(0, 0, 0), yellow)
	_box(n, Vector3(0.21, 0.02, 0.022), Vector3(0, 0.06, 0), _toon(Color(0.86, 0.62, 0.08)))
	for side in [1.0, -1.0]:
		var l := Label3D.new()
		l.text = num
		if UIStyle.font():
			l.font = UIStyle.font()
		l.font_size = 64
		l.pixel_size = 0.0016
		l.modulate = Color(0.12, 0.10, 0.08)
		l.outline_size = 0
		l.position = Vector3(0, -0.012, 0.011 * side)
		l.rotation.y = 0.0 if side > 0.0 else PI
		l.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		n.add_child(l)
	# 扣環：整圈或扯斷的半圈
	var ring := Node3D.new()
	ring.name = "Ring"
	ring.position = Vector3(0, 0.12, 0)
	n.add_child(ring)
	var seg := 7 if torn else 12
	for k in seg:
		var a := TAU * float(k) / 12.0 + (0.5 if torn else 0.0)
		_ball(ring, 0.014, Vector3(cos(a) * 0.055, sin(a) * 0.055, 0), yellow, Vector3.ONE, 6)
	return n

## 家豪自己腳上的號碼牌（六十七號）
func _leg_tag(a: Dictionary, num: String) -> Node3D:
	var tag := _foot_tag(num)
	(a.body as Node3D).add_child(tag)
	tag.position = Vector3(0.105, 0.085, 0.045)
	tag.rotation = Vector3(-0.1, 0.25, 0.0)
	tag.scale = Vector3.ONE * 0.3
	return tag

func _peel(parent: Node3D, pos: Vector3, scl := 0.9) -> Node3D:
	return _glb(parent, PEEL, pos, 0.6, scl)

# ================================================================== 光和天空

## 做一個天空：上面、地平線兩個顏色；amb 是環境光
func _make_env(top: Color, horizon: Color, amb: Color, amb_e: float, fog: Color, fog_d: float, glow := 0.5) -> Environment:
	var e := Environment.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = top
	sm.sky_horizon_color = horizon
	sm.sky_curve = 0.12
	sm.ground_bottom_color = horizon.darkened(0.35)
	sm.ground_horizon_color = horizon
	sm.sun_angle_max = 0.0
	var sky := Sky.new()
	sky.sky_material = sm
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = amb
	e.ambient_light_energy = amb_e
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.tonemap_white = 4.0
	e.ssao_enabled = true
	e.ssao_radius = 0.8
	e.fog_enabled = fog_d > 0.0
	e.fog_light_color = fog
	e.fog_density = fog_d
	e.fog_sky_affect = 0.0
	e.glow_enabled = glow > 0.0
	e.glow_intensity = glow
	e.glow_bloom = 0.1
	e.glow_hdr_threshold = 0.9
	e.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	e.adjustment_enabled = true
	e.adjustment_saturation = 1.15
	return e

func _light(env: Environment, sun_c: Color, sun_e: float, sun_rot: Vector3) -> void:
	_env_node.environment = env
	_sun.visible = sun_e > 0.0
	_sun.light_color = sun_c
	_sun.light_energy = sun_e
	_sun.rotation = sun_rot

# ================================================================== 角色

## kind："hero" 家豪、"rooster" 公雞、"hen" 圓滾滾的雞、"chick" 小雞
func _actor(parent: Node3D, kind: String, pos: Vector3, yaw := 0.0, scl := 1.0) -> Dictionary:
	var n: Node3D
	match kind:
		"hero":
			n = _chars._make_standin_rooster(true)
		"rooster":
			n = _chars._make_standin_rooster(false)
		_:
			n = _chars._make_round_chicken(false)
	parent.add_child(n)
	if kind == "chick":
		scl *= 0.42
	n.scale *= scl
	n.position = pos
	n.rotation.y = yaw
	var a := {
		"kind": kind, "node": n, "body": n.get_node("Body"),
		"head": n.find_child("Head", true, false), "wl": n.find_child("WingL", true, false), "wr": n.find_child("WingR", true, false),
		"anim": "idle", "ph": float(_actors.size()) * 1.618, "look": null, "talk": 0.0, "beat": 9.0, "amp": 1.0,
		"v": {"by": 0.0, "brx": 0.0, "bry": 0.0, "brz": 0.0, "hrx": 0.0, "hry": 0.0, "hrz": 0.0, "wlx": 0.0, "wlz": 0.0, "wrx": 0.0, "wrz": 0.0, "sy": 1.0},
	}
	_actors.append(a)
	return a

func _set_anim(a: Dictionary, anim: String, amp := 1.0) -> void:
	if a.is_empty():
		return
	a.anim = anim
	a.amp = amp

## 面向某個點（整隻轉過去）
func _face(a: Dictionary, target: Vector3, dur := 0.0) -> void:
	var n := a.node as Node3D
	var d := target - n.global_position
	var yaw := atan2(d.x, d.z)
	if dur <= 0.0:
		n.rotation.y = yaw
	else:
		var from := n.rotation.y
		yaw = from + wrapf(yaw - from, -PI, PI)
		_tw().tween_property(n, "rotation:y", yaw, dur).set_trans(Tween.TRANS_SINE)

## 用走的過去（一搖一擺）
func _walk(a: Dictionary, to: Vector3, dur: float, then := "idle") -> void:
	var n := a.node as Node3D
	_face(a, to)
	a.anim = "walk"
	var tw := _tw()
	tw.tween_property(n, "position", to, dur)
	tw.tween_callback(func(): a.anim = then)

## 用跳的過去（拋物線）
func _hop(a: Dictionary, to: Vector3, dur: float, h := 1.0, delay := 0.0, then := "") -> void:
	var n := a.node as Node3D
	var tw := _tw()
	if delay > 0.0:
		tw.tween_interval(delay)
	var from_box := [n.position]
	tw.tween_callback(func(): from_box[0] = n.position)
	var arc := func(k: float) -> void:
		var p: Vector3 = (from_box[0] as Vector3).lerp(to, k)
		p.y += sin(k * PI) * h
		n.position = p
	tw.tween_method(arc, 0.0, 1.0, dur)
	if then != "":
		tw.tween_callback(func(): a.anim = then)

func _animate(a: Dictionary, dt: float) -> void:
	if String(a.anim) == "freeze":
		return                      # 定格：停在現在的姿勢
	var t: float = _t + float(a.ph)
	var amp: float = a.amp
	var g := {"by": absf(sin(t * 2.2)) * 0.012, "brx": 0.0, "bry": 0.0, "brz": 0.0, "hrx": sin(t * 1.3) * 0.05, "hry": 0.0, "hrz": 0.0,
		"wlx": 0.0, "wlz": 0.0, "wrx": 0.0, "wrz": 0.0, "sy": 1.0}
	var rate := 10.0
	var bt: float = _t * float(a.beat)
	match String(a.anim):
		"idle":
			g.hry = sin(t * 0.7) * 0.25
		"still":
			g.by = 0.0
			g.hrx = 0.0
		"dj":
			# 打碟：一隻翅膀在前面搓，另一隻按著耳朵，身體跟著拍子晃
			rate = 22.0
			g.by = absf(sin(bt)) * 0.05 * amp
			g.brz = sin(bt) * 0.12 * amp
			g.bry = sin(bt * 0.5) * 0.3 * amp
			g.brx = 0.16
			g.hrx = 0.14 + sin(bt * 2.0) * 0.12 * amp
			g.hry = sin(bt * 0.5) * 0.2
			g.wrx = -1.15 + sin(bt * 2.0) * 0.5 * amp
			g.wrz = 0.25
			g.wlz = -2.15 + sin(bt) * 0.08
			g.wlx = -0.2
		"dj_big":
			# 越搓越誇張：兩隻翅膀輪流搓、轉圈
			rate = 22.0
			g.by = absf(sin(bt)) * 0.09
			g.brz = sin(bt) * 0.2
			g.bry = sin(bt * 0.25) * 1.2
			g.brx = 0.2
			g.hrx = 0.1 + sin(bt * 2.0) * 0.2
			g.wrx = -1.2 + sin(bt * 2.0) * 0.7
			g.wlx = -1.2 + sin(bt * 2.0 + PI) * 0.7
			g.wrz = 0.3
			g.wlz = -0.3
		"cool":
			# 耍帥：一隻翅膀拉著帽沿，頭低下來
			g.by = 0.0
			g.hrx = 0.28
			g.hry = 0.25
			g.wlz = -2.0
			g.wlx = -0.5
			g.brz = -0.06
		"sad":
			g.by = 0.0
			g.brx = 0.14
			g.hrx = 0.42
			g.sy = 0.96
		"lookup":
			g.hrx = -0.5
			g.brx = -0.12
			g.hry = sin(t * 0.9) * 0.1
		"shake":
			rate = 18.0
			g.hry = sin(_t * 10.0) * 0.5
			g.hrx = 0.05
		"nod":
			rate = 16.0
			g.hrx = 0.12 + absf(sin(_t * 6.0)) * 0.3
		"yell":
			# 對著上面喊：身體往後仰、翅膀張開、一下一下地跳
			rate = 16.0
			g.brx = -0.22
			g.hrx = -0.45
			g.by = absf(sin(_t * 9.0)) * 0.05
			g.wlz = -0.9 - sin(_t * 9.0) * 0.3
			g.wrz = 0.9 + sin(_t * 9.0) * 0.3
		"flap":
			rate = 26.0
			g.wlz = -1.2 - sin(_t * 22.0) * 0.8
			g.wrz = 1.2 + sin(_t * 22.0) * 0.8
			g.by = absf(sin(_t * 11.0)) * 0.04
		"fly":
			rate = 16.0
			g.wlz = -1.25 - sin(_t * 7.5) * 0.85
			g.wrz = 1.25 + sin(_t * 7.5) * 0.85
			g.brx = -0.18
			g.by = sin(_t * 7.5 + 1.2) * 0.05
			g.hrx = 0.1
		"glide":
			g.wlz = -1.5 + sin(_t * 2.0) * 0.06
			g.wrz = 1.5 - sin(_t * 2.0) * 0.06
			g.brx = 0.2
			g.hrx = -0.1
		"walk":
			rate = 20.0
			g.by = absf(sin(_t * 11.0)) * 0.035
			g.brz = sin(_t * 11.0) * 0.11
			g.hrx = sin(_t * 22.0) * 0.06
		"shock":
			rate = 30.0
			g.sy = 1.12
			g.brx = -0.2
			g.hrx = -0.3
			g.wlz = -1.3
			g.wrz = 1.3
			g.by = 0.03
		"peck":
			rate = 14.0
			var pk := pow(maxf(sin(t * 2.6), 0.0), 6.0)
			g.brx = pk * 0.55
			g.hrx = pk * 0.5
		"sleep":
			g.by = 0.0
			g.hrx = 0.3
			g.sy = 1.0 + sin(t * 1.4) * 0.025
		"point":
			# 用翅膀指自己：「我？」
			g.wrx = -1.5
			g.wrz = -0.5
			g.hrz = 0.3
			g.hrx = -0.1
		"shrug":
			g.wlz = -0.8
			g.wrz = 0.8
			g.hrz = 0.2
			g.by = 0.02
		"cower":
			g.sy = 0.9
			g.brx = 0.25
			g.hrx = 0.35
			g.wlz = -0.35
			g.wrz = 0.35
			g.by = sin(_t * 30.0) * 0.004
	# 看著某個點：頭轉過去
	if a.look is Vector3:
		var n := a.node as Node3D
		var d: Vector3 = (a.look as Vector3) - (n.global_position + Vector3(0, 1.0, 0))
		var yaw := wrapf(atan2(d.x, d.z) - n.global_rotation.y, -PI, PI)
		g.hry = clampf(yaw, -1.1, 1.1)
		g.hrx += clampf(-atan2(d.y, Vector2(d.x, d.z).length()), -0.7, 0.6)
	# 講話：頭一點一點的
	var talk: float = a.talk
	if talk > 0.01:
		g.hrx += sin(_t * 15.0) * 0.09 * talk
		g.by += absf(sin(_t * 7.5)) * 0.018 * talk
		g.sy = float(g.sy) + sin(_t * 15.0) * 0.012 * talk
	var v: Dictionary = a.v
	var k := 1.0 - exp(-dt * rate)
	for key in g:
		v[key] = lerpf(float(v[key]), float(g[key]), k)
	var body := a.body as Node3D
	body.position.y = v.by
	body.rotation = Vector3(v.brx, v.bry, v.brz)
	body.scale = Vector3(2.0 - float(v.sy), v.sy, 2.0 - float(v.sy)) if absf(float(v.sy) - 1.0) > 0.001 else Vector3.ONE
	var head := a.head as Node3D
	if head:
		head.rotation = Vector3(v.hrx, v.hry, v.hrz)
	var wl := a.wl as Node3D
	var wr := a.wr as Node3D
	if wl:
		wl.rotation = Vector3(v.wlx, 0, v.wlz)
	if wr:
		wr.rotation = Vector3(v.wrx, 0, v.wrz)

## 頭上冒出來的字（？、！、♪、Zzz…）。who 可以是角色，也可以直接給位置
func _emote(who, text: String, color := Color(1, 1, 1), dur := 1.3, size := 1.0, rise := 0.5) -> Label3D:
	var l := _label3d(text, int(72 * size), color)
	add_child(l)
	var base: Vector3
	if who is Dictionary:
		var n := (who as Dictionary).node as Node3D
		base = n.global_position + Vector3(0, 1.25 * n.scale.y + 0.3, 0)
	else:
		base = who
	l.global_position = base
	_emotes.append({"node": l, "t": 0.0, "dur": dur, "base": base, "rise": rise, "who": who})
	return l

func _update_emotes(dt: float) -> void:
	for i in range(_emotes.size() - 1, -1, -1):
		var e: Dictionary = _emotes[i]
		var l := e.node as Label3D
		if not is_instance_valid(l):
			_emotes.remove_at(i)
			continue
		e.t = float(e.t) + dt
		var k: float = float(e.t) / float(e.dur)
		if k >= 1.0:
			l.queue_free()
			_emotes.remove_at(i)
			continue
		var pop := 1.0 + 0.35 * maxf(1.0 - float(e.t) / 0.18, 0.0)
		l.scale = Vector3.ONE * pop * minf(float(e.t) / 0.08, 1.0)
		var base: Vector3 = e.base
		if e.who is Dictionary:
			var n := (e.who as Dictionary).node as Node3D
			if is_instance_valid(n):
				base = n.global_position + Vector3(0, 1.25 * n.scale.y + 0.3, 0)
		l.global_position = base + Vector3(0, float(e.rise) * k, 0)
		l.modulate.a = clampf((1.0 - k) / 0.3, 0.0, 1.0)
		l.outline_modulate.a = l.modulate.a

# ================================================================== 運鏡

## 把鏡頭擺到 pos、看 look。dur > 0 是慢慢移過去；drift 是之後每秒再飄多少（很慢的推軌）
func _shot_cam(pos: Vector3, look: Vector3, fov := 45.0, dur := 0.0, drift := Vector3.ZERO) -> void:
	_cam_a = _cam_now()
	_cam_b = {"p": pos, "l": look, "f": fov}
	_cam_dur = dur
	_cam_k = 0.0 if dur > 0.0 else 1.0
	_cam_drift = drift
	_cam_drift_t = 0.0
	_update_cam(0.0)

func _cam_now() -> Dictionary:
	var e := _ease(_cam_k)
	var p: Vector3 = (_cam_a.p as Vector3).lerp(_cam_b.p, e) + _cam_drift * minf(_cam_drift_t, 12.0)
	return {"p": p, "l": (_cam_a.l as Vector3).lerp(_cam_b.l, e), "f": lerpf(_cam_a.f, _cam_b.f, e)}

func _ease(k: float) -> float:
	return k * k * (3.0 - 2.0 * k)

func _update_cam(dt: float) -> void:
	if _cam_k < 1.0 and _cam_dur > 0.0:
		_cam_k = minf(_cam_k + dt / _cam_dur, 1.0)
	_cam_drift_t += dt
	_shake = maxf(_shake - dt * 1.6, 0.0)
	var c := _cam_now()
	var p: Vector3 = c.p
	var l: Vector3 = c.l
	if _shake > 0.0:
		p += Vector3(sin(_t * 71.0), sin(_t * 93.0 + 1.0), 0) * 0.06 * _shake
	if p.distance_to(l) > 0.01:
		_cam.global_position = p
		_cam.look_at(l, Vector3.UP)
	_cam.fov = c.f

# ================================================================== 時間軸上的小工具

func _tw() -> Tween:
	var t := create_tween()
	_tweens.append(t)
	return t

## 這一句開始後第 sec 秒做一件事
func _at(sec: float, c: Callable) -> void:
	_tw().tween_callback(c).set_delay(maxf(sec, 0.001))

## 換句子之前：還沒做完的動作直接做完（位置、開關都到最後的狀態）
func _finish_tweens() -> void:
	# 做完的動作可能又排了新的動作（跳上去之後再轉身），所以多跑幾輪到沒有為止
	for _pass in 6:
		if _tweens.is_empty():
			break
		var list := _tweens
		_tweens = []
		for t in list:
			var tw := t as Tween
			if tw and tw.is_valid():
				if tw.is_running():
					tw.custom_step(600.0)
				tw.kill()

func _spin_add(n: Node3D, axis: Vector3, speed: float) -> void:
	_spin.append({"node": n, "axis": axis, "speed": speed})

# ================================================================== 介面

func _build_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 20
	add_child(_layer)
	# 上下兩條黑邊（電影的畫面比例）
	for top in [true, false]:
		var bar := ColorRect.new()
		bar.color = Color(0.02, 0.02, 0.03)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.set_anchors_preset(Control.PRESET_TOP_WIDE if top else Control.PRESET_BOTTOM_WIDE)
		if top:
			bar.offset_bottom = 58
		else:
			bar.offset_top = -58
		_layer.add_child(bar)
		_bars.append(bar)
	# 右上角的按鍵提示
	var keys := HBoxContainer.new()
	keys.add_theme_constant_override("separation", 26)
	keys.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	keys.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	keys.offset_right = -28
	keys.offset_top = 12
	_layer.add_child(keys)
	var light := Color(1, 0.97, 0.9, 0.85)
	_hint_next = UIStyle.key_hint("Enter", "下一句", 14, light)
	keys.add_child(_hint_next)
	var esc := UIStyle.key_hint("Esc", _skip_text(), 14, light)
	esc.modulate.a = 0.75
	keys.add_child(esc)
	# 對話框＝筆記紙
	_dlg = PanelContainer.new()
	UIStyle.paper(_dlg, 0.0)
	_dlg.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_dlg.offset_left = 150
	_dlg.offset_right = -150
	_dlg.offset_top = -196
	_dlg.offset_bottom = -30
	_dlg.visible = false
	_layer.add_child(_dlg)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	_dlg.add_child(v)
	_name = Label.new()
	_name.label_settings = UIStyle.ls(25, UIStyle.accent())
	v.add_child(_name)
	var ts := UIStyle.ls(28, UIStyle.INK)
	ts.line_spacing = 6
	_text = Label.new()
	_text.label_settings = ts
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(0, 84)
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_text)
	# 「▼ 還有下一句」放在框框右下角。對話框是 PanelContainer，直接放進去的子節點會被排到左上角
	# （錨點沒用，會疊在第一個字上），所以先墊一層一般的 Control（會被撐滿整個框的內容區），▼ 再用錨點貼右下角
	var over := Control.new()
	over.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dlg.add_child(over)
	_arrow = Label.new()
	_arrow.text = "▼"
	_arrow.label_settings = UIStyle.ls(18, UIStyle.accent())
	_arrow.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_arrow.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_arrow.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_arrow.offset_left = -26
	_arrow.offset_top = -26
	_arrow.offset_right = -2
	_arrow.offset_bottom = 2
	_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	over.add_child(_arrow)
	# 畫面正中間的大字（「天選之雞」）
	_stamp_label = Label.new()
	_stamp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stamp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_stamp_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_stamp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stamp_label.visible = false
	_layer.add_child(_stamp_label)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 1)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_fade)

## 畫面正中間蓋一排大字，停 dur 秒
func _stamp(text: String, color: Color, dur := 1.6, size := 120, y := -60.0) -> void:
	_stamp_label.text = text
	_stamp_label.label_settings = UIStyle.ls(size, color, 22, Color(0.20, 0.10, 0.04))
	_stamp_label.visible = true
	_stamp_label.offset_top = y
	_stamp_label.offset_bottom = y
	_stamp_label.modulate.a = 0.0
	_stamp_label.pivot_offset = get_viewport().get_visible_rect().size * 0.5
	_stamp_label.scale = Vector2.ONE * 2.2
	var tw := _tw()
	tw.set_parallel(true)
	tw.tween_property(_stamp_label, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_stamp_label, "modulate:a", 1.0, 0.12)
	tw.chain().tween_interval(dur)
	tw.chain().tween_property(_stamp_label, "modulate:a", 0.0, 0.35)
	tw.chain().tween_callback(func(): _stamp_label.visible = false)

## 整個畫面閃一下（白光）
func _flash(color := Color(1, 1, 1), peak := 0.85, dur := 0.5) -> void:
	_fade.color = Color(color, peak)
	_tw().tween_property(_fade, "color:a", 0.0, dur)

# ================================================================== 流程

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
	if _busy or _leaving:
		return
	if _typing:
		_shown = float(_text.text.length())
		_text.visible_characters = -1
		_typing = false
		return
	_next()

func skip() -> void:
	if _leaving:
		return
	_leaving = true
	_busy = true
	_music_stop(0.4)
	var tw := create_tween()
	tw.tween_property(_fade, "color", Color(0, 0, 0, 1), 0.4)
	await tw.finished
	# 下一個場景（主畫面）要建一兩秒、網頁版更久，建好之前畫面完全不會動：
	# 先蓋上「載入中」（掛在 root，換場景不會被拿掉）再換，新場景畫出來之後它自己淡掉
	var card := LoadingCard.new()
	get_tree().root.add_child(card)
	await card.shown
	get_tree().change_scene_to_file(_next_scene())

func _next() -> void:
	if _busy or _leaving:
		return
	_finish_tweens()
	_i += 1
	if _i >= _script.size():
		skip()
		return
	var line: Dictionary = _script[_i]
	if String(line.shot) != _shot:
		_busy = true
		_dlg.visible = false
		var c := Color(1, 1, 1) if String(line.get("fade", "")) == "white" else Color(0, 0, 0)
		if _shot != "":
			_fade.color = Color(c, _fade.color.a)
			var tw := create_tween()
			tw.tween_property(_fade, "color:a", 1.0, float(line.get("fade_out", 0.35)))
			await tw.finished
		_shot = String(line.shot)
		_shot_t = 0.0
		_enter_shot(_shot)
		_start_line(line)
		var tw2 := create_tween()
		tw2.tween_property(_fade, "color:a", 0.0, float(line.get("fade_in", 0.6)))
		await tw2.finished
		_busy = false
	else:
		_start_line(line)

func _start_line(line: Dictionary) -> void:
	_line = line
	_line_t = 0.0
	_hold = float(line.get("hold", -1.0))
	var text := String(line.get("text", ""))
	_name.text = String(line.get("who", ""))
	_name.visible = _name.text != ""
	_text.text = text
	_text.visible_characters = 0
	_shown = 0.0
	_blip_n = 0
	_typing = text != ""
	for a in _actors:
		a.talk = 0.0
	_on_line(line)

func _process(dt: float) -> void:
	_t += dt
	if not _busy:
		_shot_t += dt
		_line_t += dt
	var has_text := _text.text != ""
	_dlg.visible = has_text and not _busy
	_hint_next.modulate.a = 1.0 if has_text else 0.45
	if _typing and not _busy:
		_shown += dt * TYPE_SPEED
		var n := int(_shown)
		if n > _blip_n:
			_blip_n = n
			var ch := _text.text.substr(mini(n, _text.text.length()) - 1, 1)
			if n % 2 == 0 and not (ch in " 　。，、…！？「」（）：.!?"):
				var p := _voice_pitch(_name.text)
				if p > 0.0:
					_play("blip", -17.0, p * (0.96 + 0.08 * float((n * 7) % 5) / 4.0))
		_text.visible_characters = n
		if _shown >= _text.text.length():
			_typing = false
			_text.visible_characters = -1
	_arrow.visible = has_text and not _typing
	_arrow.modulate.a = 0.45 + 0.55 * absf(sin(_t * 3.2))
	# 正在講話的那個角色：頭跟著動
	var sp := _actor_of(_name.text) if has_text else {}
	for a in _actors:
		var on: bool = _typing and not sp.is_empty() and a.node == sp.node
		a.talk = lerpf(a.talk, 1.0 if on else 0.0, 1.0 - exp(-dt * 12.0))
		if is_instance_valid(a.node) and (a.node as Node3D).is_visible_in_tree():
			_animate(a, dt)
	for s in _spin:
		if is_instance_valid(s.node):
			(s.node as Node3D).rotate(s.axis, dt * float(s.speed))
	_update_emotes(dt)
	_tick(dt)
	_update_cam(dt)
	if _hold >= 0.0 and not _busy and not _leaving and _line_t >= _hold:
		_next()

# ================================================================== 聲音（程式合成）

static func s_buf(sec: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(sec * RATE))
	return b

static func s_wav(b: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	# 太大聲會破音：最大的地方超過 0.9 就整段等比例縮小
	var peak := 0.0
	for i in b.size():
		peak = maxf(peak, absf(b[i]))
	var gain := 0.9 / peak if peak > 0.9 else 1.0
	var bytes := PackedByteArray()
	bytes.resize(b.size() * 2)
	for i in b.size():
		bytes.encode_s16(i * 2, int(clampf(b[i] * gain, -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.data = bytes
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_end = b.size()
	return w

static func s_hz(note: int) -> float:
	return 440.0 * pow(2.0, float(note - 69) / 12.0)

## 一顆音：基音加泛音，敲下去之後慢慢變小。bright 越大越亮；decay 越大越短促；wrap＝超出去的繞回開頭（循環的配樂用）
static func s_tone(b: PackedFloat32Array, at: float, hz: float, dur: float, amp: float, bright := 0.3, decay := 5.0, wrap := false) -> void:
	var n0 := int(at * RATE)
	var n := int(dur * RATE)
	var size := b.size()
	for i in n:
		var j := n0 + i
		if j >= size:
			if not wrap:
				break
			j %= size
		var t := float(i) / RATE
		var env := minf(t / 0.004, 1.0) * exp(-t * decay) * minf(float(n - i) / (0.01 * RATE), 1.0)
		var ph := TAU * hz * t
		b[j] += (sin(ph) + bright * sin(ph * 2.0) + bright * 0.5 * sin(ph * 3.0)) * env * amp

## 一小撮雜訊（鼓刷、沙沙聲、唱片的「嚓」）：tone 越小越悶
static func s_noise(b: PackedFloat32Array, at: float, dur: float, amp: float, tone: float, seed_n: int, decay := 18.0, wrap := false) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = seed_n
	var n0 := int(at * RATE)
	var n := int(dur * RATE)
	var size := b.size()
	var lp := 0.0
	for i in n:
		var j := n0 + i
		if j >= size:
			if not wrap:
				break
			j %= size
		var t := float(i) / RATE
		lp = lerpf(lp, r.randf_range(-1.0, 1.0), tone)
		b[j] += lp * exp(-t * decay) * amp

## 大鼓：頻率很快往下掉的正弦波
static func s_kick(b: PackedFloat32Array, at: float, amp: float, wrap := false) -> void:
	var n0 := int(at * RATE)
	var n := int(0.22 * RATE)
	var size := b.size()
	var ph := 0.0
	for i in n:
		var j := n0 + i
		if j >= size:
			if not wrap:
				break
			j %= size
		var t := float(i) / RATE
		ph += TAU * (48.0 + 110.0 * exp(-t * 34.0)) / RATE
		b[j] += sin(ph) * exp(-t * 13.0) * amp

## 滑音：頻率從 f0 滑到 f1
static func s_glide(b: PackedFloat32Array, at: float, f0: float, f1: float, dur: float, amp: float, bright := 0.2) -> void:
	var n0 := int(at * RATE)
	var n := int(dur * RATE)
	var ph := 0.0
	for i in n:
		var j := n0 + i
		if j >= b.size():
			break
		var k := float(i) / float(n)
		ph += TAU * lerpf(f0, f1, k) / RATE
		b[j] += (sin(ph) + bright * sin(ph * 2.0)) * sin(k * PI) * amp

func _make_base_sounds() -> void:
	# 講話的「嘟」：很短的一顆音，照說話的人調高低
	var b := s_buf(0.07)
	s_tone(b, 0.0, 520.0, 0.07, 0.5, 0.25, 34.0)
	_snd["blip"] = s_wav(b)
	# 頭上冒問號的「啵」
	b = s_buf(0.16)
	s_glide(b, 0.0, 420.0, 760.0, 0.14, 0.5)
	_snd["pop"] = s_wav(b)
	# 咚（東西掉在地上、跌倒）
	b = s_buf(0.3)
	s_kick(b, 0.0, 0.9)
	s_noise(b, 0.0, 0.1, 0.25, 0.3, 4)
	_snd["thud"] = s_wav(b)
	# 叮（發現東西、閃一下）
	b = s_buf(0.7)
	s_tone(b, 0.0, s_hz(88), 0.7, 0.3, 0.5, 6.0)
	s_tone(b, 0.07, s_hz(93), 0.6, 0.25, 0.5, 6.0)
	_snd["ding"] = s_wav(b)
	# 咻（東西滑過、往下掉）
	b = s_buf(0.5)
	s_glide(b, 0.0, 900.0, 240.0, 0.45, 0.35)
	_snd["whoosh"] = s_wav(b)
	for k in 6:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_voices.append(p)
	_music = AudioStreamPlayer.new()
	add_child(_music)

func _play(snd_name: String, db := -8.0, pitch := 1.0) -> void:
	if not _snd.has(snd_name):
		return
	var p := _voices[_voice_i % _voices.size()] as AudioStreamPlayer
	_voice_i += 1
	p.stream = _snd[snd_name]
	p.volume_db = db
	p.pitch_scale = pitch
	p.play()

func _music_play(snd_name: String, db := -10.0, fade := 0.0) -> void:
	if not _snd.has(snd_name):
		return
	_music_db = db
	if _music.stream != _snd[snd_name] or not _music.playing:
		_music.stream = _snd[snd_name]
		_music.volume_db = -50.0 if fade > 0.0 else db
		_music.play()
	if fade > 0.0:
		create_tween().tween_property(_music, "volume_db", db, fade)
	else:
		_music.volume_db = db

func _music_stop(fade := 0.0) -> void:
	if _music == null or not _music.playing:
		return
	if fade <= 0.0:
		_music.stop()
		return
	var tw := create_tween()
	tw.tween_property(_music, "volume_db", -50.0, fade)
	tw.tween_callback(_music.stop)

# ================================================================== 農場外景（開場和結局的「屋頂」鏡頭）

## 蓋一座農場：草地、雞舍、遠處的穀倉和風車、樹、圍欄、乾草。
## 回傳 {root, coop, ridge_y（屋脊多高）, sun（天上那顆大太陽）, clouds}。雞舍的屋脊沿著 X 方向。
func _build_farm(parent: Node3D) -> Dictionary:
	var root := Node3D.new()
	root.name = "Farm"
	parent.add_child(root)
	# 草地（貼圖）、雞舍前面的一塊泥地
	var gm := PlaneMesh.new()
	gm.size = Vector2(260, 260)
	_mesh(root, gm, Vector3.ZERO, _tex_mat("res://assets/textures/grass_ground_diff_1k.jpg", 56.0, Color(0.92, 1.0, 0.82)))
	var dirt := _tex_mat("res://assets/textures/gravelly_sand_diff_1k.jpg", 3.0, Color(1.0, 0.9, 0.78))
	_cyl(root, 6.4, 6.6, 0.03, Vector3(0.6, 0.01, 4.2), dirt, Vector3.ZERO, 28)
	_cyl(root, 2.6, 2.8, 0.03, Vector3(6.2, 0.012, 1.0), dirt, Vector3.ZERO, 20)
	# 雞舍：屋脊轉成左右向（鏡頭看得到一整排）
	var coop := _glb(root, FARM + "ChickenCoop.glb", Vector3.ZERO, PI * 0.5, 3.0)
	var ridge_y := _top_y(coop, 0.0, 0.0)
	# 遠處：穀倉、筒倉、風車
	_glb(root, FARM + "Barn.glb", Vector3(17.0, 0, -19.0), -0.5, 1.25)
	_glb(root, FARM + "Silo.glb", Vector3(27.0, 0, -24.0), 0.3, 1.2)
	_glb(root, FARM + "SmallBarn.glb", Vector3(-19.0, 0, -22.0), 0.7, 1.0)
	var mill := _glb(root, FARM + "Windmill.glb", Vector3(-7.5, 0, -17.0), 0.35, 4.6)
	# 樹
	var r := RandomNumberGenerator.new()
	r.seed = 21
	var trees := [NATURE + "BirchTree.glb", NATURE + "AutumnTree.glb"]
	for k in 26:
		var a := r.randf_range(0.0, TAU)
		var d := r.randf_range(20.0, 58.0)
		var p := Vector3(cos(a) * d, 0, sin(a) * d * 0.9 - 6.0)
		if p.z > 6.0 and absf(p.x) < 16.0:
			continue          # 鏡頭前面不要種樹
		_glb(root, trees[k % 2], p, r.randf_range(0, TAU), r.randf_range(1.8, 3.0))
	for p in [Vector3(-8.2, 0, 2.0), Vector3(10.5, 0, -5.0), Vector3(-12.0, 0, -8.5)]:
		_glb(root, NATURE + "BushBerries.glb", p, p.x, 1.6)
	# 木頭圍欄：圍著泥地的後半圈
	var wood := _toon(Color(0.62, 0.44, 0.28))
	var wood_d := _toon(Color(0.46, 0.31, 0.20))
	var posts: Array = []
	for k in 13:
		var a := lerpf(-0.25, PI + 0.25, float(k) / 12.0)
		posts.append(Vector3(0.6 - cos(a) * 9.6, 0, 3.4 - sin(a) * 8.6))
	for k in posts.size():
		var p: Vector3 = posts[k]
		if absf(p.x - 6.5) < 2.0 and p.z < 0.0:
			continue          # 雞舍斜坡出口留一個缺口
		_box(root, Vector3(0.16, 1.0, 0.16), p + Vector3(0, 0.5, 0), wood_d)
		if k + 1 < posts.size():
			var q: Vector3 = posts[k + 1]
			if absf(q.x - 6.5) < 2.0 and q.z < 0.0:
				continue
			var mid := (p + q) * 0.5
			var yaw := atan2(q.x - p.x, q.z - p.z)
			for h in [0.38, 0.78]:
				_box(root, Vector3(0.07, 0.11, p.distance_to(q) + 0.1), mid + Vector3(0, h, 0), wood, Vector3(0, yaw, 0))
	# 乾草捆、飼料槽
	for p in [Vector3(-4.6, 0, 1.2), Vector3(-5.3, 0, 0.5), Vector3(-4.2, 0, 0.3), Vector3(7.6, 0, 4.4)]:
		_glb(root, FARM + "Hay.glb", p, p.z * 2.0, 6.5)
	_box(root, Vector3(1.8, 0.22, 0.5), Vector3(3.6, 0.2, 5.2), wood, Vector3(0, 0.3, 0))
	_box(root, Vector3(1.6, 0.06, 0.34), Vector3(3.6, 0.3, 5.2), _toon(Color(0.90, 0.74, 0.36)), Vector3(0, 0.3, 0))
	# 遠處起伏的草丘（擋住地平線的直線）
	var hill := _toon(Color(0.42, 0.60, 0.30))
	for k in 9:
		var a := -PI + float(k) * (PI / 8.0)
		_ball(root, 26.0, Vector3(cos(a) * 110.0, -15.0 + (k % 3) * 2.0, sin(a) * 110.0 - 10.0), hill, Vector3(1.6, 0.9, 1.0), 16)
	# 太陽（或月亮）：一顆不受光的大球，位置由各個鏡頭自己擺
	var sun := _ball(root, 13.0, Vector3(60, 14, -130), _glow(Color(1.0, 0.80, 0.42)), Vector3.ONE, 28)
	_no_shadow(sun)
	var halo := _ball(sun, 22.0, Vector3.ZERO, _glow(Color(1.0, 0.72, 0.36), 0.22, true), Vector3.ONE, 24)
	_no_shadow(halo)
	# 雲
	var clouds: Array = []
	for k in 7:
		var c := _glb(root, CLOUDS % ["a", "b", "c"][k % 3], Vector3(-80.0 + k * 30.0 + r.randf_range(-6, 6), r.randf_range(24, 40), -120.0 + r.randf_range(-12, 12)), 0.0, r.randf_range(4.5, 7.5))
		if c:
			_no_shadow(c)
			clouds.append(c)
	return {"root": root, "coop": coop, "ridge_y": ridge_y, "sun": sun, "halo": halo, "clouds": clouds, "mill": mill}

## 屋脊上第 x 公尺的位置（站在屋頂上）
func _ridge(farm: Dictionary, x: float) -> Vector3:
	return Vector3(x, float(farm.ridge_y), 0.0)

# ================================================================== 開發用：每一句截一張圖

## --cutshots=<資料夾>：自動一句一句播，每句截圖（沒台詞的那幾拍截中間和最後）。開發時在背景看畫面用
func _cutshots(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var only := -1
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--from="):
			only = int(a.substr(7))
	var n := 0
	while not _leaving and _i < _script.size():
		while _busy:
			await get_tree().process_frame
		var idx := _i
		if idx < only:
			# 前面的句子快轉過去
			if _typing:
				advance()
			_hold = -1.0
			advance()
			await get_tree().process_frame
			continue
		var hold := _hold
		if hold >= 0.0:
			_hold = -1.0             # 自己控制什麼時候往下
			for part in [0.45, 0.98]:
				await get_tree().create_timer(hold * (0.45 if part < 0.5 else 0.53)).timeout
				await _snap(dir, "%02d%s_%s" % [idx, "a" if part < 0.5 else "b", _shot])
		else:
			await get_tree().create_timer(float(_line.get("snap", 1.4))).timeout
			if _typing:
				advance()
			await get_tree().process_frame
			await _snap(dir, "%02d_%s" % [idx, _shot])
		n += 1
		if _i == idx:
			if _i >= _script.size() - 1:
				break
			_typing = false
			_next()
		await get_tree().process_frame
	var f := FileAccess.open(dir.path_join("DONE"), FileAccess.WRITE)
	if f:
		f.store_string("%d" % n)
		f.close()
	get_tree().quit()

func _snap(dir: String, shot_name: String) -> void:
	for _k in 180:
		if DisplayServer.window_can_draw():
			break
		await get_tree().process_frame
	if not DisplayServer.window_can_draw():
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dir.path_join(shot_name + ".png"))

# ================================================================== 自動驗收（--autotest）

func _autotest_report(_seen: Array) -> Array:
	return []

func _autotest() -> void:
	var out_dir := "user://autotest"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--outdir="):
			out_dir = a.substr(9)
	DirAccess.make_dir_recursive_absolute(out_dir)
	var shots := {}
	var seen := []
	var guard := 0
	while _i < _script.size() and guard < 200 and not _leaving:
		guard += 1
		await get_tree().create_timer(0.5).timeout
		if _busy:
			continue
		if not shots.has(_shot) and DisplayServer.window_can_draw():
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(out_dir.path_join("intro_%s.png" % _shot))
			shots[_shot] = true
		if not seen.has(_shot):
			seen.append(_shot)
		if _i >= _script.size() - 1 and not _typing:
			break
		advance()
		if _typing:
			advance()
	var rep := _autotest_report(seen)
	var fails := 0
	var lines: Array = []
	for r in rep:
		lines.append("[%s] %s" % ["PASS" if r[0] else "FAIL", r[1]])
		if not r[0]:
			fails += 1
	for l in lines:
		print(l)
	Engine.set_meta("intro_lines", lines)
	Engine.set_meta("intro_fails", fails)
	_hold = -1.0
	_typing = false
	skip()
