extends RefCounted
## 選關地圖上的「丹穴山」（chapter.gd 的 MAP_SCRIPT；由 scripts/level_select.gd 呼叫，不是關卡腳本）。
##
## 別的大關都是海上的島；丹穴山是仙境，所以做成一座「浮在雲海上的仙島」：
##   ‧島不碰海面：島面抬高，底下是往下收尖的山岩，四周一圈雲海，三道瀑布從島緣落進雲裡。
##   ‧島面從西往東一路升高，三個小關是同一卷畫的三段：
##       西（1 雲階）雪地紅梅、青綠的松、掛著畫的立軸　中（2 山海迴廊）石板街、木樓、攤子、銀杏、燈籠串
##       東（3 天門）深藍的星盤、地上一圈會轉的山海轉盤（十二個異獸紋章）、圓門和唱盤、頭頂一圈金環
##   ‧朝主島（北邊）那一側有一道雲階，從雲海一階一階接到島上；島的四周浮著幾座小仙山，仙鶴繞著島飛，一道鳳羽靈光在島上空盤旋。
## 模型跟關卡裡是同一批（assets/blender/）；島面的網格借用冰雪島的 art/isle_builder.gd（只是算形狀的工具）。

const Isle := preload("res://levels/ice/art/isle_builder.gd")
const World := preload("res://levels/heaven/heaven_world.gd")     # 只借用 HEAVEN_MOODS（每一關的配色）
const Fx := preload("res://levels/heaven/art/map_fx.gd")
const Spirit := preload("res://levels/heaven/art/spirit.gd")
const HM := "res://levels/heaven/assets/blender/"
const HS := "res://levels/heaven/shaders/"
const HT := "res://levels/heaven/assets/textures/"
const CLOUD := "res://levels/ice/assets/blender/cloud_puff_"
const TEX := "res://assets/textures/"
const STAGE_MOODS := ["ink", "gold", "astral"]
const FLOAT_H := 4.2          # 島面（中間）比海面高多少：浮在雲上
const SLOPE := 0.042          # 島面從西往東每公尺升高多少（三個小關一關比一關高）

var _cx := 11.5
var _ctx := {}
var _o := {}
var _rng := RandomNumberGenerator.new()
var _cloud_mat: StandardMaterial3D
var _fall_mat: ShaderMaterial

## 走到第 k 小關時的天色（照那一關的配色）
func mood(k: int) -> Dictionary:
	var md: Dictionary = World.HEAVEN_MOODS[STAGE_MOODS[clampi(k, 0, STAGE_MOODS.size() - 1)]]
	return {
		"sun": md.sun, "energy": md.energy, "rot": md.rot, "amb": md.amb, "amb_e": md.amb_e, "fog": md.fog,
		"sky.top_color": md.top, "sky.horizon_color": md.hor, "sky.cloud_color": md.cloud, "sky.cloud_shade": md.cloud_sh,
		"sea.deep": md.sea_deep, "sea.near_c": md.sea_near, "sea.stroke_c": md.sea_stroke,
		"sea.foam_c": (md.sea_stroke as Color).lerp(Color.WHITE, 0.6), "sea.horizon_c": md.sea_far,
	}

## 島面是一塊從西往東慢慢升高的斜面（路是站點之間拉直線，所以島面在東西向也要是直的）
func ground_y(x: float, _z: float) -> float:
	return FLOAT_H + SLOPE * (x - _cx)

func _g(x: float, z: float, lift := 0.0) -> Vector3:
	return Vector3(x, ground_y(x, z) + lift, z)

