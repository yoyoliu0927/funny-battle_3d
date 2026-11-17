extends "res://scripts/battle/battle_base.gd"
## 島上三個小關共用的戰局底：
##   - 過關之後不跳結算、不問要不要換關：鏡頭飛進下一小關的空地就直接接下去（之後輸了也是從那一關重來）
##   - 「眼睛進落葉」：風把葉子吹進敵人眼睛的那幾秒，他看不見、站在原地揉眼睛（見 items/wind_item.gd）
## 各小關的 battle.gd 覆寫 _next_stage() 回傳下一小關是第幾關（最後一關回傳 0）。

const BLIND_VISION := 0.9        # 看不見的時候，偵測扇形縮到多短
const GodHands := preload("res://levels/liuchiyu/god_hands.gd")

var hands: Node3D                # 神的雙手（第一人稱，掛在鏡頭底下；見 god_hands.gd）

var _leaving := false
var _opened := false
var _base_vision := {}           # 每個敵人原本看多遠（看不見結束後還回去）

func _next_stage() -> int:
	return 0

## 過關之後，現在可不可以去下一關：有設定「家豪要走的路」的關，要等他走完
func _can_leave() -> bool:
	return _crossed or _exit_path().is_empty()

## 過關之後家豪自己走去下一關要走的路（y 是腳要踩的高度）。空的 = 不用走，玩家自己飛過去就接
func _exit_path() -> Array[Vector3]:
	return []

## 路的第一個點之後現在能不能走（例如第一小關要等橋搭好）
func _exit_open() -> bool:
	return true

const EXIT_SPEED := 5.0          # 家豪走去下一關的速度
var _exit_i := 0                 # 走到路上的第幾個點了
var _crossed := false            # 走完了

# ---------------------------------------------------------------- 星星

const STAR_CUT := 2.0            # 拿到星星的小過場多長
const STAR_NEAR := 1.7           # 家豪離星星多近算拿到

var _star_done := false          # 這一小關的星星拿到了
var _star_stage := 0             # 過關後去拿星星：0 還沒去、1 正在走過去、2 拿到了正在走回來、3 結束
var _star_route: Array[Vector3] = []
var _star_i := 0
var _star_fx := -1.0             # 星星飛起來的動畫播了幾秒（< 0 = 沒在播）
var _cut_t := 0.0                # 過場還剩幾秒（> 0 的時候鏡頭被借走）
var _cut_back := Transform3D.IDENTITY
var _cut_head := 0.0
var _star_label: Label
var _foe_dots: HBoxContainer        # 右上角的紅色圓點（敵人還剩幾個）

## 這一小關是第幾關（星星記在第幾關名下）
func _stage_no() -> int:
	return world.stage_index if world and "stage_index" in world else 0

## 這一小關的星星現在拿不拿得到（例如風車的葉片掉下來了、樹橋搭好了）
func _star_ready() -> bool:
	return false

## 星星現在在哪（這一小關的座標，地面的高度）
func _star_pos() -> Vector3:
	return Vector3.ZERO

## 過關之後家豪走去拿星星的路、拿完走回來的路（y 是腳要踩的高度）
func _star_path() -> Array[Vector3]:
	return [_star_pos()]

func _star_back() -> Array[Vector3]:
	return []

## 把家豪往 target 走一步（prev 是上一個路點，用來算腳踩的高度）。回傳 true = 走到了
func _move_bird(target: Vector3, prev: Vector3, dt: float) -> bool:
	var to := Vector2(target.x - bird.pos.x, target.z - bird.pos.z)
	var step := EXIT_SPEED * dt
	var reached := to.length() <= step
	if reached:
		bird.pos = Vector3(target.x, 0.0, target.z)
	else:
		var d := to.normalized()
		bird.pos += Vector3(d.x, 0.0, d.y) * step
		bird.yaw = atan2(d.x, d.y)
	# 腳踩的高度：照路上寫的高度走，但不會比地面低（樹幹底下是河或水池、石階比斜坡高一點）
	var gy: float = world.height_at(bird.pos.x, bird.pos.z)
	var seg := Vector2(target.x - prev.x, target.z - prev.z)
	var t := clampf(Vector2(bird.pos.x - prev.x, bird.pos.z - prev.z).dot(seg) / maxf(seg.length_squared(), 0.001), 0.0, 1.0)
	var want := maxf(lerpf(prev.y, target.y, t), gy)
	bird.pos.y = gy
	bird.air = want - gy
	return reached

## 拿到星星：記下來、星星飛起來轉一圈；cut = true 的話鏡頭拉近拍一小段
func _collect_star(cut: bool) -> void:
	if _star_done:
		return
	_star_done = true
	world.take_star(_stage_no())
	_star_fx = 0.0
	log_event("家豪拿到星星（%d / %d）" % [world.star_count(), world.STAR_TOTAL])
	if cut and player and _cut_t <= 0.0:
		_cut_t = STAR_CUT
		_cut_back = player.global_transform
		var head := player.get_node_or_null("Head") as Node3D
		_cut_head = head.rotation.x if head else 0.0

## 打鬥中家豪剛好走到星星旁邊也算拿到（不拉鏡頭）
func _star_touch() -> void:
	if _star_done or not _star_ready() or not bird.alive() or bird.air > 0.5 or _star_stage == 1:
		return
	if flat_dist(bird.pos, _star_pos()) <= STAR_NEAR:
		_collect_star(false)

