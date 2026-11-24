extends "res://scripts/battle/battle_base.gd"
## 島上三個小關共用的戰局底：
##   - 過關之後不跳結算、不問要不要換關：鏡頭飛進下一小關的空地就直接接下去（之後輸了也是從那一關重來）
##   - 「眼睛進落葉」：風把葉子吹進敵人眼睛的那幾秒，他看不見、站在原地揉眼睛（見 items/wind_item.gd）
## 各小關的 battle.gd 覆寫 _next_stage() 回傳下一小關是第幾關（最後一關回傳 0）。

const BLIND_VISION := 0.9        # 看不見的時候，偵測扇形縮到多短
const GodHands := preload("res://levels/liuchiyu/god_hands.gd")

var hands: Node3D                # 神的雙手（第一人稱，掛在鏡頭底下；見 god_hands.gd）
## 畫面下方那雙半透明的神之手：先拿掉（改回 true 就會再出現，程式都還留著）
const SHOW_HANDS := false
## 農夫的血量：家豪啄兩下才倒（共用設定是啄一下就倒；啄一下扣 PECK_DAMAGE）
const FARMER_HP := PECK_DAMAGE * 2.0
## 這個大關家豪挨打的傷害只有兩種，血量永遠是整顆或半顆心：
##   一顆心：農夫踢一腳（普通踢和重踢都一樣）
##   半顆心：豪王打一下、被自己這邊的機關波及（滾石、風車葉片、倒樹、水灘的電、岩漿球）
const HIT_FULL := HEART_HP
const HIT_HALF := HEART_HP * 0.5
## 農夫踢一下扣多少血：剛好一顆心（三腳就倒）。
## 這樣設是為了「神不出手，家豪自己打不贏」：他啄兩下才倒一個農夫，換不過來
const FARMER_KICK := HIT_FULL

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
var _star_rows: VBoxContainer       # 左上角「星星」紙卡裡的三列
var _star_shown := -1               # 紙卡上現在畫的是「拿到哪幾顆」（位元），變了才重畫

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

## 每一小關三顆星：過關一顆、打倒所有敵人一顆、場上那顆要去拿的星星一顆。
## 左上角的紙卡上，第三顆旁邊寫它在哪
const STAR_WHERE := ["風車頂上", "外海的礁石上", "小湖中間的島上"]

## 第 n 小關「打倒所有敵人」「過關」這兩顆拿到了沒（跟場上的星星一樣，記到遊戲關掉為止）
static func goal_done(n: int, id: String) -> bool:
	var all: Dictionary = Engine.get_meta("liuchiyu_goals", {})
	return all.get("%d/%s" % [n, id], false)

static func mark_goal(n: int, id: String) -> void:
	var all: Dictionary = Engine.get_meta("liuchiyu_goals", {})
	all["%d/%s" % [n, id]] = true
	Engine.set_meta("liuchiyu_goals", all)

## 這一小關的三顆星：[[文字, 拿到了沒], ...]
func _stage_goals() -> Array:
	var n := _stage_no()
	var where: String = STAR_WHERE[n - 1] if n >= 1 and n <= STAR_WHERE.size() else ""
	return [
		["過關", goal_done(n, "clear")],
		["打倒所有敵人", goal_done(n, "foes")],
		["拿到星星：" + where, world.star_taken(n)],
	]

## 這一小關現在拿到幾顆星
func stage_star_count() -> int:
	var c := 0
	for g in _stage_goals():
		c += 1 if g[1] else 0
	return c

## 選關地圖讀的星星紀錄表：{小關場景路徑: {條件 id: true}}（chapter.gd 的 STARS_SCRIPT 指到這個檔案）。
## 地圖上每一小關的泡泡和關卡徽章會照這張表畫三顆星（跟其他大關一樣）
static var best_stars := {}

## 把這一小關現在拿到的星星抄進 best_stars（拿到一顆就馬上記，中途回地圖也看得到）
func _sync_best_stars() -> void:
	var root := get_parent()
	var key := String(root.scene_file_path) if root else ""
	if key == "":
		return
	var n := _stage_no()
	var got := {"clear": goal_done(n, "clear"), "foes": goal_done(n, "foes"), "star": world != null and world.star_taken(n)}
	for id in got:
		if got[id]:
			if not best_stars.has(key):
				best_stars[key] = {}
			best_stars[key][id] = true

## 每一畫面看一次：敵人都倒了就拿到「打倒所有敵人」；出發去下一關（最後一關是打贏）就拿到「過關」
func _tick_goals() -> void:
	var n := _stage_no()
	_sync_best_stars()
	if not _won():
		return
	if not goal_done(n, "foes"):
		mark_goal(n, "foes")
		log_event("拿到星星：打倒所有敵人")
	if not goal_done(n, "clear") and (_leaving or _next_stage() <= 0):
		mark_goal(n, "clear")
		log_event("拿到星星：過關")

## 左上角的「星星」紙卡：跟其他大關左上角的目標卡同一種樣式（米色紙片、一列一顆星加一行字），
## 列出這一小關的三顆星。右上角的敵人欄直接用共用的（一排頭像，倒下打叉），不再自己畫紅點。
func _build_star_card() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(20.0, 16.0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIStyle.paper(panel)
	layer.add_child(panel)
	_star_rows = VBoxContainer.new()
	_star_rows.add_theme_constant_override("separation", 4)
	_star_rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(_star_rows)
	_star_shown = -1

func _refresh_star_card() -> void:
	_tick_goals()
	var goals := _stage_goals()
	var mask := 0
	for k in goals.size():
		if goals[k][1]:
			mask |= 1 << k
	if mask == _star_shown:
		return
	_star_shown = mask
	for c in _star_rows.get_children():
		_star_rows.remove_child(c)
		c.queue_free()
	var title := Label.new()
	title.text = "星星"
	title.label_settings = UIStyle.ls(20, UIStyle.INK)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_star_rows.add_child(title)
	for g in goals:
		var got: bool = g[1]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_star_rows.add_child(row)
		var st := Label.new()
		st.text = "★"
		st.mouse_filter = Control.MOUSE_FILTER_IGNORE
		st.label_settings = UIStyle.ls(24, Color("f6c445") if got else Color("fff8e7"), 6, UIStyle.INK if got else Color(UIStyle.INK, 0.45))
		row.add_child(st)
		var tx := Label.new()
		tx.text = String(g[0])
		tx.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tx.label_settings = UIStyle.ls(22, UIStyle.INK if got else Color(UIStyle.INK, 0.55))
		row.add_child(tx)

## 每一畫面：星星飛起來的動畫、過場時的鏡頭、左上角的星星紙卡
func _tick_star_view(dt: float) -> void:
	if _star_rows == null:
		_build_star_card()
	_refresh_star_card()
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
const NIGHT_SLOT := 74.0         # 夜晚那一格多大（跟技能欄的卡片一樣大）
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
		# 跟共用的技能欄（scripts/ui/hotbar.gd）同一種手帳風格：米色圓角紙卡、深色描邊、底下一點陰影，
		# 中間一顆咖啡色圓貼紙放圖示；按住的時候跟「選中的道具」一樣變成紅框、往上浮一點
		var layer := CanvasLayer.new()
		layer.layer = 20
		add_child(layer)
		_night_slot = Panel.new()
		_night_slot.custom_minimum_size = Vector2(NIGHT_SLOT, NIGHT_SLOT)
		_night_slot.size = Vector2(NIGHT_SLOT, NIGHT_SLOT)
		_night_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_night_box = StyleBoxFlat.new()
		_night_box.bg_color = Color(1.0, 0.973, 0.906)
		_night_box.set_corner_radius_all(14)
		_night_box.shadow_color = Color(0, 0, 0, 0.28)
		_night_box.shadow_size = 5
		_night_box.shadow_offset = Vector2(2, 4)
		_night_slot.add_theme_stylebox_override("panel", _night_box)
		layer.add_child(_night_slot)
		var sticker := Panel.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.36, 0.27, 0.2, 0.92)
		sb.set_corner_radius_all(29)
		sticker.add_theme_stylebox_override("panel", sb)
		sticker.size = Vector2(58.0, 58.0)
		sticker.position = Vector2((NIGHT_SLOT - 58.0) * 0.5, (NIGHT_SLOT - 58.0) * 0.5 + 2.0)
		sticker.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_night_slot.add_child(sticker)
		var icon := TextureRect.new()
		icon.texture = NightIcon.new().icon
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.size = Vector2(44.0, 44.0)
		icon.position = Vector2((NIGHT_SLOT - 44.0) * 0.5, (NIGHT_SLOT - 44.0) * 0.5 + 2.0)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_night_slot.add_child(icon)
		# 按鍵：一顆小小的鍵帽貼在卡片底下（跟畫面右下角「H 操作說明」那一排同一種樣子）
		var key := Label.new()
		key.text = "右鍵"
		key.add_theme_font_size_override("font_size", 14)
		key.add_theme_color_override("font_color", UIStyle.INK)
		var kb := StyleBoxFlat.new()
		kb.bg_color = Color(1.0, 0.973, 0.906)
		kb.border_color = UIStyle.INK
		kb.set_border_width_all(2)
		kb.border_width_bottom = 3
		kb.set_corner_radius_all(6)
		kb.content_margin_left = 6.0
		kb.content_margin_right = 6.0
		kb.content_margin_top = 0.0
		kb.content_margin_bottom = 1.0
		key.add_theme_stylebox_override("normal", kb)
		key.position = Vector2(-8.0, -10.0)
		key.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_night_slot.add_child(key)
	# 放在道具欄右邊、隔開一段，跟道具欄底部對齊
	var hb_w: float = maxf(_hotbar.size.x, float(items.size()) * 84.0 + 4.0)
	# 跟技能欄的卡片對齊（卡片在 84 的格子裡上下各縮 5）；按住時往上浮 7，跟選中的道具一樣
	_night_slot.position = _hotbar.global_position + Vector2(hb_w + NIGHT_GAP, 2.0 + 5.0 - (7.0 if held else 0.0))
	if _hero_card:
		# 家豪的愛心紙片排在「夜晚」那一格的右邊
		_hero_card.offset_left = _night_slot.position.x + NIGHT_SLOT + 18.0
	# 輸了（畫面下半變黑、顯示「家豪被抓去當晚餐了」）的時候技能欄會收起來，這一格也跟著收
	_night_slot.visible = _hotbar.is_visible_in_tree() and not _leaving and not defeat_shown
	_night_slot.modulate.a = 1.0 if _night_shown else 0.0        # 還沒介紹到夜晚之前先藏著
	_night_box.border_color = UIStyle.accent() if held else UIStyle.INK
	_night_box.set_border_width_all(4 if held else 3)
	_night_box.border_width_bottom = 6 if held else 5

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

