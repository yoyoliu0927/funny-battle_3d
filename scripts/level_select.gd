extends Node3D
## 選關地圖（2.5D）
##
## 一座像橫躺台灣的小島（參考古地圖「Het Eyland Formosa」那樣轉了 90 度：左邊是北、山脈在後方）。
## 每個大關一支旗子（從 scripts/registry.gd 自動找到 levels/*/chapter.gd），沿著西部平原用虛線連起來。
## 風格沿用遊戲內：同一套天空、霧、卡通光影、地形著色與低多邊形樹。
## template 的一部分：各關不要改這個檔案，大關的名字、城市、小關都寫在自己的 chapter.gd。
##
## 操作：← → 選大關、↑ ↓ 或數字鍵選小關、Enter 開始；滑鼠移到旗子上會選取，點一下開始。

const TerrainShader := preload("res://shaders/terrain.gdshader")
const Progress := preload("res://scripts/progress.gd")
const Registry := preload("res://scripts/registry.gd")
const UIStyle := preload("res://scripts/ui/ui_style.gd")   # 全遊戲共用的介面美術
const TEX := "res://assets/textures/"

## 城市在地圖上的位置（由南往北）。大關的 chapter.gd 寫了 CITY 就放那裡，沒寫就照順序補空位。
const CITIES := [
	["高雄", Vector2(12.6, 6.8)], ["台南", Vector2(8.7, 8.8)], ["台中", Vector2(-5.6, 7.0)],
	["新竹", Vector2(-13.6, 4.4)], ["台北", Vector2(-17.9, -0.1)],
]
## 城市不夠用時的備用位置（沿海）
const SPARE_POS := [Vector2(2.0, 10.4), Vector2(-9.8, 8.2), Vector2(15.5, 4.0), Vector2(-19.5, 2.4)]

## 大關（照 Registry 排好，每個多一個 pos 和 city）
var LEVELS: Array = []

## 島的輪廓：用台灣海岸線的經緯度換算，轉 90 度並擺正成水平（北在左、西岸朝鏡頭、東岸在後方）
const OUTLINE := [
	Vector2(-21.5, 0.0), Vector2(-20.0, -2.5), Vector2(-18.9, -5.8), Vector2(-16.5, -4.2),
	Vector2(-13.6, -5.2), Vector2(-5.8, -3.8), Vector2(-0.7, -3.5), Vector2(5.7, -3.2),
	Vector2(10.4, -1.4), Vector2(15.9, 0.5), Vector2(21.5, 0.0), Vector2(21.3, 1.4),
	Vector2(16.3, 3.9), Vector2(13.9, 8.1), Vector2(9.5, 10.8), Vector2(4.1, 11.7),
	Vector2(-3.1, 10.6), Vector2(-7.2, 9.0), Vector2(-14.1, 5.8), Vector2(-17.5, 4.4),
	Vector2(-19.7, 1.3),
]
## 中央山脈的稜線（沿東側，從宜蘭一路到恆春半島收尾）
const RIDGE := [Vector2(-14.9, -0.5), Vector2(-12.5, 0.6), Vector2(-9.8, 1.2), Vector2(1.6, 1.9), Vector2(12.9, 1.6), Vector2(17.9, 1.3)]
## 旁邊的小島：澎湖、綠島、蘭嶼
const ISLETS := [[Vector2(3.6, 16.6), 1.1], [Vector2(5.5, 17.4), 0.7], [Vector2(2.4, 17.6), 0.6], [Vector2(10.7, -5.6), 0.6], [Vector2(18.1, -7.5), 0.8]]

const GRID_X := 150
const GRID_Z := 96
const MAP_MIN := Vector2(-28.0, -16.0)
const MAP_MAX := Vector2(28.0, 20.0)

var selected := 0
var stage_sel := 0           # 目前大關裡選的小關（0 開始）
var cleared := 0             # 從頭數過來連續全破的大關數（畫路線顏色、家豪站的位置用）
var _noise := FastNoiseLite.new()
var _markers: Array = []      # {root, flag, ring, label}
var _hero: Node3D
var _cam: Camera3D
var _cam_base := Vector3.ZERO
var _t := 0.0
var _title: Label
var _info: Label
var _hint: Label
var _toast: Label
var _toast_t := 0.0
var _starting := false