## 每一畫面：星星飛起來的動畫、過場時的鏡頭、左上角的星星數
func _tick_star_view(dt: float) -> void:
	if _star_label == null:
		var layer := CanvasLayer.new()
		layer.layer = 20
		add_child(layer)
		_star_label = Label.new()
		_star_label.add_theme_font_size_override("font_size", 30)
		_star_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.3))
		_star_label.add_theme_color_override("font_outline_color", Color(0.1, 0.07, 0.03))
		_star_label.add_theme_constant_override("outline_size", 8)
		_star_label.position = Vector2(22.0, 12.0)
		_star_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(_star_label)
		# 右上角：敵人還剩幾個，用紅色圓點表示（和左邊的星星同一種樣子）；倒下的變成空心
		_foe_dots = HBoxContainer.new()
		_foe_dots.add_theme_constant_override("separation", 4)
		_foe_dots.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		_foe_dots.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		_foe_dots.offset_right = -22
		_foe_dots.offset_top = 12
		_foe_dots.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(_foe_dots)
		for f in enemies:
			var dot := Label.new()
			dot.add_theme_font_size_override("font_size", 30)
			dot.add_theme_color_override("font_outline_color", Color(0.1, 0.03, 0.03))
			dot.add_theme_constant_override("outline_size", 8)
			dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_foe_dots.add_child(dot)
		# 共用的敵人欄（頭像＋血條）收起來
		if not _enemy_rows.is_empty():
			var n0: Node = _enemy_rows[0]["fill"]
			while n0.get_parent() is Control:        # 一路往上找到整個敵人欄（直接掛在畫面層底下的那一個）
				n0 = n0.get_parent()
			if n0 is VBoxContainer:
				(n0 as CanvasItem).visible = false
	for i in mini(_foe_dots.get_child_count(), enemies.size()):
		var lb: Label = _foe_dots.get_child(i)
		var alive: bool = enemies[i].alive()
		lb.text = "●" if alive else "○"
		lb.add_theme_color_override("font_color", Color(0.90, 0.16, 0.13) if alive else Color(0.55, 0.30, 0.28))
	var n: int = world.star_count()
	_star_label.text = "★".repeat(n) + "☆".repeat(world.STAR_TOTAL - n)
	var node: Node3D = world.star_node(_stage_no())
	if _star_fx >= 0.0 and node and is_instance_valid(node):
		_star_fx += dt
		var k := clampf(_star_fx / (STAR_CUT * 0.85), 0.0, 1.0)
		# 星星飛到家豪頭上，轉得很快、先變大再縮小不見
		node.global_position = bird.pos + Vector3(0.0, bird.air + 1.6 + 1.4 * k, 0.0)
		node.rotate_y(dt * 14.0)
		node.scale = Vector3.ONE * (1.0 + sin(k * PI) * 0.9) * (1.0 - smoothstep(0.8, 1.0, k))
		if k >= 1.0:
			node.visible = false
			_star_fx = -1.0
	if _cut_t > 0.0:
		# 小過場的計時放在這裡（每一畫面都會跑）：時間到一定把鏡頭還給玩家，不會因為戰局那邊沒繼續叫就卡住
		_cut_t -= dt
		if _cut_t <= 0.0:
			_cut_t = 0.0
			_end_star_cut()
	if _cut_t > 0.0 and player:
		# 鏡頭借走：擺在家豪斜前方，看著他和頭上的星星
		var at := bird.pos + Vector3(0.0, bird.air + 1.8, 0.0)
		var from := at + Vector3(3.4, 1.6, 4.2)
		var d := at - from
		player.global_position = from - Vector3(0.0, 1.65, 0.0)
		player.rotation = Vector3(0.0, atan2(-d.x, -d.z), 0.0)
		player.set("velocity", Vector3.ZERO)
		var head := player.get_node_or_null("Head") as Node3D
		if head:
			head.rotation.x = atan2(d.y, Vector2(d.x, d.z).length())

func _end_star_cut() -> void:
	if player:
		player.global_transform = _cut_back
		var head := player.get_node_or_null("Head") as Node3D
		if head:
			head.rotation.x = _cut_head
		player.set("velocity", Vector3.ZERO)

## 過關之後：星星拿得到就先去拿（走過去 → 小過場 → 走回來），然後走到出口的第一個點等著；
## 可以走了就沿著路走完（踩在樹幹、石階上面），走完就接下一小關
func _walk_exit(dt: float) -> void:
	if _crossed:
		return
	# 先去拿星星（已經走上橋／石階的話就不回頭了）
	if _fetch_star(dt, _exit_i <= 1):
		return
	var path := _exit_path()
	if path.is_empty():
		return
	if _exit_i >= path.size():
		_crossed = true
		_go_next()
		return
	if _exit_i >= 1 and not _exit_open():
		return
	var target := path[_exit_i]
	var to := Vector2(target.x - bird.pos.x, target.z - bird.pos.z)
	var step := EXIT_SPEED * dt
	if to.length() <= step:
		bird.pos = Vector3(target.x, 0.0, target.z)
		_exit_i += 1
	else:
		var d := to.normalized()
		bird.pos += Vector3(d.x, 0.0, d.y) * step
		bird.yaw = atan2(d.x, d.y)
	# 腳踩的高度：照路上寫的高度走，但不會比地面低（樹幹底下是河、石階比斜坡高一點）
	var gy: float = world.height_at(bird.pos.x, bird.pos.z)
	var want := gy
	if _exit_i >= 1:
		var a := path[_exit_i - 1]
		var b := path[mini(_exit_i, path.size() - 1)]
		var seg := Vector2(b.x - a.x, b.z - a.z)
		var t := clampf(Vector2(bird.pos.x - a.x, bird.pos.z - a.z).dot(seg) / maxf(seg.length_squared(), 0.001), 0.0, 1.0)
		want = maxf(lerpf(a.y, b.y, t), gy)
	bird.pos.y = gy
	bird.air = want - gy

