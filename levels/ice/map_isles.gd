extends RefCounted
## 選關地圖上的冰雪島（chapter.gd 的 MAP_SCRIPT；由 scripts/level_select.gd 呼叫，不是關卡腳本）。
## 整個大關是一座大雪島，六個小關是島上的六個地點，地標和時段照 docs/關卡規格.md 的總覽表：
##   1 漁村・早晨　2 冰雕廣場・正午　3 冰晶溪谷・陰天細雪　4 燈塔・金色傍晚　5 鐘樓・黃昏　6 燈籠夜市・極光夜
## 島的本體用關卡同一套網格和著色器（art/isle_builder.gd：雪簷＋一層一層的冰崖＋結冰的湖），模型也跟關卡裡的是同一批。

const Isle := preload("res://levels/ice/art/isle_builder.gd")
const IceWorld := preload("res://levels/ice/ice_world.gd")     # 只借用 MOODS（每個時段的配色）
const KH := "res://levels/ice/assets/kenney_holiday/"
const KS := "res://levels/ice/assets/kenney_survival/"
const KP := "res://levels/ice/assets/kenney_platformer/"
const KC := "res://levels/ice/assets/kenney_cubepets/"
const MB := "res://levels/ice/assets/blender/"
const TX := "res://levels/ice/assets/textures/"
const SH := "res://levels/ice/shaders/"

## 每一小關的時段（IceWorld.MOODS 的鍵）
const STAGE_MOODS := ["morning", "noon", "overcast", "golden", "sunset", "dusk"]

var _top_y := 1.5
var _ctx := {}                 # level_select.gd 給的：島的中心、範圍、站點和地標的位置
var _lakes: Array = []         # 結冰的湖 [中心 Vector2, rx, rz]
var _snow_mat: ShaderMaterial      # 只有雪（模型上的積雪）
var _top_mat: ShaderMaterial       # 島面（雪＋結冰的湖）
var _cliff_mat: ShaderMaterial
var _ice_mat: ShaderMaterial
var _statue_mat: ShaderMaterial
var _thin_mat: ShaderMaterial
var _crack_mat: StandardMaterial3D
var _water_mat: StandardMaterial3D
var _toon_cache := {}
var _toon_at := {}             # 「卡通材質|站的高度」→ 那個高度用的複本（見 _toon_at_height）

# ================================================================== 給 level_select.gd 呼叫的兩個函式

## 走到第 k 小關時的天色
func mood(k: int) -> Dictionary:
	var md: Dictionary = IceWorld.MOODS[STAGE_MOODS[clampi(k, 0, STAGE_MOODS.size() - 1)]]
	var far: Color = md.get("sea_far", (md.band as Color).lerp(md.sea_near, 0.25))
	return {
		"sun": md.sun, "energy": md.energy, "rot": md.rot, "amb": md.amb, "amb_e": md.amb_e, "fog": md.get("fog", md.band),
		"sky.top_color": md.top, "sky.horizon_color": md.hor, "sky.mist_color": md.band, "sky.abyss_color": far,
		"sky.cloud_color": md.cloud, "sky.cloud_shade": md.cloud_sh, "sky.sun_glow": md.sun_glow,
		"sky.stars": float(md.stars), "sky.aurora": float(md.aurora), "sky.cloud_cover": float(md.get("cloud_cover", 0.0)),
		"sky.glow_band": float(md.glow_band), "sky.band_thin": float(md.get("band_thin", 11.0)),
		"sky.aurora_elev": 0.05,          # 地圖的鏡頭只看得到地平線上面一小條天空：極光壓低到地平線才看得到
		"sea.deep": md.sea_deep, "sea.near_c": md.sea_near, "sea.stroke_c": md.sea_stroke,
		"sea.foam_c": (md.sea_stroke as Color).lerp(Color.WHITE, 0.7), "sea.horizon_c": far,
	}

## 島面高度（路、站點、家豪都貼在這個高度上）：幾乎是平的，只有一點點起伏
func ground_y(x: float, z: float) -> float:
	return _top_y + 0.10 * sin(x * 0.55) * cos(z * 0.7)

