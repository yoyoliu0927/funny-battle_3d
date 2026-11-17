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
const MAP_SCENE := "res://scenes/level_select.tscn"

const INK := Color("3b2a20")
const PAPER := Color("fff8e7")
const PAPER_EDGE := Color("d9c9a8")
const GOLD := Color("f2c230")
const GREEN := Color("5cb85c")
const RED := Color("e2483d")

const COLS := 3                        # 卡片一排幾張
const CARD := Vector2(190, 186)        # 一張卡片多大
const PANEL_W := 656.0                 # 右邊那塊面板佔多寬（含邊距）
## 每件服裝的縮圖從哪個角度拍
const THUMB_VIEW := {"tag": "chest", "mask": "head", "slippers": "full", "bag": "headwide", "allnighter": "full", "silver": "head",
	"delivery": "back", "azhi": "back", "cleanroom": "full", "colonel": "tall", "leather": "full", "gown": "tall"}
## 角度：[鏡頭看哪裡, 距離, 左右轉幾度（弧度）, 往上抬幾度]
const VIEWS := {
	"full": [Vector3(0, 0.74, 0.05), 3.05, 0.5, 0.14],
	"tall": [Vector3(0, 0.9, 0.05), 3.7, 0.5, 0.12],
	"head": [Vector3(0, 1.17, 0.18), 1.95, 0.45, 0.1],
	"headwide": [Vector3(0, 1.25, 0.12), 2.3, 0.45, 0.1],
	"back": [Vector3(0, 0.74, -0.2), 3.0, PI - 0.45, 0.16],
	"chest": [Vector3(-0.1, 0.86, 0.3), 1.5, -0.3, 0.08],
}

var sel := 0
var _thumbs := {}            # 服裝 id -> 拍縮圖的小畫面（SubViewport）
var _name: Label
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

func _ready() -> void:
	_build_stage()
	_build_thumbs()
	_build_ui()
	_build_audio()
	_select(0, true)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shopshots="):
			_shots.call_deferred(a.substr(12))

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
	_cam.look_at_from_position(Vector3(2.2, 1.9, 7.0), Vector3(2.2, 0.95, 0.0))

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
	_spawn_fit("res://assets/farm/OpenBarn.glb", Vector3(-0.4, 0, -7.5), 9.0, 0.0)
	_spawn_fit("res://assets/farm/Hay.glb", Vector3(-4.4, 0, -2.4), 1.5, 0.4)
	_spawn_fit("res://assets/farm/Hay.glb", Vector3(3.4, 0, -2.8), 1.5, -0.3)
	_spawn_fit("res://assets/nature/BirchTree.glb", Vector3(-6.2, 0, -4.4), 6.0, 0.8)
	_spawn_fit("res://assets/nature/AutumnTree.glb", Vector3(6.0, 0, -5.0), 6.0, 2.0)

	# 試衣台：木頭圓台，上面一圈亮色
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

	_build_duck()
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
	chars.scale = Vector3.ONE * 1.55
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
	# 攤子：桌子、紅布條、一袋一袋的鹹酥雞
	var cart := Node3D.new()
	cart.position = Vector3(0, 0, 1.0)
	_duck.add_child(cart)
	_mesh(cart, _box(Vector3(2.0, 0.85, 0.8)), Color(0.72, 0.5, 0.3), Vector3(0, 0.425, 0))
	_mesh(cart, _box(Vector3(2.1, 0.3, 0.84)), Color(0.86, 0.2, 0.16), Vector3(0, 0.62, 0))
	for k in 3:
		_mesh(cart, _box(Vector3(0.24, 0.3, 0.2)), Color(0.80, 0.63, 0.42), Vector3(-0.6 + k * 0.6, 1.0, 0.0), Vector3(0, 0.2 * (k - 1), 0.06 * (k - 1)))
	var sign := Label3D.new()
	sign.text = "鹹酥雞"
	sign.font = UIStyle.font()
	sign.font_size = 96
	sign.pixel_size = 0.0028
	sign.modulate = Color(1, 0.95, 0.75)
	sign.position = Vector3(0, 0.62, 0.43)
	cart.add_child(sign)

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
	panel.offset_top = -426
	panel.offset_bottom = 426
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	panel.add_child(col)
	var top := HBoxContainer.new()
	col.add_child(top)
	var title := _lbl("商店", 40, RED)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	_wallet = _lbl("★ 0", 30, INK)
	var ws := _style(Color("fff1bf"), Color("d9b84a"), 18, 3)
	ws.content_margin_left = 16
	ws.content_margin_right = 16
	_wallet.add_theme_stylebox_override("normal", ws)
	_wallet.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(_wallet)
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
	bubble.position = Vector2(40, 150)
	_quip = _lbl("", 24)
	_quip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_quip.custom_minimum_size.x = 300
	bubble.add_child(_quip)
	var who := _lbl("鴨老闆", 16, Color(1, 1, 1))
	who.add_theme_stylebox_override("normal", _style(Color("e8963a"), Color("9a5a14"), 10, 2))
	root.add_child(who)
	who.position = Vector2(56, 122)

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
	_desc = _lbl("", 19, Color(INK, 0.85))
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.custom_minimum_size = Vector2(430, 0)
	iv.add_child(_desc)
	var act := HBoxContainer.new()
	act.add_theme_constant_override("separation", 10)
	iv.add_child(act)
	_action = UIStyle.go_button("買", 24)
	act.add_child(_action)
	var kc := UIStyle.keycap("Enter", 16)
	kc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	act.add_child(kc)

	# 最下面：操作說明
	var hint := PanelContainer.new()
	UIStyle.slip(hint, Vector2(16, 6))
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hrow := HBoxContainer.new()
	hrow.add_theme_constant_override("separation", 22)
	hint.add_child(hrow)
	hrow.add_child(UIStyle.key_hint("方向鍵", "選", 14))
	hrow.add_child(UIStyle.key_hint("A／D", "轉", 14))
	hrow.add_child(UIStyle.key_hint("空白鍵", "擺姿勢", 14))
	hrow.add_child(UIStyle.key_hint("Esc", "回地圖", 14))
	root.add_child(hint)
	hint.anchor_top = 1.0
	hint.anchor_bottom = 1.0
	hint.offset_left = 36
	hint.offset_bottom = -12
	hint.grow_vertical = Control.GROW_DIRECTION_BEGIN

	# 上面（3D 畫面那一半的正中間）：提示字卡
	var tbox := CenterContainer.new()
	tbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(tbox)
	tbox.anchor_right = 1.0
	tbox.offset_right = -PANEL_W
	tbox.offset_top = 34
	tbox.offset_bottom = 94
	_toast = Label.new()
	_toast.label_settings = UIStyle.ls(28)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIStyle.pill(_toast)
	_toast.visible = false
	tbox.add_child(_toast)

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
			chip.text = "已擁有"
			cbg = Color("a59a8c")
			cedge = Color("857a6c")
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
		var bg := Color("ffe98a") if picked else (Color("e4f4de") if on else Color(1, 1, 1, 0.7))
		var edge := INK if picked else (Color("8fcf8a") if on else Color(PAPER_EDGE, 0.9))
		var sb := _style(bg, edge, 14, 4 if picked else 2)
		if picked:
			sb.shadow_color = Color(0, 0, 0, 0.25)
			sb.shadow_size = 6
			sb.shadow_offset = Vector2(2, 4)
		(r.bg as Panel).add_theme_stylebox_override("panel", sb)
		var card: Control = r.panel
		card.scale = Vector2.ONE * (1.06 if picked else 1.0)
		card.z_index = 1 if picked else 0
		# 還沒買的縮圖淡一點
		(r.tex as TextureRect).modulate = Color(1, 1, 1, 1.0 if own or picked else 0.82)
	var cur: Dictionary = Wardrobe.ITEMS[sel]
	_name.text = String(cur.name)
	var parts: Array = []
	for s in cur.slots:
		parts.append(String(Wardrobe.SLOT_NAMES[s]))
	_slots.text = "＋".join(parts)
	_desc.text = String(cur.desc)
	_quip.text = String(cur.quip)
	var a := "買 ★%d" % Wardrobe.price(cur.id)
	if Wardrobe.is_worn(worn, cur.id):
		a = "脫掉"
	elif Wardrobe.owned(cur.id):
		a = "穿上"
	elif int(cur.price) < 0:
		a = "還不能拿"
	_action.text = a

