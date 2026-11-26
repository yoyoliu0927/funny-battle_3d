extends Node3D
## 商店：用關卡拿到的星星買家豪的服裝。
##
## 畫面：家豪站在會轉的試衣台上，右邊是一格一格的服裝卡片（每格有那件服裝的縮圖），
##       左邊是賣鹹酥雞的鴨子老闆（每換一件就吐槽一句），左下是現在選的這一件的說明。
## 游標移到哪一件，家豪就先試穿那一件；按 Enter 才是真的買／穿／脫。
## 操作：方向鍵 選服裝、Enter 買或穿脫、A／D 轉家豪、空白鍵 擺過關姿勢（看專屬演出）、Esc 回地圖。
## 服裝清單和存檔都在 scripts/wardrobe.gd。
## 開發用：命令列加 -- --shopshots=<資料夾>，每一件服裝各截一張圖然後關掉。

const Wardrobe := preload("res://scripts/wardrobe.gd")
const UIStyle := preload("res://scripts/ui/ui_style.gd")
const LevelSelect := preload("res://scripts/level_select.gd")
const Journal := preload("res://scripts/hub/journal.gd")
const MAP_SCENE := "res://scenes/level_select.tscn"
const LoadingCard := preload("res://scripts/ui/loading_card.gd")   # 換場景時先蓋上「載入中」（按了馬上有反應）

const INK := Color("3b2a20")
const PAPER := Color("fff8e7")
const PAPER_EDGE := Color("d9c9a8")
const GOLD := Color("f2c230")
const GREEN := Color("5cb85c")
const RED := Color("e2483d")

const COLS := 3                        # 卡片一排幾張
const CARD := Vector2(190, 176)        # 一張卡片多大
const PANEL_W := 656.0                 # 右邊那塊面板佔多寬（含邊距）
## 每件服裝的縮圖從哪個角度拍
const THUMB_VIEW := {"tag": "bust", "mask": "head", "slippers": "full", "bag": "headwide", "allnighter": "full", "silver": "head",
	"delivery": "back34", "azhi": "full", "cleanroom": "full", "colonel": "tall", "leather": "full", "gown": "tall"}
## 角度：[鏡頭看哪裡, 距離, 左右轉幾度（弧度）, 往上抬幾度]
const VIEWS := {
	"full": [Vector3(0, 0.74, 0.05), 3.05, 0.5, 0.14],
	"tall": [Vector3(0, 0.9, 0.05), 3.7, 0.5, 0.12],
	"head": [Vector3(0, 1.17, 0.18), 1.95, 0.45, 0.1],
	"headwide": [Vector3(0, 1.25, 0.12), 2.3, 0.45, 0.1],
	"bust": [Vector3(-0.03, 0.98, 0.2), 2.35, 0.2, 0.1],
	"back34": [Vector3(0, 0.76, -0.12), 3.1, PI - 1.0, 0.16],
	"back": [Vector3(0, 0.74, -0.2), 3.0, PI - 0.45, 0.16],
	"chest": [Vector3(-0.1, 0.86, 0.3), 1.5, -0.3, 0.08],
}

## 分類頁籤：依服裝佔用的部位篩選（多部位的服裝會出現在每個它佔用的分頁）
const TABS := [
	{"name": "全部", "slots": []},
	{"name": "身體", "slots": ["body"]},
	{"name": "頭", "slots": ["head"]},
	{"name": "臉", "slots": ["face"]},
	{"name": "背後・配件", "slots": ["back", "badge"]},
]
## 點鹹酥雞老闆的彩蛋：一句一句輪流說，連點 10 下拿貼紙
const DUCK_LINES := ["規矩不能壞。", "吃了不燒心。", "規矩立住了，路才能越走越寬。", "不怕虧錢嗎？怕，更怕賬本不清。",
	"搶的走鋪子，搶不走人心。", "明天怎麼辦？先做。", "剩下怎麼辦？倒掉，人不能沒良心。", "終於好起來了；嗯，要穩。",
	"寧可少掙點，也不能壞了規矩。", "那明天多進點肉？不用，慢慢來。", "不是我穩，是不能慌，一慌就容易做錯事。",
	"吃完舒服，下午乾活不燒心。", "老闆，你家貴是貴了點，但是吃了不燒心。"]
const DUCK_STREAK := 10
const DUCK_GAP_MS := 3000     # 兩下之間超過這麼久就不算「連續」

var sel := 0
var _tab := 0
var _tab_btns: Array = []    # 每個分頁 {label, idx}
var _duck_i := 0             # 下一句講哪一句
var _duck_n := 0             # 目前連點幾下
var _duck_last := 0          # 上一下點的時間（毫秒）
var _duck_hop := 0.0         # 鴨老闆被點到時的跳一下
var _thumbs := {}            # 服裝 id -> 拍縮圖的小畫面（SubViewport）
var _name: Label
var _state: Label            # 說明卡上的小標籤：試穿中／穿著中
var _swap: Label             # 說明卡上的提醒：穿上會換掉哪一件
var _slots: Label
var _cam: Camera3D
var _stand: Node3D           # 試衣台上會轉的那一層
var _chars: Node3D           # 家豪（每次換裝整個重做）
var _mini: Node3D            # 旁邊小台子上圓滾滾的家豪（地圖上的樣子）
var _mini_chars: Node3D
var _duck: Node3D
var _spin := 0.6             # 試衣台的角度
var _spin_hold := 0.0        # 剛手動轉過：先停一下再自己轉
var _pose_t := 0.0           # 擺過關姿勢還剩幾秒
var _t := 0.0
var _rows: Array = []        # 每張卡片 {panel, bg, chip, tex}
var _wallet: Label
var _desc: Label
var _quip: Label
var _action: Label
var _toast: Label
var _toast_t := 0.0
var _snd := {}
var _leaving := false
var _burst: CPUParticles3D   # 買到時噴的星星
var _say := ""               # 鴨老闆臨時說的話（買到、買不起）；換一件就收掉
var _enter_key: Control      # 主按鈕旁邊的 Enter 鍵帽（不能按的時候變淡）
var _combo: Label            # 「隱藏組合 2／6」
var _try: Label              # 試衣台上方的大標籤：試穿中／穿著中
var _eye_btns: Array = []    # 眼睛的三顆選項 {id, label}

func _ready() -> void:
	_build_stage()
	_build_thumbs()
	_build_ui()
	_build_audio()
	_select(0, true)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shopshots="):
			_shots.call_deferred(a.substr(12))
		if a.begins_with("--shopboard="):
			_board.call_deferred(a.substr(12))

func _exit_tree() -> void:
	Wardrobe.preview = {}
	Wardrobe.Fx.demo_win = false

# ================================================================== 場景

