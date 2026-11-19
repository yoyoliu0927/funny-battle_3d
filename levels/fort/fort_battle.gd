extends Node
## 人類要塞的戰局（yujuan）。這是 template 之前那一版的整包戰局程式（原本是共用的 scripts/battle.gd），
## 合併進 develop 時搬進大關資料夾：存檔改用 scripts/progress.gd 的小關 id（"fort/1"…），
## Esc 接上共用的暫停選單，其他照原樣。下面是原本的說明（第一關農場的規則，要塞沿用同一套）。
##
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
const FARMER_MAX_HP := 2.0     # 統一規則：小兵啄一下就倒
## 先攻規則：家豪先打到農夫 → 農夫一下就倒、家豪不受傷；
## 農夫先踢到家豪 → 家豪掉一顆心，但這個農夫踢完就沒力氣了、不會再踢，家豪回頭一定打得贏他。
## 家豪的心 = 這關農夫總數 − 1（自爆農夫也算）：全部正面硬碰會輸，至少要靠神蹟（偷襲、香蕉皮…）搶到一次先手。
const FIRST_STRIKE_DMG := 2.0  # 農夫先手踢中扣的血（= 一顆心）
## 自爆農夫：背著火藥桶，走到家豪身邊就點引信，炸到家豪扣一顆心，旁邊的農夫也會一起被炸倒。
## 家豪搶先啄倒他 → 引信被啄掉、不會爆；被巨石、砲彈、大砲砸倒 → 當場爆炸（可以拿來炸別的農夫）。
const BOMB_FUSE := 0.45        # 點引信到爆炸的時間（跟一般農夫出腳一樣快）
const BOMB_RADIUS := 2.3       # 爆炸範圍
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
const UIStyle := preload("res://scripts/ui/ui_style.gd")   # 全遊戲共用的介面美術（手帳風格）
const HeartBar := preload("res://scripts/ui/heart_bar.gd")
const HEART_HP := 2.0          # 一顆愛心 = 幾點血（家豪 10 點血 = 5 顆心）
const Progress := preload("res://scripts/progress.gd")          # 共用存檔：哪些小關過了
const FortProgress := preload("res://levels/fort/fort_progress.gd")   # 要塞自己的存檔：教學看過了沒
const PauseMenu := preload("res://scripts/ui/pause_menu.gd")    # 共用的暫停選單（Esc）
const SKILLS := [
	# prep = 準備階段（預先佈置）能放幾次；live = 開打後（現場）能放幾次；-1 代表不限次數
	# 兩個次數各算各的，準備階段沒用完的不會留到現場
	# cooldown = 現場用一次之後要等幾秒才能再用（準備階段沒有冷卻）
	{"id": "feed", "name": "飼料", "key": "1", "prep": -1, "live": -1, "cooldown": 1.5, "radius": 0.6, "color": Color(1.0, 0.85, 0.3)},
	{"id": "banana", "name": "香蕉皮", "key": "2", "prep": -1, "live": -1, "cooldown": 4.0, "radius": 0.5, "color": Color(1.0, 0.9, 0.25)},
	{"id": "rock", "name": "巨石", "key": "3", "prep": 1, "live": -1, "cooldown": 8.0, "radius": 0.9, "color": Color(0.85, 0.85, 0.8)},
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
const FEED_GIVE_UP := 6.0       # 往飼料走這麼久還吃不到（被東西擋住）就放棄
const FEED_EAT_TIME := 0.9
const FEED_LINGER := 3.0       # 吃完飼料後，家豪會在原地意猶未盡地東張西望這麼久才繼續衝
const LIGHT_TIME := 5.0
const LIGHT_HEAL := 2.0        # 每秒
const FEED_HEAL := 1.0         # 吃一把飼料回的血
## 大砲（關卡有 cannon_muzzle() 才有）：飼料撒在砲口前，家豪去吃就會鑽進砲管卡住；
## 引信燒完（或玩家按左鍵）就把家豪射向準心指的地方
const CANNON_LURE := 1.6       # 飼料離砲口前方這麼近，家豪就會鑽進砲管
const CANNON_FUSE := 4.0       # 引信燒完的秒數（= 瞄準時間）
const CANNON_MIN_FIRE := 0.6   # 卡進去至少這麼久之後才能按左鍵提早發射
const CANNON_RANGE := 34.0     # 最遠射多遠（2-3 要從要塞射到東邊院子的指揮官高台）
const CANNON_SPLASH := 1.7     # 落地時這個距離內的人會被砸倒
const CANNON_HIT_FARMER := 6.0
## 炮塔（關卡的 towers 有 gun 才會開砲）：塔頂砲手瞄準一下就開砲，砲彈飛一段時間才落地，
## 一直在走的家豪大多躲得掉；站著不動（打架、吃東西、卡在大砲裡）就容易被炸到。
## 梯子腳下撒飼料，家豪會爬上去把砲手踢下去，炮塔就改打人類。
const TURRET_RANGE := 12.0
const TURRET_AIM := 1.0        # 瞄準（地上出現紅圈）多久後開砲
const TURRET_RELOAD := 5.0
const SHOW_EDGE_ARROW := false   # 家豪跑出畫面時的邊緣箭頭（先關掉）
const TURRET_TURN := 1.8        # 炮塔轉向的速度（弧度/秒）：先看到砲管轉過來，才開始瞄準
const TURRET_FACE := 0.12       # 砲管對準到這個角度以內才開始瞄準（紅圈出現）
const TURRET_RECOIL := 0.35     # 開砲後座力的時間
const CANNON_SNAP := 2.2        # 大砲落點離指揮官高台（或炮塔）邊緣這麼近，就自動吸過去
const CHEST_OPEN := 1.3         # 家豪走到寶箱這麼近就會打開
const GOAL_STANDOFF := 4.5      # 沒有農夫可打時，家豪走到離最近的炮塔這麼遠就停下來（叫囂）
const TURRET_FIRST := 2.5      # 開打後第一砲要等多久（第二座再晚一點）
const SHELL_TIME := 1.0        # 砲彈飛行時間
const SHELL_PEAK := 3.0
const SHELL_BLAST := 1.5
const SHELL_DMG_BIRD := 1.0
const SHELL_DMG_FARMER := 4.0
const CLIMB_TIME := 2.6        # 爬上梯子要多久
const TOP_STEP := 0.45         # 從梯子頂端翻過矮牆、踏上塔頂要多久
const TOP_HOLD := 1.0          # 在塔頂站多久（把砲手踢下去、得意一下）才跳回地面
const TOP_STAND := 0.7         # 塔頂的站位：從塔中心往梯子那一側這麼遠（塔頂能站的範圍是矮牆以內）
const LADDER_LURE := 1.4       # 飼料離梯子腳這麼近，家豪吃完就會往上爬

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
const DEMO_ROCK_DELAY := 2.5
const DEMO_ROCK_RADIUS := 0.5   # 示範石頭比巨石小一號
var demo_rock: MeshInstance3D
var _demo_start: Variant = null   # 關卡有示範石頭才有值（world.demo_rock_start）
var has_cannon := false
var cannon_t := -1.0              # 家豪卡在砲管裡多久了（< 0 = 沒在砲管裡）
var cannon_target := Vector3.ZERO # 現在瞄準的落點
var cannon_fire_req := false      # 玩家按了左鍵要提早發射
var launch_from := Vector3.ZERO
var launch_to := Vector3.ZERO
var launch_dur := 1.0
var launch_peak := 3.0
var launch_hurt := true           # true = 被大砲射出去（落地會摔、會砸人）；false = 自己跳下來
var shells: Array = []            # 飛行中的砲彈 {from, to, t, node, side}
var climb_k := -1                 # 正在爬第幾座塔的梯子（-1 = 沒在爬）
var _warn_mat: StandardMaterial3D
var _tower_chain := true          # true = 骨牌（倒向前一座、最後砸大穀倉）；false = 順著巨石的方向倒
var demo_path := PackedVector3Array()
var demo_i := 0   # 右上角敵人欄 {fighter, face, fill, chip, name}

# 神蹟狀態
var selected := 0
var charges: Array = []        # 現場（開打後）剩下的次數
var prep_charges: Array = []   # 準備階段剩下的次數
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
var _phase_start_key: Control
var _enemy_col: VBoxContainer
var _crew_label: Label
var _tower_label: Label
var _bird_bar: PaperBar
var _hearts: HeartBar          # 統一介面：家豪的血改用愛心顯示
var _start_btn: Control        # 右下角「開始 ▶ Enter」
var _edge_arrow: EdgeArrow
var _first_hint: PanelContainer
var _phase_retry_key: Control
var _toast_label: Label
var _summary_panel: PanelContainer
var _summary_label: Label
var _toast_t := 0.0
var _hotbar: Hotbar
var _dialog: DialogBox
var _napoleon_tex: Texture2D
# 新手教學：第一次進關卡時跳出教學彈窗（左邊播示範動畫、右邊說明），H 可以再叫出來
const TUT_PAGES := [
	{"title": "操作方式", "controls": [["W／A／S／D", "飄移"], ["Space", "上升"], ["Shift", "下降"], ["MOUSE", "轉視角"],
		["1／2／3", "選神蹟"], ["LMB", "施放"], ["Enter", "開打"], ["R", "重試"], ["M", "回地圖"], ["Tab", "俯看全場／回到家豪旁邊"], ["H", "再看一次說明"]],
		"body": "你是一個飄在空中的幽靈，只能從旁觀察、偷偷降下神蹟幫家豪。

準備階段先把神蹟佈置好，再按 Enter 開打。"},
	{"title": "家豪會自己行動", "icon": preload("res://assets/ui/jiahao_portrait.png"),
		"body": "不用畫路線，家豪會自己往最近的目標衝過去。

其他的，玩玩看就知道了。"},
	{"title": "飼料", "clip": "feed", "keys": [["1", "選擇"], ["LMB", "對準地面撒下"]],
		"body": "撒在地上，家豪會忍不住跑過去吃，吃一把回一點血。

用它把家豪引到你想要的地方，或拖住他、讓他避開農夫。"},
	{"title": "香蕉皮", "clip": "banana", "keys": [["2", "選擇"], ["LMB", "對準地面丟下"]],
		"body": "丟在路上，誰走過去踩到就會滑倒，躺在地上好一陣子。

放在農夫巡邏的路線上最有效。小心，家豪自己也會踩到。"},
	{"title": "巨石", "clip": "rock", "keys": [["3", "選擇"], ["LMB", "斜坡滾、平地擋"]],
		"body": "一顆圓滾滾的大石頭。放在斜坡上會自己滾下去，一路撞倒擋路的東西；放在平地上就是一塊路障，誰都過不去。\n\n瞄準時會畫出滾動路線，撞得到的東西會亮綠色。"},
]
var tutorial_step: int:       # 教學彈窗現在在第幾頁（-1 = 沒開）
	get:
		return _tut.page if _tut else -1
var _tut_seen := false
var _tut: Node                 # 教學彈窗（scripts/tutorial_popup.gd）
var _hud_layer: CanvasLayer
# 換階段的通知卡（像 Mac 的通知：右上角滑進來、停一下、滑出去）
const NOTICE_TIME := 2.6
var _notice: PanelContainer
var _notice_title: Label
var _notice_body: Label
var _notice_t := -1.0
# 輸了的畫面
const DEFEAT_ORIGIN := Vector3(600.0, 0.0, 600.0)
var defeat_room: Node3D
var defeat_shown := false
var _defeat_delay := -1.0
# 過關後開門、走進下一小關（2-1、2-2）：見 _tick_exit()
const EXIT_WAIT := 2.4         # 過關後先歡呼這麼久，再開始開門
var _exit_delay := -1.0
var _exit_t := -1.0            # -1 = 沒在播
var _exit_cam: Camera3D
var _exit_fade: ColorRect
var _exit_from := Vector3.ZERO
var _exit_air := 0.0            # 開始飛向門口時離地多高（在塔頂過關就是塔頂的高度）
var _exit_fly := 1.0           # 飛到門口要幾秒
var _exit_cam_from := Vector3.ZERO
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
	var steer_side := 1.0  # 繞障礙物時偏向哪一邊（記住，避免左右抖動）
	var steer_angle := 0.0  # 目前繞開的偏角
	var steer_t := -1.0     # 什麼時候決定繞開的（< 0 = 沒在繞）
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
	var bar: Control        # 頭上的血條（現在不畫了，留著給舊的檢查用，一直是 null）
	var chip := 1.0         # 血條淺色那段（扣血後慢慢追上）
	var kind := "farmer"    # "farmer" 一般農夫、"bomber" 自爆農夫
	var struck := false     # 已經先手踢中過家豪（之後不會再踢）
	var dud := false        # 自爆農夫被家豪啄倒或淹死：引信熄了，不會爆
	var exploded := false
	var bomb: Node3D        # 自爆農夫背上的火藥桶

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

	## 圓形貼紙：深色外圈、米色底，中間畫臉；倒下就變灰、打紅叉
	func _draw() -> void:
		var c0 := size * 0.5
		var rad := minf(size.x, size.y) * 0.5
		draw_circle(c0, rad, UIStyle.INK)
		draw_circle(c0, rad - 2.5, Color("f6ecd4") if not boss else Color("ffe9a8"))
		var c := size * Vector2(0.5, 0.6)
		var k := size.x / 60.0
		var skin := Color(0.96, 0.78, 0.62)
		draw_circle(c, 15 * k, skin)
		# 帽子
		var hat := Color(0.25, 0.2, 0.18) if boss else Color(0.92, 0.82, 0.55)
		draw_rect(Rect2(c + Vector2(-20, -16) * k, Vector2(40, 5) * k), hat)
		draw_rect(Rect2(c + Vector2(-11, -27) * k, Vector2(22, 12) * k), hat)
		if not boss:
			draw_rect(Rect2(c + Vector2(-11, -19) * k, Vector2(22, 3) * k), Color(0.8, 0.25, 0.2))
		if boss:
			for sx in [-1.0, 1.0]:
				draw_arc(c + Vector2(6 * sx, -2) * k, 4.5 * k, 0, TAU, 16, UIStyle.INK, 2.0 * k)
			draw_line(c + Vector2(-1.5, -2) * k, c + Vector2(1.5, -2) * k, UIStyle.INK, 2.0 * k)
			draw_rect(Rect2(c + Vector2(-7, 6) * k, Vector2(14, 3) * k), Color(0.35, 0.22, 0.15))
		else:
			for sx in [-1.0, 1.0]:
				draw_circle(c + Vector2(6 * sx, -2) * k, 2.0 * k, UIStyle.INK)
			draw_line(c + Vector2(-5, 7) * k, c + Vector2(5, 7) * k, Color(0.55, 0.3, 0.25), 2.0 * k)
		if dead:
			draw_circle(c0, rad - 2.5, Color(0.25, 0.22, 0.2, 0.55))
			var d := rad * 0.55
			for v in [Vector2(d, d), Vector2(d, -d)]:
				draw_line(c0 - v, c0 + v, UIStyle.INK, 6.0, true)
				draw_line(c0 - v, c0 + v, UIStyle.accent(), 3.5, true)

## 血條（手帳風格）：深色圓角外框、米色底；淺色那段是剛扣掉的血，慢慢追上
class PaperBar extends Control:
	var fill := Color("58b85a")
	var ratio := 1.0
	var chip := 1.0

	func set_values(r: float, c: float) -> void:
		if absf(r - ratio) > 0.001 or absf(c - chip) > 0.001:
			ratio = r
			chip = c
			queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var rad := int(size.y * 0.5)
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color("e9dcc0")
		bg.set_corner_radius_all(rad)
		bg.anti_aliasing = true
		draw_style_box(bg, r)
		var inner := r.grow(-3.0)
		for part in [[chip, Color(1, 0.93, 0.7)], [ratio, fill]]:
			var w: float = inner.size.x * clampf(part[0], 0.0, 1.0)
			if w <= 0.5:
				continue
			var sb := StyleBoxFlat.new()
			sb.bg_color = part[1]
			sb.set_corner_radius_all(int(inner.size.y * 0.5))
			sb.anti_aliasing = true
			draw_style_box(sb, Rect2(inner.position, Vector2(maxf(w, inner.size.y), inner.size.y)))
		var edge := StyleBoxFlat.new()
		edge.draw_center = false
		edge.border_color = UIStyle.INK
		edge.set_border_width_all(2)
		edge.set_corner_radius_all(rad)
		edge.anti_aliasing = true
		draw_style_box(edge, r)

## 圓形大頭貼：深色外圈＋米色底＋頭像
class Portrait extends Control:
	var tex: Texture2D

	func _draw() -> void:
		var c := size * 0.5
		var rad := minf(size.x, size.y) * 0.5
		draw_circle(c, rad, UIStyle.INK)
		draw_circle(c, rad - 2.5, Color("f6ecd4"))
		if tex:
			var s2 := (rad - 3.0) * 2.0
			draw_texture_rect(tex, Rect2(c - Vector2(s2, s2) * 0.5, Vector2(s2, s2)), false)

## 家豪不在畫面裡時，畫面邊緣的箭頭（綠色、深色描邊，跟家豪的血條同色）
class EdgeArrow extends Control:
	var on := false
	var pos := Vector2.ZERO
	var ang := 0.0

	func _draw() -> void:
		if not on:
			return
		var dir := Vector2.from_angle(ang)
		var nrm := Vector2(-dir.y, dir.x)
		var tip := pos + dir * 26.0
		var pts := PackedVector2Array([tip, pos - dir * 6.0 + nrm * 20.0, pos - dir * 6.0 - nrm * 20.0])
		var big := PackedVector2Array([tip + dir * 5.0, pos - dir * 10.0 + nrm * 26.0, pos - dir * 10.0 - nrm * 26.0])
		draw_colored_polygon(big, UIStyle.INK)
		draw_colored_polygon(pts, Color("58b85a"))
		# 箭頭後面一個小圓貼紙寫「家豪」
		var lc := pos - dir * 40.0
		draw_circle(lc, 22.0, UIStyle.INK)
		draw_circle(lc, 19.5, Color("fff8e7"))
		var font := UIStyle.font()
		var tw := font.get_string_size("家豪", HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		draw_string(font, lc + Vector2(-tw * 0.5, 5), "家豪", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UIStyle.INK)

## 技能欄的一格
## 方塊遊戲風格的快捷欄：一整條相連的格子，選中的那格外面套一圈粗白框，圖示用像素點畫
class Hotbar extends Control:
	const S := 84.0          # 一格的大小
	const PX := 4.0          # 圖示一個像素的大小
	var skills: Array = []
	var counts: Array = []        # 現場次數
	var prep_counts: Array = []   # 準備階段次數
	var prepping := true          # 現在是不是準備階段（顯示哪一個階段的次數）
	var cooldowns: Array = []
	var pulse_t := 0.0            # 換階段時整條閃一下，提示次數可能變了
	var selected := 0
	var name_t := 0.0        # 切換後在上方顯示技能名稱的剩餘時間

	func bar_size() -> Vector2:
		return Vector2(skills.size() * S + 4.0, S + 4.0)

	func _process(dt: float) -> void:
		if name_t > 0.0:
			name_t = maxf(name_t - dt, 0.0)
			queue_redraw()
		if pulse_t > 0.0:
			pulse_t = maxf(pulse_t - dt, 0.0)
			queue_redraw()

	## 手帳風格（跟教學卡、對話框同一套）：每個神蹟一張米色圓角紙卡，選中的往上浮、紅框；
	## 中間一顆深色圓貼紙放像素圖示，右上角紅色圓徽章是這個階段還能用幾次
	func _draw() -> void:
		var bs := bar_size()
		var font := UIStyle.font()
		var k := _pulse_k()
		for i in skills.size():
			var cell := Rect2(Vector2(2.0 + i * S, 2.0), Vector2(S, S))
			var is_sel := i == selected
			var card := cell.grow(-5.0)
			if is_sel:
				card.position.y -= 7.0
			var live: int = counts[i] if i < counts.size() else 0
			var prep: int = prep_counts[i] if i < prep_counts.size() else 0
			var cnt: int = prep if prepping else live
			var cd: float = cooldowns[i] if i < cooldowns.size() else 0.0
			var sb := StyleBoxFlat.new()
			sb.bg_color = UIStyle.PAPER if cnt != 0 else Color(0.86, 0.84, 0.8)
			sb.border_color = UIStyle.accent() if is_sel else UIStyle.INK
			sb.set_border_width_all(4 if is_sel else 3)
			sb.border_width_bottom = 6 if is_sel else 5
			sb.set_corner_radius_all(14)
			sb.shadow_color = Color(0, 0, 0, 0.28)
			sb.shadow_size = 5
			sb.shadow_offset = Vector2(2, 4)
			sb.anti_aliasing = true
			draw_style_box(sb, card)
			# 圖示底下的圓貼紙（讓黃色的像素圖示在米色紙上也清楚）
			draw_circle(card.get_center() + Vector2(0, 3), 25.0, Color(0.36, 0.27, 0.2, 0.92 if cnt != 0 else 0.5))
			_draw_icon(skills[i].id, card.get_center() + Vector2(0, 3), cnt == 0)
			if cd > 0.0:
				# 冷卻中：一片暗色從上往下縮短，中間顯示剩下的秒數
				var frac := clampf(cd / float(skills[i].cooldown), 0.0, 1.0)
				var inner := card.grow(-4.0)
				draw_rect(Rect2(inner.position + Vector2(0, inner.size.y * (1.0 - frac)), Vector2(inner.size.x, inner.size.y * frac)), Color(0, 0, 0, 0.55))
				var ct := "%.1f" % cd if cd < 10.0 else "%d" % ceili(cd)
				var cw := font.get_string_size(ct, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
				_shadow_text(font, card.get_center() + Vector2(-cw * 0.5, 9), ct, 26, Color(1, 1, 1))
			# 左上角小小的按鍵數字
			draw_string(font, card.position + Vector2(8, 19), skills[i].key, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(UIStyle.INK, 0.7))
			# 右上角的次數徽章（換階段時徽章跳一下、閃一圈金光）
			var bc := card.position + Vector2(card.size.x - 5.0, 5.0)
			var rad := 17.0 * (1.0 + 0.25 * k)
			draw_circle(bc, rad, UIStyle.INK)
			draw_circle(bc, rad - 2.5, UIStyle.accent() if cnt != 0 else Color(0.55, 0.55, 0.55))
			var txt := "∞" if cnt < 0 else str(cnt)
			var fs := int(20 * (1.0 + 0.3 * k))
			var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			draw_string(font, bc + Vector2(-tw * 0.5, fs * 0.36), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1))
			if k > 0.0:
				draw_arc(bc, rad + 2.0, 0.0, TAU, 24, Color(1.0, 0.85, 0.3, 0.9 * k), 3.0, true)
		# 切換時在上方浮出技能名稱（米色小紙片）
		if name_t > 0.0 and selected < skills.size():
			var nm: String = skills[selected].name
			var a := clampf(name_t / 0.5, 0.0, 1.0)
			var w := font.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
			var tag := Rect2(Vector2((bs.x - w) * 0.5 - 14.0, -46.0), Vector2(w + 28.0, 34.0))
			var tsb := UIStyle.slip_box(Vector2(14, 6), 0.96 * a)
			tsb.border_color = Color(tsb.border_color, a)
			tsb.shadow_color = Color(tsb.shadow_color, tsb.shadow_color.a * a)
			draw_style_box(tsb, tag)
			draw_string(font, Vector2(tag.position.x + 14.0, tag.position.y + 24.0), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(UIStyle.INK, a))

	## 閃一下的強度：開頭快速亮起，再慢慢淡掉
	func _pulse_k() -> float:
		const DUR := 0.9
		if pulse_t <= 0.0:
			return 0.0
		var t := 1.0 - pulse_t / DUR
		return clampf(t / 0.12, 0.0, 1.0) * (1.0 - clampf((t - 0.12) / 0.88, 0.0, 1.0))

	func pulse() -> void:
		pulse_t = 0.9
		queue_redraw()

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
		# 米色筆記紙＋深色實線框＋小小的硬陰影（跟其他介面同一套，不用半透明）
		var sb := UIStyle.slip_box(Vector2(14, 8), a)
		sb.border_color = Color(UIStyle.INK, a)
		sb.set_border_width_all(3)
		sb.border_width_bottom = 5
		sb.set_corner_radius_all(12)
		sb.shadow_color = Color(0, 0, 0, 0.25 * a)
		draw_style_box(sb, box)
		# 左邊：家豪的頭像（圓形大頭貼，深色外圈）
		var pc := off + Vector2(70, H * 0.5)
		draw_circle(pc, 50, Color(UIStyle.INK, a))
		draw_circle(pc, 47, Color(0.965, 0.925, 0.83, a))
		if portrait:
			draw_texture_rect(portrait, Rect2(pc - Vector2(44, 44), Vector2(88, 88)), false, Color(1, 1, 1, a))
		# 右邊：文字
		var font := UIStyle.font()
		var fs := 34
		var tx := off.x + 140.0
		var avail := W - 150.0 - (190.0 if pic else 20.0)
		var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		while tw > avail and fs > 18:
			fs -= 2
			tw = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var ty := off.y + H * 0.5 + fs * 0.35
		draw_string(font, Vector2(tx, ty), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(UIStyle.INK, a))
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
	_ink_interactables()
	_build_preview()
	_build_hud()
	_build_defeat()
	add_child(preload("res://levels/fort/closeup_cam.gd").new())   # 搞笑特寫鏡頭（射出去、落水）
	_build_pause_menu()
	_build_view_toggle()
	reset()
	if view:
		view.snap_to_hero()   # 開場就在家豪旁邊（進場鏡頭播完會飛回這裡）
	if _want_intro():
		_start_intro()
	elif not _auto_run():
		start_tutorial()

## 自動測試在跑（--autotest，或 tools/smoke_test.gd）：不跳教學、不播進場鏡頭、不寫存檔
static func _auto_run() -> bool:
	if "--autotest" in OS.get_cmdline_user_args():
		return true
	var ml := Engine.get_main_loop()
	var scr = ml.get_script() if ml else null
	return scr is Script and String((scr as Script).resource_path).ends_with("smoke_test.gd")

## tools/smoke_test.gd 用的名字（跟 scripts/battle/battle_base.gd 一樣）
var items: Array:
	get:
		return SKILLS
## 敵人：地上的農夫照原樣；炮塔的砲手站在塔頂上，回報的位置是梯子腳（家豪從那裡爬上去）。
## 指揮官站在高台上、只有大砲打得到，不列進來（smoke test 會檢查每個敵人是不是站在走得到的地方）。
var enemies: Array:
	get:
		var out: Array = farmers.filter(func(f): return not f.is_boss)
		for k in towers.size():
			var tw: Dictionary = towers[k]
			if tw.get("ladder") != null:
				var foe := SmokeFoe.new()
				foe.name = "炮塔 %s" % "ABCDEF"[k]
				foe.pos = _ground(Vector3(tw.ladder.x, 0, tw.ladder.y))
				out.append(foe)
		return out

class SmokeFoe:
	var name := ""
	var pos := Vector3.ZERO

func _ensure_actions() -> void:
	var map := {
		"battle_start": [KEY_ENTER, KEY_KP_ENTER], "battle_reset": [KEY_R], "back_to_map": [KEY_M],
		"skill_1": [KEY_1, KEY_KP_1], "skill_2": [KEY_2, KEY_KP_2], "skill_3": [KEY_3, KEY_KP_3],
		"tutorial": [KEY_H],
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
			f.kind = routes[i].get("kind", "farmer")
			if f.kind == "bomber":
				f.name = "自爆農夫"
				f.speed = 2.0
				f.bomb = _make_bomb(f.node)
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
	# 先攻規則：家豪的心 = 農夫總數 − 1（至少一顆）；這關沒有農夫就照原本的血量
	var crew := farmers.filter(func(f): return not f.is_boss).size()
	if crew > 0:
		bird.max_hp = maxf(crew - 1, 1) * FIRST_STRIKE_DMG
	# 骨牌
	for t in world.towers:
		var td := {"node": t.node, "pos": t.pos, "radius": t.radius, "height": t.height,
			"state": "stand", "angle": 0.0, "omega": 0.0, "dir": Vector3.FORWARD, "crushed": false,
			"gun": t.get("gun"), "gunner": t.get("gunner"), "ladder": t.get("ladder"), "top_y": t.get("top_y", 0.0),
			"side": "enemy", "cd": 0.0, "aim_t": -1.0, "lock": Vector3.ZERO}
		if td.gun:
			td["gun_rot"] = (td.gun as Node3D).rotation
			td["gun_pos"] = (td.gun as Node3D).position
			td["recoil"] = 0.0
			td["warn"] = _make_warn_ring()
		if td.gunner:
			td["gunner_xf"] = (td.gunner as Node3D).transform
		towers.append(td)
	_tower_chain = world.get("tower_chain") != false
	has_cannon = world.has_method("cannon_muzzle")
	if world.barn_node:
		_barn_xf = world.barn_node.transform
	_demo_start = world.get("demo_rock_start")
	if _demo_start == null:
		return
	demo_rock = MeshInstance3D.new()
	demo_rock.name = "DemoRock"
	var drng := RandomNumberGenerator.new()
	drng.seed = 999
	demo_rock.mesh = world.make_rock_mesh(drng, 3, 0.08)
	demo_rock.material_override = world._rock_material
	demo_rock.scale = Vector3.ONE * DEMO_ROCK_RADIUS
	world.add_child(demo_rock)

func _build_preview() -> void:
	# 地上的瞄準圈：每一幀沿著地形長出來的細線圈＋淡底色＋中心小十字，被東西擋住時淡淡透出（scripts/ui/aim_ring.gd）
	_preview = preload("res://scripts/ui/aim_ring.gd").new()
	_preview.set("world", world)
	_preview.material_override = StandardMaterial3D.new()
	(_preview.material_override as StandardMaterial3D).albedo_color = Color(1, 1, 1, 0.9)
	_preview.visible = false
	world.add_child(_preview)
	var dot_mesh := SphereMesh.new()
	dot_mesh.radius = 0.09
	dot_mesh.height = 0.18
	dot_mesh.radial_segments = 8
	dot_mesh.rings = 4
	var dm := StandardMaterial3D.new()
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.no_depth_test = false   # 被山坡擋住的那段就看不到（不然會像飄在空中）
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
	var was_prep := phase == Phase.PREPARE
	phase = Phase.PREPARE
	time = 0.0
	_acc = 0.0
	outcome = ""
	events.clear()
	hit_spots.clear()
	casts.clear()
	charges.clear()
	prep_charges.clear()
	cooldowns.clear()
	for s in SKILLS:
		charges.append(s.live)
		prep_charges.append(s.prep)
		cooldowns.append(0.0)
	for c in _fx_root.get_children():
		c.queue_free()
	feeds.clear()
	for r in rocks:
		if r.has("obs"):
			world.obstacles.erase(r.obs)
	rocks.clear()
	lights.clear()
	peels.clear()
	_last_pos.clear()
	for k in towers.size():
		var t: Dictionary = towers[k]
		t.state = "stand"
		t.angle = 0.0
		t.omega = 0.0
		t.crushed = false
		(t.node as Node3D).basis = Basis()
		t.side = "enemy"
		t.cd = TURRET_FIRST + k * 1.3
		t.aim_t = -1.0
		if t.gun:
			(t.gun as Node3D).rotation = t.gun_rot
			(t.gun as Node3D).position = t.gun_pos
			t.recoil = 0.0
			(t.warn as Node3D).visible = false
		if t.gunner:
			(t.gunner as Node3D).transform = t.gunner_xf
			(t.gunner as Node3D).visible = true
	shells.clear()
	climb_k = -1
	barn_state = "stand"
	barn_t = 0.0
	if demo_rock:
		demo_path = simulate_roll(_ground(_demo_start))
		demo_i = 0
		demo_rock.rotation = Vector3.ZERO
		demo_rock.position = (demo_path[0] if demo_path.size() > 0 else _ground(_demo_start)) - Vector3(0, ROCK_RADIUS - DEMO_ROCK_RADIUS, 0)
	if world.barn_node:
		world.barn_node.transform = _barn_xf
	cannon_t = -1.0
	cannon_fire_req = false
	if has_cannon:
		world.reset_cannon()
		cannon_target = _default_cannon_target()
	_fx_timed.clear()
	_reset_chests()
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
		f.steer_t = -1.0
		f.chased = false
		f.aggro = false
		f.alert_t = -1.0
		f.wp = 1
		f.wp_dir = 1
		f.target = null
		f.feed_target = -1
		f.struck = false
		f.dud = false
		f.exploded = false
		if f.bomb:
			f.bomb.visible = true
		f.set_state("idle")
		_anim(f, "Idle")
	_apply_visuals()
	_summary_panel.visible = false
	_hide_defeat()
	_toast("", 0.0)
	_update_phase_label()
	_refresh_slots()
	if not was_prep and _notice:
		notify_phase("回到準備階段", "神蹟次數換回準備階段的次數")
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
	_refresh_slots()
	notify_phase("開戰了", "神蹟次數換成戰鬥中的次數")
	_show_first_hint(false)
	phase_changed.emit("running")

func _end(result: String) -> void:
	phase = Phase.ENDED
	outcome = result
	_log("勝利" if result == "win" else "落敗")
	if result == "win":
		if not _auto_run():   # 自動驗收不動到玩家的存檔
			var st = world.get("stage")
			if st != null:
				Progress.mark_cleared("fort/%d" % int(st))   # 選關地圖：這一小關過了（旗子變綠、下一小關解鎖）
				FortProgress.mark_fort_stage(int(st))
				_toast("第 %d 小關過關！通往下一關的門打開了" % st if st < 3 else "第 3 小關過關！要塞攻下了", 3.0)
		bird.set_state("cheer")
		if climb_k < 0:
			bird.air = 0.0   # 站在塔頂上過關就留在塔頂歡呼（不然會掉進塔裡面）
		# 2-1、2-2：歡呼一下之後開門，家豪走進下一小關（自動驗收不播，除非帶 --doortest）
		if world.get("next_door") != null and (not _auto_run() or "--doortest" in OS.get_cmdline_user_args()):
			_exit_delay = EXIT_WAIT
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

# ------------------------------------------------------------------ 過關後走進下一小關

## 時間軸（秒）：0 鏡頭轉到門前、門開始開 → 0.7 家豪飛到門口 → 落地後走進門 → 轉黑 → 載入下一小關
const EXIT_OPEN := 1.1
const EXIT_FLY_AT := 0.7
const EXIT_WALK := 1.0
const EXIT_FADE := 0.6
var EXIT_FADE_AT: float:
	get:
		return EXIT_FLY_AT + _exit_fly + EXIT_WALK * 0.5

func _start_exit() -> void:
	var door: Node3D = world.next_door
	_exit_t = 0.0
	_summary_panel.visible = false
	if _hud_layer:
		_hud_layer.visible = false
	var hud := get_node_or_null("../HUD")   # 準心、操作提示也收起來
	if hud and "visible" in hud:
		hud.visible = false
	_exit_from = bird.pos
	_exit_air = bird.air   # 在塔頂過關的話，從塔頂飛下來
	climb_k = -1
	var front: Vector3 = door.front_point()
	_exit_fly = clampf(Vector2(front.x - bird.pos.x, front.z - bird.pos.z).length() / 9.0, 0.8, 1.8)
	# 鏡頭：站在院子裡、斜對著門，慢慢往前推
	var side: Vector3 = (door.inward as Vector3).cross(Vector3.UP).normalized()
	_exit_cam_from = door.front_point(10.0) + side * 3.5 + Vector3(0, 4.5, 0)
	_exit_cam = Camera3D.new()
	_exit_cam.fov = camera.fov
	_exit_cam.far = camera.far
	add_child(_exit_cam)
	_exit_cam.global_position = _exit_cam_from
	_exit_cam.look_at(door.global_position + Vector3(0, 1.6, 0), Vector3.UP)
	_exit_cam.make_current()
	# 轉場用的黑幕
	var layer := CanvasLayer.new()
	layer.layer = 30
	add_child(layer)
	_exit_fade = ColorRect.new()
	_exit_fade.color = Color(0, 0, 0, 0)
	_exit_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_exit_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_exit_fade)
	bird.set_state("cheer")

func _tick_exit(dt: float) -> void:
	var door: Node3D = world.next_door
	_exit_t += dt
	var e := _exit_t
	door.set_open(e / EXIT_OPEN)
	var look_at_pt: Vector3 = door.global_position + Vector3(0, 1.6, 0)
	var push := clampf(e / 4.0, 0.0, 1.0)
	_exit_cam.global_position = _exit_cam_from.lerp(door.front_point(6.0) + Vector3(0, 3.2, 0), push * push * (3.0 - 2.0 * push))
	_exit_cam.look_at(look_at_pt, Vector3.UP)
	var front: Vector3 = door.front_point()
	if e >= EXIT_FLY_AT and e < EXIT_FLY_AT + _exit_fly:
		# 飛到門口：拋物線，越遠飛越高
		var k := (e - EXIT_FLY_AT) / _exit_fly
		var dist := Vector2(front.x - _exit_from.x, front.z - _exit_from.z).length()
		if bird.state != "fly":
			bird.set_state("fly")
			bird.fly_from = _exit_from
			bird.fly_to = front
			bird.fly_dur = _exit_fly
		bird.pos = _ground(_exit_from.lerp(front, k))
		bird.air = _exit_air * (1.0 - k) + sin(k * PI) * clampf(dist * 0.22, 1.5, 4.0)
		bird.yaw = atan2(front.x - _exit_from.x, front.z - _exit_from.z)
	elif e >= EXIT_FLY_AT + _exit_fly:
		# 落地後走進門裡
		var k := clampf((e - EXIT_FLY_AT - _exit_fly) / EXIT_WALK, 0.0, 1.0)
		if bird.state != "charge":
			bird.set_state("charge")
			_anim(bird, "Run")
		var inside: Vector3 = door.inside_point()
		bird.pos = front.lerp(inside, k)
		bird.pos.y = front.y
		bird.air = 0.0
		bird.yaw = atan2(inside.x - front.x, inside.z - front.z)
	var fade := clampf((e - EXIT_FADE_AT) / EXIT_FADE, 0.0, 1.0)
	_exit_fade.color.a = fade
	if fade >= 1.0:
		_go_next_stage()

func _go_next_stage() -> void:
	var n: int = int(world.get("stage")) + 1
	_exit_t = -1.0
	Engine.set_meta("fort_stage", n)
	Engine.set_meta("stage_id", "fort/%d" % n)
	Engine.set_meta("fort_from_door", true)   # 下一小關可以知道是從門走進來的
	get_tree().paused = false
	get_tree().change_scene_to_file("res://levels/fort/stage_%d/stage.tscn" % n)

# ------------------------------------------------------------------ 輸入與神蹟

func _unhandled_input(event: InputEvent) -> void:
	# 測試用：在要塞裡按 F1 / F2 / F3 直接重新載入 2-1 / 2-2 / 2-3
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_F1, KEY_F2, KEY_F3] and "stage" in world:
		var n: int = [KEY_F1, KEY_F2, KEY_F3].find(event.keycode) + 1
		Engine.set_meta("stage_id", "fort/%d" % n)
		get_tree().paused = false
		get_tree().change_scene_to_file("res://levels/fort/stage_%d/stage.tscn" % n)
		return
	if _intro_i >= 0:
		var skip: bool = (event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_ESCAPE]) \
			or (event is InputEventMouseButton and event.pressed)
		if skip:
			_end_intro()
		get_viewport().set_input_as_handled()
		return
	# 正在（或準備）走進下一關：空白／Enter／點一下 直接跳到轉場；R 不接（要重玩就回地圖）
	if _exit_t >= 0.0 or _exit_delay > 0.0:
		var skip: bool = (event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]) 			or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT)
		if skip:
			if _exit_t < 0.0:
				_exit_delay = -1.0
				_start_exit()
			_exit_t = maxf(_exit_t, EXIT_FADE_AT)
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("battle_reset"):
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("battle_start"):
		start()
	elif event.is_action_pressed("battle_reset"):
		reset()
	elif event.is_action_pressed("back_to_map"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_tree().change_scene_to_file("res://scenes/level_select.tscn")
	elif event.is_action_pressed("tutorial"):
		_set_tut_step(0)
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
			if bird.state == "cannon":
				cannon_fire_req = true   # 家豪在砲管裡：左鍵 = 發射
			else:
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
	if view and view.overview:
		var ray: Array = view.mouse_ray()   # 俯看時用滑鼠指的位置瞄準
		aim_point = world.ray_ground(ray[0], ray[1], 160.0)
		return
	aim_point = world.ray_ground(camera.global_position, -camera.global_basis.z, 70.0)

# ------------------------------------------------------------------ 兩種視角（Tab）：家豪旁邊 ↔ 俯看全場（共用的 scripts/battle/view_toggle.gd）

var view: Node

func _build_view_toggle() -> void:
	view = preload("res://scripts/battle/view_toggle.gd").new()
	view.name = "ViewToggle"
	view.setup(player, camera, func() -> Vector3: return bird.pos, _view_area)
	view.on_click = func() -> void: try_cast()
	view.changed.connect(func(on: bool) -> void:
		if crosshair:
			crosshair.visible = not on)
	add_child(view)

## 俯看要裝進畫面的範圍：要塞的橢圓院子（2-3 再加上東邊的院子）
func _view_area() -> Rect2:
	var c: Vector2 = world.FORT_C
	var r := Rect2(c.x - world.FORT_RX, c.y - world.FORT_RZ, world.FORT_RX * 2.0, world.FORT_RZ * 2.0)
	if world.get("east"):
		var c2: Vector2 = world.R2_C
		r = r.merge(Rect2(c2.x - world.R2_RX, c2.y - world.R2_RZ, world.R2_RX * 2.0, world.R2_RZ * 2.0))
	return r

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
	var ny := _ground_normal(p).y
	# 巨石本來就是「斜坡上放了會自己滾下去」，所以斜坡都可以放，只有接近垂直的崖面不行（約 65° 以上）；
	# 飼料、香蕉皮放在太陡的地方會滑走，維持原本的限制（約 44°）
	if ny < (0.42 if id == "rock" else 0.72):
		return "這裡太陡了，放不住"
	if id == "rock":
		if not world.rock_ground(p.x, p.z):
			return "這裡放不了"
		if _hits_obstacle(Vector2(p.x, p.z)):
			return "那裡被擋住了"
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

## 目前這個階段還能放幾次（-1 = 不限）
func charges_left(i: int) -> int:
	return prep_charges[i] if phase == Phase.PREPARE else charges[i]

func cast(i: int, p: Vector3) -> bool:
	if phase == Phase.ENDED:
		return false
	var prepping := phase == Phase.PREPARE
	if charges_left(i) == 0:
		_toast("%s 這階段用完了" % SKILLS[i].name if prepping else "%s 用完了" % SKILLS[i].name, 1.4)
		return false
	if not prepping and not no_cooldown and i < cooldowns.size() and cooldowns[i] > 0.0:
		_toast("%s 還要等 %.1f 秒" % [SKILLS[i].name, cooldowns[i]], 1.0)
		return false
	var err := placement_error(i, p)
	if err != "":
		_toast(err, 1.4)
		return false
	var pool: Array = prep_charges if prepping else charges
	if pool[i] > 0:
		pool[i] -= 1
	if not prepping and not no_cooldown:   # 準備階段可以連續佈置，不進冷卻
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
	_show_first_hint(false)
	return true

func _spawn_rock(p: Vector3) -> void:
	var rock := MeshInstance3D.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242 + rocks.size()
	rock.mesh = world.make_rock_mesh(rng, 3, 0.08, false)   # 圓的（平底的會在地上浮起來一截）
	rock.material_override = world._rock_material
	rock.scale = Vector3.ONE * ROCK_RADIUS
	var path := simulate_roll(p)
	rock.position = path[0] if path.size() > 0 else p
	_fx_root.add_child(rock)
	_ink(rock)
	_settle_rock(rock)   # 準備階段還沒滾，先貼地放好
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
	# 撒在寶箱、石頭、建築旁邊（貼著它們）：往外挪到走得到的地方，免得家豪一直往障礙物裡鑽、永遠吃不到
	for k in 3:   # 夾在兩個障礙物之間時，推一次可能又推進另一個，多推幾次
		p = _avoid(p, p, 0.75)
	p = _ground(p)   # 0.75：比繞路判斷（_blocked_at 的 +0.6）再外面一點，才不會一靠近就被轉開
	var node := Node3D.new()
	node.position = p
	node.quaternion = Quaternion(Vector3.UP, _ground_normal(p))
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

## 冷卻時間照真實時間走（準備階段不會進冷卻）
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
	var pn := _ground_normal(p)
	node.position = p + pn * 0.02
	node.basis = Basis(Quaternion(Vector3.UP, pn)) * Basis(Vector3.UP, float(peels.size()) * 1.3)
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
				_log("巨石撞倒了第 %d 座塔！" % (k + 1))
				_toast("撞到塔了！", 1.4)
				_topple(k, flat)
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
		# 自爆農夫被巨石／砲彈／大砲砸倒：當場爆炸（被炸倒的自爆農夫下一格也會跟著爆）
		for f in farmers:
			if f.kind == "bomber" and not f.alive() and not f.exploded and not f.dud:
				_bomb_explode(f)
		_tick_towers(dt)
		_tick_turrets(dt)
		_tick_shells(dt)
		_tick_demo_rock(dt)
		_tick_bird(dt)
		_tick_miracles(dt)
		_tick_peels()
		_tick_chests()
		if farmers.all(func(f): return not f.alive()) and towers_left() == 0:
			_end("win")
		elif not bird.alive():
			_end("lose")
	elif phase == Phase.ENDED:
		bird.t += dt
		_tick_towers(dt)   # 勝負已分，但正在倒的水塔和穀倉要照樣倒完

func _process(dt: float) -> void:
	if view:
		view.enabled = _intro_i < 0 and _exit_t < 0.0 and _exit_delay <= 0.0
	if _intro_i >= 0:
		_tick_intro(dt)
		_fade_near_camera(dt)
		return
	if _exit_delay > 0.0:
		_exit_delay -= dt
		if _exit_delay <= 0.0:
			_start_exit()
	if _exit_t >= 0.0:
		_tick_exit(dt)
		return
	for r in rocks:
		if r.done and not r.get("rested", false):
			_rest_rock(r)
	_fade_near_camera(dt)
	_tick_notice(dt)
	_tick_cooldowns(dt)
	_update_aim()
	if bird and bird.state == "cannon" and phase == Phase.RUNNING:
		_update_cannon_aim()
		_tick_hud_misc(dt)
		return
	var show: bool = phase != Phase.ENDED and aim_point != null and charges_left(selected) != 0 and not defeat_shown
	aim_error = placement_error(selected, aim_point) if aim_point != null else ""
	var ok := show and aim_error == ""
	_preview.visible = show
	if show:
		var r: float = SKILLS[selected].radius
		var n := _ground_normal(aim_point)
		_preview.global_position = aim_point + n * 0.08
		_preview.quaternion = Quaternion(Vector3.UP, n)   # 圈圈貼著坡面，不會一半插在土裡、一半浮在空中
		_preview.scale = Vector3(r, 1, r)
		var c: Color = SKILLS[selected].color if ok else Color(1.0, 0.3, 0.25)
		(_preview.material_override as StandardMaterial3D).albedo_color = Color(c, 0.85)
	_update_path_preview(ok and SKILLS[selected].id == "rock")
	if crosshair and "state" in crosshair:
		crosshair.state = (1 if ok else 2) if show else 0   # 綠＝可以放、紅＝這裡不行
	_tick_hud_misc(dt)

## 家豪卡在砲管裡：砲口跟著準心轉，畫出拋物線和落點
func _update_cannon_aim() -> void:
	# 準心（或俯看時的滑鼠）直接指著敵方炮塔的塔身：射線只會打到地面、會穿過塔落在塔後面，
	# 所以先檢查射線有沒有碰到塔，碰到就當作瞄準那座塔（下面的吸附會鎖到塔頂）
	var ray := _aim_ray()
	var hit_tower := _ray_hits_tower(ray[0], ray[1])
	var raw = aim_point
	if hit_tower >= 0:
		var tp: Vector2 = towers[hit_tower].pos
		raw = _ground(Vector3(tp.x, 0, tp.y))
	_out_of_range = false
	if raw != null:
		var m0: Vector3 = world.cannon_muzzle()
		_out_of_range = Vector2(raw.x - m0.x, raw.z - m0.z).length() > CANNON_RANGE + 0.3
		cannon_target = _snap_cannon_target(_clamp_cannon_target(raw))
		if cannon_locked:
			_out_of_range = false
		if _out_of_range and not _range_warned:
			_toast("太遠了，射不到那裡（會落在紅圈）", 1.4)
		_range_warned = _out_of_range
	world.aim_cannon(cannon_target)
	var m: Vector3 = world.cannon_muzzle()
	var dist := Vector2(cannon_target.x - m.x, cannon_target.z - m.z).length()
	var peak := 2.5 + dist * 0.3 + maxf(cannon_target.y - m.y, 0.0)
	var n := 22
	for k in _dots.size():
		var d: MeshInstance3D = _dots[k]
		if k < n:
			var t := float(k + 1) / (n + 1)
			d.visible = true
			d.global_position = m.lerp(cannon_target, t) + Vector3.UP * peak * 4.0 * t * (1.0 - t)
			d.scale = Vector3.ONE * (1.2 - t * 0.5)
		else:
			d.visible = false
	_preview.visible = true
	var cn := _ground_normal(cannon_target)
	_preview.global_position = cannon_target + cn * 0.08
	_preview.quaternion = Quaternion(Vector3.UP, cn)
	_preview.scale = Vector3(1.2, 1, 1.2)
	var on_boss: bool = world.has_method("on_boss_platform") and world.on_boss_platform(cannon_target)
	var ring_col := Color(0.4, 1.0, 0.4, 0.9) if (on_boss or cannon_locked) else Color(1, 0.6, 0.2, 0.85)
	if _out_of_range:
		ring_col = Color(1.0, 0.25, 0.2, 0.9)   # 超出射程：落點圈變紅（落點已經被拉回最遠的地方）
	(_preview.material_override as StandardMaterial3D).albedo_color = ring_col
	if cannon_locked:
		var pulse := 1.0 + 0.12 * sin(Time.get_ticks_msec() * 0.012)
		_preview.scale = Vector3(2.2 * pulse, 1, 2.2 * pulse)
	if crosshair and "highlight" in crosshair:
		crosshair.highlight = not _out_of_range

var _out_of_range := false
var _range_warned := false

## 現在瞄準用的射線 [起點, 方向]：平常是準心，俯看（Tab）時是滑鼠
func _aim_ray() -> Array:
	if view and view.overview:
		return view.mouse_ray()
	return [camera.global_position, -camera.global_basis.z]

## 射線有沒有碰到還站著的敵方炮塔（把塔當成一根圓柱）；碰到回傳塔的編號，沒有回傳 -1
func _ray_hits_tower(o: Vector3, d: Vector3) -> int:
	var best := -1
	var best_t := INF
	for k in towers.size():
		var t: Dictionary = towers[k]
		if t.state != "stand" or t.side != "enemy" or t.gun == null:
			continue
		var c: Vector2 = t.pos
		var r: float = float(t.radius) + 0.35
		var base_y: float = (t.node as Node3D).global_position.y
		var top_y: float = base_y + float(t.height) + 0.6
		# 水平面上：|o.xz + s*d.xz - c| = r
		var ox := o.x - c.x
		var oz := o.z - c.y
		var a := d.x * d.x + d.z * d.z
		if a < 0.000001:
			continue
		var b := 2.0 * (ox * d.x + oz * d.z)
		var cc := ox * ox + oz * oz - r * r
		var disc := b * b - 4.0 * a * cc
		if disc < 0.0:
			continue
		var sq := sqrt(disc)
		for s in [(-b - sq) / (2.0 * a), (-b + sq) / (2.0 * a)]:
			if s > 0.0 and s < best_t:
				var y: float = o.y + d.y * s
				if y >= base_y - 0.5 and y <= top_y:
					best_t = s
					best = k
					break
	return best

func _tick_hud_misc(dt: float) -> void:
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
	# 偵測扇形：只強調離家豪最近的那一個，其他只留淡淡的外框
	var focus: Fighter = null
	var fd := INF
	for f in farmers:
		if f.cone != null and f.alive() and not f.aggro:
			var d := _flat_dist(f.pos, bird.pos)
			if d < fd:
				fd = d
				focus = f
	for f in farmers:
		_draw_cone(f, f == focus)
	var up := 0
	var crew := 0
	for row in _enemy_rows:
		var f: Fighter = row.fighter
		if row.bar != null:
			(row.bar as PaperBar).set_values(f.ratio() if f.alive() else 0.0, f.chip)
		else:
			crew += 1
			up += 1 if f.alive() else 0
		var face: EnemyFace = row.face
		if face.dead != (not f.alive()):
			face.dead = not f.alive()
			face.queue_redraw()
	if _crew_label:
		_crew_label.text = "農夫 %d/%d" % [up, crew]
	if _tower_label:
		_tower_label.text = "敵方炮塔 %d/%d" % [towers_left(), towers_total()]
	if _bird_bar:
		_bird_bar.set_values(bird.ratio() if bird.alive() else 0.0, bird.chip)
	if _hearts:
		_hearts.hp = maxf(bird.hp, 0.0)
	if _start_btn:
		_start_btn.visible = phase == Phase.PREPARE and _intro_i < 0
	_update_edge_arrow()

# ------------------------------------------------------------------ 農夫

func _farmer_open(f: Fighter) -> bool:
	return (f.heavy and f.state == "recover") or f.state in ["pant", "stagger", "down", "getup", "startled", "slip"]

func _bird_targetable() -> bool:
	# 飛行中、或已經站上塔頂時，地面上的人打不到
	return bird.alive() and bird.state != "fly" and not (bird.state == "climb" and bird.t >= CLIMB_TIME)

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
		f.dud = true   # 火藥泡水，不會爆
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
			if dist <= f.reach and _bird_targetable() and not f.struck:
				_farmer_attack(f)
		"windup":
			_face(f, bird.pos)
			if f.t >= f.windup:
				if dist <= f.reach + 0.35 and _bird_targetable():
					_hit_bird(FIRST_STRIKE_DMG, false, f.pos, f)
					f.struck = true   # 先手只有一次：踢完就沒力氣了
				f.set_state("recover")
		"fuse":
			# 自爆農夫點了引信，抱著火藥桶衝過來
			_face(f, bird.pos)
			if f.t >= BOMB_FUSE:
				_bomb_explode(f)
		"recover":
			if f.t >= f.recover:
				f.heavy = false
				if dist <= f.reach and _bird_targetable() and not f.struck:
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

func _topple(k: int, push := Vector3.ZERO) -> void:
	var t: Dictionary = towers[k]
	if t.state != "stand":
		return
	t.state = "fall"
	t.omega = 0.35
	if not _tower_chain:
		# 不是骨牌：順著巨石滾過來的方向倒
		var pd := Vector3(push.x, 0, push.z)
		t.dir = pd.normalized() if pd.length() > 0.0001 else Vector3.FORWARD
		return
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
		if not _tower_chain:
			pass
		elif k > 0:
			var n: Dictionary = towers[k - 1]
			if n.state == "stand" and reach >= (t.pos as Vector2).distance_to(n.pos) - n.radius:
				_log("第 %d 座水塔砸倒第 %d 座" % [k + 1, k])
				_topple(k - 1)
		elif barn_state == "stand" and world.barn_node:
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
						_log("塔倒下來壓到家豪")
						_hit_bird(minf(3.0, maxf(f.hp - 1.0, 0.0)), true, Vector3(a.x, 0, a.y))
					else:
						f.hp = 0.0
						f.set_state("dead")
						_anim(f, "Death")
						_log("塔倒下來壓倒了%s" % f.name)
		if t.angle >= 1.45:
			t.state = "down"
	# 大穀倉垮掉的動畫
	if barn_state == "collapse":
		barn_t += dt
		var k2 := clampf(barn_t / 0.7, 0.0, 1.0)
		var xf := _barn_xf
		xf.basis = _barn_xf.basis * Basis(Vector3.FORWARD, 0.12 * k2)
		xf.basis = xf.basis.scaled(Vector3(1.0 + 0.08 * k2, 1.0 - 0.6 * k2 * k2, 1.0 + 0.08 * k2))
		if world.barn_node:
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
		elif e.kind == "gunner":
			# 被踢飛的砲手：拋物線飛出去、一邊翻滾
			e.vel.y -= 12.0 * dt
			n2.global_position += e.vel * dt
			n2.rotate_x(dt * 9.0)
		if e.t >= e.life:
			if e.kind == "gunner":
				n2.visible = false   # 砲手是場景裡原本的東西，重試時要放回去，不能刪
			else:
				n2.queue_free()
			_fx_timed.remove_at(i)

## 示範石頭只是滾下來給玩家看，不會傷人、不會撞倒水塔
func _tick_demo_rock(_dt: float) -> void:
	if demo_rock == null or time < DEMO_ROCK_DELAY or demo_i >= demo_path.size() - 1:
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
	# 排在變半透明的建築前面畫：建築擋在前面時，扇形會被建築蓋住（不會穿過建築浮在最上面）
	m.render_priority = -1
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(mi)
	return mi

## 把偵測區畫成貼著地面的紅色扇形（紅 = 有攻擊範圍的感覺）；
## 離家豪最近的那個填色比較明顯，其他只有淡淡的外框
func _draw_cone(f: Fighter, focus := true) -> void:
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
		var a0 := (0.2 if focus else 0.04) * (1.0 - 0.08 * r)
		var a1 := (0.2 if focus else 0.04) * (1.0 - 0.08 * (r + 1))
		var c0 := Color(1.0, 0.1, 0.08, a0 * 1.4)
		var c1 := Color(1.0, 0.1, 0.08, a1 * 1.4)
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
	var edge := Color(1.0, 0.2, 0.15, 0.95 if focus else 0.45)
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

## 還沒拿下的敵方炮塔（被撞倒或被佔領都算拿下）；第一關的水塔沒有砲，不算
func towers_left() -> int:
	return towers.filter(func(t): return t.gun != null and t.state == "stand" and t.side == "enemy").size()

func towers_total() -> int:
	return towers.filter(func(t): return t.gun != null).size()

func _farmer_attack(f: Fighter) -> void:
	# 先攻規則：沒有重踢，每個農夫只有一次先手
	f.heavy = false
	f.attack_n += 1
	if f.kind == "bomber":
		f.set_state("fuse")
		_anim(f, "Run", 1.2)
		_log("%s點燃了引信" % f.name)
		_toast("自爆農夫點燃引信！", 1.0)
		return
	f.set_state("windup")
	_anim(f, "Kick_Right", 1.3)

## 自爆農夫背上的火藥桶（紅色木桶＋頂上的引信火花）
func _make_bomb(parent: Node3D) -> Node3D:
	var root := Node3D.new()
	root.name = "Bomb"
	parent.add_child(root)
	root.position = Vector3(0, 1.3, -0.42)
	var barrel := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.3
	cm.bottom_radius = 0.3
	cm.height = 0.62
	barrel.mesh = cm
	barrel.material_override = _toon_mat(Color(0.78, 0.16, 0.12))
	barrel.name = "Barrel"
	root.add_child(barrel)
	for y in [-0.2, 0.2]:
		var ring := MeshInstance3D.new()
		var rm := CylinderMesh.new()
		rm.top_radius = 0.315
		rm.bottom_radius = 0.315
		rm.height = 0.07
		ring.mesh = rm
		ring.material_override = _toon_mat(Color(0.22, 0.18, 0.16))
		ring.position.y = y
		root.add_child(ring)
	var spark := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.09
	sm.height = 0.18
	spark.mesh = sm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.85, 0.25)
	spark.material_override = mat
	spark.position.y = 0.45
	spark.name = "Spark"
	root.add_child(spark)
	return root

## 自爆農夫爆炸：炸到家豪扣一顆心，範圍內的農夫一起倒
func _bomb_explode(f: Fighter) -> void:
	f.exploded = true
	f.hp = 0.0
	if f.state != "dead":
		f.set_state("dead")
		_anim(f, "Death")
	if f.bomb:
		f.bomb.visible = false
	var p := f.pos
	_puff(p + Vector3.UP * 0.4, Color(1.0, 0.55, 0.15, 0.85), 9, 0.7)
	_puff(p + Vector3.UP * 0.9, Color(0.3, 0.27, 0.25, 0.7), 7, 0.9)
	_noise_at(p)
	_toast("轟！", 0.9)
	_log("%s爆炸了" % f.name)
	for o in farmers:
		if o == f or o.is_boss or not o.alive() or o.air >= 1.0:
			continue
		if _flat_dist(o.pos, p) < BOMB_RADIUS:
			o.hp = 0.0
			var away: Vector3 = o.pos - p
			away.y = 0.0
			o.kb_vel = (away.normalized() if away.length() > 0.01 else Vector3.BACK) * 4.0
			o.set_state("dead")
			_anim(o, "Death")
			_log("爆炸把%s炸倒了" % o.name)
	var b := bird
	if _bird_targetable() and b.air < 1.5 and not b.state in ["launch", "cannon"] and _flat_dist(b.pos, p) < BOMB_RADIUS:
		_log("爆炸炸到家豪")
		_hit_bird(FIRST_STRIKE_DMG, false, p)

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
	if cannon_t >= 0.0 and b.state != "cannon":
		# 還沒發射就被打出來了（農夫把牠從砲管拔出來）
		cannon_t = -1.0
		world.set_fuse(-1.0)
		if b.state != "fly":
			b.air = 0.0
		_log("家豪被從砲管裡拔了出來")
	if climb_k >= 0 and b.state != "climb":
		climb_k = -1
		if b.state != "fly":
			b.air = 0.0
		_log("家豪從梯子上摔了下來")
	if not b.state in ["fly", "cannon", "launch", "climb"]:
		_apply_knockback(b, dt)
	var tgt := _nearest_farmer(b.pos)
	if tgt == null:
		tgt = _tower_goal(b.pos)   # 農夫都倒了（或這關沒有農夫）：走去最近的炮塔前面叫囂
	b.target = tgt
	if tgt == null:
		return
	var goal := tgt == _goal
	var dist := _flat_dist(b.pos, tgt.pos)
	# 飼料優先：不在出招、挨打、飛行中時，聞到飼料就跑去吃
	if b.state in ["charge", "return", "feed", "linger"]:
		var fi := _nearest_feed(b.pos, FEED_SENSE)
		if fi >= 0:
			if b.state != "feed":
				_log("家豪看到飼料，跑去吃")
				b.t = 0.0   # 放棄的計時從開始走向飼料算起
			elif fi != b.feed_target:
				b.t = 0.0
			b.feed_target = fi
			b.state = "feed"
	match b.state:
		"charge":
			if goal:
				_bird_walk(tgt.pos, b.speed * 0.8, dt, "charge")
				if dist < 0.6:
					b.set_state("linger")
			else:
				_bird_walk(tgt.pos, b.speed * (1.35 if tgt.state == "down" else 1.0), dt, "charge")
				if dist <= b.reach:
					b.set_state("windup")
		"feed":
			if b.feed_target < 0 or b.feed_target >= feeds.size():
				b.set_state("charge")
			elif b.t > FEED_GIVE_UP:
				# 走了好一陣子還是吃不到（被擋住）：放棄這一把，回去做原本的事
				_log("家豪吃不到那把飼料，放棄了")
				(feeds[b.feed_target].node as Node3D).queue_free()
				feeds.remove_at(b.feed_target)
				b.feed_target = -1
				b.set_state("charge")
			else:
				var fp: Vector3 = feeds[b.feed_target].pos
				_bird_walk(fp, b.speed * 0.85, dt, "feed")
				# 飼料貼著障礙物時家豪走不到正上方：靠得夠近（1.1 公尺內）就算到了
				var fd := _flat_dist(b.pos, fp)
				if fd < 0.35 or (fd < 1.1 and _blocked_at(fp)):
					if has_cannon and _cannon_at(fp) >= 0:
						world.select_cannon(_cannon_at(fp))
						cannon_target = _default_cannon_target()
						(feeds[b.feed_target].node as Node3D).queue_free()
						feeds.remove_at(b.feed_target)
						_enter_cannon()
					elif _ladder_at(fp) >= 0:
						(feeds[b.feed_target].node as Node3D).queue_free()
						feeds.remove_at(b.feed_target)
						_start_climb(_ladder_at(fp))
					else:
						b.set_state("eat")
		"eat":
			if b.t >= FEED_EAT_TIME:
				var fi := _nearest_feed(b.pos, 1.2)
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
		"cannon":
			_tick_cannon(dt)
		"climb":
			_tick_climb(dt)
		"launch":
			var k := clampf(b.t / launch_dur, 0.0, 1.0)
			var p := launch_from.lerp(launch_to, k) + Vector3.UP * launch_peak * 4.0 * k * (1.0 - k)
			var gy: float = world.height_at(p.x, p.z)
			b.pos = Vector3(p.x, gy, p.z)
			b.air = maxf(p.y - gy, 0.0)
			b.yaw = atan2(launch_to.x - launch_from.x, launch_to.z - launch_from.z)
			if k >= 1.0:
				_land_cannon()
		"return":
			_bird_walk(tgt.pos, b.speed * 0.75, dt, "return")
			if goal:
				if dist < 0.6:
					b.set_state("linger")
			elif _farmer_open(tgt) and dist < 6.5:
				_log("家豪看到%s的破綻，提前反擊" % tgt.name)
				b.set_state("charge")
			elif dist <= tgt.reach + 0.5:
				b.set_state("charge")

## 沒有農夫可打時的目標：最近一座還沒拿下的炮塔前方（假的 Fighter，只用到位置）
var _goal := Fighter.new()
func _tower_goal(from: Vector3) -> Fighter:
	var best := -1
	var bd := INF
	for k in towers.size():
		var t: Dictionary = towers[k]
		if t.gun == null or t.state != "stand" or t.side != "enemy":
			continue
		var d := Vector2(from.x - t.pos.x, from.z - t.pos.y).length()
		if d < bd:
			bd = d
			best = k
	if best < 0:
		return null
	var tp: Vector2 = towers[best].pos
	var away := Vector2(from.x - tp.x, from.z - tp.y)
	away = away.normalized() if away.length() > 0.01 else Vector2(0, 1)
	var spot := tp + away * GOAL_STANDOFF
	_goal.name = "炮塔" + _tower_name(best)
	_goal.hp = 1.0
	_goal.state = "idle"
	# 叫囂的位置剛好落在寶箱、石頭上的話往外挪（不然家豪會一直往裡面鑽）
	_goal.pos = _ground(world.clamp_play(_avoid(Vector3(spot.x, 0, spot.y), Vector3(spot.x, 0, spot.y), 0.4)))
	return _goal

## 寶箱：家豪走過去就打開，補滿血、神蹟冷卻清空
var _chests_open: Array = []
func _tick_chests() -> void:
	var list = world.get("chests")
	if list == null:
		return
	if _chests_open.size() != list.size():
		_chests_open.resize(list.size())
		_chests_open.fill(false)
	for i in list.size():
		if _chests_open[i] or not bird.alive() or bird.air > 0.5:
			continue
		var cp: Vector2 = list[i].pos
		if Vector2(bird.pos.x - cp.x, bird.pos.z - cp.y).length() < CHEST_OPEN:
			_chests_open[i] = true
			var node := list[i].node as Node3D
			if node:
				var ap := node.find_child("AnimationPlayer", true, false) as AnimationPlayer
				if ap and ap.has_animation("open"):
					ap.play("open")
				_puff(node.global_position + Vector3.UP * 0.8, Color(1.0, 0.85, 0.35, 0.8), 8, 0.5)
			# 開打後神蹟不限次數、只有冷卻，所以寶箱給的是：家豪補滿血＋冷卻全部清空
			bird.hp = bird.max_hp
			for k in cooldowns.size():
				cooldowns[k] = 0.0
			_refresh_slots()
			_log("家豪打開了寶箱（補滿血、神蹟冷卻清空）")
			_toast("打開寶箱！家豪補滿血、神蹟冷卻清空", 2.2)

func _reset_chests() -> void:
	_chests_open.clear()
	var list = world.get("chests")
	if list == null:
		return
	for c in list:
		var node := c.node as Node3D
		if node:
			var ap := node.find_child("AnimationPlayer", true, false) as AnimationPlayer
			if ap and ap.has_animation("open"):
				ap.play("open")
				ap.seek(0.0, true)
				ap.stop()

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
	var sdir := _steer_dir(b, d.normalized(), step.length(), d.length())
	b.yaw = atan2(sdir.x, sdir.z)
	var moved: Vector3 = world.clamp_play(_avoid(b.pos, b.pos + sdir * step.length(), 0.35))
	moved = _separate(b, moved, 0.7)
	if _wall_crossing(b.pos, moved) == null:
		b.pos = _ground(moved)

# ------------------------------------------------------------------ 大砲

func _default_cannon_target() -> Vector3:
	var m: Vector3 = world.cannon_muzzle()
	return _ground(m + world.cannon_dir() * 12.0)

## 瞄準輔助：落點靠近指揮官高台（還在場上）就吸到高台中間，鎖定時提示一次
## （從遠處用第一人稱準心瞄一個小高台很難，差一點點就掉到台下）
var cannon_locked := false
func _snap_cannon_target(p: Vector3) -> Vector3:
	var lock := false
	var what := ""
	var m: Vector3 = world.cannon_muzzle()
	if world.has_method("on_boss_platform") and boss and boss.alive() and "PLATFORM_C" in world:
		var c: Vector2 = world.PLATFORM_C
		if Vector2(p.x, p.z).distance_to(c) < world.PLATFORM_R + CANNON_SNAP \
				and Vector2(c.x - m.x, c.y - m.z).length() <= CANNON_RANGE + 0.5:
			p = _ground(Vector3(c.x, 0, c.y))
			lock = true
			what = "指揮官"
	if not lock:
		# 敵方炮塔：落點吸到塔頂，家豪會直接站上去把砲手踢下去
		for k in towers.size():
			var t: Dictionary = towers[k]
			if t.gun == null or t.state != "stand" or t.side != "enemy":
				continue
			var tp: Vector2 = t.pos
			if Vector2(p.x, p.z).distance_to(tp) < t.radius + CANNON_SNAP:
				p = _ground(Vector3(tp.x, 0, tp.y))
				lock = true
				what = "炮塔" + _tower_name(k)
				break
	if lock and not cannon_locked:
		_toast("鎖定%s！左鍵發射" % what, 1.2)
	cannon_locked = lock
	return p

## 落點在哪一座敵方炮塔上（沒有 = -1）
func _tower_top_at(p: Vector3) -> int:
	for k in towers.size():
		var t: Dictionary = towers[k]
		if t.gun != null and t.state == "stand" and t.side == "enemy" and t.ladder != null:
			if Vector2(p.x, p.z).distance_to(t.pos) < t.radius + 0.6:
				return k
	return -1

## 把準心指的點收進射程內
func _clamp_cannon_target(p: Vector3) -> Vector3:
	var m: Vector3 = world.cannon_muzzle()
	var d := Vector3(p.x - m.x, 0, p.z - m.z)
	if d.length() > CANNON_RANGE:
		d = d.normalized() * CANNON_RANGE
	return _ground(m + d)

## 飼料撒在哪一門大砲的砲口前（沒有 = -1）
func _cannon_at(p: Vector3) -> int:
	var n: int = world.cannon_count() if world.has_method("cannon_count") else 1
	for i in n:
		var spot: Vector3 = world.cannon_bait_spot_of(i) if world.has_method("cannon_bait_spot_of") else world.cannon_bait_spot()
		if _flat_dist(p, spot) < CANNON_LURE:
			return i
	return -1

func _enter_cannon() -> void:
	var b := bird
	b.set_state("cannon")
	b.kb_vel = Vector3.ZERO
	cannon_t = 0.0
	cannon_fire_req = false
	world.set_fuse(1.0)
	_log("家豪鑽進砲管吃飼料，結果卡住了")
	_toast("家豪卡在砲管裡！瞄準落點，左鍵發射", 2.2)
	_tick_cannon(0.0)

## 卡在砲管裡：屁股露在外面亂踢，引信一路燒
func _tick_cannon(dt: float) -> void:
	var b := bird
	cannon_t += dt
	var m: Vector3 = world.cannon_muzzle()
	var dir: Vector3 = world.cannon_dir()
	var p := m + dir * 0.15
	var gy: float = world.height_at(p.x, p.z)
	b.pos = Vector3(p.x, gy, p.z)
	b.air = maxf(m.y - gy - 0.55, 0.0)
	b.yaw = atan2(-dir.x, -dir.z)   # 頭朝砲管裡面
	world.set_fuse(1.0 - cannon_t / CANNON_FUSE)
	if (cannon_fire_req and cannon_t >= CANNON_MIN_FIRE) or cannon_t >= CANNON_FUSE:
		_fire_cannon()

func _fire_cannon() -> void:
	var b := bird
	var m: Vector3 = world.cannon_muzzle()
	launch_from = m
	launch_to = cannon_target
	var dist := Vector2(launch_to.x - m.x, launch_to.z - m.z).length()
	launch_dur = 0.6 + dist * 0.038
	launch_peak = 2.5 + dist * 0.3 + maxf(launch_to.y - m.y, 0.0)
	launch_hurt = true
	cannon_t = -1.0
	cannon_fire_req = false
	cannon_locked = false
	world.set_fuse(0.0)
	b.set_state("launch")
	_noise_at(m)
	_log("砰！大砲把家豪射向（%.1f, %.1f）" % [launch_to.x, launch_to.z])
	_toast("砰！", 0.8)
	_puff(m, Color(0.9, 0.9, 0.88, 0.6), 6, 0.5)

func _land_cannon() -> void:
	var b := bird
	var p := launch_to
	b.air = 0.0
	if not launch_hurt:
		# 自己從塔上跳下來：輕輕落地
		b.pos = _ground(world.clamp_play(p))
		b.set_state("land")
		return
	_puff(p, Color(0.85, 0.8, 0.7, 0.55), 8, 0.6)
	_noise_at(p)
	# 落在指揮官的高台上：一頭撞翻指揮官
	if world.has_method("on_boss_platform") and world.on_boss_platform(p):
		b.pos = _ground(p)
		if boss and boss.alive():
			boss.hp = 0.0
			boss.set_state("dead")
			_anim(boss, "Death")
			_log("家豪從天而降，一頭撞翻了%s！" % boss.name)
			_toast("正中%s！" % boss.name, 2.0)
		b.set_state("land")
		return
	# 落在敵方炮塔頂上：直接站上去，把砲手踢下去
	var tk := _tower_top_at(p)
	if tk >= 0:
		climb_k = tk
		b.set_state("climb")
		b.t = CLIMB_TIME + TOP_STEP   # 跳過爬梯子那段，直接在塔頂站好
		_log("家豪從天而降，落在炮塔%s頂上" % _tower_name(tk))
		_tick_climb(0.0)
		return
	# 落在別的地方：砸倒旁邊的人，自己也摔一下
	var hit_any := false
	for f in farmers:
		if f.alive() and not f.is_boss and _flat_dist(f.pos, p) < CANNON_SPLASH:
			f.hp = maxf(f.hp - CANNON_HIT_FARMER, 0.0)
			var away: Vector3 = f.pos - p
			away.y = 0.0
			f.kb_vel = (away.normalized() if away.length() > 0.01 else Vector3.BACK) * 4.0
			_aggro(f)
			_anim(f, "Death")
			f.set_state("dead" if f.hp <= 0.0 else "down")
			_log("家豪砸在%s頭上（剩 %d）" % [f.name, ceili(f.hp)])
			hit_any = true
	if hit_any:
		_toast("砸中了！", 1.2)
	b.pos = _ground(world.clamp_play(p))
	b.hp = maxf(b.hp - 1.0, 1.0)
	_log("家豪摔在地上（剩 %d）" % ceili(b.hp))
	b.set_state("land")

# ------------------------------------------------------------------ 炮塔：開砲、爬梯子、佔領

func _make_warn_ring() -> MeshInstance3D:
	if _warn_mat == null:
		_warn_mat = StandardMaterial3D.new()
		_warn_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_warn_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_warn_mat.no_depth_test = false   # 被建築、山坡擋住的部分看不到
		_warn_mat.render_priority = -1
		_warn_mat.albedo_color = Color(1.0, 0.2, 0.15, 0.85)
	var mi := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = SHELL_BLAST - 0.12
	tm.outer_radius = SHELL_BLAST
	tm.rings = 32
	tm.ring_segments = 4
	mi.mesh = tm
	mi.material_override = _warn_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visible = false
	world.add_child(mi)
	return mi

var _ally_mat: StandardMaterial3D
## 我方炮塔瞄準的圈是綠色（敵方是紅色），一眼看得出是在幫家豪開砲
func _ally_warn_mat() -> StandardMaterial3D:
	if _ally_mat == null:
		_ally_mat = _warn_mat.duplicate() as StandardMaterial3D
		_ally_mat.albedo_color = Color(0.3, 1.0, 0.35, 0.85)
	return _ally_mat

func _gun_muzzle(t: Dictionary) -> Vector3:
	var g := t.gun as Node3D
	return g.global_position + Vector3(sin(g.rotation.y), 0, cos(g.rotation.y)) * 1.1 + Vector3.UP * 0.8

## 炮塔要打誰：敵方炮塔打家豪，被佔領的炮塔打最近的農夫（老闆打不到）
func _turret_target(k: int) -> Variant:
	var t: Dictionary = towers[k]
	var origin := Vector3(t.pos.x, 0, t.pos.y)
	if t.side == "enemy":
		var b := bird
		if not b.alive() or b.state in ["launch", "fly"] or b.air > 1.5 or (b.state == "climb" and climb_k == k):
			return null
		return b.pos if _flat_dist(origin, b.pos) <= TURRET_RANGE else null
	var best: Variant = null
	var bd := TURRET_RANGE
	for f in farmers:
		if f.alive() and not f.is_boss and f.air < 1.0:
			var d := _flat_dist(origin, f.pos)
			if d <= bd:
				bd = d
				best = f.pos
	return best

## 炮塔：先把砲管慢慢轉向目標（看得到在轉）→ 對準了才開始瞄準（地上出現紅圈，越來越亮）
## → 開砲（砲管往後一縮、砲口冒煙，砲彈從砲口飛出去）
func _tick_turrets(dt: float) -> void:
	for k in towers.size():
		var t: Dictionary = towers[k]
		if t.gun == null:
			continue
		var gun := t.gun as Node3D
		var warn := t.warn as MeshInstance3D
		# 後座力：開砲後砲管沿著砲口反方向縮一下再回來
		var rec: float = t.get("recoil", 0.0)
		if rec > 0.0:
			rec = maxf(rec - dt, 0.0)
			t.recoil = rec
		var kick := sin(clampf(rec / TURRET_RECOIL, 0.0, 1.0) * PI) * 0.35
		gun.position = t.gun_pos - Vector3(sin(gun.rotation.y), 0, cos(gun.rotation.y)) * kick
		if t.state != "stand":
			warn.visible = false
			continue
		var tgt: Variant = _turret_target(k)
		var look: Variant = t.lock if t.aim_t >= 0.0 else tgt
		if t.aim_t >= 0.0 and tgt != null:
			t.lock = tgt
			look = tgt
		# 砲管（和砲手）轉向要打的點
		var facing := false
		if look != null:
			var d: Vector3 = (look as Vector3) - gun.global_position
			var want := atan2(d.x, d.z)
			gun.rotation.y = _turn_toward(gun.rotation.y, want, TURRET_TURN * dt)
			facing = absf(wrapf(want - gun.rotation.y, -PI, PI)) < TURRET_FACE
			if t.gunner and (t.gunner as Node3D).visible:
				(t.gunner as Node3D).rotation.y = gun.rotation.y
		if t.aim_t >= 0.0:
			t.aim_t += dt
			warn.visible = true
			warn.material_override = _warn_mat if t.side == "enemy" else _ally_warn_mat()
			var wn := _ground_normal(t.lock)
			warn.global_position = t.lock + wn * 0.1
			warn.quaternion = Quaternion(Vector3.UP, wn)
			var u: float = clampf(t.aim_t / TURRET_AIM, 0.0, 1.0)
			warn.scale = Vector3.ONE * lerpf(1.6, 1.0, u)   # 紅圈從大縮到砲彈的爆炸範圍
			if t.aim_t >= TURRET_AIM:
				_fire_shell(k, t.lock)
				t.aim_t = -1.0
				t.recoil = TURRET_RECOIL
				t.cd = TURRET_RELOAD if t.side == "enemy" else TURRET_RELOAD * 0.6
				warn.visible = false
		else:
			warn.visible = false
			t.cd -= dt
			if t.cd <= 0.0 and tgt != null and facing:
				t.aim_t = 0.0
				t.lock = tgt
				_log("炮塔%s瞄準%s" % [_tower_name(k), "家豪" if t.side == "enemy" else "農夫"])

func _tower_name(k: int) -> String:
	return "ABCDEFG"[k] if k < 7 else str(k + 1)

func _fire_shell(k: int, to: Vector3) -> void:
	var t: Dictionary = towers[k]
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.22
	sm.height = 0.44
	mi.mesh = sm
	mi.material_override = _toon_mat(Color(0.15, 0.15, 0.17) if t.side == "enemy" else Color(1.0, 0.55, 0.1))
	mi.scale = Vector3.ONE * (1.0 if t.side == "enemy" else 1.5)
	_fx_root.add_child(mi)
	var from := _gun_muzzle(t)
	mi.global_position = from
	shells.append({"from": from, "to": to, "t": 0.0, "node": mi, "side": t.side})
	_puff(from, Color(0.9, 0.9, 0.88, 0.6), 4, 0.35)
	_log("炮塔%s開砲" % _tower_name(k))

var _toon_cache := {}
func _toon_mat(c: Color) -> ShaderMaterial:
	if _toon_cache.has(c):
		return _toon_cache[c]
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/toon_color.gdshader")
	m.set_shader_parameter("albedo", c)
	_toon_cache[c] = m
	return m

func _tick_shells(dt: float) -> void:
	for i in range(shells.size() - 1, -1, -1):
		var sh: Dictionary = shells[i]
		sh.t += dt
		var k := clampf(sh.t / SHELL_TIME, 0.0, 1.0)
		(sh.node as Node3D).global_position = (sh.from as Vector3).lerp(sh.to, k) + Vector3.UP * SHELL_PEAK * 4.0 * k * (1.0 - k)
		if k >= 1.0:
			(sh.node as Node3D).queue_free()
			shells.remove_at(i)
			_explode_shell(sh.to, sh.side)

func _explode_shell(p: Vector3, side: String) -> void:
	_puff(p, Color(0.35, 0.3, 0.28, 0.6), 7, 0.55)
	_noise_at(p)
	# 農夫被砸到（敵方炮塔也會誤傷自己人）
	for f in farmers:
		if f.alive() and not f.is_boss and f.air < 1.0 and _flat_dist(f.pos, p) < SHELL_BLAST:
			f.hp = maxf(f.hp - SHELL_DMG_FARMER, 0.0)
			var away: Vector3 = f.pos - p
			away.y = 0.0
			f.kb_vel = (away.normalized() if away.length() > 0.01 else Vector3.BACK) * 3.5
			_aggro(f)
			_anim(f, "Death")
			f.set_state("dead" if f.hp <= 0.0 else "down")
			_log("砲彈炸到%s（剩 %d）" % [f.name, ceili(f.hp)])
	if side != "enemy":
		return
	var b := bird
	if b.alive() and b.air < 1.5 and not b.state in ["launch", "fly"] and _flat_dist(b.pos, p) < SHELL_BLAST:
		b.hp = maxf(b.hp - SHELL_DMG_BIRD, 0.0)
		hit_spots.append(b.pos)
		_log("砲彈炸到家豪（剩 %d）" % ceili(b.hp))
		_toast("轟！", 0.8)
		if b.hp <= 0.0:
			b.set_state("dead")
			return
		b.air = 0.0
		var away := b.pos - p
		away.y = 0.0
		away = away.normalized() if away.length() > 0.01 else Vector3.BACK
		_start_fly(b.pos + away * 4.0, FLY_TIME, FLY_PEAK, "land")

## 飼料撒在哪一座炮塔的梯子腳下（還站著、還沒被佔領的）
func _ladder_at(p: Vector3) -> int:
	for k in towers.size():
		var t: Dictionary = towers[k]
		if t.ladder != null and t.state == "stand" and t.side == "enemy":
			var l: Vector2 = t.ladder
			if Vector2(p.x - l.x, p.z - l.y).length() < LADDER_LURE:
				return k
	return -1

func _start_climb(k: int) -> void:
	climb_k = k
	bird.set_state("climb")
	bird.kb_vel = Vector3.ZERO
	_log("家豪吃完飼料，順著梯子爬上炮塔%s" % _tower_name(k))
	_toast("家豪爬上炮塔了！", 1.6)

func _tick_climb(_dt: float) -> void:
	var b := bird
	var t: Dictionary = towers[climb_k]
	if t.state != "stand":
		# 塔倒了：跟著摔下來
		climb_k = -1
		b.air = 0.0
		b.set_state("land")
		_log("炮塔倒了，家豪摔了下來")
		return
	var holder := t.node as Node3D
	var l: Vector2 = t.ladder
	var tp: Vector2 = t.pos
	var out := (l - tp).normalized()
	var foot := tp + out * ((l - tp).length() - 0.35)
	var stand := tp + out * TOP_STAND          # 塔頂上的站位（矮牆以內）
	var top_abs: float = holder.global_position.y + float(t.top_y)
	if b.t < CLIMB_TIME:
		# 第一段：順著梯子往上爬
		var k := b.t / CLIMB_TIME
		var gy: float = world.height_at(foot.x, foot.y)
		b.pos = Vector3(foot.x, gy, foot.y)
		b.air = maxf(top_abs - gy, 0.0) * k
		b.yaw = atan2(tp.x - foot.x, tp.y - foot.y)   # 面向塔
		return
	# 第二段：翻過矮牆，踏上塔頂
	var s := clampf((b.t - CLIMB_TIME) / TOP_STEP, 0.0, 1.0)
	var p := foot.lerp(stand, s)
	var gy2: float = world.height_at(p.x, p.y)
	b.pos = Vector3(p.x, gy2, p.y)
	b.air = maxf(top_abs - gy2, 0.0) + 0.9 * 4.0 * s * (1.0 - s)
	if s >= 1.0 and t.side == "enemy":
		_capture_tower(climb_k)
	# 第三段：在塔頂站一下，再跳回地面
	if b.t >= CLIMB_TIME + TOP_STEP + TOP_HOLD:
		_jump_off_tower()

func _capture_tower(k: int) -> void:
	var b := bird
	var t: Dictionary = towers[k]
	t.side = "ally"
	t.aim_t = -1.0
	t.cd = 0.8
	(t.warn as Node3D).visible = false
	if t.gunner:
		var g := t.gunner as Node3D
		var away := g.global_position - (b.pos + Vector3(0, b.air, 0))
		away.y = 0.0
		away = away.normalized() if away.length() > 0.01 else Vector3.FORWARD
		b.yaw = atan2(away.x, away.z)   # 轉向砲手，一腳踢出去
		_fx_timed.append({"node": g, "t": 0.0, "life": 1.6, "kind": "gunner", "vel": away * 4.0 + Vector3.UP * 5.0})
	_log("家豪把砲手踢下去，佔領了炮塔%s！" % _tower_name(k))
	_toast("佔領炮塔%s！" % _tower_name(k), 1.8)

## 從塔頂跳回地面（梯子前方 2.5 公尺）
func _jump_off_tower() -> void:
	var b := bird
	var t: Dictionary = towers[climb_k]
	climb_k = -1
	var l: Vector2 = t.ladder
	var tp: Vector2 = t.pos
	var out := l + (l - tp).normalized() * 2.5
	var top := b.pos + Vector3(0, b.air, 0)
	var land := _ground(world.clamp_play(Vector3(out.x, 0, out.y)))
	launch_from = top
	launch_to = land
	launch_dur = 0.9
	launch_peak = 0.8
	launch_hurt = false
	b.air = 0.0
	b.set_state("launch")

## 一團煙／塵土
func _puff(p: Vector3, col: Color, n: int, r: float) -> void:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = col
	for k in n:
		var a := k * TAU / n
		var mi := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = r
		sm.height = r * 2.0
		mi.mesh = sm
		mi.material_override = m
		_fx_root.add_child(mi)
		mi.global_position = p + Vector3(cos(a) * r * 1.2, 0.3, sin(a) * r * 1.2)
		_fx_timed.append({"node": mi, "t": 0.0, "life": 0.8, "kind": "dust"})

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
	# 先攻規則：被農夫踢中只是小跳一下、馬上回頭反擊；只有重擊（巨石之類）才會飛開撤退
	var first_half := false
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
	# 挨打的地方冒一小團亮黃色，看得出這一跳是「被打到」，不是自己想跳
	_puff(b.pos + Vector3(0, 0.9, 0), Color(1.0, 0.92, 0.45, 0.85), 5, 0.16)

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
		_defuse(f)
		return
	f.heavy = false
	f.set_state("startled")
	f.yaw = _yaw_to(f.pos, bird.pos)
	_anim(f, "HitRecieve", 0.8)

## 家豪搶先啄倒自爆農夫：引信被啄掉，不會爆
func _defuse(f: Fighter) -> void:
	if f.kind != "bomber" or f.exploded:
		return
	f.dud = true
	if f.bomb:
		var sp := f.bomb.get_node_or_null("Spark")
		if sp:
			sp.visible = false
	_log("家豪啄掉了%s的引信" % f.name)
	_toast("引信啄掉了！", 1.2)

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
		_defuse(f)
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
	# 要走進障礙物（建築、樹、停下來的巨石）時：推回邊緣，再往「繞過去」的方向滑一點。
	# 只推回邊緣的話，正面撞上去會一直卡在原地抖（推出去、又走進來）
	var p := Vector2(to.x, to.z)
	var f2 := Vector2(from.x, from.z)
	var mv := p - f2
	for o in world.obstacles:
		var c: Vector2 = o[0]
		var r: float = o[1] + pad
		var d := p - c
		if d.length() < r:
			var n := d.normalized() if d.length() > 0.001 else (f2 - c).normalized()
			var t := Vector2(-n.y, n.x)
			# 往比較順的那一邊繞：跟原本前進方向同側；幾乎正面撞上時固定往同一側（用相對位置決定，不會左右搖擺）
			var side := signf(t.dot(mv))
			if absf(t.dot(mv.normalized())) < 0.2:
				side = 1.0 if (f2 - c).cross(mv) >= 0.0 else -1.0
			if side == 0.0:
				side = 1.0
			p = c + n * r + t * side * maxf(mv.length(), 0.02)
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
	var step := minf(spd * dt, d.length())
	var dir := _steer_dir(f, d.normalized(), step, d.length())
	# 身體轉向有速度上限：就算路線突然改變，人（和他腳下的偵測扇形）也是轉過去，不會一步之內甩到另一邊
	f.yaw = _turn_toward(f.yaw, atan2(dir.x, dir.z), TURN_SPEED * dt)
	var nxt := f.pos + dir * step
	nxt = world.clamp_play(_avoid(f.pos, nxt, 0.5))
	nxt = _separate(f, nxt)
	if _fence_crossing(f.pos, nxt) == null:
		f.pos = _ground(nxt)

const TURN_SPEED := 7.0        # 農夫走路時轉身的速度上限（弧度／秒；轉半圈約 0.45 秒）
const STEER_LOOK := 1.0        # 走路時往前看多遠有沒有障礙
const STEER_HOLD := 0.35       # 決定繞開之後，至少照那個方向走這麼久（避免一步繞、一步不繞地來回抖）

func _turn_toward(from: float, to: float, max_step: float) -> float:
	var diff := angle_difference(from, to)
	return to if absf(diff) <= max_step else from + signf(diff) * max_step

## 前方有障礙就把方向轉開：試各個偏角，挑最接近目標方向又不撞的。
## dist = 離目標還有多遠。目標就在眼前（比往前看的距離還近）就直接走過去，不要去看目標後面的東西，
## 否則目標點剛好在障礙物旁邊時，會永遠走不到、在原地左右甩頭。
func _steer_dir(f: Fighter, dir: Vector3, step: float, dist := INF) -> Vector3:
	if dist <= step + STEER_LOOK:
		f.steer_t = -1.0
		return dir
	# 剛決定要繞：這段時間內維持同一個偏角，不重新判斷
	if f.steer_t >= 0.0 and time >= f.steer_t and time - f.steer_t < STEER_HOLD:
		var held := dir.rotated(Vector3.UP, f.steer_angle)
		if not _blocked_at(f.pos + held * (step + STEER_LOOK)):
			return held
	# 往前看的距離不要超過目標本身：目標就在障礙物旁邊（例如寶箱旁的飼料）時，看過頭會一直被轉開、在原地打轉
	if not _blocked_at(f.pos + dir * minf(step + STEER_LOOK, dist)):
		f.steer_t = -1.0
		return dir
	for a in [0.4, 0.8, 1.2, 1.6, 2.0, 2.5]:
		for s in [f.steer_side, -f.steer_side]:
			var cand := dir.rotated(Vector3.UP, a * s)
			if not _blocked_at(f.pos + cand * (step + STEER_LOOK)):
				f.steer_side = s
				f.steer_angle = a * s
				f.steer_t = time
				return cand
	return dir

func _blocked_at(p: Vector3) -> bool:
	for o in world.obstacles:
		var c: Vector2 = o[0]
		if Vector2(p.x, p.z).distance_to(c) < float(o[1]) + 0.6:
			return true
	return false

## 農夫之間不能重疊：太近就把自己往外推開
func _separate(f: Fighter, nxt: Vector3, min_d := 1.0) -> Vector3:
	var out := nxt
	for o in farmers + ([bird] if f != bird else []):
		if o == f or not o.alive() or (o == bird and bird.air > 0.5):
			continue
		var d := Vector3(out.x - o.pos.x, 0, out.z - o.pos.z)
		if d.length() < min_d:
			var push := d.normalized() if d.length() > 0.001 else Vector3(cos(float(([bird] + farmers).find(f)) * 2.4), 0, sin(float(([bird] + farmers).find(f)) * 2.4))
			out = Vector3(o.pos.x, out.y, o.pos.z) + push * min_d
	return out

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
		if f.bomb and f.bomb.visible:
			var sp := f.bomb.get_node_or_null("Spark") as Node3D
			if sp and not f.dud:
				var fast: bool = f.state == "fuse"
				sp.scale = Vector3.ONE * ((1.6 + sin(time * 60.0) * 0.6) if fast else (1.0 + sin(time * 18.0) * 0.25))
			var barrel := f.bomb.get_node_or_null("Barrel") as Node3D
			if barrel:
				barrel.scale = Vector3.ONE * ((1.0 + absf(sin(time * 25.0)) * 0.15) if f.state == "fuse" else 1.0)
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
		"cannon":
			# 頭塞在砲管裡，屁股翹在外面左右扭，翅膀亂拍
			rx = 1.25
			rz = sin(b.t * 14.0) * 0.18
			flap = 0.5 + 0.6 * absf(sin(b.t * 22.0))
		"launch":
			# 被射出去：頭朝著拋物線的切線方向（上升抬頭、落下低頭），翅膀張開；自己跳下來就維持站姿
			if launch_hurt:
				var lk := clampf(b.t / maxf(launch_dur, 0.01), 0.0, 1.0)
				var lh := Vector2(launch_to.x - launch_from.x, launch_to.z - launch_from.z).length()
				var lvy := (launch_to.y - launch_from.y) + launch_peak * 4.0 * (1.0 - 2.0 * lk)
				rx = PI * 0.5 - atan2(lvy, maxf(lh, 0.01))
			else:
				rx = -0.3
			flap = 1.1
		"climb":
			if b.t < CLIMB_TIME:
				# 抱著梯子一格一格往上爬，身體左右晃
				rx = -0.35
				rz = sin(b.t * 10.0) * 0.16
				lift = absf(sin(b.t * 10.0)) * 0.05
				flap = 0.3 + 0.3 * absf(sin(b.t * 10.0))
			elif b.t < CLIMB_TIME + TOP_STEP:
				# 翻過矮牆
				rx = 0.5
				flap = 1.0
			else:
				# 站在塔頂得意地跳兩下
				lift = absf(sin(b.t * 9.0)) * 0.2
				rx = -0.25
				flap = 0.6
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

	# 技能欄：畫面下方一整條相連的快捷欄（方塊遊戲風格）
	_hotbar = Hotbar.new()
	UIStyle.apply_theme(_hotbar)
	_hotbar.skills = SKILLS
	_hotbar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hb := _hotbar.bar_size()
	_hotbar.custom_minimum_size = hb
	# 統一介面：神蹟欄放左下（跟冰雪大關一樣），家豪的愛心在它上方
	_hotbar.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_hotbar.offset_left = 28
	_hotbar.offset_right = 28 + hb.x
	_hotbar.offset_top = -hb.y - 30
	_hotbar.offset_bottom = -30
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
	# 教學彈窗改用共用版（scripts/ui/tutorial_popup.gd，從這裡的版本搬過去的），示範動畫還是讀要塞的影格表
	_tut = preload("res://scripts/ui/tutorial_popup.gd").new()
	_tut.clip_dir = "res://levels/fort/assets/tutorial"
	_tut.kicker_text = "新手教學"
	add_child(_tut)
	_tut.set_pages(TUT_PAGES)
	_tut.closed.connect(_on_tut_closed)

	# 右上角敵人欄（米色小紙片）：老闆一張（頭像＋血條，他是過關目標）；
	# 農夫合成一張，只排一排小頭像，被打倒就打紅叉——用陷阱一次就倒，血量沒什麼好看的
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	col.alignment = BoxContainer.ALIGNMENT_BEGIN
	col.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	col.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	col.offset_right = -20
	col.offset_top = 16
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(col)
	_enemy_col = col
	for f in farmers.filter(func(f): return f.is_boss):
		var card := PanelContainer.new()
		UIStyle.slip(card, Vector2(12, 8))
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.size_flags_horizontal = Control.SIZE_SHRINK_END
		col.add_child(card)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(row)
		var face := EnemyFace.new()
		face.boss = true
		face.custom_minimum_size = Vector2(52, 52)
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(face)
		var info := VBoxContainer.new()
		info.alignment = BoxContainer.ALIGNMENT_CENTER
		info.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(info)
		var nm := Label.new()
		nm.text = f.name + "（持槍）"
		nm.label_settings = UIStyle.ls(17, UIStyle.INK)
		info.add_child(nm)
		var bar := PaperBar.new()
		bar.fill = Color("e2483d")
		bar.custom_minimum_size = Vector2(170, 16)
		bar.visible = false   # 統一介面：不顯示敵人血量
		info.add_child(bar)
		_enemy_rows.append({"fighter": f, "face": face, "bar": bar})
	var crew: Array = farmers.filter(func(f): return not f.is_boss)
	if not crew.is_empty():
		var card := PanelContainer.new()
		UIStyle.slip(card, Vector2(12, 8))
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.size_flags_horizontal = Control.SIZE_SHRINK_END
		col.add_child(card)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(row)
		_crew_label = Label.new()
		_crew_label.label_settings = UIStyle.ls(17, UIStyle.INK)
		_crew_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(_crew_label)
		for f in crew:
			var face := EnemyFace.new()
			face.custom_minimum_size = Vector2(40, 40)
			face.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(face)
			_enemy_rows.append({"fighter": f, "face": face, "bar": null})
	if towers_total() > 0:
		var tcard := PanelContainer.new()
		UIStyle.slip(tcard, Vector2(12, 8))
		tcard.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tcard.size_flags_horizontal = Control.SIZE_SHRINK_END
		col.add_child(tcard)
		_tower_label = Label.new()
		_tower_label.label_settings = UIStyle.ls(17, UIStyle.INK)
		tcard.add_child(_tower_label)
	# 左下角：家豪的頭像＋血條（頭上不再疊血條）
	var me := PanelContainer.new()
	UIStyle.slip(me, Vector2(12, 8))
	me.mouse_filter = Control.MOUSE_FILTER_IGNORE
	me.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	me.offset_left = 28 + hb.x + 18   # 神蹟欄右邊同一排（上方留給浮出的神蹟名稱）
	me.offset_bottom = -30 - (hb.y - 56.0) * 0.5
	me.grow_vertical = Control.GROW_DIRECTION_BEGIN
	layer.add_child(me)
	var mrow := HBoxContainer.new()
	mrow.add_theme_constant_override("separation", 10)
	mrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	me.add_child(mrow)
	var pic := Portrait.new()
	pic.tex = _load_tex("res://assets/ui/jiahao_portrait.png")
	pic.custom_minimum_size = Vector2(40, 40)
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mrow.add_child(pic)
	var minfo := VBoxContainer.new()
	minfo.alignment = BoxContainer.ALIGNMENT_CENTER
	minfo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mrow.add_child(minfo)
	var mn := Label.new()
	mn.text = "家豪"
	mn.label_settings = UIStyle.ls(17, UIStyle.INK)
	minfo.add_child(mn)
	_bird_bar = PaperBar.new()
	_bird_bar.fill = Color("58b85a")
	_bird_bar.custom_minimum_size = Vector2(170, 16)
	_bird_bar.visible = false
	minfo.add_child(_bird_bar)
	mn.visible = false
	_hearts = HeartBar.new()
	_hearts.max_hp = bird.max_hp
	_hearts.per_heart = HEART_HP
	_hearts.hp = bird.max_hp
	_hearts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	minfo.add_child(_hearts)
	# 家豪跑出畫面時，畫面邊緣的箭頭指著他
	_edge_arrow = EdgeArrow.new()
	_edge_arrow.set_anchors_preset(Control.PRESET_FULL_RECT)
	_edge_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_edge_arrow)

	# 上方中間：現在的階段（米色小紙片＋鍵帽），取代原本一整排的操作文字
	var phase_box := PanelContainer.new()
	UIStyle.slip(phase_box, Vector2(18, 8))
	phase_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	phase_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	phase_box.offset_top = 18
	phase_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	layer.add_child(phase_box)
	var prow := HBoxContainer.new()
	prow.add_theme_constant_override("separation", 16)
	prow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	phase_box.add_child(prow)
	_phase_label = Label.new()
	_phase_label.label_settings = UIStyle.ls(22, UIStyle.INK)
	_phase_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	prow.add_child(_phase_label)
	_phase_start_key = UIStyle.key_hint("Enter", "開打", 16)
	prow.add_child(_phase_start_key)
	_phase_retry_key = UIStyle.key_hint("R", "重試", 16)
	prow.add_child(_phase_retry_key)
	# 右下角：常用的三顆鍵（其他操作都在 H 的說明裡）
	var corner := PanelContainer.new()
	UIStyle.slip(corner, Vector2(12, 6))
	corner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	corner.modulate.a = 0.85
	corner.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	corner.offset_right = -20
	corner.offset_bottom = -22
	corner.grow_vertical = Control.GROW_DIRECTION_BEGIN
	corner.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	layer.add_child(corner)
	var crow := HBoxContainer.new()
	crow.add_theme_constant_override("separation", 14)
	crow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	corner.add_child(crow)
	crow.add_child(UIStyle.key_hint("H", "操作說明", 13))
	_start_btn = _make_start_button()
	layer.add_child(_start_btn)
	crow.add_child(UIStyle.key_hint("R", "重試", 13))
	crow.add_child(UIStyle.key_hint("M", "地圖", 13))
	# 第一次玩：教學關掉後，在神蹟欄上方提示一次「先試著放一個」，放成功就收起來
	_first_hint = PanelContainer.new()
	UIStyle.slip(_first_hint, Vector2(16, 8))
	_first_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_first_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_first_hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_first_hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_first_hint.offset_bottom = -_hotbar.bar_size().y - 22 - 62
	_first_hint.visible = false
	layer.add_child(_first_hint)
	var fh := HBoxContainer.new()
	fh.add_theme_constant_override("separation", 8)
	fh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_first_hint.add_child(fh)
	fh.add_child(UIStyle.key_hint("1", "選飼料，對準地面", 16))
	fh.add_child(UIStyle.mouse_hint("left", "撒一把試試看", 16))

	_build_notice(layer)

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
	UIStyle.pill(_toast_label)   # 圓角膠囊
	_toast_label.visible = false
	layer.add_child(_toast_label)

	_summary_panel = PanelContainer.new()
	UIStyle.paper(_summary_panel, 0.0)
	_summary_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_summary_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_summary_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var ss := UIStyle.ls(22, UIStyle.INK)
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
	var band := PanelContainer.new()
	UIStyle.paper(band, 0.0)   # 跟其他畫面同一張筆記紙
	band.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	band.offset_left = 160
	band.offset_right = -160
	band.offset_top = -190
	band.offset_bottom = -30
	_defeat_layer.add_child(band)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 6)
	band.add_child(box)
	var big := UIStyle.ls(34, UIStyle.accent())
	_defeat_label = Label.new()
	_defeat_label.label_settings = big
	_defeat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_defeat_label)
	var small := UIStyle.ls(19, Color(UIStyle.INK, 0.8))
	small.line_spacing = 4
	_defeat_detail = Label.new()
	_defeat_detail.label_settings = small
	_defeat_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_defeat_detail)
	var keys := HBoxContainer.new()
	keys.alignment = BoxContainer.ALIGNMENT_CENTER
	keys.add_theme_constant_override("separation", 28)
	box.add_child(keys)
	keys.add_child(UIStyle.key_hint("R", "重試", 16))
	keys.add_child(UIStyle.key_hint("M", "回到地圖", 16))

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
	_defeat_detail.text = "第 %d 次嘗試　｜　撐了 %.1f 秒　｜　還剩 %d 個農夫\n%s" % [attempts.size(), time, left, tip]
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
	_hotbar.prep_counts = prep_charges.duplicate()
	_hotbar.prepping = phase == Phase.PREPARE
	_hotbar.cooldowns = cooldowns.duplicate()
	_hotbar.selected = selected
	_hotbar.queue_redraw()

