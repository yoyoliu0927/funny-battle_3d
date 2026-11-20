extends "res://scripts/battle/battle_base.gd"
## 森林戰局。
## 伐木工會去砍離自己最近、還沒人佔的樹；砍倒的樹變成橫躺的樹幹，會擋路、也會擋火。
## 抽菸的人每隔一陣子彈一根菸蒂；菸被打斷（去看假獵物、挨打）也會丟在地上。
## 菸蒂放著不管就會點著附近的樹，火會往旁邊延燒。家豪走過去可以踩熄。
## 站著的樹會擋住視線，從樹後面摸過去就能偷襲。
## 假獵物把附近的人引開（狼外婆不理）。外婆的籃子只引得動狼外婆。
## 引路點照放下的順序走；走到人旁邊會停下來打。
## 狼外婆守著小紅帽：家豪闖進屋會被拍出門外。只有外婆的籃子引得開她，趁她在聞的時候進屋才救得到。
## 家豪不會自己跑進木屋，要用引路點帶她進去（外面的人都倒了才會自己去）。

const CHOP_TIME := 5.0
const LURE_LIFE := 12.0
const ATTRACT := 7.0           # 假獵物的吸引範圍（舊版 11 公尺，整張圖的人都被拉過去，變成一團）
const ENGAGE := 2.55          # 家豪走到這麼近就會停下來打
const STICKY := 4.4           # 已經開打的話，拉開到這麼遠才會回去跟引路點
const LOCK := ["windup", "recover", "stagger", "down", "getup", "slip", "startled"]
const Models := preload("res://levels/forest/items/models.gd")
const ForestTutorial := preload("res://levels/forest/forest_tutorial.gd")
const IconOverlay := preload("res://levels/forest/icon_overlay.gd")
const ForestSfx := preload("res://levels/forest/forest_sfx.gd")
const MUSIC_DB := {"bgm_plan": -14.0, "bgm_run": -13.0}
const MUSIC_OFF := -60.0
var _sounds := {}             # 名字 → AudioStreamWAV
var _music := {}              # bgm_plan / bgm_run → AudioStreamPlayer
var _sfx_2d := {}             # 不分位置的音效 → AudioStreamPlayer
var _audio_wanted := false
var _audio_task := -1
var tut: ForestTutorial
static var _forest_tut_seen := {}    # 這次開遊戲已經看完（或跳過）教學的小關

const BUTT_EVERY := 8.0       # 抽菸的人每抽這麼久彈一根菸蒂
const BUTT_FUSE := 6.0        # 菸蒂在地上悶燒這麼久才點著樹
const STOMP_R := 0.95         # 家豪走到這麼近就踩熄
const SPARK_R := 5.5          # 菸蒂點得到多遠的樹
const SPREAD_R := 5.8         # 火燒得到多遠的鄰樹
const SPREAD_AFTER := 4.5     # 一棵樹燒多久才往旁邊延燒（只延燒一次）
const SPREAD_CHANCE := 0.55   # 延燒的機率（固定 seed，每次重玩都一樣）
const BURN_TIME := 9.0        # 燒多久變成焦黑的樹樁
const LOS_R := 0.55           # 視線離樹幹這麼近就被擋住
const BASKET_LIFE := 9.0
const LURE_START_R := 7.0     # 木屋門口的假獵物：家豪走到離門這麼近才開始算時間（準備階段先放也不會過期）
const BUCKET_R := 3.8         # 水桶潑到多遠
const WET_TIME := 26.0        # 淋濕的樹這麼久（開打後的秒數）點不著
const CUT_GAP := 5.0          # 兩段特寫之間至少隔幾秒（遊戲時間）
const SLOWMO := 0.35
const SLOWMO_MS := 450

var want_trees := false
var tree_cap := 20
var want_smoke := false
var want_hood := false
var butt_every := BUTT_EVERY
var chop_time := CHOP_TIME
var hood_cap := 80.0

var grove: Array = []
var trees_cut := 0
var trees_burnt := 0
var butts: Array = []         # {pos, node, tip, fuse}
var baskets: Array = []       # {pos, node, life}
var puddles: Array = []       # 水桶潑出來的濕地 {pos, node, life}
var _log_spots: Array = []    # 倒下的樹幹加進 world.obstacles 的圓，重試時拿掉
var _fire_rng := RandomNumberGenerator.new()
var warn_fire := false
var _cut_cam: Camera3D
var _cut_t := 0.0             # 特寫還剩幾秒（遊戲時間）
var _cut_gap := 0.0           # 遊戲時間到這裡之前不切下一段特寫
var _slow_until := 0
var _seen := {}               # 這一局已經播過的「第一次」特寫
var _pops: Array = []         # 飄起來的字 {node, y, ms}
var _held_toast: Array = []   # 特寫時先收著的提示 [text, dur]
var cuts_in_tests := false    # 自動測試預設不切特寫；截圖腳本會打開
var dinner := 0.0
var hood_saved := false
var hood: Node3D
var hood_home := Vector3.ZERO
var hood_run := 0.0
var escape_point := Vector3(0, 0, 4.4)
var guides: Array = []        # {pos, node, label, used}
var decoys: Array = []        # {pos, node, life}
var fail := ""
var warn_trees := false
var warn_hood := false
var ignited := false
var last_hurt_by := ""        # 最後一個打到家豪的人（結算畫面講死因）
var swats := 0
var sneaks := 0               # 這一局偷襲成功幾次
var _range: MeshInstance3D
## 選關地圖讀這張表（場景路徑 → {目標 id: true}）。只有過關才寫進去，這次開遊戲期間累積。
static var best_stars := {}
var _done := {}
var _new_stars: Array = []
var _goal_layer: CanvasLayer
var _goal_rows: VBoxContainer

func _want_trees() -> bool:
	return false

func _tree_cap() -> int:
	return 20

## 抽菸的人會彈菸蒂（會起火）
func _want_smoke() -> bool:
	return false

func _want_hood() -> bool:
	return false

func _hood_cap() -> float:
	return 80.0

## 抽菸的人多久彈一根菸蒂、伐木工砍一棵樹要多久（關卡可以覆寫）
func _butt_every() -> float:
	return BUTT_EVERY

func _chop_time() -> float:
	return CHOP_TIME

## 天色進度 0~1（0＝場地設定的 look，1＝look2）。第三關跟著小紅帽的計時走。
func _look_k() -> float:
	return 0.0

# ---------------------------------------------------------------- 建立

func _level_setup() -> void:
	want_trees = _want_trees()
	tree_cap = _tree_cap()
	want_smoke = _want_smoke()
	want_hood = _want_hood()
	butt_every = _butt_every()
	chop_time = _chop_time()
	hood_cap = _hood_cap()
	var listed = world.get("trees")
	grove = listed if listed != null else []
	hood = world.get_node_or_null("RedHood") as Node3D
	if hood:
		hood_home = hood.position
	var door = world.get("escape_point")
	if door != null:
		escape_point = door
	_dress_fighters()
	_build_range_ring()
	_cut_cam = Camera3D.new()
	_cut_cam.name = "CloseUpCam"
	_cut_cam.fov = 50.0
	world.add_child(_cut_cam)
	var hint := get_node_or_null("../HUD/Hint") as Label
	if hint:
		hint.text = "滑鼠轉視角、準心對地面｜左鍵 放下｜WASD 移動｜空白 上升｜Shift 下降｜數字鍵／滾輪 選道具｜Enter 開始｜R 重試｜M 地圖｜T 再看教學"
		_plain_dark(hint)
	_build_goals()
	_cover_hotbar_stickers.call_deferred()   # 道具欄是 _level_setup 之後才建的
	_setup_audio()
	if not _tutorial_steps().is_empty():
		show_tutorial = false            # 有自己的教學：開場不跳共用的教學彈窗（按 H 還是看得到）
		_start_tut.call_deferred()       # HUD 都建好之後才開始

# ---------------------------------------------------------------- 聲音
## 配樂和音效都在 forest_sfx.gd 用程式合成。自動測試不出聲（也不用花時間合成）。

## 第一次進森林時，合成丟到背景執行緒做（要好幾秒），好了再接上；之後都直接用算好的
func _setup_audio() -> void:
	if _automated_run() and not Engine.has_meta("forest_audio_force"):
		return
	_audio_wanted = true
	if ForestSfx.is_ready():
		_attach_audio()
	elif not ForestSfx.building():
		_audio_task = WorkerThreadPool.add_task(ForestSfx.make_all, false, "森林音效合成")

func _poll_audio() -> void:
	if not _audio_wanted or not _sounds.is_empty() or not ForestSfx.is_ready():
		return
	if _audio_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_audio_task)
		_audio_task = -1
	_attach_audio()

func _attach_audio() -> void:
	_sounds = ForestSfx.make_all()
	for k in MUSIC_DB:
		var mp := AudioStreamPlayer.new()
		mp.stream = _sounds[k]
		mp.volume_db = MUSIC_OFF
		add_child(mp)
		mp.play()
		_music[k] = mp

## 播一個音效。at＝場上的位置（有遠近和左右）；不給就是直接在耳邊
func sfx(name: String, at = null, db := 0.0) -> void:
	if _sounds.is_empty() or not _sounds.has(name):
		return
	if at is Vector3 and fx_root:
		var p3 := AudioStreamPlayer3D.new()
		p3.stream = _sounds[name]
		p3.volume_db = db
		p3.unit_size = 7.0
		p3.max_db = 3.0
		p3.position = at
		spawn_timed(p3, (_sounds[name] as AudioStreamWAV).get_length() + 0.1)
		p3.play()
		return
	var p: AudioStreamPlayer = _sfx_2d.get(name)
	if p == null:
		p = AudioStreamPlayer.new()
		p.stream = _sounds[name]
		p.max_polyphony = 4
		add_child(p)
		_sfx_2d[name] = p
	p.volume_db = db
	p.play()

## 跟著著火的樹的劈啪聲（掛在火焰底下，樹燒完就一起消失）
func _attach_crackle(root: Node3D) -> void:
	if not _sounds.has("crackle"):
		return
	var p3 := AudioStreamPlayer3D.new()
	p3.stream = _sounds["crackle"]
	p3.volume_db = -6.0
	p3.unit_size = 5.0
	p3.position.y = 1.5
	root.add_child(p3)
	p3.play(fmod(float(grove.size() + trees_burnt) * 0.37, 1.9))   # 每棵起點不同，疊起來不會整齊劃一

## 配樂：準備階段放安靜版、開打放熱鬧版（兩首一直同步在播，只換音量）；結束後慢慢收掉
func _tick_music(dt: float) -> void:
	if _music.is_empty():
		return
	var on := ""
	if phase == Phase.PREPARE:
		on = "bgm_plan"
	elif phase == Phase.RUNNING:
		on = "bgm_run"
	for k in _music:
		var p: AudioStreamPlayer = _music[k]
		var want: float = MUSIC_DB[k] if k == on else MUSIC_OFF
		if phase == Phase.ENDED and k == "bgm_plan" and not defeat_shown:
			want = MUSIC_DB[k] - 8.0                 # 結束畫面留一點點森林的聲音
		var rate := 40.0 if want > p.volume_db else 25.0
		p.volume_db = move_toward(p.volume_db, want, rate * dt)

