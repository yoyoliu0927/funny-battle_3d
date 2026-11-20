extends RefCounted
## 農莊小東西的音效（戳戳樂、釣魚、手帳）：跟選關畫面一樣全部用程式即時合成，不用音效檔。
## 用法：const Sfx := preload("res://scripts/hub/hub_sfx.gd")；Sfx.make() 回傳 {名字: AudioStreamWAV}，只合成一次。
## 不用 level_select.gd 裡的合成函式，因為兩個檔案互相 preload 會變成循環參照。

const RATE := 22050

static var _cache := {}

static func make() -> Dictionary:
	if _cache.is_empty():
		_cache = {
			"cluck": _cluck(), "boing": _boing(), "rustle": _rustle(), "pop": _pop(), "gold": _gold(),
			"splash": _splash(), "bite": _bite(), "tick": _tick(), "catch": _catch(), "miss": _miss(),
			"page": _page(), "knock": _knock(), "whoosh": _whoosh(), "flare": _flare(), "sticker": _sticker(),
			"horn": _horn(), "quack": _quack(), "chime": _chime(), "wave": _wave(),
		}
	return _cache

## 給一個節點加一組播放器（回傳 {名字: AudioStreamPlayer}）
static func attach(parent: Node, db := -3.0) -> Dictionary:
	var out := {}
	var streams := make()
	for id in streams:
		var p := AudioStreamPlayer.new()
		p.stream = streams[id]
		p.volume_db = db
		parent.add_child(p)
		out[id] = p
	return out

# ---------------------------------------------------------------- 合成的小工具

static func _buf(sec: float) -> PackedFloat32Array:
	var s := PackedFloat32Array()
	s.resize(int(sec * RATE))
	return s

