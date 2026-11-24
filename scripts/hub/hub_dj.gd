extends Node3D
## 家豪的 DJ 台（主島的「DJ 台」站點）：一座小舞台＋舞池＋燈光，家豪站在混音台後面當 DJ。
##
## 兩種玩法（站點按 Enter 開選單）：
##   1. 演出（三首歌）：音符從上面掉下來，按 D F J K（或 ← ↓ ↑ →）在音符碰到線的時候打出去。
##      你打出去的每個音都是旋律的一部分（打錯就少一個音）。人氣條越高，舞池的雞越多；
##      連擊 12 下進入 FEVER：燈光全開、破關後搬進農莊的居民也會跑來看。
##      結束給 D～S 評價，最高分和評價記在冒險手帳（journal.gd 的 [dj]）。
##   2. 自由混音：四個樂器（鼓、貝斯、和弦、雞叫）用 D F J K 開關，Space 是氣喇叭。
##      開越多觀眾越多，四個全開撐滿 10 秒有貼紙。
##
## 音樂全部用程式合成（跟 hub_sfx.gd 同一套小工具），所以所有歌都是 4 小節的循環。
## 時間用 dt 累加（不看音訊位置），所以可以重演、也可以在 headless 測試裡快轉。
##
## 主島（level_select.gd）蓋站點時呼叫 build_stage()；進入站點按 Enter 呼叫 begin()。

const Journal := preload("res://scripts/hub/journal.gd")
const Sfx := preload("res://scripts/hub/hub_sfx.gd")
const HubUI := preload("res://scripts/hub/hub_ui.gd")
const UIStyle := preload("res://scripts/ui/ui_style.gd")

const RATE := 22050
const LANES := 4
const APPROACH := 1.7              # 音符從出現到碰到線要幾秒
const PERFECT_W := 0.07            # 差多少秒內算 Perfect
const GOOD_W := 0.14               # 差多少秒內算 Good
const LEAD_BARS := 2               # 前奏幾小節
const FEVER_COMBO := 12
const CROWD_MAX := 10
const FACE_YAW := PI               # 家豪朝北（舞池那邊）

const LANE_COLORS := [Color("ef5350"), Color("ffca28"), Color("66bb6a"), Color("42a5f5")]
const LANE_KEYS := ["D", "F", "J", "K"]
const LANE_SEMI := [7, 9, 12, 16]                 # 四條軌道的音高（相對於調，五聲音階，跟和弦不會打架）
const CHORD_ROOTS := [0, -3, -7, -5]              # 四小節的和弦根音：C Am F G（相對於調）
const RANKS := ["", "D", "C", "B", "A", "S"]
const RANK_COLORS := [Color.GRAY, Color("9e9e9e"), Color("7cb342"), Color("29b6f6"), Color("ab47bc"), Color("ffb300")]
const LAYER_NAMES := ["鼓", "貝斯", "和弦", "雞叫"]

## 三首歌。pat：十六分音符的格子（一小節 16 格）
const SONGS := [
	{"name": "咕咕早安曲", "sub": "暖身　輕鬆", "bpm": 96, "key": 0, "bars": 14, "seed": 11, "dens": [0.85, 0.1],
		"kick": [0, 6, 8, 10], "snare": [4, 12], "hat": [0, 2, 4, 6, 8, 10, 12, 14], "bass": [0, 3, 6, 8, 11, 14], "stab": [2, 7, 10, 15], "cluck": false},
	{"name": "雞飛狗跳 Disco", "sub": "熱門　中等", "bpm": 118, "key": 2, "bars": 14, "seed": 27, "dens": [0.95, 0.4],
		"kick": [0, 4, 8, 12], "snare": [4, 12], "hat": [2, 6, 10, 14], "bass": [2, 3, 6, 7, 10, 11, 14, 15], "stab": [2, 6, 10, 14], "cluck": true},
	{"name": "破殼 EDM", "sub": "挑戰　很快", "bpm": 140, "key": 5, "bars": 14, "seed": 53, "dens": [1.0, 0.62],
		"kick": [0, 4, 8, 12], "snare": [4, 12], "hat": [1, 2, 3, 5, 6, 7, 9, 10, 11, 13, 14, 15], "bass": [0, 2, 3, 4, 6, 8, 10, 11, 12, 14], "stab": [3, 7, 11, 15], "cluck": false},
]
## 自由混音用的曲子（不是演出，沒有譜）
const JAM := {"name": "自由混音", "sub": "四個樂器隨便開", "bpm": 110, "key": 0, "bars": 0, "seed": 5, "dens": [0.0, 0.0],
	"kick": [0, 4, 8, 12], "snare": [4, 12], "hat": [2, 6, 10, 14], "bass": [0, 3, 6, 8, 11, 14], "stab": [2, 7, 10, 15], "cluck": true}

# 這些貼紙（journal.gd）要看的存檔都在 [dj]：plays、best_0..2（分數）、rank_0..2、fc、fever、guest；旗標 [flag] dj_jam

var map                         # 選關畫面
var active := false
var state := "off"              # off／menu／play／result／jam
var sel := 0                    # 選單選到哪一行（0..2 是歌，3 是自由混音）

var _stage: Node3D              # 舞台的根（跟著主島）
var _t := 0.0
var _snd := {}
var _bg := {}                   # 合成好的曲子：「s0」「s1」…（整首）、「j0..3」（混音四層）
var _leads := {}                # midi -> AudioStreamWAV
var _lead_pool: Array = []
var _lead_i := 0
var _music: AudioStreamPlayer
var _layers: Array = []
var _layer_on := [false, false, false, false]
var _layer: CanvasLayer
var _ui: HubUI.Canvas

# 演出
var song := 0
var _notes: Array = []
var _first := 0
var _clock := 0.0
var _end_t := 0.0
var _score := 0
var _combo := 0
var _max_combo := 0
var _counts := {"perfect": 0, "good": 0, "miss": 0}
var _hype := 0.0
var _fever := false
var _fever_t := 0.0
var _judge_txt := ""
var _judge_t := 9.0
var _judge_col := Color.WHITE
var _flash := [0.0, 0.0, 0.0, 0.0]
var _result := {}

# 混音
var _jam_clock := 0.0
var _all_on_t := 0.0
var _jam_done := false

# 舞台上的東西
var _tiles: Array = []
var _cones: Array = []
var _discs: Array = []
var _ball: Node3D
var _beams: Array = []
var _lights: Array = []
var _crowd: Array = []
var _guests: Array = []
var _banner: Label3D
var _beat := 0.0
var _energy := 0.15
var _hue := 0.0
var _hero_yaw_saved := 0.0
var _rects: Array = []          # 滑鼠可以點的框 [{rect, kind, idx}]

func _ready() -> void:
	_snd = Sfx.attach(self, -4.0)
	_music = AudioStreamPlayer.new()
	_music.volume_db = -3.0
	add_child(_music)
	for i in 4:
		var p := AudioStreamPlayer.new()
		p.volume_db = -80.0
		add_child(p)
		_layers.append(p)
	for i in 6:
		var p := AudioStreamPlayer.new()
		p.volume_db = -2.0
		add_child(p)
		_lead_pool.append(p)
	_layer = CanvasLayer.new()
	_layer.layer = 8
	_layer.visible = false
	add_child(_layer)
	_ui = HubUI.Canvas.new()
	_ui.painter = _paint
	_ui.on_click = _on_click
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(_ui)