## 血條的淺色那段（扣血後慢慢追上）；頭上已經不畫血條，數值給左下角家豪卡和右上角老闆卡用
func _update_bars(dt: float) -> void:
	for f in [bird] + farmers:
		var r: float = f.ratio()
		f.chip = maxf(r, f.chip - dt * 0.6) if f.chip > r else r

func _update_phase_label() -> void:
	match phase:
		Phase.PREPARE:
			_phase_label.text = "準備中・先佈置神蹟"
		Phase.RUNNING:
			_phase_label.text = "戰鬥中　%.1f 秒" % time
		Phase.ENDED:
			_phase_label.text = "勝利！" if outcome == "win" else "落敗…"
	_phase_start_key.visible = phase == Phase.PREPARE
	_phase_retry_key.visible = phase == Phase.ENDED

## 右下角「開始 ▶ [Enter]」（跟其他大關同一個樣子；點它也能開打）
func _make_start_button() -> Control:
	var p := PanelContainer.new()
	var sb := UIStyle._box(UIStyle.GO, UIStyle.GO_EDGE, 22, 3)
	sb.content_margin_left = 20
	sb.content_margin_right = 14
	sb.content_margin_top = 6
	sb.content_margin_bottom = 8
	p.add_theme_stylebox_override("panel", sb)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(h)
	var t := Label.new()
	t.text = "開始 ▶"
	t.label_settings = UIStyle.ls(30, Color(1, 1, 1))
	h.add_child(t)
	h.add_child(UIStyle.keycap("Enter", 18))
	p.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	p.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	p.grow_vertical = Control.GROW_DIRECTION_BEGIN
	p.offset_right = -36
	p.offset_bottom = -76
	p.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT and phase == Phase.PREPARE:
			start())
	return p

