extends SceneTree
## 臉的結構檢查（不用畫面）：手繪表情那一片是不是真的「長在臉上」。
## Godot --headless --path <專案> --script res://levels/ice/tests/face_check.gd
##  1. 骨架底下每個有蒙皮的零件都要指到那個骨架（沒指到＝不會跟著骨頭動，頭一轉就分家）。
##  2. 表情那一片每個點都只綁頭骨。
##  3. 每一種表情圖上有畫東西的地方：正下方一定要有臉（不能懸在頭外面），
##     離臉的表面不超過 GAP_MAX（跨過劉海、鬍子邊緣的那一小條例外，但比例和高度都有上限），
##     朝向和那裡的臉差太多的比例不超過 TILT_SHARE。
const RB := preload("res://levels/ice/rescue_battle.gd")
const GAP_MAX := 0.003           # 「貼在臉上」的標準（模型座標，頭寬 0.32；換成場上的大小大約 1 公分）。舊的平面貼片整片離臉 0.013
const TILT_DEG := 35.0
const TILT_SHARE := 0.08
const GAP_CAP := 0.022           # 再怎樣也不能超過這個（頭上最高的一階高低差）
const GAP_SHARE := 0.15          # 跨過劉海、鬍子邊緣（臉上本來就有的高低差）的那一小條，最多佔這麼多
const CLIP_SHARE := 0.02
const SAMPLES := 72
var fails := 0
var checks := 0

func ok(cond: bool, text: String) -> void:
	checks += 1
	if not cond:
		fails += 1
	print("  %s  %s" % ["ok  " if cond else "FAIL", text])

func _tris(m: Mesh) -> Array:
	var a := m.surface_get_arrays(0)
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var i: PackedInt32Array = a[Mesh.ARRAY_INDEX]
	var out := []
	for t in range(0, i.size(), 3):
		out.append([v[i[t]], v[i[t + 1]], v[i[t + 2]]])
	return out

## 從正前方往臉上看，(x, y) 這一點最前面的表面：回傳 [z, 法線]，沒有東西就是 []
func _front(tris: Array, x: float, y: float) -> Array:
	var best := []
	for t in tris:
		var a: Vector3 = t[0]
		var b: Vector3 = t[1]
		var d: Vector3 = t[2]
		if x < minf(a.x, minf(b.x, d.x)) - 1e-5 or x > maxf(a.x, maxf(b.x, d.x)) + 1e-5 or y < minf(a.y, minf(b.y, d.y)) - 1e-5 or y > maxf(a.y, maxf(b.y, d.y)) + 1e-5:
			continue
		var den := (b.y - d.y) * (a.x - d.x) + (d.x - b.x) * (a.y - d.y)
		if absf(den) < 1e-9:
			continue
		var w0 := ((b.y - d.y) * (x - d.x) + (d.x - b.x) * (y - d.y)) / den
		var w1 := ((d.y - a.y) * (x - d.x) + (a.x - d.x) * (y - d.y)) / den
		var w2 := 1.0 - w0 - w1
		if w0 < -1e-4 or w1 < -1e-4 or w2 < -1e-4:
			continue
		var z := a.z * w0 + b.z * w1 + d.z * w2
		if best.is_empty() or z > best[0]:
			var n := (b - a).cross(d - a).normalized()
			if n.z < 0.0:
				n = -n
			best = [z, n]
	return best

