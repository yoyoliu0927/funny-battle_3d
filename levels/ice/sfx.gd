extends RefCounted
## 冰雪島的音效：全部用程式即時合成（不用音效檔），先有聲音、之後再換成正式素材。
## 用法：var s := Sfx.make_all()  →  {"pop": AudioStreamWAV, ...}

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
		"bgm": bgm(),
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

## 背景音樂：輕快的 8 小節循環（五聲音階旋律＋低音），8 秒
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