## 家豪走去拿星星：走過去 → 小過場 → 走回來。回傳 true = 這一步在忙這件事（別的先不要做）。
## may_start = 現在可不可以出發（星星要拿得到才會真的出發）。過關前、過關後都可以叫。
func _fetch_star(dt: float, may_start: bool) -> bool:
	if _cut_t > 0.0:
		return true        # 正在播拿到星星的小過場（計時在 _tick_star_view 裡，不管有沒有人叫這個函式都會走完）
	if _star_stage == 0 and not _star_done and _star_ready() and may_start:
		_star_route = _star_path()
		_star_i = 0
		_star_stage = 1
	if _star_stage != 1 and _star_stage != 2:
		return false
	if _star_i >= _star_route.size():
		if _star_stage == 1:
			_collect_star(true)
			_star_route = _star_back()
			_star_i = 0
			_star_stage = 2
		else:
			_star_stage = 3
			_exit_i = 0        # 回到出口的路重新走
		return true
	var prev: Vector3 = _star_route[_star_i - 1] if _star_i > 0 else Vector3(bird.pos.x, world.height_at(bird.pos.x, bird.pos.z) + bird.air, bird.pos.z)
	if _move_bird(_star_route[_star_i], prev, dt):
		_star_i += 1
	return true

# ---------------------------------------------------------------- 夜晚（不是道具：按住右鍵就是晚上）

const NightIcon := preload("res://levels/liuchiyu/items/night_item.gd")      # 只借它的月亮圖示
const NIGHT_SLOT := 70.0         # 夜晚那一格多大
const NIGHT_GAP := 34.0          # 跟道具欄隔多遠

var _night_slot: Panel
var _night_box: StyleBoxFlat

## 按住滑鼠右鍵的時候是晚上，放開就變回白天（什麼時候都可以按，不用切道具）。
## 晚上可以互動的東西會發出極光（見 _tick_glow）。畫面下方道具欄旁邊另外有一格月亮，按著的時候會亮起來
func _tick_night() -> void:
	if world == null or world.get("night") == null:
		return
	var held: bool = not _leaving and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if held != world.night:
		world.night = held
		world._apply_time()
	if _hotbar == null:
		return
	if _night_slot == null:
		var layer := CanvasLayer.new()
		layer.layer = 20
		add_child(layer)
		_night_slot = Panel.new()
		_night_slot.custom_minimum_size = Vector2(NIGHT_SLOT, NIGHT_SLOT)
		_night_slot.size = Vector2(NIGHT_SLOT, NIGHT_SLOT)
		_night_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_night_box = StyleBoxFlat.new()
		_night_box.bg_color = Color(0.17, 0.18, 0.19, 0.92)
		_night_box.set_border_width_all(4)
		_night_box.set_corner_radius_all(4)
		_night_slot.add_theme_stylebox_override("panel", _night_box)
		layer.add_child(_night_slot)
		var icon := TextureRect.new()
		icon.texture = NightIcon.new().icon
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.position = Vector2(9.0, 7.0)
		icon.size = Vector2(NIGHT_SLOT - 18.0, NIGHT_SLOT - 18.0)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_night_slot.add_child(icon)
		var key := Label.new()
		key.text = "右鍵"
		key.add_theme_font_size_override("font_size", 15)
		key.add_theme_color_override("font_color", Color(1, 1, 1))
		key.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.06))
		key.add_theme_constant_override("outline_size", 5)
		key.position = Vector2(4.0, NIGHT_SLOT - 22.0)
		key.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_night_slot.add_child(key)
	# 放在道具欄右邊、隔開一段，跟道具欄底部對齊
	var hb_w: float = maxf(_hotbar.size.x, float(items.size()) * 84.0 + 4.0)
	_night_slot.position = _hotbar.global_position + Vector2(hb_w + NIGHT_GAP, 84.0 - NIGHT_SLOT)
	_night_slot.visible = _hotbar.visible and not _leaving
	_night_box.border_color = Color(0.55, 0.95, 0.9) if held else Color(0.45, 0.46, 0.48)

# ---------------------------------------------------------------- 家豪不踩水（水灘、湖）

var _slide_sign := 1.0           # 現在往哪一邊繞
var _slide_keep := 0.0           # 還要維持這一邊多久（秒）
const POOL_SLIDE := 4.6          # 被水擋住的時候，沿著岸邊繞過去的速度

## 家豪現在想去哪（被水擋住的時候往哪一邊繞）。預設是他正在追的敵人；各小關可以覆寫
func _bird_goal() -> Variant:
	if bird.target != null and (bird.target as Fighter).alive():
		return (bird.target as Fighter).pos
	return null

