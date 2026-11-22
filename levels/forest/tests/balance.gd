extends SceneTree
## 平衡檢查：每一關用幾種打法各跑一次，看結果合不合理。
##   不放道具 → 應該輸；只用引路點硬打 → 應該很難；用假獵物偷襲 → 應該過得了。
## Godot --headless --path . --script res://levels/forest/tests/balance.gd
const DT := 1.0 / 60.0
var bt

func _initialize() -> void:
	_go.call_deferred()

func load_stage(n: int) -> void:
	change_scene_to_file("res://levels/forest/stage_%d/stage.tscn" % n)
	for i in 6:
		await process_frame
	bt = current_scene.get_node("Battle")
	bt.set_physics_process(false)
	bt.set_process(false)

func who(n: String):
	for f in bt.enemies:
		if f.name == n:
			return f
	return null

## 放道具；那一點放不下（樹、水）就在附近轉一圈找空位
func put(id: String, p: Vector3) -> void:
	var i: int = bt.skill_index(id)
	for r in [0.0, 0.8, 1.4]:
		for k in 8:
			var q: Vector3 = p + Vector3(cos(k * 0.785), 0, sin(k * 0.785)) * float(r)
			if bt.placement_error(i, bt.ground(q)) == "" and bt.cast(i, bt.ground(q)):
				return
			if r == 0.0:
				break
	print("      （%s 放不下：%s）" % [id, bt.placement_error(i, bt.ground(p))])

## 跑一局；plan(t) 每一步呼叫，可以在戰鬥中放道具
func run(name: String, prep: Callable, plan: Callable = Callable(), limit := 120.0) -> String:
	bt.reset()
	bt.no_cooldown = true
	if prep.is_valid():
		prep.call()
	bt.start()
	while bt.phase == bt.Phase.RUNNING and bt.time < limit:
		bt._tick_cooldowns(DT)
		bt._step(DT)
		if plan.is_valid():
			plan.call()
	var r := "%s：%s（%s）%.1f 秒  血 %.0f  樹 砍%d／燒%d  一擊 %d  踩熄 %d  還剩 %d 人" % [name, bt.outcome if bt.outcome != "" else "未分", bt.fail,
		bt.time, bt.bird.hp, bt.trees_cut, bt.trees_burnt, bt.lure_kos, bt.stomps, bt.enemies_left()]
	print("    ", r)
	return bt.outcome

func _go() -> void:
	print("== 第一關 林道")
	await load_stage(1)
	run("不放道具", Callable())
	# 只用引路點：直直帶去打
	run("只用引路點", func():
		put("guide", Vector3(-4.0, 0, 2.0))
		put("guide", Vector3(-6.5, 0, 0.5)))
	# 假獵物偷襲：開打前在伐木1 北邊放一隻（他背對家豪走過去），打倒後再對伐木2 放一隻
	var state := {"d2": false}
	run("假獵物偷襲", func():
		put("decoy", who("伐木1").pos + Vector3(-0.5, 0, -3.0))
		state.d2 = false,
		func():
			if not state.d2 and not who("伐木1").alive():
				state.d2 = true
				put("decoy", who("伐木2").pos + Vector3(1.5, 0, -3.0)))

	print("== 第二關 煙圈")
	await load_stage(2)
	run("不放道具", Callable())
	run("只用引路點", func():
		put("guide", Vector3(-4.5, 0, 4.5))
		put("guide", Vector3(-6.0, 0, 3.6)))
	var st2 := {"k": 0}
	run("假獵物偷襲＋旗子去踩", func():
		put("decoy", who("抽菸1").pos + Vector3(-2.5, 0, -2.0))
		st2.k = 0,
		func():
			# 每打倒一個，就對下一個最近的放假獵物，並插一支旗子去踩他剛掉的菸
			var down := 0
			for f in bt.enemies:
				if not f.alive():
					down += 1
			if down > st2.k:
				st2.k = down
				for b in bt.butts:
					put("guide", b.pos)
				var nxt = bt.nearest_enemy(bt.bird.pos)
				if nxt != null and bt.charges[bt.skill_index("decoy")] != 0:
					var away: Vector3 = (nxt.pos - bt.bird.pos)
					away.y = 0.0
					put("decoy", nxt.pos + away.normalized() * 2.8))

	print("== 第三關 小紅帽")
	await load_stage(3)
	run("不放道具", Callable())
	var st3 := {"b": false}
	run("籃子＋旗子衝進屋", func():
		put("guide", bt.escape_point)
		st3.b = false,
		func():
			if not st3.b and bt.time > 6.0:
				st3.b = true
				put("basket", bt.escape_point + Vector3(1.2, 0, -0.6)))
	quit()
