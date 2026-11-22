extends "res://levels/forest/forest_world.gd"
## 第一小關「林道」：一條林間小路，兩個伐木工各守一片林子。沒有木屋。

func _layout_level() -> void:
	world_seed = 520331
	play_min = Vector2(-14.0, -12.0)
	play_max = Vector2(14.0, 12.0)
	hero_start = Vector3(0.0, 0.0, 9.5)
	hero_yaw = PI
	camera_start = Vector3(2.0, 8.0, 16.5)
	camera_look = Vector3(0.0, 0.6, 1.0)

func _dress() -> void:
	var avoid := [
		{"p": Vector3(0, 0, 9.5), "r": 2.6},
		{"p": Vector3(-6.5, 0, -2.0), "r": 2.2},     # 伐木1 站的地方
		{"p": Vector3(6.5, 0, -5.5), "r": 2.2},      # 伐木2 站的地方
	]
	# 一條從南邊彎進林子的小路（路上不種樹，家豪走得順）
	var lane := {"a": Vector2(0, 10.5), "b": Vector2(0, 1.5), "half": 1.4}
	dirt_path(Vector2(0, 10.5), Vector2(0, 4.0))
	dirt_path(Vector2(0, 4.0), Vector2(-4.5, -0.5))
	dirt_path(Vector2(0, 4.0), Vector2(4.5, -3.5))
	scatter_trees(24, 4.2, avoid, lane)
	_woodpile(Vector3(-9.5, 0, -6.5), 0.4)
	_woodpile(Vector3(10.0, 0, 1.5), -0.6)
	undergrowth(20)
	mushrooms(8)

## 堆好的木柴（看得出這裡有人在砍樹；不擋路）
func _woodpile(p: Vector3, yaw: float) -> void:
	var n := Node3D.new()
	n.position = Vector3(p.x, height_at(p.x, p.z), p.z)
	n.rotation.y = yaw
	add_child(n)
	var bark := _toon(Color(0.42, 0.27, 0.14))
	var cut := _toon(Color(0.86, 0.7, 0.45))
	for row in 3:
		for k in 3 - row:
			var x := (k - (2 - row) * 0.5) * 0.36
			var y := 0.17 + row * 0.3
			_box(n, Vector3(0.3, 0.3, 1.4), Vector3(x, y, 0), bark)
			_box(n, Vector3(0.24, 0.24, 0.02), Vector3(x, y, 0.71), cut)
