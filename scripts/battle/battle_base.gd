extends Node
## 戰局引擎（template，所有關卡共用；各關不要改這個檔案）
##
## 每一小關的 battle.gd 這樣開頭：
##   extends "res://scripts/battle/battle_base.gd"
## 然後只覆寫底下「關卡可以覆寫」那一區的函式：要哪些道具、有哪些敵人、有什麼機關、輸贏條件、文字。
##
## 這裡負責的東西（每關都一樣）：
##   - 準備 → 開打 → 結束 三個階段、Enter 開始、R 重試、M 回地圖
##   - 道具欄（1~9 / 滾輪切換、左鍵施放、次數分準備／開打兩段、冷卻）
##   - 家豪的 AI（衝去打最近的敵人、吃飼料、挨打飛走、飛過圍欄和水、偷襲）
##   - 一般近戰敵人的 AI（巡邏、紅色偵測扇形、聽到打鬥趕來、踢、重踢、掉進水裡）
##   - 血條、右上角敵人名單、提示文字、開場教學、勝敗結算、輸了的晚餐畫面
##   - 畫面上平常只留：左上「?」（按 H 看操作）、右上敵人名單、下方道具格、右下「開始 ▶」
##
## 戰局可重演：角色邏輯固定每 1/60 秒算一步，沒有亂數。

signal phase_changed(phase: String)

enum Phase { PREPARE, RUNNING, ENDED }

const Fighter := preload("res://scripts/battle/fighter.gd")
const Hotbar := preload("res://scripts/ui/hotbar.gd")
const DialogBox := preload("res://scripts/ui/dialog_box.gd")
const TutArrow := preload("res://scripts/ui/tut_arrow.gd")
const EnemyFace := preload("res://scripts/ui/enemy_face.gd")
const UIStyle := preload("res://scripts/ui/ui_style.gd")   # 全遊戲共用的介面美術（手帳風格）
const Progress := preload("res://scripts/progress.gd")
const LEVEL_SELECT_SCENE := "res://scenes/level_select.tscn"

# 家豪（每關都一樣）
const BIRD_MAX_HP := 10.0
const PECK_DAMAGE := 2.5
const SNEAK_MULT := 1.0        # 偷襲不加傷害，只會讓敵人嚇一跳愣住
const STARTLE_TIME := 1.1      # 被偷襲嚇一跳、愣住的時間
const FLY_TIME := 1.15
const FLY_PEAK := 1.7
const HOP_TIME := 0.7          # 飛越圍欄的小跳
const FENCE_CLEAR := 1.0
const SLIP_TIME := 3.0         # 滑倒後躺在地上的時間
const FEED_SENSE := 10.0       # 家豪聞得到多遠的飼料
const FEED_EAT_TIME := 0.9
const FEED_LINGER := 3.0       # 吃完飼料後，家豪會在原地東張西望這麼久才繼續衝
const FEED_HEAL := 1.0         # 吃一把飼料回的血
# 一般近戰敵人（農夫型）的預設值；每個敵人可以在 _enemy_specs() 個別改
const ENEMY_MAX_HP := 8.0
const ALERT_RADIUS := 11.0     # 打鬥聲傳得到的距離：哪裡有人挨打，這個距離內的敵人會趕過來
const DEFEAT_ORIGIN := Vector3(600.0, 0.0, 600.0)
const SIM_DT := 1.0 / 60.0
const TUT_STEP_TIME := 5.5
const TUT_WIDTH := 400.0       # 教學便利貼的寬度（字會自動換行）
const PAN_STEP := 3.0

var phase: Phase = Phase.PREPARE
var time := 0.0
var outcome := ""
var events: Array = []
var attempts: Array = []
var hit_spots: Array = []
var stage_id := ""             # 例如 "example_farm/1"（從選關畫面帶進來；直接開場景時是空的）

var world: Node
var chars: Node
var player: Node3D
var camera: Camera3D
var crosshair: Control

var bird: Fighter
var enemies: Array = []        # Array[Fighter]
var farmers: Array:            # 舊名字（農場範例和自動測試在用）
	get:
		return enemies

# 道具
var items: Array = []          # 道具物件（scripts/items/*.gd）
var SKILLS: Array:             # 舊名字
	get:
		return items
var selected := 0
var charges: Array = []
var cooldowns: Array = []      # 每個道具剩下的冷卻秒數
var casts: Array = []          # 本輪施放紀錄 {t, id, pos}
var feeds: Array = []          # 地上的飼料 {pos, node}（家豪 AI 會去吃）
var no_cooldown := false       # 自動驗收用：跳過冷卻
var no_limit := false          # 自動驗收用：不扣次數
var show_tutorial := true      # 進關卡時自動播道具教學（關卡可以在 _level_setup() 關掉）
var aim_point: Variant = null
var aim_error := ""
var fx_root: Node3D            # 道具、特效都放這底下，重試時一起清掉
var _fx_timed: Array = []      # 會自己消失的特效 {node, t, life, kind}
var _step_start := {}          # 每一步開始時每個角色的位置（判斷有沒有在走）
var _preview: MeshInstance3D
var _dots: Array = []          # 預測路徑的小點
var _path_cache_at := Vector3(INF, INF, INF)
var _path_cache := PackedVector3Array()
var _path_cache_item := -1
var _acc := 0.0
var _pan_acc := 0.0
var _pan_ms := -100000

# HUD
var _hud_layer: CanvasLayer
var _phase_label: Label
var _toast_label: Label
var _toast_t := 0.0
var _summary_panel: PanelContainer
var _summary_label: Label
var _hotbar: Hotbar
var _dialog: DialogBox
var _enemy_rows: Array = []    # 右上角敵人欄 {fighter, face, fill, chip, width}
var _summary_box: VBoxContainer   # 結算卡的內容（標題＋歷次嘗試＋按鈕列）
var _summary_title: Label
var _summary_keys: HBoxContainer
# 預設的小按鈕（右下「開始 ▶」、開打後的「R 重試」、左上「?」＋操作說明卡）
var _hud_default := false      # _update_phase_label() 跑過＝這一關用預設的這幾個（見那個函式的說明）
var _hud_start: Control
var _hud_retry: Control
var _hud_help_chip: Control
var _hud_help_card: PanelContainer
var _hud_help_key := ""        # 說明卡目前的內容（內容變了才重排）
var _hud_help_pin := false     # 按一下 H：釘住；再按一下：收起來
var _hud_help_down := false
var _hud_help_ms := 0
var tutorial_step := -1        # -1 = 沒在教學
var _tut_t := 0.0
var _tut_seen := false
var _tut_arrow: TutArrow
var _tut_panel: PanelContainer
var _tut_label: Label
var _tut_page: Label
# 輸了的畫面
var defeat_room: Node3D
var defeat_shown := false
var _defeat_delay := -1.0
var _defeat_layer: CanvasLayer
var _defeat_label: Label
var _defeat_detail: Label

# ================================================================== 關卡可以覆寫

## 這一關有哪些道具、各幾次（順序就是技能欄的順序，最多 9 個）
func _make_items() -> Array:
	return [
		preload("res://scripts/items/feed_item.gd").new().uses(-1, -1),
		preload("res://scripts/items/banana_item.gd").new().uses(-1, -1),
		preload("res://scripts/items/rock_item.gd").new().uses(-1, -1),
	]

## 這一關的敵人。每個敵人是一個字典，常用的鍵：
##   name: 名字（右上角顯示）
##   route: 巡邏路線 [Vector3, ...]，第一個點是出生點（只有一個點就站著不動）
##   loop: true 繞圈 / false 來回　pause: 每到一個點停下來張望幾秒
##   model: "farmer"（預設）、"merchant"（胖商人）或 .glb/.gltf 的路徑
##   kind: "melee"（預設，一般近戰）；其他名字要自己覆寫 _tick_enemy() 處理
##   hp, speed, reach, kick_damage, heavy_damage, vision_range, vision_deg（偵測扇形半角）
##   immune_peck, immune_rock, can_slip, has_cone, hears_noise, target_last, is_boss
##   portrait: 頭像圖片路徑　hud_name: 敵人欄顯示的名字　bar_y: 頭上血條高度
func _enemy_specs() -> Array:
	return []

## 所有角色建好之後呼叫一次：在這裡做關卡專屬的東西（機關、特效、改 show_tutorial…）
func _level_setup() -> void:
	pass

## 每次重試（R）時呼叫：把機關恢復原狀
func _level_reset() -> void:
	pass

## 按下 Enter 開打時呼叫
func _level_start() -> void:
	pass

## 開打後每 1/60 秒呼叫（在角色移動之後、判定勝負之前）
func _level_step(_dt: float) -> void:
	pass

## 勝負已分之後每 1/60 秒呼叫（讓正在倒的東西倒完）
func _level_step_ended(_dt: float) -> void:
	pass

## 每一畫面呼叫（擺姿勢、動畫等純視覺的東西）
func _level_visuals() -> void:
	pass

## 判定勝負：回傳 "win"、"lose" 或 ""（還沒分出來）
func _check_end() -> String:
	if enemies.all(func(f): return not f.alive()):
		return "win"
	if not bird.alive():
		return "lose"
	return ""

## 每個敵人每 1/60 秒的行為。自訂 kind 的敵人在這裡處理，其他交給一般近戰 AI
func _tick_enemy(f: Fighter, dt: float) -> void:
	_tick_melee(f, dt)

## 巨石滾動中每一步都會問一次：撞到關卡的機關就處理，回傳 true 讓巨石停下
func _on_rock_rolling(_rock: Dictionary, _pos: Vector3, _speed: float) -> bool:
	return false

## 瞄準時預測路徑更新了（例如把會撞到的機關亮起來）；on=false 代表不用亮
func _update_highlights(_path: PackedVector3Array, _on: bool) -> void:
	pass

## 開場教學每一步的文字（預設用每個道具的 tutorial）
func _tutorial_texts() -> Array:
	var out: Array = []
	for i in items.size():
		out.append("【%d %s】%s" % [i + 1, items[i].name, items[i].tutorial])
	return out

## 準備階段上方小紙片的提示（一句話就好；不用再寫「準備中」和「按 Enter 開始」，右下角有開始鈕）。
## 回傳空字串就不顯示
func _prepare_hint() -> String:
	return ""

