extends "res://scripts/world/arena_world.gd"
## 劉起佑版的「油畫」美術：秋天的樹林，滿地落葉都是一筆一筆的顏料，
## 樹幹是直向的深色筆觸，整個畫面再過一層油畫濾鏡。小關的 world.gd 改成 extends 這個檔案就會套用。
## 只換外觀，遊玩範圍、牆、障礙物、地形高度都跟原本一樣。

const GROUND_SHADER := preload("res://levels/liuchiyu/shaders/oil_ground.gdshader")
const TRUNK_SHADER := preload("res://levels/liuchiyu/shaders/oil_trunk.gdshader")
const LEAF_SHADER := preload("res://levels/liuchiyu/shaders/oil_leaf.gdshader")
const SKY_SHADER := preload("res://levels/liuchiyu/shaders/oil_sky.gdshader")
const FILTER_SHADER := preload("res://levels/liuchiyu/shaders/oil_filter.gdshader")

## 葉子的顏色（黃、橘為主，一點紅和綠）
const LEAF_COLORS := [
	Color(0.90, 0.62, 0.16), Color(0.84, 0.46, 0.12), Color(0.92, 0.70, 0.24), Color(0.72, 0.34, 0.12),
	Color(0.56, 0.24, 0.12), Color(0.70, 0.44, 0.14), Color(0.94, 0.74, 0.30), Color(0.78, 0.52, 0.18),
]
## 地上的落葉和草叢只用這幾個比較暗、比較接近的顏色，地面才不會花
const GROUND_LEAF_COLORS := [
	Color(0.56, 0.26, 0.10), Color(0.70, 0.40, 0.12), Color(0.42, 0.18, 0.12), Color(0.80, 0.56, 0.16),
	Color(0.62, 0.20, 0.12), Color(0.40, 0.42, 0.16), Color(0.40, 0.24, 0.34), Color(0.84, 0.66, 0.22),
]
## 背光那一面的葉子往這個顏色靠（深紅棕）
const LEAF_SHADE := Color(0.34, 0.14, 0.12)
## 從場地看向太陽的方向：從鏡頭的左前方照過來；要夠高，陽光才越得過外圍的懸崖照進場內
const SUN_DIR := Vector3(-0.36, 0.89, -0.27)
const LEAF_LIT_SHADER := preload("res://levels/liuchiyu/shaders/oil_leaf_lit.gdshader")
const ROCK_SHADER := preload("res://levels/liuchiyu/shaders/oil_rock.gdshader")
const SEA_SHADER := preload("res://levels/liuchiyu/shaders/oil_sea.gdshader")

## 樹林外面那一圈石頭懸崖（只有外觀，遊玩範圍不變）。小關可以在 _configure() 裡改這幾個數字。
## island = true：場地是一座島，樹林外面的岩壁一層一層往下掉進海裡，四周都是海。
## island = false：岩壁往上長，把樹林包在一圈高牆裡（cliff_height 是牆的高度）。
var island := true
var sea_level := -4.5       # 海面的高度（場地地面大約在 0～2）
var cliff_inner := 10.0     # 懸崖邊離遊玩範圍最近多遠（中間這一段就是樹林）
var cliff_width := 7.0      # 從崖邊到崖底（或崖頂）的水平距離
var cliff_height := 20.0    # island = false 時懸崖大概多高
var cliff_steps := 4.0      # 分成幾層岩階

## 晚上（有極光）的版本。遊戲中按 N 可以切換白天／晚上，只換外觀，不影響玩法。
## 小關想一開始就是晚上，在 _configure() 裡寫 night = true。
var night := false
var _leaf_mats: Array = []      # 所有要跟著日夜換色的材質（葉子、地面）
var _grass_mat: ShaderMaterial
var _sky_mat: ShaderMaterial
var _env: Environment
var _sun: DirectionalLight3D

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_N:
		night = not night
		_apply_time()

## 依白天／晚上設定光線、霧、天空和葉子的色調
func _apply_time() -> void:
	if _sky_mat:
		_sky_mat.set_shader_parameter("night", 1.0 if night else 0.0)
	if _env:
		if night:
			_env.ambient_light_color = Color(0.30, 0.48, 0.52)     # 極光映下來的藍綠色
			_env.ambient_light_energy = 1.0
			_env.fog_light_color = Color(0.04, 0.14, 0.16)
			_env.fog_density = 0.0055
			_env.fog_sun_scatter = 0.0
			_env.glow_intensity = 0.45
			_env.glow_hdr_threshold = 0.95
		else:
			_env.ambient_light_color = Color(0.62, 0.42, 0.52)     # 陰影偏紫紅，不是黑的
			_env.ambient_light_energy = 0.85
			_env.fog_light_color = Color(1.0, 0.92, 0.68)          # 發亮的淡黃色薄霧
			_env.fog_density = 0.0036
			_env.fog_sun_scatter = 0.12
			_env.glow_intensity = 0.12
			_env.glow_hdr_threshold = 1.8
	if _sun:
		# 晚上同一盞燈當月光：偏藍、弱很多
		_sun.light_color = Color(0.66, 0.82, 0.92) if night else Color(1.0, 0.86, 0.56)
		_sun.light_energy = 1.15 if night else 2.2
	for m in _leaf_mats:
		(m as ShaderMaterial).set_shader_parameter("night", 1.0 if night else 0.0)
	if _grass_mat:
		_grass_mat.set_shader_parameter("root_color", Color(0.10, 0.24, 0.32) if night else Color(0.20, 0.13, 0.06))
		_grass_mat.set_shader_parameter("tip_color", Color(0.62, 0.86, 0.88) if night else Color(0.74, 0.60, 0.22))