## 有人被沙子吹得睜不開眼睛（blow_sand() 會叫這個）：下面的對話框跳一句，頭像是說話的那個人
func on_blinded(f: Fighter) -> void:
	say_as(f, "啊，沙子進到眼睛裡了！")
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
		_daze_mat.next_pass = _outline_mat()        # 暈的時候紅框也還在
	_daze_mat.albedo_color.a = 0.22 + 0.12 * sin(float(Time.get_ticks_msec()) * 0.008)
	if f.node == null or f.is_bird or _daze_tinted.get(f, false) == on:
		return        # 家豪不蓋這層紅（他身上是綠框）
	_daze_tinted[f] = on
	var todo: Array = [f.node]
	while not todo.is_empty():
		var n: Node = todo.pop_back()
		if n is GeometryInstance3D:
			# 暈的時候蓋一層紅；不暈了要把紅框放回去（紅框也是用同一個 overlay 的位置）
			(n as GeometryInstance3D).material_overlay = _daze_mat if on else (_outline_for(f) if n is MeshInstance3D and _outlined.get(f, false) else null)
		for c in n.get_children():
			todo.append(c)

# ---------------------------------------------------------------- 敵人的紅框（被擋住也看得到）

const OUTLINE_COLOR := Color(1.0, 0.16, 0.10)       # 敵人：紅
const OUTLINE_HERO := Color(0.25, 0.95, 0.35)        # 家豪：綠
const OUTLINE_WIDTH := 0.07      # 敵人的框多粗（公尺）
const OUTLINE_HERO_WIDTH := 0.022   # 家豪的框細一點（他的模型比較圓，同樣的粗細看起來會很厚）
const OUTLINE_DASH := 11.0       # 家豪的框是斷斷續續的虛線：數字越大，一段一段越短

var _dash_tex: ImageTexture

var _outline_mats := {}          # 顏色 → 材質（同一種顏色的人共用一份）
var _outlined := {}              # 角色 → 現在有沒有框

## 角色身上的框：沿著整個人的輪廓描一圈線，隔著樹、石頭、山坡也看得到（只畫輪廓，不會蓋住他本人）。
## 敵人是紅色，家豪是綠色。做法是引擎內建的 stencil（模板）：
##   第一層：看不見，只在「這個人佔到的每一個像素」上做記號（被擋住的部分也記）
##   第二層：把模型往外長一圈、塗上顏色、不管前面有沒有東西擋都畫，但做過記號的地方不畫 → 只剩外面那一圈
## 兩層都是很簡單的材質，同一種顏色共用同一份，幾乎不花效能。
func _outline_mat(col: Color = OUTLINE_COLOR, width := OUTLINE_WIDTH, dashed := false) -> StandardMaterial3D:
	if _outline_mats.has(col):
		return _outline_mats[col]
	var ring := StandardMaterial3D.new()
	ring.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.albedo_color = col
	ring.grow = true
	ring.grow_amount = width
	if dashed:
		# 虛線：一張斜條紋的小貼圖（一半透明）順著身體貼上去，透明的地方不畫，框就斷成一段一段。
		# 條紋是貼在模型上的，角色走動、轉身的時候虛線跟著他，不會在畫面上亂跳
		if _dash_tex == null:
			var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
			for y in 16:
				for x in 16:
					img.set_pixel(x, y, Color(1, 1, 1, 1.0 if (x + y) % 16 < 9 else 0.0))
			_dash_tex = ImageTexture.create_from_image(img)
		ring.albedo_texture = _dash_tex
		ring.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		ring.uv1_triplanar = true
		ring.uv1_scale = Vector3.ONE * OUTLINE_DASH
		ring.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		ring.alpha_scissor_threshold = 0.5
	ring.no_depth_test = true
	ring.render_priority = 2
	ring.stencil_mode = BaseMaterial3D.STENCIL_MODE_CUSTOM
	ring.stencil_flags = BaseMaterial3D.STENCIL_FLAG_READ
	ring.stencil_compare = BaseMaterial3D.STENCIL_COMPARE_NOT_EQUAL
	ring.stencil_reference = 1
	var mark := StandardMaterial3D.new()
	mark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mark.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mark.albedo_color = Color(1, 1, 1, 0.0)        # 完全透明：只做記號
	mark.no_depth_test = true
	mark.render_priority = 1
	mark.stencil_mode = BaseMaterial3D.STENCIL_MODE_CUSTOM
	mark.stencil_flags = BaseMaterial3D.STENCIL_FLAG_WRITE
	mark.stencil_compare = BaseMaterial3D.STENCIL_COMPARE_ALWAYS
	mark.stencil_reference = 1
	mark.next_pass = ring
	_outline_mats[col] = mark
	return mark

func _outline_for(f: Fighter) -> StandardMaterial3D:
	if f.is_bird:
		return _outline_mat(OUTLINE_HERO, OUTLINE_HERO_WIDTH, true)
	return _outline_mat(OUTLINE_COLOR)

## 每一畫面看一次：還活著、已經上場的敵人有紅框，家豪有綠框；倒下的、還沒上場的（飛機上的騎士）沒有
func _tick_outline() -> void:
	var all: Array = enemies.duplicate()
	if bird:
		all.append(bird)
	for f in all:
		if f.node == null or not is_instance_valid(f.node):
			continue
		var want: bool = f.alive() and not f.data.get("hidden", false)
		if _outlined.get(f, false) == want:
			continue
		_outlined[f] = want
		if _daze_tinted.get(f, false):
			continue        # 正在暈：overlay 現在是那層紅，框接在它後面，等不暈的時候再換回來
		var todo: Array = [f.node]
		while not todo.is_empty():
			var n: Node = todo.pop_back()
			if n is MeshInstance3D:
				(n as MeshInstance3D).material_overlay = _outline_for(f) if want else null
			for c in n.get_children():
				todo.append(c)

