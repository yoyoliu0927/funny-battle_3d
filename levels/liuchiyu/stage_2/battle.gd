extends "res://levels/liuchiyu/island_battle.gd"
## 第二小關的戰局：枯樹林。跟第一小關過河那一招一樣，只是這次拿來對付農夫：
##   1. 用「雷」劈在枯樹上，把它劈開（樹幹燒焦、歪一邊）
##   2. 按住「風」對著劈開的樹吹，它會順著風向倒下去，壓到樹底下的人（家豪被壓到也會受傷）
## 倒在地上的樹會擋路：農夫要繞過去，可以拿來把他們和家豪隔開。
## 三個農夫，一打起來另外兩個就會趕過來，家豪正面打不贏；要看準農夫走到哪裡，讓樹倒在他們身上。
## 風也還是可以對著農夫的臉吹，讓他們暫時看不見。
## 場上還有幾灘小水灘：農夫踩進去的時候用雷劈那一灘，他直接被電倒。家豪自己不會踩進水灘。
## 星星在東邊外海的一塊礁石上：把海岸那棵枯樹（BRIDGE_TREE）劈開、剛好朝礁石的方向吹，只要大致往海邊吹，它就會倒在礁石上變成橋，
## 農夫都倒下之後家豪會踩著樹幹走過去拿星星。往陸地那邊吹的話樹就倒在地上，這一次就拿不到了（按 R 重來）。

const ThunderItem := preload("res://levels/liuchiyu/items/thunder_item.gd")
const WindItem := preload("res://levels/liuchiyu/items/wind_item.gd")

## 枯樹的位置和高度在 island_world.gd 的 GROVE_TREES、GROVE_H（別的小關也要照樣種出來，所以放在那邊）
const BRIDGE_TREE := 3          # 第幾棵枯樹可以當橋（GROVE_TREES 裡的編號）：長在東邊海岸，朝外海的礁石倒就搭得上去
const TREE_H := 12.0           # 枯樹多高（倒下來可以壓到這麼遠；要跟 island_world.gd 的 GROVE_H 一樣）
const POOL_BIRD_DAMAGE := 5.0  # 家豪剛好在水灘裡被電到扣多少血（最多電到剩 1 滴）；他平常進不了水灘
const BRIDGE_ANGLE := 60.0     # 風的方向和「樹到礁石」的方向差幾度以內，樹就會倒在礁石上
const TRUNK_BLOCK := 0.7       # 站著的樹擋路的半徑
const BOLT_REACH := 4.0        # 雷劈在離樹多近才算劈中
const WIND_REACH := 4.5        # 風吹在離樹多近才吹得倒
const FALL_TIME := 0.9         # 樹倒下去要幾秒
const CRUSH_WIDTH := 1.7       # 倒下來的樹幹兩邊多寬會被壓到
const LOG_BLOCK := 0.85        # 倒在地上的樹幹擋路的半徑
const TREE_BIRD_DAMAGE := 4.0  # 家豪被壓到扣多少血（最多壓到剩 1 滴）

var _trees: Array = []         # 每棵：{pos, node, mat, struck, fall, dir, done, yaw}
var _gate: Dictionary = {}     # 崖壁上那棵枯樹：{node, mat, fall, done}
var _napoleon_tex: Texture2D
var _bridge_down := false      # 那棵樹已經倒向小島、變成橋了
var _skip_star := false        # 玩家按了 Enter：不拿星星，直接上高原
var _hovering := false         # 家豪現在是不是因為在水面上而飛著
var _obstacles0 := 0           # 場地原本有幾個擋路的東西（重試的時候把倒樹加的那些拿掉）

func _make_items() -> Array:
	return [
		ThunderItem.new().uses(0, -1),
		WindItem.new().uses(0, -1),
	]