## 每一步：有人被打倒就「咻——」一聲
func _sound_step() -> void:
	for f in enemies:
		var up: bool = f.alive()
		if f.data.get("was_up", true) and not up:
			sfx("down", f.pos)
		f.data["was_up"] = up

func cast(i: int, p: Vector3) -> bool:
	var ok := super(i, p)
	if ok and i < items.size():
		sfx(String(items[i].id), ground(p))
	return ok

func start() -> void:
	super()
	sfx("go")

func _hit_enemy(f: Fighter, dmg: float, from: Vector3) -> void:
	super(f, dmg, from)
	sfx("peck", f.pos, -3.0)

func hit_bird(dmg: float, heavy: bool, from: Vector3, by: Fighter = null) -> void:
	if by != null:
		last_hurt_by = by.kind
	super(dmg, heavy, from, by)
	sfx("ouch", bird.pos)

## 道具欄圖示底下那顆深棕色圓貼紙蓋掉（見 icon_overlay.gd）
func _cover_hotbar_stickers() -> void:
	if _hotbar == null or _hotbar.get_node_or_null("IconOverlay") != null:
		return
	var ov := IconOverlay.new()
	ov.name = "IconOverlay"
	_hotbar.add_child(ov)

# ---------------------------------------------------------------- 新手教學

## 這一小關的教學步驟（格式見 forest_tutorial.gd）；空陣列＝沒有教學
func _tutorial_steps() -> Array:
	return []

func tut_on() -> bool:
	return tut != null and tut.active()

func _start_tut() -> void:
	var key := String(get_parent().scene_file_path)
	if _forest_tut_seen.has(key):
		return
	if _automated_run() and not Engine.has_meta("forest_tut_force"):   # 自動測試不跑教學（截圖腳本會設 forest_tut_force）
		return
	if tut != null:
		tut.queue_free()
	tut = ForestTutorial.new()
	tut.name = "ForestTutorial"
	add_child(tut)
	tut.finished.connect(func(): _forest_tut_seen[key] = true)
	tut.begin(self, _tutorial_steps())

## 再看一次教學（T 鍵）
func replay_tutorial() -> void:
	if phase != Phase.PREPARE or tut_on() or _tutorial_steps().is_empty():
		return
	_forest_tut_seen.erase(String(get_parent().scene_file_path))
	_start_tut()

## 給教學步驟用的小工具
func tut_enemy(n: String) -> Fighter:
	for f in enemies:
		if f.name == n:
			return f
	return null

func tut_selected(id: String) -> bool:
	return not items.is_empty() and items[selected].id == id

func _plain_dark(hint: Label) -> void:
	hint.remove_theme_stylebox_override("normal")
	var ink := Color(0.16, 0.1, 0.06)
	hint.add_theme_color_override("font_color", ink)
	hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0))
	hint.add_theme_constant_override("outline_size", 0)
	if hint.label_settings:
		var ls := hint.label_settings.duplicate() as LabelSettings
		ls.font_color = ink
		ls.outline_size = 0
		hint.label_settings = ls

## 「過關」那一行放在道具欄下面，貼著畫面底。
func _place_goal_line() -> void:
	if _phase_label == null or _hotbar == null:
		return
	var hb: Vector2 = _hotbar.bar_size()
	_hotbar.offset_top = -hb.y - 58.0
	_hotbar.offset_bottom = -58.0
	# 跟其他大關一樣放在畫面上方中間（底下是道具欄、愛心和開始鈕）
	_phase_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_phase_label.offset_left = 0
	_phase_label.offset_right = 0
	_phase_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_phase_label.offset_top = 18
	_phase_label.offset_bottom = 58
	_phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if _dialog:
		_dialog.offset_top = -hb.y - 58.0 - 20.0 - 120.0
		_dialog.offset_bottom = -hb.y - 58.0 - 20.0

func _set_tut_step(i: int) -> void:
	super(i)
	if pause_menu:
		pause_menu.hotkey = tutorial_step < 0

func _input(event: InputEvent) -> void:
	if tutorial_step < 0:
		return
	var key_ev := event as InputEventKey
	if key_ev == null or not key_ev.pressed or key_ev.echo:
		return
	var key := key_ev.physical_keycode if key_ev.physical_keycode != KEY_NONE else key_ev.keycode
	if key != KEY_ESCAPE:
		return
	_set_tut_step(-1)
	get_viewport().set_input_as_handled()

func _dress_fighters() -> void:
	for f in enemies:
		if f.kind == "wolf":
			_wear_wolf(f)
		elif f.kind == "chopper":
			_wear_axe(f)
		elif f.kind == "smoker":
			_wear_smoke(f)

func _wear_wolf(f: Fighter) -> void:
	var gray := _tint(Color(0.55, 0.55, 0.58))
	var cloth := _tint(Color(0.85, 0.82, 0.74))
	_peg(f.node, Vector3(0.16, 0.28, 0.16), Vector3(-0.2, 2.42, 0.05), gray, Vector3(0, 0, 0.5))
	_peg(f.node, Vector3(0.16, 0.28, 0.16), Vector3(0.2, 2.42, 0.05), gray, Vector3(0, 0, -0.5))
	_peg(f.node, Vector3(0.22, 0.16, 0.28), Vector3(0, 2.05, 0.38), gray)          # 狼嘴
	_peg(f.node, Vector3(0.34, 0.28, 0.34), Vector3(0, 2.55, 0), cloth)            # 睡帽
	_peg(f.node, Vector3(0.5, 0.08, 0.5), Vector3(0, 1.35, 0.05), _tint(Color(0.45, 0.18, 0.22)))  # 披肩

func _wear_axe(f: Fighter) -> void:
	_peg(f.node, Vector3(0.08, 0.72, 0.08), Vector3(0.32, 1.05, 0.2), _tint(Color(0.45, 0.28, 0.14)))
	_peg(f.node, Vector3(0.34, 0.16, 0.08), Vector3(0.32, 1.4, 0.2), _tint(Color(0.65, 0.66, 0.7)))

func _wear_smoke(f: Fighter) -> void:
	_peg(f.node, Vector3(0.05, 0.05, 0.22), Vector3(0.22, 1.55, 0.32), _tint(Color(0.9, 0.9, 0.86)))
	var puff := _peg(f.node, Vector3(0.18, 0.18, 0.18), Vector3(0.22, 1.75, 0.48), _tint(Color(0.8, 0.8, 0.82)))
	puff.name = "CigarettePuff"

func _peg(parent: Node3D, size: Vector3, pos: Vector3, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi

func _tint(c: Color) -> Material:
	return world._toon(c)

func _level_reset() -> void:
	if world.has_method("set_look"):
		world.call("set_look", 0.0)
	_place_goal_line()
	_cut_off()
	Engine.time_scale = 1.0
	_slow_until = 0
	_cut_gap = 0.0
	_seen.clear()
	guides.clear()
	decoys.clear()
	butts.clear()        # 模型都在 fx_root 底下，已經被一起刪掉了
	baskets.clear()
	puddles.clear()
	for s in _log_spots:
		world.obstacles.erase(s)
	_log_spots.clear()
	_fire_rng.seed = int(world.get("world_seed") if world.get("world_seed") != null else 0) + 777
	trees_cut = 0
	trees_burnt = 0
	_stuck_t = 0.0
	_stuck_pos = Vector3.ZERO
	sneaks = 0
	swats = 0
	last_hurt_by = ""
	dinner = 0.0
	hood_saved = false
	hood_run = 0.0
	fail = ""
	warn_trees = false
	warn_fire = false
	warn_hood = false
	ignited = false
	_done.clear()
	_new_stars.clear()
	if _goal_layer:
		_goal_layer.visible = true
	_refresh_goals()
	for t in grove:
		for pair in t.get("leaf_mats", []):
			if is_instance_valid(pair[0]):
				(pair[0] as MeshInstance3D).material_override = pair[1]
		t.leaf_mats = []
		t.alive = true
		t.wet = 0.0
		t.fall = 0.0
		t.fire = -1.0
		t.burnt = false
		t.spread = false
		t.flame = null
		t.dir = Vector3.ZERO
		t.block[1] = t.radius
		var n := t.node as Node3D
		n.rotation = Vector3.ZERO
		n.position = t.rest
		if n.get_child_count() > 0:
			(n.get_child(0) as Node3D).visible = true      # 樹幹
		var crown := n.get_node_or_null("Crown") as Node3D
		if crown:
			crown.scale = Vector3.ONE
			crown.visible = true
	if hood:
		hood.visible = true
		hood.position = hood_home
		hood.rotation.y = PI

func _level_start() -> void:
	if want_hood:
		toast("小紅帽在木屋裡！", 1.6)
		log_event("狼外婆正要吃掉小紅帽")

# ---------------------------------------------------------------- 瞄準
## 操作跟南方島嶼一樣：游標鎖在畫面正中（中央圓圈是準心），滑鼠轉視角，左鍵放在準心指的地面。
## 舊版曾經把游標放出來、鏡頭轉不動，跟其他大關不一樣，已拿掉。

func _build_range_ring() -> void:
	if _range != null:
		return
	_range = MeshInstance3D.new()
	_range.name = "DecoyRange"
	var tm := TorusMesh.new()
	tm.inner_radius = 0.985
	tm.outer_radius = 1.0
	tm.rings = 48
	tm.ring_segments = 6
	_range.mesh = tm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.72, 0.46, 0.22, 0.45)
	_range.material_override = mat
	_range.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_range.visible = false
	world.add_child(_range)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).physical_keycode == KEY_T:
		replay_tutorial()
		get_viewport().set_input_as_handled()
		return
	super(event)

func _show_range() -> void:
	if _range == null:
		return
	var show: bool = phase != Phase.ENDED and aim_point != null and not items.is_empty() and items[selected].id == "decoy" and not defeat_shown
	_range.visible = show
	if show:
		_range.global_position = (aim_point as Vector3) + Vector3(0, 0.05, 0)
		_range.scale = Vector3(ATTRACT, 1.0, ATTRACT)

# ---------------------------------------------------------------- 放置

func guide_error(p: Vector3) -> String:
	if world.in_water(p.x, p.z):
		return "不能放在水裡"
	if not world.walkable(p.x, p.z):
		return "這裡放不了"
	if hits_obstacle(Vector2(p.x, p.z)):
		return "樹擋住了"
	for g in guides:
		if not g.used and flat_dist(g.pos, p) < 1.05:
			return "離另一個點太近"
	return ""

func decoy_error(p: Vector3) -> String:
	var err := guide_error(p)
	if err == "離另一個點太近":
		err = ""
	if err != "":
		return err
	for d in decoys:
		if d.life > 0.0 and flat_dist(d.pos, p) < 1.4:
			return "離另一隻太近"
	if want_hood and _wolf_lure_spot(p):
		for b in baskets:
			if b.life > 0.0:
				return "狼外婆已經在聞了"
	return ""