# ---------------------------------------------------------------- 音樂合成

static func _hz(midi: float) -> float:
	return 440.0 * pow(2.0, (midi - 69.0) / 12.0)

static func _kick(buf: PackedFloat32Array, at: float, amp: float) -> void:
	var start := int(at * RATE)
	for j in int(0.3 * RATE):
		var i := start + j
		if i >= buf.size():
			break
		var t := float(j) / RATE
		var f := 46.0 + 120.0 * exp(-t * 30.0)
		buf[i] += sin(TAU * f * t) * exp(-t * 9.0) * amp

static func _bass(buf: PackedFloat32Array, at: float, midi: float, dur: float, amp: float) -> void:
	var f := _hz(midi)
	var start := int(at * RATE)
	for j in int(dur * RATE):
		var i := start + j
		if i >= buf.size():
			break
		var t := float(j) / RATE
		var env := minf(t / 0.008, 1.0) * exp(-t * 3.5 / dur)
		buf[i] += (sin(TAU * f * t) + 0.4 * sin(TAU * f * 2.0 * t) + 0.18 * sin(TAU * f * 3.0 * t)) * env * amp

## 家豪打出去的旋律音：亮一點的撥弦
static func _lead(midi: int) -> AudioStreamWAV:
	var s := Sfx._buf(0.5)
	var f := _hz(midi)
	for i in s.size():
		var t := float(i) / RATE
		var env := minf(t / 0.004, 1.0) * exp(-t * 7.0)
		s[i] = (sin(TAU * f * t) + 0.5 * sin(TAU * f * 2.0 * t) * exp(-t * 9.0) + 0.3 * sin(TAU * f * 3.0 * t) * exp(-t * 14.0)) * env * 0.5
	return Sfx._wav(s)

## 一層（drum／bass／chord／cluck）的 4 小節循環
static func _layer_buf(sg: Dictionary, which: String) -> PackedFloat32Array:
	var spb := 60.0 / float(sg.bpm)
	var sl := spb * 0.25                       # 一個十六分音符多長
	var s := Sfx._buf(spb * 16.0)
	var key := int(sg.key)
	for bar in 4:
		var t0 := bar * 4.0 * spb
		var root := 36 + key + int(CHORD_ROOTS[bar])
		var minor := bar == 1
		match which:
			"drum":
				for k in sg.kick:
					_kick(s, t0 + int(k) * sl, 0.85)
				for k in sg.snare:
					Sfx._noise(s, t0 + int(k) * sl, 0.18, 0.55, 0.55, 7.0)
					Sfx._sweep(s, t0 + int(k) * sl, 0.1, 260.0, 170.0, 0.18)
				for k in sg.hat:
					Sfx._noise(s, t0 + int(k) * sl, 0.045, 0.2, 0.95, 9.0)
			"bass":
				var n := 0
				for k in sg.bass:
					var up := 12 if n % 3 == 2 else 0
					_bass(s, t0 + int(k) * sl, float(root + up), sl * 1.8, 0.5)
					n += 1
			"chord":
				var third := 3 if minor else 4
				for k in sg.stab:
					for iv in [0, third, 7]:
						Sfx._bell(s, t0 + int(k) * sl, root + 24 + int(iv), 0.5, 0.11)
			"cluck":
				for k in [3, 11]:
					Sfx._sweep(s, t0 + k * sl, 0.09, 640.0, 380.0, 0.3, 0.06)
					Sfx._sweep(s, t0 + (k + 1.5) * sl, 0.11, 700.0, 340.0, 0.3, 0.08)
	return s

func _wav_loop(buf: PackedFloat32Array) -> AudioStreamWAV:
	var w := Sfx._wav(buf)
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = buf.size()
	return w

## 整首歌的伴奏（鼓＋貝斯＋和弦，第二首再加雞叫）
func _song_stream(i: int) -> AudioStreamWAV:
	var id := "s%d" % i
	if not _bg.has(id):
		var sg: Dictionary = SONGS[i]
		var buf: PackedFloat32Array = _layer_buf(sg, "drum")
		var parts := ["bass", "chord"] + (["cluck"] if bool(sg.cluck) else [])
		for p in parts:
			var b2: PackedFloat32Array = _layer_buf(sg, String(p))
			for j in mini(buf.size(), b2.size()):
				buf[j] += b2[j]
		_bg[id] = _wav_loop(buf)
	return _bg[id]

func _jam_stream(l: int) -> AudioStreamWAV:
	var id := "j%d" % l
	if not _bg.has(id):
		_bg[id] = _wav_loop(_layer_buf(JAM, ["drum", "bass", "chord", "cluck"][l]))
	return _bg[id]

## 打出一個旋律音
func _lead_play(midi: int, db := -2.0) -> void:
	if not _leads.has(midi):
		_leads[midi] = _lead(midi)
	var p: AudioStreamPlayer = _lead_pool[_lead_i % _lead_pool.size()]
	_lead_i += 1
	p.stream = _leads[midi]
	p.volume_db = db
	p.play()

func _play(id: String, pitch := 1.0) -> void:
	var p: AudioStreamPlayer = _snd.get(id)
	if p:
		p.pitch_scale = pitch
		p.play()

# ---------------------------------------------------------------- 譜

## 這首歌的譜：[{t, lane, midi, done, res}]，只看歌的編號，每次都一樣
static func make_chart(si: int) -> Array:
	var sg: Dictionary = SONGS[si]
	var rng := RandomNumberGenerator.new()
	rng.seed = int(sg.seed)
	var spb := 60.0 / float(sg.bpm)
	var notes: Array = []
	var lane := 1
	var last_slot := -9
	for bar in range(LEAD_BARS, LEAD_BARS + int(sg.bars)):
		for slot in 8:
			var p := float(sg.dens[0]) if slot % 2 == 0 else float(sg.dens[1])
			if slot == 0:
				p = 1.0
			if slot - last_slot == 1 and slot % 2 == 1 and rng.randf() < 0.35:
				p = 0.0                                          # 不要太多連續的八分音符
			if rng.randf() >= p:
				continue
			var step := rng.randi_range(-1, 1)
			lane = clampi(lane + step, 0, LANES - 1)
			if step == 0 and rng.randf() < 0.6:
				lane = rng.randi_range(0, LANES - 1)
			last_slot = slot
			notes.append({"t": (bar * 4.0 + slot * 0.5) * spb, "lane": lane, "midi": 60 + int(sg.key) + int(LANE_SEMI[lane]), "done": false, "res": ""})
	return notes

# ---------------------------------------------------------------- 蓋舞台