func _enemy_specs() -> Array:
	return [
		{"name": "農夫1", "route": [Vector3(0, 0, 3), Vector3(4, 0, 0)], "loop": false, "pause": 1.2},
		{"name": "農夫2", "route": [Vector3(-1, 0, -6), Vector3(4.5, 0, -7.5), Vector3(-9, 0, -7)], "loop": false, "pause": 1.4},
		{"name": "農夫3", "route": [Vector3(9, 0, 3), Vector3(3, 0, 6), Vector3(8, 0, -4)], "loop": true, "pause": 0.8},
		# 兩個守門員：守在石階腳下，面朝場地，不巡邏、不追人、聽到聲音也不動
		{"name": "守門員1", "kind": "gate", "model": "merchant", "route": [world.GATE_GUARDS[0]], "yaw": PI * 0.5,
			"hp": 20.0, "immune_peck": true, "has_cone": false, "hears_noise": false, "can_slip": false},
		{"name": "守門員2", "kind": "gate", "model": "merchant", "route": [world.GATE_GUARDS[1]], "yaw": PI * 0.5,
			"hp": 20.0, "immune_peck": true, "has_cone": false, "hears_noise": false, "can_slip": false},
	]

## 守門員：站著不動（不叫一般敵人的行為）；倒下之後才交給共用程式處理
func _tick_enemy(f: Fighter, dt: float) -> void:
	if f.kind == "gate" and f.alive():
		f.data["rooted"] = true        # 風吹不動
		f.aggro = false
		f.kb_vel = Vector3.ZERO
		f.pos = ground(f.start_pos)
		f.yaw = PI * 0.5
		return
	super(f, dt)

## 家豪不會去打守門員
func nearest_enemy(from: Vector3) -> Fighter:
	var best: Fighter = null
	var bd := INF
	for f in enemies:
		if f.alive() and f.kind != "gate":
			var d := flat_dist(from, f.pos)
			if d < bd:
				bd = d
				best = f
	return best

## 開場只有一句（每個道具的說明在切換道具時會出現在技能欄上面）
func _tutorial_texts() -> Array:
	return ["用雷劈開枯樹，再按住風把它吹倒壓人。石階前的守門員要用崖壁上那棵樹砸。"]

func _prepare_hint() -> String:
	return "準備中：開打後 雷劈開枯樹 → 按住風吹倒壓人；敵人踩進水灘就用雷劈　按 Enter 開始"

func _win_line() -> String:
	return "往石階上面的高原走。"

func _next_stage() -> int:
	return 3

func _next_hint() -> String:
	if not _star_done and _bridge_down:
		return "家豪正在過去拿星星"
	return "石階的柵欄打開了，家豪正在往高原上走"

## 星星不是必要的：敵人都倒下就可以上石階。
## （過關時樹橋已經搭好、星星還沒拿的話，家豪會先繞去拿了再走，見 island_battle 的 _walk_exit）
func _exit_open() -> bool:
	# 砸在守門員身上的那棵樹（和被砸扁的守門員）消失之後，家豪才往石階走；不然走到一半東西突然不見很怪
	if _gate.is_empty() or _gate.fall < 0.0:
		return true
	return _gate.done and float(_gate.get("gone_t", 0.0)) >= GATE_GONE + GONE_TIME and _gate_cut < 0.0

## 星星在外海的礁石上；樹橋搭好了才拿得到
func _star_ready() -> bool:
	return _bridge_down

## 外海那塊礁石的頂（星星在上面）
func _isle_center() -> Vector3:
	return world.star_rock_top()

func _star_pos() -> Vector3:
	return _isle_center()

## 走去拿星星：樹根旁邊 → 踩上樹幹 → 沿著樹幹走到樹梢 → 踏上礁石
func _star_path() -> Array[Vector3]:
	var t: Dictionary = _trees[BRIDGE_TREE]
	var base: Vector3 = t.pos
	var d: Vector3 = t.dir
	var side := Vector3(-d.z, 0.0, d.x)
	var isle := _isle_center()
	var far: float = minf(flat_dist(base, isle), TREE_H - 1.4)
	# 腳踩在倒下來的樹幹上面：樹幹越往樹梢越細，所以越走越低（照樹幹實際的粗細算，不會浮在半空中）
	var out: Array[Vector3] = [base - d * 1.2 + side * 1.2]
	for sd in [1.2, 3.9, (3.9 + far) * 0.5, far]:
		var q: Vector3 = base + d * float(sd)
		out.append(Vector3(q.x, _log_top(base, float(sd)), q.z))
	out.append(isle)
	return out