func add_guide(p: Vector3) -> void:
	var root := Node3D.new()
	root.position = ground(p)
	fx_root.add_child(root)
	Models.guide(root)
	var label := Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.fixed_size = true
	label.font_size = 64
	label.pixel_size = 0.00048
	label.outline_size = 16
	label.outline_modulate = Color(0.15, 0.12, 0.02)
	label.modulate = Color(1, 0.95, 0.55)
	label.position = Vector3(0, 1.25, 0)
	label.text = "·"
	root.add_child(label)
	guides.append({"pos": ground(p), "node": root, "label": label, "used": false})

func add_decoy(p: Vector3) -> void:
	var root := Node3D.new()
	root.position = ground(p)
	fx_root.add_child(root)
	Models.decoy(root)
	decoys.append({"pos": ground(p), "node": root, "life": LURE_LIFE})
	log_event("放了一隻假獵物")
	# 放在木屋裡或門口：狼外婆也會走過去聞（她不理外面的假獵物）
	if want_hood and not hood_saved and _wolf_lure_spot(p):
		baskets.append({"pos": ground(p), "node": root, "life": BASKET_LIFE, "on": false})
		log_event("狼外婆被假獵物引開")

## 木屋裡或門口（假獵物放在這裡才引得動狼外婆）
func _wolf_lure_spot(p: Vector3) -> bool:
	return world.has_method("in_house") and (world.in_house(p.x, p.z) or flat_dist(p, escape_point) <= 3.2)

## （舊的外婆的籃子，已經併進假獵物；留著給 baskets 清單用）
func basket_error(p: Vector3) -> String:
	if not want_hood or not world.has_method("in_house"):
		return "這一關沒有狼外婆"
	if hood_saved:
		return "小紅帽已經得救了"
	if world.in_water(p.x, p.z) or not world.walkable(p.x, p.z):
		return "這裡放不了"
	if hits_obstacle(Vector2(p.x, p.z)):
		return "樹擋住了"
	if not world.in_house(p.x, p.z) and flat_dist(p, escape_point) > 3.2:
		return "要放在木屋裡或門口"
	for b in baskets:
		if b.life > 0.0:
			return "已經有一個籃子了"
	return ""

func add_basket(p: Vector3) -> void:
	var root := Node3D.new()
	root.position = ground(p)
	fx_root.add_child(root)
	Models.basket(root)
	baskets.append({"pos": ground(p), "node": root, "life": BASKET_LIFE})
	log_event("放了外婆的籃子")

func _basket_active() -> int:
	for i in baskets.size():
		if baskets[i].life > 0.0:
			return i
	return -1

# ---------------------------------------------------------------- 水桶

func bucket_error(p: Vector3) -> String:
	if world.in_water(p.x, p.z) or not world.walkable(p.x, p.z):
		return "這裡放不了"
	if world.has_method("in_house") and world.in_house(p.x, p.z):
		return "不能潑進木屋"
	for q in puddles:
		if q.life > 0.0 and flat_dist(q.pos, p) < 1.8:
			return "這裡已經是濕的了"
	return ""

## 潑水：圈子裡的菸蒂熄掉、著火的樹救下來；沒著火的樹淋濕之後 WET_TIME 秒內點不著
func add_bucket(p: Vector3) -> void:
	var g := ground(p)
	var root := Node3D.new()
	root.position = g
	fx_root.add_child(root)
	var bk := Models.bucket(root)
	bk.position.y = 0.0
	# 濕地：藍色的圓，慢慢淡掉
	var disc := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = BUCKET_R
	cm.bottom_radius = BUCKET_R
	cm.height = 0.02
	cm.radial_segments = 40
	disc.mesh = cm
	var dm := StandardMaterial3D.new()
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.albedo_color = Color(0.35, 0.65, 0.95, 0.32)
	disc.material_override = dm
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	disc.position.y = 0.06
	disc.name = "Wet"
	root.add_child(disc)
	puddles.append({"pos": g, "node": root, "life": WET_TIME, "t": 0.0})
	for i in 7:
		var a := TAU * float(i) / 7.0
		_puff(g + Vector3(cos(a) * 1.4, 0.4 + 0.2 * float(i % 3), sin(a) * 1.4), Color(0.55, 0.78, 1.0))
	log_event("潑了一桶水")
	_burst(g + Vector3(0, 0.5, 0), "water", 26)
	var saved := 0
	var wetted := 0
	for i in range(butts.size() - 1, -1, -1):
		var bt: Dictionary = butts[i]
		if flat_dist(bt.pos, g) < BUCKET_R:
			(bt.node as Node3D).queue_free()
			butts.remove_at(i)
			_pop("淋熄！", bt.pos + Vector3(0, 1.1, 0), Color(0.7, 0.95, 1.0))
			saved += 1
	for t in grove:
		if flat_dist(t.pos, g) >= BUCKET_R:
			continue
		if t.fire >= 0.0 and not t.burnt:
			_douse_tree(t)
			saved += 1
		elif t.alive:
			t.wet = WET_TIME
			wetted += 1
	if saved > 0:
		toast("火熄了！", 1.0)
	elif wetted > 0:
		_pop("淋濕了", g + Vector3(0, 1.6, 0), Color(0.7, 0.9, 1.0))

## 著火的樹被澆熄：站回來、樹冠換回原本的顏色，不算燒掉
func _douse_tree(t: Dictionary) -> void:
	if t.flame != null and is_instance_valid(t.flame):
		(t.flame as Node3D).queue_free()
	t.flame = null
	t.fire = -1.0
	t.spread = false
	t.alive = true
	t.wet = WET_TIME
	trees_burnt = maxi(trees_burnt - 1, 0)
	for pair in t.get("leaf_mats", []):
		if is_instance_valid(pair[0]):
			(pair[0] as MeshInstance3D).material_override = pair[1]
	t.leaf_mats = []
	var crown := (t.node as Node3D).get_node_or_null("Crown") as Node3D
	if crown:
		crown.scale = Vector3.ONE
	_pop("得救了！", t.pos + Vector3(0, _tree_height(t) + 1.6, 0), Color(0.7, 0.95, 1.0))
	log_event("一棵著火的樹被澆熄")
	_puff(t.pos + Vector3(0, _tree_height(t), 0), Color(0.85, 0.9, 0.95))

func _tick_wet(dt: float) -> void:
	for t in grove:
		var w := float(t.get("wet", 0.0))
		if w > 0.0:
			t.wet = maxf(w - dt, 0.0)
	for q in puddles:
		if q.life > 0.0:
			q.life -= dt
			var disc := (q.node as Node3D).get_node_or_null("Wet") as MeshInstance3D
			if disc:
				var m := disc.material_override as StandardMaterial3D
				m.albedo_color.a = 0.32 * clampf(q.life / 6.0, 0.0, 1.0)
			if q.life <= 0.0:
				(q.node as Node3D).visible = false

# ---------------------------------------------------------------- 菸蒂和火

## 抽菸的人丟下一根菸蒂。why："flick"＝抽完彈掉；"drop"＝被打斷、菸掉在地上
func drop_butt(f: Fighter, why: String) -> void:
	var fwd := Vector3(sin(f.yaw), 0.0, cos(f.yaw))
	var p := ground(f.pos + fwd * (0.9 if why == "flick" else 0.45))
	if hits_obstacle(Vector2(p.x, p.z)):
		p = ground(f.pos)
	var root := Node3D.new()
	root.position = p
	fx_root.add_child(root)
	_peg(root, Vector3(0.05, 0.05, 0.2), Vector3(0, 0.04, 0), _tint(Color(0.95, 0.93, 0.88)), Vector3(0, f.yaw, 0))
	var tip := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.06
	sm.height = 0.12
	tip.mesh = sm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.35, 0.1)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.3, 0.05)
	m.emission_energy_multiplier = 2.5
	tip.material_override = m
	tip.position = Vector3(sin(f.yaw) * 0.1, 0.05, cos(f.yaw) * 0.1)
	root.add_child(tip)
	var wisp := _peg(root, Vector3(0.1, 0.1, 0.1), Vector3(0, 0.35, 0), _tint(Color(0.82, 0.82, 0.84)))
	wisp.name = "Wisp"
	butts.append({"pos": p, "node": root, "tip": tip, "fuse": BUTT_FUSE})
	sfx("flick", p, -4.0)
	if why == "flick":
		log_event("%s彈掉一根菸蒂" % f.name)
		_pop("菸蒂", p + Vector3(0, 0.9, 0), Color(1.0, 0.75, 0.45))
	else:
		log_event("%s的菸掉在地上" % f.name)
		_pop("菸掉了！", p + Vector3(0, 1.1, 0), Color(1.0, 0.6, 0.35))
		if _cut("drop", (p + f.pos) * 0.5 + Vector3(0, 0.7, 0), 1.5, 4.8, 1.8):
			toast("菸掉在地上了！讓家豪去踩熄", 1.6)

func _tick_butts(dt: float) -> void:
	for i in range(butts.size() - 1, -1, -1):
		var bt: Dictionary = butts[i]
		if bird.alive() and bird.state != "fly" and flat_dist(bird.pos, bt.pos) < STOMP_R:
			(bt.node as Node3D).queue_free()
			butts.remove_at(i)
			log_event("家豪踩熄菸蒂")
			_pop("踩熄！", bt.pos + Vector3(0, 1.2, 0), Color(0.7, 0.95, 1.0))
			sfx("stomp", bt.pos)
			_burst(bt.pos + Vector3(0, 0.1, 0), "dust", 8)
			_puff(bt.pos, Color(0.6, 0.6, 0.62))
			_cut("stomp", bird.pos + Vector3(0, 0.6, 0), 1.0, 3.0, 1.1)
			continue
		bt.fuse -= dt
		if bt.fuse > 0.0:
			continue
		(bt.node as Node3D).queue_free()
		butts.remove_at(i)
		var j := _nearest_tree(bt.pos, SPARK_R)
		if j < 0:
			log_event("菸蒂自己熄了")
			continue
		if float(grove[j].get("wet", 0.0)) > 0.0:
			log_event("菸蒂掉在濕地上熄了")
			_pop("滋——", bt.pos + Vector3(0, 1.0, 0), Color(0.7, 0.9, 1.0))
			_puff(bt.pos, Color(0.7, 0.8, 0.9))
			continue
		_ignite_tree(j, "菸蒂點著了樹")

func _nearest_tree(p: Vector3, within: float, skip := -1) -> int:
	var best := -1
	var bd := within
	for i in grove.size():
		if i == skip or not grove[i].alive:
			continue
		var d := flat_dist(p, grove[i].pos)
		if d < bd:
			bd = d
			best = i
	return best