func _level_visuals() -> void:
	super()
	# 被電到僵住的時候，身體很快地左右抖（只是畫面上抖，實際位置沒動）
	if _stun_t > 0.0 and bird and bird.node and is_instance_valid(bird.node):
		var tt := float(Time.get_ticks_msec()) * 0.001
		(bird.node as Node3D).position += Vector3(sin(tt * 70.0), 0.0, cos(tt * 83.0)) * 0.05
	_tick_outline()
	_tick_daze_fx(1.0 / 60.0)
	_tick_glow()
	_tick_sand_highlight()

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
var _press_seen := false         # 上一步左鍵是不是已經按著（用來抓「剛按下去」的那一下）

## 每 1/60 秒看一次：左鍵有沒有按著、手上的道具是不是「按住型」（道具裡寫 var hold := true）。
## 是的話就叫它的 hold_step()；放開、換道具的時候叫 hold_end()。
func _hold_tick(dt: float) -> void:
	var it = items[selected] if selected >= 0 and selected < items.size() else null
	var on: bool = it != null and it.get("hold") == true and not _leaving \
		and (phase == Phase.RUNNING or _won() or it.get("hold_any") == true) \
		and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	# 準心直接指著人的時候不能起風（已經在吹的話，掃過人不會中斷）
	if on and _held_item != it and _direct_blocked():
		on = false
		if not _press_seen:
			toast(DIRECT_MSG, 1.4)        # 只在按下去的那一下提示一次
	_press_seen = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
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

# ---------------------------------------------------------------- 家豪被電到：僵在原地抖一下

const ZAP_STUN := 1.0            # 僵住多久（秒）
var _stun_t := 0.0               # 還要僵多久
var _stun_pos := Vector3.ZERO    # 僵在哪裡

## 讓家豪僵在原地一下（被電到的時候用）：這段時間他不會走、也不會被打飛，身體左右抖。
## 沒有這一下的話，他被電完馬上繼續往前走，看起來像沒事一樣。
func stun_bird(t: float = ZAP_STUN) -> void:
	if not bird.alive():
		return
	_stun_t = maxf(_stun_t, t)
	_stun_pos = ground(bird.pos)
	_stun_hold()

## 每 1/60 秒：僵住的時候把他釘在原地
func _tick_stun(dt: float) -> void:
	if _stun_t <= 0.0:
		return
	_stun_t -= dt
	if not bird.alive():
		_stun_t = 0.0
		return
	_stun_hold()

## 把家豪釘在原地：共用程式被打到會讓他拍翅飛開（或往後跳），這裡把那個動作取消掉，改成站在原地發愣
func _stun_hold() -> void:
	if bird.state in ["fly", "hop", "land"]:
		bird.set_state("linger")
	bird.pos = _stun_pos
	bird.kb_vel = Vector3.ZERO
	bird.air = 0.0

func _level_step(dt: float) -> void:
	super(dt)
	_tick_stun(dt)
	_tick_sand(dt)
	_hold_tick(dt)
	_star_touch()

# ---------------------------------------------------------------- 神不能直接干預凡人

const DIRECT_MSG := "神不能直接干預凡人"
const PERSON_R := 0.55           # 視線離人的身體多近算「直接指著他」

## 準心現在是不是直接指著某個人——敵人或家豪（視線穿過他的身體，而且他比地面近）。沒有就回傳 null。
## 道具裡寫 var no_direct := true 的（雷、風），指著人的時候不能施放；
## 玩家真的按下去的那一下，畫面中間才跳一行提示（平常指著人不會一直顯示，免得擋畫面）。
func _aimed_person() -> Fighter:
	if camera == null:
		return null
	_update_aim()
	var o := camera.global_position
	var d := -camera.global_basis.z
	var ground_t: float = (aim_point - o).length() if aim_point != null else INF
	var best: Fighter = null
	var best_t := INF
	# 敵人和家豪都算：神也不能直接對家豪出手
	var people: Array = enemies.duplicate()
	if bird:
		people.append(bird)
	for f in people:
		if not f.alive() or f.data.get("hidden", false):
			continue
		var h: float = maxf(1.9, float(f.data.get("bar_y", 0.0)) * 0.85)
		var y := 0.25
		while y <= h:
			var q: Vector3 = f.pos + Vector3(0.0, y, 0.0)
			var along := (q - o).dot(d)
			if along > 0.0 and along < best_t and along < ground_t + 0.6 and ((q - o) - d * along).length() <= PERSON_R:
				best_t = along
				best = f
			y += 0.3
	return best

## 手上的道具不能直接對人用、而且準心正指著人。
## 可以互動的東西優先：準心同時指到（或視線穿過人之後落在）樹、水池、沙地、火山這類東西，
## 就當成是對著那個東西用，不算直接干預——不然敵人剛好站在樹前面、站在水裡的時候都用不了。
func _direct_blocked() -> bool:
	if selected < 0 or selected >= items.size() or items[selected].get("no_direct") != true:
		return false
	if _aimed_person() == null:
		return false
	return not _aim_on_interactive()

## 手上的道具叫什麼（沒拿就是空字串）
func _held_id() -> String:
	return String(items[selected].id) if selected >= 0 and selected < items.size() else ""

## 視線有沒有經過 _aim_targets() 裡的某一樣東西（跟 _aim_p() 同一套算法）
func _aim_hits_target() -> bool:
	if camera == null:
		return false
	_update_aim()
	var o := camera.global_position
	var d := -camera.global_basis.z
	var ground_t: float = (aim_point - o).length() if aim_point != null else INF
	for t in _aim_targets():
		var y := 0.0
		while y <= float(t.h):
			var q: Vector3 = t.pos + Vector3(0.0, y, 0.0)
			var along := clampf((q - o).dot(d), 0.0, 80.0)
			if along < ground_t + 3.0 and ((q - o) - d * along).length() <= float(t.r):
				return true
			y += 0.5
	return false

## 準心現在是不是指著手上這個道具可以互動的東西（指到的話，就算視線上有人也照樣可以用）。
## 這裡管共用的：_aim_targets() 列的東西、拿著風指到沙地。小關自己的水池之類的就覆寫，記得 or super()
func _aim_on_interactive() -> bool:
	if _aim_hits_target():
		return true
	return _held_id() == "wind" and _sand_at(_aim_p()) >= 0

# ---------------------------------------------------------------- 沙地（風吹沙子，沙子吹進眼睛）

const SAND_REACH := 8.0          # 沙子順著風飛多遠
const SAND_WIDEN := 0.35         # 每飛 1 公尺，沙子往兩邊散開多少
const SAND_CD := 2.5             # 一塊沙地吹過之後，隔多久沙子才落定、可以再吹
const SAND_BLIND := 4.5          # 被沙子吹到之後幾秒看不見
const SAND_IMMUNE := 3.5         # 眼睛好了之後，這麼久之內不會再中
const SAND_SHADER := preload("res://levels/liuchiyu/shaders/oil_sand.gdshader")

var _sand: Array = []            # [{pos: 中心（已經貼地）, r: 半徑, cd: 還要幾秒才能再吹, node: 畫面上的那塊沙, mat: 它的材質, hl: 現在多亮}]
var _sand_immune := {}           # 每個人還要多久才會再中
var _sand_mesh: QuadMesh

