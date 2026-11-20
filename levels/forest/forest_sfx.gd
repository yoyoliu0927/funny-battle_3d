extends RefCounted
## 森林的配樂和音效：全部用程式即時合成（不用音效檔，不用管授權）。
## 用法：var s := ForestSfx.make_all()  →  {"chop": AudioStreamWAV, ...}（第一次算完會記住，重試、換關不用再算）
##
## 配樂是「叢林」風：手鼓、沙鈴、木琴、拇指琴，五聲音階（A 小調），104 BPM，8 小節一圈。
##   bgm_plan  準備階段：鳥叫、輕輕的沙鈴、低低的鼓、零星幾句拇指琴
##   bgm_run   開打之後：同一段和弦、同樣長度——手鼓打滿、低音走起來、木琴跑動。兩首同時播、只換音量，切換不會斷拍

const RATE := 22050
const BPM := 104.0
const STEP := 60.0 / BPM / 4.0          # 十六分音符
const STEPS := 128                      # 8 小節

static var _cache := {}
static var _building := false

## 合成好了沒（make_all 可以丟到背景執行緒做，主執行緒用這個問）
static func is_ready() -> bool:
	return not _cache.is_empty()

static func building() -> bool:
	return _building

static func make_all() -> Dictionary:
	if not _cache.is_empty():
		return _cache
	_building = true
	var all := {
		"guide": guide(), "decoy": decoy(), "basket": basket(),
		"chop": chop(), "fall": fall(), "flick": flick(), "ignite": ignite(), "crackle": crackle(),
		"stomp": stomp(), "bonk": bonk(), "peck": peck(), "ouch": ouch(), "down": down(),
		"swat": swat(), "sniff": sniff(), "rescue": rescue(), "win": win(), "lose": lose(),
		"go": go(), "warn": warn(), "check": check(),
		"bgm_plan": bgm_plan(), "bgm_run": bgm_run(),
	}
	_cache = all              # 全部算完才放進去，主執行緒不會拿到一半
	_building = false
	return _cache

# ================================================================== 小工具

static func _buf(sec: float) -> PackedFloat32Array:
	var s := PackedFloat32Array()
	s.resize(int(sec * RATE))
	return s