## 蓋整座大雪島（世界座標；y = 0 是海面）
func build_island(root: Node3D, ctx: Dictionary) -> void:
	_ctx = ctx
	_top_y = float(ctx.get("top_y", 1.5))
	var c: Vector2 = ctx.center
	var rx: float = ctx.rx
	var rz: float = ctx.rz
	_pick_lakes()
	_make_materials()
	var o := {"c": c, "rx": rx, "rz": rz, "seed": 2.3, "pow": 3.0, "wob": 1.0, "depth": _top_y + 1.3, "slope": 0.16, "lobe": 2.2,
		"coves": [[0.75, 2.4, 0.16], [2.5, 2.0, 0.14], [4.1, 1.8, 0.12], [5.6, 2.2, 0.14]]}
	var top := MeshInstance3D.new()
	top.name = "Top"
	top.mesh = Isle.build_top(o, ground_y, 160, 12, 0.7)
	top.material_override = _top_mat
	root.add_child(top)
	var cliff := MeshInstance3D.new()
	cliff.name = "Cliff"
	cliff.mesh = Isle.build_cliff(o, func(a: float) -> float:
		var p := Isle.rim_point(o, a)
		return ground_y(p.x, p.y), 160, 6)
	cliff.material_override = _cliff_mat
	root.add_child(cliff)
	# 空地上的雪松、雪堆、石頭（不擋路、不擋地標、不長在湖上）
	var rng := RandomNumberGenerator.new()
	rng.seed = 4100
	var placed := 0
	for i in 400:
		if placed >= 30:
			break
		var a := rng.randf() * TAU
		var d := Isle.radius(o, a) * sqrt(rng.randf()) - 1.5
		var x := c.x + cos(a) * d
		var z := c.y + sin(a) * d
		if d < 0.0 or not _free(x, z):
			continue
		var g := Vector3(x, ground_y(x, z), z)
		match placed % 5:
			0, 1, 2: _prop(root, KH + ["tree-snow-a", "tree-snow-b", "tree-snow-c"][placed % 3] + ".glb", g, rng.randf() * TAU, rng.randf_range(1.2, 2.0))
			3: _prop(root, MB + ["snow_rock_a", "snow_rock_b"][placed % 2] + ".glb", g - Vector3(0, 0.1, 0), rng.randf() * TAU, rng.randf_range(0.6, 1.0))
			_: _prop(root, MB + "snow_drift_" + ["a", "b", "c", "d"][placed % 4] + ".glb", g, rng.randf() * TAU, rng.randf_range(0.5, 0.8), false)
		placed += 1
	# 湖邊幾塊碎冰
	for l in _lakes:
		var lc: Vector2 = l[0]
		for i in 3:
			var a := i * 2.1 + lc.x
			var q := lc + Vector2(cos(a) * float(l[1]) * 1.05, sin(a) * float(l[2]) * 1.05)
			_prop(root, MB + "ice_chunk_" + ["a", "b", "e"][i] + ".glb", Vector3(q.x, ground_y(q.x, q.y) - 0.03, q.y), a, 0.6)
	# 海上漂幾塊浮冰、西岸一艘小船
	for i in 10:
		var a := (i + rng.randf_range(-0.3, 0.3)) * TAU / 10.0
		var d := Isle.cliff_radius(o, a, _top_y) + rng.randf_range(2.0, 7.0)
		_prop(root, MB + "ice_floe_" + ["a", "b", "c"][i % 3] + ".glb", Vector3(c.x + cos(a) * d, 0.0, c.y + sin(a) * d), rng.randf() * TAU, rng.randf_range(0.5, 1.0), false)
	var boat := _prop(root, MB + "rowboat.glb", Vector3(c.x - rx - 2.6, 0.05, c.y + 2.0), 1.2, 0.8)
	if boat:
		boat.rotation.z = 0.06

## 蓋第 k 小關的地標（root 在那個地點的島面上，+z 是鏡頭和站點那一邊）
func build_spot(k: int, root: Node3D, _c: Dictionary) -> void:
	match k:
		0: _fishing_village(root)
		1: _sculpture_plaza(root)
		2: _crystal_valley(root)
		3: _lighthouse(root)
		4: _belltower(root)
		_: _night_market(root)

# ================================================================== 島的本體、材質、放模型

## 地標周圍的位置（相對於 root，站在島面上）
func _g(x: float, z: float) -> Vector3:
	return Vector3(x, 0.0, z)