func _init() -> void:
	grass_count = 220        # 草少一點，地面比較乾淨
	ground_a = Color(0.62, 0.30, 0.08)
	ground_b = Color(0.40, 0.17, 0.08)
	dirt_color = Color(0.30, 0.12, 0.08)
	tree_green = Color(0.9, 0.6, 0.1)

func _leaf_color(r: RandomNumberGenerator) -> Color:
	var c: Color = LEAF_COLORS[r.randi() % LEAF_COLORS.size()]
	var v := r.randf_range(0.82, 1.1)
	return Color(c.r * v, c.g * v, c.b * v)

func _leaf_material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = LEAF_SHADER
	_leaf_mats.append(m)
	return m

# ---------------------------------------------------------------- 地面

func _tweak_terrain_material(mat: ShaderMaterial) -> void:
	mat.shader = GROUND_SHADER
	mat.set_shader_parameter("origin", _ground_origin())
	_leaf_mats.append(mat)

## 地面和岩石的筆觸以哪裡為原點（同一座島在不同小關要畫得一樣，就讓原點跟著島走）
func _ground_origin() -> Vector2:
	return Vector2.ZERO

## 這個位置離鏡頭一開始的位置太近、不要長樹（免得一開場鏡頭卡在樹裡）
func _near_camera(px: float, pz: float) -> bool:
	return Vector2(px - camera_start.x, pz - camera_start.z).length() < 10.0

## 要撒落葉、長草叢的範圍（預設只有遊玩範圍；一整座島的話每個小關的空地都要）。
## 回傳 [[範圍, 亂數編號], ...]：同一個編號不管從哪一小關看，撒出來的位置都一樣
func _leaf_areas() -> Array:
	return [[Rect2(play_min, play_max - play_min), 0]]

func _build_distant_layers() -> void:
	pass        # 遠處被金色的薄霧蓋住

# ---------------------------------------------------------------- 光線、天空、濾鏡

func _build_extra() -> void:
	_apply_look()
	_build_cliff()
	if island:
		_build_sea()
	_build_ground_leaves()
	_build_falling_leaves()
	_build_filter.call_deferred()

func _apply_look() -> void:
	var main := get_parent()
	if main == null:
		return
	var we := main.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if we and we.environment:
		var env: Environment = we.environment.duplicate()
		var sm := ShaderMaterial.new()
		sm.shader = SKY_SHADER
		var sky := Sky.new()
		sky.sky_material = sm
		sky.radiance_size = Sky.RADIANCE_SIZE_32      # 極光每一幀都在動，反射用的小圖不用大
		_sky_mat = sm
		_env = env
		env.background_mode = Environment.BG_SKY
		env.sky = sky
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(0.62, 0.42, 0.52)     # 陰影偏紫紅，不是黑的
		env.ambient_light_energy = 0.85
		env.fog_enabled = true
		env.fog_light_color = Color(1.0, 0.92, 0.68)     # 發亮的淡黃色薄霧，遠處的樹幹一排一排淡進去
		env.fog_density = 0.0036
		env.fog_sun_scatter = 0.12
		env.fog_sky_affect = 0.0
		env.volumetric_fog_enabled = false
		env.ssao_enabled = false        # 過了油畫濾鏡幾乎看不出來，省下來
		env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED      # 材質都不反光，不用每一幀更新天空的反射圖
		env.glow_enabled = true
		env.glow_intensity = 0.12
		env.glow_bloom = 0.0
		env.glow_hdr_threshold = 1.8
		env.adjustment_enabled = true
		env.adjustment_brightness = 1.0
		env.adjustment_contrast = 1.08
		env.adjustment_saturation = 1.0
		we.environment = env
	var sun := main.get_node_or_null("Sun") as DirectionalLight3D
	if sun:
		sun.basis = Basis.looking_at(-SUN_DIR.normalized())
		sun.light_color = Color(1.0, 0.86, 0.56)
		sun.light_energy = 2.2
		sun.shadow_enabled = true
		sun.shadow_blur = 0.6
		# 陰影是最花的一項：只分兩層、只畫到 80 公尺（再遠的被薄霧蓋住，看不出來）
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
		sun.directional_shadow_split_1 = 0.28
		sun.directional_shadow_blend_splits = true
		sun.directional_shadow_max_distance = 80.0
		_sun = sun
	_apply_time()
	_lighten_viewport()

## 整個畫面最後都會過油畫濾鏡（邊緣本來就糊成一筆一筆的），不需要 4 倍的多重取樣反鋸齒：
## 在這個大關裡改用便宜的 FXAA，離開關卡時還原成專案原本的設定（不影響別人的大關）
## 3D 畫面也只用 85% 的解析度算（濾鏡跟著少算三成的像素），再放大到全螢幕；
## 濾鏡的筆觸間距跟著縮成 85%，放大回來之後筆觸大小跟原本一樣。介面文字不受影響，還是全解析度。
const RENDER_SCALE := 0.85
var _vp_saved := {}

