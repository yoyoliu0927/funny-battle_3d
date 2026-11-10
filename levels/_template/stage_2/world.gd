extends "res://scripts/world/arena_world.gd"
## 第二小關的場地：中間偏左有一個水池（敵人走進去會淹死，家豪會飛過去）。

func _configure() -> void:
	play_min = Vector2(-13.0, -12.0)
	play_max = Vector2(13.0, 14.0)
	hero_start = Vector3(2.0, 0.0, 11.0)
	ponds = [{"center": Vector2(-5.0, -1.0), "r": 3.6, "island": 1.0}]
	ground_a = Color(0.6, 0.72, 0.3)    # 換個地面顏色，示範每關可以有自己的風格
	ground_b = Color(0.5, 0.66, 0.26)
	props = [
		{"model": "res://assets/farm/SmallBarn.glb", "pos": Vector3(8.0, 0, -8.0), "yaw": -0.6, "scale": 1.2, "block": 3.0},
		{"model": "res://assets/nature/AutumnTree.glb", "pos": Vector3(-10.0, 0, 9.0), "scale": 1.6, "block": 0.7},
	]