func _build_notice(layer: CanvasLayer) -> void:
	_notice = PanelContainer.new()
	_notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_notice.add_theme_stylebox_override("panel", UIStyle.slip_box(Vector2(16, 10)))   # 米色小紙片，硬陰影
	_notice.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_notice.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_notice.custom_minimum_size = Vector2(330, 0)
	# 放在右上角敵人欄的下面
	_notice.offset_top = 200.0   # 實際位置在 notify_phase 時依敵人欄的高度再算
	_notice.offset_right = -20
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_notice.add_child(row)
	var icon := TextureRect.new()
	icon.texture = load("res://assets/ui/jiahao_portrait.png")
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	icon.custom_minimum_size = Vector2(44, 44)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	var texts := VBoxContainer.new()
	texts.add_theme_constant_override("separation", 2)
	row.add_child(texts)
	_notice_title = Label.new()
	_notice_title.label_settings = UIStyle.ls(19, UIStyle.accent())
	texts.add_child(_notice_title)
	_notice_body = Label.new()
	_notice_body.label_settings = UIStyle.ls(15, Color(UIStyle.INK, 0.8))
	texts.add_child(_notice_body)
	_notice.visible = false
	layer.add_child(_notice)

## 換階段時：右上角跳一張通知，技能欄閃一下，提示神蹟次數可能變了
func notify_phase(title: String, body: String) -> void:
	if _notice == null:
		return
	_notice_title.text = title
	_notice_body.text = body
	_notice_t = 0.0
	if _enemy_col:
		_notice.offset_top = 16.0 + _enemy_col.get_combined_minimum_size().y + 14.0
	_notice.visible = true
	_notice.modulate.a = 0.0
	if _hotbar:
		_hotbar.pulse()

