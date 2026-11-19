extends "res://levels/heaven/heaven_world.gd"
## 【丹穴山 3 天門】星空下的金色圓環：一條發光的長步道穿過一座圓形的白玉壇，走到底是圓門底下的唱盤。
## 畫門加陸吾，五個人、兩片香蕉皮（2026-11-20 重新設計，見規格第 14 節）；黃線只走到唱盤前面，唱盤上要放飼料。

func _ice_configure() -> void:
	# ==================================================================
	# 【玩法】
	# ==================================================================
	play_min = Vector2(-24.0, -24.0)
	play_max = Vector2(24.0, 18.0)
	hero_start = Vector3(0.0, 0.0, 10.5)
	cage = Vector3(0.0, 0.0, -11.8)
	bird_path = [Vector3(0.0, 0, 6.0), Vector3(0.0, 0, -9.6)]
	# 圓形的白玉壇（這一關是圓的：跟唱盤、金環同一個主題）
	lakes = [{"center": Vector2(0.0, -2.5), "rx": 11.0, "rz": 7.5}]
	# 星洞甲（東北）：大老闆那條紅線一路往東的盡頭（守衛站在半路上）；星洞乙（東南）：阿土第一段一路往東的盡頭
	ponds = [{"center": Vector2(7.5, -5.6), "r": 1.3}, {"center": Vector2(5.5, 2.6), "r": 1.2}]
	# 陸吾朝西（位置沒動）：視線是 x -0.5 到 4.0、z -3.6 到 -1.4，蓋住黃線。阿土第二段從西南邊滑進視線的南緣（x 1.75 附近）
	luwu_spec = {"pos": Vector3(5.0, 0, -2.5), "face": Vector3(-1, 0, 0)}
	# 門甲的正面朝西北西（阿水第一段往東南東滑會進去）；門乙在大老闆背後、他那條紅線的西頭，朝東：
	# 從門乙出來的人沿著大老闆的紅線一路往東滑，撞上大老闆、守衛，一起進星洞甲（規格第 14 節）
	door_specs = [
		{"pos": Vector3(-4.64, 0, 0.43), "face": Vector3(-0.894, 0, -0.447)},
		{"pos": Vector3(-9.2, 0, -5.6), "face": Vector3(1, 0, 0)},
	]
	goal = "disc"
	goal_text = "唱盤"
	hole_word = "星洞"
	rough_word = "石地"
	# ==================================================================
	# 【外觀】
	# ==================================================================
	camera_start = Vector3(-1.0, 12.4, 22.8)
	camera_look = Vector3(-1.0, -2.9, -1.9)
	camera_fov = 45.0
	finale_cam_pos = Vector3(0.0, 7.5, 6.0)
	finale_cam_look = Vector3(0.0, 4.0, -14.0)
	mood = "astral"
	isle = {"seed": 9.3}
	clear_paths = [[Vector3(-9.2, 0, -5.6), Vector3(-0.8, 0, -5.6), Vector3(7.5, 0, -5.6)],
		[Vector3(-22.0, 0, -2.5), Vector3(-10.5, 0, -2.5), Vector3(-7.5, 0, -1.0), Vector3(-4.64, 0, 0.43)],
		[Vector3(-7.5, 0, -1.0), Vector3(-4.57, 0, -1.63), Vector3(-0.5, 0, -2.5)],
		[Vector3(-22.0, 0, 2.6), Vector3(-8.6, 0, 2.6), Vector3(-5.18, 0, 2.6), Vector3(5.5, 0, 2.6)],
		[Vector3(-5.18, 0, 2.6), Vector3(-2.06, 0, 0.8), Vector3(1.75, 0, -1.4)],
		[Vector3(-2.4, 0, 9.0), Vector3(-2.4, 0, 0.0)]]
	# 發光的步道：從南邊一路筆直通到唱盤；左右兩條橫的接到石碑林
	walks = [
		[Vector3(0.0, 0, 26.0), Vector3(0.0, 0, 5.0), 3.4],
		[Vector3(0.0, 0, -10.0), Vector3(0.0, 0, -13.2), 3.4],
		[Vector3(-34.0, 0, -4.4), Vector3(-11.0, 0, -4.4), 3.0],
		[Vector3(34.0, 0, -4.4), Vector3(11.0, 0, -4.4), 3.0],
	]
	front_props = false
	# 地上的山海轉盤：圍著圓壇的一圈金光，十二塊紋章盤寫著山海經的異獸，慢慢地轉
	wheel = {"c": Vector2(0.0, -2.5), "r": 13.3, "w": 2.5}
	rim_kinds = [["stele", 1.4], ["lantern", 1.2], ["rock", 0.5]]
	rim_count = 22
	rim_far = 34.0
	zones = [
		# 步道兩旁的宮燈：一路排到圓壇
		{"type": "lantern", "pos": Vector3(-2.9, 0, 17.0), "scale": 0.95},
		{"type": "lantern", "pos": Vector3(2.9, 0, 17.0), "scale": 0.95},
		{"type": "lantern", "pos": Vector3(-2.9, 0, 11.4), "scale": 0.95},
		{"type": "lantern", "pos": Vector3(2.9, 0, 11.4), "scale": 0.95},
		{"type": "lantern", "pos": Vector3(-3.2, 0, -11.2), "scale": 1.0},
		{"type": "lantern", "pos": Vector3(3.2, 0, -11.2), "scale": 1.0},
		# 兩邊立著寫滿字的石碑（一排大的）
		{"type": "stele", "pos": Vector3(-16.5, 0, -12.5), "yaw": 0.6, "scale": 1.9},
		{"type": "stele", "pos": Vector3(16.5, 0, -12.5), "yaw": -0.6, "scale": 1.9},
		{"type": "stele", "pos": Vector3(-19.0, 0, -1.0), "yaw": 1.0, "scale": 1.6},
		{"type": "stele", "pos": Vector3(19.0, 0, -1.0), "yaw": -1.0, "scale": 1.6},
		{"type": "stele", "pos": Vector3(-16.5, 0, 9.0), "yaw": 1.2, "scale": 1.3},
		{"type": "stele", "pos": Vector3(16.5, 0, 9.0), "yaw": -1.2, "scale": 1.3},
		# 遠處一圈一圈的大金環（立著，圍著圓壇）
		{"type": "ring", "pos": Vector3(0.0, 0, -26.0), "y": 9.0, "scale": 4.2},
		{"type": "ring", "pos": Vector3(0.0, 0, -40.0), "y": 13.0, "scale": 6.5},
	]
