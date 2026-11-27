extends RefCounted
## 把「不會動的模型」合併成一種材質一個面（所有平台都用；網頁版最吃的就是繪製次數）
##
## 為什麼：一個 .glb 模型常常拆成幾十個零件（一棟木樓 60 幾個），每個零件、每種材質都要畫一次，開影子再畫一次。
## 場上擺十幾棟就是上千次。把同一種材質的零件合成一個網格，整片只要畫「材質種類數」次，看起來完全一樣
## （頂點已經換到同一個座標系；用世界座標算花紋的著色器結果也不變）。
##
## 用法（蓋完場景之後呼叫一次）：
##   const StaticBatch := preload("res://scripts/static_batch.gd")
##   StaticBatch.merge(root, [模型1, 模型2, ...])     # 這些節點和它們的父節點之後都不會再移動
## 合併後原本的 MeshInstance3D 會被刪掉，其他節點（燈、文字、碰撞）留著。
## 不合併的：有動畫、骨架、形狀鍵、腳本的零件，半透明的材質，有設淡出（transparency）或可見距離的零件，藏起來的零件。
## 測試用：命令列加 -- --perf-nobatch 就完全不合併（拿來對照畫面一不一樣）
##
## 網頁版要注意：讀一個網格的頂點（SurfaceTool.append_from、surface_get_arrays）在網頁版要從顯示卡讀回來，
## 每讀一次整條繪圖管線都要停下來等（一次幾毫秒）；一座島幾百個零件，第一次蓋地圖光是這個就多好幾秒。
## 所以每個網格的每一面只讀一次，存在 _src（這次開遊戲都留著），之後合併都用存好的資料（見 source()）。
## 自己用陣列做出來的網格，資料本來就在手上：做的時候用 remember() 記起來，合併時完全不用讀顯示卡。

## 合併 pieces 底下所有可以合併的零件，結果掛在 root 底下（名字 "Batched"）。回傳合併掉幾個 MeshInstance3D
##   strict：只合「換了座標系看起來也一樣」的材質（整座島一起合的時候用；見 _local_space）
##   skip：這些節點（和底下的東西）不合（之後還會被程式移動、藏起來的）
##   cache：合好的結果留著，下次蓋出一模一樣的東西直接拿來用（選關地圖每次回來都重蓋，用這個）
static func merge(root: Node3D, pieces: Array, strict := false, skip := {}, cache := false) -> int:
	var r := _build(root, pieces, strict, skip, cache, "Batched")
	if r.is_empty():
		return 0
	for mi in r.done:
		mi.get_parent().remove_child(mi)
		mi.queue_free()
	return (r.done as Array).size()

## 遠景替身：跟 merge() 一樣合併，但原本的零件留著。鏡頭離替身比 far 遠的時候只畫替身（繪製次數少），
## 比 far 近的時候只畫原本的零件（一個一個切掉看不到的、照距離用簡化的網格）。切換是引擎照距離自動做的
## （替身設 visibility_range_begin，原本的零件把 visibility_parent 指到替身），兩邊同時只會有一邊。
## 用在世界地圖：整片地圖都在遠處，每座島只要畫幾次；走到島上時島和附近的島照原本的畫。回傳做好的替身（沒做是空的）
## （之後要改切換距離就改替身的 visibility_range_begin）
## 頂點很多的模型（掃描的大石頭一顆六萬多個頂點）不放進替身：它們自己有照距離簡化的網格（LOD），
## 合進替身反而變成遠遠的也要畫全部細節，做替身也慢（網頁版要先從顯示卡讀回來）
const PROXY_MAX_VERTS := 4000
static func proxy(root: Node3D, pieces: Array, far: float, strict := true, skip := {}) -> Array:
	# 只合認得出來的網格（程式每次重做的島面不合，不然網頁版每次都要從顯示卡讀）；結果不另外留（替身本身就一直留著，見 level_select 的 _keep_isles）
	var r := _build(root, pieces, strict, skip, false, "FarProxy", PROXY_MAX_VERTS, true)
	if r.is_empty():
		return []
	var meshes: Dictionary = r.meshes
	for nk in meshes:
		var p := meshes[nk] as MeshInstance3D
		p.visibility_range_begin = far
		p.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
	for mi in r.done:
		var m := mi as MeshInstance3D
		m.visibility_parent = m.get_path_to(meshes["%d|%d" % [m.cast_shadow, m.layers]])
	return meshes.values()

