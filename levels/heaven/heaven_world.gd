extends "res://levels/ice/rescue_world.gd"
## 【仙境丹穴山】場地：規則沿用冰雪島的場地（rescue_world.gd／ice_world.gd），外觀整個換掉。
## 跟冰雪島最大的不同：**不是一座島**。地面往四周一直鋪到遠山和霧裡，看不到海；會滑的地方也不是一個圓，
## 每一關自己拼形狀（十字形的平台、街口、圓形的壇）。
##
## 規則對照（名字每一關可以自己取，見 hole_word／rough_word／pile_word）：
##   冰面 → 白玉地（人踩香蕉皮會滑）：courts（長方形）＋ lakes（橢圓）拼起來
##   雪地 → 其他的地面（只跌倒）　冰洞 → 洞（水潭、錦鯉池、星洞；滑進去出局）
##   雪堆 → 堆（落葉堆）　雪人 → 香爐（擋一次、爐蓋扣在頭上）　松樹 → 石柱　籠子 → 終點（南天門、山門、唱盤）
## 另外多幾樣東西給戰局（heaven_battle.gd）用：
##   door_specs  畫門：[{"pos": Vector3, "face": Vector3（正面朝哪，也是出來時滑的方向）}, ...]，照順序兩扇一對
##   luwu_spec   陸吾：{"pos": Vector3, "face": Vector3}（視線在牠面前）
##   stairs      雲階：{"x0", "x1", "z0", "z1", "h"}——z0 那一頭是腳下（高度 0），z1 那一頭最高（h）。巨石只能放在這裡
##   goal        終點的樣子："gate" 南天門／"steps" 山門／"disc" 圓門底下的唱盤（唱盤要放飼料，見規格 3.8）
## 只影響外觀的設定：
##   walks       步道（不會滑的鋪面）：[[Vector3 起點, Vector3 終點, 寬], ...]，最多 8 條
##   zones       手排的擺設（種類見 _zone_item）；rim_kinds／rim_count／rim_far 是自動撒在四周的
## 小關的 world.gd：extends 這個檔案，在 _ice_configure() 設定（寫法跟冰雪島的小關一樣）。
##
## 外觀：模型是本組用 Blender 腳本做的（assets/blender/src/build_heaven_props.py），著色器在 shaders/。
## 三關三種畫面（規格 6.1）：mood = "ink" 青綠水墨的霧景、"gold" 金黃樓閣的街市、"astral" 星空金環的長廊。

const HM := "res://levels/heaven/assets/blender/"
const HS := "res://levels/heaven/shaders/"
const HT := "res://levels/heaven/assets/textures/"

## 會滑的白玉地（長方形，四個角是圓的）：[{"c": Vector2 中心, "hx": 半寬, "hz": 半深}, ...]，最多 6 塊；可以跟 lakes（橢圓）混用
var courts: Array = []
const COURT_R := 1.6           # 長方形白玉地的圓角半徑
var walks: Array = []
## 這一關怎麼叫這幾樣東西（預告線的終點、提示都用這幾個詞）
var hole_word := "水潭"
var rough_word := "草地"
var pile_word := "落葉堆"
var door_specs: Array = []
var luwu_spec: Dictionary = {}
var stairs: Dictionary = {}
var goal := "gate"
var goal_text := "南天門"
## 自動擺的外圈裝飾用哪幾種：[["pine", 比重], ["rock", 比重], ...]（種類見 _zone_item）
var rim_kinds: Array = []
var rim_count := 22
var rim_far := 30.0            # 自動擺的裝飾最遠擺到離中心多遠
const GROUND_HALF := 46.0      # 細的地面網格鋪多大（公尺，半邊）；外面接一大片平的

## 給戰局用（_build_extra 之後才有）
var doors: Array = []          # {pos, face, pair, node, mat}
var luwu: Dictionary = {}      # {pos, face, node, ...}
var disc = null                # 唱盤的位置（Vector3）；沒有唱盤是 null

var _petals: CPUParticles3D
var _gate_node: Node3D
var _goal_glow: Array = []     # 終點會亮起來的材質 {mat, base}
var _luwu_t := 0.0
var _luwu_state := "awake"     # awake / inhale / sleep
var _zzz: Label3D
var _door_flash: Array = []    # 每扇門閃光還剩幾秒
var _ring_nodes: Array = []    # 第 3 關那幾圈金環（會慢慢轉）
var _hill_mats: Array = []
var _fin_t := 0.0
var _fin_on := false
var _phoenix: Node3D