## 按 H 看到的操作說明：一列一組 [按鍵, 做什麼]。按鍵用「／」分開會畫成好幾顆鍵帽（例如 "數字鍵／滾輪"）。
## 預設讀場景裡 HUD/Hint 那一行字（「WASD 飄移｜空白 上升｜…」），所以關卡只改 Hint.text 也可以
func _help_rows() -> Array:
	var hint := get_node_or_null("../HUD/Hint") as Label
	var src: String = hint.text if hint else ""
	var rows: Array = []
	for seg in src.split("｜" if src.contains("｜") else "　", false):
		var t := seg.strip_edges()
		if t == "":
			continue
		var hold := t.begins_with("按住 ")
		if hold:
			t = t.substr(3)
		var cut := t.find(" ")
		if cut < 0:
			rows.append(["", t])
		else:
			rows.append([t.substr(0, cut), ("按住" if hold else "") + t.substr(cut + 1).strip_edges()])
	return rows

func _win_line() -> String:
	return "過關！這場是你偷偷扳回來的。"

func _lose_line(left: int) -> String:
	return "家豪倒下了…（還剩 %d 個敵人）" % left

func _defeat_title() -> String:
	return "家豪被抓去當晚餐了……"

func _defeat_tip() -> String:
	return "提示：撒飼料把家豪引開，讓他一次只對上一個敵人。" if casts.is_empty() else "提示：換個時機或位置降下神蹟再試一次。"

## 家豪飛行要降落在水裡時，改降落到哪裡（預設：往外找最近的岸邊）
func _dry_landing(dest: Vector3) -> Vector3:
	for ring in range(1, 40):
		var r := ring * 0.4
		for k in 16:
			var a := k * TAU / 16.0
			var q := Vector3(dest.x + cos(a) * r, 0, dest.z + sin(a) * r)
			if not world.in_water(q.x, q.z) and world.walkable(q.x, q.z):
				return q
	return dest

# ================================================================== 初始化

func _ready() -> void:
	world = get_node("../World")
	player = get_node("../Player")
	camera = player.get_node("Head/Camera3D")
	var hint := get_node_or_null("../HUD/Hint") as Label
	if hint:
		# 操作說明那一長行字預設收起來：左上角只留「?」，按 H 才用鍵帽排出來（_help_rows）
		UIStyle.slip(hint)
		hint.visible = false
	crosshair = get_node_or_null("../HUD/Crosshair")
	stage_id = String(Engine.get_meta("stage_id", ""))
	fx_root = Node3D.new()
	fx_root.name = "MiracleFX"
	world.add_child(fx_root)
	_ensure_actions()
	UIStyle.use_theme("default")   # 每一關都從預設主題色開始；要換的關卡在 _level_setup() 呼叫 UIStyle.use_theme()
	items = _make_items()
	_build_fighters()
	_build_preview()
	_level_setup()
	_build_hud()
	_build_defeat()
	reset()
	if show_tutorial and not "--autotest" in OS.get_cmdline_user_args():
		start_tutorial()

func _ensure_actions() -> void:
	var map := {"battle_start": [KEY_ENTER, KEY_KP_ENTER], "battle_reset": [KEY_R], "back_to_map": [KEY_M]}
	for n in 9:
		map["skill_%d" % (n + 1)] = [KEY_1 + n, KEY_KP_1 + n]
	for action in map:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			for k in map[action]:
				var ev := InputEventKey.new()
				ev.physical_keycode = k
				InputMap.action_add_event(action, ev)

func _build_fighters() -> void:
	var specs := _enemy_specs()
	# 角色模型：場地自己建好了 Characters（例如農場範例）就直接用，不然照 _enemy_specs() 生出來
	chars = world.get_node_or_null("Characters")
	if chars == null:
		chars = Node3D.new()
		chars.name = "Characters"
		chars.set_script(load("res://scripts/characters.gd"))
		world.add_child(chars)
		chars.spawn_hero(world, world.hero_start)
		for s in specs:
			var start: Vector3 = s.route[0] if s.has("route") and not s.route.is_empty() else Vector3.ZERO
			chars.spawn_enemy(world, String(s.get("model", "farmer")), start)

	bird = Fighter.new()
	bird.name = "家豪"
	bird.node = chars.hero
	bird.is_bird = true
	bird.max_hp = BIRD_MAX_HP
	bird.speed = 3.2
	bird.reach = 1.05
	bird.windup = 0.3
	bird.recover = 0.75
	bird.bar_y = 1.75
	bird.start_pos = ground(world.hero_start)
	bird.start_yaw = world.get("hero_yaw") if world.get("hero_yaw") != null else PI
	bird.body = chars.hero.get_node_or_null("Body")
	if bird.body:
		for w in ["WingL", "WingR"]:
			var n := bird.body.find_child(w, true, false)
			if n:
				bird.wings.append(n)

	for i in specs.size():
		var s: Dictionary = specs[i]
		var f := Fighter.new()
		f.name = String(s.get("name", "敵人%d" % (i + 1)))
		f.node = chars.enemies[i]
		f.kind = String(s.get("kind", "melee"))
		f.max_hp = float(s.get("hp", ENEMY_MAX_HP))
		f.speed = float(s.get("speed", 1.7))
		f.reach = float(s.get("reach", 1.75))
		f.windup = float(s.get("windup", 0.45))
		f.recover = float(s.get("recover", 1.0))
		f.kick_damage = float(s.get("kick_damage", 2.0))
		f.heavy_damage = float(s.get("heavy_damage", 4.0))
		f.vision_range = float(s.get("vision_range", 7.0))
		f.vision_half = deg_to_rad(float(s.get("vision_deg", 50.0)))
		f.is_boss = bool(s.get("is_boss", false))
		f.immune_peck = bool(s.get("immune_peck", false))
		f.immune_rock = bool(s.get("immune_rock", false))
		f.can_slip = bool(s.get("can_slip", true))
		f.has_cone = bool(s.get("has_cone", true))
		f.hears_noise = bool(s.get("hears_noise", true))
		f.target_last = bool(s.get("target_last", false))
		f.hud_name = String(s.get("hud_name", ""))
		f.face = String(s.get("face", "boss" if f.is_boss else "farmer"))
		f.bar_y = float(s.get("bar_y", 2.85))
		if s.has("portrait"):
			f.portrait = _load_tex(String(s.portrait))
		var route: Array = s.get("route", [Vector3.ZERO])
		for p in route:
			f.route.append(ground(p))
		if f.route.size() == 1:
			f.route.append(f.route[0])
		f.loop = bool(s.get("loop", true))
		f.pause = float(s.get("pause", 1.0))
		f.start_pos = f.route[0]
		f.start_yaw = float(s.get("yaw", _yaw_to(f.route[0], f.route[1]) if f.route[0] != f.route[1] else 0.0))
		if f.has_cone:
			f.cone = _make_cone()
		var aps: Array = f.node.find_children("*", "AnimationPlayer", true, false)
		if not aps.is_empty():
			f.anim = aps[0]
			for a in ["Walk", "Idle", "Run", "Idle_Gun", "Idle_Gun_Pointing"]:
				if f.anim.has_animation(a):
					f.anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR
			for a in ["Death", "Kick_Right", "Kick_Left", "HitRecieve", "Wave", "Gun_Shoot"]:
				if f.anim.has_animation(a):
					f.anim.get_animation(a).loop_mode = Animation.LOOP_NONE
		enemies.append(f)

func _build_preview() -> void:
	_preview = MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.9
	tm.outer_radius = 1.0
	tm.rings = 40
	tm.ring_segments = 6
	_preview.mesh = tm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.no_depth_test = true
	m.albedo_color = Color(1, 1, 1, 0.8)
	_preview.material_override = m
	_preview.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_preview.visible = false
	world.add_child(_preview)
	var dot_mesh := SphereMesh.new()
	dot_mesh.radius = 0.09
	dot_mesh.height = 0.18
	dot_mesh.radial_segments = 8
	dot_mesh.rings = 4
	var dm := StandardMaterial3D.new()
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.no_depth_test = true
	dm.albedo_color = Color(1, 1, 1, 0.95)
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for i in 48:
		var d := MeshInstance3D.new()
		d.mesh = dot_mesh
		d.material_override = dm
		d.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		d.visible = false
		world.add_child(d)
		_dots.append(d)

# ================================================================== 狀態切換

## 第 i 個道具在某個階段一開始有幾次（-1 = 不限）
func phase_charges(i: int, running: bool) -> int:
	return items[i].charges_for(running)

## 準備和開打是不是共用同一個次數（共用的話開始時數字不切換）
func is_shared(i: int) -> bool:
	return items[i].is_shared()

func reset() -> void:
	phase = Phase.PREPARE
	time = 0.0
	_acc = 0.0
	outcome = ""
	events.clear()
	hit_spots.clear()
	casts.clear()
	charges.clear()
	cooldowns.clear()
	for i in items.size():
		charges.append(phase_charges(i, false))
		cooldowns.append(0.0)
	for c in fx_root.get_children():
		c.queue_free()
	feeds.clear()
	for it in items:
		it.reset(self)
	_step_start.clear()
	_fx_timed.clear()
	for f in all_fighters():
		f.hp = f.max_hp
		f.chip = 1.0
		f.shoot_cd = 0.0
		f.pos = f.start_pos
		f.yaw = f.start_yaw
		f.kb_vel = Vector3.ZERO
		f.air = 0.0
		f.heavy = false
		f.attack_n = 0
		f.fled_half = false
		f.detouring = false
		f.chased = false
		f.aggro = false
		f.alert_t = -1.0
		f.wp = 1
		f.wp_dir = 1
		f.target = null
		f.feed_target = -1
		f.data = {}
		f.set_state("idle")
		anim(f, "Idle")
	_level_reset()
	_apply_visuals()
	_summary_panel.visible = false
	_summary_box.visible = false
	if _dialog:
		_dialog.t = -1.0
		_dialog.visible = false
	_hide_defeat()
	toast("", 0.0)
	_update_phase_label()
	if _hotbar != null:
		_hotbar.stop_switch()
	_refresh_slots()
	phase_changed.emit("prepare")