## 合併（merge、proxy 共用）：回傳 {meshes: "影子|圖層" → 做好的 MeshInstance3D, done: 被合進去的 MeshInstance3D}；沒合是 {}
static func _build(root: Node3D, pieces: Array, strict: bool, skip: Dictionary, cache: bool, name: String, max_verts := 0, stable_only := false) -> Dictionary:
	if root == null or not root.is_inside_tree() or "--perf-nobatch" in OS.get_cmdline_user_args():
		return {}
	var inv := root.global_transform.affine_inverse()
	var parts: Array = []      # [網格, 第幾面, 位置, 第幾組]
	var groups: Array = []     # 每一組：[材質, 影子, 圖層]
	var group_of := {}         # 材質＋影子＋圖層 → 第幾組
	var done: Array = []
	for p in pieces:
		if p == null or not is_instance_valid(p) or not (p as Node).is_inside_tree():
			continue
		_collect(p, inv, parts, groups, group_of, done, strict, skip, cache or stable_only, max_verts)
	if done.size() < 2:
		return {}
	var arrays: Array = []
	var ck := 0
	if cache:
		var sig := PackedStringArray([name])
		for pt in parts:
			sig.append("%s:%s:%d" % [_key(pt[0], pt[1]), pt[2], pt[3]])
		ck = "|".join(sig).hash()
		arrays = _results.get(ck, [])
	if arrays.size() != groups.size():
		var sts: Array = []
		for g in groups:
			sts.append(SurfaceTool.new())
		for pt in parts:
			(sts[pt[3]] as SurfaceTool).append_from(source(pt[0], pt[1]), 0, pt[2])
		arrays = []
		for st in sts:
			arrays.append((st as SurfaceTool).commit_to_arrays())
		if cache:
			_results[ck] = arrays
	var meshes := {}       # "影子|圖層" → MeshInstance3D
	for gi in groups.size():
		var g: Array = groups[gi]
		var nk := "%d|%d" % [g[1], g[2]]
		if not meshes.has(nk):
			var mi := MeshInstance3D.new()
			mi.name = name
			mi.mesh = ArrayMesh.new()
			if cache:
				mi.mesh.set_meta(&"batch_key", "batch:%d:%s" % [ck, nk])
			mi.cast_shadow = g[1]
			mi.layers = g[2]
			root.add_child(mi)
			meshes[nk] = mi
		var am: ArrayMesh = (meshes[nk] as MeshInstance3D).mesh
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays[gi])
		am.surface_set_material(am.get_surface_count() - 1, g[0])
		if cache:
			remember(am, am.get_surface_count() - 1, arrays[gi])
	return {"meshes": meshes, "done": done}

static func _collect(n: Node, inv: Transform3D, parts: Array, groups: Array, group_of: Dictionary, done: Array, strict: bool, skip: Dictionary, stable: bool, max_verts := 0) -> void:
	if skip.has(n):
		return
	if n is AnimationPlayer or n is AnimationTree or n is Skeleton3D:
		return
	if n.get_script() != null:
		return
	if n is Node3D and not (n as Node3D).visible:
		return
	if strict:
		for c in n.get_children():
			if c is AnimationMixer:
				return         # 模型裡有動畫播放器：它動的是旁邊的零件，整個模型都不合（一般的呼叫是呼叫的人自己挑好不會動的）
	for c in n.get_children():
		_collect(c, inv, parts, groups, group_of, done, strict, skip, stable, max_verts)
	if not n is MeshInstance3D:
		return
	var mi := n as MeshInstance3D
	if mi.mesh == null or mi.skin != null or mi.get_child_count() > 0:
		return
	if mi.mesh is ArrayMesh and (mi.mesh as ArrayMesh).get_blend_shape_count() > 0:
		return
	if mi.transparency > 0.0 or mi.visibility_range_end > 0.0 or mi.material_overlay != null:
		return
	if mi.mesh is PointMesh or not (mi.mesh is ArrayMesh or mi.mesh is PrimitiveMesh):
		return
	if max_verts > 0 and mi.mesh is ArrayMesh:
		var nv := 0
		for s in mi.mesh.get_surface_count():
			nv += (mi.mesh as ArrayMesh).surface_get_array_len(s)
		if nv > max_verts:
			return
	for s in mi.mesh.get_surface_count():
		if mi.mesh is ArrayMesh and (mi.mesh as ArrayMesh).surface_get_primitive_type(s) != Mesh.PRIMITIVE_TRIANGLES:
			return
		var m := mi.get_active_material(s)
		if _see_through(m) or (strict and _local_space(m)):
			return
		if stable and _key(mi.mesh, s).begins_with("#"):
			return             # 要留結果的合併：每次都重新做的網格（程式蓋的島面）認不出來是同一個，不合
	var xf := inv * mi.global_transform
	for s in mi.mesh.get_surface_count():
		var mat := mi.get_active_material(s)
		var key := "%d|%d|%d" % [mat.get_instance_id() if mat else 0, mi.cast_shadow, mi.layers]
		if not group_of.has(key):
			group_of[key] = groups.size()
			groups.append([mat, mi.cast_shadow, mi.layers])
		parts.append([mi.mesh, s, xf, int(group_of[key])])
	done.append(mi)

