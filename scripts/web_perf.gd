extends Node
## 效能小幫手（所有場景共用，不是 autoload）
##
## 主場景（scenes/intro.tscn）一開始就呼叫 `WebPerf.install(get_tree())`，
## 它把自己掛在 root 底下（不是場景的一部分），換場景時不會被刪掉。選關地圖、關卡、暫停選單也會再呼叫一次，只會裝一份。
## 別的腳本要找它：`WebPerf.find(get_tree())`（可能還沒裝好，會是 null）。
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
##    網頁版另外：太陽影子切片 4 → 2、點光源和聚光燈不開影子（Compatibility 渲染器每個有影子的燈都要多畫一輪）。
## 3. 畫質（所有平台）：玩家在選單裡選（主島按 P 的選單、戰局暫停選單的「畫質」，按 Q 輪流換），或交給「自動」：
##      最高：跟下載版一樣（只有網頁版有這一級）：3D 用螢幕的全解析度、太陽影子 4 切片 4096、點光源和聚光燈也有影子、
##            4 倍反鋸齒（MSAA）。最吃效能，「自動」不會選它
##      高：網頁版照第 2 點；電腦版就是原本的樣子
##      中：不畫影子（繪製次數大約少一半）
##      低：不畫影子、3D 解析度 75%、關掉光暈（glow）和反鋸齒
## 4. 「自動」（預設）：照這台電腦的效能在「高／中／低」裡挑，邊玩邊調：
##    - 一開始先看顯示卡和 CPU 猜一個（手機、軟體繪圖 → 低；Intel 內顯 → 中；獨立顯卡、Apple M 系列 → 高；
##      看不出來就看 CPU 核心數）。之後開遊戲直接用上次調好的等級。
##    - 邊玩邊看 FPS（每秒算一次）：連續 4 秒低於 40 → 降一級；降了之後真的變順，就記住「這台電腦跑不動那一級」，
##      以後不會再自動升回去。降了也沒有變順（瓶頸不在畫面，或瀏覽器省電模式把 FPS 鎖在 30）→ 退回原本的等級，
##      這次開遊戲不再自動調。連續 20 秒都很順（≥55 FPS）→ 試著升一級（不會超過記住的那一級）。
##    - 開場、換場景後的前 4 秒、卡一下的那一秒（載入、編著色器）不算；電腦版視窗不在最前面的時候也不算。
##    設定存在 user://settings.cfg 的 [graphics]：quality（auto／ultra／high／mid／low）、auto_lv（自動現在用哪一級）、
##    auto_cap（自動最高只能到哪一級）。等級的數字：0 最高、1 高、2 中、3 低。
##
## 測試用參數（放在 `--` 後面）：--perf-web（桌面版也套用網頁版的設定）、--perf-keep=0（不留著色器）、
##   --perf-low=0／1／2／3（直接用這一級畫質：0 最高、1 高、2 中、3 低，不自動調、不存檔）

const NODE_NAME := "WebPerf"
const SCRIPT_PATH := "res://scripts/web_perf.gd"
const SETTINGS_PATH := "user://settings.cfg"

const QUALITIES := ["auto", "ultra", "high", "mid", "low"]   # 選單裡輪流切換的順序（電腦版沒有 ultra）
const LEVEL_NAMES := ["最高", "高", "中", "低"]                 # 等級 0～3
const AUTO_BEST := 1       # 「自動」最多到「高」
const AUTO_WORST := 3
const LOW_SCALE := 0.75    # 「低」的 3D 解析度
const OFF_META := &"webperf_off"   # 燈和環境上的記號：這是畫質設定關掉的，調回來時要再打開

var web := false
var keep_shaders := true
var quality := "auto"      # 玩家選的：auto／ultra／high／mid／low
var low := 1               # 現在用的等級：0 最高、1 高、2 中、3 低
var hint := -1             # 「自動」照硬體猜的等級（還沒猜是 -1）
var gpu_name := ""         # 顯示卡名稱（猜等級時順便記下來，測試和除錯用）

