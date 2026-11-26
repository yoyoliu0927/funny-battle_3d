extends Node
## 效能小幫手（所有場景共用，不是 autoload）
##
## 主場景（scenes/intro.tscn）一開始就呼叫 `WebPerf.install(get_tree())`，
## 它把自己掛在 root 底下（不是場景的一部分），換場景時不會被刪掉。選關地圖、關卡也會再呼叫一次，只會裝一份。
##
## 做的事：
## 1. 換場景不再重編著色器（所有平台）：Compatibility 渲染器（網頁版）第一次畫某種材質要先編著色器，
##    舊場景一拿掉，材質和著色器被釋放，編好的結果也跟著丟掉，下一次進來又要從頭編——
##    這就是「轉場很卡」「按回地圖好像沒反應」的主因。這裡把「每一種」著色器留一份：
##    - ShaderMaterial：同一段著色器程式碼只留一個 Shader。之後又 new 出內容一樣的 Shader，就把材質換成留著的那一個
##      （已經編好了）。.gdshader 檔一直被留著，load() 也會直接拿到同一個。
##    - StandardMaterial3D 這類內建材質：引擎照「設定組合」共用著色器，每一種組合留一個材質，那種著色器就不會被丟掉。
##    只留每一種一份（整個遊戲幾百種），不是每個材質都留，記憶體不會一直長。
##    剛進樹的節點先排隊，這一幀最後（畫之前）才一起看：很多腳本是 add_child 之後才設材質。
## 2. 網頁版、高解析度螢幕（Retina、Windows 放大 150%）：3D 用「螢幕像素 ÷ 縮放倍率」的解析度畫
##    （跟一般螢幕一樣多的像素），介面和文字照樣用全解析度，所以字還是清楚的。原本要畫 4 倍的像素。
## 3. 網頁版：太陽影子切片 4 → 2、點光源和聚光燈不開影子（Compatibility 渲染器每個有影子的燈都要多畫一輪）。
## 4. 網頁版、電腦跑不動的時候自動降畫質（只降不升，換場景也維持）：
##    連續 4 秒低於 40 FPS → 關掉太陽的影子（繪製次數大約少一半）；還是不夠 → 3D 解析度再降到 75%。
##    開場、換場景後的前幾秒（載入、編譯著色器）不算。
##
## 測試用參數（放在 `--` 後面）：--perf-web（桌面版也套用網頁版的設定）、--perf-keep=0（不留著色器）、
##   --perf-low=1／2（直接用降過的畫質）

const NODE_NAME := "WebPerf"
const SCRIPT_PATH := "res://scripts/web_perf.gd"

var web := false
var keep_shaders := true
var low := 0               # 4. 降了幾級畫質：0 原本、1 沒有太陽影子、2 再加上 3D 解析度 75%

const SLOW_FPS := 40.0     # 低於這個 FPS 算「慢」
const SLOW_FOR := 4.0      # 連續慢了幾秒才降
const SETTLE := 4.0        # 換場景後先等幾秒才開始算
const MAX_KEEP := 1500     # 保險：最多留這麼多份（正常整個遊戲只有幾百種）

var _scene: Node = null
var _dpr := 0.0
var _dpr_t := 0.0
var _settle := SETTLE
var _slow_t := 0.0
var _avg_dt := 1.0 / 60.0

var _shaders := {}         # 著色器程式碼的 hash -> 留著的 Shader
var _base := {}            # 內建材質的設定組合 -> 留著的材質
var _other: Array = []     # 其他有檔案的材質（粒子材質等）留一份
var _other_keys := {}
var _known := {}           # 這個場景已經看過的材質（instance id）
var _pending: Array = []   # 剛進樹、等這一幀最後一起看的節點
var _flush_queued := false
var _scene_id := 0