## 倒在地上的那棵樹，離樹根 s 公尺的地方樹幹頂面有多高（樹幹的中心線在樹根的地面下 0.25 公尺）
func _log_top(base: Vector3, s: float) -> float:
	return base.y - 0.25 + world.dead_trunk_radius(TREE_H, s) - 0.04

## 拿完沿著樹幹走回來
func _star_back() -> Array[Vector3]:
	var p := _star_path()
	p.reverse()
	return p.slice(1)

## 過關之後家豪要走的路：石階腳下 → 一階一階走上高原
func _exit_path() -> Array[Vector3]:
	return world.stairs_path() if world.has_method("stairs_path") else []

# ---------------------------------------------------------------- 枯樹

## 進這一小關時預設選「雷」（不管道具清單怎麼排）。
## 剛進來的那一下不理滾輪和觸控板的滑動：從第一小關飛過來時手指還在滑（或觸控板的慣性滑動），
## 會把選好的雷又換成風。數字鍵不受影響。
const DEFAULT_ITEM := "thunder"
const ENTER_GUARD_MS := 1200
var _enter_ms := 0

func _select_default() -> void:
	for i in items.size():
		if items[i].id == DEFAULT_ITEM:
			select_skill(i)
			return

func _wheel_step(d: int) -> void:
	if Time.get_ticks_msec() - _enter_ms < ENTER_GUARD_MS:
		return
	super(d)

func _level_setup() -> void:
	super()
	_enter_ms = Time.get_ticks_msec()
	_select_default()
	for k in world.GROVE_TREES.size():
		var made: Dictionary = world.make_dead_tree_node(TREE_H, k, true)        # 高一點、分枝少的版本
		var node: Node3D = made.node
		world.add_child(node)
		var p: Vector3 = world.GROVE_TREES[k]
		world.obstacles.append([Vector2(p.x, p.z), TRUNK_BLOCK])        # 站著的樹也會擋路
		_trees.append({"pos": Vector3(p.x, world.height_at(p.x, p.z), p.z), "node": node, "mat": made.mat,
			"struck": false, "fall": -1.0, "dir": Vector3.RIGHT, "done": false, "yaw": float(k) * 1.7})
	# 崖壁上側著長的那棵枯樹
	var gmade: Dictionary = world.make_dead_tree_node(world.GATE_TREE_H, 99, true)
	world.add_child(gmade.node)
	_gate = {"node": gmade.node, "mat": gmade.mat, "fall": -1.0, "done": false}
	_napoleon_tex = _load_tex("res://assets/ui/napoleon.png")
	_obstacles0 = world.obstacles.size()
	_reset_trees()

func _level_reset() -> void:
	super()
	_reset_trees()

func _reset_trees() -> void:
	if _obstacles0 > 0:
		world.obstacles.resize(_obstacles0)        # 倒樹加的擋路圓拿掉
	_bridge_down = false
	_skip_star = false
	_reset_try()
	_end_gate_cut()
	_gate_cut_used = false
	if not _gate.is_empty():
		_gate.fall = -1.0
		_gate.done = false
		(_gate.mat as ShaderMaterial).set_shader_parameter("burnt", 0.0)
	for t in _trees:
		t.struck = false
		t.fall = -1.0
		t.done = false
		t.bridge = false
		(t.mat as ShaderMaterial).set_shader_parameter("burnt", 0.0)