func start() -> void:
	if phase != Phase.PREPARE:
		return
	phase = Phase.RUNNING
	# 換成開打後的次數；分開算的格子在技能欄上播一段數字切換動畫
	var before := charges.duplicate()
	var switched: Array = []
	for i in items.size():
		if not is_shared(i):
			charges[i] = phase_charges(i, true)
			switched.append(i)
	if _hotbar != null:
		_hotbar.play_switch(before, switched)
	_refresh_slots()
	toast("", 0.0)   # 準備階段的提示（例如「開打後會補」）不要殘留到開打後
	bird.set_state("charge")
	for f in enemies:
		f.set_state("patrol")   # 一開打就各自開始巡邏（自訂敵人可以在 _level_start() 改）
	_level_start()
	log_event("開始")
	_update_phase_label()
	phase_changed.emit("running")

func _end(result: String) -> void:
	phase = Phase.ENDED
	outcome = result
	log_event("勝利" if result == "win" else "落敗")
	if result == "win":
		if stage_id != "" and not "--autotest" in OS.get_cmdline_user_args():   # 自動驗收不動到玩家的存檔
			Progress.mark_cleared(stage_id)   # 選關地圖會記得這一小關過了
		bird.set_state("cheer")
		bird.air = 0.0
	else:
		for f in enemies:
			if f.alive():
				anim(f, "Wave")
	var used := {}
	for c in casts:
		used[c.id] = used.get(c.id, 0) + 1
	attempts.append({"num": attempts.size() + 1, "outcome": result, "time": time, "used": used,
		"left": enemies_left()})
	_show_summary()
	if result == "lose":
		_summary_panel.visible = false
		_defeat_delay = 1.6   # 先看家豪倒下，再切到晚餐畫面
	_update_phase_label()
	phase_changed.emit("ended")

