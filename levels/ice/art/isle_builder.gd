extends RefCounted
## 冰雪島「地圖本體」的網格（ice_world.gd 用 preload 拿來用，不是關卡腳本）。
## 整張地圖是一塊浮在海上的雪原：build_top() 做頂面（雪和冰同一張網格，邊緣垂下一圈扇形的厚雪簷），
## build_cliff() 做雪簷底下一層一層的岩壁（一路插進海裡）。表面的質感都在著色器和貼圖裡。
## 輪廓用一個字典描述：{"c": 中心 Vector2(x, z), "rx": 橫向半徑, "rz": 縱向半徑, "seed": 亂數,
##   "pow": 2 = 橢圓、越大越方, "wob": 輪廓歪扭的程度, "depth": 岩壁往下多深, "lobe": 雪簷一片多寬}

const BAND_H := 1.25            # 一層岩層的高度（公尺）
const BANDS_PER_TILE := 9.0     # cliff_strata.png 一張貼圖畫了 9 層

static func hash1(n: float) -> float:
	return fposmod(sin(n * 127.1 + 311.7) * 43758.5453, 1.0)

## 從中心往 a 這個方向（弧度，x = cos、z = sin）到地圖邊緣的距離
static func radius(o: Dictionary, a: float) -> float:
	var n: float = o.get("pow", 2.5)
	var ca := absf(cos(a)) / float(o.rx)
	var sa := absf(sin(a)) / float(o.rz)
	var base := pow(pow(ca, n) + pow(sa, n), -1.0 / n)
	var s: float = o.get("seed", 1.0)
	var w: float = o.get("wob", 1.0)
	var k := 1.0 + w * (0.050 * sin(2.0 * a + s) + 0.040 * sin(3.0 * a + s * 2.1) + 0.030 * sin(5.0 * a + s * 3.3)
		+ 0.018 * sin(8.0 * a + s * 1.7) + 0.010 * sin(13.0 * a + s * 4.9))
	return base * k

## 邊緣上的點（inset > 0 = 往裡面縮幾公尺）
static func rim_point(o: Dictionary, a: float, inset := 0.0) -> Vector2:
	var c: Vector2 = o.c
	return c + Vector2(cos(a), sin(a)) * (radius(o, a) - inset)

## (x, z) 在不在地圖上（margin > 0 = 要離邊緣至少這麼遠）
static func inside(o: Dictionary, x: float, z: float, margin := 0.0) -> bool:
	var c: Vector2 = o.c
	var d := Vector2(x - c.x, z - c.y)
	return d.length() < radius(o, atan2(d.y, d.x)) - margin

## 雪簷垂下來的長度（一片一片圓弧形，長短不一，像蛋糕上流下來的糖霜）
static func scallop(o: Dictionary, a: float) -> float:
	var s: float = o.get("seed", 1.0)
	var per := (float(o.rx) + float(o.rz)) * 0.5
	var n := maxf(roundf(PI * per / float(o.get("lobe", 2.3))), 3.0)
	var ph := a * n + 0.8 * sin(a * 3.0 + s) + 0.5 * sin(a * 7.0 + s * 2.0)
	var lobe := pow(absf(sin(ph)), 0.65)
	var size := 0.68 + 0.32 * sin(a * 5.0 + s * 3.1) * sin(a * 2.0 + s)
	return 0.32 + 1.30 * lobe * size

static func _normals(verts: PackedVector3Array, idx: PackedInt32Array) -> PackedVector3Array:
	var n := PackedVector3Array()
	n.resize(verts.size())
	for i in range(0, idx.size(), 3):
		var a := verts[idx[i]]
		var fn := (verts[idx[i + 2]] - a).cross(verts[idx[i + 1]] - a)   # Godot：順時針那一面是正面
		n[idx[i]] += fn
		n[idx[i + 1]] += fn
		n[idx[i + 2]] += fn
	for i in n.size():
		n[i] = n[i].normalized() if n[i].length_squared() > 1e-12 else Vector3.UP
	return n

static func _grid_indices(cols: int, rows: int, wrap: bool) -> PackedInt32Array:
	var idx := PackedInt32Array()
	var n := cols if wrap else cols - 1
	for si in n:
		var sj := (si + 1) % cols
		for ri in rows - 1:
			var a := si * rows + ri
			var b := si * rows + ri + 1
			var c := sj * rows + ri + 1
			var d := sj * rows + ri
			idx.append_array([a, b, c, a, c, d])
	return idx