## 每個小關的沙地（座標以那一小關自己的 (0, 0) 為準）：對著它吹風，沙子順著風飛出去，下風處的人好幾秒看不見。
## 放在這裡而不是各小關的 battle.gd：別的小關的沙地也要畫出來（開場的島嶼預覽、從遠處看都看得到），只是吹不到。
const SAND_ZONES := {
	# 第一小關：盆地南邊（從家豪這邊往北吹，吹到農夫1 來回走的那條線）、東北邊（往西吹到農夫2 繞的那一圈）
	1: [{"pos": Vector3(0.0, 0.0, 5.0), "r": 2.2}, {"pos": Vector3(4.5, 0.0, -3.0), "r": 2.0}],
	# 第三小關：場地中間（往南吹到兩個農夫巡邏路線靠北的那一頭）、最南邊（往北吹到騎士落地的那塊空地）
	3: [{"pos": Vector3(0.0, 0.0, 2.5), "r": 2.4}, {"pos": Vector3(0.5, 0.0, 12.0), "r": 2.2}],
}

## 這一小關可以吹的沙地：[{"pos": Vector3(x, 0, z), "r": 半徑}, ...]。小關想自己擺可以覆寫
func _sand_specs() -> Array:
	return SAND_ZONES.get(_stage_no(), [])

## 把沙地鋪在地上（貼著地形起伏、邊緣不規則）。沙紋和顏色都在 oil_sand.gdshader 裡算，
## 每塊沙只有兩百多個三角形、沒有貼圖，幾乎不花效能。
## 這一小關的沙地可以吹；別的小關的也鋪出來，但只是遠遠看得到的景。
func _build_sand() -> void:
	_sand.clear()
	var old := world.get_node_or_null("SandPatches")
	if old:
		old.free()
	var root := Node3D.new()
	root.name = "SandPatches"
	world.add_child(root)
	var specs := _sand_specs()
	for k in specs.size():
		var made := _make_sand(root, ground(specs[k].pos), specs[k].r, float(k) * 7.3 + float(_stage_no()) * 3.1)
		made[0].name = "Sand%d" % (k + 1)
		_sand.append({"pos": made[0].position, "r": specs[k].r, "cd": 0.0, "node": made[0], "mat": made[1], "hl": 0.0})
	# 別的小關的沙地：換算成這一小關的座標再鋪
	var origins = world.get("ZONE_ORIGIN")
	if not (origins is Array):
		return
	for zone in SAND_ZONES:
		if zone == _stage_no() or zone < 1 or zone > origins.size() or _stage_no() < 1 or _stage_no() > origins.size():
			continue
		var shift: Vector2 = origins[zone - 1] - origins[_stage_no() - 1]
		var list: Array = SAND_ZONES[zone]
		for k in list.size():
			var at: Vector3 = list[k].pos + Vector3(shift.x, 0.0, shift.y)
			_make_sand(root, ground(at), list[k].r, float(k) * 7.3 + float(zone) * 3.1)

## 鋪一塊沙：回傳 [節點, 材質]
func _make_sand(root: Node3D, c: Vector3, r: float, seed_v: float) -> Array:
	var mat := ShaderMaterial.new()        # 每塊沙自己一份：變白的程度各自控制
	mat.shader = SAND_SHADER
	mat.set_shader_parameter("seed", seed_v)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := 5
	var segs := 28
	var pts: Array = []        # pts[ring][seg] = [位置, 顏色]
	for ri in rings + 1:
		var row: Array = []
		for si in segs:
			var a := TAU * float(si) / segs
			# 邊緣忽遠忽近，輪廓才不會是正圓
			var edge := r * (1.0 + 0.16 * sin(a * 3.0 + seed_v * 1.7) + 0.09 * sin(a * 7.0 + 0.6))
			var rr := edge * float(ri) / rings
			var gp: Vector3 = ground(c + Vector3(cos(a) * rr, 0.0, sin(a) * rr))
			# 中間堆高一點點，像一小堆沙；最外圈貼地
			gp.y += 0.05 + 0.10 * (1.0 - float(ri) / rings)
			# 頂點顏色的紅色 = 離中心多遠（0～1），shader 用它畫深色的邊
			row.append([gp - c, Color(float(ri) / rings, 0.0, 0.0)])
		pts.append(row)
	for ri in rings:
		for si in segs:
			var sj := (si + 1) % segs
			var quad := [pts[ri][si], pts[ri + 1][si], pts[ri + 1][sj], pts[ri][sj]]
			for t in [0, 1, 2, 0, 2, 3]:
				st.set_color(quad[t][1])
				st.set_normal(Vector3.UP)
				st.add_vertex(quad[t][0])
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = c
	root.add_child(mi)
	return [mi, mat]

func _tick_sand(dt: float) -> void:
	for s in _sand:
		if s.cd > 0.0:
			s.cd -= dt
	for k in _sand_immune.keys():
		_sand_immune[k] -= dt
		if _sand_immune[k] <= 0.0:
			_sand_immune.erase(k)

## 準心 p 現在指著哪一塊沙地（-1 = 沒有）
func _sand_at(p: Vector3) -> int:
	for k in _sand.size():
		if flat_dist(p, _sand[k].pos) <= float(_sand[k].r) + 0.6:
			return k
	return -1

## 這個位置在不在「從沙地 s 順著 dir 飛出去的那一片沙」裡面
func _in_sand_cloud(s: Dictionary, dir: Vector3, at: Vector3) -> bool:
	var v := Vector3(at.x - s.pos.x, 0.0, at.z - s.pos.z)
	var along := v.dot(dir)
	if along < -float(s.r) or along > SAND_REACH:
		return false
	return (v - dir * along).length() <= float(s.r) + maxf(along, 0.0) * SAND_WIDEN

## 風道具每 1/60 秒叫一次：風正吹在 p、風向 dir。吹到沙地（而且沙子已經落定）就揚起一陣沙，
## 下風處的敵人被沙子吹進眼睛（家豪不受影響）。風沒有直接碰到人：沒有沙地就什麼事都不會發生。
func blow_sand(p: Vector3, dir: Vector3) -> void:
	var k := _sand_at(p)
	if k < 0 or _sand[k].cd > 0.0:
		return
	var s: Dictionary = _sand[k]
	s.cd = SAND_CD
	_sand_burst(s, dir)
	log_event("風揚起沙地%d的沙（風向 %.2f, %.2f）" % [k + 1, dir.x, dir.z])
	if phase != Phase.RUNNING:
		return
	for f in enemies:
		if f.data.get("hidden", false) or not f.alive() or _sand_immune.has(f):
			continue        # 還沒上場的人（例如還在飛機上的騎士）吹不到
		if _in_sand_cloud(s, dir, f.pos):
			_sand_immune[f] = SAND_BLIND + SAND_IMMUNE
			f.data["blind_t"] = SAND_BLIND
			log_event("%s被沙子吹進眼睛" % f.name)
			on_blinded(f)
	# 家豪不受沙子影響：站在下風處也照常行動（沙子只會吹進敵人的眼睛）

## 一陣沙順著風飛出去（只是畫面效果）
func _sand_burst(s: Dictionary, dir: Vector3) -> void:
	if _sand_mesh == null:
		_sand_mesh = QuadMesh.new()
		_sand_mesh.size = Vector2(0.22, 0.22)
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.vertex_color_use_as_albedo = true
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		_sand_mesh.material = m
	var ps := CPUParticles3D.new()
	ps.mesh = _sand_mesh
	ps.amount = 260
	ps.one_shot = true
	ps.explosiveness = 0.8
	ps.lifetime = 1.3
	ps.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	ps.emission_box_extents = Vector3(float(s.r) * 0.8, 0.15, float(s.r) * 0.8)
	ps.direction = dir + Vector3(0.0, 0.22, 0.0)
	ps.spread = 20.0
	ps.initial_velocity_min = 4.0
	ps.initial_velocity_max = 9.5
	ps.gravity = Vector3(0.0, -2.2, 0.0)
	ps.scale_amount_min = 0.6
	ps.scale_amount_max = 2.2
	var g := Gradient.new()
	g.set_color(0, Color(0.97, 0.88, 0.62, 0.95))
	g.set_color(1, Color(0.80, 0.66, 0.42, 0.0))
	g.add_point(0.6, Color(0.90, 0.78, 0.52, 0.8))
	ps.color_ramp = g
	ps.position = s.pos + Vector3(0.0, 0.35, 0.0)
	fx_root.add_child(ps)
	ps.emitting = true
	ps.finished.connect(ps.queue_free)