# ================================================================== 輸入與道具

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("battle_start"):
		start()
		return
	if event.is_action_pressed("battle_reset"):
		reset()
		return
	if event.is_action_pressed("back_to_map"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_tree().change_scene_to_file(LEVEL_SELECT_SCENE)
		return
	for n in mini(items.size(), 9):
		if event.is_action_pressed("skill_%d" % (n + 1)):
			select_skill(n)
			return
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		# 滾輪換道具：游標有沒有鎖住都可以（觸控板滑動剛觸發過就不重複算）
		if Time.get_ticks_msec() - _pan_ms > 250:
			_wheel_step(-1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if event.button_index == MOUSE_BUTTON_LEFT:
			try_cast()
	elif event is InputEventPanGesture:
		# Mac 觸控板兩指上下滑：累積到一定距離才換一格，避免一滑就跳好幾格
		_pan_ms = Time.get_ticks_msec()
		_pan_acc += event.delta.y
		while absf(_pan_acc) >= PAN_STEP:
			_wheel_step(1 if _pan_acc > 0.0 else -1)
			_pan_acc -= signf(_pan_acc) * PAN_STEP

## 滾輪往下 = 下一格，往上 = 上一格（頭尾相接）
func _wheel_step(d: int) -> void:
	if items.is_empty():
		return
	select_skill((selected + d + items.size()) % items.size())
	if _hotbar:
		_hotbar.name_t = 2.0

func select_skill(i: int) -> void:
	selected = clampi(i, 0, maxi(items.size() - 1, 0))
	_refresh_slots()

func _update_aim() -> void:
	aim_point = world.ray_ground(camera.global_position, -camera.global_basis.z, 70.0)

## 在準心指到的地面施放目前選的道具
func try_cast() -> bool:
	_update_aim()
	if aim_point == null:
		toast("準心要指到地面", 1.2)
		return false
	return cast(selected, aim_point)

## 這裡能不能放這個道具；可以回傳空字串，不行回傳原因
func placement_error(i: int, p: Vector3) -> String:
	return items[i].placement_error(self, p)

func cast(i: int, p: Vector3) -> bool:
	if phase == Phase.ENDED or i < 0 or i >= items.size():
		return false
	var it = items[i]
	if charges[i] == 0 and not no_limit:
		if phase == Phase.PREPARE and not is_shared(i) and phase_charges(i, true) != 0:
			if phase_charges(i, false) == 0:
				toast("%s 要開打後才能用" % it.name, 1.4)
			else:
				toast("準備階段的%s用完了，開打後會補" % it.name, 1.6)
		else:
			toast("%s 用完了" % it.name, 1.4)
		return false
	if not no_cooldown and cooldowns[i] > 0.0:
		toast("%s 還要等 %.1f 秒" % [it.name, cooldowns[i]], 1.0)
		return false
	var err := placement_error(i, p)
	if err != "":
		toast(err, 1.4)
		return false
	if charges[i] > 0 and not no_limit:
		charges[i] -= 1
	if not no_cooldown:
		cooldowns[i] = it.cooldown
	casts.append({"t": time, "id": it.id, "pos": p})
	log_event("神降下%s（%.1f, %.1f）" % [it.name, p.x, p.z])
	it.cast(self, p)
	_refresh_slots()
	return true

func skill_index(id: String) -> int:
	for k in items.size():
		if items[k].id == id:
			return k
	return -1

## 找某種道具的物件（例如 item("rock").rocks）
func item(id: String):
	var k := skill_index(id)
	return items[k] if k >= 0 else null

## 冷卻時間照真實時間走（準備階段也會倒數）
func _tick_cooldowns(dt: float) -> void:
	var changed := false
	for k in cooldowns.size():
		if cooldowns[k] > 0.0:
			cooldowns[k] = maxf(cooldowns[k] - dt, 0.0)
			changed = true
	if changed and _hotbar:
		_hotbar.cooldowns = cooldowns.duplicate()
		_hotbar.queue_redraw()

## 像高爾夫球遊戲一樣：沿著預測路徑擺一排小點
func _update_path_preview(on: bool) -> void:
	var path := PackedVector3Array()
	if on:
		if aim_point.distance_to(_path_cache_at) > 0.05 or _path_cache_item != selected:
			_path_cache_at = aim_point
			_path_cache_item = selected
			_path_cache = items[selected].preview_path(self, aim_point)
		path = _path_cache
	if path.size() < 2:
		for d in _dots:
			d.visible = false
		_update_highlights(PackedVector3Array(), false)
		return
	_update_highlights(path, true)
	var n := path.size()
	var spacing := 5
	var r: float = items[selected].radius
	for k in _dots.size():
		var idx := (k + 1) * spacing
		var d: MeshInstance3D = _dots[k]
		if idx < n:
			d.visible = true
			d.global_position = path[idx] - Vector3(0, r - 0.12, 0)
			var fade := 1.0 - float(idx) / maxf(n, 1.0) * 0.6
			d.scale = Vector3.ONE * fade
		else:
			d.visible = false

func visible_dots() -> int:
	return _dots.filter(func(d): return d.visible).size()

## 巨石的預測路徑（舊名字，給農場範例和自動測試用）
func simulate_roll(start: Vector3) -> PackedVector3Array:
	return preload("res://scripts/items/rock_item.gd").simulate(self, start)

# ================================================================== 主迴圈

func _physics_process(delta: float) -> void:
	_acc += delta
	while _acc >= SIM_DT - 0.000001:
		_acc -= SIM_DT
		_step(SIM_DT)
	_apply_visuals()

func _step(dt: float) -> void:
	if phase == Phase.RUNNING:
		time += dt
		for f in all_fighters():
			_step_start[f] = f.pos
		for f in enemies:
			_tick_enemy(f, dt)
		_level_step(dt)
		_tick_bird(dt)
		for it in items:
			it.step(self, dt)
		_tick_fx(dt)
		var r := _check_end()
		if r != "":
			_end(r)
	elif phase == Phase.ENDED:
		bird.t += dt
		_level_step_ended(dt)
		_tick_fx(dt)

func _process(dt: float) -> void:
	_tick_tutorial(dt)
	_tick_cooldowns(dt)
	if _hud_default:
		_hud_tick_help()
	_update_aim()
	if items.is_empty():
		_preview.visible = false
		return
	# 準備階段用完（或準備階段不能用）但開打後還有：照樣顯示預覽讓玩家先規劃，只是放不下去
	var later: bool = phase == Phase.PREPARE and charges[selected] == 0 and not no_limit \
		and not is_shared(selected) and phase_charges(selected, true) != 0
	var show: bool = phase != Phase.ENDED and aim_point != null and (charges[selected] != 0 or no_limit or later) and not defeat_shown
	aim_error = placement_error(selected, aim_point) if aim_point != null else ""
	var ok := show and aim_error == ""
	_preview.visible = show
	if show:
		var r: float = items[selected].radius
		_preview.global_position = aim_point + Vector3(0, 0.08, 0)
		_preview.scale = Vector3(r, 1, r)
		var c: Color = items[selected].color if ok else Color(1.0, 0.3, 0.25)
		if ok and later:
			c = Color(0.75, 0.75, 0.75)   # 灰色：位置可以，但要開打後才放得下
		(_preview.material_override as StandardMaterial3D).albedo_color = Color(c, 0.85)
	_update_path_preview(ok)
	var can := ok and not later
	if crosshair and "highlight" in crosshair:
		crosshair.highlight = can
	if _toast_t > 0.0:
		_toast_t -= dt
		if _toast_t <= 0.0:
			_toast_label.text = ""
			_toast_label.visible = false
	if _defeat_delay > 0.0:
		_defeat_delay -= dt
		if _defeat_delay <= 0.0:
			_show_defeat()
	if phase == Phase.RUNNING:
		_update_phase_label()
	_update_bars(dt)
	for f in enemies:
		_draw_cone(f)
	for row in _enemy_rows:
		var f: Fighter = row.fighter
		var rr: float = f.ratio() if f.alive() else 0.0
		(row.fill as ColorRect).size.x = row.width * rr
		(row.chip as ColorRect).size.x = row.width * f.chip
		var face: EnemyFace = row.face
		if face.dead != (not f.alive()):
			face.dead = not f.alive()
			face.queue_redraw()

## 會自己消失的特效（灰塵、水花、子彈軌跡）
func spawn_timed(node: Node3D, life: float, kind := "") -> void:
	if node.get_parent() == null:
		fx_root.add_child(node)
	_fx_timed.append({"node": node, "t": 0.0, "life": life, "kind": kind})

func _tick_fx(dt: float) -> void:
	for i in range(_fx_timed.size() - 1, -1, -1):
		var e: Dictionary = _fx_timed[i]
		e.t += dt
		var n2 := e.node as Node3D
		if e.kind == "dust":
			n2.scale = Vector3.ONE * (1.0 + e.t * 2.5)
			n2.position.y += dt * 1.2
		if e.t >= e.life:
			n2.queue_free()
			_fx_timed.remove_at(i)

# ================================================================== 一般近戰敵人（農夫型）

func _farmer_open(f: Fighter) -> bool:
	return (f.heavy and f.state == "recover") or f.state in ["pant", "stagger", "down", "getup", "startled", "slip"]

func _bird_targetable() -> bool:
	return bird.alive() and bird.state != "fly"

func aggro(f: Fighter) -> void:
	if f.aggro or not f.alive():
		return
	f.aggro = true
	if f.state in ["idle", "patrol", "look"]:
		f.set_state("alert")
		anim(f, "Idle")
	log_event("%s發現家豪" % f.name)

## 打鬥聲：在 p 發生打擊時，附近還沒發現的敵人會在 0.8 秒後趕過來
func noise_at(p: Vector3) -> void:
	for o in enemies:
		if not o.hears_noise:
			continue
		if o.alive() and not o.aggro and o.alert_t < 0.0 and flat_dist(o.pos, p) <= ALERT_RADIUS:
			o.alert_t = 0.8

## 掉進水裡：沉下去。回傳 true 代表這一步已經處理完（呼叫的人直接 return）
func _tick_drown(f: Fighter) -> bool:
	if f.state == "drown":
		f.air = -2.2 * clampf(f.t / 1.4, 0.0, 1.0)
		if f.t >= 1.4:
			f.hp = 0.0
			f.set_state("dead")
		return true
	if f.alive() and world.in_water(f.pos.x, f.pos.z):
		f.hp = 0.0
		f.set_state("drown")
		anim(f, "Death")
		spawn_splash(f.pos)
		log_event("%s追家豪追進水池，溺死了" % f.name)
		toast("撲通！", 1.2)
		return true
	return false

func _tick_melee(f: Fighter, dt: float) -> void:
	f.t += dt
	_apply_knockback(f, dt)
	if _tick_drown(f):
		return
	if f.alert_t >= 0.0:
		f.alert_t -= dt
		if f.alert_t < 0.0 and not f.aggro:
			log_event("%s聽到打鬥聲趕過來" % f.name)
			aggro(f)
	var dist := flat_dist(f.pos, bird.pos)
	if not f.aggro and f.state in ["patrol", "look", "idle"] and sees_bird(f):
		log_event("%s看到家豪了" % f.name)
		aggro(f)
	match f.state:
		"patrol":
			var goal: Vector3 = f.route[f.wp]
			if flat_dist(f.pos, goal) < 0.2:
				f.look_yaw = f.yaw
				f.set_state("look")
				anim(f, "Idle")
			else:
				_walk(f, goal, 1.0, dt)
				anim(f, "Walk", 0.7)
		"look":
			# 停下來左右張望（偵測區會跟著掃）
			f.yaw = f.look_yaw + sin(f.t * 2.2) * 0.9
			if f.t >= f.pause:
				var n := f.route.size()
				if f.loop:
					f.wp = (f.wp + 1) % n
				else:
					if f.wp + f.wp_dir >= n or f.wp + f.wp_dir < 0:
						f.wp_dir = -f.wp_dir
					f.wp += f.wp_dir
				f.set_state("patrol")
		"startled":
			# 被偷襲嚇一跳，愣在原地
			if f.t >= STARTLE_TIME:
				f.set_state("walk")
		"alert":
			_face(f, bird.pos)
			if f.t >= 0.6:
				f.set_state("walk")
		"walk":
			var target := bird.fly_to if bird.state == "fly" else bird.pos
			var was := f.detouring
			_walk(f, target, f.speed, dt)
			if f.detouring and not was:
				log_event("%s被圍欄擋住，繞路追" % f.name)
			elif was and not f.detouring and f.chased:
				f.chased = false
				f.set_state("pant")
				anim(f, "Idle", 0.6)
				log_event("%s繞了一大圈，停下來喘氣" % f.name)
				return
			anim(f, "Walk")
			if dist <= f.reach and _bird_targetable():
				_melee_attack(f)
		"windup":
			_face(f, bird.pos)
			if f.t >= (0.8 if f.heavy else f.windup):
				if dist <= f.reach + 0.35 and _bird_targetable():
					hit_bird(f.heavy_damage if f.heavy else f.kick_damage, f.heavy, f.pos, f)
				f.set_state("recover")
		"recover":
			if f.t >= (1.7 if f.heavy else f.recover):
				f.heavy = false
				if dist <= f.reach and _bird_targetable():
					_melee_attack(f)
				else:
					f.set_state("walk")
		"stagger":
			if f.t >= 0.5:
				f.set_state("walk")
		"pant":
			_face(f, bird.pos)
			if f.t >= 1.3:
				f.set_state("walk")
		"down":
			if f.t >= 3.0:
				f.set_state("getup")
				anim(f, "Idle")
		"getup":
			if f.t >= 0.5:
				f.set_state("walk")
		"slip":
			# 踩到香蕉皮，躺在地上；起來後有在追就繼續追，沒發現家豪的回去巡邏
			if f.t >= SLIP_TIME:
				anim(f, "Idle")
				f.set_state("getup" if f.aggro else "patrol")

func _melee_attack(f: Fighter) -> void:
	f.heavy = f.attack_n % 3 == 2
	f.attack_n += 1
	f.set_state("windup")
	if f.heavy:
		anim(f, "Kick_Left", 0.75)
	else:
		anim(f, "Kick_Right", 1.3)

## 家豪在不在這個敵人前方的偵測區裡
func sees_bird(f: Fighter) -> bool:
	if not bird.alive() or bird.air > 1.0:
		return false
	var to := Vector2(bird.pos.x - f.pos.x, bird.pos.z - f.pos.z)
	var d := to.length()
	if d > f.vision_range:
		return false
	if d < 0.01:
		return true
	var fwd := Vector2(sin(f.yaw), cos(f.yaw))
	return fwd.angle_to(to.normalized()) <= f.vision_half and fwd.angle_to(to.normalized()) >= -f.vision_half

func enemies_left() -> int:
	return enemies.filter(func(f): return f.alive()).size()

## 角色踩到東西滑倒（香蕉皮等道具會呼叫）
func make_slip(f: Fighter, what := "香蕉皮") -> void:
	f.kb_vel = Vector3.ZERO
	f.heavy = false
	f.set_state("slip")
	if not f.is_bird:
		anim(f, "Death")
	log_event("%s踩到%s滑倒了" % [f.name, what])
	toast("滑倒了！", 1.2)

func spawn_splash(p: Vector3) -> void:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.85, 0.95, 1.0, 0.7)
	var wy: float = world.get("water_y") if world.get("water_y") != null else p.y
	for k in 6:
		var a := k * TAU / 6.0
		var mi := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.35
		sm.height = 0.7
		mi.mesh = sm
		mi.material_override = m
		fx_root.add_child(mi)
		mi.global_position = Vector3(p.x + cos(a) * 0.6, wy + 0.2, p.z + sin(a) * 0.6)
		spawn_timed(mi, 0.9, "dust")

func _make_cone() -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = ImmediateMesh.new()
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.vertex_color_use_as_albedo = true
	m.render_priority = 1
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(mi)
	return mi

## 把偵測區畫成貼著地面的紅色扇形
func _draw_cone(f: Fighter) -> void:
	if f.cone == null:
		return
	var im := f.cone.mesh as ImmediateMesh
	im.clear_surfaces()
	var show := f.alive() and not f.aggro and phase != Phase.ENDED
	f.cone.visible = show
	if not show:
		return
	var segs := 20
	var rings := 8
	var pts := []
	for r in rings + 1:
		var row := []
		var rad := f.vision_range * float(r) / rings
		for k in segs + 1:
			var a := f.yaw - f.vision_half + 2.0 * f.vision_half * float(k) / segs
			var x := f.pos.x + sin(a) * rad
			var z := f.pos.z + cos(a) * rad
			row.append(Vector3(x, world.height_at(x, z) + 0.15, z))
		pts.append(row)
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for r in rings:
		var c0 := Color(1.0, 0.1, 0.08, 0.5 - 0.03 * r)
		var c1 := Color(1.0, 0.1, 0.08, 0.5 - 0.03 * (r + 1))
		for k in segs:
			var a: Vector3 = pts[r][k]
			var b: Vector3 = pts[r][k + 1]
			var c: Vector3 = pts[r + 1][k]
			var d: Vector3 = pts[r + 1][k + 1]
			for v in [[a, c0], [c, c1], [d, c1], [a, c0], [d, c1], [b, c0]]:
				im.surface_set_color(v[1])
				im.surface_add_vertex(v[0])
	im.surface_end()
	# 邊框：外緣弧線和兩條側邊，用細長條畫，遠看也清楚
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var edge := Color(1.0, 0.2, 0.15, 0.95)
	var border := []
	for r in rings + 1:
		border.append(pts[r][0])
	for k in range(1, segs + 1):
		border.append(pts[rings][k])
	for r in range(rings - 1, -1, -1):
		border.append(pts[r][segs])
	for i in border.size() - 1:
		var p0: Vector3 = border[i]
		var p1: Vector3 = border[i + 1]
		var side := (p1 - p0).cross(Vector3.UP).normalized() * 0.07
		for v in [p0 - side, p0 + side, p1 + side, p0 - side, p1 + side, p1 - side]:
			im.surface_set_color(edge)
			im.surface_add_vertex(v + Vector3(0, 0.02, 0))
	im.surface_end()

# ================================================================== 家豪（每關都一樣）

## 家豪要去打的敵人：最近的那個；target_last 的敵人等其他人都倒了才打
func nearest_enemy(from: Vector3) -> Fighter:
	var best: Fighter = null
	var bd := INF
	var others := enemies.any(func(f): return f.alive() and not f.target_last)
	for f in enemies:
		if f.alive() and (not f.target_last or not others):
			var d := flat_dist(from, f.pos)
			if d < bd:
				bd = d
				best = f
	return best

func _nearest_feed(from: Vector3, within: float) -> int:
	var best := -1
	var bd := within
	for i in feeds.size():
		var d := flat_dist(from, feeds[i].pos)
		if d < bd:
			bd = d
			best = i
	return best

func _tick_bird(dt: float) -> void:
	var b := bird
	b.t += dt
	if b.state != "fly":
		_apply_knockback(b, dt)
	var tgt := nearest_enemy(b.pos)
	b.target = tgt
	if tgt == null:
		return
	var dist := flat_dist(b.pos, tgt.pos)
	# 飼料優先：不在出招、挨打、飛行中時，聞到飼料就跑去吃
	if b.state in ["charge", "return", "feed", "linger"]:
		var fi := _nearest_feed(b.pos, FEED_SENSE)
		if fi >= 0:
			if b.state != "feed":
				log_event("家豪看到飼料，跑去吃")
			b.feed_target = fi
			b.state = "feed"
	match b.state:
		"charge":
			_bird_walk(tgt.pos, b.speed * (1.35 if tgt.state == "down" else 1.0), dt, "charge")
			if dist <= b.reach:
				b.set_state("windup")
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
				var fi := _nearest_feed(b.pos, 0.8)
				if fi >= 0:
					(feeds[fi].node as Node3D).queue_free()
					feeds.remove_at(fi)
					b.hp = minf(b.hp + FEED_HEAL, b.max_hp)
					log_event("家豪吃掉一把飼料（回到 %d）" % ceili(b.hp))
				b.set_state("linger")
		"linger":
			# 吃飽了在原地東張西望、啄啄地，過一會兒才想起來要打敵人
			if b.t >= FEED_LINGER:
				b.set_state("charge")
		"slip":
			# 自己也踩到香蕉皮，四腳朝天躺一陣子
			if b.t >= SLIP_TIME:
				b.set_state("charge")
		"windup":
			_face(b, tgt.pos)
			if b.t >= b.windup:
				if dist <= b.reach + 0.35 and tgt.alive():
					if not tgt.aggro and not tgt.immune_peck:
						_sneak(tgt)
					else:
						_hit_enemy(tgt, PECK_DAMAGE, b.pos)
				b.set_state("recover")
		"recover":
			if b.t >= b.recover:
				b.set_state("windup" if dist <= b.reach else "charge")
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
				if b.after_fly == "land":
					b.set_state("land")
				else:
					b.set_state(b.after_fly)
		"land":
			if b.t > 0.25:
				_face(b, tgt.pos)
			if b.t >= 0.7:
				b.set_state("return")
				log_event("家豪落地站穩，找路繞回來")
		"return":
			_bird_walk(tgt.pos, b.speed * 0.75, dt, "return")
			if _farmer_open(tgt) and dist < 6.5:
				log_event("家豪看到%s的破綻，提前反擊" % tgt.name)
				b.set_state("charge")
			elif dist <= tgt.reach + 0.5:
				b.set_state("charge")

## 雞走路：遇到圍欄就拍翅小跳過去
func _bird_walk(target: Vector3, spd: float, dt: float, resume: String) -> void:
	var b := bird
	# 牆擋住：繞到門口再進去（牆飛不過去）
	target = world.route_point(b.pos, target)
	var wseg: Variant = _blocking_wall(b.pos, target)
	if wseg != null:
		target = _detour(b.pos, target, wseg)
	var d := target - b.pos
	d.y = 0.0
	if d.length() < 0.001:
		return
	b.yaw = atan2(d.x, d.z)
	var stp := d.normalized() * minf(spd * dt, d.length())
	var nxt := b.pos + stp
	# 前面是水：拍翅飛過去（目標在小島上就直接飛到小島）
	if world.in_water(nxt.x, nxt.z) or world.in_water(b.pos.x + d.normalized().x * 0.6, b.pos.z + d.normalized().z * 0.6):
		var dest := target
		if not world.on_island(target.x, target.z):
			dest = b.pos
			for k in 60:
				dest += d.normalized() * 0.25
				if not world.in_water(dest.x, dest.z) and flat_dist(dest, b.pos) > 1.0:
					break
			dest += d.normalized() * 0.4
		_start_fly(dest, HOP_TIME + 0.3, 1.4, resume)
		return
	var cross: Variant = fence_crossing(b.pos, nxt + d.normalized() * 0.6, false)
	if cross != null:
		var over: Vector3 = cross + d.normalized() * 1.4
		_start_fly(over, HOP_TIME, 1.2, resume)
		return
	var moved: Vector3 = world.clamp_play(_avoid(b.pos, nxt, 0.35))
	if wall_crossing(b.pos, moved) == null:
		b.pos = ground(moved)

## 家豪拍翅飛到 to（after = 落地後要做什麼，"land" = 站穩再找路回來）
func start_fly(to: Vector3, dur: float, peak: float, after: String) -> void:
	_start_fly(to, dur, peak, after)

func _start_fly(to: Vector3, dur: float, peak: float, after: String) -> void:
	var b := bird
	b.fly_from = b.pos
	var dest: Vector3 = world.clamp_play(to)
	var wc: Variant = wall_crossing(b.pos, dest)
	if wc != null:
		var back := (dest - b.pos)
		back.y = 0.0
		dest = (wc as Vector3) - back.normalized() * 0.8
	if world.in_water(dest.x, dest.z):
		dest = _dry_landing(dest)   # 別降落在水裡
	b.fly_to = ground(dest)
	b.fly_dur = dur
	b.fly_peak = peak
	b.after_fly = after
	b.kb_vel = Vector3.ZERO
	b.set_state("fly")

## 家豪挨打（by = 誰打的，可以是 null）
func hit_bird(dmg: float, heavy: bool, from: Vector3, by: Fighter = null) -> void:
	var b := bird
	var before := b.hp
	b.hp = maxf(b.hp - dmg, 0.0)
	hit_spots.append(b.pos)
	noise_at(b.pos)
	if by:
		log_event("%s%s踢中家豪（剩 %d）" % [by.name, "重" if heavy else "", ceili(b.hp)])
	var away := b.pos - from
	away.y = 0.0
	away = away.normalized() if away.length() > 0.01 else Vector3.BACK
	if b.hp <= 0.0:
		b.set_state("dead")
		b.kb_vel = away * 3.0
		return
	var first_half := not b.fled_half and before > b.max_hp * 0.5 and b.hp <= b.max_hp * 0.5
	if heavy or first_half:
		if first_half:
			b.fled_half = true
		var target := b.pos + away * 5.0
		var fp: Variant = _closest_fence_point(b.pos)
		if fp != null and flat_dist(fp, b.pos) < 6.5:
			var n := _fence_normal_away(fp, b.pos)
			if n.dot(away) > -0.2:
				target = fp + n * 2.4
				log_event("家豪%s，拍翅飛過圍欄撤退" % ("被重踢" if heavy else "掉到半血"))
			else:
				log_event("家豪%s，拍翅飛開撤退" % ("被重踢" if heavy else "掉到半血"))
		else:
			log_event("家豪%s，拍翅飛開撤退" % ("被重踢" if heavy else "掉到半血"))
		_start_fly(target, FLY_TIME, FLY_PEAK, "land")
		for f in enemies:
			if f.aggro:
				f.chased = true
	else:
		b.set_state("hop")
		b.kb_vel = away * 0.5 / 0.25

## 偷襲：敵人還沒發現家豪就被啄，會嚇一跳愣住
func _sneak(f: Fighter) -> void:
	f.hp = maxf(f.hp - PECK_DAMAGE * SNEAK_MULT, 0.0)
	hit_spots.append(f.pos)
	log_event("家豪偷襲%s！（剩 %d）" % [f.name, ceili(f.hp)])
	toast("偷襲！", 1.2)
	noise_at(f.pos)
	f.aggro = true
	f.alert_t = -1.0
	if f.hp <= 0.0:
		f.set_state("dead")
		anim(f, "Death")
		log_event("%s倒下了" % f.name)
		return
	f.heavy = false
	f.set_state("startled")
	f.yaw = _yaw_to(f.pos, bird.pos)
	anim(f, "HitRecieve", 0.8)

func _hit_enemy(f: Fighter, dmg: float, from: Vector3) -> void:
	if f.immune_peck:
		log_event("家豪的啄對%s完全沒用" % f.name)
		return
	f.hp = maxf(f.hp - dmg, 0.0)
	hit_spots.append(f.pos)
	noise_at(f.pos)
	log_event("家豪啄中%s（剩 %d）" % [f.name, ceili(f.hp)])
	aggro(f)
	var away := f.pos - from
	away.y = 0.0
	away = away.normalized() if away.length() > 0.01 else Vector3.FORWARD
	if f.hp <= 0.0:
		f.set_state("dead")
		f.kb_vel = away * 2.0
		anim(f, "Death")
		log_event("%s倒下了" % f.name)
		return
	if f.state == "down":
		return
	if f.state == "windup" and f.heavy:
		return
	f.heavy = false
	f.set_state("stagger")
	f.kb_vel = away
	anim(f, "HitRecieve", 1.4)

## 直接打倒一個敵人（關卡機關用，例如被東西壓到）
func knock_out(f: Fighter, why := "") -> void:
	if not f.alive():
		return
	f.hp = 0.0
	f.set_state("dead")
	anim(f, "Death")
	if why != "":
		log_event(why)

# ================================================================== 圍欄與障礙
# 場地（world）提供：fence_segments（矮圍欄，家豪飛得過去、敵人要繞）、
# wall_segments（牆，誰都過不去）、obstacles（[[中心 Vector2, 半徑], ...] 建築和樹）

func _seg_hit(p1: Vector2, p2: Vector2, q1: Vector2, q2: Vector2) -> float:
	## 回傳 p1→p2 上的交點參數 t（0~1），沒交到回傳 -1
	var r := p2 - p1
	var s := q2 - q1
	var den := r.cross(s)
	if absf(den) < 1e-6:
		return -1.0
	var t := (q1 - p1).cross(s) / den
	var u := (q1 - p1).cross(r) / den
	if t >= 0.0 and t <= 1.0 and u >= 0.0 and u <= 1.0:
		return t
	return -1.0

## 會擋路的線段：矮圍欄 + 牆（walls=false 時只算矮圍欄）
func _segments(walls := true) -> Array:
	return world.fence_segments + world.wall_segments if walls else world.fence_segments

func wall_crossing(from: Vector3, to: Vector3) -> Variant:
	var a := Vector2(from.x, from.z)
	var b := Vector2(to.x, to.z)
	var best := 2.0
	for seg in world.wall_segments:
		var t := _seg_hit(a, b, seg[0], seg[1])
		if t >= 0.0 and t < best:
			best = t
	if best > 1.0:
		return null
	var p := a.lerp(b, best)
	return Vector3(p.x, 0, p.y)

func _blocking_wall(from: Vector3, to: Vector3) -> Variant:
	var a := Vector2(from.x, from.z)
	var b := Vector2(to.x, to.z)
	var best := 2.0
	var found: Variant = null
	for seg in world.wall_segments:
		var d: Vector2 = (seg[1] - seg[0]).normalized()
		var t := _seg_hit(a, b, seg[0] - d * 0.3, seg[1] + d * 0.3)
		if t >= 0.0 and t < best:
			best = t
			found = seg
	return found

func fence_crossing(from: Vector3, to: Vector3, walls := true) -> Variant:
	var a := Vector2(from.x, from.z)
	var b := Vector2(to.x, to.z)
	var best := 2.0
	for seg in _segments(walls):
		var t := _seg_hit(a, b, seg[0], seg[1])
		if t >= 0.0 and t < best:
			best = t
	if best > 1.0:
		return null
	var p := a.lerp(b, best)
	return Vector3(p.x, 0, p.y)

func _blocking_segment(from: Vector3, to: Vector3) -> Variant:
	var a := Vector2(from.x, from.z)
	var b := Vector2(to.x, to.z)
	var best := 2.0
	var found: Variant = null
	for seg in _segments():
		var d: Vector2 = (seg[1] - seg[0]).normalized()
		var t := _seg_hit(a, b, seg[0] - d * 0.3, seg[1] + d * 0.3)
		if t >= 0.0 and t < best:
			best = t
			found = seg
	return found

func _closest_fence_point(p: Vector3) -> Variant:
	var q := Vector2(p.x, p.z)
	var best: Variant = null
	var bd := INF
	for seg in world.fence_segments:
		var a: Vector2 = seg[0]
		var b: Vector2 = seg[1]
		var t := clampf((q - a).dot(b - a) / (b - a).length_squared(), 0.05, 0.95)
		var c := a.lerp(b, t)
		if q.distance_to(c) < bd:
			bd = q.distance_to(c)
			best = Vector3(c.x, 0, c.y)
	return best

func _fence_normal_away(fp: Vector3, p: Vector3) -> Vector3:
	var d := Vector2(p.x - fp.x, p.z - fp.z)
	if d.length() < 0.01:
		return Vector3.BACK
	return -Vector3(d.x, 0, d.y).normalized()

func _detour(from: Vector3, to: Vector3, seg: Array) -> Vector3:
	var a: Vector2 = seg[0]
	var b: Vector2 = seg[1]
	var d := (b - a).normalized()
	var ends := [a - d * FENCE_CLEAR, b + d * FENCE_CLEAR]
	var p := Vector2(from.x, from.z)
	var q := Vector2(to.x, to.z)
	var best: Vector2 = ends[0]
	var bl := INF
	for e in ends:
		var l: float = p.distance_to(e) + e.distance_to(q)
		if l < bl:
			bl = l
			best = e
	return Vector3(best.x, 0, best.y)

## 避開建築和樹：要走進去時沿著邊緣滑開
func _avoid(from: Vector3, to: Vector3, pad: float) -> Vector3:
	var p := Vector2(to.x, to.z)
	for o in world.obstacles:
		var c: Vector2 = o[0]
		var r: float = o[1] + pad
		var d := p - c
		if d.length() < r:
			p = c + d.normalized() * r
	return Vector3(p.x, to.y, p.y)

func hits_obstacle(p: Vector2) -> bool:
	for o in world.obstacles:
		var c: Vector2 = o[0]
		if p.distance_to(c) < o[1] + 0.2:
			return true
	return false

# ================================================================== 小工具（關卡和道具都可以用）

func all_fighters() -> Array:
	return [bird] + enemies

func ground(p: Vector3) -> Vector3:
	return Vector3(p.x, world.height_at(p.x, p.z), p.z)

func flat_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

## 這個角色這一步走了多遠（判斷有沒有在走路）
func moved_this_step(f: Fighter) -> float:
	return flat_dist(_step_start.get(f, f.pos), f.pos)

func _yaw_to(from: Vector3, to: Vector3) -> float:
	return atan2(to.x - from.x, to.z - from.z)

func _face(f: Fighter, target: Vector3) -> void:
	f.yaw = _yaw_to(f.pos, target)

## 敵人走路：直線被圍欄擋住就走到欄的端點繞過去，也會避開建築
func _walk(f: Fighter, target: Vector3, spd: float, dt: float) -> void:
	var goal: Vector3 = world.route_point(f.pos, target)
	var seg: Variant = _blocking_segment(f.pos, goal)
	f.detouring = seg != null
	if f.detouring:
		goal = _detour(f.pos, goal, seg)
	var d := goal - f.pos
	d.y = 0.0
	if d.length() < 0.001:
		return
	f.yaw = atan2(d.x, d.z)
	var nxt := f.pos + d.normalized() * minf(spd * dt, d.length())
	nxt = world.clamp_play(_avoid(f.pos, nxt, 0.5))
	if fence_crossing(f.pos, nxt) == null:
		f.pos = ground(nxt)

func _apply_knockback(f: Fighter, dt: float) -> void:
	if f.kb_vel.length() < 0.01:
		f.kb_vel = Vector3.ZERO
		return
	var nxt := f.pos + f.kb_vel * dt
	if fence_crossing(f.pos, nxt) != null:
		f.kb_vel = Vector3.ZERO
	else:
		f.pos = ground(world.clamp_play(_avoid(f.pos, nxt, 0.4)))
	f.kb_vel = f.kb_vel.move_toward(Vector3.ZERO, 9.0 * dt)

func anim(f: Fighter, name: String, speed := 1.0) -> void:
	if f.anim and f.anim.has_animation(name):
		if f.anim.current_animation != name or not f.anim.is_playing() or name in ["Kick_Right", "Kick_Left", "HitRecieve"]:
			f.anim.play(name, 0.15, speed)

## 記一筆戰鬥紀錄（自動測試會讀）
func log_event(text: String) -> void:
	events.append({"t": snappedf(time, 0.001), "text": text})

## 畫面中間跳一行黃字
func toast(text: String, dur: float) -> void:
	_toast_label.text = text
	_toast_label.visible = text != ""     # 沒字時連膠囊底一起收起來
	_toast_t = dur

## 下方對話框（左邊是家豪的頭像，pic 是右邊額外的圖）
func say(text: String, pic: Texture2D = null) -> void:
	if _dialog:
		_dialog.say(text, pic)

## 讀圖：有匯入過就用匯入的資源，沒有就直接讀 PNG
func _load_tex(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	return ImageTexture.create_from_image(img) if img else null

# ================================================================== 畫面表現

func _apply_visuals() -> void:
	for f in all_fighters():
		f.node.global_position = f.pos + Vector3(0, f.air, 0)
		f.node.rotation = Vector3(0, f.yaw, 0)
	_level_visuals()
	_bird_pose()

func _bird_pose() -> void:
	var b := bird
	if b.body == null:
		return
	var rx := 0.0
	var rz := 0.0
	var sq := Vector3.ONE
	var lift := 0.0
	var flap := 0.12 * sin(time * 3.0)
	match b.state:
		"windup":
			var k := clampf(b.t / b.windup, 0.0, 1.0)
			rx = lerpf(-0.25, 0.7, k * k)
			sq = Vector3(1.0, 1.0 - 0.1 * k, 1.0 + 0.1 * k)
		"recover":
			rx = lerpf(0.7, 0.0, clampf(b.t / 0.25, 0.0, 1.0))
		"hop":
			var k := clampf(b.t / 0.4, 0.0, 1.0)
			rx = -0.35 * (1.0 - k)
			lift = sin(k * PI) * 0.12
			sq = Vector3(1.0 + 0.12 * (1.0 - k), 1.0 - 0.15 * (1.0 - k), 1.0)
			flap = 0.5 * (1.0 - k)
		"fly":
			var k := clampf(b.t / b.fly_dur, 0.0, 1.0)
			rx = -0.35 + 0.5 * k
			flap = 0.35 + 0.9 * absf(sin(b.t * 26.0))
		"land":
			var k := clampf(b.t / 0.7, 0.0, 1.0)
			var bounce := exp(-k * 5.0)
			sq = Vector3(1.0 + 0.3 * bounce, 1.0 - 0.35 * bounce, 1.0 + 0.2 * bounce)
			rz = sin(b.t * 18.0) * 0.2 * bounce
			flap = 0.8 * bounce
		"charge", "feed":
			lift = absf(sin(time * 12.0)) * 0.08
			rx = 0.2
			flap = 0.25
		"eat":
			# 低頭猛啄地上的飼料
			rx = 0.55 + 0.35 * absf(sin(b.t * 16.0))
			flap = 0.1
		"return":
			lift = absf(sin(time * 9.0)) * 0.04
		"slip":
			# 側躺在地上，翅膀偶爾抽一下
			var k := clampf(b.t / 0.25, 0.0, 1.0)
			rz = 1.45 * k
			rx = -0.2 * k
			flap = 0.3 * absf(sin(b.t * 7.0)) * float(b.t < SLIP_TIME - 0.5)
		"linger":
			# 慢慢左右張望，偶爾低頭啄一下
			rz = sin(b.t * 2.2) * 0.12
			rx = 0.45 if fmod(b.t, 1.1) < 0.25 else 0.05
			flap = 0.05
		"dead":
			rz = minf(b.t * 6.0, 1.0) * 1.5
		"cheer":
			lift = absf(sin(b.t * 9.0)) * 0.35
			rx = -0.3
			flap = 0.4 + 0.8 * absf(sin(b.t * 9.0))
	b.body.rotation = Vector3(rx, 0, rz)
	b.body.scale = sq
	b.body.set_meta("posed", lift > 0.0)
	if lift > 0.0:
		b.body.position.y = lift
	for w in b.wings:
		var sx := -1.0 if w.name == "WingL" else 1.0
		w.rotation = Vector3(0, 0, sx * flap)

# ================================================================== HUD
# 手帳風格（scripts/ui/ui_style.gd）：米色紙片、便利貼、鍵帽。平常畫面上只留四樣東西：
#   左上「?」（按 H 看操作）、右上敵人名單、下方道具格、右下「開始 ▶」；其他都是需要時才出現。

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	_hud_layer = layer

	# 頭上的血條（主角綠色、敵人紅色）
	for f in all_fighters():
		var bar := Control.new()
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.size = Vector2(96, 12)
		var bg := ColorRect.new()
		bg.color = Color(UIStyle.INK, 0.85)
		bg.size = Vector2(96, 12)
		bar.add_child(bg)
		var chip := ColorRect.new()
		chip.color = Color(1.0, 0.92, 0.8, 0.9)
		chip.position = Vector2(2, 2)
		chip.size = Vector2(92, 8)
		bar.add_child(chip)
		var fill := ColorRect.new()
		fill.color = Color(0.3, 0.82, 0.32) if f.is_bird else Color(0.89, 0.28, 0.24)
		fill.position = Vector2(2, 2)
		fill.size = Vector2(92, 8)
		bar.add_child(fill)
		layer.add_child(bar)
		f.bar = bar
		f.bar_fill = fill
		f.bar_chip = chip

	# 道具欄：畫面下方一排紙卡
	_hotbar = Hotbar.new()
	UIStyle.apply_theme(_hotbar)
	_hotbar.skills = items
	_hotbar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hb := _hotbar.bar_size()
	_hotbar.custom_minimum_size = hb
	_hotbar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hotbar.offset_left = -hb.x * 0.5
	_hotbar.offset_right = hb.x * 0.5
	_hotbar.offset_top = -hb.y - 22
	_hotbar.offset_bottom = -22
	layer.add_child(_hotbar)
	# 對話框：放在快捷欄上方
	_dialog = DialogBox.new()
	UIStyle.apply_theme(_dialog)
	_dialog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dialog.visible = false
	_dialog.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_dialog.offset_left = -400
	_dialog.offset_right = 400
	_dialog.offset_top = -hb.y - 22 - 20 - DialogBox.H
	_dialog.offset_bottom = -hb.y - 22 - 20
	layer.add_child(_dialog)
	_dialog.portrait = _load_tex("res://assets/ui/jiahao_portrait.png")
	# 開場教學：箭頭指著道具格，上面一張便利貼（限制寬度、自動換行），右下角小字是第幾張
	_tut_arrow = TutArrow.new()
	_tut_arrow.size = Vector2(70, 120)
	_tut_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tut_arrow.visible = false
	layer.add_child(_tut_arrow)
	_tut_panel = PanelContainer.new()
	UIStyle.sticky(_tut_panel, 0.0)
	_tut_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tut_panel.visible = false
	var tut_box := VBoxContainer.new()
	tut_box.add_theme_constant_override("separation", 2)
	_tut_panel.add_child(tut_box)
	_tut_label = Label.new()
	var tls := UIStyle.ls(21, UIStyle.INK)
	tls.line_spacing = 6
	_tut_label.label_settings = tls
	_tut_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tut_label.custom_minimum_size = Vector2(TUT_WIDTH, 0)
	tut_box.add_child(_tut_label)
	_tut_page = Label.new()
	_tut_page.label_settings = UIStyle.ls(15, Color(UIStyle.INK, 0.55))
	_tut_page.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tut_box.add_child(_tut_page)
	layer.add_child(_tut_panel)

	# 右上角敵人名單：一張米色小紙片，一列一個敵人（小頭像＋名字＋血條），Boss 排最上面
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 7)
	col.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	col.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	col.offset_right = -32
	col.offset_top = 28
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(col)
	# 紙片直接畫在這個直排後面（不多包一層，關卡要收起名單時只要隱藏這個直排）
	var card := UIStyle.slip_box(Vector2(12, 10))
	col.draw.connect(func():
		if col.get_child_count() > 0:
			col.draw_style_box(card, Rect2(Vector2(-12, -10), col.size + Vector2(24, 20))))
	var order: Array = enemies.filter(func(f): return f.is_boss) + enemies.filter(func(f): return not f.is_boss)
	var ns := UIStyle.ls(15, UIStyle.INK)
	for f in order:
		var erow := HBoxContainer.new()
		erow.add_theme_constant_override("separation", 8)
		erow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(erow)
		var face := EnemyFace.new()
		face.boss = f.face == "boss"
		face.portrait = f.portrait
		face.custom_minimum_size = Vector2(36, 36)   # 大小都一樣，名字才會對齊；Boss 用金色邊框和比較長的血條區分
		face.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		erow.add_child(face)
		var info := VBoxContainer.new()
		info.alignment = BoxContainer.ALIGNMENT_CENTER
		info.add_theme_constant_override("separation", 1)
		info.mouse_filter = Control.MOUSE_FILTER_IGNORE
		erow.add_child(info)
		var nm := Label.new()
		nm.text = f.hud_name if f.hud_name != "" else f.name
		nm.label_settings = ns
		info.add_child(nm)
		var bar := Control.new()
		bar.custom_minimum_size = Vector2(124 if f.is_boss else 104, 10)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		info.add_child(bar)
		var bg := ColorRect.new()
		bg.color = Color(UIStyle.INK, 0.85)
		bg.size = bar.custom_minimum_size
		bar.add_child(bg)
		var chip := ColorRect.new()
		chip.color = Color(1.0, 0.92, 0.8, 0.9)
		chip.position = Vector2(2, 2)
		chip.size = bar.custom_minimum_size - Vector2(4, 4)
		bar.add_child(chip)
		var fill := ColorRect.new()
		fill.color = Color(0.89, 0.28, 0.24)
		fill.position = Vector2(2, 2)
		fill.size = bar.custom_minimum_size - Vector2(4, 4)
		bar.add_child(fill)
		_enemy_rows.append({"fighter": f, "face": face, "fill": fill, "chip": chip, "width": bar.custom_minimum_size.x - 4.0})

	# 上方中間的小紙片：準備時是關卡的一句提示（沒有就不出現），開打後是計時
	_phase_label = Label.new()
	_phase_label.label_settings = UIStyle.ls(20)
	_phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_phase_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_phase_label.offset_top = 18
	_phase_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	UIStyle.slip(_phase_label)
	layer.add_child(_phase_label)

	var ts := UIStyle.ls(28)
	_toast_label = Label.new()
	_toast_label.label_settings = ts
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_toast_label.offset_top = -140
	_toast_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	UIStyle.pill(_toast_label)            # 字卡＝米白膠囊
	layer.add_child(_toast_label)

	# 結算＝筆記紙：一行標題、歷次嘗試、按鈕列
	_summary_panel = PanelContainer.new()
	UIStyle.paper(_summary_panel, 0.01)
	_summary_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_summary_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_summary_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_summary_box = VBoxContainer.new()
	_summary_box.add_theme_constant_override("separation", 12)
	_summary_box.visible = false
	_summary_panel.add_child(_summary_box)
	_summary_title = Label.new()
	_summary_title.label_settings = UIStyle.ls(30, UIStyle.INK)
	_summary_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_summary_box.add_child(_summary_title)
	var ss := UIStyle.ls(19, Color(UIStyle.INK, 0.72))
	ss.line_spacing = 4
	_summary_label = Label.new()
	_summary_label.label_settings = ss
	_summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_summary_box.add_child(_summary_label)
	_summary_keys = HBoxContainer.new()
	_summary_keys.alignment = BoxContainer.ALIGNMENT_CENTER
	_summary_box.add_child(_summary_keys)
	layer.add_child(_summary_panel)
	_hud_build_buttons(layer)

## 預設的小按鈕：右下「開始 ▶ [Enter]」、開打後換成「[R] 重試」、左上「? [H]」和按 H 才出現的操作說明卡。
## 一開始都收著，_update_phase_label() 才會把它們打開
func _hud_build_buttons(layer: CanvasLayer) -> void:
	var sbx := HBoxContainer.new()
	sbx.add_theme_constant_override("separation", 10)
	sbx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sbx.add_child(UIStyle.go_button("開始 ▶", 30))
	sbx.add_child(UIStyle.keycap("Enter", 22))
	layer.add_child(sbx)
	sbx.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	sbx.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	sbx.grow_vertical = Control.GROW_DIRECTION_BEGIN
	sbx.offset_right = -36
	sbx.offset_bottom = -40
	sbx.visible = false
	_hud_start = sbx
	var rbx := PanelContainer.new()
	UIStyle.slip(rbx, Vector2(12, 7))
	rbx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rbx.add_child(UIStyle.key_hint("R", "重試", 18))
	layer.add_child(rbx)
	rbx.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	rbx.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	rbx.grow_vertical = Control.GROW_DIRECTION_BEGIN
	rbx.offset_right = -36
	rbx.offset_bottom = -40
	rbx.visible = false
	_hud_retry = rbx
	var chip := PanelContainer.new()
	UIStyle.slip(chip, Vector2(10, 6))
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var crow := HBoxContainer.new()
	crow.add_theme_constant_override("separation", 8)
	chip.add_child(crow)
	var q := Label.new()
	q.text = "?"
	q.label_settings = UIStyle.ls(22, UIStyle.INK)
	crow.add_child(q)
	crow.add_child(UIStyle.keycap("H", 16))
	chip.position = Vector2(24, 20)
	chip.visible = false
	layer.add_child(chip)
	_hud_help_chip = chip
	_hud_help_card = PanelContainer.new()
	UIStyle.paper(_hud_help_card, 0.0)
	_hud_help_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_help_card.position = Vector2(24, 78)
	_hud_help_card.visible = false
	layer.add_child(_hud_help_card)

## 操作說明卡要列的東西（_help_rows() 整理過的版本；暫停選單也用這一份）
func help_list() -> Array:
	return _help_rows()

## H：按住的時候顯示操作說明；輕按一下是釘住／收起來
func _hud_tick_help() -> void:
	var down := Input.is_physical_key_pressed(KEY_H)
	var now := Time.get_ticks_msec()
	if down and not _hud_help_down:
		_hud_help_ms = now
		_hud_help_pin = not _hud_help_pin
	elif not down and _hud_help_down and now - _hud_help_ms > 350:
		_hud_help_pin = false
	_hud_help_down = down
	var on := (_hud_help_pin or down) and not defeat_shown
	if on:
		var rows := help_list()
		var key := str(rows)
		if key != _hud_help_key:
			_hud_help_key = key
			for c in _hud_help_card.get_children():
				if c is GridContainer:
					c.queue_free()
			_hud_help_card.add_child(UIStyle.key_grid(rows, 2, 16))
			_hud_help_card.reset_size()
	_hud_help_card.visible = on

## 結算／失敗卡片底下那一排：綠色主要按鈕＋它的鍵帽，後面接其他「鍵帽＋說明」
func _hud_button_row(row: HBoxContainer, go_text: String, go_key: String, others: Array) -> void:
	for c in row.get_children():
		row.remove_child(c)
		c.queue_free()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	row.add_child(UIStyle.go_button(go_text, 26))
	row.add_child(UIStyle.keycap(go_key, 18))
	for o in others:
		var gap := Control.new()
		gap.custom_minimum_size = Vector2(12, 0)
		row.add_child(gap)
		row.add_child(UIStyle.key_hint(String(o[0]), String(o[1]), 18))

## 卡片內容換過之後：縮回內容的大小，再照 preset 擺回去（off 是離那個位置多遠）
func _hud_place(card: Control, preset: int, off := Vector2.ZERO) -> void:
	card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	card.grow_vertical = Control.GROW_DIRECTION_BOTH
	card.reset_size()
	card.set_anchors_and_offsets_preset(preset, Control.PRESET_MODE_MINSIZE)
	card.position += off

func _refresh_slots() -> void:
	if _hotbar == null:
		return
	if _hotbar.selected != selected:
		_hotbar.name_t = 2.0
	_hotbar.counts = charges.duplicate()
	_hotbar.cooldowns = cooldowns.duplicate()
	_hotbar.selected = selected
	_hotbar.queue_redraw()

func _update_bars(dt: float) -> void:
	for f in all_fighters():
		var head: Vector3 = f.pos + Vector3(0, f.air + f.bar_y, 0)
		var show: bool = not camera.is_position_behind(head) and (f.alive() or phase == Phase.ENDED)
		f.bar.visible = show
		if not show:
			continue
		f.bar.position = camera.unproject_position(head) - f.bar.size * 0.5
		var r: float = f.ratio()
		f.chip = maxf(r, f.chip - dt * 0.6) if f.chip > r else r
		f.bar_fill.size.x = 92.0 * r
		f.bar_chip.size.x = 92.0 * f.chip

## 關卡的 _prepare_hint() 以前都寫成「準備中：……　按 Enter 開始」；頭尾現在由右下角的開始鈕負責，只留中間那句
static func _hint_core(t: String) -> String:
	var trim := " 　｜|：:"
	var s := t.strip_edges().lstrip(trim).rstrip(trim)
	for tail in ["按 Enter 開始", "Enter 開始"]:
		if s.ends_with(tail):
			s = s.substr(0, s.length() - tail.length()).rstrip(trim)
	if s.begins_with("準備中"):
		s = s.substr(3).lstrip(trim)
	return s

## 上方的小紙片（準備時的提示／開打後的計時），順便開關預設的「開始 ▶」「R 重試」「?」。
## 關卡如果整個覆寫這個函式、不呼叫 super()（例如冰雪島自己畫開始鈕），預設的那幾個就不會出現。
func _update_phase_label() -> void:
	_hud_default = true
	match phase:
		Phase.PREPARE:
			_phase_label.text = _hint_core(_prepare_hint())
		Phase.RUNNING:
			_phase_label.text = "%.1f 秒" % time
		Phase.ENDED:
			_phase_label.text = "" if outcome == "win" else "落敗…"
	_phase_label.visible = _phase_label.text != ""
	_hud_start.visible = phase == Phase.PREPARE
	_hud_retry.visible = phase == Phase.RUNNING
	_hud_help_chip.visible = true

func _show_summary() -> void:
	var win := outcome == "win"
	_summary_title.text = _win_line() if win else _lose_line(enemies_left())
	var lines: PackedStringArray = []
	for a in attempts.slice(maxi(attempts.size() - 5, 0)):
		lines.append("第 %d 次　%s　%.1f 秒" % [a.num, "過關" if a.outcome == "win" else "失敗（剩 %d 個敵人）" % a.left, a.time])
	_summary_label.text = "\n".join(lines)
	if win:
		_hud_button_row(_summary_keys, "回地圖 ▶", "M", [["R", "重試"]])
	else:
		_hud_button_row(_summary_keys, "重試 ▶", "R", [["M", "地圖"]])
	_summary_box.visible = true
	_summary_panel.visible = true
	_hud_place(_summary_panel, Control.PRESET_CENTER)

# ================================================================== 輸了的畫面

func _build_defeat() -> void:
	defeat_room = Node3D.new()
	defeat_room.name = "DefeatRoom"
	defeat_room.set_script(load("res://scripts/defeat_room.gd"))
	world.add_child(defeat_room)
	defeat_room.global_position = DEFEAT_ORIGIN
	defeat_room.build(chars)
	defeat_room.visible = false
	_defeat_layer = CanvasLayer.new()
	_defeat_layer.layer = 6
	_defeat_layer.visible = false
	add_child(_defeat_layer)
	# 下方一張筆記紙：標題、這一次的結果和提示、按鈕列（跟結算卡同一套）
	var band := PanelContainer.new()
	UIStyle.paper(band, -0.01)
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_defeat_layer.add_child(band)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	band.add_child(box)
	_defeat_label = Label.new()
	_defeat_label.label_settings = UIStyle.ls(32, UIStyle.INK)
	_defeat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_defeat_label)
	var small := UIStyle.ls(19, Color(UIStyle.INK, 0.72))
	small.line_spacing = 4
	_defeat_detail = Label.new()
	_defeat_detail.label_settings = small
	_defeat_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_defeat_detail)
	var keys := HBoxContainer.new()
	box.add_child(keys)
	_hud_button_row(keys, "重試 ▶", "R", [["M", "地圖"]])