func _tick_notice(dt: float) -> void:
	if _notice_t < 0.0:
		return
	_notice_t += dt
	var t := _notice_t
	var slide_in := clampf(t / 0.28, 0.0, 1.0)
	var slide_out := clampf((t - (NOTICE_TIME - 0.35)) / 0.35, 0.0, 1.0)
	var ease_in := 1.0 - pow(1.0 - slide_in, 3.0)
	var off := (1.0 - ease_in) * 360.0 + slide_out * slide_out * 360.0
	_notice.offset_right = -20.0 + off
	_notice.offset_left = _notice.offset_right - _notice.size.x
	_notice.modulate.a = ease_in * (1.0 - slide_out)
	if t >= NOTICE_TIME:
		_notice_t = -1.0
		_notice.visible = false

func _toast(text: String, dur: float) -> void:
	_toast_label.text = text
	_toast_label.visible = text != ""
	# 膠囊照文字大小重新置中（不然會沿用上一次的高度）
	var sz := _toast_label.get_combined_minimum_size()
	_toast_label.offset_left = -sz.x * 0.5
	_toast_label.offset_right = sz.x * 0.5
	_toast_label.offset_top = -140.0 - sz.y * 0.5
	_toast_label.offset_bottom = -140.0 + sz.y * 0.5
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

