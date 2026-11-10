extends Node
## 第一關：農場大門
##
## 家豪從農場大門外出發，會自己衝進去找最近的農夫打。三個農夫守在不同位置，
## 看到雞或聽到同伴打起來就會圍過來。什麼都不做的話，雞會被圍毆到倒下。
##
## 玩家是神，用畫面下方的神蹟技能欄幫牠（按 1 / 2 / 3 切換，左鍵施放在準心指到的地面）：
##   1 飼料：在地上撒一把飼料，雞會傻傻地跑去吃（吃一把回 1 滴血），可以用來帶路、拖時間、把牠引開
##   2 香蕉皮：丟在地上，走過去的人（家豪和農夫都會）踩到就滑倒，躺在地上一段時間
##   3 巨石：放在地上（有人站的地方不能放）；放在斜坡上會順著坡滾下去，沿路撞到誰就傷誰；
##           瞄準時會畫出預測的滾動路徑
##   三個神蹟都有冷卻時間，依序越來越長
##
## 大穀倉最裡面坐著老闆：家豪一靠近就開槍，家豪被打中會嚇得逃走，正面打不到他。
## 要打倒老闆得靠骨牌：從台地放巨石撞倒水塔，五座水塔一座接一座倒，最後砸垮大穀倉。
##
## 戰局可重演：角色邏輯只跑在固定步長的 _physics_process，沒有亂數。
## 按鍵：Enter 開始｜R 重試（保留觀察位置）

signal phase_changed(phase: String)

enum Phase { PREPARE, RUNNING, ENDED }

const BIRD_MAX_HP := 10.0
const FARMER_MAX_HP := 8.0
const KICK_DAMAGE := 2.0
const HEAVY_DAMAGE := 4.0
const PECK_DAMAGE := 2.5
const VISION_RANGE := 7.0     # 農夫前方偵測區（紅色扇形）的長度
const VISION_HALF := deg_to_rad(50.0)   # 偵測區半角
const BOSS_RANGE := 11.0       # 老闆開槍的距離
const BOSS_AIM := 0.5          # 瞄準時間
const BOSS_COOLDOWN := 1.4
const TOWER_GRAVITY := 2.6     # 水塔倒下的角加速度
const BARN_HIT_RADIUS := 4.8   # 水塔倒到這麼近就算砸中大穀倉
const SNEAK_MULT := 1.0        # 偷襲不加傷害，只會讓農夫嚇一跳愣住
const STARTLE_TIME := 1.1      # 被偷襲嚇一跳、愣住的時間
const ALERT_RADIUS := 11.0     # 打鬥聲傳得到的距離：哪裡有人挨打，這個距離內的農夫會趕過來
const FLY_TIME := 1.15
const FLY_PEAK := 1.7
const HOP_TIME := 0.7          # 飛越圍欄的小跳
const FENCE_CLEAR := 1.0

## 神蹟設定
const SKILLS := [
	# charges = -1 代表不限次數（目前先不限）
	# cooldown = 用一次之後要等幾秒才能再用
	{"id": "feed", "name": "飼料", "key": "1", "charges": -1, "cooldown": 1.5, "radius": 0.6, "color": Color(1.0, 0.85, 0.3)},
	{"id": "banana", "name": "香蕉皮", "key": "2", "charges": -1, "cooldown": 4.0, "radius": 0.5, "color": Color(1.0, 0.9, 0.25)},
	{"id": "rock", "name": "巨石", "key": "3", "charges": -1, "cooldown": 8.0, "radius": 0.9, "color": Color(0.85, 0.85, 0.8)},
]
const PEEL_RADIUS := 0.55      # 走到香蕉皮這麼近就會踩到
const SLIP_TIME := 3.0         # 滑倒後躺在地上的時間
const ROCK_RADIUS := 0.9
const ROCK_HIT_RADIUS := 1.45  # 巨石中心離角色多近算撞到
const ROCK_MIN_HIT_SPEED := 1.5
const ROCK_CLEAR := 1.9        # 放置點這個距離內有人就不能放
const ROLL_GRAVITY := 9.0
const ROLL_RESIST := 3.2       # 滾動阻力（m/s²）
const ROLL_MAX_SPEED := 9.0
const ROCK_DAMAGE_FARMER := 999.0   # 巨石撞到農夫一次就倒
const ROCK_DAMAGE_BIRD := 4.0       # 撞到家豪會扣血，但不會一下撞死（最少留 1 滴）
const FEED_SENSE := 10.0
const FEED_EAT_TIME := 0.9
const FEED_LINGER := 3.0       # 吃完飼料後，家豪會在原地意猶未盡地東張西望這麼久才繼續衝
const LIGHT_TIME := 5.0
const LIGHT_HEAL := 2.0        # 每秒
const FEED_HEAL := 1.0         # 吃一把飼料回的血

var phase: Phase = Phase.PREPARE
var time := 0.0
var outcome := ""
var events: Array = []
var attempts: Array = []
var hit_spots: Array = []

var world: Node
var chars: Node
var player: Node3D
var camera: Camera3D
var crosshair: Control

var bird: Fighter
var farmers: Array = []        # Array[Fighter]（最後一個是老闆）
var boss: Fighter

# 骨牌：水塔與大穀倉
var towers: Array = []         # {node, pos, radius, height, state, angle, omega, dir, crushed}
var barn_state := "stand"      # stand / collapse / down
var barn_t := 0.0
var _barn_xf: Transform3D
var _fx_timed: Array = []      # 會自己消失的特效 {node, t, life, kind}
var _enemy_rows: Array = []
# 示範石頭：一開始放在台地斜坡頂端，開打後一下下就自己滑下來，讓玩家想到巨石可以放在坡上
const DEMO_ROCK_START := Vector3(10.4, 0, 4.2)
const DEMO_ROCK_DELAY := 2.5
const DEMO_ROCK_RADIUS := 0.5   # 示範石頭比巨石小一號
var demo_rock: MeshInstance3D
var demo_path := PackedVector3Array()
var demo_i := 0   # 右上角敵人欄 {fighter, face, fill, chip, name}

# 神蹟狀態
var selected := 0
var charges: Array = []
var casts: Array = []          # 本輪施放紀錄 {t, id, pos}
var feeds: Array = []          # {pos, node}
var rocks: Array = []          # {path, i, node, done, hit}
var lights: Array = []         # {pos, t, node}（舊的聖光，現在沒用到）
var peels: Array = []          # 香蕉皮 {pos, node}
var cooldowns: Array = []      # 每個神蹟剩下的冷卻秒數
var no_cooldown := false       # 自動驗收用：跳過冷卻
var _last_pos := {}            # 每個角色上一步的位置（判斷有沒有在走）
var aim_point: Variant = null
var _preview: MeshInstance3D
var _dots: Array = []          # 預測路徑的小點
var _path_cache_at := Vector3(INF, INF, INF)
var _path_cache := PackedVector3Array()
var aim_error := ""
var _fx_root: Node3D

# HUD
var _phase_label: Label
var _toast_label: Label
var _summary_panel: PanelContainer
var _summary_label: Label
var _toast_t := 0.0
var _hotbar: Hotbar
var _dialog: DialogBox
var _napoleon_tex: Texture2D
# 開場教學：箭頭依序指著技能欄的每一格，旁邊一小段說明
const TUT_STEP_TIME := 5.5
const TUT_TEXT := [
	"【1 飼料】撒在地上，家豪會忍不住跑去吃，吃一把回一點血。\n用它把家豪引到你想要的地方。",
	"【2 香蕉皮】丟在路上，走過去踩到就會滑倒，躺在地上好一陣子。\n小心，家豪自己也會踩到。",
	"【3 巨石】一顆圓滾滾的大石頭。\n或許可以讓它自己滾起來？",
]
var tutorial_step := -1        # -1 = 沒在教學
var _tut_t := 0.0
var _tut_seen := false
var _tut_arrow: TutArrow
var _tut_panel: PanelContainer
var _tut_label: Label
var _hud_layer: CanvasLayer
# 輸了的畫面
const DEFEAT_ORIGIN := Vector3(600.0, 0.0, 600.0)
var defeat_room: Node3D
var defeat_shown := false
var _defeat_delay := -1.0
var _defeat_layer: CanvasLayer
var _defeat_label: Label
var _defeat_detail: Label

# ------------------------------------------------------------------ 角色資料

class Fighter:
	var name := ""
	var node: Node3D
	var is_bird := false
	var max_hp := 10.0
	var hp := 10.0
	var speed := 2.0
	var reach := 1.0
	var windup := 0.3
	var recover := 0.8
	var state := "idle"
	var t := 0.0
	var pos := Vector3.ZERO
	var start_pos := Vector3.ZERO
	var start_yaw := 0.0
	var yaw := 0.0
	var kb_vel := Vector3.ZERO
	var air := 0.0
	var anim: AnimationPlayer
	var body: Node3D
	var wings: Array = []
	var heavy := false
	var attack_n := 0
	var fled_half := false
	var fly_from := Vector3.ZERO
	var fly_to := Vector3.ZERO
	var fly_dur := 1.0
	var fly_peak := 1.0
	var after_fly := ""
	var detouring := false
	var chased := false
	# 農夫專用
	var route: Array = []
	var loop := true
	var pause := 1.0
	var wp := 1
	var wp_dir := 1
	var look_yaw := 0.0
	var cone: MeshInstance3D
	var is_boss := false
	var shoot_cd := 0.0
	var gun: Node3D
	var aggro := false
	var alert_t := -1.0
	var target: Fighter
	var feed_target := -1
	# 血條
	var bar: Control
	var bar_fill: ColorRect
	var bar_chip: ColorRect
	var chip := 1.0

	func set_state(s: String) -> void:
		state = s
		t = 0.0

	func alive() -> bool:
		return state != "dead" and state != "drown"

	func ratio() -> float:
		return clampf(hp / max_hp, 0.0, 1.0)