## 拿著風、準心指到沙地（而且沙子已經落定）的時候，那塊沙蓋上一層白（跟滾石、風車、枯樹一樣，不閃），
## 讓玩家知道現在吹下去會有反應。沙本來就是淺色的，共用的那層淡白色蓋上去看不太出來，所以在 shader 裡蓋得稍微重一點。
## 晚上的時候，還能吹的沙地跟其他可以互動的東西一樣圍一圈極光。
func _tick_sand_highlight() -> void:
	if _sand.is_empty():
		return
	var can: bool = not _leaving and selected >= 0 and selected < items.size() and items[selected].id == "wind"
	var k := _sand_at(_aim_p()) if can else -1
	for i in _sand.size():
		var s: Dictionary = _sand[i]
		var want := 1.0 if (i == k and s.cd <= 0.0) else 0.0
		if s.hl != want:
			s.hl = move_toward(s.hl, want, 1.0 / 60.0 * 8.0)        # 很快地亮起來／暗下去，不會一格一格跳
			(s.mat as ShaderMaterial).set_shader_parameter("hl", s.hl)
		if world.has_method("set_glow"):
			world.set_glow(s.node, world.night and s.cd <= 0.0 and not _leaving)

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
	# 島嶼預覽播放中：按 Enter、空白鍵或滑鼠左鍵跳過（這一下不算開打、也不算用道具）
	if _intro_t >= 0.0:
		var skip: bool = event.is_action_pressed("battle_start") \
			or (event is InputEventKey and event.pressed and event.keycode == KEY_SPACE) \
			or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED)
		if skip:
			_end_intro()
			get_viewport().set_input_as_handled()
		elif event is InputEventMouseMotion:
			get_viewport().set_input_as_handled()        # 預覽時滑鼠不轉視角
		return
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
			f.bar.visible = show_float_bars   # 統一介面預設不顯示頭上血條

# ---------------------------------------------------------------- 家豪和敵人互打：每一下扣得比較少

## 敵人踢家豪：普通踢和重踢都剛好扣一顆心（HIT_FULL），在 _level_setup() 裡統一設定

## 家豪啄中敵人、偷襲：統一規則是敵人一到兩下就倒，所以不再打折（只有敵人踢家豪還是打折）

## 不播開場的黑框道具教學（一進場技能欄上面會浮現一行說明，就夠了）
## 家豪在這個大關只有三顆心（共用設定是五顆；一顆心 = HEART_HP 點血）
const BIRD_HEARTS := 3

func _level_setup() -> void:
	super()
	if bird:
		bird.max_hp = BIRD_HEARTS * HEART_HP
		bird.hp = bird.max_hp
	show_tutorial = false
	auto_next = false        # 過關後家豪沿著島上的路走到下一小關（自己的流程），不用共用的自動出發
	if SHOW_HANDS and hands == null and camera:
		hands = GodHands.new()
		hands.name = "GodHands"
		camera.add_child(hands)
	# 敵人踢家豪一律扣一顆心（共用設定的重踢是普通踢的兩倍，這裡拉成一樣，才不會出現奇怪的零頭）
	for f in enemies:
		f.kick_damage = HIT_FULL
		f.heavy_damage = HIT_FULL
	_build_sand()
	# 上一小關交代要介紹的新道具（只介紹這一次）
	_gift_id = String(Engine.get_meta("liuchiyu_new_item", ""))
	if _gift_id != "":
		Engine.remove_meta("liuchiyu_new_item")
		_gift_queue.append(_gift_id)
	# 第一小關一開始（島嶼預覽播完之後）：先介紹「風」，再介紹「夜晚」。只在第一次進來的時候演，重來不再演
	if _stage_no() == 1 and not Engine.get_meta("liuchiyu_intro_gifts", false):
		Engine.set_meta("liuchiyu_intro_gifts", true)
		_gift_queue.append("wind")
		_gift_queue.append("night")
		_night_shown = false
	# 敵人腳下的紅色扇形（偵測範圍）不畫了；他們還是看得到家豪，只是畫面上不顯示
	for f in enemies:
		if f.cone != null:
			f.cone.queue_free()
			f.cone = null
	_start_intro()

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

## 每一畫面看一次：選的道具換了，就在畫面最下面中間顯示那個道具的一行說明，過幾秒淡掉
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
	# 位置跟「現在還無法使用」那種提示一樣：畫面最下面中間的一行（那種提示出現的時候這一行先讓位）
	_hint_label.visible = _hint_t > 0.0 and tutorial_step < 0 and _note_t <= 0.0 and not defeat_shown and not _gift_playing() and _gift_queue.is_empty()
	if _hint_label.visible:
		var vs := get_viewport().get_visible_rect().size
		_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_hint_label.size = Vector2(vs.x, 30.0)
		_hint_label.position = Vector2(0.0, vs.y - NOTE_BOTTOM - 30.0)
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
	if _direct_blocked():
		toast(DIRECT_MSG, 1.4)        # 雷不能直接劈人、風不能直接吹人
		return false
	var p := _aim_p()
	if aim_point == null and p == _ahead_point() and not (selected >= 0 and selected < items.size() and items[selected].get("any_aim") == true):
		return super()
	return cast(selected, p)

## 開場預覽、星星特寫、跟拍時，Tab 的俯看切換先不作用（共用的 scripts/battle/view_toggle.gd）
func _view_blocked() -> bool:
	return _camera_borrowed() or super()

## 鏡頭現在是不是被過場借走了（這時候神的手收起來）。小關有自己的過場就覆寫，記得 or super()
func _camera_borrowed() -> bool:
	return _cut_t > 0.0 or _follow_pos != null or _intro_t >= 0.0

# ---------------------------------------------------------------- 一開始的島嶼預覽（像賽車遊戲開賽前繞場地的鏡頭）

## 每一段鏡頭：[從哪裡, 到哪裡, 一開始看哪裡, 最後看哪裡, 幾秒]（島座標）；一段結束直接切到下一段。
## 最後一段的終點會換成「家豪背後」，接回平常開場的鏡頭
const INTRO_SHOTS := [
	# 從海上高高地繞著整座島看
	[Vector3(84.0, 40.0, 54.0), Vector3(36.0, 46.0, 72.0), Vector3(22.0, 6.0, 2.0), Vector3(12.0, 8.0, 0.0), 4.2],
	# 沿著北岸（Chapter 2）低飛，往高原和火山（Chapter 3）看過去
	[Vector3(74.0, 20.0, -40.0), Vector3(40.0, 27.0, -30.0), Vector3(38.0, 3.0, -16.0), Vector3(-6.0, 20.0, 4.0), 3.8],
	# 從南邊的海上往南岸（Chapter 1）飛下去，停在家豪背後
	[Vector3(58.0, 34.0, 70.0), Vector3(43.0, 14.0, 34.0), Vector3(40.0, 8.0, 10.0), Vector3(43.0, 1.0, 19.0), 4.0],
]
var _intro_t := -1.0             # 預覽播到第幾秒（< 0 = 沒在播）
var _intro_hud := {}             # 預覽時藏起來的畫面元件 → 原本有沒有顯示

## 進到第一小關（整個大關的開頭）時播一次；重來（R）不會再播
func _start_intro() -> void:
	if _stage_no() != 1 or player == null or DisplayServer.get_name() == "headless":
		return
	_intro_t = 0.0
	player.set_physics_process(false)
	if hands:
		hands.hide_now()        # 預覽的時候完全不要看到神的手（原本會留在畫面上淡出）
	# 右下角：Space 跳過（跟要塞那一關進場鏡頭的提示同一種樣子）
	_skip_layer = CanvasLayer.new()
	_skip_layer.layer = 40
	_skip_layer.set_meta("intro_keep", true)        # 預覽時別的介面都收起來，這個要留著
	add_child(_skip_layer)
	var pill := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1.0, 0.973, 0.906, 0.94)
	sb.border_color = Color(UIStyle.INK, 0.35)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 14.0
	sb.content_margin_right = 14.0
	sb.content_margin_top = 6.0
	sb.content_margin_bottom = 6.0
	pill.add_theme_stylebox_override("panel", sb)
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.add_child(UIStyle.key_hint("Space", "跳過"))
	pill.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	pill.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	pill.grow_vertical = Control.GROW_DIRECTION_BEGIN
	pill.offset_right = -24.0
	pill.offset_bottom = -22.0
	_skip_layer.add_child(pill)