static func _wav(s: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(s.size() * 2)
	for i in s.size():
		data.encode_s16(i * 2, int(clampf(s[i], -1.0, 1.0) * 30000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w

## 音樂盒的一顆音（跟選關畫面同一種音色）
static func _bell(buf: PackedFloat32Array, at: float, note: int, dur: float, amp: float) -> void:
	var f := 440.0 * pow(2.0, (note - 69) / 12.0)
	var cnt := int(dur * RATE)
	var start := int(at * RATE)
	for j in cnt:
		var i := start + j
		if i >= buf.size():
			break
		var t := float(j) / RATE
		var env := minf(float(j) / 60.0, 1.0) * exp(-t * 5.0 / dur)
		buf[i] += (sin(TAU * f * t) + 0.35 * sin(TAU * f * 2.0 * t) * exp(-t * 6.0) + 0.15 * sin(TAU * f * 4.0 * t) * exp(-t * 12.0)) * env * amp

## 一段會滑音的正弦波，疊加進 buf
static func _sweep(buf: PackedFloat32Array, at: float, dur: float, f0: float, f1: float, amp: float, wobble := 0.0) -> void:
	var start := int(at * RATE)
	var cnt := int(dur * RATE)
	var ph := 0.0
	for j in cnt:
		var i := start + j
		if i >= buf.size():
			break
		var k := float(j) / cnt
		var f := lerpf(f0, f1, k) * (1.0 + wobble * sin(k * 60.0))
		ph += TAU * f / RATE
		buf[i] += sin(ph) * sin(k * PI) * amp

## 一段噪音（固定亂數種子，每次聽起來都一樣）；lp 越小越悶
static func _noise(buf: PackedFloat32Array, at: float, dur: float, amp: float, lp: float, decay := 4.0) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7 + int(at * 1000.0)
	var start := int(at * RATE)
	var cnt := int(dur * RATE)
	var y := 0.0
	for j in cnt:
		var i := start + j
		if i >= buf.size():
			break
		var k := float(j) / cnt
		y += (rng.randf_range(-1.0, 1.0) - y) * lp
		buf[i] += y * exp(-k * decay) * amp

# ---------------------------------------------------------------- 音效

## 母雞：兩下短短的「咕咕」
static func _cluck() -> AudioStreamWAV:
	var s := _buf(0.3)
	_sweep(s, 0.0, 0.09, 620.0, 380.0, 0.34, 0.06)
	_sweep(s, 0.12, 0.11, 700.0, 340.0, 0.34, 0.08)
	return _wav(s)

## 彈起來：「啵～」
static func _boing() -> AudioStreamWAV:
	var s := _buf(0.32)
	_sweep(s, 0.0, 0.3, 200.0, 560.0, 0.4, 0.05)
	return _wav(s)

## 樹葉沙沙
static func _rustle() -> AudioStreamWAV:
	var s := _buf(0.5)
	_noise(s, 0.0, 0.5, 0.55, 0.45, 3.0)
	_noise(s, 0.08, 0.35, 0.35, 0.6, 4.0)
	return _wav(s)

## 收到蛋：往上的一顆「叮」
static func _pop() -> AudioStreamWAV:
	var s := _buf(0.4)
	_sweep(s, 0.0, 0.08, 400.0, 900.0, 0.3)
	_bell(s, 0.05, 88, 0.3, 0.4)
	return _wav(s)

## 金蛋：往上的四顆音
static func _gold() -> AudioStreamWAV:
	var s := _buf(1.0)
	var notes := [84, 88, 91, 96]
	for i in notes.size():
		_bell(s, i * 0.08, notes[i], 0.5, 0.36)
	_bell(s, 0.3, 100, 0.6, 0.16)
	return _wav(s)

## 魚線落水：「噗通」
static func _splash() -> AudioStreamWAV:
	var s := _buf(0.5)
	_sweep(s, 0.0, 0.16, 260.0, 70.0, 0.55)
	_noise(s, 0.0, 0.4, 0.45, 0.35, 5.0)
	return _wav(s)

## 魚上鉤了：兩下清脆的「叮叮」
static func _bite() -> AudioStreamWAV:
	var s := _buf(0.55)
	_bell(s, 0.0, 91, 0.25, 0.45)
	_bell(s, 0.14, 91, 0.35, 0.45)
	return _wav(s)

## 拉線的一格：很短的「嗒」
static func _tick() -> AudioStreamWAV:
	var s := _buf(0.05)
	_sweep(s, 0.0, 0.04, 1500.0, 1100.0, 0.3)
	return _wav(s)

## 釣到了：往上的五顆音
static func _catch() -> AudioStreamWAV:
	var s := _buf(1.2)
	var notes := [72, 76, 79, 84, 88]
	for i in notes.size():
		_bell(s, i * 0.09, notes[i], 0.4 if i < 4 else 0.8, 0.34)
	return _wav(s)

## 跑掉了：往下滑的「嗚～」
static func _miss() -> AudioStreamWAV:
	var s := _buf(0.4)
	_sweep(s, 0.0, 0.38, 420.0, 150.0, 0.36)
	return _wav(s)

## 翻頁：一小段高頻的噪音
static func _page() -> AudioStreamWAV:
	var s := _buf(0.22)
	_noise(s, 0.0, 0.2, 0.5, 0.85, 6.0)
	return _wav(s)

## 敲門：兩下木頭的「咚咚」
static func _knock() -> AudioStreamWAV:
	var s := _buf(0.4)
	for hit in 2:
		_sweep(s, hit * 0.15, 0.1, 190.0, 90.0, 0.6)
		_noise(s, hit * 0.15, 0.05, 0.25, 0.4, 8.0)
	return _wav(s)

## 風：一聲「呼～」
static func _whoosh() -> AudioStreamWAV:
	var s := _buf(0.7)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var y := 0.0
	for i in s.size():
		var k := float(i) / s.size()
		y += (rng.randf_range(-1.0, 1.0) - y) * lerpf(0.08, 0.3, sin(k * PI))
		s[i] = y * sin(k * PI) * 0.9
	return _wav(s)

## 船的汽笛：低低的「嗚——」（兩個音疊在一起）
static func _horn() -> AudioStreamWAV:
	var s := _buf(0.95)
	for i in s.size():
		var t := float(i) / RATE
		var env := minf(t / 0.06, 1.0) * exp(-maxf(t - 0.55, 0.0) * 7.0)
		var f := 196.0 * (1.0 + 0.012 * sin(t * 30.0))
		s[i] = (sin(TAU * f * t) + 0.6 * sin(TAU * f * 1.5 * t) + 0.25 * sin(TAU * f * 3.0 * t)) * env * 0.42
	return _wav(s)

## 企鵝的叫聲：短短的「呱」
static func _quack() -> AudioStreamWAV:
	var s := _buf(0.22)
	_sweep(s, 0.0, 0.2, 520.0, 330.0, 0.5, 0.05)
	for i in s.size():
		s[i] += sin(TAU * 1040.0 * float(i) / RATE) * 0.12 * exp(-float(i) / RATE * 22.0)
	return _wav(s)

## 撈到寶箱：叮叮咚
static func _chime() -> AudioStreamWAV:
	var s := _buf(0.9)
	_bell(s, 0.0, 79, 0.5, 0.35)
	_bell(s, 0.12, 83, 0.5, 0.3)
	_bell(s, 0.26, 86, 0.6, 0.3)
	return _wav(s)

## 海浪：一陣沙沙聲（開船時當背景，音量跟速度走）
static func _wave() -> AudioStreamWAV:
	var s := _buf(2.4)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var y := 0.0
	for i in s.size():
		var k := float(i) / s.size()
		y += (rng.randf_range(-1.0, 1.0) - y) * 0.12
		s[i] = y * (0.55 + 0.45 * sin(k * TAU)) * 0.55
	return _wav(s)

## 火苗竄起來：「啪嘰」
static func _flare() -> AudioStreamWAV:
	var s := _buf(0.4)
	_noise(s, 0.0, 0.3, 0.6, 0.7, 7.0)
	_sweep(s, 0.0, 0.2, 300.0, 700.0, 0.2)
	return _wav(s)

## 解鎖貼紙：「叮叮咚」
static func _sticker() -> AudioStreamWAV:
	var s := _buf(0.8)
	_bell(s, 0.0, 79, 0.3, 0.4)
	_bell(s, 0.1, 84, 0.3, 0.4)
	_bell(s, 0.2, 91, 0.6, 0.4)
	return _wav(s)