## 右上角敵人欄的頭像（用畫的：農夫戴草帽、老闆戴深色帽子和眼鏡）
class EnemyFace extends Control:
	var boss := false
	var dead := false

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color(0.1, 0.11, 0.13, 0.8))
		draw_rect(r, Color(1, 0.85, 0.4, 0.9) if boss else Color(1, 1, 1, 0.35), false, 3.0 if boss else 2.0)
		var c := size * Vector2(0.5, 0.58)
		var k := size.x / 56.0
		var skin := Color(0.96, 0.78, 0.62)
		draw_circle(c, 15 * k, skin)
		# 帽子
		var hat := Color(0.25, 0.2, 0.18) if boss else Color(0.92, 0.82, 0.55)
		draw_rect(Rect2(c + Vector2(-20, -16) * k, Vector2(40, 5) * k), hat)
		draw_rect(Rect2(c + Vector2(-11, -27) * k, Vector2(22, 12) * k), hat)
		if not boss:
			draw_rect(Rect2(c + Vector2(-11, -19) * k, Vector2(22, 3) * k), Color(0.8, 0.25, 0.2))
		# 眼睛 / 眼鏡、嘴、鬍子
		if boss:
			for sx in [-1.0, 1.0]:
				draw_arc(c + Vector2(6 * sx, -2) * k, 4.5 * k, 0, TAU, 16, Color(0.1, 0.1, 0.1), 2.0 * k)
			draw_line(c + Vector2(-1.5, -2) * k, c + Vector2(1.5, -2) * k, Color(0.1, 0.1, 0.1), 2.0 * k)
			draw_rect(Rect2(c + Vector2(-7, 6) * k, Vector2(14, 3) * k), Color(0.35, 0.22, 0.15))
		else:
			for sx in [-1.0, 1.0]:
				draw_circle(c + Vector2(6 * sx, -2) * k, 2.0 * k, Color(0.12, 0.1, 0.1))
			draw_line(c + Vector2(-5, 7) * k, c + Vector2(5, 7) * k, Color(0.55, 0.3, 0.25), 2.0 * k)
		if dead:
			draw_rect(r, Color(0.1, 0.1, 0.1, 0.55))
			draw_line(Vector2(8, 8) * k, size - Vector2(8, 8) * k, Color(0.95, 0.3, 0.25), 4.0 * k)
			draw_line(Vector2(size.x - 8 * k, 8 * k), Vector2(8 * k, size.y - 8 * k), Color(0.95, 0.3, 0.25), 4.0 * k)

## 技能欄的一格
## 方塊遊戲風格的快捷欄：一整條相連的格子，選中的那格外面套一圈粗白框，圖示用像素點畫
class Hotbar extends Control:
	const S := 84.0          # 一格的大小
	const PX := 4.0          # 圖示一個像素的大小
	var skills: Array = []
	var counts: Array = []
	var cooldowns: Array = []
	var selected := 0
	var name_t := 0.0        # 切換後在上方顯示技能名稱的剩餘時間

	func bar_size() -> Vector2:
		return Vector2(skills.size() * S + 4.0, S + 4.0)

	func _process(dt: float) -> void:
		if name_t > 0.0:
			name_t = maxf(name_t - dt, 0.0)
			queue_redraw()

	func _draw() -> void:
		var bs := bar_size()
		# 整條外框
		draw_rect(Rect2(Vector2.ZERO, bs), Color(0.05, 0.05, 0.05, 0.8))
		for i in skills.size():
			var cell := Rect2(Vector2(2.0 + i * S, 2.0), Vector2(S, S))
			# 格子邊框（淺灰）＋ 內部半透明深色
			draw_rect(cell, Color(0.56, 0.56, 0.56, 0.95))
			var inner := cell.grow(-4.0)
			draw_rect(inner, Color(0.16, 0.18, 0.16, 0.82))
			# 內凹的立體感：左上暗、右下亮
			draw_rect(Rect2(inner.position, Vector2(inner.size.x, 3)), Color(0.08, 0.08, 0.08, 0.9))
			draw_rect(Rect2(inner.position, Vector2(3, inner.size.y)), Color(0.08, 0.08, 0.08, 0.9))
			draw_rect(Rect2(inner.position + Vector2(0, inner.size.y - 3), Vector2(inner.size.x, 3)), Color(0.4, 0.4, 0.4, 0.9))
			draw_rect(Rect2(inner.position + Vector2(inner.size.x - 3, 0), Vector2(3, inner.size.y)), Color(0.4, 0.4, 0.4, 0.9))
			var cnt: int = counts[i] if i < counts.size() else 0
			var cd: float = cooldowns[i] if i < cooldowns.size() else 0.0
			_draw_icon(skills[i].id, cell.get_center(), cnt == 0)
			if cd > 0.0:
				# 冷卻中：一片暗色從上往下縮短，中間顯示剩下的秒數
				var frac := clampf(cd / float(skills[i].cooldown), 0.0, 1.0)
				draw_rect(Rect2(inner.position + Vector2(0, inner.size.y * (1.0 - frac)), Vector2(inner.size.x, inner.size.y * frac)), Color(0, 0, 0, 0.6))
				var ft := get_theme_default_font()
				var ct := "%.1f" % cd if cd < 10.0 else "%d" % ceili(cd)
				var cw := ft.get_string_size(ct, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
				_shadow_text(ft, cell.get_center() + Vector2(-cw * 0.5, 9), ct, 26, Color(1, 1, 1))
			var font := get_theme_default_font()
			# 左上角小小的按鍵數字
			_shadow_text(font, cell.position + Vector2(9, 24), skills[i].key, 17, Color(0.85, 0.85, 0.85))
			# 右下角數量（方塊遊戲的堆疊數字）
			var txt := "∞" if cnt < 0 else str(cnt)
			var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
			_shadow_text(font, cell.position + Vector2(S - 10 - tw, S - 10), txt, 24, Color(1, 1, 1) if cnt != 0 else Color(1, 0.35, 0.3))
		# 選中的格子：粗白框，比格子大一圈、蓋在相鄰格子上
		var sel := Rect2(Vector2(2.0 + selected * S, 2.0), Vector2(S, S)).grow(4.0)
		draw_rect(sel, Color(0.05, 0.05, 0.05, 0.95), false, 10.0)
		draw_rect(sel.grow(-2.0), Color(0.93, 0.93, 0.93), false, 6.0)
		draw_rect(sel.grow(-5.0), Color(0.62, 0.62, 0.62), false, 1.0)
		# 切換時在上方浮出技能名稱
		if name_t > 0.0 and selected < skills.size():
			var font := get_theme_default_font()
			var nm: String = skills[selected].name
			var a := clampf(name_t / 0.5, 0.0, 1.0)
			var w := font.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
			_shadow_text(font, Vector2((bs.x - w) * 0.5, -16), nm, 26, Color(1, 1, 1, a))

	func _shadow_text(font: Font, pos: Vector2, txt: String, fs: int, col: Color) -> void:
		draw_string(font, pos + Vector2(2, 2), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.15, 0.15, 0.15, col.a))
		draw_string(font, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)

	func _px(c: Vector2, x: int, y: int, col: Color) -> void:
		draw_rect(Rect2(c + Vector2(x, y) * PX, Vector2(PX, PX)), col)

	## 12×12 的像素圖示（左上角是 c - 6 格）
	func _draw_icon(id: String, center: Vector2, empty: bool) -> void:
		var c := center - Vector2(6, 6) * PX
		var dim := 0.55 if empty else 0.0
		match id:
			"rock":
				for y in 12:
					for x in 12:
						var d := Vector2(x - 5.5, y - 5.8).length()
						if d > 5.6:
							continue
						var light := clampf(0.5 - (x + y - 11) * 0.06, 0.0, 1.0)
						var col := Color(0.4, 0.41, 0.43).lerp(Color(0.82, 0.83, 0.84), light)
						if d > 4.7:
							col = Color(0.22, 0.22, 0.24)
						elif (x * 7 + y * 3) % 11 == 0:
							col = col.darkened(0.18)
						_px(c, x, y, col.darkened(dim))
				_px(c, 3, 3, Color(0.95, 0.95, 0.95).darkened(dim))
				_px(c, 4, 3, Color(0.92, 0.92, 0.92).darkened(dim))
			"feed":
				# 一小堆飼料粒：深淺黃色像素
				var grains := [[5, 2], [7, 3], [3, 4], [6, 5], [8, 5], [2, 6], [4, 6], [10, 6], [5, 7], [7, 7], [9, 7],
					[1, 8], [3, 8], [6, 8], [8, 8], [10, 8], [2, 9], [4, 9], [5, 9], [7, 9], [9, 9], [3, 10], [6, 10], [8, 10]]
				for k in grains.size():
					var g: Array = grains[k]
					var col := Color(1.0, 0.86, 0.3) if k % 3 != 0 else Color(0.86, 0.6, 0.15)
					_px(c, g[0], g[1], col.darkened(dim))
					if k % 4 == 0:
						_px(c, g[0], g[1] + 1, Color(0.6, 0.4, 0.1).darkened(dim))
			"banana":
				# 一片攤開的香蕉皮：黃色三瓣、中間一點咖啡色
				var pts := [[5, 1], [6, 1], [5, 2], [6, 2], [5, 3], [6, 3], [5, 4], [6, 4],
					[4, 5], [5, 5], [6, 5], [7, 5], [3, 6], [4, 6], [5, 6], [6, 6], [7, 6], [8, 6],
					[2, 7], [3, 7], [4, 7], [7, 7], [8, 7], [9, 7], [1, 8], [2, 8], [3, 8], [8, 8], [9, 8], [10, 8],
					[1, 9], [2, 9], [9, 9], [10, 9], [5, 7], [6, 7], [5, 8], [6, 8]]
				for q in pts:
					var col := Color(1.0, 0.88, 0.25)
					if q[1] <= 2 or (q[0] + q[1]) % 5 == 0:
						col = Color(0.95, 0.72, 0.12)
					if q[0] in [5, 6] and q[1] >= 7:
						col = Color(1.0, 0.97, 0.75)
					_px(c, q[0], q[1], col.darkened(dim))
				_px(c, 5, 0, Color(0.4, 0.26, 0.1).darkened(dim))
				_px(c, 6, 0, Color(0.4, 0.26, 0.1).darkened(dim))
				_px(c, 1, 10, Color(0.4, 0.26, 0.1).darkened(dim))
				_px(c, 10, 10, Color(0.4, 0.26, 0.1).darkened(dim))

## 開場教學用的白色大箭頭（往下指，粗粗方方的）
class TutArrow extends Control:
	func _draw() -> void:
		var w := size.x
		var h := size.y
		var shaft := Rect2(Vector2(w * 0.5 - 7, 0), Vector2(14, h - 26))
		var head := PackedVector2Array([Vector2(w * 0.5 - 26, h - 30), Vector2(w * 0.5 + 26, h - 30), Vector2(w * 0.5, h)])
		# 黑色外框
		draw_rect(shaft.grow(3), Color(0.1, 0.1, 0.1, 0.85))
		var ho := PackedVector2Array([Vector2(w * 0.5 - 32, h - 33), Vector2(w * 0.5 + 32, h - 33), Vector2(w * 0.5, h + 5)])
		draw_colored_polygon(ho, Color(0.1, 0.1, 0.1, 0.85))
		draw_rect(shaft, Color(1, 1, 1))
		draw_colored_polygon(head, Color(1, 1, 1))