func _lighten_viewport() -> void:
	var vp := get_viewport()
	if vp == null or not _vp_saved.is_empty():
		return
	_vp_saved = {"msaa": vp.msaa_3d, "ssaa": vp.screen_space_aa, "scale": vp.scaling_3d_scale}
	vp.msaa_3d = Viewport.MSAA_DISABLED
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
	vp.scaling_3d_scale = RENDER_SCALE

func _exit_tree() -> void:
	var vp := get_viewport()
	if vp != null and not _vp_saved.is_empty():
		vp.msaa_3d = _vp_saved["msaa"]
		vp.screen_space_aa = _vp_saved["ssaa"]
		vp.scaling_3d_scale = _vp_saved["scale"]
	_vp_saved = {}

## 油畫濾鏡：一片貼在鏡頭前面的全螢幕面。介面（CanvasLayer）不受影響。
func _build_filter() -> void:
	var main := get_parent()
	if main == null:
		return
	var cam := main.get_node_or_null("Player/Head/Camera3D") as Camera3D
	if cam == null:
		cam = get_viewport().get_camera_3d()
	if cam == null or cam.has_node("OilFilter"):
		return
	var quad := MeshInstance3D.new()
	quad.name = "OilFilter"
	var qm := QuadMesh.new()
	qm.size = Vector2(2.0, 2.0)
	quad.mesh = qm
	var m := ShaderMaterial.new()
	m.shader = FILTER_SHADER
	m.set_shader_parameter("spread", 2.0 * RENDER_SCALE)     # 3D 解析度降到 85%，筆觸間距跟著縮，放大回來大小不變
	m.render_priority = -100        # 最先畫，血條、視野扇形這些半透明的東西才會蓋在上面
	quad.material_override = m
	quad.extra_cull_margin = 16000.0
	quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	quad.position = Vector3(0, 0, -1.0)
	cam.add_child(quad)

# ---------------------------------------------------------------- 石頭懸崖

## 崖腳離遊玩範圍多遠（沿著邊緣忽遠忽近，輪廓才不會是一條直線）
func _cliff_edge(x: float, z: float) -> float:
	return cliff_inner + (_noise.get_noise_2d(x * 0.9 + 31.0, z * 0.9 - 17.0) * 0.5 + 0.5) * 4.0

## 這個位置的崖頂比原本的地面高多少（有高有低，天際線才不會是平的）
func _cliff_top(x: float, z: float) -> float:
	return cliff_height * (0.88 + 0.24 * (_noise.get_noise_2d(x * 0.6 - 80.0, z * 0.6 + 12.0) * 0.5 + 0.5))

## 島：懸崖邊以外的共用地形整個沉到海底下，換成我們自己蓋的岩壁和海
func arena_height(x: float, z: float) -> float:
	var h := _land_h(x, z)
	if island:
		# 地面在崖邊「內側」一點就沉下去，沉下去的那一圈整個藏在崖邊的岩石底下；
		# 不然地形網格被拉下去的邊會從岩石外面露出來，島的邊緣變成一排鋸齒
		h -= sstep(-1.1, -0.3, _edge_d(x, z)) * 60.0
	return h

## 離懸崖邊多遠：負的 = 還在陸地上，正的 = 已經超出崖邊。子類別可以覆寫成別的形狀（例如一整座島）
func _edge_d(x: float, z: float) -> float:
	return play_dist(x, z) - _cliff_edge(x, z)

## 離「不能長樹的空地」多遠（預設就是遊玩範圍）
func _clear_d(x: float, z: float) -> float:
	return play_dist(x, z)

## 這個位置可不可以長樹（子類別用來排除陡坡、階梯）
func _tree_ok(_x: float, _z: float) -> bool:
	return true

## 這個位置可不可以擺崖邊的大石頭和海裡的礁石（子類別用來空出河口）
func _rock_ok(_x: float, _z: float) -> bool:
	return true

## 陸地大概的範圍（懸崖、海、樹林都以這個範圍往外蓋）
func _amin() -> Vector2:
	return play_min
func _amax() -> Vector2:
	return play_max

## 樹林格子的原點（同一座島在不同小關要長出一樣的樹，就讓格子跟著島走）
func _forest_origin() -> Vector2:
	return Vector2.ZERO

## 沒有沉下去之前的地面高度（岩壁從這個高度開始往下／往上蓋）
func _land_h(x: float, z: float) -> float:
	return super.arena_height(x, z)

## 0 = 還在崖腳裡面，0～1 = 在崖壁上，1 = 在崖頂上
func _cliff_t(x: float, z: float) -> float:
	return clampf(_edge_d(x, z) / cliff_width, 0.0, 1.0)

## 懸崖把地面墊高多少：一層一層的岩階，每層是一段陡壁加一小段平台
func cliff_h(x: float, z: float) -> float:
	var t := _cliff_t(x, z)
	if t <= 0.0:
		return 0.0
	var top := _cliff_top(x, z)
	if island:
		# 一路降到海面底下（不管原本地面多高，崖底都在水裡）
		top = sea_level - 2.5 - top * 0.12 - _land_h(x, z)
	if t >= 1.0:
		return top
	var st := t * cliff_steps
	var fl := floorf(st)
	return top * (fl + smoothstep(0.0, 0.38, st - fl)) / cliff_steps