func _ready() -> void:
	_noise.seed = 1624
	_noise.frequency = 0.12
	_noise.fractal_octaves = 3
	_load_chapters()
	_cam = get_node("../Camera3D")
	_cam_base = _cam.position
	_build_island()
	_build_sea()
	_build_trees()
	_build_path()
	_build_markers()
	_build_hero()
	_build_ui()
	select(0)
	if "--autotest" in OS.get_cmdline_user_args():
		_autotest.call_deferred()

## 讀大關清單，決定每支旗子插在哪
func _load_chapters() -> void:
	LEVELS = Registry.chapters()
	var used := {}
	for ch in LEVELS:
		for c in CITIES:
			if c[0] == ch.city and not used.has(c[0]):
				ch.pos = c[1]
				used[c[0]] = true
	var spare := 0
	for ch in LEVELS:
		if ch.has("pos"):
			continue
		for c in CITIES:
			if not used.has(c[0]):
				ch.pos = c[1]
				ch.city = c[0]
				used[c[0]] = true
				break
		if not ch.has("pos"):
			ch.pos = SPARE_POS[spare % SPARE_POS.size()] + Vector2(0, spare / SPARE_POS.size() * 1.5)
			ch.city = "外島"
			spare += 1
	# 由南往北排（地圖 x 越大越南）
	LEVELS.sort_custom(func(a, b): return a.pos.x > b.pos.x)
	cleared = 0
	for ch in LEVELS:
		if not Progress.chapter_cleared(ch):
			break
		cleared += 1

# ---------------------------------------------------------------- 地形

func _sd(p: Vector2) -> float:
	## 到海岸線的帶號距離（島內為正）
	var inside := false
	var dmin := INF
	var n := OUTLINE.size()
	for i in n:
		var a: Vector2 = OUTLINE[i]
		var b: Vector2 = OUTLINE[(i + 1) % n]
		if (a.y > p.y) != (b.y > p.y) and p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x:
			inside = not inside
		var t := clampf((p - a).dot(b - a) / (b - a).length_squared(), 0.0, 1.0)
		dmin = minf(dmin, p.distance_to(a.lerp(b, t)))
	var d := dmin if inside else -dmin
	for isl in ISLETS:
		d = maxf(d, isl[1] - p.distance_to(isl[0]))
	return d

static func _ss(a: float, b: float, x: float) -> float:
	var t := clampf((x - a) / (b - a), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)

