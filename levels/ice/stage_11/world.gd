extends "res://levels/ice/rescue_world.gd"
## 【救企鵝 3】時機：阿土從西邊沿著一條直線衝過冰湖，線的盡頭是冰洞；
## 阿水從東北斜斜衝下來，在 3 秒多的時候穿過阿土那條線。
## 只有一片香蕉皮：要讓阿土剛好在阿水經過時滑出去，兩個一起撞進冰洞。

func _ice_configure() -> void:
	play_min = Vector2(-20.0, -23.0)
	play_max = Vector2(20.0, 18.0)
	hero_start = Vector3(0.0, 0.0, 7.0)
	# 鏡頭：視角收窄到 45 度、退遠一點（像看一個小模型）。家豪在畫面最下面、籠子在最上面、冰湖佔中間一半以上
	camera_start = Vector3(-1.0, 11.0, 18.0)
	camera_look = Vector3(-1.5, -3.0, -3.6)      # y 只用來調俯角：家豪的圓環完整入鏡、腳下留一點空間
	camera_fov = 45.0
	mood = "dusk"
	cage = Vector3(0.0, 0.0, -11.8)
	bird_path = [Vector3(0.0, 0, 4.0), Vector3(0.0, 0, -9.4)]
	# 冰湖往西延伸：阿土一出發就在冰上，香蕉皮丟太早也會失敗（他自己先滑過去）
	lakes = [{"center": Vector2(-2.0, -4.0), "rx": 12.5, "rz": 6.0}]
	ponds = [{"center": Vector2(7.6, -6.5), "r": 1.4}]
	snowmen = [Vector3(4.8, 0, -7.7)]
	pines = [Vector3(-6.0, 0, -12.5), Vector3(6.0, 0, -13.0), Vector3(11.5, 0, -1.0)]
	# 東北那棵就在阿水出發點前面：畫成小樹，從鏡頭看過去才不會把他整個擋住（擋路的範圍不變，玩法一樣）
	low_pines = [1]
	# ---- 以下都是外觀（不影響玩法）
	# 地圖的輪廓：南邊（鏡頭這一側）收短一點；coves 是岸邊凹進來的小海灣（看得到對面的冰崖）
	isle = {"seed": 7.9, "c": Vector2(0.0, -4.0), "rz": 19.5,
		"coves": [[-0.10, 4.5, 0.12], [-1.25, 4.5, 0.12], [-1.95, 4.5, 0.12], [3.20, 4.0, 0.12]]}
	# 裝飾要讓開的路線（兩個工人的紅線、滑出去的方向）
	clear_paths = [[Vector3(-12.0, 0, -6.5), Vector3(-1.0, 0, -6.5), Vector3(7.6, 0, -6.5)], [Vector3(7.2, 0, -13.6), Vector3(0.6, 0, -5.0)]]
	# 這一關的重點是兩條紅線在冰湖上的交叉點：周圍的冰面保持乾淨，不放任何小東西
	clear_spots = [Vector3(1.75, 0, -6.5)]
	# 工人的冰釣營地（裝飾）：在他們出發點後面
	camps = [{"pos": Vector3(-15.5, 0, -13.5), "yaw": 0.6}, {"pos": Vector3(13.0, 0, -18.0), "yaw": -0.8}]
	# 冰湖周圍的擺設（純裝飾）。高的東西都離冰洞 9 公尺以上：過關特寫的鏡頭會繞著冰洞拍
	front_props = false
	zones = [
		# 這一關的地標：湖西南岸的燈籠夜市——條紋攤位、一串串圓燈籠，暖黃的光照到雪地和冰湖邊緣（跟天上極光的冷光對比）
		{"type": "stall", "pos": Vector3(-11.4, 0, 4.6), "yaw": 1.0},
		{"type": "stall", "pos": Vector3(-8.6, 0, 6.6), "yaw": 0.5},
		{"type": "string", "pos": Vector3(-8.4, 0, 3.3), "yaw": 0.15},
		{"type": "crates", "pos": Vector3(-12.6, 0, 7.0), "yaw": 0.4},
		# 夜市延伸到家豪出發點附近：一盞立燈、一串燈籠（避開左下的道具格、右下的開始鈕、黃線）
		{"type": "lantern", "pos": Vector3(-4.4, 0, 8.6), "scale": 0.85},
		{"type": "string", "pos": Vector3(4.0, 0, 9.6), "yaw": -0.2},
		# 碼頭和湖邊的立燈：暖光碰到冰湖邊緣
		{"type": "lantern", "pos": Vector3(-14.2, 0, -2.5)},
		{"type": "lantern", "pos": Vector3(-3.4, 0, 3.0), "scale": 0.8},
		{"type": "lantern", "pos": Vector3(3.0, 0, 2.7), "scale": 0.8},
		{"type": "pier", "pos": Vector3(-12.5, 0, -1.0), "yaw": -1.57},
		{"type": "crystals", "pos": Vector3(15.0, 0, 0.5)},
		{"type": "crystals", "pos": Vector3(-8.0, 0, -15.0)},
		{"type": "creek", "from": Vector3(17.0, 0, -15.0), "to": Vector3(10.2, 0, -6.0)},
	]
