extends RefCounted
## 冰雪島的音效和配樂：全部用程式即時合成（不用音效檔）。
## 用法：var s := Sfx.make_all()  →  {"pop": AudioStreamWAV, ...}
##
## 配樂照同類遊戲的做法（搞笑解謎常用撥弦＋木琴；Untitled Goose Game 那種「同一首曲子分安靜版和熱鬧版，看玩家在做什麼來切換」）：
##   bgm_plan  準備階段：躡手躡腳的撥弦低音＋零星幾顆木琴，留空間給玩家想事情
##   bgm_run   開打之後：同一段和弦、同樣長度，低音走滿、木琴加花、加木魚和小鼓——兩首同時播、只換音量，所以切換不會斷拍

const RATE := 22050

static func make_all() -> Dictionary:
	return {
		"pop": pop(),
		"drop": drop(),
		"crack": crack(),
		"splash": splash(),
		"yell": yell(),
		"caught": caught(),
		"win": win(),
		"undo": undo(),
		"bonk": bonk(),
		"poof": poof(),
		"miss": miss(),
		"peck": peck(),
		"huh": huh(),
		"sigh": sigh(),
		"creak": creak(),
		"carom": carom(),
		"go": go(),
		"bgm_plan": bgm_plan(),
		"bgm_run": bgm_run(),
	}

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

static func _n(sec: float) -> int:
	return int(sec * RATE)

## 放下路線點：短促往上的「啵」
static func pop() -> AudioStreamWAV:
	var s := PackedFloat32Array()
	var n := _n(0.09)
	var ph := 0.0
	for i in n:
		var k := float(i) / n
		ph += TAU * lerpf(520.0, 1100.0, k) / RATE
		s.append(sin(ph) * (1.0 - k) * 0.5)
	return _wav(s)

## 收回路線點：往下的「啵」
static func undo() -> AudioStreamWAV:
	var s := PackedFloat32Array()
	var n := _n(0.1)
	var ph := 0.0
	for i in n:
		var k := float(i) / n
		ph += TAU * lerpf(700.0, 300.0, k) / RATE
		s.append(sin(ph) * (1.0 - k) * 0.4)
	return _wav(s)

## 飼料灑落：一串細碎的沙沙聲
static func drop() -> AudioStreamWAV:
	var r := RandomNumberGenerator.new()
	r.seed = 11
	var s := PackedFloat32Array()
	var n := _n(0.22)
	for i in n:
		var k := float(i) / n
		var grain := 1.0 if fmod(float(i), 900.0) < 160.0 else 0.15
		s.append(r.randf_range(-1.0, 1.0) * grain * (1.0 - k) * 0.35)
	return _wav(s)

## 薄冰裂開：幾聲清脆的喀
static func crack() -> AudioStreamWAV:
	var r := RandomNumberGenerator.new()
	r.seed = 7
	var s := PackedFloat32Array()
	var n := _n(0.35)
	for i in n:
		s.append(0.0)
	for c in 4:
		var at := _n(0.02 + c * 0.075 + r.randf() * 0.02)
		for j in _n(0.03):
			if at + j < n:
				s[at + j] += r.randf_range(-1.0, 1.0) * exp(-float(j) / 90.0) * 0.8
	return _wav(s)

## 掉進水裡：低沉的「撲通」加上水花聲
static func splash() -> AudioStreamWAV:
	var r := RandomNumberGenerator.new()
	r.seed = 3
	var s := PackedFloat32Array()
	var n := _n(0.7)
	var ph := 0.0
	var lp := 0.0
	for i in n:
		var k := float(i) / n
		ph += TAU * lerpf(160.0, 60.0, minf(k * 3.0, 1.0)) / RATE
		var thump := sin(ph) * exp(-k * 9.0) * 0.8
		lp = lerpf(lp, r.randf_range(-1.0, 1.0), 0.25)
		var noise := lp * exp(-k * 3.5) * 0.7
		s.append(thump + noise)
	return _wav(s)

## 人類滑倒時的「哇啊啊」：抖音往下滑的鋸齒波
static func yell() -> AudioStreamWAV:
	var s := PackedFloat32Array()
	var n := _n(0.6)
	var ph := 0.0
	for i in n:
		var k := float(i) / n
		var f := lerpf(330.0, 180.0, k) * (1.0 + 0.06 * sin(k * 60.0))
		ph += f / RATE
		var saw := 2.0 * fmod(ph, 1.0) - 1.0
		var env := minf(k * 12.0, 1.0) * (1.0 - k)
		s.append(saw * env * 0.28)
	return _wav(s)

## 被抓到：喇叭「哇～哇～哇～哇～～」往下的失敗音
static func caught() -> AudioStreamWAV:
	var s := PackedFloat32Array()
	var notes := [[392.0, 0.28], [370.0, 0.28], [349.0, 0.28], [330.0, 0.9]]
	var ph := 0.0
	for nt in notes:
		var n := _n(nt[1])
		for i in n:
			var k := float(i) / n
			var f: float = nt[0] * (1.0 + (0.03 * sin(k * 40.0) if nt[1] > 0.5 else 0.0))
			ph += f / RATE
			var saw := 2.0 * fmod(ph, 1.0) - 1.0
			s.append(saw * minf(k * 10.0, 1.0) * (1.0 - k * 0.6) * 0.3)
	return _wav(s)