func _mat(c: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/toon_color.gdshader")
	m.set_shader_parameter("albedo", c)
	return m

func _mesh(parent: Node3D, mesh: Mesh, col: Color, pos: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(col)
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi

func _cyl(r: float, h: float, seg := 32) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = h
	c.radial_segments = seg
	return c

func _box(s: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = s
	return b

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

## 放一個模型：縮放到最長邊 = target 公尺，底部貼在 pos
func _spawn_fit(path: String, pos: Vector3, target: float, yaw := 0.0) -> Node3D:
	if not ResourceLoader.exists(path):
		return null
	var ps := load(path) as PackedScene
	if ps == null:
		return null
	var holder := Node3D.new()
	holder.position = pos
	holder.rotation.y = yaw
	add_child(holder)
	var n := ps.instantiate() as Node3D
	holder.add_child(n)
	var bb := _aabb(n, Transform3D.IDENTITY)
	var s := target / maxf(maxf(bb.size.x, bb.size.y), maxf(bb.size.z, 0.001))
	var c := bb.get_center()
	n.transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * s), -Vector3(c.x, bb.position.y, c.z) * s) * n.transform
	return holder

func _build_stage() -> void:
	# 天空和光
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ShaderMaterial.new()
	sm.shader = preload("res://shaders/sky.gdshader")
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.78, 0.74, 0.70)
	env.ambient_light_energy = 0.95
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 4.0
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.85, -0.55, 0)
	sun.light_color = Color(1.0, 0.93, 0.80)
	sun.light_energy = 1.5
	sun.shadow_enabled = true
	add_child(sun)
	_cam = Camera3D.new()
	_cam.fov = 38.0
	add_child(_cam)
	_cam.look_at_from_position(Vector3(1.6, 1.95, 7.2), Vector3(1.6, 1.0, 0.0))

	# 地面：一塊草地
	var ground := MeshInstance3D.new()
	ground.mesh = _cyl(30.0, 0.2, 48)
	var gm := StandardMaterial3D.new()
	gm.albedo_texture = load("res://assets/textures/grass_ground_diff_1k.jpg")
	gm.albedo_color = Color(0.80, 0.95, 0.62)
	gm.uv1_triplanar = true
	gm.uv1_scale = Vector3.ONE * 0.25
	gm.roughness = 1.0
	ground.material_override = gm
	ground.position.y = -0.1
	add_child(ground)
	# 後面的店面和擺設（共用的農場素材）
	_spawn_fit("res://assets/farm/OpenBarn.glb", Vector3(-0.4, 0, -8.6), 11.5, 0.0)
	_spawn_fit("res://assets/farm/Hay.glb", Vector3(-4.4, 0, -2.4), 1.5, 0.4)
	_spawn_fit("res://assets/nature/BirchTree.glb", Vector3(-6.2, 0, -4.4), 6.0, 0.8)
	_spawn_fit("res://assets/nature/AutumnTree.glb", Vector3(6.0, 0, -5.0), 6.0, 2.0)

	var W0 := Wardrobe
	# 試衣台：木頭圓台，上面一圈亮色、金色的邊
	var wood := Color(0.62, 0.42, 0.26)
	_mesh(self, _cyl(1.25, 0.22), wood.darkened(0.25), Vector3(0, 0.11, 0))
	_stand = Node3D.new()
	_stand.position.y = 0.22
	add_child(_stand)
	_mesh(_stand, _cyl(1.12, 0.06), wood, Vector3(0, 0.03, 0))
	_mesh(_stand, _cyl(0.82, 0.02), Color(0.98, 0.86, 0.5), Vector3(0, 0.065, 0))
	# 旁邊的小台子：地圖上圓滾滾的家豪也穿同一套
	_mesh(self, _cyl(0.55, 0.16), wood.darkened(0.25), Vector3(1.35, 0.08, 1.3))
	_mini = Node3D.new()
	_mini.position = Vector3(1.35, 0.16, 1.3)
	_mini.rotation.y = -0.3
	add_child(_mini)

	W0._p(_stand, W0._torus(1.06, 1.14), Color(0.96, 0.78, 0.2), Vector3(0, 0.06, 0), Vector3(1, 0.5, 1)).material_override = W0._gloss(Color(0.96, 0.78, 0.2), 0.35, 0.8)
	for k in 10:
		W0._p(_stand, W0._sphere(0.035, 8), Color(1.0, 0.95, 0.75), Vector3(cos(k * TAU / 10.0), 0.075, sin(k * TAU / 10.0)) * Vector3(0.95, 1, 0.95))
	_build_duck()
	_build_decor()
	_build_burst()
	_rebuild_hero()