## 換關的時候記下來：每棵枯樹有沒有被劈開、倒了沒、往哪邊倒
func _save_state() -> void:
	var list: Array = []
	for t in _trees:
		list.append({"struck": t.struck, "fallen": t.fall >= 0.0, "dir": Vector2(t.dir.x, t.dir.z), "gone": t.fall >= 0.0 and not t.get("bridge", false)})
	world.remember_zone(2, {"trees": list, "gate_tree": not _gate.is_empty() and _gate.fall >= 0.0})

## 雷劈下來（雷道具會叫這個）：離得最近、還沒劈過的枯樹被劈開
func on_thunder(p: Vector3) -> void:
	var best = null
	for t in _trees:
		if not t.struck and flat_dist(p, t.pos) <= BOLT_REACH:
			if best == null or flat_dist(p, t.pos) < flat_dist(p, best.pos):
				best = t
	if best:
		best.struck = true
		(best.mat as ShaderMaterial).set_shader_parameter("burnt", 1.0)
		# 跟第一小關河邊那棵一樣，劈開之後冒黑煙（掛在 fx_root 底下，重試會自動清掉）
		var smoke: CPUParticles3D = world.make_smoke(best.pos + Vector3(0.0, TREE_H * 0.4, 0.0))
		fx_root.add_child(smoke)
		best.smoke = smoke
		log_event("枯樹被雷劈開了")
	# 劈在崖壁上那棵枯樹：整棵倒下來
	if not _gate.is_empty() and _gate.fall < 0.0 and world.gate_tree_dist(p) <= BOLT_REACH + 1.0:
		_gate.fall = 0.0
		(_gate.mat as ShaderMaterial).set_shader_parameter("burnt", 1.0)
		log_event("崖壁上的枯樹被雷劈下來")

	# 劈在水灘上：站在水裡的人都被電倒
	for pool in world.zone_pools(2):
		if flat_dist(p, pool.center) > float(pool.r) * 1.3 + 0.8:
			continue        # 準心指在這一灘上才算
		var n := 0
		for f in enemies:
			if f.alive() and f.kind != "gate" and flat_dist(f.pos, pool.center) <= float(pool.r) * 1.3 and world.in_pool(2, f.pos.x, f.pos.z):
				# 水會導電：站在水裡的敵人直接被電倒
				f.hp = 0.0
				n += 1
				f.data.erase("blind_t")
				f.set_state("dead")
				anim(f, "Death")
				log_event("%s在水裡被電倒了" % f.name)
		if bird.alive() and bird.air < 0.5 and flat_dist(bird.pos, pool.center) <= float(pool.r) * 1.3 and world.in_pool(2, bird.pos.x, bird.pos.z):
			log_event("家豪在水裡被電到")
			hit_bird(minf(POOL_BIRD_DAMAGE, maxf(bird.hp - 1.0, 0.0)), true, pool.center)
		if n == 0:
			log_event("雷劈在水灘上，水裡沒有人")

## 家豪不踩水灘：走到水邊會被擋住（沿著邊緣繞過去），被打飛也不會掉進去
func _keep_out_of_pools() -> void:
	if _try_state == 2:
		return        # 正被守門員嚇得飛回來
	_keep_bird_dry(2, 1.0 / 60.0)

## 風吹過來（按住吹的每一步，風道具會叫這個）：劈開的枯樹順著風向倒下去
func on_wind(p: Vector3, dir: Vector3, _dt: float) -> void:
	for i in _trees.size():
		var t: Dictionary = _trees[i]
		if t.struck and t.fall < 0.0 and flat_dist(p, t.pos) <= WIND_REACH:
			t.fall = 0.0
			t.dir = Vector3(dir.x, 0.0, dir.z).normalized()
			var sm = t.get("smoke")
			if sm and is_instance_valid(sm):
				(sm as CPUParticles3D).emitting = false        # 倒下去就不冒煙了
			if i == BRIDGE_TREE:
				# 海岸那一棵：只要風大致是往海邊（礁石那一側）吹，就算搭上（偏 BRIDGE_ANGLE 度以內都算）
				var to_isle: Vector3 = _isle_center() - t.pos
				to_isle.y = 0.0
				if t.dir.dot(to_isle.normalized()) >= cos(deg_to_rad(BRIDGE_ANGLE)):
					t.bridge = true
					t.dir = to_isle.normalized()        # 算搭上了：樹就正正地倒在礁石的正上方，一眼看得出來有中
			log_event("枯樹被風吹倒了")