var _skip_layer: CanvasLayer

func _end_intro() -> void:
	if _intro_t < 0.0:
		return
	_intro_t = -1.0
	if _skip_layer and is_instance_valid(_skip_layer):
		_skip_layer.queue_free()
	_skip_layer = null
	for n in _intro_hud:
		if is_instance_valid(n):
			n.visible = _intro_hud[n]
	_intro_hud.clear()
	if crosshair:
		crosshair.visible = true
	if player:
		player.set_physics_process(true)
		_aim_camera(_behind_bird(), bird.pos + Vector3(0.0, bird.air + 1.0, 0.0))

## 預覽時畫面上只留風景：道具欄、準心、星星數、敵人圓點都先收起來
func _intro_hide_hud() -> void:
	var list: Array = [get_node_or_null("../HUD")]
	for c in get_children():
		if c is CanvasLayer and not c.has_meta("intro_keep"):
			list.append(c)
	for n in list:
		if n != null and not _intro_hud.has(n) and n != _defeat_layer:
			_intro_hud[n] = n.visible
			n.visible = false

func _tick_intro(dt: float) -> void:
	if _intro_t < 0.0:
		return
	if phase != Phase.PREPARE:
		_end_intro()        # 已經開打了（例如測試直接開始）就不播
		return
	_intro_hide_hud()
	if crosshair:
		crosshair.visible = false
	if _preview:
		_preview.visible = false        # 地上那一圈瞄準的白環也先不畫
	_intro_t += dt
	var off := Vector3(world._off.x, 0.0, world._off.y)
	var t := _intro_t
	for i in INTRO_SHOTS.size():
		var sh: Array = INTRO_SHOTS[i]
		var dur: float = sh[4]
		if t > dur:
			t -= dur
			continue
		var k := t / dur
		var a: Vector3 = sh[0] + off
		var b: Vector3 = sh[1] + off
		var la: Vector3 = sh[2] + off
		var lb: Vector3 = sh[3] + off
		if i == INTRO_SHOTS.size() - 1:
			# 最後一段：慢慢停下來，剛好停在平常開場的位置
			b = _behind_bird()
			lb = bird.pos + Vector3(0.0, bird.air + 1.0, 0.0)
			k = 1.0 - pow(1.0 - k, 2.5)
		_aim_camera(a.lerp(b, k), la.lerp(lb, k))
		return
	_end_intro()

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
	mark_goal(_stage_no(), "clear")      # 出發去下一關 = 這一關過關了（這一幀就換場景，等不到每一畫面的檢查）
	var n := _next_stage()
	_save_state()        # 把這一關的機關現在的樣子記下來，下一關看過來還是這個樣子
	if world.has_method("remember_camera"):
		world.remember_camera()      # 下一關從鏡頭現在的位置接著飛，不會跳回起點
	Engine.set_meta("stage_id", "liuchiyu/%d" % n)
	Engine.set_meta("next_scene", "res://levels/liuchiyu/stage_%d/stage.tscn" % n)
	# 第一小關只有風，第二小關多了雷：交代下一小關一進去就介紹這個新道具
	if _stage_no() == 1 and n == 2:
		Engine.set_meta("liuchiyu_new_item", "thunder")
	get_tree().change_scene_to_file.call_deferred("res://levels/liuchiyu/stage_%d/stage.tscn" % n)

## 過關、而且可以走了之後：鏡頭飛進下一小關的空地就直接接下去
# ---------------------------------------------------------------- 按 H 的操作說明：補上「右鍵 = 夜晚」

## 共用的速查卡只會列出技能欄裡的道具；「夜晚」不在技能欄裡（是另外一格、按住右鍵用的），
## 所以這裡自己補一列右鍵（速查卡只有一頁，不再另外加一整頁長說明）
func _tutorial_pages() -> Array:
	var pages: Array = super()
	if not pages.is_empty() and pages[0].has("controls"):
		var ctl: Array = pages[0].controls
		ctl.append(["右鍵", "按住變晚上：能互動的東西會發光"])
	return pages

# ---------------------------------------------------------------- 提示字（「要開打後才能用」「神不能直接干預凡人」…）

const NOTE_FONT := 20            # 提示字多大（跟技能欄上面那行道具說明一樣）
const NOTE_BOTTOM := 34.0        # 離畫面底邊多遠

var _note_label: Label
var _note_t := 0.0

## 共用程式的提示是畫面正中間一顆大膠囊，在這個大關裡太擋畫面（準心就在那裡）：
## 改成畫面最下面中間小小的一行白字，過一下淡掉。所有 toast() 都走這裡，不再顯示中間那一顆。
func toast(text: String, dur: float) -> void:
	if _note_label == null:
		var layer := CanvasLayer.new()
		layer.layer = 20
		add_child(layer)
		_note_label = Label.new()
		_note_label.add_theme_font_size_override("font_size", NOTE_FONT)
		_note_label.add_theme_color_override("font_color", Color(1, 1, 1))
		_note_label.add_theme_color_override("font_outline_color", Color(0.08, 0.08, 0.08))
		_note_label.add_theme_constant_override("outline_size", 6)
		_note_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_note_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# 貼著畫面底邊、左右置中
		_note_label.anchor_left = 0.0
		_note_label.anchor_right = 1.0
		_note_label.anchor_top = 1.0
		_note_label.anchor_bottom = 1.0
		_note_label.offset_top = -NOTE_BOTTOM - 30.0
		_note_label.offset_bottom = -NOTE_BOTTOM
		layer.add_child(_note_label)
	# 共用程式寫的是「雷 要開打後才能用」：這個大關統一說「現在還無法使用」
	if text.ends_with("要開打後才能用"):
		text = "現在還無法使用"
	_note_label.text = text
	_note_t = dur if text != "" else 0.0
	# 共用的那顆膠囊收起來（不叫 super，它就不會再被打開；一開始可能是開著的，所以這裡關一次）
	if _toast_label:
		_toast_label.text = ""
		_toast_label.visible = false

func _tick_note(dt: float) -> void:
	if _note_label == null:
		return
	if _note_t > 0.0:
		_note_t -= dt
	_note_label.visible = _note_t > 0.0 and not defeat_shown
	_note_label.modulate.a = clampf(_note_t / 0.4, 0.0, 1.0)

# ---------------------------------------------------------------- 雷劈在水上：水面爬滿白色的小電光

const ZAP_COUNT := 26            # 一次有幾道小電光
const ZAP_TIME := 0.55           # 電光閃多久
const ZAP_NEAR := 3.2            # 一半的電光集中在落雷點附近這麼大一圈，其他的散在整片水面上

var _zaps: Array = []            # [{node, t, arcs: [MeshInstance3D], rng_k}]
var _zap_mat: StandardMaterial3D