## 鴨子老闆：共用的圓滾滾雞模型改成黃色、扁嘴，站在鹹酥雞攤後面
func _build_duck() -> void:
	_duck = Node3D.new()
	_duck.position = Vector3(-2.0, 0, -1.6)
	_duck.rotation.y = 0.45
	add_child(_duck)
	var chars := Node3D.new()
	chars.set_script(load("res://scripts/characters.gd"))
	_duck.add_child(chars)
	var d: Node3D = chars._make_round_chicken(false)
	chars.add_child(d)
	chars.scale = Vector3.ONE * 1.42
	for mi in d.find_children("*", "MeshInstance3D", true, false):
		var sph := (mi as MeshInstance3D).mesh as SphereMesh
		if sph:
			sph.radial_segments = 36
			sph.rings = 18
	for mi in d.find_children("*", "MeshInstance3D", true, false):
		var m := (mi as MeshInstance3D).material_override as ShaderMaterial
		if m == null:
			continue
		var c: Color = m.get_shader_parameter("albedo")
		if c.r > 0.85 and c.g > 0.85 and c.b > 0.85:           # 白羽毛 -> 黃
			m.set_shader_parameter("albedo", Color(0.99, 0.85, 0.30) if c.r > 0.93 else Color(0.93, 0.76, 0.24))
		elif c.r > 0.8 and c.g < 0.35:                          # 紅冠 -> 收掉
			(mi as MeshInstance3D).visible = false
		elif c.g > 0.7 and c.b < 0.4:                           # 尖嘴 -> 橘色扁嘴
			m.set_shader_parameter("albedo", Color(0.96, 0.52, 0.14))
			if (mi as MeshInstance3D).mesh is CylinderMesh and ((mi as MeshInstance3D).mesh as CylinderMesh).height > 0.12:
				(mi as MeshInstance3D).scale = Vector3(1.8, 1.0, 0.55)
	# 頭上的廚師帽
	var head := d.find_child("Head", true, false) as Node3D
	if head:
		_mesh(head, _cyl(0.17, 0.2, 16), Color(0.98, 0.98, 0.96), Vector3(0, 0.36, 0))
		var puff := SphereMesh.new()
		puff.radius = 0.23
		puff.height = 0.3
		_mesh(head, puff, Color(0.98, 0.98, 0.96), Vector3(0, 0.5, 0))
	# 攤子：木頭櫃檯、紅布條、油鍋、一盤炸好的、兩袋插著竹籤的鹹酥雞，旁邊立一塊菜單
	var W := Wardrobe
	var cart := Node3D.new()
	cart.position = Vector3(0, 0, 1.0)
	_duck.add_child(cart)
	var wood := Color(0.72, 0.5, 0.3)
	W._p(cart, W._rbox(Vector3(2.0, 0.85, 0.8), 0.04), wood, Vector3(0, 0.425, 0))
	W._p(cart, W._rbox(Vector3(2.12, 0.07, 0.9), 0.03), wood.darkened(0.25), Vector3(0, 0.87, 0))
	for k in 5:
		W._p(cart, W._rbox(Vector3(0.03, 0.5, 0.02), 0.008), wood.darkened(0.18), Vector3(-0.8 + k * 0.4, 0.3, 0.405))
	W._p(cart, W._rbox(Vector3(2.06, 0.3, 0.03), 0.012), Color(0.86, 0.2, 0.16), Vector3(0, 0.66, 0.41))
	for k in 9:      # 布條下緣的波浪邊
		W._p(cart, W._sphere(0.115, 14), Color(0.86, 0.2, 0.16) if k % 2 == 0 else Color(0.98, 0.95, 0.88), Vector3(-0.92 + k * 0.23, 0.51, 0.41), Vector3(1, 1, 0.14))
	var sign := Label3D.new()
	sign.text = "鹹酥雞"
	sign.font = UIStyle.font()
	sign.font_size = 96
	sign.pixel_size = 0.0027
	sign.modulate = Color(1, 0.95, 0.75)
	sign.outline_size = 14
	sign.outline_modulate = Color(0.45, 0.08, 0.06)
	sign.position = Vector3(0, 0.67, 0.43)
	cart.add_child(sign)
	# 油鍋：鍋子、金黃色的油、撈網
	var steel := W._gloss(Color(0.75, 0.77, 0.8), 0.35, 0.85)
	var pot := Node3D.new()
	pot.position = Vector3(0.62, 0.905, 0.02)
	cart.add_child(pot)
	W._p(pot, W._cyl(0.26, 0.22, 0.2, 32), Color(0.7, 0.72, 0.75), Vector3(0, 0.1, 0)).material_override = steel
	W._p(pot, W._torus(0.245, 0.275), Color(0.7, 0.72, 0.75), Vector3(0, 0.2, 0)).material_override = steel
	W._p(pot, W._cyl(0.245, 0.245, 0.01, 32), Color(0.98, 0.78, 0.25), Vector3(0, 0.185, 0))
	for k in 6:
		W._p(pot, W._sphere(0.045, 10), Color(0.80, 0.52, 0.2), Vector3(cos(k * 1.1) * 0.12, 0.19, sin(k * 1.1) * 0.12), Vector3(1.2, 0.6, 1))
	W._path(pot, [Vector3(0.2, 0.2, 0.1), Vector3(0.42, 0.32, 0.22), Vector3(0.52, 0.34, 0.26)], 0.014, Color(0.3, 0.2, 0.14))
	W._p(pot, W._torus(0.07, 0.085), Color(0.7, 0.72, 0.75), Vector3(0.13, 0.215, 0.06), Vector3(1, 0.6, 1)).material_override = steel
	# 一盤炸好的
	W._p(cart, W._rbox(Vector3(0.52, 0.04, 0.36), 0.015), Color(0.82, 0.84, 0.86), Vector3(-0.1, 0.925, 0.08)).material_override = steel
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for k in 16:
		var nug := Color(0.80, 0.53, 0.2).darkened(rng.randf() * 0.2)
		W._p(cart, W._sphere(0.05, 10), nug, Vector3(-0.1 + rng.randf_range(-0.19, 0.19), 0.965 + (0.04 if k > 10 else 0.0), 0.08 + rng.randf_range(-0.12, 0.12)), Vector3(rng.randf_range(0.9, 1.3), 0.75, rng.randf_range(0.9, 1.2)), Vector3(0, rng.randf() * 3.0, 0))
	# 兩袋包好的
	for k in 2:
		var bagn := Node3D.new()
		bagn.position = Vector3(-0.78 + k * 0.3, 0.905, 0.1 - k * 0.12)
		bagn.rotation.y = 0.3 - k * 0.5
		cart.add_child(bagn)
		W._p(bagn, W._rbox(Vector3(0.2, 0.28, 0.14), 0.012), Color(0.80, 0.63, 0.42), Vector3(0, 0.14, 0))
		W._p(bagn, W._rbox(Vector3(0.205, 0.03, 0.145), 0.008), Color(0.66, 0.5, 0.32), Vector3(0, 0.275, 0))
		W._p(bagn, W._cyl(0.004, 0.006, 0.2, 6), Color(0.9, 0.8, 0.55), Vector3(0.03, 0.34, 0), Vector3.ONE, Vector3(0, 0, -0.3))
		W._p(bagn, W._sphere(0.03, 10), Color(0.78, 0.5, 0.2), Vector3(0.06, 0.42, 0), Vector3(1, 0.85, 1))
		var bl := W._label(bagn, "鹹酥雞", Vector3(0, 0.15, 0.072), 0.0009, Color(0.82, 0.13, 0.1), 56)
		bl.rotation.z = 0.04

## 後面的佈置：掛著衣服的衣架、一串小燈泡
func _build_decor() -> void:
	var W := Wardrobe
	var metal := W._gloss(Color(0.78, 0.78, 0.8), 0.35, 0.8)
	var rack := Node3D.new()
	rack.position = Vector3(2.55, 0, -2.3)
	rack.rotation.y = -0.18
	add_child(rack)
	for sx in [-1.0, 1.0]:
		W._p(rack, W._cyl(0.035, 0.035, 2.0, 12), Color(0.78, 0.78, 0.8), Vector3(1.05 * sx, 1.0, 0)).material_override = metal
		W._p(rack, W._rbox(Vector3(0.12, 0.05, 0.7), 0.02), Color(0.3, 0.3, 0.32), Vector3(1.05 * sx, 0.03, 0))
	W._stroke(rack, Vector3(-1.05, 1.98, 0), Vector3(1.05, 1.98, 0), 0.03, Color(0.78, 0.78, 0.8), metal)
	var cols := [Color(0.09, 0.09, 0.1), Color(0.15, 0.21, 0.42), Color(1.0, 0.97, 0.87), Color(0.80, 0.90, 0.98), Color(0.93, 0.91, 0.85), Color(0.97, 0.5, 0.1)]
	for k in cols.size():
		var g := Node3D.new()
		g.position = Vector3(-0.85 + k * 0.34, 1.98, 0)
		g.rotation.y = PI * 0.5 + 0.25 * sin(k * 2.1)
		rack.add_child(g)
		W._p(g, W._torus(0.03, 0.042), Color(0.78, 0.78, 0.8), Vector3(0, -0.03, 0), Vector3.ONE, Vector3(PI * 0.5, 0, 0)).material_override = metal
		W._path(g, [Vector3(-0.2, -0.17, 0), Vector3(0, -0.07, 0), Vector3(0.2, -0.17, 0)], 0.012, Color(0.55, 0.4, 0.28))
		W._p(g, W._rbox(Vector3(0.4, 0.56, 0.1), 0.045), cols[k], Vector3(0, -0.46, 0))
		for sx in [-1.0, 1.0]:
			W._p(g, W._rbox(Vector3(0.11, 0.32, 0.09), 0.04), (cols[k] as Color).darkened(0.07), Vector3(0.235 * sx, -0.36, 0), Vector3.ONE, Vector3(0, 0, 0.3 * sx))
		W._p(g, W._torus(0.05, 0.075), (cols[k] as Color).darkened(0.2), Vector3(0, -0.19, 0), Vector3(1, 0.5, 0.7))
	# 吊在衣架上方的菜單黑板
	var wood := Color(0.72, 0.5, 0.3)
	var board := Node3D.new()
	board.position = Vector3(2.2, 2.2, -2.9)
	board.rotation = Vector3(0.05, -0.2, 0.03)
	board.scale = Vector3.ONE * 1.25
	add_child(board)
	for sx in [-1.0, 1.0]:
		W._stroke(board, Vector3(0.3 * sx, 1.08, 0), Vector3(0.3 * sx, 2.4, 0), 0.012, Color(0.3, 0.22, 0.16))
	W._p(board, W._rbox(Vector3(0.82, 1.0, 0.06), 0.02), wood.darkened(0.3), Vector3(0, 0.6, 0))
	W._p(board, W._rbox(Vector3(0.72, 0.88, 0.02), 0.01), Color(0.13, 0.2, 0.18), Vector3(0, 0.6, 0.03))
	var lines := [["今日菜單", 70, Color(1, 0.93, 0.6), 0.93], ["鹹酥雞　★1", 52, Color(0.95, 0.97, 0.95), 0.74],
		["甜不辣　★1", 52, Color(0.95, 0.97, 0.95), 0.58], ["九層塔　免費", 52, Color(0.7, 0.95, 0.75), 0.42], ["家豪　非賣品", 52, Color(1.0, 0.6, 0.55), 0.26]]
	for ln in lines:
		var ml := W._label(board, String(ln[0]), Vector3(0, float(ln[3]), 0.045), 0.0019, ln[2], int(ln[1]))
		ml.rotation.z = 0.015 * (1.0 if int(ln[1]) > 60 else -1.0)
	# 一串小燈泡，掛在店面前面
	var wire := []
	var bulbs := [Color(1.0, 0.85, 0.4), Color(1.0, 0.45, 0.4), Color(0.5, 0.9, 0.8), Color(1.0, 0.97, 0.9)]
	for k in 21:
		var t := k / 20.0
		wire.append(Vector3(-6.0 + t * 12.0, 3.7 - sin(t * PI) * 0.55, -3.6))
	W._path(self, wire, 0.012, Color(0.2, 0.16, 0.14))
	for k in range(1, 20):
		var bm := StandardMaterial3D.new()
		bm.albedo_color = bulbs[k % bulbs.size()]
		bm.emission_enabled = true
		bm.emission = bulbs[k % bulbs.size()]
		bm.emission_energy_multiplier = 1.6
		var bulb := W._p(self, W._sphere(0.085, 12), bulbs[k % bulbs.size()], (wire[k] as Vector3) + Vector3(0, -0.11, 0), Vector3(1, 1.25, 1))
		bulb.material_override = bm
		bulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