## 這個位置能不能放裝飾
func _free(x: float, z: float) -> bool:
	var p := Vector2(x, z)
	var pads: Array = _ctx.pads
	for k in pads.size():
		var a := Vector2(pads[k].x, pads[k].z)
		if p.distance_to(a) < 3.2:
			return false
		# 站點正前方（鏡頭那一邊）留空：樹才不會擋住家豪和旗子
		if absf(x - a.x) < 3.4 and z > a.y and z - a.y < 7.0:
			return false
		if k + 1 < pads.size():
			var b := Vector2(pads[k + 1].x, pads[k + 1].z)
			if Geometry2D.get_closest_point_to_segment(p, a, b).distance_to(p) < 2.6:
				return false
		var sp: Vector3 = _ctx.spots[k]
		if p.distance_to(Vector2(sp.x, sp.z)) < 4.8:
			return false
	for l in _lakes:
		var d := (p - (l[0] as Vector2)) / Vector2(float(l[1]) + 1.2, float(l[2]) + 1.2)
		if d.length() < 1.0:
			return false
	return true

## 結冰的湖：放在路的南邊空地最寬的兩個地方
func _pick_lakes() -> void:
	_lakes.clear()
	var pads: Array = _ctx.pads
	var south: float = (_ctx.center as Vector2).y + float(_ctx.rz)
	var cands: Array = []
	for k in pads.size() - 1:
		var m: Vector3 = ((pads[k] as Vector3) + (pads[k + 1] as Vector3)) * 0.5
		var room := south - maxf(pads[k].z, pads[k + 1].z)
		cands.append([room, m.x, south - room * 0.5])
	cands.sort_custom(func(a, b): return a[0] > b[0])
	for i in mini(2, cands.size()):
		var room: float = cands[i][0]
		if room > 5.5:
			_lakes.append([Vector2(cands[i][1], float(cands[i][2]) + 0.6), 4.0, minf(room * 0.28, 2.6)])

func _make_materials() -> void:
	if _snow_mat:
		return
	var md: Dictionary = IceWorld.MOODS["morning"]
	_snow_mat = ShaderMaterial.new()
	_snow_mat.shader = load(SH + "island_top.gdshader")
	_snow_mat.set_shader_parameter("crack_tex", load(TX + "ice_cracks.png"))
	_snow_mat.set_shader_parameter("snow_tex", load(TX + "snow_soft.png"))
	_snow_mat.set_shader_parameter("snow_lit", Color(0.97, 0.98, 1.0))
	_snow_mat.set_shader_parameter("snow_shade", Color(0.70, 0.80, 0.98))
	# 島面：同一個著色器，多畫結冰的湖
	_top_mat = _snow_mat.duplicate() as ShaderMaterial
	var la := PackedVector4Array()
	for l in _lakes:
		la.append(Vector4((l[0] as Vector2).x, (l[0] as Vector2).y, l[1], l[2]))
	_top_mat.set_shader_parameter("lake_count", la.size())
	la.resize(4)
	_top_mat.set_shader_parameter("lakes", la)
	_top_mat.set_shader_parameter("ice_glow", 0.3)
	_cliff_mat = ShaderMaterial.new()
	_cliff_mat.shader = load(SH + "cliff.gdshader")
	_cliff_mat.set_shader_parameter("strata_tex", load(TX + "cliff_strata.png"))
	_cliff_mat.set_shader_parameter("col_top", md.cliff[0])
	_cliff_mat.set_shader_parameter("col_mid", md.cliff[1])
	_cliff_mat.set_shader_parameter("col_low", md.cliff[2])
	_cliff_mat.set_shader_parameter("sea_color", md.sea_near)
	_cliff_mat.set_shader_parameter("glow", 0.3)
	_cliff_mat.set_shader_parameter("wet_start", _top_y - 0.5)
	_cliff_mat.set_shader_parameter("wet_range", 0.7)
	_ice_mat = ShaderMaterial.new()
	_ice_mat.shader = load(SH + "ice_solid.gdshader")
	_ice_mat.set_shader_parameter("crack_tex", load(TX + "ice_cracks.png"))
	_ice_mat.set_shader_parameter("inner", Color(0.13, 0.56, 0.84))
	_ice_mat.set_shader_parameter("outer", Color(0.74, 0.94, 1.0))
	_ice_mat.set_shader_parameter("frost_top", 0.3)
	_ice_mat.set_shader_parameter("glow", 0.4)
	_statue_mat = _ice_mat.duplicate() as ShaderMaterial
	_statue_mat.set_shader_parameter("inner", Color(0.18, 0.50, 0.80))
	_statue_mat.set_shader_parameter("outer", Color(0.70, 0.90, 1.0))
	_statue_mat.set_shader_parameter("crack_amount", 0.2)
	_statue_mat.set_shader_parameter("glow", 0.3)
	_thin_mat = _ice_mat.duplicate() as ShaderMaterial
	_thin_mat.set_shader_parameter("inner", Color(0.74, 0.92, 1.0))
	_thin_mat.set_shader_parameter("outer", Color(1.0, 1.0, 1.0))
	_thin_mat.set_shader_parameter("frost_top", 0.75)
	_thin_mat.set_shader_parameter("crack_amount", 0.5)
	_thin_mat.set_shader_parameter("glow", 0.55)
	_crack_mat = StandardMaterial3D.new()
	_crack_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_crack_mat.albedo_color = Color(0.06, 0.24, 0.50)
	_water_mat = StandardMaterial3D.new()
	_water_mat.albedo_color = Color(0.10, 0.50, 0.74)
	_water_mat.roughness = 0.2