const SLOW_FPS := 40.0     # 低於這個 FPS 算「慢」
const SLOW_FOR := 4        # 連續慢了幾秒才降
const FAST_FPS := 55.0     # 高於這個 FPS 算「很順」
const FAST_FOR := 20       # 連續順了幾秒才試著升
const STALL := 0.3         # 這一秒裡有一格超過這麼久：算「卡一下」（載入、編著色器），這一秒不算
const SETTLE := 4.0        # 換場景、換畫質後先等幾秒才開始算
const MAX_KEEP := 1500     # 保險：最多留這麼多份（正常整個遊戲只有幾百種）

var _forced := false       # 用 --perf-low 指定了等級
var _headless := false
var _auto_level := -1      # 存檔裡「自動」上次用的等級（沒有是 -1）
var _floor := AUTO_BEST    # 「自動」最高只能到哪一級（試過跑不動的那一級的下一級）
var _stuck := false        # 降了也沒有變順：這次開遊戲不再自動調
var _scene: Node = null
var _dpr_t := 0.0
var _settle := SETTLE
var _win_t := 0.0          # 這一秒已經過了多久
var _win_n := 0            # 這一秒畫了幾格
var _win_worst := 0.0      # 這一秒最久的一格
var _slow_n := 0           # 連續慢了幾秒
var _fast_n := 0           # 連續順了幾秒
var _fps_hist: Array = []  # 最近幾秒的 FPS（不含卡一下的那幾秒）
var _check := {}           # 剛降一級：{before 降之前的 FPS, level 降之前的等級, floor 降之前的上限}，看降了有沒有變順
var _scale_key := -1.0     # 上次設的 3D 解析度（一樣就不重設）
var _scale_touched := false
var _msaa_touched := false
var _msaa_was := Viewport.MSAA_DISABLED
var _msaa_default := -1    # 一開始的反鋸齒（專案設定，網頁版是關的）
var _atlas := 0            # 網頁版現在的太陽影子貼圖大小（0＝沒動過）

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
	if tree == null or tree.root.has_node(NODE_NAME) or tree.has_meta(&"webperf_pending"):
		return
	tree.set_meta(&"webperf_pending", true)   # 同一幀裡又呼叫一次（還沒真的加進去）：不要裝兩份
	var n := Node.new()
	n.set_script(load(SCRIPT_PATH))
	n.name = NODE_NAME
	tree.root.add_child.call_deferred(n)

## 找到裝好的那一個（還沒裝好是 null）
static func find(tree: SceneTree) -> Node:
	if tree == null:
		return null
	return tree.root.get_node_or_null(NODE_NAME)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if get_tree().has_meta(&"webperf_pending"):
		get_tree().remove_meta(&"webperf_pending")
	var args := OS.get_cmdline_user_args()
	web = OS.has_feature("web") or "--perf-web" in args
	keep_shaders = not "--perf-keep=0" in args
	_headless = DisplayServer.get_name() == "headless"
	_load_settings()
	for a in args:
		if a.begins_with("--perf-low="):
			low = clampi(int(a.substr(11)), 0, 3)
			_forced = true
	print("WebPerf: 畫質 %s（顯示卡：%s）" % [quality_label(), gpu_name if gpu_name != "" else "?"])
	get_tree().node_added.connect(_on_node_added)
	# 裝上之前就已經在樹裡的東西也看一次（例如直接從關卡場景開始跑）
	for n in get_tree().root.find_children("*", "", true, false):
		_on_node_added(n)
	_apply()

func _process(dt: float) -> void:
	var cur := get_tree().current_scene
	if cur != _scene:
		_scene = cur
		_settle = SETTLE
		_reset_watch()
		_fps_hist.clear()
	if _settle > 0.0:
		_settle -= dt
		if _settle <= 0.0:
			_apply()              # 場景自己在 _ready 之後才打開的影子、光暈，再照畫質調一次
	else:
		_watch_fps(dt)
	# 視窗搬到另一個螢幕、瀏覽器縮放改變時，縮放倍率會變
	_dpr_t -= dt
	if _dpr_t <= 0.0:
		_dpr_t = 1.0
		_update_scale()