static func _wav(s: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(s.size() * 2)
	for i in s.size():
		data.encode_s16(i * 2, int(clampf(s[i], -1.0, 1.0) * 30000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = s.size()
	return w

static func _hz(note: float) -> float:
	return 440.0 * pow(2.0, (note - 69.0) / 12.0)

## 加進 s：t0 秒開始；wrap＝超出尾巴的部分繞回開頭（循環的配樂）
static func _add(s: PackedFloat32Array, i: int, v: float, wrap: bool) -> void:
	if i >= s.size():
		if not wrap:
			return
		i = i % s.size()
	s[i] += v

## 木琴：基音＋第四泛音（木琴的泛音大約在 4 倍），很快衰減
static func _marimba(s: PackedFloat32Array, t0: float, note: float, amp: float, wrap := false, decay := 7.0) -> void:
	var f := _hz(note)
	var n := int(minf(0.9, 6.0 / decay) * RATE)          # 衰減到聽不見就不用再算
	var start := int(t0 * RATE)
	for j in n:
		var t := float(j) / RATE
		var env := minf(t * 400.0, 1.0) * exp(-t * decay)
		var v := sin(TAU * f * t) + 0.3 * sin(TAU * f * 3.93 * t) * exp(-t * 18.0)
		_add(s, start + j, v * env * amp, wrap)

## 拇指琴（卡林巴）：亮一點、尾巴長一點、帶一點不和諧的泛音
static func _kalimba(s: PackedFloat32Array, t0: float, note: float, amp: float, wrap := false) -> void:
	var f := _hz(note)
	var n := int(1.3 * RATE)
	var start := int(t0 * RATE)
	for j in n:
		var t := float(j) / RATE
		var env := minf(t * 600.0, 1.0) * exp(-t * 3.6)
		var v := sin(TAU * f * t) + 0.22 * sin(TAU * f * 5.4 * t) * exp(-t * 14.0) + 0.12 * sin(TAU * f * 2.0 * t)
		_add(s, start + j, v * env * amp, wrap)

## 鼓：音高從 f0 掉到 f1 的正弦波＋一點敲擊的雜音
static func _drum(s: PackedFloat32Array, t0: float, f0: float, f1: float, dur: float, amp: float, click: float, seed: int, wrap := false) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var n := int(dur * RATE)
	var start := int(t0 * RATE)
	var ph := 0.0
	for j in n:
		var t := float(j) / RATE
		var k := t / dur
		var f := f1 + (f0 - f1) * exp(-k * 6.0)
		ph += f / RATE
		var env := minf(t * 800.0, 1.0) * pow(1.0 - k, 2.2)
		var v := sin(TAU * ph) + click * rng.randf_range(-1.0, 1.0) * exp(-t * 90.0)
		_add(s, start + j, v * env * amp, wrap)

## 雜音：hp＝高通程度（0 很悶、1 很沙）
static func _noise(s: PackedFloat32Array, t0: float, dur: float, amp: float, hp: float, seed: int, wrap := false, attack := 0.004) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var n := int(dur * RATE)
	var start := int(t0 * RATE)
	var lp := 0.0
	for j in n:
		var t := float(j) / RATE
		var k := t / dur
		var x := rng.randf_range(-1.0, 1.0)
		lp += (x - lp) * (1.0 - hp * 0.85)
		var v := lerpf(lp, x - lp, hp)
		var env := minf(t / attack, 1.0) * pow(1.0 - k, 2.0)
		_add(s, start + j, v * env * amp, wrap)

## 鳥叫：快速往上滑、帶顫音的短音，連叫 count 聲
static func _bird(s: PackedFloat32Array, t0: float, base: float, count: int, amp: float, wrap := false) -> void:
	for c in count:
		var start := int((t0 + c * 0.11) * RATE)
		var n := int(0.075 * RATE)
		var ph := 0.0
		for j in n:
			var t := float(j) / RATE
			var k := t / 0.075
			var f := base * (1.0 + 0.6 * k) + 120.0 * sin(TAU * 38.0 * t)
			ph += f / RATE
			var env := sin(PI * k)
			_add(s, start + j, sin(TAU * ph) * env * amp, wrap)

## 低音：正弦＋一點八度，慢慢收
static func _bass(s: PackedFloat32Array, t0: float, note: float, dur: float, amp: float, wrap := false) -> void:
	var f := _hz(note)
	var n := int(dur * RATE)
	var start := int(t0 * RATE)
	for j in n:
		var t := float(j) / RATE
		var k := t / dur
		var env := minf(t * 120.0, 1.0) * (1.0 - k) * (1.0 - k * 0.3)
		_add(s, start + j, (sin(TAU * f * t) + 0.25 * sin(TAU * f * 2.0 * t)) * env * amp, wrap)

static func _norm(s: PackedFloat32Array, peak := 0.9) -> PackedFloat32Array:
	var m := 0.0001
	for v in s:
		m = maxf(m, absf(v))
	var k := peak / m
	for i in s.size():
		s[i] *= k
	return s

# ================================================================== 配樂

## 和弦進行：Am  G  F  G（每兩小節一個），低音的根音
const ROOTS := [45, 45, 43, 43, 41, 41, 43, 43]
## 拇指琴的旋律（A 小調五聲：A C D E G），-1＝休息；一格＝八分音符
const MEL := [
	69, -1, 72, -1, 74, 76, -1, 74,   72, -1, 69, -1, -1, -1, 67, -1,
	67, -1, 71, -1, 74, -1, 72, 71,   67, -1, -1, -1, 64, -1, 67, -1,
	65, -1, 69, -1, 72, -1, 74, 72,   69, -1, 65, -1, -1, -1, 64, -1,
	67, -1, 71, 74, -1, 76, 74, -1,   71, -1, 67, -1, 69, -1, -1, -1,
]

## 準備階段：森林的聲音為主——鳥叫、沙鈴、遠遠的低鼓、零星的拇指琴
static func bgm_plan() -> AudioStreamWAV:
	var s := _buf(STEPS * STEP)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7311
	for i in STEPS:
		var t := i * STEP
		if i % 16 == 0:
			_drum(s, t, 110.0, 70.0, 0.45, 0.5, 0.15, 100 + i, true)            # 每小節第一拍：低鼓
		if i % 16 == 10:
			_drum(s, t, 150.0, 95.0, 0.3, 0.28, 0.2, 200 + i, true)
		if i % 4 == 2:
			_noise(s, t, 0.06, 0.07, 0.95, 300 + i, true)                        # 反拍的沙鈴
	for k in MEL.size():
		if MEL[k] >= 0 and k % 4 != 3 and (k / 8) % 2 == 0:                     # 只彈每兩小節的第一句
			_kalimba(s, k * STEP * 2.0, MEL[k], 0.2, true)
	for b in 9:                                                                 # 鳥叫：固定的亂數，每次都一樣
		var t := rng.randf_range(0.0, STEPS * STEP - 0.6)
		_bird(s, t, rng.randf_range(2400.0, 3600.0), rng.randi_range(2, 4), 0.07, true)
	for i in 8:                                                                 # 低音：每兩小節一個長音
		_bass(s, i * 16 * STEP, ROOTS[i] - 12, 16 * STEP * 0.95, 0.22, true)
	return _wav(_norm(s, 0.85), true)

## 開打之後：同一段的熱鬧版——手鼓打滿、低音走起來、木琴跑十六分音符、拇指琴唱整段
static func bgm_run() -> AudioStreamWAV:
	var s := _buf(STEPS * STEP)
	# 手鼓的節奏型（一小節 16 格）：1＝低音、2＝高音（拍擊）、0＝空
	var djembe := [1, 0, 2, 0, 0, 2, 1, 0, 1, 0, 2, 0, 2, 2, 0, 2]
	var rng := RandomNumberGenerator.new()
	rng.seed = 9917
	for i in STEPS:
		var t := i * STEP
		var bar := i / 16
		match djembe[i % 16]:
			1:
				_drum(s, t, 140.0, 80.0, 0.32, 0.55, 0.25, 400 + i, true)
			2:
				_drum(s, t, 420.0, 300.0, 0.12, 0.3, 0.6, 500 + i, true)
		if i % 16 == 0:
			_drum(s, t, 80.0, 45.0, 0.6, 0.6, 0.1, 600 + i, true)                 # 大鼓
		_noise(s, t, 0.05, 0.05 if i % 2 == 0 else 0.09, 0.95, 700 + i, true)   # 沙鈴打滿
		# 木琴：和弦音跑十六分音符
		var root: int = ROOTS[bar]
		var arp: int = [12, 19, 24, 19, 15, 19, 24, 27][i % 8] if root == 45 else [12, 19, 24, 19, 16, 19, 24, 28][i % 8]
		_marimba(s, t, root + arp, 0.11, true, 12.0)
		if i % 4 == 0:
			_bass(s, t, root - 12 + (7 if i % 16 == 8 else 0), 4 * STEP * 0.9, 0.3, true)
	for k in MEL.size():
		if MEL[k] >= 0:
			_kalimba(s, k * STEP * 2.0, MEL[k] + 12, 0.17, true)
	for b in 5:
		var t := rng.randf_range(0.0, STEPS * STEP - 0.6)
		_bird(s, t, rng.randf_range(2600.0, 3600.0), 3, 0.05, true)
	return _wav(_norm(s, 0.85), true)

# ================================================================== 音效

## 插引路點：木頭「叩」＋旗子啪一下
static func guide() -> AudioStreamWAV:
	var s := _buf(0.3)
	_drum(s, 0.0, 1100.0, 800.0, 0.08, 0.6, 0.5, 11)
	_noise(s, 0.04, 0.12, 0.25, 0.7, 12)
	return _wav(_norm(s))

## 放假獵物：「啵嚶」一聲
static func decoy() -> AudioStreamWAV:
	var s := _buf(0.35)
	var ph := 0.0
	for j in s.size():
		var t := float(j) / RATE
		var k := t / 0.35
		var f := 320.0 + 520.0 * sin(PI * minf(k * 1.4, 1.0)) + 40.0 * sin(TAU * 22.0 * t)
		ph += f / RATE
		s[j] = sin(TAU * ph) * sin(PI * k) * 0.6
	return _wav(_norm(s, 0.7))

## 放籃子：藤編窸窣＋輕輕落地
static func basket() -> AudioStreamWAV:
	var s := _buf(0.4)
	for k in 4:
		_noise(s, k * 0.05, 0.06, 0.3, 0.8, 20 + k)
	_drum(s, 0.18, 180.0, 110.0, 0.15, 0.5, 0.3, 25)
	return _wav(_norm(s, 0.75))

## 斧頭砍樹：「咚」一聲悶響＋木屑
static func chop() -> AudioStreamWAV:
	var s := _buf(0.3)
	_drum(s, 0.0, 260.0, 120.0, 0.18, 0.8, 0.9, 30)
	_noise(s, 0.0, 0.1, 0.3, 0.5, 31)
	return _wav(_norm(s, 0.8))

## 倒樹：吱嘎——轟
static func fall() -> AudioStreamWAV:
	var s := _buf(1.5)
	var ph := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 40
	for j in int(0.7 * RATE):
		var t := float(j) / RATE
		var f := 130.0 - 50.0 * t + rng.randf_range(-25.0, 25.0)
		ph += f / RATE
		var saw := fmod(ph, 1.0) * 2.0 - 1.0
		var grit := 0.5 + 0.5 * sin(TAU * 17.0 * t)
		s[j] += saw * grit * minf(t * 10.0, 1.0) * 0.25
	_drum(s, 0.68, 90.0, 38.0, 0.75, 0.9, 0.4, 41)
	_noise(s, 0.68, 0.7, 0.45, 0.2, 42)
	return _wav(_norm(s, 0.85))

## 彈菸蒂：小小「嘶」
static func flick() -> AudioStreamWAV:
	var s := _buf(0.25)
	_drum(s, 0.0, 2200.0, 1800.0, 0.03, 0.3, 0.3, 50)
	_noise(s, 0.02, 0.2, 0.25, 0.97, 51)
	return _wav(_norm(s, 0.5))

## 起火：「呼——」
static func ignite() -> AudioStreamWAV:
	var s := _buf(0.9)
	var rng := RandomNumberGenerator.new()
	rng.seed = 60
	var lp := 0.0
	for j in s.size():
		var t := float(j) / RATE
		var k := t / 0.9
		var cut := 0.02 + 0.25 * k
		lp += (rng.randf_range(-1.0, 1.0) - lp) * cut
		s[j] = lp * sin(PI * minf(k * 1.3, 1.0)) * 1.5
	return _wav(_norm(s, 0.8))

## 燒的時候的劈啪聲（循環播放，跟著著火的樹）
static func crackle() -> AudioStreamWAV:
	var s := _buf(2.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 70
	var lp := 0.0
	for j in s.size():
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.04
		s[j] = lp * 0.5                                                          # 低低的火聲
	for k in 34:
		var t := rng.randf_range(0.0, 1.95)
		_noise(s, t, rng.randf_range(0.01, 0.04), rng.randf_range(0.2, 0.6), 0.9, 71 + k, true, 0.0005)
	return _wav(_norm(s, 0.7), true)

## 踩熄菸蒂：噗滋——嘶
static func stomp() -> AudioStreamWAV:
	var s := _buf(0.6)
	_drum(s, 0.0, 160.0, 90.0, 0.1, 0.6, 0.5, 80)
	_noise(s, 0.06, 0.5, 0.35, 0.98, 81, false, 0.02)
	return _wav(_norm(s, 0.75))

## 偷襲：「咚！」＋小跳音
static func bonk() -> AudioStreamWAV:
	var s := _buf(0.45)
	_drum(s, 0.0, 700.0, 260.0, 0.18, 0.8, 0.6, 90)
	_marimba(s, 0.08, 84, 0.3)
	_marimba(s, 0.16, 91, 0.25)
	return _wav(_norm(s, 0.85))

## 家豪啄人
static func peck() -> AudioStreamWAV:
	var s := _buf(0.18)
	_drum(s, 0.0, 900.0, 500.0, 0.08, 0.6, 0.8, 95)
	return _wav(_norm(s, 0.6))

## 家豪挨打：低一點的「啪」＋往下的小哀叫
static func ouch() -> AudioStreamWAV:
	var s := _buf(0.4)
	_noise(s, 0.0, 0.08, 0.6, 0.6, 100)
	var ph := 0.0
	for j in int(0.3 * RATE):
		var t := float(j) / RATE
		ph += (1100.0 - 1600.0 * t) / RATE
		s[int(0.05 * RATE) + j] += sin(TAU * ph) * sin(PI * t / 0.3) * 0.3
	return _wav(_norm(s, 0.7))

## 有人被打倒：往下滑的口哨
static func down() -> AudioStreamWAV:
	var s := _buf(0.6)
	var ph := 0.0
	for j in s.size():
		var t := float(j) / RATE
		var k := t / 0.6
		ph += (1400.0 - 900.0 * k) / RATE
		s[j] = sin(TAU * ph) * sin(PI * k) * 0.4
	_drum(s, 0.45, 120.0, 60.0, 0.15, 0.5, 0.3, 110)
	return _wav(_norm(s, 0.65))

## 狼外婆一掌：低吼＋「啪」
static func swat() -> AudioStreamWAV:
	var s := _buf(0.8)
	var ph := 0.0
	for j in int(0.45 * RATE):
		var t := float(j) / RATE
		ph += (85.0 + 12.0 * sin(TAU * 28.0 * t)) / RATE
		var saw := fmod(ph, 1.0) * 2.0 - 1.0
		s[j] += saw * sin(PI * t / 0.45) * 0.35
	_noise(s, 0.32, 0.12, 0.9, 0.7, 120)
	_drum(s, 0.32, 220.0, 90.0, 0.25, 0.7, 0.5, 121)
	return _wav(_norm(s, 0.85))

## 狼外婆聞籃子：嗅、嗅、嗅
static func sniff() -> AudioStreamWAV:
	var s := _buf(0.6)
	for k in 3:
		_noise(s, k * 0.17, 0.11, 0.5, 0.75, 130 + k, false, 0.03)
	return _wav(_norm(s, 0.55))

## 救出小紅帽：拇指琴往上的琶音
static func rescue() -> AudioStreamWAV:
	var s := _buf(1.4)
	var notes := [69, 72, 76, 81, 84]
	for k in notes.size():
		_kalimba(s, k * 0.09, notes[k], 0.4)
	return _wav(_norm(s, 0.8))

## 過關：木琴＋手鼓的小號角
static func win() -> AudioStreamWAV:
	var s := _buf(2.0)
	var notes := [72, 76, 79, 84, -1, 81, 84]
	for k in notes.size():
		if notes[k] >= 0:
			_marimba(s, k * 0.12, notes[k], 0.45, false, 4.0)
	_kalimba(s, 0.84, 88, 0.35)
	for k in 4:
		_drum(s, k * 0.12, 420.0, 300.0, 0.1, 0.25, 0.6, 140 + k)
	_drum(s, 0.84, 100.0, 50.0, 0.6, 0.6, 0.2, 145)
	return _wav(_norm(s, 0.85))

## 輸了：往下走的木琴
static func lose() -> AudioStreamWAV:
	var s := _buf(1.8)
	var notes := [76, 74, 72, 69, 64]
	for k in notes.size():
		_marimba(s, k * 0.22, notes[k], 0.45, false, 3.0)
	_drum(s, 1.1, 70.0, 40.0, 0.6, 0.5, 0.1, 150)
	return _wav(_norm(s, 0.75))

## 開打：兩聲手鼓＋大鼓
static func go() -> AudioStreamWAV:
	var s := _buf(0.8)
	_drum(s, 0.0, 420.0, 300.0, 0.12, 0.5, 0.6, 160)
	_drum(s, 0.14, 420.0, 300.0, 0.12, 0.5, 0.6, 161)
	_drum(s, 0.28, 110.0, 55.0, 0.5, 0.9, 0.3, 162)
	return _wav(_norm(s, 0.85))

## 警告：低—高—低的拇指琴
static func warn() -> AudioStreamWAV:
	var s := _buf(1.0)
	_kalimba(s, 0.0, 64, 0.4)
	_kalimba(s, 0.14, 71, 0.4)
	_kalimba(s, 0.28, 64, 0.4)
	return _wav(_norm(s, 0.7))

## 教學做到一步：叮叮
static func check() -> AudioStreamWAV:
	var s := _buf(0.8)
	_kalimba(s, 0.0, 81, 0.4)
	_kalimba(s, 0.1, 88, 0.4)
	return _wav(_norm(s, 0.6))
