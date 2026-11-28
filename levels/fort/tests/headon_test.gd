extends SceneTree
## 2-0（偷襲！）不放任何道具直接開打：家豪正面衝進守衛的視線，應該要輸。
##   Godot --headless --path . -s res://levels/fort/tests/headon_test.gd [-- --sneak]
## 帶 --sneak：從側面撒一串飼料繞到守衛背後，應該要贏；再加 --one 只撒一把（三星解）。
## 印 HEADON: PASS（輸了）或 HEADON: FAIL（贏了／沒分出勝負）。

func _initialize() -> void:
	_go.call_deferred()

func _go() -> void:
	var sc: Node = (load("res://levels/fort/stage_0/stage.tscn") as PackedScene).instantiate()
	root.add_child(sc)
	for i in 5:
		await process_frame
	var b: Node = sc.get_node("Battle")
	var sneak := "--sneak" in OS.get_cmdline_user_args()
	if sneak:
		# 正解：從側面撒一串飼料繞到守衛背後（守衛在 (-4, -2.3) 面向 +Z，紅色扇形 7 公尺、左右各 50 度）
		var g = b.farmers[0]
		print("守衛 %s 面向 %.2f　家豪 %s" % [g.start_pos, g.start_yaw, b.bird.start_pos])
		# 帶 --one：只撒一把（三星解：從扇形外側斜切過去）
		var trail := [Vector2(-8, 6)] if "--one" in OS.get_cmdline_user_args() else [Vector2(-6, 12), Vector2(-8, 6), Vector2(-7.5, 1.5), Vector2(-4, -2.5)]
		for off in trail:
			var p: Vector3 = g.start_pos + Vector3(off.x, 0, off.y)
			var err: String = b.placement_error(0, p)
			if err == "":
				b.cast(0, p)
			else:
				print("放不下 %s：%s" % [p, err])
	b.start()
	var log_hp := []
	for i in 60 * 40:
		b._step(1.0 / 60.0)
		if b.outcome != "":
			break
	for e in b.events:
		print("  ", e)
	print("結果：%s　家豪血量 %.1f／%.1f　時間 %.1f 秒" % [b.outcome, b.bird.hp, b.bird.max_hp, b.time])
	print("星星條件：", b._star_goals())
	var want := "win" if sneak else "lose"
	print("HEADON: %s" % ("PASS" if b.outcome == want else "FAIL"))
	quit(0 if b.outcome == want else 1)