## 每一關的顏色（鍵跟冰雪島的 MOODS 一樣，所以冰雪島的程式可以直接用；多的鍵是仙境自己的）。
##   snow_lit／snow_shade = 四周地面的亮面／暗面；ground_far = 地面遠處融進去的顏色；walk = 步道；paving = 地面上石板縫的深淺（0＝草地）
##   jade = 白玉地的淺／中／深；trim = 白玉地的鑲邊；hole = 洞裡面的深色／亮色；hills = 三層遠山；hill_h = 山多高
const HEAVEN_MOODS := {
	# 青綠水墨的霧景：冷色、低對比，松林和遠山一層一層淡進霧裡；畫門的朱紅是畫面裡最暖的顏色
	"ink": {"sun": Color(0.86, 0.96, 0.94), "energy": 1.15, "rot": Vector3(-0.80, 0.55, 0), "amb": Color(0.56, 0.78, 0.78), "amb_e": 1.0,
		"top": Color(0.34, 0.60, 0.66), "hor": Color(0.74, 0.90, 0.88), "band": Color(0.84, 0.95, 0.92), "glow_band": 0.75, "band_thin": 6.0,
		"cloud": Color(0.92, 0.98, 0.96), "cloud_sh": Color(0.56, 0.76, 0.78), "sun_glow": Color(0.9, 1.0, 0.96), "stars": 0.0, "aurora": 0.0,
		"snow_lit": Color(0.50, 0.72, 0.62), "snow_shade": Color(0.26, 0.50, 0.50), "ground_far": Color(0.62, 0.84, 0.82), "exposure": 0.98,
		"walk": Color(0.78, 0.86, 0.80), "paving": 0.0, "sparkle": 0.0,
		"ice_glow": 0.14, "ice_lit": 0.90, "sky_tint": Color(0.80, 0.95, 0.93), "water": 1.0, "lamp": 1.9,
		"jade": [Color(0.90, 0.97, 0.93), Color(0.66, 0.87, 0.82), Color(0.34, 0.62, 0.60)], "trim": Color(0.93, 0.80, 0.40),
		"hole": [Color(0.06, 0.26, 0.32), Color(0.40, 0.72, 0.72)],
		"sea_deep": Color(0.24, 0.48, 0.52), "sea_near": Color(0.60, 0.82, 0.80), "sea_stroke": Color(0.94, 1.0, 0.98), "sea_stroke2": Color(0.56, 0.78, 0.78),
		"sea_far": Color(0.70, 0.88, 0.86), "fog": Color(0.70, 0.88, 0.86), "fog_density": 0.011,
		"hills": [Color(0.14, 0.34, 0.38), Color(0.30, 0.54, 0.56), Color(0.50, 0.72, 0.72)], "hill_mist": Color(0.74, 0.90, 0.88), "hill_h": 0.46,
		"petal": Color(1.0, 0.66, 0.78), "petal_n": 70,
		"cliff": [Color(0.70, 0.86, 0.82), Color(0.34, 0.56, 0.58), Color(0.14, 0.32, 0.38)], "cliff_glow": 0.10},
	# 金黃樓閣的街市：暖光、長影子、滿天金葉；地面是暖色的石板路；陸吾是青色的，在一片金黃裡很顯眼
	"gold": {"sun": Color(1.0, 0.88, 0.60), "energy": 1.75, "rot": Vector3(-0.52, -0.85, 0), "amb": Color(0.90, 0.76, 0.58), "amb_e": 0.85,
		"top": Color(0.54, 0.70, 0.76), "hor": Color(0.99, 0.90, 0.66), "band": Color(1.0, 0.94, 0.74), "glow_band": 0.9, "band_thin": 7.0,
		"cloud": Color(1.0, 0.97, 0.84), "cloud_sh": Color(0.94, 0.76, 0.54), "sun_glow": Color(1.0, 0.86, 0.48), "stars": 0.0, "aurora": 0.0,
		"snow_lit": Color(0.86, 0.72, 0.52), "snow_shade": Color(0.62, 0.46, 0.34), "ground_far": Color(0.98, 0.86, 0.62), "exposure": 0.96,
		"walk": Color(0.74, 0.60, 0.46), "paving": 0.7, "sparkle": 0.0,
		"ice_glow": 0.12, "ice_lit": 0.94, "sky_tint": Color(1.0, 0.95, 0.80), "water": 1.0, "lamp": 1.3,
		"jade": [Color(0.99, 0.97, 0.90), Color(0.92, 0.88, 0.76), Color(0.72, 0.66, 0.52)], "trim": Color(0.80, 0.20, 0.14),
		"hole": [Color(0.10, 0.34, 0.36), Color(0.52, 0.80, 0.72)],
		"sea_deep": Color(0.86, 0.62, 0.38), "sea_near": Color(0.80, 0.62, 0.42), "sea_stroke": Color(1.0, 1.0, 0.92), "sea_stroke2": Color(0.96, 0.78, 0.52),
		"sea_far": Color(0.99, 0.88, 0.66), "fog": Color(0.99, 0.87, 0.64), "fog_density": 0.006,
		"hills": [Color(0.50, 0.38, 0.30), Color(0.74, 0.56, 0.38), Color(0.92, 0.78, 0.54)], "hill_mist": Color(1.0, 0.90, 0.68), "hill_h": 0.40,
		"petal": Color(1.0, 0.78, 0.20), "petal_n": 130,
		"cliff": [Color(0.94, 0.86, 0.70), Color(0.72, 0.52, 0.36), Color(0.42, 0.28, 0.24)], "cliff_glow": 0.12},
	# 星空金環的長廊：深藍的夜、滿天星，地面是暗色會反光的石頭；光都來自金色——步道、圓環、唱盤、宮燈
	"astral": {"sun": Color(0.78, 0.84, 1.0), "energy": 0.9, "rot": Vector3(-0.85, 0.4, 0), "amb": Color(0.48, 0.52, 0.80), "amb_e": 1.1,
		"top": Color(0.02, 0.03, 0.12), "hor": Color(0.10, 0.13, 0.32), "band": Color(1.0, 0.82, 0.42), "glow_band": 0.95, "band_thin": 30.0,
		"cloud": Color(0.36, 0.40, 0.62), "cloud_sh": Color(0.08, 0.10, 0.26), "sun_glow": Color(0.7, 0.78, 1.0), "stars": 1.0, "aurora": 0.0,
		"snow_lit": Color(0.16, 0.19, 0.40), "snow_shade": Color(0.07, 0.08, 0.22), "ground_far": Color(0.10, 0.11, 0.28), "exposure": 1.05,
		"walk": Color(1.0, 0.82, 0.40), "paving": 0.45, "sparkle": 1.0,
		"ice_glow": 0.34, "ice_lit": 0.72, "sky_tint": Color(0.60, 0.68, 1.0), "water": 1.2, "lamp": 2.4, "center_lift": 0.10,
		"jade": [Color(0.82, 0.86, 1.0), Color(0.44, 0.50, 0.84), Color(0.16, 0.20, 0.48)], "trim": Color(1.0, 0.84, 0.36),
		"hole": [Color(0.01, 0.01, 0.06), Color(0.30, 0.34, 0.80)],
		"sea_deep": Color(0.04, 0.05, 0.18), "sea_near": Color(0.20, 0.22, 0.46), "sea_stroke": Color(1.0, 0.88, 0.56), "sea_stroke2": Color(0.20, 0.22, 0.46),
		"sea_far": Color(0.10, 0.12, 0.30), "fog": Color(0.10, 0.11, 0.28), "fog_density": 0.007,
		"hills": [Color(0.03, 0.04, 0.12), Color(0.06, 0.08, 0.20), Color(0.10, 0.13, 0.30)], "hill_mist": Color(0.16, 0.16, 0.36), "hill_h": 0.30,
		"petal": Color(1.0, 0.88, 0.50), "petal_n": 90,
		"cliff": [Color(0.62, 0.66, 0.90), Color(0.22, 0.26, 0.52), Color(0.06, 0.08, 0.22)], "cliff_glow": 0.30},
}

func _mood() -> Dictionary:
	return HEAVEN_MOODS.get(mood, HEAVEN_MOODS.ink)

# ================================================================== 地形：白玉地的形狀、雲階

func _configure() -> void:
	mood = "ink"
	super()
	hill_amount = 0.10           # 仙境的地面幾乎是平的（遠處才有山，是背景）