## 第一次玩才自動跳出（記在存檔裡）；之後按 H 隨時可以再看
func start_tutorial() -> void:
	if _tut_seen or FortProgress.tutorial_seen():
		return
	_tut_seen = true
	_set_tut_step(0)

## i >= 0：打開教學彈窗到第 i 頁；-1：關掉
func _set_tut_step(i: int) -> void:
	if _tut == null:
		return
	if i < 0:
		_tut.close()
	elif not _tut.is_open():
		_tut.open(i)

func _on_tut_closed() -> void:
	if _tut_seen and casts.is_empty() and phase == Phase.PREPARE:
		_show_first_hint(true)   # 第一次自動跳出的教學看完 → 提示先放一個試試
	if not _auto_run():
		FortProgress.mark_tutorial_seen()
	if player.has_method("_set_looking"):
		player._set_looking(true)
	if _hotbar:
		_hotbar.pulse()   # 提醒一下：神蹟在下面這條

## 家豪不在畫面裡（在背後、或跑到畫面外）時，畫面邊緣出現一個箭頭指著他
func _update_edge_arrow() -> void:
	if _edge_arrow == null or not SHOW_EDGE_ARROW:
		return
	var head: Vector3 = bird.pos + Vector3(0, bird.air + 1.0, 0)
	var vp := get_viewport().get_visible_rect().size
	var behind := camera.is_position_behind(head)
	var sp := camera.unproject_position(head)
	# 箭頭能出現的框：避開上方狀態列和下方的神蹟欄、家豪卡
	var bottom := 330.0 if (_dialog and _dialog.showing()) else 190.0   # 對話框出現時再往上讓
	var box := Rect2(Vector2(80, 100), vp - Vector2(160, 100 + bottom))
	var inside := not behind and box.has_point(sp)
	var on := not inside and bird.alive() and phase != Phase.ENDED and not defeat_shown
	if not on:
		if _edge_arrow.on:
			_edge_arrow.on = false
			_edge_arrow.queue_redraw()
		return
	var c := box.get_center()
	var d := sp - c
	if behind:
		d = -d
	if d.length() < 1.0:
		d = Vector2(0, 1)
	# 從框的中心沿著方向射到框邊
	var half := box.size * 0.5
	var t := minf(half.x / maxf(absf(d.x), 0.001), half.y / maxf(absf(d.y), 0.001))
	_edge_arrow.on = true
	_edge_arrow.pos = c + d * t
	_edge_arrow.ang = d.angle()
	_edge_arrow.queue_redraw()