func _on_node_added(n: Node) -> void:
	if n is Light3D:
		_tune_light(n as Light3D)
	elif n is WorldEnvironment:
		_tune_env(n as WorldEnvironment)
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

# ---------------------------------------------------------------- 2～3. 照畫質調整解析度、影子、光暈、反鋸齒

const PSSM_META := &"webperf_pssm4"   # 太陽原本是 4 切片、被網頁版改成 2 切片的記號

## 照現在的等級把整個遊戲調一次（已經在場上的燈和環境、解析度、反鋸齒、影子貼圖）
func _apply() -> void:
	var root := get_tree().root
	if _msaa_default < 0:
		_msaa_default = root.msaa_3d
	for l in root.find_children("*", "Light3D", true, false):
		_tune_light(l as Light3D)
	for e in root.find_children("*", "WorldEnvironment", true, false):
		_tune_env(e as WorldEnvironment)
	_scale_key = -1.0
	_update_scale()
	_update_msaa()
	_update_atlas()

## 3D 解析度。網頁版：最高＝螢幕全解析度；其他＝螢幕像素 ÷ 縮放倍率（低再 ×75%）。電腦版：低＝75%
func _update_scale() -> void:
	var vp := get_tree().root
	if web:
		var sc := 1.0
		if low >= 1:
			sc = clampf(1.0 / maxf(DisplayServer.screen_get_scale(), 0.01), 0.35, 1.0) * (LOW_SCALE if low >= 3 else 1.0)
		if is_equal_approx(sc, _scale_key):
			return
		_scale_key = sc
		vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
		vp.scaling_3d_scale = sc
	elif low >= 3:
		if _scale_touched:
			return
		_scale_touched = true
		vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
		vp.scaling_3d_scale = LOW_SCALE
	elif _scale_touched:
		# 電腦版從「低」調回來：還原專案設定（沒調過就完全不碰，關卡自己改的解析度不會被蓋掉）
		_scale_touched = false
		vp.scaling_3d_mode = int(ProjectSettings.get_setting("rendering/scaling_3d/mode", 0)) as Viewport.Scaling3DMode
		vp.scaling_3d_scale = float(ProjectSettings.get_setting("rendering/scaling_3d/scale", 1.0))

## 反鋸齒：網頁版本來是關的，「最高」開成跟電腦版一樣；「低」關掉。沒有要改就不碰（關卡自己設的不會被蓋掉）
func _update_msaa() -> void:
	var vp := get_tree().root
	var target := _msaa_default
	if web and low == 0:
		target = int(ProjectSettings.get_setting("rendering/anti_aliasing/quality/msaa_3d", Viewport.MSAA_4X))
	elif low >= 3:
		target = Viewport.MSAA_DISABLED
	if target != _msaa_default:
		if vp.msaa_3d != target:
			if not _msaa_touched:
				_msaa_was = vp.msaa_3d
			_msaa_touched = true
			vp.msaa_3d = target as Viewport.MSAA
	elif _msaa_touched:
		_msaa_touched = false
		vp.msaa_3d = _msaa_was

## 網頁版太陽影子貼圖：「最高」用電腦版的 4096，其他用網頁版的 2048
func _update_atlas() -> void:
	if not web:
		return
	var size := int(ProjectSettings.get_setting("rendering/lights_and_shadows/directional_shadow/size", 4096))
	if low >= 1:
		size = 2048
	if size == _atlas:
		return
	if _atlas == 0 and size == 2048:
		_atlas = size                # 一開始就是 2048（網頁版的專案設定），不用重設
		return
	_atlas = size
	RenderingServer.directional_shadow_atlas_set_size(size, bool(ProjectSettings.get_setting("rendering/lights_and_shadows/directional_shadow/16_bits", true)))