## 畫面中下方的對話框：左邊家豪的頭像、右邊文字，自己滑上來、停一下、再自己滑下去
## 可以另外帶一張圖放在右側，圖比框高，會超出框外
class DialogBox extends Control:
	const W := 760.0
	const H := 120.0
	const SHOW_TIME := 3.2
	var text := ""
	var pic: Texture2D
	var portrait: Texture2D
	var t := -1.0          # <0 表示沒在顯示

	func say(s: String, tex: Texture2D = null) -> void:
		text = s
		pic = tex
		t = 0.0
		visible = true
		queue_redraw()

	func showing() -> bool:
		return t >= 0.0

	func _process(dt: float) -> void:
		if t < 0.0:
			return
		t += dt
		if t >= SHOW_TIME:
			t = -1.0
			visible = false
		queue_redraw()

	func _draw() -> void:
		if t < 0.0:
			return
		# 進場 0.25 秒、出場 0.3 秒：上下滑動＋淡入淡出
		var k_in := clampf(t / 0.25, 0.0, 1.0)
		var k_out := clampf((SHOW_TIME - t) / 0.3, 0.0, 1.0)
		var k := minf(k_in, k_out)
		var e := 1.0 - pow(1.0 - k, 3.0)
		var off := Vector2((size.x - W) * 0.5, (1.0 - e) * 50.0)
		var a := e
		var box := Rect2(off, Vector2(W, H))
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.07, 0.07, 0.09, 0.45 * a)   # 半透明，看得到後面的場景
		sb.border_color = Color(1, 1, 1, 0.6 * a)
		sb.set_border_width_all(4)
		sb.set_corner_radius_all(10)
		draw_style_box(sb, box)
		# 左邊：家豪的頭像（圓形大頭照，外面一圈白框）
		var pc := off + Vector2(70, H * 0.5)
		draw_circle(pc, 50, Color(1, 1, 1, 0.85 * a))
		if portrait:
			draw_texture_rect(portrait, Rect2(pc - Vector2(47, 47), Vector2(94, 94)), false, Color(1, 1, 1, a))
		# 右邊：文字
		var font := get_theme_default_font()
		var fs := 34
		var tx := off.x + 140.0
		var avail := W - 150.0 - (190.0 if pic else 20.0)
		var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		while tw > avail and fs > 18:
			fs -= 2
			tw = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var ty := off.y + H * 0.5 + fs * 0.35
		draw_string(font, Vector2(tx + 3, ty + 3), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.8 * a))
		draw_string(font, Vector2(tx, ty), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, a))
		# 右側的圖：底部貼著框底，往上超出框外
		if pic:
			var ph := 210.0
			var pw := ph * float(pic.get_width()) / float(pic.get_height())
			var pr := Rect2(Vector2(off.x + W - pw + 40.0, off.y + H - ph + 8.0), Vector2(pw, ph))
			draw_texture_rect(pic, pr, false, Color(1, 1, 1, a))

# ------------------------------------------------------------------ 初始化

func _ready() -> void:
	world = get_node("../World")
	chars = world.get_node("Characters")
	player = get_node("../Player")
	camera = player.get_node("Head/Camera3D")
	crosshair = get_node_or_null("../HUD/Crosshair")
	_fx_root = Node3D.new()
	_fx_root.name = "MiracleFX"
	world.add_child(_fx_root)
	_ensure_actions()
	_build_fighters()
	_build_preview()
	_build_hud()
	_build_defeat()
	reset()
	if not "--autotest" in OS.get_cmdline_user_args():
		start_tutorial()

func _ensure_actions() -> void:
	var map := {
		"battle_start": [KEY_ENTER, KEY_KP_ENTER], "battle_reset": [KEY_R], "back_to_map": [KEY_M],
		"skill_1": [KEY_1, KEY_KP_1], "skill_2": [KEY_2, KEY_KP_2], "skill_3": [KEY_3, KEY_KP_3],
	}
	for action in map:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			for k in map[action]:
				var ev := InputEventKey.new()
				ev.physical_keycode = k
				InputMap.action_add_event(action, ev)

func _build_fighters() -> void:
	bird = Fighter.new()
	bird.name = "家豪"
	bird.node = chars.hero
	bird.is_bird = true
	bird.max_hp = BIRD_MAX_HP
	bird.speed = 3.2
	bird.reach = 1.05
	bird.windup = 0.3
	bird.recover = 0.75
	bird.start_pos = _ground(world.hero_start)
	bird.start_yaw = PI   # 面向農場（-Z）
	bird.body = chars.hero.get_node_or_null("Body")
	if bird.body:
		for w in ["WingL", "WingR"]:
			var n := bird.body.find_child(w, true, false)
			if n:
				bird.wings.append(n)

	var routes: Array = world.farmer_routes
	for i in chars.enemies.size():
		var f := Fighter.new()
		f.name = "農夫%d" % (i + 1)
		f.node = chars.enemies[i]
		f.max_hp = FARMER_MAX_HP
		f.speed = 1.7
		f.reach = 1.75
		f.windup = 0.45
		f.recover = 1.0
		if i >= routes.size():
			# 老闆：站在辦公桌後面，不巡邏、沒有偵測區，打不到
			f.name = "老闆"
			f.is_boss = true
			f.max_hp = 99.0
			f.start_pos = _ground(world.boss_post)
			f.start_yaw = 0.0
			f.route = [f.start_pos, f.start_pos]
			f.gun = f.node.find_child("Gun", true, false)   # 胖商人模型自帶的槍
			boss = f
		else:
			for p in routes[i].route:
				f.route.append(_ground(p))
			f.loop = routes[i].loop
			f.pause = routes[i].pause
			f.start_pos = f.route[0]
			f.start_yaw = _yaw_to(f.route[0], f.route[1])
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
		farmers.append(f)
	# 骨牌
	for t in world.towers:
		towers.append({"node": t.node, "pos": t.pos, "radius": t.radius, "height": t.height,
			"state": "stand", "angle": 0.0, "omega": 0.0, "dir": Vector3.FORWARD, "crushed": false})
	_barn_xf = world.barn_node.transform
	demo_rock = MeshInstance3D.new()
	demo_rock.name = "DemoRock"
	var drng := RandomNumberGenerator.new()
	drng.seed = 999
	demo_rock.mesh = world.make_rock_mesh(drng, 3, 0.08)
	demo_rock.material_override = world._rock_material
	demo_rock.scale = Vector3.ONE * DEMO_ROCK_RADIUS
	world.add_child(demo_rock)

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

# ------------------------------------------------------------------ 狀態切換

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
	for s in SKILLS:
		charges.append(s.charges)
		cooldowns.append(0.0)
	for c in _fx_root.get_children():
		c.queue_free()
	feeds.clear()
	rocks.clear()
	lights.clear()
	peels.clear()
	_last_pos.clear()
	for t in towers:
		t.state = "stand"
		t.angle = 0.0
		t.omega = 0.0
		t.crushed = false
		(t.node as Node3D).basis = Basis()
	barn_state = "stand"
	barn_t = 0.0
	demo_path = simulate_roll(_ground(DEMO_ROCK_START))
	demo_i = 0
	demo_rock.rotation = Vector3.ZERO
	demo_rock.position = (demo_path[0] if demo_path.size() > 0 else _ground(DEMO_ROCK_START)) - Vector3(0, ROCK_RADIUS - DEMO_ROCK_RADIUS, 0)
	world.barn_node.transform = _barn_xf
	_fx_timed.clear()
	for f in [bird] + farmers:
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
		f.set_state("idle")
		_anim(f, "Idle")
	_apply_visuals()
	_summary_panel.visible = false
	_hide_defeat()
	_toast("", 0.0)
	_update_phase_label()
	_refresh_slots()
	phase_changed.emit("prepare")

func start() -> void:
	if phase != Phase.PREPARE:
		return
	phase = Phase.RUNNING
	bird.set_state("charge")
	for f in farmers:
		f.set_state("boss" if f.is_boss else "patrol")   # 一開打就各自開始巡邏
	_log("開始")
	_update_phase_label()
	phase_changed.emit("running")

func _end(result: String) -> void:
	phase = Phase.ENDED
	outcome = result
	_log("勝利" if result == "win" else "落敗")
	if result == "win":
		if not "--autotest" in OS.get_cmdline_user_args():   # 自動驗收不動到玩家的存檔
			preload("res://scripts/progress.gd").mark_cleared(1)   # 第 1 關攻下了，地圖上會插上綠旗
		bird.set_state("cheer")
		bird.air = 0.0
	else:
		for f in farmers:
			if f.alive():
				_anim(f, "Wave")
	var used := {}
	for c in casts:
		used[c.id] = used.get(c.id, 0) + 1
	attempts.append({"num": attempts.size() + 1, "outcome": result, "time": time, "used": used,
		"left": farmers.filter(func(f): return f.alive()).size()})
	_show_summary()
	if result == "lose":
		_summary_panel.visible = false
		_defeat_delay = 1.6   # 先看家豪倒下，再切到晚餐畫面
	_update_phase_label()
	phase_changed.emit("ended")