## 裝上（重複呼叫沒關係）
static func install(tree: SceneTree) -> void:
	if tree == null or tree.root.has_node(NODE_NAME):
		return
	var n := Node.new()
	n.set_script(load(SCRIPT_PATH))
	n.name = NODE_NAME
	tree.root.add_child.call_deferred(n)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var args := OS.get_cmdline_user_args()
	web = OS.has_feature("web") or "--perf-web" in args
	keep_shaders = not "--perf-keep=0" in args
	for a in args:
		if a.begins_with("--perf-low="):
			low = clampi(int(a.substr(11)), 0, 2)
	get_tree().node_added.connect(_on_node_added)
	# 裝上之前就已經在樹裡的東西也看一次（例如直接從關卡場景開始跑）
	for n in get_tree().root.find_children("*", "", true, false):
		_on_node_added(n)
	_update_scale()

func _process(dt: float) -> void:
	var cur := get_tree().current_scene
	if cur != _scene:
		_scene = cur
		_settle = SETTLE
		_slow_t = 0.0
	_watch_fps(dt)
	# 視窗搬到另一個螢幕、瀏覽器縮放改變時，縮放倍率會變
	_dpr_t -= dt
	if _dpr_t <= 0.0:
		_dpr_t = 1.0
		_update_scale()

func _on_node_added(n: Node) -> void:
	if n is Light3D:
		_tune_light(n as Light3D)
	if keep_shaders and (n is GeometryInstance3D or n is WorldEnvironment or (n is CanvasItem and (n as CanvasItem).material != null)):
		_pending.append(n)
		if not _flush_queued:
			_flush_queued = true
			_flush.call_deferred()

# ---------------------------------------------------------------- 1. 換場景不再重編著色器

func _flush() -> void:
	_flush_queued = false
	var cs := get_tree().current_scene
	var sid := cs.get_instance_id() if cs else 0
	if sid != _scene_id:
		_scene_id = sid
		_known.clear()
	var list := _pending
	_pending = []
	for n in list:
		if is_instance_valid(n):
			_look_node(n)

func _look_node(n: Node) -> void:
	if n is GeometryInstance3D:
		var g := n as GeometryInstance3D
		if g.material_override:
			g.material_override = _look(g.material_override)
		if g.material_overlay:
			g.material_overlay = _look(g.material_overlay)
		if n is MeshInstance3D:
			var mi := n as MeshInstance3D
			if mi.mesh:
				for i in mi.mesh.get_surface_count():
					var so := mi.get_surface_override_material(i)
					if so:
						var so2 := _look(so)
						if so2 != so:
							mi.set_surface_override_material(i, so2)
					var sm := mi.mesh.surface_get_material(i)
					if sm:
						_look(sm)       # 網格自己的材質（多半是匯入的模型）：留一份就好，不換
		elif n is MultiMeshInstance3D:
			var mm := (n as MultiMeshInstance3D).multimesh
			if mm and mm.mesh:
				for i in mm.mesh.get_surface_count():
					var m := mm.mesh.surface_get_material(i)
					if m:
						_look(m)
		elif n is GPUParticles3D:
			var pm := (n as GPUParticles3D).process_material
			if pm:
				_look(pm)
	elif n is WorldEnvironment:
		var env := (n as WorldEnvironment).environment
		if env and env.sky and env.sky.sky_material:
			env.sky.sky_material = _look(env.sky.sky_material)
	elif n is CanvasItem:
		var ci := n as CanvasItem
		if ci.material:
			ci.material = _look(ci.material)

## 看一個材質：回傳要用的材質（通常是原本那個；ShaderMaterial 可能換掉裡面的 Shader，材質本身不變）
func _look(m: Material) -> Material:
	if m == null:
		return m
	var id := m.get_instance_id()
	if _known.has(id):
		return m
	_known[id] = true
	if m.next_pass:
		_look(m.next_pass)
	if kept_count() >= MAX_KEEP:
		return m
	if m is ShaderMaterial:
		var sm := m as ShaderMaterial
		var sh := sm.shader
		if sh == null:
			return m
		var key := sh.code.hash()
		var kept: Shader = _shaders.get(key)
		if kept == null:
			_shaders[key] = sh
		elif kept != sh and kept.code == sh.code:
			sm.shader = kept          # 同一段程式碼：換成已經編好的那一個（參數名字一樣，值會留著）
	elif m is BaseMaterial3D:
		var k := _base_key(m as BaseMaterial3D)
		if not _base.has(k):
			_base[k] = m
	elif m.resource_path != "":
		var ok := "%s|%s" % [m.get_class(), m.resource_path]
		if not _other_keys.has(ok) and _other.size() < 64:
			_other_keys[ok] = true
			_other.append(m)
	return m