## 外圍擺東西用的地面高度（包含懸崖）
func _gy(x: float, z: float) -> float:
	if _cliff_t(x, z) <= 0.0:
		return height_at(x, z)
	return _land_h(x, z) + cliff_h(x, z)

func _on_cliff_face(x: float, z: float) -> bool:
	var d := _edge_d(x, z)
	return d > -0.6 and d < cliff_width + 0.8

func _cliff_material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = ROCK_SHADER
	m.set_shader_parameter("origin", _ground_origin())
	m.set_shader_parameter("night", 1.0 if night else 0.0)
	_leaf_mats.append(m)        # 上面的落葉斑點跟著日夜切換
	return m

func _build_cliff() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = world_seed + 97
	var step := 0.8
	var ext := cliff_inner + 5.0 + cliff_width + 16.0
	var x0 := _amin().x - ext
	var z0 := _amin().y - ext
	var nx := int(ceil((_amax().x + ext - x0) / step)) + 1
	var nz := int(ceil((_amax().y + ext - z0) / step)) + 1
	var pts := PackedVector3Array()
	var ts := PackedFloat32Array()
	pts.resize(nx * nz)
	ts.resize(nx * nz)
	var ds := PackedFloat32Array()
	ds.resize(nx * nz)
	for ix in nx:
		for iz in nz:
			var x := x0 + ix * step
			var z := z0 + iz * step
			var t := _cliff_t(x, z)
			var p := Vector3(x, _land_h(x, z) + cliff_h(x, z), z)
			ds[ix * nz + iz] = _edge_d(x, z)
			if t > 0.0 and t < 1.0:
				# 崖壁上的點往旁邊、上下各推一點，面才會一塊一塊有稜有角
				p += Vector3(r.randf_range(-0.32, 0.32), r.randf_range(-0.45, 0.45), r.randf_range(-0.32, 0.32))
			elif t <= 0.0:
				# 往上的懸崖：崖腳埋進地面一點；島：崖邊一圈岩石稍微高出地面，蓋住地形的接縫
				p.y += 0.07 if island else -0.35
			pts[ix * nz + iz] = p
			ts[ix * nz + iz] = t
	var rock := SurfaceTool.new()
	rock.begin(Mesh.PRIMITIVE_TRIANGLES)
	var top := SurfaceTool.new()
	top.begin(Mesh.PRIMITIVE_TRIANGLES)
	top.set_color(Color(0, 0, 0))
	for ix in nx - 1:
		for iz in nz - 1:
			var i00 := ix * nz + iz
			var i10 := (ix + 1) * nz + iz
			var i01 := ix * nz + iz + 1
			var i11 := (ix + 1) * nz + iz + 1
			var tmax := maxf(maxf(ts[i00], ts[i10]), maxf(ts[i01], ts[i11]))
			var dmax := maxf(maxf(ds[i00], ds[i10]), maxf(ds[i01], ds[i11]))
			if (dmax <= -2.4) if island else (tmax <= 0.0):
				continue        # 還在場內，不用蓋
			var tmin := minf(minf(ts[i00], ts[i10]), minf(ts[i01], ts[i11]))
			var st := top if (tmin >= 1.0 and not island) else rock
			for tri in [[i00, i10, i11], [i00, i11, i01]]:
				var a := pts[tri[0]]
				var b := pts[tri[1]]
				var c := pts[tri[2]]
				var n := (b - a).cross(c - a)
				if n.y > 0.0:        # Godot 的正面是順時針
					var tmp := b
					b = c
					c = tmp
				else:
					n = -n
				st.set_normal(n.normalized())
				st.add_vertex(a)
				st.add_vertex(b)
				st.add_vertex(c)
	var mi := MeshInstance3D.new()
	mi.name = "CliffRock"
	mi.mesh = rock.commit()
	mi.material_override = _cliff_material()
	add_child(mi)
	var gm := ShaderMaterial.new()
	gm.shader = GROUND_SHADER
	gm.set_shader_parameter("origin", _ground_origin())
	_leaf_mats.append(gm)
	var ti := MeshInstance3D.new()
	ti.name = "CliffTop"
	ti.mesh = top.commit()
	ti.material_override = gm
	add_child(ti)
	# 崖腳和岩階上散落的大石塊
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.radial_segments = 6
	sm.rings = 3
	var xf: Array[Transform3D] = []
	var tries := 0
	while xf.size() < 110 and tries < 20000:
		tries += 1
		var x := r.randf_range(_amin().x - cliff_inner - 8.0, _amax().x + cliff_inner + 8.0)
		var z := r.randf_range(_amin().y - cliff_inner - 8.0, _amax().y + cliff_inner + 8.0)
		var d := _edge_d(x, z)
		if d < -2.5 or d > cliff_width * 0.6 or not _rock_ok(x, z):
			continue
		var sc := r.randf_range(0.9, 2.6)
		var b := Basis.from_euler(Vector3(r.randf() * TAU, r.randf() * TAU, r.randf() * TAU)).scaled(Vector3(sc * r.randf_range(0.8, 1.4), sc * r.randf_range(0.6, 1.0), sc * r.randf_range(0.8, 1.3)))
		xf.append(Transform3D(b, Vector3(x, _gy(x, z) + sc * 0.2, z)))
	# 島：海裡再立幾塊尖尖的礁石
	tries = 0
	var stacks := 0
	while island and stacks < 22 and tries < 20000:
		tries += 1
		var x := r.randf_range(_amin().x - cliff_inner - 26.0, _amax().x + cliff_inner + 26.0)
		var z := r.randf_range(_amin().y - cliff_inner - 26.0, _amax().y + cliff_inner + 26.0)
		var d := _edge_d(x, z)
		if d < cliff_width * 0.8 or d > cliff_width + 14.0 or not _rock_ok(x, z):
			continue
		var sc := r.randf_range(0.8, 2.2)
		var b := Basis.from_euler(Vector3(r.randf_range(-0.25, 0.25), r.randf() * TAU, r.randf_range(-0.25, 0.25))).scaled(Vector3(sc, sc * r.randf_range(1.3, 2.4), sc * r.randf_range(0.8, 1.2)))
		xf.append(Transform3D(b, Vector3(x, sea_level, z)))
		stacks += 1
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = sm
	mm.instance_count = xf.size()
	for i in xf.size():
		mm.set_instance_transform(i, xf[i])
	var bi := MultiMeshInstance3D.new()
	bi.name = "CliffBoulders"
	bi.multimesh = mm
	bi.material_override = _cliff_material()
	add_child(bi)