## 不是島：「地圖的輪廓」只拿來決定裝飾可以擺多遠（一個大圓），不拿來蓋地形
func _fit_isle() -> void:
	isle = {"c": Vector2(0.0, -4.0), "rx": 64.0, "rz": 64.0, "seed": float(isle.get("seed", 1.0)), "pow": 2.0, "wob": 0.0,
		"depth": 5.0, "slope": 0.8, "lobe": 2.4}
	if finale_cam_pos == Vector3.ZERO:
		finale_cam_pos = Vector3(3.0, 15.0, 34.0)
		finale_cam_look = Vector3(0.0, 15.0 - 60.0 * tan(deg_to_rad(7.5)), -26.0)

## 離第 i 塊長方形白玉地的邊多遠（負的＝在裡面）
func _court_d(ct: Dictionary, x: float, z: float) -> float:
	var c: Vector2 = ct.c
	var q := Vector2(absf(x - c.x) - (float(ct.hx) - COURT_R), absf(z - c.y) - (float(ct.hz) - COURT_R))
	return Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0) - COURT_R

func on_ice(x: float, z: float) -> bool:
	if super(x, z):
		return true
	for ct in courts:
		if _court_d(ct, x, z) < 0.0:
			return true
	return false

## 1 = 在白玉地上，0 = 在外面（邊緣平滑過渡）：地形用它把白玉地整平，裝飾用它避開
func lake_weight(x: float, z: float) -> float:
	var best := super(x, z)
	for ct in courts:
		best = maxf(best, 1.0 - sstep(-0.6, 0.9, _court_d(ct, x, z)))
	return best

func on_stairs(x: float, z: float) -> bool:
	if stairs.is_empty():
		return false
	var z_lo := minf(float(stairs.z0), float(stairs.z1))
	var z_hi := maxf(float(stairs.z0), float(stairs.z1))
	return x >= float(stairs.x0) and x <= float(stairs.x1) and z >= z_lo and z <= z_hi

## 雲階上 0（腳下）～1（最高）
func _stair_k(z: float) -> float:
	return clampf((z - float(stairs.z0)) / (float(stairs.z1) - float(stairs.z0)), 0.0, 1.0)

func _stair_w(x: float, z: float) -> float:
	if stairs.is_empty():
		return 0.0
	var z_lo := minf(float(stairs.z0), float(stairs.z1)) - 0.6
	var z_hi := maxf(float(stairs.z0), float(stairs.z1)) + 6.0
	if z < z_lo or z > z_hi:
		return 0.0
	return sstep(float(stairs.x0) - 0.9, float(stairs.x0), x) * (1.0 - sstep(float(stairs.x1), float(stairs.x1) + 0.9, x))

func _extra_height(x: float, z: float) -> float:
	var h := super(x, z)
	var w := _stair_w(x, z)
	if w > 0.0:
		# 斜坡本身是平整的（把地面的起伏扣掉），巨石滾下來的路線才穩
		h = lerpf(h, -_bumps(x, z), w) + float(stairs.h) * _stair_k(z) * w
	return h

## 地面看起來的高度：跟 height_at 一樣，但洞底下不挖坑（地面一路平到洞口）
func _ground_y(x: float, z: float) -> float:
	var h := height_at(x, z)
	for p in ponds:
		var r: float = p.r
		h += 1.5 * (1.0 - sstep(r - 1.2, r + 0.3, Vector2(x, z).distance_to(p.center)))
	return h

## 巨石滾動的阻力：雲階上很小（一放就滾）、白玉台和雲毯上很大（滾下來沒撞到人的話，離開雲階兩三公尺就停）
func roll_resist(x: float, z: float) -> float:
	return 0.8 if on_stairs(x, z) else 6.0

# ================================================================== 材質

func _make_materials() -> void:
	super()
	var md := _mood()
	# 洞裡面：水潭／錦鯉池是水，星洞是星空
	_water_mat = ShaderMaterial.new()
	_water_mat.shader = load(HS + "hole_fill.gdshader")
	_water_mat.set_shader_parameter("noise_tex", load(TX + "snow_soft.png"))
	_water_mat.set_shader_parameter("deep", md.hole[0])
	_water_mat.set_shader_parameter("light_c", md.hole[1])
	_water_mat.set_shader_parameter("stars", 1.0 if mood == "astral" else 0.0)
	_cloud_mat.set_shader_parameter("light_c", md.cloud)
	_cloud_mat.set_shader_parameter("shade_c", md.cloud_sh)

## 地面：白玉地＋四周的地面＋步道＋雲階，一個著色器畫完（取代冰雪島的雪＋冰）
func _snow_material() -> ShaderMaterial:
	var md := _mood()
	var m := ShaderMaterial.new()
	m.shader = load(HS + "heaven_ground.gdshader")
	m.set_shader_parameter("vein_tex", load(TX + "ice_cracks.png"))
	m.set_shader_parameter("grain_tex", load(TX + "snow_soft.png"))
	m.set_shader_parameter("ground_lit", md.snow_lit)
	m.set_shader_parameter("ground_shade", md.snow_shade)
	m.set_shader_parameter("ground_far", md.ground_far)
	m.set_shader_parameter("walk_c", md.walk)
	m.set_shader_parameter("paving", md.paving)
	m.set_shader_parameter("sparkle", md.sparkle)
	m.set_shader_parameter("jade_pale", md.jade[0])
	m.set_shader_parameter("jade_mid", md.jade[1])
	m.set_shader_parameter("jade_deep", md.jade[2])
	m.set_shader_parameter("trim_c", md.trim)
	m.set_shader_parameter("jade_glow", md.ice_glow)
	m.set_shader_parameter("jade_lit", md.ice_lit)
	m.set_shader_parameter("sky_tint", md.sky_tint)
	m.set_shader_parameter("court_r", COURT_R)
	var ca := PackedVector4Array()
	for ct in courts:
		if ca.size() < 6:
			ca.append(Vector4((ct.c as Vector2).x, (ct.c as Vector2).y, float(ct.hx), float(ct.hz)))
	m.set_shader_parameter("court_count", ca.size())
	ca.resize(6)
	m.set_shader_parameter("courts", ca)
	var wa := PackedVector4Array()
	var ww := PackedFloat32Array()
	for w in walks:
		if wa.size() < 8:
			wa.append(Vector4((w[0] as Vector3).x, (w[0] as Vector3).z, (w[1] as Vector3).x, (w[1] as Vector3).z))
			ww.append(float(w[2]) * 0.5)
	m.set_shader_parameter("walk_count", wa.size())
	wa.resize(8)
	ww.resize(8)
	m.set_shader_parameter("walks", wa)
	m.set_shader_parameter("walk_half", ww)
	if not stairs.is_empty():
		m.set_shader_parameter("stairs", Vector4(float(stairs.x0), float(stairs.x1), float(stairs.z0), float(stairs.z1)))
		m.set_shader_parameter("stair_steps", maxf(roundf(absf(float(stairs.z1) - float(stairs.z0)) / 0.55), 2.0))
	if md.has("center_lift"):
		m.set_shader_parameter("center_lift", md.center_lift)
	return m