## 一盞燈的影子：
##   電腦版：最高、高＝照關卡原本的設定；中、低＝都不畫
##   網頁版：最高＝照原本的設定；高＝只有太陽（2 切片）；中、低＝都不畫
## 畫質關掉的影子、改掉的切片都會做記號，調回來的時候還原
func _tune_light(l: Light3D) -> void:
	var sun := l is DirectionalLight3D
	if sun:
		var d := l as DirectionalLight3D
		if web and low >= 1 and d.directional_shadow_mode == DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS:
			d.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
			d.set_meta(PSSM_META, true)
		elif low == 0 and d.has_meta(PSSM_META):
			d.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
			d.remove_meta(PSSM_META)
	var want: bool
	if web:
		want = low == 0 or (low == 1 and sun)
	else:
		want = low <= 1
	if not want and l.shadow_enabled:
		l.shadow_enabled = false
		l.set_meta(OFF_META, true)
	elif want and l.has_meta(OFF_META):
		l.shadow_enabled = true
		l.remove_meta(OFF_META)

## 環境：「低」關掉光暈
func _tune_env(w: WorldEnvironment) -> void:
	var env := w.environment
	if env == null:
		return
	if low >= 3 and env.glow_enabled:
		env.glow_enabled = false
		env.set_meta(OFF_META, true)
	elif low < 3 and env.has_meta(OFF_META):
		env.glow_enabled = true
		env.remove_meta(OFF_META)

# ---------------------------------------------------------------- 3. 畫質設定（選單用）

## 這個平台可以選的畫質（電腦版沒有「最高」：電腦版的「高」就是最高）
func qualities() -> Array:
	return QUALITIES if web else QUALITIES.filter(func(q): return q != "ultra")

## 選單上寫的：「自動（中）」或「最高」
func quality_label() -> String:
	if quality == "auto":
		return "自動（%s）" % LEVEL_NAMES[low]
	return String(LEVEL_NAMES[low])

## 換畫質時跳出來的一句說明
func quality_hint() -> String:
	var what := ["跟下載版一樣，最吃效能", "有影子", "不畫影子，比較順", "不畫影子、解析度降低，最順"][low] as String
	if quality == "auto":
		return "畫質：自動（現在是「%s」，%s）・依照電腦跑得順不順自己調整" % [LEVEL_NAMES[low], what]
	return "畫質：%s（%s）" % [LEVEL_NAMES[low], what]

## 選單按一下：自動 → 最高 → 高 → 中 → 低 → 自動（電腦版跳過最高）
func cycle_quality() -> void:
	var qs := qualities()
	set_quality(qs[(qs.find(quality) + 1) % qs.size()])

## 設定畫質（auto／ultra／high／mid／low），馬上套用並存到設定檔
func set_quality(q: String) -> void:
	if not q in qualities():
		return
	quality = q
	_forced = false
	_stuck = false
	_check = {}
	low = _auto_start() if q == "auto" else QUALITIES.find(q) - 1
	_settle = SETTLE
	_reset_watch()
	_fps_hist.clear()
	_save_settings()
	_apply()
	print("WebPerf: 畫質改成 %s" % quality_label())

## 「自動」從哪一級開始：上次調好的等級（沒有就照硬體猜），不超過記住的上限
func _auto_start() -> int:
	var start := _auto_level if _auto_level >= 0 else guess_level()
	return clampi(maxi(start, _floor), AUTO_BEST, AUTO_WORST)

func _load_settings() -> void:
	var cf := ConfigFile.new()
	cf.load(SETTINGS_PATH)           # 沒有這個檔就全部用預設
	quality = String(cf.get_value("graphics", "quality", "auto"))
	if not quality in qualities():
		quality = "auto"
	_floor = clampi(int(cf.get_value("graphics", "auto_cap", AUTO_BEST)), AUTO_BEST, AUTO_WORST)
	_auto_level = clampi(int(cf.get_value("graphics", "auto_lv", -1)), -1, AUTO_WORST)
	low = _auto_start() if quality == "auto" else QUALITIES.find(quality) - 1
	if hint < 0:
		guess_level()                # 順便記下顯示卡名稱

