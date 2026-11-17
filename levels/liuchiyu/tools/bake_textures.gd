extends SceneTree
## 預先畫好油畫關卡用的貼圖（只要跑一次，結果存成 PNG；shader 讀貼圖就好，不用每個像素每一幀重算雜訊）。
## 用法：Godot --headless --path . -s res://levels/liuchiyu/tools/bake_textures.gd
## 產生的檔案在 levels/liuchiyu/assets/textures/：
##   ground_shade.png  地面陰影色的筆觸（可以無縫拼接，一張 = 地上 8 公尺見方）
##   ground_sun.png    光斑裡的暖色筆觸；alpha = 這一筆的亂數（shader 用它決定光斑裡要畫幾筆，沒有筆觸的地方是 1）
##   noise4.png        四個頻率的平滑雜訊（R 最粗 → A 最細），可以無縫拼接，給岩石、樹幹用
##   water.png         水面：R = 波浪的高低、G = 水面上亮亮的網狀光紋（焦散）、B = 慢慢變化的大塊明暗；可以無縫拼接，給海、水池、河用
## 只想重畫其中一張：在最後加  -- --only=water（或 ground、noise）

const OUT := "res://levels/liuchiyu/assets/textures/"
const N := 512
const PX_PER_M := 64.0      # ground 貼圖：一張 512 像素 = 8 公尺

# 跟 oil_ground.gdshader 原本的顏色一樣
const SH := [Color(0.40, 0.17, 0.15), Color(0.31, 0.21, 0.38), Color(0.20, 0.31, 0.17), Color(0.47, 0.25, 0.11), Color(0.35, 0.21, 0.14)]
const SU := [Color(0.86, 0.50, 0.14), Color(0.90, 0.70, 0.22), Color(0.84, 0.60, 0.18), Color(0.80, 0.38, 0.14), Color(0.62, 0.64, 0.24)]

var buf := PackedFloat32Array()
var rng := RandomNumberGenerator.new()

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.substr(7)
	if only == "" or only == "ground":
		_bake_ground_shade()
		_bake_ground_sun()
	if only == "" or only == "noise":
		_bake_noise()
	if only == "" or only == "water":
		_bake_water()
	print("BAKE: done")
	quit(0)

func _clear(c: Color, a: float) -> void:
	buf.resize(N * N * 4)
	for i in N * N:
		buf[i * 4] = c.r
		buf[i * 4 + 1] = c.g
		buf[i * 4 + 2] = c.b
		buf[i * 4 + 3] = a

## 一筆顏料：中心 (cx, cy)，方向 ang，半長 l、半寬 w（像素），兩頭稍微收尖；超出邊界的部分從另一邊接回來（無縫）
func _stamp(cx: float, cy: float, ang: float, l: float, w: float, col: Color, a: float) -> void:
	var c := cos(ang)
	var s := sin(ang)
	var r := int(ceil(l + 2.0))
	var x0 := int(floor(cx))
	var y0 := int(floor(cy))
	for py in range(y0 - r, y0 + r + 1):
		var dy := py + 0.5 - cy
		for px in range(x0 - r, x0 + r + 1):
			var dx := px + 0.5 - cx
			var u := dx * c + dy * s
			var v := -dx * s + dy * c
			var au := absf(u)
			if au > l + 1.0:
				continue
			var t := minf(au / l, 1.0)
			var d := maxf(au - l, absf(v) - w * (1.0 - 0.55 * t * t * t * t))
			var cov := clampf(0.5 - d, 0.0, 1.0)
			if cov <= 0.0:
				continue
			var i := (posmod(py, N) * N + posmod(px, N)) * 4
			buf[i] = lerpf(buf[i], col.r, cov)
			buf[i + 1] = lerpf(buf[i + 1], col.g, cov)
			buf[i + 2] = lerpf(buf[i + 2], col.b, cov)
			buf[i + 3] = lerpf(buf[i + 3], a, cov)

## 筆的方向隨位置慢慢轉（用整數週期的 sin，才拼得起來）
func _flow(x: float, y: float, base: float) -> float:
	var fx := x / N * TAU
	var fy := y / N * TAU
	return base + 0.7 * sin(fx * 2.0 + 1.3) * cos(fy + 0.4) + 0.4 * sin(fy * 3.0 - fx)

func _layer(count: int, base_ang: float, len_m: Vector2, wid_m: Vector2, cols: Array, with_rand: bool) -> void:
	for k in count:
		var x := rng.randf() * N
		var y := rng.randf() * N
		var l := rng.randf_range(len_m.x, len_m.y) * PX_PER_M
		var w := rng.randf_range(wid_m.x, wid_m.y) * PX_PER_M
		var col: Color = cols[rng.randi() % cols.size()]
		var v := rng.randf_range(0.92, 1.06)
		col = Color(col.r * v, col.g * v, col.b * v)
		var a := rng.randf() if with_rand else 1.0
		_stamp(x, y, _flow(x, y, base_ang) + rng.randf_range(-0.15, 0.15), l, w, col, a)

func _save(name: String) -> void:
	var img := Image.create_empty(N, N, false, Image.FORMAT_RGBA8)
	for y in N:
		for x in N:
			var i := (y * N + x) * 4
			img.set_pixel(x, y, Color(buf[i], buf[i + 1], buf[i + 2], buf[i + 3]))
	img.save_png(ProjectSettings.globalize_path(OUT + name))
	print("BAKE: ", OUT + name)

