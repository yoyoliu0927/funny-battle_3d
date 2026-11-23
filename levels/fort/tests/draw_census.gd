extends SceneTree
## 找出哪裡的 MeshInstance3D 最多（選關農莊）：依第二、三層節點統計
func _initialize() -> void:
	_go.call_deferred()
func _go() -> void:
	change_scene_to_file("res://scenes/level_select.tscn")
	for i in 200:
		await process_frame
	var counts := {}
	var mm := {}
	_walk(current_scene, counts, mm, "")
	var keys := counts.keys()
	keys.sort_custom(func(a, b): return counts[a] > counts[b])
	for k in keys.slice(0, 30):
		print("CENSUS | %5d mesh | %4d multimesh | %s" % [counts[k], mm.get(k, 0), k])
	quit()
func _walk(n: Node, counts: Dictionary, mm: Dictionary, path: String) -> void:
	for c in n.get_children():
		var p := path + "/" + String(c.name) if path.count("/") < 2 else path
		if c is MeshInstance3D and c.is_visible_in_tree():
			counts[p] = counts.get(p, 0) + 1
		elif c is MultiMeshInstance3D and c.is_visible_in_tree():
			mm[p] = mm.get(p, 0) + 1
			counts[p] = counts.get(p, 0)
		_walk(c, counts, mm, p)