## 買到的時候在家豪身邊噴一圈金色小星星
func _build_burst() -> void:
	_burst = CPUParticles3D.new()
	_burst.emitting = false
	_burst.one_shot = true
	_burst.amount = 70
	_burst.lifetime = 1.1
	_burst.explosiveness = 0.92
	_burst.direction = Vector3.UP
	_burst.spread = 75.0
	_burst.initial_velocity_min = 2.6
	_burst.initial_velocity_max = 5.0
	_burst.gravity = Vector3(0, -7.5, 0)
	_burst.scale_amount_min = 0.5
	_burst.scale_amount_max = 1.2
	_burst.position = Vector3(0, 1.0, 0)
	var star := SphereMesh.new()
	star.radius = 0.035
	star.height = 0.07
	star.radial_segments = 8
	star.rings = 4
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(1.0, 0.82, 0.2)
	sm.emission_enabled = true
	sm.emission = Color(1.0, 0.78, 0.15)
	sm.emission_energy_multiplier = 1.4
	star.material = sm
	_burst.mesh = star
	add_child(_burst)

func _make_chars(parent: Node3D, round: bool, height: float) -> Node3D:
	var chars := Node3D.new()
	chars.set_script(load("res://scripts/characters.gd"))
	parent.add_child(chars)
	var c: Node3D = chars._make_round_chicken(true) if round else chars._make_standin_rooster(true)
	chars.add_child(c)
	var bb := _aabb(c, Transform3D.IDENTITY)
	if bb.size.y > 0.01:
		# 用沒有穿衣服時的身高當基準，換裝時家豪才不會忽大忽小
		chars.scale = Vector3.ONE * height
		chars.position.y = 0.0
	return chars

## 照現在的（試穿）穿著把家豪整個重做
func _rebuild_hero() -> void:
	if _chars:
		_chars.queue_free()
	if _mini_chars:
		_mini_chars.queue_free()
	_chars = _make_chars(_stand, false, 1.25)
	_chars.position.y = 0.07
	_mini_chars = _make_chars(_mini, true, 0.62)
	# 小的那一隻不用冒過關的字（大的那一隻冒就好，不然兩行字疊在一起）
	for l in _mini_chars.find_children("*", "Label3D", true, false):
		if not (l as Label3D).visible:
			l.queue_free()

# ================================================================== 縮圖

## 每件服裝的縮圖：各自一個小畫面，家豪只穿那一件，鏡頭對著那個部位拍一張
func _build_thumbs() -> void:
	var keep := Wardrobe.preview
	for it in Wardrobe.ITEMS:
		var id := String(it.id)
		var view: Array = VIEWS[String(THUMB_VIEW.get(id, "full"))]
		var vp := SubViewport.new()
		vp.size = Vector2i(352, 258)
		vp.own_world_3d = true
		vp.transparent_bg = true
		vp.msaa_3d = Viewport.MSAA_4X
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(vp)
		var env := Environment.new()
		env.background_mode = Environment.BG_CLEAR_COLOR
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(0.86, 0.84, 0.82)
		env.ambient_light_energy = 1.0
		var we := WorldEnvironment.new()
		we.environment = env
		vp.add_child(we)
		var yaw := float(view[2])
		var sun := DirectionalLight3D.new()
		sun.rotation = Vector3(-0.6, yaw - 0.55, 0)
		sun.light_energy = 1.3
		vp.add_child(sun)
		Wardrobe.preview = Wardrobe.with_item({"body": Wardrobe.DEFAULT_BODY}, id)
		var chars := Node3D.new()
		chars.set_script(load("res://scripts/characters.gd"))
		chars.set_process(false)
		vp.add_child(chars)
		chars.add_child(chars._make_standin_rooster(true))
		var cam := Camera3D.new()
		cam.fov = 30.0
		vp.add_child(cam)
		var target: Vector3 = view[0]
		var pitch := float(view[3])
		cam.look_at_from_position(target + Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * float(view[1]), target)
		cam.current = true
		_thumbs[id] = vp
	Wardrobe.preview = keep
	# 拍好就停，不用每個畫面都重畫
	get_tree().create_timer(0.5).timeout.connect(func():
		for id in _thumbs:
			(_thumbs[id] as SubViewport).render_target_update_mode = SubViewport.UPDATE_DISABLED)

# ================================================================== 介面

func _style(bg: Color, edge: Color, radius := 10, border := 2) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = edge
	s.set_border_width_all(border)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 3
	s.content_margin_bottom = 4
	s.anti_aliasing = true
	return s