func _save_settings() -> void:
	if _forced:
		return
	var cf := ConfigFile.new()
	cf.load(SETTINGS_PATH)
	cf.set_value("graphics", "quality", quality)
	if quality == "auto":
		_auto_level = low
		cf.set_value("graphics", "auto_lv", low)
	cf.set_value("graphics", "auto_cap", _floor)
	cf.save(SETTINGS_PATH)

# ---------------------------------------------------------------- 4. 自動：照硬體猜、邊玩邊看 FPS

## 照顯示卡、CPU 核心數、記憶體猜一個等級（1 高、2 中、3 低）
func guess_level() -> int:
	if hint >= 0:
		return hint
	var info := {}
	if OS.has_feature("web"):
		# 遊戲自己的 WebGL 拿到的顯示卡名稱被瀏覽器遮掉了（「WebKit WebGL」），另外開一個小畫布問
		var r = JavaScriptBridge.eval("""(function () { try {
	var c = document.createElement('canvas');
	var gl = c.getContext('webgl2') || c.getContext('webgl');
	var g = '';
	if (gl) {
		var d = gl.getExtension('WEBGL_debug_renderer_info');
		g = d ? gl.getParameter(d.UNMASKED_RENDERER_WEBGL) : gl.getParameter(gl.RENDERER);
		var lose = gl.getExtension('WEBGL_lose_context');
		if (lose) lose.loseContext();
	}
	var ua = navigator.userAgent || '';
	var mobile = /Android|iPhone|iPad|iPod|Mobile/i.test(ua) || (/Macintosh/.test(ua) && navigator.maxTouchPoints > 1);
	return JSON.stringify({ gpu: String(g || ''), cores: navigator.hardwareConcurrency || 0, mem: navigator.deviceMemory || 0, mobile: mobile });
} catch (e) { return '{}'; } })()""", true)
		if r is String:
			var parsed = JSON.parse_string(r)
			if parsed is Dictionary:
				info = parsed
	else:
		info = {"gpu": "%s %s" % [RenderingServer.get_video_adapter_vendor(), RenderingServer.get_video_adapter_name()],
			"cores": OS.get_processor_count(), "mem": 0, "mobile": OS.has_feature("mobile")}
	gpu_name = String(info.get("gpu", "")).strip_edges()
	hint = AUTO_BEST + level_for(gpu_name, int(info.get("cores", 0)), float(info.get("mem", 0)), bool(info.get("mobile", false)))
	return hint

## 猜等級的規則（獨立出來方便測試）：回傳 0 好、1 普通、2 弱（對應 高／中／低）
static func level_for(gpu: String, cores: int, mem: float, mobile: bool) -> int:
	var g := gpu.to_lower()
	var has := func(words: Array) -> bool:
		for w in words:
			if g.contains(String(w)):
				return true
		return false
	var lv := 1
	if mobile or has.call(["swiftshader", "llvmpipe", "software", "basic render", "mali", "adreno", "powervr"]):
		lv = 2                       # 手機、平板、軟體繪圖（沒有顯示卡加速）
	elif has.call(["nvidia", "geforce", "quadro", "rtx", "gtx"]):
		lv = 0
	elif has.call(["radeon", "amd"]):
		lv = 1 if has.call(["vega", "radeon(tm) graphics", "radeon graphics"]) else 0   # AMD 內顯算普通
	elif has.call(["apple m", "apple a1"]):
		lv = 0                       # Apple M 系列
	elif g.contains("intel"):
		if has.call(["arc(", "arc "]):
			lv = 0                   # Intel Arc 獨立顯卡
		elif g.contains("hd graphics") and not g.contains("uhd"):
			lv = 2                   # 舊的 Intel HD 內顯
		else:
			lv = 1                   # Intel UHD／Iris 內顯
	elif cores >= 8:
		lv = 0                       # 看不出顯示卡（例如 Safari 只說「Apple GPU」）：看 CPU
	if cores > 0 and cores <= 2:
		lv = 2
	elif cores > 0 and cores <= 4:
		lv = maxi(lv, 1)
	if mem > 0.0 and mem <= 2.0:
		lv = 2
	elif mem > 0.0 and mem < 4.0:
		lv = maxi(lv, 1)
	return lv