func _initialize() -> void:
	for model in [RB.MODEL_WORKER, RB.MODEL_GUARD]:
		var id := ""
		for k in RB.LOOKS:
			if String(k).begins_with("守衛") == (model == RB.MODEL_GUARD):
				id = k
				break
		print("== %s（造型：%s）" % [String(model).get_file(), id])
		var m: Node3D = (load(model) as PackedScene).instantiate()
		var w := Node3D.new()
		w.add_child(m)
		w.set_meta("source", model)
		root.add_child(w)
		var rig: Dictionary = RB.style_mini(w, RB.LOOKS[id], id)
		var sk: Skeleton3D = rig.skel
		var hb: int = rig.bones["head"]
		for c in sk.find_children("*", "MeshInstance3D", true, false):
			var mi := c as MeshInstance3D
			if mi.skin == null:
				continue
			ok(mi.get_node_or_null(mi.skeleton) == sk, "%s 有指到骨架（skeleton = \"%s\"）" % [mi.name, mi.skeleton])
		var face: MeshInstance3D = rig.face
		ok(face.get_parent() == sk and face.skin == (sk.find_child("head*", false, false) as MeshInstance3D).skin, "表情和頭的網格掛在同一個骨架、用同一套蒙皮")
		var fa := face.mesh.surface_get_arrays(0)
		var bones = fa[Mesh.ARRAY_BONES]
		var wts = fa[Mesh.ARRAY_WEIGHTS]
		var only_head := true
		for i in range(0, bones.size(), 4):
			if bones[i] != hb or absf(wts[i] - 1.0) > 0.001 or wts[i + 1] > 0.001:
				only_head = false
		ok(only_head, "表情每個點都只綁頭骨（%d 個點）" % (bones.size() / 4))
		var head_tris := _tris(rig.head_main)
		var patch_tris := _tris(face.mesh)
		var rest := sk.get_bone_global_rest(hb).origin
		for kind in RB.FACES:
			var tex := load(RB.FACES[kind]) as Texture2D
			var img := tex.get_image() if tex else null
			if img == null or img.is_empty():
				ok(false, "%s：讀不到表情圖" % kind)
				continue
			if img.is_compressed():
				img.decompress()
			var n := 0
			var clipped := 0
			var hang := 0
			var far := 0
			var tilt := 0
			var gap_max := 0.0
			for sy in SAMPLES:
				for sx in SAMPLES:
					var u := (sx + 0.5) / SAMPLES
					var v := (sy + 0.5) / SAMPLES
					if img.get_pixel(int(u * img.get_width()), int(v * img.get_height())).a < 0.5:
						continue
					n += 1
					var x := rest.x + RB.FACE_AT.x + (u - 0.5) * RB.FACE_SIZE
					var y := rest.y + RB.FACE_AT.y + (0.5 - v) * RB.FACE_SIZE
					var p := _front(patch_tris, x, y)
					var h := _front(head_tris, x, y)
					if p.is_empty():
						clipped += 1          # 超出頭的邊緣：那一小塊不畫（不會懸在空中）
						continue
					if h.is_empty():
						hang += 1
						continue
					var gap: float = p[0] - h[0]
					gap_max = maxf(gap_max, gap)
					if gap < 0.0 or gap > GAP_MAX:
						far += 1
					if rad_to_deg((p[1] as Vector3).angle_to(h[1])) > TILT_DEG:
						tilt += 1
			ok(n > 0 and hang == 0, "%s：有畫東西的 %d 個取樣點底下都有臉（懸空 %d 點）" % [kind, n, hang])
			ok(clipped <= n * CLIP_SHARE, "%s：超出頭的邊緣、不畫的 %d 點（%.1f%%，上限 %.0f%%）" % [kind, clipped, 100.0 * clipped / maxf(n, 1), CLIP_SHARE * 100.0])
			ok(gap_max <= GAP_CAP and far <= n * GAP_SHARE, "%s：離臉的表面最多 %.4f（上限 %.3f）；沒貼著臉（超過 %.3f）的 %d 點（%.1f%%，上限 %.0f%%：跨過劉海、鬍子邊緣的地方）" % [kind, gap_max, GAP_CAP, GAP_MAX, far, 100.0 * far / maxf(n, 1), GAP_SHARE * 100.0])
			ok(tilt <= n * TILT_SHARE, "%s：朝向和臉差超過 %d 度的 %d 點（%.1f%%，上限 %.0f%%）" % [kind, int(TILT_DEG), tilt, 100.0 * tilt / maxf(n, 1), TILT_SHARE * 100.0])
		w.queue_free()
	print("FACE_CHECK: %s（%d 項檢查，%d 項沒過）" % ["ALL PASS" if fails == 0 else "FAIL", checks, fails])
	quit(0 if fails == 0 else 1)
