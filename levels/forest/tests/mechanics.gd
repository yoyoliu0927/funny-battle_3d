extends SceneTree
## 森林機制的自動檢查（不開視窗）：菸蒂、起火延燒、倒下的樹幹、視線、假獵物丟菸、外婆的籃子、引路點順序、可重演。
## Godot --headless --path . --script res://levels/forest/tests/mechanics.gd
const DT := 1.0 / 60.0
const S1 := "res://levels/forest/stage_3/stage.tscn"
const S3 := "res://levels/forest/stage_2/stage.tscn"   # 煙圈（抽菸、起火）
var bt
var fails := 0
var checks := 0

func _initialize() -> void:
	_go.call_deferred()

func ok(cond: bool, what: String) -> void:
	checks += 1
	if cond:
		print("  ok    ", what)
	else:
		fails += 1
		print("  FAIL  ", what)

func load_stage(path: String) -> void:
	change_scene_to_file(path)
	for i in 6:
		await process_frame
	bt = current_scene.get_node("Battle")
	bt.set_physics_process(false)
	bt.set_process(false)

func steps(sec: float, each: Callable = Callable()) -> void:
	var n := int(sec / DT)
	for i in n:
		if bt.phase != bt.Phase.RUNNING:
			return
		bt._step(DT)
		if each.is_valid():
			each.call()

func ev(key: String) -> float:
	for e in bt.events:
		if String(e.text).contains(key):
			return e.t
	return -1.0

func who(name: String):
	for f in bt.enemies:
		if f.name == name:
			return f
	return null

## 把家豪放到場外角落、站著不動（不干擾要測的東西）
func park_bird() -> void:
	bt.bird.pos = bt.ground(Vector3(15.5, 0, -13.5))
	bt.bird.set_state("linger")
	bt.bird.t = -9999.0