# ------------------------------------------------------------------ 輸入與神蹟

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("battle_start"):
		start()
	elif event.is_action_pressed("battle_reset"):
		reset()
	elif event.is_action_pressed("back_to_map"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_tree().change_scene_to_file("res://scenes/level_select.tscn")
	elif event.is_action_pressed("skill_1"):
		select_skill(0)
	elif event.is_action_pressed("skill_2"):
		select_skill(1)
	elif event.is_action_pressed("skill_3"):
		select_skill(2)
	elif event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		# 滾輪換技能：游標有沒有鎖住都可以（觸控板滑動剛觸發過就不重複算）
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

const PAN_STEP := 3.0
var _pan_acc := 0.0
var _pan_ms := -100000

## 滾輪往下 = 下一格，往上 = 上一格（頭尾相接）
func _wheel_step(d: int) -> void:
	select_skill((selected + d + SKILLS.size()) % SKILLS.size())
	if _hotbar:
		_hotbar.name_t = 2.0

func select_skill(i: int) -> void:
	selected = clampi(i, 0, SKILLS.size() - 1)
	_refresh_slots()

func _update_aim() -> void:
	aim_point = world.ray_ground(camera.global_position, -camera.global_basis.z, 70.0)

## 在準心指到的地面施放目前選的神蹟
func try_cast() -> bool:
	_update_aim()
	if aim_point == null:
		_toast("準心要指到地面", 1.2)
		return false
	return cast(selected, aim_point)

## 這裡能不能放這個神蹟；可以回傳空字串，不行回傳原因
func placement_error(i: int, p: Vector3) -> String:
	var id: String = SKILLS[i].id
	if id == "rock":
		if not world.rock_ground(p.x, p.z):
			return "這裡放不了"
		for f in [bird] + farmers:
			if f.alive() and _flat_dist(f.pos, p) < ROCK_CLEAR:
				return "那裡有人，巨石放不下去"
		for r in rocks:
			if not r.done:
				return "上一顆巨石還在滾"
		return ""
	if world.in_water(p.x, p.z):
		return "不能放在水裡"
	if not world.walkable(p.x, p.z):
		return "這裡放不了"
	return ""

func cast(i: int, p: Vector3) -> bool:
	if phase == Phase.ENDED:
		return false
	if charges[i] == 0:
		_toast("%s 用完了" % SKILLS[i].name, 1.4)
		return false
	if not no_cooldown and i < cooldowns.size() and cooldowns[i] > 0.0:
		_toast("%s 還要等 %.1f 秒" % [SKILLS[i].name, cooldowns[i]], 1.0)
		return false
	var err := placement_error(i, p)
	if err != "":
		_toast(err, 1.4)
		return false
	if charges[i] > 0:
		charges[i] -= 1
	if not no_cooldown:
		cooldowns[i] = SKILLS[i].cooldown
	var id: String = SKILLS[i].id
	casts.append({"t": time, "id": id, "pos": p})
	_log("神降下%s（%.1f, %.1f）" % [SKILLS[i].name, p.x, p.z])
	match id:
		"rock":
			_spawn_rock(p)
		"feed":
			_spawn_feed(p)
		"banana":
			_spawn_peel(p)
	_refresh_slots()
	return true

func _spawn_rock(p: Vector3) -> void:
	var rock := MeshInstance3D.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242 + rocks.size()
	rock.mesh = world.make_rock_mesh(rng, 3, 0.08)
	rock.material_override = world._rock_material
	rock.scale = Vector3.ONE * ROCK_RADIUS
	var path := simulate_roll(p)
	rock.position = path[0] if path.size() > 0 else p
	_fx_root.add_child(rock)
	rocks.append({"path": path, "i": 0, "node": rock, "done": path.size() < 2, "hit": []})

## 從 start 放下巨石，預測它每個物理幀的位置（和實際滾動完全一樣，用來畫路徑）
func simulate_roll(start: Vector3) -> PackedVector3Array:
	var pts := PackedVector3Array()
	var p := Vector2(start.x, start.z)
	var v := Vector2.ZERO
	var dt := SIM_DT
	pts.append(Vector3(p.x, world.height_at(p.x, p.y) + ROCK_RADIUS, p.y))
	for i in 900:
		var g := Vector2(world.height_at(p.x + 0.15, p.y) - world.height_at(p.x - 0.15, p.y),
			world.height_at(p.x, p.y + 0.15) - world.height_at(p.x, p.y - 0.15)) / 0.3
		v += -g * ROLL_GRAVITY * dt
		var sp := v.length()
		# 台地上（高起來的地方）幾乎沒有阻力，巨石會沿著微斜的台面一路滾到邊緣再滾下去
		var resist := ROLL_RESIST if world.hill_bump(p.x, p.y) < 1.0 else 0.2
		if sp > 0.0:
			v = v / sp * clampf(sp - resist * dt, 0.0, ROLL_MAX_SPEED)
		var np := p + v * dt
		if not world.rock_ground(np.x, np.y) or world.in_water(np.x, np.y) or _hits_obstacle(np) or _fence_crossing(Vector3(p.x, 0, p.y), Vector3(np.x, 0, np.y)) != null:
			break
		p = np
		pts.append(Vector3(p.x, world.height_at(p.x, p.y) + ROCK_RADIUS, p.y))
		if i > 20 and v.length() < 0.05:
			break
	return pts

func _hits_obstacle(p: Vector2) -> bool:
	for o in world.obstacles:
		var c: Vector2 = o[0]
		if p.distance_to(c) < o[1] + 0.2:
			return true
	return false

func _spawn_feed(p: Vector3) -> void:
	var node := Node3D.new()
	node.position = p
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/toon_color.gdshader")
	mat.set_shader_parameter("albedo", Color(0.98, 0.82, 0.32))
	var grain := SphereMesh.new()
	grain.radius = 0.05
	grain.height = 0.07
	grain.radial_segments = 6
	grain.rings = 3
	for i in 18:
		var a := i * 2.39996
		var r := 0.08 + sqrt(float(i)) * 0.11
		var g := MeshInstance3D.new()
		g.mesh = grain
		g.material_override = mat
		g.position = Vector3(cos(a) * r, 0.03, sin(a) * r)
		node.add_child(g)
	_fx_root.add_child(node)
	feeds.append({"pos": p, "node": node})

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

## 讀圖：有匯入過就用匯入的資源，沒有就直接讀 PNG
func _load_tex(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	return ImageTexture.create_from_image(img) if img else null

func skill_index(id: String) -> int:
	for k in SKILLS.size():
		if SKILLS[k].id == id:
			return k
	return -1

## 香蕉皮：中間一小截，外面三片翻開的皮
func _spawn_peel(p: Vector3) -> void:
	var node := Node3D.new()
	node.position = p + Vector3(0, 0.02, 0)
	node.rotation.y = float(peels.size()) * 1.3
	var yel := StandardMaterial3D.new()
	yel.albedo_color = Color(1.0, 0.88, 0.22)
	yel.roughness = 0.6
	var brown := StandardMaterial3D.new()
	brown.albedo_color = Color(0.45, 0.3, 0.12)
	var mid := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.09
	cm.height = 0.34
	mid.mesh = cm
	mid.material_override = yel
	mid.rotation.x = 0.35
	mid.position.y = 0.12
	node.add_child(mid)
	var tip := MeshInstance3D.new()
	var tipm := CylinderMesh.new()
	tipm.top_radius = 0.03
	tipm.bottom_radius = 0.045
	tipm.height = 0.08
	tip.mesh = tipm
	tip.material_override = brown
	tip.position = Vector3(0, 0.29, 0.06)
	tip.rotation.x = 0.35
	node.add_child(tip)
	for k in 3:
		var flap := MeshInstance3D.new()
		var fm := CapsuleMesh.new()
		fm.radius = 0.085
		fm.height = 0.42
		flap.mesh = fm
		flap.material_override = yel
		var a := k * TAU / 3.0
		flap.position = Vector3(cos(a) * 0.17, 0.04, sin(a) * 0.17)
		flap.scale = Vector3(1.0, 1.0, 0.35)
		flap.rotation = Vector3(0, -a, 0)
		flap.rotate_object_local(Vector3.FORWARD, PI * 0.5 - 0.15)
		node.add_child(flap)
	_fx_root.add_child(node)
	peels.append({"pos": p, "node": node})

## 走路中的角色踩到香蕉皮就滑倒（家豪和農夫都會；老闆坐著不會）
func _tick_peels() -> void:
	for f in [bird] + farmers:
		var last: Vector3 = _last_pos.get(f, f.pos)
		_last_pos[f] = f.pos
		if peels.is_empty() or f.is_boss or not f.alive() or f.air > 0.3:
			continue
		if f.state in ["slip", "fly", "hop", "land", "drown"]:
			continue
		if _flat_dist(last, f.pos) < 0.004:
			continue   # 沒在走路
		for k in range(peels.size() - 1, -1, -1):
			var pl: Dictionary = peels[k]
			if _flat_dist(f.pos, pl.pos) < PEEL_RADIUS:
				(pl.node as Node3D).queue_free()
				peels.remove_at(k)
				f.kb_vel = Vector3.ZERO
				f.heavy = false
				f.set_state("slip")
				if not f.is_bird:
					_anim(f, "Death")
				_log("%s踩到香蕉皮滑倒了" % f.name)
				_toast("滑倒了！", 1.2)
				break

func _spawn_light(p: Vector3) -> void:
	var node := Node3D.new()
	node.position = p
	var r: float = SKILLS[2].radius
	var col := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = r * 0.85
	cyl.bottom_radius = r
	cyl.height = 9.0
	cyl.cap_top = false
	cyl.cap_bottom = false
	col.mesh = cyl
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = Color(1.0, 0.9, 0.5, 0.22)
	col.material_override = m
	col.position.y = 4.5
	col.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(col)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = r - 0.12
	tm.outer_radius = r
	tm.rings = 48
	ring.mesh = tm
	var rm := m.duplicate()
	rm.albedo_color = Color(1.0, 0.95, 0.6, 0.85)
	ring.material_override = rm
	ring.position.y = 0.06
	node.add_child(ring)
	_fx_root.add_child(node)
	lights.append({"pos": p, "t": 0.0, "node": node})

func _tick_miracles(dt: float) -> void:
	for r in rocks:
		if r.done:
			continue
		var path: PackedVector3Array = r.path
		var i: int = r.i + 1
		if i >= path.size():
			r.done = true
			continue
		r.i = i
		var prev := path[i - 1]
		var cur := path[i]
		var step := cur - prev
		var node: Node3D = r.node
		node.position = cur
		var flat := Vector3(step.x, 0, step.z)
		if flat.length() > 0.0001:
			node.rotate(flat.normalized().cross(Vector3.UP).normalized(), -flat.length() / ROCK_RADIUS)
		var speed := flat.length() / dt
		if speed >= ROCK_MIN_HIT_SPEED:
			for f in [bird] + farmers:
				if f.alive() and not r.hit.has(f) and f.air < 0.5 and _flat_dist(f.pos, cur) < ROCK_HIT_RADIUS:
					r.hit.append(f)
					_rock_hits(f, cur, flat.normalized())
		# 撞到水塔：水塔開始往下一座倒
		for k in towers.size():
			var t: Dictionary = towers[k]
			if t.state == "stand" and speed >= 0.6 and Vector2(cur.x - t.pos.x, cur.z - t.pos.y).length() < t.radius + ROCK_RADIUS + 0.45:
				_log("巨石撞倒了第 %d 座水塔！" % (k + 1))
				_toast("撞到水塔了！", 1.4)
				_topple(k)
				r.done = true
				break
		if r.done:
			continue
		if i == path.size() - 1:
			r.done = true
			if r.hit.is_empty():
				_log("巨石滾停了，沒撞到人")
	for i in range(lights.size() - 1, -1, -1):
		var l: Dictionary = lights[i]
		l.t += dt
		var rad: float = SKILLS[2].radius
		for f in [bird] + farmers:
			if f.alive() and _flat_dist(f.pos, l.pos) <= rad and f.hp < f.max_hp:
				f.hp = minf(f.hp + LIGHT_HEAL * dt, f.max_hp)
		var fade := clampf((LIGHT_TIME - l.t) / 0.6, 0.0, 1.0)
		(l.node as Node3D).scale = Vector3(1, fade, 1)
		if l.t >= LIGHT_TIME:
			(l.node as Node3D).queue_free()
			lights.remove_at(i)

## 像高爾夫球遊戲一樣：沿著預測路徑擺一排小點
func _update_path_preview(on: bool) -> void:
	if not on:
		for d in _dots:
			d.visible = false
		_update_highlights(PackedVector3Array(), false)
		return
	if aim_point.distance_to(_path_cache_at) > 0.05:
		_path_cache_at = aim_point
		_path_cache = simulate_roll(aim_point)
	_update_highlights(_path_cache, true)
	var n := _path_cache.size()
	var spacing := 5
	for k in _dots.size():
		var idx := (k + 1) * spacing
		var d: MeshInstance3D = _dots[k]
		if idx < n:
			d.visible = true
			d.global_position = _path_cache[idx] - Vector3(0, ROCK_RADIUS - 0.12, 0)
			var fade := 1.0 - float(idx) / maxf(n, 1.0) * 0.6
			d.scale = Vector3.ONE * fade
		else:
			d.visible = false

var _green_mat: StandardMaterial3D
var highlighted: Array = []    # 目前亮綠色的東西（水塔的索引）

## 巨石路徑會撞到的水塔亮綠色，讓玩家知道那是可以互動的東西
func _update_highlights(path: PackedVector3Array, on: bool) -> void:
	var want: Array = []
	# 只有巨石真的滾過去（不是直接對著水塔放）時，才讓它撞到的「最近那一座」亮綠色
	if on and path.size() > 1:
		var first := path[0]
		var last := path[path.size() - 1]
		var rolled := Vector2(last.x - first.x, last.z - first.z).length()
		var best := -1
		var best_d := INF
		for k in towers.size():
			var t: Dictionary = towers[k]
			if t.state != "stand":
				continue
			var d_end := Vector2(last.x - t.pos.x, last.z - t.pos.y).length()
			var d_start := Vector2(first.x - t.pos.x, first.z - t.pos.y).length()
			if rolled > 1.5 and d_start > t.radius + 2.0 and d_end < t.radius + ROCK_RADIUS + 0.6 and d_end < best_d:
				best_d = d_end
				best = k
		if best >= 0:
			want.append(best)
	if want == highlighted:
		return
	if _green_mat == null:
		_green_mat = StandardMaterial3D.new()
		_green_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_green_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_green_mat.albedo_color = Color(0.3, 1.0, 0.35, 0.45)
	for k in towers.size():
		var mat: Material = _green_mat if want.has(k) else null
		for mi in (towers[k].node as Node).find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).material_overlay = mat
	highlighted = want

func visible_dots() -> int:
	return _dots.filter(func(d): return d.visible).size()

func _rock_hits(f: Fighter, p: Vector3, dir: Vector3) -> void:
	if f.is_boss:
		return
	_noise_at(p)
	if f.is_bird:
		_log("巨石撞到家豪")
		_toast("糟糕，撞到家豪了！", 1.8)
		_hit_bird(minf(ROCK_DAMAGE_BIRD, maxf(bird.hp - 1.0, 0.0)), true, p - dir)
		return
	f.hp = maxf(f.hp - ROCK_DAMAGE_FARMER, 0.0)
	_log("巨石撞倒%s" % f.name)
	_toast("撞倒了！", 1.2)
	_aggro(f)
	f.heavy = false
	f.kb_vel = dir * 3.0
	_anim(f, "Death")
	f.set_state("dead" if f.hp <= 0.0 else "down")

# ------------------------------------------------------------------ 主迴圈

## 戰鬥邏輯固定每 1/60 秒算一步：不管遊戲加速、放慢或掉幀，同樣的操作永遠得到同樣的結果
const SIM_DT := 1.0 / 60.0
var _acc := 0.0

func _physics_process(delta: float) -> void:
	_acc += delta
	while _acc >= SIM_DT - 0.000001:
		_acc -= SIM_DT
		_step(SIM_DT)
	_apply_visuals()

func _step(dt: float) -> void:
	if phase == Phase.RUNNING:
		time += dt
		for f in farmers:
			if f.is_boss:
				_tick_boss(f, dt)
			else:
				_tick_farmer(f, dt)
		_tick_towers(dt)
		_tick_demo_rock(dt)
		_tick_bird(dt)
		_tick_miracles(dt)
		_tick_peels()
		if farmers.all(func(f): return not f.alive()):
			_end("win")
		elif not bird.alive():
			_end("lose")
	elif phase == Phase.ENDED:
		bird.t += dt
		_tick_towers(dt)   # 勝負已分，但正在倒的水塔和穀倉要照樣倒完

func _process(dt: float) -> void:
	_tick_tutorial(dt)
	_tick_cooldowns(dt)
	_update_aim()
	var show: bool = phase != Phase.ENDED and aim_point != null and charges[selected] != 0 and not defeat_shown
	aim_error = placement_error(selected, aim_point) if aim_point != null else ""
	var ok := show and aim_error == ""
	_preview.visible = show
	if show:
		var r: float = SKILLS[selected].radius
		_preview.global_position = aim_point + Vector3(0, 0.08, 0)
		_preview.scale = Vector3(r, 1, r)
		var c: Color = SKILLS[selected].color if ok else Color(1.0, 0.3, 0.25)
		(_preview.material_override as StandardMaterial3D).albedo_color = Color(c, 0.85)
	_update_path_preview(ok and SKILLS[selected].id == "rock")
	var can := ok
	if crosshair and "highlight" in crosshair:
		crosshair.highlight = can
	if _toast_t > 0.0:
		_toast_t -= dt
		if _toast_t <= 0.0:
			_toast_label.text = ""
	if _defeat_delay > 0.0:
		_defeat_delay -= dt
		if _defeat_delay <= 0.0:
			_show_defeat()
	if phase == Phase.RUNNING:
		_update_phase_label()
	_update_bars(dt)
	for f in farmers:
		_draw_cone(f)
	for row in _enemy_rows:
		var f: Fighter = row.fighter
		var r: float = f.ratio() if f.alive() else 0.0
		(row.fill as ColorRect).size.x = row.width * r
		(row.chip as ColorRect).size.x = row.width * f.chip
		var face: EnemyFace = row.face
		if face.dead != (not f.alive()):
			face.dead = not f.alive()
			face.queue_redraw()

# ------------------------------------------------------------------ 農夫

func _farmer_open(f: Fighter) -> bool:
	return (f.heavy and f.state == "recover") or f.state in ["pant", "stagger", "down", "getup", "startled", "slip"]

func _bird_targetable() -> bool:
	return bird.alive() and bird.state != "fly"

func _aggro(f: Fighter) -> void:
	if f.aggro or not f.alive():
		return
	f.aggro = true
	if f.state in ["idle", "patrol", "look"]:
		f.set_state("alert")
		_anim(f, "Idle")
	_log("%s發現家豪" % f.name)

## 打鬥聲：在 p 發生打擊時，附近還沒發現的農夫會在 0.8 秒後趕過來
func _noise_at(p: Vector3) -> void:
	for o in farmers:
		if o.is_boss:
			continue
		if o.alive() and not o.aggro and o.alert_t < 0.0 and _flat_dist(o.pos, p) <= ALERT_RADIUS:
			o.alert_t = 0.8

func _tick_farmer(f: Fighter, dt: float) -> void:
	f.t += dt
	_apply_knockback(f, dt)
	# 掉進水池：沉下去淹死
	if f.state == "drown":
		f.air = -2.2 * clampf(f.t / 1.4, 0.0, 1.0)
		if f.t >= 1.4:
			f.hp = 0.0
			f.set_state("dead")
		return
	if f.alive() and world.in_water(f.pos.x, f.pos.z):
		f.hp = 0.0
		f.set_state("drown")
		_anim(f, "Death")
		_spawn_splash(f.pos)
		_log("%s追家豪追進水池，溺死了" % f.name)
		_toast("撲通！", 1.2)
		return
	if f.alert_t >= 0.0:
		f.alert_t -= dt
		if f.alert_t < 0.0 and not f.aggro:
			_log("%s聽到打鬥聲趕過來" % f.name)
			_aggro(f)
	var dist := _flat_dist(f.pos, bird.pos)
	if not f.aggro and f.state in ["patrol", "look", "idle"] and sees_bird(f):
		_log("%s看到家豪了" % f.name)
		_aggro(f)
	match f.state:
		"patrol":
			var goal: Vector3 = f.route[f.wp]
			if _flat_dist(f.pos, goal) < 0.2:
				f.look_yaw = f.yaw
				f.set_state("look")
				_anim(f, "Idle")
			else:
				_walk(f, goal, 1.0, dt)
				_anim(f, "Walk", 0.7)
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
				_log("%s被圍欄擋住，繞路追" % f.name)
			elif was and not f.detouring and f.chased:
				f.chased = false
				f.set_state("pant")
				_anim(f, "Idle", 0.6)
				_log("%s繞了一大圈，停下來喘氣" % f.name)
				return
			_anim(f, "Walk")
			if dist <= f.reach and _bird_targetable():
				_farmer_attack(f)
		"windup":
			_face(f, bird.pos)
			if f.t >= (0.8 if f.heavy else f.windup):
				if dist <= f.reach + 0.35 and _bird_targetable():
					_hit_bird(HEAVY_DAMAGE if f.heavy else KICK_DAMAGE, f.heavy, f.pos, f)
				f.set_state("recover")
		"recover":
			if f.t >= (1.7 if f.heavy else f.recover):
				f.heavy = false
				if dist <= f.reach and _bird_targetable():
					_farmer_attack(f)
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
				_anim(f, "Idle")
		"getup":
			if f.t >= 0.5:
				f.set_state("walk")
		"slip":
			# 踩到香蕉皮，躺在地上；起來後有在追就繼續追，沒發現家豪的回去巡邏
			if f.t >= SLIP_TIME:
				_anim(f, "Idle")
				f.set_state("getup" if f.aggro else "patrol")

# ------------------------------------------------------------------ 老闆

func _tick_boss(f: Fighter, dt: float) -> void:
	f.t += dt
	if not f.alive():
		return
	f.shoot_cd -= dt
	# 牆會擋子彈：只有從門口看得到家豪時才會開槍
	var in_range := bird.alive() and bird.air < 1.5 and _flat_dist(f.pos, bird.pos) <= BOSS_RANGE \
		and _wall_crossing(f.pos, bird.pos) == null
	match f.state:
		"boss":
			if in_range:
				_face(f, bird.pos)
				if f.shoot_cd <= 0.0:
					f.set_state("aim")
					_anim(f, "Idle_Gun_Pointing")
					_log("老闆掏出槍瞄準家豪")
			else:
				_anim(f, "Idle")
		"aim":
			_face(f, bird.pos)
			if f.t >= BOSS_AIM:
				_boss_fire(f, in_range)
				f.shoot_cd = BOSS_COOLDOWN
				f.set_state("boss")

func _boss_fire(f: Fighter, hit: bool) -> void:
	_anim(f, "Gun_Shoot", 1.2)
	var muzzle := f.pos + Vector3(0, 1.7, 0) + Vector3(sin(f.yaw), 0, cos(f.yaw)) * 0.8
	if f.gun:
		muzzle = (f.gun as Node3D).global_position + (f.gun as Node3D).global_basis.y * -0.5
	var target := bird.pos + Vector3(0, bird.air + 0.7, 0)
	_spawn_tracer(muzzle, target)
	if not hit:
		return
	_noise_at(f.pos)
	# 子彈打不中、也不扣血：家豪只是被槍聲嚇得飛走（再回來也一樣）
	hit_spots.append(bird.pos)
	_log("老闆開槍，家豪被槍聲嚇得飛走")
	_toast("砰！", 0.8)
	if _dialog:
		_dialog.say("THERE IS NOTHING I CAN DO", _napoleon_tex)
	var away := bird.pos - f.pos
	away.y = 0.0
	away = away.normalized() if away.length() > 0.01 else Vector3.BACK
	_start_fly(bird.pos + away * 6.5, FLY_TIME, FLY_PEAK, "land")

func _spawn_splash(p: Vector3) -> void:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.85, 0.95, 1.0, 0.7)
	for k in 6:
		var a := k * TAU / 6.0
		var mi := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.35
		sm.height = 0.7
		mi.mesh = sm
		mi.material_override = m
		_fx_root.add_child(mi)
		mi.global_position = Vector3(p.x + cos(a) * 0.6, world.water_y + 0.2, p.z + sin(a) * 0.6)
		_fx_timed.append({"node": mi, "t": 0.0, "life": 0.9, "kind": "dust"})

