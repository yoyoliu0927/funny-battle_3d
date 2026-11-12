extends Node
## 搞笑特寫鏡頭：家豪被大砲射出去、或敵人掉進水裡的時候，照分鏡表連續切幾個鏡頭
## （放慢動作、上下加黑邊），播完再切回玩家（神）的視角。
##
## 這個節點只「看」戰局的狀態（每一幀比對角色的 state 有沒有變），不改戰局邏輯，
## 慢動作用 Engine.time_scale，所以每一輪的過程和結局還是一樣，只是實際播放時間變長。
## 用法：在戰局的 _ready() 裡 add_child(preload("res://scripts/closeup_cam.gd").new())。

## 分鏡表。每個事件是一串鏡頭，照順序播。每個鏡頭：
##   cam     = 鏡位（見 _frame()）
##   slow    = 慢動作倍率（1 = 正常速度）；有 slow_to 的話，這個鏡頭裡會從 slow 平順地變到 slow_to
##   fov     = 視角（越小越貼臉）
##   until   = 這個鏡頭播到飛行進度的多少（0~1，只有射出去用得到）
##   hold    = 這個鏡頭停留幾秒（真實時間）；有 until 的鏡頭不用寫
##   fov_to  = 有寫的話，視角會隨著飛行進度從 fov 慢慢變到 fov_to（拉近）
##   lines   = 速度線（效果線）的濃度，0 或不寫 = 沒有
##   caption = 字幕
##   deform  = 誇張變形的強度（0 = 不變形）
const SEQ := {
	# 射出去：「誰被什麼射出去、往哪裡飛 → 砸到誰」，中間只切一次鏡頭
	"launch": [
		# 1 背影一鏡到底：鏡頭在大砲的右後方，大砲在畫面左下，家豪往右上方飛出去；
		#   鏡頭不動、只轉頭跟著他並慢慢拉近，一路跟到最高點才換鏡頭。
		#   一開始最慢（砰的那一下），很快回到正常速度
		{"cam": "behind_follow", "slow": 0.4, "slow_to": 1.0, "fov": 62.0, "fov_to": 34.0, "until": 0.56, "caption": "砰！", "deform": 0.8, "lines": 1.0},
		# 2 落點那一頭：從倒楣鬼的側面看家豪越飛越近，一直播到砸中
		{"cam": "target", "slow": 1.0, "fov": 56.0, "until": 1.0, "caption": "", "deform": 0.35, "lines": 0.55},
		# （同一個鏡位）砸中之後停一下再切回去
		{"cam": "target", "slow": 1.0, "fov": 56.0, "hold": 0.7, "caption": "", "deform": 0.0},
	],
	# 落水：「他在追誰 → 一腳踩空 → 沉下去」
	"drown": [
		# 1 交代：從家豪背後看過去，追兵踩進水裡
		{"cam": "over_bird", "slow": 0.35, "fov": 50.0, "hold": 0.8, "caption": "", "deform": 0.3},
		# 2 主體：貼著水面看他往下沉
		{"cam": "sink", "slow": 0.5, "fov": 45.0, "hold": 1.5, "caption": "咕嚕咕嚕……", "deform": 0.0},
	],
}
const BAR_H := 0.12          # 上下黑邊各佔畫面高度的比例
const BAR_TIME := 0.18       # 黑邊滑進來的時間
const ZOOM_TIME := 0.2       # 第一個鏡頭從廣角「撞」進來的時間
const ZOOM_FROM := 14.0      # 撞進來之前寬幾度
const MAX_TIME := 7.0        # 保險：整段特寫最長幾秒

var bt: Node                 # 戰局（battle.gd）
var cam: Camera3D
var active := false
var _kind := ""
var _target = null           # 主角（射出去 = 家豪；落水 = 掉下去的敵人）
var _victim = null           # 射出去：落點附近會被砸到的人（沒有就是 null）
var _i := 0                  # 現在播到第幾個鏡頭
var _t0 := 0                 # 整段特寫開始的時間（毫秒，真實時間）
var _s0 := 0                 # 這個鏡頭開始的時間
var _fly := Vector3.FORWARD  # 射出去：水平的飛行方向
var _side := Vector3.RIGHT   # 鏡頭在動作的哪一側（靠玩家那一側，切鏡頭時左右不會顛倒）
var _prev := {}              # 每個角色上一幀的 state
var _layer: CanvasLayer
var _top: ColorRect
var _bottom: ColorRect
var _caption: Label
var _lines: SpeedLines
var _hidden: Array = []      # 特寫時暫時藏起來的 HUD
var _base_scale := Vector3.ONE   # 落水的人原本的大小（結束時還原）