## 雷劈在第 zone 小關的水池（湖、水灘）上：p 是落雷點。水面上冒出一道一道白色的小電光，一閃一閃地亂跳，
## 過一下子消失。只是畫面效果，讓玩家看得出「電傳到水裡了」（有沒有電到人是各小關自己算的）。
func pool_sparks(zone: int, p: Vector3) -> void:
	if not world.has_method("zone_pools") or DisplayServer.get_name() == "headless":
		return
	var pools: Array = world.zone_pools(zone)
	var raw: Array = world.ZONE_POOLS[zone - 1]
	var best := -1
	for i in pools.size():
		if flat_dist(p, pools[i].center) <= float(pools[i].r) * 1.3 + 0.8 and (best < 0 or flat_dist(p, pools[i].center) < flat_dist(p, pools[best].center)):
			best = i
	if best < 0:
		return
	var c: Vector3 = pools[best].center
	var r: float = float(pools[best].r) * 1.25
	var y: float = float(world.pool_water_y(zone - 1, raw[best])) + 0.07
	if _zap_mat == null:
		_zap_mat = StandardMaterial3D.new()
		_zap_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_zap_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_zap_mat.albedo_color = Color(3.2, 3.4, 4.0)        # 很亮的藍白色，會發光
	var rng := RandomNumberGenerator.new()
	rng.seed = int(absf(p.x) * 97.0 + absf(p.z) * 53.0) + 11
	var holder := Node3D.new()
	fx_root.add_child(holder)
	var arcs: Array = []
	var tries := 0
	while arcs.size() < ZAP_COUNT and tries < ZAP_COUNT * 12:
		tries += 1
		# 前一半集中在落雷點附近，後一半散在整片水上
		var at: Vector3
		if arcs.size() < ZAP_COUNT / 2:
			var a0 := rng.randf() * TAU
			at = p + Vector3(cos(a0), 0.0, sin(a0)) * ZAP_NEAR * sqrt(rng.randf())
		else:
			var a1 := rng.randf() * TAU
			at = c + Vector3(cos(a1), 0.0, sin(a1)) * r * sqrt(rng.randf())
		if not world.in_pool(zone, at.x, at.z):
			continue        # 只畫在水面上（岸上、湖中間的小島不畫）
		# 一道小電光：貼著水面、折來折去的細線，尾巴翹起來一點點
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var dir := rng.randf() * TAU
		var prev := Vector3.ZERO
		var segs := rng.randi_range(3, 5)
		var w := 0.045
		for k in segs:
			dir += rng.randf_range(-1.1, 1.1)
			var up := 0.0 if k < segs - 1 else rng.randf_range(0.12, 0.45)
			var nxt := prev + Vector3(cos(dir), 0.0, sin(dir)) * rng.randf_range(0.25, 0.6) + Vector3(0.0, up, 0.0)
			# 兩片交叉的細長條：平躺的一片（從上面看得到）＋立著的一片（從旁邊看得到）
			var side := Vector3(-sin(dir), 0.0, cos(dir)) * w
			for off in [side, Vector3(0.0, w, 0.0)]:
				var q := [prev - off, prev + off, nxt + off, nxt - off]
				for t in [0, 1, 2, 0, 2, 3]:
					st.add_vertex(q[t])
			prev = nxt
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		mi.material_override = _zap_mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = Vector3(at.x, y, at.z)
		holder.add_child(mi)
		arcs.append(mi)
	# 落雷點一小團光，照亮水面一下
	var light := OmniLight3D.new()
	light.light_color = Color(0.75, 0.88, 1.0)
	light.light_energy = 5.0
	light.omni_range = 9.0
	light.position = Vector3(p.x, y + 1.2, p.z)
	holder.add_child(light)
	_zaps.append({"node": holder, "t": 0.0, "arcs": arcs, "light": light, "k": rng.randi() % 997})

## 每一畫面：電光一閃一閃（每一道各自亂數決定這一下亮不亮），越後面亮著的越少，時間到就收掉
func _tick_zaps(dt: float) -> void:
	for i in range(_zaps.size() - 1, -1, -1):
		var z: Dictionary = _zaps[i]
		if not is_instance_valid(z.node):
			_zaps.remove_at(i)        # 重試的時候 fx_root 已經把它清掉了
			continue
		z.t += dt
		var left: float = 1.0 - float(z.t) / ZAP_TIME
		if left <= 0.0:
			(z.node as Node).queue_free()
			_zaps.remove_at(i)
			continue
		var tick := int(float(z.t) * 16.0)        # 一秒換 16 次
		for k in z.arcs.size():
			var h := fposmod(sin(float(tick * 31 + k * 17 + int(z.k))) * 43758.5453, 1.0)
			(z.arcs[k] as MeshInstance3D).visible = h < 0.25 + 0.55 * left
		(z.light as OmniLight3D).light_energy = 5.0 * left * (0.6 + 0.4 * fposmod(sin(float(tick * 7)) * 91.7, 1.0))

# ---------------------------------------------------------------- 拿到新道具的小過場（第一小關 → 第二小關：多了「雷」）

const GIFT_IN := 0.3             # 背景變暗、道具卡片在畫面正中央彈出來
const GIFT_SPIN := 1.0           # 卡片在中間轉一圈
const GIFT_HOLD := 1.7           # 轉完停一下（底下有一行介紹，要留時間看）
const GIFT_FLY := 0.65           # 滑到左下角技能欄裡它自己的那一格
const GIFT_BIG := 3.0            # 在中間的時候是技能欄卡片的幾倍大
const GIFT_DIM := 0.62           # 背景暗到多暗

var _gift_id := ""               # 這一小關一進來要介紹的新道具（上一小關離開時交代的）
var _gift_queue: Array = []      # 排隊等著介紹的（道具的 id；"night" = 按住右鍵的夜晚），一個演完才換下一個
var _night_shown := true         # 「夜晚」那一格現在可不可以露出來（還沒介紹到它之前先藏著）
## 「夜晚」不是技能欄裡的道具，介紹的時候名字和說明寫在這裡
const NIGHT_NAME := "夜晚"
const NIGHT_HINT := "按住右鍵：變成晚上，可以互動的東西會發光"
var _gift := {}                  # 過場用到的節點和時間

## 一張跟技能欄一樣的道具卡片（米色紙卡、咖啡色圓貼紙、右上角次數徽章）。回傳 [卡片, 它的外框樣式]
## i < 0 的時候不是技能欄裡的道具（夜晚）：圖示用 tex
func _gift_card(layer: Node, i: int, bright: bool, tex: Texture2D = null) -> Array:
	var cnt: int = charges[i] if i >= 0 and i < charges.size() else 0
	var live: bool = bright or cnt != 0
	var card := Panel.new()
	card.size = Vector2(74.0, 74.0)
	card.pivot_offset = card.size * 0.5
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1.0, 0.973, 0.906) if live else Color(0.86, 0.84, 0.8)
	sb.set_corner_radius_all(14)
	sb.shadow_color = Color(0, 0, 0, 0.28)
	sb.shadow_size = 5
	sb.shadow_offset = Vector2(2, 4)
	card.add_theme_stylebox_override("panel", sb)
	layer.add_child(card)
	var sticker := Panel.new()
	var cb := StyleBoxFlat.new()
	cb.bg_color = Color(0.36, 0.27, 0.2, 0.92 if live else 0.5)
	cb.set_corner_radius_all(29)
	sticker.add_theme_stylebox_override("panel", cb)
	sticker.size = Vector2(58.0, 58.0)
	sticker.position = Vector2(8.0, 10.0)
	sticker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(sticker)
	var icon := TextureRect.new()
	icon.texture = tex if tex != null else (items[i].icon_tex if items[i].icon_tex != null else items[i].icon)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.size = Vector2(52.0, 52.0)
	icon.position = Vector2(11.0, 13.0)
	icon.modulate = Color(1, 1, 1) if live else Color(0.45, 0.45, 0.45)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(icon)
	if not bright and cnt > 0:
		# 右上角的次數徽章：跟共用技能欄一樣是深色小圓，用完（0）和不限次數（∞）不畫
		# （介紹中的那張大卡片不畫，歸位之後技能欄自己會畫）
		var badge := Panel.new()
		var bb := StyleBoxFlat.new()
		bb.bg_color = UIStyle.INK
		bb.border_color = Color(1, 1, 1, 0.9)
		bb.set_border_width_all(3)
		bb.set_corner_radius_all(17)
		badge.add_theme_stylebox_override("panel", bb)
		badge.size = Vector2(34.0, 34.0)
		badge.position = Vector2(card.size.x - 5.0 - 17.0, 5.0 - 17.0)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(badge)
		var num := Label.new()
		num.text = str(cnt)
		num.add_theme_font_size_override("font_size", 20)
		num.add_theme_color_override("font_color", Color(1, 1, 1))
		num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		num.size = badge.size
		num.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.add_child(num)
	return [card, sb]

## 卡片的外框：選中的是紅框、粗一點（跟技能欄一樣）
func _gift_frame(sb: StyleBoxFlat, sel: bool) -> void:
	sb.border_color = UIStyle.accent() if sel else UIStyle.INK
	sb.set_border_width_all(4 if sel else 3)
	sb.border_width_bottom = 6 if sel else 5