func _spawn_tracer(a: Vector3, b: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.035
	cm.bottom_radius = 0.035
	cm.height = a.distance_to(b)
	mi.mesh = cm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1.0, 0.92, 0.5)
	mi.material_override = m
	_fx_root.add_child(mi)
	mi.global_position = (a + b) * 0.5
	var up := (b - a).normalized()
	var side := up.cross(Vector3.FORWARD if absf(up.z) < 0.9 else Vector3.RIGHT).normalized()
	mi.global_basis = Basis(side, up, side.cross(up))
	_fx_timed.append({"node": mi, "t": 0.0, "life": 0.12, "kind": "tracer"})
	var flash := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.22
	sm.height = 0.44
	flash.mesh = sm
	flash.material_override = m
	_fx_root.add_child(flash)
	flash.global_position = a
	_fx_timed.append({"node": flash, "t": 0.0, "life": 0.1, "kind": "tracer"})

# ------------------------------------------------------------------ 骨牌：水塔與大穀倉

func _topple(k: int) -> void:
	var t: Dictionary = towers[k]
	if t.state != "stand":
		return
	t.state = "fall"
	t.omega = 0.35
	var target: Vector2 = towers[k - 1].pos if k > 0 else Vector2(world.barn_pos.x, world.barn_pos.z)
	var d := target - (t.pos as Vector2)
	t.dir = Vector3(d.x, 0, d.y).normalized()