func height_at(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var d := _sd(p)
	var n := _noise.get_noise_2d(x, z)
	var land := 0.25 + n * 0.25
	# 中央山脈：離稜線越近越高，北端（宜蘭）和南端（恆春）收低
	var rd := INF
	var along := 0.0
	for i in RIDGE.size() - 1:
		var a: Vector2 = RIDGE[i]
		var b: Vector2 = RIDGE[i + 1]
		var t := clampf((p - a).dot(b - a) / (b - a).length_squared(), 0.0, 1.0)
		var dd := p.distance_to(a.lerp(b, t))
		if dd < rd:
			rd = dd
			along = (float(i) + t) / (RIDGE.size() - 1)
	var taper := _ss(0.0, 0.18, along) * _ss(1.0, 0.75, along)
	var ridge := exp(-pow(rd / 3.2, 2.0)) * (0.35 + 0.65 * taper)
	land += ridge * (5.2 + _noise.get_noise_2d(x * 2.0, z * 2.0) * 2.4)
	land *= _ss(0.0, 1.6, d)
	return lerpf(-0.9, land, _ss(-1.2, 0.6, d))

func _build_island() -> void:
	var nx := GRID_X + 1
	var nz := GRID_Z + 1
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	var hs := PackedFloat32Array()
	hs.resize(nx * nz)
	for j in nz:
		for i in nx:
			var x := lerpf(MAP_MIN.x, MAP_MAX.x, float(i) / GRID_X)
			var z := lerpf(MAP_MIN.y, MAP_MAX.y, float(j) / GRID_Z)
			hs[j * nx + i] = height_at(x, z)
	var dx := (MAP_MAX.x - MAP_MIN.x) / GRID_X
	var dz := (MAP_MAX.y - MAP_MIN.y) / GRID_Z
	for j in nz:
		for i in nx:
			var x := lerpf(MAP_MIN.x, MAP_MAX.x, float(i) / GRID_X)
			var z := lerpf(MAP_MIN.y, MAP_MAX.y, float(j) / GRID_Z)
			var h := hs[j * nx + i]
			verts.append(Vector3(x, h, z))
			var hl := hs[j * nx + maxi(i - 1, 0)]
			var hr := hs[j * nx + mini(i + 1, nx - 1)]
			var hd := hs[maxi(j - 1, 0) * nx + i]
			var hu := hs[mini(j + 1, nz - 1) * nx + i]
			var nrm := Vector3((hl - hr) / (2.0 * dx), 1.0, (hd - hu) / (2.0 * dz)).normalized()
			norms.append(nrm)
			var d := _sd(Vector2(x, z))
			var sand := 1.0 - _ss(0.2, 1.3, d)
			var rock := _ss(0.42, 0.65, 1.0 - nrm.y) * _ss(1.6, 2.6, h) + _ss(3.4, 4.4, h)
			var fields := _ss(0.15, 0.45, _noise.get_noise_2d(x * 1.7 + 30.0, z * 1.7)) * (1.0 - _ss(0.8, 1.8, h))
			cols.append(Color(sand, fields * 0.8, clampf(rock, 0.0, 1.0), 1.0))
	for j in nz - 1:
		for i in nx - 1:
			var a := j * nx + i
			idx.append_array([a, a + 1, a + nx, a + 1, a + nx + 1, a + nx])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mat := ShaderMaterial.new()
	mat.shader = TerrainShader
	mat.set_shader_parameter("detail_tex", load(TEX + "gravelly_sand_diff_1k.jpg"))
	mat.set_shader_parameter("ground_a", Color(0.58, 0.65, 0.33))
	mat.set_shader_parameter("ground_b", Color(0.50, 0.60, 0.29))
	mat.set_shader_parameter("grassy", Color(0.44, 0.58, 0.27))
	mat.set_shader_parameter("sand_c", Color(0.90, 0.80, 0.56))
	mat.set_shader_parameter("dirt_c", Color(0.76, 0.66, 0.40))
	mat.set_shader_parameter("rock_c", Color(0.66, 0.64, 0.58))
	var mi := MeshInstance3D.new()
	mi.name = "Island"
	mi.mesh = mesh
	mi.material_override = mat
	add_child(mi)

func _build_sea() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(400, 400)
	var mi := MeshInstance3D.new()
	mi.name = "Sea"
	mi.mesh = plane
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/water.gdshader")
	mi.material_override = m
	mi.position.y = -0.05
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)