# ---------------------------------------------------------------- 海

## 海面的格線座標：島附近密（才能記下離岸邊多近），外海幾大格一路鋪到很遠
func _sea_axis(lo: float, hi: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var far := [900.0, 520.0, 300.0, 170.0, 100.0]
	var near := cliff_inner + cliff_width + 34.0
	for f in far:
		out.append(lo - near - f)
	var v := lo - near
	while v < hi + near:
		out.append(v)
		v += 2.0
	out.append(hi + near)
	far.reverse()
	for f in far:
		out.append(hi + near + f)
	return out

func _build_sea() -> void:
	var xs := _sea_axis(_amin().x, _amax().x)
	var zs := _sea_axis(_amin().y, _amax().y)
	var nz := zs.size()
	var depth := PackedFloat32Array()
	depth.resize(xs.size() * nz)
	for ix in xs.size():
		for iz in nz:
			var x := xs[ix]
			var z := zs[iz]
			var dp := 1.0
			var d := _edge_d(x, z)
			if d < cliff_width + 6.0:
				# 水有多深（0 = 剛好碰到岩壁，1 = 外海），岸邊的浪花用
				dp = clampf((sea_level - (_land_h(x, z) + cliff_h(x, z))) / 2.2, -1.0, 1.0) if d > 0.0 else -1.0
			depth[ix * nz + iz] = dp
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	for ix in xs.size() - 1:
		for iz in nz - 1:
			var idx := [ix * nz + iz, (ix + 1) * nz + iz, (ix + 1) * nz + iz + 1, ix * nz + iz + 1]
			var cs := [Vector2(xs[ix], zs[iz]), Vector2(xs[ix + 1], zs[iz]), Vector2(xs[ix + 1], zs[iz + 1]), Vector2(xs[ix], zs[iz + 1])]
			if maxf(maxf(depth[idx[0]], depth[idx[1]]), maxf(depth[idx[2]], depth[idx[3]])) <= -1.0:
				continue        # 整格都在島上
			for k in [0, 1, 2, 0, 2, 3]:
				st.set_color(Color(clampf(depth[idx[k]], 0.0, 1.0), 0, 0))
				st.add_vertex(Vector3(cs[k].x, sea_level, cs[k].y))
	var m := ShaderMaterial.new()
	m.shader = SEA_SHADER
	m.set_shader_parameter("sun_dir", SUN_DIR)
	m.set_shader_parameter("center", (_amin() + _amax()) * 0.5)
	_leaf_mats.append(m)        # 跟著日夜切換
	var mi := MeshInstance3D.new()
	mi.name = "Sea"
	mi.mesh = st.commit()
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)

# ---------------------------------------------------------------- 落葉

## 地上一片一片凸起來的落葉筆觸（貼著地面的小面片）
func _build_ground_leaves() -> void:
	var r := RandomNumberGenerator.new()
	var xf: Array[Transform3D] = []
	var cols: Array[Color] = []
	var o := _ground_origin()
	for area in _leaf_areas():
		var rect: Rect2 = area[0]
		r.seed = world_seed + 61 + int(area[1]) * 1000
		for k in 1300:        # 落葉少一點：地面不會那麼花，也少畫很多小面片
			# 每一輪固定抽一樣多個亂數（不管這一片要不要），這樣同一個範圍每次撒出來都一樣
			var x := rect.position.x - 8.0 + r.randf() * (rect.size.x + 16.0)
			var z := rect.position.y - 8.0 + r.randf() * (rect.size.y + 16.0)
			var clump := r.randf()
			var s := r.randf_range(0.28, 0.6)
			var tilt := r.randf_range(-0.25, 0.25)
			var yaw := r.randf() * TAU
			var lift := r.randf_range(0.03, 0.09)
			var gc: Color = GROUND_LEAF_COLORS[r.randi() % GROUND_LEAF_COLORS.size()]
			var gv := r.randf_range(0.85, 1.05)
			if in_water(x, z) or _on_cliff_face(x, z):
				continue
			# 一堆一堆的，不是平均撒（用島的座標算，才不會每一關堆的地方不一樣）
			if _noise.get_noise_2d((x - o.x) * 3.0 + 50.0, (z - o.y) * 3.0) < -0.05 + clump * 0.2:
				continue
			var b := Basis.from_euler(Vector3(-PI * 0.5 + tilt, yaw, 0.0)).scaled(Vector3(s, s * 0.55, s))
			xf.append(Transform3D(b, Vector3(x, _gy(x, z) + lift, z)))
			cols.append(Color(gc.r * gv, gc.g * gv, gc.b * gv))
	var lm := ShaderMaterial.new()
	lm.shader = LEAF_LIT_SHADER
	_leaf_mats.append(lm)
	_leaf_multimesh("GroundLeaves", xf, cols, lm, false)
	_build_tufts()