func _level_step(dt: float) -> void:
	super(dt)
	_step_trees(dt)
	_keep_out_of_pools()

func _level_step_ended(dt: float) -> void:
	super(dt)
	_step_trees(dt)
	_keep_out_of_pools()

## 崖壁上那棵枯樹倒下來：砸到樹底下的人（兩個守門員就站在那裡）
func _step_gate_tree(dt: float) -> void:
	if _gate.is_empty() or _gate.fall < 0.0 or _gate.done:
		return
	_gate.fall = minf(_gate.fall + dt / (FALL_TIME * 1.2), 1.0)
	if _gate.fall < 1.0:
		return
	_gate.done = true
	var a: Vector3 = world.gate_rock_top()
	var d: Vector3 = world.gate_tree_dir()
	noise_at(a + d * 5.0)
	for f in enemies:
		if f.alive() and _under_gate(f.pos, a, d):
			f.hp = 0.0
			f.data.erase("blind_t")
			f.set_state("dead")
			anim(f, "Death")
			log_event("倒下來的枯樹砸倒%s" % f.name)
	if bird.alive() and bird.air < 0.5 and _under_gate(bird.pos, a, d):
		log_event("倒下來的枯樹壓到家豪")
		hit_bird(minf(TREE_BIRD_DAMAGE, maxf(bird.hp - 1.0, 0.0)), true, a)

func _under_gate(p: Vector3, a: Vector3, d: Vector3) -> bool:
	var rel := Vector3(p.x - a.x, 0.0, p.z - a.z)
	var along := rel.dot(d)
	return along > 1.0 and along < world.GATE_TREE_H and (rel - d * along).length() <= 2.4

## 農夫都倒下了、只剩守門員：家豪打不動他們，但還是一直想走上石階——
## 走到守門員面前就被嚇得飛回來。連試兩次都不行，才說「THERE IS NOTHING I CAN DO」；
## 之後等一陣子再走過去試一次、又飛回來，一直重複到守門員被樹砸倒為止。
const TRY_STOP := 2.0          # 走到離守門員多近就被趕回來
const TRY_BACK := 3.0          # 被嚇到往後退多遠
const TRY_FLY := 0.7           # 飛回來飛幾秒
const TRY_PEAK := 1.3          # 飛多高
const TRY_QUICK := 0.7         # 第一次失敗之後隔多久再試
const TRY_WAIT := 5.0          # 之後每次隔多久再試

var _try_state := 0            # 0 等著、1 正在走過去、2 正在飛回來
var _try_t := 0.6              # 還要等多久
var _try_n := 0                # 試過幾次了
var _try_home := Vector3.ZERO  # 飛回哪裡（出發的地方）
var _try_from := Vector3.ZERO
var _try_k := 0.0

func _reset_try() -> void:
	_try_state = 0
	_try_t = 0.6
	_try_n = 0
	_try_k = 0.0

func _bird_state(st: String) -> void:
	if bird.state != st:
		bird.set_state(st)