func _build_trees() -> void:
	# 和遊戲裡森林同一種圓團樹冠，集中在山腳和幾片樹林
	var r := RandomNumberGenerator.new()
	r.seed = 99
	var blob := SphereMesh.new()
	blob.radius = 1.0
	blob.height = 1.8
	blob.radial_segments = 7
	blob.rings = 4
	var xf: Array[Transform3D] = []
	var cs: Array[Color] = []
	for k in 2600:
		var x := r.randf_range(-21.0, 22.0)
		var z := r.randf_range(-6.0, 12.0)
		var d := _sd(Vector2(x, z))
		if d < 0.9:
			continue
		var h := height_at(x, z)
		var forest := _noise.get_noise_2d(x * 0.9 - 50.0, z * 0.9)
		var on_mountain := h > 0.9 and h < 3.6
		var near_flag := false
		for lv in LEVELS:
			if Vector2(x, z).distance_to(lv.pos) < 2.2:
				near_flag = true
		if near_flag:
			continue
		if not (on_mountain and r.randf() < 0.5) and not (forest > 0.4 and r.randf() < 0.6):
			continue
		var s := r.randf_range(0.18, 0.32)
		xf.append(Transform3D(Basis(Vector3.UP, r.randf() * TAU).scaled(Vector3(s, s * 1.1, s)), Vector3(x, h + s * 0.7, z)))
		cs.append(Color(r.randf_range(0.22, 0.34), r.randf_range(0.44, 0.56), r.randf_range(0.2, 0.28)))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = blob
	mm.instance_count = xf.size()
	for i in xf.size():
		mm.set_instance_transform(i, xf[i])
		mm.set_instance_color(i, cs[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Trees"
	mmi.multimesh = mm
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/forest_crown.gdshader")
	mmi.material_override = m
	add_child(mmi)

# ---------------------------------------------------------------- 關卡

func _ground(p: Vector2, lift := 0.0) -> Vector3:
	return Vector3(p.x, maxf(height_at(p.x, p.y), 0.0) + lift, p.y)

func _toon(c: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/toon_color.gdshader")
	m.set_shader_parameter("albedo", c)
	return m

## 第 i 個大關的第 n 小關（從 1 開始）照規則解鎖了沒
func unlocked(i: int, n := 1) -> bool:
	var ch: Dictionary = LEVELS[i]
	if n < 1 or n > ch.stages.size() or String(ch.stages[n - 1].scene) == "":
		return false
	return Progress.unlocked(ch.id, n)

func _build_path() -> void:
	var dot := SphereMesh.new()
	dot.radius = 0.13
	dot.height = 0.22
	dot.radial_segments = 8
	dot.rings = 4
	for i in LEVELS.size() - 1:
		var a: Vector2 = LEVELS[i].pos
		var b: Vector2 = LEVELS[i + 1].pos
		var len := a.distance_to(b)
		var steps := int(len / 0.55)
		var col := Color(1.0, 0.94, 0.78) if i < cleared else Color(0.72, 0.72, 0.7)
		var mat := _toon(col)
		for k in range(1, steps):
			var t := float(k) / steps
			# 稍微彎一點，看起來像手繪路線
			var p := a.lerp(b, t) + Vector2(0, sin(t * PI) * 0.6)
			var mi := MeshInstance3D.new()
			mi.mesh = dot
			mi.material_override = mat
			mi.position = _ground(p, 0.12)
			add_child(mi)

func _build_markers() -> void:
	for i in LEVELS.size():
		var lv: Dictionary = LEVELS[i]
		var open: bool = not lv.stages.is_empty()
		var root := Node3D.new()
		root.position = _ground(lv.pos)
		add_child(root)
		var holder := Node3D.new()
		holder.scale = Vector3.ONE * 1.5
		root.add_child(holder)
		var base := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.5
		cyl.bottom_radius = 0.58
		cyl.height = 0.16
		cyl.radial_segments = 16
		base.mesh = cyl
		base.material_override = _toon(Color(0.86, 0.76, 0.56) if open else Color(0.6, 0.6, 0.58))
		base.position.y = 0.08
		holder.add_child(base)
		var pole := MeshInstance3D.new()
		var pm := CylinderMesh.new()
		pm.top_radius = 0.05
		pm.bottom_radius = 0.05
		pm.height = 1.5
		pole.mesh = pm
		pole.material_override = _toon(Color(0.45, 0.32, 0.2))
		pole.position.y = 0.9
		holder.add_child(pole)
		var flag := MeshInstance3D.new()
		var fm := BoxMesh.new()
		fm.size = Vector3(0.7, 0.42, 0.04)
		flag.mesh = fm
		var fc := Color(0.95, 0.42, 0.24) if open else Color(0.55, 0.56, 0.58)
		if Progress.chapter_cleared(lv):
			fc = Color(0.35, 0.75, 0.38)
		flag.material_override = _toon(fc)
		flag.position = Vector3(0.37, 1.42, 0)
		holder.add_child(flag)
		var ring := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.66
		tm.outer_radius = 0.78
		tm.rings = 32
		ring.mesh = tm
		var rm := StandardMaterial3D.new()
		rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		rm.albedo_color = Color(1.0, 0.88, 0.4)
		ring.material_override = rm
		ring.position.y = 0.1
		ring.visible = false
		holder.add_child(ring)
		var label := Label3D.new()
		label.text = "%s  %s" % [lv.city, lv.title]
		label.font_size = 56
		label.outline_size = 14
		label.pixel_size = 0.008
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true   # 被山或樹擋住時也看得到
		label.modulate = Color(1, 1, 1) if open else Color(0.8, 0.8, 0.8)
		label.outline_modulate = Color(0, 0, 0, 0.6)
		label.position = Vector3(0, 2.15, 0)
		holder.add_child(label)
		UIStyle.plate(label, "wood" if open else "ice")   # 大關名牌＝木牌（還沒開放的是淡藍牌）
		_markers.append({"root": root, "flag": flag, "ring": ring, "label": label, "holder": holder})

func _build_hero() -> void:
	# 家豪站在目前的關卡旁邊（和遊戲內同一個模型）
	var chars := Node3D.new()
	chars.set_script(load("res://scripts/characters.gd"))
	add_child(chars)
	_hero = chars._make_standin_rooster()
	chars.add_child(_hero)
	_hero.scale *= 0.85
	var cur := clampi(cleared, 0, maxi(LEVELS.size() - 1, 0))
	var p: Vector2 = (LEVELS[cur].pos if not LEVELS.is_empty() else Vector2.ZERO) + Vector2(0.8, -1.3)
	_hero.position = _ground(p)
	_hero.rotation.y = PI * 0.15

# ---------------------------------------------------------------- 介面

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var big := UIStyle.ls(44)
	_title = Label.new()
	_title.text = "家豪的起義之路"
	_title.label_settings = big
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_title.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_title.offset_top = 26
	UIStyle.ribbon(_title)               # 標題＝緞帶
	layer.add_child(_title)

	var panel := PanelContainer.new()
	UIStyle.paper(panel, 0.0)            # 大關資訊＝筆記紙
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.offset_bottom = -26
	var box := VBoxContainer.new()
	panel.add_child(box)
	var mid := UIStyle.ls(30, UIStyle.INK)
	_info = Label.new()
	_info.label_settings = mid
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_info)
	var small := UIStyle.ls(19, Color(UIStyle.INK, 0.75))
	_hint = Label.new()
	_hint.label_settings = small
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.text = "← → 選大關　｜　↑ ↓ 或數字鍵 選小關　｜　Enter 開始　｜　滑鼠點旗子也可以"
	box.add_child(_hint)
	layer.add_child(panel)

	var ts := UIStyle.ls(28)
	_toast = Label.new()
	_toast.label_settings = ts
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast.offset_top = 120
	UIStyle.pill(_toast)
	layer.add_child(_toast)

func select(i: int) -> void:
	if LEVELS.is_empty():
		_info.text = "還沒有任何大關（levels/ 底下沒有 chapter.gd）"
		return
	var was := selected
	selected = clampi(i, 0, LEVELS.size() - 1)
	if selected != was:
		stage_sel = 0
	_refresh_info()
	for k in _markers.size():
		_markers[k].ring.visible = k == selected

func select_stage(n: int) -> void:
	if LEVELS.is_empty():
		return
	stage_sel = clampi(n, 0, maxi(LEVELS[selected].stages.size() - 1, 0))
	_refresh_info()

func _refresh_info() -> void:
	var lv: Dictionary = LEVELS[selected]
	var lines: PackedStringArray = []
	var who := ("　by %s" % lv.author) if lv.author != "" else ""
	lines.append("%s・%s%s" % [lv.city, lv.title, who])
	if lv.desc != "":
		lines.append(lv.desc)
	var row: PackedStringArray = []
	for k in lv.stages.size():
		var st: Dictionary = lv.stages[k]
		var mark := "（已過）" if Progress.is_cleared(st.id) else ("" if unlocked(selected, k + 1) else "（未解鎖）")
		var txt := "%d. %s%s" % [k + 1, st.title, mark]
		row.append(("【%s】" % txt) if k == stage_sel else txt)
	lines.append("　".join(row) if not row.is_empty() else "（這個大關還沒有小關）")
	_info.text = "\n".join(lines)

func start_selected() -> bool:
	if _starting or LEVELS.is_empty():
		return false
	var lv: Dictionary = LEVELS[selected]
	if lv.stages.is_empty() or String(lv.stages[stage_sel].scene) == "":
		_show_toast("這一關還沒做好")
		return false
	if not unlocked(selected, stage_sel + 1):
		if OS.is_debug_build() and not "--autotest" in OS.get_cmdline_user_args():
			_show_toast("（開發模式：還沒解鎖也讓你進去）")
		else:
			_show_toast("先過前一小關才能玩這一關")
			return false
	_starting = true
	Engine.set_meta("next_scene", lv.stages[stage_sel].scene)
	Engine.set_meta("stage_id", lv.stages[stage_sel].id)
	get_tree().change_scene_to_file("res://scenes/loading.tscn")   # 先進載入畫面
	return true

func _show_toast(t: String) -> void:
	_toast.text = t
	_toast.visible = true
	_toast_t = 2.0

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo:
		match e.keycode:
			KEY_LEFT, KEY_A:
				select(selected - 1)   # 往南（回到前面的關卡）
			KEY_RIGHT, KEY_D:
				select(selected + 1)
			KEY_UP, KEY_W:
				select_stage(stage_sel - 1)
			KEY_DOWN, KEY_S:
				select_stage(stage_sel + 1)
			KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9:
				select_stage(e.keycode - KEY_1)
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				start_selected()
	elif e is InputEventMouseMotion:
		var k := _marker_under(e.position)
		if k >= 0 and k != selected:
			select(k)
	elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		var k := _marker_under(e.position)
		if k >= 0:
			select(k)
			start_selected()

func _marker_under(sp: Vector2) -> int:
	var best := -1
	var bd := 48.0
	for k in _markers.size():
		var root: Node3D = _markers[k].root
		var p := _cam.unproject_position(root.global_position + Vector3(0, 1.4, 0))
		var d := p.distance_to(sp)
		if d < bd:
			bd = d
			best = k
	return best

func _process(dt: float) -> void:
	_t += dt
	# 鏡頭微微晃動，旗子輕輕飄
	_cam.position = _cam_base + Vector3(sin(_t * 0.25) * 0.5, sin(_t * 0.4) * 0.15, 0)
	for k in _markers.size():
		var m: Dictionary = _markers[k]
		var sel := k == selected
		(m.flag as Node3D).rotation.y = sin(_t * 2.0 + k) * 0.25
		var s := 1.0 + (0.12 * absf(sin(_t * 3.0)) if sel else 0.0)
		(m.root as Node3D).scale = Vector3.ONE * s
	if _toast_t > 0.0:
		_toast_t -= dt
		if _toast_t <= 0.0:
			_toast.text = ""
			_toast.visible = false

# ---------------------------------------------------------------- 自動驗收（--autotest）

func _autotest() -> void:
	var lines: Array = []
	var fails := 0
	var out_dir := "user://autotest"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--outdir="):
			out_dir = a.substr(9)
	DirAccess.make_dir_recursive_absolute(out_dir)
	await get_tree().create_timer(1.5).timeout
	var farm := -1
	for k in LEVELS.size():
		if LEVELS[k].id == "example_farm":
			farm = k
	var all_first := true
	for k in LEVELS.size():
		all_first = all_first and (LEVELS[k].stages.is_empty() or unlocked(k, 1))
	var checks := [
		["選關地圖自動找到所有大關（%d 個）" % LEVELS.size(), _markers.size() == LEVELS.size() and LEVELS.size() >= 1],
		["農場範例在地圖上", farm >= 0],
		["每個大關的第 1 小關都可以玩", all_first],
		["旗子由南往北排", LEVELS.size() < 2 or LEVELS[0].pos.x >= LEVELS[LEVELS.size() - 1].pos.x],
	]
	if DisplayServer.window_can_draw():
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out_dir.path_join("00_level_select.png"))
	select(0)
	var e := InputEventKey.new()
	e.keycode = KEY_RIGHT
	e.pressed = true
	Input.parse_input_event(e)
	await get_tree().process_frame
	await get_tree().process_frame
	checks.append(["按 → 換到下一個大關", LEVELS.size() < 2 or selected == 1])
	# 找一個有第 2 小關的大關，測「沒過第 1 小關進不去第 2 小關」
	for k in LEVELS.size():
		if LEVELS[k].stages.size() >= 2 and not Progress.is_cleared(LEVELS[k].stages[0].id):
			select(k)
			select_stage(1)
			checks.append(["還沒過第 1 小關，第 2 小關進不去", not start_selected()])
			break
	if DisplayServer.window_can_draw():
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out_dir.path_join("00b_level_locked.png"))
	select(farm if farm >= 0 else 0)
	select_stage(0)
	for c in checks:
		var ok: bool = c[1]
		if not ok:
			fails += 1
		var s := "[%s] %s" % ["PASS" if ok else "FAIL", c[0]]
		print(s)
		lines.append(s)
	Engine.set_meta("ls_lines", lines)
	Engine.set_meta("ls_fails", fails)
	# 進入農場範例，繼續農場的驗收
	start_selected()