## 家豪走進第 n 小關的水池範圍就把他推回岸上，同時沿著岸邊往「離目標比較近」的那一側繞過去，
## 所以目標在水的另一邊的時候，他會繞著水走，不會頂著岸邊卡住。每 1/60 秒叫一次
func _keep_bird_dry(n: int, dt: float) -> void:
	_slide_keep = maxf(_slide_keep - dt, 0.0)
	if not bird.alive() or bird.state == "fly":
		return
	if _star_stage == 1 or _star_stage == 2 or _cut_t > 0.0:
		return        # 正踩著樹幹／石頭去拿星星
	if not world.in_pool(n, bird.pos.x, bird.pos.z, 0.35, true):
		return
	var c: Vector3 = bird.pos
	var best := INF
	for pool in world.zone_pools(n):
		var d: float = flat_dist(bird.pos, pool.center)
		if d < best:
			best = d
			c = pool.center
	var out := Vector3(bird.pos.x - c.x, 0.0, bird.pos.z - c.z)
	out = out.normalized() if out.length() > 0.05 else Vector3.RIGHT
	var q := bird.pos
	for i in 120:
		if not world.in_pool(n, q.x, q.z, 0.35, true):
			break
		q += out * 0.1
	# 沿著岸邊繞：兩個方向挑離目標近的那一邊（沒有目標就照他現在面對的方向）。
	# 選了一邊就一直繞同一邊（不然目標剛好在正對面的時候會左右搖擺）；那一邊被場地邊界擋住就換另一邊
	var tan := Vector3(-out.z, 0.0, out.x)
	var goal = _bird_goal()
	var want := Vector3(sin(bird.yaw), 0.0, cos(bird.yaw))
	if goal != null:
		want = Vector3((goal as Vector3).x - q.x, 0.0, (goal as Vector3).z - q.z)
	if want.length() > 0.1:
		var side: float = want.normalized().dot(tan)
		if _slide_keep <= 0.0 or absf(side) > 0.75:
			_slide_sign = 1.0 if side >= 0.0 else -1.0
		_slide_keep = 1.0
		tan *= _slide_sign
		var raw: Vector3 = q + tan * POOL_SLIDE * dt
		var slid: Vector3 = world.clamp_play(raw)
		if flat_dist(raw, slid) > 0.01:
			_slide_sign = -_slide_sign        # 這一邊是場地邊界：換另一邊繞
		q = slid
		bird.yaw = atan2(tan.x, tan.z)
	bird.pos = ground(q)
	bird.air = 0.0
	bird.kb_vel = Vector3.ZERO

# ---------------------------------------------------------------- 鏡頭跟著家豪（第三人稱）

const FOLLOW_BACK := 6.0         # 鏡頭在家豪後面多遠
const FOLLOW_UP := 3.4           # 比家豪高多少

var _follow_pos = null           # 跟拍時鏡頭現在的位置（慢慢跟上，不會一頓一頓）
var _start_cam := false          # 一開始那一下擺過了沒

## 把鏡頭（玩家）擺在 from、看著 at
func _aim_camera(from: Vector3, at: Vector3) -> void:
	if player == null:
		return
	var d := at - from
	player.global_position = from - Vector3(0.0, 1.65, 0.0)
	player.rotation = Vector3(0.0, atan2(-d.x, -d.z), 0.0)
	player.set("velocity", Vector3.ZERO)
	var head := player.get_node_or_null("Head") as Node3D
	if head:
		head.rotation.x = atan2(d.y, Vector2(d.x, d.z).length())

## 家豪背後斜上方的位置
func _behind_bird() -> Vector3:
	var fwd := Vector3(sin(bird.yaw), 0.0, cos(bird.yaw))
	var p := bird.pos + Vector3(0.0, bird.air, 0.0) - fwd * FOLLOW_BACK + Vector3(0.0, FOLLOW_UP, 0.0)
	p.y = maxf(p.y, world.height_at(p.x, p.z) + 1.2)        # 不要鑽進地裡（上石階的時候後面是斜坡）
	return p

## 家豪現在是不是正在走去下一小關（過橋／上石階）
func _walking_out() -> bool:
	return _won() and _next_stage() > 0 and not _leaving and _cut_t <= 0.0 \
		and (_star_stage == 0 or _star_stage == 3) and not _exit_path().is_empty() and _exit_open()

## 每一畫面：一進場鏡頭先擺在家豪背後；家豪走去下一小關的時候，鏡頭像第三人稱一樣跟在他後面
func _tick_follow(dt: float) -> void:
	if player == null or bird == null:
		return
	var look := bird.pos + Vector3(0.0, bird.air + 1.0, 0.0)
	if not _start_cam:
		_start_cam = true
		_aim_camera(_behind_bird(), look)
		return

## 每 1/60 秒（和家豪走路同一個節奏，畫面才不會抖）：家豪走去下一小關的時候鏡頭跟在他後面
func _step_follow(dt: float) -> void:
	if player == null or bird == null:
		return
	var look := bird.pos + Vector3(0.0, bird.air + 1.0, 0.0)
	if not _walking_out():
		if _follow_pos != null:
			_follow_pos = null
			player.set_physics_process(true)        # 還給玩家自己飛
		return
	# 跟拍的時候玩家自己的移動先停掉（不然兩邊搶著改位置，畫面會抖）
	if _follow_pos == null:
		_follow_pos = player.global_position + Vector3(0.0, 1.65, 0.0)
		_follow_look = look
		player.set_physics_process(false)
	# 看的點和鏡頭的位置都慢慢跟上：石階一階一階的高低、轉彎都被抹平
	_follow_look = _follow_look.lerp(look, clampf(dt * 5.0, 0.0, 1.0))
	var cur: Vector3 = _follow_pos
	var flat := Vector3(_follow_look.x - cur.x, 0.0, _follow_look.z - cur.z)
	if flat.length() < 0.2:
		flat = Vector3(sin(bird.yaw), 0.0, cos(bird.yaw))
	var want: Vector3 = _follow_look - flat.normalized() * FOLLOW_BACK + Vector3(0.0, FOLLOW_UP, 0.0)
	_follow_pos = cur.lerp(want, clampf(dt * 3.0, 0.0, 1.0))
	_aim_camera(_follow_pos, _follow_look)

var _follow_look := Vector3.ZERO  # 跟拍時鏡頭看的點（慢慢跟上）

## 有人被風吹得睜不開眼睛（風道具會叫這個）：下面的對話框跳一句，頭像是說話的那個人
func on_blinded(f: Fighter) -> void:
	say_as(f, "啊！我的眼睛！")
	if f.is_bird:
		_bird_dazed = 3.0        # 家豪大約東張西望這麼久

