extends SceneTree
## 按 H 的提示流程（不開視窗）：輸一局 → 提示 1 打開、左上角有「新」→ R 重來、按 H 停在「這一關」頁 → 看過「新」消失 → 輸 3 次提示 2 打開 → 過關後全開
##   Godot --headless --path . -s res://levels/ice/tests/hint_flow.gd

func _initialize() -> void:
	_go.call_deferred()

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)

func _go() -> void:
	for path in ["res://levels/ice/stage_12/stage.tscn", "res://levels/heaven/stage_3/stage.tscn"]:
		print("== ", path)
		var sc := (load(path) as PackedScene).instantiate()
		Engine.set_meta("stage_id", "")
		root.add_child(sc)
		current_scene = sc
		await _frames(10)
		var bt = sc.get_node("Battle")
		var pop = bt.help_popup
		_check(pop != null and pop.get_script().resource_path.ends_with("ice_help_popup.gd"), "說明卡換成冰雪島版")
		_check(pop.pages.size() >= 4 and pop.pages[0].get("level", false), "第一頁是這一關（共 %d 頁）" % pop.pages.size())
		_check(pop.pages.any(func(p): return p.has("item")), "道具頁還在")
		_check(String(pop.pages.back().get("title", "")) == "操作方式", "最後一頁是操作方式")
		var b0: Array = bt._hint_board()
		_check(b0.size() == 3 and b0[1].open == false and b0[2].open == false, "一開始兩張提示都蓋著")
		_check(not bt._hint_fresh(), "一開始沒有「新」")
		# 輸一局
		bt._end("lose")
		await _frames(3)
		_check(bt.help_fails() == 1, "輸了一次 → 記到 1")
		var b1: Array = bt._hint_board()
		_check(b1[1].open and b1[1].fresh and not b1[2].open, "提示 1 打開並標新、提示 2 還蓋著")
		_check(bt._hint_fresh(), "左上角要亮「新」")
		# 回到準備階段，按 H
		bt.reset()
		await _frames(3)
		var ev := InputEventKey.new()
		ev.physical_keycode = KEY_H
		ev.keycode = KEY_H
		ev.pressed = true
		Input.parse_input_event(ev)
		await _frames(3)
		var up := ev.duplicate()
		up.pressed = false
		Input.parse_input_event(up)
		await _frames(2)
		_check(pop.is_open() and pop.page == 0, "按 H 打開說明卡、停在第一頁")
		_check(not bt._hint_fresh(), "看過以後「新」消失")
		pop.close()
		await _frames(2)
		# 再輸兩次 → 提示 2 打開
		bt.help_fake_fails(3)
		var b3: Array = bt._hint_board()
		_check(b3[2].open and b3[2].fresh, "輸 3 次 → 提示 2 打開")
		# 過關 → 全開、星星提示出現
		bt.help_fake_fails(0)
		bt._best()["rescue"] = true
		var bw: Array = bt._hint_board()
		_check(bw[1].open and bw[2].open, "過關以後全部打開")
		_check(bw.any(func(r): return r.get("star", false)), "過關以後有沒拿到的星星提示")
		bt._best().erase("rescue")
		sc.queue_free()
		await _frames(5)
	quit()