func _ignite_tree(i: int, why: String) -> void:
	var t: Dictionary = grove[i]
	if not t.alive:
		return
	t.alive = false
	t.fire = 0.0
	trees_burnt += 1
	log_event("%s（第 %d 棵燒起來）" % [why, trees_burnt])
	var root := Node3D.new()
	root.position = t.pos
	fx_root.add_child(root)
	var h := _tree_height(t)
	var outer := _cone(0.6, 1.3, Color(1.0, 0.38, 0.06), 1.6)
	outer.position.y = h + 1.0
	outer.name = "Outer"
	root.add_child(outer)
	var inner := _cone(0.32, 0.9, Color(1.0, 0.82, 0.25), 2.4)
	inner.position.y = h + 1.35
	inner.name = "Inner"
	root.add_child(inner)
	# 樹冠四角冒出來的小火舌、樹幹底下一小團
	var tongues := Node3D.new()
	tongues.name = "Tongues"
	root.add_child(tongues)
	for k in 4:
		var a := PI * 0.25 + PI * 0.5 * k
		var tg := _cone(0.32, 0.9, Color(1.0, 0.5, 0.1), 2.0)
		tg.position = Vector3(cos(a) * 0.72, h + 0.75, sin(a) * 0.72)
		tongues.add_child(tg)
	var base := _cone(0.3, 0.7, Color(1.0, 0.55, 0.12), 2.0)
	base.position = Vector3(0.12, 0.35, 0.1)
	tongues.add_child(base)
	var light := OmniLight3D.new()
	light.name = "Glow"
	light.light_color = Color(1.0, 0.55, 0.2)
	light.light_energy = 1.6
	light.omni_range = 5.5
	light.position.y = h + 0.8
	root.add_child(light)
	var emb := CPUParticles3D.new()
	emb.name = "Embers"
	emb.amount = 22
	emb.lifetime = 1.6
	emb.direction = Vector3.UP
	emb.spread = 25.0
	emb.initial_velocity_min = 1.2
	emb.initial_velocity_max = 2.4
	emb.gravity = Vector3(0, 0.6, 0)
	emb.scale_amount_min = 0.12
	emb.scale_amount_max = 0.22
	var em := SphereMesh.new()
	em.radius = 0.5
	em.height = 1.0
	em.radial_segments = 6
	em.rings = 3
	emb.mesh = em
	var emat := StandardMaterial3D.new()
	emat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	emat.albedo_color = Color(1.0, 0.6, 0.2)
	emat.emission_enabled = true
	emat.emission = Color(1.0, 0.5, 0.1)
	emb.material_override = emat
	emb.position.y = h + 1.2
	emb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(emb)
	var fl := CPUParticles3D.new()
	fl.name = "Flames"
	fl.amount = 40
	fl.lifetime = 0.9
	fl.direction = Vector3.UP
	fl.spread = 40.0
	fl.initial_velocity_min = 1.6
	fl.initial_velocity_max = 2.8
	fl.gravity = Vector3.ZERO
	fl.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	fl.emission_sphere_radius = 0.7
	fl.scale_amount_min = 0.5
	fl.scale_amount_max = 1.0
	var fc := Gradient.new()
	fc.colors = PackedColorArray([Color(1.0, 0.95, 0.4, 0.95), Color(1.0, 0.45, 0.08, 0.8), Color(0.4, 0.1, 0.05, 0.0)])
	fc.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	fl.color_ramp = fc
	fl.mesh = em
	var fmat := StandardMaterial3D.new()
	fmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fmat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	fmat.vertex_color_use_as_albedo = true
	fmat.albedo_color = Color(1, 0.85, 0.7, 0.8)
	fl.material_override = fmat
	fl.position.y = h + 0.5
	fl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(fl)
	var smoke := CPUParticles3D.new()
	smoke.name = "Smoke"
	smoke.amount = 10
	smoke.lifetime = 2.4
	smoke.direction = Vector3.UP
	smoke.spread = 12.0
	smoke.initial_velocity_min = 1.0
	smoke.initial_velocity_max = 1.6
	smoke.gravity = Vector3(0.3, 0.2, 0)
	smoke.scale_amount_min = 0.5
	smoke.scale_amount_max = 0.9
	smoke.mesh = em
	var smat := StandardMaterial3D.new()
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smat.albedo_color = Color(0.25, 0.24, 0.24, 0.5)
	smoke.material_override = smat
	smoke.position.y = h + 2.0
	smoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(smoke)
	t.flame = root
	sfx("ignite", t.pos + Vector3(0, 2.0, 0))
	_attach_crackle(root)
	# 樹冠燒焦：先記住原本的顏色，重試時換回來
	var crown := (t.node as Node3D).get_node_or_null("Crown") as Node3D
	if crown:
		var keep: Array = []
		var scorch := _tint(Color(0.24, 0.16, 0.12))
		for c in crown.find_children("*", "MeshInstance3D", true, false):
			keep.append([c, (c as MeshInstance3D).material_override])
			(c as MeshInstance3D).material_override = scorch
		t.leaf_mats = keep
	_pop("著火了！", t.pos + Vector3(0, h + 2.6, 0), Color(1.0, 0.6, 0.25))
	_cut("spark", t.pos + Vector3(0, h + 0.5, 0), 1.7, 7.4, 0.2)
	if not warn_fire:
		warn_fire = true
		toast("起火了！火會往旁邊的樹延燒", 1.6)
		sfx("warn")

func _cone(radius: float, height: float, c: Color, glow: float) -> MeshInstance3D:
	var cone := CylinderMesh.new()
	cone.top_radius = 0.03
	cone.bottom_radius = radius
	cone.height = height
	cone.radial_segments = 10
	var mi := MeshInstance3D.new()
	mi.mesh = cone
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(c, 0.3)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = glow
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

func _tree_height(t: Dictionary) -> float:
	var n := t.node as Node3D
	if n.has_meta("h"):
		return float(n.get_meta("h"))
	if n.get_child_count() > 0:
		var trunk := n.get_child(0) as MeshInstance3D
		if trunk and trunk.mesh is BoxMesh:
			return (trunk.mesh as BoxMesh).size.y
	return 2.6

func _tick_fire(dt: float) -> void:
	for i in grove.size():
		var t: Dictionary = grove[i]
		if t.fire < 0.0 or t.burnt:
			continue
		t.fire += dt
		if not t.spread and t.fire >= SPREAD_AFTER:
			t.spread = true
			if _fire_rng.randf() < SPREAD_CHANCE:
				var j := _spread_target(i)
				if j >= 0:
					_ignite_tree(j, "火延燒到旁邊的樹")
		if t.fire >= BURN_TIME:
			_burn_out(t)

## 往旁邊延燒：找最近、還站著、中間沒有倒下樹幹隔著的樹
func _spread_target(i: int) -> int:
	var from: Vector3 = grove[i].pos
	var best := -1
	var bd := SPREAD_R
	for j in grove.size():
		if j == i or not grove[j].alive or float(grove[j].get("wet", 0.0)) > 0.0:
			continue
		var d := flat_dist(from, grove[j].pos)
		if d >= bd or _log_between(from, grove[j].pos):
			continue
		bd = d
		best = j
	return best

func _log_between(a: Vector3, b: Vector3) -> bool:
	var a2 := Vector2(a.x, a.z)
	var b2 := Vector2(b.x, b.z)
	for s in _log_spots:
		var c: Vector2 = s[0]
		if Geometry2D.get_closest_point_to_segment(c, a2, b2).distance_to(c) < float(s[1]) + 0.15:
			return true
	return false

func _burn_out(t: Dictionary) -> void:
	t.burnt = true
	if t.flame != null and is_instance_valid(t.flame):
		(t.flame as Node3D).queue_free()
	t.flame = null
	var n := t.node as Node3D
	var h := _tree_height(t)
	if n.get_child_count() > 0:
		(n.get_child(0) as Node3D).visible = false
	var crown := n.get_node_or_null("Crown") as Node3D
	if crown:
		crown.visible = false
	var stump := Node3D.new()
	stump.position = t.pos
	fx_root.add_child(stump)
	_peg(stump, Vector3(0.32, h * 0.5, 0.32), Vector3(0, h * 0.25, 0), _tint(Color(0.13, 0.1, 0.08)))
	_peg(stump, Vector3(0.12, 0.5, 0.12), Vector3(0.12, h * 0.5 + 0.2, 0.02), _tint(Color(0.1, 0.08, 0.07)), Vector3(0, 0, -0.5))
	_puff(t.pos + Vector3(0, h * 0.6, 0), Color(0.32, 0.3, 0.3))
	log_event("一棵樹燒成焦炭")

func _burning() -> int:
	var n := 0
	for t in grove:
		if t.fire >= 0.0 and not t.burnt:
			n += 1
	return n

func trees_lost() -> int:
	return trees_cut + trees_burnt

## 一團會變大、往上飄的灰（倒樹、踩熄、燒完）
func _puff(p: Vector3, c: Color) -> void:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.35
	sm.height = 0.5
	mi.mesh = sm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(c, 0.55)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = p + Vector3(0, 0.25, 0)
	spawn_timed(mi, 0.7, "dust")

## 一次性的粒子噴發（木屑、水珠、星星、塵土、落葉）。kind: wood / water / star / dust / leaf
func _burst(p: Vector3, kind: String, n := 14) -> void:
	var cfg: Array = {
		"wood": [Color(0.78, 0.55, 0.3), 3.4, 0.3, 1.0, 1.0],
		"water": [Color(0.6, 0.85, 1.0), 4.6, 0.28, 1.1, 1.6],
		"star": [Color(1.0, 0.92, 0.3), 3.6, 0.38, 1.4, 0.2],
		"dust": [Color(0.7, 0.62, 0.48), 2.2, 0.3, 1.0, 0.2],
		"leaf": [Color(0.55, 0.78, 0.28), 2.8, 0.3, 1.5, 0.8],
	}[kind]
	var pt := CPUParticles3D.new()
	pt.emitting = true
	pt.one_shot = true
	pt.explosiveness = 0.95
	pt.amount = n * 2
	pt.lifetime = float(cfg[3])
	pt.direction = Vector3.UP
	pt.spread = 70.0
	pt.initial_velocity_min = float(cfg[1]) * 0.5
	pt.initial_velocity_max = float(cfg[1])
	pt.gravity = Vector3(0, -7.0 * float(cfg[4]) - 1.0, 0)
	pt.scale_amount_min = float(cfg[2]) * 0.7
	pt.scale_amount_max = float(cfg[2]) * 1.4
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	sm.radial_segments = 6
	sm.rings = 3
	pt.mesh = sm
	var m := StandardMaterial3D.new()
	m.albedo_color = cfg[0]
	if kind == "star" or kind == "water":
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.emission_enabled = true
		m.emission = cfg[0]
	pt.material_override = m
	pt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pt.position = p
	spawn_timed(pt, float(cfg[3]) + 0.3, "burst")

## 飄起來的字
func _pop(text: String, p: Vector3, c: Color) -> void:
	var l := Label3D.new()
	l.text = text
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.fixed_size = true
	l.font_size = 64
	l.pixel_size = 0.0005
	l.outline_size = 18
	l.outline_modulate = Color(0.12, 0.08, 0.04)
	l.modulate = c
	l.position = p
	spawn_timed(l, 1.3)
	_pops.append({"node": l, "y": p.y, "ms": Time.get_ticks_msec()})

func _animate_pops() -> void:
	var now := Time.get_ticks_msec()
	for i in range(_pops.size() - 1, -1, -1):
		var e: Dictionary = _pops[i]
		if not is_instance_valid(e.node):
			_pops.remove_at(i)
			continue
		var k := clampf(float(now - int(e.ms)) / 1250.0, 0.0, 1.0)
		var l := e.node as Label3D
		l.position.y = float(e.y) + 0.9 * (1.0 - pow(1.0 - k, 3.0))
		l.modulate.a = 1.0 - clampf((k - 0.6) / 0.4, 0.0, 1.0)

# ---------------------------------------------------------------- 時鐘