## 技能欄第 k 格卡片的位置（選中的那一格往上浮 7）
func _slot_pos(k: int, sel: bool) -> Vector2:
	return _hotbar.global_position + Vector2(2.0 + float(k) * 84.0 + 5.0, 2.0 + 5.0 - (7.0 if sel else 0.0))

## 開始介紹新道具。過場的時候真的技能欄先藏起來，改用幾張一模一樣的假卡片演：
##   一開始技能欄上還沒有這個新道具（只有原本那幾個）
##   背景變暗 → 新道具的卡片在正中央彈出來轉一圈
##   卡片滑向技能欄的時候，原本的道具往右挪一格讓位，新道具落進空出來的那一格
## 演完再把真的技能欄放出來。
func _start_gift(i: int) -> void:
	var night := i < 0
	var layer := CanvasLayer.new()
	layer.layer = 30
	add_child(layer)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.03, 0.05, 0.0)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(dim)
	# 原本就有的道具：[卡片, 外框, 現在第幾格, 之前第幾格]。介紹夜晚的時候技能欄不用動，照常顯示
	var olds: Array = []
	if not night:
		for k in items.size():
			if k == i:
				continue
			var made := _gift_card(layer, k, false)
			olds.append([made[0], made[1], k, k if k < i else k - 1])
	var big := _gift_card(layer, i, true, NightIcon.new().icon if night else null)
	_gift_frame(big[1], not night)
	var title := Label.new()
	title.text = "新的神蹟：%s" % (NIGHT_NAME if night else String(items[i].name))
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(1, 1, 1))
	title.add_theme_color_override("font_outline_color", Color(0.08, 0.08, 0.08))
	title.add_theme_constant_override("outline_size", 8)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(title)
	# 名字底下一行介紹：怎麼用、有什麼效果（跟切到這個道具時技能欄上面那行小字一樣）
	var desc := Label.new()
	desc.text = NIGHT_HINT if night else _item_hint(i)
	desc.add_theme_font_size_override("font_size", 22)
	desc.add_theme_color_override("font_color", Color(1.0, 0.95, 0.78))
	desc.add_theme_color_override("font_outline_color", Color(0.08, 0.08, 0.08))
	desc.add_theme_constant_override("outline_size", 6)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(desc)
	if not night:
		_hotbar.modulate.a = 0.0
	_gift = {"t": 0.0, "i": i, "layer": layer, "dim": dim, "card": big[0], "title": title, "desc": desc, "olds": olds}

func _gift_playing() -> bool:
	return not _gift.is_empty()

func _tick_gift(dt: float) -> void:
	if _gift.is_empty():
		# 等技能欄建好了才開始（要知道卡片最後飛去哪）
		if _gift_queue.is_empty() or _hotbar == null or _intro_t >= 0.0:
			return
		if _gift_queue[0] == "night":
			if _night_slot == null:
				return        # 夜晚那一格還沒建好（要知道卡片最後飛去哪）
			_gift_queue.pop_front()
			_start_gift(-1)
			return
		var idx := -1
		for k in items.size():
			if items[k].id == _gift_queue[0]:
				idx = k
		_gift_queue.pop_front()
		if idx >= 0:
			_start_gift(idx)
		return
	_gift.t += dt
	var t: float = _gift.t
	var card: Panel = _gift.card
	var dim: ColorRect = _gift.dim
	var title: Label = _gift.title
	var vs := get_viewport().get_visible_rect().size
	var mid := vs * 0.5 - card.size * 0.5 - Vector2(0.0, 24.0)
	var i: int = _gift.i
	var t_fly := GIFT_IN + GIFT_SPIN + GIFT_HOLD
	var k_in := clampf(t / GIFT_IN, 0.0, 1.0)
	var k_fly := clampf((t - t_fly) / GIFT_FLY, 0.0, 1.0)
	k_fly = k_fly * k_fly * (3.0 - 2.0 * k_fly)        # 慢慢起步、慢慢停
	# 彈出來：先衝過頭一點再縮回來
	var pop := 1.0 + 0.18 * sin(k_in * PI)
	card.scale = Vector2.ONE * lerpf(GIFT_BIG * k_in * pop, 1.0, k_fly)
	var k_spin := clampf((t - GIFT_IN) / GIFT_SPIN, 0.0, 1.0)
	k_spin = k_spin * k_spin * (3.0 - 2.0 * k_spin)
	card.rotation = TAU * k_spin
	# 最後飛到哪：技能欄裡它自己的那一格；夜晚飛到技能欄旁邊它那一格
	var home: Vector2 = _night_slot.position if i < 0 else _slot_pos(i, i == selected)
	card.position = mid.lerp(home, k_fly)
	# 原本的道具：新卡片滑過來的前半段就往右挪好位置（新卡片到的時候那一格已經空出來了）
	var k_move := clampf((t - t_fly) / (GIFT_FLY * 0.6), 0.0, 1.0)
	k_move = k_move * k_move * (3.0 - 2.0 * k_move)
	for o in _gift.olds:
		var was_sel: bool = int(o[3]) == 0            # 還沒有新道具的時候，選的是第一格
		var now_sel: bool = int(o[2]) == selected
		(o[0] as Panel).position = _slot_pos(int(o[3]), was_sel).lerp(_slot_pos(int(o[2]), now_sel), k_move)
		_gift_frame(o[1], was_sel if k_move < 0.5 else now_sel)
	dim.color.a = GIFT_DIM * k_in * (1.0 - k_fly)
	title.size = Vector2(vs.x, 44.0)
	title.position = Vector2(0.0, mid.y + card.size.y * 0.5 + 74.0 * GIFT_BIG * 0.5 + 18.0)
	title.modulate.a = clampf((t - GIFT_IN) / 0.25, 0.0, 1.0) * (1.0 - clampf((t - t_fly) / 0.2, 0.0, 1.0))
	# 介紹那一行：卡片轉到一半才浮出來，跟著名字一起淡掉
	var desc: Label = _gift.desc
	desc.size = Vector2(vs.x, 34.0)
	desc.position = Vector2(0.0, title.position.y + 50.0)
	desc.modulate.a = clampf((t - GIFT_IN - GIFT_SPIN * 0.5) / 0.3, 0.0, 1.0) * (1.0 - clampf((t - t_fly) / 0.2, 0.0, 1.0))
	if t >= t_fly + GIFT_FLY + 0.05:
		(_gift.layer as Node).queue_free()
		_gift = {}
		if i < 0:
			_night_shown = true         # 夜晚那一格從現在開始露出來
		else:
			_hotbar.modulate.a = 1.0    # 真的技能欄放出來，位置和假卡片一模一樣
		if _gift_queue.is_empty():
			_hint_sel = -1              # 都介紹完了，底下那行道具說明再浮出來一次

## 地上那個表示道具範圍的白色大圓圈：這個大關先不顯示（準心和「可以互動的東西變白」就夠了）。
## 想再打開就改成 true。
const SHOW_AIM_RING := false

func _process(dt: float) -> void:
	super(dt)
	if not SHOW_AIM_RING and _preview:
		_preview.visible = false        # 共用程式每一畫面會把它打開，這裡再關掉
	_hide_texts()
	_hide_dead_bars()
	_tick_night()
	_tick_sprint()
	_keep_above_sea()
	_tick_follow(dt)
	_tick_intro(dt)
	if phase == Phase.PREPARE:
		_hold_tick(dt)        # 按 Enter 之前也能用「準備階段也能按」的按住型道具（變成晚上）
	_tick_gift(dt)
	_tick_zaps(dt)
	_tick_item_hint(dt)
	_tick_note(dt)
	_tick_star_view(dt)
	if hands:
		# 鏡頭被借走（拿星星的小過場、跟著家豪走去下一關）的時候把手收起來
		hands.show_hands(not _camera_borrowed())
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
	_stun_t = 0.0
	_held_item = null
	for s in _sand:
		s.cd = 0.0
	_sand_immune.clear()
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

## 眼睛進沙子、或是被電到的敵人：看不見、不會追人，站在原地；時間到了才恢復巡邏
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