func _bake_ground_shade() -> void:
	rng.seed = 1201
	_clear(SH[4], 1.0)
	# 兩層：大筆觸鋪滿底，小一點的筆觸疊在上面（原本是 shader 每個像素算三層）
	_layer(520, 0.3, Vector2(0.30, 0.42), Vector2(0.08, 0.11), [SH[0], SH[4], SH[3], SH[0]], false)
	# 第二層顏色往底色靠一點：色相豐富，但明暗、彩度接近，地面才不會花
	var soft: Array = []
	for c in SH:
		soft.append((c as Color).lerp(SH[4], 0.45))
	_layer(460, 1.1, Vector2(0.20, 0.30), Vector2(0.06, 0.085), soft, false)
	_save("ground_shade.png")

func _bake_ground_sun() -> void:
	rng.seed = 1202
	_clear(SU[0], 1.0)      # 沒有筆觸的地方 alpha = 1（亂數門檻永遠不會過）
	_layer(560, 0.8, Vector2(0.24, 0.36), Vector2(0.07, 0.10), [SU[0], SU[2], SU[3]], true)
	_layer(560, 2.0, Vector2(0.16, 0.26), Vector2(0.05, 0.075), [SU[0], SU[1], SU[2], SU[4]], true)
	_save("ground_sun.png")

## 可以無縫拼接的平滑雜訊：格子每 period 格繞回來
func _vnoise(x: float, y: float, period: int, salt: int) -> float:
	var ix := int(floor(x))
	var iy := int(floor(y))
	var fx := x - ix
	var fy := y - iy
	fx = fx * fx * (3.0 - 2.0 * fx)
	fy = fy * fy * (3.0 - 2.0 * fy)
	var a := _h(posmod(ix, period), posmod(iy, period), salt)
	var b := _h(posmod(ix + 1, period), posmod(iy, period), salt)
	var c := _h(posmod(ix, period), posmod(iy + 1, period), salt)
	var d := _h(posmod(ix + 1, period), posmod(iy + 1, period), salt)
	return lerpf(lerpf(a, b, fx), lerpf(c, d, fx), fy)

func _h(x: int, y: int, salt: int) -> float:
	return float(hash(Vector3i(x, y, salt)) % 100003) / 100003.0

func _bake_noise() -> void:
	var size := 256
	var cells := [4, 8, 16, 32]
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var v := [0.0, 0.0, 0.0, 0.0]
			for k in 4:
				var sc := float(cells[k]) / size
				v[k] = _vnoise(x * sc, y * sc, cells[k], 31 + k)
			img.set_pixel(x, y, Color(v[0], v[1], v[2], v[3]))
	img.save_png(ProjectSettings.globalize_path(OUT + "noise4.png"))
	print("BAKE: ", OUT + "noise4.png")

## 水面貼圖。全部用整數週期算，左右上下都接得起來
func _bake_water() -> void:
	var size := 512
	# 波浪：幾組不同方向的正弦波疊起來（方向用整數，繞一圈剛好接回來）
	var waves := [[Vector2(3, 1), 1.0, 0.3], [Vector2(-1, 4), 0.8, 1.9], [Vector2(5, -2), 0.6, 4.1], [Vector2(2, 6), 0.45, 2.6], [Vector2(-7, 3), 0.3, 5.3]]
	# 焦散：每格一個亂數點（8×8 格，會繞回來），離最近兩點的距離差很小的地方 = 一條亮線
	var cells := 8
	var pts: Array[Vector2] = []
	var r := RandomNumberGenerator.new()
	r.seed = 4040
	for i in cells * cells:
		pts.append(Vector2(r.randf_range(0.15, 0.85), r.randf_range(0.15, 0.85)))
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var wsum := 0.0
	for w in waves:
		wsum += float(w[1])
	for y in size:
		for x in size:
			var u := float(x) / size
			var v := float(y) / size
			var h := 0.0
			for w in waves:
				var d: Vector2 = w[0]
				h += sin(TAU * (d.x * u + d.y * v) + float(w[2])) * float(w[1])
			h = h / wsum * 0.5 + 0.5
			var cu := u * cells
			var cv := v * cells
			var ix := int(floor(cu))
			var iy := int(floor(cv))
			var f1 := 9.0
			var f2 := 9.0
			for oy in range(-1, 2):
				for ox in range(-1, 2):
					var gx := ix + ox
					var gy := iy + oy
					var pt := pts[posmod(gy, cells) * cells + posmod(gx, cells)]
					var dd := Vector2(gx + pt.x - cu, gy + pt.y - cv).length()
					if dd < f1:
						f2 = f1
						f1 = dd
					elif dd < f2:
						f2 = dd
			var line := 1.0 - smoothstep(0.0, 0.09, f2 - f1)
			var b := _vnoise(u * 4.0, v * 4.0, 4, 91)
			img.set_pixel(x, y, Color(h, line, b, 1.0))
	img.save_png(ProjectSettings.globalize_path(OUT + "water.png"))
	print("BAKE: ", OUT + "water.png")