func _lbl(text: String, size: int, col := INK) -> Label:
	var l := Label.new()
	l.text = text
	l.label_settings = UIStyle.ls(size, col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIStyle.apply_theme(root)
	layer.add_child(root)

	# 右邊：一格一格的服裝卡片（每格一張縮圖）
	var panel := PanelContainer.new()
	var ps := _style(Color(PAPER, 0.97), PAPER_EDGE, 18, 3)
	ps.content_margin_left = 18
	ps.content_margin_right = 18
	ps.content_margin_top = 12
	ps.content_margin_bottom = 16
	ps.shadow_color = Color(0, 0, 0, 0.25)
	ps.shadow_size = 8
	ps.shadow_offset = Vector2(3, 5)
	panel.add_theme_stylebox_override("panel", ps)
	root.add_child(panel)
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -PANEL_W
	panel.offset_right = -24
	panel.offset_top = -438
	panel.offset_bottom = 438
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	panel.add_child(col)
	var top := HBoxContainer.new()
	col.add_child(top)
	var title := _lbl("商店", 40, RED)
	top.add_child(title)
	var tgap := Control.new()
	tgap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(tgap)
	_combo = _lbl("隱藏組合 0／6", 20, Color("7a4b12"))
	_combo.add_theme_stylebox_override("normal", _style(Color("ffe2a8"), Color("d9a441"), 14, 2))
	_combo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(_combo)
	var tgap2 := Control.new()
	tgap2.custom_minimum_size.x = 10
	top.add_child(tgap2)
	_wallet = _lbl("★ 0", 30, INK)
	var ws := _style(Color("fff1bf"), Color("d9b84a"), 18, 3)
	ws.content_margin_left = 16
	ws.content_margin_right = 16
	_wallet.add_theme_stylebox_override("normal", ws)
	_wallet.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(_wallet)
	# 分類頁籤（數字鍵 1～5 或直接點）
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	col.add_child(tabs)
	for t in TABS.size():
		var tl := _lbl("", 19)
		tl.mouse_filter = Control.MOUSE_FILTER_STOP
		tl.gui_input.connect(_on_tab_input.bind(t))
		tabs.add_child(tl)
		_tab_btns.append({"label": tl})
	var grid := GridContainer.new()
	grid.columns = COLS
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	col.add_child(grid)
	for i in Wardrobe.ITEMS.size():
		var it: Dictionary = Wardrobe.ITEMS[i]
		var card := Control.new()
		card.custom_minimum_size = CARD
		card.pivot_offset = CARD * 0.5
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		card.gui_input.connect(_on_row_input.bind(i))
		grid.add_child(card)
		var bg := Panel.new()
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(bg)
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var plate := Panel.new()
		plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
		plate.add_theme_stylebox_override("panel", _style(Color("b7cbdb"), Color("9fb6c8"), 10, 1))
		plate.position = Vector2(7, 7)
		plate.size = Vector2(CARD.x - 14, CARD.y - 50)
		card.add_child(plate)
		var tex := TextureRect.new()
		tex.texture = (_thumbs[String(it.id)] as SubViewport).get_texture()
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tex.position = Vector2(6, 6)
		tex.size = Vector2(CARD.x - 12, CARD.y - 48)
		card.add_child(tex)
		var nm := _lbl(String(it.name), 19)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nm.position = Vector2(0, CARD.y - 40)
		nm.size = Vector2(CARD.x, 32)
		card.add_child(nm)
		var chip := _lbl("", 16)
		card.add_child(chip)
		chip.anchor_left = 1.0
		chip.anchor_right = 1.0
		chip.offset_right = -7
		chip.offset_top = 7
		chip.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		_rows.append({"panel": card, "bg": bg, "chip": chip, "tex": tex})
	# 最下面一排：眼睛三選一（免費），按 Tab 輪流換
	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(fill)
	var eyes := HBoxContainer.new()
	eyes.add_theme_constant_override("separation", 8)
	col.add_child(eyes)
	eyes.add_child(_lbl("家豪的眼睛（免費）", 18, Color(INK, 0.75)))
	var egap := Control.new()
	egap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	eyes.add_child(egap)
	for id in Wardrobe.EYES:
		var b := _lbl(String(Wardrobe.EYE_NAMES[id]), 18)
		b.mouse_filter = Control.MOUSE_FILTER_STOP
		b.gui_input.connect(_on_eye_input.bind(String(id)))
		eyes.add_child(b)
		_eye_btns.append({"id": String(id), "label": b})
	var tabk := UIStyle.keycap("Tab", 14)
	tabk.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	eyes.add_child(tabk)

	# 左上：鴨子老闆說的話
	var bubble := PanelContainer.new()
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bs := _style(Color(1, 1, 1, 0.97), INK, 20, 3)
	bs.content_margin_left = 18
	bs.content_margin_right = 18
	bs.content_margin_top = 10
	bs.content_margin_bottom = 12
	bubble.add_theme_stylebox_override("panel", bs)
	root.add_child(bubble)
	bubble.position = Vector2(28, 132)
	_quip = _lbl("", 24)
	_quip.custom_minimum_size.x = 0
	bubble.add_child(_quip)
	var who := _lbl("鴨老闆", 16, Color(1, 1, 1))
	who.add_theme_stylebox_override("normal", _style(Color("e8963a"), Color("9a5a14"), 10, 2))
	root.add_child(who)
	who.position = Vector2(44, 104)

	# 左下：現在選的這一件（名字、部位、說明、按 Enter 會怎樣）
	var info := PanelContainer.new()
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var isb := _style(Color(PAPER, 0.97), PAPER_EDGE, 14, 3)
	isb.content_margin_left = 20
	isb.content_margin_right = 20
	isb.content_margin_top = 12
	isb.content_margin_bottom = 14
	isb.shadow_color = Color(0, 0, 0, 0.22)
	isb.shadow_size = 6
	isb.shadow_offset = Vector2(2, 4)
	info.add_theme_stylebox_override("panel", isb)
	root.add_child(info)
	info.anchor_top = 1.0
	info.anchor_bottom = 1.0
	info.offset_left = 36
	info.offset_bottom = -62
	info.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var iv := VBoxContainer.new()
	iv.add_theme_constant_override("separation", 6)
	info.add_child(iv)
	var ih := HBoxContainer.new()
	ih.add_theme_constant_override("separation", 12)
	iv.add_child(ih)
	_name = _lbl("", 30)
	ih.add_child(_name)
	_slots = _lbl("", 16, Color(1, 1, 1))
	_slots.add_theme_stylebox_override("normal", _style(Color("8a7a66"), Color("6b5a48"), 10, 2))
	_slots.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ih.add_child(_slots)
	_state = _lbl("", 16, Color(1, 1, 1))
	_state.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ih.add_child(_state)
	_swap = _lbl("", 17, Color("b8651a"))
	_swap.visible = false
	_desc = _lbl("", 19, Color(INK, 0.85))
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.custom_minimum_size = Vector2(500, 0)
	iv.add_child(_desc)
	iv.add_child(_swap)
	var act := HBoxContainer.new()
	act.add_theme_constant_override("separation", 10)
	iv.add_child(act)
	_action = UIStyle.go_button("買", 24)
	act.add_child(_action)
	var kc := UIStyle.keycap("Enter", 16)
	_enter_key = kc
	kc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	act.add_child(kc)

	# 最下面：操作說明
	var hint := PanelContainer.new()
	UIStyle.slip(hint, Vector2(16, 6))
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hrow := HBoxContainer.new()
	hrow.add_theme_constant_override("separation", 22)
	hint.add_child(hrow)
	hrow.add_child(UIStyle.key_hint("方向鍵", "選", 18))
	hrow.add_child(UIStyle.key_hint("1～5", "分類", 18))
	hrow.add_child(UIStyle.key_hint("A／D", "轉", 18))
	hrow.add_child(UIStyle.key_hint("Tab", "換眼睛", 18))
	hrow.add_child(UIStyle.key_hint("空白鍵", "擺姿勢", 18))
	hrow.add_child(UIStyle.key_hint("Esc", "回地圖", 18))
	root.add_child(hint)
	hint.anchor_top = 1.0
	hint.anchor_bottom = 1.0
	hint.offset_left = 36
	hint.offset_bottom = -12
	hint.grow_vertical = Control.GROW_DIRECTION_BEGIN

	# 試衣台正上方：現在是試穿還是真的穿在身上
	var tbox := CenterContainer.new()
	tbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(tbox)
	tbox.anchor_right = 1.0
	tbox.offset_left = 230
	tbox.offset_right = -PANEL_W
	tbox.offset_top = 26
	tbox.offset_bottom = 80
	_try = _lbl("試穿中", 26, Color(1, 1, 1))
	tbox.add_child(_try)
	# 說明卡上面：買到了、星星不夠這類提示
	_toast = Label.new()
	_toast.label_settings = UIStyle.ls(26)
	UIStyle.pill(_toast)
	_toast.visible = false
	root.add_child(_toast)
	_toast.anchor_top = 1.0
	_toast.anchor_bottom = 1.0
	_toast.offset_left = 36
	_toast.offset_bottom = -272
	_toast.grow_vertical = Control.GROW_DIRECTION_BEGIN

func _chip_style(bg: Color, edge: Color) -> StyleBoxFlat:
	var s := _style(bg, edge, 11, 2)
	s.content_margin_left = 8
	s.content_margin_right = 8
	s.content_margin_top = 0
	s.content_margin_bottom = 1
	return s

func _refresh() -> void:
	var worn := Wardrobe.saved_look()
	_wallet.text = "★ %d" % Wardrobe.wallet()
	for t in _tab_btns.size():
		var on_tab := t == _tab
		var tl: Label = _tab_btns[t].label
		tl.text = "%s %d" % [String(TABS[t].name), _items_in(t).size()]
		tl.label_settings = UIStyle.ls(19, Color(1, 1, 1) if on_tab else INK)
		tl.add_theme_stylebox_override("normal", _style(INK if on_tab else Color(1, 1, 1, 0.8), INK if on_tab else PAPER_EDGE, 14, 2))
	var shown := _items_in(_tab)
	for i in _rows.size():
		(_rows[i].panel as Control).visible = shown.has(i)
	for i in _rows.size():
		var it: Dictionary = Wardrobe.ITEMS[i]
		var r: Dictionary = _rows[i]
		var own := Wardrobe.owned(it.id)
		var on := Wardrobe.is_worn(worn, it.id)
		var chip: Label = r.chip
		var txt := Color(1, 1, 1)
		var cbg := Color("5cb85c")
		var cedge := Color("3d8b3d")
		if on:
			chip.text = "穿著中"
		elif own:
			chip.text = "✓ 已擁有"
			cbg = Color("8a6f4d")
			cedge = Color("6b5438")
		elif int(it.price) < 0:
			chip.text = "全三星"
			cbg = Color("fff1bf")
			cedge = Color("d9b84a")
			txt = Color("8a6410")
		else:
			var can := Wardrobe.wallet() >= Wardrobe.price(it.id)
			chip.text = "★ %d" % Wardrobe.price(it.id)
			cbg = Color("fff1bf") if can else Color("f3ded8")
			cedge = Color("d9b84a") if can else Color("d9a79c")
			txt = INK if can else Color("b03a2e")
		chip.label_settings = UIStyle.ls(16, txt)
		chip.add_theme_stylebox_override("normal", _chip_style(cbg, cedge))
		var picked := i == sel
		var bg := Color("ffe98a") if picked else (Color("d9f0d2") if on else (Color("f1e3c6") if own else Color(1, 1, 1, 0.75)))
		var edge := INK if picked else (Color("7cc276") if on else (Color("c9ad7c") if own else Color(PAPER_EDGE, 0.9)))
		var sb := _style(bg, edge, 14, 4 if picked else 2)
		if picked:
			sb.shadow_color = Color(0, 0, 0, 0.25)
			sb.shadow_size = 6
			sb.shadow_offset = Vector2(2, 4)
		(r.bg as Panel).add_theme_stylebox_override("panel", sb)
		var card: Control = r.panel
		card.scale = Vector2.ONE * (1.03 if picked else 1.0)
		card.z_index = 1 if picked else 0
		# 還沒買的縮圖淡一點
		(r.tex as TextureRect).modulate = Color(1, 1, 1, 1.0 if own or picked else 0.82)
	var eye_now := Wardrobe.eyes()
	for eb in _eye_btns:
		var on_eye: bool = eb.id == eye_now
		var el: Label = eb.label
		el.label_settings = UIStyle.ls(19, Color(1, 1, 1) if on_eye else INK)
		var es := _style(INK if on_eye else Color(1, 1, 1, 0.8), INK if on_eye else PAPER_EDGE, 14, 2)
		el.add_theme_stylebox_override("normal", es)
	var cur: Dictionary = Wardrobe.ITEMS[sel]
	_name.text = String(cur.name)
	var parts: Array = []
	for s in cur.slots:
		parts.append(String(Wardrobe.SLOT_NAMES[s]))
	_slots.text = "＋".join(parts)
	_desc.text = String(cur.desc).replace("。", "。\n").strip_edges()      # 一句一行，才不會剩一個字掉到下一行
	# 現在是試穿還是真的穿著；穿上這一件會換掉身上的哪一件
	var cur_on := Wardrobe.is_worn(worn, cur.id)
	var cur_own := Wardrobe.owned(cur.id)
	_state.text = "穿著中" if cur_on else ("已擁有・試穿中" if cur_own else "試穿中")
	_state.add_theme_stylebox_override("normal", _chip_style(Color("5cb85c") if cur_on else Color("e8963a"), Color("3d8b3d") if cur_on else Color("9a5a14")))
	var out: Array = []
	if not cur_on:
		for s in cur.slots:
			var other := String(worn.get(s, ""))
			if other != "" and other != Wardrobe.DEFAULT_BODY and other != String(cur.id):
				var nm := String(Wardrobe.item(other).name)
				if not out.has(nm):
					out.append(nm)
	_swap.visible = not out.is_empty()
	_swap.text = "穿上會換掉：" + "、".join(out)
	# 試衣台上方的大標籤
	_try.text = "穿著中" if cur_on else "試穿中・還沒買" if not cur_own else "試穿中・Enter 穿上"
	var tsb := _style(Color("4cae4c") if cur_on else Color("e8963a"), Color("2f7d2f") if cur_on else Color("9a5a14"), 20, 3)
	tsb.content_margin_left = 20
	tsb.content_margin_right = 20
	tsb.content_margin_top = 5
	tsb.content_margin_bottom = 7
	_try.add_theme_stylebox_override("normal", tsb)
	# 鴨老闆：臨時的話 > 湊到組合的話 > 這一件的吐槽
	var combo := Wardrobe.combo_line(Wardrobe.look(), String(cur.id))
	if combo != "" and Wardrobe.mark_combo(combo):
		# 第一次湊到：老闆先講組合的話（蓋過「謝謝惠顧」），提示也接在後面
		_say = ""
		_show_toast((_toast.text + "　＋ 發現隱藏組合！") if _toast.visible else "發現隱藏組合！")
		_play("arrive")
	_combo.text = "隱藏組合 %d／%d" % [Wardrobe.combos_found(), Wardrobe.COMBOS.size()]
	var line := _say if _say != "" else (combo if combo != "" else String(cur.quip))
	if line.length() > 13:      # 太長的話在中間的標點後面換一行（不會剩一個字掉下去）
		for mark in ["，", "？", "。", "、"]:
			var at := line.find(mark, 4)
			if at >= 0 and at < line.length() - 3:
				line = line.substr(0, at + 1) + "\n" + line.substr(at + 1)
				break
	_quip.text = line
	# 主按鈕：買得起是綠的；買不起、還不能拿是灰的，直接寫差多少
	var a := "買 ★%d" % Wardrobe.price(cur.id)
	var can_act := true
	if cur_on:
		a = "脫掉"
	elif cur_own:
		a = "穿上"
	elif int(cur.price) < 0:
		a = "全部關卡三星才送" if Wardrobe.stars_max() <= 0 else "三星進度 %d／%d" % [mini(Wardrobe.stars_total(), Wardrobe.stars_max()), Wardrobe.stars_max()]
		can_act = false
	elif Wardrobe.wallet() < Wardrobe.price(cur.id):
		a = "還差 ★%d" % (Wardrobe.price(cur.id) - Wardrobe.wallet())
		can_act = false
	_action.text = a
	if can_act:
		UIStyle.pill(_action, UIStyle.GO, UIStyle.GO_EDGE, Color(1, 1, 1))
	else:
		UIStyle.pill(_action, Color("ddd6c8"), Color("a39a8a"), Color("5a4634"))
	_enter_key.modulate.a = 1.0 if can_act else 0.3

## 選到第 i 件：家豪先試穿（已經穿在身上的就維持原樣）
func _select(i: int, quiet := false) -> void:
	sel = clampi(i, 0, Wardrobe.ITEMS.size() - 1)
	var id := String(Wardrobe.ITEMS[sel].id)
	Wardrobe.preview = Wardrobe.with_item(Wardrobe.saved_look(), id)
	_rebuild_hero()
	_say = ""
	_refresh()
	# 背後的東西：把家豪轉過去給你看
	_spin = PI + 0.6 if String(THUMB_VIEW.get(id, "")).begins_with("back") else 0.5
	_spin_hold = 3.0
	if id == "azhi":      # 正面有耳機和金鍊、背後有圖案：先給正面，馬上慢慢轉一圈
		_spin_hold = 0.7
	if not quiet:
		_play("click")

## 第 t 個分頁裡有哪幾件（服裝的索引）
func _items_in(t: int) -> Array:
	var out: Array = []
	var want: Array = TABS[t].slots
	for i in Wardrobe.ITEMS.size():
		var ok := want.is_empty()
		for s in Wardrobe.ITEMS[i].slots:
			ok = ok or want.has(s)
		if ok:
			out.append(i)
	return out

func _set_tab(t: int) -> void:
	t = clampi(t, 0, TABS.size() - 1)
	if t == _tab:
		return
	_tab = t
	var shown := _items_in(t)
	_play("click")
	_select(sel if shown.has(sel) else int(shown[0]), true)

func _on_tab_input(ev: InputEvent, t: int) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		_set_tab(t)

## 方向鍵在目前分頁的格子裡移動（超出邊界就不動）
func _move(dx: int, dy: int) -> void:
	var shown := _items_in(_tab)
	var p := shown.find(sel)
	var cx := p % COLS + dx
	var q := p + dx + dy * COLS
	if cx < 0 or cx >= COLS or q < 0 or q >= shown.size():
		_play("bump")
		return
	_select(int(shown[q]))

## 點鹹酥雞老闆：講一句規矩，連點 10 下得貼紙
func _poke_duck() -> void:
	var now := Time.get_ticks_msec()
	_duck_n = _duck_n + 1 if now - _duck_last <= DUCK_GAP_MS else 1
	_duck_last = now
	_say = String(DUCK_LINES[_duck_i % DUCK_LINES.size()])
	_duck_i += 1
	_duck_hop = 0.35
	_play("click")
	_refresh()
	if _duck_n >= DUCK_STREAK:
		_duck_n = 0
		if not Journal.has("flag", "duck_red"):
			Journal.mark("flag", "duck_red")
			_show_toast("獲得貼紙：前途一片紅果（到手帳看）")
			_play("start")
			_burst.restart()
			_burst.emitting = true

func _is_duck_hit(pos: Vector2) -> bool:
	var o := _cam.project_ray_origin(pos)
	var d := _cam.project_ray_normal(pos)
	var c := _duck.global_position + Vector3(0, 0.95, 0.3)
	var oc := c - o
	var t := oc.dot(d)
	return t > 0.0 and (oc - d * t).length() < 1.05

## Enter：買／穿／脫
func act() -> void:
	var it: Dictionary = Wardrobe.ITEMS[sel]
	var id := String(it.id)
	var worn := Wardrobe.saved_look()
	if Wardrobe.is_worn(worn, id):
		Wardrobe.save_look(Wardrobe.without_item(worn, id))
		Wardrobe.preview = Wardrobe.saved_look()
		_rebuild_hero()
		_say = "脫了也好，省得洗。"
		_play("click")
	elif Wardrobe.owned(id):
		Wardrobe.save_look(Wardrobe.with_item(worn, id))
		Wardrobe.preview = Wardrobe.saved_look()
		_rebuild_hero()
		_say = ""
		_play("arrive")
	elif int(it.price) < 0:
		_show_toast("學士服不賣：全部關卡都拿三星就送你")
		_say = "先把學分修完再說。"
		_play("bump")
	elif Wardrobe.buy(id):
		Wardrobe.save_look(Wardrobe.with_item(worn, id))
		_show_toast("買到了：%s　★ −%d" % [String(it.name), Wardrobe.price(id)])
		# 剛好湊成組合的話，讓老闆講組合的那一句
		_say = "" if Wardrobe.combo_line(Wardrobe.saved_look(), id) != "" else "謝謝惠顧，不找零。"
		_play("start")
		_pose_t = 2.5
		_spin = 0.4
		_spin_hold = 3.0
		_burst.restart()
		_burst.emitting = true
	else:
		_show_toast("星星不夠，還差 %d 顆" % (Wardrobe.price(id) - Wardrobe.wallet()))
		_say = "本攤不賒帳。"
		_play("bump")
	_refresh()

## 換眼睛：家豪轉回正面給你看
func set_eyes(id: String) -> void:
	Wardrobe.set_eyes(id)
	_rebuild_hero()
	_refresh()
	_spin = 0.35
	_spin_hold = 3.0
	_play("click")

func _on_eye_input(ev: InputEvent, id: String) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		set_eyes(id)

func _show_toast(t: String) -> void:
	_toast.text = t
	_toast.visible = true
	_toast_t = 2.2

func _leave() -> void:
	if _leaving:
		return
	_leaving = true
	Wardrobe.preview = {}
	Wardrobe.Fx.demo_win = false
	LoadingCard.go(get_tree(), MAP_SCENE, "回到地圖")

func _on_row_input(ev: InputEvent, i: int) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		if i == sel:
			act()
		else:
			_select(i)

func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		if _is_duck_hit(ev.position):
			_poke_duck()
		return
	if ev is InputEventKey and ev.pressed:
		if ev.keycode >= KEY_1 and ev.keycode <= KEY_5 and not ev.echo:
			_set_tab(ev.keycode - KEY_1)
			return
		match ev.keycode:
			KEY_UP:
				_move(0, -1)
			KEY_DOWN:
				_move(0, 1)
			KEY_LEFT:
				_move(-1, 0)
			KEY_RIGHT:
				_move(1, 0)
			KEY_ENTER, KEY_KP_ENTER:
				if not ev.echo:
					act()
			KEY_TAB:
				if not ev.echo:
					set_eyes(Wardrobe.EYES[(Wardrobe.EYES.find(Wardrobe.eyes()) + 1) % Wardrobe.EYES.size()])
			KEY_SPACE:
				if not ev.echo:
					_pose_t = 2.5
					_play("arrive")
			KEY_ESCAPE, KEY_B:
				if not ev.echo:
					_leave()

func _process(dt: float) -> void:
	_t += dt
	var turn := 0.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_Q):
		turn -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_E):
		turn += 1.0
	if turn != 0.0:
		_spin += turn * 2.6 * dt
		_spin_hold = 2.5
	else:
		_spin_hold = maxf(_spin_hold - dt, 0.0)
		if _spin_hold <= 0.0 and _pose_t <= 0.0:
			_spin += 0.45 * dt
	_stand.rotation.y = lerp_angle(_stand.rotation.y, _spin, minf(dt * 8.0, 1.0))
	_pose_t = maxf(_pose_t - dt, 0.0)
	Wardrobe.Fx.demo_win = _pose_t > 0.0
	_try.visible = _pose_t <= 0.0      # 擺姿勢的時候頭上會冒字，標籤先讓開
	if _chars:
		_chars.position.y = 0.07 + (absf(sin(_t * 9.0)) * 0.12 if _pose_t > 0.0 else 0.0)
	if _duck:
		_duck_hop = maxf(_duck_hop - dt, 0.0)
		_duck.position.y = absf(sin(_t * 2.0)) * 0.03 + sin(_duck_hop / 0.35 * PI) * 0.18
	if _toast_t > 0.0:
		_toast_t -= dt
		if _toast_t <= 0.0:
			_toast.visible = false