const DAZE_LEAVES := 5
var _daze_fx := {}               # 角色 → 他頭上那一圈葉子的節點
var _bird_dazed := 0.0

## 看不見的人（農夫是 blind_t > 0，家豪是剛被吹到那幾秒）頭上有一圈小葉子繞著轉，一眼就知道誰中了
func _tick_daze_fx(dt: float) -> void:
	if _bird_dazed > 0.0:
		_bird_dazed -= dt
	for f in all_fighters():
		var on: bool = f.alive() and ((f.is_bird and _bird_dazed > 0.0 and f.state == "linger") or (not f.is_bird and f.data.get("blind_t", 0.0) > 0.0))
		var node: Node3D = _daze_fx.get(f)
		if node == null or not is_instance_valid(node):
			if not on:
				continue
			node = Node3D.new()
			var qm := QuadMesh.new()
			qm.size = Vector2(0.52, 0.3)
			# 微微發光的紅色（跟滿地的橘黃色落葉分得開）
			var cols := [Color(1.0, 0.22, 0.18), Color(1.0, 0.42, 0.30), Color(0.95, 0.12, 0.14)]
			for k in DAZE_LEAVES:
				var m := StandardMaterial3D.new()
				m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				m.cull_mode = BaseMaterial3D.CULL_DISABLED
				m.albedo_color = cols[k % cols.size()]
				var leaf := MeshInstance3D.new()
				leaf.mesh = qm
				leaf.material_override = m
				leaf.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				var a := TAU * float(k) / DAZE_LEAVES
				leaf.position = Vector3(cos(a) * 0.75, sin(a * 2.0) * 0.12, sin(a) * 0.75)
				leaf.rotation = Vector3(0.6, -a, 0.4)
				node.add_child(leaf)
			var glow := OmniLight3D.new()        # 一點點紅光照在頭上
			glow.light_color = Color(1.0, 0.25, 0.2)
			glow.light_energy = 1.2
			glow.omni_range = 2.6
			node.add_child(glow)
			world.add_child(node)
			_daze_fx[f] = node
		node.visible = on
		_daze_tint(f, on)
		if on:
			node.global_position = f.pos + Vector3(0.0, f.air + (1.4 if f.is_bird else 2.45), 0.0)
			node.rotate_y(dt * 5.0)

var _daze_mat: StandardMaterial3D
var _daze_tinted := {}

## 看不見的人整個身體也罩一層淡淡發光的紅色（一閃一閃）
func _daze_tint(f: Fighter, on: bool) -> void:
	if _daze_mat == null:
		_daze_mat = StandardMaterial3D.new()
		_daze_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_daze_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_daze_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_daze_mat.albedo_color = Color(1.0, 0.16, 0.10, 0.3)
	_daze_mat.albedo_color.a = 0.22 + 0.12 * sin(float(Time.get_ticks_msec()) * 0.008)
	if f.node == null or _daze_tinted.get(f, false) == on:
		return
	_daze_tinted[f] = on
	var todo: Array = [f.node]
	while not todo.is_empty():
		var n: Node = todo.pop_back()
		if n is GeometryInstance3D:
			(n as GeometryInstance3D).material_overlay = _daze_mat if on else null
		for c in n.get_children():
			todo.append(c)

func _level_visuals() -> void:
	super()
	_tick_daze_fx(1.0 / 60.0)
	_tick_glow()

## 晚上會閃藍綠色的光的東西：[[節點, 現在還能不能互動], ...]，各小關自己列
func _glow_nodes() -> Array:
	return []

var _night_init := false

## 晚上的時候，還能互動的東西閃淡淡的藍綠色光（提示玩家哪些東西可以用技能）。
## 上一小關如果是晚上離開的，這一小關一開始也是晚上。
func _tick_glow() -> void:
	if not world.has_method("set_glow"):
		return
	if not _night_init:
		_night_init = true
		if Engine.get_meta("liuchiyu_night", false) and not world.night:
			world.night = true
			world._apply_time()
	for e in _glow_nodes():
		if e[0] != null and is_instance_valid(e[0]):
			world.set_glow(e[0], world.night and e[1] and not _leaving, e[2] if e.size() > 2 else null)

var _bird_portrait: Texture2D
var _farmer_portrait: Texture2D

## 讓某個角色說一句話：對話框左邊的頭像換成他（共用的 say() 固定是家豪的頭像）
func say_as(f: Fighter, text: String) -> void:
	if _dialog == null:
		return
	if _bird_portrait == null:
		_bird_portrait = _dialog.portrait
	if f.is_bird:
		_dialog.portrait = _bird_portrait
		_dialog.say(text)
	else:
		_dialog.portrait = f.portrait if f.portrait else _make_farmer_portrait()
		_dialog.say("%s：%s" % [f.name, text])

## 共用的 say()（家豪說話、教學提示）：頭像要換回家豪
func say(text: String, pic: Texture2D = null) -> void:
	if _dialog and _bird_portrait:
		_dialog.portrait = _bird_portrait
	super(text, pic)