## 過關：往上的小琶音
static func win() -> AudioStreamWAV:
	var s := PackedFloat32Array()
	for f in [523.0, 659.0, 784.0, 1047.0]:
		var n := _n(0.13)
		var ph := 0.0
		for i in n:
			var k := float(i) / n
			ph += TAU * f / RATE
			s.append((sin(ph) + 0.3 * sin(ph * 2.0)) * (1.0 - k * 0.7) * 0.35)
	return _wav(s)

static func _buf(sec: float) -> PackedFloat32Array:
	var s := PackedFloat32Array()
	s.resize(_n(sec))
	return s

static func _hz(note: int) -> float:
	return 440.0 * pow(2.0, (note - 69) / 12.0)

## 在 buf 的第 at 秒加一顆「敲／撥」出來的音：基音加兩個泛音，敲下去之後很快變小。
## bright 越大泛音越多（木琴亮、撥弦悶）；wrap：超出尾巴的部分繞回開頭（循環音樂用，接縫才聽不出來）
static func _note(buf: PackedFloat32Array, at: float, note: int, dur: float, amp: float, bright := 0.35, wrap := false) -> void:
	var f := _hz(note)
	var n := _n(dur)
	var start := _n(at)
	var size := buf.size()
	for j in n:
		var i := start + j
		if i >= size:
			if not wrap:
				break
			i %= size
		var t := float(j) / RATE
		var env := minf(float(j) / 40.0, 1.0) * exp(-t * 5.0 / dur)
		buf[i] += (sin(TAU * f * t) + bright * sin(TAU * f * 2.0 * t) * exp(-t * 8.0) + bright * 0.5 * sin(TAU * f * 3.0 * t) * exp(-t * 14.0)) * env * amp

## 一小撮雜訊（木魚、小鼓、雪堆）：tone 越小越悶
static func _noise(buf: PackedFloat32Array, at: float, dur: float, amp: float, tone: float, seed: int, wrap := false) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = seed
	var n := _n(dur)
	var start := _n(at)
	var size := buf.size()
	var lp := 0.0
	for j in n:
		var i := start + j
		if i >= size:
			if not wrap:
				break
			i %= size
		lp = lerpf(lp, r.randf_range(-1.0, 1.0), tone)
		buf[i] += lp * exp(-float(j) / n * 5.0) * amp

## 滑音（口哨、「欸？」）：頻率從 f0 滑到 f1
static func _glide(buf: PackedFloat32Array, at: float, f0: float, f1: float, dur: float, amp: float) -> void:
	var n := _n(dur)
	var start := _n(at)
	var ph := 0.0
	for j in n:
		if start + j >= buf.size():
			break
		var k := float(j) / n
		ph += TAU * lerpf(f0, f1, k) / RATE
		buf[start + j] += sin(ph) * sin(k * PI) * amp

## 撞到雪人（雪人頭扣在頭上）：木頭敲一下的「咚」
static func bonk() -> AudioStreamWAV:
	var s := _buf(0.35)
	_glide(s, 0.0, 300.0, 120.0, 0.16, 0.9)
	_note(s, 0.0, 55, 0.3, 0.5, 0.8)
	_noise(s, 0.0, 0.03, 0.5, 0.6, 5)
	return _wav(s)

## 栽進雪堆：悶悶的「噗」
static func poof() -> AudioStreamWAV:
	var s := _buf(0.4)
	_noise(s, 0.0, 0.38, 0.9, 0.08, 9)
	_glide(s, 0.0, 140.0, 70.0, 0.2, 0.5)
	return _wav(s)

## 差一點：往下滑的口哨
static func miss() -> AudioStreamWAV:
	var s := _buf(0.45)
	_glide(s, 0.0, 1100.0, 420.0, 0.42, 0.3)
	return _wav(s)

## 家豪啄飼料：兩下很短的「篤篤」
static func peck() -> AudioStreamWAV:
	var s := _buf(0.2)
	_note(s, 0.0, 91, 0.05, 0.4, 0.9)
	_note(s, 0.09, 93, 0.05, 0.4, 0.9)
	return _wav(s)

## 守衛看到腳邊的香蕉皮「？」：往上的兩顆音
static func huh() -> AudioStreamWAV:
	var s := _buf(0.5)
	_note(s, 0.0, 69, 0.2, 0.35)
	_note(s, 0.14, 76, 0.35, 0.35)
	return _wav(s)

## 追不上了：往下垂的兩顆音
static func sigh() -> AudioStreamWAV:
	var s := _buf(0.8)
	_note(s, 0.0, 67, 0.35, 0.3, 0.2)
	_note(s, 0.28, 62, 0.5, 0.3, 0.2)
	return _wav(s)

## 踩上薄冰的「喀喀喀…」：一串越來越密的小裂聲
static func creak() -> AudioStreamWAV:
	var s := _buf(0.9)
	var at := 0.0
	for c in 7:
		_noise(s, at, 0.03, 0.55, 0.9, 20 + c)
		at += 0.2 - c * 0.02
	return _wav(s)