func _reset_watch() -> void:
	_win_t = 0.0
	_win_n = 0
	_win_worst = 0.0
	_slow_n = 0
	_fast_n = 0

## 每一秒算一次 FPS，太慢就降一級、一直很順就試著升一級
func _watch_fps(dt: float) -> void:
	if quality != "auto" or _forced or _stuck or _headless or get_tree().paused:
		_reset_watch()
		return
	if not web and not DisplayServer.window_is_focused():
		_reset_watch()               # 電腦版視窗被蓋住、不在最前面：macOS 不太畫，FPS 不準
		return
	_win_t += dt
	_win_n += 1
	_win_worst = maxf(_win_worst, dt)
	if _win_t < 1.0:
		return
	var fps := _win_n / _win_t
	var stalled := _win_worst > STALL
	_win_t = 0.0
	_win_n = 0
	_win_worst = 0.0
	if stalled:
		return                       # 卡一下（載入、編著色器、切回分頁）：這一秒不算
	_fps_hist.append(fps)
	if _fps_hist.size() > SLOW_FOR:
		_fps_hist.pop_front()
	# 剛降過一級：看幾秒，有變順就記住；沒有變順就退回去，這次不再自動調
	if not _check.is_empty():
		if _fps_hist.size() < SLOW_FOR:
			return
		var now := _avg(_fps_hist)
		var before := float(_check.before)
		if now < SLOW_FPS and now < before * 1.15:
			print("WebPerf: 降了畫質也沒有變順（%.0f → %.0f FPS），退回「%s」，這次不再自動調" % [before, now, LEVEL_NAMES[int(_check.level)]])
			_floor = int(_check.floor)
			_stuck = true
			_auto_set(int(_check.level))
		_check = {}
		_reset_watch()
		return
	if fps < SLOW_FPS:
		_slow_n += 1
		_fast_n = 0
	elif fps >= FAST_FPS:
		_fast_n += 1
		_slow_n = maxi(_slow_n - 1, 0)
	else:
		_fast_n = 0
		_slow_n = maxi(_slow_n - 1, 0)
	if _slow_n >= SLOW_FOR and low < AUTO_WORST:
		_check = {"before": _avg(_fps_hist), "level": low, "floor": _floor}
		_floor = maxi(_floor, low + 1)
		print("WebPerf: 跑不動（%.0f FPS），畫質降到「%s」" % [_avg(_fps_hist), LEVEL_NAMES[low + 1]])
		_auto_set(low + 1)
	elif _fast_n >= FAST_FOR and low > _floor:
		print("WebPerf: 一直很順，畫質試著升到「%s」" % LEVEL_NAMES[low - 1])
		_auto_set(low - 1)

## 「自動」換等級：套用、存檔，換完先等幾秒再開始算
func _auto_set(level: int) -> void:
	low = clampi(level, AUTO_BEST, AUTO_WORST)
	_settle = SETTLE
	_reset_watch()
	_fps_hist.clear()
	_save_settings()
	_apply()

static func _avg(a: Array) -> float:
	if a.is_empty():
		return 0.0
	var s := 0.0
	for x in a:
		s += float(x)
	return s / a.size()

## 直接指定等級（0～3），不存檔（測試用）
func set_low(level: int) -> void:
	low = clampi(level, 0, 3)
	_apply()