func build_island(root: Node3D, ctx: Dictionary) -> void:
	_ctx = ctx
	_rng.seed = 9090
	var c: Vector2 = ctx.center
	_cx = c.x
	var rx := float(ctx.rx)
	var rz := float(ctx.rz)
	_o = {"c": c, "rx": rx, "rz": rz, "seed": 6.6, "pow": 2.6, "wob": 1.1, "depth": 1.0, "slope": 0.10, "lobe": 2.6,
		"coves": [[0.8, 2.0, 0.14], [2.6, 1.8, 0.12], [4.4, 2.2, 0.14], [5.6, 1.6, 0.12]]}
	_cloud_mat = StandardMaterial3D.new()
	_cloud_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_cloud_mat.albedo_color = Color(1.0, 0.99, 0.97, 0.95)
	_cloud_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_fall_mat = ShaderMaterial.new()
	_fall_mat.shader = load(HS + "waterfall.gdshader")

	# ---- 島面：白玉色的石地（關卡裡沒有草地，島上也不要有）
	var top := MeshInstance3D.new()
	top.name = "Top"
	top.mesh = Isle.build_top(_o, ground_y, 128, 12, 0.3)
	var tm := StandardMaterial3D.new()
	tm.albedo_color = Color(0.86, 0.93, 0.92)
	tm.albedo_texture = load("res://levels/ice/assets/textures/snow_soft.png")
	tm.uv1_triplanar = true
	tm.uv1_world_triplanar = true
	tm.uv1_scale = Vector3.ONE * 0.12
	tm.roughness = 0.55
	top.material_override = tm
	root.add_child(top)
	# ---- 島底：往下收尖的山岩（不碰海面）
	var under := MeshInstance3D.new()
	under.name = "Under"
	under.mesh = _under_mesh()
	var um := _tex_mat("lichen_rock_diff_1k.jpg", Color(0.78, 0.92, 1.0), 0.14)
	um.vertex_color_use_as_albedo = true
	um.cull_mode = BaseMaterial3D.CULL_DISABLED
	under.material_override = um
	root.add_child(under)

	# ---- 三段地面：西邊的雪、中間的石板街、東邊的星盤（都是貼在斜面上的薄片）
	var tilt := atan(SLOPE)
	var spots: Array = ctx.spots
	# 先鋪三大塊底色，幾乎蓋滿整座島：西邊淡青的霧雪、中間暖色的石板、東邊深藍的夜
	_patch(root, _g(c.x - rx * 0.56, c.y, 0.015), rx * 0.42, rz * 0.82, Color(0.80, 0.90, 0.93), tilt)
	_patch(root, _g(c.x, c.y, 0.02), rx * 0.36, rz * 0.86, Color(0.90, 0.82, 0.68), tilt)
	_patch(root, _g(c.x + rx * 0.55, c.y, 0.025), rx * 0.42, rz * 0.84, Color(0.13, 0.15, 0.36), tilt)
	for blob in [[-1.6, -1.8, 6.4, 4.6], [3.2, 1.6, 4.6, 3.4], [-4.6, 2.2, 3.6, 2.8]]:
		_patch(root, _g(spots[0].x + float(blob[0]), spots[0].z + 2.4 + float(blob[1]), 0.04), float(blob[2]), float(blob[3]), Color(0.95, 0.97, 1.0), tilt)
	_patch(root, _g(spots[1].x, spots[1].z + 2.2, 0.04), 6.0, 4.8, Color(0.84, 0.78, 0.68), tilt)
	_patch(root, _g(spots[1].x, spots[1].z + 2.2, 0.06), 5.2, 4.0, Color(0.93, 0.88, 0.78), tilt)
	var star_c := _g(spots[2].x + 0.4, spots[2].z + 1.8, 0.05)
	_patch(root, star_c, 6.6, 5.6, Color(0.07, 0.08, 0.24), tilt)
	_patch(root, star_c + Vector3(0, 0.02, 0), 4.0, 3.4, Color(0.80, 0.82, 0.98), tilt)
	_floor_wheel(root, star_c + Vector3(0, 0.05, 0), 5.2, 1.0, tilt)

	# ---- 樹和擺設：西邊紅梅和松，中間銀杏，東邊星碑和宮燈
	var placed := 0
	var span := maxf(rx * 2.0, 1.0)
	for i in 600:
		if placed >= 30:
			break
		var a := _rng.randf() * TAU
		var d := Isle.radius(_o, a) * sqrt(_rng.randf()) - 1.8
		var x := c.x + cos(a) * d
		var z := c.y + sin(a) * d
		if d < 0.0 or not _free(x, z):
			continue
		var t := (x - (c.x - rx)) / span
		var south := z > _near_pad_z(x) + 2.0
		var sc := _rng.randf_range(0.42, 0.55) if south else _rng.randf_range(0.6, 0.85)
		var g := _g(x, z, -0.03)
		if t < 0.36:
			_piece(root, HM + ["plum_a.glb", "pine_a.glb", "plum_b.glb", "pine_b.glb"][placed % 4], g, _rng.randf() * TAU, sc * 0.95)
		elif t < 0.68:
			_piece(root, HM + ["ginkgo_a.glb", "ginkgo_b.glb", "palace_lantern.glb"][placed % 3], g, _rng.randf() * TAU, sc * 0.85)
		else:
			_piece(root, HM + ["star_stele.glb", "scholar_rock.glb", "palace_lantern.glb"][placed % 3], g, _rng.randf() * TAU + PI, sc * 0.9)
		placed += 1

	# ---- 雲海：島底下和四周一圈雲（島看起來浮在上面）
	for i in 26:
		var a := (i + _rng.randf_range(-0.3, 0.3)) * TAU / 26.0
		var rr := Isle.radius(_o, a) * _rng.randf_range(0.55, 1.12)
		var sc := _rng.randf_range(1.5, 2.6)
		var cl := _cloud(root, Vector3(c.x + cos(a) * rr, _rng.randf_range(0.25, 0.9), c.y + sin(a) * rr), a, sc)
		if cl and i % 3 == 0:
			_fx(cl, "bob", {"amp": 0.18, "speed": 0.5, "phase": float(i)})
	for i in 5:
		# 幾朵比較高的雲貼著島緣，半遮著岩壁
		var a := (i * 1.3 + 0.5)
		var p := Isle.rim_point(_o, a)
		_cloud(root, Vector3(p.x + cos(a) * 1.4, ground_y(p.x, p.y) - 1.4, p.y + sin(a) * 1.4), a, _rng.randf_range(1.0, 1.5))

	# ---- 三道瀑布：從島緣落進雲海
	for a in [0.55, 2.55, 4.05]:
		var p := Isle.rim_point(_o, a, 0.5)
		_waterfall(root, Vector3(p.x, ground_y(p.x, p.y) - 0.05, p.y), a)

	# ---- 雲階：朝主島的那一側（北邊），從雲海一階一階接到島上
	var np := Isle.rim_point(_o, -PI * 0.5)
	var top_n := ground_y(np.x, np.y)
	for k in 6:
		var t := float(k + 1) / 7.0
		var sp := Vector3(np.x + sin(k * 1.3) * 0.8, lerpf(top_n - 0.3, 0.7, t), np.y - 1.6 - k * 1.9)
		var cl := _cloud(root, sp, k * 0.9, 0.85)
		var slab := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(1.5, 0.16, 1.1)
		slab.mesh = bm
		var sm := StandardMaterial3D.new()
		sm.albedo_color = Color(0.93, 0.97, 0.94)
		sm.emission_enabled = true
		sm.emission = Color(1.0, 0.86, 0.46)
		sm.emission_energy_multiplier = 0.25
		slab.material_override = sm
		slab.position = sp + Vector3(0, 0.42, 0)
		slab.rotation.y = k * 0.25
		root.add_child(slab)
		if cl:
			_fx(cl, "bob", {"amp": 0.08, "speed": 0.8, "phase": float(k)})

	# ---- 四周浮著的小仙山
	for pk in [[-0.72, 1.28, 8.6, 0.55], [0.28, 1.34, 10.5, 0.75], [1.02, 1.22, 7.8, 0.5], [3.6, 1.30, 9.4, 0.6]]:
		var a := float(pk[0])
		var p2 := Vector2(c.x + cos(a) * Isle.radius(_o, a) * float(pk[1]), c.y + sin(a) * Isle.radius(_o, a) * float(pk[1]))
		var peak := _piece(root, HM + "float_peak.glb", Vector3(p2.x, float(pk[2]), p2.y), a * 2.0, float(pk[3]))
		if peak:
			_swap(peak, "lantern_glow_fall", _fall_mat)
			_cloud(peak, Vector3(0, -5.4, 0), 0.0, 2.4)
			_fx(peak, "bob", {"amp": 0.35, "speed": 0.35, "phase": a * 3.0})

	# ---- 仙鶴繞著島飛；鳳羽靈光在島上空盤旋
	for k in 3:
		var cr := _piece(root, HM + "crane.glb", Vector3(c.x, 9.0, c.y), 0.0, 0.55)
		if cr:
			_fx(cr, "orbit", {"center": Vector3(c.x, 0, c.y), "rx": rx * (0.85 + 0.18 * k), "rz": rz * (1.05 + 0.25 * k), "h": 8.5 + 1.2 * k,
				"speed": (0.25 - 0.04 * k) * (1.0 if k % 2 == 0 else -1.0), "phase": k * 2.1})
	var loop: Array = []
	for i in 10:
		var a := i * TAU / 10.0
		loop.append(Vector3(c.x + cos(a) * rx * 0.72, FLOAT_H + 5.2 + 1.6 * sin(a * 2.0), c.y + sin(a) * rz * 0.8))
	var head: Node3D = null
	var hps := load(HM + "phoenix_light.glb") as PackedScene
	if hps:
		head = hps.instantiate() as Node3D
		var hm := StandardMaterial3D.new()
		hm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		hm.albedo_color = Color(1.0, 0.62, 0.10)
		hm.cull_mode = BaseMaterial3D.CULL_DISABLED
		for m in head.find_children("*", "MeshInstance3D", true, false):
			(m as MeshInstance3D).material_override = hm
			(m as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var spirit := Node3D.new()
	spirit.name = "Spirit"
	spirit.set_script(Spirit)
	root.add_child(spirit)
	spirit.setup(loop, head, false)

	# ---- 東邊（天門）頭頂一圈平放的金環，慢慢轉
	var holder := Node3D.new()
	holder.position = star_c + Vector3(0, 6.4, -1.0)
	root.add_child(holder)
	var halo := _piece(holder, HM + "gold_ring.glb", Vector3.ZERO, 0.0, 1.9)
	if halo:
		halo.rotation.x = PI * 0.5
		for m in halo.find_children("*", "MeshInstance3D", true, false):
			(m as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_fx(holder, "spin", {"speed": 0.25})

func build_spot(k: int, root: Node3D, _c: Dictionary) -> void:
	match k:
		0:
			# 雲階：立軸畫門、亭子、紅梅和松（雪地在 build_island 鋪了）
			_piece(root, HM + "picture_gate.glb", Vector3(-0.4, 0, -0.9), 0.35, 0.95)
			_piece(root, HM + "pavilion.glb", Vector3(2.7, 0, -2.4), 0.6, 0.5)
			_piece(root, HM + "plum_a.glb", Vector3(-3.0, 0, -1.8), 0.4, 0.95)
			_piece(root, HM + "pine_a.glb", Vector3(-2.2, 0, -3.4), 1.4, 0.7)
			_piece(root, HM + "plum_b.glb", Vector3(3.6, 0, 0.6), 2.0, 0.7)
			_piece(root, HM + "scholar_rock.glb", Vector3(-2.6, 0, 1.2), 2.0, 0.6)
			_piece(root, HM + "palace_lantern.glb", Vector3(1.9, 0, 1.3), 0.0, 0.6)
			_light(root, Vector3(0.0, 1.8, 0.6), Color(1.0, 0.75, 0.4), 1.0, 4.5)
			root.set_meta("bubble_y", 5.0)
		1:
			# 山海迴廊：木樓、攤子、陸吾、銀杏、一串燈籠
			_piece(root, HM + "house.glb", Vector3(-1.8, 0, -2.2), 0.3, 0.55)
			_piece(root, HM + "stall.glb", Vector3(2.4, 0, -1.6), -0.4, 0.75)
			_piece(root, HM + "luwu.glb", Vector3(0.9, 0, 1.1), -0.5, 0.8)
			_piece(root, HM + "ginkgo_a.glb", Vector3(4.0, 0, -2.6), 1.0, 0.7)
			_piece(root, HM + "ginkgo_b.glb", Vector3(-3.8, 0, 0.6), 2.0, 0.5)
			_piece(root, HM + "leaf_pile.glb", Vector3(-1.2, 0, 1.8), 0.0, 0.55)
			for i in 5:
				var t := (i + 0.5) / 5.0
				_piece(root, HM + "mini_lantern.glb", Vector3(lerpf(-1.4, 2.6, t), 3.3 - 1.2 * t * (1.0 - t), lerpf(-1.4, -1.2, t)), i * 1.3, 0.9)
			_light(root, Vector3(0.6, 2.2, 0.0), Color(1.0, 0.72, 0.36), 1.4, 6.0)
			root.set_meta("bubble_y", 5.8)
		_:
			# 天門：圓門、唱盤、金環、星碑（地上的星盤和轉盤在 build_island 鋪了）
			_piece(root, HM + "ring_gate.glb", Vector3(0, 0, -2.2), 0.0, 0.55)
			_piece(root, HM + "turntable.glb", Vector3(0, 0, 0.4), 0.0, 0.9)
			var ring := _piece(root, HM + "gold_ring.glb", Vector3(0, 2.6, -3.4), 0.0, 1.05)
			if ring:
				for m in ring.find_children("*", "MeshInstance3D", true, false):
					(m as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_piece(root, HM + "star_stele.glb", Vector3(-3.2, 0, -0.8), 0.5 + PI, 0.7)
			_piece(root, HM + "star_stele.glb", Vector3(3.2, 0, -0.8), -0.5 + PI, 0.7)
			_piece(root, HM + "palace_lantern.glb", Vector3(-1.7, 0, 1.6), 0.0, 0.6)
			_piece(root, HM + "palace_lantern.glb", Vector3(1.7, 0, 1.6), 0.0, 0.6)
			_light(root, Vector3(0, 2.4, -1.4), Color(1.0, 0.85, 0.45), 2.2, 7.0)
			root.set_meta("bubble_y", 6.6)

# ================================================================== 蓋東西的小工具

## 島底：從島緣一圈一圈往中間、往下收，最後收成一個尖（頂點色越往下越暗）
func _under_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var c: Vector2 = _o.c
	var segs := 96
	var f := [1.0, 0.94, 0.76, 0.52, 0.26, 0.04]
	var dep := [0.25, 0.75, 1.5, 2.25, 2.85, 3.2]
	var grid: Array = []
	for i in segs + 1:
		var a := i * TAU / segs
		var p := Isle.rim_point(_o, a)
		var col: Array = []
		for k in f.size():
			var n := (sin(a * 7.0 + k * 1.7) * 0.05 + sin(a * 13.0 + k) * 0.035) if (k > 0 and k < f.size() - 1) else 0.0
			var q := c.lerp(p, float(f[k]) + n)
			col.append(Vector3(q.x, ground_y(q.x, q.y) - float(dep[k]) - (0.25 * sin(a * 5.0 + k) if k > 1 else 0.0), q.y))
		grid.append(col)
	for i in segs:
		for k in f.size() - 1:
			var sh0 := 1.0 - 0.13 * k
			var sh1 := 1.0 - 0.13 * (k + 1)
			var quad := [[grid[i][k], sh0], [grid[i + 1][k], sh0], [grid[i + 1][k + 1], sh1], [grid[i][k], sh0], [grid[i + 1][k + 1], sh1], [grid[i][k + 1], sh1]]
			for v in quad:
				st.set_color(Color(float(v[1]), float(v[1]), float(v[1])))
				st.add_vertex(v[0])
	st.generate_normals()
	return st.commit()

## 貼在斜面上的一片橢圓（雪地、石板街、星盤）
func _patch(root: Node3D, pos: Vector3, rx: float, rz: float, col: Color, tilt: float) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 1.0
	cm.bottom_radius = 1.0
	cm.height = 0.04
	cm.radial_segments = 40
	mi.mesh = cm
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.9
	mi.material_override = m
	mi.position = pos
	mi.scale = Vector3(rx, 1.0, rz)
	mi.rotation.z = tilt
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)

## 地上的山海轉盤：一圈金色的光環，十二個異獸紋章繞著轉
func _floor_wheel(root: Node3D, pos: Vector3, r: float, width: float, tilt: float) -> void:
	var node := Node3D.new()
	node.name = "Wheel"
	node.position = pos
	node.rotation.z = tilt
	root.add_child(node)
	var spin := Node3D.new()
	node.add_child(spin)
	_fx(spin, "spin", {"speed": 0.12})
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs := 72
	for i in segs:
		var a0 := i * TAU / segs
		var a1 := (i + 1) * TAU / segs
		var p := [Vector3(cos(a0) * (r - width * 0.5), 0, sin(a0) * (r - width * 0.5)), Vector3(cos(a0) * (r + width * 0.5), 0, sin(a0) * (r + width * 0.5)),
			Vector3(cos(a1) * (r - width * 0.5), 0, sin(a1) * (r - width * 0.5)), Vector3(cos(a1) * (r + width * 0.5), 0, sin(a1) * (r + width * 0.5))]
		var uv := [Vector2(float(i) / segs, 0), Vector2(float(i) / segs, 1), Vector2(float(i + 1) / segs, 0), Vector2(float(i + 1) / segs, 1)]
		for j in [0, 2, 1, 1, 2, 3]:
			st.set_uv(uv[j])
			st.add_vertex(p[j])
	var ring := MeshInstance3D.new()
	ring.mesh = st.commit()
	var wm := ShaderMaterial.new()
	wm.shader = load(HS + "astral_wheel.gdshader")
	wm.set_shader_parameter("strength", 1.3)
	ring.material_override = wm
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	spin.add_child(ring)
	for k in 12:
		var a := k * TAU / 12.0
		var em := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(0.95, 0.95)
		em.mesh = q
		var emm := StandardMaterial3D.new()
		emm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		emm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		emm.albedo_texture = load(HT + "emblems/emblem_%02d.png" % k)
		emm.cull_mode = BaseMaterial3D.CULL_DISABLED
		em.material_override = emm
		em.rotation.x = -PI * 0.5
		em.position = Vector3(cos(a) * r, 0.03, sin(a) * r)
		em.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		spin.add_child(em)

## 一道從島緣落下去的瀑布（半透明的水；底下一朵雲接著）
func _waterfall(root: Node3D, top: Vector3, a: float) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rows := 10
	var pts: Array = []
	for i in rows + 1:
		var t := float(i) / rows
		var w := 0.45 + 0.9 * pow(t, 1.5)
		pts.append([Vector3(-w, -5.6 * t, 0.5 * t * t), Vector3(w, -5.6 * t, 0.5 * t * t)])
	for i in rows:
		for v in [pts[i][0], pts[i][1], pts[i + 1][0], pts[i][1], pts[i + 1][1], pts[i + 1][0]]:
			st.add_vertex(v)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = _fall_mat
	mi.position = top
	mi.rotation.y = -a + PI * 0.5
	mi.scale = Vector3(1.0, top.y / 5.6, 1.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	_cloud(root, Vector3(top.x + cos(a) * 0.8, 0.5, top.z + sin(a) * 0.8), a, 1.3)

func _cloud(parent: Node3D, pos: Vector3, yaw: float, scale: float) -> Node3D:
	var cl := _piece(parent, CLOUD + ["a", "b", "c"][int(absf(pos.x * 3.0 + pos.z)) % 3] + ".glb", pos, yaw, scale)
	if cl:
		cl.scale = Vector3(scale, scale * 0.55, scale)
		for m in cl.find_children("*", "MeshInstance3D", true, false):
			(m as MeshInstance3D).material_override = _cloud_mat
			(m as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return cl

## 掛上小動畫（art/map_fx.gd）：mode 和它要的參數
func _fx(n: Node3D, mode: String, args: Dictionary) -> void:
	n.set_script(Fx)
	n.set("mode", mode)
	for key in args:
		n.set(key, args[key])
	n.set("_home", n.position)
	n.set("_wl", n.find_child("WingL", true, false))
	n.set("_wr", n.find_child("WingR", true, false))
	n.set_process(true)

## 把模型裡某個名字的材質換掉
func _swap(n: Node3D, mat_name: String, to: Material) -> void:
	for m in n.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		for k in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(k)
			if src and String(src.resource_name) == mat_name:
				mi.set_surface_override_material(k, to)

func _near_pad_z(x: float) -> float:
	var best := 0.0
	var bd := INF
	for p in _ctx.pads:
		if absf(x - p.x) < bd:
			bd = absf(x - p.x)
			best = p.z
	return best

func _free(x: float, z: float) -> bool:
	var p := Vector2(x, z)
	var pads: Array = _ctx.pads
	for k in pads.size():
		var a := Vector2(pads[k].x, pads[k].z)
		if p.distance_to(a) < 3.2:
			return false
		if absf(x - a.x) < 4.6 and z > a.y:
			return false
		if k + 1 < pads.size():
			var b := Vector2(pads[k + 1].x, pads[k + 1].z)
			if Geometry2D.get_closest_point_to_segment(p, a, b).distance_to(p) < 2.6:
				return false
		var sp: Vector3 = _ctx.spots[k]
		if p.distance_to(Vector2(sp.x, sp.z)) < 5.6:
			return false
	return true

func _tex_mat(tex: String, tint: Color, scale: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(TEX + tex)
	m.albedo_color = tint
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE * scale
	m.roughness = 1.0
	return m

func _piece(parent: Node3D, path: String, pos: Vector3, yaw := 0.0, scale := 1.0) -> Node3D:
	if not ResourceLoader.exists(path):
		push_warning("丹穴山地圖：找不到模型 " + path)
		return null
	var ps := load(path) as PackedScene
	if ps == null:
		return null
	var n := ps.instantiate() as Node3D
	n.position = pos
	n.rotation.y = yaw
	n.scale = Vector3.ONE * scale
	parent.add_child(n)
	var shut := n.find_child("EyesShut", true, false) as Node3D
	if shut:
		shut.visible = false
	return n

func _light(parent: Node3D, p: Vector3, col: Color, energy: float, rng: float) -> void:
	var l := OmniLight3D.new()
	l.light_color = col
	l.light_energy = energy
	l.omni_range = rng
	l.light_specular = 0.0
	l.position = p
	parent.add_child(l)
