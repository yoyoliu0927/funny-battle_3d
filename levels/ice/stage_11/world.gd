extends "res://levels/ice/rescue_world.gd"
## 【救企鵝 3】時機：阿土從西邊沿著一條直線衝過冰湖，線的盡頭是冰洞；
## 阿水從東北斜斜衝下來，在 3 秒多的時候穿過阿土那條線。
## 只有一片香蕉皮：要讓阿土剛好在阿水經過時滑出去，兩個一起撞進冰洞。

func _ice_configure() -> void:
	play_min = Vector2(-17.0, -20.0)
	play_max = Vector2(17.0, 16.0)
	hero_start = Vector3(0.0, 0.0, 7.0)
	camera_start = Vector3(-1.0, 11.5, 10.5)
	camera_look = Vector3(-1.5, 0.0, -5.0)
	cage = Vector3(0.0, 0.0, -11.8)
	bird_path = [Vector3(0.0, 0, 4.0), Vector3(0.0, 0, -9.4)]
	# 冰湖往西延伸：阿土一出發就在冰上，香蕉皮丟太早也會失敗（他自己先滑過去）
	lakes = [{"center": Vector2(-2.0, -4.0), "rx": 12.5, "rz": 6.0}]
	ponds = [{"center": Vector2(7.6, -6.5), "r": 1.4}]
	snowmen = [Vector3(4.8, 0, -7.7)]
	pines = [Vector3(-6.0, 0, -12.5), Vector3(6.0, 0, -13.0), Vector3(11.5, 0, -1.0)]
	# 工人的冰釣營地（裝飾）：在他們出發點後面
	camps = [{"pos": Vector3(-15.0, 0, -13.5), "yaw": 0.6}, {"pos": Vector3(12.0, 0, -17.0), "yaw": -0.8}]