## 選到第 i 件：家豪先試穿（已經穿在身上的就維持原樣）
func _select(i: int, quiet := false) -> void:
	sel = clampi(i, 0, Wardrobe.ITEMS.size() - 1)
	var id := String(Wardrobe.ITEMS[sel].id)
	Wardrobe.preview = Wardrobe.with_item(Wardrobe.saved_look(), id)
	_rebuild_hero()
	_refresh()
	# 背後的東西：把家豪轉過去給你看
	_spin = PI + 0.55 if String(THUMB_VIEW.get(id, "")) == "back" else 0.5
	_spin_hold = 3.0
	if not quiet:
		_play("click")

## 方向鍵在格子裡移動（超出邊界就不動）
func _move(dx: int, dy: int) -> void:
	var n := Wardrobe.ITEMS.size()
	var cx := sel % COLS + dx
	var j := sel + dx + dy * COLS
	if cx < 0 or cx >= COLS or j < 0 or j >= n:
		_play("bump")
		return
	_select(j)

## Enter：買／穿／脫
func act() -> void:
	var it: Dictionary = Wardrobe.ITEMS[sel]
	var id := String(it.id)
	var worn := Wardrobe.saved_look()
	if Wardrobe.is_worn(worn, id):
		Wardrobe.save_look(Wardrobe.without_item(worn, id))
		Wardrobe.preview = Wardrobe.saved_look()
		_rebuild_hero()
		_play("click")
	elif Wardrobe.owned(id):
		Wardrobe.save_look(Wardrobe.with_item(worn, id))
		_play("arrive")
	elif int(it.price) < 0:
		_show_toast("全部關卡三星才拿得到（%d／%d）" % [mini(Wardrobe.stars_total(), Wardrobe.stars_max()), Wardrobe.stars_max()])
		_play("bump")
	elif Wardrobe.buy(id):
		Wardrobe.save_look(Wardrobe.with_item(worn, id))
		_show_toast("買到了：%s" % String(it.name))
		_play("start")
		_pose_t = 2.5
	else:
		_show_toast("星星不夠，還差 %d 顆" % (Wardrobe.price(id) - Wardrobe.wallet()))
		_play("bump")
	_refresh()

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
	get_tree().change_scene_to_file(MAP_SCENE)

func _on_row_input(ev: InputEvent, i: int) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		if i == sel:
			act()
		else:
			_select(i)

func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed:
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
	if _chars:
		_chars.position.y = 0.07 + (absf(sin(_t * 9.0)) * 0.12 if _pose_t > 0.0 else 0.0)
	if _duck:
		_duck.position.y = absf(sin(_t * 2.0)) * 0.03
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