func _tick_towers(dt: float) -> void:
	for k in towers.size():
		var t: Dictionary = towers[k]
		if t.state != "fall":
			continue
		t.omega += TOWER_GRAVITY * dt
		t.angle = minf(t.angle + t.omega * dt, 1.45)
		var axis := Vector3.UP.cross(t.dir).normalized()
		(t.node as Node3D).basis = Basis(axis, t.angle)
		var reach: float = t.height * sin(t.angle)
		# 倒向下一座（或大穀倉）
		if k > 0:
			var n: Dictionary = towers[k - 1]
			if n.state == "stand" and reach >= (t.pos as Vector2).distance_to(n.pos) - n.radius:
				_log("第 %d 座水塔砸倒第 %d 座" % [k + 1, k])
				_topple(k - 1)
		elif barn_state == "stand":
			var bp := Vector2(world.barn_pos.x, world.barn_pos.z)
			if reach >= (t.pos as Vector2).distance_to(bp) - BARN_HIT_RADIUS:
				_collapse_barn()
		# 倒下的路上壓到人
		if not t.crushed and t.angle > 1.0:
			t.crushed = true
			var a := Vector2(t.pos.x, t.pos.y)
			var b: Vector2 = a + Vector2(t.dir.x, t.dir.z) * t.height
			for f in [bird] + farmers:
				if not f.alive() or f.is_boss or f.air > 1.0:
					continue
				var q := Vector2(f.pos.x, f.pos.z)
				var u := clampf((q - a).dot(b - a) / (b - a).length_squared(), 0.0, 1.0)
				if q.distance_to(a.lerp(b, u)) < 1.4:
					if f.is_bird:
						_log("水塔倒下來壓到家豪")
						_hit_bird(minf(3.0, maxf(f.hp - 1.0, 0.0)), true, Vector3(a.x, 0, a.y))
					else:
						f.hp = 0.0
						f.set_state("dead")
						_anim(f, "Death")
						_log("水塔倒下來壓倒了%s" % f.name)
		if t.angle >= 1.45:
			t.state = "down"
	# 大穀倉垮掉的動畫
	if barn_state == "collapse":
		barn_t += dt
		var k2 := clampf(barn_t / 0.7, 0.0, 1.0)
		var xf := _barn_xf
		xf.basis = _barn_xf.basis * Basis(Vector3.FORWARD, 0.12 * k2)
		xf.basis = xf.basis.scaled(Vector3(1.0 + 0.08 * k2, 1.0 - 0.6 * k2 * k2, 1.0 + 0.08 * k2))
		world.barn_node.transform = xf
		if k2 >= 1.0:
			barn_state = "down"
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

## 示範石頭只是滾下來給玩家看，不會傷人、不會撞倒水塔
func _tick_demo_rock(_dt: float) -> void:
	if time < DEMO_ROCK_DELAY or demo_i >= demo_path.size() - 1:
		return
	demo_i += 1
	var prev := demo_path[demo_i - 1]
	var cur := demo_path[demo_i]
	demo_rock.position = cur - Vector3(0, ROCK_RADIUS - DEMO_ROCK_RADIUS, 0)
	var flat := Vector3(cur.x - prev.x, 0, cur.z - prev.z)
	if flat.length() > 0.0001:
		demo_rock.rotate(flat.normalized().cross(Vector3.UP).normalized(), -flat.length() / DEMO_ROCK_RADIUS)
	if demo_i == 1:
		_log("台地坡頂的石頭滑下來了")

func _collapse_barn() -> void:
	barn_state = "collapse"
	barn_t = 0.0
	_log("水塔砸垮了大穀倉！")
	_toast("大穀倉垮了！", 2.0)
	_noise_at(world.barn_pos)
	var dust_mat := StandardMaterial3D.new()
	dust_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dust_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dust_mat.albedo_color = Color(0.85, 0.8, 0.7, 0.55)
	for k in 10:
		var a := k * TAU / 10.0
		var mi := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 1.0
		sm.height = 2.0
		mi.mesh = sm
		mi.material_override = dust_mat
		_fx_root.add_child(mi)
		mi.global_position = world.barn_pos + Vector3(cos(a) * 4.0, 1.0, sin(a) * 4.0)
		_fx_timed.append({"node": mi, "t": 0.0, "life": 1.4, "kind": "dust"})
	if boss and boss.alive():
		boss.hp = 0.0
		boss.set_state("dead")
		_anim(boss, "Death")
		_log("老闆被壓在大穀倉底下，倒下了")

## 家豪在不在這個農夫前方的偵測區裡
func sees_bird(f: Fighter) -> bool:
	if not bird.alive() or bird.air > 1.0:
		return false
	var to := Vector2(bird.pos.x - f.pos.x, bird.pos.z - f.pos.z)
	var d := to.length()
	if d > VISION_RANGE:
		return false
	if d < 0.01:
		return true
	var fwd := Vector2(sin(f.yaw), cos(f.yaw))
	return fwd.angle_to(to.normalized()) <= VISION_HALF and fwd.angle_to(to.normalized()) >= -VISION_HALF

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
		var rad := VISION_RANGE * float(r) / rings
		for k in segs + 1:
			var a := f.yaw - VISION_HALF + 2.0 * VISION_HALF * float(k) / segs
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

func enemies_left() -> int:
	return farmers.filter(func(f): return f.alive()).size()

func _farmer_attack(f: Fighter) -> void:
	f.heavy = f.attack_n % 3 == 2
	f.attack_n += 1
	f.set_state("windup")
	if f.heavy:
		_anim(f, "Kick_Left", 0.75)
	else:
		_anim(f, "Kick_Right", 1.3)

# ------------------------------------------------------------------ 家豪

func _nearest_farmer(from: Vector3) -> Fighter:
	var best: Fighter = null
	var bd := INF
	var others := farmers.any(func(f): return f.alive() and not f.is_boss)
	for f in farmers:
		if f.alive() and (not f.is_boss or not others):
			var d := _flat_dist(from, f.pos)
			if d < bd:
				bd = d
				best = f
	return best

func _nearest_feed(from: Vector3, within: float) -> int:
	var best := -1
	var bd := within
	for i in feeds.size():
		var d := _flat_dist(from, feeds[i].pos)
		if d < bd:
			bd = d
			best = i
	return best