# ================================================================== 音效（跟選關地圖同一組合成音）

func _build_audio() -> void:
	var defs := {"click": LevelSelect._snd_click(), "arrive": LevelSelect._snd_arrive(),
		"bump": LevelSelect._snd_bump(), "start": LevelSelect._snd_start()}
	for id in defs:
		var p := AudioStreamPlayer.new()
		p.stream = defs[id]
		p.volume_db = -6.0
		add_child(p)
		_snd[id] = p

func _play(id: String) -> void:
	if _snd.has(id):
		(_snd[id] as AudioStreamPlayer).play()

# ================================================================== 開發用：每件服裝截一張圖

func _shots(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	await get_tree().create_timer(0.6).timeout
	for id in _thumbs:
		(_thumbs[id] as SubViewport).get_texture().get_image().save_png(dir.path_join("thumb_%s.png" % id))
	for i in Wardrobe.ITEMS.size():
		var id := String(Wardrobe.ITEMS[i].id)
		for view in 2:
			sel = i
			Wardrobe.preview = Wardrobe.with_item({"body": Wardrobe.DEFAULT_BODY}, id)
			if id == "silver":
				Wardrobe.preview = Wardrobe.with_item(Wardrobe.preview, "leather")
			_rebuild_hero()
			_refresh()
			_spin = 0.45 if view == 0 else PI + 0.5
			_stand.rotation.y = _spin
			_spin_hold = 99.0
			_mini.rotation.y = -0.3 if view == 0 else PI - 0.4
			_pose_t = 99.0 if view == 1 else 0.0
			await get_tree().create_timer(0.5).timeout
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(dir.path_join("shop_%02d_%s_%d.png" % [i, id, view]))
	get_tree().quit()

# ================================================================== 開發用：照玩家的流程走一遍，每一步截一張圖

## 一定要搭配 -- --wardrobe=user://測試檔名.cfg（用另外的存檔，不動玩家的），建議再加 --stars=6。
## 流程：進商店 → 每一件看一眼 → 買口罩 → 買皮衣 → 買銀髮（錢花光）→ 星星不夠 → 學士服還不能拿 → 脫口罩 → 換眼睛 → 擺姿勢
func _board(dir: String) -> void:
	if Wardrobe.save_path() == Wardrobe.PATH:
		push_error("--shopboard 要搭配 --wardrobe=（不然會動到玩家的存檔）")
		get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute(dir)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Wardrobe.save_path()))
	var idx := func(id: String) -> int:
		for i in Wardrobe.ITEMS.size():
			if Wardrobe.ITEMS[i].id == id:
				return i
		return 0
	var snap := func(name: String, wait: float) -> void:
		await get_tree().create_timer(wait).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(dir.path_join(name + ".png"))
	_select(0, true)
	await snap.call("01_enter", 0.8)
	for i in Wardrobe.ITEMS.size():
		_select(i, true)
		await snap.call("02_item_%02d_%s" % [i, String(Wardrobe.ITEMS[i].id)], 0.7)
	_select(idx.call("mask"), true)
	act()
	await snap.call("03_buy_mask", 0.5)
	_pose_t = 0.0
	_select(idx.call("leather"), true)
	act()
	await snap.call("04_buy_leather_pose", 0.9)
	_pose_t = 0.0
	_select(idx.call("silver"), true)
	act()
	await snap.call("05_buy_silver", 0.5)
	_pose_t = 0.0
	_toast.visible = false
	_select(idx.call("cleanroom"), true)
	act()
	await snap.call("06_not_enough", 0.5)
	_select(idx.call("gown"), true)
	act()
	await snap.call("07_gown_locked", 0.5)
	_toast.visible = false
	_select(idx.call("mask"), true)
	await snap.call("08_worn_mask_selected", 0.6)
	act()
	await snap.call("09_mask_on", 0.6)
	act()
	await snap.call("09b_mask_off", 0.6)
	act()
	set_eyes("drawn")
	await snap.call("10_eyes_drawn", 0.8)
	set_eyes("dot")
	await snap.call("11_eyes_dot", 0.8)
	set_eyes("drawn")
	_select(idx.call("leather"), true)
	_pose_t = 2.5
	await snap.call("12_pose_gpu", 0.9)
	var f := FileAccess.open(dir.path_join("DONE"), FileAccess.WRITE)
	if f:
		f.store_string("ok")
		f.close()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Wardrobe.save_path()))
	get_tree().quit()
