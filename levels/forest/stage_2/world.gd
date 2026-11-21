extends "res://levels/forest/forest_world.gd"
## 第二小關「煙圈」：林子中間一個小水塘，三個抽菸的人圍在水塘外面。樹種得比較密，火很容易延燒。

const POND := Vector2(0.0, -1.0)

func _layout_level() -> void:
	world_seed = 520347
	play_min = Vector2(-14.0, -12.0)
	play_max = Vector2(14.0, 12.0)
	hero_start = Vector3(0.0, 0.0, 9.5)
	hero_yaw = PI
	camera_start = Vector3(1.6, 8.6, 16.8)
	camera_look = Vector3(0.0, 0.4, 0.0)
	ponds = [{"center": POND, "r": 2.6}]

func _dress() -> void:
	var avoid := [
		{"p": Vector3(0, 0, 9.5), "r": 2.6},
		{"p": Vector3(POND.x, 0, POND.y), "r": 4.2},  # 水塘和岸邊
		{"p": Vector3(-6.5, 0, 2.5), "r": 2.0},       # 抽菸1
		{"p": Vector3(6.5, 0, 1.0), "r": 2.0},        # 抽菸2
		{"p": Vector3(0.5, 0, -7.5), "r": 2.0},       # 抽菸3
	]
	_fix_pond()
	dirt_path(Vector2(0, 10.5), Vector2(0, 3.6))
	scatter_trees(28, 3.7, avoid, {})
	_stump_seat(Vector3(-6.0, 0, 3.4))
	_stump_seat(Vector3(7.1, 0, 1.7))
	_stump_seat(Vector3(1.3, 0, -8.2))
	undergrowth(24)
	mushrooms(10)

## 共用的水池把水面算在「池邊 70% 的地面再低 0.6」，森林的地幾乎是平的，水面會沉到池底下面看不到。
## 這裡把水面抬到池底和岸邊中間，再圍一圈石頭和蘆葦，看得出是水塘。
func _fix_pond() -> void:
	var pond := get_node_or_null("Pond") as Node3D
	var bottom := height_at(POND.x, POND.y)
	var rim := height_at(POND.x + 2.6, POND.y)
	if pond:
		pond.position.y = lerpf(bottom, rim, 0.55)
		water_y = pond.position.y
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed + 7
	var stone := _toon(Color(0.55, 0.56, 0.52))
	var reed := _toon(Color(0.42, 0.55, 0.22))
	for k in 16:
		var a := TAU * k / 16.0 + rng.randf_range(-0.12, 0.12)
		var d := 2.75 + rng.randf_range(-0.1, 0.25)
		var x := POND.x + cos(a) * d
		var z := POND.y + sin(a) * d
		var s := rng.randf_range(0.25, 0.45)
		_box(self, Vector3(s, s * 0.6, s * 0.9), Vector3(x, height_at(x, z) + s * 0.25, z), stone, Vector3(0, a, 0))
		if k % 3 == 0:
			for r in 3:
				var rx := x + rng.randf_range(-0.25, 0.25)
				var rz := z + rng.randf_range(-0.25, 0.25)
				var h := rng.randf_range(0.6, 0.9)
				_box(self, Vector3(0.05, h, 0.05), Vector3(rx, height_at(rx, rz) + h * 0.5, rz), reed, Vector3(rng.randf_range(-0.2, 0.2), 0, rng.randf_range(-0.2, 0.2)))

## 抽菸的人坐的樹墩（不擋路）
func _stump_seat(p: Vector3) -> void:
	var n := Node3D.new()
	n.position = Vector3(p.x, height_at(p.x, p.z), p.z)
	add_child(n)
	_box(n, Vector3(0.6, 0.4, 0.6), Vector3(0, 0.2, 0), _toon(Color(0.42, 0.27, 0.14)))
	_box(n, Vector3(0.5, 0.02, 0.5), Vector3(0, 0.41, 0), _toon(Color(0.86, 0.7, 0.45)))