func _level_step(dt: float) -> void:
	_sound_step()
	_tick_cut(dt)
	_mark_saved()
	if want_hood and not hood_saved and enemies_left() == 0 and _wolf_guarding() and not _seen.has("wait_tip") and baskets.is_empty():
		_seen["wait_tip"] = true
		toast("外面的人都倒了！把假獵物放在木屋門口，引開狼外婆", 2.6)
	if want_hood and not hood_saved and not _wolf_sniffing():
		dinner += dt
	for d in decoys:
		if d.life > 0.0:
			d.life -= dt
			if d.life <= 0.0:
				(d.node as Node3D).visible = false
	for b in baskets:
		if b.life > 0.0:
			if not b.get("on", true) and flat_dist(bird.pos, escape_point) < LURE_START_R:
				b["on"] = true
				toast("狼外婆去聞假獵物了！趕快進屋（%d 秒）" % int(BASKET_LIFE), 1.8)
			if b.get("on", true) and bird.state != "fly" and flat_dist(bird.pos, escape_point) < LURE_START_R + 3.0:
				b.life -= dt
			if b.life <= 0.0:
				(b.node as Node3D).visible = false
	if world.has_method("set_look"):
		world.call("set_look", _look_k())
	_tick_butts(dt)
	_tick_fire(dt)
	_tick_wet(dt)
	_advance_falls(dt)
	_move_hood(dt)
	_warnings()
	_sync_goals()

func _level_step_ended(dt: float) -> void:
	_tick_cut(dt)
	_tick_fire(dt)
	_advance_falls(dt)
	_move_hood(dt)

func _wolf_sniffing() -> bool:
	for f in enemies:
		if f.kind == "wolf" and f.alive() and f.state == "sniff":
			return true
	return false

func _mark_saved() -> void:
	if hood_saved or not want_hood:
		return
	if not _bird_inside() or _wolf_guarding():
		return
	hood_saved = true
	log_event("小紅帽得救了")
	sfx("rescue")
	_burst(hood_home + Vector3(0, 1.2, 0), "star", 24)
	toast("小紅帽得救了！", 1.4)
	# 特寫：從門外往屋裡拍，小紅帽走出來
	var mid := hood_home.lerp(escape_point, 0.6)
	mid.y = hood_home.y + 0.9
	_cut("hood", mid, 2.6, 5.4, 3.0, true, Vector3(0, 0, 1), true)

func _bird_in_house() -> bool:
	return world.has_method("in_house") and bool(world.call("in_house", bird.pos.x, bird.pos.z))

func _warnings() -> void:
	var lost := trees_lost()
	if want_trees and not warn_trees and lost >= tree_cap - 3 and lost > 0 and lost <= tree_cap:
		warn_trees = true
		toast("樹快沒了！", 1.1)
		sfx("warn")
	if want_hood and not warn_hood and not hood_saved and dinner > hood_cap - 25.0:
		warn_hood = true
		toast("小紅帽快撐不住了！", 1.2)
		sfx("warn")

## 倒樹：倒完那一刻，橫躺的樹幹變成一串擋路的圓（也擋火）
func _advance_falls(dt: float) -> void:
	for t in grove:
		if t.fall > 0.0 and t.fall < 1.0:
			t.fall = minf(t.fall + dt / 0.75, 1.0)
			if t.fall >= 1.0:
				_lay_log(t)

func _lay_log(t: Dictionary) -> void:
	var dir: Vector3 = t.dir
	var h := _tree_height(t)
	var n := 3 if h < 2.7 else 4
	for k in n:
		var at: Vector3 = t.pos + dir * (0.75 + 0.62 * k)
		var spot := [Vector2(at.x, at.z), 0.3]
		world.obstacles.append(spot)
		_log_spots.append(spot)
	_puff(t.pos + dir * (h * 0.85), Color(0.55, 0.45, 0.3))
	_burst(t.pos + dir * (h * 0.8) + Vector3(0, 0.3, 0), "leaf", 18)
	_burst(t.pos + dir * (h * 0.5) + Vector3(0, 0.2, 0), "dust", 10)
	_puff(t.pos + dir * (h * 0.45), Color(0.55, 0.45, 0.3))

func _move_hood(dt: float) -> void:
	if not hood_saved or hood == null or hood_run >= 1.0:
		return
	hood_run = minf(hood_run + dt / 2.4, 1.0)
	var goal := escape_point
	goal.y = hood_home.y
	hood.position = hood_home.lerp(goal, hood_run)
	hood.rotation.y = 0.0

func _check_end() -> String:
	_mark_saved()
	# 家豪是在這一步之後才走進門的，星星要在判定輸贏前補記，不然過關字出現了、左邊那顆還是空的。
	_sync_goals()
	# 砍倒的加燒掉的樹一超過就輸，家豪血還滿也一樣。
	if want_trees and trees_lost() > tree_cap:
		if trees_burnt > trees_cut:
			fail = "fire"
			_ignite()
		else:
			fail = "trees"
		return "lose"
	if want_hood and not hood_saved and dinner > hood_cap:
		fail = "hood"
		if hood:
			hood.visible = false
		log_event("小紅帽被吃掉了")
		return "lose"
	if not bird.alive():
		fail = "bird"
		return "lose"
	if want_hood and hood_saved:
		return "win"
	if not want_hood and enemies_left() == 0:
		return "win"
	return ""

func _ignite() -> void:
	if ignited:
		return
	ignited = true
	toast("森林燒起來了！", 1.5)
	log_event("森林燒起來了")
	var n := 0
	for t in grove:
		if t.alive and n % 2 == 0:
			_flame(t.pos)
		n += 1
	for f in enemies:
		if f.kind == "smoker":
			_flame(f.pos)
	# 輸了也拍一下火海（之後晚餐畫面會接手鏡頭）
	var hot := Vector3.ZERO
	var k := 0
	for t in grove:
		if t.fire >= 0.0:
			hot += t.pos
			k += 1
	if k > 0:
		_cut("blaze", hot / float(k) + Vector3(0, 1.6, 0), 1.6, 9.0, 3.0, true, Vector3.ZERO, true)

func _flame(p: Vector3) -> void:
	var root := Node3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.04
	cone.bottom_radius = 0.42
	cone.height = 1.25
	var mi := MeshInstance3D.new()
	mi.mesh = cone
	mi.position.y = 0.62
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.42, 0.08)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.32, 0.04)
	m.emission_energy_multiplier = 1.8
	mi.material_override = m
	root.add_child(mi)
	root.position = ground(p) + Vector3(0, 0.15, 0)
	spawn_timed(root, 6.0)

# ---------------------------------------------------------------- 敵人

func _tick_enemy(f: Fighter, dt: float) -> void:
	if f.kind == "wolf":
		_tick_wolf(f, dt)
	elif f.kind == "chopper" or f.kind == "smoker":
		_tick_worker(f, dt)
	else:
		super(f, dt)

func _tick_wolf(f: Fighter, dt: float) -> void:
	# 狼外婆守在床邊看著小紅帽。家豪進屋的話，衝過去把她拍出門外。
	# 只有外婆的籃子引得開她：她走去聞籃子的時候，家豪進屋才救得到小紅帽。
	if not f.alive():
		return
	f.aggro = false
	f.data["swat_cd"] = maxf(float(f.data.get("swat_cd", 0.0)) - dt, 0.0)
	var bi := _basket_active() if not hood_saved else -1
	if bi >= 0:
		# 外婆的籃子：走過去聞，聞的時候小紅帽的計時停下來
		var spot: Vector3 = ground(world.clamp_house(baskets[bi].pos))
		if flat_dist(f.pos, spot) > 0.4:
			if f.state != "basket":
				f.set_state("basket")
				log_event("狼外婆被假獵物引開")
			_walk(f, spot, f.speed, dt)
			anim(f, "Walk", 0.8)
			f.pos = ground(world.clamp_house(f.pos))
			return
		if f.state != "sniff":
			f.set_state("sniff")
			anim(f, "Idle")
			_pop("嗅嗅…", f.pos + Vector3(0, 2.9, 0), Color(1.0, 0.9, 0.7))
			sfx("sniff", f.pos)
			_cut("basket", f.pos + Vector3(0, 1.4, 0), 1.6, 6.4, 0.9, true, Vector3(0, 0, 1))
		_face(f, baskets[bi].pos)
		return
	if not hood_saved and _bird_inside():
		_guard_rush(f, dt)
		return
	var home: Vector3 = f.route[0]
	if flat_dist(f.pos, home) > 0.35:
		if f.state != "home":
			f.set_state("home")
		_walk(f, home, f.speed * 0.6, dt)
		anim(f, "Walk", 0.5)
		f.pos = ground(world.clamp_house(f.pos))
		return
	if f.state != "eat":
		f.set_state("eat")
		anim(f, "Idle")
	if hood and not hood_saved:
		_face(f, hood.position)
	else:
		_face(f, escape_point)

## 家豪在屋裡（站在地上、還活著）
func _bird_inside() -> bool:
	return bird.alive() and bird.state != "fly" and _bird_in_house()

## 狼外婆在看著小紅帽（沒有被籃子引開）
func _wolf_guarding() -> bool:
	for f in enemies:
		if f.kind == "wolf" and f.alive() and not (f.state in ["basket", "sniff"]):
			return true
	return false

## 狼外婆衝向家豪，夠近就一掌把她拍出門外
const SWAT_DAMAGE := 1.0
const SWAT_REACH := 1.5
func _guard_rush(f: Fighter, dt: float) -> void:
	if f.state != "guard":
		f.set_state("guard")
		log_event("狼外婆發現家豪闖進來")
		_pop("滾出去！", f.pos + Vector3(0, 2.9, 0), Color(1.0, 0.55, 0.45))
	var to := ground(world.clamp_house(bird.pos))
	if flat_dist(f.pos, bird.pos) > SWAT_REACH:
		_walk(f, to, f.speed * 2.6, dt)
		anim(f, "Walk", 1.4)
		f.pos = ground(world.clamp_house(f.pos))
		return
	_face(f, bird.pos)
	if f.data.swat_cd > 0.0:
		return
	f.data["swat_cd"] = 1.2
	anim(f, "Kick_Right", 1.2)
	_swat_out(f)

func _swat_out(f: Fighter) -> void:
	sfx("swat", f.pos)
	var b := bird
	swats += 1
	last_hurt_by = "wolf"
	b.hp = maxf(b.hp - SWAT_DAMAGE, 0.0)
	hit_spots.append(b.pos)
	log_event("狼外婆把家豪拍出門外（剩 %d）" % ceili(b.hp))
	_pop("啪！", b.pos + Vector3(0, 1.6, 0), Color(1.0, 0.5, 0.4))
	if b.hp <= 0.0:
		b.set_state("dead")
		return
	var out := escape_point + Vector3(0, 0, 2.6)
	start_fly(ground(out), FLY_TIME, FLY_PEAK, "land")
	if not _seen.has("swat_tip"):
		_seen["swat_tip"] = true
		toast("狼外婆守著小紅帽！先把假獵物放在門口引開她", 2.2)
	_cut("swat", (f.pos + escape_point) * 0.5 + Vector3(0, 1.2, 0), 1.4, 5.8, 1.6, true, Vector3(0, 0, 1))