func _say_nothing(dt: float) -> void:
	if phase != Phase.RUNNING or not bird.alive():
		return
	var farmers := enemies.any(func(f): return f.alive() and f.kind != "gate")
	var gates := enemies.any(func(f): return f.alive() and f.kind == "gate")
	if farmers or not gates:
		return
	# 樹橋搭到小島了：不管守門員，先走過去拿星星（正在飛回來的話等落地）
	if _try_state != 2 and _fetch_star(dt, true):
		_bird_state("charge")
		_try_state = 0
		_try_t = 0.8
		return
	var mid: Vector3 = (world.GATE_GUARDS[0] + world.GATE_GUARDS[1]) * 0.5
	match _try_state:
		0:
			_bird_state("linger")
			_try_t -= dt
			if _try_t <= 0.0:
				# 出發。被嚇回來的時候只往後退一小段（TRY_BACK 公尺），不會一路飛回場地另一頭
				_try_home = ground(mid + Vector3(TRY_STOP + TRY_BACK, 0.0, 0.0))
				_try_state = 1
		1:
			_bird_state("charge")
			var goal := ground(mid + Vector3(TRY_STOP, 0.0, 0.0))
			if _move_bird(goal, goal, dt) or flat_dist(bird.pos, mid) <= TRY_STOP + 0.2:
				_try_from = bird.pos
				_try_k = 0.0
				_try_state = 2
				_try_n += 1
				log_event("家豪想上石階，被守門員嚇得飛回來")
		2:
			_bird_state("fly")
			_try_k = minf(_try_k + dt / TRY_FLY, 1.0)
			bird.pos = ground(_try_from.lerp(_try_home, _try_k))
			bird.air = sin(_try_k * PI) * TRY_PEAK
			bird.yaw = atan2(_try_home.x - _try_from.x, _try_home.z - _try_from.z)
			if _try_k >= 1.0:
				bird.air = 0.0
				_try_state = 0
				if _try_n == 1:
					_try_t = TRY_QUICK        # 第一次：馬上再試一次
				else:
					_try_t = TRY_WAIT
					bird.yaw = atan2(mid.x - bird.pos.x, mid.z - bird.pos.z)
					log_event("家豪打不動守門員")
					say("THERE IS NOTHING I CAN DO", _napoleon_tex)

func _step_trees(dt: float) -> void:
	_step_gate_tree(dt)
	_say_nothing(dt)
	for t in _trees:
		if t.fall < 0.0 or t.done:
			continue
		t.fall = minf(t.fall + dt / FALL_TIME, 1.0)
		if t.fall < 1.0:
			continue
		t.done = true
		# 樹幹砸到地上：從樹根沿著倒的方向 TREE_H 公尺這一條，兩邊 CRUSH_WIDTH 以內的人都被壓到
		var a: Vector3 = t.pos
		var d: Vector3 = t.dir
		noise_at(a + d * (TREE_H * 0.5))
		var n := 0
		for f in enemies:
			# 守門員只有岩石上那棵樹砸得到，場地上的枯樹壓不到他們
			if f.alive() and f.kind != "gate" and _under(f.pos, a, d):
				f.hp = 0.0
				f.data.erase("blind_t")
				f.set_state("dead")
				anim(f, "Death")
				log_event("倒下來的枯樹壓倒%s" % f.name)
				n += 1
		if bird.alive() and bird.air < 0.5 and _under(bird.pos, a, d):
			log_event("倒下來的枯樹壓到家豪")
			hit_bird(minf(TREE_BIRD_DAMAGE, maxf(bird.hp - 1.0, 0.0)), true, a)        # 最多壓到剩 1 滴血
		if n == 0:
			log_event("枯樹倒在地上，沒壓到人")
		if t.get("bridge", false):
			_bridge_down = true        # 倒向小島的那一棵是橋，不擋路
			log_event("枯樹搭上外海的礁石，變成一座橋")
			continue
		# 倒在地上的樹幹不擋路，過一下就消失（見 _level_visuals 的 _gone()）；只有搭到小島的那一棵會留著

func _under(p: Vector3, a: Vector3, d: Vector3) -> bool:
	var rel := Vector3(p.x - a.x, 0.0, p.z - a.z)
	var along := rel.dot(d)
	return along > 0.6 and along < TREE_H and (rel - d * along).length() <= CRUSH_WIDTH

## 還沒倒的枯樹（準心指在它們身上就算指到）
func _aim_targets() -> Array:
	var out: Array = []
	for t in _trees:
		if t.fall < 0.0:
			out.append({"pos": t.pos, "h": TREE_H, "r": 2.4})
	if not _gate.is_empty() and _gate.fall < 0.0:
		out.append({"pos": world.gate_tree_mid(), "h": 10.0, "r": 3.2})
	return out