func _show_first_hint(on: bool) -> void:
	if _first_hint:
		_first_hint.visible = on

# ------------------------------------------------------------------ 墨色描邊

const INK_SHADER := preload("res://levels/fort/shaders/ink_outline.gdshader")
var _ink_mat: ShaderMaterial

## 可以互動的東西（角色、炮塔/水塔、大砲、巨石）加上跟介面一樣的墨色描邊，
## 跟背景的樹、山、草地分開，畫面也比較像同一本繪本
func _ink_interactables() -> void:
	for f in [bird] + farmers:
		if f.node:
			_ink(f.node)
	for t in towers:
		if t.node:
			_ink(t.node)
	for c in world.get("cannon_nodes") if world.get("cannon_nodes") != null else []:
		_ink(c)
	for c in world.get("chests") if world.get("chests") != null else []:
		if c.node:
			_ink(c.node)
	var cn = world.get("cannon_node")
	if cn is Node3D:
		_ink(cn)

func _ink(root: Node, width := 2.6) -> void:
	if _ink_mat == null:
		_ink_mat = ShaderMaterial.new()
		_ink_mat.shader = INK_SHADER
	var mat := _ink_mat
	if absf(width - 2.6) > 0.01:
		mat = _ink_mat.duplicate()
		mat.set_shader_parameter("width_px", width)
	var stack: Array = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D and _ink_ok(n):
			(n as MeshInstance3D).material_overlay = mat
		for c in n.get_children():
			stack.append(c)