# ================================================================== 蓋場地

func _build_extra() -> void:
	keep_clear.append(cage)
	for p in bird_path:
		keep_clear.append(p)
	_hide_base()
	_make_materials()
	var root := Node3D.new()
	root.name = "Heaven"
	add_child(root)
	_build_ground(root)
	for i in ponds.size():
		_build_hole(root, i)
	_refresh_holes()
	for p in snowmen:
		_snowman(root, p)
	for i in pines.size():
		_pine(root, pines[i], low_pines.has(i))
	for p in snow_piles:
		_pile(root, p)
	_build_backdrop(root)
	for i in door_specs.size():
		_build_door(root, i)
	if not luwu_spec.is_empty():
		_build_luwu(root)
	if not stairs.is_empty():
		_build_stair_rails(root)
	if decor:
		_build_decor(root)
	_weather()
	_build_cage()

## 地面：中間一塊細的網格（跟著地形起伏、雲階是斜的），外面接一大片平的，一路鋪到霧裡
func _build_ground(root: Node3D) -> void:
	var c: Vector2 = isle.c
	var step := 0.5
	var n := int(GROUND_HALF * 2.0 / step)
	var verts := PackedVector3Array()
	var nrm := PackedVector3Array()
	var idx := PackedInt32Array()
	verts.resize((n + 1) * (n + 1))
	nrm.resize((n + 1) * (n + 1))
	for j in n + 1:
		var z := c.y - GROUND_HALF + j * step
		for i in n + 1:
			var x := c.x - GROUND_HALF + i * step
			# 邊上往下收一點，跟外面那片平的接起來不露縫
			var edge := maxf(absf(x - c.x), absf(z - c.y)) / GROUND_HALF
			var y := _ground_y(x, z) * (1.0 - sstep(0.90, 1.0, edge)) - 0.35 * sstep(0.94, 1.0, edge)
			verts[j * (n + 1) + i] = Vector3(x, y, z)
	for j in n + 1:
		for i in n + 1:
			var l := verts[j * (n + 1) + maxi(i - 1, 0)]
			var r := verts[j * (n + 1) + mini(i + 1, n)]
			var d := verts[maxi(j - 1, 0) * (n + 1) + i]
			var u := verts[mini(j + 1, n) * (n + 1) + i]
			nrm[j * (n + 1) + i] = Vector3(l.y - r.y, (r.x - l.x + u.z - d.z) * 0.5, d.y - u.y).normalized()
	for j in n:
		for i in n:
			var a := j * (n + 1) + i
			idx.append_array([a, a + 1, a + n + 1, a + 1, a + n + 2, a + n + 1])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = nrm
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var top := MeshInstance3D.new()
	top.name = "Ground"
	top.mesh = mesh
	top.material_override = _top_mat
	root.add_child(top)
	var far := MeshInstance3D.new()
	far.name = "FarGround"
	var pm := PlaneMesh.new()
	pm.size = Vector2(900, 900)
	far.mesh = pm
	far.material_override = _top_mat
	far.position = Vector3(c.x, -0.3, c.y)
	far.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(far)

## 洞：地面挖一個圓（著色器），蓋上一圈洞口（水潭是石頭砌的、星洞是金邊）；洞裡是水或星空
func _build_hole(root: Node3D, i: int) -> void:
	var c: Vector2 = ponds[i].center
	var r: float = ponds[i].r
	_hole_rim(root, Vector3(c.x, water_surface_y(c.x, c.y), c.y), r, i)

func _hole_rim(parent: Node3D, pos: Vector3, r: float, variant: int) -> Node3D:
	var rim := _prop(parent, HM + ("hole_rim_gold.glb" if mood == "astral" else "hole_rim_stone.glb"), pos, variant * 1.9, 1.0)
	if rim:
		rim.scale = Vector3(r, 1.0, r)
		_restyle(rim, false)
	return rim

func _floating_chunks(_parent: Node3D, _center: Vector3, _r: float, _count: int, _rng: RandomNumberGenerator) -> void:
	pass

## 堆（取代雪堆）：滑出去停在旁邊的人會倒栽進去
func _pile(root: Node3D, p: Vector3) -> void:
	var g := Vector3(p.x, height_at(p.x, p.z) - 0.05, p.z)
	var n := _prop(root, HM + "leaf_pile.glb", g, p.x, 1.0)
	if n:
		n.scale = Vector3.ONE * 1.25
	_blob_shadow(root, g, 1.7, 0.4)

## 香爐（取代雪人）：爐蓋是獨立的節點 Head，被撞到會掉下來扣在工人頭上
func _snowman(parent: Node3D, p: Vector3) -> void:
	var y := height_at(p.x, p.z)
	var node := Node3D.new()
	node.position = Vector3(p.x, y, p.z)
	node.rotation.y = p.x * 0.7
	parent.add_child(node)
	var hd: Node3D = null
	var model := _prop(node, HM + "censer.glb", Vector3.ZERO, 0.0, 1.0)
	if model:
		hd = model.find_child("Head", true, false) as Node3D
	if hd:
		hd.reparent(node)
	else:
		hd = Node3D.new()
		hd.position = Vector3(0, 1.5, 0)
		node.add_child(hd)
	_blob_shadow(parent, Vector3(p.x, y, p.z), 1.0)
	snowman_nodes.append({"pos": Vector3(p.x, y, p.z), "node": node, "head": hd, "home": hd.transform})
	obstacles.append([Vector2(p.x, p.z), 0.6])

## 石柱（取代松樹）：會擋路。low＝矮的那種（不擋住站在後面的人）
func _pine(parent: Node3D, p: Vector3, low := false) -> void:
	var g := Vector3(p.x, height_at(p.x, p.z), p.z)
	var n := _prop(parent, HM + "pillar.glb", g, p.x * 1.3, 1.0)
	if n and low:
		n.scale = Vector3(1.0, 0.55, 1.0)
	_blob_shadow(parent, g, 0.9)
	obstacles.append([Vector2(p.x, p.z), 0.7])

# ---------------------------------------------------------------- 畫門

