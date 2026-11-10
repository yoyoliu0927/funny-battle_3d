extends SceneTree
## 冒煙測試：把每個大關的每個小關都打開、按開始、讓它自己打一陣子，確認沒有壞掉。
## 開 PR／合併前請跑一次：
##   Godot --headless --path . -s res://tools/smoke_test.gd
## 只測某個大關：在最後加上  -- --chapter=tainan
## 順便每關截一張圖（不能加 --headless）：在最後加上  -- --shots=/某個資料夾
## 全部通過會印出 SMOKE: ALL PASS，結束代碼是 0；有問題印 SMOKE: FAILED，結束代碼是失敗數。

const Registry := preload("res://scripts/registry.gd")
const RUN_SECONDS := 25.0      # 每關最多讓它打幾秒（遊戲內時間）

var fails := 0
var shots_dir := ""

func _initialize() -> void:
	_run.call_deferred()

func _check(name: String, ok: bool, detail := "") -> void:
	if not ok:
		fails += 1
	print("[%s] %s %s" % ["PASS" if ok else "FAIL", name, detail])

func _run() -> void:
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--chapter="):
			only = a.substr(10)
		if a.begins_with("--shots="):
			shots_dir = a.substr(8)
			DirAccess.make_dir_recursive_absolute(shots_dir)
	var chapters := Registry.chapters()
	_check("找到大關", not chapters.is_empty(), "%d 個" % chapters.size())
	for ch in chapters:
		if only != "" and ch.id != only:
			continue
		_check("%s 至少有 3 個小關" % ch.id, ch.stages.size() >= 3 or ch.example, "（%d 個）" % ch.stages.size())
		for st in ch.stages:
			await _run_stage(st)
	Engine.time_scale = 1.0
	print("SMOKE: %s" % ("ALL PASS" if fails == 0 else "FAILED (%d)" % fails))
	quit(fails)

func _run_stage(st: Dictionary) -> void:
	var tag: String = st.id
	if not ResourceLoader.exists(st.scene):
		_check(tag + " 場景存在", false, st.scene)
		return
	Engine.set_meta("stage_id", st.id)
	var err := change_scene_to_file(st.scene)
	if err != OK:
		_check(tag + " 場景載得起來", false, error_string(err))
		return
	for i in 5:
		await process_frame
	var bt: Node = current_scene.get_node_or_null("Battle") if current_scene else null
	if bt == null or not bt.has_method("start"):
		_check(tag + " 戰局腳本正常", false, "Battle 節點沒有掛 battle_base 的腳本（多半是腳本有錯）")
		return
	_check(tag + " 道具 1~9 個", bt.items.size() >= 1 and bt.items.size() <= 9, "（%d 個）" % bt.items.size())
	_check(tag + " 至少一個敵人", bt.enemies.size() >= 1, "（%d 個）" % bt.enemies.size())
	var w: Node = bt.world
	_check(tag + " 家豪站在走得到的地方", w.walkable(bt.bird.pos.x, bt.bird.pos.z))
	var bad := []
	for f in bt.enemies:
		if not w.walkable(f.pos.x, f.pos.z):
			bad.append(f.name)
	_check(tag + " 敵人都站在走得到的地方", bad.is_empty(), str(bad))
	await _shot(tag + "_a_prepare")
	bt.start()
	Engine.time_scale = 4.0
	var waited := 0
	while bt.phase != bt.Phase.ENDED and bt.time < RUN_SECONDS and waited < 3000:
		await physics_frame
		waited += 1
	Engine.time_scale = 1.0
	_check(tag + " 開打後會動", bt.time > 1.0, "（%.1f 秒，%s）" % [bt.time, bt.outcome if bt.outcome != "" else "還沒分出勝負"])
	await _shot(tag + "_b_end")
	bt.reset()
	await process_frame
	_check(tag + " 按 R 重置回準備階段", bt.phase == bt.Phase.PREPARE and bt.time == 0.0)

func _shot(name: String) -> void:
	if shots_dir == "" or not DisplayServer.window_can_draw():
		return
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(shots_dir.path_join(name.replace("/", "_") + ".png"))