## 地上一叢一叢尖尖的葉子（黃、綠、橘），每叢是幾筆往外斜的長筆觸
func _build_tufts() -> void:
	var r := RandomNumberGenerator.new()
	var tuft_cols := [Color(0.88, 0.74, 0.24), Color(0.50, 0.60, 0.24), Color(0.84, 0.52, 0.14), Color(0.30, 0.44, 0.22)]
	var xf: Array[Transform3D] = []
	var cols: Array[Color] = []
	for area in _leaf_areas():
		var rect: Rect2 = area[0]
		for k in 110:
			# 每一叢用自己的亂數種子，這樣同一個範圍每次長出來都一樣
			r.seed = world_seed + 77 + int(area[1]) * 1000 + k
			var x := rect.position.x - 10.0 + r.randf() * (rect.size.x + 20.0)
			var z := rect.position.y - 10.0 + r.randf() * (rect.size.y + 20.0)
			if in_water(x, z) or _on_cliff_face(x, z):
				continue
			_one_tuft(r, x, z, tuft_cols, xf, cols)
	_leaf_multimesh("Tufts", xf, cols, null, false)

func _one_tuft(r: RandomNumberGenerator, x: float, z: float, tuft_cols: Array, xf: Array[Transform3D], cols: Array[Color]) -> void:
	if true:
		var c: Color = tuft_cols[r.randi() % tuft_cols.size()]
		var gy := _gy(x, z)
		var size := r.randf_range(0.3, 0.55)
		var n := r.randi_range(5, 8)
		for j in n:
			var yaw := TAU * float(j) / float(n) + r.randf_range(-0.3, 0.3)
			var lean := r.randf_range(0.2, 0.7)
			var l := size * r.randf_range(0.8, 1.25)
			# 面片的 X 軸當葉子的長邊：先立起來再往外倒
			var b := Basis.from_euler(Vector3(0.0, yaw, PI * 0.5 - lean)).scaled(Vector3(l, l * 0.34, l))
			xf.append(Transform3D(b, Vector3(x, gy + 0.02, z) + b.x.normalized() * l * 0.4))
			var v := r.randf_range(0.6, 0.85)
			cols.append(Color(c.r * v, c.g * v, c.b * v))

## shadow = false：貼在地上的小東西不投影子（影子看不出來，卻要多畫好幾次）
func _leaf_multimesh(node_name: String, xf: Array[Transform3D], cols: Array[Color], mat: ShaderMaterial = null, shadow := true) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var qm := QuadMesh.new()
	qm.size = Vector2(1.0, 1.0)
	mm.mesh = qm
	mm.instance_count = xf.size()
	for i in xf.size():
		mm.set_instance_transform(i, xf[i])
		mm.set_instance_color(i, cols[i])
	var mi := MultiMeshInstance3D.new()
	mi.name = node_name
	mi.multimesh = mm
	mi.material_override = mat if mat else _leaf_material()
	if not shadow:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)

## 慢慢飄下來的葉子
func _build_falling_leaves() -> void:
	var c := (play_min + play_max) * 0.5
	var size := play_max - play_min
	var p := CPUParticles3D.new()
	p.name = "FallingLeaves"
	p.amount = 70
	p.lifetime = 11.0
	p.preprocess = 11.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(size.x * 0.5 + 5.0, 0.5, size.y * 0.5 + 5.0)
	p.direction = Vector3(0.4, -1.0, 0.2)
	p.spread = 25.0
	p.gravity = Vector3(0.15, -0.25, 0.1)
	p.initial_velocity_min = 0.5
	p.initial_velocity_max = 1.1
	p.angle_min = -180.0
	p.angle_max = 180.0
	p.angular_velocity_min = -120.0
	p.angular_velocity_max = 120.0
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.5
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.35, 0.65, 1.0])
	grad.colors = PackedColorArray([Color(1.0, 0.82, 0.14), Color(1.0, 0.60, 0.08), Color(0.86, 0.32, 0.10), Color(0.75, 0.80, 0.25)])
	p.color_initial_ramp = grad
	var qm := QuadMesh.new()
	qm.size = Vector2(0.34, 0.2)
	p.mesh = qm
	p.material_override = _leaf_material()
	p.position = Vector3(c.x, height_at(c.x, c.y) + 10.0, c.y)
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)

# ---------------------------------------------------------------- 草和樹林

func _build_arena_grass() -> void:
	super()
	var g := get_node_or_null("Grass") as MultiMeshInstance3D
	if g and g.material_override is ShaderMaterial:
		var m := g.material_override as ShaderMaterial
		_grass_mat = m
		_apply_time()

