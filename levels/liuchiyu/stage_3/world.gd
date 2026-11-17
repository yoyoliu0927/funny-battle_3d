extends "res://levels/liuchiyu/island_world.gd"
## 第三小關的場地：島中間的岩石高原，西邊是山坡，山坡上靠海的地方有一座火山（地形在 island_world.gd）。

func _configure() -> void:
	use_zone(3)       # 擺設和水池在 island_world.gd 的 ZONE_PROPS / ZONE_PONDS
	play_min = Vector2(-12.0, -12.0)
	play_max = Vector2(14.0, 14.0)
	hero_start = Vector3(4.5, 0.0, -11.0)        # 石階頂附近：從第二小關走上來就站在這裡
	hero_yaw = 0.0                                # 背對石階、面向場地（鏡頭一開始在他背後，也是看著場地）
	camera_start = Vector3(-2.0, 8.0, 16.5)
	camera_look = Vector3(4.0, PLATEAU_H, -2.0)
	walls = []        # 場地東邊是一排鐵桶（island_world.gd 的 SILOS），原本那道牆拿掉了

## 西邊的山坡上敵人和家豪走不上去，但巨石可以放
func walkable(x: float, z: float) -> bool:
	return super(x, z) and x > HILL_X + 0.5        # 山坡在場地西邊外面

func rock_ground(x: float, z: float) -> bool:
	return in_play(x, z)
