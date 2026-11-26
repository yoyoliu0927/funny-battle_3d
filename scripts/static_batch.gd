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

## 合併 pieces 底下所有可以合併的零件，結果掛在 root 底下（名字 "Batched"）。回傳合併掉幾個 MeshInstance3D
static func merge(root: Node3D, pieces: Array) -> int:
	if root == null or not root.is_inside_tree() or "--perf-nobatch" in OS.get_cmdline_user_args():
		return 0
	var inv := root.global_transform.affine_inverse()
	var groups := {}       # 材質＋影子＋圖層 → [SurfaceTool, 材質, 影子, 圖層]
	var done: Array = []
	for p in pieces:
		if p == null or not is_instance_valid(p) or not (p as Node).is_inside_tree():
			continue
		_collect(p, inv, groups, done)
	if done.size() < 2:
		return 0
	var meshes := {}       # "影子|圖層" → MeshInstance3D
	for key in groups:
		var g: Array = groups[key]
		var nk := "%d|%d" % [g[2], g[3]]
		if not meshes.has(nk):
			var mi := MeshInstance3D.new()
			mi.name = "Batched"
			mi.mesh = ArrayMesh.new()
			mi.cast_shadow = g[2]
			mi.layers = g[3]
			root.add_child(mi)
			meshes[nk] = mi
		var am: ArrayMesh = (meshes[nk] as MeshInstance3D).mesh
		(g[0] as SurfaceTool).commit(am)
		am.surface_set_material(am.get_surface_count() - 1, g[1])
	for mi in done:
		mi.get_parent().remove_child(mi)
		mi.queue_free()
	return done.size()

static func _collect(n: Node, inv: Transform3D, groups: Dictionary, done: Array) -> void:
	if n is AnimationPlayer or n is AnimationTree or n is Skeleton3D:
		return
	if n.get_script() != null:
		return
	if n is Node3D and not (n as Node3D).visible:
		return
	for c in n.get_children():
		_collect(c, inv, groups, done)
	if not n is MeshInstance3D:
		return
	var mi := n as MeshInstance3D
	if mi.mesh == null or mi.skin != null or mi.mesh.get_blend_shape_count() > 0 or mi.get_child_count() > 0:
		return
	if mi.transparency > 0.0 or mi.visibility_range_end > 0.0 or mi.material_overlay != null:
		return
	for s in mi.mesh.get_surface_count():
		if mi.mesh.surface_get_primitive_type(s) != Mesh.PRIMITIVE_TRIANGLES:
			return
		if _see_through(mi.get_active_material(s)):
			return
	var xf := inv * mi.global_transform
	for s in mi.mesh.get_surface_count():
		var mat := mi.get_active_material(s)
		var key := "%d|%d|%d" % [mat.get_instance_id() if mat else 0, mi.cast_shadow, mi.layers]
		if not groups.has(key):
			groups[key] = [SurfaceTool.new(), mat, mi.cast_shadow, mi.layers]
		(groups[key][0] as SurfaceTool).append_from(mi.mesh, s, xf)
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
