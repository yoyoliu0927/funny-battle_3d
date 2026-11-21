extends SceneTree
## 家豪在木屋後面、引路點插在門口：家豪走不走得到？（從很多個起點試）
## Godot --headless --path . --script res://levels/forest/tests/guide_reach.gd
const DT := 1.0 / 60.0
const S1 := "res://levels/forest/stage_1/stage.tscn"
var bt

func _initialize() -> void:
	_go.call_deferred()

func flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

## 屋裡的引路點：家豪一進屋就救到小紅帽、這局就結束了，所以「走進屋、離點不遠」也算走到

func _go() -> void:
	change_scene_to_file(S1)
	for i in 6:
		await process_frame
	bt = current_scene.get_node("Battle")
	bt.set_physics_process(false)
	bt.set_process(false)
	var starts := []
	for x in [-7.0, -4.5, -2.0, 0.0, 2.0, 4.5, 7.0]:
		for z in [-4.0, -6.5]:
			starts.append(Vector3(x, 0, z))
	for x in [-5.0, 5.0]:
		for z in [-1.0, 1.5]:
			starts.append(Vector3(x, 0, z))
	var fails := 0
	var front: Array = []
	for x in [-6.0, -2.5, 0.0, 2.5, 6.0]:
		front.append(Vector3(x, 0, 7.5))
	var cases: Array = []                    # [起點, 引路點]
	for st in starts:
		cases.append([st, bt.escape_point + Vector3(0, 0, 1.2)])     # 屋後 → 門口
		cases.append([st, Vector3(0.8, 0, 0.6)])                     # 屋後 → 屋裡
	for st in front:
		cases.append([st, Vector3(0.0, 0, -4.6)])                    # 屋前 → 屋後
	for cs in cases:
		var st: Vector3 = cs[0]
		var door: Vector3 = cs[1]
		bt.reset()
		for f in bt.enemies:                       # 敵人全部放到很遠，只看走路
			f.pos = bt.ground(Vector3(15.0, 0, 13.0))
			f.set_state("dead")
		bt.add_guide(bt.ground(door))
		bt.start()
		bt.bird.pos = bt.ground(st)
		var trail := PackedVector2Array()
		var reached := -1.0
		var t := 0.0
		while t < 20.0 and bt.phase == bt.Phase.RUNNING:
			bt._step(DT)
			t += DT
			if int(t * 60) % 30 == 0:
				trail.append(Vector2(bt.bird.pos.x, bt.bird.pos.z))
			var indoor: bool = bt.world.in_house(door.x, door.z)
			if bt.guides[0].used or (indoor and bt.world.in_house(bt.bird.pos.x, bt.bird.pos.z) and flat(bt.bird.pos, door) < 3.5):
				reached = t
				break
		var ok := reached >= 0.0
		if not ok:
			fails += 1
		var tail := ""
		for k in range(maxi(0, trail.size() - 4), trail.size()):
			tail += "(%.1f,%.1f) " % [trail[k].x, trail[k].y]
		print("  %s (%.1f, %.1f) → (%.1f, %.1f)  %s   最後：%s" % ["ok  " if ok else "FAIL", st.x, st.z, door.x, door.z,
			("%.1f 秒到" % reached) if ok else "20 秒還沒到", tail])
	print("GUIDE REACH: ALL PASS" if fails == 0 else "GUIDE REACH: FAILED (%d)" % fails)
	quit(1 if fails > 0 else 0)