func _show_defeat() -> void:
	defeat_shown = true
	defeat_room.visible = true
	defeat_room.cam.current = true
	_hud_layer.visible = false
	var main_hud := get_node_or_null("../HUD")
	if main_hud:
		main_hud.visible = false
	_preview.visible = false
	_defeat_label.text = _defeat_title()
	_defeat_detail.text = "第 %d 次嘗試　·　撐了 %.1f 秒　·　還剩 %d 個敵人\n%s" % [attempts.size(), time, enemies_left(), _defeat_tip()]
	_defeat_layer.visible = true
	_hud_place(_defeat_label.get_parent().get_parent() as Control, Control.PRESET_CENTER_BOTTOM, Vector2(0, -44))

func _hide_defeat() -> void:
	_defeat_delay = -1.0
	if not defeat_shown and defeat_room and not defeat_room.visible:
		return
	defeat_shown = false
	defeat_room.visible = false
	camera.current = true
	_hud_layer.visible = true
	var main_hud := get_node_or_null("../HUD")
	if main_hud:
		main_hud.visible = true
	_defeat_layer.visible = false

# ================================================================== 開場教學

func start_tutorial() -> void:
	if _tut_seen or items.is_empty():
		return
	_tut_seen = true
	_set_tut_step(0)

func _set_tut_step(i: int) -> void:
	var texts := _tutorial_texts()
	tutorial_step = i
	_tut_t = 0.0
	var on := i >= 0 and i < texts.size()
	_tut_arrow.visible = on
	_tut_panel.visible = on
	if not on:
		tutorial_step = -1
		select_skill(0)
		return
	select_skill(mini(i, items.size() - 1))
	_hotbar.name_t = 0.0   # 教學時說明框已經寫了名字，不用再浮一次
	_tut_label.text = String(texts[i]).replace("\n", "")   # 便利貼自己會換行，不用手動斷行
	_tut_page.text = "%d / %d" % [i + 1, texts.size()]
	_tut_fit()