## 外圍的樹林：又高又直的深色樹幹，到高處才分枝，葉子一團一團長在頭頂；林下有小樹苗。
## 每棵樹有自己的主色（整棵偏黃、偏橘或偏紅），偶爾一棵白樺。
var _trunk_xf: Array[Transform3D] = []
var _trunk_col: Array[Color] = []
var _leaf_xf: Array[Transform3D] = []
var _leaf_col: Array[Color] = []

## 一段樹枝：從 a 到 b，底部半徑 rad（網格本身上面比較細）
func _seg(a: Vector3, b: Vector3, rad: float, col: Color) -> void:
	var y := b - a
	var l := y.length()
	if l < 0.01:
		return
	y /= l
	var x := y.cross(Vector3(0.31, 0.12, 0.94))
	if x.length() < 0.05:
		x = y.cross(Vector3.RIGHT)
	x = x.normalized()
	var z := x.cross(y)
	_trunk_xf.append(Transform3D(Basis(x * rad, y * l, z * rad), (a + b) * 0.5))
	_trunk_col.append(col)

## 把方向 dir 往旁邊偏 ang 弧度，az 是繞著 dir 的方位
func _tilt(dir: Vector3, ang: float, az: float) -> Vector3:
	var p := dir.cross(Vector3.UP)
	if p.length() < 0.05:
		p = Vector3.RIGHT
	p = p.normalized()
	var q := dir.cross(p).normalized()
	return (dir * cos(ang) + (p * cos(az) + q * sin(az)) * sin(ang)).normalized()

## 枝頭的一團葉子
func _leaf_clump(r: RandomNumberGenerator, c: Vector3, rc: float, n: int, tint: Color) -> void:
	for k in n:
		var o := Vector3(r.randf_range(-1.0, 1.0), r.randf_range(-0.6, 0.75), r.randf_range(-1.0, 1.0))
		if o.length() > 1.0:
			o = o.normalized() * r.randf_range(0.5, 1.0)
		var s := r.randf_range(0.85, 1.6)        # 葉子的筆觸少一點、大一點：樹冠是幾大塊顏色，不是一堆碎片
		var b := Basis.from_euler(Vector3(r.randf_range(-1.2, 1.2), r.randf() * TAU, r.randf_range(-0.8, 0.8))).scaled(Vector3(s, s * 0.6, s))
		_leaf_xf.append(Transform3D(b, c + o * rc))
		var col := _leaf_color(r)
		if r.randf() < 0.72:
			var v := r.randf_range(0.8, 1.12)
			col = Color(tint.r * v, tint.g * v, tint.b * v)
		# 顏色就是顏料：朝太陽那一面用亮的顏色，背光那一面混進深紅棕
		var lit := clampf(o.normalized().dot(SUN_DIR.normalized()) * 0.75 + 0.5 + r.randf_range(-0.2, 0.2), 0.0, 1.0)
		col = LEAF_SHADE.lerp(col, 0.25 + 0.75 * lit)
		if lit > 0.8:
			col = col.lerp(Color(1.0, 0.93, 0.55), 0.3)
		_leaf_col.append(col)

## 一根枝（中間稍微彎一下），到頭再分叉；depth 用完就長葉子
func _limb(r: RandomNumberGenerator, a: Vector3, dir: Vector3, l: float, rad: float, depth: int, col: Color, tint: Color) -> void:
	var mid := a + dir * l * 0.5
	var d2 := _tilt(dir, r.randf_range(0.05, 0.22), r.randf() * TAU)
	var b := mid + d2 * l * 0.5
	_seg(a, mid + dir * 0.04, rad, col)
	_seg(mid, b, rad * 0.78, col)
	if depth <= 0 or rad < 0.03:
		_leaf_clump(r, b, clampf(l * 0.8, 1.0, 1.9), 5, tint)
		return
	if depth == 1:
		_leaf_clump(r, b, 1.0, 2, tint)
	var n := 2 + (1 if r.randf() < 0.45 else 0)
	var az0 := r.randf() * TAU
	for k in n:
		var nd := _tilt(d2, r.randf_range(0.45, 0.85), az0 + TAU * float(k) / float(n) + r.randf_range(-0.4, 0.4))
		nd = (nd + Vector3.UP * 0.22).normalized()
		_limb(r, b - d2 * 0.06, nd, l * r.randf_range(0.62, 0.8), rad * 0.6 * r.randf_range(0.8, 1.0), depth - 1, col, tint)

func _oil_tree(r: RandomNumberGenerator, base: Vector3, h: float, rad: float, birch: bool, depth: int) -> void:
	var col := Color(1.0 if birch else 0.0, r.randf(), 0.0)
	var tint: Color = LEAF_COLORS[r.randi() % LEAF_COLORS.size()]
	var up := _tilt(Vector3.UP, r.randf_range(0.0, 0.05), r.randf() * TAU)
	# 又高又直的樹幹，到六成高以上才開始分枝，葉子都在頭頂上
	var th := h * r.randf_range(0.56, 0.68)
	_seg(base - up * 0.4, base + up * th * 0.5, rad * 1.2, col)
	var d2 := _tilt(up, r.randf_range(0.02, 0.08), r.randf() * TAU)
	var top := base + up * th * 0.5 + d2 * th * 0.5
	_seg(base + up * (th * 0.5 - 0.05), top, rad * 0.95, col)
	# 樹幹上半段斜斜伸出去的細枝
	for k in r.randi_range(1, 3):
		var f := r.randf_range(0.62, 0.95)
		var at := base + up * th * 0.5 + d2 * th * (f - 0.5)
		_limb(r, at, _tilt(up, r.randf_range(0.7, 1.1), r.randf() * TAU), h * r.randf_range(0.12, 0.2), rad * 0.3, 0, col, tint)
	var n := 3 + (1 if r.randf() < 0.4 else 0)
	var az0 := r.randf() * TAU
	for k in n:
		var nd := _tilt(d2, r.randf_range(0.25, 0.6), az0 + TAU * float(k) / float(n) + r.randf_range(-0.4, 0.4))
		_limb(r, top - d2 * 0.08, nd, h * r.randf_range(0.16, 0.24), rad * 0.6, depth, col, tint)