## 農夫的頭像：跟右上角敵人欄一樣的畫法（膚色的圓臉、草帽、紅帽帶、兩個眼睛、一條嘴），畫成一張圖
func _make_farmer_portrait() -> Texture2D:
	if _farmer_portrait:
		return _farmer_portrait
	var n := 96
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var skin := Color(0.96, 0.78, 0.62)
	var hat := Color(0.92, 0.82, 0.55)
	var dark := Color(0.12, 0.10, 0.10)
	for y in n:
		for x in n:
			var p := Vector2(x + 0.5, y + 0.5)
			var c := Color(0, 0, 0, 0)
			if p.distance_to(Vector2(48, 56)) <= 30.0:
				c = skin
			if p.distance_to(Vector2(36, 52)) <= 4.0 or p.distance_to(Vector2(60, 52)) <= 4.0:
				c = dark
			if Rect2(38, 68, 20, 4).has_point(p):
				c = Color(0.55, 0.30, 0.25)
			if Rect2(8, 24, 80, 10).has_point(p) or Rect2(26, 4, 44, 22).has_point(p):
				c = hat
			if Rect2(26, 19, 44, 6).has_point(p):
				c = Color(0.80, 0.25, 0.20)
			if c.a > 0.0:
				img.set_pixel(x, y, c)
	_farmer_portrait = ImageTexture.create_from_image(img)
	return _farmer_portrait

## 換關之前呼叫：各小關把自己的機關現在的樣子記下來（world.remember_zone(第幾關, {...})），
## 這樣到了下一關回頭看，倒的樹還是倒的、滾石還在它停的地方
func _save_state() -> void:
	pass

## 過關之後畫面最上面那一行寫什麼（告訴玩家接下來往哪走）
func _next_hint() -> String:
	return "往第%s小關飛過去" % ["一", "二", "三"][_next_stage() - 1]

## 過關之後玩家按左鍵：共用程式這時候已經把道具鎖住了，這裡直接叫手上那個「按一下」型的道具
## （例如打贏之後還要用雷劈樹搭橋）。按住型的道具（風）由 _hold_tick 處理，不走這裡
func _post_win_click(p: Vector3) -> void:
	if selected < 0 or selected >= items.size() or _post_cd > 0.0:
		return
	var it = items[selected]
	if it.get("hold") == true:
		return
	_post_cd = minf(float(it.cooldown), 1.5)
	it.cast(self, p)
	if hands:
		hands.cast_pulse(it.id)

var _post_cd := 0.0        # 過關後按一下型道具的間隔

## 這個位置現在是不是剛淋過雨、還濕著（雷道具會問）
func is_wet_at(p: Vector3) -> bool:
	var r = item("rain")
	return r != null and r.is_wet(self, p)

# ---------------------------------------------------------------- 按住持續施放的道具（風、雨）

var _held_item = null

## 每 1/60 秒看一次：左鍵有沒有按著、手上的道具是不是「按住型」（道具裡寫 var hold := true）。
## 是的話就叫它的 hold_step()；放開、換道具的時候叫 hold_end()。
func _hold_tick(dt: float) -> void:
	var it = items[selected] if selected >= 0 and selected < items.size() else null
	var on: bool = it != null and it.get("hold") == true and not _leaving \
		and (phase == Phase.RUNNING or _won() or it.get("hold_any") == true) \
		and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if _held_item != null and (not on or _held_item != it):
		_held_item.hold_end(self)
		_held_item = null
	if hands:
		hands.set_hold(it.id if on else "")
	if not on:
		return
	var p := _aim_p()
	var fresh: bool = _held_item == null
	_held_item = it
	it.hold_step(self, p, wind_dir_to(p), dt, fresh)

## 從神（鏡頭）吹向 p 的水平方向
func wind_dir_to(p: Vector3) -> Vector3:
	var from := camera.global_position
	var d := Vector3(p.x - from.x, 0.0, p.z - from.z)
	if d.length() < 0.5:
		d = -camera.global_basis.z
		d.y = 0.0
	return d.normalized()

func _level_step(dt: float) -> void:
	super(dt)
	_hold_tick(dt)
	_star_touch()

func _won() -> bool:
	return phase == Phase.ENDED and outcome == "win"

func _unhandled_input(event: InputEvent) -> void:
	if _won() and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_post_win_click(_aim_p())
		return
	super(event)

# ---------------------------------------------------------------- 切換道具時，技能欄上面出現一行小字

## 畫面上盡量不放字：最上面的按鍵說明、「準備中／戰鬥中…」那一行都收起來，
## 能用畫面表達的就用畫面（星星數在左上角、可以互動的東西會變白／晚上會發光）
func _hide_texts() -> void:
	if _phase_label:
		_phase_label.visible = false
	var keys := get_parent().get_node_or_null("HUD/Hint")
	if keys:
		(keys as CanvasItem).visible = false

# ---------------------------------------------------------------- 連按兩下 W：飛得比較快

const SPRINT_TAP := 0.3          # 兩下之間最多隔幾秒
const WALK_MULT := 1.9           # 平常飄移的速度是共用設定的幾倍
const SPRINT_MULT := 3.3         # 連按兩下 W 之後是幾倍

var _sprint := false
var _w_last := -10.0             # 上一次按下 W 是什麼時候（秒）
var _base_speed := -1.0          # 原本的飄移速度

## 連按兩下 W（往前）就開始加速，一直到放開 W 為止
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("move_forward") and not event.is_echo():
		var now := float(Time.get_ticks_msec()) / 1000.0
		if now - _w_last <= SPRINT_TAP:
			_sprint = true
		_w_last = now

func _tick_sprint() -> void:
	if player == null or player.get("move_speed") == null:
		return
	if _base_speed < 0.0:
		_base_speed = player.move_speed
	if _sprint and not Input.is_action_pressed("move_forward"):
		_sprint = false
	player.move_speed = _base_speed * (SPRINT_MULT if _sprint else WALK_MULT)

## 旁觀的玩家不能飛進海裡：鏡頭最低只能貼在海面上面一點
func _keep_above_sea() -> void:
	if player == null or world.get("sea_level") == null:
		return
	var low: float = float(world.sea_level) - 0.8        # 鏡頭在身體上面 1.65 公尺，所以鏡頭大約在海面上 0.85 公尺
	if player.global_position.y < low:
		player.global_position.y = low
		var v = player.get("velocity")
		if v is Vector3 and (v as Vector3).y < 0.0:
			player.set("velocity", Vector3((v as Vector3).x, 0.0, (v as Vector3).z))