## 內建材質會影響著色器的設定（顏色、數值是 uniform，不影響）
const _BASE_PROPS := [
	"transparency", "alpha_antialiasing_mode", "blend_mode", "cull_mode", "depth_draw_mode", "no_depth_test",
	"shading_mode", "diffuse_mode", "specular_mode", "disable_ambient_light", "disable_fog", "disable_receive_shadows",
	"vertex_color_use_as_albedo", "vertex_color_is_srgb", "albedo_texture_force_srgb", "albedo_texture_msdf",
	"normal_enabled", "emission_enabled", "emission_operator", "rim_enabled", "clearcoat_enabled", "anisotropy_enabled",
	"ao_enabled", "heightmap_enabled", "subsurf_scatter_enabled", "backlight_enabled", "refraction_enabled", "detail_enabled",
	"uv1_triplanar", "uv2_triplanar", "uv1_world_triplanar", "billboard_mode", "billboard_keep_scale", "grow",
	"use_point_size", "fixed_size", "texture_filter", "texture_repeat", "proximity_fade_enabled", "distance_fade_mode",
	"use_particle_trails", "shadow_to_opacity", "metallic_texture_channel", "roughness_texture_channel",
]

func _base_key(m: BaseMaterial3D) -> String:
	var parts := PackedStringArray([m.get_class()])
	for p in _BASE_PROPS:
		parts.append(str(m.get(p)))
	parts.append("1" if m.albedo_texture else "0")
	parts.append("1" if m.metallic_texture else "0")
	parts.append("1" if m.roughness_texture else "0")
	return "|".join(parts)

## 目前留著幾種著色器（測試用）
func kept_count() -> int:
	return _shaders.size() + _base.size() + _other.size()

# ---------------------------------------------------------------- 2. 網頁版的 3D 解析度

func _update_scale() -> void:
	if not web:
		return
	var dpr := DisplayServer.screen_get_scale() * (1.0 / 0.75 if low >= 2 else 1.0)
	if is_equal_approx(dpr, _dpr):
		return
	_dpr = dpr
	var vp := get_tree().root
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	vp.scaling_3d_scale = clampf(1.0 / maxf(dpr, 0.01), 0.35, 1.0)

# ---------------------------------------------------------------- 3. 網頁版的影子

func _tune_light(l: Light3D) -> void:
	if not web:
		return
	if l is DirectionalLight3D:
		var d := l as DirectionalLight3D
		if d.directional_shadow_mode == DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS:
			d.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
		if low >= 1:
			d.shadow_enabled = false
	else:
		l.shadow_enabled = false

# ---------------------------------------------------------------- 4. 跑不動就自動降畫質

func _watch_fps(dt: float) -> void:
	if not web or low >= 2 or get_tree().paused:
		return
	if _settle > 0.0:
		_settle -= dt
		_avg_dt = 1.0 / 60.0
		if _settle <= 0.0 and low >= 1:
			set_low(low)          # 場景自己在 _ready 之後才把影子打開的，再關一次
		return
	_avg_dt = lerpf(_avg_dt, minf(dt, 0.25), 0.1)
	if _avg_dt > 1.0 / SLOW_FPS:
		_slow_t += dt
	else:
		_slow_t = maxf(_slow_t - dt * 0.5, 0.0)
	if _slow_t >= SLOW_FOR:
		_slow_t = 0.0
		_settle = SETTLE
		set_low(low + 1)

## 設定降畫質的等級（0～2）：已經在場上的燈、之後新建的燈都會照這個
func set_low(level: int) -> void:
	if level != low:
		print("WebPerf: 畫質降到 %d（FPS 太低）" % level)
	low = clampi(level, 0, 2)
	for l in get_tree().root.find_children("*", "DirectionalLight3D", true, false):
		_tune_light(l as Light3D)
	_dpr = 0.0
	_update_scale()