func _tick_bird(dt: float) -> void:
	var b := bird
	b.t += dt
	if b.state != "fly":
		_apply_knockback(b, dt)
	var tgt := _nearest_farmer(b.pos)
	b.target = tgt
	if tgt == null:
		return
	var dist := _flat_dist(b.pos, tgt.pos)
	# 飼料優先：不在出招、挨打、飛行中時，聞到飼料就跑去吃
	if b.state in ["charge", "return", "feed", "linger"]:
		var fi := _nearest_feed(b.pos, FEED_SENSE)
		if fi >= 0:
			if b.state != "feed":
				_log("家豪看到飼料，跑去吃")
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
				if _flat_dist(b.pos, fp) < 0.35:
					b.set_state("eat")
		"eat":
			if b.t >= FEED_EAT_TIME:
				var fi := _nearest_feed(b.pos, 0.8)
				if fi >= 0:
					(feeds[fi].node as Node3D).queue_free()
					feeds.remove_at(fi)
					b.hp = minf(b.hp + FEED_HEAL, b.max_hp)
					_log("家豪吃掉一把飼料（回到 %d）" % ceili(b.hp))
				b.set_state("linger")
		"linger":
			# 吃飽了在原地東張西望、啄啄地，過一會兒才想起來要打農夫
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
					if not tgt.aggro:
						_sneak(tgt)
					else:
						_hit_farmer(tgt, PECK_DAMAGE, b.pos)
				b.set_state("recover")
		"recover":
			if b.t >= b.recover:
				b.set_state("windup" if dist <= b.reach else "charge")
		"hop":
			if b.t >= 0.4:
				b.set_state("charge")
		"fly":
			var k := clampf(b.t / b.fly_dur, 0.0, 1.0)
			b.pos = _ground(b.fly_from.lerp(b.fly_to, k))
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
				_log("家豪落地站穩，找路繞回來")
		"return":
			_bird_walk(tgt.pos, b.speed * 0.75, dt, "return")
			if _farmer_open(tgt) and dist < 6.5:
				_log("家豪看到%s的破綻，提前反擊" % tgt.name)
				b.set_state("charge")
			elif dist <= tgt.reach + 0.5:
				b.set_state("charge")

## 雞走路：遇到圍欄就拍翅小跳過去
func _bird_walk(target: Vector3, spd: float, dt: float, resume: String) -> void:
	var b := bird
	# 大穀倉的牆擋住：繞到門口再進去（牆飛不過去）
	target = world.route_point(b.pos, target)
	var wseg: Variant = _blocking_wall(b.pos, target)
	if wseg != null:
		target = _detour(b.pos, target, wseg)
	var d := target - b.pos
	d.y = 0.0
	if d.length() < 0.001:
		return
	b.yaw = atan2(d.x, d.z)
	var step := d.normalized() * minf(spd * dt, d.length())
	var nxt := b.pos + step
	# 前面是水：拍翅飛過去（目標在小島上就直接飛到小島）
	if world.in_water(nxt.x, nxt.z) or world.in_water(b.pos.x + d.normalized().x * 0.6, b.pos.z + d.normalized().z * 0.6):
		var dest := target
		if not world.on_island(target.x, target.z):
			dest = b.pos
			for k in 60:
				dest += d.normalized() * 0.25
				if not world.in_water(dest.x, dest.z) and _flat_dist(dest, b.pos) > 1.0:
					break
			dest += d.normalized() * 0.4
		_start_fly(dest, HOP_TIME + 0.3, 1.4, resume)
		return
	var cross: Variant = _fence_crossing(b.pos, nxt + d.normalized() * 0.6, false)
	if cross != null:
		var over: Vector3 = cross + d.normalized() * 1.4
		_start_fly(over, HOP_TIME, 1.2, resume)
		return
	var moved: Vector3 = world.clamp_play(_avoid(b.pos, nxt, 0.35))
	if _wall_crossing(b.pos, moved) == null:
		b.pos = _ground(moved)

func _start_fly(to: Vector3, dur: float, peak: float, after: String) -> void:
	var b := bird
	b.fly_from = b.pos
	var dest := _clamp_play(to)
	var wc: Variant = _wall_crossing(b.pos, dest)
	if wc != null:
		var back := (dest - b.pos)
		back.y = 0.0
		dest = (wc as Vector3) - back.normalized() * 0.8
	if world.in_water(dest.x, dest.z):
		# 別降落在水裡：推到岸邊
		var c: Vector2 = world.pond_center
		var v := Vector2(dest.x - c.x, dest.z - c.y)
		v = v.normalized() if v.length() > 0.01 else Vector2(1, 0)
		dest = Vector3(c.x + v.x * (world.pond_r + 0.5), 0, c.y + v.y * (world.pond_r + 0.5))
	b.fly_to = _ground(dest)
	b.fly_dur = dur
	b.fly_peak = peak
	b.after_fly = after
	b.kb_vel = Vector3.ZERO
	b.set_state("fly")

func _hit_bird(dmg: float, heavy: bool, from: Vector3, by: Fighter = null) -> void:
	var b := bird
	var before := b.hp
	b.hp = maxf(b.hp - dmg, 0.0)
	hit_spots.append(b.pos)
	_noise_at(b.pos)
	if by:
		_log("%s%s踢中家豪（剩 %d）" % [by.name, "重" if heavy else "", ceili(b.hp)])
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
		if fp != null and _flat_dist(fp, b.pos) < 6.5:
			var n := _fence_normal_away(fp, b.pos)
			if n.dot(away) > -0.2:
				target = fp + n * 2.4
				_log("家豪%s，拍翅飛過圍欄撤退" % ("被重踢" if heavy else "掉到半血"))
			else:
				_log("家豪%s，拍翅飛開撤退" % ("被重踢" if heavy else "掉到半血"))
		else:
			_log("家豪%s，拍翅飛開撤退" % ("被重踢" if heavy else "掉到半血"))
		_start_fly(target, FLY_TIME, FLY_PEAK, "land")
		for f in farmers:
			if f.aggro:
				f.chased = true
	else:
		b.set_state("hop")
		b.kb_vel = away * 0.5 / 0.25

## 偷襲：農夫還沒發現家豪就被啄，傷害加倍，還會嚇一跳愣住
func _sneak(f: Fighter) -> void:
	f.hp = maxf(f.hp - PECK_DAMAGE * SNEAK_MULT, 0.0)
	hit_spots.append(f.pos)
	_log("家豪偷襲%s！（剩 %d）" % [f.name, ceili(f.hp)])
	_toast("偷襲！", 1.2)
	_noise_at(f.pos)
	f.aggro = true
	f.alert_t = -1.0
	if f.hp <= 0.0:
		f.set_state("dead")
		_anim(f, "Death")
		_log("%s倒下了" % f.name)
		return
	f.heavy = false
	f.set_state("startled")
	f.yaw = _yaw_to(f.pos, bird.pos)
	_anim(f, "HitRecieve", 0.8)

func _hit_farmer(f: Fighter, dmg: float, from: Vector3) -> void:
	if f.is_boss:
		_log("家豪的啄對老闆完全沒用")
		return
	f.hp = maxf(f.hp - dmg, 0.0)
	hit_spots.append(f.pos)
	_noise_at(f.pos)
	_log("家豪啄中%s（剩 %d）" % [f.name, ceili(f.hp)])
	_aggro(f)
	var away := f.pos - from
	away.y = 0.0
	away = away.normalized() if away.length() > 0.01 else Vector3.FORWARD
	if f.hp <= 0.0:
		f.set_state("dead")
		f.kb_vel = away * 2.0
		_anim(f, "Death")
		_log("%s倒下了" % f.name)
		return
	if f.state == "down":
		return
	if f.state == "windup" and f.heavy:
		return
	f.heavy = false
	f.set_state("stagger")
	f.kb_vel = away
	_anim(f, "HitRecieve", 1.4)

# ------------------------------------------------------------------ 圍欄與障礙

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

## 會擋路的線段：矮圍欄 + 大穀倉的牆（walls=false 時只算矮圍欄）
func _segments(walls := true) -> Array:
	return world.fence_segments + world.wall_segments if walls else world.fence_segments

func _wall_crossing(from: Vector3, to: Vector3) -> Variant:
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

func _fence_crossing(from: Vector3, to: Vector3, walls := true) -> Variant:
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

func _clamp_play(p: Vector3) -> Vector3:
	return world.clamp_play(p)

# ------------------------------------------------------------------ 共用

func _ground(p: Vector3) -> Vector3:
	return Vector3(p.x, world.height_at(p.x, p.z), p.z)

func _flat_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

func _yaw_to(from: Vector3, to: Vector3) -> float:
	return atan2(to.x - from.x, to.z - from.z)

func _face(f: Fighter, target: Vector3) -> void:
	f.yaw = _yaw_to(f.pos, target)

## 農夫走路：直線被圍欄擋住就走到欄的端點（大門）繞過去，也會避開建築
func _walk(f: Fighter, target: Vector3, spd: float, dt: float) -> void:
	var goal: Vector3 = world.route_point(f.pos, target)   # 進出大穀倉要走門口
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
	if _fence_crossing(f.pos, nxt) == null:
		f.pos = _ground(nxt)

func _apply_knockback(f: Fighter, dt: float) -> void:
	if f.kb_vel.length() < 0.01:
		f.kb_vel = Vector3.ZERO
		return
	var nxt := f.pos + f.kb_vel * dt
	if _fence_crossing(f.pos, nxt) != null:
		f.kb_vel = Vector3.ZERO
	else:
		f.pos = _ground(world.clamp_play(_avoid(f.pos, nxt, 0.4)))
	f.kb_vel = f.kb_vel.move_toward(Vector3.ZERO, 9.0 * dt)

func _anim(f: Fighter, name: String, speed := 1.0) -> void:
	if f.anim and f.anim.has_animation(name):
		if f.anim.current_animation != name or not f.anim.is_playing() or name in ["Kick_Right", "Kick_Left", "HitRecieve"]:
			f.anim.play(name, 0.15, speed)

func _log(text: String) -> void:
	events.append({"t": snappedf(time, 0.001), "text": text})

# ------------------------------------------------------------------ 畫面表現

func _apply_visuals() -> void:
	for f in [bird] + farmers:
		f.node.global_position = f.pos + Vector3(0, f.air, 0)
		f.node.rotation = Vector3(0, f.yaw, 0)
	_boss_pose()
	_bird_pose()

## 胖商人：瞄準時舉起拿槍的手，被穀倉壓到就扁掉
func _boss_pose() -> void:
	if boss == null:
		return
	var arm := boss.node.find_child("ArmR", true, false) as Node3D
	var body := boss.node.find_child("Body", true, false) as Node3D
	if arm:
		var want := 0.9
		if boss.state == "aim":
			want = 1.55
		elif boss.alive() and boss.shoot_cd > BOSS_COOLDOWN - 0.25:
			want = 1.85   # 開槍的後座力
		arm.rotation.x = lerpf(arm.rotation.x, want, 0.3)
	if body:
		if boss.alive():
			body.scale = Vector3.ONE
			body.position.y = absf(sin(time * 1.6)) * 0.03   # 呼吸
		else:
			body.scale = Vector3(1.25, 0.35, 1.25)
			body.position.y = -0.4

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

