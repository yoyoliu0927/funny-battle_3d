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

## 火山在場地的西南角、緊貼著能飛的範圍邊上：往火山（西邊）和海（南邊）那一側多給一些空間，
## 鏡頭才能往後退、把整座火山和岩漿球的落點一起看進來
const VOLCANO_EXTRA := 12.0

func _place_player() -> void:
	super()
	var player := get_node_or_null(player_path) as Node3D
	if player == null:
		return
	var lo: Vector2 = player.get("bounds_min")
	var hi: Vector2 = player.get("bounds_max")
	player.set("bounds_min", Vector2(lo.x - VOLCANO_EXTRA, lo.y))
	player.set("bounds_max", Vector2(hi.x, hi.y + VOLCANO_EXTRA))

## 西邊的山坡上敵人和家豪走不上去，但巨石可以放
func walkable(x: float, z: float) -> bool:
	return super(x, z) and x > HILL_X + 0.5        # 山坡在場地西邊外面

func rock_ground(x: float, z: float) -> bool:
	return in_play(x, z)
