extends Node3D
## 角色擺放：鳥禽主角 + 人類敵人（目前只有模型與待機動作，沒有 AI）
##
## 主角：優先載入 assets/characters/ 裡檔名含 rooster / chicken 的 .glb/.gltf
##       （styloo 的 CHICKEN ESCAPE 素材包），找不到就用程式做的卡通公雞替身。
## 敵人：Quaternius Ultimate Modular Men 的 Farmer.gltf（CC0），找不到同樣用替身。

const CHAR_DIR := "res://assets/characters/"
const HERO_HEIGHT := 1.45
const ENEMY_HEIGHT := 2.6
## 主角造型：黑色連帽 T、帽子戴起來（網路「家豪」風的厭世少年感）
const HERO_HOODIE := true

var hero: Node3D
var enemy: Node3D
var _standin_parts: Array = []   # 替身的待機動畫用
var _t := 0.0

func setup(world: Node) -> void:
	var cc: Vector2 = world.clearing_center()
	var hero_pos := Vector3(cc.x - 0.8, 0, cc.y - 0.6)
	var enemy_pos := Vector3(cc.x + 2.6, 0, cc.y - 2.3)
	hero_pos.y = world.height_at(hero_pos.x, hero_pos.z)
	enemy_pos.y = world.height_at(enemy_pos.x, enemy_pos.z)

	hero = _load_model(["rooster", "chicken"], HERO_HEIGHT, ["idle"])
	if hero == null:
		hero = _make_standin_rooster()
	hero.name = "Hero"
	add_child(hero)
	hero.global_position = hero_pos

	enemy = _load_model(["farmer"], ENEMY_HEIGHT, ["Idle"])
	if enemy == null:
		enemy = _make_standin_human()
	enemy.name = "Enemy"
	add_child(enemy)
	enemy.global_position = enemy_pos

	# 互相面對（模型正面為 +Z 時 look_at 要 use_model_front）
	hero.look_at(Vector3(enemy_pos.x, hero_pos.y, enemy_pos.z), Vector3.UP, true)
	enemy.look_at(Vector3(hero_pos.x, enemy_pos.y, hero_pos.z), Vector3.UP, true)

var enemies: Array[Node3D] = []

## 一隻主角 + 多個敵人（農場關卡用）
func setup_multi(world: Node, hero_pos: Vector3, enemy_positions: Array, boss_last := false) -> void:
	hero = _load_model(["rooster", "chicken"], HERO_HEIGHT, ["idle"])
	if hero == null:
		hero = _make_standin_rooster()
	hero.name = "Hero"
	add_child(hero)
	hero.global_position = Vector3(hero_pos.x, world.height_at(hero_pos.x, hero_pos.z), hero_pos.z)
	for i in enemy_positions.size():
		var p: Vector3 = enemy_positions[i]
		var e: Node3D
		if boss_last and i == enemy_positions.size() - 1:
			e = _make_merchant()   # 老闆：坐著的胖商人
		else:
			e = _load_model(["farmer"], ENEMY_HEIGHT, ["Idle"])
			if e == null:
				e = _make_standin_human()
		e.name = "Farmer%d" % (i + 1)
		add_child(e)
		e.global_position = Vector3(p.x, world.height_at(p.x, p.z), p.z)
		enemies.append(e)
	enemy = enemies[0] if not enemies.is_empty() else null

## 一個一個生角色（battle_base.gd 照 _enemy_specs() 生敵人時用）
func spawn_hero(world: Node, pos: Vector3) -> Node3D:
	hero = _load_model(["rooster", "chicken"], HERO_HEIGHT, ["idle"])
	if hero == null:
		hero = _make_standin_rooster()
	hero.name = "Hero"
	add_child(hero)
	hero.global_position = Vector3(pos.x, world.height_at(pos.x, pos.z), pos.z)
	return hero