## 晚上會閃藍綠色的光的東西：還站著的枯樹、崖壁上那棵、水灘
func _glow_nodes() -> Array:
	var out: Array = []
	for t in _trees:
		out.append([t.node, t.fall < 0.0])
	if not _gate.is_empty():
		# 這棵樹是斜的：極光圈住伸出崖壁的那一段樹幹（位置自己給，不照模型的外框算）
		var top: Vector3 = world.gate_rock_top()
		var mid: Vector3 = top + world.gate_tree_fallen_basis(0.0) * Vector3.UP * (world.GATE_TREE_H * 0.55)
		out.append([_gate.node, _gate.fall < 0.0, {"pos": mid - Vector3(0.0, 2.6, 0.0), "r": 3.6, "h": 5.5}])
	for pool in world.zone_pools(2):
		if pool.node:
			out.append([pool.node, true])
	return out

const GONE_DELAY := 2.5        # 樹倒在地上之後過幾秒開始消失
const GONE_TIME := 0.8         # 花幾秒縮小不見

## 倒在地上的樹過一下就縮小不見。回傳現在要畫多大（1 = 原本大小，0 = 不見了）；o 裡面記 gone_t
func _gone(o: Dictionary, down: bool, delay := GONE_DELAY) -> float:
	if not down:
		o["gone_t"] = 0.0
		return 1.0
	o["gone_t"] = float(o.get("gone_t", 0.0)) + 1.0 / 60.0
	return clampf(1.0 - (float(o["gone_t"]) - delay) / GONE_TIME, 0.0, 1.0)

# ---------------------------------------------------------------- 樹砸守門員的小特寫

const GATE_GONE := 1.7         # 崖壁那棵樹砸下來之後過幾秒開始消失（被砸扁的守門員跟著一起不見）
const GATE_CUT_AT := 0.62      # 樹倒到幾成的時候切特寫（1 = 砸到）
const GATE_CUT_AFTER := 1.5    # 砸到之後特寫再停幾秒
const SQUASH_TIME := 0.12      # 守門員被砸扁要幾秒

var _gate_cut := -1.0          # 特寫播了幾秒（< 0 = 沒在播）
var _gate_cut_used := false    # 這一局已經播過特寫了
var _gate_hit := -1.0          # 特寫播到第幾秒的時候砸到的
var _gate_back := Transform3D.IDENTITY
var _gate_head := 0.0

## 樹快砸到守門員的時候：鏡頭拉到守門員前面，看著他們兩個被砸扁（鏡頭原本的位置先記下來）
func _start_gate_cut() -> void:
	if player == null or _gate_cut >= 0.0:
		return
	_gate_cut = 0.0
	_gate_hit = -1.0
	_gate_back = player.global_transform
	var head := player.get_node_or_null("Head") as Node3D
	_gate_head = head.rotation.x if head else 0.0
	player.set_physics_process(false)

## 特寫結束：鏡頭還給玩家，回到原本的位置
func _end_gate_cut() -> void:
	if _gate_cut < 0.0:
		return
	_gate_cut = -1.0
	if player:
		player.global_transform = _gate_back
		var head := player.get_node_or_null("Head") as Node3D
		if head:
			head.rotation.x = _gate_head
		player.set("velocity", Vector3.ZERO)
		player.set_physics_process(true)