## 林下的小樹苗：一根細枝，掛幾片大大的黃葉
func _sapling(r: RandomNumberGenerator, base: Vector3) -> void:
	var col := Color(0.0, r.randf(), 0.0)
	var tint := Color(0.98, 0.84, 0.26) if r.randf() < 0.6 else Color(0.92, 0.50, 0.14)
	var h := r.randf_range(1.6, 3.2)
	var up := _tilt(Vector3.UP, r.randf_range(0.05, 0.2), r.randf() * TAU)
	_seg(base - up * 0.2, base + up * h, 0.045, col)
	for k in 3:
		var f := r.randf_range(0.45, 1.0)
		var o := Vector3(r.randf_range(-0.5, 0.5), 0.0, r.randf_range(-0.5, 0.5))
		_seg(base + up * h * f * 0.8, base + up * h * f + o, 0.025, col)
		_leaf_clump(r, base + up * h * f + o, 0.45, 3, tint)

func _build_arena_forest() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = world_seed + 31
	_trunk_xf.clear()
	_trunk_col.clear()
	_leaf_xf.clear()
	_leaf_col.clear()
	var band := cliff_inner + 5.0 + cliff_width + 12.0
	var step := 3.0
	var org := _forest_origin()
	var ix0 := int(floor((_amin().x - band - org.x) / step))
	var ix1 := int(ceil((_amax().x + band - org.x) / step))
	var iz0 := int(floor((_amin().y - band - org.y) / step))
	var iz1 := int(ceil((_amax().y + band - org.y) / step))
	for ix in range(ix0, ix1 + 1):
		for iz in range(iz0, iz1 + 1):
			# 每一格用自己的亂數種子：同一格不管從哪一小關看，長出來的樹都一樣
			r.seed = hash(Vector3i(ix, iz, world_seed % 100000))
			var px := org.x + ix * step + r.randf_range(-1.3, 1.3)
			var pz := org.y + iz * step + r.randf_range(-1.3, 1.3)
			var cd := _clear_d(px, pz)
			var ed := _edge_d(px, pz)
			var pd := cd          # 離最近的空地多遠：遠的樹做簡單一點（用空地算，不是用現在這一關算，每一關看到的才會一樣）
			var near_cam := _near_camera(px, pz)
			var kv := r.randf()
			var keep := kv < 0.75
			var top_v := r.randf()
			var below := cd > 2.2 and ed < -1.2 and _tree_ok(px, pz)
			var on_top := not island and ed > cliff_width + 1.5 and ed < cliff_width + 17.0 and top_v < 0.35
			if (below or on_top) and not near_cam and keep:
				var birch := r.randf() < 0.1
				var h := r.randf_range(11.0, 16.0)
				# 粗細差很多：幾棵很粗的老樹，中間夾著很多細的
				var rad := (r.randf_range(0.42, 0.62) if r.randf() < 0.3 else r.randf_range(0.16, 0.32)) * (0.7 if birch else 1.0)
				# 遠的樹少分一層，省一點
				_oil_tree(r, Vector3(px, _gy(px, pz), pz), h, rad, birch, 2 if pd < 12.0 else 1)
			elif cd > 1.0 and cd < 14.0 and ed < -1.0 and _tree_ok(px, pz) and not near_cam and r.randf() < 0.3:
				_sapling(r, Vector3(px, _gy(px, pz), pz))
	var cm := CylinderMesh.new()
	cm.top_radius = 0.78
	cm.bottom_radius = 1.0
	cm.height = 1.0
	# 樹枝是一段一段接起來的，頭尾都埋在別段或葉子裡：不用蓋子、不用中間那一圈，面數少七成
	cm.radial_segments = 5
	cm.rings = 0
	cm.cap_top = false
	cm.cap_bottom = false
	var tm := MultiMesh.new()
	tm.transform_format = MultiMesh.TRANSFORM_3D
	tm.use_colors = true
	tm.mesh = cm
	tm.instance_count = _trunk_xf.size()
	for i in _trunk_xf.size():
		tm.set_instance_transform(i, _trunk_xf[i])
		tm.set_instance_color(i, _trunk_col[i])
	var tmi := MultiMeshInstance3D.new()
	tmi.name = "ForestTrunks"
	tmi.multimesh = tm
	var tmat := ShaderMaterial.new()
	tmat.shader = TRUNK_SHADER
	tmi.material_override = tmat
	add_child(tmi)
	_leaf_multimesh("ForestLeaves", _leaf_xf, _leaf_col)