func _build_door(root: Node3D, i: int) -> void:
	var s: Dictionary = door_specs[i]
	var face: Vector3 = (s.face as Vector3).normalized()
	var g := Vector3(s.pos.x, height_at(s.pos.x, s.pos.z), s.pos.z)
	var node := _prop(root, HM + "picture_gate.glb", g, atan2(face.x, face.z), 1.0)
	var pm: ShaderMaterial = null
	if node:
		pm = ShaderMaterial.new()
		pm.shader = load(HS + "painting.gdshader")
		pm.set_shader_parameter("noise_tex", load(TX + "snow_soft.png"))
		pm.set_shader_parameter("seed", float(i / 2) * 3.7 + 1.0)
		for m in node.find_children("*", "MeshInstance3D", true, false):
			var mi := m as MeshInstance3D
			for k in mi.mesh.get_surface_count():
				var mat := mi.mesh.surface_get_material(k)
				if mat and String(mat.resource_name) == "painting":
					mi.set_surface_override_material(k, pm)
		_blob_shadow(root, g, 1.6, 0.45)
		_warm_light(root, g + face * 1.0 + Vector3(0, 1.8, 0), 0.7, 3.6)
	# 兩根門柱會擋路
	var side := Vector3(-face.z, 0, face.x)
	for sg in [-1.0, 1.0]:
		var q: Vector3 = g + side * 1.42 * float(sg)
		obstacles.append([Vector2(q.x, q.z), 0.22])
	doors.append({"pos": g, "face": face, "pair": i + 1 if i % 2 == 0 else i - 1, "node": node, "mat": pm})
	_door_flash.append(0.0)
	keep_clear.append(g)

## 有人穿過這扇門：畫亮一下
func door_flash(i: int) -> void:
	if i >= 0 and i < _door_flash.size():
		_door_flash[i] = 0.6

# ---------------------------------------------------------------- 陸吾

func _build_luwu(root: Node3D) -> void:
	var face: Vector3 = (luwu_spec.face as Vector3).normalized()
	var g := Vector3(luwu_spec.pos.x, height_at(luwu_spec.pos.x, luwu_spec.pos.z), luwu_spec.pos.z)
	var node := _prop(root, HM + "luwu.glb", g, atan2(face.x, face.z), 1.0)
	luwu = {"pos": g, "face": face, "node": node}
	if node:
		luwu["head"] = node.find_child("Head", true, false)
		luwu["open"] = node.find_child("EyesOpen", true, false)
		luwu["shut"] = node.find_child("EyesShut", true, false)
		luwu["tails"] = node.find_child("Tails", true, false)
		if luwu.shut:
			(luwu.shut as Node3D).visible = false
	_blob_shadow(root, g, 2.2, 0.55)
	obstacles.append([Vector2(g.x, g.z), 0.95])
	keep_clear.append(g)
	_zzz = Label3D.new()
	_zzz.text = "Zzz"
	_zzz.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_zzz.no_depth_test = true
	_zzz.fixed_size = true
	_zzz.pixel_size = 0.0006
	_zzz.font_size = 34
	_zzz.modulate = Color(1, 1, 1)
	_zzz.outline_modulate = Color("3b2a20")
	_zzz.outline_size = 10
	_zzz.visible = false
	add_child(_zzz)

func luwu_wake() -> void:
	_luwu_state = "awake"
	_luwu_t = 0.0
	_luwu_pose()

func luwu_inhale() -> void:
	_luwu_state = "inhale"
	_luwu_t = 0.0

func luwu_sleep() -> void:
	_luwu_state = "sleep"
	_luwu_t = 0.0
	_luwu_pose()

func _luwu_pose() -> void:
	if luwu.is_empty():
		return
	var asleep := _luwu_state == "sleep"
	if luwu.get("open"):
		(luwu.open as Node3D).visible = not asleep
	if luwu.get("shut"):
		(luwu.shut as Node3D).visible = asleep
	if _zzz:
		_zzz.visible = asleep

# ---------------------------------------------------------------- 雲階兩邊的欄杆

func _build_stair_rails(root: Node3D) -> void:
	var z0: float = stairs.z0
	var z1: float = stairs.z1
	var n := maxi(int(absf(z1 - z0) / 1.6), 2)
	for sx in [float(stairs.x0) - 0.5, float(stairs.x1) + 0.5]:
		for k in n + 1:
			var z := lerpf(z0, z1, float(k) / n)
			_prop(root, HM + "rail_post.glb", Vector3(sx, height_at(sx, z), z), 0.0, 1.0)

# ================================================================== 終點（取代企鵝籠）

func _build_cage() -> void:
	_cage_root = Node3D.new()
	_cage_root.name = "Goal"
	_cage_root.position = Vector3(cage.x, height_at(cage.x, cage.z), cage.z)
	add_child(_cage_root)
	match goal:
		"disc":
			disc = _cage_root.position
			_prop(_cage_root, HM + "turntable.glb", Vector3.ZERO, 0.0, 1.0)
			_gate_node = _prop(_cage_root, HM + "ring_gate.glb", Vector3(0, 0.0, -3.4), 0.0, 1.0)
			# 一圈一圈往裡收的金環（越後面越大、越淡）
			for k in 3:
				var rn := _prop(_cage_root, HM + "gold_ring.glb", Vector3(0, 3.6, -6.0 - k * 5.0), 0.0, 1.0)
				if rn:
					rn.scale = Vector3.ONE * (1.6 + k * 0.9)
					_restyle(rn, false)
					_ring_nodes.append(rn)
		"steps":
			_gate_node = _prop(_cage_root, HM + "sky_gate.glb", Vector3(0, 0.0, -0.4), 0.0, 0.8)
		_:
			_gate_node = _prop(_cage_root, HM + "sky_gate.glb", Vector3(0, 0.0, -0.4), 0.0, 1.0)
	for m in _cage_root.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		for k in mi.mesh.get_surface_count():
			var sm := mi.get_surface_override_material(k) as ShaderMaterial
			var src := mi.mesh.surface_get_material(k)
			if sm and src and String(src.resource_name).begins_with("lantern_glow"):
				_goal_glow.append({"mat": sm, "base": sm.get_shader_parameter("emission_c")})
	_blob_shadow(self, _cage_root.position, 2.6, 0.5)
	if goal != "disc":
		obstacles.append([Vector2(cage.x, cage.z), 1.2])
	_warm_light(self, _cage_root.position + Vector3(0, 2.4, 1.2), 1.1, 6.0)
	_cage_label = Label3D.new()
	_cage_label.text = goal_text
	_cage_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_cage_label.no_depth_test = true
	_cage_label.font_size = LABEL_SIZE
	_cage_label.pixel_size = 0.00052
	_cage_label.fixed_size = true
	add_child(_cage_label)
	UISkin.plate(_cage_label, "bubble")

