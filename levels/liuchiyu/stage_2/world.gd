extends "res://levels/liuchiyu/island_world.gd"
## 第二小關的場地（島北邊的低地，南邊有石階通到高原；整座島見 island_world.gd）：中間偏左有一個水池（敵人走進去會淹死，家豪會飛過去）。

func _configure() -> void:
	use_zone(2)       # 擺設和水池在 island_world.gd 的 ZONE_PROPS / ZONE_PONDS
	fly_min = Vector2(-12.0, -INF)        # 西邊是石階腳下的柵欄
	fly_max = Vector2(INF, 18.8)          # 南邊是河邊的柵欄（河對面是第一小關）
	play_min = Vector2(-13.0, -12.0)
	play_max = Vector2(13.0, 14.0)
	hero_start = Vector3(2.0, 0.0, 11.0)