func _tick_worker(f: Fighter, dt: float) -> void:
	# 菸被打斷（去看假獵物、挨打、倒下）：手上那根掉在地上
	if f.kind == "smoker" and f.data.get("lit", false) and f.state != "smoke":
		f.data["lit"] = false
		if want_smoke:
			drop_butt(f, "drop")
	if not f.alive():
		return
	if f.state in LOCK:
		_tick_melee(f, dt)
		return
	if _bird_close(f):
		_fight(f, dt)
		return
	var lure := _nearest_decoy(f.pos)
	if lure >= 0:
		_tick_lure(f, dt, lure)
		return
	if f.aggro and bird.alive() and flat_dist(f.pos, bird.pos) < f.vision_range + 1.2:
		_fight(f, dt)
		return
	f.aggro = false
	if sees_bird(f):
		_fight(f, dt)
		return
	if f.kind == "chopper":
		_tick_chop(f, dt)
	else:
		_tick_smoke(f, dt)

## 家豪貼到身邊（0.95 公尺內）才一定會發現；再遠一點要「看得到」（在視線扇形裡、中間沒有樹）才會發現。
## 所以從背後、或從樹後面摸過去，家豪走到打得到的距離（1.05）時還不會被發現，這一下就是偷襲。
func _bird_close(f: Fighter) -> bool:
	if not bird.alive() or bird.state == "fly":
		return false
	var d := flat_dist(f.pos, bird.pos)
	return d < 0.95 or (d < 2.35 and sees_bird(f))

func _fight(f: Fighter, _dt: float) -> void:
	f.aggro = true
	if f.state in ["idle", "patrol", "look", "smoke", "chop", "lure", "goto", "eat"]:
		f.set_state("alert")
	_tick_melee(f, _dt)

func _tick_lure(f: Fighter, _dt: float, idx: int) -> void:
	var d: Dictionary = decoys[idx]
	if f.state != "lure" and f.state != "goto":
		log_event("%s去看假獵物" % f.name)
	if flat_dist(f.pos, d.pos) > 0.85:
		if f.state != "goto":
			f.set_state("goto")
		_walk(f, d.pos, f.speed, _dt)
		anim(f, "Walk", 0.85)
	else:
		if f.state != "lure":
			f.set_state("lure")
			anim(f, "Idle")
		_face(f, d.pos)

func _tick_chop(f: Fighter, _dt: float) -> void:
	var idx := _claim_tree(f)
	if idx < 0:
		if f.state != "idle":
			f.set_state("idle")
			anim(f, "Idle")
		return
	var pos: Vector3 = grove[idx].pos
	if flat_dist(f.pos, pos) > 1.2:
		if f.state != "goto":
			f.set_state("goto")
		_walk(f, pos, f.speed, _dt)
		anim(f, "Walk", 0.8)
		return
	if f.state != "chop":
		f.set_state("chop")
		anim(f, "Kick_Right", 0.65)
	_face(f, pos)
	var swing := int(f.t / 0.9)
	f.t += _dt
	if int(f.t / 0.9) != swing:
		sfx("chop", pos, -2.0)
		_burst(pos + Vector3(0, 0.9, 0), "wood", 6)
	if f.t >= chop_time:
		_fell(idx, f.pos)
		f.data["tree"] = -1
		f.set_state("idle")

func _tick_smoke(f: Fighter, _dt: float) -> void:
	var home: Vector3 = f.route[0]
	if flat_dist(f.pos, home) > 0.5:
		if f.state != "goto":
			f.set_state("goto")
		_walk(f, home, f.speed, _dt)
		anim(f, "Walk", 0.7)
		return
	if f.state != "smoke":
		f.set_state("smoke")
		anim(f, "Idle")
		f.data["lit"] = true
		f.data["puff"] = 0.0
	f.yaw = f.start_yaw
	f.t += _dt
	if want_smoke:
		f.data["puff"] = float(f.data.get("puff", 0.0)) + _dt
		if f.data.puff >= butt_every:
			f.data["puff"] = 0.0
			drop_butt(f, "flick")

func _claim_tree(f: Fighter) -> int:
	var cur := int(f.data.get("tree", -1))
	if cur >= 0 and cur < grove.size() and grove[cur].alive:
		return cur
	var best := -1
	var bd := INF
	for i in grove.size():
		if not grove[i].alive or _tree_taken(i, f):
			continue
		var d := flat_dist(f.pos, grove[i].pos)
		if d < bd:
			bd = d
			best = i
	f.data["tree"] = best
	return best

func _tree_taken(i: int, self_f: Fighter) -> bool:
	for o in enemies:
		if o == self_f or not o.alive() or o.kind != "chopper":
			continue
		if int(o.data.get("tree", -1)) == i:
			return true
	return false

## 樹往伐木工的反方向倒
func _fell(i: int, from: Vector3) -> void:
	var t: Dictionary = grove[i]
	if not t.alive:
		return
	t.alive = false
	t.fall = 0.01
	t.block[1] = 0.0
	var dir: Vector3 = t.pos - from
	dir.y = 0.0
	if dir.length() < 0.05:
		dir = Vector3(sin(float(i) * 2.3), 0.0, cos(float(i) * 2.3))
	t.dir = dir.normalized()
	trees_cut += 1
	log_event("砍倒第 %d 棵樹" % trees_cut)
	sfx("fall", t.pos)
	_pop("砍倒了！", t.pos + Vector3(0, 2.6, 0), Color(1.0, 0.85, 0.5))
	# 第一棵倒下來，或砍到快輸的時候：從側面拍樹倒下去
	var key := "fell" if not _seen.has("fell") else ("fell_warn" if want_trees and trees_lost() >= tree_cap - 2 else "")
	if key != "":
		var side: Vector3 = (t.dir as Vector3).cross(Vector3.UP)
		if camera and side.dot(camera.global_position - t.pos) < 0.0:
			side = -side
		_cut(key, t.pos + t.dir * 1.1 + Vector3(0, 1.1, 0), 1.7, 5.4, 1.0, true, side)

func _nearest_decoy(p: Vector3) -> int:
	var best := -1
	var bd := ATTRACT
	for i in decoys.size():
		if decoys[i].life <= 0.0:
			continue
		var d := flat_dist(p, decoys[i].pos)
		if d < bd:
			bd = d
			best = i
	return best

# ---------------------------------------------------------------- 家豪

var _stuck_t := 0.0
var _stuck_pos := Vector3.ZERO

## 家豪走路被倒下的樹幹、樹、石頭卡住超過 1 秒：拍翅小跳過去（朝她要去的方向 2.5 公尺）
func _unstick(dt: float) -> void:
	var b := bird
	if not (b.state in ["charge", "return"]):
		_stuck_t = 0.0
		return
	if flat_dist(b.pos, _stuck_pos) < 0.12:
		_stuck_t += dt
	else:
		_stuck_t = 0.0
		_stuck_pos = b.pos
	if _stuck_t < 1.0:
		return
	_stuck_t = 0.0
	var goal := escape_point
	var g = _next_guide()
	if g != null:
		goal = g.pos
	elif b.target != null:
		goal = (b.target as Fighter).pos
	elif hood != null:
		goal = hood.position
	var dir := goal - b.pos
	dir.y = 0.0
	if dir.length() < 0.5:
		return
	dir = dir.normalized()
	var dest := b.pos + dir * minf(2.8, flat_dist(goal, b.pos))
	if hits_obstacle(Vector2(dest.x, dest.z)):
		dest = b.pos + dir.rotated(Vector3.UP, 0.7) * 2.8
	start_fly(ground(world.clamp_play(dest)), HOP_TIME + 0.3, 1.5, "land")
	log_event("家豪被擋住，拍翅飛過去")

func _tick_bird(dt: float) -> void:
	var b := bird
	if not b.alive():
		return
	_unstick(dt)
	b.t += dt
	if b.state != "fly":
		_apply_knockback(b, dt)
	var close := _sticky_enemy()
	var nxt := nearest_enemy(b.pos)
	b.target = close if close != null else nxt
	if b.target == null and _next_guide() == null and not _hood_last():
		return
	if b.state in ["charge", "return", "feed", "linger"]:
		var fi := _nearest_feed(b.pos, FEED_SENSE)
		if fi >= 0:
			if b.state != "feed":
				log_event("家豪看到飼料，跑去吃")
			b.feed_target = fi
			b.state = "feed"
	match b.state:
		"charge", "return":
			_bird_toward(dt)
		"feed":
			if b.feed_target < 0 or b.feed_target >= feeds.size():
				b.set_state("charge")
			else:
				var fp: Vector3 = feeds[b.feed_target].pos
				_bird_walk(fp, b.speed * 0.85, dt, "feed")
				if flat_dist(b.pos, fp) < 0.35:
					b.set_state("eat")
		"eat":
			if b.t >= FEED_EAT_TIME:
				var food := _nearest_feed(b.pos, 0.8)
				if food >= 0:
					(feeds[food].node as Node3D).queue_free()
					feeds.remove_at(food)
					b.hp = minf(b.hp + FEED_HEAL, b.max_hp)
					log_event("家豪吃掉一把飼料（回到 %d）" % ceili(b.hp))
				b.set_state("linger")
		"linger":
			if b.t >= FEED_LINGER:
				b.set_state("charge")
		"slip":
			if b.t >= SLIP_TIME:
				b.set_state("charge")
		"windup":
			var foe: Fighter = b.target
			if foe == null or not foe.alive():
				b.set_state("charge")
			else:
				_face(b, foe.pos)
				if b.t >= b.windup:
					if flat_dist(b.pos, foe.pos) <= b.reach + 0.35 and foe.alive():
						if not foe.aggro and not foe.immune_peck:
							_sneak(foe)
						else:
							_hit_enemy(foe, PECK_DAMAGE, b.pos)
					b.set_state("recover")
		"recover":
			if b.t >= b.recover:
				var foe2: Fighter = b.target
				var still := foe2 != null and foe2.alive() and flat_dist(b.pos, foe2.pos) <= b.reach
				b.set_state("windup" if still else "charge")
		"hop":
			if b.t >= 0.4:
				b.set_state("charge")
		"fly":
			var k := clampf(b.t / b.fly_dur, 0.0, 1.0)
			b.pos = ground(b.fly_from.lerp(b.fly_to, k))
			b.air = sin(k * PI) * b.fly_peak
			b.yaw = atan2(b.fly_to.x - b.fly_from.x, b.fly_to.z - b.fly_from.z)
			if k >= 1.0:
				b.air = 0.0
				b.set_state("land" if b.after_fly == "land" else b.after_fly)
		"land":
			if b.target != null and b.t > 0.25:
				_face(b, b.target.pos)
			if b.t >= 0.7:
				b.set_state("charge")