func _ready() -> void:
	bt = get_parent()
	process_priority = 100   # 排在戰局之後，拿到這一幀最新的角色位置
	cam = Camera3D.new()
	cam.name = "CloseupCamera"
	cam.near = 0.05
	cam.far = 1500.0
	add_child(cam)
	_layer = CanvasLayer.new()
	_layer.layer = 20
	_layer.visible = false
	add_child(_layer)
	_lines = SpeedLines.new()
	_lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_lines)     # 在黑邊底下
	_top = _bar()
	_bottom = _bar()
	_caption = Label.new()
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.add_theme_font_size_override("font_size", 34)
	_caption.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_caption.add_theme_constant_override("outline_size", 10)
	_layer.add_child(_caption)

func _bar() -> ColorRect:
	var r := ColorRect.new()
	r.color = Color.BLACK
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(r)
	return r

func _exit_tree() -> void:
	if active:
		Engine.time_scale = 1.0

## 特寫中的滑鼠點擊不算數（看不到準心，不能讓玩家盲放神蹟）
func _input(event: InputEvent) -> void:
	if active and event is InputEventMouseButton:
		get_viewport().set_input_as_handled()

## 現在播到第幾個鏡頭（給自動測試用；沒在播是 -1）
func shot_index() -> int:
	return _i if active else -1

func _process(_dt: float) -> void:
	if bt == null or bt.bird == null:
		return
	_watch()
	if not active:
		return
	var now := Time.get_ticks_msec()
	# 重試（回到準備階段）、輸了切到晚餐畫面、或超過保險時間：收掉特寫
	if bt.phase == bt.Phase.PREPARE or bt.defeat_shown or not cam.current or (now - _t0) / 1000.0 > MAX_TIME:
		_finish()
		return
	# 這個鏡頭播完了就換下一個
	var shots: Array = SEQ[_kind]
	while _shot_done(shots[_i], now):
		if _i + 1 >= shots.size():
			_finish()
			return
		_enter_shot(_i + 1)
	var shot: Dictionary = shots[_i]
	var el := (now - _s0) / 1000.0
	if shot.has("slow_to") and shot.has("until"):
		# 變速：照這個鏡頭的進度，從 slow 平順地變到 slow_to
		var k0: float = shots[_i - 1].until if _i > 0 and shots[_i - 1].has("until") else 0.0
		var prog := clampf((_flight_k() - k0) / maxf(shot.until - k0, 0.001), 0.0, 1.0)
		Engine.time_scale = lerpf(shot.slow, shot.slow_to, prog)
	_smooth_flight()
	_deform(shot, el)
	_frame(shot)
	var z := clampf((now - _t0) / 1000.0 / ZOOM_TIME, 0.0, 1.0)
	var fov: float = shot.fov
	if shot.has("fov_to") and shot.has("until"):
		fov = lerpf(shot.fov, shot.fov_to, smoothstep(0.05, shot.until, _flight_k()))
	cam.fov = fov + ZOOM_FROM * (1.0 - z) * (1.0 - z)
	# 速度線：以家豪在畫面上的位置為中心往外放射；落地就收掉
	var flying: bool = _kind == "launch" and bt.bird.state == "launch"
	_lines.strength = shot.get("lines", 0.0) if flying else 0.0
	_lines.center = cam.unproject_position(_target.node.global_position + Vector3(0, 0.6, 0))
	_lines.queue_redraw()
	_layout((now - _t0) / 1000.0)

func _shot_done(shot: Dictionary, now: int) -> bool:
	if shot.has("until"):
		# 照飛行進度換鏡頭；已經落地也算播完
		return bt.bird.state != "launch" or _flight_k() >= shot.until
	return (now - _s0) / 1000.0 >= shot.hold

## 飛行進度 0~1。戰局是每 1/60 秒算一步，慢動作時好幾個畫面才算一步，
## 所以把「還沒算進去的零頭時間」（戰局的 _acc）也加上來，進度才會每個畫面都往前一點
func _flight_k() -> float:
	return clampf((bt.bird.t + bt._acc) / maxf(bt.launch_dur, 0.01), 0.0, 1.0)

## 慢動作時家豪的位置會一格一格跳，看起來斷斷續續。
## 這裡每個畫面用同一條拋物線公式重算他的位置（只改外觀，戰局裡的位置不動）
func _smooth_flight() -> void:
	if _kind != "launch" or bt.bird.state != "launch":
		return
	var k := _flight_k()
	var p: Vector3 = bt.launch_from.lerp(bt.launch_to, k) + Vector3.UP * bt.launch_peak * 4.0 * k * (1.0 - k)
	bt.bird.node.global_position = p