## 放一個模型（scale 是倍率：模型原本就是公尺單位），材質換成關卡同一套卡通材質
func _prop(parent: Node3D, path: String, pos: Vector3, yaw := 0.0, scale := 1.0, shadows := true) -> Node3D:
	if not ResourceLoader.exists(path):
		push_warning("冰雪島地圖：找不到模型 " + path)
		return null
	var ps := load(path) as PackedScene
	if ps == null:
		return null
	var n := ps.instantiate() as Node3D
	n.position = pos
	n.rotation.y = yaw
	n.scale = Vector3.ONE * scale
	parent.add_child(n)
	var ap := n.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap:
		ap.stop()
	_restyle(n, shadows)
	return n

func _restyle(n: Node3D, shadows := true) -> void:
	for m in n.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null:
			continue
		if not shadows:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for i in mi.mesh.get_surface_count():
			var mat := mi.mesh.surface_get_material(i)
			match String(mat.resource_name) if mat else "":
				"snow": mi.set_surface_override_material(i, _snow_mat)
				"ice", "ice_wall": mi.set_surface_override_material(i, _ice_mat)
				"water": mi.set_surface_override_material(i, _water_mat)
				"thin_ice": mi.set_surface_override_material(i, _thin_mat)
				"crack": mi.set_surface_override_material(i, _crack_mat)
				_:
					var tm := _toon_mat(mat)
					if tm:
						mi.set_surface_override_material(i, _toon_at_height(tm, base_y))

## 卡通材質「這個模型站的地面高度」（離地面越近越暗）寫進材質：同一種材質、同一個高度（每 5 公分一格）共用一份複本。
## 不用 instance uniform：網頁版（Compatibility 渲染）整個畫面最多只有 64 個物件能用（同 ice_world.gd 的 _pin_height）。
func _toon_at_height(m: ShaderMaterial, base_y: float) -> ShaderMaterial:
	var y := snappedf(base_y, 0.05)
	var key := "%d|%.2f" % [m.get_instance_id(), y]
	if not _toon_at.has(key):
		var c := m.duplicate() as ShaderMaterial
		c.set_shader_parameter("base_y", y)
		_toon_at[key] = c
	return _toon_at[key]

## 一般模型的卡通材質（kit_prop.gdshader；同一個來源材質只做一份）。半透明的材質（冰晶）不換。
func _toon_mat(src: Material) -> ShaderMaterial:
	var sm := src as BaseMaterial3D
	if sm == null or sm.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
		return null
	if _toon_cache.has(sm):
		return _toon_cache[sm]
	var m := ShaderMaterial.new()
	m.shader = load(SH + "kit_prop.gdshader")
	if sm.albedo_texture:
		m.set_shader_parameter("albedo_tex", sm.albedo_texture)
	m.set_shader_parameter("tint", sm.albedo_color)
	m.set_shader_parameter("detail_tex", load(TX + "snow_soft.png"))
	if sm.emission_enabled:
		m.set_shader_parameter("emission_c", sm.emission * sm.emission_energy_multiplier)
	_toon_cache[sm] = m
	return m