## 每一畫面：特寫的鏡頭擺在兩個守門員斜前方、稍微低一點，看著他們
func _tick_gate_cut() -> void:
	# 雷劈下去的時候先不切鏡頭；等樹快砸到守門員的那一瞬間才拉特寫
	if _gate_cut < 0.0 and not _gate_cut_used and not _gate.is_empty() and _gate.fall >= GATE_CUT_AT and not _gate.done:
		_gate_cut_used = true
		_start_gate_cut()
	if _gate_cut < 0.0:
		return
	_gate_cut += 1.0 / 60.0
	if _gate.done and _gate_hit < 0.0:
		_gate_hit = _gate_cut
	var mid: Vector3 = ground((world.GATE_GUARDS[0] + world.GATE_GUARDS[1]) * 0.5)
	_aim_camera(mid + Vector3(4.8, 2.1, 2.2), mid + Vector3(0.0, 0.8, 0.0))
	if (_gate_hit >= 0.0 and _gate_cut - _gate_hit >= GATE_CUT_AFTER) or _gate_cut > 6.0:
		_end_gate_cut()

## 樹的樣子：劈開之後歪一點；倒下去的時候整棵繞著樹根轉 90 度。
## 準心指到現在手上的道具用得上的樹（拿雷：還沒劈的；拿風：劈開的），那棵樹會變淺白色。
func _level_visuals() -> void:
	super()
	if not world.has_method("set_highlight"):
		return
	var p := _aim_p()
	var id: String = items[selected].id if selected >= 0 and selected < items.size() else ""
	var live: bool = phase != Phase.PREPARE and not _leaving
	for t in _trees:
		var node: Node3D = t.node
		var basis := Basis(Vector3.UP, t.yaw)
		if t.fall >= 0.0:
			var axis: Vector3 = Vector3.UP.cross(t.dir).normalized()
			var k: float = t.fall
			basis = Basis(axis, PI * 0.5 * k * k) * basis
		elif t.struck:
			basis = Basis(Vector3(1, 0, 0), 0.09) * basis        # 劈開了，歪一點
		var keep: float = _gone(t, t.done and not t.get("bridge", false))
		node.visible = keep > 0.0
		node.global_transform = Transform3D(basis.scaled(Vector3.ONE * maxf(keep, 0.001)), t.pos - Vector3(0.0, 0.25, 0.0))
		var d := flat_dist(p, t.pos)
		var lit := false
		if live and t.fall < 0.0:
			if id == "thunder":
				lit = not t.struck and d <= BOLT_REACH
			elif id == "wind":
				lit = t.struck and d <= WIND_REACH
		world.set_highlight(node, lit)
	_tick_gate_cut()
	# 守門員被樹砸到：一下子被壓成扁扁的一片（往旁邊攤開），扁著躺一下，再跟樹一起縮小不見
	for f in enemies:
		if f.kind == "gate" and f.node:
			var gone: float = f.data.get("gone_t", 0.0)
			gone = 0.0 if f.alive() else gone + 1.0 / 60.0
			f.data["gone_t"] = gone
			var k := clampf(gone / SQUASH_TIME, 0.0, 1.0)
			var keep := clampf(1.0 - (gone - GATE_GONE) / GONE_TIME, 0.0, 1.0)
			f.node.scale = Vector3(1.0 + 0.7 * k, lerpf(1.0, 0.08, k), 1.0 + 0.7 * k) * maxf(keep, 0.001)
			f.node.visible = keep > 0.0
	# 崖壁上那棵枯樹：站著 → 被劈之後整棵倒向守門員；拿著雷指到它會變淺白色
	if not _gate.is_empty():
		var gn: Node3D = _gate.node
		var gk: float = maxf(_gate.fall, 0.0)
		var gkeep: float = _gone(_gate, _gate.done, GATE_GONE)
		gn.visible = gkeep > 0.0
		gn.global_transform = Transform3D(world.gate_tree_fallen_basis(gk * gk).scaled(Vector3.ONE * maxf(gkeep, 0.001)), world.gate_rock_top())
		world.set_highlight(gn, live and id == "thunder" and _gate.fall < 0.0 and world.gate_tree_dist(p) <= BOLT_REACH + 1.0)
	# 拿著雷指到水灘，水面也變淺白色
	for pool in world.zone_pools(2):
		if pool.node:
			world.set_highlight(pool.node, live and id == "thunder" and flat_dist(p, pool.center) <= float(pool.r) * 1.3 + 0.8)