## 比對每個角色的 state，抓「剛被射出去」和「剛掉進水裡」的那一幀
func _watch() -> void:
	var all: Array = [bt.bird] + bt.farmers
	for f in all:
		var was: String = _prev.get(f, "")
		_prev[f] = f.state
		if active or was == f.state or bt.phase == bt.Phase.PREPARE or bt.defeat_shown:
			continue
		if f == bt.bird and f.state == "launch" and bt.launch_hurt:
			_begin("launch", f)
		elif f != bt.bird and f.state == "drown":
			_begin("drown", f)

func _begin(kind: String, f) -> void:
	active = true
	_kind = kind
	_target = f
	_victim = null
	_t0 = Time.get_ticks_msec()
	_base_scale = f.node.scale
	# 鏡頭擺在「玩家看過去」的那一側
	var from: Vector3 = bt.camera.global_position - f.node.global_position
	from.y = 0.0
	_side = from.normalized() if from.length() > 0.1 else Vector3.BACK
	if kind == "launch":
		_fly = bt.launch_to - bt.launch_from
		_fly.y = 0.0
		_fly = _fly.normalized() if _fly.length() > 0.1 else Vector3.FORWARD
		var lateral := _fly.cross(Vector3.UP)
		_side = lateral if lateral.dot(_side) >= 0.0 else -lateral
		# 落點附近最近的人就是倒楣鬼
		var best := 3.0
		for e in bt.farmers:
			if not e.alive():
				continue
			var d := Vector2(e.pos.x - bt.launch_to.x, e.pos.z - bt.launch_to.z).length()
			if d < best:
				best = d
				_victim = e
	_hidden.clear()
	for h in [bt._hud_layer, bt.get_node_or_null("../HUD")]:
		if h and h.visible:
			h.visible = false
			_hidden.append(h)
	_layer.visible = true
	_enter_shot(0)
	cam.fov = SEQ[kind][0].fov + ZOOM_FROM
	_smooth_flight()
	_frame(SEQ[kind][0])
	_layout(0.0)
	cam.make_current()

func _enter_shot(i: int) -> void:
	_i = i
	_s0 = Time.get_ticks_msec()
	var shot: Dictionary = SEQ[_kind][i]
	Engine.time_scale = shot.slow
	_caption.text = shot.caption

func _finish() -> void:
	active = false
	Engine.time_scale = 1.0
	_layer.visible = false
	_lines.strength = 0.0
	if _target and is_instance_valid(_target.node) and _kind == "drown":
		_target.node.scale = _base_scale
	# 中途切到別的鏡頭（例如輸了的晚餐畫面）就不要搶回來
	if cam.current:
		bt.camera.make_current()
		for h in _hidden:
			if is_instance_valid(h):
				h.visible = true
	_hidden.clear()
	_target = null
	_victim = null

## 每一幀照鏡位擺鏡頭
func _frame(shot: Dictionary) -> void:
	var p: Vector3 = _target.node.global_position
	var eye := p
	var at := p
	match shot.cam:
		"behind_follow":
			# 大砲的右後方、偏低：一開始看到的是家豪的背影，大砲在左下角，他往右上方飛
			var m: Vector3 = bt.launch_from
			var lat := _fly.cross(Vector3.UP)        # 飛行方向的右手邊
			eye = m - _fly * 3.0 + lat * 2.1 + Vector3(0, 0.7, 0)
			# 鏡頭朝飛行方向偏左一點、往上抬：大砲落在畫面左下，飛行路線往畫面右上方延伸
			var first := eye + _fly * 5.8 - lat * 1.55 + Vector3(0, 2.0, 0)
			# 接著平順地轉去跟著家豪，但不完全對準：他會一直待在畫面偏右上的位置
			var w := smoothstep(0.0, 0.3, _flight_k())
			at = first.lerp(p + Vector3(0, 0.4, 0), 0.8 * w)
		"target":
			# 落點那一頭：鏡頭在倒楣鬼的正側面（和第一鏡同一側，左右方向不變），
			# 畫面一邊是他、另一邊是越飛越近的家豪；沒有倒楣鬼就拍落點
			var t: Vector3 = bt.launch_to
			var head := 0.6
			if _victim != null:
				t = _victim.node.global_position
				head = 1.6
			eye = t + _side * 7.5 + _fly * 0.8 + Vector3(0, 2.8, 0)
			at = (t + Vector3(0, head, 0)).lerp(p + Vector3(0, 0.7, 0), 0.3)
		"over_bird":
			# 從家豪背後看過去：前景是家豪，後面是踩進水裡的追兵
			var b: Vector3 = bt.bird.node.global_position
			var d := p - b
			d.y = 0.0
			if d.length() < 0.5 or d.length() > 14.0:
				_frame({"cam": "sink"})   # 離太遠就直接拍落水的人
				return
			d = d.normalized()
			var perp := d.cross(Vector3.UP)
			eye = b - d * 3.2 + perp * 1.3 + Vector3(0, 2.1, 0)
			at = Vector3(p.x, _target.pos.y, p.z) + Vector3(0, 1.3, 0)
		_:
			# sink：人往下沉，鏡頭留在水面
			p.y = _target.pos.y
			eye = p + _side * 5.2 + Vector3(0, 2.3, 0)
			at = p + Vector3(0, 1.4, 0)
	# 不要鑽進地底
	eye.y = maxf(eye.y, bt.world.height_at(eye.x, eye.z) + 0.4)
	cam.global_position = eye
	if eye.distance_to(at) > 0.05:
		cam.look_at(at, Vector3.UP)

