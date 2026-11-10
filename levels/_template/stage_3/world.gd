extends "res://scripts/world/arena_world.gd"
## 第三小關的場地：東邊有一座山坡（自訂地形），巨石放在坡上會滾下來。

const HILL_X := 8.0     # 山坡從 x = 8 開始往東升高

func _configure() -> void:
	play_min = Vector2(-12.0, -12.0)
	play_max = Vector2(14.0, 14.0)
	hero_start = Vector3(-4.0, 0.0, 11.0)
	camera_start = Vector3(-2.0, 8.0, 19.0)
	camera_look = Vector3(4.0, 0.0, -2.0)
	walls = [[Vector2(-12.0, -2.0), Vector2(-4.0, -2.0)]]   # 一道牆：誰都過不去
	props = [
		{"model": "res://assets/farm/Silo.glb", "pos": Vector3(-8.0, 0, -7.0), "scale": 1.0, "block": 1.6},
	]

## 自訂地形：東邊一座山坡
func _extra_height(x: float, _z: float) -> float:
	return sstep(HILL_X, HILL_X + 6.0, x) * 4.0

## 山坡上敵人和家豪走不上去，但巨石可以放
func walkable(x: float, z: float) -> bool:
	return super(x, z) and x < HILL_X + 1.0

func rock_ground(x: float, z: float) -> bool:
	return in_play(x, z)