func _bird_toward(dt: float) -> void:
	var b := bird
	var foe := _sticky_enemy()
	if foe != null:
		b.target = foe
		var spd := b.speed * (1.35 if foe.state == "down" else 1.0)
		_bird_walk(foe.pos, spd, dt, "charge")
		if flat_dist(b.pos, foe.pos) <= b.reach:
			b.set_state("windup")
		return
	var g = _next_guide()
	if g != null:
		_bird_walk(g.pos, b.speed, dt, "charge")
		if flat_dist(b.pos, g.pos) < 0.7:
			g.used = true
			(g.node as Node3D).visible = false
			log_event("家豪經過引路點")
		return
	var far := nearest_enemy(b.pos)
	if far == null:
		# 外面的人都倒了、也沒有旗子：最後才自己走進木屋
		if _hood_last():
			_bird_walk(hood.position, b.speed, dt, "charge")
		return
	b.target = far
	_bird_walk(far.pos, b.speed, dt, "charge")
	if flat_dist(b.pos, far.pos) <= b.reach:
		b.set_state("windup")

## 外面的人都倒了才會自己去救；狼外婆還守著的話在門外等（不然一直被拍出來），等玩家把她引開
func _hood_last() -> bool:
	return want_hood and not hood_saved and hood != null and enemies_left() == 0 and not _wolf_guarding()

func nearest_enemy(from: Vector3) -> Fighter:
	var best: Fighter = null
	var bd := INF
	for f in enemies:
		if not f.alive() or f.kind == "wolf":
			continue
		var d := flat_dist(from, f.pos)
		if d < bd:
			bd = d
			best = f
	return best

func enemies_left() -> int:
	var n := 0
	for f in enemies:
		if f.alive() and f.kind != "wolf":
			n += 1
	return n

func _sticky_enemy() -> Fighter:
	var cur = bird.target
	if cur != null and (cur as Fighter).kind == "wolf":
		cur = null
	if bird.state in ["windup", "recover"] and cur != null and (cur as Fighter).alive():
		if flat_dist(bird.pos, (cur as Fighter).pos) <= STICKY:
			return cur
	var best: Fighter = null
	var bd := ENGAGE
	for f in enemies:
		if not f.alive() or f.kind == "wolf":
			continue
		var d := flat_dist(bird.pos, f.pos)
		if d < bd:
			bd = d
			best = f
	return best

## 照放下的順序走。倒下的樹幹壓在引路點上就跳過那一個。
func _next_guide():
	for g in guides:
		if g.used:
			continue
		if hits_obstacle(Vector2(g.pos.x, g.pos.z)):
			g.used = true
			(g.node as Node3D).visible = false
			log_event("引路點被倒下的樹壓住了")
			_pop("被壓住了", g.pos + Vector3(0, 1.3, 0), Color(1.0, 0.7, 0.5))
			continue
		return g
	return null

# ---------------------------------------------------------------- 視線

## 站著的樹（包括正在燒的）會擋住視線；倒下的樹幹和燒完的樹樁擋不住
func sees_bird(f: Fighter) -> bool:
	if not super(f):
		return false
	var a := Vector2(f.pos.x, f.pos.z)
	var b := Vector2(bird.pos.x, bird.pos.z)
	if a.distance_to(b) < 1.6:
		return true
	for t in grove:
		if t.fall > 0.0 or t.burnt:
			continue
		var c := Vector2(t.pos.x, t.pos.z)
		if c.distance_to(a) < 0.7 or c.distance_to(b) < 0.7:
			continue
		if Geometry2D.get_closest_point_to_segment(c, a, b).distance_to(c) < LOS_R:
			return false
	return true

## 偷襲：拍家豪和被嚇到的人
func _sneak(f: Fighter) -> void:
	super(f)
	sneaks += 1
	_burst(f.pos + Vector3(0, 1.4, 0), "star", 12)
	sfx("bonk", f.pos)
	var mid := (bird.pos + f.pos) * 0.5 + Vector3(0, 1.0, 0)
	var side := (f.pos - bird.pos).cross(Vector3.UP)
	if side.length() < 0.05:
		side = Vector3.RIGHT
	if camera and side.dot(camera.global_position - f.pos) < 0.0:
		side = -side
	_cut("sneak", mid, 1.2, 3.8, 0.7, false, side.normalized())

# ---------------------------------------------------------------- 畫面

# ---------------------------------------------------------------- 特寫
## 跟冰雪島一樣：重要的事發生時切到旁邊的近拍鏡頭、放慢一下，幾秒後切回來。
## once＝這一局只拍第一次；force＝不管間隔一定拍（過關、輸掉）。
## side＝希望鏡頭擺在哪個方向（預設是玩家鏡頭那一側）。回傳有沒有切過去。

func _cut(kind: String, target: Vector3, sec: float, dist: float, height: float,
		once := true, side := Vector3.ZERO, force := false) -> bool:
	if _cut_cam == null or not is_inside_tree() or (_automated_run() and not cuts_in_tests) or defeat_shown:
		return false
	if phase != Phase.RUNNING:
		return false
	if once and _seen.has(kind):
		return false
	if not force and (_cut_t > 0.0 or time < _cut_gap):
		return false
	var at = _pick_shot(target, dist, height, side)
	if at == null:
		return false
	_seen[kind] = true
	_cut_cam.fov = 50.0
	_cut_cam.global_position = at
	_cut_cam.look_at(target, Vector3.UP)
	_cut_cam.make_current()
	_cut_t = sec
	_cut_gap = time + sec + CUT_GAP
	_slow_until = Time.get_ticks_msec() + SLOWMO_MS
	if _range:
		_range.visible = false
	return true

## 繞著目標找一個沒被樹、牆擋住的機位；都擋住就回傳 null（不拍）
func _pick_shot(target: Vector3, dist: float, height: float, side: Vector3):
	var base := side
	base.y = 0.0
	if base.length() < 0.05 and camera:
		base = camera.global_position - target
		base.y = 0.0
	base = base.normalized() if base.length() > 0.05 else Vector3.BACK
	for lift in [0.0, 1.6]:
		for a in [0.0, 0.5, -0.5, 1.0, -1.0, 1.6, -1.6, 2.3, -2.3, PI]:
			var d: Vector3 = base.rotated(Vector3.UP, float(a))
			var c: Vector3 = target + d * dist
			c.y = ground(c).y + maxf(target.y - ground(target).y, 0.0) + height + float(lift)
			if _shot_clear(c, target):
				return c
	return null

func _shot_clear(c: Vector3, target: Vector3) -> bool:
	var lo = world.get("play_min")
	var hi = world.get("play_max")
	if lo is Vector2 and hi is Vector2:
		if c.x < lo.x - 1.0 or c.x > hi.x + 1.0 or c.z < lo.y - 1.0 or c.z > hi.y + 1.0:
			return false
	if world.has_method("in_house") and world.in_house(c.x, c.z):
		return false
	if wall_crossing(c, target) != null:
		return false
	var a := Vector2(c.x, c.z)
	var b := Vector2(target.x, target.z)
	for t in grove:
		if t.fall > 0.0 or t.burnt:
			continue
		var p := Vector2(t.pos.x, t.pos.z)
		if p.distance_to(b) < 1.3:
			continue        # 主角那棵樹本身
		if p.distance_to(a) < 1.3:
			return false    # 鏡頭塞在樹冠裡
		if Geometry2D.get_closest_point_to_segment(p, a, b).distance_to(p) < 0.95:
			return false
	return true

func _tick_cut(dt: float) -> void:
	if _cut_t <= 0.0:
		return
	_cut_t -= dt
	if _cut_t <= 0.0:
		_cut_off()

func _cut_off() -> void:
	_cut_t = 0.0
	if _cut_cam and _cut_cam.current and camera:
		camera.make_current()
	if not _held_toast.is_empty():
		var h := _held_toast
		_held_toast = []
		if phase == Phase.RUNNING:
			super.toast(String(h[0]), float(h[1]))

## 提示框在畫面正中間，特寫時會蓋住主角：先收著，切回來再顯示
func toast(text: String, dur: float) -> void:
	if _cutting() and text != "" and dur > 0.0:
		_held_toast = [text, dur]
		return
	super(text, dur)
	if _toast_label:
		_toast_label.reset_size()      # 前一則是長句時，字卡不要一直撐著那麼高
		_toast_label.call_deferred("reset_size")

func _cutting() -> bool:
	return _cut_cam != null and _cut_cam.current

func _process(dt: float) -> void:
	super(dt)
	_poll_audio()
	_tick_music(dt)
	var want := 1.0
	if Time.get_ticks_msec() < _slow_until and phase != Phase.PREPARE:
		want = SLOWMO
	if Engine.time_scale != want:
		Engine.time_scale = want

func _exit_tree() -> void:
	Engine.time_scale = 1.0
	if _audio_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_audio_task)   # 背景合成還沒做完：等它結束再離開
		_audio_task = -1

func _view_blocked() -> bool:
	return super() or _cutting()

func _update_bars(dt: float) -> void:
	super(dt)
	for f in enemies:
		if f.kind == "wolf" and f.bar:
			f.bar.visible = false

func _level_visuals() -> void:
	_show_range()
	_number_guides()
	_animate_pops()
	for row in _enemy_rows:
		var who: Fighter = row.fighter
		if who.kind != "wolf":
			continue
		var face: Node = row.face
		if face.get_parent():
			face.get_parent().visible = false
	for f in enemies:
		if f.kind != "wolf":
			continue
		var lb := f.node.get_node_or_null("WolfState") as Label3D
		if lb == null:
			lb = Label3D.new()
			lb.name = "WolfState"
			lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			lb.no_depth_test = true
			lb.fixed_size = true
			lb.font_size = 56
			lb.pixel_size = 0.0006
			lb.outline_size = 14
			lb.position = Vector3(0, 4.6, 0)
			f.node.add_child(lb)
		if not f.alive():
			lb.visible = false
		elif f.state in ["basket", "sniff"]:
			lb.text = "嗅嗅…（現在進屋！）"
			lb.modulate = Color(0.7, 1.0, 0.7)
		else:
			lb.text = "守著小紅帽"
			lb.modulate = Color(1.0, 0.6, 0.5)
	var now := float(Time.get_ticks_msec()) * 0.001
	for i in grove.size():
		var t: Dictionary = grove[i]
		if t.fall > 0.0:
			# 往外倒、越倒越快，最後橫躺在地上
			var n := t.node as Node3D
			var dir: Vector3 = t.dir
			var axis := Vector3.UP.cross(dir)
			if axis.length() > 0.01:
				n.basis = Basis(axis.normalized(), (PI * 0.5 - 0.05) * t.fall * t.fall)
			var crown := n.get_node_or_null("Crown") as Node3D
			if crown:
				crown.scale = Vector3.ONE * (1.0 - 0.35 * t.fall)
		elif t.fire >= 0.0 and not t.burnt:
			var crown2 := (t.node as Node3D).get_node_or_null("Crown") as Node3D
			if crown2:
				crown2.scale = Vector3.ONE * (1.0 - 0.55 * clampf(t.fire / BURN_TIME, 0.0, 1.0))
			var fl = t.flame
			if fl != null and is_instance_valid(fl):
				var k := clampf(t.fire / 1.2, 0.2, 1.0) * (1.0 - 0.5 * clampf((t.fire - BURN_TIME + 2.5) / 2.5, 0.0, 1.0))
				var o := (fl as Node3D).get_node("Outer") as Node3D
				var inn := (fl as Node3D).get_node("Inner") as Node3D
				o.scale = Vector3(k, k * (0.85 + 0.22 * sin(now * 13.0 + i)), k)
				inn.scale = Vector3(k, k * (0.8 + 0.3 * sin(now * 17.0 + i * 2.0)), k)
				((fl as Node3D).get_node("Glow") as OmniLight3D).light_energy = 1.6 + 0.8 * sin(now * 9.0 + i) * k
	for bt in butts:
		# 越接近點著，紅點閃得越快
		var hurry: float = 1.0 - clampf(bt.fuse / BUTT_FUSE, 0.0, 1.0)
		var m := (bt.tip as MeshInstance3D).material_override as StandardMaterial3D
		m.emission_energy_multiplier = 1.5 + 2.5 * absf(sin(now * (3.0 + 12.0 * hurry)))
		var wisp := (bt.node as Node3D).get_node_or_null("Wisp") as Node3D
		if wisp:
			var w := fmod(now * 0.8 + bt.pos.x, 1.0)
			wisp.position.y = 0.15 + w * 0.6
			wisp.scale = Vector3.ONE * (0.6 + w)
	for f in enemies:
		var puff := f.node.find_child("CigarettePuff", true, false) as Node3D
		if puff == null:
			continue
		puff.visible = f.alive() and f.state == "smoke"
		if puff.visible:
			puff.position.y = 1.75 + 0.2 * sin(f.t * 3.5)
			var s := 0.55 + 0.45 * absf(sin(f.t * 2.4))
			puff.scale = Vector3.ONE * s