## 倒下的敵人頭上那條空血條不留著（重試之後活過來會再出現）
func _hide_dead_bars() -> void:
	for f in enemies:
		if f.bar == null:
			continue
		if not f.alive() or f.data.get("hidden", false):        # hidden = 還沒上場（例如還在飛機上的騎士）
			f.bar.visible = false
			f.data["bar_hidden"] = true
		elif f.data.get("bar_hidden", false):
			f.data.erase("bar_hidden")
			f.bar.visible = true

# ---------------------------------------------------------------- 家豪和敵人互打：每一下扣得比較少

## 雙方近身互打（家豪啄人、敵人踢家豪）的傷害只有共用設定的這麼多倍，打鬥的節奏才不會太快。
## 道具和機關（滾石、風車、倒樹、雷擊水池、岩漿、鐵桶）造成的傷害不受影響。
const MELEE_SCALE := 0.6

## 家豪啄中敵人
func _hit_enemy(f: Fighter, dmg: float, from: Vector3) -> void:
	super(f, dmg * MELEE_SCALE, from)

## 家豪偷襲（共用程式裡直接扣固定的傷害，所以先把少扣的部分補回去）
func _sneak(f: Fighter) -> void:
	f.hp += PECK_DAMAGE * SNEAK_MULT * (1.0 - MELEE_SCALE)
	super(f)

## 不播開場的黑框道具教學（一進場技能欄上面會浮現一行說明，就夠了）
func _level_setup() -> void:
	super()
	show_tutorial = false
	if hands == null and camera:
		hands = GodHands.new()
		hands.name = "GodHands"
		camera.add_child(hands)
	# 敵人打家豪的傷害調低（家豪啄敵人的在 _hit_enemy() / _sneak()）；機關造成的傷害不變
	for f in enemies:
		f.kick_damage *= MELEE_SCALE
		f.heavy_damage *= MELEE_SCALE
	# 敵人腳下的紅色扇形（偵測範圍）不畫了；他們還是看得到家豪，只是畫面上不顯示
	for f in enemies:
		if f.cone != null:
			f.cone.queue_free()
			f.cone = null

## 共用道具沒有 hint，在這裡補
const ITEM_HINTS := {"feed": "按一下左鍵：撒飼料，把家豪引過去"}
const HINT_TIME := 2.8

var _hint_label: Label
var _hint_t := 0.0
var _hint_sel := -1

func _item_hint(i: int) -> String:
	if i < 0 or i >= items.size():
		return ""
	var h = items[i].get("hint")
	if h is String and h != "":
		return h
	return ITEM_HINTS.get(items[i].id, "")

## 每一畫面看一次：選的道具換了，就在技能欄上面顯示那個道具的一行說明，過幾秒淡掉
func _tick_item_hint(dt: float) -> void:
	if _hotbar == null:
		return
	if _hint_label == null:
		var layer := CanvasLayer.new()
		layer.layer = 20
		add_child(layer)
		_hint_label = Label.new()
		_hint_label.add_theme_font_size_override("font_size", 20)
		_hint_label.add_theme_color_override("font_color", Color(1, 1, 1))
		_hint_label.add_theme_color_override("font_outline_color", Color(0.08, 0.08, 0.08))
		_hint_label.add_theme_constant_override("outline_size", 6)
		_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(_hint_label)
		_hint_sel = -1              # 一進場就把手上那個道具的說明浮現一下（取代開場的黑框教學）
	if selected != _hint_sel:
		_hint_sel = selected
		_hint_t = HINT_TIME
		_hint_label.text = _item_hint(selected)
		_hotbar.name_t = HINT_TIME        # 道具名稱也一起浮出來（用數字鍵換的時候共用程式不會顯示）
	if _hint_t > 0.0:
		_hint_t -= dt
	_hint_label.visible = _hint_t > 0.0 and tutorial_step < 0
	if _hint_label.visible:
		var hb := _hotbar.get_global_rect()
		_hint_label.size = Vector2(700.0, 28.0)
		_hint_label.position = Vector2(hb.position.x + hb.size.x * 0.5 - 350.0, hb.position.y - 78.0)
		_hint_label.modulate.a = clampf(_hint_t / 0.5, 0.0, 1.0)

## 準心沒有指到地面的時候（例如看著天空或海），就當成指著正前方 10 公尺的地面
func _ahead_point() -> Vector3:
	var fwd := -camera.global_basis.z
	fwd.y = 0.0
	if fwd.length() < 0.05:
		fwd = -camera.global_basis.y        # 垂直往下看：用畫面的「上方」當前方
		fwd.y = 0.0
	return ground(camera.global_position + fwd.normalized() * 10.0)

## 這一關可以用道具互動的東西：[{"pos": 底部的位置, "h": 多高, "r": 準心離它多近算指到}]
## 高的東西（樹、風車）準心通常是指在它身上，視線穿過去落地的點會在它後面很遠；所以要另外算「視線有沒有經過它」
func _aim_targets() -> Array:
	return []

## 準心現在指的地方：視線經過某個可以互動的東西，就當成指著它（回傳它底部的位置）；
## 不然就是視線落地的點；沒落地（看著天空、海）就是正前方 10 公尺
func _aim_p() -> Vector3:
	_update_aim()
	var o := camera.global_position
	var d := -camera.global_basis.z
	var ground_t: float = (aim_point - o).length() if aim_point != null else INF
	var best_t := INF
	var best := Vector3.ZERO
	for t in _aim_targets():
		var y := 0.0
		while y <= float(t.h):
			var q: Vector3 = t.pos + Vector3(0.0, y, 0.0)
			var along := clampf((q - o).dot(d), 0.0, 80.0)
			# 地面比它近很多的話，是指著它前面的地上，不算
			if along < best_t and along < ground_t + 3.0 and ((q - o) - d * along).length() <= float(t.r):
				best_t = along
				best = t.pos
			y += 0.5
	if best_t < INF:
		return best
	return aim_point if aim_point != null else _ahead_point()