## model："farmer"（預設農夫）、"merchant"（胖商人）、或 .glb / .gltf 的完整路徑（自動縮放到敵人身高）
func spawn_enemy(world: Node, model: String, pos: Vector3) -> Node3D:
	var e: Node3D = null
	if model == "merchant":
		e = _make_merchant()
	elif model.begins_with("res://"):
		e = _load_model_path(model, ENEMY_HEIGHT, ["Idle", "idle"])
	else:
		e = _load_model([model], ENEMY_HEIGHT, ["Idle"])
	if e == null:
		e = _make_standin_human()
	e.name = "Enemy%d" % (enemies.size() + 1)
	add_child(e)
	e.global_position = Vector3(pos.x, world.height_at(pos.x, pos.z), pos.z)
	enemies.append(e)
	if enemy == null:
		enemy = e
	return e

func _load_model_path(path: String, height: float, idle_names: Array) -> Node3D:
	var scene := load(path) as PackedScene
	if scene == null:
		return null
	var model := scene.instantiate() as Node3D
	var wrapper := Node3D.new()
	wrapper.add_child(model)
	var aabb := _merged_aabb(model, Transform3D.IDENTITY)
	if aabb.size.y > 0.001:
		var s := height / aabb.size.y
		model.scale = Vector3.ONE * s
		model.position.y = -aabb.position.y * s
	_play_idle(model, idle_names)
	wrapper.set_meta("source", path)
	return wrapper

# ------------------------------------------------------------ 載入外部模型

func _find_file(keys: Array) -> String:
	var dir := DirAccess.open(CHAR_DIR)
	if dir == null:
		return ""
	for f in dir.get_files():
		var lf := f.to_lower()
		if not (lf.ends_with(".glb") or lf.ends_with(".gltf")):
			continue
		for k in keys:
			if lf.contains(k):
				return CHAR_DIR + f
	return ""

func _load_model(keys: Array, height: float, idle_names: Array) -> Node3D:
	var path := _find_file(keys)
	if path == "":
		return null
	var scene := load(path) as PackedScene
	if scene == null:
		return null
	var model := scene.instantiate() as Node3D
	var wrapper := Node3D.new()
	wrapper.add_child(model)
	# 依模型實際高度縮放，腳底對齊地面
	var aabb := _merged_aabb(model, Transform3D.IDENTITY)
	if aabb.size.y > 0.001:
		var s := height / aabb.size.y
		model.scale = Vector3.ONE * s
		model.position.y = -aabb.position.y * s
	_play_idle(model, idle_names)
	wrapper.set_meta("source", path)
	return wrapper

func _merged_aabb(node: Node, xf: Transform3D) -> AABB:
	var out := AABB()
	var first := true
	var stack := [[node, xf]]
	while stack.size() > 0:
		var item: Array = stack.pop_back()
		var n: Node = item[0]
		var t: Transform3D = item[1]
		if n is Node3D and n != node:
			t = t * (n as Node3D).transform
		if n is MeshInstance3D and (n as MeshInstance3D).mesh:
			var b: AABB = t * (n as MeshInstance3D).mesh.get_aabb()
			out = b if first else out.merge(b)
			first = false
		for c in n.get_children():
			stack.append([c, t])
	return out

func _play_idle(model: Node, idle_names: Array) -> void:
	var players := model.find_children("*", "AnimationPlayer", true, false)
	if players.is_empty():
		return
	var ap: AnimationPlayer = players[0]
	var pick := ""
	for want in idle_names:
		for a in ap.get_animation_list():
			if a.to_lower() == String(want).to_lower() or (pick == "" and a.to_lower().contains(String(want).to_lower())):
				pick = a
		if pick != "":
			break
	if pick == "" and ap.get_animation_list().size() > 0:
		pick = ap.get_animation_list()[0]
	if pick != "":
		ap.get_animation(pick).loop_mode = Animation.LOOP_LINEAR
		ap.play(pick)

# ------------------------------------------------------------ 替身：卡通公雞