# ------------------------------------------------------------------ HUD

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	_hud_layer = layer

	for f in [bird] + farmers:
		var bar := Control.new()
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.size = Vector2(96, 12)
		var bg := ColorRect.new()
		bg.color = Color(0.08, 0.06, 0.06, 0.75)
		bg.size = Vector2(96, 12)
		bar.add_child(bg)
		var chip := ColorRect.new()
		chip.color = Color(1.0, 0.92, 0.8, 0.9)
		chip.position = Vector2(2, 2)
		chip.size = Vector2(92, 8)
		bar.add_child(chip)
		var fill := ColorRect.new()
		# 主角綠色、敵人紅色
		fill.color = Color(0.3, 0.82, 0.32) if f.is_bird else Color(0.86, 0.13, 0.12)
		fill.position = Vector2(2, 2)
		fill.size = Vector2(92, 8)
		bar.add_child(fill)
		layer.add_child(bar)
		f.bar = bar
		f.bar_fill = fill
		f.bar_chip = chip

	# 技能欄：畫面下方一整條相連的快捷欄（方塊遊戲風格）
	_hotbar = Hotbar.new()
	_hotbar.skills = SKILLS
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
	_dialog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dialog.visible = false
	_dialog.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_dialog.offset_left = -400
	_dialog.offset_right = 400
	_dialog.offset_top = -hb.y - 22 - 20 - DialogBox.H
	_dialog.offset_bottom = -hb.y - 22 - 20
	layer.add_child(_dialog)
	_napoleon_tex = _load_tex("res://assets/ui/napoleon.png")
	_dialog.portrait = _load_tex("res://assets/ui/jiahao_portrait.png")
	_tut_arrow = TutArrow.new()
	_tut_arrow.size = Vector2(70, 120)
	_tut_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tut_arrow.visible = false
	layer.add_child(_tut_arrow)
	_tut_panel = PanelContainer.new()
	var tsb := StyleBoxFlat.new()
	tsb.bg_color = Color(0.06, 0.06, 0.06, 0.78)
	tsb.border_color = Color(1, 1, 1, 0.9)
	tsb.set_border_width_all(3)
	tsb.set_content_margin_all(14)
	_tut_panel.add_theme_stylebox_override("panel", tsb)
	_tut_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tut_panel.visible = false
	_tut_label = Label.new()
	var tls := LabelSettings.new()
	tls.font_size = 22
	tls.line_spacing = 4
	_tut_label.label_settings = tls
	_tut_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tut_panel.add_child(_tut_label)
	layer.add_child(_tut_panel)

	var top := LabelSettings.new()
	top.font_size = 26
	top.outline_size = 8
	top.outline_color = Color(0, 0, 0, 0.6)
	# 右上角敵人欄：一列一個敵人（頭像方格 + 右側血條），老闆排最上面
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	col.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	col.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	col.offset_right = -20
	col.offset_top = 16
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(col)
	var order: Array = farmers.filter(func(f): return f.is_boss) + farmers.filter(func(f): return not f.is_boss)
	var ns := LabelSettings.new()
	ns.font_size = 17
	ns.outline_size = 6
	ns.outline_color = Color(0, 0, 0, 0.6)
	for f in order:
		var erow := HBoxContainer.new()
		erow.add_theme_constant_override("separation", 10)
		erow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(erow)
		var face := EnemyFace.new()
		face.boss = f.is_boss
		face.custom_minimum_size = Vector2(64, 64) if f.is_boss else Vector2(52, 52)
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		erow.add_child(face)
		var info := VBoxContainer.new()
		info.alignment = BoxContainer.ALIGNMENT_CENTER
		info.mouse_filter = Control.MOUSE_FILTER_IGNORE
		erow.add_child(info)
		var nm := Label.new()
		nm.text = f.name + ("（持槍）" if f.is_boss else "")
		nm.label_settings = ns
		info.add_child(nm)
		var bar := Control.new()
		bar.custom_minimum_size = Vector2(170 if f.is_boss else 140, 14)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		info.add_child(bar)
		var bg := ColorRect.new()
		bg.color = Color(0.08, 0.06, 0.06, 0.8)
		bg.size = bar.custom_minimum_size
		bar.add_child(bg)
		var chip := ColorRect.new()
		chip.color = Color(1.0, 0.92, 0.8, 0.9)
		chip.position = Vector2(2, 2)
		chip.size = bar.custom_minimum_size - Vector2(4, 4)
		bar.add_child(chip)
		var fill := ColorRect.new()
		fill.color = Color(0.86, 0.13, 0.12)
		fill.position = Vector2(2, 2)
		fill.size = bar.custom_minimum_size - Vector2(4, 4)
		bar.add_child(fill)
		_enemy_rows.append({"fighter": f, "face": face, "fill": fill, "chip": chip, "width": bar.custom_minimum_size.x - 4.0})
	_phase_label = Label.new()
	_phase_label.label_settings = top
	_phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_phase_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_phase_label.offset_top = 56
	_phase_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	layer.add_child(_phase_label)

	var ts := LabelSettings.new()
	ts.font_size = 30
	ts.font_color = Color(1, 0.92, 0.55)
	ts.outline_size = 10
	ts.outline_color = Color(0, 0, 0, 0.65)
	_toast_label = Label.new()
	_toast_label.label_settings = ts
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_toast_label.offset_top = -140
	_toast_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	layer.add_child(_toast_label)

	_summary_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.1, 0.12, 0.78)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(22)
	_summary_panel.add_theme_stylebox_override("panel", sb)
	_summary_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_summary_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_summary_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var ss := LabelSettings.new()
	ss.font_size = 22
	ss.line_spacing = 6
	_summary_label = Label.new()
	_summary_label.label_settings = ss
	_summary_panel.add_child(_summary_label)
	layer.add_child(_summary_panel)

# ------------------------------------------------------------------ 輸了的畫面

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
	var band := ColorRect.new()
	band.color = Color(0.11, 0.14, 0.2)
	band.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	band.anchor_top = 0.82
	band.offset_top = 0
	_defeat_layer.add_child(band)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 6)
	band.add_child(box)
	var big := LabelSettings.new()
	big.font_size = 34
	_defeat_label = Label.new()
	_defeat_label.label_settings = big
	_defeat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_defeat_label)
	var small := LabelSettings.new()
	small.font_size = 19
	small.font_color = Color(1, 1, 1, 0.75)
	_defeat_detail = Label.new()
	_defeat_detail.label_settings = small
	_defeat_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_defeat_detail)

func _show_defeat() -> void:
	defeat_shown = true
	defeat_room.visible = true
	defeat_room.cam.current = true
	_hud_layer.visible = false
	var main_hud := get_node_or_null("../HUD")
	if main_hud:
		main_hud.visible = false
	_preview.visible = false
	var left := farmers.filter(func(f): return f.alive()).size()
	_defeat_label.text = "家豪被抓去當晚餐了……"
	var tip := "提示：撒飼料把家豪引開，讓他一次只對上一個農夫。" if casts.is_empty() else "提示：換個時機或位置降下神蹟再試一次。"
	_defeat_detail.text = "第 %d 次嘗試　｜　撐了 %.1f 秒　｜　還剩 %d 個農夫\n%s\nR 重試　｜　M 回到地圖" % [attempts.size(), time, left, tip]
	_defeat_layer.visible = true

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
	for f in [bird] + farmers:
		var head: Vector3 = f.pos + Vector3(0, f.air + (1.75 if f.is_bird else (3.4 if f.is_boss else 2.85)), 0)
		var show: bool = not camera.is_position_behind(head) and (f.alive() or phase == Phase.ENDED)
		f.bar.visible = show
		if not show:
			continue
		f.bar.position = camera.unproject_position(head) - f.bar.size * 0.5
		var r: float = f.ratio()
		f.chip = maxf(r, f.chip - dt * 0.6) if f.chip > r else r
		f.bar_fill.size.x = 92.0 * r
		f.bar_chip.size.x = 92.0 * f.chip

func _update_phase_label() -> void:
	match phase:
		Phase.PREPARE:
			_phase_label.text = "準備中：可以先撒飼料、換觀察位置　按 Enter 開始"
		Phase.RUNNING:
			_phase_label.text = "戰鬥中  %.1f 秒　｜　R 重試" % time
		Phase.ENDED:
			_phase_label.text = ("勝利！" if outcome == "win" else "落敗…") + "　按 R 重試"

func _toast(text: String, dur: float) -> void:
	_toast_label.text = text
	_toast_t = dur

func _show_summary() -> void:
	var lines: PackedStringArray = []
	var left := farmers.filter(func(f): return f.alive()).size()
	if outcome == "win":
		lines.append("攻下農場大門！這場是你偷偷扳回來的。")
	else:
		lines.append("家豪被農夫圍毆倒下了…（還剩 %d 個農夫）" % left)
	lines.append("")
	lines.append("歷次嘗試：")
	for a in attempts.slice(maxi(attempts.size() - 5, 0)):
		lines.append("  #%d　%s（%.1f 秒）" % [a.num, "勝" if a.outcome == "win" else "敗，剩 %d 個農夫" % a.left, a.time])
	lines.append("")
	lines.append("按 R 回到起點重試（觀察位置會保留）　｜　按 M 回到地圖")
	_summary_label.text = "\n".join(lines)
	_summary_panel.visible = true


# ------------------------------------------------------------------ 開場教學

func start_tutorial() -> void:
	if _tut_seen:
		return
	_tut_seen = true
	_set_tut_step(0)

func _set_tut_step(i: int) -> void:
	tutorial_step = i
	_tut_t = 0.0
	var on := i >= 0 and i < TUT_TEXT.size()
	_tut_arrow.visible = on
	_tut_panel.visible = on
	if not on:
		tutorial_step = -1
		select_skill(0)
		return
	select_skill(i)
	_hotbar.name_t = 0.0   # 教學時說明框已經寫了名字，不用再浮一次
	_tut_label.text = TUT_TEXT[i] + "\n（%d / %d）" % [i + 1, TUT_TEXT.size()]
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
	var cx := hb.position.x + 2.0 + (tutorial_step + 0.5) * Hotbar.S
	var bob := absf(sin(_tut_t * 4.0)) * 10.0
	_tut_arrow.position = Vector2(cx - _tut_arrow.size.x * 0.5, hb.position.y - _tut_arrow.size.y - 14.0 - bob)
	var ps := _tut_panel.size
	var vw := get_viewport().get_visible_rect().size.x
	_tut_panel.position = Vector2(clampf(cx - ps.x * 0.5, 12.0, vw - ps.x - 12.0), _tut_arrow.position.y - ps.y - 10.0 + bob)
