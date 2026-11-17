extends "res://levels/liuchiyu/island_world.gd"
## 第一小關的場地：島東南邊的圓形盆地，裡面有風車和滾石（整座島見 island_world.gd）。可以設定的東西見 scripts/world/arena_world.gd 最上面。

func _configure() -> void:
	use_zone(1)       # 擺設和水池在 island_world.gd 的 ZONE_PROPS / ZONE_PONDS
	fly_min = Vector2(-INF, -17.7)        # 北邊是河：玩家只能飛到河邊的柵欄，過不去第二小關
	play_min = Vector2(-12.0, -12.0)
	play_max = Vector2(12.0, 14.0)
	hero_start = Vector3(0.0, 0.0, 11.0)
	camera_start = Vector3(5.0, 7.0, 18.0)
	camera_look = Vector3(0.0, 0.0, 0.0)