func _light(root: Node3D, p: Vector3, col: Color, energy: float, rng: float) -> void:
	var l := OmniLight3D.new()
	l.light_color = col
	l.light_energy = energy
	l.omni_range = rng
	l.light_specular = 0.0
	l.position = p
	root.add_child(l)

func _warm(root: Node3D, p: Vector3, energy := 1.2, rng := 4.0) -> void:
	_light(root, p, Color(1.0, 0.72, 0.38), energy, rng)

func _tree(root: Node3D, x: float, z: float, kind: int, scale: float) -> void:
	_prop(root, KH + ["tree-snow-a", "tree-snow-b", "tree-snow-c"][kind % 3] + ".glb", _g(x, z), x * 3.0, scale)

## 一座冰雕：冰台座上放一個冰做的模型
func _statue(root: Node3D, x: float, z: float, model: String, yaw: float, scale: float) -> void:
	var q := _g(x, z)
	var k := maxf(scale / 1.2, 0.7)
	var ped := _prop(root, MB + "ice_pedestal.glb", q + Vector3(0, -0.04, 0), yaw + x, k)
	if ped:
		for m in ped.find_children("*", "MeshInstance3D", true, false):
			(m as MeshInstance3D).material_override = _statue_mat
	var st := _prop(root, model, q + Vector3(0, 0.5 * k, 0), yaw, scale)
	if st:
		for m in st.find_children("*", "MeshInstance3D", true, false):
			(m as MeshInstance3D).material_override = _statue_mat

# ================================================================== 六座小島

## 1 漁村：兩間釣魚小屋、碼頭和小船、木桶、燈籠
func _fishing_village(root: Node3D) -> void:
	_prop(root, MB + "fishing_hut.glb", _g(-1.0, -1.2), 0.3, 0.8)
	_prop(root, MB + "fishing_hut.glb", _g(1.9, -2.2), -0.4, 0.6)
	_prop(root, MB + "fish_net.glb", _g(3.0, 0.4), 0.6, 0.7)
	_prop(root, KS + "barrel.glb", _g(1.3, 0.6), 0.0, 1.1)
	_prop(root, KS + "campfire-fishing-stand.glb", _g(-2.6, 1.3), 0.8, 1.5)
	_prop(root, KH + "lantern.glb", _g(0.4, 1.0), 0.0, 1.2)
	_warm(root, _g(0.4, 1.0) + Vector3(0, 1.1, 0), 0.8, 3.0)
	_tree(root, -3.1, -1.6, 0, 1.6)
	_tree(root, 0.2, -3.2, 1, 1.9)
	root.set_meta("bubble_y", 4.6)

## 2 冰雕廣場：三座冰雕（兩隻企鵝、一條魚）、雪人
func _sculpture_plaza(root: Node3D) -> void:
	_statue(root, 0.0, -1.2, KC + "animal-penguin.glb", 0.0, 1.5)
	_statue(root, -2.3, -0.2, KC + "animal-penguin.glb", 0.4, 1.0)
	_statue(root, 2.3, -0.2, KS + "fish-large.glb", -0.5, 2.2)
	_prop(root, MB + "snowman.glb", _g(1.2, 1.7), -0.3, 0.75)
	_prop(root, KH + "lantern.glb", _g(-1.4, 1.7), 0.0, 1.2)
	_tree(root, -2.6, -2.5, 2, 1.7)
	_tree(root, 2.7, -2.4, 0, 1.5)
	_light(root, _g(0.0, -0.6) + Vector3(0, 2.0, 0), Color(0.6, 0.86, 1.0), 0.9, 4.5)
	root.set_meta("bubble_y", 5.0)