# 雪簷的剖面：[往外, 往下, 被扇形拉長的程度]（單位：公尺 × lip）
const LIP := [[0.25, -0.02, 0.0], [0.48, -0.09, 0.0], [0.66, -0.24, 0.25], [0.74, -0.44, 0.6], [0.70, -0.66, 1.0],
	[0.54, -0.84, 1.0], [0.30, -0.90, 1.0], [0.02, -0.78, 1.0], [-0.42, -0.50, 0.6]]

## 頂面＋雪簷。hf = Callable(x, z) -> 高度
static func build_top(o: Dictionary, hf: Callable, segs: int, rings: int, lip := 1.0) -> ArrayMesh:
	var c: Vector2 = o.c
	var verts := PackedVector3Array()
	var rows := rings + 1 + LIP.size()
	for si in segs:
		var a := si * TAU / segs
		var dir := Vector2(cos(a), sin(a))
		var r := radius(o, a)
		for ri in rings + 1:
			var p := c + dir * r * (float(ri) / rings)
			verts.append(Vector3(p.x, hf.call(p.x, p.y), p.y))
		var rim := c + dir * r
		var y0: float = hf.call(rim.x, rim.y)
		var sc := scallop(o, a)
		for l in LIP:
			var st: float = l[2]
			var q := rim + dir * float(l[0]) * lip * lerpf(1.0, 0.8 + 0.25 * sc, st)
			verts.append(Vector3(q.x, y0 + float(l[1]) * lip * lerpf(1.0, sc, st), q.y))
	var idx := _grid_indices(segs, rows, true)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = _normals(verts, idx)
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

## 岩壁：從雪簷底下開始，一層一層往下（每層中間鼓出來、層和層之間凹一道縫），底部稍微往外張，插進海裡。
## rim_y = Callable(角度) -> 邊緣的高度。UV = 岩層貼圖座標，UV2.x = 離頂面幾公尺，COLOR = 每層的明暗
static func build_cliff(o: Dictionary, rim_y: Callable, segs: int, rows: int) -> ArrayMesh:
	var c: Vector2 = o.c
	var depth: float = o.get("depth", 4.5)
	var s: float = o.get("seed", 1.0)
	var per := (float(o.rx) + float(o.rz)) * 0.5
	var tiles := maxf(roundf(TAU * per / (BAND_H * BANDS_PER_TILE)), 1.0)
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var cols := PackedColorArray()
	var nrows := rows + 2
	for si in segs + 1:
		var a := (si % segs) * TAU / segs
		var dir := Vector2(cos(a), sin(a))
		var r := radius(o, a)
		var y0: float = rim_y.call(a)
		# 第一圈：藏在雪底下的平台，從哪個角度都看不穿
		var q0 := c + dir * maxf(r - 1.8, 0.1)
		verts.append(Vector3(q0.x, y0 - 0.22, q0.y))
		uvs.append(Vector2(float(si) / segs * tiles, -0.05))
		uv2.append(Vector2(0.0, 0.0))
		cols.append(Color(1, 1, 1))
		for ri in rows + 1:
			var d := depth * float(ri) / rows
			# 岩層座標：繞著地圖微微起伏，所以層不是死板的水平線
			var bc := d / BAND_H + 0.30 * sin(a * 3.0 + s) + 0.18 * sin(a * 5.0 + s * 2.2)
			var b := floorf(bc)
			var v := bc - b
			var off := (0.26 * pow(sin(PI * v), 0.5) - 0.12) + (hash1(b * 7.3 + s) - 0.4) * 0.5
			off += 0.22 * sin(a * 9.0 + b * 2.1 + s) * sin(a * 4.0 - b)        # 每層凹凹凸凸，不是完美的圓弧
			var p := c + dir * (r - 0.30 + off + 0.12 * d)
			verts.append(Vector3(p.x, y0 - 0.25 - d, p.y))
			uvs.append(Vector2(float(si) / segs * tiles, bc / BANDS_PER_TILE))
			uv2.append(Vector2(d, 0.0))
			var tint := 0.84 + 0.26 * hash1(b * 3.1 + s * 2.0)
			cols.append(Color(tint, tint, tint))
	var idx := _grid_indices(segs + 1, nrows, false)
	var nrm := _normals(verts, idx)
	# 接縫（第一欄和最後一欄是同一條線）：法線取平均
	for ri in nrows:
		var m := (nrm[ri] + nrm[segs * nrows + ri]).normalized()
		nrm[ri] = m
		nrm[segs * nrows + ri] = m
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = nrm
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TEX_UV2] = uv2
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