## 誇張變形（只改外觀，不影響戰局）
func _deform(shot: Dictionary, el: float) -> void:
	var amt: float = shot.get("deform", 0.0)
	if _kind == "launch":
		# 飛行中：頭朝前的「飛彈」姿勢，沿著飛行方向拉長、身體變細
		# （戰局每 1/60 秒會把身體擺回去，所以這裡每一幀重新蓋上去）
		var body: Node3D = _target.body
		if body == null or _target.state != "launch" or amt <= 0.0:
			return
		var k := amt * (0.6 + 0.4 * exp(-el * 5.0))
		# 頭朝著軌跡的切線方向：上升時抬頭、過了最高點慢慢低頭、落下時頭朝下
		var fk := _flight_k()
		var horiz := Vector2(bt.launch_to.x - bt.launch_from.x, bt.launch_to.z - bt.launch_from.z).length()
		var vy: float = (bt.launch_to.y - bt.launch_from.y) + bt.launch_peak * 4.0 * (1.0 - 2.0 * fk)
		body.rotation = Vector3(PI * 0.5 - atan2(vy, maxf(horiz, 0.01)), 0.0, 0.0)
		body.scale = Vector3(1.0 - 0.3 * k, 1.0 + k, 1.0 - 0.3 * k)
	elif amt > 0.0:
		# 落水：先壓扁，再像果凍一樣彈幾下
		var w := amt * exp(-el * 2.2) * cos(el * 16.0)
		_target.node.scale = _base_scale * Vector3(1.0 + 0.6 * w, 1.0 - w, 1.0 + 0.6 * w)
	else:
		_target.node.scale = _base_scale

## 黑邊和字幕（依視窗大小排）
func _layout(el: float) -> void:
	var size := get_viewport().get_visible_rect().size
	var k := clampf(el / BAR_TIME, 0.0, 1.0)
	var h := size.y * BAR_H * k
	_top.position = Vector2.ZERO
	_top.size = Vector2(size.x, h)
	_bottom.position = Vector2(0, size.y - h)
	_bottom.size = Vector2(size.x, h)
	_caption.position = Vector2(0, size.y * (1.0 - BAR_H) - 64.0)
	_caption.size = Vector2(size.x, 48.0)
	_lines.position = Vector2.ZERO
	_lines.size = size

## 速度線（漫畫的集中線）：一圈白色細長三角形，從畫面外圍指向中心，每隔一下子換一批
class SpeedLines extends Control:
	var center := Vector2.ZERO
	var strength := 0.0

	func _draw() -> void:
		if strength <= 0.0:
			return
		var rng := RandomNumberGenerator.new()
		rng.seed = int(Time.get_ticks_msec() / 50)
		var reach := size.length()
		for i in 44:
			var a := rng.randf() * TAU
			var d := Vector2(cos(a), sin(a))
			var n := Vector2(-d.y, d.x)
			var inner := reach * rng.randf_range(0.2, 0.42)
			var half := reach * rng.randf_range(0.003, 0.011)
			var tip := center + d * inner
			var far := center + d * reach
			draw_colored_polygon(PackedVector2Array([tip, far + n * half, far - n * half]), Color(1, 1, 1, 0.5 * strength))