func _number_guides() -> void:
	var n := 1
	for g in guides:
		if g.used:
			continue
		(g.label as Label3D).text = str(n)
		n += 1

func _update_phase_label() -> void:
	super()
	if phase == Phase.RUNNING and _phase_label != null:
		_phase_label.text = _meter_line()

# ---------------------------------------------------------------- 左邊的三顆星

## 每一小關三顆星（選關地圖按顆數算）。小關的 battle.gd 覆寫 _objectives()，格式：
##   {"id": 自己取的名字, "text": 畫面上的說明, "end": true 的話只在「過關那一刻」判定（例如「燒掉不超過 2 棵」）}
## 判定在 _goal_met(id)：這裡已經有 hood / smoker / chop / all / lost_le_N / burnt_le_N / hp_ge_N / sneak / sneak2 / time_le_N。
func _objectives() -> Array:
	if not want_hood:
		return []
	return [
		{"id": "hood", "text": "救出小紅帽"},
		{"id": "smoker", "text": "打倒抽菸的人"},
		{"id": "chop", "text": "打倒伐木的人"},
	]

func _goal_met(id: String) -> bool:
	match id:
		"hood":
			return want_hood and hood_saved
		"smoker":
			return _kind_all_down("smoker")
		"chop":
			return _kind_all_down("chopper")
		"all":
			return enemies_left() == 0
		"sneak":
			return sneaks >= 1
		"sneak2":
			return sneaks >= 2
		"hp_ge_10":
			return bird.alive() and bird.hp >= bird.max_hp
	if id.begins_with("hp_ge_"):
		return bird.alive() and bird.hp >= float(id.substr(6))
	if id.begins_with("lost_le_"):
		return trees_lost() <= int(id.substr(8))
	if id.begins_with("burnt_le_"):
		return trees_burnt <= int(id.substr(9))
	if id.begins_with("time_le_"):
		return time <= float(id.substr(8))
	return false

func _stage_key() -> String:
	var root := get_parent()
	return root.scene_file_path if root else "?"

func _best() -> Dictionary:
	var k := _stage_key()
	if not best_stars.has(k):
		best_stars[k] = {}
	return best_stars[k]

func _kind_all_down(kind: String) -> bool:
	var any := false
	for f in enemies:
		if f.kind != kind:
			continue
		any = true
		if f.alive():
			return false
	return any

func _sync_goals() -> void:
	for c in _objectives():
		if not c.get("end", false) and _goal_met(String(c.id)):
			_mark_goal(String(c.id))

## 過關那一刻：把「只在結尾判定」的目標也算進去
func _sync_end_goals() -> void:
	for c in _objectives():
		if c.get("end", false) and _goal_met(String(c.id)):
			_mark_goal(String(c.id))

func _mark_goal(id: String) -> void:
	if _done.has(id):
		return
	if not _objectives().any(func(c): return c.id == id):
		return
	_done[id] = true
	if not _best().has(id):
		_new_stars.append(id)
	var text := ""
	for c in _objectives():
		if c.id == id:
			text = String(c.text)
	toast("★ " + text, 1.4)
	log_event("目標：" + text)
	_refresh_goals()

func _build_goals() -> void:
	if _objectives().is_empty():
		return
	_goal_layer = CanvasLayer.new()
	_goal_layer.layer = 5
	add_child(_goal_layer)
	var box := VBoxContainer.new()
	box.position = Vector2(20, 56)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_goal_layer.add_child(box)
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	UIStyle.paper(panel)
	box.add_child(panel)
	_goal_rows = VBoxContainer.new()
	_goal_rows.add_theme_constant_override("separation", 4)
	_goal_rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(_goal_rows)
	_refresh_goals()

func _refresh_goals() -> void:
	if _goal_rows == null:
		return
	for c in _goal_rows.get_children():
		_goal_rows.remove_child(c)
		c.queue_free()
	var title := Label.new()
	title.text = "目標"
	title.label_settings = UIStyle.ls(20, UIStyle.INK)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_goal_rows.add_child(title)
	var best := _best()
	for c in _objectives():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_goal_rows.add_child(row)
		var now_done: bool = _done.has(c.id)
		var had: bool = best.has(c.id)
		var st := Label.new()
		st.text = "★"
		st.mouse_filter = Control.MOUSE_FILTER_IGNORE
		st.label_settings = UIStyle.ls(24, Color("f6c445") if now_done else (Color("f5e2a8") if had else Color("fff8e7")), 6,
			UIStyle.INK if (now_done or had) else Color(UIStyle.INK, 0.45))
		row.add_child(st)
		var tx := Label.new()
		tx.text = String(c.text)
		tx.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tx.label_settings = UIStyle.ls(24, UIStyle.INK if (now_done or had) else Color(UIStyle.INK, 0.55))
		row.add_child(tx)

## saved：過關結算用累積紀錄（含這一局）。沒過關就只列這一局做到的。
func _star_block(saved: bool) -> String:
	var list := _objectives()
	if list.is_empty():
		return ""
	var have: Dictionary = _best() if saved else _done
	var n := 0
	for c in list:
		if have.has(c.id):
			n += 1
	var lines: PackedStringArray = ["★".repeat(n) + "☆".repeat(list.size() - n) + "（%d/%d）" % [n, list.size()]]
	for c in list:
		var tag := "★ " if have.has(c.id) else "☆ "
		var fresh := "　新！" if saved and _new_stars.has(c.id) else ""
		lines.append(tag + String(c.text) + fresh)
	return "\n".join(lines)

func _end(result: String) -> void:
	sfx("win" if result == "win" else "lose")
	if result == "lose" and not _seen.has("blaze"):
		_cut_off()
	if result == "win":
		_sync_goals()
		_sync_end_goals()
		var best := _best()
		for id in _done:
			best[id] = true
	super(result)
	if _summary_panel and not _objectives().is_empty():
		_summary_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		_summary_panel.offset_right = -28
		_summary_panel.offset_top = 28
		_summary_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		_summary_panel.grow_vertical = Control.GROW_DIRECTION_END

func _meter_line() -> String:
	var bits := PackedStringArray()
	if want_trees:
		var star := ""
		for c in _objectives():
			if String(c.id).begins_with("lost_le_") or String(c.id).begins_with("burnt_le_"):
				if (String(c.id).begins_with("lost_le_") and trees_lost() > int(String(c.id).get_slice("_", 2))) or (String(c.id).begins_with("burnt_le_") and trees_burnt > int(String(c.id).get_slice("_", 2))):
					star = "　★已失去"
					continue
				star = ("　★一棵都不能燒" if String(c.id).get_slice("_", 2) == "0" else "　★要 ≤%s 棵" % String(c.id).get_slice("_", 2))
		bits.append("樹 %d/%d 會輸%s" % [trees_lost() if not String(star).contains("burnt") else trees_lost(), tree_cap, star])
	var fire := _burning()
	if fire > 0:
		bits.append("起火 %d" % fire)
	if not butts.is_empty():
		bits.append("菸蒂 %d 個（會起火）" % butts.size())
	for b in baskets:
		if b.life > 0.0 and b.get("on", true) and not hood_saved:
			bits.append("狼外婆被引開 %d 秒" % ceili(b.life))
	if want_hood:
		if hood_saved:
			bits.append("小紅帽安全")
		else:
			bits.append("小紅帽還撐得住 %.0f 秒" % maxf(hood_cap - dinner, 0.0))
	return "　".join(bits)

func _prepare_hint() -> String:
	return "假獵物引開人、引路點照放的順序走　Enter 開始　T 再看教學"

func _win_line() -> String:
	var lead := "人倒下了，樹還在。"
	if want_hood:
		lead = "救出小紅帽了。"
	elif want_smoke and trees_burnt == 0:
		lead = "菸都踩熄了，森林沒有著火。"
	var stars := _star_block(true)
	if stars == "":
		return lead
	return lead + "\n" + stars

func _lose_line(_left: int) -> String:
	match fail:
		"hood":
			return "小紅帽被狼外婆吃掉了。"
		"fire":
			return "燒掉加砍倒超過 %d 棵，森林燒起來了。" % tree_cap
		"trees":
			return "砍倒加燒掉超過 %d 棵樹了。" % tree_cap
		_:
			return "家豪倒下了…（還剩 %d 個敵人）" % _left

func _defeat_title() -> String:
	match fail:
		"hood":
			return "小紅帽被吃掉了……"
		"fire":
			return "森林燒起來了……"
		"trees":
			return "樹都被砍光了……"
		_:
			return "家豪被抓去當晚餐了……"

func _defeat_tip() -> String:
	var tip := "用引路點讓家豪一次只打到一個人，不要讓她被包圍。"
	match fail:
		"hood":
			tip = "狼外婆守著小紅帽，直接進門會被拍出來。先把假獵物放在木屋門口引開她，再用引路點帶家豪進屋。"
		"bird":
			match last_hurt_by:
				"wolf":
					tip = "家豪被狼外婆拍了 %d 次。先放假獵物在木屋門口把她引開，再讓家豪進屋。" % swats
				"chopper":
					tip = "家豪被伐木工圍著打。用假獵物讓他們背對家豪，從背後偷襲；一次只對付一個。"
				"smoker":
					tip = "家豪被抽菸的人打倒了。別讓她一次碰到兩個人，先用假獵物引開一個。"
				_:
					tip = "家豪撐不住了。用假獵物引開人，一次只讓她打一個。"
		"fire":
			tip = "菸蒂幾秒後會點著附近的樹，火還會延燒。讓家豪走過去踩熄；倒下的樹幹能擋火。"
		"trees":
			tip = "假獵物能把伐木的人引離樹，但抽菸的人跑去看時會把菸丟在地上。從樹後面摸過去可以偷襲。"
	tip += "\n按 R 重試，按 T 再看教學。"
	var stars := _star_block(false)
	if stars == "":
		return tip
	return tip + "\n" + stars