## 到終點了：門亮起來（沒有企鵝）
func open_cage(target: Vector3, cam := Vector3.ZERO) -> void:
	_freed = true
	_free_target = target
	_free_cam = cam
	_free_t = 0.0
	_cage_label.text = ""

func reset_cage() -> void:
	_freed = false
	if _cage_label:
		_cage_label.text = goal_text
	for g in _goal_glow:
		(g.mat as ShaderMaterial).set_shader_parameter("emission_c", g.base)

# ================================================================== 外圍：雲海、遠山、月亮；天色

## 外圍沒有海：地面一直鋪出去，遠處三層水墨的山，天上幾朵雲；青綠那一關有月亮
func _build_backdrop(root: Node3D) -> void:
	var md := _mood()
	var c: Vector2 = isle.c
	var cols: Array = md.hills
	for k in 3:
		var ring := MeshInstance3D.new()
		ring.name = "Hills%d" % k
		ring.mesh = _curtain(120.0 + k * 60.0, 52.0 + k * 22.0, 96)
		var hm := ShaderMaterial.new()
		hm.shader = load(HS + "ink_hills.gdshader")
		hm.set_shader_parameter("noise_tex", load(TX + "snow_soft.png"))
		hm.set_shader_parameter("ink", cols[k])
		hm.set_shader_parameter("mist", md.hill_mist)
		hm.set_shader_parameter("seed", 1.7 + k * 5.3 + float(isle.seed))
		hm.set_shader_parameter("ridge", float(md.hill_h) + k * 0.10)
		hm.set_shader_parameter("peaks", 7.0 + k * 3.0)
		ring.material_override = hm
		ring.position = Vector3(c.x, -1.5, c.y)
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(ring)
		_hill_mats.append(hm)
	_clouds = Node3D.new()
	_clouds.name = "Clouds"
	_clouds.position = Vector3(c.x, 0, c.y)
	root.add_child(_clouds)
	var rng := RandomNumberGenerator.new()
	rng.seed = 808 + int(float(isle.seed) * 100.0)
	for k in 6:
		var a := (k + rng.randf_range(-0.25, 0.25)) * TAU / 6.0 - 1.2
		var d := rng.randf_range(90.0, 150.0)
		var cl := _prop(_clouds, MB + "cloud_puff_" + ["a", "b", "c"][k % 3] + ".glb", Vector3(cos(a) * d, rng.randf_range(22.0, 44.0), sin(a) * d), a + PI * 0.5, rng.randf_range(6.0, 10.0))
		_restyle(cl, false)
	if mood == "ink":
		_moon(root, Vector3(c.x + 52.0, 44.0, c.y - 140.0), 13.0, Color(1.0, 0.98, 0.86))

func _build_sea(_root: Node3D) -> void:
	pass

## 圍一圈的布幕（圓柱面，朝裡面）：UV.x 繞一圈 0～1、UV.y 由下到上 0～1
func _curtain(radius: float, height: float, segs: int) -> ArrayMesh:
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	for i in segs + 1:
		var a := i * TAU / segs
		var p := Vector3(cos(a) * radius, 0, sin(a) * radius)
		verts.append(p)
		verts.append(p + Vector3(0, height, 0))
		uvs.append(Vector2(float(i) / segs, 0.0))
		uvs.append(Vector2(float(i) / segs, 1.0))
		if i > 0:
			var b := i * 2
			idx.append_array([b - 2, b, b - 1, b - 1, b, b + 1])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func _moon(root: Node3D, pos: Vector3, size: float, col: Color) -> void:
	var mi := MeshInstance3D.new()
	mi.name = "Moon"
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	mi.mesh = q
	var m := ShaderMaterial.new()
	m.shader = load(HS + "moon.gdshader")
	m.set_shader_parameter("tint", col)
	mi.material_override = m
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)

# ================================================================== 裝飾