## 連環撞：兩下接在一起的撞擊加一顆亮音
static func carom() -> AudioStreamWAV:
	var s := _buf(0.5)
	_glide(s, 0.0, 260.0, 130.0, 0.12, 0.8)
	_glide(s, 0.1, 320.0, 150.0, 0.12, 0.8)
	_note(s, 0.1, 84, 0.35, 0.3, 0.6)
	return _wav(s)

## 按下開始：一聲抖動的哨子
static func go() -> AudioStreamWAV:
	var s := _buf(0.5)
	var ph := 0.0
	for i in s.size():
		var k := float(i) / s.size()
		ph += TAU * (1900.0 + 140.0 * sin(k * 150.0)) / RATE
		s[i] = sin(ph) * minf(k * 20.0, 1.0) * (1.0 - k * k) * 0.28
	return _wav(s)

# ---- 配樂：兩首都是四小節（Cm｜Cm｜Fm｜G），每個八分音符 0.3 秒，一共 9.6 秒
const BGM_STEP := 0.3

static func _loop(s: PackedFloat32Array) -> AudioStreamWAV:
	var w := _wav(s)
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = s.size()
	return w

## 準備階段的配樂：躡手躡腳。撥弦低音一拍一顆，上面零星幾顆撥弦
static func bgm_plan() -> AudioStreamWAV:
	var bass := [36, -1, 43, -1,  36, -1, 43, 46,  41, -1, 48, -1,  43, -1, 47, -1]
	var mel := [60, -1, 63, -1, 67, -1, 66, 67,  72, -1, -1, -1, 70, -1, 67, -1,
		65, -1, 68, -1, 72, -1, 71, 72,  74, -1, -1, 71, 67, -1, 62, -1]
	var s := _buf(mel.size() * BGM_STEP)
	for i in bass.size():
		if bass[i] >= 0:
			_note(s, i * BGM_STEP * 2.0, bass[i], 0.5, 0.42, 0.5, true)
	for i in mel.size():
		if mel[i] >= 0:
			_note(s, i * BGM_STEP, mel[i], 0.28, 0.24, 0.25, true)
	return _loop(s)

## 開打之後的配樂：同一段和弦的熱鬧版。低音每個八分音符都走、木琴高八度加花、反拍木魚、二四拍小鼓
static func bgm_run() -> AudioStreamWAV:
	var roots := [36, 36, 41, 43]
	var mel := [72, 75, 79, 75, 72, 75, 79, 78,  84, 79, 75, 79, 82, 79, 75, 72,
		77, 80, 84, 80, 77, 80, 84, 83,  86, 83, 79, 83, 86, 83, 79, 74]
	var s := _buf(mel.size() * BGM_STEP)
	for i in mel.size():
		var root: int = roots[i >> 3]
		var walk: int = [0, 7, 12, 7][i % 4]
		_note(s, i * BGM_STEP, root + walk, 0.3, 0.36, 0.5, true)
		_note(s, i * BGM_STEP, mel[i], 0.3, 0.20, 0.8, true)
		if i % 2 == 1:
			_note(s, i * BGM_STEP, 96, 0.05, 0.10, 1.0, true)                 # 反拍的木魚
		if i % 4 == 2:
			_noise(s, i * BGM_STEP, 0.12, 0.16, 0.7, 40 + i, true)           # 二、四拍的小鼓
	return _loop(s)

## （舊的背景音樂，方波的版本；現在不用了，留著對照）
static func bgm() -> AudioStreamWAV:
	var bpm := 120.0
	var beat := 60.0 / bpm
	var melody := [72, 74, 76, 79, 76, 74, 72, -1, 74, 76, 79, 81, 79, 76, 74, -1,
		76, 79, 81, 84, 81, 79, 76, 74, 72, 74, 76, 74, 72, -1, 67, -1]
	var bass := [48, 48, 55, 55, 50, 50, 55, 55, 52, 52, 57, 57, 53, 53, 55, 55]
	var total := int(melody.size() * beat * 0.5 * RATE)
	var s := PackedFloat32Array()
	s.resize(total)
	var step := int(beat * 0.5 * RATE)
	for i in melody.size():
		var note: int = melody[i]
		if note < 0:
			continue
		var f := 440.0 * pow(2.0, (note - 69) / 12.0)
		for j in step:
			var k := float(j) / step
			var env := minf(k * 30.0, 1.0) * (1.0 - k) * 0.9
			var ph := f * float(j) / RATE
			var sq := 1.0 if fmod(ph, 1.0) < 0.5 else -1.0
			s[i * step + j] += sq * env * 0.12
	var bstep := int(beat * RATE)
	for i in bass.size():
		var f := 440.0 * pow(2.0, (bass[i] - 69) / 12.0)
		for j in bstep:
			var k := float(j) / bstep
			s[i * bstep + j] += sin(TAU * f * float(j) / RATE) * (1.0 - k * 0.7) * 0.22
	var w := _wav(s)
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = total
	return w