func _mat(col: Color, rough := 0.7, metal := 0.0, emit := Color(0, 0, 0, 0), emit_e := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	m.metallic = metal
	if emit.a > 0.0:
		m.emission_enabled = true
		m.emission = emit
		m.emission_energy_multiplier = emit_e
	return m

func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi

func _cyl(parent: Node3D, r: float, h: float, pos: Vector3, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = h
	cm.radial_segments = 24
	mi.mesh = cm
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi

const STAGE_SCALE := 0.8        # 整座舞台縮小一點，才放得進空地
const BOOTH := Vector3(0, 0.0, 5.0)   # 家豪站的地方（舞台座標：混音台南邊）

var _prompt: Label3D

## 在 root（主島的節點）的 pos 位置蓋舞台（pos 是島座標）；家豪當 DJ 的位置在混音台南邊。z 越小越北
func build_stage(root: Node3D, pos: Vector3) -> void:
	_stage = Node3D.new()
	_stage.name = "DjStage"
	_stage.position = pos
	_stage.scale = Vector3.ONE * STAGE_SCALE
	root.add_child(_stage)
	# 家豪站的地方：一圈紫色的地墊（跟站點的圓台同一種感覺）
	var ring := _cyl(_stage, 1.5, 0.06, BOOTH + Vector3(0, 0.03, 0), _mat(Color("a04fd0"), 0.5, 0.0, Color("a04fd0"), 0.5))
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_prompt = Label3D.new()
	_prompt.text = "按 E 當 DJ"
	_prompt.font = UIStyle.font()
	_prompt.font_size = 64
	_prompt.pixel_size = 0.014
	_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_prompt.no_depth_test = true
	_prompt.shaded = false
	_prompt.modulate = Color(1.6, 1.2, 2.2)
	_prompt.outline_size = 16
	_prompt.outline_modulate = Color(0.2, 0.1, 0.3)
	_prompt.render_priority = 10
	_prompt.outline_render_priority = 9
	_prompt.position = Vector3(0, 2.6, 3.1)
	_prompt.visible = false
	_stage.add_child(_prompt)
	var dark := _mat(Color("2a2233"), 0.55)
	var wood := _mat(Color("8b5a2b"), 0.85)
	# 舞池：5 × 3 格會發光的地磚（一格一個材質，tick 裡換顏色）
	for iz in 3:
		for ix in 5:
			var tm := _mat(Color("1d1a26"), 0.35, 0.0, Color.WHITE, 0.3)
			var tile := _box(_stage, Vector3(1.86, 0.06, 1.86), Vector3((ix - 2) * 1.95, 0.03, 1.0 - iz * 1.95), tm)
			tile.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_tiles.append({"mat": tm, "ix": ix, "iz": iz})
	# 混音台：木桌＋兩張唱盤＋混音器
	var desk := Node3D.new()
	desk.position = Vector3(0, 0, 3.1)
	_stage.add_child(desk)
	_box(desk, Vector3(3.4, 0.95, 1.1), Vector3(0, 0.475, 0), wood)
	_box(desk, Vector3(3.6, 0.1, 1.3), Vector3(0, 0.98, 0), dark)
	for sx in [-1.0, 1.0]:
		_cyl(desk, 0.46, 0.05, Vector3(sx * 1.0, 1.06, 0.0), _mat(Color("15131b"), 0.3, 0.4))
		var lab := _cyl(desk, 0.16, 0.06, Vector3(sx * 1.0, 1.09, 0.0), _mat(Color("ff7ab8") if sx < 0 else Color("6ad6ff"), 0.5, 0.0, Color("ff7ab8") if sx < 0 else Color("6ad6ff"), 0.6))
		_discs.append({"node": lab, "speed": 3.0 * sx, "base": lab.position})
	_box(desk, Vector3(0.8, 0.16, 0.7), Vector3(0, 1.09, 0), _mat(Color("3a3448"), 0.4, 0.3))
	for i in 5:
		var knob := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.05
		sm.height = 0.1
		knob.mesh = sm
		knob.material_override = _mat(LANE_COLORS[i % 4], 0.4, 0.0, LANE_COLORS[i % 4], 0.8)
		knob.position = Vector3(-0.28 + i * 0.14, 1.2, 0.18)
		desk.add_child(knob)
	# 喇叭：兩座，前面兩顆會跟著鼓點彈的喇叭盆
	for sx in [-6.4, 6.4]:
		var sp := Node3D.new()
		sp.position = Vector3(sx, 0, -2.2)
		_stage.add_child(sp)
		_box(sp, Vector3(1.5, 2.8, 1.2), Vector3(0, 1.4, 0), dark)
		for cy in [0.8, 2.0]:
			var cone := _cyl(sp, 0.46 if cy < 1.0 else 0.3, 0.16, Vector3(0, cy, 0.62), _mat(Color("55506a"), 0.5, 0.3), Vector3(PI * 0.5, 0, 0))
			_cones.append({"node": cone, "big": cy < 1.0})
		map._hub_blocks.append([sp, 1.1, Vector3.ZERO, 0.0])
	map._hub_blocks.append([desk, 0.9, Vector3.ZERO, 0.0])
	map._life.register("dj", desk, 2.2, 1.0)             # 戳混音台（點滑鼠或按 E）就開演
	# 燈架：兩根柱子＋橫樑＋招牌，橫樑下面掛四盞會掃的燈
	for sx in [-6.4, 6.4]:
		_cyl(_stage, 0.12, 6.4, Vector3(sx * 0.93, 3.2, -6.2), dark)
	_box(_stage, Vector3(12.6, 0.18, 0.18), Vector3(0, 6.4, -6.2), dark)
	_box(_stage, Vector3(0.14, 0.14, 3.9), Vector3(0, 6.4, -4.2), dark)
	_banner = Label3D.new()
	_banner.text = "家豪 DJ 台"
	_banner.font = UIStyle.font()
	_banner.font_size = 160
	_banner.pixel_size = 0.0105
	_banner.shaded = false
	_banner.alpha_cut = Label3D.ALPHA_CUT_OPAQUE_PREPASS      # 不然會被後面半透明的光束蓋掉一半
	_banner.double_sided = true
	_banner.modulate = Color(1.0, 0.7, 1.9)
	_banner.outline_size = 20
	_banner.outline_modulate = Color(0.1, 0.05, 0.2)
	_banner.position = Vector3(0, 5.3, -6.0)
	_stage.add_child(_banner)
	var bm := StandardMaterial3D.new()
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	bm.cull_mode = BaseMaterial3D.CULL_DISABLED
	for i in 4:
		var pv := Node3D.new()
		pv.position = Vector3(-4.5 + i * 3.0, 6.3, -6.0)
		_stage.add_child(pv)
		var cm := CylinderMesh.new()
		cm.top_radius = 0.04
		cm.bottom_radius = 1.0
		cm.height = 8.0
		cm.radial_segments = 20
		var mi := MeshInstance3D.new()
		mi.mesh = cm
		var mm := bm.duplicate() as StandardMaterial3D
		mm.albedo_color = Color(LANE_COLORS[i], 0.1)
		mi.material_override = mm
		mi.position = Vector3(0, -4.0, 0)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pv.add_child(mi)
		_beams.append({"pivot": pv, "mat": mm, "i": i})
	# 舞廳球：從吊臂垂下來
	_cyl(_stage, 0.025, 1.4, Vector3(0, 5.7, -2.5), dark)
	_ball = Node3D.new()
	_ball.position = Vector3(0, 4.7, -2.5)
	_stage.add_child(_ball)
	var sph := MeshInstance3D.new()
	var sm2 := SphereMesh.new()
	sm2.radius = 0.62
	sm2.height = 1.24
	sm2.radial_segments = 14
	sm2.rings = 8
	sph.mesh = sm2
	sph.material_override = _mat(Color("c9ccd8"), 0.12, 0.95, Color("8e9bd0"), 0.35)
	_ball.add_child(sph)
	# 兩盞彩色的小燈（照亮舞池）
	for sx in [-3.0, 3.0]:
		var ol := OmniLight3D.new()
		ol.position = Vector3(sx, 3.2, -1.5)
		ol.omni_range = 9.0
		ol.light_energy = 0.0
		ol.shadow_enabled = false
		_stage.add_child(ol)
		_lights.append(ol)

# ---------------------------------------------------------------- 進出

## 家豪當 DJ 站的地方（世界座標）
func booth_pos() -> Vector3:
	return _stage.to_global(BOOTH)

## 家豪離混音台夠近嗎（會冒出「按 E」的提示）
func near(p: Vector3) -> bool:
	var b := booth_pos()
	return Vector2(p.x - b.x, p.z - b.z).length() < 6.0

func begin() -> bool:
	if _stage == null or active or not map._free_hub() and not map._is_hub(map.selected):
		return false
	active = true
	if map._free_hub():
		# 家豪走到混音台後面（滑鼠點混音台、離得遠也一樣）
		var b := booth_pos()
		b.y = (map._hero as Node3D).position.y
		map._free.pos = b
		(map._hero as Node3D).position = b
	_layer.visible = true
	_ui.mouse_filter = Control.MOUSE_FILTER_STOP
	state = "menu"
	sel = clampi(sel, 0, SONGS.size())
	_hero_yaw_saved = map._face_yaw
	map._face_yaw = FACE_YAW
	map._cam_bias_to = Vector3(3.0, 1.0, -3.5)
	_prompt.visible = false
	(map._snd["bgm"] as AudioStreamPlayer).volume_db = -80.0
	_make_crowd()
	_play("page")
	return true

func end() -> void:
	if not active:
		return
	_stop_music()
	active = false
	state = "off"
	_layer.visible = false
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map._face_yaw = 0.0
	map._cam_bias_to = Vector3.ZERO
	(map._snd["bgm"] as AudioStreamPlayer).volume_db = map.BGM_DB
	_set_crowd_target(0, false)
	map._journal_check()
	_ui.queue_redraw()

func _stop_music() -> void:
	_music.stop()
	for p in _layers:
		(p as AudioStreamPlayer).stop()
		(p as AudioStreamPlayer).volume_db = -80.0
	_layer_on = [false, false, false, false]

func to_menu() -> void:
	_stop_music()
	state = "menu"
	_hype = 0.0
	_fever = false
	_set_crowd_target(0, false)
	_play("page")

# ---------------------------------------------------------------- 開始演出／混音

func start_song(i: int) -> void:
	song = clampi(i, 0, SONGS.size() - 1)
	_notes = make_chart(song)
	_first = 0
	_clock = 0.0
	var sg: Dictionary = SONGS[song]
	_end_t = float((_notes[_notes.size() - 1] as Dictionary).t) + 60.0 / float(sg.bpm) * 4.0
	_score = 0
	_combo = 0
	_max_combo = 0
	_counts = {"perfect": 0, "good": 0, "miss": 0}
	_hype = 8.0
	_fever = false
	_fever_t = 0.0
	_judge_t = 9.0
	_result = {}
	state = "play"
	_music.stream = _song_stream(song)
	_music.play()
	_play("tick")

func start_jam() -> void:
	state = "jam"
	_jam_clock = 0.0
	_all_on_t = 0.0
	_jam_done = Journal.has("flag", "dj_jam")
	_layer_on = [true, false, false, false]
	for l in 4:
		var p: AudioStreamPlayer = _layers[l]
		p.stream = _jam_stream(l)
		p.volume_db = 0.0 if _layer_on[l] else -80.0
		p.play()
	_sync_jam_crowd()
	_play("tick")

func toggle_layer(l: int) -> void:
	if state != "jam":
		return
	_layer_on[l] = not _layer_on[l]
	(_layers[l] as AudioStreamPlayer).volume_db = 0.0 if _layer_on[l] else -80.0
	_play("pop", 0.9 + l * 0.15)
	_flash[l] = 0.2
	_sync_jam_crowd()

func _sync_jam_crowd() -> void:
	var cnt := 0
	for b in _layer_on:
		if b:
			cnt += 1
	_set_crowd_target([0, 3, 5, 8, CROWD_MAX][cnt], cnt == 4)

func air_horn() -> void:
	_play("horn", 1.3)
	_flash = [0.25, 0.25, 0.25, 0.25]
	_pulse_extra = 1.0
	map._life.puff(_stage.global_position + Vector3(0, 2.0, -2.0), Color("ffe27a"), 18, 6.0, 0.3, -4.0, 1.2, 1.0, 2.0)

var _pulse_extra := 0.0

# ---------------------------------------------------------------- 輸入

func _unhandled_input(ev: InputEvent) -> void:
	if not active:
		return
	if ev is InputEventKey and ev.pressed and not ev.echo:
		var k: int = ev.keycode
		if k == KEY_V:
			return
		key_down(k)
		get_viewport().set_input_as_handled()
	elif ev is InputEventMouseButton and ev.pressed:
		get_viewport().set_input_as_handled()

func _lane_of(k: int) -> int:
	match k:
		KEY_D, KEY_LEFT:
			return 0
		KEY_F, KEY_DOWN:
			return 1
		KEY_J, KEY_UP:
			return 2
		KEY_K, KEY_RIGHT:
			return 3
	return -1

func key_down(k: int) -> void:
	var lane := _lane_of(k)
	match state:
		"menu":
			if k == KEY_ESCAPE or k == KEY_BACKSPACE:
				end()
			elif k == KEY_UP or k == KEY_W:
				sel = (sel + SONGS.size()) % (SONGS.size() + 1)
				_play("tick")
			elif k == KEY_DOWN or k == KEY_S:
				sel = (sel + 1) % (SONGS.size() + 1)
				_play("tick")
			elif k == KEY_ENTER or k == KEY_KP_ENTER or k == KEY_SPACE:
				_choose()
		"play":
			if k == KEY_ESCAPE or k == KEY_BACKSPACE:
				to_menu()
			elif lane >= 0:
				press_lane(lane)
		"result":
			if k == KEY_ESCAPE or k == KEY_BACKSPACE:
				to_menu()
			elif k == KEY_ENTER or k == KEY_KP_ENTER or k == KEY_SPACE:
				start_song(song)
		"jam":
			if k == KEY_ESCAPE or k == KEY_BACKSPACE:
				to_menu()
			elif k == KEY_SPACE:
				air_horn()
			elif lane >= 0:
				toggle_layer(lane)
	_ui.queue_redraw()

func _choose() -> void:
	if sel >= SONGS.size():
		start_jam()
	else:
		start_song(sel)

func _on_click(pos: Vector2) -> void:
	for r in _rects:
		if (r.rect as Rect2).has_point(pos):
			match String(r.kind):
				"row":
					sel = int(r.idx)
					_choose()
				"pad":
					toggle_layer(int(r.idx))
				"close":
					key_down(KEY_ESCAPE)
				"again":
					key_down(KEY_ENTER)
			_ui.queue_redraw()
			return

# ---------------------------------------------------------------- 打節奏

## 按下第 lane 條軌道：找最近、還沒打的音符
func press_lane(lane: int) -> void:
	if state != "play":
		return
	_flash[lane] = 0.16
	var best := -1
	var bd := 9.0
	for i in range(_first, _notes.size()):
		var nd: Dictionary = _notes[i]
		if float(nd.t) > _clock + 0.3:
			break
		if bool(nd.done) or int(nd.lane) != lane:
			continue
		var d := absf(float(nd.t) - _clock)
		if d < bd:
			bd = d
			best = i
	if best < 0 or bd > GOOD_W:
		_play("tick", 0.6)                       # 空按：悶悶的一下，不扣分
		return
	var nd2: Dictionary = _notes[best]
	nd2.done = true
	var res := "perfect" if bd <= PERFECT_W else "good"
	nd2.res = res
	_lead_play(int(nd2.midi))
	_judge(res)

func _judge(res: String) -> void:
	_counts[res] = int(_counts[res]) + 1
	match res:
		"perfect":
			_combo += 1
			_score += int(100.0 * (1.0 + minf(_combo, 40) / 40.0))
			_hype = minf(_hype + 4.0, 100.0)
			_judge_txt = "Perfect!"
			_judge_col = Color("ffd54f")
		"good":
			_combo += 1
			_score += int(60.0 * (1.0 + minf(_combo, 40) / 40.0))
			_hype = minf(_hype + 2.5, 100.0)
			_judge_txt = "Good"
			_judge_col = Color("81d4fa")
		_:
			_combo = 0
			_hype = maxf(_hype - 9.0, 0.0)
			_judge_txt = "Miss"
			_judge_col = Color("e57373")
			if _fever:
				_fever = false
			_play("miss", 1.4)
	_judge_t = 0.0
	_max_combo = maxi(_max_combo, _combo)
	if res != "miss" and not _fever and _combo >= FEVER_COMBO:
		_start_fever()
	_set_crowd_target(int(round(_hype / 100.0 * CROWD_MAX)), _fever)

func _start_fever() -> void:
	_fever = true
	_fever_t = 0.0
	Journal.add("dj", "fever")
	_play("gold")
	_pulse_extra = 1.0
	map._life.say(_stage.global_position + Vector3(0, 4.2, 0.5), "FEVER！", Color("ff8ae0"), 72)
	map._life.puff(_stage.global_position + Vector3(0, 3.5, -1.0), Color("ff8ae0"), 26, 6.5, 0.34, -4.0, 1.4, 1.0, 2.6)
	if _show_guests():
		Journal.add("dj", "guest")

func _finish() -> void:
	var total: int = int(_counts.perfect) + int(_counts.good) + int(_counts.miss)
	var acc := (float(_counts.perfect) + 0.6 * float(_counts.good)) / maxf(total, 1.0)
	var rank := 1
	if acc >= 0.9:
		rank = 5
	elif acc >= 0.75:
		rank = 4
	elif acc >= 0.55:
		rank = 3
	elif acc >= 0.3:
		rank = 2
	var fc := int(_counts.miss) == 0
	var new_best := _score > Journal.n("dj", "best_%d" % song)
	Journal.set_max("dj", "best_%d" % song, _score)
	Journal.set_max("dj", "rank_%d" % song, rank)
	Journal.add("dj", "plays")
	if fc:
		Journal.add("dj", "fc")
	_result = {"rank": rank, "acc": acc, "fc": fc, "new": new_best, "score": _score, "max_combo": _max_combo}
	state = "result"
	_music.stop()
	_play("catch" if rank >= 3 else "pop")
	if rank >= 4:
		map._life.puff(_stage.global_position + Vector3(0, 3.0, -1.0), RANK_COLORS[rank], 30, 7.0, 0.36, -4.0, 1.5, 1.0, 2.8)
	_set_crowd_target(CROWD_MAX if rank >= 4 else 4, rank >= 5)
	map._journal_check()

# ---------------------------------------------------------------- 觀眾

func _make_crowd() -> void:
	if not _crowd.is_empty() or _stage == null:
		return
	var spots: Array = [Vector2(0, -0.1), Vector2(-1.95, 0.1), Vector2(1.95, 0.1), Vector2(-3.9, 0.0), Vector2(3.9, 0.0),
		Vector2(-0.9, -2.0), Vector2(1.0, -2.0), Vector2(-2.9, -2.1), Vector2(2.9, -2.1), Vector2(0.0, -3.7)]
	for i in CROWD_MAX:
		var hen: Node3D = map._life._make_hen(1.05 + 0.12 * sin(i * 2.3))
		hen.reparent(_stage, false)
		var sp: Vector2 = spots[i]
		var base := Vector3(sp.x, 0.06, sp.y)
		hen.position = base
		hen.visible = false
		hen.scale = Vector3.ZERO
		_crowd.append({"node": hen, "base": base, "ph": i * 0.37, "vis": 0.0, "want": 0.0, "yaw": 0.0})

## 現在要幾隻觀眾（0..CROWD_MAX）；guests：是不是要請居民也來
func _set_crowd_target(n: int, guests: bool) -> void:
	for i in _crowd.size():
		(_crowd[i] as Dictionary).want = 1.0 if i < n else 0.0
	for g in _guests:
		(g as Dictionary).want = 1.0 if (guests and n > 0) else 0.0
	if guests and n > 0:
		_show_guests()

## 破關搬進農莊的居民跑來看演出。回傳有沒有人來
func _show_guests() -> bool:
	if _guests.is_empty():
		var growth = map._growth
		var xs := [-5.1, 5.1, -6.0, 6.0, -4.4]
		var n := 0
		for id in growth.ids():
			if not growth.has_grown(String(id)):
				continue
			var sp: Dictionary = growth.SPECS[id]
			var rs: Dictionary = sp.res
			var node: Node3D
			var x: float = xs[n % xs.size()]
			var pos := Vector3(x, 0.05, 1.6 - float(n / 2) * 1.8)
			if rs.has("hen"):
				node = map._life._make_hen(float(rs.hen))
				node.reparent(_stage, false)
				node.position = pos
			else:
				node = map._spawn_fit(_stage, String(rs.model), pos, float(rs.size), 0.0)
			if node == null:
				continue
			node.visible = false
			node.scale = Vector3.ZERO
			_guests.append({"node": node, "base": pos, "ph": 0.2 + n * 0.31, "vis": 0.0, "want": 1.0, "yaw": 0.0, "id": String(id)})
			n += 1
	for g in _guests:
		(g as Dictionary).want = 1.0
	return not _guests.is_empty()

# ---------------------------------------------------------------- 每一格

func tick(dt: float, t: float) -> void:
	_t = t
	if _stage == null:
		return
	var spb := 60.0 / (float(SONGS[song].bpm) if state != "jam" else float(JAM.bpm))
	match state:
		"play":
			_clock += dt
			for i in range(_first, _notes.size()):
				var nd: Dictionary = _notes[i]
				if float(nd.t) + GOOD_W >= _clock:
					break
				if not bool(nd.done):
					nd.done = true
					nd.res = "miss"
					_judge("miss")
			while _first < _notes.size() and bool((_notes[_first] as Dictionary).done):
				_first += 1
			if _fever:
				_fever_t += dt
			_hype = maxf(_hype - dt * 0.6, 0.0)
			if _clock >= _end_t:
				_finish()
			_beat = _clock / spb
		"jam":
			_jam_clock += dt
			var all_on: bool = _layer_on[0] and _layer_on[1] and _layer_on[2] and _layer_on[3]
			_all_on_t = _all_on_t + dt if all_on else 0.0
			if all_on and _all_on_t >= 10.0 and not _jam_done:
				_jam_done = true
				Journal.mark("flag", "dj_jam")
				_play("gold")
				map._life.say(_stage.global_position + Vector3(0, 4.2, 0.5), "混音大師！", Color("ff8ae0"), 66)
				map._journal_check()
			_beat = _jam_clock / spb
		_:
			_beat = t * 1.6
	if _prompt != null:
		_prompt.visible = not active and near((map._hero as Node3D).global_position) and map._is_hub(map.selected) and not map._busy()
		_prompt.scale = Vector3.ONE * (1.0 + 0.06 * sin(t * 5.0))
	_judge_t += dt
	for i in 4:
		_flash[i] = maxf(float(_flash[i]) - dt, 0.0)
	_pulse_extra = maxf(_pulse_extra - dt * 2.5, 0.0)
	_visuals(dt)
	if active:
		_ui.queue_redraw()

func _target_energy() -> float:
	match state:
		"play":
			return clampf(_hype / 100.0 * 0.8 + (0.35 if _fever else 0.0), 0.1, 1.0)
		"jam":
			var n := 0
			for b in _layer_on:
				if b:
					n += 1
			return 0.2 + n * 0.2
		"result":
			return 0.7
	return 0.15

func _visuals(dt: float) -> void:
	_energy = lerpf(_energy, _target_energy(), 1.0 - exp(-dt * 3.0))
	var bf := fmod(_beat, 1.0)
	var pulse := maxf(exp(-bf * 5.0), _pulse_extra)
	_hue = fmod(_hue + dt * (0.04 + _energy * 0.25), 1.0)
	# 地磚
	var bi := int(floor(_beat))
	for tl in _tiles:
		var ix: int = tl.ix
		var iz: int = tl.iz
		var col := Color.from_hsv(fmod(_hue + ix * 0.09 + iz * 0.16, 1.0), 0.8, 1.0)
		var checker := (ix + iz + bi) % 2 == 0
		var e := 0.18 + _energy * 0.5 + pulse * (0.9 if checker else 0.25) * (0.3 + _energy)
		var m: StandardMaterial3D = tl.mat
		m.emission = col
		m.emission_energy_multiplier = e
		m.albedo_color = col.darkened(0.7)
	# 喇叭盆、唱盤、舞廳球
	for c in _cones:
		var s := 1.0 + pulse * (0.22 if bool(c.big) else 0.12) * (0.3 + _energy)
		(c.node as Node3D).scale = Vector3(s, 1.0, s)
	for d in _discs:
		(d.node as Node3D).rotation.y += dt * float(d.speed) * (0.3 + _energy * 2.0)
	_ball.rotation.y += dt * (0.4 + _energy * 2.2)
	# 光束：掃來掃去，越嗨越亮
	for b in _beams:
		var i: int = b.i
		var pv: Node3D = b.pivot
		var amp := 0.25 + _energy * 0.6
		pv.rotation.z = sin(_t * (0.8 + _energy) + i * 1.7) * amp
		pv.rotation.x = cos(_t * (0.6 + _energy * 0.7) + i * 2.3) * amp * 0.7
		var mm: StandardMaterial3D = b.mat
		mm.albedo_color = Color(Color.from_hsv(fmod(_hue + i * 0.25, 1.0), 0.7, 1.0), 0.04 + _energy * 0.12 + pulse * 0.05)
	for i in _lights.size():
		var ol: OmniLight3D = _lights[i]
		ol.light_color = Color.from_hsv(fmod(_hue + i * 0.5, 1.0), 0.7, 1.0)
		ol.light_energy = (0.2 + _energy * 1.6) * (0.6 + 0.4 * pulse) if (active or _energy > 0.2) else 0.0
	_banner.modulate = Color.from_hsv(fmod(_hue + 0.7, 1.0), 0.45, 1.0) * Color(1.4, 1.4, 1.4, 1.0) if _energy > 0.2 else Color(1.0, 0.7, 1.9)
	# 觀眾和貴賓：跟著拍子跳
	for grp in [_crowd, _guests]:
		for c in grp:
			var cd: Dictionary = c
			cd.vis = move_toward(float(cd.vis), float(cd.want), dt * 3.0)
			var nd: Node3D = cd.node
			var v := float(cd.vis)
			nd.visible = v > 0.02
			if not nd.visible:
				continue
			nd.scale = Vector3.ONE * (v * (1.0 + 0.2 * (1.0 - v)))
			var ph := _beat + float(cd.ph)
			var hop := absf(sin(ph * PI)) * (0.18 + 0.5 * _energy) * (1.4 if _fever else 1.0)
			nd.position = (cd.base as Vector3) + Vector3(0, hop, 0)
			var yaw := sin(ph * PI * 0.5) * 0.45
			if _fever:
				yaw += (_fever_t * 3.0 if int(float(cd.ph) * 100.0) % 2 == 0 else 0.0)
			nd.rotation.y = lerp_angle(nd.rotation.y, yaw, 1.0 - exp(-dt * 8.0))

# ---------------------------------------------------------------- 測試用

## 快轉演完一首歌（測試用）。skill：1.0 = 每個音都打準；0.5 = 隔一個打一個；0 = 完全不按。回傳結果
func sim_song(i: int, skill := 1.0) -> Dictionary:
	if not active:
		begin()
	start_song(i)
	var dt := 1.0 / 60.0
	var guard := 0
	var n := 0
	while state == "play" and guard < 30000:
		guard += 1
		if skill > 0.0:
			for j in range(_first, _notes.size()):
				var nd: Dictionary = _notes[j]
				if float(nd.t) > _clock + dt:
					break
				if not bool(nd.done) and absf(float(nd.t) - _clock) <= dt * 0.5:
					n += 1
					if skill >= 1.0 or n % 2 == 0:
						press_lane(int(nd.lane))
		tick(dt, _t + dt)
	return _result

# ---------------------------------------------------------------- 畫面

func _paint(c: Control) -> void:
	if not active:
		return
	_rects.clear()
	var vs := c.size
	var u := HubUI.scale_of(vs)
	match state:
		"menu":
			_paint_menu(c, u, vs)
		"play":
			_paint_play(c, u, vs)
		"result":
			_paint_play(c, u, vs)
			_paint_result(c, u, vs)
		"jam":
			_paint_jam(c, u, vs)

func _rank_text(i: int) -> String:
	var r := Journal.n("dj", "rank_%d" % i)
	return RANKS[r] if r > 0 else "－"

func _paint_menu(c: Control, u: float, vs: Vector2) -> void:
	var pr := Rect2(vs * 0.5 - Vector2(470, 330) * u + Vector2(0, 20) * u, Vector2(940, 640) * u)
	c.draw_style_box(HubUI.box(Color(HubUI.PAPER, 0.97), HubUI.PAPER_EDGE, 34 * u, 4.0), pr)
	HubUI.tag(c, Vector2(pr.get_center().x, pr.position.y + 8 * u), "家豪的 DJ 台", 40 * u, Color("a04fd0"), Color("5e2a82"), -0.03)
	var items := SONGS.size() + 1
	for i in items:
		var rr := Rect2(pr.position + Vector2(40, 68 + i * 116) * u, Vector2(pr.size.x - 80 * u, 104 * u))
		_rects.append({"rect": rr, "kind": "row", "idx": i})
		var on := i == sel
		c.draw_style_box(HubUI.box(Color("f4e6ff") if on else Color("fffdf4"), Color("a04fd0") if on else HubUI.PAPER_EDGE, 24 * u, 4.0 if on else 3.0, on), rr)
		var ic := rr.position + Vector2(64, 52) * u
		var hue := Color.from_hsv(fmod(0.78 + i * 0.13, 1.0), 0.55, 0.95)
		HubUI.vinyl(c, ic, 40 * u, hue, _t * (1.5 if on else 0.0))
		var nm: String = String(SONGS[i].name) if i < SONGS.size() else String(JAM.name)
		var sb: String = String(SONGS[i].sub) if i < SONGS.size() else String(JAM.sub)
		HubUI.text(c, rr.position + Vector2(128, 46) * u, nm, HubUI.fit(nm, 38 * u, rr.size.x - 128 * u - 220 * u), HubUI.INK)
		HubUI.text(c, rr.position + Vector2(130, 84) * u, sb, 24 * u, Color("7a6a5a"))
		if i < SONGS.size():
			var rk := Journal.n("dj", "rank_%d" % i)
			var bc := rr.position + Vector2(rr.size.x - 70 * u, 52 * u)
			c.draw_circle(bc, 36 * u, Color.WHITE)
			c.draw_circle(bc, 31 * u, RANK_COLORS[rk])
			HubUI.text_c(c, bc + Vector2(0, -2) * u, _rank_text(i), 38 * u, Color.WHITE)
			var best := Journal.n("dj", "best_%d" % i)
			if best > 0:
				HubUI.text(c, rr.position + Vector2(rr.size.x - 260 * u, 90 * u), "最高 %d" % best, 22 * u, Color("7a6a5a"), 160 * u, HORIZONTAL_ALIGNMENT_RIGHT)
		else:
			HubUI.text(c, rr.position + Vector2(rr.size.x - 250 * u, 62 * u), "D F J K 開關樂器", 24 * u, Color("a04fd0"), 200 * u, HORIZONTAL_ALIGNMENT_RIGHT)
	HubUI.key_strip(c, u, [[["↑", "↓"], "選歌"], [["Enter"], "開演"], [["Esc"], "離開"]])

# 高速公路的位置
func _hwy(u: float, vs: Vector2) -> Rect2:
	return Rect2(Vector2(vs.x - 480 * u, 50 * u), Vector2(420 * u, 780 * u))

func _paint_play(c: Control, u: float, vs: Vector2) -> void:
	var hw := _hwy(u, vs)
	c.draw_style_box(HubUI.box(Color(0.1, 0.07, 0.16, 0.86), Color("a04fd0"), 26 * u, 4.0), hw)
	var lw := (hw.size.x - 30 * u) / LANES
	var hit_y := hw.position.y + 610 * u
	var travel := 570.0 * u
	for l in LANES:
		var lx := hw.position.x + 15 * u + l * lw
		var lr := Rect2(Vector2(lx + 3 * u, hw.position.y + 16 * u), Vector2(lw - 6 * u, hw.size.y - 130 * u))
		c.draw_rect(lr, Color(LANE_COLORS[l], 0.1 + 0.35 * float(_flash[l]) / 0.16))
	c.draw_line(Vector2(hw.position.x + 12 * u, hit_y), Vector2(hw.end.x - 12 * u, hit_y), Color(1, 1, 1, 0.9), 5 * u)
	# 音符
	for i in range(_first, _notes.size()):
		var nd: Dictionary = _notes[i]
		var dtm := float(nd.t) - _clock
		if dtm > APPROACH:
			break
		if bool(nd.done) and String(nd.res) != "miss":
			continue
		var y := hit_y - dtm / APPROACH * travel
		if y < hw.position.y + 16 * u or y > hw.end.y - 100 * u:
			continue
		var cx := hw.position.x + 15 * u + int(nd.lane) * lw + lw * 0.5
		var col: Color = LANE_COLORS[int(nd.lane)]
		if String(nd.res) == "miss":
			col = Color(0.5, 0.5, 0.5)
		c.draw_circle(Vector2(cx, y + 4 * u), 33 * u, Color(0, 0, 0, 0.3))
		c.draw_circle(Vector2(cx, y), 33 * u, Color.WHITE)
		c.draw_circle(Vector2(cx, y), 28 * u, col)
		c.draw_circle(Vector2(cx - 8 * u, y - 9 * u), 8 * u, Color(1, 1, 1, 0.5))
	# 按鍵
	for l in LANES:
		var cx2 := hw.position.x + 15 * u + l * lw + lw * 0.5
		var kp := float(_flash[l]) > 0.0
		c.draw_circle(Vector2(cx2, hit_y + 62 * u), 34 * u, LANE_COLORS[l] if kp else Color(LANE_COLORS[l], 0.35))
		var ks := 26.0 * u
		var cs := UIStyle.keycap_size(String(LANE_KEYS[l]), ks)
		UIStyle.draw_keycap(c, Vector2(cx2, hit_y + 62 * u) - cs * 0.5, String(LANE_KEYS[l]), ks)
	# 判定、連擊
	if _judge_t < 0.6:
		var a := 1.0 - smoothstep(0.3, 0.6, _judge_t)
		var jp := Vector2(hw.get_center().x, hit_y - 150 * u - _judge_t * 40 * u)
		HubUI.text_c(c, jp, _judge_txt, 46 * u, Color(_judge_col, a))
	if _combo >= 2:
		HubUI.text_c(c, Vector2(hw.get_center().x, hw.position.y + 70 * u), "%d 連擊" % _combo, 40 * u, Color("ffe27a") if _fever else Color.WHITE)
	if _clock < LEAD_BARS * 4.0 * 60.0 / float(SONGS[song].bpm) - 0.5 and state == "play":
		HubUI.text_c(c, hw.get_center() + Vector2(0, -60 * u), "準備！", 54 * u, Color.WHITE)
	# 左上角：歌名、分數、人氣
	var sp := Rect2(Vector2(60, 50) * u, Vector2(470, 190) * u)
	c.draw_style_box(HubUI.box(Color(HubUI.PAPER, 0.95), HubUI.PAPER_EDGE, 24 * u, 3.0), sp)
	var nm := String(SONGS[song].name)
	HubUI.text(c, sp.position + Vector2(24, 44) * u, nm, HubUI.fit(nm, 32 * u, sp.size.x - 48 * u), HubUI.INK)
	HubUI.text(c, sp.position + Vector2(24, 92) * u, "分數 %d" % _score, 30 * u, HubUI.INK)
	var br := Rect2(sp.position + Vector2(24, 116) * u, Vector2(sp.size.x - 48 * u, 26 * u))
	c.draw_style_box(HubUI.box(Color("e8e0cc"), HubUI.PAPER_EDGE, 13 * u, 2.0, false), br)
	var fillw := br.size.x * clampf(_hype / 100.0, 0.0, 1.0)
	if fillw > 4 * u:
		c.draw_style_box(HubUI.box(Color("ff8ae0") if _fever else Color("a04fd0"), Color("5e2a82"), 13 * u, 2.0, false), Rect2(br.position, Vector2(fillw, br.size.y)))
	var lvl := "暖場中" if _hype < 34.0 else ("升溫了" if _hype < 67.0 else "嗨翻天")
	if _fever:
		lvl = "FEVER！"
	HubUI.text(c, sp.position + Vector2(24, 172) * u, "人氣：" + lvl, 24 * u, HubUI.INK)
	# 進度
	var prog := clampf(_clock / maxf(_end_t, 1.0), 0.0, 1.0)
	c.draw_rect(Rect2(hw.position + Vector2(20 * u, hw.size.y - 20 * u), Vector2(hw.size.x - 40 * u, 6 * u)), Color(1, 1, 1, 0.15))
	c.draw_rect(Rect2(hw.position + Vector2(20 * u, hw.size.y - 20 * u), Vector2((hw.size.x - 40 * u) * prog, 6 * u)), Color("a04fd0"))
	if state == "play":
		HubUI.key_strip(c, u, [[["D", "F", "J", "K"], "打音符"], [["Esc"], "不玩了"]])

func _paint_result(c: Control, u: float, vs: Vector2) -> void:
	var pr := Rect2(vs * 0.5 - Vector2(380, 270) * u + Vector2(-230, 0) * u, Vector2(760, 540) * u)
	c.draw_rect(Rect2(Vector2.ZERO, vs), Color(0, 0, 0, 0.25))
	c.draw_style_box(HubUI.box(Color(HubUI.PAPER, 0.98), HubUI.PAPER_EDGE, 34 * u, 4.0), pr)
	HubUI.tag(c, Vector2(pr.get_center().x, pr.position.y + 8 * u), "演出結束", 38 * u, Color("a04fd0"), Color("5e2a82"), -0.03)
	var rk := int(_result.rank)
	var bc := pr.position + Vector2(190, 230) * u
	c.draw_circle(bc + Vector2(0, 8) * u, 120 * u, Color(0, 0, 0, 0.2))
	c.draw_circle(bc, 120 * u, Color.WHITE)
	c.draw_circle(bc, 108 * u, RANK_COLORS[rk])
	HubUI.text_c(c, bc + Vector2(0, -6) * u, String(RANKS[rk]), 150 * u, Color.WHITE)
	var x := pr.position.x + 360 * u
	HubUI.text(c, Vector2(x, pr.position.y + 130 * u), "分數　%d" % int(_result.score), 38 * u, HubUI.INK)
	HubUI.text(c, Vector2(x, pr.position.y + 188 * u), "Perfect　%d" % int(_counts.perfect), 30 * u, Color("c08a00"))
	HubUI.text(c, Vector2(x, pr.position.y + 232 * u), "Good　　%d" % int(_counts.good), 30 * u, Color("2f8fc0"))
	HubUI.text(c, Vector2(x, pr.position.y + 276 * u), "Miss　　%d" % int(_counts.miss), 30 * u, Color("c04a40"))
	HubUI.text(c, Vector2(x, pr.position.y + 328 * u), "最高連擊　%d" % int(_result.max_combo), 30 * u, HubUI.INK)
	if bool(_result.new):
		HubUI.tag(c, pr.position + Vector2(560, 90) * u, "新紀錄！", 30 * u, HubUI.RED, Color("8a2a20"), 0.12)
	if bool(_result.fc):
		HubUI.tag(c, pr.position + Vector2(190, 410) * u, "全連擊！", 32 * u, Color("ffb300"), Color("8a6410"), -0.06)
	HubUI.text(c, pr.position + Vector2(60, 490) * u, ("Enter 再來一次　　%s 回選單" % UIStyle.key_label("Esc")), 26 * u, Color("7a6a5a"))
	_rects.append({"rect": pr, "kind": "again", "idx": 0})
	HubUI.key_strip(c, u, [[["Enter"], "再來一次"], [["Esc"], "回選單"]])

func _paint_jam(c: Control, u: float, vs: Vector2) -> void:
	HubUI.tag(c, Vector2(vs.x * 0.5, 70 * u), "自由混音", 40 * u, Color("a04fd0"), Color("5e2a82"), -0.03)
	var pw := 170.0 * u
	var gap := 22.0 * u
	var total := pw * 4.0 + gap * 3.0
	var y := vs.y - 330 * u
	for l in 4:
		var r := Rect2(Vector2(vs.x * 0.5 - total * 0.5 + l * (pw + gap), y), Vector2(pw, 200 * u))
		_rects.append({"rect": r, "kind": "pad", "idx": l})
		var on: bool = _layer_on[l]
		var col: Color = LANE_COLORS[l]
		var glow := float(_flash[l]) / 0.2
		c.draw_style_box(HubUI.box(col.lerp(Color.WHITE, 0.15 + glow * 0.3) if on else Color(col, 0.28).lerp(Color.WHITE, 0.5), col.darkened(0.3), 28 * u, 4.0), r)
		HubUI.text_c(c, r.get_center() + Vector2(0, -26 * u), String(LAYER_NAMES[l]), 46 * u, Color.WHITE if on else HubUI.INK)
		HubUI.text_c(c, r.get_center() + Vector2(0, 30 * u), "開" if on else "關", 30 * u, Color.WHITE if on else Color("8a847a"))
		var ks := 26.0 * u
		var cs := UIStyle.keycap_size(String(LANE_KEYS[l]), ks)
		UIStyle.draw_keycap(c, Vector2(r.get_center().x, r.end.y + 38 * u) - cs * 0.5, String(LANE_KEYS[l]), ks)
	if _layer_on[0] and _layer_on[1] and _layer_on[2] and _layer_on[3] and not _jam_done:
		HubUI.text_c(c, Vector2(vs.x * 0.5, y - 40 * u), "全開撐住！%d／10 秒" % int(_all_on_t), 34 * u, Color("ffe27a"))
	elif _jam_done:
		HubUI.text_c(c, Vector2(vs.x * 0.5, y - 40 * u), "混音大師 ✓", 30 * u, Color("ffe27a"))
	HubUI.key_strip(c, u, [[["D", "F", "J", "K"], "開關樂器"], [["Space"], "氣喇叭"], [["Esc"], "回選單"]])