func _build_decor(root: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5151 + int(float(isle.seed) * 100.0)
	for z in zones:
		_zone_item(root, z)
	# 外圈：照 rim_kinds 的比重隨機擺（避開台子、雲洞、路線、終點、出發點、手排的擺設）
	if not rim_kinds.is_empty():
		var total := 0.0
		for rk in rim_kinds:
			total += float(rk[1])
		var c: Vector2 = isle.c
		var placed := 0
		for i in 900:
			if placed >= rim_count:
				break
			var a := rng.randf() * TAU
			var d := rim_far * sqrt(rng.randf_range(0.10, 1.0))
			var x := c.x + cos(a) * d
			var z := c.y + sin(a) * d
			if d < 0.0 or not _decor_ok(x, z, 3.8) or _stair_w(x, z) > 0.0:
				continue
			# 鏡頭和家豪之間（南邊靠中間）不放高的東西
			if z > hero_start.z - 3.0 and absf(x - hero_start.x) < 9.0:
				continue
			var pick := rng.randf() * total
			var kind := String(rim_kinds[0][0])
			for rk in rim_kinds:
				pick -= float(rk[1])
				if pick <= 0.0:
					kind = String(rk[0])
					break
			var south := z > hero_start.z - 8.0
			_zone_item(root, {"type": kind, "pos": Vector3(x, 0, z), "yaw": rng.randf() * TAU,
				"scale": rng.randf_range(0.55, 0.75) if south else rng.randf_range(0.85, 1.25)})
			placed += 1
	_petal_fall(root)

## 這個位置能不能放自動擺的裝飾：不在白玉地、步道、雲階上，離洞、路線、終點、出發點、畫門、陸吾、手排的擺設夠遠
func _decor_ok(x: float, z: float, room := 3.4) -> bool:
	if lake_weight(x, z) > 0.0 or _near_hole(x, z, 6.0) or _path_dist(x, z) < 2.6 or _stair_w(x, z) > 0.0:
		return false
	for w in walks:
		var a := Vector2((w[0] as Vector3).x, (w[0] as Vector3).z)
		var ab := Vector2((w[1] as Vector3).x, (w[1] as Vector3).z) - a
		var t := clampf((Vector2(x, z) - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
		if Vector2(x, z).distance_to(a + ab * t) < float(w[2]) * 0.5 + 1.6:
			return false
	var clear: Array = keep_clear.duplicate()
	clear.append(hero_start)
	for c in clear:
		if Vector2(x - c.x, z - c.z).length() < room:
			return false
	for s in door_specs:
		if Vector2(x - s.pos.x, z - s.pos.z).length() < 4.5:
			return false
	if not luwu_spec.is_empty() and Vector2(x - luwu_spec.pos.x, z - luwu_spec.pos.z).length() < 5.0:
		return false
	for zn in zones:
		if zn.has("pos"):
			var need: float = {"tower": 6.0, "house": 5.0, "pavilion": 4.5, "corridor": 4.5, "gate": 5.0, "bridge": 4.0}.get(String(zn.type), 2.6) * float(zn.get("scale", 1.0))
			if Vector2(x - zn.pos.x, z - zn.pos.z).length() < need:
				return false
		if zn.has("pts"):
			var pts: Array = zn.pts
			for i in range(1, pts.size()):
				var a2 := Vector2(pts[i - 1].x, pts[i - 1].z)
				var ab2 := Vector2(pts[i].x, pts[i].z) - a2
				var t2 := clampf((Vector2(x, z) - a2).dot(ab2) / maxf(ab2.length_squared(), 0.001), 0.0, 1.0)
				if Vector2(x, z).distance_to(a2 + ab2 * t2) < float(zn.get("w", 3.0)) * 0.5 + 1.8:
					return false
	return true

## zones 裡的一項擺設：
##   "pine" 水墨松　"blossom" 開粉紅花的樹　"ginkgo" 金黃的樹　"rock" 山石
##   "pavilion" 亭子　"corridor" 一段迴廊（yaw＝走向）　"tower" 樓閣（三層，約 9 公尺高）
##   "house" 兩層的木樓（街邊的房子）　"gate" 一座牌樓（純裝飾，跟終點的南天門同一個模型）
##   "lantern" 宮燈（有一圈暖光）　"stele" 石碑　"ribbon" 紅綢帶："from"、"to"（兩頭掛多高："h"）
##   "river" 小河："pts": [Vector3, ...]、"w": 寬（鋪在地面上的一條水，不擋路）　"bridge" 小拱橋　"ring" 立著的金環（"scale"）
func _zone_item(root: Node3D, z: Dictionary) -> void:
	var yaw: float = z.get("yaw", 0.0)
	var sc: float = z.get("scale", 1.0)
	var g := Vector3.ZERO
	if z.has("pos"):
		g = _g(z.pos.x, z.pos.z)
	match String(z.type):
		"pine":
			_prop(root, HM + "pine_" + ["a", "b"][int(absf(g.x * 7.0)) % 2] + ".glb", g - Vector3(0, 0.05, 0), yaw, sc)
			_blob_shadow(root, g, 1.3 * sc, 0.4)
		"blossom":
			_prop(root, HM + "blossom.glb", g - Vector3(0, 0.05, 0), yaw, sc)
			_blob_shadow(root, g, 1.2 * sc, 0.4)
		"ginkgo":
			_prop(root, HM + "ginkgo_" + ["a", "b"][int(absf(g.z * 5.0)) % 2] + ".glb", g - Vector3(0, 0.05, 0), yaw, sc)
			_blob_shadow(root, g, 1.5 * sc, 0.45)
		"rock":
			_prop(root, HM + "scholar_rock.glb", g - Vector3(0, 0.1, 0), yaw, sc)
			_blob_shadow(root, g, 1.0 * sc, 0.4)
		"pavilion":
			_prop(root, HM + "pavilion.glb", g, yaw, sc)
			_blob_shadow(root, g, 2.6 * sc, 0.5)
			_warm_light(root, g + Vector3(0, 2.0 * sc, 0), 1.0, 5.0)
		"corridor":
			_prop(root, HM + "corridor.glb", g, yaw, sc)
			_blob_shadow(root, g, 2.4 * sc, 0.45)
		"tower":
			_prop(root, HM + "tower.glb", g, yaw, sc)
			_blob_shadow(root, g, 3.4 * sc, 0.55)
			_warm_light(root, g + Vector3(sin(yaw), 0, cos(yaw)) * 2.4 * sc + Vector3(0, 2.2, 0), 1.0, 6.0)
		"lantern":
			_prop(root, HM + "palace_lantern.glb", g, yaw, sc)
			_warm_light(root, g + Vector3(0, 2.2 * sc, 0), 1.2, 4.8)
		"stele":
			_prop(root, HM + "stele.glb", g, yaw, sc)
			_blob_shadow(root, g, 1.2 * sc, 0.45)
		"house":
			_prop(root, HM + "house.glb", g, yaw, sc)
			_blob_shadow(root, g, 3.0 * sc, 0.5)
			_warm_light(root, g + Vector3(sin(yaw), 0, cos(yaw)) * 2.6 * sc + Vector3(0, 2.0, 0), 0.9, 5.5)
		"gate":
			_prop(root, HM + "sky_gate.glb", g, yaw, sc)
			_blob_shadow(root, g, 2.6 * sc, 0.45)
		"bridge":
			_prop(root, HM + "bridge.glb", g, yaw, sc)
		"ring":
			var rn := _prop(root, HM + "gold_ring.glb", g + Vector3(0, float(z.get("y", 4.0)), 0), yaw, sc)
			if rn:
				_restyle(rn, false)
				_ring_nodes.append(rn)
		"ribbon":
			_ribbon(root, z.from, z.to, float(z.get("h", 4.0)), float(z.get("sag", 1.4)))
		"river":
			_river(root, z.pts, float(z.get("w", 3.0)))

## 小河：沿著一串點鋪一條水（貼在地面上一點點；UV.x 橫向 0～1、UV.y 沿河的公尺數）
func _river(root: Node3D, pts: Array, width: float) -> void:
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	var fine: Array = []
	for i in range(1, pts.size()):
		var a: Vector3 = pts[i - 1]
		var b: Vector3 = pts[i]
		var n := maxi(int(a.distance_to(b) / 1.5), 1)
		for k in n:
			fine.append(a.lerp(b, float(k) / n))
	fine.append(pts.back())
	var dist := 0.0
	for i in fine.size():
		var p: Vector3 = fine[i]
		var dir: Vector3 = ((fine[mini(i + 1, fine.size() - 1)] as Vector3) - (fine[maxi(i - 1, 0)] as Vector3))
		dir.y = 0.0
		dir = dir.normalized()
		var side := Vector3(dir.z, 0, -dir.x) * width * 0.5
		if i > 0:
			dist += p.distance_to(fine[i - 1])
		for sg in [-1.0, 1.0]:
			var q: Vector3 = p + side * float(sg)
			verts.append(Vector3(q.x, _ground_y(q.x, q.z) + 0.05, q.z))
			uvs.append(Vector2(0.5 + 0.5 * float(sg), dist))
		if i > 0:
			var k2 := i * 2
			idx.append_array([k2 - 2, k2 - 1, k2, k2 - 1, k2 + 1, k2])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := MeshInstance3D.new()
	mi.name = "River"
	mi.mesh = mesh
	var md := _mood()
	var m := ShaderMaterial.new()
	m.shader = load(HS + "stream.gdshader")
	m.set_shader_parameter("noise_tex", load(TX + "snow_soft.png"))
	m.set_shader_parameter("deep", md.hole[0])
	m.set_shader_parameter("light_c", md.hole[1])
	m.set_shader_parameter("width", width)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)

## 紅綢帶：兩頭掛在高處、中間垂下來的一條布（會輕輕飄）
func _ribbon(root: Node3D, a: Vector3, b: Vector3, h: float, sag: float) -> void:
	var p0 := Vector3(a.x, height_at(a.x, a.z) + h, a.z)
	var p1 := Vector3(b.x, height_at(b.x, b.z) + h, b.z)
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	var n := 28
	for i in n + 1:
		var t := float(i) / n
		var p := p0.lerp(p1, t) - Vector3(0, sag * 4.0 * t * (1.0 - t), 0)
		verts.append(p + Vector3(0, 0.32, 0))
		verts.append(p - Vector3(0, 0.32, 0))
		uvs.append(Vector2(t, 0.0))
		uvs.append(Vector2(t, 1.0))
		if i > 0:
			var k := i * 2
			idx.append_array([k - 2, k - 1, k, k - 1, k + 1, k])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := MeshInstance3D.new()
	mi.name = "Ribbon"
	mi.mesh = mesh
	var m := ShaderMaterial.new()
	m.shader = load(HS + "ribbon.gdshader")
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)

## 飄落的花瓣／金葉／光點（取代下雪）
func _petal_fall(root: Node3D) -> void:
	var md := _mood()
	var ps := CPUParticles3D.new()
	ps.name = "Petals"
	ps.amount = int(md.get("petal_n", 80))
	ps.lifetime = 10.0
	ps.preprocess = 10.0
	ps.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	ps.emission_box_extents = Vector3(22, 0.5, 22)
	ps.direction = Vector3(0.5, -1, 0.15)
	ps.spread = 18.0
	ps.initial_velocity_min = 0.8
	ps.initial_velocity_max = 1.5
	ps.gravity = Vector3(0.12, -0.25, 0)
	ps.angular_velocity_min = -160.0
	ps.angular_velocity_max = 160.0
	ps.angle_min = 0.0
	ps.angle_max = 360.0
	ps.scale_amount_min = 0.6
	ps.scale_amount_max = 1.3
	var q := QuadMesh.new()
	q.size = Vector2(0.24, 0.15) if mood != "astral" else Vector2(0.13, 0.13)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_keep_scale = true
	m.albedo_color = md.get("petal", Color(1, 1, 1))
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
	m.distance_fade_min_distance = 2.5
	m.distance_fade_max_distance = 6.0
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(0.5, 0.04)
	gt.width = 32
	gt.height = 32
	m.albedo_texture = gt
	if mood == "astral":
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	q.material = m
	ps.mesh = q
	ps.position = Vector3(isle.c.x, 16, isle.c.y)
	root.add_child(ps)
	_petals = ps

func set_snow(on: bool) -> void:
	if _petals:
		_petals.visible = on

# ================================================================== 每一畫面：畫門的光、陸吾、金環

func _process(dt: float) -> void:
	super(dt)
	var now := Time.get_ticks_msec() * 0.001
	for i in doors.size():
		_door_flash[i] = maxf(float(_door_flash[i]) - dt, 0.0)
		var pm = doors[i].mat
		if pm:
			(pm as ShaderMaterial).set_shader_parameter("flash", float(_door_flash[i]) / 0.6)
	if not luwu.is_empty() and luwu.get("node"):
		_luwu_t += dt
		var node := luwu.node as Node3D
		var head := luwu.get("head") as Node3D
		var tails := luwu.get("tails") as Node3D
		match _luwu_state:
			"inhale":
				node.scale = Vector3.ONE * (1.0 + 0.18 * clampf(_luwu_t / 0.4, 0.0, 1.0))
				if head:
					head.rotation.x = -0.25 * clampf(_luwu_t / 0.4, 0.0, 1.0)
			"sleep":
				node.scale = Vector3.ONE * (1.0 + 0.025 * sin(now * 1.6))
				if head:
					head.rotation.x = lerpf(head.rotation.x, 0.42, 1.0 - exp(-dt * 6.0))
				if _zzz:
					_zzz.position = (luwu.pos as Vector3) + Vector3(0.6, 3.0 + 0.25 * sin(now * 1.6), 0)
			_:
				node.scale = Vector3.ONE * (1.0 + 0.02 * sin(now * 2.4))
				if head:
					head.rotation.x = lerpf(head.rotation.x, 0.0, 1.0 - exp(-dt * 6.0))
		if tails:
			tails.rotation.y = sin(now * (0.5 if _luwu_state == "sleep" else 1.6)) * 0.12
	for k in _ring_nodes.size():
		(_ring_nodes[k] as Node3D).rotation.z = now * (0.10 + 0.05 * k) * (1.0 if k % 2 == 0 else -1.0) * (4.0 if _fin_on else 1.0)
	# 到終點：門的光慢慢亮起來
	if _freed or _fin_on:
		var k2 := clampf(_free_t / 1.2, 0.0, 1.0) * (2.6 if _fin_on else 1.0)
		for g in _goal_glow:
			(g.mat as ShaderMaterial).set_shader_parameter("emission_c", (g.base as Color) * (1.0 + 2.2 * k2))
	if _fin_on:
		_fin_t += dt
		if _phoenix:
			var s := 1.0 - pow(1.0 - clampf(_fin_t / 2.2, 0.0, 1.0), 3.0)
			_phoenix.scale = Vector3.ONE * (0.2 + 2.6 * s)
			_phoenix.position.y = 1.5 + 5.5 * s

## 全章收尾（規格第 5 節）：唱盤和圓門大亮、金環轉快、家豪身上展開一道鳳凰形狀的金光
func finale_show(on: bool) -> void:
	_fin_on = on
	_fin_t = 0.0
	if on and _phoenix == null and _cage_root:
		_phoenix = _prop(_cage_root, HM + "phoenix_light.glb", Vector3(0, 1.5, 0.0), 0.0, 1.0)
		if _phoenix:
			var pm := ShaderMaterial.new()
			pm.shader = load(HS + "phoenix_light.gdshader")
			for m in _phoenix.find_children("*", "MeshInstance3D", true, false):
				(m as MeshInstance3D).material_override = pm
				(m as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if _phoenix:
		_phoenix.visible = on
	if _petals:
		_petals.amount = int(_mood().get("petal_n", 80)) * (3 if on else 1)