## 半透明的東西（偵測扇形、預覽圈、特效）不描邊
func _ink_ok(mi: MeshInstance3D) -> bool:
	if mi.mesh == null or mi.material_overlay != null:
		return false
	var m := mi.material_override
	if m == null and mi.mesh.get_surface_count() > 0:
		m = mi.get_active_material(0)
	if m is BaseMaterial3D and (m as BaseMaterial3D).transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
		return false
	return true

# ------------------------------------------------------------------ 貼地

## 地面的法線（用高度差算），坡越陡 y 越小
func _ground_normal(p: Vector3) -> Vector3:
	var e := 0.3
	var hx: float = world.height_at(p.x + e, p.z) - world.height_at(p.x - e, p.z)
	var hz: float = world.height_at(p.x, p.z + e) - world.height_at(p.x, p.z - e)
	return Vector3(-hx, 2.0 * e, -hz).normalized()

var _rock_verts: Dictionary = {}   # mesh → 頂點（算巨石最低點用）

## 巨石停下來：往下貼到地面（最低的頂點剛好碰地、再陷一點點），
## 變成一塊路障（家豪和農夫都會繞開，不能穿過去），站太近的人被輕輕推開
func _rest_rock(r: Dictionary) -> void:
	r.rested = true
	var node: MeshInstance3D = r.node
	if not is_instance_valid(node):
		return
	_settle_rock(node)
	var c := Vector2(node.global_position.x, node.global_position.z)
	var rad := ROCK_RADIUS * 0.9
	r.obs = [c, rad]
	world.obstacles.append(r.obs)
	for f in [bird] + farmers:
		var d := Vector2(f.pos.x, f.pos.z) - c
		var need := rad + 0.75
		if f.alive() and d.length() < need:
			var dir := d.normalized() if d.length() > 0.01 else Vector2.RIGHT
			var np := c + dir * need
			f.pos = _ground(Vector3(np.x, 0, np.y))