## 半透明的材質不合併（合併後前後順序會亂）
static func _see_through(m: Material) -> bool:
	if m == null:
		return false
	if m is BaseMaterial3D:
		return (m as BaseMaterial3D).transparency != BaseMaterial3D.TRANSPARENCY_DISABLED
	if m is ShaderMaterial and (m as ShaderMaterial).shader:
		var code := (m as ShaderMaterial).shader.code
		return code.contains("ALPHA") or code.contains("blend_")
	return m.next_pass != null

## 這個材質的樣子跟「物件自己的座標系」有關（合到別的座標系就會變樣）：
## 物件座標的三面投影、看板、照物件距離淡出；著色器在 vertex() 裡改頂點、用到物件的原點（NODE_POSITION、MODEL_MATRIX[3]）。
## 只讀頂點換成世界座標（MODEL_MATRIX * vec4(VERTEX, 1.0)）的不算（合併後世界座標不變）。
static var _local_cache := {}
static func _local_space(m: Material) -> bool:
	if m == null:
		return false
	if m is BaseMaterial3D:
		var b := m as BaseMaterial3D
		return (b.uv1_triplanar and not b.uv1_world_triplanar) or (b.uv2_triplanar and not b.uv2_world_triplanar) \
			or b.billboard_mode != BaseMaterial3D.BILLBOARD_DISABLED or b.distance_fade_mode == BaseMaterial3D.DISTANCE_FADE_OBJECT_DITHER \
			or b.grow or (b.next_pass != null and _local_space(b.next_pass))
	if m is ShaderMaterial:
		var sh := (m as ShaderMaterial).shader
		if sh == null:
			return false
		if not _local_cache.has(sh):
			var code := sh.code
			var re := RegEx.create_from_string("VERTEX(\\.[xyzw]+)?\\s*[-+*/]?=[^=]")
			_local_cache[sh] = code.contains("NODE_POSITION") or code.contains("MODEL_MATRIX[3]") or code.contains("INSTANCE_CUSTOM") \
				or code.contains("billboard") or re.search(code) != null
		return bool(_local_cache[sh]) or ((m as ShaderMaterial).next_pass != null and _local_space((m as ShaderMaterial).next_pass))
	return true

# ---------------------------------------------------------------- 網格資料（不從顯示卡讀）

static var _src := {}       # 網格的鍵|第幾面 → _CpuMesh（存好的頂點資料）
static var _results := {}   # merge(cache = true) 合好的結果：簽名 → 每一組的頂點資料