func _go() -> void:
	print("== 菸蒂會點著樹（煙圈）")
	await load_stage(S3)
	bt.reset()
	bt.start()
	park_bird()
	steps(9.0 + 6.0, func(): bt.bird.t = -9999.0)
	ok(ev("彈掉一根菸蒂") >= 0.0, "抽菸的人彈了菸蒂（%.1f 秒）" % ev("彈掉一根菸蒂"))
	steps(8.0, func(): bt.bird.t = -9999.0)
	ok(ev("菸蒂點著了樹") >= 0.0 or ev("菸蒂自己熄了") >= 0.0, "菸蒂放著不管會點火或熄掉")
	ok(bt.trees_burnt > 0, "有樹燒起來（%d 棵）" % bt.trees_burnt)

	print("== 延燒和燒完")
	bt.reset()
	bt.start()
	park_bird()
	var first: int = bt._nearest_tree(Vector3.ZERO, 99.0)
	bt._ignite_tree(first, "測試點火")
	ok(bt.grove[first].fire >= 0.0 and not bt.grove[first].alive, "點著的樹算損失")
	steps(bt.BURN_TIME + 0.2, func(): bt.bird.t = -9999.0)
	ok(bt.grove[first].burnt, "燒 %.0f 秒變成樹樁" % bt.BURN_TIME)
	ok(not bt.grove[first].node.get_node("Crown").visible, "樹冠不見了")
	var spread_a: int = bt.trees_burnt

	print("== 可重演：同一局重來，延燒結果一樣")
	bt.reset()
	bt.start()
	park_bird()
	bt._ignite_tree(first, "測試點火")
	steps(bt.BURN_TIME + 0.2, func(): bt.bird.t = -9999.0)
	ok(bt.trees_burnt == spread_a, "兩次都燒了 %d 棵" % spread_a)

	print("== 踩熄菸蒂")
	bt.reset()
	bt.start()
	var sm = who("抽菸1")
	sm.yaw = 0.0
	bt.drop_butt(sm, "flick")
	var bp: Vector3 = bt.butts[0].pos
	bt.bird.pos = bt.ground(bp + Vector3(0.3, 0, 0))
	bt._tick_butts(DT)
	ok(bt.butts.is_empty() and ev("踩熄") >= 0.0, "家豪走到菸蒂上就踩熄")

	print("== 小紅帽關：倒下的樹幹")
	await load_stage(S1)
	bt.reset()
	bt.start()
	park_bird()
	var n0: int = bt.world.obstacles.size()
	var ti: int = bt._nearest_tree(Vector3(5, 0, 5), 99.0)
	var tp: Vector3 = bt.grove[ti].pos
	bt._fell(ti, tp + Vector3(-1.0, 0, 0))
	steps(1.0, func(): bt.bird.t = -9999.0)
	ok(bt.grove[ti].fall >= 1.0, "樹倒完了")
	ok(bt.world.obstacles.size() > n0, "樹幹變成擋路的圓（多了 %d 個）" % (bt.world.obstacles.size() - n0))
	ok(bt.hits_obstacle(Vector2(tp.x + 1.6, tp.z)), "樹往伐木工反方向倒（+X 那邊被擋住）")
	ok(bt.guide_error(tp + Vector3(1.6, 0, 0)) != "", "樹幹上不能放引路點")
	var nb: Vector3 = tp + Vector3(1.6, 0, 0)
	bt.add_guide(bt.ground(nb + Vector3(0, 0, 3.0)))
	bt.guides[0].pos = bt.ground(nb)       # 假裝先放好、後來才被樹壓住
	ok(bt._next_guide() == null, "被樹幹壓住的引路點會跳過")
	bt.reset()
	ok(bt.world.obstacles.size() == n0, "重試後樹幹拿掉")
	ok(bt.grove[ti].alive and bt.grove[ti].fall == 0.0, "重試後樹站回來")

	print("== 視線：樹擋得住")
	bt.reset()
	bt.start()
	var ch = who("伐木1")
	var tc: Vector3 = bt.grove[ti].pos
	ch.pos = bt.ground(tc + Vector3(-2.5, 0, 0))
	ch.yaw = PI * 0.5                      # 面向 +X
	bt.bird.pos = bt.ground(tc + Vector3(2.5, 0, 0))
	ok(not bt.sees_bird(ch), "家豪在樹後面看不到")
	bt.grove[ti].fall = 1.0
	ok(bt.sees_bird(ch), "樹倒了就看得到")

	print("== 假獵物讓抽菸的人把菸丟在地上")
	bt.reset()
	bt.start()
	park_bird()
	var sm1 = who("抽菸1")
	steps(12.0, func(): bt.bird.t = -9999.0)
	ok(sm1.state == "smoke", "抽菸1 在抽菸")
	var before: int = bt.butts.size()
	bt.add_decoy(bt.ground(sm1.pos + Vector3(3.0, 0, -2.0)))
	steps(0.5, func(): bt.bird.t = -9999.0)
	ok(ev("的菸掉在地上") >= 0.0 and bt.butts.size() > before, "去看假獵物時菸掉在地上")

	print("== 外婆的籃子")
	bt.reset()
	bt.start()
	park_bird()
	ok(bt.basket_error(bt.ground(Vector3(9, 0, 9))) != "", "離木屋太遠放不了")
	var door: Vector3 = bt.escape_point
	ok(bt.basket_error(bt.ground(door)) == "", "門口可以放")
	bt.add_basket(bt.ground(door))
	var wolf = who("狼外婆")
	steps(6.0, func(): bt.bird.t = -9999.0)
	ok(wolf.state == "sniff", "狼外婆走去聞籃子")
	var d0: float = bt.dinner
	steps(1.0, func(): bt.bird.t = -9999.0)
	ok(is_equal_approx(bt.dinner, d0), "聞的時候小紅帽計時停下來")
	steps(bt.BASKET_LIFE, func(): bt.bird.t = -9999.0)
	ok(wolf.state != "sniff" and bt.dinner > d0, "籃子沒味道了，狼外婆回去、計時繼續")

	print("== 狼外婆守著小紅帽")
	bt.reset()
	bt.start()
	var hp0: float = bt.bird.hp
	bt.bird.pos = bt.ground(bt.escape_point + Vector3(0, 0, -1.4))      # 家豪站在門檻上
	bt.bird.set_state("linger")                              # 站著不動，等狼外婆過來
	var thrown := [false]
	steps(3.0, func():
		if bt.bird.state == "linger":
			bt.bird.t = -9999.0
		if bt.bird.state == "fly":
			thrown[0] = true)
	ok(not bt.hood_saved, "狼外婆在看著的時候救不到小紅帽")
	ok(thrown[0] and bt.bird.hp < hp0, "家豪被拍出門外、扣血（剩 %.0f）" % bt.bird.hp)
	ok(ev("拍出門外") >= 0.0, "記錄寫了狼外婆出手")

	print("== 籃子引開狼外婆才救得到")
	bt.reset()
	bt.start()
	park_bird()
	bt.add_basket(bt.ground(bt.escape_point + Vector3(1.4, 0, -0.4)))
	steps(4.0, func(): bt.bird.t = -9999.0)
	ok(not bt._wolf_guarding(), "狼外婆去聞籃子，沒在看著")
	bt.bird.pos = bt.ground(bt.escape_point + Vector3(-0.6, 0, -1.4))
	bt.bird.set_state("charge")
	steps(0.5)
	ok(bt.hood_saved, "趁狼外婆在聞籃子，家豪進屋救出小紅帽")

	print("== 家豪不會自己跑進木屋")
	bt.reset()
	bt.start()
	bt.bird.pos = bt.ground(Vector3(0.0, 0, 6.5))             # 離小紅帽不到 7.5 公尺
	var went_in := [false]
	steps(4.0, func():
		if bt._bird_in_house():
			went_in[0] = true)
	ok(not went_in[0], "外面還有人、也沒有旗子時，家豪不會自己走進木屋")

	print("== 林道：看假獵物的人一擊就倒")
	await load_stage("res://levels/forest/stage_1/stage.tscn")
	bt.reset()
	bt.start()
	var c1 = who("伐木1")
	bt.add_decoy(bt.ground(c1.pos + Vector3(0, 0, -3.0)))        # 假獵物在他北邊：他背對南邊的家豪
	steps(2.5, func(): bt.bird.t = -9999.0)
	ok(bt._is_lured(c1), "伐木1 在看假獵物（%s）" % c1.state)
	bt.bird.pos = bt.ground(c1.pos + Vector3(0, 0, 1.4))         # 家豪站在他背後
	ok(not bt.sees_bird(c1), "看假獵物的人沒發現背後的家豪")
	bt.bird.set_state("charge")
	steps(3.0)
	ok(not c1.alive() and bt.lure_kos == 1, "從背後一啄就倒（一擊 %d）" % bt.lure_kos)
	ok(bt._done.has("lure_ko"), "拿到「一擊打倒」那顆星")
	bt.reset()
	bt.start()
	var c2 = who("伐木2")
	bt.bird.pos = bt.ground(c2.pos + Vector3(0, 0, 1.2))
	bt.bird.set_state("charge")
	steps(1.5)
	ok(c2.alive(), "沒看假獵物的伐木工一啄不會倒（剩 %.1f）" % c2.hp)
	await load_stage(S1)

	print("== 引路點照放的順序")
	bt.reset()
	var far: Vector3 = bt.ground(Vector3(0, 0, -6.0))
	var near: Vector3 = bt.ground(bt.bird.pos + Vector3(0.0, 0, -1.5))
	bt.add_guide(far)
	bt.add_guide(near)
	ok(bt._next_guide().pos == far, "先放的先走（就算比較遠）")
	bt._number_guides()
	ok(bt.guides[0].label.text == "1" and bt.guides[1].label.text == "2", "數字照放的順序")

	print("== 小紅帽關整局跑完不出錯")
	bt.reset()
	bt.start()
	steps(90.0)
	ok(bt.phase == bt.Phase.ENDED, "分出勝負（%s，%s）" % [bt.outcome, bt.fail])
	print("   樹 砍 %d／燒 %d" % [bt.trees_cut, bt.trees_burnt])

	print("")
	print("FOREST MECHANICS: %d/%d ok" % [checks - fails, checks])
	print("FOREST: ALL PASS" if fails == 0 else "FOREST: FAILED (%d)" % fails)
	quit(1 if fails > 0 else 0)