## 巨石往下（或往上）移到最低的頂點剛好碰地、再陷一點點
func _settle_rock(node: MeshInstance3D) -> void:
	if not _rock_verts.has(node.mesh):
		_rock_verts[node.mesh] = node.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var xf := node.global_transform
	var gap := INF
	for v in _rock_verts[node.mesh]:
		var w: Vector3 = xf * v
		gap = minf(gap, w.y - world.height_at(w.x, w.z))
	if gap < INF:
		node.global_position.y -= gap + 0.06

# ------------------------------------------------------------------ 鏡頭前的建築變半透明

## 幽靈飄到城牆、城門、塔、房子旁邊時，貼在鏡頭前面的那塊變半透明，才看得到後面
const FADE_NEAR := 1.6          # 這麼近就幾乎透明
const FADE_FAR := 3.2           # 這麼遠以外完全不透明
const FADE_MAX := 0.75
var _fade_list: Array = []      # GeometryInstance3D（模型、3D 字）
var _fade_ready := false

func _collect_fade() -> void:
	_fade_ready = true
	var roots: Array = []
	for nm in ["FortWalls", "FortGate", "CannonTowers", "CommanderPlatform", "Props", "Cannon", "Buildings", "FarmFence"]:
		var n := world.find_child(nm, true, false)
		if n:
			roots.append(n)
	for t in towers:
		if t.node and not roots.has(t.node):
			roots.append(t.node)
	var stack := roots.duplicate()
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is GeometryInstance3D:   # 模型和招牌上的 3D 字都算
			_fade_list.append(n)
		for ch in n.get_children():
			stack.append(ch)

func _fade_near_camera(dt: float) -> void:
	if not _fade_ready:
		_collect_fade()
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var cp := cam.global_position
	var k := clampf(dt * 8.0, 0.0, 1.0)
	for m in _fade_list:
		if not is_instance_valid(m):
			continue
		var mi := m as GeometryInstance3D
		if not mi.is_visible_in_tree():
			continue
		# 在模型自己的座標裡找離鏡頭最近的點（斜放的牆用世界座標的包圍盒會大很多）
		var xf := mi.global_transform
		var box := mi.get_aabb()
		var lp := xf.affine_inverse() * cp
		var q: Vector3 = xf * lp.clamp(box.position, box.end)
		var d := cp.distance_to(q)
		# 只有貼近鏡頭才變透明；擋在準心前面的不弄透明（瞄準的東西本身才不會跟著淡掉）
		var want := FADE_MAX * (1.0 - clampf((d - FADE_NEAR) / (FADE_FAR - FADE_NEAR), 0.0, 1.0))
		if absf(mi.transparency - want) > 0.005:
			mi.transparency = lerpf(mi.transparency, want, k)

# ------------------------------------------------------------------ 進場鏡頭

## 一進場先播三個鏡頭（入口 → 兩個角度的俯瞰），再回到幽靈原本的位置；
## 鏡頭內容由關卡的 intro_shots() 提供：[{from, to, look_from, look_to, dur, title, body}]
const INTRO_RETURN := 1.1        # 最後一個鏡頭飛回幽靈視角的時間
var _intro_cam: Camera3D
var _intro_shots: Array = []
var _intro_i := -1               # 現在播第幾個鏡頭（-1 = 沒在播；= 鏡頭數 → 正在飛回去）
var _intro_t := 0.0
var _intro_from_xf: Transform3D
var _intro_layer: CanvasLayer
var _intro_title: Label
var _intro_body: Label

func _want_intro() -> bool:
	if not world.has_method("intro_shots"):
		return false
	for a in OS.get_cmdline_user_args():
		if a in ["--autotest", "--nointro"] or a.begins_with("--fortshots=") or a.begins_with("--recordtut="):
			return false
	return not _auto_run()

func _start_intro() -> void:
	_intro_shots = world.intro_shots()
	if _intro_shots.is_empty():
		start_tutorial()
		return
	_intro_cam = Camera3D.new()
	_intro_cam.fov = camera.fov
	_intro_cam.far = camera.far
	add_child(_intro_cam)
	_intro_cam.make_current()
	player.set_physics_process(false)
	player.set_process_unhandled_input(false)
	_hud_layer.visible = false
	if crosshair:
		crosshair.visible = false
	_preview.visible = false
	_build_intro_caption()
	_intro_i = 0
	_intro_t = 0.0
	_show_intro_caption()
	_tick_intro(0.0)

func _build_intro_caption() -> void:
	_intro_layer = CanvasLayer.new()
	_intro_layer.layer = 6
	add_child(_intro_layer)
	var card := PanelContainer.new()
	UIStyle.slip(card, Vector2(22, 12))
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	card.offset_top = 28
	_intro_layer.add_child(card)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(box)
	_intro_title = Label.new()
	_intro_title.label_settings = UIStyle.ls(26, UIStyle.INK)
	_intro_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_intro_title)
	_intro_body = Label.new()
	_intro_body.label_settings = UIStyle.ls(17, UIStyle.INK)
	_intro_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_intro_body)
	var hint := UIStyle.key_hint("Space", "跳過")
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	hint.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hint.offset_right = -24
	hint.offset_bottom = -22
	_intro_layer.add_child(hint)

func _show_intro_caption() -> void:
	if _intro_i < 0 or _intro_i >= _intro_shots.size():
		return
	var sh: Dictionary = _intro_shots[_intro_i]
	_intro_title.text = sh.get("title", "")
	_intro_body.text = sh.get("body", "")
	_intro_body.visible = _intro_body.text != ""

func _tick_intro(dt: float) -> void:
	_intro_t += dt
	if _intro_i < _intro_shots.size():
		var sh: Dictionary = _intro_shots[_intro_i]
		var u := clampf(_intro_t / float(sh.dur), 0.0, 1.0)
		var k := u * u * (3.0 - 2.0 * u)
		var pos: Vector3 = (sh.from as Vector3).lerp(sh.to, k)
		var look: Vector3 = (sh.look_from as Vector3).lerp(sh.look_to, k)
		_intro_cam.global_transform = Transform3D(Basis(), pos).looking_at(look, Vector3.UP)
		if u >= 1.0:
			_intro_i += 1
			_intro_t = 0.0
			_intro_from_xf = _intro_cam.global_transform
			_show_intro_caption()
			if _intro_i >= _intro_shots.size():
				_intro_layer.visible = false
		return
	# 飛回幽靈原本的位置
	var u2 := clampf(_intro_t / INTRO_RETURN, 0.0, 1.0)
	var k2 := u2 * u2 * (3.0 - 2.0 * u2)
	var to := camera.global_transform
	var q := _intro_from_xf.basis.get_rotation_quaternion().slerp(to.basis.get_rotation_quaternion(), k2)
	_intro_cam.global_transform = Transform3D(Basis(q), _intro_from_xf.origin.lerp(to.origin, k2))
	if u2 >= 1.0:
		_end_intro()

## 播完（或按 Space 跳過）：回到幽靈視角，接著開教學
func _end_intro() -> void:
	if _intro_i < 0:
		return
	_intro_i = -1
	camera.make_current()
	if _intro_cam:
		_intro_cam.queue_free()
		_intro_cam = null
	if _intro_layer:
		_intro_layer.queue_free()
		_intro_layer = null
	player.set_physics_process(true)
	player.set_process_unhandled_input(true)
	_hud_layer.visible = true
	if crosshair:
		crosshair.visible = true
	if not _auto_run():
		start_tutorial()

## 自動測試用：直接跳過進場鏡頭
func skip_intro() -> void:
	_end_intro()

# ------------------------------------------------------------------ 暫停選單（共用的 scripts/ui/pause_menu.gd）

var pause_menu: PauseMenu

func _build_pause_menu() -> void:
	pause_menu = PauseMenu.new()
	pause_menu.name = "PauseMenu"
	pause_menu.stage_root = get_parent()
	pause_menu.player = player
	pause_menu.help_rows = func() -> Array: return TUT_PAGES[0].controls
	pause_menu.hotkey = false          # Esc 由 _input 自己判斷：教學彈窗、進場鏡頭開著的時候不搶
	pause_menu.picked.connect(_on_pause_picked)
	add_child(pause_menu)

func _input(event: InputEvent) -> void:
	if pause_menu == null or pause_menu.is_open or _intro_i >= 0 or (_tut and _tut.is_open()):
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		pause_menu.open()
		get_viewport().set_input_as_handled()

func _on_pause_picked(id: String) -> void:
	match id:
		"restart":
			reset()
		"map":
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			get_tree().change_scene_to_file("res://scenes/level_select.tscn")