## 給 SurfaceTool.append_from 用的「網格」：資料直接從記憶體拿，不經過 RenderingServer（網頁版不用從顯示卡讀回來）
class _CpuMesh:
	extends Mesh
	var arrays: Array = []
	func _get_surface_count() -> int:
		return 1
	func _surface_get_array_len(_i: int) -> int:
		return (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	func _surface_get_array_index_len(_i: int) -> int:
		return (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() if arrays[Mesh.ARRAY_INDEX] != null else 0
	func _surface_get_arrays(_i: int) -> Array:
		return arrays
	func _surface_get_blend_shape_arrays(_i: int) -> Array[Array]:
		return []
	func _surface_get_lods(_i: int) -> Dictionary:
		return {}
	func _surface_get_format(_i: int) -> int:
		# 做碰撞形狀（get_faces）會看有沒有索引；其他的照有哪些陣列填
		var f := 0
		var bits := [[Mesh.ARRAY_VERTEX, Mesh.ARRAY_FORMAT_VERTEX], [Mesh.ARRAY_NORMAL, Mesh.ARRAY_FORMAT_NORMAL],
			[Mesh.ARRAY_TANGENT, Mesh.ARRAY_FORMAT_TANGENT], [Mesh.ARRAY_COLOR, Mesh.ARRAY_FORMAT_COLOR],
			[Mesh.ARRAY_TEX_UV, Mesh.ARRAY_FORMAT_TEX_UV], [Mesh.ARRAY_TEX_UV2, Mesh.ARRAY_FORMAT_TEX_UV2],
			[Mesh.ARRAY_INDEX, Mesh.ARRAY_FORMAT_INDEX]]
		for b in bits:
			if arrays[b[0]] != null:
				f |= int(b[1])
		return f
	func _surface_get_primitive_type(_i: int) -> int:
		return Mesh.PRIMITIVE_TRIANGLES
	func _surface_set_material(_i: int, _m: Material) -> void:
		pass
	func _surface_get_material(_i: int) -> Material:
		return null
	func _get_blend_shape_count() -> int:
		return 0
	func _get_blend_shape_name(_i: int) -> StringName:
		return &""
	func _set_blend_shape_name(_i: int, _n: StringName) -> void:
		pass
	func _get_aabb() -> AABB:
		return AABB()

## 網格的鍵：有檔案路徑的（模型檔裡的網格）用路徑，換場景重新載入也認得；合併做出來的網格用它的 batch_key（meta）；
## 其他自己做的網格用物件編號（「#」開頭：認不出來，不留）
static func _key(mesh: Mesh, s: int) -> String:
	if mesh.has_meta(&"batch_key"):
		return "%s|%d" % [mesh.get_meta(&"batch_key"), s]
	if mesh.resource_path != "":
		return "%s|%d" % [mesh.resource_path, s]
	if mesh is PrimitiveMesh:
		# 程式做的方塊、球……：形狀設定一樣就是同一個網格（每次蓋都 new 一個也認得）
		var desc := PackedStringArray(["prim", mesh.get_class()])
		for pr in mesh.get_property_list():
			var nm := String(pr.name)
			if int(pr.usage) & PROPERTY_USAGE_STORAGE and nm != "material" and nm != "script" and not nm.begins_with("resource_") and not nm.begins_with("metadata/"):
				desc.append("%s=%s" % [nm, mesh.get(nm)])
		mesh.set_meta(&"batch_key", ",".join(desc))
		return "%s|%d" % [mesh.get_meta(&"batch_key"), s]
	return "#%d|%d|%d" % [mesh.get_instance_id(), s, mesh.surface_get_array_len(s)]

## 用手上的頂點資料（ArrayMesh 那種陣列）做一個「網格」：可以拿去 SurfaceTool.append_from、create_trimesh_shape、
## create_convex_shape，結果跟真的網格一樣，但不用從顯示卡讀（不能拿來畫）
static func cpu_mesh(arrays: Array) -> Mesh:
	var cm := _CpuMesh.new()
	cm.arrays = arrays
	return cm

## mesh 的第 s 面，換成資料存在記憶體裡的網格（第一次要從顯示卡讀一次，之後直接拿）
static func source(mesh: Mesh, s: int) -> Mesh:
	var k := _key(mesh, s)
	var cm = _src.get(k)
	if cm == null:
		cm = _CpuMesh.new()
		# 方塊、球這類程式做的網格自己就算得出頂點（不用讀顯示卡）
		(cm as _CpuMesh).arrays = (mesh as PrimitiveMesh).get_mesh_arrays() if mesh is PrimitiveMesh else mesh.surface_get_arrays(s)
		if not k.begins_with("#"):
			_src[k] = cm       # 認不出來的（每次都重新做的網格）不留，不然每換一次場景就多存一份
	return cm

## 合併做出來的網格（有 batch_key）：把第 s 面的資料記起來，之後再合併它不用讀顯示卡。
## 用 batch_key 當鍵：換場景再做一次一模一樣的網格也認得（不會每次都多存一份）；沒有 batch_key 的不記
static func remember(mesh: ArrayMesh, s: int, arrays: Array) -> void:
	var k := _key(mesh, s)
	if k.begins_with("#"):
		return
	var cm := _CpuMesh.new()
	cm.arrays = arrays
	_src[k] = cm
