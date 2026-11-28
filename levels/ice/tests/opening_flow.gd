extends SceneTree
## 大關開場動畫什麼時候播（levels/ice/story/story_registry.gd）：
##   在選關地圖按某一章的第 1 關 → 每次都播（看過了也播）；按其他小關 → 不播。
##   開場按 Esc 跳過 → 載入畫面 → 第 1 關，而且第 1 關不會又轉回開場（冰雪島、丹穴山的第 1 關自己也會問）。
## 無頭模式、帶 -- 旗標都算測試，開場本來就不播，所以這支要開視窗跑，輸出資料夾用環境變數 OPENING_OUT 給：
##   bash levels/ice/tests/opening_flow.sh [輸出資料夾]
## sh 用一個空的 HOME 開（不碰玩家的存檔）、沒有聲音；關卡的 Player 一進樹就換成 still_player.gd（不鎖游標、不搶滑鼠）。
const Story := preload("res://levels/ice/story/story_registry.gd")
const Kit := preload("res://levels/ice/story/story_kit.gd")
const IceStory := preload("res://levels/ice/story/ice_story.gd")
const Chapters := preload("res://scripts/registry.gd")
const STILL := preload("res://levels/ice/tests/still_player.gd")
const PLAYER := "res://scripts/player.gd"
const LOADING := "res://scenes/loading.tscn"
const IDS := ["ice", "forest", "liuchiyu", "fort", "heaven"]

var _out := ""
var _bad := 0
var _lines := PackedStringArray()

func _initialize() -> void:
	node_added.connect(_swap_player)
	_go.call_deferred()

## 關卡的 Player 一進樹（還沒 _ready）就換掉腳本，才不會鎖游標
func _swap_player(n: Node) -> void:
	if n.name == &"Player" and n.get_script() is Script and (n.get_script() as Script).resource_path == PLAYER:
		n.set_script(STILL)

func _say(ok: bool, msg: String) -> void:
	if not ok:
		_bad += 1
	var line := ("OK   " if ok else "FAIL ") + msg
	print(line)
	_lines.append(line)

func _scene() -> String:
	return current_scene.scene_file_path if current_scene != null else ""

func _until(cond: Callable, sec: float) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		if Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		if cond.call():
			return true
		await process_frame
	return false

func _wait(sec: float) -> void:
	await _until(func(): return false, sec)

func _snap(name: String) -> void:
	if _out == "":
		return
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_jpg(_out.path_join(name + ".jpg"), 0.8)

func _go() -> void:
	_out = OS.get_environment("OPENING_OUT")
	if _out != "":
		DirAccess.make_dir_recursive_absolute(_out)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_say(not Kit.quiet(), "這次不算測試模式（不然開場本來就不播）")
	var stage1 := {}
	for ch in Chapters.chapters():
		if String(ch.id) in IDS and not (ch.stages as Array).is_empty():
			stage1[String(ch.id)] = String(ch.stages[0].scene)
	# 1) 按哪一關才播
	for id in IDS:
		Engine.set_meta("stage_id", id + "/2")
		_say(Story.opening_for(id) == "", "%s 按第 2 關：不播開場" % id)
		Engine.set_meta("stage_id", id + "/1")
		_say(Story.opening_for(id) != "", "%s 按第 1 關：播開場" % id)
	# 2) 真的走一次：每一章按兩次第 1 關（第二次已經看過了，也要再播）
	for id in IDS:
		for k in 2:
			await _flow(id, String(stage1.get(id, "")), k + 1)
	Engine.set_meta("stage_id", "")
	_lines.append("SUMMARY %s（%d 項失敗）" % ["ALL PASS" if _bad == 0 else "FAIL", _bad])
	print(_lines[-1])
	if _out != "":
		var f := FileAccess.open(_out.path_join("result.txt"), FileAccess.WRITE)
		f.store_string("\n".join(_lines) + "\n")
		f.close()
		FileAccess.open(_out.path_join("DONE"), FileAccess.WRITE).close()
	quit(1 if _bad > 0 else 0)

## 照選關地圖按下第 1 關的做法（scripts/level_select.gd：設 next_scene、stage_id，再問 opening_for）
func _flow(id: String, stage: String, nth: int) -> void:
	var tag := "%s 第 %d 次" % [id, nth]
	Engine.set_meta("next_scene", stage)
	Engine.set_meta("stage_id", id + "/1")
	var op := Story.opening_for(id)
	_say(op != "", tag + "：地圖要先播開場")
	if op == "" or stage == "":
		return
	change_scene_to_file(op)
	var shown: bool = await _until(func(): return _scene() == op and current_scene.process_mode == Node.PROCESS_MODE_INHERIT and current_scene.get("_fade") != null, 30.0)
	_say(shown, tag + "：開場出現")
	if not shown:
		return
	await _wait(1.5)
	await _snap("%s_%d_opening" % [id, nth])
	if id == "heaven":
		_say(Story.opening_pending("heaven") == "", tag + "：開場開始之後，丹穴山 1 自己不會再轉回開場")
	if id == "ice":
		_say(not IceStory.opening_pending(), tag + "：開場開始之後，冰雪島 1 自己不會再轉回開場")
	current_scene.skip()
	var to_load: bool = await _until(func(): return _scene() == LOADING, 15.0)
	_say(to_load, tag + "：跳過之後走載入畫面")
	var in_stage: bool = await _until(func(): return _scene() == stage, 40.0)
	_say(in_stage, tag + "：進第 1 關（%s）" % stage.get_file().get_basename())
	if not in_stage:
		return
	await _wait(2.5)
	_say(_scene() == stage, tag + "：停在第 1 關，沒有又轉回開場")
	await _snap("%s_%d_stage" % [id, nth])