## 便利貼的高度跟著換行後的行數走（寬度固定 TUT_WIDTH）
func _tut_fit() -> void:
	var f: Font = _tut_label.label_settings.font if _tut_label.label_settings.font else _tut_label.get_theme_default_font()
	var fs: int = _tut_label.label_settings.font_size
	var sz := f.get_multiline_string_size(_tut_label.text, HORIZONTAL_ALIGNMENT_LEFT, TUT_WIDTH, fs, -1,
		TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE)
	var lines := maxi(1, roundi(sz.y / f.get_height(fs)))
	_tut_label.custom_minimum_size = Vector2(TUT_WIDTH, sz.y + (lines - 1) * _tut_label.label_settings.line_spacing)
	_tut_panel.reset_size()

func _tick_tutorial(dt: float) -> void:
	if tutorial_step < 0:
		return
	if phase != Phase.PREPARE:
		_set_tut_step(-1)
		return
	_tut_t += dt
	if _tut_t >= TUT_STEP_TIME:
		_set_tut_step(tutorial_step + 1)
		if tutorial_step < 0:
			return
	# 箭頭對準第 i 格的正上方，輕輕上下跳動；說明框在箭頭上面
	var hb := _hotbar.get_global_rect()
	var cx := hb.position.x + 2.0 + (mini(tutorial_step, items.size() - 1) + 0.5) * Hotbar.S
	var bob := absf(sin(_tut_t * 4.0)) * 10.0
	_tut_arrow.position = Vector2(cx - _tut_arrow.size.x * 0.5, hb.position.y - _tut_arrow.size.y - 14.0 - bob)
	var ps := _tut_panel.size
	var vw := get_viewport().get_visible_rect().size.x
	_tut_panel.position = Vector2(clampf(cx - ps.x * 0.5, 12.0, vw - ps.x - 12.0), _tut_arrow.position.y - ps.y - 10.0 + bob)