## 按一下施放：準心指到可以互動的東西就對著它放；風、雨這種不用指到地面的（道具裡寫 var any_aim := true）也照樣放
func try_cast() -> bool:
	_update_aim()
	var p := _aim_p()
	if aim_point == null and p == _ahead_point() and not (selected >= 0 and selected < items.size() and items[selected].get("any_aim") == true):
		return super()
	return cast(selected, p)

## 道具真的放出去了，手就動一下（按住型的在 _hold_tick 裡處理）
func cast(i: int, p: Vector3) -> bool:
	var ok := super(i, p)
	if ok and hands and items[i].get("hold") != true:
		hands.cast_pulse(items[i].id)
	return ok

func _go_next() -> void:
	if _leaving:
		return
	_leaving = true
	var n := _next_stage()
	_save_state()        # 把這一關的機關現在的樣子記下來，下一關看過來還是這個樣子
	if world.has_method("remember_camera"):
		world.remember_camera()      # 下一關從鏡頭現在的位置接著飛，不會跳回起點
	Engine.set_meta("stage_id", "liuchiyu/%d" % n)
	Engine.set_meta("next_scene", "res://levels/liuchiyu/stage_%d/stage.tscn" % n)
	get_tree().change_scene_to_file.call_deferred("res://levels/liuchiyu/stage_%d/stage.tscn" % n)

## 過關、而且可以走了之後：鏡頭飛進下一小關的空地就直接接下去
func _process(dt: float) -> void:
	super(dt)
	_hide_texts()
	_hide_dead_bars()
	_tick_night()
	_tick_sprint()
	_keep_above_sea()
	_tick_follow(dt)
	if phase == Phase.PREPARE:
		_hold_tick(dt)        # 按 Enter 之前也能用「準備階段也能按」的按住型道具（變成晚上）
	_tick_item_hint(dt)
	_tick_star_view(dt)
	if hands:
		# 鏡頭被借走（拿星星的小過場、跟著家豪走去下一關）的時候把手收起來
		hands.show_hands(_cut_t <= 0.0 and _follow_pos == null)
	if _leaving or not _won() or _next_stage() <= 0 or not _can_leave():
		return
	if _walking_out():
		return        # 鏡頭正跟著家豪走：等他自己走完再換關，不要因為鏡頭先進了下一關的範圍就切走
	if player and world.has_method("in_zone") and world.in_zone(_next_stage(), player.global_position.x, player.global_position.z):
		_go_next()

func _level_step_ended(dt: float) -> void:
	super(dt)
	if _post_cd > 0.0:
		_post_cd -= dt
	if _won():
		_hold_tick(dt)        # 過關之後按住型的道具還是可以用（例如吹倒枯樹）
		if _next_stage() > 0:
			_walk_exit(dt)
			_step_follow(dt)
	if not _won() or _next_stage() <= 0:
		return
	# 不跳「過關」的結算、也不問要不要去下一關：島是連在一起的，玩家自己飛過去就接下去。
	# 只在畫面最上面那一行留一句接下來要做什麼
	_summary_panel.visible = false
	_phase_label.text = _next_hint()
	# 柵欄要在家豪走過去之前就打開：路可以走了（橋搭好／石階）就開，不用等他走完
	if not _opened and (_can_leave() or (not _exit_path().is_empty() and _exit_open())):
		_opened = true
		if world.has_method("open_barrier"):
			world.open_barrier()

func _level_reset() -> void:
	super()
	_held_item = null
	_opened = false
	_exit_i = 0
	_crossed = false
	if _cut_t > 0.0:
		_cut_t = 0.0
		_end_star_cut()
	_star_stage = 0
	_star_fx = -1.0
	# 這一小關的星星：重試不會把已經拿到的星星收回去，只是把還沒拿到的放回原位
	_star_done = world.star_taken(_stage_no())
	var sn: Node3D = world.star_node(_stage_no())
	if sn and is_instance_valid(sn) and not _star_done:
		sn.visible = true
		sn.scale = Vector3.ONE
		sn.global_position = world.star_home(_stage_no())
	for f in enemies:
		if _base_vision.has(f):
			f.vision_range = _base_vision[f]
	_base_vision.clear()
	if world and world.has_method("close_barrier"):
		world.close_barrier()

## 眼睛進落葉、或是被電到的敵人：看不見、不會追人，站在原地；時間到了才恢復巡邏
func _tick_enemy(f: Fighter, dt: float) -> void:
	var left: float = f.data.get("blind_t", 0.0)
	if left <= 0.0 or not f.alive():
		super(f, dt)
		return
	if not _base_vision.has(f):
		_base_vision[f] = f.vision_range
	left -= dt
	f.data["blind_t"] = left
	f.vision_range = BLIND_VISION
	f.aggro = false
	f.alert_t = -1.0
	f.kb_vel = Vector3.ZERO
	if f.state != "blind":
		f.set_state("blind")
		anim(f, "HitRecieve", 0.6)
	if left <= 0.0:
		f.vision_range = _base_vision[f]
		_base_vision.erase(f)
		f.set_state("patrol")
		log_event(f.data.get("blind_end", "%s的眼睛好了" % f.name))
		f.data.erase("blind_end")