## 3 冰晶溪谷：發光的冰晶簇、兩片薄冰、碎冰
func _crystal_valley(root: Node3D) -> void:
	_prop(root, MB + "ice_crystals.glb", _g(-0.3, -1.3), 0.4, 2.0)
	_prop(root, MB + "ice_crystals.glb", _g(1.9, -0.6), 1.6, 1.3)
	_prop(root, MB + "ice_crystals.glb", _g(-2.3, -0.2), 2.8, 1.1)
	_prop(root, MB + "ice_crystals.glb", _g(0.9, -2.9), 4.0, 0.9)
	_prop(root, MB + "thin_ice.glb", _g(0.7, 1.5) + Vector3(0, 0.03, 0), 0.5, 0.75, false)
	_prop(root, MB + "thin_ice.glb", _g(-1.9, 1.9) + Vector3(0, 0.03, 0), 2.0, 0.5, false)
	_prop(root, MB + "ice_chunk_a.glb", _g(2.9, 1.2), 0.7, 0.7)
	_prop(root, MB + "ice_chunk_b.glb", _g(-3.2, -1.9), 2.1, 0.8)
	_prop(root, MB + "snow_rock_a.glb", _g(3.0, -2.2), 1.0, 0.8)
	_light(root, _g(-0.2, -0.9) + Vector3(0, 1.6, 0), Color(0.55, 0.85, 1.0), 1.6, 5.0)
	root.set_meta("bubble_y", 4.2)

## 4 燈塔：紅白條紋的燈塔、石頭、一艘小船
func _lighthouse(root: Node3D) -> void:
	_prop(root, MB + "lighthouse.glb", _g(-0.2, -1.0) + Vector3(0, -0.1, 0), 0.0, 0.72)
	_warm(root, _g(-0.2, -1.0) + Vector3(0, 4.4, 0), 2.2, 8.0)
	_prop(root, MB + "snow_rock_a.glb", _g(2.5, -1.6), 0.6, 0.9)
	_prop(root, MB + "snow_rock_b.glb", _g(-2.8, 0.4), 2.2, 0.8)
	_prop(root, KS + "signpost-single.glb", _g(1.8, 1.6), -0.4, 1.5)
	_tree(root, 2.6, 0.6, 1, 1.4)
	root.set_meta("bubble_y", 6.0)

## 5 鐘樓：木頭鐘樓、雪橇、雪松
func _belltower(root: Node3D) -> void:
	_prop(root, MB + "belltower.glb", _g(0.0, -1.1) + Vector3(0, -0.1, 0), 0.0, 0.62)
	_warm(root, _g(0.0, 0.3) + Vector3(0, 1.2, 0), 0.9, 3.5)
	_prop(root, KH + "sled.glb", _g(2.3, 1.2), 0.9, 1.2)
	_prop(root, KH + "lantern.glb", _g(-1.7, 1.5), 0.0, 1.2)
	_warm(root, _g(-1.7, 1.5) + Vector3(0, 1.1, 0), 0.8, 3.0)
	_tree(root, -2.9, -1.3, 0, 1.8)
	_tree(root, 2.9, -1.6, 2, 1.6)
	_tree(root, -2.6, 1.0, 1, 1.1)
	root.set_meta("bubble_y", 6.2)

## 6 燈籠夜市：兩個攤位、一串燈籠、木箱，整座島是暖色的燈光
func _night_market(root: Node3D) -> void:
	_prop(root, MB + "market_stall.glb", _g(-1.7, -1.3), 0.35, 0.85)
	_prop(root, MB + "market_stall.glb", _g(1.8, -1.3), -0.35, 0.85)
	_prop(root, MB + "lantern_string.glb", _g(0.0, 0.5), 0.0, 0.8)
	_warm(root, _g(0.0, 0.5) + Vector3(0, 2.0, 0), 1.8, 6.0)
	_warm(root, _g(-1.7, -0.4) + Vector3(0, 1.5, 0), 1.2, 3.5)
	_warm(root, _g(1.8, -0.4) + Vector3(0, 1.5, 0), 1.2, 3.5)
	_prop(root, KP + "crate.glb", _g(3.1, 0.9), 0.5, 1.2)
	_prop(root, KS + "barrel.glb", _g(-3.1, 1.0), 0.0, 1.1)
	_prop(root, KH + "lantern.glb", _g(2.2, 1.9), 0.0, 1.2)
	_prop(root, KH + "lantern.glb", _g(-2.2, 1.9), 0.0, 1.2)
	_tree(root, 0.0, -3.1, 0, 1.7)
	root.set_meta("bubble_y", 4.6)