func _mat(c: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/toon_color.gdshader")
	m.set_shader_parameter("albedo", c)
	return m

func _part(parent: Node3D, mesh: Mesh, color: Color, pos: Vector3, scl := Vector3.ONE, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(color)
	mi.position = pos
	mi.rotation = rot
	mi.scale = scl
	parent.add_child(mi)
	return mi

func _sphere(r: float, seg := 16) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = seg
	s.rings = seg / 2
	return s

func _capsule(r: float, h: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = h
	c.radial_segments = 10
	c.rings = 4
	return c

func _cone(r: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = 0.0
	c.bottom_radius = r
	c.height = h
	c.radial_segments = 8
	return c

## 圓滾滾版本的雞（載入畫面用）：頭和身體連成一顆圓滾滾的蛋形、頂上一撮紅冠、黃色尖嘴、
## 平面朝上的黑色半圓眼、兩側小翅膀、很短的黃腳。
## hoodie=true 就是家豪：黑色帽 T 包住全身，只露出白臉，胸前白色 W、白帽繩和一個小紅點。
## 模型正面朝 +Z（配合 look_at 的 use_model_front）
func _make_round_chicken(hoodie := HERO_HOODIE) -> Node3D:
	var root := Node3D.new()
	root.set_meta("source", "standin")
	var body := Node3D.new()
	body.name = "Body"
	root.add_child(body)

	var white := Color(0.96, 0.95, 0.93)
	var wing_c := Color(0.90, 0.90, 0.90)
	var black := Color(0.09, 0.09, 0.10)
	var red := Color(0.90, 0.22, 0.16)
	var yellow := Color(0.98, 0.80, 0.25)
	var body_c := black if hoodie else white

	# 短短的腳：只露出一點點，下面是三根腳趾
	for sx in [-1.0, 1.0]:
		_part(body, _capsule(0.026, 0.1), yellow, Vector3(0.12 * sx, 0.06, 0.02))
		for k in 3:
			var a := (k - 1) * 0.45
			_part(body, _capsule(0.018, 0.08), yellow, Vector3(0.12 * sx + sin(a) * 0.03, 0.015, 0.05 + cos(a) * 0.02), Vector3.ONE, Vector3(PI * 0.5, a, 0))
	# 圓滾滾的蛋形身體（頭和身體一體）
	var egg := SphereMesh.new()
	egg.radius = 0.4
	egg.height = 0.8
	egg.radial_segments = 12
	egg.rings = 8
	_part(body, egg, body_c, Vector3(0, 0.48, 0), Vector3(1.0, 1.08, 0.95))
	# 小尾巴
	_part(body, _sphere(0.1, 8), body_c, Vector3(0, 0.6, -0.36), Vector3(0.8, 1.0, 0.8))
	# 翅膀掛在肩膀的樞紐上，戰鬥時可以拍翅（battle.gd 轉 WingL / WingR）
	for sx in [-1.0, 1.0]:
		var pivot := Node3D.new()
		pivot.name = "WingL" if sx < 0.0 else "WingR"
		pivot.position = Vector3(0.37 * sx, 0.55, 0.0)
		body.add_child(pivot)
		_part(pivot, _sphere(0.15, 8), body_c if hoodie else wing_c, Vector3(0.02 * sx, -0.1, 0.0), Vector3(0.35, 0.8, 0.95), Vector3(0, 0, 0.12 * sx))

	# 臉（獨立節點，做點頭動作）
	var head := Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, 0.62, 0)
	body.add_child(head)
	var face_z := 0.32
	if hoodie:
		# 帽 T 開口露出的白臉
		_part(head, _sphere(0.19, 12), white, Vector3(0, 0.03, 0.27), Vector3(1.0, 1.15, 0.5))
		face_z = 0.355
	# 紅冠：一撮往上豎的紅色
	var comb := [[Vector3(0, 0.38, 0.06), 0.075], [Vector3(0, 0.44, 0.0), 0.06], [Vector3(0, 0.33, 0.13), 0.05]]
	for c in comb:
		_part(head, _sphere(c[1], 8), red, c[0], Vector3(0.6, 1.3, 1.0))
	# 黃色多面體尖嘴（微微朝下）
	var beak := CylinderMesh.new()
	beak.top_radius = 0.0
	beak.bottom_radius = 0.075
	beak.height = 0.13
	beak.radial_segments = 5
	beak.rings = 1
	_part(head, beak, yellow, Vector3(0, -0.02, face_z + 0.04), Vector3.ONE, Vector3(PI * 0.5 + 0.35, 0, 0))
	# 眼睛：平面朝上的黑色小半圓
	var eye_mesh := SphereMesh.new()
	eye_mesh.radius = 0.034
	eye_mesh.height = 0.034
	eye_mesh.is_hemisphere = true
	eye_mesh.radial_segments = 14
	eye_mesh.rings = 5
	for sx in [-1.0, 1.0]:
		_part(head, eye_mesh, black, Vector3(0.105 * sx, 0.07, face_z + 0.008), Vector3(1.0, 1.0, 0.4), Vector3(0, 0.3 * sx, PI))

	if hoodie:
		# 帽繩、胸前 W、W 旁邊的小紅點
		for sx in [-1.0, 1.0]:
			_part(body, _capsule(0.012, 0.17), white, Vector3(0.06 * sx, 0.47, 0.375), Vector3.ONE, Vector3(0.15, 0, 0))
		_w_mark(body, Vector3(0, 0.3, 0.36), 0.055, white)
		_part(body, _sphere(0.016, 8), red, Vector3(0.05, 0.24, 0.35))

	_standin_parts.append({"body": body, "head": head, "kind": "bird"})
	root.scale = Vector3.ONE * (HERO_HEIGHT / 1.05)   # 替身原始高度約 1.05（含雞冠）
	return root

## 遊戲內的家豪（白雞穿黑色帽 T、帽兜戴起來），腿比最早的版本短一點。
## 模型正面朝 +Z（配合 look_at 的 use_model_front）
const LEG_TRIM := 0.08   # 腿縮短的長度（模型原始單位）

func _make_standin_rooster(hoodie := HERO_HOODIE) -> Node3D:
	var root := Node3D.new()
	root.set_meta("source", "standin")
	var body := Node3D.new()
	body.name = "Body"
	root.add_child(body)
	# 腿以上的部位都放在 upper 裡、整體往下移，腿就變短了
	var upper := Node3D.new()
	upper.name = "Upper"
	upper.position.y = -LEG_TRIM
	body.add_child(upper)

	var white_feather := Color(0.97, 0.96, 0.93)
	var white_shade := Color(0.86, 0.87, 0.88)
	var cream := white_feather
	var olive := white_shade
	var orange := white_shade
	var teal := white_feather
	var dark_teal := white_shade
	var red := Color(0.84, 0.20, 0.17)
	var leg := Color(0.96, 0.80, 0.42)
	if hoodie:
		# 帽 T 把胸羽、腹部、翅膀都包住
		cream = Color(0.10, 0.10, 0.11)
		olive = Color(0.13, 0.13, 0.14)
		orange = Color(0.11, 0.11, 0.12)

	# 身體：大大的胸、往後收的屁股
	_part(upper, _sphere(0.27), olive, Vector3(0, 0.46, -0.06), Vector3(0.9, 0.85, 1.15))
	_part(upper, _sphere(0.25), cream, Vector3(0, 0.55, 0.08), Vector3(0.92, 1.0, 0.95))
	# 翅膀掛在肩膀的樞紐上，戰鬥時可以拍翅（battle.gd 轉 WingL / WingR）
	for sx in [-1.0, 1.0]:
		var pivot := Node3D.new()
		pivot.name = "WingL" if sx < 0.0 else "WingR"
		pivot.position = Vector3(0.2 * sx, 0.62, -0.04)
		upper.add_child(pivot)
		_part(pivot, _sphere(0.15), orange, Vector3(0.02 * sx, -0.12, 0.0), Vector3(0.35, 0.75, 1.15), Vector3(0.2, 0, 0.15 * sx))
	# 尾羽
	for k in 6:
		var a := -0.5 + k * 0.2
		var col := teal if k % 2 == 0 else dark_teal
		_part(upper, _capsule(0.045, 0.42 - absf(a) * 0.15), col, Vector3(a * 0.12, 0.72, -0.34), Vector3.ONE, Vector3(-0.75 + absf(a) * 0.3, 0, a * 0.9))
	# 腿（比原本短）
	for sx in [-1.0, 1.0]:
		_part(body, _capsule(0.025, 0.3 - LEG_TRIM * 1.5), leg, Vector3(0.09 * sx, 0.17 - LEG_TRIM * 0.75, 0.0))
		if not hoodie:
			_part(body, _sphere(0.05, 8), leg, Vector3(0.09 * sx, 0.02, 0.05), Vector3(1.0, 0.3, 1.6))

	# 頭（獨立節點，做點頭動作）
	var head := Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, 0.78, 0.18)
	upper.add_child(head)
	_part(head, _sphere(0.11), white_feather, Vector3(0, 0.02, -0.02), Vector3(0.9, 1.1, 1.0))
	# 整張臉都是白羽毛
	_part(head, _sphere(0.1), white_feather, Vector3(0, 0.0, 0.03), Vector3(0.9, 1.0, 0.88))
	# 雞冠
	for k in 4:
		_part(head, _sphere(0.045, 8), red, Vector3(0, 0.12 + (0.02 if k % 2 == 1 else 0.0), 0.06 - k * 0.045), Vector3(0.5, 1.3, 0.9))
	# 大大的黃色多面體嘴喙，夾在兩隻眼睛中間
	_part(head, _sphere(0.05, 6), Color(0.98, 0.86, 0.42), Vector3(0, 0.005, 0.125), Vector3(1.0, 1.1, 0.95))
	# 長肉垂（喜劇感來源）
	_part(head, _capsule(0.03, 0.34), red, Vector3(0, -0.17, 0.1), Vector3(1.0, 1.0, 0.8), Vector3(-0.12, 0, 0))
	# 眼睛：倒過來的黑色小半圓（平的那側朝上）
	var eye_mesh := SphereMesh.new()
	eye_mesh.radius = 0.022
	eye_mesh.height = 0.022
	eye_mesh.is_hemisphere = true
	eye_mesh.radial_segments = 16
	eye_mesh.rings = 6
	for sx in [-1.0, 1.0]:
		var eye := Node3D.new()
		eye.position = Vector3(0.066 * sx, 0.035, 0.092)
		eye.rotation = Vector3(0, 0.35 * sx, 0)
		head.add_child(eye)
		_part(eye, eye_mesh, Color(0.05, 0.05, 0.06), Vector3.ZERO, Vector3(1.0, 1.0, 0.35), Vector3(0, 0, PI))

	if hoodie:
		_dress_hoodie(upper, head, body)

	_standin_parts.append({"body": body, "head": head, "kind": "bird"})
	root.scale = Vector3.ONE * (HERO_HEIGHT / (0.95 - LEG_TRIM))
	return root

## 黑色帽 T：帽兜罩住頭（露出白臉、嘴喙和一點雞冠）、白色抽繩、胸前白色 W 字、黑白球鞋
func _dress_hoodie(upper: Node3D, head: Node3D, body: Node3D) -> void:
	var black := Color(0.10, 0.10, 0.11)
	var rim := Color(0.15, 0.15, 0.16)
	var white := Color(0.95, 0.95, 0.93)
	_part(head, _sphere(0.16), black, Vector3(0, 0.05, -0.08), Vector3(1.05, 1.05, 1.0))
	var torus := TorusMesh.new()
	torus.inner_radius = 0.105
	torus.outer_radius = 0.135
	torus.rings = 24
	torus.ring_segments = 8
	_part(head, torus, rim, Vector3(0, 0.035, 0.055), Vector3(1.0, 1.0, 1.15), Vector3(PI * 0.5, 0, 0))
	# 帽 T 領口探出一圈白羽毛
	_part(upper, _sphere(0.13, 12), Color(0.97, 0.96, 0.93), Vector3(0, 0.74, 0.2), Vector3(1.0, 0.45, 0.85))
	# 帽繩
	for sx in [-1.0, 1.0]:
		_part(upper, _capsule(0.008, 0.22), white, Vector3(0.05 * sx, 0.62, 0.3), Vector3.ONE, Vector3(0.25, 0, 0.06 * sx))
	# 胸前 W 字
	_w_mark(upper, Vector3(0, 0.52, 0.322), 0.055, white)
	# 黑色球鞋 + 白鞋底
	for sx in [-1.0, 1.0]:
		_part(body, _sphere(0.06, 10), black, Vector3(0.09 * sx, 0.04, 0.05), Vector3(1.0, 0.55, 1.6))
		_part(body, _sphere(0.062, 10), white, Vector3(0.09 * sx, 0.012, 0.05), Vector3(1.0, 0.2, 1.62))

## 用細膠囊拼一個簡單的 W 字（貼在 +Z 正面）
func _w_mark(parent: Node3D, center: Vector3, s: float, color: Color) -> void:
	var pts := [Vector2(-1, 1), Vector2(-0.5, -1), Vector2(0, 0.35), Vector2(0.5, -1), Vector2(1, 1)]
	for k in pts.size() - 1:
		var a: Vector2 = pts[k] * s
		var b: Vector2 = pts[k + 1] * s
		var d := b - a
		var r := s * 0.09
		var mid := (a + b) * 0.5
		_part(parent, _capsule(r, d.length() + r * 2.0), color, center + Vector3(mid.x, mid.y, 0), Vector3(1, 1, 0.5), Vector3(0, 0, -atan2(d.x, d.y)))

# ------------------------------------------------------------ 老闆：坐在椅子上的胖商人（拿著槍）

## 正面朝 +Z。節點：Body（整個人）、ArmR（拿槍的手，樞紐在肩膀，battle.gd 轉它來瞄準）、Gun
func _make_merchant() -> Node3D:
	var root := Node3D.new()
	root.set_meta("source", "merchant")
	var suit := Color(0.48, 0.16, 0.2)
	var vest := Color(0.9, 0.72, 0.3)
	var skin := Color(0.96, 0.76, 0.6)
	var dark := Color(0.12, 0.1, 0.1)
	var wood := Color(0.42, 0.27, 0.17)
	# 椅子
	var chair_seat := BoxMesh.new()
	chair_seat.size = Vector3(1.4, 0.15, 1.2)
	_part(root, chair_seat, wood, Vector3(0, 0.7, -0.1))
	var chair_back := BoxMesh.new()
	chair_back.size = Vector3(1.5, 1.7, 0.15)
	_part(root, chair_back, wood, Vector3(0, 1.5, -0.75))
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_part(root, _capsule(0.06, 0.7), wood, Vector3(0.6 * sx, 0.35, -0.1 + 0.5 * sz))
	var body := Node3D.new()
	body.name = "Body"
	root.add_child(body)
	# 坐著的粗腿
	for sx in [-1.0, 1.0]:
		_part(body, _capsule(0.2, 0.75), suit.darkened(0.2), Vector3(0.32 * sx, 0.85, 0.3), Vector3.ONE, Vector3(PI * 0.5, 0, 0))
		_part(body, _capsule(0.17, 0.6), suit.darkened(0.25), Vector3(0.32 * sx, 0.4, 0.62))
		_part(body, _sphere(0.17, 8), dark, Vector3(0.32 * sx, 0.08, 0.72), Vector3(1.0, 0.6, 1.4))
	# 圓滾滾的肚子 + 西裝
	_part(body, _sphere(0.78, 14), suit, Vector3(0, 1.4, 0.0), Vector3(1.22, 1.0, 1.05))
	_part(body, _sphere(0.62, 12), vest, Vector3(0, 1.32, 0.3), Vector3(1.0, 0.95, 0.75))
	for k in 3:
		_part(body, _sphere(0.05, 6), dark, Vector3(0, 1.62 - k * 0.25, 0.78))
	_part(body, _capsule(0.018, 0.55), Color(1.0, 0.85, 0.3), Vector3(0.18, 1.35, 0.76), Vector3.ONE, Vector3(0, 0, 1.2))
	# 頭、八字鬍、高禮帽
	var head := Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, 2.35, 0.05)
	body.add_child(head)
	_part(head, _sphere(0.42, 12), skin, Vector3.ZERO, Vector3(1.05, 0.95, 1.0))
	_part(head, _sphere(0.08, 8), Color(0.95, 0.55, 0.5), Vector3(0, -0.02, 0.42))
	for sx in [-1.0, 1.0]:
		_part(head, _sphere(0.045, 6), dark, Vector3(0.15 * sx, 0.1, 0.37))
		_part(head, _capsule(0.05, 0.28), Color(0.3, 0.2, 0.15), Vector3(0.14 * sx, -0.12, 0.38), Vector3.ONE, Vector3(0, 0, PI * 0.5 + 0.25 * sx))
	var brim := CylinderMesh.new()
	brim.top_radius = 0.55
	brim.bottom_radius = 0.55
	brim.height = 0.06
	_part(head, brim, dark, Vector3(0, 0.33, 0))
	var crown := CylinderMesh.new()
	crown.top_radius = 0.33
	crown.bottom_radius = 0.33
	crown.height = 0.55
	_part(head, crown, dark, Vector3(0, 0.62, 0))
	_part(head, crown.duplicate(), Color(0.7, 0.15, 0.15), Vector3(0, 0.4, 0), Vector3(1.03, 0.15, 1.03))
	# 左手放在桌上
	_part(body, _capsule(0.16, 0.85), suit, Vector3(-0.95, 1.4, 0.4), Vector3.ONE, Vector3(1.1, 0, 0.25))
	_part(body, _sphere(0.15, 8), skin, Vector3(-0.85, 1.05, 0.85))
	# 右手拿槍（樞紐在肩膀）
	var arm := Node3D.new()
	arm.name = "ArmR"
	arm.position = Vector3(0.95, 1.8, 0.1)
	body.add_child(arm)
	_part(arm, _capsule(0.16, 0.85), suit, Vector3(0, -0.4, 0))
	_part(arm, _sphere(0.15, 8), skin, Vector3(0, -0.85, 0))
	var gun := Node3D.new()
	gun.name = "Gun"
	gun.position = Vector3(0, -0.92, 0.05)
	arm.add_child(gun)
	var gm := BoxMesh.new()
	gm.size = Vector3(0.12, 0.5, 0.16)
	_part(gun, gm, dark, Vector3(0, -0.22, 0))
	var grip := BoxMesh.new()
	grip.size = Vector3(0.1, 0.12, 0.22)
	_part(gun, grip, Color(0.35, 0.22, 0.14), Vector3(0, 0.02, -0.1))
	arm.rotation.x = 0.9   # 平常：手擱在前面
	return root

# ------------------------------------------------------------ 替身：人類（只在 Farmer 找不到時用）

func _make_standin_human() -> Node3D:
	var root := Node3D.new()
	root.set_meta("source", "standin")
	var body := Node3D.new()
	root.add_child(body)
	_part(body, _capsule(0.2, 0.75), Color(0.35, 0.45, 0.7), Vector3(0, 1.05, 0))
	_part(body, _sphere(0.15), Color(0.95, 0.78, 0.62), Vector3(0, 1.58, 0))
	for sx in [-1.0, 1.0]:
		_part(body, _capsule(0.08, 0.7), Color(0.5, 0.36, 0.22), Vector3(0.1 * sx, 0.35, 0))
	_standin_parts.append({"body": body, "head": null, "kind": "human"})
	root.scale = Vector3.ONE * (ENEMY_HEIGHT / 1.75)
	return root

func _process(delta: float) -> void:
	_t += delta
	for p in _standin_parts:
		var b: Node3D = p.body
		if p.kind == "bird":
			# 呼吸 + 偶爾探頭
			if not b.get_meta("posed", false):
				b.position.y = absf(sin(_t * 2.2)) * 0.015
			var h: Node3D = p.head
			h.rotation.x = sin(_t * 1.3) * 0.08 + (0.35 if fmod(_t, 3.0) < 0.25 else 0.0)
			h.rotation.y = sin(_t * 0.7) * 0.3
		else:
			b.scale.y = 1.0 + sin(_t * 2.0) * 0.01
